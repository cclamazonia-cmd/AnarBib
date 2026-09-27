-- ============================================================================
-- Un doublon que la détection ne voyait pas, et la suggestion d'éditions qui
-- n'a jamais répondu — relevés ensemble par Xavier le 27/09/2026 sur la notice
-- BTL-TL-000880 (« Da Escravidão nos Estados Unidos », Élisée Reclus).
--
-- 1. LA SUGGESTION D'ÉDITIONS. `suggest_editions_for_book` plantait à CHAQUE
--    appel depuis sa création (20260620103632) : « column reference "book_id"
--    is ambiguous » (42702) — `book_authors.book_id` et la colonne de sortie de
--    la fonction portent le même nom. Relevé dans les journaux PostgREST à
--    19:15 et 19:24 UTC ; à l'écran : « Erreur technique (42702) ». Correctif :
--    requête qualifiée. Le reste de la fonction est repris tel qu'il est en
--    production (pg_get_functiondef du 27/09), sans autre changement.
--
-- 2. LA FUSION. Deux notices pour le même livre, venues de deux éléments du
--    Zotero de la BTL (880 et 881) : même titre, même autrice·eur, même éditeur,
--    même œuvre ; l'une en 2010 avec ISBN, l'autre en 2011 sans ISBN. La
--    détection ne les propose pas (même œuvre + années différentes = éditions
--    distinctes, règle du 31/08) et l'écran n'a aucun chemin pour une paire
--    qu'elle ne propose pas. Décision de Xavier : fusionner, « conserve toutes
--    les données possibles ; l'année restera celle de la première édition ».
--
--    NOTICE GARDÉE : BTL-TL-000881 (2010, ISBN 9788579350085, exemplaires BTL
--    et BLMF). `merge_book` est gardée par fn_is_dedup_arbiter() (auth.uid),
--    injoignable en migration : on reprend ses étapes pour CETTE paire (modèle
--    20260903182352), et on y ajoute ce qu'elle perd :
--      - les champs vides de la notice gardée sont remplis par ceux du doublon
--        (ici : la couverture) ; ceux qu'elle a (année 2010, ISBN, trace
--        d'import) restent ;
--      - les sujets et contributeur·rices du doublon qui lui manquent sont
--        repris (merge_book les laisse partir en cascade) ;
--      - l'exemplaire du doublon prend la référence de la notice gardée : la
--        conversion réservation → prêt cherche les exemplaires PAR bib_ref, et
--        un exemplaire resté sous l'ancienne référence ne serait jamais servi ;
--      - le brouillon ouvert sur le doublon (identique à la notice) est écarté,
--        pas rattaché : publié plus tard sur la notice gardée, il l'aurait
--        écrasée avec « 2011, sans ISBN » ;
--      - ce que merge_book laisse orphelin suit aussi (partages numériques,
--        pistes audio, titre d'œuvre, lignes d'import) ;
--      - la notice supprimée est gardée ENTIÈRE dans merge_log.details : ligne
--        complète, sujets, contributeur·rices, contexte, fonds (avec sa
--        référence locale BTL-TL-000880), exemplaires, brouillons.
--    Garde : rien n'est fait (NOTICE) si les deux notices ne sont pas celles
--    attendues — une base rejouée depuis zéro ne les a pas.
--
-- Suite : tests/sql/editions_suggerees_tests.sql.
-- ============================================================================
begin;

-- ── 1 · La suggestion d'éditions ───────────────────────────────────────────
create or replace function public.suggest_editions_for_book(p_book_id bigint)
 returns table(book_id bigint, titulo text, ano text, editora text, isbn text, work_id bigint, score real)
 language plpgsql
 security definer
 set search_path to 'public', 'extensions', 'pg_catalog'
as $function$
declare v_title text; v_author bigint; v_work bigint;
begin
  if not exists (select 1 from public.user_library_memberships m
                 where m.user_id = auth.uid() and m.role = any(array['librarian','coordenador']) and m.status='active') then
    raise exception 'Apenas bibliotecárias e coordenadoras podem editar o catálogo.'
      using errcode='42501', hint='error.catalog.discard.forbidden';
  end if;

  select public.fn_normalize_name(b.titulo), b.work_id into v_title, v_work from public.books b where b.id = p_book_id;
  if v_title is null or v_title = '' then return; end if;
  -- Qualifiée (27/09/2026) : `book_id` seul désignait aussi la colonne de sortie.
  select ba.author_id into v_author from public.book_authors ba
   where ba.book_id = p_book_id and ba.role = 'autor' order by ba.ord limit 1;
  if v_author is null then return; end if; -- besoin d'un auteur·rice principal·e pour regrouper

  return query
  select b.id, b.titulo, b.ano, b.editora, b.isbn, b.work_id,
         similarity(public.fn_normalize_name(b.titulo), v_title)::real
  from public.books b
  where b.id <> p_book_id
    and exists (select 1 from public.book_authors ba
                where ba.book_id = b.id and ba.role='autor' and ba.author_id = v_author)
    -- pas déjà dans la même œuvre que la notice courante
    and not (v_work is not null and b.work_id is not null and b.work_id = v_work)
    and similarity(public.fn_normalize_name(b.titulo), v_title) >= 0.35
  order by 7 desc, b.titulo
  limit 30;
