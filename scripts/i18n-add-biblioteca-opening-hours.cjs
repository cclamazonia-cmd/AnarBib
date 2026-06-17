/* ===========================================================================
 * i18n-add-biblioteca-opening-hours.cjs
 * Éditeur d'horaires/permanences (pill « État de fonctionnement ») : 9 clés
 * biblioteca.openingHours.* + 1 clé account.mylib.hours (vitrine lecteur·rice).
 * 10 clés × 10 locales. Noms de jours via Intl côté front (pas de clés).
 * Idempotent (sentinelle biblioteca.openingHours.notePlaceholder).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'biblioteca.openingHours.notePlaceholder';

const ADD = {
  'pt-BR': {
    'biblioteca.openingHours.title': 'Horários de atendimento / plantões',
    'biblioteca.openingHours.hint': 'Faixas semanais — adiciona quantas precisares (plantões, aberturas…). Visível pelos membros da biblioteca.',
    'biblioteca.openingHours.start': 'Início',
    'biblioteca.openingHours.end': 'Fim',
    'biblioteca.openingHours.labelPlaceholder': 'Rótulo (opcional)',
    'biblioteca.openingHours.addSlot': '+ Adicionar faixa',
    'biblioteca.openingHours.empty': 'Nenhuma faixa definida por enquanto.',
    'biblioteca.openingHours.note': 'Nota (opcional)',
    'biblioteca.openingHours.notePlaceholder': 'Ex.: com hora marcada, fechado em agosto…',
    'account.mylib.hours': 'Horários / plantões',
  },
  fr: {
    'biblioteca.openingHours.title': "Horaires d'ouverture / permanences",
    'biblioteca.openingHours.hint': "Créneaux hebdomadaires — ajoute autant de plages que nécessaire (permanences, ouvertures…). Visible par les membres de la biblio.",
    'biblioteca.openingHours.start': 'Début',
    'biblioteca.openingHours.end': 'Fin',
    'biblioteca.openingHours.labelPlaceholder': 'Libellé (facultatif)',
    'biblioteca.openingHours.addSlot': '+ Ajouter un créneau',
    'biblioteca.openingHours.empty': "Aucun créneau défini pour l'instant.",
    'biblioteca.openingHours.note': 'Note (facultative)',
    'biblioteca.openingHours.notePlaceholder': 'Ex. : sur rendez-vous, fermé en août…',
    'account.mylib.hours': 'Horaires / permanences',
  },
  es: {
    'biblioteca.openingHours.title': 'Horarios de atención / turnos',
    'biblioteca.openingHours.hint': 'Franjas semanales — añade las que necesites (turnos, aperturas…). Visible para los miembros de la biblioteca.',
    'biblioteca.openingHours.start': 'Inicio',
    'biblioteca.openingHours.end': 'Fin',
    'biblioteca.openingHours.labelPlaceholder': 'Etiqueta (opcional)',
    'biblioteca.openingHours.addSlot': '+ Añadir franja',
    'biblioteca.openingHours.empty': 'Ninguna franja definida por ahora.',
    'biblioteca.openingHours.note': 'Nota (opcional)',
    'biblioteca.openingHours.notePlaceholder': 'Ej.: con cita previa, cerrado en agosto…',
    'account.mylib.hours': 'Horarios / turnos',
  },
  en: {
    'biblioteca.openingHours.title': 'Opening hours / shifts',
    'biblioteca.openingHours.hint': 'Weekly slots — add as many as you need (shifts, openings…). Visible to library members.',
    'biblioteca.openingHours.start': 'Start',
    'biblioteca.openingHours.end': 'End',
    'biblioteca.openingHours.labelPlaceholder': 'Label (optional)',
    'biblioteca.openingHours.addSlot': '+ Add a slot',
    'biblioteca.openingHours.empty': 'No slot defined yet.',
    'biblioteca.openingHours.note': 'Note (optional)',
    'biblioteca.openingHours.notePlaceholder': 'E.g. by appointment, closed in August…',
    'account.mylib.hours': 'Hours / shifts',
  },
  it: {
    'biblioteca.openingHours.title': 'Orari di apertura / turni',
    'biblioteca.openingHours.hint': 'Fasce settimanali — aggiungi quante ne servono (turni, aperture…). Visibile ai membri della biblioteca.',
    'biblioteca.openingHours.start': 'Inizio',
    'biblioteca.openingHours.end': 'Fine',
    'biblioteca.openingHours.labelPlaceholder': 'Etichetta (facoltativa)',
    'biblioteca.openingHours.addSlot': '+ Aggiungi fascia',
    'biblioteca.openingHours.empty': 'Nessuna fascia definita per ora.',
    'biblioteca.openingHours.note': 'Nota (facoltativa)',
    'biblioteca.openingHours.notePlaceholder': 'Es.: su appuntamento, chiuso ad agosto…',
    'account.mylib.hours': 'Orari / turni',
  },
  de: {
    'biblioteca.openingHours.title': 'Öffnungszeiten / Dienste',
    'biblioteca.openingHours.hint': 'Wöchentliche Zeitfenster — füge so viele hinzu wie nötig (Dienste, Öffnungen…). Sichtbar für Bibliotheksmitglieder.',
    'biblioteca.openingHours.start': 'Beginn',
    'biblioteca.openingHours.end': 'Ende',
    'biblioteca.openingHours.labelPlaceholder': 'Bezeichnung (optional)',
    'biblioteca.openingHours.addSlot': '+ Zeitfenster hinzufügen',
    'biblioteca.openingHours.empty': 'Noch kein Zeitfenster festgelegt.',
    'biblioteca.openingHours.note': 'Hinweis (optional)',
    'biblioteca.openingHours.notePlaceholder': 'Z. B. nach Vereinbarung, im August geschlossen…',
    'account.mylib.hours': 'Zeiten / Dienste',
  },
  ca: {
    'biblioteca.openingHours.title': "Horaris d'atenció / torns",
    'biblioteca.openingHours.hint': 'Franges setmanals — afegeix-ne tantes com calgui (torns, obertures…). Visible per als membres de la biblioteca.',
    'biblioteca.openingHours.start': 'Inici',
    'biblioteca.openingHours.end': 'Fi',
    'biblioteca.openingHours.labelPlaceholder': 'Etiqueta (opcional)',
    'biblioteca.openingHours.addSlot': '+ Afegeix una franja',
    'biblioteca.openingHours.empty': 'Cap franja definida de moment.',
    'biblioteca.openingHours.note': 'Nota (opcional)',
    'biblioteca.openingHours.notePlaceholder': "Ex.: amb cita prèvia, tancat a l'agost…",
    'account.mylib.hours': 'Horaris / torns',
  },
  eo: {
    'biblioteca.openingHours.title': 'Malfermaj horoj / deĵoroj',
    'biblioteca.openingHours.hint': 'Semajnaj fenestroj — aldonu kiom necesas (deĵoroj, malfermoj…). Videbla por la membroj de la biblioteko.',
    'biblioteca.openingHours.start': 'Komenco',
    'biblioteca.openingHours.end': 'Fino',
    'biblioteca.openingHours.labelPlaceholder': 'Etikedo (nedeviga)',
    'biblioteca.openingHours.addSlot': '+ Aldoni fenestron',
    'biblioteca.openingHours.empty': 'Ankoraŭ neniu fenestro difinita.',
    'biblioteca.openingHours.note': 'Noto (nedeviga)',
    'biblioteca.openingHours.notePlaceholder': 'Ekz.: laŭ interkonsento, fermita en aŭgusto…',
    'account.mylib.hours': 'Horoj / deĵoroj',
  },
  nl: {
    'biblioteca.openingHours.title': 'Openingsuren / diensten',
    'biblioteca.openingHours.hint': 'Wekelijkse tijdvakken — voeg er zoveel toe als nodig (diensten, openingen…). Zichtbaar voor bibliotheekleden.',
    'biblioteca.openingHours.start': 'Begin',
    'biblioteca.openingHours.end': 'Einde',
    'biblioteca.openingHours.labelPlaceholder': 'Label (optioneel)',
    'biblioteca.openingHours.addSlot': '+ Tijdvak toevoegen',
    'biblioteca.openingHours.empty': 'Nog geen tijdvak ingesteld.',
    'biblioteca.openingHours.note': 'Notitie (optioneel)',
    'biblioteca.openingHours.notePlaceholder': 'Bijv. op afspraak, gesloten in augustus…',
    'account.mylib.hours': 'Uren / diensten',
  },
  el: {
    'biblioteca.openingHours.title': 'Ώρες λειτουργίας / βάρδιες',
    'biblioteca.openingHours.hint': 'Εβδομαδιαία διαστήματα — πρόσθεσε όσα χρειάζεσαι (βάρδιες, ανοίγματα…). Ορατό στα μέλη της βιβλιοθήκης.',
    'biblioteca.openingHours.start': 'Έναρξη',
    'biblioteca.openingHours.end': 'Λήξη',
    'biblioteca.openingHours.labelPlaceholder': 'Ετικέτα (προαιρετική)',
    'biblioteca.openingHours.addSlot': '+ Προσθήκη διαστήματος',
    'biblioteca.openingHours.empty': 'Δεν έχει οριστεί διάστημα ακόμη.',
    'biblioteca.openingHours.note': 'Σημείωση (προαιρετική)',
    'biblioteca.openingHours.notePlaceholder': 'Π.χ. κατόπιν ραντεβού, κλειστά τον Αύγουστο…',
    'account.mylib.hours': 'Ώρες / βάρδιες',
  },
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes('"' + SENTINEL + '"')) {
    const map = ADD[loc];
    const keys = Object.keys(ADD['pt-BR']);
    const entries = keys.map((k) => {
      if (map[k] == null) throw new Error('Traduction manquante: ' + k + ' / ' + loc);
      return '  ' + JSON.stringify(k) + ': ' + JSON.stringify(map[k]);
    });
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entries.join(',\n') + '\n' + content.slice(marker);
    if (!content.endsWith('\n')) content += '\n';
    fs.writeFileSync(file, content, 'utf8');
  }
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ': 10 clés (si absentes), JSON valide.');
}
console.log('\nTerminé.');
