-- ===========================================================================
-- _ci_setup_vault_stub.sql — SEL de test Vault (CI uniquement ; jamais une suite).
-- ---------------------------------------------------------------------------
-- Certaines fonctions (ex. fn_pseudonymize_token, paquet BG2-14) lisent un
-- secret dans vault.decrypted_secrets (extension supabase_vault). L'image de
-- test (public.ecr.aws/supabase/postgres) FOURNIT deja l'extension Vault
-- (schema vault + create_secret) ; on n'a donc PAS a stuber le schema. Il
-- suffit d'y injecter un secret 'pseudonym_salt' de TEST, via l'API native,
-- AVANT les migrations — sinon les DO-blocks qui appellent fn_pseudonymize_token
-- echouent (« secret pseudonym_salt introuvable »).
--
-- La valeur ci-dessous n'est PAS un secret : c'est un sel de test PUBLIC. Les
-- jetons calcules en CI different donc de ceux de prod (sel different) — sans
-- importance : les suites testent la COHERENCE interne (determinisme,
-- distinguabilite), pas une correspondance avec la prod.
--
-- Idempotent : ne cree le secret que s'il est absent. Base de test jetable
-- uniquement — ne touche jamais la prod (applique seulement par le job CI).
-- ===========================================================================
DO $vaultstub$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM vault.decrypted_secrets WHERE name = 'pseudonym_salt') THEN
    PERFORM vault.create_secret(
      'ci_test_salt_deterministic_not_a_real_secret_0123456789abcdef',
      'pseudonym_salt',
      'CI test stub — NOT a real secret'
    );
  END IF;
END
$vaultstub$;
