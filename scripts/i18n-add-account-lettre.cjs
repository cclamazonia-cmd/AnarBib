/* ===========================================================================
 * i18n-add-account-lettre.cjs
 * Lot 2 (2b) — toggle « Lettre de la fédération » dans /conta : 8 clés UI
 * (account.lettre.*) dans les 10 locales. Insertion idempotente (sentinelle
 * account.lettre.note). Convention reprise de i18n-add-federacao-gazeta.cjs.
 * Les strings e-mail vivent dans _shared/i18n/mail-strings.ts (séparé).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'account.lettre.note';

const ADD = {
  'pt-BR': {
    'account.lettre.title': 'Boletim da rede',
    'account.lettre.intro': 'Um caderno da vida da rede, enviado por e-mail só se tu pedires.',
    'account.lettre.toggle': 'Receber o Boletim da rede',
    'account.lettre.confirmationSent': 'Enviámos-te um e-mail de confirmação — clica no link para validar tua inscrição.',
    'account.lettre.pending': 'Confirmação pendente: verifica tua caixa de entrada (e o spam).',
    'account.lettre.subscribed': 'A tua inscrição está ativa.',
    'account.lettre.unsubscribed': 'A tua inscrição foi cancelada.',
    'account.lettre.note': 'Podes cancelar a qualquer momento, com um clique. Sem rastreio, sem revenda.',
  },
  fr: {
    'account.lettre.title': 'Lettre de la fédération',
    'account.lettre.intro': 'Un carnet de la vie du réseau, envoyé par e-mail seulement si tu le demandes.',
    'account.lettre.toggle': 'Recevoir la Lettre de la fédération',
    'account.lettre.confirmationSent': 'On t’a envoyé un e-mail de confirmation — clique sur le lien pour valider ton abonnement.',
    'account.lettre.pending': 'Confirmation en attente : vérifie ta boîte mail (et les indésirables).',
    'account.lettre.subscribed': 'Ton abonnement est actif.',
    'account.lettre.unsubscribed': 'Ton abonnement est annulé.',
    'account.lettre.note': 'Désabonnement possible à tout moment, en un clic. Aucun pistage, aucune revente.',
  },
  es: {
    'account.lettre.title': 'Boletín de la red',
    'account.lettre.intro': 'Un cuaderno de la vida de la red, enviado por correo solo si lo pides.',
    'account.lettre.toggle': 'Recibir el Boletín de la red',
    'account.lettre.confirmationSent': 'Te hemos enviado un correo de confirmación: haz clic en el enlace para validar tu suscripción.',
    'account.lettre.pending': 'Confirmación pendiente: revisa tu bandeja de entrada (y el spam).',
    'account.lettre.subscribed': 'Tu suscripción está activa.',
    'account.lettre.unsubscribed': 'Tu suscripción ha sido cancelada.',
    'account.lettre.note': 'Puedes darte de baja en cualquier momento, con un clic. Sin rastreo, sin reventa.',
  },
  en: {
    'account.lettre.title': 'Federation letter',
    'account.lettre.intro': 'A notebook of the network’s life, sent by email only if you ask for it.',
    'account.lettre.toggle': 'Receive the federation letter',
    'account.lettre.confirmationSent': 'We’ve sent you a confirmation email — click the link to confirm your subscription.',
    'account.lettre.pending': 'Confirmation pending: check your inbox (and spam folder).',
    'account.lettre.subscribed': 'Your subscription is active.',
    'account.lettre.unsubscribed': 'Your subscription has been cancelled.',
    'account.lettre.note': 'Unsubscribe any time, in one click. No tracking, no reselling.',
  },
  it: {
    'account.lettre.title': 'Lettera della rete',
    'account.lettre.intro': 'Un taccuino della vita della rete, inviato per e-mail solo se lo chiedi.',
    'account.lettre.toggle': 'Ricevere la Lettera della rete',
    'account.lettre.confirmationSent': 'Ti abbiamo inviato un’e-mail di conferma — clicca sul link per convalidare la tua iscrizione.',
    'account.lettre.pending': 'Conferma in sospeso: controlla la tua casella di posta (e lo spam).',
    'account.lettre.subscribed': 'La tua iscrizione è attiva.',
    'account.lettre.unsubscribed': 'La tua iscrizione è stata annullata.',
    'account.lettre.note': 'Puoi disiscriverti in qualsiasi momento, con un clic. Nessun tracciamento, nessuna rivendita.',
  },
  de: {
    'account.lettre.title': 'Netzwerk-Rundbrief',
    'account.lettre.intro': 'Ein Notizbuch aus dem Leben des Netzwerks — nur per E-Mail, wenn du es möchtest.',
    'account.lettre.toggle': 'Den Netzwerk-Rundbrief erhalten',
    'account.lettre.confirmationSent': 'Wir haben dir eine Bestätigungs-E-Mail geschickt — klicke auf den Link, um dein Abo zu bestätigen.',
    'account.lettre.pending': 'Bestätigung ausstehend: Sieh in deinem Postfach nach (auch im Spam).',
    'account.lettre.subscribed': 'Dein Abo ist aktiv.',
    'account.lettre.unsubscribed': 'Dein Abo wurde gekündigt.',
    'account.lettre.note': 'Jederzeit mit einem Klick abbestellbar. Kein Tracking, kein Weiterverkauf.',
  },
  ca: {
    'account.lettre.title': 'Butlletí de la xarxa',
    'account.lettre.intro': 'Un quadern de la vida de la xarxa, enviat per correu només si ho demanes.',
    'account.lettre.toggle': 'Rebre el Butlletí de la xarxa',
    'account.lettre.confirmationSent': 'T’hem enviat un correu de confirmació: fes clic a l’enllaç per validar la teva subscripció.',
    'account.lettre.pending': 'Confirmació pendent: revisa la teva safata d’entrada (i el correu brossa).',
    'account.lettre.subscribed': 'La teva subscripció és activa.',
    'account.lettre.unsubscribed': 'La teva subscripció s’ha cancel·lat.',
    'account.lettre.note': 'Pots donar-te de baixa en qualsevol moment, amb un clic. Sense rastreig, sense revenda.',
  },
  eo: {
    'account.lettre.title': 'Reta bulteno',
    'account.lettre.intro': 'Kajero pri la vivo de la reto, sendata retpoŝte nur se vi petas.',
    'account.lettre.toggle': 'Ricevi la retan bultenon',
    'account.lettre.confirmationSent': 'Ni sendis al vi konfirman retmesaĝon — klaku la ligilon por validigi vian abonon.',
    'account.lettre.pending': 'Konfirmo atendata: kontrolu vian poŝtkeston (kaj la spamujon).',
    'account.lettre.subscribed': 'Via abono estas aktiva.',
    'account.lettre.unsubscribed': 'Via abono estas nuligita.',
    'account.lettre.note': 'Vi povas malaboni iam ajn, per unu klako. Neniu spurado, neniu revendo.',
  },
  nl: {
    'account.lettre.title': 'Nieuwsbrief van het netwerk',
    'account.lettre.intro': 'Een logboek van het leven van het netwerk, alleen per e-mail als je erom vraagt.',
    'account.lettre.toggle': 'De nieuwsbrief van het netwerk ontvangen',
    'account.lettre.confirmationSent': 'We hebben je een bevestigingsmail gestuurd — klik op de link om je inschrijving te bevestigen.',
    'account.lettre.pending': 'Bevestiging in afwachting: controleer je inbox (en de spammap).',
    'account.lettre.subscribed': 'Je inschrijving is actief.',
    'account.lettre.unsubscribed': 'Je inschrijving is geannuleerd.',
    'account.lettre.note': 'Je kunt je op elk moment met één klik uitschrijven. Geen tracking, geen doorverkoop.',
  },
  el: {
    'account.lettre.title': 'Ενημερωτικό δελτίο του δικτύου',
    'account.lettre.intro': 'Ένα σημειωματάριο της ζωής του δικτύου, που στέλνεται με e-mail μόνο αν το ζητήσεις.',
    'account.lettre.toggle': 'Να λαμβάνω το ενημερωτικό δελτίο του δικτύου',
    'account.lettre.confirmationSent': 'Σου στείλαμε ένα e-mail επιβεβαίωσης — πάτησε τον σύνδεσμο για να επικυρώσεις την εγγραφή σου.',
    'account.lettre.pending': 'Εκκρεμεί επιβεβαίωση: έλεγξε τα εισερχόμενά σου (και τα ανεπιθύμητα).',
    'account.lettre.subscribed': 'Η εγγραφή σου είναι ενεργή.',
    'account.lettre.unsubscribed': 'Η εγγραφή σου ακυρώθηκε.',
    'account.lettre.note': 'Μπορείς να διαγραφείς οποιαδήποτε στιγμή, με ένα κλικ. Χωρίς παρακολούθηση, χωρίς μεταπώληση.',
  },
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes('"' + SENTINEL + '"')) {
    const map = ADD[loc];
    const keys = Object.keys(ADD['pt-BR']);
    const entries = keys.map((k) => {
      if (map[k] == null) throw new Error('Traduction manquante: ' + k + ' / ' + loc);
      return '  ' + JSON.stringify(k) + ': ' + JSON.stringify(map[k]);
    });
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entries.join(',\n') + '\n' + content.slice(marker);
    if (!content.endsWith('\n')) content += '\n';
    fs.writeFileSync(file, content, 'utf8');
  }
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ': 8 clés account.lettre (si absentes), JSON valide.');
}
console.log('\nTerminé.');
