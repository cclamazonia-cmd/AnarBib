#!/usr/bin/env bash
#
# anarbib-bg2-fraicheur.sh — controle de fraicheur des trois flux #BG2
#
# CE FICHIER EST LA SOURCE DE VERITE — versionne. `~/anarbib-ops/` n'en a qu'un
# lien symbolique. Voir deploy/ops/README.md.
#
# --------------------------------------------------------------------------
# CE QU'IL FAIT
#   Ouvre les trois depots restic, lit la date du DERNIER SNAPSHOT de chaque
#   flux, la compare a l'intervalle attendu, et pose un drapeau lisible a
#   l'ouverture du terminal si un flux a pris du retard.
#   Aucune ecriture ailleurs : il ne sauvegarde rien, ne supprime rien, ne
#   touche ni a la base ni aux depots. Lecture seule.
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
#           longtemps · 2 = erreur d'usage/prerequis.
# --------------------------------------------------------------------------
set -euo pipefail

OPS_DIR="${OPS_DIR:-$HOME/anarbib-ops}"
FLAG="$OPS_DIR/.fraicheur-alerte"          # lu par ~/.bashrc a chaque terminal
VU="$OPS_DIR/.fraicheur-derniere-lecture"  # horodatage epoch de la derniere lecture reussie

RESTIC_BASE="${RESTIC_BASE:-sftp:anarbib@bricolage.herbesfolles.org:/data}"
export RESTIC_PASSWORD_FILE="${RESTIC_PASSWORD_FILE:-$HOME/.config/restic-anarbib.pass}"

FLUX=(court long storage)

# Seuils en heures. ALIGNES SUR public.fn_backup_heartbeat_status() : les deux
# gardes doivent porter le meme jugement, sinon on passe son temps a se demander
# laquelle a raison. Si tu changes ici, change la-bas (et l'inverse).
#   court   quotidien  -> 36 h  (un jour saute, pas deux)
#   long    hebdo      -> 9 j   (une semaine sautee, plus la marge du dimanche)
#   storage hebdo      -> 9 j
SEUIL_court=36
SEUIL_long=216
SEUIL_storage=216

# Age au-dela duquel un marqueur « tir en cours » signale un tir MORT et non un
# tir qui travaille. Aligne sur la regle `interrompu` de la sonde en base (60 min),
# pour la meme raison que les seuils ci-dessus : deux gardes qui jugeraient
# differemment feraient perdre du temps a se demander laquelle a raison.
# Marge confortable — le plus long des trois flux, storage, tient en ~23 min.
SEUIL_INTERROMPU_MIN="${SEUIL_INTERROMPU_MIN:-60}"

# Au-dela de ce delai sans avoir pu LIRE les depots, l'aveuglement devient une
# alerte a part entiere. Trois jours : assez pour absorber un voyage ou une
# coupure, trop peu pour qu'un depot mort passe une semaine inapercu.
MAX_AVEUGLE_H="${MAX_AVEUGLE_H:-72}"

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

  json="$(RESTIC_REPOSITORY="$RESTIC_BASE/anarbib-$flux" \
            timeout 120 restic snapshots --tag "flux-$flux" --json 2>/dev/null)" || return 1

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
interrompus=()
for f in "${FLUX[@]}"; do
  m="$OPS_DIR/.en-cours-$f"
  [ -f "$m" ] || continue
  debut="$(cut -d' ' -f1 "$m" 2>/dev/null || echo 0)"
  case "$debut" in ''|*[!0-9]*) debut=0 ;; esac
  [ "$debut" -gt 0 ] || continue
  min=$(( (maintenant - debut) / 60 ))
  if [ "$min" -gt "$SEUIL_INTERROMPU_MIN" ]; then
    interrompus+=("$f (parti il y a $((min / 60)) h $((min % 60)) min, jamais revenu)")
    printf '    !!  %-8s TIR INTERROMPU — parti il y a %s min, jamais revenu\n' "$f" "$min"
  else
    printf '    ..  %-8s tir en cours depuis %s min (sous le seuil de %s min)\n' \
      "$f" "$min" "$SEUIL_INTERROMPU_MIN"
  fi
done

if [ ${#interrompus[@]} -gt 0 ]; then
  {
    echo "TIR INTERROMPU $(date -u +%Y-%m-%dT%H:%M:%SZ) : ${interrompus[*]}"
    echo "--- ce que cela veut dire ---"
    echo "Un tir a demarre et n'est jamais revenu : processus tue, session WSL"
    echo "demontee, ou machine eteinte en cours de route. La DONNEE peut etre"
    echo "encore fraiche — ce n'est pas un retard, c'est un tir mort."
    echo "ATTENTION : un rattrapage tue ne se rejoue pas tout seul."
    for i in "${interrompus[@]}"; do
      echo "  Relancer : systemctl --user start anarbib-backup-${i%% *}.service"
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
    echo "Relancer : systemctl --user start anarbib-backup-<flux>.service"
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
  } > "$FLAG"
  info "AVEUGLE depuis ${aveugle_depuis_h} h — drapeau pose."
  exit 3
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
  info "Les trois flux sont frais."
fi
exit 0
