-- ============================================================================
-- 20260522030000_peb_retour_partiel.sql
-- ----------------------------------------------------------------------------
-- Chantier #ILL-partial : retour partiel des prets interbibliotheques.
--
-- CONTEXTE
--   Le statut 'parcialmente_devolvido' existe dans le CHECK de
--   interlibrary_loans_v2 mais rien ne le produit. Cette migration cable
--   le retour partiel de bout en bout, cote base :
--
--   ETAPE 2 - RPC fn_peb_update_item_status
--     Permet de pointer un ou plusieurs exemplaires d'un pret comme rendus
--     (devolvido), perdus (perdido), endommages (danificado) ou annules
--     (cancelado). Atomique. Non-DEFINER : s'appuie sur la RLS
--     interlibrary_loan_items_v2_update (prêteuse OU emprunteuse).
--
--   ETAPE 3 - trigger de consolidation trg_peb_consolidate_loan_status
--     Sur interlibrary_loan_items_v2. Apres tout changement d'item_status,
--     recalcule le status_global du pret parent :
--       - exemplaire "regle"  = devolvido | perdido | danificado | cancelado
--       - exemplaire "dehors" = emprestado | reservado_para_saida
--       - tous regles                 -> 'devolvido'
--       - au moins un regle + un dehors -> 'parcialmente_devolvido'
--       - aucun regle                 -> ne touche pas
--     Garde-fou de phase : ne recalcule QUE si le pret est deja dans une
--     phase ou un retour a un sens (emprestado, em_devolucao, atrasado,
--     parcialmente_devolvido). N'ecrit que si la valeur change reellement
--     (IS DISTINCT FROM) pour ne pas declencher de notification parasite.
--
--   ETAPE 4 - branche 'parcialmente_devolvido' dans
--     trg_interlibrary_loan_enqueue_notifications
--     Ajoute le mapping parcialmente_devolvido -> interlibrary_loan_partially_returned.
--     L'Edge Function notify-interlibrary-loan et la cle i18n
--     ill.intro.partially_returned sont deja en place (branche dormante).
--
-- ENCHAINEMENT
--   RPC -> UPDATE items -> trigger consolidation -> UPDATE status_global du
--   pret -> trigger de notification -> event partially_returned -> EF.
--   Tout s'enchaine sans intervention : le trigger de notification ecoute
--   deja status_global.
--
-- PIPELINE
--   Fichier depose dans supabase/migrations/, applique par Woodpecker via
--   `supabase db push --linked`. Bloc DO de verification en fin.
-- ============================================================================


