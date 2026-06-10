/**
 * Ajoute/MAJ les clés dédiées importacoes.export.lote.* dans les 10 locales.
 * Méthode SÛRE (doctrine i18n) : édition TEXTUELLE, pas de re-sérialisation JSON.
 *   - desc : remplacement de valeur ciblé par clé (regex), quelle que soit la langue.
 *   - format/download/exporting/success/error : insertion avant le } final si absent.
 * Idempotent. Préserve toutes les clés existantes (dont celles d'autres sessions).
 * Run : node scripts/merge-imp-export-lote-keys.cjs
 * Session : Lot 5 — Export de lote (i18n)
 */
const fs = require('fs');
const path = require('path');

const DIR = path.resolve(__dirname, '../src/i18n/locales');
const FILES = {
  'pt-BR': 'pt-BR.json', fr: 'fr.json', es: 'es.json', en: 'en.json', it: 'it.json',
  de: 'de.json', ca: 'ca.json', eo: 'eo.json', nl: 'nl.json', el: 'el.json',
};
const DESC = 'importacoes.export.lote.desc';

const KEYS = {
  'pt-BR': {
    'importacoes.export.lote.desc': 'Exportar todo o catálogo da biblioteca em formato normalizado (CSV, MARCXML, JSON), para backup, migração ou intercâmbio entre bibliotecas.',
    'importacoes.export.lote.format': 'Formato de exportação',
    'importacoes.export.lote.download': 'Exportar catálogo',
    'importacoes.export.lote.exporting': 'Gerando o arquivo…',
    'importacoes.export.lote.success': 'Pronto! O download começou.',
    'importacoes.export.lote.error': 'Erro ao exportar: {message}',
  },
  fr: {
    'importacoes.export.lote.desc': 'Exporter tout le catalogue de la bibliothèque dans un format normalisé (CSV, MARCXML, JSON), pour la sauvegarde, la migration ou l\'échange entre bibliothèques.',
    'importacoes.export.lote.format': 'Format d\'export',
    'importacoes.export.lote.download': 'Exporter le catalogue',
    'importacoes.export.lote.exporting': 'Génération du fichier…',
    'importacoes.export.lote.success': 'C\'est prêt ! Le téléchargement a commencé.',
    'importacoes.export.lote.error': 'Erreur à l\'export : {message}',
  },
  es: {
    'importacoes.export.lote.desc': 'Exportar todo el catálogo de la biblioteca en formato normalizado (CSV, MARCXML, JSON), para copia de seguridad, migración o intercambio entre bibliotecas.',
    'importacoes.export.lote.format': 'Formato de exportación',
    'importacoes.export.lote.download': 'Exportar catálogo',
    'importacoes.export.lote.exporting': 'Generando el archivo…',
    'importacoes.export.lote.success': '¡Listo! La descarga comenzó.',
    'importacoes.export.lote.error': 'Error al exportar: {message}',
  },
  en: {
    'importacoes.export.lote.desc': 'Export the library\'s full catalog in a normalized format (CSV, MARCXML, JSON), for backup, migration or exchange between libraries.',
    'importacoes.export.lote.format': 'Export format',
    'importacoes.export.lote.download': 'Export catalog',
    'importacoes.export.lote.exporting': 'Generating the file…',
    'importacoes.export.lote.success': 'Done! The download has started.',
    'importacoes.export.lote.error': 'Export error: {message}',
  },
  it: {
    'importacoes.export.lote.desc': 'Esportare l\'intero catalogo della biblioteca in un formato normalizzato (CSV, MARCXML, JSON), per backup, migrazione o scambio tra biblioteche.',
    'importacoes.export.lote.format': 'Formato di esportazione',
    'importacoes.export.lote.download': 'Esporta catalogo',
    'importacoes.export.lote.exporting': 'Generazione del file…',
    'importacoes.export.lote.success': 'Fatto! Il download è iniziato.',
    'importacoes.export.lote.error': 'Errore durante l\'esportazione: {message}',
  },
  de: {
    'importacoes.export.lote.desc': 'Den gesamten Katalog der Bibliothek in einem normalisierten Format (CSV, MARCXML, JSON) exportieren — für Backup, Migration oder Austausch zwischen Bibliotheken.',
    'importacoes.export.lote.format': 'Exportformat',
    'importacoes.export.lote.download': 'Katalog exportieren',
    'importacoes.export.lote.exporting': 'Datei wird erstellt…',
    'importacoes.export.lote.success': 'Fertig! Der Download wurde gestartet.',
    'importacoes.export.lote.error': 'Fehler beim Export: {message}',
  },
  ca: {
    'importacoes.export.lote.desc': 'Exportar tot el catàleg de la biblioteca en un format normalitzat (CSV, MARCXML, JSON), per a còpia de seguretat, migració o intercanvi entre biblioteques.',
    'importacoes.export.lote.format': 'Format d\'exportació',
    'importacoes.export.lote.download': 'Exporta el catàleg',
    'importacoes.export.lote.exporting': 'S\'està generant el fitxer…',
    'importacoes.export.lote.success': 'Fet! La baixada ha començat.',
    'importacoes.export.lote.error': 'Error en exportar: {message}',
  },
  eo: {
    'importacoes.export.lote.desc': 'Eksporti la tutan katalogon de la biblioteko en normigita formato (CSV, MARCXML, JSON), por sekurkopio, migrado aŭ interŝanĝo inter bibliotekoj.',
    'importacoes.export.lote.format': 'Eksporta formato',
    'importacoes.export.lote.download': 'Eksporti katalogon',
    'importacoes.export.lote.exporting': 'Generado de la dosiero…',
    'importacoes.export.lote.success': 'Preta! La elŝuto komenciĝis.',
    'importacoes.export.lote.error': 'Eraro dum eksporto: {message}',
  },
  nl: {
    'importacoes.export.lote.desc': 'Exporteer de volledige catalogus van de bibliotheek in een genormaliseerd formaat (CSV, MARCXML, JSON), voor back-up, migratie of uitwisseling tussen bibliotheken.',
    'importacoes.export.lote.format': 'Exportformaat',
    'importacoes.export.lote.download': 'Catalogus exporteren',
    'importacoes.export.lote.exporting': 'Bestand wordt gegenereerd…',
    'importacoes.export.lote.success': 'Klaar! De download is gestart.',
    'importacoes.export.lote.error': 'Fout bij exporteren: {message}',
  },
  el: {
    'importacoes.export.lote.desc': 'Εξαγωγή ολόκληρου του καταλόγου της βιβλιοθήκης σε τυποποιημένη μορφή (CSV, MARCXML, JSON), για αντίγραφο ασφαλείας, μετεγκατάσταση ή ανταλλαγή μεταξύ βιβλιοθηκών.',
    'importacoes.export.lote.format': 'Μορφή εξαγωγής',
    'importacoes.export.lote.download': 'Εξαγωγή καταλόγου',
    'importacoes.export.lote.exporting': 'Δημιουργία του αρχείου…',
    'importacoes.export.lote.success': 'Έτοιμο! Η λήψη ξεκίνησε.',
    'importacoes.export.lote.error': 'Σφάλμα κατά την εξαγωγή: {message}',
  },
};

