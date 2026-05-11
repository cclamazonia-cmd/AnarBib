-- =============================================================================
-- Paquet 26 — Phase 3 consultations — Livrable 1 (toggles notifications)
-- Migration : 20260513120000_paquet26_consulta_notification_toggles
--
-- Ajoute 8 colonnes booléennes à public.library_notification_policies pour la
-- granularité fine des notifications consultations sur place, calquée sur le
-- pattern v3 réservations (paquet 5 du 07/05/2026).
--
-- Décision politique : dépasse la spec docs/spec-flux-consultations.md §7.4
-- qui propose 3 toggles globaux. Le calque v3 réservations offre une finesse
-- de contrôle anti-spam que les biblios pourront exploiter.
--
-- Master switch préexistant `local_consultation_enabled` (default true) est
-- conservé : il agit comme garde en amont dans les triggers de notification
-- (livrable 2) et les handlers (livrable 3). Si false → aucun mail consulta
-- n'est dispatché, indépendamment des 8 flags fins.
--
-- Defaults :
--   consulta_mail_criada_enabled            true   — création visible côté lecteur+biblio
--   consulta_mail_agendada_enabled          true   — créneau proposé visible côté lecteur
--   consulta_mail_resposta_creneau_enabled  true   — réponse lecteur visible côté biblio
--   consulta_mail_realizada_enabled         ?      — voir sondage Q (option 1/2/3)
--   consulta_mail_cancelada_enabled         true   — annulation visible des deux côtés
--   consulta_mail_expirada_enabled          true   — expiration visible des deux côtés
--   consulta_reminders_enabled              true   — placeholder rappels (§7.5 future)
--   admin_copy_consultas_enabled            true   — calque admin_copy_reservations_enabled
-- =============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Ajout des 8 colonnes (IF NOT EXISTS pour rejouabilité)
-- ----------------------------------------------------------------------------

ALTER TABLE public.library_notification_policies
  ADD COLUMN IF NOT EXISTS consulta_mail_criada_enabled
    boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS consulta_mail_agendada_enabled
    boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS consulta_mail_resposta_creneau_enabled
    boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS consulta_mail_realizada_enabled
    boolean NOT NULL DEFAULT false,  -- anti-spam : calque reservation_mail_liberada_para_circulacao_enabled (le lecteur sait, il etait sur place)
  ADD COLUMN IF NOT EXISTS consulta_mail_cancelada_enabled
    boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS consulta_mail_expirada_enabled
    boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS consulta_reminders_enabled
    boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS admin_copy_consultas_enabled
    boolean NOT NULL DEFAULT true;

-- ----------------------------------------------------------------------------
-- 2. Commentaires de table (traçabilité doctrine + audit futur)
-- ----------------------------------------------------------------------------

COMMENT ON COLUMN public.library_notification_policies.consulta_mail_criada_enabled IS
  'Paquet 26 — Notification de création de consultation locale (event consulta_v2_criada). Lecteur + copie biblio.';

COMMENT ON COLUMN public.library_notification_policies.consulta_mail_agendada_enabled IS
  'Paquet 26 — Notification de créneau proposé/reproposé (event consulta_v2_agendada). Lecteur uniquement, avec date+heure+timezone.';

COMMENT ON COLUMN public.library_notification_policies.consulta_mail_resposta_creneau_enabled IS
  'Paquet 26 — Notification de réponse lecteur au créneau (event consulta_v2_resposta_creneau). Biblio uniquement, confirmé ou refusé.';

COMMENT ON COLUMN public.library_notification_policies.consulta_mail_realizada_enabled IS
  'Paquet 26 — Notification de consultation réalisée (event consulta_v2_realizada). Log biblio uniquement (le lecteur sait, il était sur place). Default false par cohérence anti-spam avec reservation_mail_liberada_para_circulacao_enabled.';

COMMENT ON COLUMN public.library_notification_policies.consulta_mail_cancelada_enabled IS
  'Paquet 26 — Notification d''annulation (event consulta_v2_cancelada). Payload discriminant cancelled_by ∈ {leitor, biblioteca} pour routing.';

COMMENT ON COLUMN public.library_notification_policies.consulta_mail_expirada_enabled IS
  'Paquet 26 — Notification d''expiration automatique (event consulta_v2_expirada). Lecteur + copie biblio.';

COMMENT ON COLUMN public.library_notification_policies.consulta_reminders_enabled IS
  'Paquet 26 — Placeholder pour rappels consultations (§7.5 future de spec-flux-consultations.md, non implémentés au paquet 26).';

COMMENT ON COLUMN public.library_notification_policies.admin_copy_consultas_enabled IS
  'Paquet 26 — Active les copies admin biblio pour TOUS les events consulta_v2_*. Calque admin_copy_reservations_enabled.';

-- ----------------------------------------------------------------------------
-- 3. Sanity check post-migration (RAISE NOTICE si tout OK)
-- ----------------------------------------------------------------------------

DO $$
DECLARE
  v_missing text[] := ARRAY[]::text[];
  v_col text;
  v_expected text[] := ARRAY[
    'consulta_mail_criada_enabled',
    'consulta_mail_agendada_enabled',
    'consulta_mail_resposta_creneau_enabled',
    'consulta_mail_realizada_enabled',
    'consulta_mail_cancelada_enabled',
    'consulta_mail_expirada_enabled',
    'consulta_reminders_enabled',
    'admin_copy_consultas_enabled'
  ];
BEGIN
  FOREACH v_col IN ARRAY v_expected
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'library_notification_policies'
        AND column_name = v_col
    ) THEN
      v_missing := array_append(v_missing, v_col);
    END IF;
  END LOOP;

  IF array_length(v_missing, 1) > 0 THEN
    RAISE EXCEPTION 'Paquet 26 L1 — Colonnes manquantes après migration : %', v_missing;
  END IF;

  RAISE NOTICE 'Paquet 26 L1 OK — 8 colonnes consulta_mail_*/consulta_reminders_/admin_copy_consultas_ ajoutées à library_notification_policies';
  RAISE NOTICE 'Paquet 26 L1 — Master switch local_consultation_enabled (preexistant) conservé en garde amont.';
END;
$$;

COMMIT;
