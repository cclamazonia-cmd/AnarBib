-- =========================================================================
-- Notice 2272 « Da Democracia à Liberdade » (0000066) — le Coletivo de
-- Ex-Trabalhadores est co-auteur, avec CrimethInc.
-- =========================================================================
-- Date     : 2026-09-05
-- Chantier : conventions / autorites — suite du rapport reseau du 05/09
-- Auteur   : coordination AnarBib (arbitrage Xavier, 05/09/2026 :
--            « 2272 : auteurs, ou mieux co-auteurs »)
--
-- CONV-8 (03/09) avait laisse ce contributeur sans fiche : « traducteurs ou
-- auteurs ? ». C'est tranche : co-auteurs. Le collectif recoit sa fiche
-- (collectivite) et garde la premiere place, telle que la notice le credite ;
-- CrimethInc. (fiche 10175, editeur du texte original) devient le second
-- auteur. Il n'existe pas de role « coautor » dans l'usage de
-- book_contributors (autor, organizador, tradutor, prefaciador…) : deux
-- lignes « autor » disent la co-autorite. La transcription suit.
--
-- Liste fermee, gestes conditionnels (sur une base fraiche : rien), traces.
-- =========================================================================

begin;

do $$
declare v_book public.books%rowtype; v_col bigint; v_n int := 0;
begin
  select * into v_book from public.books where id = 2272;
  if v_book.id is null then
    raise notice 'Notice 2272 absente (base fraiche) : rien a faire.';
    return;
  end if;

  -- La fiche du collectif (retrouvee ou creee).
  v_col := public.fn_conv_autorite_homonyme('Coletivo de Ex-Trabalhadores');
  if v_col is null then
    insert into public.authors (preferred_name, sort_name, authority_type, source_kind, source_label)
    values ('Coletivo de Ex-Trabalhadores', 'Coletivo de Ex-Trabalhadores', 'collective', 'conv_revue', 'Arbitrage 2272 (05/09/2026)')
    returning id into v_col;
    v_n := v_n + 1;
  end if;

  -- Le contributeur existant se lie ; sinon il est cree en premiere place.
  if exists (select 1 from public.book_contributors c where c.book_id = 2272 and c.name = 'Coletivo de Ex-Trabalhadores') then
    update public.book_contributors c
       set author_id = v_col, role = 'autor', position = 1, is_primary = true, updated_at = now()
     where c.book_id = 2272 and c.name = 'Coletivo de Ex-Trabalhadores';
  else
    insert into public.book_contributors (book_id, author_id, name, role, position, is_primary)
    values (2272, v_col, 'Coletivo de Ex-Trabalhadores', 'autor', 1, true);
  end if;

  -- CrimethInc. en second auteur, si sa fiche existe et n'y est pas deja.
  if exists (select 1 from public.authors where id = 10175)
     and not exists (select 1 from public.book_contributors c where c.book_id = 2272 and c.author_id = 10175) then
    insert into public.book_contributors (book_id, author_id, name, role, position, is_primary)
    values (2272, 10175, 'CrimethInc.', 'autor', 2, false);
    v_n := v_n + 1;
  end if;

  -- La table derivee, remise d'aplomb pour ce livre.
  delete from public.book_authors ba where ba.book_id = 2272;
  insert into public.book_authors (book_id, author_id, role, ord)
  select c.book_id, c.author_id, c.role, c.position::smallint
    from public.book_contributors c where c.book_id = 2272 and c.author_id is not null
  on conflict (book_id, author_id, role, ord) do nothing;

  update public.books set autor = 'Coletivo de Ex-Trabalhadores ; CrimethInc.', updated_at = now() where id = 2272;

  insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, label, details)
  values (null, 'update', 'book', 2272, 'Coletivo de Ex-Trabalhadores ; CrimethInc.',
          jsonb_build_object('via', 'migration arbitrage 2272 (05/09/2026)',
                             'raison', 'co-auteurs : le collectif (fiche creee ou retrouvee) et CrimethInc. — arbitrage Xavier',
                             'avant_autor', v_book.autor, 'collective_author_id', v_col));
  raise notice 'Notice 2272 : co-auteurs poses (fiche collectif %, % creation(s)).', v_col, v_n;
end $$;

commit;
