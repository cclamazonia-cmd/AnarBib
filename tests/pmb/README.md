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

## Les autorités d'AnarBib dans PMB (H25, mesuré le 28/09/2026)

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

La marche à suivre, **dans cet ordre** (l'écran la rappelle quand on choisit ce
format) :

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
   - **« Oui » à « Tenir compte des notices d'autorités »**
     (`authorities_notices=1` ; un choix Oui/Non, « Non » par défaut ; « Take
     authority records into account » dans un PMB en anglais) ;
   - **l'origine des autorités : AnarBib** (`authorities_default_origin`) ;
   - le prêteur, le statut et la localisation des exemplaires, choisis dans ce
     formulaire (`PMB_PROPRIETAIRE`, `PMB_STATUT`, `PMB_LOCALISATION` au
     banc) : PMB ne lit pas la 995 `$a`.

   Sans cette option — et, avec elle, pour une responsabilité sans `$3` —,
   PMB rapproche les auteurs par la forme du nom et les dates
   (`auteur::import`, `classes/author.class.php` : `author_name`,
   `author_rejete`, `author_date` ; plus subdivision, lieu, ville, pays et
   numéro pour une collectivité ou un congrès) : deux homonymes sans dates, ou
   aux mêmes dates, n'en font qu'un ; une autre forme ou d'autres dates (une même
   personne avec et sans 700 `$f`) en créent un second, et aucun lien vers la
   fiche AnarBib n'est écrit. Les menus de
   PMB sont traduits (« Autorités » : « Autoridades » en pt_BR et es_ES,
   « Authorities » en en_UK et de_DE, « Responsabilità » en it_IT…).

   Au banc : `PMB_FONCTION_IMPORT=func_cpt_rameau_first_level.inc
   PMB_AUTORITES_NOTICES=1 PMB_ORIGINE=AnarBib node banc/importer-pmb.mjs …`.

Réimporter les autorités après une correction : sans 801 `$c`, PMB met toujours
la fiche à jour. Avec une date, il ne le ferait que si elle est postérieure à sa
dernière mise à jour — une correction réimportée le même jour serait ignorée en
silence (`authority_import.class.php`, `update_authority`).

Essai du 28/09 (`src/tests/essai-h25-pmb.test.js`, les 64 notices des deux
fixtures telles qu'AnarBib les garde, dans un PMB qui les avait déjà reçues et
qui n'a qu'un thésaurus ; base sauvegardée avant, restaurée après) :

| | |
|---|---|
| autorités traitées | 88 (57 noms, 31 vedettes), 0 erronée |
| notices créées | 62 sur 64 (les 2 autres, « Géo » et « Le Rat des bibliothèques », sont des périodiques que PMB avait déjà) ; 46 exemplaires |
| responsabilités rattachées à leur fiche AnarBib, par le `$3` | **61 sur 61** ; 0 auteur recréé par l'import des notices |
| catégories rattachées à une fiche AnarBib, par le libellé | **47 sur 47** |

## Réimporter dans PMB l'export tiré de la base (H27, mesuré le 29/09/2026)

Le chemin complet : les 64 notices des deux fixtures (`fixtures/`), lues par la
vraie edge function d'import, promues, révisées, publiées au banc SQL, puis
exportées par `fn_export_catalog_lote` dans l'ordre où l'écran les reçoit (par
id) et écrites par le module de l'écran Importations (« UNIMARC — ISO 2709 »,
qui range les périodiques avant les articles) — et réimportées dans un PMB
**vidé** de son jeu de test par le script de PMB
(`tables/empty_example_set.sql`). Notices, exemplaires, auteurs, éditeurs,
collections, séries, bulletins et liens sont recréés par l'import ; le
thésaurus et la table Dewey de PMB **restent**, comme dans le PMB d'une
bibliothèque : les vedettes et les indices de l'export y sont rapprochés par
leur libellé (aucune catégorie, aucun indice créé).

```bash
# 1. l'export complet, émis par la suite SQL (banc SQL reconstruit) ; rien
#    n'est écrit si la suite ne rend pas « ALLER-RETOUR-PMB OK »
bash tests/pmb/exporter-h27.sh ~/pmb-banc/echange/h27/export-h27.json
# 2. le fichier, par le chemin de l'écran
ESSAI_H27_EXPORT=~/pmb-banc/echange/h27/export-h27.json ESSAI_H27_DIR=~/pmb-banc/echange/h27 \
  npx vitest run src/tests/essai-h27-pmb.test.js
# 3. sauvegarde, vidage, import, bilans avant/après, restauration
bash tests/pmb/banc/essai-reimport-pmb.sh ~/pmb-banc/echange/h27/catalogue-h27.iso
# 4. le bilan versé au dépôt, et le tableau régénéré
cp ~/pmb-banc/echange/h27/bilan-h27.json tests/pmb/reimport-h27-bilan.json
REGENERER_COUVERTURE=1 npx vitest run src/tests/couverture-pmb.test.js
```

