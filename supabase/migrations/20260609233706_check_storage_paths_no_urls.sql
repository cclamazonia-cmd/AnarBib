-- ════════════════════════════════════════════════════════════════════════════
-- CHECK constraint : les colonnes *_object_path / storage_path ne doivent
-- contenir que des chemins relatifs Supabase Storage, jamais d'URL complètes.
-- Auteur  : Claude (Opus)
-- Session : Enrichissement données & backlog
-- Date    : 2026-06-09 (UTC)
--
-- 3 violations existantes corrigées avant pose des contraintes :
--   • authors 10025, 10026 : photo_object_path contenait une URL noblogs.org
--     (photo externe, pas un objet Storage) → mis à NULL
--   • book_draft_digital_resources 18 : storage_path contenait l'URL Supabase
--     complète → extrait le chemin relatif
-- ════════════════════════════════════════════════════════════════════════════

-- ── 1. Corriger les violations existantes ─────────────────────────────────

UPDATE authors SET photo_object_path = NULL
WHERE id IN (10025, 10026) AND photo_object_path LIKE 'http%';

UPDATE book_draft_digital_resources
SET storage_path = regexp_replace(
  storage_path,
  '^https?://[^/]+/storage/v1/object/public/[^/]+/',
  ''
)
WHERE id = 18 AND storage_path LIKE 'http%';

-- ── 2. Poser les CHECK constraints ────────────────────────────────────────

ALTER TABLE books
  ADD CONSTRAINT chk_cover_object_path_no_url
  CHECK (cover_object_path IS NULL OR cover_object_path NOT LIKE 'http%');

ALTER TABLE book_drafts
  ADD CONSTRAINT chk_cover_object_path_no_url
  CHECK (cover_object_path IS NULL OR cover_object_path NOT LIKE 'http%');

ALTER TABLE authors
  ADD CONSTRAINT chk_photo_object_path_no_url
  CHECK (photo_object_path IS NULL OR photo_object_path NOT LIKE 'http%');

ALTER TABLE author_drafts
  ADD CONSTRAINT chk_photo_object_path_no_url
  CHECK (photo_object_path IS NULL OR photo_object_path NOT LIKE 'http%');

ALTER TABLE digital_assets
  ADD CONSTRAINT chk_object_path_no_url
  CHECK (object_path IS NULL OR object_path NOT LIKE 'http%');

ALTER TABLE book_digital_resources
  ADD CONSTRAINT chk_storage_path_no_url
  CHECK (storage_path IS NULL OR storage_path NOT LIKE 'http%');

ALTER TABLE book_draft_digital_resources
  ADD CONSTRAINT chk_storage_path_no_url
  CHECK (storage_path IS NULL OR storage_path NOT LIKE 'http%');

ALTER TABLE libraries
  ADD CONSTRAINT chk_regimento_draft_path_no_url
  CHECK (regimento_draft_object_path IS NULL OR regimento_draft_object_path NOT LIKE 'http%');

ALTER TABLE libraries
  ADD CONSTRAINT chk_regimento_published_path_no_url
  CHECK (regimento_published_object_path IS NULL OR regimento_published_object_path NOT LIKE 'http%');

ALTER TABLE library_regulation_documents
  ADD CONSTRAINT chk_storage_path_draft_no_url
  CHECK (storage_path_draft IS NULL OR storage_path_draft NOT LIKE 'http%');

ALTER TABLE library_regulation_documents
  ADD CONSTRAINT chk_storage_path_public_no_url
  CHECK (storage_path_public IS NULL OR storage_path_public NOT LIKE 'http%');

ALTER TABLE library_themes
  ADD CONSTRAINT chk_manifest_path_no_url
  CHECK (manifest_path IS NULL OR manifest_path NOT LIKE 'http%');
