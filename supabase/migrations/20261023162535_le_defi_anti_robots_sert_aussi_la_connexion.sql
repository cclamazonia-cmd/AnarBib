-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — le défi anti-robots sert aussi la connexion (23/10/2026)
-- Auteur  : Xavier (CCLA) + Claude
-- Session : Modele de menace
--
-- La fonction `login` ne ferme plus un compte au-delà de cinq essais : elle
-- exige une preuve de travail Altcha, valide et jamais servie. L'anti-rejeu
-- passe par fn_consume_altcha_challenge, qui refusait tout usage hors liste :
-- l'usage « login » y entre, et dans la contrainte de la table.
--
-- Corps repris de la définition RÉELLE en production le 23/10/2026 (dernière
-- écriture : migration 20261019155956) ; un seul changement, la liste des
-- usages.
--
-- Tests : tests/sql/compteurs_d_abus_tests.sql (T12 étendu) ;
-- src/tests/login-compteurs-haches.test.js (le défi au lieu du blocage).
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_consume_altcha_challenge(p_challenge text, p_expires_at timestamp with time zone, p_purpose text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_insere boolean;
begin
  if p_purpose not in ('register', 'cartography', 'bug_report', 'gazette', 'login') then
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
  CHECK (purpose = ANY (ARRAY['register'::text, 'cartography'::text, 'bug_report'::text, 'gazette'::text, 'login'::text]));

-- ─── Vérification ──────────────────────────────────────────────────────────
DO $verif$
DECLARE c text;
BEGIN
  IF has_function_privilege('anon', 'public.fn_consume_altcha_challenge(text, timestamptz, text)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.fn_consume_altcha_challenge(text, timestamptz, text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Altcha : la consommation des défis est ouverte hors service_role';
  END IF;
  SELECT pg_get_constraintdef(oid) INTO c FROM pg_constraint WHERE conname = 'altcha_consumed_challenges_purpose_check';
  IF c IS NULL OR position('login' IN c) = 0 OR position('gazette' IN c) = 0 THEN
    RAISE EXCEPTION 'Altcha : l''usage login n''est pas admis par la table (ou un usage a été perdu)';
  END IF;
END $verif$;

COMMIT;
