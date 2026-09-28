-- ============================================================================
-- La fusion de notices ne perd plus rien, et la référence d'un exemplaire
-- suit son fonds — demandé par Xavier le 28/09/2026 (« Corrige l'outil de
-- fusion et les 75 exemplaires »), après la fusion à la main de BTL-TL-000880
-- dans BTL-TL-000881 (20260927194141).
--
-- CE QUI N'ALLAIT PAS (mesuré en production le 28/09).
--   · merge_book laissait partir en cascade les SUJETS et les CONTRIBUTEUR·RICES
--     du doublon ; rattachait ses brouillons OUVERTS à la notice gardée (publiés,
--     ils l'écrasaient) ; laissait orphelins partages numériques, pistes audio,
--     titre d'œuvre et lignes d'import ; ne gardait du doublon que son titre.
--   · Fusion lancée du formulaire : la notice gardée a un brouillon ouvert — celui
--     qu'on édite —, et sa publication REMPLACE sujets et contributeur·rices et
--     réécrit chaque champ : ce que la fusion reprenait disparaissait au clic
--     suivant.
--   · La référence d'un exemplaire (exemplares.bib_ref) n'était pas mise à jour
--     quand il changeait de fonds ou que sa notice était renommée. Or c'est la
--     clé : trg_exemplar_ensure_holding rattache un exemplaire neuf PAR elle, et
--     la conversion réservation → prêt cherche l'exemplaire PAR elle. La règle,
--     celle de resolve_library_holding_bridge : la référence locale du fonds,
--     sinon celle de la notice. Sur 2 760 exemplaires, 2 717 la suivent ; les
--     32 qui portent une référence locale la suivent TOUS (ce n'est pas un
--     défaut : c'était la moitié des « 75 » annoncés le 27/09) ; 43 portent une
--     référence qui ne désigne plus aucune notice (BTL 25, MLEG 16, BLMF 2).
--
-- CE QUE FAIT CETTE MIGRATION.
--   1. La règle devient un invariant, tenu par trois déclencheurs : l'exemplaire
--      (création, changement de fonds, écriture de sa référence), le fonds
--      (référence locale, notice), la notice (renommage).
--   2. public.fn_fusion_notices : la fusion, une seule fois, appelée par
--      merge_book (qui reprend en plus les champs VIDES de la notice gardée) et
--      par merge_book_with_fields (qui ne reprend que les champs choisis — c'est
--      l'assistant qui décide, ses pertes sèches sont cochées d'office). Elle :
--      garde le doublon ENTIER dans merge_log.details ; reprend sujets et
--      contributeur·rices manquants ; reporte ce que la notice gardée reçoit sur
--      ses brouillons ouverts, là où ils n'avaient rien changé ; écarte les
--      brouillons ouverts du doublon ; déplace fonds et exemplaires (leur
--      référence suit, par déclencheur) et met à jour la référence des lignes de
--      circulation déplacées ; rattache tout ce qui désignait le doublon.
--   3. Les 43 exemplaires reprennent la référence de leur fonds.
--
-- Signatures publiques inchangées (merge_book, merge_book_with_fields, leurs
-- droits) ; messages de refus inchangés (« Arbitragem reservada », etc.).
-- Suite : tests/sql/fusion_notices_complete_tests.sql.
-- ============================================================================
begin;

-- ── 1 · La référence d'un exemplaire suit son fonds ────────────────────────
create or replace function public.tg_exemplaire_reference_suit_son_fonds()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_ref text;
begin
  if new.holding_id is null then
    return new;
  end if;
  select coalesce(nullif(btrim(h.local_bib_ref), ''), b.bib_ref) into v_ref
    from public.book_holdings h join public.books b on b.id = h.book_id
   where h.id = new.holding_id;
  if nullif(btrim(coalesce(v_ref, '')), '') is not null then
    new.bib_ref := v_ref;
  end if;
  return new;
end;
$function$;

-- Après trg_exemplar_ensure_holding (ordre alphabétique des BEFORE) : le fonds
-- est déjà résolu quand la référence s'aligne.
drop trigger if exists trg_exemplar_zz_reference_suit_son_fonds on public.exemplares;
create trigger trg_exemplar_zz_reference_suit_son_fonds
  before insert or update of holding_id, bib_ref on public.exemplares
  for each row execute function public.tg_exemplaire_reference_suit_son_fonds();

-- Le fonds change de référence (référence locale posée ou retirée, notice
-- changée) : ses exemplaires suivent, et les lignes de circulation qui le
-- désignent par l'ancienne référence aussi — la conversion réservation → prêt
-- cherche l'exemplaire PAR cette référence.
create or replace function public.tg_fonds_reference_des_exemplaires()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_avant text;
  v_apres text;
begin
  select coalesce(nullif(btrim(old.local_bib_ref), ''), b.bib_ref) into v_avant
    from public.books b where b.id = old.book_id;
  select coalesce(nullif(btrim(new.local_bib_ref), ''), b.bib_ref) into v_apres
    from public.books b where b.id = new.book_id;
  if nullif(btrim(coalesce(v_apres, '')), '') is null then
    return null;
  end if;
  update public.exemplares e set bib_ref = v_apres
   where e.holding_id = new.id and e.bib_ref is distinct from v_apres;
  if v_avant is distinct from v_apres and v_avant is not null then
    update public.emprestimo_itens_v2        set bib_ref = v_apres where holding_id = new.id and bib_ref = v_avant;
    update public.reserva_linhas_v2          set bib_ref = v_apres where holding_id = new.id and bib_ref = v_avant;
    update public.interlibrary_loan_items_v2 set bib_ref = v_apres where holding_id = new.id and bib_ref = v_avant;
    update public.consulta_linhas_v2         set bib_ref = v_apres where holding_id = new.id and bib_ref = v_avant;
  end if;
  return null;
end;
$function$;

drop trigger if exists trg_fonds_reference_des_exemplaires on public.book_holdings;
create trigger trg_fonds_reference_des_exemplaires
  after update of local_bib_ref, book_id on public.book_holdings
  for each row
  when (old.local_bib_ref is distinct from new.local_bib_ref or old.book_id is distinct from new.book_id)
  execute function public.tg_fonds_reference_des_exemplaires();

create or replace function public.tg_notice_renommee_ses_exemplaires_suivent()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
begin
  if nullif(btrim(coalesce(new.bib_ref, '')), '') is null then
    return null;
  end if;
  -- Seuls les fonds SANS référence locale portent la référence de la notice.
  update public.exemplares e set bib_ref = new.bib_ref
    from public.book_holdings h
   where h.id = e.holding_id and h.book_id = new.id
     and nullif(btrim(h.local_bib_ref), '') is null
     and e.bib_ref is distinct from new.bib_ref;
  -- Les lignes de circulation qui portaient l'ancienne référence (celles d'un
  -- fonds à référence locale portent la locale : elles ne sont pas touchées).
  if old.bib_ref is not null then
    update public.emprestimo_itens_v2        set bib_ref = new.bib_ref where book_id = new.id and bib_ref = old.bib_ref;
    update public.reserva_linhas_v2          set bib_ref = new.bib_ref where book_id = new.id and bib_ref = old.bib_ref;
    update public.interlibrary_loan_items_v2 set bib_ref = new.bib_ref where book_id = new.id and bib_ref = old.bib_ref;
    update public.consulta_linhas_v2         set bib_ref = new.bib_ref where book_id = new.id and bib_ref = old.bib_ref;
  end if;
  return null;
end;
$function$;

drop trigger if exists trg_notice_renommee_ses_exemplaires_suivent on public.books;
create trigger trg_notice_renommee_ses_exemplaires_suivent
  after update of bib_ref on public.books
  for each row
  when (old.bib_ref is distinct from new.bib_ref)
  execute function public.tg_notice_renommee_ses_exemplaires_suivent();

-- Fonctions de déclencheur : aucun appel direct (EXECUTE n'est pas vérifié au
-- déclenchement ; les privilèges par défaut de `public` l'ouvriraient).
revoke all on function public.tg_exemplaire_reference_suit_son_fonds() from public, anon, authenticated;
revoke all on function public.tg_fonds_reference_des_exemplaires() from public, anon, authenticated;
revoke all on function public.tg_notice_renommee_ses_exemplaires_suivent() from public, anon, authenticated;

-- ── 2 · La fusion, une seule fois ──────────────────────────────────────────
create or replace function public.fn_fusion_notices(
  p_canonical_id    bigint,
  p_duplicate_id    bigint,
  p_champs          text[]  default '{}'::text[],
  p_reprendre_vides boolean default true)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_c         public.books%rowtype;   -- la notice gardée, AVANT la fusion
  v_d         public.books%rowtype;   -- le doublon
  v_snap      jsonb;
  v_col       text;
  v_n         int;
  v_choisis   text[] := '{}';
  v_repris    text[] := '{}';
  v_sujets    int := 0;
  v_contrib   int := 0;
  v_ecartes   int := 0;
  v_ouverts   bigint[];
  dh          record;
  v_ch        bigint;
  v_ref_avant text;
  v_ref_apres text;
begin
  IF NOT public.fn_is_dedup_arbiter() THEN
    RAISE EXCEPTION 'Arbitragem reservada à coordenação.'
      USING ERRCODE = '42501', HINT = 'error.catalog.arbiter_only';
  END IF;

  -- Garde de rattachement (2026-08-20, durcie le 2026-08-21) : fusionner deux
  -- notices qui appartiennent à d'autres bibliothèques que la sienne engage des
  -- collectifs dont on n'est pas membre.
  IF NOT EXISTS (SELECT 1 FROM public.network_administrators na
                  WHERE na.user_id = auth.uid() AND na.status = 'active')
     AND EXISTS (SELECT 1 FROM public.book_holdings h
                 WHERE h.book_id IN (p_canonical_id, p_duplicate_id))
     AND NOT EXISTS (
       SELECT 1
       FROM public.book_holdings h
       JOIN public.user_library_memberships m
         ON m.library_id = h.library_id
        AND m.user_id = auth.uid()
        AND m.status = 'active'
        AND m.role = 'coordenador'
       WHERE h.book_id IN (p_canonical_id, p_duplicate_id)
     ) THEN
    RAISE EXCEPTION 'Fusao restrita a coordenacao de uma das bibliotecas detentoras (ou a administracao da rede).'
      USING ERRCODE = '42501', HINT = 'error.catalog.merge_not_related';
  END IF;

  IF p_canonical_id = p_duplicate_id THEN
    RAISE EXCEPTION 'Canonico e duplicado identicos.';
  END IF;
  SELECT * INTO v_d FROM public.books WHERE id = p_duplicate_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Duplicado % inexistente.', p_duplicate_id;
  END IF;
  SELECT * INTO v_c FROM public.books WHERE id = p_canonical_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Canonico % inexistente.', p_canonical_id;
  END IF;

  -- 0. Le doublon, gardé ENTIER, avant tout changement.
  v_snap := jsonb_build_object(
    'duplicate_titulo', v_d.titulo,
    'notice', to_jsonb(v_d),
    'sujets', (select coalesce(jsonb_agg(to_jsonb(s) order by s.ord), '[]'::jsonb)
                 from public.book_subjects s where s.book_id = p_duplicate_id),
    'contributeurs', (select coalesce(jsonb_agg(to_jsonb(x) order by x.position), '[]'::jsonb)
                        from public.book_contributors x where x.book_id = p_duplicate_id),
    'contexte_catalogage', (select to_jsonb(x) from public.book_catalog_context x where x.book_id = p_duplicate_id),
    'fonds', (select coalesce(jsonb_agg(to_jsonb(h)), '[]'::jsonb)
                from public.book_holdings h where h.book_id = p_duplicate_id),
    'exemplaires', (select coalesce(jsonb_agg(to_jsonb(e)), '[]'::jsonb)
                      from public.exemplares e join public.book_holdings h on h.id = e.holding_id
                     where h.book_id = p_duplicate_id),
    'brouillons', (select coalesce(jsonb_agg(jsonb_build_object('id', d.id, 'status', d.status, 'action', d.action)), '[]'::jsonb)
                     from public.book_drafts d where d.published_book_id = p_duplicate_id),
    'couverture_proposee', (select to_jsonb(cp) from public.cover_proposals cp where cp.book_id = p_duplicate_id));

  -- 1. Les champs CHOISIS (assistant) : la valeur du doublon remplace. La
  --    validation (champ inconnu, non reprenable) est faite par l'appelant.
  for v_col in select distinct c from unnest(coalesce(p_champs, '{}'::text[])) c
                where nullif(btrim(c), '') is not null
  loop
    execute format('update public.books g set %1$I = d.%1$I from public.books d where g.id = $1 and d.id = $2', v_col)
      using p_canonical_id, p_duplicate_id;
    v_choisis := v_choisis || v_col;
  end loop;

  -- 2. Les champs VIDES de la notice gardée (merge_book) : ceux du doublon.
  --    Jamais par-dessus une valeur : la notice gardée décide. Un titre de
  --    périodique (serial_id) ne se pose que sur un fascicule ou un article.
  if p_reprendre_vides then
    for v_col in
      select c.column_name from information_schema.columns c
       where c.table_schema = 'public' and c.table_name = 'books' and c.is_generated = 'NEVER'
         and c.column_name <> all (public.fn_dedup_non_transferable_fields())
         and c.column_name <> all (v_choisis)
         and (c.column_name <> 'serial_id' or v_c.tipo_material in ('periodico', 'artigo'))
       order by c.ordinal_position
    loop
      execute format(
        'update public.books g set %1$I = d.%1$I from public.books d
          where g.id = $1 and d.id = $2
            and nullif(btrim(coalesce(g.%1$I::text, '''')), '''') is null
            and nullif(btrim(coalesce(d.%1$I::text, '''')), '''') is not null', v_col)
        using p_canonical_id, p_duplicate_id;
      get diagnostics v_n = row_count;
      if v_n > 0 then v_repris := v_repris || v_col; end if;
    end loop;
  end if;

  -- 3. Les brouillons OUVERTS de la notice gardée reçoivent ce qu'elle vient de
  --    recevoir, là où ils n'ont rien changé (valeur vide, ou encore celle de
  --    la notice avant la fusion) : publiés ensuite, ils l'auraient effacé.
  select array_agg(d.id) into v_ouverts
    from public.book_drafts d
   where d.published_book_id = p_canonical_id and d.status not in ('published', 'cancelled');
  if v_ouverts is not null then
    for v_col in
      select c from unnest(v_choisis || v_repris) c
       where exists (select 1 from information_schema.columns b
                       join information_schema.columns bd
                         on bd.table_schema = 'public' and bd.table_name = 'book_drafts'
                        and bd.column_name = b.column_name and bd.data_type = b.data_type
                      where b.table_schema = 'public' and b.table_name = 'books' and b.column_name = c)
    loop
      execute format(
        'update public.book_drafts bd set %1$I = g.%1$I
           from public.books g
          where g.id = $1 and bd.id = any ($2)
            and (nullif(btrim(coalesce(bd.%1$I::text, '''')), '''') is null
                 or bd.%1$I::text is not distinct from $3)
            and (%2$L <> ''serial_id'' or bd.tipo_material in (''periodico'', ''artigo''))', v_col, v_col)
        using p_canonical_id, v_ouverts, (to_jsonb(v_c) ->> v_col);
    end loop;
  end if;

  -- 4. Sujets et contributeur·rices du doublon qui manquent — à la notice
  --    gardée, et à ses brouillons ouverts (leur publication les remplace).
  insert into public.book_subjects (book_id, subject_id, ord)
  select p_canonical_id, s.subject_id,
         coalesce((select max(t.ord) from public.book_subjects t where t.book_id = p_canonical_id), 0)
           + row_number() over (order by s.ord, s.subject_id)
    from public.book_subjects s
   where s.book_id = p_duplicate_id
     and not exists (select 1 from public.book_subjects t
                      where t.book_id = p_canonical_id and t.subject_id = s.subject_id);
  get diagnostics v_sujets = row_count;

  insert into public.book_contributors (book_id, author_id, position, name, role, is_primary)
  select p_canonical_id, x.author_id,
         coalesce((select max(t.position) from public.book_contributors t where t.book_id = p_canonical_id), 0)
           + row_number() over (order by x.position, x.id),
         x.name, x.role, false
    from public.book_contributors x
   where x.book_id = p_duplicate_id
     and not exists (select 1 from public.book_contributors t
                      where t.book_id = p_canonical_id
                        and coalesce(t.role, '') = coalesce(x.role, '')
                        and ((t.author_id is not null and t.author_id = x.author_id)
                             or public.fn_normalize_name(t.name) = public.fn_normalize_name(x.name)));
  get diagnostics v_contrib = row_count;

  if v_ouverts is not null then
    insert into public.book_draft_subjects (book_draft_id, subject_id, ord)
    select bd, s.subject_id,
           coalesce((select max(t.ord) from public.book_draft_subjects t where t.book_draft_id = bd), 0)
             + row_number() over (partition by bd order by s.ord, s.subject_id)
      from unnest(v_ouverts) bd
      cross join public.book_subjects s
     where s.book_id = p_duplicate_id
       and not exists (select 1 from public.book_draft_subjects t
                        where t.book_draft_id = bd and t.subject_id = s.subject_id);

    -- Un brouillon sans contributeur·rices ne touche pas ceux de la notice à la
    -- publication (fn_sync_book_contributors_on_publish) : on ne lui en ajoute pas.
    insert into public.book_draft_contributors (draft_id, author_id, position, name, role, is_primary)
    select bd, x.author_id,
           coalesce((select max(t.position) from public.book_draft_contributors t where t.draft_id = bd), 0)
             + row_number() over (partition by bd order by x.position, x.id),
           x.name, x.role, false
      from unnest(v_ouverts) bd
      cross join public.book_contributors x
     where x.book_id = p_duplicate_id
       and exists (select 1 from public.book_draft_contributors t0 where t0.draft_id = bd)
       and not exists (select 1 from public.book_draft_contributors t
                        where t.draft_id = bd
                          and coalesce(t.role, '') = coalesce(x.role, '')
                          and ((t.author_id is not null and t.author_id = x.author_id)
                               or public.fn_normalize_name(t.name) = public.fn_normalize_name(x.name)));
  end if;

  -- 5. Brouillons du doublon : l'ouvert est écarté (rattaché puis publié, il
  --    écraserait la notice gardée) ; tous suivent la notice gardée.
  update public.book_drafts set status = 'cancelled'
   where published_book_id = p_duplicate_id and status not in ('published', 'cancelled');
  get diagnostics v_ecartes = row_count;
  update public.book_drafts set published_book_id = p_canonical_id where published_book_id = p_duplicate_id;

  -- 6. Fonds et exemplaires. Un fonds du doublon dans une bibliothèque où la
  --    notice gardée en a déjà un : ses exemplaires et ses lignes rejoignent
  --    celui-ci (sa référence locale et ses notes aussi, si le fonds gardé n'en
  --    a pas), et il disparaît. Sinon il passe sous la notice gardée. Dans les
  --    deux cas la référence des exemplaires suit par déclencheur (fonds
  --    modifié) ; celle des lignes déplacées suit ici.
  for dh in select * from public.book_holdings where book_id = p_duplicate_id loop
    v_ref_avant := coalesce(nullif(btrim(dh.local_bib_ref), ''), v_d.bib_ref);
    select id into v_ch from public.book_holdings
     where book_id = p_canonical_id and library_id = dh.library_id order by id limit 1;
    if v_ch is not null then
      update public.exemplares set holding_id = v_ch where holding_id = dh.id;
      update public.exemplar_drafts            set target_holding_id = v_ch where target_holding_id = dh.id;
      update public.emprestimo_itens_v2        set holding_id = v_ch where holding_id = dh.id;
      update public.reserva_linhas_v2          set holding_id = v_ch where holding_id = dh.id;
      update public.interlibrary_loan_items_v2 set holding_id = v_ch where holding_id = dh.id;
      update public.consulta_linhas_v2         set holding_id = v_ch where holding_id = dh.id;
      delete from public.book_holdings where id = dh.id;
      -- (après la suppression : la référence locale est unique par bibliothèque)
      update public.book_holdings h
         set local_bib_ref = coalesce(nullif(btrim(h.local_bib_ref), ''), nullif(btrim(dh.local_bib_ref), '')),
             notes         = coalesce(nullif(btrim(h.notes), ''), dh.notes)
       where h.id = v_ch
         and ((nullif(btrim(h.local_bib_ref), '') is null and nullif(btrim(dh.local_bib_ref), '') is not null)
              or (nullif(btrim(h.notes), '') is null and nullif(btrim(dh.notes), '') is not null));
      select coalesce(nullif(btrim(h.local_bib_ref), ''), g.bib_ref) into v_ref_apres
        from public.book_holdings h join public.books g on g.id = h.book_id where h.id = v_ch;
      update public.emprestimo_itens_v2        set bib_ref = v_ref_apres where holding_id = v_ch and bib_ref = v_ref_avant;
      update public.reserva_linhas_v2          set bib_ref = v_ref_apres where holding_id = v_ch and bib_ref = v_ref_avant;
      update public.interlibrary_loan_items_v2 set bib_ref = v_ref_apres where holding_id = v_ch and bib_ref = v_ref_avant;
      update public.consulta_linhas_v2         set bib_ref = v_ref_apres where holding_id = v_ch and bib_ref = v_ref_avant;
    else
      -- Le déclencheur du fonds aligne exemplaires et lignes sur la nouvelle notice.
      update public.book_holdings set book_id = p_canonical_id where id = dh.id;
    end if;
    v_ch := null;
  end loop;
  -- Les exemplaires encore à créer qui visaient le doublon par sa référence.
  update public.exemplar_drafts set target_bib_ref = v_c.bib_ref
   where target_bib_ref = v_d.bib_ref and status in ('draft', 'ready')
     and v_d.bib_ref is not null and v_c.bib_ref is not null;

  -- 7. Tout ce qui désigne encore le doublon suit la notice gardée.
  update public.emprestimo_itens_v2        set book_id = p_canonical_id where book_id = p_duplicate_id;
  update public.reserva_linhas_v2          set book_id = p_canonical_id where book_id = p_duplicate_id;
  update public.interlibrary_loan_items_v2 set book_id = p_canonical_id where book_id = p_duplicate_id;
  update public.consulta_linhas_v2         set book_id = p_canonical_id where book_id = p_duplicate_id;
  update public.digital_assets             set book_id = p_canonical_id where book_id = p_duplicate_id;
  update public.ill_digital_shares         set book_id = p_canonical_id where book_id = p_duplicate_id;
  update public.work_titles                set source_book_id = p_canonical_id where source_book_id = p_duplicate_id;
  update ingest.partner_catalog_staging_rows set proposed_book_id = p_canonical_id where proposed_book_id = p_duplicate_id;
  update public.audio_tracks a
     set book_id = p_canonical_id,
         position = a.position + coalesce((select max(t.position) from public.audio_tracks t where t.book_id = p_canonical_id), 0)
   where a.book_id = p_duplicate_id;
  delete from public.user_wishlist w
   where w.book_id = p_duplicate_id
     and exists (select 1 from public.user_wishlist w2 where w2.user_id = w.user_id and w2.book_id = p_canonical_id);
  update public.user_wishlist set book_id = p_canonical_id where book_id = p_duplicate_id;
  -- Une par notice : celle du doublon ne vaut que si la notice gardée n'en a pas.
  update public.cover_proposals set book_id = p_canonical_id
   where book_id = p_duplicate_id
     and not exists (select 1 from public.cover_proposals where book_id = p_canonical_id);
  update public.book_catalog_context set book_id = p_canonical_id
   where book_id = p_duplicate_id
     and not exists (select 1 from public.book_catalog_context where book_id = p_canonical_id);

  -- 8. La trace : le doublon entier, et ce que la fusion a repris.
  insert into public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
  values ('book', p_canonical_id, p_duplicate_id,
          v_snap || jsonb_build_object(
            'champs_choisis', to_jsonb(v_choisis), 'champs_repris', to_jsonb(v_repris),
            'sujets_repris', v_sujets, 'contributeurs_repris', v_contrib,
            'brouillons_ecartes', v_ecartes),
          auth.uid());

  -- 9. Supprimer le doublon (cascade : ce qui n'a pas été repris, et qui est
  --    dans merge_log), recalculer la disponibilité.
  delete from public.books where id = p_duplicate_id;
  perform public.fn_v2_recompute_holdings_availability(null, array[p_canonical_id]);

  return jsonb_build_object(
    'champs_choisis', to_jsonb(v_choisis), 'champs_repris', to_jsonb(v_repris),
    'sujets_repris', v_sujets, 'contributeurs_repris', v_contrib, 'brouillons_ecartes', v_ecartes);
end;
$function$;

comment on function public.fn_fusion_notices(bigint, bigint, text[], boolean) is
  'Fusion de deux notices (28/09/2026), appelée par merge_book (reprise des champs vides) et '
  'merge_book_with_fields (champs choisis seulement). Ne perd rien : doublon entier dans merge_log, '
  'sujets et contributeur·rices repris, brouillons ouverts de la notice gardée mis à jour, '
  'brouillons ouverts du doublon écartés, références de circulation suivies.';

revoke all on function public.fn_fusion_notices(bigint, bigint, text[], boolean) from public, anon, authenticated;

-- merge_book : même signature, mêmes droits, même refus ; la fusion est ailleurs.
create or replace function public.merge_book(p_canonical_id bigint, p_duplicate_id bigint)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
BEGIN
  IF NOT public.fn_is_dedup_arbiter() THEN
    RAISE EXCEPTION 'Arbitragem reservada à coordenação.'
      USING ERRCODE = '42501', HINT = 'error.catalog.arbiter_only';
  END IF;
  -- Fusion complète (garde de rattachement comprise), avec reprise des champs
  -- que la notice gardée n'a pas : ce bouton-là n'a pas d'aperçu pour choisir.
  PERFORM public.fn_fusion_notices(p_canonical_id, p_duplicate_id, '{}'::text[], true);
END;
$function$;

-- merge_book_with_fields : la validation d'avant, puis la fusion sans reprise
-- automatique — l'assistant a déjà proposé (et coché) les pertes sèches.
create or replace function public.merge_book_with_fields(p_canonical_id bigint, p_duplicate_id bigint, p_fields text[] DEFAULT '{}'::text[])
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
DECLARE
  k_interdits text[] := public.fn_dedup_non_transferable_fields();
  v_champs    text[];
  v_inconnus  text[];
  v_refuses   text[];
BEGIN
  IF NOT public.fn_is_dedup_arbiter() THEN
    RAISE EXCEPTION 'Arbitragem reservada à coordenação.'
      USING ERRCODE = '42501', HINT = 'error.catalog.arbiter_only';
  END IF;
  IF p_canonical_id IS NULL OR p_duplicate_id IS NULL OR p_canonical_id = p_duplicate_id THEN
    RAISE EXCEPTION 'Par de documentos inválido.'
      USING ERRCODE = 'P0001', HINT = 'error.catalog.notDuplicate.invalidPair';
  END IF;

  SELECT coalesce(array_agg(DISTINCT c), '{}'::text[]) INTO v_champs
    FROM unnest(coalesce(p_fields, '{}'::text[])) c
   WHERE nullif(btrim(c), '') IS NOT NULL;

  IF array_length(v_champs, 1) IS NOT NULL THEN
    -- Un champ inexistant est presque toujours une faute de frappe côté appelant.
    SELECT coalesce(array_agg(c), '{}'::text[]) INTO v_inconnus
      FROM unnest(v_champs) c
     WHERE NOT EXISTS (
       SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'books' AND column_name = c
     );
    IF array_length(v_inconnus, 1) IS NOT NULL THEN
      RAISE EXCEPTION 'Champ(s) inconnu(s) dans books : %.', array_to_string(v_inconnus, ', ')
        USING ERRCODE = 'P0001', HINT = 'error.catalog.merge.unknown_field';
    END IF;

    SELECT coalesce(array_agg(c), '{}'::text[]) INTO v_refuses
      FROM unnest(v_champs) c
     WHERE c = ANY (k_interdits);
    IF array_length(v_refuses, 1) IS NOT NULL THEN
      RAISE EXCEPTION 'Champ(s) non reprenable(s) : %.', array_to_string(v_refuses, ', ')
        USING ERRCODE = 'P0001', HINT = 'error.catalog.merge.field_not_transferable';
    END IF;
  END IF;

  -- Une seule transaction : si la fusion refuse (rattachement), la reprise des
  -- champs est annulée avec elle.
  PERFORM public.fn_fusion_notices(p_canonical_id, p_duplicate_id, v_champs, false);
END;
$function$;

-- ── 3 · Les exemplaires dont la référence ne désigne plus rien ─────────────
do $$
declare
  v_n int;
  v_reste int;
begin
  update public.exemplares e
     set bib_ref = coalesce(nullif(btrim(h.local_bib_ref), ''), b.bib_ref)
    from public.book_holdings h join public.books b on b.id = h.book_id
   where h.id = e.holding_id
     and e.bib_ref is distinct from coalesce(nullif(btrim(h.local_bib_ref), ''), b.bib_ref);
  get diagnostics v_n = row_count;

  select count(*) into v_reste
    from public.exemplares e
    join public.book_holdings h on h.id = e.holding_id
    join public.books b on b.id = h.book_id
   where e.bib_ref is distinct from coalesce(nullif(btrim(h.local_bib_ref), ''), b.bib_ref);
  if v_reste > 0 then
    raise exception 'références d''exemplaires : % encore décalée(s) après correction', v_reste;
  end if;
  raise notice 'Références d''exemplaires réalignées sur leur fonds : %', v_n;
end $$;

-- ── 4 · Vérification des droits ────────────────────────────────────────────
do $$
declare
  v_f text;
begin
  foreach v_f in array array[
    'public.fn_fusion_notices(bigint, bigint, text[], boolean)',
    'public.tg_exemplaire_reference_suit_son_fonds()',
    'public.tg_fonds_reference_des_exemplaires()',
    'public.tg_notice_renommee_ses_exemplaires_suivent()'] loop
    if has_function_privilege('anon', v_f, 'EXECUTE') or has_function_privilege('authenticated', v_f, 'EXECUTE') then
      raise exception 'fusion : % ouverte au lectorat', v_f;
    end if;
  end loop;
  foreach v_f in array array['public.merge_book(bigint, bigint)', 'public.merge_book_with_fields(bigint, bigint, text[])'] loop
    if has_function_privilege('anon', v_f, 'EXECUTE') or not has_function_privilege('authenticated', v_f, 'EXECUTE') then
      raise exception 'fusion : droits inattendus sur %', v_f;
    end if;
  end loop;
end $$;

commit;
