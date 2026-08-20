-- =====================================================================
-- CONVENTIONS CATALOGRAPHIQUES — 04 · Autorités
-- Foyer : REGISTRE §37 `CONV` · CONV-1 (casse naturelle), CONV-2
--         (sort_name fait foi), CONV-6 (name_lang)
--
-- Réversible depuis conv_backup.authors_20260820 (migration 00).
-- Prérequis : migration 02 (colonne name_lang).
--
-- Ordre impératif : on corrige d'abord le POINT D'ACCÈS (A/B), puis on
-- en dérive la forme d'affichage (C) — CONV-2 : sort_name fait foi.
--
--   A. Suffixes de filiation mal pris en entrée   (8 fiches, liste close)
--   B. Particules mal prises en entrée            (8 fiches, liste close)
--   C. preferred_name reconstruit depuis sort_name (mécanique, resserré)
--   D. Double patronyme hispanique                (22 candidats, REVUE HUMAINE)
--
-- ⚠️  Vérifications en `raise warning` : cf. doctrine en tête de la 03.
-- =====================================================================

begin;

-- =====================================================================
-- A. Filho / Júnior / Neto / Sobrinho ne sont JAMAIS l'élément d'entrée.
--    Ranger sous « FILHO » revient à créer une autorité « Monsieur Fils ».
-- =====================================================================
update public.authors set sort_name = 'Sousa Filho, Alípio de'                where id = 10593 and sort_name = 'FILHO, Alípio de Sousa';
update public.authors set sort_name = 'Luz Filho, Fábio'                      where id = 10594 and sort_name = 'FILHO, Fábio Luz';
update public.authors set sort_name = 'Ramos Filho, Olavo Cabral'             where id = 10595 and sort_name = 'FILHO, Olavo Cabral Ramos';
update public.authors set sort_name = 'Franco Júnior, Hilário'               where id = 10743 and sort_name = 'JÚNIOR, Hilário Franco';
update public.authors set sort_name = 'Araujo Neto, Adalberto Coutinho de'    where id = 10952 and sort_name = 'NETO, Adalberto Coutinho de Araujo';
update public.authors set sort_name = 'Mello Neto, Candido de'                where id = 10953 and sort_name = 'NETO, Candido de Mello';
update public.authors set sort_name = 'Farinha Neto, Oscar'                   where id = 10954 and sort_name = 'NETO, Oscar Farinha';
update public.authors set sort_name = 'Aquino Júnior, Paulo Olivio Correa de' where id = 28    and sort_name = 'CORREA DE AQUINO JÚNIOR, Paulo Olivio';
-- id 10078 « REIS FILHO, Daniel Aarão » est CORRECT — « Reis Filho » est le
-- patronyme entier, pas un suffixe détaché. Ne pas toucher.

-- =====================================================================
-- B. Particules : la règle dépend de l'aire linguistique du NOM (CONV-6).
--
--    À NE PAS TOUCHER (entrées correctes) :
--      10167 Van der Walt, Lucien   — afrikaans, préfixe conservé
--      10487 De Amicis, Edmondo     — italien moderne, préfixe conservé
--      10499 Di Paolo, Pasquale     — italien moderne
--      10492 De Greef, Guillaume    — belge francophone
-- =====================================================================
update public.authors set sort_name = 'Bringel, Fabiano de Oliveira' where id = 18    and sort_name = 'DE OLIVEIRA BRINGEL, Fabiano';
update public.authors set sort_name = 'Macedo, Cátia de Oliveira'    where id = 19    and sort_name = 'DE OLIVEIRA MACEDO, Cátia';
update public.authors set sort_name = 'Sousa, Manuel Joaquim de'     where id = 10154 and sort_name = 'DE SOUSA, Manuel Joaquim';
update public.authors set sort_name = 'Carvalho, Florentino de'      where id = 10164 and sort_name = 'DE CARVALHO, Florentino';
update public.authors set sort_name = 'Jong, Rudolf de'              where id = 10180 and sort_name = 'DE JONG, Rudolf';
update public.authors set sort_name = 'Beauvoir, Simone de'          where id = 10488 and sort_name = 'DE BEAUVOIR, Simone';
update public.authors set sort_name = 'Castro, Paulo de'             where id = 10489 and sort_name = 'DE CASTRO, Paulo';
update public.authors set sort_name = 'Pereira, Almir de Lima'       where id = 10493 and sort_name = 'DE LIMA PEREIRA, Almir';

