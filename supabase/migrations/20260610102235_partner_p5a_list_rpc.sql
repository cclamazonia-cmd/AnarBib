-- ════════════════════════════════════════════════════════════════════════════
-- §21 PARTNER — P5a : RPC de lecture pour la console coordenador
-- Auteur  : Xavier + Claude
-- Session : Catalogação work completion
-- Date    : 2026-06-10 (UTC)
-- Registre: §21 PARTNER (D7 cycle de vie ; D9 droits) — surface de lecture
--
-- OBJET : lister les partenariats STABILISÉS concernant une biblio, pour la
-- console coordenador (P5b). Distingue les directions actionnables :
--   - 'incoming'  : une autre biblio nous a proposé (status=proposed) → accept/refuse
--   - 'outgoing'  : on a proposé, en attente (status=proposed)
--   - 'active'    : partenariat actif (avec ses droits) → set_right / break
--   - 'refused' / 'broken' : historique
-- Les lignes 'declared' (annuaire déclaratif #PARTNERS) et les catalog_partners
-- sont EXCLUS (gérés par LibraryPartnershipsSection).
--
-- partnership_id renvoyé = l'id à passer aux RPC P2 :
--   incoming → la ligne du proposeur {autre→moi} (ce qu'attend fn_partnership_accept)
--   outgoing/active/historique → ma propre ligne {moi→autre}
--
-- SECURITY DEFINER, gardé coordenador (user_can_engage_library) — c'est une
-- console d'engagement politique de la biblio.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_partnership_list_mine(p_library_id uuid)
RETURNS TABLE (
  partnership_id     uuid,
  direction          text,
  status             text,
  partner_library_id uuid,
  partner_name       text,
  rights             text[]
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
  IF NOT public.user_can_engage_library(p_library_id) THEN
    RAISE EXCEPTION 'Acesso restrito à coordenação da biblioteca.'
      USING ERRCODE = '42501', HINT = 'error.partnership.forbidden';
  END IF;

  RETURN QUERY
  -- Propositions ENTRANTES : l'autre biblio est proposeur, nous sommes la cible.
  SELECT lp.id,
         'incoming'::text,
         lp.status,
         lp.library_id,                              -- le proposeur
         COALESCE(l.short_name, l.name),
         NULL::text[]
  FROM public.library_partnerships lp
  JOIN public.libraries l ON l.id = lp.library_id
  WHERE lp.partner_library_id = p_library_id
    AND lp.status = 'proposed'

  UNION ALL
  -- Mes lignes {moi→autre} : sortantes / actives / historique (jamais 'declared').
  SELECT lp.id,
         CASE lp.status WHEN 'proposed' THEN 'outgoing' ELSE lp.status END,
         lp.status,
         lp.partner_library_id,
         COALESCE(l.short_name, l.name),
         CASE WHEN lp.status = 'active'
              THEN (SELECT array_agg(pr.right_key ORDER BY pr.right_key)
                    FROM public.partnership_rights pr WHERE pr.partnership_id = lp.id)
              ELSE NULL END
  FROM public.library_partnerships lp
  JOIN public.libraries l ON l.id = lp.partner_library_id
  WHERE lp.library_id = p_library_id
    AND lp.partner_library_id IS NOT NULL
    AND lp.status IN ('proposed', 'active', 'refused', 'broken')
  ORDER BY 2, 5;
END $function$;

REVOKE EXECUTE ON FUNCTION public.fn_partnership_list_mine(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_partnership_list_mine(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
