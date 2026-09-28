-- ============================================================================
-- Un brouillon de reprise hérite des sujets de sa notice — et un brouillon sans
-- aucun sujet ne les efface plus à la publication.
--
-- CE QUI N'ALLAIT PAS (constaté le 28/09/2026 : BTL-TL-000881 a perdu son sujet
-- en recevant une mention d'édition). « Éditer » une notice publiée crée un
-- brouillon de reprise (create_book_draft_from_book) qui reprend les champs et
-- les contributeur·rices (trg_seed_draft_contributors) — mais PAS les sujets :
-- book_draft_subjects reste vide. Or fn_sync_book_subjects_on_publish REMPLACE
-- les sujets de la notice par ceux du brouillon : vides, la notice est
-- désindexée, sans un mot. Depuis juin, 136 brouillons de reprise ont été
-- publiés sans sujet ; 20 notices n'en ont plus aujourd'hui — 7 dont on sait ce
-- qu'elles portaient (C7 du 27/09, fusion 149), 13 qui n'en avaient jamais reçu
-- par un chemin tracé (aucun brouillon à sujets ; hors C7, C11, assuntos).
--
-- CE QUE FAIT CETTE MIGRATION.
--   1. trg_seed_draft_subjects : à la création d'un brouillon rattaché à une
--      notice, ses sujets sont copiés — comme ses contributeur·rices.
--   2. fn_sync_book_subjects_on_publish : un brouillon SANS AUCUN sujet laisse
--      les sujets de la notice en place. Retirer le dernier sujet d'une notice
--      ne passe plus par la publication d'un brouillon vide — c'est le prix
--      d'une perte silencieuse qui a eu lieu 136 fois.
--   3. Les brouillons ouverts sans sujet dont la notice en a reçoivent les siens.
--   4. Les sept notices dont les sujets sont connus les retrouvent (sans
--      condition de titre : elles viennent d'être rééditées, c'est le point).
-- Suite : tests/sql/sujets_suivent_la_reprise_tests.sql.
-- ============================================================================
begin;

-- ── 1 · Le brouillon hérite des sujets ─────────────────────────────────────
create or replace function public.fn_seed_draft_subjects()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
begin
  if new.published_book_id is not null
     and not exists (select 1 from public.book_draft_subjects ds where ds.book_draft_id = new.id) then
    insert into public.book_draft_subjects (book_draft_id, subject_id, ord)
    select new.id, bs.subject_id, bs.ord
      from public.book_subjects bs
     where bs.book_id = new.published_book_id
     order by bs.ord, bs.subject_id
    on conflict do nothing;
  end if;
  return null;
end;
$function$;

revoke all on function public.fn_seed_draft_subjects() from public, anon, authenticated;

drop trigger if exists trg_seed_draft_subjects on public.book_drafts;
create trigger trg_seed_draft_subjects
  after insert on public.book_drafts
  for each row
  when (new.published_book_id is not null)
  execute function public.fn_seed_draft_subjects();

-- ── 2 · Un brouillon sans aucun sujet n'efface rien ────────────────────────
create or replace function public.fn_sync_book_subjects_on_publish()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
begin
  if new.published_book_id is not null then
    -- Aucun sujet sur le brouillon : la notice garde les siens (28/09/2026).
    if not exists (select 1 from public.book_draft_subjects ds where ds.book_draft_id = new.id) then
      return null;
    end if;
    delete from public.book_subjects where book_id = new.published_book_id;
    insert into public.book_subjects (book_id, subject_id, ord)
      select new.published_book_id, ds.subject_id, ds.ord
        from public.book_draft_subjects ds where ds.book_draft_id = new.id
      on conflict (book_id, subject_id) do nothing;
  end if;
  return null;
end;
$function$;

revoke all on function public.fn_sync_book_subjects_on_publish() from public, anon, authenticated;

-- ── 3 · Les brouillons ouverts reçoivent les sujets de leur notice ─────────
do $$
declare v_n int;
begin
  insert into public.book_draft_subjects (book_draft_id, subject_id, ord)
  select d.id, bs.subject_id, bs.ord
    from public.book_drafts d
    join public.book_subjects bs on bs.book_id = d.published_book_id
   where d.status in ('draft', 'ready')
     and not exists (select 1 from public.book_draft_subjects s where s.book_draft_id = d.id)
  on conflict do nothing;
  get diagnostics v_n = row_count;
  raise notice 'Brouillons ouverts : % sujet(s) hérité(s)', v_n;
end $$;

-- ── 4 · Les notices désindexées retrouvent leurs sujets ────────────────────
do $$
declare
  r record; v_sid bigint; v_slug text; v_ord int; v_notices int := 0;
begin
  for r in
    select * from (values
      (106,  'BTL-TL-000103', array['historia-anarquismo', 'greve']),                 -- C7
      (181,  'BTL-TL-000181', array['educacao-libertaria']),                          -- C7
      (463,  'BTL-TL-000491', array['biografia']),                                    -- C7
      (2602, 'MLEG-0145',     array['anarcossindicalismo', 'revolucao-espanhola']),   -- C7
      (2603, 'MLEG-0146',     array['anarcossindicalismo', 'revolucao-espanhola']),   -- C7
      (2604, 'MLEG-0147',     array['anarcossindicalismo', 'revolucao-espanhola']),   -- C7
      (822,  'BTL-TL-000881', array['anarquismo'])                                    -- fusion 149 (sujet 1)
    ) v(id, bib_ref, slugs)
  loop
    if not exists (select 1 from public.books b where b.id = r.id and b.bib_ref = r.bib_ref) then
      raise notice 'Notice % (%) absente ou renumérotée : sautée', r.bib_ref, r.id;
      continue;
    end if;
    if exists (select 1 from public.book_subjects s where s.book_id = r.id) then
      continue;   -- réindexée entre-temps (ou par un passage précédent)
    end if;
    v_ord := 0;
    foreach v_slug in array r.slugs loop
      select id into v_sid from public.subjects where slug = v_slug and status = 'ativo';
      if v_sid is null then
        raise exception 'Sujets : matière % absente ou inactive', v_slug;
      end if;
      v_ord := v_ord + 1;
      insert into public.book_subjects (book_id, subject_id, ord) values (r.id, v_sid, v_ord)
      on conflict do nothing;
    end loop;
    v_notices := v_notices + 1;
  end loop;
  raise notice 'Notices réindexées : %', v_notices;
end $$;

-- ── 5 · Droits ─────────────────────────────────────────────────────────────
do $$
declare v_f text;
begin
  foreach v_f in array array['public.fn_seed_draft_subjects()', 'public.fn_sync_book_subjects_on_publish()'] loop
    if has_function_privilege('anon', v_f, 'EXECUTE') or has_function_privilege('authenticated', v_f, 'EXECUTE') then
      raise exception 'sujets : % ouverte au lectorat', v_f;
    end if;
  end loop;
end $$;

commit;
