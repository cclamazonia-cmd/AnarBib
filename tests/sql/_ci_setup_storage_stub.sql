-- ===========================================================================
-- _ci_setup_storage_stub.sql — STUB du schéma `storage` (CI uniquement ; jamais une suite).
-- ---------------------------------------------------------------------------
-- Troisième stub, à côté de `auth` et `vault`, et pour exactement la même
-- raison : le schéma `storage` n'est PAS créé par les migrations. C'est le
-- service Storage qui le construit à son initialisation. En CI on reconstruit
-- dans une base FRAÎCHE (CREATE DATABASE … TEMPLATE template0) où aucun service
-- ne tourne : `storage.buckets` n'existe donc pas.
--
-- POURQUOI IL MANQUAIT (constaté le 20/08/2026). Aucune migration ne touchait
-- `storage` avant `20260820230000_plafonds_buckets_numerisation`. La première
-- qui l'a fait a cassé `sql-tests`, et a dû se garder elle-même par
-- `if to_regclass('storage.buckets') is null then return`. Ce stub est la
-- correction de fond : avec lui, ces migrations s'appliquent VRAIMENT en CI au
-- lieu de se sauter, et sont donc réellement éprouvées.
--
-- LES BUCKETS SONT SEMÉS, ET C'EST INDISPENSABLE. La migration des plafonds ne
-- se contente pas de faire des UPDATE : elle vérifie ensuite que tout bucket
-- attendu existe, et **lève une exception** sinon (« Buckets introuvables »).
-- Une table vide ferait donc échouer la CI plus sûrement qu'une table absente.
-- Les seize identifiants ci-dessous sont ceux relevés en production le
-- 2026-08-20 — huit publics, huit privés.
--
-- CE QUE CE STUB N'EST PAS. Une reproduction du service Storage : ni objets, ni
-- policies, ni upload. Uniquement l'INTERFACE que les migrations lisent et
-- écrivent — id, name, public, file_size_limit, allowed_mime_types. Si une
-- migration future a besoin de `storage.objects`, c'est ici qu'on l'ajoutera.
--
-- Si un bucket est créé ou renommé en production, l'ajouter ici : sinon la
-- migration des plafonds lèvera « Buckets introuvables » en CI — ce qui est le
-- comportement voulu, le stub doit suivre la production.
--
-- Idempotent. Base de test jetable uniquement — ne touche jamais la prod.
-- ===========================================================================
CREATE SCHEMA IF NOT EXISTS storage;

CREATE TABLE IF NOT EXISTS storage.buckets (
  id                 text PRIMARY KEY,
  name               text NOT NULL,
  owner              uuid,
  public             boolean DEFAULT false,
  file_size_limit    bigint,
  allowed_mime_types text[],
  created_at         timestamptz DEFAULT now(),
  updated_at         timestamptz DEFAULT now()
);

INSERT INTO storage.buckets (id, name, public)
VALUES
  ('anarbib-carte-rede',         'anarbib-carte-rede',         false),
  ('anarbib-epub-public',        'anarbib-epub-public',        true),
  ('anarbib-epub-restricted',    'anarbib-epub-restricted',    false),
  ('anarbib-media-public',       'anarbib-media-public',       true),
  ('anarbib-media-restricted',   'anarbib-media-restricted',   false),
  ('anarbib-pdf-public',         'anarbib-pdf-public',         true),
  ('authors',                    'authors',                    true),
  ('catalogos_parceiros_raw',    'catalogos_parceiros_raw',    false),
  ('covers',                     'covers',                     true),
  ('library-privacy-public',     'library-privacy-public',     true),
  ('library-regimentos-private', 'library-regimentos-private', false),
  ('library-regimentos-public',  'library-regimentos-public',  true),
  ('library-ui-assets',          'library-ui-assets',          true),
  ('network-map',                'network-map',                false),
  ('partner-catalog-deposits',   'partner-catalog-deposits',   false),
  ('pdf-restrito',               'pdf-restrito',               false)
ON CONFLICT (id) DO NOTHING;
