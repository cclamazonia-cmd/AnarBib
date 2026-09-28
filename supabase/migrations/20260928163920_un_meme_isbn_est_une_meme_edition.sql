-- ============================================================================
-- Un même ISBN est une même édition — sous ses deux formes ; et un éditeur ne
-- change pas de nom parce qu'on écrit « Ediciones » devant.
--
-- Question de Xavier, 28/09/2026 : BTL-TL-000504 et BTL-TL-000727 (Anarquistas,
-- Suriano, Manantial, 2001), même édition de la même œuvre (68), ne sont jamais
-- proposées comme doublon. Deux failles, qui se cumulent :
--   1. l'ISBN est comparé comme une suite de chiffres brute : 987-500-069-8
--      (ISBN-10) et 978-987-500-069-8 (ISBN-13) — le même numéro — deviennent
--      « deux ISBN différents », donc « deux éditions » (fn_editions_distinctes),
--      et les trois détecteurs les excluent encore par leur propre règle
--      « ISBN présents et différents ». Quatre paires du catalogue sont dans ce
--      cas (000504~000727 ; 000301~0000054 ; 001525~0000258 ; 001808~0000060).
--   2. « Manantial » et « Ediciones Manantial » ont une similarité de 0,5 sous
--      le seuil de 0,75 : deux éditeurs, donc deux éditions — même sans ISBN.
--   Et aucune suite n'exerçait fn_editions_distinctes.
--
-- CE QUE FAIT CETTE MIGRATION (DEDUP-14).
--   · fn_isbn_coeur : les 12 chiffres sans clé, ISBN-10 ramené à sa forme 978.
--   · fn_editeur_coeur / fn_meme_editeur : nom d'éditeur sans ses mots
--     génériques (editora, ediciones, éditions, verlag, press…), égalité,
--     inclusion des mots ou similarité ≥ 0,75.
--   · fn_editions_distinctes : deux ISBN présents décident seuls — le même
--     cœur = la même édition, quoi qu'en disent l'année ou l'éditeur (un
--     tirage n'est pas une édition) ; deux cœurs différents = deux éditions.
--     Sans ISBN des deux côtés : année, éditeur (au sens ci-dessus), mention.
--   · suggest_book_duplicates, suggest_catalog_duplicates,
--     api.suggest_draft_duplicates comparent les ISBN par leur cœur ;
--     rien d'autre n'y change.
-- Suite : tests/sql/editions_distinctes_tests.sql.
-- ============================================================================
begin;

-- ── 1 · Le cœur d'un ISBN ──────────────────────────────────────────────────
create or replace function public.fn_isbn_coeur(p_isbn text)
returns text
language sql
immutable
set search_path to 'public', 'pg_catalog'
as $function$
  select case when length(n) = 10 then '978' || left(n, 9)
              when length(n) = 13 then left(n, 12)
              else '' end
    from (select regexp_replace(upper(coalesce(p_isbn, '')), '[^0-9X]', '', 'g') as n) s;
$function$;

comment on function public.fn_isbn_coeur(text) is
  'Les 12 chiffres d''un ISBN sans sa clé, l''ISBN-10 ramené à sa forme 978 : deux formes du même numéro ont le même cœur. Vide si ce n''est pas un ISBN.';

-- ── 2 · Le cœur d'un nom d'éditeur ─────────────────────────────────────────
create or replace function public.fn_editeur_coeur(p_editora text)
returns text
language sql
immutable
set search_path to 'public', 'pg_catalog'
as $function$
  select coalesce(array_to_string(array(
    select tok
      from unnest(string_to_array(public.fn_normalize_name(p_editora), ' ')) as tok
     where tok <> '' and length(tok) > 1
       and tok <> all (array[
         'editora','editorial','editoriale','editoriali','ediciones','edicions','edicoes','edicao','edicion','edition','editions',
         'editeur','editeurs','editores','editore','editor','ed','eds','verlag','press','publishing','publishers','publisher',
         'books','livros','livraria','libreria','librairie','libri','casa','cia','cie','co','ltda','ltd','sa','srl','inc',
         'grafica','tipografia','imprenta','imprensa','impressora','oficina','oficinas','colecao','coleccion','collection',
         'de','da','do','das','dos','del','della','di','la','le','les','el','los','las','the','and','et','und'])
     order by tok), ' '), '');
$function$;

