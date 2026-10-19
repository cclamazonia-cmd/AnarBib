#!/usr/bin/env bash
#
# anarbib-copie-froide.sh — replique hors ligne des quatre depots restic
# (les trois distants, et depuis le 19/10/2026 le depot local du flux lourd).
#
# CE FICHIER EST LA SOURCE DE VERITE, comme le reste de deploy/ops/.
#
# ─────────────────────────────────────────────────────────────────────────────
# CE QUE C'EST, ET CE QUE CE N'EST PAS
#
# Les trois depots restic vivent chez Herbes Folles, en SFTP. C'est deja une
# copie hors du poste — mais une seule, chez un tiers, joignable par le reseau.
# Ce script en pose une seconde sur un disque qu'on debranche : le jour ou le
# compte SFTP ferme, ou une manoeuvre efface un depot, ou le reseau n'est plus
# la, il reste quelque chose.
#
# Ce n'est PAS un `restic copy`. Celui-ci recree des instantanes avec de
# NOUVEAUX identifiants : la copie cesse d'etre comparable a l'original, et on
# perd la capacite de dire « c'est le meme instantane ». Ici on replique les
# fichiers tels quels : memes identifiants, meme lignee, restauration identique.
#
# Ce n'est PAS non plus le miroir Git — voir anarbib-mirror-refresh.sh, qui
# traite `anarbib-mirror.git` et n'a rien a voir avec restic.
#
# ─────────────────────────────────────────────────────────────────────────────
# POURQUOI CE DETOUR PAR WSL PLUTOT QU'UNE COPIE DIRECTE (constate le 26/08/2026)
#
# Trois contraintes se combinent, et aucune n'est contournable sans privileges :
#
#   1. Le serveur n'autorise QUE SFTP — pas de shell. La reponse a toute
#      commande distante est « This service allows sftp connections only ».
#      Donc `rsync` par-dessus SSH est impossible : rsync a besoin d'un shell
#      a l'autre bout. C'est aussi la raison du `sftp:` dans anarbib-bg2.sh.
#   2. sshfs et rclone ne sont pas installes sur le poste. On ne peut donc pas
#      monter le distant pour le traiter comme un dossier local.
#   3. Le disque externe n'est pas monte dans WSL, et le monter demande un
#      `sudo` que l'automate n'a pas. WSL ne monte que les volumes presents a
#      son demarrage : un disque branche apres coup n'apparait pas.
#
# D'ou la sequence : on telecharge en SFTP dans WSL — le seul endroit ou la
# passphrase se trouve, donc le seul ou la verification est possible — on
# verifie, puis on recopie vers le disque depuis Windows.
#
# LA VERIFICATION EST LE COEUR DU SCRIPT, pas le telechargement. `restic check
# --read-data` lit et DECHIFFRE chaque paquet. Un `check` simple ne controle que
# le catalogue : il declarerait saine une copie dont les donnees sont illisibles.
# Une sauvegarde qu'on n'a pas relue n'est pas une sauvegarde, c'est un espoir.
#
# ─────────────────────────────────────────────────────────────────────────────
# NE CONTIENT AUCUN SECRET
#   passphrase restic -> ~/.config/restic-anarbib.pass
#   cle SSH           -> ~/.ssh/config, entree bricolage.herbesfolles.org
#
# LECTURE SEULE COTE DISTANT. Ce script ne peut pas abimer les depots d'origine :
# il ne fait que des `get`.
#
# USAGE
#   anarbib-copie-froide.sh [--vers <chemin>] [--sans-relecture] [--sans-lourd]
#
#   --vers <chemin>    recopie et revalide vers ce dossier si accessible
#                      (utile le jour ou le disque externe sera monte dans WSL ;
#                      sinon le script imprime les deux commandes a passer
#                      cote Windows)
#   --sans-relecture   saute le --read-data. A n'utiliser que pour un controle
#                      rapide : ce n'est plus une verification serieuse.
#   --sans-lourd       laisse de cote le depot local du flux lourd (19/10/2026,
#                      voir plus bas) : 51 Gio a relire, une vingtaine de minutes.
#
set -uo pipefail

