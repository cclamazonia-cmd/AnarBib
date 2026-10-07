/* ===========================================================================
 * i18n-add-h21-lot5.cjs — H21 lot 5 (REGISTRE IMP-26 b/c, IMP-32, 07/10/2026) :
 * notice partagée, une divergence signalée, jamais réécrite.
 * Catalogage : l'onglet « Divergences à traiter » (liste par notice et
 * bibliothèque qui importe, pastille), le bandeau d'une notice (« Le fichier de
 * <bibliothèque> diffère sur N champs »), le détail champ par champ (base /
 * AnarBib / fichier / verdict, cases à cocher), les gestes « Appliquer la
 * sélection » (brouillon de reprise prérempli), « Écarter la sélection »,
 * « Tout écarter », leurs messages (écartées, ignorées par raison) ; les refus
 * traduits (HINT error.divergence.* des RPC et de la garde de publication ;
 * error.import.trace_reserved, la garde à l'INSERT de la revue sceptique).
 * Importations : le message du lot 4 pour une notice partagée dit désormais
 * qu'elle est signalée aux détentrices (même valeur posée dans
 * scripts/i18n-add-h21-lot4.cjs, pour que les deux scripts s'accordent).
 * Tutoiement partout ; pt-BR au « você ». Vocabulaire repris des clés voisines
 * (catalogacao.*, importacoes.fila.*, review.report.updates.*).
 * Idempotent : une clé déjà posée n'est réécrite que si sa valeur a changé ici.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const CLES = {
  // ── l'onglet, la liste ──
  'catalogacao.tab.divergences': {
    fr: 'Divergences', 'pt-BR': 'Divergências', en: 'Divergences', es: 'Divergencias', ca: 'Divergències',
    it: 'Divergenze', de: 'Abweichungen', nl: 'Afwijkingen', eo: 'Diverĝoj', el: 'Αποκλίσεις',
  },
  'catalogacao.divergences.title': {
    fr: 'Divergences à traiter', 'pt-BR': 'Divergências a tratar', en: 'Divergences to handle',
    es: 'Divergencias por tratar', ca: 'Divergències per tractar', it: 'Divergenze da trattare',
    de: 'Zu bearbeitende Abweichungen', nl: 'Te behandelen afwijkingen', eo: 'Traktendaj diverĝoj',
    el: 'Αποκλίσεις προς χειρισμό',
  },
  'catalogacao.divergences.intro': {
    fr: 'Un réimport ne réécrit jamais une notice que plusieurs bibliothèques détiennent : il signale ce que son fichier dit autrement. Pour chaque champ, applique la valeur du fichier (dans un brouillon que tu relis et publies) ou écarte-la : la même valeur ne reviendra plus.',
    'pt-BR': 'Uma reimportação nunca reescreve uma ficha que várias bibliotecas possuem: ela sinaliza o que o arquivo dela diz de outro modo. Para cada campo, aplique o valor do arquivo (num rascunho que você revisa e publica) ou desconsidere-o: o mesmo valor não voltará mais.',
    en: 'A reimport never rewrites a record that several libraries hold: it flags what its file says differently. For each field, apply the file’s value (in a draft you review and publish) or dismiss it: the same value will not come back.',
    es: 'Una reimportación nunca reescribe una ficha que tienen varias bibliotecas: señala lo que su archivo dice de otro modo. Para cada campo, aplica el valor del archivo (en un borrador que revisas antes de publicarlo) o desestímalo: el mismo valor no volverá.',
    ca: 'Una reimportació mai no torna a escriure una fitxa que tenen diverses biblioteques: assenyala el que el seu fitxer diu d’una altra manera. Per a cada camp, aplica el valor del fitxer (en un esborrany que revises i publiques) o desestima’l: el mateix valor no tornarà.',
    it: 'Una reimportazione non riscrive mai una scheda che più biblioteche possiedono: segnala ciò che il suo file dice diversamente. Per ogni campo, applica il valore del file (in una bozza che rileggi e pubblichi) oppure scartalo: lo stesso valore non tornerà più.',
    de: 'Ein Neuimport überschreibt nie einen Eintrag, den mehrere Bibliotheken besitzen: Er meldet, was seine Datei anders sagt. Übernimm für jedes Feld den Wert der Datei (in einem Entwurf, den du prüfst und veröffentlichst) oder verwirf ihn: Derselbe Wert kommt nicht wieder.',
    nl: 'Een herimport herschrijft nooit een record dat meerdere bibliotheken bezitten: hij meldt wat zijn bestand anders zegt. Pas per veld de waarde uit het bestand toe (in een concept dat je naleest en publiceert) of wijs haar af: dezelfde waarde komt niet terug.',
    eo: 'Reimporto neniam reskribas slipon, kiun pluraj bibliotekoj havas: ĝi signalas tion, kion ĝia dosiero diras alie. Por ĉiu kampo, apliku la valoron de la dosiero (en malneto, kiun vi relegas kaj publikigas) aŭ malakceptu ĝin: la sama valoro ne revenos.',
    el: 'Μια επανεισαγωγή δεν ξαναγράφει ποτέ μια εγγραφή που έχουν πολλές βιβλιοθήκες: επισημαίνει ό,τι το αρχείο της λέει αλλιώς. Για κάθε πεδίο, εφάρμοσε την τιμή του αρχείου (σε πρόχειρο που ξαναδιαβάζεις και δημοσιεύεις) ή απόρριψέ την: η ίδια τιμή δεν θα ξαναεμφανιστεί.',
  },
  'catalogacao.divergences.loading': {
    fr: 'Chargement des divergences…', 'pt-BR': 'Carregando as divergências…', en: 'Loading divergences…',
    es: 'Cargando las divergencias…', ca: 'S’estan carregant les divergències…', it: 'Caricamento delle divergenze…',
    de: 'Abweichungen werden geladen…', nl: 'Afwijkingen worden geladen…', eo: 'Ŝargante la diverĝojn…',
    el: 'Φόρτωση αποκλίσεων…',
  },
  'catalogacao.divergences.empty': {
    fr: 'Aucune divergence à traiter : aucun réimport n’a trouvé de différence sur une notice partagée que tu coordonnes.',
    'pt-BR': 'Nenhuma divergência a tratar: nenhuma reimportação encontrou diferença numa ficha compartilhada que você coordena.',
    en: 'No divergences to handle: no reimport has found a difference on a shared record you coordinate.',
    es: 'Ninguna divergencia por tratar: ninguna reimportación encontró diferencias en una ficha compartida que coordinas.',
    ca: 'Cap divergència per tractar: cap reimportació no ha trobat diferències en una fitxa compartida que coordines.',
    it: 'Nessuna divergenza da trattare: nessuna reimportazione ha trovato differenze su una scheda condivisa che coordini.',
    de: 'Keine Abweichungen zu bearbeiten: Kein Neuimport hat bei einem geteilten Eintrag, den du koordinierst, einen Unterschied gefunden.',
    nl: 'Geen afwijkingen te behandelen: geen herimport vond een verschil in een gedeeld record dat jij coördineert.',
    eo: 'Neniu traktenda diverĝo: neniu reimporto trovis diferencon en kunhavata slipo, kiun vi kunordigas.',
    el: 'Καμία απόκλιση προς χειρισμό: καμία επανεισαγωγή δεν βρήκε διαφορά σε κοινή εγγραφή που συντονίζεις.',
  },
  'catalogacao.divergences.count': {
    fr: '{n, plural, one {# notice à traiter} other {# notices à traiter}}',
    'pt-BR': '{n, plural, one {# ficha a tratar} other {# fichas a tratar}}',
    en: '{n, plural, one {# record to handle} other {# records to handle}}',
    es: '{n, plural, one {# ficha por tratar} other {# fichas por tratar}}',
    ca: '{n, plural, one {# fitxa per tractar} other {# fitxes per tractar}}',
    it: '{n, plural, one {# scheda da trattare} other {# schede da trattare}}',
    de: '{n, plural, one {# Eintrag zu bearbeiten} other {# Einträge zu bearbeiten}}',
    nl: '{n, plural, one {# record te behandelen} other {# records te behandelen}}',
    eo: '{n, plural, one {# traktenda slipo} other {# traktendaj slipoj}}',
    el: '{n, plural, one {# εγγραφή προς χειρισμό} other {# εγγραφές προς χειρισμό}}',
  },
  'catalogacao.divergences.fromLibrary': {
    fr: 'fichier de {library}', 'pt-BR': 'arquivo de {library}', en: 'file from {library}', es: 'archivo de {library}',
    ca: 'fitxer de {library}', it: 'file di {library}', de: 'Datei von {library}', nl: 'bestand van {library}',
    eo: 'dosiero de {library}', el: 'αρχείο της {library}',
  },
  'catalogacao.divergences.fields': {
    fr: '{n, plural, one {# champ} other {# champs}} : {list}',
    'pt-BR': '{n, plural, one {# campo} other {# campos}}: {list}',
    en: '{n, plural, one {# field} other {# fields}}: {list}',
    es: '{n, plural, one {# campo} other {# campos}}: {list}',
    ca: '{n, plural, one {# camp} other {# camps}}: {list}',
    it: '{n, plural, one {# campo} other {# campi}}: {list}',
    de: '{n, plural, one {# Feld} other {# Felder}}: {list}',
    nl: '{n, plural, one {# veld} other {# velden}}: {list}',
    eo: '{n, plural, one {# kampo} other {# kampoj}}: {list}',
    el: '{n, plural, one {# πεδίο} other {# πεδία}}: {list}',
  },
  'catalogacao.divergences.view': {
    fr: 'Voir', 'pt-BR': 'Ver', en: 'View', es: 'Ver', ca: 'Veure', it: 'Vedi', de: 'Ansehen', nl: 'Bekijken',
    eo: 'Vidi', el: 'Προβολή',
  },
  // ── le bandeau ──
  'catalogacao.divergences.regionLabel': {
    fr: 'Divergences signalées par un réimport', 'pt-BR': 'Divergências sinalizadas por uma reimportação',
    en: 'Divergences flagged by a reimport', es: 'Divergencias señaladas por una reimportación',
    ca: 'Divergències assenyalades per una reimportació', it: 'Divergenze segnalate da una reimportazione',
    de: 'Von einem Neuimport gemeldete Abweichungen', nl: 'Afwijkingen gemeld door een herimport',
    eo: 'Diverĝoj signalitaj de reimporto', el: 'Αποκλίσεις που επισήμανε μια επανεισαγωγή',
  },
  'catalogacao.divergences.banner': {
    fr: 'Le fichier de {library} diffère sur {n, plural, one {# champ} other {# champs}}',
    'pt-BR': 'O arquivo de {library} difere em {n, plural, one {# campo} other {# campos}}',
    en: 'The file from {library} differs on {n, plural, one {# field} other {# fields}}',
    es: 'El archivo de {library} difiere en {n, plural, one {# campo} other {# campos}}',
    ca: 'El fitxer de {library} difereix en {n, plural, one {# camp} other {# camps}}',
    it: 'Il file di {library} differisce in {n, plural, one {# campo} other {# campi}}',
    de: 'Die Datei von {library} weicht in {n, plural, one {# Feld} other {# Feldern}} ab',
    nl: 'Het bestand van {library} wijkt af in {n, plural, one {# veld} other {# velden}}',
    eo: 'La dosiero de {library} diferencas en {n, plural, one {# kampo} other {# kampoj}}',
    el: 'Το αρχείο της {library} διαφέρει σε {n, plural, one {# πεδίο} other {# πεδία}}',
  },
  'catalogacao.divergences.bannerHelp': {
    fr: 'Cette notice est partagée : le réimport ne l’a pas réécrite. Applique les champs que tu retiens, ou écarte-les.',
    'pt-BR': 'Esta ficha é compartilhada: a reimportação não a reescreveu. Aplique os campos que você aceita, ou desconsidere-os.',
    en: 'This record is shared: the reimport did not rewrite it. Apply the fields you accept, or dismiss them.',
    es: 'Esta ficha es compartida: la reimportación no la reescribió. Aplica los campos que aceptas, o desestímalos.',
    ca: 'Aquesta fitxa és compartida: la reimportació no l’ha reescrita. Aplica els camps que acceptes, o desestima’ls.',
    it: 'Questa scheda è condivisa: la reimportazione non l’ha riscritta. Applica i campi che accetti, oppure scartali.',
    de: 'Dieser Eintrag ist geteilt: Der Neuimport hat ihn nicht überschrieben. Übernimm die Felder, die du annimmst, oder verwirf sie.',
    nl: 'Dit record is gedeeld: de herimport heeft het niet herschreven. Pas de velden toe die je aanvaardt, of wijs ze af.',
    eo: 'Ĉi tiu slipo estas kunhavata: la reimporto ne reskribis ĝin. Apliku la kampojn, kiujn vi akceptas, aŭ malakceptu ilin.',
    el: 'Αυτή η εγγραφή είναι κοινή: η επανεισαγωγή δεν την ξανάγραψε. Εφάρμοσε τα πεδία που δέχεσαι ή απόρριψέ τα.',
  },
  'catalogacao.divergences.draftOpen': {
    fr: 'Un brouillon de reprise prérempli est ouvert (n° {id}).',
    'pt-BR': 'Há um rascunho de retomada pré-preenchido aberto (nº {id}).',
    en: 'A prefilled revision draft is open (no. {id}).',
    es: 'Hay un borrador de revisión prerrellenado abierto (n.º {id}).',
    ca: 'Hi ha un esborrany de revisió preomplert obert (núm. {id}).',
    it: 'È aperta una bozza di revisione precompilata (n. {id}).',
    de: 'Ein vorausgefüllter Überarbeitungsentwurf ist offen (Nr. {id}).',
    nl: 'Er staat een vooraf ingevuld bewerkingsconcept open (nr. {id}).',
    eo: 'Antaŭplenigita reviza malneto estas malfermita (n-ro {id}).',
    el: 'Υπάρχει ανοιχτό προσυμπληρωμένο πρόχειρο αναθεώρησης (αρ. {id}).',
  },
  'catalogacao.divergences.openDraft': {
    fr: 'Ouvrir le brouillon', 'pt-BR': 'Abrir o rascunho', en: 'Open the draft', es: 'Abrir el borrador',
    ca: 'Obrir l’esborrany', it: 'Apri la bozza', de: 'Entwurf öffnen', nl: 'Concept openen', eo: 'Malfermi la malneton',
    el: 'Άνοιγμα του προχείρου',
  },
  'catalogacao.divergences.showDetail': {
    fr: 'Voir le détail', 'pt-BR': 'Ver o detalhe', en: 'Show the detail', es: 'Ver el detalle', ca: 'Veure el detall',
    it: 'Vedi il dettaglio', de: 'Details anzeigen', nl: 'Details tonen', eo: 'Montri la detalojn', el: 'Εμφάνιση λεπτομερειών',
  },
  'catalogacao.divergences.hideDetail': {
    fr: 'Masquer le détail', 'pt-BR': 'Ocultar o detalhe', en: 'Hide the detail', es: 'Ocultar el detalle',
    ca: 'Amagar el detall', it: 'Nascondi il dettaglio', de: 'Details ausblenden', nl: 'Details verbergen',
    eo: 'Kaŝi la detalojn', el: 'Απόκρυψη λεπτομερειών',
  },
  'catalogacao.divergences.col.select': {
    fr: 'Choisir', 'pt-BR': 'Escolher', en: 'Select', es: 'Elegir', ca: 'Triar', it: 'Scegli', de: 'Auswählen',
    nl: 'Kiezen', eo: 'Elekti', el: 'Επιλογή',
  },
  'catalogacao.divergences.col.field': {
    fr: 'Champ', 'pt-BR': 'Campo', en: 'Field', es: 'Campo', ca: 'Camp', it: 'Campo', de: 'Feld', nl: 'Veld',
    eo: 'Kampo', el: 'Πεδίο',
  },
  'catalogacao.divergences.col.base': {
    fr: 'Import précédent', 'pt-BR': 'Importação anterior', en: 'Previous import', es: 'Importación anterior',
    ca: 'Importació anterior', it: 'Importazione precedente', de: 'Vorheriger Import', nl: 'Vorige import',
    eo: 'Antaŭa importo', el: 'Προηγούμενη εισαγωγή',
  },
  'catalogacao.divergences.col.anarbib': {
    fr: 'AnarBib', 'pt-BR': 'AnarBib', en: 'AnarBib', es: 'AnarBib', ca: 'AnarBib', it: 'AnarBib', de: 'AnarBib',
    nl: 'AnarBib', eo: 'AnarBib', el: 'AnarBib',
  },
  'catalogacao.divergences.col.file': {
    fr: 'Fichier', 'pt-BR': 'Arquivo', en: 'File', es: 'Archivo', ca: 'Fitxer', it: 'File', de: 'Datei', nl: 'Bestand',
    eo: 'Dosiero', el: 'Αρχείο',
  },
  'catalogacao.divergences.col.verdict': {
    fr: 'Constat', 'pt-BR': 'Constatação', en: 'Finding', es: 'Constatación', ca: 'Constatació', it: 'Esito',
    de: 'Befund', nl: 'Bevinding', eo: 'Konstato', el: 'Διαπίστωση',
  },
  'catalogacao.divergences.selectField': {
    fr: 'Choisir le champ {field}', 'pt-BR': 'Escolher o campo {field}', en: 'Select the field {field}',
    es: 'Elegir el campo {field}', ca: 'Triar el camp {field}', it: 'Scegli il campo {field}',
    de: 'Feld {field} auswählen', nl: 'Veld {field} kiezen', eo: 'Elekti la kampon {field}', el: 'Επιλογή του πεδίου {field}',
  },
  'catalogacao.divergences.shownContributors': {
    fr: 'Responsabilités : montrées, jamais préremplies — à reprendre à la main dans le brouillon.',
    'pt-BR': 'Responsabilidades: mostradas, nunca pré-preenchidas — retome-as à mão no rascunho.',
    en: 'Responsibilities: shown, never prefilled — take them over by hand in the draft.',
    es: 'Responsabilidades: mostradas, nunca prerrellenadas — retómalas a mano en el borrador.',
    ca: 'Responsabilitats: mostrades, mai preomplertes — reprèn-les a mà a l’esborrany.',
    it: 'Responsabilità: mostrate, mai precompilate — riprendile a mano nella bozza.',
    de: 'Verantwortlichkeiten: gezeigt, nie vorausgefüllt — übernimm sie von Hand im Entwurf.',
    nl: 'Verantwoordelijkheden: getoond, nooit vooraf ingevuld — neem ze met de hand over in het concept.',
    eo: 'Respondecoj: montrataj, neniam antaŭplenigataj — reprenu ilin mane en la malneto.',
    el: 'Ευθύνες: εμφανίζονται, δεν προσυμπληρώνονται ποτέ — πέρασέ τες με το χέρι στο πρόχειρο.',
  },
  'catalogacao.divergences.shownErased': {
    fr: 'Effacé par la source : montré, jamais vidé d’office.',
    'pt-BR': 'Apagado pela fonte: mostrado, nunca esvaziado automaticamente.',
    en: 'Erased by the source: shown, never emptied automatically.',
    es: 'Borrado por la fuente: mostrado, nunca vaciado de oficio.',
    ca: 'Esborrat per la font: mostrat, mai buidat d’ofici.',
    it: 'Cancellato dalla fonte: mostrato, mai svuotato d’ufficio.',
    de: 'Von der Quelle gelöscht: gezeigt, nie automatisch geleert.',
    nl: 'Gewist door de bron: getoond, nooit automatisch leeggemaakt.',
    eo: 'Forigita de la fonto: montrata, neniam aŭtomate malplenigata.',
    el: 'Διαγράφηκε από την πηγή: εμφανίζεται, δεν αδειάζει ποτέ αυτόματα.',
  },
  'catalogacao.divergences.verdict.source_seule': {
    fr: 'Changé dans le fichier seulement', 'pt-BR': 'Alterado só no arquivo', en: 'Changed in the file only',
    es: 'Cambiado solo en el archivo', ca: 'Canviat només al fitxer', it: 'Modificato solo nel file',
    de: 'Nur in der Datei geändert', nl: 'Alleen in het bestand gewijzigd', eo: 'Ŝanĝita nur en la dosiero',
    el: 'Άλλαξε μόνο στο αρχείο',
  },
  'catalogacao.divergences.verdict.conflit': {
    fr: 'Conflit (changé des deux côtés)', 'pt-BR': 'Conflito (alterado dos dois lados)', en: 'Conflict (changed on both sides)',
    es: 'Conflicto (cambiado en ambos lados)', ca: 'Conflicte (canviat als dos costats)', it: 'Conflitto (modificato da entrambe le parti)',
    de: 'Konflikt (auf beiden Seiten geändert)', nl: 'Conflict (aan beide kanten gewijzigd)', eo: 'Konflikto (ŝanĝita ambaŭflanke)',
    el: 'Σύγκρουση (άλλαξε και από τις δύο πλευρές)',
  },
  'catalogacao.divergences.verdict.sans_base': {
    fr: 'À revoir (sans base)', 'pt-BR': 'A revisar (sem base)', en: 'To review (no baseline)', es: 'Por revisar (sin base)',
    ca: 'Per revisar (sense base)', it: 'Da rivedere (senza base)', de: 'Zu prüfen (ohne Basis)', nl: 'Na te kijken (zonder basis)',
    eo: 'Reviziinda (sen bazo)', el: 'Προς έλεγχο (χωρίς βάση)',
  },
  // ── les gestes ──
  'catalogacao.divergences.apply': {
    fr: 'Appliquer la sélection ({n})', 'pt-BR': 'Aplicar a seleção ({n})', en: 'Apply the selection ({n})',
    es: 'Aplicar la selección ({n})', ca: 'Aplicar la selecció ({n})', it: 'Applica la selezione ({n})',
    de: 'Auswahl übernehmen ({n})', nl: 'Selectie toepassen ({n})', eo: 'Apliki la elekton ({n})', el: 'Εφαρμογή επιλογής ({n})',
  },
  'catalogacao.divergences.applyTitle': {
    fr: 'Un brouillon de reprise de la notice, prérempli des champs cochés avec la valeur du fichier, pour ta bibliothèque active : tu le relis et le publies toi-même.',
    'pt-BR': 'Um rascunho de retomada da ficha, pré-preenchido com o valor do arquivo nos campos marcados, para a sua biblioteca ativa: você o revisa e o publica.',
    en: 'A revision draft of the record, prefilled with the file’s value in the ticked fields, for your active library: you review and publish it yourself.',
    es: 'Un borrador de revisión de la ficha, prerrellenado con el valor del archivo en los campos marcados, para tu biblioteca activa: lo revisas y decides cuándo publicarlo.',
    ca: 'Un esborrany de revisió de la fitxa, preomplert amb el valor del fitxer als camps marcats, per a la teva biblioteca activa: el revises i el publiques tu.',
    it: 'Una bozza di revisione della scheda, precompilata con il valore del file nei campi spuntati, per la tua biblioteca attiva: la rileggi e la pubblichi tu.',
    de: 'Ein Überarbeitungsentwurf des Eintrags, in den angehakten Feldern mit dem Wert der Datei vorausgefüllt, für deine aktive Bibliothek: Du prüfst und veröffentlichst ihn selbst.',
    nl: 'Een bewerkingsconcept van het record, in de aangevinkte velden vooraf ingevuld met de waarde uit het bestand, voor je actieve bibliotheek: je leest het na en publiceert het zelf.',
    eo: 'Reviza malneto de la slipo, antaŭplenigita per la valoro de la dosiero en la markitaj kampoj, por via aktiva biblioteko: vi mem relegas kaj publikigas ĝin.',
    el: 'Ένα πρόχειρο αναθεώρησης της εγγραφής, προσυμπληρωμένο με την τιμή του αρχείου στα επιλεγμένα πεδία, για την ενεργή σου βιβλιοθήκη: το ξαναδιαβάζεις και το δημοσιεύεις εσύ.',
  },
  'catalogacao.divergences.applied': {
    fr: 'Brouillon de reprise n° {id} prérempli : relis-le, puis publie-le.',
    'pt-BR': 'Rascunho de retomada nº {id} pré-preenchido: revise-o e depois publique-o.',
    en: 'Revision draft no. {id} prefilled: review it, then publish it.',
    es: 'Borrador de revisión n.º {id} prerrellenado: revísalo y luego publícalo.',
    ca: 'Esborrany de revisió núm. {id} preomplert: revisa’l i després publica’l.',
    it: 'Bozza di revisione n. {id} precompilata: rileggila, poi pubblicala.',
    de: 'Überarbeitungsentwurf Nr. {id} vorausgefüllt: prüfe ihn, dann veröffentliche ihn.',
    nl: 'Bewerkingsconcept nr. {id} vooraf ingevuld: lees het na en publiceer het dan.',
    eo: 'Reviza malneto n-ro {id} antaŭplenigita: relegu ĝin, poste publikigu ĝin.',
    el: 'Το πρόχειρο αναθεώρησης αρ. {id} προσυμπληρώθηκε: ξαναδιάβασέ το και μετά δημοσίευσέ το.',
  },
  'catalogacao.divergences.applyNeedsActiveHolder': {
    fr: 'Pour appliquer, choisis comme bibliothèque active une bibliothèque qui détient cette notice et que tu coordonnes.',
    'pt-BR': 'Para aplicar, escolha como biblioteca ativa uma biblioteca que possui esta ficha e que você coordena.',
    en: 'To apply, choose as active library a library that holds this record and that you coordinate.',
    es: 'Para aplicar, elige como biblioteca activa una biblioteca que tenga esta ficha y que coordines.',
    ca: 'Per aplicar, tria com a biblioteca activa una biblioteca que tingui aquesta fitxa i que coordinis.',
    it: 'Per applicare, scegli come biblioteca attiva una biblioteca che possiede questa scheda e che coordini.',
    de: 'Um zu übernehmen, wähle als aktive Bibliothek eine Bibliothek, die diesen Eintrag besitzt und die du koordinierst.',
    nl: 'Om toe te passen, kies als actieve bibliotheek een bibliotheek die dit record bezit en die jij coördineert.',
    eo: 'Por apliki, elektu kiel aktivan bibliotekon bibliotekon, kiu havas ĉi tiun slipon kaj kiun vi kunordigas.',
    el: 'Για να εφαρμόσεις, διάλεξε ως ενεργή βιβλιοθήκη μια βιβλιοθήκη που έχει αυτή την εγγραφή και που συντονίζεις.',
  },
  'catalogacao.divergences.dismiss': {
    fr: 'Écarter la sélection ({n})', 'pt-BR': 'Desconsiderar a seleção ({n})', en: 'Dismiss the selection ({n})',
    es: 'Desestimar la selección ({n})', ca: 'Desestimar la selecció ({n})', it: 'Scarta la selezione ({n})',
    de: 'Auswahl verwerfen ({n})', nl: 'Selectie afwijzen ({n})', eo: 'Malakcepti la elekton ({n})', el: 'Απόρριψη επιλογής ({n})',
  },
  'catalogacao.divergences.dismissTitle': {
    fr: 'Garder la notice telle quelle pour ces champs : la base du réimport avance, la même valeur du fichier ne sera plus signalée.',
    'pt-BR': 'Manter a ficha como está nesses campos: a base da reimportação avança, o mesmo valor do arquivo não será mais sinalizado.',
    en: 'Keep the record as it is for these fields: the reimport baseline moves forward, the same file value will no longer be flagged.',
    es: 'Mantener la ficha tal cual en estos campos: la base de la reimportación avanza, el mismo valor del archivo ya no se señalará.',
    ca: 'Mantenir la fitxa tal com és en aquests camps: la base de la reimportació avança, el mateix valor del fitxer ja no s’assenyalarà.',
    it: 'Tenere la scheda così com’è per questi campi: la base della reimportazione avanza, lo stesso valore del file non sarà più segnalato.',
    de: 'Den Eintrag in diesen Feldern so lassen: Die Basis des Neuimports rückt vor, derselbe Wert der Datei wird nicht mehr gemeldet.',
    nl: 'Het record voor deze velden laten zoals het is: de basis van de herimport schuift op, dezelfde waarde uit het bestand wordt niet meer gemeld.',
    eo: 'Lasi la slipon tia, kia ĝi estas, por ĉi tiuj kampoj: la bazo de la reimporto antaŭeniras, la sama valoro de la dosiero ne plu estos signalata.',
    el: 'Η εγγραφή μένει ως έχει σε αυτά τα πεδία: η βάση της επανεισαγωγής προχωρά, η ίδια τιμή του αρχείου δεν θα επισημαίνεται πια.',
  },
  'catalogacao.divergences.dismissAll': {
    fr: 'Tout écarter', 'pt-BR': 'Desconsiderar tudo', en: 'Dismiss all', es: 'Desestimar todo', ca: 'Desestimar-ho tot',
    it: 'Scarta tutto', de: 'Alles verwerfen', nl: 'Alles afwijzen', eo: 'Malakcepti ĉion', el: 'Απόρριψη όλων',
  },
  'catalogacao.divergences.dismissAllConfirm': {
    fr: 'Écarter {n, plural, one {la divergence} other {les # divergences}} de cette notice ? La notice reste telle quelle ; les mêmes valeurs du fichier ne seront plus signalées.',
    'pt-BR': 'Desconsiderar {n, plural, one {a divergência} other {as # divergências}} desta ficha? A ficha fica como está; os mesmos valores do arquivo não serão mais sinalizados.',
    en: 'Dismiss {n, plural, one {the divergence} other {the # divergences}} of this record? The record stays as it is; the same file values will no longer be flagged.',
    es: '¿Desestimar {n, plural, one {la divergencia} other {las # divergencias}} de esta ficha? La ficha queda tal cual; los mismos valores del archivo ya no se señalarán.',
    ca: 'Vols desestimar {n, plural, one {la divergència} other {les # divergències}} d’aquesta fitxa? La fitxa queda tal com és; els mateixos valors del fitxer ja no s’assenyalaran.',
    it: 'Scartare {n, plural, one {la divergenza} other {le # divergenze}} di questa scheda? La scheda resta com’è; gli stessi valori del file non saranno più segnalati.',
    de: '{n, plural, one {Die Abweichung} other {Die # Abweichungen}} dieses Eintrags verwerfen? Der Eintrag bleibt, wie er ist; dieselben Werte der Datei werden nicht mehr gemeldet.',
    nl: '{n, plural, one {De afwijking} other {De # afwijkingen}} van dit record afwijzen? Het record blijft zoals het is; dezelfde waarden uit het bestand worden niet meer gemeld.',
    eo: 'Ĉu malakcepti {n, plural, one {la diverĝon} other {la # diverĝojn}} de ĉi tiu slipo? La slipo restas tia, kia ĝi estas; la samaj valoroj de la dosiero ne plu estos signalataj.',
    el: 'Απόρριψη {n, plural, one {της απόκλισης} other {των # αποκλίσεων}} αυτής της εγγραφής; Η εγγραφή μένει ως έχει· οι ίδιες τιμές του αρχείου δεν θα επισημαίνονται πια.',
  },
  'catalogacao.divergences.dismissed': {
    fr: '{n, plural, one {# divergence écartée} other {# divergences écartées}} : la base avance pour ces champs.',
    'pt-BR': '{n, plural, one {# divergência desconsiderada} other {# divergências desconsideradas}}: a base avança nesses campos.',
    en: '{n, plural, one {# divergence dismissed} other {# divergences dismissed}}: the baseline moves forward for these fields.',
    es: '{n, plural, one {# divergencia desestimada} other {# divergencias desestimadas}}: la base avanza en estos campos.',
    ca: '{n, plural, one {# divergència desestimada} other {# divergències desestimades}}: la base avança en aquests camps.',
    it: '{n, plural, one {# divergenza scartata} other {# divergenze scartate}}: la base avanza per questi campi.',
    de: '{n, plural, one {# Abweichung verworfen} other {# Abweichungen verworfen}}: Die Basis rückt für diese Felder vor.',
    nl: '{n, plural, one {# afwijking afgewezen} other {# afwijkingen afgewezen}}: de basis schuift op voor deze velden.',
    eo: '{n, plural, one {# diverĝo malakceptita} other {# diverĝoj malakceptitaj}}: la bazo antaŭeniras por ĉi tiuj kampoj.',
    el: '{n, plural, one {# απόκλιση απορρίφθηκε} other {# αποκλίσεις απορρίφθηκαν}}: η βάση προχωρά για αυτά τα πεδία.',
  },
  'catalogacao.divergences.dismissedNone': {
    fr: 'Aucune divergence écartée.', 'pt-BR': 'Nenhuma divergência desconsiderada.', en: 'No divergence dismissed.',
    es: 'Ninguna divergencia desestimada.', ca: 'Cap divergència desestimada.', it: 'Nessuna divergenza scartata.',
    de: 'Keine Abweichung verworfen.', nl: 'Geen afwijking afgewezen.', eo: 'Neniu diverĝo malakceptita.',
    el: 'Δεν απορρίφθηκε καμία απόκλιση.',
  },
  'catalogacao.divergences.skipped': {
    fr: 'Ignorées : {list}.', 'pt-BR': 'Ignoradas: {list}.', en: 'Skipped: {list}.', es: 'Ignoradas: {list}.',
    ca: 'Ignorades: {list}.', it: 'Ignorate: {list}.', de: 'Übergangen: {list}.', nl: 'Overgeslagen: {list}.',
    eo: 'Preterlasitaj: {list}.', el: 'Παραλείφθηκαν: {list}.',
  },
  'catalogacao.divergences.skip.perimee': {
    fr: '{n, plural, one {# dont la base a changé depuis le constat (rouvre la comparaison dans Importations)} other {# dont la base a changé depuis le constat (rouvre la comparaison dans Importations)}}',
    'pt-BR': '{n, plural, one {# cuja base mudou desde a constatação (reabra a comparação em Importações)} other {# cuja base mudou desde a constatação (reabra a comparação em Importações)}}',
    en: '{n, plural, one {# whose baseline changed since it was found (reopen the comparison in Imports)} other {# whose baseline changed since they were found (reopen the comparison in Imports)}}',
    es: '{n, plural, one {# cuya base cambió desde la constatación (reabre la comparación en Importaciones)} other {# cuya base cambió desde la constatación (reabre la comparación en Importaciones)}}',
    ca: '{n, plural, one {# la base de la qual ha canviat des de la constatació (reobre la comparació a Importacions)} other {# la base de les quals ha canviat des de la constatació (reobre la comparació a Importacions)}}',
    it: '{n, plural, one {# la cui base è cambiata dalla constatazione (riapri il confronto in Importazioni)} other {# la cui base è cambiata dalla constatazione (riapri il confronto in Importazioni)}}',
    de: '{n, plural, one {# deren Basis sich seit dem Befund geändert hat (öffne den Vergleich in Importe erneut)} other {# deren Basis sich seit dem Befund geändert hat (öffne den Vergleich in Importe erneut)}}',
    nl: '{n, plural, one {# waarvan de basis sinds de vaststelling veranderde (open de vergelijking opnieuw in Imports)} other {# waarvan de basis sinds de vaststelling veranderde (open de vergelijking opnieuw in Imports)}}',
    eo: '{n, plural, one {# kies bazo ŝanĝiĝis post la konstato (remalfermu la komparon en Importoj)} other {# kies bazo ŝanĝiĝis post la konstato (remalfermu la komparon en Importoj)}}',
    el: '{n, plural, one {# της οποίας η βάση άλλαξε από τη διαπίστωση (ξανάνοιξε τη σύγκριση στις Εισαγωγές)} other {# των οποίων η βάση άλλαξε από τη διαπίστωση (ξανάνοιξε τη σύγκριση στις Εισαγωγές)}}',
  },
  'catalogacao.divergences.skip.pas_ouverte': {
    fr: '{n, plural, one {# déjà traitée} other {# déjà traitées}}', 'pt-BR': '{n, plural, one {# já tratada} other {# já tratadas}}',
    en: '{n, plural, one {# already handled} other {# already handled}}', es: '{n, plural, one {# ya tratada} other {# ya tratadas}}',
    ca: '{n, plural, one {# ja tractada} other {# ja tractades}}', it: '{n, plural, one {# già trattata} other {# già trattate}}',
    de: '{n, plural, one {# bereits bearbeitet} other {# bereits bearbeitet}}', nl: '{n, plural, one {# al behandeld} other {# al behandeld}}',
    eo: '{n, plural, one {# jam traktita} other {# jam traktitaj}}', el: '{n, plural, one {# ήδη υπό χειρισμό} other {# ήδη υπό χειρισμό}}',
  },
  'catalogacao.divergences.skip.non_partagee': {
    fr: '{n, plural, one {# d’une notice qui n’est plus partagée} other {# d’une notice qui n’est plus partagée}}',
    'pt-BR': '{n, plural, one {# de uma ficha que não é mais compartilhada} other {# de uma ficha que não é mais compartilhada}}',
    en: '{n, plural, one {# on a record that is no longer shared} other {# on a record that is no longer shared}}',
    es: '{n, plural, one {# de una ficha que ya no es compartida} other {# de una ficha que ya no es compartida}}',
    ca: '{n, plural, one {# d’una fitxa que ja no és compartida} other {# d’una fitxa que ja no és compartida}}',
    it: '{n, plural, one {# di una scheda non più condivisa} other {# di una scheda non più condivisa}}',
    de: '{n, plural, one {# eines nicht mehr geteilten Eintrags} other {# eines nicht mehr geteilten Eintrags}}',
    nl: '{n, plural, one {# van een record dat niet meer gedeeld is} other {# van een record dat niet meer gedeeld is}}',
    eo: '{n, plural, one {# de slipo ne plu kunhavata} other {# de slipo ne plu kunhavata}}',
    el: '{n, plural, one {# εγγραφής που δεν είναι πια κοινή} other {# εγγραφής που δεν είναι πια κοινή}}',
  },
  'catalogacao.divergences.skip.pas_detentrice': {
    fr: '{n, plural, one {# d’une notice qu’aucune bibliothèque que tu coordonnes ne détient} other {# de notices qu’aucune bibliothèque que tu coordonnes ne détient}}',
    'pt-BR': '{n, plural, one {# de uma ficha que nenhuma biblioteca que você coordena possui} other {# de fichas que nenhuma biblioteca que você coordena possui}}',
    en: '{n, plural, one {# on a record no library you coordinate holds} other {# on records no library you coordinate holds}}',
    es: '{n, plural, one {# de una ficha que ninguna biblioteca que coordinas tiene} other {# de fichas que ninguna biblioteca que coordinas tiene}}',
    ca: '{n, plural, one {# d’una fitxa que cap biblioteca que coordines no té} other {# de fitxes que cap biblioteca que coordines no té}}',
    it: '{n, plural, one {# di una scheda che nessuna biblioteca che coordini possiede} other {# di schede che nessuna biblioteca che coordini possiede}}',
    de: '{n, plural, one {# eines Eintrags, den keine von dir koordinierte Bibliothek besitzt} other {# von Einträgen, die keine von dir koordinierte Bibliothek besitzt}}',
    nl: '{n, plural, one {# van een record dat geen bibliotheek die jij coördineert bezit} other {# van records die geen bibliotheek die jij coördineert bezit}}',
    eo: '{n, plural, one {# de slipo, kiun neniu biblioteko kunordigata de vi havas} other {# de slipoj, kiujn neniu biblioteko kunordigata de vi havas}}',
    el: '{n, plural, one {# εγγραφής που δεν έχει καμία βιβλιοθήκη που συντονίζεις} other {# εγγραφών που δεν έχει καμία βιβλιοθήκη που συντονίζεις}}',
  },
  'catalogacao.divergences.skip.introuvable': {
    fr: '{n, plural, one {# introuvable} other {# introuvables}}', 'pt-BR': '{n, plural, one {# não encontrada} other {# não encontradas}}',
    en: '{n, plural, one {# not found} other {# not found}}', es: '{n, plural, one {# no encontrada} other {# no encontradas}}',
    ca: '{n, plural, one {# no trobada} other {# no trobades}}', it: '{n, plural, one {# non trovata} other {# non trovate}}',
    de: '{n, plural, one {# nicht gefunden} other {# nicht gefunden}}', nl: '{n, plural, one {# niet gevonden} other {# niet gevonden}}',
    eo: '{n, plural, one {# ne trovita} other {# ne trovitaj}}', el: '{n, plural, one {# δεν βρέθηκε} other {# δεν βρέθηκαν}}',
  },
  // ── les refus (HINT error.divergence.*) ──
  'error.divergence.coord_only': {
    fr: 'Seule la coordination d’une bibliothèque qui détient la notice (ou l’administration du réseau) traite ses divergences.',
    'pt-BR': 'Só a coordenação de uma biblioteca que possui a ficha (ou a administração da rede) trata as divergências dela.',
    en: 'Only the coordination of a library that holds the record (or the network administration) handles its divergences.',
    es: 'Solo la coordinación de una biblioteca que tiene la ficha (o la administración de la red) trata sus divergencias.',
    ca: 'Només la coordinació d’una biblioteca que té la fitxa (o l’administració de la xarxa) en tracta les divergències.',
    it: 'Solo il coordinamento di una biblioteca che possiede la scheda (o l’amministrazione della rete) ne tratta le divergenze.',
    de: 'Nur die Koordination einer Bibliothek, die den Eintrag besitzt (oder die Netzwerkverwaltung), bearbeitet seine Abweichungen.',
    nl: 'Alleen de coördinatie van een bibliotheek die het record bezit (of het netwerkbeheer) behandelt de afwijkingen ervan.',
    eo: 'Nur la kunordigo de biblioteko, kiu havas la slipon (aŭ la administrado de la reto), traktas ĝiajn diverĝojn.',
    el: 'Μόνο ο συντονισμός μιας βιβλιοθήκης που έχει την εγγραφή (ή η διαχείριση του δικτύου) χειρίζεται τις αποκλίσεις της.',
  },
  'error.divergence.page_too_large': {
    fr: 'Au plus 200 divergences à la fois : choisis-en moins.', 'pt-BR': 'No máximo 200 divergências por vez: escolha menos.',
    en: 'At most 200 divergences at a time: select fewer.', es: 'Como máximo 200 divergencias a la vez: elige menos.',
    ca: 'Com a màxim 200 divergències alhora: tria’n menys.', it: 'Al massimo 200 divergenze alla volta: scegline meno.',
    de: 'Höchstens 200 Abweichungen auf einmal: wähle weniger aus.', nl: 'Hoogstens 200 afwijkingen tegelijk: kies er minder.',
    eo: 'Maksimume 200 diverĝoj samtempe: elektu malpli.', el: 'Το πολύ 200 αποκλίσεις κάθε φορά: διάλεξε λιγότερες.',
  },
  'error.divergence.not_holder': {
    fr: 'Ta bibliothèque active ne détient pas (ou plus) cette notice : choisis comme bibliothèque active une détentrice que tu coordonnes.',
    'pt-BR': 'A sua biblioteca ativa não possui (ou não possui mais) esta ficha: escolha como biblioteca ativa uma detentora que você coordena.',
    en: 'Your active library does not (or no longer) hold this record: choose as active library a holder you coordinate.',
    es: 'Tu biblioteca activa no tiene (o ya no tiene) esta ficha: elige como biblioteca activa una poseedora que coordines.',
    ca: 'La teva biblioteca activa no té (o ja no té) aquesta fitxa: tria com a biblioteca activa una posseïdora que coordinis.',
    it: 'La tua biblioteca attiva non possiede (o non possiede più) questa scheda: scegli come biblioteca attiva una detentrice che coordini.',
    de: 'Deine aktive Bibliothek besitzt diesen Eintrag nicht (mehr): Wähle als aktive Bibliothek eine Besitzerin, die du koordinierst.',
    nl: 'Je actieve bibliotheek bezit dit record niet (meer): kies als actieve bibliotheek een bezitter die jij coördineert.',
    eo: 'Via aktiva biblioteko ne (plu) havas ĉi tiun slipon: elektu kiel aktivan bibliotekon posedanton, kiun vi kunordigas.',
    el: 'Η ενεργή σου βιβλιοθήκη δεν έχει (ή δεν έχει πια) αυτή την εγγραφή: διάλεξε ως ενεργή βιβλιοθήκη μια κάτοχο που συντονίζεις.',
  },
  'error.divergence.record_gone': {
    fr: 'La notice de ce brouillon a été retirée du catalogue : le publier en créerait une neuve. Mets le brouillon à la corbeille.',
    'pt-BR': 'A ficha deste rascunho foi retirada do catálogo: publicá-lo criaria uma nova. Mande o rascunho para a lixeira.',
    en: 'This draft’s record was removed from the catalogue: publishing it would create a new one. Move the draft to the trash.',
    es: 'La ficha de este borrador fue retirada del catálogo: publicarlo crearía una nueva. Envía el borrador a la papelera.',
    ca: 'La fitxa d’aquest esborrany s’ha retirat del catàleg: publicar-lo en crearia una de nova. Envia l’esborrany a la paperera.',
    it: 'La scheda di questa bozza è stata ritirata dal catalogo: pubblicarla ne creerebbe una nuova. Sposta la bozza nel cestino.',
    de: 'Der Eintrag dieses Entwurfs wurde aus dem Katalog entfernt: Ihn zu veröffentlichen würde einen neuen anlegen. Verschiebe den Entwurf in den Papierkorb.',
    nl: 'Het record van dit concept is uit de catalogus gehaald: publiceren zou een nieuw aanmaken. Verplaats het concept naar de prullenbak.',
    eo: 'La slipo de ĉi tiu malneto estis forigita el la katalogo: publikigi ĝin kreus novan. Movu la malneton al la rubujo.',
    el: 'Η εγγραφή αυτού του προχείρου αποσύρθηκε από τον κατάλογο: η δημοσίευσή του θα δημιουργούσε νέα. Μετακίνησε το πρόχειρο στον κάδο.',
  },
  'error.divergence.draft_exists': {
    fr: 'Un brouillon de reprise prérempli de cette notice est déjà ouvert : publie-le ou mets-le à la corbeille avant d’en préparer un autre.',
    'pt-BR': 'Já há um rascunho de retomada pré-preenchido desta ficha aberto: publique-o ou mande-o para a lixeira antes de preparar outro.',
    en: 'A prefilled revision draft of this record is already open: publish it or move it to the trash before preparing another.',
    es: 'Ya hay un borrador de revisión prerrellenado de esta ficha abierto: publícalo o envíalo a la papelera antes de preparar otro.',
    ca: 'Ja hi ha un esborrany de revisió preomplert d’aquesta fitxa obert: publica’l o envia’l a la paperera abans de preparar-ne un altre.',
    it: 'È già aperta una bozza di revisione precompilata di questa scheda: pubblicala o spostala nel cestino prima di prepararne un’altra.',
    de: 'Ein vorausgefüllter Überarbeitungsentwurf dieses Eintrags ist schon offen: Veröffentliche ihn oder verschiebe ihn in den Papierkorb, bevor du einen weiteren vorbereitest.',
    nl: 'Er staat al een vooraf ingevuld bewerkingsconcept van dit record open: publiceer het of verplaats het naar de prullenbak voor je een ander voorbereidt.',
    eo: 'Antaŭplenigita reviza malneto de ĉi tiu slipo jam estas malfermita: publikigu ĝin aŭ movu ĝin al la rubujo antaŭ ol prepari alian.',
    el: 'Υπάρχει ήδη ανοιχτό προσυμπληρωμένο πρόχειρο αναθεώρησης αυτής της εγγραφής: δημοσίευσέ το ή μετακίνησέ το στον κάδο πριν ετοιμάσεις άλλο.',
  },
  'error.divergence.nothing_to_apply': {
    fr: 'Rien à préremplir : les responsabilités et les champs que le fichier vide se reprennent à la main. Coche un autre champ, ou écarte ceux-ci.',
    'pt-BR': 'Nada a pré-preencher: as responsabilidades e os campos que o arquivo esvazia se retomam à mão. Marque outro campo, ou desconsidere estes.',
    en: 'Nothing to prefill: responsibilities and fields the file empties are taken over by hand. Tick another field, or dismiss these.',
    es: 'Nada que prerrellenar: las responsabilidades y los campos que el archivo vacía se retoman a mano. Marca otro campo, o desestima estos.',
    ca: 'Res a preomplir: les responsabilitats i els camps que el fitxer buida es reprenen a mà. Marca un altre camp, o desestima aquests.',
    it: 'Niente da precompilare: le responsabilità e i campi che il file svuota si riprendono a mano. Spunta un altro campo, oppure scarta questi.',
    de: 'Nichts vorauszufüllen: Verantwortlichkeiten und Felder, die die Datei leert, werden von Hand übernommen. Hake ein anderes Feld an oder verwirf diese.',
    nl: 'Niets vooraf in te vullen: verantwoordelijkheden en velden die het bestand leegmaakt neem je met de hand over. Vink een ander veld aan, of wijs deze af.',
    eo: 'Nenio antaŭplenigenda: la respondecoj kaj la kampoj, kiujn la dosiero malplenigas, estas reprenataj mane. Marku alian kampon, aŭ malakceptu ĉi tiujn.',
    el: 'Τίποτα προς προσυμπλήρωση: οι ευθύνες και τα πεδία που αδειάζει το αρχείο περνιούνται με το χέρι. Επίλεξε άλλο πεδίο ή απόρριψε αυτά.',
  },
  'error.divergence.same_field_twice': {
    fr: 'Deux fichiers proposent chacun une valeur pour le même champ : coche-en une seule.',
    'pt-BR': 'Dois arquivos propõem cada um um valor para o mesmo campo: marque só um.',
    en: 'Two files each propose a value for the same field: tick only one.',
    es: 'Dos archivos proponen cada uno un valor para el mismo campo: marca solo uno.',
    ca: 'Dos fitxers proposen cadascun un valor per al mateix camp: marca’n només un.',
    it: 'Due file propongono ciascuno un valore per lo stesso campo: spuntane uno solo.',
    de: 'Zwei Dateien schlagen je einen Wert für dasselbe Feld vor: Hake nur einen an.',
    nl: 'Twee bestanden stellen elk een waarde voor hetzelfde veld voor: vink er maar één aan.',
    eo: 'Du dosieroj proponas po valoron por la sama kampo: marku nur unu.',
    el: 'Δύο αρχεία προτείνουν το καθένα μια τιμή για το ίδιο πεδίο: επίλεξε μόνο μία.',
  },
  'error.divergence.bib_ref_changed': {
    fr: 'La référence (bib_ref) du brouillon n’est plus celle de la notice : remets celle de la notice, sinon les exemplaires des autres bibliothèques seraient renommés.',
    'pt-BR': 'A referência (bib_ref) do rascunho não é mais a da ficha: volte à da ficha, senão os exemplares das outras bibliotecas seriam renomeados.',
    en: 'The draft’s reference (bib_ref) is no longer the record’s: restore the record’s, otherwise the other libraries’ copies would be renamed.',
    es: 'La referencia (bib_ref) del borrador ya no es la de la ficha: vuelve a poner la de la ficha, si no los ejemplares de las otras bibliotecas se renombrarían.',
    ca: 'La referència (bib_ref) de l’esborrany ja no és la de la fitxa: torna a posar la de la fitxa, si no els exemplars de les altres biblioteques es renomenarien.',
    it: 'Il riferimento (bib_ref) della bozza non è più quello della scheda: rimetti quello della scheda, altrimenti gli esemplari delle altre biblioteche verrebbero rinominati.',
    de: 'Die Referenz (bib_ref) des Entwurfs ist nicht mehr die des Eintrags: Setze die des Eintrags wieder ein, sonst würden die Exemplare der anderen Bibliotheken umbenannt.',
    nl: 'De referentie (bib_ref) van het concept is niet meer die van het record: zet die van het record terug, anders worden de exemplaren van de andere bibliotheken hernoemd.',
    eo: 'La referenco (bib_ref) de la malneto ne plu estas tiu de la slipo: remetu tiun de la slipo, alie la ekzempleroj de la aliaj bibliotekoj estus renomitaj.',
    el: 'Η αναφορά (bib_ref) του προχείρου δεν είναι πια αυτή της εγγραφής: ξαναβάλε αυτή της εγγραφής, αλλιώς τα αντίτυπα των άλλων βιβλιοθηκών θα μετονομάζονταν.',
  },
  'error.divergence.draft_unlinked': {
    fr: 'Ce brouillon ne vient pas du geste « Appliquer » : aucune divergence ne le désigne. Mets-le à la corbeille et applique depuis la notice.',
    'pt-BR': 'Este rascunho não vem do gesto “Aplicar”: nenhuma divergência o designa. Mande-o para a lixeira e aplique a partir da ficha.',
    en: 'This draft does not come from the “Apply” action: no divergence points to it. Move it to the trash and apply from the record.',
    es: 'Este borrador no viene de la acción «Aplicar»: ninguna divergencia lo designa. Envíalo a la papelera y aplica desde la ficha.',
    ca: 'Aquest esborrany no ve de l’acció «Aplicar»: cap divergència no el designa. Envia’l a la paperera i aplica des de la fitxa.',
    it: 'Questa bozza non viene dal gesto «Applica»: nessuna divergenza la designa. Spostala nel cestino e applica dalla scheda.',
    de: 'Dieser Entwurf stammt nicht aus der Aktion „Übernehmen“: Keine Abweichung verweist auf ihn. Verschiebe ihn in den Papierkorb und übernimm vom Eintrag aus.',
    nl: 'Dit concept komt niet van de actie ‘Toepassen’: geen afwijking verwijst ernaar. Verplaats het naar de prullenbak en pas toe vanuit het record.',
    eo: 'Ĉi tiu malneto ne venas de la ago «Apliki»: neniu diverĝo indikas ĝin. Movu ĝin al la rubujo kaj apliku el la slipo.',
    el: 'Αυτό το πρόχειρο δεν προέρχεται από την ενέργεια «Εφαρμογή»: καμία απόκλιση δεν παραπέμπει σε αυτό. Μετακίνησέ το στον κάδο και εφάρμοσε από την εγγραφή.',
  },
  'error.divergence.record_changed': {
    fr: 'La notice a changé depuis le préremplissage : ce brouillon l’écraserait. Mets-le à la corbeille et applique à nouveau depuis la notice.',
    'pt-BR': 'A ficha mudou desde o pré-preenchimento: este rascunho a sobrescreveria. Mande-o para a lixeira e aplique de novo a partir da ficha.',
    en: 'The record changed since the draft was prefilled: this draft would overwrite it. Move it to the trash and apply again from the record.',
    es: 'La ficha cambió desde el prerrelleno: este borrador la sobrescribiría. Envíalo a la papelera y aplica de nuevo desde la ficha.',
    ca: 'La fitxa ha canviat des del preompliment: aquest esborrany la sobreescriuria. Envia’l a la paperera i torna a aplicar des de la fitxa.',
    it: 'La scheda è cambiata dalla precompilazione: questa bozza la sovrascriverebbe. Spostala nel cestino e applica di nuovo dalla scheda.',
    de: 'Der Eintrag hat sich seit dem Vorausfüllen geändert: Dieser Entwurf würde ihn überschreiben. Verschiebe ihn in den Papierkorb und übernimm erneut vom Eintrag aus.',
    nl: 'Het record is veranderd sinds het vooraf invullen: dit concept zou het overschrijven. Verplaats het naar de prullenbak en pas opnieuw toe vanuit het record.',
    eo: 'La slipo ŝanĝiĝis post la antaŭplenigo: ĉi tiu malneto anstataŭigus ĝin. Movu ĝin al la rubujo kaj apliku denove el la slipo.',
    el: 'Η εγγραφή άλλαξε από την προσυμπλήρωση: αυτό το πρόχειρο θα την αντικαθιστούσε. Μετακίνησέ το στον κάδο και εφάρμοσε ξανά από την εγγραφή.',
  },
  'error.divergence.draft_not_mergeable': {
    fr: 'Un brouillon prérempli depuis des divergences ne s’absorbe pas dans une notice : publie-le, ou mets-le à la corbeille.',
    'pt-BR': 'Um rascunho pré-preenchido a partir de divergências não se absorve numa ficha: publique-o, ou mande-o para a lixeira.',
    en: 'A draft prefilled from divergences cannot be merged into a record: publish it, or move it to the trash.',
    es: 'Un borrador prerrellenado a partir de divergencias no se absorbe en una ficha: publícalo, o envíalo a la papelera.',
    ca: 'Un esborrany preomplert a partir de divergències no s’absorbeix en una fitxa: publica’l, o envia’l a la paperera.',
    it: 'Una bozza precompilata a partire da divergenze non si assorbe in una scheda: pubblicala, oppure spostala nel cestino.',
    de: 'Ein aus Abweichungen vorausgefüllter Entwurf lässt sich nicht in einen Eintrag übernehmen: Veröffentliche ihn oder verschiebe ihn in den Papierkorb.',
    nl: 'Een concept dat vooraf is ingevuld vanuit afwijkingen gaat niet op in een record: publiceer het, of verplaats het naar de prullenbak.',
    eo: 'Malneto antaŭplenigita el diverĝoj ne kunfandiĝas en slipon: publikigu ĝin, aŭ movu ĝin al la rubujo.',
    el: 'Ένα πρόχειρο προσυμπληρωμένο από αποκλίσεις δεν απορροφάται σε εγγραφή: δημοσίευσέ το ή μετακίνησέ το στον κάδο.',
  },
  'error.import.trace_reserved': {
    fr: 'Cette trace d’import ne se pose pas à la main : prépare la mise à jour depuis Importations, ou applique la divergence depuis la notice.',
    'pt-BR': 'Este rastro de importação não se coloca à mão: prepare a atualização em Importações, ou aplique a divergência a partir da ficha.',
    en: 'This import trace cannot be set by hand: prepare the update from Imports, or apply the divergence from the record.',
    es: 'Este rastro de importación no se pone a mano: prepara la actualización desde Importaciones, o aplica la divergencia desde la ficha.',
    ca: 'Aquest rastre d’importació no es posa a mà: prepara l’actualització des d’Importacions, o aplica la divergència des de la fitxa.',
    it: 'Questa traccia di importazione non si pone a mano: prepara l’aggiornamento da Importazioni, oppure applica la divergenza dalla scheda.',
    de: 'Diese Importspur lässt sich nicht von Hand setzen: Bereite die Aktualisierung unter Importe vor oder übernimm die Abweichung vom Eintrag aus.',
    nl: 'Dit importspoor zet je niet met de hand: bereid de update voor in Imports, of pas de afwijking toe vanuit het record.',
    eo: 'Ĉi tiu importa spuro ne estas metebla mane: preparu la ĝisdatigon en Importoj, aŭ apliku la diverĝon el la slipo.',
    el: 'Αυτό το ίχνος εισαγωγής δεν μπαίνει με το χέρι: ετοίμασε την ενημέρωση από τις Εισαγωγές ή εφάρμοσε την απόκλιση από την εγγραφή.',
  },
  // ── Importations, lot 4 : la notice partagée est signalée ──
  'importacoes.fila.prepareSkip.partagee': {
    fr: '{n, plural, one {# notice partagée avec une autre bibliothèque (jamais réécrite par un réimport : signalée aux détentrices)} other {# notices partagées avec une autre bibliothèque (jamais réécrites par un réimport : signalées aux détentrices)}}',
    'pt-BR': '{n, plural, one {# ficha compartilhada com outra biblioteca (nunca reescrita por uma reimportação: sinalizada às detentoras)} other {# fichas compartilhadas com outra biblioteca (nunca reescritas por uma reimportação: sinalizadas às detentoras)}}',
    en: '{n, plural, one {# record shared with another library (never rewritten by a reimport: flagged to its holders)} other {# records shared with another library (never rewritten by a reimport: flagged to their holders)}}',
    es: '{n, plural, one {# ficha compartida con otra biblioteca (nunca reescrita por una reimportación: señalada a las poseedoras)} other {# fichas compartidas con otra biblioteca (nunca reescritas por una reimportación: señaladas a las poseedoras)}}',
    ca: '{n, plural, one {# fitxa compartida amb una altra biblioteca (mai reescrita per una reimportació: assenyalada a les posseïdores)} other {# fitxes compartides amb una altra biblioteca (mai reescrites per una reimportació: assenyalades a les posseïdores)}}',
    it: '{n, plural, one {# scheda condivisa con un’altra biblioteca (mai riscritta da una reimportazione: segnalata alle detentrici)} other {# schede condivise con un’altra biblioteca (mai riscritte da una reimportazione: segnalate alle detentrici)}}',
    de: '{n, plural, one {# Eintrag mit einer anderen Bibliothek geteilt (nie von einem Neuimport überschrieben: den Besitzerinnen gemeldet)} other {# Einträge mit einer anderen Bibliothek geteilt (nie von einem Neuimport überschrieben: den Besitzerinnen gemeldet)}}',
    nl: '{n, plural, one {# record gedeeld met een andere bibliotheek (nooit herschreven door een herimport: gemeld aan de bezitters)} other {# records gedeeld met een andere bibliotheek (nooit herschreven door een herimport: gemeld aan de bezitters)}}',
    eo: '{n, plural, one {# slipo kunhavata kun alia biblioteko (neniam reskribita de reimporto: signalita al la posedantoj)} other {# slipoj kunhavataj kun alia biblioteko (neniam reskribitaj de reimporto: signalitaj al la posedantoj)}}',
    el: '{n, plural, one {# εγγραφή κοινή με άλλη βιβλιοθήκη (δεν ξαναγράφεται ποτέ από επανεισαγωγή: επισημαίνεται στις κατόχους)} other {# εγγραφές κοινές με άλλη βιβλιοθήκη (δεν ξαναγράφονται ποτέ από επανεισαγωγή: επισημαίνονται στις κατόχους)}}',
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
