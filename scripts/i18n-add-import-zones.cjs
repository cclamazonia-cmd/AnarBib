#!/usr/bin/env node
/**
 * i18n-add-import-zones.cjs — H17/H18 (27/09/2026), aller-retour PMB.
 *
 * Clés ajoutées dans les 10 locales :
 *  - couverture d'un import : le statut « laissé exprès » (importacoes.coverage.
 *    status.laisse), son compte (countsLaisse) et ses six motifs
 *    (importacoes.coverage.motif.*, codes de _shared/marc/correspondance.ts) ;
 *  - rapport de lot : les rapprochements d'autorité PROPOSÉS pour les
 *    contributeurs sans autorité (review.report.contributors.*).
 * Tutoiement partout ; pt-BR au « você ». Idempotent.
 */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const ADD = {
  fr: {
    'importacoes.coverage.status.laisse': 'laissé exprès',
    'importacoes.coverage.countsLaisse': '{n, plural, one {# élément laissé exprès} other {# éléments laissés exprès}} : sans champ dans AnarBib, ou propre au logiciel d’origine — gardé dans l’enregistrement d’origine.',
    'importacoes.coverage.motif.interne': 'donnée interne au logiciel d’origine',
    'importacoes.coverage.motif.sans_champ': 'sans champ dans AnarBib',
    'importacoes.coverage.motif.redondant': 'redit une zone reprise',
    'importacoes.coverage.motif.materiel': 'description matérielle au-delà de la pagination',
    'importacoes.coverage.motif.liens': 'lien entre notices propre au logiciel d’origine',
    'importacoes.coverage.motif.codees': 'données codées de traitement',
    'review.report.contributors.title': 'Contributeurs sans autorité',
    'review.report.contributors.intro': 'L’import ne rattache aucune autorité d’office. Pour chaque contributeur sans autorité, la recherche par nom propose une fiche : à toi de rattacher, ou non.',
    'review.report.contributors.search': 'Chercher les fiches d’autorité',
    'review.report.contributors.searching': 'Recherche…',
    'review.report.contributors.none': 'Aucune fiche proposée pour les contributeurs sans autorité de ce lot.',
    'review.report.contributors.count': '{n, plural, one {# fiche proposée} other {# fiches proposées}}',
    'review.report.contributors.link': 'Rattacher',
    'review.report.contributors.linked': 'Rattaché',
    'review.report.contributors.linkFailed': 'Pas rattaché : la ligne a changé depuis, ou tu n’as pas les droits. Relance la recherche.',
  },
  'pt-BR': {
    'importacoes.coverage.status.laisse': 'deixado de propósito',
    'importacoes.coverage.countsLaisse': '{n, plural, one {# elemento deixado de propósito} other {# elementos deixados de propósito}}: sem campo no AnarBib, ou próprio do software de origem — guardado no registro de origem.',
    'importacoes.coverage.motif.interne': 'dado interno do software de origem',
    'importacoes.coverage.motif.sans_champ': 'sem campo no AnarBib',
    'importacoes.coverage.motif.redondant': 'repete um campo já importado',
    'importacoes.coverage.motif.materiel': 'descrição física além da paginação',
    'importacoes.coverage.motif.liens': 'vínculo entre registros próprio do software de origem',
    'importacoes.coverage.motif.codees': 'dados codificados de processamento',
    'review.report.contributors.title': 'Contribuidores sem autoridade',
    'review.report.contributors.intro': 'A importação não vincula nenhuma autoridade automaticamente. Para cada contribuidor sem autoridade, a busca por nome propõe um registro: você decide se vincula ou não.',
    'review.report.contributors.search': 'Buscar registros de autoridade',
    'review.report.contributors.searching': 'Buscando…',
    'review.report.contributors.none': 'Nenhum registro proposto para os contribuidores sem autoridade deste lote.',
    'review.report.contributors.count': '{n, plural, one {# registro proposto} other {# registros propostos}}',
    'review.report.contributors.link': 'Vincular',
    'review.report.contributors.linked': 'Vinculado',
    'review.report.contributors.linkFailed': 'Não vinculado: a linha mudou desde então, ou você não tem permissão. Refaça a busca.',
  },
  es: {
    'importacoes.coverage.status.laisse': 'dejado a propósito',
    'importacoes.coverage.countsLaisse': '{n, plural, one {# elemento dejado a propósito} other {# elementos dejados a propósito}}: sin campo en AnarBib, o propio del programa de origen — guardado en el registro de origen.',
    'importacoes.coverage.motif.interne': 'dato interno del programa de origen',
    'importacoes.coverage.motif.sans_champ': 'sin campo en AnarBib',
    'importacoes.coverage.motif.redondant': 'repite un campo ya importado',
    'importacoes.coverage.motif.materiel': 'descripción física más allá de la paginación',
    'importacoes.coverage.motif.liens': 'vínculo entre registros propio del programa de origen',
    'importacoes.coverage.motif.codees': 'datos codificados de proceso',
    'review.report.contributors.title': 'Contribuidores sin autoridad',
    'review.report.contributors.intro': 'La importación no vincula ninguna autoridad de oficio. Para cada contribuidor sin autoridad, la búsqueda por nombre propone un registro: tú decides si lo vinculas o no.',
    'review.report.contributors.search': 'Buscar registros de autoridad',
    'review.report.contributors.searching': 'Buscando…',
    'review.report.contributors.none': 'Ningún registro propuesto para los contribuidores sin autoridad de este lote.',
    'review.report.contributors.count': '{n, plural, one {# registro propuesto} other {# registros propuestos}}',
    'review.report.contributors.link': 'Vincular',
    'review.report.contributors.linked': 'Vinculado',
    'review.report.contributors.linkFailed': 'No vinculado: la línea cambió desde entonces, o no tienes permiso. Vuelve a buscar.',
  },
  en: {
    'importacoes.coverage.status.laisse': 'left on purpose',
    'importacoes.coverage.countsLaisse': '{n, plural, one {# element left on purpose} other {# elements left on purpose}}: no field in AnarBib, or specific to the source software — kept in the original record.',
    'importacoes.coverage.motif.interne': 'internal data of the source software',
    'importacoes.coverage.motif.sans_champ': 'no field in AnarBib',
    'importacoes.coverage.motif.redondant': 'repeats a field already imported',
    'importacoes.coverage.motif.materiel': 'physical description beyond the page count',
    'importacoes.coverage.motif.liens': 'link between records specific to the source software',
    'importacoes.coverage.motif.codees': 'coded processing data',
    'review.report.contributors.title': 'Contributors without an authority',
    'review.report.contributors.intro': 'The import never links an authority on its own. For each contributor without an authority, the name search proposes a record: you decide whether to link it.',
    'review.report.contributors.search': 'Look up authority records',
    'review.report.contributors.searching': 'Searching…',
    'review.report.contributors.none': 'No record proposed for the contributors without an authority in this batch.',
    'review.report.contributors.count': '{n, plural, one {# record proposed} other {# records proposed}}',
    'review.report.contributors.link': 'Link',
    'review.report.contributors.linked': 'Linked',
    'review.report.contributors.linkFailed': 'Not linked: the row has changed since, or you lack permission. Run the search again.',
  },
  ca: {
    'importacoes.coverage.status.laisse': 'deixat expressament',
    'importacoes.coverage.countsLaisse': '{n, plural, one {# element deixat expressament} other {# elements deixats expressament}}: sense camp a AnarBib, o propi del programari d’origen — desat al registre d’origen.',
    'importacoes.coverage.motif.interne': 'dada interna del programari d’origen',
    'importacoes.coverage.motif.sans_champ': 'sense camp a AnarBib',
    'importacoes.coverage.motif.redondant': 'repeteix un camp ja importat',
    'importacoes.coverage.motif.materiel': 'descripció física més enllà de la paginació',
    'importacoes.coverage.motif.liens': 'enllaç entre registres propi del programari d’origen',
    'importacoes.coverage.motif.codees': 'dades codificades de processament',
    'review.report.contributors.title': 'Col·laboradors sense autoritat',
    'review.report.contributors.intro': 'La importació no vincula cap autoritat d’ofici. Per a cada col·laborador sense autoritat, la cerca per nom proposa un registre: tu decideixes si el vincules o no.',
    'review.report.contributors.search': 'Cercar registres d’autoritat',
    'review.report.contributors.searching': 'Cercant…',
    'review.report.contributors.none': 'Cap registre proposat per als col·laboradors sense autoritat d’aquest lot.',
    'review.report.contributors.count': '{n, plural, one {# registre proposat} other {# registres proposats}}',
    'review.report.contributors.link': 'Vincular',
    'review.report.contributors.linked': 'Vinculat',
    'review.report.contributors.linkFailed': 'No vinculat: la línia ha canviat des de llavors, o no tens permís. Torna a cercar.',
  },
  de: {
    'importacoes.coverage.status.laisse': 'bewusst ausgelassen',
    'importacoes.coverage.countsLaisse': '{n, plural, one {# Element bewusst ausgelassen} other {# Elemente bewusst ausgelassen}}: kein Feld in AnarBib oder eigen der Ursprungssoftware — im ursprünglichen Datensatz aufbewahrt.',
    'importacoes.coverage.motif.interne': 'interne Angabe der Ursprungssoftware',
    'importacoes.coverage.motif.sans_champ': 'kein Feld in AnarBib',
    'importacoes.coverage.motif.redondant': 'wiederholt ein bereits übernommenes Feld',
    'importacoes.coverage.motif.materiel': 'physische Beschreibung über die Seitenzahl hinaus',
    'importacoes.coverage.motif.liens': 'Verknüpfung zwischen Datensätzen, eigen der Ursprungssoftware',
    'importacoes.coverage.motif.codees': 'codierte Verarbeitungsdaten',
    'review.report.contributors.title': 'Mitwirkende ohne Normdatensatz',
    'review.report.contributors.intro': 'Der Import verknüpft nie von selbst einen Normdatensatz. Für jede mitwirkende Person ohne Normdatensatz schlägt die Namenssuche einen Datensatz vor: du entscheidest, ob du ihn verknüpfst.',
    'review.report.contributors.search': 'Normdatensätze suchen',
    'review.report.contributors.searching': 'Suche…',
    'review.report.contributors.none': 'Für die Mitwirkenden ohne Normdatensatz in diesem Stapel wird kein Datensatz vorgeschlagen.',
    'review.report.contributors.count': '{n, plural, one {# vorgeschlagener Datensatz} other {# vorgeschlagene Datensätze}}',
    'review.report.contributors.link': 'Verknüpfen',
    'review.report.contributors.linked': 'Verknüpft',
    'review.report.contributors.linkFailed': 'Nicht verknüpft: Die Zeile hat sich seitdem geändert, oder dir fehlt die Berechtigung. Suche erneut.',
  },
  el: {
    'importacoes.coverage.status.laisse': 'αφέθηκε σκόπιμα',
    'importacoes.coverage.countsLaisse': '{n, plural, one {# στοιχείο αφέθηκε σκόπιμα} other {# στοιχεία αφέθηκαν σκόπιμα}}: χωρίς πεδίο στο AnarBib, ή ίδιο του λογισμικού προέλευσης — φυλάσσεται στην αρχική εγγραφή.',
    'importacoes.coverage.motif.interne': 'εσωτερικό δεδομένο του λογισμικού προέλευσης',
    'importacoes.coverage.motif.sans_champ': 'χωρίς πεδίο στο AnarBib',
    'importacoes.coverage.motif.redondant': 'επαναλαμβάνει ένα πεδίο που ήδη εισήχθη',
    'importacoes.coverage.motif.materiel': 'φυσική περιγραφή πέρα από τη σελιδαρίθμηση',
    'importacoes.coverage.motif.liens': 'σύνδεση μεταξύ εγγραφών ίδια του λογισμικού προέλευσης',
    'importacoes.coverage.motif.codees': 'κωδικοποιημένα δεδομένα επεξεργασίας',
    'review.report.contributors.title': 'Συντελεστές χωρίς καθιερωμένο όνομα',
    'review.report.contributors.intro': 'Η εισαγωγή δεν συνδέει ποτέ αυτόματα ένα καθιερωμένο όνομα. Για κάθε συντελεστή χωρίς καθιερωμένο όνομα, η αναζήτηση με όνομα προτείνει μια εγγραφή: εσύ αποφασίζεις αν θα τη συνδέσεις.',
    'review.report.contributors.search': 'Αναζήτηση εγγραφών καθιερωμένων ονομάτων',
    'review.report.contributors.searching': 'Αναζήτηση…',
    'review.report.contributors.none': 'Καμία εγγραφή δεν προτείνεται για τους συντελεστές χωρίς καθιερωμένο όνομα αυτής της παρτίδας.',
    'review.report.contributors.count': '{n, plural, one {# προτεινόμενη εγγραφή} other {# προτεινόμενες εγγραφές}}',
    'review.report.contributors.link': 'Σύνδεση',
    'review.report.contributors.linked': 'Συνδέθηκε',
    'review.report.contributors.linkFailed': 'Δεν συνδέθηκε: η γραμμή άλλαξε στο μεταξύ ή δεν έχεις δικαίωμα. Ξαναρχίζεις την αναζήτηση.',
  },
  eo: {
    'importacoes.coverage.status.laisse': 'intence lasita',
    'importacoes.coverage.countsLaisse': '{n, plural, one {# elemento intence lasita} other {# elementoj intence lasitaj}}: sen kampo en AnarBib, aŭ propra al la origina programo — konservita en la origina registro.',
    'importacoes.coverage.motif.interne': 'interna datumo de la origina programo',
    'importacoes.coverage.motif.sans_champ': 'sen kampo en AnarBib',
    'importacoes.coverage.motif.redondant': 'ripetas kampon jam importitan',
    'importacoes.coverage.motif.materiel': 'fizika priskribo preter la paĝnombro',
    'importacoes.coverage.motif.liens': 'ligo inter registroj propra al la origina programo',
    'importacoes.coverage.motif.codees': 'koditaj pritraktaj datumoj',
    'review.report.contributors.title': 'Kontribuantoj sen aŭtoritato',
    'review.report.contributors.intro': 'La importo neniam ligas aŭtoritaton memstare. Por ĉiu kontribuanto sen aŭtoritato, la serĉo laŭ nomo proponas registron: vi decidas, ĉu ligi ĝin.',
    'review.report.contributors.search': 'Serĉi aŭtoritatajn registrojn',
    'review.report.contributors.searching': 'Serĉado…',
    'review.report.contributors.none': 'Neniu registro proponita por la kontribuantoj sen aŭtoritato de ĉi tiu loto.',
    'review.report.contributors.count': '{n, plural, one {# proponita registro} other {# proponitaj registroj}}',
    'review.report.contributors.link': 'Ligi',
    'review.report.contributors.linked': 'Ligita',
    'review.report.contributors.linkFailed': 'Ne ligita: la linio ŝanĝiĝis intertempe, aŭ vi ne rajtas. Serĉu denove.',
  },
  it: {
    'importacoes.coverage.status.laisse': 'lasciato di proposito',
    'importacoes.coverage.countsLaisse': '{n, plural, one {# elemento lasciato di proposito} other {# elementi lasciati di proposito}}: senza campo in AnarBib, o proprio del software d’origine — conservato nel record d’origine.',
    'importacoes.coverage.motif.interne': 'dato interno del software d’origine',
    'importacoes.coverage.motif.sans_champ': 'senza campo in AnarBib',
    'importacoes.coverage.motif.redondant': 'ripete un campo già importato',
    'importacoes.coverage.motif.materiel': 'descrizione fisica oltre la paginazione',
    'importacoes.coverage.motif.liens': 'collegamento tra record proprio del software d’origine',
    'importacoes.coverage.motif.codees': 'dati codificati di trattamento',
    'review.report.contributors.title': 'Contributori senza autorità',
    'review.report.contributors.intro': 'L’importazione non collega mai d’ufficio un’autorità. Per ogni contributore senza autorità, la ricerca per nome propone una scheda: decidi tu se collegarla.',
    'review.report.contributors.search': 'Cerca le schede di autorità',
    'review.report.contributors.searching': 'Ricerca…',
    'review.report.contributors.none': 'Nessuna scheda proposta per i contributori senza autorità di questo lotto.',
    'review.report.contributors.count': '{n, plural, one {# scheda proposta} other {# schede proposte}}',
    'review.report.contributors.link': 'Collega',
    'review.report.contributors.linked': 'Collegato',
    'review.report.contributors.linkFailed': 'Non collegato: la riga è cambiata nel frattempo, o non hai i permessi. Rifai la ricerca.',
  },
  nl: {
    'importacoes.coverage.status.laisse': 'bewust weggelaten',
    'importacoes.coverage.countsLaisse': '{n, plural, one {# element bewust weggelaten} other {# elementen bewust weggelaten}}: geen veld in AnarBib, of eigen aan de bronsoftware — bewaard in het oorspronkelijke record.',
    'importacoes.coverage.motif.interne': 'interne gegevens van de bronsoftware',
    'importacoes.coverage.motif.sans_champ': 'geen veld in AnarBib',
    'importacoes.coverage.motif.redondant': 'herhaalt een al geïmporteerd veld',
    'importacoes.coverage.motif.materiel': 'fysieke beschrijving buiten de paginering',
    'importacoes.coverage.motif.liens': 'koppeling tussen records, eigen aan de bronsoftware',
    'importacoes.coverage.motif.codees': 'gecodeerde verwerkingsgegevens',
    'review.report.contributors.title': 'Bijdragers zonder autoriteit',
    'review.report.contributors.intro': 'De import koppelt nooit uit zichzelf een autoriteit. Voor elke bijdrager zonder autoriteit stelt het zoeken op naam een record voor: jij beslist of je het koppelt.',
    'review.report.contributors.search': 'Autoriteitsrecords zoeken',
    'review.report.contributors.searching': 'Zoeken…',
    'review.report.contributors.none': 'Geen record voorgesteld voor de bijdragers zonder autoriteit in dit lot.',
    'review.report.contributors.count': '{n, plural, one {# voorgesteld record} other {# voorgestelde records}}',
    'review.report.contributors.link': 'Koppelen',
    'review.report.contributors.linked': 'Gekoppeld',
    'review.report.contributors.linkFailed': 'Niet gekoppeld: de regel is intussen gewijzigd, of je hebt geen rechten. Zoek opnieuw.',
  },
};

let total = 0;
for (const loc of LOCALES) {
  const f = path.join(DIR, `${loc}.json`);
  const j = JSON.parse(fs.readFileSync(f, 'utf8'));
  const add = ADD[loc];
  if (!add || Object.keys(add).length !== Object.keys(ADD.fr).length
      || Object.keys(ADD.fr).some((k) => !(k in add))) throw new Error(`${loc} : traductions incomplètes`);
  let n = 0;
  for (const [k, v] of Object.entries(add)) {
    if (!(k in j)) { j[k] = v; n++; }
  }
  fs.writeFileSync(f, JSON.stringify(j, null, 2) + '\n');
  total += n;
  console.log(`${loc}: +${n}`);
}
console.log(`total : ${total}`);
