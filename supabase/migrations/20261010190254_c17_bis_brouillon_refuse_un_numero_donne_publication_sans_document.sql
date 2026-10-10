-- =====================================================================
-- AnarBib — C17 bis : le brouillon d'exemplaire refuse déjà un numéro donné ;
--           publier sans document se dit
-- Date    : 2026-10-10
-- Ref     : backlog v34 C17 (CAT-E21), regard de Xavier à l'écran le 10/10.
--
-- L'essai de Xavier (10/10, 20 h 45) a montré deux trous :
--   1. un brouillon d'exemplaire s'enregistre avec un numéro déjà donné — la
--      règle CAT-E21 ne jouait qu'à la publication (déclencheur sur exemplares).
--      La personne apprend le refus après avoir rempli tout le formulaire.
--   2. un brouillon sans document (ni référence, ni fiche, ni exemplaire déjà
--      publié) passe l'enregistrement, et la publication casse sur la colonne
--      NOT NULL bib_ref : « erreur technique 23502 » au lieu d'un mot clair.
--
--   1. public.tg_exemplar_draft_tombo_refuse() — BEFORE INSERT OR UPDATE OF
--      tombo ON exemplar_drafts : un numéro au registre que plus aucun
--      exemplaire présent ne porte est refusé (error.catalog.tombo.deja_attribue,
--      même message qu'à la publication) ; un numéro porté par un AUTRE
--      exemplaire présent est refusé aussi (error.publish.tombo_duplicate) —
--      avant, la publication le remplaçait en silence par le suivant (rejeu
--      #fix-tombo-stale, qui reste pour les numéros proposés d'avance). Le
--      brouillon qui édite un exemplaire publié garde son propre numéro.
--   2. publish_exemplar_draft : sans référence résolue, 22023 avec
--      error.publish.bib_ref_required (clé déjà dans les dix locales), posé sur
--      la définition vivante par ancre comptée (md5 vérifié).
-- Suite : tests/sql/tombo_jamais_redonne_tests.sql (T7 à T9).
-- =====================================================================

CREATE OR REPLACE FUNCTION public.tg_exemplar_draft_tombo_refuse()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF NEW.tombo IS NULL OR btrim(NEW.tombo) = '' THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' AND NEW.tombo IS NOT DISTINCT FROM OLD.tombo THEN RETURN NEW; END IF;
  -- Porté par un exemplaire présent qui n'est pas celui que ce brouillon édite.
  IF EXISTS (SELECT 1 FROM public.exemplares e
              WHERE e.tombo = NEW.tombo AND e.id IS DISTINCT FROM NEW.published_exemplar_id) THEN
    RAISE EXCEPTION 'tombo_duplicate: %', NEW.tombo
      USING errcode = 'P0001', hint = 'error.publish.tombo_duplicate';
  END IF;
  -- Au registre, et plus aucun exemplaire présent ne le porte : libéré par une
  -- suppression, il ne se redonne pas (CAT-E21).
  IF EXISTS (SELECT 1 FROM public.tombos_attribues t
              WHERE t.tombo = NEW.tombo AND t.exemplar_id IS DISTINCT FROM NEW.published_exemplar_id) THEN
    RAISE EXCEPTION 'tombo_deja_attribue: %', NEW.tombo
      USING errcode = 'P0001', hint = 'error.catalog.tombo.deja_attribue';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.tg_exemplar_draft_tombo_refuse() FROM PUBLIC, anon, authenticated;
COMMENT ON FUNCTION public.tg_exemplar_draft_tombo_refuse() IS
  'C17 bis (CAT-E21, 10/10/2026) : un brouillon d''exemplaire refuse, dès l''enregistrement, un numéro déjà donné (registre) ou porté par un autre exemplaire présent. Déclencheur seulement.';
DROP TRIGGER IF EXISTS trg_exemplar_drafts_aa_tombo_refuse ON public.exemplar_drafts;
CREATE TRIGGER trg_exemplar_drafts_aa_tombo_refuse
  BEFORE INSERT OR UPDATE OF tombo ON public.exemplar_drafts
  FOR EACH ROW EXECUTE FUNCTION public.tg_exemplar_draft_tombo_refuse();

-- ── publish_exemplar_draft : publier sans document se dit ──────────────
DO $c17bis$
DECLARE
  v text;
  c_ancre constant text := E'  if v_draft.published_exemplar_id is null then\n    -- #fix-tombo-stale (15/08/2026)';
  c_garde constant text := E'  -- C17 bis (10/10/2026) : sans document résolu, le dire — avant, la colonne\n'
                        || E'  -- NOT NULL bib_ref levait un 23502 sans mot pour la personne.\n'
                        || E'  if v_draft.published_exemplar_id is null\n'
                        || E'     and nullif(btrim(coalesce(v_resolved_bib_ref, v_draft.target_bib_ref, '''')), '''') is null then\n'
                        || E'    raise exception ''bib_ref_required'' using errcode = ''22023'', hint = ''error.publish.bib_ref_required'';\n'
                        || E'  end if;\n';
BEGIN
  v := pg_get_functiondef('public.publish_exemplar_draft(bigint)'::regprocedure);
  IF md5(v) <> '53293ff5f6d930f08bf6a671915dd880' THEN
    RAISE EXCEPTION 'C17 bis : publish_exemplar_draft n''est pas la définition attendue (md5 %) — repartir de la définition réelle', md5(v);
  END IF;
  IF (SELECT count(*) FROM regexp_matches(v, regexp_replace(c_ancre, '([().\[\]*+?^$|\\])', '\\\1', 'g'), 'g')) <> 1 THEN
    RAISE EXCEPTION 'C17 bis : ancre introuvable ou multiple dans publish_exemplar_draft';
  END IF;
  v := replace(v, c_ancre, c_garde || c_ancre);
  EXECUTE v;
END
$c17bis$;

DO $c17bis_verif$
DECLARE v_e text := '';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.exemplar_drafts'::regclass AND tgname = 'trg_exemplar_drafts_aa_tombo_refuse') THEN v_e := v_e || ' trigger'; END IF;
  IF has_function_privilege('authenticated', 'public.tg_exemplar_draft_tombo_refuse()', 'EXECUTE') THEN v_e := v_e || ' declencheur-ouvert'; END IF;
  IF pg_get_functiondef('public.publish_exemplar_draft(bigint)'::regprocedure) NOT LIKE '%error.publish.bib_ref_required%' THEN v_e := v_e || ' publish-sans-garde'; END IF;
  IF NOT (SELECT prosecdef FROM pg_proc WHERE oid = 'public.publish_exemplar_draft(bigint)'::regprocedure) THEN v_e := v_e || ' publish-plus-definer'; END IF;
  IF v_e <> '' THEN RAISE EXCEPTION 'C17 bis : vérification en échec :%', v_e; END IF;
  RAISE NOTICE 'C17 bis : vérifications OK — refus au brouillon, publication sans document dite';
END
$c17bis_verif$;

NOTIFY pgrst, 'reload schema';