-- --- Langue du nom pour les fiches touchées (CONV-6) -----------------
update public.authors set name_lang = 'pt-BR'
 where name_lang is null and id in (18,19,28,10164,10493,10593,10594,10595,10743,10952,10953,10954,10078);
update public.authors set name_lang = 'pt'
 where name_lang is null and id in (10154);
update public.authors set name_lang = 'fr'
 where name_lang is null and id in (10488,10489,10492);
update public.authors set name_lang = 'nl'
 where name_lang is null and id in (10180);
update public.authors set name_lang = 'af'
 where name_lang is null and id in (10167);
update public.authors set name_lang = 'it'
 where name_lang is null and id in (10487,10499);

-- =====================================================================
-- C. CONV-1 + CONV-2 : casse naturelle du point d'accès, puis
--    reconstruction de la forme d'affichage.
--
--    ⚠️ On ne peut PAS « décapitaliser » automatiquement un patronyme :
--    initcap() détruirait « Van der Walt », « McKay », « D'Amico »,
--    « Ramón y Cajal ». La décapitalisation en masse est donc
--    VOLONTAIREMENT absente : elle passe par la table de revue C.3.
-- =====================================================================

-- C.1 — virgules parasites (audit A1)
update public.authors set preferred_name = 'Edson Passetti' where id = 34    and preferred_name = 'Edson, PASSETTI';
update public.authors set preferred_name = 'Ênio Silveira'  where id = 10065 and preferred_name = 'SILVEIRA, Ênio';
update public.authors set sort_name      = 'Silveira, Ênio' where id = 10065 and sort_name      = 'SILVEIRA, Ênio';

-- C.2 — forme d'affichage dérivée du point d'accès (CONV-2).
--
--   Prédicat RESSERRÉ par rapport au cadrage. La condition d'origine
--   (`preferred_name ~ ','`) attrapait TOUTE fiche dont la forme
--   d'affichage contient une virgule, sans vérifier qu'il s'agisse de la
--   forme inversée : collectivités, qualificatifs de fonction
--   (« Marcos, Subcomandante Insurgente », que D classe en 'autre'),
--   suffixes — tous auraient perdu leur preferred_name réel.
--
--   Trois gardes :
--     (1) preferred_name EST le point d'accès (à la casse près) — c'est la
--         seule définition opérationnelle de « porte encore la forme inversée » ;
--     (2) une seule virgule — un sort_name à deux virgules (dates, qualificatif)
--         serait tronqué par split_part ; ces cas partent en revue ;
--     (3) partie prénom non vide — les mononymes (Volin) sont exclus.
update public.authors
   set preferred_name = btrim(split_part(sort_name, ', ', 2) || ' ' || split_part(sort_name, ', ', 1))
 where sort_name ~ ', '
   and (length(sort_name) - length(replace(sort_name, ',', ''))) = 1
   and upper(btrim(preferred_name)) = upper(btrim(sort_name))
   and split_part(sort_name, ', ', 2) <> '';

-- C.3 — décapitalisation : proposition, pas application.
drop table if exists conv_backup.autorites_casse_a_revoir_20260820;
create table conv_backup.autorites_casse_a_revoir_20260820 as
select
  id,
  sort_name                                   as avant,
  initcap(split_part(sort_name, ', ', 1))
    || case when sort_name ~ ', '
            then ', ' || split_part(sort_name, ', ', 2)
            else '' end                       as apres_propose,
  false                                       as valide
from public.authors
where sort_name ~ '\m[A-ZÀ-Þ]{2,}\M';

