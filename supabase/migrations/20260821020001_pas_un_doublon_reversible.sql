-- =========================================================================
-- Paquet DOUBLONS P3 — « Pas un doublon » réversible et attribué
-- =========================================================================
-- Date     : 2026-08-20
-- Chantier : catalogage / dédoublonnage (lot 2 du plan « Dédoublonner sans casser »)
-- Auteur   : Xavier (+ Claude)
-- Session  : Dédoublonnage & arbitrage
--
-- POURQUOI. mark_books_not_duplicate écrit dans public.book_not_duplicate, et la
-- paire disparaît alors DÉFINITIVEMENT de toutes les détections du réseau —
-- suggest_book_duplicates, api.suggest_draft_duplicates, suggest_duplicates_for_fields
-- et suggest_catalog_duplicates la consultent toutes. Aucune interface ne permet
-- d'y revenir. C'est aujourd'hui le seul geste du catalogage sans retour arrière
-- possible, et il est offert au profil le moins formé, à côté d'actions
-- inoffensives et sous la même apparence : un « ménage » de bonne foi peut
-- masquer pour tout le monde de vrais doublons, sans trace exploitable.
--
-- La table portait déjà created_by et created_at, et le GRANT DELETE au staff
-- existe depuis sa création (20260620083749) : la réversibilité était permise en
-- base, elle n'était simplement jamais exposée. Ce paquet ajoute donc le strict
-- nécessaire, sans rien changer aux règles de détection.
--
--   1. book_not_duplicate.reason — motif facultatif, pour que la décision reste
--      lisible six mois plus tard (« deux volumes », « deux éditions »…).
--   2. mark_books_not_duplicate(bigint, bigint, text) — même fonction, un
--      paramètre de plus, NULL par défaut. Le DROP est imposé : ajouter un
--      argument à défaut sans supprimer l'ancienne signature rendrait tout appel
--      à deux arguments ambigu. DROP et CREATE sont dans la même transaction,
--      donc sans fenêtre d'indisponibilité. Les trois appelants existants
--      passent p_a/p_b nommés et continuent de fonctionner sans changement.
--   3. unmark_books_not_duplicate(bigint, bigint) — le geste symétrique.
--   4. list_books_not_duplicate(integer) — de quoi afficher les paires écartées
--      avec leurs titres, la personne qui a arbitré et la date ; la table ne
--      stocke que des identifiants.
--
-- CE QUE CE PAQUET NE FAIT PAS. Il ne touche pas au NIVEAU de rôle exigé :
-- écarter et rétablir restent ouverts à bibliothécaire comme à coordination,
-- exactement comme avant. Le relèvement à la seule coordination est le lot 1 du
-- plan, indépendant de celui-ci. Les deux gardes devront être relevées ENSEMBLE :
-- il ne doit jamais exister d'état où l'on peut écarter sans pouvoir rétablir.
--
-- CHECKLIST DOCTRINE (fonctions SECURITY DEFINER) :
--   [x] SET search_path = public, pg_catalog
--   [x] REVOKE EXECUTE ... FROM PUBLIC, anon
--   [x] GRANT EXECUTE ... TO authenticated
--   [x] Garde staff interne, reprise à l'identique de l'existant
--   [x] DO block de vérification (la migration touche des droits d'exécution)
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. Motif d'arbitrage (facultatif)
-- -------------------------------------------------------------------------
ALTER TABLE public.book_not_duplicate
  ADD COLUMN IF NOT EXISTS reason text;

COMMENT ON COLUMN public.book_not_duplicate.reason IS
  'Motif facultatif de l''arbitrage « ce ne sont pas des doublons » (ex. « deux volumes », '
  '« deux éditions distinctes »). Saisi par le staff, lisible dans la liste des paires '
  'écartées. Ajouté par le paquet DOUBLONS P3 du 21/08/2026.';

-- -------------------------------------------------------------------------
-- 2. Écarter une paire — même garde, plus un motif
-- -------------------------------------------------------------------------
-- Le DROP est obligatoire : conserver mark_books_not_duplicate(bigint, bigint)
-- à côté d'une version (bigint, bigint, text DEFAULT NULL) rendrait tout appel
-- à deux arguments ambigu et casserait les trois appelants du catalogage.
DROP FUNCTION IF EXISTS public.mark_books_not_duplicate(bigint, bigint);

CREATE OR REPLACE FUNCTION public.mark_books_not_duplicate(
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
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid()
                   AND m.role = ANY (ARRAY['librarian','coordenador'])
                   AND m.status = 'active') THEN
    RAISE EXCEPTION 'Apenas bibliotecárias e coordenadoras podem editar o catálogo.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;

  IF p_a IS NULL OR p_b IS NULL OR p_a = p_b THEN
    RAISE EXCEPTION 'Par de documentos inválido.'
      USING ERRCODE = 'P0001', HINT = 'error.catalog.notDuplicate.invalidPair';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.books WHERE id = p_a)
     OR NOT EXISTS (SELECT 1 FROM public.books WHERE id = p_b) THEN
    RAISE EXCEPTION 'Documento inexistente.'
      USING ERRCODE = 'P0002', HINT = 'error.catalog.notDuplicate.invalidPair';
  END IF;

  v_lo := least(p_a, p_b);
  v_hi := greatest(p_a, p_b);

  INSERT INTO public.book_not_duplicate (book_id_a, book_id_b, created_by, reason)
  VALUES (v_lo, v_hi, auth.uid(), nullif(btrim(coalesce(p_reason, '')), ''))
  ON CONFLICT (book_id_a, book_id_b) DO NOTHING;
