-- ===========================================================================
-- _ci_setup_image_services_stub.sql — ce que GoTrue pose au démarrage de la
-- pile, et qu'une image supabase/postgres NUE n'a pas encore.
-- (CI uniquement, job `rejeu-image` ; jamais une suite. Backlog I18, 16/09/2026.)
-- ---------------------------------------------------------------------------
-- La pile auto-hébergée démarre `auth` (GoTrue) et `storage` AVANT de rejouer
-- les migrations, et bootstrap.sh attend que les quatre helpers auth.* soient
-- là (étape 4/8). En CI aucun service ne tourne : le job `rejeu-image` parle à
-- l'image seule. Mesuré le 16/09/2026 sur public.ecr.aws/supabase/postgres
-- 17.6.1.084, la base `postgres` de l'image fournit :
--
--   * `auth` : `auth.users` dans sa forme d'ORIGINE (21 colonnes : ni
--     email_confirmed_at, ni is_sso_user / is_anonymous / deleted_at /
--     banned_until / phone…) ; `auth.uid()`, `auth.role()`, `auth.email()`
--     dans leur forme d'origine aussi — elles ne lisent que
--     `request.jwt.claim.sub` / `.role` / `.email`, pas `request.jwt.claims`
--     (le jeton simulé par les auto-tests des migrations, cf. 20260702081711
--     qui échoue sur « Nenhum usuário autenticado ») ; et PAS `auth.jwt()`
--     (le socle s'arrête dessus à sa ligne 41402). GoTrue remplace les trois
--     helpers et ajoute le quatrième par ses propres migrations ;
--   * `storage` : le schéma, vide — ni `buckets` ni `objects` ;
--   * `vault` : l'extension supabase_vault RÉELLE (vault.secrets,
--     vault.decrypted_secrets, vault.create_secret) — rien à stubber, le sel
--     se pose par vault.create_secret, comme bootstrap.sh le fait (étape 3/8).
--
-- Ce fichier ne pose QUE ce qui n'est écrit nulle part ailleurs, et il passe
-- APRÈS les stubs `auth` et `storage` de sql-tests :
--
--   1. les colonnes qu'un GoTrue à jour ajoute à `auth.users` et que le dépôt
--      cite (20260623204043 insère email_confirmed_at, is_sso_user,
--      is_anonymous) — liste calquée sur le stub `auth`, colonne pour
--      colonne, pour ne pas avoir deux vérités. Les quatre helpers auth.*
--      (définitions de référence Supabase) et les GRANT sur `auth` viennent
--      du stub `auth` lui-même : son CREATE TABLE IF NOT EXISTS ne fait rien
--      ici (la table existe), ses CREATE OR REPLACE FUNCTION remplacent les
--      définitions d'origine — exactement ce que GoTrue fait dans la pile ;
--   2. les droits que Storage donne sur ses tables. Le stub `storage` crée
--      `storage.buckets` et sème les buckets que les migrations vérifient ;
--      mais en sql-tests c'est `postgres` qui l'applique et possède la table,
--      alors qu'ici c'est `supabase_admin` — et l'image n'a AUCUN privilège
--      par défaut sur `storage` : la table naît fermée, et 20260820012512
--      s'arrête sur « permission denied for table buckets ». Dans la pile,
--      Storage possède ses tables et les ouvre à postgres, anon,
--      authenticated et service_role (relevé sur la pile locale, 16/09) ;
--      on écrit la même ouverture.
--
-- CE QUE CE STUB N'EST PAS : GoTrue ni Storage. Si une migration future
-- dépend d'une table `auth.*` autre que `users`, ou de `storage.objects`,
-- c'est ici qu'on l'ajoutera — et ce sera l'occasion de se demander si un
-- rejeu à froid (restauration après sinistre, sans services) y survivrait.
--
-- Idempotent. Base jetable uniquement — ne touche jamais la prod.
-- ===========================================================================

-- 1. auth.users : les colonnes des migrations de GoTrue.
ALTER TABLE auth.users
  ADD COLUMN IF NOT EXISTS email_confirmed_at     timestamptz,
  ADD COLUMN IF NOT EXISTS email_change_token_new varchar(255),
  ADD COLUMN IF NOT EXISTS phone                  text,
  ADD COLUMN IF NOT EXISTS phone_confirmed_at     timestamptz,
  ADD COLUMN IF NOT EXISTS banned_until           timestamptz,
  ADD COLUMN IF NOT EXISTS deleted_at             timestamptz,
  ADD COLUMN IF NOT EXISTS is_sso_user            boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_anonymous           boolean NOT NULL DEFAULT false;

-- 2. storage : les droits que le service Storage pose sur ses tables.
GRANT ALL ON ALL TABLES IN SCHEMA storage TO postgres, anon, authenticated, service_role;
