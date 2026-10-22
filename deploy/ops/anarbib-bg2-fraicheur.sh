#!/usr/bin/env bash
#
# anarbib-bg2-fraicheur.sh — controle de fraicheur des flux #BG2 (quatre, cinq avec le restreint)
#
# CE FICHIER EST LA SOURCE DE VERITE — versionne. `~/anarbib-ops/` n'en a qu'un
# lien symbolique. Voir deploy/ops/README.md.
#
# --------------------------------------------------------------------------
# CE QU'IL FAIT
#   Ouvre les trois depots restic, lit la date du DERNIER SNAPSHOT de chaque
#   flux, la compare a l'intervalle attendu, et pose un drapeau lisible a
#   l'ouverture du terminal si un flux a pris du retard.
#   Il ne sauvegarde rien lui-meme, ne supprime rien, ne touche ni a la base
#   ni aux depots. Un seul geste depuis le 30/09/2026 (I24) : il RELANCE le
#   service d'un flux interrompu ou en retard (voir « RELANCE » plus bas).
#
# POURQUOI IL EXISTE (21/08/2026)
#   Le flux storage est reste ONZE JOURS sans sauvegarder — du 09/08 au 20/08 —
#   sans que personne le sache. Le tir du 16/08 a ete tue au bout de 20 s par
#   l'extinction de la machine, et la notification `OnFailure=` n'a pas pu
#   partir : systemd refuse d'enfiler un job de notification pendant un arret
#   ("basic.target has 'stop' job queued"). L'alerte est morte avec ce qu'elle
#   devait signaler.
#
#   C'est le defaut de forme des trois gardes existantes :
#     - `OnFailure=`                    voit les ERREURS, pas les silences,
#                                       et se tait quand la cause est l'arret ;
#     - le temoin de vie (BG2-16)       part du poste : un poste eteint n'envoie
#                                       ni succes ni echec ;
#     - fn_backup_heartbeat_status()    voit tres bien le silence, mais depuis
#                                       la base, et ne parle a personne qui soit
#                                       assis devant la machine.
#
#   Celle-ci regarde depuis le troisieme point de vue : le poste, au reveil.
#
# POURQUOI IL LIT LE DEPOT ET NON LA TABLE DES TEMOINS
#   La sonde `fn_backup_heartbeat_status()` surveille deja les temoins, et bien.
#   La refaire ici ne donnerait qu'un seul temoin lu deux fois. Or un temoin dit
#   « le script a cru reussir » ; un snapshot dit « la donnee est la ». Ce sont
#   deux affirmations differentes : un `restic backup` peut rendre 0 et le depot
#   etre illisible a la relecture. Deux temoins independants valent mieux qu'un
#   seul consulte depuis deux endroits.
#
# CE QU'IL FAIT QUAND IL NE PEUT PAS REGARDER
#   Un depot injoignable n'est PAS un flux en retard : on ne crie pas au loup
#   parce qu'on n'a pas pu ouvrir les yeux. Mais ne rien dire du tout
#   reintroduirait exactement le silence qu'on corrige. Le script garde donc la
#   date de sa derniere lecture REUSSIE : au-dela de MAX_AVEUGLE_H sans avoir pu
#   lire un depot, l'impossibilite de verifier devient elle-meme l'alerte.
#
# Sorties : 0 = tout frais · 1 = au moins un flux en retard · 3 = aveugle trop
#           longtemps · 4 = disque du flux lourd presque plein (19/10/2026) ·
#           5 = replique hors ligne trop vieille (22/10/2026) ·
#           2 = erreur d'usage/prerequis.
# --------------------------------------------------------------------------
set -euo pipefail

OPS_DIR="${OPS_DIR:-$HOME/anarbib-ops}"
FLAG="$OPS_DIR/.fraicheur-alerte"          # lu par ~/.bashrc a chaque terminal
VU="$OPS_DIR/.fraicheur-derniere-lecture"  # horodatage epoch de la derniere lecture reussie

RESTIC_BASE="${RESTIC_BASE:-sftp:anarbib@bricolage.herbesfolles.org:/data}"
export RESTIC_PASSWORD_FILE="${RESTIC_PASSWORD_FILE:-$HOME/.config/restic-anarbib.pass}"

FLUX=(court long storage lourd)

