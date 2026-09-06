#!/usr/bin/env bash
# =============================================================================
# AnarBib — All-in-one centralized installer (Backend + Frontend)
# =============================================================================
# Installs, configures and starts the entire AnarBib stack in one command.
#
# USAGE:
#   ./install.sh                       # full install and start
#   ./install.sh --lang fr|en|pt       # force display language
#   ./install.sh --local               # force localhost configuration
#   ./install.sh --prod DOMAIN         # configure for a public domain
#   ./install.sh --rebuild             # wipe volumes and reinstall from scratch
#   ./install.sh --sans-front          # start backend only (no Vite)
#   ./install.sh --sans-start          # prepare config without starting
#   ./install.sh --stop                # stop all containers
#   ./install.sh -h | --help           # show this help
# =============================================================================

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Language detection (must happen before any output or argument parsing)
# ─────────────────────────────────────────────────────────────────────────────
_SYS_LANG="${LANG:-${LC_ALL:-${LC_MESSAGES:-}}}"
case "${_SYS_LANG%%_*}" in
  fr) LANG_CODE="fr" ;;
  pt) LANG_CODE="pt" ;;
  *)  LANG_CODE="en" ;;
esac

# Pre-scan for --lang before full argument parsing so t() works immediately
for _arg in "$@"; do
  case "$_arg" in --lang) _NEXT_IS_LANG=1 ;; *)
    if [ "${_NEXT_IS_LANG:-0}" = "1" ]; then
      case "$_arg" in
        fr|en|pt) LANG_CODE="$_arg" ;;
      esac
      _NEXT_IS_LANG=0
    fi
  ;; esac
done
unset _SYS_LANG _NEXT_IS_LANG _arg

