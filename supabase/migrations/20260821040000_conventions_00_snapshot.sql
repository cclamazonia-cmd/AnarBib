-- =====================================================================
-- CONVENTIONS CATALOGRAPHIQUES — 00 · Filet de sécurité (snapshot)
-- Spec  : spec-conventions-catalographiques v0.1 §9
-- Audit : docs/journal/audits/AUDIT_conventions_catalographiques_2026-08-20.md
-- Foyer : REGISTRE §37 `CONV` · doctrine DOC-CONV-1 (§0)
-- Date  : 2026-08-21 (UTC) — chantier conventions catalographiques
--
-- Rôle : figer l'état AVANT correction, dans un schéma dédié.
--        Les migrations 01→04 sont réversibles depuis ces tables.
--        Ce fichier ne modifie AUCUNE donnée applicative.
--
-- ⚠️  Le schéma `conv_backup` n'est PAS repris par la sauvegarde #BG2
--     (`anarbib-bg2.sh` dumpe `--schema=public`). Après une restauration
--     depuis BG2, ce filet n'existe plus : la réversibilité vaut pour la
--     base vivante, pas au travers d'un restore. Conserver jusqu'à
--     validation de la reprise, puis archiver hors base.
-- =====================================================================

begin;

create schema if not exists conv_backup;
comment on schema conv_backup is
  'Snapshots pré-correction du chantier conventions catalographiques (REGISTRE §37 CONV, 20/08/2026). '
  'Hors périmètre de la sauvegarde #BG2 (--schema=public). '
  'Conserver jusqu''à validation de la reprise, puis archiver.';

revoke all on schema conv_backup from public, anon, authenticated;

-- --- Autorités ------------------------------------------------------
create table if not exists conv_backup.authors_20260820 as
  select id, preferred_name, sort_name, country, birth_year, death_year
  from public.authors;

-- --- Notices --------------------------------------------------------
create table if not exists conv_backup.books_20260820 as
  select id, titulo, subtitulo, idioma, autor
  from public.books;

-- --- Brouillons (le chemin d'écriture est corrigé en 01) -------------
create table if not exists conv_backup.book_drafts_20260820 as
  select id, titulo, subtitulo, idioma from public.book_drafts;

create table if not exists conv_backup.author_drafts_20260820 as
  select id, preferred_name, sort_name, country from public.author_drafts;

-- ---------------------------------------------------------------------
-- Vérification
--
-- ⚠️ Ce bloc DOIT rester jouable sur une base VIDE : le job CI `sql-tests`
--    (scripts/ci/run-sql-suites.sh) reconstruit un schéma jetable à partir
--    des migrations, sur une base créée TEMPLATE template0 et AVANT le
--    seed, avec ON_ERROR_STOP=1. Un `raise exception` conditionné à la
--    présence de données y échoue systématiquement et bloque toute la
--    forge. On distingue donc « base sans données » (normal en CI) de
--    « snapshot vide alors que la source ne l'est pas » (vrai échec).
-- ---------------------------------------------------------------------
do $$
declare
  n_src_auth bigint;
  n_src_book bigint;
  n_auth     bigint;
  n_book     bigint;
begin
  select count(*) into n_src_auth from public.authors;
  select count(*) into n_src_book from public.books;
  select count(*) into n_auth     from conv_backup.authors_20260820;
  select count(*) into n_book     from conv_backup.books_20260820;

  if n_src_auth = 0 and n_src_book = 0 then
    raise notice 'CONV/00 — base sans données applicatives (reconstruction CI) : snapshot sans objet.';

  elsif (n_src_auth > 0 and n_auth = 0) or (n_src_book > 0 and n_book = 0) then
    raise exception 'CONV/00 — snapshot VIDE alors que la source ne l''est pas '
                    '(authors %/%, books %/%). Abandon : les migrations 01→04 '
                    'ne seraient pas réversibles.',
                    n_auth, n_src_auth, n_book, n_src_book;

  elsif n_auth <> n_src_auth or n_book <> n_src_book then
    raise warning 'CONV/00 — snapshot préexistant et désynchronisé '
                  '(authors %/%, books %/%). Les tables n''ont PAS été recréées '
                  '(create table if not exists). Vérifier avant de continuer.',
                  n_auth, n_src_auth, n_book, n_src_book;

  else
    raise notice 'CONV/00 — snapshot OK : % autorités, % notices.', n_auth, n_book;
  end if;
end $$;

commit;
