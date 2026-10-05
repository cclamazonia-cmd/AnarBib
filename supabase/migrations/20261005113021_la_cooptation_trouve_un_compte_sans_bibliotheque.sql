-- =====================================================================
-- La cooptation trouve un compte qui n'appartient à aucune bibliothèque.
-- Date : 2026-10-05 · constaté par Xavier en cooptant le camarade (`ASR2026`).
--
-- La fenêtre « Proposer la cooptation » résolvait l'adresse en lisant
-- `profiles` depuis le navigateur, sous la RLS. La politique de lecture ne
-- montre à un·e admin réseau que les profils de SES bibliothèques et ceux qui
-- figurent déjà dans une proposition : une personne inscrite sans
-- bibliothèque — le parcours « contributeur·rice d'autorités », celui qu'on
-- conseille pour un·e futur·e admin — restait invisible, et l'écran disait
-- « Aucun compte trouvé avec cet e-mail » alors que le compte existait,
-- confirmé. La recherche passait aussi par `ilike` : `_` et `%` y sont des
-- jokers.
--
-- Correctif : une fonction réservée à l'administration du réseau, qui résout
-- une adresse EXACTE (casse et espaces ignorés) en identifiant de compte. Elle
-- ne rend que l'identifiant — rien que l'admin ne puisse déjà faire —, et ne
-- sert qu'à désigner la personne à coopter. La politique de `profiles` ne
-- change pas.
-- Suite : tests/sql/cooptation_compte_sans_bibliotheque_tests.sql.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.fn_network_admin_find_user_by_email(p_email text)
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_id    uuid;
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Recherche réservée à l''administration du réseau.'
      USING ERRCODE = '42501', HINT = 'error.forbidden';
  END IF;
  IF v_email = '' THEN
    RETURN NULL;
  END IF;
  SELECT u.id INTO v_id
    FROM auth.users u
    JOIN public.profiles p ON p.id = u.id
   WHERE lower(btrim(u.email)) = v_email
     AND u.deleted_at IS NULL
   LIMIT 1;
  RETURN v_id;
END
$fn$;

REVOKE EXECUTE ON FUNCTION public.fn_network_admin_find_user_by_email(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_network_admin_find_user_by_email(text) TO authenticated;

COMMENT ON FUNCTION public.fn_network_admin_find_user_by_email(text) IS
  'Cooptation (05/10/2026) : résout une adresse exacte en identifiant de compte, pour l''administration du réseau seule (error.forbidden sinon). Un compte sans bibliothèque est invisible sous la RLS de profiles.';
