-- ============================================================================
-- C9 — les fiches d'autorité qui réunissent plusieurs personnes sont scindées
--
-- Fiche validée par Xavier le 27/09 (« tout, sauf 4955 ») :
-- docs/journal/arbitrages/C9_scissions_des_fiches_a_plusieurs_personnes_2026-09-27.md
-- Vaut reprise du verdict CONV-O8 (« pas de scission avant la quatrième fiche
-- double », dépassé : REGISTRE §37, MàJ du 03/09 nuit). Plus, sur sa parole du
-- même soir (« Sorel, G. est forcément Georges Sorel »), la fusion de la fiche
-- 11190 dans 10190.
--
-- Écrit EN SON PROPRE NOM : aucune colonne d'auteur n'est remplie, le journal des
-- fusions porte merged_by NULL et le motif. merge_author est réservée à une
-- arbitre connectée : ses gestes sont reproduits ici (et complétés : pistes
-- audio, que merge_author oublie ; book_authors vidé avant la suppression, sa
-- clé étrangère restreint).
--
-- Chaque fiche est retrouvée par son id ET son nom actuel ; nom changé → rien, et
-- une notice le dit. Une personne qui a déjà sa fiche est RELIÉE, jamais recréée.
-- La première personne sans fiche reprend la fiche double (même id : œuvres,
-- historique suivent) ; si toutes ont déjà leur fiche, la double est fusionnée
-- dans la première puis supprimée. Idempotente : rejouée, elle ne trouve plus les
-- noms d'origine et ne fait rien.
--
-- Section C : dix brouillons non publiés reçoivent une contribution par personne
-- (le champ « auteur » ne change pas) ; le brouillon 4955 est laissé, faute de
-- certitude.
-- ============================================================================
begin;

-- ── Outils de la migration (schéma temporaire, disparaissent avec la session) ──
create function pg_temp.c9_fusionner(p_canon bigint, p_dup bigint, p_motif text)
returns void language plpgsql as $f$
declare v_nom text; v_canon text;
begin
  select preferred_name into v_nom from public.authors where id = p_dup;
  select preferred_name into v_canon from public.authors where id = p_canon;
  if v_nom is null or v_canon is null then raise exception 'C9 : fusion %→% impossible', p_dup, p_canon; end if;
  -- un livre déjà lié à la fiche gardée ne la reçoit pas deux fois
  delete from public.book_contributors d
   where d.author_id = p_dup
     and exists (select 1 from public.book_contributors c where c.book_id = d.book_id and c.author_id = p_canon);
  update public.book_contributors set author_id = p_canon, name = v_canon, updated_at = now() where author_id = p_dup;
  insert into public.book_authors (book_id, author_id, role, ord)
    select book_id, p_canon, role, ord from public.book_authors where author_id = p_dup
    on conflict do nothing;
  delete from public.book_authors where author_id = p_dup;
  update public.author_translations t set author_id = p_canon
   where t.author_id = p_dup
     and not exists (select 1 from public.author_translations c where c.author_id = p_canon and c.lang = t.lang);
  update public.author_name_aliases set author_id = p_canon where author_id = p_dup;
  update public.author_drafts set published_author_id = p_canon where published_author_id = p_dup;
  update public.book_draft_contributors set author_id = p_canon where author_id = p_dup;
  update public.audio_track_contributors set author_id = p_canon where author_id = p_dup;
  update public.works set primary_author_id = p_canon where primary_author_id = p_dup;
  insert into public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
  values ('author', p_canon, p_dup,
          jsonb_build_object('duplicate_preferred_name', v_nom, 'motif', p_motif), null);
  delete from public.authors where id = p_dup;
end $f$;

create function pg_temp.c9_personne(p_id bigint, p_pref text, p_sort text, p_type text, p_source text)
returns bigint language plpgsql as $f$
declare v bigint;
begin
  if p_id is not null then
    if not exists (select 1 from public.authors where id = p_id) then
      raise exception 'C9 : fiche existante % introuvable', p_id;
    end if;
    return p_id;
  end if;
  insert into public.authors (preferred_name, sort_name, authority_type, structured_meta, source_label)
  values (p_pref, p_sort, p_type, jsonb_build_object('authorityType', p_type), p_source)
  returning id into v;
  return v;
end $f$;

create function pg_temp.c9_ajouter(p_book bigint, p_author bigint, p_role text)
returns void language plpgsql as $f$
begin
  if exists (select 1 from public.book_contributors where book_id = p_book and author_id = p_author) then return; end if;
  insert into public.book_contributors (book_id, author_id, position, name, role, is_primary)
  select p_book, p_author,
         coalesce((select max(position) from public.book_contributors where book_id = p_book), 0) + 1,
         (select preferred_name from public.authors where id = p_author), p_role, false;
