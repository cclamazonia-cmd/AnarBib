/* ===========================================================================
 * i18n-add-gazette-correction-keys.cjs
 * GAZ-9 (15/09/2026) — le staff corrige une brève avant de la retenir.
 * Panneau réseau : bouton « Corriger », éditeur, trace de la correction,
 * version d'origine. 8 clés × 10 locales.
 * Idempotent (sentinelle par clé), purement textuel (insertion avant le `}` final).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const KEYS = {
  'rede.gazeta.correct': {
    'pt-BR': 'Corrigir', fr: 'Corriger', es: 'Corregir', en: 'Revise', it: 'Correggere',
    de: 'Überarbeiten', ca: 'Corregir', eo: 'Korekti', nl: 'Aanpassen', el: 'Διόρθωση',
  },
  'rede.gazeta.correct.hint': {
    'pt-BR': 'Corrige tu mesma o que impede a nota de sair. A pessoa será avisada de que foi retida com correções, com o texto que sairá; a tradução recomeça.',
    fr: 'Corrige toi-même ce qui empêche la brève de paraître. La personne sera prévenue qu’elle est retenue avec corrections, texte à l’appui ; la traduction repart.',
    es: 'Corrige tú misme lo que impide que la nota salga. La persona será avisada de que fue retenida con correcciones, con el texto que saldrá; la traducción vuelve a empezar.',
    en: 'Fix yourself what keeps the bulletin from being published. The contributor will be told it was accepted with corrections, with the text as it will appear; translation starts over.',
    it: 'Correggi tu stess* ciò che impedisce alla breve di uscire. La persona sarà avvisata che è stata accolta con correzioni, testo alla mano; la traduzione riparte.',
    de: 'Überarbeite selbst, was der Veröffentlichung im Weg steht. Die Person erfährt, dass ihre Kurzmeldung mit Korrekturen angenommen wurde, samt Text; die Übersetzung beginnt neu.',
    ca: 'Corregeix tu mateixa el que impedeix que la breu surti. La persona serà avisada que s’ha retingut amb correccions, amb el text que sortirà; la traducció torna a començar.',
    eo: 'Korektu mem tion, kio malhelpas la aperon de la novaĵeto. La persono estos avertita, ke ĝi estas akceptita kun korektoj, kun la teksto aperonta; la traduko rekomenciĝas.',
    nl: 'Pas zelf aan wat publicatie van het bericht in de weg staat. De persoon hoort dat het met correcties is aangenomen, met de tekst zoals die verschijnt; de vertaling begint opnieuw.',
    el: 'Διόρθωσε μόνη σου ό,τι εμποδίζει τη δημοσίευση. Το άτομο θα ενημερωθεί ότι το σημείωμα κρατήθηκε με διορθώσεις, μαζί με το κείμενο που θα δημοσιευτεί· η μετάφραση ξεκινά από την αρχή.',
  },
  'rede.gazeta.correct.saveAccept': {
    'pt-BR': 'Guardar e aceitar', fr: 'Enregistrer et accepter', es: 'Guardar y aceptar', en: 'Save and accept',
    it: 'Salvare e accogliere', de: 'Speichern und annehmen', ca: 'Desar i acceptar', eo: 'Konservi kaj akcepti',
    nl: 'Opslaan en aannemen', el: 'Αποθήκευση και αποδοχή',
  },
  'rede.gazeta.correct.save': {
    'pt-BR': 'Guardar a correção', fr: 'Enregistrer la correction', es: 'Guardar la corrección', en: 'Save the correction',
    it: 'Salvare la correzione', de: 'Korrektur speichern', ca: 'Desar la correcció', eo: 'Konservi la korekton',
    nl: 'Correctie opslaan', el: 'Αποθήκευση διόρθωσης',
  },
  'rede.gazeta.correct.editedAt': {
    'pt-BR': 'corrigida pela equipe em {date}', fr: 'corrigée par l’équipe le {date}', es: 'corregida por el equipo el {date}',
    en: 'revised by the team on {date}', it: 'corretta dall’équipe il {date}', de: 'vom Team überarbeitet am {date}',
    ca: 'corregida per l’equip el {date}', eo: 'korektita de la teamo la {date}', nl: 'aangepast door het team op {date}',
    el: 'διορθώθηκε από την ομάδα στις {date}',
  },
  'rede.gazeta.correct.showOriginal': {
    'pt-BR': 'ver a versão da pessoa', fr: 'voir la version de la personne', es: 'ver la versión de la persona',
    en: 'show the contributor’s version', it: 'vedere la versione della persona', de: 'Fassung der Person anzeigen',
    ca: 'veure la versió de la persona', eo: 'vidi la version de la persono', nl: 'versie van de persoon tonen',
    el: 'εμφάνιση της εκδοχής του ατόμου',
  },
  'rede.gazeta.correct.hideOriginal': {
    'pt-BR': 'ocultar a versão da pessoa', fr: 'masquer la version de la personne', es: 'ocultar la versión de la persona',
    en: 'hide the contributor’s version', it: 'nascondere la versione della persona', de: 'Fassung der Person ausblenden',
    ca: 'amagar la versió de la persona', eo: 'kaŝi la version de la persono', nl: 'versie van de persoon verbergen',
    el: 'απόκρυψη της εκδοχής του ατόμου',
  },
  'rede.gazeta.correct.original': {
    'pt-BR': 'Versão da pessoa', fr: 'Version de la personne', es: 'Versión de la persona', en: 'Contributor’s version',
    it: 'Versione della persona', de: 'Fassung der Person', ca: 'Versió de la persona', eo: 'Versio de la persono',
    nl: 'Versie van de persoon', el: 'Εκδοχή του ατόμου',
  },
};

let added = 0;
for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  let n = 0;
  for (const [key, vals] of Object.entries(KEYS)) {
    if (content.includes('"' + key + '"')) continue;
    if (vals[loc] == null) throw new Error('Traduction manquante : ' + loc + ' / ' + key);
    const entry = '  ' + JSON.stringify(key) + ': ' + JSON.stringify(vals[loc]);
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entry + '\n' + content.slice(marker);
    n++;
  }
  if (n > 0) {
    if (!content.endsWith('\n')) content += '\n';
    fs.writeFileSync(file, content, 'utf8');
  }
  JSON.parse(fs.readFileSync(file, 'utf8'));
  added += n;
  console.log(loc + ' : ' + n + ' clé(s) ajoutée(s), JSON valide.');
}
console.log('\nTerminé — ' + added + ' entrée(s) au total (' + Object.keys(KEYS).length + ' clés × ' + LOCALES.length + ' locales).');
