-- =====================================================================
-- AnarBib — Paquet 20 v2 (fix critique) :
--   fn_resolve_caller_role_for_library retournait NULL pour les vrais lecteurs.
--
-- Date : 2026-05-11
--
-- BUG DETECTE :
--   Lors des tests d'acceptation paquet 20, le test 6.05 (Lívia renouvelle
--   son propre emprunt) a echoue avec :
--     'Acao nao autorizada (<NULL>/aberto) sobre emprestimo 27'
--
--   Le wrapper api.renew_my_loan appelle fn_resolve_caller_role_for_library
--   qui retournait NULL pour Lívia (membership active, role='reader' BLMF)
--   parce que la fonction ne reconnaissait QUE les roles staff (coordenador,
--   administrador, librarian) et retournait NULL pour tous les autres.
--
--   Cette fonction a ete creee dans la Phase 2 reservations ou elle suffisait
--   (les wrappers reservations verifient l'ownership avec auth.uid() directement).
--   Mais le paquet 19 a etendu son usage aux emprunts ou le role 'leitor'
--   est explicitement teste par fn_check_loan_action.
--
-- FIX :
--   Etendre la fonction pour retourner 'leitor' si l'user a une membership
--   active (status='active') sur la library, meme sans role staff.
--
-- RETRO-COMPATIBILITE :
--   - Les appelants qui testent IF role IS NULL (non-membres) continuent
--     a fonctionner : Patricia (sans membership active BLMF) reste NULL.
--   - Les appelants qui testent IF role = 'coordenador' / 'librarian' /
--     'administrador' ne sont pas affectes (ces valeurs continuent a etre
--     retournees pour les staff).
--   - Les appelants paquet 19 qui attendent 'leitor' pour les lecteurs
--     fonctionnent enfin correctement.
-- =====================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_resolve_caller_role_for_library(p_library_id uuid)
RETURNS text
LANGUAGE plpgsql
STABLE
SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;
  -- coordenador OU administrador (user_can_manage_library couvre les deux)
  IF user_can_manage_library(p_library_id) THEN
    RETURN 'coordenador';
  END IF;
  -- librarian
  IF user_has_library_staff_role(v_uid, p_library_id) THEN
    RETURN 'librarian';
  END IF;
  -- Paquet 20 v2 (11/05/2026, fix critique) : reconnaitre le role lecteur
  -- pour les users ayant une membership active sur la library.
  -- Auparavant, la fonction retournait NULL pour les vrais lecteurs, ce qui
  -- bloquait notamment api.renew_my_loan (fn_check_loan_action retournait
  -- false pour role=NULL).
  IF EXISTS (
    SELECT 1 
    FROM public.user_library_memberships
    WHERE user_id = v_uid
      AND library_id = p_library_id
      AND status = 'active'
  ) THEN
    RETURN 'leitor';
  END IF;
  -- ni l'un ni l'autre ni lecteur
  RETURN NULL;
END;
$function$;

COMMENT ON FUNCTION public.fn_resolve_caller_role_for_library(uuid) IS
'Resout le role de l''appelant auth.uid() sur la library donnee.
Retourne : coordenador, administrador (via user_can_manage_library),
librarian, leitor (paquet 20 v2 : membership active), ou NULL.';

COMMIT;

-- Tests post-deploiement :
-- 
-- 1. Livia (reader actif BLMF) doit retourner 'leitor' :
--    SET LOCAL ROLE authenticated;
--    SET LOCAL "request.jwt.claims" TO '{"sub": "366cdc4e-10e0-44ad-8554-a444bcf9607a", "role": "authenticated"}';
--    SELECT public.fn_resolve_caller_role_for_library('1234825f-a0f9-4fbd-a875-6551c30ea4ca'::uuid);
--    -- attendu : 'leitor'
--
-- 2. Xavier (coordenador) doit continuer a retourner 'coordenador' :
--    SET LOCAL "request.jwt.claims" TO '{"sub": "d6710372-e5e5-4608-800b-99a26817c677", "role": "authenticated"}';
--    SELECT public.fn_resolve_caller_role_for_library('1234825f-a0f9-4fbd-a875-6551c30ea4ca'::uuid);
--    -- attendu : 'coordenador'
--
-- 3. Patricia (sans membership active BLMF) doit retourner NULL :
--    SET LOCAL "request.jwt.claims" TO '{"sub": "2a42b6bd-d159-4ee0-b66b-28a03062232b", "role": "authenticated"}';
--    SELECT public.fn_resolve_caller_role_for_library('1234825f-a0f9-4fbd-a875-6551c30ea4ca'::uuid);
--    -- attendu : NULL
