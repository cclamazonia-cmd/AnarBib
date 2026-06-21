-- 20260621180651_audio_p1_tracks_segments_sublayer.sql
--
-- Chantier #AUDIO-fonds — Paquet P1 : sous-couche granularité (segments).
-- Cf. spec-fonds-sonores §5 (re-ancré works) / §11 ; REGISTRE §35 AUDIO ;
--     docs/journal/cadrages/CADRAGE_fonds_sonores_P1_2026-06-21.md.
--
-- La captation reste une EDITION books audio (work_id/expression_id) ; on ajoute
-- la granularite INTRA-document : le segment (audio_tracks, MB Track) et son credit
-- au grain segment (audio_track_contributors, MB Relationship), + une ref de types
-- de captation. L'oeuvre realisee d'un segment = public.works (FS-D4). Credits au
-- grain edition = book_contributors existant (derives vers l'oeuvre, hors migration).
--
-- Visibilite P1 = STAFF ONLY (librarian/coordenador) sur les 2 tables de contenu ;
-- exposition OPAC public-safe = P3 (via catalog_list_anon_v1). La ref = lecture publique.
--
-- Auteur  : Claude (assistant·e) — redaction assistee
-- Session : Fonds sonores
-- Doctrine: _TEMPLATE (RLS + GRANT + policies + service_role), DOC-OBJ-2
--           (SECURITY DEFINER + search_path + REVOKE/GRANT), vues security_invoker,
--           DO-block de verification. Idempotent (IF NOT EXISTS + guards).

begin;

-- ============================================================================
-- 1) Reference : types de captation (patron catalog_ref_*)
-- ============================================================================
create table if not exists public.catalog_ref_audio_recording_types (
  code       text primary key,
  label      text not null,
  sort_order integer not null default 100,
  is_active  boolean not null default true
);

grant select on public.catalog_ref_audio_recording_types to anon, authenticated;
grant all    on public.catalog_ref_audio_recording_types to service_role;
alter table public.catalog_ref_audio_recording_types enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='catalog_ref_audio_recording_types' and policyname='crart_read_all') then
    create policy crart_read_all on public.catalog_ref_audio_recording_types
      for select to anon, authenticated using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='catalog_ref_audio_recording_types' and policyname='crart_write_staff') then
    create policy crart_write_staff on public.catalog_ref_audio_recording_types
      for all to authenticated
      using (exists (select 1 from public.user_library_memberships m where m.user_id=auth.uid() and m.role = any(array['librarian','coordenador']) and m.status='active'))
      with check (exists (select 1 from public.user_library_memberships m where m.user_id=auth.uid() and m.role = any(array['librarian','coordenador']) and m.status='active'));
  end if;
end $$;

insert into public.catalog_ref_audio_recording_types (code, label, sort_order) values
  ('captacao_ao_vivo', 'Captação ao vivo',   10),
  ('estudio',          'Estúdio',            20),
  ('radio',            'Rádio',              30),
  ('campo',            'Gravação de campo',  40),
  ('entrevista',       'Entrevista',         50),
  ('outro',            'Outro',             900)
on conflict (code) do nothing;

-- ============================================================================
-- 2) audio_tracks (MB: Track) — le segment
-- ============================================================================
create table if not exists public.audio_tracks (
  id                    bigint generated always as identity primary key,
  book_id               bigint not null references public.books(id) on delete cascade,
  position              integer not null,
  title                 text,
  start_offset          text,                 -- ex. '00:12:30'
  duration              text,
  work_id               bigint references public.works(id) on delete set null,                 -- l'oeuvre realisee (FS-D4)
  digital_resource_id   bigint references public.book_digital_resources(id) on delete set null, -- le fichier precis (optionnel)
  recording_type        text references public.catalog_ref_audio_recording_types(code),
  recording_date        date,
  recording_date_approx text,
  place_text            text,
  external_ids          jsonb not null default '{}'::jsonb,
  notes                 text,
  created_by            uuid references auth.users(id) on delete set null,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint audio_tracks_external_ids_is_object check (jsonb_typeof(external_ids) = 'object'),
  constraint audio_tracks_book_position_uniq    unique (book_id, position)
);

