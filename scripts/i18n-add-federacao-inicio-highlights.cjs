/* ===========================================================================
 * i18n-add-federacao-inicio-highlights.cjs
 * Onglet d'accueil Fédération : met en valeur Communs + Entraide (boutons
 * « annuaire ») au même rang que Carte/Gazette. 6 clés × 10 locales.
 * Idempotent (sentinelle federacao.inicio.communs).
 * Session : Fédération — Communs & Entraide
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const PREFIX = 'federacao.inicio.';
const SENTINEL = PREFIX + 'communs';

const K = ['communs', 'communs.desc', 'toCommuns', 'entraide', 'entraide.desc', 'toEntraide'];

const V = {
  fr: ['Les Communs', 'Chartes, guides et vade-mecum du réseau — vivants, et lisibles ici même.', 'Ouvrir les communs', 'L’Entraide', 'Besoin d’un coup de main, ou envie d’en prêter un ? C’est ici.', 'Aller à l’entraide'],
  'pt-BR': ['Os Comuns', 'Cartas, guias e vade-mécuns da rede — vivos, e legíveis aqui mesmo.', 'Abrir os comuns', 'A Entreajuda', 'Precisa de uma mão, ou quer emprestar a sua? É aqui.', 'Ir para a entreajuda'],
  es: ['Los Comunes', 'Cartas, guías y vademécums de la red — vivos, y legibles aquí mismo.', 'Abrir los comunes', 'La Ayuda Mutua', '¿Necesitas una mano, o quieres prestar la tuya? Es aquí.', 'Ir a la ayuda mutua'],
  en: ['The Commons', 'The network’s charters, guides and handbooks — alive, and readable right here.', 'Open the commons', 'Mutual Aid', 'Need a hand, or want to lend one? It’s here.', 'Go to mutual aid'],
  it: ['I Beni Comuni', 'Carte, guide e vademecum della rete — vivi, e leggibili proprio qui.', 'Aprire i beni comuni', 'Il Mutuo Aiuto', 'Ti serve una mano, o vuoi offrirne una? È qui.', 'Vai al mutuo aiuto'],
  de: ['Die Commons', 'Chartas, Leitfäden und Handbücher des Netzwerks — lebendig und gleich hier lesbar.', 'Commons öffnen', 'Die Gegenseitige Hilfe', 'Brauchst du Hilfe oder möchtest du welche anbieten? Hier entlang.', 'Zur gegenseitigen Hilfe'],
  ca: ['Els Comuns', 'Cartes, guies i vademècums de la xarxa — vius, i llegibles aquí mateix.', 'Obrir els comuns', 'El Suport Mutu', 'Necessites un cop de mà, o en vols oferir un? És aquí.', 'Anar al suport mutu'],
  eo: ['La Komunaĵoj', 'Ĉartoj, gvidiloj kaj manlibroj de la reto — vivaj, kaj legeblaj ĝuste ĉi tie.', 'Malfermi la komunaĵojn', 'La Reciproka Helpo', 'Ĉu vi bezonas helpon, aŭ volas oferti ĝin? Ĉi tie.', 'Iri al la reciproka helpo'],
  nl: ['De Commons', 'Handvesten, gidsen en handleidingen van het netwerk — levend, en hier meteen leesbaar.', 'Commons openen', 'De Onderlinge Hulp', 'Hulp nodig, of wil je hulp bieden? Hier.', 'Naar de onderlinge hulp'],
  el: ['Τα Κοινά', 'Χάρτες, οδηγοί και εγχειρίδια του δικτύου — ζωντανά, και αναγνώσιμα εδώ.', 'Άνοιγμα των κοινών', 'Η Αλληλοβοήθεια', 'Χρειάζεσαι ένα χέρι, ή θες να προσφέρεις ένα; Εδώ είναι.', 'Στην αλληλοβοήθεια'],
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes('"' + SENTINEL + '"')) {
    const vals = V[loc];
    if (!vals || vals.length !== K.length) throw new Error('Valeurs manquantes: ' + loc);
    const entries = K.map((k, i) => '  ' + JSON.stringify(PREFIX + k) + ': ' + JSON.stringify(vals[i]));
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entries.join(',\n') + '\n' + content.slice(marker);
    if (!content.endsWith('\n')) content += '\n';
    fs.writeFileSync(file, content, 'utf8');
  }
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ': 6 clés inicio-highlights (si absentes), JSON valide.');
}
console.log('\nTerminé.');
