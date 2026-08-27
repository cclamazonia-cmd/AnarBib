# Journal de reprise — 27/08/2026

Trois chantiers du prompt de reprise, dans l'ordre. Ce qui suit consigne
surtout **ce qui ne s'est pas passé comme prévu** : c'est la partie utile.

---

## Chantier 0 — Installation

`npm ci` : **rc = 0**, 595 paquets, aucune divergence entre `package-lock.json`
et `package.json`. L'import de `@supabase/supabase-js` répond
(`createClient` = function) : le point d'entrée `auth-js` est réparé.
`node --check` passe sur les deux scripts `ficedl_*`.

Le travail s'est fait dans un worktree neuf `~/anarbib-wt-bologne`
(branche `claude/bologne`), pas dans `~/anarbib` — un worktree voisin
(`anarbib-wt-garde`) était déjà monté par une autre session.

**Correction au prompt :** « vérifier que `npm run deploy` fonctionne
toujours » n'a plus d'objet. Le script est une pierre tombale volontaire
depuis la bascule git-pages du 21/08 : il affiche un message et `exit 1`.
Publier = pousser sur `main`.

---

## Chantier 1 — Témoin de sauvegarde

### Les quatre points demandés étaient déjà faits

| Demande | État |
|---|---|
| Exposer `host` | fait le 20/08 (`20260820012343`) |
| Témoin réel `ACCATTONE` pour `long` et `storage` | arrivé le 26/08 |
| Purger les lignes d'amorçage | fait le 26/08 (`20260826170000`) |
| Trancher le sort de `snapshot_id` | fait : rempli depuis BG2-15, et `instantane_atteste` exposé |

Vérifié en production, pas sur parole : `ok = true`, `temoin_amorcage = false`
sur les trois flux, plus aucune ligne `amorcage-migration` dans la table.

### Mais les sauvegardes étaient bloquées

Le tir `court` du 27/08 à 19:01 a **échoué** :

```
!!! TABLES NON CLASSEES (ni court ni long connu) :
    - serial_holdings
    - serial_not_duplicate
    - serials
ERREUR: Filet declenche : classe les nouvelles tables avant de sauvegarder.
```

Les tables des périodiques, livrées le jour même. Le filet a fait exactement
son travail.

**La cause n'était pas le classement** — il était déjà commité
(`b18f7821`, « Périodiques P5 »). Elle était topographique :
`~/anarbib-ops/bg2-known-tables.txt` est un lien vers
`~/anarbib/deploy/bg2-known-tables.txt`, et **le worktree principal était
32 commits en arrière d'`origin/main`**. Le fichier servi aux sauvegardes
était donc la version d'avant.

C'est le genre de panne qui ne se voit pas en relisant le dépôt : le dépôt
avait raison. Seul le disque avait tort.

**Réparation.** Avance rapide de `~/anarbib` sur `origin/main` (arbre propre,
aucun commit local non poussé, donc sans risque pour les autres sessions).
Contrôle fait avant : entre les deux états, le **seul** changement dans toute
la chaîne d'exploitation était ces trois lignes — `anarbib-bg2.sh` est resté
identique au bit près (md5 égaux). Puis `./anarbib-bg2.sh check`
(mode sans écriture ni envoi) : « Filet OK : toutes les tables sont
classées. »

Le tir a été relancé : instantané `dc1baba3`, témoin reposé, `court` à 0,0 h.

**Ce qui serait arrivé sans cela :** le seuil de 36 h expirait le 28/08 à
05:01 UTC, soit **12 h avant** le tir programmé suivant. L'alarme aurait
sonné juste, et se serait tue toute seule le soir — le pire des scénarios,
celui qui apprend à ignorer une alarme vraie.

### Deux choses relevées au passage, non traitées

- **Trou dans les instantanés `court` les 22 et 23/08** (la rétention en
  garde 7 : 19, 20, 21, puis 24). Poste éteint, probablement — mais ce n'est
  pas vérifié.
- La leçon générale : `~/anarbib` n'est pas qu'un dépôt de travail, c'est la
  **racine d'exécution** des sauvegardes. Le laisser vieillir a un coût
  opérationnel, pas seulement un coût de confort.

---

## Chantier 2 — Import du fonds Solidaires

### Deux des trois fichiers annoncés n'existaient pas

Seuls `20260828_sujets_solidaires_ficedl.sql` et le tableur source
`Bibliothèque Solidaires - Titres.xlsx` étaient présents.
`SOLIDAIRES_import_test.csv` et `SOLIDAIRES_alignement_ficedl.csv` sont
introuvables — ni dans le dépôt, ni dans WSL, ni dans les scratchpads.
Ils ont été **reconstruits depuis le tableur**.

