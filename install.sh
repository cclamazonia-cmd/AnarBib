#!/usr/bin/env bash
# =============================================================================
# AnarBib — script d'installation centralisé tout-en-un (Backend + Frontend)
# =============================================================================
# Ce script installe, configure et démarre l'INTEGRALITÉ d'AnarBib en une seule
# commande :
#   1. La pile backend complète (6 conteneurs Docker : Postgres, PostgREST,
#      GoTrue, Storage, Edge Functions, et passerelle Caddy).
#   2. Les 308 migrations SQL rejouées de zéro et vérifiées.
#   3. La configuration automatique du frontend (.env.local).
#   4. L'installation des dépendances frontend (npm ci).
#   5. Le lancement automatique du serveur web (Vite) prêt dans le navigateur.
#
# USAGE :
#   ./install.sh                # installation et démarrage complet (Backend + Frontend)
#   ./install.sh --local        # force la configuration pour localhost
#   ./install.sh --prod DOMAINE # configure pour un domaine public (ex: api.anarbib.org)
#   ./install.sh --rebuild      # réinitialise les volumes avant réinstallation
#   ./install.sh --sans-front   # démarre uniquement la pile backend (sans Vite)
#   ./install.sh --sans-start   # prépare la configuration sans rien démarrer
#   ./install.sh --stop         # arrête l'application web et les conteneurs
#   ./install.sh -h | --help    # affiche ce message d'aide
# =============================================================================

set -euo pipefail

RACINE="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "✗ Hors d'un dépôt git. Exécutez ce script depuis la racine d'AnarBib." >&2
  exit 1
}
cd "$RACINE"

MODE="local"
DOMAINE_PROD=""
REBUILD=0
START=1
START_FRONT=1
ACTION="install"

while [ $# -gt 0 ]; do
  case "$1" in
    --local)
      MODE="local"
      ;;
    --prod|--production)
      MODE="prod"
      DOMAINE_PROD="${2:-}"
      if [ -z "$DOMAINE_PROD" ] || [ "${DOMAINE_PROD#--}" != "$DOMAINE_PROD" ]; then
        echo "✗ Domaine manquant pour --prod. Exemple : ./install.sh --prod api.anarbib.org" >&2
        exit 1
      fi
      shift
      ;;
    --rebuild)
      REBUILD=1
      ;;
    --sans-front)
      START_FRONT=0
      ;;
    --sans-start)
      START=0
      START_FRONT=0
      ;;
    --stop)
      ACTION="stop"
      ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *)
      echo "✗ Option inconnue : $1" >&2
      echo "  Utilisez ./install.sh --help pour voir les options disponibles." >&2
      exit 2
      ;;
  esac
  shift
done