# Le flux restreint (prepare le 22/10/2026, README « Le flux restreint ») n'est
# juge qu'une fois actif, c'est-a-dire son minuteur active. Avant, son depot
# n'existe pas : le juger ferait dire « injoignable » chaque jour d'un flux qui
# n'a jamais tire — le bruit qu'on apprend a ignorer.
if "${SYSTEMCTL:-systemctl}" --user is-enabled --quiet anarbib-backup-restreint.timer 2>/dev/null; then
  FLUX+=(restreint)
fi

# Le flux lourd (18/10/2026) a son depot sur un disque du poste, pas chez Herbes
# Folles. MEME chemin que LOURD_REPO dans anarbib-bg2.sh, meme variable pour le
# deplacer. Il finit par `anarbib-lourd`, comme les depots distants.
DEPOT_lourd="${BG2_LOURD_REPO:-/mnt/e/anarbib-sauvegardes/anarbib-lourd}"
depot_de() {
  local var="DEPOT_$1"
  printf '%s' "${!var:-$RESTIC_BASE/anarbib-$1}"
}

# Seuils en heures. ALIGNES SUR public.fn_backup_heartbeat_status() : les deux
# gardes doivent porter le meme jugement, sinon on passe son temps a se demander
# laquelle a raison. Si tu changes ici, change la-bas (et l'inverse).
#   court   quotidien  -> 36 h  (un jour saute, pas deux)
#   long    hebdo      -> 9 j   (une semaine sautee, plus la marge du dimanche)
#   storage hebdo      -> 9 j
#   lourd   hebdo      -> 9 j
#   restreint hebdo    -> 9 j  (22/10/2026 ; la sonde en base ne le juge qu'a
#                               son activation, par sa migration)
SEUIL_court=36
SEUIL_long=216
SEUIL_storage=216
SEUIL_lourd=216
SEUIL_restreint=216

# Age au-dela duquel un marqueur « tir en cours » signale un tir MORT et non un
# tir qui travaille. Aligne sur la regle `interrompu` de la sonde en base (60 min),
# pour la meme raison que les seuils ci-dessus : deux gardes qui jugeraient
# differemment feraient perdre du temps a se demander laquelle a raison.
# Le seuil ne sert qu'aux marqueurs SANS numero de processus (anciens) : un
# marqueur qui en porte un est juge sur la vie du processus, quelle que soit la
# duree du tir — c'est ce qui laisse le flux lourd travailler trois heures.
SEUIL_INTERROMPU_MIN="${SEUIL_INTERROMPU_MIN:-60}"

# Au-dela de ce delai sans avoir pu LIRE les depots, l'aveuglement devient une
# alerte a part entiere. Trois jours : assez pour absorber un voyage ou une
# coupure, trop peu pour qu'un depot mort passe une semaine inapercu.
MAX_AVEUGLE_H="${MAX_AVEUGLE_H:-72}"

# --- PLACE SUR LES DISQUES DU FLUX LOURD (19/10/2026) ------------------------
# Le flux lourd ecrit sur deux disques du poste : le miroir (D:) et le depot
# (E:). Rien ne disait quand ils se remplissent : le tir echouerait le jour ou,
# et seulement ce jour-la. La semaine du 11/10 a verse 18 Go de PDF ; 50 Go de
# marge, c'est donc environ trois semaines au pire rythme vu, une a deux mois
# au rythme ordinaire — le temps de trouver de la place, pas d'eteindre un feu.
# Un disque absent n'est pas juge ici : le depot illisible le dit deja (??).
PLACE_MIN_GO="${PLACE_MIN_GO:-50}"
DISQUES_LOURD=("$(dirname "$DEPOT_lourd")" "${BG2_LOURD_WORK:-/mnt/d/anarbib-sauvegardes/miroir-lourd}")

# --- REPLIQUE HORS LIGNE (22/10/2026) ----------------------------------------
# La copie froide (anarbib-copie-froide.sh) pose les quatre depots sur un disque
# qu'on debranche. C'est la seule copie qui resiste a une cle volee : le disque
# range ailleurs n'est branche nulle part. Mais rien ne disait quand elle avait
# ete faite pour la derniere fois : la rotation des deux disques (l'un au
# poste, l'autre hors du lieu, echanges chaque mois) reposait sur la memoire.
#
# Le disque est le plus souvent debranche : on ne peut pas le lire. On lit donc
# un TEMOIN, que la copie froide ecrit quand la replique a ete REVALIDEE sur le
# disque (empreintes des petits depots ET du depot lourd) : premier champ =
# epoch. Absent ou plus vieux que REPLIQUE_MAX_J jours -> drapeau HORS LIGNE.
# 35 jours : un mois de rotation, plus une semaine de marge. 0 = garde coupee
# (une machine qui ne fait pas de copie hors ligne).
REPLIQUE_HL="$OPS_DIR/.replique-hors-ligne"
REPLIQUE_MAX_J="${REPLIQUE_MAX_J:-35}"

