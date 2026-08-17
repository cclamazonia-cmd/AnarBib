-- Performance fiche livre, 2e passe : sort le calcul des dates de retour de la vue.
--
-- Contexte. Apres la reecriture en LATERAL (20260817022450), la vue restait
-- assez couteuse pour saturer l'instance sous concurrence : ~77 ms de
-- PLANIFICATION et ~68 ms d'execution par fiche. Mesure du detail (17/08), role
-- authenticated, RLS active, avec l'enrobage PostgREST :
--
--   fonds reduits a book_holdings + libraries ......  2,8 ms
--   noyau bibliographique ......................... 40,3 ms
--   fonds avec les dates de retour ................ 79,0 ms
--   idem sans les tombos .......................... 79,0 ms  <- les tombos ne coutent RIEN
--
-- Autrement dit, la quasi-totalite du cout des fonds vient des deux LATERAL qui
-- lisent emprestimo_itens_v2 (date de retour, par livre et par holding). La
-- raison : la politique RLS de cette table fait un EXISTS qui traverse
-- api.my_access, une vue lourde ; son expansion doit etre PLANIFIEE a chaque
-- requete, deux fois. Les compteurs de disponibilite, eux, sont deja
-- denormalises sur book_holdings et ne coutent rien.
--
-- Correctif : le calcul passe dans une fonction dont le corps est planifie une
-- fois puis mis en cache par session. Elle est SECURITY DEFINER pour ne pas
-- faire derouler la RLS a l'appelant, mais elle REJOUE EXPLICITEMENT la meme
-- regle de visibilite que emprestimo_itens_v2_select_policy (emprunt personnel
-- OU acces painel sur la biblio de l'emprunt) : aucun elargissement de ce qui
-- est visible. Point verifie specifiquement, car un simple SECURITY DEFINER
-- aurait rendu les dates de retour visibles au public, ce qu'elles ne sont pas
-- aujourd'hui (anon et lecteur non concerne ne voient AUCUNE ligne d'emprunt).
--
-- Verification : avec un emprunt ouvert temporaire (cree puis annule), sous
-- anon (NULL des deux cotes), sous l'emprunteur et sous le staff (meme date) :
-- ligne entiere identique dans les trois cas, JSON des fonds compris. Et sur
-- les 2 677 livres : 0 difference. NB : le type de earliest_due_back_at est
-- `date` (comme emprestimo_itens_v2.due_at), PAS timestamptz — un premier jet
-- castait en timestamptz et changeait le contrat de l'API.
--
-- Resultat mesure : 144,5 ms -> 42,5 ms par fiche, dont la planification
-- 76,9 -> 22,4 ms. Sous charge, le parcours complet passe de 12-18 req/s avec
-- 2,5-4 % d'erreurs (et 30-90 % d'echecs sur la fiche) a 68 req/s sans aucune
-- erreur a 40 usagers simultanes, et ~100 req/s a 80-120.

create or replace function public.fn_book_due_dates(p_book_id bigint)
returns jsonb
language sql
stable
security definer
set search_path to 'public', 'api', 'pg_temp'
as $$
  with visible as (
    select coalesce(ei.extended_until, ei.due_at) as due, ex.holding_id
    from emprestimo_itens_v2 ei
    join emprestimos_v2 e on e.id = ei.emprestimo_id
    left join exemplares ex on ex.id = ei.item_id
    where ei.book_id = p_book_id
      and ei.item_status = 'aberto'
      -- Meme predicat que emprestimo_itens_v2_select_policy.
      and ( e.user_id = (select auth.uid())
            or exists (select 1 from api.my_access ma
                        where ma.user_id = (select auth.uid())
                          and ma.can_access_painel = true
                          and ma.library_id = e.library_id) )
  )
  select jsonb_build_object(
    'global', (select min(due) from visible),
    'by_holding', coalesce((
        select jsonb_object_agg(x.holding_id::text, x.d)
        from (select holding_id, min(due) as d from visible
               where holding_id is not null group by holding_id) x), '{}'::jsonb));
$$;

comment on function public.fn_book_due_dates(bigint) is
  'Dates de retour (min global + min par holding) des exemplaires en pret d''un livre. SECURITY DEFINER pour eviter de planifier l''expansion de api.my_access dans chaque requete appelante, mais rejoue explicitement la regle de visibilite de emprestimo_itens_v2_select_policy : anon et lecteur non concerne obtiennent NULL, comme avant.';

revoke all on function public.fn_book_due_dates(bigint) from public;
grant execute on function public.fn_book_due_dates(bigint) to anon, authenticated, service_role;

