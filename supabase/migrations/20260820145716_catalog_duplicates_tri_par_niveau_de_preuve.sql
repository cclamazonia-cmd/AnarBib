-- suggest_catalog_duplicates : trier par NIVEAU DE PREUVE, plus par similarite.
--
-- POURQUOI. Le tri par similarite de titre est un mauvais signal. Mesure du
-- 2026-08-20 sur les 266 paires : 135 sont sous 0.75, et cette bande est pleine
-- de faux positifs (titres generiques, tomes d'une serie, oeuvres differentes au
-- titre proche). Surtout, dans la bande la PLUS sure — titre normalise identique
-- — deux paires sur cinq n'etaient pas des doublons mais deux EDITIONS
-- distinctes (MORYON 2008 Terramar contre MORIYON 1985 Cincel) : les fusionner
-- aurait detruit une notice legitime, irreversiblement.
--
-- Ce qui distingue reellement un doublon d'une edition differente, ce n'est pas
-- le titre : c'est la coincidence du titre AVEC l'annee ET l'editeur. Deux
-- notices qui partagent les trois sont presque toujours la meme edition saisie
-- deux fois (coquille d'auteur : FERRUA/FERROA, GUYAU M./GUYAU J.M., MTD/
-- « Movimento dos Trabalhadores Desempregados »). Deux notices au meme titre
-- mais d'annee ou d'editeur different sont presque toujours deux editions — et
-- l'action juste pour elles est « Meme oeuvre », pas la fusion.
--
-- Effet mesure du nouveau tri : 3 paires ISBN, puis 2 en titre+annee+editeur,
-- puis 7 en titre+annee, puis 254 en titre seul. La revue passe d'une liste
-- illisible de 266 a une douzaine de paires examinables en quelques minutes.
--
-- CE QUI NE CHANGE PAS. Les regles de DETECTION sont identiques — memes paires,
-- meme ensemble. Seuls l'ordre et deux colonnes d'explication changent. On ne
-- fusionne rien automatiquement : le niveau de preuve informe la decision, il ne
-- la prend pas. Meme en tete de liste il reste des pieges — MLEG-0016 et
-- MLEG-0017 (« A Guerra Civil Espanhola ») sont deux VOLUMES, pas un doublon —
-- et merge_book conserve les metadonnees de la seule notice survivante :
-- choisir la mauvaise fait disparaitre une attribution bibliographique. Ce n'est
-- pas un choix qu'une regle peut faire.
--
-- `score` et `match_kind` sont conserves tels quels : l'interface existante s'en
-- sert, et une migration de tri ne doit pas casser un appelant. Le DROP est
-- impose par l'ajout de colonnes en sortie (42P13) ; il est dans la meme
-- transaction que le CREATE, donc sans fenetre d'indisponibilite.
drop function if exists public.suggest_catalog_duplicates(integer);

create function public.suggest_catalog_duplicates(p_max integer default 500)
returns table(
  book_id_a bigint, ref_a text, titulo_a text, autor_a text, ano_a text,
  bibliotecas_a text, exemplares_a integer,
  book_id_b bigint, ref_b text, titulo_b text, autor_b text, ano_b text,
  bibliotecas_b text, exemplares_b integer,
  match_kind text, score real, configuration text, fusion_possible boolean,
  niveau_preuve text, rang_preuve integer
)
language plpgsql
stable
security definer
set search_path to 'public', 'extensions', 'pg_catalog'
as $fn$
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
           a.work_id as work_a, b.work_id as work_b
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
      and not (r.work_a is not null and r.work_b = r.work_a)
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
end $fn$;

comment on function public.suggest_catalog_duplicates(integer) is
  'Balayage global des doublons du catalogue publie. Memes regles de detection que suggest_book_duplicates. Trie par NIVEAU DE PREUVE (isbn > titre+annee+editeur > titre+annee > titre seul) et non par similarite : deux notices au meme titre mais d''annee ou d''editeur different sont presque toujours deux EDITIONS, pour lesquelles l''action juste est « Meme oeuvre » et non la fusion. Distingue aussi les doublons INTERNES (fusion legitime) des INTER-BIBLIOTHEQUES (mutualisation). Staff de catalogage uniquement.';

revoke all on function public.suggest_catalog_duplicates(integer) from public, anon;
grant execute on function public.suggest_catalog_duplicates(integer) to authenticated, service_role;