HOTE="${ANARBIB_BG2_HOTE:-bricolage.herbesfolles.org}"
UTILISATEUR="${ANARBIB_BG2_USER:-anarbib}"
RACINE_DISTANTE="${ANARBIB_BG2_RACINE:-/data}"
DEPOTS="court long storage"
PASSFILE="${RESTIC_PASSWORD_FILE:-$HOME/.config/restic-anarbib.pass}"
JOUR=$(date -u +%Y-%m-%d)
BASE_LOCALE="${ANARBIB_COPIE_FROIDE_DIR:-$HOME/restic-miroir}"
DEST="$BASE_LOCALE/$JOUR"

# --- LE DEPOT LOURD (19/10/2026) ---------------------------------------------
# Depuis le 18/10, les buckets lourds (PDF, EPUB, fond de carte : ~51 Gio) sont
# sauvegardes dans un depot restic LOCAL, sur le disque E: du poste — le depot
# SFTP n'avait pas la place (deploy/ops/README.md, « flux lourd »). Ce depot
# n'avait AUCUNE copie hors du poste : c'est ce que cette section corrige.
#
# Il ne suit pas le chemin des trois autres, et c'est voulu :
#   - pas de telechargement : il est deja la. Le recopier dans $BASE_LOCALE
#     (WSL, donc C:) couterait 51 Go a un disque qui n'en a qu'une centaine ;
#   - verifie EN PLACE (check --read-data, empreintes), verrou `.bg2.lock`
#     tenu : un tir qui ecrirait pendant la lecture fausserait les empreintes ;
#   - empreintes en CACHE : un paquet restic ne change jamais une fois ecrit,
#     on ne hache donc que les nouveaux (sans cache : 51 Go relus a chaque fois) ;
#   - vers F:, une replique UNIQUE et non datee, tenue par `robocopy /MIR` :
#     seuls les nouveaux paquets passent, les paquets retires par le prune
#     disparaissent. La regle « une seule generation » (BG2-FROID-1) vise le
#     depot court et ses donnees personnelles ; celui-ci n'en porte pas.
LOURD_REPO="${BG2_LOURD_REPO:-/mnt/e/anarbib-sauvegardes/anarbib-lourd}"
VERROU="${OPS_DIR:-$HOME/anarbib-ops}/.bg2.lock"
CACHE_LOURD="$BASE_LOCALE/.empreintes-lourd.tsv"
LOURD=1

VERS=""
RELECTURE=1
while [ $# -gt 0 ]; do
  case "$1" in
    --vers) VERS="${2:-}"; shift 2 ;;
    --sans-relecture) RELECTURE=0; shift ;;
    --sans-lourd) LOURD=0; shift ;;
    -h|--help) sed -n '/^# USAGE/,/^set -uo/{/^set -uo/!p;}' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Option inconnue : $1" >&2; exit 2 ;;
  esac
done

info() { echo ">>> $*"; }
alerte() { echo "!!! $*" >&2; }

# ── Prerequis ───────────────────────────────────────────────────────────────
info "Prerequis"
command -v restic >/dev/null || { alerte "restic manquant"; exit 1; }
command -v sftp   >/dev/null || { alerte "sftp manquant"; exit 1; }
[ -r "$PASSFILE" ] || { alerte "passphrase illisible : $PASSFILE"; exit 1; }
export RESTIC_PASSWORD_FILE="$PASSFILE"

# Le distant refuse les commandes ; on teste donc l'acces par SFTP lui-meme.
if ! echo "bye" | sftp -q -o BatchMode=yes -o ConnectTimeout=30 "$UTILISATEUR@$HOTE" >/dev/null 2>&1; then
  alerte "acces SFTP impossible vers $UTILISATEUR@$HOTE"
  alerte "verifier ~/.ssh/config (entree $HOTE) et la cle qu'il designe"
  exit 1
