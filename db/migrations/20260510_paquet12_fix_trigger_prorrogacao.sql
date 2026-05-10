-- =====================================================================
-- AnarBib — Paquet 12 : fix trigger notification prorogation
-- Date : 2026-05-10
-- Spec : docs/spec-flux-emprunts.md (post-Phase 5)
--
-- Bug : depuis le paquet 7, fn_renew_my_loan et fn_v2_extend_emprestimo_once
-- font UPDATE ... SET renewals_used = renewals_used + 1, sans toucher
-- explicitement a extended_once (mis a jour par trg_emprestimo_sync_extended_once
-- en BEFORE UPDATE).
--
-- Or trg_notify_emprestimo_prorrogacao etait declare AFTER UPDATE OF
-- "extended_once". Ce trigger ne se declenche que si la colonne
-- extended_once est mentionnee dans la clause SET, ce qui n'est plus
-- le cas. Resultat : aucun mail de prorogation envoye.
--
-- Fix Option A : reattacher le trigger sur renewals_used (source de
-- verite depuis le paquet 7) et adapter la condition.
-- =====================================================================

BEGIN;

-- =====================================================================
-- 1. Reecriture de la fonction de trigger
--    Compare OLD.renewals_used < NEW.renewals_used pour detecter
--    une nouvelle prorogation (incrementation du compteur).
-- =====================================================================

CREATE OR REPLACE FUNCTION public.trg_notify_emprestimo_prorrogacao()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- Paquet 12 (10/05/2026) : la condition compare renewals_used (source
  -- de verite depuis paquet 7) au lieu de extended_once (deprecate).
  -- On dispatche a chaque incrementation, pas seulement au passage 0->1.
  IF TG_OP = 'UPDATE'
     AND COALESCE(NEW.renewals_used, 0) > COALESCE(OLD.renewals_used, 0) THEN
    PERFORM public.fn_dispatch_circulation_notify_event(
      'emprestimo_v2_prorrogado',
      NEW.id,
      '{}'::jsonb
    );
  END IF;
  RETURN NEW;
END;
$$;

ALTER FUNCTION public.trg_notify_emprestimo_prorrogacao() OWNER TO postgres;

COMMENT ON FUNCTION public.trg_notify_emprestimo_prorrogacao() IS
'Paquet 12 (10/05/2026) : detecte une nouvelle prorogation via
incrementation de renewals_used (source de verite depuis le paquet 7).
Remplace l ancienne condition basee sur extended_once qui ne se
declenchait plus depuis que les RPCs ont migre vers renewals_used.';

-- =====================================================================
-- 2. Reattacher le trigger sur la bonne colonne
-- =====================================================================

DROP TRIGGER IF EXISTS trg_notify_emprestimo_prorrogacao ON public.emprestimos_v2;
CREATE TRIGGER trg_notify_emprestimo_prorrogacao
AFTER UPDATE OF renewals_used ON public.emprestimos_v2
FOR EACH ROW
EXECUTE FUNCTION public.trg_notify_emprestimo_prorrogacao();

COMMENT ON TRIGGER trg_notify_emprestimo_prorrogacao ON public.emprestimos_v2 IS
'Paquet 12 (10/05/2026) : reattache sur renewals_used (anciennement
extended_once). Le passage a renewals_used comme source de verite
au paquet 7 avait casse silencieusement les notifications de
prorogation.';

COMMIT;

-- =====================================================================
-- Test apres deploiement :
--
-- 1. Faire une prorogation cote lecteur (bouton Renovar dans /conta)
--    OU cote biblio (bouton Prorrogar dans /painel)
--
-- 2. Verifier qu'une requete HTTP a ete dispatchee :
--    SELECT id, created, status_code, (content::jsonb)->>'event' AS event
--    FROM net._http_response
--    WHERE created > now() - interval '5 minutes'
--    ORDER BY created DESC LIMIT 3;
--    On doit voir 'emprestimo_v2_prorrogado' avec status_code = 200
--
-- 3. Verifier reception du mail "Renovacao confirmada" cote lecteur
--    et de la copie carbone cote biblio
-- =====================================================================