create or replace function public.fn_meme_editeur(p_editora_a text, p_editora_b text)
returns boolean
language sql
immutable
set search_path to 'public', 'extensions', 'pg_catalog'
as $function$
  with c as (select public.fn_editeur_coeur(p_editora_a) as ca, public.fn_editeur_coeur(p_editora_b) as cb)
  select ca = '' or cb = ''            -- inconnu d'un côté : on ne sépare pas
      or ca = cb
      or (select bool_and(t = any (string_to_array(cb, ' '))) from unnest(string_to_array(ca, ' ')) t)
      or (select bool_and(t = any (string_to_array(ca, ' '))) from unnest(string_to_array(cb, ' ')) t)
      or similarity(ca, cb) >= 0.75
    from c;
$function$;

comment on function public.fn_meme_editeur(text, text) is
  'Vrai si deux noms d''éditeur désignent le même, une fois retirés les mots génériques (editora, ediciones, éditions…) : égalité, inclusion des mots, ou similarité ≥ 0,75. Vrai aussi si l''un des deux est vide.';

revoke all on function public.fn_isbn_coeur(text) from public, anon;
revoke all on function public.fn_editeur_coeur(text) from public, anon;
revoke all on function public.fn_meme_editeur(text, text) from public, anon;
grant execute on function public.fn_isbn_coeur(text) to authenticated, service_role;
grant execute on function public.fn_editeur_coeur(text) to authenticated, service_role;
grant execute on function public.fn_meme_editeur(text, text) to authenticated, service_role;

-- ── 3 · Le juge commun des éditions distinguables ──────────────────────────
create or replace function public.fn_editions_distinctes(p_isbn_a text, p_isbn_b text, p_ano_a text, p_ano_b text, p_editora_a text, p_editora_b text, p_edicao_a text, p_edicao_b text)
returns boolean
language sql
immutable
set search_path to 'public', 'extensions', 'pg_catalog'
as $function$
  WITH n AS (
    SELECT public.fn_isbn_coeur(p_isbn_a) AS ia,
           public.fn_isbn_coeur(p_isbn_b) AS ib,
           nullif(btrim(coalesce(p_ano_a,'')),'') AS aa,
           nullif(btrim(coalesce(p_ano_b,'')),'') AS ab,
           public.fn_normalize_name(coalesce(p_edicao_a,'')) AS da,
           public.fn_normalize_name(coalesce(p_edicao_b,'')) AS db
  )
  SELECT CASE
           -- Deux ISBN présents décident seuls : le même cœur est la même édition
           -- (un tirage, une année ou un nom d'éditeur écrit autrement n'y changent
           -- rien) ; deux cœurs différents sont deux éditions.
           WHEN ia <> '' AND ib <> '' THEN ia <> ib
           ELSE (aa IS NOT NULL AND ab IS NOT NULL AND aa <> ab)
             OR NOT public.fn_meme_editeur(p_editora_a, p_editora_b)
             OR (da <> '' AND db <> '' AND da <> db)
         END
  FROM n;
$function$;

-- ── 4 · Les trois détecteurs comparent les ISBN par leur cœur ──────────────
CREATE OR REPLACE FUNCTION public.suggest_book_duplicates(p_book_id bigint)
 RETURNS TABLE(book_id bigint, titulo text, autor text, ano text, editora text, isbn text, exemplares integer, match_kind text, score real)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_catalog'
AS $function$
declare v_isbn text; v_title text; v_author text; v_work bigint;
        v_ano text; v_editora text; v_edicao text;
