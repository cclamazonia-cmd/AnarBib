-- =====================================================================
-- CONVENTIONS CATALOGRAPHIQUES — 01 · Référentiels (CONV-7)
-- Foyer : REGISTRE §37 `CONV` · CONV-7
--
-- Prérequis DUR de toutes les autres passes : la règle de casse des
-- titres (CONV-3) et la règle d'entrée des noms (CONV-6) sont pilotées
-- par la langue. Réversible depuis conv_backup.* (migration 00).
--
-- Constat (audit R1/R2) :
--   books.idioma    : 11 valeurs pour 8 langues, 471 NULL
--   authors.country : 47 valeurs, 12 libellés en clair, 722 NULL
--
-- ⚠️  CONV-7 ne vaut que si TOUS les chemins d'écriture appliquent le
--     référentiel. Cette migration traite donc aussi les tables de
--     BROUILLON : `publish_book_draft` recopie `book_drafts.idioma`
--     dans `books.idioma`, un brouillon ancien publié après coup
--     ré-injecterait sinon l'ancien régime. Le volet frontend
--     (sélecteur de pays, mapping OCR) voyage dans le même paquet.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. books.idioma → BCP-47
--    Les NULL restent NULL : ne pas inventer une langue (CONV-7).
-- ---------------------------------------------------------------------
update public.books set idioma = 'pt-BR' where idioma in ('Português', 'pt-BR', 'pt');
update public.books set idioma = 'es'    where idioma in ('Espanhol', 'es');
update public.books set idioma = 'fr'    where idioma in ('Francês', 'fr');
update public.books set idioma = 'en'    where idioma in ('Inglês', 'en');
update public.books set idioma = 'it'    where idioma in ('Italiano', 'it');
update public.books set idioma = 'de'    where idioma in ('Alemão', 'de');
update public.books set idioma = 'eo'    where idioma in ('Esperanto', 'eo');
update public.books set idioma = 'ca'    where idioma in ('Catalão', 'ca');
update public.books set idioma = 'nl'    where idioma in ('Holandês', 'Neerlandês', 'nl');
update public.books set idioma = 'el'    where idioma in ('Grego', 'el');

