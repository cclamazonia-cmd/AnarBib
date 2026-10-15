#!/usr/bin/env bash
# =============================================================================
# AnarBib — semer les ressources du réseau dans le Storage de CETTE instance
# =============================================================================
# Les trois manuels (src/lib/docLinks.js) et le thème `default` vivent dans le
# bucket `library-ui-assets` de la prod. Une instance auto-hébergée ne les a
# pas : le bouton « Manuel » répondait 404 sur la VM d'essai du camarade
# (ASR2026), et un manifeste de thème posé à la main pour faire taire un autre
# 404 rendait l'interface illisible (ticket #35, 15/10/2026).
#
# Décision de Xavier (15/10/2026) : chaque instance garde SA copie, au même
# chemin que la prod (docLinks.js et theme.js ne changent pas), semée depuis une
# release Codeberg du dépôt — jamais depuis le Storage de la prod : le but d'une
# instance auto-hébergée est de ne dépendre de personne.
#
# La liste et les empreintes sont épinglées dans deploy/ressources-reseau.json.
# Pour chaque objet : téléchargement depuis la release, contrôle sha256 (un
# fichier dont l'empreinte diffère n'est JAMAIS versé), dépôt dans le Storage
# local (upsert), relecture et nouveau contrôle de l'empreinte servie. Un objet
# déjà semé avec la même empreinte, et toujours servi, est laissé tel quel :
# le script est rejouable à chaque deploy.sh.
#
# Appelé par : bootstrap.sh (après les buckets), install.sh, deploy.sh.
# Sans réseau, il sort en 1 sans rien casser : l'application tourne sans
# manuels, et le thème retombe sur theme-base.css.
#
#   deploy/scripts/ressources-reseau.sh            # semer ce qui manque
#   deploy/scripts/ressources-reseau.sh --force    # tout reverser
#
# Variables (essai hors de la pile compose, par exemple sur `supabase start`) :
#   ANARBIB_STORAGE_URL   défaut http://storage:5000 (vu depuis le conteneur caddy)
#   ANARBIB_STORAGE_EXEC  défaut « docker compose exec -T caddy » ; vide = curl de l'hôte
#   ANARBIB_SERVICE_KEY   défaut SERVICE_ROLE_KEY de deploy/.env
# =============================================================================
set -uo pipefail

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LISTE="$DEPLOY_DIR/ressources-reseau.json"
ETAT="$DEPLOY_DIR/.ressources-reseau.etat"
CACHE="$DEPLOY_DIR/.ressources-cache"
FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

STORAGE_URL="${ANARBIB_STORAGE_URL:-http://storage:5000}"
if [ "${ANARBIB_STORAGE_EXEC+defini}" = "defini" ]; then
  EXEC="$ANARBIB_STORAGE_EXEC"
else
  EXEC="docker compose exec -T caddy"
fi
CLE="${ANARBIB_SERVICE_KEY:-}"
if [ -z "$CLE" ] && [ -f "$DEPLOY_DIR/.env" ]; then
  CLE="$(grep -E '^SERVICE_ROLE_KEY=' "$DEPLOY_DIR/.env" | head -1 | cut -d= -f2- | tr -d '"'"'"'\r')"
fi
if [ -z "$CLE" ]; then
  echo "✗ Clé de service introuvable (SERVICE_ROLE_KEY dans deploy/.env)."
  exit 1
fi
for outil in curl sha256sum node; do
  command -v "$outil" >/dev/null 2>&1 || { echo "✗ $outil introuvable."; exit 1; }
done

cd "$DEPLOY_DIR"
mkdir -p "$CACHE"
touch "$ETAT"

# curl côté Storage : dans le conteneur caddy (réseau interne de la pile), ou sur l'hôte.
# shellcheck disable=SC2086
scurl() { $EXEC curl "$@"; }

# La liste : fichier, bucket, chemin, type, sha256 — une ligne par objet.
LIGNES="$(node -e '
  const l = require(process.argv[1]);
  const base = `${l.depot}/releases/download/${l.release}/`;
  console.log(base);
  for (const o of l.objets) console.log([o.fichier, o.bucket, o.chemin, o.type, o.sha256].join("\t"));
' "$LISTE")" || { echo "✗ $LISTE illisible."; exit 1; }
BASE="$(printf '%s\n' "$LIGNES" | head -1)"

encoder() { node -e 'process.stdout.write(process.argv[1].split("/").map(encodeURIComponent).join("/"))' "$1"; }

KO=0; VERSES=0; DEJA=0
while IFS=$'\t' read -r fichier bucket chemin type sha; do
  [ -n "$fichier" ] || continue
  cle_etat="$bucket/$chemin"
  url_objet="$STORAGE_URL/object/public/$bucket/$(encoder "$chemin")"

  if [ "$FORCE" = "0" ] && grep -qxF "$cle_etat	$sha" "$ETAT"; then
    code="$(scurl -s -o /dev/null -w '%{http_code}' -r 0-0 "$url_objet" || echo 000)"
    if [ "$code" = "200" ] || [ "$code" = "206" ]; then
      DEJA=$((DEJA + 1)); continue
    fi
  fi

  local_f="$CACHE/$fichier"
  if [ ! -f "$local_f" ] || [ "$(sha256sum "$local_f" | cut -d' ' -f1)" != "$sha" ]; then
    if ! curl -fsSL --retry 3 --max-time 900 -o "$local_f.part" "$BASE$fichier"; then
      echo "✗ $fichier : téléchargement impossible ($BASE$fichier)"; rm -f "$local_f.part"; KO=1; continue
    fi
    mv "$local_f.part" "$local_f"
  fi
  recu="$(sha256sum "$local_f" | cut -d' ' -f1)"
  if [ "$recu" != "$sha" ]; then
    echo "✗ $fichier : empreinte $recu ≠ $sha attendue — rien n'est versé."
    rm -f "$local_f"; KO=1; continue
  fi

  code="$(scurl -s -o /dev/null -w '%{http_code}' -X POST \
      -H "Authorization: Bearer $CLE" -H "apikey: $CLE" \
      -H "x-upsert: true" -H "Content-Type: $type" -H "Cache-Control: no-cache" \
      --data-binary @- "$STORAGE_URL/object/$bucket/$(encoder "$chemin")" < "$local_f" || echo 000)"
  if [ "$code" != "200" ]; then
    echo "✗ $chemin : dépôt refusé (HTTP $code)"; KO=1; continue
  fi

  servi="$(scurl -s "$url_objet" | sha256sum | cut -d' ' -f1)"
  if [ "$servi" != "$sha" ]; then
    echo "✗ $chemin : l'objet servi n'a pas l'empreinte attendue ($servi)"; KO=1; continue
  fi
  grep -vF "$cle_etat	" "$ETAT" > "$ETAT.tmp" || true
  printf '%s\t%s\n' "$cle_etat" "$sha" >> "$ETAT.tmp"
  mv "$ETAT.tmp" "$ETAT"
  echo "✓ $chemin"
  VERSES=$((VERSES + 1))
done < <(printf '%s\n' "$LIGNES" | tail -n +2)

if [ "$KO" = "0" ]; then
  echo "✓ Ressources du réseau : $VERSES versée(s), $DEJA déjà à jour."
else
  echo "⚠ Ressources du réseau incomplètes ($VERSES versée(s), $DEJA à jour) — relancer deploy/scripts/ressources-reseau.sh"
fi
exit "$KO"
