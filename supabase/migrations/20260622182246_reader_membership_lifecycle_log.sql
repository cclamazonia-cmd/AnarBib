-- =========================================================================
-- Journal de cycle de vie des adhésions lecteur·ices (churn pour les rapports)
-- =========================================================================
-- Date     : 2026-06-22
-- Chantier : relatórios semanais — inscriptions et départs de lecteur·ices
-- Auteur   : Claude (MCP Supabase) — appliquée d'abord sur staging, réintégrée au repo
--
-- Contexte : les relatórios semanais (par bibliothèque et réseau) ne reflétaient
-- ni les inscriptions ni les départs de lecteur·ices. Les inscriptions étaient
-- déjà traçables (membership_validation_log / created_at), mais AUCUNE date de
-- sortie n'existait : une adhésion qui se termine passe seulement à un statut
-- terminal, sans horodatage fiable (updated_at = dernière modif quelconque).
-- On ajoute donc un journal IMMUTABLE des transitions de statut des adhésions
-- role='reader', alimenté par trigger, qui donne une date EXACTE pour chaque
-- inscription / réactivation / départ.
--
-- Cas piège géré : la promotion d'un lecteur en librarian clôt son adhésion
-- reader (active -> removed). Le trigger détecte le membership staff actif
-- concomitant et classe l'événement 'promocao' (exclu des départs), pour que le
-- compteur de départs reste juste.
--
-- Doctrine : table d'audit immutable (cf. library_profile_history) — INSERT via
-- trigger SECURITY DEFINER, RLS lecture staff de la biblio, trigger bloquant
-- les UPDATE. Idempotent (IF NOT EXISTS + guards pg_policies/pg_trigger).
-- Pas de backfill : ne capte que les événements à partir du 2026-06-22.
-- =========================================================================

-- Journal immutable des transitions de statut des adhésions role='reader'.
-- Source des inscriptions/départs de lecteur·ices dans les relatórios semanais.
create table if not exists public.reader_membership_events (
  id            uuid primary key default gen_random_uuid(),
  membership_id uuid not null references public.user_library_memberships(id) on delete cascade,
  library_id    uuid not null references public.libraries(id) on delete cascade,
  user_id       uuid not null,
  role          text not null,
  old_status    text,
  new_status    text not null,
  event_type    text not null check (event_type in ('solicitacao','inscricao','reativacao','saida','promocao','outro')),
  actor_user_id uuid,
  changed_at    timestamptz not null default now()
);

comment on table public.reader_membership_events is 'Journal immutable des transitions de statut des adhesions role=reader (INSERT only via trigger). Source des inscriptions/departs de lecteur-ices dans les relatorios semanais (notify-weekly-report / notify-network-weekly-report). Pas de backfill : evenements a partir du 2026-06-22.';

create index if not exists idx_rme_library_event_changed on public.reader_membership_events (library_id, event_type, changed_at);
create index if not exists idx_rme_changed_at on public.reader_membership_events (changed_at);

alter table public.reader_membership_events enable row level security;
grant select on public.reader_membership_events to authenticated;
grant all on public.reader_membership_events to service_role;

do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='reader_membership_events' and policyname='rme_read_staff') then
    create policy rme_read_staff on public.reader_membership_events
      for select to authenticated
      using (exists (select 1 from public.user_library_memberships m
                     where m.user_id = auth.uid()
                       and m.library_id = reader_membership_events.library_id
                       and m.role in ('librarian','coordenador')
                       and m.status = 'active'));
  end if;
end $$;

create or replace function public.fn_log_reader_membership_event()
  returns trigger language plpgsql security definer set search_path to 'public','pg_temp'
as $$
declare
  v_old text := null;
  v_event text;
  v_terminal constant text[] := array['removed','inactive','terminated','left_with_pending_circulation'];
  v_is_promotion boolean := false;
begin
  if new.role <> 'reader' then
    return null;
  end if;
  if tg_op = 'UPDATE' then
    if new.status is not distinct from old.status then
      return null;
    end if;
    v_old := old.status;
  end if;

  if new.status = 'active' and (v_old is null or v_old = 'pending_validation') then
    v_event := 'inscricao';
  elsif new.status = 'active' and v_old = any(v_terminal) then
    v_event := 'reativacao';
  elsif new.status = any(v_terminal) and (v_old is null or not (v_old = any(v_terminal))) then
    select exists (select 1 from public.user_library_memberships s
                   where s.user_id = new.user_id and s.library_id = new.library_id
                     and s.role <> 'reader' and s.status = 'active')
      into v_is_promotion;
    v_event := case when v_is_promotion then 'promocao' else 'saida' end;
  elsif new.status = 'pending_validation' then
    v_event := 'solicitacao';
  else
    v_event := 'outro';
  end if;

  insert into public.reader_membership_events
    (membership_id, library_id, user_id, role, old_status, new_status, event_type, actor_user_id)
  values
    (new.id, new.library_id, new.user_id, new.role, v_old, new.status, v_event, auth.uid());

  return null;
end;
$$;

alter function public.fn_log_reader_membership_event() owner to postgres;

do $$ begin
  if not exists (select 1 from pg_trigger where tgname = 'trg_log_reader_membership_event') then
    create trigger trg_log_reader_membership_event
      after insert or update of status on public.user_library_memberships
      for each row execute function public.fn_log_reader_membership_event();
  end if;
end $$;

create or replace function public.fn_block_rme_modification()
  returns trigger language plpgsql as $$
begin
  raise exception 'reader_membership_events is immutable: % blocked', tg_op
    using errcode = '42501', hint = 'Table audit immutable. Aucune modification possible.';
end;
$$;

alter function public.fn_block_rme_modification() owner to postgres;

do $$ begin
  if not exists (select 1 from pg_trigger where tgname = 'trg_block_rme_modification') then
    create trigger trg_block_rme_modification
      before update on public.reader_membership_events
      for each row execute function public.fn_block_rme_modification();
  end if;
end $$;

notify pgrst, 'reload schema';
