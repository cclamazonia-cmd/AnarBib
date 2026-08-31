-- =====================================================================
-- AnarBib -- Une meme edition n'est plus masquee par son oeuvre
-- Date    : 2026-08-31  ·  Chantier doublons (suite P4 du 21/08 et works du 20/06)
--
-- LE PIEGE, VECU SUR LE CAS 2335/2641 (« O Anarquismo na Escola, no Teatro,
-- na Poesia », Rodrigues, Achiame 1992 : une fiche BLMF+BTL, une fiche MLEG).
--
-- Le backfill du modele d'oeuvres (20260620090724) groupe les notices par
-- titre+auteur normalises. La regle P4 des trois suggest_* exclut ensuite
-- toute paire de MEME oeuvre (« editions, jamais doublons »). Or le critere
-- qui groupe une oeuvre est LE MEME que celui qui detecte un doublon : tout
-- vrai doublon assez net pour etre detecte a ete groupe sous la meme oeuvre
-- au backfill... et devient de ce fait invisible aux trois detecteurs.
-- « Aucun doublon detecte » sur deux fiches identiques a la ponctuation pres.
-- Au 31/08 : 77 paires de meme oeuvre indistinguables etaient masquees.
--
-- LE GESTE. La meme oeuvre ne masque plus une paire que si les EDITIONS sont
-- REELLEMENT distinguables : ISBN differents, ou annees differentes, ou
-- editeurs clairement differents, ou mentions d'edition differentes. Deux
-- fiches de la meme oeuvre qu'AUCUN de ces champs ne separe redeviennent des
-- candidates au doublon, presentees a l'arbitrage existant (balayage,
-- brouillons, fiche) -- rien n'est fusionne automatiquement ici.
--
-- ATTENTION ARBITRAGE : une paire indistinguable peut aussi etre deux tomes
-- d'un ouvrage en plusieurs volumes jamais renseignes (ex. L'Homme et la
-- Terre, 6 notices 1905 identiques a la BTL). C'est a l'arbitrage de trancher
-- (« pas un doublon » les ecarte definitivement) -- mais les MONTRER est
-- correct : la notice qui ne dit pas son tome est elle-meme a corriger.
--
-- Trois fonctions reprises a l'identique du live, seule la clause P4 change :
--   public.suggest_book_duplicates      (fiche publiee)
--   api.suggest_draft_duplicates        (file editoriale)
--   public.suggest_catalog_duplicates   (balayage du catalogue)
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Le juge commun : deux jeux de champs decrivent-ils des editions
--    distinguables ? (Normalisations identiques a celles des suggest_*.)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_editions_distinctes(
  p_isbn_a text, p_isbn_b text,
  p_ano_a text, p_ano_b text,
  p_editora_a text, p_editora_b text,
  p_edicao_a text, p_edicao_b text
) RETURNS boolean
LANGUAGE sql IMMUTABLE
SET search_path TO 'public', 'extensions', 'pg_catalog'
AS $function$
  WITH n AS (
    SELECT regexp_replace(upper(coalesce(p_isbn_a,'')),'[^0-9X]','','g') AS ia,
           regexp_replace(upper(coalesce(p_isbn_b,'')),'[^0-9X]','','g') AS ib,
           nullif(btrim(coalesce(p_ano_a,'')),'')  AS aa,
           nullif(btrim(coalesce(p_ano_b,'')),'')  AS ab,
           public.fn_normalize_name(coalesce(p_editora_a,'')) AS ea,
           public.fn_normalize_name(coalesce(p_editora_b,'')) AS eb,
           public.fn_normalize_name(coalesce(p_edicao_a,''))  AS da,
           public.fn_normalize_name(coalesce(p_edicao_b,''))  AS db
  )
  SELECT (ia <> '' AND ib <> '' AND ia <> ib)
      OR (aa IS NOT NULL AND ab IS NOT NULL AND aa <> ab)
      OR (ea <> '' AND eb <> '' AND similarity(ea, eb) < 0.75)
      OR (da <> '' AND db <> '' AND da <> db)
  FROM n;
$function$;