END;
$function$;

REVOKE ALL ON FUNCTION public.mark_books_not_duplicate(bigint, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_books_not_duplicate(bigint, bigint, text) TO authenticated;

COMMENT ON FUNCTION public.mark_books_not_duplicate(bigint, bigint, text) IS
  'Écarte définitivement une paire de documents des détections de doublons, avec motif '
  'facultatif. Réversible depuis le 21/08/2026 via unmark_books_not_duplicate. '
  'Staff de catalogage uniquement.';

-- -------------------------------------------------------------------------
-- 3. Rétablir une paire écartée
-- -------------------------------------------------------------------------
-- La paire redevient visible dans toutes les détections. Rien n'est recréé :
-- on retire une ligne d'arbitrage, les deux documents n'ont jamais été touchés.
CREATE OR REPLACE FUNCTION public.unmark_books_not_duplicate(
  p_a bigint,
  p_b bigint
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
  -- Garde identique à mark_books_not_duplicate : qui peut écarter peut rétablir.
  -- Toute divergence entre les deux créerait un cul-de-sac.
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid()
                   AND m.role = ANY (ARRAY['librarian','coordenador'])
                   AND m.status = 'active') THEN
    RAISE EXCEPTION 'Apenas bibliotecárias e coordenadoras podem editar o catálogo.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;

  IF p_a IS NULL OR p_b IS NULL OR p_a = p_b THEN
    RAISE EXCEPTION 'Par de documentos inválido.'
      USING ERRCODE = 'P0001', HINT = 'error.catalog.notDuplicate.invalidPair';
  END IF;

  v_lo := least(p_a, p_b);
  v_hi := greatest(p_a, p_b);

  DELETE FROM public.book_not_duplicate
  WHERE book_id_a = v_lo AND book_id_b = v_hi;
END;
$function$;

REVOKE ALL ON FUNCTION public.unmark_books_not_duplicate(bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.unmark_books_not_duplicate(bigint, bigint) TO authenticated;

COMMENT ON FUNCTION public.unmark_books_not_duplicate(bigint, bigint) IS
  'Rétablit une paire écartée : elle réapparaît dans les détections de doublons. '
  'Aucun document n''est modifié — seule la ligne d''arbitrage est retirée. '
  'Staff de catalogage uniquement. Paquet DOUBLONS P3 du 21/08/2026.';

-- -------------------------------------------------------------------------
-- 4. Lister les paires écartées, avec de quoi les relire
-- -------------------------------------------------------------------------
-- book_not_duplicate ne stocke que des identifiants : sans cette fonction,
-- l'interface ne pourrait afficher qu'une liste de nombres. On renvoie les
-- titres des deux côtés, le motif, la date et le nom de la personne qui a
-- arbitré — c'est ce qui rend la décision relisible, donc contestable.
CREATE OR REPLACE FUNCTION public.list_books_not_duplicate(p_max integer DEFAULT 200)
RETURNS TABLE (
  book_id_a       bigint,
  ref_a           text,
  titulo_a        text,
  autor_a         text,
  ano_a           text,
  book_id_b       bigint,
  ref_b           text,
  titulo_b        text,
  autor_b         text,
  ano_b           text,
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
  SELECT
    ba.id, ba.bib_ref, ba.titulo, ba.autor, ba.ano,
    bb.id, bb.bib_ref, bb.titulo, bb.autor, bb.ano,
    nd.reason,
    nd.created_at,
    -- Prénom + nom, jamais l'e-mail : savoir QUI a arbitré suffit à rendre la
    -- décision discutable, exposer une adresse ne sert à rien de plus.
    nullif(btrim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')), '')
  FROM public.book_not_duplicate nd
  JOIN public.books ba ON ba.id = nd.book_id_a
  JOIN public.books bb ON bb.id = nd.book_id_b
  LEFT JOIN public.profiles p ON p.id = nd.created_by
  ORDER BY nd.created_at DESC
  LIMIT greatest(1, coalesce(p_max, 200));
END;
$function$;

REVOKE ALL ON FUNCTION public.list_books_not_duplicate(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_books_not_duplicate(integer) TO authenticated;

COMMENT ON FUNCTION public.list_books_not_duplicate(integer) IS
  'Paires de documents écartées des détections de doublons, les plus récentes d''abord, '
  'avec titres, motif, date et personne ayant arbitré. Staff de catalogage uniquement. '
  'Paquet DOUBLONS P3 du 21/08/2026.';

-- -------------------------------------------------------------------------
-- 5. Vérification (rollback automatique en cas d'échec)
-- -------------------------------------------------------------------------
DO $$
DECLARE
  v_mark_sigs int;
  v_n         int;
BEGIN
  -- L'ancienne signature à deux arguments ne doit plus exister : deux surcharges
  -- dont l'une a un défaut rendraient les appels existants ambigus.
  SELECT count(*) INTO v_mark_sigs
  FROM pg_proc pr
  JOIN pg_namespace ns ON ns.oid = pr.pronamespace
  WHERE ns.nspname = 'public' AND pr.proname = 'mark_books_not_duplicate';

  IF v_mark_sigs <> 1 THEN
    RAISE EXCEPTION 'mark_books_not_duplicate : % signature(s) au lieu d''une seule. Rollback.', v_mark_sigs;
  END IF;

  -- Le geste symétrique et la liste doivent exister.
  IF to_regprocedure('public.unmark_books_not_duplicate(bigint,bigint)') IS NULL THEN
    RAISE EXCEPTION 'unmark_books_not_duplicate absente. Rollback.';
  END IF;
  IF to_regprocedure('public.list_books_not_duplicate(integer)') IS NULL THEN
    RAISE EXCEPTION 'list_books_not_duplicate absente. Rollback.';
  END IF;

  -- Aucune des trois ne doit être exécutable par anon (doctrine advisors 0028/0029).
  SELECT count(*) INTO v_n
  FROM pg_proc pr
  JOIN pg_namespace ns ON ns.oid = pr.pronamespace
  WHERE ns.nspname = 'public'
    AND pr.proname IN ('mark_books_not_duplicate', 'unmark_books_not_duplicate', 'list_books_not_duplicate')
    AND has_function_privilege('anon', pr.oid, 'EXECUTE');

  IF v_n > 0 THEN
    RAISE EXCEPTION 'Paquet DOUBLONS P3 : % fonction(s) encore exécutables par anon. Rollback.', v_n;
  END IF;

  RAISE NOTICE 'Paquet DOUBLONS P3 : vérifications OK.';
END $$;

COMMIT;

-- =========================================================================
-- Rollback ciblé :
--   BEGIN;
--     DROP FUNCTION IF EXISTS public.list_books_not_duplicate(integer);
--     DROP FUNCTION IF EXISTS public.unmark_books_not_duplicate(bigint, bigint);
--     DROP FUNCTION IF EXISTS public.mark_books_not_duplicate(bigint, bigint, text);
--     CREATE OR REPLACE FUNCTION public.mark_books_not_duplicate(p_a bigint, p_b bigint)
--       ... (corps d'origine, migration 20260620083749_dedup_edition_aware_not_duplicate.sql)
--     ALTER TABLE public.book_not_duplicate DROP COLUMN IF EXISTS reason;
--   COMMIT;
-- =========================================================================
