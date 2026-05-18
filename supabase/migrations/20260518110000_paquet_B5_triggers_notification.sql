-- ============================================================================
-- Migration : 20260518110000_paquet_B5_triggers_notification.sql
-- Chantier  : #98-B paquet B sous-paquet B.5 — triggers de notification
-- Date      : 18 mai 2026
-- ============================================================================
--
-- OBJET : ajouter 3 trigger functions + 3 triggers AFTER sur les tables d'audit
-- du paquet B, qui publient les events `library_profile.*` dans l'outbox via
-- les helpers symétriques fn_team_notify_event / fn_network_notify_event.
--
-- MAPPING SUB-EVENT → DECLENCHEUR → PERIMETRE :
--   library_profile.proposed   ← AFTER INSERT lpp WHERE status='open'    → team.*
--   library_profile.voted      ← AFTER INSERT lpv                        → team.*
--   library_profile.accepted   ← AFTER UPDATE lpp status→accepted_*      → network.*
--   library_profile.rejected   ← AFTER UPDATE lpp status→rejected|expired→ team.*
--   library_profile.cancelled  ← AFTER UPDATE lpp status→cancelled       → team.*
--   library_profile.executed   ← AFTER INSERT library_profile_history    → network.*
--
-- DECISIONS DOCTRINALES :
--
-- 1. PERIMETRE team.* vs network.* (validé 18/05) :
--    - team.* : processus de délibération interne (proposed, voted, cancelled,
--      rejected) → reste dans l'équipe de la biblio, le réseau n'a pas à
--      surveiller les débats internes (anti-doctrinal).
--    - network.* : résultat politique acquis (accepted, executed) → admins
--      réseau notifiés via le handler #114 + staff de la biblio via le
--      handler library_profile.
--
-- 2. INSERT lpp type 1 (direct) :
--    Une transition type 1 (sans vote) crée directement status='completed'
--    via fn_propose_*. L'INSERT trigger ne déclenche PAS 'proposed' dans ce
--    cas (filtre WHEN status='open'). L'event 'executed' sera levé par
--    l'INSERT trigger sur library_profile_history (côté fn_execute_*).
--    L'event 'accepted' n'est pas levé pour type 1 (pas d'étape carence).
--
-- 3. MAIL LECTEURS sur executed :
--    Sorti en B.7 séparé (handler distinct, autre destinataire, autre ton).
--    B.5 ne notifie que staff + admins réseau.
--
-- 4. SCHEMA PAYLOAD :
--    Tous les payloads incluent au minimum :
--      - library_id  : pour fan-out staff dans l'EF
--      - axis        : pour i18n du label d'axe
--      - actor_id    : auteur de l'action (proposeur / votant / staff exécutant)
--      - proposal_id : pour CTA URL « voir la proposition »
--    Champs additionnels selon sub-event (vote_count, old_value, new_value, …).
--
-- 5. DOCTRINE creation objets backend (#19) :
--    Les trigger functions sont SECURITY DEFINER + search_path TO public, pg_temp.
--    REVOKE EXECUTE TO PUBLIC, anon, authenticated, service_role (jamais
--    appelées depuis frontend, uniquement par le trigger AFTER en tant
--    qu'owner). Pas de GRANT à authenticated.
--
-- 6. DEFENSE EN PROFONDEUR :
--    Les trigger functions wrappent leurs appels notify dans un BEGIN/EXCEPTION
--    WHEN OTHERS pour qu'une panne notification ne casse jamais une mutation
--    métier (même pattern que fn_team_notify_event lui-même).
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. Trigger function : library_profile_proposals (INSERT + UPDATE status)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_notify_lpp_lifecycle()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_payload jsonb;
BEGIN
  -- =====================
  -- Cas A : INSERT
  -- =====================
  IF TG_OP = 'INSERT' THEN

    -- Type 1 (direct) → status créé directement à 'completed', pas de
    -- délibération. On laisse le trigger history s'occuper de 'executed'.
    -- On ne notifie 'proposed' que si la proposition entre réellement en vote.
    IF NEW.status = 'open' THEN
      v_payload := jsonb_build_object(
        'library_id',          NEW.library_id,
        'proposal_id',         NEW.id,
        'axis',                NEW.axis,
        'old_value',           NEW.old_value,
        'new_value',           NEW.new_value,
        'transition_type',     NEW.transition_type,
        'governance_required', NEW.governance_required,
        'motivation',          NEW.motivation,
        'actor_id',            NEW.proposed_by,
        'proposed_by',         NEW.proposed_by,
        'proposed_at',         NEW.proposed_at,
        'expires_at',          NEW.expires_at
      );
      PERFORM public.fn_team_notify_event('team.library_profile.proposed', v_payload);
    END IF;

    RETURN NEW;
  END IF;

  -- =====================
  -- Cas B : UPDATE (status transitions)
  -- =====================
  IF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN

    -- B.1 — accepted_unanimous | accepted_majority → network.*
    IF NEW.status IN ('accepted_unanimous', 'accepted_majority') THEN
      v_payload := jsonb_build_object(
        'library_id',          NEW.library_id,
        'proposal_id',         NEW.id,
        'axis',                NEW.axis,
        'old_value',           NEW.old_value,
        'new_value',           NEW.new_value,
        'transition_type',     NEW.transition_type,
        'governance_required', NEW.governance_required,
        'motivation',          NEW.motivation,
        'actor_id',            NEW.proposed_by,
        'proposed_by',         NEW.proposed_by,
        'proposed_at',         NEW.proposed_at,
        'accepted_status',     NEW.status,
        'unanimous_at',        NEW.unanimous_at,
        'majority_at',         NEW.majority_at,
        'grace_period_until',  NEW.grace_period_until
      );
      PERFORM public.fn_network_notify_event('network.library_profile.accepted', v_payload);

    -- B.2 — rejected | expired → team.*
    ELSIF NEW.status IN ('rejected', 'expired') THEN
      v_payload := jsonb_build_object(
        'library_id',      NEW.library_id,
        'proposal_id',     NEW.id,
        'axis',            NEW.axis,
        'old_value',       NEW.old_value,
        'new_value',       NEW.new_value,
        'transition_type', NEW.transition_type,
        'motivation',      NEW.motivation,
        'actor_id',        NEW.proposed_by,
        'proposed_by',     NEW.proposed_by,
        'reason',          NEW.status  -- 'rejected' ou 'expired'
      );
      PERFORM public.fn_team_notify_event('team.library_profile.rejected', v_payload);

    -- B.3 — cancelled → team.*
    ELSIF NEW.status = 'cancelled' THEN
      v_payload := jsonb_build_object(
        'library_id',           NEW.library_id,
        'proposal_id',          NEW.id,
        'axis',                 NEW.axis,
        'old_value',            NEW.old_value,
        'new_value',            NEW.new_value,
        'transition_type',      NEW.transition_type,
        'motivation',           NEW.motivation,
        'actor_id',             NEW.cancelled_by,
        'proposed_by',          NEW.proposed_by,
        'cancelled_by',         NEW.cancelled_by,
        'cancelled_at',         NEW.cancelled_at,
        'cancelled_motivation', NEW.cancelled_motivation
      );
      PERFORM public.fn_team_notify_event('team.library_profile.cancelled', v_payload);

    -- B.4 — 'completed' : pas de notif ici, la notif executed est levée
    -- par le trigger sur library_profile_history (déclenché par fn_execute_*).
    END IF;

    RETURN NEW;
  END IF;

  RETURN NEW;

EXCEPTION
  WHEN OTHERS THEN
    -- Une erreur de notification ne doit JAMAIS faire échouer la RPC métier.
    RAISE WARNING 'fn_notify_lpp_lifecycle échec pour proposal_id=% : %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$function$;

COMMENT ON FUNCTION public.fn_notify_lpp_lifecycle() IS
  'Trigger function (B.5) : publie team.library_profile.{proposed,rejected,cancelled} et network.library_profile.accepted dans l''outbox. Robuste aux erreurs notification (WARNING + continue).';

REVOKE EXECUTE ON FUNCTION public.fn_notify_lpp_lifecycle()
  FROM PUBLIC, anon, authenticated, service_role;


-- ============================================================================
-- 2. Trigger function : library_profile_votes (INSERT)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_notify_lpv_cast()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_proposal record;
  v_vote_count int;
  v_active_staff_count int;
  v_payload jsonb;
BEGIN
  -- On a besoin des infos de la proposition (library_id, axis, proposed_by)
  -- pour construire le payload. Lookup minimal.
  SELECT id, library_id, axis, old_value, new_value, transition_type,
         governance_required, proposed_by, motivation
  INTO v_proposal
  FROM public.library_profile_proposals
  WHERE id = NEW.proposal_id;

  IF NOT FOUND THEN
    RAISE WARNING 'fn_notify_lpv_cast : proposal % introuvable, skip notif', NEW.proposal_id;
    RETURN NEW;
  END IF;

  -- Compteur de votes actuel (utilisé pour la doctrine #21 : le proposeur
  -- n'est notifié QUE sur le 1er vote, puis silencieux jusqu'au résultat).
  SELECT COUNT(*)::int INTO v_vote_count
  FROM public.library_profile_votes
  WHERE proposal_id = NEW.proposal_id;

  -- Staff actif total (pour afficher « N/M voix » dans le mail).
  v_active_staff_count := public.fn_library_active_staff_count(v_proposal.library_id);

  v_payload := jsonb_build_object(
    'library_id',          v_proposal.library_id,
    'proposal_id',         v_proposal.id,
    'axis',                v_proposal.axis,
    'old_value',           v_proposal.old_value,
    'new_value',           v_proposal.new_value,
    'transition_type',     v_proposal.transition_type,
    'governance_required', v_proposal.governance_required,
    'motivation',          v_proposal.motivation,
    'actor_id',            NEW.voter_id,
    'proposed_by',         v_proposal.proposed_by,
    'vote',                NEW.vote,
    'rationale_against',   NEW.rationale_against,
    'voter_id',            NEW.voter_id,
    'voted_at',            NEW.voted_at,
    'vote_count',          v_vote_count,
    'active_staff_count',  v_active_staff_count,
    -- Hint pour l'EF : proposeur notifié uniquement si vote_count = 1
    'is_first_vote',       (v_vote_count = 1)
  );

  PERFORM public.fn_team_notify_event('team.library_profile.voted', v_payload);

  RETURN NEW;

EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'fn_notify_lpv_cast échec pour vote sur proposal=% : %', NEW.proposal_id, SQLERRM;
    RETURN NEW;
END;
$function$;

COMMENT ON FUNCTION public.fn_notify_lpv_cast() IS
  'Trigger function (B.5) : publie team.library_profile.voted dans l''outbox sur INSERT vote. Inclut vote_count et is_first_vote pour la doctrine proposeur silencieux après 1er vote (mémoire #21).';

REVOKE EXECUTE ON FUNCTION public.fn_notify_lpv_cast()
  FROM PUBLIC, anon, authenticated, service_role;


-- ============================================================================
-- 3. Trigger function : library_profile_history (INSERT)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_notify_lph_executed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_payload jsonb;
BEGIN
  -- Note : library_profile_history n'a pas de proposal_id direct, c'est un
  -- log d'événement. Le mail 'executed' renvoie donc vers la page profil
  -- biblio (et non vers une proposition spécifique).
  v_payload := jsonb_build_object(
    'library_id', NEW.library_id,
    'axis',       NEW.axis,
    'old_value',  NEW.old_value,
    'new_value',  NEW.new_value,
    'actor_id',   NEW.changed_by,
    'changed_by', NEW.changed_by,
    'changed_at', NEW.changed_at,
    'motivation', NEW.motivation,
    'history_id', NEW.id
  );

  PERFORM public.fn_network_notify_event('network.library_profile.executed', v_payload);

  RETURN NEW;

EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'fn_notify_lph_executed échec pour history_id=% : %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$function$;

COMMENT ON FUNCTION public.fn_notify_lph_executed() IS
  'Trigger function (B.5) : publie network.library_profile.executed dans l''outbox sur INSERT history. Notifie staff de la biblio + admins réseau (transition appliquée = info publique).';

REVOKE EXECUTE ON FUNCTION public.fn_notify_lph_executed()
  FROM PUBLIC, anon, authenticated, service_role;


-- ============================================================================
-- 4. Attachement des triggers
-- ============================================================================

CREATE TRIGGER trg_lpp_notify_lifecycle
  AFTER INSERT OR UPDATE ON public.library_profile_proposals
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_notify_lpp_lifecycle();

CREATE TRIGGER trg_lpv_notify_cast
  AFTER INSERT ON public.library_profile_votes
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_notify_lpv_cast();

CREATE TRIGGER trg_lph_notify_executed
  AFTER INSERT ON public.library_profile_history
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_notify_lph_executed();


-- ============================================================================
-- 5. DO block de vérification (fail-fast)
-- ============================================================================

DO $verif$
DECLARE
  v_violations int := 0;
  v_count int;
BEGIN
  -- 5.1 Les 3 trigger functions existent ?
  SELECT COUNT(*)::int INTO v_count
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public'
    AND p.proname IN ('fn_notify_lpp_lifecycle', 'fn_notify_lpv_cast', 'fn_notify_lph_executed');
  IF v_count <> 3 THEN
    RAISE WARNING 'VIOLATION : attendu 3 trigger functions, trouvé %', v_count;
    v_violations := v_violations + 1;
  END IF;

  -- 5.2 Les 3 trigger functions sont SECURITY DEFINER ?
  SELECT COUNT(*)::int INTO v_count
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public'
    AND p.proname IN ('fn_notify_lpp_lifecycle', 'fn_notify_lpv_cast', 'fn_notify_lph_executed')
    AND p.prosecdef = true;
  IF v_count <> 3 THEN
    RAISE WARNING 'VIOLATION : attendu 3 SECURITY DEFINER, trouvé %', v_count;
    v_violations := v_violations + 1;
  END IF;

  -- 5.3 Les 3 trigger functions sont privées (pas accessibles à anon/authenticated/service_role) ?
  SELECT COUNT(*)::int INTO v_count
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public'
    AND p.proname IN ('fn_notify_lpp_lifecycle', 'fn_notify_lpv_cast', 'fn_notify_lph_executed')
    AND (
      has_function_privilege('anon',          p.oid, 'EXECUTE') OR
      has_function_privilege('authenticated', p.oid, 'EXECUTE') OR
      has_function_privilege('service_role',  p.oid, 'EXECUTE')
    );
  IF v_count > 0 THEN
    RAISE WARNING 'VIOLATION : % trigger function(s) accessible(s) à anon/authenticated/service_role', v_count;
    v_violations := v_violations + 1;
  END IF;

  -- 5.4 Les 3 triggers sont attachés et enabled ?
  SELECT COUNT(*)::int INTO v_count
  FROM pg_trigger t
  JOIN pg_class c ON t.tgrelid = c.oid
  JOIN pg_namespace n ON c.relnamespace = n.oid
  WHERE n.nspname = 'public'
    AND t.tgname IN ('trg_lpp_notify_lifecycle', 'trg_lpv_notify_cast', 'trg_lph_notify_executed')
    AND NOT t.tgisinternal
    AND t.tgenabled = 'O';
  IF v_count <> 3 THEN
    RAISE WARNING 'VIOLATION : attendu 3 triggers enabled, trouvé %', v_count;
    v_violations := v_violations + 1;
  END IF;

  IF v_violations > 0 THEN
    RAISE EXCEPTION 'Paquet B.5 SQL : % violation(s), rollback', v_violations;
  END IF;

  RAISE NOTICE 'Paquet B.5 SQL : 3 trigger functions + 3 triggers en place, ACL correctes. OK.';
END
$verif$;

COMMIT;
