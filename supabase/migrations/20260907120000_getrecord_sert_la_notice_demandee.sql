-- =============================================================================
-- H8 — `GetRecord` sert la notice demandée, pas la première de la bibliothèque
-- Date : 2026-09-07 · Backlog v34 H8 · Nuance la clôture H5 du 02/09
-- -----------------------------------------------------------------------------
-- Le défaut. `fn_oai_harvestable_records(p_library_slug, p_from, p_until,
-- p_limit, p_offset, p_book_id)` appliquait `p_book_id` au COMPTAGE
-- (`v_total`) mais pas à la requête qui produit les notices : celle-ci ne
-- filtrait que sur la fenêtre de dates, puis `ORDER BY b.id LIMIT … OFFSET …`.
-- L'Edge Function `oai-pmh-provider` appelle `fetchRecords(slug, '', '', 1, 0,
-- bookId)` pour le verbe `GetRecord` : `LIMIT 1 OFFSET 0`, donc la notice de
-- plus petit `books.id` de la bibliothèque, quel que soit l'identifiant
-- demandé — et un identifiant inexistant recevait une notice au lieu de
-- `idDoesNotExist` (l'EF ne regarde que `records[0]`, pas `total`).
--
-- Vérifié le 07/09/2026 dans la migration 20260622120319 ET dans `pg_proc` en
-- production (deux occurrences de `p_book_id` dans le corps : la signature et
-- le comptage). La définition ci-dessous REPART de `pg_get_functiondef` lu en
-- production ce jour-là ; la seule différence est le prédicat ajouté à la
-- requête des notices. Signature, volatilité, `search_path`, grants : inchangés
-- (CREATE OR REPLACE conserve les privilèges ; la fonction figure à la liste
-- T10 de `grants_herites_tests`, qui n'a donc pas à bouger).
--
-- Sans effet sur les données : aucune bibliothèque n'est ouverte au
-- moissonnage au 07/09 (l'ouverture BLMF du 02/09 a été refermée 21 min plus
-- tard) et aucun moissonneur tiers n'existe. Le comportement fonctionnel est
-- gardé par `tests/sql/oai_getrecord_tests.sql` (au manifeste CI) ; ici, on ne
-- vérifie que la STRUCTURE (le prédicat est présent dans les deux requêtes).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_oai_harvestable_records(
  p_library_slug text,
  p_from timestamp with time zone DEFAULT NULL::timestamp with time zone,
  p_until timestamp with time zone DEFAULT NULL::timestamp with time zone,
  p_limit integer DEFAULT 100,
  p_offset integer DEFAULT 0,
  p_book_id bigint DEFAULT NULL::bigint
)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_lib     record;
  v_total   int;
  v_records jsonb;
  v_limit   int := least(greatest(coalesce(p_limit, 100), 1), 500);
  v_offset  int := greatest(coalesce(p_offset, 0), 0);
BEGIN
  SELECT l.id, l.slug INTO v_lib
    FROM public.libraries l
   WHERE l.slug = p_library_slug
     AND l.id IN (SELECT library_id FROM public.fn_oai_harvestable_libraries());

  IF v_lib.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_open', 'records', '[]'::jsonb, 'total', 0);
  END IF;

  SELECT count(*) INTO v_total
    FROM public.books b
   WHERE EXISTS (SELECT 1 FROM public.book_holdings h
                  WHERE h.book_id = b.id AND h.library_id = v_lib.id)
     AND (p_from  IS NULL OR coalesce(b.updated_at, b.created_at) >= p_from)
     AND (p_until IS NULL OR coalesce(b.updated_at, b.created_at) <= p_until)
     AND (p_book_id IS NULL OR b.id = p_book_id);

  SELECT coalesce(jsonb_agg(rec ORDER BY rec_id), '[]'::jsonb) INTO v_records
    FROM (
      SELECT
        b.id AS rec_id,
        jsonb_build_object(
          'identifier', 'oai:anarbib:' || v_lib.slug || ':' || b.id::text,
          'datestamp',  to_char(coalesce(b.updated_at, b.created_at) AT TIME ZONE 'UTC',
                                'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
          'id',             b.id,
          'bibRef',         b.bib_ref,
          'title',          b.titulo,
          'subtitle',       b.subtitulo,
          'authors', coalesce((
            SELECT jsonb_agg(jsonb_build_object('name', a.preferred_name, 'role', ba.role, 'ord', ba.ord)
                             ORDER BY ba.ord)
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
          'notes',          b.notas,
          -- P5 (#AUDIO-fonds) : MBID MusicBrainz associés (artistes + enregistrements).
          'musicbrainz', coalesce((
            SELECT jsonb_agg(DISTINCT u.mb)
              FROM (
                SELECT jsonb_build_object(
                         'type', 'artist',
                         'mbid', a.external_ids->>'musicbrainz',
                         'url',  'https://musicbrainz.org/artist/' || (a.external_ids->>'musicbrainz')
                       ) AS mb
                  FROM public.book_authors ba
                  JOIN public.authors a ON a.id = ba.author_id
                 WHERE ba.book_id = b.id
                   AND coalesce(a.external_ids->>'musicbrainz', '') <> ''
                UNION
                SELECT jsonb_build_object(
                         'type', 'recording',
                         'mbid', t.external_ids->>'musicbrainz',
                         'url',  'https://musicbrainz.org/recording/' || (t.external_ids->>'musicbrainz')
                       ) AS mb
                  FROM public.audio_tracks t
                 WHERE t.book_id = b.id
                   AND coalesce(t.external_ids->>'musicbrainz', '') <> ''
              ) u
          ), '[]'::jsonb)
        ) AS rec
        FROM public.books b
       WHERE EXISTS (SELECT 1 FROM public.book_holdings h
                      WHERE h.book_id = b.id AND h.library_id = v_lib.id)
         AND (p_from  IS NULL OR coalesce(b.updated_at, b.created_at) >= p_from)
         AND (p_until IS NULL OR coalesce(b.updated_at, b.created_at) <= p_until)
         -- H8 (07/09/2026) : le même prédicat que le comptage. Sans lui,
         -- GetRecord servait la première notice de la bibliothèque.
         AND (p_book_id IS NULL OR b.id = p_book_id)
       ORDER BY b.id
       LIMIT v_limit OFFSET v_offset
    ) sub;

  RETURN jsonb_build_object(
    'ok', true,
    'library_slug', v_lib.slug,
    'total', v_total,
    'count', jsonb_array_length(v_records),
    'limit', v_limit,
    'offset', v_offset,
    'records', v_records
  );
END;
$function$;

COMMENT ON FUNCTION public.fn_oai_harvestable_records(text, timestamptz, timestamptz, integer, integer, bigint) IS
  'Entrepôt OAI-PMH : notices moissonnables d''une bibliothèque ouverte (fenêtre de dates, pagination). p_book_id restreint À LA FOIS le comptage et les notices (H8, 07/09/2026) — c''est ce qui rend GetRecord exact.';

-- -----------------------------------------------------------------------------
-- Garde structurelle : le prédicat p_book_id figure dans les DEUX requêtes.
-- (Deux occurrences = signature + comptage, l'état d'avant ; il en faut trois.)
-- -----------------------------------------------------------------------------
DO $$
DECLARE
  v_n int;
BEGIN
  SELECT count(*) INTO v_n
    FROM regexp_matches(
      (SELECT prosrc FROM pg_proc
        WHERE oid = 'public.fn_oai_harvestable_records(text,timestamptz,timestamptz,integer,integer,bigint)'::regprocedure),
      'p_book_id IS NULL OR b\.id = p_book_id', 'g');
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'H8 : le prédicat p_book_id doit apparaître dans le comptage ET dans les notices (trouvé % fois, attendu 2)', v_n;
  END IF;
  RAISE NOTICE 'H8 OK : fn_oai_harvestable_records filtre les notices sur p_book_id.';
END $$;
