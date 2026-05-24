-- ============================================================================
-- 20260524030000_peb_overdue.sql
-- ----------------------------------------------------------------------------
-- Chantier #ILL-overdue — detection automatique du retard d'un PEB.
--
-- BESOIN
--   Le statut 'atrasado' existe (transition licite depuis #ILL-lifecycle)
--   mais rien ne le pose : il faudrait un acte manuel, donc en pratique il
--   ne serait jamais pose. Ce chantier ajoute le cron qui bascule
--   automatiquement les PEB echus, ET le retour quand un PEB est prolonge.
--
-- DEUX VOLETS
--   1. Completer la machine a etats (#ILL-lifecycle) : deux transitions
--      nouvelles, pour couvrir tous les scenarios (arbitrage 24/05) :
--        - atrasado -> emprestado            (retour apres prolongation)
--        - parcialmente_devolvido -> atrasado (un PEB partiel peut etre en retard)
--      La table passe de 16 a 18 transitions.
--   2. fn_cron_peb_detect_overdue() : cron quotidien, gere ALLER et RETOUR.
--        ALLER  : emprestado|parcialmente_devolvido -> atrasado
--                 quand due_date < current_date.
--        RETOUR : atrasado -> emprestado|parcialmente_devolvido
--                 quand due_date repassee dans le futur (prolongation).
--                 Le statut de retour est DEDUIT des exemplaires (option A) :
--                 au moins un exemplaire regle -> parcialmente_devolvido,
--                 sinon -> emprestado. Meme logique de comptage que
--                 fn_peb_consolidate_loan_status.
--
-- NB due_date NULL : un PEB sans echeance n'est jamais en retard — ignore
--   par le cron (la bibliotheque preteuse n'attend pas de retour fixe).
--
-- Patron : fn_detect_no_show_reservations (cron de bascule sur echeance).
-- ============================================================================


-- ─── Volet 1 — completer la table des transitions licites ───────────────────
INSERT INTO public.interlibrary_loan_status_transitions (from_status, to_status)
VALUES
  ('atrasado',               'emprestado'),   -- retour apres prolongation
  ('parcialmente_devolvido', 'atrasado')      -- un PEB partiel peut etre en retard
ON CONFLICT (from_status, to_status) DO NOTHING;


-- ============================================================================
-- Volet 2 — fn_cron_peb_detect_overdue : cron de detection du retard
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_cron_peb_detect_overdue()
 RETURNS TABLE(processed_count integer, error_count integer, details jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_row record;
  v_processed integer := 0;
  v_errors integer := 0;
  v_errors_details jsonb := '[]'::jsonb;
  v_total int;
  v_settled int;
  v_target text;
begin
  -- ─── ALLER : PEB echus a basculer vers 'atrasado' ───────────────────────
  -- Eligibles : emprestado ou parcialmente_devolvido, due_date depassee.
  for v_row in
    select id, status_global, due_date
    from public.interlibrary_loans_v2
    where status_global in ('emprestado', 'parcialmente_devolvido')
      and due_date is not null
      and due_date < current_date
      and archived_at is null
  loop
    begin
      update public.interlibrary_loans_v2
      set status_global = 'atrasado',
          updated_at = timezone('utc', now())
      where id = v_row.id;
      v_processed := v_processed + 1;
    exception when others then
      v_errors := v_errors + 1;
      v_errors_details := v_errors_details || jsonb_build_object(
        'loan_id', v_row.id, 'direction', 'aller',
        'from', v_row.status_global, 'sqlstate', sqlstate, 'message', sqlerrm
      );
    end;
  end loop;

  -- ─── RETOUR : PEB 'atrasado' prolonges, a sortir du retard ──────────────
  -- Un PEB atrasado dont la due_date est repassee dans le futur (ou a NULL)
  -- a ete prolonge : on le sort du retard. Statut cible DEDUIT des
  -- exemplaires (option A) — meme comptage que fn_peb_consolidate_loan_status.
  for v_row in
    select id, due_date
    from public.interlibrary_loans_v2
    where status_global = 'atrasado'
      and (due_date is null or due_date >= current_date)
      and archived_at is null
  loop
    begin
      -- Comptage des exemplaires : combien au total, combien regles.
      --   regle = devolvido | perdido | danificado | cancelado
      select count(*),
             count(*) filter (where item_status in
               ('devolvido','perdido','danificado','cancelado'))
      into v_total, v_settled
      from public.interlibrary_loan_items_v2
      where interlibrary_loan_id = v_row.id;

      -- Statut de retour : si une partie est deja reglee -> partiel ;
      -- sinon -> emprestado. (Si tout etait regle le PEB ne serait pas
      -- 'atrasado' mais 'devolvido' : ce cas n'arrive pas ici.)
      if v_total > 0 and v_settled > 0 then
        v_target := 'parcialmente_devolvido';
      else
        v_target := 'emprestado';
      end if;

      update public.interlibrary_loans_v2
      set status_global = v_target,
          updated_at = timezone('utc', now())
      where id = v_row.id;
      v_processed := v_processed + 1;
    exception when others then
      v_errors := v_errors + 1;
      v_errors_details := v_errors_details || jsonb_build_object(
        'loan_id', v_row.id, 'direction', 'retour',
        'sqlstate', sqlstate, 'message', sqlerrm
      );
    end;
  end loop;

  processed_count := v_processed;
  error_count := v_errors;
  details := jsonb_build_object('run_at', timezone('utc', now()), 'errors', v_errors_details);
  return next;
end;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_cron_peb_detect_overdue() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_cron_peb_detect_overdue() TO service_role;


-- ─── Job pg_cron — quotidien, 3h40 (apres les autres jobs nocturnes) ────────
SELECT cron.schedule(
  'anarbib-peb-detect-overdue-daily',
  '40 3 * * *',
  $cron$ SELECT public.fn_cron_peb_detect_overdue(); $cron$
);


-- ============================================================================
-- VERIFICATION POST-MIGRATION
-- ============================================================================
DO $verif$
declare
  v_count integer;
begin
  -- (a) La table de transitions compte desormais 18 lignes.
  select count(*) into v_count from public.interlibrary_loan_status_transitions;
  if v_count <> 18 then
    raise exception 'Verification echouee : % transitions en table, 18 attendues.', v_count;
  end if;

  -- (b) Les deux nouvelles transitions sont presentes.
  if not exists (select 1 from public.interlibrary_loan_status_transitions
                 where from_status='atrasado' and to_status='emprestado') then
    raise exception 'Verification echouee : transition atrasado->emprestado absente.';
  end if;
  if not exists (select 1 from public.interlibrary_loan_status_transitions
                 where from_status='parcialmente_devolvido' and to_status='atrasado') then
    raise exception 'Verification echouee : transition parcialmente_devolvido->atrasado absente.';
  end if;

  -- (c) La fonction cron existe.
  select count(*) into v_count
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname='public' and p.proname='fn_cron_peb_detect_overdue';
  if v_count <> 1 then
    raise exception 'Verification echouee : fn_cron_peb_detect_overdue absente.';
  end if;

  -- (d) Le job pg_cron est planifie.
  select count(*) into v_count from cron.job
  where jobname = 'anarbib-peb-detect-overdue-daily';
  if v_count <> 1 then
    raise exception 'Verification echouee : job cron anarbib-peb-detect-overdue-daily absent.';
  end if;

  raise notice 'Migration 20260524030000 : verification OK (18 transitions, fn_cron_peb_detect_overdue, job quotidien planifie).';
end;
$verif$;
