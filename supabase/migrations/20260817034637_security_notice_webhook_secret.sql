-- Secret d'appel de l'Edge Function notify-security-notice.
--
-- Meme convention que les autres notifieurs : la valeur vit dans le Vault et
-- l'appelant la passe en en-tete x-webhook-secret. Difference : la fonction
-- n'accepte AUCUN repli sur un simple Bearer (cf. commentaire en tete de
-- l'Edge Function), et la verification se fait ici, cote base, par une
-- fonction qui ne renvoie qu'un booleen.
--
-- Contexte : le helper partage authorizeWebhook() autorise
-- `webhookOk || bearerOk`, donc n'importe quel Bearer bien forme suffit a
-- appeler les notifieurs existants. On ne le reutilise pas ici. Ce point est
-- a traiter separement pour les autres fonctions.

-- Garde-fou CI. Le job sql-tests reconstruit le schema dans une base FRAICHE
-- qui n'herite pas des extensions : le Vault reel n'existe pas. Le stub
-- tests/sql/_ci_setup_vault_stub.sql ne pose que vault.decrypted_secrets, ni
-- vault.secrets ni vault.create_secret(). Sans ce bloc, la migration echoue en
-- CI avec « relation vault.secrets does not exist » (42P01). Meme convention
-- que les blocs DO/EXCEPTION autour de cron.schedule.
do $$
begin
  if not exists (select 1 from vault.secrets where name = 'WEBHOOK_SECRET_NOTIFY_SECURITY_NOTICE') then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'WEBHOOK_SECRET_NOTIFY_SECURITY_NOTICE',
      'Secret d''appel de l''Edge Function notify-security-notice (avis de securite aux membres).'
    );
  end if;
exception
  when undefined_table or undefined_function or invalid_schema_name then
    raise notice 'Vault indisponible (CI) : creation du secret ignoree. fn_check_security_notice_secret renverra false.';
end $$;

-- Comparaison du secret fourni avec celui du Vault. Ne renvoie jamais la valeur.
create or replace function public.fn_check_security_notice_secret(p_secret text)
returns boolean
language plpgsql
stable
security definer
set search_path to 'public', 'vault', 'pg_temp'
as $$
declare
  v_expected text;
begin
  if p_secret is null or length(btrim(p_secret)) = 0 then
    return false;
  end if;

  select decrypted_secret into v_expected
  from vault.decrypted_secrets
  where name = 'WEBHOOK_SECRET_NOTIFY_SECURITY_NOTICE';

  if v_expected is null or length(v_expected) = 0 then
    return false;
  end if;

  return btrim(p_secret) = v_expected;
end $$;

comment on function public.fn_check_security_notice_secret(text) is
  'Verifie le secret d''appel de notify-security-notice contre le Vault. Ne renvoie qu''un booleen, jamais la valeur.';

revoke all on function public.fn_check_security_notice_secret(text) from public, anon, authenticated;
grant execute on function public.fn_check_security_notice_secret(text) to service_role;