end $f$;

-- ── A. Dix scissions ───────────────────────────────────────────────────────
do $$
declare
  s record; p jsonb; v_parts jsonb; v_books bigint[]; v_p0 int; v_cible0 bigint; v_cibles bigint[];
  v_role text; v_b bigint; v_t bigint; v_i int; v_noms text; v_faites int := 0;
begin
  for s in select * from jsonb_to_recordset($j$[
    {"src":10709,"avant":"Ibáñez, Salvador Gurucharri y Tomás","role":null,"autor":["IBÁÑEZ, Salvador Gurucharri y Tomás"],
     "parts":[{"id":10683,"pref":"Salvador Gurucharri","sort":"Gurucharri, Salvador"},{"id":10090,"pref":"Tomás Ibáñez","sort":"Ibáñez, Tomás"}]},
    {"src":10748,"avant":"KAISER, William Young and David E.","role":null,"autor":["KAISER, William Young and David E."],
     "parts":[{"id":null,"pref":"William Young","sort":"Young, William"},{"id":null,"pref":"David E. Kaiser","sort":"Kaiser, David E."}]},
    {"src":10942,"avant":"Musté, Ignacio Vidal y Pedro Costa","role":null,"autor":["MUSTÉ, Ignacio Vidal y Pedro Costa"],
     "parts":[{"id":null,"pref":"Ignacio Vidal","sort":"Vidal, Ignacio"},{"id":null,"pref":"Pedro Costa Musté","sort":"Costa Musté, Pedro"}]},
    {"src":11035,"avant":"Philopat, Duka e Marco","role":null,"autor":["PHILOPAT, Duka e Marco","PHILOPAT, Duka e Marco PhilopatMarco"],
     "parts":[{"id":null,"pref":"Duka","sort":"Duka"},{"id":11037,"pref":"Marco Philopat","sort":"Philopat, Marco"}]},
    {"src":11359,"avant":"Antonio Serra & Cristina Pereira","role":null,"autor":["Antonio Serra & Cristina Pereira"],
     "parts":[{"id":null,"pref":"Antonio Serra","sort":"Serra, Antonio"},{"id":null,"pref":"Cristina Pereira","sort":"Pereira, Cristina"}]},
    {"src":11376,"avant":"Bookchin, Janet Biehl/Murray","role":null,"autor":["Bookchin, Janet Biehl/Murray"],
     "parts":[{"id":10335,"pref":"Janet Biehl","sort":"Biehl, Janet"},{"id":10,"pref":"Murray Bookchin","sort":"Bookchin, Murray"}]},
    {"src":11389,"avant":"Doris Accioly e Silva, Sonia Alem Marrach (Org.)","role":"organizador","autor":["Doris Accioly e Silva, Sonia Alem Marrach (Org.)"],
     "parts":[{"id":null,"pref":"Sonia Alem Marrach","sort":"Marrach, Sonia Alem"},{"id":null,"pref":"Doris Accioly e Silva","sort":"Silva, Doris Accioly e"}]},
    {"src":11420,"avant":"Giorgio Sacchetti, Augusto Gayubas, Manuel Vicent Balaguer, Ignacio Donézar, José Luis Gutiérrez Molina","role":null,
     "autor":["Giorgio Sacchetti, Augusto Gayubas, Manuel Vicent Balaguer, Ignacio Donézar, José Luis Gutiérrez Molina"],
     "parts":[{"id":11134,"pref":"Giorgio Sacchetti","sort":"Sacchetti, Giorgio"},{"id":null,"pref":"Augusto Gayubas","sort":"Gayubas, Augusto"},
              {"id":null,"pref":"Manuel Vicent Balaguer","sort":"Vicent Balaguer, Manuel"},{"id":null,"pref":"Ignacio Donézar","sort":"Donézar, Ignacio"},
              {"id":null,"pref":"José Luis Gutiérrez Molina","sort":"Gutiérrez Molina, José Luis"}]},
    {"src":11424,"avant":"Durval Muniz de Albuquerque Júnior, Alfredo Veiga-Neto, Alípio de Souza Filho (orgs.)","role":"organizador",
     "autor":["Durval Muniz de Albuquerque Júnior, Alfredo Veiga-Neto, Alípio de Souza Filho (orgs.)"],
     "parts":[{"id":null,"pref":"Durval Muniz de Albuquerque Júnior","sort":"Albuquerque Júnior, Durval Muniz de"},
              {"id":null,"pref":"Alfredo Veiga-Neto","sort":"Veiga-Neto, Alfredo"},{"id":null,"pref":"Alípio de Souza Filho","sort":"Souza Filho, Alípio de"}]},
    {"src":11475,"avant":"MORAES, Carla Kelen de Andrade. Acioli, Edane de Jesus França et al.","role":null,
     "autor":["MORAES, Carla Kelen de Andrade. Acioli, Edane de Jesus França et al."],
     "parts":[{"id":null,"pref":"Carla Kelen de Andrade Moraes","sort":"Moraes, Carla Kelen de Andrade"},
              {"id":null,"pref":"Edane de Jesus França Acioli","sort":"Acioli, Edane de Jesus França"}]}
  ]$j$::jsonb) as x(src bigint, avant text, role text, autor jsonb, parts jsonb)
  loop
    if not exists (select 1 from public.authors where id = s.src and sort_name = s.avant) then
      raise notice 'C9 : fiche % absente ou renommée — sautée', s.src;
      continue;
    end if;
    select array_agg(distinct book_id) into v_books from public.book_contributors where author_id = s.src;
    v_books := coalesce(v_books, '{}');
    -- la première personne sans fiche reprend la fiche double
    select (i - 1)::int into v_p0 from jsonb_array_elements(s.parts) with ordinality e(p, i)
     where e.p ->> 'id' is null order by i limit 1;
    v_cibles := '{}';
    if v_p0 is not null then
      p := s.parts -> v_p0;
      update public.authors
         set preferred_name = p ->> 'pref', sort_name = p ->> 'sort', authority_type = 'person',
             structured_meta = jsonb_set(coalesce(structured_meta, '{}'::jsonb), '{authorityType}', '"person"', true),
             updated_at = now()
       where id = s.src;
      update public.book_contributors set name = p ->> 'pref', updated_at = now() where author_id = s.src;
      v_cible0 := s.src;
    else
      v_p0 := 0;
      v_cible0 := (s.parts -> 0 ->> 'id')::bigint;
      perform pg_temp.c9_fusionner(v_cible0, s.src, 'C9 · scission : « ' || s.avant || ' » réunissait plusieurs personnes');
    end if;
    -- les autres personnes, liées à chaque livre, dans l'ordre de la fiche
    for v_i in 0 .. jsonb_array_length(s.parts) - 1 loop
      p := s.parts -> v_i;
      if v_i = v_p0 then v_t := v_cible0;
      else v_t := pg_temp.c9_personne((p ->> 'id')::bigint, p ->> 'pref', p ->> 'sort', 'person', 'C9 · scission de la fiche ' || s.src);
      end if;
      v_cibles := v_cibles || v_t;
      foreach v_b in array v_books loop
        select coalesce(s.role, c.role, 'autor') into v_role from public.book_contributors c
         where c.book_id = v_b and c.author_id = v_cible0 limit 1;
        perform pg_temp.c9_ajouter(v_b, v_t, coalesce(v_role, s.role, 'autor'));
      end loop;
    end loop;
    if s.role is not null then
      update public.book_contributors set role = s.role, updated_at = now()
       where book_id = any (v_books) and author_id = any (v_cibles);
    end if;
    -- le champ libre, seulement s'il dit encore exactement l'ancien texte
    select string_agg(e.p ->> 'sort', ' ; ' order by e.i) into v_noms
      from jsonb_array_elements(s.parts) with ordinality e(p, i);
    update public.books set autor = v_noms
     where id = any (v_books) and autor in (select jsonb_array_elements_text(s.autor));
    v_faites := v_faites + 1;
  end loop;
  raise notice 'C9 : % fiche(s) scindée(s)', v_faites;
