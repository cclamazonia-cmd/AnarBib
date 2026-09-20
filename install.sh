#!/usr/bin/env bash
# =============================================================================
# AnarBib — All-in-one centralized installer (Backend + Frontend)
# =============================================================================
# Installs, configures and starts the entire AnarBib stack in one command.
#
# USAGE:
#   ./install.sh                       # full install and start
#   ./install.sh --lang CODE           # force display language (see the list below)
#   ./install.sh --local               # force localhost configuration
#   ./install.sh --prod DOMAIN         # configure for a public domain
#   ./install.sh --rebuild             # wipe volumes and reinstall from scratch
#   ./install.sh --sans-front          # start backend only (no Vite)
#   ./install.sh --sans-start          # prepare config without starting
#   ./install.sh --stop                # stop all containers
#   ./install.sh -h | --help           # show this help
#
#   --lang: fr en pt es it de ca eo nl el
# =============================================================================

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Language detection (must happen before any output or argument parsing)
# ─────────────────────────────────────────────────────────────────────────────
_SYS_LANG="${LANG:-${LC_ALL:-${LC_MESSAGES:-}}}"
case "${_SYS_LANG%%_*}" in
  fr|pt|es|it|de|ca|eo|nl|el) LANG_CODE="${_SYS_LANG%%_*}" ;;
  *)                          LANG_CODE="en" ;;
esac

