-- =====================================================================
-- AnarBib -- C18 : deux doublons de notices fusionnés (Nettlau, Kropotkine)
-- Date     : 2026-10-05  ·  Item C18 (backlog v34)
-- Auteur   : Claude (Opus 5.5), à la demande de Xavier
-- Session  : Recherche catalogue — auteur·rice et titres d'œuvre
--
-- CONSTAT (05/10, en instruisant C18) : deux éditions cataloguées deux fois.
--   · Nettlau, La Anarquía a través de los tiempos, Júcar 1978 :
--     1195 (BTL, cote locale BTL-TL-001276) et 2601 (MLEG, sans cote locale :
--     son fonds affiche la cote de la notice, MLEG-0144).
--   · Kropotkine, La Moral anarquista y otros escritos, Anarres/Terramar 2008 :
--     138 et 143, LES DEUX à la BTL (cotes BTL-TL-000137 et -000142) — deux
--     exemplaires d'une même édition.
--
-- AUTORISATION — À LIRE. La fusion de notices est un geste de coordination,
-- journalisé à son auteur (merge_log.merged_by) ; une migration n'a pas de
-- session. Xavier a demandé le 05/10, explicitement et après avoir été
-- prévenu, que ces deux fusions soient faites ici et inscrites SOUS SON
-- IDENTITÉ : la session est posée sur son compte (d6710372…, administration
-- réseau active, coordination BLMF) le temps de la transaction. Ce n'est PAS
-- un modèle pour d'autres migrations : une fusion se fait dans l'assistant
-- de doublons, par la personne qui en répond.
--
-- CE QUI EST FAIT (fn_fusion_notices, gardes comprises : arbitre, rattachement)
--   · 1195 → 2601 : la notice MLEG est gardée, pour que son fonds garde la
--     cote MLEG-0144 (gardée 1195, il aurait affiché BTL-TL-001276) ; le fonds
--     BTL garde sa cote locale. Repris de 1195 : titre et éditeur (choisis),
--     ISBN, langue et CDD (vides sur 2601).
--   · 143 → 138 : l'exemplaire BTL-TL-EX-000142 rejoint le fonds de 138 et
--     garde son numéro d'inventaire ; il affiche désormais la cote
--     BTL-TL-000137 (étiquette à refaire). Repris de 143 : l'éditeur, plus
--     précis. PAS les champs vides : 143 apporterait son sous-titre
--     « y otros escritos », déjà dans le titre de 138.
-- Joué à blanc en production le 05/10 (transaction annulée).
-- Sur une base sans ces notices (banc d'essai), rien n'est fait.
-- =====================================================================

BEGIN;

DO $$
DECLARE r1 jsonb; r2 jsonb;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.books WHERE id = 1195 AND bib_ref = 'BTL-TL-001276')
     OR NOT EXISTS (SELECT 1 FROM public.books WHERE id = 2601 AND bib_ref = 'MLEG-0144')
     OR NOT EXISTS (SELECT 1 FROM public.books WHERE id = 138 AND bib_ref = 'BTL-TL-000137')
     OR NOT EXISTS (SELECT 1 FROM public.books WHERE id = 143 AND bib_ref = 'BTL-TL-000142') THEN
    RAISE NOTICE 'C18 doublons : notices absentes ou déjà fusionnées, rien à faire.';
    RETURN;
  END IF;
  IF ARRAY['titulo', 'editora'] && public.fn_dedup_non_transferable_fields() THEN
    RAISE EXCEPTION 'C18 doublons : titulo ou editora devenu non reprenable';
  END IF;

  -- La session de Xavier, à sa demande (voir l'en-tête), le temps de la transaction.
  PERFORM set_config('request.jwt.claims', '{"sub":"d6710372-e5e5-4608-800b-99a26817c677","role":"authenticated"}', true);

  r1 := public.fn_fusion_notices(2601, 1195, ARRAY['titulo', 'editora'], true);
  r2 := public.fn_fusion_notices(138, 143, ARRAY['editora'], false);

  PERFORM set_config('request.jwt.claims', '', true);
  RAISE NOTICE 'C18 doublons : 1195 → 2601 %, 143 → 138 %', r1, r2;

  -- Vérification
  IF EXISTS (SELECT 1 FROM public.books WHERE id IN (1195, 143)) THEN
    RAISE EXCEPTION 'C18 doublons : un doublon subsiste';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.exemplares WHERE tombo = 'MLEG-2026-0144' AND bib_ref = 'MLEG-0144')
     OR NOT EXISTS (SELECT 1 FROM public.exemplares WHERE tombo = 'BTL-TL-EX-001276' AND bib_ref = 'BTL-TL-001276')
     OR (SELECT count(*) FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id
          WHERE h.book_id = 138 AND e.tombo IN ('BTL-TL-EX-000137', 'BTL-TL-EX-000142')) <> 2 THEN
    RAISE EXCEPTION 'C18 doublons : les exemplaires n''ont pas la cote attendue';
  END IF;
  IF (SELECT isbn FROM public.books WHERE id = 2601) IS DISTINCT FROM '84-334-1049-0'
     OR (SELECT subtitulo FROM public.books WHERE id = 138) IS NOT NULL THEN
    RAISE EXCEPTION 'C18 doublons : champs repris inattendus';
  END IF;
END $$;

COMMIT;
