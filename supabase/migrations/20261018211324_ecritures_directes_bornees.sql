-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — écritures directes bornées, lectures au plus juste
-- (17/10/2026)
-- Auteur  : Xavier (CCLA) + Claude
-- Session : Modele de menace
--
-- RÈGLES POSÉES
--
-- 1. profiles : les colonnes de gouvernance ne se changent que par leur
--    procédure (fonctions DEFINER, clé de service), jamais par un UPDATE
--    direct sous authenticated : gel (is_restricted, restricted_*),
--    parcours d'inscription (solicitante_state, signup_intent*), consentement
--    à la Lettre (consent_lettre*, double opt-in), is_librarian, identifiants.
--    Trigger BEFORE UPDATE tg_profiles_colonnes_de_gouvernance. Les champs que
--    le front écrit (nom, prénom, téléphone, genre, organisation, adresse,
--    langue, courriel par l'équipe, consent_email, mot de passe changé)
--    restent libres — relevé du front le 17/10.
--
-- 2. book_reading_notes : une note publiée se lit sans l'identifiant de son
--    auteur·rice (le pseudonyme suffit) — api.reading_notes_published_v1,
--    qui rend is_mine à la place. La table ne rend plus en direct que ses
--    propres notes et, à l'équipe, celles de sa bibliothèque (modération).
--
-- 3. reservas_v2 / reserva_linhas_v2 : plus d'écriture directe ; toutes les
--    écritures passent par les fonctions DEFINER de la circulation (vérifié
--    le 17/10 : aucune fonction INVOKER ouverte à authenticated ne les écrit,
--    le front ne les écrit pas).
--
-- 4. oai_opening_requests : lisible par qui délibère (coordinations, qui
--    votent ; administration du réseau) et par l'équipe de la bibliothèque
--    demandeuse — plus par tout compte inscrit.
--
-- 5. network_administrators : removal_reason n'est plus lisible en direct.
--    Les vues security_invoker qui listent l'administration n'utilisent pas
--    cette colonne.
--
-- Tests : tests/sql/ecritures_directes_bornees_tests.sql.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- ─── 1. profiles : colonnes de gouvernance ─────────────────────────────────
CREATE OR REPLACE FUNCTION public.tg_profiles_colonnes_de_gouvernance()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  -- Les procédures (DEFINER, clé de service) passent ; seul l'UPDATE direct
  -- d'un compte est borné.
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.public_id IS DISTINCT FROM OLD.public_id
     OR NEW.created_at IS DISTINCT FROM OLD.created_at
     OR NEW.is_librarian IS DISTINCT FROM OLD.is_librarian
     OR NEW.is_restricted IS DISTINCT FROM OLD.is_restricted
     OR NEW.restricted_since IS DISTINCT FROM OLD.restricted_since
     OR NEW.restricted_reason IS DISTINCT FROM OLD.restricted_reason
     OR NEW.restricted_by IS DISTINCT FROM OLD.restricted_by
     OR NEW.solicitante_state IS DISTINCT FROM OLD.solicitante_state
     OR NEW.signup_intent IS DISTINCT FROM OLD.signup_intent
     OR NEW.signup_intent_metadata IS DISTINCT FROM OLD.signup_intent_metadata
     OR NEW.signup_intent_set_at IS DISTINCT FROM OLD.signup_intent_set_at
     OR NEW.consent_lettre IS DISTINCT FROM OLD.consent_lettre
     OR NEW.consent_lettre_at IS DISTINCT FROM OLD.consent_lettre_at
     OR NEW.consent_lettre_pending_at IS DISTINCT FROM OLD.consent_lettre_pending_at THEN
    RAISE EXCEPTION 'Ce champ du profil se modifie par sa procédure.'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.tg_profiles_colonnes_de_gouvernance() FROM PUBLIC, anon, authenticated, service_role;
COMMENT ON FUNCTION public.tg_profiles_colonnes_de_gouvernance() IS
  'BEFORE UPDATE sur profiles : sous authenticated/anon, refuse tout changement des colonnes de gouvernance (gel, inscription, consentement Lettre, is_librarian, identifiants). Les procédures DEFINER et la clé de service passent (17/10/2026).';

DROP TRIGGER IF EXISTS trg_profiles_colonnes_de_gouvernance ON public.profiles;
CREATE TRIGGER trg_profiles_colonnes_de_gouvernance
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.tg_profiles_colonnes_de_gouvernance();

-- ─── 2. book_reading_notes : les notes publiées, sans l'auteur·rice ────────
CREATE OR REPLACE FUNCTION api.reading_notes_published_v1(p_work_id bigint)
RETURNS TABLE (
  id bigint,
  author_pseudonym text,
  body text,
  language text,
  created_at timestamptz,
  edited boolean,
  status text,
  is_mine boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  select n.id, n.author_pseudonym, n.body, n.language, n.created_at, n.edited, n.status,
         (n.author_user_id = (select auth.uid())) as is_mine
    from public.book_reading_notes n
   where n.work_id = p_work_id
     and n.status = 'published'
     and (select auth.uid()) is not null
   order by n.created_at desc;
$function$;

REVOKE EXECUTE ON FUNCTION api.reading_notes_published_v1(bigint) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION api.reading_notes_published_v1(bigint) TO authenticated;
COMMENT ON FUNCTION api.reading_notes_published_v1(bigint) IS
  'Notes de lecture publiées d''une œuvre, sans l''identifiant de leur auteur·rice : pseudonyme, texte, date, et is_mine pour l''appelant. Réservé aux comptes connectés, comme la lecture directe qu''elle remplace (17/10/2026).';

DROP POLICY IF EXISTS reading_notes_select ON public.book_reading_notes;
CREATE POLICY reading_notes_select ON public.book_reading_notes
  FOR SELECT TO authenticated
  USING (author_user_id = (SELECT auth.uid())
         OR public.user_can_act_as_staff_on_library(origin_library_id));

-- Le signalement d'une note publiée ne dépend plus de sa lecture directe.
CREATE OR REPLACE FUNCTION private.fn_note_de_lecture_publiee(p_note_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  select exists (select 1 from public.book_reading_notes n
                  where n.id = p_note_id and n.status = 'published');
$function$;

REVOKE EXECUTE ON FUNCTION private.fn_note_de_lecture_publiee(bigint) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.fn_note_de_lecture_publiee(bigint) TO authenticated;
COMMENT ON FUNCTION private.fn_note_de_lecture_publiee(bigint) IS
  'Vrai si la note existe et est publiée. Lue par la politique de signalement (reading_note_reports_insert), qui ne peut plus lire la note en direct (17/10/2026).';

DROP POLICY IF EXISTS reading_note_reports_insert ON public.book_reading_note_reports;
CREATE POLICY reading_note_reports_insert ON public.book_reading_note_reports
  FOR INSERT TO authenticated
  WITH CHECK (reporter_user_id = (SELECT auth.uid())
              AND private.fn_note_de_lecture_publiee(note_id));

-- ─── 3. Réservations : écritures par les fonctions seulement ───────────────
DROP POLICY IF EXISTS reservas_v2_insert_own ON public.reservas_v2;
DROP POLICY IF EXISTS reservas_v2_update_consolidated ON public.reservas_v2;
DROP POLICY IF EXISTS reserva_linhas_v2_update_consolidated ON public.reserva_linhas_v2;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.reservas_v2 FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.reserva_linhas_v2 FROM PUBLIC, anon, authenticated;

-- ─── 4. Ouvertures OAI : lues par qui délibère ─────────────────────────────
DROP POLICY IF EXISTS oai_opening_requests_select_authenticated ON public.oai_opening_requests;
DROP POLICY IF EXISTS oai_opening_requests_select_deliberation ON public.oai_opening_requests;
CREATE POLICY oai_opening_requests_select_deliberation ON public.oai_opening_requests
  FOR SELECT TO authenticated
  USING (
    (SELECT public.fn_caller_is_network_admin())
    OR library_id = ANY ((SELECT public.fn_caller_staff_library_ids())::uuid[])
    OR (SELECT EXISTS (
          SELECT 1 FROM public.user_library_memberships m
           WHERE m.user_id = (SELECT auth.uid()) AND m.status = 'active' AND m.role = 'coordenador'))
  );

-- ─── 5. network_administrators : removal_reason hors lecture directe ───────
DO $colonnes$
DECLARE
  v_cols text;
BEGIN
  SELECT string_agg(quote_ident(column_name), ', ' ORDER BY ordinal_position) INTO v_cols
    FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'network_administrators'
     AND column_name <> 'removal_reason';
  REVOKE SELECT ON public.network_administrators FROM anon, authenticated;
  EXECUTE format('GRANT SELECT (%s) ON public.network_administrators TO authenticated', v_cols);
END $colonnes$;

-- ─── Vérifications ─────────────────────────────────────────────────────────
DO $verif$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger
                  WHERE tgrelid = 'public.profiles'::regclass
                    AND tgname = 'trg_profiles_colonnes_de_gouvernance') THEN
    RAISE EXCEPTION 'écritures bornées : trigger de profiles absent';
  END IF;
  IF has_function_privilege('anon', 'api.reading_notes_published_v1(bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'écritures bornées : api.reading_notes_published_v1 ouverte à anon';
  END IF;
  IF has_table_privilege('authenticated', 'public.reservas_v2', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.reservas_v2', 'INSERT')
     OR has_table_privilege('authenticated', 'public.reserva_linhas_v2', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.reserva_linhas_v2', 'INSERT') THEN
    RAISE EXCEPTION 'écritures bornées : les réservations restent inscriptibles en direct';
  END IF;
  IF has_column_privilege('authenticated', 'public.network_administrators', 'removal_reason', 'SELECT') THEN
    RAISE EXCEPTION 'écritures bornées : removal_reason reste lisible';
  END IF;
  IF NOT has_column_privilege('authenticated', 'public.network_administrators', 'last_seen_at', 'SELECT') THEN
    RAISE EXCEPTION 'écritures bornées : une colonne utile n''est plus lisible';
  END IF;
END $verif$;

NOTIFY pgrst, 'reload schema';

COMMIT;
