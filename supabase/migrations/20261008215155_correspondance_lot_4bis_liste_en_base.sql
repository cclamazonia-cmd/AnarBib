-- =====================================================================
-- AnarBib — G19 lot 4 bis : la liste des fils est calculée en base
-- Date    : 2026-10-08
-- Ref     : backlog v34 G19 ; constat de la session voisine « Mécanismes de
--           communication » (08/10, relecture des lots 1-2 demandée par Xavier).
--
-- Le constat : l'onglet lisait au plus 200 participations triées par identité
-- de fil (ordre de création, pas d'activité), puis TOUS leurs messages sans
-- limite — plafonnés par max_rows de PostgREST. Au-delà, les messages les plus
-- récents manquaient : dernier message et non-lus faux, et un fil actif mais
-- ancien pouvait sortir des 200.
--
-- Le remède : une RPC qui rend la liste calculée en base, par fil — sujet,
-- dernière activité, les autres bibliothèques, le dernier message (extrait,
-- langue, bibliothèque), le nombre de non-lus d'après la dernière lecture de
-- la personne — triée par dernière activité. L'écran ne lit les messages d'un
-- fil qu'à son ouverture (politique RLS du lot 1, un fil à la fois).
--
-- Garde : la même que les autres RPC du lot 1 — coordination active de la
-- bibliothèque (fn_correspondance_coordonne), sinon 42501 not_coordinator.
-- DEFINER (lit les quatre tables), STABLE, search_path figé ; fermée à anon.
-- Suite : tests/sql/correspondance_lot1_tests.sql (T15).
-- =====================================================================

CREATE OR REPLACE FUNCTION api.fn_correspondance_fils(p_library_id uuid)
RETURNS TABLE (
  conversation_id     bigint,
  subject             text,
  last_message_at     timestamptz,
  archived_at         timestamptz,
  autres              uuid[],
  dernier_id          bigint,
  dernier_library_id  uuid,
  dernier_body        text,
  dernier_lang        text,
  dernier_created_at  timestamptz,
  non_lus             integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF NOT public.fn_correspondance_coordonne(p_library_id) THEN
    RAISE EXCEPTION 'not_coordinator' USING errcode = '42501', hint = 'error.correspondance.not_coordinator';
  END IF;
  RETURN QUERY
  SELECT c.id,
         c.subject,
         c.last_message_at,
         p.archived_at,
         COALESCE((SELECT array_agg(q.library_id ORDER BY q.joined_at, q.library_id)
                     FROM public.library_conversation_participants q
                    WHERE q.conversation_id = c.id AND q.library_id <> p_library_id), '{}'::uuid[]),
         d.id,
         d.library_id,
         left(d.body, 300),
         d.lang,
         d.created_at,
         (SELECT count(*)::integer FROM public.library_messages m
           WHERE m.conversation_id = c.id
             AND m.id > COALESCE((SELECT r.last_read_message_id FROM public.library_conversation_reads r
                                   WHERE r.conversation_id = c.id AND r.user_id = (SELECT auth.uid())), 0))
    FROM public.library_conversation_participants p
    JOIN public.library_conversations c ON c.id = p.conversation_id
    LEFT JOIN LATERAL (SELECT m.id, m.library_id, m.body, m.lang, m.created_at
                         FROM public.library_messages m
                        WHERE m.conversation_id = c.id
                        ORDER BY m.id DESC LIMIT 1) d ON true
   WHERE p.library_id = p_library_id
   ORDER BY c.last_message_at DESC, c.id DESC
   LIMIT 500;
END;
$$;
REVOKE EXECUTE ON FUNCTION api.fn_correspondance_fils(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION api.fn_correspondance_fils(uuid) TO authenticated, service_role;
COMMENT ON FUNCTION api.fn_correspondance_fils(uuid) IS
  'G19 lot 4 bis (08/10/2026) : la liste des fils d''une bibliothèque, calculée en base — sujet, dernière activité, autres '
  'bibliothèques, dernier message (extrait 300), non-lus pour la personne appelante ; coordination active seulement '
  '(42501 not_coordinator) ; 500 fils au plus, par dernière activité.';

DO $g19l4b_verif$
DECLARE v_e text := '';
BEGIN
  IF has_function_privilege('anon', 'api.fn_correspondance_fils(uuid)', 'EXECUTE') THEN v_e := v_e || ' anon-execute'; END IF;
  IF NOT has_function_privilege('authenticated', 'api.fn_correspondance_fils(uuid)', 'EXECUTE') THEN v_e := v_e || ' authenticated-sans-execute'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                  WHERE n.nspname = 'api' AND p.proname = 'fn_correspondance_fils' AND p.prosecdef
                    AND coalesce(p.proconfig::text, '') LIKE '%search_path%') THEN v_e := v_e || ' definer-search_path'; END IF;
  IF v_e <> '' THEN RAISE EXCEPTION 'G19 lot 4 bis : vérification en échec :%', v_e; END IF;
  RAISE NOTICE 'G19 lot 4 bis : vérifications OK — api.fn_correspondance_fils, DEFINER fermée à anon';
END
$g19l4b_verif$;

NOTIFY pgrst, 'reload schema';
