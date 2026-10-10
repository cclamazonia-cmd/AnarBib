/* ===========================================================================
 * i18n-add-c29-exemplaires-notice.cjs — C29 lot 1 (10/10/2026) : les
 * exemplaires d'une notice, dans la notice (ExemplaresPanel).
 * Titre et compte du panneau, « Nouvel exemplaire », la note d'une fiche non
 * publiée, la liste vide, l'étiquette « autre bibliothèque », la reprise d'une
 * mise à jour déjà ouverte, l'erreur de chargement, la bibliothèque inconnue.
 * Vocabulaire repris des clés voisines (catalogacao.publish.copies*,
 * catalogacao.infocard.exemplar*, common.edit). Tutoiement partout ; pt-BR au
 * « você » (aucune adresse directe ici).
 * Idempotent : une clé déjà posée n'est réécrite que si sa valeur a changé ici.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const CLES = {
  'catalogacao.copies.title': {
    fr: 'Exemplaires', 'pt-BR': 'Exemplares', en: 'Copies', es: 'Ejemplares', ca: 'Exemplars',
    it: 'Esemplari', de: 'Exemplare', nl: 'Exemplaren', eo: 'Ekzempleroj', el: 'Αντίτυπα',
  },
  'catalogacao.copies.count': {
    fr: '{n, plural, one {# exemplaire} other {# exemplaires}}',
    'pt-BR': '{n, plural, one {# exemplar} other {# exemplares}}',
    en: '{n, plural, one {# copy} other {# copies}}',
    es: '{n, plural, one {# ejemplar} other {# ejemplares}}',
    ca: '{n, plural, one {# exemplar} other {# exemplars}}',
    it: '{n, plural, one {# esemplare} other {# esemplari}}',
    de: '{n, plural, one {# Exemplar} other {# Exemplare}}',
    nl: '{n, plural, one {# exemplaar} other {# exemplaren}}',
    eo: '{n, plural, one {# ekzemplero} other {# ekzempleroj}}',
    el: '{n, plural, one {# αντίτυπο} other {# αντίτυπα}}',
  },
  'catalogacao.copies.new': {
    fr: 'Nouvel exemplaire', 'pt-BR': 'Novo exemplar', en: 'New copy', es: 'Nuevo ejemplar', ca: 'Nou exemplar',
    it: 'Nuovo esemplare', de: 'Neues Exemplar', nl: 'Nieuw exemplaar', eo: 'Nova ekzemplero', el: 'Νέο αντίτυπο',
  },
  'catalogacao.copies.unpublished': {
    fr: 'La fiche n’est pas encore publiée : ses exemplaires naissent à la publication, au nombre indiqué plus bas. Un exemplaire importé apparaît déjà ici, rattaché à la fiche.',
    'pt-BR': 'A ficha ainda não foi publicada: seus exemplares nascem na publicação, no número indicado mais abaixo. Um exemplar importado já aparece aqui, vinculado à ficha.',
    en: 'The record is not published yet: its copies are created on publication, in the number given below. An imported copy already appears here, attached to the record.',
    es: 'La ficha aún no está publicada: sus ejemplares nacen al publicar, en el número indicado más abajo. Un ejemplar importado ya aparece aquí, vinculado a la ficha.',
    ca: 'La fitxa encara no està publicada: els seus exemplars neixen en publicar, en el nombre indicat més avall. Un exemplar importat ja apareix aquí, vinculat a la fitxa.',
    it: 'La scheda non è ancora pubblicata: i suoi esemplari nascono alla pubblicazione, nel numero indicato più sotto. Un esemplare importato compare già qui, legato alla scheda.',
    de: 'Der Datensatz ist noch nicht veröffentlicht: seine Exemplare entstehen bei der Veröffentlichung, in der unten angegebenen Zahl. Ein importiertes Exemplar erscheint hier bereits, dem Datensatz zugeordnet.',
    nl: 'De fiche is nog niet gepubliceerd: haar exemplaren ontstaan bij publicatie, in het aantal dat hieronder staat. Een geïmporteerd exemplaar staat hier al, gekoppeld aan de fiche.',
    eo: 'La skedo ankoraŭ ne estas publikigita: ĝiaj ekzempleroj naskiĝas ĉe la publikigo, en la nombro indikita sube. Importita ekzemplero jam aperas ĉi tie, ligita al la skedo.',
    el: 'Η καρτέλα δεν έχει δημοσιευτεί ακόμη: τα αντίτυπά της δημιουργούνται κατά τη δημοσίευση, στον αριθμό που δίνεται παρακάτω. Ένα εισαγόμενο αντίτυπο εμφανίζεται ήδη εδώ, συνδεδεμένο με την καρτέλα.',
  },
  'catalogacao.copies.empty': {
    fr: 'Aucun exemplaire pour l’instant.', 'pt-BR': 'Nenhum exemplar por enquanto.', en: 'No copies yet.',
    es: 'Ningún ejemplar por ahora.', ca: 'Cap exemplar per ara.', it: 'Nessun esemplare per ora.',
    de: 'Noch keine Exemplare.', nl: 'Nog geen exemplaren.', eo: 'Ankoraŭ neniu ekzemplero.', el: 'Κανένα αντίτυπο ακόμη.',
  },
  'catalogacao.copies.otherLibrary': {
    fr: 'autre bibliothèque', 'pt-BR': 'outra biblioteca', en: 'other library', es: 'otra biblioteca', ca: 'altra biblioteca',
    it: 'altra biblioteca', de: 'andere Bibliothek', nl: 'andere bibliotheek', eo: 'alia biblioteko', el: 'άλλη βιβλιοθήκη',
  },
  'catalogacao.copies.resumeUpdate': {
    fr: 'Reprendre la mise à jour', 'pt-BR': 'Retomar a atualização', en: 'Resume the update', es: 'Retomar la actualización',
    ca: 'Reprendre l’actualització', it: 'Riprendere l’aggiornamento', de: 'Aktualisierung fortsetzen', nl: 'Bijwerken hervatten',
    eo: 'Daŭrigi la ĝisdatigon', el: 'Συνέχιση της ενημέρωσης',
  },
  'catalogacao.copies.updatePending': {
    fr: 'mise à jour en cours', 'pt-BR': 'atualização em curso', en: 'update in progress', es: 'actualización en curso',
    ca: 'actualització en curs', it: 'aggiornamento in corso', de: 'Aktualisierung läuft', nl: 'bijwerken bezig',
    eo: 'ĝisdatigo kuranta', el: 'ενημέρωση σε εξέλιξη',
  },
  'catalogacao.copies.loadError': {
    fr: 'Les exemplaires n’ont pas pu être chargés : {message}',
    'pt-BR': 'Não foi possível carregar os exemplares: {message}',
    en: 'The copies could not be loaded: {message}',
    es: 'No se pudieron cargar los ejemplares: {message}',
    ca: 'No s’han pogut carregar els exemplars: {message}',
    it: 'Impossibile caricare gli esemplari: {message}',
    de: 'Die Exemplare konnten nicht geladen werden: {message}',
    nl: 'De exemplaren konden niet worden geladen: {message}',
    eo: 'La ekzempleroj ne povis esti ŝargitaj: {message}',
    el: 'Δεν ήταν δυνατή η φόρτωση των αντιτύπων: {message}',
  },
  'catalogacao.copies.libraryUnknown': {
    fr: 'Bibliothèque inconnue', 'pt-BR': 'Biblioteca desconhecida', en: 'Unknown library', es: 'Biblioteca desconocida',
    ca: 'Biblioteca desconeguda', it: 'Biblioteca sconosciuta', de: 'Unbekannte Bibliothek', nl: 'Onbekende bibliotheek',
    eo: 'Nekonata biblioteko', el: 'Άγνωστη βιβλιοθήκη',
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
