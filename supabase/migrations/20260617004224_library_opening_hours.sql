-- supabase/migrations/20260617004224_library_opening_hours.sql
-- Horaires d'ouverture / permanences HEBDOMADAIRES d'une bibliothèque.
-- Édité par le coordenador (onglet « Identité et fonctionnement » → section
-- « État de fonctionnement »), lu par les membres actifs (vitrine lecteur·rice).
-- slots = tableau jsonb : [{ "day": 1..7 (ISO, lundi=1), "start": "HH:MM",
-- "end": "HH:MM", "label": "…" (facultatif) }]. Doctrine DOC-OBJ-2 / DOC-RPC-3.
-- Idempotent.

create table if not exists public.library_opening_hours (
  library_id  uuid primary key references public.libraries(id) on delete cascade,
  slots       jsonb not null default '[]'::jsonb,
  public_note text,
  updated_at  timestamptz not null default now(),
  updated_by  uuid references public.profiles(id)
);
comment on table public.library_opening_hours is 'Horaires/permanences hebdomadaires d''une biblio. slots = [{day 1..7, start HH:MM, end HH:MM, label?}]. Écriture coordenador (RPC fn_upsert_library_opening_hours), lecture membres actifs.';

create or replace trigger tg_library_opening_hours_updated_at
  before update on public.library_opening_hours
  for each row execute function public.set_updated_at();

alter table public.library_opening_hours enable row level security;
-- Lecture : coordenador OU membre actif de la biblio (cohérent vitrine MYLIB, pas d'anon).
drop policy if exists library_opening_hours_read_members on public.library_opening_hours;
create policy library_opening_hours_read_members on public.library_opening_hours
  for select to authenticated
  using (
    public.user_can_manage_library(library_id)
    or exists (
      select 1 from public.user_library_memberships m
      where m.library_id = library_opening_hours.library_id
        and m.user_id = auth.uid() and m.status = 'active'
    )
  );
grant select on public.library_opening_hours to authenticated;
-- Écriture : via la RPC SECURITY DEFINER uniquement (aucune policy permissive).

-- RPC d'upsert (gardée coordenador = user_can_manage_library).
create or replace function api.fn_upsert_library_opening_hours(
  p_library_id uuid, p_slots jsonb, p_public_note text default null)
returns void
language plpgsql
security definer
set search_path = public, api, pg_temp
as $$
begin
  if not public.user_can_manage_library(p_library_id) then
    raise exception 'forbidden: coordenador only' using errcode = '42501';
  end if;
  if p_slots is not null and jsonb_typeof(p_slots) <> 'array' then
    raise exception 'slots doit être un tableau jsonb' using errcode = '22023';
  end if;
  insert into public.library_opening_hours (library_id, slots, public_note, updated_by)
    values (p_library_id, coalesce(p_slots, '[]'::jsonb),
            nullif(btrim(coalesce(p_public_note, '')), ''), auth.uid())
  on conflict (library_id) do update
    set slots = excluded.slots, public_note = excluded.public_note, updated_by = excluded.updated_by;
end;
$$;
revoke all on function api.fn_upsert_library_opening_hours(uuid, jsonb, text) from public, anon, service_role;
grant execute on function api.fn_upsert_library_opening_hours(uuid, jsonb, text) to authenticated;

notify pgrst, 'reload schema';
