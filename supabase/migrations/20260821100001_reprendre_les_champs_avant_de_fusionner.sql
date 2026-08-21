-- =========================================================================
-- Paquet DOUBLONS P7 — reprendre ce qui allait être perdu, avant de fusionner
-- =========================================================================
-- Date     : 2026-08-21
-- Chantier : catalogage / dédoublonnage
-- Auteur   : Xavier (+ Claude)
-- Session  : Dédoublonnage & arbitrage
--
-- POURQUOI. Le catalogage savait déjà faire ça — mais du mauvais côté.
-- `api.merge_book_drafts` et `api.merge_draft_into_book` prennent un `p_fields`
-- qui enrichit le survivant, et la modale de comparaison offre des cases à
-- cocher champ par champ. Autrement dit : le chemin RÉVERSIBLE (le brouillon
-- perdant part à la corbeille) sait récupérer les données, et le chemin
-- IRRÉVERSIBLE — `merge_book` sur deux notices publiées — ne le savait pas. Il
-- gardait la canonique telle quelle et jetait le reste. Exactement à l'envers.
--
-- Le calcul difficile était déjà fait : `preview_merge_book.metadonnees_perdues`
-- liste précisément les champs où la canonique est vide et où le doublon porte
-- une valeur. Écrite pour AVERTIR, cette liste devient ici la RÉPARATION.
--
-- POURQUOI UNE FONCTION SÉPARÉE, ET PAS UN ARGUMENT DE PLUS SUR merge_book.
-- Le corps de `merge_book` (holdings, circulation, numérique, souhaits,
-- brouillons, journal, recalcul) a déjà été recopié une fois, le 21/08, pour en
-- changer la garde. Le recopier encore pour un changement de signature serait le
-- meilleur moyen de l'abîmer sans s'en apercevoir. On prépare donc la canonique,
-- puis on DÉLÈGUE : `merge_book` reste intacte, ses appelants aussi, et le test
-- de fusion réelle du paquet P4 continue de la protéger telle quelle.
--
-- POURQUOI DES NOMS DE CHAMPS, ET PAS DES VALEURS. `p_fields` est un `text[]` de
-- noms de colonnes, pas un jsonb de valeurs : la valeur ne peut venir que de la
-- notice qu'on s'apprête à supprimer, c'est tout l'objet du geste. Accepter des
-- valeurs arbitraires ferait de cette fonction un point d'écriture générique sur
-- `books`, avec une garde pensée pour la fusion. On ferme la porte.
--
-- LA LISTE DES CHAMPS INTERDITS EST UNE DENYLIST, JAMAIS UNE ALLOWLIST. C'est la
-- leçon de `DEDUP-5` reprise à l'endroit : une liste positive écrite à la main
-- deviendrait fausse au premier champ ajouté au catalogue, et un champ oublié
-- serait une perte non annoncée. Toute colonne nouvelle est donc reprenable par
-- défaut ; seules sont exclues celles dont la reprise casserait quelque chose.
--
-- UN CHAMP REFUSÉ LÈVE UNE ERREUR, il n'est jamais ignoré en silence : ignorer
-- une demande de reprise, c'est perdre la donnée en faisant croire qu'on l'a
-- gardée — le pire des deux mondes.
--
-- CHECKLIST DOCTRINE :
--   [x] SET search_path = public, pg_catalog
--   [x] REVOKE EXECUTE ... FROM PUBLIC, anon
--   [x] GRANT EXECUTE ... TO authenticated
--   [x] Garde d'arbitrage (fn_is_dedup_arbiter), en plus de celle de merge_book
--   [x] DO block de vérification
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- La liste des champs non reprenables, en UN SEUL endroit
-- -------------------------------------------------------------------------
-- Elle est consultée par `merge_book_with_fields` ET par l'interface : un écran
-- qui proposerait une case que la base refuse serait un bouton qui échoue sous
-- les doigts — le défaut qu'on a déjà corrigé une fois aujourd'hui, ailleurs.
-- Une seule définition, donc, et pas deux listes qui divergent.
--
-- Pourquoi chacune est exclue :
--   id, bib_ref          : identité. `books_bib_ref_unique` est un index unique
--                          partiel — recopier la référence entrerait en
--                          collision avec elle-même.
--   created_*, updated_* : traçabilité de la fiche conservée, pas du doublon.
--   available_count,
--   loanable             : dérivés, recalculés par la fusion elle-même.
--   *library*            : la détention passe par les holdings, que merge_book
--                          refond déjà — la dupliquer ici la désynchroniserait.
--   work_id,
--   expression_id        : rattachements structurels. Regrouper deux notices en
--                          œuvre est un geste délibéré et séparé.
--   publisher_id         : dérivé de `editora` par trigger. Reprendre `editora`
--                          le resynchronise ; le forcer à la main le casse.
CREATE OR REPLACE FUNCTION public.fn_dedup_non_transferable_fields()
RETURNS text[]
LANGUAGE sql
IMMUTABLE
AS $function$
  SELECT ARRAY[
    'id', 'bib_ref',
    'created_at', 'updated_at', 'created_by', 'updated_by', 'last_cataloged_at',
    'available_count', 'loanable',
    'owner_library', 'holder_library', 'owner_library_id', 'holder_library_id',
    'work_id', 'expression_id', 'publisher_id'
  ]::text[];
