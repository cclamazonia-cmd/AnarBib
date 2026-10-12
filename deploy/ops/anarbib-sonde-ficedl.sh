#!/usr/bin/env bash
#
# anarbib-sonde-ficedl.sh — la sonde legere du thesaurus de la FICEDL (backlog H2)
#
# CE FICHIER EST LA SOURCE DE VERITE — versionne. `~/anarbib-ops/` n'en a qu'un
# lien symbolique. Voir deploy/ops/README.md, « La sonde du thesaurus FICEDL ».
#
# --------------------------------------------------------------------------
# POURQUOI ELLE EXISTE (12/10/2026)
#   L'export du thesaurus de la FICEDL (H2, H3, H13) attend des reponses de la
#   FICEDL — et leur site, thesaurus.ficedl.info, s'est degrade sur un mois :
#   deux fiches en 503 le 03/09, tout le site le 09/09, encore le 27/09, plus
#   de reponse le 05/10. Personne ne le surveillait ; on s'en apercevait en
#   essayant de racler. Une requete par jour suffit a savoir quand il revient,
#   et a le dire a la FICEDL si elle ne le sait pas.
#
# CE QU'ELLE FAIT
#   Une fois par jour (minuteur systemd utilisateur, comme le temoin de panne),
#   depuis le poste, elle demande UNE fiche de descripteur (pas la page
#   d'accueil : un SPIP peut servir sa une et refuser ses articles). Apres
#   SEUIL_ECHECS echecs de suite (deux : deux jours), elle ecrit par l'API de
#   Resend — la meme configuration que le temoin, ~/anarbib-ops/temoin.env —
#   que le site ne repond plus ; puis une seconde fois le jour ou il revient,
#   avec la duree. Un seul courriel par absence.
#
# CE QU'ELLE NE FAIT PAS QUAND ELLE NE PEUT PAS REGARDER
#   Un poste sans reseau n'est pas un site tombe : si la fiche ne repond pas
#   ET qu'une adresse de controle (codeberg.org) ne repond pas non plus, le
#   passage est « aveugle » — dit au journal, pas compte, personne n'est ecrit.
#
# Sorties : 0 = le site repond · 1 = il ne repond pas (absence declaree ou en
#           cours de constat) · 3 = aveugle (poste sans reseau) · 2 = usage ou
#           configuration.
# --------------------------------------------------------------------------
set -uo pipefail

OPS_DIR="${OPS_DIR:-$HOME/anarbib-ops}"
ETAT_DIR="$OPS_DIR/sonde-ficedl"
ETAT="$ETAT_DIR/etat"
CONF="${TEMOIN_CONF:-$OPS_DIR/temoin.env}"

# La configuration posee sur le poste (celle du temoin de panne) ; une variable
# deja presente dans l'environnement (un banc, un essai) l'emporte sur le fichier.
if [ -f "$CONF" ]; then
  while IFS='=' read -r k v; do
    case "$k" in ''|\#*) continue ;; esac
    k="${k// /}"; v="${v%\"}"; v="${v#\"}"
    [ -z "${!k:-}" ] && export "$k=$v"
  done < "$CONF"
fi

# Une fiche de descripteur, pas la une : « anarchisme », la plus stable.
URL_FICHE="${SONDE_FICEDL_URL:-https://thesaurus.ficedl.info/spip.php?mot8}"
URL_CONTROLE="${SONDE_FICEDL_URL_CONTROLE:-https://codeberg.org/}"
SEUIL_ECHECS="${SONDE_FICEDL_SEUIL_ECHECS:-2}"
DELAI_S="${SONDE_FICEDL_DELAI_S:-30}"
INTERVALLE_S="${SONDE_FICEDL_INTERVALLE_S:-86400}"   # un passage par jour : la duree se compte en jours
TRANSPORT="${TEMOIN_TRANSPORT:-resend}"             # resend | fichier (banc)
DESTINATAIRES="${TEMOIN_DESTINATAIRES:-}"
EXPEDITEUR="${TEMOIN_EXPEDITEUR:-}"
RESEND_API_KEY="${RESEND_API_KEY:-}"
RESEND_URL="${TEMOIN_RESEND_URL:-https://api.resend.com/emails}"
FUSEAU="${TEMOIN_FUSEAU:-Europe/Paris}"