info() { echo ">>> $*"; }
die()  { echo "ERREUR: $*" >&2; exit 2; }

command -v restic >/dev/null 2>&1 || die "outil manquant: restic"
[ -f "$RESTIC_PASSWORD_FILE" ] || die "passphrase restic introuvable: $RESTIC_PASSWORD_FILE"
mkdir -p "$OPS_DIR"

# Date ISO du snapshot le PLUS RECENT d'un flux.
#   stdout = date ISO (vide si le depot est lisible mais ne contient rien)
#   retour = 0 si le depot a pu etre lu, 1 s'il est injoignable
#
# `jq` n'est pas installe sur ce poste (cf. anarbib-bg2.sh) : on lit le JSON au
# grep, ce qui suffit pour un champ plat.
#
# ON N'UTILISE PAS `--latest 1`. Piege verifie le 21/08/2026 : restic groupe les
# snapshots par (host, paths) et `--latest n` rend n snapshots PAR GROUPE. Le
# depot `long` en a trois groupes — le chemin a change quand le dump du Vault
# s'est ajoute (BG2-15, 19/08) — donc `--latest 1` y rendait TROIS lignes, dont
# la premiere datait du 30/06. Un `head -1` dessus faisait dire au controle que
# le flux avait 51 jours de retard, tous les jours, pour toujours : l'alerte
# permanente qu'on apprend a ignorer en une semaine.
#
# On lit donc toutes les dates et on prend le maximum. La retention (7/4/6) les
# garde peu nombreuses, c'est sans effet sur le cout, et c'est vrai quelle que
# soit la version de restic et le nombre de groupes.
date_dernier_snapshot() {
  local flux="$1" json="" iso="" ts="" best=0 best_iso=""

  json="$(RESTIC_REPOSITORY="$(depot_de "$flux")" \
            timeout 120 restic snapshots --no-lock --tag "flux-$flux" --json 2>/dev/null)" || return 1

  while IFS= read -r iso; do
    [ -n "$iso" ] || continue
    ts="$(date -d "$iso" +%s 2>/dev/null)" || continue
    if [ "$ts" -gt "$best" ]; then best="$ts"; best_iso="$iso"; fi
  done <<< "$(printf '%s' "$json" | grep -o '"time":"[^"]*"' | cut -d'"' -f4)"

  [ -n "$best_iso" ] && printf '%s' "$best_iso"
  return 0
}

maintenant=$(date +%s)
retard=()      # flux en retard, avec leur age
interrompus=() # flux dont un tir est parti sans revenir
aveugle=()     # flux qu'on n'a pas pu lire
lecture_ok=0   # au moins un depot lu -> on a bien vu quelque chose

info "Controle de fraicheur #BG2 — $(date '+%d/%m/%Y %H:%M %Z')"

for flux in "${FLUX[@]}"; do
  seuil_var="SEUIL_$flux"; seuil="${!seuil_var}"

  # Trois issues distinctes, et il FAUT les distinguer : un depot injoignable
  # n'accuse personne, un depot lisible et vide accuse beaucoup.
  if ! iso="$(date_dernier_snapshot "$flux")"; then
    aveugle+=("$flux")
    printf '    ??  %-8s depot injoignable — pas de verdict\n' "$flux"
    continue
  fi

  lecture_ok=1

  if [ -z "$iso" ]; then
    retard+=("$flux (AUCUN snapshot)")
    printf '    !!  %-8s depot lisible mais VIDE — aucun snapshot\n' "$flux"
    continue
  fi

  ts=$(date -d "$iso" +%s 2>/dev/null) || { aveugle+=("$flux"); continue; }
  age_h=$(( (maintenant - ts) / 3600 ))

  if [ "$age_h" -gt "$seuil" ]; then
    if [ "$age_h" -lt 48 ]; then
      retard+=("$flux (${age_h} h, seuil ${seuil} h)")
    else
      retard+=("$flux ($((age_h / 24)) j, seuil $((seuil / 24)) j)")
    fi
    printf '    !!  %-8s %s — %s h (seuil %s h) EN RETARD\n' \
      "$flux" "$(date -d "$iso" '+%d/%m %H:%M')" "$age_h" "$seuil"
  else
    printf '    OK  %-8s %s — %s h (seuil %s h)\n' \
      "$flux" "$(date -d "$iso" '+%d/%m %H:%M')" "$age_h" "$seuil"
  fi
done

[ "$lecture_ok" = 1 ] && echo "$maintenant" > "$VU"

place=()   # « chemin : N Go libres (seuil S Go) »
for d in "${DISQUES_LOURD[@]}"; do
  [ -d "$d" ] || continue
  libre_ko="$(df -Pk "$d" 2>/dev/null | awk 'NR==2{print $4}' || true)"
  case "$libre_ko" in ''|*[!0-9]*) continue ;; esac   # df illisible : pas de verdict
  libre_go=$(( libre_ko / 1048576 ))
  if [ "$libre_go" -lt "$PLACE_MIN_GO" ]; then
    place+=("$d : ${libre_go} Go libres (seuil ${PLACE_MIN_GO} Go)")
    printf '    !!  %-8s %s — %s Go libres, seuil %s Go\n' place "$d" "$libre_go" "$PLACE_MIN_GO"
  else
    printf '    OK  %-8s %s — %s Go libres\n' place "$d" "$libre_go"
  fi
