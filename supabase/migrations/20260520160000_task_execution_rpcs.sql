-- =============================================================================
-- 20260520160000_task_execution_rpcs.sql
-- =============================================================================
-- Chantier audit Biblioteca, sous-chantier EA-15 (4 RPC tasks).
-- Cf. docs/decisions/CHANTIER_audit_biblioteca_parite_doctrinale_2026-05-21.md
--
-- Objectif :
--   Créer 4 RPC d'exécution pour les tâches internes, permettre au frontend
--   de basculer ses 4 appels .from() direct sur des RPC contrôlées, et
--   aligner le frontend sur l'infrastructure backend existante (triggers
--   sync_task_invites_from_task et enqueue_task_level_notifications_from_task).
--
-- Architecture (option C, décidée 21/05) :
--   - fn_task_create        : insère une task (status default = 'pendente')
--   - fn_task_update_status : change le status
--   - fn_task_delete        : supprime une task (cascade items via FK)
--   - fn_task_invite        : RPC intelligente — ajoute l'email aux tags
--     de la task, puis appelle sync_task_invites_from_task pour créer
--     proprement l'invite via l'infrastructure existante (au lieu d'insérer
--     directement dans painel_internal_task_invites comme le faisait le
--     frontend court-circuitant).
--
-- Convention statut (décidée 21/05) :
--   - Default backend aligné sur le frontend : 'aberta' → 'pendente'
--   - Pas de CHECK constraint (chantier hygiène SQL ultérieur)
--   - 1 task historique en prod (status='concluida', 27/04) — aucune
--     migration de données nécessaire
--   - Alignement parallèle invite_status : 'pending' → 'pendente'
--
-- Doctrine RPC v3 (actée 21/05) :
--   - SECURITY INVOKER explicite (les RLS existantes font le travail :
--     user_can_act_as_staff_on_library pour les 4 opérations)
--   - SET search_path = public, pg_temp
--   - REVOKE PUBLIC + GRANT EXECUTE authenticated
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. Alignement defaults statut
-- -----------------------------------------------------------------------------
-- Le default 'aberta' n'a jamais été utilisé en prod (le frontend force
-- 'pendente' à la création). On aligne pour clarté et cohérence future.

ALTER TABLE public.painel_internal_tasks
  ALTER COLUMN status SET DEFAULT 'pendente';

ALTER TABLE public.painel_internal_task_invites
  ALTER COLUMN invite_status SET DEFAULT 'pendente';


