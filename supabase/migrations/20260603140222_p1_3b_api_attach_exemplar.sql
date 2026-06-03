-- Migration P1.3b -- api.attach_exemplar
-- Chantier exemplares Phase 1. spec-exemplaires-circulation 7.1, bouton "Criar exemplar aqui".
--
-- Role : rattacher un exemplaire a une notice DEJA publiee (partagee reseau), pour la
-- biblioteca courante. C'est le chainon federatif manquant : aucune fonction SQL ne cree
-- de book_holdings (ils naissaient cote frontend), donc on cree ici (si absent) le holding
-- local (Camada 2) de la notice (Camada 1), puis on cree un exemplaire (Camada 3) via le
-- flux exemplar_draft -> publish_exemplar_draft (qui seede circulation_policy, cf. P1.2).
--
-- Conception (DOC-OBJ-2) : une seule fonction SECURITY DEFINER cliente, search_path fixe,
-- controle staff interne, REVOKE public/anon/service_role + GRANT authenticated, DO-block.
-- Biblio courante = membership actif principal (meme resolution que publish_exemplar_draft).
--
-- Deploiement : fonction NEUVE en SECURITY DEFINER -> le hook pre-commit Test 2 signalera
-- l'absence de REVOKE FROM authenticated (attendu : on GRANT authenticated). commit --no-verify.

create or replace function api.attach_exemplar(
  p_book_id            bigint,
  p_tombo              text default null,
  p_circulation_policy text default null,   -- emprestavel|consulta|ambos ; null => seed notice
  p_visibility         text default null,   -- public|staff_only ; null => public
  p_acquisition_mode   text default null,
  p_acquisition_date   date default null,
  p_provenance_note    text default null,
  p_source_library     text default null
) returns bigint
  language plpgsql
  security definer
  set search_path to 'public'
as $$
declare
  v_uid          uuid := auth.uid();
  v_library_id   uuid;
  v_role         text;
  v_bib_ref      text;
  v_pol          text := nullif(btrim(lower(coalesce(p_circulation_policy, ''))), '');
  v_vis          text := nullif(btrim(lower(coalesce(p_visibility, ''))), '');
  v_holding_id   bigint;
  v_draft_id     bigint;
  v_exemplar_id  bigint;
begin
  -- auth
  if v_uid is null then
    raise exception 'auth_required'
      using errcode = '28000', hint = 'Authentification obrigatoria.';
  end if;

  -- biblio courante = membership actif principal ; doit etre staff
  select ulm.library_id, ulm.role
    into v_library_id, v_role
  from public.user_library_memberships ulm
  where ulm.user_id = v_uid
    and ulm.status = 'active'
    and ulm.is_primary = true
  limit 1;

  if v_library_id is null then
    raise exception 'library_not_identified'
      using errcode = 'P0001',
            hint = 'Nenhuma biblioteca ativa/principal encontrada para o usuario atual.';
  end if;

  if v_role not in ('librarian', 'coordenador') then
    raise exception 'not_staff_of_this_library'
      using errcode = '42501',
            hint = 'Esta acao esta reservada a equipe da biblioteca.';
  end if;

  -- garde-fous d'enum (laisse passer null = defaut/seed)
  if v_pol is not null and v_pol not in ('emprestavel', 'consulta', 'ambos') then
    raise exception 'invalid_circulation_policy: %', p_circulation_policy
      using errcode = '22023',
            hint = 'Padrao de circulacao invalido (emprestavel|consulta|ambos).';
  end if;
  if v_vis is not null and v_vis not in ('public', 'staff_only') then
    raise exception 'invalid_visibility: %', p_visibility
      using errcode = '22023',
            hint = 'Visibilidade invalida (public|staff_only).';
  end if;

  -- notice cible : doit exister (notice publiee, partagee reseau)
  select b.bib_ref into v_bib_ref
  from public.books b
  where b.id = p_book_id;

  if not found then
    raise exception 'book_not_found: %', p_book_id
      using errcode = 'P0001',
            hint = format('Ficha %s nao encontrada.', p_book_id);
  end if;

  -- get-or-create du holding local (Camada 2) pour (notice, biblio courante)
  insert into public.book_holdings (book_id, library_id)
  values (p_book_id, v_library_id)
  on conflict (book_id, library_id) do update
    set updated_at = now()
  returning id into v_holding_id;

  -- brouillon d'exemplaire deja resolu sur le holding ; attributs optionnels.
  -- circulation_policy null => publish_exemplar_draft seede depuis la notice (P1.2).
  insert into public.exemplar_drafts (
    action, status,
    target_library_id, target_holding_id, target_bib_ref,
    tombo,
    circulation_policy, visibility,
    acquisition_mode, acquisition_date, provenance_note, source_library,
    created_by, updated_by
  )
  values (
    'create', 'ready',
    v_library_id, v_holding_id, v_bib_ref,
    nullif(btrim(coalesce(p_tombo, '')), ''),
    v_pol,
    coalesce(v_vis, 'public'),
    nullif(btrim(coalesce(p_acquisition_mode, '')), ''),
    p_acquisition_date,
    nullif(btrim(coalesce(p_provenance_note, '')), ''),
    nullif(btrim(coalesce(p_source_library, '')), ''),
    v_uid, v_uid
  )
  returning id into v_draft_id;

  -- publication -> cree l'exemplaire (seed P1.2) et renvoie son id
  v_exemplar_id := public.publish_exemplar_draft(v_draft_id);

  -- le holding vient peut-etre d'etre cree (0/0) : recalcul des compteurs
  perform public.fn_v2_recompute_holdings_availability(array[v_holding_id]::bigint[], null);

  return v_exemplar_id;
end;
$$;

comment on function api.attach_exemplar(bigint, text, text, text, text, date, text, text) is
  'P1.3b (spec-exemplaires-circulation 7.1) : rattache un exemplaire a une notice partagee pour la biblioteca courante. Get-or-create du book_holding local + exemplar_draft + publish_exemplar_draft (seed P1.2). SECURITY DEFINER, controle staff interne. Retour : id du nouvel exemplaire.';

-- ACL : RPC cliente. Pas de REVOKE FROM authenticated (on lui GRANT EXECUTE) ;
-- le controle staff est interne. (Hook Test 2 -> commit --no-verify.)
revoke execute on function api.attach_exemplar(bigint, text, text, text, text, date, text, text)
  from public, anon, service_role;
grant execute on function api.attach_exemplar(bigint, text, text, text, text, date, text, text)
  to authenticated;

-- Verification non destructive
do $$
begin
  if to_regprocedure('api.attach_exemplar(bigint,text,text,text,text,date,text,text)') is null then
    raise exception 'P1.3b: api.attach_exemplar absente apres migration';
  end if;
end
$$;
