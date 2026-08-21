-- =========================================================================
-- Paquet DOUBLONS P11 — « pas un doublon » pour les AUTORITÉS
-- =========================================================================
-- Date     : 2026-08-21
-- Chantier : catalogage / dédoublonnage
-- Auteur   : Xavier (+ Claude)
-- Session  : Dédoublonnage & arbitrage
--
-- POURQUOI. Depuis le paquet P8, la coordination peut clore un signalement
-- d'autorité — mais clore ne fait qu'acquitter : la paire réapparaît à la
-- détection suivante. C'est le défaut que les documents avaient avant le paquet
-- P3, et il use plus vite qu'il n'y paraît : sur 95 paires d'autorités
-- détectées, la bande « nom seul » en compte 79, pleine de faux positifs qu'on
-- reverra indéfiniment. Une file qu'on ne peut pas vider est une file qu'on
-- cesse d'ouvrir.
--
-- LE PATRON EST CELUI DE P3, délibérément : table de paires ordonnées, motif et
-- attribution, RPC pour écarter, RPC pour rétablir, RPC pour lister. Qui a
-- compris l'arbitrage des documents retrouve le même ici.
--
-- ÉCARTER ET RÉTABLIR SONT RELEVÉS ENSEMBLE (`DEDUP-2`). Les deux exigent
-- l'arbitrage ; il ne doit jamais exister d'état où l'on peut écarter sans
-- pouvoir rétablir. Lire, en revanche, reste au niveau staff : relire une
-- décision est ce qui la rend contestable.
--
-- LES DEUX DÉTECTIONS SONT MISES À JOUR ENSEMBLE (`DEDUP-6`). C'est le point
-- délicat de ce paquet : `suggest_author_duplicates` (par autorité) et
-- `suggest_authority_duplicates` (balayage global, créé le jour même) doivent
-- exclure les mêmes paires, sans quoi les deux vues divergeraient — une paire
-- écartée disparaîtrait d'un écran et pas de l'autre. Les corps sont repris à
-- l'identique ; seule une clause NOT EXISTS est ajoutée à chacun.
--
-- CE QUI N'EST PAS CHANGÉ, ET POURQUOI. La garde de `suggest_author_duplicates`
-- ne vérifie pas `status = 'active'` — contrairement aux fonctions écrites
-- depuis. C'est un écart réel, mais sur une fonction en LECTURE SEULE, et le
-- corriger au détour d'une migration sur l'arbitrage serait un changement
-- silencieux. Il est signalé ici pour être traité pour lui-même.
--
-- CHECKLIST DOCTRINE :
--   [x] Table dans public : GRANT explicites, RLS, policy, GRANT ALL service_role
--   [x] Fonctions SECURITY DEFINER : search_path, REVOKE PUBLIC/anon, GRANT
--   [x] Gardes internes (arbitre pour écarter/rétablir, staff pour lire)
--   [x] DO block de vérification
--   [x] Table classée dans deploy/bg2-known-tables.txt (filet BG2)
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. La table d'arbitrage
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.author_not_duplicate (
  author_id_a bigint NOT NULL REFERENCES public.authors(id) ON DELETE CASCADE,
  author_id_b bigint NOT NULL REFERENCES public.authors(id) ON DELETE CASCADE,
  reason      text,
  created_by  uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (author_id_a, author_id_b),
  CONSTRAINT author_not_duplicate_ordered CHECK (author_id_a < author_id_b)
);

REVOKE ALL ON public.author_not_duplicate FROM anon, authenticated;
GRANT ALL ON public.author_not_duplicate TO service_role;

ALTER TABLE public.author_not_duplicate ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies
                  WHERE schemaname = 'public' AND tablename = 'author_not_duplicate'
                    AND policyname = 'author_not_duplicate_staff_select') THEN
    CREATE POLICY author_not_duplicate_staff_select
      ON public.author_not_duplicate
      FOR SELECT TO authenticated
      USING (EXISTS (SELECT 1 FROM public.user_library_memberships m
                      WHERE m.user_id = auth.uid()
                        AND m.role = ANY (ARRAY['librarian','coordenador'])
                        AND m.status = 'active'));
  END IF;
END $$;

COMMENT ON TABLE public.author_not_duplicate IS
  'Paires d''autorités arbitrées « ce ne sont pas des doublons » : elles quittent les deux '
  'détections (par autorité et balayage global). Réversible et attribuée, comme '
  'book_not_duplicate. Paquet DOUBLONS P11 du 21/08/2026.';

