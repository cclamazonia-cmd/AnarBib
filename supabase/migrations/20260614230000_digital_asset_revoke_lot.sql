-- =========================================================================
-- Chantier « gestion des fichiers numériques », ENTRÉE (c) — dé-vérification.
--
-- La promotion/attache (entrées a et b) crée un `digital_asset` à
-- `rights_status='public_domain_confirmed'` + `is_public=true` dans un bucket
-- PUBLIC : c'est une revendication de droits à portée juridique. Une erreur doit
-- pouvoir être ANNULÉE (point 4). Comme le bucket est public au niveau storage,
-- un simple changement de flag ne retire PAS l'accès par URL → la révocation
-- supprime la ligne `digital_asset`, délie un éventuel `received_asset` (qui
-- retourne en file d'attache), et l'EF `revoke-digital-asset` retire le FICHIER
-- physique — mais SEULEMENT s'il n'est référencé nulle part ailleurs
-- (`book_digital_resources` du catalogue ou un autre `digital_asset` ; cas des
-- assets d'entrée (a) qui PARTAGENT le fichier avec la couche catalogue → on ne
-- supprime alors que la ligne, pas le fichier, pour ne pas casser le lecteur).
--
--   1. fn_list_verified_digital_assets(library) : audit des assets d'une biblio.
--   2. fn_revoke_digital_asset_record(asset)     : délie + supprime la ligne,
--      renvoie si le fichier est devenu orphelin (l'EF le retire alors). Gardée coordenador.
-- =========================================================================
BEGIN;

-- ─── 1. Audit : digital_assets des livres de la biblio ──────────────────────
CREATE OR REPLACE FUNCTION public.fn_list_verified_digital_assets(p_library_id uuid)
RETURNS TABLE (
  asset_id      bigint,
  book_id       bigint,
  book_title    text,
  asset_kind    text,
  rights_status text,
  is_public     boolean,
  bucket_name   text,
  object_path   text,
  source_name   text,
  verified_at   timestamptz,
  verified_by   uuid,
  from_received boolean,
  created_at    timestamptz,
  notes         text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, ingest, auth, pg_catalog
AS $$
BEGIN
  IF p_library_id IS NULL THEN RAISE EXCEPTION 'library_id obrigatorio.'; END IF;
  IF NOT (
    EXISTS (SELECT 1 FROM public.user_library_memberships m
             WHERE m.user_id = auth.uid() AND m.library_id = p_library_id
               AND m.status = 'active' AND m.role = 'coordenador')
    OR public.fn_caller_is_network_admin()
  ) THEN RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.'; END IF;

  RETURN QUERY
    SELECT da.id, da.book_id, b.titulo, da.asset_kind, da.rights_status, da.is_public,
           da.bucket_name, da.object_path, da.source_name, da.verified_at, da.verified_by,
           EXISTS (SELECT 1 FROM ingest.partner_catalog_received_assets ra
                    WHERE ra.attached_digital_asset_id = da.id) AS from_received,
           da.created_at, da.notes
      FROM public.digital_assets da
      JOIN public.books b ON b.id = da.book_id
     WHERE EXISTS (SELECT 1 FROM public.book_holdings h
                    WHERE h.book_id = da.book_id AND h.library_id = p_library_id)
     ORDER BY da.created_at DESC, da.id DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_list_verified_digital_assets(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_list_verified_digital_assets(uuid) TO authenticated;

COMMENT ON FUNCTION public.fn_list_verified_digital_assets(uuid) IS
  'Chantier fichiers numériques (c). Audit des digital_assets des livres d''une biblio (provenance, '
  'verified_by/at, origine reçue). Pour la dé-vérification. Reservé coordenador / admin réseau.';

-- ─── 2. Révocation : supprime la ligne + délie le reçu + verdict d'orphelin ──
CREATE OR REPLACE FUNCTION public.fn_revoke_digital_asset_record(p_asset_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, ingest, auth, pg_catalog
AS $$
DECLARE
  da          public.digital_assets%rowtype;
  v_authorized boolean;
  v_ra_id     bigint;
  v_orphaned  boolean;
BEGIN
  IF p_asset_id IS NULL THEN RAISE EXCEPTION 'asset_id obrigatorio.'; END IF;

  SELECT * INTO da FROM public.digital_assets WHERE id = p_asset_id FOR UPDATE;
  IF NOT FOUND THEN
    -- Idempotent : déjà supprimé.
    RETURN jsonb_build_object('ok', true, 'asset_id', p_asset_id, 'deleted', false,
      'reason', 'already_gone', 'file_orphaned', false);
  END IF;

  -- Garde : coordenador d'une biblio détentrice du livre (ou admin réseau).
  SELECT (
    EXISTS (SELECT 1 FROM public.book_holdings h
              JOIN public.user_library_memberships m ON m.library_id = h.library_id
             WHERE h.book_id = da.book_id AND m.user_id = auth.uid()
               AND m.status = 'active' AND m.role = 'coordenador')
    OR public.fn_caller_is_network_admin()
  ) INTO v_authorized;
  IF NOT v_authorized THEN RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca detentora.'; END IF;

  -- Délie un éventuel fichier reçu : il retourne en file d'attache (ré-attachable).
  UPDATE ingest.partner_catalog_received_assets
     SET attached_digital_asset_id = NULL, deposit_status = 'deposited'
   WHERE attached_digital_asset_id = p_asset_id
   RETURNING id INTO v_ra_id;

  DELETE FROM public.digital_assets WHERE id = p_asset_id;

  -- Le fichier est-il devenu orphelin ? (plus aucun digital_asset NI book_digital_resources
  -- ne le référence) → l'EF pourra le retirer du bucket. Sinon (partagé avec le catalogue,
  -- cas entrée (a)), on garde le fichier pour ne pas casser le lecteur.
  v_orphaned := (
    da.bucket_name IS NOT NULL AND da.object_path IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM public.digital_assets d2
                     WHERE d2.bucket_name = da.bucket_name AND d2.object_path = da.object_path)
    AND NOT EXISTS (SELECT 1 FROM public.book_digital_resources r
                     WHERE r.storage_bucket = da.bucket_name AND r.storage_path = da.object_path)
  );

  RETURN jsonb_build_object('ok', true, 'asset_id', p_asset_id, 'deleted', true,
    'book_id', da.book_id, 'unlinked_received_asset', v_ra_id,
    'bucket_name', da.bucket_name, 'object_path', da.object_path,
    'file_orphaned', v_orphaned);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_revoke_digital_asset_record(bigint) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_revoke_digital_asset_record(bigint) TO authenticated, service_role;

COMMENT ON FUNCTION public.fn_revoke_digital_asset_record(bigint) IS
  'Chantier fichiers numériques (c). Dé-vérifie un digital_asset : supprime la ligne, délie un '
  'éventuel received_asset (retour en file d''attache), et renvoie file_orphaned=true si le fichier '
  'n''est plus référencé (l''EF revoke-digital-asset le retire alors du bucket ; sinon il est partagé '
  'avec le catalogue et conservé). Idempotent. Gardée coordenador de la biblio détentrice.';

-- ─── Vérification ───────────────────────────────────────────────────────────
DO $verify$
DECLARE v_fns int;
BEGIN
  SELECT count(*) INTO v_fns FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public'
      AND p.proname IN ('fn_list_verified_digital_assets','fn_revoke_digital_asset_record');
  IF v_fns <> 2 THEN RAISE EXCEPTION 'verify (c): attendu 2 fn, trouvé %', v_fns; END IF;
  -- record ne doit PAS être ouvert à anon.
  IF has_function_privilege('anon', 'public.fn_revoke_digital_asset_record(bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'verify (c): fn_revoke_digital_asset_record ne doit pas être exécutable par anon';
  END IF;
  RAISE NOTICE 'chantier fichiers numériques (c) OK : audit + dé-vérification.';
END;
$verify$;

COMMIT;

-- =========================================================================
-- Rollback ciblé :
--   DROP FUNCTION IF EXISTS public.fn_revoke_digital_asset_record(bigint);
--   DROP FUNCTION IF EXISTS public.fn_list_verified_digital_assets(uuid);
-- =========================================================================
