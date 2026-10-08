# Banc PMB — éprouver l'aller-retour PMB ↔ AnarBib (H14)

Un PMB réel, sur le poste, pour que « relisible par PMB » cesse d'être une
supposition. Ouvert le 26/09/2026 à la demande de DIRA (bibliothèque sous PMB,
**G15**) ; sert **H15** à **H27** du backlog v34.

- `banc/` — la recette : image PHP 8.3 + Apache, MariaDB 10.11, installation et
  mise à jour de la base, export — **tout sans cliquer**.
- `fixtures/` — des fichiers **exportés par PMB lui-même**, versés octet pour
  octet (`fixtures/.gitattributes` interdit toute conversion).

## Monter le banc

Prérequis : Docker dans WSL. Aucune archive PMB dans le dépôt : `pmb.env`
désigne la version, son URL sur la forge officielle et sa somme SHA256.

```bash
bash tests/pmb/banc/recuperer-pmb.sh      # ~/pmb-banc/dl/pmb<version>.zip, somme vérifiée
bash tests/pmb/banc/banc.sh up -d --build # projet compose « pmb-banc », http://127.0.0.1:8088/pmb
bash tests/pmb/banc/installer-pmb.sh      # base + jeu de test PMB (notices, exemplaires, périodiques)
bash tests/pmb/banc/maj-base-pmb.sh       # schéma à la version attendue par le code (v5.34 → v6.03 en 8.1.1.1)
node tests/pmb/banc/exporter-pmb.mjs "UNIMARC ISO2709" ~/pmb-banc/echange/export.iso
node tests/pmb/banc/importer-pmb.mjs fichier.iso [bilan.json]   # import de notices + exemplaires (995)
```

L'import **n'est pas idempotent** : une notice sans ISBN est recréée à chaque
passage. Sauvegarder la base avant (`mariadb-dump`), la restaurer avant de
rejouer.

Démonter : `bash tests/pmb/banc/banc.sh down` (garde la base) ou `down -v`
(repart de zéro). Le projet compose porte son propre nom : son `down -v` ne
touche jamais le stack de dev `anarbib`.

Identifiants **de banc**, locaux, ports liés à 127.0.0.1 seulement :
gestion PMB `admin` / `admin` ; MariaDB `bibli` / `bibli` (base `bibli`),
`root` / `pmb-banc-root`.

## Ce qui a été appris en montant le banc (26/09/2026)

- **Prérequis** : « Pré-requis installation serveur applicatif PMB 8.1 »
  (PMB Services, 25/02/2026) — PHP 8.3 sous Apache (mod_php), MariaDB en
  `utf8mb3`, moteur **MyISAM**, `sql_mode = ''`. Repris dans `Dockerfile`,
  `php.ini`, `mariadb.cnf`.
- **PMB 8.1 n'installe qu'en UTF-8** (`tables/install_rep.php` force
  `$charset='utf-8'`). Une base en ISO-8859-1 suppose une version plus ancienne ;
  la fixture latin-1 est donc **transcodée par `yaz-marcdump`** (longueurs ISO
  2709 recalculées), pas produite par PMB.
