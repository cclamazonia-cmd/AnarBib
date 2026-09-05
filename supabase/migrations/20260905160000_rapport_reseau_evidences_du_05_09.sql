-- =========================================================================
-- Paquet rapport-reseau-evidences-du-05-09 — ce que le rapport general du
-- 05/09/2026 montrait encore, et qui se corrige
-- =========================================================================
-- Date     : 2026-09-05
-- Chantier : conventions / autorites — suite de l'audit du 03/09
-- Auteur   : coordination AnarBib (decision Xavier du 05/09/2026 :
--            « corrige tout ce qui y est corrigeable »)
--
-- POURQUOI LE RAPPORT MONTRAIT « AA. VV. » ALORS QUE CONV-8 L'AVAIT REGLE
--   CONV-8 (20260903184828) a retire les CONTRIBUTEURS « AA. VV. »,
--   « Anônimo », « Coletivo » — et a garde, a dessein, la transcription dans
--   books.autor (c'est la mention de responsabilite ; l'OPAC l'affiche entre
--   crochets). Or le rapport « Auteur·rices non resolu·es » lit books.autor
--   par la vue v_author_alias_worklist, et proposait donc de « creer
--   l'autorite » pour ce que CONV-8 venait de dire n'etre PAS une autorite.
--   Les deux ecrans se contredisaient. Ce paquet donne au reseau UN SEUL
--   predicat (fn_conv_est_non_agent) et le fait lire par la vue, par la vue
--   des semis de contributeurs, et par le rapport de revision des lots.
--
-- CE QUE FAIT LE PAQUET
--   1. fn_conv_est_non_agent(text) : « AA. VV. », « VV. AA. », « Vários
--      autores », « Collectif », « Coletivo », « Anônimo », « Sem autoria »,
--      « identificado, Não », « ?? »… — vocabulaire ferme, normalise.
--   2. v_author_alias_worklist et v_author_seed_candidates l'appliquent.
--   3. api.report_incoherences_auteurs compare book_authors aux contributeurs
--      de TOUS les roles lies (comme le trigger qui derive la table), et non
--      plus au seul role autor : « Federação » (organizacao) et « Goldman »
--      (prefaciador) n'etaient pas des incoherences.
--   4. Dix-sept fusions de fiches en double, toutes nees du lot C5 du 03/09
--      (la recherche d'homonyme n'attrapait pas la variante) ou d'un doublon
--      exact ; les fixtures de formation (formacao-*) sont laissees.
--   5. Dix-huit lignes book_authors orphelines retirees : les « A… » des
--      identifiants 10212–10225 (une jointure fausse d'un import de juin qui
--      a colle le premier auteur de l'alphabet a des notices sans rapport)
--      et Bakunin en auteur d'un livre de Leval SUR Bakunin.
--   6. Dix lignes book_authors plus RICHES que les contributeurs (anthologies
--      MLEG) deviennent des contributeurs : rien ne se perd, la table derivee
--      et la verite se rejoignent.
--   7. Deux collectivites reelles recoivent une fiche et un contributeur
--      (Colectivo Paideia, Coletivo Libertário de Oposição Sindical) ; les
--      deux personnes de la notice 2548 recoivent leur fiche et la mention
--      garblee est reecrite ; la notice 1707 range « Piccolo Dizionario degli
--      Orrori » en collection, pas en auteur.
--   8. fn_batch_review_report : plus de table temporaire (chaque appel
--      declenchait pgrst_ddl_watch, donc un rechargement du cache PostgREST,
--      et l'ecran recevait un 400) ; les brouillons vivants passent par une
--      fonction ; deux regles nouvelles (contributeur non-agent a retirer ;
--      auteur non-agent = entree au titre, informatif, pas un ecart).
--
-- CE QUE LE PAQUET NE TRANCHE PAS (a Xavier)
--   - 2272 « Coletivo de Ex-Trabalhadores » : traducteurs ou auteurs ? CONV-8
--     l'avait deja laisse ; il reste au rapport.
--   - 2571 « Estudos Proudhonianos » : Ansart devient contributeur, Proudhon
--     reste (sujet ou auteur ? a arbitrer).
--   - Les 1493 autorites « a completer » et les documents incomplets : pas
--     un script.
--
-- CHECKLIST DOCTRINE
--   [x] Vues recreees SANS option (elles n'en avaient pas : DEFINER, lues par
--       les RPC admin seulement) — CREATE OR REPLACE conserve les grants
--   [x] Fonctions de migration : INVOKER, aucun grant, garde des fixtures
--   [x] Listes FERMEES, chaque geste trace (merge_log / catalog_audit_log)
--   [x] Sur une base fraiche (CI), aucune des lignes n'existe : 0 geste,
--       aucune erreur — les gestes sont conditionnels
--   [x] fn_batch_review_report : REVOKE/GRANT rejoues
-- =========================================================================

begin;

-- ── 1. Le predicat ───────────────────────────────────────────────────────
create or replace function public.fn_conv_est_non_agent(p_nom text)
returns boolean
language sql
immutable
set search_path to ''
as $function$
  select btrim(public.normalize_author_alias(p_nom)) in (
    '', 'aa vv', 'vv aa', 'aavv', 'vvaa', 'autori vari', 'autores varios', 'varios autores',
    'varios', 'divers', 'auteurs divers', 'collectif', 'coletivo', 'colectivo', 'collettivo',
    'collective', 'anonimo', 'anonima', 'anonyme', 'anonymous', 'anon', 'sem autoria',
    'sem autor', 'sin autor', 'senza autore', 'sans auteur', 'identificado nao',
    'nao identificado', 'no identificado', 'non identificato', 'desconhecido', 'desconocido',
    'inconnu', 'unknown', 's n', 's a', 'n a'
  );
$function$;

comment on function public.fn_conv_est_non_agent(text) is
  'CONV-8 : vrai pour une mention de responsabilite qui n''est PAS un agent '
  '(« AA. VV. », « Vários autores », « Collectif », « Anônimo », « Sem autoria », '
  '« ?? »…). L''entree se fait au titre, la transcription reste. Un seul '
  'predicat pour la vue des non-resolus, les semis et le rapport de revision (05/09/2026).';

-- ── 2. Les deux vues le lisent ───────────────────────────────────────────
create or replace view public.v_author_alias_worklist as
 WITH remaining AS (
         SELECT b.id AS book_id,
            b.bib_ref,
            b.titulo,
            TRIM(BOTH FROM b.autor) AS autor,
            normalize_author_alias(b.autor) AS autor_norm
           FROM books b
             LEFT JOIN ( SELECT DISTINCT author_books_public.book_id
                   FROM author_books_public) abp ON abp.book_id = b.id
          WHERE COALESCE(NULLIF(TRIM(BOTH FROM b.autor), ''::text), ''::text) <> ''::text
            AND abp.book_id IS NULL
            AND b.autor !~~ '%;%'::text
            -- CONV-8 (05/09/2026) : une mention qui n'est pas un agent n'a
            -- pas d'autorite a creer — l'entree se fait au titre.
            AND NOT public.fn_conv_est_non_agent(b.autor)
        ), alias_hits AS (
         SELECT ana.alias_norm,
            count(DISTINCT ana.author_id) AS alias_matches,
            string_agg(DISTINCT ana.author_id::text, ', '::text ORDER BY (ana.author_id::text)) AS alias_author_ids
           FROM author_name_aliases ana
          WHERE ana.is_active = true
          GROUP BY ana.alias_norm
        ), candidate_hits AS (
         SELECT r_1.autor_norm,
            count(DISTINCT a.id) AS candidate_matches,
            string_agg(DISTINCT a.id::text, ', '::text ORDER BY (a.id::text)) AS candidate_author_ids
           FROM ( SELECT DISTINCT remaining.autor_norm
                   FROM remaining) r_1
             JOIN authors a ON normalize_author_alias(a.preferred_name) = r_1.autor_norm OR normalize_author_alias(a.sort_name) = r_1.autor_norm
          GROUP BY r_1.autor_norm
        )
 SELECT r.autor,
    r.autor_norm,
    count(*) AS books_count,
    min(r.bib_ref) AS sample_bib_ref,
    min(r.titulo) AS sample_title,
    COALESCE(ah.alias_matches, 0::bigint) AS alias_matches,
    ah.alias_author_ids,
    COALESCE(ch.candidate_matches, 0::bigint) AS candidate_matches,
    ch.candidate_author_ids,
        CASE
            WHEN COALESCE(ah.alias_matches, 0::bigint) > 0 THEN 'alias_exists'::text
            WHEN COALESCE(ch.candidate_matches, 0::bigint) = 1 THEN 'candidate_existing_author'::text
            WHEN COALESCE(ch.candidate_matches, 0::bigint) > 1 THEN 'ambiguous_existing_author'::text
            ELSE 'needs_new_author'::text
        END AS status
   FROM remaining r
     LEFT JOIN alias_hits ah ON ah.alias_norm = r.autor_norm
     LEFT JOIN candidate_hits ch ON ch.autor_norm = r.autor_norm
  GROUP BY r.autor, r.autor_norm, ah.alias_matches, ah.alias_author_ids, ch.candidate_matches, ch.candidate_author_ids;

create or replace view public.v_author_seed_candidates as
 WITH unresolved AS (
         SELECT TRIM(BOTH FROM book_contributors.name) AS raw_name,
            lower(TRIM(BOTH FROM book_contributors.name)) AS unresolved_name,
            norm_match_text(TRIM(BOTH FROM book_contributors.name)) AS unresolved_norm,
            count(*) AS uses,
            min(book_contributors.book_id) AS sample_book_id
           FROM book_contributors
          WHERE book_contributors.author_id IS NULL AND TRIM(BOTH FROM COALESCE(book_contributors.name, ''::text)) <> ''::text
          GROUP BY (TRIM(BOTH FROM book_contributors.name)), (lower(TRIM(BOTH FROM book_contributors.name))), (norm_match_text(TRIM(BOTH FROM book_contributors.name)))
        ), filtered AS (
         SELECT unresolved.raw_name,
            unresolved.unresolved_name,
            unresolved.unresolved_norm,
            unresolved.uses,
            unresolved.sample_book_id
           FROM unresolved
          WHERE unresolved.uses >= 3
            AND unresolved.raw_name !~ '^[ /0-9]'::text
            -- la liste locale (aa. vv, anônimo, coletivo…) cede la place au predicat CONV-8
            AND NOT public.fn_conv_est_non_agent(unresolved.raw_name)
            AND lower(unresolved.raw_name) <> ALL (ARRAY['c.n.t.'::text, 'cnt'::text])
            AND unresolved.raw_name !~~* '%grupo%'::text AND unresolved.raw_name !~~* '%rivista%'::text
            AND unresolved.raw_name !~~* '%taller%'::text AND unresolved.raw_name !~~* '%escuela%'::text
            AND unresolved.raw_name !~~* '%confederación%'::text
        )
 SELECT raw_name,
    unresolved_name,
    unresolved_norm,
    uses,
    sample_book_id
   FROM filtered
  ORDER BY uses DESC, unresolved_name;

-- ── 3. Le rapport d'incoherences compare ce que le trigger derive ────────
create or replace function api.report_incoherences_auteurs()
returns table(book_id bigint, bib_ref text, titulo text, ba_ids bigint[], bc_ids bigint[], type_incoherence text)
language plpgsql
stable
security definer
set search_path to 'public', 'pg_catalog'
as $function$
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Relatorio reservado a administracao da rede.' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH ba AS (
    SELECT b1.book_id, array_agg(DISTINCT b1.author_id ORDER BY b1.author_id) AS ids
    FROM public.book_authors b1 GROUP BY b1.book_id
  ), bc AS (
    -- Tous les roles lies a une autorite : c'est ce que fn_sync_book_authors_from_contributor
    -- derive dans book_authors. Comparer au seul role autor fabriquait des faux positifs
    -- (une organisation, une prefaciere) — rapport reseau du 05/09/2026.
    SELECT b2.book_id, array_agg(DISTINCT b2.author_id ORDER BY b2.author_id) AS ids
    FROM public.book_contributors b2
    WHERE b2.author_id IS NOT NULL
    GROUP BY b2.book_id
  ), diff AS (
    SELECT COALESCE(ba.book_id, bc.book_id) AS book_id, ba.ids AS ba_ids, bc.ids AS bc_ids,
      CASE WHEN ba.ids IS NULL THEN 'manque_dans_book_authors' ELSE 'divergence' END AS type_incoherence
    FROM ba FULL OUTER JOIN bc ON ba.book_id = bc.book_id
    WHERE bc.ids IS NOT NULL
      AND ba.ids IS DISTINCT FROM bc.ids
  )
  SELECT d.book_id, b.bib_ref, b.titulo, d.ba_ids, d.bc_ids, d.type_incoherence
  FROM diff d
  JOIN public.books b ON b.id = d.book_id
  ORDER BY d.book_id;
END;
$function$;

-- ── 4. Dix-sept fusions : variantes d'une meme personne, listes fermees ──
-- Meme corps que fn_conv_fusionner_doublon_exact (03/09), sans la garde
-- d'exactitude : ici la decision est humaine (Xavier, 05/09), ligne par ligne.
-- La garde des fixtures de formation reste.
create or replace function public.fn_conv_fusionner_variante(p_canonical bigint, p_duplicate bigint, p_motif text)
returns boolean
language plpgsql
security invoker
set search_path to 'public', 'pg_catalog'
as $$
declare
  v_can  public.authors%rowtype;
  v_dup  public.authors%rowtype;
begin
  if p_canonical is null or p_duplicate is null or p_canonical = p_duplicate then return false; end if;
  select * into v_can from public.authors where id = p_canonical;
  select * into v_dup from public.authors where id = p_duplicate;
  if v_can.id is null or v_dup.id is null then return false; end if;
  if coalesce(v_can.source_label, '') like 'formacao-%' or coalesce(v_dup.source_label, '') like 'formacao-%' then return false; end if;

  -- La forme retiree survit en forme variante de la fiche canonique.
  update public.authors
     set variant_forms = coalesce(variant_forms, '[]'::jsonb)
                         || jsonb_build_array(jsonb_build_object('form', v_dup.sort_name, 'source', 'fusion 05/09/2026')),
         updated_at = now()
   where id = p_canonical
     and (variant_forms is null or jsonb_typeof(variant_forms) = 'array')
     and not (coalesce(variant_forms, '[]'::jsonb) @> jsonb_build_array(jsonb_build_object('form', v_dup.sort_name)));

  -- Corps de merge_author, recopie (identique a fn_conv_fusionner_doublon_exact).
  update public.book_contributors set author_id = p_canonical where author_id = p_duplicate;
  insert into public.book_authors (book_id, author_id, role, ord)
    select book_id, p_canonical, role, ord from public.book_authors where author_id = p_duplicate
    on conflict (book_id, author_id, role, ord) do nothing;
  delete from public.book_authors where author_id = p_duplicate;
  update public.author_translations t set author_id = p_canonical
    where t.author_id = p_duplicate
      and not exists (select 1 from public.author_translations c where c.author_id = p_canonical and c.lang = t.lang);
  update public.author_name_aliases set author_id = p_canonical where author_id = p_duplicate;
  update public.author_drafts set published_author_id = p_canonical where published_author_id = p_duplicate;
  update public.book_draft_contributors set author_id = p_canonical where author_id = p_duplicate;
  update public.works set primary_author_id = p_canonical where primary_author_id = p_duplicate;

  update public.catalog_review_queue q
     set decision = 'ecarte', decided_at = now(),
         note = coalesce(q.note || ' · ', '') || 'Fusionnée dans la fiche ' || p_canonical || ' (variante, rapport réseau 05/09).'
   where q.entity_kind = 'author' and q.entity_id = p_duplicate and q.applique_le is null;

  insert into public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
  values ('author', p_canonical, p_duplicate,
          jsonb_build_object('duplicate_preferred_name', v_dup.preferred_name,
                             'duplicate_sort_name', v_dup.sort_name,
                             'motif', p_motif,
                             'via', 'migration rapport réseau 05/09 (fn_conv_fusionner_variante)'),
          null);

  delete from public.authors where id = p_duplicate;
  return true;
end;
$$;

revoke all on function public.fn_conv_fusionner_variante(bigint, bigint, text) from public, anon, authenticated;

do $$
declare r record; v_n int := 0; v_refus int := 0;
begin
  for r in select * from (values
      -- doublons exacts du rapport (les fixtures formacao-e4/e5 sont laissees)
      (10303, 11399, 'Baudelaire, Charles — doublon exact ne du lot C5 (contributeur « Boudelaire »)'),
      (10472, 11340, 'D''Auria, Aníbal A. — meme nom, apostrophe typographique contre droite'),
      (10890, 11557, 'Mercier-Vega, Louis — doublon exact ne du lot C5'),
      (11035, 11510, 'Philopat, Duka e Marco — doublon exact ne du lot C5'),
      -- variantes d'une meme personne (book_authors les reliait deja a la fiche ancienne)
      (10349, 11347, 'Bonanno, Alfredo María ← Alfredo M. Bonanno (initiale)'),
      (10349, 11378, 'Bonanno, Alfredo María ← Alfredo M. Bonanno (initiale, second semis)'),
      (10686, 11406, 'Guyau, Jean-Marie ← Juan Maria Guyau (forme espagnole de la traduction)'),
      (10686, 11409, 'Guyau, Jean-Marie ← M. Guyau (initiale)'),
      (10820, 11435, 'Lopreato, Christina Da Silva Roquette ← Christina Roquette Lopreato'),
      (10914, 11514, 'Moraes, Wallace ← Morais, Wallace (graphie)'),
      (10304, 11377, 'Souchy Bauer, Agustín ← Augustín (graphie)'),
      (11311, 11554, 'Zamenhof, Lázaro Luíz ← L.L. Zamenhof (initiales)'),
      (10147, 11411, 'Archinov, Piotr ← Archinov (nom seul)'),
      (10797, 11490, 'Lima, Adolfo ← Adolpho (graphie ancienne)'),
      (10807, 11544, 'Souza Lobo, Elisabeth ← Elizabeth (graphie)'),
      (10839, 11487, 'Magnani, Silvia Lang ← Silvia Magnani'),
      (11437, 11456, 'Ratgeb ← Ratgreb (coquille du pseudonyme)'),
      (10175, 11365, 'CrimethInc. ← CrimethInc. Writers'' Bloc (auto-designation du collectif)')
    ) as t(canonique, doublon, motif)
  loop
    if exists (select 1 from public.authors where id = r.doublon) and exists (select 1 from public.authors where id = r.canonique) then
      if public.fn_conv_fusionner_variante(r.canonique, r.doublon, r.motif) then v_n := v_n + 1; else v_refus := v_refus + 1; end if;
    end if;
  end loop;
  raise notice 'Rapport reseau 05/09 — % fusion(s), % refusee(s) par la garde.', v_n, v_refus;
end $$;

-- ── 5. Les lignes book_authors orphelines qui n'ont jamais dit vrai ──────
do $$
declare r record; v_n int := 0;
begin
  for r in select * from (values
      -- les « A… » de juin : identifiants 10212–10225 colles par une jointure fausse
      (764, 10212), (567, 10213), (1886, 10213), (2148, 10214), (2149, 10214), (2132, 10215),
      (478, 10216), (750, 10217), (1563, 10217), (968, 10218), (1684, 10219), (815, 10220),
      (2361, 10220), (2150, 10221), (752, 10222), (1393, 10223), (1493, 10224), (770, 10225),
      -- Bakunin en auteur d'un livre de Gaston Leval SUR Bakunin (sujet, pas agent)
      (2525, 3)
    ) as t(book_id, author_id)
  loop
    if exists (select 1 from public.book_authors ba where ba.book_id = r.book_id and ba.author_id = r.author_id)
       and not exists (select 1 from public.book_contributors bc where bc.book_id = r.book_id and bc.author_id = r.author_id) then
      insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, label, details)
      select null, 'discard', 'book', r.book_id, a.preferred_name,
             jsonb_build_object('via', 'migration rapport réseau 05/09',
                                'raison', 'ligne book_authors sans contributeur : jointure fausse de l''import de juin (ids 10212-10225) ou sujet pris pour auteur',
                                'author_id', r.author_id)
        from public.authors a where a.id = r.author_id;
      delete from public.book_authors ba where ba.book_id = r.book_id and ba.author_id = r.author_id;
      v_n := v_n + 1;
    end if;
  end loop;
  raise notice 'Rapport reseau 05/09 — % ligne(s) book_authors orpheline(s) retiree(s).', v_n;
