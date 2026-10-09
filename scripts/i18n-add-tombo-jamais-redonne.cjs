/* ===========================================================================
 * i18n-add-tombo-jamais-redonne.cjs — C17 (CAT-E21, 09/10/2026)
 * Le refus d'un numéro d'inventaire déjà donné : 1 clé × 10 locales. Idempotent, source de la clé.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const CLES = {
  'error.catalog.tombo.deja_attribue': {
    fr: 'Ce numéro d’inventaire a déjà été donné : un numéro ne se redonne jamais, même après la suppression de l’exemplaire qui le portait. Laisse le champ vide pour recevoir le prochain numéro de la série.',
    'pt-BR': 'Este número de tombo já foi dado: um número nunca é dado de novo, mesmo depois de apagar o exemplar que o tinha. Deixe o campo vazio para receber o próximo número da série.',
    en: 'This inventory number has already been given: a number is never given again, even after the copy that carried it was deleted. Leave the field empty to receive the next number in the series.',
    es: 'Este número de inventario ya fue dado: un número nunca se vuelve a dar, ni siquiera después de borrar el ejemplar que lo llevaba. Deja el campo vacío para recibir el siguiente número de la serie.',
    ca: 'Aquest número d’inventari ja s’ha donat: un número no es torna a donar mai, ni tan sols després d’esborrar l’exemplar que el portava. Deixa el camp buit per rebre el número següent de la sèrie.',
    it: 'Questo numero d’inventario è già stato dato: un numero non si ridà mai, nemmeno dopo la cancellazione dell’esemplare che lo portava. Lascia il campo vuoto per ricevere il numero successivo della serie.',
    de: 'Diese Inventarnummer wurde schon vergeben: Eine Nummer wird nie erneut vergeben, auch nicht nach dem Löschen des Exemplars, das sie trug. Lass das Feld leer, um die nächste Nummer der Reihe zu erhalten.',
    nl: 'Dit inventarisnummer is al gegeven: een nummer wordt nooit opnieuw gegeven, ook niet nadat het exemplaar dat het droeg is verwijderd. Laat het veld leeg om het volgende nummer van de reeks te krijgen.',
    eo: 'Ĉi tiu inventara numero jam estis donita: numero neniam estas donita denove, eĉ post forigo de la ekzemplero kiu portis ĝin. Lasu la kampon malplena por ricevi la sekvan numeron de la serio.',
    el: 'Αυτός ο αριθμός καταγραφής έχει ήδη δοθεί: ένας αριθμός δεν δίνεται ποτέ ξανά, ακόμη και μετά τη διαγραφή του αντιτύπου που τον έφερε. Άφησε το πεδίο κενό για να πάρεις τον επόμενο αριθμό της σειράς.',
  },
};
const ligneDe = (cle) => new RegExp('^  ' + JSON.stringify(cle).replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ': (".*?")(,?)$', 'm');
for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  let ajoutees = 0, corrigees = 0;
  for (const [cle, valeurs] of Object.entries(CLES)) {
    const val = valeurs[loc];
    if (!val) throw new Error(`Valeur manquante : ${cle} / ${loc}`);
    const m = content.match(ligneDe(cle));
    if (m) {
      if (JSON.parse(m[1]) !== val) { content = content.replace(m[0], '  ' + JSON.stringify(cle) + ': ' + JSON.stringify(val) + m[2]); corrigees++; }
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