- **L'installeur crée `bibli@localhost`** puis s'y reconnecte : échec quand PHP
  et MariaDB sont dans deux conteneurs. `installer-pmb.sh` passe par sa branche
  « base existante » (base et utilisateur `bibli@'%'` créés d'abord).
- **Le jeu de test PMB arrive en v5.34** alors que le code attend v6.03 :
  `maj-base-pmb.sh` enchaîne les paliers de `admin/misc/alter.php`.
- **L'export** est une chaîne de pages relancées en JavaScript
  (`start_export.php` par lots de 200 → `start_import.php?noimport=1` pour la
  conversion → formulaire `folow_import.php`, `deliver=3`) ; `exporter-pmb.mjs`
  la suit.

## Ce que dit la première fixture (jeu de test PMB 8.1.1.1, 50 notices)

`fixtures/pmb-8.1.1.1_jeu-de-test.unimarc.txt` en est la lecture par
`yaz-marcdump`. Constats qui orientent H15-H19 :

| Point | Ce que PMB écrit |
|---|---|
| Leader | position 9 **blanche** (non définie en UNIMARC) |
| Encodage déclaré | `100 $a` positions 26-29 = `50` (Unicode) |
| Exemplaires | **995** : `$a`/`$c` propriétaire, `$f` code-barres, `$k` cote, `$r` type, `$q` — 33 exemplaires |
| Responsabilités | 700/701/702/710/711, rôle en **`$4`** (`070` = auteur), identifiant PMB en **`$9 id:N`** (pas `$3`) |
| Périodiques | 461/462/463/464 marqués `$9 lnk:bull`, `lnk:art`… |
| Zones présentes | 001 009 010 100 101 102 200 210 214 215 225 300 319 327 330 410 461 462 463 464 530 606 610 676 700 701 702 710 711 801 856 896 995 996 |

Formats de sortie de PMB essayés : `UNIMARC ISO2709` (`.iso`), `XML MARC`
(MARCXML **sans** espace de noms, lu par notre import), `UNIMARC PMB XML`
(`<unimarc><notice><f c="200">…` — XML **propre à PMB**, que notre import ne
reconnaît pas : **H22**).

## Les cas difficiles (14 notices fictives, `banc/cas-difficiles.marcxml.xml`)

Zine photocopié sans ISBN, grec, russe (cyrillique + translittération ISO 9),
ukrainien, arabe, chinois, collectivité et congrès, traductrice et préfacière
(`$4` 730/080), œuvre en deux tomes (461 et 200 `$h/$i`), notice à trois
exemplaires, périodique + bulletin + article dépouillé, caractères latins
difficiles (œ ’ « » € ß ł ñ č), 606 à subdivisions, 856, 330, 225, 676.
Importées dans PMB par `importer-pmb.mjs` (fonction `func_bdp`), puis
**réexportées par PMB** : `fixtures/pmb-8.1.1.1_cas-difficiles.*` est donc
ce que PMB rend de ces notices (restreint aux notices 61-74, octets intacts).

### Ce que PMB fait d'un fichier qu'il importe (mesuré le 26/09/2026)

C'est le chemin RETOUR de l'aller-retour (**H24**, **H27**) : un export
AnarBib parfait peut encore perdre de l'information en entrant dans PMB. Avec
la fonction d'import par défaut (`func_bdp`) :

- **Intact** : les écritures non latines (47 valeurs sur 52 ressortent octet
  pour octet ; les 5 autres sont des 200 `$f`, perdues pour une autre raison),
  les caractères latins difficiles, 205, 215, 300, 330, 101 (tous les `$a`),
  225/410, les rôles `$4` (070, 730, 080, 220, 340, 557).
- **Perdu** : 200 `$f`/`$g` (mentions de responsabilité), `$z`, `$h`/`$i`
  (le tome devient une « série » PMB) ; la **seconde 700** (translittération :
  PMB ne garde que la première) ; 102, 454, 510, 207, 326 ; 010 `$b` ; 856
  `$z` ; 676 `$v`.
- **Transformé** : **toutes les 606 fondues en une seule 610** (`$x/$y/$z` et
  `$2` perdus, aucune catégorie créée) ; Dewey tronquée à 5 caractères
  (`pmb_limitation_dewey`) ; les deux 200 d'une notice fusionnées en un `$a`
  « … ; … » ; 461 type `c` ressort en 410 + 461 ; ISSN de 011 vers 010 `$a` ;
  guide réécrit (niveau hiérarchique 0) ; 100 `$a` réécrit (dates, public,
  écriture du titre perdus) ; 801 `$a`/`$b` inversés.
- **Exemplaires** : les 13 × 995 ressortent (+ 13 × 996), mais **le
  propriétaire de la 995 est ignoré** — propriétaire, statut et localisation
  viennent du formulaire d'import ; les dates de dépôt/retour prennent le jour
  de l'import.
- **Ajouté** : 009, 214 (copie de la 210), 319, 896, 801 « INTERNE », des
  `$9 id:` sur 210, 225, 410, 676 et 7XX ; 001 renuméroté.

Conséquence pour l'aller-retour : il faudra dire à une bibliothèque **quelle
fonction d'import PMB employer** pour relire un export AnarBib (`func_bdp`
détruit les sujets structurés) — ou en écrire une. À instruire dans **H27**.

## Mesure de départ du parseur

Mesure de départ de notre parseur (`marc.ts`, commit `d15098cf`) sur ces
fixtures : l'ISO 2709 UTF-8 se lit (50/50) mais avec un **faux avertissement
« MARC-8 »** (leader/9 blanc) ; la variante latin-1 donne **29 notices sur 50
avec U+FFFD**, sans autre alerte (**H15**) ; le XML propre à PMB n'est pas
reconnu (**H22**).

