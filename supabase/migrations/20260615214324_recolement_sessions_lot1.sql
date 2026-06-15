-- =========================================================================
-- Paquet RECOLEMENT-B1 — Récolement persisté (sessions + scans + RPC)
-- =========================================================================
-- Date     : 2026-06-15
-- Chantier : MOBILE Paquet 4 — aide au récolement (scan), option B (persisté)
-- Auteur   : AnarBib
-- Session  : Perf UX + nettoyage advisors sécurité
--
-- OBJET
--   Récolement d'inventaire par scan des étiquettes QR d'exemplaires (le QR
--   encode `?ex=<exemplar_id>`). Persisté → reprenable sur plusieurs jours,
--   auditable, multi-appareils. Le·la bibliothécaire scanne ; on compare au
--   fonds de la biblio et on sort présents / manquants / intrus.
--
-- MODÈLE
--   recolement_sessions : une campagne de récolement (biblio, qui, statut).
--   recolement_scans     : un exemplaire vu dans une session (unique par paire).
--   RPC SECDEF staff-gated : start / scan / finish (rapport+clôture) / open_sessions.
--   Écritures via RPC uniquement ; RLS staff en lecture sur les 2 tables.
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- Tables
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.recolement_sessions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  library_id  uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,
  started_by  uuid,
  started_at  timestamptz NOT NULL DEFAULT now(),
  closed_at   timestamptz,
  status      text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  note        text,
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS recolement_sessions_library_idx ON public.recolement_sessions(library_id, status);

CREATE TABLE IF NOT EXISTS public.recolement_scans (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id  uuid NOT NULL REFERENCES public.recolement_sessions(id) ON DELETE CASCADE,
  exemplar_id bigint NOT NULL,           -- pas de FK : on enregistre aussi un scan intrus/inconnu
  scanned_by  uuid,
  scanned_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (session_id, exemplar_id)
);
CREATE INDEX IF NOT EXISTS recolement_scans_session_idx ON public.recolement_scans(session_id);

-- Grants : lecture via RLS (authenticated), écritures via RPC SECDEF uniquement.
REVOKE ALL ON public.recolement_sessions FROM anon, authenticated;
REVOKE ALL ON public.recolement_scans     FROM anon, authenticated;
GRANT SELECT ON public.recolement_sessions TO authenticated;
GRANT SELECT ON public.recolement_scans     TO authenticated;
GRANT ALL ON public.recolement_sessions TO service_role;
GRANT ALL ON public.recolement_scans     TO service_role;

ALTER TABLE public.recolement_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recolement_scans     ENABLE ROW LEVEL SECURITY;

CREATE POLICY recolement_sessions_select_staff ON public.recolement_sessions
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid() AND m.library_id = recolement_sessions.library_id
      AND m.status = 'active' AND m.role IN ('librarian', 'coordenador')
  ));

CREATE POLICY recolement_scans_select_staff ON public.recolement_scans
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.recolement_sessions rs
    JOIN public.user_library_memberships m ON m.library_id = rs.library_id
    WHERE rs.id = recolement_scans.session_id
      AND m.user_id = auth.uid() AND m.status = 'active' AND m.role IN ('librarian', 'coordenador')
  ));

-- -------------------------------------------------------------------------
-- Helper interne : l'appelant est-il staff actif de la biblio ?
-- (non exposé — appelé par les RPC ; pas de GRANT à anon/authenticated)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.fn_recolement_is_staff(p_uid uuid, p_library_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_catalog
AS $fn_staff$
  SELECT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = p_uid AND m.library_id = p_library_id
      AND m.status = 'active' AND m.role IN ('librarian', 'coordenador')
  );
$fn_staff$;
REVOKE EXECUTE ON FUNCTION private.fn_recolement_is_staff(uuid, uuid) FROM PUBLIC, anon, authenticated;

