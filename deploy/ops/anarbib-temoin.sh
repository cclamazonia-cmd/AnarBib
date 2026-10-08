#!/usr/bin/env bash
#
# anarbib-temoin.sh — temoin de panne HORS de la base (backlog I31)
#
# CE FICHIER EST LA SOURCE DE VERITE — versionne. `~/anarbib-ops/` n'en a qu'un
# lien symbolique. Voir deploy/ops/README.md, « Le temoin de panne ».
#
# --------------------------------------------------------------------------
# POURQUOI IL EXISTE (07/10/2026)
#   La base de production s'est arretee de 19:58 a 20:19 (Paris) et PERSONNE
#   n'a ete prevenu : la sonde `health-probe` tourne par une tache planifiee de
#   la base, ecrit ses incidents dans la base et n'envoie qu'a partir d'eux —
#   base tombee, sonde tombee avec elle. C'est Xavier qui a vu la panne, en se
#   servant de Mon compte. Une panne qui dure jusqu'a ce que quelqu'un s'en
#   apercoive dure le temps qu'on mette a s'en apercevoir.
#
# CE QU'IL FAIT
#   Toutes les cinq minutes (minuteur systemd utilisateur, comme les
#   sauvegardes), depuis une AUTRE machine que la base — le poste, en attendant
#   le serveur maison —, il interroge l'API de production : une lecture REST
#   (la liste publique des bibliotheques, par la cle publiable) et la sante
#   d'Auth. Apres SEUIL_ECHECS echecs de suite (deux : dix minutes), il ecrit
#   DIRECTEMENT par le transport de courriel — l'API de Resend, sans rien lire
#   ni ecrire dans la base — aux destinataires configures ; puis une seconde
#   fois au retour, avec la duree. Un seul courriel par panne.
#
# CE QU'IL NE FAIT PAS QUAND IL NE PEUT PAS REGARDER
#   Un poste sans reseau n'est pas une base en panne : si l'API ne repond pas
#   ET qu'une adresse de controle (codeberg.org) ne repond pas non plus, le
#   passage est « aveugle » — il le dit au journal, ne compte pas d'echec et
#   n'ecrit a personne. Meme philosophie que le controle de fraicheur : on ne
#   crie pas au loup parce qu'on n'a pas pu ouvrir les yeux.
#
# CONFIGURATION (jamais au depot) : ~/anarbib-ops/temoin.env, mode 600, posee
#   par la personne qui tient le poste — voir deploy/ops/temoin.env.example
#   pour les NOMS de variables. Sans elle, le temoin refuse de tourner (sortie
#   2) : un temoin qui tourne sans pouvoir prevenir serait le silence meme
#   qu'on corrige, et une unite « failed » se voit.
#
# Sorties : 0 = l'API repond · 1 = l'API ne repond pas (panne declaree ou en
#           cours de constat) · 3 = aveugle (poste sans reseau) · 2 = usage ou
#           configuration.
# --------------------------------------------------------------------------
set -uo pipefail

OPS_DIR="${OPS_DIR:-$HOME/anarbib-ops}"
ETAT_DIR="$OPS_DIR/temoin"
ETAT="$ETAT_DIR/etat"
CONF="${TEMOIN_CONF:-$OPS_DIR/temoin.env}"

# La configuration posee sur le poste ; une variable deja presente dans
# l'environnement (un banc, un essai) l'emporte sur le fichier.
if [ -f "$CONF" ]; then
  while IFS='=' read -r k v; do
    case "$k" in ''|\#*) continue ;; esac
    k="${k// /}"; v="${v%\"}"; v="${v#\"}"
    [ -z "${!k:-}" ] && export "$k=$v"
  done < "$CONF"
fi