REVOKE ALL ON FUNCTION public.fn_editions_distinctes(text,text,text,text,text,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_editions_distinctes(text,text,text,text,text,text,text,text) TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 2. suggest_book_duplicates : P4 raffine
-- ---------------------------------------------------------------------
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
  select regexp_replace(upper(coalesce(b.isbn,'')),'[^0-9X]','','g'), public.fn_normalize_name(b.titulo), public.fn_normalize_name(b.autor), b.work_id,
         b.ano, b.editora, b.edicao
    into v_isbn, v_title, v_author, v_work, v_ano, v_editora, v_edicao from public.books b where b.id=p_book_id;
  if v_title is null then return; end if;
  return query
  with other as (
    select b.id,b.titulo,b.autor,b.ano,b.editora,b.isbn,b.work_id,b.edicao,
           regexp_replace(upper(coalesce(b.isbn,'')),'[^0-9X]','','g') as ni,
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

-- ---------------------------------------------------------------------
-- 3. api.suggest_draft_duplicates : meme raffinement, cote brouillons
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.suggest_draft_duplicates(p_draft_id bigint)
 RETURNS TABLE(candidate_id bigint, source text, titulo text, subtitulo text, autor text, ano text, editora text, isbn text, cdd text, colecao text, idioma text, tipo_material text, match_kind text, score real)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_catalog'
AS $function$
declare v_isbn text; v_title text; v_author text; v_lib uuid; v_pub bigint; v_work bigint;
        v_ano text; v_editora text; v_edicao text;
begin
  if not exists (select 1 from public.user_library_memberships m where m.user_id=auth.uid() and m.role=any(array['librarian'::text,'coordenador'::text])) then
    raise exception 'Acesso restrito ao staff de catalogacao.'; end if;
  select regexp_replace(upper(coalesce(d.isbn,'')),'[^0-9X]','','g'), public.fn_normalize_name(d.titulo), public.fn_normalize_name(d.autor), d.owner_library_id, d.published_book_id,
         d.ano, d.editora, d.edicao
    into v_isbn, v_title, v_author, v_lib, v_pub, v_ano, v_editora, v_edicao from public.book_drafts d where d.id=p_draft_id;
  if v_title is null then return; end if;
  select b.work_id into v_work from public.books b where b.id = v_pub;
  return query
  with cand as (
    select d.id as cid,'draft'::text as src,d.titulo,d.subtitulo,d.autor,d.ano,d.editora,d.isbn,d.cdd,d.colecao,d.idioma,d.tipo_material,
           null::bigint as cwork, d.edicao as cedicao,
           regexp_replace(upper(coalesce(d.isbn,'')),'[^0-9X]','','g') as ni, public.fn_normalize_name(d.titulo) as nt, public.fn_normalize_name(d.autor) as na
    from public.book_drafts d where d.status='draft' and d.id<>p_draft_id and (v_lib is null or d.owner_library_id=v_lib)
    union all
    select b.id,'book'::text,b.titulo,b.subtitulo,b.autor,b.ano,b.editora,b.isbn,b.cdd,b.colecao,b.idioma,b.tipo_material,
           b.work_id, b.edicao,
           regexp_replace(upper(coalesce(b.isbn,'')),'[^0-9X]','','g'), public.fn_normalize_name(b.titulo), public.fn_normalize_name(b.autor)
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

-- ---------------------------------------------------------------------
-- 4. suggest_catalog_duplicates : le balayage voit aussi ces paires
-- ---------------------------------------------------------------------
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
           regexp_replace(upper(coalesce(a.isbn,'')),'[^0-9X]','','g') as isbn_a,
           regexp_replace(upper(coalesce(b.isbn,'')),'[^0-9X]','','g') as isbn_b,
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
           -- AJOUT PERIODIQUES P3 : de quoi reconnaitre deux fascicules d'une
           -- meme revue, et savoir si leurs designations different.
           a.serial_id as serial_a, b.serial_id as serial_b,
           a.issue_key as issue_a,  b.issue_key as issue_b
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
      -- AJOUT PERIODIQUES P3. Deux fascicules d'un meme periodique ne sont pas
      -- des doublons des lors que leur designation differe. S'ils portent la
      -- MEME designation, la detection reste active : c'est alors un vrai
      -- doublon de saisie, et c'est le plus frequent sur un import.
      and not (
            r.serial_a is not null
        and r.serial_b = r.serial_a
        and r.issue_a is not null and r.issue_b is not null
        and r.issue_a <> r.issue_b
      )
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

-- ---------------------------------------------------------------------
-- 5. Verifications structurelles (sans donnees : passe en CI)
-- ---------------------------------------------------------------------
DO $$
BEGIN
  -- Le juge des editions : indistinguables => false, distinguables => true.
  IF public.fn_editions_distinctes(null, null, '1992', '1992', 'Achiame', 'Achiamé', null, null) THEN
    RAISE EXCEPTION 'fn_editions_distinctes : meme annee + meme editeur devrait etre indistinguable';
  END IF;
  IF NOT public.fn_editions_distinctes(null, null, '1992', '1995', 'Achiame', 'Achiame', null, null) THEN
    RAISE EXCEPTION 'fn_editions_distinctes : annees differentes devraient distinguer';
  END IF;
  IF NOT public.fn_editions_distinctes('978-85-1', '978-85-2', null, null, null, null, null, null) THEN
    RAISE EXCEPTION 'fn_editions_distinctes : ISBN differents devraient distinguer';
  END IF;
  IF public.fn_editions_distinctes(null, null, '1992', null, 'Achiame', '', null, null) THEN
    RAISE EXCEPTION 'fn_editions_distinctes : un champ absent d''un cote ne distingue pas';
  END IF;
  -- anon ne gagne rien au passage.
  IF has_function_privilege('anon', 'public.fn_editions_distinctes(text,text,text,text,text,text,text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'fn_editions_distinctes ne doit pas etre executable par anon';
  END IF;
END $$;

COMMIT;