-- -------------------------------------------------------------------------
-- RPC : démarrer une session
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.recolement_start(p_library_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog
AS $fn_start$
DECLARE v_uid uuid := auth.uid(); v_sid uuid; v_acervo int;
BEGIN
  IF v_uid IS NULL THEN RETURN jsonb_build_object('ok', false, 'reason', 'not_authenticated'); END IF;
  IF NOT private.fn_recolement_is_staff(v_uid, p_library_id) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_staff_of_library');
  END IF;
  INSERT INTO public.recolement_sessions (library_id, started_by)
    VALUES (p_library_id, v_uid) RETURNING id INTO v_sid;
  SELECT count(*) INTO v_acervo FROM public.exemplares WHERE library_id = p_library_id;
  RETURN jsonb_build_object('ok', true, 'session_id', v_sid, 'acervo_count', v_acervo);
END;
$fn_start$;
REVOKE EXECUTE ON FUNCTION api.recolement_start(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION api.recolement_start(uuid) TO authenticated;

-- -------------------------------------------------------------------------
-- RPC : enregistrer un scan (idempotent par paire session/exemplaire)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.recolement_scan(p_session_id uuid, p_exemplar_id bigint)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog
AS $fn_scan$
DECLARE
  v_uid uuid := auth.uid();
  v_lib uuid; v_status text;
  v_ex public.exemplares%ROWTYPE;
  v_title text; v_in_acervo boolean;
  v_rows int; v_count int;
BEGIN
  IF v_uid IS NULL THEN RETURN jsonb_build_object('ok', false, 'reason', 'not_authenticated'); END IF;
  SELECT library_id, status INTO v_lib, v_status FROM public.recolement_sessions WHERE id = p_session_id;
  IF v_lib IS NULL THEN RETURN jsonb_build_object('ok', false, 'reason', 'session_not_found'); END IF;
  IF NOT private.fn_recolement_is_staff(v_uid, v_lib) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_staff_of_library');
  END IF;
  IF v_status <> 'open' THEN RETURN jsonb_build_object('ok', false, 'reason', 'session_closed'); END IF;

  INSERT INTO public.recolement_scans (session_id, exemplar_id, scanned_by)
    VALUES (p_session_id, p_exemplar_id, v_uid)
    ON CONFLICT (session_id, exemplar_id) DO NOTHING;
  GET DIAGNOSTICS v_rows = ROW_COUNT;

  SELECT * INTO v_ex FROM public.exemplares WHERE id = p_exemplar_id;
  v_in_acervo := (v_ex.id IS NOT NULL AND v_ex.library_id = v_lib);
  IF v_ex.holding_id IS NOT NULL THEN
    SELECT b.titulo INTO v_title FROM public.book_holdings h JOIN public.books b ON b.id = h.book_id WHERE h.id = v_ex.holding_id;
  END IF;
  SELECT count(*) INTO v_count FROM public.recolement_scans WHERE session_id = p_session_id;

  RETURN jsonb_build_object(
    'ok', true,
    'already_scanned', (v_rows = 0),
    'in_acervo', v_in_acervo,
    'exemplar_id', p_exemplar_id,
    'tombo', v_ex.tombo,
    'title', v_title,
    'scanned_count', v_count
  );
END;
$fn_scan$;
REVOKE EXECUTE ON FUNCTION api.recolement_scan(uuid, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION api.recolement_scan(uuid, bigint) TO authenticated;

-- -------------------------------------------------------------------------
-- RPC : clôturer + rapport (présents / manquants / intrus)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.recolement_finish(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog
AS $fn_finish$
DECLARE
  v_uid uuid := auth.uid();
  v_lib uuid;
  v_acervo int; v_scanned int; v_present int; v_intrus int;
  v_missing jsonb; v_intrus_list jsonb;
BEGIN
  IF v_uid IS NULL THEN RETURN jsonb_build_object('ok', false, 'reason', 'not_authenticated'); END IF;
  SELECT library_id INTO v_lib FROM public.recolement_sessions WHERE id = p_session_id;
  IF v_lib IS NULL THEN RETURN jsonb_build_object('ok', false, 'reason', 'session_not_found'); END IF;
  IF NOT private.fn_recolement_is_staff(v_uid, v_lib) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_staff_of_library');
  END IF;

  UPDATE public.recolement_sessions SET status = 'closed', closed_at = now(), updated_at = now()
    WHERE id = p_session_id AND status = 'open';

  SELECT count(*) INTO v_acervo  FROM public.exemplares WHERE library_id = v_lib;
  SELECT count(*) INTO v_scanned FROM public.recolement_scans WHERE session_id = p_session_id;
  SELECT count(*) INTO v_present FROM public.recolement_scans s
    WHERE s.session_id = p_session_id
      AND EXISTS (SELECT 1 FROM public.exemplares e WHERE e.id = s.exemplar_id AND e.library_id = v_lib);
  v_intrus := v_scanned - v_present;

  -- Manquants : fonds non scanné (sortie actionnable).
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'exemplar_id', e.id, 'tombo', e.tombo, 'shelf', e.shelf_location,
           'title', (SELECT b.titulo FROM public.book_holdings h JOIN public.books b ON b.id = h.book_id WHERE h.id = e.holding_id)
         ) ORDER BY e.tombo), '[]'::jsonb)
    INTO v_missing
    FROM public.exemplares e
    WHERE e.library_id = v_lib
      AND NOT EXISTS (SELECT 1 FROM public.recolement_scans s WHERE s.session_id = p_session_id AND s.exemplar_id = e.id);

  -- Intrus : scanné mais hors fonds (exemplaire d'une autre biblio / inconnu).
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'exemplar_id', s.exemplar_id,
           'tombo', (SELECT tombo FROM public.exemplares WHERE id = s.exemplar_id),
           'lib', (SELECT l.slug FROM public.exemplares e2 JOIN public.libraries l ON l.id = e2.library_id WHERE e2.id = s.exemplar_id)
         )), '[]'::jsonb)
    INTO v_intrus_list
    FROM public.recolement_scans s
    WHERE s.session_id = p_session_id
      AND NOT EXISTS (SELECT 1 FROM public.exemplares e WHERE e.id = s.exemplar_id AND e.library_id = v_lib);

  RETURN jsonb_build_object(
    'ok', true,
    'acervo_count', v_acervo,
    'scanned_count', v_scanned,
    'present_count', v_present,
    'missing_count', v_acervo - v_present,
    'intrus_count', v_intrus,
    'missing', v_missing,
    'intrus', v_intrus_list
  );
