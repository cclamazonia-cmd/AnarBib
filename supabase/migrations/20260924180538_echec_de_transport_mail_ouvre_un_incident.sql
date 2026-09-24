-- =============================================================================
-- Un échec de transport mail ouvre un incident (24/09/2026)
-- Réf. : backlog v34 F7 (second critère tenu le 24/09), DOC-SILENCE-1 cas (a),
--        décision de Xavier du 23/09/2026.
--
-- Pourquoi. `request-password-reset` répond 200 quoi qu'il arrive — c'est
-- l'anti-énumération, une décision juste qui reste. Mais quand le transport
-- refuse (clé Resend tournée ou absente, domaine suspendu), la personne lit
-- « si un compte existe, un message est parti » et rien ne part ; côté nous,
-- un console.error que personne ne lit. Plutôt qu'un cas spécial dans cette
-- fonction, le module partagé `_shared/transport/email.ts` — par lequel passent
-- désormais TOUS les envois — note chaque échec ici, et `health-probe` porte une
-- sonde structurelle de plus : un échec dans les 30 dernières minutes ouvre un
-- incident `mail_transport`, trente minutes de calme le referment. Un courriel
-- à l'ouverture, un à la clôture, comme les autres sondes.
--
-- Ce qu'on n'écrit PAS : l'adresse du destinataire. Le banc de
-- request-password-reset vérifie qu'aucune écriture ne la porte, et la règle
-- vaut pour tout le monde : libellé, nombre de destinataires, erreur expurgée
-- de toute adresse et tronquée. Rien d'autre.
--
-- Deux endroits à tenir ENSEMBLE (commentaire de la colonne `kind`,
-- migration 20260821060000) : la CHECK ci-dessous et `sondesStructurelles`
-- dans health-probe. L'un sans l'autre, l'insertion de l'incident échoue et
-- l'alerte est retenue à chaque tour.
-- =============================================================================

begin;

-- ─── 1. La table des échecs ─────────────────────────────────────────────────
create table if not exists public.mail_transport_failures (
  id           bigint generated always as identity primary key,
  occurred_at  timestamptz not null default now(),
  label        text        not null,
  recipients   integer     not null default 1,
  error        text        not null
);

comment on table public.mail_transport_failures is
  'Un enregistrement par échec de transport mail (Resend, SMTP), écrit par _shared/transport/email.ts au moment où sendEmail lève. Lu par fn_healthcheck_mail_transport() : un échec dans les 30 dernières minutes ouvre l''incident `mail_transport`. Ne porte JAMAIS l''adresse du destinataire (expurgée avant écriture). Purgée au-delà de 30 jours par health-probe.';
comment on column public.mail_transport_failures.label is
  'Le libellé passé à sendEmail (ex. weekly-report, register:welcome email, password-reset) : dit quelle fonction a échoué, jamais pour qui.';
comment on column public.mail_transport_failures.error is
  'Message d''erreur du transport, toute adresse remplacée par <adresse>, tronqué à 300 caractères.';

create index if not exists mail_transport_failures_occurred_at_idx
  on public.mail_transport_failures (occurred_at desc);

alter table public.mail_transport_failures enable row level security;

drop policy if exists mail_transport_failures_read_admin on public.mail_transport_failures;
create policy mail_transport_failures_read_admin on public.mail_transport_failures
  for select to authenticated using (fn_caller_is_network_admin());

revoke all on public.mail_transport_failures from anon;
grant select on public.mail_transport_failures to authenticated;          -- filtré par la policy
grant select, insert, delete on public.mail_transport_failures to service_role;

-- ─── 2. La sonde ────────────────────────────────────────────────────────────
-- Même forme que les autres sondes structurelles (fn_healthcheck_notifications,
-- fn_healthcheck_images_pins) : `ok` booléen, rubriques en TABLEAUX, `verifie_le`,
-- `que_faire`. health-probe nomme les rubriques non vides dans l'alerte et joint
-- le bilan brut.
create or replace function public.fn_healthcheck_mail_transport()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
declare
  v_recents jsonb;
  v_n       integer;
begin
  select coalesce(jsonb_agg(jsonb_build_object(
             'label', f.label,
             'destinataires', f.recipients,
             'erreur', f.error,
             'quand', f.occurred_at
           ) order by f.occurred_at desc), '[]'::jsonb),
         count(*)
    into v_recents, v_n
    from public.mail_transport_failures f
   where f.occurred_at > now() - interval '30 minutes';

  return jsonb_build_object(
    'ok', v_n = 0,
    'verifie_le', now(),
    'echecs_recents', v_recents,
    'que_faire', 'Lire l''erreur : une clé Resend tournée ou absente, un domaine d''envoi suspendu, un serveur SMTP qui refuse se voient ici avant que quelqu''un s''en plaigne. Le module partagé note chaque échec ; l''incident se referme de lui-même après trente minutes sans échec.'
  );
end $fn$;

comment on function public.fn_healthcheck_mail_transport() is
  'Sonde de santé du transport mail. `ok` = aucun échec de transport noté dans les 30 dernières minutes par _shared/transport/email.ts. Lecture seule ; les enregistrements ne portent aucune adresse.';

revoke all on function public.fn_healthcheck_mail_transport() from public, anon, authenticated;
grant execute on function public.fn_healthcheck_mail_transport() to service_role;

-- ─── 3. Le genre d'incident ─────────────────────────────────────────────────
alter table public.service_health_incidents
  drop constraint if exists service_health_incidents_kind_check;

alter table public.service_health_incidents
  add constraint service_health_incidents_kind_check
  check (kind = any (array[
    'service',                -- sondes HTTP du parcours public
    'backup',                 -- temoin de vie des trois flux restic
    'notifications',          -- fn_healthcheck_notifications
    'ressources_numeriques',  -- fn_healthcheck_digital_resources
    'backup_snapshot',        -- instantane non atteste (20260828234500)
    'images_pins',            -- fn_healthcheck_images_pins
    'mail_transport'          -- fn_healthcheck_mail_transport (cette migration)
  ]));

-- ─── Vérification : porte sur ce que CETTE migration fait (DOC-DEPLOY-4) ────
do $verif$
begin
  if to_regclass('public.mail_transport_failures') is null then
    raise exception 'mail_transport_failures absente';
  end if;
  if not exists (select 1 from pg_class where oid = 'public.mail_transport_failures'::regclass and relrowsecurity) then
    raise exception 'RLS non activée sur mail_transport_failures';
  end if;
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                  where n.nspname = 'public' and p.proname = 'fn_healthcheck_mail_transport') then
    raise exception 'fn_healthcheck_mail_transport absente';
  end if;
  if has_function_privilege('anon', 'public.fn_healthcheck_mail_transport()', 'execute') then
    raise exception 'fn_healthcheck_mail_transport ouverte à anon';
  end if;
  if not exists (select 1 from pg_constraint
                  where conname = 'service_health_incidents_kind_check'
                    and pg_get_constraintdef(oid) like '%mail_transport%') then
    raise exception 'la CHECK des incidents ignore mail_transport';
  end if;
end $verif$;

commit;
