/* ===========================================================================
 * i18n-add-rede-gazeta-broadcast.cjs
 * Bouton « Diffuser » du panneau staff Gazette (Étape C) : 4 clés × 10 locales.
 * Idempotent (sentinelle rede.gazeta.broadcast).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'rede.gazeta.broadcast';

const ADD = {
  fr: {
    'rede.gazeta.broadcast': 'Diffuser',
    'rede.gazeta.broadcastConfirm': 'Diffuser le n°{number} par e-mail à tout le staff du réseau ?',
    'rede.gazeta.broadcastDone': 'Diffusé à {count} destinataires.',
    'rede.gazeta.broadcastedAt': 'diffusé le {date}',
  },
  'pt-BR': {
    'rede.gazeta.broadcast': 'Difundir',
    'rede.gazeta.broadcastConfirm': 'Difundir o n.º {number} por e-mail a todo o staff da rede?',
    'rede.gazeta.broadcastDone': 'Difundido a {count} destinatários.',
    'rede.gazeta.broadcastedAt': 'difundido em {date}',
  },
  es: {
    'rede.gazeta.broadcast': 'Difundir',
    'rede.gazeta.broadcastConfirm': '¿Difundir el n.º {number} por correo a todo el staff de la red?',
    'rede.gazeta.broadcastDone': 'Difundido a {count} destinatarios.',
    'rede.gazeta.broadcastedAt': 'difundido el {date}',
  },
  en: {
    'rede.gazeta.broadcast': 'Broadcast',
    'rede.gazeta.broadcastConfirm': 'Broadcast issue {number} by email to all network staff?',
    'rede.gazeta.broadcastDone': 'Sent to {count} recipients.',
    'rede.gazeta.broadcastedAt': 'broadcast on {date}',
  },
  it: {
    'rede.gazeta.broadcast': 'Diffondi',
    'rede.gazeta.broadcastConfirm': 'Diffondere il n. {number} via e-mail a tutto lo staff della rete?',
    'rede.gazeta.broadcastDone': 'Diffuso a {count} destinatari.',
    'rede.gazeta.broadcastedAt': 'diffuso il {date}',
  },
  de: {
    'rede.gazeta.broadcast': 'Verbreiten',
    'rede.gazeta.broadcastConfirm': 'Ausgabe {number} per E-Mail an das gesamte Netzwerk-Team senden?',
    'rede.gazeta.broadcastDone': 'An {count} Personen gesendet.',
    'rede.gazeta.broadcastedAt': 'verbreitet am {date}',
  },
  ca: {
    'rede.gazeta.broadcast': 'Difondre',
    'rede.gazeta.broadcastConfirm': 'Difondre el núm. {number} per correu a tot l’staff de la xarxa?',
    'rede.gazeta.broadcastDone': 'Difós a {count} destinataris.',
    'rede.gazeta.broadcastedAt': 'difós el {date}',
  },
  eo: {
    'rede.gazeta.broadcast': 'Disvastigi',
    'rede.gazeta.broadcastConfirm': 'Ĉu disvastigi la n-ron {number} retpoŝte al la tuta reta teamo?',
    'rede.gazeta.broadcastDone': 'Sendita al {count} ricevantoj.',
    'rede.gazeta.broadcastedAt': 'disvastigita la {date}',
  },
  nl: {
    'rede.gazeta.broadcast': 'Verspreiden',
    'rede.gazeta.broadcastConfirm': 'Nummer {number} per e-mail naar het hele netwerkteam verspreiden?',
    'rede.gazeta.broadcastDone': 'Verzonden naar {count} ontvangers.',
    'rede.gazeta.broadcastedAt': 'verspreid op {date}',
  },
  el: {
    'rede.gazeta.broadcast': 'Διάδοση',
    'rede.gazeta.broadcastConfirm': 'Διάδοση του τεύχους αρ. {number} με e-mail σε όλο το προσωπικό του δικτύου;',
    'rede.gazeta.broadcastDone': 'Στάλθηκε σε {count} παραλήπτες.',
    'rede.gazeta.broadcastedAt': 'διαδόθηκε στις {date}',
  },
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes('"' + SENTINEL + '"')) {
    const map = ADD[loc];
    const keys = Object.keys(ADD.fr);
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
  console.log(loc + ': 4 clés broadcast (si absentes), JSON valide.');
}
console.log('\nTerminé.');
