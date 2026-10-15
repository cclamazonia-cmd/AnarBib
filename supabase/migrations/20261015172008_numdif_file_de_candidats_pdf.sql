-- =========================================================================
-- Paquet NUMDIF-D13 — une file de candidats PDF par notice, que valide la
-- coordination de la bibliothèque détentrice
-- =========================================================================
-- Date     : 2026-10-15
-- Chantier : documents numériques — PDF déjà diffusés en ligne (REGISTRE §47)
-- Auteur   : Claude (assistant·e), pour la coordination
-- Session  : File de candidats PDF
-- Ref      : backlog v34 D13 ; REGISTRE §47 NUMDIF-1, NUMDIF-2, NUMDIF-5 ;
--            docs/journal/cadrages/CADRAGE_pdf-sous-droits-diffuses_2026-10-15.md §5
--
-- POURQUOI
--   Le 14/10, la recherche de PDF par édition exacte (Guérin, Grave, Reclus)
--   a vécu dans une session, et ses rejets avec elle. Rien ne garde la trace
--   d'un PDF trouvé ailleurs. `book_draft_digital_resources` ne convient pas :
--   il exige que le fichier soit déjà dans le stockage
--   (private.fn_objet_stocke_existe) et vit attaché à un brouillon de notice,
--   alors qu'un candidat existe AVANT tout fichier et SANS brouillon.
--
-- CE QUE FAIT LE PAQUET
--   1. ingest.digital_candidates : un candidat = (bibliothèque détentrice,
--      notice, URL du fichier). On y garde l'URL de la page qui présente le
--      fichier (NUMDIF-3), l'édition CONSTATÉE sur la page de titre du PDF
--      téléchargé (éditeur, lieu, année, traduction, ISBN — NUMDIF-1),
--      l'extrait de la page de titre, la proposition de l'outil (verdict et
--      cas de source), l'empreinte SHA-256 et la taille du fichier examiné,
--      puis la décision humaine : verdict, cas (NUMDIF-2), justification, la
--      mention citée avec sa page pour les cas publics, le motif d'un rejet,
--      qui a décidé et quand ; enfin le versement (D16) : la ressource créée,
--      qui l'a versée et quand, le dernier refus de versement.
--      Statuts : propose -> valide (« à verser ») -> verse ; propose | valide
--      -> rejete. Un rejet garde son motif ET l'édition trouvée : elle dit
--      qu'une autre édition existe et circule (utile aux acquisitions), et
--      évite de refaire la recherche.
--   2. Les cas de source. NUMDIF-2 en pose trois pour les œuvres sous droits :
--      diffusion_autorisee (a), anti_copyright (b) -> licenca_livre, public ;
--      statut_inconnu (c) -> sob_direitos, restreint. Un quatrième, hors
--      NUMDIF-2 qui ne traite que des œuvres sous droits, couvre le cas des
--      Reclus du 14/10 : domaine_public -> dominio_publico, public.
--      ingest.fn_numdif_destination(cas) dit le statut de droits, la portée,
--      le seau et le type de ressource — la seule table de correspondance,
--      que relira le versement (D16).
--   3. Trois portes (DEFINER, authenticated, DOC-RPC-3) :
--      - fn_digital_candidates_propose(bibliothèque, candidats) : l'outil de
--        recherche (D14) y écrit, par la main d'une coordination ; un
--        candidat déjà décidé n'est pas réécrit (« deja_traite ») ;
--      - fn_digital_candidates_list(...) : ce que lit l'écran de validation ;
--      - fn_digital_candidate_decide(...) : valider ou rejeter.
--      Portée de chacune : la coordination de LA bibliothèque du candidat, ou
--      l'administration du réseau ; la bibliothèque doit détenir la notice
--      (book_holdings) au moment du geste. Une coordination d'une autre
--      bibliothèque ne voit rien — même détentrice de la même notice :
--      c'est la bibliothèque qui verse qui porte la responsabilité (doctrine
--      du 20/08, NUMDIF-2), la file est la sienne.
--
-- CE QUE LE PAQUET NE FAIT PAS
--   - Il ne verse rien : c'est D16 (fonction Edge, côté serveur).
--   - Il ne lit aucune source : c'est D14 (script lancé à la main).
--
-- RÉGIME D'ACCÈS (« fermée par RLS »)
--   Celui du schéma `ingest` (paquet INGEST-RLS du 29/08/2026) : RLS activée
--   SANS politique, aucun droit pour anon ni authenticated, le schéma n'étant
--   pas exposé ; la portée (coordination de la détentrice, administration du
--   réseau) est tenue par les portes ci-dessus, qui s'exécutent avec les
--   droits du propriétaire des tables. Une politique ici ne protégerait rien
--   de plus et ferait échouer ingest_ferme_tests T7. Jamais de FORCE.
--
-- CHECKLIST DOCTRINE
--   [x] Table neuve : RLS + REVOKE/GRANT explicites + index sur chaque clé
--       étrangère (gardes fk_sans_index / grants_herites / ingest_ferme) ;
--       classée ingest.digital_candidates dans deploy/bg2-known-tables.txt
--   [x] Fonctions DEFINER : SET search_path ; REVOKE EXECUTE ... FROM PUBLIC,
--       anon (portes) ou FROM PUBLIC, anon, authenticated (aides) ;
--       GRANT ciblé
--   [x] DO block de vérification STRUCTUREL ; le fonctionnel vit dans
--       tests/sql/numdif_file_candidats_tests.sql
-- =========================================================================

