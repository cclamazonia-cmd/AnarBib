-- =========================================================================
-- Refus d'une inscription en attente (action « Recusar »)
-- =========================================================================
-- Date     : 2026-06-22
-- Chantier : validation des inscriptions (BLMF) — Suite 6
-- Auteur   : Claude (livré en fichier, appliqué par Forgejo / supabase db push)
--
-- Contexte : le flux de validation n'avait QUE « Validar ». Quand une rencontre
-- présentielle conclut à un refus, le staff n'avait aucun moyen de clore la
-- demande. On ajoute un refus, décidé ainsi (Xavier) :
--   • silencieux (aucune notification — adapté à une biblio masquée),
--   • statut terminal 'removed' → la personne PEUT se ré-inscrire plus tard
--     (api.request_membership autorise un nouveau départ depuis 'removed'),
--   • raison conservée en note dans membership_validation_log.
--
-- 3 morceaux :
--   1. Élargir la contrainte d'action du journal à 'refused'.
--   2. Corriger fn_log_reader_membership_event : une transition
--      'pending_validation' → terminal est un refus/abandon de CANDIDATURE
--      (jamais active) → 'outro', PAS 'saida' (sinon les relatórios comptent
--      un départ fantôme).
--   3. RPC api.reject_membership (staff librarian+, même garde que validate).
-- =========================================================================

BEGIN;

-- ── 1. Contrainte d'action du journal ────────────────────────────────────
ALTER TABLE public.membership_validation_log
  DROP CONSTRAINT membership_validation_log_action_check;
ALTER TABLE public.membership_validation_log
  ADD CONSTRAINT membership_validation_log_action_check
  CHECK (action = ANY (ARRAY['validated', 'revalidated', 'invalidated', 'refused']));

-- ── 2. Journal de cycle de vie : pending → terminal = 'outro', pas 'saida' ─
-- (Reprise intégrale de fn_log_reader_membership_event + 1 branche ajoutée.)
CREATE OR REPLACE FUNCTION public.fn_log_reader_membership_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_old text := null;
  v_event text;
  v_terminal constant text[] := array['removed','inactive','terminated','left_with_pending_circulation'];
  v_is_promotion boolean := false;
begin
  if new.role <> 'reader' then
    return null;
  end if;
  if tg_op = 'UPDATE' then
    if new.status is not distinct from old.status then
      return null;
    end if;
    v_old := old.status;
  end if;

  if new.status = 'active' and (v_old is null or v_old = 'pending_validation') then
    v_event := 'inscricao';
  elsif new.status = 'active' and v_old = any(v_terminal) then
    v_event := 'reativacao';
  elsif new.status = any(v_terminal) and v_old = 'pending_validation' then
    -- Suite 6 : candidature refusée/abandonnée (jamais active) → pas un départ.
    v_event := 'outro';
  elsif new.status = any(v_terminal) and (v_old is null or not (v_old = any(v_terminal))) then
    select exists (select 1 from public.user_library_memberships s
                   where s.user_id = new.user_id and s.library_id = new.library_id
                     and s.role <> 'reader' and s.status = 'active')
      into v_is_promotion;
    v_event := case when v_is_promotion then 'promocao' else 'saida' end;
  elsif new.status = 'pending_validation' then
    v_event := 'solicitacao';
  else
    v_event := 'outro';
  end if;

  insert into public.reader_membership_events
    (membership_id, library_id, user_id, role, old_status, new_status, event_type, actor_user_id)
  values
    (new.id, new.library_id, new.user_id, new.role, v_old, new.status, v_event, auth.uid());

  return null;
end;
$function$;

-- ── 3. RPC de refus ───────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION api.reject_membership(p_membership_id uuid, p_note text DEFAULT NULL::text)
RETURNS TABLE(ok boolean, message text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_caller uuid := auth.uid();
  v_m record;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Autenticação obrigatória.';
  END IF;

  SELECT m.id, m.user_id, m.library_id, m.status INTO v_m
  FROM public.user_library_memberships m WHERE m.id = p_membership_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Associação não encontrada.';
  END IF;

  -- Staff actif (librarian/coordenador) de CETTE biblio — même garde que
  -- api.validate_membership.
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships s
    WHERE s.user_id = v_caller AND s.library_id = v_m.library_id
      AND s.role IN ('librarian', 'coordenador') AND s.status = 'active'
  ) THEN
    RAISE EXCEPTION 'Acesso de equipe obrigatório nesta biblioteca.'
      USING ERRCODE = 'P0001', HINT = 'error.staff_required';
  END IF;

  IF v_m.status <> 'pending_validation' THEN
    RAISE EXCEPTION 'Esta associação não está pendente de validação.'
      USING ERRCODE = 'P0001', HINT = 'error.membership.not_pending';
  END IF;

  -- Refus silencieux : statut terminal 'removed' (re-candidature possible),
  -- raison en note. AUCUN dispatch de notification (cf. décision Suite 6).
  UPDATE public.user_library_memberships
    SET status = 'removed', updated_at = now()
    WHERE id = p_membership_id;

  INSERT INTO public.membership_validation_log
    (membership_id, user_id, library_id, action, performed_by_user_id, local_reader_number, note)
  VALUES
    (p_membership_id, v_m.user_id, v_m.library_id, 'refused', v_caller, NULL, p_note);

  RETURN QUERY SELECT true, 'Inscrição recusada.'::text;
END $function$;

REVOKE EXECUTE ON FUNCTION api.reject_membership(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.reject_membership(uuid, text) TO authenticated;

COMMENT ON FUNCTION api.reject_membership(uuid, text) IS
  'Refuse une inscription en attente (staff librarian+). Statut → removed (re-candidature possible), action « refused » journalisée, AUCUNE notification. Suite 6, 22/06/2026.';

NOTIFY pgrst, 'reload schema';

-- ── Vérification ──────────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'api' AND p.proname = 'reject_membership'
  ) THEN
    RAISE EXCEPTION 'Vérification échouée : api.reject_membership absente. Rollback.';
  END IF;
  -- La contrainte doit désormais accepter 'refused'.
  PERFORM 1;
  RAISE NOTICE 'reject_membership + contrainte + trigger OK.';
END $$;

COMMIT;

-- =========================================================================
-- Rollback ciblé :
-- =========================================================================
-- BEGIN;
--   DROP FUNCTION IF EXISTS api.reject_membership(uuid, text);
--   -- (restaurer l'ancienne fn_log_reader_membership_event sans la branche refus)
--   -- (restaurer la contrainte sans 'refused')
--   NOTIFY pgrst, 'reload schema';
-- COMMIT;
-- =========================================================================
