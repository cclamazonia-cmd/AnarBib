-- =========================================================================
-- Le rattachement d'une notice à une autre œuvre s'exécute depuis l'écran :
-- assign_book_to_work retrouve son EXECUTE pour authenticated
-- =========================================================================
-- Date     : 2026-09-28
-- Chantier : OPAC par œuvre, lot 1b (« Rattacher à une autre œuvre ») ;
--            constat de Xavier du 28/09 au soir sur MLEG-0153.
--
-- LE CONSTAT. Dans le formulaire de catalogage, « Rattacher à une autre
-- œuvre » cherche (search_works_for_link, qui répond) puis rattache
-- (assign_book_to_work) : l'écran affichait « Une erreur technique est
-- survenue (42501) ». Journaux Postgres, 18:44 et 18:45 UTC :
--   permission denied for function assign_book_to_work
-- Le 02/09 (`20260902104830`, solde des différées B20), la fonction a été
-- fermée à authenticated parce qu'aucun écran ne l'appelait — c'était vrai ce
-- jour-là. Le 04/09 (`20260904130000`, lot 1b), elle a été réécrite pour
-- l'écran qui arrivait (elle supprime désormais l'œuvre quittée si elle reste
-- vide), et le paquet a accordé authenticated à merge_works, suggest_split_works,
-- mark_works_not_same et search_works_for_link — pas à assign_book_to_work :
-- un CREATE OR REPLACE garde l'ACL en place, et l'ACL en place était celle du
-- solde. La suite `oeuvres_rattachement_tests` (T4) l'appelle en `postgres`,
-- qui exécute tout : le chemin de l'écran n'a jamais été emprunté avant ce
-- soir (DOC : une RPC jamais empruntée ne marche pas).
--
-- LE GESTE. GRANT EXECUTE à authenticated — le régime du solde le prévoit
-- (« restauration = GRANT le jour où l'écran arrive ») ; anon reste fermé, la
-- garde staff du corps (librarian/coordenador actif) reste seule juge. La
-- suite `solde_des_differees_tests` sort la fonction de sa liste (45 fermées)
-- et l'ajoute aux chemins vivants ; `oeuvres_rattachement_tests` T4 vérifie
-- désormais aussi le droit. Rien d'autre ne change : corps, signature et
-- garde sont ceux du 04/09.
-- =========================================================================

BEGIN;

DO $entree$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                  WHERE n.nspname = 'public' AND p.proname = 'assign_book_to_work'
                    AND pg_get_function_identity_arguments(p.oid) = 'p_book_id bigint, p_work_id bigint'
                    AND p.prosecdef) THEN
    RAISE EXCEPTION 'rattachement : public.assign_book_to_work(bigint, bigint) SECURITY DEFINER introuvable — relire 20260904130000';
  END IF;
END
$entree$;

REVOKE EXECUTE ON FUNCTION public.assign_book_to_work(bigint, bigint) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.assign_book_to_work(bigint, bigint) TO authenticated, service_role;

DO $verif$
BEGIN
  IF NOT has_function_privilege('authenticated', 'public.assign_book_to_work(bigint,bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'rattachement : authenticated ne peut toujours pas exécuter assign_book_to_work';
  END IF;
  IF has_function_privilege('anon', 'public.assign_book_to_work(bigint,bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'rattachement : anon ne doit pas exécuter assign_book_to_work';
  END IF;
  -- La garde staff est toujours dans le corps : le droit d'exécuter n'est pas le droit de rattacher.
  IF (SELECT p.prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'public' AND p.proname = 'assign_book_to_work') NOT LIKE '%''librarian'',''coordenador''%' THEN
    RAISE EXCEPTION 'rattachement : la garde staff a disparu du corps d''assign_book_to_work';
  END IF;
END
$verif$;

COMMIT;
