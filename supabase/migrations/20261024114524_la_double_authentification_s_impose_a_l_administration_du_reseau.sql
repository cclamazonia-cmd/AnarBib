-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — la double authentification s'impose à l'administration du réseau
-- (24/10/2026)
-- Auteur  : Xavier (CCLA) + Claude
-- Session : Modele de menace
--
-- Dernier point de la suite sécurité fixée le 21/10 : avancer, pour la seule
-- administration du réseau, l'obligation que B42 fixait au 1er janvier 2027
-- pour tous les comptes d'équipe. L'administration du réseau traverse
-- l'isolement des bibliothèques (RET-5) : c'est le compte dont la prise vaut
-- le plus.
--
-- Un mode de plus, entre 'facteurs' et 'equipes' :
--   'off'       rien n'est exigé ;
--   'facteurs'  les comptes qui ont inscrit un appareil ;
--   'reseau'    idem, ET l'administration du réseau active, appareil ou non ;
--   'equipes'   idem, ET les bibliothécaires et coordinations actives.
-- Chaque mode contient le précédent. Une administration sans appareil ne fait
-- plus, une fois connectée, que s'inscrire : la fonction d'avant-requête la
-- refuse partout sauf rpc/fn_mon_etat_double_facteur, qui rend « exige » ; la
-- page de connexion ouvre alors l'inscription guidée (REGISTRE 2FA-2).
-- Storage et les Edge Functions lisent la même fonction : rien d'autre à
-- changer.
--
-- Corps de private.fn_aal2_exige_pour_moi repris de sa définition RÉELLE en
-- production le 24/10/2026 (20261013171710) ; seul l'ordre des tests change.
-- Retour arrière : UPDATE private.double_facteur_reglage SET mode = 'facteurs'.
-- Le fichier en attente du 1er janvier 2027 (_a_poser_le_2027-01-01_…) passe
-- toujours en 'equipes', qui contient 'reseau'.
--
-- Tests : tests/sql/b42_double_authentification_tests.sql (T1 : mode 'reseau'
-- après les migrations ; T12 : le tableau du mode 'reseau' ; T13 : l'état
-- rendu à une administration sans appareil).
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

ALTER TABLE private.double_facteur_reglage DROP CONSTRAINT double_facteur_reglage_mode_check;
ALTER TABLE private.double_facteur_reglage
  ADD CONSTRAINT double_facteur_reglage_mode_check CHECK (mode IN ('off', 'facteurs', 'reseau', 'equipes'));

CREATE OR REPLACE FUNCTION private.fn_aal2_exige_pour_moi()
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid  uuid := auth.uid();
  v_mode text;
BEGIN
  IF v_uid IS NULL THEN RETURN false; END IF;
  SELECT r.mode INTO v_mode FROM private.double_facteur_reglage r WHERE r.id;
  IF v_mode IS NULL OR v_mode = 'off' THEN RETURN false; END IF;
  IF EXISTS (SELECT 1 FROM auth.mfa_factors f WHERE f.user_id = v_uid AND f.status = 'verified') THEN
    RETURN true;
  END IF;
  IF v_mode = 'facteurs' THEN RETURN false; END IF;
  -- 'reseau' et 'equipes' : l'administration du réseau active.
  IF EXISTS (SELECT 1 FROM public.network_administrators na WHERE na.user_id = v_uid AND na.status = 'active') THEN
    RETURN true;
  END IF;
  IF v_mode <> 'equipes' THEN RETURN false; END IF;
  RETURN EXISTS (SELECT 1 FROM public.user_library_memberships m
                  WHERE m.user_id = v_uid AND m.status = 'active' AND m.role IN ('librarian', 'coordenador'));
END $function$;

COMMENT ON COLUMN private.double_facteur_reglage.mode IS
  'B42 — mode d''exigence de la double authentification : off ; facteurs (comptes qui en ont un) ; reseau (idem + administration du réseau, depuis le 24/10/2026) ; equipes (idem + bibliothécaires et coordinations, prévu le 1er janvier 2027).';

-- Garde, comme pour 'equipes' : sans la fonction d'avant-requête branchée,
-- Storage et les Edge Functions exigeraient le code et PostgREST non.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_db_role_setting s JOIN pg_roles r ON r.oid = s.setrole
                  WHERE r.rolname = 'authenticator' AND s.setdatabase = 0
                    AND 'pgrst.db_pre_request=private.fn_avant_requete' = ANY (s.setconfig)) THEN
    RAISE EXCEPTION 'B42 : la fonction d''avant-requête n''est pas branchée sur authenticator — mode reseau refusé';
  END IF;
END $$;

-- Ne descend jamais : si le réglage est déjà plus exigeant, il reste.
UPDATE private.double_facteur_reglage SET mode = 'reseau', modifie_le = now()
 WHERE id AND mode IN ('off', 'facteurs');

DO $verif$
BEGIN
  IF (SELECT mode FROM private.double_facteur_reglage WHERE id) NOT IN ('reseau', 'equipes') THEN
    RAISE EXCEPTION 'B42 : le mode n''est pas au moins reseau';
  END IF;
  IF has_function_privilege('anon', 'private.fn_aal2_exige_pour_moi()', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'private.fn_aal2_exige_pour_moi()', 'EXECUTE') THEN
    RAISE EXCEPTION 'B42 : fn_aal2_exige_pour_moi doit rester fermée à anon et ouverte à authenticated';
  END IF;
END
$verif$;

COMMIT;
