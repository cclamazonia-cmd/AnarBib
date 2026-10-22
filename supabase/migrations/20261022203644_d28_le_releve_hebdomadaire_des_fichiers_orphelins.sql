-- ============================================================================
-- D28 — le relevé hebdomadaire des fichiers orphelins (décision Xavier,
-- 22/10/2026, option b).
--
-- Le 19/10, deux fichiers dormaient dans les seaux PDF sans qu'aucune ressource
-- ne les cite (un versement de brouillon remplacé, un essai de mars) ; Xavier
-- les a retirés le 22/10 par le tableau de bord. La cause probable — un fichier
-- versé dans le formulaire d'un brouillon puis remplacé — ne laisse aucune
-- trace en base : rien n'empêche qu'elle se reproduise. Plutôt qu'une
-- suppression automatique (option c, écartée : une archive ne s'efface pas par
-- un automate), le rapport hebdomadaire du réseau (`notify-network-weekly-report`,
-- lundi) liste désormais ces fichiers ; l'administration du réseau décide.
--
-- Un fichier est orphelin s'il est dans un des quatre seaux PDF/EPUB, qu'aucune
-- ressource numérique (notice ou brouillon) ni aucun actif numérique ne le
-- cite, qu'il a plus de 24 heures (un versement en cours n'est pas un orphelin)
-- et que ce n'est pas un marqueur de dossier vide du tableau de bord.
--
-- Lecture seule ; service_role seul (l'Edge Function). Banc :
-- tests/sql/d28_fichiers_orphelins_tests.sql.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_stockage_orphelins_v1()
RETURNS TABLE (bucket text, chemin text, octets bigint, depose_le timestamptz)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $fn$
  SELECT o.bucket_id::text, o.name::text,
         nullif(o.metadata ->> 'size', '')::bigint,
         o.created_at
    FROM storage.objects o
   WHERE o.bucket_id IN ('anarbib-pdf-public', 'pdf-restrito', 'anarbib-epub-public', 'anarbib-epub-restricted')
     AND o.name NOT LIKE '%.emptyFolderPlaceholder'
     AND o.created_at < now() - interval '24 hours'
     AND NOT EXISTS (SELECT 1 FROM public.book_digital_resources r
                      WHERE r.storage_bucket = o.bucket_id AND r.storage_path = o.name)
     AND NOT EXISTS (SELECT 1 FROM public.book_draft_digital_resources d
                      WHERE d.storage_bucket = o.bucket_id AND d.storage_path = o.name)
     AND NOT EXISTS (SELECT 1 FROM public.digital_assets a
                      WHERE a.bucket_name = o.bucket_id AND a.object_path = o.name)
   ORDER BY o.created_at, o.bucket_id, o.name
   LIMIT 200
$fn$;

REVOKE ALL ON FUNCTION public.fn_stockage_orphelins_v1() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_stockage_orphelins_v1() TO service_role;

COMMENT ON FUNCTION public.fn_stockage_orphelins_v1() IS
  'D28 (22/10/2026) : fichiers des seaux PDF/EPUB qu''aucune ressource (notice, brouillon) ni actif numérique ne cite, '
  'de plus de 24 h, hors marqueurs de dossier ; lus par le rapport hebdomadaire du réseau. Lecture seule, rien n''est supprimé.';