comment on table conv_backup.autorites_casse_a_revoir_20260820 is
  'CONV-1 · propositions de passage en casse naturelle du point d''accès. '
  'initcap() est un POINT DE DÉPART, pas une vérité : il casse « Van der Walt », '
  '« McKay », « D''Amico », « Ramón y Cajal ». Relire avant de passer valide=true.';

-- =====================================================================
-- D. Double patronyme hispanique — REVUE HUMAINE OBLIGATOIRE.
--    3 faux positifs sur 22 dans l'échantillon audité (14 %). Aucune
--    heuristique ne distingue « Juan Carlos Mechoso » (prénom composé)
--    de « Juan Gómez Casas » (double patronyme).
-- =====================================================================
drop table if exists conv_backup.autorites_patronyme_a_revoir_20260820;
create table conv_backup.autorites_patronyme_a_revoir_20260820 (
  id            bigint primary key,
  country       text,
  avant         text,
  apres_propose text,
  verdict       text default 'a_revoir'
                check (verdict in ('a_revoir','corriger','faux_positif','autre')),
  note          text
);

insert into conv_backup.autorites_patronyme_a_revoir_20260820
  (id, country, avant, apres_propose, verdict, note) values
 (10059,'ES','MOSCARDÓ, Cristina Escrivá',   'Escrivá Moscardó, Cristina',   'corriger', null),
 (10074,'ES','CASAS, Juan Gómez',            'Gómez Casas, Juan',            'corriger', null),
 (10079,'AR','FILIPPO, Luis Di',             'Di Filippo, Luis',             'corriger', 'nom italien en Argentine'),
 (10110,'ES','TRUJILLO, Fernando López',     'López Trujillo, Fernando',     'corriger', null),
 (10212,'ES','ABELLA, Isidro Guardia',       'Guardia Abella, Isidro',       'corriger', null),
 (10384,'ES','CALVO, Agustín García',        'García Calvo, Agustín',        'corriger', null),
 (10392,'AR','CANCLINI, Néstor García',      'García Canclini, Néstor',      'corriger', null),
 (10411,'MX','CASSANOVA, Pablo González',    'González Casanova, Pablo',     'corriger', 'coquille : Cassanova → Casanova'),
 (10442,'ES','COLOMER, Eduardo Comin',       'Comín Colomer, Eduardo',       'corriger', 'accent manquant'),
 (10582,'ES','FERRER, Alejandro Tiana',      'Tiana Ferrer, Alejandro',      'corriger', null),
 (10708,'ES','IBÁÑES, Vicente Blasco',       'Blasco Ibáñez, Vicente',       'corriger', 'coquille : Ibáñes → Ibáñez'),
 (10729,'AR','JIMENEZ, Francisco Garcia',    'García Jiménez, Francisco',    'corriger', 'accents manquants'),
 (10840,'MX','MAGÓN, Ricardo Flores',        'Flores Magón, Ricardo',        'corriger', 'autorité majeure du fonds'),
 (10866,'ES','MARTÍNEZ, Beltrán Roca',       'Roca Martínez, Beltrán',       'corriger', null),
 (10901,'ES','MIRAMAR, José Luis Carretero', 'Carretero Miramar, José Luis', 'corriger', null),
 (10925,'ES','MORYÓN, Félix García',         'García Moryón, Félix',         'corriger', null),
 (11080,'MX','RAMÍREZ, Manuel Gonzalez',     'González Ramírez, Manuel',     'corriger', 'accent manquant'),
 (11128,'ES','RUIZ, Benjamín Cano',          'Cano Ruiz, Benjamín',          'corriger', null),
 (10381,'ES','CAJAL, Santiago Ramon y',      'Ramón y Cajal, Santiago',      'corriger', 'composé en « y »'),
 (33,   'UY','MECHOSO, Juan Carlos',         null,                           'faux_positif', 'Juan Carlos = prénom composé'),
 (10070,'AR','BORGES, Jorge Luis',           null,                           'faux_positif', 'Jorge Luis = prénom composé'),
 (10856,'MX','MARCOS, Sous commandant insurgé', 'Marcos, Subcomandante Insurgente', 'autre',
        'qualificatif de fonction, pas un prénom ; relève de la règle mononyme + pseudonyme (spec §6.1/6.2)')