# Pre-scan for --lang before full argument parsing so t() works immediately
for _arg in "$@"; do
  case "$_arg" in --lang) _NEXT_IS_LANG=1 ;; *)
    if [ "${_NEXT_IS_LANG:-0}" = "1" ]; then
      case "$_arg" in
        fr|en|pt|es|it|de|ca|eo|nl|el) LANG_CODE="$_arg" ;;
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
    es:err_no_git)     echo "Fuera de un repositorio git. Ejecutá este script desde la raíz de AnarBib." ;;
    it:err_no_git)     echo "Fuori da un deposito git. Esegui questo script dalla radice di AnarBib." ;;
    de:err_no_git)     echo "Nicht in einem Git-Depot. Führe dieses Skript im Stammverzeichnis von AnarBib aus." ;;
    ca:err_no_git)     echo "Fora d'un dipòsit git. Executa aquest script des de l'arrel d'AnarBib." ;;
    eo:err_no_git)     echo "Ekster git-deponejo. Rulu ĉi tiun skripton el la radiko de AnarBib." ;;
    nl:err_no_git)     echo "Niet in een git-depot. Voer dit script uit vanuit de hoofdmap van AnarBib." ;;
    el:err_no_git)     echo "Εκτός αποθετηρίου git. Εκτέλεσε αυτό το σενάριο από τη ρίζα του AnarBib." ;;

    fr:err_no_domain)  echo "Domaine manquant pour --prod. Exemple : ./install.sh --prod api.anarbib.org" ;;
    en:err_no_domain)  echo "Missing domain for --prod. Example: ./install.sh --prod api.anarbib.org" ;;
    pt:err_no_domain)  echo "Domínio ausente para --prod. Exemplo: ./install.sh --prod api.anarbib.org" ;;
    es:err_no_domain)  echo "Falta el dominio para --prod. Ejemplo: ./install.sh --prod api.anarbib.org" ;;
    it:err_no_domain)  echo "Dominio mancante per --prod. Esempio: ./install.sh --prod api.anarbib.org" ;;
    de:err_no_domain)  echo "Domain fehlt für --prod. Beispiel: ./install.sh --prod api.anarbib.org" ;;
    ca:err_no_domain)  echo "Falta el domini per a --prod. Exemple: ./install.sh --prod api.anarbib.org" ;;
    eo:err_no_domain)  echo "Mankas domajno por --prod. Ekzemplo: ./install.sh --prod api.anarbib.org" ;;
    nl:err_no_domain)  echo "Domein ontbreekt voor --prod. Voorbeeld: ./install.sh --prod api.anarbib.org" ;;
    el:err_no_domain)  echo "Λείπει ο τομέας για το --prod. Παράδειγμα: ./install.sh --prod api.anarbib.org" ;;

    fr:err_unknown)    echo "Option inconnue : $2" ;;
    en:err_unknown)    echo "Unknown option: $2" ;;
    pt:err_unknown)    echo "Opção desconhecida: $2" ;;
    es:err_unknown)    echo "Opción desconocida: $2" ;;
    it:err_unknown)    echo "Opzione sconosciuta: $2" ;;
    de:err_unknown)    echo "Unbekannte Option: $2" ;;
    ca:err_unknown)    echo "Opció desconeguda: $2" ;;
    eo:err_unknown)    echo "Nekonata opcio: $2" ;;
    nl:err_unknown)    echo "Onbekende optie: $2" ;;
    el:err_unknown)    echo "Άγνωστη επιλογή: $2" ;;

    fr:err_help_hint)  echo "  Utilisez ./install.sh --help pour voir les options disponibles." ;;
    en:err_help_hint)  echo "  Use ./install.sh --help to see available options." ;;
    pt:err_help_hint)  echo "  Use ./install.sh --help para ver as opções disponíveis." ;;
    es:err_help_hint)  echo "  Usá ./install.sh --help para ver las opciones disponibles." ;;
    it:err_help_hint)  echo "  Usa ./install.sh --help per vedere le opzioni disponibili." ;;
    de:err_help_hint)  echo "  Nutze ./install.sh --help für die verfügbaren Optionen." ;;
    ca:err_help_hint)  echo "  Fes servir ./install.sh --help per veure les opcions disponibles." ;;
    eo:err_help_hint)  echo "  Uzu ./install.sh --help por vidi la disponeblajn opciojn." ;;
    nl:err_help_hint)  echo "  Gebruik ./install.sh --help om de beschikbare opties te zien." ;;
    el:err_help_hint)  echo "  Χρησιμοποίησε ./install.sh --help για τις διαθέσιμες επιλογές." ;;

    fr:err_lang)       echo "Langue non reconnue : '$2'. Valeurs acceptées : fr, en, pt, es, it, de, ca, eo, nl, el" ;;
    en:err_lang)       echo "Unknown language: '$2'. Accepted values: fr, en, pt, es, it, de, ca, eo, nl, el" ;;
    pt:err_lang)       echo "Idioma não reconhecido: '$2'. Valores aceitos: fr, en, pt, es, it, de, ca, eo, nl, el" ;;
    es:err_lang)       echo "Idioma no reconocido: '$2'. Valores aceptados: fr, en, pt, es, it, de, ca, eo, nl, el" ;;
    it:err_lang)       echo "Lingua non riconosciuta: '$2'. Valori accettati: fr, en, pt, es, it, de, ca, eo, nl, el" ;;
    de:err_lang)       echo "Sprache nicht erkannt: '$2'. Zulässige Werte: fr, en, pt, es, it, de, ca, eo, nl, el" ;;
    ca:err_lang)       echo "Llengua no reconeguda: '$2'. Valors acceptats: fr, en, pt, es, it, de, ca, eo, nl, el" ;;
    eo:err_lang)       echo "Nekonata lingvo: '$2'. Akceptataj valoroj: fr, en, pt, es, it, de, ca, eo, nl, el" ;;
    nl:err_lang)       echo "Taal niet herkend: '$2'. Aanvaarde waarden: fr, en, pt, es, it, de, ca, eo, nl, el" ;;
    el:err_lang)       echo "Μη αναγνωρισμένη γλώσσα: '$2'. Αποδεκτές τιμές: fr, en, pt, es, it, de, ca, eo, nl, el" ;;

    # ── --stop action ────────────────────────────────────────────────────────
    fr:stop_title)     echo "Arrêt d'AnarBib (Frontend + Backend)" ;;
    en:stop_title)     echo "Stopping AnarBib (Frontend + Backend)" ;;
    pt:stop_title)     echo "Parando AnarBib (Frontend + Backend)" ;;
    es:stop_title)     echo "Deteniendo AnarBib (Frontend + Backend)" ;;
    it:stop_title)     echo "Arresto di AnarBib (Frontend + Backend)" ;;
    de:stop_title)     echo "AnarBib wird gestoppt (Frontend + Backend)" ;;
    ca:stop_title)     echo "Aturada d'AnarBib (Frontend + Backend)" ;;
    eo:stop_title)     echo "Haltigo de AnarBib (Frontend + Backend)" ;;
    nl:stop_title)     echo "AnarBib wordt gestopt (Frontend + Backend)" ;;
    el:stop_title)     echo "Διακοπή του AnarBib (Frontend + Backend)" ;;

    fr:stop_frontend)  echo "Serveur web frontend arrêté (PID $2)" ;;
    en:stop_frontend)  echo "Frontend web server stopped (PID $2)" ;;
    pt:stop_frontend)  echo "Servidor web frontend parado (PID $2)" ;;
    es:stop_frontend)  echo "Servidor web frontend detenido (PID $2)" ;;
    it:stop_frontend)  echo "Server web frontend arrestato (PID $2)" ;;
    de:stop_frontend)  echo "Frontend-Webserver gestoppt (PID $2)" ;;
    ca:stop_frontend)  echo "Servidor web frontend aturat (PID $2)" ;;
    eo:stop_frontend)  echo "Frontend-retservilo haltigita (PID $2)" ;;
    nl:stop_frontend)  echo "Frontend-webserver gestopt (PID $2)" ;;
    el:stop_frontend)  echo "Ο διακομιστής ιστού frontend σταμάτησε (PID $2)" ;;

    fr:stop_backend)   echo "Pile backend arrêtée." ;;
    en:stop_backend)   echo "Backend stack stopped." ;;
    pt:stop_backend)   echo "Pilha backend parada." ;;
    es:stop_backend)   echo "Pila backend detenida." ;;
    it:stop_backend)   echo "Pila backend arrestata." ;;
    de:stop_backend)   echo "Backend-Stack gestoppt." ;;
    ca:stop_backend)   echo "Pila backend aturada." ;;
    eo:stop_backend)   echo "Backend-stako haltigita." ;;
    nl:stop_backend)   echo "Backend-stack gestopt." ;;
    el:stop_backend)   echo "Η στοίβα backend σταμάτησε." ;;

    # ── banner ───────────────────────────────────────────────────────────────
    fr:banner)         echo "AnarBib — Installateur centralisé tout-en-un" ;;
    en:banner)         echo "AnarBib — All-in-one centralized installer" ;;
    pt:banner)         echo "AnarBib — Instalador centralizado completo" ;;
    es:banner)         echo "AnarBib — Instalador centralizado todo en uno" ;;
    it:banner)         echo "AnarBib — Installatore centralizzato tutto-in-uno" ;;
    de:banner)         echo "AnarBib — Zentraler Alles-in-einem-Installer" ;;
    ca:banner)         echo "AnarBib — Instal·lador centralitzat tot en un" ;;
    eo:banner)         echo "AnarBib — Centralizita ĉio-en-unu instalilo" ;;
    nl:banner)         echo "AnarBib — Centrale alles-in-één installer" ;;
    el:banner)         echo "AnarBib — Κεντρικός εγκαταστάτης όλα-σε-ένα" ;;

    # ── step 1 ───────────────────────────────────────────────────────────────
    fr:step1)          echo "1/4 · Vérification des prérequis système" ;;
    en:step1)          echo "1/4 · Checking system prerequisites" ;;
    pt:step1)          echo "1/4 · Verificação dos pré-requisitos do sistema" ;;
    es:step1)          echo "1/4 · Verificación de los requisitos del sistema" ;;
    it:step1)          echo "1/4 · Verifica dei requisiti di sistema" ;;
    de:step1)          echo "1/4 · Prüfung der Systemvoraussetzungen" ;;
    ca:step1)          echo "1/4 · Verificació dels requisits del sistema" ;;
    eo:step1)          echo "1/4 · Kontrolo de la sistemaj antaŭkondiĉoj" ;;
    nl:step1)          echo "1/4 · Controle van de systeemvereisten" ;;
    el:step1)          echo "1/4 · Έλεγχος των προαπαιτούμενων του συστήματος" ;;

    fr:err_docker)     echo "Docker est introuvable. Installez Docker avant de continuer." ;;
    en:err_docker)     echo "Docker not found. Please install Docker before continuing." ;;
    pt:err_docker)     echo "Docker não encontrado. Instale o Docker antes de continuar." ;;
    es:err_docker)     echo "No se encuentra Docker. Instalalo antes de continuar." ;;
    it:err_docker)     echo "Docker non trovato. Installa Docker prima di continuare." ;;
    de:err_docker)     echo "Docker nicht gefunden. Installiere Docker, bevor du fortfährst." ;;
    ca:err_docker)     echo "No es troba Docker. Instal·la'l abans de continuar." ;;
    eo:err_docker)     echo "Docker ne troviĝas. Instalu Docker antaŭ ol daŭrigi." ;;
    nl:err_docker)     echo "Docker niet gevonden. Installeer Docker voordat je verdergaat." ;;
    el:err_docker)     echo "Το Docker δεν βρέθηκε. Εγκατέστησέ το πριν συνεχίσεις." ;;

    fr:ok_docker)      echo "Docker est présent ($2)" ;;
    en:ok_docker)      echo "Docker is ready ($2)" ;;
    pt:ok_docker)      echo "Docker encontrado ($2)" ;;
    es:ok_docker)      echo "Docker está presente ($2)" ;;
    it:ok_docker)      echo "Docker è presente ($2)" ;;
    de:ok_docker)      echo "Docker ist vorhanden ($2)" ;;
    ca:ok_docker)      echo "Docker és present ($2)" ;;
    eo:ok_docker)      echo "Docker ĉeestas ($2)" ;;
    nl:ok_docker)      echo "Docker is aanwezig ($2)" ;;
    el:ok_docker)      echo "Το Docker είναι παρόν ($2)" ;;

    fr:err_compose)    echo "Le plugin 'docker compose' est introuvable." ;;
    en:err_compose)    echo "The 'docker compose' plugin is not found." ;;
    pt:err_compose)    echo "O plugin 'docker compose' não foi encontrado." ;;
    es:err_compose)    echo "No se encuentra el plugin 'docker compose'." ;;
    it:err_compose)    echo "Il plugin 'docker compose' non è stato trovato." ;;
    de:err_compose)    echo "Das Plugin 'docker compose' wurde nicht gefunden." ;;
    ca:err_compose)    echo "No es troba el connector 'docker compose'." ;;
    eo:err_compose)    echo "La kromaĵo 'docker compose' ne troviĝas." ;;
    nl:err_compose)    echo "De plugin 'docker compose' is niet gevonden." ;;
    el:err_compose)    echo "Το πρόσθετο 'docker compose' δεν βρέθηκε." ;;

    fr:ok_compose)     echo "Docker Compose est prêt ($2)" ;;
    en:ok_compose)     echo "Docker Compose is ready ($2)" ;;
    pt:ok_compose)     echo "Docker Compose pronto ($2)" ;;
    es:ok_compose)     echo "Docker Compose está listo ($2)" ;;
    it:ok_compose)     echo "Docker Compose è pronto ($2)" ;;
    de:ok_compose)     echo "Docker Compose ist bereit ($2)" ;;
    ca:ok_compose)     echo "Docker Compose està a punt ($2)" ;;
    eo:ok_compose)     echo "Docker Compose pretas ($2)" ;;
    nl:ok_compose)     echo "Docker Compose is klaar ($2)" ;;
    el:ok_compose)     echo "Το Docker Compose είναι έτοιμο ($2)" ;;

    fr:err_daemon)     echo "Le démon Docker ne répond pas. Vérifiez que le service Docker est démarré." ;;
    en:err_daemon)     echo "Docker daemon not responding. Make sure the Docker service is running." ;;
    pt:err_daemon)     echo "Docker daemon não responde. Verifique se o serviço Docker está em execução." ;;
    es:err_daemon)     echo "El demonio Docker no responde. Verificá que el servicio Docker esté iniciado." ;;
    it:err_daemon)     echo "Il demone Docker non risponde. Controlla che il servizio Docker sia avviato." ;;
    de:err_daemon)     echo "Der Docker-Daemon antwortet nicht. Prüfe, ob der Docker-Dienst läuft." ;;
    ca:err_daemon)     echo "El dimoni Docker no respon. Comprova que el servei Docker estigui engegat." ;;
    eo:err_daemon)     echo "La Docker-demono ne respondas. Kontrolu ke la servo Docker funkcias." ;;
    nl:err_daemon)     echo "De Docker-daemon antwoordt niet. Controleer of de Docker-dienst draait." ;;
    el:err_daemon)     echo "Ο δαίμονας Docker δεν αποκρίνεται. Έλεγξε ότι η υπηρεσία Docker τρέχει." ;;

    fr:ok_daemon)      echo "Démon Docker opérationnel" ;;
    en:ok_daemon)      echo "Docker daemon running" ;;
    pt:ok_daemon)      echo "Docker daemon operacional" ;;
    es:ok_daemon)      echo "Demonio Docker operativo" ;;
    it:ok_daemon)      echo "Demone Docker operativo" ;;
    de:ok_daemon)      echo "Docker-Daemon läuft" ;;
    ca:ok_daemon)      echo "Dimoni Docker operatiu" ;;
    eo:ok_daemon)      echo "Docker-demono funkcias" ;;
    nl:ok_daemon)      echo "Docker-daemon draait" ;;
    el:ok_daemon)      echo "Ο δαίμονας Docker λειτουργεί" ;;

    fr:err_node)       echo "Node.js / npm est introuvable. Installez Node.js pour faire tourner l'application." ;;
    en:err_node)       echo "Node.js / npm not found. Install Node.js to run the application." ;;
    pt:err_node)       echo "Node.js / npm não encontrado. Instale o Node.js para executar a aplicação." ;;
    es:err_node)       echo "No se encuentra Node.js / npm. Instalá Node.js para ejecutar la aplicación." ;;
    it:err_node)       echo "Node.js / npm non trovato. Installa Node.js per far girare l'applicazione." ;;
    de:err_node)       echo "Node.js / npm nicht gefunden. Installiere Node.js, um die Anwendung zu betreiben." ;;
    ca:err_node)       echo "No es troba Node.js / npm. Instal·la Node.js per fer funcionar l'aplicació." ;;
    eo:err_node)       echo "Node.js / npm ne troviĝas. Instalu Node.js por ruli la aplikaĵon." ;;
    nl:err_node)       echo "Node.js / npm niet gevonden. Installeer Node.js om de toepassing te draaien." ;;
    el:err_node)       echo "Το Node.js / npm δεν βρέθηκε. Εγκατέστησε το Node.js για να τρέξει η εφαρμογή." ;;

    fr:ok_node)        echo "Node.js / npm est prêt ($2)" ;;
    en:ok_node)        echo "Node.js / npm ready ($2)" ;;
    pt:ok_node)        echo "Node.js / npm pronto ($2)" ;;
    es:ok_node)        echo "Node.js / npm está listo ($2)" ;;
    it:ok_node)        echo "Node.js / npm è pronto ($2)" ;;
    de:ok_node)        echo "Node.js / npm ist bereit ($2)" ;;
    ca:ok_node)        echo "Node.js / npm està a punt ($2)" ;;
    eo:ok_node)        echo "Node.js / npm pretas ($2)" ;;
    nl:ok_node)        echo "Node.js / npm is klaar ($2)" ;;
    el:ok_node)        echo "Το Node.js / npm είναι έτοιμο ($2)" ;;

    # ── step 2 ───────────────────────────────────────────────────────────────
    fr:step2)          echo "2/4 · Initialisation des environnements et génération des clés" ;;
    en:step2)          echo "2/4 · Environment setup and key generation" ;;
    pt:step2)          echo "2/4 · Configuração do ambiente e geração de chaves" ;;
    es:step2)          echo "2/4 · Inicialización de los entornos y generación de claves" ;;
    it:step2)          echo "2/4 · Inizializzazione degli ambienti e generazione delle chiavi" ;;
    de:step2)          echo "2/4 · Einrichtung der Umgebungen und Schlüsselerzeugung" ;;
    ca:step2)          echo "2/4 · Inicialització dels entorns i generació de claus" ;;
    eo:step2)          echo "2/4 · Pretigo de la medioj kaj generado de la ŝlosiloj" ;;
    nl:step2)          echo "2/4 · Opzetten van de omgevingen en genereren van de sleutels" ;;
    el:step2)          echo "2/4 · Αρχικοποίηση των περιβαλλόντων και δημιουργία των κλειδιών" ;;

    fr:ok_env)         echo "Fichier deploy/.env créé depuis deploy/.env.example" ;;
    en:ok_env)         echo "File deploy/.env created from deploy/.env.example" ;;
    pt:ok_env)         echo "Arquivo deploy/.env criado a partir de deploy/.env.example" ;;
    es:ok_env)         echo "Archivo deploy/.env creado a partir de deploy/.env.example" ;;
    it:ok_env)         echo "File deploy/.env creato da deploy/.env.example" ;;
    de:ok_env)         echo "Datei deploy/.env aus deploy/.env.example erstellt" ;;
    ca:ok_env)         echo "Fitxer deploy/.env creat a partir de deploy/.env.example" ;;
    eo:ok_env)         echo "Dosiero deploy/.env kreita el deploy/.env.example" ;;
    nl:ok_env)         echo "Bestand deploy/.env aangemaakt vanuit deploy/.env.example" ;;
    el:ok_env)         echo "Το αρχείο deploy/.env δημιουργήθηκε από το deploy/.env.example" ;;

    fr:ok_fenv)        echo "Fichier deploy/functions.env créé depuis deploy/functions.env.example" ;;
    en:ok_fenv)        echo "File deploy/functions.env created from deploy/functions.env.example" ;;
    pt:ok_fenv)        echo "Arquivo deploy/functions.env criado a partir de deploy/functions.env.example" ;;
    es:ok_fenv)        echo "Archivo deploy/functions.env creado a partir de deploy/functions.env.example" ;;
    it:ok_fenv)        echo "File deploy/functions.env creato da deploy/functions.env.example" ;;
    de:ok_fenv)        echo "Datei deploy/functions.env aus deploy/functions.env.example erstellt" ;;
    ca:ok_fenv)        echo "Fitxer deploy/functions.env creat a partir de deploy/functions.env.example" ;;
    eo:ok_fenv)        echo "Dosiero deploy/functions.env kreita el deploy/functions.env.example" ;;
    nl:ok_fenv)        echo "Bestand deploy/functions.env aangemaakt vanuit deploy/functions.env.example" ;;
    el:ok_fenv)        echo "Το αρχείο deploy/functions.env δημιουργήθηκε από το deploy/functions.env.example" ;;

    fr:gen_keys)       echo "→ Génération automatique des clés JWT et mots de passe..." ;;
    en:gen_keys)       echo "→ Auto-generating JWT keys and passwords..." ;;
    pt:gen_keys)       echo "→ Gerando chaves JWT e senhas automaticamente..." ;;
    es:gen_keys)       echo "→ Generación automática de claves JWT y contraseñas..." ;;
    it:gen_keys)       echo "→ Generazione automatica delle chiavi JWT e delle password..." ;;
    de:gen_keys)       echo "→ Automatische Erzeugung der JWT-Schlüssel und Passwörter..." ;;
    ca:gen_keys)       echo "→ Generació automàtica de les claus JWT i les contrasenyes..." ;;
    eo:gen_keys)       echo "→ Aŭtomata generado de la JWT-ŝlosiloj kaj pasvortoj..." ;;
    nl:gen_keys)       echo "→ Automatisch genereren van de JWT-sleutels en wachtwoorden..." ;;
    el:gen_keys)       echo "→ Αυτόματη δημιουργία των κλειδιών JWT και των κωδικών..." ;;

    fr:ok_keys)        echo "Clés et secrets configurés dans deploy/.env" ;;
    en:ok_keys)        echo "Keys and secrets configured in deploy/.env" ;;
    pt:ok_keys)        echo "Chaves e segredos configurados em deploy/.env" ;;
    es:ok_keys)        echo "Claves y secretos configurados en deploy/.env" ;;
    it:ok_keys)        echo "Chiavi e segreti configurati in deploy/.env" ;;
    de:ok_keys)        echo "Schlüssel und Geheimnisse in deploy/.env konfiguriert" ;;
    ca:ok_keys)        echo "Claus i secrets configurats a deploy/.env" ;;
    eo:ok_keys)        echo "Ŝlosiloj kaj sekretoj agorditaj en deploy/.env" ;;
    nl:ok_keys)        echo "Sleutels en geheimen ingesteld in deploy/.env" ;;
    el:ok_keys)        echo "Κλειδιά και μυστικά ρυθμίστηκαν στο deploy/.env" ;;

    fr:ok_prod_domain) echo "Domaine de production configuré : https://$2" ;;
    en:ok_prod_domain) echo "Production domain configured: https://$2" ;;
    pt:ok_prod_domain) echo "Domínio de produção configurado: https://$2" ;;
    es:ok_prod_domain) echo "Dominio de producción configurado: https://$2" ;;
    it:ok_prod_domain) echo "Dominio di produzione configurato: https://$2" ;;
    de:ok_prod_domain) echo "Produktionsdomain konfiguriert: https://$2" ;;
    ca:ok_prod_domain) echo "Domini de producció configurat: https://$2" ;;
    eo:ok_prod_domain) echo "Produkta domajno agordita: https://$2" ;;
    nl:ok_prod_domain) echo "Productiedomein ingesteld: https://$2" ;;
    el:ok_prod_domain) echo "Ο τομέας παραγωγής ρυθμίστηκε: https://$2" ;;

    # ── mail config ──────────────────────────────────────────────────────────
    fr:mail_title)     echo "📧 Configuration du service d'e-mail pour les notifications :" ;;
    en:mail_title)     echo "📧 Email service configuration for notifications:" ;;
    pt:mail_title)     echo "📧 Configuração do serviço de e-mail para notificações:" ;;
    es:mail_title)     echo "📧 Configuración del servicio de correo para las notificaciones:" ;;
    it:mail_title)     echo "📧 Configurazione del servizio e-mail per le notifiche:" ;;
    de:mail_title)     echo "📧 Konfiguration des E-Mail-Dienstes für Benachrichtigungen:" ;;
    ca:mail_title)     echo "📧 Configuració del servei de correu per a les notificacions:" ;;
    eo:mail_title)     echo "📧 Agordo de la retpoŝta servo por la sciigoj:" ;;
    nl:mail_title)     echo "📧 Instelling van de e-maildienst voor de meldingen:" ;;
    el:mail_title)     echo "📧 Ρύθμιση της υπηρεσίας e-mail για τις ειδοποιήσεις:" ;;

    fr:mail_opt1)      echo "   [1] Serveur SMTP standard (votre propre boîte mail) — À VENIR, pas encore pris en charge" ;;
    en:mail_opt1)      echo "   [1] Standard SMTP server (your own mailbox) — COMING SOON, not supported yet" ;;
    pt:mail_opt1)      echo "   [1] Servidor SMTP padrão (sua própria caixa de correio) — EM BREVE, ainda não suportado" ;;
    es:mail_opt1)      echo "   [1] Servidor SMTP estándar (tu propio buzón) — POR VENIR, todavía no soportado" ;;
    it:mail_opt1)      echo "   [1] Server SMTP standard (la tua casella di posta) — IN ARRIVO, non ancora supportato" ;;
    de:mail_opt1)      echo "   [1] Standard-SMTP-Server (dein eigenes Postfach) — KOMMT NOCH, noch nicht unterstützt" ;;
    ca:mail_opt1)      echo "   [1] Servidor SMTP estàndard (la teva bústia) — EN CAMÍ, encara no admès" ;;
    eo:mail_opt1)      echo "   [1] Norma SMTP-servilo (via propra leterkesto) — VENONTA, ankoraŭ ne subtenata" ;;
    nl:mail_opt1)      echo "   [1] Standaard SMTP-server (je eigen mailbox) — KOMT NOG, nog niet ondersteund" ;;
    el:mail_opt1)      echo "   [1] Τυπικός διακομιστής SMTP (το δικό σου γραμματοκιβώτιο) — ΕΡΧΕΤΑΙ, δεν υποστηρίζεται ακόμη" ;;

    fr:mail_opt2)      echo "   [2] Clé API Resend (service tiers clé en main)" ;;
    en:mail_opt2)      echo "   [2] Resend API key (third-party turnkey service)" ;;
    pt:mail_opt2)      echo "   [2] Chave API Resend (serviço terceirizado pronto para uso)" ;;
    es:mail_opt2)      echo "   [2] Clave API Resend (servicio externo llave en mano)" ;;
    it:mail_opt2)      echo "   [2] Chiave API Resend (servizio esterno chiavi in mano)" ;;
    de:mail_opt2)      echo "   [2] Resend-API-Schlüssel (schlüsselfertiger Fremddienst)" ;;
    ca:mail_opt2)      echo "   [2] Clau API Resend (servei extern clau en mà)" ;;
    eo:mail_opt2)      echo "   [2] Resend API-ŝlosilo (ekstera pretsolvo)" ;;
    nl:mail_opt2)      echo "   [2] Resend API-sleutel (externe kant-en-klare dienst)" ;;
    el:mail_opt2)      echo "   [2] Κλειδί API Resend (εξωτερική έτοιμη υπηρεσία)" ;;

    fr:mail_opt3)      echo "   [3] Simulation locale (e-mails journalisés) — À VENIR, pas encore prise en charge" ;;
    en:mail_opt3)      echo "   [3] Local simulation (emails logged) — COMING SOON, not supported yet" ;;
    pt:mail_opt3)      echo "   [3] Simulação local (e-mails registrados) — EM BREVE, ainda não suportada" ;;
    es:mail_opt3)      echo "   [3] Simulación local (correos registrados) — POR VENIR, todavía no soportada" ;;
    it:mail_opt3)      echo "   [3] Simulazione locale (e-mail registrate) — IN ARRIVO, non ancora supportata" ;;
    de:mail_opt3)      echo "   [3] Lokale Simulation (E-Mails protokolliert) — KOMMT NOCH, noch nicht unterstützt" ;;
    ca:mail_opt3)      echo "   [3] Simulació local (correus registrats) — EN CAMÍ, encara no admesa" ;;
    eo:mail_opt3)      echo "   [3] Loka simulado (retleteroj protokolitaj) — VENONTA, ankoraŭ ne subtenata" ;;
    nl:mail_opt3)      echo "   [3] Lokale simulatie (e-mails gelogd) — KOMT NOG, nog niet ondersteund" ;;
    el:mail_opt3)      echo "   [3] Τοπική προσομοίωση (καταγραφή e-mail) — ΕΡΧΕΤΑΙ, δεν υποστηρίζεται ακόμη" ;;

    fr:mail_prompt)    printf "Votre choix [1/2/3] (seul 2 fonctionne aujourd'hui) : " ;;
    en:mail_prompt)    printf "Your choice [1/2/3] (only 2 works today): " ;;
    pt:mail_prompt)    printf "Sua escolha [1/2/3] (só a 2 funciona hoje): " ;;
    es:mail_prompt)    printf "Tu elección [1/2/3] (hoy solo funciona la 2): " ;;
    it:mail_prompt)    printf "La tua scelta [1/2/3] (oggi funziona solo la 2): " ;;
    de:mail_prompt)    printf "Deine Wahl [1/2/3] (heute funktioniert nur die 2): " ;;
    ca:mail_prompt)    printf "La teva tria [1/2/3] (avui només funciona la 2): " ;;
    eo:mail_prompt)    printf "Via elekto [1/2/3] (hodiaŭ nur la 2 funkcias): " ;;
    nl:mail_prompt)    printf "Jouw keuze [1/2/3] (vandaag werkt alleen 2): " ;;
    el:mail_prompt)    printf "Η επιλογή σου [1/2/3] (σήμερα λειτουργεί μόνο η 2): " ;;
    fr:mail_not_yet)   echo "Pas de transport configuré : les fonctions serveur ne savent envoyer que par Resend (option 2)."
                       echo "   SMTP et simulation viendront avec le transport hybride (backlog F7). D'ici là, AUCUN courriel"
                       echo "   ne partira et chaque envoi échouera avec « RESEND_API_KEY absente » — bruyamment, jamais en silence."
                       echo "   Relancez ./install.sh avec une clé Resend quand vous en aurez une." ;;
    en:mail_not_yet)   echo "No transport configured: the server functions can only send through Resend (option 2)."
                       echo "   SMTP and simulation will come with the hybrid transport (backlog F7). Until then NO email"
                       echo "   will leave, and each send will fail with 'RESEND_API_KEY absente' — loudly, never silently."
                       echo "   Run ./install.sh again with a Resend key when you have one." ;;
    pt:mail_not_yet)   echo "Nenhum transporte configurado: as funções do servidor só sabem enviar pelo Resend (opção 2)."
                       echo "   SMTP e simulação virão com o transporte híbrido (backlog F7). Até lá NENHUM e-mail"
                       echo "   sairá, e cada envio falhará com « RESEND_API_KEY absente » — de forma ruidosa, nunca em silêncio."
                       echo "   Rode ./install.sh de novo com uma chave Resend quando tiver uma." ;;
    es:mail_not_yet)   echo "Sin transporte configurado: las funciones del servidor solo saben enviar por Resend (opción 2)."
                       echo "   SMTP y simulación llegarán con el transporte híbrido (backlog F7). Hasta entonces NINGÚN correo"
                       echo "   saldrá, y cada envío fallará con « RESEND_API_KEY absente » — ruidosamente, nunca en silencio."
                       echo "   Volvé a ejecutar ./install.sh con una clave Resend cuando tengas una." ;;
    it:mail_not_yet)   echo "Nessun trasporto configurato: le funzioni del server sanno inviare solo tramite Resend (opzione 2)."
                       echo "   SMTP e simulazione arriveranno con il trasporto ibrido (backlog F7). Fino ad allora NESSUNA e-mail"
                       echo "   partirà, e ogni invio fallirà con « RESEND_API_KEY absente » — rumorosamente, mai in silenzio."
                       echo "   Rilancia ./install.sh con una chiave Resend quando ne avrai una." ;;
    de:mail_not_yet)   echo "Kein Transport konfiguriert: die Server-Funktionen können nur über Resend senden (Option 2)."
                       echo "   SMTP und Simulation kommen mit dem hybriden Transport (Backlog F7). Bis dahin geht KEINE E-Mail"
                       echo "   hinaus, und jeder Versand scheitert mit « RESEND_API_KEY absente » — laut, nie stillschweigend."
                       echo "   Starte ./install.sh erneut mit einem Resend-Schlüssel, sobald du einen hast." ;;
    ca:mail_not_yet)   echo "Cap transport configurat: les funcions del servidor només saben enviar per Resend (opció 2)."
                       echo "   SMTP i simulació arribaran amb el transport híbrid (backlog F7). Fins llavors CAP correu"
                       echo "   no sortirà, i cada enviament fallarà amb « RESEND_API_KEY absente » — sorollosament, mai en silenci."
                       echo "   Torna a executar ./install.sh amb una clau Resend quan en tinguis una." ;;
    eo:mail_not_yet)   echo "Neniu transporto agordita: la servilaj funkcioj scias sendi nur per Resend (opcio 2)."
                       echo "   SMTP kaj simulado venos kun la hibrida transporto (backlog F7). Ĝis tiam NENIU retletero"
                       echo "   foriros, kaj ĉiu sendo malsukcesos kun « RESEND_API_KEY absente » — laŭte, neniam silente."
                       echo "   Relanĉu ./install.sh kun Resend-ŝlosilo kiam vi havos unu." ;;
    nl:mail_not_yet)   echo "Geen transport ingesteld: de serverfuncties kunnen alleen via Resend versturen (optie 2)."
                       echo "   SMTP en simulatie komen met het hybride transport (backlog F7). Tot dan vertrekt er GEEN e-mail,"
                       echo "   en elke verzending mislukt met « RESEND_API_KEY absente » — luid, nooit in stilte."
                       echo "   Start ./install.sh opnieuw met een Resend-sleutel zodra je er een hebt." ;;
    el:mail_not_yet)   echo "Καμία μεταφορά δεν ρυθμίστηκε: οι συναρτήσεις του διακομιστή στέλνουν μόνο μέσω Resend (επιλογή 2)."
                       echo "   Το SMTP και η προσομοίωση θα έρθουν με την υβριδική μεταφορά (backlog F7). Ως τότε ΚΑΝΕΝΑ e-mail"
                       echo "   δεν θα φύγει, και κάθε αποστολή θα αποτυγχάνει με « RESEND_API_KEY absente » — θορυβωδώς, ποτέ σιωπηλά."
                       echo "   Ξανατρέξε το ./install.sh με ένα κλειδί Resend μόλις αποκτήσεις ένα." ;;

    fr:smtp_title)     echo "→ Configuration SMTP :" ;;
    en:smtp_title)     echo "→ SMTP configuration:" ;;
    pt:smtp_title)     echo "→ Configuração SMTP:" ;;
    es:smtp_title)     echo "→ Configuración SMTP:" ;;
    it:smtp_title)     echo "→ Configurazione SMTP:" ;;
    de:smtp_title)     echo "→ SMTP-Konfiguration:" ;;
    ca:smtp_title)     echo "→ Configuració SMTP:" ;;
    eo:smtp_title)     echo "→ SMTP-agordo:" ;;
    nl:smtp_title)     echo "→ SMTP-instelling:" ;;
    el:smtp_title)     echo "→ Ρύθμιση SMTP:" ;;

    fr:smtp_host)      printf "  Hôte SMTP (ex: mail.mon-domaine.org) : " ;;
    en:smtp_host)      printf "  SMTP host (e.g. mail.example.org): " ;;
    pt:smtp_host)      printf "  Host SMTP (ex: mail.meu-dominio.org): " ;;
    es:smtp_host)      printf "  Host SMTP (ej: mail.mi-dominio.org): " ;;
    it:smtp_host)      printf "  Host SMTP (es: mail.mio-dominio.org): " ;;
    de:smtp_host)      printf "  SMTP-Host (z. B. mail.meine-domain.org): " ;;
    ca:smtp_host)      printf "  Amfitrió SMTP (ex.: mail.el-meu-domini.org): " ;;
    eo:smtp_host)      printf "  SMTP-gastiganto (ekz.: mail.mia-domajno.org): " ;;
    nl:smtp_host)      printf "  SMTP-host (bv.: mail.mijn-domein.org): " ;;
    el:smtp_host)      printf "  Διακομιστής SMTP (π.χ.: mail.example.org): " ;;

    fr:smtp_port)      printf "  Port SMTP (ex: 587 ou 465) [défaut: 587] : " ;;
    en:smtp_port)      printf "  SMTP port (e.g. 587 or 465) [default: 587]: " ;;
    pt:smtp_port)      printf "  Porta SMTP (ex: 587 ou 465) [padrão: 587]: " ;;
    es:smtp_port)      printf "  Puerto SMTP (ej: 587 o 465) [por defecto: 587]: " ;;
    it:smtp_port)      printf "  Porta SMTP (es: 587 o 465) [predefinita: 587]: " ;;
    de:smtp_port)      printf "  SMTP-Port (z. B. 587 oder 465) [Standard: 587]: " ;;
    ca:smtp_port)      printf "  Port SMTP (ex.: 587 o 465) [per defecte: 587]: " ;;
    eo:smtp_port)      printf "  SMTP-pordo (ekz.: 587 aŭ 465) [defaŭlte: 587]: " ;;
    nl:smtp_port)      printf "  SMTP-poort (bv.: 587 of 465) [standaard: 587]: " ;;
    el:smtp_port)      printf "  Θύρα SMTP (π.χ.: 587 ή 465) [προεπιλογή: 587]: " ;;

    fr:smtp_user)      printf "  Utilisateur SMTP (votre adresse mail) : " ;;
    en:smtp_user)      printf "  SMTP user (your email address): " ;;
    pt:smtp_user)      printf "  Usuário SMTP (seu endereço de e-mail): " ;;
    es:smtp_user)      printf "  Usuarie SMTP (tu dirección de correo): " ;;
    it:smtp_user)      printf "  Utente SMTP (il tuo indirizzo e-mail): " ;;
    de:smtp_user)      printf "  SMTP-Benutzer*in (deine E-Mail-Adresse): " ;;
    ca:smtp_user)      printf "  Usuari SMTP (la teva adreça de correu): " ;;
    eo:smtp_user)      printf "  SMTP-uzanto (via retpoŝta adreso): " ;;
    nl:smtp_user)      printf "  SMTP-gebruiker (je e-mailadres): " ;;
    el:smtp_user)      printf "  Χρήστης SMTP (η διεύθυνση e-mail σου): " ;;

    fr:smtp_pass)      printf "  Mot de passe SMTP : " ;;
    en:smtp_pass)      printf "  SMTP password: " ;;
    pt:smtp_pass)      printf "  Senha SMTP: " ;;
    es:smtp_pass)      printf "  Contraseña SMTP: " ;;
    it:smtp_pass)      printf "  Password SMTP: " ;;
    de:smtp_pass)      printf "  SMTP-Passwort: " ;;
    ca:smtp_pass)      printf "  Contrasenya SMTP: " ;;
    eo:smtp_pass)      printf "  SMTP-pasvorto: " ;;
    nl:smtp_pass)      printf "  SMTP-wachtwoord: " ;;
    el:smtp_pass)      printf "  Κωδικός SMTP: " ;;

    fr:smtp_sender)    printf "  Adresse d'expédition (From) [défaut: %s] : " "$2" ;;
    en:smtp_sender)    printf "  Sender address (From) [default: %s]: " "$2" ;;
    pt:smtp_sender)    printf "  Endereço de envio (From) [padrão: %s]: " "$2" ;;
    es:smtp_sender)    printf "  Dirección de envío (From) [por defecto: %s]: " "$2" ;;
    it:smtp_sender)    printf "  Indirizzo di invio (From) [predefinito: %s]: " "$2" ;;
    de:smtp_sender)    printf "  Absenderadresse (From) [Standard: %s]: " "$2" ;;
    ca:smtp_sender)    printf "  Adreça d'enviament (From) [per defecte: %s]: " "$2" ;;
    eo:smtp_sender)    printf "  Sendanta adreso (From) [defaŭlte: %s]: " "$2" ;;
    nl:smtp_sender)    printf "  Afzenderadres (From) [standaard: %s]: " "$2" ;;
    el:smtp_sender)    printf "  Διεύθυνση αποστολής (From) [προεπιλογή: %s]: " "$2" ;;

    fr:ok_smtp)        echo "Service SMTP configuré ($2)" ;;
    en:ok_smtp)        echo "SMTP service configured ($2)" ;;
    pt:ok_smtp)        echo "Serviço SMTP configurado ($2)" ;;
    es:ok_smtp)        echo "Servicio SMTP configurado ($2)" ;;
    it:ok_smtp)        echo "Servizio SMTP configurato ($2)" ;;
    de:ok_smtp)        echo "SMTP-Dienst konfiguriert ($2)" ;;
    ca:ok_smtp)        echo "Servei SMTP configurat ($2)" ;;
    eo:ok_smtp)        echo "SMTP-servo agordita ($2)" ;;
    nl:ok_smtp)        echo "SMTP-dienst ingesteld ($2)" ;;
    el:ok_smtp)        echo "Η υπηρεσία SMTP ρυθμίστηκε ($2)" ;;

    fr:resend_title)   echo "→ Configuration API Resend :" ;;
    en:resend_title)   echo "→ Resend API configuration:" ;;
    pt:resend_title)   echo "→ Configuração API Resend:" ;;
    es:resend_title)   echo "→ Configuración API Resend:" ;;
    it:resend_title)   echo "→ Configurazione API Resend:" ;;
    de:resend_title)   echo "→ Resend-API-Konfiguration:" ;;
    ca:resend_title)   echo "→ Configuració API Resend:" ;;
    eo:resend_title)   echo "→ Agordo de la Resend-API:" ;;
    nl:resend_title)   echo "→ Instelling Resend-API:" ;;
    el:resend_title)   echo "→ Ρύθμιση του API Resend:" ;;

    fr:resend_key)     printf "  Clé API Resend (ex: re_123456...) : " ;;
    en:resend_key)     printf "  Resend API key (e.g. re_123456...): " ;;
    pt:resend_key)     printf "  Chave API Resend (ex: re_123456...): " ;;
    es:resend_key)     printf "  Clave API Resend (ej: re_123456...): " ;;
    it:resend_key)     printf "  Chiave API Resend (es: re_123456...): " ;;
    de:resend_key)     printf "  Resend-API-Schlüssel (z. B. re_123456...): " ;;
    ca:resend_key)     printf "  Clau API Resend (ex.: re_123456...): " ;;
    eo:resend_key)     printf "  Resend API-ŝlosilo (ekz.: re_123456...): " ;;
    nl:resend_key)     printf "  Resend API-sleutel (bv.: re_123456...): " ;;
    el:resend_key)     printf "  Κλειδί API Resend (π.χ.: re_123456...): " ;;

    fr:resend_sender)  printf "  Adresse d'expédition vérifiée sur Resend : " ;;
    en:resend_sender)  printf "  Verified sender address on Resend: " ;;
    pt:resend_sender)  printf "  Endereço de envio verificado no Resend: " ;;
    es:resend_sender)  printf "  Dirección de envío verificada en Resend: " ;;
    it:resend_sender)  printf "  Indirizzo di invio verificato su Resend: " ;;
    de:resend_sender)  printf "  Bei Resend verifizierte Absenderadresse: " ;;
    ca:resend_sender)  printf "  Adreça d'enviament verificada a Resend: " ;;
    eo:resend_sender)  printf "  Sendanta adreso kontrolita ĉe Resend: " ;;
    nl:resend_sender)  printf "  Bij Resend geverifieerd afzenderadres: " ;;
    el:resend_sender)  printf "  Επαληθευμένη διεύθυνση αποστολής στο Resend: " ;;

    fr:ok_resend)      echo "Service Resend configuré ($2)" ;;
    en:ok_resend)      echo "Resend service configured ($2)" ;;
    pt:ok_resend)      echo "Serviço Resend configurado ($2)" ;;
    es:ok_resend)      echo "Servicio Resend configurado ($2)" ;;
    it:ok_resend)      echo "Servizio Resend configurato ($2)" ;;
    de:ok_resend)      echo "Resend-Dienst konfiguriert ($2)" ;;
    ca:ok_resend)      echo "Servei Resend configurat ($2)" ;;
    eo:ok_resend)      echo "Resend-servo agordita ($2)" ;;
    nl:ok_resend)      echo "Resend-dienst ingesteld ($2)" ;;
    el:ok_resend)      echo "Η υπηρεσία Resend ρυθμίστηκε ($2)" ;;

    fr:ok_mock)        echo "Mode local activé (e-mails journalisés sans envoi externe)" ;;
    en:ok_mock)        echo "Local mode activated (emails logged, no external sending)" ;;
    pt:ok_mock)        echo "Modo local ativado (e-mails registrados sem envio externo)" ;;
    es:ok_mock)        echo "Modo local activado (correos registrados, sin envío externo)" ;;
    it:ok_mock)        echo "Modalità locale attivata (e-mail registrate, senza invio esterno)" ;;
    de:ok_mock)        echo "Lokaler Modus aktiviert (E-Mails protokolliert, kein externer Versand)" ;;
    ca:ok_mock)        echo "Mode local activat (correus registrats, sense enviament extern)" ;;
    eo:ok_mock)        echo "Loka reĝimo aktiva (retleteroj protokolitaj, sen ekstera sendo)" ;;
    nl:ok_mock)        echo "Lokale modus actief (e-mails gelogd, geen externe verzending)" ;;
    el:ok_mock)        echo "Τοπική λειτουργία ενεργή (καταγραφή e-mail, χωρίς εξωτερική αποστολή)" ;;

    # ── library name (GOUV-19) ────────────────────────────────────────────────
    fr:lib_title)      echo "📚 Initialisation de votre première bibliothèque (GOUV-19) :" ;;
    en:lib_title)      echo "📚 Initializing your first library (GOUV-19):" ;;
    pt:lib_title)      echo "📚 Inicialização da sua primeira biblioteca (GOUV-19):" ;;
    es:lib_title)      echo "📚 Inicialización de tu primera biblioteca (GOUV-19):" ;;
    it:lib_title)      echo "📚 Inizializzazione della tua prima biblioteca (GOUV-19):" ;;
    de:lib_title)      echo "📚 Einrichtung deiner ersten Bibliothek (GOUV-19):" ;;
    ca:lib_title)      echo "📚 Inicialització de la teva primera biblioteca (GOUV-19):" ;;
    eo:lib_title)      echo "📚 Pretigo de via unua biblioteko (GOUV-19):" ;;
    nl:lib_title)      echo "📚 Opzetten van je eerste bibliotheek (GOUV-19):" ;;
    el:lib_title)      echo "📚 Αρχικοποίηση της πρώτης σου βιβλιοθήκης (GOUV-19):" ;;

    fr:lib_prompt)     printf "  Nom de votre bibliothèque [défaut: %s] : " "$2" ;;
    en:lib_prompt)     printf "  Library name [default: %s]: " "$2" ;;
    pt:lib_prompt)     printf "  Nome da sua biblioteca [padrão: %s]: " "$2" ;;
    es:lib_prompt)     printf "  Nombre de tu biblioteca [por defecto: %s]: " "$2" ;;
    it:lib_prompt)     printf "  Nome della tua biblioteca [predefinito: %s]: " "$2" ;;
    de:lib_prompt)     printf "  Name deiner Bibliothek [Standard: %s]: " "$2" ;;
    ca:lib_prompt)     printf "  Nom de la teva biblioteca [per defecte: %s]: " "$2" ;;
    eo:lib_prompt)     printf "  Nomo de via biblioteko [defaŭlte: %s]: " "$2" ;;
    nl:lib_prompt)     printf "  Naam van je bibliotheek [standaard: %s]: " "$2" ;;
    el:lib_prompt)     printf "  Όνομα της βιβλιοθήκης σου [προεπιλογή: %s]: " "$2" ;;

    fr:ok_lib)         echo "Bibliothèque configurée : $2" ;;
    en:ok_lib)         echo "Library configured: $2" ;;
    pt:ok_lib)         echo "Biblioteca configurada: $2" ;;
    es:ok_lib)         echo "Biblioteca configurada: $2" ;;
    it:ok_lib)         echo "Biblioteca configurata: $2" ;;
    de:ok_lib)         echo "Bibliothek konfiguriert: $2" ;;
    ca:ok_lib)         echo "Biblioteca configurada: $2" ;;
    eo:ok_lib)         echo "Biblioteko agordita: $2" ;;
    nl:ok_lib)         echo "Bibliotheek ingesteld: $2" ;;
    el:ok_lib)         echo "Η βιβλιοθήκη ρυθμίστηκε: $2" ;;

    fr:admin_lib)      echo "  • Bibliothèque : $2" ;;
    en:admin_lib)      echo "  • Library      : $2" ;;
    pt:admin_lib)      echo "  • Biblioteca   : $2" ;;
    es:admin_lib)      echo "  • Biblioteca   : $2" ;;
    it:admin_lib)      echo "  • Biblioteca   : $2" ;;
    de:admin_lib)      echo "  • Bibliothek   : $2" ;;
    ca:admin_lib)      echo "  • Biblioteca   : $2" ;;
    eo:admin_lib)      echo "  • Biblioteko   : $2" ;;
    nl:admin_lib)      echo "  • Bibliotheek  : $2" ;;
    el:admin_lib)      echo "  • Βιβλιοθήκη   : $2" ;;

    # ── admin email (GOUV-19) ────────────────────────────────────────────────
    fr:admin_email_title)  echo "👤 Compte d'administration initial :" ;;
    en:admin_email_title)  echo "👤 Initial administration account:" ;;
    pt:admin_email_title)  echo "👤 Conta de administração inicial:" ;;
    es:admin_email_title)  echo "👤 Cuenta de administración inicial:" ;;
    it:admin_email_title)  echo "👤 Account di amministrazione iniziale:" ;;
    de:admin_email_title)  echo "👤 Anfängliches Verwaltungskonto:" ;;
    ca:admin_email_title)  echo "👤 Compte d'administració inicial:" ;;
    eo:admin_email_title)  echo "👤 Komenca administra konto:" ;;
    nl:admin_email_title)  echo "👤 Eerste beheerdersaccount:" ;;
    el:admin_email_title)  echo "👤 Αρχικός λογαριασμός διαχείρισης:" ;;

    fr:admin_email_prompt) printf "  Courriel de l'administrateur [défaut: %s] : " "$2" ;;
    en:admin_email_prompt) printf "  Administrator email [default: %s]: " "$2" ;;
    pt:admin_email_prompt) printf "  E-mail do administrador [padrão: %s]: " "$2" ;;
    es:admin_email_prompt) printf "  Correo de la administración [por defecto: %s]: " "$2" ;;
    it:admin_email_prompt) printf "  E-mail di chi amministra [predefinita: %s]: " "$2" ;;
    de:admin_email_prompt) printf "  E-Mail der Administrator*in [Standard: %s]: " "$2" ;;
    ca:admin_email_prompt) printf "  Correu de l'administració [per defecte: %s]: " "$2" ;;
    eo:admin_email_prompt) printf "  Retpoŝto de la administranto [defaŭlte: %s]: " "$2" ;;
    nl:admin_email_prompt) printf "  E-mail van het beheer [standaard: %s]: " "$2" ;;
    el:admin_email_prompt) printf "  E-mail της διαχείρισης [προεπιλογή: %s]: " "$2" ;;

    # ── rebuild confirmation ─────────────────────────────────────────────────
    fr:rebuild_warn)       echo "⚠️  Attention : cette opération va supprimer définitivement la base locale et ses données." ;;
    en:rebuild_warn)       echo "⚠️  Warning: this operation will permanently delete the local database and its data." ;;
    pt:rebuild_warn)       echo "⚠️  Atenção: esta operação apagará definitivamente o banco de dados local e seus dados." ;;
    es:rebuild_warn)       echo "⚠️  Atención: esta operación va a borrar definitivamente la base local y sus datos." ;;
    it:rebuild_warn)       echo "⚠️  Attenzione: questa operazione cancellerà definitivamente il database locale e i suoi dati." ;;
    de:rebuild_warn)       echo "⚠️  Achtung: dieser Vorgang löscht die lokale Datenbank und ihre Daten endgültig." ;;
    ca:rebuild_warn)       echo "⚠️  Atenció: aquesta operació esborrarà definitivament la base local i les seves dades." ;;
    eo:rebuild_warn)       echo "⚠️  Atentu: ĉi tiu operacio definitive forigos la lokan datumbazon kaj ĝiajn datumojn." ;;
    nl:rebuild_warn)       echo "⚠️  Let op: deze handeling verwijdert de lokale database en haar gegevens definitief." ;;
    el:rebuild_warn)       echo "⚠️  Προσοχή: αυτή η ενέργεια θα διαγράψει οριστικά την τοπική βάση και τα δεδομένα της." ;;

    fr:confirm_prompt)     printf "  Continuer ? [o/N] : " ;;
    en:confirm_prompt)     printf "  Continue? [y/N]: " ;;
    pt:confirm_prompt)     printf "  Continuar? [s/N]: " ;;
    es:confirm_prompt)     printf "  ¿Continuar? [s/N]: " ;;
    it:confirm_prompt)     printf "  Continuare? [s/N]: " ;;
    de:confirm_prompt)     printf "  Fortfahren? [j/N]: " ;;
    ca:confirm_prompt)     printf "  Continuar? [s/N]: " ;;
    eo:confirm_prompt)     printf "  Ĉu daŭrigi? [j/N]: " ;;
    nl:confirm_prompt)     printf "  Doorgaan? [j/N]: " ;;
    el:confirm_prompt)     printf "  Συνέχεια; [ν/Ο]: " ;;

    fr:abort)              echo "Opération annulée." ;;
    en:abort)              echo "Operation aborted." ;;
    pt:abort)              echo "Operação cancelada." ;;
    es:abort)              echo "Operación cancelada." ;;
    it:abort)              echo "Operazione annullata." ;;
    de:abort)              echo "Vorgang abgebrochen." ;;
    ca:abort)              echo "Operació anul·lada." ;;
    eo:abort)              echo "Operacio nuligita." ;;
    nl:abort)              echo "Handeling geannuleerd." ;;
    el:abort)              echo "Η ενέργεια ακυρώθηκε." ;;

    # ── step 3 ───────────────────────────────────────────────────────────────
    fr:step3)          echo "3/4 · Configuration et compilation du frontend" ;;
    en:step3)          echo "3/4 · Frontend configuration and build" ;;
    pt:step3)          echo "3/4 · Configuração e compilação do frontend" ;;
    es:step3)          echo "3/4 · Configuración y compilación del frontend" ;;
    it:step3)          echo "3/4 · Configurazione e compilazione del frontend" ;;
    de:step3)          echo "3/4 · Konfiguration und Bau des Frontends" ;;
    ca:step3)          echo "3/4 · Configuració i compilació del frontend" ;;
    eo:step3)          echo "3/4 · Agordo kaj kompilado de la frontend" ;;
    nl:step3)          echo "3/4 · Instelling en bouw van de frontend" ;;
    el:step3)          echo "3/4 · Ρύθμιση και μεταγλώττιση του frontend" ;;

    fr:ok_envlocal)    echo "Fichier .env.local créé et relié à la passerelle locale ($2)" ;;
    en:ok_envlocal)    echo "File .env.local created and linked to local gateway ($2)" ;;
    pt:ok_envlocal)    echo "Arquivo .env.local criado e vinculado ao gateway local ($2)" ;;
    es:ok_envlocal)    echo "Archivo .env.local creado y enlazado a la pasarela local ($2)" ;;
    it:ok_envlocal)    echo "File .env.local creato e collegato al gateway locale ($2)" ;;
    de:ok_envlocal)    echo "Datei .env.local erstellt und mit dem lokalen Gateway verbunden ($2)" ;;
    ca:ok_envlocal)    echo "Fitxer .env.local creat i enllaçat a la passarel·la local ($2)" ;;
    eo:ok_envlocal)    echo "Dosiero .env.local kreita kaj ligita al la loka kluzo ($2)" ;;
    nl:ok_envlocal)    echo "Bestand .env.local aangemaakt en verbonden met de lokale gateway ($2)" ;;
    el:ok_envlocal)    echo "Το αρχείο .env.local δημιουργήθηκε και συνδέθηκε με την τοπική πύλη ($2)" ;;

    fr:npm_install)    echo "→ Installation des dépendances JavaScript (npm ci)..." ;;
    en:npm_install)    echo "→ Installing JavaScript dependencies (npm ci)..." ;;
    pt:npm_install)    echo "→ Instalando dependências JavaScript (npm ci)..." ;;
    es:npm_install)    echo "→ Instalación de las dependencias JavaScript (npm ci)..." ;;
    it:npm_install)    echo "→ Installazione delle dipendenze JavaScript (npm ci)..." ;;
    de:npm_install)    echo "→ Installation der JavaScript-Abhängigkeiten (npm ci)..." ;;
    ca:npm_install)    echo "→ Instal·lació de les dependències JavaScript (npm ci)..." ;;
    eo:npm_install)    echo "→ Instalado de la JavaScript-dependaĵoj (npm ci)..." ;;
    nl:npm_install)    echo "→ Installatie van de JavaScript-afhankelijkheden (npm ci)..." ;;
    el:npm_install)    echo "→ Εγκατάσταση των εξαρτήσεων JavaScript (npm ci)..." ;;

    fr:ok_deps)        echo "Dépendances frontend installées." ;;
    en:ok_deps)        echo "Frontend dependencies installed." ;;
    pt:ok_deps)        echo "Dependências frontend instaladas." ;;
    es:ok_deps)        echo "Dependencias del frontend instaladas." ;;
    it:ok_deps)        echo "Dipendenze del frontend installate." ;;
    de:ok_deps)        echo "Frontend-Abhängigkeiten installiert." ;;
    ca:ok_deps)        echo "Dependències del frontend instal·lades." ;;
    eo:ok_deps)        echo "Frontend-dependaĵoj instalitaj." ;;
    nl:ok_deps)        echo "Frontend-afhankelijkheden geïnstalleerd." ;;
    el:ok_deps)        echo "Οι εξαρτήσεις του frontend εγκαταστάθηκαν." ;;

    fr:ok_deps_exist)  echo "Dépendances frontend déjà présentes (node_modules/)" ;;
    en:ok_deps_exist)  echo "Frontend dependencies already present (node_modules/)" ;;
    pt:ok_deps_exist)  echo "Dependências frontend já presentes (node_modules/)" ;;
    es:ok_deps_exist)  echo "Dependencias del frontend ya presentes (node_modules/)" ;;
    it:ok_deps_exist)  echo "Dipendenze del frontend già presenti (node_modules/)" ;;
    de:ok_deps_exist)  echo "Frontend-Abhängigkeiten bereits vorhanden (node_modules/)" ;;
    ca:ok_deps_exist)  echo "Dependències del frontend ja presents (node_modules/)" ;;
    eo:ok_deps_exist)  echo "Frontend-dependaĵoj jam ĉeestas (node_modules/)" ;;
    nl:ok_deps_exist)  echo "Frontend-afhankelijkheden al aanwezig (node_modules/)" ;;
    el:ok_deps_exist)  echo "Οι εξαρτήσεις του frontend υπάρχουν ήδη (node_modules/)" ;;

    fr:npm_build)      echo "→ Construction de l'application web pour Caddy (npm run build)..." ;;
    en:npm_build)      echo "→ Building web application for Caddy (npm run build)..." ;;
    pt:npm_build)      echo "→ Construindo aplicação web para o Caddy (npm run build)..." ;;
    es:npm_build)      echo "→ Construcción de la aplicación web para Caddy (npm run build)..." ;;
    it:npm_build)      echo "→ Costruzione dell'applicazione web per Caddy (npm run build)..." ;;
    de:npm_build)      echo "→ Bau der Web-Anwendung für Caddy (npm run build)..." ;;
    ca:npm_build)      echo "→ Construcció de l'aplicació web per a Caddy (npm run build)..." ;;
    eo:npm_build)      echo "→ Konstruado de la retaplikaĵo por Caddy (npm run build)..." ;;
    nl:npm_build)      echo "→ Bouw van de webtoepassing voor Caddy (npm run build)..." ;;
    el:npm_build)      echo "→ Κατασκευή της εφαρμογής ιστού για τον Caddy (npm run build)..." ;;

    fr:ok_build)       echo "Application web compilée dans dist/." ;;
    en:ok_build)       echo "Web application built in dist/." ;;
    pt:ok_build)       echo "Aplicação web compilada em dist/." ;;
    es:ok_build)       echo "Aplicación web compilada en dist/." ;;
    it:ok_build)       echo "Applicazione web compilata in dist/." ;;
    de:ok_build)       echo "Web-Anwendung in dist/ gebaut." ;;
    ca:ok_build)       echo "Aplicació web compilada a dist/." ;;
    eo:ok_build)       echo "Retaplikaĵo kompilita en dist/." ;;
    nl:ok_build)       echo "Webtoepassing gebouwd in dist/." ;;
    el:ok_build)       echo "Η εφαρμογή ιστού μεταγλωττίστηκε στο dist/." ;;

    fr:ok_build_exist) echo "Application web déjà prête (dist/)" ;;
    en:ok_build_exist) echo "Web application already ready (dist/)" ;;
    pt:ok_build_exist) echo "Aplicação web já pronta (dist/)" ;;
    es:ok_build_exist) echo "Aplicación web ya lista (dist/)" ;;
    it:ok_build_exist) echo "Applicazione web già pronta (dist/)" ;;
    de:ok_build_exist) echo "Web-Anwendung bereits fertig (dist/)" ;;
    ca:ok_build_exist) echo "Aplicació web ja a punt (dist/)" ;;
    eo:ok_build_exist) echo "Retaplikaĵo jam preta (dist/)" ;;
    nl:ok_build_exist) echo "Webtoepassing al klaar (dist/)" ;;
    el:ok_build_exist) echo "Η εφαρμογή ιστού είναι ήδη έτοιμη (dist/)" ;;

    # ── step 4 ───────────────────────────────────────────────────────────────
    fr:step4)          echo "4/4 · Déploiement et démarrage de la pile complète (Docker)" ;;
    en:step4)          echo "4/4 · Deployment and startup of the full stack (Docker)" ;;
    pt:step4)          echo "4/4 · Implantação e inicialização da pilha completa (Docker)" ;;
    es:step4)          echo "4/4 · Despliegue y arranque de la pila completa (Docker)" ;;
    it:step4)          echo "4/4 · Distribuzione e avvio della pila completa (Docker)" ;;
    de:step4)          echo "4/4 · Auslieferung und Start des gesamten Stacks (Docker)" ;;
    ca:step4)          echo "4/4 · Desplegament i engegada de la pila completa (Docker)" ;;
    eo:step4)          echo "4/4 · Disponigo kaj lanĉo de la tuta stako (Docker)" ;;
    nl:step4)          echo "4/4 · Uitrol en start van de volledige stack (Docker)" ;;
    el:step4)          echo "4/4 · Ανάπτυξη και εκκίνηση ολόκληρης της στοίβας (Docker)" ;;

    fr:rebuild_clean)  echo "→ Nettoyage des conteneurs et volumes existants (--rebuild)..." ;;
    en:rebuild_clean)  echo "→ Cleaning existing containers and volumes (--rebuild)..." ;;
    pt:rebuild_clean)  echo "→ Limpando contêineres e volumes existentes (--rebuild)..." ;;
    es:rebuild_clean)  echo "→ Limpieza de los contenedores y volúmenes existentes (--rebuild)..." ;;
    it:rebuild_clean)  echo "→ Pulizia dei container e dei volumi esistenti (--rebuild)..." ;;
    de:rebuild_clean)  echo "→ Aufräumen der vorhandenen Container und Volumes (--rebuild)..." ;;
    ca:rebuild_clean)  echo "→ Neteja dels contenidors i volums existents (--rebuild)..." ;;
    eo:rebuild_clean)  echo "→ Purigo de la ekzistantaj ujoj kaj volumoj (--rebuild)..." ;;
    nl:rebuild_clean)  echo "→ Opruimen van de bestaande containers en volumes (--rebuild)..." ;;
    el:rebuild_clean)  echo "→ Καθαρισμός των υπαρχόντων container και τόμων (--rebuild)..." ;;

    fr:db_existing)    echo "→ Base existante détectée ($2 tables). Démarrage des conteneurs et vérification des migrations..." ;;
    en:db_existing)    echo "→ Existing database detected ($2 tables). Starting containers and checking migrations..." ;;
    pt:db_existing)    echo "→ Base de dados existente detectada ($2 tabelas). Iniciando contêineres e verificando migrações..." ;;
    es:db_existing)    echo "→ Base existente detectada ($2 tablas). Arrancando los contenedores y verificando las migraciones..." ;;
    it:db_existing)    echo "→ Database esistente rilevato ($2 tabelle). Avvio dei container e verifica delle migrazioni..." ;;
    de:db_existing)    echo "→ Vorhandene Datenbank erkannt ($2 Tabellen). Container starten und Migrationen prüfen..." ;;
    ca:db_existing)    echo "→ Base existent detectada ($2 taules). Engegant els contenidors i verificant les migracions..." ;;
    eo:db_existing)    echo "→ Ekzistanta datumbazo trovita ($2 tabeloj). Lanĉo de la ujoj kaj kontrolo de la migradoj..." ;;
    nl:db_existing)    echo "→ Bestaande database gevonden ($2 tabellen). Containers starten en migraties controleren..." ;;
    el:db_existing)    echo "→ Εντοπίστηκε υπάρχουσα βάση ($2 πίνακες). Εκκίνηση των container και έλεγχος των μεταναστεύσεων..." ;;

    fr:db_fresh)       echo "→ Base vierge détectée. Lancement de l'amorçage complet..." ;;
    en:db_fresh)       echo "→ Fresh database detected. Running full bootstrap..." ;;
    pt:db_fresh)       echo "→ Base de dados vazia detectada. Executando bootstrap completo..." ;;
    es:db_fresh)       echo "→ Base vacía detectada. Lanzando el arranque completo..." ;;
    it:db_fresh)       echo "→ Database vuoto rilevato. Avvio dell'inizializzazione completa..." ;;
    de:db_fresh)       echo "→ Leere Datenbank erkannt. Vollständige Erstinitialisierung läuft..." ;;
    ca:db_fresh)       echo "→ Base buida detectada. Iniciant l'arrencada completa..." ;;
    eo:db_fresh)       echo "→ Malplena datumbazo trovita. Lanĉo de la kompleta pretigo..." ;;
    nl:db_fresh)       echo "→ Lege database gevonden. Volledige eerste opzet wordt gestart..." ;;
    el:db_fresh)       echo "→ Εντοπίστηκε κενή βάση. Εκκίνηση της πλήρους αρχικοποίησης..." ;;

    fr:health_title)   echo "Contrôle de santé global des services" ;;
    en:health_title)   echo "Global service health check" ;;
    pt:health_title)   echo "Verificação de saúde global dos serviços" ;;
    es:health_title)   echo "Control de salud global de los servicios" ;;
    it:health_title)   echo "Controllo di salute globale dei servizi" ;;
    de:health_title)   echo "Globale Gesundheitsprüfung der Dienste" ;;
    ca:health_title)   echo "Control de salut global dels serveis" ;;
    eo:health_title)   echo "Ĝenerala sankontrolo de la servoj" ;;
    nl:health_title)   echo "Algemene gezondheidscontrole van de diensten" ;;
    el:health_title)   echo "Γενικός έλεγχος υγείας των υπηρεσιών" ;;

    # ── final output ─────────────────────────────────────────────────────────
    fr:done_banner)    echo "✓ AnarBib est installé et prêt à être utilisé !" ;;
    en:done_banner)    echo "✓ AnarBib is installed and ready to use!" ;;
    pt:done_banner)    echo "✓ AnarBib instalado e pronto para usar!" ;;
    es:done_banner)    echo "✓ ¡AnarBib está instalado y listo para usar!" ;;
    it:done_banner)    echo "✓ AnarBib è installato e pronto all'uso!" ;;
    de:done_banner)    echo "✓ AnarBib ist installiert und einsatzbereit!" ;;
    ca:done_banner)    echo "✓ AnarBib està instal·lat i a punt per fer servir!" ;;
    eo:done_banner)    echo "✓ AnarBib estas instalita kaj preta por uzo!" ;;
    nl:done_banner)    echo "✓ AnarBib is geïnstalleerd en klaar voor gebruik!" ;;
    el:done_banner)    echo "✓ Το AnarBib εγκαταστάθηκε και είναι έτοιμο για χρήση!" ;;

    fr:open_browser)   echo "  👉 Ouvrez votre navigateur sur :" ;;
    en:open_browser)   echo "  👉 Open your browser at:" ;;
    pt:open_browser)   echo "  👉 Abra seu navegador em:" ;;
    es:open_browser)   echo "  👉 Abrí tu navegador en:" ;;
    it:open_browser)   echo "  👉 Apri il browser su:" ;;
    de:open_browser)   echo "  👉 Öffne deinen Browser unter:" ;;
    ca:open_browser)   echo "  👉 Obre el navegador a:" ;;
    eo:open_browser)   echo "  👉 Malfermu vian retumilon ĉe:" ;;
    nl:open_browser)   echo "  👉 Open je browser op:" ;;
    el:open_browser)   echo "  👉 Άνοιξε τον περιηγητή σου στο:" ;;

    fr:url_local)      echo "     • Local       : http://localhost" ;;
    en:url_local)      echo "     • Local       : http://localhost" ;;
    pt:url_local)      echo "     • Local       : http://localhost" ;;
    es:url_local)      echo "     • Local        : http://localhost" ;;
    it:url_local)      echo "     • Locale       : http://localhost" ;;
    de:url_local)      echo "     • Lokal        : http://localhost" ;;
    ca:url_local)      echo "     • Local        : http://localhost" ;;
    eo:url_local)      echo "     • Loke         : http://localhost" ;;
    nl:url_local)      echo "     • Lokaal       : http://localhost" ;;
    el:url_local)      echo "     • Τοπικά       : http://localhost" ;;

    fr:url_network)    echo "     • Réseau (IP) : http://$2" ;;
    en:url_network)    echo "     • Network (IP): http://$2" ;;
    pt:url_network)    echo "     • Rede (IP)   : http://$2" ;;
    es:url_network)    echo "     • Red (IP)     : http://$2" ;;
    it:url_network)    echo "     • Rete (IP)    : http://$2" ;;
    de:url_network)    echo "     • Netzwerk (IP): http://$2" ;;
    ca:url_network)    echo "     • Xarxa (IP)   : http://$2" ;;
    eo:url_network)    echo "     • Reto (IP)    : http://$2" ;;
    nl:url_network)    echo "     • Netwerk (IP) : http://$2" ;;
    el:url_network)    echo "     • Δίκτυο (IP)  : http://$2" ;;

    fr:url_domain)     echo "     • Domaine     : tout nom de domaine ou alias DNS pointant vers cette machine" ;;
    en:url_domain)     echo "     • Domain      : any domain name or DNS alias pointing to this machine" ;;
    pt:url_domain)     echo "     • Domínio     : qualquer nome de domínio ou alias DNS apontando para esta máquina" ;;
    es:url_domain)     echo "     • Dominio      : cualquier nombre de dominio o alias DNS que apunte a esta máquina" ;;
    it:url_domain)     echo "     • Dominio      : qualsiasi nome di dominio o alias DNS che punti a questa macchina" ;;
    de:url_domain)     echo "     • Domain       : jeder Domainname oder DNS-Alias, der auf diese Maschine zeigt" ;;
    ca:url_domain)     echo "     • Domini       : qualsevol nom de domini o àlies DNS que apunti a aquesta màquina" ;;
    eo:url_domain)     echo "     • Domajno      : ajna domajna nomo aŭ DNS-kromnomo montranta al ĉi tiu maŝino" ;;
    nl:url_domain)     echo "     • Domein       : elke domeinnaam of DNS-alias die naar deze machine wijst" ;;
    el:url_domain)     echo "     • Τομέας       : οποιοδήποτε όνομα τομέα ή ψευδώνυμο DNS δείχνει σε αυτή τη μηχανή" ;;

    fr:admin_title)    echo "👤 Compte d'administration initial créé (amorçage) :" ;;
    en:admin_title)    echo "👤 Initial admin account created (bootstrap):" ;;
    pt:admin_title)    echo "👤 Conta de administrador inicial criada (bootstrap):" ;;
    es:admin_title)    echo "👤 Cuenta de administración inicial creada (arranque):" ;;
    it:admin_title)    echo "👤 Account di amministrazione iniziale creato (avvio):" ;;
    de:admin_title)    echo "👤 Anfängliches Verwaltungskonto angelegt (Erstinitialisierung):" ;;
    ca:admin_title)    echo "👤 Compte d'administració inicial creat (arrencada):" ;;
    eo:admin_title)    echo "👤 Komenca administra konto kreita (pretigo):" ;;
    nl:admin_title)    echo "👤 Eerste beheerdersaccount aangemaakt (opzet):" ;;
    el:admin_title)    echo "👤 Ο αρχικός λογαριασμός διαχείρισης δημιουργήθηκε (αρχικοποίηση):" ;;

    fr:admin_email)    echo "  • Courriel     : $2" ;;
    en:admin_email)    echo "  • Email        : $2" ;;
    pt:admin_email)    echo "  • E-mail       : $2" ;;
    es:admin_email)    echo "  • Correo       : $2" ;;
    it:admin_email)    echo "  • E-mail       : $2" ;;
    de:admin_email)    echo "  • E-Mail       : $2" ;;
    ca:admin_email)    echo "  • Correu       : $2" ;;
    eo:admin_email)    echo "  • Retpoŝto     : $2" ;;
    nl:admin_email)    echo "  • E-mail       : $2" ;;
    el:admin_email)    echo "  • E-mail       : $2" ;;

    fr:admin_pass)     echo "  • Mot de passe : $2" ;;
    en:admin_pass)     echo "  • Password     : $2" ;;
    pt:admin_pass)     echo "  • Senha        : $2" ;;
    es:admin_pass)     echo "  • Contraseña   : $2" ;;
    it:admin_pass)     echo "  • Password     : $2" ;;
    de:admin_pass)     echo "  • Passwort     : $2" ;;
    ca:admin_pass)     echo "  • Contrasenya  : $2" ;;
    eo:admin_pass)     echo "  • Pasvorto     : $2" ;;
    nl:admin_pass)     echo "  • Wachtwoord   : $2" ;;
    el:admin_pass)     echo "  • Κωδικός      : $2" ;;

    fr:admin_warn)     echo "  ⚠️  Notez bien ce mot de passe aléatoire : il ne sera plus réaffiché !" ;;
    en:admin_warn)     echo "  ⚠️  Save this random password: it will not be displayed again!" ;;
    pt:admin_warn)     echo "  ⚠️  Guarde esta senha aleatória: ela não será exibida novamente!" ;;
    es:admin_warn)     echo "  ⚠️  Anotá bien esta contraseña aleatoria: ¡no se volverá a mostrar!" ;;
    it:admin_warn)     echo "  ⚠️  Annota bene questa password casuale: non verrà più mostrata!" ;;
    de:admin_warn)     echo "  ⚠️  Notiere dieses Zufallspasswort: es wird kein zweites Mal angezeigt!" ;;
    ca:admin_warn)     echo "  ⚠️  Apunta bé aquesta contrasenya aleatòria: no es tornarà a mostrar!" ;;
    eo:admin_warn)     echo "  ⚠️  Notu bone ĉi tiun hazardan pasvorton: ĝi ne plu estos montrata!" ;;
    nl:admin_warn)     echo "  ⚠️  Noteer dit willekeurige wachtwoord goed: het wordt niet opnieuw getoond!" ;;
    el:admin_warn)     echo "  ⚠️  Σημείωσε αυτόν τον τυχαίο κωδικό: δεν θα εμφανιστεί ξανά!" ;;

    fr:access_title)   echo "Points d'accès de votre installation :" ;;
    en:access_title)   echo "Access points for your installation:" ;;
    pt:access_title)   echo "Pontos de acesso da sua instalação:" ;;
    es:access_title)   echo "Puntos de acceso de tu instalación:" ;;
    it:access_title)   echo "Punti di accesso della tua installazione:" ;;
    de:access_title)   echo "Zugangspunkte deiner Installation:" ;;
    ca:access_title)   echo "Punts d'accés de la teva instal·lació:" ;;
    eo:access_title)   echo "Alirpunktoj de via instalaĵo:" ;;
    nl:access_title)   echo "Toegangspunten van je installatie:" ;;
    el:access_title)   echo "Σημεία πρόσβασης της εγκατάστασής σου:" ;;

    fr:access_web)     echo "  • Application Web (Interface) : port 80 (ou port 5173 en mode npm run dev)" ;;
    en:access_web)     echo "  • Web Application (Interface)  : port 80 (or port 5173 in npm run dev mode)" ;;
    pt:access_web)     echo "  • Aplicação Web (Interface)    : porta 80 (ou porta 5173 no modo npm run dev)" ;;
    es:access_web)     echo "  • Aplicación web (interfaz)    : puerto 80 (o puerto 5173 en modo npm run dev)" ;;
    it:access_web)     echo "  • Applicazione web (interfaccia): porta 80 (o porta 5173 in modalità npm run dev)" ;;
    de:access_web)     echo "  • Web-Anwendung (Oberfläche)   : Port 80 (oder Port 5173 im Modus npm run dev)" ;;
    ca:access_web)     echo "  • Aplicació web (interfície)   : port 80 (o port 5173 en mode npm run dev)" ;;
    eo:access_web)     echo "  • Retaplikaĵo (interfaco)      : pordo 80 (aŭ pordo 5173 en reĝimo npm run dev)" ;;
    nl:access_web)     echo "  • Webtoepassing (interface)    : poort 80 (of poort 5173 in modus npm run dev)" ;;
    el:access_web)     echo "  • Εφαρμογή ιστού (διεπαφή)     : θύρα 80 (ή θύρα 5173 σε λειτουργία npm run dev)" ;;

    fr:access_api)     echo "  • Passerelle API (Caddy)       : /rest/v1/, /auth/v1/, /storage/v1/, /functions/v1/" ;;
    en:access_api)     echo "  • API Gateway (Caddy)          : /rest/v1/, /auth/v1/, /storage/v1/, /functions/v1/" ;;
    pt:access_api)     echo "  • Gateway de API (Caddy)       : /rest/v1/, /auth/v1/, /storage/v1/, /functions/v1/" ;;
    es:access_api)     echo "  • Pasarela API (Caddy)         : /rest/v1/, /auth/v1/, /storage/v1/, /functions/v1/" ;;
    it:access_api)     echo "  • Gateway API (Caddy)          : /rest/v1/, /auth/v1/, /storage/v1/, /functions/v1/" ;;
    de:access_api)     echo "  • API-Gateway (Caddy)          : /rest/v1/, /auth/v1/, /storage/v1/, /functions/v1/" ;;
    ca:access_api)     echo "  • Passarel·la API (Caddy)      : /rest/v1/, /auth/v1/, /storage/v1/, /functions/v1/" ;;
    eo:access_api)     echo "  • API-kluzo (Caddy)            : /rest/v1/, /auth/v1/, /storage/v1/, /functions/v1/" ;;
    nl:access_api)     echo "  • API-gateway (Caddy)          : /rest/v1/, /auth/v1/, /storage/v1/, /functions/v1/" ;;
    el:access_api)     echo "  • Πύλη API (Caddy)             : /rest/v1/, /auth/v1/, /storage/v1/, /functions/v1/" ;;

    fr:access_auth)    echo "  • Point de santé Auth          : /auth/v1/health" ;;
    en:access_auth)    echo "  • Auth health endpoint         : /auth/v1/health" ;;
    pt:access_auth)    echo "  • Endpoint de saúde Auth       : /auth/v1/health" ;;
    es:access_auth)    echo "  • Punto de salud Auth          : /auth/v1/health" ;;
    it:access_auth)    echo "  • Punto di salute Auth         : /auth/v1/health" ;;
    de:access_auth)    echo "  • Auth-Gesundheitspunkt        : /auth/v1/health" ;;
    ca:access_auth)    echo "  • Punt de salut Auth           : /auth/v1/health" ;;
    eo:access_auth)    echo "  • Sanpunkto Auth               : /auth/v1/health" ;;
    nl:access_auth)    echo "  • Gezondheidspunt Auth         : /auth/v1/health" ;;
    el:access_auth)    echo "  • Σημείο υγείας Auth           : /auth/v1/health" ;;

    fr:access_rest)    echo "  • Point de santé API REST      : /rest/v1/" ;;
    en:access_rest)    echo "  • REST API health endpoint     : /rest/v1/" ;;
    pt:access_rest)    echo "  • Endpoint de saúde API REST   : /rest/v1/" ;;
    es:access_rest)    echo "  • Punto de salud API REST      : /rest/v1/" ;;
    it:access_rest)    echo "  • Punto di salute API REST     : /rest/v1/" ;;
    de:access_rest)    echo "  • REST-API-Gesundheitspunkt    : /rest/v1/" ;;
    ca:access_rest)    echo "  • Punt de salut API REST       : /rest/v1/" ;;
    eo:access_rest)    echo "  • Sanpunkto REST-API           : /rest/v1/" ;;
    nl:access_rest)    echo "  • Gezondheidspunt REST-API     : /rest/v1/" ;;
    el:access_rest)    echo "  • Σημείο υγείας REST API       : /rest/v1/" ;;

    fr:manage_title)   echo "Gestion de l'application :" ;;
    en:manage_title)   echo "Application management:" ;;
    pt:manage_title)   echo "Gerenciamento da aplicação:" ;;
    es:manage_title)   echo "Gestión de la aplicación:" ;;
    it:manage_title)   echo "Gestione dell'applicazione:" ;;
    de:manage_title)   echo "Verwaltung der Anwendung:" ;;
    ca:manage_title)   echo "Gestió de l'aplicació:" ;;
    eo:manage_title)   echo "Administrado de la aplikaĵo:" ;;
    nl:manage_title)   echo "Beheer van de toepassing:" ;;
    el:manage_title)   echo "Διαχείριση της εφαρμογής:" ;;

    fr:manage_stop)    echo "  • Arrêter l'ensemble         : ./install.sh --stop" ;;
    en:manage_stop)    echo "  • Stop everything            : ./install.sh --stop" ;;
    pt:manage_stop)    echo "  • Parar tudo                 : ./install.sh --stop" ;;
    es:manage_stop)    echo "  • Detener todo               : ./install.sh --stop" ;;
    it:manage_stop)    echo "  • Fermare tutto              : ./install.sh --stop" ;;
    de:manage_stop)    echo "  • Alles stoppen              : ./install.sh --stop" ;;
    ca:manage_stop)    echo "  • Aturar-ho tot              : ./install.sh --stop" ;;
    eo:manage_stop)    echo "  • Haltigi ĉion               : ./install.sh --stop" ;;
    nl:manage_stop)    echo "  • Alles stoppen              : ./install.sh --stop" ;;
    el:manage_stop)    echo "  • Διακοπή των πάντων         : ./install.sh --stop" ;;

    fr:manage_rebuild) echo "  • Réinitialiser de zéro      : ./install.sh --rebuild" ;;
    en:manage_rebuild) echo "  • Reset from scratch         : ./install.sh --rebuild" ;;
    pt:manage_rebuild) echo "  • Reiniciar do zero          : ./install.sh --rebuild" ;;
    es:manage_rebuild) echo "  • Reiniciar desde cero       : ./install.sh --rebuild" ;;
    it:manage_rebuild) echo "  • Ripartire da zero          : ./install.sh --rebuild" ;;
    de:manage_rebuild) echo "  • Von Null neu aufsetzen     : ./install.sh --rebuild" ;;
    ca:manage_rebuild) echo "  • Reiniciar des de zero      : ./install.sh --rebuild" ;;
    eo:manage_rebuild) echo "  • Rekomenci de nulo          : ./install.sh --rebuild" ;;
    nl:manage_rebuild) echo "  • Vanaf nul opnieuw opzetten : ./install.sh --rebuild" ;;
    el:manage_rebuild) echo "  • Επανεκκίνηση από το μηδέν  : ./install.sh --rebuild" ;;

    fr:manage_health)  echo "  • Vérifier la santé          : ./deploy/deploy.sh --controle" ;;
    en:manage_health)  echo "  • Check health               : ./deploy/deploy.sh --controle" ;;
    pt:manage_health)  echo "  • Verificar saúde            : ./deploy/deploy.sh --controle" ;;
    es:manage_health)  echo "  • Verificar la salud         : ./deploy/deploy.sh --controle" ;;
    it:manage_health)  echo "  • Verificare la salute       : ./deploy/deploy.sh --controle" ;;
    de:manage_health)  echo "  • Gesundheit prüfen          : ./deploy/deploy.sh --controle" ;;
    ca:manage_health)  echo "  • Verificar la salut         : ./deploy/deploy.sh --controle" ;;
    eo:manage_health)  echo "  • Kontroli la sanon          : ./deploy/deploy.sh --controle" ;;
    nl:manage_health)  echo "  • Gezondheid controleren     : ./deploy/deploy.sh --controle" ;;
    el:manage_health)  echo "  • Έλεγχος υγείας             : ./deploy/deploy.sh --controle" ;;

    fr:manage_update)  echo "  • Mettre à jour le code      : ./deploy/deploy.sh" ;;
    en:manage_update)  echo "  • Update code                : ./deploy/deploy.sh" ;;
    pt:manage_update)  echo "  • Update code                : ./deploy/deploy.sh" ;;
    es:manage_update)  echo "  • Actualizar el código       : ./deploy/deploy.sh" ;;
    it:manage_update)  echo "  • Aggiornare il codice       : ./deploy/deploy.sh" ;;
    de:manage_update)  echo "  • Code aktualisieren         : ./deploy/deploy.sh" ;;
    ca:manage_update)  echo "  • Actualitzar el codi        : ./deploy/deploy.sh" ;;
    eo:manage_update)  echo "  • Ĝisdatigi la kodon         : ./deploy/deploy.sh" ;;
    nl:manage_update)  echo "  • Code bijwerken             : ./deploy/deploy.sh" ;;
    el:manage_update)  echo "  • Ενημέρωση του κώδικα       : ./deploy/deploy.sh" ;;

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
ASSUME_YES=0
START=1
START_FRONT=1
ACTION="install"

