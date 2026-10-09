-- =====================================================================
-- AnarBib — C17 : un numéro d'inventaire donné ne se redonne jamais
-- Date    : 2026-10-09
-- Ref     : backlog v34 C17 ; REGISTRE CAT-E21 (décision de Xavier du 08/10/2026).
--
-- Le constat (C17) : `CCLA.2026.93`, créé par erreur le 27/09 et retiré le
-- 28/09, a été redonné le 29/09 à un autre exemplaire. Ce n'était pas une
-- panne : fn_next_tombo rendait « le plus grand numéro PRÉSENT sous le
-- préfixe, plus un », et l'unicité (exemplares_unique_tombo) ne vaut qu'entre
-- exemplaires présents. Supprimer le dernier exemplaire d'une série libérait
-- donc son numéro — cinq numéros ont ainsi été portés par deux exemplaires
-- (relevé du 09/10 dans catalog_audit_log).
--
-- La règle (Xavier, 08/10) : un numéro donné ne se redonne JAMAIS. Un
-- numéro d'inventaire est une trace : qu'il ait été retiré, désherbé, ou
-- créé par erreur, il reste pris.
--
-- Ce que fait cette migration :
--   1. public.tombos_attribues — le registre de tous les numéros jamais
--      portés par un exemplaire (le premier exemplaire qui l'a porté, sa
--      bibliothèque, la date). Repris du stock (2 762 exemplaires) et du
--      journal des exemplaires supprimés (catalog_audit_log, instantané).
--      Fermé à anon et authenticated : seules les fonctions DEFINER le lisent.
--   2. Deux déclencheurs sur exemplares : AVANT — un numéro déjà au registre
--      et qu'aucun exemplaire présent ne porte est refusé (P0001, HINT
--      error.catalog.tombo.deja_attribue, dix locales) ; un numéro porté par
--      un exemplaire PRÉSENT reste du ressort de exemplares_unique_tombo
--      (23505), que publish_exemplar_draft sait rejouer avec un numéro neuf ;
--      APRÈS — tout numéro posé entre au registre, et y reste.
--   3. fn_next_tombo rend le plus grand numéro JAMAIS ATTRIBUÉ sous le
--      préfixe (stock + registre), plus un. Réécrite sur sa définition vivante
--      (md5 vérifié), signature, droits et verrou par préfixe inchangés.
-- Suite : tests/sql/tombo_jamais_redonne_tests.sql.
-- =====================================================================

-- ── 1. Le registre ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.tombos_attribues (
  tombo        text PRIMARY KEY,
  exemplar_id  bigint,                      -- le premier exemplaire qui l'a porté ; sans FK : il peut avoir disparu
  library_id   uuid,                        -- sa bibliothèque à ce moment ; sans FK : une bibliothèque retirée garde ses numéros
  attribue_le  timestamptz NOT NULL DEFAULT now(),
  source       text NOT NULL DEFAULT 'exemplar'
               CONSTRAINT tombos_attribues_source_check CHECK (source IN ('exemplar', 'reprise', 'journal'))
);
COMMENT ON TABLE public.tombos_attribues IS
  'C17 (CAT-E21, 09/10/2026) : tout numéro d''inventaire jamais porté par un exemplaire — il ne se redonne jamais, même après la '
  'suppression de l''exemplaire. Alimenté par déclencheur ; repris du stock (reprise) et du journal des suppressions (journal). '
  'Lu par fn_next_tombo et par le déclencheur de refus. Sauvegarde #BG2 : flux long.';
ALTER TABLE public.tombos_attribues ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.tombos_attribues FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.tombos_attribues TO service_role;

-- Reprise du stock : chaque exemplaire présent a donné son numéro.
INSERT INTO public.tombos_attribues (tombo, exemplar_id, library_id, attribue_le, source)
SELECT e.tombo, e.id, e.library_id, coalesce(e.created_at, now()), 'reprise'
  FROM public.exemplares e
 WHERE e.tombo IS NOT NULL AND btrim(e.tombo) <> ''
ON CONFLICT (tombo) DO NOTHING;

-- Reprise du journal : les exemplaires supprimés avant ce jour (discard_exemplar,
-- discard_book_cascade) ont laissé leur instantané dans catalog_audit_log.
INSERT INTO public.tombos_attribues (tombo, exemplar_id, library_id, attribue_le, source)
SELECT DISTINCT ON (t.tombo) t.tombo, t.exemplar_id, t.library_id, t.occurred_at, 'journal'
  FROM (
    SELECT coalesce(a.details->'snapshot'->>'tombo', a.details->>'tombo') AS tombo,
           a.entity_id AS exemplar_id,
           nullif(a.details->'snapshot'->>'library_id', '')::uuid AS library_id,
           a.occurred_at
      FROM public.catalog_audit_log a
     WHERE a.entity_type = 'exemplar' AND a.action IN ('discard', 'delete')
  ) t
 WHERE t.tombo IS NOT NULL AND btrim(t.tombo) <> ''
 ORDER BY t.tombo, t.occurred_at
