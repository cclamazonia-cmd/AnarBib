/* ===========================================================================
 * i18n-add-periodiques-gouvernance.cjs
 * Panneau de coordination des titres de périodiques (onglet du catalogage) :
 * promotion / dépréciation, et saisie de l'état de collection DÉCLARÉ.
 * 32 clés × 10 locales. Idempotent (sentinelle par clé), purement textuel.
 *
 * Cinq clés `error.serial.*` sont incluses : localizeError n'a pas de
 * whitelist, il traduit le HINT posé par la RPC. Sans elles, un refus de rôle
 * retomberait sur un message générique — l'information « tu n'es pas
 * coordination DE CETTE bibliothèque » serait perdue au moment précis où elle
 * sert.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const KEYS = {
  'catalogacao.tab.periodicos': {
    'pt-BR': 'Periódicos', fr: 'Périodiques', es: 'Publicaciones periódicas', en: 'Serials',
    it: 'Periodici', de: 'Zeitschriften', ca: 'Publicacions periòdiques', eo: 'Periodaĵoj',
    nl: 'Tijdschriften', el: 'Περιοδικά',
  },
  'catalogacao.serialGov.title': {
    'pt-BR': 'Coordenação de periódicos', fr: 'Coordination des périodiques',
    es: 'Coordinación de publicaciones periódicas', en: 'Serials coordination',
    it: 'Coordinamento dei periodici', de: 'Zeitschriften-Koordination',
    ca: 'Coordinació de publicacions periòdiques', eo: 'Kunordigo de periodaĵoj',
    nl: 'Coördinatie van tijdschriften', el: 'Συντονισμός περιοδικών',
  },
  'catalogacao.serialGov.intro': {
    'pt-BR': 'Um título criado durante a catalogação nasce PROPOSTO, portanto invisível ao público. É aqui que ele é promovido — e que cada biblioteca declara o que possui.',
    fr: 'Un titre créé au catalogage naît PROPOSÉ, donc invisible du public. C’est ici qu’il est promu — et que chaque bibliothèque déclare ce qu’elle possède.',
    es: 'Un título creado durante la catalogación nace PROPUESTO, por tanto invisible al público. Aquí se promueve — y cada biblioteca declara lo que posee.',
    en: 'A title created while cataloguing is born PROPOSED, hence invisible to the public. This is where it gets promoted — and where each library states what it holds.',
    it: 'Un titolo creato durante la catalogazione nasce PROPOSTO, quindi invisibile al pubblico. È qui che viene promosso — e che ogni biblioteca dichiara ciò che possiede.',
    de: 'Ein beim Katalogisieren angelegter Titel entsteht als VORGESCHLAGEN und ist damit öffentlich unsichtbar. Hier wird er bestätigt — und hier gibt jede Bibliothek ihren Bestand an.',
    ca: 'Un títol creat durant la catalogació neix PROPOSAT, per tant invisible al públic. Aquí es promou — i cada biblioteca declara què posseeix.',
    eo: 'Titolo kreita dum katalogado naskiĝas PROPONITA, do publike nevidebla. Ĉi tie ĝi estas promociita — kaj ĉiu biblioteko deklaras kion ĝi posedas.',
    nl: 'Een titel die tijdens het catalogiseren ontstaat is VOORGESTELD en dus publiek onzichtbaar. Hier wordt hij bevestigd — en geeft elke bibliotheek haar bezit aan.',
    el: 'Ένας τίτλος που δημιουργείται κατά την καταλογογράφηση γεννιέται ΠΡΟΤΕΙΝΟΜΕΝΟΣ, άρα αόρατος στο κοινό. Εδώ προάγεται — και εδώ κάθε βιβλιοθήκη δηλώνει τι κατέχει.',
  },
  'catalogacao.serialGov.coordOnly': {
    'pt-BR': 'Você pode consultar esta lista; promover ou depreciar cabe à coordenação de catalogação.',
    fr: 'Tu peux consulter cette liste ; promouvoir ou déprécier revient à la coordination catalogage.',
    es: 'Puedes consultar esta lista; promover o depreciar corresponde a la coordinación de catalogación.',
    en: 'You can browse this list; promoting or deprecating is up to the cataloguing coordination.',
    it: 'Puoi consultare questa lista; promuovere o deprecare spetta al coordinamento di catalogazione.',
    de: 'Du kannst diese Liste einsehen; bestätigen oder zurückziehen ist Sache der Katalogisierungs-Koordination.',
    ca: 'Pots consultar aquesta llista; promoure o depreciar correspon a la coordinació de catalogació.',
    eo: 'Vi povas konsulti ĉi tiun liston; promocii aŭ malrekomendi apartenas al la kunordigo de katalogado.',
    nl: 'Je kunt deze lijst bekijken; bevestigen of afvoeren is aan de catalogiseringscoördinatie.',
    el: 'Μπορείτε να δείτε αυτή τη λίστα· η προαγωγή ή η απόσυρση ανήκει στον συντονισμό καταλογογράφησης.',
  },
  'catalogacao.serialGov.empty': {
    'pt-BR': 'Nenhum título de periódico ainda.', fr: 'Aucun titre de périodique pour l’instant.',
    es: 'Ningún título de publicación periódica por ahora.', en: 'No serial titles yet.',
    it: 'Nessun titolo di periodico per ora.', de: 'Noch keine Zeitschriftentitel.',
    ca: 'Cap títol de publicació periòdica de moment.', eo: 'Ankoraŭ neniu titolo de periodaĵo.',
    nl: 'Nog geen tijdschrifttitels.', el: 'Δεν υπάρχουν ακόμη τίτλοι περιοδικών.',
  },
  'catalogacao.serialGov.promote': {
    'pt-BR': 'Promover', fr: 'Promouvoir', es: 'Promover', en: 'Promote',
    it: 'Promuovere', de: 'Bestätigen', ca: 'Promoure', eo: 'Promocii',
    nl: 'Bevestigen', el: 'Προαγωγή',
  },
  'catalogacao.serialGov.deprecate': {
    'pt-BR': 'Depreciar', fr: 'Déprécier', es: 'Depreciar', en: 'Deprecate',
    it: 'Deprecare', de: 'Zurückziehen', ca: 'Depreciar', eo: 'Malrekomendi',
    nl: 'Afvoeren', el: 'Απόσυρση',
  },
  'catalogacao.serialGov.statusUpdated': {
    'pt-BR': 'Estado atualizado.', fr: 'Statut mis à jour.', es: 'Estado actualizado.',
    en: 'Status updated.', it: 'Stato aggiornato.', de: 'Status aktualisiert.',
    ca: 'Estat actualitzat.', eo: 'Stato ĝisdatigita.', nl: 'Status bijgewerkt.',
    el: 'Η κατάσταση ενημερώθηκε.',
  },
  'catalogacao.serialGov.statusFailed': {
    'pt-BR': 'Não foi possível alterar o estado.', fr: 'Le statut n’a pas pu être modifié.',
    es: 'No se ha podido cambiar el estado.', en: 'The status could not be changed.',
    it: 'Non è stato possibile cambiare lo stato.', de: 'Der Status konnte nicht geändert werden.',
    ca: 'No s’ha pogut canviar l’estat.', eo: 'Ne eblis ŝanĝi la staton.',
    nl: 'De status kon niet worden gewijzigd.', el: 'Δεν ήταν δυνατή η αλλαγή της κατάστασης.',
  },
  'catalogacao.serialGov.status.proposto': {
    'pt-BR': 'proposto', fr: 'proposé', es: 'propuesto', en: 'proposed',
    it: 'proposto', de: 'vorgeschlagen', ca: 'proposat', eo: 'proponita',
    nl: 'voorgesteld', el: 'προτεινόμενος',
  },
  'catalogacao.serialGov.status.ativo': {
    'pt-BR': 'ativo', fr: 'actif', es: 'activo', en: 'active',
    it: 'attivo', de: 'aktiv', ca: 'actiu', eo: 'aktiva',
    nl: 'actief', el: 'ενεργός',
  },
  'catalogacao.serialGov.status.depreciado': {
    'pt-BR': 'depreciado', fr: 'déprécié', es: 'depreciado', en: 'deprecated',
    it: 'deprecato', de: 'zurückgezogen', ca: 'depreciat', eo: 'malrekomendita',
    nl: 'afgevoerd', el: 'αποσυρμένος',
  },
  'catalogacao.serialGov.issues': {
    'pt-BR': '{count, plural, one {# número catalogado} other {# números catalogados}}',
    fr: '{count, plural, one {# numéro catalogué} other {# numéros catalogués}}',
    es: '{count, plural, one {# número catalogado} other {# números catalogados}}',
    en: '{count, plural, one {# catalogued issue} other {# catalogued issues}}',
    it: '{count, plural, one {# numero catalogato} other {# numeri catalogati}}',
    de: '{count, plural, one {# erfasstes Heft} other {# erfasste Hefte}}',
    ca: '{count, plural, one {# número catalogat} other {# números catalogats}}',
    eo: '{count, plural, one {# katalogita numero} other {# katalogitaj numeroj}}',
    nl: '{count, plural, one {# gecatalogiseerd nummer} other {# gecatalogiseerde nummers}}',
    el: '{count, plural, one {# καταλογογραφημένο τεύχος} other {# καταλογογραφημένα τεύχη}}',
  },
  'catalogacao.serialGov.viewPublic': {
    'pt-BR': 'ver a página pública', fr: 'voir la page publique', es: 'ver la página pública',
    en: 'view the public page', it: 'vedere la pagina pubblica', de: 'öffentliche Seite ansehen',
    ca: 'veure la pàgina pública', eo: 'vidi la publikan paĝon', nl: 'bekijk de publieke pagina',
    el: 'δείτε τη δημόσια σελίδα',
  },
  'catalogacao.serialGov.holdings': {
    'pt-BR': 'Estado da coleção', fr: 'État de collection', es: 'Estado de la colección',
    en: 'Holdings statement', it: 'Consistenza', de: 'Bestandsangabe',
    ca: 'Estat de la col·lecció', eo: 'Stato de la kolekto', nl: 'Bezitsaanduiding',
    el: 'Κατάσταση συλλογής',
  },
  'catalogacao.serialGov.holdings.declaredWins': {
    'pt-BR': 'O que você declara é o que aparece. O cálculo abaixo apenas acompanha: ele diz o que está catalogado, nunca que uma lacuna é definitiva.',
    fr: 'Ce que tu déclares est ce qui s’affiche. Le calcul ci-dessous ne fait qu’accompagner : il dit ce qui est catalogué, jamais qu’une lacune est définitive.',
    es: 'Lo que declaras es lo que se muestra. El cálculo de abajo solo acompaña: dice lo que está catalogado, nunca que una laguna sea definitiva.',
    en: 'What you state is what is shown. The figure below only accompanies it: it says what is catalogued, never that a gap is permanent.',
    it: 'Ciò che dichiari è ciò che appare. Il calcolo qui sotto accompagna soltanto: dice ciò che è catalogato, mai che una lacuna sia definitiva.',
    de: 'Was du angibst, wird angezeigt. Die Berechnung darunter begleitet nur: sie sagt, was erfasst ist, nie dass eine Lücke endgültig ist.',
    ca: 'El que declares és el que es mostra. El càlcul de sota només acompanya: diu què està catalogat, mai que una llacuna sigui definitiva.',
    eo: 'Kion vi deklaras, tio aperas. La suba kalkulo nur akompanas: ĝi diras kio estas katalogita, neniam ke manko estas definitiva.',
    nl: 'Wat jij aangeeft, is wat getoond wordt. De berekening hieronder begeleidt alleen: zij zegt wat gecatalogiseerd is, nooit dat een hiaat definitief is.',
    el: 'Αυτό που δηλώνετε είναι αυτό που εμφανίζεται. Ο παρακάτω υπολογισμός απλώς συνοδεύει: λέει τι έχει καταλογογραφηθεί, ποτέ ότι ένα κενό είναι οριστικό.',
  },
  'catalogacao.serialGov.holdings.computed': {
    'pt-BR': 'Calculado: {first}–{last} ({count})', fr: 'Calculé : {first}–{last} ({count})',
    es: 'Calculado: {first}–{last} ({count})', en: 'Computed: {first}–{last} ({count})',
    it: 'Calcolato: {first}–{last} ({count})', de: 'Berechnet: {first}–{last} ({count})',
    ca: 'Calculat: {first}–{last} ({count})', eo: 'Kalkulita: {first}–{last} ({count})',
    nl: 'Berekend: {first}–{last} ({count})', el: 'Υπολογισμένο: {first}–{last} ({count})',
  },
  'catalogacao.serialGov.holdings.statement': {
    'pt-BR': 'Estado declarado', fr: 'État déclaré', es: 'Estado declarado',
    en: 'Stated holdings', it: 'Consistenza dichiarata', de: 'Angegebener Bestand',
    ca: 'Estat declarat', eo: 'Deklarita stato', nl: 'Aangegeven bezit',
    el: 'Δηλωμένη κατάσταση',
  },
  'catalogacao.serialGov.holdings.statementPh': {
    'pt-BR': '1896-1914, lacunas: n.º 23, 1902', fr: '1896-1914, lacunes : n° 23, 1902',
    es: '1896-1914, lagunas: n.º 23, 1902', en: '1896-1914, gaps: no. 23, 1902',
    it: '1896-1914, lacune: n. 23, 1902', de: '1896-1914, Lücken: Nr. 23, 1902',
    ca: '1896-1914, llacunes: núm. 23, 1902', eo: '1896-1914, mankoj: n-ro 23, 1902',
    nl: '1896-1914, hiaten: nr. 23, 1902', el: '1896-1914, κενά: αρ. 23, 1902',
  },
  'catalogacao.serialGov.holdings.gaps': {
    'pt-BR': 'Precisões sobre as lacunas', fr: 'Précisions sur les lacunes',
    es: 'Precisiones sobre las lagunas', en: 'Notes on the gaps',
    it: 'Precisazioni sulle lacune', de: 'Hinweise zu den Lücken',
    ca: 'Precisions sobre les llacunes', eo: 'Precizigoj pri la mankoj',
    nl: 'Toelichting bij de hiaten', el: 'Διευκρινίσεις για τα κενά',
  },
  'catalogacao.serialGov.holdings.completeness': {
    'pt-BR': 'Completude', fr: 'Complétude', es: 'Completitud', en: 'Completeness',
    it: 'Completezza', de: 'Vollständigkeit', ca: 'Completesa', eo: 'Kompleteco',
    nl: 'Volledigheid', el: 'Πληρότητα',
  },
  'catalogacao.serialGov.holdings.unknown': {
    'pt-BR': 'Não informado', fr: 'Non renseigné', es: 'Sin indicar', en: 'Not stated',
    it: 'Non indicato', de: 'Keine Angabe', ca: 'Sense indicar', eo: 'Ne indikita',
    nl: 'Niet opgegeven', el: 'Δεν δηλώθηκε',
  },
  'catalogacao.serialGov.holdings.isPublic': {
    'pt-BR': 'Mostrar ao público', fr: 'Montrer au public', es: 'Mostrar al público',
    en: 'Show publicly', it: 'Mostrare al pubblico', de: 'Öffentlich zeigen',
    ca: 'Mostrar al públic', eo: 'Montri publike', nl: 'Publiek tonen',
    el: 'Εμφάνιση στο κοινό',
  },
  'catalogacao.serialGov.holdings.save': {
    'pt-BR': 'Registrar', fr: 'Enregistrer', es: 'Guardar', en: 'Save',
    it: 'Salvare', de: 'Speichern', ca: 'Desar', eo: 'Konservi',
    nl: 'Opslaan', el: 'Αποθήκευση',
  },
  'catalogacao.serialGov.holdings.saved': {
    'pt-BR': 'Estado da coleção registrado.', fr: 'État de collection enregistré.',
    es: 'Estado de la colección guardado.', en: 'Holdings statement saved.',
    it: 'Consistenza registrata.', de: 'Bestandsangabe gespeichert.',
    ca: 'Estat de la col·lecció desat.', eo: 'Stato de la kolekto konservita.',
    nl: 'Bezitsaanduiding opgeslagen.', el: 'Η κατάσταση συλλογής αποθηκεύτηκε.',
  },
  'catalogacao.serialGov.holdings.failed': {
    'pt-BR': 'Não foi possível registrar o estado da coleção.',
    fr: 'L’état de collection n’a pas pu être enregistré.',
    es: 'No se ha podido guardar el estado de la colección.',
    en: 'The holdings statement could not be saved.',
    it: 'Non è stato possibile registrare la consistenza.',
    de: 'Die Bestandsangabe konnte nicht gespeichert werden.',
    ca: 'No s’ha pogut desar l’estat de la col·lecció.',
    eo: 'Ne eblis konservi la staton de la kolekto.',
    nl: 'De bezitsaanduiding kon niet worden opgeslagen.',
    el: 'Δεν ήταν δυνατή η αποθήκευση της κατάστασης συλλογής.',
  },
  'catalogacao.serialGov.holdings.noLibrary': {
    'pt-BR': 'Só a coordenação de uma biblioteca pode declarar o que ela possui.',
    fr: 'Seule la coordination d’une bibliothèque peut déclarer ce qu’elle possède.',
    es: 'Solo la coordinación de una biblioteca puede declarar lo que posee.',
    en: 'Only a library’s coordination can state what that library holds.',
    it: 'Solo il coordinamento di una biblioteca può dichiarare ciò che essa possiede.',
    de: 'Nur die Koordination einer Bibliothek kann deren Bestand angeben.',
    ca: 'Només la coordinació d’una biblioteca pot declarar què posseeix.',
    eo: 'Nur la kunordigo de biblioteko povas deklari kion ĝi posedas.',
    nl: 'Alleen de coördinatie van een bibliotheek kan haar bezit aangeven.',
    el: 'Μόνο ο συντονισμός μιας βιβλιοθήκης μπορεί να δηλώσει τι κατέχει.',
  },

  // ── HINT des RPC, lus par localizeError ────────────────────────────────
  'error.serial.forbidden': {
    'pt-BR': 'Reservado ao staff de catalogação.', fr: 'Réservé au staff de catalogage.',
    es: 'Reservado al personal de catalogación.', en: 'Restricted to cataloguing staff.',
    it: 'Riservato al personale di catalogazione.', de: 'Nur für das Katalogisierungsteam.',
    ca: 'Reservat al personal de catalogació.', eo: 'Rezervita al la kataloga skipo.',
    nl: 'Voorbehouden aan het catalogiseringsteam.', el: 'Μόνο για το προσωπικό καταλογογράφησης.',
  },
  'error.serial.status.forbidden': {
    'pt-BR': 'Promover ou depreciar um título cabe à coordenação de catalogação.',
    fr: 'Promouvoir ou déprécier un titre revient à la coordination catalogage.',
    es: 'Promover o depreciar un título corresponde a la coordinación de catalogación.',
    en: 'Promoting or deprecating a title is up to the cataloguing coordination.',
    it: 'Promuovere o deprecare un titolo spetta al coordinamento di catalogazione.',
    de: 'Einen Titel zu bestätigen oder zurückzuziehen ist Sache der Katalogisierungs-Koordination.',
    ca: 'Promoure o depreciar un títol correspon a la coordinació de catalogació.',
    eo: 'Promocii aŭ malrekomendi titolon apartenas al la kunordigo de katalogado.',
    nl: 'Een titel bevestigen of afvoeren is aan de catalogiseringscoördinatie.',
    el: 'Η προαγωγή ή απόσυρση τίτλου ανήκει στον συντονισμό καταλογογράφησης.',
  },
  'error.serial.holdings.forbidden': {
    'pt-BR': 'Só a coordenação DESTA biblioteca pode declarar o estado da coleção.',
    fr: 'Seule la coordination DE CETTE bibliothèque peut déclarer l’état de collection.',
    es: 'Solo la coordinación DE ESTA biblioteca puede declarar el estado de la colección.',
    en: 'Only THIS library’s coordination can state its holdings.',
    it: 'Solo il coordinamento DI QUESTA biblioteca può dichiarare la consistenza.',
    de: 'Nur die Koordination DIESER Bibliothek kann deren Bestand angeben.',
    ca: 'Només la coordinació D’AQUESTA biblioteca pot declarar l’estat de la col·lecció.',
    eo: 'Nur la kunordigo DE ĈI TIU biblioteko povas deklari la staton de la kolekto.',
    nl: 'Alleen de coördinatie VAN DEZE bibliotheek kan haar bezit aangeven.',
    el: 'Μόνο ο συντονισμός ΑΥΤΗΣ της βιβλιοθήκης μπορεί να δηλώσει την κατάσταση συλλογής.',
  },
  'error.serial.holdings.completeness': {
    'pt-BR': 'Nível de completude inválido.', fr: 'Niveau de complétude invalide.',
    es: 'Nivel de completitud no válido.', en: 'Invalid completeness level.',
    it: 'Livello di completezza non valido.', de: 'Ungültige Vollständigkeitsstufe.',
    ca: 'Nivell de completesa no vàlid.', eo: 'Nevalida nivelo de kompleteco.',
    nl: 'Ongeldige volledigheidsgraad.', el: 'Μη έγκυρο επίπεδο πληρότητας.',
  },
  'error.serial.notFound': {
    'pt-BR': 'Periódico não encontrado.', fr: 'Revue introuvable.',
    es: 'Revista no encontrada.', en: 'Serial not found.',
    it: 'Periodico non trovato.', de: 'Zeitschrift nicht gefunden.',
    ca: 'Revista no trobada.', eo: 'Periodaĵo ne trovita.',
    nl: 'Tijdschrift niet gevonden.', el: 'Το περιοδικό δεν βρέθηκε.',
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
