-- =====================================================================
-- AnarBib — E34 : « Éditer » une notice en consultation la rendait
--                 empruntable à la publication — la reprise garde sa circulation
-- Date    : 2026-10-08
-- Ref     : backlog v34 E34 (ouvert le 07/10 sur constat de la revue sceptique
--           du lot 5 de H21, qui a corrigé le même oubli dans SA copie,
--           ingest.fn_h21_copie_de_la_notice — 20261007175456, point 8 B1).
--
-- Le défaut. public.create_book_draft_from_book (« Éditer » / « Reprendre »
-- une notice publiée, CatalogPanel) recopie 90 colonnes de la notice dans le
-- brouillon — pas circulation_default. Le brouillon naît donc au défaut de la
-- colonne ('emprestavel'). À la publication, le déclencheur
-- fn_propagate_circulation_default_on_publish (AFTER UPDATE OF status →
-- 'published') réécrit sur la notice circulation_default = celle du brouillon
-- ET loanable = (circulation_default IS DISTINCT FROM 'consulta') : une notice
-- « consultation sur place » redevient empruntable sans que personne l'ait
-- choisi, et un document qui ne doit pas quitter la bibliothèque peut sortir.
-- Même cause que serial_id le 27/08/2026 (20260827210000) : une colonne de
-- books vit à TROIS endroits — book_drafts, publish_book_draft (deux
-- branches, et ici un déclencheur de publication), create_book_draft_from_book
-- — et la troisième avait été oubliée quand la colonne est née (20260622).
--
-- Ce qui a protégé les notices jusqu'ici : l'écran. BookDraftForm, en
-- chargeant le brouillon, RECALCULE la circulation depuis loanable (recopié,
-- lui) — « loanable false ⇒ 'consulta' » — et l'enregistre avec le reste ; en
-- production (lecture seule, 08/10/2026) les douze notices en consultation ont
-- tous leurs brouillons publiés à 'consulta', aucune n'a basculé par ce chemin.
-- Mais la règle ne doit pas tenir à un recalcul d'écran : un brouillon publié
-- tel qu'il naît (« Publier le lot », l'API, un écran qui ne passe pas par le
-- formulaire) bascule la notice.
--
-- Le correctif, en un geste : la reprise recopie circulation_default. Sur la
-- définition VIVANTE (pg_get_functiondef, retours chariot retirés), par ancres
-- comptées ; signature, droits et search_path inchangés (pas de DROP ; CREATE
-- OR REPLACE garde l'ACL : postgres, authenticated, service_role — pas anon).
-- md5 de prosrc lu le 08/10/2026 en production (MCP, lecture seule) :
--   public.create_book_draft_from_book   d1cd9eb260d7f163eaf54113b055d384
--
-- Revue des colonnes (la vérification finale la rejoue, et la suite la garde
-- pour les colonnes à venir) : toute colonne commune à books et book_drafts
-- est recopiée, sauf — à dessein — id, created_at, updated_at, created_by,
-- updated_by (posés par la reprise), work_id (publish_book_draft l'écrit en
-- coalesce : NULL garde celui de la notice) et publisher_id (déduit d'editora
-- par déclencheur, sur le brouillon comme sur la notice).
--
-- Données : AUCUNE correction ici. Les notices dont la circulation aurait
-- changé par ce chemin ne se distinguent pas en base (la bascule les laisse
-- cohérentes) ; ce qui a été relevé est soumis à Xavier dans la fiche E34.
-- Suite : tests/sql/e34_reprise_garde_la_circulation_tests.sql.
-- =====================================================================

-- Outils de la migration, éphémères (pg_temp).
CREATE OR REPLACE FUNCTION pg_temp.e34_remplacer(p_quoi text, p_def text, p_old text, p_new text, p_n int DEFAULT 1)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_n int;
BEGIN
  IF coalesce(p_old, '') = '' THEN
    RAISE EXCEPTION 'E34 — % : ancre vide', p_quoi;
  END IF;
  v_n := (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old);
  IF v_n <> p_n THEN
    RAISE EXCEPTION 'E34 — % : ancre trouvée % fois (attendu %) — relire la définition réelle', p_quoi, v_n, p_n;
  END IF;
  RETURN replace(p_def, p_old, p_new);
END
$f$;

CREATE OR REPLACE FUNCTION pg_temp.e34_def(p_fn regprocedure)
RETURNS text LANGUAGE sql AS $f$
  SELECT replace(pg_get_functiondef(p_fn), E'\r', '');
$f$;

-- ─────────────────────────────────────────────────────────────────────
-- 1. La reprise recopie circulation_default
-- ─────────────────────────────────────────────────────────────────────
DO $e34_copie$
DECLARE v_def text;
BEGIN
  v_def := pg_temp.e34_def('public.create_book_draft_from_book(bigint, bigint)'::regprocedure);
  v_def := pg_temp.e34_remplacer('create_book_draft_from_book (colonnes)', v_def,
$a$    zine_format, zine_print_run, zine_technique, distribuidora, gravadora, subjects,
    created_by, updated_by
  )$a$,
$b$    zine_format, zine_print_run, zine_technique, distribuidora, gravadora, subjects,
    -- E34 (08/10/2026) : le déclencheur de publication
    -- (fn_propagate_circulation_default_on_publish) réécrit circulation_default
    -- ET loanable sur la notice depuis le brouillon : sans la recopie, le
    -- défaut 'emprestavel' rendait empruntable une notice en consultation.
    circulation_default,
    created_by, updated_by
  )$b$);
  v_def := pg_temp.e34_remplacer('create_book_draft_from_book (valeurs)', v_def,
$a$    b.zine_format, b.zine_print_run, b.zine_technique, b.distribuidora, b.gravadora, b.subjects,
    auth.uid(), auth.uid()
  from public.books b$a$,
$b$    b.zine_format, b.zine_print_run, b.zine_technique, b.distribuidora, b.gravadora, b.subjects,
    b.circulation_default,
    auth.uid(), auth.uid()
  from public.books b$b$);
  EXECUTE v_def;
