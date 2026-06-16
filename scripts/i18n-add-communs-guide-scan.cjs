/* ===========================================================================
 * i18n-add-communs-guide-scan.cjs
 * Communs — vademecum « Guide scan & QR » (carte, ISBN, récolement).
 * 2 clés × 10 locales. Idempotent (sentinelle federacao.communs.doc.guideScan.title).
 * Session : Fédération — Communs & Entraide
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const PREFIX = 'federacao.communs.doc.guideScan.';
const SENTINEL = PREFIX + 'title';

const K = ['title', 'desc'];

const V = {
  fr: ['Scan & QR — carte, ISBN, récolement', 'Utiliser la caméra pour identifier une carte, saisir un ISBN ou faire le récolement — décodage 100 % local.'],
  'pt-BR': ['Scan & QR — carteirinha, ISBN, acervo', 'Usar a câmera para identificar uma carteirinha, puxar um ISBN ou conferir o acervo — decodificação 100 % local.'],
  es: ['Escaneo & QR — carné, ISBN, recuento', 'Usar la cámara para identificar un carné, capturar un ISBN o hacer el recuento — decodificación 100 % local.'],
  en: ['Scan & QR — card, ISBN, stocktake', 'Use the camera to identify a card, capture an ISBN, or do stocktaking — 100 % local decoding.'],
  it: ['Scan & QR — tessera, ISBN, inventario', 'Usare la fotocamera per identificare una tessera, acquisire un ISBN o fare l’inventario — decodifica 100 % locale.'],
  de: ['Scan & QR — Ausweis, ISBN, Bestandskontrolle', 'Mit der Kamera einen Ausweis erkennen, eine ISBN erfassen oder die Bestandskontrolle machen — 100 % lokale Dekodierung.'],
  ca: ['Escaneig & QR — carnet, ISBN, recompte', 'Fer servir la càmera per identificar un carnet, capturar un ISBN o fer el recompte — descodificació 100 % local.'],
  eo: ['Skanado & QR — karto, ISBN, stokkontrolo', 'Uzi la kameraon por identigi karton, kapti ISBN-on aŭ fari stokkontrolon — dekodado 100 % loka.'],
  nl: ['Scan & QR — pas, ISBN, inventarisatie', 'De camera gebruiken om een pas te herkennen, een ISBN vast te leggen of de inventarisatie te doen — 100 % lokale decodering.'],
  el: ['Σάρωση & QR — κάρτα, ISBN, απογραφή', 'Χρήση της κάμερας για αναγνώριση κάρτας, καταχώριση ISBN ή απογραφή — αποκωδικοποίηση 100 % τοπική.'],
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
  console.log(loc + ': 2 clés guideScan (si absentes), JSON valide.');
}
console.log('\nTerminé.');