# ─────────────────────────────────────────────────────────────────────────────
# Translation function — t KEY [ARG]
# All user-visible strings are here. $2 is an optional interpolated argument.
# ─────────────────────────────────────────────────────────────────────────────
t() {
  case "${LANG_CODE}:$1" in

    # ── system / errors ──────────────────────────────────────────────────────
    fr:err_no_git)     echo "Hors d'un dépôt git. Exécutez ce script depuis la racine d'AnarBib." ;;
    en:err_no_git)     echo "Not in a git repository. Run this script from the AnarBib root." ;;
    pt:err_no_git)     echo "Fora de um repositório git. Execute este script na raiz do AnarBib." ;;

    fr:err_no_domain)  echo "Domaine manquant pour --prod. Exemple : ./install.sh --prod api.anarbib.org" ;;
    en:err_no_domain)  echo "Missing domain for --prod. Example: ./install.sh --prod api.anarbib.org" ;;
    pt:err_no_domain)  echo "Domínio ausente para --prod. Exemplo: ./install.sh --prod api.anarbib.org" ;;

    fr:err_unknown)    echo "Option inconnue : $2" ;;
    en:err_unknown)    echo "Unknown option: $2" ;;
    pt:err_unknown)    echo "Opção desconhecida: $2" ;;

    fr:err_help_hint)  echo "  Utilisez ./install.sh --help pour voir les options disponibles." ;;
    en:err_help_hint)  echo "  Use ./install.sh --help to see available options." ;;
    pt:err_help_hint)  echo "  Use ./install.sh --help para ver as opções disponíveis." ;;

    fr:err_lang)       echo "Langue non reconnue : '$2'. Valeurs acceptées : fr, en, pt" ;;
    en:err_lang)       echo "Unknown language: '$2'. Accepted values: fr, en, pt" ;;
    pt:err_lang)       echo "Idioma não reconhecido: '$2'. Valores aceitos: fr, en, pt" ;;

    # ── --stop action ────────────────────────────────────────────────────────
    fr:stop_title)     echo "Arrêt d'AnarBib (Frontend + Backend)" ;;
    en:stop_title)     echo "Stopping AnarBib (Frontend + Backend)" ;;
    pt:stop_title)     echo "Parando AnarBib (Frontend + Backend)" ;;

    fr:stop_frontend)  echo "Serveur web frontend arrêté (PID $2)" ;;
    en:stop_frontend)  echo "Frontend web server stopped (PID $2)" ;;
    pt:stop_frontend)  echo "Servidor web frontend parado (PID $2)" ;;

    fr:stop_backend)   echo "Pile backend arrêtée." ;;
    en:stop_backend)   echo "Backend stack stopped." ;;
    pt:stop_backend)   echo "Pilha backend parada." ;;

    # ── banner ───────────────────────────────────────────────────────────────
    fr:banner)         echo "AnarBib — Installateur centralisé tout-en-un" ;;
    en:banner)         echo "AnarBib — All-in-one centralized installer" ;;
    pt:banner)         echo "AnarBib — Instalador centralizado completo" ;;

    # ── step 1 ───────────────────────────────────────────────────────────────
    fr:step1)          echo "1/5 · Vérification des prérequis système" ;;
    en:step1)          echo "1/5 · Checking system prerequisites" ;;
    pt:step1)          echo "1/5 · Verificação dos pré-requisitos do sistema" ;;

    fr:err_docker)     echo "Docker est introuvable. Installez Docker avant de continuer." ;;
    en:err_docker)     echo "Docker not found. Please install Docker before continuing." ;;
    pt:err_docker)     echo "Docker não encontrado. Instale o Docker antes de continuar." ;;

    fr:ok_docker)      echo "Docker est présent ($2)" ;;
    en:ok_docker)      echo "Docker is ready ($2)" ;;
    pt:ok_docker)      echo "Docker encontrado ($2)" ;;

    fr:err_compose)    echo "Le plugin 'docker compose' est introuvable." ;;
    en:err_compose)    echo "The 'docker compose' plugin is not found." ;;
    pt:err_compose)    echo "O plugin 'docker compose' não foi encontrado." ;;

    fr:ok_compose)     echo "Docker Compose est prêt ($2)" ;;
    en:ok_compose)     echo "Docker Compose is ready ($2)" ;;
    pt:ok_compose)     echo "Docker Compose pronto ($2)" ;;

    fr:err_daemon)     echo "Le démon Docker ne répond pas. Vérifiez que le service Docker est démarré." ;;
    en:err_daemon)     echo "Docker daemon not responding. Make sure the Docker service is running." ;;
    pt:err_daemon)     echo "Docker daemon não responde. Verifique se o serviço Docker está em execução." ;;

    fr:ok_daemon)      echo "Démon Docker opérationnel" ;;
    en:ok_daemon)      echo "Docker daemon running" ;;
    pt:ok_daemon)      echo "Docker daemon operacional" ;;

    fr:err_node)       echo "Node.js / npm est introuvable. Installez Node.js pour faire tourner l'application." ;;
    en:err_node)       echo "Node.js / npm not found. Install Node.js to run the application." ;;
    pt:err_node)       echo "Node.js / npm não encontrado. Instale o Node.js para executar a aplicação." ;;

    fr:ok_node)        echo "Node.js / npm est prêt ($2)" ;;
    en:ok_node)        echo "Node.js / npm ready ($2)" ;;
    pt:ok_node)        echo "Node.js / npm pronto ($2)" ;;

    # ── step 2 ───────────────────────────────────────────────────────────────
    fr:step2)          echo "2/5 · Initialisation des environnements et génération des clés" ;;
    en:step2)          echo "2/5 · Environment setup and key generation" ;;
    pt:step2)          echo "2/5 · Configuração do ambiente e geração de chaves" ;;

    fr:ok_env)         echo "Fichier deploy/.env créé depuis deploy/.env.example" ;;
    en:ok_env)         echo "File deploy/.env created from deploy/.env.example" ;;
    pt:ok_env)         echo "Arquivo deploy/.env criado a partir de deploy/.env.example" ;;

    fr:ok_fenv)        echo "Fichier deploy/functions.env créé depuis deploy/functions.env.example" ;;
    en:ok_fenv)        echo "File deploy/functions.env created from deploy/functions.env.example" ;;
    pt:ok_fenv)        echo "Arquivo deploy/functions.env criado a partir de deploy/functions.env.example" ;;

    fr:gen_keys)       echo "→ Génération automatique des clés JWT et mots de passe..." ;;
    en:gen_keys)       echo "→ Auto-generating JWT keys and passwords..." ;;
    pt:gen_keys)       echo "→ Gerando chaves JWT e senhas automaticamente..." ;;

    fr:ok_keys)        echo "Clés et secrets configurés dans deploy/.env" ;;
    en:ok_keys)        echo "Keys and secrets configured in deploy/.env" ;;
    pt:ok_keys)        echo "Chaves e segredos configurados em deploy/.env" ;;

    fr:ok_prod_domain) echo "Domaine de production configuré : https://$2" ;;
    en:ok_prod_domain) echo "Production domain configured: https://$2" ;;
    pt:ok_prod_domain) echo "Domínio de produção configurado: https://$2" ;;

    # ── mail config ──────────────────────────────────────────────────────────
    fr:mail_title)     echo "📧 Configuration du service d'e-mail pour les notifications :" ;;
    en:mail_title)     echo "📧 Email service configuration for notifications:" ;;
    pt:mail_title)     echo "📧 Configuração do serviço de e-mail para notificações:" ;;

    fr:mail_opt1)      echo "   [1] Aucun / Test en local (les e-mails sont simulés, aucun compte requis) [Défaut]" ;;
    en:mail_opt1)      echo "   [1] None / Local test (emails are simulated, no account needed) [Default]" ;;
    pt:mail_opt1)      echo "   [1] Nenhum / Teste local (e-mails simulados, nenhuma conta necessária) [Padrão]" ;;

    fr:mail_opt2)      echo "   [2] Serveur SMTP standard (votre propre boîte mail : OVH, Gandi, Infomaniak, etc.)" ;;
    en:mail_opt2)      echo "   [2] Standard SMTP server (your own mailbox: Gmail, Gandi, Infomaniak, etc.)" ;;
    pt:mail_opt2)      echo "   [2] Servidor SMTP padrão (sua própria caixa de correio: Gmail, Gandi, etc.)" ;;

    fr:mail_opt3)      echo "   [3] Clé API Resend (service tiers clé en main)" ;;
    en:mail_opt3)      echo "   [3] Resend API key (third-party turnkey service)" ;;
    pt:mail_opt3)      echo "   [3] Chave API Resend (serviço terceirizado pronto para uso)" ;;

    fr:mail_prompt)    printf "Votre choix [1/2/3] (défaut: 1) : " ;;
    en:mail_prompt)    printf "Your choice [1/2/3] (default: 1): " ;;
    pt:mail_prompt)    printf "Sua escolha [1/2/3] (padrão: 1): " ;;

    fr:smtp_title)     echo "→ Configuration SMTP :" ;;
    en:smtp_title)     echo "→ SMTP configuration:" ;;
    pt:smtp_title)     echo "→ Configuração SMTP:" ;;

    fr:smtp_host)      printf "  Hôte SMTP (ex: mail.mon-domaine.org) : " ;;
    en:smtp_host)      printf "  SMTP host (e.g. mail.example.org): " ;;
    pt:smtp_host)      printf "  Host SMTP (ex: mail.meu-dominio.org): " ;;

    fr:smtp_port)      printf "  Port SMTP (ex: 587 ou 465) [défaut: 587] : " ;;
    en:smtp_port)      printf "  SMTP port (e.g. 587 or 465) [default: 587]: " ;;
    pt:smtp_port)      printf "  Porta SMTP (ex: 587 ou 465) [padrão: 587]: " ;;

    fr:smtp_user)      printf "  Utilisateur SMTP (votre adresse mail) : " ;;
    en:smtp_user)      printf "  SMTP user (your email address): " ;;
    pt:smtp_user)      printf "  Usuário SMTP (seu endereço de e-mail): " ;;

    fr:smtp_pass)      printf "  Mot de passe SMTP : " ;;
    en:smtp_pass)      printf "  SMTP password: " ;;
    pt:smtp_pass)      printf "  Senha SMTP: " ;;

    fr:smtp_sender)    printf "  Adresse d'expédition (From) [défaut: %s] : " "$2" ;;
    en:smtp_sender)    printf "  Sender address (From) [default: %s]: " "$2" ;;
    pt:smtp_sender)    printf "  Endereço de envio (From) [padrão: %s]: " "$2" ;;

    fr:ok_smtp)        echo "Service SMTP configuré ($2)" ;;
    en:ok_smtp)        echo "SMTP service configured ($2)" ;;
    pt:ok_smtp)        echo "Serviço SMTP configurado ($2)" ;;

    fr:resend_title)   echo "→ Configuration API Resend :" ;;
    en:resend_title)   echo "→ Resend API configuration:" ;;
    pt:resend_title)   echo "→ Configuração API Resend:" ;;

    fr:resend_key)     printf "  Clé API Resend (ex: re_123456...) : " ;;
    en:resend_key)     printf "  Resend API key (e.g. re_123456...): " ;;
    pt:resend_key)     printf "  Chave API Resend (ex: re_123456...): " ;;

    fr:resend_sender)  printf "  Adresse d'expédition vérifiée sur Resend : " ;;
    en:resend_sender)  printf "  Verified sender address on Resend: " ;;
    pt:resend_sender)  printf "  Endereço de envio verificado no Resend: " ;;

    fr:ok_resend)      echo "Service Resend configuré ($2)" ;;
    en:ok_resend)      echo "Resend service configured ($2)" ;;
    pt:ok_resend)      echo "Serviço Resend configurado ($2)" ;;

    fr:ok_mock)        echo "Mode local activé (e-mails journalisés sans envoi externe)" ;;
    en:ok_mock)        echo "Local mode activated (emails logged, no external sending)" ;;
    pt:ok_mock)        echo "Modo local ativado (e-mails registrados sem envio externo)" ;;

    # ── library name (GOUV-19) ────────────────────────────────────────────────
    fr:lib_title)      echo "📚 Initialisation de votre première bibliothèque (GOUV-19) :" ;;
    en:lib_title)      echo "📚 Initializing your first library (GOUV-19):" ;;
    pt:lib_title)      echo "📚 Inicialização da sua primeira biblioteca (GOUV-19):" ;;

    fr:lib_prompt)     printf "  Nom de votre bibliothèque [défaut: %s] : " "$2" ;;
    en:lib_prompt)     printf "  Library name [default: %s]: " "$2" ;;
    pt:lib_prompt)     printf "  Nome da sua biblioteca [padrão: %s]: " "$2" ;;

    fr:ok_lib)         echo "Bibliothèque configurée : $2" ;;
    en:ok_lib)         echo "Library configured: $2" ;;
    pt:ok_lib)         echo "Biblioteca configurada: $2" ;;

    fr:admin_lib)      echo "  • Bibliothèque : $2" ;;
    en:admin_lib)      echo "  • Library      : $2" ;;
    pt:admin_lib)      echo "  • Biblioteca   : $2" ;;

    # ── step 3 ───────────────────────────────────────────────────────────────
    fr:step3)          echo "3/4 · Configuration et compilation du frontend" ;;
    en:step3)          echo "3/4 · Frontend configuration and build" ;;
    pt:step3)          echo "3/4 · Configuração e compilação do frontend" ;;

    fr:ok_envlocal)    echo "Fichier .env.local créé et relié à la passerelle locale ($2)" ;;
    en:ok_envlocal)    echo "File .env.local created and linked to local gateway ($2)" ;;
    pt:ok_envlocal)    echo "Arquivo .env.local criado e vinculado ao gateway local ($2)" ;;

    fr:npm_install)    echo "→ Installation des dépendances JavaScript (npm ci)..." ;;
    en:npm_install)    echo "→ Installing JavaScript dependencies (npm ci)..." ;;
    pt:npm_install)    echo "→ Instalando dependências JavaScript (npm ci)..." ;;

    fr:ok_deps)        echo "Dépendances frontend installées." ;;
    en:ok_deps)        echo "Frontend dependencies installed." ;;
    pt:ok_deps)        echo "Dependências frontend instaladas." ;;

    fr:ok_deps_exist)  echo "Dépendances frontend déjà présentes (node_modules/)" ;;
    en:ok_deps_exist)  echo "Frontend dependencies already present (node_modules/)" ;;
    pt:ok_deps_exist)  echo "Dependências frontend já presentes (node_modules/)" ;;

    fr:npm_build)      echo "→ Construction de l'application web pour Caddy (npm run build)..." ;;
    en:npm_build)      echo "→ Building web application for Caddy (npm run build)..." ;;
    pt:npm_build)      echo "→ Construindo aplicação web para o Caddy (npm run build)..." ;;

    fr:ok_build)       echo "Application web compilée dans dist/." ;;
    en:ok_build)       echo "Web application built in dist/." ;;
    pt:ok_build)       echo "Aplicação web compilada em dist/." ;;

    fr:ok_build_exist) echo "Application web déjà prête (dist/)" ;;
    en:ok_build_exist) echo "Web application already ready (dist/)" ;;
    pt:ok_build_exist) echo "Aplicação web já pronta (dist/)" ;;

    # ── step 4 ───────────────────────────────────────────────────────────────
    fr:step4)          echo "4/4 · Déploiement et démarrage de la pile complète (Docker)" ;;
    en:step4)          echo "4/4 · Deployment and startup of the full stack (Docker)" ;;
    pt:step4)          echo "4/4 · Implantação e inicialização da pilha completa (Docker)" ;;

    fr:rebuild_clean)  echo "→ Nettoyage des conteneurs et volumes existants (--rebuild)..." ;;
    en:rebuild_clean)  echo "→ Cleaning existing containers and volumes (--rebuild)..." ;;
    pt:rebuild_clean)  echo "→ Limpando contêineres e volumes existentes (--rebuild)..." ;;

    fr:db_existing)    echo "→ Base existante détectée ($2 tables). Démarrage des conteneurs et vérification des migrations..." ;;
    en:db_existing)    echo "→ Existing database detected ($2 tables). Starting containers and checking migrations..." ;;
    pt:db_existing)    echo "→ Base de dados existente detectada ($2 tabelas). Iniciando contêineres e verificando migrações..." ;;

    fr:db_fresh)       echo "→ Base vierge détectée. Lancement de l'amorçage complet..." ;;
    en:db_fresh)       echo "→ Fresh database detected. Running full bootstrap..." ;;
    pt:db_fresh)       echo "→ Base de dados vazia detectada. Executando bootstrap completo..." ;;

    fr:health_title)   echo "Contrôle de santé global des services" ;;
    en:health_title)   echo "Global service health check" ;;
    pt:health_title)   echo "Verificação de saúde global dos serviços" ;;

    # ── final output ─────────────────────────────────────────────────────────
    fr:done_banner)    echo "✓ AnarBib est installé et prêt à être utilisé !" ;;
    en:done_banner)    echo "✓ AnarBib is installed and ready to use!" ;;
    pt:done_banner)    echo "✓ AnarBib instalado e pronto para usar!" ;;

    fr:open_browser)   echo "  👉 Ouvrez votre navigateur sur :" ;;
    en:open_browser)   echo "  👉 Open your browser at:" ;;
    pt:open_browser)   echo "  👉 Abra seu navegador em:" ;;

    fr:url_local)      echo "     • Local       : http://localhost" ;;
    en:url_local)      echo "     • Local       : http://localhost" ;;
    pt:url_local)      echo "     • Local       : http://localhost" ;;

    fr:url_network)    echo "     • Réseau (IP) : http://$2" ;;
    en:url_network)    echo "     • Network (IP): http://$2" ;;
    pt:url_network)    echo "     • Rede (IP)   : http://$2" ;;

    fr:url_domain)     echo "     • Domaine     : tout nom de domaine ou alias DNS pointant vers cette machine" ;;
    en:url_domain)     echo "     • Domain      : any domain name or DNS alias pointing to this machine" ;;
    pt:url_domain)     echo "     • Domínio     : qualquer nome de domínio ou alias DNS apontando para esta máquina" ;;

    fr:admin_title)    echo "👤 Compte d'administration initial créé (amorçage) :" ;;
    en:admin_title)    echo "👤 Initial admin account created (bootstrap):" ;;
    pt:admin_title)    echo "👤 Conta de administrador inicial criada (bootstrap):" ;;

    fr:admin_email)    echo "  • Courriel     : $2" ;;
    en:admin_email)    echo "  • Email        : $2" ;;
    pt:admin_email)    echo "  • E-mail       : $2" ;;

    fr:admin_pass)     echo "  • Mot de passe : $2" ;;
    en:admin_pass)     echo "  • Password     : $2" ;;
    pt:admin_pass)     echo "  • Senha        : $2" ;;

    fr:admin_warn)     echo "  ⚠️  Notez bien ce mot de passe aléatoire : il ne sera plus réaffiché !" ;;
    en:admin_warn)     echo "  ⚠️  Save this random password: it will not be displayed again!" ;;
    pt:admin_warn)     echo "  ⚠️  Guarde esta senha aleatória: ela não será exibida novamente!" ;;

    fr:access_title)   echo "Points d'accès de votre installation :" ;;
    en:access_title)   echo "Access points for your installation:" ;;
    pt:access_title)   echo "Pontos de acesso da sua instalação:" ;;

    fr:access_web)     echo "  • Application Web (Interface) : port 80 (ou port 5173 en mode npm run dev)" ;;
    en:access_web)     echo "  • Web Application (Interface)  : port 80 (or port 5173 in npm run dev mode)" ;;
    pt:access_web)     echo "  • Aplicação Web (Interface)    : porta 80 (ou porta 5173 no modo npm run dev)" ;;

    fr:access_api)     echo "  • Passerelle API (Caddy)       : /rest/v1/, /auth/v1/, /storage/v1/, /functions/v1/" ;;
    en:access_api)     echo "  • API Gateway (Caddy)          : /rest/v1/, /auth/v1/, /storage/v1/, /functions/v1/" ;;
    pt:access_api)     echo "  • Gateway de API (Caddy)       : /rest/v1/, /auth/v1/, /storage/v1/, /functions/v1/" ;;

    fr:access_auth)    echo "  • Point de santé Auth          : /auth/v1/health" ;;
    en:access_auth)    echo "  • Auth health endpoint         : /auth/v1/health" ;;
    pt:access_auth)    echo "  • Endpoint de saúde Auth       : /auth/v1/health" ;;

    fr:access_rest)    echo "  • Point de santé API REST      : /rest/v1/" ;;
    en:access_rest)    echo "  • REST API health endpoint     : /rest/v1/" ;;
    pt:access_rest)    echo "  • Endpoint de saúde API REST   : /rest/v1/" ;;

    fr:manage_title)   echo "Gestion de l'application :" ;;
    en:manage_title)   echo "Application management:" ;;
    pt:manage_title)   echo "Gerenciamento da aplicação:" ;;

    fr:manage_stop)    echo "  • Arrêter l'ensemble         : ./install.sh --stop" ;;
    en:manage_stop)    echo "  • Stop everything            : ./install.sh --stop" ;;
    pt:manage_stop)    echo "  • Parar tudo                 : ./install.sh --stop" ;;

    fr:manage_rebuild) echo "  • Réinitialiser de zéro      : ./install.sh --rebuild" ;;
    en:manage_rebuild) echo "  • Reset from scratch         : ./install.sh --rebuild" ;;
    pt:manage_rebuild) echo "  • Reiniciar do zero          : ./install.sh --rebuild" ;;

    fr:manage_health)  echo "  • Vérifier la santé          : ./deploy/deploy.sh --controle" ;;
    en:manage_health)  echo "  • Check health               : ./deploy/deploy.sh --controle" ;;
    pt:manage_health)  echo "  • Verificar saúde            : ./deploy/deploy.sh --controle" ;;

    fr:manage_update)  echo "  • Mettre à jour le code      : ./deploy/deploy.sh" ;;
    en:manage_update)  echo "  • Update code                : ./deploy/deploy.sh" ;;
    pt:manage_update)  echo "  • Update code                : ./deploy/deploy.sh" ;;

    *) echo "[$1]" ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Git root check (must be before argument parsing to get RACINE)