begin
  if not exists (select 1 from public.user_library_memberships m where m.user_id=auth.uid() and m.role=any(array['librarian'::text,'coordenador'::text])) then
    raise exception 'Acesso restrito ao staff de catalogacao.'; end if;
  -- DEDUP-14 (28/09) : l'ISBN par son cœur — ISBN-10 et ISBN-13 du même livre sont le même.
  select public.fn_isbn_coeur(b.isbn), public.fn_normalize_name(b.titulo), public.fn_normalize_name(b.autor), b.work_id,
         b.ano, b.editora, b.edicao
    into v_isbn, v_title, v_author, v_work, v_ano, v_editora, v_edicao from public.books b where b.id=p_book_id;
  if v_title is null then return; end if;
  return query
  with other as (
    select b.id,b.titulo,b.autor,b.ano,b.editora,b.isbn,b.work_id,b.edicao,
           public.fn_isbn_coeur(b.isbn) as ni,
           public.fn_normalize_name(b.titulo) as nt, public.fn_normalize_name(b.autor) as na
    from public.books b where b.id<>p_book_id)
  select o.id,o.titulo,o.autor,o.ano,o.editora,o.isbn,
         (select coalesce(sum(h.exemplares_total),0)::integer from public.book_holdings h where h.book_id=o.id),
         case when v_isbn<>'' and o.ni=v_isbn then 'isbn' else 'approx' end,
         case when v_isbn<>'' and o.ni=v_isbn then 1.0::real else similarity(o.nt,v_title)::real end
  from other o
  where not exists (select 1 from public.book_not_duplicate nd where nd.book_id_a=least(p_book_id,o.id) and nd.book_id_b=greatest(p_book_id,o.id))
    -- P4 raffine (31/08) : meme oeuvre = editions SI ON PEUT LES DISTINGUER ;
    -- deux fiches de meme oeuvre qu'aucun champ d'edition ne separe restent
    -- des candidates au doublon.
    and not (v_work is not null and o.work_id = v_work
             and public.fn_editions_distinctes(v_isbn, o.isbn, v_ano, o.ano, v_editora, o.editora, v_edicao, o.edicao))
    and ( (v_isbn<>'' and o.ni=v_isbn)
       or ( o.nt<>'' and similarity(o.nt,v_title)>=0.5 and (v_author='' or o.na='' or similarity(o.na,v_author)>=0.4)
            and not (v_isbn<>'' and o.ni<>'' and o.ni<>v_isbn) ) )
  order by 9 desc, o.titulo limit 50;
end;
$function$;