$function$;

REVOKE ALL ON FUNCTION public.fn_dedup_non_transferable_fields() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_dedup_non_transferable_fields() TO authenticated;

COMMENT ON FUNCTION public.fn_dedup_non_transferable_fields() IS
  'Colonnes de public.books qu''une fusion ne peut pas reprendre du doublon vers la '
  'canonique : identité, traçabilité, dérivés, détention et rattachements structurels. '
  'Source unique, partagée par merge_book_with_fields et par l''interface — pour qu''un '
  'écran ne propose jamais une reprise que la base refusera. Paquet DOUBLONS P7.';

CREATE OR REPLACE FUNCTION public.merge_book_with_fields(
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
  k_interdits text[] := public.fn_dedup_non_transferable_fields();
  v_champs   text[];
  v_inconnus text[];
  v_refuses  text[];
  v_set      text;
BEGIN
  IF NOT public.fn_is_dedup_arbiter() THEN
    RAISE EXCEPTION 'Arbitragem reservada à coordenação.'
      USING ERRCODE = '42501', HINT = 'error.catalog.arbiter_only';
  END IF;

  IF p_canonical_id IS NULL OR p_duplicate_id IS NULL OR p_canonical_id = p_duplicate_id THEN
    RAISE EXCEPTION 'Par de documentos inválido.'
      USING ERRCODE = 'P0001', HINT = 'error.catalog.notDuplicate.invalidPair';
  END IF;

  -- Dédoublonnage et nettoyage de la demande.
  SELECT coalesce(array_agg(DISTINCT c), '{}'::text[]) INTO v_champs
  FROM unnest(coalesce(p_fields, '{}'::text[])) c
  WHERE nullif(btrim(c), '') IS NOT NULL;

  IF array_length(v_champs, 1) IS NOT NULL THEN
    -- Un champ inexistant est presque toujours une faute de frappe côté appelant.
    SELECT coalesce(array_agg(c), '{}'::text[]) INTO v_inconnus
    FROM unnest(v_champs) c
    WHERE NOT EXISTS (
      SELECT 1 FROM information_schema.columns
       WHERE table_schema = 'public' AND table_name = 'books' AND column_name = c
    );
    IF array_length(v_inconnus, 1) IS NOT NULL THEN
      RAISE EXCEPTION 'Champ(s) inconnu(s) dans books : %.', array_to_string(v_inconnus, ', ')
        USING ERRCODE = 'P0001', HINT = 'error.catalog.merge.unknown_field';
    END IF;

    SELECT coalesce(array_agg(c), '{}'::text[]) INTO v_refuses
    FROM unnest(v_champs) c WHERE c = ANY (k_interdits);
    IF array_length(v_refuses, 1) IS NOT NULL THEN
      RAISE EXCEPTION 'Champ(s) non reprenable(s) : %.', array_to_string(v_refuses, ', ')
        USING ERRCODE = 'P0001', HINT = 'error.catalog.merge.field_not_transferable';
    END IF;

    -- La reprise se fait par UPDATE, jamais par affectation brute : les triggers
    -- de `books` doivent se rejouer (editora resynchronise publisher_id, idioma
    -- resynchronise l'expression). C'est le seul moyen que la fiche conservée
    -- reste cohérente avec ses colonnes dérivées.
    SELECT string_agg(format('%I = d.%I', c, c), ', ') INTO v_set FROM unnest(v_champs) c;

    EXECUTE format(
      'UPDATE public.books AS c SET %s FROM public.books AS d WHERE c.id = $1 AND d.id = $2',
      v_set
    ) USING p_canonical_id, p_duplicate_id;
  END IF;

  -- Puis la fusion, inchangée. `merge_book` revérifie la garde et le
  -- rattachement : si elle refuse, l'UPDATE ci-dessus est annulé avec elle —
  -- une seule transaction, pas de canonique à moitié enrichie.
  PERFORM public.merge_book(p_canonical_id, p_duplicate_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.merge_book_with_fields(bigint, bigint, text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.merge_book_with_fields(bigint, bigint, text[]) TO authenticated;

COMMENT ON FUNCTION public.merge_book_with_fields(bigint, bigint, text[]) IS
  'Fusionne deux notices en reprenant d''abord, sur la canonique, les champs nommés dans '
  'p_fields — dont la valeur est prise sur la notice supprimée. Les champs d''identité, '
  'dérivés ou structurels sont refusés (erreur, jamais un silence). Délègue ensuite à '
  'merge_book, laissée intacte. Coordination uniquement. Paquet DOUBLONS P7 du 21/08/2026.';

-- -------------------------------------------------------------------------
-- Vérification (rollback automatique en cas d'échec)
-- -------------------------------------------------------------------------
DO $$
DECLARE
  v_n int;
BEGIN
  IF to_regprocedure('public.fn_dedup_non_transferable_fields()') IS NULL THEN
    RAISE EXCEPTION 'fn_dedup_non_transferable_fields absente. Rollback.';
  END IF;
  IF NOT ('bib_ref' = ANY (public.fn_dedup_non_transferable_fields())) THEN
    RAISE EXCEPTION 'bib_ref doit rester non reprenable (index unique). Rollback.';
  END IF;
  IF to_regprocedure('public.merge_book_with_fields(bigint,bigint,text[])') IS NULL THEN
    RAISE EXCEPTION 'merge_book_with_fields absente. Rollback.';
  END IF;

  -- merge_book doit rester intacte et appelée : c'est tout l'intérêt du montage.
  IF to_regprocedure('public.merge_book(bigint,bigint)') IS NULL THEN
    RAISE EXCEPTION 'merge_book(bigint,bigint) a disparu — la délégation est cassée. Rollback.';
  END IF;
  IF (SELECT pg_get_functiondef(to_regprocedure('public.merge_book_with_fields(bigint,bigint,text[])')::oid))
       NOT LIKE '%public.merge_book(p_canonical_id, p_duplicate_id)%' THEN
    RAISE EXCEPTION 'merge_book_with_fields ne délègue pas à merge_book. Rollback.';
  END IF;

  SELECT count(*) INTO v_n
  FROM pg_proc pr JOIN pg_namespace ns ON ns.oid = pr.pronamespace
  WHERE ns.nspname = 'public' AND pr.proname = 'merge_book_with_fields'
    AND has_function_privilege('anon', pr.oid, 'EXECUTE');
  IF v_n > 0 THEN
    RAISE EXCEPTION 'merge_book_with_fields exécutable par anon. Rollback.';
  END IF;

  RAISE NOTICE 'Paquet DOUBLONS P7 : vérifications OK.';
END $$;

COMMIT;

-- =========================================================================
-- Rollback ciblé :
--   BEGIN;
--     DROP FUNCTION IF EXISTS public.merge_book_with_fields(bigint, bigint, text[]);
--   COMMIT;
-- (merge_book n'a pas été touchée : rien d'autre à défaire.)
-- =========================================================================