create or replace view public.v_book_detail_public_v2 with (security_invoker = true) as
select
  b.id, b.id as book_id, b.bib_ref, b.autor, b.titulo, b.ano, b.editora, b.cdd,
  coalesce(b.loanable, true) as loanable,
  coalesce(hold.global_available_count, 0) as available_count,
  b.created_at, b.cover_object_path, b.subtitulo, b.edicao, b.local_publicacao,
  b.isbn, b.issn, b.idioma, b.paginas, b.notas, b.tipo_material,
  b.autores_secundarios, b.colecao, b.volume, b.assuntos, b.tradutor, b.organizador,
  fa.author_id, b.catalog_source,
  case when hold.bibliotecas_count = 1 then hold.single_library_id else null::uuid end as library_id,
  case when hold.bibliotecas_count = 1 then hold.single_library_slug else null::text end as library_slug,
  case when hold.bibliotecas_count = 1 then hold.single_library_name else null::text end as library_name,
  case when hold.bibliotecas_count = 1 then hold.single_library_name
       when hold.bibliotecas_count > 1 then hold.bibliotecas_count::text || ' bibliotecas'::text
       else null::text end as biblioteca,
  coalesce(df.has_online_reading, false) as has_online_reading,
  coalesce(c.author_display, b.autor) as author_display,
  coalesce(c.author_chips, '[]'::jsonb) as author_chips,
  coalesce(aj.authors_json, '[]'::jsonb) as authors_json,
  coalesce(hold.exemplares_total, 0) as exemplares_total,
  coalesce(hold.bibliotecas_count, 0) as bibliotecas_count,
  coalesce(hold.holding_libraries_json, '[]'::jsonb) as holding_libraries_json,
  coalesce(hold.tombos_json, '[]'::jsonb) as tombos_json,
  coalesce(hold.global_available_count, 0) as global_available_count,
  coalesce(b.available_count, 0) as legacy_available_count_global,
  coalesce(hold.exemplares_total, 0) as global_exemplares_total,
  (d.j ->> 'global')::date as earliest_due_back_at,
  b.distribuidora, b.gravadora,
  coalesce(bsa.subjects_json, '[]'::jsonb) as subjects_json
from books b
cross join lateral (select public.fn_book_due_dates(b.id) as j) d
left join lateral (select ba.author_id from book_authors ba
  where ba.book_id = b.id and ba.author_id is not null
  order by ba.ord, ba.author_id limit 1) fa on true
left join v_book_authors_canonical c on c.book_id = b.id
left join lateral (select jsonb_agg(jsonb_build_object(
    'author_id', abp.author_id,
    'display_name', coalesce(abp.author_name, abp.sort_name, abp.preferred_name),
    'preferred_name', abp.preferred_name, 'sort_name', abp.sort_name,
    'role', abp.role, 'ord', abp.ord) order by abp.ord, abp.author_id) as authors_json
  from author_books_public abp where abp.book_id = b.id) aj on true
left join lateral (select bool_or(r.resource_type = 'pdf_restrito'::text
    and r.usage_type = 'leitura_online'::text and r.access_scope = 'conta_ativa'::text
    and r.status = 'active'::text and coalesce(r.is_active, false) = true) as has_online_reading
  from book_digital_resources r where r.book_id = b.id) df on true
left join lateral (select jsonb_agg(jsonb_build_object('subject_id', s.id, 'slug', s.slug,
    'label_i18n', s.label_i18n) order by bs.ord, s.id) as subjects_json
  from book_subjects bs join subjects s on s.id = bs.subject_id
  where bs.book_id = b.id and s.status = 'ativo'::text) bsa on true
left join lateral (
  with he as (
    select h.id as holding_id, h.library_id, l.slug as library_slug, l.name as library_name,
           l.short_name, l.city, l.state,
           coalesce(nullif(btrim(h.local_bib_ref), ''::text), b.bib_ref) as local_bib_ref,
           coalesce(h.loanable, b.loanable, true) as holding_loanable,
           coalesce(h.exemplares_total, 0) as holding_exemplares_total,
           coalesce(h.available_count, 0) as holding_available_count,
           coalesce(exh.tombos_json, '[]'::jsonb) as tombos_json,
           (d.j -> 'by_holding' ->> h.id::text)::date as holding_earliest_due_back_at
    from book_holdings h
    join libraries l on l.id = h.library_id
    left join lateral (select jsonb_agg(e.tombo order by e.tombo)
        filter (where nullif(btrim(coalesce(e.tombo, ''::text)), ''::text) is not null) as tombos_json
      from exemplares e where e.holding_id = h.id) exh on true
    where h.book_id = b.id)
  select coalesce(sum(he.holding_exemplares_total), 0::bigint)::integer as exemplares_total,
         count(*)::integer as bibliotecas_count,
         coalesce(sum(he.holding_available_count), 0::bigint)::integer as global_available_count,
         jsonb_agg(jsonb_build_object('holding_id', he.holding_id, 'library_id', he.library_id,
           'library_slug', he.library_slug, 'library_name', he.library_name,
           'short_name', he.short_name, 'city', he.city, 'state', he.state,
           'local_bib_ref', he.local_bib_ref, 'loanable', he.holding_loanable,
           'available_count', he.holding_available_count, 'exemplares_total', he.holding_exemplares_total,
           'tombos_json', he.tombos_json, 'earliest_due_back_at', he.holding_earliest_due_back_at)
           order by he.library_name, he.library_slug, he.holding_id) as holding_libraries_json,
         (array_agg(he.library_id order by he.holding_id))[1] as single_library_id,
         (array_agg(he.library_slug order by he.holding_id))[1] as single_library_slug,
         (array_agg(he.library_name order by he.holding_id))[1] as single_library_name,
         (select jsonb_agg(x.tombo order by x.tombo)
            from (select jsonb_array_elements_text(he2.tombos_json) as tombo from he he2) x) as tombos_json
  from he) hold on true;

-- Nettoyage des prototypes de mesure (n'ont existe que sur la base distante).
drop view if exists public.zz_full_v2;
drop view if exists public.zz_core;
drop view if exists public.zz_fonds;
drop view if exists public.zz_fonds_notombos;
drop view if exists public.zz_fonds_min;
drop view if exists public.zz_fonds_v2;
drop function if exists public.zz_due(bigint);
drop function if exists public.zz_due2(bigint);
