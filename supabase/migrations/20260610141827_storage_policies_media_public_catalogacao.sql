-- ════════════════════════════════════════════════════════════════════════════
-- Storage policies : anarbib-media-public — upload par catalogueur·euse
-- ════════════════════════════════════════════════════════════════════════════
-- Date    : 2026-06-10 14:18 UTC (horodatage réel, > max présent au moment de
--           la création)
-- Session : anti-opacite messages erreur (outil d'import de ressources numériques)
-- Auteur  : Xavier + Claude
--
-- OBJET
-- -----
-- Le bucket public `anarbib-pdf-public` autorise déjà l'upload par les
-- catalogueur·euses (policies `anarbib_pdf_public_librarians_*`). Le bucket
-- `anarbib-media-public` (image / audio / vidéo libres de droits) existe mais
-- n'a AUCUNE policy → upload impossible. Cette migration ajoute les 4 policies
-- catalogueur·euse, miroir exact de celles des PDF, pour que l'outil d'import
-- simplifié (bouton « téléverser ») puisse y déposer les médias.
--
-- Garde : `api.my_access.can_access_catalogacao = true` (même garde que les PDF).
-- Le bucket est public en lecture (URL publique) ; la policy SELECT couvre la
-- liste via l'API authentifiée, par cohérence avec le pendant PDF.
-- ════════════════════════════════════════════════════════════════════════════

CREATE POLICY "anarbib_media_public_librarians_insert"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'anarbib-media-public'
    AND EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true)
  );

CREATE POLICY "anarbib_media_public_librarians_select"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'anarbib-media-public'
    AND EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true)
  );

CREATE POLICY "anarbib_media_public_librarians_update"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'anarbib-media-public'
    AND EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true)
  )
  WITH CHECK (
    bucket_id = 'anarbib-media-public'
    AND EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true)
  );

CREATE POLICY "anarbib_media_public_librarians_delete"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'anarbib-media-public'
    AND EXISTS (SELECT 1 FROM api.my_access a WHERE a.can_access_catalogacao = true)
  );
