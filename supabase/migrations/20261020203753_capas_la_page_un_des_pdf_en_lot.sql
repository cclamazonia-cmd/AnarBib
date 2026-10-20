-- ============================================================================
-- CAPAS · la page 1 des PDF, en lot
-- Foyer : spec-module-capas · Session : Anarchief — capas page 1 des PDF
-- Date : 2026-10-20
--
-- POURQUOI. Anarchief.org est une archive numérique : 1 002 notices publiées
-- le 20/10, AUCUNE couverture, et les catalogues ouverts n'ont rien pour des
-- brochures, tracts et périodiques. Mais 609 d'entre elles portent un PDF
-- versé dans Storage (569 publics, 40 restreints seulement), et la page 1 d'un
-- PDF EST sa couverture. Le bouton
-- « page 1 du PDF » du formulaire de catalogage (capas P3) le savait déjà —
-- notice par notice : reprendre en brouillon, cliquer, enregistrer, publier.
-- 609 fois. Comme pour la photo prise en rayon (20260927182008), le geste
-- passe du formulaire au Painel, onglet « Couvertures », et de la notice au lot.
--
-- CE QUE FAIT CETTE MIGRATION — trois RPC (staff de la bibliothèque, ou
-- administration du réseau) :
--   1. api.capas_pdf_resume(biblio) : combien de notices détenues sans
--      couverture ont un PDF versé (faisables), dont combien n'ont qu'un PDF à
--      diffusion restreinte, et combien portent déjà une page 1 ;
--   2. api.capas_pdf_liste(biblio, n, exclure) : les prochaines faisables, avec
--      le PDF à rendre (un PDF public d'abord, puis le principal, puis le plus
--      ancien — le seau dit au navigateur comment le lire). `exclure`
--      porte les notices dont le PDF n'a pas pu être rendu pendant la passe :
--      sans lui, un fichier illisible resterait en tête de liste et la passe
--      tournerait sur place ;
--   3. api.capas_pdf_poser(notice, chemin) : attache l'image (déjà rangée par le
--      navigateur sous un nom neuf `capa-…` dans le dossier de la notice),
--      provenance « pdf_page1 », celle que le formulaire pose déjà. Jamais de
--      remplacement : une couverture posée entre-temps (photo, lot, à la main)
--      gagne, réponse « deja_une_capa » et rien n'est écrit.
--
-- LES PDF RESTREINTS AUSSI — décision de Xavier, 20/10/2026. Le bucket
-- `covers` est PUBLIC et une capa se sert à 800 px de large : la page 1 d'un
-- PDF de `pdf-restrito` (sans accord de diffusion, NUMDIF) devient donc une
-- image publique — pour un tract d'une page, le tract entier. La question a été
-- posée avec ce risque en face ; la réponse a été de les inclure. L'écran
-- annonce combien de faisables n'ont qu'un PDF restreint, pour que le geste
-- reste conscient ; une capa se retire à tout moment depuis le formulaire.
--
-- Le rendu se fait dans le navigateur (pdf.js, src/lib/capaPdf.js), comme le
-- bouton du formulaire : aucune dépendance serveur nouvelle, rien qui ne
-- tourne sur une pile auto-hébergée.
--
-- Suite : tests/sql/capas_pdf_tests.sql.
-- ============================================================================
begin;

