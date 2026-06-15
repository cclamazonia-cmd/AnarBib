-- supabase/migrations/20260615211000_entraide_help_board.sql
-- Session : Fédération — Communs & Entraide
-- Onglet « Entraide » (Fédération) — v1 : tableau d'appels à l'aide.
-- Réseau-large, gardé STAFF (membre actif librarian/coordenador d'une biblio).
-- Le routage par cercle, le partage de catalogue scopé et le moteur wizard sont
-- des couches ultérieures (cf. docs/journal/cadrages/CADRAGE_entraide_catalogage).
-- Conforme à la charte relationnelle : on poste/répond sur SON geste, jamais de
-- surveillance ; un appel = du texte (« j'ai besoin d'aide sur X »), pas de
-- données de catalogue (le partage consenti viendra au degré 3).

-- 1) Appels à l'aide
create table if not exists public.entraide_help_requests (
  id                uuid primary key default gen_random_uuid(),
  author_user_id    uuid not null references public.profiles(id),
  author_library_id uuid references public.libraries(id),
  subject           text not null check (length(btrim(subject)) between 2 and 160),
  body              text not null check (length(btrim(body)) between 2 and 4000),
  status            text not null default 'open' check (status in ('open','resolved')),
  created_at        timestamptz not null default now(),
  resolved_at       timestamptz
);
create index if not exists entraide_requests_status_idx
  on public.entraide_help_requests(status, created_at desc);

-- 2) Réponses (« je peux aider »)
create table if not exists public.entraide_help_offers (
  id                uuid primary key default gen_random_uuid(),
  request_id        uuid not null references public.entraide_help_requests(id) on delete cascade,
  helper_user_id    uuid not null references public.profiles(id),
  helper_library_id uuid references public.libraries(id),
  message           text check (message is null or length(btrim(message)) <= 2000),
  created_at        timestamptz not null default now()
);
create index if not exists entraide_offers_request_idx
  on public.entraide_help_offers(request_id);

-- 3) RLS — gardé staff. Lecture réseau-large (tout staff voit) ; écriture par
--    l'auteur·rice / le helper de la ligne uniquement.
alter table public.entraide_help_requests enable row level security;
alter table public.entraide_help_offers   enable row level security;

create policy entraide_requests_read_staff on public.entraide_help_requests
  for select to authenticated
  using (exists (select 1 from public.user_library_memberships m
                 where m.user_id = auth.uid() and m.status = 'active'
                   and m.role in ('librarian','coordenador')));

create policy entraide_requests_insert_author on public.entraide_help_requests
  for insert to authenticated
  with check (author_user_id = auth.uid()
    and exists (select 1 from public.user_library_memberships m
                where m.user_id = auth.uid() and m.status = 'active'
                  and m.role in ('librarian','coordenador')));

create policy entraide_requests_update_author on public.entraide_help_requests
  for update to authenticated
  using (author_user_id = auth.uid())
  with check (author_user_id = auth.uid());

create policy entraide_offers_read_staff on public.entraide_help_offers
  for select to authenticated
  using (exists (select 1 from public.user_library_memberships m
                 where m.user_id = auth.uid() and m.status = 'active'
                   and m.role in ('librarian','coordenador')));

create policy entraide_offers_insert_helper on public.entraide_help_offers
  for insert to authenticated
  with check (helper_user_id = auth.uid()
    and exists (select 1 from public.user_library_memberships m
                where m.user_id = auth.uid() and m.status = 'active'
                  and m.role in ('librarian','coordenador')));

-- 4) Grants explicites (RLS gère les lignes ; anon n'a aucun accès).
grant select, insert, update on public.entraide_help_requests to authenticated;
grant select, insert          on public.entraide_help_offers   to authenticated;
revoke all on public.entraide_help_requests from anon;
revoke all on public.entraide_help_offers   from anon;

notify pgrst, 'reload schema';
