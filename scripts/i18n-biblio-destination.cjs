/* ===========================================================================
 * i18n-lib.cjs
 * File et corbeille du catalogage : dire a quelle bibliotheque appartient le
 * travail qu'on s'apprete a toucher, et distinguer ce qui est ENREGISTRE de ce
 * qui est seulement DEDUIT.
 * 2 cles x 10 locales. Idempotent (sentinelle catalogacao.queue.libraryRecorded).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'catalogacao.queue.libraryRecorded';
const K = ['catalogacao.queue.libraryRecorded', 'catalogacao.queue.libraryInferred'];

const V = {
  fr: [
    'Bibliothèque de destination, enregistrée sur le brouillon.',
    'Bibliothèque de destination déduite de l’adhésion de la personne qui a catalogué : rien ne rattache formellement ce brouillon à cette bibliothèque.',
  ],
  'pt-BR': [
    'Biblioteca de destino, registada no rascunho.',
    'Biblioteca de destino deduzida do vínculo de quem catalogou: nada liga formalmente este rascunho a essa biblioteca.',
  ],
  es: [
    'Biblioteca de destino, registrada en el borrador.',
    'Biblioteca de destino deducida de la afiliación de quien catalogó: nada vincula formalmente este borrador a esa biblioteca.',
  ],
  en: [
    'Destination library, recorded on the draft.',
    'Destination library inferred from the membership of whoever catalogued it: nothing formally ties this draft to that library.',
  ],
  it: [
    'Biblioteca di destinazione, registrata sulla bozza.',
    'Biblioteca di destinazione dedotta dall’affiliazione di chi ha catalogato: nulla lega formalmente questa bozza a quella biblioteca.',
  ],
  de: [
    'Zielbibliothek, im Entwurf hinterlegt.',
    'Zielbibliothek aus der Mitgliedschaft der katalogisierenden Person abgeleitet: nichts bindet diesen Entwurf formal an diese Bibliothek.',
  ],
  ca: [
    'Biblioteca de destinació, registrada a l’esborrany.',
    'Biblioteca de destinació deduïda de l’afiliació de qui ha catalogat: res no lliga formalment aquest esborrany a aquesta biblioteca.',
  ],
  eo: [
    'Celbiblioteko, registrita en la malneto.',
    'Celbiblioteko deduktita el la aliĝo de tiu kiu katalogis: nenio formale ligas ĉi tiun malneton al tiu biblioteko.',
  ],
  nl: [
    'Doelbibliotheek, vastgelegd op het concept.',
    'Doelbibliotheek afgeleid uit het lidmaatschap van wie catalogiseerde: niets bindt dit concept formeel aan die bibliotheek.',
  ],
  el: [
    'Βιβλιοθήκη προορισμού, καταγεγραμμένη στο πρόχειρο.',
    'Βιβλιοθήκη προορισμού που συνάγεται από τη συμμετοχή όποιου καταλογογράφησε: τίποτα δεν συνδέει τυπικά αυτό το πρόχειρο με εκείνη τη βιβλιοθήκη.',
  ],
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes('"' + SENTINEL + '"')) {
    const vals = V[loc];
    if (!vals || vals.length !== K.length) throw new Error('Valeurs manquantes: ' + loc);
    const entries = K.map((k, i) => '  ' + JSON.stringify(k) + ': ' + JSON.stringify(vals[i]));
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entries.join(',\n') + '\n' + content.slice(marker);
    if (!content.endsWith('\n')) content += '\n';
    fs.writeFileSync(file, content, 'utf8');
  }
  const parsed = JSON.parse(fs.readFileSync(file, 'utf8'));
  for (const k of K) if (parsed[k] === undefined) throw new Error('cle absente: ' + loc + ' / ' + k);
  console.log(loc + ': 2 cles bibliotheque (si absentes), JSON valide.');
}
console.log('\nTermine.');
