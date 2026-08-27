/* ===========================================================================
 * i18n-add-periodiques-ui.cjs
 * Chantier « interface périodiques » : fiche éditable d'un titre, filiation,
 * numéros rattachés, doublons de titres, et l'option « periódico » du
 * formulaire de fusion de l'Atelier. 61 clés × 10 locales.
 *
 * Idempotent (sentinelle par clé), purement textuel : insertion avant le `}`
 * final, jamais de re-sérialisation JSON.
 *
 * Y compris six clés `error.serial.*` : localizeError traduit le HINT posé par
 * la RPC, sans whitelist. Sans elles, « filiation circulaire refusée » — le
 * refus le plus probable sur le fonds Anarchief — retomberait sur un message
 * générique qui ne dit pas quoi corriger.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const KEYS = {
  // ── Liste : filtre ──────────────────────────────────────────────────────
  'catalogacao.serialGov.filterPh': {
    'pt-BR': 'Filtrar por título, slug ou ISSN…', fr: 'Filtrer par titre, slug ou ISSN…',
    es: 'Filtrar por título, slug o ISSN…', en: 'Filter by title, slug or ISSN…',
    it: 'Filtrare per titolo, slug o ISSN…', de: 'Nach Titel, Slug oder ISSN filtern…',
    ca: 'Filtrar per títol, slug o ISSN…', eo: 'Filtri laŭ titolo, slug aŭ ISSN…',
    nl: 'Filter op titel, slug of ISSN…', el: 'Φιλτράρισμα κατά τίτλο, slug ή ISSN…',
  },
  'catalogacao.serialGov.noMatch': {
    'pt-BR': 'Nenhum título corresponde ao filtro.', fr: 'Aucun titre ne correspond au filtre.',
    es: 'Ningún título coincide con el filtro.', en: 'No title matches the filter.',
    it: 'Nessun titolo corrisponde al filtro.', de: 'Kein Titel entspricht dem Filter.',
    ca: 'Cap títol coincideix amb el filtre.', eo: 'Neniu titolo kongruas kun la filtrilo.',
    nl: 'Geen titel voldoet aan het filter.', el: 'Κανένας τίτλος δεν ταιριάζει στο φίλτρο.',
  },

  // ── Fiche : description ─────────────────────────────────────────────────
  'catalogacao.serialDetail.description': {
    'pt-BR': 'Descrição', fr: 'Description', es: 'Descripción', en: 'Description',
    it: 'Descrizione', de: 'Beschreibung', ca: 'Descripció', eo: 'Priskribo',
    nl: 'Beschrijving', el: 'Περιγραφή',
  },
  'catalogacao.serialDetail.uniformTitle': {
    'pt-BR': 'Título retido', fr: 'Titre retenu', es: 'Título uniforme', en: 'Uniform title',
    it: 'Titolo uniforme', de: 'Einheitstitel', ca: 'Títol uniforme', eo: 'Unueca titolo',
    nl: 'Uniforme titel', el: 'Καθιερωμένος τίτλος',
  },
  'catalogacao.serialDetail.slugFixed': {
    'pt-BR': 'O endereço público continua /periodico/{slug} mesmo se o título mudar: alterá-lo quebraria os links já compartilhados.',
    fr: 'L’adresse publique reste /periodico/{slug} même si le titre change : la modifier casserait les liens déjà partagés.',
    es: 'La dirección pública sigue siendo /periodico/{slug} aunque cambie el título: modificarla rompería los enlaces ya compartidos.',
    en: 'The public address stays /periodico/{slug} even if the title changes: altering it would break links already shared.',
    it: 'L’indirizzo pubblico resta /periodico/{slug} anche se il titolo cambia: modificarlo romperebbe i link già condivisi.',
    de: 'Die öffentliche Adresse bleibt /periodico/{slug}, auch wenn sich der Titel ändert: sie zu ändern würde bereits geteilte Links zerstören.',
    ca: 'L’adreça pública continua sent /periodico/{slug} encara que canviï el títol: modificar-la trencaria els enllaços ja compartits.',
    eo: 'La publika adreso restas /periodico/{slug} eĉ se la titolo ŝanĝiĝas: ŝanĝi ĝin rompus jam kunhavigitajn ligilojn.',
    nl: 'Het publieke adres blijft /periodico/{slug} ook als de titel verandert: het wijzigen zou reeds gedeelde links breken.',
    el: 'Η δημόσια διεύθυνση παραμένει /periodico/{slug} ακόμη κι αν αλλάξει ο τίτλος: η αλλαγή της θα έσπαγε ήδη κοινοποιημένους συνδέσμους.',
  },
  'catalogacao.serialDetail.sortTitle': {
    'pt-BR': 'Forma de ordenação', fr: 'Forme de tri', es: 'Forma de ordenación',
    en: 'Sort form', it: 'Forma di ordinamento', de: 'Sortierform',
    ca: 'Forma d’ordenació', eo: 'Ordiga formo', nl: 'Sorteervorm', el: 'Μορφή ταξινόμησης',
  },
  'catalogacao.serialDetail.emitter': {
    'pt-BR': 'Organização editora', fr: 'Organisation éditrice', es: 'Organización editora',
    en: 'Issuing body', it: 'Organizzazione editrice', de: 'Herausgebende Organisation',
    ca: 'Organització editora', eo: 'Eldona organizo', nl: 'Uitgevende organisatie',
    el: 'Εκδότρια οργάνωση',
  },
  'catalogacao.serialDetail.issnLHint': {
    'pt-BR': 'Liga os suportes de um mesmo título (papel, on-line).',
    fr: 'Relie les supports d’un même titre (papier, en ligne).',
    es: 'Enlaza los soportes de un mismo título (papel, en línea).',
    en: 'Links the media of a single title (print, online).',
    it: 'Collega i supporti di uno stesso titolo (carta, in linea).',
    de: 'Verbindet die Ausgabeformen eines Titels (Druck, online).',
    ca: 'Enllaça els suports d’un mateix títol (paper, en línia).',
    eo: 'Ligas la surfacojn de sama titolo (papero, reta).',
    nl: 'Verbindt de dragers van eenzelfde titel (papier, online).',
    el: 'Συνδέει τα υποστρώματα ενός τίτλου (έντυπο, ηλεκτρονικό).',
  },
  'catalogacao.serialDetail.startYear': {
    'pt-BR': 'Início', fr: 'Début', es: 'Inicio', en: 'Start', it: 'Inizio',
    de: 'Beginn', ca: 'Inici', eo: 'Komenco', nl: 'Begin', el: 'Έναρξη',
  },
  'catalogacao.serialDetail.endYear': {
    'pt-BR': 'Fim', fr: 'Fin', es: 'Fin', en: 'End', it: 'Fine',
    de: 'Ende', ca: 'Fi', eo: 'Fino', nl: 'Einde', el: 'Λήξη',
  },
  'catalogacao.serialDetail.stillRunning': {
    'pt-BR': 'Ainda publicado', fr: 'Paraît toujours', es: 'Sigue publicándose',
    en: 'Still running', it: 'Ancora in corso', de: 'Erscheint weiterhin',
    ca: 'Encara es publica', eo: 'Ankoraŭ aperas', nl: 'Verschijnt nog',
    el: 'Εξακολουθεί να εκδίδεται',
  },
  'catalogacao.serialDetail.place': {
    'pt-BR': 'Local de publicação', fr: 'Lieu de publication', es: 'Lugar de publicación',
    en: 'Place of publication', it: 'Luogo di pubblicazione', de: 'Erscheinungsort',
    ca: 'Lloc de publicació', eo: 'Eldonloko', nl: 'Plaats van uitgave',
    el: 'Τόπος έκδοσης',
  },
  'catalogacao.serialDetail.frequency': {
    'pt-BR': 'Periodicidade', fr: 'Périodicité', es: 'Periodicidad', en: 'Frequency',
    it: 'Periodicità', de: 'Erscheinungsweise', ca: 'Periodicitat', eo: 'Aperofteco',
    nl: 'Verschijningsfrequentie', el: 'Συχνότητα έκδοσης',
  },
  'catalogacao.serialDetail.language': {
    'pt-BR': 'Idioma', fr: 'Langue', es: 'Idioma', en: 'Language', it: 'Lingua',
    de: 'Sprache', ca: 'Idioma', eo: 'Lingvo', nl: 'Taal', el: 'Γλώσσα',
  },
  'catalogacao.serialDetail.country': {
    'pt-BR': 'País', fr: 'Pays', es: 'País', en: 'Country', it: 'Paese',
    de: 'Land', ca: 'País', eo: 'Lando', nl: 'Land', el: 'Χώρα',
  },
  'catalogacao.serialDetail.altForms': {
    'pt-BR': 'Formas paralelas ({locale})', fr: 'Formes parallèles ({locale})',
    es: 'Formas paralelas ({locale})', en: 'Parallel forms ({locale})',
    it: 'Forme parallele ({locale})', de: 'Parallelformen ({locale})',
    ca: 'Formes paral·leles ({locale})', eo: 'Paralelaj formoj ({locale})',
    nl: 'Parallelvormen ({locale})', el: 'Παράλληλες μορφές ({locale})',
  },
  'catalogacao.serialDetail.altFormsHint': {
    'pt-BR': 'Uma por linha. As outras línguas não são tocadas.',
    fr: 'Une par ligne. Les autres langues ne sont pas touchées.',
    es: 'Una por línea. Los otros idiomas no se tocan.',
    en: 'One per line. Other languages are left untouched.',
    it: 'Una per riga. Le altre lingue non vengono toccate.',
    de: 'Eine pro Zeile. Andere Sprachen bleiben unberührt.',
    ca: 'Una per línia. Els altres idiomes no es toquen.',
    eo: 'Unu po linio. La aliaj lingvoj ne estas tuŝitaj.',
    nl: 'Eén per regel. De andere talen blijven onaangeroerd.',
    el: 'Μία ανά γραμμή. Οι άλλες γλώσσες δεν θίγονται.',
  },
  'catalogacao.serialDetail.scopeNote': {
    'pt-BR': 'Nota de aplicação', fr: 'Note d’application', es: 'Nota de alcance',
    en: 'Scope note', it: 'Nota d’ambito', de: 'Anwendungshinweis',
    ca: 'Nota d’abast', eo: 'Apliknoto', nl: 'Toepassingsnotitie', el: 'Σημείωση εμβέλειας',
  },
  'catalogacao.serialDetail.save': {
    'pt-BR': 'Registrar a descrição', fr: 'Enregistrer la description',
    es: 'Guardar la descripción', en: 'Save the description',
    it: 'Salvare la descrizione', de: 'Beschreibung speichern',
    ca: 'Desar la descripció', eo: 'Konservi la priskribon',
    nl: 'Beschrijving opslaan', el: 'Αποθήκευση περιγραφής',
  },
  'catalogacao.serialDetail.saved': {
    'pt-BR': 'Descrição registrada.', fr: 'Description enregistrée.',
    es: 'Descripción guardada.', en: 'Description saved.',
    it: 'Descrizione salvata.', de: 'Beschreibung gespeichert.',
    ca: 'Descripció desada.', eo: 'Priskribo konservita.',
    nl: 'Beschrijving opgeslagen.', el: 'Η περιγραφή αποθηκεύτηκε.',
  },
  'catalogacao.serialDetail.saveFailed': {
    'pt-BR': 'Não foi possível registrar a descrição.', fr: 'La description n’a pas pu être enregistrée.',
    es: 'No se ha podido guardar la descripción.', en: 'The description could not be saved.',
    it: 'Non è stato possibile salvare la descrizione.', de: 'Die Beschreibung konnte nicht gespeichert werden.',
    ca: 'No s’ha pogut desar la descripció.', eo: 'Ne eblis konservi la priskribon.',
    nl: 'De beschrijving kon niet worden opgeslagen.', el: 'Δεν ήταν δυνατή η αποθήκευση της περιγραφής.',
  },

  // ── Fiche : filiation ───────────────────────────────────────────────────
  'catalogacao.serialDetail.filiation': {
    'pt-BR': 'Filiação', fr: 'Filiation', es: 'Filiación', en: 'Title history',
    it: 'Filiazione', de: 'Titelabfolge', ca: 'Filiació', eo: 'Titola sinsekvo',
    nl: 'Titelopvolging', el: 'Διαδοχή τίτλων',
  },
  'catalogacao.serialDetail.filiation.intro': {
    'pt-BR': 'Um jornal que muda de nome continua o mesmo fundo. Ligar os dois títulos evita duas coleções sem relação. A reciprocidade é posta automaticamente, e um ciclo é recusado.',
    fr: 'Un journal qui change de nom reste le même fonds. Relier les deux titres évite deux collections sans lien. La réciprocité est posée automatiquement, et un cycle est refusé.',
    es: 'Un periódico que cambia de nombre sigue siendo el mismo fondo. Enlazar ambos títulos evita dos colecciones sin relación. La reciprocidad se pone automáticamente, y un ciclo se rechaza.',
    en: 'A paper that changes its name is still the same run. Linking both titles avoids two unrelated collections. The reciprocal link is set automatically, and a cycle is refused.',
    it: 'Un giornale che cambia nome resta lo stesso fondo. Collegare i due titoli evita due collezioni senza legame. La reciprocità è posta automaticamente e un ciclo viene rifiutato.',
    de: 'Eine Zeitung, die ihren Namen ändert, bleibt derselbe Bestand. Beide Titel zu verknüpfen verhindert zwei unverbundene Reihen. Die Gegenrichtung wird automatisch gesetzt, ein Zirkel abgelehnt.',
    ca: 'Un diari que canvia de nom continua sent el mateix fons. Enllaçar els dos títols evita dues col·leccions sense relació. La reciprocitat es posa automàticament, i un cicle es rebutja.',
    eo: 'Ĵurnalo kiu ŝanĝas nomon restas la sama fonduso. Ligi la du titolojn evitas du senrilatajn kolektojn. La reciprokeco estas metita aŭtomate, kaj ciklo estas rifuzita.',
    nl: 'Een blad dat van naam verandert blijft dezelfde reeks. Beide titels koppelen voorkomt twee losstaande collecties. De omgekeerde link wordt automatisch gelegd, een kring wordt geweigerd.',
    el: 'Μια εφημερίδα που αλλάζει όνομα παραμένει το ίδιο σώμα. Η σύνδεση των δύο τίτλων αποτρέπει δύο άσχετες συλλογές. Η αμοιβαιότητα τίθεται αυτόματα και ο κύκλος απορρίπτεται.',
  },
  'catalogacao.serialDetail.filiation.predecessor': {
    'pt-BR': 'Título anterior', fr: 'Titre précédent', es: 'Título anterior',
    en: 'Preceding title', it: 'Titolo precedente', de: 'Vorheriger Titel',
    ca: 'Títol anterior', eo: 'Antaŭa titolo', nl: 'Voorgaande titel', el: 'Προηγούμενος τίτλος',
  },
  'catalogacao.serialDetail.filiation.successor': {
    'pt-BR': 'Título seguinte', fr: 'Titre suivant', es: 'Título siguiente',
    en: 'Succeeding title', it: 'Titolo successivo', de: 'Nachfolgender Titel',
    ca: 'Títol següent', eo: 'Sekva titolo', nl: 'Volgende titel', el: 'Επόμενος τίτλος',
  },
  'catalogacao.serialDetail.filiation.searchPh': {
    'pt-BR': 'Buscar um título…', fr: 'Chercher un titre…', es: 'Buscar un título…',
    en: 'Search a title…', it: 'Cercare un titolo…', de: 'Titel suchen…',
    ca: 'Cercar un títol…', eo: 'Serĉi titolon…', nl: 'Zoek een titel…',
    el: 'Αναζήτηση τίτλου…',
  },
  'catalogacao.serialDetail.filiation.clear': {
    'pt-BR': 'Retirar', fr: 'Retirer', es: 'Quitar', en: 'Remove', it: 'Rimuovere',
    de: 'Entfernen', ca: 'Treure', eo: 'Forigi', nl: 'Verwijderen', el: 'Αφαίρεση',
  },
  'catalogacao.serialDetail.filiation.saved': {
    'pt-BR': 'Filiação registrada.', fr: 'Filiation enregistrée.', es: 'Filiación guardada.',
    en: 'Title history saved.', it: 'Filiazione registrata.', de: 'Titelabfolge gespeichert.',
    ca: 'Filiació desada.', eo: 'Titola sinsekvo konservita.', nl: 'Titelopvolging opgeslagen.',
    el: 'Η διαδοχή τίτλων αποθηκεύτηκε.',
  },
  'catalogacao.serialDetail.filiation.failed': {
    'pt-BR': 'Não foi possível registrar a filiação.', fr: 'La filiation n’a pas pu être enregistrée.',
    es: 'No se ha podido guardar la filiación.', en: 'The title history could not be saved.',
    it: 'Non è stato possibile registrare la filiazione.', de: 'Die Titelabfolge konnte nicht gespeichert werden.',
    ca: 'No s’ha pogut desar la filiació.', eo: 'Ne eblis konservi la titolan sinsekvon.',
    nl: 'De titelopvolging kon niet worden opgeslagen.', el: 'Δεν ήταν δυνατή η αποθήκευση της διαδοχής.',
  },

  // ── Fiche : numéros ─────────────────────────────────────────────────────
  'catalogacao.serialDetail.issues': {
    'pt-BR': 'Números ({count})', fr: 'Numéros ({count})', es: 'Números ({count})',
    en: 'Issues ({count})', it: 'Numeri ({count})', de: 'Hefte ({count})',
    ca: 'Números ({count})', eo: 'Numeroj ({count})', nl: 'Nummers ({count})',
    el: 'Τεύχη ({count})',
  },
  'catalogacao.serialDetail.issues.none': {
    'pt-BR': 'Nenhum número vinculado.', fr: 'Aucun numéro rattaché.',
    es: 'Ningún número vinculado.', en: 'No issue linked.',
    it: 'Nessun numero collegato.', de: 'Kein Heft verknüpft.',
    ca: 'Cap número vinculat.', eo: 'Neniu numero ligita.',
    nl: 'Geen nummer gekoppeld.', el: 'Δεν έχει συνδεθεί τεύχος.',
  },
  'catalogacao.serialDetail.issues.detach': {
    'pt-BR': 'Desvincular', fr: 'Détacher', es: 'Desvincular', en: 'Unlink',
    it: 'Scollegare', de: 'Lösen', ca: 'Desvincular', eo: 'Malligi',
    nl: 'Ontkoppelen', el: 'Αποσύνδεση',
  },
  'catalogacao.serialDetail.issues.attach': {
    'pt-BR': 'Vincular um número já catalogado', fr: 'Rattacher un numéro déjà catalogué',
    es: 'Vincular un número ya catalogado', en: 'Link an already catalogued issue',
    it: 'Collegare un numero già catalogato', de: 'Ein bereits erfasstes Heft verknüpfen',
    ca: 'Vincular un número ja catalogat', eo: 'Ligi jam katalogitan numeron',
    nl: 'Een reeds gecatalogiseerd nummer koppelen', el: 'Σύνδεση ήδη καταλογογραφημένου τεύχους',
  },
  'catalogacao.serialDetail.issues.attachPh': {
    'pt-BR': 'Buscar entre os fascículos sem título…', fr: 'Chercher parmi les fascicules sans titre…',
    es: 'Buscar entre los fascículos sin título…', en: 'Search among unlinked issues…',
    it: 'Cercare tra i fascicoli senza titolo…', de: 'Unter den nicht verknüpften Heften suchen…',
    ca: 'Cercar entre els fascicles sense títol…', eo: 'Serĉi inter la neligitaj kajeroj…',
    nl: 'Zoeken onder niet-gekoppelde nummers…', el: 'Αναζήτηση στα μη συνδεδεμένα τεύχη…',
  },
  'catalogacao.serialDetail.issues.attached': {
    'pt-BR': 'Número vinculado.', fr: 'Numéro rattaché.', es: 'Número vinculado.',
    en: 'Issue linked.', it: 'Numero collegato.', de: 'Heft verknüpft.',
    ca: 'Número vinculat.', eo: 'Numero ligita.', nl: 'Nummer gekoppeld.',
    el: 'Το τεύχος συνδέθηκε.',
  },
  'catalogacao.serialDetail.issues.detached': {
    'pt-BR': 'Número desvinculado.', fr: 'Numéro détaché.', es: 'Número desvinculado.',
    en: 'Issue unlinked.', it: 'Numero scollegato.', de: 'Heft gelöst.',
    ca: 'Número desvinculat.', eo: 'Numero malligita.', nl: 'Nummer ontkoppeld.',
    el: 'Το τεύχος αποσυνδέθηκε.',
  },
  'catalogacao.serialDetail.issues.attachFailed': {
    'pt-BR': 'A operação sobre o número falhou.', fr: 'L’opération sur le numéro a échoué.',
    es: 'La operación sobre el número ha fallado.', en: 'The operation on the issue failed.',
    it: 'L’operazione sul numero non è riuscita.', de: 'Die Operation am Heft ist fehlgeschlagen.',
    ca: 'L’operació sobre el número ha fallat.', eo: 'La operacio pri la numero malsukcesis.',
    nl: 'De bewerking op het nummer is mislukt.', el: 'Η ενέργεια στο τεύχος απέτυχε.',
  },

  // ── Doublons de titres ──────────────────────────────────────────────────
  'catalogacao.serialDup.title': {
    'pt-BR': 'Duplicatas de títulos', fr: 'Doublons de titres', es: 'Duplicados de títulos',
    en: 'Duplicate titles', it: 'Duplicati di titoli', de: 'Doppelte Titel',
    ca: 'Duplicats de títols', eo: 'Duoblaj titoloj', nl: 'Dubbele titels',
    el: 'Διπλότυποι τίτλοι',
  },
  'catalogacao.serialDup.intro': {
    'pt-BR': 'Dois números de uma mesma revista não são duplicatas — dois TÍTULOS próximos, sim. Fundir apaga uma autoridade que outras bibliotecas talvez usem: a proposta vai ao Ateliê e se delibera lá.',
    fr: 'Deux numéros d’une même revue ne sont pas des doublons — deux TITRES proches, si. Fusionner supprime une autorité que d’autres bibliothèques utilisent peut-être : la proposition part à l’Atelier et s’y délibère.',
    es: 'Dos números de una misma revista no son duplicados — dos TÍTULOS próximos, sí. Fusionar borra una autoridad que otras bibliotecas quizá usen: la propuesta va al Taller y allí se delibera.',
    en: 'Two issues of one serial are not duplicates — two close TITLES are. Merging deletes an authority other libraries may be using: the proposal goes to the Workshop and is deliberated there.',
    it: 'Due numeri di uno stesso periodico non sono duplicati — due TITOLI vicini sì. Fondere elimina un’autorità che altre biblioteche forse usano: la proposta va all’Atelier e lì si delibera.',
    de: 'Zwei Hefte derselben Zeitschrift sind keine Dubletten — zwei ähnliche TITEL schon. Eine Zusammenführung löscht Normdaten, die andere Bibliotheken vielleicht nutzen: der Vorschlag geht an die Werkstatt und wird dort beraten.',
    ca: 'Dos números d’una mateixa revista no són duplicats — dos TÍTOLS propers, sí. Fusionar esborra una autoritat que altres biblioteques potser fan servir: la proposta va al Taller i s’hi delibera.',
    eo: 'Du numeroj de sama periodaĵo ne estas duoblaĵoj — du proksimaj TITOLOJ jes. Kunfandi forigas aŭtoritaton kiun aliaj bibliotekoj eble uzas: la propono iras al la Metiejo kaj tie pridiskutiĝas.',
    nl: 'Twee nummers van hetzelfde tijdschrift zijn geen dubbels — twee gelijkende TITELS wel. Samenvoegen wist autoriteitsgegevens die andere bibliotheken misschien gebruiken: het voorstel gaat naar het Atelier en wordt daar besproken.',
    el: 'Δύο τεύχη του ίδιου περιοδικού δεν είναι διπλότυπα — δύο κοντινοί ΤΙΤΛΟΙ είναι. Η συγχώνευση διαγράφει μια καθιέρωση που ίσως χρησιμοποιούν άλλες βιβλιοθήκες: η πρόταση πηγαίνει στο Εργαστήριο και συζητείται εκεί.',
  },
  'catalogacao.serialDup.empty': {
    'pt-BR': 'Nenhuma duplicata de título detectada.', fr: 'Aucun doublon de titre détecté.',
    es: 'Ningún duplicado de título detectado.', en: 'No duplicate title detected.',
    it: 'Nessun duplicato di titolo rilevato.', de: 'Keine doppelten Titel erkannt.',
    ca: 'Cap duplicat de títol detectat.', eo: 'Neniu duobla titolo detektita.',
    nl: 'Geen dubbele titel gevonden.', el: 'Δεν εντοπίστηκε διπλότυπος τίτλος.',
  },
  'catalogacao.serialDup.keepThis': {
    'pt-BR': 'Manter « {titre} »', fr: 'Garder « {titre} »', es: 'Conservar « {titre} »',
    en: 'Keep “{titre}”', it: 'Tenere « {titre} »', de: '„{titre}“ behalten',
    ca: 'Conservar « {titre} »', eo: 'Konservi « {titre} »', nl: '‘{titre}’ behouden',
    el: 'Διατήρηση «{titre}»',
  },
  'catalogacao.serialDup.notDuplicate': {
    'pt-BR': 'Não são duplicatas', fr: 'Ce ne sont pas des doublons',
    es: 'No son duplicados', en: 'Not duplicates', it: 'Non sono duplicati',
    de: 'Keine Dubletten', ca: 'No són duplicats', eo: 'Ne estas duoblaĵoj',
    nl: 'Geen dubbels', el: 'Δεν είναι διπλότυπα',
  },
  'catalogacao.serialDup.reasonPh': {
    'pt-BR': 'Motivo (opcional)', fr: 'Motif (facultatif)', es: 'Motivo (opcional)',
    en: 'Reason (optional)', it: 'Motivo (facoltativo)', de: 'Grund (optional)',
    ca: 'Motiu (opcional)', eo: 'Kialo (nedeviga)', nl: 'Reden (optioneel)',
    el: 'Αιτιολογία (προαιρετική)',
  },
  'catalogacao.serialDup.discarded': {
    'pt-BR': 'Par afastado das detecções.', fr: 'Paire écartée des détections.',
    es: 'Par descartado de las detecciones.', en: 'Pair set aside from detection.',
    it: 'Coppia esclusa dalle rilevazioni.', de: 'Paar von der Erkennung ausgenommen.',
    ca: 'Parella descartada de les deteccions.', eo: 'Paro forigita el la detektoj.',
    nl: 'Paar uitgesloten van detectie.', el: 'Το ζεύγος εξαιρέθηκε από τον εντοπισμό.',
  },
  'catalogacao.serialDup.restored': {
    'pt-BR': 'Par restabelecido.', fr: 'Paire rétablie.', es: 'Par restablecido.',
    en: 'Pair restored.', it: 'Coppia ripristinata.', de: 'Paar wiederhergestellt.',
    ca: 'Parella restablerta.', eo: 'Paro restarigita.', nl: 'Paar hersteld.',
    el: 'Το ζεύγος αποκαταστάθηκε.',
  },
  'catalogacao.serialDup.restore': {
    'pt-BR': 'Restabelecer', fr: 'Rétablir', es: 'Restablecer', en: 'Restore',
    it: 'Ripristinare', de: 'Wiederherstellen', ca: 'Restablir', eo: 'Restarigi',
    nl: 'Herstellen', el: 'Αποκατάσταση',
  },
  'catalogacao.serialDup.discardedList': {
    'pt-BR': 'Pares afastados ({count})', fr: 'Paires écartées ({count})',
    es: 'Pares descartados ({count})', en: 'Pairs set aside ({count})',
    it: 'Coppie escluse ({count})', de: 'Ausgenommene Paare ({count})',
    ca: 'Parelles descartades ({count})', eo: 'Forigitaj paroj ({count})',
    nl: 'Uitgesloten paren ({count})', el: 'Εξαιρεμένα ζεύγη ({count})',
  },
  'catalogacao.serialDup.proposed': {
    'pt-BR': 'Proposta de fusão enviada ao Ateliê.', fr: 'Proposition de fusion envoyée à l’Atelier.',
    es: 'Propuesta de fusión enviada al Taller.', en: 'Merge proposal sent to the Workshop.',
    it: 'Proposta di fusione inviata all’Atelier.', de: 'Zusammenführungsvorschlag an die Werkstatt gesendet.',
    ca: 'Proposta de fusió enviada al Taller.', eo: 'Kunfanda propono sendita al la Metiejo.',
    nl: 'Samenvoegvoorstel naar het Atelier gestuurd.', el: 'Η πρόταση συγχώνευσης στάλθηκε στο Εργαστήριο.',
  },
  'catalogacao.serialDup.failed': {
    'pt-BR': 'A operação falhou.', fr: 'L’opération a échoué.', es: 'La operación ha fallado.',
    en: 'The operation failed.', it: 'L’operazione non è riuscita.', de: 'Der Vorgang ist fehlgeschlagen.',
    ca: 'L’operació ha fallat.', eo: 'La operacio malsukcesis.', nl: 'De bewerking is mislukt.',
    el: 'Η ενέργεια απέτυχε.',
  },
  'catalogacao.serialDup.rationale': {
    'pt-BR': '« {dup} » (#{dupId}) → « {can} » (#{canId}). Detectado: {niveau}.',
    fr: '« {dup} » (#{dupId}) → « {can} » (#{canId}). Détecté : {niveau}.',
    es: '« {dup} » (#{dupId}) → « {can} » (#{canId}). Detectado: {niveau}.',
    en: '“{dup}” (#{dupId}) → “{can}” (#{canId}). Detected: {niveau}.',
    it: '« {dup} » (#{dupId}) → « {can} » (#{canId}). Rilevato: {niveau}.',
    de: '„{dup}“ (#{dupId}) → „{can}“ (#{canId}). Erkannt: {niveau}.',
    ca: '« {dup} » (#{dupId}) → « {can} » (#{canId}). Detectat: {niveau}.',
    eo: '« {dup} » (#{dupId}) → « {can} » (#{canId}). Detektita: {niveau}.',
    nl: '‘{dup}’ (#{dupId}) → ‘{can}’ (#{canId}). Gedetecteerd: {niveau}.',
    el: '«{dup}» (#{dupId}) → «{can}» (#{canId}). Εντοπίστηκε: {niveau}.',
  },
  'catalogacao.serialDup.level.issn': {
    'pt-BR': 'mesmo ISSN', fr: 'même ISSN', es: 'mismo ISSN', en: 'same ISSN',
    it: 'stesso ISSN', de: 'gleiche ISSN', ca: 'mateix ISSN', eo: 'sama ISSN',
    nl: 'zelfde ISSN', el: 'ίδιο ISSN',
  },
  'catalogacao.serialDup.level.titre_exact': {
    'pt-BR': 'título idêntico', fr: 'titre identique', es: 'título idéntico',
    en: 'identical title', it: 'titolo identico', de: 'identischer Titel',
    ca: 'títol idèntic', eo: 'identa titolo', nl: 'identieke titel',
    el: 'ταυτόσημος τίτλος',
  },
  'catalogacao.serialDup.level.issn_de_liaison': {
    'pt-BR': 'mesmo ISSN-L', fr: 'même ISSN-L', es: 'mismo ISSN-L', en: 'same ISSN-L',
    it: 'stesso ISSN-L', de: 'gleiche ISSN-L', ca: 'mateix ISSN-L', eo: 'sama ISSN-L',
    nl: 'zelfde ISSN-L', el: 'ίδιο ISSN-L',
  },
  'catalogacao.serialDup.level.titre_proche': {
    'pt-BR': 'título próximo', fr: 'titre proche', es: 'título parecido',
    en: 'close title', it: 'titolo simile', de: 'ähnlicher Titel',
    ca: 'títol semblant', eo: 'proksima titolo', nl: 'gelijkende titel',
    el: 'παρόμοιος τίτλος',
  },

  // ── Atelier ─────────────────────────────────────────────────────────────
  'atelier.kind.serial': {
    'pt-BR': 'Periódico (serial)', fr: 'Périodique (serial)', es: 'Publicación periódica (serial)',
    en: 'Serial', it: 'Periodico (serial)', de: 'Zeitschrift (serial)',
    ca: 'Publicació periòdica (serial)', eo: 'Periodaĵo (serial)',
    nl: 'Tijdschrift (serial)', el: 'Περιοδικό (serial)',
  },

  // ── HINT des RPC, lus par localizeError ────────────────────────────────
  'error.serial.filiation.cycle': {
    'pt-BR': 'Filiação circular recusada: um título não pode preceder aquele que o precede.',
    fr: 'Filiation circulaire refusée : un titre ne peut pas précéder celui qui le précède.',
    es: 'Filiación circular rechazada: un título no puede preceder al que lo precede.',
    en: 'Circular title history refused: a title cannot precede the one that precedes it.',
    it: 'Filiazione circolare rifiutata: un titolo non può precedere quello che lo precede.',
    de: 'Zirkuläre Titelabfolge abgelehnt: ein Titel kann dem nicht vorausgehen, der ihm vorausgeht.',
    ca: 'Filiació circular rebutjada: un títol no pot precedir el que el precedeix.',
    eo: 'Cikla sinsekvo rifuzita: titolo ne povas antaŭi tiun kiu antaŭas ĝin.',
    nl: 'Kringvormige titelopvolging geweigerd: een titel kan niet voorafgaan aan wat hem voorafgaat.',
    el: 'Κυκλική διαδοχή: ένας τίτλος δεν μπορεί να προηγείται εκείνου που προηγείται του.',
  },
  'error.serial.filiation.tooLong': {
    'pt-BR': 'Cadeia de filiação longa demais (mais de 20 elos).',
    fr: 'Chaîne de filiation trop longue (plus de 20 maillons).',
    es: 'Cadena de filiación demasiado larga (más de 20 eslabones).',
    en: 'Title history chain too long (over 20 links).',
    it: 'Catena di filiazione troppo lunga (oltre 20 anelli).',
    de: 'Titelabfolge zu lang (über 20 Glieder).',
    ca: 'Cadena de filiació massa llarga (més de 20 baules).',
    eo: 'Ĉeno de sinsekvo tro longa (pli ol 20 eroj).',
    nl: 'Keten van titelopvolging te lang (meer dan 20 schakels).',
    el: 'Πολύ μακριά αλυσίδα διαδοχής (πάνω από 20 κρίκους).',
  },
  'error.serial.attach.wrongMaterial': {
    'pt-BR': 'Só um fascículo ou um artigo pode ser vinculado a um título de periódico.',
    fr: 'Seul un fascicule ou un article peut être rattaché à un titre de périodique.',
    es: 'Solo un fascículo o un artículo puede vincularse a un título de publicación periódica.',
    en: 'Only an issue or an article can be linked to a serial title.',
    it: 'Solo un fascicolo o un articolo può essere collegato a un titolo di periodico.',
    de: 'Nur ein Heft oder ein Artikel kann mit einem Zeitschriftentitel verknüpft werden.',
    ca: 'Només un fascicle o un article es pot vincular a un títol de publicació periòdica.',
    eo: 'Nur kajero aŭ artikolo povas esti ligita al titolo de periodaĵo.',
    nl: 'Alleen een aflevering of een artikel kan aan een tijdschrifttitel worden gekoppeld.',
    el: 'Μόνο ένα τεύχος ή ένα άρθρο μπορεί να συνδεθεί με τίτλο περιοδικού.',
  },
  'error.serial.title.required': {
    'pt-BR': 'O título retido não pode ficar vazio.', fr: 'Le titre retenu ne peut pas être vide.',
    es: 'El título uniforme no puede estar vacío.', en: 'The uniform title cannot be empty.',
    it: 'Il titolo uniforme non può essere vuoto.', de: 'Der Einheitstitel darf nicht leer sein.',
    ca: 'El títol uniforme no pot estar buit.', eo: 'La unueca titolo ne povas esti malplena.',
    nl: 'De uniforme titel mag niet leeg zijn.', el: 'Ο καθιερωμένος τίτλος δεν μπορεί να είναι κενός.',
  },
  'error.serial.notDuplicate.invalidPair': {
    'pt-BR': 'Par de periódicos inválido.', fr: 'Paire de périodiques invalide.',
    es: 'Par de publicaciones periódicas no válido.', en: 'Invalid pair of serials.',
    it: 'Coppia di periodici non valida.', de: 'Ungültiges Zeitschriftenpaar.',
    ca: 'Parella de publicacions periòdiques no vàlida.', eo: 'Nevalida paro de periodaĵoj.',
    nl: 'Ongeldig paar tijdschriften.', el: 'Μη έγκυρο ζεύγος περιοδικών.',
  },
  'error.serial.issue.notFound': {
    'pt-BR': 'Documento não encontrado.', fr: 'Document introuvable.',
    es: 'Documento no encontrado.', en: 'Document not found.',
    it: 'Documento non trovato.', de: 'Dokument nicht gefunden.',
    ca: 'Document no trobat.', eo: 'Dokumento ne trovita.',
    nl: 'Document niet gevonden.', el: 'Το τεκμήριο δεν βρέθηκε.',
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
console.log('\nTerminé — ' + added + ' entrée(s) (' + Object.keys(KEYS).length + ' clés × ' + LOCALES.length + ' locales).');