-- -------------------------------------------------------------------------
-- 2. Écarter — coordination
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_authors_not_duplicate(
  p_a      bigint,
  p_b      bigint,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_lo bigint;
  v_hi bigint;
BEGIN
  IF NOT public.fn_is_dedup_arbiter() THEN
    RAISE EXCEPTION 'Arbitragem reservada à coordenação.'
      USING ERRCODE = '42501', HINT = 'error.catalog.arbiter_only';
  END IF;

  IF p_a IS NULL OR p_b IS NULL OR p_a = p_b THEN
    RAISE EXCEPTION 'Par de autoridades inválido.'
      USING ERRCODE = 'P0001', HINT = 'error.catalog.notDuplicate.invalidPair';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.authors WHERE id = p_a)
     OR NOT EXISTS (SELECT 1 FROM public.authors WHERE id = p_b) THEN
    RAISE EXCEPTION 'Autoridade inexistente.'
      USING ERRCODE = 'P0002', HINT = 'error.catalog.notDuplicate.invalidPair';
  END IF;

  v_lo := least(p_a, p_b);
  v_hi := greatest(p_a, p_b);

  INSERT INTO public.author_not_duplicate (author_id_a, author_id_b, created_by, reason)
  VALUES (v_lo, v_hi, auth.uid(), nullif(btrim(coalesce(p_reason, '')), ''))
  ON CONFLICT (author_id_a, author_id_b) DO NOTHING;

  -- Arbitrer une paire signalée répond au signalement : le laisser ouvert
  -- ferait revenir la coordination sur une décision déjà prise.
  UPDATE public.authority_duplicate_reports
     SET status = 'closed', closed_by = auth.uid(), closed_at = now()
   WHERE author_id_a = v_lo AND author_id_b = v_hi AND status = 'open';
END;
$function$;

