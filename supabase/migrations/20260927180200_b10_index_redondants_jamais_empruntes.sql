-- =========================================================================
-- B10, passe 3 — retirer les index redondants jamais empruntés
-- =========================================================================
-- Date     : 2026-09-27
-- Chantier : B10 (hygiène de performance), avis 0005 unused_index
--
-- LA RÈGLE DE LA FICHE : « ne supprimer un index inutilisé que si l'on
-- comprend pourquoi il avait été créé ». L'avis en compte 284 — mais « zéro
-- scan depuis le 02/09 » ne prouve pas l'inutilité : à 2 700 notices le
-- planificateur préfère souvent un parcours séquentiel, et un index qui sert
-- une recherche servira à 100 000. 174 de ces 284 servent d'ailleurs une clé
-- étrangère (garde B21). L'inventaire du reste est écrit à part (docs, B10).
--
-- Ce que cette migration retire, et seulement cela : les index qui sont à la
-- fois JAMAIS EMPRUNTÉS (idx_scan = 0 du 02/09 au 27/09) et REDONDANTS au sens
-- strict — leurs colonnes-clés sont le préfixe exact d'un autre index valide
-- de la même table, même méthode, mêmes classes d'opérateurs, collations et
-- ordres, même prédicat, et ils n'ont pas de colonne INCLUDE. Toute requête
-- qui pouvait les emprunter peut emprunter l'index couvrant ; les garder ne
-- coûte que des écritures. Ce critère ne dépend pas du volume : il vaudra à
-- 100 000 notices comme aujourd'hui.
--
-- Pourquoi ils existaient (un par un, relu le 27/09) :
--   * 8 viennent du socle du 10/05 (dump sans commentaire) et suivent un même
--     réflexe : un index sur la colonne de tête d'une contrainte UNIQUE ou
--     d'un index composé déjà présent — celui-ci servait déjà la clé
--     étrangère et les recherches par cette colonne ;
--   * 2 viennent des périodiques (27/08) : l'index de support de la FK a été
--     créé dans LA MÊME migration que l'index composé qui le couvrait déjà —
--     books (serial_id) sous (serial_id, issue_key), même prédicat ;
--     serial_holdings (serial_id) sous UNIQUE (serial_id, library_id).
--
-- Ce qui reste, exprès : 22 autres index redondants au sens strict SONT
-- empruntés (jusqu'à 10,8 millions de scans pour book_holdings_book_id_idx).
-- Les retirer déplacerait des plans chauds vers l'index couvrant : cela se
-- décide sur mesure, pas dans une passe d'hygiène. Ils sont nommés, avec
-- leurs compteurs, dans tests/sql/index_redondants_garde_tests.sql, qui
-- refuse désormais tout NOUVEL index redondant.
--
-- Garde d'entrée : chaque index retiré est encore couvert, au moment du
-- retrait, par l'index nommé ci-dessous (sinon la migration refuse). Garde de
-- sortie : aucune clé étrangère n'a perdu son index de support (B21).
-- =========================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- Garde d'entrée : chaque index à retirer qui existe encore est strictement
-- couvert par l'index nommé (rejeu : un index déjà retiré ne compte pas).
-- ---------------------------------------------------------------------------
DO $garde$
DECLARE v_pb text; v_fk_avant int;
BEGIN
  SELECT string_agg(r.sch || '.' || r.idx, ', ') INTO v_pb
  FROM
  (VALUES
    -- socle du 10/05
    ('ingest', 'partner_catalog_import_files_run_idx',        'partner_catalog_import_files_role_idx'),                    -- (run_id) sous (run_id, file_role, parse_status)
    ('public', 'emprestimo_itens_v2_emprestimo_idx',          'emprestimo_itens_v2_emprestimo_line_unique'),               -- (emprestimo_id, line_no) = UNIQUE identique
    ('public', 'emprestimo_itens_v2_user_open_idx',           'idx_emprestimo_itens_v2_itemstatus_due_emprestimo_lineno'), -- (item_status, due_at) sous (…, emprestimo_id, line_no)
    ('public', 'idx_authority_proposal_objections_proposal', 'authority_proposal_objections_one_per_library'),            -- (proposal_id) sous UNIQUE (proposal_id, objecting_library_id)
    ('public', 'idx_consulta_item_workflow_v2_consulta_id',  'consulta_item_workflow_v2_unique_line'),                    -- (consulta_id) sous UNIQUE (consulta_id, line_no)
    ('public', 'idx_lpv_proposal',                           'uniq_lpv_one_vote_per_voter'),                              -- (proposal_id) sous UNIQUE (proposal_id, voter_id)
    ('public', 'idx_painel_internal_tasks_library',          'idx_painel_internal_tasks_status'),                         -- (library_id) sous (library_id, status)
    ('public', 'idx_task_invites_library',                   'idx_task_invites_status'),                                  -- (library_id) sous (library_id, invite_status)
    -- périodiques du 27/08
    ('public', 'books_serial_id_idx',                        'books_serial_issue_idx'),                                   -- (serial_id) WHERE serial_id IS NOT NULL sous (serial_id, issue_key), même prédicat
    ('public', 'serial_holdings_serial_id_idx',              'serial_holdings_unique')                                    -- (serial_id) sous UNIQUE (serial_id, library_id)
  ) AS r(sch, idx, couvrant)
  WHERE to_regclass(r.sch || '.' || r.idx) IS NOT NULL
    AND NOT EXISTS (
      SELECT 1
      FROM pg_index i
      JOIN pg_class ic ON ic.oid = i.indexrelid
      JOIN pg_index o ON o.indrelid = i.indrelid
      JOIN pg_class oc ON oc.oid = o.indexrelid
      WHERE i.indexrelid = to_regclass(r.sch || '.' || r.idx)
        AND o.indexrelid = to_regclass(r.sch || '.' || r.couvrant)
        AND o.indisvalid AND o.indisready
        AND oc.relam = ic.relam
        AND i.indexprs IS NULL AND o.indexprs IS NULL
        AND i.indnatts = i.indnkeyatts
        AND NOT i.indisunique
        AND coalesce(pg_get_expr(o.indpred, o.indrelid), '') = coalesce(pg_get_expr(i.indpred, i.indrelid), '')
        AND o.indnkeyatts >= i.indnkeyatts
        AND (o.indkey::int2[])[0:i.indnkeyatts - 1]      = (i.indkey::int2[])[0:i.indnkeyatts - 1]
        AND (o.indclass::oid[])[0:i.indnkeyatts - 1]     = (i.indclass::oid[])[0:i.indnkeyatts - 1]
        AND (o.indcollation::oid[])[0:i.indnkeyatts - 1] = (i.indcollation::oid[])[0:i.indnkeyatts - 1]
        AND (o.indoption::int2[])[0:i.indnkeyatts - 1]   = (i.indoption::int2[])[0:i.indnkeyatts - 1]);
  IF v_pb IS NOT NULL THEN
    RAISE EXCEPTION 'B10 passe 3 : plus couverts par l''index attendu, retrait refusé : %', v_pb;
  END IF;

  SELECT count(*) INTO v_fk_avant
  FROM pg_constraint c JOIN pg_namespace n ON n.oid = c.connamespace
  WHERE c.contype = 'f' AND n.nspname IN ('public', 'ingest')
    AND NOT EXISTS (SELECT 1 FROM pg_index i WHERE i.indrelid = c.conrelid
                      AND (i.indkey::int2[])[0:array_length(c.conkey, 1) - 1] = c.conkey);
  PERFORM set_config('b10.fk_avant', v_fk_avant::text, true);
END
$garde$;

DROP INDEX IF EXISTS ingest.partner_catalog_import_files_run_idx;
DROP INDEX IF EXISTS public.emprestimo_itens_v2_emprestimo_idx;
DROP INDEX IF EXISTS public.emprestimo_itens_v2_user_open_idx;
DROP INDEX IF EXISTS public.idx_authority_proposal_objections_proposal;
DROP INDEX IF EXISTS public.idx_consulta_item_workflow_v2_consulta_id;
DROP INDEX IF EXISTS public.idx_lpv_proposal;
DROP INDEX IF EXISTS public.idx_painel_internal_tasks_library;
DROP INDEX IF EXISTS public.idx_task_invites_library;
DROP INDEX IF EXISTS public.books_serial_id_idx;
DROP INDEX IF EXISTS public.serial_holdings_serial_id_idx;

-- ---------------------------------------------------------------------------
-- Garde de sortie : aucune clé étrangère n'a perdu son index de support.
-- ---------------------------------------------------------------------------
DO $sortie$
DECLARE v_fk_apres int;
BEGIN
  SELECT count(*) INTO v_fk_apres
  FROM pg_constraint c JOIN pg_namespace n ON n.oid = c.connamespace
  WHERE c.contype = 'f' AND n.nspname IN ('public', 'ingest')
    AND NOT EXISTS (SELECT 1 FROM pg_index i WHERE i.indrelid = c.conrelid
                      AND (i.indkey::int2[])[0:array_length(c.conkey, 1) - 1] = c.conkey);
  IF v_fk_apres <> current_setting('b10.fk_avant')::int THEN
    RAISE EXCEPTION 'B10 passe 3 : % clés étrangères sans index après retrait, % avant', v_fk_apres, current_setting('b10.fk_avant');
  END IF;
  IF EXISTS (SELECT 1 FROM
    (VALUES
      -- socle du 10/05
      ('ingest', 'partner_catalog_import_files_run_idx',        'partner_catalog_import_files_role_idx'),                    -- (run_id) sous (run_id, file_role, parse_status)
      ('public', 'emprestimo_itens_v2_emprestimo_idx',          'emprestimo_itens_v2_emprestimo_line_unique'),               -- (emprestimo_id, line_no) = UNIQUE identique
      ('public', 'emprestimo_itens_v2_user_open_idx',           'idx_emprestimo_itens_v2_itemstatus_due_emprestimo_lineno'), -- (item_status, due_at) sous (…, emprestimo_id, line_no)
      ('public', 'idx_authority_proposal_objections_proposal', 'authority_proposal_objections_one_per_library'),            -- (proposal_id) sous UNIQUE (proposal_id, objecting_library_id)
      ('public', 'idx_consulta_item_workflow_v2_consulta_id',  'consulta_item_workflow_v2_unique_line'),                    -- (consulta_id) sous UNIQUE (consulta_id, line_no)
      ('public', 'idx_lpv_proposal',                           'uniq_lpv_one_vote_per_voter'),                              -- (proposal_id) sous UNIQUE (proposal_id, voter_id)
      ('public', 'idx_painel_internal_tasks_library',          'idx_painel_internal_tasks_status'),                         -- (library_id) sous (library_id, status)
      ('public', 'idx_task_invites_library',                   'idx_task_invites_status'),                                  -- (library_id) sous (library_id, invite_status)
      -- périodiques du 27/08
      ('public', 'books_serial_id_idx',                        'books_serial_issue_idx'),                                   -- (serial_id) WHERE serial_id IS NOT NULL sous (serial_id, issue_key), même prédicat
      ('public', 'serial_holdings_serial_id_idx',              'serial_holdings_unique')                                    -- (serial_id) sous UNIQUE (serial_id, library_id)
    ) AS r(sch, idx, couvrant)
             WHERE to_regclass(r.sch || '.' || r.idx) IS NOT NULL) THEN
    RAISE EXCEPTION 'B10 passe 3 : un index à retirer est toujours là';
  END IF;
END
$sortie$;

COMMIT;
