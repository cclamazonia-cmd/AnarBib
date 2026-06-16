/* ===========================================================================
 * i18n-add-federacao-assembleias-fac.cjs
 * UI de facilitation (P2b-front) : 18 clés federacao.assembleias.fac.*
 * (créer une assemblée, jalons de dates, statut, différer) dans les 10 locales.
 * Insertion idempotente (sentinelle federacao.assembleias.fac.create).
 * Auteur : Claude (assistant)
 * Session : Fédération — Assemblée du réseau (AG)
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'federacao.assembleias.fac.create';

const ADD = {
  'pt-BR': {
    "federacao.assembleias.fac.create": "Criar uma assembleia",
    "federacao.assembleias.fac.create.titlePlaceholder": "Título da assembleia (ex.: « AG da rede — outono 2026 »)",
    "federacao.assembleias.fac.create.kindLabel": "Tipo",
    "federacao.assembleias.fac.create.kindConstituinte": "Constituinte (1ª AG)",
    "federacao.assembleias.fac.create.kindOrdinaria": "Ordinária",
    "federacao.assembleias.fac.create.submit": "Criar",
    "federacao.assembleias.fac.create.titleRequired": "Dê um título à assembleia.",
    "federacao.assembleias.fac.create.done": "Assembleia criada.",
    "federacao.assembleias.fac.tools": "Ferramentas de facilitação",
    "federacao.assembleias.fac.status.label": "Estado",
    "federacao.assembleias.fac.dates.edit": "Definir as datas (marcos)",
    "federacao.assembleias.fac.dates.convocation": "Convocação (D-30)",
    "federacao.assembleias.fac.dates.deadline": "Encerramento das inscrições (D-15)",
    "federacao.assembleias.fac.dates.published": "Ordem do dia publicada (~D-10)",
    "federacao.assembleias.fac.dates.scheduled": "Realização (D-0)",
    "federacao.assembleias.fac.dates.save": "Salvar as datas",
    "federacao.assembleias.fac.saved": "Alterado.",
    "federacao.assembleias.fac.defer": "Adiar"
  },
  fr: {
    "federacao.assembleias.fac.create": "Créer une assemblée",
    "federacao.assembleias.fac.create.titlePlaceholder": "Titre de l’assemblée (ex. « AG du réseau — automne 2026 »)",
    "federacao.assembleias.fac.create.kindLabel": "Type",
    "federacao.assembleias.fac.create.kindConstituinte": "Constituante (1ʳᵉ AG)",
    "federacao.assembleias.fac.create.kindOrdinaria": "Ordinaire",
    "federacao.assembleias.fac.create.submit": "Créer",
    "federacao.assembleias.fac.create.titleRequired": "Donne un titre à l’assemblée.",
    "federacao.assembleias.fac.create.done": "Assemblée créée.",
    "federacao.assembleias.fac.tools": "Outils de facilitation",
    "federacao.assembleias.fac.status.label": "Statut",
    "federacao.assembleias.fac.dates.edit": "Poser les dates (jalons)",
    "federacao.assembleias.fac.dates.convocation": "Convocation (J-30)",
    "federacao.assembleias.fac.dates.deadline": "Clôture des dépôts (J-15)",
    "federacao.assembleias.fac.dates.published": "ODJ publié (~J-10)",
    "federacao.assembleias.fac.dates.scheduled": "Tenue (J-0)",
    "federacao.assembleias.fac.dates.save": "Enregistrer les dates",
    "federacao.assembleias.fac.saved": "Modifié.",
    "federacao.assembleias.fac.defer": "Différer"
  },
  es: {
    "federacao.assembleias.fac.create": "Crear una asamblea",
    "federacao.assembleias.fac.create.titlePlaceholder": "Título de la asamblea (ej.: « AG de la red — otoño 2026 »)",
    "federacao.assembleias.fac.create.kindLabel": "Tipo",
    "federacao.assembleias.fac.create.kindConstituinte": "Constituyente (1ª AG)",
    "federacao.assembleias.fac.create.kindOrdinaria": "Ordinaria",
    "federacao.assembleias.fac.create.submit": "Crear",
    "federacao.assembleias.fac.create.titleRequired": "Ponle un título a la asamblea.",
    "federacao.assembleias.fac.create.done": "Asamblea creada.",
    "federacao.assembleias.fac.tools": "Herramientas de facilitación",
    "federacao.assembleias.fac.status.label": "Estado",
    "federacao.assembleias.fac.dates.edit": "Definir las fechas (hitos)",
    "federacao.assembleias.fac.dates.convocation": "Convocatoria (D-30)",
    "federacao.assembleias.fac.dates.deadline": "Cierre de inscripciones (D-15)",
    "federacao.assembleias.fac.dates.published": "Orden del día publicado (~D-10)",
    "federacao.assembleias.fac.dates.scheduled": "Celebración (D-0)",
    "federacao.assembleias.fac.dates.save": "Guardar las fechas",
    "federacao.assembleias.fac.saved": "Modificado.",
    "federacao.assembleias.fac.defer": "Aplazar"
  },
  en: {
    "federacao.assembleias.fac.create": "Create an assembly",
    "federacao.assembleias.fac.create.titlePlaceholder": "Assembly title (e.g. “Network AG — autumn 2026”)",
    "federacao.assembleias.fac.create.kindLabel": "Type",
    "federacao.assembleias.fac.create.kindConstituinte": "Constituent (1st AG)",
    "federacao.assembleias.fac.create.kindOrdinaria": "Ordinary",
    "federacao.assembleias.fac.create.submit": "Create",
    "federacao.assembleias.fac.create.titleRequired": "Give the assembly a title.",
    "federacao.assembleias.fac.create.done": "Assembly created.",
    "federacao.assembleias.fac.tools": "Facilitation tools",
    "federacao.assembleias.fac.status.label": "Status",
    "federacao.assembleias.fac.dates.edit": "Set the dates (milestones)",
    "federacao.assembleias.fac.dates.convocation": "Convening (D-30)",
    "federacao.assembleias.fac.dates.deadline": "Submissions close (D-15)",
    "federacao.assembleias.fac.dates.published": "Agenda published (~D-10)",
    "federacao.assembleias.fac.dates.scheduled": "Held (D-0)",
    "federacao.assembleias.fac.dates.save": "Save the dates",
    "federacao.assembleias.fac.saved": "Updated.",
    "federacao.assembleias.fac.defer": "Defer"
  },
  it: {
    "federacao.assembleias.fac.create": "Creare un’assemblea",
    "federacao.assembleias.fac.create.titlePlaceholder": "Titolo dell’assemblea (es.: « AG della rete — autunno 2026 »)",
    "federacao.assembleias.fac.create.kindLabel": "Tipo",
    "federacao.assembleias.fac.create.kindConstituinte": "Costituente (1ª AG)",
    "federacao.assembleias.fac.create.kindOrdinaria": "Ordinaria",
    "federacao.assembleias.fac.create.submit": "Creare",
    "federacao.assembleias.fac.create.titleRequired": "Dai un titolo all’assemblea.",
    "federacao.assembleias.fac.create.done": "Assemblea creata.",
    "federacao.assembleias.fac.tools": "Strumenti di facilitazione",
    "federacao.assembleias.fac.status.label": "Stato",
    "federacao.assembleias.fac.dates.edit": "Definire le date (tappe)",
    "federacao.assembleias.fac.dates.convocation": "Convocazione (G-30)",
    "federacao.assembleias.fac.dates.deadline": "Chiusura delle proposte (G-15)",
    "federacao.assembleias.fac.dates.published": "Ordine del giorno pubblicato (~G-10)",
    "federacao.assembleias.fac.dates.scheduled": "Svolgimento (G-0)",
    "federacao.assembleias.fac.dates.save": "Salvare le date",
    "federacao.assembleias.fac.saved": "Modificato.",
    "federacao.assembleias.fac.defer": "Rinviare"
  },
  de: {
    "federacao.assembleias.fac.create": "Eine Versammlung anlegen",
    "federacao.assembleias.fac.create.titlePlaceholder": "Titel der Versammlung (z. B. „Netzwerk-VV — Herbst 2026“)",
    "federacao.assembleias.fac.create.kindLabel": "Art",
    "federacao.assembleias.fac.create.kindConstituinte": "Konstituierend (1. VV)",
    "federacao.assembleias.fac.create.kindOrdinaria": "Ordentlich",
    "federacao.assembleias.fac.create.submit": "Anlegen",
    "federacao.assembleias.fac.create.titleRequired": "Gib der Versammlung einen Titel.",
    "federacao.assembleias.fac.create.done": "Versammlung angelegt.",
    "federacao.assembleias.fac.tools": "Moderationswerkzeuge",
    "federacao.assembleias.fac.status.label": "Status",
    "federacao.assembleias.fac.dates.edit": "Termine festlegen (Etappen)",
    "federacao.assembleias.fac.dates.convocation": "Einberufung (T-30)",
    "federacao.assembleias.fac.dates.deadline": "Einreichungsschluss (T-15)",
    "federacao.assembleias.fac.dates.published": "Tagesordnung veröffentlicht (~T-10)",
    "federacao.assembleias.fac.dates.scheduled": "Durchführung (T-0)",
    "federacao.assembleias.fac.dates.save": "Termine speichern",
    "federacao.assembleias.fac.saved": "Geändert.",
    "federacao.assembleias.fac.defer": "Vertagen"
  },
  ca: {
    "federacao.assembleias.fac.create": "Crear una assemblea",
    "federacao.assembleias.fac.create.titlePlaceholder": "Títol de l’assemblea (ex.: « AG de la xarxa — tardor 2026 »)",
    "federacao.assembleias.fac.create.kindLabel": "Tipus",
    "federacao.assembleias.fac.create.kindConstituinte": "Constituent (1a AG)",
    "federacao.assembleias.fac.create.kindOrdinaria": "Ordinària",
    "federacao.assembleias.fac.create.submit": "Crear",
    "federacao.assembleias.fac.create.titleRequired": "Posa un títol a l’assemblea.",
    "federacao.assembleias.fac.create.done": "Assemblea creada.",
    "federacao.assembleias.fac.tools": "Eines de facilitació",
    "federacao.assembleias.fac.status.label": "Estat",
    "federacao.assembleias.fac.dates.edit": "Definir les dates (fites)",
    "federacao.assembleias.fac.dates.convocation": "Convocatòria (D-30)",
    "federacao.assembleias.fac.dates.deadline": "Tancament de les inscripcions (D-15)",
    "federacao.assembleias.fac.dates.published": "Ordre del dia publicat (~D-10)",
    "federacao.assembleias.fac.dates.scheduled": "Realització (D-0)",
    "federacao.assembleias.fac.dates.save": "Desar les dates",
    "federacao.assembleias.fac.saved": "Modificat.",
    "federacao.assembleias.fac.defer": "Ajornar"
  },
  eo: {
    "federacao.assembleias.fac.create": "Krei asembleon",
    "federacao.assembleias.fac.create.titlePlaceholder": "Titolo de la asembleo (ekz.: « Reta AG — aŭtuno 2026 »)",
    "federacao.assembleias.fac.create.kindLabel": "Tipo",
    "federacao.assembleias.fac.create.kindConstituinte": "Konstituanta (1ª AG)",
    "federacao.assembleias.fac.create.kindOrdinaria": "Ordinara",
    "federacao.assembleias.fac.create.submit": "Krei",
    "federacao.assembleias.fac.create.titleRequired": "Donu titolon al la asembleo.",
    "federacao.assembleias.fac.create.done": "Asembleo kreita.",
    "federacao.assembleias.fac.tools": "Faciligaj iloj",
    "federacao.assembleias.fac.status.label": "Stato",
    "federacao.assembleias.fac.dates.edit": "Difini la datojn (etapoj)",
    "federacao.assembleias.fac.dates.convocation": "Kunvoko (T-30)",
    "federacao.assembleias.fac.dates.deadline": "Fino de la enskriboj (T-15)",
    "federacao.assembleias.fac.dates.published": "Tagordo publikigita (~T-10)",
    "federacao.assembleias.fac.dates.scheduled": "Okazigo (T-0)",
    "federacao.assembleias.fac.dates.save": "Konservi la datojn",
    "federacao.assembleias.fac.saved": "Ŝanĝita.",
    "federacao.assembleias.fac.defer": "Prokrasti"
  },
  nl: {
    "federacao.assembleias.fac.create": "Een vergadering aanmaken",
    "federacao.assembleias.fac.create.titlePlaceholder": "Titel van de vergadering (bv. „Netwerk-AV — najaar 2026”)",
    "federacao.assembleias.fac.create.kindLabel": "Type",
    "federacao.assembleias.fac.create.kindConstituinte": "Constituerend (1e AV)",
    "federacao.assembleias.fac.create.kindOrdinaria": "Gewoon",
    "federacao.assembleias.fac.create.submit": "Aanmaken",
    "federacao.assembleias.fac.create.titleRequired": "Geef de vergadering een titel.",
    "federacao.assembleias.fac.create.done": "Vergadering aangemaakt.",
    "federacao.assembleias.fac.tools": "Facilitatiegereedschap",
    "federacao.assembleias.fac.status.label": "Status",
    "federacao.assembleias.fac.dates.edit": "De data bepalen (mijlpalen)",
    "federacao.assembleias.fac.dates.convocation": "Bijeenroeping (D-30)",
    "federacao.assembleias.fac.dates.deadline": "Sluiting van de indieningen (D-15)",
    "federacao.assembleias.fac.dates.published": "Agenda gepubliceerd (~D-10)",
    "federacao.assembleias.fac.dates.scheduled": "Plaatsvinden (D-0)",
    "federacao.assembleias.fac.dates.save": "Data opslaan",
    "federacao.assembleias.fac.saved": "Gewijzigd.",
    "federacao.assembleias.fac.defer": "Uitstellen"
  },
  el: {
    "federacao.assembleias.fac.create": "Δημιουργία συνέλευσης",
    "federacao.assembleias.fac.create.titlePlaceholder": "Τίτλος της συνέλευσης (π.χ. « ΓΣ του δικτύου — φθινόπωρο 2026 »)",
    "federacao.assembleias.fac.create.kindLabel": "Τύπος",
    "federacao.assembleias.fac.create.kindConstituinte": "Καταστατική (1η ΓΣ)",
    "federacao.assembleias.fac.create.kindOrdinaria": "Τακτική",
    "federacao.assembleias.fac.create.submit": "Δημιουργία",
    "federacao.assembleias.fac.create.titleRequired": "Δώσε έναν τίτλο στη συνέλευση.",
    "federacao.assembleias.fac.create.done": "Η συνέλευση δημιουργήθηκε.",
    "federacao.assembleias.fac.tools": "Εργαλεία διευκόλυνσης",
    "federacao.assembleias.fac.status.label": "Κατάσταση",
    "federacao.assembleias.fac.dates.edit": "Ορισμός των ημερομηνιών (ορόσημα)",
    "federacao.assembleias.fac.dates.convocation": "Σύγκληση (Η-30)",
    "federacao.assembleias.fac.dates.deadline": "Λήξη υποβολών (Η-15)",
    "federacao.assembleias.fac.dates.published": "Ημερήσια διάταξη δημοσιευμένη (~Η-10)",
    "federacao.assembleias.fac.dates.scheduled": "Διεξαγωγή (Η-0)",
    "federacao.assembleias.fac.dates.save": "Αποθήκευση των ημερομηνιών",
    "federacao.assembleias.fac.saved": "Τροποποιήθηκε.",
    "federacao.assembleias.fac.defer": "Αναβολή"
  }
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
  }
  fs.writeFileSync(file, content, 'utf8');
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ': 18 clés fac.* (si absentes), JSON valide.');
}
console.log('\nTerminé.');
