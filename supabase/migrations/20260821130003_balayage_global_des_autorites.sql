-- =========================================================================
-- Paquet DOUBLONS P10 — balayage global des doublons d'AUTORITÉS
-- =========================================================================
-- Date     : 2026-08-21
-- Chantier : catalogage / dédoublonnage
-- Auteur   : Xavier (+ Claude)
-- Session  : Dédoublonnage & arbitrage
--
-- POURQUOI. `suggest_author_duplicates` travaille autorité par autorité. Il n'y
-- avait donc AUCUN moyen de voir l'état des doublons d'autorités : il aurait
-- fallu ouvrir les 1 300 fiches une par une. Conséquence mesurée le 21/08 : le
-- signalement (paquet P8) était le seul chemin par lequel un doublon d'autorité
-- parvenait à la coordination — beaucoup reposer sur un geste volontaire.
--
-- MÊMES RÈGLES DE DÉTECTION, À LA LETTRE (`DEDUP-6`). On reprend celles de
-- `suggest_author_duplicates` : les FORMES d'une autorité sont son
-- preferred_name normalisé, son sort_name normalisé et ses alias actifs ; une
-- paire est retenue si le preferred_name normalisé de l'une figure parmi les
-- formes de l'autre, ou si la similarité trigramme atteint 0,45. La règle est
-- appliquée DANS LES DEUX SENS, parce qu'une autorité peut porter un alias que
-- l'autre n'a pas. Seuls l'ordre et deux colonnes d'explication sont nouveaux.
--
-- LE PROBLÈME DE COÛT, ET SA VRAIE SOLUTION. Écrit naïvement, ce balayage est
-- un produit cartésien : 1 300 autorités = 844 350 paires, chacune calculant
-- des similarités. Mesuré : **87 secondes**. Inutilisable.
--
-- Les index trigrammes existants ne pouvaient pas aider : ils portent sur
-- `f_normalize_search`, qui CONSERVE l'ordre des mots, alors que la détection
-- utilise `fn_normalize_name`, qui les TRIE — c'est précisément ce qui fait
-- correspondre « Ian Curtis » et « Curtis, Ian ». Sur 1 300 autorités, les deux
-- normalisations divergent 817 fois sur le nom d'affichage et 1 299 fois sur le
-- nom de tri. S'appuyer sur ces index aurait changé la détection ; on ne l'a
-- donc pas fait.
--
-- La solution est un index sur LA normalisation qui sert vraiment, rendue
-- possible par le fait que `fn_normalize_name` est IMMUTABLE. Le balayage
-- devient alors une sonde indexée par forme (~3 000 sondes) au lieu d'un
-- produit cartésien.
--
-- L'opérateur `%` sert de PRÉ-FILTRE : son seuil (0,3 par défaut) est inférieur
-- au seuil de détection (0,45), il ne peut donc que sur-sélectionner. On le fixe
-- explicitement, pour qu'une session ayant relevé le seuil ne fasse pas
-- disparaître des paires en silence.
--
-- CHECKLIST DOCTRINE :
--   [x] SET search_path (public, extensions, pg_catalog — extensions pour pg_trgm)
--   [x] REVOKE EXECUTE ... FROM PUBLIC, anon
--   [x] GRANT EXECUTE ... TO authenticated
--   [x] Garde staff interne, identique à suggest_author_duplicates
--   [x] DO block de vérification
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. L'index qui rend le balayage possible
-- -------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS authors_fn_normalize_name_trgm_idx
  ON public.authors
  USING gin (public.fn_normalize_name(preferred_name) extensions.gin_trgm_ops);

COMMENT ON INDEX public.authors_fn_normalize_name_trgm_idx IS
  'Trigrammes sur la normalisation qui TRIE les mots (fn_normalize_name), celle qu''utilise '
  'le dédoublonnage — à ne pas confondre avec authors_preferred_name_norm_trgm_idx, qui '
  'porte sur f_normalize_search et conserve l''ordre. Sans cet index, le balayage global '
  'est un produit cartésien de 844 350 paires : 87 s mesurées. Paquet DOUBLONS P10.';