ON CONFLICT (tombo) DO NOTHING;

-- ── 2. Les déclencheurs ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.tg_exemplar_tombo_jamais_redonne()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF NEW.tombo IS NULL OR btrim(NEW.tombo) = '' THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' AND NEW.tombo IS NOT DISTINCT FROM OLD.tombo THEN RETURN NEW; END IF;
  -- Déjà donné à un AUTRE exemplaire, et aucun exemplaire présent ne le porte :
  -- c'est un numéro libéré par une suppression — il ne se redonne pas.
  -- (S'il est porté par un exemplaire présent, exemplares_unique_tombo tranche,
  -- et publish_exemplar_draft sait rejouer avec un numéro neuf.)
  IF EXISTS (SELECT 1 FROM public.tombos_attribues t
              WHERE t.tombo = NEW.tombo AND t.exemplar_id IS DISTINCT FROM NEW.id)
     AND NOT EXISTS (SELECT 1 FROM public.exemplares e
                      WHERE e.tombo = NEW.tombo AND e.id <> NEW.id) THEN
    RAISE EXCEPTION 'tombo_deja_attribue: %', NEW.tombo
      USING errcode = 'P0001', hint = 'error.catalog.tombo.deja_attribue';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.tg_exemplar_tombo_jamais_redonne() FROM PUBLIC, anon, authenticated;
COMMENT ON FUNCTION public.tg_exemplar_tombo_jamais_redonne() IS
  'C17 (CAT-E21) : refuse, avant écriture, un numéro d''inventaire déjà donné que plus aucun exemplaire présent ne porte. Déclencheur seulement.';

CREATE OR REPLACE FUNCTION public.tg_exemplar_tombo_au_registre()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF NEW.tombo IS NULL OR btrim(NEW.tombo) = '' THEN RETURN NULL; END IF;
  INSERT INTO public.tombos_attribues (tombo, exemplar_id, library_id, attribue_le, source)
  VALUES (NEW.tombo, NEW.id, NEW.library_id, now(), 'exemplar')
  ON CONFLICT (tombo) DO NOTHING;
  RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION public.tg_exemplar_tombo_au_registre() FROM PUBLIC, anon, authenticated;
COMMENT ON FUNCTION public.tg_exemplar_tombo_au_registre() IS
  'C17 (CAT-E21) : tout numéro d''inventaire posé sur un exemplaire entre au registre tombos_attribues, et y reste. Déclencheur seulement.';

DROP TRIGGER IF EXISTS trg_exemplar_aa_tombo_jamais_redonne ON public.exemplares;
CREATE TRIGGER trg_exemplar_aa_tombo_jamais_redonne
  BEFORE INSERT OR UPDATE OF tombo ON public.exemplares
  FOR EACH ROW EXECUTE FUNCTION public.tg_exemplar_tombo_jamais_redonne();
DROP TRIGGER IF EXISTS trg_exemplar_zz_tombo_au_registre ON public.exemplares;
CREATE TRIGGER trg_exemplar_zz_tombo_au_registre
  AFTER INSERT OR UPDATE OF tombo ON public.exemplares
  FOR EACH ROW EXECUTE FUNCTION public.tg_exemplar_tombo_au_registre();

-- ── 3. fn_next_tombo : le plus grand numéro jamais attribué ────────────
DO $c17_garde$
DECLARE v_md5 text;
BEGIN
  SELECT md5(pg_get_functiondef('public.fn_next_tombo(uuid)'::regprocedure)) INTO v_md5;
  IF v_md5 <> 'a9ab3bde22171210f945715320ec1a45' THEN
    RAISE EXCEPTION 'C17 : fn_next_tombo n''est pas la définition attendue (md5 %) — repartir de la définition réelle', v_md5;
  END IF;
END
$c17_garde$;