create index if not exists idx_audio_tracks_book_id   on public.audio_tracks(book_id);
create index if not exists idx_audio_tracks_work_id   on public.audio_tracks(work_id);
create index if not exists idx_audio_tracks_resource  on public.audio_tracks(digital_resource_id);

grant select on public.audio_tracks to authenticated;
grant all    on public.audio_tracks to service_role;
alter table public.audio_tracks enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='audio_tracks' and policyname='audio_tracks_read_staff') then
    create policy audio_tracks_read_staff on public.audio_tracks
      for select to authenticated
      using (exists (select 1 from public.user_library_memberships m where m.user_id=auth.uid() and m.role = any(array['librarian','coordenador']) and m.status='active'));
  end if;
end $$;

-- updated_at auto (si le helper existe au repo)
do $$ begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='fn_set_updated_at')
     and not exists (select 1 from pg_trigger where tgname='trg_audio_tracks_set_updated_at') then
    create trigger trg_audio_tracks_set_updated_at before update on public.audio_tracks
      for each row execute function public.fn_set_updated_at();
  end if;
end $$;

comment on table public.audio_tracks is
  'Segment positionne dans une edition audio (books.tipo_material=audio). MB: Track. '
  'work_id -> public.works (l''oeuvre realisee, FS-D4). Visibilite staff-only en P1 ; '
  'OPAC public-safe = P3. spec-fonds-sonores §5, REGISTRE §35.';

-- ============================================================================
-- 3) audio_track_contributors (MB: Relationship) — credit au grain segment
-- ============================================================================
create table if not exists public.audio_track_contributors (
  id          bigint generated always as identity primary key,
  track_id    bigint not null references public.audio_tracks(id) on delete cascade,
  author_id   bigint references public.authors(id) on delete set null,  -- l'autorite (FS-D5)
  name        text not null,                                            -- repli affichage (cf. book_contributors.name)
  role        text not null default 'locutor',                          -- texte libre, vocab pt-BR
  position    integer not null default 1,
  is_primary  boolean not null default false,
  created_at  timestamptz not null default now()
);

create index if not exists idx_audio_track_contrib_track  on public.audio_track_contributors(track_id);
create index if not exists idx_audio_track_contrib_author on public.audio_track_contributors(author_id);

grant select on public.audio_track_contributors to authenticated;
grant all    on public.audio_track_contributors to service_role;
alter table public.audio_track_contributors enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='audio_track_contributors' and policyname='atc_read_staff') then
    create policy atc_read_staff on public.audio_track_contributors
      for select to authenticated
      using (exists (select 1 from public.user_library_memberships m where m.user_id=auth.uid() and m.role = any(array['librarian','coordenador']) and m.status='active'));
  end if;
end $$;

comment on table public.audio_track_contributors is
  'Credit au grain segment (locutor·a, interprete, compositor...). MB: Relationship. '
  'Reutilise l''autorite authors (author_id) + repli name. role = texte libre (vocab pt-BR). FS-D5.';

-- ============================================================================
-- 4) RPC d'ecriture (schema api, SECURITY DEFINER, staff-gated)
-- ============================================================================
create or replace function api.audio_track_upsert(
  p_book_id               bigint,
  p_position              integer,
  p_title                 text    default null,
  p_start_offset          text    default null,
  p_duration              text    default null,
  p_work_id               bigint  default null,
  p_digital_resource_id   bigint  default null,
  p_recording_type        text    default null,
  p_recording_date        date    default null,
  p_recording_date_approx text    default null,
  p_place_text            text    default null,
  p_notes                 text    default null,
  p_track_id              bigint  default null
) returns bigint
language plpgsql
security definer
set search_path = public, pg_catalog
as $fn$
declare
  v_id bigint;