end $$;

-- ── 6. Les anthologies MLEG : book_authors savait plus que les contributeurs ──
do $$
declare r record; v_n int := 0; v_a public.authors%rowtype;
begin
  for r in select * from (values
      (2569, 1), (2569, 10049),                                   -- Essência da Religião : Reclus, Faure
      (2593, 12), (2593, 23), (2593, 10021), (2593, 10040), (2593, 10097), (2593, 10180), -- Hist. do Mov. Operário Rev.
      (2662, 10014), (2662, 10020), (2662, 10106),                -- Os Anarquistas Julgam Marx
      (2571, 10068)                                               -- Estudos Proudhonianos : Ansart (Proudhon reste, a arbitrer)
    ) as t(book_id, author_id)
  loop
    select * into v_a from public.authors where id = r.author_id;
    if v_a.id is not null
       and exists (select 1 from public.book_authors ba where ba.book_id = r.book_id and ba.author_id = r.author_id)
       and not exists (select 1 from public.book_contributors bc where bc.book_id = r.book_id and bc.author_id = r.author_id) then
      insert into public.book_contributors (book_id, author_id, name, role, position, is_primary)
      select r.book_id, r.author_id, coalesce(v_a.sort_name, v_a.preferred_name), ba.role,
             coalesce((select max(c.position) from public.book_contributors c where c.book_id = r.book_id), 0) + 1,
             false
        from public.book_authors ba where ba.book_id = r.book_id and ba.author_id = r.author_id
        limit 1;
      insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, label, details)
      values (null, 'update', 'book', r.book_id, coalesce(v_a.sort_name, v_a.preferred_name),
              jsonb_build_object('via', 'migration rapport réseau 05/09',
                                 'raison', 'book_authors portait un auteur absent des contributeurs : devient contributeur (anthologie)',
                                 'author_id', r.author_id));
      v_n := v_n + 1;
    end if;
  end loop;
  raise notice 'Rapport reseau 05/09 — % contributeur(s) recree(s) depuis book_authors.', v_n;
