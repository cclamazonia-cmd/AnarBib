-- ============================================================================
-- CAPAS · la page 1 des PDF : l'administration du réseau choisit la bibliothèque
-- Foyer : spec-module-capas · Session : Anarchief — capas page 1 des PDF
-- Date : 2026-10-20
--
-- POURQUOI. Le bloc « Page 1 des PDF » (20261020203753) travaille sur la
-- bibliothèque courante du Painel, et le Painel ne se place que sur une
-- bibliothèque où le compte a une adhésion. Vécu le soir même du déploiement :
-- l'administration du réseau, qui importe et suit le fonds d'Anarchief.org, n'y
-- est pas coordinatrice — le bloc lui montrait BLMF, et les 609 notices restaient
-- hors de portée. Les trois RPC acceptent pourtant déjà l'administration du
-- réseau pour toute bibliothèque (garde de api.capas_pdf_resume / _liste,
-- fn_capas_dans_le_perimetre pour _poser).
--
-- CE QUE FAIT CETTE MIGRATION — une RPC, administration du réseau seulement :
--   api.capas_pdf_bibliotheques() : les bibliothèques qui détiennent au moins
--   une notice sans couverture avec un PDF versé et actif, avec ce décompte et
--   celui des PDF restreints seulement. L'écran en fait un choix, visible des
--   seuls admins réseau ; le reste de la passe est inchangé.
--
-- Décision de Xavier, 20/10/2026 (entre « la coordination d'Anarchief clique »,
-- « me rattacher à Anarchief » et ce sélecteur) : pas d'adhésion de complaisance
-- à la bibliothèque d'un autre collectif — l'acte reste celui du réseau.
--
-- Suite : tests/sql/capas_pdf_tests.sql (T10).
-- ============================================================================
begin;

create or replace function api.capas_pdf_bibliotheques()
returns table (library_id uuid, nom text, faisables integer, restreintes integer)
language plpgsql
stable
security definer
set search_path to 'public', 'pg_catalog'
as $function$
#variable_conflict use_column
begin
  if not public.fn_caller_is_network_admin() then
    raise exception 'Acesso restrito a administracao da rede.' using errcode = '42501', hint = 'error.catalog.staff_only';
  end if;

  return query
  with n as (
    select h.library_id,
           exists (select 1 from public.book_digital_resources r
                    where r.book_id = b.id and r.storage_bucket = 'anarbib-pdf-public'
                      and r.status = 'active' and coalesce(r.is_active, true)
                      and (r.mime_type = 'application/pdf' or r.storage_path ~* '\.pdf$')) as pdf_public,
           exists (select 1 from public.book_digital_resources r
                    where r.book_id = b.id and r.storage_bucket is not null
                      and r.status = 'active' and coalesce(r.is_active, true)
                      and (r.mime_type = 'application/pdf' or r.storage_path ~* '\.pdf$')) as pdf_verse
      from public.books b
      join public.book_holdings h on h.book_id = b.id
     where nullif(btrim(coalesce(b.cover_object_path, '')), '') is null
  )
  select l.id,
         coalesce(nullif(l.short_name, ''), l.name),
         (count(*) filter (where n.pdf_verse))::integer,
         (count(*) filter (where n.pdf_verse and not n.pdf_public))::integer
    from n
    join public.libraries l on l.id = n.library_id
   group by l.id, l.short_name, l.name
  having count(*) filter (where n.pdf_verse) > 0
   order by 3 desc, 2;
end;
$function$;

comment on function api.capas_pdf_bibliotheques() is
  'Capas page 1 (20/10/2026) : pour l''administration du réseau, les bibliothèques ayant des notices sans couverture avec un PDF versé, et combien (dont restreintes).';

revoke execute on function api.capas_pdf_bibliotheques() from public, anon;
grant execute on function api.capas_pdf_bibliotheques() to authenticated;

notify pgrst, 'reload schema';

commit;