fi
info "Acces SFTP : OK"

LIBRE_KO=$(df -Pk "$BASE_LOCALE" 2>/dev/null | awk 'NR==2{print $4}' || echo 0)
[ "${LIBRE_KO:-0}" -lt 2000000 ] && alerte "moins de 2 Go libres sous $BASE_LOCALE — a surveiller"

mkdir -p "$DEST" || { alerte "impossible de creer $DEST"; exit 1; }
cd "$DEST" || exit 1
info "Destination locale : $DEST"

# ── 1. Telechargement ───────────────────────────────────────────────────────
info "1/5 — telechargement SFTP"
for r in $DEPOTS; do
  if [ -d "$DEST/anarbib-$r" ]; then
    info "    anarbib-$r : deja present, telechargement saute"
    continue
  fi
  info "    anarbib-$r : reception…"
  sftp -q -o ConnectTimeout=30 "$UTILISATEUR@$HOTE" <<EOF >/dev/null 2>&1
get -r $RACINE_DISTANTE/anarbib-$r
bye
EOF
  if [ -d "$DEST/anarbib-$r" ]; then
    info "    anarbib-$r : $(du -sh "$DEST/anarbib-$r" | cut -f1), $(find "$DEST/anarbib-$r" -type f | wc -l) fichiers"
  else
    alerte "anarbib-$r NON RECU — on continue, mais la copie est incomplete"
  fi
done

# ── 2. Verification ─────────────────────────────────────────────────────────
ETAT=0
if [ "$RELECTURE" -eq 1 ]; then
  info "2/5 — verification integrale (restic check --read-data)"
else
  info "2/5 — verification de catalogue seule (--sans-relecture)"
fi
for r in $DEPOTS; do
  [ -d "$DEST/anarbib-$r" ] || { ETAT=1; continue; }
  if [ "$RELECTURE" -eq 1 ]; then
    RESTIC_REPOSITORY="$DEST/anarbib-$r" restic check --read-data --no-lock >/dev/null 2>&1
  else
    RESTIC_REPOSITORY="$DEST/anarbib-$r" restic check --no-lock >/dev/null 2>&1
  fi
  if [ $? -eq 0 ]; then
    n=$(RESTIC_REPOSITORY="$DEST/anarbib-$r" restic snapshots --no-lock 2>/dev/null | grep -cE '^[0-9a-f]{8} ')
    info "    anarbib-$r : OK ($n instantanes)"
  else
    alerte "anarbib-$r : VERIFICATION EN ECHEC — ne pas se fier a cette copie"
    ETAT=1
  fi
done

