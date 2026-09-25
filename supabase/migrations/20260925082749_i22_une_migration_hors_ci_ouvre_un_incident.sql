-- =============================================================================
-- Une migration appliquée hors de la CI ouvre un incident (25/09/2026)
-- Réf. : backlog v34 I22, REGISTRE DOC-DEPLOY-1 (tranché le 25/09 :
--        « interdire et contrôler », décision de Xavier), note ⚠️ du §30.
--
-- Pourquoi. DOC-DEPLOY-1 interdit `apply_migration` (MCP), le SQL Editor avant
-- push et la CLI manuelle : `git push` → Forgejo Actions déploie tout. La règle
-- était écrite et rien ne la vérifiait. Le 07/09, un écart a été constaté après
-- coup en venant l'inscrire au registre ; le 25/09, en instruisant I22, deux
-- autres sont apparus que personne n'avait vus (20260922185953, 20260924180538).
--
-- La signature. `supabase_migrations.schema_migrations.created_by` porte le
-- compte de la personne quand une migration passe par l'API de gestion de la
-- plateforme (MCP `apply_migration`, tableau de bord) ; il reste NUL quand c'est
-- `supabase db push` de la CI qui l'inscrit. Vérifié le 25/09 sur les 335
-- versions de la production : les versions dont les commits disent « appliquée
-- par MCP » (601be0d6, cac464fd, le §30 du registre) portent un auteur, toutes
-- celles de la CI n'en portent pas.
--
-- Ce que le contrôle ne voit PAS, dit pour qu'on ne lui fasse pas dire plus :
-- une `supabase db push` lancée à la main depuis un poste (created_by nul, comme
-- la CI) et le SQL Editor (qui n'écrit rien dans ce journal ; DOC-DEPLOY-3 le
-- tolère pour le diagnostic en lecture).
--
-- Le mécanisme. Toute version signée d'un auteur et absente de
-- `deploiement_ecarts_acquittes` rend la sonde rouge ; health-probe ouvre
-- l'incident `deploiement`, un courriel à l'ouverture. Il ne se referme PAS de
-- lui-même : on l'acquitte par une MIGRATION versée au dépôt, qui insère la
-- version et le motif. L'acquittement passe donc lui-même par la CI, et la trace
-- de l'écart vit dans git — c'est la règle « tracer » de DOC-DEPLOY-1.
--
-- Les écarts antérieurs sont acquittés ici, nommément pour ceux du 20/08 au
-- 24/09 (inventaire au REGISTRE), en bloc pour ceux d'avant.
--
-- Deux endroits à tenir ENSEMBLE (commentaire de la colonne `kind`,
-- migration 20260821060000) : la CHECK ci-dessous et `sondesStructurelles`
-- dans health-probe.
-- =============================================================================

begin;

-- ─── 1. Les écarts acquittés ────────────────────────────────────────────────
create table if not exists public.deploiement_ecarts_acquittes (
  version      text        primary key,
  motif        text        not null check (length(btrim(motif)) >= 20),
  acquitte_le  timestamptz not null default now()
);

comment on table public.deploiement_ecarts_acquittes is
  'Versions de migration appliquées hors de la CI (created_by non nul dans supabase_migrations.schema_migrations) et acquittées. On n''y écrit QUE par une migration versée au dépôt : l''acquittement passe lui-même par la CI, la trace de l''écart vit dans git (DOC-DEPLOY-1, I22). Lue par fn_healthcheck_deploiement().';
comment on column public.deploiement_ecarts_acquittes.motif is
  'Pourquoi l''écart a eu lieu et où il est tracé (commit, section du registre). Vingt caractères au moins : « ok » n''est pas un motif.';

alter table public.deploiement_ecarts_acquittes enable row level security;

drop policy if exists deploiement_ecarts_acquittes_read_admin on public.deploiement_ecarts_acquittes;
create policy deploiement_ecarts_acquittes_read_admin on public.deploiement_ecarts_acquittes
  for select to authenticated using (fn_caller_is_network_admin());

