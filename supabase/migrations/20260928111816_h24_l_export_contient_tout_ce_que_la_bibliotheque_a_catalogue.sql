-- =============================================================================
-- H24 — L'export d'une bibliothèque contient tout ce qu'elle a catalogué
-- (aller-retour PMB ; décidé le 28/09/2026 : réémettre prudemment, pour la seule
-- bibliothèque d'où vient la notice, les zones MARC d'origine que l'import ne
-- lit pas)
--
-- public.fn_export_catalog_lote, réécrite depuis sa définition de production
-- (md5 contrôlé) ; sa garde est inchangée (coordination de la bibliothèque, ou
-- administration du réseau). Avant : les notices détenues, leurs auteur·rices
-- par la seule table dérivée, sans rôle ; des sujets découpés dans un texte ;
-- aucun exemplaire. Désormais : identifiants d'origine (H20), responsabilités
-- (nature, rôle, code, autorité), sujets du thésaurus, exemplaires de la
-- bibliothèque, œuvre, périodique, article, et l'enregistrement MARC d'origine
-- pour la bibliothèque qui l'a importé.
-- =============================================================================

-- H26 : la signature gagne la page (p_apres, p_limite) ; l'ancienne part.
DROP FUNCTION IF EXISTS public.fn_export_catalog_lote(uuid);

