-- ════════════════════════════════════════════════════════════════════════════
-- Renommage du tombo intrus SP-EX-000001 (coquille de saisie) chez BTL
-- Auteur  : Claude (Opus)
-- Session : Enrichissement données & backlog
-- Date    : 2026-06-10 (UTC)
--
-- L'exemplaire BTL id=2459 portait un tombo hors motif (« SP-EX-000001 »),
-- seul écart parmi les 2209 exemplaires BTL. Sa référence biblio est pourtant
-- déjà « BTL-TL-002364 » → la coquille n'était que sur le tombo.
--
-- On le réaligne sur le motif BTL en prenant le prochain tombo libre via
-- fn_next_tombo (déposée en 20260610000845). L'appel résout le numéro AU MOMENT
-- de l'application : robuste même si un exemplaire BTL a été créé entre-temps.
--
-- Idempotent : rejoué, le WHERE ne matche plus (no-op).
-- ════════════════════════════════════════════════════════════════════════════

UPDATE public.exemplares
   SET tombo = public.fn_next_tombo(library_id),
       updated_at = now()
 WHERE tombo = 'SP-EX-000001'
   AND library_id = 'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a';
