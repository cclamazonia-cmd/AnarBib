-- =========================================================================
-- Paquet EX-1 — Socle DB : sélection/éligibilité de l'export de fonds numériques
-- =========================================================================
-- Date     : 2026-06-14 (UTC 20260614170000)
-- Chantier : Importacoes/Exportacoes — face Export, niveau 2 (bulk, remise d'un
--            lot de matériel gris numérisé à une companheira). Cf.
--            CADRAGE_export_fonds_numeriques_2026-06-12.
-- Auteur   : Claude (Opus 4.8) pour Xavier Van Welden
--
-- BESOIN
--   Remettre EN MASSE des documents numérisés (notices + fichiers) à une
--   companheira. EX-1 = la sélection : renvoie, pour une biblio, les notices
--   ÉLIGIBLES (au moins un digital_asset `public_domain_confirmed` — décision P3,
--   strict) + les métadonnées de leurs fichiers (pour le manifeste + l'empaquetage
--   ZIP de EX-2). Miroir lecture de fn_export_catalog_lote, filtré au libre-de-droits.
--   La sérialisation (notices via serialize.ts), l'empaquetage des fichiers et le
--   « run d'export » vivent dans l'EF/EX-2.
--
-- CONTENU : 2 RPC SECURITY DEFINER (gate coordenador de la biblio / admin réseau,
--   IMP-14) — fn_export_fonds_eligible_count + fn_export_fonds_records.
-- =========================================================================

BEGIN;

-- ─── Compte des notices éligibles (aperçu UI) ───────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_export_fonds_eligible_count(p_library_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
DECLARE v_authorized boolean; v_n integer;
BEGIN
  IF p_library_id IS NULL THEN RAISE EXCEPTION 'library_id obrigatorio.'; END IF;
  SELECT (
    EXISTS (SELECT 1 FROM public.user_library_memberships m
             WHERE m.user_id = auth.uid() AND m.library_id = p_library_id
               AND m.status = 'active' AND m.role = 'coordenador')
    OR public.fn_caller_is_network_admin()
  ) INTO v_authorized;
  IF NOT v_authorized THEN RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.'; END IF;

  SELECT count(DISTINCT b.id) INTO v_n
    FROM public.books b
   WHERE EXISTS (SELECT 1 FROM public.book_holdings h WHERE h.book_id = b.id AND h.library_id = p_library_id)
     AND EXISTS (SELECT 1 FROM public.digital_assets da
                  WHERE da.book_id = b.id AND da.rights_status = 'public_domain_confirmed');
  RETURN coalesce(v_n, 0);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_export_fonds_eligible_count(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_export_fonds_eligible_count(uuid) TO authenticated;

COMMENT ON FUNCTION public.fn_export_fonds_eligible_count(uuid) IS
  'Paquet EX-1. Nombre de notices d''une biblio éligibles à l''export de fonds (>=1 digital_asset '
  'public_domain_confirmed). Aperçu UI. Reservé coordenador (IMP-14) / admin réseau.';

-- ─── Notices éligibles + métadonnées des fichiers (pour ZIP + manifeste) ────
CREATE OR REPLACE FUNCTION public.fn_export_fonds_records(
  p_library_id uuid,
  p_book_ids   bigint[] DEFAULT NULL   -- sélection explicite ; NULL = tout l'éligible
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
DECLARE v_authorized boolean; v_records jsonb;
BEGIN
  IF p_library_id IS NULL THEN RAISE EXCEPTION 'library_id obrigatorio.'; END IF;

  -- IMP-14 : remise de fonds = acte de coordenador (ou admin réseau).
  SELECT (
    EXISTS (SELECT 1 FROM public.user_library_memberships m
             WHERE m.user_id = auth.uid() AND m.library_id = p_library_id
               AND m.status = 'active' AND m.role = 'coordenador')
    OR public.fn_caller_is_network_admin()
  ) INTO v_authorized;
  IF NOT v_authorized THEN RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.'; END IF;

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
            SELECT jsonb_agg(jsonb_build_object('name', a.preferred_name, 'role', ba.role, 'ord', ba.ord) ORDER BY ba.ord)
              FROM public.book_authors ba JOIN public.authors a ON a.id = ba.author_id
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
            CASE WHEN coalesce(b.subjects, b.assuntos) IS NULL OR btrim(coalesce(b.subjects, b.assuntos)) = ''
                 THEN '[]'::jsonb
                 ELSE to_jsonb(regexp_split_to_array(btrim(coalesce(b.subjects, b.assuntos)), '\s*[;,]\s*')) END,
          'collection',     b.colecao,
          'materialType',   b.tipo_material,
          'notes',          b.notas,
          -- Fichiers libres de droits rattachés (pour le manifeste + l'empaquetage EX-2).
          'assets', coalesce((
            SELECT jsonb_agg(jsonb_build_object(
                     'asset_id', da.id, 'kind', da.asset_kind, 'title', da.title,
                     'bucket', da.bucket_name, 'path', da.object_path, 'mime', da.mime_type,
                     'rights_status', da.rights_status, 'checksum_sha256', da.checksum_sha256,
                     'file_size_bytes', da.file_size_bytes, 'source_name', da.source_name,
                     'source_license_name', da.source_license_name, 'attribution_text', da.attribution_text)
                     ORDER BY da.id)
              FROM public.digital_assets da
             WHERE da.book_id = b.id AND da.rights_status = 'public_domain_confirmed'
          ), '[]'::jsonb)
        ) AS rec
        FROM public.books b
       WHERE EXISTS (SELECT 1 FROM public.book_holdings h WHERE h.book_id = b.id AND h.library_id = p_library_id)
         AND EXISTS (SELECT 1 FROM public.digital_assets da
                      WHERE da.book_id = b.id AND da.rights_status = 'public_domain_confirmed')
         AND (p_book_ids IS NULL OR b.id = ANY(p_book_ids))
    ) sub;

  RETURN jsonb_build_object('ok', true, 'library_id', p_library_id,
    'eligibility', 'public_domain_confirmed',
    'count', jsonb_array_length(v_records), 'records', v_records);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_export_fonds_records(uuid, bigint[]) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_export_fonds_records(uuid, bigint[]) TO authenticated;

COMMENT ON FUNCTION public.fn_export_fonds_records(uuid, bigint[]) IS
  'Paquet EX-1 (export de fonds, niveau 2). Renvoie les notices normalisées (forme serialize.ts) '
  'd''une biblio ayant au moins un fichier public_domain_confirmed (filtre P3, strict), + les '
  'métadonnées de ces fichiers (manifeste/empaquetage EX-2). Reservé coordenador (IMP-14) / admin '
  'réseau. p_book_ids non NULL => sélection explicite.';

-- ─── Vérification ───────────────────────────────────────────────────────────
DO $verify$
DECLARE v_fns int;
BEGIN
  SELECT count(*) INTO v_fns FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public' AND p.proname IN ('fn_export_fonds_eligible_count','fn_export_fonds_records');
  IF v_fns <> 2 THEN RAISE EXCEPTION 'verify: expected 2 fn_export_fonds_*, found %', v_fns; END IF;
  RAISE NOTICE 'paquet EX-1 OK : 2 RPC export de fonds.';
END;
$verify$;

COMMIT;

-- =========================================================================
-- Rollback ciblé :
--   DROP FUNCTION IF EXISTS public.fn_export_fonds_records(uuid, bigint[]);
--   DROP FUNCTION IF EXISTS public.fn_export_fonds_eligible_count(uuid);
-- =========================================================================
