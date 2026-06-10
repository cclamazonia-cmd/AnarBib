/**
 * Ajoute les clés importacoes.wizard.* (assistant Novo import, IMP-8) aux 10 locales.
 * Méthode SÛRE (doctrine i18n) : insertion TEXTUELLE additive avant le } final,
 * idempotente, sans re-sérialisation JSON. Préserve toutes les clés existantes.
 * Run : node scripts/merge-imp-wizard-keys.cjs
 * Session : Wizard d'import (IMP-8) — incrément 1
 */
const fs = require('fs');
const path = require('path');

const DIR = path.resolve(__dirname, '../src/i18n/locales');
const FILES = {
  'pt-BR': 'pt-BR.json', fr: 'fr.json', es: 'es.json', en: 'en.json', it: 'it.json',
  de: 'de.json', ca: 'ca.json', eo: 'eo.json', nl: 'nl.json', el: 'el.json',
};

const K = (title, subtitle, launch, stCircuit, stSource, stPreview, stPromote, cMig, cArq, cFon, back, next, wip) => ({
  'importacoes.wizard.title': title,
  'importacoes.wizard.subtitle': subtitle,
  'importacoes.wizard.launch': launch,
  'importacoes.wizard.step.circuit': stCircuit,
  'importacoes.wizard.step.source': stSource,
  'importacoes.wizard.step.preview': stPreview,
  'importacoes.wizard.step.promote': stPromote,
  'importacoes.wizard.circuit.migracao': cMig,
  'importacoes.wizard.circuit.arquivo': cArq,
  'importacoes.wizard.circuit.fontes': cFon,
  'importacoes.wizard.back': back,
  'importacoes.wizard.next': next,
  'importacoes.wizard.wip': wip,
});

const KEYS = {
  'pt-BR': K('Novo import', 'Assistente guiado de importação, passo a passo.', 'Novo import', 'Circuito', 'Fonte', 'Pré-visualização', 'Promoção', 'Migração de sistema', 'Importação de arquivo', 'Fontes externas', 'Voltar', 'Próximo', 'Etapa em construção (em breve).'),
  fr: K('Nouvel import', 'Assistant d\'import guidé, étape par étape.', 'Nouvel import', 'Circuit', 'Source', 'Aperçu', 'Promotion', 'Migration de système', 'Import de fichier', 'Sources externes', 'Retour', 'Suivant', 'Étape en construction (bientôt).'),
  es: K('Nueva importación', 'Asistente de importación guiado, paso a paso.', 'Nueva importación', 'Circuito', 'Fuente', 'Vista previa', 'Promoción', 'Migración de sistema', 'Importación de archivo', 'Fuentes externas', 'Atrás', 'Siguiente', 'Etapa en construcción (próximamente).'),
  en: K('New import', 'Guided step-by-step import assistant.', 'New import', 'Circuit', 'Source', 'Preview', 'Promotion', 'System migration', 'File import', 'External sources', 'Back', 'Next', 'Step under construction (coming soon).'),
  it: K('Nuovo import', 'Assistente di importazione guidato, passo dopo passo.', 'Nuovo import', 'Circuito', 'Fonte', 'Anteprima', 'Promozione', 'Migrazione di sistema', 'Importazione di file', 'Fonti esterne', 'Indietro', 'Avanti', 'Fase in costruzione (prossimamente).'),
  de: K('Neuer Import', 'Geführter Import-Assistent, Schritt für Schritt.', 'Neuer Import', 'Importweg', 'Quelle', 'Vorschau', 'Übernahme', 'Systemmigration', 'Datei-Import', 'Externe Quellen', 'Zurück', 'Weiter', 'Schritt in Arbeit (bald verfügbar).'),
  ca: K('Nova importació', 'Assistent d\'importació guiat, pas a pas.', 'Nova importació', 'Circuit', 'Font', 'Vista prèvia', 'Promoció', 'Migració de sistema', 'Importació de fitxer', 'Fonts externes', 'Enrere', 'Següent', 'Etapa en construcció (properament).'),
  eo: K('Nova enporto', 'Gvidata enporta asistanto, paŝon post paŝo.', 'Nova enporto', 'Vojo', 'Fonto', 'Antaŭrigardo', 'Promocio', 'Sistema migrado', 'Dosiera enporto', 'Eksteraj fontoj', 'Reen', 'Sekva', 'Paŝo en konstruado (baldaŭ).'),
  nl: K('Nieuwe import', 'Begeleide import-assistent, stap voor stap.', 'Nieuwe import', 'Traject', 'Bron', 'Voorbeeld', 'Promotie', 'Systeemmigratie', 'Bestandsimport', 'Externe bronnen', 'Terug', 'Volgende', 'Stap in aanbouw (binnenkort).'),
  el: K('Νέα εισαγωγή', 'Καθοδηγούμενος βοηθός εισαγωγής, βήμα προς βήμα.', 'Νέα εισαγωγή', 'Διαδρομή', 'Πηγή', 'Προεπισκόπηση', 'Προαγωγή', 'Μετεγκατάσταση συστήματος', 'Εισαγωγή αρχείου', 'Εξωτερικές πηγές', 'Πίσω', 'Επόμενο', 'Βήμα υπό κατασκευή (σύντομα).'),
};

let total = 0;
for (const [loc, file] of Object.entries(FILES)) {
  const p = path.join(DIR, file);
  let txt = fs.readFileSync(p, 'utf8');
  const toAdd = Object.entries(KEYS[loc]).filter(([k]) => !txt.includes('"' + k + '"'));
  if (toAdd.length) {
    const ins = toAdd.map(([k, v]) => '  ' + JSON.stringify(k) + ': ' + JSON.stringify(v)).join(',\n');
    const i = txt.lastIndexOf('}');
    const head = txt.slice(0, i).replace(/\s*,?\s*$/, '');
    txt = head + ',\n' + ins + '\n' + txt.slice(i);
    fs.writeFileSync(p, txt, 'utf8');
  }
  JSON.parse(fs.readFileSync(p, 'utf8')); // validation stricte
  console.log(loc.padEnd(6), '+' + toAdd.length);
  total += toAdd.length;
}
console.log('\nTerminé. Total clés ajoutées :', total);
