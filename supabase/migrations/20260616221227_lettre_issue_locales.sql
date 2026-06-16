-- supabase/migrations/20260616221227_lettre_issue_locales.sql
-- Lettre v2 (L1) — Corps MULTILINGUE riche par numéro (fusion du contenu éditorial
-- Cowork dans le modèle push opt-in existant). Un numéro `lettre_issues` peut porter
-- un corps markdown par locale (`lettre_issue_locales`) ; l'e-mail rend le corps de
-- la locale du destinataire (handler L2), et les numéros ENVOYÉS sont lisibles in-app
-- (vues publiques). Si pas de corps → repli sur le digest (intro + items). Le payload
-- d'envoi reste léger (issue_id + locale) ; le handler va chercher le corps.
-- Doctrine DOC-OBJ-2 / DOC-RPC-3. Idempotent.

-- 1) Corps par locale.
create table if not exists public.lettre_issue_locales (
  id                 uuid primary key default gen_random_uuid(),
  issue_id           uuid not null references public.lettre_issues(id) on delete cascade,
  locale             text not null
                     check (locale in ('pt-BR','fr','es','en','it','de','el','ca','eo','nl')),
  title              text not null default '',
  body_md            text not null default '',   -- markdown
  translation_status text not null default 'machine'
                     check (translation_status in ('original','machine','human_reviewed')),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (issue_id, locale)
);
create index if not exists lettre_issue_locales_issue_idx on public.lettre_issue_locales(issue_id);
comment on table public.lettre_issue_locales is 'Corps markdown par locale d''un numéro de la Lettre de la fédération (10 locales). Rendu dans l''e-mail (locale du destinataire) et lisible in-app pour les numéros status=sent. Repli digest si absent.';

create or replace trigger tg_lettre_issue_locales_updated_at
  before update on public.lettre_issue_locales
  for each row execute function public.set_updated_at();

alter table public.lettre_issue_locales enable row level security;
-- Écriture staff réseau ; lecture publique des corps des numéros ENVOYÉS (lecture in-app).
drop policy if exists lettre_issue_locales_write_staff on public.lettre_issue_locales;
create policy lettre_issue_locales_write_staff on public.lettre_issue_locales
  for all to authenticated
  using (exists (select 1 from public.network_staff ns where ns.user_id = auth.uid() and ns.is_active))
  with check (exists (select 1 from public.network_staff ns where ns.user_id = auth.uid() and ns.is_active));
drop policy if exists lettre_issue_locales_read_sent on public.lettre_issue_locales;
create policy lettre_issue_locales_read_sent on public.lettre_issue_locales
  for select to anon, authenticated
  using (exists (select 1 from public.lettre_issues li where li.id = issue_id and li.status = 'sent'));
grant select on public.lettre_issue_locales to anon, authenticated;

-- 2) Lecture publique des numéros ENVOYÉS (pour l'onglet de lecture). Les brouillons
--    restent staff-only (policy lettre_issues_read_staff existante).
drop policy if exists lettre_issues_read_sent on public.lettre_issues;
create policy lettre_issues_read_sent on public.lettre_issues
  for select to anon, authenticated using (status = 'sent');
grant select on public.lettre_issues to anon, authenticated;

-- 3) Vues publiques (schéma api, security_invoker) pour l'onglet « Lettre ».
create or replace view api.lettre_public_v1
  with (security_invoker = on) as
  select id, number, sent_at
  from public.lettre_issues where status = 'sent' order by number desc;

create or replace view api.lettre_locales_public_v1
  with (security_invoker = on) as
  select ll.issue_id, li.number as issue_number,
         ll.locale, ll.title, ll.body_md, ll.translation_status, li.sent_at
  from public.lettre_issue_locales ll
  join public.lettre_issues li on li.id = ll.issue_id
  where li.status = 'sent';

grant select on api.lettre_public_v1        to anon, authenticated;
grant select on api.lettre_locales_public_v1 to anon, authenticated;

-- 4) RPC — upsert d'un corps de locale (édition staff + chargement de contenu).
create or replace function api.fn_lettre_set_locale(
  p_issue_id uuid, p_locale text, p_title text, p_body_md text, p_translation_status text default 'machine')
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
  if p_locale not in ('pt-BR','fr','es','en','it','de','el','ca','eo','nl') then
    raise exception 'locale invalide: %', p_locale using errcode = '22023';
  end if;
  insert into public.lettre_issue_locales (issue_id, locale, title, body_md, translation_status)
    values (p_issue_id, p_locale, coalesce(p_title,''), coalesce(p_body_md,''),
            coalesce(p_translation_status,'machine'))
  on conflict (issue_id, locale) do update
    set title = excluded.title, body_md = excluded.body_md,
        translation_status = excluded.translation_status;
end;
$$;
revoke all on function api.fn_lettre_set_locale(uuid, text, text, text, text) from public, anon, service_role;
grant execute on function api.fn_lettre_set_locale(uuid, text, text, text, text) to authenticated;

notify pgrst, 'reload schema';