BEGIN;

-- ── 1. La table ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ingest.digital_candidates (
  id                  bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  book_id             bigint NOT NULL REFERENCES public.books(id) ON DELETE CASCADE,
  library_id          uuid   NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,
  status              text   NOT NULL DEFAULT 'propose'
                      CONSTRAINT digital_candidates_status_check
                      CHECK (status IN ('propose', 'valide', 'rejete', 'verse')),

  -- la source : deux adresses (NUMDIF-3)
  file_url            text   NOT NULL
                      CONSTRAINT digital_candidates_file_url_check CHECK (file_url ~ '^https?://'),
  page_url            text
                      CONSTRAINT digital_candidates_page_url_check CHECK (page_url IS NULL OR page_url ~ '^https?://'),
  source_name         text,
  source_identifier   text,

  -- l'édition CONSTATÉE sur la page de titre du PDF téléchargé (NUMDIF-1)
  found_title         text,
  found_publisher     text,
  found_place         text,
  found_year          text,
  found_translator    text,
  found_isbn          text,
  found_language      text,
  title_page_text     text
                      CONSTRAINT digital_candidates_title_page_text_check
                      CHECK (title_page_text IS NULL OR length(title_page_text) <= 20000),
  title_page_number   integer,

  -- la proposition de l'outil (D14) — jamais la décision
  proposed_verdict    text
                      CONSTRAINT digital_candidates_proposed_verdict_check
                      CHECK (proposed_verdict IS NULL OR proposed_verdict IN ('meme_edition', 'autre_edition', 'texte_ressaisi')),
  proposed_case       text
                      CONSTRAINT digital_candidates_proposed_case_check
                      CHECK (proposed_case IS NULL OR proposed_case IN ('domaine_public', 'diffusion_autorisee', 'anti_copyright', 'statut_inconnu')),
  proposed_mention    text,
  proposed_mention_page text,
  tool_notes          jsonb  NOT NULL DEFAULT '{}'::jsonb,
  proposed_by         uuid,
  proposed_at         timestamptz NOT NULL DEFAULT now(),

  -- le fichier examiné
  sha256              text
                      CONSTRAINT digital_candidates_sha256_check CHECK (sha256 IS NULL OR sha256 ~ '^[0-9a-f]{64}$'),
  file_size_bytes     bigint
                      CONSTRAINT digital_candidates_file_size_check CHECK (file_size_bytes IS NULL OR file_size_bytes > 0),
  page_count          integer,
  original_filename   text,

  -- la décision de la coordination (NUMDIF-5)
  verdict             text
                      CONSTRAINT digital_candidates_verdict_check
                      CHECK (verdict IS NULL OR verdict IN ('meme_edition', 'autre_edition', 'texte_ressaisi')),
  source_case         text
                      CONSTRAINT digital_candidates_source_case_check
                      CHECK (source_case IS NULL OR source_case IN ('domaine_public', 'diffusion_autorisee', 'anti_copyright', 'statut_inconnu')),
  justification       text,
  rights_mention      text,
  rights_mention_page text,
  rejection_reason    text,
  decided_by          uuid,
  decided_at          timestamptz,

  -- le versement (D16)
  resource_id         bigint REFERENCES public.book_digital_resources(id) ON DELETE SET NULL,
  deposited_by        uuid,
  deposited_at        timestamptz,
  deposit_error       text,
  deposit_attempted_at timestamptz,

  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT digital_candidates_cle UNIQUE (library_id, book_id, file_url),
  -- décidé <=> une date de décision
  CONSTRAINT digital_candidates_decision_datee
    CHECK ((status = 'propose') = (decided_at IS NULL)),
  -- un rejet dit pourquoi
  CONSTRAINT digital_candidates_rejet_motive
    CHECK (status <> 'rejete' OR nullif(btrim(rejection_reason), '') IS NOT NULL),
  -- NUMDIF-1 : on ne valide que la même édition, avec un cas, une empreinte
  -- et une justification
  CONSTRAINT digital_candidates_meme_edition
    CHECK (status NOT IN ('valide', 'verse')
           OR (verdict = 'meme_edition' AND source_case IS NOT NULL AND sha256 IS NOT NULL
               AND nullif(btrim(justification), '') IS NOT NULL)),
  -- NUMDIF-2 (a)/(b) : la mention citée, avec sa page
  CONSTRAINT digital_candidates_mention_citee
    CHECK (status NOT IN ('valide', 'verse')
           OR source_case NOT IN ('diffusion_autorisee', 'anti_copyright')
           OR (nullif(btrim(rights_mention), '') IS NOT NULL AND nullif(btrim(rights_mention_page), '') IS NOT NULL)),
  -- versé <=> une date de versement
  CONSTRAINT digital_candidates_versement_date
    CHECK ((status = 'verse') = (deposited_at IS NOT NULL))
);

