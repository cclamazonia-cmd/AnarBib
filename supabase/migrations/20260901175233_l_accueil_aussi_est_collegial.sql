-- =====================================================================
-- 20260901175233_l_accueil_aussi_est_collegial.sql
--
-- Objet : GOUV-13 — T1 (reader -> librarian) cesse d'être unilatérale.
--         La promotion directe est condamnée ; l'accueil passe par le
--         circuit d'invitation, qui a été construit pour lui.
--
-- Constat (cadrage CADRAGE_promotion_directe_reader_coordenador_2026-09-01
-- §2.3, arbitré le 01/09/2026 au soir) : depuis la v1.4 de la spec
-- gouvernance, T2 est collégiale et — depuis GOUV-11 — même le saut
-- reader -> coordenador exige proposition, endossement et acceptation.
-- fn_team_promote_to_librarian restait le seul chemin où UNE personne
-- donnait un rôle staff à une autre, sur-le-champ et sans son
-- consentement : le chemin le MOINS collégial du modèle, pour l'entrée
-- dans l'équipe. P2 prescrit la cooptation pour les deux rôles staff ;
-- P3 fait du consentement un droit. Même remède que GOUV-1/GOUV-4 :
--   - le circuit d'invitation (p_role='librarian') est le seul chemin ;
--   - la fonction est conservée (signature, droits, appelants) mais lève
--     `collegiality_required` en désignant le chemin — un échec bruyant
--     qui instruit vaut mieux qu'un 404 (GOUV-4).
--
-- Le quorum du circuit protège déjà les petites équipes (bootstrap :
-- moins de 2 staff hors personne visée => 1 endossement) ; ce qui change
-- vraiment, partout, c'est que la personne ACCEPTE.
--
-- Idempotente : CREATE OR REPLACE (ACL conservées).
-- Rollback : _rollback_20260901175233_l_accueil_aussi_est_collegial.sql
-- Tests : tests/sql/t1_accueil_collegial_tests.sql
-- =====================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_team_promote_to_librarian(
  p_user_id uuid,
  p_library_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  RAISE EXCEPTION 'collegiality_required: direct promotion to librarian is disabled'
    USING ERRCODE = '0A000',
          HINT = 'Use fn_team_propose_invitation(p_library_id, <public_id>, ''librarian''), '
                 'then fn_team_ratify_invitation() by another staff member (per the '
                 'team_admission_mode quorum), then fn_team_accept_invitation() by the '
                 'person concerned.';
END
$fn$;

COMMENT ON FUNCTION public.fn_team_promote_to_librarian(uuid, uuid) IS
  'CONDAMNÉE (GOUV-13, 01/09/2026) : lève collegiality_required. L''accueil dans l''équipe passe par le circuit d''invitation (fn_team_propose_invitation, p_role=''librarian''). Conservée pour que ses appelants reçoivent une erreur qui instruit plutôt qu''un 404 (même doctrine que fn_team_promote_to_coordenador, GOUV-4).';

-- ---------------------------------------------------------------------
-- Vérification : ce que CETTE migration fait (DOC-DEPLOY-4)
-- ---------------------------------------------------------------------

DO $do$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = 'fn_team_promote_to_librarian'
       AND p.prosrc LIKE '%collegiality_required%'
  ) THEN
    RAISE EXCEPTION 'verification: fn_team_promote_to_librarian promeut encore';
  END IF;
END
$do$;

COMMIT;
