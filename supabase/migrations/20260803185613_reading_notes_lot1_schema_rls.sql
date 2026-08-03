-- =========================================================================
-- Notes de lecture partagees sur les oeuvres — Lot 1 (couche SQL).
-- Cadrage : docs/journal/cadrages/CADRAGE_notes_de_lecture_2026-08-01.md
-- Adopte en AG BLMF. Aucune surface frontend ici (Lots 2-3) : ce lot pose le
-- modele de donnees + RLS + garde-fous, validable par le job sql-tests.
--
-- Profil de gouvernance encode :
--   * note en TEXTE (pas de note chiffree), rattachee a l'OEUVRE (works.id) ;
--   * visible dans tout le RESEAU, mais ecriture activable PAR BIBLIO
--     (library_service_state.reading_notes_enabled, defaut false = opt-in) ;
--   * ecriture reservee aux LECTEUR-RICES VALIDE-ES (adhesion active, non
--     restreinte) de la biblio d'origine ;
--   * affichage sous PSEUDONYME (choisi cote frontend, stocke sur la note) ;
--   * moderation A POSTERIORI par le staff de la biblio D'ORIGINE ;
--   * RGPD : a la suppression du compte, fn_delete_my_account hard-delete
--     auth.users -> author_user_id passe a NULL (on delete set null). La note
--     (texte + pseudonyme deja non identifiant) est CONSERVEE, depersonnalisee.
--     Aucune modification de fn_delete_my_account necessaire.
-- Idempotent (if not exists / drop-create) pour re-jouabilite (baseline+forward).
-- =========================================================================

-- ─────────────────────────── 1. Tables ───────────────────────────────────

create table if not exists public.book_reading_notes (
  id                bigint generated always as identity primary key,
  work_id           bigint not null references public.works(id) on delete cascade,
  -- auteur : lien coupe (NULL) a l'anonymisation RGPD ; pseudonyme + texte restent.
  author_user_id    uuid references auth.users(id) on delete set null,
  author_pseudonym  text not null check (char_length(btrim(author_pseudonym)) between 1 and 60),
  -- biblio d'origine : contexte de moderation + perimetre d'activation (opt-in).
  origin_library_id uuid not null references public.libraries(id) on delete restrict,
  body              text not null check (char_length(btrim(body)) between 1 and 4000),
  language          text,
  status            text not null default 'published'
                      check (status in ('published','hidden','removed')),
  hidden_reason     text,
  hidden_by         uuid references auth.users(id) on delete set null,
  hidden_at         timestamptz,
  edited            boolean not null default false,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

-- Une note par oeuvre et par auteur-rice tant que le compte existe (anti-spam).
-- Les NULL (auteurs anonymises) ne se comparent pas -> pas de conflit.
create unique index if not exists uniq_reading_note_par_oeuvre_auteur
  on public.book_reading_notes (work_id, author_user_id)
  where author_user_id is not null;

create index if not exists idx_reading_notes_work    on public.book_reading_notes (work_id);
create index if not exists idx_reading_notes_library on public.book_reading_notes (origin_library_id);
create index if not exists idx_reading_notes_author  on public.book_reading_notes (author_user_id);

-- Signalement (moderation a posteriori). Report d'un compte supprime -> disparait.
create table if not exists public.book_reading_note_reports (
  id               bigint generated always as identity primary key,
  note_id          bigint not null references public.book_reading_notes(id) on delete cascade,
  reporter_user_id uuid not null references auth.users(id) on delete cascade,
  reason           text check (reason is null or char_length(btrim(reason)) <= 1000),
  created_at       timestamptz not null default now(),
  resolved_at      timestamptz,
  resolved_by      uuid references auth.users(id) on delete set null,
  constraint uniq_report_par_note_signaleur unique (note_id, reporter_user_id)
);

-- Opt-in par bibliotheque (meme table de config que consultation_timezone).
alter table public.library_service_state
  add column if not exists reading_notes_enabled boolean not null default false;

-- ────────────────────── 2. Garde-fous colonnes (triggers) ─────────────────
-- La RLS controle QUELLES LIGNES on peut modifier, pas quelles colonnes : on
-- verrouille au niveau colonne pour que l'auteur-rice ne touche pas au statut de
-- moderation et que le staff ne reecrive pas le contenu.

create or replace function public.fn_reading_note_before_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- l'auteur-rice est forcement soi-meme ; publication directe (a posteriori).
  new.author_user_id := auth.uid();
  new.status := 'published';
  new.edited := false;
  new.hidden_reason := null; new.hidden_by := null; new.hidden_at := null;
  new.created_at := now(); new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_reading_note_before_insert on public.book_reading_notes;
create trigger trg_reading_note_before_insert
  before insert on public.book_reading_notes
  for each row execute function public.fn_reading_note_before_insert();

create or replace function public.fn_reading_note_before_update()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_is_author boolean := (auth.uid() is not null and auth.uid() = old.author_user_id);
  v_is_staff  boolean := public.user_can_act_as_staff_on_library(old.origin_library_id);
begin
  -- champs jamais modifiables par un UPDATE applicatif
  new.id := old.id;
  new.work_id := old.work_id;
  new.origin_library_id := old.origin_library_id;
  new.author_user_id := old.author_user_id;
  new.author_pseudonym := old.author_pseudonym;
  new.created_at := old.created_at;

  if v_is_author then
    -- auteur-rice : edite body/language ; la moderation fige.
    new.status := old.status;
    new.hidden_reason := old.hidden_reason;
    new.hidden_by := old.hidden_by;
    new.hidden_at := old.hidden_at;
    if new.body is distinct from old.body or new.language is distinct from old.language then
      new.edited := true;
    end if;
    new.updated_at := now();
  elsif v_is_staff then
    -- staff de la biblio d'origine : modere le statut ; le contenu fige.
    new.body := old.body;
    new.language := old.language;
    new.edited := old.edited;
    if new.status is distinct from old.status then
      if new.status in ('hidden','removed') then
        new.hidden_by := auth.uid();
        new.hidden_at := now();
      else  -- retour a 'published'
        new.hidden_by := null; new.hidden_at := null; new.hidden_reason := null;
      end if;
    end if;
    new.updated_at := now();
  else
    raise exception 'reading_note: modification non autorisee' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_reading_note_before_update on public.book_reading_notes;
create trigger trg_reading_note_before_update
  before update on public.book_reading_notes
  for each row execute function public.fn_reading_note_before_update();

-- ─────────────────────────── 3. RLS ───────────────────────────────────────

alter table public.book_reading_notes        enable row level security;
alter table public.book_reading_note_reports enable row level security;

-- Lecture : notes 'published' visibles par tout compte du reseau ; les notes
-- masquees/retirees seulement par leur auteur-rice + le staff d'origine.
drop policy if exists reading_notes_select on public.book_reading_notes;
create policy reading_notes_select on public.book_reading_notes
  for select to authenticated
  using (
    status = 'published'
    or author_user_id = auth.uid()
    or public.user_can_act_as_staff_on_library(origin_library_id)
  );

-- Ecriture : lecteur-rice VALIDE-E (adhesion active, non restreinte) d'une biblio
-- ayant ACTIVE la fonction ; auteur-rice = soi-meme.
drop policy if exists reading_notes_insert on public.book_reading_notes;
create policy reading_notes_insert on public.book_reading_notes
  for insert to authenticated
  with check (
    author_user_id = auth.uid()
    and exists (
      select 1 from public.user_library_memberships m
      where m.user_id = auth.uid()
        and m.library_id = origin_library_id
        and m.status = 'active'
        and coalesce(m.is_restricted, false) = false
    )
    and exists (
      select 1 from public.library_service_state s
      where s.library_id = origin_library_id
        and s.reading_notes_enabled = true
    )
  );

-- Edition : l'auteur-rice modifie sa propre note (colonnes bornees par le trigger).
drop policy if exists reading_notes_update_own on public.book_reading_notes;
create policy reading_notes_update_own on public.book_reading_notes
  for update to authenticated
  using (author_user_id = auth.uid())
  with check (author_user_id = auth.uid());

-- Moderation : le staff de la biblio d'origine (colonnes bornees par le trigger).
drop policy if exists reading_notes_update_staff on public.book_reading_notes;
create policy reading_notes_update_staff on public.book_reading_notes
  for update to authenticated
  using (public.user_can_act_as_staff_on_library(origin_library_id))
  with check (public.user_can_act_as_staff_on_library(origin_library_id));

-- Suppression : l'auteur-rice supprime la sienne ; le staff peut retirer (mais on
-- privilegie status='removed' via UPDATE — le DELETE staff reste possible en filet).
drop policy if exists reading_notes_delete_own on public.book_reading_notes;
create policy reading_notes_delete_own on public.book_reading_notes
  for delete to authenticated
  using (author_user_id = auth.uid()
         or public.user_can_act_as_staff_on_library(origin_library_id));

