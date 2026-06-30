-- =========================================================================
-- Paquet AUTHOR-SOURCE-WIKIPEDIA — libellé de provenance « Wikipédia »
-- =========================================================================
-- Date     : 2026-06-30
-- Chantier : fiches d'autorité — nettoyage des libellés de provenance
--
-- Les fiches auteur réellement sourcées Wikipédia (source_url Wikipédia)
-- portaient le libellé TECHNIQUE du lot manuel d'enrichissement
-- (« manual batch from v_author_alias_worklist »), affiché tel quel en public
-- dans le champ « fonte ». On le remplace par « Wikipédia » (la source
-- réellement consultée) et on vide source_kind (sinon « wikidata · Wikipédia »
-- redondant ; l'identifiant wikidata_id reste affiché à part sur la fiche).
--
-- Ciblage chirurgical : uniquement les fiches dont l'URL est Wikipédia ET dont
-- le libellé est ce note de batch technique (≈ 1 fiche au 30/06 : José Peirats).
-- Idempotent : après exécution, la condition ne matche plus.
--
-- NB : les fiches d'origine INTERNE (catalog_backfill / catalog_seed, sans URL)
-- ne sont PAS touchées ici — leur jargon est masqué côté front (AuthorPage),
-- la donnée de provenance étant conservée pour les coulisses.
-- =========================================================================

BEGIN;

DO $$
DECLARE
  v_n integer;
BEGIN
  UPDATE public.authors
  SET source_label = 'Wikipédia',
      source_kind  = NULL
  WHERE source_url ILIKE '%wikipedia%'
    AND source_label ILIKE 'manual batch%v_author_alias_worklist%';

  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'AUTHOR-SOURCE-WIKIPEDIA : % fiche(s) corrigée(s) -> source_label=Wikipédia, source_kind=NULL.', v_n;
END $$;

COMMIT;
