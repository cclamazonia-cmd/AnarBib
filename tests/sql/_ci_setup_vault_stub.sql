-- ===========================================================================
-- _ci_setup_vault_stub.sql — STUB du schéma `vault` (CI uniquement ; jamais une suite).
-- ---------------------------------------------------------------------------
-- Certaines fonctions (ex. fn_pseudonymize_token, paquet BG2-14) lisent un
-- secret dans vault.decrypted_secrets (extension supabase_vault). En CI on
-- reconstruit dans une base FRAÎCHE (CREATE DATABASE … TEMPLATE template0), qui
-- n'hérite PAS des extensions de l'image (Vault inclus) : le schéma `vault`
-- n'existe donc pas. Toute migration qui référence vault.decrypted_secrets
-- échoue (« relation vault.decrypted_secrets does not exist »). Il faut poser
-- nous-mêmes un `vault` minimal AVANT les migrations, comme pour `auth`.
--
--   * vault.decrypted_secrets — reproduit l'INTERFACE lue par le code
--     (colonnes name + decrypted_secret) ; en prod c'est une VUE de
--     déchiffrement de l'extension, ici une simple table (le chiffrement n'a
--     pas de sens en base de test jetable).
--   * un secret 'pseudonym_salt' de TEST (valeur factice, PUBLIQUE, jamais le
--     vrai sel de prod) → les fonctions Vault-dépendantes calculent un résultat
--     déterministe en CI, ce qui permet aux DO-blocks de vérification de passer.
--     Les jetons CI diffèrent de ceux de prod (sel différent) : sans importance,
--     les suites testent la cohérence interne, pas une correspondance prod.
--
-- Idempotent. Base de test jetable uniquement — ne touche jamais la prod
-- (appliqué seulement par le job CI / db reset local, comme le stub auth).
-- ===========================================================================
CREATE SCHEMA IF NOT EXISTS vault;

CREATE TABLE IF NOT EXISTS vault.decrypted_secrets (
  id               uuid DEFAULT gen_random_uuid(),
  name             text,
  description      text,
  decrypted_secret text,
  created_at       timestamptz DEFAULT now(),
  updated_at       timestamptz DEFAULT now()
);

INSERT INTO vault.decrypted_secrets (name, description, decrypted_secret)
SELECT 'pseudonym_salt', 'CI test stub — NOT a real secret',
       'ci_test_salt_deterministic_not_a_real_secret_0123456789abcdef'
WHERE NOT EXISTS (
  SELECT 1 FROM vault.decrypted_secrets WHERE name = 'pseudonym_salt'
);
