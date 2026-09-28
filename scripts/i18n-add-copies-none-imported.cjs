#!/usr/bin/env node
/**
 * i18n-add-copies-none-imported.cjs — IMP-25 (28/09/2026).
 *
 *  - catalogacao.publish.copiesNoneImported : le bloc « exemplaires initiaux »
 *    d'une fiche importée d'un fichier MARC qui ne lui décrit aucun exemplaire —
 *    aucun ne sera créé à la publication (publish_book_draft), on l'ajoute après
 *    s'il en faut un.
 * Tutoiement partout ; pt-BR au « você ». Idempotent.
 */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const TEXTE = {
  fr: 'Le fichier importé ne décrit aucun exemplaire pour cette notice : aucun ne sera créé à la publication. S’il en faut un, ajoute-le une fois la notice publiée.',
  'pt-BR': 'O arquivo importado não descreve nenhum exemplar para esta ficha: nenhum será criado na publicação. Se precisar de um, adicione-o depois que a ficha for publicada.',
  es: 'El archivo importado no describe ningún ejemplar para esta ficha: no se creará ninguno al publicarla. Si hace falta uno, añádelo una vez publicada la ficha.',
  en: 'The imported file describes no copy for this record: none will be created when it is published. If one is needed, add it once the record is published.',
  ca: 'El fitxer importat no descriu cap exemplar per a aquesta fitxa: no se’n crearà cap en publicar-la. Si en cal un, afegeix-lo un cop publicada la fitxa.',
  de: 'Die importierte Datei beschreibt kein Exemplar für diesen Datensatz: Bei der Veröffentlichung wird keines angelegt. Wenn eines nötig ist, füge es hinzu, sobald der Datensatz veröffentlicht ist.',
  el: 'Το εισαγόμενο αρχείο δεν περιγράφει κανένα αντίτυπο για αυτή την εγγραφή: δεν θα δημιουργηθεί κανένα κατά τη δημοσίευση. Αν χρειάζεται ένα, πρόσθεσέ το μόλις δημοσιευτεί η εγγραφή.',
  eo: 'La importita dosiero priskribas neniun ekzempleron por ĉi tiu registro: neniu estos kreita ĉe la publikigo. Se necesas unu, aldonu ĝin post la publikigo de la registro.',
  it: 'Il file importato non descrive alcuna copia per questa scheda: non ne verrà creata nessuna alla pubblicazione. Se ne serve una, aggiungila una volta pubblicata la scheda.',
  nl: 'Het geïmporteerde bestand beschrijft geen exemplaar voor dit record: bij het publiceren wordt er geen aangemaakt. Is er een nodig, voeg het dan toe zodra het record gepubliceerd is.',
};

let n = 0;
for (const loc of LOCALES) {
  const f = path.join(DIR, `${loc}.json`);
  const j = JSON.parse(fs.readFileSync(f, 'utf8'));
  if (!TEXTE[loc]) throw new Error(`${loc} : traduction absente`);
  if (j['catalogacao.publish.copiesNoneImported'] !== TEXTE[loc]) { j['catalogacao.publish.copiesNoneImported'] = TEXTE[loc]; n++; }
  fs.writeFileSync(f, JSON.stringify(j, null, 2) + '\n');
}
console.log(`écrit : ${n}`);