end $$;

-- ── 7. Collectivites, personnes de la notice 2548, notice 1707 ────────────
do $$
declare v_id bigint; v_book public.books%rowtype; v_n int := 0;
begin
  -- 7a. Deux collectivites reelles : fiche + contributeur primaire.
  for v_book in select * from public.books b where b.id in (2673, 2545) loop
    if btrim(coalesce(v_book.autor, '')) <> ''
       and not exists (select 1 from public.book_contributors c where c.book_id = v_book.id) then
      v_id := public.fn_conv_autorite_homonyme(v_book.autor);
      if v_id is null then
        insert into public.authors (preferred_name, sort_name, authority_type, source_kind, source_label)
        values (v_book.autor, v_book.autor, 'collective', 'conv_revue', 'Rapport réseau 05/09/2026')
        returning id into v_id;
      end if;
      insert into public.book_contributors (book_id, author_id, name, role, position, is_primary)
      values (v_book.id, v_id, v_book.autor, 'autor', 1, true);
      insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, label, details)
      values (null, 'update', 'book', v_book.id, v_book.autor,
              jsonb_build_object('via', 'migration rapport réseau 05/09', 'raison', 'collectivité réelle : fiche et contributeur', 'author_id', v_id));
      v_n := v_n + 1;
    end if;
  end loop;

  -- 7b. Notice 2548 : deux personnes deja en contributeurs sans fiche, mention garblee.
  select * into v_book from public.books where id = 2548;
  if v_book.id is not null and v_book.autor = 'CHRISTIAN BAY, Charles Walter' then
    for v_id in select c.id from public.book_contributors c where c.book_id = 2548 and c.author_id is null and c.name in ('Bay, Christian', 'Walker, Charles C.') loop
      declare v_c public.book_contributors%rowtype; v_a bigint; v_pref text;
      begin
        select * into v_c from public.book_contributors where id = v_id;
        v_a := public.fn_conv_autorite_homonyme(v_c.name);
        if v_a is null then
          v_pref := split_part(v_c.name, ', ', 2) || ' ' || split_part(v_c.name, ', ', 1);
          insert into public.authors (preferred_name, sort_name, authority_type, source_kind, source_label)
          values (v_pref, v_c.name, 'person', 'conv_revue', 'Rapport réseau 05/09/2026')
          returning id into v_a;
        end if;
        update public.book_contributors set author_id = v_a where id = v_id;
      end;
    end loop;
    update public.books set autor = 'Christian Bay, Charles C. Walker', updated_at = now() where id = 2548;
    insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, label, details)
    values (null, 'update', 'book', 2548, 'Christian Bay, Charles C. Walker',
            jsonb_build_object('via', 'migration rapport réseau 05/09', 'raison', 'mention garblée réécrite, deux fiches créées et liées', 'avant', v_book.autor));
    v_n := v_n + 1;
  end if;

  -- 7c. Notice 1707 : un titre de collection en auteur (CONV-8 avait deja retire le contributeur).
  select * into v_book from public.books where id = 1707;
  if v_book.id is not null and v_book.autor = 'Piccolo Dizionario degli Orrori' then
    update public.books
       set colecao = coalesce(nullif(btrim(colecao), ''), 'Piccolo Dizionario degli Orrori'),
           autor = null, updated_at = now()
     where id = 1707;
    insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, label, details)
    values (null, 'update', 'book', 1707, 'Piccolo Dizionario degli Orrori',
            jsonb_build_object('via', 'migration rapport réseau 05/09', 'raison', 'un titre de collection n''est pas un auteur : rangé en collection, autor vidé'));
    v_n := v_n + 1;
  end if;

  raise notice 'Rapport reseau 05/09 — % notice(s) reprise(s) (collectivites, 2548, 1707).', v_n;
