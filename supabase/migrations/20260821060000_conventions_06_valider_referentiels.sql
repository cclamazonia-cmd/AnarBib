-- =====================================================================
-- CONVENTIONS CATALOGRAPHIQUES — 06 · Solder CONV-7
-- Foyer : REGISTRE §37 `CONV` · CONV-7
--
-- ---------------------------------------------------------------------
-- POURQUOI CE FICHIER EXISTE — la leçon du 20/08, 22:04 UTC
--
-- La migration 01 a pose ses deux CHECK en `NOT VALID`, avec ce
-- commentaire : « posees NOT VALID pour ne bloquer aucune saisie en
-- cours ». Ce raisonnement est FAUX, et il a coute le deploiement.
--
-- `NOT VALID` ne dispense pas les ecritures : il dispense uniquement le
-- SCAN INITIAL des lignes deja presentes. Toute ligne INSEREE ou MISE A
-- JOUR ensuite est verifiee normalement. La contrainte bloque donc les
-- saisies des la seconde qui suit — c'est exactement l'inverse de ce que
-- le commentaire annonçait.
--
-- Consequence vecue : la migration 02 fait une retro-qualification de
-- dates (`update public.authors set birth_year_qualifier = 'exact' where
-- birth_year is not null`), qui touche 574 lignes sans rapport avec le
-- pays. Parmi elles, au moins une portait encore un `country` non
-- normalise. Postgres a fait son travail :
--
--   new row for relation "authors" violates check constraint
--   "authors_country_iso_chk"
--
-- La transaction de 02 a ete annulee en entier, et `db push` s'est arrete
-- la : 03, 04 et 05 ne sont jamais parties. Une contrainte posee sur un
-- residu non solde n'est pas un filet, c'est une mine — elle explose sous
-- la premiere ecriture venue, y compris une ecriture qui ne la concerne
-- pas.
--
-- Ce fichier solde le residu, puis VALIDE les deux contraintes : une fois
-- validees, elles ne mentent plus sur ce qu'elles garantissent.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Le residu que la table de correspondance de 01 ne couvrait pas
--
--    Elle listait des exonymes (« Espanha », « Allemagne »…) et oubliait
--    les ENDONYMES. Les trois valeurs restantes, relevees en base, sont
--    sans ambiguite. `Angleterre` -> GB : ISO 3166-1 alpha-2 ne code pas
--    l'Angleterre separement (GB-ENG est une subdivision) ; au niveau
--    d'une autorite, GB est la maille juste.
-- ---------------------------------------------------------------------
update public.authors
   set country = case
     when country in ('Angleterre','England','Inglaterra','Inglaterra (Reino Unido)','Reino Unido','Royaume-Uni') then 'GB'
     when country in ('Nederland','Holanda','Pays-Bas','Países Bajos','Paesi Bassi')                              then 'NL'
     when country in ('Türkiye','Turkiye','Turquie','Turquia','Turkey')                                           then 'TR'
     else country end
 where country is not null and country !~ '^[A-Z]{2}$';

update public.author_drafts
   set country = case
     when country in ('Angleterre','England','Inglaterra','Inglaterra (Reino Unido)','Reino Unido','Royaume-Uni') then 'GB'
     when country in ('Nederland','Holanda','Pays-Bas','Países Bajos','Paesi Bassi')                              then 'NL'
     when country in ('Türkiye','Turkiye','Turquie','Turquia','Turkey')                                           then 'TR'
     else country end
 where country is not null and btrim(country) <> '' and country !~ '^[A-Z]{2}$';

-- Les brouillons ne portent aucune contrainte (un brouillon est un
-- materiau de travail), mais ils alimentent `authors` a la publication :
-- un brouillon non normalise ferait echouer la publication sur la
-- contrainte, avec un message que personne ne saurait relier a sa cause.

-- ---------------------------------------------------------------------
-- 2. Validation — seulement si le residu est REELLEMENT solde.
--
--    Jouable sur base vide (CI) : les compteurs y valent 0, la condition
--    est donc satisfaite et la validation ne scanne rien.
-- ---------------------------------------------------------------------
do $$
declare
  bad_lang bigint;
  bad_ctry bigint;
begin
  select count(*) into bad_lang from public.books
   where idioma is not null and idioma !~ '^[a-z]{2}(-[A-Z]{2})?$';
  select count(*) into bad_ctry from public.authors
   where country is not null and country !~ '^[A-Z]{2}$';

  if bad_lang = 0 then
    execute 'alter table public.books validate constraint books_idioma_bcp47_chk';
    raise notice 'CONV/06 — books_idioma_bcp47_chk VALIDEE.';
  else
    raise warning 'CONV/06 — % notice(s) hors referentiel BCP-47 : contrainte laissee NOT VALID. '
                  'Attention : NOT VALID n''empeche PAS le blocage des ecritures.', bad_lang;
  end if;

  if bad_ctry = 0 then
    execute 'alter table public.authors validate constraint authors_country_iso_chk';
    raise notice 'CONV/06 — authors_country_iso_chk VALIDEE.';
  else
    raise warning 'CONV/06 — % autorite(s) hors referentiel ISO 3166-1 : contrainte laissee NOT VALID. '
                  'Toute mise a jour de ces lignes echouera, y compris sur une colonne sans rapport.', bad_ctry;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 3. Verification
-- ---------------------------------------------------------------------
do $$
declare
  n_valides bigint;
  n_draft   bigint;
begin
  select count(*) into n_valides from pg_constraint
   where conname in ('books_idioma_bcp47_chk','authors_country_iso_chk') and convalidated;
  select count(*) into n_draft from public.author_drafts
   where country is not null and btrim(country) <> '' and country !~ '^[A-Z]{2}$';

  raise notice 'CONV/06 — % / 2 contrainte(s) validee(s) · % brouillon(s) d''autorite encore hors referentiel.',
               n_valides, n_draft;
end $$;

commit;
