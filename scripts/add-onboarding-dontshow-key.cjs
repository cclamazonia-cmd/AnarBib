/**
 * Add i18n key for the "don't show again" checkbox inside the Painel
 * onboarding guided tour. 10 locales, strict parity.
 * Session : Perf UX + nettoyage advisors securite
 */
const fs = require('fs');
const path = require('path');

const LOCALES_DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const KEYS = {
  'panel.onboarding.tour.dontShowAgain': {
    'pt-BR': 'Não mostrar a visita novamente',
    en: 'Don’t show this tour again',
    fr: 'Ne plus afficher la visite',
    es: 'No mostrar la visita de nuevo',
    de: 'Diese Tour nicht mehr anzeigen',
    it: 'Non mostrare più la visita',
    ca: 'No tornis a mostrar la visita',
    eo: 'Ne plu montri ĉi tiun viziton',
    nl: 'Deze rondleiding niet meer tonen',
    el: 'Να μην εμφανιστεί ξανά η ξενάγηση',
  },
};

const FILES = fs.readdirSync(LOCALES_DIR).filter(f => f.endsWith('.json'));

for (const file of FILES) {
  const locale = file.replace('.json', '');
  const filePath = path.join(LOCALES_DIR, file);
  const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));

  let added = 0;
  for (const [key, translations] of Object.entries(KEYS)) {
    if (!data[key]) {
      data[key] = translations[locale] || translations['en'];
      added++;
    }
  }

  const sorted = {};
  for (const k of Object.keys(data).sort()) sorted[k] = data[k];
  fs.writeFileSync(filePath, JSON.stringify(sorted, null, 2) + '\n', 'utf8');
  console.log(`${file}: ${added} key(s) added (total: ${Object.keys(sorted).length})`);
}