-- Index de chaque clé étrangère (garde « FK sans index ») ; la clé unique
-- couvre library_id en tête.
CREATE INDEX IF NOT EXISTS digital_candidates_book_idx     ON ingest.digital_candidates (book_id);
CREATE INDEX IF NOT EXISTS digital_candidates_resource_idx ON ingest.digital_candidates (resource_id);
CREATE INDEX IF NOT EXISTS digital_candidates_file_a_traiter_idx
  ON ingest.digital_candidates (library_id, status, proposed_at DESC);

COMMENT ON TABLE ingest.digital_candidates IS
  'NUMDIF-D13 (15/10/2026, REGISTRE §47 NUMDIF-1, 2, 5) : la file des PDF trouvés ailleurs pour une notice, '
  'une ligne par (bibliothèque détentrice, notice, URL du fichier). L''outil de recherche (D14) propose un verdict '
  'et un cas ; la coordination de la bibliothèque décide, PDF ouvert (D15) ; le versement se fait côté serveur (D16). '
  'propose -> valide -> verse ; propose | valide -> rejete (le rejet garde son motif et l''édition trouvée). '
  'Paquet INGEST-RLS (schéma fermé, 29/08/2026) : RLS sans politique, aucun droit pour anon ni authenticated — accès par '
  'les portes fn_digital_candidates_propose, fn_digital_candidates_list, fn_digital_candidate_decide (portée : coordination '
  'de la bibliothèque du candidat, détentrice de la notice, ou administration du réseau) ; service_role. '
  'Sauvegarde #BG2 : flux long (schéma ingest).';
COMMENT ON COLUMN ingest.digital_candidates.library_id IS
  'La bibliothèque détentrice dont la coordination décide et qui verse. Elle doit détenir la notice (book_holdings) à chaque geste.';
COMMENT ON COLUMN ingest.digital_candidates.file_url IS
  'L''URL du fichier : provenance, téléchargée par le versement (D16) ; jamais exposée pour une ressource restreinte (NUMDIF-3).';
COMMENT ON COLUMN ingest.digital_candidates.page_url IS
  'L''URL de la page qui présente le fichier (NUMDIF-3) : fiche Archive.org …/details/…, article, page du site.';
COMMENT ON COLUMN ingest.digital_candidates.sha256 IS
  'L''empreinte du fichier examiné (D14), figée à la validation : le versement (D16) refuse un fichier dont l''empreinte diffère.';
COMMENT ON COLUMN ingest.digital_candidates.proposed_case IS
  'Cas de source proposé. NUMDIF-2 : diffusion_autorisee (a), anti_copyright (b), statut_inconnu (c) ; domaine_public, '
  'hors NUMDIF-2 (qui ne traite que des œuvres sous droits). Correspondance : ingest.fn_numdif_destination.';

ALTER TABLE ingest.digital_candidates ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ingest.digital_candidates FROM PUBLIC, anon, authenticated;
GRANT ALL ON ingest.digital_candidates TO service_role;


-- ── 2. Les aides ───────────────────────────────────────────────────────

