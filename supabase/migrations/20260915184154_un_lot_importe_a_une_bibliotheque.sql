-- =========================================================================
-- Paquet un-lot-importe-a-une-bibliotheque — la bibliotheque de destination
-- d'un lot importe se declare, se tamponne et se reattribue
-- =========================================================================
-- Date     : 2026-09-15
-- Chantier : importations — a qui appartient ce qu'on fait entrer
-- Auteur   : coordination AnarBib (demande Xavier du 15/09/2026)
--
-- POURQUOI
--   La chaine d'import connait une bibliotheque : partner_catalog_sources.
--   library_id, recopiee sur chaque run par fn_stamp_run_library_id. Mais cette
--   colonne veut dire « bibliotheque de la personne qui importe » et ne sert
--   qu'au controle d'acces des fn_import_*. Et la creation des brouillons
--   (ingest.fn_create_book_drafts_from_import_rows) ne posait JAMAIS
--   book_drafts.owner_library_id. Consequence : tout lot importe tombait dans
--   le repli de publish_book_draft — la biblio de qui publie. Pour un catalogue
--   propre, c'est juste par accident. Pour un depot de compagne, c'est faux a
--   chaque fois : l'admin qui importe n'est jamais la biblio qui detient les
--   livres. Vecu sur le lot Solidaires (source 17, run 29, lot 63) : 1673
--   brouillons sans proprietaire, alors que la bibliotheque existe depuis le
--   14/09 — et aucun geste dans l'app pour les y rattacher, sinon un UPDATE a
--   la main que chaque admin aurait a refaire a chaque admission.
--
-- CE QUE FAIT LE PAQUET
--   1. ingest.partner_catalog_sources.destination_library_id : la biblio qui
--      DETIENT les livres d'un depot de compagne (partner_deposit, oai_pmh).
--      Nulle tant que la compagne n'est pas admise. Distincte de library_id,
--      qui reste la biblio importatrice (controle d'acces inchange).
--   2. fn_import_promote tamponne owner_library_id (+ owner_library) sur les
--      brouillons qu'il vient de creer : la biblio du run pour un catalogue
--      propre (own_catalog, manual_upload, zotero_*, institutional_lookup),
--      la destination declaree pour un depot de compagne, rien si elle n'est
--      pas encore connue.
--   3. fn_import_register_deposit_source accepte une destination (optionnelle)
--      et l'ecrit ; fn_import_list_sources l'expose.
--   4. fn_batch_reassign_library(lot, biblio) — admin reseau : les brouillons
--      encore en cours (draft/ready) du lot recoivent la biblio ; les fiches
--      publiees et la corbeille ne bougent pas ; initial_copies_library_id est
--      remis a nul (sinon l'override admin l'emporterait sur la reattribution a
--      la publication) ; la source d'import compagne est alignee ; la trace
--      (qui, quand, d'ou, vers ou, combien) est ajoutee aux notes du lot.
--      Refus : lot ferme, biblio inconnue, revision deja APPROUVEE (le rapport
--      a ete rendu pour une autre biblio : refaire un tour). Avertissements
--      (pas des refus) : biblio sans serie de tombos, biblio inactive — la
--      reattribution et l'etat de preparation de la biblio sont deux
--      responsabilites ; la garde de publication tient la seconde.
--   5. fn_batch_owner_libraries() — staff : par lot non archive, les biblios
--      proprietaires des brouillons en cours et leurs effectifs, pour que
--      l'ecran montre « sans bibliotheque » AVANT la publication.
--
-- CE QUE LE PAQUET NE FAIT PAS
--   * Il ne touche pas publish_book_draft ni sa regle de repli.
--   * Il ne reattribue aucun lot existant : c'est le geste d'un admin, depuis
--     l'ecran (premier cas reel : le lot Solidaires).
--   * Il ne cree aucune table (rien a classer pour la sauvegarde).
--
-- CHECKLIST DOCTRINE
--   [x] fonctions SECURITY DEFINER : search_path pose, REVOKE PUBLIC/anon
--       (+ authenticated pour rien ici : toutes sont appelees par l'ecran)
--   [x] FK neuve → index (garde fk_sans_index_garde_tests)
--   [x] aucune fonction ouverte a anon (garde grants_herites T10 inchangee)
--   [x] DO block de verification en fin de transaction
--   [x] suite : tests/sql/lot_importe_bibliotheque_de_destination_tests.sql
--   [x] corps de fn_import_promote, fn_import_register_deposit_source et
--       fn_import_list_sources repris de pg_get_functiondef en prod (15/09)
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. La bibliotheque qui detient les livres d'une source compagne
-- -------------------------------------------------------------------------
ALTER TABLE ingest.partner_catalog_sources
  ADD COLUMN IF NOT EXISTS destination_library_id uuid
    REFERENCES public.libraries(id) ON DELETE SET NULL;

COMMENT ON COLUMN ingest.partner_catalog_sources.destination_library_id IS
  'Bibliotheque qui DETIENT les livres de cette source (depot de compagne, entrepot OAI). '
  'Nulle tant que la compagne n''est pas admise au reseau. Distincte de library_id = '
  'bibliotheque importatrice (controle d''acces). Tamponnee sur book_drafts.owner_library_id '
  'a la promotion (fn_import_promote) ; alignee par fn_batch_reassign_library. Paquet 15/09/2026.';

CREATE INDEX IF NOT EXISTS partner_catalog_sources_destination_library_idx
  ON ingest.partner_catalog_sources (destination_library_id);

-- -------------------------------------------------------------------------
-- 2. fn_import_register_deposit_source : la destination se declare a
--    l'enregistrement (optionnelle). La signature change (parametre ajoute) :
--    l'ancienne est supprimee, sinon PostgREST hesiterait entre deux candidates.
-- -------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.fn_import_register_deposit_source(text, text);

CREATE OR REPLACE FUNCTION public.fn_import_register_deposit_source(
  p_partner_name text,
  p_notes text DEFAULT NULL::text,
  p_destination_library_id uuid DEFAULT NULL::uuid
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'auth'
AS $function$
DECLARE
  v_actor     public.my_access%rowtype;
  v_source_id bigint;
  v_name      text;
BEGIN
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;
  -- 04/09/2026 : deposer le catalogue d'une bibliotheque compagne engage le
  -- reseau (cf. en-tete). La coordination garde fn_import_own_source.
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Deposito de catalogo companheiro reservado a administracao da rede.'
      USING HINT = 'error.import.deposit_admin_only';
  END IF;

  v_name := nullif(trim(p_partner_name), '');
  IF v_name IS NULL THEN
    RAISE EXCEPTION 'Nome do parceiro obrigatorio.';
  END IF;

  -- 15/09/2026 : la destination, si elle est donnee, doit exister.
  IF p_destination_library_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.libraries l WHERE l.id = p_destination_library_id) THEN
    RAISE EXCEPTION 'Biblioteca de destino % introuvable', p_destination_library_id
      USING HINT = 'error.import.destination_not_found';
  END IF;

  SELECT id INTO v_source_id
    FROM ingest.partner_catalog_sources
   WHERE library_id  = v_actor.library_id
     AND source_kind = 'partner_deposit'
     AND partner_name = v_name
   LIMIT 1;

  IF v_source_id IS NOT NULL THEN
    -- Source deja connue : une destination donnee maintenant la met a jour
    -- (c'est le cas « la compagne vient d'etre admise »).
    IF p_destination_library_id IS NOT NULL THEN
      UPDATE ingest.partner_catalog_sources
         SET destination_library_id = p_destination_library_id, updated_at = now()
       WHERE id = v_source_id;
    END IF;
    RETURN jsonb_build_object(
      'ok', true, 'source_id', v_source_id, 'created', false
    );
  END IF;

  -- 'mapeada' : statut le plus faible du vocabulaire (cf. 20260828100000).
  INSERT INTO ingest.partner_catalog_sources
    (partner_name, library_id, relation_status, source_kind,
     import_enabled, notes, destination_library_id)
  VALUES
    (v_name, v_actor.library_id, 'mapeada', 'partner_deposit',
     true, nullif(trim(p_notes), ''), p_destination_library_id)
  RETURNING id INTO v_source_id;

  RETURN jsonb_build_object(
    'ok', true, 'source_id', v_source_id, 'created', true
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_import_register_deposit_source(text, text, uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_import_register_deposit_source(text, text, uuid) TO authenticated, service_role;

COMMENT ON FUNCTION public.fn_import_register_deposit_source(text, text, uuid) IS
  'Enregistre (ou retrouve) une source de depot compagne pour la biblio de l''appelant·e — admin reseau. '
  'p_destination_library_id (optionnel, 15/09/2026) : la biblio qui detient les livres ; sur une source '
  'deja connue, la met a jour.';

-- -------------------------------------------------------------------------
-- 3. fn_import_list_sources expose la destination (colonnes ajoutees en fin :
--    le type de retour change, donc DROP puis CREATE).
-- -------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.fn_import_list_sources();

CREATE OR REPLACE FUNCTION public.fn_import_list_sources()
 RETURNS TABLE(id bigint, partner_name text, library_id uuid, relation_status text, source_kind text,
               import_enabled boolean, notes text, meta jsonb,
               created_at timestamp with time zone, updated_at timestamp with time zone,
               destination_library_id uuid, destination_library_name text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'auth'
AS $function$
DECLARE
  v_actor public.my_access%rowtype;
BEGIN
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;
  IF v_actor.role IS DISTINCT FROM 'coordenador' AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.';
  END IF;

  RETURN QUERY
  SELECT s.id, s.partner_name, s.library_id, s.relation_status,
         s.source_kind, s.import_enabled, s.notes, s.meta,
         s.created_at, s.updated_at,
         s.destination_library_id, l.name
  FROM ingest.partner_catalog_sources s
  LEFT JOIN public.libraries l ON l.id = s.destination_library_id
  WHERE s.library_id = v_actor.library_id
  ORDER BY s.created_at DESC;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_import_list_sources() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_import_list_sources() TO authenticated, service_role;

-- -------------------------------------------------------------------------
-- 4. fn_import_promote tamponne la biblio proprietaire des brouillons crees.
--    Corps repris de la prod (04/09/2026, garde deposit_admin_only) ; un seul
--    bloc ajoute apres la creation.
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_import_promote(
  p_run_id bigint,
  p_match_statuses text[] DEFAULT NULL::text[],
  p_editorial_decisions text[] DEFAULT ARRAY['accept_new'::text, 'accept_duplicate'::text],
  p_batch_name text DEFAULT NULL::text,
  p_batch_notes text DEFAULT NULL::text
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'auth'
AS $function$
DECLARE
  v_actor public.my_access%rowtype;
  v_run_library_id uuid;
  v_source_kind text;
  v_destination uuid;
  v_owner uuid;
  v_result jsonb;
  v_batch_id bigint;
  v_stamped integer := 0;
BEGIN
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;
  IF v_actor.role IS DISTINCT FROM 'coordenador' AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.';
  END IF;

  SELECT r.library_id, s.source_kind, s.destination_library_id
    INTO v_run_library_id, v_source_kind, v_destination
  FROM ingest.partner_catalog_import_runs r
  LEFT JOIN ingest.partner_catalog_sources s ON s.id = r.source_id
  WHERE r.id = p_run_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;

  -- Meme message que « introuvable » (B14, oracle d'existence, cf. fn_import_create).
  IF v_run_library_id IS DISTINCT FROM v_actor.library_id THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;

  -- 04/09/2026 : un lot venu d'un depot compagnon n'entre dans la file de
  -- catalogage que par l'administration du reseau (cf. en-tete).
  IF v_source_kind IN ('partner_deposit', 'oai_pmh') AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Deposito de catalogo companheiro reservado a administracao da rede.'
      USING HINT = 'error.import.deposit_admin_only';
  END IF;

  v_result := ingest.fn_bulk_create_book_drafts_from_run(
    p_run_id              := p_run_id,
    p_match_statuses      := p_match_statuses,
    p_editorial_decisions := p_editorial_decisions,
    p_batch_name          := p_batch_name,
    p_batch_notes         := p_batch_notes,
    p_created_by          := v_actor.user_id
  );

  -- 15/09/2026 : la biblio proprietaire se tamponne ICI, pas au repli de la
  -- publication. Catalogue propre (own_catalog, manual_upload, zotero_*,
  -- institutional_lookup) : la biblio du run, qui detient les livres. Depot
  -- de compagne / entrepot OAI : la destination declaree sur la source —
  -- rien si elle n'est pas encore connue (compagne non admise), et l'ecran
  -- le montre (« sans bibliotheque ») ; fn_batch_reassign_library fait le
  -- reste le jour de l'admission.
  v_batch_id := nullif(v_result->>'batch_id', '')::bigint;
  IF v_batch_id IS NOT NULL THEN
    v_owner := CASE
                 WHEN v_source_kind IN ('partner_deposit', 'oai_pmh') THEN v_destination
                 ELSE v_run_library_id
               END;
    IF v_owner IS NOT NULL THEN
      UPDATE public.book_drafts d
         SET owner_library_id = l.id,
             owner_library    = l.name
        FROM public.libraries l
       WHERE l.id = v_owner
         AND d.batch_id = v_batch_id
         AND d.owner_library_id IS NULL;
      GET DIAGNOSTICS v_stamped = ROW_COUNT;
    END IF;
  END IF;

  RETURN v_result || jsonb_build_object(
    'owner_library_id', v_owner,
    'owner_stamped', v_stamped
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_import_promote(bigint, text[], text[], text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_import_promote(bigint, text[], text[], text, text) TO authenticated, service_role;

-- -------------------------------------------------------------------------
-- 5. fn_batch_reassign_library : le geste d'admin qui manquait
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_batch_reassign_library(
  p_batch_id bigint,
  p_library_id uuid
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest'
AS $function$
DECLARE
  v_batch    public.catalog_batches%rowtype;
  v_lib      public.libraries%rowtype;
  v_before   text;
  v_n        integer := 0;
  v_published bigint := 0;
  v_sources  integer := 0;
  v_who      text;
  v_warnings text[] := ARRAY[]::text[];
BEGIN
  -- Reattribuer un lot, c'est decider a qui appartient un fonds : un acte de
  -- reseau, comme son entree (04/09) et sa revision (05/09).
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Reatribuicao de lote reservada a administracao da rede.'
      USING HINT = 'error.batch.reassign.admin_only';
  END IF;

  SELECT * INTO v_batch FROM public.catalog_batches WHERE id = p_batch_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Lote % introuvable', p_batch_id
      USING HINT = 'error.batch.reassign.not_found';
  END IF;
  IF v_batch.status <> 'open' THEN
    RAISE EXCEPTION 'Lote % nao esta aberto (%)', p_batch_id, v_batch.status
      USING HINT = 'error.batch.reassign.not_open';
  END IF;

  SELECT * INTO v_lib FROM public.libraries WHERE id = p_library_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Biblioteca % introuvable', p_library_id
      USING HINT = 'error.batch.reassign.library_not_found';
  END IF;

  -- Une revision APPROUVEE l'a ete sur un rapport rendu pour une autre
  -- biblio : on ne change pas la destination sous une approbation. Un tour
  -- demande ou renvoye en retouches n'empeche rien.
  IF public.fn_batch_review_status(p_batch_id) = 'approved' THEN
    RAISE EXCEPTION 'Lote % tem revisao aprovada : pedir novo turno antes de reatribuir', p_batch_id
      USING HINT = 'error.batch.reassign.review_approved';
  END IF;

  -- D'ou viennent-ils (pour la trace) ?
  SELECT string_agg(DISTINCT coalesce(l.name, 'sem biblioteca'), ', ' ORDER BY coalesce(l.name, 'sem biblioteca'))
    INTO v_before
    FROM public.book_drafts d
    LEFT JOIN public.libraries l ON l.id = d.owner_library_id
   WHERE d.batch_id = p_batch_id AND d.status IN ('draft', 'ready');

  -- Les brouillons en cours changent de proprietaire. initial_copies_library_id
  -- est remis a nul : c'est l'override admin lu EN DERNIER par
  -- publish_book_draft, il l'emporterait sur la reattribution.
  UPDATE public.book_drafts d
     SET owner_library_id = v_lib.id,
         owner_library    = v_lib.name,
         initial_copies_library_id = NULL,
         updated_at = now()
   WHERE d.batch_id = p_batch_id
     AND d.status IN ('draft', 'ready')
     AND (d.owner_library_id IS DISTINCT FROM v_lib.id
          OR d.owner_library IS DISTINCT FROM v_lib.name
          OR d.initial_copies_library_id IS NOT NULL);
  GET DIAGNOSTICS v_n = ROW_COUNT;

  SELECT count(*) INTO v_published
    FROM public.book_drafts d
   WHERE d.batch_id = p_batch_id AND d.status = 'published';

  -- La source compagne d'ou vient le lot suit : le prochain depot de la meme
  -- compagne arrivera directement chez elle.
  UPDATE ingest.partner_catalog_sources s
     SET destination_library_id = v_lib.id, updated_at = now()
   WHERE s.source_kind IN ('partner_deposit', 'oai_pmh')
     AND s.destination_library_id IS DISTINCT FROM v_lib.id
     AND s.id IN (
       SELECT r.source_id
         FROM ingest.partner_catalog_row_to_draft m
         JOIN ingest.partner_catalog_import_runs r ON r.id = m.run_id
        WHERE m.batch_id = p_batch_id
     );
  GET DIAGNOSTICS v_sources = ROW_COUNT;

  -- La trace, dans la langue des notes de lot (pt-BR, comme fn_create_book_drafts_from_import_rows).
  SELECT coalesce(nullif(btrim(concat_ws(' ', p.first_name, p.last_name)), ''), auth.uid()::text)
    INTO v_who
    FROM public.profiles p WHERE p.id = auth.uid();
  UPDATE public.catalog_batches
     SET notes = concat_ws(E'\n', nullif(notes, ''),
           format('[%s] Lote reatribuido a biblioteca « %s » por %s (%s rascunho(s) em curso ; antes : %s).',
                  to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI UTC'),
                  v_lib.name, coalesce(v_who, '?'), v_n, coalesce(v_before, 'sem biblioteca'))),
         updated_at = now()
   WHERE id = p_batch_id;

  -- array_append, pas « || 'litteral' » : un litteral non type a droite d'un
  -- text[] est lu comme un tableau (« malformed array literal »), vu au banc.
  IF v_lib.tombo_pattern IS NULL THEN v_warnings := array_append(v_warnings, 'library_without_tombo_pattern'); END IF;
  IF NOT coalesce(v_lib.is_active, false) THEN v_warnings := array_append(v_warnings, 'library_inactive'); END IF;
  IF v_n = 0 THEN v_warnings := array_append(v_warnings, 'nothing_to_do'); END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'batch_id', p_batch_id,
    'library_id', v_lib.id,
    'library_name', v_lib.name,
    'drafts_updated', v_n,
    'drafts_published_untouched', v_published,
    'sources_aligned', v_sources,
    'previous', v_before,
    'warnings', to_jsonb(v_warnings)
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_batch_reassign_library(bigint, uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_batch_reassign_library(bigint, uuid) TO authenticated, service_role;

COMMENT ON FUNCTION public.fn_batch_reassign_library(bigint, uuid) IS
  'Admin reseau : les brouillons en cours (draft/ready) d''un lot OUVERT recoivent p_library_id comme '
  'proprietaire (owner_library_id/owner_library ; initial_copies_library_id remis a nul). Les fiches '
  'publiees et la corbeille ne bougent pas. La source compagne du lot est alignee (destination_library_id). '
  'Trace dans catalog_batches.notes. Refus : lot ferme, biblio inconnue, revision approuvee. '
  'Avertissements (warnings) : library_without_tombo_pattern, library_inactive, nothing_to_do. Paquet 15/09/2026.';

-- -------------------------------------------------------------------------
-- 6. fn_batch_owner_libraries : ce que l'ecran montre avant de publier
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_batch_owner_libraries()
 RETURNS TABLE(batch_id bigint, library_id uuid, library_name text, drafts bigint)
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select d.batch_id, d.owner_library_id, l.name, count(*)
    from public.book_drafts d
    join public.catalog_batches b on b.id = d.batch_id
    left join public.libraries l on l.id = d.owner_library_id
   where b.status <> 'archived'
     and d.status in ('draft', 'ready')
     and (public.fn_caller_is_network_admin()
          or exists (select 1 from public.user_library_memberships m
                      where m.user_id = auth.uid() and m.status = 'active'
                        and m.role in ('librarian', 'coordenador')))
   group by d.batch_id, d.owner_library_id, l.name
   order by d.batch_id, l.name nulls first;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_batch_owner_libraries() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_batch_owner_libraries() TO authenticated, service_role;

COMMENT ON FUNCTION public.fn_batch_owner_libraries() IS
  'Staff : par lot non archive, les biblios proprietaires des brouillons en cours (library_id nul = '
  '« sans bibliotheque », donc repli a la publication) et leurs effectifs. Paquet 15/09/2026.';

-- -------------------------------------------------------------------------
-- Verification en fin de transaction
-- -------------------------------------------------------------------------
DO $verif$
DECLARE
  v_def text;
  v_n int;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema = 'ingest' AND table_name = 'partner_catalog_sources'
                    AND column_name = 'destination_library_id') THEN
    RAISE EXCEPTION 'destination_library_id absente';
  END IF;
  IF to_regclass('ingest.partner_catalog_sources_destination_library_idx') IS NULL THEN
    RAISE EXCEPTION 'index de la FK destination_library_id absent';
  END IF;

  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'fn_import_register_deposit_source';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'fn_import_register_deposit_source : % signatures (attendu 1, sinon PostgREST hesite)', v_n;
  END IF;

  v_def := pg_get_functiondef('public.fn_import_promote(bigint, text[], text[], text, text)'::regprocedure);
  IF v_def NOT LIKE '%owner_library_id%' OR v_def NOT LIKE '%error.import.deposit_admin_only%' THEN
    RAISE EXCEPTION 'fn_import_promote : le tampon de la biblio ou la garde du 04/09 manque';
  END IF;

  IF has_function_privilege('anon', 'public.fn_batch_reassign_library(bigint, uuid)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.fn_batch_owner_libraries()', 'EXECUTE')
     OR has_function_privilege('anon', 'public.fn_import_register_deposit_source(text, text, uuid)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.fn_import_list_sources()', 'EXECUTE')
     OR has_function_privilege('anon', 'public.fn_import_promote(bigint, text[], text[], text, text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'une fonction du paquet est ouverte a anon';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.fn_batch_reassign_library(bigint, uuid)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.fn_batch_owner_libraries()', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.fn_import_register_deposit_source(text, text, uuid)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.fn_import_list_sources()', 'EXECUTE') THEN
    RAISE EXCEPTION 'une fonction d''ecran du paquet n''est pas executable par authenticated';
  END IF;
  RAISE NOTICE 'paquet un-lot-importe-a-une-bibliotheque : verifications OK';
END;
$verif$;

COMMIT;
