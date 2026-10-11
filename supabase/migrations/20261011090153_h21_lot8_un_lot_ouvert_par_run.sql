-- =====================================================================
-- H21 lot 8 — ce que la preuve de bout en bout a cassé, et IMP-35
-- (constats de tests/sql/h21_bout_en_bout_tests.sql, 11/10/2026)
--   A. un lot ouvert par run : les quatre gestes le retrouvent (IMP-27 d) ;
--   B. un exemplaire réattribué est signalé « parti chez … », jamais recréé
--      (IMP-35, décision de Xavier du 11/10/2026) ;
--   C. « préparable » dans la liste : la partie notice d'une notice partagée
--      ou plus détenue ne compte plus (comme « Préparer » la juge).
--
-- ── A. Un lot ouvert par run ──
-- IMP-27 d : « une sélection rejoint le lot ouvert du run ». Quatre gestes de
-- l'écran créent des brouillons pour un run : « Promouvoir » (notices
-- nouvelles), « Rapprocher » (exemplaires), « Préparer la mise à jour »
-- (lot 4), « Proposer les retraits » (lot 7). Les deux derniers venus
-- cherchent le lot ouvert du run par ingest.fn_h21_lot_ouvert_du_run, qui le
-- reconnaît par l'un quelconque de ses brouillons (lien ligne → brouillon de
-- notice, brouillon d'exemplaire d'une ligne du run, brouillon de retrait ou
-- de levée du run). Les deux premiers le cherchaient encore par le seul lien
-- ligne → brouillon de notice (partner_catalog_row_to_draft) :
--   ingest.fn_create_book_drafts_from_import_rows (la promotion) et
--   ingest.fn_h21_lot_de_la_mise_a_jour (« Préparer »).
-- Constat (tests/sql/h21_bout_en_bout_tests.sql, T06-T08, fichier PMB v2) :
-- « Rapprocher » ouvre le lot du run avec un brouillon d'exemplaire ; ensuite
-- « Préparer » en ouvrait un SECOND (le brouillon d'exemplaire n'a pas de lien
-- ligne → brouillon de notice), et la notice nouvelle promue rejoignait ce
-- second lot — deux révisions pour un run. Même chose après « Proposer les
-- retraits » seul.
--
-- Aucune règle neuve : les deux recherches délèguent à
-- ingest.fn_h21_lot_ouvert_du_run (même bibliothèque, lot ouvert, ni révision
-- demandée ni approuvée — les conditions qu'elles posaient déjà), la création
-- d'un lot quand il n'y en a pas reste la leur, inchangée. La promotion garde
-- son verrou (FOR UPDATE, pris par fn_h21_lot_ouvert_du_run) et son nom de
-- lot repris.
--
-- ── B. IMP-35 : un exemplaire réattribué, « parti chez <bibliothèque> » ──
-- Le constat (ingest.fn_h21_constat_exemplaire — la règle unique de la
-- promotion, de « Rapprocher », des trois états et des retraits) ne cherchait
-- l'exemplaire du fichier que dans la bibliothèque importatrice. Réattribué à
-- une autre (network_admin_reassign_book_to_library…), il y emporte son code,
-- son expl_id et sa source : le constat le disait « nouveau », et
-- « Rapprocher » le recréait chez la bibliothèque importatrice (cas 13 de la
-- suite de bout en bout).
-- Désormais, quand rien n'est trouvé chez la bibliothèque importatrice, le
-- constat cherche l'exemplaire de la SOURCE du run dans les autres
-- bibliothèques. Le même exemplaire, c'est la même source et le même
-- identifiant (IMP-33 a : le code est la clé PAR BIBLIOTHÈQUE, l'expl_id le
-- second signal) : par l'expl_id de même source d'abord ; par le code porté
-- par un exemplaire de cette source seulement quand le fichier ne donne pas
-- d'expl_id pour cet exemplaire, ou que l'exemplaire trouvé n'en a pas. Deux
-- expl_id qui diffèrent : ce n'est pas le même exemplaire (le code recyclé
-- chez une autre bibliothèque ne bloque rien chez soi) — on continue vers
-- deja_en_brouillon ou nouveau (revue du 11/10 : un premier jet disait
-- « code_repris » ailleurs, et bloquait une création légitime). Trouvé : le
-- verdict « reattribue » (exemplaire, tombo, notice, library_id et
-- library_name de la bibliothèque actuelle).
-- Deux index partiels servent ces deux recherches, LIMIT 1 chacune :
-- (import_source_id, source_item_id) et (import_source_id, source_item_code),
-- WHERE import_source_id IS NOT NULL.
-- Ordre des verdicts, du premier au dernier :
--   sans_code (inchangé : sans code-barres, rien n'est cherché) ;
--   chez la bibliothèque importatrice : code_repris, deplace, deja_la (par le
--   code), puis reetiquete (par l'expl_id) — inchangés : un exemplaire présent
--   chez soi l'emporte sur une copie ailleurs ;
--   ailleurs, de la même source : reattribue (par l'expl_id, puis par le code
--   sous la condition dite) ;
--   deja_en_brouillon ; nouveau.
-- « reattribue » passe donc avant « deja_en_brouillon » et « nouveau » : un
-- brouillon vivant chez soi n'efface pas le fait que l'exemplaire est chez une
-- autre. Il ne crée rien (promotion, « Rapprocher ») et n'est pas un signal :
-- une ligne dont tous les exemplaires sont déjà là, en brouillon ou
-- réattribués n'apporte rien et est rejetée d'office (même préfixe de note,
-- que ingest.fn_h21_rejet_par_choix reconnaît) ; aucune mise à jour (6b :
-- raison « autre_bibliotheque ») ; aucun retrait ni levée (le constat des
-- retraits ne retient que deja_la et reetiquete). L'exemplaire garde son code
-- et son expl_id chez l'autre bibliothèque : rien n'y est écrit. Le rapport de
-- révision compte « reattribue » parmi les exemplaires écartés.
--
-- ── C. « Préparable » dans la liste ──
-- public.fn_import_list_run_rows.update_applicable comptait les champs
-- applicables d'une notice partagée ou plus détenue, que « Préparer » ignore
-- (« partagee », « plus_detenue ») : l'écran les comptait dans « Préparer la
-- mise à jour (n) » (constat de src/tests/h21-lot8-ecran.test.jsx). Désormais
-- 0 pour elles, jugées comme « Préparer » les juge (aucun fonds de la
-- bibliothèque importatrice ; un fonds d'une autre). Les exemplaires
-- préparables (exemplaires_maj.applicables, lot 6b) restent comptés à part.
--
-- Définitions de départ : production (projet uflwmikiyjfnikiphtcp, lues le
-- 11/10/2026 par pg_get_functiondef), identiques au dépôt :
--   ingest.fn_create_book_drafts_from_import_rows     3e6003e9dcfca15cebeab73bb054c1eb
--   ingest.fn_h21_lot_de_la_mise_a_jour               3062320d5707cdd2575378b373adbf0b
--   ingest.fn_h21_lot_ouvert_du_run (appelée)         eb85941cb8cefc844bace649b22f5584
--   ingest.fn_h21_constat_exemplaire                  34091d64fdb993e708be1f97bfb9ac37
--   ingest.fn_create_exemplar_drafts_from_import_rows c0ea2eeb82468dc9cd9262c846784c4e
--   ingest.fn_h21_preparer_exemplaires                c5d24092e884861023f5df2c183fb337
--   public.fn_batch_review_report                     05bc5f35c9a7e550ccb83adba6a7afa9
--   public.fn_import_list_run_rows                    41056b5daa6db979b1a6e922d393c10e
--   lues, inchangées : ingest.fn_create_item_drafts_for_batch 58590a2e5b41b4e9fd2af9ed8ad4115e,
--   ingest.fn_h21_exemplaires_trois_etats_lot 870e151c9a1341e89cdc371123ed0661,
--   ingest.fn_h21_retraits_constat 50962e7c83bd3364b392df626753c079,
--   ingest.fn_h21_publier_retrait 828df977944971d5a00f821326ffee9a.
-- Droits : CREATE OR REPLACE les garde ; vérifiés à la fin.
-- Suite : tests/sql/h21_bout_en_bout_tests.sql (A : T06-T08 ; B : T03, T06,
-- T17, T20 ; C : T04).
-- =====================================================================

CREATE OR REPLACE FUNCTION pg_temp.h21l8_remplacer(p_quoi text, p_def text, p_old text, p_new text, p_n int DEFAULT 1)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_n int;
BEGIN
  IF coalesce(p_old, '') = '' THEN
    RAISE EXCEPTION 'H21 lot 8 — % : ancre vide', p_quoi;
  END IF;
  v_n := (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old);
  IF v_n <> p_n THEN
    RAISE EXCEPTION 'H21 lot 8 — % : ancre trouvée % fois (attendu %) — relire la définition réelle', p_quoi, v_n, p_n;
  END IF;
  RETURN replace(p_def, p_old, p_new);
END
$f$;

CREATE OR REPLACE FUNCTION pg_temp.h21l8_def(p_fn regprocedure)
RETURNS text LANGUAGE sql AS $f$
  SELECT replace(pg_get_functiondef(p_fn), E'\r', '');
$f$;


-- ─────────────────────────────────────────────────────────────────────
-- 1. La promotion
-- ─────────────────────────────────────────────────────────────────────
DO $h21l8_promotion$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l8_def('ingest.fn_create_book_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure);
  v_def := pg_temp.h21l8_remplacer('fn_create_book_drafts_from_import_rows (lot du run)', v_def,
$a$  select b.id, b.name into v_lot_repris, v_lot_repris_nom
    from public.catalog_batches b
   where b.status = 'open'
     and b.library_id is not distinct from v_batch_library
     and b.id in (select m.batch_id from ingest.partner_catalog_row_to_draft m
                   where m.run_id = p_run_id and m.batch_id is not null)
     and coalesce(public.fn_batch_review_status(b.id), 'aucune') in ('aucune', 'changes_requested')
   order by b.id desc
   limit 1
   for update of b;
$a$,
$b$  -- H21 lot 8 (11/10/2026) : le lot ouvert du run, reconnu par l'un
  -- quelconque de ses brouillons (ingest.fn_h21_lot_ouvert_du_run, qui le
  -- verrouille) — aussi celui que « Rapprocher », « Préparer » ou « Proposer
  -- les retraits » a ouvert.
  v_lot_repris := ingest.fn_h21_lot_ouvert_du_run(p_run_id, v_batch_library);
  select b.name into v_lot_repris_nom from public.catalog_batches b where b.id = v_lot_repris;
$b$);
  EXECUTE v_def;
END
$h21l8_promotion$;


-- ─────────────────────────────────────────────────────────────────────
-- 2. « Préparer la mise à jour »
-- ─────────────────────────────────────────────────────────────────────
DO $h21l8_preparer$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l8_def('ingest.fn_h21_lot_de_la_mise_a_jour(bigint, uuid, uuid)'::regprocedure);
  v_def := pg_temp.h21l8_remplacer('fn_h21_lot_de_la_mise_a_jour (lot du run)', v_def,
$a$  select b.id into v_batch
    from public.catalog_batches b
   where b.status = 'open'
     and b.library_id is not distinct from p_library_id
     and b.id in (select m.batch_id from ingest.partner_catalog_row_to_draft m
                   where m.run_id = p_run_id and m.batch_id is not null)
     and coalesce(public.fn_batch_review_status(b.id), 'aucune') in ('aucune', 'changes_requested')
   order by b.id desc
   limit 1
   for update of b;
$a$,
$b$  -- H21 lot 8 (11/10/2026) : le lot ouvert du run, reconnu par l'un
  -- quelconque de ses brouillons — aussi celui que « Rapprocher » ou
  -- « Proposer les retraits » a ouvert (IMP-27 d).
  v_batch := ingest.fn_h21_lot_ouvert_du_run(p_run_id, p_library_id);
$b$);
  EXECUTE v_def;
END
$h21l8_preparer$;


-- ─────────────────────────────────────────────────────────────────────
-- 3. Le constat : l'exemplaire de la source, réattribué (IMP-35)
-- ─────────────────────────────────────────────────────────────────────
-- Les deux recherches « ailleurs » par la source : sans ces index, chacune
-- lisait tous les exemplaires de la source (revue du 11/10 : 5 000 constats de
-- codes neufs sur une source de 5 000 exemplaires, 4 955 ms).
CREATE INDEX IF NOT EXISTS exemplares_source_item_id_par_import_source
  ON public.exemplares (import_source_id, source_item_id) WHERE import_source_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS exemplares_source_item_code_par_import_source
  ON public.exemplares (import_source_id, source_item_code) WHERE import_source_id IS NOT NULL;

DO $h21l8_constat$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l8_def('ingest.fn_h21_constat_exemplaire(uuid, bigint, bigint, text, text)'::regprocedure);
  v_def := pg_temp.h21l8_remplacer('fn_h21_constat_exemplaire (déclarations)', v_def,
$a$  v_draft bigint;
BEGIN$a$,
$b$  v_draft bigint;
  r_id bigint; r_tombo text; r_xid text; r_book bigint; r_lib uuid;    -- H21 lot 8 : ailleurs, même source
BEGIN$b$);
  v_def := pg_temp.h21l8_remplacer('fn_h21_constat_exemplaire (ailleurs)', v_def,
$a$                              'ancien_code', x_code);
  END IF;
$a$,
$b$                              'ancien_code', x_code);
  END IF;
  -- H21 lot 8 (11/10/2026, IMP-35) : rien chez la bibliothèque importatrice —
  -- l'exemplaire de la SOURCE est-il dans une autre bibliothèque
  -- (réattribué) ? Le même exemplaire = même source et même identifiant :
  -- l'expl_id de même source d'abord ; le code seulement quand l'un des deux
  -- n'a pas d'expl_id (deux expl_id différents : ce n'est pas le même
  -- exemplaire, le code n'est unique que par bibliothèque). Jamais recréé :
  -- « reattribue ». Deux recherches LIMIT 1 sur les index
  -- (import_source_id, source_item_id) et (import_source_id, source_item_code)
  -- (p_library n'est pas NULL ici).
  IF p_source IS NOT NULL THEN
    IF v_id IS NOT NULL THEN
      SELECT e.id, e.tombo, e.source_item_id, e.library_id,
             coalesce(h.book_id, (SELECT b.id FROM public.books b WHERE b.bib_ref = e.bib_ref ORDER BY b.id LIMIT 1))
        INTO r_id, r_tombo, r_xid, r_lib, r_book
        FROM public.exemplares e
        LEFT JOIN public.book_holdings h ON h.id = e.holding_id
       WHERE e.import_source_id = p_source AND e.source_item_id = v_id AND e.library_id <> p_library
       ORDER BY e.id
       LIMIT 1;
    END IF;
    IF r_id IS NULL THEN
      SELECT e.id, e.tombo, e.source_item_id, e.library_id,
             coalesce(h.book_id, (SELECT b.id FROM public.books b WHERE b.bib_ref = e.bib_ref ORDER BY b.id LIMIT 1))
        INTO r_id, r_tombo, r_xid, r_lib, r_book
        FROM public.exemplares e
        LEFT JOIN public.book_holdings h ON h.id = e.holding_id
       WHERE e.import_source_id = p_source AND e.source_item_code = v_code AND e.library_id <> p_library
         AND (v_id IS NULL OR e.source_item_id IS NULL)
       ORDER BY e.id
       LIMIT 1;
    END IF;
    IF r_id IS NOT NULL THEN
      RETURN jsonb_build_object('verdict', 'reattribue', 'exemplar_id', r_id, 'tombo', r_tombo, 'book_id', r_book,
                                'library_id', r_lib,
                                'library_name', (SELECT l.name FROM public.libraries l WHERE l.id = r_lib));
    END IF;
  END IF;
$b$);
  EXECUTE v_def;
END
$h21l8_constat$;


-- ─────────────────────────────────────────────────────────────────────
-- 4. « Rapprocher » : le verdict compté, la ligne qui n'apporte rien rejetée
-- ─────────────────────────────────────────────────────────────────────
DO $h21l8_rapprocher$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l8_def('ingest.fn_create_exemplar_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure);
  v_def := pg_temp.h21l8_remplacer('fn_create_exemplar_drafts_from_import_rows (comptes)', v_def,
$a$                                         'deplace', 0, 'reetiquete', 0, 'code_repris', 0);$a$,
$b$                                         'deplace', 0, 'reetiquete', 0, 'code_repris', 0,
                                         'reattribue', 0);   -- H21 lot 8 (IMP-35)
  v_reattribue boolean;   -- H21 lot 8 : un exemplaire de la ligne est chez une autre bibliothèque$b$);
  v_def := pg_temp.h21l8_remplacer('fn_create_exemplar_drafts_from_import_rows (par ligne)', v_def,
$a$    v_signal := false;
    v_k := 0;$a$,
$b$    v_signal := false;
    v_reattribue := false;
    v_k := 0;$b$);
  v_def := pg_temp.h21l8_remplacer('fn_create_exemplar_drafts_from_import_rows (réattribué)', v_def,
$a$        if v_c->>'verdict' = 'deja_la' then
          v_items_skipped := v_items_skipped + 1;
        end if;$a$,
$b$        if v_c->>'verdict' = 'deja_la' then
          v_items_skipped := v_items_skipped + 1;
        end if;
        -- H21 lot 8 (IMP-35) : réattribué — ni brouillon ni signal
        if v_c->>'verdict' = 'reattribue' then
          v_reattribue := true;
        end if;$b$);
  v_def := pg_temp.h21l8_remplacer('fn_create_exemplar_drafts_from_import_rows (note)', v_def,
$a$               else 'Todos os exemplares desta linha ja estao na biblioteca (mesmo codigo de origem): nada a aproximar.' end,$a$,
$b$               when v_reattribue
               then 'Todos os exemplares desta linha ja estao na biblioteca ou foram reatribuidos a outra biblioteca (mesma origem): nada a aproximar.'
               else 'Todos os exemplares desta linha ja estao na biblioteca (mesmo codigo de origem): nada a aproximar.' end,$b$);
  EXECUTE v_def;
END
$h21l8_rapprocher$;


-- ─────────────────────────────────────────────────────────────────────
-- 5. « Préparer » (6b) : un exemplaire réattribué est d'une autre bibliothèque
-- ─────────────────────────────────────────────────────────────────────
DO $h21l8_preparer_ex$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l8_def('ingest.fn_h21_preparer_exemplaires(bigint, bigint[], uuid, uuid, bigint)'::regprocedure);
  v_def := pg_temp.h21l8_remplacer('fn_h21_preparer_exemplaires (réattribué)', v_def,
$a$             when i.it->>'constat' is distinct from 'deja_la' then 'pas_au_catalogue'$a$,
$b$             when i.it->>'constat' = 'reattribue' then 'autre_bibliotheque'   -- H21 lot 8 (IMP-35)
             when i.it->>'constat' is distinct from 'deja_la' then 'pas_au_catalogue'$b$);
  EXECUTE v_def;
END
$h21l8_preparer_ex$;


-- ─────────────────────────────────────────────────────────────────────
-- 6. Le rapport de révision : « reattribue » parmi les exemplaires écartés
-- ─────────────────────────────────────────────────────────────────────
DO $h21l8_rapport$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l8_def('public.fn_batch_review_report(bigint)'::regprocedure);
  v_def := pg_temp.h21l8_remplacer('fn_batch_review_report (comptes)', v_def,
$a$             'code_repris',       count(*) filter (where ec.it->>'verdict' = 'code_repris')),$a$,
$b$             'code_repris',       count(*) filter (where ec.it->>'verdict' = 'code_repris'),
             'reattribue',        count(*) filter (where ec.it->>'verdict' = 'reattribue')),   -- H21 lot 8 (IMP-35)$b$);
  v_def := pg_temp.h21l8_remplacer('fn_batch_review_report (exemples)', v_def,
$a$                      'draft_id', (e.it->>'draft_id')::bigint) order by e.rang)$a$,
$b$                      'draft_id', (e.it->>'draft_id')::bigint,
                      'library_id', e.it->>'library_id', 'library_name', e.it->>'library_name') order by e.rang)$b$);
  v_def := pg_temp.h21l8_remplacer('fn_batch_review_report (ordre)', v_def,
$a$                               order by array_position(array['code_repris', 'reetiquete', 'deplace', 'sans_code',
                                                             'deja_en_brouillon', 'deja_la'], ec2.it->>'verdict'),$a$,
$b$                               order by array_position(array['code_repris', 'reetiquete', 'deplace', 'sans_code',
                                                             'reattribue', 'deja_en_brouillon', 'deja_la'], ec2.it->>'verdict'),$b$);
  EXECUTE v_def;
