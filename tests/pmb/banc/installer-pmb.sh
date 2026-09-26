#!/bin/bash
# Installe PMB sur le banc sans cliquer : un POST vers tables/install_rep.php,
# avec les champs du formulaire de tables/fr/install.tpl.php (PMB 8.1).
# Charge le jeu de test fourni par PMB (data_test.sql : notices, exemplaires,
# périodiques, lecteurs FICTIFS) avec le thésaurus UNESCO et l'indexation
# décimale « 100 cases ». PMB 8.1 installe toujours en UTF-8
# (install_rep.php force $charset='utf-8').
#
# Piège (constaté le 26/09/2026) : en mode « création de base », l'installeur
# crée l'utilisateur `bibli@localhost` puis s'y reconnecte — ce qui échoue ici,
# puisque PHP et MariaDB sont dans deux conteneurs (connexion depuis une autre
# adresse que localhost). On passe donc par sa branche « base existante »
# (champ dbnamedbhost) : base et utilisateur `bibli@'%'` créés d'abord par root,
# puis l'installeur se connecte en `bibli` et écrit db_param avec ce compte.
#
# Identifiants de banc (locaux, sans rien derrière) :
#   MariaDB root / pmb-banc-root (compose.yml) ; base bibli, utilisateur bibli / bibli ;
#   gestion PMB : admin / admin (posé par minimum.sql).
set -euo pipefail
ICI="$(cd "$(dirname "$0")" && pwd)"
URL="${PMB_URL_BANC:-http://127.0.0.1:8088/pmb}"
RAPPORT="${PMB_ECHANGE_DIR:-$HOME/pmb-banc/echange}/rapport-installation.html"
mkdir -p "$(dirname "$RAPPORT")"

bash "$ICI/banc.sh" exec -T db mariadb -uroot -ppmb-banc-root -e "
  DROP DATABASE IF EXISTS bibli;
  CREATE DATABASE bibli CHARACTER SET utf8 COLLATE utf8_unicode_ci;
  CREATE USER IF NOT EXISTS 'bibli'@'%' IDENTIFIED BY 'bibli';
  GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER,
        CREATE TEMPORARY TABLES, LOCK TABLES ON bibli.* TO 'bibli'@'%';
  FLUSH PRIVILEGES;"

# Une installation précédente laisse db_param : l'installeur réécrit les deux
# fichiers, mais on les retire pour que le contrôle final soit probant.
bash "$ICI/banc.sh" exec -T web rm -f \
  /var/www/html/pmb/includes/db_param.inc.php \
  /var/www/html/pmb/opac_css/includes/opac_db_param.inc.php

curl -fsS -o "$RAPPORT" "$URL/tables/install_rep.php" \
  --data-urlencode "Submit=OK" \
  --data-urlencode "install_lang=fr_FR" \
  --data-urlencode "usermysql=bibli" \
  --data-urlencode "passwdmysql=bibli" \
  --data-urlencode "dbhost=db" \
  --data-urlencode "dbnamedbhost=bibli" \
  --data-urlencode "user=bibli" \
  --data-urlencode "passwd=bibli" \
  --data-urlencode "secretpass=banc-pmb-anarbib" \
  --data-urlencode "structure=1" \
  --data-urlencode "minimum=1" \
  --data-urlencode "essential=1" \
  --data-urlencode "data_test=1" \
  --data-urlencode "thesaurus=unesco" \
  --data-urlencode "indexint=marguerite"

# Le rapport marque chaque étape OK ou KO (cellules « OK » / « KO »).
OK=$(sed -e 's/<[^>]*>/\n/g' "$RAPPORT" | grep -cx '[[:space:]]*OK[[:space:]]*' || true)
KO=$(sed -e 's/<[^>]*>/\n/g' "$RAPPORT" | grep -cx '[[:space:]]*KO[[:space:]]*' || true)
echo "étapes OK : $OK — KO : $KO — rapport : $RAPPORT"
[ "$KO" = "0" ] && [ "$OK" -gt 0 ]
