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

## Seconde phase — Library of Congress (26/09, soir)

**Demande :** Xavier, 26/09 — « applique et lance la seconde phase ». **Appliqué par** `supabase/migrations/20260926200208_autorites_liees_a_la_library_of_congress.sql`.

Source : le fichier d'autorités de la LC (`id.loc.gov`, API `suggest2`), le mieux fourni pour l'édition brésilienne et hispano-américaine (bureau de Rio). Portée : les 1 125 personnes à qui il manquait encore au moins un champ après la phase Wikidata.

Règle, plus exigeante que la première parce que les homonymes brésiliens sont nombreux :

- **vedette LC** (sans dates ni précisions entre parenthèses) identique à la forme de tri de la fiche ;
- **preuve obligatoire** : un titre de l'auteur au catalogue AnarBib cité dans les sources de la notice LC (champ 670) — le titre *principal*, avant les deux-points, car la LC cite le titre court (« Violentados, 1995 ») —, ou des dates concordantes avec la fiche. Le nom seul ne suffit jamais ;
- **années** : champ structuré 046, sinon la vedette (« Leuenroth, Edgard, 1881-1968 ») ;
- **pays** : celui du **lieu de naissance** — la LC n'a pas de champ nationalité ; la trace le dit (`country (lieu de naissance)`) ;
- **langue** : seulement si la LC n'en donne qu'une ET qu'elle est celle des livres de l'auteur au catalogue ou de son pays (la LC donne « English » à Wilhelm Reich et à Gandhi).

Résultat : **288 fiches liées** (`external_ids.lccn` + trace `lc_releve`), dont 90 avec un champ comblé : langue 85, naissance 15, mort 3, pays 8. La LC recoupe surtout Wikidata : ses auteurs datés avaient déjà leurs dates. Non retenus : 440 introuvables, 345 homonymes sans titre commun, 27 contradictions, 24 noms trop courts — liste `decisions-lc.csv`.

**Après les deux phases** (copie de banc des 1 499 fiches visibles) : 735 sans pays (49 %), 713 sans année de naissance, 503 avec une langue d'écriture, 614 liées à Wikidata, 288 à la LC. Le critère de C4 (moins de 20 % sans pays) n'est **pas atteignable par des sources d'autorité** : 668 des 735 fiches restantes ont un seul livre au catalogue — brochures, travaux universitaires brésiliens (371 en portugais) et hispano-américains (155). Déduire la nationalité de la langue ou du lieu d'édition serait une supposition, pas une donnée : non fait.

**Cas relevés pour une relecture humaine** : Cioran (langue posée : roumain, langue maternelle ; il écrit en français après 1949) ; Flor O'Squarr (exclu, dates) ; les listes des deux tableurs.

## Troisième phase — IdRef (27/09)

**Demande :** Xavier, 26/09 — « une phase 3 avec une bibliothèque brésilienne ou sud-américaine » ; relevé présenté et application validée le 27/09. **Appliqué par** `supabase/migrations/20260927091555_autorites_liees_a_idref.sql`.

**Les sources sud-américaines sont fermées à l'accès automatisé**, constaté le 27/09 : la Biblioteca Nacional do Brasil répond 403 à toute requête, navigateur compris ; la Biblioteca Nacional Mariano Moreno (Aleph) refuse ses X-Services au public (« User WWW-X denied permission ») ; VIAF, qui agrège la BN du Brésil, ne répond rien. Aucun contournement.

Source retenue : **IdRef** (ABES, autorités des bibliothèques universitaires françaises), API publique : la nationalité (UNIMARC 102), la langue (101) et les dates (103), et de nombreux auteurs brésiliens et hispano-américains traduits ou étudiés en France. **ISNI** a été sondé : dates et titres, mais ni nationalité ni langue — non retenu pour cette phase.

Règle : vedette IdRef (sans précisions) identique à la forme de tri ; preuve obligatoire — un titre de l'auteur au catalogue AnarBib, **deux mots significatifs au moins** (« Anarquistas » seul ne prouve rien), parmi les documents SUDOC liés à la notice, ou des dates concordantes ; années du 103 seulement si la vedette ne les contredit pas (Alexandre Vieira : 1884 dans la vedette, 1880 dans le 103) ; langue seulement si unique et confirmée par les livres au catalogue ou par le pays (IdRef donne « eng » à Paulo Ghiraldelli Jr.). Pays relus un par un (66).

Résultat : **187 fiches liées** (`external_ids.idref` + trace `idref_releve`), dont 164 complétées : langue 150, pays 66, naissance 33, mort 9. Non retenus : 524 introuvables, 173 non corroborés, 50 contradictions, 45 noms trop courts — liste `decisions-idref.csv`. Éprouvée sur copie de l'état de production du 27/09 : 187 appliquées, idempotente, refus si une fiche a changé.

