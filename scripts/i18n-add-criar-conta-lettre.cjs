/* ===========================================================================
 * i18n-add-criar-conta-lettre.cjs  — À INTÉGRER : scripts/
 * Case « Lettre » au signup : 1 clé auth.create.consentLettre × 10 locales.
 * Idempotent (sentinelle auth.create.consentLettre).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'auth.create.consentLettre';

const ADD = {
  'pt-BR': { 'auth.create.consentLettre': 'Quero também receber o Boletim da rede (cancelo quando quiser).' },
  fr: { 'auth.create.consentLettre': 'Je veux aussi recevoir la Lettre de la fédération (désabonnement à tout moment).' },
  es: { 'auth.create.consentLettre': 'También quiero recibir el Boletín de la red (puedo darme de baja cuando quiera).' },
  en: { 'auth.create.consentLettre': 'I’d also like to receive the federation letter (unsubscribe any time).' },
  it: { 'auth.create.consentLettre': 'Voglio anche ricevere la Lettera della rete (mi disiscrivo quando voglio).' },
  de: { 'auth.create.consentLettre': 'Ich möchte auch den Netzwerk-Rundbrief erhalten (jederzeit abbestellbar).' },
  ca: { 'auth.create.consentLettre': 'També vull rebre el Butlletí de la xarxa (em puc donar de baixa quan vulgui).' },
  eo: { 'auth.create.consentLettre': 'Mi ankaŭ volas ricevi la retan bultenon (mi povas malaboni iam ajn).' },
  nl: { 'auth.create.consentLettre': 'Ik wil ook de nieuwsbrief van het netwerk ontvangen (uitschrijven kan altijd).' },
  el: { 'auth.create.consentLettre': 'Θέλω επίσης να λαμβάνω το ενημερωτικό δελτίο του δικτύου (διαγραφή οποτεδήποτε).' },
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
  console.log(loc + ': 1 clé consentLettre (si absente), JSON valide.');
}
console.log('\nTerminé.');
