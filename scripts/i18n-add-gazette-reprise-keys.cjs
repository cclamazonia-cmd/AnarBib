/* ===========================================================================
 * i18n-add-gazette-reprise-keys.cjs
 * GAZ-7 (15/09/2026) — une brève rejetée dit pourquoi et peut revenir.
 * Panneau staff (motif obligatoire au rejet, reprise chaînée) et formulaire
 * public de reprise (pré-rempli par le jeton reçu par courriel). 21 clés × 10
 * locales.
 *
 * Idempotent (sentinelle par clé) et purement textuel : insertion avant le `}`
 * final, jamais de re-sérialisation JSON.
 *
 * Les dix langues sont produites d'emblée, y compris celles où je suis le moins
 * sûr (el, eo, nl, ca) : mieux vaut une formulation à corriger qu'un repli
 * silencieux, qui ne se voit pas et ne se signale pas.
 * Tutoiement fr/es (décision du 07/09), formes neutres ou doublets ailleurs.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const KEYS = {
  // ── Panneau staff : le rejet porte un motif ─────────────────────────────
  'rede.gazeta.reject.noteLabel': {
    'pt-BR': 'Motivo da rejeição (enviado à pessoa)', fr: 'Motif du rejet (transmis à la personne)',
    es: 'Motivo del rechazo (enviado a la persona)', en: 'Reason for rejection (sent to the contributor)',
    it: 'Motivo del rifiuto (inviato alla persona)', de: 'Grund der Ablehnung (geht an die Person)',
    ca: 'Motiu del rebuig (enviat a la persona)', eo: 'Kialo de la malakcepto (sendita al la persono)',
    nl: 'Reden van afwijzing (gaat naar de persoon)', el: 'Λόγος απόρριψης (αποστέλλεται στο άτομο)',
  },
  'rede.gazeta.reject.notePlaceholder': {
    'pt-BR': 'Diz por quê, e o que tornaria a nota publicável.', fr: 'Dis pourquoi, et ce qui rendrait la brève publiable.',
    es: 'Di por qué, y qué haría publicable la nota.', en: 'Say why, and what would make the bulletin publishable.',
    it: 'Di’ perché, e cosa renderebbe la breve pubblicabile.', de: 'Sag warum, und was die Kurzmeldung veröffentlichbar machen würde.',
    ca: 'Digues per què, i què faria publicable la breu.', eo: 'Diru kial, kaj kio farus la novaĵeton publikigebla.',
    nl: 'Zeg waarom, en wat het bericht wél publiceerbaar zou maken.', el: 'Πες γιατί, και τι θα έκανε το σημείωμα δημοσιεύσιμο.',
  },
  'rede.gazeta.reject.confirm': {
    'pt-BR': 'Confirmar a rejeição', fr: 'Confirmer le rejet', es: 'Confirmar el rechazo', en: 'Confirm rejection',
    it: 'Confermare il rifiuto', de: 'Ablehnung bestätigen', ca: 'Confirmar el rebuig', eo: 'Konfirmi la malakcepton',
    nl: 'Afwijzing bevestigen', el: 'Επιβεβαίωση απόρριψης',
  },
  'rede.gazeta.reject.withEmail': {
    'pt-BR': 'A pessoa receberá este motivo por e-mail, com um link para corrigir e reenviar a nota (válido 60 dias).',
    fr: 'La personne recevra ce motif par e-mail, avec un lien pour corriger et renvoyer sa brève (valable 60 jours).',
    es: 'La persona recibirá este motivo por correo, con un enlace para corregir y reenviar su nota (válido 60 días).',
    en: 'The contributor will receive this reason by e-mail, with a link to revise and resend the bulletin (valid 60 days).',
    it: 'La persona riceverà questo motivo per e-mail, con un link per correggere e rimandare la breve (valido 60 giorni).',
    de: 'Die Person erhält diesen Grund per E-Mail, mit einem Link zum Überarbeiten und erneuten Senden (60 Tage gültig).',
    ca: 'La persona rebrà aquest motiu per correu, amb un enllaç per corregir i reenviar la breu (vàlid 60 dies).',
    eo: 'La persono ricevos ĉi tiun kialon retpoŝte, kun ligilo por korekti kaj resendi la novaĵeton (valida 60 tagojn).',
    nl: 'De persoon ontvangt deze reden per e-mail, met een link om het bericht aan te passen en opnieuw in te sturen (60 dagen geldig).',
    el: 'Το άτομο θα λάβει αυτόν τον λόγο με e-mail, μαζί με σύνδεσμο για διόρθωση και επαναποστολή (ισχύει 60 ημέρες).',
  },
  'rede.gazeta.reject.withoutEmail': {
    'pt-BR': 'Nenhum e-mail foi deixado: ninguém será avisado. O motivo fica aqui, para a equipe.',
    fr: 'Aucun e-mail laissé : personne ne sera prévenu. Le motif reste ici, pour l’équipe.',
    es: 'No se dejó ningún correo: nadie será avisado. El motivo queda aquí, para el equipo.',
    en: 'No e-mail was left: nobody will be notified. The reason stays here, for the team.',
    it: 'Nessuna e-mail lasciata: nessuno sarà avvisato. Il motivo resta qui, per l’équipe.',
    de: 'Keine E-Mail hinterlassen: niemand wird benachrichtigt. Der Grund bleibt hier, für das Team.',
    ca: 'No s’ha deixat cap correu: ningú serà avisat. El motiu queda aquí, per a l’equip.',
    eo: 'Neniu retpoŝtadreso lasita: neniu estos avertita. La kialo restas ĉi tie, por la teamo.',
    nl: 'Geen e-mailadres achtergelaten: niemand wordt verwittigd. De reden blijft hier, voor het team.',
    el: 'Δεν αφέθηκε e-mail: κανείς δεν θα ειδοποιηθεί. Ο λόγος μένει εδώ, για την ομάδα.',
  },
  'rede.gazeta.reviewNote': {
    'pt-BR': 'Motivo', fr: 'Motif', es: 'Motivo', en: 'Reason', it: 'Motivo', de: 'Grund',
    ca: 'Motiu', eo: 'Kialo', nl: 'Reden', el: 'Λόγος',
  },
  'rede.gazeta.resubmission.badge': {
    'pt-BR': 'Retomada', fr: 'Reprise', es: 'Retoma', en: 'Resubmission', it: 'Ripresa', de: 'Wiedervorlage',
    ca: 'Represa', eo: 'Reprezento', nl: 'Opnieuw ingestuurd', el: 'Επανυποβολή',
  },
  'rede.gazeta.resubmission.hint': {
    'pt-BR': 'Versão corrigida de uma nota rejeitada. Motivo da rejeição anterior:',
    fr: 'Version corrigée d’une brève rejetée. Motif du rejet précédent :',
    es: 'Versión corregida de una nota rechazada. Motivo del rechazo anterior:',
    en: 'Revised version of a rejected bulletin. Reason for the previous rejection:',
    it: 'Versione corretta di una breve rifiutata. Motivo del rifiuto precedente:',
    de: 'Überarbeitete Fassung einer abgelehnten Kurzmeldung. Grund der vorherigen Ablehnung:',
    ca: 'Versió corregida d’una breu rebutjada. Motiu del rebuig anterior:',
    eo: 'Korektita versio de malakceptita novaĵeto. Kialo de la antaŭa malakcepto:',
    nl: 'Aangepaste versie van een afgewezen bericht. Reden van de vorige afwijzing:',
    el: 'Διορθωμένη εκδοχή απορριφθέντος σημειώματος. Λόγος της προηγούμενης απόρριψης:',
  },
  'rede.gazeta.resubmission.hintNoParent': {
    'pt-BR': 'Versão corrigida de uma nota rejeitada.', fr: 'Version corrigée d’une brève rejetée.',
    es: 'Versión corregida de una nota rechazada.', en: 'Revised version of a rejected bulletin.',
    it: 'Versione corretta di una breve rifiutata.', de: 'Überarbeitete Fassung einer abgelehnten Kurzmeldung.',
    ca: 'Versió corregida d’una breu rebutjada.', eo: 'Korektita versio de malakceptita novaĵeto.',
    nl: 'Aangepaste versie van een afgewezen bericht.', el: 'Διορθωμένη εκδοχή απορριφθέντος σημειώματος.',
  },
  'rede.gazeta.resubmitted.at': {
    'pt-BR': 'retomada recebida em {date}', fr: 'reprise reçue le {date}', es: 'retoma recibida el {date}',
    en: 'resubmission received on {date}', it: 'ripresa ricevuta il {date}', de: 'Wiedervorlage eingegangen am {date}',
    ca: 'represa rebuda el {date}', eo: 'reprezento ricevita la {date}', nl: 'opnieuw ingestuurd op {date}',
    el: 'επανυποβολή ελήφθη στις {date}',
  },
  'rede.gazeta.resubmit.until': {
    'pt-BR': 'retomada possível até {date}', fr: 'reprise possible jusqu’au {date}', es: 'retoma posible hasta el {date}',
    en: 'resubmission possible until {date}', it: 'ripresa possibile fino al {date}', de: 'Wiedervorlage möglich bis {date}',
    ca: 'represa possible fins al {date}', eo: 'reprezento ebla ĝis {date}', nl: 'opnieuw insturen mogelijk tot {date}',
    el: 'επανυποβολή δυνατή έως {date}',
  },
  'rede.gazeta.resubmit.noEmail': {
    'pt-BR': 'sem e-mail: a pessoa não foi avisada', fr: 'sans e-mail : la personne n’a pas été prévenue',
    es: 'sin correo: la persona no fue avisada', en: 'no e-mail: the contributor was not notified',
    it: 'senza e-mail: la persona non è stata avvisata', de: 'keine E-Mail: die Person wurde nicht benachrichtigt',
    ca: 'sense correu: la persona no ha estat avisada', eo: 'sen retpoŝto: la persono ne estis avertita',
    nl: 'geen e-mail: de persoon is niet verwittigd', el: 'χωρίς e-mail: το άτομο δεν ειδοποιήθηκε',
  },

  // ── Formulaire public : corriger et renvoyer ────────────────────────────
  'federacao.gazeta.resubmit.title': {
    'pt-BR': 'Corrigir e reenviar tua nota', fr: 'Corriger et renvoyer ta brève', es: 'Corregir y reenviar tu nota',
    en: 'Revise and resend your bulletin', it: 'Correggere e rimandare la tua breve', de: 'Deine Kurzmeldung überarbeiten und erneut senden',
    ca: 'Corregir i reenviar la teva breu', eo: 'Korekti kaj resendi vian novaĵeton', nl: 'Je bericht aanpassen en opnieuw insturen',
    el: 'Διόρθωσε και ξαναστείλε το σημείωμά σου',
  },
  'federacao.gazeta.resubmit.intro': {
    'pt-BR': 'Tua nota foi lida e não foi retida tal como está. Eis o motivo; corrige o que for preciso e reenvia-a: a equipe da rede a relerá como uma nova proposta.',
    fr: 'Ta brève a été relue et n’a pas été retenue telle quelle. Voici le motif ; corrige ce qui doit l’être, puis renvoie-la : l’équipe réseau la relira comme une nouvelle proposition.',
    es: 'Tu nota fue leída y no fue retenida tal como está. Este es el motivo; corrige lo necesario y vuelve a enviarla: el equipo de la red la releerá como una nueva propuesta.',
    en: 'Your bulletin was read and not retained as it stands. Here is the reason; revise what needs it, then resend it: the network team will read it again as a new proposal.',
    it: 'La tua breve è stata letta e non è stata accolta così com’è. Ecco il motivo; correggi ciò che serve, poi rimandala: l’équipe della rete la rileggerà come una nuova proposta.',
    de: 'Deine Kurzmeldung wurde gelesen und so nicht aufgenommen. Hier der Grund; überarbeite, was nötig ist, und sende sie erneut: das Netzwerk-Team liest sie als neuen Vorschlag.',
    ca: 'La teva breu s’ha llegit i no s’ha retingut tal com està. Aquest és el motiu; corregeix el que calgui i torna-la a enviar: l’equip de la xarxa la rellegirà com una nova proposta.',
    eo: 'Via novaĵeto estis legita kaj ne akceptita tia, kia ĝi estas. Jen la kialo; korektu tion, kio necesas, kaj resendu ĝin: la reta teamo relegos ĝin kiel novan proponon.',
    nl: 'Je bericht is gelezen en zo niet opgenomen. Dit is de reden; pas aan wat nodig is en stuur het opnieuw in: het netwerkteam leest het als een nieuw voorstel.',
    el: 'Το σημείωμά σου διαβάστηκε και δεν κρατήθηκε ως έχει. Να ο λόγος· διόρθωσε ό,τι χρειάζεται και ξαναστείλε το: η ομάδα του δικτύου θα το ξαναδιαβάσει ως νέα πρόταση.',
  },
  'federacao.gazeta.resubmit.reason': {
    'pt-BR': 'Motivo da recusa', fr: 'Motif du refus', es: 'Motivo del rechazo', en: 'Reason for rejection',
    it: 'Motivo del rifiuto', de: 'Grund der Ablehnung', ca: 'Motiu del rebuig', eo: 'Kialo de la malakcepto',
    nl: 'Reden van afwijzing', el: 'Λόγος απόρριψης',
  },
  'federacao.gazeta.resubmit.loading': {
    'pt-BR': 'Recuperando tua nota…', fr: 'Récupération de ta brève…', es: 'Recuperando tu nota…', en: 'Fetching your bulletin…',
    it: 'Recupero della tua breve…', de: 'Deine Kurzmeldung wird geladen…', ca: 'Recuperant la teva breu…', eo: 'Reprenante vian novaĵeton…',
    nl: 'Je bericht wordt opgehaald…', el: 'Ανάκτηση του σημειώματός σου…',
  },
  'federacao.gazeta.resubmit.submit': {
    'pt-BR': 'Reenviar a nota corrigida', fr: 'Renvoyer la brève corrigée', es: 'Reenviar la nota corregida', en: 'Resend the revised bulletin',
    it: 'Rimandare la breve corretta', de: 'Überarbeitete Kurzmeldung senden', ca: 'Reenviar la breu corregida', eo: 'Resendi la korektitan novaĵeton',
    nl: 'Aangepast bericht opnieuw insturen', el: 'Επαναποστολή του διορθωμένου σημειώματος',
  },
  'federacao.gazeta.resubmit.success': {
    'pt-BR': 'Obrigado, tua nota corrigida foi transmitida à equipe da rede.', fr: 'Merci, ta brève corrigée a été transmise à l’équipe réseau.',
    es: 'Gracias, tu nota corregida fue transmitida al equipo de la red.', en: 'Thank you, your revised bulletin has been passed on to the network team.',
    it: 'Grazie, la tua breve corretta è stata trasmessa all’équipe della rete.', de: 'Danke, deine überarbeitete Kurzmeldung wurde an das Netzwerk-Team weitergegeben.',
    ca: 'Gràcies, la teva breu corregida s’ha transmès a l’equip de la xarxa.', eo: 'Dankon, via korektita novaĵeto estis transdonita al la reta teamo.',
    nl: 'Bedankt, je aangepaste bericht is doorgegeven aan het netwerkteam.', el: 'Ευχαριστούμε, το διορθωμένο σημείωμά σου διαβιβάστηκε στην ομάδα του δικτύου.',
  },
  'federacao.gazeta.resubmit.error.invalid': {
    'pt-BR': 'Este link de retomada não é válido. Podes propor tua nota de novo pelo formulário habitual.',
    fr: 'Ce lien de reprise n’est pas valable. Tu peux proposer ta brève à nouveau depuis le formulaire habituel.',
    es: 'Este enlace de retoma no es válido. Puedes proponer tu nota de nuevo desde el formulario habitual.',
    en: 'This resubmission link is not valid. You can propose your bulletin again from the usual form.',
    it: 'Questo link di ripresa non è valido. Puoi proporre di nuovo la tua breve dal modulo abituale.',
    de: 'Dieser Link ist nicht gültig. Du kannst deine Kurzmeldung über das übliche Formular erneut vorschlagen.',
    ca: 'Aquest enllaç de represa no és vàlid. Pots proposar la teva breu de nou des del formulari habitual.',
    eo: 'Ĉi tiu reprezenta ligilo ne validas. Vi povas proponi vian novaĵeton denove per la kutima formularo.',
    nl: 'Deze link is niet geldig. Je kunt je bericht opnieuw voorstellen via het gewone formulier.',
    el: 'Αυτός ο σύνδεσμος επανυποβολής δεν ισχύει. Μπορείς να προτείνεις ξανά το σημείωμά σου από τη συνηθισμένη φόρμα.',
  },
  'federacao.gazeta.resubmit.error.used': {
    'pt-BR': 'Este link já foi usado: tua nota corrigida já foi transmitida.', fr: 'Ce lien a déjà servi : ta brève corrigée a bien été transmise.',
    es: 'Este enlace ya se usó: tu nota corregida ya fue transmitida.', en: 'This link has already been used: your revised bulletin was passed on.',
    it: 'Questo link è già stato usato: la tua breve corretta è già stata trasmessa.', de: 'Dieser Link wurde bereits verwendet: deine überarbeitete Kurzmeldung ist angekommen.',
    ca: 'Aquest enllaç ja s’ha fet servir: la teva breu corregida ja s’ha transmès.', eo: 'Ĉi tiu ligilo jam estis uzita: via korektita novaĵeto jam estis transdonita.',
    nl: 'Deze link is al gebruikt: je aangepaste bericht is doorgegeven.', el: 'Αυτός ο σύνδεσμος έχει ήδη χρησιμοποιηθεί: το διορθωμένο σημείωμά σου έχει διαβιβαστεί.',
  },
  'federacao.gazeta.resubmit.error.expired': {
    'pt-BR': 'Este link de retomada expirou (60 dias). Podes propor tua nota de novo pelo formulário habitual.',
    fr: 'Ce lien de reprise a expiré (60 jours). Tu peux proposer ta brève à nouveau depuis le formulaire habituel.',
    es: 'Este enlace de retoma expiró (60 días). Puedes proponer tu nota de nuevo desde el formulario habitual.',
    en: 'This resubmission link has expired (60 days). You can propose your bulletin again from the usual form.',
    it: 'Questo link di ripresa è scaduto (60 giorni). Puoi proporre di nuovo la tua breve dal modulo abituale.',
    de: 'Dieser Link ist abgelaufen (60 Tage). Du kannst deine Kurzmeldung über das übliche Formular erneut vorschlagen.',
    ca: 'Aquest enllaç de represa ha caducat (60 dies). Pots proposar la teva breu de nou des del formulari habitual.',
    eo: 'Ĉi tiu reprezenta ligilo eksvalidiĝis (60 tagoj). Vi povas proponi vian novaĵeton denove per la kutima formularo.',
    nl: 'Deze link is verlopen (60 dagen). Je kunt je bericht opnieuw voorstellen via het gewone formulier.',
    el: 'Αυτός ο σύνδεσμος επανυποβολής έληξε (60 ημέρες). Μπορείς να προτείνεις ξανά το σημείωμά σου από τη συνηθισμένη φόρμα.',
  },
};

let added = 0;
for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  let n = 0;
  for (const [key, vals] of Object.entries(KEYS)) {
    if (content.includes('"' + key + '"')) continue;
    if (vals[loc] == null) throw new Error('Traduction manquante : ' + loc + ' / ' + key);
    const entry = '  ' + JSON.stringify(key) + ': ' + JSON.stringify(vals[loc]);
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entry + '\n' + content.slice(marker);
    n++;
  }
  if (n > 0) {
    if (!content.endsWith('\n')) content += '\n';
    fs.writeFileSync(file, content, 'utf8');
  }
  JSON.parse(fs.readFileSync(file, 'utf8'));
  added += n;
  console.log(loc + ' : ' + n + ' clé(s) ajoutée(s), JSON valide.');
}
console.log('\nTerminé — ' + added + ' entrée(s) au total (' + Object.keys(KEYS).length + ' clés × ' + LOCALES.length + ' locales).');