-- -------------------------------------------------------------------------
-- 2. Le balayage
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.suggest_authority_duplicates(p_max integer DEFAULT 500)
RETURNS TABLE (
  author_id_a   bigint,
  nom_a         text,
  tri_a         text,
  oeuvres_a     integer,
  author_id_b   bigint,
  nom_b         text,
  tri_b         text,
  oeuvres_b     integer,
  match_kind    text,
  score         real,
  niveau_preuve text,
  rang_preuve   integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog'
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid()
                   AND m.role = ANY (ARRAY['librarian','coordenador'])
                   AND m.status = 'active') THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;

  -- Le pré-filtre `%` doit rester plus large que le seuil de détection (0,45).
  -- Sans ce réglage, une session ayant relevé pg_trgm.similarity_threshold
  -- ferait disparaître des paires sans que rien ne le signale.
  PERFORM set_config('pg_trgm.similarity_threshold', '0.3', true);

  RETURN QUERY
  WITH formes AS (
    -- Les trois sources de formes, exactement comme suggest_author_duplicates.
    SELECT a.id, public.fn_normalize_name(a.preferred_name) AS f FROM public.authors a
    UNION
    SELECT a.id, public.fn_normalize_name(a.sort_name) FROM public.authors a
    UNION
    SELECT al.author_id, al.alias_norm FROM public.author_name_aliases al WHERE al.is_active
  ), formes_net AS (
    SELECT id, f FROM formes WHERE f IS NOT NULL AND f <> ''
  ), candidats AS (
    -- Une sonde INDEXÉE par forme, au lieu du produit cartésien.
    SELECT DISTINCT least(fo.id, b.id) AS ida, greatest(fo.id, b.id) AS idb
    FROM formes_net fo
    JOIN public.authors b
      ON b.id <> fo.id
     AND public.fn_normalize_name(b.preferred_name) % fo.f
  ), evalues AS (
    SELECT c.ida, c.idb,
           aa.preferred_name AS na, aa.sort_name AS sa,
           ab.preferred_name AS nb, ab.sort_name AS sb,
           public.fn_normalize_name(aa.preferred_name) AS npa,
           public.fn_normalize_name(ab.preferred_name) AS npb,
           aa.birth_year AS ba, aa.death_year AS da,
           ab.birth_year AS bb, ab.death_year AS db,
           nullif(btrim(coalesce(aa.viaf_id, aa.isni, '')), '') AS xa,
           nullif(btrim(coalesce(ab.viaf_id, ab.isni, '')), '') AS xb
    FROM candidats c
    JOIN public.authors aa ON aa.id = c.ida
    JOIN public.authors ab ON ab.id = c.idb
  ), scores AS (
    SELECT e.*,
           -- Règle appliquée dans les DEUX sens : une autorité peut porter un
           -- alias que l'autre n'a pas.
           (EXISTS (SELECT 1 FROM formes_net f WHERE f.id = e.ida AND f.f = e.npb)
            OR EXISTS (SELECT 1 FROM formes_net f WHERE f.id = e.idb AND f.f = e.npa)) AS exact,
           greatest(
             coalesce((SELECT max(similarity(e.npb, f.f)) FROM formes_net f WHERE f.id = e.ida), 0),
             coalesce((SELECT max(similarity(e.npa, f.f)) FROM formes_net f WHERE f.id = e.idb), 0)
           )::real AS sc
    FROM evalues e
  ), classes AS (
    SELECT s.*,
           -- coalesce indispensable : sans lui, deux autorités sans aucune date
           -- donnent NULL, et la paire se range dans AUCUN niveau — 27 paires
           -- perdues en silence lors de la mesure du 21/08.
           coalesce((s.ba IS NOT NULL AND s.ba = s.bb) OR (s.da IS NOT NULL AND s.da = s.db), false) AS dates_ok,
           coalesce(s.xa IS NOT NULL AND s.xa = s.xb, false) AS meme_id
    FROM scores s
    WHERE s.exact OR s.sc >= 0.45
  )
  SELECT
    k.ida, k.na, k.sa,
    (SELECT count(DISTINCT ba.book_id)::integer FROM public.book_authors ba WHERE ba.author_id = k.ida),
    k.idb, k.nb, k.sb,
    (SELECT count(DISTINCT bb.book_id)::integer FROM public.book_authors bb WHERE bb.author_id = k.idb),
    CASE WHEN k.exact THEN 'exact' ELSE 'approx' END,
    k.sc,
    CASE WHEN k.meme_id  THEN 'identifiant'
         WHEN k.exact    THEN 'nom_exact'
         WHEN k.dates_ok THEN 'nom_et_dates'
         ELSE 'nom_seul' END,
    CASE WHEN k.meme_id  THEN 1
         WHEN k.exact    THEN 2
         WHEN k.dates_ok THEN 3
         ELSE 4 END
  FROM classes k
  ORDER BY
    CASE WHEN k.meme_id THEN 1 WHEN k.exact THEN 2 WHEN k.dates_ok THEN 3 ELSE 4 END,
    k.sc DESC, k.na
  LIMIT greatest(1, coalesce(p_max, 500));
END;
$function$;

REVOKE ALL ON FUNCTION public.suggest_authority_duplicates(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.suggest_authority_duplicates(integer) TO authenticated;

COMMENT ON FUNCTION public.suggest_authority_duplicates(integer) IS
  'Balayage global des doublons d''autorités. Pendant de suggest_catalog_duplicates pour '
  'les autorités, et mêmes règles de détection que suggest_author_duplicates (formes = nom '
  'affiché, nom de tri, alias actifs ; exact ou similarité >= 0,45, dans les deux sens). '
  'Trié par NIVEAU DE PREUVE : identifiant externe partagé, puis nom exact, puis nom + '
  'dates concordantes, puis nom seul — la bande où se cachent les faux positifs. '
  'Staff de catalogage. Paquet DOUBLONS P10 du 21/08/2026.';

-- -------------------------------------------------------------------------
-- 3. Vérification
-- -------------------------------------------------------------------------
DO $$
BEGIN
  IF to_regprocedure('public.suggest_authority_duplicates(integer)') IS NULL THEN
    RAISE EXCEPTION 'suggest_authority_duplicates absente. Rollback.';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_indexes
                  WHERE schemaname = 'public' AND indexname = 'authors_fn_normalize_name_trgm_idx') THEN
    RAISE EXCEPTION 'L''index trigramme est absent — le balayage serait inutilisable. Rollback.';
  END IF;

  IF EXISTS (SELECT 1 FROM pg_proc pr JOIN pg_namespace ns ON ns.oid = pr.pronamespace
             WHERE ns.nspname = 'public' AND pr.proname = 'suggest_authority_duplicates'
               AND has_function_privilege('anon', pr.oid, 'EXECUTE')) THEN
    RAISE EXCEPTION 'suggest_authority_duplicates exécutable par anon. Rollback.';
  END IF;

  RAISE NOTICE 'Paquet DOUBLONS P10 : vérifications OK.';
END $$;

COMMIT;

-- =========================================================================
-- Rollback ciblé :
--   BEGIN;
--     DROP FUNCTION IF EXISTS public.suggest_authority_duplicates(integer);
--     DROP INDEX IF EXISTS public.authors_fn_normalize_name_trgm_idx;
--   COMMIT;
-- =========================================================================
