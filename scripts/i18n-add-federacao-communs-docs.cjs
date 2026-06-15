/* ===========================================================================
 * i18n-add-federacao-communs-docs.cjs
 * Communs — 2 nouvelles catégories (guides, vademecums) + 3 docs
 * (gouvernance, manuel, cotation) : 8 clés × 10 locales.
 * Idempotent (sentinelle federacao.communs.cat.guides).
 * Session : Fédération — Communs & Entraide
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const PREFIX = 'federacao.communs.';
const SENTINEL = PREFIX + 'cat.guides';

// suffixes, dans l'ordre des valeurs V[loc]
const K = [
  'cat.guides', 'cat.vademecums',
  'doc.gouvernance.title', 'doc.gouvernance.desc',
  'doc.manuel.title', 'doc.manuel.desc',
  'doc.cotation.title', 'doc.cotation.desc',
];

const V = {
  fr: ['Guides', 'Mémentos', 'Guide de gouvernance', 'La logique politique des règles du réseau, à l’usage des coordinations.', 'Manuel d’utilisation', 'Prendre AnarBib en main, pas à pas.', 'Cotation & classification anarchiste', 'Une norme de cote et une grille Dewey revisitée — un exemple de catalogage situé.'],
  'pt-BR': ['Guias', 'Manuais práticos', 'Guia de governança', 'A lógica política das regras da rede, para quem coordena.', 'Manual de uso', 'Aprender a usar o AnarBib, passo a passo.', 'Cotação & classificação anarquista', 'Uma norma de cota e uma grade Dewey revisitada — um exemplo de catalogação situada.'],
  es: ['Guías', 'Manuales prácticos', 'Guía de gobernanza', 'La lógica política de las reglas de la red, para quienes coordinan.', 'Manual de uso', 'Aprender a usar AnarBib, paso a paso.', 'Signatura & clasificación anarquista', 'Una norma de signatura y una tabla Dewey revisada — un ejemplo de catalogación situada.'],
  en: ['Guides', 'Handbooks', 'Governance guide', 'The political logic of the network’s rules, for those who coordinate.', 'User manual', 'Getting started with AnarBib, step by step.', 'Shelfmarks & anarchist classification', 'A shelfmark standard and a reworked Dewey grid — one example of situated cataloging.'],
  it: ['Guide', 'Vademecum', 'Guida alla governance', 'La logica politica delle regole della rete, per chi coordina.', 'Manuale d’uso', 'Imparare a usare AnarBib, passo dopo passo.', 'Collocazione & classificazione anarchica', 'Una norma di collocazione e una griglia Dewey rivista — un esempio di catalogazione situata.'],
  de: ['Leitfäden', 'Praxisleitfäden', 'Governance-Leitfaden', 'Die politische Logik der Netzwerkregeln, für die Koordinierenden.', 'Benutzungshandbuch', 'AnarBib Schritt für Schritt kennenlernen.', 'Signatur & anarchistische Klassifikation', 'Eine Signaturnorm und ein überarbeitetes Dewey-Raster — ein Beispiel situierter Katalogisierung.'],
  ca: ['Guies', 'Manuals pràctics', 'Guia de governança', 'La lògica política de les regles de la xarxa, per a qui coordina.', 'Manual d’ús', 'Aprendre a fer servir AnarBib, pas a pas.', 'Signatura & classificació anarquista', 'Una norma de signatura i una graella Dewey revisada — un exemple de catalogació situada.'],
  eo: ['Gvidiloj', 'Manlibroj', 'Gvidilo pri governado', 'La politika logiko de la retaj reguloj, por la kunordigant-in-oj.', 'Uzmanlibro', 'Ekuzi AnarBib, paŝon post paŝo.', 'Bretsigno & anarkiisma klasifiko', 'Normo de bretsigno kaj reviziita Dewey-tabelo — ekzemplo de situita katalogado.'],
  nl: ['Gidsen', 'Handleidingen', 'Bestuursgids', 'De politieke logica achter de netwerkregels, voor wie coördineert.', 'Handleiding', 'AnarBib leren gebruiken, stap voor stap.', 'Plaatskenmerk & anarchistische classificatie', 'Een plaatskenmerknorm en een herwerkt Dewey-raster — een voorbeeld van gesitueerd catalogiseren.'],
  el: ['Οδηγοί', 'Εγχειρίδια', 'Οδηγός διακυβέρνησης', 'Η πολιτική λογική των κανόνων του δικτύου, για όσες και όσους συντονίζουν.', 'Εγχειρίδιο χρήσης', 'Πρώτα βήματα στο AnarBib, βήμα βήμα.', 'Ταξινομικά σύμβολα & αναρχική ταξινόμηση', 'Ένα πρότυπο ταξινομικού και ένας αναθεωρημένος πίνακας Dewey — ένα παράδειγμα τοποθετημένης καταλογογράφησης.'],
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
  console.log(loc + ': 8 clés communs-docs (si absentes), JSON valide.');
}
console.log('\nTerminé.');
