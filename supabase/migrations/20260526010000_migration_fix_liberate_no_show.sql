-- ============================================================================
-- Migration : correction propagation item_status sur libération automatique
-- Chantier  : BUG resa terminale classee active (audit UX Painel, 26/05/2026)
-- ============================================================================
--
-- PROBLEME
-- --------
-- Le trigger trg_auto_liberate_after_no_show (sur reserva_item_workflow_v2)
-- bascule workflow_stage -> 'liberada_para_circulacao' apres un no-show, mais
-- ne propage JAMAIS l'etat terminal a reserva_linhas_v2.item_status, qui reste
-- fige a 'ativa'. La reservation cloturee continue donc d'apparaitre dans la
-- file active du Painel et de l'espace lecteur (vues filtrant item_status='ativa').
--
-- Constat : 1 ligne concernee en production (reserva_item_id=19, resa 29.1).
--
-- CAUSE
-- -----
-- La fonction trg_auto_liberate_after_no_show_change() ne fait qu'un UPDATE sur
-- reserva_item_workflow_v2. Aucune des fonctions qui synchronisent item_status
-- (cancel_reservation_as_library, cancel_my_reservation, la fonction CASE
-- parametree) n'est sur le chemin no-show declenche par cron.
--
-- CORRECTION
-- ----------
-- 1. La fonction du trigger propage desormais l'etat a reserva_linhas_v2,
--    conditionnee par `item_status = 'ativa'`. Ce garde-fou garantit qu'on ne
--    touche QUE les lignes encore actives :
--      - no-show           -> ligne 'ativa'              -> propagation appliquee
--      - annulation biblio -> ligne deja 'cancelada_*'   -> WHERE exclut, intacte
--    L'issue de la reservation (annulation) prime ; le workflow ne decrit que
--    l'etat physique de l'exemplaire (remis en circulation). Pas de collision.
-- 2. UPDATE de rattrapage de la ligne 19 (resa 29.1).
-- 3. Bloc DO de verification : RAISE EXCEPTION -> rollback si echec.
--
-- DOCTRINE
-- --------
-- - SECURITY DEFINER + SET search_path : conserves de la fonction d'origine.
-- - Bloc permissions REMIS en conformite doctrine §5.2 (le dump portait une
--   forme historique REVOKE ALL FROM PUBLIC + GRANT service_role ; remplacee
--   par REVOKE EXECUTE etendu sans GRANT, forme fonction interne de trigger).
-- - Migration appliquee par Woodpecker (supabase db push --linked). Ne PAS
--   coller ce SQL dans le SQL Editor avant push.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Fonction du trigger corrigee
-- ----------------------------------------------------------------------------
-- Diff par rapport a l'original : ajout du bloc UPDATE reserva_linhas_v2 entre
-- l'UPDATE du workflow et le RETURN NEW. Tout le reste est identique.

CREATE OR REPLACE FUNCTION "public"."trg_auto_liberate_after_no_show_change"()
RETURNS "trigger"
LANGUAGE "plpgsql" SECURITY DEFINER
SET "search_path" TO 'public'
AS $$
DECLARE
  v_reason text;
BEGIN
  v_reason := CASE
    WHEN NEW.workflow_stage IN ('retirada_no_show', 'nao_retirada')
      THEN 'no_show'
    WHEN NEW.workflow_stage = 'cancelada_biblioteca'
      THEN 'cancelled_by_library'
    ELSE NULL
  END;

  IF v_reason IS NULL THEN
    RETURN NEW;
  END IF;

  -- Bascule du workflow vers l'etat de liberation (inchange).
  UPDATE public.reserva_item_workflow_v2
  SET workflow_stage = 'liberada_para_circulacao',
      final_reason = v_reason,
      updated_at = now()
  WHERE id = NEW.id;

  -- CORRECTION 26/05/2026 : propagation de l'etat terminal a la ligne de
  -- reservation. Conditionnee par item_status = 'ativa' :
  --  - no-show           : la ligne est encore 'ativa' -> on inscrit la
  --                        liberation, la resa cesse d'etre comptee active.
  --  - annulation biblio : cancel_reservation_as_library a deja pose
  --                        item_status = 'cancelada_biblioteca' AVANT cette
  --                        bascule -> le WHERE exclut la ligne, l'issue
  --                        terminale (annulation) est preservee.
  -- Le workflow_stage decrit l'etat physique de l'exemplaire ; item_status
  -- decrit l'issue de la reservation. Les deux dimensions restent distinctes.
  UPDATE public.reserva_linhas_v2
  SET item_status = 'liberada_para_circulacao',
      updated_at = timezone('utc', now())
  WHERE reserva_id = NEW.reserva_id
    AND line_no = NEW.line_no
    AND item_status = 'ativa';

  RETURN NEW;