end $$;

-- ── B. Trois corrections sans scission, et Sorel ───────────────────────────
update public.authors set preferred_name = 'Aline Ludmila', sort_name = 'Ludmila, Aline', updated_at = now()
 where id = 11448 and sort_name = 'LUDMILA, Aline (et al.)';
update public.book_contributors set name = 'Aline Ludmila', updated_at = now()
 where author_id = 11448 and name <> 'Aline Ludmila';
update public.authors set preferred_name = 'Beatriz Silvério', sort_name = 'Silvério, Beatriz', updated_at = now()
 where id = 11540 and sort_name = 'SILVÉRIO, Beatriz (et al.)';
update public.book_contributors set name = 'Beatriz Silvério', updated_at = now()
 where author_id = 11540 and name <> 'Beatriz Silvério';
update public.authors
   set authority_type = 'collective',
       structured_meta = jsonb_set(coalesce(structured_meta, '{}'::jsonb), '{authorityType}', '"collective"', true),
       updated_at = now()
 where id = 11457 and sort_name = 'Noir et Rouge';

do $$
begin
  if exists (select 1 from public.authors where id = 11190 and sort_name = 'Sorel, G.')
     and exists (select 1 from public.authors where id = 10190 and sort_name = 'Sorel, Georges') then
    perform pg_temp.c9_fusionner(10190, 11190, 'C9 · « Sorel, G. » est Georges Sorel (décision de Xavier, 27/09)');
  else
    raise notice 'C9 : Sorel déjà fusionné ou renommé — rien';
  end if;
