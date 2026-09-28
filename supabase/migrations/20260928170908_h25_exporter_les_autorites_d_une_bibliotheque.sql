-- =============================================================================
-- H25 — Exporter les autorités d'une bibliothèque (UNIMARC Autorités), pour que
-- les liens $3 de l'export bibliographique (H24) mènent quelque part
--
-- public.fn_export_authorities_lote(p_library_id) : les fiches d'autorité liées
-- aux notices que la bibliothèque détient — personnes, collectivités, congrès
-- (book_contributors.author_id) et sujets du thésaurus (book_subjects), avec
-- les ancêtres de ces sujets pour que les renvois génériques (550 $5 g)
-- mènent eux aussi quelque part. Même garde que fn_export_catalog_lote :
-- coordination de la bibliothèque, ou administration du réseau.
--
-- Revue contradictoire du 28/09 : une fiche d'autorité a UN type, le même dans
-- les deux exports (sinon une 71X $3 mène à une fiche de personne, et
-- l'inverse). private.fn_nature_autorite le dit : celui de la fiche, sinon la
-- nature que lui donnent le plus souvent ses responsabilités, sinon
-- « collective » si elle est « organizacao », sinon « person » (808 fiches sur
-- 1 509 ne sont pas typées en production, lu le 28/09).
-- fn_export_catalog_lote recréée depuis sa définition réelle (md5 880c5e0e…),
-- une expression changée.
-- =============================================================================

CREATE OR REPLACE FUNCTION private.fn_nature_autorite(p_author_id bigint)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  SELECT coalesce(
    (SELECT a.authority_type FROM public.authors a WHERE a.id = p_author_id),
    (SELECT bc.nature FROM public.book_contributors bc
      WHERE bc.author_id = p_author_id AND bc.nature IS NOT NULL
      GROUP BY bc.nature ORDER BY count(*) DESC, bc.nature LIMIT 1),
    CASE WHEN EXISTS (SELECT 1 FROM public.book_contributors bc
                       WHERE bc.author_id = p_author_id AND bc.role = 'organizacao')
         THEN 'collective' END,
    'person');
$function$;

REVOKE EXECUTE ON FUNCTION private.fn_nature_autorite(bigint) FROM PUBLIC, anon, authenticated;
COMMENT ON FUNCTION private.fn_nature_autorite(bigint) IS
  'H25 : le type d''une fiche d''autorite (person, collective, congress), le meme dans fn_export_catalog_lote et fn_export_authorities_lote.';

CREATE OR REPLACE FUNCTION public.fn_export_authorities_lote(p_library_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
DECLARE
  v_authorized boolean;
  v_library    jsonb;
  v_locale     text;
  v_auteurs    jsonb;
  v_sujets     jsonb;
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

  -- Personnes, collectivités, congrès liés aux notices détenues. Les formes
  -- rejetées : variant_forms est un tableau de {form, source} (fusions) ou un
  -- objet {langue: [formes]} (relevés Wikidata) — les deux donnent des formes.
  WITH livres AS (
    SELECT DISTINCT h.book_id FROM public.book_holdings h WHERE h.library_id = p_library_id
  ), ids AS (
    SELECT DISTINCT bc.author_id FROM public.book_contributors bc
      JOIN livres l ON l.book_id = bc.book_id
     WHERE bc.author_id IS NOT NULL
  )
  SELECT coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
           'id', a.id,
           'type', private.fn_nature_autorite(a.id),
           'preferredName', a.preferred_name,
           'sortName', a.sort_name,
           'birthYear', a.birth_year, 'deathYear', a.death_year,
           'activityPeriod', a.activity_period,
           'country', a.country, 'nameLang', a.name_lang,
           'variants', (
             SELECT jsonb_agg(DISTINCT v) FROM (
               SELECT btrim(e->>'form') AS v FROM jsonb_array_elements(
                 CASE WHEN jsonb_typeof(a.variant_forms) = 'array' THEN a.variant_forms ELSE '[]'::jsonb END) e
               UNION
               SELECT btrim(x) FROM jsonb_each(
                   CASE WHEN jsonb_typeof(a.variant_forms) = 'object' THEN a.variant_forms ELSE '{}'::jsonb END) o(k, val)
                 CROSS JOIN LATERAL jsonb_array_elements_text(CASE WHEN jsonb_typeof(o.val) = 'array' THEN o.val ELSE '[]'::jsonb END) x
             ) f
             WHERE nullif(v, '') IS NOT NULL
               AND v IS DISTINCT FROM a.preferred_name AND v IS DISTINCT FROM a.sort_name),
           'viaf', a.viaf_id, 'isni', a.isni, 'wikidata', a.wikidata_id,
           'idref', a.external_ids->>'idref', 'lccn', a.external_ids->>'lccn',
           'note', a.dates_note))
         ORDER BY a.id), '[]'::jsonb)
    INTO v_auteurs
    FROM public.authors a JOIN ids ON ids.author_id = a.id;

  -- Sujets du thésaurus liés aux notices détenues, et leurs ancêtres.
  WITH RECURSIVE livres AS (
    SELECT DISTINCT h.book_id FROM public.book_holdings h WHERE h.library_id = p_library_id
  ), directs AS (
    SELECT DISTINCT bs.subject_id FROM public.book_subjects bs JOIN livres l ON l.book_id = bs.book_id
  ), arbre AS (
    SELECT s.id, s.parent_id FROM public.subjects s JOIN directs d ON d.subject_id = s.id
    UNION
    SELECT p.id, p.parent_id FROM public.subjects p JOIN arbre a ON a.parent_id = p.id
  )
  SELECT coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
           'id', s.id,
           'slug', s.slug,
           'label', coalesce(s.label_i18n->>v_locale, s.label_i18n->>'pt-BR',
                             (SELECT v FROM jsonb_each_text(s.label_i18n) x(k, v) ORDER BY k LIMIT 1), s.slug),
           'alt', CASE WHEN jsonb_typeof(s.alt_i18n->v_locale) = 'array' AND s.alt_i18n->v_locale <> '[]'::jsonb
                       THEN s.alt_i18n->v_locale END,
           'broader', s.parent_id,
           'related', (SELECT jsonb_agg(DISTINCT r.autre ORDER BY r.autre) FROM (
                         SELECT sr.related_subject_id AS autre FROM public.subject_relations sr WHERE sr.subject_id = s.id
                         UNION
                         SELECT sr.subject_id FROM public.subject_relations sr WHERE sr.related_subject_id = s.id) r),
           'notation', s.notation,
           'scopeNote', s.scope_note))
         ORDER BY s.id), '[]'::jsonb)
    INTO v_sujets
    FROM public.subjects s
   WHERE s.id IN (SELECT id FROM arbre);

  RETURN jsonb_build_object(
    'ok', true,
    'library_id', p_library_id,
    'library', v_library,
    'authors', v_auteurs,
    'subjects', v_sujets
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_export_authorities_lote(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_export_authorities_lote(uuid) TO authenticated, service_role;
COMMENT ON FUNCTION public.fn_export_authorities_lote(uuid) IS
  'H25 (28/09/2026) : les autorites (personnes, collectivites, congres, sujets et leurs ancetres) liees aux '
  'notices qu''une bibliotheque detient, pour l''export UNIMARC Autorites ; coordination de la bibliotheque '
  'ou administration du reseau.';

CREATE OR REPLACE FUNCTION public.fn_export_catalog_lote(p_library_id uuid, p_apres bigint DEFAULT NULL::bigint, p_limite integer DEFAULT NULL::integer)
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
                     -- H25 : rattachée à une fiche, la nature est celle de la fiche — la
                     -- même que dans l'export des autorités, où ce $3 mène.
                     'nature', CASE WHEN bc.author_id IS NOT NULL THEN private.fn_nature_autorite(bc.author_id)
                                    ELSE coalesce(bc.nature, CASE WHEN bc.role = 'organizacao' THEN 'collective' END) END,
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
$function$
;