revoke all on public.deploiement_ecarts_acquittes from public, anon, authenticated, service_role;
grant select on public.deploiement_ecarts_acquittes to authenticated;      -- filtré par la policy
grant select on public.deploiement_ecarts_acquittes to service_role;

-- ─── 2. La sonde ────────────────────────────────────────────────────────────
-- Même forme que les autres sondes structurelles : `ok`, rubriques en tableaux,
-- `verifie_le`, `que_faire`. Le journal des migrations est lu en SQL dynamique :
-- le banc de la CI (base neuve, sans CLI) n'a pas ce schéma, et la pile
-- auto-hébergée l'a sans la colonne `created_by`, qui est propre à la
-- plateforme. Là où la colonne manque, personne ne peut passer par l'API de
-- gestion : la sonde le dit (`controle` = 'sans_objet') et reste verte.
-- L'auteur n'est jamais rendu : la version et le nom suffisent à retrouver
-- l'écart, et le bilan part par courriel.
create or replace function public.fn_healthcheck_deploiement()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
declare
  v_ecarts jsonb;
  v_n      integer;
begin
  if not exists (
    select 1 from information_schema.columns
     where table_schema = 'supabase_migrations'
       and table_name   = 'schema_migrations'
       and column_name  = 'created_by'
  ) then
    return jsonb_build_object(
      'ok', true,
      'verifie_le', now(),
      'controle', 'sans_objet',
      'ecarts_non_acquittes', '[]'::jsonb,
      'que_faire', 'Rien : ce journal des migrations ne note pas qui applique (colonne created_by absente, propre à la plateforme hébergée). Aucune migration ne peut y passer par l''API de gestion.'
    );
  end if;

  execute $q$
    select coalesce(jsonb_agg(jsonb_build_object('version', m.version, 'nom', m.name)
                              order by m.version), '[]'::jsonb),
           count(*)::integer
      from supabase_migrations.schema_migrations m
     where m.created_by is not null
       and not exists (select 1 from public.deploiement_ecarts_acquittes a
                        where a.version = m.version)
  $q$ into v_ecarts, v_n;

  return jsonb_build_object(
    'ok', v_n = 0,
    'verifie_le', now(),
    'controle', 'actif',
    'ecarts_non_acquittes', v_ecarts,
    'que_faire', 'Une migration a été appliquée hors de la CI (MCP apply_migration ou tableau de bord), ce que DOC-DEPLOY-1 interdit. Vérifier que son fichier est au dépôt sous la MÊME version (sinon db push la rejouera ou échouera), puis verser une migration qui insère la version et le motif dans deploiement_ecarts_acquittes. L''incident reste ouvert jusque-là : il ne se referme pas de lui-même.'
  );
end $fn$;

comment on function public.fn_healthcheck_deploiement() is
  'Sonde de santé du déploiement (I22, DOC-DEPLOY-1). `ok` = aucune version de supabase_migrations.schema_migrations signée d''un auteur (created_by, API de gestion) qui ne soit acquittée dans deploiement_ecarts_acquittes. Ne rend jamais l''auteur. `controle` = sans_objet là où la colonne n''existe pas.';

revoke all on function public.fn_healthcheck_deploiement() from public, anon, authenticated;
grant execute on function public.fn_healthcheck_deploiement() to service_role;

