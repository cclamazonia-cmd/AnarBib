-- ===========================================================================
-- _ci_setup_auth_stub.sql — STUB du schéma `auth` (CI uniquement ; jamais une suite).
-- ---------------------------------------------------------------------------
-- Le baseline (dump --schema public,api,ingest,private) ne crée PAS le schéma
-- `auth` : il SUPPOSE que GoTrue l'a déjà posé (table auth.users + helpers
-- auth.uid()/role()/jwt()/email()). En CI on reconstruit dans une base FRAÎCHE
-- (TEMPLATE template0, pour n'hériter d'AUCUN event trigger — notamment
-- issue_pg_graphql_access, qui casse l'application massive du baseline). Il faut
-- donc poser nous-mêmes un `auth` minimal AVANT le baseline :
--
--   * la table auth.users — cible de la FK profiles_id_fkey (et des inserts du
--     seed) ; colonnes calquées sur GoTrue, toutes nullable hormis la PK ;
--   * les helpers auth.* — définitions RÉELLES de Supabase (lecture de
--     request.jwt.claims) → le JWT simulé par les suites
--     (set_config('request.jwt.claims', …)) pilote aussi la RLS, fidèlement.
--
-- Idempotent. Base de test jetable uniquement — ne touche jamais la prod
-- (le seed et ce stub ne sont appliqués que par le job CI / db reset local).
-- ===========================================================================
CREATE SCHEMA IF NOT EXISTS auth;

CREATE TABLE IF NOT EXISTS auth.users (
  instance_id            uuid,
  id                     uuid NOT NULL PRIMARY KEY,
  aud                    varchar(255),
  role                   varchar(255),
  email                  varchar(255),
  encrypted_password     varchar(255),
  email_confirmed_at     timestamptz,
  invited_at             timestamptz,
  confirmation_token     varchar(255),
  confirmation_sent_at   timestamptz,
  recovery_token         varchar(255),
  recovery_sent_at       timestamptz,
  email_change_token_new varchar(255),
  email_change           varchar(255),
  email_change_sent_at   timestamptz,
  last_sign_in_at        timestamptz,
  raw_app_meta_data      jsonb,
  raw_user_meta_data     jsonb,
  is_super_admin         boolean,
  created_at             timestamptz,
  updated_at             timestamptz,
  phone                  text,
  phone_confirmed_at     timestamptz,
  confirmed_at           timestamptz,
  banned_until           timestamptz,
  deleted_at             timestamptz,
  is_sso_user            boolean NOT NULL DEFAULT false,
  is_anonymous           boolean NOT NULL DEFAULT false
);

-- Helpers Supabase (définitions de référence, schéma auth).
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid
  LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'sub', '')::uuid
$$;

CREATE OR REPLACE FUNCTION auth.role() RETURNS text
  LANGUAGE sql STABLE AS $$
  SELECT coalesce(nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'role', ''), 'anon')
$$;

CREATE OR REPLACE FUNCTION auth.email() RETURNS text
  LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'email', '')
$$;

CREATE OR REPLACE FUNCTION auth.jwt() RETURNS jsonb
  LANGUAGE sql STABLE AS $$
  SELECT coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb, '{}'::jsonb)
$$;
