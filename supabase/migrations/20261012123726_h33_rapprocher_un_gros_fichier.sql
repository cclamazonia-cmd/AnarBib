-- =====================================================================
-- H33 — « Rapprocher » (et « Promouvoir ») un gros fichier sous le plafond
-- de 8 s des appels de l'API (statement_timeout d'authenticator)
--
-- ── Le constat (banc privé, 11-12/10/2026, scratchpad h33) ──
-- « Rapprocher » 200 lignes x 25 exemplaires neufs, sous le jeton de la
-- coordination : 26 s (et de 8 à 80 s selon l'état des statistiques), dont
--   ingest.fn_h21_constat_exemplaire        16,2 s pour 5 000 appels ;
--   public.sync_exemplar_draft_holdings_bridge 5,5 s (dont la résolution du
--     fonds, public.resolve_library_holding_bridge, 1,8 s) ;
--   la boucle elle-même (INSERT un par un, jsonb allongé) 4,1 s.
-- Les déclencheurs de exemplar_drafts ne coûtent presque rien (0,7 s pour
-- 15 000 appels : sous le propriétaire de la fonction, la plupart rendent la
-- main d'emblée) ; la recherche du lot ouvert et la mise à jour des lignes
-- non plus.
-- La cause : la boucle constatait, créait le brouillon puis reliait son fonds
-- EXEMPLAIRE PAR EXEMPLAIRE. Le constat relit exemplar_drafts (« déjà en
-- brouillon ») et sync_exemplar_draft_holdings_bridge la relit par son id :
-- deux requêtes par exemplaire sur une table qui GROSSIT pendant l'appel, sous
-- des plans mis en cache par la session quand elle était presque vide (en
-- production : 19 lignes, 1 page). auto_explain : « Seq Scan on
-- exemplar_drafts … Rows Removed by Filter: 4999 » à chaque exemplaire, ou
-- un parcours complet de l'index primaire (ORDER BY id LIMIT 1) quand la
-- table vient d'être vidée par l'autovacuum (relpages = 0) — d'où l'écart de
-- 8 à 80 s d'un passage à l'autre : il dépend de ce que l'autovacuum a laissé
-- dans pg_class, pas de la charge. Le même défaut frappe la page suivante de
-- l'écran (5 000 brouillons de la page 1, plans d'une table vide : 12 à 46 s
-- pour 5 000 constats) et la promotion (ingest.fn_create_item_drafts_for_batch,
-- 200 lignes nouvelles x 25 exemplaires : 20,8 s, dont 13,8 s de constat).
--
-- ── Le correctif : le jugement et les écritures en une passe ──
-- Aucune règle neuve : mêmes verdicts, mêmes brouillons, mêmes lignes, même
-- réponse ; les gardes (dépôt compagnon à l'administration, éligibilité,
-- verrou d'avis par bibliothèque, lot ouvert du run, lot de la bibliothèque
-- des exemplaires) sont reprises telles quelles, hors du bloc remplacé.
--   1. ingest.fn_h21_constat_exemplaire_au_catalogue : le constat SANS sa
--      dernière étape (les brouillons vivants). Engendrée ici depuis la
--      définition vivante du constat (même texte), elle rend NULL là où le
--      constat passait aux brouillons. Le constat l'appelle, puis fait sa
--      dernière étape comme avant : une seule règle, un seul texte.
--   2. ingest.fn_h33_juger_exemplaires(p_items) : le jugement d'une liste
--      d'exemplaires dans l'ordre de la boucle d'avant — le constat au
--      catalogue de chacun ; les brouillons vivants lus UNE fois (EXECUTE,
--      donc planifiée avec les tailles du moment) pour tous ; et « déjà en
--      brouillon » pour un exemplaire qu'un précédent de la même liste vient
--      de faire naître, avec les deux bras du constat dans son ordre (brouillon
--      de la bibliothèque, puis d'une notice en brouillon de la bibliothèque) —
--      la boucle d'avant le voyait, puisqu'elle insérait avant de constater le
--      suivant. Seuls les exemplaires qui partagent un code, ou un expl_id de
--      même source, avec un autre sont jugés un par un.
--   3. ingest.fn_create_exemplar_drafts_from_import_rows (« Rapprocher ») :
--      les lignes et leurs exemplaires d'abord, jugés ensemble ; puis le lot
--      (comme avant : au premier brouillon) ; le fonds de chaque notice résolu
--      UNE fois (public.resolve_library_holding_bridge, ce que
--      sync_exemplar_draft_holdings_bridge faisait pour chaque brouillon neuf
--      — même résultat, la suite le prouve en la rappelant) ; les brouillons
--      en un INSERT (identifiants croissants dans l'ordre de la boucle) ; les
--      lignes en un UPDATE.
--   4. ingest.fn_create_item_drafts_for_batch (la promotion) : de même.
--   5. La borne d'une page d'appel (spécification H33, point 3) : même en une
--      passe, une sélection entière ne tient pas toujours sous 8 s (au banc :
--      « Rapprocher » 1 000 lignes x 25 exemplaires en un appel, 7,3 s ;
--      « Promouvoir » 1 000 lignes nouvelles, 4 à 5 s pour les seules notices,
--      17,8 s avec 25 exemplaires chacune). Comme « Préparer la mise à jour »
--      et le recalcul (lot 6b) : 200 lignes et 5 000 exemplaires du fichier au
--      plus par appel ; la base refuse au-delà (HINT error.import.page_too_large,
--      neuve, et error.import.update_page_too_many_items, reprise), l'écran et
--      l'assistant découpent la sélection (pagesParExemplaires). Une page
--      suivante voit les brouillons des précédentes : mêmes verdicts qu'en un
--      appel ; toutes rejoignent le lot ouvert du run (IMP-27 d).
-- Après (même banc) : « Rapprocher » 200 x 25 en 1,4 s, et 1,4 s pour la page
-- suivante (avant : 19 à 26 s, puis 48 s) ; avec 2 136 fonds analysés comme
-- BTL, 1,9 s ; « Promouvoir » 200 x 25 en 2,6 s (avant : 10 à 49 s). Mesures
-- dans tests/sql/h33_rapprocher_gros_fichier_tests.sql (T07, T08).
--
-- ── Non corrigé ici (mesuré, à décider) ──
-- La PUBLICATION d'un lot importé de 5 000 exemplaires (public.publish_catalog_batch)
-- prend 208 s au banc à l'échelle de la production : par exemplaire publié,
-- public.fn_v2_recompute_holdings_availability recompte les exemplaires de
-- TOUT le réseau (110 s) et public.fn_next_tombo relit tous les numéros du
-- préfixe (49 s). Autre défaut (circulation, numérotation), autre lot.
--
-- Définitions de départ : production (projet uflwmikiyjfnikiphtcp, lues le
-- 12/10/2026 par pg_get_functiondef), identiques au banc :
--   ingest.fn_h21_constat_exemplaire                  ec5de79c349313eafeb1b5937f96a32c
--   ingest.fn_create_exemplar_drafts_from_import_rows d66e3d480489d57e05a317ea96f279f2
--   ingest.fn_create_item_drafts_for_batch            58590a2e5b41b4e9fd2af9ed8ad4115e
--   ingest.fn_create_book_drafts_from_import_rows     26acf55e2841e23ac0f34dbae345fb13 (la borne seule)
--   lues, inchangées : public.fn_import_reconcile_duplicates e946fa973bdc4297e280f864d82db390,
--   public.fn_import_promote 765bd7201d6c2b4d0cae97e68d0ade43,
--   public.sync_exemplar_draft_holdings_bridge 0a3dd08d147cdccee9879fc33b95f982,
--   public.resolve_library_holding_bridge 4271a8619d8b5bb63106b2676bab7319,
--   ingest.fn_h21_lot_ouvert_du_run eb85941cb8cefc844bace649b22f5584,
--   ingest.fn_h21_bibliotheque_importatrice 1da31ed2fa4a6cf3b5f742a4da600e02,
--   public.fn_book_draft_library 8b0babd67d476daceb9939ea1064b7f3,
--   ingest.fn_h21_exemplaires_par_appel 03f2bcfdf9912c05c98230a963493110,
--   public.publish_catalog_batch 52bfe412194226cc7a688cce78bd9ff9,
--   public.publish_exemplar_draft 39694e0ac10ed1910b4c7012f5b0c02e.
-- Droits : CREATE OR REPLACE garde ceux des fonctions modifiées ; les deux
-- fonctions neuves sont fermées à l'API (service_role seul) ; vérifiés à la fin.
-- =====================================================================

CREATE OR REPLACE FUNCTION pg_temp.h33_remplacer(p_quoi text, p_def text, p_old text, p_new text, p_n int DEFAULT 1)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_n int;
BEGIN
  IF coalesce(p_old, '') = '' THEN
    RAISE EXCEPTION 'H33 — % : ancre vide', p_quoi;
  END IF;
  v_n := (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old);
  IF v_n <> p_n THEN
    RAISE EXCEPTION 'H33 — % : ancre trouvée % fois (attendu %) — relire la définition réelle', p_quoi, v_n, p_n;
  END IF;
  RETURN replace(p_def, p_old, p_new);
END
$f$;

-- Remplace le texte compris entre deux ancres (la première incluse, la
-- seconde exclue), chacune trouvée une fois, la première avant la seconde.
CREATE OR REPLACE FUNCTION pg_temp.h33_entre(p_quoi text, p_def text, p_debut text, p_fin text, p_new text)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_d int; v_f int;
BEGIN
  IF coalesce(p_debut, '') = '' OR coalesce(p_fin, '') = '' THEN
    RAISE EXCEPTION 'H33 — % : ancre vide', p_quoi;
  END IF;
  IF (length(p_def) - length(replace(p_def, p_debut, ''))) / length(p_debut) <> 1
     OR (length(p_def) - length(replace(p_def, p_fin, ''))) / length(p_fin) <> 1 THEN
    RAISE EXCEPTION 'H33 — % : ancres non uniques — relire la définition réelle', p_quoi;
  END IF;
  v_d := position(p_debut IN p_def);
  v_f := position(p_fin IN p_def);
  IF v_d >= v_f THEN
    RAISE EXCEPTION 'H33 — % : ancres dans le désordre', p_quoi;
  END IF;
  RETURN left(p_def, v_d - 1) || p_new || substr(p_def, v_f);
END
$f$;

CREATE OR REPLACE FUNCTION pg_temp.h33_def(p_fn regprocedure)
RETURNS text LANGUAGE sql AS $f$
  SELECT replace(pg_get_functiondef(p_fn), E'\r', '');
$f$;


-- ─────────────────────────────────────────────────────────────────────
-- 1. Le constat au catalogue, et le constat qui l'appelle
-- ─────────────────────────────────────────────────────────────────────
DO $h33_constat$
DECLARE
  v_vivant text;
  v_def text;
  -- la dernière étape du constat : les brouillons vivants
  c_brouillons constant text := $a$  SELECT y.id INTO v_draft FROM public.exemplar_drafts y
   WHERE y.status IN ('draft', 'ready') AND y.target_library_id = p_library
$a$;
BEGIN
  v_vivant := pg_temp.h33_def('ingest.fn_h21_constat_exemplaire(uuid, bigint, bigint, text, text)'::regprocedure);

  -- (a) au catalogue : le même texte, arrêté avant les brouillons
  v_def := pg_temp.h33_remplacer('constat au catalogue (nom)', v_vivant,
$a$CREATE OR REPLACE FUNCTION ingest.fn_h21_constat_exemplaire(p_library uuid$a$,
$b$CREATE OR REPLACE FUNCTION ingest.fn_h21_constat_exemplaire_au_catalogue(p_library uuid$b$);
  v_def := pg_temp.h33_entre('constat au catalogue (fin)', v_def, c_brouillons, E'END\n$function$',
$b$  -- H33 (12/10/2026) : rien au catalogue de la bibliothèque, ni ailleurs pour
  -- la source. La dernière étape du constat (les brouillons vivants) n'est pas
  -- ici : ingest.fn_h21_constat_exemplaire la fait pour un exemplaire,
  -- ingest.fn_h33_juger_exemplaires pour une liste.
  RETURN NULL;
$b$);
  EXECUTE v_def;

  -- (b) le constat : le catalogue par la fonction ci-dessus, puis les
  -- brouillons vivants comme avant
  v_def := pg_temp.h33_remplacer('constat (déclaration)', v_vivant,
$a$  v_draft bigint;
$a$,
$b$  v_draft bigint;
  v_cat jsonb;   -- H33 : le verdict au catalogue
$b$);
  v_def := pg_temp.h33_entre('constat (catalogue délégué)', v_def,
$a$  SELECT e.id, e.tombo, e.source_item_code, e.source_item_id, e.import_source_id,
$a$, c_brouillons,
$b$  -- H33 (12/10/2026) : le constat au catalogue (bibliothèque importatrice,
  -- puis la source ailleurs) est ingest.fn_h21_constat_exemplaire_au_catalogue,
  -- engendrée du texte qui était ici ; NULL : les brouillons vivants décident.
  v_cat := ingest.fn_h21_constat_exemplaire_au_catalogue(p_library, p_source, p_book_id, p_code, p_item_id);
  IF v_cat IS NOT NULL THEN
    RETURN v_cat;
  END IF;
$b$);
  EXECUTE v_def;
END
$h33_constat$;

REVOKE ALL ON FUNCTION ingest.fn_h21_constat_exemplaire_au_catalogue(uuid, bigint, bigint, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION ingest.fn_h21_constat_exemplaire_au_catalogue(uuid, bigint, bigint, text, text) TO service_role;
COMMENT ON FUNCTION ingest.fn_h21_constat_exemplaire_au_catalogue(uuid, bigint, bigint, text, text) IS
  'H33 (12/10/2026) : le constat d''un exemplaire du fichier (ingest.fn_h21_constat_exemplaire) sans sa dernière étape — le verdict au catalogue (sans_code, nouveau sans bibliothèque, code_repris, deplace, deja_la, reetiquete, reattribue), NULL quand les brouillons vivants décident. Engendrée depuis le texte du constat ; aide interne.';


-- ─────────────────────────────────────────────────────────────────────
-- 2. Le jugement d'une liste d'exemplaires
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION ingest.fn_h33_juger_exemplaires(p_items jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
-- p_items : les exemplaires dans l'ordre où la boucle d'avant les constatait
-- puis les créait, un objet par exemplaire :
--   lib (bibliothèque du constat), src (source du run), book (notice de la
--   ligne, ou null), code, item_id (tels que lus dans le fichier),
--   implicite (l'exemplaire implicite d'H19 : nouveau sans constat),
--   tgt, bd (target_library_id et book_draft_id du brouillon qu'il ferait naître).
-- Rendu : un objet par exemplaire, DANS LE MÊME ORDRE : k (le rang, de 1 à n),
--   c (le verdict du constat, tel que ingest.fn_h21_constat_exemplaire le
--   rendait à ce point de la boucle), et par (le rang de l'exemplaire de cette
--   liste dont le brouillon rend celui-ci « déjà en brouillon » : l'appelant
--   pose son identifiant dans c.draft_id). « nouveau » = un brouillon à créer.
DECLARE
  v_j jsonb;
  v_g record;
  v_carte jsonb;
  v_cartes jsonb := '{}'::jsonb;
  v_imp jsonb;
  v_x record;
  v_fin jsonb := '{}'::jsonb;
  v_lib uuid; v_src bigint; v_code text; v_vid text;
  v_p1 integer; v_p2 integer; v_i integer;
  -- le vivier : les exemplaires de la liste déjà jugés « nouveau », dans l'ordre
  w_k integer[] := '{}'; w_tgt uuid[] := '{}'; w_bd bigint[] := '{}';
  w_code text[] := '{}'; w_src bigint[] := '{}'; w_sid text[] := '{}';
BEGIN
  -- 1. Le constat au catalogue de chacun (la règle unique, sans les brouillons).
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'k', i.o, 'lib', i.v->'lib', 'src', i.v->'src', 'tgt', i.v->'tgt', 'bd', i.v->'bd',
           -- comme le constat : le code ; l'expl_id, signal seulement avec sa source
           'code', nullif(btrim(coalesce(i.v->>'code', '')), ''),
           'vid', CASE WHEN i.v->>'src' IS NOT NULL THEN nullif(btrim(coalesce(i.v->>'item_id', '')), '') END,
           -- comme le brouillon créé : son source_item_id
           'sid', nullif(btrim(i.v->>'item_id'), ''),
           'cat', CASE WHEN coalesce((i.v->>'implicite')::boolean, false)
                       THEN jsonb_build_object('verdict', 'nouveau', 'implicite', true)
                       ELSE ingest.fn_h21_constat_exemplaire_au_catalogue((i.v->>'lib')::uuid, (i.v->>'src')::bigint,
                              (i.v->>'book')::bigint, i.v->>'code', i.v->>'item_id') END)
         ORDER BY i.o), '[]'::jsonb)
    INTO v_j
    FROM jsonb_array_elements(p_items) WITH ORDINALITY i(v, o);

  -- 2. Les brouillons vivants, lus une fois par (bibliothèque, source) pour
  --    tous les codes et expl_id à chercher : les deux bras du constat,
  --    mot pour mot (statut draft/ready ; bras 1 : de la bibliothèque ;
  --    bras 2 : sans bibliothèque, d'une notice en brouillon de la
  --    bibliothèque). EXECUTE : planifiée à chaque appel, avec les tailles du
  --    moment — jamais un plan d'une table vide.
  FOR v_g IN
    SELECT (j->>'lib')::uuid AS lib, (j->>'src')::bigint AS src,
           array_agg(DISTINCT j->>'code') AS codes,
           coalesce(array_agg(DISTINCT j->>'vid') FILTER (WHERE j->>'vid' IS NOT NULL), '{}'::text[]) AS vids
      FROM jsonb_array_elements(v_j) j
     WHERE jsonb_typeof(j->'cat') = 'null'
     GROUP BY 1, 2
  LOOP
    EXECUTE $q$
      WITH y AS (
        SELECT 1 AS bras, y.id, y.source_item_code AS code,
               CASE WHEN y.import_source_id = $2 THEN y.source_item_id END AS expl
          FROM public.exemplar_drafts y
         WHERE y.status IN ('draft', 'ready') AND y.target_library_id = $1
           AND (y.source_item_code = ANY ($3) OR ($2 IS NOT NULL AND y.import_source_id = $2 AND y.source_item_id = ANY ($4)))
        UNION ALL
        SELECT 2, y.id, y.source_item_code,
               CASE WHEN y.import_source_id = $2 THEN y.source_item_id END
          FROM public.exemplar_drafts y
         WHERE y.status IN ('draft', 'ready') AND y.target_library_id IS NULL AND y.book_draft_id IS NOT NULL
           AND (y.source_item_code = ANY ($3) OR ($2 IS NOT NULL AND y.import_source_id = $2 AND y.source_item_id = ANY ($4)))
           AND public.fn_book_draft_library(y.book_draft_id) = $1
      )
      SELECT jsonb_build_object(
        '1c', (SELECT coalesce(jsonb_object_agg(s.code, s.m), '{}'::jsonb)
                 FROM (SELECT code, min(id) AS m FROM y WHERE bras = 1 AND code IS NOT NULL GROUP BY code) s),
        '1x', (SELECT coalesce(jsonb_object_agg(s.expl, s.m), '{}'::jsonb)
                 FROM (SELECT expl, min(id) AS m FROM y WHERE bras = 1 AND expl IS NOT NULL GROUP BY expl) s),
        '2c', (SELECT coalesce(jsonb_object_agg(s.code, s.m), '{}'::jsonb)
                 FROM (SELECT code, min(id) AS m FROM y WHERE bras = 2 AND code IS NOT NULL GROUP BY code) s),
        '2x', (SELECT coalesce(jsonb_object_agg(s.expl, s.m), '{}'::jsonb)
                 FROM (SELECT expl, min(id) AS m FROM y WHERE bras = 2 AND expl IS NOT NULL GROUP BY expl) s))
    $q$ INTO v_carte USING v_g.lib, v_g.src, v_g.codes, v_g.vids;
    v_cartes := v_cartes || jsonb_build_object(v_g.lib::text || '/' || coalesce(v_g.src::text, ''), v_carte);
  END LOOP;

  -- 3. Pour chacun sans verdict au catalogue : le premier brouillon vivant de
  --    chaque bras (par le code ou par l'expl_id de même source).
  SELECT coalesce(jsonb_agg(x.e || jsonb_build_object(
           'a1', least((x.c->'1c'->>(x.e->>'code'))::bigint, (x.c->'1x'->>(x.e->>'vid'))::bigint),
           'a2', least((x.c->'2c'->>(x.e->>'code'))::bigint, (x.c->'2x'->>(x.e->>'vid'))::bigint))
         ORDER BY (x.e->>'k')::integer), '[]'::jsonb)
    INTO v_j
    FROM (SELECT j AS e,
                 CASE WHEN jsonb_typeof(j->'cat') = 'null'
                      THEN v_cartes->((j->>'lib') || '/' || coalesce(j->>'src', '')) END AS c
            FROM jsonb_array_elements(v_j) j) x;

  -- 4. Ceux que la liste peut faire naître (sans brouillon vivant de la
  --    bibliothèque, ou « nouveau » au catalogue : sans bibliothèque) et qui
  --    partagent un code, ou un expl_id de même source, avec un autre : seuls
  --    ceux-là dépendent de l'ordre.
  SELECT coalesce(jsonb_object_agg(s.k::text, true), '{}'::jsonb)
    INTO v_imp
    FROM (SELECT t.k
            FROM (SELECT c.k, count(*) OVER (PARTITION BY c.cle) AS n
                    FROM (SELECT (j->>'k')::integer AS k, 'c:' || (j->>'code') AS cle
                            FROM jsonb_array_elements(v_j) j
                           WHERE ((jsonb_typeof(j->'cat') = 'null' AND j->>'a1' IS NULL) OR j->'cat'->>'verdict' = 'nouveau')
                             AND j->>'code' IS NOT NULL
                          UNION ALL
                          SELECT (j->>'k')::integer, 'x:' || (j->>'src') || ':' || (j->>'sid')
                            FROM jsonb_array_elements(v_j) j
                           WHERE ((jsonb_typeof(j->'cat') = 'null' AND j->>'a1' IS NULL) OR j->'cat'->>'verdict' = 'nouveau')
                             AND j->>'src' IS NOT NULL AND j->>'sid' IS NOT NULL) c) t
           WHERE t.n > 1
           GROUP BY t.k) s;

  -- 5. Ceux-là, dans l'ordre, comme la boucle d'avant : le brouillon qu'un
  --    précédent vient de faire naître compte, bras 1 d'abord (même
  --    bibliothèque), puis bras 2 (un brouillon vivant d'avant l'appel passe
  --    devant un de l'appel : identifiant plus petit).
  FOR v_x IN
    SELECT (j->>'k')::integer AS k, j
      FROM jsonb_array_elements(v_j) j
     WHERE v_imp ? (j->>'k')
     ORDER BY 1
  LOOP
    IF jsonb_typeof(v_x.j->'cat') <> 'null' THEN
      -- « nouveau » au catalogue (sans bibliothèque) : il naît, sans constat
      -- des brouillons
      w_k := array_append(w_k, v_x.k);
      w_tgt := array_append(w_tgt, (v_x.j->>'tgt')::uuid);
      w_bd := array_append(w_bd, (v_x.j->>'bd')::bigint);
      w_code := array_append(w_code, v_x.j->>'code');
      w_src := array_append(w_src, (v_x.j->>'src')::bigint);
      w_sid := array_append(w_sid, v_x.j->>'sid');
      CONTINUE;
    END IF;
    v_lib := (v_x.j->>'lib')::uuid;
    v_src := (v_x.j->>'src')::bigint;
    v_code := v_x.j->>'code';
    v_vid := v_x.j->>'vid';
    v_p1 := NULL;
    v_p2 := NULL;
    FOR v_i IN 1 .. coalesce(array_length(w_k, 1), 0) LOOP
      IF w_code[v_i] = v_code OR (v_vid IS NOT NULL AND w_src[v_i] = v_src AND w_sid[v_i] = v_vid) THEN
        IF w_tgt[v_i] = v_lib THEN
          v_p1 := w_k[v_i];
          EXIT;
        END IF;
        IF v_p2 IS NULL AND w_tgt[v_i] IS NULL AND w_bd[v_i] IS NOT NULL
           AND public.fn_book_draft_library(w_bd[v_i]) = v_lib THEN
          v_p2 := w_k[v_i];
        END IF;
      END IF;
    END LOOP;
    IF v_p1 IS NOT NULL THEN
      v_fin := v_fin || jsonb_build_object(v_x.k::text,
                 jsonb_build_object('c', jsonb_build_object('verdict', 'deja_en_brouillon'), 'par', v_p1));
    ELSIF v_x.j->>'a2' IS NOT NULL THEN
      v_fin := v_fin || jsonb_build_object(v_x.k::text,
                 jsonb_build_object('c', jsonb_build_object('verdict', 'deja_en_brouillon', 'draft_id', (v_x.j->>'a2')::bigint)));
    ELSIF v_p2 IS NOT NULL THEN
      v_fin := v_fin || jsonb_build_object(v_x.k::text,
                 jsonb_build_object('c', jsonb_build_object('verdict', 'deja_en_brouillon'), 'par', v_p2));
    ELSE
      v_fin := v_fin || jsonb_build_object(v_x.k::text, jsonb_build_object('c', jsonb_build_object('verdict', 'nouveau')));
      w_k := array_append(w_k, v_x.k);
      w_tgt := array_append(w_tgt, (v_x.j->>'tgt')::uuid);
      w_bd := array_append(w_bd, (v_x.j->>'bd')::bigint);
      w_code := array_append(w_code, v_code);
      w_src := array_append(w_src, v_src);
      w_sid := array_append(w_sid, v_x.j->>'sid');
    END IF;
  END LOOP;

  -- 6. Le rendu, dans l'ordre de p_items.
  RETURN (SELECT coalesce(jsonb_agg(
            CASE WHEN jsonb_typeof(j->'cat') <> 'null'
                   THEN jsonb_build_object('k', (j->>'k')::integer, 'c', j->'cat')
                 WHEN v_imp ? (j->>'k')
                   THEN jsonb_build_object('k', (j->>'k')::integer) || (v_fin->(j->>'k'))
                 WHEN j->>'a1' IS NOT NULL
                   THEN jsonb_build_object('k', (j->>'k')::integer,
                          'c', jsonb_build_object('verdict', 'deja_en_brouillon', 'draft_id', (j->>'a1')::bigint))
                 WHEN j->>'a2' IS NOT NULL
                   THEN jsonb_build_object('k', (j->>'k')::integer,
                          'c', jsonb_build_object('verdict', 'deja_en_brouillon', 'draft_id', (j->>'a2')::bigint))
                 ELSE jsonb_build_object('k', (j->>'k')::integer, 'c', jsonb_build_object('verdict', 'nouveau')) END
            ORDER BY (j->>'k')::integer), '[]'::jsonb)
          FROM jsonb_array_elements(v_j) j);
END
$function$;

REVOKE ALL ON FUNCTION ingest.fn_h33_juger_exemplaires(jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION ingest.fn_h33_juger_exemplaires(jsonb) TO service_role;
COMMENT ON FUNCTION ingest.fn_h33_juger_exemplaires(jsonb) IS
  'H33 (12/10/2026) : le constat (ingest.fn_h21_constat_exemplaire) d''une liste d''exemplaires du fichier, dans l''ordre de création — au catalogue un par un, les brouillons vivants en une lecture, « déjà en brouillon » pour un exemplaire qu''un précédent de la liste fait naître. Pour « Rapprocher » et la promotion ; aide interne.';


-- ─────────────────────────────────────────────────────────────────────
-- 3. « Rapprocher » : ingest.fn_create_exemplar_drafts_from_import_rows
-- ─────────────────────────────────────────────────────────────────────
DO $h33_rapprocher$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h33_def('ingest.fn_create_exemplar_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure);
  v_def := pg_temp.h33_remplacer('rapprocher (déclarations)', v_def,
$a$  v_lot_constat bigint;
begin
$a$,
$b$  v_lot_constat bigint;
  -- H33 (12/10/2026) : le jugement et les écritures en une passe
  v_lignes_j jsonb;               -- les lignes éligibles, dans l'ordre
  v_entree jsonb;                 -- leurs exemplaires, à juger
  v_juge jsonb;                   -- les verdicts (ingest.fn_h33_juger_exemplaires)
  v_ids jsonb;                    -- rang -> identifiant du brouillon créé
  v_final jsonb;                  -- par exemplaire : le constat posé sur la ligne
  v_par_ligne jsonb;              -- par ligne : premier brouillon, signal, constat
  v_ponts jsonb := '{}'::jsonb;   -- cote de la notice -> fonds et cote résolus
  v_ref text;
  v_pont record;
  v_items_demandes bigint := 0;   -- la borne d'une page d'appel
begin
$b$);
  v_def := pg_temp.h33_remplacer('rapprocher (la borne)', v_def,
$a$  if v_requested_count = 0 then
    raise exception 'Aucune ligne eligible au rapprochement pour le run %', p_run_id;
  end if;
$a$,
$b$  if v_requested_count = 0 then
    raise exception 'Aucune ligne eligible au rapprochement pour le run %', p_run_id;
  end if;

  -- H33 (12/10/2026) : une page d'appel porte au plus 200 lignes et 5 000
  -- exemplaires du fichier, comme « Préparer la mise à jour » et le recalcul
  -- (lot 6b, ingest.fn_h21_exemplaires_par_appel) ; l'écran découpe la
  -- sélection (pagesParExemplaires). Au-delà, le plafond de 8 s des appels de
  -- l'API ne tient plus (au banc : 1 000 lignes x 25 exemplaires, 7,3 s).
  if v_requested_count > 200 then
    raise exception 'No maximo 200 linhas por chamada (%).', v_requested_count
      using hint = 'error.import.page_too_large';
  end if;
  select coalesce(sum(case when jsonb_typeof(sr.normalized_payload->'items') = 'array'
                           then jsonb_array_length(sr.normalized_payload->'items') else 0 end), 0)
    into v_items_demandes
  from ingest.partner_catalog_staging_rows sr
  where sr.run_id = p_run_id
    and sr.created_exemplar_draft_id is null
    and sr.created_book_draft_id is null
    and sr.proposed_book_id is not null
    and sr.editorial_decision = 'accept_duplicate'
    and sr.match_status in ('matched_book', 'possible_duplicate', 'manual_decision', 'known_record')
    and (coalesce(array_length(p_row_ids, 1), 0) = 0 or sr.id = any(p_row_ids));
  if v_items_demandes > ingest.fn_h21_exemplaires_par_appel() then
    raise exception 'No maximo % exemplares do arquivo por chamada (%).', ingest.fn_h21_exemplaires_par_appel(), v_items_demandes
      using hint = 'error.import.update_page_too_many_items';
  end if;
$b$);
  v_def := pg_temp.h33_entre('rapprocher (la boucle)', v_def,
$a$  for rec in
    select sr.id as row_id,
$a$,
$a$  v_refresh := ingest.fn_refresh_partner_catalog_run_counters(p_run_id);
$a$,
$b$  -- H33 (12/10/2026) : en une passe. La boucle d'avant constatait, créait le
  -- brouillon puis reliait son fonds exemplaire par exemplaire ; chaque
  -- constat relisait exemplar_drafts, qui grossissait pendant l'appel, sous
  -- des plans bâtis pour une table presque vide (26 s, et de 8 à 80 s, pour
  -- 200 lignes de 25 exemplaires). Les règles d'avant, dans le même ordre :
  -- H19 (IMP-21) un brouillon par exemplaire du fichier, l'exemplaire
  -- implicite seulement pour un format qui n'en décrit jamais (IMP-25) ;
  -- H21 lot 6a (IMP-33) chaque exemplaire constaté, seul « nouveau » crée ;
  -- le constat posé sur la ligne ; une ligne qui n'apporte rien rejetée
  -- d'office (même note), un signal la laisse rattachée ; IMP-35 (lot 8).
  --
  -- 1. Les lignes éligibles et leurs exemplaires, dans l'ordre de la boucle.
  with lg as (
    select sr.id as row_id,
           sr.row_no,
           sr.normalized_payload,
           b.bib_ref as proposed_bib_ref,
           b.titulo  as proposed_titulo,
           sr.proposed_book_id,
           coalesce(sr.raw_payload ? 'item_tag', false) as zone_exemplaire
    from ingest.partner_catalog_staging_rows sr
    join public.books b on b.id = sr.proposed_book_id
    where sr.run_id = p_run_id
      and sr.created_exemplar_draft_id is null
      and sr.created_book_draft_id is null      -- H19
      and sr.proposed_book_id is not null
      and sr.editorial_decision = 'accept_duplicate'
      and sr.match_status in ('matched_book', 'possible_duplicate', 'manual_decision', 'known_record')   -- H21 lot 1
      and (coalesce(array_length(p_row_ids, 1), 0) = 0 or sr.id = any(p_row_ids))
  ), lg2 as (
    select lg.*,
           not coalesce(jsonb_typeof(lg.normalized_payload->'items') = 'array'
                        and jsonb_array_length(lg.normalized_payload->'items') > 0, false)
           and not lg.zone_exemplaire as implicite
      from lg
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'row_id', lg2.row_id, 'row_no', lg2.row_no, 'bib_ref', lg2.proposed_bib_ref,
           'titulo', lg2.proposed_titulo, 'book_id', lg2.proposed_book_id, 'implicite', lg2.implicite,
           'items', case when lg2.implicite then '[{}]'::jsonb
                         when jsonb_typeof(lg2.normalized_payload->'items') = 'array' then lg2.normalized_payload->'items'
                         else '[]'::jsonb end)
         order by lg2.row_no, lg2.row_id), '[]'::jsonb)
    into v_lignes_j
    from lg2;

  select coalesce(jsonb_agg(jsonb_build_object(
           'k', t.k, 'lo', t.lo, 'n', t.n, 'it', t.it,
           'lib', v_lib_imp, 'src', v_source_id, 'book', t.book_id,
           'code', t.it->>'source_item_code', 'item_id', t.it->>'source_item_id',
           'implicite', t.implicite, 'tgt', v_item_library, 'bd', null) order by t.k), '[]'::jsonb)
    into v_entree
    from (select (row_number() over (order by g.lo, e.n))::integer as k, g.lo, e.n, e.it,
                 (g.v->>'book_id')::bigint as book_id, (g.v->>'implicite')::boolean as implicite
            from jsonb_array_elements(v_lignes_j) with ordinality g(v, lo)
            cross join lateral jsonb_array_elements(g.v->'items') with ordinality e(it, n)) t;

  -- 2. Le constat de chacun (ingest.fn_h21_constat_exemplaire, en liste).
  v_juge := ingest.fn_h33_juger_exemplaires(v_entree);

  -- 3. Les identifiants des brouillons à créer, croissants dans l'ordre de la
  --    boucle (le premier d'une ligne est celui qu'elle pointe).
  --    Les deux listes triées, appariées par position (unnest à deux
  --    tableaux) : aucune jointure, aucun plan à deviner.
  select coalesce(jsonb_object_agg(z.k::text, z.id), '{}'::jsonb)
    into v_ids
    from unnest(
           (select array_agg((j->>'k')::integer order by (j->>'k')::integer)
              from jsonb_array_elements(v_juge) j where j->'c'->>'verdict' = 'nouveau'),
           (select array_agg(s.id order by s.id)
              from (select nextval('public.exemplar_drafts_id_seq'::regclass) as id
                      from jsonb_array_elements(v_juge) j where j->'c'->>'verdict' = 'nouveau') s)
         ) as z(k, id);

  -- 4. Le constat posé sur la ligne, exemplaire par exemplaire.
  select coalesce(jsonb_agg(jsonb_build_object(
           'k', e.k, 'lo', e.lo, 'it', e.it,
           'id', case when e.j->'c'->>'verdict' = 'nouveau' then (v_ids->>(e.k::text))::bigint end,
           'c', jsonb_build_object('n', e.n,
                  'code', nullif(btrim(e.it->>'source_item_code'), ''),
                  'expl_id', nullif(btrim(e.it->>'source_item_id'), ''),
                  'cote', nullif(btrim(e.it->>'call_number'), ''))
                || (e.j->'c')
                || case when e.j->>'par' is not null
                        then jsonb_build_object('draft_id', (v_ids->>(e.j->>'par'))::bigint) else '{}'::jsonb end
                || case when e.j->'c'->>'verdict' = 'nouveau'
                        then jsonb_build_object('brouillon_cree', (v_ids->>(e.k::text))::bigint) else '{}'::jsonb end)
         order by e.k), '[]'::jsonb)
    into v_final
    from (select (x->>'k')::integer as k, (x->>'lo')::integer as lo, (x->>'n')::integer as n, x->'it' as it,
                 v_juge->((x->>'k')::integer - 1) as j
            from jsonb_array_elements(v_entree) x) e;

  select v_verdicts || coalesce(jsonb_object_agg(s.v, coalesce((v_verdicts->>s.v)::integer, 0) + s.n), '{}'::jsonb),
         coalesce(sum(s.n) filter (where s.v = 'nouveau'), 0),
         coalesce(sum(s.n) filter (where s.v = 'deja_la'), 0)
    into v_verdicts, v_items_created, v_items_skipped
    from (select f->'c'->>'verdict' as v, count(*)::integer as n
            from jsonb_array_elements(v_final) f group by 1) s;

  select coalesce(jsonb_object_agg(s.lo::text, jsonb_build_object(
           'premier', s.premier, 'signal', s.signal, 'reattribue', s.reattribue, 'nk', s.nk, 'items', s.items)), '{}'::jsonb)
    into v_par_ligne
    from (select (f->>'lo')::integer as lo,
                 min((f->>'id')::bigint) as premier,
                 -- rien à créer : signalé (sans code, déplacé, réétiqueté, code repris)
                 bool_or(f->'c'->>'verdict' in ('sans_code', 'deplace', 'reetiquete', 'code_repris')) as signal,
                 -- H21 lot 8 (IMP-35) : réattribué — ni brouillon ni signal
                 bool_or(f->'c'->>'verdict' = 'reattribue') as reattribue,
                 count(*)::integer as nk,
                 jsonb_agg(f->'c' order by (f->>'k')::integer) as items
            from jsonb_array_elements(v_final) f
           group by 1) s;

  -- 5. Le lot, au premier brouillon (comme avant) : le lot ouvert du run
  --    (IMP-27 d), sinon un lot neuf — B30 : avec la bibliothèque des exemplaires.
  if v_items_created > 0 then
    v_batch_id := ingest.fn_h21_lot_ouvert_du_run(p_run_id, v_item_library);
    if v_batch_id is null then
      insert into public.catalog_batches (name, notes, created_by, library_id)
      values (v_batch_name, v_batch_notes, v_actor, v_item_library)
      returning id into v_batch_id;
    else
      select b.name into v_batch_name from public.catalog_batches b where b.id = v_batch_id;
      v_lot_rejoint := true;
    end if;
  end if;

  -- 6. Le fonds de chaque notice, résolu une fois : ce que
  --    public.sync_exemplar_draft_holdings_bridge faisait pour chaque
  --    brouillon neuf (sans fonds ni exemplaire publié : le fonds de la
  --    bibliothèque pour la cote de la notice, public.resolve_library_holding_bridge),
  --    dans l'ordre des lignes (une cote ambiguë refuse l'appel, comme avant).
  if v_items_created > 0 and v_item_library is not null then
    for v_ref in
      select r.ref
        from (select g.v->>'bib_ref' as ref, min(g.lo) as o
                from jsonb_array_elements(v_lignes_j) with ordinality g(v, lo)
               where v_par_ligne->(g.lo::text)->>'premier' is not null
                 and nullif(trim(g.v->>'bib_ref'), '') is not null
               group by 1) r
       order by r.o
    loop
      select * into v_pont from public.resolve_library_holding_bridge(v_item_library, v_ref) limit 1;
      if found then
        v_ponts := v_ponts || jsonb_build_object(v_ref, jsonb_build_object(
                     'holding_id', v_pont.holding_id,
                     'ref', coalesce(v_pont.local_bib_ref, v_pont.resolved_bib_ref, v_ref)));
      end if;
    end loop;
  end if;

  -- 7. Les brouillons, en un INSERT : avec leur code d'origine (IMP-21 b : pas
  --    dans la note), leur identifiant interne, leur source et leur run (lot 6a).
  insert into public.exemplar_drafts (
    id, batch_id, action, status, label_status,
    target_library_id, target_holding_id, target_bib_ref, source_library, provenance_note,
    source_item_code, shelf_location, notes, import_staging_row_id,
    source_item_id, import_source_id, import_run_id,     -- H21 lot 6a
    created_by, updated_by
  )
  select (x.f->>'id')::bigint, v_batch_id, 'create', 'draft', 'pending',
         v_item_library,
         (v_ponts->(x.g->>'bib_ref')->>'holding_id')::bigint,
         coalesce(v_ponts->(x.g->>'bib_ref')->>'ref', x.g->>'bib_ref'),
         coalesce(nullif(btrim(x.f->'it'->>'owner'), ''), v_partner_name),
         concat_ws(' ',
           format(
             'Exemplar criado a partir de catalogo parceiro "%s" (%s, run %s, linha %s): biblioteca importadora declara possuir um exemplar de "%s".',
             coalesce(v_partner_name, 'parceiro sem nome'),
             coalesce(v_original_filename, 'arquivo sem nome'),
             p_run_id,
             x.g->>'row_no',
             coalesce(x.g->>'titulo', 'sem titulo')),
           'Tipo: ' || nullif(btrim(x.f->'it'->>'item_type'), '') || '.',
           'Publico: ' || nullif(btrim(x.f->'it'->>'public'), '') || '.',
           'Situacao: ' || nullif(btrim(x.f->'it'->>'status'), '') || '.'),
         nullif(btrim(x.f->'it'->>'source_item_code'), ''),
         nullif(btrim(x.f->'it'->>'call_number'), ''),
         nullif(btrim(x.f->'it'->>'note'), ''),
         (x.g->>'row_id')::bigint,
         nullif(btrim(x.f->'it'->>'source_item_id'), ''), v_source_id, p_run_id,
         v_actor, v_actor
    from (select f, v_lignes_j->((f->>'lo')::integer - 1) as g
            from jsonb_array_elements(v_final) f
           where f->>'id' is not null) x
   order by (x.f->>'id')::bigint;

  -- 8. Les lignes, en un UPDATE. Le constat désigne le lot où le rapport de
  --    révision le montrera — celui de ce rapprochement, sinon (rien créé) le
  --    lot ouvert du run s'il y en a un, sans en ouvrir. Une ligne qui a un
  --    brouillon pointe le premier ; sans brouillon, un signal la laisse
  --    rattachée (plus sélectionnée) ; sinon elle est rejetée d'office — avec la
  --    note d'avant, que ingest.fn_h21_rejet_par_choix reconnaît.
  v_lot_constat := coalesce(v_batch_id, ingest.fn_h21_lot_ouvert_du_run(p_run_id, v_item_library));
  update ingest.partner_catalog_staging_rows sr
     set exemplaires_constat = jsonb_build_object(
           'version', 'h21-lot6a/2026-10-08', 'via', 'rapprochement', 'at', now(),
           'run_id', p_run_id, 'library_id', v_lib_imp, 'book_id', x.book_id,
           'source_id', v_source_id, 'sans_exemplaire_decrit', x.nk = 0,
           'batch_id', v_lot_constat, 'items', x.items),
         created_exemplar_draft_id = coalesce(x.premier, sr.created_exemplar_draft_id),
         review_status = case when x.premier is not null then 'draft_created'
                              when x.signal then sr.review_status
                              else 'rejected' end,
         selected_for_draft = false,
         editorial_decision = case when x.premier is null and not x.signal then 'reject' else sr.editorial_decision end,
         editorial_note = case when x.premier is null and not x.signal then
                            case when x.nk = 0
                              then 'Todos os exemplares desta linha ja estao na biblioteca (o arquivo nao descreve nenhum exemplar desta linha): nada a aproximar.'
                              when x.reattribue
                              then 'Todos os exemplares desta linha ja estao na biblioteca ou foram reatribuidos a outra biblioteca (mesma origem): nada a aproximar.'
                              else 'Todos os exemplares desta linha ja estao na biblioteca (mesmo codigo de origem): nada a aproximar.' end
                          else sr.editorial_note end,
         editorial_decided_at = case when x.premier is null and not x.signal then now() else sr.editorial_decided_at end,
         editorial_decided_by = case when x.premier is null and not x.signal then v_actor else sr.editorial_decided_by end
    from (select (g.v->>'row_id')::bigint as row_id,
                 (g.v->>'book_id')::bigint as book_id,
                 (v_par_ligne->(g.lo::text)->>'premier')::bigint as premier,
                 coalesce((v_par_ligne->(g.lo::text)->>'signal')::boolean, false) as signal,
                 coalesce((v_par_ligne->(g.lo::text)->>'reattribue')::boolean, false) as reattribue,
                 coalesce((v_par_ligne->(g.lo::text)->>'nk')::integer, 0) as nk,
                 coalesce(v_par_ligne->(g.lo::text)->'items', '[]'::jsonb) as items
            from jsonb_array_elements(v_lignes_j) with ordinality g(v, lo)) x
   where sr.id = x.row_id;

  select count(*) filter (where v_par_ligne->(g.lo::text)->>'premier' is not null),
         count(*) filter (where v_par_ligne->(g.lo::text)->>'premier' is null
                            and not coalesce((v_par_ligne->(g.lo::text)->>'signal')::boolean, false)),
         count(*) filter (where v_par_ligne->(g.lo::text)->>'premier' is null
                            and coalesce((v_par_ligne->(g.lo::text)->>'signal')::boolean, false))
    into v_created_count, v_rows_held, v_rows_signalees
    from jsonb_array_elements(v_lignes_j) with ordinality g(v, lo);

$b$);
  EXECUTE v_def;
END
$h33_rapprocher$;


-- ─────────────────────────────────────────────────────────────────────
-- 4. La promotion : la borne (ingest.fn_create_book_drafts_from_import_rows),
--    puis les exemplaires (ingest.fn_create_item_drafts_for_batch)
-- ─────────────────────────────────────────────────────────────────────
DO $h33_promotion_borne$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h33_def('ingest.fn_create_book_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure);
  v_def := pg_temp.h33_remplacer('promotion borne (déclaration)', v_def,
$a$  v_livre jsonb;               -- H21 lot 2 : la ligne vue comme notice
$a$,
$b$  v_livre jsonb;               -- H21 lot 2 : la ligne vue comme notice
  v_items_demandes bigint := 0;   -- H33 : la borne d'une page d'appel
$b$);
  v_def := pg_temp.h33_remplacer('promotion borne (comptes)', v_def,
$a$    select count(*)::integer
      into v_requested_count
$a$,
$b$    select count(*)::integer,
           coalesce(sum(case when jsonb_typeof(sr.normalized_payload->'items') = 'array'
                             then jsonb_array_length(sr.normalized_payload->'items') else 0 end), 0)   -- H33
      into v_requested_count, v_items_demandes
$b$, 2);
  v_def := pg_temp.h33_remplacer('promotion borne (refus)', v_def,
$a$  if v_requested_count = 0 then
    raise exception 'Aucune ligne autorisée à convertir pour le run %', p_run_id;
  end if;
$a$,
$b$  if v_requested_count = 0 then
    raise exception 'Aucune ligne autorisée à convertir pour le run %', p_run_id;
  end if;

  -- H33 (12/10/2026) : une page d'appel porte au plus 200 lignes et 5 000
  -- exemplaires du fichier, comme « Préparer la mise à jour » (lot 6b) ;
  -- l'écran et l'assistant découpent la sélection (pagesParExemplaires).
  -- Au-delà, le plafond de 8 s des appels de l'API ne tient plus (au banc :
  -- 1 000 lignes nouvelles, 4 à 5 s pour les seules notices ; x 25
  -- exemplaires, 17,8 s).
  if v_requested_count > 200 then
    raise exception 'No maximo 200 linhas por chamada (%).', v_requested_count
      using hint = 'error.import.page_too_large';
  end if;
  if v_items_demandes > ingest.fn_h21_exemplaires_par_appel() then
    raise exception 'No maximo % exemplares do arquivo por chamada (%).', ingest.fn_h21_exemplaires_par_appel(), v_items_demandes
      using hint = 'error.import.update_page_too_many_items';
  end if;
$b$);
  EXECUTE v_def;
END
$h33_promotion_borne$;

DO $h33_promotion$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.h33_def('ingest.fn_create_item_drafts_for_batch(bigint, uuid, bigint[])'::regprocedure);
  v_def := pg_temp.h33_remplacer('promotion (déclarations)', v_def,
$a$  v_x bigint;
BEGIN
$a$,
$b$  v_x bigint;
  -- H33 (12/10/2026) : le jugement et les écritures en une passe
  v_lignes_j jsonb;
  v_entree jsonb;
  v_juge jsonb;
  v_ids jsonb;
  v_final jsonb;
  v_lib uuid;
BEGIN
$b$);
  v_def := pg_temp.h33_entre('promotion (la boucle)', v_def,
$a$  FOR rec IN
    SELECT m.staging_row_id, m.draft_id, m.run_id, sr.row_no, sr.normalized_payload,
$a$,
$a$  RETURN v_n;
END;
$a$,
$b$  -- H33 (12/10/2026) : en une passe, comme « Rapprocher » (la boucle d'avant
  -- relisait exemplar_drafts à chaque exemplaire pendant qu'elle y insérait :
  -- 20,8 s pour 200 lignes nouvelles de 25 exemplaires). Les règles d'avant,
  -- dans le même ordre : chaque exemplaire du fichier constaté pour la
  -- bibliothèque importatrice, la notice étant nouvelle ; seul « nouveau »
  -- entre dans les brouillons ; le constat posé sur la ligne.
  WITH lg AS (
    SELECT m.staging_row_id, m.draft_id, m.run_id, sr.row_no, sr.normalized_payload,
           d.owner_library_id, r.original_filename, s.partner_name, r.source_id
      FROM ingest.partner_catalog_row_to_draft m
      JOIN ingest.partner_catalog_staging_rows sr ON sr.id = m.staging_row_id
      JOIN public.book_drafts d ON d.id = m.draft_id
      JOIN ingest.partner_catalog_import_runs r ON r.id = m.run_id
      LEFT JOIN ingest.partner_catalog_sources s ON s.id = r.source_id
     WHERE m.batch_id = p_batch_id
       -- IMP-27 (d) : les lignes de la promotion en cours (NULL : tout le lot).
       AND (p_staging_row_ids IS NULL OR m.staging_row_id = ANY (p_staging_row_ids))
       AND d.status IN ('draft', 'ready')
       AND jsonb_typeof(sr.normalized_payload->'items') = 'array'
       AND jsonb_array_length(sr.normalized_payload->'items') > 0
       AND NOT EXISTS (SELECT 1 FROM public.exemplar_drafts x WHERE x.book_draft_id = m.draft_id)
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'staging_row_id', lg.staging_row_id, 'draft_id', lg.draft_id, 'run_id', lg.run_id, 'row_no', lg.row_no,
           'owner_library_id', lg.owner_library_id, 'original_filename', lg.original_filename,
           'partner_name', lg.partner_name, 'source_id', lg.source_id,
           'lib_imp', ingest.fn_h21_bibliotheque_importatrice(lg.run_id, NULL, lg.owner_library_id),
           'items', lg.normalized_payload->'items')
         ORDER BY lg.row_no, lg.staging_row_id), '[]'::jsonb)
    INTO v_lignes_j
    FROM lg;

  -- Le verrou d'avis de chaque bibliothèque importatrice, dans l'ordre où la
  -- boucle d'avant le prenait (deux constats concurrents).
  FOR v_lib IN
    SELECT (g.v->>'lib_imp')::uuid
      FROM jsonb_array_elements(v_lignes_j) WITH ORDINALITY g(v, lo)
     WHERE g.v->>'lib_imp' IS NOT NULL
     GROUP BY 1
     ORDER BY min(g.lo)
  LOOP
    PERFORM pg_advisory_xact_lock(hashtextextended('h21-lot6a/exemplaires/' || v_lib::text, 0));
  END LOOP;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'k', t.k, 'lo', t.lo, 'n', t.n, 'it', t.it,
           'lib', t.g->'lib_imp', 'src', t.g->'source_id', 'book', NULL,
           'code', t.it->>'source_item_code', 'item_id', t.it->>'source_item_id',
           'implicite', false, 'tgt', t.g->'owner_library_id', 'bd', t.g->'draft_id') ORDER BY t.k), '[]'::jsonb)
    INTO v_entree
    FROM (SELECT (row_number() OVER (ORDER BY g.lo, e.n))::integer AS k, g.lo, e.n, e.it, g.v AS g
            FROM jsonb_array_elements(v_lignes_j) WITH ORDINALITY g(v, lo)
            CROSS JOIN LATERAL jsonb_array_elements(g.v->'items') WITH ORDINALITY e(it, n)) t;

  v_juge := ingest.fn_h33_juger_exemplaires(v_entree);

  -- Les identifiants, croissants dans l'ordre de la boucle d'avant.
  SELECT coalesce(jsonb_object_agg(z.k::text, z.id), '{}'::jsonb)
    INTO v_ids
    FROM unnest(
           (SELECT array_agg((j->>'k')::integer ORDER BY (j->>'k')::integer)
              FROM jsonb_array_elements(v_juge) j WHERE j->'c'->>'verdict' = 'nouveau'),
           (SELECT array_agg(s.id ORDER BY s.id)
              FROM (SELECT nextval('public.exemplar_drafts_id_seq'::regclass) AS id
                      FROM jsonb_array_elements(v_juge) j WHERE j->'c'->>'verdict' = 'nouveau') s)
         ) AS z(k, id);

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'k', e.k, 'lo', e.lo, 'it', e.it,
           'id', CASE WHEN e.j->'c'->>'verdict' = 'nouveau' THEN (v_ids->>(e.k::text))::bigint END,
           'c', jsonb_build_object('n', e.n,
                  'code', nullif(btrim(e.it->>'source_item_code'), ''),
                  'expl_id', nullif(btrim(e.it->>'source_item_id'), ''),
                  'cote', nullif(btrim(e.it->>'call_number'), ''))
                || (e.j->'c')
                || CASE WHEN e.j->>'par' IS NOT NULL
                        THEN jsonb_build_object('draft_id', (v_ids->>(e.j->>'par'))::bigint) ELSE '{}'::jsonb END
                || CASE WHEN e.j->'c'->>'verdict' = 'nouveau'
                        THEN jsonb_build_object('brouillon_cree', (v_ids->>(e.k::text))::bigint) ELSE '{}'::jsonb END)
         ORDER BY e.k), '[]'::jsonb)
    INTO v_final
    FROM (SELECT (x->>'k')::integer AS k, (x->>'lo')::integer AS lo, (x->>'n')::integer AS n, x->'it' AS it,
                 v_juge->((x->>'k')::integer - 1) AS j
            FROM jsonb_array_elements(v_entree) x) e;

  -- Sans tombo (numérotation « B » : il sera pris dans le schéma de la
  -- bibliothèque à la publication), avec le code d'origine (IMP-21 b), la cote,
  -- la note, le propriétaire ; type, public et statut dans la note de
  -- provenance (IMP-21 d).
  INSERT INTO public.exemplar_drafts (
    id, batch_id, action, status, label_status,
    book_draft_id, import_staging_row_id, target_library_id,
    source_item_code, shelf_location, notes, source_library, provenance_note,
    source_item_id, import_source_id, import_run_id,     -- H21 lot 6a
    created_by, updated_by
  )
  SELECT (x.f->>'id')::bigint, p_batch_id, 'create', 'draft', 'pending',
         (x.g->>'draft_id')::bigint, (x.g->>'staging_row_id')::bigint, (x.g->>'owner_library_id')::uuid,
         nullif(btrim(x.f->'it'->>'source_item_code'), ''),
         nullif(btrim(x.f->'it'->>'call_number'), ''),
         nullif(btrim(x.f->'it'->>'note'), ''),
         nullif(btrim(x.f->'it'->>'owner'), ''),
         concat_ws(' ',
           format('Exemplar importado de "%s" (%s, run %s, linha %s).',
                  coalesce(x.g->>'partner_name', 'parceiro sem nome'),
                  coalesce(x.g->>'original_filename', 'arquivo sem nome'), x.g->>'run_id', x.g->>'row_no'),
           'Tipo: ' || nullif(btrim(x.f->'it'->>'item_type'), '') || '.',
           'Publico: ' || nullif(btrim(x.f->'it'->>'public'), '') || '.',
           'Situacao: ' || nullif(btrim(x.f->'it'->>'status'), '') || '.'),
         nullif(btrim(x.f->'it'->>'source_item_id'), ''), (x.g->>'source_id')::bigint, (x.g->>'run_id')::bigint,
         v_actor, v_actor
    FROM (SELECT f, v_lignes_j->((f->>'lo')::integer - 1) AS g
            FROM jsonb_array_elements(v_final) f
           WHERE f->>'id' IS NOT NULL) x
   ORDER BY (x.f->>'id')::bigint;
  GET DIAGNOSTICS v_n = ROW_COUNT;

  WITH par_ligne AS (
    SELECT (f->>'lo')::integer AS lo, jsonb_agg(f->'c' ORDER BY (f->>'k')::integer) AS items
      FROM jsonb_array_elements(v_final) f
     GROUP BY 1
  )
  UPDATE ingest.partner_catalog_staging_rows sr
     SET exemplaires_constat = jsonb_build_object(
           'version', 'h21-lot6a/2026-10-08', 'via', 'promotion', 'at', now(),
           'run_id', x.g->'run_id', 'library_id', x.g->'lib_imp', 'book_id', NULL, 'source_id', x.g->'source_id', 'source_id', x.g->'source_id',
           'book_draft_id', x.g->'draft_id', 'batch_id', p_batch_id, 'items', x.items)
    FROM (SELECT g.v AS g, coalesce(p.items, '[]'::jsonb) AS items
            FROM jsonb_array_elements(v_lignes_j) WITH ORDINALITY g(v, lo)
            LEFT JOIN par_ligne p ON p.lo = g.lo) x
   WHERE sr.id = (x.g->>'staging_row_id')::bigint;