while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes)
      ASSUME_YES=1
      ;;
    --lang)
      shift
      case "${1:-}" in
        fr|en|pt|es|it|de|ca|eo|nl|el) LANG_CODE="$1" ;;
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
      sed -n '2,18p' "$0"
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
#
# 16/09/2026 — l'installateur ne promet que ce que les fonctions serveur
# tiennent. Les Edge Functions de main (_shared/transport/email.ts et les deux
# copies dans notify-*) ne connaissent que Resend : sans RESEND_API_KEY, chaque
# envoi lève « RESEND_API_KEY absente ». Le transport hybride (SMTP, simulation
# sur MAIL_TRANSPORT=mock explicite) était la PR #29, fermée par son auteur le
# 16/09 sans remplacement : backlog F7. Tant qu'il n'est pas dans main, les
# options [1] et [3] sont annoncées « à venir », ne configurent rien, et le
# disent ; la touche Entrée ne choisit rien non plus. Le bloc de saisie SMTP
# reviendra avec F7 — ses libellés (smtp_*) sont gardés pour ça.
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

  case "$MAIL_CHOICE" in
    2)
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
      # [1], [3], Entrée ou autre : rien n'est écrit, et on dit pourquoi.
      echo ""
      avertir "$(t mail_not_yet)"
      ;;
  esac
