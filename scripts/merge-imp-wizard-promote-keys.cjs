/**
 * Ajoute les clés importacoes.wizard.preview.* / .promote.* (étapes 3-4 du wizard,
 * IMP-8 inc.3) aux 10 locales. Méthode SÛRE : insertion TEXTUELLE additive.
 * Run : node scripts/merge-imp-wizard-promote-keys.cjs
 */
const fs = require('fs');
const path = require('path');
const DIR = path.resolve(__dirname, '../src/i18n/locales');
const FILES = { 'pt-BR': 'pt-BR.json', fr: 'fr.json', es: 'es.json', en: 'en.json', it: 'it.json', de: 'de.json', ca: 'ca.json', eo: 'eo.json', nl: 'nl.json', el: 'el.json' };

const K = (loading, empty, summary, btn, promoting, done, viewDrafts, finish) => ({
  'importacoes.wizard.preview.loading': loading,
  'importacoes.wizard.preview.empty': empty,
  'importacoes.wizard.preview.summary': summary,
  'importacoes.wizard.promote.button': btn,
  'importacoes.wizard.promote.promoting': promoting,
  'importacoes.wizard.promote.done': done,
  'importacoes.wizard.promote.viewDrafts': viewDrafts,
  'importacoes.wizard.promote.finish': finish,
});

const KEYS = {
  'pt-BR': K('Carregando…', 'Nenhuma linha para importar.', '{n} notícia(s) pronta(s) para promoção.', 'Promover para os rascunhos', 'Promovendo…', 'Import concluído! {n} rascunho(s) criado(s).', 'Ver os rascunhos (Catalogação)', 'Concluir'),
  fr: K('Chargement…', 'Aucune ligne à importer.', '{n} notice(s) prête(s) à être promue(s).', 'Promouvoir vers les brouillons', 'Promotion en cours…', 'Import terminé ! {n} brouillon(s) créé(s).', 'Voir les brouillons (Catalogage)', 'Terminer'),
  es: K('Cargando…', 'Ninguna línea para importar.', '{n} ficha(s) lista(s) para promoción.', 'Promover a los borradores', 'Promoviendo…', '¡Importación completada! {n} borrador(es) creado(s).', 'Ver los borradores (Catalogación)', 'Finalizar'),
  en: K('Loading…', 'No row to import.', '{n} record(s) ready for promotion.', 'Promote to drafts', 'Promoting…', 'Import complete! {n} draft(s) created.', 'View drafts (Cataloging)', 'Finish'),
  it: K('Caricamento…', 'Nessuna riga da importare.', '{n} scheda/e pronta/e per la promozione.', 'Promuovi alle bozze', 'Promozione…', 'Importazione completata! {n} bozza/e creata/e.', 'Vedi le bozze (Catalogazione)', 'Concludi'),
  de: K('Wird geladen…', 'Keine Zeile zum Importieren.', '{n} Datensatz/Datensätze bereit zur Übernahme.', 'In Entwürfe übernehmen', 'Übernahme läuft…', 'Import abgeschlossen! {n} Entwurf/Entwürfe erstellt.', 'Entwürfe ansehen (Katalogisierung)', 'Abschließen'),
  ca: K('S\'està carregant…', 'Cap línia per importar.', '{n} fitxa/fitxes a punt per a la promoció.', 'Promou als esborranys', 'Promovent…', 'Importació completada! {n} esborrany(s) creat(s).', 'Mostra els esborranys (Catalogació)', 'Finalitza'),
  eo: K('Ŝargado…', 'Neniu linio por importi.', '{n} registro(j) preta(j) por promocio.', 'Promocii al malnetoj', 'Promociado…', 'Importo finita! {n} malneto(j) kreita(j).', 'Vidi la malnetojn (Katalogado)', 'Fini'),
  nl: K('Laden…', 'Geen rij om te importeren.', '{n} record(s) klaar voor promotie.', 'Promoveren naar concepten', 'Bezig met promoveren…', 'Import voltooid! {n} concept(en) aangemaakt.', 'Concepten bekijken (Catalogiseren)', 'Voltooien'),
  el: K('Φόρτωση…', 'Καμία γραμμή προς εισαγωγή.', '{n} εγγραφή/ές έτοιμη/ες για προαγωγή.', 'Προαγωγή σε προσχέδια', 'Προαγωγή…', 'Η εισαγωγή ολοκληρώθηκε! Δημιουργήθηκαν {n} προσχέδιο/α.', 'Προβολή προσχεδίων (Καταλογογράφηση)', 'Ολοκλήρωση'),
};

let total = 0;
for (const [loc, file] of Object.entries(FILES)) {
  const p = path.join(DIR, file);
  let txt = fs.readFileSync(p, 'utf8');
  const toAdd = Object.entries(KEYS[loc]).filter(([k]) => !txt.includes('"' + k + '"'));
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
