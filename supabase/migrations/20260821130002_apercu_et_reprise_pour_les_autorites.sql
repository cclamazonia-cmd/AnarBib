-- =========================================================================
-- Paquet DOUBLONS P9 — aperçu et reprise de champs pour les AUTORITÉS
-- =========================================================================
-- Date     : 2026-08-21
-- Chantier : catalogage / dédoublonnage
-- Auteur   : Xavier (+ Claude)
-- Session  : Dédoublonnage & arbitrage
--
-- POURQUOI. Les documents ont reçu l'aperçu (P6) puis la reprise de champs (P7).
-- `merge_author` en est restée au comportement que `merge_book` avait le matin
-- même : elle garde les métadonnées de la seule survivante et jette le reste,
-- sans rien annoncer.
--
-- CE QUI EST EN JEU, mesuré le 21/08 sur les 1 300 autorités du réseau :
-- 574 portent des dates, 578 un pays, 75 une biographie, 28 un identifiant VIAF
-- ou ISNI. Fusionner une autorité riche dans une autorité pauvre détruit tout
-- cela en silence. Ce n'est pas une hypothèse : c'est le cas le plus fréquent,
-- puisque le doublon est souvent la fiche récente et documentée, et la
-- canonique la vieille entrée sommaire.
--
-- MÊME ARCHITECTURE QUE POUR LES DOCUMENTS, délibérément. `merge_author` n'est
-- pas touchée : `merge_author_with_fields` prépare la canonique puis DÉLÈGUE.
-- Deux raisons. La première, mécanique : ne pas recopier un corps qui repointe
-- sept tables. La seconde, humaine : quelqu'un qui a compris le montage côté
-- documents le retrouve identique ici, jusqu'aux noms.
--
-- CE QUI N'EST PAS REPRENABLE, et pourquoi c'est plus court qu'ailleurs :
-- `authors` n'a aucune contrainte d'unicité hors la clé primaire, aucun
-- trigger, aucune colonne dérivée. La denylist se réduit donc à l'identité
-- technique, la traçabilité — et aux DEUX NOMS. `preferred_name` et `sort_name`
-- sont exclus au nom de `DOC-CONV-1` : le point d'accès et la forme d'affichage
-- sont deux rendus d'une même autorité, et reprendre l'un sans l'autre les
-- désynchronise. Si la canonique manque de nom, on l'édite ; on n'hérite pas de
-- celui d'une autre.
--
-- CHECKLIST DOCTRINE :
--   [x] SET search_path = public, pg_catalog
--   [x] REVOKE EXECUTE ... FROM PUBLIC, anon
--   [x] GRANT EXECUTE ... TO authenticated
--   [x] Gardes internes (staff pour lire, arbitre pour fusionner)
--   [x] DO block de vérification
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. La liste des champs non reprenables (autorités)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_dedup_non_transferable_author_fields()
RETURNS text[]
LANGUAGE sql
IMMUTABLE
AS $function$
  SELECT ARRAY[
    'id', 'created_at', 'updated_at', 'created_by', 'updated_by',
    -- Les deux noms : cf. DOC-CONV-1. sort_name fait foi, preferred_name en
    -- dérive ; reprendre l'un sans l'autre casse la correspondance.
    'preferred_name', 'sort_name'
  ]::text[];
$function$;

REVOKE ALL ON FUNCTION public.fn_dedup_non_transferable_author_fields() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_dedup_non_transferable_author_fields() TO authenticated;

COMMENT ON FUNCTION public.fn_dedup_non_transferable_author_fields() IS
  'Colonnes de public.authors qu''une fusion ne peut pas reprendre du doublon vers la '
  'canonique : identité technique, traçabilité, et les deux formes du nom (DOC-CONV-1). '
  'Source unique, partagée par la base et l''interface. Paquet DOUBLONS P9.';

