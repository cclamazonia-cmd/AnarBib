-- =========================================================================
-- Notes de lecture — Lot 5 : garantir UNE ŒUVRE PAR LIVRE.
-- Cadrage : docs/journal/cadrages/CADRAGE_notes_de_lecture_2026-08-01.md
-- Réf modèle œuvre : 20260620090724 (Lot 1) + 20260620091752 (RPC staff).
--
-- Contexte : les notes de lecture sont rattachées à l'ŒUVRE (works.id), pour se
-- mutualiser entre toutes les éditions/traductions d'un même titre (choix du
-- cadrage). Or le backfill initial (20260620090724) n'a créé une œuvre que pour
-- les titres à ≥ 2 éditions : un livre à édition unique n'a pas de work_id, donc
-- aucune œuvre à laquelle accrocher une note, et pas de lien « voir l'œuvre ».
-- En FRBR, tout livre EST pourtant la manifestation d'une œuvre : on complète le
-- modèle en garantissant work_id NOT NULL pour tout livre.
--
-- Décision (AG / échange 03-04/08/2026) : option « une œuvre par livre » (plutôt
-- que notes au niveau book_id — qui casserait la mutualisation réseau — ou
-- création d'œuvre par un lecteur — mélange des genres catalogue).
--
-- Non destructif, réversible. Les œuvres-singleton n'encombrent aucune liste
-- (l'OPAC liste les éditions) ; group_books_as_editions les regroupe si un
-- doublon apparaît, les notes suivent.
-- =========================================================================

-- ── 1. Trigger : tout NOUVEAU livre sans œuvre en reçoit une. ───────────────
-- BEFORE INSERT UNIQUEMENT (surtout pas UPDATE) : detach_book_from_work met
-- délibérément work_id := NULL ; un trigger sur UPDATE le referait aussitôt,
-- rendant le détachement impossible. Le détachement staff (rare) laisse donc un
-- livre sans œuvre — cas assumé (les notes y redeviennent inaccessibles jusqu'au
-- prochain rattachement). SECURITY DEFINER : crée l'œuvre en contournant la RLS
-- d'écriture staff-only de works.
create or replace function public.fn_books_ensure_work()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare v_work bigint;
begin
  if new.work_id is not null then
    return new;  -- import ou saisie qui assigne déjà une œuvre : on ne touche à rien
  end if;
  -- book_authors n'est pas encore inséré à ce stade (FK book_id) -> auteur·rice
  -- principal·e non résolu ici ; enrichissable ensuite par les flux catalogue.
  insert into public.works (uniform_title, sort_title, primary_author_id)
  values (
    coalesce(nullif(btrim(new.titulo), ''), '(sans titre)'),
    public.fn_normalize_name(new.titulo),
    null
  )
  returning id into v_work;
  new.work_id := v_work;
  return new;
end;
$$;

drop trigger if exists trg_books_ensure_work on public.books;
create trigger trg_books_ensure_work
  before insert on public.books
  for each row execute function public.fn_books_ensure_work();

comment on function public.fn_books_ensure_work() is
  'Garantit work_id NOT NULL sur tout livre inséré : crée une œuvre-manifestation si aucune n''est fournie. BEFORE INSERT seulement (ne pas défaire detach_book_from_work). Cadrage CADRAGE_notes_de_lecture_2026-08-01 (Lot 5).';

-- ── 2. Backfill des livres orphelins existants. ────────────────────────────
-- Une œuvre par livre sans work_id, avec auteur·rice principal·e (book_authors
-- existe déjà pour ces livres). Idempotent : ne touche que work_id IS NULL.
-- L'UPDATE ne redéclenche pas le trigger (INSERT-only). No-op en CI (base
-- reconstruite sans livres) et à tout re-jeu.
do $backfill$
declare r record; v_work bigint; v_auth bigint; v_n int := 0;
begin
  for r in select id, titulo from public.books where work_id is null loop
    select author_id into v_auth
      from public.book_authors
      where book_id = r.id and role = 'autor'
      order by ord limit 1;
    insert into public.works (uniform_title, sort_title, primary_author_id)
    values (coalesce(nullif(btrim(r.titulo), ''), '(sans titre)'),
            public.fn_normalize_name(r.titulo), v_auth)
    returning id into v_work;
    update public.books set work_id = v_work where id = r.id;
    v_n := v_n + 1;
  end loop;
  raise notice 'reading_notes_lot5: % livre(s) orphelin(s) rattaché(s) à une œuvre neuve', v_n;
end $backfill$;
