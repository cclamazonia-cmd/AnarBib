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