La reconstruction retombe sur les comptes annoncés, ce qui est rassurant sur
la méthode : **35 rubriques sur 35 retrouvées, 1685 notices, 0 orpheline**
avant la première rubrique.

### Le module d'import n'attend aucun en-tête particulier

Le prompt prévoyait « adapter les en-têtes au format réellement attendu ».
Il n'y a pas de format attendu : l'importeur fonctionne par **profil de
correspondance** (`fn_import_profile_create`), où l'on associe chaque colonne
du fichier à un champ cible. Les champs cibles sont :

```
title  subtitle  author  publisher  place  year  language
subjects  isbn  issn  edition  itemType  externalKey
```

Le CSV produit porte ces noms-là, pour que la correspondance soit immédiate.
L'outil accepte aussi le `.xlsx` directement.

### Le piège des intertitres a un second étage

Le cadrage signalait 35 rubriques déguisées en livres. Il y en a **onze de
plus**, d'une autre nature : des **titres de revue nus servant d'en-tête** à
leurs numéros, dans la queue du tableur.

```
1705 | Contretemps                    <- en-tête
1706 | Contretemps n°29 - Le défi des « migrants » ...
1707 | Contretemps n°30 - Droit du travail ...
```

Onze lignes : *Les utopiques, Cahiers de la formation syndicale, Revue
internationale, Cerises la coopérative, La révolution prolétarienne,
Réfractions, Panthères, GRESEA Echos, Casse-Rôles, Contretemps, La Commune*.

Dix se détectent par une règle sûre (titre sans auteur qui est le préfixe
strict du titre suivant). **« La Commune » (ligne 1722) y échappe** — la ligne
qui suit ne reprend pas son nom — et n'a été vue qu'à l'œil. S'il en existait
d'autres du même genre ailleurs dans le tableur, la règle ne les verrait pas
non plus.

Ces onze lignes sont **écartées** du fichier d'import et déposées à part :
ce ne sont pas des livres, ce sont des **titres de revue**, c'est-à-dire
exactement ce que le chantier des périodiques a livré aujourd'hui
(`serials`). Le lot Solidaires en est un banc d'essai involontaire.

Reste donc **1674 notices**.

### Écarts avec ce que le cadrage annonçait

| Annoncé | Mesuré | Explication |
|---|---|---|
| 114 notices sans auteur | **115** (104 après retrait des en-têtes) | l'écart d'une unité vient probablement de « La Commune », comptée ici comme notice |
| 533 sous-titres suggérés | **602** | ma règle coupe aussi sur « : » et sur les tirets longs, pas seulement sur « - » |
| 5 rubriques à coquille | **5**, confirmé | voir ci-dessous |

Les sous-titres restent **suggérés et non appliqués** : ils vivent dans une
colonne `subtitle_suggested` que l'importeur ne mappera que si on le lui
demande. `title` est intact. Les titres à numéro de périodique sont écartés
de la suggestion, comme prévu.

Les cinq coquilles sont conservées telles quelles, la correction est
**proposée** en regard, jamais appliquée :

```
Ecologie                       ->  Écologie
Economie                       ->  Économie
Education                      ->  Éducation
Amérique du nord               ->  Amérique du Nord
URSS - Pays de l'Est europen   ->  URSS - Pays de l'Est européen
```

### La contrainte « pas de bibliothèque Solidaires » tient sans effort

Vérifié dans le schéma, pas supposé :

- `book_drafts` n'a **aucune** colonne de bibliothèque obligatoire —
  `owner_library_id` et `holder_library_id` sont nulles ;
- les marqueurs de provenance demandés existent déjà : `partner_source`,
  `source_label`, `provenance_note`, `source_record_id`, `import_method` ;
- une source d'import de type dépôt se déclare par
  `fn_import_register_deposit_source(nom_du_partenaire)` et vit dans
  `ingest.partner_catalog_sources` — **ce n'est pas une bibliothèque**.

Aucune ligne ne sera écrite dans `libraries`. L'acte fédéral reste entier.

