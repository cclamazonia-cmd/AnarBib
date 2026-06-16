-- supabase/migrations/20260616200645_lettre_issues.sql
-- Lot 3 (3b+3d) — Numéros de la Lettre de la fédération : brouillon AUTO-assemblé
-- (hybride GAZ-3), édité + envoyé MANUELLEMENT par network_staff (GAZ-3/GAZ-4),
-- dispatch aux abonné·es consent_lettre=true. S'appuie sur le socle Lot 2
-- (consent_lettre, lettre_notification_outbox + trigger de dispatch, lettre_consent_tokens).
-- Doctrine DOC-OBJ-2 / DOC-RPC-3. Validé BEGIN/ROLLBACK contre la prod. Idempotent.

-- 1) Table des numéros.
create table if not exists public.lettre_issues (
  id               uuid primary key default gen_random_uuid(),
  number           int not null,
  status           text not null default 'draft' check (status in ('draft','sent')),
  intro_md         text,                                 -- intro libre staff (optionnelle)
  items            jsonb not null default '[]'::jsonb,   -- digest structuré (cercles/assemblées/gazette), éditable
  created_at       timestamptz not null default now(),
  created_by       uuid references public.profiles(id),
  sent_at          timestamptz,
  sent_by          uuid references public.profiles(id),
  recipients_count int not null default 0
);
create unique index if not exists lettre_issues_number_idx on public.lettre_issues(number);
comment on table public.lettre_issues is 'Numéros de la Lettre de la fédération (newsletter opt-in). Brouillon auto-assemblé, édité + envoyé manuellement par network_staff. Envoi = fan-out vers lettre_notification_outbox pour consent_lettre=true.';

alter table public.lettre_issues enable row level security;
-- Lecture réservée au staff réseau (UI de relecture) ; écriture via RPC DEFINER only.
drop policy if exists lettre_issues_read_staff on public.lettre_issues;
create policy lettre_issues_read_staff on public.lettre_issues
  for select to authenticated
  using (exists (select 1 from public.network_staff ns where ns.user_id = auth.uid() and ns.is_active));

-- 2) RPC — créer un brouillon AUTO-assemblé (cercles récents + assemblées à venir + dernière gazette).
create or replace function api.fn_lettre_draft_create()
returns uuid
language plpgsql
security definer
set search_path = public, api, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_number int;
  v_circles jsonb;
  v_assemblies jsonb;
  v_gazette int;
  v_items jsonb;
  v_id uuid;
begin
  if not exists (select 1 from public.network_staff ns where ns.user_id = v_uid and ns.is_active) then
    raise exception 'forbidden: network_staff only' using errcode = '42501';
  end if;

  select coalesce(max(number), 0) + 1 into v_number from public.lettre_issues;

  -- Cercles ouverts créés récemment (≤ 35 j)
  select coalesce(jsonb_agg(jsonb_build_object('kind','circle','name',c.name,'nature',c.nature) order by c.created_at desc), '[]'::jsonb)
    into v_circles
  from public.circles c
  where c.is_open and c.status = 'ativo' and c.created_at > now() - interval '35 days';

  -- Assemblées à venir (avec date programmée future)
  select coalesce(jsonb_agg(jsonb_build_object('kind','assembly','title',a.title,'scheduled_at',a.scheduled_at,'assembly_kind',a.kind) order by a.scheduled_at), '[]'::jsonb)
    into v_assemblies
  from public.assembleias a
  where a.scheduled_at is not null and a.scheduled_at > now();

  -- Dernier numéro publié de la gazette (Rizoma)
  select number into v_gazette from public.gazette_issues where status = 'published' order by number desc limit 1;

  v_items := v_circles || v_assemblies
    || (case when v_gazette is not null
             then jsonb_build_array(jsonb_build_object('kind','gazette','number',v_gazette))
             else '[]'::jsonb end);

  insert into public.lettre_issues (number, status, items, created_by)
    values (v_number, 'draft', v_items, v_uid)
    returning id into v_id;
  return v_id;
end;
$$;
revoke all on function api.fn_lettre_draft_create() from public, anon, service_role;
grant execute on function api.fn_lettre_draft_create() to authenticated;

-- 3) RPC — éditer un brouillon (intro libre + items retenus).
create or replace function api.fn_lettre_issue_update(p_id uuid, p_intro_md text, p_items jsonb)
returns void
language plpgsql
security definer
set search_path = public, api, pg_temp
as $$
declare v_uid uuid := auth.uid();
begin
  if not exists (select 1 from public.network_staff ns where ns.user_id = v_uid and ns.is_active) then
    raise exception 'forbidden: network_staff only' using errcode = '42501';
  end if;
  update public.lettre_issues
     set intro_md = p_intro_md, items = coalesce(p_items, '[]'::jsonb)
   where id = p_id and status = 'draft';
  if not found then raise exception 'brouillon introuvable ou déjà envoyé' using errcode = '22023'; end if;
end;
$$;
revoke all on function api.fn_lettre_issue_update(uuid, text, jsonb) from public, anon, service_role;
grant execute on function api.fn_lettre_issue_update(uuid, text, jsonb) to authenticated;

-- 4) RPC — envoyer un numéro : fan-out aux abonné·es (1 ligne d'outbox/personne). Idempotent.
create or replace function api.fn_lettre_issue_send(p_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, api, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_issue public.lettre_issues;
  v_count int := 0;
begin
  if not exists (select 1 from public.network_staff ns where ns.user_id = v_uid and ns.is_active) then
    raise exception 'forbidden: network_staff only' using errcode = '42501';
  end if;

  select * into v_issue from public.lettre_issues where id = p_id for update;
  if not found then raise exception 'numéro introuvable' using errcode = '22023'; end if;
  if v_issue.status = 'sent' then return 0; end if;  -- déjà envoyé : idempotent

  -- Garantir un token de désabonnement stable pour chaque abonné·e (1-clic sans login).
  insert into public.lettre_consent_tokens (user_id, action)
    select p.id, 'unsubscribe'
    from public.profiles p
    where p.consent_lettre = true and coalesce(p.email, '') <> ''
      and not exists (
        select 1 from public.lettre_consent_tokens t
        where t.user_id = p.id and t.action = 'unsubscribe' and t.consumed_at is null);

  -- Fan-out : 1 ligne d'outbox par abonné·e → le trigger de dispatch poste vers notify-event.
  with subs as (
    select p.id, p.email, p.first_name, p.preferred_language,
           (select t.token from public.lettre_consent_tokens t
             where t.user_id = p.id and t.action = 'unsubscribe' and t.consumed_at is null
             order by t.created_at desc limit 1) as unsub_token
    from public.profiles p
    where p.consent_lettre = true and coalesce(p.email, '') <> ''
  ),
  ins as (
    insert into public.lettre_notification_outbox (event, payload)
    select 'lettre.issue.sent',
           jsonb_build_object(
             'issue_id',    v_issue.id,
             'number',      v_issue.number,
             'to',          s.email,
             'to_name',     s.first_name,
             'locale',      coalesce(s.preferred_language, 'pt-BR'),
             'intro',       v_issue.intro_md,
             'items',       v_issue.items,
             'unsub_token', s.unsub_token
           )
    from subs s
    returning 1
  )
  select count(*) into v_count from ins;

  update public.lettre_issues
     set status = 'sent', sent_at = now(), sent_by = v_uid, recipients_count = v_count
   where id = p_id;
  return v_count;
end;
$$;
revoke all on function api.fn_lettre_issue_send(uuid) from public, anon, service_role;
grant execute on function api.fn_lettre_issue_send(uuid) to authenticated;

notify pgrst, 'reload schema';
