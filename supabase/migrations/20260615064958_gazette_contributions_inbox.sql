-- supabase/migrations/20260615064958_gazette_contributions_inbox.sql
-- Version FIGÉE = 20260615064958 (horodatage déjà enregistré côté distant via apply_migration).
-- Reconstruit le DDL COMPLET réellement appliqué (le distant n'a journalisé qu'1 statement).
-- Idempotent : sûr pour une reconstruction de DB à neuf depuis migrations/.

-- 1) Soumissions
create table if not exists public.gazette_submissions (
  id                      uuid primary key default gen_random_uuid(),
  rubric                  text not null
                          check (rubric in ('une','reseau','luttes','international','cultures','agenda','autre')),
  locale                  text
                          check (locale is null or locale in ('pt-BR','fr','es','en','it','de','el','ca','eo','nl')),
  title                   text not null check (length(btrim(title)) between 2 and 200),
  body                    text not null check (length(btrim(body)) between 2 and 6000),
  link                    text,
  event_date              date,
  contributor_name        text,
  contributor_collective  text,
  contributor_email       text,
  target_issue_number     integer,
  status                  text not null default 'new'
                          check (status in ('new','accepted','rejected','published')),
  reviewed_by             uuid references public.profiles(id),
  review_note             text,
  source_ip_hash          text,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);
comment on table public.gazette_submissions is
 'Contributions ouvertes à la Gazette (toutes rubriques). Insertion via Edge Function publique submit-gazette-contribution (service_role, rate-limité). Triage par network_staff. Notif → fede@anarbib.org via outbox + notify-event.';

create index if not exists gazette_submissions_status_idx on public.gazette_submissions(status, created_at desc);
create index if not exists gazette_submissions_rubric_idx on public.gazette_submissions(rubric);

create or replace trigger tg_gazette_submissions_updated_at
  before update on public.gazette_submissions
  for each row execute function public.set_updated_at();

-- 2) Outbox de notification (forme identique à team_notification_outbox)
create table if not exists public.gazette_submission_notification_outbox (
  id                bigint generated always as identity primary key,
  event             text not null,
  payload           jsonb not null default '{}'::jsonb,
  status            text not null default 'queued' check (status in ('queued','sent','failed')),
  pg_net_request_id bigint,
  attempts          integer not null default 0,
  last_error        text,
  created_at        timestamptz not null default now(),
  sent_at           timestamptz
);
comment on table public.gazette_submission_notification_outbox is
 'File d''événements de contribution Gazette (1 ligne par event). Consommée par le dispatcher notify-event. Destinataire réseau : fede@anarbib.org.';

create index if not exists gazette_submission_outbox_status_idx
  on public.gazette_submission_notification_outbox(status, created_at);

-- 3) Enqueue automatique à chaque nouvelle contribution
create or replace function public.fn_gazette_submission_enqueue()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  insert into public.gazette_submission_notification_outbox(event, payload)
  values ('gazette.contribution.received',
    jsonb_build_object('to','fede@anarbib.org','submission_id',new.id,'rubric',new.rubric,
      'locale',new.locale,'title',new.title,'excerpt',left(new.body,280),'link',new.link,
      'event_date',new.event_date,'contributor_name',new.contributor_name,
      'contributor_collective',new.contributor_collective,'contributor_email',new.contributor_email,
      'created_at',new.created_at));
  return new;
end;$fn$;

create or replace trigger tg_gazette_submission_enqueue
  after insert on public.gazette_submissions
  for each row execute function public.fn_gazette_submission_enqueue();

-- 4) RLS
alter table public.gazette_submissions enable row level security;
alter table public.gazette_submission_notification_outbox enable row level security;
-- Outbox : aucune policy (accès service_role/dispatcher uniquement).

drop policy if exists gazette_submissions_read_network_staff on public.gazette_submissions;
create policy gazette_submissions_read_network_staff on public.gazette_submissions
  for select to authenticated
  using (exists (select 1 from public.network_staff ns where ns.user_id = auth.uid() and ns.is_active));

drop policy if exists gazette_submissions_update_network_staff on public.gazette_submissions;
create policy gazette_submissions_update_network_staff on public.gazette_submissions
  for update to authenticated
  using (exists (select 1 from public.network_staff ns where ns.user_id = auth.uid() and ns.is_active))
  with check (exists (select 1 from public.network_staff ns where ns.user_id = auth.uid() and ns.is_active));
