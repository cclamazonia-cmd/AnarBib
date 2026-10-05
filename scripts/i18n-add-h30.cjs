/* ===========================================================================
 * i18n-add-h30.cjs — H30 (04/10/2026) : « Retraiter » exige le fichier.
 * Une HINT levée par la migration retraiter_exige_le_fichier
 * (convention (a) de localizeError : RAISE ... USING HINT = 'error.…').
 * 1 clé × 10 locales. Tutoiement partout ; pt-BR au « você ».
 * Idempotent : une clé déjà posée n'est réécrite que si sa valeur a changé ici.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const CLES = {
  'error.import.reparse_no_file': {
    fr: 'Le fichier de cet import n’est pas dans le stockage (disparu, ou jamais déposé : moisson OAI, candidat, dépôt direct) : il ne peut pas être retraité, et ses lignes restent telles quelles. Importe de nouveau le fichier si besoin.',
    'pt-BR': 'O arquivo desta importação não está no armazenamento (sumiu, ou nunca foi depositado: coleta OAI, candidato, depósito direto): ela não pode ser reprocessada, e as linhas ficam como estão. Importe o arquivo de novo, se precisar.',
    en: 'This import’s file is not in storage (gone, or never uploaded: OAI harvest, candidate, direct deposit): it cannot be reprocessed, and its rows stay as they are. Import the file anew if needed.',
    es: 'El archivo de esta importación no está en el almacenamiento (desaparecido, o nunca depositado: cosecha OAI, candidato, depósito directo): no se puede reprocesar, y sus filas quedan como están. Importa de nuevo el archivo si hace falta.',
    ca: 'El fitxer d’aquesta importació no és a l’emmagatzematge (desaparegut, o mai dipositat: collita OAI, candidat, dipòsit directe): no es pot reprocessar, i les seves files queden com estan. Importa de nou el fitxer si cal.',
    it: 'Il file di questa importazione non è nell’archivio (sparito, o mai depositato: raccolta OAI, candidato, deposito diretto): non può essere rielaborata, e le sue righe restano come sono. Importa di nuovo il file se serve.',
    de: 'Die Datei dieses Imports liegt nicht im Speicher (verschwunden oder nie hochgeladen: OAI-Ernte, Kandidat, Direkteinlieferung): Er kann nicht neu verarbeitet werden, und seine Zeilen bleiben, wie sie sind. Importiere die Datei bei Bedarf erneut.',
    nl: 'Het bestand van deze import staat niet in de opslag (verdwenen, of nooit geüpload: OAI-oogst, kandidaat, rechtstreekse inzending): hij kan niet opnieuw verwerkt worden, en zijn regels blijven zoals ze zijn. Importeer het bestand zo nodig opnieuw.',
    eo: 'La dosiero de ĉi tiu importo ne estas en la konservejo (malaperinta, aŭ neniam deponita: OAI-rikolto, kandidato, rekta deponaĵo): ĝi ne povas esti repritraktata, kaj ĝiaj linioj restas kiel ili estas. Importu la dosieron denove, se necese.',
    el: 'Το αρχείο αυτής της εισαγωγής δεν βρίσκεται στον αποθηκευτικό χώρο (χάθηκε ή δεν ανέβηκε ποτέ: συγκομιδή OAI, υποψήφιο, άμεση κατάθεση): δεν μπορεί να επανεπεξεργαστεί, και οι γραμμές της μένουν όπως είναι. Κάνε ξανά εισαγωγή του αρχείου αν χρειάζεται.',
  },
};

const ligneDe = (cle) => new RegExp('^  ' + JSON.stringify(cle).replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ': (".*?")(,?)$', 'm');

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  let ajoutees = 0;
  let corrigees = 0;
  for (const [cle, valeurs] of Object.entries(CLES)) {
    const val = valeurs[loc];
    if (!val) throw new Error(`Valeur manquante : ${cle} / ${loc}`);
    const m = content.match(ligneDe(cle));
    if (m) {
      if (JSON.parse(m[1]) !== val) {
        content = content.replace(m[0], '  ' + JSON.stringify(cle) + ': ' + JSON.stringify(val) + m[2]);
        corrigees++;
      }
      continue;
    }
    const entry = '  ' + JSON.stringify(cle) + ': ' + JSON.stringify(val);
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entry + '\n' + content.slice(marker);
    ajoutees++;
  }
  if (!content.endsWith('\n')) content += '\n';
  fs.writeFileSync(file, content, 'utf8');
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(`${loc} : ${ajoutees} clé(s) ajoutée(s), ${corrigees} corrigée(s), JSON valide.`);
}