dire() { printf '\n\033[1;36m── %s\033[0m\n' "$*"; }
succes() { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
avertir() { printf '\033[1;33m⚠\033[0m %s\n' "$*"; }
erreur() { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; }

# ─────────────────────────────────────────────────────────────────────────────
# Arrêt complet de l'application si demandé (--stop)
# ─────────────────────────────────────────────────────────────────────────────
if [ "$ACTION" = "stop" ]; then
  dire "Arrêt d'AnarBib (Frontend + Backend)"
  if [ -f .vite.pid ]; then
    PID="$(cat .vite.pid)"
    if kill -0 "$PID" 2>/dev/null; then
      kill "$PID" 2>/dev/null || true
      succes "Serveur web frontend arrêté (PID $PID)"
    fi
    rm -f .vite.pid
  fi
  # Tuer tout processus vite restant sur le port 5173
  pkill -f "vite.*5173" 2>/dev/null || true

  cd deploy
  docker compose down
  succes "Pile backend arrêtée."
  exit 0
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║          AnarBib — Installateur centralisé tout-en-un             ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 1. Vérification des prérequis système
# ─────────────────────────────────────────────────────────────────────────────
dire "1/5 · Vérification des prérequis système"

if ! command -v docker >/dev/null 2>&1; then
  erreur "Docker est introuvable. Installez Docker avant de continuer."
  exit 1
fi
succes "Docker est présent ($(docker --version | cut -d, -f1))"

if ! docker compose version >/dev/null 2>&1; then
  erreur "Le plugin 'docker compose' est introuvable."
  exit 1
fi
succes "Docker Compose est prêt ($(docker compose version --short))"

if ! docker info >/dev/null 2>&1; then
  erreur "Le démon Docker ne répond pas. Vérifiez que le service Docker est démarré."
  exit 1
fi
succes "Démon Docker opérationnel"

if ! command -v npm >/dev/null 2>&1; then
  erreur "Node.js / npm est introuvable. Installez Node.js pour faire tourner l'application."
  exit 1
fi
succes "Node.js / npm est prêt ($(node --version) / npm $(npm --version))"

# ─────────────────────────────────────────────────────────────────────────────
# 2. Configuration des environnements et génération des secrets
# ─────────────────────────────────────────────────────────────────────────────
dire "2/5 · Initialisation des environnements et génération des clés"

if [ ! -f deploy/.env ]; then
  cp deploy/.env.example deploy/.env
  succes "Fichier deploy/.env créé depuis deploy/.env.example"
fi

if [ ! -f deploy/functions.env ]; then
  cp deploy/functions.env.example deploy/functions.env
  succes "Fichier deploy/functions.env créé depuis deploy/functions.env.example"
fi

echo "→ Génération automatique des clés JWT et mots de passe..."
GEN_FLAG="--local"
if [ "$MODE" = "prod" ]; then
  GEN_FLAG=""
fi
(cd deploy && node genkeys.mjs $GEN_FLAG)
succes "Clés et secrets configurés dans deploy/.env"

if [ "$MODE" = "prod" ] && [ -n "$DOMAINE_PROD" ]; then
  sed -i "s|^API_DOMAIN=.*|API_DOMAIN=${DOMAINE_PROD}|" deploy/.env
  sed -i "s|^API_EXTERNAL_URL=.*|API_EXTERNAL_URL=https://${DOMAINE_PROD}|" deploy/.env
  succes "Domaine de production configuré : https://${DOMAINE_PROD}"
fi

# Configuration du service de messagerie (interactive si terminal interactif et non configuré)
CURRENT_TRANSPORT="$(grep '^MAIL_TRANSPORT=' deploy/functions.env 2>/dev/null | cut -d= -f2- || echo "")"
CURRENT_SMTP="$(grep '^SMTP_HOST=' deploy/functions.env 2>/dev/null | cut -d= -f2- || echo "")"
CURRENT_RESEND="$(grep '^RESEND_API_KEY=' deploy/functions.env 2>/dev/null | cut -d= -f2- || echo "")"

if [ -t 0 ] && [ -z "$CURRENT_SMTP" ] && [ -z "$CURRENT_RESEND" ]; then
  echo ""
  echo "📧 Configuration du service d'e-mail pour les notifications :"
  echo "   [1] Aucun / Test en local (les e-mails sont simulés, aucun compte requis) [Défaut]"
  echo "   [2] Serveur SMTP standard (votre propre boîte mail : OVH, Gandi, Infomaniak, etc.)"
  echo "   [3] Clé API Resend (service tiers clé en main)"
  read -r -p "Votre choix [1/2/3] (défaut: 1) : " MAIL_CHOICE
  MAIL_CHOICE="${MAIL_CHOICE:-1}"

  case "$MAIL_CHOICE" in
    2)
      echo ""
      echo "→ Configuration SMTP :"
      read -r -p "  Hôte SMTP (ex: mail.mon-domaine.org) : " CFG_SMTP_HOST
      read -r -p "  Port SMTP (ex: 587 ou 465) [défaut: 587] : " CFG_SMTP_PORT
      CFG_SMTP_PORT="${CFG_SMTP_PORT:-587}"
      read -r -p "  Utilisateur SMTP (votre adresse mail) : " CFG_SMTP_USER
      read -r -s -p "  Mot de passe SMTP : " CFG_SMTP_PASS
      echo ""
      read -r -p "  Adresse d'expédition (From) [défaut: ${CFG_SMTP_USER}] : " CFG_SENDER_EMAIL
      CFG_SENDER_EMAIL="${CFG_SENDER_EMAIL:-$CFG_SMTP_USER}"

      CFG_SECURE="false"
      if [ "$CFG_SMTP_PORT" = "465" ]; then
        CFG_SECURE="true"
      fi

      sed -i "s|^MAIL_TRANSPORT=.*|MAIL_TRANSPORT=smtp|" deploy/functions.env
      sed -i "s|^SMTP_HOST=.*|SMTP_HOST=${CFG_SMTP_HOST}|" deploy/functions.env
      sed -i "s|^SMTP_PORT=.*|SMTP_PORT=${CFG_SMTP_PORT}|" deploy/functions.env
      sed -i "s|^SMTP_USER=.*|SMTP_USER=${CFG_SMTP_USER}|" deploy/functions.env
      sed -i "s|^SMTP_PASS=.*|SMTP_PASS=${CFG_SMTP_PASS}|" deploy/functions.env
      sed -i "s|^SMTP_SECURE=.*|SMTP_SECURE=${CFG_SECURE}|" deploy/functions.env
      sed -i "s|^SENDER_EMAIL=.*|SENDER_EMAIL=${CFG_SENDER_EMAIL}|" deploy/functions.env
      succes "Service SMTP configuré (${CFG_SMTP_HOST}:${CFG_SMTP_PORT})"
      ;;
    3)
      echo ""
      echo "→ Configuration API Resend :"
      read -r -p "  Clé API Resend (ex: re_123456...) : " CFG_RESEND_KEY
      read -r -p "  Adresse d'expédition vérifiée sur Resend : " CFG_RESEND_SENDER
      sed -i "s|^MAIL_TRANSPORT=.*|MAIL_TRANSPORT=resend|" deploy/functions.env
      sed -i "s|^RESEND_API_KEY=.*|RESEND_API_KEY=${CFG_RESEND_KEY}|" deploy/functions.env
      sed -i "s|^SENDER_EMAIL=.*|SENDER_EMAIL=${CFG_RESEND_SENDER}|" deploy/functions.env
      succes "Service Resend configuré (${CFG_RESEND_SENDER})"
      ;;
    *)
      sed -i "s|^MAIL_TRANSPORT=.*|MAIL_TRANSPORT=mock|" deploy/functions.env
      succes "Mode local activé (e-mails journalisés sans envoi externe)"
      ;;
  esac
