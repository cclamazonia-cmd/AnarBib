-- ════════════════════════════════════════════════════════════════════════════
-- §21 PARTNER — P6a : RPC de lecture du consentement côté lectrice (/conta)
-- Auteur  : Xavier + Claude
-- Session : Catalogação work completion
-- Date    : 2026-06-10 (UTC)
-- Registre: §21 PARTNER (D1 opt-in ; D8 versionnage du consentement)
--
-- OBJET : lister, pour la lectrice connectée, les partenariats ACTIFS qui la
-- concernent — c.-à-d. ceux où elle est membre active des DEUX biblios et où le
-- droit `transparence` est activé — avec l'état de son consentement :
--   'none'  : pas de consentement (ou révoqué) → transparence minimale
--   'valid' : consenti à la configuration courante
--   'stale' : consenti à une config antérieure (un droit a été ajouté depuis) →
--             re-sollicitation « vers le haut » (D8)
--
-- Renvoie la ligne CANONIQUE du couple (library_id < partner_library_id), id que
-- les RPC P3 fn_partnership_consent / _revoke_consent résolvent de toute façon.
-- SECURITY DEFINER, self-service (auth.uid()).
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_reader_my_partnerships()
RETURNS TABLE (
  partnership_id  uuid,
  library_a_name  text,
  library_b_name  text,
  consent_state   text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH canon AS (
    SELECT lp.id, lp.library_id AS la, lp.partner_library_id AS lb, lp.config_version AS cv
    FROM public.library_partnerships lp
    WHERE lp.status = 'active'
      AND lp.partner_library_id IS NOT NULL
      AND lp.library_id < lp.partner_library_id     -- ligne canonique unique de la paire
      AND EXISTS (SELECT 1 FROM public.partnership_rights pr
                  WHERE pr.partnership_id = lp.id AND pr.right_key = 'transparence')
      AND EXISTS (SELECT 1 FROM public.user_library_memberships m
                  WHERE m.user_id = v_uid AND m.library_id = lp.library_id AND m.status = 'active')
      AND EXISTS (SELECT 1 FROM public.user_library_memberships m
                  WHERE m.user_id = v_uid AND m.library_id = lp.partner_library_id AND m.status = 'active')
  )
  SELECT c.id,
         COALESCE(la.short_name, la.name),
         COALESCE(lb.short_name, lb.name),
         CASE
           WHEN cons.partnership_id IS NULL OR cons.revoked_at IS NOT NULL THEN 'none'
           WHEN cons.config_version = c.cv THEN 'valid'
           ELSE 'stale'
         END
  FROM canon c
  JOIN public.libraries la ON la.id = c.la
  JOIN public.libraries lb ON lb.id = c.lb
  LEFT JOIN public.reader_partnership_consent cons
    ON cons.partnership_id = c.id AND cons.user_id = v_uid
  ORDER BY 2, 3;
END $function$;

REVOKE EXECUTE ON FUNCTION public.fn_reader_my_partnerships() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_reader_my_partnerships() TO authenticated;

NOTIFY pgrst, 'reload schema';
