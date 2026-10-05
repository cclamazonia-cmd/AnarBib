-- =====================================================================
-- C23 (05/10/2026) — un exemplaire déplacé par sa publication trouve, ou
-- crée, le fonds de sa notice dans la bibliothèque visée.
--
-- Vu en livrant C14 : publier le brouillon d'un exemplaire DÉJÀ publié dont la
-- cible est une autre bibliothèque échouait en
-- « exemplar_library_holding_mismatch » quand la notice n'avait pas encore de
-- fonds trouvé par la cote dans cette bibliothèque. La branche de
-- republication écrit library_id = la cible mais
-- holding_id = coalesce(<fonds résolu>, <ancien fonds>) : l'ancien fonds, d'une
-- autre bibliothèque. (Un exemplaire NEUF n'a pas ce défaut :
-- trg_exemplar_ensure_holding crée son fonds à l'INSERT, pas à l'UPDATE.)
-- À l'écran, le message traduit parlait d'un brouillon « qui pointe vers les
-- exemplaires d'une autre bibliothèque » : faux.
--
-- Correctif : quand la publication change l'exemplaire de bibliothèque et
-- qu'aucun fonds n'a été résolu, on prend le fonds de la MÊME notice dans la
-- cible, sinon on le crée — et s'il y avait été supprimé par une
-- réattribution (CAT-E19), il revient tel qu'il était (cote locale,
-- prêtabilité, notes), exactement comme dans les deux fonctions de
-- réattribution. Le fonds quitté suit la règle de CAT-E19 (C14 (3)), déjà en
-- place plus bas dans la fonction.
--
-- Réécrite depuis la définition RÉELLE (pg_get_functiondef, retours chariot
-- retirés), ancre COMPTÉE, empreinte du corps relevée le 05/10 après C14.
-- Aucune donnée existante n'est modifiée.
-- Suite : tests/sql/exemplaire_deplace_cree_son_fonds_tests.sql.
-- =====================================================================

DO $mig$
DECLARE
  v_fn   regprocedure := 'public.publish_exemplar_draft(bigint)'::regprocedure;
  v_def  text;
  v_md5  text;
  v_n    int;
  v_vieux text := $a$  select case when b.loanable then 'ambos' else 'consulta' end
    into v_seed_policy$a$;
  v_neuf  text := $a$  -- C23 (05/10/2026) : une republication qui CHANGE l'exemplaire de
  -- bibliothèque, sans fonds trouvé par la cote dans la cible : l'UPDATE
  -- ci-dessous garderait l'ancien fonds (coalesce) avec la nouvelle
  -- bibliothèque — exemplar_library_holding_mismatch. Le fonds de la MÊME
  -- notice dans la cible est pris, sinon créé ; supprimé là par une
  -- réattribution (CAT-E19), il revient tel qu'il était (cote locale,
  -- prêtabilité, notes), comme dans les fonctions de réattribution.
  if v_resolved_holding_id is null and v_existing_holding is not null
     and v_existing_library is distinct from v_library_id then
    select h.id into v_resolved_holding_id
      from public.book_holdings h
     where h.library_id = v_library_id
       and h.book_id = (select h0.book_id from public.book_holdings h0 where h0.id = v_existing_holding)
     order by h.id
     limit 1;
    if v_resolved_holding_id is null then
      insert into public.book_holdings (book_id, library_id, loanable, local_bib_ref, notes, exemplares_total, available_count)
      select b.id, v_library_id,
             coalesce((t.fonds->>'loanable')::boolean, b.loanable, true),
             t.fonds->>'local_bib_ref', t.fonds->>'notes', 0, 0
        from public.book_holdings h0
        join public.books b on b.id = h0.book_id
        left join lateral (
          select a.details->'fonds' as fonds
            from public.catalog_audit_log a
           where a.action = 'holding_removed_after_reassign'
             and a.entity_type = 'book'
             and a.entity_id = b.id
             and a.library_id = v_library_id
           order by a.occurred_at desc, a.id desc
           limit 1) t on true
       where h0.id = v_existing_holding
      returning id into v_resolved_holding_id;
      -- Une revue compte ses fascicules par fonds.
      perform public.fn_recompute_serial_holdings(b.serial_id, v_library_id)
         from public.book_holdings h join public.books b on b.id = h.book_id
        where h.id = v_resolved_holding_id and b.serial_id is not null;
    end if;
    select coalesce(nullif(btrim(h.local_bib_ref), ''), b.bib_ref) into v_resolved_bib_ref
      from public.book_holdings h join public.books b on b.id = h.book_id
     where h.id = v_resolved_holding_id;
  end if;

  select case when b.loanable then 'ambos' else 'consulta' end
    into v_seed_policy$a$;
BEGIN
  SELECT md5(replace(prosrc, E'\r', '')) INTO v_md5 FROM pg_proc WHERE oid = v_fn;
  IF v_md5 <> 'b280484369161d1d79853e23e9b685a9' THEN
    RAISE EXCEPTION 'C23 : % a changé depuis le relevé du 05/10 — relire avant de réécrire', v_fn;
  END IF;
  v_def := replace(pg_get_functiondef(v_fn), E'\r', '');
  v_n := (length(v_def) - length(replace(v_def, v_vieux, ''))) / length(v_vieux);
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'C23 : ancre trouvée % fois (1 attendue)', v_n;
  END IF;
  EXECUTE replace(v_def, v_vieux, v_neuf);

  IF pg_get_functiondef(v_fn) NOT LIKE '%C23 (05/10/2026)%' THEN
    RAISE EXCEPTION 'C23 : réécriture incomplète';
  END IF;
END
$mig$;