fi

# ─────────────────────────────────────────────────────────────────────────────
# 3. Configuration et compilation du frontend
# ─────────────────────────────────────────────────────────────────────────────
dire "3/4 · Configuration et compilation du frontend"

ANON_KEY="$(grep '^ANON_KEY=' deploy/.env | cut -d= -f2-)"
API_URL="$(grep '^API_EXTERNAL_URL=' deploy/.env | cut -d= -f2-)"

cat > .env.local << EOF
# Généré automatiquement par ./install.sh
VITE_SUPABASE_URL=${API_URL}
VITE_SUPABASE_PUBLISHABLE_KEY=${ANON_KEY}
EOF
succes "Fichier .env.local créé et relié à la passerelle locale (${API_URL})"

if [ ! -d "node_modules" ] || [ ! -f "node_modules/.bin/vite" ]; then
  echo "→ Installation des dépendances JavaScript (npm ci)..."
  npm ci
  succes "Dépendances frontend installées."
else
  succes "Dépendances frontend déjà présentes (node_modules/)"
fi

if [ ! -d "dist" ] || [ "$REBUILD" = "1" ] || [ ! -f "dist/index.html" ]; then
  echo "→ Construction de l'application web pour Caddy (npm run build)..."
  npm run build
  succes "Application web compilée dans dist/."
