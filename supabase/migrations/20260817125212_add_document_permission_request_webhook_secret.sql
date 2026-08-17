-- Secret d'appel de l'Edge Function notify-document-permission-request.
--
-- Anomalie corrigee : WEBHOOK_SECRET_NOTIFY_DOCUMENT_PERMISSION_REQUEST existait
-- cote Edge Functions mais n'avait JAMAIS ete cree dans le Vault. Or
-- fn_enqueue_document_permission_request_notification() lit ce secret dans le
-- Vault et leve « raise exception ... introuvable dans vault » s'il est absent :
-- l'exception annule la transaction, donc l'insert dans
-- document_permission_request_notification_events est annule lui aussi.
-- Constat en prod avant correction : 1 demande reelle, 0 event de notification.
-- Le flux etait donc mort depuis l'origine.
--
-- Anterieur au durcissement de authorizeWebhook du 2026-08-17 (commit 406bf9bfe) :
-- ce dispatcher n'a jamais envoye ni `manual_test` ni en-tete Authorization, il
-- lui a toujours fallu le secret. Ce n'est pas une regression de ce durcissement.
--
-- La valeur est generee ici (gen_random_bytes) et n'apparait donc pas dans ce
-- fichier. Elle doit etre posee A L'IDENTIQUE cote Edge Functions
-- (`supabase secrets set`), sans quoi la comparaison echouera en 401. Fait le
-- 2026-08-17 ; verifie en comparant le digest SHA-256 affiche par
-- `supabase secrets list` a celui de la valeur du Vault.
--
-- Garde-fou CI : le job sql-tests reconstruit le schema dans une base FRAICHE
-- ou le Vault reel n'existe pas (le stub tests/sql/_ci_setup_vault_stub.sql ne
-- pose que vault.decrypted_secrets, ni vault.secrets ni vault.create_secret()).
-- Meme convention que 20260817034637 et que les blocs autour de cron.schedule.
do $$
begin
  if not exists (select 1 from vault.secrets where name = 'WEBHOOK_SECRET_NOTIFY_DOCUMENT_PERMISSION_REQUEST') then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'WEBHOOK_SECRET_NOTIFY_DOCUMENT_PERMISSION_REQUEST',
      'Secret d''appel de l''Edge Function notify-document-permission-request. Doit etre identique au secret Edge du meme nom.'
    );
  end if;
exception
  when undefined_table or undefined_function or invalid_schema_name then
    raise notice 'Vault indisponible (CI) : creation du secret ignoree.';
end $$;