END;
$$;

ALTER FUNCTION "public"."trg_auto_liberate_after_no_show_change"() OWNER TO "postgres";

-- Permissions (doctrine creation objets securises, §5.2 forme etendue).
-- Fonction interne de trigger : REVOKE nominatif sur les 4 roles applicatifs
-- (le REVOKE FROM PUBLIC seul ne suffit pas a cause du piege ALTER DEFAULT
-- PRIVILEGES de Supabase). AUCUN GRANT : une fonction de trigger n'est jamais
-- appelee par un role client, elle tourne via le moteur en SECURITY DEFINER ;
-- postgres conserve EXECUTE par defaut (cf. doctrine, fonction interne l.65).
-- NB : REVOKE volontairement sur UNE seule ligne (le hook pre-commit attend
-- 'REVOKE EXECUTE ... FROM PUBLIC' sans saut de ligne intermediaire).
REVOKE EXECUTE ON FUNCTION "public"."trg_auto_liberate_after_no_show_change"() FROM PUBLIC, anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 2. Rattrapage de la donnee corrompue (resa 29.1 / reserva_item_id = 19)
-- ----------------------------------------------------------------------------
-- Le WHERE inclut item_status = 'ativa' pour idempotence : si la ligne a deja
-- ete corrigee (re-run de la migration), l'UPDATE ne touche rien.

UPDATE public.reserva_linhas_v2
SET item_status = 'liberada_para_circulacao',
    updated_at = timezone('utc', now())
WHERE id = 19
  AND item_status = 'ativa';

-- ----------------------------------------------------------------------------
-- 3. Verification en fin de transaction (rollback automatique si echec)
-- ----------------------------------------------------------------------------
DO $$
DECLARE
  v_29_status text;
  v_orphans   integer;
BEGIN
  -- 3.a La ligne 19 doit etre passee a 'liberada_para_circulacao'.
  SELECT item_status INTO v_29_status
  FROM public.reserva_linhas_v2
  WHERE id = 19;

  IF v_29_status IS DISTINCT FROM 'liberada_para_circulacao' THEN
    RAISE EXCEPTION
      'Verification echouee : reserva_linhas_v2 id=19 a item_status=% (attendu liberada_para_circulacao)',
      coalesce(v_29_status, 'NULL');
  END IF;

  -- 3.b Plus aucune ligne 'ativa' ne doit avoir un workflow_stage terminal.
  --     Detecte d'eventuelles autres incoherences du meme type.
  SELECT count(*) INTO v_orphans
  FROM public.reserva_linhas_v2 rl
  JOIN public.reserva_item_workflow_v2 w
    ON w.reserva_id = rl.reserva_id
   AND w.line_no = rl.line_no
  WHERE rl.item_status = 'ativa'
    AND w.workflow_stage IN (
      'liberada_para_circulacao', 'retirada_efetivada',
      'cancelada_leitor', 'cancelada_biblioteca', 'expirada'
    );

  IF v_orphans > 0 THEN
    RAISE EXCEPTION
      'Verification echouee : % ligne(s) reserva_linhas_v2 encore ativa avec un workflow_stage terminal',
      v_orphans;
  END IF;

  RAISE NOTICE 'Verification OK : ligne 19 corrigee, aucune incoherence residuelle.';
END;
$$;

COMMIT;
