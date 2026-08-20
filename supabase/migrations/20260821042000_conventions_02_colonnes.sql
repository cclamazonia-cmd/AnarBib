-- =====================================================================
-- CONVENTIONS CATALOGRAPHIQUES — 02 · Colonnes nouvelles
-- Foyer : REGISTRE §37 `CONV` · CONV-4 (title_nonfiling), CONV-5 (dates
--         qualifiées), CONV-6 (name_lang, 🟡 à confirmer)
--
-- DDL additive seule : aucune colonne supprimée, aucune donnée perdue.
-- Convention `text` + CHECK plutôt qu'enum PG, par cohérence avec CAT-B1.
-- Prérequis : migration 01 (le pré-remplissage filtre sur idioma normalisé).
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Autorités — langue du nom (CONV-6, 🟡 à confirmer)
--    Distincte de `country` : un·e Argentin·e peut porter un nom italien
--    (cf. Luis Di Filippo). C'est la LANGUE DU NOM qui décide de la règle
--    d'entrée, pas le pays de naissance.
--
--    Créer la colonne n'engage rien (nullable, sans valeur) ; c'est
--    l'utiliser qui engage. CONV-6 reste ouverte au registre.
-- ---------------------------------------------------------------------
alter table public.authors add column if not exists name_lang text;

comment on column public.authors.name_lang is
  'BCP-47. Langue du NOM (≠ country, ≠ langue des ouvrages). Pilote la règle '
  'd''élément d''entrée : cf. spec-conventions-catalographiques §3.1, REGISTRE CONV-6.';

-- Contrainte VALIDE d'emblée : la colonne vient d'être créée, elle est vide,
-- le scan est gratuit. Une contrainte NOT VALID sur une colonne neuve reste
-- non validée à perpétuité et se fait signaler par les advisors.
alter table public.authors drop constraint if exists authors_name_lang_bcp47_chk;
alter table public.authors add constraint authors_name_lang_bcp47_chk
  check (name_lang is null or name_lang ~ '^[a-z]{2}(-[A-Z]{2})?$');

-- ---------------------------------------------------------------------
-- 2. Autorités — dates qualifiées (CONV-5)
-- ---------------------------------------------------------------------
alter table public.authors add column if not exists birth_year_qualifier text;
alter table public.authors add column if not exists death_year_qualifier text;
alter table public.authors add column if not exists activity_period      text;
alter table public.authors add column if not exists dates_note           text;

alter table public.authors drop constraint if exists authors_birth_qualifier_chk;
alter table public.authors add constraint authors_birth_qualifier_chk
  check (birth_year_qualifier is null
         or birth_year_qualifier in ('exact','circa','uncertain','unknown'));

alter table public.authors drop constraint if exists authors_death_qualifier_chk;
alter table public.authors add constraint authors_death_qualifier_chk
  check (death_year_qualifier is null
         or death_year_qualifier in ('exact','circa','uncertain','unknown','living'));

comment on column public.authors.birth_year_qualifier is
  'exact | circa | uncertain | unknown. Se projette sans perte vers EDTF '
  '(1870 / 1870~ / 1870? / ∅) si bascule ultérieure — cf. CONV-5 / CONV-O4.';
comment on column public.authors.death_year_qualifier is
  'idem + living : « encore vivant·e », à distinguer de « date inconnue ». '
  'C''est la distinction que le modèle à deux entiers ne savait pas dire.';
comment on column public.authors.activity_period is
  'Période d''activité quand naissance et mort sont inconnues : « ativo 1900-1910 ».';
comment on column public.authors.dates_note is
  'Note documentaire : source de la date, désaccord entre sources. '
  'Réparation historiographique (spec-notice-autorite-enrichie, INV-4).';

