-- =========================================================================
-- Fix : no-show / cancelada_biblioteca ne fermait pas l'entête reservas_v2
--       -> « 1 réservation active » fantôme au compte lecteur·rice
-- =========================================================================
-- Date     : 2026-06-17
-- Chantier : Bug compte lecteur·rice — divergence compteur réservations
-- Auteur   : Claude (assistant·e)
-- Session  : Bug résa active fantôme (no-show / entête)
--
-- Symptôme (signalé au navigateur, /conta, mobile) :
--   Les chips affichaient « Réservations actives : 0 » mais le bandeau d'état
--   affichait « Tu as 1 réservation active ». Deux sources divergentes.
--
-- Cause racine :
--   - Le bandeau d'état lit public.fn_my_account_status, qui compte des ENTÊTES
--     reservas_v2 (status_global IN ('ativa','parcialmente_encerrada')).
--   - Toutes les surfaces lectrice (chip, onglet « reservar », vue
--     api.my_reservations_active_v2) comptent des LIGNES (reserva_linhas_v2
--     item_status = 'ativa').
--   - La bascule no-show (api.mark_no_show / public.fn_detect_no_show_reservations
--     -> trigger trg_auto_liberate_after_no_show) libère la LIGNE
--     (item_status -> 'liberada_para_circulacao') mais NE rappelait PAS le
--     recompute canonique public.fn_v2_refresh_reserva_status_global. Résultat :
--     l'entête restait 'ativa' alors qu'aucune ligne n'est 'ativa'. Tous les
--     autres chemins terminaux (annulation lecteur/biblio, conversion en
--     emprunt) appellent ce recompute ; le no-show était le seul oubli.
--   Invariant attendu (cf. fn_v2_refresh_reserva_status_global) :
--     status_global='ativa' ssi TOUTES les lignes 'ativa' ;
--     status_global='encerrada' ssi AUCUNE ligne 'ativa'.
--
-- Correctif :
--   1) trg_auto_liberate_after_no_show_change rappelle désormais
--      fn_v2_refresh_reserva_status_global(NEW.reserva_id) après libération de
--      la ligne (idempotent ; couvre aussi la branche cancelada_biblioteca où le
--      recompute a déjà eu lieu en amont). Ferme l'entête à 'encerrada' dès qu'il
--      ne reste aucune ligne active.
--   2) Backfill des entêtes déjà désynchronisés (status_global stocké != recompute
--      canonique). Au moment du correctif : 1 ligne (reserva #29, no-show du 31/05
--      jamais clôturé). Requête générale -> auto-réparatrice.
--
-- Note : aucun changement frontend. Le bandeau d'état reflète l'entête ; une fois
-- l'entête correctement fermée, fn_my_account_status renvoie 0, aligné sur la chip.
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1) Trigger no-show : re-synchroniser l'entête depuis les lignes
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_auto_liberate_after_no_show_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  -- Propagation de l'etat a la ligne de reservation (inchange ; conditionnee
  -- par item_status = 'ativa' pour ne pas ecraser une issue terminale deja posee
  -- par cancel_reservation_as_library).
  UPDATE public.reserva_linhas_v2
  SET item_status = 'liberada_para_circulacao',
      updated_at = timezone('utc', now())
  WHERE reserva_id = NEW.reserva_id
    AND line_no = NEW.line_no
    AND item_status = 'ativa';

  -- CORRECTION 17/06/2026 : re-synchroniser l'entete depuis les lignes, comme
  -- tous les autres chemins terminaux (annulation lecteur/biblio, conversion en
  -- emprunt). Sans cela, status_global restait 'ativa' -> compteur
  -- « 1 reserva active » fantome au compte lecteur. Idempotent.
  PERFORM public.fn_v2_refresh_reserva_status_global(NEW.reserva_id);

  RETURN NEW;
END;
$function$;

-- -------------------------------------------------------------------------
-- 2) Backfill des entetes deja desynchronises (auto-reparateur, idempotent)
-- -------------------------------------------------------------------------
SELECT public.fn_v2_refresh_reserva_status_global(r.id)
FROM public.reservas_v2 r
WHERE r.status_global IS DISTINCT FROM (
  CASE
    WHEN (SELECT count(*) FROM public.reserva_linhas_v2 l WHERE l.reserva_id = r.id) = 0
      THEN 'encerrada'
    WHEN (SELECT count(*) FROM public.reserva_linhas_v2 l WHERE l.reserva_id = r.id AND l.item_status = 'ativa')
       = (SELECT count(*) FROM public.reserva_linhas_v2 l WHERE l.reserva_id = r.id)
      THEN 'ativa'
    WHEN (SELECT count(*) FROM public.reserva_linhas_v2 l WHERE l.reserva_id = r.id AND l.item_status = 'ativa') > 0
      THEN 'parcialmente_encerrada'
    ELSE 'encerrada'
  END
);

COMMIT;
