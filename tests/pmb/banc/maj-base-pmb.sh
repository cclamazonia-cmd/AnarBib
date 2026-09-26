#!/bin/bash
# Monte le schéma de la base PMB à la version attendue par le code
# (Administration > Outils > Mise à jour de la base, sans cliquer).
# Le jeu de test de PMB 8.1.1.1 arrive en v5.34 ; le code attend v6.03.
# alter.php enchaîne des paliers : chaque page propose le suivant dans un
# lien « alter.php?categ=alter&sub=&action=<palier> ». On suit jusqu'à ce
# qu'il n'y en ait plus, avec un plafond pour ne jamais boucler.
set -euo pipefail
ICI="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$ICI/session-pmb.sh"
JOURNAL="$(dirname "$PMB_COOKIES")/maj-base.log"
: > "$JOURNAL"
action="lancement"
for i in $(seq 1 200); do
  page=$(curl -fsS -b "$PMB_COOKIES" -c "$PMB_COOKIES" \
    "$PMB_URL_BANC/admin/misc/alter.php?categ=alter&sub=&action=$action")
  echo "== palier $i action=$action" >> "$JOURNAL"
  echo "$page" | sed -e 's/<[^>]*>/ /g' | tr -s ' ' | grep -iE 'error may be fatal|version|v[0-9]\.[0-9]' >> "$JOURNAL" || true
  if echo "$page" | grep -qi 'error may be fatal'; then
    echo "palier $action : erreur signalée (voir $JOURNAL)" >&2
  fi
  suivant=$(echo "$page" | grep -oE 'action=[^"&]+' | sed 's/action=//' | tail -1 || true)
  if [ -z "$suivant" ] || [ "$suivant" = "$action" ]; then break; fi
  action="$suivant"
done
bash "$ICI/banc.sh" exec -T db mariadb -ubibli -pbibli bibli -N -e \
  "select valeur_param from parametres where type_param='pmb' and sstype_param='bdd_version'"
