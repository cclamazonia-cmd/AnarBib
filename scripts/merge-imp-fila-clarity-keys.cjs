/**
 * Ajoute les clés de lisibilité de la file de revue (colonnes humanisées
 * Correspondência/Decisão/Estado, labels match/decision, pagination) aux 10
 * locales. Additif textuel. Run : node scripts/merge-imp-fila-clarity-keys.cjs
 */
const fs = require('fs');
const path = require('path');
const DIR = path.resolve(__dirname, '../src/i18n/locales');
const FILES = ['pt-BR', 'fr', 'es', 'en', 'it', 'de', 'ca', 'eo', 'nl', 'el'];

// key -> { locale: value }
const K = {
  'importacoes.fila.col.match':    { 'pt-BR': 'Correspondência', fr: 'Correspondance', es: 'Correspondencia', en: 'Match', it: 'Corrispondenza', de: 'Treffer', ca: 'Correspondència', eo: 'Kongruo', nl: 'Overeenkomst', el: 'Αντιστοίχιση' },
  'importacoes.fila.col.decision': { 'pt-BR': 'Decisão', fr: 'Décision', es: 'Decisión', en: 'Decision', it: 'Decisione', de: 'Entscheidung', ca: 'Decisió', eo: 'Decido', nl: 'Beslissing', el: 'Απόφαση' },
  'importacoes.fila.col.state':    { 'pt-BR': 'Estado', fr: 'État', es: 'Estado', en: 'State', it: 'Stato', de: 'Status', ca: 'Estat', eo: 'Stato', nl: 'Status', el: 'Κατάσταση' },
  'importacoes.fila.match.new_record':        { 'pt-BR': 'Novidade', fr: 'Nouveauté', es: 'Novedad', en: 'New', it: 'Novità', de: 'Neu', ca: 'Novetat', eo: 'Novaĵo', nl: 'Nieuw', el: 'Νέο' },
  'importacoes.fila.match.possible_duplicate':{ 'pt-BR': 'Possível duplicado', fr: 'Doublon possible', es: 'Posible duplicado', en: 'Possible duplicate', it: 'Possibile duplicato', de: 'Mögliches Duplikat', ca: 'Possible duplicat', eo: 'Ebla duplikato', nl: 'Mogelijk duplicaat', el: 'Πιθανό διπλότυπο' },
  'importacoes.fila.match.matched_book':      { 'pt-BR': 'Já no catálogo', fr: 'Déjà au catalogue', es: 'Ya en el catálogo', en: 'Already in catalog', it: 'Già in catalogo', de: 'Schon im Katalog', ca: 'Ja al catàleg', eo: 'Jam en katalogo', nl: 'Al in catalogus', el: 'Ήδη στον κατάλογο' },
  'importacoes.fila.match.matched_draft':     { 'pt-BR': 'Já em rascunho', fr: 'Déjà en brouillon', es: 'Ya en borrador', en: 'Already a draft', it: 'Già in bozza', de: 'Schon Entwurf', ca: 'Ja en esborrany', eo: 'Jam malneto', nl: 'Al een concept', el: 'Ήδη προσχέδιο' },
  'importacoes.fila.match.manual_decision':   { 'pt-BR': 'Decisão manual', fr: 'Décision manuelle', es: 'Decisión manual', en: 'Manual decision', it: 'Decisione manuale', de: 'Manuelle Entscheidung', ca: 'Decisió manual', eo: 'Mana decido', nl: 'Handmatige beslissing', el: 'Χειροκίνητη απόφαση' },
  'importacoes.fila.match.unreviewed':        { 'pt-BR': 'Não avaliado', fr: 'Non évalué', es: 'Sin evaluar', en: 'Unreviewed', it: 'Non valutato', de: 'Ungeprüft', ca: 'Sense revisar', eo: 'Nekontrolita', nl: 'Niet beoordeeld', el: 'Μη ελεγμένο' },
  'importacoes.fila.decision.accept_new':       { 'pt-BR': 'Aceite (nova)', fr: 'Accepté (nouveau)', es: 'Aceptado (nuevo)', en: 'Accepted (new)', it: 'Accettato (nuovo)', de: 'Übernommen (neu)', ca: 'Acceptat (nou)', eo: 'Akceptita (nova)', nl: 'Geaccepteerd (nieuw)', el: 'Αποδεκτό (νέο)' },
  'importacoes.fila.decision.accept_duplicate': { 'pt-BR': 'Aceite (vínculo)', fr: 'Accepté (rattaché)', es: 'Aceptado (vinculado)', en: 'Accepted (linked)', it: 'Accettato (collegato)', de: 'Übernommen (verknüpft)', ca: 'Acceptat (vinculat)', eo: 'Akceptita (ligita)', nl: 'Geaccepteerd (gekoppeld)', el: 'Αποδεκτό (συνδεδεμένο)' },
  'importacoes.fila.decision.reject':           { 'pt-BR': 'Rejeitada', fr: 'Rejeté', es: 'Rechazado', en: 'Rejected', it: 'Rifiutato', de: 'Abgelehnt', ca: 'Rebutjat', eo: 'Malakceptita', nl: 'Afgewezen', el: 'Απορρίφθηκε' },
  'importacoes.fila.decision.pending':          { 'pt-BR': 'Pendente', fr: 'En attente', es: 'Pendiente', en: 'Pending', it: 'In attesa', de: 'Ausstehend', ca: 'Pendent', eo: 'Atendanta', nl: 'In afwachting', el: 'Σε εκκρεμότητα' },
  'importacoes.fila.draftCreated': { 'pt-BR': 'Rascunho criado', fr: 'Brouillon créé', es: 'Borrador creado', en: 'Draft created', it: 'Bozza creata', de: 'Entwurf erstellt', ca: 'Esborrany creat', eo: 'Malneto kreita', nl: 'Concept aangemaakt', el: 'Δημιουργήθηκε προσχέδιο' },
  'importacoes.fila.loadMore':  { 'pt-BR': 'Carregar mais 50', fr: 'Charger 50 de plus', es: 'Cargar 50 más', en: 'Load 50 more', it: 'Carica altri 50', de: '50 weitere laden', ca: 'Carrega’n 50 més', eo: 'Ŝargi pliajn 50', nl: '50 meer laden', el: 'Φόρτωση 50 ακόμη' },
  'importacoes.fila.showing':   { 'pt-BR': 'Mostrando {shown} de {total}.', fr: 'Affichage de {shown} sur {total}.', es: 'Mostrando {shown} de {total}.', en: 'Showing {shown} of {total}.', it: 'Visualizzati {shown} di {total}.', de: '{shown} von {total} angezeigt.', ca: 'Mostrant {shown} de {total}.', eo: 'Montrante {shown} el {total}.', nl: '{shown} van {total} weergegeven.', el: 'Εμφάνιση {shown} από {total}.' },
  'importacoes.fila.showingAll':{ 'pt-BR': '{total} linhas.', fr: '{total} lignes.', es: '{total} líneas.', en: '{total} rows.', it: '{total} righe.', de: '{total} Zeilen.', ca: '{total} línies.', eo: '{total} linioj.', nl: '{total} rijen.', el: '{total} γραμμές.' },
};

let total = 0;
for (const loc of FILES) {
  const p = path.join(DIR, loc + '.json');
  let txt = fs.readFileSync(p, 'utf8');
  const toAdd = Object.entries(K).filter(([k]) => !txt.includes('"' + k + '"')).map(([k, v]) => [k, v[loc]]);
  if (toAdd.length) {
    const ins = toAdd.map(([k, v]) => '  ' + JSON.stringify(k) + ': ' + JSON.stringify(v)).join(',\n');
    const i = txt.lastIndexOf('}');
    txt = txt.slice(0, i).replace(/\s*,?\s*$/, '') + ',\n' + ins + '\n' + txt.slice(i);
    fs.writeFileSync(p, txt, 'utf8');
  }
  JSON.parse(fs.readFileSync(p, 'utf8'));
  console.log(loc.padEnd(6), '+' + toAdd.length);
  total += toAdd.length;
}
console.log('\nTotal :', total);
