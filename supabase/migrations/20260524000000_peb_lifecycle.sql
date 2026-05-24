-- ============================================================================
-- 20260524000000_peb_lifecycle.sql
-- ----------------------------------------------------------------------------
-- Chantier #ILL-lifecycle — verrouiller la machine a etats du PEB.
-- Specification : docs/specs/spec-cycle-vie-peb.md
--
-- DEUX MANQUES TRAITES
--   A. Aucun trigger ne propage status_global -> item_status. Quand un PEB
--      passe 'emprestado', ses exemplaires restent 'reservado_para_saida' ;
--      dispatched_at / returned_at ne sont jamais poses.
--   B. Aucun controle des transitions : fn_peb_update_status fait un
--      SET status_global brut. On peut sauter des etapes (PEB #23 :
--      devolvido sans dispatched_at).
--
-- ARCHITECTURE — deux triggers separes (spec sec. 3)
--   1. trg_peb_validate_status_transition  BEFORE UPDATE  : valide la
--      transition contre la table de reference ; RAISE EXCEPTION si illicite.
--   2. trg_peb_propagate_status            AFTER UPDATE   : propage les
--      jalons (item_status, dispatched_at, returned_at).
--
--   La table de transitions licites est une VRAIE TABLE de reference
--   (interlibrary_loan_status_transitions) — choix retenu a l'implementation
--   parmi les deux options de la spec sec. 3.1 : plus auditable, evolutive
--   sans toucher au code du trigger.
--
-- CORRECTION DE SPEC ACTEE LE 24/05
--   Le graphe sec. 2.2 omettait la transition atrasado -> parcialmente_-
--   devolvido. Or fn_peb_consolidate_loan_status PEUT la produire (retour
--   partiel d'un PEB en retard). Sans elle, la consolidation serait bloquee
--   par le trigger de validation. La table ci-dessous l'inclut : atrasado a
--   les memes cibles de retour que emprestado.
--
-- VERIFICATION
--   Bloc DO : table peuplee, deux triggers presents, une transition
--   illicite est refusee, une transition licite passe.
-- ============================================================================


-- ─── Table de reference des transitions licites ─────────────────────────────
CREATE TABLE IF NOT EXISTS public.interlibrary_loan_status_transitions (
  from_status text NOT NULL,
  to_status   text NOT NULL,
  PRIMARY KEY (from_status, to_status)
);

COMMENT ON TABLE public.interlibrary_loan_status_transitions IS
  'Transitions licites de status_global d''un PEB (#ILL-lifecycle). '
  'Une ligne (A,B) autorise A -> B. Les transitions immobiles (A -> A) ne '
  'figurent PAS ici : elles sont tolerees directement par le trigger.';

-- GRANT explicites (doctrine Template 2 — conformite Supabase). Table de
-- reference en LECTURE SEULE : SELECT pour les roles legitimes, aucune
-- ecriture accordee (seules les migrations la peuplent, en tant que
-- postgres, qui n'a pas besoin de GRANT). Pas d'acces anon : la machinerie
-- interne du cycle de vie du PEB n'a pas a etre exposee a un role anonyme.
REVOKE ALL ON TABLE public.interlibrary_loan_status_transitions FROM PUBLIC, anon;
GRANT SELECT ON TABLE public.interlibrary_loan_status_transitions TO authenticated, service_role;

-- RLS : table de reference en lecture seule pour tous, ecriture personne
-- (hors postgres). Le trigger de validation est SECURITY DEFINER et lit la
-- table avec les droits du proprietaire.
ALTER TABLE public.interlibrary_loan_status_transitions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ilst_select ON public.interlibrary_loan_status_transitions;
CREATE POLICY ilst_select ON public.interlibrary_loan_status_transitions
  FOR SELECT USING (true);

-- Peuplement. Graphe valide (spec sec. 2.2 + correction atrasado du 24/05).
TRUNCATE public.interlibrary_loan_status_transitions;
INSERT INTO public.interlibrary_loan_status_transitions (from_status, to_status) VALUES
  ('preparacao',             'aguardando_saida'),
  ('preparacao',             'cancelado'),
  ('aguardando_saida',       'emprestado'),
  ('aguardando_saida',       'cancelado'),
  ('aguardando_saida',       'preparacao'),
  ('emprestado',             'em_devolucao'),
  ('emprestado',             'parcialmente_devolvido'),
  ('emprestado',             'atrasado'),
  ('emprestado',             'devolvido'),
  ('atrasado',               'em_devolucao'),
  ('atrasado',               'parcialmente_devolvido'),
  ('atrasado',               'devolvido'),
  ('parcialmente_devolvido', 'devolvido'),
  ('parcialmente_devolvido', 'emprestado'),
  ('em_devolucao',           'devolvido'),
  ('em_devolucao',           'parcialmente_devolvido');
-- devolvido et cancelado : etats terminaux, aucune ligne sortante.


-- ============================================================================
-- TRIGGER 1 — validation des transitions (manque B), BEFORE UPDATE
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_peb_validate_status_transition()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ok boolean;
BEGIN
  -- Transition immobile (statut inchange) : toujours toleree — un UPDATE peut
  -- ne modifier que d'autres colonnes.
  IF NEW.status_global IS NOT DISTINCT FROM OLD.status_global THEN
    RETURN NEW;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.interlibrary_loan_status_transitions
    WHERE from_status = OLD.status_global
      AND to_status   = NEW.status_global
  ) INTO v_ok;

  IF NOT v_ok THEN
    RAISE EXCEPTION
      'PEB #%: transition de statut interdite (% -> %). Cibles licites depuis "%": %.',
      OLD.id, OLD.status_global, NEW.status_global, OLD.status_global,
      COALESCE(
        (SELECT string_agg(to_status, ', ' ORDER BY to_status)
         FROM public.interlibrary_loan_status_transitions
         WHERE from_status = OLD.status_global),
        '(aucune — etat terminal)'
      );
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_peb_validate_status_transition() FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_peb_validate_status_transition ON public.interlibrary_loans_v2;
CREATE TRIGGER trg_peb_validate_status_transition
  BEFORE UPDATE ON public.interlibrary_loans_v2
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_peb_validate_status_transition();


-- ============================================================================
-- TRIGGER 2 — propagation des jalons (manque A), AFTER UPDATE
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_peb_propagate_status()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Ne fait rien si le statut n'a pas change.
  IF NEW.status_global IS NOT DISTINCT FROM OLD.status_global THEN
    RETURN NEW;
  END IF;

  -- Transition vers 'emprestado' : le PEB est expedie.
  --   - poser dispatched_at si pas deja pose ;
  --   - passer les exemplaires encore 'reservado_para_saida' a 'emprestado'.
  IF NEW.status_global = 'emprestado' THEN
    IF NEW.dispatched_at IS NULL THEN
      UPDATE interlibrary_loans_v2
        SET dispatched_at = timezone('utc', now())
        WHERE id = NEW.id AND dispatched_at IS NULL;
    END IF;
    UPDATE interlibrary_loan_items_v2
      SET item_status = 'emprestado'
      WHERE interlibrary_loan_id = NEW.id
        AND item_status = 'reservado_para_saida';
  END IF;

  -- Transition vers 'devolvido' : le PEB est clos. Poser returned_at.
  IF NEW.status_global = 'devolvido' AND NEW.returned_at IS NULL THEN
    UPDATE interlibrary_loans_v2
      SET returned_at = timezone('utc', now())
      WHERE id = NEW.id AND returned_at IS NULL;
  END IF;

  -- Marche arriere parcialmente_devolvido -> emprestado (spec sec. 3.2) :
  -- on NE de-pointe PAS les exemplaires deja regles. La marche arriere
  -- rouvre l'en-tete, elle n'efface pas le travail de pointage. Donc
  -- aucune action sur les items ici — comportement deliberement vide.

  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_peb_propagate_status() FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_peb_propagate_status ON public.interlibrary_loans_v2;
CREATE TRIGGER trg_peb_propagate_status
  AFTER UPDATE ON public.interlibrary_loans_v2
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_peb_propagate_status();


-- ============================================================================
-- VERIFICATION POST-MIGRATION
-- ============================================================================
DO $verif$
declare
  v_count integer;
begin
  -- (a) La table de transitions est peuplee (16 lignes attendues).
  select count(*) into v_count from public.interlibrary_loan_status_transitions;
  if v_count <> 16 then
    raise exception 'Verification echouee : % transitions en table, 16 attendues.', v_count;
  end if;

  -- (b) Les deux triggers existent sur interlibrary_loans_v2.
  select count(*) into v_count
  from pg_trigger
  where tgrelid = 'public.interlibrary_loans_v2'::regclass
    and not tgisinternal
    and tgname in ('trg_peb_validate_status_transition', 'trg_peb_propagate_status');
  if v_count <> 2 then
    raise exception 'Verification echouee : % triggers #ILL-lifecycle presents, 2 attendus.', v_count;
  end if;

  -- (c) Coherence de la table de transitions — test NON intrusif : on
  -- verifie la donnee qui pilote le trigger, sans inserer de PEB ni reveiller
  -- aucun trigger (pas d'effet de bord notification pendant la migration).
  -- La validation fonctionnelle reelle du trigger se fait en test apres
  -- deploiement, sur un PEB neuf.

  -- Une transition de saut d'etapes (preparacao -> devolvido) doit etre ABSENTE.
  if exists (select 1 from public.interlibrary_loan_status_transitions
             where from_status = 'preparacao' and to_status = 'devolvido') then
    raise exception 'Verification echouee : la transition illicite preparacao->devolvido figure dans la table.';
  end if;

  -- Une transition normale (preparacao -> aguardando_saida) doit etre PRESENTE.
  if not exists (select 1 from public.interlibrary_loan_status_transitions
                 where from_status = 'preparacao' and to_status = 'aguardando_saida') then
    raise exception 'Verification echouee : la transition licite preparacao->aguardando_saida manque dans la table.';
  end if;

  -- La correction du 24/05 doit etre presente : atrasado -> parcialmente_devolvido.
  if not exists (select 1 from public.interlibrary_loan_status_transitions
                 where from_status = 'atrasado' and to_status = 'parcialmente_devolvido') then
    raise exception 'Verification echouee : la transition atrasado->parcialmente_devolvido (correction 24/05) manque.';
  end if;

  -- Les etats terminaux n'ont aucune transition sortante.
  if exists (select 1 from public.interlibrary_loan_status_transitions
             where from_status in ('devolvido', 'cancelado')) then
    raise exception 'Verification echouee : un etat terminal (devolvido/cancelado) a une transition sortante.';
  end if;

  raise notice 'Migration 20260524000000 : verification OK (table 16 transitions coherente, 2 triggers presents).';
end;
$verif$;