$b$);
  EXECUTE v_def;
END
$h33_promotion$;


-- ─────────────────────────────────────────────────────────────────────
-- 5. Vérification structurelle
-- ─────────────────────────────────────────────────────────────────────
DO $h33_verif$
DECLARE
  v_e text := '';
  v_f text;
  v_constat text := pg_get_functiondef('ingest.fn_h21_constat_exemplaire(uuid, bigint, bigint, text, text)'::regprocedure);
  v_cat text := pg_get_functiondef('ingest.fn_h21_constat_exemplaire_au_catalogue(uuid, bigint, bigint, text, text)'::regprocedure);
  v_juge text := pg_get_functiondef('ingest.fn_h33_juger_exemplaires(jsonb)'::regprocedure);
  v_rap text := pg_get_functiondef('ingest.fn_create_exemplar_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure);
  v_pro text := pg_get_functiondef('ingest.fn_create_item_drafts_for_batch(bigint, uuid, bigint[])'::regprocedure);
BEGIN
  -- le constat délègue le catalogue et garde ses brouillons ; le catalogue
  -- n'a pas de brouillons et finit par NULL
  IF position('ingest.fn_h21_constat_exemplaire_au_catalogue(p_library, p_source, p_book_id, p_code, p_item_id)' IN v_constat) = 0
     OR position('e.source_item_code = v_code' IN v_constat) > 0
     OR position('AND y.target_library_id = p_library' IN v_constat) = 0
     OR position('public.fn_book_draft_library(y.book_draft_id) = p_library' IN v_constat) = 0
     OR position('exemplar_drafts' IN v_cat) > 0
     OR position('RETURN NULL;' IN v_cat) = 0
     OR position('''reattribue''' IN v_cat) = 0
     OR position('''code_repris''' IN v_cat) = 0 THEN
    v_e := v_e || ' constat';
  END IF;
  -- le jugement : le catalogue par la règle unique, les deux bras des brouillons
  IF position('ingest.fn_h21_constat_exemplaire_au_catalogue(' IN v_juge) = 0
     OR position('y.target_library_id = $1' IN v_juge) = 0
     OR position('public.fn_book_draft_library(y.book_draft_id) = $1' IN v_juge) = 0 THEN
    v_e := v_e || ' jugement';
  END IF;
  -- « Rapprocher » et la promotion : en une passe, gardes en place
  IF position('ingest.fn_h33_juger_exemplaires(v_entree)' IN v_rap) = 0
     OR position('for rec in' IN v_rap) > 0
     OR position('sync_exemplar_draft_holdings_bridge(' IN v_rap) > 0
     OR position('public.resolve_library_holding_bridge(v_item_library, v_ref)' IN v_rap) = 0
     OR position('error.import.deposit_admin_only' IN v_rap) = 0
     OR position('h21-lot6a/exemplaires/' IN v_rap) = 0
     OR position('ingest.fn_h21_lot_ouvert_du_run(p_run_id, v_item_library)' IN v_rap) = 0
     OR position('ingest.fn_refresh_partner_catalog_run_counters(p_run_id)' IN v_rap) = 0 THEN
    v_e := v_e || ' rapprocher';
  END IF;
  IF position('ingest.fn_h33_juger_exemplaires(v_entree)' IN v_pro) = 0
     OR position('FOR rec IN' IN v_pro) > 0
     OR position('h21-lot6a/exemplaires/' IN v_pro) = 0
     OR position('NOT EXISTS (SELECT 1 FROM public.exemplar_drafts x WHERE x.book_draft_id = m.draft_id)' IN v_pro) = 0 THEN
    v_e := v_e || ' promotion';
  END IF;
  -- la borne d'une page d'appel, dans les deux gestes
  IF position('error.import.page_too_large' IN v_rap) = 0
     OR position('ingest.fn_h21_exemplaires_par_appel()' IN v_rap) = 0
     OR position('error.import.page_too_large' IN pg_get_functiondef('ingest.fn_create_book_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure)) = 0
     OR position('error.import.update_page_too_many_items' IN pg_get_functiondef('ingest.fn_create_book_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure)) = 0 THEN
    v_e := v_e || ' borne';
  END IF;
  -- les identifiants viennent de la séquence de la colonne
  IF pg_get_serial_sequence('public.exemplar_drafts', 'id') IS DISTINCT FROM 'public.exemplar_drafts_id_seq' THEN
    v_e := v_e || ' sequence';
  END IF;
  -- droits : les fonctions modifiées restent DEFINER à search_path, fermées à
  -- l'API ; les aides fermées
  FOREACH v_f IN ARRAY ARRAY['ingest.fn_create_exemplar_drafts_from_import_rows(bigint, bigint[], text, text, uuid)',
                             'ingest.fn_create_item_drafts_for_batch(bigint, uuid, bigint[])',
                             'ingest.fn_create_book_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'] LOOP
    IF has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
       OR NOT has_function_privilege('service_role', v_f, 'EXECUTE')
       OR NOT (SELECT p.prosecdef AND coalesce(p.proconfig::text, '') LIKE '%search_path%' FROM pg_proc p WHERE p.oid = v_f::regprocedure) THEN
      v_e := v_e || ' droits(' || v_f || ')';
    END IF;
  END LOOP;
  FOREACH v_f IN ARRAY ARRAY['ingest.fn_h21_constat_exemplaire(uuid, bigint, bigint, text, text)',
                             'ingest.fn_h21_constat_exemplaire_au_catalogue(uuid, bigint, bigint, text, text)',
                             'ingest.fn_h33_juger_exemplaires(jsonb)'] LOOP
    IF has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
       OR NOT has_function_privilege('service_role', v_f, 'EXECUTE')
       OR EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
                   WHERE p.oid = v_f::regprocedure AND a.grantee = 0)
       OR (SELECT p.prosecdef OR coalesce(p.proconfig::text, '') NOT LIKE '%search_path%' FROM pg_proc p WHERE p.oid = v_f::regprocedure) THEN
      v_e := v_e || ' droits-aides(' || v_f || ')';
    END IF;
  END LOOP;
  IF v_e <> '' THEN
    RAISE EXCEPTION 'H33 : vérification en échec :%', v_e;
  END IF;
  RAISE NOTICE 'H33 : vérifications OK';
END
$h33_verif$;

NOTIFY pgrst, 'reload schema';