end $$;

-- ── C. Dix brouillons : une contribution par personne ─────────────────────
do $$
declare d record; v_i int; c jsonb; v_n int := 0;
begin
  for d in select * from jsonb_to_recordset($j$[
    {"id":116,"autor":"Errico Malatesta e Luigi Fabbri","c":[{"n":"Errico Malatesta","a":4},{"n":"Luigi Fabbri","a":10031}]},
    {"id":278,"autor":"Karl Marx & Engels","c":[{"n":"Karl Marx","a":25},{"n":"Friedrich Engels","a":26}]},
    {"id":418,"autor":"G.Sorel/E.berth/H.Lagardelle/S. Pannunzio/V. Griffuelhes/P. Delesalles/E. Pouget",
     "c":[{"n":"Georges Sorel","a":10190},{"n":"Édouard Berth","a":null},{"n":"Hubert Lagardelle","a":null},{"n":"Sergio Panunzio","a":null},
          {"n":"Victor Griffuelhes","a":null},{"n":"Paul Delesalle","a":null},{"n":"Émile Pouget","a":11055}]},
    {"id":4726,"autor":"Bruno Astarian et Robert Ferro","c":[{"n":"Bruno Astarian","a":null},{"n":"Robert Ferro","a":null}]},
    {"id":4866,"autor":"Cédric Biagini, David Murray et Pierre Thiesset","c":[{"n":"Cédric Biagini","a":null},{"n":"David Murray","a":null},{"n":"Pierre Thiesset","a":null}]},
    {"id":4917,"autor":"Bella et Roger Belbéoch","c":[{"n":"Bella Belbéoch","a":null},{"n":"Roger Belbéoch","a":null}]},
    {"id":5771,"autor":"André et Dori Prudhomeaux","c":[{"n":"André Prudhommeaux","a":null},{"n":"Dori Prudhommeaux","a":null}]},
    {"id":5786,"autor":"A. et D. Prudhommeaux","c":[{"n":"André Prudhommeaux","a":null},{"n":"Dori Prudhommeaux","a":null}]},
    {"id":5842,"autor":"Jaime Balius & Amigos de Durruti","c":[{"n":"Jaime Balius","a":null},{"n":"Amigos de Durruti","a":null}]},
    {"id":5862,"autor":"Informations et Correspondances Ouvrières","c":[{"n":"Informations et Correspondances Ouvrières","a":null}]}
  ]$j$::jsonb) as x(id bigint, autor text, c jsonb)
  loop
    if not exists (select 1 from public.book_drafts where id = d.id and autor = d.autor and status not in ('published', 'cancelled'))
       or exists (select 1 from public.book_draft_contributors where draft_id = d.id) then
      raise notice 'C9 : brouillon % publié, modifié ou déjà pourvu — sauté', d.id;
      continue;
    end if;
    for v_i in 0 .. jsonb_array_length(d.c) - 1 loop
      c := d.c -> v_i;
      insert into public.book_draft_contributors (draft_id, position, name, role, is_primary, author_id)
      values (d.id, v_i + 1, c ->> 'n', 'autor', v_i = 0,
              case when (c ->> 'a') is not null and exists (select 1 from public.authors where id = (c ->> 'a')::bigint)
                   then (c ->> 'a')::bigint end);
    end loop;
    v_n := v_n + 1;
  end loop;
  raise notice 'C9 : % brouillon(s) pourvu(s) de leurs contributions', v_n;
end $$;

-- ── Vérification ──────────────────────────────────────────────────────────
do $$
begin
  if exists (select 1 from public.authors where id in (10709, 10748, 10942, 11035, 11359, 11376, 11389, 11420, 11424, 11475, 11448, 11540)
              and (sort_name ~ '(;|&|/| and | y | et |\met al\M)' or sort_name ~ ' e [[:upper:]]'
                   or (length(sort_name) - length(replace(sort_name, ',', ''))) > 1)) then
    raise exception 'C9 : une fiche à plusieurs personnes subsiste';
  end if;
  if exists (select 1 from public.authors where id = 11190) and exists (select 1 from public.authors where id = 10190 and sort_name = 'Sorel, Georges') then
    raise exception 'C9 : « Sorel, G. » n''est pas fusionné';
  end if;
  if exists (select 1 from public.book_authors ba where not exists (select 1 from public.authors a where a.id = ba.author_id)) then
    raise exception 'C9 : un lien livre-autorité pointe dans le vide';
  end if;
end $$;

commit;
