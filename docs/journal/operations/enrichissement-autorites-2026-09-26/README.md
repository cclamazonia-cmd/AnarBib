# Enrichissement des autorités depuis Wikidata — 26/09/2026

**Demande :** Xavier, 26/09/2026 — « compléter l'ensemble des fiches auteurs (nationalité, année de naissance/mort, langue d'écriture principale) », carte blanche sur la méthode, application validée le jour même.
**Items :** backlog v34 **C4** (pays manquants) et **C8** (dates, identifiants externes).
**Appliqué par :**
- `supabase/migrations/20260926191225_autorites_langue_d_ecriture.sql` — la colonne `writing_language` (il n'y avait aucun endroit pour la langue d'écriture), dans `authors` et `author_drafts`, recopiée par `publish_author_draft` et `create_author_draft_from_author` ;
- `supabase/migrations/20260926193111_autorites_enrichies_depuis_wikidata.sql` — les 607 fiches.

## Relevé de départ (production, 26/09)

1 505 autorités, dont 1 402 sans type ; 928 sans année de naissance, 925 sans pays, 28 avec un identifiant Wikidata, aucune avec une langue d'écriture.

## Méthode

Source unique : **Wikidata** (licence CC0, API publique, coût nul, aucun modèle de langue). La spec `spec-sources-externes-autorites` veut qu'une source extérieure reste un **candidat** : la règle ci-dessous tient lieu d'« équipe », et tout ce qu'elle ne tranche pas avec certitude reste à relire, sans écriture.

Pour chacune des 1 443 fiches de personnes ou non typées (les collectivités ne sont pas traitées ici) :

1. recherche du nom dans Wikidata, restreinte aux êtres humains (`P31 = Q5`) ;
2. **nom** : une forme de la fiche (retenue, de tri retournée, variantes) doit être identique à un libellé ou alias du candidat, à l'ordre des mots près ;
3. **aucune contradiction** : années de naissance et de mort de la fiche (±1 an), et pas de naissance dans les dix ans qui précèdent la première publication de l'auteur au catalogue ;
4. **acceptée** seulement si les dates de la fiche concordent, **ou** si deux signaux indépendants la soutiennent parmi : un identifiant de bibliothèque nationale (VIAF, ISNI, BnF, LoC, BNE, SBN, GND…), un métier d'écriture (écrivain, journaliste, historien, philosophe, militant…), l'anarchisme comme idéologie déclarée. « Chercheur » seul ne compte pas : ce sont souvent des fiches créées en masse depuis ORCID ;
5. un nom porté par trois humains ou plus dans Wikidata n'est accepté qu'avec des dates concordantes.

**Champs repris** (seulement s'ils sont vides dans AnarBib — rien n'est écrasé, les noms ne sont jamais touchés) :

- **naissance, mort** : `P569`, `P570`, à l'année près ; une valeur imprécise ou contradictoire dans Wikidata est ignorée ;
- **pays** : nationalité `P27` en code ISO actuel. Plusieurs nationalités → celle du pays de naissance si elle en fait partie, sinon rien. État disparu → son successeur (`etats-historiques.json` : royaume d'Italie → IT, Empire russe → le pays de naissance s'il est l'un de ses successeurs…) ;
- **langue d'écriture** : `P6886` (langue d'écriture) fait foi ; à défaut, `P1412` n'est retenue que si elle est aussi la langue maternelle ou celle des livres de l'auteur au catalogue (seule, elle donnait l'espéranto pour Tragtenberg). Référentiel des notices : le portugais y est `pt-BR` ; une langue hors des 36 codes n'est pas écrite (Staline : géorgien, Gandhi : gujarati) ;
- **identifiants** : Wikidata, VIAF (`P214`), ISNI (`P213`) ;
- **type** : « personne », seulement si la colonne et `structured_meta.authorityType` sont vides.

Chaque fiche touchée porte sa trace dans `external_ids.wikidata_releve` : `{ qid, date, champs }`.

## Justesse

- Premier échantillon aléatoire de 60 (règle initiale) : erreurs toutes dans le groupe « un seul signal, sans dates » — Claude Bertin rattaché à un sculpteur du XVIIe siècle, Lúcia Bruno à un acteur australien, M. Kun à une astronome, George Berger (*The Story of Crass*, 2008) à un éditeur mort en 1868, Giancarlo Giannini à l'acteur. D'où la règle 4.
- Second échantillon aléatoire de 60, règle finale : **60 justes sur 60** (John Brademas est bien le député auteur d'*Anarcosindicalismo y revolución en España* ; Alice Wexler, la biographe d'Emma Goldman).
- Exclue à la main : Flor O'Squarr (Wikidata le dit mort en 1890, il signe *Les coulisses de l'anarchie* en 1892).

## Résultat

| Décision | Fiches | Écrit ? |
|---|---|---|
| acceptée | 587 | oui (sauf Flor O'Squarr) |
| déjà liée à Wikidata | 28 | champs vides complétés |
| introuvable dans Wikidata | 535 | non — seconde phase |
| ambiguë (plusieurs homonymes plausibles) | 96 | non |
| contradiction avec la fiche | 70 | non |
| à relire (un seul signal) | 88 | non |
| non corroborée | 39 | non |

Champs remplis sur 607 fiches : naissance 197, mort 110, pays 177, langue d'écriture 418, Wikidata 586, VIAF 578, ISNI 567, type 581.

`decisions.csv` donne, pour chacune des 1 443 fiches : la décision, le candidat retenu, les signaux, et pour les cas non écrits la liste des candidats avec le motif du refus (ex. `mort 1923 ≠ 1920` pour Neno Vasco). C'est la liste de travail des relectures.

## Épreuves avant de pousser

- extraction rafraîchie juste avant l'assemblage : aucune fiche modifiée depuis le premier export ;
- rejeu complet des migrations au banc (aucune fiche relevée : rien touché) ;
- copie jetable avec les 607 fiches dans leur état de production : 607 enrichies, rejouée sans changement, et refus complet si une seule fiche a changé de nom entre-temps (« 606 fiches sur 607 retrouvées »).

## Outils (trace, non exécutés par la CI)

`wd-rapprocher.mjs` (rapprochement, lecture seule, cache disque des réponses), `engendrer-migration.mjs`, `assembler-migration.cjs`, `etats-historiques.json`. Ils lisent un export des autorités par l'API publique (`authors`) et des notices (`api.catalog_books_public_v2` : auteur principal, année, langue).
