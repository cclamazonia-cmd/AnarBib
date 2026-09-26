-- =====================================================================
-- H28 — un fichier MARC en ISO 2709 peut s'importer : le format que l'EF
-- écrit est admis par la base.
-- Date : 2026-09-26 · Backlog v34 H28 · Aller-retour PMB (G15, H14)
--
-- Constat (production, 26/09/2026) : la CHECK
-- partner_catalog_import_runs_detected_format_check (dernière définition :
-- 20260828170000_chemin_oai_pmh_executable.sql) n'admet ni 'marc_iso2709' ni
-- 'marc21'. Or :
--   * process-partner-catalog-import ÉCRIT 'marc_iso2709' pour tout fichier
--     ISO 2709 reconnu (marc.ts, parseMarcFile) — l'UPDATE final du run
--     violait donc la CHECK APRÈS l'insertion des lignes de staging : run
--     « failed », lignes présentes mais invisibles à l'écran ;
--   * le front envoyait 'marc21' pour un .mrc ou un .marc — la création même
--     du run (fn_import_create → ingest.fn_create_partner_catalog_import)
--     levait 23514. PMB livre ses exports UNIMARC avec le suffixe « marc ».
-- Aucun run MARC n'a jamais tourné en production (8 runs : 5 CSV, 3 RIS) :
-- aucune donnée à reprendre.
--
-- Choix : admettre 'marc_iso2709' (structure du fichier), PAS 'marc21'.
-- UNIMARC ou MARC21 est un VOCABULAIRE (adapter_overrides.forced_vocabulary,
-- détecté notice par notice par l'EF), pas un format de fichier ; le front
-- envoie désormais 'marc_iso2709' (src/lib/importFileKind.js).
--
-- Même défaut, même réparation que le 28/08 pour 'oai_pmh' : un mot écrit par
-- une fonction qui ne pouvait donc pas s'exécuter.
-- Gardé par src/tests/import-file-kind.test.js (chaque valeur écrite par le
-- front ou par l'EF appartient à la CHECK de la DERNIÈRE migration qui la
-- pose) et tests/sql/import_format_marc_tests.sql.
-- =====================================================================

alter table ingest.partner_catalog_import_runs
  drop constraint if exists partner_catalog_import_runs_detected_format_check;
alter table ingest.partner_catalog_import_runs
  add constraint partner_catalog_import_runs_detected_format_check
  check (detected_format = any (array[
    'csv', 'tsv', 'xlsx', 'xls', 'ods', 'json', 'csl_json', 'ris',
    'bibtex', 'biblatex', 'mods', 'marcxml', 'xml', 'pdf', 'zip',
    -- MARC en ISO 2709 (binaire), UNIMARC ou MARC21 : le vocabulaire se lit
    -- notice par notice, il n'est pas un format de fichier.
    'marc_iso2709',
    'lookup',
    -- Run né d'un moissonnage : aucun fichier reçu, et le format des notices
    -- n'est pas encore connu (le préfixe demandé est auto-négocié par l'EF).
    -- Écrire marcxml affirmerait le résultat d'une négociation non tenue.
    'oai_pmh',
    'unknown'
  ]));

comment on constraint partner_catalog_import_runs_detected_format_check
  on ingest.partner_catalog_import_runs is
  'Formats de fichier, plus deux provenances SANS fichier : ''lookup'' (run '
  'alimente ligne a ligne par fn_import_ingest_candidate) et ''oai_pmh'' (run '
  'ne d''un moissonnage, dont le format reel n''est pas connu a sa naissance). '
  'Elargie le 28/08/2026, puis le 26/09/2026 a ''marc_iso2709'' (H28) : ecrit '
  'par process-partner-catalog-import, il faisait echouer tout import ISO 2709. '
  'UNIMARC/MARC21 est un vocabulaire (forced_vocabulary), pas un format.';
