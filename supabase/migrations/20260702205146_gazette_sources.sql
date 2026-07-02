-- CHEMIN DÉPÔT : supabase/migrations/<timestamp>_gazette_sources.sql
-- À APPLIQUER VIA LE FLUX NORMAL (fichier → CI `supabase db push`). Ne pas appliquer hors-bande.
-- Registre des sources RSS de la Gazette, géré par network_staff. L'EF gazette-monthly-build
-- lit `active = true` et met à jour les colonnes de santé à chaque collecte.
-- Idempotent.

create table if not exists public.gazette_sources (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  feed_url        text not null unique,
  locale          text not null default 'mul'
                  check (locale in ('pt-BR','fr','es','en','it','de','el','ca','eo','nl','mul')),
  scope           text,
  active          boolean not null default true,
  -- santé (renseignées par l'EF à chaque run)
  last_fetched_at timestamptz,
  last_item_at    timestamptz,
  last_status     text,           -- 'ok' | 'empty' | 'error'
  last_error      text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
comment on table public.gazette_sources is
 'Sources RSS de la Gazette (registre éditable par network_staff). locale=''mul'' pour les sources internationales/multilingues. L''EF gazette-monthly-build collecte les sources active=true et met à jour last_fetched_at / last_item_at / last_status.';

create index if not exists gazette_sources_active_idx on public.gazette_sources(active) where active;

create or replace trigger tg_gazette_sources_updated_at
  before update on public.gazette_sources
  for each row execute function public.set_updated_at();

-- RLS : gestion réservée à l'équipe réseau active (l'EF passe en service_role, hors RLS).
alter table public.gazette_sources enable row level security;

drop policy if exists gazette_sources_read_network_staff on public.gazette_sources;
create policy gazette_sources_read_network_staff on public.gazette_sources
  for select to authenticated
  using (exists (select 1 from public.network_staff ns where ns.user_id = auth.uid() and ns.is_active));

drop policy if exists gazette_sources_write_network_staff on public.gazette_sources;
create policy gazette_sources_write_network_staff on public.gazette_sources
  for all to authenticated
  using (exists (select 1 from public.network_staff ns where ns.user_id = auth.uid() and ns.is_active))
  with check (exists (select 1 from public.network_staff ns where ns.user_id = auth.uid() and ns.is_active));

-- Seed de démarrage (1 source par locale + 2 internationales + les 2 d'origine).
-- À ajuster librement ensuite depuis le panel. on conflict = rejouable.
insert into public.gazette_sources (name, feed_url, locale, scope) values
  ('Info Libertaire',                 'https://www.infolibertaire.net/feed/',                 'fr',    'France / agrégateur'),
  ('Notícias Anarquistas (ANA)',      'https://noticiasanarquistas.noblogs.org/feed/',        'pt-BR', 'Brésil / lusophone'),
  ('Alasbarricadas',                  'https://www.alasbarricadas.org/noticias/?q=rss.xml',   'es',    'Espagne / intl hispanophone'),
  ('It''s Going Down',                'https://itsgoingdown.org/feed/',                       'en',    'Amérique du Nord'),
  ('Umanità Nova',                    'https://umanitanova.org/feed/',                        'it',    'Italie (hebdo FAI)'),
  ('de.indymedia',                    'https://de.indymedia.org/rss.xml',                     'de',    'Allemagne'),
  ('Athens Indymedia',               'https://athens.indymedia.org/feed/',                   'el',    'Grèce'),
  ('Anarquia.cat',                    'https://www.anarquia.cat/feed/',                       'ca',    'Catalogne'),
  ('Anarchistische Federatie NL',     'https://www.anarchistischefederatie.nl/feed/',         'nl',    'Pays-Bas'),
  ('Anarkio — Esperanto',             'https://anarkio.net/category/esperanto/feed/',         'eo',    'Espéranto (articles originaux)'),
  ('Anarchist News',                  'https://anarchistnews.org/rss.xml',                    'mul',   'International (EN)'),
  ('CrimethInc.',                     'https://crimethinc.com/feed',                          'mul',   'International (EN)')
on conflict (feed_url) do nothing;