begin
  if not exists (select 1 from public.user_library_memberships m where m.user_id=auth.uid() and m.role = any(array['librarian','coordenador']) and m.status='active') then
    raise exception 'error.audio.forbidden';
  end if;
  if not exists (select 1 from public.books b where b.id=p_book_id and coalesce(b.tipo_material,'') in ('audio','audiovisual')) then
    raise exception 'error.audio.bookNotAudio';
  end if;
  if p_work_id is not null and not exists (select 1 from public.works w where w.id=p_work_id) then
    raise exception 'error.audio.workNotFound';
  end if;
  if p_recording_type is not null and not exists (select 1 from public.catalog_ref_audio_recording_types t where t.code=p_recording_type) then
    raise exception 'error.audio.recordingTypeInvalid';
  end if;
  if p_digital_resource_id is not null and not exists (select 1 from public.book_digital_resources d where d.id=p_digital_resource_id and d.book_id=p_book_id) then
    raise exception 'error.audio.resourceNotInBook';
  end if;

  if p_track_id is null then
    insert into public.audio_tracks
      (book_id, position, title, start_offset, duration, work_id, digital_resource_id, recording_type, recording_date, recording_date_approx, place_text, notes, created_by)
    values
      (p_book_id, p_position, p_title, p_start_offset, p_duration, p_work_id, p_digital_resource_id, p_recording_type, p_recording_date, p_recording_date_approx, p_place_text, p_notes, auth.uid())
    returning id into v_id;
  else
    update public.audio_tracks set
      book_id=p_book_id, position=p_position, title=p_title, start_offset=p_start_offset, duration=p_duration,
      work_id=p_work_id, digital_resource_id=p_digital_resource_id, recording_type=p_recording_type,
      recording_date=p_recording_date, recording_date_approx=p_recording_date_approx, place_text=p_place_text,
      notes=p_notes, updated_at=now()
    where id=p_track_id
    returning id into v_id;
    if v_id is null then raise exception 'error.audio.trackNotFound'; end if;
  end if;
  return v_id;
end;
$fn$;
revoke execute on function api.audio_track_upsert(bigint,integer,text,text,text,bigint,bigint,text,date,text,text,text,bigint) from public, anon;
grant  execute on function api.audio_track_upsert(bigint,integer,text,text,text,bigint,bigint,text,date,text,text,text,bigint) to authenticated;

create or replace function api.audio_track_delete(p_track_id bigint)
returns void
language plpgsql security definer set search_path = public, pg_catalog
as $fn$
begin
  if not exists (select 1 from public.user_library_memberships m where m.user_id=auth.uid() and m.role = any(array['librarian','coordenador']) and m.status='active') then
    raise exception 'error.audio.forbidden';
  end if;
  delete from public.audio_tracks where id=p_track_id;
end;
$fn$;
revoke execute on function api.audio_track_delete(bigint) from public, anon;
grant  execute on function api.audio_track_delete(bigint) to authenticated;

create or replace function api.audio_track_contributor_add(
  p_track_id   bigint,
  p_name       text,
  p_role       text    default 'locutor',
  p_author_id  bigint  default null,
  p_position   integer default 1,
  p_is_primary boolean default false
) returns bigint
language plpgsql security definer set search_path = public, pg_catalog
as $fn$
declare
  v_id bigint;
begin
  if not exists (select 1 from public.user_library_memberships m where m.user_id=auth.uid() and m.role = any(array['librarian','coordenador']) and m.status='active') then
    raise exception 'error.audio.forbidden';
  end if;
  if not exists (select 1 from public.audio_tracks t where t.id=p_track_id) then
    raise exception 'error.audio.trackNotFound';
  end if;
  if p_author_id is not null and not exists (select 1 from public.authors a where a.id=p_author_id) then
    raise exception 'error.audio.authorNotFound';
  end if;
  if coalesce(btrim(p_name),'') = '' then
    raise exception 'error.audio.nameRequired';
  end if;
  insert into public.audio_track_contributors (track_id, author_id, name, role, position, is_primary)
  values (p_track_id, p_author_id, btrim(p_name), coalesce(nullif(btrim(p_role),''),'locutor'), p_position, p_is_primary)
  returning id into v_id;
  return v_id;
