/* ===========================================================================
 * i18n-c29-lot4-un-seul-endroit.cjs — C29 lot 4 (11/10/2026) : un seul endroit
 * pour les exemplaires d'une fiche (décision de Xavier).
 *   - la note du panneau pour une fiche non publiée dit que le nombre se
 *     choisit « ci-dessous » (le bloc « Exemplaires à créer » vit désormais
 *     dans le panneau) ;
 *   - l'aide de « Ajouter un exemplaire » (après publication) dit qu'on reste
 *     dans la fiche ;
 *   - six clés retirées avec ce qu'elles servaient : la carte des exemplaires
 *     d'InfoCards (cinq clés catalogacao.infocard.*Exemplar*) et le bandeau 💡
 *     d'Indexation (catalogacao.exemplar.autoExemplarInfo), faux depuis le
 *     17/06 (le numéro vient de la série, plus de bib_ref).
 * Tutoiement partout ; pt-BR au « você ».
 * Idempotent : une clé déjà à la bonne valeur n'est pas réécrite ; une clé
 * déjà absente n'est pas cherchée.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const CLES = {
  'catalogacao.copies.unpublished': {
    fr: 'La fiche n’est pas encore publiée : ses exemplaires naissent à la publication, au nombre choisi ci-dessous. Un exemplaire importé apparaît déjà, rattaché à la fiche.',
    'pt-BR': 'A ficha ainda não foi publicada: seus exemplares nascem na publicação, no número escolhido abaixo. Um exemplar importado já aparece, vinculado à ficha.',
    en: 'The record is not published yet: its copies are created on publication, in the number chosen below. An imported copy already appears, attached to the record.',
    es: 'La ficha aún no está publicada: sus ejemplares nacen al publicar, en el número elegido abajo. Un ejemplar importado ya aparece, vinculado a la ficha.',
    ca: 'La fitxa encara no està publicada: els seus exemplars neixen en publicar, en el nombre triat a sota. Un exemplar importat ja apareix, vinculat a la fitxa.',
    it: 'La scheda non è ancora pubblicata: i suoi esemplari nascono alla pubblicazione, nel numero scelto qui sotto. Un esemplare importato compare già, collegato alla scheda.',
    de: 'Der Datensatz ist noch nicht veröffentlicht: seine Exemplare entstehen bei der Veröffentlichung, in der unten gewählten Anzahl. Ein importiertes Exemplar erscheint bereits, dem Datensatz zugeordnet.',
    nl: 'De fiche is nog niet gepubliceerd: haar exemplaren ontstaan bij publicatie, in het hieronder gekozen aantal. Een geïmporteerd exemplaar verschijnt al, gekoppeld aan de fiche.',
    eo: 'La skedo ankoraŭ ne estas publikigita: ĝiaj ekzempleroj naskiĝas ĉe la publikigo, en la nombro elektita sube. Importita ekzemplero jam aperas, ligita al la skedo.',
    el: 'Η καρτέλα δεν έχει δημοσιευτεί ακόμη: τα αντίτυπά της δημιουργούνται στη δημοσίευση, στον αριθμό που επιλέγεις παρακάτω. Ένα εισαγόμενο αντίτυπο εμφανίζεται ήδη, συνδεδεμένο με την καρτέλα.',
  },
  'catalogacao.next.addExemplarHint': {
    fr: 'Dans la fiche : bibliothèque et numéro proposés, publié en un geste.',
    'pt-BR': 'Na ficha: biblioteca e tombo propostos, publicado num gesto.',
    en: 'In the record: library and number proposed, published in one step.',
    es: 'En la ficha: biblioteca y número propuestos, publicado en un gesto.',
    ca: 'A la fitxa: biblioteca i número proposats, publicat en un gest.',
    it: 'Nella scheda: biblioteca e numero proposti, pubblicato in un gesto.',
    de: 'Im Datensatz: Bibliothek und Nummer vorgeschlagen, mit einem Schritt veröffentlicht.',
    nl: 'In de fiche: bibliotheek en nummer voorgesteld, in één stap gepubliceerd.',
    eo: 'En la skedo: biblioteko kaj numero proponitaj, publikigita per unu gesto.',
    el: 'Στην καρτέλα: βιβλιοθήκη και αριθμός προτείνονται, δημοσιεύεται με μία κίνηση.',
  },
};

const SUPPRIMER = [
  'catalogacao.exemplar.autoExemplarInfo',
  'catalogacao.infocard.exemplarTitle',
  'catalogacao.infocard.exemplarUnsaved',
  'catalogacao.infocard.noExemplar',
  'catalogacao.infocard.goExemplar',
  'catalogacao.infocard.exemplarCount',
];

const ligneDe = (cle) => new RegExp('^[ \\t]*' + JSON.stringify(cle).replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ':[ \\t]*("(?:[^"\\\\]|\\\\.)*")(,?)[ \\t]*\\r?\\n', 'm');

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  let corrigees = 0;
  let retirees = 0;
  for (const [cle, valeurs] of Object.entries(CLES)) {
    const val = valeurs[loc];
    if (!val) throw new Error(`Valeur manquante : ${cle} / ${loc}`);
    const m = content.match(ligneDe(cle));
    if (!m) throw new Error(`Clé absente, rien à corriger : ${cle} / ${loc}`);
    if (JSON.parse(m[1]) !== val) {
      content = content.replace(m[0], m[0].replace(m[1], JSON.stringify(val)));
      corrigees++;
    }
  }
  for (const cle of SUPPRIMER) {
    const m = content.match(ligneDe(cle));
    if (!m) continue;
    // Dernière clé du fichier (sans virgule) : la virgule de la précédente saute.
    if (!m[2]) {
      const avant = content.slice(0, m.index).replace(/,(\s*)$/, '$1');
      content = avant + content.slice(m.index + m[0].length);
    } else {
      content = content.slice(0, m.index) + content.slice(m.index + m[0].length);
    }
    retirees++;
  }
  if (!content.endsWith('\n')) content += '\n';
  fs.writeFileSync(file, content, 'utf8');
  const j = JSON.parse(fs.readFileSync(file, 'utf8'));
  for (const cle of SUPPRIMER) if (cle in j) throw new Error(`Toujours présente : ${cle} / ${loc}`);
  console.log(`${loc} : ${corrigees} clé(s) corrigée(s), ${retirees} retirée(s), JSON valide.`);
}