# ── 3. Le depot lourd, verifie en place ─────────────────────────────────────
# Empreintes ecrites dans $DEST/SHA256SUMS-lourd.txt, chemins relatifs au
# dossier PARENT du depot (« anarbib-lourd/data/… ») : c'est la disposition de
# la replique sur F: (F:\anarbib-backups\anarbib-lourd), ou elles se rejouent.
# `locks/` est exclu : restic y depose des verrous passagers, qui n'ont rien a
# faire sur un disque froid.
LOURD_NOM="$(basename "$LOURD_REPO")"
verifier_lourd() {
  local f rel k h n nouveaux=0 repris=0
  if [ ! -f "$LOURD_REPO/config" ]; then
    alerte "depot lourd introuvable : $LOURD_REPO (E: monte dans WSL ?)"
    return 1
  fi
  if [ "$RELECTURE" -eq 1 ]; then
    RESTIC_REPOSITORY="$LOURD_REPO" restic check --read-data --no-lock >/dev/null 2>&1
  else
    RESTIC_REPOSITORY="$LOURD_REPO" restic check --no-lock >/dev/null 2>&1
  fi || { alerte "$LOURD_NOM : VERIFICATION EN ECHEC — ne pas se fier a ce depot"; return 1; }
  n=$(RESTIC_REPOSITORY="$LOURD_REPO" restic snapshots --no-lock 2>/dev/null | grep -cE '^[0-9a-f]{8} ')
  info "    $LOURD_NOM : OK ($n instantanes)"

  local -A cache=()
  if [ -f "$CACHE_LOURD" ]; then
    while IFS=$'\t' read -r k h; do [ -n "$k" ] && cache["$k"]="$h"; done < "$CACHE_LOURD"
  fi
  : > "$CACHE_LOURD.tmp"
  : > "$DEST/SHA256SUMS-lourd.txt"
  while IFS= read -r -d '' f; do
    rel="$LOURD_NOM/${f#"$LOURD_REPO"/}"
    # Cle : chemin, taille, date. Un paquet restic ne change jamais une fois
    # ecrit ; si l'un des trois bouge, on rehache, on ne fait pas confiance.
    k="$rel|$(stat -c '%s|%Y' -- "$f")"
    if [ -n "${cache[$k]+x}" ]; then
      h="${cache[$k]}"; repris=$((repris + 1))
    else
      h="$(sha256sum -- "$f" | cut -d' ' -f1)"; nouveaux=$((nouveaux + 1))
    fi
    printf '%s\t%s\n' "$k" "$h" >> "$CACHE_LOURD.tmp"
    printf '%s  %s\n' "$h" "$rel" >> "$DEST/SHA256SUMS-lourd.txt"
  done < <(find "$LOURD_REPO" -path "$LOURD_REPO/locks" -prune -o -type f -print0 | sort -z)
  mv -f "$CACHE_LOURD.tmp" "$CACHE_LOURD"
  info "    $LOURD_NOM : $(wc -l < "$DEST/SHA256SUMS-lourd.txt") fichiers, $nouveaux hache(s), $repris repris du cache"
}

LOURD_OK=0
if [ "$LOURD" -eq 1 ]; then
  info "3/5 — depot lourd, verifie en place ($LOURD_REPO)"
  # Le verrou des tirs : tant qu'on lit, aucun tir n'ecrit (et un tir en cours
  # finit avant qu'on commence). 45 min d'attente au plus, comme les tirs.
  verrou_tenu=1
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$VERROU"
    if ! flock -w 2700 9; then
      alerte "un tir tient le verrou depuis 45 min : depot lourd NON verifie"
      verrou_tenu=0
    fi
  else
    alerte "flock absent : depot lourd lu SANS verrou (un tir pourrait ecrire pendant la lecture)"
  fi
  if [ "$verrou_tenu" -eq 1 ] && verifier_lourd; then LOURD_OK=1; fi
  exec 9>&-   # rend le verrou (sans rien d'autre : un `exec … 2>…` ici
              # redirigerait la sortie d'erreur de tout le script)
  [ "$LOURD_OK" -eq 1 ] || ETAT=1
else
  info "3/5 — depot lourd laisse de cote (--sans-lourd)"
fi

# ── 4. Inventaire et empreintes ─────────────────────────────────────────────
info "4/5 — inventaire et empreintes"
cd "$DEST" || exit 1
find . -type f -printf '%P\n' | grep -vE '^(INVENTAIRE|SHA256SUMS|EMPREINTE-GLOBALE|MANIFESTE)' | sort > INVENTAIRE.txt
find $(for r in $DEPOTS; do echo "anarbib-$r"; done) -type f -print0 2>/dev/null \
  | sort -z | xargs -0 sha256sum > SHA256SUMS.txt 2>/dev/null
if [ "$LOURD_OK" -eq 1 ]; then
  sha256sum SHA256SUMS.txt SHA256SUMS-lourd.txt > EMPREINTE-GLOBALE.txt
else
  rm -f SHA256SUMS-lourd.txt
  sha256sum SHA256SUMS.txt > EMPREINTE-GLOBALE.txt
fi
info "    $(wc -l < INVENTAIRE.txt) fichiers, empreinte(s) $(cut -c1-16 < EMPREINTE-GLOBALE.txt | sed 's/$/…/' | paste -sd ' ' -)"