END
$h21l8_rapport$;


-- ─────────────────────────────────────────────────────────────────────
-- 7. La liste : « préparable » comme « Préparer » le juge
-- ─────────────────────────────────────────────────────────────────────
DO $h21l8_liste$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h21l8_def('public.fn_import_list_run_rows(bigint)'::regprocedure);
  v_def := pg_temp.h21l8_remplacer('fn_import_list_run_rows (update_applicable)', v_def,
$a$              THEN CASE WHEN ingest.fn_h21_rejet_par_choix(sr.editorial_decision, sr.editorial_note, sr.discarded_draft_id) THEN 0
                        ELSE$a$,
$b$              THEN CASE WHEN ingest.fn_h21_rejet_par_choix(sr.editorial_decision, sr.editorial_note, sr.discarded_draft_id) THEN 0
                        -- H21 lot 8 (11/10/2026) : comme « Préparer » les juge — plus détenue
                        -- (aucun fonds de la bibliothèque importatrice), partagée (un fonds
                        -- d'une autre) : rien à préparer pour la notice
                        WHEN v_bibliotheque_importatrice IS NULL
                             OR NOT EXISTS (SELECT 1 FROM public.book_holdings h
                                             WHERE h.book_id = sr.proposed_book_id AND h.library_id = v_bibliotheque_importatrice)
                             OR EXISTS (SELECT 1 FROM public.book_holdings h
                                         WHERE h.book_id = sr.proposed_book_id AND h.library_id IS DISTINCT FROM v_bibliotheque_importatrice)
                        THEN 0
                        ELSE$b$);
  EXECUTE v_def;
END
$h21l8_liste$;


-- ─────────────────────────────────────────────────────────────────────
-- 8. Vérification structurelle
-- ─────────────────────────────────────────────────────────────────────
DO $h21l8_verif$
DECLARE v_e text := ''; v_f text;
BEGIN
  FOREACH v_f IN ARRAY ARRAY['ingest.fn_create_book_drafts_from_import_rows(bigint, bigint[], text, text, uuid)',
                             'ingest.fn_h21_lot_de_la_mise_a_jour(bigint, uuid, uuid)'] LOOP
    IF position('ingest.fn_h21_lot_ouvert_du_run(p_run_id' IN pg_get_functiondef(v_f::regprocedure)) = 0
       OR position('partner_catalog_row_to_draft m
                   where m.run_id = p_run_id and m.batch_id is not null)' IN pg_get_functiondef(v_f::regprocedure)) > 0 THEN
      v_e := v_e || ' recherche(' || v_f || ')';
    END IF;
    IF has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
       OR NOT has_function_privilege('service_role', v_f, 'EXECUTE')
       OR EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
                   WHERE p.oid = v_f::regprocedure AND a.grantee = 0)
       OR NOT (SELECT p.prosecdef AND coalesce(p.proconfig::text, '') LIKE '%search_path%' FROM pg_proc p WHERE p.oid = v_f::regprocedure) THEN
      v_e := v_e || ' droits(' || v_f || ')';
    END IF;
  END LOOP;
  -- B et C : les ajouts sont en place
  IF position('''reattribue''' IN pg_get_functiondef('ingest.fn_h21_constat_exemplaire(uuid, bigint, bigint, text, text)'::regprocedure)) = 0
     OR position('''reattribue'', 0' IN pg_get_functiondef('ingest.fn_create_exemplar_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure)) = 0
     OR position('''reattribue'' then ''autre_bibliotheque''' IN pg_get_functiondef('ingest.fn_h21_preparer_exemplaires(bigint, bigint[], uuid, uuid, bigint)'::regprocedure)) = 0
     OR position('''reattribue'',        count(*)' IN pg_get_functiondef('public.fn_batch_review_report(bigint)'::regprocedure)) = 0
     OR position('h.library_id IS DISTINCT FROM v_bibliotheque_importatrice' IN pg_get_functiondef('public.fn_import_list_run_rows(bigint)'::regprocedure)) = 0 THEN
    v_e := v_e || ' imp35-ou-liste';
  END IF;
  IF to_regclass('public.exemplares_source_item_id_par_import_source') IS NULL
     OR to_regclass('public.exemplares_source_item_code_par_import_source') IS NULL
     OR position('code_repris' IN substring(pg_get_functiondef('ingest.fn_h21_constat_exemplaire(uuid, bigint, bigint, text, text)'::regprocedure)
                                             FROM position('IMP-35' IN pg_get_functiondef('ingest.fn_h21_constat_exemplaire(uuid, bigint, bigint, text, text)'::regprocedure)))) > 0 THEN
    v_e := v_e || ' imp35-index-ou-code_repris-ailleurs';
  END IF;
  -- portes modifiées : ouvertes à authenticated et service_role, fermées à
  -- anon, DEFINER à search_path
  FOREACH v_f IN ARRAY ARRAY['public.fn_batch_review_report(bigint)', 'public.fn_import_list_run_rows(bigint)'] LOOP
    IF NOT has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
       OR NOT has_function_privilege('service_role', v_f, 'EXECUTE')
       OR NOT (SELECT p.prosecdef AND coalesce(p.proconfig::text, '') LIKE '%search_path%' FROM pg_proc p WHERE p.oid = v_f::regprocedure) THEN
      v_e := v_e || ' droits-portes(' || v_f || ')';
    END IF;
  END LOOP;
  -- aides internes modifiées : fermées à l'API
  FOREACH v_f IN ARRAY ARRAY['ingest.fn_h21_constat_exemplaire(uuid, bigint, bigint, text, text)',
                             'ingest.fn_create_exemplar_drafts_from_import_rows(bigint, bigint[], text, text, uuid)',
                             'ingest.fn_h21_preparer_exemplaires(bigint, bigint[], uuid, uuid, bigint)'] LOOP
    IF has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE') THEN
      v_e := v_e || ' droits-internes(' || v_f || ')';
    END IF;
  END LOOP;
  IF v_e <> '' THEN
    RAISE EXCEPTION 'H21 lot 8 : vérification en échec :%', v_e;
  END IF;
  RAISE NOTICE 'H21 lot 8 : vérifications OK';
END
$h21l8_verif$;

NOTIFY pgrst, 'reload schema';