on conflict (id) do nothing;

comment on table conv_backup.autorites_patronyme_a_revoir_20260820 is
  'CONV / audit A4 · double patronyme hispanique. Liste NON exhaustive : la '
  'détection dépend de country, nul sur 722 fiches (audit A5). Rejouer la '
  'détection après renseignement du pays. 3 faux positifs connus sur 22.';

-- =====================================================================
-- Vérification — SIGNALE, ne bloque pas
-- =====================================================================
do $$
declare
  n_suffixe   bigint;
  n_particule bigint;
  n_inverse   bigint;
  n_multi     bigint;
  n_casse     bigint;
  l_suffixe   text;
  l_particule text;
  l_multi     text;
begin
  select count(*), coalesce(string_agg(id::text, ', ' order by id), '')
    into n_suffixe, l_suffixe
    from public.authors
   where sort_name ~ '^(FILHO|JÚNIOR|JUNIOR|NETO|SOBRINHO),';

  select count(*), coalesce(string_agg(id::text, ', ' order by id), '')
    into n_particule, l_particule
    from public.authors
   where upper(sort_name) ~ '^(DE|DA|DO|DOS|DAS|DEL)\s'
     and id not in (10167,10487,10499,10492);

  -- Forme inversée résiduelle : preferred_name identique au point d'accès.
  select count(*) into n_inverse
    from public.authors
   where sort_name ~ ', '
     and upper(btrim(preferred_name)) = upper(btrim(sort_name));

  -- Points d'accès à plusieurs virgules, écartés de C.2 par construction.
  select count(*), coalesce(string_agg(id::text, ', ' order by id), '')
    into n_multi, l_multi
    from public.authors
   where (length(sort_name) - length(replace(sort_name, ',', ''))) > 1
     and upper(btrim(preferred_name)) = upper(btrim(sort_name));

  select count(*) into n_casse from conv_backup.autorites_casse_a_revoir_20260820;

  if n_suffixe > 0 then
    raise warning 'CONV/04·A — % point(s) d''accès commencent encore par un suffixe '
                  'de filiation : ids %. La liste close de l''audit ne les couvrait pas '
                  '(fiches éditées depuis, ou saisies après).', n_suffixe, l_suffixe;
  end if;

  if n_particule > 0 then
    raise warning 'CONV/04·B — % point(s) d''accès commencent encore par une particule : '
                  'ids %. Vérifier la langue du nom (CONV-6) avant de corriger : la '
                  'particule se CONSERVE en italien moderne et en afrikaans.',
                  n_particule, l_particule;
  end if;

  if n_multi > 0 then
    raise warning 'CONV/04·C.2 — % fiche(s) portent un point d''accès à plusieurs virgules '
                  'et n''ont donc PAS été dérivées : ids %. À traiter à la main.',
                  n_multi, l_multi;
  end if;

  raise notice 'CONV/04 — OK : suffixes et particules traités, formes d''affichage dérivées. '
               'Reste % forme(s) inversée(s) · % autorités proposées à la revue de casse · '
               '22 au contrôle de double patronyme.', n_inverse, n_casse;
end $$;

commit;

-- =====================================================================
-- SUITE, en migrations séparées APRÈS revue humaine. Ne pas décommenter
-- ici, ne pas scripter de passage en masse à valide=true (REGISTRE §37).
--
--   -- décapitalisation validée
--   update public.authors a set sort_name = r.apres_propose
--     from conv_backup.autorites_casse_a_revoir_20260820 r
--    where r.id = a.id and r.valide and a.sort_name = r.avant;
--
--   -- double patronyme validé
--   update public.authors a set sort_name = r.apres_propose
--     from conv_backup.autorites_patronyme_a_revoir_20260820 r
--    where r.id = a.id and r.verdict = 'corriger'
--      and r.apres_propose is not null and a.sort_name = r.avant;
--
--   -- puis re-dériver preferred_name (CONV-2) sur les fiches touchées.
-- =====================================================================
