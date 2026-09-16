-- =========================================================================
-- AnarBib — La gazette s'appelle « Fractale », plus « Rizoma »
-- =========================================================================
-- Date     : 2026-09-16
-- Chantier : Gazette — renommage (GAZ-10)
--
-- POURQUOI
--   « Rizoma » est déjà le nom du journal d'un collectif catalan rencontré à
--   Bologne (13/09/2026) ; on ne garde pas le nom d'un journal camarade. Le
--   nouveau nom, « Fractale », est celui d'une forme dont chaque partie
--   contient le tout — chaque bibliothèque est le réseau en petit. Décision
--   Xavier, 16/09/2026 (REGISTRE §29 GAZ-10).
--
-- CE QUE FAIT CETTE MIGRATION
--   Les numéros déjà parus (n°01–04) portent « Rizoma » dans leur bandeau
--   (gazette_issues.masthead_title). Décision : la gazette a UN SEUL nom,
--   archives comprises → on renomme aussi les anciens numéros. Données
--   seulement : aucune table, colonne, fonction ni vue touchée. Idempotent.
--   Les slugs (n02-2026-07), l'emblème et le contenu des locales ne bougent
--   pas — le nom ne s'y trouve pas.
--
--   Le code (EF gazette-monthly-build, panneau, onglet, mail-strings, 3 clés
--   × 10 locales) est renommé dans le même commit.
-- =========================================================================

begin;

update public.gazette_issues
   set masthead_title = replace(masthead_title, 'Rizoma', 'Fractale')
 where masthead_title like '%Rizoma%';

do $$
declare
  v_n int;
begin
  select count(*) into v_n from public.gazette_issues where masthead_title like '%Rizoma%';
  if v_n <> 0 then
    raise exception 'ECHEC : % numéro(s) portent encore « Rizoma »', v_n;
  end if;
  select count(*) into v_n from public.gazette_issues where masthead_title like 'Fractale%';
  raise notice 'OK : % numéro(s) au nom de Fractale (0 en CI, base reconstruite : normal).', v_n;
end $$;

commit;
