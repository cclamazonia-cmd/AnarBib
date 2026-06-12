-- Migration : provenance partenaire sur book_drafts (continuite rigueur de source, B4)
-- Auteur  : Claude (Opus 4.8)
-- Session : Import/Export — fiabilisation matching & rapprochement
-- Date    : 2026-06-12 (UTC)
--
-- Chantier B4 (cf. CADRAGE_partenaire_import_unification_2026-06-11). Les
-- book_drafts issus d'un import portent deja la provenance en texte
-- (provenance_note), mais pas de lien vers l'ENTITE partenaire reelle
-- (public.catalog_partners). On ajoute book_drafts.catalog_partner_id et on
-- l'estampille automatiquement a la creation du brouillon d'import, en derivant
-- la source du run (ingest.partner_catalog_sources.catalog_partner_id, lien pose
-- par B1 / migration 20260611090151).
--
-- Approche : on NE reecrit PAS le worker de creation (fn_create_book_drafts_from
-- _import_rows). On branche un TRIGGER sur la table de lien
-- ingest.partner_catalog_row_to_draft (alimentee par le worker apres l'insert du
-- book_draft) -> decouple, additif, zero modification du worker.

-- ──────────────────────────────────────────────────────────────────────────
-- 1) Colonne provenance partenaire
-- ──────────────────────────────────────────────────────────────────────────
ALTER TABLE public.book_drafts
  ADD COLUMN IF NOT EXISTS catalog_partner_id bigint
  REFERENCES public.catalog_partners(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_book_drafts_catalog_partner
  ON public.book_drafts (catalog_partner_id)
  WHERE catalog_partner_id IS NOT NULL;

-- ──────────────────────────────────────────────────────────────────────────
-- 2) Trigger d'estampillage a la creation du lien import -> draft
-- ──────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION ingest.fn_stamp_book_draft_partner()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'ingest', 'public'
AS $function$
begin
  update public.book_drafts bd
     set catalog_partner_id = (
       select s.catalog_partner_id
       from ingest.partner_catalog_import_runs r
       join ingest.partner_catalog_sources s on s.id = r.source_id
       where r.id = new.run_id
     )
   where bd.id = new.draft_id
     and bd.catalog_partner_id is null;
  return new;
end;
$function$;

-- SECURITY DEFINER : verrouiller l'execution (doctrine .githooks). Une fonction
-- trigger est invoquee par le mecanisme de trigger (pas via le privilege EXECUTE),
-- donc aucun GRANT n'est requis pour son fonctionnement.
REVOKE EXECUTE ON FUNCTION ingest.fn_stamp_book_draft_partner() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_stamp_book_draft_partner ON ingest.partner_catalog_row_to_draft;
CREATE TRIGGER trg_stamp_book_draft_partner
  AFTER INSERT ON ingest.partner_catalog_row_to_draft
  FOR EACH ROW
  EXECUTE FUNCTION ingest.fn_stamp_book_draft_partner();

-- ──────────────────────────────────────────────────────────────────────────
-- 3) Backfill des book_drafts existants issus d'un import (idempotent)
-- ──────────────────────────────────────────────────────────────────────────
UPDATE public.book_drafts bd
   SET catalog_partner_id = s.catalog_partner_id
  FROM ingest.partner_catalog_row_to_draft rd
  JOIN ingest.partner_catalog_import_runs r ON r.id = rd.run_id
  JOIN ingest.partner_catalog_sources s ON s.id = r.source_id
 WHERE rd.draft_id = bd.id
   AND s.catalog_partner_id IS NOT NULL
   AND bd.catalog_partner_id IS DISTINCT FROM s.catalog_partner_id;
