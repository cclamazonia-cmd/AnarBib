-- =========================================================================
-- Paquet « Lecteur ePub » — backend (type ePub, casiers, reprise de lecture)
-- =========================================================================
-- Date     : 2026-06-17
-- Chantier : Lecteur ePub (intégration editora-ccla → AnarBib, page /ler)
-- Auteur   : Claude (assistant·e)
-- Session  : Lecteur ePub — intégration AnarBib/CCLA
--
-- Contenu :
--   1) resource_type 'epub' autorisé sur public.book_digital_resources
--      (D-EPUB-A : valeur unique ; access_scope/usage_type existants réutilisés —
--       'leitura_online' couvre déjà la lecture en ligne).
--   2) casiers Storage dédiés (D-EPUB-B) : anarbib-epub-public / -restricted.
--      Public  → 4 policies « bibliothécaires » (calquées sur anarbib-media-public) ;
--      Restreint → aucune policy d'accès direct (comme anarbib-media-restricted) :
--      lecture par URL signée service_role (Edge Function read-digital-asset),
--      dépôt par le dashboard.
--   3) reprise de lecture serveur : table public.reading_progress (scénario C,
--      RPC-only) + RPC api.fn_get_reading_progress / api.fn_upsert_reading_progress
--      (appelées par apiRpc côté front).
--
-- Le dispatch viewer (viewer_kind='epub') est ajouté dans l'Edge Function
-- read-digital-asset (inferViewerKind) — hors SQL, même paquet.
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1) resource_type 'epub'
-- -------------------------------------------------------------------------
ALTER TABLE public.book_digital_resources
  DROP CONSTRAINT IF EXISTS book_digital_resources_resource_type_chk;
ALTER TABLE public.book_digital_resources
  ADD CONSTRAINT book_digital_resources_resource_type_chk
  CHECK (resource_type = ANY (ARRAY[
    'pdf_publico', 'pdf_restrito', 'audio', 'video', 'image',
    'link_externo', 'recurso_digital', 'epub'
  ]));

-- -------------------------------------------------------------------------
-- 2) Casiers Storage dédiés ePub
-- -------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('anarbib-epub-public', 'anarbib-epub-public', true),
       ('anarbib-epub-restricted', 'anarbib-epub-restricted', false)
ON CONFLICT (id) DO NOTHING;

-- Casier PUBLIC : gestion par les bibliothécaires (can_access_catalogacao),
-- lecture publique via le flag public=true. Calqué sur anarbib-media-public.
DROP POLICY IF EXISTS "anarbib_epub_public_librarians_select" ON storage.objects;
CREATE POLICY "anarbib_epub_public_librarians_select" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'anarbib-epub-public'
         AND EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true));

DROP POLICY IF EXISTS "anarbib_epub_public_librarians_insert" ON storage.objects;
CREATE POLICY "anarbib_epub_public_librarians_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'anarbib-epub-public'
              AND EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true));

DROP POLICY IF EXISTS "anarbib_epub_public_librarians_update" ON storage.objects;
CREATE POLICY "anarbib_epub_public_librarians_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'anarbib-epub-public'
         AND EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true))
  WITH CHECK (bucket_id = 'anarbib-epub-public'
              AND EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true));

DROP POLICY IF EXISTS "anarbib_epub_public_librarians_delete" ON storage.objects;
CREATE POLICY "anarbib_epub_public_librarians_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'anarbib-epub-public'
         AND EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true));

-- Casier RESTREINT : volontairement AUCUNE policy d'accès direct (comme
-- anarbib-media-restricted). Accès uniquement via URL signée (service_role,
-- Edge Function) ; dépôt par le dashboard. Anti-fuite (D-EPUB-B).

-- -------------------------------------------------------------------------
-- 3) Reprise de lecture côté serveur (table)
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.reading_progress (
  user_id         uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  resource_id     bigint      NOT NULL REFERENCES public.book_digital_resources(id) ON DELETE CASCADE,
  cfi             text,
  percent         real,
  reading_seconds integer     NOT NULL DEFAULT 0,
  updated_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, resource_id)
);

-- Scénario C : hors Data API. Accès uniquement via les RPC SECURITY DEFINER.
REVOKE ALL ON public.reading_progress FROM anon, authenticated;
GRANT ALL ON public.reading_progress TO service_role;

ALTER TABLE public.reading_progress ENABLE ROW LEVEL SECURITY;