done
# Ajoutee a tout drapeau pose plus bas : une alerte de place ne doit pas se
# perdre derriere un retard ou un tir interrompu, ni les cacher.
ligne_place() {
  local p
  for p in "${place[@]}"; do echo "PLACE : $p — le flux lourd echouera quand le disque sera plein"; done
}

hors_ligne=""   # vide = replique recente (ou garde coupee)
if [ "$REPLIQUE_MAX_J" != 0 ]; then
  quand=""
  [ -f "$REPLIQUE_HL" ] && read -r quand _ < "$REPLIQUE_HL" 2>/dev/null || true
  case "$quand" in ''|*[!0-9]*) quand="" ;; esac
  if [ -z "$quand" ]; then
    hors_ligne="aucune replique hors ligne consignee ($REPLIQUE_HL absent ou illisible)"
    printf '    !!  %-8s aucune replique consignee\n' "hors-lig"
  else
    age_j=$(( (maintenant - quand) / 86400 ))
    if [ "$age_j" -gt "$REPLIQUE_MAX_J" ]; then
      hors_ligne="derniere replique verifiee le $(date -d "@$quand" '+%d/%m/%Y'), il y a ${age_j} j (seuil ${REPLIQUE_MAX_J} j)"
      printf '    !!  %-8s %s — %s j (seuil %s j)\n' "hors-lig" "$(date -d "@$quand" '+%d/%m')" "$age_j" "$REPLIQUE_MAX_J"
    else
      printf '    OK  %-8s %s — %s j (seuil %s j)\n' "hors-lig" "$(date -d "@$quand" '+%d/%m')" "$age_j" "$REPLIQUE_MAX_J"
    fi
  fi
fi
# Comme la place : ajoutee a tout drapeau, pour ne pas se perdre derriere un
# retard, et sans le cacher.
ligne_hors_ligne() {
  [ -n "$hors_ligne" ] || return 0
  echo "HORS LIGNE : $hors_ligne — brancher le disque, deploy/ops/anarbib-copie-froide.sh, puis echanger les disques"
}

