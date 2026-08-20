-- =========================================================================
-- Paquet DOUBLONS P6 — dire ce que la fusion va détruire, AVANT de la faire
-- =========================================================================
-- Date     : 2026-08-20
-- Chantier : catalogage / dédoublonnage (lot 3 du plan « Dédoublonner sans casser »)
-- Auteur   : Xavier (+ Claude)
-- Session  : Dédoublonnage & arbitrage
--
-- POURQUOI. `merge_book` refond les rattachements, déplace les exemplaires,
-- repointe la circulation, puis SUPPRIME la notice doublon — dont seules les
-- métadonnées de la survivante subsistent. L'interface n'a jamais montré ce que
-- cette opération fait : ni quelles métadonnées disparaissent, ni combien
-- d'exemplaires migrent, ni sous quels tombos. On demandait donc à la
-- coordination de confirmer une destruction dont personne ne lui disait le
-- contenu. C'est le trou du chantier, et c'est celui que cette fonction ferme.
--
-- Le relevé du 20/08 dit pourquoi ça compte : MORYON 2008 Terramar contre
-- MORIYON 1985 Cincel, deux paires sur cinq dans la bande la plus sûre n'étaient
-- pas des doublons mais deux éditions. Fusionner la mauvaise fait disparaître
-- une attribution bibliographique, sans retour.
--
-- DEUX LISTES, PAS UNE. La distinction est le cœur de l'aperçu :
--   * `metadonnees_perdues`   — le doublon porte une valeur, la canonique n'a
--     RIEN. Après fusion, l'information n'existe plus nulle part. C'est la
--     perte sèche, celle qu'il faut regarder avant de cliquer.
--   * `metadonnees_divergentes` — les deux portent une valeur, différente. On
--     garde celle de la canonique ; l'autre version disparaît. Moins grave,
--     mais c'est souvent là que se cache « ce ne sont pas les mêmes éditions ».
--
-- COMPARAISON GÉNÉRIQUE, jamais une liste de champs figée. `public.books` porte
-- plus de cent colonnes et en gagne à chaque type de matériel ; une énumération
-- écrite à la main serait fausse au premier ajout, et fausse SILENCIEUSEMENT —
-- un champ oublié, c'est une perte non annoncée. On compare donc les deux
-- lignes converties en jsonb, en excluant les seules colonnes techniques.
--
-- LECTURE SEULE, niveau staff. Cette fonction ne modifie rien : elle est
-- ouverte à tout le staff de catalogage, comme les détections. Lire ce qu'une
-- fusion coûterait n'a jamais rien cassé — et une bibliothécaire qui signale
-- gagne à savoir ce qu'elle signale.
--
-- CHECKLIST DOCTRINE (fonction SECURITY DEFINER) :
--   [x] SET search_path = public, pg_catalog
--   [x] REVOKE EXECUTE ... FROM PUBLIC, anon
--   [x] GRANT EXECUTE ... TO authenticated
--   [x] Garde staff interne
--   [x] DO block de vérification
-- =========================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.preview_merge_book(
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
  -- Colonnes techniques ou dérivées : leur disparition n'apprend rien à
  -- personne, et les afficher noierait les pertes réelles.
  k_techniques constant text[] := ARRAY[
    'id', 'created_at', 'updated_at', 'created_by', 'updated_by',
    'last_cataloged_at', 'available_count', 'loanable', 'marc_json',
    'work_id', 'expression_id'
  ];
  v_c            jsonb;
  v_d            jsonb;
  v_perdues      jsonb;
  v_divergentes  jsonb;
  v_exemplaires  jsonb;
  v_n_ex         integer;
  v_emprestimos  integer;
  v_reservas     integer;
  v_peb          integer;
  v_consultas    integer;
  v_numeriques   integer;
  v_souhaits     integer;
  v_brouillons   integer;
  v_signalements integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid()
                   AND m.role = ANY (ARRAY['librarian','coordenador'])
                   AND m.status = 'active') THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;

  IF p_canonical_id IS NULL OR p_duplicate_id IS NULL OR p_canonical_id = p_duplicate_id THEN
    RAISE EXCEPTION 'Par de documentos inválido.'
      USING ERRCODE = 'P0001', HINT = 'error.catalog.notDuplicate.invalidPair';
  END IF;

  SELECT to_jsonb(b) INTO v_c FROM public.books b WHERE b.id = p_canonical_id;
  SELECT to_jsonb(b) INTO v_d FROM public.books b WHERE b.id = p_duplicate_id;

  IF v_c IS NULL OR v_d IS NULL THEN
    RAISE EXCEPTION 'Documento inexistente.'
      USING ERRCODE = 'P0002', HINT = 'error.catalog.notDuplicate.invalidPair';
  END IF;

  -- ── Métadonnées : ce qui disparaît, et ce qui est simplement écrasé ──────
  SELECT
    coalesce(jsonb_agg(jsonb_build_object('champ', k, 'valeur', dv) ORDER BY k)
             FILTER (WHERE canonique_vide), '[]'::jsonb),
    coalesce(jsonb_agg(jsonb_build_object('champ', k,
                                          'valeur_perdue', dv,
                                          'valeur_conservee', cv) ORDER BY k)
             FILTER (WHERE NOT canonique_vide AND cv IS DISTINCT FROM dv), '[]'::jsonb)
  INTO v_perdues, v_divergentes
  FROM (
    SELECT e.key AS k,
           e.value AS dv,
           v_c -> e.key AS cv,
           (v_c -> e.key IS NULL
            OR v_c -> e.key IN ('null'::jsonb, '""'::jsonb, '[]'::jsonb, '{}'::jsonb)) AS canonique_vide
    FROM jsonb_each(v_d) e
    WHERE e.key <> ALL (k_techniques)
      AND e.value IS NOT NULL
      AND e.value NOT IN ('null'::jsonb, '""'::jsonb, '[]'::jsonb, '{}'::jsonb)
  ) t;

  -- ── Exemplaires : lesquels migrent, sous quel tombo, et comment ──────────
  -- « fusionne » : la canonique a déjà un rattachement dans cette bibliothèque,
  -- les exemplaires y basculent. « repointe » : le rattachement entier change
  -- de notice. Dans les deux cas l'exemplaire survit — c'est la notice qui meurt.
  SELECT
    coalesce(jsonb_agg(jsonb_build_object(
      'tombo',        coalesce(nullif(btrim(coalesce(x.tombo, '')), ''), x.bib_ref),
      'bibliotheque', coalesce(l.name, '—'),
      'action',       CASE WHEN EXISTS (SELECT 1 FROM public.book_holdings ch
                                         WHERE ch.book_id = p_canonical_id
                                           AND ch.library_id = h.library_id)
                           THEN 'fusionne' ELSE 'repointe' END
    ) ORDER BY coalesce(l.name, '—'), coalesce(x.tombo, x.bib_ref)), '[]'::jsonb),
    count(*)
  INTO v_exemplaires, v_n_ex
  FROM public.exemplares x
  JOIN public.book_holdings h ON h.id = x.holding_id
  LEFT JOIN public.libraries l ON l.id = h.library_id
  WHERE h.book_id = p_duplicate_id;

  -- ── Ce qui suit la notice : circulation, numérique, souhaits, brouillons ─
  SELECT count(*) INTO v_emprestimos  FROM public.emprestimo_itens_v2        WHERE book_id = p_duplicate_id;
  SELECT count(*) INTO v_reservas     FROM public.reserva_linhas_v2          WHERE book_id = p_duplicate_id;
  SELECT count(*) INTO v_peb          FROM public.interlibrary_loan_items_v2 WHERE book_id = p_duplicate_id;
  SELECT count(*) INTO v_consultas    FROM public.consulta_linhas_v2         WHERE book_id = p_duplicate_id;
  SELECT count(*) INTO v_numeriques   FROM public.digital_assets             WHERE book_id = p_duplicate_id;
  SELECT count(*) INTO v_souhaits     FROM public.user_wishlist              WHERE book_id = p_duplicate_id;
  SELECT count(*) INTO v_brouillons   FROM public.book_drafts                WHERE published_book_id = p_duplicate_id;
  -- Les signalements de la paire partent en cascade avec la notice supprimée.
  SELECT count(*) INTO v_signalements FROM public.catalog_duplicate_reports
   WHERE book_id_a = least(p_canonical_id, p_duplicate_id)
     AND book_id_b = greatest(p_canonical_id, p_duplicate_id);

  RETURN jsonb_build_object(
    'canonique', jsonb_build_object(
      'id', p_canonical_id, 'titulo', v_c ->> 'titulo', 'autor', v_c ->> 'autor',
      'ano', v_c ->> 'ano', 'editora', v_c ->> 'editora', 'ref', v_c ->> 'bib_ref'),
    'doublon', jsonb_build_object(
      'id', p_duplicate_id, 'titulo', v_d ->> 'titulo', 'autor', v_d ->> 'autor',
      'ano', v_d ->> 'ano', 'editora', v_d ->> 'editora', 'ref', v_d ->> 'bib_ref'),
    'metadonnees_perdues',     v_perdues,
    'metadonnees_divergentes', v_divergentes,
    'exemplaires',             v_exemplaires,
    'exemplaires_total',       v_n_ex,
    'circulation', jsonb_build_object(
      'emprestimos', v_emprestimos, 'reservas', v_reservas,
      'peb', v_peb, 'consultas', v_consultas),
    'ressources_numeriques', v_numeriques,
    'listes_souhaits',       v_souhaits,
    'brouillons',            v_brouillons,
    'signalements',          v_signalements
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.preview_merge_book(bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.preview_merge_book(bigint, bigint) TO authenticated;

COMMENT ON FUNCTION public.preview_merge_book(bigint, bigint) IS
  'Aperçu en LECTURE SEULE de ce qu''une fusion de notices détruirait : métadonnées '
  'perdues (la canonique n''a rien) et divergentes (la version du doublon disparaît), '
  'exemplaires qui migrent avec leur tombo, circulation, ressources numériques, '
  'souhaits et brouillons rattachés. Comparaison générique des colonnes, pour qu''un '
  'champ ajouté au catalogue ne soit jamais perdu en silence. Staff de catalogage. '
  'Paquet DOUBLONS P6 du 20/08/2026.';

-- -------------------------------------------------------------------------
-- Vérification (rollback automatique en cas d'échec)
-- -------------------------------------------------------------------------
DO $$
DECLARE
  v_n int;
BEGIN
  IF to_regprocedure('public.preview_merge_book(bigint,bigint)') IS NULL THEN
    RAISE EXCEPTION 'preview_merge_book absente. Rollback.';
  END IF;

  SELECT count(*) INTO v_n
  FROM pg_proc pr
  JOIN pg_namespace ns ON ns.oid = pr.pronamespace
  WHERE ns.nspname = 'public' AND pr.proname = 'preview_merge_book'
    AND has_function_privilege('anon', pr.oid, 'EXECUTE');
  IF v_n > 0 THEN
    RAISE EXCEPTION 'preview_merge_book exécutable par anon. Rollback.';
  END IF;

  -- Une fonction d'aperçu qui écrirait quoi que ce soit serait un piège :
  -- STABLE l'interdit au niveau du moteur, on vérifie que la promesse tient.
  IF NOT EXISTS (SELECT 1 FROM pg_proc pr
                 JOIN pg_namespace ns ON ns.oid = pr.pronamespace
                 WHERE ns.nspname = 'public' AND pr.proname = 'preview_merge_book'
                   AND pr.provolatile = 's') THEN
    RAISE EXCEPTION 'preview_merge_book n''est pas STABLE. Rollback.';
  END IF;

  RAISE NOTICE 'Paquet DOUBLONS P6 : vérifications OK.';
END $$;

COMMIT;

-- =========================================================================
-- Rollback ciblé :
--   BEGIN;
--     DROP FUNCTION IF EXISTS public.preview_merge_book(bigint, bigint);
--   COMMIT;
-- =========================================================================