else
  succes "Application web déjà prête (dist/)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 4. Démarrage de la pile complète dans Docker (6 conteneurs)
# ─────────────────────────────────────────────────────────────────────────────
if [ "$START" = "1" ]; then
  dire "4/4 · Déploiement et démarrage de la pile complète (Docker)"

  cd deploy

  if [ "$REBUILD" = "1" ]; then
    echo "→ Nettoyage des conteneurs et volumes existants (--rebuild)..."
    docker compose down -v
    ./bootstrap.sh --depuis-le-depot --sel-jetable
  else
    # S'assurer que le dossier dist existe avant le montage Docker
    mkdir -p ../dist
    
    # Vérifier si la base existe déjà et contient des tables
    docker compose up -d db >/dev/null 2>&1
    sleep 2
    NB_TABLES="$(docker compose exec -T db psql -U supabase_admin -d postgres -tAc "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';" 2>/dev/null || echo "0")"
    
    if [ "$NB_TABLES" -gt 0 ]; then
      echo "→ Base existante détectée ($NB_TABLES tables). Démarrage des conteneurs et vérification des migrations..."
      docker compose up -d
      docker compose exec -T db sh /scripts/apply-pending-migrations.sh
    else
      echo "→ Base vierge détectée. Lancement de l'amorçage complet..."
      ./bootstrap.sh --depuis-le-depot --sel-jetable
    fi
  fi
  cd "$RACINE"

  dire "Contrôle de santé global des services"
  ./deploy/deploy.sh --controle

  # Initialisation du compte administrateur si la base est neuve
  node deploy/scripts/seed-admin.mjs "$MODE" "$DOMAINE_PROD"
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║          ✓ AnarBib est installé et prêt à être utilisé !         ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""
echo "  👉 Ouvrez votre navigateur sur :"
echo "     • Local       : http://localhost:5173  (ou http://localhost)"
echo "     • Réseau (IP) : http://$(ip -4 addr show scope global 2>/dev/null | grep inet | head -n1 | awk '{print $2}' | cut -d/ -f1 || echo "IP_HOTE"):5173"
echo "     • Domaine     : tout nom de domaine ou alias DNS pointant vers cette machine"
echo ""

if [ -f deploy/.initial_admin_creds ]; then
  ADMIN_EMAIL="$(grep '^ADMIN_EMAIL=' deploy/.initial_admin_creds | cut -d= -f2-)"
  ADMIN_PASSWORD="$(grep '^ADMIN_PASSWORD=' deploy/.initial_admin_creds | cut -d= -f2-)"
  rm -f deploy/.initial_admin_creds

  echo "👤 Compte d'administration initial créé :"
  echo "  • Courriel     : ${ADMIN_EMAIL}"
  echo "  • Mot de passe : ${ADMIN_PASSWORD}"
  if [ "$MODE" = "prod" ]; then
    echo "  ⚠️  Pensez à modifier ce mot de passe dès votre première connexion !"
  fi
  echo ""
fi

echo "Points d'accès de votre installation :"
echo "  • Application Web (Interface) : port 5173 ou port 80 (IP, domaine ou localhost)"
echo "  • Passerelle API (Caddy)       : /rest/v1/, /auth/v1/, /storage/v1/, /functions/v1/"
echo "  • Point de santé Auth         : /auth/v1/health"
echo "  • Point de santé API REST     : /rest/v1/"
echo ""
echo "Gestion de l'application :"
echo "  • Arrêter l'ensemble         : ./install.sh --stop"
echo "  • Réinitialiser de zéro      : ./install.sh --rebuild"
echo "  • Vérifier la santé          : ./deploy/deploy.sh --controle"
echo "  • Mettre à jour le code      : ./deploy/deploy.sh"
echo ""