# --- TIRS INTERROMPUS -------------------------------------------------------
# Un marqueur `.en-cours-<flux>` que rien n'est venu retirer = un tir parti et
# jamais revenu. C'est une panne DISTINCTE du retard, et elle peut frapper un
# flux parfaitement frais : le 24/08, `long` a ete tue en plein pg_dump avec un
# instantane vieux de deux jours seulement. Le controle disait « frais », et
# c'etait vrai — la donnee etait la. Mais le tir, lui, etait mort, et personne
# sur ce poste ne pouvait le dire.
#
# Consequence qu'on ne veut plus subir : un rattrapage `Persistent=true` tue ne
# se represente PAS. Son jeton est consomme. `long` serait reste muet jusqu'au
# dimanche suivant.
# --- Qui tourne en ce moment ? (30/09/2026, backlog I24) ----------------------
# Un tir est VIVANT si son service est en cours — un service oneshot l'est a
# l'etat `activating` pendant tout le tir, jamais `active` : `is-active` rend 3,
# d'ou `show -p ActiveState` — ou si le processus note dans son marqueur est
# encore un anarbib-bg2.sh de CE flux (un numero de processus se recycle a
# chaque demarrage de la session). Lu sans tube : sous `pipefail`,
# `tr | grep -q` peut rendre faux quand grep a trouve (tr recoit SIGPIPE).
SYSTEMCTL="${SYSTEMCTL:-systemctl}"
PROC="${PROC:-/proc}"
etat_service() {
  "$SYSTEMCTL" --user show -p ActiveState --value "anarbib-backup-$1.service" 2>/dev/null || true
}
service_en_cours() {
  case "$(etat_service "$1")" in active|activating|deactivating|reloading) return 0 ;; esac
  return 1
}
processus_du_marqueur_vivant() {   # $1 flux, $2 numero de processus
  local cmd=""
  [ -n "$2" ] && [ -r "$PROC/$2/cmdline" ] || return 1
  cmd="$(tr '\0' ' ' < "$PROC/$2/cmdline" 2>/dev/null || true)"
  case "$cmd" in *"anarbib-bg2.sh backup $1"*|*"anarbib-bg2.sh backup all"*) return 0 ;; esac
  return 1
}

interrompus=()
for f in "${FLUX[@]}"; do
  m="$OPS_DIR/.en-cours-$f"
  [ -f "$m" ] || continue
  debut=0; pid=""
  read -r debut pid _ < "$m" 2>/dev/null || true
  case "$debut" in ''|*[!0-9]*) debut=0 ;; esac
  case "$pid" in *[!0-9]*) pid="" ;; esac
  [ "$debut" -gt 0 ] || continue
  min=$(( (maintenant - debut) / 60 ))
  if service_en_cours "$f" || processus_du_marqueur_vivant "$f" "$pid"; then
    printf '    ..  %-8s tir en cours depuis %s min\n' "$f" "$min"
  elif [ -n "$pid" ] || [ "$min" -gt "$SEUIL_INTERROMPU_MIN" ]; then
    # Processus connu et mort : inutile d'attendre une heure — la session
    # redemarre souvent quelques minutes apres avoir tue le tir. Sans numero de
    # processus (ancien marqueur), on retombe sur le seuil d'age.
    interrompus+=("$f (parti il y a $((min / 60)) h $((min % 60)) min, jamais revenu)")
    printf '    !!  %-8s TIR INTERROMPU — parti il y a %s min, jamais revenu\n' "$f" "$min"
  else
    printf '    ..  %-8s tir en cours depuis %s min (sans numero de processus : seuil de %s min)\n' \
      "$f" "$min" "$SEUIL_INTERROMPU_MIN"
  fi
done