end;
$fn$;
revoke execute on function api.audio_track_contributor_add(bigint,text,text,bigint,integer,boolean) from public, anon;
grant  execute on function api.audio_track_contributor_add(bigint,text,text,bigint,integer,boolean) to authenticated;

create or replace function api.audio_track_contributor_remove(p_contributor_id bigint)
returns void
language plpgsql security definer set search_path = public, pg_catalog
as $fn$
begin
  if not exists (select 1 from public.user_library_memberships m where m.user_id=auth.uid() and m.role = any(array['librarian','coordenador']) and m.status='active') then
    raise exception 'error.audio.forbidden';
  end if;
  delete from public.audio_track_contributors where id=p_contributor_id;
end;
$fn$;
revoke execute on function api.audio_track_contributor_remove(bigint) from public, anon;
grant  execute on function api.audio_track_contributor_remove(bigint) to authenticated;

-- ============================================================================
-- 5) Vue de confort staff (security_invoker -> RLS staff de audio_tracks)
-- ============================================================================
create or replace view public.v_audio_tracklist
with (security_invoker = true) as
select
  t.id   as track_id,
  t.book_id,
  t.position,
  t.title,
  t.start_offset,
  t.duration,
  t.work_id,
  w.uniform_title as work_title,
  t.digital_resource_id,
  t.recording_type,
  rt.label as recording_type_label,
  t.recording_date,
  t.recording_date_approx,
  t.place_text,
  t.notes,
  coalesce((
    select jsonb_agg(jsonb_build_object('id', c.id, 'author_id', c.author_id, 'name', c.name, 'role', c.role, 'position', c."position", 'is_primary', c.is_primary)
                     order by c."position", c.id)
    from public.audio_track_contributors c where c.track_id = t.id
  ), '[]'::jsonb) as contributors
from public.audio_tracks t
left join public.works w  on w.id = t.work_id
left join public.catalog_ref_audio_recording_types rt on rt.code = t.recording_type;

grant select on public.v_audio_tracklist to authenticated;
comment on view public.v_audio_tracklist is
  'Confort staff : segments d''une edition audio + titre d''oeuvre + contributeurs agreges. '
  'security_invoker=true (RLS staff de audio_tracks s''applique). OPAC public-safe = P3.';

notify pgrst, 'reload schema';

-- ============================================================================
-- 6) Verification (bloc DO ; rollback auto si manquant)
-- ============================================================================
do $$
declare v_missing text := '';
begin
  if to_regclass('public.catalog_ref_audio_recording_types') is null then v_missing := v_missing||' ref-table'; end if;
  if to_regclass('public.audio_tracks') is null then v_missing := v_missing||' audio_tracks'; end if;
  if to_regclass('public.audio_track_contributors') is null then v_missing := v_missing||' audio_track_contributors'; end if;
  if to_regclass('public.v_audio_tracklist') is null then v_missing := v_missing||' v_audio_tracklist'; end if;
  if (select count(*) from public.catalog_ref_audio_recording_types) < 6 then v_missing := v_missing||' ref-seed'; end if;
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='api' and p.proname='audio_track_upsert') then v_missing := v_missing||' api.audio_track_upsert'; end if;
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='api' and p.proname='audio_track_delete') then v_missing := v_missing||' api.audio_track_delete'; end if;
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='api' and p.proname='audio_track_contributor_add') then v_missing := v_missing||' api.audio_track_contributor_add'; end if;
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='api' and p.proname='audio_track_contributor_remove') then v_missing := v_missing||' api.audio_track_contributor_remove'; end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='audio_tracks' and policyname='audio_tracks_read_staff') then v_missing := v_missing||' rls-tracks'; end if;

  if v_missing <> '' then
    raise exception 'AUDIO P1 — objets manquants :%', v_missing;
  end if;
  raise notice 'AUDIO P1 OK — ref(seed) + audio_tracks + audio_track_contributors + 4 RPC + vue en place.';
end $$;

commit;
