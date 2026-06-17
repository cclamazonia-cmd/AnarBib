-- supabase/migrations/20260617054114_publib_public_libraries_logo_file_key.sql
-- Session : Gazette Rizoma & Lettre federation
-- Chantier PUBLIB (REGISTRE §31) — expose lc.logo_file_key dans api.public_libraries.
-- But : l'annuaire /bibliotecas + la fiche affichent le VRAI logo défini dans
-- l'onglet « Identité et fonctionnement » (library_commons.logo_file_key, Storage
-- themes/<key>/logo-<key>.png), résolu côté front par resolveLibraryLogo — et pas
-- seulement logo_url (souvent NULL → repli initiales).
-- CREATE OR REPLACE VIEW : colonnes existantes inchangées (même ordre/types), ajout
-- de logo_file_key EN FIN (contrainte CoR). security_invoker conservé. Grants
-- anon/authenticated conservés par CoR + re-grant idempotent. logo_file_key = clé
-- d'asset public (logo), non sensible. Idempotent.

create or replace view api.public_libraries
with (security_invoker = true) as
  select l.id, l.slug, l.name, l.short_name, l.city, l.state, l.country,
    lc.affiliation_label, lc.website_url, lc.logo_url,
    l.catalog_mode, l.circulation_mode,
    (select count(distinct bh.book_id) from public.book_holdings bh where bh.library_id = l.id) as notices_count,
    case when l.catalog_mode = 'network_published'::text and l.circulation_mode = 'full_sigb'::text
         then 'automatizado'::text else 'em_construcao'::text end as catalog_status,
    lc.logo_file_key
  from public.libraries l
    left join public.library_commons lc on lc.library_id = l.id
  where l.is_active = true and l.visibility_level = 'public'::text;

grant select on api.public_libraries to anon, authenticated;

notify pgrst, 'reload schema';
