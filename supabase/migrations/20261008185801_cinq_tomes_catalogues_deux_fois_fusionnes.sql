-- =====================================================================
-- AnarBib -- Cinq tomes catalogués deux fois (BTL/BLMF et MLEG) fusionnés
-- Date     : 2026-10-08  ·  Relevé de Xavier (capture de la liste plate, 20 h 12)
-- Dépend   : 20260928100501 (fn_fusion_notices), 20261005092727 (C18, modèle)
--
-- CONSTAT (prod, 08/10). Cinq paires de notices de la même œuvre, même édition
-- (année, éditeur, sans ISBN ni mention d'édition), MÊME TOME, dans deux
-- bibliothèques ; jamais fusionnées le 31/08 (DEDUP-8) parce que le tome y est
-- écrit autrement (« 1 » / « I », « Vol I » dans le titre MLEG) :
--   · Thomas, A guerra civil espanhola, Civilização Brasileira 1964 :
--     tome 1 = 305 (BTL-TL-000323) et 2473 (MLEG-0016) ;
--     tome 2 = 304 (BTL-TL-000322) et 2474 (MLEG-0017).
--   · Os Sindicatos operários e a Revolução social, Novos Tempos 1988, vol. 1 :
--     2311 (BLMF 0000112, aussi détenue par la BTL) et 2670 (MLEG-0213).
--   · Rebeldias, Opúsculo Libertário : vol. 2 (2004) = 1990 (BTL-TL-002123)
--     et 2683 (MLEG-0226) ; vol. 3 (2005) = 1989 (BTL-TL-002122) et 2684
--     (MLEG-0227).
-- Aucun brouillon ouvert sur les dix notices ; un sujet et un·e contributeur·rice
-- par notice (deux sur 2311).
--
-- AUTORISATION — À LIRE. La fusion est un geste de coordination, journalisé
-- à son auteur (merge_log.merged_by) ; une migration n'a pas de session.
-- Xavier a demandé le 08/10 (« Fais les deux, accord donné pour la fusion
-- des 5 paires ») que ces fusions soient faites ici ; comme pour C18
-- (20261005092727), elles sont inscrites SOUS SON IDENTITÉ (d6710372…,
-- administration réseau active) le temps de la transaction. Ce n'est PAS un
-- modèle : une fusion se fait dans l'assistant de doublons, par la personne
-- qui en répond.
--
-- CE QUI EST FAIT, pour chaque paire (fn_fusion_notices, gardes comprises)
--   · La notice la plus ancienne est gardée (BTL ou BLMF, mars 2026) ; la
--     notice MLEG (juin 2026) est le doublon, gardé ENTIER dans
--     merge_log.details.
--   · AVANT la fusion, le fonds MLEG reçoit en référence locale la cote de
--     sa notice (MLEG-0016…) : son exemplaire garde sa cote et son étiquette,
--     comme chaque fonds BTL garde la sienne (même raison qu'en C18, où la
--     notice MLEG avait été gardée pour cela).
--   · Rien n'est copié de la notice MLEG (p_reprendre_vides = false) : ses
--     seuls champs renseignés que la gardée n'a pas sont sa provenance
--     d'import (source_label, source_record_id, provenance_note) et, pour
--     Rebeldias, une note « Assuntos importados : … » qui parle de l'import
--     MLEG, pas du livre. Les sujets et contributeur·rices manquants sont
--     repris quand même (règle de fn_fusion_notices) : un sujet rejoint 1989.
-- Joué à blanc en production le 08/10 (deux fois, transaction annulée) :
-- 0 exemplaire décalé avant comme après, 5 lignes de merge_log.
-- Sur une base sans ces notices (banc d'essai), rien n'est fait.
-- =====================================================================

BEGIN;

DO $$
DECLARE
  p record; r jsonb; v_n int;
  c_paires constant text := '305:BTL-TL-000323:2473:MLEG-0016,304:BTL-TL-000322:2474:MLEG-0017,2311:0000112:2670:MLEG-0213,1990:BTL-TL-002123:2683:MLEG-0226,1989:BTL-TL-002122:2684:MLEG-0227';
BEGIN
  -- Toutes les notices doivent être là, sous la référence attendue ; sinon
  -- (banc d'essai, ou fusion déjà faite) on ne touche à rien.
  SELECT count(*) INTO v_n
    FROM unnest(string_to_array(c_paires, ',')) AS x(p)
    JOIN public.books c ON c.id = split_part(x.p, ':', 1)::bigint AND c.bib_ref = split_part(x.p, ':', 2)
    JOIN public.books d ON d.id = split_part(x.p, ':', 3)::bigint AND d.bib_ref = split_part(x.p, ':', 4);
  IF v_n <> 5 THEN
    RAISE NOTICE 'Tomes en double : % paire(s) sur 5 présentes, rien à faire.', v_n;
    RETURN;
  END IF;
  IF EXISTS (SELECT 1 FROM public.book_drafts d
              WHERE d.status = 'draft' AND d.published_book_id IN (305, 2473, 304, 2474, 2311, 2670, 1990, 2683, 1989, 2684)) THEN
    RAISE EXCEPTION 'Tomes en double : un brouillon ouvert est apparu sur une des dix notices — relire avant de fusionner';
  END IF;

  -- La session de Xavier, à sa demande (voir l'en-tête), le temps de la transaction.
  PERFORM set_config('request.jwt.claims', '{"sub":"d6710372-e5e5-4608-800b-99a26817c677","role":"authenticated"}', true);

  FOR p IN
    SELECT split_part(x.p, ':', 1)::bigint AS c, split_part(x.p, ':', 3)::bigint AS d, split_part(x.p, ':', 4) AS d_ref
      FROM unnest(string_to_array(c_paires, ',')) AS x(p)
  LOOP
    -- Le fonds MLEG garde sa cote : référence locale = cote de la notice qui disparaît.
    UPDATE public.book_holdings h SET local_bib_ref = p.d_ref
     WHERE h.book_id = p.d AND nullif(btrim(h.local_bib_ref), '') IS NULL;
    r := public.fn_fusion_notices(p.c, p.d, '{}', false);
    RAISE NOTICE 'Tomes en double : % ← % (%) : %', p.c, p.d, p.d_ref, r;
  END LOOP;

  PERFORM set_config('request.jwt.claims', '', true);

  -- Vérification
  IF EXISTS (SELECT 1 FROM public.books WHERE id IN (2473, 2474, 2670, 2683, 2684)) THEN
    RAISE EXCEPTION 'Tomes en double : un doublon subsiste';
  END IF;
  SELECT count(*) INTO v_n
    FROM public.exemplares e
    JOIN public.book_holdings h ON h.id = e.holding_id
    JOIN public.books b ON b.id = h.book_id
   WHERE e.bib_ref IS DISTINCT FROM coalesce(nullif(btrim(h.local_bib_ref), ''), b.bib_ref);
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'Tomes en double : % exemplaire(s) dont la référence ne suit pas son fonds', v_n;
  END IF;
  -- Chaque notice gardée a maintenant un fonds MLEG sous la cote MLEG, avec son exemplaire.
  SELECT count(*) INTO v_n
    FROM unnest(string_to_array(c_paires, ',')) AS x(p)
    JOIN public.book_holdings h ON h.book_id = split_part(x.p, ':', 1)::bigint AND h.local_bib_ref = split_part(x.p, ':', 4)
    JOIN public.libraries l ON l.id = h.library_id AND l.slug = 'mleg'
    JOIN public.exemplares e ON e.holding_id = h.id AND e.bib_ref = split_part(x.p, ':', 4);
  IF v_n <> 5 THEN
    RAISE EXCEPTION 'Tomes en double : % fonds MLEG sur 5 n''ont pas gardé leur cote', v_n;
  END IF;
  -- Rien n'a été copié des notices MLEG.
  IF EXISTS (SELECT 1 FROM public.books WHERE id IN (305, 304, 2311, 1990, 1989)
              AND (source_label IS NOT NULL OR provenance_note IS NOT NULL OR notas IS NOT NULL)) THEN
    RAISE EXCEPTION 'Tomes en double : un champ de la notice MLEG a été copié';
  END IF;
END $$;

COMMIT;
