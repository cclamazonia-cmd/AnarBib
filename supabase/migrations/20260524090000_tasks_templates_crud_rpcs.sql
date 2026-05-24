-- ════════════════════════════════════════════════════════════════════════
-- Chantier #TASKS — étape 6 paquet 2 : RPC CRUD des tâches-types
-- Migration 20260524090000_tasks_templates_crud_rpcs
-- ────────────────────────────────────────────────────────────────────────
-- Contexte : painel_recurring_task_rules (tâches-types locales) a une RLS
-- complète (SELECT/INSERT/UPDATE/DELETE gardés par user_can_act_as_staff_on_
-- library) et un CHECK de cohérence de cadence, mais aucune RPC d'écriture.
-- La doctrine RPC v3 (21/05/2026) impose une RPC pour toute écriture DB avec
-- validation métier. Ce fichier ajoute create / update / delete.
--
-- Choix : ces fonctions s'exécutent avec les droits de l'appelant·e (mode
-- INVOKER), donc la RLS de painel_recurring_task_rules s'applique et assure
-- seule le contrôle d'accès. Elles ne sont donc pas concernées par la forme
-- REVOKE étendue post-#150, qui ne vise que les fonctions privées à droits
-- élevés. Elles restent exécutables par authenticated (GRANT explicite plus
-- bas) ; la RLS rejette toute tentative hors équipe.
--
-- Validation métier : on reproduit côté RPC, en RAISE EXCEPTION clairs, les
-- règles du CHECK de cohérence de cadence, pour ne pas exposer au frontend
-- un message Postgres technique. Le CHECK reste la défense en profondeur.
--
-- Pipeline : fichier appliqué par Woodpecker via supabase db push --linked.
-- Aucune exécution manuelle (ni SQL Editor, ni apply_migration MCP).
-- ════════════════════════════════════════════════════════════════════════

