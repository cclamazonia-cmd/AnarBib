-- ============================================================================
-- 20260524060000_tasks_recurrence_stale_cron.sql
-- ----------------------------------------------------------------------------
-- Chantier #TASKS — etape 3-bis : cron de securite des chaines de recurrence.
-- Dossier d'ouverture : module des taches, v0.1 (23/05/2026).
-- Pre-requis : migrations 20260524040000 (schema) et 20260524050000
--              (regeneration a l'achevement).
--
-- BESOIN
--   La regeneration (etape 3) ne cree la prochaine occurrence qu'a
--   l'achevement de la precedente. Si une occurrence recurrente n'est
--   jamais achevee, la chaine s'interrompt en silence. Ce cron est le
--   filet de securite : il REPERE et SIGNALE ces chaines interrompues.
--
-- CONCEPTION (arbitrages 24/05)
--   - Variante LEGERE : le cron ne mail pas. Il pose un drapeau
--     recurrence_stale_flagged_at sur l'occurrence en souffrance. Le Painel
--     met ces taches en evidence (etape 6, vues). Aucune dependance a la
--     chaine de notification (enqueue_task_level_... n'accepte que
--     task_created/task_updated). Coherent avec l'etape 6 du dossier
--     (« mise en evidence des taches recurrentes dues »).
--   - Seuil : delai FIXE. Une occurrence recurrente est « en souffrance »
--     si elle est pendente|em_andamento et que sa due_date est depassee
--     de plus de 7 jours.
--   - Idempotence : le cron ne re-signale pas une tache deja signalee
--     (drapeau deja pose). Si une tache signalee est ensuite achevee ou
--     voit sa due_date repoussee, le drapeau est efface (retour a la
--     normale) — egalement gere par le cron.
-- ============================================================================


-- ─── Colonne-drapeau sur painel_internal_tasks ──────────────────────────────
ALTER TABLE public.painel_internal_tasks
  ADD COLUMN IF NOT EXISTS recurrence_stale_flagged_at timestamptz;

COMMENT ON COLUMN public.painel_internal_tasks.recurrence_stale_flagged_at IS
  'Marqueur du cron de securite #TASKS 3-bis : pose quand une occurrence '
  'recurrente est en souffrance (chaine interrompue — pendente/em_andamento '
  'et due_date depassee de plus de 7 jours). NULL = pas en souffrance. '
  'Le Painel met ces taches en evidence.';


-- ============================================================================
-- fn_cron_tasks_detect_stale_recurrence — cron de securite
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_cron_tasks_detect_stale_recurrence()
 RETURNS TABLE(flagged_count integer, cleared_count integer, run_at timestamptz)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_flagged integer := 0;
  v_cleared integer := 0;
begin
  -- ─── POSE du drapeau ────────────────────────────────────────────────────
  -- Occurrence recurrente, non achevee, due_date depassee de plus de 7 jours,
  -- pas encore signalee.
  update public.painel_internal_tasks
  set recurrence_stale_flagged_at = timezone('utc', now())
  where recurrence_rule_id is not null
    and status in ('pendente', 'em_andamento')
    and due_date is not null
    and due_date < current_date - 7
    and recurrence_stale_flagged_at is null;
  get diagnostics v_flagged = row_count;

  -- ─── RETRAIT du drapeau ─────────────────────────────────────────────────
  -- Une tache signalee qui n'est plus en souffrance : achevee/annulee, ou
  -- due_date repoussee, ou plus rattachee a une serie. Retour a la normale.
  update public.painel_internal_tasks
  set recurrence_stale_flagged_at = null
  where recurrence_stale_flagged_at is not null
    and (
      recurrence_rule_id is null
      or status not in ('pendente', 'em_andamento')
      or due_date is null
      or due_date >= current_date - 7
    );
  get diagnostics v_cleared = row_count;

  flagged_count := v_flagged;
  cleared_count := v_cleared;
  run_at := timezone('utc', now());
  return next;
end;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_cron_tasks_detect_stale_recurrence() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_cron_tasks_detect_stale_recurrence() TO service_role;


-- ─── Job pg_cron — quotidien, 3h50 (apres les autres jobs nocturnes) ────────
SELECT cron.schedule(
  'anarbib-tasks-detect-stale-recurrence-daily',
  '50 3 * * *',
  $cron$ SELECT public.fn_cron_tasks_detect_stale_recurrence(); $cron$
);


-- ─── Verification post-migration ────────────────────────────────────────────
DO $verif$
declare
  v_count integer;
begin
  -- (a) La colonne-drapeau existe.
  if not exists (
    select 1 from pg_attribute
    where attrelid = 'public.painel_internal_tasks'::regclass
      and attname = 'recurrence_stale_flagged_at' and not attisdropped
  ) then
    raise exception 'Verification echouee : colonne recurrence_stale_flagged_at absente.';
  end if;

  -- (b) La fonction cron existe.
  select count(*) into v_count
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname='public' and p.proname='fn_cron_tasks_detect_stale_recurrence';
  if v_count <> 1 then
    raise exception 'Verification echouee : fn_cron_tasks_detect_stale_recurrence absente.';
  end if;

  -- (c) Le job pg_cron est planifie.
  select count(*) into v_count from cron.job
  where jobname = 'anarbib-tasks-detect-stale-recurrence-daily';
  if v_count <> 1 then
    raise exception 'Verification echouee : job cron anarbib-tasks-detect-stale-recurrence-daily absent.';
  end if;

  raise notice 'Migration 20260524060000 : verification OK (colonne drapeau, fn_cron_tasks_detect_stale_recurrence, job quotidien planifie).';
end;
$verif$;