> **Correction du 28/08/2026 — la fonction citée ci-dessus ne marchait pas.**
> `fn_import_register_deposit_source` insérait `relation_status = 'active'`, un
> mot qui n'appartient pas au vocabulaire de la colonne : la contrainte
> `partner_catalog_sources_relation_status_check` n'admet que `mapeada`,
> `contatada`, `em_discussao`, `acordo_parcial`, `acordo_tecnico`,
> `importacao_autorizada`, `mutualizacao_autorizada`. Tout appel atteignant
> l'INSERT levait donc une violation de contrainte : seule la branche
> « source déjà existante » pouvait aboutir. La fonction savait retrouver une
> source, jamais en créer une.
>
> C'est pourquoi la source #17 « Bibliothèque Solidaires » a été posée à la main
> le 27/08 par un INSERT direct. Le défaut était invisible parce qu'aucune
> interface n'appelait cette RPC — la vérification ci-dessus a lu le schéma,
> pas un appel réel, et un chemin jamais emprunté n'est pas un chemin qui marche.
>
> Réparé par le paquet `20260828100000_source_depot_sans_partenaire` : le statut
> posé devient `mapeada`, le plus faible du vocabulaire, cohérent avec
> `catalog_partner_id` NULL. La RPC est désormais appelée par un vrai bouton
> (« + Nouveau·elle partenaire », mode *arquivo* de la page Importações), donc
> le chemin est emprunté.
>
> Le point à trancher ci-dessous, lui, reste entièrement ouvert.

**Un point à trancher tout de même :** cette fonction rattache la source à la
bibliothèque de celui qui l'appelle (`v_actor.library_id`). Le lot
apparaîtra donc dans l'Atelier d'une des quatre bibliothèques membres. C'est
un choix, pas une fatalité technique, et il n'est pas à moi de le faire.

### Ce qui reste à faire

Passer réellement le fichier dans l'outil — c'est-à-dire une session
connectée : téléversement, choix de la source, profil de correspondance,
dispatch. Éprouver l'importeur était **l'objet de l'exercice**, et cette
partie-là ne s'est pas encore faite.

Le SQL des 35 sujets n'a pas été joué non plus : il écrit en production, et
le prompt demande une validation explicite avant toute écriture.

---

## Chantier 3 — Patch du scraper FICEDL

Le patch s'applique proprement (`git apply` rc = 0), `node --check` passe,
et le diagnostic est juste : `getH1()` était bien appelé après les retours
précoces.

**Mais le patch, seul, ne change rien.** `title_fr` est écrit et n'est lu
nulle part. Deux obstacles, tous deux dans `scripts/ficedl_thesaurus_sync.mjs` :

1. ligne 114, le sync **écarte explicitement** les fiches sans bloc `labels` —
   commentaire à l'appui : « exclut la facette dates ». Les 158 descripteurs
   restent donc jetés, patch ou pas ;
2. lignes 71-85, la charge écrite en base ne porte pas `title_fr`. Aucune
   colonne ne l'attend.

Rabattre `title_fr` dans `labels.fr` lèverait les deux obstacles d'un coup —
et c'est précisément ce que le commentaire du patch interdit, à raison : cela
ferait croire à une couverture linguistique qui n'existe pas.

La route propre demande donc une colonne dédiée, donc une migration : ce n'est
plus un chantier de quinze minutes. Le patch reste appliqué dans le worktree,
non commité : il est nécessaire, il n'est pas suffisant.

**Conséquence sur Solidaires : aucune — je m'étais trompé.** J'avais écrit que
trois rubriques historiques (*La Commune 1871*, *Mai 1968*, *Révolution 1789*)
étaient tributaires de ce chantier. C'est faux, et je l'avais avancé sans le
vérifier.

Vérification faite le 27/08 au soir : la base compte **462 termes, dont zéro
sans libellé français**. Les trois termes utiles existaient depuis le début —
`mot338`, `mot346`, `mot335` — et ils vivent dans la facette **`geo`**
(l'histoire d'un pays), pas dans une facette de dates. Ces trois rubriques
n'étaient donc pas bloquées : elles avaient simplement été **oubliées** dans le
lot d'alignement. Corrigé le soir même, 47 liens désormais.

Ce qui reste vrai du chantier 3 : les 158 descripteurs manquants sont un
**autre ensemble**, et le compte le confirme — environ 620 termes au thésaurus,
462 en base, l'écart fait exactement 158. Ils sont **absents** de la base, et
non présents-sans-libellé comme je l'avais écrit plus haut : le filtre de la
ligne 114 ne les laisse jamais entrer. Le chantier garde donc sa raison d'être,
mais il ne débloquait rien pour Solidaires.

Seule *Divers* (127 notices) reste sans alignement, et c'est définitif : une
rubrique fourre-tout n'a pas d'équivalent dans un thésaurus.

---

## Fichiers produits

| Fichier | Contenu |
|---|---|
| `SOLIDAIRES_import_test.csv` | 1674 notices, colonnes aux noms attendus par l'importeur |
| `SOLIDAIRES_entetes_revues.csv` | les 11 titres de revue écartés |
| `SOLIDAIRES_alignement_ficedl.csv` | 48 lignes : 44 liens + les 4 rubriques sans alignement |
