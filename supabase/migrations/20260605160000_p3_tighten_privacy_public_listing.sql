-- 20260605160000_p3_tighten_privacy_public_listing.sql
--
-- P3 — empêche l'énumération par anon du bucket public library-privacy-public.
--
-- Vérifié dans le front (grep src/) : AUCUN .list() sur library-privacy-public ;
-- l'accès se fait uniquement par URL publique directe (slug/filename). Sur un
-- bucket PUBLIC, le téléchargement par URL ne passe pas par cette policy SELECT
-- (l'endpoint /object/public/ contourne la RLS), donc la retirer ne casse rien.
-- Les Edge Functions utilisent service_role (RLS contournée) → non affectées.
--
-- On retire la seule policy SELECT "PUBLIC" qui laissait anon lister TOUT le
-- bucket. Les policies coordenador (upload/update/delete, déjà scopées par slug)
-- restent en place.

DROP POLICY IF EXISTS "Privacy sections are publicly readable" ON storage.objects;

-- NON touché : library-ui-assets garde sa policy SELECT (le composant d'admin
-- LibraryVisualAssetsSection fait un .list() légitime sur themes/{slug}/).
--
-- Si DROP POLICY échoue pour cause de privilèges sur le schéma storage, fais-le
-- via le dashboard Supabase (Storage > Policies) en repli.
