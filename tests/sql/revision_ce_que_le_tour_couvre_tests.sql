-- =====================================================================
-- AnarBib — Tests d'acceptation : ce que couvre un tour de révision
-- (H21 lot 0, REGISTRE IMP-27 b et c, décisions de Xavier du 29/09/2026)
-- Date    : 2026-09-29 ; seconde passe le 2026-09-30 (revue, constat #17 : T9 réécrit, T22) ;
--           troisième passe le 2026-09-30 (constat #17 : un exemplaire SANS notice dans le
--           décor de T9, que le rattrapage doit lister et qui se publie sous le tour rattrapé) ;
--           quatrième passe le 2026-09-30 (les deux verdicts #17 de la troisième : T9b —
--           exemplaires RAPPROCHÉS en brouillon, prêt et publié dans le lot rattrapé, republication
--           du publié ; un tour d'avant le 29/09 encore « requested ») ;
--           H21 lot 1 le 2026-10-05 (REGISTRE IMP-28 d : un exemplaire RATTACHÉ à une
--           notice importée passe la porte de révision des rapprochés, et
--           fn_batch_ajouts_apres_revision le compte — T18, T21 et l'en-tête réécrits ;
--           le parcours entier : tests/sql/h21_lot1_reconnaitre_tests.sql, T12-T14)
-- Ref     : migration 20261001200931_h21_lot0_la_revision_suit_le_brouillon_importe ;
--           migration 20261005103427_h21_lot1_reconnaitre_une_notice_deja_importee
--
-- (b) L'approbation d'un tour couvre les brouillons que CE tour a soumis
--     (catalog_batch_reviews.draft_ids / exemplar_draft_ids, figés à la
--     DEMANDE par fn_batch_review_request). Un brouillon rangé ensuite dans
--     le lot attend un nouveau tour (HINT error.publish.added_after_review),
--     que la coordination peut demander elle-même (fn_batch_ajouts_apres_revision
--     > 0).
--     Les tours d'avant le 29/09 couvrent ce que leur lot contenait ce jour-là :
--     la migration remplit les listes de ces tours, approuvés ou encore demandés,
--     du contenu non annulé du lot, exemplaires rattachés à une notice ou non
--     (private.fn_h21_rattraper_listes_des_tours) ; T9 et T9b jouent cette même
--     fonction. Une liste NULL ne subsiste que dans un
--     tour ÉCRIT sans elle (fixtures) : il couvre son lot. C'est une garde de
--     compatibilité (T22), pas « le tour d'avant le 29/09 ».
--     Amendement de la migration (29/09) : draft_ids = brouillons de notice du
--     lot en draft, ready ET published (une republication ne redevient pas
--     « ajoutée ») ; exemplar_draft_ids = TOUS les brouillons d'exemplaire du
--     lot en draft, ready, published, rattachés à une notice ou non (l'absorption
--     de leur notice les détache sans les avoir rangés après la demande).
--     fn_batch_ajouts_apres_revision ne compte toujours que les vivants
--     (draft/ready) hors liste — exemplaires rattachés à une notice compris
--     depuis le H21 lot 1 (IMP-28 d, 05/10) : ils attendent un tour comme les
--     autres.
-- (c) Un lot né d'un RAPPROCHEMENT (exemplaires sans notice, venus d'une
--     ligne d'import) est importé : l'exemplaire rapproché ne se publie que
--     dans un lot, après une révision approuvée qui le couvre ; un exemplaire
--     fait à la main rangé dans ce lot attend avec lui. Un exemplaire
--     rattaché à une notice (book_draft_id) ne se publie qu'après elle, et,
--     depuis le H21 lot 1 (IMP-28 d), passe la même porte que le rapproché :
--     publish_book_draft ne publie avec la notice que ceux que le tour couvre.
--
-- T1  (b) demande : la liste figée = brouillons du lot hors corbeille (ici draft/ready ;
--         les publiés : T6, T19).
-- T2  (b) lot approuvé SANS ajout : la coordination ne redemande pas (already_approved).
-- T3  (b) brouillon importé d'un autre lot, rangé après l'approbation (API) :
--         added_after_review, rien de publié.
-- T4  (b) les brouillons couverts se publient.
-- T5  (b) fn_batch_ajouts_apres_revision = 1 ; fn_batch_reviews_list.after_review = 1
--         (jeton de la coordination).
-- T6  (b) la coordination (pas l'administration) redemande un tour : accepté,
--         liste du tour 2 = tout le lot hors corbeille, d1 (publié en T4)
--         compris ; la garde se referme pendant le tour.
-- T7  (b) tour 2 approuvé : le brouillon ajouté se publie ; plus d'ajout.
-- T8  (b) brouillon fait à la main rangé PENDANT le tour « requested » : non
--         couvert par l'approbation qui suit (contagion du lot importé).
-- T9  (b) tour d'avant le 29/09 (approuvé, inséré sans liste) dans un lot qui
--         contient un brouillon, un prêt, une notice publiée, un exemplaire
--         rattaché et un exemplaire SANS notice fait à la main (x5m, rangé par la
--         coordination avant le tour ; plus, à la corbeille, une notice et un
--         exemplaire) : private.fn_h21_rattraper_listes_des_tours, la fonction que
--         joue la migration, remplit ses listes avec le contenu non annulé du lot,
--         publiés et exemplaires rattachés ou sans notice compris (liste triée
--         d'exemplaires = x5 et x5m). Elle ne touche pas un tour qui a déjà sa liste
--         (celui de T8). Un brouillon rangé APRÈS le rattrapage : added_after_review,
--         ajouts = 1. Le prêt se publie, la notice publiée se republie, et x5m se
--         publie sur sa notice détenue SANS nouveau tour (le lot n'a encore que le
--         tour rattrapé) : c'est le seul genre d'exemplaire dont publish_exemplar_draft
--         consulte la liste. Puis la coordination redemande un tour (le tour 2
--         soumet l'ajout). La notice publiée est faite à la main et rangée par le
--         décor : T9 ne passe pas par la garde de compatibilité.
-- T9b (b, c) le rattrapage et les exemplaires SANS notice qu'un tour d'avant le 29/09 a
--         pu couvrir. Lot 12 : né d'une promotion (d12) ; la coordination y a rangé par
--         l'API, avant le tour, les quatre exemplaires d'un « Rapprocher »
--         (fn_import_reconcile_duplicates) ; tour approuvé, inséré sans liste. Avant la
--         migration : x12c PUBLIÉ par publish_exemplar_draft — le statut « publié » d'un
--         brouillon d'exemplaire ne se pose plus par l'API (exemplar_drafts_statut_publie_reserve) ;
--         la garde de compatibilité le couvre, comme la publication d'avant le 29/09, qui ne
--         lisait aucune liste —, x12b passé « prêt » et x12d mis à la corbeille par l'API.
--         Lot 13 : né d'une promotion (d13), tour d'avant le 29/09 encore « requested »,
--         sans liste. Le rattrapage remplit les deux : lot 12 = d12 et x12a, x12b, x12c
--         (triés, pas x12d) ; lot 13 = d13 et aucun exemplaire. Lot 12 : ajouts = 0 ; x12a et
--         x12b se publient sur la notice détenue ; x12c, retouché par l'API (rayon), se
--         republie sur le MÊME exemplaire, mis à jour, sans nouveau tour. Lot 13 : approuvé
--         après la migration ; une notice et un exemplaire sans notice faits à la main,
--         rangés ensuite par l'API : ajouts = 2, added_after_review tous deux ; d13 se publie.
-- T10 (b) publish_catalog_batch d'un lot approuvé avec un ajout : refus, tout ou rien.
-- T11 (c) « Rapprocher » : exemplaires dans leur lot ; fn_batch_is_imported vrai.
-- T12 (c) exemplaire rapproché avant révision : review_required, rien de publié.
-- T13 (c) la révision d'un lot de rapprochement se demande ; liste d'exemplaires figée.
-- T14 (c) après approbation : l'exemplaire rapproché se publie.
-- T15 (c) exemplaire rapproché sorti du lot (API) : imported_needs_batch.
-- T16 (c) exemplaire fait à la main rangé dans le lot rapproché après la demande :
--         added_after_review ; un exemplaire couvert se publie, lui.
-- T17 (c) exemplaire fait à la main, lot fait à la main ou sans lot : publié
--         (non-régression).
-- T18     exemplaire importé RATTACHÉ à une notice : pas avant elle ; il figure
--         dans la liste d'exemplaires du tour (amendement) et c'est elle qui le
--         rend publiable (IMP-28 d) : publié avec sa notice après révision, puis,
--         republié seul, il passe la porte (le tour approuvé le couvre).
-- T19 (b) republication : d19 publié sous le tour 1 ; une notice ajoutée à la
--         main, la coordination redemande (tour 2), l'administration approuve ;
--         republier d19 (brouillon au statut published, comme la file) passe :
--         il figure dans draft_ids du tour 2 ; la notice est mise à jour, pas
--         dupliquée.
-- T20 (b) exemplaire détaché : notice importée avec son exemplaire (promotion
--         d'une ligne qui en porte) ; demande, approbation ; api.merge_draft_into_book
--         l'absorbe dans une notice existante DÉTENUE par la bibliothèque
--         (exemplaire détaché, book_draft_id NULL) : pas un ajout, et
--         publish_exemplar_draft passe — il figurait dans exemplar_draft_ids.
-- T21 (b) fn_batch_ajouts_apres_revision (et after_review) ne compte que les
--         brouillons vivants (draft/ready) hors liste : ni corbeille, ni publiés ;
--         l'exemplaire RATTACHÉ rangé après la demande compte (IMP-28 d, 05/10 :
--         il attendait sans que la coordination puisse redemander un tour).
-- T22     garde de compatibilité : un tour ÉCRIT sans liste (une fixture ; après
--         le rattrapage de la migration, plus aucun tour de production) couvre son
--         lot, même un brouillon rangé après (ajouts = 0, les deux se publient).
--
-- Contre-épreuves (définition d'avant le lot 0, ou mutant, rejoué avant la suite ;
-- toutes rejouées le 30/09 après la quatrième passe — T9b ajouté —, 23/23 avec la
-- migration ; les chiffres ci-dessous sont ceux de ce rejeu) :
--   ancien-publish_book_draft.sql      : 15/23 — T3, T8, T9, T9b, T10 tombent (le brouillon
--                                        rangé après se publie ; en T9b, la notice rangée
--                                        après l'approbation du tour rattrapé) ; T5, T6, T7
--                                        par cascade (le brouillon ajouté, publié dès T3, ne
--                                        se compte plus ni ne se redemande) ;
--   ancien-publish_exemplar_draft.sql  : 19/23 — T9b (l'exemplaire fait à la main rangé
--                                        après l'approbation du tour rattrapé se publie),
--                                        T12, T15, T16 tombent (T13 ne tombe plus par
--                                        cascade : la liste garde l'exemplaire publié en T12) ;
--   ancien-fn_batch_is_imported.sql    : 18/23 — T11, T12, T13, T16 tombent ; T14 par
--                                        cascade (pas de tour à approuver) ;
--   ancien-fn_batch_review_request.sql : 10/23 — T1, T3, T5, T6, T8, T10, T13, T16,
--                                        T19 (la coordination ne rouvre pas), T20 (rien
--                                        de figé) tombent ; T9 aussi (la coordination ne
--                                        rouvre pas, et le rattrapage remplit les tours
--                                        restés sans liste, celui de T8 avec dh) ; T7,
--                                        T21 par cascade (T9b ne demande aucun tour) ;
--   mutant « listes de la version première » (Tb-mutant-liste-premiere.sql :
--     fn_batch_review_request vivante, draft_ids = draft/ready, exemplar_draft_ids = sans
--     notice, draft/ready) :             19/23 — T6, T18, T19, T20 tombent ;
--   mutant fn_batch_ajouts_apres_revision « tout sauf la corbeille »
--     (Tb-mutant-ajouts-statuts.sql) : 22/23 — T21 ;
--   mutant fn_batch_ajouts_apres_revision « exemplaires rattachés comptés »
--     (Tb-mutant-ajouts-rattaches.sql) : 22/23 — T21 ; depuis le H21 lot 1 (IMP-28 d),
--     ce « mutant » est la règle, et c'est la définition du lot 0 (rattachés NON
--     comptés) qui fait tomber T21 (contre-épreuve du 05/10, h21_lot1_reconnaitre_tests.sql) ;
--   mutants de private.fn_h21_rattraper_listes_des_tours :
--     B17-mutant-rattrapage-sans-rattaches.sql  22/23 — T9 seul (exemplaires sans notice
--                                                seuls : x5 hors liste),
--     B17-mutant-rattrapage-sans-publies.sql    22/23 — T9 seul (la notice publiée hors
--                                                liste : sa republication est refusée),
--     C17-mutant-rattrapage-rattaches-seuls.sql 21/23 — T9, T9b (x.book_draft_id is not
--                                                null : rattachés seuls ; T9 : x5m hors liste,
--                                                ajouts = 2, sa publication refusée
--                                                added_after_review ; T9b : lot 12 sans
--                                                exemplaire, les trois refusés),
--     B17-mutant-rattrapage-vide.sql            21/23 — T9, T9b (listes laissées NULL : le
--                                                brouillon rangé après se publie, ajouts = 0,
--                                                la coordination ne rouvre pas — ce
--                                                qu'affirmait l'ancien T9 ; T9b : les ajouts
--                                                du lot 13 se publient),
--     B17-mutant-rattrapage-tous-les-tours.sql  21/23 — T9, T9b (recalcule aussi les tours
--                                                listés : celui de T8 couvrirait dh ; T9b :
--                                                7 tours réécrits pour 2 sans liste),
--     et, quatrième passe (verdicts #17 de la troisième), chacun 22/23 — T9b seul, T9
--     restant vert :
--     sk2-17/M1-rattrapage-exemplaires-brouillons-seuls.sql (x.status = 'draft') : lot 12
--                                                = x12a seul ; ajouts = 1 ; le prêt et la
--                                                republication refusés added_after_review,
--     sk2-17/M1p-rattrapage-exemplaires-sans-publies.sql et
--     SK1p3-17-mutant-rattrapage-sans-exemplaires-publies.sql (x.status in ('draft',
--                                                'ready') : les listes de la version première)
--                                                : x12c hors liste, sa republication refusée
--                                                avec ajouts = 0 (mesuré) — l'impasse relevée
--                                                à la troisième passe : la règle de T2 refuse
--                                                alors un nouveau tour à la coordination,
--     sk2-17/M2-rattrapage-sans-rapproches.sql et
--     SK1p3-17-mutant-rattrapage-sans-rapproches.sql (rapprochés exclus : book_draft_id
--                                                NULL et ligne d'import posée) : lot 12 sans
--                                                exemplaire, ajouts = 2, les trois refusés,
--     sk2-17/M3-rattrapage-tours-approuves-seuls.sql (r.status = 'approved') : le tour
--                                                requested du lot 13 garde des listes NULL
--                                                (1 rattrapé sur 2) ; approuvé, il couvre les
--                                                deux ajouts, qui se publient, ajouts = 0 ;
--   B17-mutant-couvre-null-rien.sql (fn_batch_review_couvre : une liste NULL ne couvre
--     rien) : 21/23 — T22, et T9b AU DÉCOR (x12c ne se publie pas sous le tour d'avant le
--     29/09, sans liste : « decor : x12c non publie ») ; T9 ne dépend pas de la garde de
--     compatibilité, T9b seulement pour poser l'état publié d'avant la migration.
--   T2, T4, T17 : non-régression (ne tombent avec aucune).
--   Les fichiers : …\scratchpad\h21-lot0-agents\ (ancien-*, Tb-*, B17-*, C17-*, SK1p3-17-*,
--   sk2-17\M*) ; rejeu : P4\C\contre.sh (noms des tests tombés), P4\C\contre-t9b.sh.
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'REVISION-TOUR-COUVRE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_admin uuid := '22222222-2222-2222-2222-222222222222';  -- compte sans rôle (seed) -> admin réseau ici
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF de test (seed)
  v_src bigint;
  v_run1 bigint; v_run2 bigint; v_run3 bigint; v_run5 bigint; v_run6 bigint; v_run6b bigint; v_run7 bigint; v_run8 bigint;
  v_lot1 bigint; v_lot2 bigint; v_lot3 bigint; v_lot5 bigint; v_lot6 bigint; v_lot6b bigint; v_lotr bigint; v_lotm bigint; v_lot8 bigint;
  v_d1 bigint; v_d2 bigint; v_dc bigint; v_d3 bigint; v_d4 bigint; v_dh bigint; v_d6 bigint; v_d7 bigint;
  v_d8 bigint; v_d9 bigint; v_d10 bigint; v_d11 bigint;
  v_rev1 bigint; v_rev2 bigint; v_rev3 bigint; v_rev6 bigint; v_revr bigint; v_rev8 bigint;
  v_book0 bigint; v_r7 bigint; v_x1 bigint; v_x2 bigint; v_x3 bigint; v_xm bigint; v_xhm bigint; v_xsl bigint; v_xn bigint;
  v_res jsonb; v_hint text; v_hint2 text; v_n int; v_m int; v_ok boolean; v_txt text; v_id bigint;
  -- amendement 1 (T19-T21)
  v_run9 bigint; v_run10 bigint; v_lot9 bigint; v_lot10 bigint; v_d19 bigint; v_dh9 bigint; v_d20 bigint; v_xd bigint;
  v_rev9a bigint; v_rev9b bigint; v_rev10 bigint; v_book19 bigint; v_book20 bigint; v_k int;
  -- seconde passe (T9 réécrit, T22)
  v_d6r bigint; v_d5c bigint; v_d6p bigint; v_x5 bigint; v_x5c bigint; v_rev5 bigint; v_rev5b bigint; v_book5 bigint;
  v_hint3 text; v_listes text; v_run11 bigint; v_lot11 bigint; v_d22 bigint; v_d22h bigint;
  -- troisième passe (T9 : un exemplaire sans notice dans le lot rattrapé)
  v_x5m bigint; v_book5m bigint; v_hint4 text; v_id2 bigint; v_tours int;
  -- quatrième passe (T9b : rapprochés prêts et publiés dans le lot rattrapé ; tour requested)
  v_book12 bigint; v_run12 bigint; v_run12r bigint; v_lot12 bigint; v_lot12r bigint; v_r12 bigint; v_d12 bigint;
  v_x12a bigint; v_x12b bigint; v_x12c bigint; v_x12d bigint; v_rev12 bigint; v_e12a bigint; v_e12b bigint; v_e12c bigint; v_e12c2 bigint;
  v_run13 bigint; v_lot13 bigint; v_d13 bigint; v_dh13 bigint; v_x13m bigint; v_rev13 bigint; v_m2 int; v_tours13 int;
  v_hint5 text; v_hint6 text; v_hint7 text; v_listes2 text; v_rayon text;
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');
  INSERT INTO public.catalog_ref_source_partners (code, label, sort_order, is_active)
  VALUES ('other_partner', 'Outro parceiro', 80, true) ON CONFLICT (code) DO NOTHING;
  -- Une série de tombos pour la bibliothèque de test (exemplaires automatiques et rapprochés).
  UPDATE public.libraries SET tombo_pattern = '{"prefix": "H21TC-T-", "year": false, "pad": 4}'::jsonb WHERE id = v_lib;

  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('H21TC Essai tour de revision', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO v_src;

  -- ── Décor : des lots nés d'une promotion (un run par lot : IMP-27 d ne joue pas) ──
  -- R1 -> lot 1 : d1 (brouillon), d2 (prêt), dc (à la corbeille avant la demande)
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h21tc-1.marc', 'h21tc-1.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run1;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
  VALUES (v_run1, 1, 'H21TC-1-1', 'H21TC Couverte un', 'new_record', 'accept_new', '{"items": []}'::jsonb),
         (v_run1, 2, 'H21TC-1-2', 'H21TC Couverte deux', 'new_record', 'accept_new', '{"items": []}'::jsonb),
         (v_run1, 3, 'H21TC-1-3', 'H21TC A la corbeille', 'new_record', 'accept_new', '{"items": []}'::jsonb);
  v_lot1 := (public.fn_import_promote(v_run1, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
  SELECT m.draft_id INTO v_d1 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run1 AND s.row_no = 1;
  SELECT m.draft_id INTO v_d2 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run1 AND s.row_no = 2;
  SELECT m.draft_id INTO v_dc FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run1 AND s.row_no = 3;
  -- R2 -> lot 2 : d3, qui sera rangé dans le lot 1 après son approbation
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h21tc-2.marc', 'h21tc-2.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run2;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
  VALUES (v_run2, 1, 'H21TC-2-1', 'H21TC Venue d''un autre lot', 'new_record', 'accept_new', '{"items": []}'::jsonb);
  v_lot2 := (public.fn_import_promote(v_run2, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
  SELECT m.draft_id INTO v_d3 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run2;
  -- R3 -> lot 3 : d4 (T8)
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h21tc-3.marc', 'h21tc-3.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run3;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
  VALUES (v_run3, 1, 'H21TC-3-1', 'H21TC Soumise au tour requested', 'new_record', 'accept_new', '{"items": []}'::jsonb);
  v_lot3 := (public.fn_import_promote(v_run3, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
  SELECT m.draft_id INTO v_d4 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run3;
  -- R5 -> lot 5 (T9, un lot révisé avant le 29/09) : d6 (brouillon) et ses deux exemplaires du
  -- fichier, rattachés (x5 vivant, x5c à la corbeille) ; d6r (prêt) ; d5c (à la corbeille) ;
  -- T9 y range d6p, une notice publiée.
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h21tc-5.marc', 'h21tc-5.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run5;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
  VALUES (v_run5, 1, 'H21TC-5-1', 'H21TC Sous un tour ancien', 'new_record', 'accept_new',
          '{"items": [{"source_item_code": "H21TC-OLD-1", "call_number": "O1"},
                      {"source_item_code": "H21TC-OLD-2", "call_number": "O2"}]}'::jsonb),
         (v_run5, 2, 'H21TC-5-2', 'H21TC Prete sous un tour ancien', 'new_record', 'accept_new', '{"items": []}'::jsonb),
         (v_run5, 3, 'H21TC-5-3', 'H21TC A la corbeille sous un tour ancien', 'new_record', 'accept_new', '{"items": []}'::jsonb);
  v_lot5 := (public.fn_import_promote(v_run5, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
  SELECT m.draft_id INTO v_d6 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run5 AND s.row_no = 1;
  SELECT m.draft_id INTO v_d6r FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run5 AND s.row_no = 2;
  SELECT m.draft_id INTO v_d5c FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run5 AND s.row_no = 3;
  SELECT x.id INTO v_x5 FROM public.exemplar_drafts x WHERE x.book_draft_id = v_d6 AND x.source_item_code = 'H21TC-OLD-1';
  SELECT x.id INTO v_x5c FROM public.exemplar_drafts x WHERE x.book_draft_id = v_d6 AND x.source_item_code = 'H21TC-OLD-2';
  -- R6 -> lot 6 : d8, d9 ; R6b -> lot 6b : d10, qui sera rangé dans le lot 6 (T10)
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h21tc-6.marc', 'h21tc-6.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run6;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
  VALUES (v_run6, 1, 'H21TC-6-1', 'H21TC Lot entier un', 'new_record', 'accept_new', '{"items": []}'::jsonb),
         (v_run6, 2, 'H21TC-6-2', 'H21TC Lot entier deux', 'new_record', 'accept_new', '{"items": []}'::jsonb);
  v_lot6 := (public.fn_import_promote(v_run6, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
  SELECT m.draft_id INTO v_d8 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run6 AND s.row_no = 1;
  SELECT m.draft_id INTO v_d9 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run6 AND s.row_no = 2;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h21tc-6b.marc', 'h21tc-6b.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run6b;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
  VALUES (v_run6b, 1, 'H21TC-6b-1', 'H21TC Rangee dans le lot entier', 'new_record', 'accept_new', '{"items": []}'::jsonb);
  v_lot6b := (public.fn_import_promote(v_run6b, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
  SELECT m.draft_id INTO v_d10 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run6b;
  -- R8 -> lot 8 : d11 avec UN exemplaire du fichier, rattaché (T18)
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h21tc-8.marc', 'h21tc-8.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run8;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
  VALUES (v_run8, 1, 'H21TC-8-1', 'H21TC Notice a exemplaire du fichier', 'new_record', 'accept_new',
          '{"items": [{"source_item_code": "H21TC-NOT-1", "call_number": "H21TC"}]}'::jsonb);
  v_lot8 := (public.fn_import_promote(v_run8, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
  SELECT m.draft_id INTO v_d11 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run8;
  SELECT x.id INTO v_xn FROM public.exemplar_drafts x WHERE x.book_draft_id = v_d11;

  -- Les cotes, comme fn_batch_assign_bib_refs les poserait (postgres : hors déclencheurs d'API).
  UPDATE public.book_drafts SET bib_ref = 'H21TC-REF-' || id, tipo_material = 'livro'
   WHERE id IN (v_d1, v_d2, v_dc, v_d3, v_d4, v_d6, v_d6r, v_d5c, v_d8, v_d9, v_d10, v_d11);
  UPDATE public.book_drafts SET status = 'ready' WHERE id IN (v_d2, v_d6r);
  UPDATE public.book_drafts SET status = 'cancelled' WHERE id IN (v_dc, v_d5c);
  UPDATE public.exemplar_drafts SET status = 'cancelled' WHERE id = v_x5c;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 (b) la demande fige ce que le tour soumet : brouillons du lot (draft/ready ; publies : T6), pas la corbeille';
  BEGIN
    v_res := public.fn_batch_review_request(v_lot1, 'H21TC : premier tour');
    v_rev1 := (v_res->>'review_id')::bigint;
    IF (SELECT r.draft_ids = ARRAY[least(v_d1, v_d2), greatest(v_d1, v_d2)]
               AND r.exemplar_draft_ids = '{}'::bigint[] AND r.status = 'requested'
          FROM public.catalog_batch_reviews r WHERE r.id = v_rev1)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce((SELECT 'draft_ids='||coalesce(r.draft_ids::text,'NULL')||' exemplar_draft_ids='||coalesce(r.exemplar_draft_ids::text,'NULL')
                                                                                       FROM public.catalog_batch_reviews r WHERE r.id = v_rev1), 'aucun tour')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 (b) lot approuve sans ajout : la coordination ne redemande pas (non-regression)';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict(v_rev1, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_hint := NULL;
    BEGIN
      PERFORM public.fn_batch_review_request(v_lot1, 'H21TC : sans raison');
      v_hint := 'acceptee';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    END;
    IF v_hint = 'error.review.already_approved' AND public.fn_batch_review_status(v_lot1) = 'approved'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : redemande='||coalesce(v_hint,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 (b) brouillon importe d''un autre lot, range apres l''approbation : added_after_review, rien de publie';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET batch_id = v_lot1 WHERE id = v_d3;
    EXECUTE 'RESET ROLE';
    IF (SELECT batch_id FROM public.book_drafts WHERE id = v_d3) IS DISTINCT FROM v_lot1 THEN
      RAISE EXCEPTION 'rangement refuse par le declencheur (lot=%)', (SELECT batch_id FROM public.book_drafts WHERE id = v_d3);
    END IF;
    v_hint := NULL;
    BEGIN
      PERFORM public.publish_book_draft(v_d3);
      v_hint := 'publie';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    END;
    IF v_hint = 'error.publish.added_after_review'
       AND NOT EXISTS (SELECT 1 FROM public.books WHERE bib_ref = 'H21TC-REF-' || v_d3)
       AND (SELECT status FROM public.book_drafts WHERE id = v_d3) = 'draft'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 (b) les brouillons que le tour a soumis se publient';
  BEGIN
    v_id := public.publish_book_draft(v_d1);
    IF v_id IS NOT NULL
       AND (SELECT status FROM public.book_drafts WHERE id = v_d1) = 'published'
       AND EXISTS (SELECT 1 FROM public.books WHERE id = v_id AND bib_ref = 'H21TC-REF-' || v_d1)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : livre='||coalesce(v_id::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM);
  END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 (b) un ajout apres approbation se compte, et la liste des lots le dit (jeton de la coordination)';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_n := public.fn_batch_ajouts_apres_revision(v_lot1);
    SELECT l.after_review INTO v_m FROM public.fn_batch_reviews_list() l WHERE l.batch_id = v_lot1;
    IF v_n = 1 AND v_m = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : ajouts='||coalesce(v_n::text,'NULL')||' after_review='||coalesce(v_m::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 (b) la coordination redemande un tour elle-meme, parce qu''il y a des ajouts ; la garde se referme';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    IF public.fn_caller_is_network_admin() THEN RAISE EXCEPTION 'la coordination du seed est admin reseau : test sans objet'; END IF;
    v_res := public.fn_batch_review_request(v_lot1, 'H21TC : un brouillon ajoute apres approbation');
    v_rev2 := (v_res->>'review_id')::bigint;
    -- Pendant le nouveau tour, un brouillon couvert par le premier attend aussi.
    v_hint := NULL;
    BEGIN
      PERFORM public.publish_book_draft(v_d2);
      v_hint := 'publie';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    END;
    -- La liste du tour 2 : tout le lot hors corbeille, d1 (publié en T4) compris —
    -- sa republication ne redevient pas « ajoutée » (T19).
    IF (v_res->>'round')::int = 2
       AND (SELECT r.requested_by = v_coord AND r.status = 'requested'
                   AND r.draft_ids = ARRAY(SELECT unnest(ARRAY[v_d1, v_d2, v_d3]) ORDER BY 1)
              FROM public.catalog_batch_reviews r WHERE r.id = v_rev2)
       AND v_hint = 'error.publish.review_required'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_res::text,'NULL')||' draft_ids='
         ||coalesce((SELECT coalesce(r.draft_ids::text,'NULL') FROM public.catalog_batch_reviews r WHERE r.id = v_rev2),'aucun tour')
         ||' publier d2 pendant le tour='||coalesce(v_hint,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM);
  END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 (b) le nouveau tour approuve, le brouillon ajoute se publie ; plus rien n''attend';
  BEGIN
    IF v_rev2 IS NULL THEN RAISE EXCEPTION 'pas de second tour (T6)'; END IF;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict(v_rev2, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    PERFORM public.publish_book_draft(v_d3);
    PERFORM public.publish_book_draft(v_d2);
    SELECT l.after_review INTO v_m FROM public.fn_batch_reviews_list() l WHERE l.batch_id = v_lot1;
    IF (SELECT count(*) FROM public.book_drafts WHERE id IN (v_d2, v_d3) AND status = 'published') = 2
       AND EXISTS (SELECT 1 FROM public.books WHERE bib_ref = 'H21TC-REF-' || v_d3)
       AND public.fn_batch_ajouts_apres_revision(v_lot1) = 0 AND v_m = 0
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : after_review='||coalesce(v_m::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM);
  END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T8 (b) un brouillon range PENDANT le tour requested n''est pas couvert par l''approbation qui suit';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_res := public.fn_batch_review_request(v_lot3, NULL);
    v_rev3 := (v_res->>'review_id')::bigint;
    -- Une notice faite à la main, rangée dans le lot importé pendant la révision (API).
    EXECUTE 'SET LOCAL ROLE authenticated';
    INSERT INTO public.book_drafts (titulo, bib_ref, tipo_material, owner_library_id, batch_id, status)
    VALUES ('H21TC Faite a la main pendant la revision', 'H21TC-REF-MAIN-3', 'livro', v_lib, v_lot3, 'draft');
    EXECUTE 'RESET ROLE';
    SELECT id INTO v_dh FROM public.book_drafts WHERE bib_ref = 'H21TC-REF-MAIN-3';
    IF (SELECT batch_id FROM public.book_drafts WHERE id = v_dh) IS DISTINCT FROM v_lot3 THEN
      RAISE EXCEPTION 'rangement refuse par le declencheur';
    END IF;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict(v_rev3, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_n := public.fn_batch_ajouts_apres_revision(v_lot3);
    v_hint := NULL;
    BEGIN
      PERFORM public.publish_book_draft(v_dh);
      v_hint := 'publie';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    END;
    v_hint2 := NULL;
    BEGIN
      PERFORM public.publish_book_draft(v_d4);
      v_hint2 := 'publie';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint2 = PG_EXCEPTION_HINT;
    END;
    IF v_n = 1 AND v_hint = 'error.publish.added_after_review' AND v_hint2 = 'publie'
       AND NOT EXISTS (SELECT 1 FROM public.books WHERE bib_ref = 'H21TC-REF-MAIN-3')
       AND (SELECT r.draft_ids FROM public.catalog_batch_reviews r WHERE r.id = v_rev3) = ARRAY[v_d4]
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : ajouts='||coalesce(v_n::text,'NULL')||' faite a la main='||coalesce(v_hint,'NULL')
         ||' soumise='||coalesce(v_hint2,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T9 (b) un tour d''avant le 29/09, rattrape par la fonction de la migration, couvre le contenu non annule de son lot '
      || '(publies, exemplaires rattaches et sans notice compris), pas un brouillon range apres ; la coordination redemande un tour';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    -- Décor : l'état qu'un lot révisé avant le 29/09 a laissé. Une notice PUBLIÉE du lot : d6p,
    -- faite à la main, publiée « Sans lot », puis rangée dans le lot (postgres) — ainsi T9 ne passe
    -- pas par la garde de compatibilité des listes NULL (T22) et n'en dépend pas.
    INSERT INTO public.book_drafts (titulo, bib_ref, tipo_material, owner_library_id, created_by, status)
    VALUES ('H21TC Publiee avant le 29/09', 'H21TC-REF-OLD-PUB', 'livro', v_lib, v_coord, 'draft') RETURNING id INTO v_d6p;
    v_book5 := public.publish_book_draft(v_d6p);
    UPDATE public.book_drafts SET batch_id = v_lot5 WHERE id = v_d6p;
    -- Un exemplaire SANS notice (book_draft_id NULL), fait à la main par la coordination (API) et
    -- rangé dans le lot avant le tour : x5m, sur une notice au catalogue détenue par la
    -- bibliothèque. C'est le seul genre d'exemplaire pour lequel publish_exemplar_draft consulte
    -- la liste du tour (un rattaché suit sa notice) : le rattrapage doit le lister comme x5.
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
    VALUES ('H21TC Notice des exemplaires faits a la main du lot 5', 'H21TC-B5', 'livro', v_lib) RETURNING id INTO v_book5m;
    INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_book5m, v_lib);
    EXECUTE 'SET LOCAL ROLE authenticated';
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, target_bib_ref, batch_id, notes)
    VALUES ('create', 'draft', 'pending', v_lib, 'H21TC-B5', v_lot5, 'H21TC-X5M fait a la main');
    EXECUTE 'RESET ROLE';
    SELECT id INTO v_x5m FROM public.exemplar_drafts WHERE notes = 'H21TC-X5M fait a la main';
    -- Le tour d'avant le 29/09 : approuvé, sans liste (les colonnes n'existaient pas).
    INSERT INTO public.catalog_batch_reviews (batch_id, round, status, requested_by, reviewed_by, reviewed_at)
    VALUES (v_lot5, 1, 'approved', v_coord, v_admin, now()) RETURNING id INTO v_rev5;
    IF v_book5 IS NULL OR v_x5 IS NULL OR v_x5c IS NULL OR v_x5m IS NULL
       OR (SELECT count(*) FROM public.book_drafts WHERE batch_id = v_lot5) <> 4
       OR (SELECT string_agg(status, ',' ORDER BY id) FROM public.book_drafts WHERE id IN (v_d6, v_d6r, v_d5c, v_d6p))
          IS DISTINCT FROM (SELECT string_agg(s, ',' ORDER BY i) FROM (VALUES (v_d6, 'draft'), (v_d6r, 'ready'),
                                                                               (v_d5c, 'cancelled'), (v_d6p, 'published')) v(i, s))
       OR (SELECT count(*) FROM public.exemplar_drafts WHERE batch_id = v_lot5 AND book_draft_id = v_d6) <> 2
       OR (SELECT x.batch_id IS DISTINCT FROM v_lot5 OR x.book_draft_id IS NOT NULL OR x.status <> 'draft'
             FROM public.exemplar_drafts x WHERE x.id = v_x5m)
       OR public.fn_batch_review_status(v_lot5) IS DISTINCT FROM 'approved' THEN
      RAISE EXCEPTION 'decor du lot 5 incomplet (livre=%, x5=%, x5c=%, x5m=%)', v_book5, v_x5, v_x5c, v_x5m;
    END IF;

    -- Le rattrapage que la migration joue, tel quel ; il ne remplit que les tours sans liste.
    SELECT count(*) INTO v_k FROM public.catalog_batch_reviews WHERE draft_ids IS NULL;
    v_n := private.fn_h21_rattraper_listes_des_tours();
    SELECT 'draft_ids='||coalesce(r.draft_ids::text,'NULL')||' exemplar_draft_ids='||coalesce(r.exemplar_draft_ids::text,'NULL')
      INTO v_listes FROM public.catalog_batch_reviews r WHERE r.id = v_rev5;
    v_ok := v_k >= 1 AND v_n = v_k
            -- tout le contenu non annulé du lot : brouillon, prêt, publié ; les exemplaires vivants,
            -- rattaché (x5) ET sans notice (x5m), triés
            AND (SELECT r.draft_ids = ARRAY(SELECT unnest(ARRAY[v_d6, v_d6r, v_d6p]) ORDER BY 1)
                        AND r.exemplar_draft_ids = ARRAY(SELECT unnest(ARRAY[v_x5, v_x5m]) ORDER BY 1)
                   FROM public.catalog_batch_reviews r WHERE r.id = v_rev5)
            AND NOT EXISTS (SELECT 1 FROM public.catalog_batch_reviews WHERE draft_ids IS NULL OR exemplar_draft_ids IS NULL)
            -- un tour qui a sa liste n'est pas recalculé : dh (T8, rangé pendant le tour 3) reste hors de la sienne
            AND (SELECT r.draft_ids FROM public.catalog_batch_reviews r WHERE r.id = v_rev3) = ARRAY[v_d4];

    -- Un brouillon rangé APRÈS le rattrapage (API, la coordination) attend un nouveau tour.
    EXECUTE 'SET LOCAL ROLE authenticated';
    INSERT INTO public.book_drafts (titulo, bib_ref, tipo_material, owner_library_id, batch_id, status)
    VALUES ('H21TC Rangee apres le rattrapage', 'H21TC-REF-MAIN-5', 'livro', v_lib, v_lot5, 'draft');
    EXECUTE 'RESET ROLE';
    SELECT id INTO v_d7 FROM public.book_drafts WHERE bib_ref = 'H21TC-REF-MAIN-5';
    IF (SELECT batch_id FROM public.book_drafts WHERE id = v_d7) IS DISTINCT FROM v_lot5 THEN
      RAISE EXCEPTION 'rangement refuse par le declencheur';
    END IF;
    v_m := public.fn_batch_ajouts_apres_revision(v_lot5);
    v_hint := NULL;
    BEGIN
      PERFORM public.publish_book_draft(v_d7);
      v_hint := 'publie';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    END;
    -- Ce que le tour couvre se publie : le prêt, et le publié se republie (il est dans la liste).
    v_hint2 := NULL;
    BEGIN
      PERFORM public.publish_book_draft(v_d6r);
      v_hint2 := 'publie';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint2 = PG_EXCEPTION_HINT;
    END;
    v_hint3 := NULL; v_id := NULL;
    BEGIN
      v_id := public.publish_book_draft(v_d6p);
      v_hint3 := 'publie';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint3 = PG_EXCEPTION_HINT;
    END;
    -- L'exemplaire sans notice, dans la liste rattrapée, se publie SANS nouveau tour (le seul tour
    -- du lot est encore celui d'avant le 29/09), sur la notice détenue.
    v_hint4 := NULL; v_id2 := NULL;
    BEGIN
      v_id2 := public.publish_exemplar_draft(v_x5m);
      v_hint4 := 'publie';
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint4 = PG_EXCEPTION_HINT;
      v_hint4 := coalesce(nullif(v_hint4, ''), SQLERRM);
    END;
    SELECT count(*) INTO v_tours FROM public.catalog_batch_reviews WHERE batch_id = v_lot5;
    -- La coordination (pas l'administration) redemande un tour, parce qu'il y a un ajout.
    IF public.fn_caller_is_network_admin() THEN RAISE EXCEPTION 'la coordination du seed est admin reseau : test sans objet'; END IF;
    v_txt := NULL; v_res := NULL;
    BEGIN
      v_res := public.fn_batch_review_request(v_lot5, 'H21TC : un brouillon range apres le rattrapage');
      v_rev5b := (v_res->>'review_id')::bigint;
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_txt = PG_EXCEPTION_HINT;
    END;
    IF v_ok AND v_m = 1
       AND v_hint = 'error.publish.added_after_review'
       AND NOT EXISTS (SELECT 1 FROM public.books WHERE bib_ref = 'H21TC-REF-MAIN-5')
       AND (SELECT status FROM public.book_drafts WHERE id = v_d7) = 'draft'
       AND v_hint2 = 'publie' AND v_hint3 = 'publie' AND v_id = v_book5
       -- l'exemplaire sans notice : publié sous le seul tour d'avant le 29/09, sur la notice détenue
       AND v_hint4 = 'publie' AND v_tours = 1
       AND (SELECT status FROM public.exemplar_drafts WHERE id = v_x5m) = 'published'
       AND EXISTS (SELECT 1 FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id
                    WHERE e.id = v_id2 AND e.library_id = v_lib AND h.book_id = v_book5m)
       -- le tour 2 soumet l'ajout (le reste de sa liste : T6, T19)
       AND (v_res->>'round')::int = 2
       AND (SELECT r.requested_by = v_coord AND r.status = 'requested' AND v_d7 = ANY (r.draft_ids)
              FROM public.catalog_batch_reviews r WHERE r.id = v_rev5b)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : rattrapes='||coalesce(v_n::text,'NULL')||'/'||coalesce(v_k::text,'NULL')
         ||' '||coalesce(v_listes,'aucun tour')||' (d6='||v_d6||' d6r='||v_d6r||' d6p='||v_d6p||' x5='||v_x5||' x5m='||coalesce(v_x5m::text,'NULL')||')'
         ||' tour 3='||coalesce((SELECT coalesce(r.draft_ids::text,'NULL') FROM public.catalog_batch_reviews r WHERE r.id = v_rev3),'aucun')
         ||' ajouts='||coalesce(v_m::text,'NULL')||' range apres='||coalesce(v_hint,'NULL')
         ||' pret='||coalesce(v_hint2,'NULL')||' republie='||coalesce(v_hint3,'NULL')
         ||' sans notice='||coalesce(v_hint4,'NULL')||' (tours='||coalesce(v_tours::text,'NULL')||')'
         ||' redemande='||coalesce(v_txt, v_res::text, 'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    EXECUTE 'RESET ROLE';
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM);
  END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T9b (b, c) le rattrapage liste les exemplaires SANS notice du lot, rapproches, prets et publies (le publie se '
      || 'republie sur le meme exemplaire, sans nouveau tour) ; un tour d''avant le 29/09 encore requested, rattrape puis '
      || 'approuve, refuse un ajout';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    -- Décor 1 (lot 12) : un lot né d'une PROMOTION (d12) où la coordination a rangé par l'API,
    -- avant le tour, les quatre exemplaires d'un « Rapprocher » (fn_import_reconcile_duplicates,
    -- l'écran) : sans notice (book_draft_id NULL), venus d'une ligne d'import. Avant le 29/09,
    -- seul un lot de notices importées se révisait : c'est là qu'un rapproché a pu passer un tour.
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
    VALUES ('H21TC Notice des exemplaires rapproches du lot 12', 'H21TC-B12', 'livro', v_lib) RETURNING id INTO v_book12;
    INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_book12, v_lib);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21tc-12r.marc', 'h21tc-12r.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run12r;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, proposed_book_id, normalized_payload)
    VALUES (v_run12r, 1, 'H21TC-12r-1', 'H21TC Notice du lot 12 (doublon)', 'matched_book', 'pending', v_book12,
            '{"items": [{"source_item_code": "H21TC-R12-1", "call_number": "R12-1"},
                        {"source_item_code": "H21TC-R12-2", "call_number": "R12-2"},
                        {"source_item_code": "H21TC-R12-3", "call_number": "R12-3"},
                        {"source_item_code": "H21TC-R12-4", "call_number": "R12-4"}]}'::jsonb)
    RETURNING id INTO v_r12;
    v_res := public.fn_import_reconcile_duplicates(v_run12r, ARRAY[v_r12]);
    v_lot12r := (v_res->>'batch_id')::bigint;
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21tc-12.marc', 'h21tc-12.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run12;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
    VALUES (v_run12, 1, 'H21TC-12-1', 'H21TC Notice promue du lot 12', 'new_record', 'accept_new', '{"items": []}'::jsonb);
    v_lot12 := (public.fn_import_promote(v_run12, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
    SELECT m.draft_id INTO v_d12 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run12;
    UPDATE public.book_drafts SET bib_ref = 'H21TC-REF-' || id, tipo_material = 'livro' WHERE id = v_d12;
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.exemplar_drafts SET batch_id = v_lot12 WHERE import_staging_row_id = v_r12;
    EXECUTE 'RESET ROLE';
    SELECT id INTO v_x12a FROM public.exemplar_drafts WHERE import_staging_row_id = v_r12 AND source_item_code = 'H21TC-R12-1';
    SELECT id INTO v_x12b FROM public.exemplar_drafts WHERE import_staging_row_id = v_r12 AND source_item_code = 'H21TC-R12-2';
    SELECT id INTO v_x12c FROM public.exemplar_drafts WHERE import_staging_row_id = v_r12 AND source_item_code = 'H21TC-R12-3';
    SELECT id INTO v_x12d FROM public.exemplar_drafts WHERE import_staging_row_id = v_r12 AND source_item_code = 'H21TC-R12-4';
    -- Le tour d'avant le 29/09 : approuvé, sans liste (les colonnes n'existaient pas).
    INSERT INTO public.catalog_batch_reviews (batch_id, round, status, requested_by, reviewed_by, reviewed_at)
    VALUES (v_lot12, 1, 'approved', v_coord, v_admin, now()) RETURNING id INTO v_rev12;
    -- Ce qu'il a laissé avant la migration. x12c PUBLIÉ par publish_exemplar_draft : le statut
    -- « publié » d'un brouillon d'exemplaire ne se pose plus par l'API
    -- (exemplar_drafts_statut_publie_reserve) ; sous le tour sans liste, la garde de
    -- compatibilité le couvre, comme publish_exemplar_draft d'avant le 29/09 (qui ne lisait
    -- aucune liste) le publiait. x12b passé « prêt » et x12d mis à la corbeille, par l'API.
    BEGIN
      v_e12c := public.publish_exemplar_draft(v_x12c);
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
      RAISE EXCEPTION 'decor : x12c non publie sous le tour d''avant le 29/09 sans liste (garde de compatibilite) : % %',
        coalesce(v_hint, ''), SQLERRM;
    END;
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.exemplar_drafts SET status = 'ready' WHERE id = v_x12b;
    UPDATE public.exemplar_drafts SET status = 'cancelled' WHERE id = v_x12d;
    EXECUTE 'RESET ROLE';
    -- Décor 2 (lot 13) : un lot né d'une promotion (d13), dont le tour d'avant le 29/09 était
    -- encore « requested » (sans liste) le jour de la migration.
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21tc-13.marc', 'h21tc-13.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run13;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
    VALUES (v_run13, 1, 'H21TC-13-1', 'H21TC Soumise a un tour ancien en attente', 'new_record', 'accept_new', '{"items": []}'::jsonb);
    v_lot13 := (public.fn_import_promote(v_run13, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
    SELECT m.draft_id INTO v_d13 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run13;
    UPDATE public.book_drafts SET bib_ref = 'H21TC-REF-' || id, tipo_material = 'livro' WHERE id = v_d13;
    INSERT INTO public.catalog_batch_reviews (batch_id, round, status, requested_by)
    VALUES (v_lot13, 1, 'requested', v_coord) RETURNING id INTO v_rev13;
    IF v_book12 IS NULL OR v_lot12r IS NULL OR v_lot12 IS NULL OR v_d12 IS NULL OR v_e12c IS NULL
       OR v_x12a IS NULL OR v_x12b IS NULL OR v_x12c IS NULL OR v_x12d IS NULL
       OR (SELECT string_agg(x.status, ',' ORDER BY v.o)
             FROM (VALUES (1, v_x12a), (2, v_x12b), (3, v_x12c), (4, v_x12d)) v(o, i)
             JOIN public.exemplar_drafts x ON x.id = v.i) IS DISTINCT FROM 'draft,ready,published,cancelled'
       OR EXISTS (SELECT 1 FROM public.exemplar_drafts x WHERE x.id IN (v_x12a, v_x12b, v_x12c, v_x12d)
                   AND (x.batch_id IS DISTINCT FROM v_lot12 OR x.book_draft_id IS NOT NULL))
       OR (SELECT count(*) FROM public.exemplar_drafts WHERE batch_id = v_lot12) <> 4
       OR (SELECT string_agg(d.id::text, ',') FROM public.book_drafts d WHERE d.batch_id = v_lot12) IS DISTINCT FROM v_d12::text
       OR NOT public.fn_batch_is_imported(v_lot12)
       OR public.fn_batch_review_status(v_lot12) IS DISTINCT FROM 'approved'
       OR v_lot13 IS NULL OR v_d13 IS NULL
       OR public.fn_batch_review_status(v_lot13) IS DISTINCT FROM 'requested' THEN
      RAISE EXCEPTION 'decor de T9b incomplet (lot 12=%, rapprochement=%, d12=%, x=%/%/%/%, publie avant le 29/09=%, lot 13=%, d13=%)',
        v_lot12, v_lot12r, v_d12, v_x12a, v_x12b, v_x12c, v_x12d, v_e12c, v_lot13, v_d13;
    END IF;

    -- Le rattrapage que la migration joue, tel quel : les deux tours sans liste, l'approuvé
    -- comme le requested.
    SELECT count(*) INTO v_k FROM public.catalog_batch_reviews WHERE draft_ids IS NULL;
    v_n := private.fn_h21_rattraper_listes_des_tours();
    SELECT 'draft_ids='||coalesce(r.draft_ids::text,'NULL')||' exemplar_draft_ids='||coalesce(r.exemplar_draft_ids::text,'NULL')
      INTO v_listes FROM public.catalog_batch_reviews r WHERE r.id = v_rev12;
    SELECT 'draft_ids='||coalesce(r.draft_ids::text,'NULL')||' exemplar_draft_ids='||coalesce(r.exemplar_draft_ids::text,'NULL')
      INTO v_listes2 FROM public.catalog_batch_reviews r WHERE r.id = v_rev13;
    v_ok := v_k >= 2 AND v_n = v_k
            -- lot 12 : la notice promue ; les exemplaires rapprochés en brouillon, prêt ET publié,
            -- triés — pas celui de la corbeille
            AND (SELECT r.draft_ids = ARRAY[v_d12]
                        AND r.exemplar_draft_ids = ARRAY(SELECT unnest(ARRAY[v_x12a, v_x12b, v_x12c]) ORDER BY 1)
                   FROM public.catalog_batch_reviews r WHERE r.id = v_rev12)
            -- lot 13 : le tour encore requested a sa liste lui aussi
            AND (SELECT r.status = 'requested' AND r.draft_ids = ARRAY[v_d13] AND r.exemplar_draft_ids = '{}'::bigint[]
                   FROM public.catalog_batch_reviews r WHERE r.id = v_rev13);
    -- Rien n'est entré dans le lot 12 après sa demande : aucun ajout, rien à redemander.
    v_m := public.fn_batch_ajouts_apres_revision(v_lot12);

    -- Lot 12, après la migration (la coordination) : le brouillon et le prêt se publient sur la
    -- notice détenue ; le publié, retouché par l'API, se republie sur le MÊME exemplaire.
    v_hint := NULL; v_e12a := NULL;
    BEGIN
      v_e12a := public.publish_exemplar_draft(v_x12a);
      v_hint := 'publie';
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
      v_hint := coalesce(nullif(v_hint, ''), SQLERRM);
    END;
    v_hint2 := NULL; v_e12b := NULL;
    BEGIN
      v_e12b := public.publish_exemplar_draft(v_x12b);
      v_hint2 := 'publie';
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint2 = PG_EXCEPTION_HINT;
      v_hint2 := coalesce(nullif(v_hint2, ''), SQLERRM);
    END;
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.exemplar_drafts SET shelf_location = 'H21TC rayon corrige' WHERE id = v_x12c;
    EXECUTE 'RESET ROLE';
    SELECT x.shelf_location INTO v_rayon FROM public.exemplar_drafts x WHERE x.id = v_x12c;
    IF v_rayon IS DISTINCT FROM 'H21TC rayon corrige' THEN
      RAISE EXCEPTION 'retouche de l''exemplaire publie refusee (rayon=%)', coalesce(v_rayon, 'NULL');
    END IF;
    v_hint3 := NULL; v_e12c2 := NULL;
    BEGIN
      v_e12c2 := public.publish_exemplar_draft(v_x12c);
      v_hint3 := 'publie';
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint3 = PG_EXCEPTION_HINT;
      v_hint3 := coalesce(nullif(v_hint3, ''), SQLERRM);
    END;
    SELECT count(*) INTO v_tours FROM public.catalog_batch_reviews WHERE batch_id = v_lot12;

    -- Lot 13 : l'administration approuve le tour rattrapé ; la coordination range ensuite par
    -- l'API une notice et un exemplaire sans notice faits à la main. Ils attendent un nouveau
    -- tour ; d13, que le tour a soumis, se publie.
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict(v_rev13, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    INSERT INTO public.book_drafts (titulo, bib_ref, tipo_material, owner_library_id, batch_id, status)
    VALUES ('H21TC Rangee apres l''approbation du tour rattrape', 'H21TC-REF-MAIN-13', 'livro', v_lib, v_lot13, 'draft');
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, target_bib_ref, batch_id, notes)
    VALUES ('create', 'draft', 'pending', v_lib, 'H21TC-B12', v_lot13, 'H21TC-X13M fait a la main');
    EXECUTE 'RESET ROLE';
    SELECT id INTO v_dh13 FROM public.book_drafts WHERE bib_ref = 'H21TC-REF-MAIN-13';
    SELECT id INTO v_x13m FROM public.exemplar_drafts WHERE notes = 'H21TC-X13M fait a la main';
    IF (SELECT batch_id FROM public.book_drafts WHERE id = v_dh13) IS DISTINCT FROM v_lot13
       OR (SELECT batch_id FROM public.exemplar_drafts WHERE id = v_x13m) IS DISTINCT FROM v_lot13 THEN
      RAISE EXCEPTION 'rangement refuse par le declencheur (notice=%, exemplaire=%)', v_dh13, v_x13m;
    END IF;
    v_m2 := public.fn_batch_ajouts_apres_revision(v_lot13);
    v_hint5 := NULL;
    BEGIN
      PERFORM public.publish_book_draft(v_dh13);
      v_hint5 := 'publie';
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint5 = PG_EXCEPTION_HINT;
      v_hint5 := coalesce(nullif(v_hint5, ''), SQLERRM);
    END;
    v_hint6 := NULL;
    BEGIN
      PERFORM public.publish_exemplar_draft(v_x13m);
      v_hint6 := 'publie';
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint6 = PG_EXCEPTION_HINT;
      v_hint6 := coalesce(nullif(v_hint6, ''), SQLERRM);
    END;
    v_hint7 := NULL;
    BEGIN
      PERFORM public.publish_book_draft(v_d13);
      v_hint7 := 'publie';
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint7 = PG_EXCEPTION_HINT;
      v_hint7 := coalesce(nullif(v_hint7, ''), SQLERRM);
    END;
    SELECT count(*) INTO v_tours13 FROM public.catalog_batch_reviews WHERE batch_id = v_lot13;

    IF v_ok AND v_m = 0
       -- lot 12 : les trois rapprochés sont publiés, sous le seul tour d'avant le 29/09
       AND v_hint = 'publie' AND v_hint2 = 'publie' AND v_hint3 = 'publie' AND v_tours = 1
       AND (SELECT count(*) FROM public.exemplar_drafts WHERE id IN (v_x12a, v_x12b, v_x12c) AND status = 'published') = 3
       AND (SELECT count(*) FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id
             WHERE e.id IN (v_e12a, v_e12b) AND e.library_id = v_lib AND h.book_id = v_book12) = 2
       -- la republication met à jour l'exemplaire publié avant le 29/09 : pas de doublon
       AND v_e12c2 = v_e12c
       AND (SELECT shelf_location FROM public.exemplares WHERE id = v_e12c) = 'H21TC rayon corrige'
       AND (SELECT count(*) FROM public.exemplares WHERE source_item_code = 'H21TC-R12-3') = 1
       AND NOT EXISTS (SELECT 1 FROM public.exemplares WHERE source_item_code = 'H21TC-R12-4')
       -- lot 13 : approuvé, le tour rattrapé couvre d13, pas ce qui est rangé après
       AND public.fn_batch_review_status(v_lot13) = 'approved' AND v_tours13 = 1
       AND v_m2 = 2
       AND v_hint5 = 'error.publish.added_after_review' AND v_hint6 = 'error.publish.added_after_review'
       AND NOT EXISTS (SELECT 1 FROM public.books WHERE bib_ref = 'H21TC-REF-MAIN-13')
       AND (SELECT status FROM public.exemplar_drafts WHERE id = v_x13m) = 'draft'
       AND v_hint7 = 'publie'
       AND EXISTS (SELECT 1 FROM public.books WHERE bib_ref = 'H21TC-REF-' || v_d13)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : rattrapes='||coalesce(v_n::text,'NULL')||'/'||coalesce(v_k::text,'NULL')
         ||' lot 12 '||coalesce(v_listes,'aucun tour')||' (d12='||v_d12||' x12a='||v_x12a||' x12b='||v_x12b||' x12c='||v_x12c||' x12d='||v_x12d||')'
         ||' ajouts='||coalesce(v_m::text,'NULL')||' brouillon='||coalesce(v_hint,'NULL')||' pret='||coalesce(v_hint2,'NULL')
         ||' republie='||coalesce(v_hint3,'NULL')||' (exemplaire '||coalesce(v_e12c::text,'NULL')||' -> '||coalesce(v_e12c2::text,'NULL')
         ||', tours='||coalesce(v_tours::text,'NULL')||')'
         ||' | lot 13 '||coalesce(v_listes2,'aucun tour')||' (d13='||v_d13||') ajouts='||coalesce(v_m2::text,'NULL')
         ||' notice ajoutee='||coalesce(v_hint5,'NULL')||' exemplaire ajoute='||coalesce(v_hint6,'NULL')
         ||' soumise='||coalesce(v_hint7,'NULL')||' (tours='||coalesce(v_tours13::text,'NULL')||')'); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    EXECUTE 'RESET ROLE';
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM);
  END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T10 (b) publier le lot entier avec un ajout apres approbation : refus, rien de publie (tout ou rien)';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_res := public.fn_batch_review_request(v_lot6, NULL);
    v_rev6 := (v_res->>'review_id')::bigint;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict(v_rev6, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET batch_id = v_lot6 WHERE id = v_d10;
    EXECUTE 'RESET ROLE';
    IF (SELECT batch_id FROM public.book_drafts WHERE id = v_d10) IS DISTINCT FROM v_lot6 THEN
      RAISE EXCEPTION 'rangement refuse par le declencheur';
    END IF;
    v_hint := NULL;
    BEGIN
      v_res := public.publish_catalog_batch(v_lot6);
      v_hint := 'publie : ' || v_res::text;
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    END;
    IF v_hint = 'error.publish.added_after_review'
       AND NOT EXISTS (SELECT 1 FROM public.book_drafts WHERE id IN (v_d8, v_d9, v_d10) AND status = 'published')
       AND NOT EXISTS (SELECT 1 FROM public.books WHERE bib_ref IN ('H21TC-REF-' || v_d8, 'H21TC-REF-' || v_d9, 'H21TC-REF-' || v_d10))
       AND (SELECT status FROM public.catalog_batches WHERE id = v_lot6) = 'open'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'NULL')||' publies='
         ||(SELECT count(*) FROM public.book_drafts WHERE id IN (v_d8, v_d9, v_d10) AND status = 'published')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── Décor (c) : une notice déjà au catalogue, une ligne d'import qui la désigne ──
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
  VALUES ('H21TC Notice deja au catalogue', 'H21TC-B0', 'livro', v_lib) RETURNING id INTO v_book0;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_book0, v_lib);
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h21tc-7.marc', 'h21tc-7.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run7;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, proposed_book_id, normalized_payload)
  VALUES (v_run7, 1, 'H21TC-7-1', 'H21TC Notice deja au catalogue (doublon)', 'matched_book', 'pending', v_book0,
          '{"items": [{"source_item_code": "H21TC-RAP-1", "call_number": "R1"},
                      {"source_item_code": "H21TC-RAP-2", "call_number": "R2"},
                      {"source_item_code": "H21TC-RAP-3", "call_number": "R3"}]}'::jsonb)
  RETURNING id INTO v_r7;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T11 (c) « Rapprocher » cree les exemplaires dans leur lot, et ce lot est ne d''un import';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_res := public.fn_import_reconcile_duplicates(v_run7, ARRAY[v_r7]);
    v_lotr := (v_res->>'batch_id')::bigint;
    SELECT id INTO v_x1 FROM public.exemplar_drafts WHERE import_staging_row_id = v_r7 AND source_item_code = 'H21TC-RAP-1';
    SELECT id INTO v_x2 FROM public.exemplar_drafts WHERE import_staging_row_id = v_r7 AND source_item_code = 'H21TC-RAP-2';
    SELECT id INTO v_x3 FROM public.exemplar_drafts WHERE import_staging_row_id = v_r7 AND source_item_code = 'H21TC-RAP-3';
    IF v_lotr IS NOT NULL
       AND (SELECT count(*) FROM public.exemplar_drafts
             WHERE import_staging_row_id = v_r7 AND batch_id = v_lotr AND book_draft_id IS NULL
               AND target_library_id = v_lib AND status IN ('draft', 'ready')) = 3
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft m WHERE m.batch_id = v_lotr)
       AND NOT EXISTS (SELECT 1 FROM public.book_drafts d WHERE d.batch_id = v_lotr)
       AND public.fn_batch_is_imported(v_lotr)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : lot='||coalesce(v_lotr::text,'NULL')||' importe='
         ||coalesce(public.fn_batch_is_imported(v_lotr)::text,'NULL')||' res='||left(coalesce(v_res::text,'NULL'), 200)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T12 (c) un exemplaire rapproche ne se publie pas avant la revision de son lot';
  BEGIN
    v_hint := NULL;
    BEGIN
      PERFORM public.publish_exemplar_draft(v_x1);
      v_hint := 'publie';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    END;
    IF v_hint = 'error.publish.review_required'
       AND NOT EXISTS (SELECT 1 FROM public.exemplares e WHERE e.source_item_code = 'H21TC-RAP-1')
       AND (SELECT status FROM public.exemplar_drafts WHERE id = v_x1) = 'draft'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T13 (c) la revision d''un lot de rapprochement se demande ; le tour fige ses exemplaires';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_hint := NULL;
    BEGIN
      v_res := public.fn_batch_review_request(v_lotr, 'H21TC : exemplaires rapproches');
      v_revr := (v_res->>'review_id')::bigint;
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    END;
    IF v_revr IS NOT NULL
       AND (SELECT r.status = 'requested' AND r.draft_ids = '{}'::bigint[]
                   AND r.exemplar_draft_ids = ARRAY[v_x1, v_x2, v_x3]
              FROM public.catalog_batch_reviews r WHERE r.id = v_revr)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : refus='||coalesce(v_hint,'aucun')||' exemplar_draft_ids='
         ||coalesce((SELECT coalesce(r.exemplar_draft_ids::text,'NULL') FROM public.catalog_batch_reviews r WHERE r.id = v_revr),'aucun tour')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T14 (c) apres approbation, l''exemplaire rapproche se publie sur la notice existante';
  BEGIN
    IF v_revr IS NULL THEN RAISE EXCEPTION 'pas de tour a approuver (T13)'; END IF;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict(v_revr, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_id := public.publish_exemplar_draft(v_x1);
    IF (SELECT status FROM public.exemplar_drafts WHERE id = v_x1) = 'published'
       AND EXISTS (SELECT 1 FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id
                    WHERE e.id = v_id AND e.source_item_code = 'H21TC-RAP-1' AND e.library_id = v_lib AND h.book_id = v_book0)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : exemplaire='||coalesce(v_id::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM);
  END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T15 (c) un exemplaire rapproche sorti de son lot (API) ne se publie pas : imported_needs_batch';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.exemplar_drafts SET batch_id = NULL WHERE id = v_x2;
    EXECUTE 'RESET ROLE';
    IF (SELECT batch_id FROM public.exemplar_drafts WHERE id = v_x2) IS NOT NULL THEN
      RAISE EXCEPTION 'l''exemplaire n''est pas sorti du lot';
    END IF;
    v_hint := NULL;
    BEGIN
      PERFORM public.publish_exemplar_draft(v_x2);
      v_hint := 'publie';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    END;
    IF v_hint = 'error.publish.imported_needs_batch'
       AND NOT EXISTS (SELECT 1 FROM public.exemplares e WHERE e.source_item_code = 'H21TC-RAP-2')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T16 (c) un exemplaire fait a la main, range dans le lot rapproche apres la demande, attend ; un couvert passe';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, target_bib_ref, batch_id, notes)
    VALUES ('create', 'draft', 'pending', v_lib, 'H21TC-B0', v_lotr, 'H21TC-XM fait a la main');
    EXECUTE 'RESET ROLE';
    SELECT id INTO v_xm FROM public.exemplar_drafts WHERE notes = 'H21TC-XM fait a la main';
    IF (SELECT batch_id FROM public.exemplar_drafts WHERE id = v_xm) IS DISTINCT FROM v_lotr THEN
      RAISE EXCEPTION 'rangement refuse par le declencheur';
    END IF;
    v_n := public.fn_batch_ajouts_apres_revision(v_lotr);
    v_hint := NULL;
    BEGIN
      PERFORM public.publish_exemplar_draft(v_xm);
      v_hint := 'publie';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    END;
    v_hint2 := NULL;
    BEGIN
      PERFORM public.publish_exemplar_draft(v_x3);
      v_hint2 := 'publie';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint2 = PG_EXCEPTION_HINT;
    END;
    IF v_hint = 'error.publish.added_after_review' AND v_n = 1
       AND (SELECT status FROM public.exemplar_drafts WHERE id = v_xm) = 'draft'
       AND v_hint2 = 'publie'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : fait a la main='||coalesce(v_hint,'NULL')||' ajouts='||coalesce(v_n::text,'NULL')
         ||' couvert='||coalesce(v_hint2,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T17 (c) un exemplaire fait a la main, dans un lot fait a la main ou sans lot, se publie (non-regression)';
  BEGIN
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('H21TC lot a la main', v_coord, v_lib) RETURNING id INTO v_lotm;
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, target_bib_ref, created_by, batch_id, notes)
    VALUES ('create', 'draft', 'pending', v_lib, 'H21TC-B0', v_coord, v_lotm, 'H21TC-XHM') RETURNING id INTO v_xhm;
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, target_bib_ref, created_by, notes)
    VALUES ('create', 'draft', 'pending', v_lib, 'H21TC-B0', v_coord, 'H21TC-XSL') RETURNING id INTO v_xsl;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    PERFORM public.publish_exemplar_draft(v_xhm);
    PERFORM public.publish_exemplar_draft(v_xsl);
    IF NOT public.fn_batch_is_imported(v_lotm)
       AND (SELECT count(*) FROM public.exemplar_drafts WHERE id IN (v_xhm, v_xsl) AND status = 'published') = 2
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : lot importe='||public.fn_batch_is_imported(v_lotm)); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM);
  END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T18 un exemplaire importe rattache : pas avant sa notice ; couvert par le tour, publie avec elle puis republie seul (IMP-28 d)';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    IF v_xn IS NULL THEN RAISE EXCEPTION 'la promotion n''a pas cree l''exemplaire du fichier'; END IF;
    v_hint := NULL;
    BEGIN
      PERFORM public.publish_exemplar_draft(v_xn);
      v_hint := 'publie';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    END;
    v_res := public.fn_batch_review_request(v_lot8, NULL);
    v_rev8 := (v_res->>'review_id')::bigint;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict(v_rev8, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    PERFORM public.publish_book_draft(v_d11);
    -- IMP-28 d (05/10) : republié seul, le rattaché passe la porte de révision — le tour
    -- approuvé le couvre (il était dans sa liste) ; même exemplaire, aucun doublon.
    v_hint2 := NULL;
    BEGIN
      PERFORM public.publish_exemplar_draft(v_xn);
      v_hint2 := 'republie';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint2 = PG_EXCEPTION_HINT;
    END;
    IF v_hint = 'error.publish.item_before_record'
       -- rattaché à sa notice, il figure dans la liste d'exemplaires du tour (l'absorption de sa
       -- notice pourrait le détacher : T20) ; depuis IMP-28 d, c'est cette liste qui le rend
       -- publiable, avec sa notice comme seul.
       -- coalesce : sous fn_batch_review_request d'avant (contre-épreuve), le tour n'a pas de liste.
       AND (SELECT coalesce(r.exemplar_draft_ids = ARRAY[v_xn], true) AND coalesce(r.draft_ids = ARRAY[v_d11], true)
              FROM public.catalog_batch_reviews r WHERE r.id = v_rev8)
       AND (SELECT status FROM public.exemplar_drafts WHERE id = v_xn) = 'published'
       AND v_hint2 = 'republie'
       AND (SELECT count(*) FROM public.exemplares e WHERE e.source_item_code = 'H21TC-NOT-1' AND e.library_id = v_lib) = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : avant la notice='||coalesce(v_hint,'NULL')
         ||' republication='||coalesce(v_hint2,'NULL')
         ||' exemplaire='||coalesce((SELECT status FROM public.exemplar_drafts WHERE id = v_xn),'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM);
  END;

  -- ── Décor (amendement 1) : R9 -> lot 9 : d19 (publié, puis republié) ;
  --    R10 -> lot 10 : d20 avec UN exemplaire du fichier (xd), absorbée par une notice existante ──
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h21tc-9.marc', 'h21tc-9.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run9;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
  VALUES (v_run9, 1, 'H21TC-9-1', 'H21TC Publiee puis republiee', 'new_record', 'accept_new', '{"items": []}'::jsonb);
  v_lot9 := (public.fn_import_promote(v_run9, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
  SELECT m.draft_id INTO v_d19 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run9;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h21tc-10.marc', 'h21tc-10.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run10;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
  VALUES (v_run10, 1, 'H21TC-10-1', 'H21TC Absorbee avec son exemplaire', 'new_record', 'accept_new',
          '{"items": [{"source_item_code": "H21TC-DET-1", "call_number": "D1"}]}'::jsonb);
  v_lot10 := (public.fn_import_promote(v_run10, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
  SELECT m.draft_id INTO v_d20 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run10;
  SELECT x.id INTO v_xd FROM public.exemplar_drafts x WHERE x.book_draft_id = v_d20;
  UPDATE public.book_drafts SET bib_ref = 'H21TC-REF-' || id, tipo_material = 'livro' WHERE id IN (v_d19, v_d20);
  -- La notice existante qui absorbera d20, DÉTENUE par la bibliothèque (l'exemplaire y trouve sa détention).
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
  VALUES ('H21TC Notice qui absorbe', 'H21TC-B20', 'livro', v_lib) RETURNING id INTO v_book20;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_book20, v_lib);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T19 (b) un brouillon publie sous le tour 1 se republie apres le tour 2 : la liste figee compte les publies';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_res := public.fn_batch_review_request(v_lot9, 'H21TC : tour 1 du lot 9');
    v_rev9a := (v_res->>'review_id')::bigint;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict(v_rev9a, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_book19 := public.publish_book_draft(v_d19);
    -- Une notice faite à la main, rangée dans le lot après l'approbation (API) : un tour de plus.
    EXECUTE 'SET LOCAL ROLE authenticated';
    INSERT INTO public.book_drafts (titulo, bib_ref, tipo_material, owner_library_id, batch_id, status)
    VALUES ('H21TC Ajoutee au lot 9', 'H21TC-REF-MAIN-9', 'livro', v_lib, v_lot9, 'draft');
    EXECUTE 'RESET ROLE';
    SELECT id INTO v_dh9 FROM public.book_drafts WHERE bib_ref = 'H21TC-REF-MAIN-9';
    IF (SELECT batch_id FROM public.book_drafts WHERE id = v_dh9) IS DISTINCT FROM v_lot9 THEN
      RAISE EXCEPTION 'rangement refuse par le declencheur';
    END IF;
    v_n := public.fn_batch_ajouts_apres_revision(v_lot9);
    -- La coordination redemande (tour 2), l'administration approuve.
    v_res := public.fn_batch_review_request(v_lot9, 'H21TC : tour 2 du lot 9');
    v_rev9b := (v_res->>'review_id')::bigint;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict(v_rev9b, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    -- La file corrige la notice publiée et republie son brouillon (statut published).
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET titulo = 'H21TC Republiee apres le tour 2' WHERE id = v_d19;
    EXECUTE 'RESET ROLE';
    IF (SELECT titulo FROM public.book_drafts WHERE id = v_d19) IS DISTINCT FROM 'H21TC Republiee apres le tour 2' THEN
      RAISE EXCEPTION 'correction du brouillon publie refusee';
    END IF;
    v_hint := NULL; v_id := NULL;
    BEGIN
      v_id := public.publish_book_draft(v_d19);
      v_hint := 'publie';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    END;
    IF v_n = 1 AND v_hint = 'publie' AND v_id = v_book19
       AND (SELECT r.round = 2 AND r.requested_by = v_coord
                   AND r.draft_ids = ARRAY[least(v_d19, v_dh9), greatest(v_d19, v_dh9)]
              FROM public.catalog_batch_reviews r WHERE r.id = v_rev9b)
       AND (SELECT titulo FROM public.books WHERE id = v_book19) = 'H21TC Republiee apres le tour 2'
       AND (SELECT count(*) FROM public.books WHERE bib_ref = 'H21TC-REF-' || v_d19) = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : ajouts='||coalesce(v_n::text,'NULL')||' republier='||coalesce(v_hint,'NULL')
         ||' draft_ids tour 2='||coalesce((SELECT coalesce(r.draft_ids::text,'NULL') FROM public.catalog_batch_reviews r WHERE r.id = v_rev9b),'aucun tour')
         ||' (d19='||v_d19||')'); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    EXECUTE 'RESET ROLE';
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM);
  END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T20 (b) un exemplaire rattache, detache par l''absorption de sa notice apres approbation, reste couvert et se publie';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    IF v_xd IS NULL THEN RAISE EXCEPTION 'la promotion n''a pas cree l''exemplaire du fichier'; END IF;
    v_res := public.fn_batch_review_request(v_lot10, 'H21TC : notice et son exemplaire');
    v_rev10 := (v_res->>'review_id')::bigint;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict(v_rev10, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    -- « Même édition : fusionner » (API) : la notice importée est absorbée par la notice existante.
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM api.merge_draft_into_book(v_d20, v_book20, '{}'::jsonb);
    EXECUTE 'RESET ROLE';
    IF (SELECT x.book_draft_id IS NOT NULL OR x.batch_id IS DISTINCT FROM v_lot10 OR x.status <> 'draft'
          FROM public.exemplar_drafts x WHERE x.id = v_xd)
       OR (SELECT status FROM public.book_drafts WHERE id = v_d20) IS DISTINCT FROM 'cancelled' THEN
      RAISE EXCEPTION 'absorption sans l''effet attendu (exemplaire detache dans son lot, notice ecartee)';
    END IF;
    v_n := public.fn_batch_ajouts_apres_revision(v_lot10);
    v_hint := NULL; v_id := NULL;
    BEGIN
      v_id := public.publish_exemplar_draft(v_xd);
      v_hint := 'publie';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    END;
    IF v_hint = 'publie' AND v_n = 0
       AND (SELECT r.draft_ids = ARRAY[v_d20] AND r.exemplar_draft_ids = ARRAY[v_xd]
              FROM public.catalog_batch_reviews r WHERE r.id = v_rev10)
       AND (SELECT status FROM public.exemplar_drafts WHERE id = v_xd) = 'published'
       AND EXISTS (SELECT 1 FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id
                    WHERE e.id = v_id AND e.source_item_code = 'H21TC-DET-1' AND e.library_id = v_lib AND h.book_id = v_book20)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : publier='||coalesce(v_hint,'NULL')||' ajouts='||coalesce(v_n::text,'NULL')
         ||' exemplar_draft_ids='||coalesce((SELECT coalesce(r.exemplar_draft_ids::text,'NULL') FROM public.catalog_batch_reviews r WHERE r.id = v_rev10),'aucun tour')
         ||' (xd='||v_xd||')'); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    EXECUTE 'RESET ROLE';
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM);
  END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T21 (b) fn_batch_ajouts_apres_revision ne compte que les brouillons vivants hors liste, rattaches compris (IMP-28 d)';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    IF v_rev9b IS NULL OR public.fn_batch_review_status(v_lot9) IS DISTINCT FROM 'approved' THEN
      RAISE EXCEPTION 'pas de tour 2 approuve sur le lot 9 (T19)';
    END IF;
    -- Avant : d19 (publié) et dh9 (brouillon) sont tous deux dans la liste du tour 2.
    v_n := public.fn_batch_ajouts_apres_revision(v_lot9);
    -- Rangés après la demande du tour 2 (décor, postgres) : les trois vivants comptent — le
    -- rattaché aussi depuis IMP-28 d (il ne se publie plus avec sa notice hors de la liste).
    INSERT INTO public.book_drafts (titulo, bib_ref, tipo_material, owner_library_id, created_by, batch_id, status) VALUES
      ('H21TC T21 vivante',   'H21TC-REF-T21-VIF',  'livro', v_lib, v_coord, v_lot9, 'ready'),       -- comptée
      ('H21TC T21 corbeille', 'H21TC-REF-T21-CORB', 'livro', v_lib, v_coord, v_lot9, 'cancelled'),   -- non
      ('H21TC T21 publiee',   'H21TC-REF-T21-PUB',  'livro', v_lib, v_coord, v_lot9, 'published');   -- non
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, target_bib_ref, created_by, batch_id, book_draft_id, notes) VALUES
      ('create', 'draft',     'pending', v_lib, 'H21TC-B20', v_coord, v_lot9, NULL,  'H21TC-T21 vivant'),     -- compté
      ('create', 'cancelled', 'pending', v_lib, 'H21TC-B20', v_coord, v_lot9, NULL,  'H21TC-T21 corbeille'),  -- non
      ('create', 'published', 'ready',   v_lib, 'H21TC-B20', v_coord, v_lot9, NULL,  'H21TC-T21 publie'),     -- non
      ('create', 'draft',     'pending', v_lib, NULL,        v_coord, v_lot9, v_dh9, 'H21TC-T21 rattache');   -- compté (IMP-28 d)
    v_m := public.fn_batch_ajouts_apres_revision(v_lot9);
    SELECT l.after_review INTO v_k FROM public.fn_batch_reviews_list() l WHERE l.batch_id = v_lot9;
    IF v_n = 0 AND v_m = 3 AND v_k = 3
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : avant='||coalesce(v_n::text,'NULL')||' apres='||coalesce(v_m::text,'NULL')
         ||' after_review='||coalesce(v_k::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM);
  END;

  -- ─────────────────────────────────────────────────────────────────
  -- Après le rattrapage de T9 et T9b : aucun tour de production n'est plus sans liste. Un tour
  -- ÉCRIT sans liste ne naît que d'une fixture (lot_a_une_bibliotheque T15/T16, par exemple).
  v_t := 'T22 garde de compatibilite : un tour ecrit sans liste (fixture) couvre son lot, meme un brouillon range apres';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21tc-11.marc', 'h21tc-11.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run11;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
    VALUES (v_run11, 1, 'H21TC-11-1', 'H21TC Sous un tour sans liste', 'new_record', 'accept_new', '{"items": []}'::jsonb);
    v_lot11 := (public.fn_import_promote(v_run11, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
    SELECT m.draft_id INTO v_d22 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run11;
    UPDATE public.book_drafts SET bib_ref = 'H21TC-REF-' || id, tipo_material = 'livro' WHERE id = v_d22;
    INSERT INTO public.catalog_batch_reviews (batch_id, round, status, requested_by, reviewed_by, reviewed_at)
    VALUES (v_lot11, 1, 'approved', v_coord, v_admin, now());
    INSERT INTO public.book_drafts (titulo, bib_ref, tipo_material, owner_library_id, created_by, batch_id, status)
    VALUES ('H21TC Rangee apres un tour sans liste', 'H21TC-REF-MAIN-11', 'livro', v_lib, v_coord, v_lot11, 'draft') RETURNING id INTO v_d22h;
    IF NOT public.fn_batch_is_imported(v_lot11) THEN RAISE EXCEPTION 'le lot 11 n''est pas un lot importe : test sans objet'; END IF;
    v_n := public.fn_batch_ajouts_apres_revision(v_lot11);
    PERFORM public.publish_book_draft(v_d22);
    PERFORM public.publish_book_draft(v_d22h);
    IF v_n = 0
       AND (SELECT r.draft_ids IS NULL AND r.exemplar_draft_ids IS NULL FROM public.catalog_batch_reviews r WHERE r.batch_id = v_lot11)
       AND (SELECT count(*) FROM public.book_drafts WHERE id IN (v_d22, v_d22h) AND status = 'published') = 2
       AND (SELECT count(*) FROM public.books WHERE bib_ref IN ('H21TC-REF-' || v_d22, 'H21TC-REF-MAIN-11')) = 2
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : ajouts='||coalesce(v_n::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM);
  END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'REVISION-TOUR-COUVRE OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'REVISION-TOUR-COUVRE ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
