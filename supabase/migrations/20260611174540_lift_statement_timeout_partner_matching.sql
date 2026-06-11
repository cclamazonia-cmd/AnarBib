-- Migration : relève le statement_timeout des fonctions de matching d'import
-- Auteur  : Claude Opus 4.8
-- Session : Unification partenaire <-> source d'import (fix matching timeout)
-- Date    : 2026-06-11 (UTC)
--
-- BUG : l'import des 301 fiches CIRA parse correctement (301 staging rows créées),
-- puis l'étape de matching/dédup (ingest.fn_match_partner_catalog_run boucle sur
-- les lignes en appelant fn_match_partner_catalog_row — fonction lourde par ligne)
-- dépasse le statement_timeout (~10 s) -> run marqué 'failed', compteurs jamais
-- rafraîchis (l'écran affiche 0 lignes alors que les 301 sont en base).
--
-- Fix immédiat : on retire le plafond de temps pour CES fonctions via
-- ALTER FUNCTION ... SET statement_timeout (n'altère pas le corps). Le coût reste
-- borné par le nombre de lignes du lot.
--
-- NOTE perf (suite) : pour de gros lots (migration de milliers de notices), la
-- vraie optimisation = matching PAR LOTS (l'EF appelle fn_match_partner_catalog_run
-- avec des batches de row_ids) et/ou index sur les colonnes comparées. À faire.

ALTER FUNCTION ingest.fn_match_partner_catalog_run(bigint, bigint[]) SET statement_timeout = '0';
ALTER FUNCTION ingest.fn_match_partner_catalog_row(bigint)           SET statement_timeout = '0';
ALTER FUNCTION ingest.fn_refresh_partner_catalog_run_counters(bigint) SET statement_timeout = '0';

DO $verif$
DECLARE
  v_missing text := '';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
                  WHERE n.nspname='ingest' AND p.proname='fn_match_partner_catalog_run'
                    AND array_to_string(p.proconfig, ',') ILIKE '%statement_timeout%')
  THEN v_missing := v_missing || 'fn_match_partner_catalog_run '; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
                  WHERE n.nspname='ingest' AND p.proname='fn_match_partner_catalog_row'
                    AND array_to_string(p.proconfig, ',') ILIKE '%statement_timeout%')
  THEN v_missing := v_missing || 'fn_match_partner_catalog_row '; END IF;
  IF v_missing <> '' THEN
    RAISE EXCEPTION 'statement_timeout non posé sur : %', v_missing;
  END IF;
  RAISE NOTICE 'statement_timeout levé sur les fonctions de matching d''import.';
END
$verif$;