-- NOTE : 'pt-BR' est retenu comme valeur unique pour le portugais, par
-- cohérence avec DOC-I18N-1 (langue de base de l'instance) et avec le
-- sélecteur de Catalogação (IDIOMA_CODES, src/pages/catalogacao/
-- fieldRegistry.js) qui n'offre que 'pt-BR'. Si le réseau doit un jour
-- distinguer pt-PT de pt-BR au niveau notice, c'est ICI que la décision
-- se prend — pas dans un correctif ultérieur.

-- --- Même passe sur les brouillons (chemin d'écriture) ---------------
update public.book_drafts set idioma = 'pt-BR' where idioma in ('Português', 'pt-BR', 'pt');
update public.book_drafts set idioma = 'es'    where idioma in ('Espanhol', 'es');
update public.book_drafts set idioma = 'fr'    where idioma in ('Francês', 'fr');
update public.book_drafts set idioma = 'en'    where idioma in ('Inglês', 'en');
update public.book_drafts set idioma = 'it'    where idioma in ('Italiano', 'it');
update public.book_drafts set idioma = 'de'    where idioma in ('Alemão', 'de');
update public.book_drafts set idioma = 'eo'    where idioma in ('Esperanto', 'eo');
update public.book_drafts set idioma = 'ca'    where idioma in ('Catalão', 'ca');
update public.book_drafts set idioma = 'nl'    where idioma in ('Holandês', 'Neerlandês', 'nl');
update public.book_drafts set idioma = 'el'    where idioma in ('Grego', 'el');

-- ---------------------------------------------------------------------
-- 2. authors.country → ISO 3166-1 alpha-2
--    NB : `libraries.country` et `library_requests.country` ne sont PAS
--    touchées — colonnes distinctes, `DEFAULT 'Brasil' NOT NULL`, dont
--    l'affichage passe par getCountryName() qui tolère les deux régimes.
-- ---------------------------------------------------------------------
update public.authors set country = 'ES' where country in ('España', 'Espanha', 'Espagne');
update public.authors set country = 'BR' where country in ('Brasil', 'Brésil', 'Brazil');
update public.authors set country = 'FR' where country in ('France', 'França', 'Francia');
update public.authors set country = 'RU' where country in ('Russie', 'Rússia', 'Rusia', 'Russia');
update public.authors set country = 'IT' where country in ('Itália', 'Italie', 'Italia');
update public.authors set country = 'DE' where country in ('Alemanha', 'Allemagne', 'Alemania');
update public.authors set country = 'PT' where country in ('Portugal');
update public.authors set country = 'AR' where country in ('Argentina', 'Argentine');
update public.authors set country = 'US' where country in ('Estados Unidos', 'États-Unis', 'USA');

-- Normalisation défensive : casse + espaces sur les codes déjà corrects.
update public.authors
   set country = upper(btrim(country))
 where country is not null
   and country ~ '^\s*[A-Za-z]{2}\s*$'
   and country <> upper(btrim(country));

-- --- Même passe sur les brouillons d'autorité ------------------------
update public.author_drafts set country = 'ES' where country in ('España', 'Espanha', 'Espagne');
update public.author_drafts set country = 'BR' where country in ('Brasil', 'Brésil', 'Brazil');
update public.author_drafts set country = 'FR' where country in ('France', 'França', 'Francia');
update public.author_drafts set country = 'RU' where country in ('Russie', 'Rússia', 'Rusia', 'Russia');
update public.author_drafts set country = 'IT' where country in ('Itália', 'Italie', 'Italia');
update public.author_drafts set country = 'DE' where country in ('Alemanha', 'Allemagne', 'Alemania');
update public.author_drafts set country = 'PT' where country in ('Portugal');
update public.author_drafts set country = 'AR' where country in ('Argentina', 'Argentine');
update public.author_drafts set country = 'US' where country in ('Estados Unidos', 'États-Unis', 'USA');

update public.author_drafts
   set country = upper(btrim(country))
 where country is not null
   and country ~ '^\s*[A-Za-z]{2}\s*$'
   and country <> upper(btrim(country));

-- ---------------------------------------------------------------------
-- 3. Expressions FRBR orphelines.
--
--    `trg_sync_book_expression` dérive expression_id de (work_id, idioma)
--    et crée l'expression manquante — la réécriture ci-dessus a donc
--    fabriqué les expressions 'pt-br', 'es', 'fr'… Mais les anciennes
--    lignes ('português', 'espanhol'…) subsistent, désormais sans aucune
--    notice qui les référence : WorkPage afficherait des groupes de
--    langue vides.
-- ---------------------------------------------------------------------
delete from public.work_expressions e
 where not exists (select 1 from public.books b where b.expression_id = e.id);

-- ---------------------------------------------------------------------
-- 4. Contraintes — posées NOT VALID pour ne bloquer aucune saisie en
--    cours, puis validées une fois le résidu traité à la main.
--
--    Les tables de BROUILLON ne reçoivent volontairement PAS de CHECK :
--    un brouillon est un matériau de travail, une contrainte y bloquerait
--    une saisie en cours. Le verrou est posé à la publication (books).
-- ---------------------------------------------------------------------
alter table public.books
  drop constraint if exists books_idioma_bcp47_chk;
alter table public.books
  add constraint books_idioma_bcp47_chk
  check (idioma is null or idioma ~ '^[a-z]{2}(-[A-Z]{2})?$')
  not valid;

alter table public.authors
  drop constraint if exists authors_country_iso_chk;
alter table public.authors
  add constraint authors_country_iso_chk
  check (country is null or country ~ '^[A-Z]{2}$')
  not valid;

-- ---------------------------------------------------------------------
-- 5. Vérification (jouable sur base vide — cf. note en 00)
-- ---------------------------------------------------------------------
do $$
declare
  bad_lang    bigint;
  bad_ctry    bigint;
  bad_dlang   bigint;
  bad_dctry   bigint;
  n_orphelins bigint;
begin
  select count(*) into bad_lang from public.books
   where idioma is not null and idioma !~ '^[a-z]{2}(-[A-Z]{2})?$';
  select count(*) into bad_ctry from public.authors
   where country is not null and country !~ '^[A-Z]{2}$';
  select count(*) into bad_dlang from public.book_drafts
   where idioma is not null and btrim(idioma) <> '' and idioma !~ '^[a-z]{2}(-[A-Z]{2})?$';
  select count(*) into bad_dctry from public.author_drafts
   where country is not null and btrim(country) <> '' and country !~ '^[A-Z]{2}$';

  select count(*) into n_orphelins from public.work_expressions e
   where not exists (select 1 from public.books b where b.expression_id = e.id);

  raise notice 'CONV/01 — résidu à traiter à la main : idioma % · country % '
               '(brouillons : idioma % · country %). Expressions orphelines restantes : %.',
               bad_lang, bad_ctry, bad_dlang, bad_dctry, n_orphelins;

  if bad_lang > 20 or bad_ctry > 20 then
    raise exception 'CONV/01 — résidu anormalement élevé (idioma=%, country=%) : '
                    'la table de correspondance est incomplète, la compléter avant de rejouer.',
                    bad_lang, bad_ctry;
  end if;
end $$;

commit;

-- =====================================================================
-- Après traitement manuel du résidu ET fermeture des chemins d'écriture
-- (sélecteur de pays côté AuthorDraftForm, mapping OCR por→pt-BR),
-- valider les contraintes dans une migration séparée :
--   alter table public.books   validate constraint books_idioma_bcp47_chk;
--   alter table public.authors validate constraint authors_country_iso_chk;
-- =====================================================================