function escKey(k) { return k.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }

let total = 0;
for (const [loc, file] of Object.entries(FILES)) {
  const p = path.join(DIR, file);
  let txt = fs.readFileSync(p, 'utf8');
  const keys = KEYS[loc];

  // 1) MAJ de la valeur de desc (remplacement ciblé par clé, toute langue).
  const descRe = new RegExp('("' + escKey(DESC) + '":\\s*)"(?:[^"\\\\]|\\\\.)*"');
  if (descRe.test(txt)) {
    txt = txt.replace(descRe, (_m, p1) => p1 + JSON.stringify(keys[DESC]));
  }

  // 2) Ajout des autres clés absentes, juste avant le } final.
  const toAdd = Object.entries(keys).filter(([k]) => k !== DESC && !txt.includes('"' + k + '"'));
  if (toAdd.length) {
    const ins = toAdd.map(([k, v]) => '  ' + JSON.stringify(k) + ': ' + JSON.stringify(v)).join(',\n');
    const i = txt.lastIndexOf('}');
    const head = txt.slice(0, i).replace(/\s*,?\s*$/, '');
    const tail = txt.slice(i);
    txt = head + ',\n' + ins + '\n' + tail;
  }

  fs.writeFileSync(p, txt, 'utf8');
  JSON.parse(fs.readFileSync(p, 'utf8')); // validation stricte
  console.log(loc.padEnd(6), '+' + toAdd.length, 'clé(s) ajoutée(s), desc MAJ');
  total += toAdd.length;
}
console.log('\nTerminé. Total clés ajoutées :', total, '(desc mise à jour dans les 10).');
