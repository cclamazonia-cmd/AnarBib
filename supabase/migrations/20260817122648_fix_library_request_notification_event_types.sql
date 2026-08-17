-- =========================================================================
-- Paquet ONBO-#111 — Répare la file de notifications des demandes de biblio
-- =========================================================================
-- Date     : 2026-08-17
-- Chantier : Onboarding biblioteca (#111) — suite du Lot 2b
-- Auteur   : AnarBib · Session « notify-library-request : appel frontend mort »
--
-- POURQUOI
--   La migration 20260619001819_onbo_111_lot2b_mail_wiring.sql a élargi
--   l'allowlist *interne* de fn_enqueue_library_request_notification aux deux
--   nouveaux évènements du Lot 2a/2b :
--       'library_request_message'
--       'library_request_invitation'
--   … mais a oublié la contrainte CHECK de la table de file
--   public.library_request_notification_events, restée sur les 5 évènements
--   d'origine. Conséquence : l'INSERT dans la file viole la CHECK, la fonction
--   lève, et les triggers du Lot 2b (défensifs, cf. doctrine « enqueue jamais
--   bloquant ») avalent l'erreur en simple RAISE WARNING. Les notifications de
--   *message* et d'*invitation* d'échange n'ont donc jamais pu partir, sans
--   trace visible autre qu'un warning dans les logs Postgres.
--
--   Reproduit en transaction annulée sur la prod le 17/08/2026 :
--     enqueue message ECHOUE -> new row for relation
--     "library_request_notification_events" violates check constraint
--     "library_request_notification_events_event_type_check"
--
--   Le chemin 'library_request_created' (formulaire public), lui, fonctionne :
--   trg_library_requests_notify -> enqueue -> net.http_post avec l'en-tête
--   x-webhook-secret lu dans vault.decrypted_secrets. Vérifié dans la même
--   transaction annulée. Rien à recâbler de ce côté.
--
-- CE QUE FAIT CETTE MIGRATION
--   Aligne la CHECK de la table sur l'allowlist de la fonction (7 évènements).
--   Aucune donnée à migrer : la table est vide (0 ligne en prod au 17/08/2026),
--   et de toute façon on ne fait qu'élargir un domaine de valeurs.
--
-- DOCTRINE
--   Pas de fonction ni de table créée, pas de permission touchée : la
--   checklist SECURITY DEFINER / RLS / GRANT ne s'applique pas ici. Un bloc de
--   vérification (BLOC D) est tout de même fourni car la migration touche une
--   contrainte d'intégrité sur un chemin de notification silencieux.
-- =========================================================================

BEGIN;

ALTER TABLE public.library_request_notification_events
  DROP CONSTRAINT IF EXISTS library_request_notification_events_event_type_check;

ALTER TABLE public.library_request_notification_events
  ADD CONSTRAINT library_request_notification_events_event_type_check
  CHECK (event_type = ANY (ARRAY[
    'library_request_created'::text,
    'library_request_in_analysis'::text,
    'library_request_more_info'::text,
    'library_request_approved'::text,
    'library_request_refused'::text,
    'library_request_message'::text,      -- #111 Lot 2b
    'library_request_invitation'::text    -- #111 Lot 2b
  ]));

COMMENT ON CONSTRAINT library_request_notification_events_event_type_check
  ON public.library_request_notification_events IS
  'Doit rester aligné sur l''allowlist de public.fn_enqueue_library_request_notification. '
  'Élargi aux évènements message/invitation le 17/08/2026 (oubli du Lot 2b).';

-- -------------------------------------------------------------------------
-- BLOC D — Vérification automatique
-- -------------------------------------------------------------------------
-- Les triggers du Lot 2b avalent les erreurs d'enqueue : sans ce test, une
-- nouvelle désynchronisation CHECK / allowlist repasserait inaperçue.
DO $verif$
DECLARE
  v_def  text;
  v_ev   text;
  v_manquants text[] := ARRAY[]::text[];
BEGIN
  SELECT pg_get_constraintdef(oid) INTO v_def
  FROM pg_constraint
  WHERE conrelid = 'public.library_request_notification_events'::regclass
    AND conname  = 'library_request_notification_events_event_type_check';

  IF v_def IS NULL THEN
    RAISE EXCEPTION 'Vérification échouée : contrainte event_type absente. Rollback automatique.';
  END IF;

  FOREACH v_ev IN ARRAY ARRAY[
    'library_request_created',
    'library_request_in_analysis',
    'library_request_more_info',
    'library_request_approved',
    'library_request_refused',
    'library_request_message',
    'library_request_invitation'
  ] LOOP
    IF position(v_ev in v_def) = 0 THEN
      v_manquants := v_manquants || v_ev;
    END IF;
  END LOOP;

  IF array_length(v_manquants, 1) IS NOT NULL THEN
    RAISE EXCEPTION 'Vérification échouée : évènements absents de la CHECK : %. Rollback automatique.',
      array_to_string(v_manquants, ', ');
  END IF;

  RAISE NOTICE 'Paquet ONBO-#111 fix CHECK : OK, 7 évènements autorisés dans la file.';
END
$verif$;

COMMIT;

-- =========================================================================
-- Rollback ciblé en cas de régression post-déploiement :
-- =========================================================================
-- BEGIN;
--   ALTER TABLE public.library_request_notification_events
--     DROP CONSTRAINT library_request_notification_events_event_type_check;
--   ALTER TABLE public.library_request_notification_events
--     ADD CONSTRAINT library_request_notification_events_event_type_check
--     CHECK (event_type = ANY (ARRAY[
--       'library_request_created'::text, 'library_request_in_analysis'::text,
--       'library_request_more_info'::text, 'library_request_approved'::text,
--       'library_request_refused'::text]));
-- COMMIT;
-- =========================================================================