{
  echo "COPIE FROIDE DES DEPOTS RESTIC — AnarBib"
  echo "Produite le : $(date -u +%Y-%m-%dT%H%M%SZ) (UTC)"
  echo "Source      : sftp:$UTILISATEUR@$HOTE:$RACINE_DISTANTE"
  echo "Par         : deploy/ops/anarbib-copie-froide.sh"
  echo
  echo "SANS LA PASSPHRASE, CECI N'EST QU'UN BLOC D'OCTETS."
  echo "  Dashlane, entree « restic — depot sauvegarde AnarBib », + copie hors"
  echo "  ligne, + ~/.config/restic-anarbib.pass sur le poste. Aucune"
  echo "  recuperation n'est possible sans elle : le verifier AVANT d'en avoir"
  echo "  besoin, pas le jour du sinistre."
  echo
  echo "REPLIQUE FICHIER A FICHIER, pas un 'restic copy' : memes identifiants"
  echo "d'instantanes que l'original, meme lignee, restauration identique."
  echo
  echo "LES QUATRE FLUX"
  echo "  court   : 30 tables de donnees personnelles + auth.*   retention 7 j"
  echo "  long    : schema public hors PII + secrets du Vault    retention 7/4/6"
  echo "  storage : les buckets legers (images, gabarits...)     retention 7/4/6"
  echo "  lourd   : PDF, EPUB, fond de carte (depuis le 18/10)   retention 7/4/6"
  echo "            -> PAS dans ce dossier : replique a part, F:\\anarbib-backups\\$LOURD_NOM"
  echo "               (une seule, tenue a jour par robocopy /MIR ; empreintes"
  echo "               dans SHA256SUMS-lourd.txt, ici)"
  echo
  for r in $DEPOTS; do
    echo "  --- anarbib-$r ---"
    RESTIC_REPOSITORY="$DEST/anarbib-$r" restic snapshots --no-lock 2>/dev/null | sed 's/^/    /'
    echo
  done
  if [ "$LOURD_OK" -eq 1 ]; then
    echo "  --- $LOURD_NOM (lu en place : $LOURD_REPO) ---"
    RESTIC_REPOSITORY="$LOURD_REPO" restic snapshots --no-lock 2>/dev/null | sed 's/^/    /'
    echo
  else
    echo "  --- $LOURD_NOM : NON VERIFIE A CETTE COPIE ---"
    echo
  fi
  echo "VERIFICATION FAITE AVANT COPIE"
  if [ "$RELECTURE" -eq 1 ]; then
    echo "  restic check --read-data : chaque paquet lu et dechiffre. Pas un"
    echo "  simple controle de catalogue."
  else
    echo "  restic check (catalogue seul) — la relecture des donnees a ete"
    echo "  SAUTEE. Verification incomplete."
  fi
  echo
  echo "REVALIDER PLUS TARD, SANS RIEN RETELECHARGER"
  echo "  cd <ce dossier>"
  echo "  sha256sum -c SHA256SUMS.txt          # fichier par fichier"
  echo "  sha256sum -c EMPREINTE-GLOBALE.txt   # somme d'ensemble"
  echo "  cd <ce dossier>/.. && sha256sum --quiet -c <ce dossier>/SHA256SUMS-lourd.txt"
  echo "                                       # la replique du depot lourd, a cote"
  echo
  echo "RESTAURER"
  echo "  export RESTIC_PASSWORD_FILE=<passphrase>"
  echo "  export RESTIC_REPOSITORY=<ce dossier>/anarbib-long"
  echo "  restic snapshots && restic restore latest --tag flux-long --target /tmp/x"
  echo "  Marche complete : docs/journal/operations/RUNBOOK_restauration_BG2_2026-07-01.md"
  echo
  echo "NE CONTIENT PAS"
  echo "  - la passphrase (jamais rangee avec ce qu'elle protege)"
  echo "  - le depot Git (voir la section « copie froide du depot Git » du"
  echo "    README de deploy/ops/)"
  echo "  - les secrets de la pile auto-hebergee (Archives\\SECRETS-EN-CLAIR)"
} > MANIFESTE.txt

