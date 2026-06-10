-- ════════════════════════════════════════════════════════════════════════════
-- §21 PARTNER — P4a : transparence enrichie conditionnée (backend)
-- Auteur  : Xavier + Claude
-- Session : Catalogação work completion
-- Date    : 2026-06-10 (UTC)
-- Registre: §21 PARTNER (D5 visibilité conditionnée ; D8 effet immédiat) ;
--           MULTI-E.3 / Zone 21 (spec-multi-appartenance-lecteur §6)
--
-- OBJET : crée la surface de transparence « Zone 21 » (inexistante à ce jour).
-- Un·e staff de A voit les AUTRES appartenances actives d'une lectrice :
--   - par défaut : TRANSPARENCE MINIMALE (nombre, sans identité) ;
--   - ENRICHIE (nom de B + statut + restriction) UNIQUEMENT si, pour le couple
--     (A,B) et cette lectrice : partenariat ACTIF ∧ droit `transparence` ∧
--     consentement valide (config courante).
--
-- Approche RPC SECURITY DEFINER (sanctionnée par la spec §ligne 84 : « les RPC
-- painel de transparence lisent via ces conditions ») plutôt qu'une RLS ajoutée
-- sur user_library_memberships (table cœur d'autorisation). D5 : visibilité
-- conditionnée, jamais copie. D8 : la garde étant évaluée à la lecture, un retrait
-- de consentement ferme l'accès immédiatement. γ.1 : expose sans imposer.
--
-- HORS P4a : le frontend (carte TabLeitor) + i18n = P4b.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. Garde combinée : transparence active de A vers B pour une lectrice ────
CREATE OR REPLACE FUNCTION public.fn_partnership_transparence_active(
  p_library_a uuid, p_library_b uuid, p_user_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.library_partnerships lp
    WHERE lp.library_id = p_library_a
      AND lp.partner_library_id = p_library_b
      AND lp.status = 'active'
      AND EXISTS (SELECT 1 FROM public.partnership_rights pr
                  WHERE pr.partnership_id = lp.id AND pr.right_key = 'transparence')
      AND public.fn_reader_consent_valid(p_user_id, lp.id)
  );
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_partnership_transparence_active(uuid, uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_partnership_transparence_active(uuid, uuid, uuid) TO authenticated;

-- ── 2. RPC painel « Zone 21 » : autres appartenances d'une lectrice ─────────
-- Retourne une ligne par autre appartenance active. Pour les couples SANS
-- transparence enrichie : enriched=false + identité NULL (compte « minimal »
-- côté UI). Pour les couples avec garde vraie : enriched=true + détails.
CREATE OR REPLACE FUNCTION public.fn_painel_reader_other_memberships(
  p_user_id           uuid,
  p_viewer_library_id uuid
)
RETURNS TABLE (
  enriched          boolean,
  library_id        uuid,
  library_name      text,
  membership_status text,
  is_restricted     boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
  -- Garde : le caller est staff de la biblio observatrice.
  IF NOT public.user_can_act_as_staff_on_library(p_viewer_library_id) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff da biblioteca.'
      USING ERRCODE = '42501', HINT = 'error.partnership.forbidden';
  END IF;

  -- La lectrice doit être membre active de la biblio observatrice (sinon rien).
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = p_user_id AND m.library_id = p_viewer_library_id
                   AND m.status = 'active') THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH others AS (
    SELECT m.library_id AS lib,
           m.status     AS st,
           COALESCE(m.is_restricted, false) AS restr,
           COALESCE(l.short_name, l.name)   AS lname,
           public.fn_partnership_transparence_active(p_viewer_library_id, m.library_id, p_user_id) AS ok
    FROM public.user_library_memberships m
    JOIN public.libraries l ON l.id = m.library_id
    WHERE m.user_id = p_user_id
      AND m.status = 'active'
      AND m.library_id <> p_viewer_library_id
  )
  SELECT o.ok,
         CASE WHEN o.ok THEN o.lib   END,
         CASE WHEN o.ok THEN o.lname END,
         CASE WHEN o.ok THEN o.st    END,
         CASE WHEN o.ok THEN o.restr END
  FROM others o;
END $function$;

REVOKE EXECUTE ON FUNCTION public.fn_painel_reader_other_memberships(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_painel_reader_other_memberships(uuid, uuid) TO authenticated;

-- ── 3. Vérification ─────────────────────────────────────────────────────────
DO $verify$
DECLARE v int;
BEGIN
  SELECT count(*) INTO v FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname IN
     ('fn_partnership_transparence_active','fn_painel_reader_other_memberships');
  IF v <> 2 THEN RAISE EXCEPTION 'VERIFY FAILED: % / 2 fonctions P4a', v; END IF;

  IF has_function_privilege('anon','public.fn_painel_reader_other_memberships(uuid,uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'VERIFY FAILED: anon peut exécuter le RPC de transparence';
  END IF;

  RAISE NOTICE 'VERIFY OK: PARTNER P4a — garde transparence + RPC Zone 21.';
END;
$verify$;

NOTIFY pgrst, 'reload schema';

COMMIT;