# ─────────────────────────────────────────────────────────────────────────────
RACINE="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "✗ $(t err_no_git)" >&2
  exit 1
}
cd "$RACINE"

# ─────────────────────────────────────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────────────────────────────────────
MODE="local"
DOMAINE_PROD=""
REBUILD=0
START=1
START_FRONT=1
ACTION="install"

while [ $# -gt 0 ]; do
  case "$1" in
    --lang)
      shift
      case "${1:-}" in
        fr|en|pt) LANG_CODE="$1" ;;
        *) echo "✗ $(t err_lang "${1:-}")" >&2; exit 2 ;;
      esac
      ;;
    --local)
      MODE="local"
      ;;
    --prod|--production)
      MODE="prod"
      DOMAINE_PROD="${2:-}"
      if [ -z "$DOMAINE_PROD" ] || [ "${DOMAINE_PROD#--}" != "$DOMAINE_PROD" ]; then
        echo "✗ $(t err_no_domain)" >&2
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
      sed -n '2,10p' "$0"
      exit 0
      ;;
    *)
      echo "✗ $(t err_unknown "$1")" >&2
      echo "$(t err_help_hint)" >&2
      exit 2
      ;;
  esac
  shift
done

# ─────────────────────────────────────────────────────────────────────────────
# Display helpers
# ─────────────────────────────────────────────────────────────────────────────
dire()    { printf '\n\033[1;36m── %s\033[0m\n' "$*"; }
succes()  { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
avertir() { printf '\033[1;33m⚠\033[0m %s\n' "$*"; }
erreur()  { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; }

# ─────────────────────────────────────────────────────────────────────────────
# --stop
# ─────────────────────────────────────────────────────────────────────────────
if [ "$ACTION" = "stop" ]; then
  dire "$(t stop_title)"
  if [ -f .vite.pid ]; then
    PID="$(cat .vite.pid)"
    if kill -0 "$PID" 2>/dev/null; then
      kill "$PID" 2>/dev/null || true
      succes "$(t stop_frontend "$PID")"
    fi
    rm -f .vite.pid
  fi
  pkill -f "vite.*5173" 2>/dev/null || true
  cd deploy
  docker compose down
  succes "$(t stop_backend)"
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# Banner
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
printf "║  %-65s║\n" "$(t banner)"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 1. Prerequisites
# ─────────────────────────────────────────────────────────────────────────────
dire "$(t step1)"

if ! command -v docker >/dev/null 2>&1; then
  erreur "$(t err_docker)"; exit 1
fi
succes "$(t ok_docker "$(docker --version | cut -d, -f1)")"

if ! docker compose version >/dev/null 2>&1; then
  erreur "$(t err_compose)"; exit 1
fi
succes "$(t ok_compose "$(docker compose version --short)")"

if ! docker info >/dev/null 2>&1; then
  erreur "$(t err_daemon)"; exit 1
fi
succes "$(t ok_daemon)"

if ! command -v npm >/dev/null 2>&1; then
  erreur "$(t err_node)"; exit 1
fi
succes "$(t ok_node "$(node --version) / npm $(npm --version)")"

# ─────────────────────────────────────────────────────────────────────────────
# 2. Environment & secrets
# ─────────────────────────────────────────────────────────────────────────────
dire "$(t step2)"

if [ ! -f deploy/.env ]; then
  cp deploy/.env.example deploy/.env
  succes "$(t ok_env)"
fi

if [ ! -f deploy/functions.env ]; then
  cp deploy/functions.env.example deploy/functions.env
  succes "$(t ok_fenv)"
fi

echo "$(t gen_keys)"
GEN_FLAG="--local"
[ "$MODE" = "prod" ] && GEN_FLAG=""
(cd deploy && node genkeys.mjs $GEN_FLAG)
succes "$(t ok_keys)"

if [ "$MODE" = "prod" ] && [ -n "$DOMAINE_PROD" ]; then
  sed -i "s|^API_DOMAIN=.*|API_DOMAIN=${DOMAINE_PROD}|" deploy/.env
  sed -i "s|^API_EXTERNAL_URL=.*|API_EXTERNAL_URL=https://${DOMAINE_PROD}|" deploy/.env
  succes "$(t ok_prod_domain "$DOMAINE_PROD")"
fi

# Mail configuration (interactive, only if not already set)
CURRENT_SMTP="$(grep '^SMTP_HOST=' deploy/functions.env 2>/dev/null | cut -d= -f2- || echo "")"
CURRENT_RESEND="$(grep '^RESEND_API_KEY=' deploy/functions.env 2>/dev/null | cut -d= -f2- || echo "")"

if [ -t 0 ] && [ -z "$CURRENT_SMTP" ] && [ -z "$CURRENT_RESEND" ]; then
  echo ""
  t mail_title
  t mail_opt1
  t mail_opt2
  t mail_opt3
  t mail_prompt
  read -r MAIL_CHOICE
  MAIL_CHOICE="${MAIL_CHOICE:-1}"

  case "$MAIL_CHOICE" in
    2)
      echo ""
      t smtp_title
      t smtp_host;   read -r CFG_SMTP_HOST
      t smtp_port;   read -r CFG_SMTP_PORT
      CFG_SMTP_PORT="${CFG_SMTP_PORT:-587}"
      t smtp_user;   read -r CFG_SMTP_USER
      t smtp_pass;   read -r -s CFG_SMTP_PASS
      echo ""
      t smtp_sender "$CFG_SMTP_USER"; read -r CFG_SENDER_EMAIL
      CFG_SENDER_EMAIL="${CFG_SENDER_EMAIL:-$CFG_SMTP_USER}"
      CFG_SECURE="false"
      [ "$CFG_SMTP_PORT" = "465" ] && CFG_SECURE="true"
      sed -i "s|^MAIL_TRANSPORT=.*|MAIL_TRANSPORT=smtp|"         deploy/functions.env
      sed -i "s|^SMTP_HOST=.*|SMTP_HOST=${CFG_SMTP_HOST}|"       deploy/functions.env
      sed -i "s|^SMTP_PORT=.*|SMTP_PORT=${CFG_SMTP_PORT}|"       deploy/functions.env
      sed -i "s|^SMTP_USER=.*|SMTP_USER=${CFG_SMTP_USER}|"       deploy/functions.env
      sed -i "s|^SMTP_PASS=.*|SMTP_PASS=${CFG_SMTP_PASS}|"       deploy/functions.env
      sed -i "s|^SMTP_SECURE=.*|SMTP_SECURE=${CFG_SECURE}|"      deploy/functions.env
      sed -i "s|^SENDER_EMAIL=.*|SENDER_EMAIL=${CFG_SENDER_EMAIL}|" deploy/functions.env
      succes "$(t ok_smtp "${CFG_SMTP_HOST}:${CFG_SMTP_PORT}")"
      ;;
    3)
      echo ""
      t resend_title
      t resend_key;    read -r CFG_RESEND_KEY
      t resend_sender; read -r CFG_RESEND_SENDER
      sed -i "s|^MAIL_TRANSPORT=.*|MAIL_TRANSPORT=resend|"           deploy/functions.env
      sed -i "s|^RESEND_API_KEY=.*|RESEND_API_KEY=${CFG_RESEND_KEY}|" deploy/functions.env
      sed -i "s|^SENDER_EMAIL=.*|SENDER_EMAIL=${CFG_RESEND_SENDER}|"  deploy/functions.env
      succes "$(t ok_resend "$CFG_RESEND_SENDER")"
      ;;
    *)
      sed -i "s|^MAIL_TRANSPORT=.*|MAIL_TRANSPORT=mock|" deploy/functions.env
      succes "$(t ok_mock)"
      ;;
  esac
