# Autorités d'Anarchief.org — passe NTA (C33, 22/10/2026)

**Demande :** C33 — relire et enrichir les autorités créées pour Anarchief.org. La passe D7 du 19/10
(`../anarchief-2026-10-19/`, Wikidata puis IdRef) en avait enrichi 94 sur 308 ; restaient **214**
fiches sans identifiant (114 personnes, 100 collectifs).
**Appliqué par :** `supabase/migrations/20261022190340_c33_le_nta_troisieme_source_des_autorites.sql`
— `private.fn_enrichir_autorites` apprend la source `nta`, puis l'appel pour 24 fiches. Suite
`tests/sql/c33_source_nta_tests.sql`.

## La source

Le **NTA** (*Nederlandse Thesaurus van Auteursnamen*) de la Bibliothèque royale des Pays-Bas, sous CC0,
sur le SPARQL `https://data.bibliotheken.nl/sparql`. Une fiche de personne
(`http://data.bibliotheken.nl/id/thes/p…`) porte `schema:familyName`, `schema:givenName`,
`rdfs:label` (« Nom, Prénoms (dates) »), `schema:birthDate`, `schema:deathDate`,
`schema:nationality`, `schema:sameAs` (Wikidata, VIAF, ISNI), et ses titres au catalogue national
(NBT) la désignent par `schema:author` ou `schema:contributor`. Requêtes par valeur exacte : 0,15 s ;
un `FILTER(CONTAINS(…))` sur les noms dépasse les 58 s de la passerelle — ne jamais filtrer en texte.

## La règle

Celle de C4 (08/10), inchangée : **dates concordantes OU deux signaux**, un seul candidat. Ces fiches
n'ont aucune date ; les deux signaux sont donc :

1. le **nom** : nom de famille identique (particule comprise, « van Houten » / « Houten »), prénoms
   compatibles (une initiale couvre un prénom, un prénom écrit doit être identique) ;
2. un **titre** : la forme courte d'un titre de nos notices (avant « : », « . », « , ») égale à un
   titre de la personne à la KB, ou contenue dans lui à partir de 15 caractères.

## Résultat (114 personnes)

| Décision | Fiches | |
|---|---|---|
| deux signaux, relues une à une | **24** | appliquées (8 avec un Wikidata tiré des liens du NTA) |
| un seul signal (nom, sans titre commun) | 24 | **non appliquées** — dans la file de revue de l'Atelier |
| homonymes sans titre commun | 9 | non appliquées |
| sans correspondance au NTA | 55 | |
| sans forme exploitable (« Doctress Neutopia », « Van den Dungen ») | 2 | |

Les collectifs ne sont pas au NTA. Chaque fiche appliquée garde sa trace :
`external_ids.nta` et `nta_releve { nta, date, lot, preuve, champs }` — **tous** les champs y sont
attribués au NTA, Wikidata compris, puisque Wikidata n'a pas été consulté ; pas de `wikidata_releve`.

## Fichiers

- `nta-anarchief.py` — l'outil (entrée : `authors.json`, les 214 fiches avec les titres de leurs
  notices, à refaire par une lecture en base) ;
- `decisions-nta.csv` — les 114 personnes : décision, fiche NTA, vedette, dates, titres communs ou
  candidats écartés ;
- `liste-c33.json` — la liste fermée passée à la migration.
