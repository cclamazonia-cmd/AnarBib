-- supabase/migrations/20260616171842_lettre_optin.sql
-- Lot 2 (paquet 2a) — Socle de données « Lettre de la fédération » (newsletter opt-in).
-- Consentement DISTINCT du transactionnel (profiles.consent_email) : base légale =
-- consentement RGPD art. 6.1.a (REGISTRE §29 GAZ-5). Double opt-in (confirmation par
-- mail) + désabonnement 1-clic par token. AUCUN envoi ici (pipeline = Lot 3).
-- Doctrine DOC-OBJ-2 / DOC-RPC-3. Idempotent.

-- 1) Consentement « lettre » sur profiles (miroir de consent_email, mais opt-in).
alter table public.profiles
  add column if not exists consent_lettre boolean not null default false,
  add column if not exists consent_lettre_at timestamptz,           -- confirmé (preuve)
  add column if not exists consent_lettre_pending_at timestamptz;   -- demandé, en attente de confirmation

comment on column public.profiles.consent_lettre is 'Abonnement à la Lettre de la fédération (opt-in, RGPD 6.1.a). true = confirmé via double opt-in. Distinct de consent_email (transactionnel, 6.1.b).';
comment on column public.profiles.consent_lettre_at is 'Horodatage de confirmation du consentement à la Lettre (preuve RGPD). NULL si non confirmé.';
comment on column public.profiles.consent_lettre_pending_at is 'Horodatage de la demande d''abonnement en attente de confirmation (double opt-in). NULL si rien en attente.';

-- 2) Tokens d'action : confirmation (double opt-in, 7 j, usage unique) + désabonnement
--    (stable, 1-clic sans login). Manipulés UNIQUEMENT via les RPC SECURITY DEFINER.
create table if not exists public.lettre_consent_tokens (
  token       uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  action      text not null check (action in ('confirm','unsubscribe')),
  created_at  timestamptz not null default now(),
  expires_at  timestamptz,            -- daté pour 'confirm' ; NULL (sans expiration) pour 'unsubscribe'
  consumed_at timestamptz
);
create index if not exists lettre_consent_tokens_user_idx on public.lettre_consent_tokens(user_id);
comment on table public.lettre_consent_tokens is 'Tokens Lettre de la fédération : ''confirm'' (double opt-in, 7 j, usage unique) et ''unsubscribe'' (stable, sans login). Accès exclusivement via RPC SECURITY DEFINER (RLS verrouillée).';

alter table public.lettre_consent_tokens enable row level security;
-- Aucune policy permissive : aucun accès direct (anon/authenticated) ; seules les RPC DEFINER agissent.

-- 3) Outbox de la Lettre (confirmation d'opt-in en 2c ; envois de numéros en Lot 3).
--    Mêmes colonnes que gazette_submission_notification_outbox (consommée par notify-event).
create table if not exists public.lettre_notification_outbox (
  id         bigint generated always as identity primary key,
  event      text not null,
  payload    jsonb not null default '{}'::jsonb,
  status     text not null default 'queued' check (status in ('queued','sent','failed','skipped')),
  last_error text,
  created_at timestamptz not null default now(),
  sent_at    timestamptz
);
create index if not exists lettre_notification_outbox_queued_idx on public.lettre_notification_outbox(status) where status = 'queued';
comment on table public.lettre_notification_outbox is 'File d''envois e-mail de la Lettre de la fédération (confirmation opt-in, numéros). Alimentée par RPC DEFINER, consommée par notify-event (service_role). RLS verrouillée.';

alter table public.lettre_notification_outbox enable row level security;
-- Aucune policy permissive : alimentée par RPC DEFINER, lue par service_role (EF).

-- 4) RPC — lecture de mon état d'abonnement (pour /conta).
create or replace function api.fn_get_my_lettre_consent()
returns table (consent_lettre boolean, pending boolean)
language sql
security definer
set search_path = public, api, pg_temp
as $$
  select p.consent_lettre,
         (p.consent_lettre_pending_at is not null and not p.consent_lettre) as pending
  from public.profiles p
  where p.id = auth.uid();
$$;
revoke all on function api.fn_get_my_lettre_consent() from public, anon, service_role;
grant execute on function api.fn_get_my_lettre_consent() to authenticated;

-- 5) RPC — demander l'abonnement (étape 1 du double opt-in). Pose 'pending' + token
--    'confirm' + enfile l'e-mail de confirmation (envoi = handler 2c). Idempotent.
create or replace function api.fn_lettre_request_optin()
returns text   -- 'already_subscribed' | 'confirmation_sent'
language plpgsql
security definer
set search_path = public, api, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_first text;
  v_locale text;
  v_already boolean;
  v_token uuid;
