/**
 * Add i18n keys for the recolement (collection inventory by scan) tab.
 * MOBILE Paquet 4 (option B). 10 locales, strict parity.
 * Session : Perf UX + nettoyage advisors securite
 */
const fs = require('fs');
const path = require('path');

const LOCALES_DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const KEYS = {
  'panel.tab.recolement': {
    'pt-BR': 'Inventário', en: 'Inventory', fr: 'Récolement', es: 'Inventario',
    de: 'Inventur', it: 'Inventario', ca: 'Inventari', eo: 'Inventaro',
    nl: 'Inventarisatie', el: 'Απογραφή',
  },
  'panel.tab.recolement.hint': {
    'pt-BR': 'Conferência do acervo por leitura das etiquetas',
    en: 'Check the collection by scanning labels',
    fr: 'Vérification du fonds par lecture des étiquettes',
    es: 'Verificación del fondo escaneando las etiquetas',
    de: 'Bestandsprüfung durch Scannen der Etiketten',
    it: 'Verifica del fondo scansionando le etichette',
    ca: 'Verificació del fons escanejant les etiquetes',
    eo: 'Kontrolo de la kolekto per skanado de etikedoj',
    nl: 'Collectie controleren door etiketten te scannen',
    el: 'Έλεγχος της συλλογής με σάρωση των ετικετών',
  },
  'recolement.title': {
    'pt-BR': 'Inventário do acervo', en: 'Collection inventory',
    fr: 'Récolement du fonds', es: 'Inventario del fondo',
    de: 'Bestandsinventur', it: 'Inventario del fondo', ca: 'Inventari del fons',
    eo: 'Inventaro de la kolekto', nl: 'Inventarisatie van de collectie',
    el: 'Απογραφή της συλλογής',
  },
  'recolement.intro': {
    'pt-BR': 'Inicie uma sessão e leia as etiquetas QR dos exemplares para conferir o acervo. Ao terminar, gere o relatório de presentes, faltantes e intrusos.',
    en: 'Start a session and scan the exemplars’ QR labels to check the collection. When done, get the report of present, missing and intruder items.',
    fr: 'Démarrez une session et scannez les étiquettes QR des exemplaires pour vérifier le fonds. À la fin, obtenez le rapport des présents, manquants et intrus.',
    es: 'Inicie una sesión y escanee las etiquetas QR de los ejemplares para verificar el fondo. Al terminar, obtenga el informe de presentes, faltantes e intrusos.',
    de: 'Starte eine Sitzung und scanne die QR-Etiketten der Exemplare, um den Bestand zu prüfen. Am Ende erhältst du den Bericht über vorhandene, fehlende und fremde Exemplare.',
    it: 'Avvia una sessione e scansiona le etichette QR delle copie per verificare il fondo. Al termine, ottieni il rapporto di presenti, mancanti e intrusi.',
    ca: 'Inicieu una sessió i escanegeu les etiquetes QR dels exemplars per verificar el fons. En acabar, obtindreu l’informe de presents, faltants i intrusos.',
    eo: 'Komencu seancon kaj skanu la QR-etikedojn de la ekzempleroj por kontroli la kolekton. Fine, ricevu la raporton pri ĉeestantaj, mankantaj kaj fremdaj ekzempleroj.',
    nl: 'Start een sessie en scan de QR-etiketten van de exemplaren om de collectie te controleren. Daarna krijg je het rapport met aanwezige, ontbrekende en vreemde exemplaren.',
    el: 'Ξεκινήστε μια συνεδρία και σαρώστε τις ετικέτες QR των αντιτύπων για να ελέγξετε τη συλλογή. Στο τέλος, λάβετε την αναφορά παρόντων, ελλειπόντων και ξένων.',
  },
  'recolement.start': {
    'pt-BR': 'Iniciar inventário', en: 'Start inventory', fr: 'Démarrer un récolement',
    es: 'Iniciar inventario', de: 'Inventur starten', it: 'Avvia inventario',
    ca: 'Iniciar inventari', eo: 'Komenci inventaron', nl: 'Inventarisatie starten',
    el: 'Έναρξη απογραφής',
  },
  'recolement.openSessions': {
    'pt-BR': 'Sessões em andamento', en: 'Sessions in progress', fr: 'Sessions en cours',
    es: 'Sesiones en curso', de: 'Laufende Sitzungen', it: 'Sessioni in corso',
    ca: 'Sessions en curs', eo: 'Daŭrantaj seancoj', nl: 'Lopende sessies',
    el: 'Συνεδρίες σε εξέλιξη',
  },
  'recolement.session.scanned': {
    'pt-BR': '{n} lidos', en: '{n} scanned', fr: '{n} scannés', es: '{n} escaneados',
    de: '{n} gescannt', it: '{n} scansionati', ca: '{n} escanejats',
    eo: '{n} skanitaj', nl: '{n} gescand', el: '{n} σαρώθηκαν',
  },
  'recolement.resume': {
    'pt-BR': 'Retomar', en: 'Resume', fr: 'Reprendre', es: 'Reanudar',
    de: 'Fortsetzen', it: 'Riprendi', ca: 'Reprendre', eo: 'Daŭrigi',
    nl: 'Hervatten', el: 'Συνέχιση',
  },
  'recolement.counter.label': {
    'pt-BR': 'lidos', en: 'scanned', fr: 'scannés', es: 'escaneados',
    de: 'gescannt', it: 'scansionati', ca: 'escanejats', eo: 'skanitaj',
    nl: 'gescand', el: 'σαρώθηκαν',
  },
  'recolement.scan.prompt': {
    'pt-BR': 'Aponte para o QR da etiqueta do exemplar',
    en: 'Aim at the exemplar label’s QR code',
    fr: 'Visez le QR de l’étiquette de l’exemplaire',
    es: 'Apunte al QR de la etiqueta del ejemplar',
    de: 'Ziele auf den QR-Code des Exemplar-Etiketts',
    it: 'Inquadra il QR dell’etichetta della copia',
    ca: 'Apunteu al QR de l’etiqueta de l’exemplar',
    eo: 'Celu la QR-kodon de la etikedo de la ekzemplero',
    nl: 'Richt op de QR-code van het exemplaaretiket',
    el: 'Στοχεύστε στον κωδικό QR της ετικέτας του αντιτύπου',
  },
  'recolement.scan.open': {
    'pt-BR': 'Abrir a câmera', en: 'Open the camera', fr: 'Ouvrir la caméra',
    es: 'Abrir la cámara', de: 'Kamera öffnen', it: 'Apri la fotocamera',
    ca: 'Obrir la càmera', eo: 'Malfermi la fotilon', nl: 'Camera openen',
    el: 'Άνοιγμα κάμερας',
  },
  'recolement.manual.placeholder': {
    'pt-BR': 'URL da etiqueta ou id do exemplar', en: 'Label URL or exemplar id',
    fr: 'URL d’étiquette ou id d’exemplaire', es: 'URL de etiqueta o id de ejemplar',
    de: 'Etikett-URL oder Exemplar-ID', it: 'URL etichetta o id copia',
    ca: 'URL d’etiqueta o id d’exemplar', eo: 'URL de etikedo aŭ id de ekzemplero',
    nl: 'Etiket-URL of exemplaar-id', el: 'URL ετικέτας ή id αντιτύπου',
  },
  'recolement.manual.action': {
    'pt-BR': 'Adicionar', en: 'Add', fr: 'Ajouter', es: 'Añadir', de: 'Hinzufügen',
    it: 'Aggiungi', ca: 'Afegir', eo: 'Aldoni', nl: 'Toevoegen', el: 'Προσθήκη',
  },
  'recolement.finish': {
    'pt-BR': 'Encerrar e ver relatório', en: 'Finish and view report',
    fr: 'Terminer et voir le rapport', es: 'Finalizar y ver el informe',
    de: 'Abschließen und Bericht anzeigen', it: 'Termina e vedi il rapporto',
    ca: 'Finalitzar i veure l’informe', eo: 'Fini kaj vidi raporton',
    nl: 'Afronden en rapport bekijken', el: 'Ολοκλήρωση και προβολή αναφοράς',
  },
  'recolement.confirmFinish': {
    'pt-BR': 'Encerrar o inventário? A sessão será fechada.',
    en: 'Finish the inventory? The session will be closed.',
    fr: 'Terminer le récolement ? La session sera clôturée.',
    es: '¿Finalizar el inventario? La sesión se cerrará.',
    de: 'Inventur abschließen? Die Sitzung wird geschlossen.',
    it: 'Terminare l’inventario? La sessione verrà chiusa.',
    ca: 'Finalitzar l’inventari? La sessió es tancarà.',
    eo: 'Ĉu fini la inventaron? La seanco estos fermita.',
    nl: 'Inventarisatie afronden? De sessie wordt gesloten.',
    el: 'Ολοκλήρωση της απογραφής; Η συνεδρία θα κλείσει.',
  },
  'recolement.last.already': {
    'pt-BR': 'Já lido: {title}', en: 'Already scanned: {title}',
    fr: 'Déjà scanné : {title}', es: 'Ya escaneado: {title}',
    de: 'Bereits gescannt: {title}', it: 'Già scansionato: {title}',
    ca: 'Ja escanejat: {title}', eo: 'Jam skanita: {title}',
    nl: 'Al gescand: {title}', el: 'Ήδη σαρωμένο: {title}',
  },
  'recolement.last.intrus': {
    'pt-BR': 'Fora do acervo: exemplar {id}', en: 'Outside the collection: item {id}',
    fr: 'Hors du fonds : exemplaire {id}', es: 'Fuera del fondo: ejemplar {id}',
    de: 'Nicht im Bestand: Exemplar {id}', it: 'Fuori dal fondo: copia {id}',
    ca: 'Fora del fons: exemplar {id}', eo: 'Ekster la kolekto: ekzemplero {id}',
    nl: 'Buiten de collectie: exemplaar {id}', el: 'Εκτός συλλογής: αντίτυπο {id}',
  },
  'recolement.last.unknown': {
    'pt-BR': 'Etiqueta não reconhecida', en: 'Unrecognized label',
    fr: 'Étiquette non reconnue', es: 'Etiqueta no reconocida',
    de: 'Etikett nicht erkannt', it: 'Etichetta non riconosciuta',
    ca: 'Etiqueta no reconeguda', eo: 'Nekonata etikedo',
    nl: 'Etiket niet herkend', el: 'Μη αναγνωρισμένη ετικέτα',
  },
  'recolement.report.acervo': {
    'pt-BR': 'Acervo', en: 'Collection', fr: 'Fonds', es: 'Fondo', de: 'Bestand',
    it: 'Fondo', ca: 'Fons', eo: 'Kolekto', nl: 'Collectie', el: 'Συλλογή',
  },
  'recolement.report.scanned': {
    'pt-BR': 'Lidos', en: 'Scanned', fr: 'Scannés', es: 'Escaneados', de: 'Gescannt',
    it: 'Scansionati', ca: 'Escanejats', eo: 'Skanitaj', nl: 'Gescand', el: 'Σαρωμένα',
  },
  'recolement.report.present': {
    'pt-BR': 'Presentes', en: 'Present', fr: 'Présents', es: 'Presentes', de: 'Vorhanden',
    it: 'Presenti', ca: 'Presents', eo: 'Ĉeestantaj', nl: 'Aanwezig', el: 'Παρόντα',
  },
  'recolement.report.missing': {
    'pt-BR': 'Faltantes', en: 'Missing', fr: 'Manquants', es: 'Faltantes', de: 'Fehlend',
    it: 'Mancanti', ca: 'Faltants', eo: 'Mankantaj', nl: 'Ontbrekend', el: 'Ελλείποντα',
  },
  'recolement.report.intrus': {
    'pt-BR': 'Intrusos', en: 'Intruders', fr: 'Intrus', es: 'Intrusos', de: 'Fremd',
    it: 'Intrusi', ca: 'Intrusos', eo: 'Fremdaj', nl: 'Vreemd', el: 'Ξένα',
  },
  'recolement.report.missingTitle': {
    'pt-BR': 'Exemplares faltantes', en: 'Missing items', fr: 'Exemplaires manquants',
    es: 'Ejemplares faltantes', de: 'Fehlende Exemplare', it: 'Copie mancanti',
    ca: 'Exemplars faltants', eo: 'Mankantaj ekzempleroj', nl: 'Ontbrekende exemplaren',
    el: 'Ελλείποντα αντίτυπα',
  },
  'recolement.report.intrusTitle': {
    'pt-BR': 'Exemplares fora do acervo (intrusos)',
    en: 'Out-of-collection items (intruders)',
    fr: 'Exemplaires hors fonds (intrus)',
    es: 'Ejemplares fuera del fondo (intrusos)',
    de: 'Exemplare außerhalb des Bestands (fremd)',
    it: 'Copie fuori dal fondo (intrusi)',
    ca: 'Exemplars fora del fons (intrusos)',
    eo: 'Ekzempleroj ekster la kolekto (fremdaj)',
    nl: 'Exemplaren buiten de collectie (vreemd)',
    el: 'Αντίτυπα εκτός συλλογής (ξένα)',
  },
  'recolement.report.none': {
    'pt-BR': 'Nenhum', en: 'None', fr: 'Aucun', es: 'Ninguno', de: 'Keine',
    it: 'Nessuno', ca: 'Cap', eo: 'Neniu', nl: 'Geen', el: 'Κανένα',
  },
  'recolement.report.subtitle': {
    'pt-BR': 'Acervo: {acervo} · Lidos: {scanned} · Presentes: {present} · Faltantes: {missing} · Intrusos: {intrus}',
    en: 'Collection: {acervo} · Scanned: {scanned} · Present: {present} · Missing: {missing} · Intruders: {intrus}',
    fr: 'Fonds : {acervo} · Scannés : {scanned} · Présents : {present} · Manquants : {missing} · Intrus : {intrus}',
    es: 'Fondo: {acervo} · Escaneados: {scanned} · Presentes: {present} · Faltantes: {missing} · Intrusos: {intrus}',
    de: 'Bestand: {acervo} · Gescannt: {scanned} · Vorhanden: {present} · Fehlend: {missing} · Fremd: {intrus}',
    it: 'Fondo: {acervo} · Scansionati: {scanned} · Presenti: {present} · Mancanti: {missing} · Intrusi: {intrus}',
    ca: 'Fons: {acervo} · Escanejats: {scanned} · Presents: {present} · Faltants: {missing} · Intrusos: {intrus}',
    eo: 'Kolekto: {acervo} · Skanitaj: {scanned} · Ĉeestantaj: {present} · Mankantaj: {missing} · Fremdaj: {intrus}',
    nl: 'Collectie: {acervo} · Gescand: {scanned} · Aanwezig: {present} · Ontbrekend: {missing} · Vreemd: {intrus}',
    el: 'Συλλογή: {acervo} · Σαρωμένα: {scanned} · Παρόντα: {present} · Ελλείποντα: {missing} · Ξένα: {intrus}',
  },
  'recolement.col.tombo': {
    'pt-BR': 'Tombo', en: 'Accession no.', fr: 'N° d’inventaire', es: 'Núm. de registro',
    de: 'Zugangsnummer', it: 'N. di inventario', ca: 'Núm. d’inventari',
    eo: 'Inventarnumero', nl: 'Aanwinstnummer', el: 'Αριθμός εισαγωγής',
  },
  'recolement.col.shelf': {
    'pt-BR': 'Localização na estante', en: 'Shelf location', fr: 'Localisation en rayon',
    es: 'Ubicación en estante', de: 'Standort im Regal', it: 'Posizione a scaffale',
    ca: 'Localització a la prestatgeria', eo: 'Lokado sur breto', nl: 'Planklocatie',
    el: 'Θέση στο ράφι',
  },
  'recolement.col.title': {
    'pt-BR': 'Título', en: 'Title', fr: 'Titre', es: 'Título', de: 'Titel',
    it: 'Titolo', ca: 'Títol', eo: 'Titolo', nl: 'Titel', el: 'Τίτλος',
  },
  'recolement.col.lib': {
    'pt-BR': 'Biblioteca', en: 'Library', fr: 'Bibliothèque', es: 'Biblioteca',
    de: 'Bibliothek', it: 'Biblioteca', ca: 'Biblioteca', eo: 'Biblioteko',
    nl: 'Bibliotheek', el: 'Βιβλιοθήκη',
  },
  'recolement.col.id': {
    'pt-BR': 'Id do exemplar', en: 'Item id', fr: 'Id exemplaire', es: 'Id de ejemplar',
    de: 'Exemplar-ID', it: 'Id copia', ca: 'Id d’exemplar', eo: 'Id de ekzemplero',
    nl: 'Exemplaar-id', el: 'Id αντιτύπου',
  },
  'recolement.csv.type': {
    'pt-BR': 'Tipo', en: 'Type', fr: 'Type', es: 'Tipo', de: 'Typ', it: 'Tipo',
    ca: 'Tipus', eo: 'Tipo', nl: 'Type', el: 'Τύπος',
  },
  'recolement.export.csv': {
    'pt-BR': 'Exportar CSV', en: 'Export CSV', fr: 'Exporter CSV', es: 'Exportar CSV',
    de: 'CSV exportieren', it: 'Esporta CSV', ca: 'Exportar CSV', eo: 'Eksporti CSV',
    nl: 'CSV exporteren', el: 'Εξαγωγή CSV',
  },
  'recolement.export.pdf': {
    'pt-BR': 'Exportar PDF', en: 'Export PDF', fr: 'Exporter PDF', es: 'Exportar PDF',
    de: 'PDF exportieren', it: 'Esporta PDF', ca: 'Exportar PDF', eo: 'Eksporti PDF',
    nl: 'PDF exporteren', el: 'Εξαγωγή PDF',
  },
  'recolement.new': {
    'pt-BR': 'Novo inventário', en: 'New inventory', fr: 'Nouveau récolement',
    es: 'Nuevo inventario', de: 'Neue Inventur', it: 'Nuovo inventario',
    ca: 'Nou inventari', eo: 'Nova inventaro', nl: 'Nieuwe inventarisatie',
    el: 'Νέα απογραφή',
  },
  'recolement.error.generic': {
    'pt-BR': 'Ocorreu um erro, tente novamente.', en: 'An error occurred, please try again.',
    fr: 'Une erreur est survenue, réessayez.', es: 'Se produjo un error, inténtelo de nuevo.',
    de: 'Ein Fehler ist aufgetreten, bitte erneut versuchen.', it: 'Si è verificato un errore, riprova.',
    ca: 'S’ha produït un error, torneu-ho a provar.', eo: 'Eraro okazis, bonvolu reprovi.',
    nl: 'Er is een fout opgetreden, probeer opnieuw.', el: 'Παρουσιάστηκε σφάλμα, δοκιμάστε ξανά.',
  },
  'recolement.error.not_staff_of_library': {
    'pt-BR': 'Reservado à equipe desta biblioteca.', en: 'Reserved for this library’s staff.',
    fr: 'Réservé au personnel de cette bibliothèque.', es: 'Reservado al personal de esta biblioteca.',
    de: 'Dem Personal dieser Bibliothek vorbehalten.', it: 'Riservato al personale di questa biblioteca.',
    ca: 'Reservat al personal d’aquesta biblioteca.', eo: 'Rezervita por la stabo de ĉi tiu biblioteko.',
    nl: 'Voorbehouden aan het personeel van deze bibliotheek.', el: 'Αποκλειστικά για το προσωπικό αυτής της βιβλιοθήκης.',
  },
  'recolement.error.session_closed': {
    'pt-BR': 'Esta sessão já está fechada.', en: 'This session is already closed.',
    fr: 'Cette session est déjà clôturée.', es: 'Esta sesión ya está cerrada.',
    de: 'Diese Sitzung ist bereits geschlossen.', it: 'Questa sessione è già chiusa.',
    ca: 'Aquesta sessió ja està tancada.', eo: 'Ĉi tiu seanco jam estas fermita.',
    nl: 'Deze sessie is al gesloten.', el: 'Αυτή η συνεδρία έχει ήδη κλείσει.',
  },
  'recolement.error.session_not_found': {
    'pt-BR': 'Sessão não encontrada.', en: 'Session not found.', fr: 'Session introuvable.',
    es: 'Sesión no encontrada.', de: 'Sitzung nicht gefunden.', it: 'Sessione non trovata.',
    ca: 'Sessió no trobada.', eo: 'Seanco ne trovita.', nl: 'Sessie niet gevonden.',
    el: 'Η συνεδρία δεν βρέθηκε.',
  },
  'recolement.error.not_authenticated': {
    'pt-BR': 'Você precisa estar conectado.', en: 'You must be signed in.',
    fr: 'Vous devez être connecté·e.', es: 'Debe haber iniciado sesión.',
    de: 'Du musst angemeldet sein.', it: 'Devi aver effettuato l’accesso.',
    ca: 'Heu d’haver iniciat la sessió.', eo: 'Vi devas esti ensalutinta.',
    nl: 'Je moet ingelogd zijn.', el: 'Πρέπει να έχετε συνδεθεί.',
  },
};

const FILES = fs.readdirSync(LOCALES_DIR).filter(f => f.endsWith('.json'));

for (const file of FILES) {
  const locale = file.replace('.json', '');
  const filePath = path.join(LOCALES_DIR, file);
  const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));

  let added = 0;
  for (const [key, translations] of Object.entries(KEYS)) {
    if (!data[key]) {
      data[key] = translations[locale] || translations['en'];
      added++;
    }
  }

  const sorted = {};
  for (const k of Object.keys(data).sort()) sorted[k] = data[k];
  fs.writeFileSync(filePath, JSON.stringify(sorted, null, 2) + '\n', 'utf8');
  console.log(`${file}: ${added} key(s) added (total: ${Object.keys(sorted).length})`);
}
