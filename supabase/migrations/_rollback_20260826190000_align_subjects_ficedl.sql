-- ============================================================================
-- ROLLBACK de 20260826190000_align_subjects_ficedl.sql
--
-- Reversibilite partielle -- lire avant d'executer.
--
--   REVERSIBLE   : les 51 liens subject_ficedl_links (la table etait vide
--                  avant la migration, on peut donc la revider sans perte).
--   REVERSIBLE   : le statut 'depreciado' des sujets 43 et 58.
--   NON REVERSIBLE : la fusion des indexations. book_subjects a ete bascule
--                  de 43 vers 4 et de 58 vers 50, et UNE indexation en double
--                  (un livre portait a la fois 43 et 4) a ete supprimee.
--                  Rien en base ne permet de savoir quels livres venaient de
--                  43 ou de 58. Restaurer exige une sauvegarde anterieure au
--                  26/08/2026.
-- ============================================================================

begin;

-- 1. Retrait des liens
delete from public.subject_ficedl_links;

-- 2. Reactivation des deux sujets fusionnes
update public.subjects
   set status = 'ativo', updated_at = now()
 where id in (43, 58);

-- 3. Verification
do $$
declare n_links int; n_act int;
begin
  select count(*) into n_links from public.subject_ficedl_links;
  select count(*) into n_act from public.subjects
   where id in (43, 58) and status = 'ativo';
  raise notice 'liens restants : % / sujets reactives : %', n_links, n_act;
  if n_links <> 0 or n_act <> 2 then
    raise exception 'rollback incomplet';
  end if;
  raise notice 'ATTENTION : les indexations fusionnees ne sont PAS restaurees.';
end $$;

commit;