# --- RELANCE (30/09/2026, backlog I24) ---------------------------------------
# Constater ne suffisait pas. Le 15/09, le tir `storage` rattrape au demarrage
# a ete tue au bout de huit minutes par l'arret de la session WSL ; le drapeau
# disait « Relancer : systemctl … », mais personne n'ouvre un terminal pour le
# lire, et le rattrapage `Persistent=` ne rejoue que les tirs MANQUES, pas un
# tir parti puis tue : neuf jours de trou. Or ce controle tourne trois minutes
# apres chaque demarrage de la session et chaque midi — exactement quand il
# faut rejouer. Il relance donc lui-meme le service d'un flux interrompu ou en
# retard, une fois par flux et par passage, sans attendre sa fin (`--no-block` :
# un tir `storage` dure vingt minutes, ce controle en a dix). Jamais :
#   - par-dessus un tir vivant de ce flux (ci-dessus) ; un tir d'un AUTRE flux
#     ne gene pas : anarbib-bg2.sh fait passer les tirs l'un apres l'autre
#     (verrou `.bg2.lock`), le relance attend son tour ;
#   - sur un depot qu'on n'a pas pu lire : relancer ne reparera ni l'hote ni la
#     cle, et l'on repartirait a chaque passage. (La lecture se fait en
#     `--no-lock` : un verrou restic orphelin ne rend plus un depot « illisible ».)
#   - quand le minuteur du flux est arrete : c'est la facon de GELER un flux
#     (`systemctl --user stop anarbib-backup-<flux>.timer`), elle doit le rester ;
#   - quand RELANCE=0 (constater sans relancer).
# Chaque relance, et chaque relance NON faite avec sa raison, est ecrite au
# drapeau. Un tir relance qui echoue ne boucle pas : le passage suivant
# (demarrage ou midi) reessaie, et la sonde en base continue d'alerter.
RELANCE="${RELANCE:-1}"
relances=()       # flux relances
non_relances=()   # « flux — raison »
traites=()        # un flux n'est examine qu'une fois par passage
relancer() {
  local flux="$1" unite="anarbib-backup-$1.service" r err=""
  for r in "${traites[@]}"; do [ "$r" = "$flux" ] && return 0; done
  traites+=("$flux")
  if [ "$RELANCE" != 1 ]; then
    non_relances+=("$flux — relance coupee (RELANCE=$RELANCE)")
    return 0
  fi
  for r in "${aveugle[@]}"; do
    if [ "$r" = "$flux" ]; then
      non_relances+=("$flux — depot illisible (hote injoignable, cle SSH ?) : relancer ne le reparerait pas")
      printf '    ??  %-8s depot illisible — pas de relance\n' "$flux"
      return 0
    fi
  done
  if ! "$SYSTEMCTL" --user is-active --quiet "anarbib-backup-$flux.timer" 2>/dev/null; then
    non_relances+=("$flux — minuteur arrete : gel voulu")
    printf '    ..  %-8s minuteur arrete (gel) — pas de relance\n' "$flux"
    return 0
  fi
  if service_en_cours "$flux"; then
    printf '    ..  %-8s tir systemd en cours (%s) — pas de relance\n' "$flux" "$(etat_service "$flux")"
    return 0
  fi
  if err="$("$SYSTEMCTL" --user start --no-block "$unite" 2>&1)"; then
    relances+=("$flux")
    printf '    >>  %-8s RELANCE (%s)\n' "$flux" "$unite"
  else
    non_relances+=("$flux — relance REFUSEE par systemd : ${err:-sans message}")
    printf '    !!  %-8s relance REFUSEE par systemd : %s\n' "$flux" "${err:-sans message}"
  fi
}
for i in "${interrompus[@]}"; do relancer "${i%% *}"; done
for i in "${retard[@]}"; do relancer "${i%% *}"; done
ligne_relance() {
  local x
  if [ ${#relances[@]} -gt 0 ]; then
    echo "RELANCE AUTOMATIQUE a $(date '+%H:%M') : ${relances[*]} — verifier au prochain passage"
    echo "  Suivre : journalctl --user -u anarbib-backup-${relances[0]}.service -f"
  fi
  for x in "${non_relances[@]}"; do echo "PAS DE RELANCE : $x"; done
}

if [ ${#interrompus[@]} -gt 0 ]; then
  {
    echo "TIR INTERROMPU $(date -u +%Y-%m-%dT%H:%M:%SZ) : ${interrompus[*]}"
    echo "--- ce que cela veut dire ---"
    echo "Un tir a demarre et n'est jamais revenu : processus tue, session WSL"
    echo "demontee, ou machine eteinte en cours de route. La DONNEE peut etre"
    echo "encore fraiche — ce n'est pas un retard, c'est un tir mort."
    echo "Un rattrapage tue ne se rejoue pas tout seul (Persistent= ne rejoue que les tirs MANQUES)."
    ligne_relance
    ligne_place
    ligne_hors_ligne
    for i in "${interrompus[@]}"; do
      echo "  Relancer a la main : systemctl --user start anarbib-backup-${i%% *}.service"
    done
  } > "$FLAG"
  info "TIR(S) INTERROMPU(S) : ${interrompus[*]}"
  info "Drapeau pose ($FLAG) — il s'affichera a l'ouverture du terminal."
  exit 1
fi

# --- Aveuglement prolonge : on n'a rien pu lire depuis trop longtemps --------
aveugle_depuis_h=0
if [ "$lecture_ok" = 0 ] && [ -f "$VU" ]; then
  derniere=$(cat "$VU" 2>/dev/null || echo "$maintenant")
  aveugle_depuis_h=$(( (maintenant - derniere) / 3600 ))
fi

if [ ${#retard[@]} -gt 0 ]; then
  {
    echo "RETARD $(date -u +%Y-%m-%dT%H:%M:%SZ) : ${retard[*]}"
    echo "--- ce que cela veut dire ---"
    echo "Un flux n'a pas produit de snapshot depuis plus longtemps que prevu."
    ligne_relance
    ligne_place
    ligne_hors_ligne
    echo "Relancer a la main : systemctl --user start anarbib-backup-<flux>.service"
    echo "Verifier : journalctl --user -u anarbib-backup-<flux>.service -n 40"
  } > "$FLAG"
  info "EN RETARD : ${retard[*]}"
  info "Drapeau pose ($FLAG) — il s'affichera a l'ouverture du terminal."
  exit 1
fi

if [ "$lecture_ok" = 0 ] && [ "$aveugle_depuis_h" -gt "$MAX_AVEUGLE_H" ]; then
  {
    echo "AVEUGLE $(date -u +%Y-%m-%dT%H:%M:%SZ) : depots illisibles depuis ${aveugle_depuis_h} h"
    echo "--- ce que cela veut dire ---"
    echo "Ce n'est PAS un flux en retard : c'est l'impossibilite de le verifier."
    echo "Hote de sauvegarde injoignable, cle SSH, ou depot restic casse."
    echo "Verifier : restic -r $RESTIC_BASE/anarbib-court snapshots"
    ligne_place
    ligne_hors_ligne
  } > "$FLAG"
  info "AVEUGLE depuis ${aveugle_depuis_h} h — drapeau pose."
  exit 3
fi

# Les flux sont frais, mais un disque du flux lourd se remplit : son propre
# drapeau, son propre code (4), pour qu'il ne passe pas pour un retard.
if [ ${#place[@]} -gt 0 ]; then
  {
    echo "PLACE $(date -u +%Y-%m-%dT%H:%M:%SZ) : disque du flux lourd presque plein"
    echo "--- ce que cela veut dire ---"
    echo "Les sauvegardes sont a jour. Mais le miroir (D:) ou le depot (E:) du flux"
    echo "lourd passe sous le seuil : faire de la place, deplacer le depot"
    echo "(BG2_LOURD_REPO / BG2_LOURD_WORK), ou trouver la place hors site (I21)."
    ligne_place
    ligne_hors_ligne
  } > "$FLAG"
  info "PLACE : ${place[*]}"
  info "Drapeau pose ($FLAG) — il s'affichera a l'ouverture du terminal."
  exit 4
fi

# Les flux sont frais et les disques ont de la place, mais la copie qu'on range
# hors du lieu vieillit : son propre drapeau, son propre code (5).
if [ -n "$hors_ligne" ]; then
  {
    echo "HORS LIGNE $(date -u +%Y-%m-%dT%H:%M:%SZ) : replique hors ligne trop vieille"
    echo "--- ce que cela veut dire ---"
    echo "Les sauvegardes sont a jour. Mais la copie sur disque debranche, la seule"
    echo "qui resiste a une cle volee, n'a pas ete refaite depuis trop longtemps."
    echo "Brancher le disque present, lancer deploy/ops/anarbib-copie-froide.sh, passer"
    echo "les commandes Windows qu'elle imprime (la derniere consigne la replique),"
    echo "puis echanger ce disque avec celui qui est range hors du lieu."
    ligne_hors_ligne
  } > "$FLAG"
  info "HORS LIGNE : $hors_ligne"
  info "Drapeau pose ($FLAG) — il s'affichera a l'ouverture du terminal."
  exit 5
fi

# Tout est frais : on retire le drapeau. Un drapeau qui survit a la reparation
# devient du bruit, et un bruit qu'on apprend a ignorer ne garde plus rien.
rm -f "$FLAG"
if [ "$lecture_ok" = 0 ]; then
  # Rien n'a pu etre lu. On ne pose pas le drapeau (on est sous le seuil
  # d'aveuglement, c'est peut-etre une coupure d'une minute), mais on se garde
  # bien de dire que tout va bien : ce serait affirmer une fraicheur qu'on n'a
  # pas verifiee — le travers meme que ce script corrige.
  info "AUCUN VERDICT : aucun depot n'a pu etre lu (${aveugle[*]})."
  info "Sous le seuil d'aveuglement (${MAX_AVEUGLE_H} h) — pas d'alerte, pas de garantie non plus."
elif [ ${#aveugle[@]} -gt 0 ]; then
  info "Flux lus : frais. NON VERIFIE(S) : ${aveugle[*]}."
else
  info "Les flux sont frais (${FLUX[*]})."
fi
exit 0
