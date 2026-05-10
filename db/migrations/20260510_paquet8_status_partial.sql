-- =====================================================================
-- AnarBib — Paquet 8 : statut intermediaire parcialmente_devolvido
-- Date : 2026-05-10
-- Spec : docs/spec-flux-emprunts.md Phase 3
--
-- Ce paquet :
-- 1. Etend le CHECK constraint sur emprestimos_v2.status_global
-- 2. Reecrit fn_v2_refresh_emprestimo_status_global avec le 3e etat
-- 3. Ajoute un trigger trg_notify_emprestimo_status_change qui detecte
--    aberto -> parcialmente_devolvido et dispatche
--    'emprestimo_v2_parcialmente_devolvido' vers la Edge Function
-- 4. Pas de toggle dedie : le retour partiel est gere par
--    loan_lifecycle_enabled (deja existant) cote politiques.
-- =====================================================================

BEGIN;

-- =====================================================================
-- 1. CHECK constraint etendu
-- =====================================================================

ALTER TABLE public.emprestimos_v2
  DROP CONSTRAINT IF EXISTS emprestimos_v2_status_global_chk;

ALTER TABLE public.emprestimos_v2
  ADD CONSTRAINT emprestimos_v2_status_global_chk
  CHECK (status_global = ANY (ARRAY[
    'aberto'::text,
    'parcialmente_devolvido'::text,
    'encerrado'::text
  ]));

-- =====================================================================
-- 2. Reecriture de fn_v2_refresh_emprestimo_status_global
--    Logique :
--    - Aucun item n'est encore rendu     -> 'aberto'
--    - Au moins un rendu, au moins un encore ouvert -> 'parcialmente_devolvido'
--    - Tous les items sont rendus        -> 'encerrado'
-- =====================================================================

CREATE OR REPLACE FUNCTION public.fn_v2_refresh_emprestimo_status_global(p_emprestimo_id bigint)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_total int := 0;
  v_open  int := 0;
  v_returned int := 0;
  v_new_status text;
BEGIN
  SELECT COUNT(*)::int,
         COUNT(*) FILTER (WHERE item_status = 'aberto')::int,
         COUNT(*) FILTER (WHERE item_status = 'devolvido')::int
    INTO v_total, v_open, v_returned
    FROM public.emprestimo_itens_v2
   WHERE emprestimo_id = p_emprestimo_id;

  -- Cas degenere : aucun item (impossible en pratique mais defensif)
  IF v_total = 0 THEN
    v_new_status := 'aberto';
  ELSIF v_open = 0 THEN
    v_new_status := 'encerrado';
  ELSIF v_returned > 0 THEN
    v_new_status := 'parcialmente_devolvido';
  ELSE
    v_new_status := 'aberto';
  END IF;

  UPDATE public.emprestimos_v2
     SET status_global = v_new_status,
         updated_at = now()
   WHERE id = p_emprestimo_id;

  RETURN v_new_status;
END;
$$;

ALTER FUNCTION public.fn_v2_refresh_emprestimo_status_global(bigint) OWNER TO postgres;

COMMENT ON FUNCTION public.fn_v2_refresh_emprestimo_status_global(bigint) IS
'Paquet 8 (10/05/2026) : etend le retour binaire aberto/encerrado avec
le statut intermediaire parcialmente_devolvido (>= 1 item rendu et
>= 1 item encore ouvert). Appelee par les fonctions de retour partiel
fn_v2_return_emprestimo_itens et fn_v2_return_emprestimo_linhas.';

REVOKE ALL ON FUNCTION public.fn_v2_refresh_emprestimo_status_global(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_v2_refresh_emprestimo_status_global(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_v2_refresh_emprestimo_status_global(bigint) TO service_role;

-- =====================================================================
-- 3. Trigger trg_notify_emprestimo_status_change
--    Declenche un dispatch vers Edge Function quand status_global passe
--    a parcialmente_devolvido (transition aberto -> partial uniquement).
--    Pas de notif sur partial -> encerrado : c'est fn_v2_return_emprestimo_total
--    qui dispatche deja 'emprestimo_v2_devolvido' via trg_notify_emprestimo_lifecycle.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.trg_notify_emprestimo_status_change()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- On notifie uniquement la transition aberto -> parcialmente_devolvido.
  -- Les autres transitions (partial -> encerrado, partial -> partial) sont
  -- couvertes par les autres triggers / pas pertinentes pour le mail.
  IF NEW.status_global = 'parcialmente_devolvido'
     AND COALESCE(OLD.status_global, '') = 'aberto' THEN
    PERFORM public.fn_dispatch_circulation_notify_event(
      'emprestimo_v2_parcialmente_devolvido',
      NEW.id,
      '{}'::jsonb
    );
  END IF;
  RETURN NEW;
END;
$$;

ALTER FUNCTION public.trg_notify_emprestimo_status_change() OWNER TO postgres;

DROP TRIGGER IF EXISTS trg_notify_emprestimo_status_change ON public.emprestimos_v2;
CREATE TRIGGER trg_notify_emprestimo_status_change
AFTER UPDATE OF status_global ON public.emprestimos_v2
FOR EACH ROW
WHEN (NEW.status_global IS DISTINCT FROM OLD.status_global)
EXECUTE FUNCTION public.trg_notify_emprestimo_status_change();

COMMENT ON TRIGGER trg_notify_emprestimo_status_change ON public.emprestimos_v2 IS
'Paquet 8 (10/05/2026) : detecte la transition aberto -> parcialmente_devolvido
et dispatche emprestimo_v2_parcialmente_devolvido vers la Edge Function
notify-event. Le toggle loan_lifecycle_enabled est verifie cote handler.';

COMMIT;

-- =====================================================================
-- Tests manuels recommandes (a executer apres deploiement) :
--
-- -- 1. Verifier le CHECK constraint
-- INSERT INTO emprestimos_v2 (status_global, ...) VALUES ('parcialmente_devolvido', ...);
-- -- Doit reussir
--
-- -- 2. Tester la fonction refresh sur un emprunt 3-items, retourner 1
-- SELECT public.fn_v2_refresh_emprestimo_status_global(<id>);
-- -- Doit retourner 'parcialmente_devolvido'
--
-- -- 3. Verifier que le trigger se declenche
-- --    (regarder les logs Edge Function via le dashboard Supabase apres
-- --    un retour partiel reel ; le mail doit arriver)
-- =====================================================================