-- Le cas de source fixe le statut de droits, la portée, le seau et le type de
-- ressource (NUMDIF-2). Seule table de correspondance : le versement la relit.
CREATE OR REPLACE FUNCTION ingest.fn_numdif_destination(p_case text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT CASE p_case
    WHEN 'domaine_public'      THEN '{"rights_status": "dominio_publico", "access_scope": "publico", "storage_bucket": "anarbib-pdf-public", "resource_type": "pdf_publico"}'::jsonb
    WHEN 'diffusion_autorisee' THEN '{"rights_status": "licenca_livre", "access_scope": "publico", "storage_bucket": "anarbib-pdf-public", "resource_type": "pdf_publico"}'::jsonb
    WHEN 'anti_copyright'      THEN '{"rights_status": "licenca_livre", "access_scope": "publico", "storage_bucket": "anarbib-pdf-public", "resource_type": "pdf_publico"}'::jsonb
    WHEN 'statut_inconnu'      THEN '{"rights_status": "sob_direitos", "access_scope": "conta_ativa", "storage_bucket": "pdf-restrito", "resource_type": "pdf_restrito"}'::jsonb
  END;
$function$;
COMMENT ON FUNCTION ingest.fn_numdif_destination(text) IS
  'NUMDIF-D13 (15/10/2026, NUMDIF-2) : statut de droits, portée, seau et type de ressource d''un cas de source. NULL pour un cas inconnu. Interne.';

-- La portée d'un geste sur un candidat : coordination de la bibliothèque ou
-- administration du réseau, et la bibliothèque détient la notice.
CREATE OR REPLACE FUNCTION ingest.fn_numdif_peut_agir(p_library_id uuid, p_book_id bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
  SELECT auth.uid() IS NOT NULL
     AND (coalesce(public.fn_caller_is_network_admin(), false)
          OR p_library_id = ANY (coalesce(public.fn_caller_coordinator_library_ids(), '{}'::uuid[])))
     AND EXISTS (SELECT 1 FROM public.book_holdings h
                  WHERE h.book_id = p_book_id AND h.library_id = p_library_id);
$function$;
COMMENT ON FUNCTION ingest.fn_numdif_peut_agir(uuid, bigint) IS
  'NUMDIF-D13 (15/10/2026) : l''appelant·e coordonne cette bibliothèque (ou administre le réseau) ET la bibliothèque détient la notice. Interne aux portes de la file.';


-- ── 3. Proposer (l'outil D14, par la main d'une coordination) ──────────
CREATE OR REPLACE FUNCTION public.fn_digital_candidates_propose(p_library_id uuid, p_candidates jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_admin boolean := coalesce(public.fn_caller_is_network_admin(), false);
  v_coord uuid[] := coalesce(public.fn_caller_coordinator_library_ids(), '{}'::uuid[]);
  v_c jsonb;
  v_book bigint;
  v_url text;
  v_prev ingest.digital_candidates%rowtype;
  v_id bigint;
  v_raison text;
  v_created int := 0;
  v_refreshed int := 0;
  v_skipped jsonb := '{}'::jsonb;
  v_ids bigint[] := '{}'::bigint[];
  v_n int;
BEGIN
  IF v_uid IS NULL OR p_library_id IS NULL OR (NOT v_admin AND NOT (p_library_id = ANY (v_coord))) THEN
    RAISE EXCEPTION 'Acesso restrito a coordenacao da biblioteca detentora.'
      USING ERRCODE = '42501', HINT = 'error.digital_candidate.coord_only';
  END IF;
  IF p_candidates IS NULL OR jsonb_typeof(p_candidates) <> 'array' THEN
    RAISE EXCEPTION 'Os candidatos chegam numa lista.' USING ERRCODE = '22023', HINT = 'error.digital_candidate.bad_payload';
  END IF;
  v_n := jsonb_array_length(p_candidates);
  IF v_n > 200 THEN
    RAISE EXCEPTION 'No maximo 200 candidatos por chamada.' USING ERRCODE = '22023', HINT = 'error.digital_candidate.page_too_large';
  END IF;

  FOR v_c IN SELECT value FROM jsonb_array_elements(p_candidates) LOOP
    v_raison := NULL;
    v_id := NULL;
    BEGIN
      v_book := nullif(v_c->>'book_id', '')::bigint;
      v_url := nullif(btrim(v_c->>'file_url'), '');
      IF v_book IS NULL OR v_url IS NULL THEN
        v_raison := 'incomplet';
      ELSIF NOT EXISTS (SELECT 1 FROM public.book_holdings h WHERE h.book_id = v_book AND h.library_id = p_library_id) THEN
        v_raison := 'pas_detentrice';
      ELSE
        SELECT * INTO v_prev FROM ingest.digital_candidates
         WHERE library_id = p_library_id AND book_id = v_book AND file_url = v_url
         FOR UPDATE;
        IF FOUND AND v_prev.status <> 'propose' THEN
          -- décidé : la décision ne se réécrit pas, la recherche ne se refait pas
          v_raison := 'deja_traite';
        ELSIF FOUND THEN
          UPDATE ingest.digital_candidates SET
            page_url = nullif(btrim(v_c->>'page_url'), ''),
            source_name = nullif(btrim(v_c->>'source_name'), ''),
            source_identifier = nullif(btrim(v_c->>'source_identifier'), ''),
            found_title = nullif(btrim(v_c->>'found_title'), ''),
            found_publisher = nullif(btrim(v_c->>'found_publisher'), ''),
            found_place = nullif(btrim(v_c->>'found_place'), ''),
            found_year = nullif(btrim(v_c->>'found_year'), ''),
            found_translator = nullif(btrim(v_c->>'found_translator'), ''),
            found_isbn = nullif(btrim(v_c->>'found_isbn'), ''),
            found_language = nullif(btrim(v_c->>'found_language'), ''),
            title_page_text = left(nullif(v_c->>'title_page_text', ''), 20000),
            title_page_number = nullif(v_c->>'title_page_number', '')::integer,
            proposed_verdict = nullif(v_c->>'proposed_verdict', ''),
            proposed_case = nullif(v_c->>'proposed_case', ''),
            proposed_mention = nullif(btrim(v_c->>'proposed_mention'), ''),
            proposed_mention_page = nullif(btrim(v_c->>'proposed_mention_page'), ''),
            tool_notes = coalesce(CASE WHEN jsonb_typeof(v_c->'tool_notes') = 'object' THEN v_c->'tool_notes' END, '{}'::jsonb),
            sha256 = lower(nullif(btrim(v_c->>'sha256'), '')),
            file_size_bytes = nullif(v_c->>'file_size_bytes', '')::bigint,
            page_count = nullif(v_c->>'page_count', '')::integer,
            original_filename = nullif(btrim(v_c->>'original_filename'), ''),
            proposed_by = v_uid, proposed_at = now(), updated_at = now()
          WHERE id = v_prev.id
          RETURNING id INTO v_id;
          v_refreshed := v_refreshed + 1;
        ELSE
          INSERT INTO ingest.digital_candidates (
            book_id, library_id, file_url, page_url, source_name, source_identifier,
            found_title, found_publisher, found_place, found_year, found_translator, found_isbn, found_language,
            title_page_text, title_page_number, proposed_verdict, proposed_case, proposed_mention, proposed_mention_page,
            tool_notes, sha256, file_size_bytes, page_count, original_filename, proposed_by)
          VALUES (
            v_book, p_library_id, v_url, nullif(btrim(v_c->>'page_url'), ''),
            nullif(btrim(v_c->>'source_name'), ''), nullif(btrim(v_c->>'source_identifier'), ''),
            nullif(btrim(v_c->>'found_title'), ''), nullif(btrim(v_c->>'found_publisher'), ''),
            nullif(btrim(v_c->>'found_place'), ''), nullif(btrim(v_c->>'found_year'), ''),
            nullif(btrim(v_c->>'found_translator'), ''), nullif(btrim(v_c->>'found_isbn'), ''),
            nullif(btrim(v_c->>'found_language'), ''),
            left(nullif(v_c->>'title_page_text', ''), 20000), nullif(v_c->>'title_page_number', '')::integer,
            nullif(v_c->>'proposed_verdict', ''), nullif(v_c->>'proposed_case', ''),
            nullif(btrim(v_c->>'proposed_mention'), ''), nullif(btrim(v_c->>'proposed_mention_page'), ''),
            coalesce(CASE WHEN jsonb_typeof(v_c->'tool_notes') = 'object' THEN v_c->'tool_notes' END, '{}'::jsonb),
            lower(nullif(btrim(v_c->>'sha256'), '')), nullif(v_c->>'file_size_bytes', '')::bigint,
            nullif(v_c->>'page_count', '')::integer, nullif(btrim(v_c->>'original_filename'), ''), v_uid)
          RETURNING id INTO v_id;
          v_created := v_created + 1;
        END IF;
      END IF;
    EXCEPTION
      -- une valeur hors vocabulaire, une URL ou une empreinte mal formée :
      -- la ligne est ignorée avec sa raison, les autres passent
      WHEN check_violation OR invalid_text_representation OR numeric_value_out_of_range THEN
        v_raison := 'invalide';
        v_id := NULL;
    END;
    IF v_raison IS NOT NULL THEN
      v_skipped := v_skipped || jsonb_build_object(v_raison, coalesce((v_skipped->>v_raison)::int, 0) + 1);
    ELSIF v_id IS NOT NULL THEN
      v_ids := v_ids || v_id;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('asked', v_n, 'created', v_created, 'refreshed', v_refreshed,
                            'skipped_rows', v_n - v_created - v_refreshed,
                            'skipped', v_skipped, 'ids', to_jsonb(v_ids));
END;
$function$;
COMMENT ON FUNCTION public.fn_digital_candidates_propose(uuid, jsonb) IS
  'NUMDIF-D13 (15/10/2026) : pose ou rafraîchit des candidats PDF (200 au plus) pour une bibliothèque détentrice ; '
  'clé (bibliothèque, notice, URL du fichier). Un candidat déjà décidé n''est pas réécrit (skipped.deja_traite) ; '
  'notice non détenue (pas_detentrice), ligne incomplète ou hors vocabulaire (incomplet, invalide) : ignorées avec '
  'leur raison. Coordination de la bibliothèque, ou administration du réseau.';


-- ── 4. Lire (l'écran de validation D15) ────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_digital_candidates_list(p_library_id uuid DEFAULT NULL, p_status text DEFAULT NULL,
                                                            p_book_id bigint DEFAULT NULL, p_limit integer DEFAULT 50,
                                                            p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
DECLARE
  v_admin boolean := coalesce(public.fn_caller_is_network_admin(), false);
  v_coord uuid[] := coalesce(public.fn_caller_coordinator_library_ids(), '{}'::uuid[]);
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 200);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_res jsonb;
BEGIN
  -- Ni coordination ni administration : rien, sans erreur (comme
  -- fn_divergences_a_traiter) — l'écran se tait.
  IF auth.uid() IS NULL OR (NOT v_admin AND cardinality(v_coord) = 0)
     OR (p_library_id IS NOT NULL AND NOT v_admin AND NOT (p_library_id = ANY (v_coord))) THEN
    RETURN jsonb_build_object('total', 0, 'counts', '{}'::jsonb, 'candidates', '[]'::jsonb);
  END IF;

  WITH vis AS MATERIALIZED (
    SELECT c.*
      FROM ingest.digital_candidates c
     WHERE (v_admin OR c.library_id = ANY (v_coord))
       AND (p_library_id IS NULL OR c.library_id = p_library_id)
       AND (p_book_id IS NULL OR c.book_id = p_book_id)
  ), sel AS MATERIALIZED (
    SELECT v.* FROM vis v WHERE p_status IS NULL OR v.status = p_status
  ), page AS (
    SELECT s.* FROM sel s
     ORDER BY (s.status = 'propose') DESC, (s.status = 'valide') DESC, s.proposed_at DESC, s.id DESC
     LIMIT v_limit OFFSET v_offset
  )
  SELECT jsonb_build_object(
           'total', (SELECT count(*) FROM sel),
           'counts', coalesce((SELECT jsonb_object_agg(t.status, t.n)
                                 FROM (SELECT v.status, count(*) AS n FROM vis v GROUP BY v.status) t), '{}'::jsonb),
           'candidates', coalesce((
             SELECT jsonb_agg(
                      (to_jsonb(p) - 'proposed_by' - 'decided_by' - 'deposited_by')
                      || jsonb_build_object(
                           'library_name', l.name,
                           'decided_by_name', nullif(btrim(concat_ws(' ', pd.first_name, pd.last_name)), ''),
                           'holding', EXISTS (SELECT 1 FROM public.book_holdings h
                                               WHERE h.book_id = p.book_id AND h.library_id = p.library_id),
                           'destination', ingest.fn_numdif_destination(coalesce(p.source_case, p.proposed_case)),
                           'book', jsonb_build_object(
                             'id', b.id, 'titulo', b.titulo, 'subtitulo', b.subtitulo, 'autor', b.autor,
                             'editora', b.editora, 'local_publicacao', b.local_publicacao, 'ano', b.ano,
                             'edicao', b.edicao, 'tradutor', b.tradutor, 'isbn', b.isbn, 'idioma', b.idioma,
                             'paginas', b.paginas, 'bib_ref', b.bib_ref))
                      ORDER BY (p.status = 'propose') DESC, (p.status = 'valide') DESC, p.proposed_at DESC, p.id DESC)
               FROM page p
               JOIN public.books b ON b.id = p.book_id
               LEFT JOIN public.libraries l ON l.id = p.library_id
               LEFT JOIN public.profiles pd ON pd.id = p.decided_by), '[]'::jsonb))
    INTO v_res;
  RETURN v_res;
END;
$function$;
COMMENT ON FUNCTION public.fn_digital_candidates_list(uuid, text, bigint, integer, integer) IS
  'NUMDIF-D13 (15/10/2026) : les candidats PDF des bibliothèques que coordonne l''appelant·e (toutes pour l''administration '
  'du réseau), filtrables par bibliothèque, statut, notice ; avec la notice, la destination que fixe le cas, et si la '
  'bibliothèque détient encore la notice. Vide, sans erreur, pour qui n''est ni coordination ni administration.';


-- ── 5. Décider : valider ou rejeter (NUMDIF-1, NUMDIF-2, NUMDIF-5) ─────
CREATE OR REPLACE FUNCTION public.fn_digital_candidate_decide(
  p_id bigint,
  p_decision text,
  p_verdict text DEFAULT NULL,
  p_source_case text DEFAULT NULL,
  p_justification text DEFAULT NULL,
  p_rights_mention text DEFAULT NULL,
  p_rights_mention_page text DEFAULT NULL,
  p_page_url text DEFAULT NULL,
  p_rejection_reason text DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_c ingest.digital_candidates%rowtype;
  v_verdict text := nullif(btrim(p_verdict), '');
  v_case text := nullif(btrim(p_source_case), '');
  v_page text := nullif(btrim(p_page_url), '');
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Acesso restrito a coordenacao da biblioteca detentora.'
      USING ERRCODE = '42501', HINT = 'error.digital_candidate.coord_only';
  END IF;
  IF p_decision IS NULL OR p_decision NOT IN ('valider', 'rejeter') THEN
    RAISE EXCEPTION 'Decisao desconhecida : %.', p_decision USING ERRCODE = '22023', HINT = 'error.digital_candidate.bad_decision';
  END IF;

  SELECT * INTO v_c FROM ingest.digital_candidates WHERE id = p_id FOR UPDATE;
  -- hors de portée = introuvable : rien ne se dit d'un candidat d'une autre bibliothèque
  IF NOT FOUND OR NOT (coalesce(public.fn_caller_is_network_admin(), false)
                       OR v_c.library_id = ANY (coalesce(public.fn_caller_coordinator_library_ids(), '{}'::uuid[]))) THEN
    RAISE EXCEPTION 'Candidato nao encontrado.' USING ERRCODE = 'P0002', HINT = 'error.digital_candidate.not_found';
  END IF;
  IF NOT ingest.fn_numdif_peut_agir(v_c.library_id, v_c.book_id) THEN
    RAISE EXCEPTION 'A biblioteca nao detem mais esta ficha.' USING ERRCODE = '42501', HINT = 'error.digital_candidate.not_holding';
  END IF;
  IF v_page IS NOT NULL AND v_page !~ '^https?://' THEN
    RAISE EXCEPTION 'Endereco de pagina invalido.' USING ERRCODE = '22023', HINT = 'error.digital_candidate.bad_page_url';
  END IF;

  IF p_decision = 'valider' THEN
    IF v_c.status <> 'propose' THEN
      RAISE EXCEPTION 'Candidato ja decidido (%).', v_c.status USING ERRCODE = '55000', HINT = 'error.digital_candidate.already_decided';
    END IF;
    -- NUMDIF-1 : la même édition, et elle seule
    IF v_verdict IS DISTINCT FROM 'meme_edition' THEN
      RAISE EXCEPTION 'So se valida o arquivo da mesma edicao.' USING ERRCODE = '22023', HINT = 'error.digital_candidate.same_edition_only';
    END IF;
    IF v_case IS NULL OR ingest.fn_numdif_destination(v_case) IS NULL THEN
      RAISE EXCEPTION 'Caso de origem obrigatorio.' USING ERRCODE = '22023', HINT = 'error.digital_candidate.case_required';
    END IF;
    IF nullif(btrim(p_justification), '') IS NULL THEN
      RAISE EXCEPTION 'Justificativa obrigatoria.' USING ERRCODE = '22023', HINT = 'error.digital_candidate.justification_required';
    END IF;
    -- NUMDIF-2 (a)/(b) : la mention de l'édition, citée, avec sa page
    IF v_case IN ('diffusion_autorisee', 'anti_copyright')
       AND (nullif(btrim(p_rights_mention), '') IS NULL OR nullif(btrim(p_rights_mention_page), '') IS NULL) THEN
      RAISE EXCEPTION 'Licenca livre : citar a mencao e a sua pagina.' USING ERRCODE = '22023', HINT = 'error.digital_candidate.mention_required';
    END IF;
    -- D16 refusera un fichier dont l'empreinte diffère : sans empreinte, rien à garantir
    IF v_c.sha256 IS NULL THEN
      RAISE EXCEPTION 'Candidato sem impressao SHA-256.' USING ERRCODE = '22023', HINT = 'error.digital_candidate.no_fingerprint';
    END IF;

    UPDATE ingest.digital_candidates SET
      status = 'valide', verdict = v_verdict, source_case = v_case,
      justification = btrim(p_justification),
      rights_mention = nullif(btrim(p_rights_mention), ''),
      rights_mention_page = nullif(btrim(p_rights_mention_page), ''),
      page_url = coalesce(v_page, page_url),
      rejection_reason = NULL,
      decided_by = v_uid, decided_at = now(), updated_at = now()
    WHERE id = p_id;
  ELSE
    IF v_c.status NOT IN ('propose', 'valide') THEN
      RAISE EXCEPTION 'Candidato ja decidido (%).', v_c.status USING ERRCODE = '55000', HINT = 'error.digital_candidate.already_decided';
    END IF;
    IF nullif(btrim(p_rejection_reason), '') IS NULL THEN
      RAISE EXCEPTION 'Motivo de rejeicao obrigatorio.' USING ERRCODE = '22023', HINT = 'error.digital_candidate.reason_required';
    END IF;
    -- le rejet garde l'édition trouvée (found_*) et dit pourquoi
    UPDATE ingest.digital_candidates SET
      status = 'rejete',
      verdict = coalesce(v_verdict, verdict, proposed_verdict),
      source_case = coalesce(v_case, source_case),
      page_url = coalesce(v_page, page_url),
      rejection_reason = btrim(p_rejection_reason),
      decided_by = v_uid, decided_at = now(), updated_at = now()
    WHERE id = p_id;
  END IF;

  RETURN jsonb_build_object('id', p_id,
                            'status', (SELECT status FROM ingest.digital_candidates WHERE id = p_id));
END;
$function$;
COMMENT ON FUNCTION public.fn_digital_candidate_decide(bigint, text, text, text, text, text, text, text, text) IS
  'NUMDIF-D13 (15/10/2026) : la coordination de la bibliothèque du candidat (ou l''administration du réseau) valide '
  '(« à verser » : même édition seulement — NUMDIF-1 ; cas de source, justification, et pour les cas publics sous '
  'licence la mention citée avec sa page — NUMDIF-2 ; empreinte présente) ou rejette avec motif (un candidat proposé '
  'ou validé non versé). Lève avec une clé error.digital_candidate.* ; un candidat hors de portée est « introuvable ».';


-- ── 6. Droits ──────────────────────────────────────────────────────────
DO $numdif_d13_droits$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY['ingest.fn_numdif_destination(text)', 'ingest.fn_numdif_peut_agir(uuid, bigint)'] LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', f);
  END LOOP;
  FOREACH f IN ARRAY ARRAY[
    'public.fn_digital_candidates_propose(uuid, jsonb)',
    'public.fn_digital_candidates_list(uuid, text, bigint, integer, integer)',
    'public.fn_digital_candidate_decide(bigint, text, text, text, text, text, text, text, text)'] LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role', f);
  END LOOP;
END
$numdif_d13_droits$;
-- Lignes littérales pour la garde CI doctrine-migrations-garde (R2), qui
-- exige le texte « REVOKE EXECUTE … FROM PUBLIC » à côté de chaque DEFINER :
REVOKE EXECUTE ON FUNCTION ingest.fn_numdif_peut_agir(uuid, bigint) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_digital_candidates_propose(uuid, jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_digital_candidates_list(uuid, text, bigint, integer, integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_digital_candidate_decide(bigint, text, text, text, text, text, text, text, text) FROM PUBLIC, anon;


-- ── 7. Vérification structurelle ───────────────────────────────────────
DO $numdif_d13_verif$
DECLARE
  v_e text := '';
  v_f text;
BEGIN
  IF NOT (SELECT c.relrowsecurity AND NOT c.relforcerowsecurity FROM pg_class c
           WHERE c.oid = 'ingest.digital_candidates'::regclass)
     OR EXISTS (SELECT 1 FROM pg_policy p WHERE p.polrelid = 'ingest.digital_candidates'::regclass)
     OR has_table_privilege('authenticated', 'ingest.digital_candidates', 'SELECT')
     OR has_table_privilege('anon', 'ingest.digital_candidates', 'SELECT')
     OR has_table_privilege('authenticated', 'ingest.digital_candidates', 'INSERT')
     OR has_table_privilege('authenticated', 'ingest.digital_candidates', 'UPDATE')
     OR coalesce(obj_description('ingest.digital_candidates'::regclass, 'pg_class'), '') NOT LIKE '%INGEST-RLS%' THEN
    v_e := v_e || ' table';
  END IF;
  FOREACH v_f IN ARRAY ARRAY[
    'public.fn_digital_candidates_propose(uuid, jsonb)',
    'public.fn_digital_candidates_list(uuid, text, bigint, integer, integer)',
    'public.fn_digital_candidate_decide(bigint, text, text, text, text, text, text, text, text)'] LOOP
    IF NOT has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
       OR EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
                   WHERE p.oid = v_f::regprocedure AND a.grantee = 0)
       OR NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.oid = v_f::regprocedure AND p.prosecdef
                       AND coalesce(p.proconfig::text, '') LIKE '%search_path%') THEN
      v_e := v_e || ' porte(' || v_f || ')';
    END IF;
  END LOOP;
  FOREACH v_f IN ARRAY ARRAY['ingest.fn_numdif_destination(text)', 'ingest.fn_numdif_peut_agir(uuid, bigint)'] LOOP
    IF has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
       OR EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
                   WHERE p.oid = v_f::regprocedure AND a.grantee = 0) THEN
      v_e := v_e || ' aide(' || v_f || ')';
    END IF;
  END LOOP;
  IF ingest.fn_numdif_destination('statut_inconnu')->>'storage_bucket' IS DISTINCT FROM 'pdf-restrito'
     OR ingest.fn_numdif_destination('statut_inconnu')->>'access_scope' IS DISTINCT FROM 'conta_ativa' THEN
    v_e := v_e || ' destination';
  END IF;

  IF v_e <> '' THEN
    RAISE EXCEPTION 'NUMDIF-D13 : vérification en échec :%', v_e;
  END IF;
  RAISE NOTICE 'NUMDIF-D13 : vérifications OK';
END
$numdif_d13_verif$;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- =========================================================================
-- Rollback ciblé (la file est vide à la livraison) :
-- BEGIN;
--   DROP FUNCTION IF EXISTS public.fn_digital_candidate_decide(bigint, text, text, text, text, text, text, text, text);
--   DROP FUNCTION IF EXISTS public.fn_digital_candidates_list(uuid, text, bigint, integer, integer);
--   DROP FUNCTION IF EXISTS public.fn_digital_candidates_propose(uuid, jsonb);
--   DROP FUNCTION IF EXISTS ingest.fn_numdif_peut_agir(uuid, bigint);
--   DROP FUNCTION IF EXISTS ingest.fn_numdif_destination(text);
--   puis supprimer la table ingest.digital_candidates (écrit en clair à dessein : une
--   suppression de table dans ingest, même commentée, fait rougir bg2-ingest-flux-long).
-- COMMIT;
-- =========================================================================