-- ============================================================================
-- ETAPE 2 — RPC fn_peb_update_item_status
-- ============================================================================
-- Calquee sur fn_peb_update_status (style RPC PEB de mise a jour) :
-- jsonb in/out, search_path 'public','pg_temp', PAS de SECURITY DEFINER,
-- validation explicite, IF NOT FOUND. Atomique (transaction implicite : un
-- RAISE EXCEPTION annule tous les UPDATE deja faits dans l'appel).
CREATE OR REPLACE FUNCTION public.fn_peb_update_item_status(p_loan_id bigint, p_items jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_item jsonb;
  v_item_id bigint;
  v_new_status text;
  v_loan interlibrary_loans_v2%ROWTYPE;
  v_items jsonb;
BEGIN
  IF p_loan_id IS NULL THEN
    RAISE EXCEPTION 'fn_peb_update_item_status: p_loan_id obligatoire';
  END IF;
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'fn_peb_update_item_status: p_items vide';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_item_id := NULLIF(v_item->>'id', '')::bigint;
    v_new_status := v_item->>'new_status';

    -- Validation : id et new_status presents.
    IF v_item_id IS NULL OR v_new_status IS NULL OR v_new_status = '' THEN
      RAISE EXCEPTION 'fn_peb_update_item_status: item invalide (id et new_status obligatoires) — item: %', v_item;
    END IF;

    -- Garde-fou metier : seuls les statuts de RETOUR sont autorises via
    -- cette RPC. Les statuts d'amont (reservado_para_saida, emprestado)
    -- sont poses par les operations du pret, jamais par le pointage de
    -- retour. On peut en revanche corriger librement entre statuts de
    -- retour (ex. perdido -> devolvido).
    IF v_new_status NOT IN ('devolvido', 'perdido', 'danificado', 'cancelado') THEN
      RAISE EXCEPTION 'fn_peb_update_item_status: statut de retour invalide "%" (attendu : devolvido, perdido, danificado, cancelado)', v_new_status;
    END IF;

    -- UPDATE. Double critere interlibrary_loan_id = p_loan_id AND id = v_item_id :
    -- garantit que l'exemplaire appartient bien au pret annonce (anti-usurpation).
    -- returned_at : pose si devolvido, efface sinon (un exemplaire perdu /
    -- endommage / annule n'a pas de date de retour).
    -- La RLS interlibrary_loan_items_v2_update verifie l'autorisation
    -- (gestionnaire de la bibliotheque prêteuse OU emprunteuse).
    UPDATE interlibrary_loan_items_v2
    SET
      item_status    = v_new_status,
      returned_at    = CASE WHEN v_new_status = 'devolvido'
                            THEN timezone('utc'::text, now())
                            ELSE NULL END,
      condition_back = COALESCE(v_item->>'condition_back', condition_back),
      notes          = COALESCE(v_item->>'notes', notes),
      updated_at     = timezone('utc'::text, now())
    WHERE interlibrary_loan_id = p_loan_id
      AND id = v_item_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'fn_peb_update_item_status: exemplaire id=% introuvable dans le PEB %, ou accès refusé', v_item_id, p_loan_id;
    END IF;
  END LOOP;

  -- Le trigger de consolidation a (potentiellement) deja mis a jour
  -- status_global. On relit le pret et ses items pour les retourner a jour.
  SELECT * INTO v_loan FROM interlibrary_loans_v2 WHERE id = p_loan_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'fn_peb_update_item_status: PEB id=% introuvable', p_loan_id;
  END IF;

  SELECT COALESCE(jsonb_agg(to_jsonb(i.*) ORDER BY i.line_no), '[]'::jsonb)
  INTO v_items
  FROM interlibrary_loan_items_v2 i
  WHERE i.interlibrary_loan_id = p_loan_id;

  RETURN jsonb_build_object(
    'loan', to_jsonb(v_loan),
    'items', v_items
  );
END;
$function$;


-- ============================================================================
-- ETAPE 3 — Trigger de consolidation du status_global
-- ============================================================================
-- Fonction du trigger. SECURITY DEFINER + search_path : le recalcul doit
-- pouvoir lire/ecrire interlibrary_loans_v2 quel que soit l'appelant — c'est
-- une consolidation systeme, pas une action utilisateur. REVOKE applique
-- plus bas (doctrine #150).
CREATE OR REPLACE FUNCTION public.fn_peb_consolidate_loan_status()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_loan_id bigint;
  v_current_status text;
  v_total int;
  v_settled int;
  v_outstanding int;
  v_new_status text;
BEGIN
  -- L'id du pret parent selon l'operation.
  IF tg_op = 'DELETE' THEN
    v_loan_id := old.interlibrary_loan_id;
  ELSE
    v_loan_id := new.interlibrary_loan_id;
  END IF;

  -- Statut courant du pret parent.
  SELECT status_global INTO v_current_status
  FROM interlibrary_loans_v2
  WHERE id = v_loan_id;

  IF NOT FOUND THEN
    -- Pret parent absent (ex. CASCADE en cours) : rien a faire.
    RETURN COALESCE(new, old);
  END IF;

  -- GARDE-FOU DE PHASE : on ne consolide que si le pret est dans une phase
  -- ou un retour d'exemplaire a un sens. En 'preparacao' ou 'aguardando_saida'
  -- (pas encore parti), ou en 'devolvido'/'cancelado' (deja clos), on ne
  -- touche a rien.
  IF v_current_status NOT IN ('emprestado', 'em_devolucao', 'atrasado', 'parcialmente_devolvido') THEN
    RETURN COALESCE(new, old);
  END IF;

  -- Comptage des exemplaires du pret.
  --   regle    = devolvido | perdido | danificado | cancelado
  --   dehors   = emprestado | reservado_para_saida
  SELECT
    count(*),
    count(*) FILTER (WHERE item_status IN ('devolvido','perdido','danificado','cancelado')),
    count(*) FILTER (WHERE item_status IN ('emprestado','reservado_para_saida'))
  INTO v_total, v_settled, v_outstanding
  FROM interlibrary_loan_items_v2
  WHERE interlibrary_loan_id = v_loan_id;

  -- Pret sans aucun exemplaire : rien a consolider.
  IF v_total = 0 THEN
    RETURN COALESCE(new, old);
  END IF;

  -- Regle de consolidation.
  IF v_settled = v_total THEN
    -- Tous les exemplaires sont regles -> pret entierement devolu.
    v_new_status := 'devolvido';
  ELSIF v_settled > 0 AND v_outstanding > 0 THEN
    -- Une partie reglee, une partie encore dehors -> retour partiel.
    v_new_status := 'parcialmente_devolvido';
  ELSE
    -- Aucun exemplaire regle (tout est encore dehors) : on ne touche pas.
    RETURN COALESCE(new, old);
  END IF;

  -- N'ecrit QUE si la valeur change reellement, pour ne pas reveiller
  -- le trigger de notification pour rien.
  IF v_new_status IS DISTINCT FROM v_current_status THEN
    UPDATE interlibrary_loans_v2
    SET status_global = v_new_status,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_loan_id;
  END IF;

  RETURN COALESCE(new, old);
END;
$function$;

-- Le trigger lui-meme. AFTER : la consolidation lit l'etat final des items.
DROP TRIGGER IF EXISTS trg_peb_consolidate_loan_status ON public.interlibrary_loan_items_v2;
CREATE TRIGGER trg_peb_consolidate_loan_status
  AFTER INSERT OR UPDATE OR DELETE ON public.interlibrary_loan_items_v2
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_peb_consolidate_loan_status();


-- ============================================================================
-- ETAPE 4 — Branche 'parcialmente_devolvido' dans le trigger de notification
-- ============================================================================
-- Recreation de trg_interlibrary_loan_enqueue_notifications a l'identique,
-- avec UN elsif ajoute : parcialmente_devolvido -> interlibrary_loan_partially_returned.
-- SECURITY DEFINER + search_path reconduits a l'identique.
CREATE OR REPLACE FUNCTION public.trg_interlibrary_loan_enqueue_notifications()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_event_id bigint;
begin
  if tg_op = 'INSERT' then
    v_event_id := public.fn_enqueue_emprestimo_interbibliotecas_notification(
      new.id,
      'interlibrary_loan_created',
      'created'
    );
    perform public.fn_notify_emprestimo_interbibliotecas_webhook(v_event_id);
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if old.status_global is distinct from new.status_global then
      if new.status_global = 'aguardando_saida' then
        v_event_id := public.fn_enqueue_emprestimo_interbibliotecas_notification(
          new.id,
          'interlibrary_loan_prepared',
          'prepared'
        );
        perform public.fn_notify_emprestimo_interbibliotecas_webhook(v_event_id);

      elsif new.status_global = 'emprestado' then
        v_event_id := public.fn_enqueue_emprestimo_interbibliotecas_notification(
          new.id,
          'interlibrary_loan_dispatched',
          'dispatched'
        );
        perform public.fn_notify_emprestimo_interbibliotecas_webhook(v_event_id);

      elsif new.status_global = 'em_devolucao' then
        v_event_id := public.fn_enqueue_emprestimo_interbibliotecas_notification(
          new.id,
          'interlibrary_loan_return_started',
          'return_started'
        );
        perform public.fn_notify_emprestimo_interbibliotecas_webhook(v_event_id);

      elsif new.status_global = 'devolvido' then
        v_event_id := public.fn_enqueue_emprestimo_interbibliotecas_notification(
          new.id,
          'interlibrary_loan_returned',
          'returned'
        );
        perform public.fn_notify_emprestimo_interbibliotecas_webhook(v_event_id);

      elsif new.status_global = 'parcialmente_devolvido' then
        -- AJOUT 20260522030000 (#ILL-partial) : retour partiel.
        v_event_id := public.fn_enqueue_emprestimo_interbibliotecas_notification(
          new.id,
          'interlibrary_loan_partially_returned',
          'partially_returned'
        );
        perform public.fn_notify_emprestimo_interbibliotecas_webhook(v_event_id);

      elsif new.status_global = 'cancelado' then
        v_event_id := public.fn_enqueue_emprestimo_interbibliotecas_notification(
          new.id,
          'interlibrary_loan_cancelled',
          'cancelled'
        );
        perform public.fn_notify_emprestimo_interbibliotecas_webhook(v_event_id);

      elsif new.status_global = 'atrasado' then
        v_event_id := public.fn_enqueue_emprestimo_interbibliotecas_notification(
          new.id,
          'interlibrary_loan_overdue',
          'overdue'
        );
        perform public.fn_notify_emprestimo_interbibliotecas_webhook(v_event_id);
      end if;
    end if;

    return new;
  end if;

  return new;
end;
$function$;


-- ============================================================================
-- PRIVILEGES (doctrine objets securises #150)
-- ============================================================================
-- fn_peb_consolidate_loan_status : fonction de trigger SECURITY DEFINER —
-- elle ne doit jamais etre appelable directement. REVOKE PUBLIC, GRANT postgres.
REVOKE EXECUTE ON FUNCTION public.fn_peb_consolidate_loan_status() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_peb_consolidate_loan_status() TO postgres;

-- trg_interlibrary_loan_enqueue_notifications : recreee ci-dessus. Bloc
-- idempotent (deja durcie) reconduisant l'etat de securite explicitement.
REVOKE EXECUTE ON FUNCTION public.trg_interlibrary_loan_enqueue_notifications() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.trg_interlibrary_loan_enqueue_notifications() TO postgres;

-- fn_peb_update_item_status : RPC appelee par le frontend authentifie.
-- NON-DEFINER (s'appuie sur la RLS). Doit etre executable par les roles
-- applicatifs, comme ses soeurs fn_peb_*. On reproduit le profil attendu :
-- execution par authenticated (et service_role pour les usages serveur).
REVOKE EXECUTE ON FUNCTION public.fn_peb_update_item_status(bigint, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_peb_update_item_status(bigint, jsonb) TO authenticated, service_role;


-- ============================================================================
-- VERIFICATION POST-MIGRATION (doctrine : bloc DO en fin de transaction)
-- ============================================================================
DO $verif$
declare
  v_ok boolean;
begin
  -- (a) La RPC fn_peb_update_item_status existe.
  select exists(
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'fn_peb_update_item_status'
  ) into v_ok;
  if not v_ok then
    raise exception 'Verification echouee : fn_peb_update_item_status absente.';
  end if;

  -- (b) La fonction de consolidation existe.
  select exists(
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'fn_peb_consolidate_loan_status'
  ) into v_ok;
  if not v_ok then
    raise exception 'Verification echouee : fn_peb_consolidate_loan_status absente.';
  end if;

  -- (c) Le trigger de consolidation est attache a interlibrary_loan_items_v2.
  select exists(
    select 1 from pg_trigger t join pg_class c on c.oid = t.tgrelid
    where c.relname = 'interlibrary_loan_items_v2'
      and t.tgname = 'trg_peb_consolidate_loan_status'
      and not t.tgisinternal
  ) into v_ok;
  if not v_ok then
    raise exception 'Verification echouee : trigger trg_peb_consolidate_loan_status absent.';
  end if;

  -- (d) Le trigger de notification contient bien la branche partially_returned.
  select position('interlibrary_loan_partially_returned' in pg_get_functiondef(p.oid)) > 0
  into v_ok
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'trg_interlibrary_loan_enqueue_notifications';
  if not v_ok then
    raise exception 'Verification echouee : branche partially_returned absente du trigger de notification.';
  end if;

  -- (e) PUBLIC ne peut pas executer la fonction de consolidation.
  if has_function_privilege('public', 'public.fn_peb_consolidate_loan_status()', 'EXECUTE') then
    raise exception 'Verification echouee : PUBLIC a EXECUTE sur fn_peb_consolidate_loan_status (doctrine #150).';
  end if;

  raise notice 'Migration 20260522030000 : verification OK (RPC, consolidation, trigger notif, privileges).';
end;
$verif$;