END
$e34_copie$;

-- ─────────────────────────────────────────────────────────────────────
-- 2. Vérifications : la recopie, toutes les colonnes communes, les droits
-- ─────────────────────────────────────────────────────────────────────
DO $e34_verif$
DECLARE
  v_e text := '';
  v_src text;
  v_manquantes text[];
  c_fn constant text := 'public.create_book_draft_from_book(bigint, bigint)';
BEGIN
  SELECT p.prosrc INTO v_src FROM pg_proc p WHERE p.oid = c_fn::regprocedure;
  IF v_src IS NULL OR position('b.circulation_default' IN v_src) = 0 THEN
    v_e := v_e || ' recopie-absente';
  END IF;
  -- Toute colonne commune à books et book_drafts est recopiée (b.<colonne>),
  -- hors les sept exceptions voulues (en-tête).
  SELECT coalesce(array_agg(b.column_name ORDER BY b.column_name), '{}') INTO v_manquantes
    FROM information_schema.columns b
    JOIN information_schema.columns d
      ON d.table_schema = 'public' AND d.table_name = 'book_drafts' AND d.column_name = b.column_name
   WHERE b.table_schema = 'public' AND b.table_name = 'books'
     AND b.column_name NOT IN ('id', 'created_at', 'updated_at', 'created_by', 'updated_by', 'work_id', 'publisher_id')
     AND v_src !~ ('\mb\.' || b.column_name || '\M');
  IF cardinality(v_manquantes) > 0 THEN
    v_e := v_e || ' colonnes-non-recopiées(' || array_to_string(v_manquantes, ',') || ')';
  END IF;
  -- Droits et nature inchangés : DEFINER, search_path figé, ouverte aux
  -- comptes connectés et à service_role, jamais à anon ni à PUBLIC.
  IF NOT has_function_privilege('authenticated', c_fn, 'EXECUTE')
     OR NOT has_function_privilege('service_role', c_fn, 'EXECUTE')
     OR has_function_privilege('anon', c_fn, 'EXECUTE')
     OR EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
                 WHERE p.oid = c_fn::regprocedure AND a.grantee = 0) THEN
    v_e := v_e || ' droits';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p WHERE p.oid = c_fn::regprocedure
              AND (NOT p.prosecdef OR coalesce(p.proconfig::text, '') NOT LIKE '%search_path%')) THEN
    v_e := v_e || ' definer';
  END IF;
  IF v_e <> '' THEN
    RAISE EXCEPTION 'E34 : vérification en échec :%', v_e;
  END IF;
  RAISE NOTICE 'E34 : vérifications OK — la reprise recopie circulation_default';
END
$e34_verif$;

NOTIFY pgrst, 'reload schema';
