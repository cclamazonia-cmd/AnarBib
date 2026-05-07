-- =============================================================================
-- Migration : Workflow réservation — Phase 1 (schéma DB)
-- Date      : 2026-05-07
-- Spec      : docs/specs/spec-workflow-reservation.md
-- =============================================================================
-- Objet : préparer le schéma pour le workflow complet de réservation à 6 états
--         + branches latérales. Ne touche AUCUNE donnée existante.
--
-- Décision politique tranchée le 07/05/2026 (cf. spec annexe C item 1) :
--   Sémantique de liberada_para_circulacao = OPTION B + final_reason.
--   liberada_para_circulacao est un nouveau stage qui REMPLACE retirada_no_show
--   ou cancelada_biblioteca (transition automatique via trigger), et la cause
--   de la libération est tracée dans la colonne final_reason.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. CHECK workflow_stage étendue : ajout de retirada_no_show
-- -----------------------------------------------------------------------------
-- L'alias historique nao_retirada est CONSERVÉ pour compatibilité avec les
-- anciens écrits éventuels et avec le mapping côté trigger trg_notify_*.
-- Aucune ligne n'utilise nao_retirada en prod (vérifié 07/05/2026).

ALTER TABLE public.reserva_item_workflow_v2
  DROP CONSTRAINT IF EXISTS reserva_item_workflow_v2_stage_chk;

ALTER TABLE public.reserva_item_workflow_v2
  ADD CONSTRAINT reserva_item_workflow_v2_stage_chk CHECK (
    workflow_stage = ANY (ARRAY[
      'solicitada'::text,
      'em_preparacao'::text,
      'pronta_para_retirada'::text,
      'retirada_a_combinar'::text,
      'retirada_agendada'::text,
      're-retirada_agendada'::text,
      'nao_retirada'::text,            -- alias historique de retirada_no_show
      'retirada_no_show'::text,        -- nom canonique de la spec
      'liberada_para_circulacao'::text,
      'retirada_efetivada'::text,
      'cancelada_leitor'::text,
      'cancelada_biblioteca'::text,
      'expirada'::text
    ])
  );

-- -----------------------------------------------------------------------------
-- 2. CHECK pickup_scheduled_for obligatoire pour les stages de retrait
-- -----------------------------------------------------------------------------

ALTER TABLE public.reserva_item_workflow_v2
  ADD CONSTRAINT chk_pickup_scheduled_for_required CHECK (
    workflow_stage NOT IN ('retirada_agendada', 're-retirada_agendada', 'retirada_a_combinar')
    OR pickup_scheduled_for IS NOT NULL
  );

-- -----------------------------------------------------------------------------
-- 3. Colonne final_reason + CHECK
-- -----------------------------------------------------------------------------
-- Renseignée automatiquement par trg_auto_liberate_after_no_show quand le stage
-- bascule en liberada_para_circulacao. NULL pour la ligne historique existante.

ALTER TABLE public.reserva_item_workflow_v2
  ADD COLUMN final_reason text;

ALTER TABLE public.reserva_item_workflow_v2
  ADD CONSTRAINT chk_final_reason CHECK (
    final_reason IS NULL
    OR final_reason IN ('no_show', 'cancelled_by_library')
  );

COMMENT ON COLUMN public.reserva_item_workflow_v2.final_reason IS
  'Cause de la bascule automatique en liberada_para_circulacao. ''no_show'' = lecteur·rice n''est pas venu·e ; ''cancelled_by_library'' = annulation par biblio. NULL = libération non causale (historique pré-2026-05-07 ou cas futurs non liés).';

-- -----------------------------------------------------------------------------
-- 4. Nouveaux timeouts dans library_notification_policies
-- -----------------------------------------------------------------------------

ALTER TABLE public.library_notification_policies
  ADD COLUMN reservation_solicitada_timeout_days int NOT NULL DEFAULT 14,
  ADD COLUMN reservation_no_show_timeout_hours int NOT NULL DEFAULT 24;

ALTER TABLE public.library_notification_policies
  ADD CONSTRAINT chk_solicitada_timeout
    CHECK (reservation_solicitada_timeout_days BETWEEN 7 AND 60),
  ADD CONSTRAINT chk_no_show_timeout
    CHECK (reservation_no_show_timeout_hours BETWEEN 12 AND 168);

