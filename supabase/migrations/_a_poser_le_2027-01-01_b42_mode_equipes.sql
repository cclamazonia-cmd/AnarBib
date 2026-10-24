-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — B42 : la double authentification devient obligatoire pour les
-- équipes (mode 'equipes'), à partir du 1er janvier 2027 — échéance décidée
-- par Xavier et annoncée le 13/10/2026 aux quatorze comptes d'équipe.
--
-- FICHIER EN ATTENTE. Préfixé « _ » : ni la CI, ni run-migrations.sh, ni la
-- CLI ne l'appliquent. Préparé le 14/10/2026, juste après l'activation en
-- mode 'facteurs' (20261013234826).
--
-- LE JOUR VENU (le 1er janvier 2027 ou juste après, hors fenêtre de
-- sauvegarde : pas à 19 h, pas le dimanche à 20 h, heure de Paris) :
--   1. Regarder l'onglet Réseau → « Double authentification » : qui n'a
--      encore aucun appareil ? Ces comptes ne pourront plus rien faire, une
--      fois connectés, que s'inscrire (écran d'inscription obligatoire).
--   2. Renommer ce fichier à la seconde UTC réelle (DOC-DEPLOY-4) :
--        git mv supabase/migrations/_a_poser_le_2027-01-01_b42_mode_equipes.sql \
--          "supabase/migrations/$(date -u +%Y%m%d%H%M%S)_b42_mode_equipes.sql"
--      et retirer ce bloc « FICHIER EN ATTENTE / LE JOUR VENU ».
--   3. Dans tests/sql/b42_double_authentification_tests.sql, T1 : le mode
--      attendu après les migrations passe de 'reseau' à 'equipes' (deux
--      endroits : l'en-tête et le IF … IS DISTINCT FROM 'reseau').
--   4. Banc SQL complet (copie isolée), vitest, puis push ; vérifier en
--      production : mode 'equipes', ligne de schema_migrations sans created_by.
--   Retour arrière : UPDATE … SET mode = 'reseau' (depuis le 24/10/2026 : les comptes à appareil
--   et l'administration du réseau restent protégés, les autres retrouvent l'accès sans code).
--
-- CE QUE CELA CHANGE. En plus des comptes qui ont un appareil, tout compte
-- d'équipe — administration du réseau active, bibliothécaire ou coordination
-- active quelque part — doit présenter un code (aal2). Sans appareil, il ne
-- peut plus que s'inscrire : PostgREST refuse tout sauf
-- rpc/fn_mon_etat_double_facteur (403 AAL2_REQUIRED), Storage et les Edge
-- Functions gardées refusent aussi, et la page de connexion ouvre l'écran
-- d'inscription guidée (REGISTRE 2FA-2). Les lecteur·rices sans appareil ne
-- voient rien.
-- ═══════════════════════════════════════════════════════════════════════════

-- Garde : 'equipes' n'a de sens que si PostgREST appelle la fonction
-- d'avant-requête (branchée par 20261013234826). Sinon Storage et les Edge
-- Functions exigeraient le code et PostgREST non : on refuse de poser le mode.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_db_role_setting s JOIN pg_roles r ON r.oid = s.setrole
                  WHERE r.rolname = 'authenticator' AND s.setdatabase = 0
                    AND 'pgrst.db_pre_request=private.fn_avant_requete' = ANY (s.setconfig)) THEN
    RAISE EXCEPTION 'B42 : la fonction d''avant-requête n''est pas branchée sur authenticator — mode equipes refusé';
  END IF;
END $$;

UPDATE private.double_facteur_reglage SET mode = 'equipes', modifie_le = now() WHERE id;