-- Signalements : tout compte peut signaler une note publiee (soi-meme comme
-- signaleur) ; le staff d'origine lit/resout les signalements de ses notes.
drop policy if exists reading_note_reports_insert on public.book_reading_note_reports;
create policy reading_note_reports_insert on public.book_reading_note_reports
  for insert to authenticated
  with check (
    reporter_user_id = auth.uid()
    and exists (
      select 1 from public.book_reading_notes n
      where n.id = note_id and n.status = 'published'
    )
  );

drop policy if exists reading_note_reports_select_staff on public.book_reading_note_reports;
create policy reading_note_reports_select_staff on public.book_reading_note_reports
  for select to authenticated
  using (
    reporter_user_id = auth.uid()
    or exists (
      select 1 from public.book_reading_notes n
      where n.id = note_id
        and public.user_can_act_as_staff_on_library(n.origin_library_id)
    )
  );

drop policy if exists reading_note_reports_resolve_staff on public.book_reading_note_reports;
create policy reading_note_reports_resolve_staff on public.book_reading_note_reports
  for update to authenticated
  using (exists (
    select 1 from public.book_reading_notes n
    where n.id = note_id
      and public.user_can_act_as_staff_on_library(n.origin_library_id)
  ))
  with check (exists (
    select 1 from public.book_reading_notes n
    where n.id = note_id
      and public.user_can_act_as_staff_on_library(n.origin_library_id)
  ));

-- ─────────────────────────── 4. Grants ────────────────────────────────────
-- RLS filtre les lignes ; les grants ouvrent l'acces au role. Pas d'anon
-- (perimetre reseau : lecture authentifiee).
grant select, insert, update, delete on public.book_reading_notes        to authenticated;
grant select, insert, update         on public.book_reading_note_reports to authenticated;
grant all on public.book_reading_notes        to service_role;
grant all on public.book_reading_note_reports to service_role;

comment on table public.book_reading_notes is
  'Notes de lecture (texte) sur une oeuvre (works). Visibles reseau, ecriture reservee aux lecteurs valides d''une biblio ayant active reading_notes_enabled ; pseudonyme ; moderation a posteriori par le staff d''origine ; anonymisees-conservees a l''effacement du compte. Cadrage CADRAGE_notes_de_lecture_2026-08-01.';
