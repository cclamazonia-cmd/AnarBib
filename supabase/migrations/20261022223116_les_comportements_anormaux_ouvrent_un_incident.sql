-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — les comportements anormaux ouvrent un incident (22/10/2026)
-- Auteur  : Xavier (CCLA) + Claude
-- Session : Modele de menace
--
-- health-probe ne voyait que les pannes. Deux sondes de plus, sur le modèle des
-- sondes structurelles (un `ok`, des rubriques en tableaux, le bilan joint à
-- l'alerte, un courriel à l'ouverture et un à la clôture) :
--
--   * `abus` — les freins (public.auth_rate_limits, P6) : beaucoup de clés
--     frappées dans la même fenêtre, ou plusieurs clés bloquées d'un même genre.
--     Le bilan ne porte que des genres et des nombres, jamais une clé.
--
--   * `consultations` — les lectures nominatives par un même compte : beaucoup
--     d'appels, beaucoup de fiches, ou beaucoup de bibliothèques dans l'heure.
--
-- Le journal des consultations COMPTE et ne nomme pas (décision de Xavier du
-- 22/10/2026, `FED-O2` adressé en mode comptage) : qui consulte, par quelle
-- fonction, dans quelle bibliothèque, combien de fiches, quand. JAMAIS quelle
-- personne a été consultée — un journal qui la nommerait serait lui-même un
-- fichier « qui regarde qui », à protéger autant que ce qu'il surveille.
--
-- Trois fonctions écrivent au journal : celles qu'un compte connecté peut
-- appeler et qui rendent des données nominatives (api.get_reader_roster,
-- public.fn_network_admin_find_user_by_email,
-- public.fn_painel_reader_other_memberships). Corps repris de la définition
-- RÉELLE en production le 22/10 ; deux changements chacune : l'écriture au
-- journal, et STABLE → VOLATILE (PostgREST exécute une fonction STABLE dans une
-- transaction en lecture seule, où l'écriture échouerait). Les trois
-- fn_painel_find_profile_by_email / _by_lookup / fn_painel_get_profile_by_id ne
-- sont exécutables par aucun compte : rien à journaliser.
--
-- Limite connue : les lectures directes de tables sous RLS (profils, adhésions)
-- ne passent par aucune fonction et ne se comptent pas ici. Elles se verront par
-- les journaux de requêtes de l'hébergeur, chantier renvoyé après la phase 2.
--
-- Conservation : 12 mois (`RET-3`, journaux du réseau), purgée par health-probe
-- à chaque tour via public.fn_consultations_purger().
--
-- Deux endroits à tenir ENSEMBLE : la CHECK ci-dessous et `sondesStructurelles`
-- dans health-probe (src/tests/health-probe-kinds-check.test.js lit CETTE liste).
--
-- Tests : tests/sql/alertes_comportements_tests.sql.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- ─── 1. Le journal des consultations nominatives ───────────────────────────
CREATE TABLE IF NOT EXISTS private.consultations_nominatives (
  id          bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  le          timestamptz NOT NULL DEFAULT now(),
  par         uuid,
  fonction    text        NOT NULL CHECK (fonction ~ '^[a-z_.]{1,80}$'),
  library_id  uuid,
  nb          integer     NOT NULL CHECK (nb >= 0)
);

COMMENT ON TABLE private.consultations_nominatives IS
  'Un enregistrement par appel d''une fonction qui rend des données nominatives : qui appelle (par), quelle fonction, dans quelle bibliothèque, combien de fiches (nb), quand. Ne porte JAMAIS la personne consultée (FED-O2 en mode comptage, 22/10/2026). Lue par fn_healthcheck_consultations ; purgée à 12 mois (RET-3).';
COMMENT ON COLUMN private.consultations_nominatives.par IS
  'auth.uid() de l''appelant ; NULL = appel de service (service_role). Sans clé étrangère : le départ d''un compte n''efface pas ce qu''il a consulté.';

CREATE INDEX IF NOT EXISTS consultations_nominatives_le_idx
  ON private.consultations_nominatives (le DESC);

ALTER TABLE private.consultations_nominatives ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.consultations_nominatives FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, DELETE ON private.consultations_nominatives TO service_role;

-- Écriture au journal. INVOKER : elle s'exécute avec les droits de la fonction
-- DEFINER qui l'appelle ; aucun compte ne peut l'appeler lui-même (pas de fausse
-- trace, pas de trace effacée).
CREATE OR REPLACE FUNCTION private.fn_noter_consultation(p_fonction text, p_library_id uuid, p_nb integer)
RETURNS void
LANGUAGE sql
SECURITY INVOKER
SET search_path = pg_catalog, pg_temp
AS $function$
  INSERT INTO private.consultations_nominatives (par, fonction, library_id, nb)
  VALUES (auth.uid(), p_fonction, p_library_id, greatest(coalesce(p_nb, 0), 0));
$function$;

REVOKE EXECUTE ON FUNCTION private.fn_noter_consultation(text, uuid, integer) FROM PUBLIC, anon, authenticated;

-- ─── 2. Les trois fonctions nominatives écrivent au journal ────────────────
CREATE OR REPLACE FUNCTION api.get_reader_roster(p_library_id uuid)
 RETURNS TABLE(user_id uuid, last_name text, first_name text, email text, local_identity text, status text, imported_from_legacy boolean, registered_since timestamp with time zone)
 LANGUAGE plpgsql
 VOLATILE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_n integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Autenticação obrigatória.';
  END IF;

  -- Coordenador/admin de la biblio uniquement (RLS coordenador, CARD-LOCAL-N3).
  IF NOT public.user_can_manage_library(p_library_id) THEN
    RAISE EXCEPTION 'Acesso de coordenação obrigatório nesta biblioteca.'
      USING ERRCODE = 'P0001', HINT = 'error.coord_required';
  END IF;

  RETURN QUERY
    SELECT
      m.user_id,
      p.last_name,
      p.first_name,
      p.email,
      m.local_reader_number             AS local_identity,
      m.status,
      coalesce(m.imported_from_legacy, false) AS imported_from_legacy,
      m.created_at                      AS registered_since
    FROM public.user_library_memberships m
    JOIN public.profiles p ON p.id = m.user_id
   WHERE m.library_id = p_library_id
     AND m.role = 'reader'
     AND coalesce(m.status, '') NOT IN ('removed', 'terminated')
   ORDER BY lower(coalesce(p.last_name, '')), lower(coalesce(p.first_name, '')), p.email;

  GET DIAGNOSTICS v_n = ROW_COUNT;
  PERFORM private.fn_noter_consultation('api.get_reader_roster', p_library_id, v_n);
END;
$function$;

REVOKE EXECUTE ON FUNCTION api.get_reader_roster(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION api.get_reader_roster(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_network_admin_find_user_by_email(p_email text)
 RETURNS uuid
 LANGUAGE plpgsql
 VOLATILE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_id    uuid;
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Recherche réservée à l''administration du réseau.'
      USING ERRCODE = '42501', HINT = 'error.forbidden';
  END IF;
  IF v_email = '' THEN
    RETURN NULL;
  END IF;
  SELECT u.id INTO v_id
    FROM auth.users u
    JOIN public.profiles p ON p.id = u.id
   WHERE lower(btrim(u.email)) = v_email
     AND u.deleted_at IS NULL
   LIMIT 1;
  -- Un appel sans résultat compte aussi : c'est la forme d'une énumération.
  PERFORM private.fn_noter_consultation('fn_network_admin_find_user_by_email', NULL,
                                        CASE WHEN v_id IS NULL THEN 0 ELSE 1 END);
  RETURN v_id;
END
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_network_admin_find_user_by_email(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_network_admin_find_user_by_email(text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.fn_painel_reader_other_memberships(p_user_id uuid, p_viewer_library_id uuid)
 RETURNS TABLE(enriched boolean, library_id uuid, library_name text, membership_status text, is_restricted boolean)
 LANGUAGE plpgsql
 VOLATILE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_membre boolean;
BEGIN
  IF NOT public.user_can_act_as_staff_on_library(p_viewer_library_id) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff da biblioteca.'
      USING ERRCODE = '42501', HINT = 'error.partnership.forbidden';
  END IF;
  v_membre := EXISTS (SELECT 1 FROM public.user_library_memberships m
                       WHERE m.user_id = p_user_id AND m.library_id = p_viewer_library_id
                         AND m.status = 'active');
  -- Une fiche consultée (ou zéro si la personne n'est pas de la bibliothèque) ;
  -- le journal ne retient pas laquelle.
  PERFORM private.fn_noter_consultation('fn_painel_reader_other_memberships', p_viewer_library_id,
                                        CASE WHEN v_membre THEN 1 ELSE 0 END);
  IF NOT v_membre THEN
    RETURN;
  END IF;
  RETURN QUERY
  WITH others AS (
    SELECT m.library_id AS lib, m.status AS st,
           COALESCE(m.is_restricted, false) AS restr,
           COALESCE(l.short_name, l.name) AS lname,
           public.fn_partnership_transparence_active(p_viewer_library_id, m.library_id, p_user_id) AS ok
    FROM public.user_library_memberships m
    JOIN public.libraries l ON l.id = m.library_id
    WHERE m.user_id = p_user_id AND m.status = 'active'
      AND m.library_id <> p_viewer_library_id
  )
  SELECT o.ok,
         CASE WHEN o.ok THEN o.lib END,
         CASE WHEN o.ok THEN o.lname END,
         CASE WHEN o.ok THEN o.st END,
         CASE WHEN o.ok THEN o.restr END
  FROM others o;
END $function$;

REVOKE EXECUTE ON FUNCTION public.fn_painel_reader_other_memberships(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_painel_reader_other_memberships(uuid, uuid) TO authenticated, service_role;

-- ─── 3. La sonde des consultations ─────────────────────────────────────────
-- Seuils par défaut (réseau de six bibliothèques au 22/10/2026, la plus grande
-- à quelques dizaines de lecteur·rices) : 60 appels, 2 000 fiches ou
-- 4 bibliothèques par compte et par heure. Ce sont des paramètres : le banc les
-- abaisse, et un réseau plus grand les relèvera sans toucher au corps.
CREATE OR REPLACE FUNCTION public.fn_healthcheck_consultations(
  p_fenetre_min integer DEFAULT 60,
  p_seuil_appels integer DEFAULT 60,
  p_seuil_fiches integer DEFAULT 2000,
  p_seuil_biblios integer DEFAULT 4)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v jsonb;
BEGIN
  IF p_fenetre_min IS NULL OR p_fenetre_min < 1 OR p_fenetre_min > 10080
     OR coalesce(p_seuil_appels, 0) < 1 OR coalesce(p_seuil_fiches, 0) < 1 OR coalesce(p_seuil_biblios, 0) < 1 THEN
    RAISE EXCEPTION 'sonde consultations : fenêtre ou seuil hors bornes' USING ERRCODE = '22023';
  END IF;

  WITH par_compte AS (
    SELECT coalesce(c.par::text, 'service') AS compte,
           count(*)                         AS appels,
           coalesce(sum(c.nb), 0)           AS fiches,
           count(DISTINCT c.library_id)     AS bibliotheques,
           array_agg(DISTINCT c.fonction)   AS fonctions
      FROM private.consultations_nominatives c
     WHERE c.le > now() - make_interval(mins => p_fenetre_min)
     GROUP BY 1
  )
  SELECT jsonb_build_object(
           'ok', NOT EXISTS (SELECT 1 FROM par_compte
                              WHERE appels >= p_seuil_appels OR fiches >= p_seuil_fiches
                                 OR bibliotheques >= p_seuil_biblios),
           'verifie_le', now(),
           'fenetre_min', p_fenetre_min,
           'seuils', jsonb_build_object('appels', p_seuil_appels, 'fiches', p_seuil_fiches,
                                        'bibliotheques', p_seuil_biblios),
           'appels_en_rafale', coalesce((SELECT jsonb_agg(jsonb_build_object(
                 'compte', compte, 'appels', appels, 'fonctions', to_jsonb(fonctions)) ORDER BY appels DESC)
               FROM par_compte WHERE appels >= p_seuil_appels), '[]'::jsonb),
           'fiches_en_masse', coalesce((SELECT jsonb_agg(jsonb_build_object(
                 'compte', compte, 'fiches', fiches, 'fonctions', to_jsonb(fonctions)) ORDER BY fiches DESC)
               FROM par_compte WHERE fiches >= p_seuil_fiches), '[]'::jsonb),
           'bibliotheques_multiples', coalesce((SELECT jsonb_agg(jsonb_build_object(
                 'compte', compte, 'bibliotheques', bibliotheques, 'fonctions', to_jsonb(fonctions)) ORDER BY bibliotheques DESC)
               FROM par_compte WHERE bibliotheques >= p_seuil_biblios), '[]'::jsonb),
           'que_faire', 'Le compte est un identifiant (uuid), jamais la personne consultée : le journal ne la retient pas. Demander à la personne qui tient ce compte ce qu''elle faisait ; un usage légitime (rentrée, import, vérification d''un fichier) se reconnaît vite. Sinon, suspendre le compte et prévenir les bibliothèques concernées. L''incident se referme seul après une fenêtre sans dépassement.'
         )
    INTO v;
  RETURN v;
END;
$function$;

COMMENT ON FUNCTION public.fn_healthcheck_consultations(integer, integer, integer, integer) IS
  'Sonde `consultations` de health-probe : comptes qui dépassent, dans la fenêtre, un seuil d''appels, de fiches ou de bibliothèques sur les fonctions nominatives. Lit private.consultations_nominatives, qui ne nomme pas les personnes consultées. service_role seul.';

REVOKE EXECUTE ON FUNCTION public.fn_healthcheck_consultations(integer, integer, integer, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_healthcheck_consultations(integer, integer, integer, integer) TO service_role;

-- ─── 4. La sonde des freins ────────────────────────────────────────────────
-- Seuils par défaut : 20 clés d'un même genre frappées en 15 minutes (une
-- attaque répartie sur beaucoup d'adresses ou d'IP), ou 3 clés d'un même genre
-- bloquées et encore frappées dans la fenêtre. Ni clé ni adresse dans le bilan :
-- les genres et les nombres suffisent à décider d'aller voir.
CREATE OR REPLACE FUNCTION public.fn_healthcheck_abus(
  p_fenetre_min integer DEFAULT 15,
  p_seuil_cles integer DEFAULT 20,
  p_seuil_bloquees integer DEFAULT 3)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v jsonb;
BEGIN
  IF p_fenetre_min IS NULL OR p_fenetre_min < 1 OR p_fenetre_min > 10080
     OR coalesce(p_seuil_cles, 0) < 1 OR coalesce(p_seuil_bloquees, 0) < 1 THEN
    RAISE EXCEPTION 'sonde abus : fenêtre ou seuil hors bornes' USING ERRCODE = '22023';
  END IF;

  WITH par_genre AS (
    SELECT r.kind,
           count(*)                                        AS cles_frappees,
           count(*) FILTER (WHERE r.blocked_until > now()) AS cles_bloquees,
           coalesce(sum(r.failure_count), 0)               AS frappes
      FROM public.auth_rate_limits r
     WHERE r.last_failure_at > now() - make_interval(mins => p_fenetre_min)
     GROUP BY r.kind
  )
  SELECT jsonb_build_object(
           'ok', NOT EXISTS (SELECT 1 FROM par_genre
                              WHERE cles_frappees >= p_seuil_cles OR cles_bloquees >= p_seuil_bloquees),
           'verifie_le', now(),
           'fenetre_min', p_fenetre_min,
           'seuils', jsonb_build_object('cles', p_seuil_cles, 'bloquees', p_seuil_bloquees),
           'freins_en_pic', coalesce((SELECT jsonb_agg(jsonb_build_object(
                 'genre', kind, 'cles_frappees', cles_frappees, 'frappes', frappes) ORDER BY cles_frappees DESC)
               FROM par_genre WHERE cles_frappees >= p_seuil_cles), '[]'::jsonb),
           'blocages_en_serie', coalesce((SELECT jsonb_agg(jsonb_build_object(
                 'genre', kind, 'cles_bloquees', cles_bloquees, 'frappes', frappes) ORDER BY cles_bloquees DESC)
               FROM par_genre WHERE cles_bloquees >= p_seuil_bloquees), '[]'::jsonb),
           'que_faire', 'Les freins tiennent : chaque clé dépassée est déjà refusée. L''alerte dit qu''on les éprouve. Genre ip ou email : essais de connexion (un genre email bloqué peut viser des comptes précis, qui ne peuvent plus se connecter pendant le blocage) ; register_* : inscriptions ; gazette_*, carto_ip, bug_ip : formulaires publics. Regarder les journaux de l''hébergeur sur la fenêtre. L''incident se referme seul après une fenêtre calme.'
         )
    INTO v;
  RETURN v;
END;
$function$;

COMMENT ON FUNCTION public.fn_healthcheck_abus(integer, integer, integer) IS
  'Sonde `abus` de health-probe : genres de freins (auth_rate_limits) qui dépassent, dans la fenêtre, un seuil de clés frappées ou bloquées. Ne rend ni clé ni adresse. service_role seul.';

REVOKE EXECUTE ON FUNCTION public.fn_healthcheck_abus(integer, integer, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_healthcheck_abus(integer, integer, integer) TO service_role;

-- ─── 5. La purge (RET-3 : 12 mois) ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_consultations_purger()
RETURNS integer
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_n integer;
BEGIN
  DELETE FROM private.consultations_nominatives WHERE le < now() - interval '12 months';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_consultations_purger() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_consultations_purger() TO service_role;

-- ─── 6. Le genre d'incident ────────────────────────────────────────────────
ALTER TABLE public.service_health_incidents
  DROP CONSTRAINT IF EXISTS service_health_incidents_kind_check;

ALTER TABLE public.service_health_incidents
  ADD CONSTRAINT service_health_incidents_kind_check
  CHECK (kind = ANY (ARRAY[
    'service',                -- sondes HTTP du parcours public
    'backup',                 -- temoin de vie des trois flux restic
    'notifications',          -- fn_healthcheck_notifications
    'ressources_numeriques',  -- fn_healthcheck_digital_resources
    'backup_snapshot',        -- instantane non atteste (20260828234500)
    'images_pins',            -- fn_healthcheck_images_pins
    'mail_transport',         -- fn_healthcheck_mail_transport (20260924180538)
    'deploiement',            -- fn_healthcheck_deploiement (20260925082749)
    'capas_sources',          -- sonde temoin des sources de capas (20260927130745)
    'ci_en_retard',           -- taches de la forge en attente ou en echec (20260928095045)
    'abus',                   -- fn_healthcheck_abus (cette migration)
    'consultations'           -- fn_healthcheck_consultations (cette migration)
  ]));

-- ─── Vérification : porte sur ce que CETTE migration fait ─────────────────
DO $verif$
DECLARE
  r record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_class WHERE oid = 'private.consultations_nominatives'::regclass AND relrowsecurity) THEN
    RAISE EXCEPTION 'RLS non activée sur private.consultations_nominatives';
  END IF;
  IF has_table_privilege('anon', 'private.consultations_nominatives', 'SELECT')
     OR has_table_privilege('authenticated', 'private.consultations_nominatives', 'SELECT')
     OR has_table_privilege('authenticated', 'private.consultations_nominatives', 'INSERT') THEN
    RAISE EXCEPTION 'le journal des consultations est lisible ou inscriptible hors service_role';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns
              WHERE table_schema = 'private' AND table_name = 'consultations_nominatives'
                AND column_name NOT IN ('id', 'le', 'par', 'fonction', 'library_id', 'nb')) THEN
    RAISE EXCEPTION 'le journal des consultations porte une colonne de trop';
  END IF;
  FOR r IN SELECT unnest(ARRAY[
             'private.fn_noter_consultation(text, uuid, integer)',
             'public.fn_healthcheck_consultations(integer, integer, integer, integer)',
             'public.fn_healthcheck_abus(integer, integer, integer)',
             'public.fn_consultations_purger()']) AS f
  LOOP
    IF has_function_privilege('anon', r.f, 'EXECUTE') OR has_function_privilege('authenticated', r.f, 'EXECUTE') THEN
      RAISE EXCEPTION '% reste exécutable hors service_role', r.f;
    END IF;
  END LOOP;
  FOR r IN SELECT unnest(ARRAY[
             'api.get_reader_roster(uuid)',
             'public.fn_network_admin_find_user_by_email(text)',
             'public.fn_painel_reader_other_memberships(uuid, uuid)']) AS f
  LOOP
    IF (SELECT provolatile FROM pg_proc WHERE oid = r.f::regprocedure) <> 'v' THEN
      RAISE EXCEPTION '% est restée en lecture seule : le journal n''y écrirait pas', r.f;
    END IF;
    IF has_function_privilege('anon', r.f, 'EXECUTE') OR NOT has_function_privilege('authenticated', r.f, 'EXECUTE') THEN
      RAISE EXCEPTION '% : droits d''exécution changés', r.f;
    END IF;
    IF position('fn_noter_consultation' IN pg_get_functiondef(r.f::regprocedure)) = 0 THEN
      RAISE EXCEPTION '% n''écrit pas au journal', r.f;
    END IF;
  END LOOP;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE conname = 'service_health_incidents_kind_check'
                    AND pg_get_constraintdef(oid) LIKE '%''abus''%'
                    AND pg_get_constraintdef(oid) LIKE '%''consultations''%'
                    AND pg_get_constraintdef(oid) LIKE '%ci_en_retard%') THEN
    RAISE EXCEPTION 'la CHECK des incidents ignore abus ou consultations (ou a perdu un kind)';
  END IF;
END $verif$;

COMMIT;