fi

# Initialisation de la première bibliothèque (GOUV-19)
DEFAULT_LIB="Bibliothèque Autonome"
[ "$LANG_CODE" = "en" ] && DEFAULT_LIB="Autonomous Library"
[ "$LANG_CODE" = "pt" ] && DEFAULT_LIB="Biblioteca Autônoma"

LIB_NAME="$DEFAULT_LIB"
if [ -t 0 ]; then
  echo ""
  t lib_title
  t lib_prompt "$DEFAULT_LIB"
  read -r USER_LIB_NAME
  [ -n "$USER_LIB_NAME" ] && LIB_NAME="$USER_LIB_NAME"
  succes "$(t ok_lib "$LIB_NAME")"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 3. Frontend build
# ─────────────────────────────────────────────────────────────────────────────
dire "$(t step3)"

ANON_KEY="$(grep '^ANON_KEY=' deploy/.env | cut -d= -f2-)"
API_URL="$(grep '^API_EXTERNAL_URL=' deploy/.env | cut -d= -f2-)"

cat > .env.local <<EOF
# $(t gen_keys)
VITE_SUPABASE_URL=${API_URL}
VITE_SUPABASE_PUBLISHABLE_KEY=${ANON_KEY}
EOF
succes "$(t ok_envlocal "$API_URL")"

