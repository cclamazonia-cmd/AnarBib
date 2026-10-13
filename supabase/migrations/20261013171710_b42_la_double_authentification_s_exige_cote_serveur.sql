-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — B42, lot 2 (13/10/2026) : la double authentification s'exige
-- côté serveur. LIVRÉE ÉTEINTE.
--
-- Décision de Xavier (12/10/2026) : double authentification obligatoire pour
-- l'administration du réseau, les coordinations et les bibliothécaires ;
-- facultative pour les lecteurs. Le lot 1 (39cb6328) l'a rendue possible
-- (TOTP natif de Supabase Auth) ; il ne protégeait rien : un jeton aal1 (mot de
-- passe seul) appelle l'API directement, l'écran du code se contourne.
--
-- POURQUOI UNE FONCTION D'AVANT-REQUÊTE ET PAS LES AIDES DE RÔLE. Les droits
-- d'équipe passent par une vingtaine d'aides (fn_caller_is_network_admin, 394
-- appels) et par 531 lectures directes de user_library_memberships au rôle
-- écrit sur place (relevé du 12/10). Les reprendre une à une serait fragile :
-- une lecture oubliée laisse fuir des droits. PostgREST appelle une fonction
-- AVANT chaque requête (pgrst.db_pre_request, documenté par Supabase) : un
-- seul contrôle couvre tables, vues, RPC et les Edge Functions qui transmettent
-- le jeton de l'utilisateur.
--
-- LA RÈGLE, calculée à chaque requête, jamais stockée (les montées et
-- descentes de statut n'ont rien à synchroniser) :
--   session aal1 ET aal2 exigé pour ce compte ⇒ requête refusée (403,
--   code AAL2_REQUIRED), sauf la liste blanche (connaître son état).
-- « aal2 exigé » selon le réglage private.double_facteur_reglage.mode :
--   'off'      : jamais (livraison) ;
--   'facteurs' : le compte a un facteur vérifié (qui l'a choisi est protégé) ;
--   'equipes'  : idem, ET tout compte d'équipe — administration du réseau
--                active, ou bibliothécaire / coordination active quelque part.
--                La règle vaut pour la PERSONNE, pas pour une bibliothèque.
-- Un compte d'équipe sans facteur, en 'equipes', ne fait plus que s'inscrire
-- (GoTrue, hors PostgREST) : l'écran d'inscription forcée lit son état par la
-- seule RPC de la liste blanche.
--
-- CE QUE CETTE MIGRATION NE FAIT PAS.
--   * Brancher la fonction : `ALTER ROLE authenticator SET pgrst.db_pre_request`
--     viendra dans une migration à part, le jour de l'activation, avec le
--     passage du mode à 'facteurs'. Tant que rien n'est branché, la fonction
--     n'est appelée par personne.
--   * Storage : pgrst.db_pre_request ne couvre que PostgREST. La politique
--     restrictive sur storage.objects ne peut pas partir par migration
--     (postgres n'est pas propriétaire de la table, les 47 politiques de prod
--     sont posées hors dépôt) : lot 3, depuis le tableau de bord.
--   * Les Edge Functions en service_role qui identifient l'appelant par son
--     jeton : audit au lot 3.
--
-- ÉCHEC OUVERT. Une erreur imprévue dans le calcul (table absente, jeton
-- illisible) laisse passer la requête avec un WARNING au journal : une
-- fonction d'avant-requête qui lève coupe l'API à tout le monde. Seul le refus
-- voulu (SQLSTATE PGRST) sort.
--
-- Objets :
--   private.double_facteur_reglage   une ligne, mode 'off'
--   private.double_facteur_journal   les retraits de facteurs par l'administration
--   private.fn_aal2_exige_pour_moi() DEFINER, sans paramètre (aucun oracle sur
--                                    autrui), ouverte à authenticated : appelée
--                                    sous ce rôle par la fonction d'avant-requête
--   private.fn_avant_requete()       INVOKER ; anon, authenticated, service_role
--                                    (PostgREST l'appelle sous le rôle de la
--                                    requête) ; rend la main tout de suite hors
--                                    authenticated et en aal2
--   api.fn_mon_etat_double_facteur() l'état de MON compte (liste blanche)
--   api.fn_admin_double_facteur_comptes()           administration du réseau :
--                                    comptes d'équipe + comptes à facteur vérifié
--   api.fn_admin_retirer_double_facteur(uuid, text) administration du réseau EN
--                                    aal2, motif obligatoire, journalisé ; ferme
--                                    aussi les sessions du compte
-- Suite : tests/sql/b42_double_authentification_tests.sql
-- ═══════════════════════════════════════════════════════════════════════════

-- ── Le réglage ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS private.double_facteur_reglage (
  id          boolean PRIMARY KEY DEFAULT true CHECK (id),
  mode        text NOT NULL DEFAULT 'off' CHECK (mode IN ('off', 'facteurs', 'equipes')),
  modifie_le  timestamptz NOT NULL DEFAULT now()
);
INSERT INTO private.double_facteur_reglage (id, mode) VALUES (true, 'off') ON CONFLICT (id) DO NOTHING;
ALTER TABLE private.double_facteur_reglage ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.double_facteur_reglage FROM PUBLIC, anon, authenticated;
GRANT ALL ON private.double_facteur_reglage TO service_role;
COMMENT ON TABLE private.double_facteur_reglage IS
  'B42 — mode d''exigence de la double authentification : off (livraison), facteurs (comptes qui en ont un), equipes (+ administration du réseau, bibliothécaires, coordinations). Se change par migration.';

-- ── Le journal des retraits ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS private.double_facteur_journal (
  id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  le                timestamptz NOT NULL DEFAULT now(),
  par               uuid NOT NULL,
  compte            uuid NOT NULL,
  facteurs_retires  integer NOT NULL,
  sessions_fermees  integer NOT NULL,
  motif             text NOT NULL CHECK (length(btrim(motif)) >= 10)
);
ALTER TABLE private.double_facteur_journal ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.double_facteur_journal FROM PUBLIC, anon, authenticated;
GRANT ALL ON private.double_facteur_journal TO service_role;
COMMENT ON TABLE private.double_facteur_journal IS
  'B42 — chaque retrait des facteurs d''un compte par l''administration du réseau (appareil perdu, identité vérifiée hors bande) : qui, pour qui, combien, pourquoi.';

-- ── « Mon compte doit-il présenter un second facteur ? » ───────────────────
CREATE OR REPLACE FUNCTION private.fn_aal2_exige_pour_moi()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
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
  IF v_mode <> 'equipes' THEN RETURN false; END IF;
  RETURN EXISTS (SELECT 1 FROM public.network_administrators na WHERE na.user_id = v_uid AND na.status = 'active')
      OR EXISTS (SELECT 1 FROM public.user_library_memberships m
                  WHERE m.user_id = v_uid AND m.status = 'active' AND m.role IN ('librarian', 'coordenador'));
END $$;
REVOKE ALL ON FUNCTION private.fn_aal2_exige_pour_moi() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.fn_aal2_exige_pour_moi() TO authenticated, service_role;
COMMENT ON FUNCTION private.fn_aal2_exige_pour_moi() IS
  'B42 — vrai si le compte de la session doit être en aal2 (selon private.double_facteur_reglage). Sans paramètre : ne dit rien d''un autre compte. Dans private (hors PostgREST) : ouverte à authenticated seulement pour la fonction d''avant-requête, qui s''exécute sous ce rôle.';

-- ── La fonction d'avant-requête (non branchée par cette migration) ─────────
CREATE OR REPLACE FUNCTION private.fn_avant_requete()
RETURNS void
LANGUAGE plpgsql
STABLE
SET search_path TO ''
AS $$
DECLARE
  v_claims jsonb;
  v_chemin text;
  v_bloque boolean := false;
BEGIN
  BEGIN
    v_claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
    -- anon, service_role, absence de jeton : rien à exiger.
    IF v_claims IS NULL OR v_claims ->> 'role' IS DISTINCT FROM 'authenticated' THEN RETURN; END IF;
    IF v_claims ->> 'aal' = 'aal2' THEN RETURN; END IF;
    -- La liste blanche : de quoi savoir qu'il faut un code ou s'inscrire.
    v_chemin := ltrim(coalesce(current_setting('request.path', true), ''), '/');
    IF v_chemin IN ('rpc/fn_mon_etat_double_facteur') THEN RETURN; END IF;
    v_bloque := private.fn_aal2_exige_pour_moi();
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'B42 fn_avant_requete, échec ouvert : % (%)', SQLERRM, SQLSTATE;
    RETURN;
  END;
  IF v_bloque THEN
    RAISE SQLSTATE 'PGRST' USING
      MESSAGE = json_build_object(
        'code', 'AAL2_REQUIRED',
        'message', 'Double authentification requise',
        'hint', 'twoFactor.required')::text,
      DETAIL = json_build_object('status', 403)::text;
  END IF;
END $$;
REVOKE ALL ON FUNCTION private.fn_avant_requete() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.fn_avant_requete() TO anon, authenticated, service_role;
COMMENT ON FUNCTION private.fn_avant_requete() IS
  'B42 — fonction d''avant-requête de PostgREST (pgrst.db_pre_request) : refuse en 403 AAL2_REQUIRED une session aal1 dont le compte doit être en aal2, sauf rpc/fn_mon_etat_double_facteur. INVOKER : PostgREST l''appelle sous le rôle de la requête, d''où l''EXECUTE à anon (rend la main aussitôt). Échec ouvert sur toute erreur imprévue. Branchée par une migration d''activation distincte.';

-- ── L'état de mon compte (seule RPC de la liste blanche) ────────────────────
CREATE OR REPLACE FUNCTION api.fn_mon_etat_double_facteur()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_mode text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
  END IF;
  SELECT r.mode INTO v_mode FROM private.double_facteur_reglage r WHERE r.id;
  RETURN jsonb_build_object(
    'mode', coalesce(v_mode, 'off'),
    'aal', coalesce(auth.jwt() ->> 'aal', 'aal1'),
    'a_facteur', EXISTS (SELECT 1 FROM auth.mfa_factors f WHERE f.user_id = v_uid AND f.status = 'verified'),
    'equipe', EXISTS (SELECT 1 FROM public.network_administrators na WHERE na.user_id = v_uid AND na.status = 'active')
           OR EXISTS (SELECT 1 FROM public.user_library_memberships m
                       WHERE m.user_id = v_uid AND m.status = 'active' AND m.role IN ('librarian', 'coordenador')),
    'exige', private.fn_aal2_exige_pour_moi());
END $$;
REVOKE ALL ON FUNCTION api.fn_mon_etat_double_facteur() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION api.fn_mon_etat_double_facteur() TO authenticated, service_role;
COMMENT ON FUNCTION api.fn_mon_etat_double_facteur() IS
  'B42 — l''état de la double authentification pour le compte de la session : mode, aal du jeton, facteur vérifié, compte d''équipe, aal2 exigé. Seule RPC de la liste blanche de private.fn_avant_requete : une session aal1 bloquée la lit pour savoir s''il faut un code ou une inscription.';

-- ── L'administration du réseau : les comptes d'équipe et leurs facteurs ────
CREATE OR REPLACE FUNCTION api.fn_admin_double_facteur_comptes()
RETURNS TABLE (
  user_id          uuid,
  nom              text,
  email            text,
  administration   boolean,
  equipes          text,
  facteurs         integer,
  dernier_facteur  timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  PERFORM public.fn_assert_network_admin();
  RETURN QUERY
  WITH comptes AS (
    SELECT na.user_id AS uid FROM public.network_administrators na WHERE na.status = 'active'
    UNION
    SELECT m.user_id FROM public.user_library_memberships m
     WHERE m.status = 'active' AND m.role IN ('librarian', 'coordenador')
    UNION
    -- les lecteurs qui l'ont choisie : un appareil perdu se retire d'ici aussi
    SELECT f.user_id FROM auth.mfa_factors f WHERE f.status = 'verified'
  )
  SELECT c.uid,
         nullif(btrim(concat_ws(' ', p.first_name, p.last_name)), ''),
         p.email::text,
         EXISTS (SELECT 1 FROM public.network_administrators na WHERE na.user_id = c.uid AND na.status = 'active'),
         (SELECT string_agg(l.name || ' (' || m.role || ')', ', ' ORDER BY l.name, m.role)
            FROM public.user_library_memberships m JOIN public.libraries l ON l.id = m.library_id
           WHERE m.user_id = c.uid AND m.status = 'active' AND m.role IN ('librarian', 'coordenador')),
         (SELECT count(*)::integer FROM auth.mfa_factors f WHERE f.user_id = c.uid AND f.status = 'verified'),
         (SELECT max(f.created_at) FROM auth.mfa_factors f WHERE f.user_id = c.uid AND f.status = 'verified')
    FROM comptes c
    LEFT JOIN public.profiles p ON p.id = c.uid
   ORDER BY 6, 2 NULLS LAST;
END $$;
REVOKE ALL ON FUNCTION api.fn_admin_double_facteur_comptes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION api.fn_admin_double_facteur_comptes() TO authenticated, service_role;
COMMENT ON FUNCTION api.fn_admin_double_facteur_comptes() IS
  'B42 — administration du réseau seulement : chaque compte d''équipe actif (administration du réseau, bibliothécaire, coordination) et chaque compte à facteur vérifié, ses bibliothèques et le nombre de ses facteurs vérifiés, ceux sans facteur d''abord. Sert à préparer et suivre la bascule, et à retrouver un compte dont l''appareil est perdu.';

-- ── L'administration du réseau retire les facteurs d'un compte ─────────────
CREATE OR REPLACE FUNCTION api.fn_admin_retirer_double_facteur(p_user uuid, p_motif text)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_facteurs integer;
  v_sessions integer;
BEGIN
  PERFORM public.fn_assert_network_admin();
  -- Retirer la protection d'autrui exige d'avoir prouvé la sienne.
  IF coalesce(auth.jwt() ->> 'aal', 'aal1') <> 'aal2' THEN
    RAISE EXCEPTION 'aal2_required' USING ERRCODE = '42501', HINT = 'twoFactor.error.needCode';
  END IF;
  IF p_user IS NULL OR NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = p_user) THEN
    RAISE EXCEPTION 'user_not_found' USING ERRCODE = 'P0002';
  END IF;
  IF length(btrim(coalesce(p_motif, ''))) < 10 THEN
    RAISE EXCEPTION 'motif_required' USING ERRCODE = '22023', HINT = 'twoFactor.admin.motifRequired';
  END IF;

  DELETE FROM auth.mfa_factors f WHERE f.user_id = p_user;
  GET DIAGNOSTICS v_facteurs = ROW_COUNT;
  -- Le compte est déconnecté partout : un appareil perdu peut avoir été pris.
  DELETE FROM auth.sessions s WHERE s.user_id = p_user;
  GET DIAGNOSTICS v_sessions = ROW_COUNT;

  INSERT INTO private.double_facteur_journal (par, compte, facteurs_retires, sessions_fermees, motif)
  VALUES (auth.uid(), p_user, v_facteurs, v_sessions, btrim(p_motif));

  RETURN jsonb_build_object('facteurs_retires', v_facteurs, 'sessions_fermees', v_sessions);
END $$;
REVOKE ALL ON FUNCTION api.fn_admin_retirer_double_facteur(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION api.fn_admin_retirer_double_facteur(uuid, text) TO authenticated, service_role;
COMMENT ON FUNCTION api.fn_admin_retirer_double_facteur(uuid, text) IS
  'B42 — administration du réseau, en aal2 : retire tous les facteurs d''un compte (appareil perdu, identité vérifiée hors bande) et ferme ses sessions ; motif d''au moins dix caractères, journalisé dans private.double_facteur_journal.';
