# Autorités d'Anarchief.org — enrichissement D7 (19/10/2026)

**Demande :** décision D7 de Xavier (19/10) — enrichir les 308 autorités créées le jour même depuis les notices d'Anarchief.org
(`source_label = 'Anarchief.org · import 2026-10'`, migration `20261019160041`) : 197 personnes, 111 collectifs, aucune date,
aucun pays, aucun identifiant.
**Appliqué par :** `supabase/migrations/20261019192349_les_autorites_d_anarchief_recoivent_dates_pays_et_identifiants.sql`
(fonction rejouable `private.fn_enrichir_autorites(liste, date, lot)` + l'appel pour 94 fiches), suite
`tests/sql/enrichir_autorites_tests.sql`.
**Validé par :** Xavier, 19/10 au soir, sur `PROPOSITION_enrichissement_autorites_anarchief_2026-10-19.md` (dossier de la
coordination, hors dépôt) : lots A, B, K, C et KC, écriture directe pays compris.

## Méthode

La recette du 26-27/09 (`../README.md`), rejouée sur ces fiches :

1. **Wikidata** (`wd-anarchief.mjs`, dérivé de `wd-rapprocher.mjs`) : les alias de la fiche (sauf les graphies bricolées —
   « aka », « e.a. », parenthèses) servent aussi de formes et de requêtes ; les collectifs sont cherchés hors `P31=Q5`
   et jamais acceptés d'office. Règle inchangée : nom identique, aucune contradiction, **dates concordantes OU deux
   signaux**. Ces fiches n'ayant aucune date, seule la seconde voie était ouverte.
2. **IdRef** (`idref-anarchief.mjs`, dérivé d'`idref-rapprocher.mjs`, mots vides néerlandais ajoutés), en deux passes :
   la première sur les fiches nues (preuve = un titre de la fiche parmi les documents SUDOC liés) ; la seconde
   (`ENTREE=authors-p3.json SORTIE=resultats-idref-p3.json`) après report des dates Wikidata, qui deviennent une preuve.
   Les dates d'une vedette IdRef ont aussi départagé des homonymes Wikidata (Holterman, Moulaert, Kuhn, Brian Martin,
   Dache).
3. **Relecture humaine** (`decisions-manuelles.json`) : chaque cas à un signal, ambigu ou collectif relu avec la
   description Wikidata, l'intro Wikipédia et les titres de la fiche ; motif écrit pour chacun.

Ordre des valeurs : Wikidata d'abord, IdRef pour ce qui manque (`champs_idref` dit quels champs viennent d'IdRef ; la
trace les attribue à `idref_releve`). Pays laissé vide quand les deux sources se contredisent (Clara Wichmann : DE/NL ;
Louis Adamic : SI/US) ; langue de Thom Holterman laissée vide (Wikidata : anglais).

## Résultat

| Lot | Fiches | |
|---|---|---|
| A — règle | 58 | personnes |
| B — relues, deux sources | 22 | personnes |
| C — un signal, confirmées par Xavier | 3 | Roosens, De Batselier, Krikke |
| K — collectifs relus | 9 | Wikidata, VIAF, pays |
| KC — collectifs douteux, confirmés par Xavier | 2 | NSV, De Nieuwe Komedie |
| **enrichies** | **94 / 308** | 83 personnes sur 197, 11 collectifs sur 111 |
| sans correspondance | 214 | 174 introuvables dans Wikidata ; le reste homonymes sans second signal |

Aucun des identifiants posés n'était déjà porté par une autre fiche (vérifié en production avant l'écriture ; la
fonction le refuse de toute façon).

## Fichiers

- `decisions-anarchief.csv` — les 308 fiches : lot, décision Wikidata, identifiants, valeurs, motif ou candidats écartés ;
- `decisions-manuelles.json` — la relecture humaine (B, C, K, KC, exclusions, pays et langues laissés vides) ;
- `liste-d7.json` — la liste fermée passée à la migration ;
- `iso2-valides.json` — codes pays ISO 3166-1 (les scripts de septembre le lisaient sans qu'il soit au dépôt) ;
- entrées des scripts (hors dépôt, à refaire par `execute_sql` en lecture) : `authors.json` (les 308 fiches + alias),
  `books.json` (`author_id`, `ano`, `idioma`, `titulo` des notices liées).

## Hors lot, portés à Xavier pour l'Atelier

- autorité 10212 (Isidro Guardia Abella) : alias « Gramsci » et « GRAMSCI, Antonio » à retirer (Gramsci = 11346) ;
- Agustín Souchy en double : 10304 → 10066 par `merge_author` avec aperçu.
