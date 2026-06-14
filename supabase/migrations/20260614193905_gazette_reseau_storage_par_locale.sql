-- AnarBib · Gazette du réseau : stockage par numéro et par locale
create table public.gazette_issues (
  id             uuid primary key default gen_random_uuid(),
  number         integer not null unique,
  slug           text not null unique,
  masthead_title text not null default 'AnarBib — La Gazette du réseau',
  cover_date     date not null,
  status         text not null default 'draft'
                 check (status in ('draft','published','archived')),
  published_at   timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
comment on table public.gazette_issues is
 'En-tête d''un numéro de la Gazette du réseau AnarBib (niveau réseau). Le contenu éditorial est porté par gazette_issue_locales, une ligne par locale.';

create table public.gazette_issue_locales (
  id                 uuid primary key default gen_random_uuid(),
  issue_id           uuid not null references public.gazette_issues(id) on delete cascade,
  locale             text not null
                     check (locale in ('pt-BR','fr','es','en','it','de','el','ca','eo','nl')),
  tagline            text not null default '',
  masthead           jsonb not null default '{}'::jsonb,
  content            jsonb not null default '[]'::jsonb,
  translation_status text not null default 'machine'
                     check (translation_status in ('original','machine','human_reviewed')),
  source_locale      text,
  pdf_object_path    text,
  updated_by         uuid references public.profiles(id),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (issue_id, locale)
);
comment on table public.gazette_issue_locales is
 'Contenu éditorial de la Gazette par numéro et par locale (10 locales du réseau). content = tableau des 6 pages, identique au gabarit front. Stockage par locale, peuplé/relu par les membres.';

create index gazette_issue_locales_issue_idx  on public.gazette_issue_locales(issue_id);
create index gazette_issue_locales_locale_idx on public.gazette_issue_locales(locale);

create trigger tg_gazette_issues_updated_at        before update on public.gazette_issues
  for each row execute function public.set_updated_at();
create trigger tg_gazette_issue_locales_updated_at before update on public.gazette_issue_locales
  for each row execute function public.set_updated_at();

-- RLS
alter table public.gazette_issues        enable row level security;
alter table public.gazette_issue_locales enable row level security;

-- Lecture publique des numéros publiés
create policy gazette_issues_read_published on public.gazette_issues
  for select to anon, authenticated using (status = 'published');

create policy gazette_locales_read_published on public.gazette_issue_locales
  for select to anon, authenticated
  using (exists (select 1 from public.gazette_issues i
                 where i.id = issue_id and i.status = 'published'));

-- Écriture réservée à l'équipe de coordination réseau active (network_staff)
create policy gazette_issues_write_network_staff on public.gazette_issues
  for all to authenticated
  using (exists (select 1 from public.network_staff ns
                 where ns.user_id = auth.uid() and ns.is_active))
  with check (exists (select 1 from public.network_staff ns
                 where ns.user_id = auth.uid() and ns.is_active));

create policy gazette_locales_write_network_staff on public.gazette_issue_locales
  for all to authenticated
  using (exists (select 1 from public.network_staff ns
                 where ns.user_id = auth.uid() and ns.is_active))
  with check (exists (select 1 from public.network_staff ns
                 where ns.user_id = auth.uid() and ns.is_active));

-- Vues de lecture exposées au frontend (schéma api)
create view api.gazette_issues_public_v1 as
  select id, number, slug, masthead_title, cover_date, published_at
  from public.gazette_issues where status = 'published' order by number desc;

create view api.gazette_locales_public_v1 as
  select l.issue_id, i.number as issue_number, i.cover_date,
         l.locale, l.tagline, l.masthead, l.content,
         l.translation_status, l.pdf_object_path
  from public.gazette_issue_locales l
  join public.gazette_issues i on i.id = l.issue_id
  where i.status = 'published';

grant select on api.gazette_issues_public_v1  to anon, authenticated;
grant select on api.gazette_locales_public_v1 to anon, authenticated;
