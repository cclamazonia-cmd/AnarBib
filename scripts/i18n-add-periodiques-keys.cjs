/* ===========================================================================
 * i18n-add-periodiques-keys.cjs
 * Chantier PÉRIODIQUES (spec-periodiques v0.1) — libellés du sélecteur de titre
 * au catalogage, de la page publique de revue, et de la désignation du
 * fascicule sur la fiche du document. 28 clés × 10 locales.
 *
 * Idempotent (sentinelle par clé) et purement textuel : insertion avant le `}`
 * final, jamais de re-sérialisation JSON — celle-ci transformerait les `\n` et
 * casserait les fichiers.
 *
 * Les dix langues sont produites d'emblée, y compris celles où je suis le moins
 * sûr (el, eo, nl, ca) : mieux vaut une formulation à corriger qu'un repli
 * silencieux sur le portugais, qui ne se voit pas et ne se signale pas.
 * Les termes à revoir en priorité par les communautés de langue sont les termes
 * catalographiques — « état de collection » et « fascicule » ont un équivalent
 * consacré dans chaque tradition bibliothéconomique, que je n'ai pas.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const KEYS = {
  // ── Catalogage : sélecteur de titre de revue ────────────────────────────
  'catalogacao.serial.label': {
    'pt-BR': 'Título de periódico (autoridade)', fr: 'Titre de revue (autorité)',
    es: 'Título de revista (autoridad)', en: 'Serial title (authority)',
    it: 'Titolo di periodico (autorità)', de: 'Zeitschriftentitel (Normdaten)',
    ca: 'Títol de revista (autoritat)', eo: 'Titolo de periodaĵo (aŭtoritato)',
    nl: 'Tijdschrifttitel (autoriteit)', el: 'Τίτλος περιοδικού (καθιερωμένος)',
  },
  'catalogacao.serial.none': {
    'pt-BR': 'Nenhum título de periódico vinculado', fr: 'Aucun titre de revue rattaché',
    es: 'Ningún título de revista vinculado', en: 'No serial title linked',
    it: 'Nessun titolo di periodico collegato', de: 'Kein Zeitschriftentitel verknüpft',
    ca: 'Cap títol de revista vinculat', eo: 'Neniu titolo de periodaĵo ligita',
    nl: 'Geen tijdschrifttitel gekoppeld', el: 'Δεν έχει συνδεθεί τίτλος περιοδικού',
  },
  'catalogacao.serial.searchPh': {
    'pt-BR': 'Buscar uma revista pelo título ou ISSN…', fr: 'Chercher une revue par son titre ou son ISSN…',
    es: 'Buscar una revista por título o ISSN…', en: 'Search a serial by title or ISSN…',
    it: 'Cercare un periodico per titolo o ISSN…', de: 'Zeitschrift nach Titel oder ISSN suchen…',
    ca: 'Cercar una revista pel títol o l’ISSN…', eo: 'Serĉi periodaĵon laŭ titolo aŭ ISSN…',
    nl: 'Zoek een tijdschrift op titel of ISSN…', el: 'Αναζήτηση περιοδικού με τίτλο ή ISSN…',
  },
  'catalogacao.serial.create': {
    'pt-BR': 'Criar a revista « {term} »', fr: 'Créer la revue « {term} »',
    es: 'Crear la revista « {term} »', en: 'Create the serial “{term}”',
    it: 'Creare il periodico « {term} »', de: 'Zeitschrift „{term}“ anlegen',
    ca: 'Crear la revista « {term} »', eo: 'Krei la periodaĵon « {term} »',
    nl: 'Tijdschrift ‘{term}’ aanmaken', el: 'Δημιουργία περιοδικού «{term}»',
  },
  'catalogacao.serial.proposed': {
    'pt-BR': 'proposto', fr: 'proposé', es: 'propuesto', en: 'proposed',
    it: 'proposto', de: 'vorgeschlagen', ca: 'proposat', eo: 'proponita',
    nl: 'voorgesteld', el: 'προτεινόμενος',
  },
  'catalogacao.serial.proposedHint': {
    'pt-BR': 'Este título aguarda validação do Ateliê: ainda não está visível ao público.',
    fr: 'Ce titre attend sa validation par l’Atelier : il n’est pas encore visible du public.',
    es: 'Este título espera la validación del Taller: aún no es visible al público.',
    en: 'This title is awaiting validation by the Workshop: it is not yet publicly visible.',
    it: 'Questo titolo attende la convalida dell’Atelier: non è ancora visibile al pubblico.',
    de: 'Dieser Titel wartet auf die Bestätigung der Werkstatt: er ist noch nicht öffentlich sichtbar.',
    ca: 'Aquest títol espera la validació del Taller: encara no és visible al públic.',
    eo: 'Ĉi tiu titolo atendas validigon de la Metiejo: ĝi ankoraŭ ne estas publike videbla.',
    nl: 'Deze titel wacht op validatie door het Atelier: nog niet publiek zichtbaar.',
    el: 'Αυτός ο τίτλος αναμένει επικύρωση από το Εργαστήριο: δεν είναι ακόμη ορατός στο κοινό.',
  },
  'catalogacao.serial.detach': {
    'pt-BR': 'Desvincular este título', fr: 'Détacher ce titre',
    es: 'Desvincular este título', en: 'Unlink this title',
    it: 'Scollegare questo titolo', de: 'Diesen Titel lösen',
    ca: 'Desvincular aquest títol', eo: 'Malligi ĉi tiun titolon',
    nl: 'Deze titel ontkoppelen', el: 'Αποσύνδεση αυτού του τίτλου',
  },
  'catalogacao.serial.createFailed': {
    'pt-BR': 'A criação do título falhou.', fr: 'La création du titre a échoué.',
    es: 'La creación del título ha fallado.', en: 'Creating the title failed.',
    it: 'La creazione del titolo non è riuscita.', de: 'Das Anlegen des Titels ist fehlgeschlagen.',
    ca: 'La creació del títol ha fallat.', eo: 'La kreado de la titolo malsukcesis.',
    nl: 'Het aanmaken van de titel is mislukt.', el: 'Η δημιουργία του τίτλου απέτυχε.',
  },
  'catalogacao.serial.transcribedHint': {
    'pt-BR': 'O campo « Título do periódico » abaixo continua sendo a forma transcrita no fascículo: as duas coexistem.',
    fr: 'Le champ « Titre du périodique » ci-dessous reste la forme transcrite sur le fascicule : les deux coexistent.',
    es: 'El campo « Título de la publicación » de abajo sigue siendo la forma transcrita en el fascículo: ambas coexisten.',
    en: 'The “Periodical title” field below remains the form transcribed on the issue: the two coexist.',
    it: 'Il campo « Titolo del periodico » qui sotto resta la forma trascritta sul fascicolo: le due coesistono.',
    de: 'Das Feld „Zeitschriftentitel“ unten bleibt die auf dem Heft abgedruckte Form: beide bestehen nebeneinander.',
    ca: 'El camp « Títol de la publicació » de sota continua sent la forma transcrita al fascicle: totes dues coexisteixen.',
    eo: 'La suba kampo « Titolo de la periodaĵo » restas la formo transskribita sur la kajero: ambaŭ kunekzistas.',
    nl: 'Het veld ‘Tijdschrifttitel’ hieronder blijft de vorm zoals afgedrukt op het nummer: beide bestaan naast elkaar.',
    el: 'Το πεδίο «Τίτλος περιοδικού» παρακάτω παραμένει η μορφή που είναι τυπωμένη στο τεύχος: οι δύο συνυπάρχουν.',
  },
  'catalogacao.serial.issuesCount': {
    'pt-BR': '{count, plural, one {# número} other {# números}}',
    fr: '{count, plural, one {# numéro} other {# numéros}}',
    es: '{count, plural, one {# número} other {# números}}',
    en: '{count, plural, one {# issue} other {# issues}}',
    it: '{count, plural, one {# numero} other {# numeri}}',
    de: '{count, plural, one {# Heft} other {# Hefte}}',
    ca: '{count, plural, one {# número} other {# números}}',
    eo: '{count, plural, one {# numero} other {# numeroj}}',
    nl: '{count, plural, one {# nummer} other {# nummers}}',
    el: '{count, plural, one {# τεύχος} other {# τεύχη}}',
  },

  // ── Page publique de revue ──────────────────────────────────────────────
  'serial.pageTitle': {
    'pt-BR': 'Periódico', fr: 'Revue', es: 'Revista', en: 'Serial',
    it: 'Periodico', de: 'Zeitschrift', ca: 'Revista', eo: 'Periodaĵo',
    nl: 'Tijdschrift', el: 'Περιοδικό',
  },
  'serial.notFound': {
    'pt-BR': 'Periódico não encontrado.', fr: 'Revue introuvable.',
    es: 'Revista no encontrada.', en: 'Serial not found.',
    it: 'Periodico non trovato.', de: 'Zeitschrift nicht gefunden.',
    ca: 'Revista no trobada.', eo: 'Periodaĵo ne trovita.',
    nl: 'Tijdschrift niet gevonden.', el: 'Το περιοδικό δεν βρέθηκε.',
  },
  'serial.altTitles': {
    'pt-BR': 'Títulos paralelos', fr: 'Titres parallèles', es: 'Títulos paralelos',
    en: 'Parallel titles', it: 'Titoli paralleli', de: 'Paralleltitel',
    ca: 'Títols paral·lels', eo: 'Paralelaj titoloj', nl: 'Paralleltitels',
    el: 'Παράλληλοι τίτλοι',
  },
  'serial.emitter': {
    'pt-BR': 'Editado por', fr: 'Édité par', es: 'Editado por', en: 'Published by',
    it: 'Edito da', de: 'Herausgegeben von', ca: 'Editat per', eo: 'Eldonita de',
    nl: 'Uitgegeven door', el: 'Έκδοση από',
  },
  'serial.frequency': {
    'pt-BR': 'Periodicidade', fr: 'Périodicité', es: 'Periodicidad', en: 'Frequency',
    it: 'Periodicità', de: 'Erscheinungsweise', ca: 'Periodicitat', eo: 'Aperofteco',
    nl: 'Verschijningsfrequentie', el: 'Συχνότητα έκδοσης',
  },
  'serial.continues': {
    'pt-BR': 'Continua', fr: 'Fait suite à', es: 'Continúa a', en: 'Continues',
    it: 'Continua', de: 'Fortsetzung von', ca: 'Continua', eo: 'Daŭrigas',
    nl: 'Voortzetting van', el: 'Συνέχεια του',
  },
  'serial.continuedBy': {
    'pt-BR': 'Continuado por', fr: 'Devient', es: 'Continuado por', en: 'Continued by',
    it: 'Continuato da', de: 'Fortgesetzt durch', ca: 'Continuat per', eo: 'Daŭrigata de',
    nl: 'Voortgezet als', el: 'Συνεχίζεται ως',
  },
  'serial.holdings': {
    'pt-BR': 'Estado da coleção', fr: 'État de collection', es: 'Estado de la colección',
    en: 'Holdings statement', it: 'Consistenza', de: 'Bestandsangabe',
    ca: 'Estat de la col·lecció', eo: 'Stato de la kolekto', nl: 'Bezitsaanduiding',
    el: 'Κατάσταση συλλογής',
  },
  'serial.holdings.computed': {
    'pt-BR': 'Segundo os números catalogados: {first}–{last} ({count})',
    fr: 'D’après les numéros catalogués : {first}–{last} ({count})',
    es: 'Según los números catalogados: {first}–{last} ({count})',
    en: 'Based on catalogued issues: {first}–{last} ({count})',
    it: 'In base ai numeri catalogati: {first}–{last} ({count})',
    de: 'Nach den erfassten Heften: {first}–{last} ({count})',
    ca: 'Segons els números catalogats: {first}–{last} ({count})',
    eo: 'Laŭ la katalogitaj numeroj: {first}–{last} ({count})',
    nl: 'Op basis van de gecatalogiseerde nummers: {first}–{last} ({count})',
    el: 'Με βάση τα καταλογογραφημένα τεύχη: {first}–{last} ({count})',
  },
  'serial.holdings.gaps': {
    'pt-BR': 'Lacunas', fr: 'Lacunes', es: 'Lagunas', en: 'Gaps',
    it: 'Lacune', de: 'Lücken', ca: 'Llacunes', eo: 'Mankoj',
    nl: 'Hiaten', el: 'Κενά',
  },
  'serial.issues': {
    'pt-BR': 'Números catalogados ({count})', fr: 'Numéros catalogués ({count})',
    es: 'Números catalogados ({count})', en: 'Catalogued issues ({count})',
    it: 'Numeri catalogati ({count})', de: 'Erfasste Hefte ({count})',
    ca: 'Números catalogats ({count})', eo: 'Katalogitaj numeroj ({count})',
    nl: 'Gecatalogiseerde nummers ({count})', el: 'Καταλογογραφημένα τεύχη ({count})',
  },
  'serial.issues.none': {
    'pt-BR': 'Nenhum número catalogado por enquanto.', fr: 'Aucun numéro catalogué pour l’instant.',
    es: 'Ningún número catalogado por ahora.', en: 'No issues catalogued yet.',
    it: 'Nessun numero catalogato per ora.', de: 'Bisher keine Hefte erfasst.',
    ca: 'Cap número catalogat de moment.', eo: 'Ankoraŭ neniu numero katalogita.',
    nl: 'Nog geen nummers gecatalogiseerd.', el: 'Δεν έχει καταλογογραφηθεί ακόμη κανένα τεύχος.',
  },
  'serial.issue.volume': {
    'pt-BR': 'vol. {v}', fr: 'vol. {v}', es: 'vol. {v}', en: 'vol. {v}',
    it: 'vol. {v}', de: 'Bd. {v}', ca: 'vol. {v}', eo: 'vol. {v}',
    nl: 'jrg. {v}', el: 'τόμ. {v}',
  },
  'serial.issue.number': {
    'pt-BR': 'n.º {n}', fr: 'n° {n}', es: 'n.º {n}', en: 'no. {n}',
    it: 'n. {n}', de: 'Nr. {n}', ca: 'núm. {n}', eo: 'n-ro {n}',
    nl: 'nr. {n}', el: 'αρ. {n}',
  },
  'serial.completeness.completa': {
    'pt-BR': 'Coleção completa', fr: 'Collection complète', es: 'Colección completa',
    en: 'Complete run', it: 'Collezione completa', de: 'Vollständige Reihe',
    ca: 'Col·lecció completa', eo: 'Kompleta kolekto', nl: 'Volledige reeks',
    el: 'Πλήρης σειρά',
  },
  'serial.completeness.quase_completa': {
    'pt-BR': 'Quase completa', fr: 'Presque complète', es: 'Casi completa',
    en: 'Nearly complete', it: 'Quasi completa', de: 'Fast vollständig',
    ca: 'Gairebé completa', eo: 'Preskaŭ kompleta', nl: 'Bijna volledig',
    el: 'Σχεδόν πλήρης',
  },
  'serial.completeness.parcial': {
    'pt-BR': 'Parcial', fr: 'Partielle', es: 'Parcial', en: 'Partial',
    it: 'Parziale', de: 'Teilweise', ca: 'Parcial', eo: 'Parta',
    nl: 'Gedeeltelijk', el: 'Μερική',
  },
  'serial.completeness.esparsa': {
    'pt-BR': 'Esparsa', fr: 'Éparse', es: 'Dispersa', en: 'Scattered',
    it: 'Sparsa', de: 'Verstreut', ca: 'Dispersa', eo: 'Disa',
    nl: 'Verspreid', el: 'Διάσπαρτη',
  },

  // ── Fiche du document : de quel titre ce numéro est-il un numéro ────────
  'book.serial.partOf': {
    'pt-BR': 'Número do periódico', fr: 'Numéro de la revue', es: 'Número de la revista',
    en: 'Issue of the serial', it: 'Numero del periodico', de: 'Heft der Zeitschrift',
    ca: 'Número de la revista', eo: 'Numero de la periodaĵo', nl: 'Nummer van het tijdschrift',
    el: 'Τεύχος του περιοδικού',
  },
  'book.meta.issue': {
    'pt-BR': 'Número', fr: 'Numéro', es: 'Número', en: 'Issue',
    it: 'Numero', de: 'Heft', ca: 'Número', eo: 'Numero',
    nl: 'Nummer', el: 'Τεύχος',
  },
  'book.meta.fascicule': {
    'pt-BR': 'Fascículo', fr: 'Fascicule', es: 'Fascículo', en: 'Fascicle',
    it: 'Fascicolo', de: 'Faszikel', ca: 'Fascicle', eo: 'Kajero',
    nl: 'Aflevering', el: 'Τεύχος (μέρος)',
  },
  'book.meta.pubDate': {
    'pt-BR': 'Data de edição', fr: 'Date d’édition', es: 'Fecha de edición',
    en: 'Issue date', it: 'Data di edizione', de: 'Erscheinungsdatum',
    ca: 'Data d’edició', eo: 'Dato de eldono', nl: 'Verschijningsdatum',
    el: 'Ημερομηνία έκδοσης',
  },
  'book.meta.frequency': {
    'pt-BR': 'Periodicidade', fr: 'Périodicité', es: 'Periodicidad', en: 'Frequency',
    it: 'Periodicità', de: 'Erscheinungsweise', ca: 'Periodicitat', eo: 'Aperofteco',
    nl: 'Verschijningsfrequentie', el: 'Συχνότητα έκδοσης',
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
