-- =====================================================================
-- AnarBib -- Les exemplaires BTL perdus en juin reviennent
-- Date    : 2026-08-31  ·  Chantier doublons
--
-- LE CONSTAT. Les fusions inter-bibliotheques du 2026-06-06
-- (migration_dedup_cross_biblio + lot2, executees hors depot) ont repointe
-- les holdings BTL des fiches doublons vers les fiches canoniques... mais les
-- EXEMPLAIRES de ces holdings ont disparu. Resultat au 31/08 : 18 holdings
-- BTL a zero exemplaire, alors que l'import Terra Livre (une notice = un
-- exemplaire physique, refs BTL-TL-nnnnnn) atteste que la BTL detient ces
-- ouvrages. L'OPAC affichait « Biblioteca Terra Livre -- indisponible » sans
-- qu'aucun exemplaire n'existe (vu sur la fiche 2335, « O Anarquismo na
-- Escola, no Teatro, na Poesia », holding BTL-TL-001861).
--
-- Cas particulier : l'exemplaire BTL-TL-001372 (« Los Anarquistas
-- Expropriadores », livre 1287) n'a pas ete supprime mais RANGE SOUS LA BLMF
-- (library_id blmf, holding BLMF 2731) -- la famille de bug deja corrigee le
-- 17-18/07 (garde-fou trg_exemplar_library_matches_holding). On le rapatrie.
--
-- LES TOMBOS. Le tombo attendu BTL-TL-EX-nnnnnn est deja occupe : la serie
-- des tombos BTL souffre d'un decalage historique (+1 par endroits ; ex.
-- l'exemplaire de ref BTL-TL-001860 porte le tombo BTL-TL-EX-001861). Les
-- exemplaires recrees prennent donc BTL-TL-EX-nnnnnn-R (R = restaure), avec
-- la ref d'origine en bib_ref et une note de provenance explicite. Le
-- recolement BTL pourra renumeroter.
--
-- SUR EN CI : tout est conditionne a l'existence des donnees ; base vide =
-- zero geste. Idempotent : un exemplaire deja present (par holding OU par
-- ref) n'est jamais recree.
-- =====================================================================

BEGIN;

DO $$
DECLARE
  v_btl uuid;
  r record;
  v_count int := 0;
BEGIN
  SELECT id INTO v_btl FROM public.libraries WHERE slug = 'btl';
  IF v_btl IS NULL THEN
    RAISE NOTICE 'Pas de bibliotheque btl (banc d''essai) : restauration sautee.';
    RETURN;
  END IF;

  -- 1. Rapatrier l'exemplaire BTL range sous la BLMF (livre 1287).
  --    Conditions strictes : la cible doit etre le holding BTL du meme livre.
  UPDATE public.exemplares e
     SET library_id = v_btl,
         holding_id = h.id,
         provenance_note = trim(both ' ' from coalesce(e.provenance_note || ' -- ', '')
           || 'Rapatrie a la BTL le 2026-08-31 : exemplaire BTL range par erreur sous la BLMF depuis la fusion inter-bibliotheques du 2026-06-06.'),
         updated_at = now()
    FROM public.book_holdings h
   WHERE e.bib_ref = 'BTL-TL-001372'
     AND e.library_id <> v_btl
     AND h.library_id = v_btl
     AND h.local_bib_ref = 'BTL-TL-001372'
     AND h.book_id = (SELECT h2.book_id FROM public.book_holdings h2 WHERE h2.id = e.holding_id);
  IF FOUND THEN
    RAISE NOTICE 'Exemplaire BTL-TL-001372 rapatrie a la BTL.';
  END IF;

  -- 2. Recreer les exemplaires manquants des holdings BTL orphelins du
  --    backfill (ceux dont la ref Terra Livre n'a plus aucun exemplaire).
  FOR r IN
    SELECT h.id AS holding_id, h.local_bib_ref
      FROM public.book_holdings h
     WHERE h.library_id = v_btl
       AND h.local_bib_ref LIKE 'BTL-TL-%'
       AND h.notes = 'Backfill inicial a partir de books + exemplares.'
       AND NOT EXISTS (SELECT 1 FROM public.exemplares e WHERE e.holding_id = h.id)
       AND NOT EXISTS (SELECT 1 FROM public.exemplares e WHERE e.bib_ref = h.local_bib_ref)
  LOOP
    INSERT INTO public.exemplares
      (bib_ref, tombo, library_id, holding_id, visibility, circulation_policy, provenance_note)
    VALUES
      (r.local_bib_ref,
       'BTL-TL-EX-' || right(r.local_bib_ref, 6) || '-R',
       v_btl, r.holding_id, 'public', 'ambos',
       'Exemplaire recree le 2026-08-31 : perdu lors de la fusion inter-bibliotheques du 2026-06-06 (migration hors depot). Ref d''origine import Terra Livre : ' || r.local_bib_ref || '. A confirmer au recolement BTL.');
    v_count := v_count + 1;
  END LOOP;

  RAISE NOTICE 'Exemplaires BTL recrees : %', v_count;

  -- 3. Filet : plus aucun holding BTL du backfill sans exemplaire.
  IF EXISTS (
    SELECT 1 FROM public.book_holdings h
     WHERE h.library_id = v_btl
       AND h.notes = 'Backfill inicial a partir de books + exemplares.'
       AND NOT EXISTS (SELECT 1 FROM public.exemplares e WHERE e.holding_id = h.id)
  ) THEN
    RAISE EXCEPTION 'Il reste des holdings BTL du backfill sans exemplaire.';
  END IF;
END $$;

COMMIT;
