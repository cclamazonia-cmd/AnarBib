-- supabase/migrations/20260616210916_lettre_optin_for_user.sql
-- Lot 2b-bis — Opt-in « Lettre » au SIGNUP : variante de api.fn_lettre_request_optin
-- prenant un user_id (l'EF register tourne en service_role, pas authentifié comme
-- la personne). Déclenche le MÊME double opt-in (pending + token confirm + e-mail) ;
-- consent_lettre reste false jusqu'au clic de confirmation. Validé BEGIN/ROLLBACK
-- contre la prod. Doctrine DOC-OBJ-2. Idempotent.

create or replace function api.fn_lettre_optin_for_user(p_user_id uuid)
returns text   -- 'confirmation_sent' | 'already_subscribed' | 'no_email' | 'no_user'
language plpgsql
security definer
set search_path = public, api, pg_temp
as $$
declare
  v_email text;
  v_first text;
  v_locale text;
  v_already boolean;
  v_token uuid;
begin
  select p.email, p.first_name, p.preferred_language, p.consent_lettre
    into v_email, v_first, v_locale, v_already
  from public.profiles p where p.id = p_user_id;

  if not found then return 'no_user'; end if;
  if v_already then return 'already_subscribed'; end if;
  if coalesce(v_email, '') = '' then return 'no_email'; end if;

  update public.profiles set consent_lettre_pending_at = now() where id = p_user_id;

  delete from public.lettre_consent_tokens
    where user_id = p_user_id and action = 'confirm' and consumed_at is null;
  insert into public.lettre_consent_tokens(user_id, action, expires_at)
    values (p_user_id, 'confirm', now() + interval '7 days')
    returning token into v_token;

  insert into public.lettre_notification_outbox(event, payload)
    values ('lettre.optin.confirm', jsonb_build_object(
      'user_id', p_user_id, 'to', v_email, 'to_name', v_first,
      'locale', coalesce(v_locale, 'pt-BR'), 'token', v_token));

  return 'confirmation_sent';
end;
$$;
revoke all on function api.fn_lettre_optin_for_user(uuid) from public, anon, authenticated;
grant execute on function api.fn_lettre_optin_for_user(uuid) to service_role;

notify pgrst, 'reload schema';
