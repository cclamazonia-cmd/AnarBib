-- =====================================================================
-- AnarBib -- Deux tomes différents ne sont jamais un doublon : la règle du
--            lot 4 portée aux deux détecteurs qui l'ignoraient (DEDUP-15)
-- Date     : 2026-10-08  ·  Relevé de Xavier (capture de la liste plate, 20 h 12)
-- Dépend   : 20260904170000 (fn_volume_marker, fn_volume_rank),
--            20260904210000 (lot 4 : la règle dans suggest_catalog_duplicates),
--            20260928163920 (DEDUP-14 : définitions réelles des deux détecteurs,
--            relues en prod le 08/10 avant réécriture)
--
-- CONSTAT (prod, 08/10). Le balayage global (suggest_catalog_duplicates)
-- écarte deux notices dont les tomes diffèrent depuis le 04/09. Le détecteur
-- par notice (suggest_book_duplicates, l'assistant ouvert sur une fiche) et le
-- détecteur des brouillons (api.suggest_draft_duplicates, le formulaire) ne
-- lisent pas le tome : sur BTL-TL-000323 (Thomas, A guerra civil espanhola,
-- Civilização Brasileira 1964, tome 1), l'assistant proposait MLEG-0016
-- (tome I — juste) mais aussi MLEG-0017 (tome II) et BTL-TL-000322 (tome 2).
-- Mesuré : 64 paires intra-bibliothèque de tomes différents proposées à tort,
-- 6 déjà écartées à la main en « pas un doublon ».
--
-- CE QUI CHANGE. Les deux fonctions calculent le rang du tome comme le
-- balayage (numéro posé, sinon marqueur lu dans le titre ou le sous-titre,
-- via fn_volume_rank : « 1 » et « I » sont le même tome) et excluent toute
-- paire dont les deux rangs sont connus et différents. Un tome inconnu d'un
-- côté reste candidat : c'est à une main de poser le tome, puis de trancher.
-- Corps repris des définitions réelles ; seuls le rang et la clause sont
-- ajoutés. Droits inchangés (CREATE OR REPLACE conserve les GRANT).
-- Suite : tests/sql/tomes_jamais_doublons_par_notice_tests.sql
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Le détecteur par notice
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.suggest_book_duplicates(p_book_id bigint)
 RETURNS TABLE(book_id bigint, titulo text, autor text, ano text, editora text, isbn text, exemplares integer, match_kind text, score real)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_catalog'
AS $function$
declare v_isbn text; v_title text; v_author text; v_work bigint;
        v_ano text; v_editora text; v_edicao text;
        v_vol integer;   -- DEDUP-15 : le rang du tome de la notice
begin
  if not exists (select 1 from public.user_library_memberships m where m.user_id=auth.uid() and m.role=any(array['librarian'::text,'coordenador'::text])) then
    raise exception 'Acesso restrito ao staff de catalogacao.'; end if;
  -- DEDUP-14 (28/09) : l'ISBN par son cœur — ISBN-10 et ISBN-13 du même livre sont le même.
  select public.fn_isbn_coeur(b.isbn), public.fn_normalize_name(b.titulo), public.fn_normalize_name(b.autor), b.work_id,
         b.ano, b.editora, b.edicao,
         -- DEDUP-15 (08/10) : le tome, posé ou lu dans le titre (même calcul que le balayage, lot 4)
         public.fn_volume_rank(coalesce(nullif(btrim(b.volume),''), public.fn_volume_marker(b.titulo), public.fn_volume_marker(b.subtitulo)))
    into v_isbn, v_title, v_author, v_work, v_ano, v_editora, v_edicao, v_vol from public.books b where b.id=p_book_id;
  if v_title is null then return; end if;
  return query
  with other as (
    select b.id,b.titulo,b.autor,b.ano,b.editora,b.isbn,b.work_id,b.edicao,
           public.fn_isbn_coeur(b.isbn) as ni,
           public.fn_normalize_name(b.titulo) as nt, public.fn_normalize_name(b.autor) as na,
           public.fn_volume_rank(coalesce(nullif(btrim(b.volume),''), public.fn_volume_marker(b.titulo), public.fn_volume_marker(b.subtitulo))) as vol
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
    -- DEDUP-15 (08/10) : deux tomes différents ne sont jamais un doublon.
    and not (v_vol is not null and o.vol is not null and o.vol <> v_vol)
    and ( (v_isbn<>'' and o.ni=v_isbn)
       or ( o.nt<>'' and similarity(o.nt,v_title)>=0.5 and (v_author='' or o.na='' or similarity(o.na,v_author)>=0.4)
            and not (v_isbn<>'' and o.ni<>'' and o.ni<>v_isbn) ) )
  order by 9 desc, o.titulo limit 50;
end;
$function$;

-- ---------------------------------------------------------------------
-- 2. Le détecteur des brouillons
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.suggest_draft_duplicates(p_draft_id bigint)
 RETURNS TABLE(candidate_id bigint, source text, titulo text, subtitulo text, autor text, ano text, editora text, isbn text, cdd text, colecao text, idioma text, tipo_material text, match_kind text, score real)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_catalog'
AS $function$
declare v_isbn text; v_title text; v_author text; v_lib uuid; v_pub bigint; v_work bigint;
        v_ano text; v_editora text; v_edicao text;
        v_admin boolean; v_staff uuid[];   -- B29
        v_vol integer;                     -- DEDUP-15 : le rang du tome du brouillon
begin
  if not exists (select 1 from public.user_library_memberships m where m.user_id=auth.uid() and m.role=any(array['librarian'::text,'coordenador'::text])) then
    raise exception 'Acesso restrito ao staff de catalogacao.'; end if;
  -- DEDUP-14 (28/09) : l'ISBN par son cœur
  select public.fn_isbn_coeur(d.isbn), public.fn_normalize_name(d.titulo), public.fn_normalize_name(d.autor), d.owner_library_id, d.published_book_id,
         d.ano, d.editora, d.edicao,
         -- DEDUP-15 (08/10) : le tome, posé ou lu dans le titre (même calcul que le balayage, lot 4)
         public.fn_volume_rank(coalesce(nullif(btrim(d.volume),''), public.fn_volume_marker(d.titulo), public.fn_volume_marker(d.subtitulo)))
    into v_isbn, v_title, v_author, v_lib, v_pub, v_ano, v_editora, v_edicao, v_vol from public.book_drafts d where d.id=p_draft_id;
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
           public.fn_isbn_coeur(d.isbn) as ni, public.fn_normalize_name(d.titulo) as nt, public.fn_normalize_name(d.autor) as na,
           public.fn_volume_rank(coalesce(nullif(btrim(d.volume),''), public.fn_volume_marker(d.titulo), public.fn_volume_marker(d.subtitulo))) as vol
    from public.book_drafts d where d.status='draft' and d.id<>p_draft_id and (v_lib is null or d.owner_library_id=v_lib)
      and (v_admin or coalesce(d.owner_library_id, private.fn_book_draft_creator_library(d.id, d.created_by)) = any(v_staff))
    union all
    select b.id,'book'::text,b.titulo,b.subtitulo,b.autor,b.ano,b.editora,b.isbn,b.cdd,b.colecao,b.idioma,b.tipo_material,
           b.work_id, b.edicao,
           public.fn_isbn_coeur(b.isbn), public.fn_normalize_name(b.titulo), public.fn_normalize_name(b.autor),
           public.fn_volume_rank(coalesce(nullif(btrim(b.volume),''), public.fn_volume_marker(b.titulo), public.fn_volume_marker(b.subtitulo)))
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
    -- DEDUP-15 (08/10) : deux tomes différents ne sont jamais un doublon.
    and not (v_vol is not null and c.vol is not null and c.vol <> v_vol)
    and ( (v_isbn<>'' and c.ni=v_isbn)
       or ( similarity(c.nt,v_title)>=0.5 and (v_author='' or c.na='' or similarity(c.na,v_author)>=0.4)
            and not (v_isbn<>'' and c.ni<>'' and c.ni<>v_isbn) ) )
  order by 14 desc, c.src, c.titulo limit 50;
end;
$function$;

-- ---------------------------------------------------------------------
-- 3. Garde-fou de la migration elle-même : la règle est bien dans les deux
--    corps, et « 1 » / « I » sont le même tome. Une mutation la fait refuser
--    AVANT la suite.
-- ---------------------------------------------------------------------
DO $$
BEGIN
  IF public.fn_volume_rank('1') IS DISTINCT FROM public.fn_volume_rank('I')
     OR public.fn_volume_rank('2') IS NOT DISTINCT FROM public.fn_volume_rank('3')
     OR public.fn_volume_rank(public.fn_volume_marker('A Guerra Civil Espanhola Vol III')) IS DISTINCT FROM 3 THEN
    RAISE EXCEPTION 'DEDUP-15 : fn_volume_rank ne distingue plus les tomes comme attendu';
  END IF;
  IF (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE (n.nspname, p.proname) IN (('public', 'suggest_book_duplicates'), ('api', 'suggest_draft_duplicates'))
         AND p.prosrc LIKE '%vol is not null and%<> v_vol)%') <> 2 THEN
    RAISE EXCEPTION 'DEDUP-15 : la clause des tomes manque dans un des deux détecteurs';
  END IF;
  IF has_function_privilege('anon', 'public.suggest_book_duplicates(bigint)', 'EXECUTE')
     OR has_function_privilege('anon', 'api.suggest_draft_duplicates(bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'DEDUP-15 : un détecteur est ouvert à anon';
  END IF;
END $$;

COMMIT;