END;
$fn_finish$;
REVOKE EXECUTE ON FUNCTION api.recolement_finish(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION api.recolement_finish(uuid) TO authenticated;

-- -------------------------------------------------------------------------
-- RPC : sessions ouvertes d'une biblio (reprise)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.recolement_open_sessions(p_library_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog
AS $fn_list$
DECLARE v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN RETURN jsonb_build_object('ok', false, 'reason', 'not_authenticated'); END IF;
  IF NOT private.fn_recolement_is_staff(v_uid, p_library_id) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_staff_of_library');
  END IF;
  RETURN jsonb_build_object('ok', true, 'sessions', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
             'session_id', rs.id, 'started_at', rs.started_at, 'note', rs.note,
             'scanned_count', (SELECT count(*) FROM public.recolement_scans s WHERE s.session_id = rs.id)
           ) ORDER BY rs.started_at DESC)
    FROM public.recolement_sessions rs
    WHERE rs.library_id = p_library_id AND rs.status = 'open'
  ), '[]'::jsonb));
END;
$fn_list$;
REVOKE EXECUTE ON FUNCTION api.recolement_open_sessions(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION api.recolement_open_sessions(uuid) TO authenticated;

-- -------------------------------------------------------------------------
-- Vérification : flux complet (staff simulé) start → scan → finish, puis NETTOYAGE.
-- -------------------------------------------------------------------------
DO $verify$
DECLARE
  v_uid uuid; v_lib uuid; v_ex bigint;
  r_start jsonb; r_scan1 jsonb; r_scan2 jsonb; r_finish jsonb; v_sid uuid;
BEGIN
  SELECT m.user_id, m.library_id INTO v_uid, v_lib
  FROM public.user_library_memberships m
  WHERE m.status = 'active' AND m.role IN ('librarian', 'coordenador')
    AND EXISTS (SELECT 1 FROM public.exemplares e WHERE e.library_id = m.library_id)
  LIMIT 1;
  IF v_uid IS NULL THEN RAISE NOTICE 'RECOLEMENT-B1 : pas de staff+acervo pour le test.'; RETURN; END IF;
  SELECT id INTO v_ex FROM public.exemplares WHERE library_id = v_lib LIMIT 1;

  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  r_start  := api.recolement_start(v_lib);
  v_sid    := (r_start->>'session_id')::uuid;
  r_scan1  := api.recolement_scan(v_sid, v_ex);            -- exemplaire réel → in_acervo true
  r_scan2  := api.recolement_scan(v_sid, 999999999::bigint); -- intrus inconnu → in_acervo false
  r_finish := api.recolement_finish(v_sid);
  RESET ROLE;

  IF (r_start->>'ok') <> 'true' OR v_sid IS NULL THEN RAISE EXCEPTION 'Verif: start KO %. Rollback.', r_start; END IF;
  IF (r_scan1->>'in_acervo') <> 'true' THEN RAISE EXCEPTION 'Verif: scan exemplaire reel attendu in_acervo. Rollback. %', r_scan1; END IF;
  IF (r_scan2->>'in_acervo') <> 'false' THEN RAISE EXCEPTION 'Verif: scan intrus attendu hors acervo. Rollback. %', r_scan2; END IF;
  IF (r_finish->>'present_count')::int < 1 OR (r_finish->>'intrus_count')::int < 1 THEN
    RAISE EXCEPTION 'Verif: rapport incoherent %. Rollback.', r_finish;
  END IF;

  -- Nettoyage des données de test (cascade sur les scans).
  DELETE FROM public.recolement_sessions WHERE id = v_sid;
  RAISE NOTICE 'RECOLEMENT-B1 OK : start/scan/finish vérifiés (present=%, intrus=%), session de test supprimée.',
    (r_finish->>'present_count'), (r_finish->>'intrus_count');
END;
$verify$;

NOTIFY pgrst, 'reload schema';

COMMIT;
