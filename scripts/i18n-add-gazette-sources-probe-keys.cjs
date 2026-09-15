/* ===========================================================================
 * i18n-add-gazette-sources-probe-keys.cjs
 * GAZ-8 (15/09/2026) — les sources de la gazette se testent à la main depuis
 * l'Edge (bouton du panneau réseau). 3 clés × 10 locales.
 * Idempotent (sentinelle par clé), purement textuel (insertion avant le `}` final).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const KEYS = {
  'rede.gazeta.sources.probe': {
    'pt-BR': 'Testar as fontes agora', fr: 'Tester les sources maintenant', es: 'Probar las fuentes ahora',
    en: 'Test the sources now', it: 'Testare le fonti adesso', de: 'Quellen jetzt prüfen',
    ca: 'Provar les fonts ara', eo: 'Testi la fontojn nun', nl: 'Bronnen nu testen', el: 'Δοκιμή των πηγών τώρα',
  },
  'rede.gazeta.sources.probeHint': {
    'pt-BR': 'Mede a partir do servidor da gazeta, sem tocar nos números; resultado em menos de um minuto.',
    fr: 'Mesure depuis le serveur de la gazette, sans toucher aux numéros ; résultat sous une minute.',
    es: 'Mide desde el servidor de la gaceta, sin tocar los números; resultado en menos de un minuto.',
    en: 'Measured from the gazette server, without touching any issue; results within a minute.',
    it: 'Misura dal server della gazzetta, senza toccare i numeri; risultato entro un minuto.',
    de: 'Gemessen vom Gazette-Server aus, ohne eine Ausgabe anzurühren; Ergebnis innerhalb einer Minute.',
    ca: 'Mesura des del servidor de la gaseta, sense tocar els números; resultat en menys d’un minut.',
    eo: 'Mezuras el la servilo de la gazeto, ne tuŝante la numerojn; rezulto ene de minuto.',
    nl: 'Gemeten vanaf de server van de Gazette, zonder een nummer aan te raken; resultaat binnen een minuut.',
    el: 'Μέτρηση από τον διακομιστή της εφημερίδας, χωρίς να αγγίξει τεύχη· αποτέλεσμα μέσα σε ένα λεπτό.',
  },
  'rede.gazeta.sources.probeStarted': {
    'pt-BR': 'Teste lançado: os estados se atualizam dentro de um minuto.', fr: 'Test lancé : les statuts se rafraîchissent d’ici une minute.',
    es: 'Prueba lanzada: los estados se actualizan en menos de un minuto.', en: 'Test started: statuses refresh within a minute.',
    it: 'Test avviato: gli stati si aggiornano entro un minuto.', de: 'Prüfung gestartet: die Zustände aktualisieren sich innerhalb einer Minute.',
    ca: 'Prova llançada: els estats s’actualitzen en menys d’un minut.', eo: 'Testo lanĉita: la statoj ĝisdatiĝos ene de minuto.',
    nl: 'Test gestart: de statussen worden binnen een minuut vernieuwd.', el: 'Η δοκιμή ξεκίνησε: οι καταστάσεις ανανεώνονται μέσα σε ένα λεπτό.',
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
