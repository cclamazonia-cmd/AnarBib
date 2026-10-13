/* ===========================================================================
 * i18n-add-b42-2fa2-inscription-guidee.cjs — REGISTRE 2FA-2 (14/10/2026) :
 * l'écran d'inscription TOTP conduit jusque dans l'application.
 *   - le lien otpauth:// à côté du code QR ;
 *   - « Copier la clé » dit si la copie a marché, sinon sélectionne la clé ;
 *   - un code refusé À L'INSCRIPTION nomme les trois causes réelles
 *     (twoFactor.error.badCodeEnroll ; twoFactor.error.badCode reste celui de
 *     la connexion) ;
 *   - le volet « J'utilise… » : Aegis, FreeOTP+, KeePassXC, une autre app.
 *
 * LES LIBELLÉS DE MENUS NE SONT PAS TRADUITS DE TÊTE. Ils sont relevés le
 * 14/10/2026 dans les fichiers de traduction des applications elles-mêmes :
 *   - KeePassXC  9e0f57a (22/09/2026) share/translations/keepassxc_<l>.ts,
 *     contextes MainWindow (« TOTP », « Set up TOTP… », « Copy &TOTP ») et
 *     TotpSetupDialog (« Secret Key: », « Default settings (RFC 6238) ») ;
 *     le sous-menu TOTP est dans le clic droit (m_entryContextMenu) ;
 *   - Aegis      d6f4e59 (06/09/2026) app/src/main/res/values-<l>/strings.xml
 *     (scan, enter_manually, secret, issuer, save ; fab_menu.xml) ;
 *   - FreeOTP+   1e1e265 (23/08/2026) app/src/main/res/values-<l>/strings.xml
 *     (scan_qr_code, add_token, issuer, account, secret, add ; menu/main.xml).
 * Aegis et FreeOTP+ déclarent le schéma otpauth dans leur manifeste.
 * Langues absentes, dites dans le texte, libellé anglais entre guillemets :
 * espéranto (aucune des trois), FreeOTP+ en nl et el ; KeePassXC en ca laisse
 * « Set up TOTP… », « Secret Key: » et « Default settings (RFC 6238) » en
 * anglais (traduction inachevée). Les guillemets suivent chaque locale.
 * Une nouvelle langue (ro) : relever de nouveau, ne pas recopier.
 *
 * Tutoiement ; pt-BR au « você » ; el au singulier ; de : Strg (clavier
 * allemand, et KeePassXC affiche Strg+T). {lien} = twoFactor.enroll.openLink.
 * Idempotent : une clé déjà posée n'est réécrite que si sa valeur a changé ici.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const VAL = {
  fr: {
    'twoFactor.enroll.openLink': "Ouvrir dans l'application d'authentification",
    'twoFactor.enroll.openLinkHint': "Sur téléphone, ce lien ouvre directement ton application d'authentification, sans scanner.",
    'twoFactor.enroll.copied': 'Clé copiée. Colle-la dans ton application.',
    'twoFactor.enroll.copyFailed': "Le presse-papiers n'est pas disponible : la clé est sélectionnée, copie-la avec Ctrl+C (ou par un appui long sur téléphone).",
    'twoFactor.error.badCodeEnroll': "Code refusé. Trois causes possibles : le code a expiré (fais-en afficher un nouveau et saisis-le aussitôt) ; l'heure de l'appareil est décalée (mets-la en réglage automatique) ; la clé a été mal recopiée à la main (corrige-la dans l'application, de préférence en la collant).",
    'twoFactor.guide.summary': 'Où ranger la clé dans ton application ?',
    'twoFactor.guide.legend': "J'utilise…",
    'twoFactor.guide.otherApp': 'une autre application',
    'twoFactor.guide.pick': 'Choisis ton application pour voir les étapes.',
    'twoFactor.guide.aegis.1': "Ouvre Aegis et touche le bouton « + » en bas de l'écran.",
    'twoFactor.guide.aegis.2': 'Choisis « Scanner code QR » et vise le code QR ci-dessus. Sur le téléphone même, le lien « {lien} » fait la même chose sans scanner.',
    'twoFactor.guide.aegis.3': 'Sans caméra : choisis « Saisir manuellement », colle la clé dans « Code secret », écris AnarBib dans « Émetteur », puis touche « Enregistrer » en haut.',
    'twoFactor.guide.aegis.4': "Le code à six chiffres apparaît dans la liste d'Aegis : saisis-le ci-dessous.",
    'twoFactor.guide.freeotp.1': "Ouvre FreeOTP+, touche « Scanner le code QR » (l'icône de code QR en haut) et vise le code QR ci-dessus. Sur le téléphone même, le lien « {lien} » évite le scan.",
    'twoFactor.guide.freeotp.2': 'Sans caméra : touche « Ajouter un jeton », écris AnarBib dans « Émetteur » et ton adresse dans « Compte », colle la clé dans « Secret », puis touche « Ajouter ».',
    'twoFactor.guide.freeotp.3': "Touche le jeton AnarBib dans la liste : le code à six chiffres s'affiche. Saisis-le ci-dessous.",
    'twoFactor.guide.keepassxc.1': "Dans ta base KeePassXC, ouvre ou crée l'entrée de ton compte AnarBib.",
    'twoFactor.guide.keepassxc.2': 'Clic droit sur cette entrée → « Mot de passe dynamique fondé sur le temps (TOTP) » → « Configurer le TOTP… ».',
    'twoFactor.guide.keepassxc.3': 'Colle la clé dans « Clé secrète : », garde « Paramètres par défaut (RFC 6238) » et valide.',
    'twoFactor.guide.keepassxc.4': "Ensuite, l'entrée sélectionnée, Ctrl+T copie le code (« Copier le TOTP ») ; avec l'extension KeePassXC-Browser, il se remplit d'un clic dans le champ du code.",
    'twoFactor.guide.other.1': 'Dans ton application, cherche « + », « Ajouter » ou « Scanner un code QR », puis vise le code QR ci-dessus. Sur le téléphone même, le lien « {lien} » évite le scan.',
    'twoFactor.guide.other.2': 'Sans caméra, choisis la saisie manuelle et colle la clé ; garde les réglages par défaut (TOTP, six chiffres, 30 secondes).',
    'twoFactor.guide.other.3': "Saisis ci-dessous le code à six chiffres que l'application affiche.",
  },
  'pt-BR': {
    'twoFactor.enroll.openLink': 'Abrir no aplicativo de autenticação',
    'twoFactor.enroll.openLinkHint': 'No celular, este link abre direto o seu aplicativo de autenticação, sem escanear.',
    'twoFactor.enroll.copied': 'Chave copiada. Cole no seu aplicativo.',
    'twoFactor.enroll.copyFailed': 'A área de transferência não está disponível: a chave ficou selecionada, copie com Ctrl+C (ou com um toque longo no celular).',
    'twoFactor.error.badCodeEnroll': 'Código recusado. Três causas possíveis: o código expirou (mostre um novo e digite na hora); a hora do aparelho está errada (deixe no ajuste automático); a chave foi copiada errado à mão (corrija no aplicativo, de preferência colando).',
    'twoFactor.guide.summary': 'Onde guardar a chave no seu aplicativo?',
    'twoFactor.guide.legend': 'Eu uso…',
    'twoFactor.guide.otherApp': 'outro aplicativo',
    'twoFactor.guide.pick': 'Escolha o seu aplicativo para ver as etapas.',
    'twoFactor.guide.aegis.1': 'Abra o Aegis e toque no botão «+» na parte de baixo da tela.',
    'twoFactor.guide.aegis.2': 'Escolha «Ler código QR» e aponte para o código QR acima. No próprio celular, o link «{lien}» faz o mesmo sem escanear.',
    'twoFactor.guide.aegis.3': 'Sem câmera: escolha «Digitar manualmente», cole a chave em «Segredo», escreva AnarBib em «Emissor» e toque em «Salvar», no alto.',
    'twoFactor.guide.aegis.4': 'O código de seis dígitos aparece na lista do Aegis: digite-o abaixo.',
    'twoFactor.guide.freeotp.1': 'Abra o FreeOTP+, toque em «Escanear código QR» (o ícone de código QR no alto) e aponte para o código QR acima. No próprio celular, o link «{lien}» dispensa o escaneamento.',
    'twoFactor.guide.freeotp.2': 'Sem câmera: toque em «Adicionar token», escreva AnarBib em «Emissor» e o seu e-mail em «Conta», cole a chave em «Segredo» e toque em «Adicionar».',
    'twoFactor.guide.freeotp.3': 'Toque no token AnarBib na lista: o código de seis dígitos aparece. Digite-o abaixo.',
    'twoFactor.guide.keepassxc.1': 'No seu banco de dados do KeePassXC, abra ou crie a entrada da sua conta AnarBib.',
    'twoFactor.guide.keepassxc.2': 'Clique com o botão direito nessa entrada → «TOTP» → «Configurar TOTP».',
    'twoFactor.guide.keepassxc.3': 'Cole a chave em «Chave secreta:», mantenha «Configurações padrão (RFC 6238)» e confirme.',
    'twoFactor.guide.keepassxc.4': 'Depois, com a entrada selecionada, Ctrl+T copia o código («Copiar TOTP»); com a extensão KeePassXC-Browser, ele é preenchido com um clique no campo do código.',
    'twoFactor.guide.other.1': 'No seu aplicativo, procure «+», «Adicionar» ou «Escanear código QR» e aponte para o código QR acima. No próprio celular, o link «{lien}» dispensa o escaneamento.',
    'twoFactor.guide.other.2': 'Sem câmera, escolha a digitação manual e cole a chave; mantenha os ajustes padrão (TOTP, seis dígitos, 30 segundos).',
    'twoFactor.guide.other.3': 'Digite abaixo o código de seis dígitos que o aplicativo mostra.',
  },
  es: {
    'twoFactor.enroll.openLink': 'Abrir en la aplicación de autenticación',
    'twoFactor.enroll.openLinkHint': 'En el móvil, este enlace abre directamente tu aplicación de autenticación, sin escanear.',
    'twoFactor.enroll.copied': 'Clave copiada. Pégala en tu aplicación.',
    'twoFactor.enroll.copyFailed': 'El portapapeles no está disponible: la clave quedó seleccionada, cópiala con Ctrl+C (o con una pulsación larga en el móvil).',
    'twoFactor.error.badCodeEnroll': 'Código rechazado. Tres causas posibles: el código caducó (haz que aparezca uno nuevo y escríbelo enseguida); la hora del dispositivo está desfasada (ponla en ajuste automático); la clave se copió mal a mano (corrígela en la aplicación, mejor pegándola).',
    'twoFactor.guide.summary': '¿Dónde guardar la clave en tu aplicación?',
    'twoFactor.guide.legend': 'Uso…',
    'twoFactor.guide.otherApp': 'otra aplicación',
    'twoFactor.guide.pick': 'Elige tu aplicación para ver los pasos.',
    'twoFactor.guide.aegis.1': 'Abre Aegis y toca el botón «+» en la parte de abajo de la pantalla.',
    'twoFactor.guide.aegis.2': 'Elige «Escanear un código QR» y apunta al código QR de arriba. En el propio móvil, el enlace «{lien}» hace lo mismo sin escanear.',
    'twoFactor.guide.aegis.3': 'Sin cámara: elige «Introducir manualmente», pega la clave en «Código secreto», escribe AnarBib en «Emisor» y toca «Guardar», arriba.',
    'twoFactor.guide.aegis.4': 'El código de seis cifras aparece en la lista de Aegis: escríbelo abajo.',
    'twoFactor.guide.freeotp.1': 'Abre FreeOTP+, toca «Escanear código QR» (el icono de código QR, arriba) y apunta al código QR de más arriba. En el propio móvil, el enlace «{lien}» evita escanear.',
    'twoFactor.guide.freeotp.2': 'Sin cámara: toca «Añadir Token», escribe AnarBib en «Emisor» y tu correo en «Cuenta», pega la clave en «Secreto» y toca «Añadir».',
    'twoFactor.guide.freeotp.3': 'Toca el token AnarBib en la lista: aparece el código de seis cifras. Escríbelo abajo.',
    'twoFactor.guide.keepassxc.1': 'En tu base de datos de KeePassXC, abre o crea la entrada de tu cuenta AnarBib.',
    'twoFactor.guide.keepassxc.2': 'Clic derecho en esa entrada → «TOTP» → «Configurar TOTP...».',
    'twoFactor.guide.keepassxc.3': 'Pega la clave en «Clave secreta:», deja «Configuración predeterminada (RFC 6238)» y confirma.',
    'twoFactor.guide.keepassxc.4': 'Después, con la entrada seleccionada, Ctrl+T copia el código («Copiar TOTP»); con la extensión KeePassXC-Browser, se rellena con un clic en el campo del código.',
    'twoFactor.guide.other.1': 'En tu aplicación, busca «+», «Añadir» o «Escanear código QR» y apunta al código QR de arriba. En el propio móvil, el enlace «{lien}» evita escanear.',
    'twoFactor.guide.other.2': 'Sin cámara, elige la introducción manual y pega la clave; deja los ajustes predeterminados (TOTP, seis cifras, 30 segundos).',
    'twoFactor.guide.other.3': 'Escribe abajo el código de seis cifras que muestra la aplicación.',
  },
  ca: {
    'twoFactor.enroll.openLink': "Obre a l'aplicació d'autenticació",
    'twoFactor.enroll.openLinkHint': "Al mòbil, aquest enllaç obre directament la teva aplicació d'autenticació, sense escanejar.",
    'twoFactor.enroll.copied': "Clau copiada. Enganxa-la a l'aplicació.",
    'twoFactor.enroll.copyFailed': 'El porta-retalls no està disponible: la clau ha quedat seleccionada, copia-la amb Ctrl+C (o amb una pulsació llarga al mòbil).',
    'twoFactor.error.badCodeEnroll': "Codi rebutjat. Tres causes possibles: el codi ha caducat (fes-ne aparèixer un de nou i escriu-lo de seguida); l'hora de l'aparell està desajustada (posa-la en ajust automàtic); la clau s'ha copiat malament a mà (corregeix-la a l'aplicació, millor enganxant-la).",
    'twoFactor.guide.summary': 'On es desa la clau a la teva aplicació?',
    'twoFactor.guide.legend': 'Faig servir…',
    'twoFactor.guide.otherApp': 'una altra aplicació',
    'twoFactor.guide.pick': "Tria la teva aplicació per veure'n els passos.",
    'twoFactor.guide.aegis.1': 'Obre Aegis i toca el botó «+» a la part de baix de la pantalla.',
    'twoFactor.guide.aegis.2': "Tria «Escaneja un codi QR» i apunta al codi QR de més amunt. Al mateix mòbil, l'enllaç «{lien}» fa el mateix sense escanejar.",
    'twoFactor.guide.aegis.3': 'Sense càmera: tria «Introdueix manualment», enganxa la clau a «Secret», escriu AnarBib a «Emissor» i toca «Guardar», a dalt.',
    'twoFactor.guide.aegis.4': "El codi de sis xifres apareix a la llista d'Aegis: escriu-lo a sota.",
    'twoFactor.guide.freeotp.1': "Obre FreeOTP+, toca «Escaneja un codi QR» (la icona de codi QR, a dalt) i apunta al codi QR de més amunt. Al mateix mòbil, l'enllaç «{lien}» estalvia l'escaneig.",
    'twoFactor.guide.freeotp.2': 'Sense càmera: toca «Afegeix nou OTP», escriu AnarBib a «Emissor» i la teva adreça a «Compte», enganxa la clau a «Clau secreta» i toca «Afegeix».',
    'twoFactor.guide.freeotp.3': "Toca l'entrada AnarBib a la llista: apareix el codi de sis xifres. Escriu-lo a sota.",
    'twoFactor.guide.keepassxc.1': "A la teva base de dades de KeePassXC, obre o crea l'entrada del teu compte AnarBib. KeePassXC en català deixa alguns d'aquests menús en anglès: aquí surten tal com es veuen.",
    'twoFactor.guide.keepassxc.2': 'Clic dret sobre aquesta entrada → «TOTP» → «Set up TOTP…».',
    'twoFactor.guide.keepassxc.3': 'Enganxa la clau a «Secret Key:», deixa «Default settings (RFC 6238)» i confirma.',
    'twoFactor.guide.keepassxc.4': "Després, amb l'entrada seleccionada, Ctrl+T copia el codi («Còpia TOTP»); amb l'extensió KeePassXC-Browser, s'omple amb un clic al camp del codi.",
    'twoFactor.guide.other.1': "A la teva aplicació, busca «+», «Afegeix» o «Escaneja un codi QR» i apunta al codi QR de més amunt. Al mateix mòbil, l'enllaç «{lien}» estalvia l'escaneig.",
    'twoFactor.guide.other.2': 'Sense càmera, tria la introducció manual i enganxa la clau; deixa els ajustos per defecte (TOTP, sis xifres, 30 segons).',
    'twoFactor.guide.other.3': "Escriu a sota el codi de sis xifres que mostra l'aplicació.",
  },
  it: {
    'twoFactor.enroll.openLink': "Apri nell'app di autenticazione",
    'twoFactor.enroll.openLinkHint': 'Sul telefono, questo link apre direttamente la tua app di autenticazione, senza scansionare.',
    'twoFactor.enroll.copied': 'Chiave copiata. Incollala nella tua app.',
    'twoFactor.enroll.copyFailed': 'Gli appunti non sono disponibili: la chiave è selezionata, copiala con Ctrl+C (o con una pressione prolungata sul telefono).',
    'twoFactor.error.badCodeEnroll': "Codice rifiutato. Tre cause possibili: il codice è scaduto (fanne comparire uno nuovo e inseriscilo subito); l'ora del dispositivo è sfasata (mettila in regolazione automatica); la chiave è stata ricopiata male a mano (correggila nell'app, meglio incollandola).",
    'twoFactor.guide.summary': 'Dove salvare la chiave nella tua app?',
    'twoFactor.guide.legend': 'Uso…',
    'twoFactor.guide.otherApp': "un'altra app",
    'twoFactor.guide.pick': 'Scegli la tua app per vedere i passaggi.',
    'twoFactor.guide.aegis.1': 'Apri Aegis e tocca il pulsante «+» in basso sullo schermo.',
    'twoFactor.guide.aegis.2': 'Scegli «Scansiona codice QR» e inquadra il codice QR qui sopra. Sullo stesso telefono, il link «{lien}» fa lo stesso senza scansionare.',
    'twoFactor.guide.aegis.3': 'Senza fotocamera: scegli «Inserisci manualmente», incolla la chiave in «Chiave segreta», scrivi AnarBib in «Servizio» e tocca «Salva», in alto.',
    'twoFactor.guide.aegis.4': "Il codice di sei cifre compare nell'elenco di Aegis: inseriscilo qui sotto.",
    'twoFactor.guide.freeotp.1': "Apri FreeOTP+, tocca «Scansiona codice QR» (l'icona del codice QR, in alto) e inquadra il codice QR qui sopra. Sullo stesso telefono, il link «{lien}» evita la scansione.",
    'twoFactor.guide.freeotp.2': 'Senza fotocamera: tocca «Aggiungi token», scrivi AnarBib in «Emittente» e il tuo indirizzo in «Conto», incolla la chiave in «Segreto» e tocca «Aggiungi».',
    'twoFactor.guide.freeotp.3': "Tocca il token AnarBib nell'elenco: compare il codice di sei cifre. Inseriscilo qui sotto.",
    'twoFactor.guide.keepassxc.1': 'Nel tuo database KeePassXC, apri o crea la voce del tuo account AnarBib.',
    'twoFactor.guide.keepassxc.2': 'Clic destro su questa voce → «TOTP» → «Configura TOTP...».',
    'twoFactor.guide.keepassxc.3': 'Incolla la chiave in «Chiave segreta:», lascia «Impostazioni predefinite (RFC 6238)» e conferma.',
    'twoFactor.guide.keepassxc.4': "Poi, con la voce selezionata, Ctrl+T copia il codice («Copia TOTP»); con l'estensione KeePassXC-Browser, si compila con un clic nel campo del codice.",
    'twoFactor.guide.other.1': 'Nella tua app, cerca «+», «Aggiungi» o «Scansiona codice QR» e inquadra il codice QR qui sopra. Sullo stesso telefono, il link «{lien}» evita la scansione.',
    'twoFactor.guide.other.2': "Senza fotocamera, scegli l'inserimento manuale e incolla la chiave; lascia le impostazioni predefinite (TOTP, sei cifre, 30 secondi).",
    'twoFactor.guide.other.3': "Inserisci qui sotto il codice di sei cifre che l'app mostra.",
  },
  de: {
    'twoFactor.enroll.openLink': 'In der Authentifizierungs-App öffnen',
    'twoFactor.enroll.openLinkHint': 'Auf dem Telefon öffnet dieser Link deine Authentifizierungs-App direkt, ohne Scannen.',
    'twoFactor.enroll.copied': 'Schlüssel kopiert. Füge ihn in deiner App ein.',
    'twoFactor.enroll.copyFailed': 'Die Zwischenablage ist nicht verfügbar: Der Schlüssel ist markiert, kopiere ihn mit Strg+C (oder durch langes Tippen auf dem Telefon).',
    'twoFactor.error.badCodeEnroll': 'Code abgelehnt. Drei mögliche Ursachen: Der Code ist abgelaufen (lass dir einen neuen anzeigen und gib ihn sofort ein); die Uhrzeit des Geräts geht falsch (stell sie auf automatisch); der Schlüssel wurde von Hand falsch abgetippt (korrigiere ihn in der App, am besten durch Einfügen).',
    'twoFactor.guide.summary': 'Wo kommt der Schlüssel in deiner App hin?',
    'twoFactor.guide.legend': 'Ich nutze …',
    'twoFactor.guide.otherApp': 'eine andere App',
    'twoFactor.guide.pick': 'Wähle deine App, um die Schritte zu sehen.',
    'twoFactor.guide.aegis.1': 'Öffne Aegis und tippe unten auf dem Bildschirm auf die Schaltfläche „+“.',
    'twoFactor.guide.aegis.2': 'Wähle „QR-Code scannen“ und richte die Kamera auf den QR-Code oben. Auf dem Telefon selbst erledigt der Link „{lien}“ das ohne Scannen.',
    'twoFactor.guide.aegis.3': 'Ohne Kamera: Wähle „Manuell eingeben“, füge den Schlüssel in „Schlüssel“ ein, schreib AnarBib in „Herausgeber“ und tippe oben auf „Speichern“.',
    'twoFactor.guide.aegis.4': 'Der sechsstellige Code erscheint in der Liste von Aegis: Gib ihn unten ein.',
    'twoFactor.guide.freeotp.1': 'Öffne FreeOTP+, tippe auf „QR-Code scannen“ (das QR-Code-Symbol oben) und richte die Kamera auf den QR-Code weiter oben. Auf dem Telefon selbst erspart dir der Link „{lien}“ das Scannen.',
    'twoFactor.guide.freeotp.2': 'Ohne Kamera: Tippe auf „Token hinzufügen“, schreib AnarBib in „Aussteller“ und deine Adresse in „Konto“, füge den Schlüssel in „Geheimnis“ ein und tippe auf „Hinzufügen“.',
    'twoFactor.guide.freeotp.3': 'Tippe in der Liste auf das Token AnarBib: Der sechsstellige Code erscheint. Gib ihn unten ein.',
    'twoFactor.guide.keepassxc.1': 'Öffne oder erstelle in deiner KeePassXC-Datenbank den Eintrag für dein AnarBib-Konto.',
    'twoFactor.guide.keepassxc.2': 'Rechtsklick auf diesen Eintrag → „TOTP“ → „TOTP einrichten …“.',
    'twoFactor.guide.keepassxc.3': 'Füge den Schlüssel bei „Geheimer Schlüssel:“ ein, lass „Standardeinstellungen (RFC 6238)“ gewählt und bestätige.',
    'twoFactor.guide.keepassxc.4': 'Danach kopiert Strg+T bei markiertem Eintrag den Code („TOTP kopieren“); mit der Erweiterung KeePassXC-Browser wird er mit einem Klick ins Code-Feld eingetragen.',
    'twoFactor.guide.other.1': 'Such in deiner App nach „+“, „Hinzufügen“ oder „QR-Code scannen“ und richte die Kamera auf den QR-Code oben. Auf dem Telefon selbst erspart dir der Link „{lien}“ das Scannen.',
    'twoFactor.guide.other.2': 'Ohne Kamera wählst du die manuelle Eingabe und fügst den Schlüssel ein; lass die Standardeinstellungen (TOTP, sechs Ziffern, 30 Sekunden).',
    'twoFactor.guide.other.3': 'Gib unten den sechsstelligen Code ein, den die App anzeigt.',
  },
  nl: {
    'twoFactor.enroll.openLink': 'Openen in de authenticatie-app',
    'twoFactor.enroll.openLinkHint': 'Op de telefoon opent deze link je authenticatie-app meteen, zonder scannen.',
    'twoFactor.enroll.copied': 'Sleutel gekopieerd. Plak hem in je app.',
    'twoFactor.enroll.copyFailed': 'Het klembord is niet beschikbaar: de sleutel is geselecteerd, kopieer hem met Ctrl+C (of door lang te drukken op de telefoon).',
    'twoFactor.error.badCodeEnroll': 'Code geweigerd. Drie mogelijke oorzaken: de code is verlopen (laat een nieuwe zien en typ die meteen in); de tijd van het apparaat loopt verkeerd (zet die op automatisch); de sleutel is met de hand verkeerd overgenomen (verbeter hem in de app, liefst door hem te plakken).',
    'twoFactor.guide.summary': 'Waar komt de sleutel in je app?',
    'twoFactor.guide.legend': 'Ik gebruik…',
    'twoFactor.guide.otherApp': 'een andere app',
    'twoFactor.guide.pick': 'Kies je app om de stappen te zien.',
    'twoFactor.guide.aegis.1': 'Open Aegis en tik onderaan het scherm op de knop „+”.',
    'twoFactor.guide.aegis.2': 'Kies „Scan QR-code” en richt de camera op de QR-code hierboven. Op de telefoon zelf doet de link „{lien}” hetzelfde zonder scannen.',
    'twoFactor.guide.aegis.3': 'Zonder camera: kies „Handmatig invoeren”, plak de sleutel in „Sleutel”, typ AnarBib in „Uitgever” en tik bovenaan op „Opslaan”.',
    'twoFactor.guide.aegis.4': 'De code van zes cijfers verschijnt in de lijst van Aegis: typ hem hieronder in.',
    'twoFactor.guide.freeotp.1': 'FreeOTP+ bestaat niet in het Nederlands; de menu’s staan hier in het Engels. Open FreeOTP+, tik op „Scan QR Code” (het QR-codepictogram bovenaan) en richt de camera op de QR-code hierboven. Op de telefoon zelf bespaart de link „{lien}” je het scannen.',
    'twoFactor.guide.freeotp.2': 'Zonder camera: tik op „Add Token”, typ AnarBib bij „Issuer” en je adres bij „Account”, plak de sleutel bij „Secret” en tik op „Add”.',
    'twoFactor.guide.freeotp.3': 'Tik in de lijst op het token AnarBib: de code van zes cijfers verschijnt. Typ hem hieronder in.',
    'twoFactor.guide.keepassxc.1': 'Open of maak in je KeePassXC-database het item voor je AnarBib-account.',
    'twoFactor.guide.keepassxc.2': 'Rechtsklik op dit item → „TOTP” → „TOTP instellen…”.',
    'twoFactor.guide.keepassxc.3': 'Plak de sleutel bij „Geheime sleutel:”, laat „Standaard instellingen (RFC 6238)” staan en bevestig.',
    'twoFactor.guide.keepassxc.4': 'Daarna kopieert Ctrl+T bij een geselecteerd item de code („TOTP kopiëren”); met de extensie KeePassXC-Browser vul je hem met één klik in het codeveld in.',
    'twoFactor.guide.other.1': 'Zoek in je app naar „+”, „Toevoegen” of „QR-code scannen” en richt de camera op de QR-code hierboven. Op de telefoon zelf bespaart de link „{lien}” je het scannen.',
    'twoFactor.guide.other.2': 'Zonder camera kies je handmatige invoer en plak je de sleutel; laat de standaardinstellingen staan (TOTP, zes cijfers, 30 seconden).',
    'twoFactor.guide.other.3': 'Typ hieronder de code van zes cijfers die de app toont.',
  },
  el: {
    'twoFactor.enroll.openLink': 'Άνοιγμα στην εφαρμογή ελέγχου ταυτότητας',
    'twoFactor.enroll.openLinkHint': 'Στο τηλέφωνο, αυτός ο σύνδεσμος ανοίγει απευθείας την εφαρμογή ελέγχου ταυτότητας, χωρίς σάρωση.',
    'twoFactor.enroll.copied': 'Το κλειδί αντιγράφηκε. Επικόλλησέ το στην εφαρμογή σου.',
    'twoFactor.enroll.copyFailed': 'Το πρόχειρο δεν είναι διαθέσιμο: το κλειδί είναι επιλεγμένο, αντίγραψέ το με Ctrl+C (ή με παρατεταμένο πάτημα στο τηλέφωνο).',
    'twoFactor.error.badCodeEnroll': 'Ο κωδικός απορρίφθηκε. Τρεις πιθανές αιτίες: ο κωδικός έληξε (εμφάνισε νέο και πληκτρολόγησέ τον αμέσως)· η ώρα της συσκευής δεν είναι σωστή (ρύθμισέ την αυτόματα)· το κλειδί αντιγράφηκε λάθος με το χέρι (διόρθωσέ το στην εφαρμογή, καλύτερα με επικόλληση).',
    'twoFactor.guide.summary': 'Πού μπαίνει το κλειδί στην εφαρμογή σου;',
    'twoFactor.guide.legend': 'Χρησιμοποιώ…',
    'twoFactor.guide.otherApp': 'άλλη εφαρμογή',
    'twoFactor.guide.pick': 'Διάλεξε την εφαρμογή σου για να δεις τα βήματα.',
    'twoFactor.guide.aegis.1': 'Άνοιξε το Aegis και πάτησε το κουμπί «+» στο κάτω μέρος της οθόνης.',
    'twoFactor.guide.aegis.2': 'Διάλεξε «Σάρωση κωδικού QR» και στόχευσε τον κωδικό QR παραπάνω. Στο ίδιο το τηλέφωνο, ο σύνδεσμος «{lien}» κάνει το ίδιο χωρίς σάρωση.',
    'twoFactor.guide.aegis.3': 'Χωρίς κάμερα: διάλεξε «Χειροκίνητη εισαγωγή», επικόλλησε το κλειδί στο «Μυστικός κωδικός», γράψε AnarBib στο «Εκδότης» και πάτησε «Αποθήκευση» επάνω.',
    'twoFactor.guide.aegis.4': 'Ο εξαψήφιος κωδικός εμφανίζεται στη λίστα του Aegis: πληκτρολόγησέ τον παρακάτω.',
    'twoFactor.guide.freeotp.1': 'Το FreeOTP+ δεν υπάρχει στα ελληνικά· τα μενού του εμφανίζονται εδώ στα αγγλικά. Άνοιξε το FreeOTP+, πάτησε «Scan QR Code» (το εικονίδιο κωδικού QR επάνω) και στόχευσε τον κωδικό QR παραπάνω. Στο ίδιο το τηλέφωνο, ο σύνδεσμος «{lien}» σε γλιτώνει από τη σάρωση.',
    'twoFactor.guide.freeotp.2': 'Χωρίς κάμερα: πάτησε «Add Token», γράψε AnarBib στο «Issuer» και τη διεύθυνσή σου στο «Account», επικόλλησε το κλειδί στο «Secret» και πάτησε «Add».',
    'twoFactor.guide.freeotp.3': 'Πάτησε το AnarBib στη λίστα: εμφανίζεται ο εξαψήφιος κωδικός. Πληκτρολόγησέ τον παρακάτω.',
    'twoFactor.guide.keepassxc.1': 'Στη βάση δεδομένων σου στο KeePassXC, άνοιξε ή δημιούργησε την καταχώρηση του λογαριασμού σου στο AnarBib.',
    'twoFactor.guide.keepassxc.2': 'Δεξί κλικ σε αυτή την καταχώρηση → «TOTP» → «Ρύθμιση TOTP...».',
    'twoFactor.guide.keepassxc.3': 'Επικόλλησε το κλειδί στο «Μυστικό Κλειδί:», άφησε επιλεγμένο το «Προεπιλεγμένες ρυθμίσεις (RFC 6238)» και επιβεβαίωσε.',
    'twoFactor.guide.keepassxc.4': 'Μετά, με την καταχώρηση επιλεγμένη, το Ctrl+T αντιγράφει τον κωδικό («Αντιγραφή TOTP»)· με την επέκταση KeePassXC-Browser, συμπληρώνεται με ένα κλικ στο πεδίο του κωδικού.',
    'twoFactor.guide.other.1': 'Στην εφαρμογή σου, ψάξε «+», «Προσθήκη» ή «Σάρωση κωδικού QR» και στόχευσε τον κωδικό QR παραπάνω. Στο ίδιο το τηλέφωνο, ο σύνδεσμος «{lien}» σε γλιτώνει από τη σάρωση.',
    'twoFactor.guide.other.2': 'Χωρίς κάμερα, διάλεξε τη χειροκίνητη εισαγωγή και επικόλλησε το κλειδί· άφησε τις προεπιλεγμένες ρυθμίσεις (TOTP, έξι ψηφία, 30 δευτερόλεπτα).',
    'twoFactor.guide.other.3': 'Πληκτρολόγησε παρακάτω τον εξαψήφιο κωδικό που δείχνει η εφαρμογή.',
  },
  eo: {
    'twoFactor.enroll.openLink': 'Malfermi en la aŭtentiga aplikaĵo',
    'twoFactor.enroll.openLinkHint': 'En telefono, ĉi tiu ligilo rekte malfermas vian aŭtentigan aplikaĵon, sen skanado.',
    'twoFactor.enroll.copied': 'Ŝlosilo kopiita. Algluu ĝin en vian aplikaĵon.',
    'twoFactor.enroll.copyFailed': 'La tondujo ne disponeblas: la ŝlosilo estas elektita, kopiu ĝin per Ctrl+C (aŭ per longa premo en telefono).',
    'twoFactor.error.badCodeEnroll': 'Kodo rifuzita. Tri eblaj kaŭzoj: la kodo eksvalidiĝis (aperigu novan kaj tajpu ĝin tuj); la horo de la aparato estas malĝusta (agordu ĝin aŭtomate); la ŝlosilo estis mise kopiita permane (korektu ĝin en la aplikaĵo, prefere algluante ĝin).',
    'twoFactor.guide.summary': 'Kien meti la ŝlosilon en via aplikaĵo?',
    'twoFactor.guide.legend': 'Mi uzas…',
    'twoFactor.guide.otherApp': 'alian aplikaĵon',
    'twoFactor.guide.pick': 'Elektu vian aplikaĵon por vidi la paŝojn.',
    'twoFactor.guide.aegis.1': 'Aegis ne ekzistas en Esperanto; ĝiaj menuoj aperas ĉi tie angle. Malfermu Aegis kaj tuŝu la butonon „+“ malsupre de la ekrano.',
    'twoFactor.guide.aegis.2': 'Elektu „Scan QR code“ kaj celu la supran QR-kodon. En la telefono mem, la ligilo „{lien}“ faras la samon sen skanado.',
    'twoFactor.guide.aegis.3': 'Sen fotilo: elektu „Enter manually“, algluu la ŝlosilon en „Secret“, skribu AnarBib en „Issuer“ kaj tuŝu „Save“ supre.',
    'twoFactor.guide.aegis.4': 'La sescifera kodo aperas en la listo de Aegis: tajpu ĝin sube.',
    'twoFactor.guide.freeotp.1': 'FreeOTP+ ne ekzistas en Esperanto; ĝiaj menuoj aperas ĉi tie angle. Malfermu FreeOTP+, tuŝu „Scan QR Code“ (la QR-koda piktogramo supre) kaj celu la supran QR-kodon. En la telefono mem, la ligilo „{lien}“ ŝparas la skanadon.',
    'twoFactor.guide.freeotp.2': 'Sen fotilo: tuŝu „Add Token“, skribu AnarBib en „Issuer“ kaj vian adreson en „Account“, algluu la ŝlosilon en „Secret“ kaj tuŝu „Add“.',
    'twoFactor.guide.freeotp.3': 'Tuŝu AnarBib en la listo: la sescifera kodo aperas. Tajpu ĝin sube.',
    'twoFactor.guide.keepassxc.1': 'KeePassXC ne ekzistas en Esperanto; ĝiaj menuoj aperas ĉi tie angle. En via KeePassXC-datumbazo, malfermu aŭ kreu la eron de via AnarBib-konto.',
    'twoFactor.guide.keepassxc.2': 'Dekstra klako sur tiu ero → „TOTP“ → „Set up TOTP…“.',
    'twoFactor.guide.keepassxc.3': 'Algluu la ŝlosilon en „Secret Key:“, lasu „Default settings (RFC 6238)“ kaj konfirmu.',
    'twoFactor.guide.keepassxc.4': 'Poste, kun la ero elektita, Ctrl+T kopias la kodon („Copy TOTP“); per la etendaĵo KeePassXC-Browser, ĝi pleniĝas per unu klako en la koda kampo.',
    'twoFactor.guide.other.1': 'En via aplikaĵo, serĉu „+“, „Aldoni“ aŭ „Skani QR-kodon“ kaj celu la supran QR-kodon. En la telefono mem, la ligilo „{lien}“ ŝparas la skanadon.',
    'twoFactor.guide.other.2': 'Sen fotilo, elektu permanan enigon kaj algluu la ŝlosilon; lasu la defaŭltajn agordojn (TOTP, ses ciferoj, 30 sekundoj).',
    'twoFactor.guide.other.3': 'Tajpu sube la sesciferan kodon, kiun la aplikaĵo montras.',
  },
  en: {
    'twoFactor.enroll.openLink': 'Open in the authenticator app',
    'twoFactor.enroll.openLinkHint': 'On a phone, this link opens your authenticator app directly, no scanning needed.',
    'twoFactor.enroll.copied': 'Key copied. Paste it into your app.',
    'twoFactor.enroll.copyFailed': 'The clipboard isn’t available: the key is selected, copy it with Ctrl+C (or a long press on a phone).',
    'twoFactor.error.badCodeEnroll': 'Code rejected. Three possible causes: the code expired (bring up a new one and enter it right away); the device clock is off (set it to automatic); the key was mistyped by hand (fix it in the app, preferably by pasting it).',
    'twoFactor.guide.summary': 'Where does the key go in your app?',
    'twoFactor.guide.legend': 'I use…',
    'twoFactor.guide.otherApp': 'another app',
    'twoFactor.guide.pick': 'Choose your app to see the steps.',
    'twoFactor.guide.aegis.1': 'Open Aegis and tap the “+” button at the bottom of the screen.',
    'twoFactor.guide.aegis.2': 'Choose “Scan QR code” and point the camera at the QR code above. On the phone itself, the “{lien}” link does the same without scanning.',
    'twoFactor.guide.aegis.3': 'No camera: choose “Enter manually”, paste the key into “Secret”, type AnarBib in “Issuer”, then tap “Save” at the top.',
    'twoFactor.guide.aegis.4': 'The six-digit code shows up in the Aegis list: enter it below.',
    'twoFactor.guide.freeotp.1': 'Open FreeOTP+, tap “Scan QR Code” (the QR code icon at the top) and point the camera at the QR code above. On the phone itself, the “{lien}” link saves you the scan.',
    'twoFactor.guide.freeotp.2': 'No camera: tap “Add Token”, type AnarBib in “Issuer” and your address in “Account”, paste the key into “Secret”, then tap “Add”.',
    'twoFactor.guide.freeotp.3': 'Tap the AnarBib token in the list: the six-digit code appears. Enter it below.',
    'twoFactor.guide.keepassxc.1': 'In your KeePassXC database, open or create the entry for your AnarBib account.',
    'twoFactor.guide.keepassxc.2': 'Right-click that entry → “TOTP” → “Set up TOTP…”.',
    'twoFactor.guide.keepassxc.3': 'Paste the key into “Secret Key:”, keep “Default settings (RFC 6238)” and confirm.',
    'twoFactor.guide.keepassxc.4': 'From then on, with the entry selected, Ctrl+T copies the code (“Copy TOTP”); with the KeePassXC-Browser extension, it fills the code field in one click.',
    'twoFactor.guide.other.1': 'In your app, look for “+”, “Add” or “Scan QR code” and point the camera at the QR code above. On the phone itself, the “{lien}” link saves you the scan.',
    'twoFactor.guide.other.2': 'No camera: choose manual entry and paste the key; keep the default settings (TOTP, six digits, 30 seconds).',
    'twoFactor.guide.other.3': 'Enter below the six-digit code the app shows.',
  },
};

const CLES = Object.keys(VAL.fr);
const echapper = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
for (const loc of LOCALES) {
  const v = VAL[loc];
  if (!v) throw new Error('locale manquante ' + loc);
  const manque = CLES.filter((k) => !v[k]);
  const enTrop = Object.keys(v).filter((k) => !CLES.includes(k));
  if (manque.length || enTrop.length) throw new Error(`${loc} : manque ${manque} ; en trop ${enTrop}`);
  for (const k of CLES) {
    if (k.startsWith('twoFactor.guide.') && /\{lien\}/.test(VAL.fr[k]) !== /\{lien\}/.test(v[k])) throw new Error(`${loc} ${k} : {lien}`);
  }
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  const bilan = { ajoutée: 0, corrigée: 0, inchangée: 0 };
  for (const cle of CLES) {
    const ligne = new RegExp('^  ' + echapper(JSON.stringify(cle)) + ': (".*?")(,?)$', 'm');
    const m = content.match(ligne);
    if (m) {
      if (JSON.parse(m[1]) !== v[cle]) { content = content.replace(m[0], '  ' + JSON.stringify(cle) + ': ' + JSON.stringify(v[cle]) + m[2]); bilan.corrigée++; } else bilan.inchangée++;
    } else {
      const marker = content.lastIndexOf('}');
      content = content.slice(0, marker).replace(/\s*$/, '') + ',\n  ' + JSON.stringify(cle) + ': ' + JSON.stringify(v[cle]) + '\n' + content.slice(marker);
      bilan.ajoutée++;
    }
  }
  JSON.parse(content);
  fs.writeFileSync(file, content);
  console.log(loc.padEnd(6), JSON.stringify(bilan));
}
