-- =========================================================================
-- Rattachement d'une lectrice à la Biblioteca Terra Livre
-- =========================================================================
-- Date     : 2026-05-20
-- Chantier : spec onboarding — rattachement d'une lectrice orpheline (K1)
-- Auteur   : Xavier
--
-- Contexte : une personne disposant d'un compte sans aucun membership est
--            rattachée comme `reader` à la BTL, sans refaire le parcours
--            d'inscription complet. La promotion ultérieure éventuelle en
--            `librarian` passera par le flux de cooptation staff du frontend.
--
-- Les identifiants ci-dessous sont des UUID techniques. La correspondance
-- avec l'identité de la personne est tracée hors dépôt (doc de décision
-- interne), conformément à la doctrine de minimisation des données.
--
-- Idempotence : ON CONFLICT DO NOTHING sur la clé unique (user, library, role).
-- =========================================================================

BEGIN;

INSERT INTO public.user_library_memberships
  (user_id, library_id, role, status, is_primary)
VALUES
  ('79e58e6c-9ca4-491e-8b92-a51864e1bef3',  -- compte lectrice (UUID technique)
   'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a',  -- Biblioteca Terra Livre
   'reader',
   'active',
   true)
ON CONFLICT (user_id, library_id, role) DO NOTHING;

-- Vérification automatique
DO $verif$
DECLARE
  v_count int;
BEGIN
  SELECT count(*) INTO v_count
  FROM public.user_library_memberships
  WHERE user_id    = '79e58e6c-9ca4-491e-8b92-a51864e1bef3'
    AND library_id = 'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a'
    AND role = 'reader'
    AND status = 'active';

  IF v_count <> 1 THEN
    RAISE EXCEPTION 'VERIF_FAIL : membership reader absent ou en double (% trouvé)', v_count;
  END IF;

  RAISE NOTICE 'OK : lectrice rattachee a la BTL';
END
$verif$;

COMMIT;