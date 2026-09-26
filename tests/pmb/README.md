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
```

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

Mesure de départ de notre parseur (`marc.ts`, commit `d15098cf`) sur ces
fixtures : l'ISO 2709 UTF-8 se lit (50/50) mais avec un **faux avertissement
« MARC-8 »** (leader/9 blanc) ; la variante latin-1 donne **29 notices sur 50
avec U+FFFD**, sans autre alerte (**H15**) ; le XML propre à PMB n'est pas
reconnu (**H22**).
