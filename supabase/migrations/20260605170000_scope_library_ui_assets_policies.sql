-- 20260605170000_scope_library_ui_assets_policies.sql
--
-- Durcissement du bucket library-ui-assets.
--
-- AVANT : 4 policies "authenticated" non scopees (condition = bucket_id seul)
--   -> n'importe quel utilisateur connecte pouvait lister / ecraser / supprimer
--      les assets de theme de N'IMPORTE QUELLE bibliotheque (faille d'integrite).
--
-- APRES :
--   - themes/{slug}/...   -> reserve au staff de la bibliotheque (user_can_engage_library)
--   - catalog/, manuals/, racine -> ecriture "authenticated" PRESERVEE (assets partages,
--     ecrits hors front : dashboard / service_role ; comportement inchange)
--   - lecture (list) : limitee au staff sur themes/{slug}/ ; tout le reste se lit par
--     URL publique (bucket public, RLS contournee), donc aucun listing large cote authenticated.
--
-- Verifie le 2026-06-05 (lecture seule) :
--   themes (33 objets, 4 slugs) ; catalog/fonts/*.woff2 (polices partagees) ; manuals (3) ;
--   user_can_engage_library(p_library_id uuid) SECURITY DEFINER ; libraries.slug present.
--
-- NB : l'affichage public des logos et le fetch de themes/{slug}/manifest.json passent par
-- URL publique -> non affectes. Si DROP/CREATE POLICY echoue pour cause de privileges sur le
-- schema storage, refaire via le dashboard (Storage > Policies).

-- 1) Retrait des 4 policies larges
DROP POLICY IF EXISTS "Authenticated can read library ui assets"   ON storage.objects;
DROP POLICY IF EXISTS "Authenticated can upload library ui assets" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated can update library ui assets" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated can delete library ui assets" ON storage.objects;

-- 2) LECTURE / LIST : staff uniquement, sur le dossier de SA bibliotheque
CREATE POLICY "ui assets: staff list own theme folder"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'library-ui-assets'
  AND (storage.foldername(name))[1] = 'themes'
  AND EXISTS (
    SELECT 1 FROM public.libraries l
    WHERE l.slug = (storage.foldername(name))[2]
      AND public.user_can_engage_library(l.id)
  )
);

-- 3) ECRITURE : staff sur themes/{slug}/, authenticated ailleurs (assets partages)
--    Expression commune : soit le chemin n'est PAS sous themes/, soit le staff de la biblio.
CREATE POLICY "ui assets: scoped insert"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'library-ui-assets'
  AND (
    (storage.foldername(name))[1] IS DISTINCT FROM 'themes'
    OR EXISTS (
      SELECT 1 FROM public.libraries l
      WHERE l.slug = (storage.foldername(name))[2]
        AND public.user_can_engage_library(l.id)
    )
  )
);

CREATE POLICY "ui assets: scoped update"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'library-ui-assets'
  AND (
    (storage.foldername(name))[1] IS DISTINCT FROM 'themes'
    OR EXISTS (
      SELECT 1 FROM public.libraries l
      WHERE l.slug = (storage.foldername(name))[2]
        AND public.user_can_engage_library(l.id)
    )
  )
)
WITH CHECK (
  bucket_id = 'library-ui-assets'
  AND (
    (storage.foldername(name))[1] IS DISTINCT FROM 'themes'
    OR EXISTS (
      SELECT 1 FROM public.libraries l
      WHERE l.slug = (storage.foldername(name))[2]
        AND public.user_can_engage_library(l.id)
    )
  )
);

CREATE POLICY "ui assets: scoped delete"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'library-ui-assets'
  AND (
    (storage.foldername(name))[1] IS DISTINCT FROM 'themes'
    OR EXISTS (
      SELECT 1 FROM public.libraries l
      WHERE l.slug = (storage.foldername(name))[2]
        AND public.user_can_engage_library(l.id)
    )
  )
);