create or replace function api.capas_pdf_resume(p_library_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v jsonb;
begin
  if not (public.fn_caller_is_network_admin()
          or public.user_has_library_staff_role((select auth.uid()), p_library_id)) then
    raise exception 'Acesso restrito ao staff de catalogacao.' using errcode = '42501', hint = 'error.catalog.staff_only';
  end if;

  with n as (
    select b.id,
           nullif(btrim(coalesce(b.cover_object_path, '')), '') is null as sans_capa,
           b.cover_source,
           exists (select 1 from public.book_digital_resources r
                    where r.book_id = b.id and r.storage_bucket = 'anarbib-pdf-public'
                      and r.status = 'active' and coalesce(r.is_active, true)
                      and (r.mime_type = 'application/pdf' or r.storage_path ~* '\.pdf$')) as pdf_public,
           exists (select 1 from public.book_digital_resources r
                    where r.book_id = b.id and r.storage_bucket is not null
                      and r.status = 'active' and coalesce(r.is_active, true)
                      and (r.mime_type = 'application/pdf' or r.storage_path ~* '\.pdf$')) as pdf_verse
      from public.books b
      join public.book_holdings h on h.book_id = b.id and h.library_id = p_library_id
  )
  select jsonb_build_object(
           'faisables',   count(*) filter (where sans_capa and pdf_verse),
           'restreintes', count(*) filter (where sans_capa and pdf_verse and not pdf_public),
           'posees',      count(*) filter (where not sans_capa and cover_source = 'pdf_page1'))
    into v
    from n;

  return v;
end;
$function$;

create or replace function api.capas_pdf_liste(p_library_id uuid, p_limite integer default 20,
                                               p_exclure bigint[] default '{}'::bigint[])
returns table (book_id bigint, bib_ref text, titulo text, storage_bucket text, storage_path text)
language plpgsql
stable
security definer
set search_path to 'public', 'pg_catalog'
as $function$
#variable_conflict use_column
begin
  if not (public.fn_caller_is_network_admin()
          or public.user_has_library_staff_role((select auth.uid()), p_library_id)) then
    raise exception 'Acesso restrito ao staff de catalogacao.' using errcode = '42501', hint = 'error.catalog.staff_only';
  end if;

  return query
  select b.id, b.bib_ref, b.titulo, r.storage_bucket, r.storage_path
    from public.books b
    join public.book_holdings h on h.book_id = b.id and h.library_id = p_library_id
    join lateral (
      select r.storage_bucket, r.storage_path
        from public.book_digital_resources r
       where r.book_id = b.id and r.storage_bucket is not null
         and r.status = 'active' and coalesce(r.is_active, true)
         and (r.mime_type = 'application/pdf' or r.storage_path ~* '\.pdf$')
       order by (r.storage_bucket = 'anarbib-pdf-public') desc, coalesce(r.is_primary, false) desc, r.id
       limit 1
    ) r on true
   where nullif(btrim(coalesce(b.cover_object_path, '')), '') is null
     and not (b.id = any (coalesce(p_exclure, '{}'::bigint[])))
   order by b.id
   limit greatest(1, least(coalesce(p_limite, 20), 100));
end;
$function$;

create or replace function api.capas_pdf_poser(p_book_id bigint, p_object_path text)
returns text
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_admin boolean := public.fn_caller_is_network_admin();
  v_ids   uuid[]  := public.fn_caller_staff_library_ids();
  v_book  public.books%rowtype;
begin
  if not v_admin and cardinality(v_ids) = 0 then
    raise exception 'Acesso restrito ao staff de catalogacao.' using errcode = '42501', hint = 'error.catalog.staff_only';
  end if;

  select * into v_book from public.books where id = p_book_id for update;
  if not found or not public.fn_capas_dans_le_perimetre(v_book.id, v_book.owner_library_id, v_ids, v_admin) then
    raise exception 'capa_hors_perimetre' using errcode = '42501', hint = 'error.capas.hors_perimetre';
  end if;

  -- Dossier de CETTE notice (clé = bib_ref, sinon id, nettoyée comme par
  -- cleCapa dans src/lib/coverThumbs.js), nom neuf `capa-…` (REGISTRE CAPAS-4).
  if coalesce(p_object_path, '') !~ '^books/[A-Za-z0-9_-]{1,120}/capa-[a-z0-9]{1,20}\.jpg$'
     or split_part(p_object_path, '/', 2)
        <> left(regexp_replace(coalesce(nullif(v_book.bib_ref, ''), v_book.id::text), '[^A-Za-z0-9_-]', '_', 'g'), 120) then
    raise exception 'capa_chemin_invalide' using hint = 'error.capas.chemin_invalide';
  end if;

  -- La page 1 d'un PDF versé, actif : pas d'image sans le fichier dont elle vient.
  if not exists (select 1 from public.book_digital_resources r
                  where r.book_id = p_book_id and r.storage_bucket is not null
                    and r.status = 'active' and coalesce(r.is_active, true)
                    and (r.mime_type = 'application/pdf' or r.storage_path ~* '\.pdf$')) then
    raise exception 'capa_sans_pdf' using hint = 'error.capas.sans_pdf';
  end if;

  if nullif(btrim(coalesce(v_book.cover_object_path, '')), '') is not null then
    return 'deja_une_capa';
  end if;

  update public.books
     set cover_object_path = p_object_path,
         cover_source      = 'pdf_page1',
         cover_license     = null,
         updated_at        = now(),
         updated_by        = auth.uid()
   where id = p_book_id;

  -- Une proposition du lot qui attendait n'a plus d'objet.
  update public.cover_proposals
     set statut = 'perimee'
   where book_id = p_book_id and statut = 'a_revoir';

  return 'posee';
end;
$function$;

comment on function api.capas_pdf_resume(uuid) is
  'Capas page 1 (20/10/2026) : notices détenues sans couverture avec un PDF versé (faisables), dont celles au PDF restreint seulement, et pages 1 déjà posées.';
comment on function api.capas_pdf_liste(uuid, integer, bigint[]) is
  'Capas page 1 (20/10/2026) : les prochaines notices détenues sans couverture avec le PDF à rendre (public d''abord) ; p_exclure écarte celles dont le rendu a échoué pendant la passe.';
comment on function api.capas_pdf_poser(bigint, text) is
  'Capas page 1 (20/10/2026) : attache la page 1 rendue par le navigateur (provenance pdf_page1). Jamais de remplacement ; un PDF versé et actif exigé.';

revoke execute on function api.capas_pdf_resume(uuid) from public, anon;
revoke execute on function api.capas_pdf_liste(uuid, integer, bigint[]) from public, anon;
revoke execute on function api.capas_pdf_poser(bigint, text) from public, anon;
grant execute on function api.capas_pdf_resume(uuid) to authenticated;
grant execute on function api.capas_pdf_liste(uuid, integer, bigint[]) to authenticated;
grant execute on function api.capas_pdf_poser(bigint, text) to authenticated;

notify pgrst, 'reload schema';

commit;
