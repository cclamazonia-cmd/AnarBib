-- =====================================================================
-- AnarBib -- Le brouillon périmé de la notice 2287 est écarté
-- Date     : 2026-10-05
-- Auteur   : Claude (Opus 5.5), à la demande de Xavier
-- Session  : Recherche catalogue — auteur·rice et titres d'œuvre
--
-- CONSTAT. La notice 2287 (Nettlau, História da anarquia, Hedra 2008) a été
-- complétée le 05/10 par Xavier depuis l'écran de catalogage : Frank Mintz en
-- compilateur (organizador, coquille « Franck » corrigée), Plínio Augusto
-- Coelho en traducteur (publiée via le brouillon 6398). Le brouillon 6393,
-- ouvert à 07:51 et jamais repris, est resté « draft » avec l'ANCIENNE liste
-- (Nettlau ; « Mintz, Franck » / coordenador) : publié un jour, il effacerait
-- Coelho et remettrait la coquille.
--
-- GESTE. Il passe « cancelled » — ce que font l'application et la fusion de
-- notices pour un brouillon écarté ; rien n'est supprimé. Gardé par l'état
-- constaté (brouillon de la notice 2287, encore « draft ») ; sinon, rien.
-- =====================================================================

BEGIN;

UPDATE public.book_drafts
   SET status = 'cancelled', updated_at = now()
 WHERE id = 6393 AND published_book_id = 2287 AND status = 'draft';

COMMIT;
