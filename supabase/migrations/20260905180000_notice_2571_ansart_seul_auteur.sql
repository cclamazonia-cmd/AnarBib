-- =========================================================================
-- Notice 2571 « Estudos Proudhonianos » (MLEG-0114) — Proudhon est le sujet,
-- Pierre Ansart le seul auteur
-- =========================================================================
-- Date     : 2026-09-05
-- Chantier : conventions / autorites — suite du rapport reseau du 05/09
-- Auteur   : coordination AnarBib (arbitrage Xavier, 05/09/2026 :
--            « Pour 2571, Proudhon est le sujet, Ansart le seul auteur »)
--
-- Le paquet 20260905160000 avait fait de Pierre Ansart un contributeur (il
-- n'etait que dans book_authors) et laisse Proudhon en auteur, faute de
-- savoir. C'est tranche : Proudhon sort des contributeurs, Ansart devient
-- l'auteur primaire, la transcription suit. Aucune vedette-matiere
-- « Proudhon » n'existe dans le thesaurus : la creer est un geste de
-- gouvernance des matieres, pas une migration.
--
-- Liste fermee, gestes conditionnels (sur une base fraiche : rien), traces.
-- book_authors est reecrit pour ce livre : le trigger ne suit pas un
-- changement de POSITION, et la ligne d'Ansart existait deux fois (ord 6
-- de juin, ord 3 du 05/09).
-- =========================================================================

begin;

do $$
declare v_book public.books%rowtype; v_n int := 0;
begin
  select * into v_book from public.books where id = 2571;
  if v_book.id is null then
    raise notice 'Notice 2571 absente (base fraiche) : rien a faire.';
    return;
  end if;

  -- Proudhon (autorite 29) quitte les contributeurs de cette notice.
  if exists (select 1 from public.book_contributors c where c.book_id = 2571 and c.author_id = 29) then
    delete from public.book_contributors c where c.book_id = 2571 and c.author_id = 29;
    v_n := v_n + 1;
  end if;

  -- Ansart (autorite 10068) : seul auteur, primaire, en tete.
  if exists (select 1 from public.book_contributors c where c.book_id = 2571 and c.author_id = 10068) then
    update public.book_contributors c
       set position = 1, is_primary = true, role = 'autor', updated_at = now()
     where c.book_id = 2571 and c.author_id = 10068;
  else
    insert into public.book_contributors (book_id, author_id, name, role, position, is_primary)
    values (2571, 10068, 'Ansart, Pierre', 'autor', 1, true);
  end if;

  -- La table derivee, remise d'aplomb pour ce livre.
  delete from public.book_authors ba where ba.book_id = 2571;
  insert into public.book_authors (book_id, author_id, role, ord)
  select c.book_id, c.author_id, c.role, c.position::smallint
    from public.book_contributors c where c.book_id = 2571 and c.author_id is not null
  on conflict (book_id, author_id, role, ord) do nothing;

  -- La transcription suit l'arbitrage.
  update public.books set autor = 'Pierre Ansart', updated_at = now() where id = 2571;

  insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, label, details)
  values (null, 'update', 'book', 2571, 'Pierre Ansart',
          jsonb_build_object('via', 'migration arbitrage 2571 (05/09/2026)',
                             'raison', 'Proudhon est le sujet, Ansart le seul auteur — arbitrage Xavier',
                             'avant_autor', v_book.autor, 'proudhon_retire', v_n = 1));
  raise notice 'Notice 2571 : Ansart seul auteur, Proudhon retire (%).', v_n;
end $$;

commit;