begin
  if v_uid is null then raise exception 'not authenticated' using errcode = '42501'; end if;

  select p.email, p.first_name, p.preferred_language, p.consent_lettre
    into v_email, v_first, v_locale, v_already
  from public.profiles p where p.id = v_uid;

  if v_already then return 'already_subscribed'; end if;
  if coalesce(v_email,'') = '' then raise exception 'no email on profile' using errcode = '22023'; end if;

  update public.profiles set consent_lettre_pending_at = now() where id = v_uid;

  -- un seul token 'confirm' actif à la fois
  delete from public.lettre_consent_tokens
    where user_id = v_uid and action = 'confirm' and consumed_at is null;
  insert into public.lettre_consent_tokens(user_id, action, expires_at)
    values (v_uid, 'confirm', now() + interval '7 days')
    returning token into v_token;

  insert into public.lettre_notification_outbox(event, payload)
    values ('lettre.optin.confirm', jsonb_build_object(
      'user_id', v_uid, 'to', v_email, 'to_name', v_first,
      'locale', coalesce(v_locale, 'pt-BR'), 'token', v_token));

  return 'confirmation_sent';
end;
$$;
revoke all on function api.fn_lettre_request_optin() from public, anon, service_role;
grant execute on function api.fn_lettre_request_optin() to authenticated;

-- 6) RPC — confirmer l'abonnement (étape 2, appelée par l'EF publique via token).
create or replace function api.fn_lettre_confirm(p_token uuid)
returns text   -- 'confirmed' | 'already' | 'expired' | 'invalid'
language plpgsql
security definer
set search_path = public, api, pg_temp
as $$
declare
  v_user uuid;
  v_exp timestamptz;
  v_consumed timestamptz;
begin
  select user_id, expires_at, consumed_at into v_user, v_exp, v_consumed
  from public.lettre_consent_tokens where token = p_token and action = 'confirm';
  if not found then return 'invalid'; end if;
  if v_consumed is not null then return 'already'; end if;
  if v_exp is not null and v_exp < now() then return 'expired'; end if;

  update public.profiles
    set consent_lettre = true, consent_lettre_at = now(), consent_lettre_pending_at = null
    where id = v_user;
  update public.lettre_consent_tokens set consumed_at = now() where token = p_token;

  -- token de désabonnement stable (réutilisable dans chaque envoi)
  if not exists (
    select 1 from public.lettre_consent_tokens
    where user_id = v_user and action = 'unsubscribe' and consumed_at is null
  ) then
    insert into public.lettre_consent_tokens(user_id, action) values (v_user, 'unsubscribe');
  end if;

  return 'confirmed';
end;
$$;
revoke all on function api.fn_lettre_confirm(uuid) from public, anon, authenticated;
grant execute on function api.fn_lettre_confirm(uuid) to service_role;

-- 7) RPC — se désabonner en 1 clic (token stable, appelée par l'EF publique, sans login).
create or replace function api.fn_lettre_unsubscribe(p_token uuid)
returns text   -- 'unsubscribed' | 'invalid'
language plpgsql
security definer
set search_path = public, api, pg_temp
as $$
declare v_user uuid;
begin
  select user_id into v_user
  from public.lettre_consent_tokens where token = p_token and action = 'unsubscribe';
  if not found then return 'invalid'; end if;

  update public.profiles
    set consent_lettre = false, consent_lettre_pending_at = null
    where id = v_user;
  -- consent_lettre_at conservé (trace de l'historique de consentement) ; le flag false stoppe l'envoi.
  return 'unsubscribed';
end;
$$;
revoke all on function api.fn_lettre_unsubscribe(uuid) from public, anon, authenticated;
grant execute on function api.fn_lettre_unsubscribe(uuid) to service_role;

-- 8) RPC — annuler/se désabonner depuis /conta (connecté·e, sans token).
create or replace function api.fn_lettre_cancel()
returns void
language plpgsql
security definer
set search_path = public, api, pg_temp
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  update public.profiles
    set consent_lettre = false, consent_lettre_pending_at = null
    where id = v_uid;
  delete from public.lettre_consent_tokens
    where user_id = v_uid and action = 'confirm' and consumed_at is null;
end;
$$;
revoke all on function api.fn_lettre_cancel() from public, anon, service_role;
grant execute on function api.fn_lettre_cancel() to authenticated;

notify pgrst, 'reload schema';
