-- =====================================================================
-- AnarBib — B39 (12/10/2026) : les fixtures de formation sont étiquetées en
-- base, pour que toute mesure d'usage les exclue par une requête et non par
-- une note.
--
-- Constat du Grand Livre blanc v18 (chapitres 9.1, 10 — précision 3 — et 12,
-- ligne rouge « aucune mesure d'usage qui compte une fixture ») : la
-- bibliothèque de formation `blmf-teste` (onze membres, cinq exemplaires,
-- aucune circulation ; formation de la coordination BLMF le 10/10) « fausse
-- tout tableau qui ne la nomme pas ». Garder les fixtures en production est
-- un choix assumé — la formation se fait sur le vrai outil — à une condition :
-- « un étiquetage que toute mesure puisse lire », « par une requête, pas par
-- une note ». Vérifié le 12/10 : rien en base ne distinguait `blmf-teste`
-- ni ses comptes d'une bibliothèque et de lecteurs réels.
--
-- Ce que fait cette migration :
--   (1) `libraries.is_training` (booléen, défaut faux), posé à vrai sur
--       `blmf-teste` ; un déclencheur BEFORE le pose de lui-même sur toute
--       bibliothèque dont le slug dit « test » ou « formation »
--       (`tg_libraries_is_training_normaliser`) — jamais l'inverse : une
--       bibliothèque étiquetée reste étiquetée, et une vraie bibliothèque
--       peut l'être à la main ;
--   (2) les comptes de formation ne portent pas de marqueur propre : un
--       compte est de formation quand toutes ses appartenances sont dans des
--       bibliothèques de formation (les quatre `formacao-e*` qui n'ont que
--       `blmf-teste` ; la personne qui forme, membre d'une vraie
--       bibliothèque, reste un compte réel) ;
--   (3) `private.fn_mesures_hors_fixtures()` : les comptes du réseau que le
--       relevé « L'état réel », la supervision et le prochain Livre blanc
--       lisent — bibliothèques, comptes, appartenances, exemplaires,
--       circulation vivante (archived_at IS NULL) — chacun en deux colonnes,
--       réel / formation, avec la date de la mesure. INVOKER, search_path
--       figé, réservée au rôle de service (le relevé l'appelle sous
--       postgres) : aucune porte nouvelle pour anon ni authenticated.
-- Suite : tests/sql/b39_fixtures_etiquetees_tests.sql.
-- =====================================================================

ALTER TABLE public.libraries
  ADD COLUMN IF NOT EXISTS is_training boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.libraries.is_training IS
  'B39 (12/10/2026) : bibliothèque de formation (fixture en production). Toute mesure d''usage la compte à part — private.fn_mesures_hors_fixtures(). Posé par la migration sur blmf-teste, et par le déclencheur sur tout slug qui dit test ou formation.';

-- (1) le déclencheur : le slug le dit, la base le sait
CREATE OR REPLACE FUNCTION public.tg_libraries_is_training_normaliser()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  -- Un slug qui porte « test », « teste », « formacao », « formation » ou
  -- « training » comme segment (blmf-teste, formation-x, x-test) étiquette.
  -- On ne retire jamais une étiquette posée : pas de « := false ».
  IF NEW.is_training IS DISTINCT FROM true
     AND coalesce(NEW.slug, '') ~ '(^|-)(teste?|formacao|formation|training)(-|$)' THEN
    NEW.is_training := true;
  END IF;
  RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS trg_libraries_is_training_normaliser ON public.libraries;
CREATE TRIGGER trg_libraries_is_training_normaliser
  BEFORE INSERT OR UPDATE OF slug, is_training ON public.libraries
  FOR EACH ROW EXECUTE FUNCTION public.tg_libraries_is_training_normaliser();

REVOKE ALL ON FUNCTION public.tg_libraries_is_training_normaliser() FROM PUBLIC;

-- la fixture connue, et toute autre que le slug trahit déjà
UPDATE public.libraries SET is_training = true
 WHERE slug = 'blmf-teste' OR slug ~ '(^|-)(teste?|formacao|formation|training)(-|$)';

-- (3) la mesure hors fixtures
CREATE OR REPLACE FUNCTION private.fn_mesures_hors_fixtures()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path TO 'public', 'pg_temp'
AS $$
  WITH lf AS (
    SELECT l.id FROM public.libraries l WHERE l.is_training
  ),
  -- un compte de formation : au moins une appartenance, toutes dans des bibliothèques de formation
  cf AS (
    SELECT m.user_id
      FROM public.user_library_memberships m
     GROUP BY m.user_id
    HAVING bool_and(m.library_id IN (SELECT id FROM lf))
  )
  SELECT jsonb_build_object(
    'bibliotheques', jsonb_build_object(
      'reelles',          (SELECT count(*) FROM public.libraries l WHERE NOT l.is_training),
      'reelles_actives',  (SELECT count(*) FROM public.libraries l WHERE NOT l.is_training AND coalesce(l.is_active, true)),
      'formation',        (SELECT count(*) FROM lf),
      'formation_slugs',  (SELECT coalesce(jsonb_agg(l.slug ORDER BY l.slug), '[]'::jsonb) FROM public.libraries l WHERE l.is_training)),
    'comptes', jsonb_build_object(
      'reels',            (SELECT count(*) FROM auth.users u WHERE u.id NOT IN (SELECT user_id FROM cf)),
      'reels_confirmes',  (SELECT count(*) FROM auth.users u WHERE u.id NOT IN (SELECT user_id FROM cf) AND u.email_confirmed_at IS NOT NULL),
      'formation',        (SELECT count(*) FROM auth.users u WHERE u.id IN (SELECT user_id FROM cf))),
    'appartenances_actives', jsonb_build_object(
      'reelles',          (SELECT count(*) FROM public.user_library_memberships m WHERE m.status = 'active' AND m.library_id NOT IN (SELECT id FROM lf)),
      'formation',        (SELECT count(*) FROM public.user_library_memberships m WHERE m.status = 'active' AND m.library_id IN (SELECT id FROM lf))),
    'exemplaires', jsonb_build_object(
      'reels',            (SELECT count(*) FROM public.exemplares e WHERE e.library_id NOT IN (SELECT id FROM lf)),
      'formation',        (SELECT count(*) FROM public.exemplares e WHERE e.library_id IN (SELECT id FROM lf))),
    'circulation_vivante', jsonb_build_object(
      'emprunts',         (SELECT count(*) FROM public.emprestimos_v2 x WHERE x.archived_at IS NULL AND x.library_id NOT IN (SELECT id FROM lf)),
      'reservations',     (SELECT count(*) FROM public.reservas_v2 x WHERE x.archived_at IS NULL AND x.library_id NOT IN (SELECT id FROM lf)),
      'consultations',    (SELECT count(*) FROM public.consultas_locais_v2 x WHERE x.archived_at IS NULL AND x.library_id NOT IN (SELECT id FROM lf)),
      'peb',              (SELECT count(*) FROM public.interlibrary_loans_v2 x WHERE x.archived_at IS NULL
                             AND x.lender_library_id NOT IN (SELECT id FROM lf) AND x.borrower_library_id NOT IN (SELECT id FROM lf)),
      'formation',        (SELECT count(*) FROM public.emprestimos_v2 x WHERE x.archived_at IS NULL AND x.library_id IN (SELECT id FROM lf))
                        + (SELECT count(*) FROM public.reservas_v2 x WHERE x.archived_at IS NULL AND x.library_id IN (SELECT id FROM lf))
                        + (SELECT count(*) FROM public.consultas_locais_v2 x WHERE x.archived_at IS NULL AND x.library_id IN (SELECT id FROM lf))),
    'mesure_a', now()
  );
$$;

COMMENT ON FUNCTION private.fn_mesures_hors_fixtures() IS
  'B39 (12/10/2026) : les comptes du réseau hors fixtures de formation (bibliothèques, comptes, appartenances, exemplaires, circulation vivante), réel / formation, avec la date de la mesure. Pour le relevé « L''état réel », la supervision et le Livre blanc. INVOKER, rôle de service seulement.';

REVOKE ALL ON FUNCTION private.fn_mesures_hors_fixtures() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.fn_mesures_hors_fixtures() TO service_role;

-- Vérification : la colonne, le déclencheur, la mesure, les droits.
DO $b39$
DECLARE v_e text := ''; v_m jsonb;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'libraries' AND column_name = 'is_training') THEN v_e := v_e || ' colonne'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.libraries'::regclass AND tgname = 'trg_libraries_is_training_normaliser') THEN v_e := v_e || ' declencheur'; END IF;
  IF EXISTS (SELECT 1 FROM public.libraries WHERE slug = 'blmf-teste' AND NOT is_training) THEN v_e := v_e || ' blmf-teste'; END IF;
  v_m := private.fn_mesures_hors_fixtures();
  IF (v_m->'bibliotheques'->>'reelles')::int + (v_m->'bibliotheques'->>'formation')::int <> (SELECT count(*) FROM public.libraries) THEN v_e := v_e || ' bibliotheques'; END IF;
  IF (v_m->'comptes'->>'reels')::int + (v_m->'comptes'->>'formation')::int <> (SELECT count(*) FROM auth.users) THEN v_e := v_e || ' comptes'; END IF;
  IF (SELECT p.prosecdef FROM pg_proc p WHERE p.oid = 'private.fn_mesures_hors_fixtures()'::regprocedure)
     OR has_function_privilege('anon', 'private.fn_mesures_hors_fixtures()', 'EXECUTE')
     OR has_function_privilege('authenticated', 'private.fn_mesures_hors_fixtures()', 'EXECUTE')
     OR NOT has_function_privilege('service_role', 'private.fn_mesures_hors_fixtures()', 'EXECUTE') THEN v_e := v_e || ' droits'; END IF;
  IF v_e <> '' THEN RAISE EXCEPTION 'B39 — vérification en échec :%', v_e; END IF;
END
$b39$;