end;
$function$;

-- ── 2 · La fusion BTL-TL-000880 → BTL-TL-000881 ────────────────────────────
do $$
declare
  c_garde   constant bigint := 822;   -- BTL-TL-000881 : 2010, ISBN, exemplaires BTL et BLMF
  c_doublon constant bigint := 821;   -- BTL-TL-000880 : 2011, sans ISBN, couverture, un sujet
  v_g       public.books%rowtype;
  v_d       public.books%rowtype;
  v_col     text;
  v_n       int;
  v_repris  text[] := '{}';
  v_snap    jsonb;
  dh        record;
  v_ch      bigint;
begin
  select * into v_g from public.books where id = c_garde for update;
  select * into v_d from public.books where id = c_doublon for update;
  if v_g.id is null or v_d.id is null
     or v_g.bib_ref is distinct from 'BTL-TL-000881' or v_d.bib_ref is distinct from 'BTL-TL-000880'
     or v_g.work_id is distinct from v_d.work_id
     or public.fn_normalize_name(v_g.titulo) is distinct from public.fn_normalize_name(v_d.titulo) then
    raise notice 'Fusion BTL-TL-000880 → BTL-TL-000881 : notices absentes ou changées, rien à faire.';
    return;
  end if;

  -- 0. La notice qui va disparaître, gardée entière.
  v_snap := jsonb_build_object(
    'raison', 'Doublon non détecté : même œuvre, années 2010 / 2011, deux éléments du Zotero de la BTL (880, 881). '
              || 'Fusion demandée par Xavier le 27/09/2026 : garder toutes les données, l''année de la première édition.',
    'duplicate_titulo', v_d.titulo,
    'notice', to_jsonb(v_d),
    'sujets', (select coalesce(jsonb_agg(to_jsonb(s) order by s.ord), '[]'::jsonb)
                 from public.book_subjects s where s.book_id = c_doublon),
    'contributeurs', (select coalesce(jsonb_agg(to_jsonb(x) order by x.position), '[]'::jsonb)
                        from public.book_contributors x where x.book_id = c_doublon),
    'contexte_catalogage', (select to_jsonb(x) from public.book_catalog_context x where x.book_id = c_doublon),
    'fonds', (select coalesce(jsonb_agg(to_jsonb(h)), '[]'::jsonb) from public.book_holdings h where h.book_id = c_doublon),
    'exemplaires', (select coalesce(jsonb_agg(to_jsonb(e)), '[]'::jsonb)
                      from public.exemplares e join public.book_holdings h on h.id = e.holding_id
                     where h.book_id = c_doublon),
    'brouillons', (select coalesce(jsonb_agg(jsonb_build_object('id', d.id, 'status', d.status, 'action', d.action)), '[]'::jsonb)
                     from public.book_drafts d where d.published_book_id = c_doublon));

  -- 1. Les champs : ce que la notice gardée n'a pas, le doublon le donne ; ce
  --    qu'elle a reste. Jamais les champs que la fusion ne reprend pas.
  for v_col in
    select c.column_name from information_schema.columns c
     where c.table_schema = 'public' and c.table_name = 'books' and c.is_generated = 'NEVER'
       and c.column_name <> all (public.fn_dedup_non_transferable_fields())
     order by c.ordinal_position
  loop
    execute format(
      'update public.books g set %1$I = d.%1$I from public.books d
        where g.id = $1 and d.id = $2
          and nullif(btrim(coalesce(g.%1$I::text, '''')), '''') is null
          and nullif(btrim(coalesce(d.%1$I::text, '''')), '''') is not null', v_col)
      using c_garde, c_doublon;
    get diagnostics v_n = row_count;
    if v_n > 0 then v_repris := v_repris || v_col; end if;
  end loop;

  -- 2. Sujets et contributeur·rices du doublon qui manquent à la notice gardée.
  insert into public.book_subjects (book_id, subject_id, ord)
  select c_garde, s.subject_id,
         coalesce((select max(t.ord) from public.book_subjects t where t.book_id = c_garde), 0)
           + row_number() over (order by s.ord, s.subject_id)
    from public.book_subjects s
   where s.book_id = c_doublon
     and not exists (select 1 from public.book_subjects t where t.book_id = c_garde and t.subject_id = s.subject_id);
  get diagnostics v_n = row_count;
  if v_n > 0 then v_repris := v_repris || ('sujets:' || v_n); end if;

  insert into public.book_contributors (book_id, author_id, position, name, role, is_primary)
  select c_garde, x.author_id,
         coalesce((select max(t.position) from public.book_contributors t where t.book_id = c_garde), 0)
           + row_number() over (order by x.position, x.id),
         x.name, x.role, false
    from public.book_contributors x
   where x.book_id = c_doublon
     and not exists (select 1 from public.book_contributors t
                      where t.book_id = c_garde
                        and coalesce(t.role, '') = coalesce(x.role, '')
                        and (t.author_id = x.author_id
                             or (x.author_id is null
                                 and public.fn_normalize_name(t.name) = public.fn_normalize_name(x.name))));
  get diagnostics v_n = row_count;
  if v_n > 0 then v_repris := v_repris || ('contributeurs:' || v_n); end if;

  -- 3. Brouillons : l'ouvert est écarté, les autres suivent la notice gardée.
  update public.book_drafts set status = 'cancelled'
   where published_book_id = c_doublon and status not in ('published', 'cancelled');
  update public.book_drafts set published_book_id = c_garde where published_book_id = c_doublon;

  -- 4. Fonds et exemplaires : les étapes de merge_book, puis la référence.
  for dh in select * from public.book_holdings where book_id = c_doublon loop
    select id into v_ch from public.book_holdings
     where book_id = c_garde and library_id = dh.library_id limit 1;
    if v_ch is not null then
      update public.exemplares                 set holding_id = v_ch where holding_id = dh.id;
      update public.emprestimo_itens_v2        set holding_id = v_ch where holding_id = dh.id;
      update public.reserva_linhas_v2          set holding_id = v_ch where holding_id = dh.id;
      update public.interlibrary_loan_items_v2 set holding_id = v_ch where holding_id = dh.id;
      update public.consulta_linhas_v2         set holding_id = v_ch where holding_id = dh.id;
      update public.exemplar_drafts            set target_holding_id = v_ch where target_holding_id = dh.id;
      delete from public.book_holdings where id = dh.id;
    else
      update public.book_holdings set book_id = c_garde where id = dh.id;
    end if;
    v_ch := null;
  end loop;
  update public.exemplares e set bib_ref = v_g.bib_ref
    from public.book_holdings h
   where h.id = e.holding_id and h.book_id = c_garde and e.bib_ref = v_d.bib_ref;

  -- 5. Tout ce qui désigne encore le doublon suit la notice gardée.
  update public.emprestimo_itens_v2        set book_id = c_garde where book_id = c_doublon;
  update public.reserva_linhas_v2          set book_id = c_garde where book_id = c_doublon;
  update public.interlibrary_loan_items_v2 set book_id = c_garde where book_id = c_doublon;
  update public.consulta_linhas_v2         set book_id = c_garde where book_id = c_doublon;
  update public.digital_assets             set book_id = c_garde where book_id = c_doublon;
  update public.audio_tracks               set book_id = c_garde where book_id = c_doublon;
  update public.ill_digital_shares         set book_id = c_garde where book_id = c_doublon;
  update public.work_titles                set source_book_id = c_garde where source_book_id = c_doublon;
  update ingest.partner_catalog_staging_rows set proposed_book_id = c_garde where proposed_book_id = c_doublon;
  delete from public.user_wishlist w
   where w.book_id = c_doublon
     and exists (select 1 from public.user_wishlist w2 where w2.user_id = w.user_id and w2.book_id = c_garde);
  update public.user_wishlist set book_id = c_garde where book_id = c_doublon;

  -- 6. La trace, puis la suppression.
  insert into public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
  values ('book', c_garde, c_doublon, v_snap || jsonb_build_object('champs_repris', to_jsonb(v_repris)), null);
  delete from public.books where id = c_doublon;
  perform public.fn_v2_recompute_holdings_availability(null, array[c_garde]);

  -- 7. Vérification : tout ce qui devait arriver est arrivé.
  select * into v_g from public.books where id = c_garde;
  if exists (select 1 from public.books where id = c_doublon) then
    raise exception 'fusion : le doublon existe encore';
  end if;
  if v_g.ano is distinct from '2010' or v_g.isbn is distinct from '9788579350085' then
    raise exception 'fusion : année ou ISBN de la notice gardée modifiés (%, %)', v_g.ano, v_g.isbn;
  end if;
  if nullif(btrim(coalesce(v_d.cover_object_path, '')), '') is not null
     and v_g.cover_object_path is distinct from v_d.cover_object_path then
    raise exception 'fusion : la couverture n''a pas été reprise';
  end if;
  if exists (select 1 from jsonb_array_elements(v_snap->'sujets') s
              where not exists (select 1 from public.book_subjects t
                                 where t.book_id = c_garde and t.subject_id = (s->>'subject_id')::bigint)) then
    raise exception 'fusion : un sujet du doublon manque';
  end if;
  if exists (select 1 from jsonb_array_elements(v_snap->'exemplaires') x
              where not exists (select 1 from public.exemplares e join public.book_holdings h on h.id = e.holding_id
                                 where e.id = (x->>'id')::bigint and h.book_id = c_garde and e.bib_ref = v_g.bib_ref)) then
    raise exception 'fusion : un exemplaire du doublon n''a pas suivi';
  end if;
  if exists (select 1 from public.book_drafts d
              where d.published_book_id = c_garde and d.status not in ('published', 'cancelled')
                and d.id in (select (b->>'id')::bigint from jsonb_array_elements(v_snap->'brouillons') b)) then
    raise exception 'fusion : un brouillon ouvert du doublon a été rattaché à la notice gardée';
  end if;
  raise notice 'Fusion BTL-TL-000880 → BTL-TL-000881 faite ; repris : %', v_repris;
end $$;

commit;
