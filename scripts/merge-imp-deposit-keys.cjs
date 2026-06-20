/**
 * Merge deposit (format maison) i18n keys into all 10 locale files.
 * Run: node scripts/merge-imp-deposit-keys.cjs
 * Session : Lot 2 – Fontes externas bout-en-bout (format maison)
 */
const fs = require('fs');
const path = require('path');

const LOCALES_DIR = path.resolve(__dirname, '../src/i18n/locales');

const NEW_KEYS = {
  'pt-BR': {
    'importacoes.deposit.title': 'Deposito formato caseiro',
    'importacoes.deposit.pill': 'CSV · RIS · BibTeX',
    'importacoes.deposit.desc': 'Uma biblioteca parceira exporta seu catalogo e deposita o arquivo aqui. Selecione ou registre a fonte, depois carregue o arquivo — o pipeline cuida do resto.',
    'importacoes.deposit.source': 'Fonte parceira',
    'importacoes.deposit.selectSource': 'Selecione uma fonte…',
    'importacoes.deposit.newPartner': 'Novo(a/e) parceir(o/a/e)',
    'importacoes.deposit.partnerPlaceholder': 'Ex: Biblioteca La Brique',
    'importacoes.deposit.fileLabel': 'Arquivo de catalogo',
    'importacoes.deposit.uploadBtn': 'Depositar e processar',
    'importacoes.deposit.uploading': 'Deposito em andamento…',
    'importacoes.deposit.processed': '{filename} processado(a/e) (formato {format})',
    'importacoes.deposit.registered': 'Fonte « {name} » registrada.',
    'importacoes.deposit.alreadyExists': 'Fonte « {name} » ja existia.',
  },
  fr: {
    'importacoes.deposit.title': 'Depot format maison',
    'importacoes.deposit.pill': 'CSV · RIS · BibTeX',
    'importacoes.deposit.desc': 'Une bibliotheque partenaire exporte son catalogue et depose le fichier ici. Selectionnez ou enregistrez la source, puis chargez le fichier — le pipeline fait le reste.',
    'importacoes.deposit.source': 'Source partenaire',
    'importacoes.deposit.selectSource': 'Selectionnez une source…',
    'importacoes.deposit.newPartner': 'Nouveau·elle partenaire',
    'importacoes.deposit.partnerPlaceholder': 'Ex : Bibliotheque La Brique',
    'importacoes.deposit.fileLabel': 'Fichier de catalogue',
    'importacoes.deposit.uploadBtn': 'Deposer et traiter',
    'importacoes.deposit.uploading': 'Depot en cours…',
    'importacoes.deposit.processed': '{filename} traite·e (format {format})',
    'importacoes.deposit.registered': 'Source « {name} » enregistree.',
    'importacoes.deposit.alreadyExists': 'Source « {name} » existait deja.',
  },
  es: {
    'importacoes.deposit.title': 'Deposito formato casero',
    'importacoes.deposit.pill': 'CSV · RIS · BibTeX',
    'importacoes.deposit.desc': 'Una biblioteca companere exporta su catalogo y deposita el archivo aqui. Seleccione o registre la fuente, luego cargue el archivo — el pipeline hace el resto.',
    'importacoes.deposit.source': 'Fuente companere',
    'importacoes.deposit.selectSource': 'Seleccione una fuente…',
    'importacoes.deposit.newPartner': 'Nueve companere',
    'importacoes.deposit.partnerPlaceholder': 'Ej: Biblioteca La Brique',
    'importacoes.deposit.fileLabel': 'Archivo de catalogo',
    'importacoes.deposit.uploadBtn': 'Depositar y procesar',
    'importacoes.deposit.uploading': 'Deposito en curso…',
    'importacoes.deposit.processed': '{filename} procesade (formato {format})',
    'importacoes.deposit.registered': 'Fuente « {name} » registrade.',
    'importacoes.deposit.alreadyExists': 'Fuente « {name} » ya existia.',
  },
  en: {
    'importacoes.deposit.title': 'In-house format deposit',
    'importacoes.deposit.pill': 'CSV · RIS · BibTeX',
    'importacoes.deposit.desc': 'A partner library exports their catalog and deposits the file here. Select or register the source, then upload the file — the pipeline handles the rest.',
    'importacoes.deposit.source': 'Partner source',
    'importacoes.deposit.selectSource': 'Select a source…',
    'importacoes.deposit.newPartner': 'New partner',
    'importacoes.deposit.partnerPlaceholder': 'E.g. La Brique Library',
    'importacoes.deposit.fileLabel': 'Catalog file',
    'importacoes.deposit.uploadBtn': 'Deposit and process',
    'importacoes.deposit.uploading': 'Depositing…',
    'importacoes.deposit.processed': '{filename} processed (format {format})',
    'importacoes.deposit.registered': 'Source "{name}" registered.',
    'importacoes.deposit.alreadyExists': 'Source "{name}" already existed.',
  },
  it: {
    'importacoes.deposit.title': 'Deposito formato casalingo',
    'importacoes.deposit.pill': 'CSV · RIS · BibTeX',
    'importacoes.deposit.desc': 'Una biblioteca compagn* esporta il suo catalogo e deposita il file qui. Seleziona o registra la fonte, poi carica il file — la pipeline fa il resto.',
    'importacoes.deposit.source': 'Fonte compagn*',
    'importacoes.deposit.selectSource': 'Seleziona una fonte…',
    'importacoes.deposit.newPartner': 'Nuov* compagn*',
    'importacoes.deposit.partnerPlaceholder': 'Es: Biblioteca La Brique',
    'importacoes.deposit.fileLabel': 'File di catalogo',
    'importacoes.deposit.uploadBtn': 'Depositare e processare',
    'importacoes.deposit.uploading': 'Deposito in corso…',
    'importacoes.deposit.processed': '{filename} processat* (formato {format})',
    'importacoes.deposit.registered': 'Fonte « {name} » registrat*.',
    'importacoes.deposit.alreadyExists': 'Fonte « {name} » gia esistente.',
  },
  de: {
    'importacoes.deposit.title': 'Ablage Eigenformat',
    'importacoes.deposit.pill': 'CSV · RIS · BibTeX',
    'importacoes.deposit.desc': 'Eine Partnerbibliothek exportiert ihren Katalog und legt die Datei hier ab. Quelle wahlen oder registrieren, dann die Datei hochladen — die Pipeline erledigt den Rest.',
    'importacoes.deposit.source': 'Partnerquelle',
    'importacoes.deposit.selectSource': 'Quelle wahlen…',
    'importacoes.deposit.newPartner': 'Neue*r Genoss*in',
    'importacoes.deposit.partnerPlaceholder': 'Z.B. Bibliothek La Brique',
    'importacoes.deposit.fileLabel': 'Katalogdatei',
    'importacoes.deposit.uploadBtn': 'Ablegen und verarbeiten',
    'importacoes.deposit.uploading': 'Ablage lauft…',
    'importacoes.deposit.processed': '{filename} verarbeitet (Format {format})',
    'importacoes.deposit.registered': 'Quelle „{name}" registriert.',
    'importacoes.deposit.alreadyExists': 'Quelle „{name}" existierte bereits.',
  },
  ca: {
    'importacoes.deposit.title': 'Diposit format casolà',
    'importacoes.deposit.pill': 'CSV · RIS · BibTeX',
    'importacoes.deposit.desc': 'Una biblioteca companyer-a-e exporta el seu cataleg i diposita el fitxer aqui. Seleccioneu o registreu la font, despres carregueu el fitxer — la pipeline fa la resta.',
    'importacoes.deposit.source': 'Font companyer-a-e',
    'importacoes.deposit.selectSource': 'Seleccioneu una font…',
    'importacoes.deposit.newPartner': 'Nou-va-ve companyer-a-e',
    'importacoes.deposit.partnerPlaceholder': 'Ex: Biblioteca La Brique',
    'importacoes.deposit.fileLabel': 'Fitxer de cataleg',
    'importacoes.deposit.uploadBtn': 'Dipositar i processar',
    'importacoes.deposit.uploading': 'Diposit en curs…',
    'importacoes.deposit.processed': '{filename} processat-da-de (format {format})',
    'importacoes.deposit.registered': 'Font « {name} » registrat-da-de.',
    'importacoes.deposit.alreadyExists': 'Font « {name} » ja existia.',
  },
  eo: {
    'importacoes.deposit.title': 'Deponejo propra formato',
    'importacoes.deposit.pill': 'CSV · RIS · BibTeX',
    'importacoes.deposit.desc': 'Partnera biblioteko eksportas sian katalogon kaj deponejas la dosieron chi tie. Elektu au registru la fonton, poste alshotu la dosieron — la dukto faras la reston.',
    'importacoes.deposit.source': 'Partnera fonto',
    'importacoes.deposit.selectSource': 'Elektu fonton…',
    'importacoes.deposit.newPartner': 'Nova kompan-in-o',
    'importacoes.deposit.partnerPlaceholder': 'Ekz: Biblioteko La Brique',
    'importacoes.deposit.fileLabel': 'Kataloga dosiero',
    'importacoes.deposit.uploadBtn': 'Deponeji kaj procezi',
    'importacoes.deposit.uploading': 'Deponejo okazas…',
    'importacoes.deposit.processed': '{filename} procezita (formato {format})',
    'importacoes.deposit.registered': 'Fonto « {name} » registrita.',
    'importacoes.deposit.alreadyExists': 'Fonto « {name} » jam ekzistis.',
  },
  nl: {
    'importacoes.deposit.title': 'Depot eigen formaat',
    'importacoes.deposit.pill': 'CSV · RIS · BibTeX',
    'importacoes.deposit.desc': 'Een partnerbibliotheek exporteert de catalogus en deponeert het bestand hier. Selecteer of registreer de bron, upload daarna het bestand — de pipeline doet de rest.',
    'importacoes.deposit.source': 'Partnerbron',
    'importacoes.deposit.selectSource': 'Selecteer een bron…',
    'importacoes.deposit.newPartner': 'Nieuwe partner',
    'importacoes.deposit.partnerPlaceholder': 'Bijv. Bibliotheek La Brique',
    'importacoes.deposit.fileLabel': 'Catalogusbestand',
    'importacoes.deposit.uploadBtn': 'Deponeren en verwerken',
    'importacoes.deposit.uploading': 'Depot bezig…',
    'importacoes.deposit.processed': '{filename} verwerkt (formaat {format})',
    'importacoes.deposit.registered': 'Bron „{name}" geregistreerd.',
    'importacoes.deposit.alreadyExists': 'Bron „{name}" bestond al.',
  },
  el: {
    'importacoes.deposit.title': 'Καταθεση εσωτερικου μορφοτυπου',
    'importacoes.deposit.pill': 'CSV · RIS · BibTeX',
    'importacoes.deposit.desc': 'Μια συνεργαζομενη βιβλιοθηκη εξαγει τον καταλογο της και καταθετει το αρχειο εδω. Επιλεξτε η εγγραψτε την πηγη, μετα ανεβαστε το αρχειο — η ροη κανει τα υπολοιπα.',
    'importacoes.deposit.source': 'Πηγη συνεργατη',
    'importacoes.deposit.selectSource': 'Επιλεξτε πηγη…',
    'importacoes.deposit.newPartner': 'Νεος συνεργατης',
    'importacoes.deposit.partnerPlaceholder': 'Π.χ. Βιβλιοθηκη La Brique',
    'importacoes.deposit.fileLabel': 'Αρχειο καταλογου',
    'importacoes.deposit.uploadBtn': 'Καταθεση και επεξεργασια',
    'importacoes.deposit.uploading': 'Καταθεση σε εξελιξη…',
    'importacoes.deposit.processed': '{filename} επεξεργασμενο (μορφοτυπο {format})',
    'importacoes.deposit.registered': 'Πηγη « {name} » εγγραφηκε.',
    'importacoes.deposit.alreadyExists': 'Πηγη « {name} » υπηρχε ηδη.',
  },
};

const LOCALE_TO_FILE = {
  'pt-BR': 'pt-BR.json', fr: 'fr.json', es: 'es.json', en: 'en.json',
  it: 'it.json', de: 'de.json', ca: 'ca.json', eo: 'eo.json',
  nl: 'nl.json', el: 'el.json',
};

let totalAdded = 0;
for (const [locale, newKeys] of Object.entries(NEW_KEYS)) {
  const filePath = path.join(LOCALES_DIR, LOCALE_TO_FILE[locale]);
  const raw = fs.readFileSync(filePath, 'utf8');
  const existing = JSON.parse(raw);
  let added = 0;
  for (const [k, v] of Object.entries(newKeys)) {
    if (!(k in existing)) { existing[k] = v; added++; }
  }
  const sorted = Object.keys(existing).sort().reduce((o, k) => { o[k] = existing[k]; return o; }, {});
  fs.writeFileSync(filePath, JSON.stringify(sorted, null, 2) + '\n', 'utf8');
  console.log(`${LOCALE_TO_FILE[locale]}: +${added} keys (total ${Object.keys(sorted).length})`);
  totalAdded += added;
}
console.log(`\nDone. Total new keys added: ${totalAdded}`);
