-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — les compteurs d'abus comptent d'un seul geste (19/10/2026)
-- Auteur  : Xavier (CCLA) + Claude
-- Session : Modele de menace
--
-- 1. public.fn_compteur_frapper : une frappe sur public.auth_rate_limits, comptée
--    et jugée dans la même instruction (INSERT … ON CONFLICT … DO UPDATE …
--    RETURNING). La ligne est verrouillée le temps de l'instruction : deux
--    frappes simultanées sur la même clé se suivent, aucune ne lit un compte
--    déjà dépassé. Règles reprises de _shared/core/rate-limit.ts :
--      - bloc en cours → refus, rien ne change ;
--      - bloc expiré, ou première frappe plus vieille qu'une fenêtre → le
--        compte repart de 1 ;
--      - sinon +1, et la frappe qui dépasse `p_limite` bloque `p_blocage_min`
--        minutes (par défaut une fenêtre).
--    Rend true quand la frappe est refusée.
-- 2. public.fn_compteur_rendre : retire une frappe d'un compteur non bloqué
--    (`login` rend celle d'une connexion réussie à la clé d'IP).
-- Les deux en SECURITY INVOKER : seul service_role a des droits sur la table
-- (aucun GRANT à anon ni à authenticated, RLS active sans politique), et seul
-- service_role peut les exécuter.
--
-- 3. Altcha : l'usage « gazette » admis par fn_consume_altcha_challenge et par
--    la contrainte de la table (submit-gazette-contribution exige désormais
--    une preuve de travail, comme les autres formulaires publics). Corps repris
--    de la définition RÉELLE en production le 19/10 (md5 du prosrc :
--    9630202294e28f2241f38cc88bd734a8) ; un seul changement, la liste des usages.
--
-- Tests : tests/sql/compteurs_d_abus_tests.sql (T5 à T12).
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- ─── 1. Une frappe ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_compteur_frapper(
  p_kind text, p_key text, p_limite integer, p_fenetre_min integer, p_blocage_min integer DEFAULT NULL)
RETURNS boolean
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_fenetre interval;
  v_blocage interval;
  v_bloque timestamptz;
BEGIN
  IF p_limite IS NULL OR p_limite < 1 OR p_fenetre_min IS NULL OR p_fenetre_min < 1 OR p_fenetre_min > 10080
     OR (p_blocage_min IS NOT NULL AND (p_blocage_min < 1 OR p_blocage_min > 10080)) THEN
    RAISE EXCEPTION 'compteur : limite ou fenêtre hors bornes' USING ERRCODE = '22023';
  END IF;
  v_fenetre := make_interval(mins => p_fenetre_min);
  v_blocage := make_interval(mins => coalesce(p_blocage_min, p_fenetre_min));

  INSERT INTO public.auth_rate_limits AS r (kind, key, failure_count, first_failure_at, last_failure_at, blocked_until)
  VALUES (p_kind, p_key, 1, now(), now(), CASE WHEN 1 > p_limite THEN now() + v_blocage END)
  ON CONFLICT (kind, key) DO UPDATE SET
    failure_count = CASE
      WHEN r.blocked_until > now() THEN r.failure_count
      WHEN r.blocked_until IS NULL AND r.first_failure_at > now() - v_fenetre THEN r.failure_count + 1
      ELSE 1 END,
    first_failure_at = CASE
      WHEN r.blocked_until > now() THEN r.first_failure_at
      WHEN r.blocked_until IS NULL AND r.first_failure_at > now() - v_fenetre THEN r.first_failure_at
      ELSE now() END,
    last_failure_at = now(),
    blocked_until = CASE
      WHEN r.blocked_until > now() THEN r.blocked_until
      WHEN r.blocked_until IS NULL AND r.first_failure_at > now() - v_fenetre AND r.failure_count + 1 > p_limite
        THEN now() + v_blocage
      WHEN 1 > p_limite THEN now() + v_blocage
      ELSE NULL END
  RETURNING r.blocked_until INTO v_bloque;

  RETURN v_bloque IS NOT NULL AND v_bloque > now();
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.fn_compteur_frapper(text, text, integer, integer, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_compteur_frapper(text, text, integer, integer, integer) TO service_role;

-- ─── 2. Rendre une frappe ───────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_compteur_rendre(p_kind text, p_key text)
RETURNS void
LANGUAGE sql
SECURITY INVOKER
SET search_path = public, pg_catalog
AS $function$
  UPDATE public.auth_rate_limits
     SET failure_count = greatest(failure_count - 1, 0)
   WHERE kind = p_kind AND key = p_key
     AND (blocked_until IS NULL OR blocked_until <= now());
$function$;
REVOKE EXECUTE ON FUNCTION public.fn_compteur_rendre(text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_compteur_rendre(text, text) TO service_role;

-- ─── 3. Altcha : l'usage « gazette » ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_consume_altcha_challenge(p_challenge text, p_expires_at timestamp with time zone, p_purpose text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_insere boolean;
begin
  if p_purpose not in ('register', 'cartography', 'bug_report', 'gazette') then
    raise exception 'usage inconnu : %', p_purpose using errcode = '22023';
  end if;

  -- Un défi déjà périmé n'a pas à être accepté, même s'il est neuf.
  if p_expires_at <= now() then
    return false;
  end if;

  insert into public.altcha_consumed_challenges (challenge, expires_at, purpose)
  values (p_challenge, p_expires_at, p_purpose)
  on conflict (challenge) do nothing
  returning true into v_insere;

  -- Purge opportuniste : une ligne périmée ne sert plus à rien, puisqu'un défi
  -- périmé est de toute façon refusé plus haut.
  delete from public.altcha_consumed_challenges where expires_at < now() - interval '1 hour';

  return coalesce(v_insere, false);
end;
$function$;
REVOKE EXECUTE ON FUNCTION public.fn_consume_altcha_challenge(text, timestamptz, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_consume_altcha_challenge(text, timestamptz, text) TO service_role;

ALTER TABLE public.altcha_consumed_challenges DROP CONSTRAINT IF EXISTS altcha_consumed_challenges_purpose_check;
ALTER TABLE public.altcha_consumed_challenges
  ADD CONSTRAINT altcha_consumed_challenges_purpose_check
  CHECK (purpose = ANY (ARRAY['register'::text, 'cartography'::text, 'bug_report'::text, 'gazette'::text]));

-- ─── Vérification ───────────────────────────────────────────────────────────
DO $verif$
DECLARE c text;
BEGIN
  IF has_function_privilege('anon', 'public.fn_compteur_frapper(text, text, integer, integer, integer)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.fn_compteur_frapper(text, text, integer, integer, integer)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.fn_compteur_rendre(text, text)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.fn_compteur_rendre(text, text)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.fn_consume_altcha_challenge(text, timestamptz, text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'compteurs : une fonction reste exécutable hors service_role';
  END IF;
  IF NOT has_function_privilege('service_role', 'public.fn_compteur_frapper(text, text, integer, integer, integer)', 'EXECUTE') THEN
    RAISE EXCEPTION 'compteurs : service_role ne peut pas frapper';
  END IF;
  SELECT pg_get_constraintdef(oid) INTO c FROM pg_constraint WHERE conname = 'altcha_consumed_challenges_purpose_check';
  IF c IS NULL OR position('gazette' IN c) = 0 THEN
    RAISE EXCEPTION 'Altcha : l''usage gazette n''est pas admis par la table';
  END IF;
END $verif$;

COMMIT;
