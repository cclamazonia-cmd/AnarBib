-- =====================================================================
-- AnarBib — Tests d'acceptation : la révision suit le BROUILLON importé
-- (H21 lot 0, REGISTRE IMP-27 a, c et e ; refus de supprimer le run)
-- Date    : 2026-09-29 (seconde à cinquième passes après revue : 2026-09-30)
-- Ref     : migration 20261001200931_h21_lot0_la_revision_suit_le_brouillon_importe
--
-- Décision de Xavier du 29/09 : une notice née d'un import (lien
-- ingest.partner_catalog_row_to_draft, ou trace marc_json.ingest d'une
-- création sans published_book_id) ne se publie que DANS un lot, après une
-- révision approuvée — même sortie de son lot d'origine. Avant le lot 0, la
-- garde ne suivait que le lot (lien m.batch_id, ou partner_source /
-- import_method, que l'API écrit) : « Sans lot », un changement de
-- bibliothèque, un lot supprimé, un rangement dans un lot fait à la main, un
-- rejeu du journal la laissaient hors de toute révision.
--
-- T1  « Sans lot » : imported_needs_batch, rien de publié.
-- T2  changement de bibliothèque par une personne staff des deux (le
--     déclencheur sort le brouillon du lot) : même refus.
-- T3  lot supprimé (seul le brouillon jeté y restait), restauration : même refus.
-- T4  rangé dans un lot fait à la main, partner_source / import_method vidés
--     (colonne ET marc_json.anarbib_provenance) : le lot devient importé,
--     review_required, la demande de révision est acceptée.
-- T5  lien perdu (suppression définitive, run supprimé, rejeu du journal),
--     trace gardée : review_required dans son lot, imported_needs_batch hors
--     lot. Depuis la seconde passe, le rejeu rend sa ligne à une création tant
--     que la ligne existe (T10) : c'est la suppression du run qui ôte le lien
--     pour de bon, et la trace reste la seule preuve.
-- T6  trace sans lien (création) : review_required dans un lot fait à la
--     main, imported_needs_batch hors lot.
-- T7  NON-RÉGRESSION : une reprise (published_book_id posé, trace recopiée de
--     sa notice) n'est pas gardée — hors lot, et dans un lot fait à la main.
-- T8  NON-RÉGRESSION : un brouillon fait à la main se publie hors lot et dans
--     un lot fait à la main.
-- T9  fn_batch_is_imported(lot) = fn_book_draft_is_imported(brouillon) pour
--     cinq formes (lié en cours, lié publié, création tracée sans lien,
--     reprise tracée, faite à la main), partner_source nul.
-- T10 (e) supprimer définitivement un brouillon importé écarte sa ligne
--     ('reject' / 'rejected', note, discarded_draft_id = ce brouillon) ; la
--     promotion suivante ne la recrée pas ; le rejeu du journal ramène le
--     brouillon ET lui rend sa ligne (created_book_draft_id, 'accept_new' /
--     'draft_created', note du rejeu, discarded_draft_id vidé, lien
--     row_to_draft SANS lot — batch_id NULL : le lot de la promotion n'est
--     plus connu —, le brouillon resté dans son lot, décision reverrouillée) :
--     une seule notice pour la ligne.
-- T11 fn_import_delete_run refusé (run_has_linked_drafts) tant qu'un
--     brouillon lié draft/ready vit hors de son lot — le refus ne détruit
--     rien (non-action) ; accepté quand ils sont à la corbeille (action).
-- T12 droits : les quatre aides fermées à anon et authenticated, ouvertes à
--     service_role.
--
-- Amendements du 29/09 (relecture contradictoire) :
-- T13 (a) la trace marc_json.ingest ne se réécrit, ne se vide ni ne s'ôte par
--     l'API (déclencheur book_drafts_trace_import_figee, rôle authenticated) ;
--     une autre retouche du même UPDATE reste ; « Sans lot », la création
--     tracée sans lien est refusée (imported_needs_batch).
-- T14 (a) par l'API, published_book_id ne passe pas de NULL à une notice de la
--     bibliothèque sur une création tracée : il reste NULL (le reste de
--     l'UPDATE passe), le brouillon reste importé, la publication hors lot est
--     refusée — une « reprise » aurait réécrit la notice sans révision.
-- T15 NON-RÉGRESSION : appelées par l'API (SET LOCAL ROLE authenticated), les
--     fonctions DEFINER posent la trace (promotion, « Éditer » d'une notice
--     importée) et published_book_id (publication après révision approuvée).
-- T16 NON-RÉGRESSION : sur un brouillon fait à la main (sans trace),
--     marc_json et published_book_id restent modifiables par l'API.
-- T17 (e) réécrit à la quatrième passe. (0) Par l'API, AUCUNE décision ne
--     relève une ligne écartée : 'pending', 'accept_new', puis 'reject' avec
--     une note, sur deux lignes écartées — ignorées (updated_rows 0,
--     skipped_rows 2) ; chaque ligne reste 'reject' / 'rejected', non
--     sélectionnée, avec la note du déclencheur et discarded_draft_id = son
--     brouillon, sans lien ni brouillon ; la promotion (la sélection, puis
--     tout le run) ne sélectionne rien. La voie de la troisième passe
--     ('pending' puis 'accept_new') est fermée. (1) La repromotion, que l'API
--     ne construit donc plus, est POSÉE EN POSTGRES : décision 'accept_new' /
--     'approved' / sélectionnée écrite sur la ligne 1 (ce qu'écrivait
--     fn_set_partner_catalog_editorial_decision), note et discarded_draft_id
--     vidés ; puis « Promouvoir » par l'API : un nouveau brouillon. (2)
--     fn_restore_deleted_draft (API) refuse alors (restore_line_repromoted)
--     de rejouer l'ancien brouillon — rien de rejoué ni de journalisé ; (3) le
--     lien seul et created_book_draft_id seul suffisent (états posés par
--     postgres ; discarded_draft_id vide : la clause d'écartement ne joue
--     pas). (4) La ligne 2, jamais repromue, sur qui les gestes de (0) sont
--     restés sans effet, est reprise par le rejeu de SON brouillon (API) :
--     created_book_draft_id, 'accept_new' / 'draft_created', discarded_draft_id
--     vidé, un seul lien, sans lot ; la ligne 1 reste au nouveau brouillon.
--     La garde du journal est désormais défensive vis-à-vis de l'API : les
--     seules fonctions ouvertes à authenticated qui écrivent la décision d'une
--     ligne sont fn_import_set_editorial, fn_import_reconcile_duplicates (qui
--     ignorent une ligne écartée) et fn_restore_deleted_draft (sonde du 30/09).
--
-- Seconde passe (revue du 29/09, constats #0, #2, #6, #7, #9, #10, #16) :
-- T18 (#6) la REPRISE (« Éditer », create_book_draft_from_book) d'une notice
--     importée publiée, supprimée définitivement, se rejoue du journal : la
--     garde de (e) ne juge que les créations. Ses retouches reviennent ; sa
--     publication met à jour LA notice (une seule au catalogue) ; la ligne
--     reste au brouillon d'import (created_book_draft_id, lien), et la
--     suppression de la reprise ne l'a pas écartée.
-- T19 (#10, #16) une création supprimée définitivement puis rejouée ; sa
--     ligne réacceptée par l'API (fn_import_set_editorial : ignorée, déjà
--     convertie, skipped_rows 1) puis promue (la sélection, puis tout le run) :
--     aucun second brouillon, une seule notice possible pour la ligne ; sorti
--     de la corbeille, le brouillon rejoué retient de nouveau le run
--     (run_has_linked_drafts : le lien est revenu SANS lot, que le compte par
--     lot ne voit pas ; seul le compte des brouillons liés le retient).
-- T20 (#0) un exemplaire RAPPROCHÉ (fn_import_reconcile_duplicates) mis à la
--     corbeille retient son run : fn_import_delete_run refusé
--     (run_has_trashed_items) ; run, ligne, lot et exemplaire intacts.
-- T21 (#0) un exemplaire rapproché purgé (« Vider la corbeille ») : le run
--     se supprime ; le journal refuse ensuite de le rejouer sans sa ligne
--     (restore_item_import_gone) — rien n'est rejoué, rien n'est journalisé.
-- T22 (#2) par l'API (authenticated), seule la publication met un brouillon
--     de notice en 'published' : UPDATE et INSERT refusés (42501,
--     error.publish.status_reserved) ; 'draft' et 'ready' passent ; un
--     brouillon déjà publié se réenregistre avec 'published' (le formulaire
--     renvoie tout le brouillon).
-- T23 (#2, défense) un exemplaire RATTACHÉ dont la notice porte 'published'
--     (posé en postgres, l'API ne le peut plus) sans notice au catalogue
--     (published_book_id NULL) ne se publie pas (item_before_record), même
--     visé par l'API sur la détention d'une notice existante ; aucun
--     exemplaire créé.
-- T24 (#7, #9) le déclencheur d'écartement lit les lignes par index.
--     Parcours séquentiels, d'index simples et index-only coupés (restent
--     les parcours bitmap, qui exigent une condition d'index : une forme non
--     indexable retombe en parcours séquentiel), plans refaits
--     (plan_cache_mode). Compteurs lus par RETURNING : après le déclencheur
--     BEFORE DELETE, AVANT l'action ON DELETE SET NULL de la clé étrangère,
--     qui lit le même index (lu après l'instruction, le compteur de l'index
--     ne prouverait rien). Pour un brouillon importé et pour un brouillon
--     fait à la main : l'index de created_book_draft_id est lu, la table des
--     lignes jamais parcourue en entier ; la ligne est bien écartée.
--
-- Troisième passe (contre-vérification du 30/09 : #0, #10/#16 P1 et P2) ;
-- jouées AVANT T24, qui reste en dernier dans le fichier :
-- T25 (P1, réécrit à la quatrième passe) entre le vidage et le rejeu, les
--     gestes sur la décision sont ignorés : les deux lignes « En attente »
--     (updated_rows 0, skipped_rows 2), puis la ligne 2 « Accepté (nouveau) »
--     (l'ordre « réaccepter avant de rejouer » : 0 / 1) ; chaque ligne reste
--     intacte ('reject' / 'rejected', non sélectionnée, la note du
--     déclencheur, discarded_draft_id = son brouillon, rien de créé, aucun
--     lien) ; le rejeu (API) reprend chacune (created_book_draft_id,
--     'accept_new' / 'draft_created', discarded_draft_id vidé, un lien sans
--     lot) ; ensuite 'pending' et 'accept_new' sont ignorés (skipped_rows 2) et
--     la promotion — la sélection puis tout le run — ne sélectionne rien : un
--     brouillon par ligne, aucun lot ouvert.
-- T26 (P2) le lot réattribué à une autre bibliothèque par l'administration
--     (fn_batch_reassign_library, run own_catalog de BLMF) avant la corbeille :
--     le brouillon purgé puis rejoué (par l'administration) reprend quand même
--     sa ligne, sans clause de bibliothèque ; il reste à la nouvelle
--     bibliothèque et dans son lot ; la coordination du run ne refait pas de
--     second brouillon (décision ignorée, promotion vide).
-- T27 (#0) le statut « publié » d'un brouillon d'exemplaire est réservé à la
--     publication : sur un exemplaire RAPPROCHÉ, par l'API, 'ready' passe,
--     UPDATE à 'published' refusé (42501, error.publish.status_reserved) ; un
--     INSERT en 'published' refusé de même, le même INSERT en 'draft' passe ;
--     l'exemplaire reste non publié, avec sa ligne, et retient son run
--     (fn_import_delete_run : run_has_drafts, run et ligne intacts) ; aucun
--     exemplaire au catalogue.
--
-- Quatrième passe (30/09 : une ligne écartée n'accepte plus aucune décision ;
-- la garde du journal lit aussi discarded_draft_id ; une ligne ne s'efface pas
-- sous un exemplaire rapproché non publié) — T17 et T25 réécrits (plus haut),
-- T28 et T29 ajoutés, joués AVANT T24, qui reste en dernier :
-- T28 (e, l'ordre « B » de la contre-vérification, fermé) D1 promu, purgé
--     (API) ; la ligne repromue EN POSTGRES (même décor que T17 (1) : l'API ne
--     le construit plus) en D2 ; D2 purgé (API) : discarded_draft_id réécrit à
--     D2. Rejouer D1 (API) : refus restore_line_repromoted (la ligne, libre,
--     n'est tenue que par discarded_draft_id = D2), rien de rejoué ni de
--     journalisé ; rejouer D2 : reprise (created_book_draft_id,
--     'accept_new' / 'draft_created', discarded_draft_id vidé, un lien sans
--     lot) ; rejouer D1 de nouveau : toujours refusé. Un seul brouillon pour
--     la ligne.
-- T29 (c, en-tête et intitulé corrigés à la cinquième passe, en-tête de
--     nouveau à la sixième) déclencheur
--     trg_staging_rows_retenue_par_rapproche : trois lignes rapprochées
--     (fn_import_reconcile_duplicates), un exemplaire chacune ; le lot révisé
--     (demandé, approuvé par l'administration), l'exemplaire 3 PUBLIÉ par
--     publish_exemplar_draft ; l'exemplaire 1 à la corbeille (API), le 2 en
--     cours. Le DELETE … WHERE run_id que joue l'edge function
--     process-partner-catalog-import au retraitement (force_reparse, en
--     service_role) est refusé par le déclencheur
--     (error.import.rows_held_by_items), l'instruction échoue en bloc ; la
--     ligne de l'exemplaire à la corbeille, puis celle de l'exemplaire en
--     cours, effacées seules en postgres : refusées de même ; rien d'effacé
--     (trois lignes, run, chaque exemplaire garde sa ligne). La ligne de
--     l'exemplaire PUBLIÉ s'efface (service_role) : l'exemplaire reste
--     publié, sa ligne à NULL (clé étrangère SET NULL), l'exemplaire au
--     catalogue intact. Seul ce DELETE est jugé ici (celui de l'edge
--     function, en service_role ; celui de postgres). Le geste « Retraiter »
--     de l'écran est refusé EN AMONT, par fn_import_dispatch (T30), quand la
--     conversion (rapprochement, corbeille) PRÉCÈDE l'envoi : il n'atteint
--     alors pas l'edge function. Cette garde se juge à l'envoi : une
--     conversion faite entre l'envoi et l'effacement par l'edge function
--     (second onglet, API) lui échappe — course antérieure (H15), consignée,
--     couverte ni par ce lot ni par cette suite.
--
-- Cinquième passe (30/09 : « Retraiter » refusé tout de suite par
-- fn_import_dispatch — un exemplaire rapproché à la corbeille, une ligne
-- écartée) — T29 corrigé (plus haut), T30 ajouté, joué AVANT T24 :
-- T30 (c, e ; en-tête précisé à la sixième passe) sous authenticated
--     (coordination de BLMF), la conversion PRÉCÉDANT l'envoi,
--     fn_import_dispatch(run, force_reparse => true) est REFUSÉ, HINT
--     error.import.reparse_after_promotion, (a) pour un run dont l'unique
--     exemplaire RAPPROCHÉ (sans notice) est à la corbeille — aucun lien, la
--     garde H19 ne voit que les exemplaires hors corbeille —, (b) pour un run
--     dont l'unique ligne est ÉCARTÉE (promue par l'API, son brouillon jeté
--     puis purgé par l'API : le lien est parti avec lui, seule
--     discarded_draft_id retient) ; les deux runs gardent leur statut, leurs
--     lignes (mêmes ids, même décision, même discarded_draft_id) et
--     l'exemplaire de (a) sa ligne. NON-RÉGRESSION : un run sans promotion ni
--     rapprochement (c), et un run dont l'exemplaire rapproché a été PURGÉ
--     (d), sont acceptés — jusqu'au relais d'envoi, remplacé par un TÉMOIN
--     (ingest.fn_dispatch_partner_catalog_import ; sur le banc local, l'envoi
--     réel poste vers les edge functions de la PRODUCTION avec le secret du
--     coffre), qui rend run_id et force_reparse. Aucune requête pg_net
--     (net.http_request_queue inchangée), aucun envoi journalisé
--     (partner_catalog_import_dispatch_log). Le témoin, le décor et les
--     appels vivent dans une sous-transaction que T30 lève lui-même :
--     run-sql-suites.sh joue chaque suite par psql -f SANS transaction
--     englobante, et le témoin ne doit rien laisser ni à T24 ni aux suites
--     suivantes ; T30 vérifie ensuite que l'envoi réel est revenu
--     (net.http_post dans sa définition). La garde se juge à l'envoi : la
--     course entre l'envoi et l'effacement des lignes par l'edge function
--     (une conversion faite pendant ces secondes, second onglet ou API) est
--     consignée — antérieure (H15) —, ni corrigée par ce lot ni couverte par
--     cette suite.
--
-- Contre-épreuves (suite.sh <suite> <fichier joué avant> ; fichiers hors
-- dépôt ; toutes rejouées de nouveau le 30/09 sur la cinquième passe, 30/30
-- sans elles, par h21-lot0-agents/P5/A/contre.sh — contre-anciens.log,
-- contre-A5.log, contre-A5-portages.log) :
--   ancien-publish_book_draft.sql      : T1 T2 T3 T5 T6 T13 T14 tombent ;
--   ancien-fn_batch_is_imported.sql    : T4 T5 T6 T9 tombent, et T29 (décor :
--     sans (c), la révision du lot de rapprochement n'est pas demandée) ;
--   ancien-fn_import_delete_run.sql    : T11 T19 T20 tombent (T19 : le lien
--     rétabli sans lot, seul le compte des brouillons liés le voit) ;
--   ancien-declencheur-ecartement.sql  : T10 T17 T19 T24 T25 T26 T28 tombent
--     (DROP TRIGGER trg_book_drafts_ecarte_ligne_importee), et T30 (décor de
--     (b) : la ligne n'est plus écartée, rien ne retiendrait le run) ;
--   ancien-T-a-sans-trace-figee.sql    : T13 T14 tombent (DROP TRIGGER
--     book_drafts_trace_import_figee) ;
--   ancien-T-a-fn_restore_deleted_draft.sql (définition d'avant le lot 0) :
--     T10 T17 T19 T21 T25 T26 T28 tombent ;
--   ancien-T-a-restauration-temoin.sql (définition du commit WIP) et ses
--     mutants -lien-seul / -cree-seul : T10 T17 T18 T19 T21 T25 T26 T28
--     tombent ;
--   ancien-publish_exemplar_draft.sql  : T23 tombe ;
--   mutants de la seconde passe, avant2-*.sql : la définition VIVANTE privée
--   du seul correctif (ancre comptée, CREATE OR REPLACE) ; chacun ne fait
--   tomber que les tests de son correctif :
--     -restauration-garde-reprises (la garde juge aussi les reprises) : T18 ;
--     -garde-lien-seul (la garde ne lit plus created_book_draft_id) : T17 ;
--     -garde-cree-seul : ancre disparue avec la quatrième passe, remplacé par
--       A4-garde-cree-seul ci-dessous ;
--     -restauration-exemplaire-sans-ligne : T21 (rejoué, lien vidé) ;
--     -suppression-run-sans-corbeille : T20 (run supprimé) ;
--     -sans-statut-reserve (DROP TRIGGER, notices) : T22 ;
--     -exemplaire-suit-le-statut : T23 (exemplaire créé sur la notice
--       existante, avec un tombo de BLMF et la cote du fichier) ;
--     -ecartement-ou (déclencheur du commit WIP, « … OR … », sans
--       discarded_draft_id) : T24 (aucune lecture de l'index, un parcours
--       séquentiel par brouillon supprimé), et T10 T17 T19 T25 T26 T28 (pas
--       de preuve d'écartement : pas de reprise), T30 (décor de (b)) ;
--     -restauration-sans-reprise-de-ligne et -decision-sans-lignes-converties :
--       ancres disparues avec la troisième passe, remplacées ci-dessous.
--   mutants de la troisième passe, A3-*.sql (même méthode) :
--     -reprise-sur-la-note (le bloc « ligne reprise » de la seconde passe :
--       note du déclencheur et 'reject', clause de bibliothèque, lien dans le
--       lot de l'instantané) : T10 T17 T19 T25 T26 T28 ;
--     -reprise-par-la-note-seule (la note et 'reject' au lieu de
--       discarded_draft_id, le reste intact) : ne fait plus tomber aucun test
--       — son scénario (un geste qui efface la note entre le vidage et le
--       rejeu, ancien T25) n'est plus possible par l'API depuis la quatrième
--       passe : mutant équivalent tant que la décision ignore la ligne écartée ;
--     -reprise-clause-bibliotheque (la clause de bibliothèque remise) : T26
--       seul (second brouillon après la réattribution) ;
--     -lien-dans-le-lot-de-l-instantane : T10 T17 T19 T25 T26 T28 ;
--     -sans-reprise-de-ligne : T10 T17 T19 T25 T26 T28 ;
--     -ecartement-sans-preuve (le déclencheur n'écrit plus
--       discarded_draft_id) : T10 T17 T19 T25 T26 T28, et T30 (décor de (b)) ;
--     -decision-releve-les-rejetees (« Accepté (nouveau) » relève de nouveau
--       une ligne rejetée À LA MAIN) : ancre comptée deux fois, une seule
--       depuis la cinquième passe (le compte des ignorées se fait sur les ids
--       demandés) — porté en A5-decision-releve-les-rejetees ci-dessous, qui ne
--       fait tomber aucun test de cette suite (la ligne écartée est ignorée par
--       le filtre de la quatrième passe) ; l'original faisait tomber
--       import_promotion_selection_tests.sql (T21 au 30/09 : ligne « rejetée
--       ailleurs ») ;
--     -decision-sans-lignes-ignorees (rien n'est plus ignoré) : T17 T19 T25
--       T26 ;
--     -sans-statut-reserve-exemplaire (DROP TRIGGER
--       exemplar_drafts_statut_publie_reserve) : T27 seul (UPDATE et INSERT
--       'published' acceptés, le run supprimé, l'exemplaire publié sans ligne).
--   mutants de la quatrième passe, A4-*.sql (h21-lot0-agents/P4/A/, même
--   méthode) :
--     -decision-sans-filtre-ecartee (fn_import_set_editorial ne filtre plus
--       discarded_draft_id) : sa seconde ancre (le compte « OR
--       sr.discarded_draft_id IS NOT NULL ») a disparu avec la cinquième
--       passe — porté en A5-decision-sans-filtre-ecartee ci-dessous : T17 T25
--       (les gestes relèvent la ligne écartée : updated_rows 2, la note de
--       l'API remplace celle du déclencheur) ;
--     -garde-sans-clause-ecartee (la garde ne lit plus discarded_draft_id) :
--       T28 seul (D1 rejoué, puis D2 repris : deux brouillons pour la ligne) ;
--     -sans-retenue-des-lignes (DROP TRIGGER
--       trg_staging_rows_retenue_par_rapproche) : T29 seul (le DELETE de
--       l'edge function efface les trois lignes, les exemplaires non publiés
--       perdent la leur) ;
--     -garde-cree-seul (la garde ne lit plus le lien) : T17 seul (le lien seul
--       ne retient plus : l'ancien brouillon est rejoué).
--   mutants de la cinquième passe, A5-*.sql (h21-lot0-agents/P5/A/, même
--   méthode ; sous chacun, T30 relève file pg_net 0 → 0, aucun envoi
--   journalisé, l'envoi réel revenu après sa sous-transaction) :
--     -retraiter-sans-corbeille (fn_import_dispatch perd « OR x.book_draft_id
--       IS NULL » : la garde H19, qui ne voit que les exemplaires hors
--       corbeille) : T30 seul — (a) accepté jusqu'au témoin, (b) refusé ;
--     -retraiter-sans-ecartee (la clause discarded_draft_id rendue fausse) :
--       T30 seul — (b) accepté jusqu'au témoin, (a) refusé ;
--     -retraiter-avant-cinquieme-passe (les deux clauses retirées : la garde
--       d'avant) : T30 seul — (a) et (b) acceptés ;
--     -retraiter-trop-strict (la clause discarded_draft_id rendue vraie : tout
--       run qui a des lignes est refusé) : T30 seul — (c) et (d) refusés, la
--       non-régression tient ;
--     -decision-sans-filtre-ecartee (portage de A4) : T17 T25 ;
--     -decision-releve-les-rejetees (portage de A3) : aucun test de cette
--       suite (voir plus haut).
--   T7, T8, T15, T16 : non-régression (ne tombent avec aucune) ; T15 tombe
--   avec le mutant ancien-T-a-trace-figee-sans-exemption.sql (le déclencheur
--   juge aussi les fonctions DEFINER) ; T12 : garde des droits (ne tombe
--   qu'avec le mutant ancien-A1-droits-ouverts.sql).
-- L'ordre « B », resté ouvert à la troisième passe (sonde A3-sonde-ordre-B.sql :
-- deux brouillons vivants pour une ligne), est fermé : l'API ne le construit
-- plus (T17 (0), T25), et construit en postgres il est refusé par la garde (T28).
--
-- Écritures par l'API sous le rôle authenticated quand un déclencheur de
-- rangement (tg_drafts_batch_guarded), la trace figée
-- (book_drafts_trace_import_figee), le statut réservé
-- (book_drafts_statut_publie_reserve, exemplar_drafts_statut_publie_reserve)
-- ou une politique doit juger ; RPC en postgres avec l'identité du jeton, sauf
-- en T15, T17, T18, T19, T21, T25, T26, T27, T28 et T30 où l'appel lui-même
-- passe par authenticated (l'exemption DEFINER, le chemin de l'écran). En T29,
-- les effacements de lignes passent par service_role (l'edge function) et par
-- postgres. États que l'API ne peut pas poser (T9, T17 (1) et (3), T23, la
-- repromotion de T28) : écrits en postgres, et dits tels. Le relais d'envoi
-- pg_net (ingest.fn_dispatch_partner_catalog_import) n'est jamais joué pour de
-- bon : T30, seul à appeler fn_import_dispatch, le remplace d'abord par un
-- témoin.
-- Refus confrontés au HINT réel (et au SQLSTATE en T22 et T27).
-- Toutes les écritures sont annulées : la suite se termine par un RAISE (en CI,
-- run-sql-suites.sh la joue par psql -f, sans transaction englobante) ; T30
-- lève en plus sa propre sous-transaction, qui emporte le témoin d'envoi.
--   Bilan OK : 'REVISION-BROUILLON-IMPORTE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF (seed)
  v_libB uuid; v_multi uuid;
  v_src bigint; v_run bigint; v_row bigint; v_row2 bigint;
  v_lot bigint; v_main bigint; v_d bigint; v_d2 bigint; v_book bigint; v_book2 bigint;
  v_l1 bigint; v_l2 bigint; v_l3 bigint; v_l4 bigint; v_l5 bigint;
  v_d1 bigint; v_d3 bigint; v_d4 bigint; v_d5 bigint;
  v_audit bigint; v_res jsonb; v_res2 jsonb;
  v_hint text; v_hint2 text; v_hint3 text; v_n int; v_m int; v_k int; v_ok boolean;
  v_b1 boolean[]; v_b2 boolean[]; v_txt text;
  v_admin uuid := '22222222-2222-2222-2222-222222222222';  -- compte sans rôle (seed) -> admin réseau en T15
  v_trace jsonb; v_audit2 bigint; v_hint4 text; v_hint5 text;
  -- seconde passe
  v_x bigint; v_h bigint; v_res3 jsonb; v_res4 jsonb; v_txt2 text; v_st text; v_st2 text;
  v_oid_idx oid; v_oid_tbl oid; v_gucs text[];
  v_i0 bigint; v_i1 bigint; v_i2 bigint; v_i3 bigint; v_s0 bigint; v_s1 bigint; v_s2 bigint; v_s3 bigint;
  -- troisième passe
  v_res5 jsonb; v_res6 jsonb; v_res7 jsonb;
  -- quatrième passe
  v_res8 jsonb; v_txt3 text; v_x2 bigint; v_x3 bigint; v_ex bigint; v_row3 bigint;
  -- cinquième passe
  v_run2 bigint; v_run3 bigint; v_run4 bigint; v_row4 bigint; v_x4 bigint;
  v_res9 jsonb; v_res10 jsonb; v_hint6 text; v_hint7 text;
  v_etat0 text; v_etat1 text; v_q0 bigint; v_q1 bigint; v_q2 bigint; v_ok2 boolean;
BEGIN
  -- ── Décor (postgres) ────────────────────────────────────────────────
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  INSERT INTO public.catalog_ref_source_partners (code, label, sort_order, is_active)
  VALUES ('other_partner', 'Outro parceiro', 80, true) ON CONFLICT (code) DO NOTHING;
  -- une seconde bibliothèque, et une personne staff de BLMF ET d'elle (T2)
  INSERT INTO public.libraries (id, slug, name, is_active, visibility_level)
  VALUES (gen_random_uuid(), 'essai-h21a-b', 'Essai H21A — B', true, 'private') RETURNING id INTO v_libB;
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'h21a-multi-' || gen_random_uuid() || '@example.invalid', now(), now())
  RETURNING id INTO v_multi;
  INSERT INTO public.profiles (id, first_name, last_name) VALUES (v_multi, 'Essai', 'H21A') ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary) VALUES
    (v_multi, v_lib, 'librarian', 'active', true),
    (v_multi, v_libB, 'librarian', 'active', false);
  -- une source « catalogue propre » de BLMF ; chaque test promeut son propre
  -- run (IMP-27 d : une nouvelle sélection d'un run rejoindrait son lot)
  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('H21A Essai revision du brouillon', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO v_src;

  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 « Sans lot » : un brouillon importe sorti de son lot ne se publie pas, rien n''est publie';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21a-t1.marc', 'h21a-t1.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 1, 'H21A-T1', 'H21A Sans lot', 'new_record', 'accept_new');
    v_lot := (public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
    SELECT m.draft_id INTO v_d FROM ingest.partner_catalog_row_to_draft m WHERE m.run_id = v_run;
    UPDATE public.book_drafts SET bib_ref = 'H21A-T1' WHERE id = v_d;
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET batch_id = NULL WHERE id = v_d;
    EXECUTE 'RESET ROLE';
    IF v_lot IS NULL OR (SELECT batch_id FROM public.book_drafts WHERE id = v_d) IS NOT NULL THEN
      RAISE EXCEPTION 'decor : lot=% brouillon toujours range', v_lot;
    END IF;
    v_hint := NULL;
    BEGIN PERFORM public.publish_book_draft(v_d); v_hint := 'publiee';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    IF v_hint = 'error.publish.imported_needs_batch'
       AND NOT EXISTS (SELECT 1 FROM public.books WHERE bib_ref = 'H21A-T1')
       AND (SELECT status FROM public.book_drafts WHERE id = v_d) = 'draft'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint='||coalesce(v_hint,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 ──────────────────────────────────────────────────────────────
  v_t := 'T2 changement de bibliotheque par une personne staff des deux : sorti du lot par le declencheur, meme refus';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21a-t2.marc', 'h21a-t2.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 1, 'H21A-T2', 'H21A Changee de bibliotheque', 'new_record', 'accept_new');
    v_lot := (public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
    SELECT m.draft_id INTO v_d FROM ingest.partner_catalog_row_to_draft m WHERE m.run_id = v_run;
    UPDATE public.book_drafts SET bib_ref = 'H21A-T2' WHERE id = v_d;
    -- la personne « multi » la passe à B, sans toucher au lot (seule owner_library_id dans le SET)
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_multi, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET owner_library_id = v_libB WHERE id = v_d;
    EXECUTE 'RESET ROLE';
    IF (SELECT owner_library_id FROM public.book_drafts WHERE id = v_d) IS DISTINCT FROM v_libB
       OR (SELECT batch_id FROM public.book_drafts WHERE id = v_d) IS NOT NULL THEN
      RAISE EXCEPTION 'decor : bibliotheque=% lot=%', (SELECT owner_library_id FROM public.book_drafts WHERE id = v_d),
                                                       (SELECT batch_id FROM public.book_drafts WHERE id = v_d);
    END IF;
    v_hint := NULL;
    BEGIN PERFORM public.publish_book_draft(v_d); v_hint := 'publiee';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    IF v_hint = 'error.publish.imported_needs_batch'
       AND NOT EXISTS (SELECT 1 FROM public.books WHERE bib_ref = 'H21A-T2')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint='||coalesce(v_hint,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 lot supprime (seul le brouillon jete y restait), brouillon restaure : meme refus';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21a-t3.marc', 'h21a-t3.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 1, 'H21A-T3', 'H21A Lot supprime', 'new_record', 'accept_new');
    v_lot := (public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
    SELECT m.draft_id INTO v_d FROM ingest.partner_catalog_row_to_draft m WHERE m.run_id = v_run;
    UPDATE public.book_drafts SET bib_ref = 'H21A-T3' WHERE id = v_d;
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET status = 'cancelled' WHERE id = v_d;     -- à la corbeille
    DELETE FROM public.catalog_batches WHERE id = v_lot;                    -- « Supprimer le lot »
    GET DIAGNOSTICS v_n = ROW_COUNT;
    UPDATE public.book_drafts SET status = 'draft' WHERE id = v_d;         -- restauration
    EXECUTE 'RESET ROLE';
    IF v_n <> 1 OR EXISTS (SELECT 1 FROM public.catalog_batches WHERE id = v_lot)
       OR (SELECT batch_id FROM public.book_drafts WHERE id = v_d) IS NOT NULL
       OR (SELECT status FROM public.book_drafts WHERE id = v_d) <> 'draft' THEN
      RAISE EXCEPTION 'decor : lot supprime=% brouillon=%', v_n,
        (SELECT row(batch_id, status)::text FROM public.book_drafts WHERE id = v_d);
    END IF;
    v_hint := NULL;
    BEGIN PERFORM public.publish_book_draft(v_d); v_hint := 'publiee';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    IF v_hint = 'error.publish.imported_needs_batch'
       AND NOT EXISTS (SELECT 1 FROM public.books WHERE bib_ref = 'H21A-T3')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint='||coalesce(v_hint,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 ──────────────────────────────────────────────────────────────
  v_t := 'T4 range dans un lot fait a la main, provenance videe : lot importe, review_required, revision demandee';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21a-t4.marc', 'h21a-t4.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 1, 'H21A-T4', 'H21A Rangee a la main', 'new_record', 'accept_new');
    v_lot := (public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
    SELECT m.draft_id INTO v_d FROM ingest.partner_catalog_row_to_draft m WHERE m.run_id = v_run;
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('H21A lot a la main T4', v_coord, v_lib) RETURNING id INTO v_main;
    -- l'API écrit partner_source et import_method : on les vide, dans la
    -- colonne ET dans marc_json.anarbib_provenance (le déclencheur-pont les
    -- remettrait sinon depuis l'autre côté)
    UPDATE public.book_drafts
       SET bib_ref = 'H21A-T4', partner_source = NULL, import_method = NULL,
           marc_json = coalesce(marc_json, '{}'::jsonb) #- '{anarbib_provenance,partner_source}' #- '{anarbib_provenance,import_method}'
     WHERE id = v_d;
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET batch_id = v_main WHERE id = v_d;
    EXECUTE 'RESET ROLE';
    IF (SELECT batch_id FROM public.book_drafts WHERE id = v_d) IS DISTINCT FROM v_main
       OR (SELECT partner_source IS NOT NULL OR import_method IS NOT NULL
                  OR marc_json->'anarbib_provenance' ? 'partner_source'
             FROM public.book_drafts WHERE id = v_d) THEN
      RAISE EXCEPTION 'decor : brouillon=%', (SELECT row(batch_id, partner_source, import_method)::text FROM public.book_drafts WHERE id = v_d);
    END IF;
    v_ok := public.fn_batch_is_imported(v_main);
    v_hint := NULL;
    BEGIN PERFORM public.publish_book_draft(v_d); v_hint := 'publiee';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    v_hint2 := NULL;
    BEGIN v_res := public.fn_batch_review_request(v_main, 'H21A : lot fait a la main, brouillon importe');
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint2 = PG_EXCEPTION_HINT; END;
    IF v_ok AND v_hint = 'error.publish.review_required'
       AND NOT EXISTS (SELECT 1 FROM public.books WHERE bib_ref = 'H21A-T4')
       AND v_hint2 IS NULL AND (v_res->>'round')::int = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : lot importe='||coalesce(v_ok::text,'NULL')
         ||' publication='||coalesce(v_hint,'NULL')||' demande='||coalesce(v_hint2, coalesce(v_res::text,'NULL'))); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T5 ──────────────────────────────────────────────────────────────
  v_t := 'T5 lien perdu (suppression definitive, run supprime, rejeu du journal), trace gardee : review_required dans le lot, imported_needs_batch hors lot';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21a-t5.marc', 'h21a-t5.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 1, 'H21A-T5', 'H21A Supprimee puis rejouee', 'new_record', 'accept_new');
    v_lot := (public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
    SELECT m.draft_id INTO v_d FROM ingest.partner_catalog_row_to_draft m WHERE m.run_id = v_run;
    UPDATE public.book_drafts
       SET bib_ref = 'H21A-T5', partner_source = NULL, import_method = NULL,
           marc_json = coalesce(marc_json, '{}'::jsonb) #- '{anarbib_provenance,partner_source}' #- '{anarbib_provenance,import_method}'
     WHERE id = v_d;
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET status = 'cancelled' WHERE id = v_d;
    DELETE FROM public.book_drafts WHERE id = v_d;                          -- « Vider la corbeille »
    EXECUTE 'RESET ROLE';
    -- « Supprimer le run » : plus rien ne le retient ; lignes et liens partent
    -- avec lui (le rejeu, sinon, rendrait sa ligne au brouillon : T10)
    v_res2 := public.fn_import_delete_run(v_run);
    SELECT max(l.id) INTO v_audit FROM public.catalog_audit_log l
     WHERE l.action = 'delete' AND l.entity_type = 'book' AND l.entity_id = v_d;
    v_res := public.fn_restore_deleted_draft(v_audit);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET status = 'draft' WHERE id = v_d;         -- sortie de corbeille
    EXECUTE 'RESET ROLE';
    IF NOT coalesce((v_res2->>'ok')::boolean, false)
       OR EXISTS (SELECT 1 FROM ingest.partner_catalog_import_runs WHERE id = v_run)
       OR (SELECT batch_id FROM public.book_drafts WHERE id = v_d) IS DISTINCT FROM v_lot
       OR EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft m WHERE m.draft_id = v_d)
       OR NOT (SELECT marc_json ? 'ingest' AND partner_source IS NULL AND published_book_id IS NULL
                 FROM public.book_drafts WHERE id = v_d) THEN
      RAISE EXCEPTION 'decor : run=% rejeu=% brouillon=%', v_res2, v_res,
        (SELECT row(batch_id, status, partner_source)::text FROM public.book_drafts WHERE id = v_d);
    END IF;
    v_hint := NULL;
    BEGIN PERFORM public.publish_book_draft(v_d); v_hint := 'publiee';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET batch_id = NULL WHERE id = v_d;           -- « Sans lot »
    EXECUTE 'RESET ROLE';
    v_hint2 := NULL;
    BEGIN PERFORM public.publish_book_draft(v_d); v_hint2 := 'publiee';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint2 = PG_EXCEPTION_HINT; END;
    IF v_hint = 'error.publish.review_required' AND v_hint2 = 'error.publish.imported_needs_batch'
       AND NOT EXISTS (SELECT 1 FROM public.books WHERE bib_ref = 'H21A-T5')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : dans le lot='||coalesce(v_hint,'NULL')||' hors lot='||coalesce(v_hint2,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T6 ──────────────────────────────────────────────────────────────
  v_t := 'T6 trace sans lien (creation) : review_required dans un lot fait a la main, imported_needs_batch hors lot';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('H21A lot a la main T6', v_coord, v_lib) RETURNING id INTO v_main;
    INSERT INTO public.book_drafts (action, status, titulo, tipo_material, bib_ref, owner_library_id, created_by, batch_id, marc_json)
    VALUES ('create', 'draft', 'H21A Trace sans lien', 'livro', 'H21A-T6', v_lib, v_coord, v_main,
            jsonb_build_object('ingest', jsonb_build_object('source_id', v_src, 'row_no', 1, 'partner_name', 'H21A')))
    RETURNING id INTO v_d;
    IF (SELECT partner_source FROM public.book_drafts WHERE id = v_d) IS NOT NULL THEN RAISE EXCEPTION 'decor : partner_source pose'; END IF;
    v_hint := NULL;
    BEGIN PERFORM public.publish_book_draft(v_d); v_hint := 'publiee';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET batch_id = NULL WHERE id = v_d;
    EXECUTE 'RESET ROLE';
    v_hint2 := NULL;
    BEGIN PERFORM public.publish_book_draft(v_d); v_hint2 := 'publiee';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint2 = PG_EXCEPTION_HINT; END;
    IF v_hint = 'error.publish.review_required' AND v_hint2 = 'error.publish.imported_needs_batch'
       AND NOT EXISTS (SELECT 1 FROM public.books WHERE bib_ref = 'H21A-T6')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : dans le lot='||coalesce(v_hint,'NULL')||' hors lot='||coalesce(v_hint2,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T7 ──────────────────────────────────────────────────────────────
  v_t := 'T7 non-regression : une reprise (published_book_id pose, trace recopiee) n''est pas gardee, hors lot et dans un lot a la main';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    -- une notice publiée d'un import : sa trace et son partner_source passent au brouillon de reprise
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id, partner_source, marc_json)
    VALUES ('H21A Notice importee publiee', 'H21A-T7', 'livro', v_lib, 'other_partner',
            jsonb_build_object('ingest', jsonb_build_object('source_id', v_src, 'row_no', 7)))
    RETURNING id INTO v_book;
    v_d := public.create_book_draft_from_book(v_book, NULL);
    IF NOT (SELECT published_book_id = v_book AND marc_json ? 'ingest' AND partner_source IS NOT NULL
              FROM public.book_drafts WHERE id = v_d) THEN
      RAISE EXCEPTION 'decor : la reprise ne porte pas la trace de sa notice';
    END IF;
    v_ok := NOT public.fn_book_draft_is_imported(v_d);
    v_hint := NULL;
    BEGIN v_book2 := public.publish_book_draft(v_d);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_hint := coalesce(v_hint, SQLERRM); END;
    -- une seconde reprise, rangée dans un lot fait à la main, partner_source vidé
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('H21A lot a la main T7', v_coord, v_lib) RETURNING id INTO v_main;
    v_d2 := public.create_book_draft_from_book(v_book, v_main);
    UPDATE public.book_drafts
       SET partner_source = NULL, import_method = NULL,
           marc_json = coalesce(marc_json, '{}'::jsonb) #- '{anarbib_provenance,partner_source}' #- '{anarbib_provenance,import_method}'
     WHERE id = v_d2;
    v_ok := v_ok AND NOT public.fn_book_draft_is_imported(v_d2) AND NOT public.fn_batch_is_imported(v_main);
    v_hint2 := NULL;
    BEGIN v_res := to_jsonb(public.publish_book_draft(v_d2));
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint2 = PG_EXCEPTION_HINT; v_hint2 := coalesce(v_hint2, SQLERRM); END;
    IF v_ok AND v_hint IS NULL AND v_book2 = v_book AND v_hint2 IS NULL AND (v_res #>> '{}')::bigint = v_book
       AND (SELECT status FROM public.book_drafts WHERE id = v_d2) = 'published'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : predicats='||coalesce(v_ok::text,'NULL')
         ||' hors lot='||coalesce(v_hint,'publiee')||' dans le lot='||coalesce(v_hint2,'publiee')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T8 ──────────────────────────────────────────────────────────────
  v_t := 'T8 non-regression : un brouillon fait a la main se publie hors lot et dans un lot fait a la main';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('H21A lot a la main T8', v_coord, v_lib) RETURNING id INTO v_main;
    INSERT INTO public.book_drafts (action, status, titulo, tipo_material, bib_ref, owner_library_id, created_by)
    VALUES ('create', 'draft', 'H21A Faite a la main, hors lot', 'livro', 'H21A-T8-1', v_lib, v_coord) RETURNING id INTO v_d;
    INSERT INTO public.book_drafts (action, status, titulo, tipo_material, bib_ref, owner_library_id, created_by, batch_id)
    VALUES ('create', 'draft', 'H21A Faite a la main, dans un lot', 'livro', 'H21A-T8-2', v_lib, v_coord, v_main) RETURNING id INTO v_d2;
    v_ok := NOT public.fn_book_draft_is_imported(v_d) AND NOT public.fn_book_draft_is_imported(v_d2)
            AND NOT public.fn_batch_is_imported(v_main);
    v_hint := NULL;
    BEGIN PERFORM public.publish_book_draft(v_d);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_hint := coalesce(v_hint, SQLERRM); END;
    v_hint2 := NULL;
    BEGIN PERFORM public.publish_book_draft(v_d2);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint2 = PG_EXCEPTION_HINT; v_hint2 := coalesce(v_hint2, SQLERRM); END;
    IF v_ok AND v_hint IS NULL AND v_hint2 IS NULL
       AND (SELECT count(*) FROM public.books WHERE bib_ref IN ('H21A-T8-1', 'H21A-T8-2')) = 2
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : predicats='||coalesce(v_ok::text,'NULL')
         ||' hors lot='||coalesce(v_hint,'publiee')||' dans le lot='||coalesce(v_hint2,'publiee')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T9 ──────────────────────────────────────────────────────────────
  v_t := 'T9 fn_batch_is_imported(lot) = fn_book_draft_is_imported(brouillon) pour cinq formes, partner_source nul';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21a-t9.marc', 'h21a-t9.marc', 'marc_iso2709', 'drafts_created') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
    VALUES (v_run, 1, 'H21A-T9-1', 'H21A Liee en cours', 'new_record', 'accept_new', 'draft_created') RETURNING id INTO v_row;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status)
    VALUES (v_run, 2, 'H21A-T9-2', 'H21A Liee publiee', 'new_record', 'accept_new', 'draft_created') RETURNING id INTO v_row2;
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id) VALUES ('H21A Publiee depuis l''import', 'H21A-T9-2', 'livro', v_lib) RETURNING id INTO v_book;
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id) VALUES ('H21A Notice reprise', 'H21A-T9-4', 'livro', v_lib) RETURNING id INTO v_book2;
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('H21A T9 lie en cours', v_coord, v_lib) RETURNING id INTO v_l1;
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('H21A T9 lie publie', v_coord, v_lib) RETURNING id INTO v_l2;
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('H21A T9 trace sans lien', v_coord, v_lib) RETURNING id INTO v_l3;
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('H21A T9 reprise tracee', v_coord, v_lib) RETURNING id INTO v_l4;
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('H21A T9 a la main', v_coord, v_lib) RETURNING id INTO v_l5;
    -- (1) liée, en cours : sortie de son lot d'origine (le lien ne dit plus de lot)
    INSERT INTO public.book_drafts (action, status, titulo, tipo_material, owner_library_id, created_by, batch_id, marc_json)
    VALUES ('create', 'draft', 'H21A Liee en cours', 'livro', v_lib, v_coord, v_l1,
            jsonb_build_object('ingest', jsonb_build_object('run_id', v_run, 'staging_row_id', v_row))) RETURNING id INTO v_d1;
    INSERT INTO ingest.partner_catalog_row_to_draft (staging_row_id, run_id, draft_id, batch_id) VALUES (v_row, v_run, v_d1, NULL);
    -- (2) liée, publiée
    INSERT INTO public.book_drafts (action, status, titulo, tipo_material, owner_library_id, created_by, batch_id, published_book_id, marc_json)
    VALUES ('create', 'published', 'H21A Liee publiee', 'livro', v_lib, v_coord, v_l2, v_book,
            jsonb_build_object('ingest', jsonb_build_object('run_id', v_run, 'staging_row_id', v_row2))) RETURNING id INTO v_d;
    INSERT INTO ingest.partner_catalog_row_to_draft (staging_row_id, run_id, draft_id, batch_id) VALUES (v_row2, v_run, v_d, NULL);
    -- (3) création tracée, sans lien
    INSERT INTO public.book_drafts (action, status, titulo, tipo_material, owner_library_id, created_by, batch_id, marc_json)
    VALUES ('create', 'draft', 'H21A Tracee sans lien', 'livro', v_lib, v_coord, v_l3,
            jsonb_build_object('ingest', jsonb_build_object('source_id', v_src, 'row_no', 3))) RETURNING id INTO v_d3;
    -- (4) reprise tracée : published_book_id posé, trace recopiée de sa notice
    INSERT INTO public.book_drafts (action, status, titulo, tipo_material, owner_library_id, created_by, batch_id, published_book_id, marc_json)
    VALUES ('update', 'draft', 'H21A Reprise tracee', 'livro', v_lib, v_coord, v_l4, v_book2,
            jsonb_build_object('ingest', jsonb_build_object('source_id', v_src, 'row_no', 4))) RETURNING id INTO v_d4;
    -- (5) faite à la main
    INSERT INTO public.book_drafts (action, status, titulo, tipo_material, owner_library_id, created_by, batch_id)
    VALUES ('create', 'draft', 'H21A A la main', 'livro', v_lib, v_coord, v_l5) RETURNING id INTO v_d5;
    IF EXISTS (SELECT 1 FROM public.book_drafts WHERE id IN (v_d1, v_d, v_d3, v_d4, v_d5)
                AND (partner_source IS NOT NULL OR import_method IS NOT NULL)) THEN
      RAISE EXCEPTION 'decor : partner_source ou import_method pose';
    END IF;
    v_b1 := ARRAY[public.fn_batch_is_imported(v_l1), public.fn_batch_is_imported(v_l2), public.fn_batch_is_imported(v_l3),
                  public.fn_batch_is_imported(v_l4), public.fn_batch_is_imported(v_l5)];
    v_b2 := ARRAY[public.fn_book_draft_is_imported(v_d1), public.fn_book_draft_is_imported(v_d), public.fn_book_draft_is_imported(v_d3),
                  public.fn_book_draft_is_imported(v_d4), public.fn_book_draft_is_imported(v_d5)];
    IF v_b1 = v_b2 AND v_b2 = ARRAY[true, true, true, false, false]
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : lots='||v_b1::text||' brouillons='||v_b2::text||' (attendu {t,t,t,f,f})'); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T10 ─────────────────────────────────────────────────────────────
  v_t := 'T10 (e) suppression definitive d''un brouillon importe : ligne ecartee, pas recreee ; le rejeu la rend au brouillon, une seule notice';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21a-t10.marc', 'h21a-t10.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 1, 'H21A-T10-1', 'H21A Supprimee definitivement', 'new_record', 'accept_new') RETURNING id INTO v_row;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 2, 'H21A-T10-2', 'H21A Gardee', 'new_record', 'accept_new') RETURNING id INTO v_row2;
    v_lot := (public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
    SELECT m.draft_id INTO v_d  FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row;
    SELECT m.draft_id INTO v_d2 FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row2;
    IF v_d IS NULL OR v_d2 IS NULL THEN RAISE EXCEPTION 'decor : promotion incomplete (lot %)', v_lot; END IF;
    -- corbeille puis « Vider la corbeille », par la coordination, sous le rôle de l'API
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET status = 'cancelled' WHERE id = v_d;
    DELETE FROM public.book_drafts WHERE id = v_d;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    EXECUTE 'RESET ROLE';
    SELECT concat_ws(' ',
             CASE WHEN v_n <> 1 THEN 'suppression='||v_n END,
             CASE WHEN sr.editorial_decision IS DISTINCT FROM 'reject' THEN 'decision='||coalesce(sr.editorial_decision,'NULL') END,
             CASE WHEN sr.review_status IS DISTINCT FROM 'rejected' THEN 'revue='||coalesce(sr.review_status,'NULL') END,
             CASE WHEN sr.selected_for_draft IS DISTINCT FROM false THEN 'selectionnee' END,
             CASE WHEN sr.created_book_draft_id IS NOT NULL THEN 'brouillon_cree='||sr.created_book_draft_id END,
             CASE WHEN coalesce(sr.editorial_note, '') NOT LIKE '%' || v_d || '%IMP-27 e%' THEN 'note='||coalesce(sr.editorial_note,'NULL') END,
             CASE WHEN sr.editorial_decided_by IS DISTINCT FROM v_coord THEN 'decide_par' END,
             -- troisième passe : la ligne garde QUEL brouillon l'a libérée
             CASE WHEN sr.discarded_draft_id IS DISTINCT FROM v_d THEN 'ecartee_par='||coalesce(sr.discarded_draft_id::text,'NULL') END,
             CASE WHEN EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row) THEN 'lien' END)
      INTO v_txt
      FROM ingest.partner_catalog_staging_rows sr WHERE sr.id = v_row;
    -- l'autre ligne du run n'est pas touchée
    IF NOT (SELECT editorial_decision = 'accept_new' AND review_status = 'draft_created' AND created_book_draft_id = v_d2
              FROM ingest.partner_catalog_staging_rows WHERE id = v_row2) THEN
      v_txt := v_txt || ' autre_ligne_touchee';
    END IF;
    -- « Promouvoir » à nouveau : la ligne écartée ne revient pas
    v_res := public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new']);
    SELECT count(*) INTO v_m FROM public.book_drafts d WHERE d.marc_json->'ingest'->>'staging_row_id' = v_row::text;
    -- le journal rejoue l'ancien brouillon : une seule notice pour la ligne, et
    -- la ligne lui revient (décision reverrouillée, preuve d'écartement vidée,
    -- lien rétabli SANS lot : le lot de la promotion n'est plus connu ; le
    -- brouillon, lui, revient dans son lot)
    SELECT max(l.id) INTO v_audit FROM public.catalog_audit_log l
     WHERE l.action = 'delete' AND l.entity_type = 'book' AND l.entity_id = v_d;
    v_res2 := public.fn_restore_deleted_draft(v_audit);
    SELECT count(*) INTO v_k FROM public.book_drafts d WHERE d.marc_json->'ingest'->>'staging_row_id' = v_row::text;
    SELECT concat_ws(' ',
             CASE WHEN sr.created_book_draft_id IS DISTINCT FROM v_d THEN 'brouillon_cree='||coalesce(sr.created_book_draft_id::text,'NULL') END,
             CASE WHEN sr.editorial_decision IS DISTINCT FROM 'accept_new' THEN 'decision='||coalesce(sr.editorial_decision,'NULL') END,
             CASE WHEN sr.review_status IS DISTINCT FROM 'draft_created' THEN 'revue='||coalesce(sr.review_status,'NULL') END,
             CASE WHEN sr.selected_for_draft IS DISTINCT FROM false THEN 'selectionnee' END,
             CASE WHEN coalesce(sr.editorial_note, '') NOT LIKE 'Rascunho ' || v_d || ' restaurado%IMP-27 e%' THEN 'note='||coalesce(sr.editorial_note,'NULL') END,
             CASE WHEN sr.editorial_decided_by IS DISTINCT FROM v_coord THEN 'decide_par' END,
             CASE WHEN sr.discarded_draft_id IS NOT NULL THEN 'ecartee_par='||sr.discarded_draft_id END,
             CASE WHEN (SELECT count(*) FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row) <> 1
                    OR NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft m
                                    WHERE m.staging_row_id = v_row AND m.draft_id = v_d AND m.run_id = v_run
                                      AND m.batch_id IS NULL)
                  THEN 'lien='||coalesce((SELECT string_agg(row(m.draft_id, m.batch_id)::text, ',') FROM ingest.partner_catalog_row_to_draft m
                                           WHERE m.staging_row_id = v_row), 'aucun') END,
             CASE WHEN (SELECT batch_id FROM public.book_drafts WHERE id = v_d) IS DISTINCT FROM v_lot THEN 'lot' END)
      INTO v_txt2
      FROM ingest.partner_catalog_staging_rows sr WHERE sr.id = v_row;
    IF v_txt = '' AND coalesce((v_res->>'selected_count')::int, 0) = 0 AND v_res->>'batch_id' IS NULL
       AND v_m = 0 AND (v_res2->>'ok')::boolean AND v_k = 1 AND v_txt2 = ''
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : ligne=['||v_txt||'] repromotion='||left(coalesce(v_res::text,'NULL'), 200)
         ||' brouillons de la ligne avant rejeu='||v_m||' apres='||v_k||' ligne apres rejeu=['||coalesce(v_txt2,'absente')||']'); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T11 ─────────────────────────────────────────────────────────────
  v_t := 'T11 fn_import_delete_run : refus tant qu''un brouillon lie vit hors de son lot (rien de detruit), accepte a la corbeille';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21a-t11.marc', 'h21a-t11.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 1, 'H21A-T11-1', 'H21A Sortie sans lot', 'new_record', 'accept_new') RETURNING id INTO v_row;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 2, 'H21A-T11-2', 'H21A Rangee ailleurs', 'new_record', 'accept_new') RETURNING id INTO v_row2;
    v_lot := (public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
    SELECT m.draft_id INTO v_d  FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row;
    SELECT m.draft_id INTO v_d2 FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row2;
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('H21A lot a la main T11', v_coord, v_lib) RETURNING id INTO v_main;
    -- l'une « Sans lot » (draft), l'autre prête et rangée dans un lot fait à la main :
    -- le lot d'origine ne retient plus rien, le compte par lot ne les voit pas
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET batch_id = NULL WHERE id = v_d;
    UPDATE public.book_drafts SET status = 'ready', batch_id = v_main WHERE id = v_d2;
    EXECUTE 'RESET ROLE';
    IF (SELECT batch_id FROM public.book_drafts WHERE id = v_d) IS NOT NULL
       OR (SELECT batch_id FROM public.book_drafts WHERE id = v_d2) IS DISTINCT FROM v_main
       OR EXISTS (SELECT 1 FROM public.book_drafts WHERE batch_id = v_lot AND status <> 'cancelled') THEN
      RAISE EXCEPTION 'decor : rangements';
    END IF;
    v_hint := NULL;
    BEGIN PERFORM public.fn_import_delete_run(v_run); v_hint := 'supprime';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    -- non-action : le refus ne détruit rien
    v_ok := EXISTS (SELECT 1 FROM ingest.partner_catalog_import_runs WHERE id = v_run)
            AND (SELECT count(*) FROM ingest.partner_catalog_staging_rows WHERE run_id = v_run) = 2
            AND (SELECT count(*) FROM ingest.partner_catalog_row_to_draft WHERE run_id = v_run) = 2
            AND (SELECT count(*) FROM public.book_drafts WHERE id IN (v_d, v_d2) AND status IN ('draft', 'ready')) = 2
            AND EXISTS (SELECT 1 FROM public.catalog_batches WHERE id = v_lot);
    -- la première à la corbeille : la seconde retient encore le run
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET status = 'cancelled' WHERE id = v_d;
    EXECUTE 'RESET ROLE';
    v_hint2 := NULL;
    BEGIN PERFORM public.fn_import_delete_run(v_run); v_hint2 := 'supprime';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint2 = PG_EXCEPTION_HINT; END;
    -- les deux à la corbeille : le run part (action), les brouillons jetés restent
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET status = 'cancelled' WHERE id = v_d2;
    EXECUTE 'RESET ROLE';
    v_hint3 := NULL; v_res := NULL;
    BEGIN v_res := public.fn_import_delete_run(v_run);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint3 = PG_EXCEPTION_HINT; v_hint3 := coalesce(v_hint3, SQLERRM); END;
    IF v_hint = 'error.import.run_has_linked_drafts' AND v_ok
       AND v_hint2 = 'error.import.run_has_linked_drafts'
       AND v_hint3 IS NULL AND coalesce((v_res->>'ok')::boolean, false)
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_import_runs WHERE id = v_run)
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft WHERE run_id = v_run)
       AND (SELECT count(*) FROM public.book_drafts WHERE id IN (v_d, v_d2) AND status = 'cancelled') = 2
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : refus='||coalesce(v_hint,'NULL')||' rien detruit='||coalesce(v_ok::text,'NULL')
         ||' une a la corbeille='||coalesce(v_hint2,'NULL')||' les deux='||coalesce(v_hint3, coalesce(v_res::text,'NULL'))); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T12 ─────────────────────────────────────────────────────────────
  v_t := 'T12 droits : les quatre aides fermees a anon et authenticated, ouvertes a service_role';
  BEGIN
    SELECT string_agg(f, ' ') INTO v_txt
      FROM unnest(ARRAY['public.fn_book_draft_is_imported(bigint)', 'public.fn_batch_is_imported(bigint)',
                        'public.fn_batch_review_couvre(bigint, bigint, text)', 'public.fn_batch_ajouts_apres_revision(bigint)']) f
     WHERE has_function_privilege('anon', f, 'EXECUTE') OR has_function_privilege('authenticated', f, 'EXECUTE')
        OR NOT has_function_privilege('service_role', f, 'EXECUTE');
    -- et par l'API, l'appel est refusé
    v_hint := NULL;
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN PERFORM public.fn_book_draft_is_imported(0); v_hint := 'execute';
    EXCEPTION WHEN insufficient_privilege THEN v_hint := '42501'; END;
    EXECUTE 'RESET ROLE';
    IF v_txt IS NULL AND v_hint = '42501'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : droits en trop='||coalesce(v_txt,'aucun')||' appel API='||coalesce(v_hint,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T13 ─────────────────────────────────────────────────────────────
  v_t := 'T13 (a) la trace d''import ne s''efface ni ne se reecrit par l''API ; sortie du lot : imported_needs_batch';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    -- une création tracée sans lien (run supprimé, rejeu du journal) : la trace
    -- est sa SEULE preuve d'import
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('H21A lot a la main T13', v_coord, v_lib) RETURNING id INTO v_main;
    INSERT INTO public.book_drafts (action, status, titulo, tipo_material, bib_ref, owner_library_id, created_by, batch_id, marc_json)
    VALUES ('create', 'draft', 'H21A Trace effacee par l''API', 'livro', 'H21A-T13', v_lib, v_coord, v_main,
            jsonb_build_object('ingest', jsonb_build_object('source_id', v_src, 'row_no', 13, 'partner_name', 'H21A')))
    RETURNING id INTO v_d;
    SELECT marc_json->'ingest' INTO v_trace FROM public.book_drafts WHERE id = v_d;
    v_txt := '';
    -- (1) trace réécrite, (2) marc_json vidé
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET marc_json = jsonb_set(coalesce(marc_json, '{}'::jsonb), '{ingest}', '{"source_id": 0, "row_no": 0}'::jsonb) WHERE id = v_d;
    EXECUTE 'RESET ROLE';
    IF (SELECT marc_json->'ingest' FROM public.book_drafts WHERE id = v_d) IS DISTINCT FROM v_trace THEN
      v_txt := v_txt || ' trace_reecrite=' || coalesce((SELECT marc_json->'ingest' FROM public.book_drafts WHERE id = v_d)::text, 'absente');
    END IF;
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET marc_json = NULL WHERE id = v_d;
    EXECUTE 'RESET ROLE';
    IF (SELECT marc_json->'ingest' FROM public.book_drafts WHERE id = v_d) IS DISTINCT FROM v_trace THEN
      v_txt := v_txt || ' trace_videe=' || coalesce((SELECT marc_json->'ingest' FROM public.book_drafts WHERE id = v_d)::text, 'absente');
    END IF;
    -- (3) en dernier, le geste du formulaire : le brouillon renvoyé sans la
    -- trace (marc_json - 'ingest'), avec une autre retouche, qui reste
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET marc_json = (coalesce(marc_json, '{}'::jsonb) - 'ingest') || '{"h21a_retouche": "gardee"}'::jsonb WHERE id = v_d;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    EXECUTE 'RESET ROLE';
    IF v_n <> 1 THEN v_txt := v_txt || ' ecriture=' || v_n; END IF;
    IF (SELECT marc_json->'ingest' FROM public.book_drafts WHERE id = v_d) IS DISTINCT FROM v_trace THEN
      v_txt := v_txt || ' trace_otee=' || coalesce((SELECT marc_json->'ingest' FROM public.book_drafts WHERE id = v_d)::text, 'absente');
    END IF;
    IF (SELECT marc_json->>'h21a_retouche' FROM public.book_drafts WHERE id = v_d) IS DISTINCT FROM 'gardee' THEN
      v_txt := v_txt || ' retouche_perdue';
    END IF;
    -- puis « Sans lot »
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET batch_id = NULL WHERE id = v_d;
    EXECUTE 'RESET ROLE';
    IF (SELECT batch_id FROM public.book_drafts WHERE id = v_d) IS NOT NULL THEN RAISE EXCEPTION 'decor : brouillon toujours range'; END IF;
    v_hint := NULL;
    BEGIN PERFORM public.publish_book_draft(v_d); v_hint := 'publiee';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    IF v_txt = '' AND v_hint = 'error.publish.imported_needs_batch'
       AND public.fn_book_draft_is_imported(v_d)
       AND NOT EXISTS (SELECT 1 FROM public.books WHERE bib_ref = 'H21A-T13')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : ['||v_txt||' ] hors lot='||coalesce(v_hint,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T14 ─────────────────────────────────────────────────────────────
  v_t := 'T14 (a) par l''API une creation tracee ne devient pas une reprise : published_book_id reste NULL, la notice n''est pas touchee';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    -- une notice de BLMF, déjà au catalogue
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
    VALUES ('H21A Notice de BLMF T14', 'H21A-T14-N', 'livro', v_lib) RETURNING id INTO v_book;
    INSERT INTO public.book_drafts (action, status, titulo, tipo_material, bib_ref, owner_library_id, created_by, marc_json)
    VALUES ('create', 'draft', 'H21A Creation tracee T14', 'livro', 'H21A-T14', v_lib, v_coord,
            jsonb_build_object('ingest', jsonb_build_object('source_id', v_src, 'row_no', 14, 'partner_name', 'H21A')))
    RETURNING id INTO v_d;
    -- le brouillon « pointé » sur la notice, avec une retouche dans le même UPDATE
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET published_book_id = v_book, titulo = 'H21A Creation tracee T14, retouchee' WHERE id = v_d;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    EXECUTE 'RESET ROLE';
    v_ok := public.fn_book_draft_is_imported(v_d);
    -- hors lot : la publication refuse ; une reprise aurait réécrit la notice
    v_hint := NULL;
    BEGIN PERFORM public.publish_book_draft(v_d); v_hint := 'publiee';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    IF v_n = 1
       AND (SELECT published_book_id IS NULL AND titulo = 'H21A Creation tracee T14, retouchee' FROM public.book_drafts WHERE id = v_d)
       AND v_ok AND v_hint = 'error.publish.imported_needs_batch'
       AND (SELECT titulo FROM public.books WHERE id = v_book) = 'H21A Notice de BLMF T14'
       AND NOT EXISTS (SELECT 1 FROM public.books WHERE bib_ref = 'H21A-T14')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : ecriture='||v_n
         ||' brouillon='||coalesce((SELECT row(published_book_id, titulo)::text FROM public.book_drafts WHERE id = v_d), 'NULL')
         ||' importe='||coalesce(v_ok::text,'NULL')||' publication='||coalesce(v_hint,'NULL')
         ||' notice='||coalesce((SELECT titulo FROM public.books WHERE id = v_book), 'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T15 ─────────────────────────────────────────────────────────────
  v_t := 'T15 non-regression (a) : appelees par l''API, les fonctions DEFINER posent la trace (promotion, reprise) et published_book_id (publication)';
  BEGIN
    INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active') ON CONFLICT DO NOTHING;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21a-t15.marc', 'h21a-t15.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 1, 'H21A-T15', 'H21A Publiee apres revision', 'new_record', 'accept_new') RETURNING id INTO v_row;
    -- tout par l'API : SET LOCAL ROLE authenticated, le déclencheur juge chaque écriture
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_lot := (public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
    EXECUTE 'RESET ROLE';
    SELECT m.draft_id INTO v_d FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row;
    SELECT marc_json->'ingest' INTO v_trace FROM public.book_drafts WHERE id = v_d;
    IF v_d IS NULL OR (v_trace->>'staging_row_id') IS DISTINCT FROM v_row::text THEN
      RAISE EXCEPTION 'decor : promotion sans trace (brouillon %, trace %)', v_d, v_trace;
    END IF;
    UPDATE public.book_drafts SET bib_ref = 'H21A-T15', tipo_material = 'livro' WHERE id = v_d;   -- la cote (postgres)
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_res := public.fn_batch_review_request(v_lot, 'H21A T15 : trace figee, publication');
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', NULL);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_book := NULL; v_d2 := NULL;
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_book := public.publish_book_draft(v_d);
    -- « Éditer » la notice publiée : une reprise, trace recopiée de la notice
    v_d2 := public.create_book_draft_from_book(v_book, NULL);
    EXECUTE 'RESET ROLE';
    IF v_book IS NOT NULL
       AND (SELECT status = 'published' AND published_book_id = v_book AND marc_json->'ingest' = v_trace
              FROM public.book_drafts WHERE id = v_d)
       AND EXISTS (SELECT 1 FROM public.books WHERE id = v_book AND bib_ref = 'H21A-T15')
       AND (SELECT published_book_id = v_book AND marc_json->'ingest' = v_trace
              FROM public.book_drafts WHERE id = v_d2)
       AND NOT public.fn_book_draft_is_imported(v_d2)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : notice='||coalesce(v_book::text,'NULL')
         ||' publie='||coalesce((SELECT row(status, published_book_id, marc_json->'ingest' = v_trace)::text FROM public.book_drafts WHERE id = v_d), 'NULL')
         ||' reprise='||coalesce((SELECT row(published_book_id, marc_json->'ingest' = v_trace)::text FROM public.book_drafts WHERE id = v_d2), 'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    EXECUTE 'RESET ROLE';
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'')||' '||SQLERRM);
  END;

  -- ── T16 ─────────────────────────────────────────────────────────────
  v_t := 'T16 non-regression (a) : sur un brouillon fait a la main, marc_json et published_book_id restent modifiables par l''API';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
    VALUES ('H21A Notice de BLMF T16', 'H21A-T16-N', 'livro', v_lib) RETURNING id INTO v_book;
    INSERT INTO public.book_drafts (action, status, titulo, tipo_material, bib_ref, owner_library_id, created_by)
    VALUES ('create', 'draft', 'H21A Faite a la main T16', 'livro', 'H21A-T16', v_lib, v_coord) RETURNING id INTO v_d;
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts
       SET marc_json = coalesce(marc_json, '{}'::jsonb) || '{"h21a_retouche": "posee"}'::jsonb, published_book_id = v_book
     WHERE id = v_d;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    EXECUTE 'RESET ROLE';
    IF v_n = 1
       AND (SELECT published_book_id = v_book AND marc_json->>'h21a_retouche' = 'posee' FROM public.book_drafts WHERE id = v_d)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : ecriture='||v_n||' brouillon='
         ||coalesce((SELECT row(published_book_id, marc_json)::text FROM public.book_drafts WHERE id = v_d), 'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T17 ─────────────────────────────────────────────────────────────
  v_t := 'T17 (e) par l''API aucune decision ne releve une ligne ecartee ; repromue (en postgres), le journal ne rejoue pas l''ancien brouillon ; jamais repromue, il la reprend';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21a-t17.marc', 'h21a-t17.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 1, 'H21A-T17-1', 'H21A Repromue (en postgres)', 'new_record', 'accept_new') RETURNING id INTO v_row;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 2, 'H21A-T17-2', 'H21A Ecartee, jamais repromue', 'new_record', 'accept_new') RETURNING id INTO v_row2;
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_lot := (public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
    EXECUTE 'RESET ROLE';
    SELECT m.draft_id INTO v_d  FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row;
    SELECT m.draft_id INTO v_d2 FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row2;
    -- corbeille puis « Vider la corbeille » : les deux lignes écartées (T10)
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET status = 'cancelled' WHERE id IN (v_d, v_d2);
    DELETE FROM public.book_drafts WHERE id IN (v_d, v_d2);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    -- (0) quatrième passe : par l'API, AUCUNE décision ne relève une ligne
    --     écartée — « En attente », « Accepté (nouveau) », « Rejeté » avec une
    --     note : ignorées (skipped_rows) ; chaque ligne garde 'reject', la note
    --     du déclencheur et discarded_draft_id ; la promotion, de la sélection
    --     puis de tout le run, ne la reprend pas. La voie de la troisième passe
    --     (« En attente » puis « Accepté (nouveau) ») est donc fermée.
    v_res3 := public.fn_import_set_editorial(v_run, ARRAY[v_row, v_row2], 'pending', NULL);
    v_res4 := public.fn_import_set_editorial(v_run, ARRAY[v_row, v_row2], 'accept_new', NULL);
    v_res5 := public.fn_import_set_editorial(v_run, ARRAY[v_row, v_row2], 'reject', 'H21A T17 note posee par l''API');
    v_res6 := public.fn_import_promote(v_run, p_row_ids := ARRAY[v_row, v_row2]);
    v_res7 := public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new']);
    EXECUTE 'RESET ROLE';
    SELECT coalesce(string_agg(CASE WHEN q.e <> '' THEN 'ligne' || q.k || '[' || q.e || ']' END, ' '), '') INTO v_txt
      FROM (SELECT c.k, concat_ws(',',
                     CASE WHEN sr.editorial_decision IS DISTINCT FROM 'reject' OR sr.review_status IS DISTINCT FROM 'rejected'
                          THEN 'decision='||coalesce(sr.editorial_decision,'NULL')||'/'||coalesce(sr.review_status,'NULL') END,
                     CASE WHEN sr.selected_for_draft IS DISTINCT FROM false THEN 'selectionnee' END,
                     CASE WHEN sr.created_book_draft_id IS NOT NULL THEN 'cree='||sr.created_book_draft_id END,
                     CASE WHEN sr.discarded_draft_id IS DISTINCT FROM c.d THEN 'ecartee_par='||coalesce(sr.discarded_draft_id::text,'NULL') END,
                     CASE WHEN coalesce(sr.editorial_note, '') NOT LIKE '%' || c.d || '%IMP-27 e%'
                          THEN 'note='||coalesce(left(sr.editorial_note, 40),'NULL') END,
                     CASE WHEN EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = c.r) THEN 'lien' END,
                     CASE WHEN EXISTS (SELECT 1 FROM public.book_drafts d WHERE d.marc_json->'ingest'->>'staging_row_id' = c.r::text)
                          THEN 'brouillon' END) AS e
              FROM (VALUES (1, v_row, v_d), (2, v_row2, v_d2)) AS c(k, r, d)
              LEFT JOIN ingest.partner_catalog_staging_rows sr ON sr.id = c.r) q;
    IF v_n <> 2 OR v_txt <> ''
       OR (v_res3->>'updated_rows')::int IS DISTINCT FROM 0 OR (v_res3->>'skipped_rows')::int IS DISTINCT FROM 2
       OR (v_res4->>'updated_rows')::int IS DISTINCT FROM 0 OR (v_res4->>'skipped_rows')::int IS DISTINCT FROM 2
       OR (v_res5->>'updated_rows')::int IS DISTINCT FROM 0 OR (v_res5->>'skipped_rows')::int IS DISTINCT FROM 2
       OR coalesce((v_res6->>'selected_count')::int, 0) <> 0 OR v_res6->>'batch_id' IS NOT NULL
       OR coalesce((v_res7->>'selected_count')::int, 0) <> 0 OR v_res7->>'batch_id' IS NOT NULL THEN
      RAISE EXCEPTION '(0) une ligne ecartee relevee par l''API : suppression=% [%] en attente=% accepte=% rejete=% selection=% run entier=%',
        v_n, v_txt, v_res3 - 'run' - 'run_id', v_res4 - 'run' - 'run_id', v_res5 - 'run' - 'run_id',
        left(coalesce(v_res6::text,'NULL'), 120), left(coalesce(v_res7::text,'NULL'), 120);
    END IF;
    -- (1) la repromotion, que l'API ne construit plus : posée EN POSTGRES — la
    --     décision « Accepté (nouveau) » écrite sur la ligne comme l'écrivait
    --     fn_set_partner_catalog_editorial_decision, discarded_draft_id vidé —,
    --     puis « Promouvoir » par l'API : un nouveau brouillon pour la ligne 1
    UPDATE ingest.partner_catalog_staging_rows
       SET editorial_decision = 'accept_new', review_status = 'approved', selected_for_draft = true,
           editorial_note = NULL, discarded_draft_id = NULL
     WHERE id = v_row;
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_res2 := public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new']);
    EXECUTE 'RESET ROLE';
    SELECT m.draft_id INTO v_d3 FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row;
    IF (v_res2->>'selected_count')::int IS DISTINCT FROM 1
       OR v_d3 IS NULL OR v_d3 = v_d
       OR (SELECT created_book_draft_id FROM ingest.partner_catalog_staging_rows WHERE id = v_row) IS DISTINCT FROM v_d3
       OR NOT (SELECT editorial_decision = 'reject' AND discarded_draft_id = v_d2
                 FROM ingest.partner_catalog_staging_rows WHERE id = v_row2) THEN
      RAISE EXCEPTION 'decor : repromotion=% nouveau brouillon=%', left(coalesce(v_res2::text,'NULL'), 200), v_d3;
    END IF;
    SELECT max(l.id) INTO v_audit  FROM public.catalog_audit_log l WHERE l.action = 'delete' AND l.entity_type = 'book' AND l.entity_id = v_d;
    SELECT max(l.id) INTO v_audit2 FROM public.catalog_audit_log l WHERE l.action = 'delete' AND l.entity_type = 'book' AND l.entity_id = v_d2;
    -- (2) la ligne repromue : refus, rien de rejoué ni journalisé (le rejeu,
    --     par la coordination, sous le rôle de l'API)
    v_hint := NULL;
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN PERFORM public.fn_restore_deleted_draft(v_audit); v_hint := 'rejoue';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    EXECUTE 'RESET ROLE';
    v_ok := NOT EXISTS (SELECT 1 FROM public.book_drafts WHERE id = v_d)
            AND (SELECT count(*) FROM public.book_drafts d WHERE d.marc_json->'ingest'->>'staging_row_id' = v_row::text) = 1
            AND NOT EXISTS (SELECT 1 FROM public.catalog_audit_log l
                             WHERE l.action = 'restore' AND l.details->>'from_audit_id' = v_audit::text);
    -- (3) chacune des deux preuves suffit (états posés par postgres ;
    --     discarded_draft_id est vide, la troisième clause de la garde ne
    --     joue pas) : le lien seul, puis created_book_draft_id seul
    UPDATE ingest.partner_catalog_staging_rows SET created_book_draft_id = NULL WHERE id = v_row;
    v_hint4 := NULL;
    BEGIN PERFORM public.fn_restore_deleted_draft(v_audit); v_hint4 := 'rejoue';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint4 = PG_EXCEPTION_HINT; END;
    DELETE FROM ingest.partner_catalog_row_to_draft WHERE staging_row_id = v_row;
    UPDATE ingest.partner_catalog_staging_rows SET created_book_draft_id = v_d3 WHERE id = v_row;
    v_hint5 := NULL;
    BEGIN PERFORM public.fn_restore_deleted_draft(v_audit); v_hint5 := 'rejoue';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint5 = PG_EXCEPTION_HINT; END;
    v_ok := v_ok AND NOT EXISTS (SELECT 1 FROM public.book_drafts WHERE id = v_d);
    -- (4) la ligne 2, écartée, jamais repromue, sur qui les gestes de (0) sont
    --     restés sans effet : le rejeu de SON brouillon la reprend quand même
    --     (T10), par l'API ; la ligne 1 reste au nouveau brouillon
    v_hint2 := NULL; v_res := NULL;
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN v_res := public.fn_restore_deleted_draft(v_audit2);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint2 = PG_EXCEPTION_HINT; v_hint2 := coalesce(v_hint2, SQLERRM); END;
    EXECUTE 'RESET ROLE';
    IF v_hint = 'error.catalog.restore_line_repromoted' AND v_ok
       AND v_hint4 = 'error.catalog.restore_line_repromoted' AND v_hint5 = 'error.catalog.restore_line_repromoted'
       AND v_hint2 IS NULL AND coalesce((v_res->>'ok')::boolean, false)
       AND EXISTS (SELECT 1 FROM public.book_drafts WHERE id = v_d2)
       AND (SELECT count(*) FROM public.book_drafts d WHERE d.marc_json->'ingest'->>'staging_row_id' = v_row2::text) = 1
       AND (SELECT created_book_draft_id = v_d2 AND editorial_decision = 'accept_new' AND review_status = 'draft_created'
                   AND discarded_draft_id IS NULL
              FROM ingest.partner_catalog_staging_rows WHERE id = v_row2)
       AND (SELECT count(*) FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row2) = 1
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft m
                    WHERE m.staging_row_id = v_row2 AND m.draft_id = v_d2 AND m.batch_id IS NULL)
       AND (SELECT created_book_draft_id FROM ingest.partner_catalog_staging_rows WHERE id = v_row) = v_d3
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : repromue='||coalesce(v_hint,'NULL')||' rien rejoue='||coalesce(v_ok::text,'NULL')
         ||' lien seul='||coalesce(v_hint4,'NULL')||' created_book_draft_id seul='||coalesce(v_hint5,'NULL')
         ||' jamais repromue='||coalesce(v_hint2, coalesce(v_res::text,'NULL'))
         ||' ligne 2='||coalesce((SELECT row(created_book_draft_id, editorial_decision, review_status, discarded_draft_id)::text
                                  FROM ingest.partner_catalog_staging_rows WHERE id = v_row2), 'absente')
         ||' liens 2='||coalesce((SELECT string_agg(row(m.draft_id, m.batch_id)::text, ',') FROM ingest.partner_catalog_row_to_draft m
                                   WHERE m.staging_row_id = v_row2), 'aucun')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T18 ─────────────────────────────────────────────────────────────
  v_t := 'T18 (e) la reprise (« Editer ») d''une notice importee, supprimee definitivement, se rejoue ; sa publication met a jour la notice ; la ligne reste au brouillon d''import';
  BEGIN
    INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active') ON CONFLICT DO NOTHING;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21a-t18.marc', 'h21a-t18.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 1, 'H21A-T18', 'H21A Notice importee puis reprise', 'new_record', 'accept_new') RETURNING id INTO v_row;
    -- la notice importée : promue, révisée, publiée ; son brouillon d'import garde la ligne
    v_lot := (public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
    SELECT m.draft_id INTO v_d FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row;
    UPDATE public.book_drafts SET bib_ref = 'H21A-T18', tipo_material = 'livro' WHERE id = v_d;   -- la cote (postgres)
    v_res := public.fn_batch_review_request(v_lot, 'H21A T18 : notice importee, puis reprise');
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_book := public.publish_book_draft(v_d);
    -- « Éditer » : la reprise recopie la notice, trace comprise ; retouchée, jetée, purgée
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_d2 := public.create_book_draft_from_book(v_book, NULL);
    UPDATE public.book_drafts SET titulo = 'H21A Notice reprise, retouchee' WHERE id = v_d2;
    UPDATE public.book_drafts SET status = 'cancelled' WHERE id = v_d2;
    DELETE FROM public.book_drafts WHERE id = v_d2;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    EXECUTE 'RESET ROLE';
    SELECT max(l.id) INTO v_audit FROM public.catalog_audit_log l
     WHERE l.action = 'delete' AND l.entity_type = 'book' AND l.entity_id = v_d2;
    IF v_book IS NULL OR v_n <> 1 OR v_audit IS NULL
       OR (SELECT (l.details->'snapshot'->>'published_book_id')::bigint IS DISTINCT FROM v_book
                  OR (l.details->'snapshot') #>> '{marc_json,ingest,staging_row_id}' IS DISTINCT FROM v_row::text
             FROM public.catalog_audit_log l WHERE l.id = v_audit)
       -- supprimer la reprise n'a pas écarté la ligne : elle est au brouillon d'import
       OR NOT (SELECT created_book_draft_id = v_d AND editorial_decision = 'accept_new'
                 FROM ingest.partner_catalog_staging_rows WHERE id = v_row) THEN
      RAISE EXCEPTION 'decor : notice=% suppression=% journal=% ligne=%', v_book, v_n, v_audit,
        (SELECT row(created_book_draft_id, editorial_decision)::text FROM ingest.partner_catalog_staging_rows WHERE id = v_row);
    END IF;
    -- « Restaurer » depuis le journal, par la coordination (API)
    v_hint := NULL; v_res := NULL;
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN v_res := public.fn_restore_deleted_draft(v_audit);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_hint := coalesce(v_hint, SQLERRM); END;
    UPDATE public.book_drafts SET status = 'draft' WHERE id = v_d2;        -- sortie de corbeille
    EXECUTE 'RESET ROLE';
    v_ok := (SELECT published_book_id = v_book AND titulo = 'H21A Notice reprise, retouchee'
               FROM public.book_drafts WHERE id = v_d2);
    -- publiée, la reprise met à jour LA notice : aucune seconde notice
    v_hint2 := NULL; v_book2 := NULL;
    BEGIN v_book2 := public.publish_book_draft(v_d2);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint2 = PG_EXCEPTION_HINT; v_hint2 := coalesce(v_hint2, SQLERRM); END;
    IF v_hint IS NULL AND coalesce((v_res->>'ok')::boolean, false) AND coalesce(v_ok, false)
       AND v_hint2 IS NULL AND v_book2 = v_book
       AND (SELECT count(*) FROM public.books WHERE bib_ref = 'H21A-T18') = 1
       AND (SELECT titulo FROM public.books WHERE id = v_book) = 'H21A Notice reprise, retouchee'
       AND (SELECT created_book_draft_id = v_d AND editorial_decision = 'accept_new'
              FROM ingest.partner_catalog_staging_rows WHERE id = v_row)
       AND (SELECT count(*) FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row) = 1
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row AND m.draft_id = v_d)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : rejeu='||coalesce(v_hint, coalesce(v_res::text,'NULL'))
         ||' reprise='||coalesce((SELECT row(published_book_id, titulo)::text FROM public.book_drafts WHERE id = v_d2), 'absente')
         ||' publication='||coalesce(v_hint2, coalesce(v_book2::text,'NULL'))||' (notice '||v_book||')'
         ||' notices='||(SELECT count(*) FROM public.books WHERE bib_ref = 'H21A-T18')
         ||' ligne='||coalesce((SELECT row(created_book_draft_id, editorial_decision)::text FROM ingest.partner_catalog_staging_rows WHERE id = v_row), 'absente')); END IF;
  EXCEPTION WHEN OTHERS THEN
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T19 ─────────────────────────────────────────────────────────────
  v_t := 'T19 (e) creation rejouee, puis sa ligne reacceptee par l''API et promue : aucun second brouillon, le run reste retenu';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21a-t19.marc', 'h21a-t19.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 1, 'H21A-T19', 'H21A Rejouee puis reacceptee', 'new_record', 'accept_new') RETURNING id INTO v_row;
    -- tout par l'API, comme à l'écran
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_lot := (public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
    EXECUTE 'RESET ROLE';
    SELECT m.draft_id INTO v_d FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row;
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET status = 'cancelled' WHERE id = v_d;
    DELETE FROM public.book_drafts WHERE id = v_d;                          -- « Vider la corbeille » : ligne écartée
    EXECUTE 'RESET ROLE';
    SELECT max(l.id) INTO v_audit FROM public.catalog_audit_log l
     WHERE l.action = 'delete' AND l.entity_type = 'book' AND l.entity_id = v_d;
    IF v_d IS NULL OR v_audit IS NULL
       OR NOT (SELECT editorial_decision = 'reject' AND created_book_draft_id IS NULL
                 FROM ingest.partner_catalog_staging_rows WHERE id = v_row) THEN
      RAISE EXCEPTION 'decor : brouillon=% journal=% ligne=%', v_d, v_audit,
        (SELECT row(editorial_decision, created_book_draft_id)::text FROM ingest.partner_catalog_staging_rows WHERE id = v_row);
    END IF;
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_res := public.fn_restore_deleted_draft(v_audit);                      -- « Restaurer » : il revient à la corbeille
    -- la même ligne réacceptée (le chemin de T17), puis « Créer 1 brouillon »
    -- (la sélection) ; puis le brouillon sort de la corbeille, et « Promouvoir »
    -- (tout le run)
    v_res2 := public.fn_import_set_editorial(v_run, ARRAY[v_row], 'accept_new', NULL);
    v_res3 := public.fn_import_promote(v_run, p_row_ids := ARRAY[v_row]);
    UPDATE public.book_drafts SET status = 'draft' WHERE id = v_d;
    v_res4 := public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new']);
    EXECUTE 'RESET ROLE';
    -- sorti de la corbeille, le brouillon rejoué retient de nouveau le run : le
    -- lien est revenu SANS lot — le compte par lot ne le voit pas, celui des
    -- brouillons liés le voit (à la corbeille, il le laisserait partir : T11)
    v_hint := NULL;
    BEGIN PERFORM public.fn_import_delete_run(v_run); v_hint := 'supprime';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    IF coalesce((v_res->>'ok')::boolean, false)
       AND (v_res2->>'updated_rows')::int = 0 AND (v_res2->>'skipped_rows')::int = 1
       AND coalesce((v_res3->>'selected_count')::int, 0) = 0 AND v_res3->>'batch_id' IS NULL
       AND coalesce((v_res4->>'selected_count')::int, 0) = 0 AND v_res4->>'batch_id' IS NULL
       AND (SELECT count(*) FROM public.book_drafts d WHERE d.marc_json->'ingest'->>'staging_row_id' = v_row::text) = 1
       AND (SELECT created_book_draft_id = v_d AND editorial_decision = 'accept_new' AND review_status = 'draft_created'
              FROM ingest.partner_catalog_staging_rows WHERE id = v_row)
       AND (SELECT count(*) FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row) = 1
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft m
                    WHERE m.staging_row_id = v_row AND m.draft_id = v_d AND m.batch_id IS NULL)
       AND (SELECT batch_id FROM public.book_drafts WHERE id = v_d) = v_lot
       AND v_hint = 'error.import.run_has_linked_drafts'
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_import_runs WHERE id = v_run)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : rejeu='||coalesce(v_res::text,'NULL')
         ||' decision='||coalesce((v_res2 - 'run')::text,'NULL')
         ||' selection='||left(coalesce(v_res3::text,'NULL'), 150)||' run entier='||left(coalesce(v_res4::text,'NULL'), 150)
         ||' brouillons de la ligne='||(SELECT count(*) FROM public.book_drafts d WHERE d.marc_json->'ingest'->>'staging_row_id' = v_row::text)
         ||' ligne='||coalesce((SELECT row(created_book_draft_id, editorial_decision, review_status)::text FROM ingest.partner_catalog_staging_rows WHERE id = v_row), 'absente')
         ||' liens='||coalesce((SELECT string_agg(row(m.draft_id, m.batch_id)::text, ',') FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row), 'aucun')
         ||' suppression du run='||coalesce(v_hint,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T20 ─────────────────────────────────────────────────────────────
  v_t := 'T20 (c) un exemplaire rapproche a la corbeille retient son run : suppression refusee (run_has_trashed_items), rien de detruit';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    -- une notice de BLMF déjà au catalogue, que le fichier redécrit
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
    VALUES ('H21A Notice existante T20', 'H21A-T20-N', 'livro', v_lib) RETURNING id INTO v_book;
    INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_book, v_lib);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21a-t20.marc', 'h21a-t20.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, proposed_book_id, normalized_payload)
    VALUES (v_run, 1, 'H21A-T20', 'H21A Doublon rapproche puis jete', 'matched_book', 'pending', v_book,
            jsonb_build_object('items', '[{"source_item_code":"H21A-T20-C1","call_number":"H21A 20"}]'::jsonb)) RETURNING id INTO v_row;
    -- « Rapprocher » : un lot de rapprochement, un exemplaire sans notice importée
    v_res := public.fn_import_reconcile_duplicates(v_run, ARRAY[v_row]);
    v_main := (v_res->>'batch_id')::bigint;
    SELECT x.id INTO v_x FROM public.exemplar_drafts x WHERE x.import_staging_row_id = v_row AND x.book_draft_id IS NULL;
    -- à la corbeille (QueuePanel, API)
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.exemplar_drafts SET status = 'cancelled' WHERE id = v_x;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    EXECUTE 'RESET ROLE';
    IF v_x IS NULL OR v_main IS NULL OR v_n <> 1 THEN
      RAISE EXCEPTION 'decor : rapprochement=% exemplaire=% corbeille=%', left(coalesce(v_res::text,'NULL'), 200), v_x, v_n;
    END IF;
    v_hint := NULL;
    BEGIN PERFORM public.fn_import_delete_run(v_run); v_hint := 'supprime';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    -- non-action : run, ligne, lot et exemplaire (avec sa ligne) intacts
    IF v_hint = 'error.import.run_has_trashed_items'
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_import_runs WHERE id = v_run)
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows WHERE id = v_row AND run_id = v_run)
       AND EXISTS (SELECT 1 FROM public.catalog_batches WHERE id = v_main)
       AND (SELECT status = 'cancelled' AND import_staging_row_id = v_row AND book_draft_id IS NULL
              FROM public.exemplar_drafts WHERE id = v_x)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : suppression='||coalesce(v_hint,'NULL')
         ||' run='||EXISTS (SELECT 1 FROM ingest.partner_catalog_import_runs WHERE id = v_run)
         ||' exemplaire='||coalesce((SELECT row(status, import_staging_row_id)::text FROM public.exemplar_drafts WHERE id = v_x), 'absent')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T21 ─────────────────────────────────────────────────────────────
  v_t := 'T21 (c) un exemplaire rapproche purge, son run supprime : le journal ne le rejoue pas (restore_item_import_gone), rien de rejoue';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
    VALUES ('H21A Notice existante T21', 'H21A-T21-N', 'livro', v_lib) RETURNING id INTO v_book;
    INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_book, v_lib);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21a-t21.marc', 'h21a-t21.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, proposed_book_id, normalized_payload)
    VALUES (v_run, 1, 'H21A-T21', 'H21A Doublon rapproche puis purge', 'matched_book', 'pending', v_book,
            jsonb_build_object('items', '[{"source_item_code":"H21A-T21-C1","call_number":"H21A 21"}]'::jsonb)) RETURNING id INTO v_row;
    v_res := public.fn_import_reconcile_duplicates(v_run, ARRAY[v_row]);
    SELECT x.id INTO v_x FROM public.exemplar_drafts x WHERE x.import_staging_row_id = v_row AND x.book_draft_id IS NULL;
    -- corbeille, puis « Vider la corbeille » (API)
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.exemplar_drafts SET status = 'cancelled' WHERE id = v_x;
    DELETE FROM public.exemplar_drafts WHERE id = v_x;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    EXECUTE 'RESET ROLE';
    SELECT max(l.id) INTO v_audit FROM public.catalog_audit_log l
     WHERE l.action = 'delete' AND l.entity_type = 'exemplar' AND (l.details->'snapshot'->>'id')::bigint = v_x;
    -- purgé, il ne retient plus le run : « Supprimer le run » passe
    v_res2 := public.fn_import_delete_run(v_run);
    IF v_x IS NULL OR v_n <> 1 OR v_audit IS NULL OR NOT coalesce((v_res2->>'ok')::boolean, false)
       OR EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows WHERE id = v_row)
       OR (SELECT (l.details->'snapshot'->>'import_staging_row_id')::bigint IS DISTINCT FROM v_row
                  OR l.details->'snapshot'->>'book_draft_id' IS NOT NULL
             FROM public.catalog_audit_log l WHERE l.id = v_audit) THEN
      RAISE EXCEPTION 'decor : exemplaire=% purge=% journal=% run=%', v_x, v_n, v_audit, v_res2;
    END IF;
    v_hint := NULL;
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN PERFORM public.fn_restore_deleted_draft(v_audit); v_hint := 'rejoue';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    EXECUTE 'RESET ROLE';
    IF v_hint = 'error.catalog.restore_item_import_gone'
       AND NOT EXISTS (SELECT 1 FROM public.exemplar_drafts WHERE id = v_x)
       AND NOT EXISTS (SELECT 1 FROM public.exemplar_drafts WHERE source_item_code = 'H21A-T21-C1')
       AND NOT EXISTS (SELECT 1 FROM public.catalog_audit_log l
                        WHERE l.action = 'restore' AND l.details->>'from_audit_id' = v_audit::text)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : rejeu='||coalesce(v_hint,'NULL')
         ||' exemplaire='||coalesce((SELECT row(id, status, import_staging_row_id, batch_id)::text FROM public.exemplar_drafts WHERE source_item_code = 'H21A-T21-C1' LIMIT 1), 'absent')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T22 ─────────────────────────────────────────────────────────────
  v_t := 'T22 (a) par l''API seule la publication pose ''published'' : UPDATE et INSERT refuses (42501), draft/ready passent, un publie se reenregistre';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    -- un brouillon déjà publié (par la publication), un brouillon en cours
    INSERT INTO public.book_drafts (action, status, titulo, tipo_material, bib_ref, owner_library_id, created_by)
    VALUES ('create', 'draft', 'H21A Deja publiee T22', 'livro', 'H21A-T22-1', v_lib, v_coord) RETURNING id INTO v_d;
    v_book := public.publish_book_draft(v_d);
    INSERT INTO public.book_drafts (action, status, titulo, tipo_material, bib_ref, owner_library_id, created_by)
    VALUES ('create', 'draft', 'H21A En cours T22', 'livro', 'H21A-T22-2', v_lib, v_coord) RETURNING id INTO v_d2;
    IF v_book IS NULL OR (SELECT status FROM public.book_drafts WHERE id = v_d) <> 'published' THEN
      RAISE EXCEPTION 'decor : publication=%', v_book;
    END IF;
    v_hint := NULL; v_st := NULL; v_hint2 := NULL; v_st2 := NULL; v_txt := '';
    EXECUTE 'SET LOCAL ROLE authenticated';
    -- (1) UPDATE à 'published' : refusé
    BEGIN UPDATE public.book_drafts SET status = 'published' WHERE id = v_d2; v_hint := 'accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT, v_st = RETURNED_SQLSTATE; END;
    -- (2) INSERT en 'published' : refusé ; le même INSERT en 'draft' passe
    BEGIN
      INSERT INTO public.book_drafts (action, status, titulo, tipo_material, bib_ref, owner_library_id, created_by)
      VALUES ('create', 'published', 'H21A Inseree publiee T22', 'livro', 'H21A-T22-3', v_lib, v_coord);
      v_hint2 := 'accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint2 = PG_EXCEPTION_HINT, v_st2 = RETURNED_SQLSTATE; END;
    INSERT INTO public.book_drafts (action, status, titulo, tipo_material, bib_ref, owner_library_id, created_by)
    VALUES ('create', 'draft', 'H21A Inseree en cours T22', 'livro', 'H21A-T22-4', v_lib, v_coord);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    IF v_n <> 1 THEN v_txt := v_txt || ' insert_draft=' || v_n; END IF;
    -- (3) 'ready' : le formulaire
    UPDATE public.book_drafts SET status = 'ready' WHERE id = v_d2;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    IF v_n <> 1 THEN v_txt := v_txt || ' ready=' || v_n; END IF;
    -- (4) le publié réenregistré tel quel (status 'published' renvoyé), avec une retouche
    UPDATE public.book_drafts SET status = 'published', titulo = 'H21A Deja publiee T22, retouchee' WHERE id = v_d;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    IF v_n <> 1 THEN v_txt := v_txt || ' republie=' || v_n; END IF;
    EXECUTE 'RESET ROLE';
    IF v_hint = 'error.publish.status_reserved' AND v_st = '42501'
       AND v_hint2 = 'error.publish.status_reserved' AND v_st2 = '42501'
       AND v_txt = ''
       AND (SELECT status FROM public.book_drafts WHERE id = v_d2) = 'ready'
       AND (SELECT status = 'published' AND titulo = 'H21A Deja publiee T22, retouchee' AND published_book_id = v_book
              FROM public.book_drafts WHERE id = v_d)
       AND NOT EXISTS (SELECT 1 FROM public.book_drafts WHERE bib_ref = 'H21A-T22-3')
       AND (SELECT status FROM public.book_drafts WHERE bib_ref = 'H21A-T22-4') = 'draft'
       AND NOT EXISTS (SELECT 1 FROM public.books WHERE bib_ref IN ('H21A-T22-2', 'H21A-T22-3'))
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : update='||coalesce(v_hint,'NULL')||'/'||coalesce(v_st,'-')
         ||' insert='||coalesce(v_hint2,'NULL')||'/'||coalesce(v_st2,'-')||' ['||v_txt||' ] en cours='
         ||coalesce((SELECT status FROM public.book_drafts WHERE id = v_d2), 'absent')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T23 ─────────────────────────────────────────────────────────────
  v_t := 'T23 (a) defense : un exemplaire rattache ne suit pas une notice ''published'' sans notice au catalogue (item_before_record), meme vise sur une detention existante';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    -- les tombos de BLMF : sans eux, le contournement (contre-épreuve)
    -- buterait sur fn_next_tombo au lieu de créer l'exemplaire
    UPDATE public.libraries SET tombo_pattern = '{"prefix": "H21A-T-", "year": false, "pad": 4}'::jsonb WHERE id = v_lib;
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
    VALUES ('H21A Notice existante T23', 'H21A-T23-N', 'livro', v_lib) RETURNING id INTO v_book;
    INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_book, v_lib) RETURNING id INTO v_h;
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21a-t23.marc', 'h21a-t23.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
    VALUES (v_run, 1, 'H21A-T23', 'H21A Notice jamais revisee, un exemplaire', 'new_record', 'accept_new',
            jsonb_build_object('items', '[{"source_item_code":"H21A-T23-C1","call_number":"H21A 23"}]'::jsonb)) RETURNING id INTO v_row;
    v_lot := (public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
    SELECT m.draft_id INTO v_d FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row;
    SELECT x.id INTO v_x FROM public.exemplar_drafts x WHERE x.book_draft_id = v_d;
    UPDATE public.book_drafts SET bib_ref = 'H21A-T23' WHERE id = v_d;
    -- l'état que l'API ne peut plus poser (T22), posé ici en postgres :
    -- « publiée » sans notice au catalogue
    UPDATE public.book_drafts SET status = 'published' WHERE id = v_d;
    -- par l'API : l'exemplaire visé sur la détention d'une notice existante
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.exemplar_drafts SET target_holding_id = v_h WHERE id = v_x;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    EXECUTE 'RESET ROLE';
    IF v_d IS NULL OR v_x IS NULL OR v_n <> 1
       OR NOT (SELECT status = 'published' AND published_book_id IS NULL FROM public.book_drafts WHERE id = v_d)
       OR (SELECT target_holding_id FROM public.exemplar_drafts WHERE id = v_x) IS DISTINCT FROM v_h THEN
      RAISE EXCEPTION 'decor : notice=% exemplaire=% visee=%', v_d, v_x, v_n;
    END IF;
    v_hint := NULL;
    BEGIN PERFORM public.publish_exemplar_draft(v_x); v_hint := 'publie';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_hint := coalesce(v_hint, SQLERRM); END;
    IF v_hint = 'error.publish.item_before_record'
       AND NOT EXISTS (SELECT 1 FROM public.exemplares WHERE source_item_code = 'H21A-T23-C1')
       AND NOT EXISTS (SELECT 1 FROM public.exemplares WHERE holding_id = v_h)
       AND (SELECT status <> 'published' AND published_exemplar_id IS NULL FROM public.exemplar_drafts WHERE id = v_x)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : publication='||coalesce(v_hint,'NULL')
         ||' exemplaires sur la detention='||(SELECT count(*) FROM public.exemplares WHERE holding_id = v_h)
         ||' exemplaire='||coalesce((SELECT row(e.tombo, e.bib_ref, e.shelf_location)::text FROM public.exemplares e
                                      WHERE e.source_item_code = 'H21A-T23-C1' LIMIT 1), 'aucun')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T25 ─────────────────────────────────────────────────────────────
  v_t := 'T25 (e, P1) entre le vidage et le rejeu, les gestes sur la decision sont ignores (ligne ecartee intacte) ; le rejeu reprend chaque ligne, aucun second brouillon';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21a-t25.marc', 'h21a-t25.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 1, 'H21A-T25-1', 'H21A En attente avant le rejeu', 'new_record', 'accept_new') RETURNING id INTO v_row;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 2, 'H21A-T25-2', 'H21A Reacceptee avant le rejeu', 'new_record', 'accept_new') RETURNING id INTO v_row2;
    -- tout par l'API, sous l'identité de la coordination
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_lot := (public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
    EXECUTE 'RESET ROLE';
    SELECT m.draft_id INTO v_d  FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row;
    SELECT m.draft_id INTO v_d2 FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row2;
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET status = 'cancelled' WHERE id IN (v_d, v_d2);
    DELETE FROM public.book_drafts WHERE id IN (v_d, v_d2);                -- « Vider la corbeille »
    GET DIAGNOSTICS v_n = ROW_COUNT;
    -- entre le vidage et le rejeu (P1) : les deux lignes « En attente », puis
    -- la ligne 2 « Accepté (nouveau) » — l'ordre « réaccepter avant de
    -- rejouer ». Quatrième passe : une ligne écartée n'accepte plus aucune
    -- décision, les deux gestes sont ignorés (skipped_rows)
    v_res := public.fn_import_set_editorial(v_run, ARRAY[v_row, v_row2], 'pending', NULL);
    v_res2 := public.fn_import_set_editorial(v_run, ARRAY[v_row2], 'accept_new', NULL);
    EXECUTE 'RESET ROLE';
    SELECT max(l.id) INTO v_audit  FROM public.catalog_audit_log l WHERE l.action = 'delete' AND l.entity_type = 'book' AND l.entity_id = v_d;
    SELECT max(l.id) INTO v_audit2 FROM public.catalog_audit_log l WHERE l.action = 'delete' AND l.entity_type = 'book' AND l.entity_id = v_d2;
    IF v_d IS NULL OR v_d2 IS NULL OR v_n <> 2 OR v_audit IS NULL OR v_audit2 IS NULL THEN
      RAISE EXCEPTION 'decor : brouillons=%/% suppression=% journal=%/%', v_d, v_d2, v_n, v_audit, v_audit2;
    END IF;
    -- les lignes avant le rejeu, jugées à la fin : chacune intacte — 'reject' /
    -- 'rejected', la note du déclencheur, discarded_draft_id = son brouillon,
    -- rien de créé, aucun lien
    SELECT coalesce(string_agg(CASE WHEN q.e <> '' THEN 'ligne' || q.k || '[' || q.e || ']' END, ' '), '') INTO v_txt3
      FROM (SELECT c.k, concat_ws(',',
                     CASE WHEN sr.editorial_decision IS DISTINCT FROM 'reject' OR sr.review_status IS DISTINCT FROM 'rejected'
                          THEN 'decision='||coalesce(sr.editorial_decision,'NULL')||'/'||coalesce(sr.review_status,'NULL') END,
                     CASE WHEN sr.selected_for_draft IS DISTINCT FROM false THEN 'selectionnee' END,
                     CASE WHEN sr.created_book_draft_id IS NOT NULL THEN 'cree='||sr.created_book_draft_id END,
                     CASE WHEN sr.discarded_draft_id IS DISTINCT FROM c.d THEN 'ecartee_par='||coalesce(sr.discarded_draft_id::text,'NULL') END,
                     CASE WHEN coalesce(sr.editorial_note, '') NOT LIKE '%' || c.d || '%IMP-27 e%'
                          THEN 'note='||coalesce(left(sr.editorial_note, 40),'NULL') END,
                     CASE WHEN EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = c.r) THEN 'lien' END) AS e
              FROM (VALUES (1, v_row, v_d), (2, v_row2, v_d2)) AS c(k, r, d)
              LEFT JOIN ingest.partner_catalog_staging_rows sr ON sr.id = c.r) q;
    v_res8 := jsonb_build_object('en_attente', v_res - 'run' - 'run_id', 'reacceptee', v_res2 - 'run' - 'run_id');
    -- « Restaurer » les deux, les sortir de la corbeille ; puis les gestes qui
    -- feraient un second brouillon : « En attente », « Accepté (nouveau) », la
    -- promotion de la sélection, puis de tout le run (API)
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_res3 := public.fn_restore_deleted_draft(v_audit);
    v_res4 := public.fn_restore_deleted_draft(v_audit2);
    UPDATE public.book_drafts SET status = 'draft' WHERE id IN (v_d, v_d2);
    v_res  := public.fn_import_set_editorial(v_run, ARRAY[v_row, v_row2], 'pending', NULL);
    v_res5 := public.fn_import_set_editorial(v_run, ARRAY[v_row, v_row2], 'accept_new', NULL);
    v_res6 := public.fn_import_promote(v_run, p_row_ids := ARRAY[v_row, v_row2]);
    v_res7 := public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new']);
    EXECUTE 'RESET ROLE';
    SELECT coalesce(string_agg(CASE WHEN q.e <> '' THEN 'ligne' || q.k || '[' || q.e || ']' END, ' '), '') INTO v_txt
      FROM (SELECT c.k, concat_ws(',',
                     CASE WHEN sr.created_book_draft_id IS DISTINCT FROM c.d THEN 'cree='||coalesce(sr.created_book_draft_id::text,'NULL') END,
                     CASE WHEN sr.editorial_decision IS DISTINCT FROM 'accept_new' OR sr.review_status IS DISTINCT FROM 'draft_created'
                          THEN 'decision='||coalesce(sr.editorial_decision,'NULL')||'/'||coalesce(sr.review_status,'NULL') END,
                     CASE WHEN sr.discarded_draft_id IS NOT NULL THEN 'ecartee_par='||sr.discarded_draft_id END,
                     CASE WHEN (SELECT count(*) FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = c.r) <> 1
                            OR NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft m
                                            WHERE m.staging_row_id = c.r AND m.draft_id = c.d AND m.batch_id IS NULL)
                          THEN 'lien='||coalesce((SELECT string_agg(row(m.draft_id, m.batch_id)::text, ',') FROM ingest.partner_catalog_row_to_draft m
                                                   WHERE m.staging_row_id = c.r), 'aucun') END,
                     CASE WHEN (SELECT count(*) FROM public.book_drafts d WHERE d.marc_json->'ingest'->>'staging_row_id' = c.r::text) <> 1
                          THEN 'brouillons='||(SELECT count(*) FROM public.book_drafts d WHERE d.marc_json->'ingest'->>'staging_row_id' = c.r::text) END) AS e
              FROM (VALUES (1, v_row, v_d), (2, v_row2, v_d2)) AS c(k, r, d)
              LEFT JOIN ingest.partner_catalog_staging_rows sr ON sr.id = c.r) q;
    IF (v_res8#>>'{en_attente,updated_rows}')::int = 0 AND (v_res8#>>'{en_attente,skipped_rows}')::int = 2
       AND (v_res8#>>'{reacceptee,updated_rows}')::int = 0 AND (v_res8#>>'{reacceptee,skipped_rows}')::int = 1
       AND v_txt3 = ''
       AND coalesce((v_res3->>'ok')::boolean, false) AND coalesce((v_res4->>'ok')::boolean, false)
       AND v_txt = ''
       AND (v_res->>'updated_rows')::int = 0 AND (v_res->>'skipped_rows')::int = 2
       AND (v_res5->>'updated_rows')::int = 0 AND (v_res5->>'skipped_rows')::int = 2
       AND coalesce((v_res6->>'selected_count')::int, 0) = 0 AND v_res6->>'batch_id' IS NULL
       AND coalesce((v_res7->>'selected_count')::int, 0) = 0 AND v_res7->>'batch_id' IS NULL
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : avant le rejeu '||v_res8::text||' ['||v_txt3||']'
         ||' rejeux='||coalesce(v_res3->>'ok','NULL')||'/'||coalesce(v_res4->>'ok','NULL')
         ||' ['||v_txt||'] en attente='||coalesce((v_res - 'run_id')::text,'NULL')||' accepte='||coalesce((v_res5 - 'run_id')::text,'NULL')
         ||' selection='||left(coalesce(v_res6::text,'NULL'), 150)||' run entier='||left(coalesce(v_res7::text,'NULL'), 150)); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T26 ─────────────────────────────────────────────────────────────
  v_t := 'T26 (e, P2) lot reattribue a une autre bibliotheque avant la suppression : le rejeu reprend quand meme la ligne, aucun second brouillon';
  BEGIN
    INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active') ON CONFLICT DO NOTHING;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21a-t26.marc', 'h21a-t26.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 1, 'H21A-T26', 'H21A Lot reattribue puis purge', 'new_record', 'accept_new') RETURNING id INTO v_row;
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_lot := (public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
    EXECUTE 'RESET ROLE';
    SELECT m.draft_id INTO v_d FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row;
    -- l'administration réattribue le lot à B (le run own_catalog reste à BLMF),
    -- puis corbeille et « Vider la corbeille » (API)
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_res := public.fn_batch_reassign_library(v_lot, v_libB);
    UPDATE public.book_drafts SET status = 'cancelled' WHERE id = v_d;
    DELETE FROM public.book_drafts WHERE id = v_d;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    EXECUTE 'RESET ROLE';
    SELECT max(l.id) INTO v_audit FROM public.catalog_audit_log l
     WHERE l.action = 'delete' AND l.entity_type = 'book' AND l.entity_id = v_d;
    IF v_d IS NULL OR v_n <> 1 OR v_audit IS NULL OR NOT coalesce((v_res->>'ok')::boolean, false)
       OR (SELECT (l.details->'snapshot'->>'owner_library_id')::uuid FROM public.catalog_audit_log l WHERE l.id = v_audit) IS DISTINCT FROM v_libB
       OR (SELECT library_id FROM ingest.partner_catalog_import_runs WHERE id = v_run) IS DISTINCT FROM v_lib
       OR (SELECT library_id FROM public.catalog_batches WHERE id = v_lot) IS DISTINCT FROM v_libB
       OR NOT (SELECT editorial_decision = 'reject' AND discarded_draft_id = v_d AND created_book_draft_id IS NULL
                 FROM ingest.partner_catalog_staging_rows WHERE id = v_row) THEN
      RAISE EXCEPTION 'decor : brouillon=% suppression=% journal=% reattribution=% ligne=%', v_d, v_n, v_audit,
        left(coalesce(v_res::text,'NULL'), 150),
        (SELECT row(editorial_decision, discarded_draft_id, created_book_draft_id)::text FROM ingest.partner_catalog_staging_rows WHERE id = v_row);
    END IF;
    -- « Restaurer » par l'administration, sortie de corbeille
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_res2 := public.fn_restore_deleted_draft(v_audit);
    UPDATE public.book_drafts SET status = 'draft' WHERE id = v_d;
    EXECUTE 'RESET ROLE';
    -- la coordination du run (BLMF) : « En attente », « Accepté (nouveau) »,
    -- promotion — rien
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_res3 := public.fn_import_set_editorial(v_run, ARRAY[v_row], 'pending', NULL);
    v_res5 := public.fn_import_set_editorial(v_run, ARRAY[v_row], 'accept_new', NULL);
    v_res4 := public.fn_import_promote(v_run, p_row_ids := ARRAY[v_row]);
    EXECUTE 'RESET ROLE';
    IF coalesce((v_res2->>'ok')::boolean, false)
       AND (SELECT created_book_draft_id = v_d AND editorial_decision = 'accept_new' AND review_status = 'draft_created'
                   AND discarded_draft_id IS NULL
              FROM ingest.partner_catalog_staging_rows WHERE id = v_row)
       AND (SELECT count(*) FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row) = 1
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft m
                    WHERE m.staging_row_id = v_row AND m.draft_id = v_d AND m.run_id = v_run AND m.batch_id IS NULL)
       AND (SELECT owner_library_id = v_libB AND batch_id = v_lot FROM public.book_drafts WHERE id = v_d)
       AND (v_res3->>'updated_rows')::int = 0 AND (v_res3->>'skipped_rows')::int = 1
       AND (v_res5->>'updated_rows')::int = 0 AND (v_res5->>'skipped_rows')::int = 1
       AND coalesce((v_res4->>'selected_count')::int, 0) = 0 AND v_res4->>'batch_id' IS NULL
       AND (SELECT count(*) FROM public.book_drafts d WHERE d.marc_json->'ingest'->>'staging_row_id' = v_row::text) = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : rejeu='||coalesce(v_res2::text,'NULL')
         ||' ligne='||coalesce((SELECT row(created_book_draft_id, editorial_decision, review_status, discarded_draft_id)::text
                                  FROM ingest.partner_catalog_staging_rows WHERE id = v_row), 'absente')
         ||' liens='||coalesce((SELECT string_agg(row(m.draft_id, m.batch_id)::text, ',') FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row), 'aucun')
         ||' brouillon='||coalesce((SELECT row(owner_library_id = v_libB, batch_id)::text FROM public.book_drafts WHERE id = v_d), 'absent')
         ||' en attente='||coalesce((v_res3 - 'run_id')::text,'NULL')||' accepte='||coalesce((v_res5 - 'run_id')::text,'NULL')
         ||' promotion='||left(coalesce(v_res4::text,'NULL'), 150)
         ||' brouillons de la ligne='||(SELECT count(*) FROM public.book_drafts d WHERE d.marc_json->'ingest'->>'staging_row_id' = v_row::text)); END IF;
  EXCEPTION WHEN OTHERS THEN
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T27 ─────────────────────────────────────────────────────────────
  v_t := 'T27 (c) exemplaire rapproche : par l''API ''published'' refuse (UPDATE et INSERT, 42501), ''ready'' passe ; le run reste retenu';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
    VALUES ('H21A Notice existante T27', 'H21A-T27-N', 'livro', v_lib) RETURNING id INTO v_book;
    INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_book, v_lib);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21a-t27.marc', 'h21a-t27.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, proposed_book_id, normalized_payload)
    VALUES (v_run, 1, 'H21A-T27', 'H21A Doublon rapproche, statut force', 'matched_book', 'pending', v_book,
            jsonb_build_object('items', '[{"source_item_code":"H21A-T27-C1","call_number":"H21A 27"}]'::jsonb)) RETURNING id INTO v_row;
    -- « Rapprocher » : un lot de rapprochement, un exemplaire sans notice importée, aucun tour
    v_res := public.fn_import_reconcile_duplicates(v_run, ARRAY[v_row]);
    SELECT x.id INTO v_x FROM public.exemplar_drafts x WHERE x.import_staging_row_id = v_row AND x.book_draft_id IS NULL;
    IF v_x IS NULL OR (SELECT status FROM public.exemplar_drafts WHERE id = v_x) <> 'draft' THEN
      RAISE EXCEPTION 'decor : rapprochement=% exemplaire=%', left(coalesce(v_res::text,'NULL'), 200), v_x;
    END IF;
    v_hint := NULL; v_st := NULL; v_hint2 := NULL; v_st2 := NULL; v_txt := '';
    EXECUTE 'SET LOCAL ROLE authenticated';
    -- (1) 'ready' : le formulaire — passe
    UPDATE public.exemplar_drafts SET status = 'ready' WHERE id = v_x;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    IF v_n <> 1 THEN v_txt := v_txt || ' ready=' || v_n; END IF;
    -- (2) 'published' posé par l'API : refusé (il libérait le run, T20/#0)
    BEGIN UPDATE public.exemplar_drafts SET status = 'published' WHERE id = v_x; v_hint := 'accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT, v_st = RETURNED_SQLSTATE; END;
    -- (3) INSERT en 'published' : refusé ; le même INSERT en 'draft' passe
    BEGIN
      INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, target_bib_ref, shelf_location, created_by)
      VALUES ('create', 'published', 'pending', v_lib, 'H21A-T27-N', 'H21A T27 insere publie', v_coord);
      v_hint2 := 'accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint2 = PG_EXCEPTION_HINT, v_st2 = RETURNED_SQLSTATE; END;
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, target_bib_ref, shelf_location, created_by)
    VALUES ('create', 'draft', 'pending', v_lib, 'H21A-T27-N', 'H21A T27 insere en cours', v_coord);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    IF v_n <> 1 THEN v_txt := v_txt || ' insert_draft=' || v_n; END IF;
    EXECUTE 'RESET ROLE';
    -- « Supprimer le run » : l'exemplaire, resté en attente, le retient
    v_hint3 := NULL;
    BEGIN PERFORM public.fn_import_delete_run(v_run); v_hint3 := 'supprime';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint3 = PG_EXCEPTION_HINT; END;
    IF v_hint = 'error.publish.status_reserved' AND v_st = '42501'
       AND v_hint2 = 'error.publish.status_reserved' AND v_st2 = '42501'
       AND v_txt = ''
       AND (SELECT status = 'ready' AND published_exemplar_id IS NULL AND import_staging_row_id = v_row AND book_draft_id IS NULL
              FROM public.exemplar_drafts WHERE id = v_x)
       AND NOT EXISTS (SELECT 1 FROM public.exemplar_drafts WHERE shelf_location = 'H21A T27 insere publie')
       AND (SELECT status FROM public.exemplar_drafts WHERE shelf_location = 'H21A T27 insere en cours') = 'draft'
       AND v_hint3 = 'error.import.run_has_drafts'
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_import_runs WHERE id = v_run)
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows WHERE id = v_row AND run_id = v_run)
       AND NOT EXISTS (SELECT 1 FROM public.exemplares WHERE source_item_code = 'H21A-T27-C1')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : update='||coalesce(v_hint,'NULL')||'/'||coalesce(v_st,'-')
         ||' insert='||coalesce(v_hint2,'NULL')||'/'||coalesce(v_st2,'-')||' ['||v_txt||' ]'
         ||' exemplaire='||coalesce((SELECT row(status, published_exemplar_id, import_staging_row_id)::text FROM public.exemplar_drafts WHERE id = v_x), 'absent')
         ||' suppression du run='||coalesce(v_hint3,'NULL')
         ||' run='||EXISTS (SELECT 1 FROM ingest.partner_catalog_import_runs WHERE id = v_run)); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T28 ─────────────────────────────────────────────────────────────
  v_t := 'T28 (e, ordre B) D1 purge, ligne repromue (en postgres) en D2, D2 purge : le journal refuse D1 (restore_line_repromoted), rejoue D2 qui reprend la ligne ; un seul brouillon';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21a-t28.marc', 'h21a-t28.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 1, 'H21A-T28', 'H21A Ordre B', 'new_record', 'accept_new') RETURNING id INTO v_row;
    -- D1 : promu, jeté, purgé (API) — la ligne écartée par D1
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_lot := (public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
    EXECUTE 'RESET ROLE';
    SELECT m.draft_id INTO v_d FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row;
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET status = 'cancelled' WHERE id = v_d;
    DELETE FROM public.book_drafts WHERE id = v_d;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    EXECUTE 'RESET ROLE';
    -- la repromotion, que l'API ne construit plus (T17) : posée EN POSTGRES
    -- (décision « Accepté (nouveau) » sur la ligne, discarded_draft_id vidé),
    -- puis « Promouvoir » (API) : D2 ; D2 jeté, purgé (API) — la ligne écartée
    -- par D2 (discarded_draft_id réécrit)
    UPDATE ingest.partner_catalog_staging_rows
       SET editorial_decision = 'accept_new', review_status = 'approved', selected_for_draft = true,
           editorial_note = NULL, discarded_draft_id = NULL
     WHERE id = v_row;
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_res := public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new']);
    EXECUTE 'RESET ROLE';
    SELECT m.draft_id INTO v_d2 FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row;
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET status = 'cancelled' WHERE id = v_d2;
    DELETE FROM public.book_drafts WHERE id = v_d2;
    GET DIAGNOSTICS v_m = ROW_COUNT;
    EXECUTE 'RESET ROLE';
    SELECT max(l.id) INTO v_audit  FROM public.catalog_audit_log l WHERE l.action = 'delete' AND l.entity_type = 'book' AND l.entity_id = v_d;
    SELECT max(l.id) INTO v_audit2 FROM public.catalog_audit_log l WHERE l.action = 'delete' AND l.entity_type = 'book' AND l.entity_id = v_d2;
    IF v_d IS NULL OR v_n <> 1 OR (v_res->>'selected_count')::int IS DISTINCT FROM 1
       OR v_d2 IS NULL OR v_d2 = v_d OR v_m <> 1 OR v_audit IS NULL OR v_audit2 IS NULL
       OR NOT (SELECT editorial_decision = 'reject' AND discarded_draft_id = v_d2 AND created_book_draft_id IS NULL
                 FROM ingest.partner_catalog_staging_rows WHERE id = v_row)
       OR EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row) THEN
      RAISE EXCEPTION 'decor : D1=% purge=% repromotion=% D2=% purge=% journal=%/% ligne=%', v_d, v_n,
        left(coalesce(v_res::text,'NULL'), 150), v_d2, v_m, v_audit, v_audit2,
        (SELECT row(editorial_decision, discarded_draft_id, created_book_draft_id)::text FROM ingest.partner_catalog_staging_rows WHERE id = v_row);
    END IF;
    -- « Restaurer » (coordination, API) : D1, dont la ligne a été libérée depuis
    -- par D2 — refus, rien de rejoué ni journalisé ; puis D2 — reprise ; puis D1
    -- de nouveau — toujours refusé (la ligne est à D2)
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_hint := NULL;
    BEGIN PERFORM public.fn_restore_deleted_draft(v_audit); v_hint := 'rejoue';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    EXECUTE 'RESET ROLE';
    v_ok := NOT EXISTS (SELECT 1 FROM public.book_drafts WHERE id = v_d)
            AND NOT EXISTS (SELECT 1 FROM public.catalog_audit_log l
                             WHERE l.action = 'restore' AND l.details->>'from_audit_id' = v_audit::text)
            AND (SELECT discarded_draft_id = v_d2 AND created_book_draft_id IS NULL
                   FROM ingest.partner_catalog_staging_rows WHERE id = v_row);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_hint2 := NULL; v_res2 := NULL;
    BEGIN v_res2 := public.fn_restore_deleted_draft(v_audit2);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint2 = PG_EXCEPTION_HINT; v_hint2 := coalesce(v_hint2, SQLERRM); END;
    v_hint3 := NULL;
    BEGIN PERFORM public.fn_restore_deleted_draft(v_audit); v_hint3 := 'rejoue';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint3 = PG_EXCEPTION_HINT; END;
    EXECUTE 'RESET ROLE';
    IF v_hint = 'error.catalog.restore_line_repromoted' AND coalesce(v_ok, false)
       AND v_hint2 IS NULL AND coalesce((v_res2->>'ok')::boolean, false)
       AND v_hint3 = 'error.catalog.restore_line_repromoted'
       AND NOT EXISTS (SELECT 1 FROM public.book_drafts WHERE id = v_d)
       AND EXISTS (SELECT 1 FROM public.book_drafts WHERE id = v_d2)
       AND (SELECT count(*) FROM public.book_drafts d WHERE d.marc_json->'ingest'->>'staging_row_id' = v_row::text) = 1
       AND (SELECT created_book_draft_id = v_d2 AND editorial_decision = 'accept_new' AND review_status = 'draft_created'
                   AND discarded_draft_id IS NULL
              FROM ingest.partner_catalog_staging_rows WHERE id = v_row)
       AND (SELECT count(*) FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row) = 1
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft m
                    WHERE m.staging_row_id = v_row AND m.draft_id = v_d2 AND m.run_id = v_run AND m.batch_id IS NULL)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : rejeu D1='||coalesce(v_hint,'NULL')||' rien rejoue='||coalesce(v_ok::text,'NULL')
         ||' rejeu D2='||coalesce(v_hint2, coalesce(v_res2::text,'NULL'))||' D1 de nouveau='||coalesce(v_hint3,'NULL')
         ||' brouillons de la ligne='||(SELECT count(*) FROM public.book_drafts d WHERE d.marc_json->'ingest'->>'staging_row_id' = v_row::text)
         ||' ligne='||coalesce((SELECT row(created_book_draft_id, editorial_decision, review_status, discarded_draft_id)::text
                                  FROM ingest.partner_catalog_staging_rows WHERE id = v_row), 'absente')
         ||' liens='||coalesce((SELECT string_agg(row(m.draft_id, m.batch_id)::text, ',') FROM ingest.partner_catalog_row_to_draft m
                                 WHERE m.staging_row_id = v_row), 'aucun')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T29 ─────────────────────────────────────────────────────────────
  v_t := 'T29 (c) le declencheur retient une ligne sous un exemplaire rapproche non publie (corbeille, en cours) : le DELETE de l''edge function (service_role) et celui de postgres refuses (rows_held_by_items), rien d''efface ; publie, il ne la retient pas';
  BEGIN
    INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active') ON CONFLICT DO NOTHING;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
    VALUES ('H21A Notice existante T29', 'H21A-T29-N', 'livro', v_lib) RETURNING id INTO v_book;
    INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_book, v_lib);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21a-t29.marc', 'h21a-t29.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    -- trois lignes qui redécrivent la notice, un exemplaire chacune
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, proposed_book_id, normalized_payload)
    VALUES (v_run, 1, 'H21A-T29-1', 'H21A Doublon rapproche, exemplaire a la corbeille', 'matched_book', 'pending', v_book,
            jsonb_build_object('items', '[{"source_item_code":"H21A-T29-C1","call_number":"H21A 29-1"}]'::jsonb)) RETURNING id INTO v_row;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, proposed_book_id, normalized_payload)
    VALUES (v_run, 2, 'H21A-T29-2', 'H21A Doublon rapproche, exemplaire en cours', 'matched_book', 'pending', v_book,
            jsonb_build_object('items', '[{"source_item_code":"H21A-T29-C2","call_number":"H21A 29-2"}]'::jsonb)) RETURNING id INTO v_row2;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, proposed_book_id, normalized_payload)
    VALUES (v_run, 3, 'H21A-T29-3', 'H21A Doublon rapproche, exemplaire publie', 'matched_book', 'pending', v_book,
            jsonb_build_object('items', '[{"source_item_code":"H21A-T29-C3","call_number":"H21A 29-3"}]'::jsonb)) RETURNING id INTO v_row3;
    -- « Rapprocher » : un lot de rapprochement, trois exemplaires sans notice importée
    v_res := public.fn_import_reconcile_duplicates(v_run, ARRAY[v_row, v_row2, v_row3]);
    v_main := (v_res->>'batch_id')::bigint;
    SELECT x.id INTO v_x  FROM public.exemplar_drafts x WHERE x.import_staging_row_id = v_row  AND x.book_draft_id IS NULL;
    SELECT x.id INTO v_x2 FROM public.exemplar_drafts x WHERE x.import_staging_row_id = v_row2 AND x.book_draft_id IS NULL;
    SELECT x.id INTO v_x3 FROM public.exemplar_drafts x WHERE x.import_staging_row_id = v_row3 AND x.book_draft_id IS NULL;
    -- le lot révisé (demande de la coordination, approbation de l'administration),
    -- l'exemplaire 3 publié ; l'exemplaire 1 à la corbeille (API) ; le 2 reste en cours
    v_res2 := public.fn_batch_review_request(v_main, 'H21A T29 : exemplaires rapproches');
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict((v_res2->>'review_id')::bigint, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_ex := public.publish_exemplar_draft(v_x3);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.exemplar_drafts SET status = 'cancelled' WHERE id = v_x;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    EXECUTE 'RESET ROLE';
    IF v_main IS NULL OR v_x IS NULL OR v_x2 IS NULL OR v_x3 IS NULL OR v_ex IS NULL OR v_n <> 1
       OR (SELECT string_agg(x.status || ':' || coalesce(x.import_staging_row_id::text, 'NULL'), ',' ORDER BY x.id)
             FROM public.exemplar_drafts x WHERE x.id IN (v_x, v_x2, v_x3))
          IS DISTINCT FROM ('cancelled:' || v_row || ',draft:' || v_row2 || ',published:' || v_row3) THEN
      RAISE EXCEPTION 'decor : rapprochement=% revision=% exemplaires=%/%/% publie=% corbeille=% etats=%',
        left(coalesce(v_res::text,'NULL'), 150), left(coalesce(v_res2::text,'NULL'), 100), v_x, v_x2, v_x3, v_ex, v_n,
        (SELECT string_agg(x.id || '=' || x.status || ':' || coalesce(x.import_staging_row_id::text, 'NULL'), ',' ORDER BY x.id)
           FROM public.exemplar_drafts x WHERE x.id IN (v_x, v_x2, v_x3));
    END IF;
    -- le DELETE … WHERE run_id de l'edge function process-partner-catalog-import
    -- au retraitement (force_reparse), en service_role — refusé par le
    -- déclencheur ; l'instruction échoue en bloc, la ligne 3 n'est pas effacée
    -- non plus. (Le geste « Retraiter » de l'écran n'arrive plus jusqu'ici pour
    -- ce run : fn_import_dispatch le refuse en amont, T30.)
    v_hint := NULL; v_hint2 := NULL; v_hint3 := NULL;
    EXECUTE 'SET LOCAL ROLE service_role';
    BEGIN DELETE FROM ingest.partner_catalog_staging_rows WHERE run_id = v_run; v_hint := 'efface';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    EXECUTE 'RESET ROLE';
    -- chaque ligne retenue, seule, même en postgres : celle de l'exemplaire à la
    -- corbeille, celle de l'exemplaire en cours
    BEGIN DELETE FROM ingest.partner_catalog_staging_rows WHERE id = v_row; v_hint2 := 'efface';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint2 = PG_EXCEPTION_HINT; END;
    BEGIN DELETE FROM ingest.partner_catalog_staging_rows WHERE id = v_row2; v_hint3 := 'efface';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint3 = PG_EXCEPTION_HINT; END;
    -- non-action : les trois lignes et le run sont là, chaque exemplaire garde sa ligne
    v_ok := EXISTS (SELECT 1 FROM ingest.partner_catalog_import_runs WHERE id = v_run)
            AND (SELECT count(*) FROM ingest.partner_catalog_staging_rows WHERE run_id = v_run) = 3
            AND (SELECT string_agg(x.status || ':' || coalesce(x.import_staging_row_id::text, 'NULL'), ',' ORDER BY x.id)
                   FROM public.exemplar_drafts x WHERE x.id IN (v_x, v_x2, v_x3))
                = ('cancelled:' || v_row || ',draft:' || v_row2 || ',published:' || v_row3);
    v_txt := coalesce((SELECT string_agg(x.id || '=' || x.status || ':' || coalesce(x.import_staging_row_id::text, 'NULL'), ',' ORDER BY x.id)
                         FROM public.exemplar_drafts x WHERE x.id IN (v_x, v_x2, v_x3)), 'aucun');
    -- la ligne de l'exemplaire PUBLIÉ ne l'est pas (service_role) : elle
    -- s'efface, l'exemplaire publié la perd (clé étrangère SET NULL)
    v_hint4 := NULL; v_m := NULL;
    EXECUTE 'SET LOCAL ROLE service_role';
    BEGIN DELETE FROM ingest.partner_catalog_staging_rows WHERE id = v_row3; GET DIAGNOSTICS v_m = ROW_COUNT;
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint4 = PG_EXCEPTION_HINT; v_hint4 := coalesce(nullif(v_hint4, ''), SQLERRM); END;
    EXECUTE 'RESET ROLE';
    IF v_hint = 'error.import.rows_held_by_items'
       AND v_hint2 = 'error.import.rows_held_by_items' AND v_hint3 = 'error.import.rows_held_by_items'
       AND v_ok
       AND v_hint4 IS NULL AND v_m = 1
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows WHERE id = v_row3)
       AND (SELECT status = 'published' AND import_staging_row_id IS NULL AND published_exemplar_id = v_ex
              FROM public.exemplar_drafts WHERE id = v_x3)
       AND EXISTS (SELECT 1 FROM public.exemplares WHERE id = v_ex)
       AND (SELECT count(*) FROM ingest.partner_catalog_staging_rows WHERE id IN (v_row, v_row2)) = 2
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : delete edge function='||coalesce(v_hint,'NULL')
         ||' corbeille='||coalesce(v_hint2,'NULL')||' en cours='||coalesce(v_hint3,'NULL')
         ||' rien efface='||coalesce(v_ok::text,'NULL')||' exemplaires apres les refus='||v_txt
         ||' publie='||coalesce(v_hint4, 'efface '||coalesce(v_m::text,'NULL'))
         ||' lignes='||(SELECT count(*) FROM ingest.partner_catalog_staging_rows WHERE run_id = v_run)
         ||' exemplaire publie='||coalesce((SELECT row(status, import_staging_row_id, published_exemplar_id)::text
                                            FROM public.exemplar_drafts WHERE id = v_x3), 'absent')); END IF;
  EXCEPTION WHEN OTHERS THEN
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T30 ─────────────────────────────────────────────────────────────
  v_t := 'T30 (c, e) « Retraiter » (fn_import_dispatch) refuse tout de suite (reparse_after_promotion) un run dont l''exemplaire rapproche est a la corbeille ou dont une ligne est ecartee, run et lignes intacts ; sans conversion, ou l''exemplaire purge, accepte ; aucune requete pg_net';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_hint := NULL; v_hint2 := NULL; v_hint6 := NULL; v_hint7 := NULL;
    v_res2 := NULL; v_res3 := NULL; v_res9 := NULL; v_res10 := NULL;
    v_etat0 := NULL; v_etat1 := NULL; v_q0 := NULL; v_q1 := NULL; v_q2 := NULL;
    -- Sous-transaction LEVÉE : l'envoi réel (ingest.fn_dispatch_partner_catalog_import,
    -- net.http_post vers l'URL des edge functions de l'instance avec le secret du
    -- coffre — sur le banc local, celles de la PRODUCTION) est remplacé par un
    -- témoin ; décor, appels et mesures s'y jouent, puis le RAISE final du bloc
    -- annule tout, témoin compris : rien ne fuit vers T24 ni vers les suites
    -- suivantes (run-sql-suites.sh ne joue pas la suite dans une transaction).
    BEGIN
      EXECUTE $f$CREATE OR REPLACE FUNCTION ingest.fn_dispatch_partner_catalog_import(p_run_id bigint, p_force_reparse boolean DEFAULT false)
        RETURNS jsonb LANGUAGE sql
        AS $b$ SELECT jsonb_build_object('temoin_h21_t30', true, 'run_id', p_run_id, 'force_reparse', p_force_reparse) $b$ $f$;
      SELECT count(*) INTO v_q0 FROM net.http_request_queue;
      -- (a) un exemplaire RAPPROCHÉ, seul produit du run, à la corbeille (API)
      INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
      VALUES ('H21A Notice existante T30', 'H21A-T30-N', 'livro', v_lib) RETURNING id INTO v_book;
      INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_book, v_lib);
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
      VALUES (v_src, v_lib, 'essai/h21a-t30a.marc', 'h21a-t30a.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
      INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, proposed_book_id, normalized_payload)
      VALUES (v_run, 1, 'H21A-T30-A', 'H21A Doublon rapproche, exemplaire a la corbeille', 'matched_book', 'pending', v_book,
              jsonb_build_object('items', '[{"source_item_code":"H21A-T30-C1","call_number":"H21A 30-1"}]'::jsonb)) RETURNING id INTO v_row;
      EXECUTE 'SET LOCAL ROLE authenticated';
      v_res := public.fn_import_reconcile_duplicates(v_run, ARRAY[v_row]);
      EXECUTE 'RESET ROLE';
      SELECT x.id INTO v_x FROM public.exemplar_drafts x WHERE x.import_staging_row_id = v_row AND x.book_draft_id IS NULL;
      EXECUTE 'SET LOCAL ROLE authenticated';
      UPDATE public.exemplar_drafts SET status = 'cancelled' WHERE id = v_x;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      EXECUTE 'RESET ROLE';
      -- (b) une ligne ÉCARTÉE : promue (API), son brouillon jeté puis purgé
      -- (API) ; aucune autre promotion dans le run — le lien est parti avec le
      -- brouillon, seule discarded_draft_id retient
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
      VALUES (v_src, v_lib, 'essai/h21a-t30b.marc', 'h21a-t30b.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run2;
      INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
      VALUES (v_run2, 1, 'H21A-T30-B', 'H21A Ligne ecartee puis retraitee', 'new_record', 'accept_new') RETURNING id INTO v_row2;
      EXECUTE 'SET LOCAL ROLE authenticated';
      v_res8 := public.fn_import_promote(v_run2, ARRAY['new_record'], ARRAY['accept_new']);
      EXECUTE 'RESET ROLE';
      SELECT m.draft_id INTO v_d FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row2;
      EXECUTE 'SET LOCAL ROLE authenticated';
      UPDATE public.book_drafts SET status = 'cancelled' WHERE id = v_d;
      DELETE FROM public.book_drafts WHERE id = v_d;
      GET DIAGNOSTICS v_m = ROW_COUNT;
      EXECUTE 'RESET ROLE';
      -- (c) NON-RÉGRESSION : ni promotion ni rapprochement
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
      VALUES (v_src, v_lib, 'essai/h21a-t30c.marc', 'h21a-t30c.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run3;
      INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
      VALUES (v_run3, 1, 'H21A-T30-C', 'H21A Run jamais converti', 'new_record', 'pending') RETURNING id INTO v_row3;
      -- (d) NON-RÉGRESSION : l'exemplaire rapproché PURGÉ (corbeille, puis
      -- « Vider la corbeille », API) ne retient plus rien
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
      VALUES (v_src, v_lib, 'essai/h21a-t30d.marc', 'h21a-t30d.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run4;
      INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, proposed_book_id, normalized_payload)
      VALUES (v_run4, 1, 'H21A-T30-D', 'H21A Doublon rapproche, exemplaire purge', 'matched_book', 'pending', v_book,
              jsonb_build_object('items', '[{"source_item_code":"H21A-T30-C4","call_number":"H21A 30-4"}]'::jsonb)) RETURNING id INTO v_row4;
      EXECUTE 'SET LOCAL ROLE authenticated';
      v_res4 := public.fn_import_reconcile_duplicates(v_run4, ARRAY[v_row4]);
      EXECUTE 'RESET ROLE';
      SELECT x.id INTO v_x4 FROM public.exemplar_drafts x WHERE x.import_staging_row_id = v_row4 AND x.book_draft_id IS NULL;
      EXECUTE 'SET LOCAL ROLE authenticated';
      UPDATE public.exemplar_drafts SET status = 'cancelled' WHERE id = v_x4;
      DELETE FROM public.exemplar_drafts WHERE id = v_x4;
      GET DIAGNOSTICS v_k = ROW_COUNT;
      EXECUTE 'RESET ROLE';
      -- le décor est bien celui qu'on croit : (a) retenu par SON seul exemplaire
      -- à la corbeille, (b) par SA seule ligne écartée ; rien d'autre ne retient
      -- aucun des quatre runs (aucun lien, aucun autre exemplaire, aucune autre
      -- ligne écartée), aucun envoi journalisé
      IF v_x IS NULL OR v_n <> 1 OR v_d IS NULL OR v_m <> 1 OR v_x4 IS NULL OR v_k <> 1
         OR NOT (SELECT status = 'cancelled' AND book_draft_id IS NULL AND import_staging_row_id = v_row
                   FROM public.exemplar_drafts WHERE id = v_x)
         OR (SELECT count(*) FROM public.exemplar_drafts x
               JOIN ingest.partner_catalog_staging_rows sr ON sr.id = x.import_staging_row_id
              WHERE sr.run_id IN (v_run, v_run2, v_run3, v_run4)) <> 1
         OR EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft m WHERE m.run_id IN (v_run, v_run2, v_run3, v_run4))
         OR NOT (SELECT discarded_draft_id = v_d AND created_book_draft_id IS NULL AND editorial_decision = 'reject'
                   FROM ingest.partner_catalog_staging_rows WHERE id = v_row2)
         OR (SELECT count(*) FROM ingest.partner_catalog_staging_rows
              WHERE run_id IN (v_run, v_run2, v_run3, v_run4) AND discarded_draft_id IS NOT NULL) <> 1
         OR EXISTS (SELECT 1 FROM public.book_drafts WHERE id = v_d)
         OR EXISTS (SELECT 1 FROM ingest.partner_catalog_import_dispatch_log
                     WHERE run_id IN (v_run, v_run2, v_run3, v_run4)) THEN
        RAISE EXCEPTION 'decor : rapprochement=% exemplaire=% corbeille=% promotion=% brouillon=% purge=% ligne ecartee=% exemplaire purge=%/%',
          left(coalesce(v_res::text,'NULL'), 120), v_x, v_n, left(coalesce(v_res8::text,'NULL'), 120), v_d, v_m,
          (SELECT row(editorial_decision, discarded_draft_id, created_book_draft_id)::text FROM ingest.partner_catalog_staging_rows WHERE id = v_row2),
          v_x4, v_k;
      END IF;
      -- état des quatre runs AVANT : statut, et pour chaque ligne id, décision,
      -- brouillon qui l'a écartée ; l'exemplaire de (a) et sa ligne
      SELECT string_agg(r.id || '=' || r.run_status || '[' ||
               coalesce((SELECT string_agg(sr.id || ':' || sr.editorial_decision || ':' || coalesce(sr.discarded_draft_id::text, '-'), ',' ORDER BY sr.id)
                           FROM ingest.partner_catalog_staging_rows sr WHERE sr.run_id = r.id), '') || ']', ' ' ORDER BY r.id)
             || ' x=' || coalesce((SELECT x.status || ':' || coalesce(x.import_staging_row_id::text, 'NULL') FROM public.exemplar_drafts x WHERE x.id = v_x), 'absent')
        INTO v_etat0
        FROM ingest.partner_catalog_import_runs r WHERE r.id IN (v_run, v_run2, v_run3, v_run4);
      -- « Retraiter » (ImportacoesPage.handleReprocess : fn_import_dispatch,
      -- force_reparse), par l'API, coordination de BLMF
      EXECUTE 'SET LOCAL ROLE authenticated';
      BEGIN v_res2 := public.fn_import_dispatch(v_run, true); v_hint := 'accepte ' || left(coalesce(v_res2::text, 'NULL'), 80);
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_hint := coalesce(nullif(v_hint, ''), SQLERRM); END;
      BEGIN v_res3 := public.fn_import_dispatch(v_run2, true); v_hint2 := 'accepte ' || left(coalesce(v_res3::text, 'NULL'), 80);
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint2 = PG_EXCEPTION_HINT; v_hint2 := coalesce(nullif(v_hint2, ''), SQLERRM); END;
      BEGIN v_res9 := public.fn_import_dispatch(v_run3, true);
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint6 = PG_EXCEPTION_HINT; v_hint6 := coalesce(nullif(v_hint6, ''), SQLERRM); END;
      BEGIN v_res10 := public.fn_import_dispatch(v_run4, true);
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint7 = PG_EXCEPTION_HINT; v_hint7 := coalesce(nullif(v_hint7, ''), SQLERRM); END;
      EXECUTE 'RESET ROLE';
      -- APRÈS : même état, aucune requête pg_net, aucun envoi journalisé
      SELECT string_agg(r.id || '=' || r.run_status || '[' ||
               coalesce((SELECT string_agg(sr.id || ':' || sr.editorial_decision || ':' || coalesce(sr.discarded_draft_id::text, '-'), ',' ORDER BY sr.id)
                           FROM ingest.partner_catalog_staging_rows sr WHERE sr.run_id = r.id), '') || ']', ' ' ORDER BY r.id)
             || ' x=' || coalesce((SELECT x.status || ':' || coalesce(x.import_staging_row_id::text, 'NULL') FROM public.exemplar_drafts x WHERE x.id = v_x), 'absent')
        INTO v_etat1
        FROM ingest.partner_catalog_import_runs r WHERE r.id IN (v_run, v_run2, v_run3, v_run4);
      SELECT count(*) INTO v_q1 FROM net.http_request_queue;
      SELECT count(*) INTO v_q2 FROM ingest.partner_catalog_import_dispatch_log WHERE run_id IN (v_run, v_run2, v_run3, v_run4);
      RAISE EXCEPTION 'h21-t30-annule';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM IS DISTINCT FROM 'h21-t30-annule' THEN RAISE; END IF;
    END;
    -- le témoin est parti avec la sous-transaction : l'envoi réel est revenu
    v_ok2 := position('net.http_post' IN pg_get_functiondef('ingest.fn_dispatch_partner_catalog_import(bigint, boolean)'::regprocedure)) > 0;
    IF v_hint = 'error.import.reparse_after_promotion'
       AND v_hint2 = 'error.import.reparse_after_promotion'
       AND v_hint6 IS NULL AND coalesce((v_res9->>'temoin_h21_t30')::boolean, false)
       AND (v_res9->>'run_id')::bigint = v_run3 AND coalesce((v_res9->>'force_reparse')::boolean, false)
       AND v_hint7 IS NULL AND coalesce((v_res10->>'temoin_h21_t30')::boolean, false)
       AND (v_res10->>'run_id')::bigint = v_run4 AND coalesce((v_res10->>'force_reparse')::boolean, false)
       AND v_etat0 IS NOT NULL AND v_etat1 = v_etat0
       AND v_q0 IS NOT NULL AND v_q1 = v_q0 AND v_q2 = 0
       AND v_ok2
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : exemplaire a la corbeille='||coalesce(v_hint,'NULL')
         ||' ligne ecartee='||coalesce(v_hint2,'NULL')
         ||' sans conversion='||coalesce(v_hint6, left(coalesce(v_res9::text,'NULL'), 80))
         ||' exemplaire purge='||coalesce(v_hint7, left(coalesce(v_res10::text,'NULL'), 80))
         ||' etat avant='||coalesce(v_etat0,'NULL')||' apres='||coalesce(v_etat1,'NULL')
         ||' file pg_net='||coalesce(v_q0::text,'NULL')||'->'||coalesce(v_q1::text,'NULL')
         ||' envois journalises='||coalesce(v_q2::text,'NULL')||' envoi reel restaure='||coalesce(v_ok2::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN
    EXECUTE 'RESET ROLE';
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T24 (en dernier : il coupe des parcours jusqu'à la fin du test) ─────
  v_t := 'T24 (e) l''ecartement lit les lignes par index : index de created_book_draft_id lu, aucun parcours sequentiel de la table (importe, fait a la main)';
  v_gucs := ARRAY[current_setting('enable_seqscan'), current_setting('enable_indexscan'),
                  current_setting('enable_indexonlyscan'), current_setting('plan_cache_mode')];
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21a-t24.marc', 'h21a-t24.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 1, 'H21A-T24', 'H21A Ecartee par index', 'new_record', 'accept_new') RETURNING id INTO v_row;
    v_lot := (public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
    SELECT m.draft_id INTO v_d FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row;
    INSERT INTO public.book_drafts (action, status, titulo, tipo_material, owner_library_id, created_by)
    VALUES ('create', 'draft', 'H21A Faite a la main T24', 'livro', v_lib, v_coord) RETURNING id INTO v_d2;
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET status = 'cancelled' WHERE id IN (v_d, v_d2);
    EXECUTE 'RESET ROLE';
    IF v_d IS NULL OR (SELECT created_book_draft_id FROM ingest.partner_catalog_staging_rows WHERE id = v_row) IS DISTINCT FROM v_d THEN
      RAISE EXCEPTION 'decor : promotion (brouillon %)', v_d;
    END IF;
    v_oid_idx := 'ingest.ix_partner_catalog_staging_rows_created_book_draft_id'::regclass;
    v_oid_tbl := 'ingest.partner_catalog_staging_rows'::regclass;
    -- restent les parcours bitmap, qui exigent une condition d'index ; les
    -- plans (du déclencheur compris) sont refaits sous ces réglages
    PERFORM set_config('enable_seqscan', 'off', true);
    PERFORM set_config('enable_indexscan', 'off', true);
    PERFORM set_config('enable_indexonlyscan', 'off', true);
    PERFORM set_config('plan_cache_mode', 'force_custom_plan', true);
    -- « Vider la corbeille » (API), un brouillon à la fois : RETURNING lit les
    -- compteurs après le déclencheur BEFORE DELETE, avant l'action de la clé
    -- étrangère (ON DELETE SET NULL, qui lit aussi l'index)
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_i0 := pg_stat_get_xact_numscans(v_oid_idx); v_s0 := pg_stat_get_xact_numscans(v_oid_tbl);
    DELETE FROM public.book_drafts WHERE id = v_d
      RETURNING pg_stat_get_xact_numscans(v_oid_idx), pg_stat_get_xact_numscans(v_oid_tbl) INTO v_i1, v_s1;
    v_i2 := pg_stat_get_xact_numscans(v_oid_idx); v_s2 := pg_stat_get_xact_numscans(v_oid_tbl);
    DELETE FROM public.book_drafts WHERE id = v_d2
      RETURNING pg_stat_get_xact_numscans(v_oid_idx), pg_stat_get_xact_numscans(v_oid_tbl) INTO v_i3, v_s3;
    EXECUTE 'RESET ROLE';
    PERFORM set_config('enable_seqscan', v_gucs[1], true);
    PERFORM set_config('enable_indexscan', v_gucs[2], true);
    PERFORM set_config('enable_indexonlyscan', v_gucs[3], true);
    PERFORM set_config('plan_cache_mode', v_gucs[4], true);
    IF v_i1 - v_i0 >= 1 AND v_s1 - v_s0 = 0
       AND v_i3 - v_i2 >= 1 AND v_s3 - v_s2 = 0
       AND (SELECT editorial_decision = 'reject' AND review_status = 'rejected' AND created_book_draft_id IS NULL
              FROM ingest.partner_catalog_staging_rows WHERE id = v_row)
       AND NOT EXISTS (SELECT 1 FROM public.book_drafts WHERE id IN (v_d, v_d2))
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : importe index='||(v_i1 - v_i0)||' sequentiels='||(v_s1 - v_s0)
         ||' (index apres l''instruction='||(v_i2 - v_i0)||')'
         ||' fait main index='||(v_i3 - v_i2)||' sequentiels='||(v_s3 - v_s2)
         ||' ligne='||coalesce((SELECT row(editorial_decision, review_status, created_book_draft_id)::text FROM ingest.partner_catalog_staging_rows WHERE id = v_row), 'absente')); END IF;
  EXCEPTION WHEN OTHERS THEN
    EXECUTE 'RESET ROLE';
    PERFORM set_config('enable_seqscan', v_gucs[1], true);
    PERFORM set_config('enable_indexscan', v_gucs[2], true);
    PERFORM set_config('enable_indexonlyscan', v_gucs[3], true);
    PERFORM set_config('plan_cache_mode', v_gucs[4], true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'REVISION-BROUILLON-IMPORTE OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'REVISION-BROUILLON-IMPORTE ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