PROJET="${TEMOIN_PROJET:-https://uflwmikiyjfnikiphtcp.supabase.co}"
# La cle PUBLIABLE du projet : publique par nature (elle est dans le front).
CLE_PUBLIABLE="${TEMOIN_CLE_PUBLIABLE:-sb_publishable_KJBytsICkVClr8iG26b0CQ_BxsVQooZ}"
URL_REST="${TEMOIN_URL_REST:-$PROJET/rest/v1/public_libraries?select=slug&limit=1}"
URL_AUTH="${TEMOIN_URL_AUTH:-$PROJET/auth/v1/health}"
URL_CONTROLE="${TEMOIN_URL_CONTROLE:-https://codeberg.org/}"
SEUIL_ECHECS="${TEMOIN_SEUIL_ECHECS:-2}"
DELAI_S="${TEMOIN_DELAI_S:-20}"
TRANSPORT="${TEMOIN_TRANSPORT:-resend}"          # resend | fichier (banc)
DESTINATAIRES="${TEMOIN_DESTINATAIRES:-}"         # adresses separees par des virgules
EXPEDITEUR="${TEMOIN_EXPEDITEUR:-}"               # « AnarBib <adresse du domaine d'envoi> »
RESEND_API_KEY="${RESEND_API_KEY:-}"
RESEND_URL="${TEMOIN_RESEND_URL:-https://api.resend.com/emails}"
TABLEAU_DE_BORD="${TEMOIN_TABLEAU_DE_BORD:-https://supabase.com/dashboard/project/uflwmikiyjfnikiphtcp}"
FUSEAU="${TEMOIN_FUSEAU:-Europe/Paris}"

info() { echo ">>> $*"; }
die()  { echo "ERREUR: $*" >&2; exit 2; }

command -v curl >/dev/null 2>&1 || die "outil manquant: curl"
[ -n "$DESTINATAIRES" ] || die "temoin non configure : TEMOIN_DESTINATAIRES vide ($CONF)"
[ -n "$EXPEDITEUR" ]    || die "temoin non configure : TEMOIN_EXPEDITEUR vide ($CONF)"
case "$TRANSPORT" in
  resend)  [ -n "$RESEND_API_KEY" ] || die "temoin non configure : RESEND_API_KEY vide ($CONF)" ;;
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
case "$etat" in ok|panne) ;; *) etat=ok ;; esac
ecrire_etat() {   # $1 echecs, $2 etat, $3 depuis, $4 detail
  printf 'echecs=%s\netat=%s\ndepuis=%s\ndernier_passage=%s\ndetail=%s\n' \
    "$1" "$2" "$3" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$4" > "$ETAT"
}

# --- Les sondes ---------------------------------------------------------------
# stdout = « <code HTTP> » (000 si la connexion a echoue) ; retour = 0 si l'API a
# repondu 2xx, 1 sinon. La cle publiable est exigee par la passerelle meme pour
# la sante d'Auth.
sonde() {
  local code
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time "$DELAI_S" \
            -H "apikey: $CLE_PUBLIABLE" -H "Accept-Profile: api" "$1" 2>/dev/null)" || code="000"
  printf '%s' "$code"
  case "$code" in 2[0-9][0-9]) return 0 ;; *) return 1 ;; esac
}
# Le controle : un hote sans rapport avec la base ; il suffit qu'il REPONDE.
controle_repond() {
  local code
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time "$DELAI_S" "$URL_CONTROLE" 2>/dev/null)" || return 1
  case "$code" in 000) return 1 ;; *) return 0 ;; esac
}

maintenant=$(date +%s)
heure_locale() { TZ="$FUSEAU" date -d "@$1" '+%d/%m/%Y %H:%M'; }

rest_ok=0; auth_ok=0
code_rest="$(sonde "$URL_REST")" && rest_ok=1
code_auth="$(sonde "$URL_AUTH")" && auth_ok=1
info "Temoin de panne — $(heure_locale "$maintenant") $FUSEAU — REST $code_rest, Auth $code_auth (etat precedent : $etat, echecs $echecs)"

