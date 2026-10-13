/* ===========================================================================
 * manuel-b42-double-authentification.cjs — B42 (13/10/2026) : la double
 * authentification dans le manuel, dix langues (docs/manual.md = fr, et les
 * neuf docs/manual-<code>.md).
 *
 * Deux sous-sections par manuel :
 *   A. fin de la partie 2 (Mon compte) : protéger son compte — activer,
 *      le code à la connexion, deuxième appareil, appareil perdu, retrait,
 *      échéance du 1er janvier 2027 pour les équipes ;
 *   B. fin de « Gestion du réseau » (partie 5) : l'onglet de l'administration
 *      du réseau et le retrait d'appareils après vérification d'identité.
 * Chaque langue suit le REGISTRE DE SON MANUEL (vous en fr, vós en ca, u en
 * nl, pluriel de politesse en el ; du en de ; tu en es et it ; você en pt-BR) :
 * les manuels n'ont pas été alignés sur le tutoiement de l'interface, et une
 * section ne doit pas changer de registre au milieu d'un document. Les noms
 * de boutons sont ceux des locales (twoFactor.*, nav.account,
 * account.tab.profile, rede.tab.twoFactor, nav.network).
 * Le roumain (lot 4 de l'ajout de ro) reprendra cette section dans son manuel.
 *
 * Idempotent : un manuel qui porte déjà le titre A n'est pas retouché.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const DOCS = path.join(__dirname, '..', 'docs');

const T = {
  fr: {
    fichier: 'manual.md',
    A: `### Protéger votre compte : la double authentification
Après le mot de passe, AnarBib peut demander un code à six chiffres qui change toutes les 30 secondes. Ce code vient d'une application d'authentification libre, qui fonctionne hors ligne : Aegis ou FreeOTP+ sur Android, FreeOTP ou 2FAS sur iPhone, KeePassXC sur ordinateur. Ni SMS ni service extérieur.

**Obligatoire pour les équipes à partir du 1er janvier 2027** (administration du réseau, coordinations, bibliothécaires) ; facultative pour les comptes de lecture.

Pour l'activer :
1. Ouvrez **Mon compte → Données personnelles**. Sous le changement de mot de passe, cliquez sur **Activer la double authentification**.
2. Donnez un nom à l'appareil (par exemple « Téléphone »), puis scannez le code QR avec l'application. Sans caméra, saisissez à la main la clé affichée.
3. Saisissez le **code à six chiffres** affiché par l'application et cliquez sur **Confirmer**.

Ensuite, à chaque connexion, AnarBib vous demande le code après le mot de passe. Si plusieurs appareils sont inscrits, choisissez celui que vous avez sous la main.

- **Inscrivez un deuxième appareil** (KeePassXC en plus du téléphone, par exemple) : c'est la seule façon de ne pas rester bloqué·e si vous en perdez un.
- **Appareil perdu ?** Contactez l'administration du réseau (Matrix ou anarbib@proton.me). Après avoir vérifié votre identité par un autre moyen, elle retire vos appareils ; vous en inscrivez un nouveau à la connexion suivante.
- Pour retirer un appareil, cliquez sur **Retirer** à côté de son nom.
- Un compte d'équipe sans appareil après le 1er janvier 2027 devra en inscrire un à la connexion avant de continuer.
- Personne chez AnarBib ne vous demandera jamais votre code ni votre code QR.`,
    B: `### Double authentification des équipes
L'onglet **Double authentification** de la page **Réseau**, réservé à l'administration du réseau, liste les comptes d'équipe actifs et ceux qui ont choisi la double authentification, avec leurs rôles et leur nombre d'appareils ; ceux qui n'en ont pas apparaissent en premier. Il indique aussi l'exigence en vigueur.

Pour dépanner une personne qui a perdu son appareil : vérifiez d'abord son identité par un autre moyen (de vive voix, Matrix), puis cliquez sur **Retirer ses appareils**, indiquez le motif (comment l'identité a été vérifiée) et cliquez sur **Retirer et déconnecter**. Le compte est déconnecté partout et le retrait est journalisé. Ce geste exige que votre propre session soit passée par le code.`,
  },
  'pt-BR': {
    fichier: 'manual-pt-BR.md',
    A: `### Proteger sua conta: a autenticação em dois fatores
Depois da senha, o AnarBib pode pedir um código de seis dígitos que muda a cada 30 segundos. Esse código vem de um aplicativo de autenticação livre, que funciona offline: Aegis ou FreeOTP+ no Android, FreeOTP ou 2FAS no iPhone, KeePassXC no computador. Sem SMS e sem serviço externo.

**Obrigatória para as equipes a partir de 1º de janeiro de 2027** (administração da rede, coordenações, equipes de biblioteca); opcional para as contas de leitura.

Para ativar:
1. Abra **Minha conta → Dados pessoais**. Abaixo da troca de senha, clique em **Ativar a autenticação em dois fatores**.
2. Dê um nome ao dispositivo (por exemplo « Celular ») e escaneie o código QR com o aplicativo. Sem câmera, digite manualmente a chave mostrada.
3. Digite o **código de seis dígitos** mostrado pelo aplicativo e clique em **Confirmar**.

Depois disso, a cada acesso o AnarBib pede o código depois da senha. Se você cadastrou vários dispositivos, escolha o que estiver à mão.

- **Cadastre um segundo dispositivo** (o KeePassXC além do celular, por exemplo): é a única forma de não ficar sem acesso se você perder um deles.
- **Perdeu o dispositivo?** Entre em contato com a administração da rede (Matrix ou anarbib@proton.me). Depois de verificar a sua identidade por outro meio, ela remove os seus dispositivos; você cadastra um novo no próximo acesso.
- Para remover um dispositivo, clique em **Remover** ao lado do nome dele.
- Uma conta de equipe sem dispositivo depois de 1º de janeiro de 2027 precisará cadastrar um ao entrar, antes de continuar.
- Ninguém do AnarBib vai pedir o seu código nem o seu código QR, nunca.`,
    B: `### Autenticação em dois fatores das equipes
A aba **Autenticação em dois fatores** da página **Rede**, reservada à administração da rede, lista as contas de equipe ativas e as que escolheram a autenticação em dois fatores, com os papéis e o número de dispositivos; as que não têm dispositivo aparecem primeiro. Ela também mostra a exigência em vigor.

Para ajudar uma pessoa que perdeu o dispositivo: verifique primeiro a identidade dela por outro meio (pessoalmente, Matrix), clique em **Remover os dispositivos**, informe o motivo (como a identidade foi verificada) e clique em **Remover e desconectar**. A conta é desconectada em todos os lugares e a remoção fica registrada. Essa ação exige que a sua própria sessão tenha passado pelo código.`,
  },
  en: {
    fichier: 'manual-en.md',
    A: `### Protecting your account: two-factor authentication
After your password, AnarBib can ask for a six-digit code that changes every 30 seconds. The code comes from a free-software authenticator app that works offline: Aegis or FreeOTP+ on Android, FreeOTP or 2FAS on iPhone, KeePassXC on a computer. No SMS, no outside service.

**Required for teams from 1 January 2027** (network administration, coordinators, library teams); optional for reader accounts.

To turn it on:
1. Open **My account → Personal data**. Below the password change, click **Turn on two-factor authentication**.
2. Give the device a name (for example "Phone"), then scan the QR code with the app. No camera? Type in the key shown by hand.
3. Enter the **six-digit code** shown by the app and click **Confirm**.

From then on, AnarBib asks for the code after your password each time you sign in. If several devices are enrolled, pick the one at hand.

- **Enroll a second device** (KeePassXC as well as your phone, for example): it is the only way not to be locked out if you lose one.
- **Lost your device?** Contact the network administration (Matrix or anarbib@proton.me). Once they have checked your identity another way, they remove your devices; you enroll a new one at your next sign-in.
- To remove a device, click **Remove** next to its name.
- A team account with no device after 1 January 2027 will have to enroll one at sign-in before going any further.
- No one at AnarBib will ever ask you for your code or your QR code.`,
    B: `### Two-factor authentication for teams
The **Two-factor authentication** tab of the **Network** page, for the network administration only, lists active team accounts and accounts that chose two-factor authentication, with their roles and number of devices; those without a device come first. It also shows the requirement in force.

To help someone who lost their device: first check the person's identity another way (in person, Matrix), then click **Remove their devices**, give the reason (how the identity was checked) and click **Remove and sign out**. The account is signed out everywhere and the removal is logged. This action requires your own session to have passed the code.`,
  },
  es: {
    fichier: 'manual-es.md',
    A: `### Proteger tu cuenta: la autenticación en dos pasos
Después de la contraseña, AnarBib puede pedir un código de seis cifras que cambia cada 30 segundos. Ese código viene de una aplicación de autenticación libre, que funciona sin conexión: Aegis o FreeOTP+ en Android, FreeOTP o 2FAS en iPhone, KeePassXC en el ordenador. Ni SMS ni servicio externo.

**Obligatoria para los equipos a partir del 1 de enero de 2027** (administración de la red, coordinaciones, equipos de biblioteca); opcional para las cuentas de lectura.

Para activarla:
1. Abre **Mi cuenta → Datos personales**. Debajo del cambio de contraseña, haz clic en **Activar la autenticación en dos pasos**.
2. Da un nombre al dispositivo (por ejemplo «Móvil») y escanea el código QR con la aplicación. Sin cámara, escribe a mano la clave que aparece.
3. Escribe el **código de seis cifras** que muestra la aplicación y haz clic en **Confirmar**.

A partir de ahí, AnarBib te pide el código después de la contraseña en cada inicio de sesión. Si registraste varios dispositivos, elige el que tengas a mano.

- **Registra un segundo dispositivo** (KeePassXC además del móvil, por ejemplo): es la única forma de no quedarte sin acceso si pierdes uno.
- **¿Perdiste el dispositivo?** Contacta con la administración de la red (Matrix o anarbib@proton.me). Tras verificar tu identidad por otro medio, quita tus dispositivos; registras uno nuevo en el siguiente inicio de sesión.
- Para quitar un dispositivo, haz clic en **Quitar** junto a su nombre.
- Una cuenta de equipo sin dispositivo después del 1 de enero de 2027 tendrá que registrar uno al iniciar sesión antes de seguir.
- Nadie de AnarBib te pedirá nunca tu código ni tu código QR.`,
    B: `### Autenticación en dos pasos de los equipos
La pestaña **Autenticación en dos pasos** de la página **Red**, reservada a la administración de la red, lista las cuentas de equipo activas y las que eligieron la autenticación en dos pasos, con sus papeles y su número de dispositivos; las que no tienen dispositivo aparecen primero. También muestra la exigencia vigente.

Para ayudar a una persona que perdió su dispositivo: verifica primero su identidad por otro medio (en persona, Matrix), luego haz clic en **Quitar sus dispositivos**, indica el motivo (cómo se verificó la identidad) y haz clic en **Quitar y cerrar sesión**. La sesión de la cuenta se cierra en todas partes y la operación queda registrada. Este gesto exige que tu propia sesión haya pasado por el código.`,
  },
  ca: {
    fichier: 'manual-ca.md',
    A: `### Protegir el vostre compte: l'autenticació en dos passos
Després de la contrasenya, AnarBib pot demanar un codi de sis xifres que canvia cada 30 segons. Aquest codi ve d'una aplicació d'autenticació lliure, que funciona sense connexió: Aegis o FreeOTP+ a Android, FreeOTP o 2FAS a iPhone, KeePassXC a l'ordinador. Ni SMS ni cap servei extern.

**Obligatòria per als equips a partir de l'1 de gener de 2027** (administració de la xarxa, coordinacions, equips de biblioteca); opcional per als comptes de lectura.

Per activar-la:
1. Obriu **El meu compte → Dades personals**. Sota el canvi de contrasenya, feu clic a **Activa l'autenticació en dos passos**.
2. Doneu un nom a l'aparell (per exemple «Mòbil») i escanegeu el codi QR amb l'aplicació. Sense càmera, escriviu a mà la clau que es mostra.
3. Escriviu el **codi de sis xifres** que mostra l'aplicació i feu clic a **Confirma**.

A partir d'aleshores, AnarBib us demana el codi després de la contrasenya a cada connexió. Si hi ha diversos aparells registrats, trieu el que tingueu a mà.

- **Registreu un segon aparell** (KeePassXC a més del mòbil, per exemple): és l'única manera de no quedar sense accés si en perdeu un.
- **Heu perdut l'aparell?** Contacteu amb l'administració de la xarxa (Matrix o anarbib@proton.me). Després de verificar la vostra identitat per un altre mitjà, treu els vostres aparells; en registreu un de nou a la connexió següent.
- Per treure un aparell, feu clic a **Treure** al costat del seu nom.
- Un compte d'equip sense aparell després de l'1 de gener de 2027 haurà de registrar-ne un en connectar-se, abans de continuar.
- Ningú d'AnarBib no us demanarà mai el codi ni el codi QR.`,
    B: `### Autenticació en dos passos dels equips
La pestanya **Autenticació en dos passos** de la pàgina **Xarxa**, reservada a l'administració de la xarxa, llista els comptes d'equip actius i els que han triat l'autenticació en dos passos, amb els seus papers i el nombre d'aparells; els que no en tenen surten primer. També mostra l'exigència vigent.

Per ajudar una persona que ha perdut l'aparell: verifiqueu primer la seva identitat per un altre mitjà (en persona, Matrix), feu clic a **Treure els aparells**, indiqueu la raó (com s'ha verificat la identitat) i feu clic a **Treure i tancar la sessió**. La sessió del compte es tanca a tot arreu i l'operació queda registrada. Aquest gest exigeix que la vostra pròpia sessió hagi passat pel codi.`,
  },
  it: {
    fichier: 'manual-it.md',
    A: `### Proteggere il tuo account: l'autenticazione a due fattori
Dopo la password, AnarBib può chiedere un codice di sei cifre che cambia ogni 30 secondi. Il codice viene da un'app di autenticazione libera, che funziona offline: Aegis o FreeOTP+ su Android, FreeOTP o 2FAS su iPhone, KeePassXC sul computer. Niente SMS né servizi esterni.

**Obbligatoria per i gruppi di lavoro dal 1° gennaio 2027** (amministrazione della rete, coordinamenti, gruppi delle biblioteche); facoltativa per gli account di lettura.

Per attivarla:
1. Apri **Il mio account → Dati personali**. Sotto il cambio della password, clicca su **Attiva l'autenticazione a due fattori**.
2. Dai un nome al dispositivo (per esempio «Telefono») e scansiona il codice QR con l'app. Senza fotocamera, inserisci a mano la chiave mostrata.
3. Inserisci il **codice di sei cifre** mostrato dall'app e clicca su **Conferma**.

Da quel momento, a ogni accesso AnarBib ti chiede il codice dopo la password. Se hai registrato più dispositivi, scegli quello che hai a portata di mano.

- **Registra un secondo dispositivo** (KeePassXC oltre al telefono, per esempio): è l'unico modo per non restare senza accesso se ne perdi uno.
- **Hai perso il dispositivo?** Contatta l'amministrazione della rete (Matrix o anarbib@proton.me). Dopo aver verificato la tua identità con un altro mezzo, rimuove i tuoi dispositivi; ne registri uno nuovo all'accesso successivo.
- Per rimuovere un dispositivo, clicca su **Rimuovi** accanto al suo nome.
- Un account di un gruppo di lavoro senza dispositivo dopo il 1° gennaio 2027 dovrà registrarne uno all'accesso, prima di continuare.
- Nessuno di AnarBib ti chiederà mai il tuo codice né il tuo codice QR.`,
    B: `### Autenticazione a due fattori dei gruppi di lavoro
La scheda **Autenticazione a due fattori** della pagina **Rete**, riservata all'amministrazione della rete, elenca gli account attivi dei gruppi di lavoro e quelli che hanno scelto l'autenticazione a due fattori, con i loro ruoli e il numero di dispositivi; quelli senza dispositivo compaiono per primi. Mostra anche il requisito in vigore.

Per aiutare una persona che ha perso il dispositivo: verifica prima la sua identità con un altro mezzo (di persona, Matrix), poi clicca su **Rimuovi i dispositivi**, indica il motivo (come è stata verificata l'identità) e clicca su **Rimuovi e disconnetti**. L'account viene disconnesso ovunque e la rimozione viene registrata. Questa operazione richiede che la tua sessione sia passata per il codice.`,
  },
  de: {
    fichier: 'manual-de.md',
    A: `### Dein Konto schützen: die Zwei-Faktor-Authentifizierung
Nach dem Passwort kann AnarBib einen sechsstelligen Code abfragen, der sich alle 30 Sekunden ändert. Der Code kommt aus einer freien Authentifizierungs-App, die offline funktioniert: Aegis oder FreeOTP+ unter Android, FreeOTP oder 2FAS auf dem iPhone, KeePassXC auf dem Computer. Keine SMS, kein externer Dienst.

**Ab dem 1. Januar 2027 Pflicht für die Teams** (Netzwerkverwaltung, Koordinationen, Bibliotheksteams); für Lesekonten freiwillig.

So aktivierst du sie:
1. Öffne **Mein Konto → Persönliche Daten**. Klicke unter der Passwortänderung auf **Zwei-Faktor-Authentifizierung aktivieren**.
2. Gib dem Gerät einen Namen (zum Beispiel „Telefon“) und scanne den QR-Code mit der App. Ohne Kamera gibst du den angezeigten Schlüssel von Hand ein.
3. Gib den **sechsstelligen Code** aus der App ein und klicke auf **Bestätigen**.

Danach fragt AnarBib bei jeder Anmeldung nach dem Passwort den Code ab. Hast du mehrere Geräte eingerichtet, wähle das, das du gerade zur Hand hast.

- **Richte ein zweites Gerät ein** (zum Beispiel KeePassXC zusätzlich zum Telefon): Nur so sperrst du dich nicht aus, wenn du eines verlierst.
- **Gerät verloren?** Wende dich an die Netzwerkverwaltung (Matrix oder anarbib@proton.me). Nachdem sie deine Identität auf anderem Weg geprüft hat, entfernt sie deine Geräte; bei der nächsten Anmeldung richtest du ein neues ein.
- Um ein Gerät zu entfernen, klicke neben seinem Namen auf **Entfernen**.
- Ein Teamkonto ohne Gerät muss nach dem 1. Januar 2027 bei der Anmeldung zuerst eines einrichten.
- Niemand von AnarBib wird dich je nach deinem Code oder deinem QR-Code fragen.`,
    B: `### Zwei-Faktor-Authentifizierung der Teams
Der Reiter **Zwei-Faktor-Authentifizierung** auf der Seite **Netzwerk**, nur für die Netzwerkverwaltung, listet die aktiven Teamkonten und die Konten, die die Zwei-Faktor-Authentifizierung gewählt haben, mit ihren Rollen und der Zahl ihrer Geräte; Konten ohne Gerät stehen oben. Er zeigt auch die geltende Anforderung.

Um einer Person zu helfen, die ihr Gerät verloren hat: Prüfe zuerst ihre Identität auf anderem Weg (persönlich, Matrix), klicke dann auf **Geräte entfernen**, gib den Grund an (wie die Identität geprüft wurde) und klicke auf **Entfernen und abmelden**. Das Konto wird überall abgemeldet, und das Entfernen wird protokolliert. Dafür muss deine eigene Sitzung den Code durchlaufen haben.`,
  },
  nl: {
    fichier: 'manual-nl.md',
    A: `### Uw account beschermen: tweestapsverificatie
Na uw wachtwoord kan AnarBib om een code van zes cijfers vragen die elke 30 seconden verandert. Die code komt uit een vrije authenticatie-app die offline werkt: Aegis of FreeOTP+ op Android, FreeOTP of 2FAS op iPhone, KeePassXC op de computer. Geen sms en geen externe dienst.

**Verplicht voor teams vanaf 1 januari 2027** (netwerkbeheer, coördinaties, bibliotheekteams); vrijwillig voor leesaccounts.

Zo schakelt u ze in:
1. Open **Mijn account → Persoonsgegevens**. Klik onder het wijzigen van het wachtwoord op **Tweestapsverificatie inschakelen**.
2. Geef het apparaat een naam (bijvoorbeeld „Telefoon”) en scan de QR-code met de app. Geen camera? Typ de getoonde sleutel met de hand in.
3. Typ de **code van zes cijfers** uit de app en klik op **Bevestigen**.

Daarna vraagt AnarBib bij elke aanmelding na het wachtwoord om de code. Hebt u meerdere apparaten ingesteld, kies dan het apparaat dat u bij de hand hebt.

- **Stel een tweede apparaat in** (bijvoorbeeld KeePassXC naast uw telefoon): alleen zo raakt u de toegang niet kwijt als u er een verliest.
- **Apparaat kwijt?** Neem contact op met het netwerkbeheer (Matrix of anarbib@proton.me). Nadat het uw identiteit op een andere manier heeft gecontroleerd, verwijdert het uw apparaten; bij de volgende aanmelding stelt u een nieuw in.
- Om een apparaat te verwijderen, klikt u naast de naam op **Verwijderen**.
- Een teamaccount zonder apparaat moet na 1 januari 2027 bij het aanmelden eerst een apparaat instellen.
- Niemand van AnarBib zal u ooit om uw code of uw QR-code vragen.`,
    B: `### Tweestapsverificatie van de teams
Het tabblad **Tweestapsverificatie** van de pagina **Netwerk**, alleen voor het netwerkbeheer, toont de actieve teamaccounts en de accounts die voor tweestapsverificatie hebben gekozen, met hun rollen en het aantal apparaten; accounts zonder apparaat staan bovenaan. Het toont ook de geldende eis.

Om iemand te helpen die een apparaat kwijt is: controleer eerst de identiteit van de persoon op een andere manier (persoonlijk, Matrix), klik dan op **Apparaten verwijderen**, geef de reden op (hoe de identiteit is gecontroleerd) en klik op **Verwijderen en afmelden**. Het account wordt overal afgemeld en de verwijdering wordt vastgelegd. Hiervoor moet uw eigen sessie de code hebben doorlopen.`,
  },
  eo: {
    fichier: 'manual-eo.md',
    A: `### Protekti vian konton: dufaktora aŭtentigo
Post la pasvorto, AnarBib povas peti sesciferan kodon, kiu ŝanĝiĝas ĉiujn 30 sekundojn. La kodo venas el libera aŭtentiga aplikaĵo, kiu funkcias senkonekte: Aegis aŭ FreeOTP+ ĉe Android, FreeOTP aŭ 2FAS ĉe iPhone, KeePassXC ĉe komputilo. Neniu SMS, neniu ekstera servo.

**Deviga por la teamoj ekde la 1-a de januaro 2027** (administrado de la reto, kunordigoj, bibliotekaj teamoj); libervola por legantaj kontoj.

Por ŝalti ĝin:
1. Malfermu **Mia konto → Personaj datumoj**. Sub la ŝanĝo de pasvorto, alklaku **Ŝalti dufaktoran aŭtentigon**.
2. Donu nomon al la aparato (ekzemple «Telefono») kaj skanu la QR-kodon per la aplikaĵo. Sen fotilo, tajpu permane la montritan ŝlosilon.
3. Tajpu la **sesciferan kodon** montratan de la aplikaĵo kaj alklaku **Konfirmi**.

Poste, ĉe ĉiu ensaluto, AnarBib petas la kodon post la pasvorto. Se vi registris plurajn aparatojn, elektu tiun, kiun vi havas ĉe mano.

- **Registru duan aparaton** (ekzemple KeePassXC krom la telefono): nur tiel vi ne restos sen aliro, se vi perdos unu.
- **Ĉu vi perdis la aparaton?** Kontaktu la administradon de la reto (Matrix aŭ anarbib@proton.me). Kontrolinte vian identecon alimaniere, ĝi forigas viajn aparatojn; vi registras novan ĉe la sekva ensaluto.
- Por forigi aparaton, alklaku **Forigi** apud ĝia nomo.
- Teama konto sen aparato post la 1-a de januaro 2027 devos registri unu ĉe ensaluto antaŭ ol daŭrigi.
- Neniu de AnarBib iam petos de vi vian kodon aŭ vian QR-kodon.`,
    B: `### Dufaktora aŭtentigo de la teamoj
La langeto **Dufaktora aŭtentigo** de la paĝo **Reto**, nur por la administrado de la reto, listigas la aktivajn teamajn kontojn kaj la kontojn, kiuj elektis dufaktoran aŭtentigon, kun iliaj roloj kaj nombro de aparatoj; tiuj sen aparato aperas unue. Ĝi montras ankaŭ la validan postulon.

Por helpi personon, kiu perdis sian aparaton: unue kontrolu la identecon de la persono alimaniere (persone, Matrix), poste alklaku **Forigi la aparatojn**, indiku la kialon (kiel la identeco estis kontrolita) kaj alklaku **Forigi kaj elsalutigi**. La konto estas elsalutita ĉie kaj la forigo estas registrita. Tiu ago postulas, ke via propra seanco jam pasis tra la kodo.`,
  },
  el: {
    fichier: 'manual-el.md',
    A: `### Προστατέψτε τον λογαριασμό σας: έλεγχος ταυτότητας δύο παραγόντων
Μετά τον κωδικό πρόσβασης, το AnarBib μπορεί να ζητήσει έναν εξαψήφιο κωδικό που αλλάζει κάθε 30 δευτερόλεπτα. Ο κωδικός προέρχεται από μια ελεύθερη εφαρμογή ελέγχου ταυτότητας που λειτουργεί εκτός σύνδεσης: Aegis ή FreeOTP+ σε Android, FreeOTP ή 2FAS σε iPhone, KeePassXC σε υπολογιστή. Χωρίς SMS και χωρίς εξωτερική υπηρεσία.

**Υποχρεωτικός για τις ομάδες από την 1η Ιανουαρίου 2027** (διαχείριση δικτύου, συντονισμοί, ομάδες βιβλιοθηκών)· προαιρετικός για τους λογαριασμούς ανάγνωσης.

Για να τον ενεργοποιήσετε:
1. Ανοίξτε **Ο λογαριασμός μου → Προσωπικά δεδομένα**. Κάτω από την αλλαγή κωδικού πρόσβασης, κάντε κλικ στο **Ενεργοποίηση ελέγχου δύο παραγόντων**.
2. Δώστε ένα όνομα στη συσκευή (για παράδειγμα «Τηλέφωνο») και σαρώστε τον κωδικό QR με την εφαρμογή. Χωρίς κάμερα, πληκτρολογήστε με το χέρι το κλειδί που εμφανίζεται.
3. Πληκτρολογήστε τον **εξαψήφιο κωδικό** που δείχνει η εφαρμογή και κάντε κλικ στο **Επιβεβαίωση**.

Από εκεί και πέρα, σε κάθε σύνδεση το AnarBib ζητά τον κωδικό μετά τον κωδικό πρόσβασης. Αν έχετε καταχωρίσει πολλές συσκευές, επιλέξτε αυτήν που έχετε πρόχειρη.

- **Καταχωρίστε και δεύτερη συσκευή** (για παράδειγμα το KeePassXC εκτός από το τηλέφωνο): είναι ο μόνος τρόπος να μη μείνετε χωρίς πρόσβαση αν χάσετε τη μία.
- **Χάσατε τη συσκευή;** Επικοινωνήστε με τη διαχείριση του δικτύου (Matrix ή anarbib@proton.me). Αφού επαληθεύσει την ταυτότητά σας με άλλο τρόπο, αφαιρεί τις συσκευές σας· καταχωρίζετε μια νέα στην επόμενη σύνδεση.
- Για να αφαιρέσετε μια συσκευή, κάντε κλικ στο **Αφαίρεση** δίπλα στο όνομά της.
- Ένας λογαριασμός ομάδας χωρίς συσκευή μετά την 1η Ιανουαρίου 2027 θα πρέπει, κατά τη σύνδεση, να καταχωρίσει μία πριν συνεχίσει.
- Κανείς από το AnarBib δεν θα σας ζητήσει ποτέ τον κωδικό σας ή τον κωδικό QR σας.`,
    B: `### Έλεγχος δύο παραγόντων των ομάδων
Η καρτέλα **Έλεγχος δύο παραγόντων** της σελίδας **Δίκτυο**, μόνο για τη διαχείριση δικτύου, παραθέτει τους ενεργούς λογαριασμούς ομάδας και όσους επέλεξαν τον έλεγχο δύο παραγόντων, με τους ρόλους και τον αριθμό των συσκευών τους· όσοι δεν έχουν συσκευή εμφανίζονται πρώτοι. Δείχνει επίσης την ισχύουσα απαίτηση.

Για να βοηθήσετε ένα άτομο που έχασε τη συσκευή του: επαληθεύστε πρώτα την ταυτότητά του με άλλο τρόπο (από κοντά, Matrix), κάντε κλικ στο **Αφαίρεση συσκευών**, συμπληρώστε την αιτιολογία (πώς επαληθεύτηκε η ταυτότητα) και κάντε κλικ στο **Αφαίρεση και αποσύνδεση**. Ο λογαριασμός αποσυνδέεται παντού και η αφαίρεση καταγράφεται. Η ενέργεια αυτή απαιτεί η δική σας σύνδεση να έχει περάσει από τον κωδικό.`,
  },
};

// Insère `bloc` juste avant la ligne « --- » qui précède le titre `## <n>.`
function avantSeparateur(texte, n, bloc, fichier) {
  const titre = texte.search(new RegExp(`^## ${n}\\. `, 'm'));
  if (titre < 0) throw new Error(`${fichier} : titre « ## ${n}. » introuvable`);
  const sep = texte.lastIndexOf('\n---\n', titre);
  if (sep < 0 || texte.slice(sep + 5, titre).trim() !== '') throw new Error(`${fichier} : séparateur avant « ## ${n}. » introuvable`);
  return texte.slice(0, sep).replace(/\s*$/, '') + '\n\n' + bloc + '\n' + texte.slice(sep);
}

for (const [loc, { fichier, A, B }] of Object.entries(T)) {
  const f = path.join(DOCS, fichier);
  let s = fs.readFileSync(f, 'utf8');
  const titreA = A.split('\n')[0];
  if (s.includes(titreA)) { console.log(`${loc} : déjà posé`); continue; }
  s = avantSeparateur(s, 3, A, fichier);
  s = avantSeparateur(s, 6, B, fichier);
  fs.writeFileSync(f, s, 'utf8');
  console.log(`${loc} : ${fichier} — deux sous-sections posées`);
}