info() { echo ">>> $*"; }
die()  { echo "ERREUR: $*" >&2; exit 2; }

command -v curl >/dev/null 2>&1 || die "outil manquant: curl"
[ -n "$DESTINATAIRES" ] || die "sonde non configuree : TEMOIN_DESTINATAIRES vide ($CONF)"
[ -n "$EXPEDITEUR" ]    || die "sonde non configuree : TEMOIN_EXPEDITEUR vide ($CONF)"
case "$TRANSPORT" in
  resend)  [ -n "$RESEND_API_KEY" ] || die "sonde non configuree : RESEND_API_KEY vide ($CONF)" ;;
  fichier) ;;
  *) die "TEMOIN_TRANSPORT inconnu : $TRANSPORT (resend | fichier)" ;;
esac
mkdir -p "$ETAT_DIR"

# --- Etat entre deux passages -------------------------------------------------
echecs=0; etat=ok; depuis=0
if [ -f "$ETAT" ]; then
  while IFS='=' read -r k v; do
    case "$k" in echecs) echecs="$v" ;; etat) etat="$v" ;; depuis) depuis="$v" ;; esac
  done < "$ETAT"
fi
case "$echecs" in ''|*[!0-9]*) echecs=0 ;; esac
case "$depuis" in ''|*[!0-9]*) depuis=0 ;; esac
case "$etat" in ok|absent) ;; *) etat=ok ;; esac
ecrire_etat() {   # $1 echecs, $2 etat, $3 depuis, $4 detail
  printf 'echecs=%s\netat=%s\ndepuis=%s\ndernier_passage=%s\ndetail=%s\n' \
    "$1" "$2" "$3" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$4" > "$ETAT"
}

# --- La sonde -------------------------------------------------------------------
# stdout = « <code HTTP> » (000 si la connexion a echoue) ; retour = 0 si 2xx.
sonde() {
  local code
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time "$DELAI_S" -A 'AnarBib-sonde (une requete par jour)' "$1" 2>/dev/null)" || code="000"
  printf '%s' "$code"
  case "$code" in 2[0-9][0-9]) return 0 ;; *) return 1 ;; esac
}
controle_repond() {
  local code
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time "$DELAI_S" "$URL_CONTROLE" 2>/dev/null)" || return 1
  case "$code" in 000) return 1 ;; *) return 0 ;; esac
}

maintenant=$(date +%s)
heure_locale() { TZ="$FUSEAU" date -d "@$1" '+%d/%m/%Y %H:%M'; }

code="$(sonde "$URL_FICHE")" && site_ok=1 || site_ok=0
info "Sonde FICEDL — $(heure_locale "$maintenant") $FUSEAU — $URL_FICHE → $code (etat precedent : $etat, echecs $echecs)"

# --- Le courriel ----------------------------------------------------------------
json_chaine() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk 'NR>1{printf "\\n"} {printf "%s", $0}'
}
json_destinataires() {
  local IFS=',' a premier=1 out="["
  for a in $DESTINATAIRES; do
    a="${a// /}"; [ -n "$a" ] || continue
    [ $premier = 1 ] || out="$out,"
    out="$out\"$(json_chaine "$a")\""; premier=0
  done
  printf '%s]' "$out"
}
envoyer() {   # $1 sujet, $2 texte ; retour 0 si parti
  local json code
  json="{\"from\":\"$(json_chaine "$EXPEDITEUR")\",\"to\":$(json_destinataires),\"subject\":\"$(json_chaine "$1")\",\"text\":\"$(json_chaine "$2")\"}"
  if [ "$TRANSPORT" = fichier ]; then
    printf '%s\n' "$json" > "$ETAT_DIR/dernier-courriel.json"
    printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" >> "$ETAT_DIR/courriels.log"
    info "courriel ecrit (transport fichier) : $1"
    return 0
  fi
  code="$(curl -sS -o "$ETAT_DIR/dernier-envoi.out" -w '%{http_code}' --max-time 30 -X POST "$RESEND_URL" \
            -H "Authorization: Bearer $RESEND_API_KEY" -H "Content-Type: application/json" \
            --data "$json" 2>/dev/null)" || code="000"
  case "$code" in
    2[0-9][0-9]) printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" >> "$ETAT_DIR/courriels.log"
                 info "courriel parti (Resend $code) : $1"; return 0 ;;
    *) info "COURRIEL NON PARTI (Resend $code) : $1 — nouvel essai au prochain passage"; return 1 ;;
  esac
}

