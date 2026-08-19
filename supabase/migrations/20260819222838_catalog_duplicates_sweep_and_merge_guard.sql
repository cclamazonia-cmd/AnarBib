-- Dedoublonnage du catalogue publie : balayage global + durcissement de la fusion.
--
-- 1) suggest_catalog_duplicates() — pendant GLOBAL de suggest_book_duplicates().
--    Jusqu'ici la detection n'existait qu'a la notice (pendant le catalogage).
--    Rien ne permettait de voir l'etat du catalogue DEJA publie.
--
--    Les regles sont reprises A L'IDENTIQUE de suggest_book_duplicates : ISBN
--    normalise identique, OU similarite de titre >= 0.5 avec auteur compatible
--    (>= 0.4, ou vide d'un cote), hors paires ecartees (book_not_duplicate) et
--    hors notices partageant la meme oeuvre (meme oeuvre = editions, jamais
--    doublons). Toute divergence entre les deux vues serait deroutante.
--
--    Cout mesure sur 2 677 notices : ~4 s, via les index GIN trigrammes
--    existants (idx_books_titulo_trgm) comme pre-filtre. On renvoie donc TOUT
--    d'un coup plutot que de paginer : 276 paires au 20/08/2026, que le client
--    filtre ensuite en memoire — un seul appel lent, puis instantane.
--
--    `configuration` distingue deux problemes de nature differente :
--      * 'interne'            : les deux notices ont exactement les memes
--                               bibliotheques detentrices -> vrai menage ;
--      * 'inter_bibliotheques': la meme oeuvre cataloguee separement par des
--                               bibliotheques differentes -> fusionner revient
--                               a MUTUALISER, ce qui engage une biblio dont on
--                               n'est pas forcement membre. `fusion_possible`
--                               est donc faux dans ce cas : l'interface liste,
--                               signale, mais n'offre pas de bouton destructeur.
--    Repartition constatee le 20/08/2026 : 159 internes, 117 inter-bibliotheques.
create or replace function public.suggest_catalog_duplicates(p_max integer default 500)
returns table(
  book_id_a bigint, ref_a text, titulo_a text, autor_a text, ano_a text,
  bibliotecas_a text, exemplares_a integer,
  book_id_b bigint, ref_b text, titulo_b text, autor_b text, ano_b text,
  bibliotecas_b text, exemplares_b integer,
  match_kind text, score real, configuration text, fusion_possible boolean
)
language plpgsql
stable
security definer
set search_path to 'public', 'extensions', 'pg_catalog'
as $fn$
begin
  -- Meme garde que suggest_book_duplicates : staff de catalogage uniquement.
  if not exists (
    select 1 from public.user_library_memberships m
    where m.user_id = auth.uid()
      and m.role = any (array['librarian'::text, 'coordenador'::text])
  ) then
    raise exception 'Acesso restrito ao staff de catalogacao.';
  end if;

  return query
  with brut as (
    -- b.titulo % a.titulo : pre-filtre servi par l'index GIN trigramme. Le
    -- predicat exact (sur les valeurs NORMALISEES) est applique ensuite.
    select a.id as ia_id, b.id as ib_id,
           regexp_replace(upper(coalesce(a.isbn,'')),'[^0-9X]','','g') as isbn_a,
           regexp_replace(upper(coalesce(b.isbn,'')),'[^0-9X]','','g') as isbn_b,
           public.fn_normalize_name(a.titulo) as nt_a,
           public.fn_normalize_name(b.titulo) as nt_b,
           public.fn_normalize_name(a.autor)  as na_a,
           public.fn_normalize_name(b.autor)  as na_b,
           a.work_id as work_a, b.work_id as work_b
    from public.books a
    join public.books b
      on b.id > a.id
     and b.titulo % a.titulo
  ),
  retenues as (
    select r.*,
           case when r.isbn_a <> '' and r.isbn_b = r.isbn_a then 'isbn' else 'approx' end as kind,
           case when r.isbn_a <> '' and r.isbn_b = r.isbn_a then 1.0::real
                else similarity(r.nt_a, r.nt_b)::real end as sc
    from brut r
    where not exists (
            select 1 from public.book_not_duplicate nd
            where nd.book_id_a = least(r.ia_id, r.ib_id)
              and nd.book_id_b = greatest(r.ia_id, r.ib_id))
      and not (r.work_a is not null and r.work_b = r.work_a)
      and ( (r.isbn_a <> '' and r.isbn_b = r.isbn_a)
         or ( r.nt_a <> '' and similarity(r.nt_a, r.nt_b) >= 0.5
              and (r.na_a = '' or r.na_b = '' or similarity(r.na_a, r.na_b) >= 0.4)
              and not (r.isbn_a <> '' and r.isbn_b <> '' and r.isbn_b <> r.isbn_a) ) )
  )
  select
    ba.id, ba.bib_ref, ba.titulo, ba.autor, ba.ano, la.libs, coalesce(la.ex,0)::integer,
    bb.id, bb.bib_ref, bb.titulo, bb.autor, bb.ano, lb.libs, coalesce(lb.ex,0)::integer,
    x.kind, x.sc,
    case when la.libs is not distinct from lb.libs then 'interne'
         else 'inter_bibliotheques' end,
    (la.libs is not distinct from lb.libs)
  from retenues x
  join public.books ba on ba.id = x.ia_id
  join public.books bb on bb.id = x.ib_id
  join lateral (
    select string_agg(distinct l.short_name, ' + ' order by l.short_name) as libs,
           sum(h.exemplares_total) as ex
    from public.book_holdings h
    join public.libraries l on l.id = h.library_id
    where h.book_id = x.ia_id) la on true
  join lateral (
    select string_agg(distinct l.short_name, ' + ' order by l.short_name) as libs,
           sum(h.exemplares_total) as ex
    from public.book_holdings h
    join public.libraries l on l.id = h.library_id
    where h.book_id = x.ib_id) lb on true
  order by x.kind, x.sc desc, ba.titulo
  limit greatest(coalesce(p_max, 500), 1);
end $fn$;

comment on function public.suggest_catalog_duplicates(integer) is
  'Balayage global des doublons du catalogue publie. Memes regles que suggest_book_duplicates (ISBN, ou titre >= 0.5 + auteur >= 0.4, hors meme oeuvre et hors paires ecartees). Distingue les doublons INTERNES a une bibliotheque (fusion legitime) de ceux INTER-BIBLIOTHEQUES (mutualisation, fusion non proposee). Staff de catalogage uniquement.';

revoke all on function public.suggest_catalog_duplicates(integer) from public, anon;
grant execute on function public.suggest_catalog_duplicates(integer) to authenticated, service_role;

-- 2) merge_book() : garde de rattachement.
--    Le controle existant se contentait d'un role librarian/coordenador dans
--    N'IMPORTE QUELLE bibliotheque. N'importe quel membre du staff du reseau
--    pouvait donc fusionner — donc SUPPRIMER — deux notices appartenant a deux
--    AUTRES bibliotheques. Tolerable tant que la fusion se faisait notice par
--    notice pendant le catalogage ; plus du tout avec un balayage global qui
--    expose 276 paires d'un coup.
--
--    On exige desormais un lien reel : etre staff actif de l'une des
--    bibliotheques detentrices, ou administrateur·rice reseau. Cas particulier
--    conserve : si AUCUNE des deux notices n'a de holding, elle n'appartient a
--    personne et le staff de catalogage peut faire le menage.
--
--    Le corps de la fusion est repris a l'identique — seul le garde change.
create or replace function public.merge_book(p_canonical_id bigint, p_duplicate_id bigint)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $fn$
DECLARE
  v_dup_titulo text;
  dh           record;
  v_ch_id      bigint;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid()
      AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
  ) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.';
  END IF;

  -- Garde de rattachement (2026-08-20).
  IF NOT EXISTS (SELECT 1 FROM public.network_administrators na WHERE na.user_id = auth.uid())
     AND EXISTS (SELECT 1 FROM public.book_holdings h
                 WHERE h.book_id IN (p_canonical_id, p_duplicate_id))
     AND NOT EXISTS (
       SELECT 1
       FROM public.book_holdings h
       JOIN public.user_library_memberships m
         ON m.library_id = h.library_id
        AND m.user_id = auth.uid()
        AND m.status = 'active'
        AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
       WHERE h.book_id IN (p_canonical_id, p_duplicate_id)
     ) THEN
    RAISE EXCEPTION 'Fusao restrita ao staff de uma das bibliotecas detentoras (ou a administracao da rede).'
      USING ERRCODE = '42501', HINT = 'error.catalog.merge_not_related';
  END IF;

  IF p_canonical_id = p_duplicate_id THEN
    RAISE EXCEPTION 'Canonico e duplicado identicos.';
  END IF;
  SELECT titulo INTO v_dup_titulo FROM public.books WHERE id = p_duplicate_id;
  IF v_dup_titulo IS NULL THEN
    RAISE EXCEPTION 'Duplicado % inexistente.', p_duplicate_id;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.books WHERE id = p_canonical_id) THEN
    RAISE EXCEPTION 'Canonico % inexistente.', p_canonical_id;
  END IF;

  -- 1. Holdings : fusionner (meme bibliotheque) ou repointer.
  FOR dh IN SELECT * FROM public.book_holdings WHERE book_id = p_duplicate_id LOOP
    SELECT id INTO v_ch_id
      FROM public.book_holdings
      WHERE book_id = p_canonical_id AND library_id = dh.library_id
      LIMIT 1;

    IF v_ch_id IS NOT NULL THEN
      -- Fusion : tout ce qui pointe vers le holding doublon bascule sur le canonique.
      UPDATE public.exemplares                SET holding_id = v_ch_id WHERE holding_id = dh.id;
      UPDATE public.emprestimo_itens_v2       SET holding_id = v_ch_id WHERE holding_id = dh.id;
      UPDATE public.reserva_linhas_v2         SET holding_id = v_ch_id WHERE holding_id = dh.id;
      UPDATE public.interlibrary_loan_items_v2 SET holding_id = v_ch_id WHERE holding_id = dh.id;
      UPDATE public.consulta_linhas_v2        SET holding_id = v_ch_id WHERE holding_id = dh.id;
      UPDATE public.exemplar_drafts           SET target_holding_id = v_ch_id WHERE target_holding_id = dh.id;
      DELETE FROM public.book_holdings WHERE id = dh.id;
    ELSE
      -- Repoint : le holding (avec ses exemplaires et refs) bascule sur le canonique.
      UPDATE public.book_holdings SET book_id = p_canonical_id WHERE id = dh.id;
    END IF;
  END LOOP;

  -- 2. Circulation au niveau livre : repoint book_id (caches/FK).
  UPDATE public.emprestimo_itens_v2        SET book_id = p_canonical_id WHERE book_id = p_duplicate_id;
  UPDATE public.reserva_linhas_v2          SET book_id = p_canonical_id WHERE book_id = p_duplicate_id;
  UPDATE public.interlibrary_loan_items_v2 SET book_id = p_canonical_id WHERE book_id = p_duplicate_id;
  UPDATE public.consulta_linhas_v2         SET book_id = p_canonical_id WHERE book_id = p_duplicate_id;

  -- 3. Ressources numeriques.
  UPDATE public.digital_assets SET book_id = p_canonical_id WHERE book_id = p_duplicate_id;

  -- 4. Wishlist : dedupe (UNIQUE user_id,book_id) puis repoint.
  DELETE FROM public.user_wishlist w
    WHERE w.book_id = p_duplicate_id
      AND EXISTS (SELECT 1 FROM public.user_wishlist w2
                  WHERE w2.user_id = w.user_id AND w2.book_id = p_canonical_id);
  UPDATE public.user_wishlist SET book_id = p_canonical_id WHERE book_id = p_duplicate_id;

  -- 5. Brouillons pointant vers le doublon.
  UPDATE public.book_drafts SET published_book_id = p_canonical_id WHERE published_book_id = p_duplicate_id;

  -- 6. Journaliser.
  INSERT INTO public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
  VALUES ('book', p_canonical_id, p_duplicate_id,
          jsonb_build_object('duplicate_titulo', v_dup_titulo), auth.uid());

  -- 7. Supprimer le doublon (cascade : book_authors/contributors/catalog_context).
  DELETE FROM public.books WHERE id = p_duplicate_id;

  -- 8. Recalcul des compteurs de disponibilite du canonique.
  PERFORM public.fn_v2_recompute_holdings_availability(NULL, ARRAY[p_canonical_id]);
END;
$fn$;

comment on function public.merge_book(bigint, bigint) is
  'Fusionne deux notices. Exige d''etre staff actif d''une des bibliotheques detentrices, ou administrateur·rice reseau (garde ajoutee le 2026-08-20 : le controle precedent acceptait tout staff du reseau, meme etranger aux deux notices).';
