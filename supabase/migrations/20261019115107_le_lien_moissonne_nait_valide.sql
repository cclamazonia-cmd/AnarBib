-- =========================================================================
-- Le lien de lecture d'une notice moissonnée naît validé : la révision du
-- lot reste le garde-fou
-- =========================================================================
-- Date     : 2026-10-19
-- Chantier : banc OAI ASB → AnarBib (19/10/2026) — décision de Xavier le
--            même jour
-- Auteur   : Claude (Opus 5.5), à la demande de Xavier
-- Suite    : tests/sql/oai_liens_externes_tests.sql (T7, lu comme le public)
--
-- LE CONSTAT.
--   La migration 20261018221318 crée, pour chaque adresse de lecture d'une
--   notice moissonnée, une ressource « lien externe » publique. Mais la
--   lecture publique (catalog_digital_access_v1, le badge du catalogue ;
--   get_book_primary_public_digital_asset_v2, le bouton de la notice) n'affiche
--   une ressource publique que si bibliographic_match_validated est vrai — et
--   le lien naissait à faux, comme toute ressource que personne n'a vérifiée.
--   Publié, il restait donc invisible au public. Les tests du 18/10 lisaient
--   les tables, pas ce que voit le public : ils ne le voyaient pas.
--
-- LA DÉCISION (Xavier, 19/10).
--   Ce lien n'est pas une copie trouvée ailleurs : c'est l'adresse de LA
--   notice chez la source, tirée de son propre dc:identifier. Il naît donc
--   validé. Le garde-fou humain reste la révision du lot par l'administration
--   du réseau (garde de sortie du 05/09/2026), sans laquelle aucun brouillon
--   importé ne se publie.
--
-- LE GESTE.
--   ingest.fn_create_book_drafts_from_import_rows, réécrite depuis sa
--   DÉFINITION RÉELLE (lue en production le 19/10/2026 : md5
--   4d97a64868dddc5f037bcc9adeea601a, 13 841 caractères) — deux ancres
--   comptées dans le bloc de la migration 20261018221318 : la colonne
--   bibliographic_match_validated et sa valeur true. Rien d'autre ne bouge.
--   Aucune ressource existante à reprendre : zéro lien né d'un import en
--   production au 19/10 (metadata->>'origine' = 'import').
--
-- CHECKLIST DOCTRINE
--   [x] Définition réelle, ancres comptées, droits et SECURITY DEFINER
--       vérifiés inchangés ; rejouée sur une fonction déjà modifiée, elle ne
--       fait rien
--   [x] Pas de table, pas de colonne, pas de policy touchée
--   [x] Le fonctionnel est dans la suite SQL, lu sous le rôle anon
-- =========================================================================

BEGIN;

DO $migration$
DECLARE
  v_sig    constant regprocedure := 'ingest.fn_create_book_drafts_from_import_rows(bigint,bigint[],text,text,uuid)'::regprocedure;
  v_def    text;
  v_acl    text;
  v_cols   constant text := E'      mime_type, label, source_name, source_url, attribution_text, metadata)\n';
  v_meta   constant text := E'           jsonb_build_object(''origine'', ''import'', ''run_id'', rec.run_id, ''staging_row_id'', rec.id)\n';
  v_n1     int;
  v_n2     int;
BEGIN
  v_def := pg_get_functiondef(v_sig);
  SELECT proacl::text INTO v_acl FROM pg_proc WHERE oid = v_sig;

  IF strpos(v_def, 'attribution_text, metadata, bibliographic_match_validated)') > 0 THEN
    RAISE NOTICE 'Le lien moissonne nait deja valide : rien a faire.';
    RETURN;
  END IF;

  v_n1 := (length(v_def) - length(replace(v_def, v_cols, ''))) / length(v_cols);
  v_n2 := (length(v_def) - length(replace(v_def, v_meta, ''))) / length(v_meta);
  IF v_n1 <> 1 OR v_n2 <> 1 THEN
    RAISE EXCEPTION 'Ancres du bloc des liens trouvees %/% fois (attendu 1/1) : la definition reelle a change, ne rien appliquer.', v_n1, v_n2;
  END IF;

  v_def := replace(v_def, v_cols,
                   E'      mime_type, label, source_name, source_url, attribution_text, metadata, bibliographic_match_validated)\n');
  v_def := replace(v_def, v_meta,
                   E'           jsonb_build_object(''origine'', ''import'', ''run_id'', rec.run_id, ''staging_row_id'', rec.id),\n'
                   || E'           -- Le lien est celui de LA notice chez la source, pas une copie trouvée\n'
                   || E'           -- ailleurs : il naît validé ; la révision du lot reste le garde-fou (19/10/2026).\n'
                   || E'           true\n');
  EXECUTE v_def;

  v_def := pg_get_functiondef(v_sig);
  IF strpos(v_def, 'attribution_text, metadata, bibliographic_match_validated)') = 0
     OR strpos(v_def, E'la révision du lot reste le garde-fou (19/10/2026).\n           true\n') = 0 THEN
    RAISE EXCEPTION 'bibliographic_match_validated absent apres reecriture.';
  END IF;
  IF (SELECT proacl::text FROM pg_proc WHERE oid = v_sig) IS DISTINCT FROM v_acl
     OR NOT (SELECT prosecdef FROM pg_proc WHERE oid = v_sig) THEN
    RAISE EXCEPTION 'Droits ou SECURITY DEFINER de fn_create_book_drafts_from_import_rows changes.';
  END IF;
END
$migration$;

COMMIT;