fi

# Initialisation de la première bibliothèque et du compte administrateur (GOUV-19)
DEFAULT_LIB="Bibliothèque Autonome"
[ "$LANG_CODE" = "en" ] && DEFAULT_LIB="Autonomous Library"
[ "$LANG_CODE" = "pt" ] && DEFAULT_LIB="Biblioteca Autônoma"

LIB_NAME=""
ADMIN_EMAIL=""
if [ -t 0 ]; then
  echo ""
  t lib_title
  while [ -z "$LIB_NAME" ]; do
    t lib_prompt "$DEFAULT_LIB"
    read -r LIB_NAME
  done
  succes "$(t ok_lib "$LIB_NAME")"

  echo ""
  t admin_email_title
  DEFAULT_ADMIN_EMAIL="admin@anarbib.local"
  if [ "$MODE" = "prod" ] && [ -n "$DOMAINE_PROD" ]; then
    CLEAN_DOM="${DOMAINE_PROD#https://}"
    CLEAN_DOM="${CLEAN_DOM#http://}"
    CLEAN_DOM="${CLEAN_DOM%%/*}"
    DEFAULT_ADMIN_EMAIL="admin@${CLEAN_DOM}"
  fi
  t admin_email_prompt "$DEFAULT_ADMIN_EMAIL"
  read -r USER_ADMIN_EMAIL
  [ -n "$USER_ADMIN_EMAIL" ] && ADMIN_EMAIL="$USER_ADMIN_EMAIL"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 3. Frontend build