CREATE OR REPLACE FUNCTION public.suggest_catalog_duplicates(p_max integer DEFAULT 500)
 RETURNS TABLE(book_id_a bigint, ref_a text, titulo_a text, autor_a text, ano_a text, bibliotecas_a text, exemplares_a integer, book_id_b bigint, ref_b text, titulo_b text, autor_b text, ano_b text, bibliotecas_b text, exemplares_b integer, match_kind text, score real, configuration text, fusion_possible boolean, niveau_preuve text, rang_preuve integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_catalog'
AS $function$
begin
  if not exists (
    select 1 from public.user_library_memberships m
    where m.user_id = auth.uid()
      and m.role = any (array['librarian'::text, 'coordenador'::text])
  ) then
    raise exception 'Acesso restrito ao staff de catalogacao.';
  end if;

  return query
  with brut as (
    select a.id as ia_id, b.id as ib_id,
           -- DEDUP-14 (28/09) : l'ISBN par son cœur
           public.fn_isbn_coeur(a.isbn) as isbn_a,
           public.fn_isbn_coeur(b.isbn) as isbn_b,
           public.fn_normalize_name(a.titulo) as nt_a,
           public.fn_normalize_name(b.titulo) as nt_b,
           public.fn_normalize_name(a.autor)  as na_a,
           public.fn_normalize_name(b.autor)  as na_b,
           public.fn_normalize_name(coalesce(a.editora,'')) as ne_a,
           public.fn_normalize_name(coalesce(b.editora,'')) as ne_b,
           nullif(btrim(coalesce(a.ano,'')),'') as an_a,
           nullif(btrim(coalesce(b.ano,'')),'') as an_b,
           a.work_id as work_a, b.work_id as work_b,
           -- P4 raffine (31/08) : le juge commun des editions distinguables
           public.fn_editions_distinctes(a.isbn, b.isbn, a.ano, b.ano, a.editora, b.editora, a.edicao, b.edicao) as ed_dist,
           a.serial_id as serial_a, b.serial_id as serial_b,
           a.issue_key as issue_a,  b.issue_key as issue_b,
           -- Lot 4 (04/09) : le tome, pose ou lu dans le titre
           public.fn_volume_rank(coalesce(nullif(btrim(a.volume),''), public.fn_volume_marker(a.titulo), public.fn_volume_marker(a.subtitulo))) as vol_a,
           public.fn_volume_rank(coalesce(nullif(btrim(b.volume),''), public.fn_volume_marker(b.titulo), public.fn_volume_marker(b.subtitulo))) as vol_b
    from public.books a
    join public.books b
      on b.id > a.id
     and b.titulo % a.titulo
  ),
  retenues as (
    select r.*,
           case when r.isbn_a <> '' and r.isbn_b = r.isbn_a then 'isbn' else 'approx' end as kind,
           case when r.isbn_a <> '' and r.isbn_b = r.isbn_a then 1.0::real
                else similarity(r.nt_a, r.nt_b)::real end as sc,
           case
             when r.isbn_a <> '' and r.isbn_b = r.isbn_a
               then 'isbn'
             when similarity(r.nt_a, r.nt_b) >= 0.99
              and r.an_a is not null and r.an_a = r.an_b
              and r.ne_a <> '' and similarity(r.ne_a, r.ne_b) >= 0.75
               then 'titre_annee_editeur'
             when similarity(r.nt_a, r.nt_b) >= 0.90
              and r.an_a is not null and r.an_a = r.an_b
               then 'titre_annee'
             else 'titre_seul'
           end as niveau
    from brut r
    where not exists (
            select 1 from public.book_not_duplicate nd
            where nd.book_id_a = least(r.ia_id, r.ib_id)
              and nd.book_id_b = greatest(r.ia_id, r.ib_id))
      -- P4 raffine (31/08) : la meme oeuvre ne masque une paire que si les
      -- editions sont reellement distinguables. Indistinguables = candidates.
      and not (r.work_a is not null and r.work_b = r.work_a and r.ed_dist)
      and not (
            r.serial_a is not null
        and r.serial_b = r.serial_a
        and r.issue_a is not null and r.issue_b is not null
        and r.issue_a <> r.issue_b
      )
      -- Lot 4 (04/09) : deux tomes differents ne sont jamais un doublon.
      and not (r.vol_a is not null and r.vol_b is not null and r.vol_a <> r.vol_b)
      and ( (r.isbn_a <> '' and r.isbn_b = r.isbn_a)
         or ( r.nt_a <> '' and similarity(r.nt_a, r.nt_b) >= 0.5
              and (r.na_a = '' or r.na_b = '' or similarity(r.na_a, r.na_b) >= 0.4)
              and not (r.isbn_a <> '' and r.isbn_b <> '' and r.isbn_b <> r.isbn_a) ) )
  )
  select
    ba.id, ba.bib_ref, ba.titulo, ba.autor, ba.ano, la.libs, coalesce(la.ex,0)::integer,
    bb.id, bb.bib_ref, bb.titulo, bb.autor, bb.ano, lb.libs, coalesce(lb.ex,0)::integer,
    x.kind, x.sc,
    case when la.libs is not distinct from lb.libs then 'interne'
         else 'inter_bibliotheques' end,
    (la.libs is not distinct from lb.libs),
    x.niveau,
    (case x.niveau when 'isbn' then 1
                   when 'titre_annee_editeur' then 2
                   when 'titre_annee' then 3
                   else 4 end)::integer
  from retenues x
  join public.books ba on ba.id = x.ia_id
  join public.books bb on bb.id = x.ib_id
  join lateral (
    select string_agg(distinct l.short_name, ' + ' order by l.short_name) as libs,
           sum(h.exemplares_total) as ex
    from public.book_holdings h
    join public.libraries l on l.id = h.library_id
    where h.book_id = x.ia_id) la on true
  join lateral (
    select string_agg(distinct l.short_name, ' + ' order by l.short_name) as libs,
           sum(h.exemplares_total) as ex
    from public.book_holdings h
    join public.libraries l on l.id = h.library_id
    where h.book_id = x.ib_id) lb on true
  order by
    case x.niveau when 'isbn' then 1
                  when 'titre_annee_editeur' then 2
                  when 'titre_annee' then 3
                  else 4 end,
    x.sc desc,
    ba.titulo
  limit greatest(coalesce(p_max, 500), 1);
end $function$;

CREATE OR REPLACE FUNCTION api.suggest_draft_duplicates(p_draft_id bigint)
 RETURNS TABLE(candidate_id bigint, source text, titulo text, subtitulo text, autor text, ano text, editora text, isbn text, cdd text, colecao text, idioma text, tipo_material text, match_kind text, score real)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_catalog'
AS $function$
declare v_isbn text; v_title text; v_author text; v_lib uuid; v_pub bigint; v_work bigint;
        v_ano text; v_editora text; v_edicao text;
        v_admin boolean; v_staff uuid[];   -- B29
begin
  if not exists (select 1 from public.user_library_memberships m where m.user_id=auth.uid() and m.role=any(array['librarian'::text,'coordenador'::text])) then
    raise exception 'Acesso restrito ao staff de catalogacao.'; end if;
  -- DEDUP-14 (28/09) : l'ISBN par son cœur
  select public.fn_isbn_coeur(d.isbn), public.fn_normalize_name(d.titulo), public.fn_normalize_name(d.autor), d.owner_library_id, d.published_book_id,
         d.ano, d.editora, d.edicao
    into v_isbn, v_title, v_author, v_lib, v_pub, v_ano, v_editora, v_edicao from public.book_drafts d where d.id=p_draft_id;
  if v_title is null then return; end if;
  -- B29 (CAT-E18) : rien pour un brouillon d'une autre bibliothèque ; et les
  -- candidats « brouillon » se limitent à ceux que l'appelant peut voir.
  if not coalesce(public.fn_caller_can_edit_book_draft(p_draft_id), false) then return; end if;
  v_admin := public.fn_caller_is_network_admin();
  v_staff := public.fn_caller_staff_library_ids();
  select b.work_id into v_work from public.books b where b.id = v_pub;
  return query
  with cand as (
    select d.id as cid,'draft'::text as src,d.titulo,d.subtitulo,d.autor,d.ano,d.editora,d.isbn,d.cdd,d.colecao,d.idioma,d.tipo_material,
           null::bigint as cwork, d.edicao as cedicao,
           public.fn_isbn_coeur(d.isbn) as ni, public.fn_normalize_name(d.titulo) as nt, public.fn_normalize_name(d.autor) as na
    from public.book_drafts d where d.status='draft' and d.id<>p_draft_id and (v_lib is null or d.owner_library_id=v_lib)
      and (v_admin or coalesce(d.owner_library_id, private.fn_book_draft_creator_library(d.id, d.created_by)) = any(v_staff))
    union all
    select b.id,'book'::text,b.titulo,b.subtitulo,b.autor,b.ano,b.editora,b.isbn,b.cdd,b.colecao,b.idioma,b.tipo_material,
           b.work_id, b.edicao,
           public.fn_isbn_coeur(b.isbn), public.fn_normalize_name(b.titulo), public.fn_normalize_name(b.autor)
    from public.books b where b.id is distinct from v_pub)
  select c.cid,c.src,c.titulo,c.subtitulo,c.autor,c.ano,c.editora,c.isbn,c.cdd,c.colecao,c.idioma,c.tipo_material,
         case when v_isbn<>'' and c.ni=v_isbn then 'isbn' else 'approx' end,
         case when v_isbn<>'' and c.ni=v_isbn then 1.0::real else similarity(c.nt,v_title)::real end
  from cand c
  where c.nt<>''
    and not ( c.src='book' and v_pub is not null and exists (select 1 from public.book_not_duplicate nd where nd.book_id_a=least(v_pub,c.cid) and nd.book_id_b=greatest(v_pub,c.cid)) )
    -- P4 raffine (31/08) : meme oeuvre que le livre du brouillon = edition
    -- SEULEMENT si un champ d'edition les distingue vraiment.
    and not ( c.src='book' and v_work is not null and c.cwork = v_work
              and public.fn_editions_distinctes(v_isbn, c.isbn, v_ano, c.ano, v_editora, c.editora, v_edicao, c.cedicao) )
    and ( (v_isbn<>'' and c.ni=v_isbn)
       or ( similarity(c.nt,v_title)>=0.5 and (v_author='' or c.na='' or similarity(c.na,v_author)>=0.4)
            and not (v_isbn<>'' and c.ni<>'' and c.ni<>v_isbn) ) )
  order by 14 desc, c.src, c.titulo limit 50;
end;
$function$;

-- ── 5 · Vérifications ──────────────────────────────────────────────────────
do $$
begin
  if public.fn_isbn_coeur('987-500-069-8') <> public.fn_isbn_coeur('978-987-500-069-8') then
    raise exception 'DEDUP-14 : ISBN-10 et ISBN-13 du même livre n''ont pas le même cœur';
  end if;
  if public.fn_editions_distinctes('978-987-500-069-8', '987-500-069-8', '2001', '2001', 'Manantial', 'Ediciones Manantial', '', '') then
    raise exception 'DEDUP-14 : Anarquistas (Suriano) serait encore deux éditions';
  end if;
  if not public.fn_editions_distinctes('978-85-7715-072-4', '978-85-7935-000-9', '2007', '2007', 'Hedra', 'Hedra', '', '') then
    raise exception 'DEDUP-14 : deux ISBN différents ne seraient plus deux éditions';
  end if;
  if has_function_privilege('anon', 'public.fn_isbn_coeur(text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.fn_meme_editeur(text, text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.fn_editions_distinctes(text, text, text, text, text, text, text, text)', 'EXECUTE') then
    raise exception 'DEDUP-14 : une aide ouverte à anon';
  end if;
end $$;

commit;