# ── 5. Recopie vers le disque externe ───────────────────────────────────────
info "5/5 — disque externe"
# Le depot lourd, cote Windows : /mnt/e/x/y -> E:\x\y (robocopy ne lit que ca).
LOURD_WIN="$LOURD_REPO"
if [[ "$LOURD_REPO" =~ ^/mnt/([a-z])/(.*)$ ]]; then
  LOURD_WIN="$(printf '%s' "${BASH_REMATCH[1]}" | tr 'a-z' 'A-Z'):\\${BASH_REMATCH[2]//\//\\}"
fi
if [ -n "$VERS" ] && [ -d "$VERS" ] && [ -w "$VERS" ]; then
  CIBLE="$VERS/restic-$JOUR"
  info "    copie vers $CIBLE"
  mkdir -p "$CIBLE" && cp -r "$DEST/." "$CIBLE/"
  if ( cd "$CIBLE" && sha256sum -c SHA256SUMS.txt >/dev/null 2>&1 ); then
    info "    revalidation sur le disque : OK"
  else
    alerte "    revalidation sur le disque : EN ECHEC"
    ETAT=1
  fi
  if [ "$LOURD_OK" -eq 1 ]; then
    info "    replique du depot lourd vers $VERS/$LOURD_NOM"
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --delete --exclude=/locks/ "$LOURD_REPO/" "$VERS/$LOURD_NOM/"
    else
      alerte "    rsync absent : recopie sans retrait des paquets prunes (cp -ru)"
      mkdir -p "$VERS/$LOURD_NOM" && cp -ru "$LOURD_REPO/." "$VERS/$LOURD_NOM/"
    fi
    if ( cd "$VERS" && sha256sum --quiet -c "$CIBLE/SHA256SUMS-lourd.txt" >/dev/null 2>&1 ); then
      info "    revalidation du depot lourd sur le disque : OK"
    else
      alerte "    revalidation du depot lourd sur le disque : EN ECHEC"
      ETAT=1
    fi
  fi
else
  [ -n "$VERS" ] && alerte "    $VERS inaccessible en ecriture"
  cat <<TXT

    Le disque externe n'est pas joignable depuis WSL (voir l'en-tete : il n'est
    monte qu'au demarrage de WSL, et le monter demande un sudo). Passer ces
    commandes cote Windows, dans Git Bash :

      cp -r "//wsl.localhost/Ubuntu-26.04$DEST/." "/f/anarbib-backups/restic-$JOUR/"
      cd "/f/anarbib-backups/restic-$JOUR" && sha256sum -c SHA256SUMS.txt

    La seconde n'est pas optionnelle : elle prouve que ce qui est sur le disque
    est bien ce qui a passe la verification.
TXT
  if [ "$LOURD_OK" -eq 1 ]; then
    cat <<TXT

    Puis le depot lourd (51 Gio au premier passage, la semaine ecoulee
    ensuite). robocopy rend 0 a 7 quand tout va bien, 8 et au-dela en echec :

      MSYS_NO_PATHCONV=1 robocopy '$LOURD_WIN' 'F:\\anarbib-backups\\$LOURD_NOM' /MIR /XD locks /NFL /NDL /NP
      cd /f/anarbib-backups && sha256sum --quiet -c "restic-$JOUR/SHA256SUMS-lourd.txt" && echo LOURD OK

    /MIR retire aussi de F: les paquets que le prune a retires de E: : la
    replique reste un depot restic coherent, pas un empilement.
TXT
  fi
  echo
fi

echo
if [ "$ETAT" -eq 0 ]; then
  info "=== Copie froide complete et verifiee : $DEST ==="
else
  alerte "=== Copie froide INCOMPLETE ou NON VERIFIEE — lire les alertes ci-dessus ==="
fi
exit "$ETAT"