-- ─── 3. Les écarts antérieurs, acquittés ────────────────────────────────────
insert into public.deploiement_ecarts_acquittes (version, motif) values
  ('20260820012343', 'Appliquée hors CI le 20/08 (témoin de sauvegarde), versée au dépôt sous la même version par 59b3414c ; antérieure au contrôle I22.'),
  ('20260820012512', 'Appliquée hors CI le 20/08 (plafond PDF 500 Mo), versée au dépôt sous la même version par 59b3414c ; antérieure au contrôle I22.'),
  ('20260820022615', 'Appliquée hors CI le 20/08 (visibilité publique BTL), versée au dépôt par e37390a5 ; antérieure au contrôle I22.'),
  ('20260820145716', 'Appliquée hors CI le 20/08 (tri des doublons par niveau de preuve), versée au dépôt par 2d88ba19 ; antérieure au contrôle I22.'),
  ('20260820163045', 'Appliquée par MCP le 20/08, dit dans 1a73d2ee (le fichier a pris la version attribuée) ; antérieure au contrôle I22.'),
  ('20260820165002', 'Appliquée hors CI le 20/08 (témoin de tir interrompu), versée au dépôt par 56a66edf ; antérieure au contrôle I22.'),
  ('20260831124714', 'Appliquée par MCP le 31/08, dit dans 601be0d6 (le fichier a pris la version réellement inscrite) ; antérieure au contrôle I22.'),
  ('20260831124757', 'Appliquée par MCP le 31/08, dit dans 601be0d6 (le fichier a pris la version réellement inscrite) ; antérieure au contrôle I22.'),
  ('20260831124823', 'Appliquée par MCP le 31/08, dit dans 601be0d6 (le fichier a pris la version réellement inscrite) ; antérieure au contrôle I22.'),
  ('20260904095317', 'Appliquée par MCP le 04/09, dit dans cac464fd qui la réintègre au dépôt ; antérieure au contrôle I22.'),
  ('20260907172508', 'Appliquée par MCP le 07/09, écart tracé au REGISTRE §30 (note DOC-DEPLOY-1) ; antérieure au contrôle I22.'),
  ('20260922185953', 'Appliquée hors CI le 22/09 SANS trace (sonde des notifications, délai de grâce, 0dfb9948) ; relevée par I22 le 25/09, inventaire au REGISTRE DOC-DEPLOY-1.'),
  ('20260924180538', 'Appliquée hors CI le 24/09 SANS trace (échec de transport mail, 91475d06) ; relevée par I22 le 25/09, inventaire au REGISTRE DOC-DEPLOY-1.')
on conflict (version) do nothing;

-- Celles d'avant le 20/08 (période des premières semaines, avant que la CI ne
-- déploie tout) : en bloc, là où le journal note l'auteur.
do $acquitter$
begin
  if exists (select 1 from information_schema.columns
              where table_schema = 'supabase_migrations'
                and table_name   = 'schema_migrations'
                and column_name  = 'created_by') then
    execute $q$
      insert into public.deploiement_ecarts_acquittes (version, motif)
      select m.version, 'Appliquée hors CI avant le 20/08/2026, antérieure au contrôle I22 ; acquittée en bloc le 25/09.'
        from supabase_migrations.schema_migrations m
       where m.created_by is not null and m.version < '20260820'
      on conflict (version) do nothing
    $q$;
  end if;
end $acquitter$;

-- ─── 4. Le genre d'incident ─────────────────────────────────────────────────
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
    'mail_transport',         -- fn_healthcheck_mail_transport (20260924180538)
    'deploiement'             -- fn_healthcheck_deploiement (cette migration)
  ]));

-- ─── Vérification : porte sur ce que CETTE migration fait (DOC-DEPLOY-4) ────
do $verif$
declare
  v_bilan jsonb;
begin
  if not exists (select 1 from pg_class where oid = 'public.deploiement_ecarts_acquittes'::regclass and relrowsecurity) then
    raise exception 'RLS non activée sur deploiement_ecarts_acquittes';
  end if;
  if has_function_privilege('anon', 'public.fn_healthcheck_deploiement()', 'execute')
     or has_function_privilege('authenticated', 'public.fn_healthcheck_deploiement()', 'execute') then
    raise exception 'fn_healthcheck_deploiement ouverte à anon ou authenticated';
  end if;
  if not exists (select 1 from pg_constraint
                  where conname = 'service_health_incidents_kind_check'
                    and pg_get_constraintdef(oid) like '%deploiement%') then
    raise exception 'la CHECK des incidents ignore deploiement';
  end if;
  -- Cette migration passe par la CI : après elle, plus rien d'antérieur ne
  -- doit rester non acquitté.
  v_bilan := public.fn_healthcheck_deploiement();
  if (v_bilan->>'ok')::boolean is not true then
    raise exception 'écarts antérieurs non acquittés : %', v_bilan->'ecarts_non_acquittes';
  end if;
end $verif$;

commit;
