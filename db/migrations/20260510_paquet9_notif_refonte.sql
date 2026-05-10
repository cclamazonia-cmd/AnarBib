-- =====================================================================
-- AnarBib — Paquet 9 : refonte notifications emprestimo (header-level)
-- Date : 2026-05-10
-- Spec : docs/spec-flux-emprunts.md (Phase 3 — fix multi-items)
--
-- Constat post-paquet-8 :
-- Le trigger trg_notify_emprestimo_lifecycle (sur emprestimo_itens_v2)
-- dispatche un event PAR ITEM. Pour un emprunt 3 items :
--   - 3 mails "criado" a la creation
--   - 1 mail "criado" + 1 mail "parcial" a chaque retour partiel
--   - 3 mails "devolvido" + 1 mail "parcial" sur retour groupe
-- Ce paquet consolide tout au niveau header :
--   - INSERT header (1 ligne) -> 1 mail criado
--   - UPDATE status_global -> mail selon transition
-- Resultat : 1 event metier = 1 mail.
--
-- Decisions metier :
--   - aberto -> encerrado : "Devolução registrada" (retour total direct)
--   - aberto -> partial   : "Devolução parcial registrada" (1er retour partiel)
--   - partial -> partial  : "Devolução parcial registrada" (item suivant
--                           rendu sans cloturer ; le trigger doit FORCER
--                           le dispatch malgre l'absence de transition statut)
--   - partial -> encerrado : event dedie "emprestimo_v2_devolvido_apos_parcial"
--                            avec mail de cloture chaleureuse
-- =====================================================================

BEGIN;

-- =====================================================================
-- 1. Desactiver l'ancien trigger sur les items
-- =====================================================================

DROP TRIGGER IF EXISTS trg_notify_emprestimo_lifecycle ON public.emprestimo_itens_v2;
-- La fonction trg_notify_emprestimo_lifecycle() reste, on ne la supprime pas
-- pour traçabilité. Elle est juste deconnectée.

COMMENT ON FUNCTION public.trg_notify_emprestimo_lifecycle() IS
'DEPRECATED 2026-05-10 (paquet 9) : remplacée par notif header-level via
fn_v2_refresh_emprestimo_status_global. Fonction conservee pour traçabilité
mais le trigger trg_notify_emprestimo_lifecycle a été dropé.';

-- =====================================================================
-- 2. Trigger AFTER INSERT sur le header pour la creation
--    Note : pg_net.http_post est asynchrone et n'envoie qu'au COMMIT,
--    donc les items inserees ensuite seront visibles au handler.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.trg_notify_emprestimo_criado()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  PERFORM public.fn_dispatch_circulation_notify_event(
    'emprestimo_v2_criado',
    NEW.id,
    '{}'::jsonb
  );
  RETURN NEW;
END;
$$;

ALTER FUNCTION public.trg_notify_emprestimo_criado() OWNER TO postgres;

DROP TRIGGER IF EXISTS trg_notify_emprestimo_criado ON public.emprestimos_v2;
CREATE TRIGGER trg_notify_emprestimo_criado
AFTER INSERT ON public.emprestimos_v2
FOR EACH ROW
EXECUTE FUNCTION public.trg_notify_emprestimo_criado();

COMMENT ON TRIGGER trg_notify_emprestimo_criado ON public.emprestimos_v2 IS
'Paquet 9 (10/05/2026) : remplace l item-level INSERT trigger par 1 dispatch
au niveau header. La requete HTTP par pg_net est asynchrone (envoi au COMMIT),
les items du meme transaction seront donc visibles au handler.';

-- =====================================================================
-- 3. Reecriture fn_v2_refresh_emprestimo_status_global
--    Centralise toute la logique notif des transitions de retour.
--    Lit l'ancien statut, calcule le nouveau, et dispatche selon la transition.
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
  v_old_status text;
  v_new_status text;
BEGIN
  -- Charger l'ancien statut AVANT le UPDATE
  SELECT status_global INTO v_old_status
    FROM public.emprestimos_v2
   WHERE id = p_emprestimo_id;

  -- Calculer le nouveau statut
  SELECT COUNT(*)::int,
         COUNT(*) FILTER (WHERE item_status = 'aberto')::int,
         COUNT(*) FILTER (WHERE item_status = 'devolvido')::int
    INTO v_total, v_open, v_returned
    FROM public.emprestimo_itens_v2
   WHERE emprestimo_id = p_emprestimo_id;

  IF v_total = 0 THEN
    v_new_status := 'aberto';
  ELSIF v_open = 0 THEN
    v_new_status := 'encerrado';
  ELSIF v_returned > 0 THEN
    v_new_status := 'parcialmente_devolvido';
  ELSE
    v_new_status := 'aberto';
  END IF;

  -- Appliquer le nouveau statut
  UPDATE public.emprestimos_v2
     SET status_global = v_new_status,
         updated_at = now()
   WHERE id = p_emprestimo_id;

  -- ============================================================
  -- Dispatch selon la transition (cf. table de decisions paquet 9)
  -- ============================================================

  -- aberto -> encerrado : retour total direct (ex. emprunt 1-item rendu,
  --                       ou tous les items rendus en bloc en 1 transaction)
  IF v_old_status = 'aberto' AND v_new_status = 'encerrado' THEN
    PERFORM public.fn_dispatch_circulation_notify_event(
      'emprestimo_v2_devolvido', p_emprestimo_id, '{}'::jsonb
    );

  -- aberto -> parcialmente_devolvido : 1er retour partiel
  ELSIF v_old_status = 'aberto' AND v_new_status = 'parcialmente_devolvido' THEN
    PERFORM public.fn_dispatch_circulation_notify_event(
      'emprestimo_v2_parcialmente_devolvido', p_emprestimo_id, '{}'::jsonb
    );

  -- partial -> partial : retour partiel suivant (le statut ne change pas
  --                      mais on a quand meme un item rendu de plus)
  ELSIF v_old_status = 'parcialmente_devolvido' AND v_new_status = 'parcialmente_devolvido' THEN
    PERFORM public.fn_dispatch_circulation_notify_event(
      'emprestimo_v2_parcialmente_devolvido', p_emprestimo_id, '{}'::jsonb
    );

  -- partial -> encerrado : retour du dernier item, cloture l'emprunt
  --                        Event dedie pour wording de cloture chaleureuse
  ELSIF v_old_status = 'parcialmente_devolvido' AND v_new_status = 'encerrado' THEN
    PERFORM public.fn_dispatch_circulation_notify_event(
      'emprestimo_v2_devolvido_apos_parcial', p_emprestimo_id, '{}'::jsonb
    );

  -- Tout autre cas (encerrado -> *, aberto -> aberto,
  -- partial -> aberto si on annule un retour, etc.) : pas de mail.
  END IF;

  RETURN v_new_status;
END;
$$;

ALTER FUNCTION public.fn_v2_refresh_emprestimo_status_global(bigint) OWNER TO postgres;

COMMENT ON FUNCTION public.fn_v2_refresh_emprestimo_status_global(bigint) IS
'Paquet 9 (10/05/2026) : centralise la logique de notification au niveau
header. Lit l ancien statut, calcule le nouveau, applique le UPDATE,
puis dispatche un event selon la table de transitions :
- aberto -> encerrado : emprestimo_v2_devolvido (retour total direct)
- aberto -> partial : emprestimo_v2_parcialmente_devolvido (1er partiel)
- partial -> partial : emprestimo_v2_parcialmente_devolvido (partiel suivant)
- partial -> encerrado : emprestimo_v2_devolvido_apos_parcial (cloture)
Remplace l ancien trigger item-level qui dispatchait 1 fois par item.';

REVOKE ALL ON FUNCTION public.fn_v2_refresh_emprestimo_status_global(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_v2_refresh_emprestimo_status_global(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_v2_refresh_emprestimo_status_global(bigint) TO service_role;

-- =====================================================================
-- 4. Supprimer l'ancien trigger trg_notify_emprestimo_status_change
--    (paquet 8) : sa logique est désormais dans fn_v2_refresh_*
-- =====================================================================

DROP TRIGGER IF EXISTS trg_notify_emprestimo_status_change ON public.emprestimos_v2;
-- Fonction conservee pour reference, mais deconnectée

COMMENT ON FUNCTION public.trg_notify_emprestimo_status_change() IS
'DEPRECATED 2026-05-10 (paquet 9) : sa logique a ete absorbee dans
fn_v2_refresh_emprestimo_status_global qui voit toutes les transitions
y compris partial->partial. Trigger drope, fonction conservee pour traçabilité.';

COMMIT;

-- =====================================================================
-- Tests manuels recommandes :
--
-- Scenario 1 (3 items, retour total direct) :
--   - Creer emprunt 3 items via /painel
--   - Devolver l'ensemble via le bouton retour groupe
--   - Verifier : 1 mail "criado" + 1 mail "devolvido"
--
-- Scenario 2 (3 items, retours successifs partiels) :
--   - Creer emprunt 3 items
--   - Devolver 1 item -> 1 mail "parcial"
--   - Devolver 1 item -> 1 mail "parcial" (le statut ne change pas)
--   - Devolver dernier item -> 1 mail "devolvido_apos_parcial" (cloture)
--   - Total : 1 mail criado + 3 mails de retour
--
-- Scenario 3 (1 item, cas simple) :
--   - Creer emprunt 1 item
--   - Devolver -> 1 mail "devolvido"
--   - Total : 1 mail criado + 1 mail devolvido
--
-- Verification SQL apres chaque test :
--   SELECT id, created, content::text->>'event' AS event, status_code
--   FROM net._http_response
--   WHERE created > now() - interval '5 minutes'
--   ORDER BY created DESC;
-- =====================================================================