# --- Le verdict ---------------------------------------------------------------
if [ $site_ok = 1 ]; then
  if [ "$etat" = absent ]; then
    duree_j=$(( (maintenant - depuis) / 86400 ))
    sujet="FICEDL — le thésaurus répond de nouveau (absent ${duree_j} jour(s), sonde du poste)"
    texte="Le thésaurus de la FICEDL répond de nouveau depuis le poste, le $(heure_locale "$maintenant") ($FUSEAU) : $URL_FICHE → $code.

Absence constatée par la sonde : du $(heure_locale "$depuis") au $(heure_locale "$maintenant"), soit ${duree_j} jour(s) environ (la sonde passe une fois par jour).

Ce que cela ouvre : le raclage (H13) redevient possible pour comparer à l'instantané du 03/09, et le courriel à la FICEDL (H2) peut partir — les sept questions sont écrites depuis le 16/09."
    if envoyer "$sujet" "$texte"; then
      ecrire_etat 0 ok 0 "retour $code"
    else
      ecrire_etat 0 absent "$depuis" "retour non notifie $code"
      exit 0
    fi
  else
    ecrire_etat 0 ok 0 "ok $code"
  fi
  info "Le thesaurus repond."
  exit 0
fi

if ! controle_repond; then
  info "AVEUGLE : ni la fiche ni $URL_CONTROLE ne repondent — le poste est sans reseau, pas de verdict, pas d'echec compte."
  ecrire_etat "$echecs" "$etat" "$depuis" "aveugle $code"
  exit 3
fi

echecs=$((echecs + 1))
if [ "$etat" = absent ]; then
  ecrire_etat "$echecs" absent "$depuis" "absence en cours $code"
  info "ABSENCE EN COURS depuis $(heure_locale "$depuis") — ${echecs} passage(s) sans reponse."
  exit 1
fi
if [ "$echecs" -lt "$SEUIL_ECHECS" ]; then
  ecrire_etat "$echecs" ok 0 "echec $echecs/$SEUIL_ECHECS $code"
  info "Le thesaurus ne repond pas ($code) — echec $echecs sur $SEUIL_ECHECS avant d'ecrire."
  exit 1
fi

debut=$(( maintenant - (echecs - 1) * INTERVALLE_S ))
sujet="FICEDL — le thésaurus ne répond plus (sonde du poste, $(TZ="$FUSEAU" date -d "@$maintenant" '+%d/%m'))"
texte="Depuis le poste, le thésaurus de la FICEDL ne répond plus : ${echecs} passages de suite sans réponse (un par jour), le dernier le $(heure_locale "$maintenant") ($FUSEAU).

Sonde : $URL_FICHE → $code (000 = pas de connexion ; 503 = le serveur refuse). L'adresse de contrôle ($URL_CONTROLE) répond : le poste a bien le réseau, c'est le site.

Ce que ce courriel ne dit pas : la cause — la sonde ne lit qu'une fiche. Si la FICEDL ne le sait pas, c'est le moment de le lui écrire (H2). La sonde écrira une seconde fois le jour où le site revient, avec la durée ; d'ici là, l'instantané du 03/09 (H13) reste la référence."
if envoyer "$sujet" "$texte"; then
  ecrire_etat "$echecs" absent "$debut" "absence declaree $code"
  info "ABSENCE DECLAREE — courriel envoye."
else
  ecrire_etat "$echecs" ok 0 "absence non notifiee $code"
fi
exit 1
