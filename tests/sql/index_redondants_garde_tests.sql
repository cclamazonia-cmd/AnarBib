-- =====================================================================
-- AnarBib — Garde des index redondants
-- Date    : 2026-09-27  ·  Item B10, passe 3 (avis 0005 unused_index)
-- Ref     : 20260927180200_b10_index_redondants_jamais_empruntes
--
-- Un index btree dont les colonnes-clés sont le PRÉFIXE EXACT d'un autre
-- index valide de la même table — mêmes classes d'opérateurs, collations et
-- ordres, même prédicat, sans colonne INCLUDE — ne sert à rien que l'autre ne
-- serve : toute requête qui pouvait l'emprunter peut emprunter le couvrant.
-- Il ne coûte que des écritures, et ce critère ne dépend pas du volume.
--
-- Le 27/09, 32 index étaient dans ce cas (banc et production identiques).
-- Les 10 jamais empruntés depuis le 02/09 ont été retirés par la migration de
-- référence. Les 22 autres SONT empruntés — jusqu'à 10,8 millions de scans :
-- les retirer déplacerait des plans chauds vers l'index couvrant, ce qui se
-- décide sur mesure, pas dans une passe d'hygiène. Ils sont nommés ci-dessous.
--
-- Même logique que la garde B21 des clés étrangères : la dette n'entre plus
-- sans un acte.
--   T1  aucun index redondant hors de la liste assumée ;
--   T2  aucune entrée périmée (redondance levée ou index disparu) ;
--   T3  le détecteur mord — et ne mord pas à tort (classe d'opérateurs,
--       prédicat, INCLUDE).
--   Bilan OK : 'INDEX_REDONDANTS_GARDE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_n int; v_txt text;
BEGIN
  CREATE FUNCTION pg_temp.b10_redondants(p_relid oid DEFAULT NULL)
  RETURNS TABLE(idx text, couvrant text)
  LANGUAGE sql AS $f$
    SELECT n.nspname || '.' || ic.relname, min(oc.relname)::text
      FROM pg_index i
      JOIN pg_class ic ON ic.oid = i.indexrelid
      JOIN pg_namespace n ON n.oid = ic.relnamespace
      JOIN pg_index o ON o.indrelid = i.indrelid AND o.indexrelid <> i.indexrelid
      JOIN pg_class oc ON oc.oid = o.indexrelid
     WHERE CASE WHEN p_relid IS NULL THEN n.nspname IN ('public', 'ingest', 'api', 'private')
                ELSE i.indrelid = p_relid END
       AND ic.relam = (SELECT oid FROM pg_am WHERE amname = 'btree')
       AND NOT i.indisunique AND NOT i.indisprimary
       AND i.indexprs IS NULL AND i.indnatts = i.indnkeyatts
       AND o.indisvalid AND o.indisready AND o.indexprs IS NULL AND oc.relam = ic.relam
       AND coalesce(pg_get_expr(o.indpred, o.indrelid), '') = coalesce(pg_get_expr(i.indpred, i.indrelid), '')
       AND o.indnkeyatts >= i.indnkeyatts
       AND (o.indkey::int2[])[0:i.indnkeyatts - 1]      = (i.indkey::int2[])[0:i.indnkeyatts - 1]
       AND (o.indclass::oid[])[0:i.indnkeyatts - 1]     = (i.indclass::oid[])[0:i.indnkeyatts - 1]
       AND (o.indcollation::oid[])[0:i.indnkeyatts - 1] = (i.indcollation::oid[])[0:i.indnkeyatts - 1]
       AND (o.indoption::int2[])[0:i.indnkeyatts - 1]   = (i.indoption::int2[])[0:i.indnkeyatts - 1]
     GROUP BY 1
  $f$;

  -- ───────────────────────────────────────────────────────────────────
  -- LA LISTE ASSUMÉE — 22 entrées au 27/09/2026 : redondants mais EMPRUNTÉS
  -- (scans du 02/09 au 27/09 entre parenthèses). Motif commun : le retrait
  -- basculerait ces lectures sur l'index couvrant ; à mesurer (EXPLAIN sur
  -- les requêtes qui les empruntent) avant de décider, un par un.
  -- En ajouter une doit être un acte motivé, jamais un réflexe.
  -- ───────────────────────────────────────────────────────────────────
  CREATE TEMP TABLE _redondants_assumes(idx text) ON COMMIT DROP;
  INSERT INTO _redondants_assumes VALUES
    ('ingest.partner_catalog_staging_rows_run_idx'),            -- (19)
    ('public.assembleia_facilitators_assembleia_idx'),          -- (1)
    ('public.book_holdings_book_id_idx'),                       -- (10 819 302) sous UNIQUE (book_id, library_id)
    ('public.book_holdings_library_id_idx'),                    -- (715)
    ('public.catalog_batch_reviews_batch_id_idx'),              -- (2)
    ('public.circle_join_objections_request_idx'),              -- (1)
    ('public.digital_assets_bucket_name_idx'),                  -- (2)
    ('public.exemplares_library_id_idx'),                       -- (294)
    ('public.gazette_issue_locales_issue_idx'),                 -- (64)
    ('public.idx_audio_tracks_book_id'),                        -- (21)
    ('public.idx_author_translations_author_lang'),             -- (569) identique à UNIQUE (author_id, lang)
    ('public.idx_book_authors_book_id'),                        -- (1 289 679)
    ('public.idx_book_contributors_book_id'),                   -- (11 353)
    ('public.idx_book_digital_resources_book_id'),              -- (8 767)
    ('public.idx_book_draft_contributors_draft_id'),            -- (1 690)
    ('public.idx_consulta_linhas_v2_consulta_id'),              -- (4 324)
    ('public.idx_library_circulation_policy_rules_policy_set_id'), -- (143)
    ('public.idx_library_regulation_documents_library_id'),     -- (14)
    ('public.ix_user_library_memberships_user'),                -- (14 549)
    ('public.lettre_issue_locales_issue_idx'),                  -- (2)
    ('public.loan_cycle_notifications_item_idx'),               -- (19)
    ('public.recolement_scans_session_idx');                    -- (6)

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 aucun index redondant hors liste';
  BEGIN
    SELECT string_agg(r.idx || ' (couvert par ' || r.couvrant || ')', ', ' ORDER BY r.idx) INTO v_txt
      FROM pg_temp.b10_redondants() r
     WHERE NOT EXISTS (SELECT 1 FROM _redondants_assumes a WHERE a.idx = r.idx);
    IF v_txt IS NULL THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt
      || ' — ne pas créer un index que l''index couvrant sert déjà ; sinon, son entrée motivée ici'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 aucune entrée périmée dans la liste';
  BEGIN
    SELECT string_agg(a.idx, ', ' ORDER BY a.idx) INTO v_txt
      FROM _redondants_assumes a
     WHERE NOT EXISTS (SELECT 1 FROM pg_temp.b10_redondants() r WHERE r.idx = a.idx);
    IF v_txt IS NULL THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt
      || ' — retiré ou plus redondant : retirer l''entrée, la liste ne rétrécit que consciemment'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 le détecteur mord sur (a) sous (a, b), et seulement là';
  -- Tables TEMPORAIRES : rien n'entre dans public.
  BEGIN
    CREATE TEMP TABLE _b10_idx_epreuve(a int, b int, c text, d int);
    CREATE INDEX _b10_i1 ON _b10_idx_epreuve (a);                           -- redondant
    CREATE INDEX _b10_i2 ON _b10_idx_epreuve (a, b);
    CREATE INDEX _b10_i3 ON _b10_idx_epreuve (c text_pattern_ops);          -- autre classe : utile au LIKE 'x%'
    CREATE INDEX _b10_i4 ON _b10_idx_epreuve (c, d);
    CREATE INDEX _b10_i5 ON _b10_idx_epreuve (d) WHERE d > 0;               -- prédicat différent
    CREATE INDEX _b10_i6 ON _b10_idx_epreuve (d, a);
    CREATE INDEX _b10_i7 ON _b10_idx_epreuve (b) INCLUDE (c);               -- INCLUDE : lecture seule d'index
    CREATE INDEX _b10_i8 ON _b10_idx_epreuve (b, a);
    SELECT count(*), string_agg(split_part(idx, '.', 2), ',') INTO v_n, v_txt
      FROM pg_temp.b10_redondants('_b10_idx_epreuve'::regclass);
    DROP TABLE _b10_idx_epreuve;
    IF v_n = 1 AND v_txt = '_b10_i1' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : attendu _b10_i1 seul, lu ' || v_n || ' -> ' || coalesce(v_txt, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'INDEX_REDONDANTS_GARDE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'INDEX_REDONDANTS_GARDE OK : %/% tests passés (22 entrées assumées)', v_passed, v_passed;
END $$;