CREATE FUNCTION public.fn_export_catalog_lote(p_library_id uuid, p_apres bigint DEFAULT NULL, p_limite integer DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
DECLARE
  v_authorized boolean;
  v_records    jsonb;
  v_library    jsonb;
  v_locale     text;
  v_total      bigint;
  v_page       integer;
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

  SELECT jsonb_build_object('id', l.id, 'slug', l.slug, 'name', l.name, 'short_name', l.short_name,
                            'country', l.country, 'default_locale', l.default_locale),
         coalesce(l.default_locale, 'pt-BR')
    INTO v_library, v_locale
    FROM public.libraries l WHERE l.id = p_library_id;

  -- H26 (28/09/2026) : par pages — p_apres, le dernier id reçu ; p_limite, au
  -- plus 5 000 notices. Sans p_limite : tout le catalogue d'un coup (l'EF, un
  -- petit catalogue). Mesuré en production le 28/09 : 306 ms pour les 2 167
  -- notices de la plus grosse bibliothèque ; le délai du rôle authenticated est
  -- de 8 s. L'écran lit par pages de 1 000 et assemble le fichier lui-même.
  v_page := CASE WHEN p_limite IS NULL THEN NULL ELSE greatest(1, least(p_limite, 5000)) END;
  IF p_apres IS NULL THEN
    SELECT count(DISTINCT h.book_id) INTO v_total FROM public.book_holdings h WHERE h.library_id = p_library_id;
  END IF;

  -- H24 (28/09/2026) : tout ce que la bibliothèque a catalogué, et d'elle
  -- seule — la forme que lit l'export (NoticeExport, _shared/marc/ecriture.ts) :
  --  * identifiants : l'identifiant d'origine qu'a SA source (H20), les autres
  --    de SA bibliothèque ; jamais ceux d'une autre bibliothèque ;
  --  * responsabilités depuis book_contributors (la vérité ; book_authors est
  --    dérivée) : nom, nature, rôle, code d'origine, autorité, dates de la fiche ;
  --  * sujets du thésaurus, libellés dans la langue de la bibliothèque ; le
  --    texte libre d'avant le thésaurus en mots-clés ;
  --  * exemplaires de CETTE bibliothèque seulement (détention et exemplaire) ;
  --  * œuvre, périodique, article, adresse, pages ;
  --  * l'enregistrement MARC d'origine, pour la seule bibliothèque dont
  --    l'import a créé la notice (réémission prudente des zones que l'import ne
  --    lit pas ; les exemplaires d'origine restent dehors).
  -- 'authors' (noms, rôle, rang) reste pour un export d'avant H24.
  SELECT coalesce(jsonb_agg(rec ORDER BY rec_id), '[]'::jsonb)
    INTO v_records
    FROM (
      SELECT
        b.id AS rec_id,
        jsonb_strip_nulls(jsonb_build_object(
          'id',             b.id,
          -- la référence de SA bibliothèque (une notice partagée porte celle d'une autre)
          'bibRef',         coalesce(nullif(btrim((SELECT h.local_bib_ref FROM public.book_holdings h
                                                   WHERE h.book_id = b.id AND h.library_id = p_library_id LIMIT 1)), ''),
                                     b.bib_ref),
          'originId', (
            SELECT e.value FROM public.book_external_ids e
             WHERE e.book_id = b.id AND e.library_id = p_library_id
             ORDER BY e.created_at, e.id LIMIT 1),
          'externalIds', (
            SELECT jsonb_agg(jsonb_build_object('scheme', e.scheme, 'value', e.value, 'label', s.partner_name)
                             ORDER BY e.created_at, e.id)
              FROM public.book_external_ids e
              LEFT JOIN ingest.partner_catalog_sources s ON s.id = e.source_id
             WHERE e.book_id = b.id AND e.library_id = p_library_id),
          'title',          b.titulo,
          'subtitle',       b.subtitulo,
          'responsibility', b.autor,
          'volume',         b.volume,
          'edition',        b.edicao,
          'place',          b.local_publicacao,
          'publisher',      b.editora,
          'year',           b.ano,
          'isbn',           b.isbn,
          'issn',           b.issn,
          'language',       b.idioma,
          'pages',          b.paginas,
          'articlePages',   b.artigo_pages,
          'cdd',            b.cdd,
          'collection',     b.colecao,
          'materialType',   b.tipo_material,
          'notes',          b.notas,
          'url',            b.digital_native_url,
          'keyTitle',       b.titulo_periodico,
          'host', CASE WHEN b.artigo_source IS NOT NULL OR b.artigo_volume IS NOT NULL
                       THEN jsonb_build_object('title', b.artigo_source, 'volume', b.artigo_volume) END,
          'issue', CASE
              WHEN b.artigo_issue IS NOT NULL OR (b.tipo_material = 'artigo' AND b.data_edicao IS NOT NULL)
                THEN jsonb_build_object('number', b.artigo_issue, 'date', b.data_edicao)
              -- le fascicule d'un périodique (l'import H17 écrit numero et data_edicao)
              WHEN b.tipo_material = 'periodico' AND (nullif(btrim(b.numero::text), '') IS NOT NULL OR b.data_edicao IS NOT NULL)
                THEN jsonb_build_object('number', nullif(btrim(b.numero::text), ''), 'date', b.data_edicao)
            END,
          'work', (SELECT jsonb_build_object('id', w.id, 'title', w.uniform_title)
                     FROM public.works w WHERE w.id = b.work_id),
          'serial', (SELECT jsonb_build_object('id', s.id, 'title', s.uniform_title, 'issn', s.issn)
                       FROM public.serials s WHERE s.id = b.serial_id),
          'contributors', (
            SELECT jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                     'name', bc.name,
                     'nature', coalesce(bc.nature, a.authority_type, CASE WHEN bc.role = 'organizacao' THEN 'collective' END),
                     'role', bc.role,
                     'roleCode', bc.role_code,
                     'primary', bc.is_primary,
                     'authorId', bc.author_id,
                     'dates', CASE WHEN a.birth_year IS NOT NULL OR a.death_year IS NOT NULL
                                   THEN coalesce(a.birth_year::text, '....') || '-' || coalesce(a.death_year::text, '....') END))
                   ORDER BY bc.position, bc.id)
              FROM public.book_contributors bc
              LEFT JOIN public.authors a ON a.id = bc.author_id
             WHERE bc.book_id = b.id),
          'authors', (
            SELECT jsonb_agg(jsonb_build_object('name', bc.name, 'role', bc.role, 'ord', bc.position)
                             ORDER BY bc.position, bc.id)
              FROM public.book_contributors bc WHERE bc.book_id = b.id),
          'subjects', (
            SELECT jsonb_agg(jsonb_build_object(
                     'id', s.id,
                     'label', coalesce(s.label_i18n->>v_locale, s.label_i18n->>'pt-BR',
                                       (SELECT v FROM jsonb_each_text(s.label_i18n) x(k, v) ORDER BY k LIMIT 1), s.slug))
                   ORDER BY bs.ord, s.id)
              FROM public.book_subjects bs
              JOIN public.subjects s ON s.id = bs.subject_id
             WHERE bs.book_id = b.id),
          'keywords', (
            SELECT jsonb_agg(u.k ORDER BY u.n)
              FROM (SELECT btrim(t.k) AS k, min(t.n) AS n
                      FROM unnest(regexp_split_to_array(concat_ws(' | ', b.subjects, b.assuntos), '\s*[|;]\s*')) WITH ORDINALITY AS t(k, n)
                     WHERE btrim(t.k) <> ''
                     GROUP BY btrim(t.k)) u),
          'items', (
            SELECT jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                     'id', e.id, 'tombo', e.tombo, 'code', e.source_item_code, 'callNumber', e.shelf_location,
                     'note', e.notes, 'circulationPolicy', e.circulation_policy, 'visibility', e.visibility))
                   ORDER BY e.tombo, e.id)
              FROM public.exemplares e
              JOIN public.book_holdings h ON h.id = e.holding_id
             WHERE h.book_id = b.id AND h.library_id = p_library_id AND e.library_id = p_library_id),
          'source', CASE
              WHEN jsonb_typeof(b.marc_json->'ingest'->'raw_payload'->'fields') = 'array'
               AND (b.marc_json->'ingest'->>'run_id') ~ '^[0-9]{1,18}$'
               -- la bibliothèque d'où vient la notice : celle que la promotion a
               -- tamponnée — la destination d'un dépôt compagnon ou d'un
               -- moissonnage, sinon celle du run (ou de sa source)
               AND EXISTS (
                     SELECT 1
                       FROM ingest.partner_catalog_sources s
                       LEFT JOIN ingest.partner_catalog_import_runs r
                              ON r.id = (b.marc_json->'ingest'->>'run_id')::bigint
                      WHERE s.id = coalesce(r.source_id,
                                            CASE WHEN (b.marc_json->'ingest'->>'source_id') ~ '^[0-9]{1,18}$'
                                                 THEN (b.marc_json->'ingest'->>'source_id')::bigint END)
                        AND CASE WHEN s.source_kind IN ('partner_deposit', 'oai_pmh') THEN s.destination_library_id
                                 ELSE coalesce(r.library_id, s.library_id) END = p_library_id)
              THEN jsonb_build_object(
                     'dialect', b.marc_json->'ingest'->'raw_payload'->>'marc_dialect',
                     'leader', b.marc_json->'ingest'->'raw_payload'->>'leader',
                     -- la zone d'exemplaire que l'import a lue (profil compris)
                     'itemTag', b.marc_json->'ingest'->'raw_payload'->>'item_tag',
                     'fields', (SELECT coalesce(jsonb_agg(f ORDER BY n), '[]'::jsonb)
                                  FROM jsonb_array_elements(b.marc_json->'ingest'->'raw_payload'->'fields') WITH ORDINALITY AS z(f, n)
                                 WHERE f->>'tag' NOT IN ('995', '996', '852')
                                   AND f->>'tag' IS DISTINCT FROM b.marc_json->'ingest'->'raw_payload'->>'item_tag'))
            END
        )) AS rec
        FROM public.books b
       WHERE EXISTS (
         SELECT 1 FROM public.book_holdings h
          WHERE h.book_id = b.id AND h.library_id = p_library_id
       )
         AND b.id > coalesce(p_apres, 0)
       ORDER BY b.id
       LIMIT v_page
    ) sub;

  RETURN jsonb_build_object(
    'ok',         true,
    'library_id', p_library_id,
    'library',    v_library,
    'count',      jsonb_array_length(v_records),
    -- H26 : le total (à la première page) et la suite (l'id après lequel
    -- reprendre, tant que la page est pleine).
    'total',      v_total,
    'next',       CASE WHEN v_page IS NOT NULL AND jsonb_array_length(v_records) = v_page
                       THEN (v_records->-1->>'id')::bigint END,
    'records',    v_records
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_export_catalog_lote(uuid, bigint, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_export_catalog_lote(uuid, bigint, integer) TO authenticated, service_role;
COMMENT ON FUNCTION public.fn_export_catalog_lote(uuid, bigint, integer) IS
  'H24/H26 (28/09/2026) : le catalogue d''une bibliotheque pour l''export (NoticeExport), par pages ; '
  'coordination de la bibliotheque ou administration du reseau.';