Après H15 (même soir) : plus de faux avertissement MARC-8 en UNIMARC ; la
variante latin-1 est reconnue comme non-UTF-8, lue en Windows-1252 (supposé,
dit au run) et donne **exactement** les mêmes notices que l'UTF-8 ; le jeu
déclaré en 100 `$a` est relu et confronté à l'encodage retenu. Figé par
`src/tests/pmb-fixtures-parseur.test.js` et
`src/tests/process-partner-catalog-import-banc.test.js` (la vraie EF, nourrie
de ces fichiers).

## Les autorités d'AnarBib dans PMB (H25, mesuré les 28 et 29/09/2026)

L'écran Importations exporte, à côté des notices, les **autorités** d'une
bibliothèque en UNIMARC Autorités (ISO 2709) : les noms et les vedettes du
thésaurus liés à ses notices (et les ancêtres de ces vedettes), leurs formes
rejetées (4XX) et leurs liens (5XX), 801 `$b` « AnarBib », sans `$c` (voir
plus bas). Leur 001 est le `$3` que portent les 7XX et les 606 des notices
exportées : `AnarBib-A…` pour un nom, `AnarBib-S…` pour une vedette.

Ce qui relie, dans PMB, une notice à ces fiches :

- **une 7XX**, par son `$3` : l'import des notices, avec « Tenir compte des
  notices d'autorités », retrouve la fiche par (numéro, type, origine
  AnarBib) dans `authorities_sources` (`keep_authority_infos`). Le numéro est
  préfixé parce que PMB relance cette recherche **sans filtrer l'origine** :
  un « 12 » nu retrouverait l'auteur 12 d'une autre origine. Il ne fait
  jamais 14 caractères, longueur que PMB tronque (`format_authority_number`).
- **une 606**, par son **libellé**, pas par son `$3` :
  `func_cpt_rameau_first_level` cherche la catégorie par son libellé fr_FR
  dans le **thésaurus par défaut de PMB** (Administration > Outils >
  Paramètres > Thésaurus, `thesaurus`/`defaut`), et en crée une à la racine
  s'il n'en trouve pas. Les vedettes doivent donc être importées dans CE
  thésaurus. Deux vedettes AnarBib de même libellé deviennent une seule
  catégorie PMB, quel que soit leur `$3`.

La marche à suivre, **dans cet ordre** (l'écran la rappelle sous les formats
« UNIMARC — ISO 2709 » et « UNIMARC Autorités ») :

1. **Autorités > Import** : le fichier d'autorités, dans le thésaurus par
   défaut de PMB (`banc/importer-autorites-pmb.mjs` le choisit ; `PMB_THESAURUS`
   pour un autre).
2. **Administration > Imports > Exemplaires UNIMARC** (`sub=import_expl`, ce
   que fait `banc/importer-pmb.mjs`) — pas l'onglet voisin « Notices UNIMARC »
   (`sub=import`), qui importe les notices mais ignore les 995 sans le dire :
   `iimport_expl.php` n'appelle `traite_exemplaires()` que si
   `$sub == "import_expl"` —, avec :
   - la fonction d'import **`func_cpt_rameau_first_level`** (« Catégories
     RAMEAU ») — elle garde les 606 en catégories ; `func_bdp`, la fonction par
     défaut, les fond en une 610 ;
   - **« Oui » à « Générer les liens entre notices ? »** (`link_generate` ;
     « Non » par défaut ; `PMB_LIENS` au banc, à 1 par défaut) : sans lui, PMB
     ne lit aucune zone de lien (`iimport_expl.php` :
     `if($link_generate) recup_noticeunimarc_link` / `import_notice_link`) — ni
     bulletin, ni article rattaché à sa revue ;
   - **« Tenir compte des notices d'autorités »** (`authorities_notices` ; un
     choix Oui/Non, « Non » par défaut ; « Take authority records into
     account » dans un PMB en anglais) et **l'origine des autorités** : dans
     PMB 8.1.1.1, laisser « Non » — voir ci-dessous ;
   - le prêteur, le statut et la localisation des exemplaires, choisis dans ce
     formulaire (`PMB_PROPRIETAIRE`, `PMB_STATUT`, `PMB_LOCALISATION` au
     banc) : PMB ne lit pas la 995 `$a`.

   Les menus de PMB sont traduits (« Autorités » : « Autoridades » en pt_BR et
   es_ES, « Authorities » en en_UK et de_DE, « Responsabilità » en it_IT… ;
   « Exemplaires UNIMARC » : « Itens UNIMARC », « Ejemplares UNIMARC »,
   « UNIMARC Items »…) : l'aide de l'écran les cite dans la langue de la locale.

