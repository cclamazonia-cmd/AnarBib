-- Perf matching import (#5) : volets A+B+C livrés et vérifiés (index scans sub-ms,
-- md5 fonction = 0d2625ad117dc22affd34908015dd605). On remplace le band-aid
-- statement_timeout=0 (illimité, migration 20260611174540) par une borne généreuse
-- de 120s : strictement plus sûr (pas de run pathologique qui pend jusqu'au
-- wall-clock EF ~150s), ~40x de marge sur le pire import réaliste (~2500 lignes).
-- Cf. docs/journal/cadrages/CADRAGE_perf_matching_import_2026-06-11.md §3-§6.
alter function ingest.fn_match_partner_catalog_row(bigint) set statement_timeout to '120s';
alter function ingest.fn_match_partner_catalog_run(bigint, bigint[]) set statement_timeout to '120s';
alter function ingest.fn_refresh_partner_catalog_run_counters(bigint) set statement_timeout to '120s';
