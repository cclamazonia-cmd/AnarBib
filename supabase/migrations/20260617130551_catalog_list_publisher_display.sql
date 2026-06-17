-- =========================================================================
-- Liste OPAC — colonne dérivée publisher_display (éditeur/distributeur/label)
-- =========================================================================
-- Date     : 2026-06-17
-- Chantier : Catalogação / cohérence supports non écrits (#CAT-EDITEUR-AV-AUDIO)
-- Auteur   : Xavier + Claude
-- Session  : File éditoriale — tri & supports AV
--
-- OBJET
-- -----
-- La liste catalogue (vues api.catalog_list_anon_v1 / catalog_list_session_v1,
-- minces au-dessus des SRF private.fn_catalog_*_rows() = SELECT * FROM MV)
-- n'exposait que `editora`. On ajoute une colonne dérivée `publisher_display`
-- adaptée au support : distributeur (audiovisuel) / maison de disques (audio) /
-- éditeur (écrits), avec repli sur editora si le champ dédié est vide (legacy).
--
-- MÉTHODE
-- -------
-- Pas de rebuild de MV (cascade lourde) : une fonction scalaire SECURITY DEFINER
-- private.fn_publisher_display(book_id) lit books, et chaque vue api l'appelle en
-- colonne supplémentaire (append → CREATE OR REPLACE VIEW l'autorise). Patches
-- idempotents (gardés sur la présence de la colonne publisher_display).
-- =========================================================================

begin;

-- 1) Fonction scalaire (SECURITY DEFINER : lit books au-delà de la RLS, comme
--    les SRF du catalogue public). Repli COALESCE sur editora.
create or replace function private.fn_publisher_display(p_book_id bigint)
returns text
language sql stable security definer
set search_path to 'public', 'pg_catalog'
as $fn$
  select case b.tipo_material
           when 'audiovisual' then coalesce(b.distribuidora, b.editora)
           when 'audio'       then coalesce(b.gravadora, b.editora)
           else b.editora
         end
  from public.books b where b.id = p_book_id
$fn$;
revoke execute on function private.fn_publisher_display(bigint) from public;
grant  execute on function private.fn_publisher_display(bigint) to anon, authenticated;

-- 2) Vue publique (anon) : append publisher_display.
do $patch$
declare q text;
begin
  if (select count(*) from information_schema.columns
        where table_schema='api' and table_name='catalog_list_anon_v1' and column_name='publisher_display') = 0 then
    select pg_get_viewdef('api.catalog_list_anon_v1'::regclass, true) into q;
    q := replace(q,
      E'holding_library_names_json\n   FROM private.fn_catalog_public_rows()',
      E'holding_library_names_json,\n    private.fn_publisher_display(book_id) AS publisher_display\n   FROM private.fn_catalog_public_rows()');
    execute 'create or replace view api.catalog_list_anon_v1 with (security_invoker=true) as ' || q;
  end if;
end
$patch$;

-- 3) Vue session (authentifié·e) : append publisher_display (book_id qualifié m).
do $patch$
declare q text;
begin
  if (select count(*) from information_schema.columns
        where table_schema='api' and table_name='catalog_list_session_v1' and column_name='publisher_display') = 0 then
    select pg_get_viewdef('api.catalog_list_session_v1'::regclass, true) into q;
    q := replace(q,
      E'session_loanable\n   FROM private.fn_catalog_network_rows()',
      E'session_loanable,\n    private.fn_publisher_display(m.book_id) AS publisher_display\n   FROM private.fn_catalog_network_rows()');
    execute 'create or replace view api.catalog_list_session_v1 with (security_invoker=true) as ' || q;
  end if;
end
$patch$;

notify pgrst, 'reload schema';

commit;

-- =========================================================================
-- Rollback : drop function private.fn_publisher_display(bigint) cascade n'est
-- PAS recommandé (casserait les vues). Restaurer les vues sans la colonne via
-- pg_get_viewdef + suppression de la ligne publisher_display, puis drop function.
-- =========================================================================
