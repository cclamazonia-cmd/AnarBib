/* ===========================================================================
 * i18n-add-error-import-run-has-drafts.cjs
 * HINT leve par public.fn_import_delete_run quand le lot de catalogage issu du
 * run retient encore des brouillons actifs. Convention (a) de localizeError :
 * RAISE EXCEPTION ... USING HINT = 'error.import.run_has_drafts'.
 * 1 cle x 10 locales. Idempotent (sentinelle error.import.run_has_drafts).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'error.import.run_has_drafts';

const V = {
  fr: 'Cet import a créé un lot de catalogage qui retient encore des brouillons. Traite le lot dans Catalogage › Lots, puis supprime l’import.',
  'pt-BR': 'Esta importação criou um lote de catalogação que ainda retém rascunhos. Trate o lote em Catalogação › Lotes e depois exclua a importação.',
  es: 'Esta importación creó un lote de catalogación que aún retiene borradores. Trata el lote en Catalogación › Lotes y luego elimina la importación.',
  en: 'This import created a cataloguing batch that still holds drafts. Deal with the batch under Cataloguing › Batches, then delete the import.',
  it: 'Questa importazione ha creato un lotto di catalogazione che trattiene ancora delle bozze. Tratta il lotto in Catalogazione › Lotti, poi elimina l’importazione.',
  de: 'Dieser Import hat ein Katalogisierungslos erzeugt, das noch Entwürfe enthält. Bearbeite das Los unter Katalogisierung › Lose und lösche dann den Import.',
  ca: 'Aquesta importació ha creat un lot de catalogació que encara reté esborranys. Tracta el lot a Catalogació › Lots i després elimina la importació.',
  eo: 'Ĉi tiu importo kreis katalogan loton kiu ankoraŭ retenas malnetojn. Traktu la loton en Katalogado › Lotoj, poste forigu la importon.',
  nl: 'Deze import heeft een catalogiseringslot aangemaakt dat nog concepten bevat. Behandel het lot onder Catalogisering › Loten en verwijder daarna de import.',
  el: 'Αυτή η εισαγωγή δημιούργησε μια παρτίδα καταλογογράφησης που κρατά ακόμη πρόχειρα. Διαχειρίσου την παρτίδα στο Καταλογογράφηση › Παρτίδες και μετά διάγραψε την εισαγωγή.',
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes('"' + SENTINEL + '"')) {
    const val = V[loc];
    if (!val) throw new Error('Valeur manquante: ' + loc);
    const entry = '  ' + JSON.stringify(SENTINEL) + ': ' + JSON.stringify(val);
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entry + '\n' + content.slice(marker);
    if (!content.endsWith('\n')) content += '\n';
    fs.writeFileSync(file, content, 'utf8');
  }
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ': 1 cle run_has_drafts (si absente), JSON valide.');
}
console.log('\nTermine.');
