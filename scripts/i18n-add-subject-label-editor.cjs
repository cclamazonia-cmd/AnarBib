/* ===========================================================================
 * i18n-add-subject-label-editor.cjs
 * Éditeur de libellés multilingue (thésaurus v2 H-1). 9 clés × 10 locales.
 * Idempotent (sentinelle catalogacao.subjectGov.editTitle).
 * Session : Fédération — Communs & Entraide
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const PREFIX = 'catalogacao.subjectGov.';
const SENTINEL = PREFIX + 'editTitle';

const K = ['editTitle', 'editHint', 'editSearch', 'editPref', 'editAlt', 'editHidden', 'editSave', 'editSaved', 'editClose'];

const V = {
  fr: ['Éditer les libellés d’un sujet', 'Cherche un sujet, puis complète ou corrige les libellés par langue. Synonymes et variantes : séparés par des virgules.', 'Chercher un sujet à éditer…', 'Libellé', 'Synonymes', 'Variantes (recherche)', 'Enregistrer les libellés', 'Libellés enregistrés.', 'Fermer'],
  'pt-BR': ['Editar os rótulos de um assunto', 'Busca um assunto, depois completa ou corrige os rótulos por língua. Sinônimos e variantes: separados por vírgulas.', 'Buscar um assunto para editar…', 'Rótulo', 'Sinônimos', 'Variantes (busca)', 'Salvar os rótulos', 'Rótulos salvos.', 'Fechar'],
  es: ['Editar las etiquetas de una materia', 'Busca una materia, luego completa o corrige las etiquetas por idioma. Sinónimos y variantes: separados por comas.', 'Buscar una materia para editar…', 'Etiqueta', 'Sinónimos', 'Variantes (búsqueda)', 'Guardar las etiquetas', 'Etiquetas guardadas.', 'Cerrar'],
  en: ['Edit a subject’s labels', 'Search a subject, then fill or fix the labels per language. Synonyms and variants: comma-separated.', 'Search a subject to edit…', 'Label', 'Synonyms', 'Variants (search)', 'Save labels', 'Labels saved.', 'Close'],
  it: ['Modificare le etichette di un soggetto', 'Cerca un soggetto, poi completa o correggi le etichette per lingua. Sinonimi e varianti: separati da virgole.', 'Cerca un soggetto da modificare…', 'Etichetta', 'Sinonimi', 'Varianti (ricerca)', 'Salva le etichette', 'Etichette salvate.', 'Chiudi'],
  de: ['Bezeichnungen eines Sachthemas bearbeiten', 'Suche ein Sachthema, dann ergänze oder korrigiere die Bezeichnungen je Sprache. Synonyme und Varianten: durch Kommas getrennt.', 'Sachthema zum Bearbeiten suchen…', 'Bezeichnung', 'Synonyme', 'Varianten (Suche)', 'Bezeichnungen speichern', 'Bezeichnungen gespeichert.', 'Schließen'],
  ca: ['Editar les etiquetes d’una matèria', 'Cerca una matèria, després completa o corregeix les etiquetes per llengua. Sinònims i variants: separats per comes.', 'Cercar una matèria per editar…', 'Etiqueta', 'Sinònims', 'Variants (cerca)', 'Desar les etiquetes', 'Etiquetes desades.', 'Tancar'],
  eo: ['Redakti la etikedojn de temo', 'Serĉu temon, poste kompletigu aŭ korektu la etikedojn laŭ lingvo. Sinonimoj kaj variantoj: apartigitaj per komoj.', 'Serĉi temon por redakti…', 'Etikedo', 'Sinonimoj', 'Variantoj (serĉo)', 'Konservi la etikedojn', 'Etikedoj konservitaj.', 'Fermi'],
  nl: ['Labels van een onderwerp bewerken', 'Zoek een onderwerp, vul daarna de labels per taal aan of corrigeer ze. Synoniemen en varianten: door komma’s gescheiden.', 'Een onderwerp zoeken om te bewerken…', 'Label', 'Synoniemen', 'Varianten (zoeken)', 'Labels opslaan', 'Labels opgeslagen.', 'Sluiten'],
  el: ['Επεξεργασία ετικετών ενός θέματος', 'Αναζήτησε ένα θέμα, μετά συμπλήρωσε ή διόρθωσε τις ετικέτες ανά γλώσσα. Συνώνυμα και παραλλαγές: χωρισμένα με κόμματα.', 'Αναζήτηση θέματος για επεξεργασία…', 'Ετικέτα', 'Συνώνυμα', 'Παραλλαγές (αναζήτηση)', 'Αποθήκευση ετικετών', 'Οι ετικέτες αποθηκεύτηκαν.', 'Κλείσιμο'],
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
  console.log(loc + ': 9 clés label-editor (si absentes), JSON valide.');
}
console.log('\nTerminé.');