**Le formulaire de PMB 8.1.1.1 ne transmet pas l'origine choisie** (revue du
29/09). Celui de l'onglet « Exemplaires UNIMARC » (`$tpl_beforeupload_expl`,
`admin/import/import_func.inc.php`) engendre sa liste par
`origin::gen_combo_box("authorities")` : elle s'appelle `authorities_origin`,
alors que l'import lit `$authorities_default_origin`. `banc/importer-pmb.mjs`
envoie le champ que PMB attend — c'est ainsi que l'essai du 28/09, plus bas, a
mesuré le rattachement par le `$3` ; `PMB_COMME_LE_NAVIGATEUR=1` envoie ce
qu'un navigateur envoie. Les trois réglages, mesurés le 29/09 sur le même
fichier (autorités importées d'abord, PMB vidé, base restaurée) :

```bash
E=~/pmb-banc/echange
ESSAI_H25_NEUVES=1 ESSAI_H25_DIR=$E/h25 npx vitest run src/tests/essai-h25-pmb.test.js &&
PMB_AUTORITES_NOTICES=0 bash tests/pmb/banc/essai-reimport-pmb.sh $E/h25/notices-h25.iso $E/h25/autorites-h25.iso $E/bilans-h25-autorites-non &&
PMB_COMME_LE_NAVIGATEUR=1 bash tests/pmb/banc/essai-reimport-pmb.sh $E/h25/notices-h25.iso $E/h25/autorites-h25.iso $E/bilans-h25-comme-le-navigateur &&
bash tests/pmb/banc/essai-reimport-pmb.sh $E/h25/notices-h25.iso $E/h25/autorites-h25.iso $E/bilans-h25-origine-transmise &&
for n in h25-autorites-non h25-comme-le-navigateur h25-origine-transmise; do cp $E/bilans-$n/bilan-h27.json tests/pmb/bilans/$n.json; done
```

Le tableau est au § 3 de `docs/interop/couverture-pmb.md`, engendré depuis
`tests/pmb/bilans/h25-*.json`. Ce qu'il dit :

- dans les trois cas, chaque responsabilité rejoint un auteur que l'import des
  autorités a créé, et **aucun auteur n'est recréé** : sans le `$3`, PMB
  rapproche par la forme du nom et les dates (`auteur::import`,
  `classes/author.class.php` : `author_name`, `author_rejete`, `author_date` ;
  plus subdivision, lieu, ville, pays et numéro pour une collectivité ou un
  congrès). Deux homonymes sans dates, ou aux mêmes dates, n'en font qu'un ;
  une autre forme ou d'autres dates (une même personne avec et sans 700 `$f`)
  en créent un second ;
- avec « Oui » et l'origine **non transmise** — ce qu'obtient une bibliothèque
  qui clique —, `keep_authority_infos` ne retrouve aucune fiche, et écrit des
  liens notice → source d'autorité qui ne pointent sur rien ;
- avec « Oui » et l'origine **transmise**, chaque responsabilité est liée à sa
  fiche par le `$3`, quelle que soit la forme du nom. Il y faut un PMB dont le
  formulaire est corrigé (une ligne :
  `origin::gen_combo_box("authorities", "authorities_default_origin")`).

Pour une bibliothèque qui clique dans PMB 8.1.1.1 : laisser « Non ».

Au banc, l'outil seul : `PMB_FONCTION_IMPORT=func_cpt_rameau_first_level.inc
PMB_AUTORITES_NOTICES=1 PMB_ORIGINE=AnarBib node banc/importer-pmb.mjs …`.

Réimporter les autorités après une correction : sans 801 `$c`, PMB met toujours
la fiche à jour. Avec une date, il ne le ferait que si elle est postérieure à sa
dernière mise à jour — une correction réimportée le même jour serait ignorée en
silence (`authority_import.class.php`, `update_authority`).

Essai du 28/09 (`src/tests/essai-h25-pmb.test.js`, les 64 notices des deux
fixtures telles qu'AnarBib les garde, dans un PMB qui les avait déjà reçues et
qui n'a qu'un thésaurus ; l'origine envoyée par l'outil du banc ; base
sauvegardée avant, restaurée après) :

| | |
|---|---|
| autorités traitées | 88 (57 noms, 31 vedettes), 0 erronée |
| notices créées | 62 sur 64 (les 2 autres, « Géo » et « Le Rat des bibliothèques », sont des périodiques que PMB avait déjà) ; 46 exemplaires |
| responsabilités rattachées à leur fiche AnarBib, par le `$3` | **61 sur 61** ; 0 auteur recréé par l'import des notices |
| catégories rattachées à une fiche AnarBib, par le libellé | **47 sur 47** |

## Pour DIRA — corriger la ligne de son PMB, puis repasser « Oui » (H32, 08/10/2026)

Tant que PMB Services n'a pas repris le correctif (signalement rédigé :
`docs/interop/signalement-pmb-origine-autorites-2026-10-08.md`), une
bibliothèque qui veut que ses notices importées se lient à leurs autorités par
le `$3` peut corriger son PMB 8.1.1.1 elle-même. C'est une ligne, dans un seul
fichier, sans toucher à la base.

1. **Sauvegarder** le fichier `admin/import/import_func.inc.php` (à la racine
   de l'installation de PMB), puis l'ouvrir. La ligne 95 (dans le gabarit
   `$tpl_beforeupload_expl`, qui commence ligne 28) est :

   ```php
   ".origin::gen_combo_box("authorities")."
   ```

   La remplacer par la forme que les trois autres formulaires du module
   utilisent déjà (ligne 245 du même fichier, lignes 275 et 451 de
   `iimport_expl.php`) :

   ```php
   ".origin::gen_combo_box("authorities","authorities_default_origin")."
   ```

   Rien d'autre ne change : le libellé de la ligne 94 porte déjà
   `for='authorities_default_origin'`, et le script d'import lit cette
   variable (lignes 911 et 924). Pas de cache à vider : PHP relit le fichier.

2. **Vérifier que le champ part sous le bon nom** : ouvrir Administration >
   Imports > Exemplaires UNIMARC, inspecter la liste des origines (clic droit,
   « Inspecter ») — son attribut `name` doit être `authorities_default_origin`.

3. **Importer dans l'ordre habituel** (ci-dessus) : les autorités d'abord
   (Autorités > Import, dans le thésaurus par défaut), puis les notices avec
   la fonction `func_cpt_rameau_first_level`, « Générer les liens : Oui »,
   **« Tenir compte des notices d'autorités : Oui »** et, dans la liste,
   l'origine **AnarBib** (créée par l'import des autorités).

4. **Vérifier le résultat** sur une notice importée : ses responsabilités
   pointent vers les fiches d'autorité importées (pas vers des auteurs
   recréés) ; dans la base, `authorities_sources` lie chaque autorité à
   l'origine AnarBib et `notices_authors` ne contient aucun auteur neuf pour ce
   fichier. **Éprouvé le 08/10/2026 au banc** : le correctif posé dans le PMB
   du banc (puis retiré), l'import joué comme le navigateur
   (`PMB_COMME_LE_NAVIGATEUR=1`, le champ part sous le nom que la page
   corrigée porte) : 61 responsabilités sur 61 rattachées à leur fiche AnarBib
   par le `$3`, 61 liens notice → source d'autorité, 0 vers une source absente,
   0 auteur recréé — chiffre pour chiffre le réglage « origine transmise » du
   tableau ci-dessus (bilan `~/pmb-banc/echange/bilans-h32-navigateur-corrige`,
   non versé : il ne mesure rien que `h25-origine-transmise` ne dise déjà).

À la prochaine mise à jour de PMB, le fichier sera réécrit : si le correctif
n'y est pas encore, refaire la ligne. Sans le correctif, laisser « Non » :
avec « Oui », l'import écrit des liens vers une origine absente.

## Réimporter dans PMB l'export tiré de la base (H27, mesuré le 29/09/2026)

Le chemin complet : les 64 notices des deux fixtures (`fixtures/`), lues par la
vraie edge function d'import, passées par la détection des doublons internes au
lot, promues, révisées, publiées au banc SQL, puis exportées par
`fn_export_catalog_lote` dans l'ordre où l'écran les reçoit (par id) et écrites
par le module de l'écran Importations (« UNIMARC — ISO 2709 », qui range les
périodiques avant les articles) — et réimportées dans un PMB **vidé** de son
jeu de test par le script de PMB (`tables/empty_example_set.sql`). Notices,
exemplaires, auteurs, éditeurs, collections, séries, bulletins et liens sont
recréés par l'import ; le thésaurus et la table Dewey de PMB **restent**, comme
dans le PMB d'une bibliothèque — les vedettes et les indices de l'export y sont
rapprochés par leur libellé (aucune catégorie, aucun indice créé) —, ainsi que
ses types de documents, sections, codes statistiques et localisations.

Chaque étape arrête la recette si elle échoue :

```bash
E=~/pmb-banc/echange
# 1. l'export complet, émis par la suite SQL (banc SQL reconstruit) ; rien
#    n'est écrit si la suite ne rend pas « ALLER-RETOUR-PMB OK »
bash tests/pmb/exporter-h27.sh $E/h27/export-h27.json &&
# 2. le fichier, par le chemin de l'écran — et, pour le contre-essai, le même
#    export dans l'ordre reçu, sans ranger les périodiques avant les articles
ESSAI_H27_SANS_TRI=1 ESSAI_H27_EXPORT=$E/h27/export-h27.json ESSAI_H27_DIR=$E/h27 \
  npx vitest run src/tests/essai-h27-pmb.test.js &&
# 3. sauvegarde, vidage, import, bilans avant/après, restauration :
#    l'aller-retour, puis ses deux contre-essais
bash tests/pmb/banc/essai-reimport-pmb.sh $E/h27/catalogue-h27.iso '' $E/bilans-h27-aller-retour &&
bash tests/pmb/banc/essai-reimport-pmb.sh $E/h27/catalogue-sans-tri.iso '' $E/bilans-h27-sans-tri &&
PMB_LIENS=0 bash tests/pmb/banc/essai-reimport-pmb.sh $E/h27/catalogue-h27.iso '' $E/bilans-h27-sans-liens &&
# 4. les bilans versés tels que l'outil les écrit, et le tableau régénéré
for n in h27-aller-retour h27-sans-tri h27-sans-liens; do cp $E/bilans-$n/bilan-h27.json tests/pmb/bilans/$n.json; done &&
REGENERER_COUVERTURE=1 npx vitest run src/tests/couverture-pmb.test.js
```

**Réglages de la mesure** (écrits dans chaque bilan) : onglet « Exemplaires
UNIMARC », fonction « Catégories RAMEAU », « Générer les liens entre
notices ? » : **Oui**, « Tenir compte des notices d'autorités » : **Non**.
Aucune autorité n'est exportée pour ces notices — une responsabilité importée
n'est liée à une fiche qu'après la révision (propositions, jamais d'office) :
le fichier ne porte aucun `$3`, et les auteurs sont rapprochés par leur nom et
leurs dates. Le chemin du `$3` est celui des essais H25, plus haut.

**Les tableaux mesurés sont aux § 3 et 4 de `docs/interop/couverture-pmb.md`**,
engendrés depuis `tests/pmb/bilans/`. Chaque écart a sa cause :

- **+2 notices, +3 périodiques, −1 notice de bulletin** : PMB exporte deux
  « notices de bulletin » (des pseudo-notices « 1-bull », « 2-bull » : 200 `$a`
  « Notice de bulletin », 463 `lnk:bull_expl`, qui portent les exemplaires d'un
  bulletin — émises même quand le bulletin a sa notice : le 278 part ainsi deux
  fois, en « 2-bull » et en notice 60) et cette notice de fascicule (60).
  AnarBib les lit comme des fascicules de périodique, qui reviennent en notices
  de périodique — trois « Géo » et un « 278 » —, sans lien vers leur titre
  (reste de **H24** : rattacher les fascicules à leur périodique). Les deux
  exemplaires posés sur des bulletins reviennent sur ces notices.
- **Exemplaires, en nombre, tous « indéterminé »** : le nombre revient, pas la
  description. À l'origine : huit types de documents, douze sections, trois
  codes statistiques. La 995 que PMB exporte ne porte que les codes d'import du
  type et de la section (`$r uu $q u` quand ils ne sont pas réglés, le cas du
  banc) ; les libellés sont dans la 996, qu'AnarBib ne reprend pas. L'export
  écrit `$r uu $q u` à son tour : PMB retrouve — ou crée — le type
  « indéterminé / indéterminé », dont la durée de prêt est de 0 jour au banc :
  à régler dans PMB avant de prêter. Sans `$r` (mesuré le 28/09), PMB prenait
  le seul type sans code d'import de sa base, « Périodique ». Propriétaire,
  statut et localisation sont ceux du formulaire d'import.
- **Exemplaires, avant IMP-25** : mesuré d'abord à 53. La publication donnait
  un exemplaire automatique aux 22 notices qui n'en ont pas (15 articles,
  3 périodiques, 4 monographies sans exemplaire dans PMB), et PMB refusait les
  15 posés sur des articles. Depuis **IMP-25** (décision de Xavier, 28/09), une
  notice importée d'un fichier MARC qui ne lui décrit aucun exemplaire n'en
  reçoit plus (un CSV, qui n'en décrit jamais, garde l'exemplaire automatique).
- **L'ordre du fichier** : sous « Générer les liens entre notices ? », un
  article dont la 461 ne porte pas à la fois le titre et un volume n'est
  rattaché à sa revue que par la 464 de la revue (réémise, IMP-22), que PMB
  doit avoir lue AVANT l'article (`import_func.inc.php` : la 464 met l'article
  en attente ; un article lu sans rien en attente redevient une monographie).
  Contre-essai `h27-sans-tri` : le même export dans l'ordre des id laisse des
  articles sans revue ; rangés, ils y sont tous.
- **Sans « Générer les liens entre notices ? »** (contre-essai
  `h27-sans-liens`, le défaut du formulaire de PMB) : ni bulletin, ni
  dépouillement.
- **−1 lien de catégorie** : dans PMB, « Couverture du magazine rustica » pointe
  vers deux catégories distinctes de même libellé (« Mammifères »,
  ids 1525 et 1639) ; AnarBib garde le libellé : une seule revient.
- **−3 langues de notice, −3 langues de l'original** : AnarBib garde une langue
  par notice (« fre, por, spa » → « fr »), aucune hors des 36 du catalogue
  (« fro »), et pas la langue de l'original (101 `$c`).
- **+2 collections, −2 séries** : PMB exporte ses séries en 461 `$t` ;
  AnarBib les garde en collection (225). L'une est bien l'ensemble
  (« Chroniques de l'entraide ouvrière », tome 1) ; l'autre est le titre propre
  du tome 2 (« Des bourses du travail aux coopératives, 1871-1914 », saisi en
  200 `$i`, dont l'import dans PMB avait fait une série).
- **−2 liens entre notices** : celui de la notice de bulletin 278 vers Géo
  (l'écart H24, plus haut) et le lien tome 1 ↔ ensemble. La 462 de l'ensemble
  est réémise (IMP-22), mais PMB ne refait pas le lien.
- **Dix responsabilités reçoivent une fonction** : les responsabilités sans
  fonction dans PMB reviennent avec une — « Autre » (570) pour les huit
  responsabilités secondaires (702), « Auteur » (070) pour une collectivité (711)
  et un congrès (710) : l'import leur donne un rôle, l'export l'écrit en `$4`.

Le reste revient **en nombre** (responsabilités, auteurs, éditeurs, bulletins,
dépouillements, notices indexées) : le bilan compte des lignes, il ne compare
pas leur contenu. Ce qui change dans le contenu — l'adresse web des auteurs
(700 `$N`), l'adresse et le pays de l'éditeur (210 `$b`, `$z`), le propriétaire
des exemplaires (995 `$a`)… — est mesuré sous-zone par sous-zone au § 2 de
`docs/interop/couverture-pmb.md`.

**Ce que la preuve ne voyait pas** (revue du 29/09). La suite SQL posait le
statut des lignes à la main. Par l'écran, le rapprochement cherche les doublons
internes au lot : avec sa clé d'alors (titre + responsabilité), six des 64
notices des fixtures — « Géo » et ses deux fascicules, « Chroniques de
l'entraide ouvrière » et ses deux tomes — étaient signalées « doublon
possible », sans autre geste à l'écran que « Rejeter ». La clé prend désormais
le numéro et la date du fascicule ou du tome (migration
`le_rapprochement_distingue_le_fascicule_de_sa_revue`), et la suite passe par
la détection (T0).