-- ─── 1. CREATE ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_recurring_task_rule_create(
  p_library_id          uuid,
  p_template_title      text,
  p_template_description text DEFAULT NULL,
  p_template_priority   text DEFAULT 'media',
  p_template_tags       text[] DEFAULT ARRAY[]::text[],
  p_label               text DEFAULT NULL,
  p_interval_count      integer DEFAULT NULL,
  p_interval_unit       text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_row painel_recurring_task_rules%ROWTYPE;
BEGIN
  IF p_library_id IS NULL THEN
    RAISE EXCEPTION 'fn_recurring_task_rule_create: p_library_id obligatoire';
  END IF;
  IF p_template_title IS NULL OR btrim(p_template_title) = '' THEN
    RAISE EXCEPTION 'fn_recurring_task_rule_create: le titre du modele est obligatoire';
  END IF;
  IF COALESCE(p_template_priority, 'media') NOT IN ('baixa', 'media', 'alta') THEN
    RAISE EXCEPTION 'fn_recurring_task_rule_create: priorite invalide (attendu baixa, media ou alta)';
  END IF;

  -- Cohérence de cadence : récurrent (les deux renseignés) ou ponctuel
  -- (les deux NULL), jamais à moitié — réplication du CHECK de la table.
  IF (p_interval_count IS NULL) <> (p_interval_unit IS NULL) THEN
    RAISE EXCEPTION 'fn_recurring_task_rule_create: cadence incoherente — renseigner intervalle ET unite, ou aucun des deux';
  END IF;
  IF p_interval_count IS NOT NULL AND p_interval_count <= 0 THEN
    RAISE EXCEPTION 'fn_recurring_task_rule_create: l''intervalle doit etre strictement positif';
  END IF;
  IF p_interval_unit IS NOT NULL AND p_interval_unit NOT IN ('dia', 'semana', 'mes') THEN
    RAISE EXCEPTION 'fn_recurring_task_rule_create: unite invalide (attendu dia, semana ou mes)';
  END IF;

  -- L'INSERT est soumis à la policy WITH CHECK user_can_act_as_staff_on_
  -- library : un appel hors équipe est rejeté ici par la RLS.
  INSERT INTO painel_recurring_task_rules (
    library_id, template_title, template_description, template_priority,
    template_tags, label, interval_count, interval_unit
  )
  VALUES (
    p_library_id,
    btrim(p_template_title),
    NULLIF(btrim(COALESCE(p_template_description, '')), ''),
    COALESCE(p_template_priority, 'media'),
    COALESCE(p_template_tags, ARRAY[]::text[]),
    NULLIF(btrim(COALESCE(p_label, '')), ''),
    p_interval_count,
    p_interval_unit
  )
  RETURNING * INTO v_row;

  RETURN to_jsonb(v_row);
END;
$function$;

-- ─── 2. UPDATE ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_recurring_task_rule_update(
  p_template_id         uuid,
  p_template_title      text,
  p_template_description text DEFAULT NULL,
  p_template_priority   text DEFAULT 'media',
  p_template_tags       text[] DEFAULT ARRAY[]::text[],
  p_label               text DEFAULT NULL,
  p_interval_count      integer DEFAULT NULL,
  p_interval_unit       text DEFAULT NULL,
  p_is_active           boolean DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_row painel_recurring_task_rules%ROWTYPE;
BEGIN
  IF p_template_id IS NULL THEN
    RAISE EXCEPTION 'fn_recurring_task_rule_update: p_template_id obligatoire';
  END IF;
  IF p_template_title IS NULL OR btrim(p_template_title) = '' THEN
    RAISE EXCEPTION 'fn_recurring_task_rule_update: le titre du modele est obligatoire';
  END IF;
  IF COALESCE(p_template_priority, 'media') NOT IN ('baixa', 'media', 'alta') THEN
    RAISE EXCEPTION 'fn_recurring_task_rule_update: priorite invalide (attendu baixa, media ou alta)';
  END IF;
  IF (p_interval_count IS NULL) <> (p_interval_unit IS NULL) THEN
    RAISE EXCEPTION 'fn_recurring_task_rule_update: cadence incoherente — renseigner intervalle ET unite, ou aucun des deux';
  END IF;
  IF p_interval_count IS NOT NULL AND p_interval_count <= 0 THEN
    RAISE EXCEPTION 'fn_recurring_task_rule_update: l''intervalle doit etre strictement positif';
  END IF;
  IF p_interval_unit IS NOT NULL AND p_interval_unit NOT IN ('dia', 'semana', 'mes') THEN
    RAISE EXCEPTION 'fn_recurring_task_rule_update: unite invalide (attendu dia, semana ou mes)';
  END IF;

  -- L'UPDATE est doublement filtré par la RLS (USING + WITH CHECK
  -- user_can_act_as_staff_on_library) : modifier le modele d'une autre
  -- biblioteca est impossible. NOT FOUND couvre id inexistant ET hors equipe.
  UPDATE painel_recurring_task_rules SET
    template_title       = btrim(p_template_title),
    template_description = NULLIF(btrim(COALESCE(p_template_description, '')), ''),
    template_priority    = COALESCE(p_template_priority, 'media'),
    template_tags        = COALESCE(p_template_tags, ARRAY[]::text[]),
    label                = NULLIF(btrim(COALESCE(p_label, '')), ''),
    interval_count       = p_interval_count,
    interval_unit        = p_interval_unit,
    is_active            = COALESCE(p_is_active, is_active),
    updated_at           = now(),
    updated_by           = auth.uid()
  WHERE id = p_template_id
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'fn_recurring_task_rule_update: modele % introuvable ou acces refuse', p_template_id;
  END IF;

  RETURN to_jsonb(v_row);
END;
$function$;

-- ─── 3. DELETE ──────────────────────────────────────────────────────────
-- Suppression dure. La FK painel_internal_tasks.recurrence_rule_id est
-- ON DELETE SET NULL (cf. migration 20260524040000) : supprimer un modele
-- ne detruit pas les taches deja instanciees, elles redeviennent ponctuelles.
CREATE OR REPLACE FUNCTION public.fn_recurring_task_rule_delete(
  p_template_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_row painel_recurring_task_rules%ROWTYPE;
BEGIN
  IF p_template_id IS NULL THEN
    RAISE EXCEPTION 'fn_recurring_task_rule_delete: p_template_id obligatoire';
  END IF;

  DELETE FROM painel_recurring_task_rules
  WHERE id = p_template_id
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'fn_recurring_task_rule_delete: modele % introuvable ou acces refuse', p_template_id;
  END IF;

  RETURN jsonb_build_object('deleted', true, 'id', v_row.id);
END;
$function$;

-- ─── 4. Permissions ─────────────────────────────────────────────────────
-- REVOKE puis GRANT, chaque instruction sur UNE SEULE LIGNE (le hook
-- pre-commit teste les regex ligne par ligne, le . ne franchit pas un saut
-- de ligne). Fonctions SECURITY INVOKER : pas de REVOKE service_role
-- necessaire, mais on retire PUBLIC/anon par hygiene (seule l'equipe
-- authentifiee gere des taches-types).
REVOKE EXECUTE ON FUNCTION public.fn_recurring_task_rule_create(uuid, text, text, text, text[], text, integer, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_recurring_task_rule_update(uuid, text, text, text, text[], text, integer, text, boolean) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_recurring_task_rule_delete(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_recurring_task_rule_create(uuid, text, text, text, text[], text, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_recurring_task_rule_update(uuid, text, text, text, text[], text, integer, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_recurring_task_rule_delete(uuid) TO authenticated;

-- ─── 5. Verification automatique en fin de transaction ──────────────────
-- Doctrine hotfix : DO-block de verification pour les migrations touchant
-- fonctions/permissions. RAISE EXCEPTION ici = rollback de toute la
-- migration. On verifie l'existence des 3 fonctions et le privilege EXECUTE
-- pour authenticated. (Pas de test en contexte anon simule : ces fonctions
-- ne creent pas de policy, le risque vise par la doctrine ne s'applique pas.)
DO $verify$
DECLARE
  v_missing text := '';
  v_fn text;
  v_sig text;
BEGIN
  FOR v_fn, v_sig IN
    SELECT * FROM (VALUES
      ('fn_recurring_task_rule_create', 'uuid, text, text, text, text[], text, integer, text'),
      ('fn_recurring_task_rule_update', 'uuid, text, text, text, text[], text, integer, text, boolean'),
      ('fn_recurring_task_rule_delete', 'uuid')
    ) AS t(fn, sig)
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.proname = v_fn
    ) THEN
      v_missing := v_missing || ' ' || v_fn || ' (absente)';
      CONTINUE;
    END IF;
    IF NOT has_function_privilege(
         'authenticated',
         ('public.' || v_fn || '(' || v_sig || ')')::regprocedure,
         'EXECUTE'
       ) THEN
      v_missing := v_missing || ' ' || v_fn || ' (EXECUTE manquant pour authenticated)';
    END IF;
  END LOOP;

  IF v_missing <> '' THEN
    RAISE EXCEPTION 'Verification migration tasks_templates_crud_rpcs ECHEC :%', v_missing;
  END IF;

  RAISE NOTICE 'Verification migration tasks_templates_crud_rpcs : OK (3 RPC presentes, EXECUTE authenticated confirme)';
END;
$verify$;
