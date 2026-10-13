/* ===========================================================================
 * i18n-add-b42-lot2.cjs — B42 lot 2 (13/10/2026) : la double authentification
 * s'exige côté serveur. Écran d'inscription obligatoire à la connexion (vue
 * 'mfa-inscription' de LoginPage) et onglet « Double authentification » de
 * la page Réseau (DoubleFacteurPanel : comptes d'équipe, appareils, retrait
 * après vérification d'identité hors bande).
 * Tutoiement partout ; pt-BR au « você » ; el au singulier (aucun impératif
 * en -τε) ; ca sans mot en -eu/-iu (« raó » plutôt que « motiu ») ; rôles sans
 * genre (« équipe de biblioteca », « library team »…) ; it et nl sans
 * « Account » seul (identique à en).
 * Idempotent : une clé déjà posée n'est réécrite que si sa valeur a changé ici.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const T = {
  fr: {
    'rede.tab.twoFactor': 'Double authentification',
    'twoFactor.required.title': 'Double authentification obligatoire',
    'twoFactor.required.body': "Ton rôle dans le réseau (administration, coordination ou bibliothécaire) demande la double authentification. Inscris un appareil pour continuer : c'est l'affaire de deux minutes.",
    'twoFactor.admin.mode': 'Exigence en vigueur : {mode}',
    'twoFactor.admin.mode.off': 'aucune, la double authentification reste facultative',
    'twoFactor.admin.mode.facteurs': 'les comptes qui ont inscrit un appareil',
    'twoFactor.admin.mode.equipes': "les comptes d'équipe et ceux qui ont inscrit un appareil",
    'twoFactor.admin.intro': "Les comptes d'équipe actifs (administration du réseau, coordinations, bibliothécaires) et ceux qui ont choisi la double authentification. Ceux sans appareil apparaissent en premier.",
    'twoFactor.admin.count': '{total, plural, one {# compte} other {# comptes}}, dont {sans} sans appareil.',
    'twoFactor.admin.empty': 'Aucun compte.',
    'twoFactor.admin.col.account': 'Compte',
    'twoFactor.admin.col.teams': 'Rôles',
    'twoFactor.admin.col.devices': 'Appareils',
    'twoFactor.admin.none': 'aucun',
    'twoFactor.admin.networkAdmin': 'administration du réseau',
    'twoFactor.admin.remove': 'Retirer ses appareils',
    'twoFactor.admin.removeHint': "Seulement après avoir vérifié l'identité de la personne par un autre moyen (de vive voix, Matrix). Le compte sera déconnecté partout et devra inscrire un nouvel appareil.",
    'twoFactor.admin.motifLabel': "Motif (comment l'identité a été vérifiée)",
    'twoFactor.admin.motifRequired': 'Le motif compte au moins dix caractères.',
    'twoFactor.admin.confirm': 'Retirer et déconnecter',
    'twoFactor.admin.done': '{n, plural, one {# appareil retiré} other {# appareils retirés}}, compte déconnecté partout.',
  },
  'pt-BR': {
    'rede.tab.twoFactor': 'Autenticação em dois fatores',
    'twoFactor.required.title': 'Autenticação em dois fatores obrigatória',
    'twoFactor.required.body': 'O seu papel na rede (administração, coordenação ou equipe de biblioteca) exige a autenticação em dois fatores. Cadastre um dispositivo para continuar: leva dois minutos.',
    'twoFactor.admin.mode': 'Exigência em vigor: {mode}',
    'twoFactor.admin.mode.off': 'nenhuma, a autenticação em dois fatores continua opcional',
    'twoFactor.admin.mode.facteurs': 'as contas que cadastraram um dispositivo',
    'twoFactor.admin.mode.equipes': 'as contas de equipe e as que cadastraram um dispositivo',
    'twoFactor.admin.intro': 'As contas de equipe ativas (administração da rede, coordenações, equipes de biblioteca) e as que escolheram a autenticação em dois fatores. As sem dispositivo aparecem primeiro.',
    'twoFactor.admin.count': '{total, plural, one {# conta} other {# contas}}, {sans} sem dispositivo.',
    'twoFactor.admin.empty': 'Nenhuma conta.',
    'twoFactor.admin.col.account': 'Conta',
    'twoFactor.admin.col.teams': 'Papéis',
    'twoFactor.admin.col.devices': 'Dispositivos',
    'twoFactor.admin.none': 'nenhum',
    'twoFactor.admin.networkAdmin': 'administração da rede',
    'twoFactor.admin.remove': 'Remover os dispositivos',
    'twoFactor.admin.removeHint': 'Só depois de verificar a identidade da pessoa por outro meio (pessoalmente, Matrix). A conta será desconectada em todos os lugares e precisará cadastrar um novo dispositivo.',
    'twoFactor.admin.motifLabel': 'Motivo (como a identidade foi verificada)',
    'twoFactor.admin.motifRequired': 'O motivo deve ter pelo menos dez caracteres.',
    'twoFactor.admin.confirm': 'Remover e desconectar',
    'twoFactor.admin.done': '{n, plural, one {# dispositivo removido} other {# dispositivos removidos}}, conta desconectada em todos os lugares.',
  },
  en: {
    'rede.tab.twoFactor': 'Two-factor authentication',
    'twoFactor.required.title': 'Two-factor authentication required',
    'twoFactor.required.body': 'Your role in the network (administration, coordination or library team) requires two-factor authentication. Enroll a device to continue: it takes two minutes.',
    'twoFactor.admin.mode': 'Requirement in force: {mode}',
    'twoFactor.admin.mode.off': 'none, two-factor authentication stays optional',
    'twoFactor.admin.mode.facteurs': 'accounts that have enrolled a device',
    'twoFactor.admin.mode.equipes': 'team accounts and accounts that have enrolled a device',
    'twoFactor.admin.intro': 'Active team accounts (network administration, coordinators, library teams) and accounts that chose two-factor authentication. Those without a device come first.',
    'twoFactor.admin.count': '{total, plural, one {# account} other {# accounts}}, {sans} without a device.',
    'twoFactor.admin.empty': 'No accounts.',
    'twoFactor.admin.col.account': 'Account',
    'twoFactor.admin.col.teams': 'Roles',
    'twoFactor.admin.col.devices': 'Devices',
    'twoFactor.admin.none': 'none',
    'twoFactor.admin.networkAdmin': 'network administration',
    'twoFactor.admin.remove': 'Remove their devices',
    'twoFactor.admin.removeHint': "Only after checking the person's identity another way (in person, Matrix). The account will be signed out everywhere and will have to enroll a new device.",
    'twoFactor.admin.motifLabel': 'Reason (how the identity was checked)',
    'twoFactor.admin.motifRequired': 'The reason needs at least ten characters.',
    'twoFactor.admin.confirm': 'Remove and sign out',
    'twoFactor.admin.done': '{n, plural, one {# device removed} other {# devices removed}}, account signed out everywhere.',
  },
  es: {
    'rede.tab.twoFactor': 'Autenticación en dos pasos',
    'twoFactor.required.title': 'Autenticación en dos pasos obligatoria',
    'twoFactor.required.body': 'Tu papel en la red (administración, coordinación o equipo de biblioteca) exige la autenticación en dos pasos. Registra un dispositivo para continuar: son dos minutos.',
    'twoFactor.admin.mode': 'Exigencia vigente: {mode}',
    'twoFactor.admin.mode.off': 'ninguna, la autenticación en dos pasos sigue siendo opcional',
    'twoFactor.admin.mode.facteurs': 'las cuentas que han registrado un dispositivo',
    'twoFactor.admin.mode.equipes': 'las cuentas de equipo y las que han registrado un dispositivo',
    'twoFactor.admin.intro': 'Las cuentas de equipo activas (administración de la red, coordinaciones, equipos de biblioteca) y las que eligieron la autenticación en dos pasos. Las que no tienen dispositivo aparecen primero.',
    'twoFactor.admin.count': '{total, plural, one {# cuenta} other {# cuentas}}, {sans} sin dispositivo.',
    'twoFactor.admin.empty': 'Ninguna cuenta.',
    'twoFactor.admin.col.account': 'Cuenta',
    'twoFactor.admin.col.teams': 'Papeles',
    'twoFactor.admin.col.devices': 'Dispositivos',
    'twoFactor.admin.none': 'ninguno',
    'twoFactor.admin.networkAdmin': 'administración de la red',
    'twoFactor.admin.remove': 'Quitar sus dispositivos',
    'twoFactor.admin.removeHint': 'Solo después de verificar la identidad de la persona por otro medio (en persona, Matrix). La sesión de la cuenta se cerrará en todas partes y tendrá que registrar un dispositivo nuevo.',
    'twoFactor.admin.motifLabel': 'Motivo (cómo se verificó la identidad)',
    'twoFactor.admin.motifRequired': 'El motivo necesita al menos diez caracteres.',
    'twoFactor.admin.confirm': 'Quitar y cerrar sesión',
    'twoFactor.admin.done': '{n, plural, one {# dispositivo quitado} other {# dispositivos quitados}}, sesión cerrada en todas partes.',
  },
  ca: {
    'rede.tab.twoFactor': 'Autenticació en dos passos',
    'twoFactor.required.title': 'Autenticació en dos passos obligatòria',
    'twoFactor.required.body': "El paper que tens a la xarxa (administració, coordinació o equip de biblioteca) demana l'autenticació en dos passos. Registra un aparell per continuar: són dos minuts.",
    'twoFactor.admin.mode': 'Exigència vigent: {mode}',
    'twoFactor.admin.mode.off': "cap, l'autenticació en dos passos continua sent opcional",
    'twoFactor.admin.mode.facteurs': 'els comptes que han registrat un aparell',
    'twoFactor.admin.mode.equipes': "els comptes d'equip i els que han registrat un aparell",
    'twoFactor.admin.intro': "Els comptes d'equip actius (administració de la xarxa, coordinacions, equips de biblioteca) i els que han triat l'autenticació en dos passos. Els que no tenen aparell surten primer.",
    'twoFactor.admin.count': '{total, plural, one {# compte} other {# comptes}}, {sans} sense aparell.',
    'twoFactor.admin.empty': 'Cap compte.',
    'twoFactor.admin.col.account': 'Compte',
    'twoFactor.admin.col.teams': 'Papers',
    'twoFactor.admin.col.devices': 'Aparells',
    'twoFactor.admin.none': 'cap',
    'twoFactor.admin.networkAdmin': 'administració de la xarxa',
    'twoFactor.admin.remove': 'Treure els aparells',
    'twoFactor.admin.removeHint': "Només després de verificar la identitat de la persona per un altre mitjà (en persona, Matrix). La sessió del compte es tancarà a tot arreu i haurà de registrar un aparell nou.",
    'twoFactor.admin.motifLabel': "Raó (com s'ha verificat la identitat)",
    'twoFactor.admin.motifRequired': 'La raó ha de tenir almenys 10 caràcters.',
    'twoFactor.admin.confirm': 'Treure i tancar la sessió',
    'twoFactor.admin.done': '{n, plural, one {# aparell tret} other {# aparells trets}}, sessió tancada a tot arreu.',
  },
  it: {
    'rede.tab.twoFactor': 'Autenticazione a due fattori',
    'twoFactor.required.title': 'Autenticazione a due fattori obbligatoria',
    'twoFactor.required.body': "Il tuo ruolo nella rete (amministrazione, coordinamento o gruppo della biblioteca) richiede l'autenticazione a due fattori. Registra un dispositivo per continuare: ci vogliono due minuti.",
    'twoFactor.admin.mode': 'Requisito in vigore: {mode}',
    'twoFactor.admin.mode.off': "nessuno, l'autenticazione a due fattori resta facoltativa",
    'twoFactor.admin.mode.facteurs': 'gli account che hanno registrato un dispositivo',
    'twoFactor.admin.mode.equipes': 'gli account dei gruppi di lavoro e quelli che hanno registrato un dispositivo',
    'twoFactor.admin.intro': "Gli account attivi dei gruppi di lavoro (amministrazione della rete, coordinamenti, gruppi delle biblioteche) e quelli che hanno scelto l'autenticazione a due fattori. Quelli senza dispositivo compaiono per primi.",
    'twoFactor.admin.count': '{total, plural, one {# account} other {# account}}, {sans} senza dispositivo.',
    'twoFactor.admin.empty': 'Nessun account.',
    'twoFactor.admin.col.account': 'Account utente',
    'twoFactor.admin.col.teams': 'Ruoli',
    'twoFactor.admin.col.devices': 'Dispositivi',
    'twoFactor.admin.none': 'nessuno',
    'twoFactor.admin.networkAdmin': 'amministrazione della rete',
    'twoFactor.admin.remove': 'Rimuovi i dispositivi',
    'twoFactor.admin.removeHint': "Solo dopo aver verificato l'identità della persona con un altro mezzo (di persona, Matrix). L'account verrà disconnesso ovunque e dovrà registrare un nuovo dispositivo.",
    'twoFactor.admin.motifLabel': "Motivo (come è stata verificata l'identità)",
    'twoFactor.admin.motifRequired': 'Il motivo deve avere almeno dieci caratteri.',
    'twoFactor.admin.confirm': 'Rimuovi e disconnetti',
    'twoFactor.admin.done': '{n, plural, one {# dispositivo rimosso} other {# dispositivi rimossi}}, account disconnesso ovunque.',
  },
  de: {
    'rede.tab.twoFactor': 'Zwei-Faktor-Authentifizierung',
    'twoFactor.required.title': 'Zwei-Faktor-Authentifizierung erforderlich',
    'twoFactor.required.body': 'Deine Rolle im Netzwerk (Verwaltung, Koordination oder Bibliotheksteam) erfordert die Zwei-Faktor-Authentifizierung. Richte ein Gerät ein, um fortzufahren: Das dauert zwei Minuten.',
    'twoFactor.admin.mode': 'Geltende Anforderung: {mode}',
    'twoFactor.admin.mode.off': 'keine, die Zwei-Faktor-Authentifizierung bleibt freiwillig',
    'twoFactor.admin.mode.facteurs': 'Konten, die ein Gerät eingerichtet haben',
    'twoFactor.admin.mode.equipes': 'Teamkonten und Konten, die ein Gerät eingerichtet haben',
    'twoFactor.admin.intro': 'Aktive Teamkonten (Netzwerkverwaltung, Koordinationen, Bibliotheksteams) und Konten, die die Zwei-Faktor-Authentifizierung gewählt haben. Konten ohne Gerät stehen oben.',
    'twoFactor.admin.count': '{total, plural, one {# Konto} other {# Konten}}, davon {sans} ohne Gerät.',
    'twoFactor.admin.empty': 'Keine Konten.',
    'twoFactor.admin.col.account': 'Konto',
    'twoFactor.admin.col.teams': 'Rollen',
    'twoFactor.admin.col.devices': 'Geräte',
    'twoFactor.admin.none': 'keines',
    'twoFactor.admin.networkAdmin': 'Netzwerkverwaltung',
    'twoFactor.admin.remove': 'Geräte entfernen',
    'twoFactor.admin.removeHint': 'Erst nachdem du die Identität der Person auf anderem Weg geprüft hast (persönlich, Matrix). Das Konto wird überall abgemeldet und muss ein neues Gerät einrichten.',
    'twoFactor.admin.motifLabel': 'Grund (wie die Identität geprüft wurde)',
    'twoFactor.admin.motifRequired': 'Der Grund braucht mindestens zehn Zeichen.',
    'twoFactor.admin.confirm': 'Entfernen und abmelden',
    'twoFactor.admin.done': '{n, plural, one {# Gerät entfernt} other {# Geräte entfernt}}, Konto überall abgemeldet.',
  },
  nl: {
    'rede.tab.twoFactor': 'Tweestapsverificatie',
    'twoFactor.required.title': 'Tweestapsverificatie verplicht',
    'twoFactor.required.body': 'Je rol in het netwerk (beheer, coördinatie of bibliotheekteam) vereist tweestapsverificatie. Stel een apparaat in om verder te gaan: het kost twee minuten.',
    'twoFactor.admin.mode': 'Geldende eis: {mode}',
    'twoFactor.admin.mode.off': 'geen, tweestapsverificatie blijft vrijwillig',
    'twoFactor.admin.mode.facteurs': 'accounts die een apparaat hebben ingesteld',
    'twoFactor.admin.mode.equipes': 'teamaccounts en accounts die een apparaat hebben ingesteld',
    'twoFactor.admin.intro': 'Actieve teamaccounts (netwerkbeheer, coördinaties, bibliotheekteams) en accounts die voor tweestapsverificatie hebben gekozen. Accounts zonder apparaat staan bovenaan.',
    'twoFactor.admin.count': '{total, plural, one {# account} other {# accounts}}, waarvan {sans} zonder apparaat.',
    'twoFactor.admin.empty': 'Geen accounts.',
    'twoFactor.admin.col.account': 'Gebruikersaccount',
    'twoFactor.admin.col.teams': 'Rollen',
    'twoFactor.admin.col.devices': 'Apparaten',
    'twoFactor.admin.none': 'geen',
    'twoFactor.admin.networkAdmin': 'netwerkbeheer',
    'twoFactor.admin.remove': 'Apparaten verwijderen',
    'twoFactor.admin.removeHint': 'Pas nadat je de identiteit van de persoon op een andere manier hebt gecontroleerd (persoonlijk, Matrix). Het account wordt overal afgemeld en moet een nieuw apparaat instellen.',
    'twoFactor.admin.motifLabel': 'Reden (hoe de identiteit is gecontroleerd)',
    'twoFactor.admin.motifRequired': 'De reden moet minstens tien tekens hebben.',
    'twoFactor.admin.confirm': 'Verwijderen en afmelden',
    'twoFactor.admin.done': '{n, plural, one {# apparaat verwijderd} other {# apparaten verwijderd}}, account overal afgemeld.',
  },
  eo: {
    'rede.tab.twoFactor': 'Dufaktora aŭtentigo',
    'twoFactor.required.title': 'Dufaktora aŭtentigo deviga',
    'twoFactor.required.body': 'Via rolo en la reto (administrado, kunordigo aŭ biblioteka teamo) postulas dufaktoran aŭtentigon. Registru aparaton por daŭrigi: tio daŭras du minutojn.',
    'twoFactor.admin.mode': 'Valida postulo: {mode}',
    'twoFactor.admin.mode.off': 'neniu, dufaktora aŭtentigo restas libervola',
    'twoFactor.admin.mode.facteurs': 'kontoj, kiuj registris aparaton',
    'twoFactor.admin.mode.equipes': 'teamaj kontoj kaj kontoj, kiuj registris aparaton',
    'twoFactor.admin.intro': 'Aktivaj teamaj kontoj (administrado de la reto, kunordigoj, bibliotekaj teamoj) kaj kontoj, kiuj elektis dufaktoran aŭtentigon. Tiuj sen aparato aperas unue.',
    'twoFactor.admin.count': '{total, plural, one {# konto} other {# kontoj}}, el kiuj {sans} sen aparato.',
    'twoFactor.admin.empty': 'Neniu konto.',
    'twoFactor.admin.col.account': 'Konto',
    'twoFactor.admin.col.teams': 'Roloj',
    'twoFactor.admin.col.devices': 'Aparatoj',
    'twoFactor.admin.none': 'neniu',
    'twoFactor.admin.networkAdmin': 'administrado de la reto',
    'twoFactor.admin.remove': 'Forigi la aparatojn',
    'twoFactor.admin.removeHint': 'Nur post kontrolo de la identeco de la persono alimaniere (persone, Matrix). La konto estos elsalutita ĉie kaj devos registri novan aparaton.',
    'twoFactor.admin.motifLabel': 'Kialo (kiel la identeco estis kontrolita)',
    'twoFactor.admin.motifRequired': 'La kialo bezonas almenaŭ dek signojn.',
    'twoFactor.admin.confirm': 'Forigi kaj elsalutigi',
    'twoFactor.admin.done': '{n, plural, one {# aparato forigita} other {# aparatoj forigitaj}}, konto elsalutita ĉie.',
  },
  el: {
    'rede.tab.twoFactor': 'Έλεγχος δύο παραγόντων',
    'twoFactor.required.title': 'Υποχρεωτικός έλεγχος δύο παραγόντων',
    'twoFactor.required.body': 'Ο ρόλος σου στο δίκτυο (διαχείριση, συντονισμός ή ομάδα βιβλιοθήκης) απαιτεί έλεγχο δύο παραγόντων. Καταχώρισε μια συσκευή για να συνεχίσεις: χρειάζονται δύο λεπτά.',
    'twoFactor.admin.mode': 'Ισχύουσα απαίτηση: {mode}',
    'twoFactor.admin.mode.off': 'καμία, ο έλεγχος δύο παραγόντων μένει προαιρετικός',
    'twoFactor.admin.mode.facteurs': 'οι λογαριασμοί που έχουν καταχωρίσει συσκευή',
    'twoFactor.admin.mode.equipes': 'οι λογαριασμοί ομάδας και όσοι έχουν καταχωρίσει συσκευή',
    'twoFactor.admin.intro': 'Οι ενεργοί λογαριασμοί ομάδας (διαχείριση δικτύου, συντονισμοί, ομάδες βιβλιοθηκών) και όσοι επέλεξαν τον έλεγχο δύο παραγόντων. Όσοι δεν έχουν συσκευή εμφανίζονται πρώτοι.',
    'twoFactor.admin.count': '{total, plural, one {# λογαριασμός} other {# λογαριασμοί}}, από τους οποίους {sans} χωρίς συσκευή.',
    'twoFactor.admin.empty': 'Κανένας λογαριασμός.',
    'twoFactor.admin.col.account': 'Λογαριασμός',
    'twoFactor.admin.col.teams': 'Ρόλοι',
    'twoFactor.admin.col.devices': 'Συσκευές',
    'twoFactor.admin.none': 'καμία',
    'twoFactor.admin.networkAdmin': 'διαχείριση δικτύου',
    'twoFactor.admin.remove': 'Αφαίρεση συσκευών',
    'twoFactor.admin.removeHint': 'Μόνο αφού επαληθεύσεις την ταυτότητα του ατόμου με άλλο τρόπο (από κοντά, Matrix). Ο λογαριασμός θα αποσυνδεθεί παντού και θα πρέπει να καταχωρίσει νέα συσκευή.',
    'twoFactor.admin.motifLabel': 'Αιτιολογία (πώς επαληθεύτηκε η ταυτότητα)',
    'twoFactor.admin.motifRequired': 'Η αιτιολογία χρειάζεται τουλάχιστον δέκα χαρακτήρες.',
    'twoFactor.admin.confirm': 'Αφαίρεση και αποσύνδεση',
    'twoFactor.admin.done': '{n, plural, one {# συσκευή αφαιρέθηκε} other {# συσκευές αφαιρέθηκαν}}, ο λογαριασμός αποσυνδέθηκε παντού.',
  },
};

// Toutes les locales portent exactement les mêmes clés.
const CLES_FR = Object.keys(T.fr);
for (const loc of LOCALES) {
  const manquantes = CLES_FR.filter((k) => !(k in T[loc]));
  const enTrop = Object.keys(T[loc]).filter((k) => !(k in T.fr));
  if (manquantes.length || enTrop.length) throw new Error(`${loc} : manquantes ${manquantes} / en trop ${enTrop}`);
}

const ligneDe = (cle) => new RegExp('^  ' + JSON.stringify(cle).replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ': (".*?")(,?)$', 'm');

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  let ajoutees = 0;
  let corrigees = 0;
  for (const cle of CLES_FR) {
    const val = T[loc][cle];
    const m = content.match(ligneDe(cle));
    if (m) {
      if (JSON.parse(m[1]) !== val) {
        content = content.replace(m[0], '  ' + JSON.stringify(cle) + ': ' + JSON.stringify(val) + m[2]);
        corrigees++;
      }
      continue;
    }
    const entry = '  ' + JSON.stringify(cle) + ': ' + JSON.stringify(val);
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entry + '\n' + content.slice(marker);
    ajoutees++;
  }
  if (!content.endsWith('\n')) content += '\n';
  fs.writeFileSync(file, content, 'utf8');
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(`${loc} : ${ajoutees} clé(s) ajoutée(s), ${corrigees} corrigée(s), JSON valide.`);
}