# ─────────────────────────────────────────────────────────────────────────────
dire "$(t step3)"

ANON_KEY="$(grep '^ANON_KEY=' deploy/.env | cut -d= -f2-)"

# Configuration de .env.local (sans écraser les clés personnalisées existantes)
if [ ! -f .env.local ]; then
  cat > .env.local <<EOF
# AnarBib — configuration locale générée par ./install.sh
VITE_SUPABASE_URL=auto
VITE_SUPABASE_PUBLISHABLE_KEY=${ANON_KEY}
EOF
else
  if grep -q '^VITE_SUPABASE_URL=' .env.local; then
    sed -i 's|^VITE_SUPABASE_URL=.*|VITE_SUPABASE_URL=auto|' .env.local
  else
    echo "VITE_SUPABASE_URL=auto" >> .env.local
  fi
  if grep -q '^VITE_SUPABASE_PUBLISHABLE_KEY=' .env.local; then
    sed -i "s|^VITE_SUPABASE_PUBLISHABLE_KEY=.*|VITE_SUPABASE_PUBLISHABLE_KEY=${ANON_KEY}|" .env.local
  else
    echo "VITE_SUPABASE_PUBLISHABLE_KEY=${ANON_KEY}" >> .env.local
  fi
fi
succes "$(t ok_envlocal "auto")"

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
    if [ "$ASSUME_YES" = "0" ] && [ -t 0 ]; then
      echo ""
      t rebuild_warn
      t confirm_prompt
      read -r REPONSE_REBUILD
      case "$REPONSE_REBUILD" in
        [yYoOsSjJ]*|ν*|Ν*) ;;   # oui/yes/sim/sí/sì/ja/jes/ναι
        *) echo "$(t abort)"; exit 0 ;;
      esac
    fi
    echo "$(t rebuild_clean)"
    docker compose down -v
    ./bootstrap.sh --depuis-le-depot --sel-jetable
  else
    mkdir -p ../dist
    docker compose up -d db >/dev/null 2>&1

    # Attente active de pg_isready (évite qu'une base lente soit prise pour vide)
    attente_db=0
    while [ "$attente_db" -lt 30 ]; do
      if docker compose exec -T db pg_isready -h localhost -U supabase_admin -d postgres >/dev/null 2>&1; then
        break
      fi
      sleep 1
      attente_db=$((attente_db + 1))
    done

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

  node deploy/scripts/seed-admin.mjs "$MODE" "$DOMAINE_PROD" "$LIB_NAME" "$ADMIN_EMAIL" "$LANG_CODE"
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
