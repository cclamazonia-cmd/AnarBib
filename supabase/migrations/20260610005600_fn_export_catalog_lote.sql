-- Migration : RPC fn_export_catalog_lote (Lot 5, IMP-13 — export de lote)
-- Auteur  : Claude Opus 4.8
-- Session : Lot 5 — Export de lote
-- Date    : 2026-06-10 (UTC)
--
-- Contrôle d'accès (IMP-14 : coordenador de la biblio, ou admin réseau) + requête
-- du catalogue scopé biblio (book_holdings) + auteur·rices ordonné·es, retournés
-- en JSON normalisé (forme attendue par serialize.ts de l'EF export-catalog-lote).
-- La sérialisation (CSV/MARCXML/JSON) et la livraison du fichier vivent dans l'EF.

CREATE OR REPLACE FUNCTION public.fn_export_catalog_lote(
  p_library_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  v_authorized boolean;
  v_records    jsonb;
BEGIN
  IF p_library_id IS NULL THEN
    RAISE EXCEPTION 'library_id obrigatorio.';
  END IF;

  -- IMP-14 : reservé au coordenador de la bibliothèque (ou à l'admin réseau).
  SELECT (
    EXISTS (
      SELECT 1 FROM public.user_library_memberships m
      WHERE m.user_id   = auth.uid()
        AND m.library_id = p_library_id
        AND m.status     = 'active'
        AND m.role       = 'coordenador'
    )
    OR public.fn_caller_is_network_admin()
  ) INTO v_authorized;

  IF NOT v_authorized THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.';
  END IF;

  -- Catalogue scopé biblio via book_holdings. Notices normalisées (forme
  -- serialize.ts) ; auteur·rices ordonné·es par book_authors.ord ; sujets
  -- éclatés en tableau depuis le champ texte (subjects sinon assuntos).
  SELECT coalesce(jsonb_agg(rec ORDER BY rec_id), '[]'::jsonb)
    INTO v_records
    FROM (
      SELECT
        b.id AS rec_id,
        jsonb_build_object(
          'id',             b.id,
          'bibRef',         b.bib_ref,
          'title',          b.titulo,
          'subtitle',       b.subtitulo,
          'authors', coalesce((
            SELECT jsonb_agg(
                     jsonb_build_object('name', a.preferred_name, 'role', ba.role, 'ord', ba.ord)
                     ORDER BY ba.ord
                   )
              FROM public.book_authors ba
              JOIN public.authors a ON a.id = ba.author_id
             WHERE ba.book_id = b.id
          ), '[]'::jsonb),
          'responsibility', b.autor,
          'publisher',      b.editora,
          'year',           b.ano,
          'place',          b.local_publicacao,
          'edition',        b.edicao,
          'isbn',           b.isbn,
          'issn',           b.issn,
          'language',       b.idioma,
          'pages',          b.paginas,
          'cdd',            b.cdd,
          'subjects',
            CASE
              WHEN coalesce(b.subjects, b.assuntos) IS NULL
                OR btrim(coalesce(b.subjects, b.assuntos)) = '' THEN '[]'::jsonb
              ELSE to_jsonb(regexp_split_to_array(btrim(coalesce(b.subjects, b.assuntos)), '\s*[;,]\s*'))
            END,
          'collection',     b.colecao,
          'materialType',   b.tipo_material,
          'notes',          b.notas
        ) AS rec
        FROM public.books b
       WHERE EXISTS (
         SELECT 1 FROM public.book_holdings h
          WHERE h.book_id = b.id AND h.library_id = p_library_id
       )
    ) sub;

  RETURN jsonb_build_object(
    'ok',         true,
    'library_id', p_library_id,
    'count',      jsonb_array_length(v_records),
    'records',    v_records
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_export_catalog_lote(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_export_catalog_lote(uuid) TO authenticated;

COMMENT ON FUNCTION public.fn_export_catalog_lote(uuid) IS
  'Lot 5 (IMP-13) — Export de lote : retourne le catalogue normalise (JSON) d''une '
  'bibliotheque. Reserve au coordenador de la biblio (IMP-14) ou admin reseau. '
  'La serialisation CSV/MARCXML/JSON + livraison fichier vivent dans l''EF '
  'export-catalog-lote.';
