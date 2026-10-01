-- =====================================================================
-- AnarBib — Tests d'acceptation : « Promouvoir la sélection » ne promeut que
-- la sélection, dans le lot que le run a ouvert (H21 lot 0, REGISTRE IMP-26
-- et IMP-27 d, décisions de Xavier du 29/09/2026)
-- Date    : 2026-09-29 (T16-T20 : 2026-09-30, seconde passe après revue ;
--           T21-T23 : 2026-09-30, troisième passe ; T24-T28 : 2026-09-30,
--           quatrième passe ; T29-T32, et T20, T26 réécrits : 2026-09-30,
--           cinquième passe ; T33 : 2026-10-01, sixième passe)
-- Ref     : migration 20261001200931_h21_lot0_la_revision_suit_le_brouillon_importe
--           public.fn_import_promote(..., p_row_ids bigint[] DEFAULT NULL) ;
--           ingest.fn_bulk_create_book_drafts_from_run(..., p_row_ids) ;
--           ingest.fn_create_book_drafts_from_import_rows (le lot du run) ;
--           ingest.fn_create_item_drafts_for_batch(p_batch_id, p_created_by, p_staging_row_ids) ;
--           public.fn_import_set_editorial (lignes déjà converties ignorées,
--           et, pour 'accept_new', lignes rejetées ignorées ; clé de retour
--           skipped_rows — ex-skipped_already_converted de la seconde passe ;
--           une décision inconnue va jusqu'au refus de l'ingest : constat #12,
--           seconde et troisième passes ; une ligne écartée, discarded_draft_id
--           posé, n'accepte plus AUCUNE décision : quatrième passe ; les ids
--           ABSENTS du run — lignes remplacées par « Retraiter », lignes d'un
--           AUTRE run vivant, ids inexistants — sont comptés parmi les
--           ignorées, et 'reject' ignore une ligne déjà rejetée : cinquième
--           passe. Un run SUPPRIMÉ n'est PAS compté : le geste est refusé
--           comme avant, « Run % introuvable », sans HINT) ;
--           public.fn_import_reconcile_duplicates (lignes promues, rapprochées,
--           rejetées ou écartées ignorées et comptées, skipped_rows ; retour
--           sans erreur si rien ne reste : quatrième passe ; ids absents du run
--           comptés parmi les ignorées — un run supprimé, lui, refusé comme
--           pour la décision — : cinquième passe ; une ligne qui n'est plus rapprochable — notice
--           proposée descartée depuis le chargement, statut que l'ingest ne
--           rapproche pas — ignorée et comptée : sixième passe). Pour les deux,
--           une liste vide ou NULL garde le refus d'avant.
--
-- La sélection (p_row_ids) :
-- T1  une ligne choisie : une notice, ses exemplaires du fichier, rien d'autre.
-- T2  promotion INTERROMPUE (set_editorial validé, promote annulé : deux RPC,
--     deux transactions) : la ligne restée accept_new sans brouillon n'est
--     pas emportée par la sélection d'une autre. (Une ligne dont le brouillon
--     est SUPPRIMÉ n'est plus ce cas : le déclencheur
--     trg_book_drafts_ecarte_ligne_importee l'écarte, IMP-27 e.)
-- T3  ids hors sélection possible — autre run, autre bibliothèque, en attente,
--     rejetée, rattachée, déjà promue, inexistant, NULL, doublon — ignorés
--     sans erreur (aucun oracle d'existence).
-- T4  '{}' = rien (jamais « tout le run ») ; sélection sans ligne éligible =
--     rien : pas de lot, pas d'erreur, pas de clé created_drafts.
-- T5  NULL = tout le run ; les appels positionnels d'avant (1 et 3 arguments)
--     tiennent (non-régression).
-- T6  « tout le run » (NULL, défaut {accept_new}) ne promeut jamais une ligne
--     « Accepté (rattaché) » (IMP-26 h).
-- T7  la garde du dépôt compagnon tient avec une sélection (HINT réel).
-- T8  une signature par nom (promote, bulk, exemplaires du lot), droits
--     reposés, DEFINER et search_path.
-- Le lot du run (IMP-27 d) :
-- T9  les sélections successives d'un run vont dans le lot qu'il a ouvert,
--     sous le nom de ce lot (batch_name rendu) ; un autre run a le sien.
-- T10 une révision demandée : la sélection suivante ouvre un lot neuf.
-- T11 des retouches demandées (changes_requested) : la sélection suivante
--     rejoint ce lot.
-- T12 un lot approuvé : lot neuf.
-- T13 un lot fermé : lot neuf.
-- T14 un lot passé à une autre bibliothèque : lot neuf, de celle du run.
-- T15 les exemplaires : seulement ceux des lignes de la promotion en cours ;
--     un brouillon d'exemplaire supprimé entre deux sélections ne revient pas.
-- La décision posée avant la promotion (seconde revue du lot 0, constat #12 :
-- deux onglets sur le même run ; l'écran pose la décision de sa sélection,
-- puis promeut cette même sélection, ImportacoesPage.handlePromoteSelected) :
-- T16 fn_import_set_editorial(run, [I1 déjà promue, I2 en attente],
--     'accept_new') ne refuse plus : updated_rows 1, skipped_rows 1 ; I2
--     acceptée, I1 intacte (ligne entière).
-- T17 puis fn_import_promote(p_row_ids [I1, I2]) crée UN brouillon :
--     created_drafts 1 < 2 demandées, ce que l'écran annonce par
--     importacoes.fila.promotedPartial ; I1 garde son seul brouillon, et celui
--     d'I2 rejoint le lot du run (IMP-27 d).
-- T18 une sélection faite seulement de lignes converties (brouillon de notice,
--     exemplaire rapproché) : updated_rows 0, sans erreur, rien d'écrit, pour
--     'accept_new' comme pour 'reject'.
-- T19 'reject' sur une sélection mêlée [promue, rapprochée, en attente] ne
--     refuse plus : la ligne en attente est rejetée ; la promue (brouillon,
--     lien) et la rapprochée (exemplaire) restent intactes. Demandées moins
--     ignorées = rejetées (3 - skipped_rows 2 = updated_rows 1) : le
--     {rejected} que handleRejectSelected affiche par
--     importacoes.fila.rejectedPartial dit vrai.
-- T20 (réécrit à la cinquième passe) non-régression : liste vide ou NULL,
--     refus de la fonction d'ingest (« Aucune ligne fournie »), comme avant.
--     Ids absents du run I — une ligne promue et une en attente d'un autre
--     run, un id inexistant, NULL, un doublon — : ni refus ni écriture,
--     comptés ignorés une fois chacun ({updated_rows 0, skipped_rows 3}, et 2
--     pour 'accept_new' sur les deux lignes) ; le retour est celui de trois
--     ids inexistants, à l'identique (pas d'oracle : le compte ne dit pas ce
--     qui existe ailleurs). Avant : {updated_rows 0, skipped_rows 0}, que
--     l'écran annonçait « Lignes écartées. » en succès (constat S2).
-- « Accepté (nouveau) » ne relève pas une ligne rejetée (troisième passe,
-- l'« autre cas » du constat #12 : l'onglet chargé avant le rejet) :
-- T21 'accept_new' sur [I5 rejetée ailleurs, I6 en attente] : I5 reste
--     rejetée, ligne entière (skipped_rows 1), I6 acceptée (updated_rows 1) ;
--     puis fn_import_promote(p_row_ids [I5, I6]) crée UN brouillon, celui
--     d'I6 : created_drafts 1 < 2, promotedPartial dit vrai (avant : I5
--     relevée et promue, « Brouillons créés », succès plein).
-- T22 même chose pour une ligne ÉCARTÉE par la suppression de son brouillon
--     (IMP-27 e, déclencheur d'écartement, par l'API) : I7 reste écartée,
--     discarded_draft_id gardé (la preuve que lit la reprise au rejeu), aucun
--     second brouillon ; I8 seule promue (created_drafts 1 < 2). Depuis la
--     quatrième passe, I7 est ignorée à double titre (rejetée, écartée).
-- T23 une décision inconnue sur une sélection entièrement convertie [I1, I4]
--     n'a plus de retour anticipé : refus de l'ingest (« editorial_decision
--     invalide : nimporte »), rien d'écrit ; une décision valide écrite
--     autrement (' Pending ') garde le retour anticipé (updated_rows 0,
--     skipped_rows 2, decision rendue 'pending').
-- « Rapprocher » ignore ce qu'un autre onglet a déjà traité (quatrième passe ;
-- run K : l'autre onglet promeut P et E, puis purge le brouillon d'E, qui est
-- écartée ; il rapproche R et rejette J ; W, rapprochable, reste en attente).
-- Au niveau de la RPC : l'écran n'envoie à « Rapprocher » que des doublons
-- (R, J, W) ; P et E n'y viennent que par l'API.
-- T24 fn_import_reconcile_duplicates(run, [P, R, J, E, W]) ne refuse plus :
--     skipped_rows 4 ; W rapprochée (un exemplaire, dans le lot rendu, sur la
--     notice proposée) ; P, R, J, E intactes (lignes entières), aucun
--     exemplaire de plus (avant : refus en bloc, « Au moins une ligne a déjà
--     été convertie en rascunho… »).
-- T25 la même sélection, de nouveau (W rapprochée entre-temps) : retour
--     {created_items 0, skipped_rows 5} sans erreur ; ni lot, ni exemplaire,
--     ni ligne écrits (ignorées = envoyées : reconciledPartial, kind 'error').
-- T26 (réécrit à la cinquième passe) non-régression : [W2, W3], toutes
--     rapprochables, comme avant (skipped_rows 0, les clés d'avant, deux
--     exemplaires) ; liste vide ou NULL : « Aucune ligne fournie », comme
--     avant. Ids absents du run K — lignes d'un autre run (promue, rejetée, en
--     attente), un id inexistant, NULL, un doublon — : ni refus, ni lot, ni
--     exemplaire, comptés ignorés une fois chacun ({created_items 0,
--     skipped_rows 4}), le retour de quatre ids inexistants à l'identique (pas
--     d'oracle). Avant : le refus en bloc sans HINT « Aucune ligne eligible
--     au rapprochement pour le run K », affiché brut (constat S1).
-- Une ligne écartée n'accepte plus aucune décision (quatrième passe) :
-- T27 'pending' (par l'API : aucun écran ne l'envoie), 'accept_new' et
--     'reject' sur [E] seule : ignorées (updated_rows 0, skipped_rows 1) ; E
--     intacte, sa note d'écartement et discarded_draft_id compris.
-- T28 sur [E, Q en attente] : 'reject', 'pending' puis 'accept_new' ne
--     touchent que Q (updated_rows 1, skipped_rows 1) ; la promotion [E, Q]
--     ne crée que le brouillon de Q (avant : E remise en attente, acceptée,
--     promue — un second brouillon pour une ligne dont le premier a été
--     purgé, discarded_draft_id désignant encore l'ancien).
-- Les lignes sorties du run depuis le chargement de l'écran (cinquième passe ;
-- run L : un onglet chargé, puis « Retraiter » dans un autre — l'edge function,
-- en service_role, efface les lignes du run et les relit du fichier sous de
-- nouveaux id, process-partner-catalog-import/index.ts) ; les gestes de l'API
-- sous SET LOCAL ROLE authenticated :
-- T29 l'onglet périmé : « Rejeter » [L1, L2, L3] rend {updated_rows 0,
--     skipped_rows 3}, « Rapprocher » [L1, L2] {created_items 0, skipped_rows
--     2}, sans refus ; ni lot ni exemplaire ; les lignes relues telles que
--     l'edge function les a écrites (l'écran : rejectedPartial et
--     reconciledPartial, kind 'error'. Avant : {0, 0} et « Lignes écartées. »
--     en succès ; refus brut sans HINT).
-- T30 sélection mêlée, une ligne sortie du run et une ligne relue éligible :
--     « Rejeter » [L3, L3 relue] rejette la relue (updated_rows 1, skipped_rows
--     1) ; « Rapprocher » [L1, L1 relue] rapproche la relue (un exemplaire, dans
--     le lot rendu, sur la notice proposée ; skipped_rows 1) ; L2 relue,
--     hors sélection, intacte. Par l'API seule : à l'écran, loadRunRows
--     élague la sélection au rechargement (un ancien id, absent des lignes
--     reçues, en sort), et l'onglet qui n'a pas rechargé ne voit pas les
--     relues ; seule l'API mêle anciens et nouveaux id.
-- « Rejeter » ne réécrit pas une ligne déjà rejetée (cinquième passe ; run N) :
-- T31 N1 rapprochée ailleurs alors que son unique exemplaire est déjà dans la
--     bibliothèque (H19 : rejetée, avec la raison « Todos os exemplares desta
--     linha ja estao na biblioteca… », rows_already_held 1) ; l'onglet chargé
--     avant : « Rejeter » [N1] rend {updated_rows 0, skipped_rows 1}, [N1, N2]
--     ne rejette que N2 ; N1 intacte, ligne entière, la raison de H19 comprise
--     (avant : updated_rows 1, raison écrasée par celle de l'écran — S4).
-- T32 non-régression : 'pending' (par l'API) sur N3 rejetée à la main la
--     relève (updated_rows 1, skipped_rows 0) : seules 'reject' et
--     'accept_new' ignorent une ligne rejetée ; une ligne ÉCARTÉE, elle,
--     refuse toute décision (T27).
-- « Rapprocher » ne retient que ce que l'ingest rapproche (sixième passe ;
-- run V : deux onglets sur le même run. V1 et V3 proposent la notice Bx, que
-- BLMF seule détient ; V2, V4, V5, V7 la notice existante du run I ; V4 au
-- statut manual_decision, V6 au statut matched_draft — compatibles avec
-- « rattaché », mais que fn_create_exemplar_drafts_from_import_rows ne
-- rapproche pas ; un exemplaire chacune) :
-- T33 l'onglet B « Descartar » Bx au catalogue (CatalogPanel.discardItem →
--     discard_book_cascade : fonds de BLMF retiré, notice supprimée,
--     proposed_book_id de V1 et V3 vidé par la clé étrangère). L'onglet A,
--     chargé avant (il montre encore la notice de V1 et V3, et
--     handleReconcileSelected les envoie) : « Rapprocher » [V3] rend
--     {created_items 0, skipped_rows 1} sans refus, ni lot ni exemplaire
--     (l'écran : reconciledPartial {skipped 1, asked 1}, kind 'error') ;
--     [V1, V2] rend skipped_rows 1 et un seul exemplaire, celui de V2, dans
--     le lot rendu (reconciledPartial, kind 'info'). Par l'API : [V6, V4] ne
--     rapproche que V4 (skipped_rows 1 : manual_decision reste rapprochable).
--     Non-régression : [V5, V7], toutes éligibles, comme avant (skipped_rows
--     0, les clés d'avant, deux exemplaires). V1, V3 et V6 : lignes entières
--     telles qu'après le descarte — en attente, aucune décision « rattaché »,
--     aucun exemplaire. Avant (cinquième passe) : [V3] refusé en bloc, sans
--     HINT, « Aucune ligne eligible au rapprochement pour le run V », affiché
--     brut ; [V1, V2] skipped_rows 0, V1 passée à « rattaché » sans
--     exemplaire, et l'écran disait « Brouillon d'exemplaire créé » en succès.
--
-- Contre-épreuve (définitions d'avant le lot 0 rejouées avant la suite,
-- scratchpad h21-lot0-agents), jouée le 29/09 :
--   ancien-promote-bulk-items : 14/15 tombent — T1-T4, T7, T10, T11, T13,
--     T15 (pas de p_row_ids : 42883 ; T7 : hint de 42883 au lieu de
--     deposit_admin_only), T8 (anciennes signatures), T6 (l'ancien bulk passe
--     la ligne rattachée à la nouvelle création, qui refuse), T9, T12, T14 en
--     cascade. T5 tient.
--   ancien-fn_create_book_drafts_from_import_rows : T9, T10, T11, T15
--     tombent (un lot neuf à chaque sélection) ; les autres tiennent (T12-T14
--     sont des bornes : l'ancien code ouvrait toujours un lot neuf).
--   les deux ensemble (ancien-B-avant-lot0-promotion) : 14/15 ; T6 tombe
--     parce que la ligne rattachée devient une notice. T5 tient.
--   T5 est un test de NON-RÉGRESSION : il ne tombe avec aucune définition
--     d'avant ; il tombe avec le mutant bulk-null-egal-rien (NULL lu comme
--     « rien »).
--   mutants (ancien-B-*) : bulk-sans-selection → T1-T4 (T9-T15 en cascade :
--     la première sélection d'un run l'emporte entier) ; bulk-vide-egal-tout
--     → T4 (T9 en cascade) ; bulk-null-egal-rien → T5 (T9 en cascade) ;
--     lot-meme-revise → T10, T12 ; lot-retouches-exclues → T11 (T12 en
--     cascade) ; lot-meme-ferme → T13 (T14 en cascade) ;
--     lot-autre-bibliotheque → T14 ; items-toute-la-notice → T15 ;
--     droits-public → T8.
-- Contre-épreuve de T16-T20 (seconde passe, 30/09 ; scratchpad
-- h21-lot0-agents, fichiers D-*) :
--   fn_import_set_editorial du commit WIP 4ea3eace (garde « rattaché »
--     seule) : 16/20 — T16, T18, T19 tombent (« Au moins une ligne a déjà
--     été convertie en rascunho ; décision éditoriale verrouillée », sans
--     HINT) ; T17 tombe en cascade (I2 restée en attente : « Nenhuma linha
--     elegível », pas de created_drafts). T1-T15 et T20 tiennent.
--   fn_import_set_editorial d'avant le lot 0 : 16/20, mêmes chutes.
--   T20 est un test de NON-RÉGRESSION : il tient avec les deux définitions
--     d'avant ; il tombe (19/20) avec les mutants vide-egal-rien (liste vide
--     ou NULL rendue « 0 ligne » au lieu du refus) et sans-filtre-run (une
--     ligne convertie d'un autre run comptée dans skipped_already_converted).
--   mutant sans-exemplaire (seul le brouillon de notice rend une ligne
--     « convertie ») : 18/20 — T18 (la rapprochée passée à accept_new :
--     refus d'incompatibilité) et T19 (la rapprochée rejetée, son exemplaire
--     vivant).
--   mutant sans-compte (skipped_already_converted rendu à 0) : 18/20 — T16,
--     T19 (T18 passe par le retour anticipé, qui n'est pas muté).
--   (Ces mutants D-* visaient la définition de la seconde passe et sa clé
--   skipped_already_converted ; ils sont rejoués ci-dessous, B3-*, sur la
--   troisième.)
-- Contre-épreuve de la troisième passe (30/09 au soir ; scratchpad
-- h21-lot0-agents, fichiers B3-*, joués avant la suite par suite.sh ; la
-- suite seule : 23/23) :
--   fn_import_set_editorial de 817c68c8^ (= WIP 4ea3eace, garde « rattaché »
--     seule) : 16/23 — T16, T18, T19 tombent (refus brut « Au moins une ligne
--     a déjà été convertie en rascunho… ») et T17 en cascade (I2 restée en
--     attente) ; T21 et T22 tombent (I5 rejetée et I7 écartée relevées :
--     updated_rows 2, created_drafts 2 = 2 demandées, le succès plein que
--     l'écran annonçait à tort ; I7 repromue alors que discarded_draft_id
--     désigne encore l'ancien brouillon) ; T23 tombe par son seul témoin
--     ' Pending ' (refus brut de l'ingest, comme T18) — sa partie refus tient,
--     c'est la non-régression : l'ingest refusait déjà « nimporte ». T1-T15 et
--     T20 tiennent. La définition d'avant le lot 0 : 16/23, mêmes chutes.
--   mutant seconde-passe (logique de la seconde passe, clé skipped_rows
--     gardée : ni règle des lignes rejetées, ni validation avant le retour
--     anticipé) : 20/23 — T21, T22, T23 (« nimporte » rendu {updated_rows 0,
--     skipped_rows 2, editorial_decision "nimporte"}, sans refus).
--   mutant sans-regle-rejetees (cette seule règle retirée) : 21/23 — T21, T22.
--   mutant retour-sans-validation (ce seul retour anticipé muté) : 22/23 — T23.
--   mutant sans-compte (skipped_rows rendu à 0 au retour de l'ingest) :
--     19/23 — T16, T19, T21, T22 (T18 et T23 passent par le retour anticipé,
--     qui n'est pas muté).
--   mutant sans-filtre-run : 22/23 — T20 (skipped_rows 1 pour une ligne
--     convertie d'un autre run : un oracle).
--   mutant vide-egal-rien : 22/23 — T20 (liste vide et NULL acceptées).
--   mutant sans-exemplaire : 20/23 — T18 (refus d'incompatibilité), T19 (la
--     rapprochée rejetée), T23 (témoin : la rapprochée remise en attente).
-- Contre-épreuve de la quatrième passe (30/09, nuit ; scratchpad
-- h21-lot0-agents/P4, fichiers P4B-*, joués avant la suite par suite.sh ;
-- la suite seule : 28/28 ; bilans relevés sur une copie de la suite dont le
-- bilan ne liste que les identifiants — suite.sh coupe à 3000 caractères) :
--   fn_import_reconcile_duplicates d'avant le lot 0 : 26/28 — T24, T25
--     (refus en bloc « Au moins une ligne a déjà été convertie en
--     rascunho ; décision éditoriale verrouillée »). T26 tient : c'est la
--     non-régression.
--   mutants de « Rapprocher » (définition vivante, ancres comptées) :
--     sans-notice : 26/28 — T24, T25 (le même refus en bloc) ;
--     sans-exemplaire : 26/28 — T24 (R réécrite : 'approved' au lieu de
--       'draft_created'), T25 (« Aucune ligne eligible au rapprochement ») ;
--     sans-regle-rejetees : 27/28 — T24 (J relevée et rapprochée, exemplaire
--       H21B-EX-K3, skipped_rows 3 ; E reste ignorée par son autre verrou) ;
--     sans-ecartee-ni-rejetees : 26/28 — T24, T25 (E passée à l'ingest :
--       « accept_duplicate incompatible ») ;
--     sans-ecartee SEUL : 28/28, survivant attendu — une ligne écartée porte
--       toujours 'reject' (le déclencheur l'écrit, T27 garde qu'aucune
--       décision ne la relève) et la règle des rejetées la couvre : le filtre
--       discarded_draft_id est un second verrou, observable seulement l'autre
--       retiré (les deux mutants ci-dessus) ;
--     sans-compte : 27/28 — T24 (skipped_rows 0) ;
--     sans-retour-anticipe : 27/28 — T25 (« Aucune ligne fournie ») ;
--     sans-filtre-run : 27/28 — T26 (lignes d'un autre run comptées :
--       {created_items 0, skipped_rows 2} au lieu du refus, un oracle).
--   fn_import_set_editorial :
--     mutant decision-sans-filtre-ecartee (sémantique de la troisième passe,
--       817c68c8) : 26/28 — T27 (updated_rows 1 pour chacune des trois
--       décisions), T28 (E remise en attente, acceptée, promue : un second
--       brouillon, discarded_draft_id désignant l'ancien). T22 tient : pour
--       'accept_new', la règle des rejetées couvre I7.
--     mutant decision-ni-ecartee-ni-rejetees : 24/28 — T21, T22, T27, T28.
--     de 817c68c8^ (B3-avant-817c68c8) et d'avant le lot 0 (D-avant-lot0) :
--       19/28 — T16-T19, T21-T23, T27, T28.
--   Mutants B3-* de la troisième passe rejoués sur la quatrième (28 tests) :
--     seconde-passe 26/28 (T21, T23) et sans-regle-rejetees 27/28 (T21) — T22
--     ne tombe plus avec eux : le filtre des lignes écartées couvre désormais
--     I7 ; sans-compte 23/28 (T16, T19, T21, T22, T28 ; T27 passe par le
--     retour anticipé) ; retour-sans-validation 27/28 (T23) ; sans-filtre-run
--     et vide-egal-rien 27/28 (T20) ; sans-exemplaire 25/28 (T18, T19, T23).
-- Contre-épreuve de la cinquième passe (30/09, nuit ; scratchpad
-- h21-lot0-agents/P5, fichiers P5-*, joués avant la suite par suite.sh ; la
-- suite seule : 32/32, file net.http_request_queue vide ; bilans relevés sur
-- une copie au bilan court, P5-suite-ids.sql, et le détail des chutes sur
-- P5-suite-detail.sql). T20 et T26 sont réécrits à cette passe : les bilans
-- ci-dessus des passes précédentes portent sur leur ancienne forme (les ids
-- d'un autre run y rendaient {0, 0} ou le refus brut).
--   quatrieme-passe (les deux fonctions à la sémantique de la quatrième
--     passe, reconstituée de 817c68c8 et du diff relevé à 21:25 : compte des
--     seules lignes du run non éligibles ; règle des rejetées pour
--     'accept_new' seul) : 27/32 — T20 et T29 (« Rejeter » : {updated_rows 0,
--     skipped_rows 0}, le faux succès), T26 et T29 (« Rapprocher » : refus
--     brut « Aucune ligne eligible au rapprochement pour le run … », sans
--     HINT), T30 (sélection mêlée : skipped_rows 0, la ligne effacée passée
--     sous silence),
--     T31 (N1 re-rejetée, updated_rows 1, la raison de H19 écrasée par celle
--     de l'écran).
--   mutants ciblés (définitions vivantes, ancres comptées) :
--     decision-sans-absentes (compte des seules lignes du run) : 29/32 — T20,
--       T29, T30 ;
--     rapprocher-sans-absentes : 29/32 — T26, T29, T30 ;
--     decision-reject-sur-reject (règle des rejetées limitée à 'accept_new') :
--       31/32 — T31 ;
--     decision-regle-etendue-pending (la règle couvre aussi 'pending') :
--       30/32 — T32 et T28 (Q, rejetée à la main, ne se relève plus) ;
--     decision-cardinalite-brute (cardinality(p_row_ids), NULL et doublon
--       comptés) : 31/32 — T20 (skipped_rows 5) ;
--     rapprocher-cardinalite-brute : 31/32 — T26 (skipped_rows 6) ;
--     rapprocher-vide-egal-rien (liste vide rendue « 0 ligne ») : 31/32 — T26.
--   Mutants des passes précédentes rejoués (32 tests). Ceux dont une ancre
--   « compte » a disparu (le compte se déduit désormais du filtre) sont
--   adaptés, garde seule mutée (P5-*) :
--     decision-sans-exemplaire 29/32 (T18, T19, T23) ; decision-sans-regle-
--     rejetees 30/32 (T21, T31) ; decision-sans-filtre-ecartee 30/32 (T27,
--     T28 ; T22 tient, la règle des rejetées couvre I7) ; decision-ni-ecartee-
--     ni-rejetees 27/32 (T21, T22, T27, T28, T31) ; decision-seconde-passe
--     29/32 (T21, T23, T31) ; rapprocher-sans-notice et rapprocher-sans-
--     exemplaire 30/32 (T24, T25) ; rapprocher-sans-regle-rejetees 31/32
--     (T24) ; rapprocher-sans-ecartee-ni-rejetees 30/32 (T24, T25) ;
--     rapprocher-sans-ecartee SEUL : 32/32, le survivant attendu de la
--     quatrième passe (second verrou, voir plus haut).
--   Rejoués tels quels : B3 retour-sans-validation 31/32 (T23) ; B3
--     sans-compte 25/32 (T16, T19, T21, T22, T28, T30, T31) ; B3
--     sans-filtre-run 31/32 (T20 : la ligne en attente de l'autre run n'est
--     plus comptée, skipped_rows 2 au lieu des 3 que rendent trois ids
--     inexistants — l'oracle) ; B3 vide-egal-rien 31/32 (T20) ; P4B
--     rapprocher-sans-compte 30/32 (T24, T30) ; P4B rapprocher-sans-filtre-run
--     31/32 (T26 : la ligne en attente de l'autre run passe à l'ingest, refus
--     brut) ; P4B rapprocher-sans-retour-anticipe 29/32 (T25, T26, T29).
-- Contre-épreuve de la sixième passe (01/10 ; scratchpad
-- h21-lot0-agents/P6/F, fichiers F-rapprocher-*, définition vivante, ancres
-- comptées, joués avant la suite par suite.sh ; la suite seule : 33/33). Les
-- bilans ci-dessus portent sur 32 tests au plus : ils n'ont pas été rejoués
-- avec T33.
--   cinquieme-passe (le filtre de « Rapprocher » sans les deux conditions
--     d'éligibilité de l'ingest, soit le bloc de la cinquième passe) : 32/33
--     — T33 : [V3] refusé en bloc, « Aucune ligne eligible au rapprochement
--     pour le run V » ; [V1, V2] skipped_rows 0, V1 passée à
--     accept_duplicate/approved sans exemplaire ; [V6, V4] skipped_rows 0,
--     V6 passée à « rattaché » sans exemplaire.
--   mutants ciblés :
--     sans-notice-proposee : 32/33 — T33 ([V3] refusé en bloc ; V1
--       « rattachée » sans exemplaire ; [V6, V4] tient) ;
--     sans-statut : 32/33 — T33 ([V3] et [V1, V2] tiennent ; V6
--       « rattachée » sans exemplaire, skipped_rows 0) ;
--     statuts-de-l-ecran (manual_decision retirée de la liste) : 32/33 —
--       T33 ([V6, V4] rend {created_items 0, skipped_rows 2}, V4 laissée en
--       attente).
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'IMPORT-PROMOTION-SELECTION OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_admin uuid := '22222222-2222-2222-2222-222222222222';  -- compte sans rôle (seed) -> admin réseau ici
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF de test (seed)
  v_libB  uuid;
  v_src bigint; v_srcB bigint; v_srcD bigint;
  v_runA bigint; v_runB bigint; v_runC bigint; v_runD bigint;
  v_runE bigint; v_runF bigint; v_runG bigint; v_runH bigint;
  v_r1 bigint; v_r2 bigint; v_r3 bigint; v_rorph bigint; v_rpend bigint; v_rrej bigint; v_rdup bigint;
  v_rb1 bigint; v_rc1 bigint; v_rd1 bigint;
  v_e1 bigint; v_e2 bigint; v_e3 bigint; v_f1 bigint; v_f2 bigint; v_f3 bigint;
  v_g1 bigint; v_g2 bigint; v_g3 bigint; v_h1 bigint; v_h2 bigint;
  v_resA1 jsonb; v_resA2 jsonb; v_resA3 jsonb; v_resA5 jsonb; v_resB jsonb;
  v_res jsonb; v_res2 jsonb; v_res3 jsonb;
  v_lotA bigint; v_lotF bigint; v_lotG2 bigint; v_lot1 bigint; v_lot2 bigint; v_lot3 bigint;
  v_n int; v_m int; v_k int; v_hint text; v_txt text; v_ok boolean;
  v_book bigint; v_runI bigint; v_i1 bigint; v_i2 bigint; v_i3 bigint; v_i4 bigint;
  v_d1 bigint; v_x4 bigint; v_snap jsonb; v_err text;
  v_i5 bigint; v_i6 bigint; v_i7 bigint; v_i8 bigint; v_d7 bigint;
  v_runK bigint; v_kp bigint; v_kr bigint; v_kj bigint; v_ke bigint; v_kw bigint;
  v_kw2 bigint; v_kw3 bigint; v_kq bigint; v_kdp bigint; v_kde bigint; v_kxr bigint;
  v_res4 jsonb; v_nb int; v_nx int; v_msg text;
  v_runL bigint; v_l1 bigint; v_l2 bigint; v_l3 bigint; v_l1n bigint; v_l2n bigint; v_l3n bigint;
  v_runN bigint; v_n1 bigint; v_n2 bigint; v_n3 bigint; v_exh bigint;
  v_bx bigint; v_runV bigint; v_v1 bigint; v_v2 bigint; v_v3 bigint; v_v4 bigint;
  v_v5 bigint; v_v6 bigint; v_v7 bigint; v_res5 jsonb;
  rec record;
BEGIN
  -- ── Décor (postgres, identité de la coordination BLMF dans le jeton) ──
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');
  INSERT INTO public.catalog_ref_source_partners (code, label, sort_order, is_active)
  VALUES ('other_partner', 'Outro parceiro', 80, true) ON CONFLICT (code) DO NOTHING;
  INSERT INTO public.libraries (id, slug, name, is_active, visibility_level)
  VALUES (gen_random_uuid(), 'essai-h21b-b', 'Essai H21B — B', true, 'private') RETURNING id INTO v_libB;

  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('Essai H21B propre', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO v_src;
  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('Essai H21B propre de B', v_libB, 'mapeada', 'own_catalog', true) RETURNING id INTO v_srcB;
  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('Essai H21B depot compagnon', v_lib, 'mapeada', 'partner_deposit', true) RETURNING id INTO v_srcD;

  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h21b-a.mrc', 'h21b-a.mrc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_runA;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h21b-b.mrc', 'h21b-b.mrc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_runB;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_srcB, v_libB, 'essai/h21b-c.mrc', 'h21b-c.mrc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_runC;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_srcD, v_lib, 'essai/h21b-d.mrc', 'h21b-d.mrc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_runD;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h21b-e.mrc', 'h21b-e.mrc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_runE;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h21b-f.mrc', 'h21b-f.mrc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_runF;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h21b-g.mrc', 'h21b-g.mrc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_runG;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h21b-h.mrc', 'h21b-h.mrc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_runH;

  -- Run A : trois lignes à promouvoir (un exemplaire chacune), une ligne qui
  -- restera accept_new sans brouillon (T2), une en attente, une rejetée, une
  -- rattachée (accept_duplicate).
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, normalized_payload)
  VALUES (v_runA, 1, 'H21B-A1', 'H21B Notice A1', 'new_record', 'accept_new', 'approved',
          jsonb_build_object('items', '[{"source_item_code": "H21B-EX-A1", "call_number": "H21B A1"}]'::jsonb)) RETURNING id INTO v_r1;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, normalized_payload)
  VALUES (v_runA, 2, 'H21B-A2', 'H21B Notice A2', 'new_record', 'accept_new', 'approved',
          jsonb_build_object('items', '[{"source_item_code": "H21B-EX-A2", "call_number": "H21B A2"}]'::jsonb)) RETURNING id INTO v_r2;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, normalized_payload)
  VALUES (v_runA, 3, 'H21B-A3', 'H21B Notice A3', 'new_record', 'accept_new', 'approved',
          jsonb_build_object('items', '[{"source_item_code": "H21B-EX-A3", "call_number": "H21B A3"}]'::jsonb)) RETURNING id INTO v_r3;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
  VALUES (v_runA, 4, 'H21B-A4', 'H21B Notice restee en file', 'new_record', 'pending', 'pending') RETURNING id INTO v_rorph;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
  VALUES (v_runA, 5, 'H21B-A5', 'H21B Notice en attente', 'new_record', 'pending', 'pending') RETURNING id INTO v_rpend;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
  VALUES (v_runA, 6, 'H21B-A6', 'H21B Notice rejetee', 'new_record', 'reject', 'rejected') RETURNING id INTO v_rrej;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
  VALUES (v_runA, 7, 'H21B-A7', 'H21B Notice rattachee', 'possible_duplicate', 'accept_duplicate', 'approved') RETURNING id INTO v_rdup;

  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
  VALUES (v_runB, 1, 'H21B-B1', 'H21B Notice du run B', 'new_record', 'accept_new', 'approved') RETURNING id INTO v_rb1;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
  VALUES (v_runC, 1, 'H21B-C1', 'H21B Notice d''une autre bibliotheque', 'new_record', 'accept_new', 'approved') RETURNING id INTO v_rc1;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
  VALUES (v_runD, 1, 'H21B-D1', 'H21B Notice d''un depot compagnon', 'new_record', 'accept_new', 'approved') RETURNING id INTO v_rd1;

  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
  VALUES (v_runE, 1, 'H21B-E1', 'H21B Notice E1', 'new_record', 'accept_new', 'approved') RETURNING id INTO v_e1;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
  VALUES (v_runE, 2, 'H21B-E2', 'H21B Notice E2', 'new_record', 'accept_new', 'approved') RETURNING id INTO v_e2;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
  VALUES (v_runE, 3, 'H21B-E3', 'H21B Notice E3', 'new_record', 'accept_new', 'approved') RETURNING id INTO v_e3;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
  VALUES (v_runF, 1, 'H21B-F1', 'H21B Notice F1', 'new_record', 'accept_new', 'approved') RETURNING id INTO v_f1;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
  VALUES (v_runF, 2, 'H21B-F2', 'H21B Notice F2', 'new_record', 'accept_new', 'approved') RETURNING id INTO v_f2;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
  VALUES (v_runF, 3, 'H21B-F3', 'H21B Notice F3', 'new_record', 'accept_new', 'approved') RETURNING id INTO v_f3;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
  VALUES (v_runG, 1, 'H21B-G1', 'H21B Notice G1', 'new_record', 'accept_new', 'approved') RETURNING id INTO v_g1;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
  VALUES (v_runG, 2, 'H21B-G2', 'H21B Notice G2', 'new_record', 'accept_new', 'approved') RETURNING id INTO v_g2;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
  VALUES (v_runG, 3, 'H21B-G3', 'H21B Notice G3', 'new_record', 'accept_new', 'approved') RETURNING id INTO v_g3;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, normalized_payload)
  VALUES (v_runH, 1, 'H21B-H1', 'H21B Notice H1', 'new_record', 'accept_new', 'approved',
          jsonb_build_object('items', '[{"source_item_code": "H21B-EX-H1", "call_number": "H21B H1"}]'::jsonb)) RETURNING id INTO v_h1;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, normalized_payload)
  VALUES (v_runH, 2, 'H21B-H2', 'H21B Notice H2', 'new_record', 'accept_new', 'approved',
          jsonb_build_object('items', '[{"source_item_code": "H21B-EX-H2", "call_number": "H21B H2"}]'::jsonb)) RETURNING id INTO v_h2;

  -- Run I (T16-T20, constat #12) : une ligne que « l'autre onglet » promeut
  -- (I1), une qu'il rapproche d'une notice du catalogue (I4), deux en attente.
  INSERT INTO public.books (titulo, bib_ref, tipo_material)
  VALUES ('H21B Notice existante', 'H21B-RATT-I4', 'livro') RETURNING id INTO v_book;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h21b-i.mrc', 'h21b-i.mrc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_runI;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, normalized_payload)
  VALUES (v_runI, 1, 'H21B-I1', 'H21B Notice I1', 'new_record', 'accept_new', 'approved',
          jsonb_build_object('items', '[{"source_item_code": "H21B-EX-I1", "call_number": "H21B I1"}]'::jsonb)) RETURNING id INTO v_i1;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
  VALUES (v_runI, 2, 'H21B-I2', 'H21B Notice I2', 'new_record', 'pending', 'pending') RETURNING id INTO v_i2;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
  VALUES (v_runI, 3, 'H21B-I3', 'H21B Notice I3', 'new_record', 'pending', 'pending') RETURNING id INTO v_i3;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, proposed_book_id, normalized_payload)
  VALUES (v_runI, 4, 'H21B-I4', 'H21B Notice I4 a rapprocher', 'matched_book', 'pending', 'pending', v_book,
          jsonb_build_object('items', '[{"source_item_code": "H21B-EX-I4", "call_number": "H21B I4"}]'::jsonb)) RETURNING id INTO v_i4;

  -- Run K (T24-T28, quatrième passe) : ce que deux onglets se disputent. P et
  -- E, nouvelles, que l'autre onglet promeut (E, il en vide ensuite le
  -- brouillon : écartée) ; R, doublon, qu'il rapproche ; J, doublon, qu'il
  -- rejette ; W, doublon rapprochable, restée en attente. W2 et W3,
  -- rapprochables (non-régression) ; Q, nouvelle (T28). Tous les doublons
  -- désignent la notice existante du run I, un exemplaire chacun.
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h21b-k.mrc', 'h21b-k.mrc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_runK;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
  VALUES (v_runK, 1, 'H21B-KP', 'H21B Notice KP promue ailleurs', 'new_record', 'pending', 'pending') RETURNING id INTO v_kp;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, proposed_book_id, normalized_payload)
  VALUES (v_runK, 2, 'H21B-KR', 'H21B Notice KR rapprochee ailleurs', 'matched_book', 'pending', 'pending', v_book,
          jsonb_build_object('items', '[{"source_item_code": "H21B-EX-K2", "call_number": "H21B K2"}]'::jsonb)) RETURNING id INTO v_kr;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, proposed_book_id, normalized_payload)
  VALUES (v_runK, 3, 'H21B-KJ', 'H21B Notice KJ rejetee ailleurs', 'matched_book', 'pending', 'pending', v_book,
          jsonb_build_object('items', '[{"source_item_code": "H21B-EX-K3", "call_number": "H21B K3"}]'::jsonb)) RETURNING id INTO v_kj;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
  VALUES (v_runK, 4, 'H21B-KE', 'H21B Notice KE ecartee ailleurs', 'new_record', 'pending', 'pending') RETURNING id INTO v_ke;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, proposed_book_id, normalized_payload)
  VALUES (v_runK, 5, 'H21B-KW', 'H21B Notice KW a rapprocher', 'matched_book', 'pending', 'pending', v_book,
          jsonb_build_object('items', '[{"source_item_code": "H21B-EX-K5", "call_number": "H21B K5"}]'::jsonb)) RETURNING id INTO v_kw;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, proposed_book_id, normalized_payload)
  VALUES (v_runK, 6, 'H21B-KW2', 'H21B Notice KW2 a rapprocher', 'possible_duplicate', 'pending', 'pending', v_book,
          jsonb_build_object('items', '[{"source_item_code": "H21B-EX-K6", "call_number": "H21B K6"}]'::jsonb)) RETURNING id INTO v_kw2;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, proposed_book_id, normalized_payload)
  VALUES (v_runK, 7, 'H21B-KW3', 'H21B Notice KW3 a rapprocher', 'matched_book', 'pending', 'pending', v_book,
          jsonb_build_object('items', '[{"source_item_code": "H21B-EX-K7", "call_number": "H21B K7"}]'::jsonb)) RETURNING id INTO v_kw3;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
  VALUES (v_runK, 8, 'H21B-KQ', 'H21B Notice KQ', 'new_record', 'pending', 'pending') RETURNING id INTO v_kq;

  -- Run L (T29-T30, cinquième passe) : trois lignes qu'un onglet a chargées
  -- avant qu'un autre « Retraite » le run (lignes effacées, relues du fichier
  -- sous de nouveaux id). L1 et L2, doublons rapprochables de la notice
  -- existante du run I ; L3, nouvelle. Rien n'y est promu, rapproché ni
  -- écarté : « Retraiter » est accepté pour ce run.
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h21b-l.mrc', 'h21b-l.mrc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_runL;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, proposed_book_id, normalized_payload)
  VALUES (v_runL, 1, 'H21B-L1', 'H21B Notice L1 a rapprocher', 'matched_book', 'pending', 'pending', v_book,
          jsonb_build_object('items', '[{"source_item_code": "H21B-EX-L1", "call_number": "H21B L1"}]'::jsonb)) RETURNING id INTO v_l1;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, proposed_book_id, normalized_payload)
  VALUES (v_runL, 2, 'H21B-L2', 'H21B Notice L2 a rapprocher', 'possible_duplicate', 'pending', 'pending', v_book,
          jsonb_build_object('items', '[{"source_item_code": "H21B-EX-L2", "call_number": "H21B L2"}]'::jsonb)) RETURNING id INTO v_l2;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
  VALUES (v_runL, 3, 'H21B-L3', 'H21B Notice L3', 'new_record', 'pending', 'pending') RETURNING id INTO v_l3;

  -- Run N (T31-T32, cinquième passe) : N1, doublon dont l'unique exemplaire
  -- porte le code d'origine d'un exemplaire déjà dans la bibliothèque (T31 le
  -- pose : « Rapprocher » la marque alors rejetée, avec la raison de H19) ;
  -- N2 et N3, nouvelles.
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h21b-n.mrc', 'h21b-n.mrc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_runN;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, proposed_book_id, normalized_payload)
  VALUES (v_runN, 1, 'H21B-N1', 'H21B Notice N1 deja detenue', 'matched_book', 'pending', 'pending', v_book,
          jsonb_build_object('items', '[{"source_item_code": "H21B-HELD-N1", "call_number": "H21B N1"}]'::jsonb)) RETURNING id INTO v_n1;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
  VALUES (v_runN, 2, 'H21B-N2', 'H21B Notice N2', 'new_record', 'pending', 'pending') RETURNING id INTO v_n2;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
  VALUES (v_runN, 3, 'H21B-N3', 'H21B Notice N3', 'new_record', 'pending', 'pending') RETURNING id INTO v_n3;

  -- Run V (T33, sixième passe) : V1 et V3 proposent la notice Bx, que BLMF
  -- seule détient (« Descartar » la supprime) ; V2, V4, V5, V7 la notice
  -- existante du run I, qui reste. V4 au statut manual_decision, V6 au statut
  -- matched_draft : tous deux compatibles avec « rattaché », mais seul le
  -- premier est rapproché par l'ingest. Un exemplaire chacune.
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
  VALUES ('H21B Notice Bx detenue par BLMF seule', 'H21B-BX', 'livro', v_lib) RETURNING id INTO v_bx;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_bx, v_lib);
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h21b-v.mrc', 'h21b-v.mrc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_runV;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, proposed_book_id, normalized_payload)
  VALUES (v_runV, 1, 'H21B-V1', 'H21B Notice V1 (Bx)', 'matched_book', 'pending', 'pending', v_bx,
          jsonb_build_object('items', '[{"source_item_code": "H21B-EX-V1", "call_number": "H21B V1"}]'::jsonb)) RETURNING id INTO v_v1;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, proposed_book_id, normalized_payload)
  VALUES (v_runV, 2, 'H21B-V2', 'H21B Notice V2', 'possible_duplicate', 'pending', 'pending', v_book,
          jsonb_build_object('items', '[{"source_item_code": "H21B-EX-V2", "call_number": "H21B V2"}]'::jsonb)) RETURNING id INTO v_v2;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, proposed_book_id, normalized_payload)
  VALUES (v_runV, 3, 'H21B-V3', 'H21B Notice V3 (Bx)', 'matched_book', 'pending', 'pending', v_bx,
          jsonb_build_object('items', '[{"source_item_code": "H21B-EX-V3", "call_number": "H21B V3"}]'::jsonb)) RETURNING id INTO v_v3;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, proposed_book_id, normalized_payload)
  VALUES (v_runV, 4, 'H21B-V4', 'H21B Notice V4 decision manuelle', 'manual_decision', 'pending', 'pending', v_book,
          jsonb_build_object('items', '[{"source_item_code": "H21B-EX-V4", "call_number": "H21B V4"}]'::jsonb)) RETURNING id INTO v_v4;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, proposed_book_id, normalized_payload)
  VALUES (v_runV, 5, 'H21B-V5', 'H21B Notice V5', 'matched_book', 'pending', 'pending', v_book,
          jsonb_build_object('items', '[{"source_item_code": "H21B-EX-V5", "call_number": "H21B V5"}]'::jsonb)) RETURNING id INTO v_v5;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, proposed_book_id, normalized_payload)
  VALUES (v_runV, 6, 'H21B-V6', 'H21B Notice V6 brouillon apparie', 'matched_draft', 'pending', 'pending', v_book,
          jsonb_build_object('items', '[{"source_item_code": "H21B-EX-V6", "call_number": "H21B V6"}]'::jsonb)) RETURNING id INTO v_v6;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, proposed_book_id, normalized_payload)
  VALUES (v_runV, 7, 'H21B-V7', 'H21B Notice V7', 'possible_duplicate', 'pending', 'pending', v_book,
          jsonb_build_object('items', '[{"source_item_code": "H21B-EX-V7", "call_number": "H21B V7"}]'::jsonb)) RETURNING id INTO v_v7;

  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 la selection seule : une ligne choisie, une notice, ses exemplaires, rien d''autre';
  BEGIN
    v_resA1 := public.fn_import_promote(v_runA, p_batch_name := 'H21B-LOT-A1', p_row_ids := ARRAY[v_r1]);
    v_lotA := (v_resA1->>'batch_id')::bigint;
    SELECT count(*) INTO v_n FROM ingest.partner_catalog_row_to_draft WHERE run_id = v_runA;
    IF (v_resA1->>'created_drafts')::int = 1
       AND v_resA1->'selected_row_ids' = to_jsonb(ARRAY[v_r1])
       AND v_n = 1
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft WHERE staging_row_id = v_r1 AND batch_id = v_lotA)
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                        WHERE id IN (v_r2, v_r3) AND (created_book_draft_id IS NOT NULL OR editorial_decision <> 'accept_new'))
       AND (SELECT count(*) FROM public.book_drafts WHERE batch_id = v_lotA) = 1
       AND (SELECT array_agg(source_item_code) FROM public.exemplar_drafts WHERE batch_id = v_lotA) = ARRAY['H21B-EX-A1']
       AND (v_resA1->>'items_created')::int = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : liens run A='||v_n||' / '||left(coalesce(v_resA1::text, '∅'), 400)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 ──────────────────────────────────────────────────────────────
  v_t := 'T2 promotion interrompue : la ligne restee accept_new sans brouillon n''est pas emportee par la selection d''une autre';
  BEGIN
    -- L'écran pose la décision (RPC validée), puis la promotion échoue (RPC
    -- annulée) : la ligne reste accept_new, sans brouillon ni lien.
    PERFORM public.fn_import_set_editorial(v_runA, ARRAY[v_rorph], 'accept_new', NULL);
    v_txt := NULL;
    BEGIN
      PERFORM public.fn_import_promote(v_runA, p_row_ids := ARRAY[v_rorph]);
      RAISE EXCEPTION 'H21B interruption simulee';
    EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM;
    END;
    v_ok := v_txt = 'H21B interruption simulee'
            AND EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                         WHERE id = v_rorph AND editorial_decision = 'accept_new' AND created_book_draft_id IS NULL)
            AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft WHERE staging_row_id = v_rorph);
    v_resA2 := public.fn_import_promote(v_runA, p_batch_name := 'H21B-LOT-A2', p_row_ids := ARRAY[v_r2]);
    IF v_ok
       AND (v_resA2->>'created_drafts')::int = 1
       AND v_resA2->'selected_row_ids' = to_jsonb(ARRAY[v_r2])
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows WHERE id = v_r2 AND created_book_draft_id IS NOT NULL)
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                    WHERE id = v_rorph AND created_book_draft_id IS NULL AND editorial_decision = 'accept_new')
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft WHERE staging_row_id = v_rorph)
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows WHERE id = v_r3 AND created_book_draft_id IS NOT NULL)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : preparation='||coalesce(v_ok::text, '∅')||' ('||coalesce(v_txt, '∅')||') / '||left(coalesce(v_resA2::text, '∅'), 400)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 ids hors selection possible (autre run, autre bibliotheque, en attente, rejetee, rattachee, deja promue, inexistant, NULL, doublon) : ignores sans erreur';
  BEGIN
    v_resA3 := public.fn_import_promote(v_runA,
                 p_row_ids := ARRAY[v_r3, v_rb1, v_rc1, v_rpend, v_rrej, v_rdup, v_r1, -1, NULL, v_r3]);
    IF (v_resA3->>'created_drafts')::int = 1
       AND v_resA3->'selected_row_ids' = to_jsonb(ARRAY[v_r3])
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows WHERE id = v_r3 AND created_book_draft_id IS NOT NULL)
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                        WHERE id IN (v_rb1, v_rc1, v_rpend, v_rrej, v_rdup, v_rorph) AND created_book_draft_id IS NOT NULL)
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft
                        WHERE staging_row_id IN (v_rb1, v_rc1, v_rpend, v_rrej, v_rdup, v_rorph))
       AND (SELECT editorial_decision FROM ingest.partner_catalog_staging_rows WHERE id = v_rpend) = 'pending'
       AND (SELECT editorial_decision FROM ingest.partner_catalog_staging_rows WHERE id = v_rrej) = 'reject'
       AND (SELECT editorial_decision FROM ingest.partner_catalog_staging_rows WHERE id = v_rdup) = 'accept_duplicate'
       AND (SELECT count(*) FROM ingest.partner_catalog_row_to_draft WHERE staging_row_id = v_r1) = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(coalesce(v_resA3::text, '∅'), 400)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 ──────────────────────────────────────────────────────────────
  v_t := 'T4 ''{}'' = rien, et une selection sans ligne eligible = rien : ni lot, ni erreur, ni created_drafts';
  BEGIN
    SELECT count(*) INTO v_n FROM public.catalog_batches;
    v_res  := public.fn_import_promote(v_runA, p_row_ids := '{}'::bigint[]);
    v_res2 := public.fn_import_promote(v_runA, p_row_ids := ARRAY[v_rpend]);
    SELECT count(*) INTO v_m FROM public.catalog_batches;
    IF (v_res->>'selected_count')::int = 0 AND NOT (v_res ? 'created_drafts') AND NOT (v_res ? 'batch_id')
       AND (v_res2->>'selected_count')::int = 0 AND NOT (v_res2 ? 'created_drafts') AND NOT (v_res2 ? 'batch_id')
       AND v_m = v_n
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                    WHERE id = v_rorph AND created_book_draft_id IS NULL AND editorial_decision = 'accept_new')
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft WHERE staging_row_id IN (v_rorph, v_rpend))
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : lots '||v_n||' -> '||v_m||' / vide='||left(coalesce(v_res::text, '∅'), 250)||' / en attente='||left(coalesce(v_res2::text, '∅'), 250)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T5 ──────────────────────────────────────────────────────────────
  v_t := 'T5 non-regression : NULL = tout le run, appels positionnels d''avant (1 et 3 arguments)';
  BEGIN
    v_resB  := public.fn_import_promote(v_runB, ARRAY['new_record'], ARRAY['accept_new']);
    v_resA5 := public.fn_import_promote(v_runA);
    IF EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows WHERE id = v_rb1 AND created_book_draft_id IS NOT NULL)
       AND (v_resB->>'created_drafts')::int = 1
       -- plus aucune ligne accept_new du run A sans brouillon (la ligne restée
       -- en file de T2 comprise) …
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                        WHERE run_id = v_runA AND match_status = 'new_record' AND editorial_decision = 'accept_new'
                          AND created_book_draft_id IS NULL)
       -- … chacune une seule fois …
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft WHERE run_id = v_runA
                        GROUP BY staging_row_id HAVING count(*) > 1)
       -- … et rien de ce qui n'était pas accepté.
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                        WHERE id IN (v_rpend, v_rrej) AND created_book_draft_id IS NOT NULL)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : B='||left(coalesce(v_resB::text, '∅'), 200)||' / A='||left(coalesce(v_resA5::text, '∅'), 300)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T6 ──────────────────────────────────────────────────────────────
  v_t := 'T6 tout le run (NULL, defaut {accept_new}) ne promeut jamais une ligne rattachee (IMP-26 h)';
  BEGIN
    v_res := public.fn_import_promote(v_runA);
    IF EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                WHERE id = v_rdup AND created_book_draft_id IS NULL AND editorial_decision = 'accept_duplicate')
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft WHERE staging_row_id = v_rdup)
       AND NOT EXISTS (SELECT 1 FROM public.book_drafts WHERE titulo = 'H21B Notice rattachee')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(coalesce(v_res::text, '∅'), 300)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T7 ──────────────────────────────────────────────────────────────
  v_t := 'T7 la garde du depot compagnon tient avec une selection (error.import.deposit_admin_only)';
  BEGIN
    v_hint := NULL;
    BEGIN
      PERFORM public.fn_import_promote(v_runD, p_row_ids := ARRAY[v_rd1]);
      v_hint := 'accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    END;
    IF v_hint = 'error.import.deposit_admin_only'
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft WHERE run_id = v_runD)
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows WHERE id = v_rd1 AND created_book_draft_id IS NULL)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint = '||coalesce(v_hint, 'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T8 ──────────────────────────────────────────────────────────────
  v_t := 'T8 une signature par nom, droits reposes (ecran a authenticated, aides a service_role, rien a anon ni PUBLIC), DEFINER';
  BEGIN
    v_txt := '';
    SELECT count(*) FILTER (WHERE p.proname = 'fn_import_promote'),
           count(*) FILTER (WHERE p.proname = 'fn_bulk_create_book_drafts_from_run'),
           count(*) FILTER (WHERE p.proname = 'fn_create_item_drafts_for_batch')
      INTO v_n, v_m, v_k
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname IN ('public', 'ingest', 'api')
       AND p.proname IN ('fn_import_promote', 'fn_bulk_create_book_drafts_from_run', 'fn_create_item_drafts_for_batch');
    IF v_n <> 1 OR v_m <> 1 OR v_k <> 1 THEN
      v_txt := v_txt || format(' signatures promote=%s bulk=%s exemplaires=%s', v_n, v_m, v_k);
    END IF;
    FOR rec IN
      SELECT n.nspname, p.proname, p.oid, pg_get_function_identity_arguments(p.oid) AS args,
             p.prosecdef, coalesce(p.proconfig::text, '') AS cfg, p.proacl
        FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname IN ('public', 'ingest', 'api')
         AND p.proname IN ('fn_import_promote', 'fn_bulk_create_book_drafts_from_run', 'fn_create_item_drafts_for_batch')
    LOOP
      IF rec.proname = 'fn_import_promote' AND (rec.nspname <> 'public'
           OR rec.args NOT LIKE '%p_batch_notes text, p_row_ids bigint[]'
           OR NOT has_function_privilege('authenticated', rec.oid, 'EXECUTE')) THEN
        v_txt := v_txt || ' promote(' || rec.args || ')';
      END IF;
      IF rec.proname = 'fn_bulk_create_book_drafts_from_run' AND (rec.nspname <> 'ingest'
           OR rec.args NOT LIKE '%p_created_by uuid, p_row_ids bigint[]'
           OR has_function_privilege('authenticated', rec.oid, 'EXECUTE')) THEN
        v_txt := v_txt || ' bulk(' || rec.args || ')';
      END IF;
      IF rec.proname = 'fn_create_item_drafts_for_batch' AND (rec.nspname <> 'ingest'
           OR rec.args <> 'p_batch_id bigint, p_created_by uuid, p_staging_row_ids bigint[]'
           OR has_function_privilege('authenticated', rec.oid, 'EXECUTE')) THEN
        v_txt := v_txt || ' exemplaires(' || rec.args || ')';
      END IF;
      IF has_function_privilege('anon', rec.oid, 'EXECUTE')
         OR NOT has_function_privilege('service_role', rec.oid, 'EXECUTE')
         OR rec.proacl IS NULL
         OR EXISTS (SELECT 1 FROM aclexplode(rec.proacl) a WHERE a.grantee = 0) THEN
        v_txt := v_txt || ' droits ' || rec.proname;
      END IF;
      IF NOT rec.prosecdef OR rec.cfg NOT LIKE '%search_path%' THEN
        v_txt := v_txt || ' definer ' || rec.proname;
      END IF;
    END LOOP;
    IF v_txt = '' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' :'||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T9 ──────────────────────────────────────────────────────────────
  v_t := 'T9 (d) les selections successives d''un run vont dans le lot qu''il a ouvert, sous son nom ; un autre run a le sien';
  BEGIN
    IF v_lotA IS NOT NULL
       AND (v_resA2->>'batch_id')::bigint = v_lotA
       AND (v_resA3->>'batch_id')::bigint = v_lotA
       AND (v_resA5->>'batch_id')::bigint = v_lotA
       AND v_resA2->>'batch_name' = 'H21B-LOT-A1'
       AND (SELECT name FROM public.catalog_batches WHERE id = v_lotA) = 'H21B-LOT-A1'
       AND NOT EXISTS (SELECT 1 FROM public.catalog_batches WHERE name = 'H21B-LOT-A2')
       AND (SELECT count(DISTINCT batch_id) FROM ingest.partner_catalog_row_to_draft WHERE run_id = v_runA) = 1
       AND (SELECT count(*) FROM public.book_drafts WHERE batch_id = v_lotA) = 4
       AND (v_resB->>'batch_id')::bigint <> v_lotA
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : lots A '||coalesce(v_lotA::text, '∅')||','||coalesce(v_resA2->>'batch_id', '∅')
         ||','||coalesce(v_resA3->>'batch_id', '∅')||','||coalesce(v_resA5->>'batch_id', '∅')||' nom rendu='||coalesce(v_resA2->>'batch_name', '∅')
         ||' lot B='||coalesce(v_resB->>'batch_id', '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T10 ─────────────────────────────────────────────────────────────
  v_t := 'T10 (d) une revision demandee ferme le lot aux selections suivantes : lot neuf, sous le nom donne';
  BEGIN
    v_res  := public.fn_import_promote(v_runE, p_batch_name := 'H21B-LOT-E1', p_row_ids := ARRAY[v_e1]);
    v_lot1 := (v_res->>'batch_id')::bigint;
    v_res2 := public.fn_import_promote(v_runE, p_batch_name := 'H21B-LOT-E2', p_row_ids := ARRAY[v_e2]);
    v_ok := (v_res2->>'batch_id')::bigint = v_lot1 AND v_res2->>'batch_name' = 'H21B-LOT-E1';
    PERFORM public.fn_batch_review_request(v_lot1, 'H21B : a relire');
    v_res3 := public.fn_import_promote(v_runE, p_batch_name := 'H21B-LOT-E3', p_row_ids := ARRAY[v_e3]);
    v_lot2 := (v_res3->>'batch_id')::bigint;
    IF v_ok
       AND v_lot2 IS NOT NULL AND v_lot2 <> v_lot1
       AND v_res3->>'batch_name' = 'H21B-LOT-E3'
       AND (SELECT library_id FROM public.catalog_batches WHERE id = v_lot2) = v_lib
       AND (SELECT count(*) FROM public.book_drafts WHERE batch_id = v_lot1) = 2
       AND (SELECT count(*) FROM public.book_drafts WHERE batch_id = v_lot2) = 1
       AND public.fn_batch_review_status(v_lot1) = 'requested'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : deux selections un lot='||coalesce(v_ok::text, '∅')
         ||' lot1='||coalesce(v_lot1::text, '∅')||' apres demande='||coalesce(v_lot2::text, '∅')||' ('||coalesce(v_res3->>'batch_name', '∅')||')'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T11 ─────────────────────────────────────────────────────────────
  v_t := 'T11 (d) des retouches demandees : la selection suivante rejoint ce lot, sous son nom';
  BEGIN
    v_res  := public.fn_import_promote(v_runF, p_batch_name := 'H21B-LOT-F1', p_row_ids := ARRAY[v_f1]);
    v_lotF := (v_res->>'batch_id')::bigint;
    v_res2 := public.fn_batch_review_request(v_lotF, NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict((v_res2->>'review_id')::bigint, 'changes_requested', 'H21B : retoucher les titres');
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_res3 := public.fn_import_promote(v_runF, p_batch_name := 'H21B-LOT-F2', p_row_ids := ARRAY[v_f2]);
    IF public.fn_batch_review_status(v_lotF) = 'changes_requested'
       AND (v_res3->>'batch_id')::bigint = v_lotF
       AND v_res3->>'batch_name' = 'H21B-LOT-F1'
       AND (SELECT count(*) FROM public.book_drafts WHERE batch_id = v_lotF) = 2
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : lot F='||coalesce(v_lotF::text, '∅')||' statut='||coalesce(public.fn_batch_review_status(v_lotF), '∅')
         ||' selection suivante='||coalesce(v_res3->>'batch_id', '∅')||' ('||coalesce(v_res3->>'batch_name', '∅')||')'); END IF;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  -- ── T12 ─────────────────────────────────────────────────────────────
  v_t := 'T12 (d) un lot approuve ne reprend pas de selection : lot neuf';
  BEGIN
    IF v_lotF IS NULL THEN RAISE EXCEPTION 'lot du run F absent (T11)'; END IF;
    v_res := public.fn_batch_review_request(v_lotF, 'H21B : retouches faites');
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_res2 := public.fn_import_promote(v_runF, p_batch_name := 'H21B-LOT-F3', p_row_ids := ARRAY[v_f3]);
    v_lot2 := (v_res2->>'batch_id')::bigint;
    IF public.fn_batch_review_status(v_lotF) = 'approved'
       AND v_lot2 IS NOT NULL AND v_lot2 <> v_lotF
       AND v_res2->>'batch_name' = 'H21B-LOT-F3'
       AND NOT EXISTS (SELECT 1 FROM public.book_drafts d JOIN ingest.partner_catalog_staging_rows sr ON sr.created_book_draft_id = d.id
                        WHERE sr.id = v_f3 AND d.batch_id = v_lotF)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : lot approuve='||v_lotF||' selection suivante='||coalesce(v_lot2::text, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  -- ── T13 ─────────────────────────────────────────────────────────────
  v_t := 'T13 (d) un lot ferme ne reprend pas de selection : lot neuf, ouvert';
  BEGIN
    v_res  := public.fn_import_promote(v_runG, p_batch_name := 'H21B-LOT-G1', p_row_ids := ARRAY[v_g1]);
    v_lot1 := (v_res->>'batch_id')::bigint;
    UPDATE public.catalog_batches SET status = 'closed' WHERE id = v_lot1;
    v_res2 := public.fn_import_promote(v_runG, p_batch_name := 'H21B-LOT-G2', p_row_ids := ARRAY[v_g2]);
    v_lotG2 := (v_res2->>'batch_id')::bigint;
    IF v_lot1 IS NOT NULL AND v_lotG2 IS NOT NULL AND v_lotG2 <> v_lot1
       AND v_res2->>'batch_name' = 'H21B-LOT-G2'
       AND (SELECT status FROM public.catalog_batches WHERE id = v_lotG2) = 'open'
       AND (SELECT status FROM public.catalog_batches WHERE id = v_lot1) = 'closed'
       AND (SELECT count(*) FROM public.book_drafts WHERE batch_id = v_lot1) = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : lot ferme='||coalesce(v_lot1::text, '∅')||' selection suivante='||coalesce(v_lotG2::text, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T14 ─────────────────────────────────────────────────────────────
  v_t := 'T14 (d) un lot passe a une autre bibliotheque ne reprend pas de selection : lot neuf, de la bibliotheque du run';
  BEGIN
    IF v_lotG2 IS NULL THEN RAISE EXCEPTION 'lot ouvert du run G absent (T13)'; END IF;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_reassign_library(v_lotG2, v_libB);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_res := public.fn_import_promote(v_runG, p_batch_name := 'H21B-LOT-G3', p_row_ids := ARRAY[v_g3]);
    v_lot3 := (v_res->>'batch_id')::bigint;
    IF (SELECT library_id FROM public.catalog_batches WHERE id = v_lotG2) = v_libB
       AND v_lot3 IS NOT NULL AND v_lot3 <> v_lotG2
       AND v_res->>'batch_name' = 'H21B-LOT-G3'
       AND (SELECT library_id FROM public.catalog_batches WHERE id = v_lot3) = v_lib
       AND EXISTS (SELECT 1 FROM public.book_drafts d JOIN ingest.partner_catalog_staging_rows sr ON sr.created_book_draft_id = d.id
                    WHERE sr.id = v_g3 AND d.batch_id = v_lot3 AND d.owner_library_id = v_lib)
       AND (SELECT count(*) FROM public.book_drafts WHERE batch_id = v_lotG2) = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : lot passe a B='||v_lotG2||' selection suivante='||coalesce(v_lot3::text, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  -- ── T15 ─────────────────────────────────────────────────────────────
  v_t := 'T15 (d) exemplaires : seulement ceux des lignes de la promotion en cours ; un exemplaire supprime entre deux selections ne revient pas';
  BEGIN
    v_res  := public.fn_import_promote(v_runH, p_batch_name := 'H21B-LOT-H1', p_row_ids := ARRAY[v_h1]);
    v_lot1 := (v_res->>'batch_id')::bigint;
    v_ok := (v_res->>'items_created')::int = 1
            AND EXISTS (SELECT 1 FROM public.exemplar_drafts WHERE batch_id = v_lot1 AND source_item_code = 'H21B-EX-H1');
    -- La coordination supprime le brouillon d'exemplaire de H1 (sa notice n'en a plus).
    DELETE FROM public.exemplar_drafts WHERE batch_id = v_lot1 AND source_item_code = 'H21B-EX-H1';
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_res2 := public.fn_import_promote(v_runH, p_batch_name := 'H21B-LOT-H2', p_row_ids := ARRAY[v_h2]);
    IF v_ok AND v_n = 1
       AND (v_res2->>'batch_id')::bigint = v_lot1
       AND (v_res2->>'items_created')::int = 1
       AND (SELECT array_agg(source_item_code ORDER BY source_item_code) FROM public.exemplar_drafts WHERE batch_id = v_lot1) = ARRAY['H21B-EX-H2']
       AND EXISTS (SELECT 1 FROM public.exemplar_drafts x JOIN ingest.partner_catalog_staging_rows sr ON sr.created_book_draft_id = x.book_draft_id
                    WHERE sr.id = v_h2 AND x.source_item_code = 'H21B-EX-H2')
       AND NOT EXISTS (SELECT 1 FROM public.exemplar_drafts x JOIN ingest.partner_catalog_staging_rows sr ON sr.created_book_draft_id = x.book_draft_id
                        WHERE sr.id = v_h1)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : premiere='||coalesce(v_ok::text, '∅')||' supprime='||v_n
         ||' seconde='||left(coalesce(v_res2::text, '∅'), 200)
         ||' exemplaires du lot='||coalesce((SELECT string_agg(source_item_code, ',' ORDER BY source_item_code) FROM public.exemplar_drafts WHERE batch_id = v_lot1), '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T16 ─────────────────────────────────────────────────────────────
  v_t := 'T16 (#12) accept_new sur [I1 deja promue, I2 en attente] : pas de refus ; I2 acceptee, I1 intacte (updated_rows 1, skipped_rows 1)';
  BEGIN
    -- L'autre onglet : il promeut I1 et rapproche I4. Ces gestes restent
    -- acquis même si la décision ci-dessous est refusée (bloc interne).
    v_res := public.fn_import_promote(v_runI, p_batch_name := 'H21B-LOT-I1', p_row_ids := ARRAY[v_i1]);
    SELECT created_book_draft_id INTO v_d1 FROM ingest.partner_catalog_staging_rows WHERE id = v_i1;
    v_res2 := public.fn_import_reconcile_duplicates(v_runI, ARRAY[v_i4]);
    SELECT created_exemplar_draft_id INTO v_x4 FROM ingest.partner_catalog_staging_rows WHERE id = v_i4;
    IF v_d1 IS NULL OR v_x4 IS NULL THEN
      RAISE EXCEPTION 'decor : I1 promue=%, I4 rapprochee=%', coalesce(v_d1::text, '∅'), coalesce(v_x4::text, '∅');
    END IF;
    SELECT to_jsonb(sr) INTO v_snap FROM ingest.partner_catalog_staging_rows sr WHERE sr.id = v_i1;
    -- Cet onglet, chargé avant : « Créer 2 brouillons » sur I1 et I2 ; la
    -- décision d'abord, avec la note que l'écran envoie.
    v_txt := NULL; v_res3 := NULL;
    BEGIN
      v_res3 := public.fn_import_set_editorial(v_runI, ARRAY[v_i1, v_i2], 'accept_new', 'page import: validation individuelle');
    EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM;
    END;
    IF v_txt IS NULL
       AND (v_res3->>'updated_rows')::int = 1
       AND (v_res3->>'skipped_rows')::int = 1
       AND v_res3->>'editorial_decision' = 'accept_new'
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                    WHERE id = v_i2 AND editorial_decision = 'accept_new' AND review_status = 'approved'
                      AND selected_for_draft AND created_book_draft_id IS NULL
                      AND editorial_note = 'page import: validation individuelle')
       AND (SELECT to_jsonb(sr) FROM ingest.partner_catalog_staging_rows sr WHERE sr.id = v_i1) = v_snap
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : refus='||coalesce(v_txt, 'aucun')
         ||' / '||left(coalesce((v_res3 - 'run')::text, '∅'), 300)
         ||' / I2='||coalesce((SELECT editorial_decision||'/'||review_status FROM ingest.partner_catalog_staging_rows WHERE id = v_i2), '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T17 ─────────────────────────────────────────────────────────────
  v_t := 'T17 (#12) puis fn_import_promote(p_row_ids [I1, I2]) : UN brouillon, created_drafts 1 < 2 demandees (promotedPartial) ; I1 garde son seul brouillon';
  BEGIN
    IF v_d1 IS NULL THEN RAISE EXCEPTION 'decor de T16 absent'; END IF;
    v_res := public.fn_import_promote(v_runI, p_row_ids := ARRAY[v_i1, v_i2]);
    -- L'écran : created === ids.length ? draftsCreated : promotedPartial.
    IF coalesce((v_res->>'created_drafts')::int, 0) = 1
       AND coalesce((v_res->>'created_drafts')::int, 0) < cardinality(ARRAY[v_i1, v_i2])
       AND v_res->'selected_row_ids' = to_jsonb(ARRAY[v_i2])
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                    WHERE id = v_i2 AND created_book_draft_id IS NOT NULL AND created_book_draft_id <> v_d1)
       AND (SELECT created_book_draft_id FROM ingest.partner_catalog_staging_rows WHERE id = v_i1) = v_d1
       AND (SELECT count(*) FROM ingest.partner_catalog_row_to_draft WHERE staging_row_id = v_i1) = 1
       AND (SELECT count(*) FROM ingest.partner_catalog_row_to_draft WHERE run_id = v_runI) = 2
       AND (SELECT count(DISTINCT batch_id) FROM ingest.partner_catalog_row_to_draft WHERE run_id = v_runI) = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(coalesce((v_res - 'run')::text, '∅'), 300)
         ||' / I2='||coalesce((SELECT editorial_decision||'/'||coalesce(created_book_draft_id::text, 'sans brouillon')
                                 FROM ingest.partner_catalog_staging_rows WHERE id = v_i2), '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T18 ─────────────────────────────────────────────────────────────
  v_t := 'T18 (#12) une selection faite seulement de lignes converties (promue, rapprochee) : updated_rows 0, sans erreur, rien d''ecrit (accept_new comme reject)';
  BEGIN
    IF v_d1 IS NULL OR v_x4 IS NULL THEN RAISE EXCEPTION 'decor de T16 absent'; END IF;
    SELECT jsonb_object_agg(sr.id, to_jsonb(sr)) INTO v_snap
      FROM ingest.partner_catalog_staging_rows sr WHERE sr.id IN (v_i1, v_i4);
    v_txt := NULL; v_res := NULL; v_res2 := NULL;
    BEGIN
      v_res  := public.fn_import_set_editorial(v_runI, ARRAY[v_i1, v_i4], 'accept_new', 'H21B deja converties');
      v_res2 := public.fn_import_set_editorial(v_runI, ARRAY[v_i1, v_i4], 'reject', 'H21B deja converties');
    EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM;
    END;
    IF v_txt IS NULL
       AND (v_res->>'updated_rows')::int = 0 AND (v_res->>'skipped_rows')::int = 2
       AND (v_res2->>'updated_rows')::int = 0 AND (v_res2->>'skipped_rows')::int = 2
       AND (SELECT jsonb_object_agg(sr.id, to_jsonb(sr)) FROM ingest.partner_catalog_staging_rows sr
             WHERE sr.id IN (v_i1, v_i4)) = v_snap
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : refus='||coalesce(v_txt, 'aucun')
         ||' / accept_new='||left(coalesce((v_res - 'run')::text, '∅'), 200)
         ||' / reject='||left(coalesce((v_res2 - 'run')::text, '∅'), 200)
         ||' / I4='||coalesce((SELECT editorial_decision FROM ingest.partner_catalog_staging_rows WHERE id = v_i4), '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T19 ─────────────────────────────────────────────────────────────
  v_t := 'T19 (#12) reject sur [promue, rapprochee, en attente] : pas de refus ; la ligne en attente rejetee, les converties intactes (brouillon, lien, exemplaire)';
  BEGIN
    IF v_d1 IS NULL OR v_x4 IS NULL THEN RAISE EXCEPTION 'decor de T16 absent'; END IF;
    SELECT jsonb_object_agg(sr.id, to_jsonb(sr)) INTO v_snap
      FROM ingest.partner_catalog_staging_rows sr WHERE sr.id IN (v_i1, v_i4);
    v_txt := NULL; v_res := NULL;
    BEGIN
      v_res := public.fn_import_set_editorial(v_runI, ARRAY[v_i1, v_i4, v_i3], 'reject', 'page import: écarté (doublon / non pertinent)');
    EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM;
    END;
    IF v_txt IS NULL
       AND (v_res->>'updated_rows')::int = 1
       AND (v_res->>'skipped_rows')::int = 2
       -- L'écran lit updated_rows (rejectedPartial dès que updated_rows <
       -- ids.length, cinquième passe) ; ici, demandées − ignorées = rejetées.
       AND cardinality(ARRAY[v_i1, v_i4, v_i3]) - (v_res->>'skipped_rows')::int = (v_res->>'updated_rows')::int
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                    WHERE id = v_i3 AND editorial_decision = 'reject' AND review_status = 'rejected'
                      AND NOT selected_for_draft AND created_book_draft_id IS NULL)
       AND (SELECT jsonb_object_agg(sr.id, to_jsonb(sr)) FROM ingest.partner_catalog_staging_rows sr
             WHERE sr.id IN (v_i1, v_i4)) = v_snap
       AND EXISTS (SELECT 1 FROM public.book_drafts WHERE id = v_d1 AND status <> 'cancelled')
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft WHERE staging_row_id = v_i1 AND draft_id = v_d1)
       AND EXISTS (SELECT 1 FROM public.exemplar_drafts WHERE id = v_x4 AND import_staging_row_id = v_i4 AND status <> 'cancelled')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : refus='||coalesce(v_txt, 'aucun')
         ||' / '||left(coalesce((v_res - 'run')::text, '∅'), 250)
         ||' / I1,I3,I4='||coalesce((SELECT string_agg(editorial_decision, ',' ORDER BY row_no) FROM ingest.partner_catalog_staging_rows
                                      WHERE id IN (v_i1, v_i3, v_i4)), '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T20 ─────────────────────────────────────────────────────────────
  v_t := 'T20 (5e passe) decision : liste vide ou NULL refusee comme avant (Aucune ligne fournie) ; ids d''un autre run (promue, en attente, inexistant, NULL, doublon) : comptes ignores sans refus {updated_rows 0, skipped_rows 3}, rien d''ecrit, comme des ids inexistants (pas d''oracle)';
  BEGIN
    SELECT jsonb_object_agg(sr.id, to_jsonb(sr)) INTO v_snap
      FROM ingest.partner_catalog_staging_rows sr WHERE sr.run_id IN (v_runA, v_runI);
    v_txt := NULL; v_err := NULL; v_msg := NULL; v_res := NULL; v_res2 := NULL; v_res3 := NULL;
    EXECUTE 'SET LOCAL ROLE authenticated';
    -- Non-régression : une liste vide ou NULL va jusqu'au refus de l'ingest.
    BEGIN
      PERFORM public.fn_import_set_editorial(v_runI, '{}'::bigint[], 'accept_new', NULL);
      v_txt := 'accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_txt = MESSAGE_TEXT;
    END;
    BEGIN
      PERFORM public.fn_import_set_editorial(v_runI, NULL, 'reject', NULL);
      v_err := 'accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    END;
    -- Cinquième passe : des ids absents du run I — deux lignes d'un autre run
    -- de la même bibliothèque (l'une promue par T1, l'autre en attente), un id
    -- inexistant, NULL et un doublon — sont ignorés et comptés une fois chacun
    -- (3), comme trois ids qui n'existent nulle part : le compte ne dit pas ce
    -- qui existe ailleurs. Avant : {updated_rows 0, skipped_rows 0}, le
    -- « Lignes écartées » que l'écran affichait en succès (constat S2).
    BEGIN
      v_res  := public.fn_import_set_editorial(v_runI, ARRAY[v_r1, v_rpend, -1, NULL, v_r1], 'reject', 'H21B autre run');
      v_res2 := public.fn_import_set_editorial(v_runI, ARRAY[-1, -2, -3], 'reject', 'H21B autre run');
      v_res3 := public.fn_import_set_editorial(v_runI, ARRAY[v_r1, v_rpend], 'accept_new', 'H21B autre run');
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT;
    END;
    EXECUTE 'RESET ROLE';
    IF v_txt = 'Aucune ligne fournie' AND v_err = 'Aucune ligne fournie'
       AND v_msg IS NULL
       AND (v_res->>'updated_rows')::int = 0
       AND (v_res->>'skipped_rows')::int = 3
       AND v_res->>'editorial_decision' = 'reject'
       -- l'écran : rejectedPartial {rejected 0, asked 3}, kind 'error'
       AND v_res2 = v_res
       AND (v_res3->>'updated_rows')::int = 0
       AND (v_res3->>'skipped_rows')::int = 2
       AND v_res3->>'editorial_decision' = 'accept_new'
       AND (SELECT jsonb_object_agg(sr.id, to_jsonb(sr)) FROM ingest.partner_catalog_staging_rows sr
             WHERE sr.run_id IN (v_runA, v_runI)) = v_snap
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : vide='||coalesce(v_txt, '∅')||' / NULL='||coalesce(v_err, '∅')
         ||' / refus='||coalesce(v_msg, 'aucun')
         ||' / autre run='||left(coalesce((v_res - 'run')::text, '∅'), 150)
         ||' / inexistants='||left(coalesce((v_res2 - 'run')::text, '∅'), 150)
         ||' / accept_new='||left(coalesce((v_res3 - 'run')::text, '∅'), 150)); END IF;
  EXCEPTION WHEN OTHERS THEN
    EXECUTE 'RESET ROLE';
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  -- ── T21 ─────────────────────────────────────────────────────────────
  v_t := 'T21 (#12) accept_new sur [I5 rejetee ailleurs, I6 en attente] : I5 reste rejetee (skipped_rows 1), I6 acceptee ; la promotion [I5, I6] cree UN brouillon (created_drafts 1 < 2 : promotedPartial dit vrai)';
  BEGIN
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
    VALUES (v_runI, 5, 'H21B-I5', 'H21B Notice I5 rejetee ailleurs', 'new_record', 'pending', 'pending') RETURNING id INTO v_i5;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
    VALUES (v_runI, 6, 'H21B-I6', 'H21B Notice I6', 'new_record', 'pending', 'pending') RETURNING id INTO v_i6;
    -- L'autre onglet : « Rejeter » sur I5, avec la note de l'écran.
    v_res := public.fn_import_set_editorial(v_runI, ARRAY[v_i5], 'reject', 'page import: écarté (doublon / non pertinent)');
    IF NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                    WHERE id = v_i5 AND editorial_decision = 'reject' AND review_status = 'rejected') THEN
      RAISE EXCEPTION 'decor : I5 non rejetee (%)', left(coalesce((v_res - 'run')::text, '∅'), 200);
    END IF;
    SELECT to_jsonb(sr) INTO v_snap FROM ingest.partner_catalog_staging_rows sr WHERE sr.id = v_i5;
    -- Cet onglet, chargé avant le rejet (I5 et I6 en attente) : « Créer 2
    -- brouillons » — la décision, puis la promotion de la même sélection.
    v_txt := NULL; v_res2 := NULL; v_res3 := NULL;
    BEGIN
      v_res2 := public.fn_import_set_editorial(v_runI, ARRAY[v_i5, v_i6], 'accept_new', 'page import: validation individuelle');
      v_res3 := public.fn_import_promote(v_runI, p_row_ids := ARRAY[v_i5, v_i6]);
    EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM;
    END;
    -- L'écran : created === ids.length ? draftsCreated : promotedPartial.
    IF v_txt IS NULL
       AND (v_res2->>'updated_rows')::int = 1
       AND (v_res2->>'skipped_rows')::int = 1
       AND v_res2->>'editorial_decision' = 'accept_new'
       AND coalesce((v_res3->>'created_drafts')::int, 0) = 1
       AND coalesce((v_res3->>'created_drafts')::int, 0) < cardinality(ARRAY[v_i5, v_i6])
       AND v_res3->'selected_row_ids' = to_jsonb(ARRAY[v_i6])
       -- I5 : la ligne entière telle que l'autre onglet l'a laissée
       AND (SELECT to_jsonb(sr) FROM ingest.partner_catalog_staging_rows sr WHERE sr.id = v_i5) = v_snap
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft WHERE staging_row_id = v_i5)
       AND NOT EXISTS (SELECT 1 FROM public.book_drafts WHERE titulo = 'H21B Notice I5 rejetee ailleurs')
       -- I6 : acceptée et promue, dans le lot du run (IMP-27 d)
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                    WHERE id = v_i6 AND editorial_decision = 'accept_new' AND created_book_draft_id IS NOT NULL
                      AND editorial_note = 'page import: validation individuelle')
       AND (SELECT count(DISTINCT batch_id) FROM ingest.partner_catalog_row_to_draft WHERE run_id = v_runI) = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : refus='||coalesce(v_txt, 'aucun')
         ||' / decision='||left(coalesce((v_res2 - 'run')::text, '∅'), 200)
         ||' / promotion='||left(coalesce((v_res3 - 'run')::text, '∅'), 200)
         ||' / I5,I6='||coalesce((SELECT string_agg(editorial_decision||':'||coalesce(created_book_draft_id::text, 'sans brouillon'), ',' ORDER BY row_no)
                                    FROM ingest.partner_catalog_staging_rows WHERE id IN (v_i5, v_i6)), '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T22 ─────────────────────────────────────────────────────────────
  v_t := 'T22 (#12, IMP-27 e) accept_new sur [I7 ecartee par la suppression de son brouillon, I8 en attente] : I7 reste ecartee (discarded_draft_id garde), aucun second brouillon ; I8 seule promue';
  BEGIN
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
    VALUES (v_runI, 7, 'H21B-I7', 'H21B Notice I7 ecartee', 'new_record', 'pending', 'pending') RETURNING id INTO v_i7;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
    VALUES (v_runI, 8, 'H21B-I8', 'H21B Notice I8', 'new_record', 'pending', 'pending') RETURNING id INTO v_i8;
    -- L'autre onglet : « Créer 1 brouillon » sur I7, puis le brouillon à la
    -- corbeille et « Vider la corbeille » (par l'API) : la ligne est écartée.
    PERFORM public.fn_import_set_editorial(v_runI, ARRAY[v_i7], 'accept_new', 'page import: validation individuelle');
    PERFORM public.fn_import_promote(v_runI, p_row_ids := ARRAY[v_i7]);
    SELECT created_book_draft_id INTO v_d7 FROM ingest.partner_catalog_staging_rows WHERE id = v_i7;
    IF v_d7 IS NULL THEN RAISE EXCEPTION 'decor : I7 non promue'; END IF;
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET status = 'cancelled' WHERE id = v_d7;
    DELETE FROM public.book_drafts WHERE id = v_d7;
    EXECUTE 'RESET ROLE';
    IF NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                    WHERE id = v_i7 AND editorial_decision = 'reject' AND created_book_draft_id IS NULL
                      AND discarded_draft_id = v_d7) THEN
      RAISE EXCEPTION 'decor : I7 non ecartee (%)',
        (SELECT row(editorial_decision, created_book_draft_id, discarded_draft_id)::text FROM ingest.partner_catalog_staging_rows WHERE id = v_i7);
    END IF;
    SELECT to_jsonb(sr) INTO v_snap FROM ingest.partner_catalog_staging_rows sr WHERE sr.id = v_i7;
    -- Cet onglet, chargé avant tout cela (I7 et I8 en attente) : « Créer 2
    -- brouillons ».
    v_txt := NULL; v_res2 := NULL; v_res3 := NULL;
    BEGIN
      v_res2 := public.fn_import_set_editorial(v_runI, ARRAY[v_i7, v_i8], 'accept_new', 'page import: validation individuelle');
      v_res3 := public.fn_import_promote(v_runI, p_row_ids := ARRAY[v_i7, v_i8]);
    EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM;
    END;
    IF v_txt IS NULL
       AND (v_res2->>'updated_rows')::int = 1
       AND (v_res2->>'skipped_rows')::int = 1
       AND coalesce((v_res3->>'created_drafts')::int, 0) = 1
       AND coalesce((v_res3->>'created_drafts')::int, 0) < cardinality(ARRAY[v_i7, v_i8])
       AND v_res3->'selected_row_ids' = to_jsonb(ARRAY[v_i8])
       -- I7 : écartée telle quelle, sa preuve d'écartement comprise ; aucun
       -- brouillon ne porte sa trace, aucun lien
       AND (SELECT to_jsonb(sr) FROM ingest.partner_catalog_staging_rows sr WHERE sr.id = v_i7) = v_snap
       AND NOT EXISTS (SELECT 1 FROM public.book_drafts d WHERE d.marc_json->'ingest'->>'staging_row_id' = v_i7::text)
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft WHERE staging_row_id = v_i7)
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                    WHERE id = v_i8 AND editorial_decision = 'accept_new' AND created_book_draft_id IS NOT NULL)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : refus='||coalesce(v_txt, 'aucun')
         ||' / decision='||left(coalesce((v_res2 - 'run')::text, '∅'), 200)
         ||' / promotion='||left(coalesce((v_res3 - 'run')::text, '∅'), 200)
         ||' / I7='||coalesce((SELECT row(editorial_decision, created_book_draft_id, discarded_draft_id)::text
                                 FROM ingest.partner_catalog_staging_rows WHERE id = v_i7), '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN
    EXECUTE 'RESET ROLE';
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  -- ── T23 ─────────────────────────────────────────────────────────────
  v_t := 'T23 (#12) decision inconnue sur une selection entierement convertie [I1, I4] : refus de l''ingest (editorial_decision invalide), rien d''ecrit ; '' Pending '' garde le retour anticipe';
  BEGIN
    IF v_d1 IS NULL OR v_x4 IS NULL THEN RAISE EXCEPTION 'decor de T16 absent'; END IF;
    SELECT jsonb_object_agg(sr.id, to_jsonb(sr)) INTO v_snap
      FROM ingest.partner_catalog_staging_rows sr WHERE sr.id IN (v_i1, v_i4);
    v_txt := NULL; v_res := NULL;
    BEGIN
      v_res := public.fn_import_set_editorial(v_runI, ARRAY[v_i1, v_i4], 'nimporte', 'H21B decision inconnue');
      v_txt := 'accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_txt = MESSAGE_TEXT;
    END;
    -- Témoin : une décision VALIDE, écrite autrement (casse, espaces), passe
    -- toujours par le retour anticipé (l'ingest refuserait I1, convertie).
    v_err := NULL; v_res2 := NULL;
    BEGIN
      v_res2 := public.fn_import_set_editorial(v_runI, ARRAY[v_i1, v_i4], ' Pending ', 'H21B deja converties');
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    END;
    IF v_txt = 'editorial_decision invalide : nimporte'
       AND v_res IS NULL
       AND v_err IS NULL
       AND (v_res2->>'updated_rows')::int = 0
       AND (v_res2->>'skipped_rows')::int = 2
       AND v_res2->>'editorial_decision' = 'pending'
       AND (SELECT jsonb_object_agg(sr.id, to_jsonb(sr)) FROM ingest.partner_catalog_staging_rows sr
             WHERE sr.id IN (v_i1, v_i4)) = v_snap
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : inconnue='||coalesce(v_txt, '∅')
         ||' ('||left(coalesce((v_res - 'run')::text, '∅'), 150)||')'
         ||' / Pending='||coalesce(v_err, left(coalesce((v_res2 - 'run')::text, '∅'), 150))); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T24 ─────────────────────────────────────────────────────────────
  v_t := 'T24 (4e passe) Rapprocher sur [P promue, R rapprochee, J rejetee, E ecartee ailleurs, W en attente] : pas de refus, skipped_rows 4 ; W rapprochee (un exemplaire), les quatre autres intactes';
  BEGIN
    -- L'autre onglet : « Créer 2 brouillons » sur P et E, « Rapprocher » R,
    -- « Rejeter » J, puis le brouillon d'E à la corbeille et « Vider la
    -- corbeille » (par l'API) : E est écartée (IMP-27 e).
    PERFORM public.fn_import_set_editorial(v_runK, ARRAY[v_kp, v_ke], 'accept_new', 'page import: validation individuelle');
    PERFORM public.fn_import_promote(v_runK, p_batch_name := 'H21B-LOT-K1', p_row_ids := ARRAY[v_kp, v_ke]);
    SELECT created_book_draft_id INTO v_kdp FROM ingest.partner_catalog_staging_rows WHERE id = v_kp;
    SELECT created_book_draft_id INTO v_kde FROM ingest.partner_catalog_staging_rows WHERE id = v_ke;
    PERFORM public.fn_import_reconcile_duplicates(v_runK, ARRAY[v_kr]);
    SELECT created_exemplar_draft_id INTO v_kxr FROM ingest.partner_catalog_staging_rows WHERE id = v_kr;
    PERFORM public.fn_import_set_editorial(v_runK, ARRAY[v_kj], 'reject', 'page import: écarté (doublon / non pertinent)');
    IF v_kdp IS NULL OR v_kde IS NULL OR v_kxr IS NULL THEN
      RAISE EXCEPTION 'decor : P promue=%, E promue=%, R rapprochee=%',
        coalesce(v_kdp::text, '∅'), coalesce(v_kde::text, '∅'), coalesce(v_kxr::text, '∅');
    END IF;
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET status = 'cancelled' WHERE id = v_kde;
    DELETE FROM public.book_drafts WHERE id = v_kde;
    EXECUTE 'RESET ROLE';
    IF NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                    WHERE id = v_ke AND editorial_decision = 'reject' AND created_book_draft_id IS NULL
                      AND discarded_draft_id = v_kde)
       OR NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                       WHERE id = v_kj AND editorial_decision = 'reject' AND review_status = 'rejected') THEN
      RAISE EXCEPTION 'decor : E non ecartee ou J non rejetee (%)',
        (SELECT string_agg(row(id, editorial_decision, created_book_draft_id, discarded_draft_id)::text, ',')
           FROM ingest.partner_catalog_staging_rows WHERE id IN (v_ke, v_kj));
    END IF;
    SELECT jsonb_object_agg(sr.id, to_jsonb(sr)) INTO v_snap
      FROM ingest.partner_catalog_staging_rows sr WHERE sr.id IN (v_kp, v_kr, v_kj, v_ke);
    -- « Rapprocher » sur les cinq, par l'API (l'écran, chargé avant tout cela,
    -- n'enverrait que les doublons R, J et W ; P et E n'y viennent que par
    -- l'API).
    v_txt := NULL; v_res := NULL;
    BEGIN
      v_res := public.fn_import_reconcile_duplicates(v_runK, ARRAY[v_kp, v_kr, v_kj, v_ke, v_kw]);
    EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM;
    END;
    IF v_txt IS NULL
       AND (v_res->>'skipped_rows')::int = 4
       -- ignorées < envoyées : l'écran dirait reconciledPartial, kind 'info'.
       AND (v_res->>'skipped_rows')::int < cardinality(ARRAY[v_kp, v_kr, v_kj, v_ke, v_kw])
       AND (v_res->>'requested_rows')::int = 1
       AND (v_res->>'created_exemplar_drafts')::int = 1
       AND (v_res->>'created_items')::int = 1
       -- W : rapprochée, son exemplaire dans le lot rendu, sur la notice proposée
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                    WHERE id = v_kw AND editorial_decision = 'accept_duplicate' AND review_status = 'draft_created'
                      AND created_exemplar_draft_id IS NOT NULL AND created_book_draft_id IS NULL)
       AND (SELECT array_agg(x.source_item_code) FROM public.exemplar_drafts x WHERE x.import_staging_row_id = v_kw) = ARRAY['H21B-EX-K5']
       AND EXISTS (SELECT 1 FROM public.exemplar_drafts x
                    WHERE x.import_staging_row_id = v_kw AND x.batch_id = (v_res->>'batch_id')::bigint
                      AND x.target_bib_ref = 'H21B-RATT-I4')
       -- P, R, J, E : les lignes entières telles que l'autre onglet les a
       -- laissées ; aucun exemplaire de plus (R garde le sien, seul)
       AND (SELECT jsonb_object_agg(sr.id, to_jsonb(sr)) FROM ingest.partner_catalog_staging_rows sr
             WHERE sr.id IN (v_kp, v_kr, v_kj, v_ke)) = v_snap
       AND NOT EXISTS (SELECT 1 FROM public.exemplar_drafts WHERE import_staging_row_id IN (v_kp, v_kj, v_ke))
       AND (SELECT array_agg(id) FROM public.exemplar_drafts WHERE import_staging_row_id = v_kr) = ARRAY[v_kxr]
       AND EXISTS (SELECT 1 FROM public.book_drafts WHERE id = v_kdp AND status <> 'cancelled')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : refus='||coalesce(v_txt, 'aucun')
         ||' / '||left(coalesce((v_res - 'run')::text, '∅'), 300)
         ||' / P,R,J,E,W='||coalesce((SELECT string_agg(editorial_decision||':'||review_status, ',' ORDER BY row_no)
                                        FROM ingest.partner_catalog_staging_rows WHERE id IN (v_kp, v_kr, v_kj, v_ke, v_kw)), '∅')
         ||' / exemplaires='||coalesce((SELECT string_agg(source_item_code, ',' ORDER BY source_item_code) FROM public.exemplar_drafts
                                         WHERE import_staging_row_id IN (v_kp, v_kr, v_kj, v_ke, v_kw)), '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN
    EXECUTE 'RESET ROLE';
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  -- ── T25 ─────────────────────────────────────────────────────────────
  v_t := 'T25 (4e passe) Rapprocher une selection faite seulement de lignes ignorees [P, R, J, E, W deja rapprochee] : {created_items 0, skipped_rows 5} sans erreur, rien d''ecrit (ni lot, ni exemplaire, ni ligne)';
  BEGIN
    IF v_kde IS NULL OR v_kxr IS NULL THEN RAISE EXCEPTION 'decor de T24 absent'; END IF;
    SELECT jsonb_object_agg(sr.id, to_jsonb(sr)) INTO v_snap
      FROM ingest.partner_catalog_staging_rows sr WHERE sr.run_id = v_runK;
    SELECT count(*) INTO v_nb FROM public.catalog_batches;
    SELECT count(*) INTO v_nx FROM public.exemplar_drafts;
    -- De nouveau les cinq, sans recharger (W rapprochée entre-temps).
    v_txt := NULL; v_res := NULL;
    BEGIN
      v_res := public.fn_import_reconcile_duplicates(v_runK, ARRAY[v_kp, v_kr, v_kj, v_ke, v_kw]);
    EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM;
    END;
    IF v_txt IS NULL
       AND (v_res->>'created_items')::int = 0
       AND (v_res->>'skipped_rows')::int = 5
       -- ignorées = envoyées : l'écran dirait reconciledPartial, kind 'error'.
       AND (v_res->>'skipped_rows')::int = cardinality(ARRAY[v_kp, v_kr, v_kj, v_ke, v_kw])
       AND v_res->>'batch_id' IS NULL
       AND (SELECT count(*) FROM public.catalog_batches) = v_nb
       AND (SELECT count(*) FROM public.exemplar_drafts) = v_nx
       AND (SELECT jsonb_object_agg(sr.id, to_jsonb(sr)) FROM ingest.partner_catalog_staging_rows sr
             WHERE sr.run_id = v_runK) = v_snap
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : refus='||coalesce(v_txt, 'aucun')
         ||' / '||left(coalesce((v_res - 'run')::text, '∅'), 300)
         ||' / lots '||v_nb||' -> '||(SELECT count(*) FROM public.catalog_batches)
         ||' / exemplaires '||v_nx||' -> '||(SELECT count(*) FROM public.exemplar_drafts)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T26 ─────────────────────────────────────────────────────────────
  v_t := 'T26 (4e et 5e passes) Rapprocher : [W2, W3] rapprochables comme avant (skipped_rows 0, memes cles, deux exemplaires) ; liste vide ou NULL : Aucune ligne fournie, comme avant ; ids d''un autre run (promue, rejetee, en attente, inexistant, NULL, doublon) : comptes ignores sans refus {created_items 0, skipped_rows 4}, rien d''ecrit, comme des ids inexistants (pas d''oracle)';
  BEGIN
    SELECT jsonb_object_agg(sr.id, to_jsonb(sr)) INTO v_snap
      FROM ingest.partner_catalog_staging_rows sr WHERE sr.run_id = v_runA;
    v_txt := NULL; v_err := NULL; v_hint := NULL; v_msg := NULL; v_res := NULL; v_res2 := NULL; v_res3 := NULL;
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
      v_res := public.fn_import_reconcile_duplicates(v_runK, ARRAY[v_kw2, v_kw3]);
    EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM;
    END;
    -- Non-régression : une liste vide ou NULL va jusqu'au refus de l'ingest.
    BEGIN
      PERFORM public.fn_import_reconcile_duplicates(v_runK, '{}'::bigint[]);
      v_err := 'accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    END;
    BEGIN
      PERFORM public.fn_import_reconcile_duplicates(v_runK, NULL);
      v_hint := 'accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = MESSAGE_TEXT;
    END;
    EXECUTE 'RESET ROLE';
    SELECT count(*) INTO v_nb FROM public.catalog_batches;
    SELECT count(*) INTO v_nx FROM public.exemplar_drafts;
    -- Cinquième passe : des ids absents du run K — trois lignes d'un autre run
    -- de la même bibliothèque (promue par T1, rejetée, en attente), un id
    -- inexistant, NULL et un doublon — sont ignorés et comptés une fois chacun
    -- (4), comme quatre ids qui n'existent nulle part (pas d'oracle). Avant :
    -- le refus en bloc sans HINT « Aucune ligne eligible au rapprochement pour
    -- le run K », affiché brut (constat S1).
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
      v_res2 := public.fn_import_reconcile_duplicates(v_runK, ARRAY[v_r1, v_rrej, v_rpend, -1, NULL, v_r1]);
      v_res3 := public.fn_import_reconcile_duplicates(v_runK, ARRAY[-1, -2, -3, -4]);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT;
    END;
    EXECUTE 'RESET ROLE';
    IF v_txt IS NULL
       AND coalesce((v_res->>'skipped_rows')::int, 0) = 0
       AND (v_res->>'requested_rows')::int = 2
       AND (v_res->>'created_exemplar_drafts')::int = 2
       AND (v_res->>'created_items')::int = 2
       AND v_res->>'batch_id' IS NOT NULL
       -- les clés d'avant, rien de moins
       AND (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(v_res - 'skipped_rows') AS k)
           = ARRAY['batch_id', 'batch_name', 'created_exemplar_drafts', 'created_items', 'items_skipped_code_taken',
                   'requested_rows', 'rows_already_held', 'run', 'run_id']
       AND (SELECT count(*) FROM ingest.partner_catalog_staging_rows
             WHERE id IN (v_kw2, v_kw3) AND editorial_decision = 'accept_duplicate' AND review_status = 'draft_created'
               AND created_exemplar_draft_id IS NOT NULL) = 2
       AND (SELECT array_agg(x.source_item_code ORDER BY x.source_item_code) FROM public.exemplar_drafts x
             WHERE x.import_staging_row_id IN (v_kw2, v_kw3)) = ARRAY['H21B-EX-K6', 'H21B-EX-K7']
       AND v_err = 'Aucune ligne fournie'
       AND v_hint = 'Aucune ligne fournie'
       AND v_msg IS NULL
       AND (v_res2->>'created_items')::int = 0
       AND (v_res2->>'skipped_rows')::int = 4
       AND v_res2->>'batch_id' IS NULL
       -- ignorées = envoyées : l'écran dirait reconciledPartial, kind 'error'
       AND v_res3 = v_res2
       AND (SELECT count(*) FROM public.catalog_batches) = v_nb
       AND (SELECT count(*) FROM public.exemplar_drafts) = v_nx
       AND (SELECT jsonb_object_agg(sr.id, to_jsonb(sr)) FROM ingest.partner_catalog_staging_rows sr
             WHERE sr.run_id = v_runA) = v_snap
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : W2,W3 refus='||coalesce(v_txt, 'aucun')
         ||' ('||left(coalesce((v_res - 'run')::text, '∅'), 250)||')'
         ||' / vide='||coalesce(v_err, '∅')||' / NULL='||coalesce(v_hint, '∅')
         ||' / autre run refus='||coalesce(v_msg, 'aucun')||' ('||left(coalesce((v_res2 - 'run')::text, '∅'), 150)||')'
         ||' / inexistants='||left(coalesce((v_res3 - 'run')::text, '∅'), 150)
         ||' / lots '||v_nb||' -> '||(SELECT count(*) FROM public.catalog_batches)
         ||' / exemplaires '||v_nx||' -> '||(SELECT count(*) FROM public.exemplar_drafts)); END IF;
  EXCEPTION WHEN OTHERS THEN
    EXECUTE 'RESET ROLE';
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  -- ── T27 ─────────────────────────────────────────────────────────────
  v_t := 'T27 (4e passe) une ligne ecartee n''accepte aucune decision : pending, accept_new et reject sur [E] seule ignores (updated_rows 0, skipped_rows 1), E intacte, sa preuve d''ecartement gardee';
  BEGIN
    IF v_kde IS NULL THEN RAISE EXCEPTION 'decor de T24 absent'; END IF;
    SELECT to_jsonb(sr) INTO v_snap FROM ingest.partner_catalog_staging_rows sr WHERE sr.id = v_ke;
    v_txt := NULL; v_res := NULL; v_res2 := NULL; v_res3 := NULL;
    BEGIN
      -- 'pending' : aucun écran ne l'envoie ; l'API, si.
      v_res  := public.fn_import_set_editorial(v_runK, ARRAY[v_ke], 'pending', 'H21B remise en attente par l''API');
      v_res2 := public.fn_import_set_editorial(v_runK, ARRAY[v_ke], 'accept_new', 'page import: validation individuelle');
      v_res3 := public.fn_import_set_editorial(v_runK, ARRAY[v_ke], 'reject', 'page import: écarté (doublon / non pertinent)');
    EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM;
    END;
    IF v_txt IS NULL
       AND (v_res->>'updated_rows')::int = 0  AND (v_res->>'skipped_rows')::int = 1  AND v_res->>'editorial_decision' = 'pending'
       AND (v_res2->>'updated_rows')::int = 0 AND (v_res2->>'skipped_rows')::int = 1 AND v_res2->>'editorial_decision' = 'accept_new'
       AND (v_res3->>'updated_rows')::int = 0 AND (v_res3->>'skipped_rows')::int = 1 AND v_res3->>'editorial_decision' = 'reject'
       -- E : la ligne entière, sa note d'écartement et discarded_draft_id
       -- (la preuve que lit la reprise au rejeu) compris
       AND (SELECT to_jsonb(sr) FROM ingest.partner_catalog_staging_rows sr WHERE sr.id = v_ke) = v_snap
       AND (SELECT discarded_draft_id FROM ingest.partner_catalog_staging_rows WHERE id = v_ke) = v_kde
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : refus='||coalesce(v_txt, 'aucun')
         ||' / pending='||left(coalesce((v_res - 'run')::text, '∅'), 150)
         ||' / accept_new='||left(coalesce((v_res2 - 'run')::text, '∅'), 150)
         ||' / reject='||left(coalesce((v_res3 - 'run')::text, '∅'), 150)
         ||' / E='||coalesce((SELECT row(editorial_decision, review_status, created_book_draft_id, discarded_draft_id)::text
                                FROM ingest.partner_catalog_staging_rows WHERE id = v_ke), '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T28 ─────────────────────────────────────────────────────────────
  v_t := 'T28 (4e passe) [E ecartee, Q] : reject, pending puis accept_new ne touchent que Q (updated_rows 1, skipped_rows 1) ; la promotion [E, Q] ne cree que le brouillon de Q, jamais un second pour E';
  BEGIN
    IF v_kde IS NULL THEN RAISE EXCEPTION 'decor de T24 absent'; END IF;
    SELECT to_jsonb(sr) INTO v_snap FROM ingest.partner_catalog_staging_rows sr WHERE sr.id = v_ke;
    v_txt := NULL; v_ok := NULL; v_res := NULL; v_res2 := NULL; v_res3 := NULL; v_res4 := NULL;
    BEGIN
      v_res := public.fn_import_set_editorial(v_runK, ARRAY[v_ke, v_kq], 'reject', 'page import: écarté (doublon / non pertinent)');
      v_ok := EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                       WHERE id = v_kq AND editorial_decision = 'reject' AND review_status = 'rejected');
      -- « En attente » puis « Créer 2 brouillons » : avant cette passe, E
      -- remise en attente redevenait promouvable — un second brouillon pour
      -- une ligne dont le premier a été purgé.
      v_res2 := public.fn_import_set_editorial(v_runK, ARRAY[v_ke, v_kq], 'pending', 'H21B remise en attente par l''API');
      v_ok := v_ok AND EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                                WHERE id = v_kq AND editorial_decision = 'pending' AND review_status = 'pending');
      v_res3 := public.fn_import_set_editorial(v_runK, ARRAY[v_ke, v_kq], 'accept_new', 'page import: validation individuelle');
      v_res4 := public.fn_import_promote(v_runK, p_row_ids := ARRAY[v_ke, v_kq]);
    EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM;
    END;
    IF v_txt IS NULL AND v_ok
       AND (v_res->>'updated_rows')::int = 1  AND (v_res->>'skipped_rows')::int = 1
       AND (v_res2->>'updated_rows')::int = 1 AND (v_res2->>'skipped_rows')::int = 1
       AND (v_res3->>'updated_rows')::int = 1 AND (v_res3->>'skipped_rows')::int = 1
       -- L'écran : promotedPartial (1 < 2).
       AND coalesce((v_res4->>'created_drafts')::int, 0) = 1
       AND v_res4->'selected_row_ids' = to_jsonb(ARRAY[v_kq])
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                    WHERE id = v_kq AND editorial_decision = 'accept_new' AND created_book_draft_id IS NOT NULL)
       -- E : telle quelle, sans brouillon ni lien
       AND (SELECT to_jsonb(sr) FROM ingest.partner_catalog_staging_rows sr WHERE sr.id = v_ke) = v_snap
       AND NOT EXISTS (SELECT 1 FROM public.book_drafts d WHERE d.marc_json->'ingest'->>'staging_row_id' = v_ke::text)
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft WHERE staging_row_id = v_ke)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : refus='||coalesce(v_txt, 'aucun')||' Q suivie='||coalesce(v_ok::text, '∅')
         ||' / reject='||left(coalesce((v_res - 'run')::text, '∅'), 120)
         ||' / pending='||left(coalesce((v_res2 - 'run')::text, '∅'), 120)
         ||' / accept_new='||left(coalesce((v_res3 - 'run')::text, '∅'), 120)
         ||' / promotion='||left(coalesce((v_res4 - 'run')::text, '∅'), 150)
         ||' / E='||coalesce((SELECT row(editorial_decision, created_book_draft_id, discarded_draft_id)::text
                                FROM ingest.partner_catalog_staging_rows WHERE id = v_ke), '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T29 ─────────────────────────────────────────────────────────────
  v_t := 'T29 (5e passe) lignes sorties du run apres le chargement (Retraiter ailleurs : effacees, relues sous de nouveaux id) : Rejeter et Rapprocher de l''onglet perime rendent {updated_rows|created_items 0, skipped_rows n} sans refus ; les lignes relues intactes';
  BEGIN
    -- L'autre onglet : « Retraiter ». L'edge function (service_role), comme
    -- process-partner-catalog-import/index.ts (l. 601-610, 461, 825) : run en
    -- cours, lignes du run effacées, relues du fichier (mêmes numéros, mêmes
    -- clés, nouveaux id), run de nouveau prêt.
    EXECUTE 'SET LOCAL ROLE service_role';
    UPDATE ingest.partner_catalog_import_runs SET run_status = 'processing', started_at = now(), finished_at = NULL WHERE id = v_runL;
    DELETE FROM ingest.partner_catalog_staging_rows WHERE run_id = v_runL;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, proposed_book_id, normalized_payload)
    VALUES (v_runL, 1, 'H21B-L1', 'H21B Notice L1 a rapprocher', 'matched_book', 'pending', 'pending', v_book,
            jsonb_build_object('items', '[{"source_item_code": "H21B-EX-L1", "call_number": "H21B L1"}]'::jsonb)) RETURNING id INTO v_l1n;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, proposed_book_id, normalized_payload)
    VALUES (v_runL, 2, 'H21B-L2', 'H21B Notice L2 a rapprocher', 'possible_duplicate', 'pending', 'pending', v_book,
            jsonb_build_object('items', '[{"source_item_code": "H21B-EX-L2", "call_number": "H21B L2"}]'::jsonb)) RETURNING id INTO v_l2n;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
    VALUES (v_runL, 3, 'H21B-L3', 'H21B Notice L3', 'new_record', 'pending', 'pending') RETURNING id INTO v_l3n;
    UPDATE ingest.partner_catalog_import_runs SET run_status = 'ready_for_review', finished_at = now() WHERE id = v_runL;
    EXECUTE 'RESET ROLE';
    IF v_n <> 3 OR EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows WHERE id IN (v_l1, v_l2, v_l3)) THEN
      RAISE EXCEPTION 'decor : Retraiter simule, % ligne(s) effacee(s)', v_n;
    END IF;
    SELECT jsonb_object_agg(sr.id, to_jsonb(sr)) INTO v_snap
      FROM ingest.partner_catalog_staging_rows sr WHERE sr.run_id = v_runL;
    SELECT count(*) INTO v_nb FROM public.catalog_batches;
    SELECT count(*) INTO v_nx FROM public.exemplar_drafts;
    -- Cet onglet, chargé avant : « Rejeter » sur ses trois lignes, puis
    -- « Rapprocher » sur ses deux doublons, par l'API.
    v_txt := NULL; v_err := NULL; v_hint := NULL; v_msg := NULL; v_res := NULL; v_res2 := NULL;
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
      v_res := public.fn_import_set_editorial(v_runL, ARRAY[v_l1, v_l2, v_l3], 'reject', 'page import: écarté (doublon / non pertinent)');
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_txt = MESSAGE_TEXT, v_hint = PG_EXCEPTION_HINT;
    END;
    BEGIN
      v_res2 := public.fn_import_reconcile_duplicates(v_runL, ARRAY[v_l1, v_l2]);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT, v_msg = PG_EXCEPTION_HINT;
    END;
    EXECUTE 'RESET ROLE';
    IF v_txt IS NULL AND v_err IS NULL
       -- « Rejeter » : rien d'écrit, les trois comptées ignorées (l'écran :
       -- rejectedPartial {rejected 0, asked 3}, kind 'error' ; avant :
       -- {updated_rows 0, skipped_rows 0} et « Lignes écartées. » en succès)
       AND (v_res->>'updated_rows')::int = 0
       AND (v_res->>'skipped_rows')::int = 3
       AND v_res->>'editorial_decision' = 'reject'
       -- « Rapprocher » : ni lot ni exemplaire, les deux comptées ignorées
       -- (l'écran : reconciledPartial, kind 'error' ; avant : refus en bloc
       -- sans HINT « Aucune ligne eligible au rapprochement pour le run L »)
       AND (v_res2->>'created_items')::int = 0
       AND (v_res2->>'skipped_rows')::int = 2
       AND v_res2->>'batch_id' IS NULL
       AND (SELECT count(*) FROM public.catalog_batches) = v_nb
       AND (SELECT count(*) FROM public.exemplar_drafts) = v_nx
       -- les lignes relues : telles que l'edge function les a écrites
       AND (SELECT jsonb_object_agg(sr.id, to_jsonb(sr)) FROM ingest.partner_catalog_staging_rows sr
             WHERE sr.run_id = v_runL) = v_snap
       AND (SELECT string_agg(editorial_decision || '/' || review_status, ',' ORDER BY row_no)
              FROM ingest.partner_catalog_staging_rows WHERE run_id = v_runL) = 'pending/pending,pending/pending,pending/pending'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : Rejeter refus='||coalesce(v_txt, 'aucun')||' ['||coalesce(v_hint, '')||']'
         ||' ('||left(coalesce((v_res - 'run')::text, '∅'), 150)||')'
         ||' / Rapprocher refus='||coalesce(v_err, 'aucun')||' ['||coalesce(v_msg, '')||']'
         ||' ('||left(coalesce((v_res2 - 'run')::text, '∅'), 200)||')'
         ||' / lignes relues='||coalesce((SELECT string_agg(editorial_decision || '/' || review_status, ',' ORDER BY row_no)
                                           FROM ingest.partner_catalog_staging_rows WHERE run_id = v_runL), '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN
    EXECUTE 'RESET ROLE';
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  -- ── T30 ─────────────────────────────────────────────────────────────
  v_t := 'T30 (5e passe) selection melee [ligne sortie du run, ligne relue eligible] : l''eligible traitee, skipped_rows 1 (Rejeter : updated_rows 1 ; Rapprocher : un exemplaire)';
  BEGIN
    IF v_l1n IS NULL OR v_l2n IS NULL OR v_l3n IS NULL THEN RAISE EXCEPTION 'decor de T29 absent'; END IF;
    SELECT to_jsonb(sr) INTO v_snap FROM ingest.partner_catalog_staging_rows sr WHERE sr.id = v_l2n;
    -- Par l'API seule : à l'écran, loadRunRows élague la sélection au
    -- rechargement (les anciens id, absents des lignes reçues, en sortent) et
    -- l'onglet qui n'a pas rechargé ne montre pas les relues ; seule l'API
    -- mêle anciens et nouveaux id : [L3 effacée, L3 relue], [L1 effacée, L1 relue].
    v_txt := NULL; v_err := NULL; v_res := NULL; v_res2 := NULL;
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
      v_res := public.fn_import_set_editorial(v_runL, ARRAY[v_l3, v_l3n], 'reject', 'page import: écarté (doublon / non pertinent)');
    EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM;
    END;
    BEGIN
      v_res2 := public.fn_import_reconcile_duplicates(v_runL, ARRAY[v_l1, v_l1n]);
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    END;
    EXECUTE 'RESET ROLE';
    IF v_txt IS NULL AND v_err IS NULL
       -- « Rejeter » : L3 relue rejetée, l'effacée comptée (l'écran :
       -- rejectedPartial {rejected 1, asked 2}, kind 'info')
       AND (v_res->>'updated_rows')::int = 1
       AND (v_res->>'skipped_rows')::int = 1
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                    WHERE id = v_l3n AND editorial_decision = 'reject' AND review_status = 'rejected'
                      AND editorial_note = 'page import: écarté (doublon / non pertinent)')
       -- « Rapprocher » : L1 relue rapprochée (un exemplaire, dans le lot
       -- rendu, sur la notice proposée), l'effacée comptée
       AND (v_res2->>'skipped_rows')::int = 1
       AND (v_res2->>'requested_rows')::int = 1
       AND (v_res2->>'created_exemplar_drafts')::int = 1
       AND (v_res2->>'created_items')::int = 1
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                    WHERE id = v_l1n AND editorial_decision = 'accept_duplicate' AND review_status = 'draft_created'
                      AND created_exemplar_draft_id IS NOT NULL)
       AND (SELECT array_agg(x.source_item_code) FROM public.exemplar_drafts x WHERE x.import_staging_row_id = v_l1n) = ARRAY['H21B-EX-L1']
       AND EXISTS (SELECT 1 FROM public.exemplar_drafts x
                    WHERE x.import_staging_row_id = v_l1n AND x.batch_id = (v_res2->>'batch_id')::bigint
                      AND x.target_bib_ref = 'H21B-RATT-I4')
       -- L2 relue, hors sélection : intacte
       AND (SELECT to_jsonb(sr) FROM ingest.partner_catalog_staging_rows sr WHERE sr.id = v_l2n) = v_snap
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : Rejeter refus='||coalesce(v_txt, 'aucun')
         ||' ('||left(coalesce((v_res - 'run')::text, '∅'), 150)||')'
         ||' / Rapprocher refus='||coalesce(v_err, 'aucun')||' ('||left(coalesce((v_res2 - 'run')::text, '∅'), 250)||')'
         ||' / L1,L2,L3 relues='||coalesce((SELECT string_agg(editorial_decision || '/' || review_status, ',' ORDER BY row_no)
                                              FROM ingest.partner_catalog_staging_rows WHERE run_id = v_runL), '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN
    EXECUTE 'RESET ROLE';
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  -- ── T31 ─────────────────────────────────────────────────────────────
  v_t := 'T31 (5e passe) Rejeter une ligne deja rejetee par H19 (Rapprocher d''une ligne entierement detenue) : ignoree (updated_rows 0, skipped_rows 1), la raison de H19 reste ; [N1, N2] ne rejette que N2';
  BEGIN
    -- Décor (postgres) : un exemplaire de BLMF du seed porte le code d'origine
    -- de l'unique exemplaire de N1.
    UPDATE public.exemplares SET source_item_code = 'H21B-HELD-N1'
     WHERE id = (SELECT e.id FROM public.exemplares e WHERE e.library_id = v_lib ORDER BY e.id LIMIT 1)
    RETURNING id INTO v_exh;
    IF v_exh IS NULL THEN RAISE EXCEPTION 'decor : aucun exemplaire de BLMF au seed'; END IF;
    -- L'autre onglet : « Rapprocher » N1. Tous ses exemplaires sont déjà là :
    -- H19 la marque rejetée, avec sa raison, sans exemplaire.
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_res := public.fn_import_reconcile_duplicates(v_runN, ARRAY[v_n1]);
    EXECUTE 'RESET ROLE';
    IF (v_res->>'rows_already_held')::int IS DISTINCT FROM 1
       OR NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                       WHERE id = v_n1 AND editorial_decision = 'reject' AND review_status = 'rejected'
                         AND created_exemplar_draft_id IS NULL
                         AND editorial_note LIKE 'Todos os exemplares desta linha ja estao na biblioteca%') THEN
      RAISE EXCEPTION 'decor : N1 non rejetee par H19 (%)', left(coalesce((v_res - 'run')::text, '∅'), 200);
    END IF;
    SELECT to_jsonb(sr) INTO v_snap FROM ingest.partner_catalog_staging_rows sr WHERE sr.id = v_n1;
    -- Cet onglet, chargé avant (N1 et N2 en attente) : « Rejeter » N1 seule,
    -- puis [N1, N2].
    v_txt := NULL; v_res2 := NULL; v_res3 := NULL;
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
      v_res2 := public.fn_import_set_editorial(v_runN, ARRAY[v_n1], 'reject', 'page import: écarté (doublon / non pertinent)');
      v_res3 := public.fn_import_set_editorial(v_runN, ARRAY[v_n1, v_n2], 'reject', 'page import: écarté (doublon / non pertinent)');
    EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM;
    END;
    EXECUTE 'RESET ROLE';
    IF v_txt IS NULL
       -- l'écran : rejectedPartial {rejected 0, asked 1}, kind 'error' ; puis
       -- {rejected 1, asked 2}, kind 'info' (avant : updated_rows 1, succès
       -- plein, la raison de H19 écrasée — constat S4)
       AND (v_res2->>'updated_rows')::int = 0
       AND (v_res2->>'skipped_rows')::int = 1
       AND v_res2->>'editorial_decision' = 'reject'
       AND (v_res3->>'updated_rows')::int = 1
       AND (v_res3->>'skipped_rows')::int = 1
       -- N1 : la ligne entière, la raison de H19 comprise
       AND (SELECT to_jsonb(sr) FROM ingest.partner_catalog_staging_rows sr WHERE sr.id = v_n1) = v_snap
       AND (SELECT editorial_note FROM ingest.partner_catalog_staging_rows WHERE id = v_n1)
           LIKE 'Todos os exemplares desta linha ja estao na biblioteca%'
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                    WHERE id = v_n2 AND editorial_decision = 'reject' AND review_status = 'rejected'
                      AND editorial_note = 'page import: écarté (doublon / non pertinent)')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : refus='||coalesce(v_txt, 'aucun')
         ||' / N1 seule='||left(coalesce((v_res2 - 'run')::text, '∅'), 150)
         ||' / [N1, N2]='||left(coalesce((v_res3 - 'run')::text, '∅'), 150)
         ||' / note N1='||coalesce((SELECT editorial_note FROM ingest.partner_catalog_staging_rows WHERE id = v_n1), '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN
    EXECUTE 'RESET ROLE';
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  -- ── T32 ─────────────────────────────────────────────────────────────
  v_t := 'T32 (5e passe, non-regression) pending sur une ligne rejetee a la main la releve (updated_rows 1, skipped_rows 0) : seules reject et accept_new ignorent une ligne rejetee';
  BEGIN
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM public.fn_import_set_editorial(v_runN, ARRAY[v_n3], 'reject', 'page import: écarté (doublon / non pertinent)');
    EXECUTE 'RESET ROLE';
    IF NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                    WHERE id = v_n3 AND editorial_decision = 'reject' AND review_status = 'rejected') THEN
      RAISE EXCEPTION 'decor : N3 non rejetee';
    END IF;
    -- « En attente », par l'API (aucun écran ne l'envoie).
    v_txt := NULL; v_res := NULL;
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
      v_res := public.fn_import_set_editorial(v_runN, ARRAY[v_n3], 'pending', 'H21B remise en attente par l''API');
    EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM;
    END;
    EXECUTE 'RESET ROLE';
    IF v_txt IS NULL
       AND (v_res->>'updated_rows')::int = 1
       AND (v_res->>'skipped_rows')::int = 0
       AND v_res->>'editorial_decision' = 'pending'
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                    WHERE id = v_n3 AND editorial_decision = 'pending' AND review_status = 'pending'
                      AND NOT selected_for_draft AND created_book_draft_id IS NULL
                      AND editorial_note = 'H21B remise en attente par l''API')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : refus='||coalesce(v_txt, 'aucun')
         ||' / '||left(coalesce((v_res - 'run')::text, '∅'), 200)
         ||' / N3='||coalesce((SELECT editorial_decision || '/' || review_status FROM ingest.partner_catalog_staging_rows WHERE id = v_n3), '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN
    EXECUTE 'RESET ROLE';
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  -- ── T33 ─────────────────────────────────────────────────────────────
  v_t := 'T33 (6e passe) notice proposee descartee dans un autre onglet : Rapprocher [V3] rend {created_items 0, skipped_rows 1} sans refus ; [V1, V2] skipped_rows 1, un exemplaire (V2), V1 en attente sans rattache ; par l''API [V6 matched_draft, V4 manual_decision] ne rapproche que V4 ; [V5, V7] toutes eligibles comme avant';
  BEGIN
    -- L'onglet B : Catalogage › Catalogue, « Descartar » sur Bx
    -- (CatalogPanel.discardItem → discard_book_cascade). BLMF seule la
    -- détient : son fonds retiré, la notice supprimée, et proposed_book_id de
    -- V1 et V3 vidé (clé étrangère ON DELETE SET NULL).
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_res5 := public.discard_book_cascade(v_bx);
    EXECUTE 'RESET ROLE';
    IF NOT coalesce((v_res5->>'book_deleted')::boolean, false)
       OR EXISTS (SELECT 1 FROM public.books WHERE id = v_bx)
       OR EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                   WHERE id IN (v_v1, v_v3) AND proposed_book_id IS NOT NULL) THEN
      RAISE EXCEPTION 'decor : descarte de Bx (%)', coalesce(v_res5::text, '∅');
    END IF;
    SELECT jsonb_object_agg(sr.id, to_jsonb(sr)) INTO v_snap
      FROM ingest.partner_catalog_staging_rows sr WHERE sr.id IN (v_v1, v_v3, v_v6);
    SELECT count(*) INTO v_nb FROM public.catalog_batches;
    SELECT count(*) INTO v_nx FROM public.exemplar_drafts;
    -- L'onglet A, chargé avant le descarte : V1 et V3 y montrent encore leur
    -- notice, handleReconcileSelected les envoie. « Rapprocher » [V3], puis
    -- [V1, V2].
    v_txt := NULL; v_err := NULL; v_msg := NULL; v_hint := NULL;
    v_res := NULL; v_res2 := NULL; v_res3 := NULL; v_res4 := NULL;
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
      v_res := public.fn_import_reconcile_duplicates(v_runV, ARRAY[v_v3]);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_txt = MESSAGE_TEXT;
    END;
    EXECUTE 'RESET ROLE';
    SELECT count(*) INTO v_n FROM public.catalog_batches;
    SELECT count(*) INTO v_m FROM public.exemplar_drafts;
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
      v_res2 := public.fn_import_reconcile_duplicates(v_runV, ARRAY[v_v1, v_v2]);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    END;
    -- Par l'API (l'écran n'envoie que matched_book et possible_duplicate) :
    -- V6, matched_draft, compatible avec « rattaché » mais que l'ingest ne
    -- rapproche pas ; V4, manual_decision, qu'il rapproche.
    BEGIN
      v_res3 := public.fn_import_reconcile_duplicates(v_runV, ARRAY[v_v6, v_v4]);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT;
    END;
    -- Non-régression : une sélection toute éligible, dont la notice est restée.
    BEGIN
      v_res4 := public.fn_import_reconcile_duplicates(v_runV, ARRAY[v_v5, v_v7]);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = MESSAGE_TEXT;
    END;
    EXECUTE 'RESET ROLE';
    IF v_txt IS NULL AND v_err IS NULL AND v_msg IS NULL AND v_hint IS NULL
       -- [V3] : rien ne reste, ni lot ni exemplaire (l'écran : reconciledPartial
       -- {skipped 1, asked 1}, kind 'error' ; avant : refus brut sans HINT)
       AND (v_res->>'created_items')::int = 0
       AND (v_res->>'skipped_rows')::int = 1
       AND v_res->>'batch_id' IS NULL
       AND v_n = v_nb AND v_m = v_nx
       -- [V1, V2] : V2 seule rapprochée, dans le lot rendu, sur sa notice
       -- (l'écran : reconciledPartial {skipped 1, asked 2}, kind 'info' ;
       -- avant : skipped_rows 0, « Brouillon d'exemplaire créé » en succès)
       AND (v_res2->>'skipped_rows')::int = 1
       AND (v_res2->>'requested_rows')::int = 1
       AND (v_res2->>'created_exemplar_drafts')::int = 1
       AND (v_res2->>'created_items')::int = 1
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                    WHERE id = v_v2 AND editorial_decision = 'accept_duplicate' AND review_status = 'draft_created'
                      AND created_exemplar_draft_id IS NOT NULL)
       AND (SELECT array_agg(x.source_item_code) FROM public.exemplar_drafts x WHERE x.import_staging_row_id = v_v2) = ARRAY['H21B-EX-V2']
       AND EXISTS (SELECT 1 FROM public.exemplar_drafts x
                    WHERE x.import_staging_row_id = v_v2 AND x.batch_id = (v_res2->>'batch_id')::bigint
                      AND x.target_bib_ref = 'H21B-RATT-I4')
       -- [V6, V4] : V4 rapprochée (manual_decision reste rapprochable), V6 ignorée
       AND (v_res3->>'skipped_rows')::int = 1
       AND (v_res3->>'requested_rows')::int = 1
       AND (v_res3->>'created_items')::int = 1
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                    WHERE id = v_v4 AND editorial_decision = 'accept_duplicate' AND review_status = 'draft_created'
                      AND created_exemplar_draft_id IS NOT NULL)
       AND (SELECT array_agg(x.source_item_code) FROM public.exemplar_drafts x WHERE x.import_staging_row_id = v_v4) = ARRAY['H21B-EX-V4']
       -- [V5, V7] : comme avant (skipped_rows 0, les clés d'avant, deux exemplaires)
       AND (v_res4->>'skipped_rows')::int = 0
       AND (v_res4->>'requested_rows')::int = 2
       AND (v_res4->>'created_exemplar_drafts')::int = 2
       AND (v_res4->>'created_items')::int = 2
       AND (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(v_res4 - 'skipped_rows') AS k)
           = ARRAY['batch_id', 'batch_name', 'created_exemplar_drafts', 'created_items', 'items_skipped_code_taken',
                   'requested_rows', 'rows_already_held', 'run', 'run_id']
       AND (SELECT array_agg(x.source_item_code ORDER BY x.source_item_code) FROM public.exemplar_drafts x
             WHERE x.import_staging_row_id IN (v_v5, v_v7)) = ARRAY['H21B-EX-V5', 'H21B-EX-V7']
       -- V1, V3, V6 : les lignes entières telles qu'après le descarte — en
       -- attente, aucune décision « rattaché », aucun exemplaire
       AND (SELECT jsonb_object_agg(sr.id, to_jsonb(sr)) FROM ingest.partner_catalog_staging_rows sr
             WHERE sr.id IN (v_v1, v_v3, v_v6)) = v_snap
       AND (SELECT string_agg(editorial_decision || '/' || review_status, ',' ORDER BY row_no)
              FROM ingest.partner_catalog_staging_rows WHERE id IN (v_v1, v_v3, v_v6)) = 'pending/pending,pending/pending,pending/pending'
       AND NOT EXISTS (SELECT 1 FROM public.exemplar_drafts WHERE import_staging_row_id IN (v_v1, v_v3, v_v6))
       -- en tout : trois lots ([V1, V2], [V6, V4], [V5, V7]), quatre exemplaires
       AND (SELECT count(*) FROM public.catalog_batches) = v_nb + 3
       AND (SELECT count(*) FROM public.exemplar_drafts) = v_nx + 4
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : [V3] refus='||coalesce(v_txt, 'aucun')
         ||' ('||left(coalesce((v_res - 'run')::text, '∅'), 120)||')'
         ||' / [V1,V2] refus='||coalesce(v_err, 'aucun')||' ('||left(coalesce((v_res2 - 'run' - 'batch_name')::text, '∅'), 200)||')'
         ||' / [V6,V4] refus='||coalesce(v_msg, 'aucun')||' ('||left(coalesce((v_res3 - 'run' - 'batch_name')::text, '∅'), 200)||')'
         ||' / [V5,V7] refus='||coalesce(v_hint, 'aucun')||' ('||left(coalesce((v_res4 - 'run' - 'batch_name')::text, '∅'), 200)||')'
         ||' / V1..V7='||coalesce((SELECT string_agg(editorial_decision || '/' || review_status, ',' ORDER BY row_no)
                                     FROM ingest.partner_catalog_staging_rows WHERE run_id = v_runV), '∅')
         ||' / lots '||v_nb||' -> '||(SELECT count(*) FROM public.catalog_batches)
         ||' / exemplaires '||v_nx||' -> '||(SELECT count(*) FROM public.exemplar_drafts)); END IF;
  EXCEPTION WHEN OTHERS THEN
    EXECUTE 'RESET ROLE';
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'IMPORT-PROMOTION-SELECTION OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'IMPORT-PROMOTION-SELECTION ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