COMMENT ON COLUMN public.library_notification_policies.reservation_solicitada_timeout_days IS
  'Nombre de jours après lequel une réservation reste ''solicitada'' avant expiration automatique par cron (default 14, range 7-60).';

COMMENT ON COLUMN public.library_notification_policies.reservation_no_show_timeout_hours IS
  'Nombre d''heures après pickup_scheduled_for au bout desquelles une réservation est marquée retirada_no_show par cron (default 24, range 12-168).';

-- -----------------------------------------------------------------------------
-- 5. 12 flags reservation_mail_*_enabled
-- -----------------------------------------------------------------------------
-- Default true SAUF liberada_para_circulacao (false : anti-spam, le lecteur a
-- déjà été notifié de l'annulation/no_show, on ne re-spam pas).

ALTER TABLE public.library_notification_policies
  ADD COLUMN reservation_mail_solicitada_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation_mail_em_preparacao_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation_mail_retirada_agendada_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation_mail_retirada_a_combinar_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation_mail_pronta_para_retirada_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation_mail_retirada_reagendada_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation_mail_retirada_no_show_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation_mail_expirada_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation_mail_cancelada_leitor_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation_mail_cancelada_biblioteca_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN reservation_mail_liberada_para_circulacao_enabled boolean NOT NULL DEFAULT false,
  ADD COLUMN reservation_mail_retirada_efetivada_enabled boolean NOT NULL DEFAULT true;

-- -----------------------------------------------------------------------------
-- 6. Trigger trg_auto_liberate_after_no_show (option B)
-- -----------------------------------------------------------------------------
-- Quand workflow_stage bascule en retirada_no_show / nao_retirada (alias) /
-- cancelada_biblioteca, on cascade automatiquement en liberada_para_circulacao
-- avec final_reason renseigné. Cette nouvelle UPDATE déclenchera à son tour
-- trg_notify_reserva_workflow qui enverra le mail liberada_para_circulacao
-- (sous réserve du flag reservation_mail_liberada_para_circulacao_enabled).
--
-- La condition WHEN exclut déjà liberada_para_circulacao comme valeur source,
-- ce qui empêche toute récursion : la deuxième UPDATE (vers liberada_*) ne
-- re-déclenche PAS ce trigger.

CREATE OR REPLACE FUNCTION public.trg_auto_liberate_after_no_show_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_reason text;
BEGIN
  -- Mapping stage source → final_reason
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

  -- Cascade : nouvelle UPDATE vers liberada_para_circulacao
  -- (l'updated_by reste celui de l'action déclenchante, à inspecter post-impl)
  UPDATE public.reserva_item_workflow_v2
  SET workflow_stage = 'liberada_para_circulacao',
      final_reason = v_reason,
      updated_at = now()
  WHERE id = NEW.id;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.trg_auto_liberate_after_no_show_change() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.trg_auto_liberate_after_no_show_change() FROM anon;
REVOKE ALL ON FUNCTION public.trg_auto_liberate_after_no_show_change() FROM authenticated;

CREATE TRIGGER trg_auto_liberate_after_no_show
  AFTER UPDATE OF workflow_stage ON public.reserva_item_workflow_v2
  FOR EACH ROW
  WHEN (
    NEW.workflow_stage IN ('retirada_no_show', 'nao_retirada', 'cancelada_biblioteca')
    AND OLD.workflow_stage IS DISTINCT FROM NEW.workflow_stage
  )
  EXECUTE FUNCTION public.trg_auto_liberate_after_no_show_change();

COMMIT;

-- =============================================================================
-- Smoke tests post-migration (à exécuter en lecture pour vérifier la cohérence)
-- =============================================================================
-- 1. La CHECK workflow_stage doit lister 13 valeurs incluant retirada_no_show.
-- 2. La colonne final_reason existe et la ligne liberada_para_circulacao
--    historique a final_reason = NULL.
-- 3. library_notification_policies a 14 nouvelles colonnes (2 timeouts + 12 flags).
-- 4. Le trigger trg_auto_liberate_after_no_show est listé sur la table.
-- =============================================================================