# --- Le courriel ----------------------------------------------------------------
json_chaine() {   # echappe une chaine pour JSON (guillemets, antislash, sauts de ligne)
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
if [ $rest_ok = 1 ]; then
  if [ "$etat" = panne ]; then
    duree_min=$(( (maintenant - depuis) / 60 ))
    sujet="AnarBib — la base répond de nouveau (panne de ${duree_min} min, témoin du poste)"
    texte="La base de production répond de nouveau depuis le poste, le $(heure_locale "$maintenant") ($FUSEAU).

Panne constatée par le témoin : du $(heure_locale "$depuis") au $(heure_locale "$maintenant"), soit ${duree_min} minutes environ (à cinq minutes près : le témoin passe toutes les cinq minutes).
Sondes à cet instant : lecture REST $code_rest, santé d'Auth $code_auth.

Ce qui reste à faire : relire les journaux du projet sur le tableau de bord ($TABLEAU_DE_BORD) et noter la cause dans le backlog (item I32)."
    if envoyer "$sujet" "$texte"; then
      ecrire_etat 0 ok 0 "retour $code_rest/$code_auth"
    else
      ecrire_etat 0 panne "$depuis" "retour non notifie $code_rest/$code_auth"
      exit 0
    fi
  else
    ecrire_etat 0 ok 0 "ok $code_rest/$code_auth"
  fi
  [ $auth_ok = 1 ] || info "Auth ne repond pas ($code_auth) alors que REST repond : note au journal, pas d'alerte."
  info "L'API repond."
  exit 0
fi

# L'API ne repond pas : le poste voit-il le reste du monde ?
if ! controle_repond; then
  info "AVEUGLE : ni l'API ni $URL_CONTROLE ne repondent — le poste est sans reseau, pas de verdict, pas d'echec compte."
  ecrire_etat "$echecs" "$etat" "$depuis" "aveugle $code_rest/$code_auth"
  exit 3
fi

echecs=$((echecs + 1))
if [ "$etat" = panne ]; then
  ecrire_etat "$echecs" panne "$depuis" "panne en cours $code_rest/$code_auth"
  info "PANNE EN COURS depuis $(heure_locale "$depuis") — ${echecs} passage(s) sans reponse."
  exit 1
fi
if [ "$echecs" -lt "$SEUIL_ECHECS" ]; then
  ecrire_etat "$echecs" ok 0 "echec $echecs/$SEUIL_ECHECS $code_rest/$code_auth"
  info "L'API ne repond pas ($code_rest) — echec $echecs sur $SEUIL_ECHECS avant d'ecrire."
  exit 1
fi

debut=$(( maintenant - (echecs - 1) * 300 ))
sujet="AnarBib — la base ne répond plus (témoin du poste, $(TZ="$FUSEAU" date -d "@$maintenant" '+%H:%M'))"
texte="Depuis le poste, l'API de production ne répond plus : ${echecs} passages de suite sans réponse, le dernier le $(heure_locale "$maintenant") ($FUSEAU).

Sondes : lecture REST → $code_rest ; santé d'Auth → $code_auth (000 = pas de connexion ; 5xx = passerelle sans base). L'adresse de contrôle ($URL_CONTROLE) répond : le poste a bien le réseau, c'est la base.

Ce que ce courriel ne dit pas : la cause. Le témoin ne lit rien dans la base, il ne peut que constater qu'elle ne répond pas.

À faire : ouvrir le tableau de bord du projet ($TABLEAU_DE_BORD) — état « Unhealthy », mémoire, connexions — et redémarrer le projet s'il le faut (le 07/10/2026, c'est le redémarrage qui a rendu la base). Le témoin écrira une seconde fois au retour, avec la durée."
if envoyer "$sujet" "$texte"; then
  ecrire_etat "$echecs" panne "$debut" "panne declaree $code_rest/$code_auth"
  info "PANNE DECLAREE — courriel envoye."
else
  ecrire_etat "$echecs" ok 0 "panne non notifiee $code_rest/$code_auth"
fi
exit 1
