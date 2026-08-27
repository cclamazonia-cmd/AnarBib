-- =========================================================================
-- Paquet candidat-institutionnel-ingerable — le bouton « Importer ce
-- candidat » de la recherche institutionnelle devient exécutable
-- =========================================================================
-- Date     : 2026-08-28
-- Chantier : importations — recherche institutionnelle (mode « Busca »)
-- Auteur   : coordination AnarBib
-- Voisin   : 20260828100000_source_depot_sans_partenaire.sql (même défaut,
--            même table, autre fonction — lire son en-tête)
--
-- POURQUOI
--   public.fn_import_ingest_candidate est la RPC derrière le bouton « Importer
--   ce candidat » du mode Busca (ImportacoesPage.handleIngestCandidate, et
--   l'étape 2 de ImportWizard). Les deux appellent SANS p_source_id, donc la
--   fonction passe toujours par sa branche de repli — celle qui n'a jamais pu
--   s'exécuter. Le bouton était mort pour TOUTE bibliothèque, sans exception.
--
--   Cinq fautes cumulées, toutes des écarts entre ce que la fonction écrit et
--   ce que les colonnes acceptent. Aucune n'était visible : une CHECK et un
--   NOT NULL ne se vérifient qu'à l'exécution, et ce chemin n'était jamais
--   emprunté. Vérifiées une à une en base le 27/08/2026, pas supposées :
--
--   1. ingest.partner_catalog_sources.relation_status est NOT NULL SANS
--      défaut ; l'INSERT de repli ne la fournissait pas.        -> 23502
--   2. source_kind = 'institutional_lookup' n'appartenait pas à
--      partner_catalog_sources_source_kind_check.               -> 23514
--      Corollaire : aucune ligne ne pouvant porter ce kind, le SELECT de repli
--      ne trouvait jamais rien et l'INSERT fautif était TOUJOURS atteint.
--   3. ingest.partner_catalog_import_runs.storage_path est NOT NULL SANS
--      défaut ; l'INSERT du run journalier ne la fournissait pas. -> 23502
--   4. detected_format = 'lookup' n'appartenait pas à
--      partner_catalog_import_runs_detected_format_check.        -> 23514
--   5. match_status = 'pre_matched' n'appartient pas à
--      partner_catalog_staging_rows_match_status_check.          -> 23514
--
--   Les fautes 3 à 5 n'étaient pas au cadrage : elles se sont vues en relisant
--   les TROIS tables écrites, pas la seule qui était signalée. Réparer les deux
--   premières aurait déplacé l'échec d'une instruction, pas rendu le bouton
--   utilisable.
--
-- LA DÉCISION DE VOCABULAIRE : ÉLARGIR, PAS DÉGUISER
--   Deux CHECK demandaient le même arbitrage — admettre le mot, ou le remplacer
--   par un mot déjà admis ('manual_upload' pour la source, 'json' pour le
--   format). On élargit, dans les deux cas, pour la même raison : ces colonnes
--   disent la PROVENANCE des notices. Une notice rapatriée en interrogeant un
--   catalogue institutionnel (Biblioteca Nacional, WorldCat) n'a été téléversée
--   par personne, et le fichier JSON qu'on prétendrait avoir reçu n'existe
--   nulle part. Écrire 'manual_upload' rendrait la source « Recherche
--   institutionnelle » indiscernable, dans la liste des Fontes, du dépôt d'une
--   bibliothèque companheira — avec un badge de relation, alors que personne
--   n'a rien accordé. Le front avait d'ailleurs DÉJÀ prévu de masquer ces
--   sources de la liste des compagnes : le filtre existait, il visait le
--   mauvais mot ('institutional' au lieu de 'institutional_lookup'). Corrigé
--   dans le même paquet, côté JS.
--
--   Élargir un vocabulaire n'est anodin que si personne n'aiguille dessus.
--   Vérifié : aucun consommateur ne branche sur source_kind (le front ne fait
--   que filtrer) ni sur detected_format (affiché tel quel dans une pastille) ;
--   l'EF de parsing ne voit que les runs dispatchés, et un run 'lookup' ne
--   l'est jamais.
--
--   NON FAIT ICI, DÉLIBÉRÉMENT : 'oai_pmh' est absent des DEUX vocabulaires
--   alors que fn_import_register_oai_source et fn_import_harvest_oai l'écrivent
--   — et la première pose en plus relation_status = 'active' (hors
--   vocabulaire), la seconde run_status = 'pending' (hors vocabulaire) et omet
--   elle aussi storage_path. Tout le chemin OAI-PMH est mort de la même mort.
--   L'élargir ici sans réparer ces fonctions ne ferait que déplacer leur échec
--   d'une ligne : c'est un paquet à part.
--
-- POURQUOI LE RAPPROCHEMENT EST AJOUTÉ (et pas seulement un mot corrigé)
--   Remplacer 'pre_matched' par 'unreviewed' suffit à faire passer l'INSERT,
--   mais la ligne serait alors dans un cul-de-sac :
--   ingest.fn_is_editorial_decision_compatible n'accepte 'accept_new' que pour
--   'new_record', et 'accept_duplicate' que pour les statuts de doublon — donc
--   une ligne 'unreviewed' ne peut recevoir AUCUNE décision éditoriale, et ne
--   deviendra jamais un brouillon. Le bouton aurait répondu « importé » en
--   laissant la notice inatteignable. On appelle donc, après l'INSERT, la
--   plomberie déjà en place : ingest.fn_match_partner_catalog_run, qui écrit le
--   vrai match_status et la confiance, rafraîchit les compteurs du run et le
--   repasse en 'ready_for_review'. C'est exactement l'enchaînement de l'EF
--   receive-fonds-bundle après ses insertions. Écrire 'new_record' en dur était
--   l'autre option : elle affirme sans vérifier qu'il n'y a pas de doublon, et
--   l'assistant promeut automatiquement les 'new_record' — c'est-à-dire qu'elle
--   aurait converti la garde anti-doublon de l'assistant en formalité.
--
--   Effet de bord assumé : fn_match_partner_catalog_run réécrit aussi la
--   colonne confidence, qui passe du score de PERTINENCE rendu par la recherche
--   institutionnelle au score de RAPPROCHEMENT avec le catalogue (0 quand la
--   notice est neuve). C'est la même convention que pour les lignes issues d'un
--   fichier, et la pastille de l'écran lit bien celle-là. Le score d'origine
--   n'est pas perdu : raw_payload conserve le candidat entier.
--
-- CHECKLIST DOCTRINE
--   [x] Corps de fonction EXTRAIT du baseline et modifié par ancrages vérifiés
--       (5 remplacements, 1 occurrence exacte chacun) — jamais retapé
--   [x] Fonction SECURITY DEFINER : search_path conservé (public, ingest, auth)
--   [x] REVOKE EXECUTE FROM PUBLIC + GRANT aux rôles ciblés rejoués
--   [x] Deux CHECK élargies ; aucune ligne existante invalidée (l'ancien
--       vocabulaire est un sous-ensemble strict du nouveau)
--   [x] Aucune table, vue ou policy créée ; RLS inchangée
--   [x] DO block de vérification STRUCTUREL (les migrations tournent AVANT le
--       seed en CI) ; le bout-en-bout fonctionnel vit dans
--       tests/sql/import_candidat_institutionnel_tests.sql
-- =========================================================================

begin;

-- ── 1. Les deux vocabulaires s'ouvrent aux mots que le code écrit ────────
alter table ingest.partner_catalog_sources
  drop constraint if exists partner_catalog_sources_source_kind_check;
alter table ingest.partner_catalog_sources
  add constraint partner_catalog_sources_source_kind_check
  check (source_kind = any (array[
    'manual_upload',
    'zotero_file_export',
    'zotero_api',
    'partner_deposit',
    -- Notice rapatriée en interrogeant un catalogue institutionnel
    -- (EF catalog_metadata_lookup). Personne ne l'a téléversée, personne n'a
    -- rien accordé : ce n'est ni un upload, ni un dépôt.
    'institutional_lookup'
  ]));

alter table ingest.partner_catalog_import_runs
  drop constraint if exists partner_catalog_import_runs_detected_format_check;
alter table ingest.partner_catalog_import_runs
  add constraint partner_catalog_import_runs_detected_format_check
  check (detected_format = any (array[
    'csv', 'tsv', 'xlsx', 'xls', 'ods', 'json', 'csl_json', 'ris',
    'bibtex', 'biblatex', 'mods', 'marcxml', 'xml', 'pdf', 'zip',
    -- Run sans fichier : les lignes y sont posées une par une par
    -- fn_import_ingest_candidate. 'json' mentirait sur un fichier inexistant ;
    -- 'unknown' dirait qu'on ignore d'où ça vient — on le sait très bien.
    'lookup',
    'unknown'
  ]));

comment on constraint partner_catalog_sources_source_kind_check
  on ingest.partner_catalog_sources is
  'Vocabulaire de provenance des sources. Elargi le 28/08/2026 a '
  '''institutional_lookup'' (paquet candidat-institutionnel-ingerable). '
  'ATTENTION : ''oai_pmh'', ecrit par fn_import_register_oai_source et par '
  'fn_import_harvest_oai, n''y figure toujours PAS — ces deux fonctions sont '
  'inexecutables et attendent leur propre paquet.';

-- ── 2. La fonction ───────────────────────────────────────────────────────
create or replace function public.fn_import_ingest_candidate(
  p_candidate jsonb,
  p_source_id bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'ingest', 'auth'
as $function$
DECLARE
  v_actor   public.my_access%rowtype;
  v_src_id  bigint;
  v_run_id  bigint;
  v_row_id  bigint;
  v_today   date := current_date;
  v_row_no  integer;
  v_match   text;
BEGIN
  -- ── 1. Contrôle d'accès ────────────────────────────────
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;
  IF v_actor.role IS DISTINCT FROM 'coordenador' AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.';
  END IF;

  -- ── 2. Résolution de la source ─────────────────────────
  IF p_source_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM ingest.partner_catalog_sources
      WHERE id = p_source_id AND library_id = v_actor.library_id
    ) THEN
      RAISE EXCEPTION 'Source % nao pertence a esta biblioteca', p_source_id;
    END IF;
    v_src_id := p_source_id;
  ELSE
    SELECT id INTO v_src_id
      FROM ingest.partner_catalog_sources
     WHERE library_id = v_actor.library_id
       AND source_kind = 'institutional_lookup'
     LIMIT 1;

    IF v_src_id IS NULL THEN
      -- relation_status est NOT NULL et SANS defaut : omise, cet INSERT
      -- levait 23502 a chaque appel. 'mapeada' est le statut le plus faible du
      -- vocabulaire (partner_catalog_sources_relation_status_check) : la source
      -- est reperee, on n'affirme aucune relation — il n'y a d'ailleurs
      -- personne en face, c'est un catalogue institutionnel consulte, pas une
      -- bibliotheque companheira. Meme choix que le paquet
      -- source-depot-sans-partenaire du 28/08/2026.
      INSERT INTO ingest.partner_catalog_sources
        (partner_name, library_id, relation_status, source_kind, import_enabled)
      VALUES
        ('Recherche institutionnelle', v_actor.library_id, 'mapeada',
         'institutional_lookup', true)
      RETURNING id INTO v_src_id;
    END IF;
  END IF;

  -- ── 3. Run journalier de type lookup ───────────────────
  SELECT id INTO v_run_id
    FROM ingest.partner_catalog_import_runs
   WHERE source_id   = v_src_id
     AND library_id  = v_actor.library_id
     AND detected_format = 'lookup'
     AND created_at::date = v_today
     AND run_status NOT IN ('drafts_created', 'failed')
   ORDER BY id DESC
   LIMIT 1;

  IF v_run_id IS NULL THEN
    -- storage_path est NOT NULL et SANS defaut : deuxieme 23502 de la
    -- fonction. Aucun fichier n'est depose ici (le candidat arrive d'une API),
    -- mais la colonne veut une adresse : on pose un chemin de CONVENTION,
    -- exactement comme fn_deposit_fonds_direct_prepare pose
    -- 'direct/<source>/<cible>' pour un run qu'aucun televersement n'alimente.
    -- Rien ne le lit : le run nait 'ready_for_review' et n'est jamais confie a
    -- l'EF de parsing (fn_import_dispatch n'est appele que juste apres un
    -- fn_import_create, jamais sur un run existant).
    INSERT INTO ingest.partner_catalog_import_runs
      (source_id, library_id, detected_format, run_status, storage_path,
       original_filename, requested_by, imported_rows)
    VALUES
      (v_src_id, v_actor.library_id, 'lookup', 'ready_for_review',
       'lookup/' || v_actor.library_id::text || '/' || v_today::text,
       'lookup-' || v_today::text, v_actor.user_id, 0)
    RETURNING id INTO v_run_id;
  END IF;

  -- ── 4. Insertion du candidat comme staging_row ─────────
  SELECT coalesce(max(row_no), 0) + 1 INTO v_row_no
    FROM ingest.partner_catalog_staging_rows
   WHERE run_id = v_run_id;

  INSERT INTO ingest.partner_catalog_staging_rows (
    run_id,
    row_no,
    external_key,
    item_type,
    title,
    subtitle,
    responsibility_statement,
    authors,
    publisher,
    place_of_publication,
    publication_year,
    edition_statement,
    language,
    isbn,
    issn,
    subjects,
    raw_payload,
    normalized_payload,
    parse_status,
    match_status,
    review_status,
    confidence
  ) VALUES (
    v_run_id,
    v_row_no,
    p_candidate->>'source_record_id',
    'lookup',
    p_candidate->>'title',
    p_candidate->>'subtitle',
    p_candidate->>'responsibility_statement',
    CASE WHEN p_candidate->'contributors' IS NOT NULL
         THEN p_candidate->'contributors'
         ELSE '[]'::jsonb END,
    p_candidate->>'publisher',
    p_candidate->>'place',
    p_candidate->>'year',
    p_candidate->>'edition',
    p_candidate->>'language',
    p_candidate->'isbn'->>0,
    p_candidate->'issn'->>0,
    CASE WHEN p_candidate->'subjects' IS NOT NULL
         THEN p_candidate->'subjects'
         ELSE '[]'::jsonb END,
    p_candidate,
    jsonb_build_object(
      'title',                    p_candidate->>'title',
      'subtitle',                 p_candidate->>'subtitle',
      'responsibility_statement', p_candidate->>'responsibility_statement',
      'authors',                  coalesce(p_candidate->'contributors', '[]'::jsonb),
      'publisher',                p_candidate->>'publisher',
      'place_of_publication',     p_candidate->>'place',
      'publication_year',         p_candidate->>'year',
      'isbn',                     p_candidate->'isbn'->>0,
      'issn',                     p_candidate->'issn'->>0,
      'subjects',                 coalesce(p_candidate->'subjects', '[]'::jsonb),
      'source',                   p_candidate->>'source',
      'source_url',               p_candidate->>'source_url',
      'raw_format',               p_candidate->>'raw_format',
      'parser_version',           'lookup_v1'
    ),
    'parsed',
    -- Le statut pre_matched, ecrit ici jusqu'au 28/08/2026, n'appartient pas a
    -- partner_catalog_staging_rows_match_status_check. (Cite sans guillemets :
    -- le controle de fin de migration cherche le LITTERAL dans le corps.)
    -- On pose l'etat neutre du
    -- vocabulaire ('unreviewed', qui est aussi le defaut de la colonne) et on
    -- laisse le moteur de rapprochement ecrire le vrai statut juste apres.
    'unreviewed',
    'pending',
    coalesce((p_candidate->>'confidence')::numeric, 0)
  ) RETURNING id INTO v_row_id;

  -- ── 5. Rapprochement, puis compteurs ─────────────────
  -- Laisser la ligne en 'unreviewed' serait un cul-de-sac :
  -- ingest.fn_is_editorial_decision_compatible n'accepte alors ni 'accept_new'
  -- ni 'accept_duplicate', donc la notice ne pourrait JAMAIS devenir un
  -- brouillon — le bouton repondrait OK et la file resterait bloquee.
  -- fn_match_partner_catalog_run rapproche la ligne du catalogue, ecrit son
  -- match_status et sa confiance, puis rafraichit les compteurs du run
  -- (imported_rows compris, d'ou la disparition du +1 manuel) et le repasse en
  -- 'ready_for_review'. C'est deja ce que fait l'EF receive-fonds-bundle apres
  -- avoir insere ses lignes : meme plomberie, meme ordre.
  PERFORM ingest.fn_match_partner_catalog_run(v_run_id, ARRAY[v_row_id]);

  SELECT match_status INTO v_match
    FROM ingest.partner_catalog_staging_rows
   WHERE id = v_row_id;

  RETURN jsonb_build_object(
    'ok',           true,
    'run_id',       v_run_id,
    'row_id',       v_row_id,
    'source_id',    v_src_id,
    'match_status', v_match,
    'source',       p_candidate->>'source'
  );
END;
$function$;

revoke execute on function public.fn_import_ingest_candidate(jsonb, bigint) from public;
grant  execute on function public.fn_import_ingest_candidate(jsonb, bigint) to authenticated, service_role;

comment on function public.fn_import_ingest_candidate(jsonb, bigint) is
  'Lot 2 — Insere un candidat catalog_metadata_lookup dans la file de revision '
  '(staging_row), puis le fait rapprocher du catalogue par '
  'ingest.fn_match_partner_catalog_run. Cree au besoin la source '
  'institutional_lookup de la bibliotheque et son run journalier. Paquet '
  'candidat-institutionnel-ingerable du 28/08/2026 : la fonction etait '
  'inexecutable depuis son ecriture (relation_status et storage_path omis, tous '
  'deux NOT NULL sans defaut ; source_kind, detected_format et match_status '
  'hors de leurs CHECK respectives). Ses deux appelants — ImportacoesPage et '
  'ImportWizard — ne passent jamais p_source_id : la branche de repli EST la '
  'branche.';

-- ── 3. Verification structurelle (aucune donnee requise) ─────────────────
do $$
DECLARE
  v_def text;
  v_con text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'fn_import_ingest_candidate';
  IF v_def IS NULL THEN
    RAISE EXCEPTION 'fn_import_ingest_candidate introuvable apres migration';
  END IF;

  -- Le mot qui la rendait inexecutable ne doit plus y etre.
  IF position('''pre_matched''' in v_def) > 0 THEN
    RAISE EXCEPTION 'match_status hors vocabulaire (pre_matched) encore ecrit';
  END IF;
  -- Les deux colonnes NOT NULL sans defaut doivent etre nommees dans les INSERT.
  IF position('relation_status' in v_def) = 0 THEN
    RAISE EXCEPTION 'relation_status toujours absent de l''INSERT de source';
  END IF;
  IF position('storage_path' in v_def) = 0 THEN
    RAISE EXCEPTION 'storage_path toujours absent de l''INSERT de run';
  END IF;
  -- Et le rapprochement doit etre appele, sinon la ligne reste un cul-de-sac.
  IF position('fn_match_partner_catalog_run' in v_def) = 0 THEN
    RAISE EXCEPTION 'le rapprochement n''est pas appele : la ligne resterait unreviewed';
  END IF;

  -- Les vocabulaires admettent bien les mots que la fonction ecrit...
  SELECT pg_get_constraintdef(c.oid) INTO v_con
    FROM pg_constraint c
   WHERE c.conname = 'partner_catalog_import_runs_detected_format_check';
  IF v_con IS NULL OR position('''lookup''' in v_con) = 0 THEN
    RAISE EXCEPTION 'detected_format_check n''admet pas lookup : %', coalesce(v_con, '<absente>');
  END IF;

  SELECT pg_get_constraintdef(c.oid) INTO v_con
    FROM pg_constraint c
   WHERE c.conname = 'partner_catalog_sources_source_kind_check';
  IF v_con IS NULL OR position('institutional_lookup' in v_con) = 0 THEN
    RAISE EXCEPTION 'source_kind_check n''admet pas institutional_lookup : %', coalesce(v_con, '<absente>');
  END IF;

  -- ...et l'elargissement ne doit RIEN avoir retire.
  IF position('manual_upload' in v_con) = 0
     OR position('zotero_file_export' in v_con) = 0
     OR position('zotero_api' in v_con) = 0
     OR position('partner_deposit' in v_con) = 0 THEN
    RAISE EXCEPTION 'l''elargissement a PERDU un mot du vocabulaire : %', v_con;
  END IF;

  RAISE NOTICE 'Paquet candidat-institutionnel-ingerable : verifications OK';
END $$;

commit;

-- =========================================================================
-- Rollback : il n'y en a pas d'utile. L'etat anterieur etait du code mort — y
-- revenir consisterait a remettre les cinq ecarts, c'est-a-dire a recasser le
-- bouton. Les deux CHECK elargies n'invalident aucune ligne existante ; les
-- restreindre en exigerait au contraire la suppression (sources et runs crees
-- depuis).
-- =========================================================================
