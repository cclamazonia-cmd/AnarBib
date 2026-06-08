-- ============================================================================
-- EA-13 (chantier-cadre Biblioteca, etape 8) -- Envoi a la demande du rapport
-- hebdomadaire d'une bibliotheque.
-- ----------------------------------------------------------------------------
-- Auteur  : Claude (Opus 4.8) pour Xavier Van Welden
-- Session : Biblioteca etape 8 -- cablage mails
-- Date    : 2026-06-08 (UTC 20260607235814)
-- ----------------------------------------------------------------------------
-- Remplace le placeholder `mailto:` du bouton "Enviar relatorio" du Painel par
-- un declenchement SERVEUR de l'Edge Function notify-weekly-report (envoi reel
-- via Resend), debloque par la cloture de la migration #110 (Brevo -> Resend).
--
-- Calque strictement sur public.fn_cron_notify_weekly_report_per_library()
-- (meme secret vault, meme net.http_post, meme corps), mais :
--   - cible UNE seule bibliotheque (p_library_id) au lieu de boucler sur toutes ;
--   - ajoute un GARDE-FOU d'autorisation : seul le staff habilite a gerer les
--     notifications de CETTE biblio peut declencher l'envoi (la RPC est appelee
--     par le frontend authentifie, qui ne doit pas pouvoir viser une autre biblio) ;
--   - trace l'initiateur (initiated_by) et marque source='manual'.
--
-- Semaine couverte : semaine ISO complete precedente (fn_internal_previous_iso_week),
-- identique au digest automatique du lundi -- coherence de l'artefact "rapport
-- hebdomadaire". Le destinataire est resolu cote EF sur weekly_report_email.
-- ============================================================================

create or replace function public.fn_send_weekly_report_now(p_library_id uuid)
  returns bigint
  language plpgsql
  security definer
  set search_path to 'public', 'vault', 'extensions', 'pg_temp'
as $function$
declare
  v_url    text;
  v_secret text;
  v_week   record;
  v_active boolean;
  v_req_id bigint;
begin
  if p_library_id is null then
    raise exception 'library_id_required';
  end if;

  -- Garde-fou d'autorisation (la RPC est exposee au frontend authentifie).
  if not public.user_can_manage_library_notifications(p_library_id) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  select l.is_active into v_active
  from public.libraries l
  where l.id = p_library_id;

  if v_active is null then
    raise exception 'library_not_found';
  end if;
  if v_active is not true then
    raise exception 'library_inactive';
  end if;

  v_url := regexp_replace(
    public.fn_internal_get_vault_secret('SUPABASE_URL'),
    '/+$', ''
  ) || '/functions/v1/notify-weekly-report';

  v_secret := public.fn_internal_get_vault_secret('WEBHOOK_SECRET_NOTIFY_WEEKLY_REPORT');

  select * into v_week from public.fn_internal_previous_iso_week();

  v_req_id := net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', v_secret
    ),
    body := jsonb_build_object(
      'source', 'manual',
      'job', 'fn_send_weekly_report_now',
      'scheduled_at', now(),
      'initiated_by', auth.uid()::text,
      'library_id', p_library_id::text,
      'week_start', to_char(v_week.week_start, 'YYYY-MM-DD'),
      'week_end',   to_char(v_week.week_end,   'YYYY-MM-DD'),
      'tz', 'UTC'
    ),
    timeout_milliseconds := 60000
  );

  return v_req_id;
end;
$function$;

revoke execute on function public.fn_send_weekly_report_now(uuid) from public;
grant execute on function public.fn_send_weekly_report_now(uuid) to authenticated;

comment on function public.fn_send_weekly_report_now(uuid) is
  'EA-13 (etape 8 Biblioteca, 08/06/2026) : envoi a la demande du rapport hebdomadaire (semaine ISO precedente) d''une bibliotheque via l''Edge Function notify-weekly-report (Resend). Calque sur fn_cron_notify_weekly_report_per_library, restreint a une biblio + garde-fou user_can_manage_library_notifications. Declenchee par le bouton Enviar relatorio du Painel.';