-- -----------------------------------------------------------------------------
-- 1. fn_task_create
-- -----------------------------------------------------------------------------
-- Crée une task interne pour une biblio.
--
-- Paramètres :
--   p_library_id  : uuid de la biblio
--   p_title       : titre (NOT NULL)
--   p_description : description (nullable)
--   p_priority    : priorité ('baixa', 'media', 'alta') — default 'media'
--   p_owner       : nom du responsable (nullable)
--   p_due_date    : date d'échéance (nullable)
--   p_tags        : tags array (default [])
-- Retour :
--   jsonb de la task créée
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_task_create(
  p_library_id  uuid,
  p_title       text,
  p_description text DEFAULT NULL,
  p_priority    text DEFAULT 'media',
  p_owner       text DEFAULT NULL,
  p_due_date    date DEFAULT NULL,
  p_tags        text[] DEFAULT ARRAY[]::text[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_new painel_internal_tasks%ROWTYPE;
BEGIN
  -- Validation minimale
  IF p_library_id IS NULL OR p_title IS NULL OR btrim(p_title) = '' THEN
    RAISE EXCEPTION 'fn_task_create: p_library_id et p_title obligatoires';
  END IF;

  -- INSERT (la RLS painel_internal_tasks_insert vérifie
  -- user_can_act_as_staff_on_library automatiquement)
  INSERT INTO painel_internal_tasks (
    library_id,
    title,
    description,
    priority,
    status,
    owner,
    due_date,
    tags
  )
  VALUES (
    p_library_id,
    btrim(p_title),
    NULLIF(btrim(COALESCE(p_description, '')), ''),
    COALESCE(p_priority, 'media'),
    'pendente',  -- doctrine 21/05 : statut frontend
    NULLIF(btrim(COALESCE(p_owner, '')), ''),
    p_due_date,
    COALESCE(p_tags, ARRAY[]::text[])
  )
  RETURNING * INTO v_new;

  RETURN to_jsonb(v_new);
END;
$$;

COMMENT ON FUNCTION public.fn_task_create IS
  'Crée une task interne pour une biblio. Sécurité par RLS héritée (INVOKER). EA-15.';

REVOKE ALL ON FUNCTION public.fn_task_create FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_task_create TO authenticated;


-- -----------------------------------------------------------------------------
-- 2. fn_task_update_status
-- -----------------------------------------------------------------------------
-- Change le status d'une task.
--
-- Paramètres :
--   p_task_id    : uuid de la task
--   p_new_status : nouveau status ('pendente', 'em_andamento', 'concluida',
--                  'cancelada' — pas de CHECK, validation laissée à un
--                  chantier ultérieur)
-- Retour :
--   jsonb de la task mise à jour
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_task_update_status(
  p_task_id    uuid,
  p_new_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_updated painel_internal_tasks%ROWTYPE;
BEGIN
  IF p_task_id IS NULL OR p_new_status IS NULL OR btrim(p_new_status) = '' THEN
    RAISE EXCEPTION 'fn_task_update_status: p_task_id et p_new_status obligatoires';
  END IF;

  -- La RLS painel_internal_tasks_update vérifie automatiquement
  -- user_can_act_as_staff_on_library.
  UPDATE painel_internal_tasks
  SET status = btrim(p_new_status)
  WHERE id = p_task_id
  RETURNING * INTO v_updated;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'fn_task_update_status: task id=% introuvable ou accès refusé', p_task_id;
  END IF;

  RETURN to_jsonb(v_updated);
END;
$$;

COMMENT ON FUNCTION public.fn_task_update_status IS
  'Change le status d''une task. Sécurité par RLS héritée (INVOKER). EA-15.';

REVOKE ALL ON FUNCTION public.fn_task_update_status FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_task_update_status TO authenticated;


-- -----------------------------------------------------------------------------
-- 3. fn_task_delete
-- -----------------------------------------------------------------------------
-- Supprime une task. Les invites associées sont gérées soit par cascade FK
-- (à vérifier), soit explicitement ici par sécurité.
--
-- Paramètres :
--   p_task_id : uuid de la task à supprimer
-- Retour :
--   jsonb {deleted_task_id, deleted_invites_count}
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_task_delete(
  p_task_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_invites_deleted integer;
  v_task_exists boolean;
BEGIN
  IF p_task_id IS NULL THEN
    RAISE EXCEPTION 'fn_task_delete: p_task_id obligatoire';
  END IF;

  -- Vérification d'existence (la RLS SELECT filtre déjà à la biblio de l'user)
  SELECT EXISTS(SELECT 1 FROM painel_internal_tasks WHERE id = p_task_id)
  INTO v_task_exists;

  IF NOT v_task_exists THEN
    RAISE EXCEPTION 'fn_task_delete: task id=% introuvable ou accès refusé', p_task_id;
  END IF;

  -- DELETE explicite des invites associées (sécurité : ne pas dépendre
  -- d'une FK ON DELETE CASCADE qui pourrait être absente)
  WITH deleted_invites AS (
    DELETE FROM painel_internal_task_invites
    WHERE task_id = p_task_id
    RETURNING 1
  )
  SELECT COUNT(*) INTO v_invites_deleted FROM deleted_invites;

  -- DELETE de la task (RLS painel_internal_tasks_delete)
  DELETE FROM painel_internal_tasks WHERE id = p_task_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'fn_task_delete: DELETE de task id=% refusé par RLS', p_task_id;
  END IF;

  RETURN jsonb_build_object(
    'deleted_task_id', p_task_id,
    'deleted_invites_count', v_invites_deleted
  );
END;
$$;

COMMENT ON FUNCTION public.fn_task_delete IS
  'Supprime une task et ses invites en cascade. Sécurité par RLS héritée (INVOKER). EA-15.';

REVOKE ALL ON FUNCTION public.fn_task_delete FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_task_delete TO authenticated;


-- -----------------------------------------------------------------------------
-- 4. fn_task_invite — RPC INTELLIGENTE
-- -----------------------------------------------------------------------------
-- Au lieu d'insérer directement dans painel_internal_task_invites (ce que
-- faisait le frontend, court-circuitant l'infrastructure backend), cette
-- RPC ajoute l'email aux tags de la task et laisse le trigger
-- tg_sync_task_invites_from_task gérer la création de l'invite proprement.
--
-- Avantage : cohérence avec le modèle backend (tags = source de vérité,
-- invites = vue dérivée synchronisée).
--
-- Paramètres :
--   p_task_id      : uuid de la task
--   p_invite_email : email à inviter
-- Retour :
--   jsonb {task_id, invite_email, tags_updated_count, sync_status}
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_task_invite(
  p_task_id      uuid,
  p_invite_email text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_email_clean text;
  v_task_exists boolean;
  v_existing_tags text[];
  v_new_tags text[];
BEGIN
  -- Validation
  IF p_task_id IS NULL THEN
    RAISE EXCEPTION 'fn_task_invite: p_task_id obligatoire';
  END IF;

  v_email_clean := btrim(lower(COALESCE(p_invite_email, '')));

  IF v_email_clean = '' THEN
    RAISE EXCEPTION 'fn_task_invite: p_invite_email obligatoire';
  END IF;

  -- Validation email basique (présence d'un @ et d'un .)
  IF v_email_clean !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' THEN
    RAISE EXCEPTION 'fn_task_invite: email invalide (%)', v_email_clean;
  END IF;

  -- Vérifier que la task existe et est visible à l'user (RLS SELECT)
  SELECT EXISTS(SELECT 1 FROM painel_internal_tasks WHERE id = p_task_id)
  INTO v_task_exists;

  IF NOT v_task_exists THEN
    RAISE EXCEPTION 'fn_task_invite: task id=% introuvable ou accès refusé', p_task_id;
  END IF;

  -- Récupérer les tags actuels
  SELECT tags INTO v_existing_tags
  FROM painel_internal_tasks
  WHERE id = p_task_id;

  -- Si l'email est déjà dans les tags, ne rien faire (idempotent)
  IF v_email_clean = ANY(v_existing_tags) THEN
    RETURN jsonb_build_object(
      'task_id', p_task_id,
      'invite_email', v_email_clean,
      'tags_updated_count', 0,
      'sync_status', 'already_present'
    );
  END IF;

  -- Ajouter l'email aux tags. Le trigger tg_sync_task_invites_from_task
  -- se déclenchera sur l'UPDATE et créera l'invite proprement.
  v_new_tags := v_existing_tags || ARRAY[v_email_clean];

  UPDATE painel_internal_tasks
  SET tags = v_new_tags
  WHERE id = p_task_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'fn_task_invite: UPDATE de task id=% refusé par RLS', p_task_id;
  END IF;

  RETURN jsonb_build_object(
    'task_id', p_task_id,
    'invite_email', v_email_clean,
    'tags_updated_count', 1,
    'sync_status', 'tag_added_trigger_will_sync'
  );
END;
$$;

COMMENT ON FUNCTION public.fn_task_invite IS
  'Invite intelligente : ajoute email aux tags de la task. Le trigger tg_sync_task_invites_from_task crée l''invite. Sécurité par RLS héritée (INVOKER). EA-15.';

REVOKE ALL ON FUNCTION public.fn_task_invite FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_task_invite TO authenticated;


-- =============================================================================
-- DO block de vérification post-migration
-- =============================================================================

DO $$
DECLARE
  v_count integer;
  v_default_tasks text;
  v_default_invites text;
BEGIN
  -- 1. Les 4 fonctions existent
  SELECT COUNT(*) INTO v_count
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'fn_task_create',
      'fn_task_update_status',
      'fn_task_delete',
      'fn_task_invite'
    );

  IF v_count <> 4 THEN
    RAISE EXCEPTION 'Vérif EA-15 : attendu 4 fonctions créées, trouvé %', v_count;
  END IF;

  -- 2. Toutes en SECURITY INVOKER
  SELECT COUNT(*) INTO v_count
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'fn_task_create',
      'fn_task_update_status',
      'fn_task_delete',
      'fn_task_invite'
    )
    AND p.prosecdef = false;

  IF v_count <> 4 THEN
    RAISE EXCEPTION 'Vérif EA-15 : toutes les RPC doivent être SECURITY INVOKER, violations: %', 4 - v_count;
  END IF;

  -- 3. Toutes avec search_path = public, pg_temp
  SELECT COUNT(*) INTO v_count
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'fn_task_create',
      'fn_task_update_status',
      'fn_task_delete',
      'fn_task_invite'
    )
    AND p.proconfig @> ARRAY['search_path=public, pg_temp'];

  IF v_count <> 4 THEN
    RAISE EXCEPTION 'Vérif EA-15 : toutes les RPC doivent avoir search_path=public, pg_temp, violations: %', 4 - v_count;
  END IF;

  -- 4. Defaults alignés
  SELECT column_default INTO v_default_tasks
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'painel_internal_tasks' AND column_name = 'status';

  IF v_default_tasks NOT LIKE '%pendente%' THEN
    RAISE EXCEPTION 'Vérif EA-15 : default status painel_internal_tasks attendu pendente, trouvé %', v_default_tasks;
  END IF;

  SELECT column_default INTO v_default_invites
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'painel_internal_task_invites' AND column_name = 'invite_status';

  IF v_default_invites NOT LIKE '%pendente%' THEN
    RAISE EXCEPTION 'Vérif EA-15 : default invite_status painel_internal_task_invites attendu pendente, trouvé %', v_default_invites;
  END IF;

  RAISE NOTICE '✓ EA-15 : 4 RPC créées (fn_task_create, fn_task_update_status, fn_task_delete, fn_task_invite)';
  RAISE NOTICE '✓ Toutes en SECURITY INVOKER avec search_path=public, pg_temp';
  RAISE NOTICE '✓ REVOKE PUBLIC + GRANT EXECUTE authenticated appliqués';
  RAISE NOTICE '✓ Defaults alignés sur ''pendente'' (status + invite_status)';
END
$$;