end $$;

-- ── 8. Le rapport de revision des lots, sans table temporaire ────────────
create or replace function public.fn_batch_live_drafts(p_batch_id bigint)
returns setof public.book_drafts
language sql
stable
security definer
set search_path to 'public'
as $function$
  select d.* from public.book_drafts d
   where d.batch_id = p_batch_id and d.status in ('draft', 'ready');
$function$;

revoke execute on function public.fn_batch_live_drafts(bigint) from public, anon, authenticated;
grant  execute on function public.fn_batch_live_drafts(bigint) to service_role;

create or replace function public.fn_batch_review_report(p_batch_id bigint)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'ingest', 'extensions'
as $function$
declare
  v_batch      public.catalog_batches%rowtype;
  v_conv       jsonb := '[]'::jsonb;
  v_rule       record;
  v_items      jsonb;
  v_count      int;
  v_issues     int := 0;
  v_dup_isbn   jsonb;
  v_dup_meta   jsonb;
  v_dup_intra  jsonb;
  v_matching   jsonb;
  v_unlinked   jsonb;
  v_unlinked_n int;
  v_linkable_n int;
  v_title_n    int;
  v_from       text;
  v_sql        text;
  v_ctx        text;
begin
  if not (public.fn_caller_is_network_admin()
          or exists (select 1 from public.user_library_memberships m
                      where m.user_id = auth.uid() and m.status = 'active'
                        and m.role in ('librarian', 'coordenador'))) then
    raise exception 'Acesso restrito ao staff de catalogacao.' using hint = 'error.catalog.staff_only';
  end if;

  select * into v_batch from public.catalog_batches where id = p_batch_id;
  if not found then
    raise exception 'Lote % introuvable', p_batch_id using hint = 'error.review.batch_not_found';
  end if;

  -- Les brouillons vivants du lot : une fonction, pas une table temporaire.
  -- (Une table temporaire creee dans une RPC reveille pgrst_ddl_watch a
  -- chaque appel : rechargement du cache PostgREST, et l'ecran recevait un 400.)
  v_from := format('public.fn_batch_live_drafts(%s) d', p_batch_id);

  -- ── Conventions : une regle = un SELECT (id, titulo, valeur) sur `d` ──
  for v_rule in
    select * from (values
      ('titulo_missing',   $q$ select d.id, d.titulo, null::text from %s where d.titulo is null or btrim(d.titulo) = '' $q$),
      ('titulo_caps',      $q$ select d.id, d.titulo, d.titulo from %s where d.titulo = upper(d.titulo) and d.titulo ~ '[A-ZÀ-Þ]{4,}' $q$),
      ('titulo_article_end', $q$ select d.id, d.titulo, d.titulo from %s where d.titulo ~ ', (O|A|Os|As|Um|Uma|Le|La|Les|El|Los|Las|The)$' $q$),
      ('autor_missing',    $q$ select d.id, d.titulo, null::text from %s
                                where (d.autor is null or btrim(d.autor) = '')
                                  and not exists (select 1 from public.book_draft_contributors c where c.draft_id = d.id) $q$),
      ('autor_unstructured', $q$ select d.id, d.titulo, d.autor from %s
                                where d.autor is not null and btrim(d.autor) <> ''
                                  and not public.fn_conv_est_non_agent(d.autor)
                                  and not exists (select 1 from public.book_draft_contributors c where c.draft_id = d.id) $q$),
      ('contrib_non_agent', $q$ select d.id, d.titulo, c.name from %s
                                join public.book_draft_contributors c on c.draft_id = d.id
                               where public.fn_conv_est_non_agent(c.name) $q$),
      ('contrib_caps',     $q$ select d.id, d.titulo, c.name from %s
                                join public.book_draft_contributors c on c.draft_id = d.id
                               where c.name ~ '\m[A-ZÀ-Þ]{2,}\M' and c.name !~ '[A-ZÀ-Þ]\.' and not public.fn_conv_est_non_agent(c.name) $q$),
      ('contrib_direct_form', $q$ select d.id, d.titulo, c.name from %s
                                join public.book_draft_contributors c on c.draft_id = d.id
                               where c.name !~ ',' and btrim(c.name) ~ '\s' and not public.fn_conv_est_non_agent(c.name) $q$),
      ('ano_invalid',      $q$ select d.id, d.titulo, d.ano from %s
                                where d.approximate_date is null and (d.ano is null or d.ano !~ '^\d{4}$') $q$),
      ('editora_missing',  $q$ select d.id, d.titulo, null::text from %s where d.editora is null or btrim(d.editora) = '' $q$),
      ('idioma_missing',   $q$ select d.id, d.titulo, null::text from %s where d.idioma is null or btrim(d.idioma) = '' $q$),
      ('tipo_material_invalid', $q$ select d.id, d.titulo, d.tipo_material from %s
                                where d.tipo_material is null or lower(d.tipo_material) <> all (array['livro','periodico','tract','cartaz','audio','audiovisual','recurso_digital','dossie','tese','artigo','relatorio','zine']) $q$),
      ('isbn_invalid',     $q$ select d.id, d.titulo, d.isbn from %s
                                where d.isbn is not null and btrim(d.isbn) <> ''
                                  and length(regexp_replace(upper(d.isbn), '[^0-9X]', '', 'g')) not in (10, 13) $q$),
      ('bib_ref_missing',  $q$ select d.id, d.titulo, null::text from %s where d.bib_ref is null or btrim(d.bib_ref) = '' $q$),
      ('subjects_missing', $q$ select d.id, d.titulo, null::text from %s
                                where (d.subjects is null or btrim(d.subjects) = '')
                                  and not exists (select 1 from public.book_draft_subjects s where s.book_draft_id = d.id) $q$)
    ) as r(rule, sql)
  loop
    v_sql := format(v_rule.sql, v_from);
    execute format('select count(*) from (%s) as q(id, titulo, v)', v_sql) into v_count;
    if v_count > 0 then
      execute format('select coalesce(jsonb_agg(jsonb_build_object(''draft_id'', t.id, ''titulo'', t.titulo, ''value'', t.v)), ''[]''::jsonb)
                        from (select q.id, q.titulo, q.v from (%s) as q(id, titulo, v) order by q.id limit 40) t', v_sql)
         into v_items;
      v_conv := v_conv || jsonb_build_object('rule', v_rule.rule, 'count', v_count, 'items', v_items);
      v_issues := v_issues + v_count;
    end if;
  end loop;

  -- Entree au titre (CONV-8) : informatif, pas un ecart.
  select count(*) into v_title_n from public.fn_batch_live_drafts(p_batch_id) d
   where d.autor is not null and public.fn_conv_est_non_agent(d.autor);

  -- ── Doublons contre le catalogue : ISBN, puis titre + auteur + annee ──
  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_dup_isbn from (
    select jsonb_build_object('draft_id', d.id, 'titulo', d.titulo, 'book_id', b.id, 'reason', 'isbn') as x
      from public.fn_batch_live_drafts(p_batch_id) d
      join public.books b
        on regexp_replace(upper(coalesce(b.isbn, '')), '[^0-9X]', '', 'g')
         = regexp_replace(upper(coalesce(d.isbn, '')), '[^0-9X]', '', 'g')
     where coalesce(d.isbn, '') <> ''
       and (d.published_book_id is null or b.id <> d.published_book_id)
     order by d.id limit 40) s;

  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_dup_meta from (
    select jsonb_build_object('draft_id', d.id, 'titulo', d.titulo, 'book_id', b.id, 'reason', 'titulo_autor_ano') as x
      from public.fn_batch_live_drafts(p_batch_id) d
      join public.books b
        on lower(extensions.unaccent(btrim(coalesce(b.titulo, '')))) = lower(extensions.unaccent(btrim(coalesce(d.titulo, ''))))
       and coalesce(b.ano, '') = coalesce(d.ano, '')
       and lower(extensions.unaccent(btrim(coalesce(b.autor, '')))) = lower(extensions.unaccent(btrim(coalesce(d.autor, ''))))
     where coalesce(d.titulo, '') <> ''
       and (d.published_book_id is null or b.id <> d.published_book_id)
       and not (coalesce(d.isbn, '') <> '' and
                regexp_replace(upper(coalesce(b.isbn, '')), '[^0-9X]', '', 'g')
              = regexp_replace(upper(coalesce(d.isbn, '')), '[^0-9X]', '', 'g'))
     order by d.id limit 40) s;

  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_dup_intra from (
    select jsonb_build_object('titulo', min(d.titulo), 'draft_ids', jsonb_agg(d.id order by d.id)) as x
      from public.fn_batch_live_drafts(p_batch_id) d
     where coalesce(d.titulo, '') <> ''
     group by lower(extensions.unaccent(btrim(d.titulo))),
              lower(extensions.unaccent(btrim(coalesce(d.autor, '')))),
              coalesce(d.ano, '')
    having count(*) > 1
     order by min(d.id) limit 40) s;

  select coalesce(jsonb_object_agg(match_status, n), '{}'::jsonb) into v_matching from (
    select sr.match_status, count(*) as n
      from ingest.partner_catalog_row_to_draft m
      join ingest.partner_catalog_staging_rows sr on sr.id = m.staging_row_id
     where m.batch_id = p_batch_id
     group by sr.match_status) s;

  -- ── Autorites : contributeurs non lies, et ceux qu'une fiche attend ──
  select count(*),
         count(*) filter (where public.fn_conv_autorite_homonyme(c.name) is not null)
    into v_unlinked_n, v_linkable_n
    from public.fn_batch_live_drafts(p_batch_id) d
    join public.book_draft_contributors c on c.draft_id = d.id
   where c.author_id is null and not public.fn_conv_est_non_agent(c.name);

  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_unlinked from (
    select jsonb_build_object('draft_id', d.id, 'titulo', d.titulo, 'name', c.name,
                              'suggested_author_id', a.id, 'suggested_sort_name', a.sort_name) as x
      from public.fn_batch_live_drafts(p_batch_id) d
      join public.book_draft_contributors c on c.draft_id = d.id
      left join public.authors a on a.id = public.fn_conv_autorite_homonyme(c.name)
     where c.author_id is null and not public.fn_conv_est_non_agent(c.name)
     order by (a.id is null), d.id limit 40) s;

  return jsonb_build_object(
    'batch', jsonb_build_object(
      'id', v_batch.id, 'name', v_batch.name, 'status', v_batch.status,
      'imported', public.fn_batch_is_imported(p_batch_id),
      'drafts_active', (select count(*) from public.fn_batch_live_drafts(p_batch_id)),
      'drafts_published', (select count(*) from public.book_drafts where batch_id = p_batch_id and status = 'published'),
      'drafts_cancelled', (select count(*) from public.book_drafts where batch_id = p_batch_id and status = 'cancelled'),
      'title_entries', v_title_n),
    'generated_at', now(),
    'conventions', v_conv,
    'duplicates', jsonb_build_object(
      'catalog_isbn', v_dup_isbn,
      'catalog_meta', v_dup_meta,
      'intra_lot', v_dup_intra,
      'import_matching', v_matching),
    'authorities', jsonb_build_object(
      'unlinked_count', v_unlinked_n,
      'linkable_count', v_linkable_n,
      'unlinked', v_unlinked),
    'totals', jsonb_build_object(
      'convention_issues', v_issues,
      'duplicates', jsonb_array_length(v_dup_isbn) + jsonb_array_length(v_dup_meta) + jsonb_array_length(v_dup_intra),
      'unlinked_authorities', v_unlinked_n)
  );
exception when others then
  -- Le contexte de l'erreur remonte a l'ecran : la prochaine panne dira ou.
  get stacked diagnostics v_ctx = pg_exception_context;
  -- Pas de HINT i18n ici : l'ecran afficherait la cle traduite et perdrait le
  -- message ; le texte brut, lui, dit ou ca casse.
  raise exception '% [%] @ %', sqlerrm, sqlstate, left(regexp_replace(v_ctx, E'\\s+', ' ', 'g'), 240)
    using errcode = sqlstate;
end;
$function$;

revoke execute on function public.fn_batch_review_report(bigint) from public, anon;
grant  execute on function public.fn_batch_review_report(bigint) to authenticated, service_role;

-- ── 9. Verification structurelle ─────────────────────────────────────────
do $verif$
declare v_def text; v_n int;
begin
  if not public.fn_conv_est_non_agent('AA. VV.') or not public.fn_conv_est_non_agent('Vários Autores')
     or not public.fn_conv_est_non_agent('identificado, Não') or not public.fn_conv_est_non_agent('??')
     or public.fn_conv_est_non_agent('Coletivo Libertário de Oposição Sindical') or public.fn_conv_est_non_agent('Kropotkine, Piotr') then
    raise exception 'fn_conv_est_non_agent ne repond pas comme attendu';
  end if;
  if position('fn_conv_est_non_agent' in pg_get_viewdef('public.v_author_alias_worklist'::regclass)) = 0
     or position('fn_conv_est_non_agent' in pg_get_viewdef('public.v_author_seed_candidates'::regclass)) = 0 then
    raise exception 'les vues ne lisent pas le predicat';
  end if;
  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'fn_batch_review_report';
  if position('create temp table' in lower(v_def)) > 0 or position('_rev_drafts' in v_def) > 0 then
    raise exception 'fn_batch_review_report cree encore une table temporaire';
  end if;
  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'api' and p.proname = 'report_incoherences_auteurs';
  if position('role=''autor''' in v_def) > 0 or position('role = ''autor''' in v_def) > 0 then
    raise exception 'report_incoherences_auteurs compare encore le seul role autor';
  end if;
  select count(*) into v_n from information_schema.routine_privileges
   where routine_schema = 'public' and routine_name in ('fn_conv_fusionner_variante', 'fn_batch_live_drafts', 'fn_batch_review_report')
     and grantee in ('anon', 'PUBLIC');
  if v_n <> 0 then raise exception '% droit(s) anon/PUBLIC de trop', v_n; end if;
  if has_function_privilege('authenticated', 'public.fn_conv_fusionner_variante(bigint,bigint,text)', 'EXECUTE') then
    raise exception 'fn_conv_fusionner_variante executable depuis l''application';
  end if;
  raise notice 'Paquet rapport-reseau-evidences-du-05-09 : verifications OK';
end
$verif$;

commit;
