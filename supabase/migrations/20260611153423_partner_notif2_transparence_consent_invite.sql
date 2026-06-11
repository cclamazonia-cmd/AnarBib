-- ════════════════════════════════════════════════════════════════════════════
-- §21 PARTNER — NOTIF-2 : invitation au consentement (transparence → lectrices)
-- Auteur  : Xavier + Claude
-- Session : Catalogação work completion
-- Date    : 2026-06-11 (UTC)
--
-- Quand le droit `transparence` est NOUVELLEMENT activé sur un partenariat actif
-- (p_enabled AND p_right_key='transparence' AND droit pas déjà présent), on émet
-- `partnership_transparence_enabled` → le handler notify-event notifie les
-- LECTRICES COMMUNES (membres actives des deux biblios) pour les inviter à
-- consentir au partage (/conta). Émis APRÈS le bump config_version (cohérent : le
-- consentement portera sur la nouvelle version).
-- Payload {partnership_id, library_a, library_b} (record_id factice ; fan-out
-- côté handler, partenariats = UUID). CREATE OR REPLACE : grants préservés.
-- NB : seul `transparence` déclenche (les autres droits — digital_share /
-- mutualisation / peb — sont biblio↔biblio et n'exposent pas de donnée lectrice).
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_partnership_set_right(p_partnership_id uuid, p_right_key text, p_enabled boolean)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_a uuid; v_b uuid; v_status text; v_existe boolean;
BEGIN
  SELECT library_id, partner_library_id, status INTO v_a, v_b, v_status
    FROM public.library_partnerships WHERE id = p_partnership_id;
  IF v_a IS NULL OR v_b IS NULL THEN
    RAISE EXCEPTION 'Parceria inexistente.' USING HINT = 'error.partnership.not_found';
  END IF;
  IF v_status <> 'active' THEN
    RAISE EXCEPTION 'Os direitos só podem ser ajustados numa parceria ativa.'
      USING HINT = 'error.partnership.not_active';
  END IF;
  IF p_right_key NOT IN ('transparence','digital_share','mutualisation','peb') THEN
    RAISE EXCEPTION 'Direito desconhecido.' USING HINT = 'error.partnership.unknown_right';
  END IF;
  IF NOT (public.user_can_engage_library(v_a) OR public.user_can_engage_library(v_b)) THEN
    RAISE EXCEPTION 'Acesso restrito à coordenação de uma das bibliotecas.'
      USING ERRCODE = '42501', HINT = 'error.partnership.forbidden';
  END IF;

  IF p_enabled THEN
    v_existe := EXISTS (SELECT 1 FROM public.partnership_rights
                        WHERE partnership_id = p_partnership_id AND right_key = p_right_key);
    -- Insert sur la direction courante ; le trigger réplique sur la réciproque.
    INSERT INTO public.partnership_rights (partnership_id, right_key, granted_by)
      VALUES (p_partnership_id, p_right_key, auth.uid())
    ON CONFLICT (partnership_id, right_key) DO NOTHING;
    -- AJOUT d'un droit = la config s'élargit → bump config_version des deux côtés
    -- (invalide le consentement lectrice, re-sollicitation « vers le haut », D8).
    IF NOT v_existe THEN
      UPDATE public.library_partnerships
         SET config_version = config_version + 1
       WHERE (library_id = v_a AND partner_library_id = v_b)
          OR (library_id = v_b AND partner_library_id = v_a);
      -- NOTIF-2 : transparence NOUVELLEMENT activée → inviter les lectrices
      -- communes (membres des deux biblios) à consentir (/conta).
      IF p_right_key = 'transparence' THEN
        PERFORM public.fn_dispatch_notify_event('partnership_transparence_enabled', 1, jsonb_build_object(
          'partnership_id', p_partnership_id::text,
          'library_a', v_a::text,
          'library_b', v_b::text));
      END IF;
    END IF;
  ELSE
    -- RETRAIT : la config se restreint → consentement maintenu, pas de bump (D8).
    DELETE FROM public.partnership_rights
     WHERE partnership_id = p_partnership_id AND right_key = p_right_key;
  END IF;
END $function$;

NOTIFY pgrst, 'reload schema';
