-- ════════════════════════════════════════════════════════════════════════════
-- §21 PARTNER — NOTIF-3 : re-sollicitation « vers le haut » (config élargie)
-- Auteur  : Xavier + Claude
-- Session : Catalogação work completion
-- Date    : 2026-06-11 (UTC)
--
-- Quand un droit NON-transparence (digital_share/mutualisation/peb) est ajouté à
-- une parceria active → bump config_version → les consentements lectrices à
-- l'ancienne version deviennent « stale ». On émet `partnership_config_expanded`
-- (id CANONIQUE — c'est la clé de reader_partnership_consent) → le handler
-- re-sollicite UNIQUEMENT les lectrices au consentement stale (revoked_at NULL,
-- config_version < courante). Le ré-ajout de `transparence`, lui, reste couvert
-- par NOTIF-2 (qui ré-invite toutes les lectrices communes — stale incluses).
-- Migration superseding 20260611153423 (set_right porte désormais les 2 émissions).
-- CREATE OR REPLACE : grants préservés.
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
      IF p_right_key = 'transparence' THEN
        -- NOTIF-2 : transparence nouvellement activée → inviter les lectrices
        -- communes (membres des deux biblios) à consentir (/conta).
        PERFORM public.fn_dispatch_notify_event('partnership_transparence_enabled', 1, jsonb_build_object(
          'partnership_id', p_partnership_id::text,
          'library_a', v_a::text,
          'library_b', v_b::text));
      ELSE
        -- NOTIF-3 : autre droit ajouté → la config s'élargit → re-solliciter les
        -- lectrices au consentement devenu stale (handler : id canonique requis).
        PERFORM public.fn_dispatch_notify_event('partnership_config_expanded', 1, jsonb_build_object(
          'partnership_id', public.fn_partnership_canonical_id(p_partnership_id)::text,
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
