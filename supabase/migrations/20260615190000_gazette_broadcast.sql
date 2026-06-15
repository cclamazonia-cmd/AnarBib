-- supabase/migrations/20260615190000_gazette_broadcast.sql
-- Étape C — diffusion d'un numéro publié à tout le staff (bouton « Diffuser »).
-- Additif. Idempotence + RPC d'énumération/fan-out gardé network_staff.
-- L'envoi réel passe par l'outbox gazette + le trigger de dispatch (Étape A) :
-- 1 ligne d'outbox par destinataire → 1 mail indépendant (event gazette.issue.published).

-- 1) Marqueur d'idempotence (1 diffusion par numéro).
alter table public.gazette_issues
  add column if not exists published_broadcast_at timestamptz;

-- 2) RPC de diffusion. SECURITY DEFINER (énumère profils/memberships avec autorité),
--    mais GARDÉ network_staff. Audience = staff (librarian/coordenador) des biblios
--    ACTIVES dont le canal mail n'est pas désactivé (kill-switch), + network_staff,
--    dédupliqués par personne. 1 insert d'outbox par destinataire avec e-mail.
create or replace function api.fn_gazette_broadcast(p_issue_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, api, pg_temp
as $fn$
declare
  v_issue public.gazette_issues;
  v_count integer := 0;
begin
  -- Garde : network_staff actif uniquement.
  if not exists (select 1 from public.network_staff ns
                 where ns.user_id = auth.uid() and ns.is_active) then
    raise exception 'forbidden: network_staff only' using errcode = '42501';
  end if;

  -- Verrou ligne (sérialise les clics concurrents) + contrôles.
  select * into v_issue from public.gazette_issues where id = p_issue_id for update;
  if not found then raise exception 'gazette issue % not found', p_issue_id; end if;
  if v_issue.status <> 'published' then
    raise exception 'gazette issue % not published', p_issue_id using errcode = '22023';
  end if;
  if v_issue.published_broadcast_at is not null then
    return 0; -- déjà diffusé : idempotent, aucun nouvel envoi.
  end if;

  with included_libs as (
    select l.id
    from public.libraries l
    left join public.v_library_notification_context c on c.library_id = l.id
    where l.is_active
      and coalesce(c.channel_active, true) = true
      and coalesce(c.delivery_mode, 'platform_shared') <> 'disabled'
  ),
  recipients as (
    select distinct m.user_id
    from public.user_library_memberships m
    join included_libs il on il.id = m.library_id
    where m.status = 'active' and m.role in ('librarian','coordenador')
    union
    select ns.user_id from public.network_staff ns where ns.is_active
  ),
  enriched as (
    select p.id, p.email, p.first_name, p.preferred_language
    from recipients r
    join public.profiles p on p.id = r.user_id
    where coalesce(p.email, '') <> ''
  ),
  ins as (
    insert into public.gazette_submission_notification_outbox (event, payload)
    select 'gazette.issue.published',
           jsonb_build_object(
             'issue_number', v_issue.number,
             'to',        e.email,
             'to_name',   e.first_name,
             'locale',    coalesce(e.preferred_language, 'pt-BR')
           )
    from enriched e
    returning 1
  )
  select count(*) into v_count from ins;

  update public.gazette_issues set published_broadcast_at = now() where id = p_issue_id;
  return v_count;
end;
$fn$;

revoke all on function api.fn_gazette_broadcast(uuid) from public, anon;
grant execute on function api.fn_gazette_broadcast(uuid) to authenticated;

notify pgrst, 'reload schema';
