-- =========================================================================
-- Anarchief.org — Stellingen et Theorie en praktijk selon la réponse de
-- l'archiviste du 20/10 ; les douze brouillons du lot 69 reçoivent leurs
-- autorités et, sans fichier, leur lien vers le wiki
-- =========================================================================
-- Date     : 2026-10-20
-- Chantier : sources partenaires — Anarchief.org (bibliothèque source)
-- Auteur   : Claude (assistant·e), pour la coordination
-- Session  : Anarchief — les 17 pages en doublon (reprise du 20/10)
-- Ref      : 20261019190037_anarchief_les_doublons_tranches_par_l_archiviste
--            (lignes requalifiées le 19/10) ;
--            20261019191616_anarchief_les_onze_brouillons_prennent_leur_cote
--            (cotes des onze brouillons du lot 69) ; mail de J/M du
--            20/10/2026 ; décision de Xavier du 20/10/2026 (« lance la
--            création ») ; journal d'accès d'Anarchief (hors dépôt)
--
-- POURQUOI
--   Le 19/10, faute de réponse, la page 1164 portait « Stellingen over
--   libertair municipalisme » et Theorie en praktijk attendait. L'archiviste
--   a répondu le 20/10 :
--     Stellingen      : garder la page 2962 (renommée sur le wiki) ; la page
--                       1164 est SUPPRIMÉE du wiki ;
--     Theorie en praktijk : garder la page 3027 « (s.d.) » (une numérisation
--                       qu'il veut garder) ; la page 322 (copie prise à une
--                       autre source) tombe.
--   Le brouillon 7680 (page 1164) n'est ni révisé ni publié : il est
--   supprimé, et la page 2962 devient le brouillon de la notice. Les deux
--   pages gardées rejoignent le lot 69, comme le ferait une promotion à
--   l'écran Importations (IMP-27 d : une promotion du run rejoint le lot
--   ouvert tant qu'aucune révision n'y est demandée).
--
--   Les autorités : la migration des auteurs d'Anarchief (20261019160041)
--   a lié les contributeurs des notices PUBLIÉES ; ces pages ne l'étaient
--   pas. Le lien se pose ici sur les brouillons — la publication le recopie
--   (fn_sync_book_contributors_on_publish) — avec les autorités que la
--   liste du 19/10 attribue aux mêmes graphies (Bakoenin 3, Kropotkin 5,
--   Bookchin 10, De Vieze Gasten 11593) et, pour les graphies que la liste
--   n'avait pas, l'autorité existante du même nom (Lorenzo Kom'boa Ervin 32,
--   Vera Figner 10592). « Ernestan » reste en texte, comme le 19/10 (D5 :
--   un nom seul, pas d'autorité).
--
--   Le lien vers le wiki : la même ressource que
--   private.fn_lien_vers_la_page_source (20261019144029), posée sur les
--   brouillons des neuf notices qui n'auront pas de PDF (Bakoenin ×3,
--   Figner ×3 — fichiers ODT —, La conquête du pain — ODT —, Stellingen,
--   Theorie). Les trois autres (2982, 2762, 1917) recevront leurs PDF par la
--   file NUMDIF. Sur les brouillons et non après publication : la fonction
--   rejouable prend la PLUS PETITE valeur import:33 d'une notice, et les
--   notices qui absorbent une page en recevront deux (1164 et 322 sont plus
--   petites que 2962 et 3027 : le lien irait vers la page tombée).
--
-- CE QUE FAIT LE PAQUET (donnée seule, run 33, lot 69)
--   1. Brouillon 7680 (page 1164) supprimé : le déclencheur de la corbeille
--      écarte sa ligne (8966, discarded_draft_id) et le journal du catalogage
--      garde son instantané ; la note de la ligne dit pourquoi.
--   2. Ligne 9345 (page 2962) et ligne 9400 (page 3027) : nouveautés
--      acceptées ; ligne 8828 (page 322) : rejetée, fondue dans 3027.
--   3. Leurs brouillons créés par ingest.fn_bulk_create_book_drafts_from_run
--      (le chemin de l'écran), au nom du compte qui a promu les onze autres
--      (celui de la coordination), puis tamponnés Anarchief.Org (ce que fait
--      fn_import_promote). Lot attendu : 69, sinon échec.
--   4. Cotes ANARCHIEF-2962 et ANARCHIEF-3027 (refus si déjà prises).
--   5. Autorités sur les contributeurs des brouillons du lot 69.
--   6. Lien vers la page du wiki (curid=<page>) sur neuf brouillons.
--   Rien de publié ici : révision et publication restent des gestes de la
--   coordination à l'écran.
--
--   Rejouable : déjà passée (la ligne 9345 a son brouillon), elle ne fait
--   rien ; au banc (run 33 absent), rien non plus. Tout autre état — lot 69
--   en révision, brouillon 7680 publié, autorité absente — fait échouer
--   plutôt qu'écrire à moitié.
--
-- CHECKLIST DOCTRINE
--   [x] Aucun objet nouveau ; écritures de lignes, sans verrou exclusif
--   [x] Liste fermée (id de ligne + clé + run ; ids d'autorités + nom)
--   [x] Aucun nom de lieu lié à l'archiviste (règle du 19/10/2026)
--   [x] Aucun contenu du wiki recopié (libellé et note fixes)
-- =========================================================================

BEGIN;

DO $decisions$
DECLARE
  c_lib    constant uuid   := '1bb157fd-4d1f-415b-9e5d-490f4f8d0895';   -- Anarchief.Org
  c_acteur constant uuid   := 'd6710372-e5e5-4608-800b-99a26817c677';   -- a promu les onze du lot 69
  c_lot    constant bigint := 69;
  c_gab    constant text   := 'https://anarchief.org/w/index.php?curid={id}';
  c_label  constant text   := 'Página da ficha no Anarchief.org';
  c_note   constant text   := 'Ligação para a página desta ficha no wiki de origem, acrescentada em 20/10/2026 '
                              || 'para as fichas sem arquivo digital, com o acordo do arquivista (mensagem de 19/10/2026).';
  -- Pages sans PDF : lien vers le wiki
  c_liens  constant text[] := ARRAY['234', '237', '240', '570', '572', '574', '591', '2962', '3027'];
  v_res  jsonb;
  v_n    int;
  v_m    int;
  v_err  text := '';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_import_runs WHERE id = 33)
     OR NOT EXISTS (SELECT 1 FROM public.libraries WHERE id = c_lib) THEN
    RAISE NOTICE 'Anarchief 20/10 : run 33 ou bibliothèque absents (banc), rien à faire';
    RETURN;
  END IF;

  IF EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
              WHERE id = 9345 AND run_id = 33 AND external_key = '2962'
                AND created_book_draft_id IS NOT NULL) THEN
    RAISE NOTICE 'Anarchief 20/10 : déjà appliquée, rien à faire';
    RETURN;
  END IF;

  -- ── L'état attendu, tout entier, avant la première écriture ──────────
  IF NOT EXISTS (SELECT 1 FROM public.catalog_batches b
                  WHERE b.id = c_lot AND b.status = 'open' AND b.library_id = c_lib
                    AND public.fn_batch_review_status(b.id) IS NULL) THEN
    v_err := v_err || ' lot 69 ouvert sans révision ;';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows sr
                   JOIN public.book_drafts d ON d.id = sr.created_book_draft_id
                  WHERE sr.id = 8966 AND sr.run_id = 33 AND sr.external_key = '1164'
                    AND d.id = 7680 AND d.batch_id = c_lot AND d.status = 'draft'
                    AND d.published_book_id IS NULL
                    AND (d.bib_ref IS NULL OR d.bib_ref = 'ANARCHIEF-1164')) THEN
    v_err := v_err || ' brouillon 7680 (page 1164) non publié dans le lot 69 ;';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                  WHERE id = 9345 AND run_id = 33 AND external_key = '2962'
                    AND editorial_decision = 'reject' AND created_book_draft_id IS NULL
                    AND created_exemplar_draft_id IS NULL AND discarded_draft_id IS NULL) THEN
    v_err := v_err || ' ligne 9345 (page 2962) rejetée sans brouillon ;';
  END IF;
  SELECT count(*) INTO v_n FROM ingest.partner_catalog_staging_rows
   WHERE run_id = 33 AND editorial_decision = 'pending' AND match_status = 'possible_duplicate'
     AND created_book_draft_id IS NULL AND created_exemplar_draft_id IS NULL AND discarded_draft_id IS NULL
     AND (id, external_key) IN ((9400, '3027'), (8828, '322'));
  IF v_n <> 2 THEN
    v_err := v_err || ' lignes 9400 (3027) et 8828 (322) en attente ;';
  END IF;
  SELECT count(*) INTO v_n FROM public.authors a
   WHERE (a.id, a.preferred_name) IN ((3, 'Mikhail Bakunin'), (5, 'Piotr Kropotkin'), (10, 'Murray Bookchin'),
                                      (32, 'Lorenzo Kom''boa Ervin'), (10592, 'Vera Figner'), (11593, 'De Vieze Gasten'));
  IF v_n <> 6 THEN
    v_err := v_err || ' six autorités attendues ;';
  END IF;
  IF EXISTS (SELECT 1 FROM public.books WHERE bib_ref IN ('ANARCHIEF-2962', 'ANARCHIEF-3027'))
     OR EXISTS (SELECT 1 FROM public.book_drafts WHERE bib_ref IN ('ANARCHIEF-2962', 'ANARCHIEF-3027')) THEN
    v_err := v_err || ' cotes ANARCHIEF-2962 / -3027 libres ;';
  END IF;
  IF v_err <> '' THEN
    RAISE EXCEPTION 'Anarchief 20/10 : état inattendu —%', v_err;
  END IF;

  -- ── 1. Le brouillon de la page 1164 quitte le lot ────────────────────
  DELETE FROM public.book_drafts WHERE id = 7680 AND batch_id = c_lot AND published_book_id IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'Anarchief 20/10 : brouillon 7680 non supprimé';
  END IF;
  UPDATE ingest.partner_catalog_staging_rows sr
     SET editorial_note = 'Page supprimée du wiki par l''archiviste : la notice tient sur la page 2962 '
                          || '(ANARCHIEF-2962), réponse de J/M du 20/10/2026. Brouillon 7680 supprimé avant révision.',
         warnings = coalesce(sr.warnings, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
           'kind', 'doublon_tranche', 'geste', 'fondue', 'dans', '2962', 'le', '2026-10-20',
           'motif', 'Page supprimée du wiki (réponse de J/M du 20/10/2026).'))
   WHERE sr.id = 8966 AND sr.run_id = 33 AND sr.external_key = '1164'
     AND sr.discarded_draft_id = 7680 AND sr.editorial_decision = 'reject';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'Anarchief 20/10 : ligne 8966 non écartée par la suppression du brouillon';
  END IF;

  -- ── 2. Les deux pages gardées, la page qui tombe ──────────────────────
  UPDATE ingest.partner_catalog_staging_rows sr
     SET match_status = 'new_record',
         proposed_book_id = NULL,
         proposed_book_draft_id = NULL,
         confidence = 0,
         editorial_decision = 'accept_new',
         review_status = 'approved',
         selected_for_draft = false,
         editorial_decided_at = now(),
         editorial_note = CASE sr.external_key
           WHEN '2962' THEN 'Page gardée par l''archiviste ; la page 1164 est supprimée du wiki (réponse de J/M du 20/10/2026).'
           ELSE 'Page gardée par l''archiviste ; la page 322 tombe (réponse de J/M du 20/10/2026).' END,
         warnings = coalesce(sr.warnings, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
           'kind', 'doublon_tranche', 'geste', 'nouveaute', 'le', '2026-10-20',
           'motif', 'Page gardée par l''archiviste (réponse de J/M du 20/10/2026).',
           'avant', jsonb_build_object('match_status', sr.match_status,
                                       'editorial_decision', sr.editorial_decision,
                                       'review_status', sr.review_status,
                                       'editorial_note', sr.editorial_note)))
   WHERE sr.run_id = 33 AND (sr.id, sr.external_key) IN ((9345, '2962'), (9400, '3027'))
     AND sr.created_book_draft_id IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;

  UPDATE ingest.partner_catalog_staging_rows sr
     SET editorial_decision = 'reject',
         review_status = 'rejected',
         selected_for_draft = false,
         editorial_decided_at = now(),
         editorial_note = 'Fondue dans ANARCHIEF-3027 : même texte, l''archiviste garde la page 3027 (réponse de J/M du 20/10/2026).',
         warnings = coalesce(sr.warnings, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
           'kind', 'doublon_tranche', 'geste', 'fondue', 'dans', '3027', 'le', '2026-10-20'))
   WHERE sr.run_id = 33 AND sr.id = 8828 AND sr.external_key = '322'
     AND sr.editorial_decision = 'pending' AND sr.created_book_draft_id IS NULL;
  GET DIAGNOSTICS v_m = ROW_COUNT;
  IF v_n <> 2 OR v_m <> 1 THEN
    RAISE EXCEPTION 'Anarchief 20/10 : % page(s) gardée(s) (2 attendues), % tombée(s) (1 attendue)', v_n, v_m;
  END IF;

  -- ── 3. Leurs brouillons, dans le lot 69 ──────────────────────────────
  v_res := ingest.fn_bulk_create_book_drafts_from_run(
    p_run_id := 33, p_match_statuses := NULL, p_editorial_decisions := NULL,
    p_batch_name := NULL, p_batch_notes := NULL,
    p_created_by := c_acteur, p_row_ids := ARRAY[9345, 9400]::bigint[]);
  IF coalesce((v_res->>'created_drafts')::int, 0) <> 2
     OR (v_res->>'batch_id')::bigint IS DISTINCT FROM c_lot THEN
    RAISE EXCEPTION 'Anarchief 20/10 : promotion inattendue : %', v_res;
  END IF;

  UPDATE public.book_drafts d
     SET owner_library_id = l.id,
         owner_library    = l.name
    FROM public.libraries l
   WHERE l.id = c_lib AND d.batch_id = c_lot AND d.owner_library_id IS NULL;

  -- ── 4. Cotes ANARCHIEF-<page> ─────────────────────────────────────────
  UPDATE public.book_drafts d
     SET bib_ref = 'ANARCHIEF-' || sr.external_key
    FROM ingest.partner_catalog_staging_rows sr
   WHERE d.id = sr.created_book_draft_id
     AND sr.run_id = 33 AND (sr.id, sr.external_key) IN ((9345, '2962'), (9400, '3027'))
     AND d.batch_id = c_lot AND d.bib_ref IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'Anarchief 20/10 : % cote(s) posée(s), 2 attendues', v_n;
  END IF;

  -- ── 5. Autorités des contributeurs du lot ─────────────────────────────
  UPDATE public.book_draft_contributors c
     SET author_id = m.autorite,
         nature = a.authority_type
    FROM (VALUES ('Michael Bakoenin', 3::bigint), ('Pierre Kropotkine', 5), ('Peter Kropotkin', 5),
                 ('Murray Bookchin', 10), ('De vieze gasten', 11593),
                 ('Lorenzo Kom''boa Ervin', 32), ('Vera Figner', 10592)) AS m(nom, autorite)
    JOIN public.authors a ON a.id = m.autorite
   WHERE c.name = m.nom AND c.author_id IS NULL
     AND c.draft_id IN (SELECT d.id FROM public.book_drafts d WHERE d.batch_id = c_lot);
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 11 THEN
    RAISE EXCEPTION 'Anarchief 20/10 : % contributeur(s) lié(s), 11 attendus (12 notices, Ernestan en texte)', v_n;
  END IF;

  -- ── 6. Lien vers la page du wiki, pour les notices sans PDF ───────────
  INSERT INTO public.book_draft_digital_resources (
    book_draft_id, resource_type, usage_type, access_scope, status, is_active,
    mime_type, label, notes, language_code, source_name, source_url,
    source_page_url, attribution_text, is_primary, bibliographic_match_validated, metadata)
  SELECT d.id, 'link_externo', 'link_externo', 'publico', 'draft', true,
         'text/html', c_label, c_note, 'nl', 'Anarchief.org',
         replace(c_gab, '{id}', sr.external_key),
         replace(c_gab, '{id}', sr.external_key),
         'Fonte: Anarchief.org (página ' || sr.external_key || ')',
         false, true,
         jsonb_build_object('source_identifier', sr.external_key,
                            'source_scheme', 'import:33',
                            'added_via', 'migration 20261020182804')
    FROM ingest.partner_catalog_staging_rows sr
    JOIN public.book_drafts d ON d.id = sr.created_book_draft_id
   WHERE sr.run_id = 33 AND sr.external_key = ANY (c_liens)
     AND d.batch_id = c_lot
     AND NOT EXISTS (SELECT 1 FROM public.book_draft_digital_resources r WHERE r.book_draft_id = d.id);
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 9 THEN
    RAISE EXCEPTION 'Anarchief 20/10 : % lien(s) posé(s), 9 attendus', v_n;
  END IF;

  -- ── Bilan ─────────────────────────────────────────────────────────────
  SELECT count(*) INTO v_n
    FROM public.book_drafts d
    JOIN ingest.partner_catalog_staging_rows sr ON sr.created_book_draft_id = d.id AND sr.run_id = 33
   WHERE d.batch_id = c_lot AND d.owner_library_id = c_lib AND d.published_book_id IS NULL
     AND d.bib_ref = 'ANARCHIEF-' || sr.external_key;
  SELECT count(*) INTO v_m FROM public.book_drafts d WHERE d.batch_id = c_lot;
  IF v_n <> 12 OR v_m <> 12 THEN
    RAISE EXCEPTION 'Anarchief 20/10 : lot 69 = % brouillon(s), dont % à leur cote (12 attendus)', v_m, v_n;
  END IF;

  PERFORM ingest.fn_refresh_partner_catalog_run_counters(33);
  RAISE NOTICE 'Anarchief 20/10 : lot 69 = 12 brouillons (2962 et 3027 ajoutés, 1164 retiré), 11 autorités, 9 liens';
END
$decisions$;

COMMIT;

-- =========================================================================
-- Suite (hors de ce paquet) : la coordination demande puis approuve la
-- révision du lot 69 et le publie (12 notices, 0 exemplaire : source 33
-- sans_exemplaire). Ensuite : les identifiants import:33 des pages fondues
-- (3297, 4605, 3898, 1164, 322) sur les notices qui les absorbent, et les
-- PDF par la file NUMDIF.
-- Retour : les traces « doublon_tranche » du 20/10 rendent l'état d'avant
-- des lignes ; le brouillon 7680 se relit dans le journal du catalogage
-- (catalog_audit_log, action delete).
-- =========================================================================
