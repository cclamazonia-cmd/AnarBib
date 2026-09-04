-- =========================================================================
-- Paquet depot-partenaire-reserve-a-l-administration — importer son propre
-- catalogue reste un geste de coordination ; deposer le catalogue d'une
-- bibliotheque compagne devient un geste d'administration du reseau
-- =========================================================================
-- Date     : 2026-09-04
-- Chantier : importations — qui peut faire entrer quoi dans le catalogue
-- Auteur   : coordination AnarBib (decision Xavier du 04/09/2026)
--
-- POURQUOI
--   L'import n'ecrit jamais directement dans le catalogue du reseau : il
--   remplit la file de brouillons de la bibliotheque, et c'est la publication
--   (publish_book_draft) qui fait entrer la notice, avec un holding dans la
--   bibliotheque de destination. Importer SON catalogue, c'est cataloguer en
--   masse : un geste de coordination, comme la saisie a la main.
--
--   Mais toutes les sources ne se valent pas. Une source partner_deposit est
--   le catalogue d'une bibliotheque COMPAGNE : la bibliotheque qui l'importe ne
--   detient pas ces livres, et a la publication chaque brouillon recoit quand
--   meme une bibliotheque de destination. Le cas s'est presente avec le fonds
--   Solidaires (source #17, 27/08/2026) : la source n'est pas une bibliotheque
--   et son statut federal est reste en suspens. Faire entrer un fonds tiers
--   engage le reseau ; c'est la meme doctrine que la page Reseau (02/09/2026) :
--   la porte federale reste a l'administration, posee dans la page du geste.
--
--   Et jusqu'ici la SEULE voie de fichier ouverte a une coordination passait
--   par une source partner_deposit (« + Nouveau partenaire ») : en production
--   il n'existe aucune source de type « catalogue propre » (sources #14 et #17,
--   toutes deux partner_deposit sous BLMF ; la #3 manual_upload n'est rattachee
--   a aucune bibliotheque). Fermer le depot sans ouvrir le catalogue propre
--   aurait retire l'import de fichier aux coordinations. D'ou les deux gestes
--   de ce paquet, indissociables.
--
-- CE QUE FAIT LE PAQUET
--   1. Le vocabulaire source_kind gagne 'own_catalog' : le catalogue propre
--      de la bibliotheque (migration depuis un SIGB, export maison). Distinct
--      de manual_upload, qui ne dit pas A QUI est le catalogue.
--   2. public.fn_import_own_source() : retrouve ou cree, pour la bibliotheque
--      active, SA source own_catalog (nom = nom de la bibliotheque,
--      relation_status 'mapeada' — statut le plus faible, on n'affirme aucune
--      relation, il n'y a personne en face). Coordination ou admin reseau.
--   3. fn_import_register_deposit_source : admin reseau seulement.
--   4. fn_import_create et fn_import_promote : refusent, pour une source
--      partner_deposit, tout appelant qui n'est pas admin reseau. Les deux
--      bouts du circuit — deposer le fichier, faire entrer le lot dans la
--      file — sont gardes ; les gestes intermediaires (decisions editoriales,
--      profils) n'ecrivent rien hors du run et restent ouverts.
--   Le refus porte le HINT i18n 'error.import.deposit_admin_only', que
--   localizeError sait traduire dans les dix langues.
--
-- CE QUE LE PAQUET NE FAIT PAS
--   - Il ne change pas le type de retour de fn_import_list_runs : l'ecran
--     joint deja runs.source_id a la liste des sources, qui porte source_kind.
--   - Il ne touche pas au moissonnage OAI-PMH ni a la recherche externe
--     (catalogage derive, un candidat a la fois).
--   - Il ne requalifie aucune source existante.
--
-- CHECKLIST DOCTRINE
--   [x] Fonctions SECURITY DEFINER : search_path conserve (public, ingest, auth)
--   [x] REVOKE EXECUTE FROM PUBLIC + GRANT aux roles cibles rejoues
--   [x] CHECK elargie : l'ancien vocabulaire est un sous-ensemble strict du
--       nouveau, aucune ligne existante invalidee
--   [x] Aucune table, vue ou policy creee ; RLS inchangee
--   [x] DO block de verification STRUCTUREL (les migrations tournent AVANT le
--       seed en CI) ; le bout-en-bout fonctionnel vit dans
--       tests/sql/import_depot_partenaire_admin_tests.sql
-- =========================================================================

begin;

-- ── 1. Le vocabulaire de provenance gagne le catalogue propre ────────────
alter table ingest.partner_catalog_sources
  drop constraint if exists partner_catalog_sources_source_kind_check;
alter table ingest.partner_catalog_sources
  add constraint partner_catalog_sources_source_kind_check
  check (source_kind = any (array[
    'manual_upload',
    'zotero_file_export',
    'zotero_api',
    'partner_deposit',
    'institutional_lookup',
    'oai_pmh',
    -- Le catalogue PROPRE de la bibliotheque (migration depuis un SIGB, export
    -- maison). Une seule par bibliotheque, posee par fn_import_own_source.
    -- C'est la provenance qui reste ouverte a la coordination quand le depot
    -- d'un catalogue compagnon (partner_deposit) passe a l'administration.
    'own_catalog'
  ]));

comment on constraint partner_catalog_sources_source_kind_check
  on ingest.partner_catalog_sources is
  'Vocabulaire de provenance des sources. Elargi le 28/08/2026 a '
  'institutional_lookup et oai_pmh, le 04/09/2026 a own_catalog (catalogue '
  'propre de la bibliotheque, pose par fn_import_own_source).';

-- ── 2. La source « catalogue propre » de la bibliotheque active ──────────
create or replace function public.fn_import_own_source()
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'ingest', 'auth'
as $function$
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
  IF v_actor.role IS DISTINCT FROM 'coordenador' AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.';
  END IF;

  SELECT id INTO v_source_id
    FROM ingest.partner_catalog_sources
   WHERE library_id  = v_actor.library_id
     AND source_kind = 'own_catalog'
   ORDER BY id
   LIMIT 1;

  IF v_source_id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'source_id', v_source_id, 'created', false);
  END IF;

  SELECT l.name INTO v_name FROM public.libraries l WHERE l.id = v_actor.library_id;

  -- 'mapeada' : statut le plus faible du vocabulaire — il n'y a personne en
  -- face, c'est le catalogue de la bibliotheque elle-meme. import_enabled
  -- true, sinon ingest.fn_create_partner_catalog_import refuse le depot.
  INSERT INTO ingest.partner_catalog_sources
    (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES
    (coalesce(v_name, 'Catalogo proprio'), v_actor.library_id, 'mapeada', 'own_catalog', true)
  RETURNING id INTO v_source_id;

  RETURN jsonb_build_object('ok', true, 'source_id', v_source_id, 'created', true);
END;
$function$;

revoke execute on function public.fn_import_own_source() from public;
grant  execute on function public.fn_import_own_source() to authenticated, service_role;

comment on function public.fn_import_own_source() is
  'Retrouve ou cree la source own_catalog (catalogue propre) de la bibliotheque '
  'active. Coordination ou admin reseau. Idempotente : une seule source par '
  'bibliotheque, la premiere par id.';

-- ── 3. Enregistrer une source de depot : administration du reseau ─────────
create or replace function public.fn_import_register_deposit_source(
  p_partner_name text,
  p_notes        text default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'ingest', 'auth'
as $function$
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

  SELECT id INTO v_source_id
    FROM ingest.partner_catalog_sources
   WHERE library_id  = v_actor.library_id
     AND source_kind = 'partner_deposit'
     AND partner_name = v_name
   LIMIT 1;

  IF v_source_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok', true, 'source_id', v_source_id, 'created', false
    );
  END IF;

  -- 'mapeada' : statut le plus faible du vocabulaire (cf. 20260828100000).
  INSERT INTO ingest.partner_catalog_sources
    (partner_name, library_id, relation_status, source_kind,
     import_enabled, notes)
  VALUES
    (v_name, v_actor.library_id, 'mapeada', 'partner_deposit',
     true, nullif(trim(p_notes), ''))
  RETURNING id INTO v_source_id;

  RETURN jsonb_build_object(
    'ok', true, 'source_id', v_source_id, 'created', true
  );
END;
$function$;

revoke execute on function public.fn_import_register_deposit_source(text, text) from public;
grant  execute on function public.fn_import_register_deposit_source(text, text) to authenticated, service_role;

comment on function public.fn_import_register_deposit_source(text, text) is
  'Enregistre une source de depot (partner_deposit) pour la bibliotheque active, '
  'sans creer d''entite catalog_partners. Idempotente par nom. Depuis le '
  '04/09/2026 : administration du reseau seulement (HINT error.import.deposit_admin_only).';

-- ── 4a. Deposer un fichier : la source partner_deposit est reservee ───────
create or replace function public.fn_import_create(
  p_source_id         bigint,
  p_storage_path      text,
  p_original_filename text,
  p_bucket_id         text   default 'catalogos_parceiros_raw',
  p_mime_type         text   default null,
  p_size_bytes        bigint default null,
  p_sha256            text   default null,
  p_detected_format   text   default 'unknown'
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'ingest', 'auth'
as $function$
DECLARE
  v_actor public.my_access%rowtype;
  v_source_library_id uuid;
  v_source_kind text;
  v_run_id bigint;
BEGIN
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;
  IF v_actor.role IS DISTINCT FROM 'coordenador' AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.';
  END IF;

  SELECT s.library_id, s.source_kind INTO v_source_library_id, v_source_kind
  FROM ingest.partner_catalog_sources s
  WHERE s.id = p_source_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Source % introuvable', p_source_id;
  END IF;

  -- Meme message que « introuvable » : un refus ne dit pas si la chose existe
  -- ailleurs (B14, 20260901091431 — l'oracle d'existence). Le corps ci-dessus
  -- part de la definition REELLE (pg_get_functiondef en prod), pas du baseline.
  IF v_source_library_id IS DISTINCT FROM v_actor.library_id THEN
    RAISE EXCEPTION 'Source % introuvable', p_source_id;
  END IF;

  -- 04/09/2026 : le catalogue d'une bibliotheque compagne n'entre que par
  -- l'administration du reseau (cf. en-tete). Le catalogue propre
  -- (own_catalog) et les autres provenances restent a la coordination.
  IF v_source_kind = 'partner_deposit' AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Deposito de catalogo companheiro reservado a administracao da rede.'
      USING HINT = 'error.import.deposit_admin_only';
  END IF;

  v_run_id := ingest.fn_create_partner_catalog_import(
    p_source_id         := p_source_id,
    p_storage_path      := p_storage_path,
    p_original_filename := p_original_filename,
    p_bucket_id         := p_bucket_id,
    p_mime_type         := p_mime_type,
    p_size_bytes        := p_size_bytes,
    p_sha256            := p_sha256,
    p_detected_format   := p_detected_format,
    p_requested_by      := v_actor.user_id
  );

  UPDATE ingest.partner_catalog_import_runs
  SET library_id = v_actor.library_id
  WHERE id = v_run_id AND library_id IS NULL;

  RETURN jsonb_build_object(
    'ok',         true,
    'run_id',     v_run_id,
    'library_id', v_actor.library_id
  );
END;
$function$;

revoke execute on function public.fn_import_create(bigint, text, text, text, text, bigint, text, text) from public;
grant  execute on function public.fn_import_create(bigint, text, text, text, text, bigint, text, text) to authenticated, service_role;

-- ── 4b. Faire entrer le lot dans la file : meme garde ─────────────────────
create or replace function public.fn_import_promote(
  p_run_id              bigint,
  p_match_statuses      text[] default null,
  p_editorial_decisions text[] default array['accept_new', 'accept_duplicate'],
  p_batch_name          text   default null,
  p_batch_notes         text   default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'ingest', 'auth'
as $function$
DECLARE
  v_actor public.my_access%rowtype;
  v_run_library_id uuid;
  v_source_kind text;
BEGIN
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;
  IF v_actor.role IS DISTINCT FROM 'coordenador' AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.';
  END IF;

  SELECT r.library_id, s.source_kind INTO v_run_library_id, v_source_kind
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
  IF v_source_kind = 'partner_deposit' AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Deposito de catalogo companheiro reservado a administracao da rede.'
      USING HINT = 'error.import.deposit_admin_only';
  END IF;

  RETURN ingest.fn_bulk_create_book_drafts_from_run(
    p_run_id              := p_run_id,
    p_match_statuses      := p_match_statuses,
    p_editorial_decisions := p_editorial_decisions,
    p_batch_name          := p_batch_name,
    p_batch_notes         := p_batch_notes,
    p_created_by          := v_actor.user_id
  );
END;
$function$;

revoke execute on function public.fn_import_promote(bigint, text[], text[], text, text) from public;
grant  execute on function public.fn_import_promote(bigint, text[], text[], text, text) to authenticated, service_role;

-- ── 5. Verification structurelle (aucune dependance aux donnees) ──────────
do $verif$
declare
  v_def text;
  v_n   int;
begin
  -- own_catalog est bien dans la CHECK
  select pg_get_constraintdef(c.oid) into v_def
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
   where n.nspname = 'ingest' and t.relname = 'partner_catalog_sources'
     and c.conname = 'partner_catalog_sources_source_kind_check';
  if v_def is null or position('own_catalog' in v_def) = 0 then
    raise exception 'partner_catalog_sources_source_kind_check n''admet pas own_catalog';
  end if;

  -- les trois gardes portent le HINT
  for v_def in
    select pg_get_functiondef(p.oid)
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname in ('fn_import_register_deposit_source', 'fn_import_create', 'fn_import_promote')
  loop
    if position('error.import.deposit_admin_only' in v_def) = 0 then
      raise exception 'une garde deposit_admin_only manque : %', left(v_def, 120);
    end if;
  end loop;

  -- fn_import_own_source existe, fermee a anon et PUBLIC
  if to_regprocedure('public.fn_import_own_source()') is null then
    raise exception 'fn_import_own_source introuvable apres migration';
  end if;
  select count(*) into v_n
    from information_schema.routine_privileges
   where routine_schema = 'public' and routine_name = 'fn_import_own_source'
     and grantee in ('anon', 'PUBLIC');
  if v_n <> 0 then
    raise exception 'fn_import_own_source ouverte a anon/PUBLIC (% droit(s))', v_n;
  end if;

  raise notice 'Paquet depot-partenaire-reserve-a-l-administration : verifications OK';
end
$verif$;

commit;
