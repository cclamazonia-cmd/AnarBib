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
-- ---------------------------------------------------------------------------
-- Absence de JWT (ajoute le 29/08/2026, backlog v34, item I7).
--
-- `set_config('request.jwt.claims', NULL, true)` ne met pas NULL : il met la
-- chaine vide. Les trois helpers ci-dessous castaient `current_setting(...)`
-- en jsonb AVANT de neutraliser cette chaine vide, donc `''::jsonb` levait
-- « invalid input syntax for type json » la ou la vraie fonction Supabase
-- renvoie simplement NULL. Consequence : aucune suite ne testait reellement
-- le rejet d'un appel anonyme — elle testait un plantage du stub, et son
-- garde-fou (`SQLERRM LIKE '%uthenticat%'`) ne pouvait pas matcher.
-- `auth.jwt()` avait deja la bonne forme ; les trois autres l'adoptent.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid
  LANGUAGE sql STABLE AS $$
  SELECT nullif(coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb, '{}'::jsonb) ->> 'sub', '')::uuid
$$;

CREATE OR REPLACE FUNCTION auth.role() RETURNS text
  LANGUAGE sql STABLE AS $$
  SELECT coalesce(nullif(coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb, '{}'::jsonb) ->> 'role', ''), 'anon')
$$;

CREATE OR REPLACE FUNCTION auth.email() RETURNS text
  LANGUAGE sql STABLE AS $$
  SELECT nullif(coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb, '{}'::jsonb) ->> 'email', '')
$$;

CREATE OR REPLACE FUNCTION auth.jwt() RETURNS jsonb
  LANGUAGE sql STABLE AS $$
  SELECT coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb, '{}'::jsonb)
$$;

-- ---------------------------------------------------------------------------
-- Les GRANT que Supabase pose sur `auth` en production (ajoutes le 29/08/2026).
-- Sans eux, la fidelite annoncee plus haut ne tient que tant qu'une suite ne
-- prend pas REELLEMENT le role `authenticated` — seul moyen d'eprouver une
-- policy RLS pour de vrai. Des qu'elle le fait, le moindre trigger SECURITY
-- INVOKER appelant auth.uid() echoue sur « permission denied for schema auth ».
-- C'est un echec du HARNAIS, pas du produit : en production `authenticated` a
-- bien USAGE sur `auth` (les policies Supabase appellent auth.uid() en invoker).
-- Trouve en ecrivant tests/sql/portee_catalogage_tests.sql.
-- ---------------------------------------------------------------------------
GRANT USAGE ON SCHEMA auth TO authenticated, anon, service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA auth TO authenticated, anon, service_role;