REVOKE ALL ON FUNCTION public.mark_authors_not_duplicate(bigint, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_authors_not_duplicate(bigint, bigint, text) TO authenticated;

COMMENT ON FUNCTION public.mark_authors_not_duplicate(bigint, bigint, text) IS
  'Écarte une paire d''autorités des deux détections, avec motif facultatif, et clôt le '
  'signalement éventuel. Réversible via unmark_authors_not_duplicate. Coordination.';

-- -------------------------------------------------------------------------
-- 3. Rétablir — relevé EN MÊME TEMPS qu'écarter (DEDUP-2)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.unmark_authors_not_duplicate(p_a bigint, p_b bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
  IF NOT public.fn_is_dedup_arbiter() THEN
    RAISE EXCEPTION 'Arbitragem reservada à coordenação.'
      USING ERRCODE = '42501', HINT = 'error.catalog.arbiter_only';
  END IF;

  IF p_a IS NULL OR p_b IS NULL OR p_a = p_b THEN
    RAISE EXCEPTION 'Par de autoridades inválido.'
      USING ERRCODE = 'P0001', HINT = 'error.catalog.notDuplicate.invalidPair';
  END IF;

  DELETE FROM public.author_not_duplicate
  WHERE author_id_a = least(p_a, p_b) AND author_id_b = greatest(p_a, p_b);
END;
$function$;

REVOKE ALL ON FUNCTION public.unmark_authors_not_duplicate(bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.unmark_authors_not_duplicate(bigint, bigint) TO authenticated;

COMMENT ON FUNCTION public.unmark_authors_not_duplicate(bigint, bigint) IS
  'Rétablit une paire d''autorités écartée : elle réapparaît dans les deux détections. '
  'Aucune autorité n''est modifiée. Coordination. Paquet DOUBLONS P11.';

-- -------------------------------------------------------------------------
-- 4. Lister — niveau staff (relire pour contester)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.list_authors_not_duplicate(p_max integer DEFAULT 200)
RETURNS TABLE (
  author_id_a     bigint,
  nom_a           text,
  tri_a           text,
  author_id_b     bigint,
  nom_b           text,
  tri_b           text,
  reason          text,
  created_at      timestamptz,
  created_by_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid()
                   AND m.role = ANY (ARRAY['librarian','coordenador'])
                   AND m.status = 'active') THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;

  RETURN QUERY
  SELECT aa.id, aa.preferred_name, aa.sort_name,
         ab.id, ab.preferred_name, ab.sort_name,
         nd.reason, nd.created_at,
         nullif(btrim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')), '')
  FROM public.author_not_duplicate nd
  JOIN public.authors aa ON aa.id = nd.author_id_a
  JOIN public.authors ab ON ab.id = nd.author_id_b
  LEFT JOIN public.profiles p ON p.id = nd.created_by
  ORDER BY nd.created_at DESC
  LIMIT greatest(1, coalesce(p_max, 200));
END;
$function$;

REVOKE ALL ON FUNCTION public.list_authors_not_duplicate(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_authors_not_duplicate(integer) TO authenticated;

COMMENT ON FUNCTION public.list_authors_not_duplicate(integer) IS
  'Paires d''autorités écartées, les plus récentes d''abord, avec motif, date et personne '
  'ayant arbitré. Staff de catalogage — relire une décision est ce qui la rend '
  'contestable. Paquet DOUBLONS P11.';

-- -------------------------------------------------------------------------
-- 5. Les DEUX détections excluent les paires arbitrées
-- -------------------------------------------------------------------------
-- Corps repris à l'identique, une seule clause ajoutée à chacun. Si une seule
-- des deux était mise à jour, une paire écartée disparaîtrait d'un écran et pas
-- de l'autre : c'est exactement ce que DEDUP-6 interdit.

CREATE OR REPLACE FUNCTION public.suggest_author_duplicates(p_author_id bigint)
RETURNS TABLE(author_id bigint, preferred_name text, sort_name text,
              linked_books integer, match_kind text, score real)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog'
AS $function$
DECLARE
  v_forms text[];
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid()
      AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
  ) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.';
  END IF;

  SELECT array_agg(DISTINCT nf) INTO v_forms
  FROM (
    SELECT public.fn_normalize_name(a.preferred_name) AS nf FROM public.authors a WHERE a.id = p_author_id
    UNION
    SELECT public.fn_normalize_name(a.sort_name) FROM public.authors a WHERE a.id = p_author_id
    UNION
    SELECT al.alias_norm FROM public.author_name_aliases al WHERE al.author_id = p_author_id AND al.is_active
  ) s
  WHERE s.nf <> '';

  IF v_forms IS NULL OR array_length(v_forms, 1) IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH other AS (
    SELECT a.id, a.preferred_name, a.sort_name,
           public.fn_normalize_name(a.preferred_name) AS np
    FROM public.authors a
    WHERE a.id <> p_author_id
  )
  SELECT o.id, o.preferred_name, o.sort_name,
         (SELECT count(DISTINCT ba.book_id)::integer FROM public.book_authors ba WHERE ba.author_id = o.id),
         CASE WHEN o.np = ANY (v_forms) THEN 'exact' ELSE 'approx' END,
         CASE WHEN o.np = ANY (v_forms) THEN 1.0::real
              ELSE (SELECT max(similarity(o.np, f)) FROM unnest(v_forms) f) END
  FROM other o
  WHERE o.np <> ''
    AND ( o.np = ANY (v_forms)
          OR (SELECT max(similarity(o.np, f)) FROM unnest(v_forms) f) >= 0.45 )
    -- AJOUT P11 : les paires arbitrées « pas un doublon » sortent de la détection.
    AND NOT EXISTS (
      SELECT 1 FROM public.author_not_duplicate nd
       WHERE nd.author_id_a = least(p_author_id, o.id)
         AND nd.author_id_b = greatest(p_author_id, o.id)
    )
  ORDER BY 6 DESC, o.preferred_name;
END;
$function$;

COMMENT ON FUNCTION public.suggest_author_duplicates(bigint) IS
  'Doublons probables d''une autorité. Exclut depuis le paquet DOUBLONS P11 les paires '
  'arbitrées « pas un doublon » (author_not_duplicate) — même exclusion que le balayage '
  'global, pour que les deux vues ne divergent pas.';

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

  PERFORM set_config('pg_trgm.similarity_threshold', '0.3', true);

  RETURN QUERY
  WITH formes AS (
    SELECT a.id, public.fn_normalize_name(a.preferred_name) AS f FROM public.authors a
    UNION
    SELECT a.id, public.fn_normalize_name(a.sort_name) FROM public.authors a
    UNION
    SELECT al.author_id, al.alias_norm FROM public.author_name_aliases al WHERE al.is_active
  ), formes_net AS (
    SELECT id, f FROM formes WHERE f IS NOT NULL AND f <> ''
  ), candidats AS (
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
    -- AJOUT P11 : même exclusion que la détection par autorité.
    WHERE NOT EXISTS (
      SELECT 1 FROM public.author_not_duplicate nd
       WHERE nd.author_id_a = c.ida AND nd.author_id_b = c.idb
    )
  ), scores AS (
    SELECT e.*,
           (EXISTS (SELECT 1 FROM formes_net f WHERE f.id = e.ida AND f.f = e.npb)
            OR EXISTS (SELECT 1 FROM formes_net f WHERE f.id = e.idb AND f.f = e.npa)) AS exact,
           greatest(
             coalesce((SELECT max(similarity(e.npb, f.f)) FROM formes_net f WHERE f.id = e.ida), 0),
             coalesce((SELECT max(similarity(e.npa, f.f)) FROM formes_net f WHERE f.id = e.idb), 0)
           )::real AS sc
    FROM evalues e
  ), classes AS (
    SELECT s.*,
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

COMMENT ON FUNCTION public.suggest_authority_duplicates(integer) IS
  'Balayage global des doublons d''autorités, trié par niveau de preuve. Exclut depuis le '
  'paquet DOUBLONS P11 les paires arbitrées « pas un doublon » — même exclusion que '
  'suggest_author_duplicates. Staff de catalogage.';

-- -------------------------------------------------------------------------
-- 6. Vérification
-- -------------------------------------------------------------------------
DO $$
DECLARE v_lack text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_tables
                  WHERE schemaname = 'public' AND tablename = 'author_not_duplicate'
                    AND rowsecurity) THEN
    RAISE EXCEPTION 'RLS absente sur author_not_duplicate. Rollback.';
  END IF;

  IF has_table_privilege('authenticated', 'public.author_not_duplicate', 'INSERT') THEN
    RAISE EXCEPTION 'author_not_duplicate insérable en direct. Rollback.';
  END IF;

  -- Le cœur du paquet : les DEUX détections doivent exclure les paires arbitrées.
  SELECT string_agg(pr.proname, ', ') INTO v_lack
  FROM pg_proc pr JOIN pg_namespace ns ON ns.oid = pr.pronamespace
  WHERE ns.nspname = 'public'
    AND pr.proname IN ('suggest_author_duplicates', 'suggest_authority_duplicates')
    AND pg_get_functiondef(pr.oid) NOT LIKE '%author_not_duplicate%';
  IF v_lack IS NOT NULL THEN
    RAISE EXCEPTION '% n''exclut(ent) pas les paires arbitrées — les deux vues divergeraient. Rollback.', v_lack;
  END IF;

  -- Écarter et rétablir doivent exiger le MÊME niveau (DEDUP-2).
  SELECT string_agg(pr.proname, ', ') INTO v_lack
  FROM pg_proc pr JOIN pg_namespace ns ON ns.oid = pr.pronamespace
  WHERE ns.nspname = 'public'
    AND pr.proname IN ('mark_authors_not_duplicate', 'unmark_authors_not_duplicate')
    AND pg_get_functiondef(pr.oid) NOT LIKE '%fn_is_dedup_arbiter()%';
  IF v_lack IS NOT NULL THEN
    RAISE EXCEPTION '% n''exige(nt) pas l''arbitrage. Rollback.', v_lack;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_proc pr JOIN pg_namespace ns ON ns.oid = pr.pronamespace
             WHERE ns.nspname = 'public'
               AND pr.proname IN ('mark_authors_not_duplicate', 'unmark_authors_not_duplicate',
                                  'list_authors_not_duplicate')
               AND has_function_privilege('anon', pr.oid, 'EXECUTE')) THEN
    RAISE EXCEPTION 'Paquet DOUBLONS P11 : fonction exécutable par anon. Rollback.';
  END IF;

  RAISE NOTICE 'Paquet DOUBLONS P11 : vérifications OK.';
END $$;

COMMIT;

-- =========================================================================
-- Rollback ciblé : reprendre les corps du 20260821130003 (balayage) et de la
-- migration d'origine de suggest_author_duplicates, puis :
--   BEGIN;
--     DROP FUNCTION IF EXISTS public.list_authors_not_duplicate(integer);
--     DROP FUNCTION IF EXISTS public.unmark_authors_not_duplicate(bigint, bigint);
--     DROP FUNCTION IF EXISTS public.mark_authors_not_duplicate(bigint, bigint, text);
--     DROP TABLE IF EXISTS public.author_not_duplicate;
--   COMMIT;
-- =========================================================================
