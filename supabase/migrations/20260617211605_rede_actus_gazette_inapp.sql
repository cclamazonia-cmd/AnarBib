-- =========================================================================
-- Actus réseau — Phase 2 : la Gazette crée un avis in-app au compte lecteur·rice
-- =========================================================================
-- Date     : 2026-06-17
-- Chantier : Feeding « avis & notifications » — surfacer les diffusions réseau
-- Auteur   : Claude (assistant·e)
-- Session  : Avis & notifications — feeding réseau (Phase 2 Gazette)
-- Branche  : rede-actus-notifs-inapp (hors worktree partagé)
--
-- Suite de la Phase 1 (Lettre, migration 20260617211604). Même gabarit appliqué
-- à api.fn_gazette_broadcast : en plus du fan-out e-mail STAFF existant (inchangé :
-- bibliothécaires/coordinateur·rices + network_staff), insère un avis in-app
-- (category 'rede_gazette', titre/corps = clés i18n résolues côté front, lien ->
-- /federacao/gazeta) pour TOU·TES les lecteur·rices actif·ves NON opt-out
-- (toggle « actus réseau » disable_rede_news, déjà créé en Phase 1).
--
-- Idempotent : la fonction sort tôt si published_broadcast_at est déjà posé.
-- Le front gère déjà link_type='rede_gazette' (Phase 1) -> aucun changement front.
-- =========================================================================

BEGIN;

CREATE OR REPLACE FUNCTION api.fn_gazette_broadcast(p_issue_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'api', 'pg_temp'
AS $function$
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

  -- AJOUT 17/06/2026 : fan-out AVIS IN-APP « actus réseau » -> tou·tes les
  -- lecteur·rices actif·ves non opt-out (canal par défaut, indépendant de
  -- l'audience e-mail staff ci-dessus). Une seule fois (idempotence par
  -- published_broadcast_at). Lien front -> /federacao/gazeta.
  insert into public.user_notifications (
    user_id, library_id, category, title, body, link_type, link_id, is_read
  )
  select distinct m.user_id, null::uuid, 'rede_gazette',
         'notif.rede.gazette.title', 'notif.rede.gazette.body',
         'rede_gazette', v_issue.id::text, false
  from public.user_library_memberships m
  left join public.user_notification_preferences np on np.user_id = m.user_id
  where m.status = 'active'
    and coalesce(np.disable_rede_news, false) = false;

  update public.gazette_issues set published_broadcast_at = now() where id = p_issue_id;
  return v_count;
end;
$function$;

COMMIT;