**Réglages de la mesure** (écrits dans le bilan) : onglet « Exemplaires
UNIMARC », fonction « Catégories RAMEAU », « Tenir compte des notices
d'autorités » : **Non**, origine « Catalogue Interne ». Aucune autorité n'est
exportée pour ces notices — une responsabilité importée n'est liée à une fiche
qu'après la révision (propositions, jamais d'office) : le fichier ne porte
aucun `$3`, PMB n'emploie ce réglage que pour une zone qui en porte un, et les
auteurs sont rapprochés par leur nom et leurs dates. Le chemin du `$3` est
celui de l'essai H25, plus haut.

**Le tableau mesuré est au § 4 de `docs/interop/couverture-pmb.md`**, engendré
depuis `tests/pmb/reimport-h27-bilan.json`. Chaque écart a sa cause :

- **+2 notices, +3 périodiques, −1 notice de bulletin** : PMB exporte deux
  « notices de bulletin » (des pseudo-notices « 1-bull », « 2-bull » : 200 `$a`
  « Notice de bulletin », 463 `lnk:bull_expl`, qui portent les exemplaires d'un
  bulletin — émises même quand le bulletin a sa notice : le 278 part ainsi deux
  fois, en « 2-bull » et en notice 60) et cette notice de fascicule (60).
  AnarBib les lit comme des fascicules de périodique, qui reviennent en notices
  de périodique — trois « Géo » et un « 278 » —, sans lien vers leur titre
  (reste de **H24** : rattacher les fascicules à leur périodique). Les deux
  exemplaires posés sur des bulletins reviennent sur ces notices.
- **Exemplaires, 46 pour 46, tous « indéterminé »** : le nombre revient, pas la
  description. À l'origine : 8 types (23 Livre, 13 indéterminé, 3 Oeuvre d'art,
  2 CD audio, 2 Périodique, 1 Cartes et plans, 1 Cédéroms, 1 DVD), 12 sections,
  23 Adultes et 9 Jeunes. La 995 que PMB exporte ne porte que les codes
  d'import du type et de la section (`$r uu $q u` quand ils ne sont pas réglés,
  le cas du banc) ; les libellés sont dans la 996, qu'AnarBib ne reprend pas.
  L'export écrit `$r uu $q u` à son tour : PMB range l'exemplaire en
  « indéterminé / indéterminé ». Sans `$r` (mesuré le 28/09), il prenait le
  premier type sans code de sa base — « Périodique », durée de prêt 8 jours.
  Propriétaire, statut et localisation sont ceux du formulaire d'import.
- **Exemplaires, avant IMP-25** : mesuré d'abord à 53. La publication donnait
  un exemplaire automatique aux 22 notices qui n'en ont pas (15 articles,
  3 périodiques, 4 monographies sans exemplaire dans PMB), et PMB refusait les
  15 posés sur des articles. Depuis **IMP-25** (décision de Xavier, 28/09), une
  notice importée d'un fichier MARC qui ne lui décrit aucun exemplaire n'en
  reçoit plus (un CSV, qui n'en décrit jamais, garde l'exemplaire automatique).
- **L'ordre du fichier** : PMB ne rattache un article à sa revue que par la
  464 de la revue (réémise, IMP-22), qu'il doit avoir lue AVANT l'article
  (`import_func.inc.php` : la 464 met l'article en attente ; un article lu
  sans rien en attente redevient une monographie). Contre-essai du 29/09 : le
  même export écrit dans l'ordre des id, sans le tri du sérialiseur, laisse
  **7 articles rattachés sur 15** (8 monographies de plus). Avec le tri :
  15 sur 15.
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
- **Dix responsabilités reçoivent une fonction** : les 10 responsabilités sans
  fonction dans PMB reviennent avec une — « Autre » (570) pour les 8
  responsabilités secondaires (702), « Auteur » (070) pour une collectivité (711)
  et un congrès (710) : l'import leur donne un rôle, l'export l'écrit en `$4`.

Le reste revient **en nombre** (responsabilités, auteurs, éditeurs, bulletins,
dépouillements, notices indexées) : le bilan compte des lignes, il ne compare
pas leur contenu. Ce qui change dans le contenu — l'adresse web des auteurs
(700 `$N`), l'adresse et le pays de l'éditeur (210 `$b`, `$z`), le propriétaire
des exemplaires (995 `$a`)… — est mesuré sous-zone par sous-zone au § 2 de
`docs/interop/couverture-pmb.md`.