-- Policy propriétaire (défensive / future-proof : l'accès passe par les RPC,
-- mais on garde une policy au cas où un GRANT direct serait ajouté plus tard).
DROP POLICY IF EXISTS "reading_progress_owner" ON public.reading_progress;
CREATE POLICY "reading_progress_owner" ON public.reading_progress
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

COMMENT ON TABLE public.reading_progress IS
  'Reprise de lecture (ePub) par utilisateur·rice et ressource numérique : '
  'position CFI + pourcentage + temps de lecture cumulé. Accès via '
  'api.fn_get/upsert_reading_progress. Paquet Lecteur ePub, 17/06/2026.';

-- -------------------------------------------------------------------------
-- 4) RPC de reprise (schéma api, appelées par apiRpc côté front)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_get_reading_progress(p_resource_id bigint)
RETURNS TABLE(cfi text, percent real, reading_seconds integer)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'api', 'pg_temp'
AS $function$
  SELECT rp.cfi, rp.percent, rp.reading_seconds
  FROM public.reading_progress rp
  WHERE rp.user_id = auth.uid()
    AND rp.resource_id = p_resource_id;
$function$;

REVOKE EXECUTE ON FUNCTION api.fn_get_reading_progress(bigint) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION api.fn_get_reading_progress(bigint) TO authenticated;
COMMENT ON FUNCTION api.fn_get_reading_progress(bigint) IS
  'Reprise : position de lecture de l''utilisateur·rice courant·e pour une ressource. Paquet Lecteur ePub, 17/06/2026.';

CREATE OR REPLACE FUNCTION api.fn_upsert_reading_progress(
  p_resource_id bigint,
  p_cfi text,
  p_percent real,
  p_seconds integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'api', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'forbidden: authentication required' USING errcode = '42501';
  END IF;
  INSERT INTO public.reading_progress (user_id, resource_id, cfi, percent, reading_seconds, updated_at)
  VALUES (v_uid, p_resource_id, p_cfi, p_percent, COALESCE(p_seconds, 0), now())
  ON CONFLICT (user_id, resource_id) DO UPDATE
    SET cfi             = COALESCE(EXCLUDED.cfi, public.reading_progress.cfi),
        percent         = COALESCE(EXCLUDED.percent, public.reading_progress.percent),
        reading_seconds = GREATEST(public.reading_progress.reading_seconds, EXCLUDED.reading_seconds),
        updated_at      = now();
END;
$function$;

REVOKE EXECUTE ON FUNCTION api.fn_upsert_reading_progress(bigint, text, real, integer) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION api.fn_upsert_reading_progress(bigint, text, real, integer) TO authenticated;
COMMENT ON FUNCTION api.fn_upsert_reading_progress(bigint, text, real, integer) IS
  'Reprise : enregistre position (CFI), pourcentage et temps de lecture (monotone) pour l''utilisateur·rice courant·e. Paquet Lecteur ePub, 17/06/2026.';

-- -------------------------------------------------------------------------
-- 5) Vérification automatique (RAISE EXCEPTION => rollback)
-- -------------------------------------------------------------------------
DO $$
BEGIN
  -- 'epub' autorisé par la contrainte ?
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.book_digital_resources'::regclass
      AND conname = 'book_digital_resources_resource_type_chk'
      AND pg_get_constraintdef(oid) LIKE '%''epub''%'
  ) THEN
    RAISE EXCEPTION 'Vérif échouée : resource_type epub absent de la contrainte';
  END IF;

  -- Casiers présents ?
  IF (SELECT count(*) FROM storage.buckets
      WHERE id IN ('anarbib-epub-public', 'anarbib-epub-restricted')) <> 2 THEN
    RAISE EXCEPTION 'Vérif échouée : casiers epub manquants';
  END IF;

  -- RPC présentes ?
  IF (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'api'
        AND p.proname IN ('fn_get_reading_progress', 'fn_upsert_reading_progress')) <> 2 THEN
    RAISE EXCEPTION 'Vérif échouée : RPC reading_progress manquantes';
  END IF;

  RAISE NOTICE 'Paquet Lecteur ePub : vérifications OK';
END $$;

-- Le schéma api/public a changé : PostgREST doit recharger.
NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback ciblé (post-déploiement, si régression) :
-- =========================================================================
-- BEGIN;
--   DROP FUNCTION IF EXISTS api.fn_upsert_reading_progress(bigint, text, real, integer);
--   DROP FUNCTION IF EXISTS api.fn_get_reading_progress(bigint);
--   DROP TABLE IF EXISTS public.reading_progress;
--   -- (casiers + valeur 'epub' : laisser en place, sans danger)
-- COMMIT;
-- =========================================================================