CREATE OR REPLACE FUNCTION public.fn_next_tombo(p_library_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
declare
  v_pat         jsonb;
  v_prefix      text;
  v_use_year    boolean;
  v_sep         text;
  v_pad         int;
  v_full_prefix text;
  v_max         bigint;
  v_next        bigint;
  v_num_str     text;
begin

  IF auth.uid() IS NOT NULL
     AND NOT public.user_has_library_staff_role(auth.uid(), p_library_id)
     AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'forbidden: tombo numbering is reserved to the staff of that library'
      USING ERRCODE = '42501';
  END IF;
  select tombo_pattern into v_pat
    from public.libraries where id = p_library_id;

  if v_pat is null then
    raise exception 'tombo_pattern_not_configured'
      using errcode = 'P0001',
            hint = format('Nenhum padrão de tombo configurado para a biblioteca %s.', p_library_id);
  end if;

  v_prefix   := coalesce(v_pat->>'prefix', '');
  v_use_year := coalesce((v_pat->>'year')::boolean, false);
  v_sep      := coalesce(v_pat->>'sep', '');
  v_pad      := coalesce((v_pat->>'pad')::int, 0);

  v_full_prefix := v_prefix
    || case when v_use_year then to_char(current_date, 'YYYY') || v_sep else '' end;

  -- Sérialise la génération PAR PRÉFIXE (même biblio OU biblios au préfixe
  -- partagé) pour la durée de la transaction. #fix-tombo-global (15/08/2026).
  perform pg_advisory_xact_lock(hashtext('tombo:' || v_full_prefix));

  -- Max sous ce préfixe, TOUTES BIBLIOTHÈQUES CONFONDUES (unicité globale de
  -- `tombo`), sur les exemplaires PRÉSENTS et sur le registre de tous les
  -- numéros JAMAIS ATTRIBUÉS (C17, CAT-E21 : un numéro ne se redonne jamais —
  -- supprimer le dernier exemplaire d'une série ne libère pas son numéro).
  -- Séquence à trous tolérée. Préfixes prod sans '%' ni '_' → LIKE sûr.
  select coalesce(max(n), 0)
    into v_max
    from (
      select (substring(e.tombo from char_length(v_full_prefix) + 1))::bigint as n
        from public.exemplares e
       where e.tombo like v_full_prefix || '%'
         and substring(e.tombo from char_length(v_full_prefix) + 1) ~ '^[0-9]+$'
      union all
      select (substring(t.tombo from char_length(v_full_prefix) + 1))::bigint
        from public.tombos_attribues t
       where t.tombo like v_full_prefix || '%'
         and substring(t.tombo from char_length(v_full_prefix) + 1) ~ '^[0-9]+$'
    ) s;

  v_next := v_max + 1;
  v_num_str := case when v_pad > 0
                    then lpad(v_next::text, v_pad, '0')
                    else v_next::text end;

  return v_full_prefix || v_num_str;
end;
$function$;

-- ── Vérification ───────────────────────────────────────────────────────
DO $c17_verif$
DECLARE v_e text := ''; v_ex bigint; v_reg bigint;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relname = 'tombos_attribues' AND c.relrowsecurity) THEN v_e := v_e || ' table-ou-rls'; END IF;
  IF has_table_privilege('anon', 'public.tombos_attribues', 'SELECT') OR has_table_privilege('authenticated', 'public.tombos_attribues', 'SELECT') THEN v_e := v_e || ' registre-ouvert'; END IF;
  IF NOT has_table_privilege('service_role', 'public.tombos_attribues', 'SELECT') THEN v_e := v_e || ' service_role-sans-droit'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.exemplares'::regclass AND tgname = 'trg_exemplar_aa_tombo_jamais_redonne') THEN v_e := v_e || ' trigger-avant'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.exemplares'::regclass AND tgname = 'trg_exemplar_zz_tombo_au_registre') THEN v_e := v_e || ' trigger-apres'; END IF;
  IF has_function_privilege('authenticated', 'public.tg_exemplar_tombo_jamais_redonne()', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.tg_exemplar_tombo_au_registre()', 'EXECUTE') THEN v_e := v_e || ' declencheurs-ouverts'; END IF;
  IF pg_get_functiondef('public.fn_next_tombo(uuid)'::regprocedure) NOT LIKE '%tombos_attribues%' THEN v_e := v_e || ' fn_next_tombo'; END IF;
  SELECT count(*) INTO v_ex FROM public.exemplares WHERE tombo IS NOT NULL AND btrim(tombo) <> '';
  SELECT count(*) INTO v_reg FROM public.tombos_attribues;
  IF v_reg < v_ex THEN v_e := v_e || format(' registre-incomplet(%s<%s)', v_reg, v_ex); END IF;
  IF v_e <> '' THEN RAISE EXCEPTION 'C17 : vérification en échec :%', v_e; END IF;
  RAISE NOTICE 'C17 : vérifications OK — registre de % numéros (% exemplaires présents), déclencheurs posés et fermés, fn_next_tombo sur le registre', v_reg, v_ex;
END
$c17_verif$;

NOTIFY pgrst, 'reload schema';