if [ ! -d "node_modules" ] || [ ! -f "node_modules/.bin/vite" ]; then
  echo "$(t npm_install)"
  npm ci
  succes "$(t ok_deps)"
else
  succes "$(t ok_deps_exist)"
fi

if [ ! -d "dist" ] || [ "$REBUILD" = "1" ] || [ ! -f "dist/index.html" ]; then
  echo "$(t npm_build)"
  npm run build
  succes "$(t ok_build)"
else
  succes "$(t ok_build_exist)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 4. Docker stack
# ─────────────────────────────────────────────────────────────────────────────
if [ "$START" = "1" ]; then
  dire "$(t step4)"
  cd deploy

  if [ "$REBUILD" = "1" ]; then
    echo "$(t rebuild_clean)"
    docker compose down -v
    ./bootstrap.sh --depuis-le-depot --sel-jetable
  else
    mkdir -p ../dist
    docker compose up -d db >/dev/null 2>&1
    sleep 2
    NB_TABLES="$(docker compose exec -T db psql -U supabase_admin -d postgres -tAc \
      "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';" \
      2>/dev/null || echo "0")"

    if [ "$NB_TABLES" -gt 0 ]; then
      echo "$(t db_existing "$NB_TABLES")"
      docker compose up -d
      docker compose exec -T db sh /scripts/apply-pending-migrations.sh
    else
      echo "$(t db_fresh)"
      ./bootstrap.sh --depuis-le-depot --sel-jetable
    fi
  fi
  cd "$RACINE"

  dire "$(t health_title)"
  ./deploy/deploy.sh --controle

  node deploy/scripts/seed-admin.mjs "$MODE" "$DOMAINE_PROD" "$LIB_NAME"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Final output
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
printf "║  %-65s║\n" "$(t done_banner)"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""
t open_browser
t url_local
t url_network "$(ip -4 addr show scope global 2>/dev/null | grep inet | head -n1 | awk '{print $2}' | cut -d/ -f1 || echo "IP_HOTE")"
t url_domain
echo ""

if [ -f deploy/.initial_admin_creds ]; then
  ADMIN_EMAIL="$(grep '^ADMIN_EMAIL=' deploy/.initial_admin_creds | cut -d= -f2-)"
  ADMIN_PASSWORD="$(grep '^ADMIN_PASSWORD=' deploy/.initial_admin_creds | cut -d= -f2-)"
  CREDS_LIB_NAME="$(grep '^LIB_NAME=' deploy/.initial_admin_creds | cut -d= -f2-)"
  rm -f deploy/.initial_admin_creds
  t admin_title
  [ -n "$CREDS_LIB_NAME" ] && t admin_lib "$CREDS_LIB_NAME"
  t admin_email "$ADMIN_EMAIL"
  t admin_pass  "$ADMIN_PASSWORD"
  t admin_warn
  echo ""
fi

t access_title
t access_web
t access_api
t access_auth
t access_rest
echo ""
t manage_title
t manage_stop
t manage_rebuild
t manage_health
t manage_update
echo ""
