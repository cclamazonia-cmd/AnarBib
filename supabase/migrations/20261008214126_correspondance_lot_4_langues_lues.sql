-- =====================================================================
-- AnarBib — G19 lot 4 : les langues que l'équipe d'une bibliothèque lit
-- Date    : 2026-10-08
-- Ref     : backlog v34 G19 ; REGISTRE CORR-3 (pas de traduction automatique :
--           on écrit dans une langue que l'autre lit).
--
-- Sans traduction automatique (décision de Xavier du 08/10), la seule aide
-- possible au moment d'écrire est de savoir ce que l'autre équipe LIT. Ce
-- n'est pas `default_locale` (la langue de l'interface et des courriels de la
-- bibliothèque) ni `langue_fonds` de la cartographie (la langue des livres) :
-- c'est une déclaration de l'équipe, faite par sa coordination dans l'onglet
-- Identité. Le formulaire de correspondance la montre (« Cette bibliothèque
-- lit : … ») et propose la première langue commune aux deux équipes.
--
--   libraries.read_languages  text[]  NOT NULL DEFAULT '{}'
--     les codes des dix locales (CHECK) ; sans doublon et dans l'ordre canonique
--     (déclencheur BEFORE) ; vide = non déclaré (l'écran retombe sur default_locale).
--
-- Droits : `libraries` accorde UPDATE colonne par colonne à `authenticated`
-- (socle) ; la colonne neuve reçoit le sien, et c'est la politique
-- `libraries_staff_update` (staff de la bibliothèque, non restreint) qui
-- borne la ligne. Lecture : la politique `libraries_read` existante.
-- Suite : tests/sql/correspondance_lot1_tests.sql (T14).
-- =====================================================================

ALTER TABLE public.libraries
  ADD COLUMN IF NOT EXISTS read_languages text[] NOT NULL DEFAULT '{}'::text[];

ALTER TABLE public.libraries DROP CONSTRAINT IF EXISTS libraries_read_languages_check;
ALTER TABLE public.libraries ADD CONSTRAINT libraries_read_languages_check
  CHECK (read_languages <@ ARRAY['pt-BR','fr','es','en','it','de','ca','eo','nl','el']::text[]);

-- Une CHECK ne peut pas porter de sous-requête : le dédoublonnage et l'ordre canonique (celui de
-- SUPPORTED_LOCALES) sont posés par un déclencheur BEFORE, fermé à l'appel direct.
CREATE OR REPLACE FUNCTION public.tg_libraries_read_languages_normaliser()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  c_canon constant text[] := ARRAY['pt-BR','fr','es','en','it','de','ca','eo','nl','el'];
BEGIN
  NEW.read_languages := COALESCE(ARRAY(
    SELECT x FROM (SELECT DISTINCT unnest(NEW.read_languages) AS x) d
    ORDER BY array_position(c_canon, x) NULLS LAST, x), '{}'::text[]);
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.tg_libraries_read_languages_normaliser() FROM PUBLIC, anon, authenticated;
COMMENT ON FUNCTION public.tg_libraries_read_languages_normaliser() IS
  'G19 lot 4 : libraries.read_languages sans doublon, dans l''ordre des dix locales (SUPPORTED_LOCALES). Déclencheur seulement.';
DROP TRIGGER IF EXISTS trg_libraries_read_languages_normaliser ON public.libraries;
CREATE TRIGGER trg_libraries_read_languages_normaliser
  BEFORE INSERT OR UPDATE OF read_languages ON public.libraries
  FOR EACH ROW EXECUTE FUNCTION public.tg_libraries_read_languages_normaliser();

COMMENT ON COLUMN public.libraries.read_languages IS
  'G19 lot 4 (08/10/2026) : les langues que l''équipe de la bibliothèque lit, déclarées par sa coordination (onglet '
  'Identité) — dix locales, sans doublon ; vide = non déclaré. Montrées à qui lui écrit (correspondance), pour choisir '
  'une langue commune : il n''y a pas de traduction automatique (CORR-3). Ni default_locale (interface, courriels) ni '
  'langue_fonds (les livres).';

-- anon n'écrit jamais libraries : en production il n'a aucun UPDATE sur la table ; sur une image Supabase
-- rejouée depuis zéro (CI rejeu-image), le privilège par défaut lui ouvre toute table de public — ce REVOKE
-- nominatif (sans effet en production) rend le rejeu fidèle et laisse la vérification ci-dessous stricte.
REVOKE UPDATE ON TABLE public.libraries FROM anon;
GRANT UPDATE (read_languages) ON TABLE public.libraries TO authenticated;

-- Le commentaire posé au lot 1 annonçait « body_i18n / i18n_status attendent le lot 5 (traduction avec
-- consentement) » : la décision de Xavier du 08/10 au soir gèle la traduction automatique (CORR-3, pas
-- d'outil libre de qualité). Le commentaire dit désormais l'état réel ; les colonnes restent, vides.
COMMENT ON TABLE public.library_messages IS
  'G19 lot 1 : un message d''un fil, au nom d''une bibliothèque participante, écrit par une de ses coordinations. '
  'Le texte reste tel qu''écrit, dans sa langue (lang, dix locales). Pas de traduction automatique : décision de '
  'Xavier du 08/10/2026 (CORR-3, traduction différée, lot 5 gelé) ; body_i18n / i18n_status existent, vides. '
  'Sauvegarde #BG2 : flux court.';

DO $g19l4_verif$
DECLARE v_e text := '';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'libraries' AND column_name = 'read_languages' AND data_type = 'ARRAY') THEN
    v_e := v_e || ' colonne';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'libraries_read_languages_check' AND conrelid = 'public.libraries'::regclass) THEN
    v_e := v_e || ' check';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_libraries_read_languages_normaliser' AND tgrelid = 'public.libraries'::regclass) THEN
    v_e := v_e || ' trigger';
  END IF;
  IF has_function_privilege('authenticated', 'public.tg_libraries_read_languages_normaliser()', 'EXECUTE') THEN
    v_e := v_e || ' trigger-ouvert';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.column_privileges WHERE table_schema = 'public' AND table_name = 'libraries'
                  AND column_name = 'read_languages' AND grantee = 'authenticated' AND privilege_type = 'UPDATE') THEN
    v_e := v_e || ' grant-update';
  END IF;
  IF has_column_privilege('anon', 'public.libraries', 'read_languages', 'UPDATE') THEN
    v_e := v_e || ' anon-update';
  END IF;
  IF v_e <> '' THEN RAISE EXCEPTION 'G19 lot 4 : vérification en échec :%', v_e; END IF;
  RAISE NOTICE 'G19 lot 4 : vérifications OK — read_languages, dix locales, UPDATE pour les comptes connectés sous politique';
END
$g19l4_verif$;

NOTIFY pgrst, 'reload schema';
