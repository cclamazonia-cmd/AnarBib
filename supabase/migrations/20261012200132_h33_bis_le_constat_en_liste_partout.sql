-- =====================================================================
-- H33 bis — le constat en liste partout, et la préparation du lot 6b sous 8 s
--
-- ── Le constat (CI de main c98b7293, 12/10/2026 ; banc privé) ──
-- Le job sql-tests est rouge sur h21_lot6b T18b : « Préparer » 200 lignes x
-- 25 exemplaires = 9 936 ms en CI (recalcul 5 262 ms) ; 2,9 s au lot 6b.
-- Mesuré au banc (pg_stat_xact_user_functions), « Préparer » 8,7 s :
--   public.tg_exemplar_draft_tombo_refuse (C17 bis, né le 10/10, après le
--     lot 6b) : 3,9 s pour 5 000 brouillons de mise à jour — chaque brouillon
--     porte le tombo de son exemplaire, et la recherche au registre
--     (public.tombos_attribues, clé primaire sur tombo) est planifiée en
--     « Seq Scan … Rows Removed by Filter: 5252 » : le registre a grossi de
--     5 000 numéros dans la transaction, ses statistiques disent quelques
--     lignes, l'index est estimé plus cher que le parcours ;
--   ingest.fn_h21_preparer_exemplaires (l'INSERT des 5 000 copies) : 2,5 s ;
--   le recalcul des trois états qu'il refait d'abord
--     (ingest.fn_h21_stocker_comparaisons_exemplaires) : 1,2 s, dont 5 000
--     appels du constat scalaire.
-- Le recalcul seul (public.fn_import_recomparer) : 2,5 s, dont le même
-- recalcul des exemplaires (1,2 s).
--
-- ── Le correctif ──
-- Aucune règle neuve ; verdicts, ordre, réponses et brouillons identiques.
--   1. ingest.fn_h33_constater_exemplaires(p_items) : le constat d'une liste,
--      sans naissance — les étapes 1 à 3 de ingest.fn_h33_juger_exemplaires
--      (le constat au catalogue de chacun ; les brouillons vivants lus une
--      fois, par EXECUTE), engendrée ici depuis sa définition vivante ; chaque
--      élément rend « c », le verdict de ingest.fn_h21_constat_exemplaire.
--      Le jugement l'appelle pour ses étapes 1 à 3 : l'étape « brouillons
--      vivants » n'a plus que deux textes, celui du constat scalaire et celui
--      de cette liste (tests/sql/h33_rapprocher_gros_fichier_tests.sql, T10,
--      les tient d'accord).
--   2. Les appelants du constat scalaire exemplaire par exemplaire passent
--      par la liste :
--        ingest.fn_h21_exemplaires_trois_etats_lot (le recalcul, la
--          préparation, la liste de l'écran ; ingest.fn_h21_exemplaires_trois_etats
--          l'appelle pour une ligne) ;
--        ingest.fn_h21_retraits_constat (les retirés réapparus, lot 7) ;
--        ingest.fn_h21_publier_retrait (la levée, à la publication).
--      ingest.fn_h21_preparer_exemplaires n'appelle pas le constat (il lit la
--      comparaison stockée) : inchangé.
--   2 bis. ingest.fn_h21_stocker_comparaisons (la comparaison des notices, du
--      recalcul et de la préparation) : son calcul MATERIALIZED. Les lignes
--      du run sans statistiques fraîches, le planificateur refaisait le
--      calcul (tri et agrégat) une fois par ligne : 4,3 s pour 200 lignes.
--   3. public.tg_exemplar_draft_tombo_refuse : enable_seqscan = off sur la
--      fonction. Ses deux recherches sont des égalités sur un index unique
--      (exemplares.tombo, la clé du registre) : elles passent par l'index quoi
--      que disent les statistiques. La garde ne change pas (même texte, mêmes
--      refus) ; garde-fou de planification, comme B32.
-- Après (même banc, machine calme, h21_lot6b T18b) : « Préparer » 200 x 25 en
-- 3,3 à 3,7 s (avant : 6,9 s), le recalcul en 1,9 à 2,0 s (inchangé ici). Sur
-- un run neuf de 200 x 25 exemplaires déjà là et retirés, avec 10 000
-- brouillons de plus (tests/sql/h33_rapprocher_gros_fichier_tests.sql, T11) :
-- recalcul 1,9 à 2,4 s (avant : 5,2 à 6,1 s), constat des retraits 0,6 s
-- (avant : 1,1 s).
--
-- Définitions de départ : production (projet uflwmikiyjfnikiphtcp, lues le
-- 12/10/2026 par pg_get_functiondef), identiques au banc :
--   ingest.fn_h33_juger_exemplaires                eb13f0467d23bbedbd91e86bfcbd64a6
--   ingest.fn_h21_exemplaires_trois_etats_lot      870e151c9a1341e89cdc371123ed0661
--   ingest.fn_h21_retraits_constat                 50962e7c83bd3364b392df626753c079
--   ingest.fn_h21_publier_retrait                  828df977944971d5a00f821326ffee9a
--   public.tg_exemplar_draft_tombo_refuse          e8ca99db99c6b28c77d077c91f644ef1 (SET seul)
--   ingest.fn_h21_stocker_comparaisons             a57ff5b01abd3e071f811a59f41bd5a2 (MATERIALIZED seul)
--   lues, inchangées : ingest.fn_h21_constat_exemplaire 9e45965702bd4f553fc7db0e6dc82d43,
--   ingest.fn_h21_constat_exemplaire_au_catalogue 8ab80be7fd9a431a636e114ca5cb2e9e,
--   ingest.fn_h21_exemplaires_trois_etats f810837394e0ae45490e2636099dc561,
--   ingest.fn_h21_preparer_exemplaires 3bbfc61682060873115fbe558283c9bb,
--   ingest.fn_h21_stocker_comparaisons_exemplaires 8dc9b96f594aca44796cb6326f548369,
--   public.fn_import_preparer_mises_a_jour 2dc11ce41c62bb094977c22cd967ab47,
--   public.fn_import_recomparer f5f0c649207d3644cb24899c69ec4af3,
--   ingest.fn_h21_retraits_bilan ab3b77306a4e941478781929e7abaaac,
--   public.fn_import_proposer_retraits d17be79328b86d4a567f16f6689f0b34.
-- Droits : CREATE OR REPLACE garde ceux des fonctions modifiées ; la fonction
-- neuve est fermée nommément à PUBLIC, anon et authenticated (le rejeu sur
-- une image vierge donne EXECUTE à authenticated), ouverte à service_role.
-- =====================================================================

CREATE OR REPLACE FUNCTION pg_temp.h33b_remplacer(p_quoi text, p_def text, p_old text, p_new text, p_n int DEFAULT 1)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_n int;
BEGIN
  IF coalesce(p_old, '') = '' THEN
    RAISE EXCEPTION 'H33 bis — % : ancre vide', p_quoi;
  END IF;
  v_n := (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old);
  IF v_n <> p_n THEN
    RAISE EXCEPTION 'H33 bis — % : ancre trouvée % fois (attendu %) — relire la définition réelle', p_quoi, v_n, p_n;
  END IF;
  RETURN replace(p_def, p_old, p_new);
END
$f$;

-- Remplace le texte compris entre deux ancres (la première incluse, la
-- seconde exclue), chacune trouvée une fois, la première avant la seconde.
CREATE OR REPLACE FUNCTION pg_temp.h33b_entre(p_quoi text, p_def text, p_debut text, p_fin text, p_new text)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_d int; v_f int;
BEGIN
  IF coalesce(p_debut, '') = '' OR coalesce(p_fin, '') = '' THEN
    RAISE EXCEPTION 'H33 bis — % : ancre vide', p_quoi;
  END IF;
  IF (length(p_def) - length(replace(p_def, p_debut, ''))) / length(p_debut) <> 1
     OR (length(p_def) - length(replace(p_def, p_fin, ''))) / length(p_fin) <> 1 THEN
    RAISE EXCEPTION 'H33 bis — % : ancres non uniques — relire la définition réelle', p_quoi;
  END IF;
  v_d := position(p_debut IN p_def);
  v_f := position(p_fin IN p_def);
  IF v_d >= v_f THEN
    RAISE EXCEPTION 'H33 bis — % : ancres dans le désordre', p_quoi;
  END IF;
  RETURN left(p_def, v_d - 1) || p_new || substr(p_def, v_f);
END
$f$;

CREATE OR REPLACE FUNCTION pg_temp.h33b_def(p_fn regprocedure)
RETURNS text LANGUAGE sql AS $f$
  SELECT replace(pg_get_functiondef(p_fn), E'\r', '');
$f$;


-- ─────────────────────────────────────────────────────────────────────
-- 1. Le constat d'une liste, et le jugement qui l'appelle
-- ─────────────────────────────────────────────────────────────────────
DO $h33b_liste$
DECLARE
  v_vivant text;
  v_def text;
  c_etape4 constant text := $a$  -- 4. Ceux que la liste peut faire naître (sans brouillon vivant de la
$a$;
BEGIN
  v_vivant := pg_temp.h33b_def('ingest.fn_h33_juger_exemplaires(jsonb)'::regprocedure);

  -- (a) le constat d'une liste : les étapes 1 à 3 du jugement, mot pour mot
  v_def := pg_temp.h33b_remplacer('constater (nom)', v_vivant,
$a$CREATE OR REPLACE FUNCTION ingest.fn_h33_juger_exemplaires(p_items jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
$a$,
$b$CREATE OR REPLACE FUNCTION ingest.fn_h33_constater_exemplaires(p_items jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
$b$);
  v_def := pg_temp.h33b_entre('constater (en-tête)', v_def, $a$-- p_items : les exemplaires dans l'ordre$a$, E'DECLARE\n',
$b$-- H33 bis (12/10/2026) : le constat (ingest.fn_h21_constat_exemplaire)
-- d'une liste d'exemplaires, SANS naissance : chacun est constaté contre ce
-- qui existe (le catalogue, les brouillons vivants), comme le constat
-- scalaire l'aurait fait au même instant. Les étapes 1 à 3 de
-- ingest.fn_h33_juger_exemplaires, engendrées depuis son texte.
-- p_items : un objet par exemplaire — lib, src, book, code, item_id (et
--   implicite, tgt, bd, recopiés pour le jugement).
-- Rendu : un objet par exemplaire, DANS LE MÊME ORDRE : k (le rang), c (le
--   verdict de ingest.fn_h21_constat_exemplaire), et, pour le jugement, cat
--   (le verdict au catalogue), a1, a2 (le premier brouillon vivant de chaque
--   bras), code, vid, sid, lib, src, tgt, bd.
$b$);
  v_def := pg_temp.h33b_entre('constater (fin)', v_def, c_etape4, E'END\n$function$',
$b$  -- Le verdict de chacun : celui du catalogue, sinon le premier brouillon
  -- vivant de la bibliothèque (bras 1), sinon celui d'une notice en brouillon
  -- de la bibliothèque (bras 2), sinon nouveau — l'ordre du constat.
  RETURN (SELECT coalesce(jsonb_agg(j || jsonb_build_object('c',
            CASE WHEN jsonb_typeof(j->'cat') <> 'null' THEN j->'cat'
                 WHEN j->>'a1' IS NOT NULL
                   THEN jsonb_build_object('verdict', 'deja_en_brouillon', 'draft_id', (j->>'a1')::bigint)
                 WHEN j->>'a2' IS NOT NULL
                   THEN jsonb_build_object('verdict', 'deja_en_brouillon', 'draft_id', (j->>'a2')::bigint)
                 ELSE jsonb_build_object('verdict', 'nouveau') END)
            ORDER BY (j->>'k')::integer), '[]'::jsonb)
          FROM jsonb_array_elements(v_j) j);
$b$);
  EXECUTE v_def;

  -- (b) le jugement : ses étapes 1 à 3 par le constat d'une liste
  v_def := pg_temp.h33b_entre('juger (étapes 1 à 3)', v_vivant,
$a$  -- 1. Le constat au catalogue de chacun (la règle unique, sans les brouillons).
$a$, c_etape4,
$b$  -- 1 à 3. H33 bis (12/10/2026) : le constat de la liste, sans naissance
  -- (ingest.fn_h33_constater_exemplaires, engendrée du texte qui était ici) :
  -- le verdict au catalogue de chacun, les brouillons vivants lus une fois,
  -- le premier de chaque bras (a1, a2).
  v_j := ingest.fn_h33_constater_exemplaires(p_items);

$b$);
  EXECUTE v_def;
END
$h33b_liste$;

REVOKE ALL ON FUNCTION ingest.fn_h33_constater_exemplaires(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION ingest.fn_h33_constater_exemplaires(jsonb) FROM anon;
REVOKE ALL ON FUNCTION ingest.fn_h33_constater_exemplaires(jsonb) FROM authenticated;
GRANT EXECUTE ON FUNCTION ingest.fn_h33_constater_exemplaires(jsonb) TO service_role;
COMMENT ON FUNCTION ingest.fn_h33_constater_exemplaires(jsonb) IS
  'H33 bis (12/10/2026) : le constat (ingest.fn_h21_constat_exemplaire) d''une liste d''exemplaires, sans naissance — au catalogue un par un, les brouillons vivants en une lecture. Pour les trois états, les retraits, la levée, et les étapes 1 à 3 de ingest.fn_h33_juger_exemplaires ; aide interne.';


-- ─────────────────────────────────────────────────────────────────────
-- 2. Les trois états des exemplaires (recalcul, préparation, liste)
-- ─────────────────────────────────────────────────────────────────────
DO $h33b_trois_etats$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h33b_def('ingest.fn_h21_exemplaires_trois_etats_lot(bigint, bigint[])'::regprocedure);
  v_def := pg_temp.h33b_entre('trois états (constat)', v_def,
$a$  ), items as materialized (
    -- le constat du lot 6a, la règle unique (lecture seule)
$a$,
$a$  ), deja as materialized (
$a$,
$b$  ), items0 as materialized (
    select l.id, l.lib, l.source_id, l.proposed_book_id, i.v, i.o::integer as o,
           (row_number() over (order by l.id, i.o))::integer as k
      from lignes l
      cross join lateral jsonb_array_elements(l.items) with ordinality i(v, o)
  ), constats as materialized (
    -- le constat du lot 6a, la règle unique (lecture seule) — H33 bis
    -- (12/10/2026) : en liste (ingest.fn_h33_constater_exemplaires), les
    -- brouillons vivants lus une fois et non plus par exemplaire
    select ingest.fn_h33_constater_exemplaires(coalesce(jsonb_agg(jsonb_build_object(
             'lib', i.lib, 'src', i.source_id, 'book', i.proposed_book_id,
             'code', i.v->>'source_item_code', 'item_id', i.v->>'source_item_id') order by i.k), '[]'::jsonb)) as r
      from items0 i
  ), items as materialized (
    select i.id, i.lib, i.source_id, i.proposed_book_id, i.v, i.o, (c.r->(i.k - 1))->'c' as c
      from items0 i
      cross join constats c
$b$);
  EXECUTE v_def;
END
$h33b_trois_etats$;


-- ─────────────────────────────────────────────────────────────────────
-- 2 bis. La comparaison des notices (recalcul, préparation)
-- ─────────────────────────────────────────────────────────────────────
-- Les lignes du run sans statistiques fraîches (estimées à une), le
-- planificateur joignait chaque ligne au calcul NON matérialisé — refait, tri
-- et agrégat compris, une fois par ligne (« GroupAggregate … loops=200 »,
-- 4,3 s pour 200 lignes de 25 exemplaires). MATERIALIZED : calculé une fois.
DO $h33b_comparaisons$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h33b_def('ingest.fn_h21_stocker_comparaisons(bigint, bigint[])'::regprocedure);
  v_def := pg_temp.h33b_remplacer('comparaisons (calcul une fois)', v_def,
$a$  with calc as (
    select t.staging_row_id, t.book_id, t.baseline_id, min(t.empreinte_fichier) as empreinte,
$a$,
$b$  -- H33 bis (12/10/2026) : calculé une fois, quelle que soit l'estimation des lignes
  with calc as materialized (
    select t.staging_row_id, t.book_id, t.baseline_id, min(t.empreinte_fichier) as empreinte,
$b$);
  EXECUTE v_def;
END
$h33b_comparaisons$;


-- ─────────────────────────────────────────────────────────────────────
-- 3. Les retirés réapparus (lot 7)
-- ─────────────────────────────────────────────────────────────────────
DO $h33b_retraits$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h33b_def('ingest.fn_h21_retraits_constat(bigint, boolean, boolean)'::regprocedure);
  v_def := pg_temp.h33b_remplacer('retraits (réapparus)', v_def,
$a$  ), reapparus as materialized (
    select distinct on (e.id) e.id, e.holding_id, h.book_id, e.tombo, e.source_item_code, e.source_item_id,
           it.row_id, k.c->>'verdict' as constat
      from run
      join paires it on true
      join public.exemplares e on e.id = it.id
      left join public.book_holdings h on h.id = e.holding_id
      cross join lateral (select ingest.fn_h21_constat_exemplaire(run.lib, run.source_id, it.proposed_book_id,
                                                                  it.code, it.xid) as c) k
$a$,
$b$  ), paires_k as materialized (
    select p.*, (row_number() over (order by p.row_id, p.o, p.id))::integer as k from paires p
  ), constats_paires as materialized (
    -- H33 bis (12/10/2026) : le constat de chaque paire, en liste
    -- (ingest.fn_h33_constater_exemplaires : la même règle, les brouillons
    -- vivants lus une fois)
    select ingest.fn_h33_constater_exemplaires(coalesce(jsonb_agg(jsonb_build_object(
             'lib', run.lib, 'src', run.source_id, 'book', p.proposed_book_id,
             'code', p.code, 'item_id', p.xid) order by p.k), '[]'::jsonb)) as r
      from paires_k p
      cross join run
  ), reapparus as materialized (
    select distinct on (e.id) e.id, e.holding_id, h.book_id, e.tombo, e.source_item_code, e.source_item_id,
           it.row_id, k.c->>'verdict' as constat
      from run
      join paires_k it on true
      join public.exemplares e on e.id = it.id
      left join public.book_holdings h on h.id = e.holding_id
      cross join constats_paires cp
      cross join lateral (select (cp.r->(it.k - 1))->'c' as c) k
$b$);
  EXECUTE v_def;
END
$h33b_retraits$;


-- ─────────────────────────────────────────────────────────────────────
-- 4. La levée, à la publication
-- ─────────────────────────────────────────────────────────────────────
DO $h33b_levee$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h33b_def('ingest.fn_h21_publier_retrait(bigint, boolean)'::regprocedure);
  v_def := pg_temp.h33b_remplacer('levée (constat)', v_def,
$a$    select exists (
      select 1
        from ingest.partner_catalog_staging_rows sr
        cross join lateral jsonb_array_elements(case when jsonb_typeof(sr.normalized_payload->'items') = 'array'
                                                     then sr.normalized_payload->'items' else '[]'::jsonb end) i(v)
       where sr.run_id = v_run.id
         and sr.match_status = 'known_record' and sr.proposed_book_id is not null
         and not ingest.fn_h21_rejet_par_choix(sr.editorial_decision, sr.editorial_note, sr.discarded_draft_id)
         and ((nullif(btrim(v_e.source_item_code), '') is not null
               and (sr.normalized_payload->'items') @> jsonb_build_array(jsonb_build_object('source_item_code', btrim(v_e.source_item_code))))
              or (nullif(btrim(v_e.source_item_id), '') is not null
                  and (sr.normalized_payload->'items') @> jsonb_build_array(jsonb_build_object('source_item_id', btrim(v_e.source_item_id)))))
         and nullif(btrim(i.v->>'source_item_code'), '') is not null
         and (ingest.fn_h21_constat_exemplaire(v_lib, v_src, sr.proposed_book_id,
                                               i.v->>'source_item_code', i.v->>'source_item_id')->>'exemplar_id')::bigint = v_e.id
         and ingest.fn_h21_constat_exemplaire(v_lib, v_src, sr.proposed_book_id,
                                              i.v->>'source_item_code', i.v->>'source_item_id')->>'verdict' in ('deja_la', 'reetiquete'))
      into v_ok;
$a$,
$b$    -- H33 bis (12/10/2026) : les exemplaires du fichier qui peuvent désigner
    -- l'exemplaire (mêmes conditions qu'avant), constatés en liste
    -- (ingest.fn_h33_constater_exemplaires : la même règle).
    select exists (
      select 1
        from (select ingest.fn_h33_constater_exemplaires(coalesce(jsonb_agg(jsonb_build_object(
                       'lib', v_lib, 'src', v_src, 'book', c.book, 'code', c.code, 'item_id', c.item_id)), '[]'::jsonb)) as r
                from (select sr.proposed_book_id as book, i.v->>'source_item_code' as code, i.v->>'source_item_id' as item_id
                        from ingest.partner_catalog_staging_rows sr
                        cross join lateral jsonb_array_elements(case when jsonb_typeof(sr.normalized_payload->'items') = 'array'
                                                                     then sr.normalized_payload->'items' else '[]'::jsonb end) i(v)
                       where sr.run_id = v_run.id
                         and sr.match_status = 'known_record' and sr.proposed_book_id is not null
                         and not ingest.fn_h21_rejet_par_choix(sr.editorial_decision, sr.editorial_note, sr.discarded_draft_id)
                         and ((nullif(btrim(v_e.source_item_code), '') is not null
                               and (sr.normalized_payload->'items') @> jsonb_build_array(jsonb_build_object('source_item_code', btrim(v_e.source_item_code))))
                              or (nullif(btrim(v_e.source_item_id), '') is not null
                                  and (sr.normalized_payload->'items') @> jsonb_build_array(jsonb_build_object('source_item_id', btrim(v_e.source_item_id)))))
                         and nullif(btrim(i.v->>'source_item_code'), '') is not null) c) x
        cross join lateral jsonb_array_elements(x.r) k
       where (k->'c'->>'exemplar_id')::bigint = v_e.id
         and k->'c'->>'verdict' in ('deja_la', 'reetiquete'))
      into v_ok;
$b$);
  EXECUTE v_def;
END
$h33b_levee$;


-- ─────────────────────────────────────────────────────────────────────
-- 5. Le registre des tombos : les recherches par l'index
-- ─────────────────────────────────────────────────────────────────────
-- Les deux recherches de la garde C17 bis sont des égalités sur un index
-- unique ; sans statistiques fraîches (registre qui vient de grossir), le
-- planificateur leur préférait un parcours de la table, à chaque brouillon.
ALTER FUNCTION public.tg_exemplar_draft_tombo_refuse() SET enable_seqscan TO off;


-- ─────────────────────────────────────────────────────────────────────
-- 6. Vérification structurelle
-- ─────────────────────────────────────────────────────────────────────
DO $h33b_verif$
DECLARE
  v_e text := '';
  v_f text;
  v_cst text := pg_get_functiondef('ingest.fn_h33_constater_exemplaires(jsonb)'::regprocedure);
  v_jug text := pg_get_functiondef('ingest.fn_h33_juger_exemplaires(jsonb)'::regprocedure);
BEGIN
  -- une seule lecture des brouillons vivants en liste : dans le constat de la liste
  IF position('EXECUTE $q$' IN v_cst) = 0 OR position('EXECUTE' IN v_jug) > 0
     OR position('v_j := ingest.fn_h33_constater_exemplaires(p_items);' IN v_jug) = 0
     OR position('y.target_library_id = $1' IN v_cst) = 0
     OR position('public.fn_book_draft_library(y.book_draft_id) = $1' IN v_cst) = 0
     OR position('ingest.fn_h21_constat_exemplaire_au_catalogue(' IN v_cst) = 0
     OR (SELECT p.provolatile FROM pg_proc p WHERE p.oid = 'ingest.fn_h33_constater_exemplaires(jsonb)'::regprocedure) <> 's' THEN
    v_e := v_e || ' liste';
  END IF;
  -- plus aucun appel du constat scalaire exemplaire par exemplaire dans les
  -- fonctions de la base (le constat lui-même excepté)
  SELECT v_e || coalesce(string_agg(' scalaire(' || n.nspname || '.' || p.proname || ')', ''), '')
    INTO v_e
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE p.prosrc ~ 'fn_h21_constat_exemplaire\('
     AND p.oid <> 'ingest.fn_h21_constat_exemplaire(uuid, bigint, bigint, text, text)'::regprocedure;
  IF position('ingest.fn_h33_constater_exemplaires(' IN pg_get_functiondef('ingest.fn_h21_exemplaires_trois_etats_lot(bigint, bigint[])'::regprocedure)) = 0
     OR position('ingest.fn_h33_constater_exemplaires(' IN pg_get_functiondef('ingest.fn_h21_retraits_constat(bigint, boolean, boolean)'::regprocedure)) = 0
     OR position('ingest.fn_h33_constater_exemplaires(' IN pg_get_functiondef('ingest.fn_h21_publier_retrait(bigint, boolean)'::regprocedure)) = 0
     OR position('error.publish.item_levee_gone_from_file' IN pg_get_functiondef('ingest.fn_h21_publier_retrait(bigint, boolean)'::regprocedure)) = 0
     OR position('with calc as materialized (' IN pg_get_functiondef('ingest.fn_h21_stocker_comparaisons(bigint, bigint[])'::regprocedure)) = 0 THEN
    v_e := v_e || ' appelants';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.oid = 'public.tg_exemplar_draft_tombo_refuse()'::regprocedure
                    AND p.proconfig @> ARRAY['enable_seqscan=off'] AND p.prosecdef
                    AND coalesce(p.proconfig::text, '') LIKE '%search_path%')
     OR position('tombo_deja_attribue' IN pg_get_functiondef('public.tg_exemplar_draft_tombo_refuse()'::regprocedure)) = 0 THEN
    v_e := v_e || ' tombo';
  END IF;
  -- droits : la fonction neuve et les aides modifiées, fermées à l'API
  FOREACH v_f IN ARRAY ARRAY['ingest.fn_h33_constater_exemplaires(jsonb)', 'ingest.fn_h33_juger_exemplaires(jsonb)'] LOOP
    IF has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
       OR NOT has_function_privilege('service_role', v_f, 'EXECUTE')
       OR EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
                   WHERE p.oid = v_f::regprocedure AND a.grantee = 0)
       OR (SELECT p.prosecdef OR coalesce(p.proconfig::text, '') NOT LIKE '%search_path%' FROM pg_proc p WHERE p.oid = v_f::regprocedure) THEN
      v_e := v_e || ' droits(' || v_f || ')';
    END IF;
  END LOOP;
  FOREACH v_f IN ARRAY ARRAY['ingest.fn_h21_exemplaires_trois_etats_lot(bigint, bigint[])',
                             'ingest.fn_h21_retraits_constat(bigint, boolean, boolean)',
                             'ingest.fn_h21_publier_retrait(bigint, boolean)'] LOOP
    IF has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
       OR NOT (SELECT p.prosecdef AND coalesce(p.proconfig::text, '') LIKE '%search_path%' FROM pg_proc p WHERE p.oid = v_f::regprocedure) THEN
      v_e := v_e || ' droits(' || v_f || ')';
    END IF;
  END LOOP;
  IF v_e <> '' THEN
    RAISE EXCEPTION 'H33 bis : vérification en échec :%', v_e;
  END IF;
  RAISE NOTICE 'H33 bis : vérifications OK';
END
$h33b_verif$;

NOTIFY pgrst, 'reload schema';
