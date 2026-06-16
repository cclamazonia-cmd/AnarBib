/* ===========================================================================
 * i18n-add-communs-guide-indexar.cjs
 * Communs — vademecum « Indexer par sujet » (artisanat de l'indexation matière).
 * 2 clés × 10 locales. Idempotent (sentinelle federacao.communs.doc.indexarAssunto.title).
 * Session : Fédération — Communs & Entraide
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const PREFIX = 'federacao.communs.doc.indexarAssunto.';
const SENTINEL = PREFIX + 'title';

const K = ['title', 'desc'];

const V = {
  fr: ['Indexer par sujet', 'Choisir un sujet du thésaurus, proposer un terme, mots-clés libres — l’artisanat de l’indexation matière.'],
  'pt-BR': ['Indexar por assunto', 'Escolher um assunto do tesauro, propor um termo, palavras-chave livres — o artesanato da indexação por assunto.'],
  es: ['Indexar por materia', 'Elegir una materia del tesauro, proponer un término, palabras clave libres — el oficio de la indización por materia.'],
  en: ['Indexing by subject', 'Choosing a thesaurus subject, proposing a term, free keywords — the craft of subject indexing.'],
  it: ['Indicizzare per soggetto', 'Scegliere un soggetto del tesauro, proporre un termine, parole chiave libere — l’artigianato dell’indicizzazione per soggetto.'],
  de: ['Nach Sachthema erschließen', 'Ein Sachthema aus dem Thesaurus wählen, einen Begriff vorschlagen, freie Schlagwörter — das Handwerk der Sacherschließung.'],
  ca: ['Indexar per matèria', 'Triar una matèria del tesaurus, proposar un terme, paraules clau lliures — l’ofici de la indexació per matèria.'],
  eo: ['Indeksi laŭ temo', 'Elekti temon el la tezaŭro, proponi terminon, liberaj ŝlosilvortoj — la metio de la tema indeksado.'],
  nl: ['Indexeren op onderwerp', 'Een onderwerp uit de thesaurus kiezen, een term voorstellen, vrije trefwoorden — het ambacht van onderwerpsindexering.'],
  el: ['Ευρετηρίαση κατά θέμα', 'Επιλογή θέματος από τον θησαυρό, πρόταση όρου, ελεύθερες λέξεις-κλειδιά — η τέχνη της θεματικής ευρετηρίασης.'],
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
  console.log(loc + ': 2 clés guideIndexar (si absentes), JSON valide.');
}
console.log('\nTerminé.');