-- Rétro-qualification prudente : ce qui est renseigné est réputé exact,
-- ce qui est absent reste indéterminé (pas 'unknown' — on ne sait pas
-- si personne n'a cherché ou si la recherche a échoué).
update public.authors
   set birth_year_qualifier = 'exact'
 where birth_year is not null and birth_year_qualifier is null;

update public.authors
   set death_year_qualifier = 'exact'
 where death_year is not null and death_year_qualifier is null;

-- ---------------------------------------------------------------------
-- 3. Notices — article non-classant (CONV-4)
-- ---------------------------------------------------------------------
alter table public.books add column if not exists title_nonfiling smallint not null default 0;

alter table public.books drop constraint if exists books_title_nonfiling_chk;
alter table public.books add constraint books_title_nonfiling_chk
  check (title_nonfiling >= 0 and title_nonfiling <= 12);

comment on column public.books.title_nonfiling is
  'Nombre de caractères initiaux ignorés au tri (article + espace), à la manière '
  'de l''indicateur 2 de la zone MARC 245. « A revolução sexual » → 2. '
  'Le titre n''est JAMAIS mutilé pour les besoins du classement (CONV-4). '
  'Consommateur prévu : parcours alphabétique #OPAC10 — la colonne n''est pas '
  'encore exposée par les vues du catalogue.';

-- Pré-remplissage par la langue. Conservateur : uniquement les articles
-- non ambigus. « A » en portugais est un article ; en anglais aussi ;
-- en espagnol « A » est une préposition → non traité, laissé à 0.
update public.books set title_nonfiling = 2
 where title_nonfiling = 0 and idioma = 'pt-BR' and titulo ~ '^(A|O) ';
update public.books set title_nonfiling = 3
 where title_nonfiling = 0 and idioma = 'pt-BR' and titulo ~ '^(As|Os|Um) ';
update public.books set title_nonfiling = 4
 where title_nonfiling = 0 and idioma = 'pt-BR' and titulo ~ '^(Uma) ';
update public.books set title_nonfiling = 3
 where title_nonfiling = 0 and idioma = 'es' and titulo ~ '^(El|La|Un) ';
update public.books set title_nonfiling = 4
 where title_nonfiling = 0 and idioma = 'es' and titulo ~ '^(Los|Las|Una) ';
update public.books set title_nonfiling = 3
 where title_nonfiling = 0 and idioma = 'fr' and titulo ~ '^(Le|La|Un) ';
update public.books set title_nonfiling = 4
 where title_nonfiling = 0 and idioma = 'fr' and titulo ~ '^(Les|Une|Des) ';
update public.books set title_nonfiling = 2
 where title_nonfiling = 0 and idioma = 'fr' and titulo ~ '^L''';
update public.books set title_nonfiling = 4
 where title_nonfiling = 0 and idioma = 'en' and titulo ~ '^The ';
update public.books set title_nonfiling = 2
 where title_nonfiling = 0 and idioma = 'en' and titulo ~ '^A ';
update public.books set title_nonfiling = 3
 where title_nonfiling = 0 and idioma = 'en' and titulo ~ '^An ';
update public.books set title_nonfiling = 3
 where title_nonfiling = 0 and idioma = 'it' and titulo ~ '^(Il|La|Lo|Le|Un) ';
update public.books set title_nonfiling = 4
 where title_nonfiling = 0 and idioma = 'it' and titulo ~ '^(Gli|Uno|Una) ';
update public.books set title_nonfiling = 2
 where title_nonfiling = 0 and idioma = 'it' and titulo ~ '^L''';

-- Index de tri (le parcours alphabétique #OPAC10 en dépend).
create index if not exists books_title_sort_idx
  on public.books ((lower(substr(titulo, title_nonfiling + 1))));

-- ---------------------------------------------------------------------
-- 4. Vérification
--    Le garde-fou d'offset est un invariant STRUCTUREL (il ne dépend pas
--    du contenu du fonds) : il garde son `raise exception`.
-- ---------------------------------------------------------------------
do $$
declare
  n_nonfiling bigint;
  n_qualified bigint;
  n_broken    bigint;
begin
  select count(*) into n_nonfiling from public.books where title_nonfiling > 0;
  select count(*) into n_qualified from public.authors where birth_year_qualifier is not null;

  -- Un offset ne doit jamais tomber au milieu d'un mot : le caractère à la
  -- position `title_nonfiling` est soit l'espace, soit l'apostrophe de « L' ».
  select count(*) into n_broken from public.books
   where title_nonfiling > 0
     and substr(titulo, title_nonfiling, 1) <> ' '
     and substr(titulo, title_nonfiling, 1) <> '''';

  if n_broken > 0 then
    raise exception 'CONV/02 — title_nonfiling incohérent sur % notices '
                    '(offset au milieu d''un mot).', n_broken;
  end if;

  raise notice 'CONV/02 — OK : % notices à article non-classant, % autorités à date qualifiée.',
               n_nonfiling, n_qualified;
end $$;

commit;