Après les trois phases (copie de banc des 1 499 fiches visibles) : **669 fiches sans pays (~45 %)**, 680 sans année de naissance, 653 avec une langue d'écriture. Le critère de C4 reste hors de portée des sources d'autorité.

## Outils (trace, non exécutés par la CI)

`wd-rapprocher.mjs`, `loc-rapprocher.mjs` et `idref-rapprocher.mjs` (rapprochements, lecture seule, cache disque des réponses), `engendrer-migration.mjs`, `assembler-migration.cjs`, `engendrer-migration-loc.cjs`, `engendrer-migration-idref.cjs`, `etats-historiques.json`. Ils lisent un export des autorités par l'API publique (`authors`) et des notices (`api.catalog_books_public_v2` : auteur principal, année, langue).

## Quatrième phase — des propositions, plus d'écriture d'office (09/10/2026)

**Décision de Xavier du 08/10 (backlog C4)** : le pays vient d'une autorité externe quand l'identité est sûre — des dates
concordantes, ou deux signaux indépendants — et il est posé en **proposition** dans l'Atelier des autorités
(`authority_proposals`, `kind = edition`, `fields.country` et, pour Wikidata, `fields.wikidata_id`), jamais d'office.

**Relevé du 09/10** : 675 fiches sans pays (`sans-pays-2026-10-09.txt`), hors les cinq fixtures de formation. Les trois
passes de septembre sont relues sous cette règle par `c4-candidats.mjs` (Node seul, sans modèle de langue ; Wikidata
interrogé pour la nationalité `P27` des candidats retenus, `P297` pour le code ISO, `etats-historiques.json` pour les
États disparus) :

| Ce que disent les passes | Fiches |
|---|---|
| introuvables dans Wikidata (et, pour la plupart, à la LC et à IdRef) | 424 |
| aucun candidat Wikidata à deux signaux | 121 |
| absentes des passes : 51 collectivités ou congrès (hors méthode), 1 sans type, 10 personnes créées le 27/09 | 62 |
| plusieurs candidats à deux signaux (homonymes) | 22 |
| acceptées en septembre, mais Wikidata ne donne pas de nationalité | 19 |
| un candidat à deux signaux, sans nationalité ou sans code ISO | 10 |
| **un seul candidat à deux signaux, avec nationalité** | **17** |
| acceptées à la LC avec un lieu de naissance (pays lu à la main) | 4 |

Sur les 21 candidates (`propositions-2026-10-09.csv`), Flor O'Squarr reste exclu (relecture de septembre : Wikidata le
fait mourir en 1889, il signe en 1892) et Xavier a écarté six homonymes probables (Rockwell → Norman Rockwell, John Lyons,
Manuel Pérez, Hugo Garcia, Bruno Ribeiro, Paul Kenny). **Quatorze propositions** ont été ouvertes dans l'Atelier le 09/10
à 21 h 50, par `api.fn_authority_propose` sous le compte de Xavier, échéance le 16/10 — dix Wikidata (Paul Berman US,
Paul Berthelot FR, Cristina de Campos BR, Paul Carton FR, Henri Dubief FR, Brian Jackson GB, César de Oliveira PT, Jeff
Stein US, Clément Duval FR, Jaguar BR) et quatre LC (Martín Albornoz ES, Germán Ferrari AR, Miguel Rodríguez MX, Antonio
Cleber Rudy BR). Chaque motif cite la source, les signaux et les candidats écartés : le relecteur tranche.

**Ce que la règle ne peut pas donner** : 424 fiches introuvables dans les sources ouvertes, 121 sans second signal — le
critère « moins de 20 % sans pays » reste hors de portée de l'enrichissement automatique (45 % avant, 44 % si les quatorze
sont acceptées). Les refus détaillés sont dans `refus-2026-10-09.csv`.

## Cinquième phase — les onze fiches jamais passées (10/10/2026)

Les 62 fiches « absentes des passes » se lisent ainsi : 51 collectivités ou congrès (la méthode ne traite que les
personnes), 1 sans type (Piero Ferroa), 10 personnes créées le 27/09, après l'export de septembre. `wd-rapprocher.mjs`
rejoué sur ces onze (`LIMITE` par défaut, cache à part, hors dépôt) : **2 acceptées** à deux signaux — David E. Kaiser
(Q5233184, *Postmortem* 1985, historien, US) et José Luis Gutiérrez Molina (Q51862284, *Germinal* 2012, historien, ES) —,
1 à relire (Pedro Costa Musté, un seul signal), 1 ambiguë (Cristina Pereira), 7 introuvables. Les deux acceptées sont
**proposées** dans l'Atelier le 10/10 (mêmes champs, même motif) : seize propositions C4 en tout, échéance du 16 au 17/10.