-- -------------------------------------------------------------------------
-- 2. L'aperçu : ce que la fusion d'autorités détruirait
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.preview_merge_author(
  p_canonical_id bigint,
  p_duplicate_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  k_techniques constant text[] := ARRAY['id', 'created_at', 'updated_at', 'created_by', 'updated_by'];
  v_c           jsonb;
  v_d           jsonb;
  v_perdues     jsonb;
  v_divergentes jsonb;
  v_oeuvres     integer;
  v_contribs    integer;
  v_traductions integer;
  v_alias       integer;
  v_works       integer;
  v_brouillons  integer;
  v_signalement integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid()
                   AND m.role = ANY (ARRAY['librarian','coordenador'])
                   AND m.status = 'active') THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;

  IF p_canonical_id IS NULL OR p_duplicate_id IS NULL OR p_canonical_id = p_duplicate_id THEN
    RAISE EXCEPTION 'Par de autoridades inválido.'
      USING ERRCODE = 'P0001', HINT = 'error.catalog.notDuplicate.invalidPair';
  END IF;

  SELECT to_jsonb(a) INTO v_c FROM public.authors a WHERE a.id = p_canonical_id;
  SELECT to_jsonb(a) INTO v_d FROM public.authors a WHERE a.id = p_duplicate_id;
  IF v_c IS NULL OR v_d IS NULL THEN
    RAISE EXCEPTION 'Autoridade inexistente.'
      USING ERRCODE = 'P0002', HINT = 'error.catalog.notDuplicate.invalidPair';
  END IF;

  -- Même tri que pour les documents : la perte sèche d'abord (la canonique n'a
  -- rien), la divergence ensuite (la version du doublon disparaît).
  SELECT
    coalesce(jsonb_agg(jsonb_build_object('champ', k, 'valeur', dv) ORDER BY k)
             FILTER (WHERE canonique_vide), '[]'::jsonb),
    coalesce(jsonb_agg(jsonb_build_object('champ', k,
                                          'valeur_perdue', dv,
                                          'valeur_conservee', cv) ORDER BY k)
             FILTER (WHERE NOT canonique_vide AND cv IS DISTINCT FROM dv), '[]'::jsonb)
  INTO v_perdues, v_divergentes
  FROM (
    SELECT e.key AS k, e.value AS dv, v_c -> e.key AS cv,
           (v_c -> e.key IS NULL
            OR v_c -> e.key IN ('null'::jsonb, '""'::jsonb, '[]'::jsonb, '{}'::jsonb)) AS canonique_vide
    FROM jsonb_each(v_d) e
    WHERE e.key <> ALL (k_techniques)
      AND e.value IS NOT NULL
      AND e.value NOT IN ('null'::jsonb, '""'::jsonb, '[]'::jsonb, '{}'::jsonb)
  ) t;

  -- Ce que la fusion repointe (le corps de merge_author touche ces sept tables).
  SELECT count(*) INTO v_oeuvres     FROM public.book_authors            WHERE author_id = p_duplicate_id;
  SELECT count(*) INTO v_contribs    FROM public.book_contributors       WHERE author_id = p_duplicate_id;
  SELECT count(*) INTO v_traductions FROM public.author_translations     WHERE author_id = p_duplicate_id;
  SELECT count(*) INTO v_alias       FROM public.author_name_aliases     WHERE author_id = p_duplicate_id;
  SELECT count(*) INTO v_works       FROM public.works                   WHERE primary_author_id = p_duplicate_id;
  SELECT count(*) INTO v_brouillons  FROM public.author_drafts           WHERE published_author_id = p_duplicate_id;
  SELECT count(*) INTO v_signalement FROM public.authority_duplicate_reports
   WHERE author_id_a = least(p_canonical_id, p_duplicate_id)
     AND author_id_b = greatest(p_canonical_id, p_duplicate_id);

  RETURN jsonb_build_object(
    'canonique', jsonb_build_object('id', p_canonical_id,
      'nom', v_c ->> 'preferred_name', 'tri', v_c ->> 'sort_name'),
    'doublon', jsonb_build_object('id', p_duplicate_id,
      'nom', v_d ->> 'preferred_name', 'tri', v_d ->> 'sort_name'),
    'metadonnees_perdues',     v_perdues,
    'metadonnees_divergentes', v_divergentes,
    'rattachements', jsonb_build_object(
      'oeuvres', v_oeuvres, 'contributions', v_contribs,
      'traductions', v_traductions, 'alias', v_alias,
      'works_principaux', v_works, 'brouillons', v_brouillons),
    'signalements', v_signalement
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.preview_merge_author(bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.preview_merge_author(bigint, bigint) TO authenticated;

COMMENT ON FUNCTION public.preview_merge_author(bigint, bigint) IS
  'Aperçu en lecture seule de ce qu''une fusion d''autorités détruirait : métadonnées '
  'perdues et divergentes (comparaison générique des colonnes), et ce qui sera repointé '
  '(œuvres, contributions, traductions, alias, brouillons). Staff de catalogage. '
  'Pendant de preview_merge_book. Paquet DOUBLONS P9 du 21/08/2026.';

-- -------------------------------------------------------------------------
-- 3. La fusion qui reprend d'abord, puis délègue
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.merge_author_with_fields(
  p_canonical_id bigint,
  p_duplicate_id bigint,
  p_fields       text[] DEFAULT '{}'::text[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  k_interdits text[] := public.fn_dedup_non_transferable_author_fields();
  v_champs    text[];
  v_inconnus  text[];
  v_refuses   text[];
  v_set       text;
BEGIN
  IF NOT public.fn_is_dedup_arbiter() THEN
    RAISE EXCEPTION 'Arbitragem reservada à coordenação.'
      USING ERRCODE = '42501', HINT = 'error.catalog.arbiter_only';
  END IF;

  IF p_canonical_id IS NULL OR p_duplicate_id IS NULL OR p_canonical_id = p_duplicate_id THEN
    RAISE EXCEPTION 'Par de autoridades inválido.'
      USING ERRCODE = 'P0001', HINT = 'error.catalog.notDuplicate.invalidPair';
  END IF;

  SELECT coalesce(array_agg(DISTINCT c), '{}'::text[]) INTO v_champs
  FROM unnest(coalesce(p_fields, '{}'::text[])) c
  WHERE nullif(btrim(c), '') IS NOT NULL;

  IF array_length(v_champs, 1) IS NOT NULL THEN
    SELECT coalesce(array_agg(c), '{}'::text[]) INTO v_inconnus
    FROM unnest(v_champs) c
    WHERE NOT EXISTS (
      SELECT 1 FROM information_schema.columns
       WHERE table_schema = 'public' AND table_name = 'authors' AND column_name = c
    );
    IF array_length(v_inconnus, 1) IS NOT NULL THEN
      RAISE EXCEPTION 'Champ(s) inconnu(s) dans authors : %.', array_to_string(v_inconnus, ', ')
        USING ERRCODE = 'P0001', HINT = 'error.catalog.merge.unknown_field';
    END IF;

    SELECT coalesce(array_agg(c), '{}'::text[]) INTO v_refuses
    FROM unnest(v_champs) c WHERE c = ANY (k_interdits);
    IF array_length(v_refuses, 1) IS NOT NULL THEN
      RAISE EXCEPTION 'Champ(s) non reprenable(s) : %.', array_to_string(v_refuses, ', ')
        USING ERRCODE = 'P0001', HINT = 'error.catalog.merge.field_not_transferable';
    END IF;

    SELECT string_agg(format('%I = d.%I', c, c), ', ') INTO v_set FROM unnest(v_champs) c;
    EXECUTE format(
      'UPDATE public.authors AS c SET %s FROM public.authors AS d WHERE c.id = $1 AND d.id = $2',
      v_set
    ) USING p_canonical_id, p_duplicate_id;
  END IF;

  -- Puis la fusion, inchangée. Une seule transaction : si merge_author refuse,
  -- la reprise est annulée avec elle.
  PERFORM public.merge_author(p_canonical_id, p_duplicate_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.merge_author_with_fields(bigint, bigint, text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.merge_author_with_fields(bigint, bigint, text[]) TO authenticated;

COMMENT ON FUNCTION public.merge_author_with_fields(bigint, bigint, text[]) IS
  'Fusionne deux autorités en reprenant d''abord, sur la canonique, les champs nommés — '
  'valeur prise sur l''autorité supprimée. Identité, traçabilité et les deux formes du nom '
  'sont refusées (erreur, jamais un silence). Délègue ensuite à merge_author, laissée '
  'intacte. Coordination uniquement. Paquet DOUBLONS P9 du 21/08/2026.';

-- -------------------------------------------------------------------------
-- 4. Vérification
-- -------------------------------------------------------------------------
DO $$
DECLARE v_n int;
BEGIN
  IF to_regprocedure('public.preview_merge_author(bigint,bigint)') IS NULL
     OR to_regprocedure('public.merge_author_with_fields(bigint,bigint,text[])') IS NULL
     OR to_regprocedure('public.fn_dedup_non_transferable_author_fields()') IS NULL THEN
    RAISE EXCEPTION 'Paquet DOUBLONS P9 : fonction manquante. Rollback.';
  END IF;

  IF to_regprocedure('public.merge_author(bigint,bigint)') IS NULL THEN
    RAISE EXCEPTION 'merge_author a disparu — la délégation est cassée. Rollback.';
  END IF;
  IF (SELECT pg_get_functiondef(to_regprocedure('public.merge_author_with_fields(bigint,bigint,text[])')::oid))
       NOT LIKE '%public.merge_author(p_canonical_id, p_duplicate_id)%' THEN
    RAISE EXCEPTION 'merge_author_with_fields ne délègue pas à merge_author. Rollback.';
  END IF;

  -- Les deux noms doivent rester hors de portée de la reprise (DOC-CONV-1).
  IF NOT ('sort_name' = ANY (public.fn_dedup_non_transferable_author_fields()))
     OR NOT ('preferred_name' = ANY (public.fn_dedup_non_transferable_author_fields())) THEN
    RAISE EXCEPTION 'Les formes du nom doivent rester non reprenables. Rollback.';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_proc pr JOIN pg_namespace ns ON ns.oid = pr.pronamespace
                 WHERE ns.nspname = 'public' AND pr.proname = 'preview_merge_author'
                   AND pr.provolatile = 's') THEN
    RAISE EXCEPTION 'preview_merge_author n''est pas STABLE. Rollback.';
  END IF;

  SELECT count(*) INTO v_n
  FROM pg_proc pr JOIN pg_namespace ns ON ns.oid = pr.pronamespace
  WHERE ns.nspname = 'public'
    AND pr.proname IN ('preview_merge_author', 'merge_author_with_fields',
                       'fn_dedup_non_transferable_author_fields')
    AND has_function_privilege('anon', pr.oid, 'EXECUTE');
  IF v_n > 0 THEN
    RAISE EXCEPTION 'Paquet DOUBLONS P9 : % fonction(s) exécutables par anon. Rollback.', v_n;
  END IF;

  RAISE NOTICE 'Paquet DOUBLONS P9 : vérifications OK.';
END $$;

COMMIT;

-- =========================================================================
-- Rollback ciblé :
--   BEGIN;
--     DROP FUNCTION IF EXISTS public.merge_author_with_fields(bigint, bigint, text[]);
--     DROP FUNCTION IF EXISTS public.preview_merge_author(bigint, bigint);
--     DROP FUNCTION IF EXISTS public.fn_dedup_non_transferable_author_fields();
--   COMMIT;
-- (merge_author n'a pas été touchée.)
-- =========================================================================
