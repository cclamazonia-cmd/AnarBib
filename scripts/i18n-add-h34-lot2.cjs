/* ===========================================================================
 * i18n-add-h34-lot2.cjs — H34 lot 2 (12/10/2026, REGISTRE IMP-36) : un lot
 * approuvé se publie par pages. publish_catalog_batch publie au plus une page
 * par appel (60 notices et 400 exemplaires, une notice et ses exemplaires
 * jamais séparés) ; « Publier le lot » enchaîne les appels et montre
 * l'avancement ; un lot « publishing » (publication en cours) montre
 * « Reprendre la publication ». Pendant « publishing », rien ne s'ajoute ni ne
 * se retouche (error.batch.publishing_locked) ; un second appel concurrent est
 * refusé (error.batch.publication_busy).
 * Tutoiement partout ; pt-BR au « você ». Vocabulaire repris des clés voisines
 * (lot, notice/ficha/registro/scheda/Datensatz/record/fitxa/katalogero/fiche/
 * εγγραφή ; exemplaire et ses équivalents).
 * Idempotent : une clé déjà posée n'est réécrite que si sa valeur a changé ici.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const CLES = {
  'catalogacao.batch.status.publishing': {
    fr: 'Publication en cours',
    'pt-BR': 'Publicação em andamento',
    en: 'Publication in progress',
    es: 'Publicación en curso',
    ca: 'Publicació en curs',
    it: 'Pubblicazione in corso',
    de: 'Veröffentlichung läuft',
    nl: 'Publicatie bezig',
    eo: 'Publikigo daŭras',
    el: 'Δημοσίευση σε εξέλιξη',
  },
  'catalogacao.batch.publication.resume': {
    fr: 'Reprendre la publication',
    'pt-BR': 'Retomar a publicação',
    en: 'Resume publication',
    es: 'Reanudar la publicación',
    ca: 'Reprendre la publicació',
    it: 'Riprendi la pubblicazione',
    de: 'Veröffentlichung fortsetzen',
    nl: 'Publicatie hervatten',
    eo: 'Daŭrigi la publikigon',
    el: 'Συνέχιση της δημοσίευσης',
  },
  'catalogacao.batch.publication.resumeConfirm': {
    fr: 'Reprendre la publication de ce lot ? Les pages déjà publiées le restent ; la suite est irréversible elle aussi.',
    'pt-BR': 'Retomar a publicação deste lote? As páginas já publicadas continuam publicadas; o restante também é irreversível.',
    en: 'Resume publishing this batch? The pages already published stay published; the rest cannot be undone either.',
    es: '¿Reanudar la publicación de este lote? Las páginas ya publicadas siguen publicadas; lo que falta tampoco se puede deshacer.',
    ca: 'Vols reprendre la publicació d’aquest lot? Les pàgines ja publicades continuen publicades; la resta tampoc no es pot desfer.',
    it: 'Riprendere la pubblicazione di questo lotto? Le pagine già pubblicate restano tali; anche il resto è irreversibile.',
    de: 'Die Veröffentlichung dieses Stapels fortsetzen? Bereits veröffentlichte Seiten bleiben veröffentlicht; auch der Rest lässt sich nicht rückgängig machen.',
    nl: 'De publicatie van dit lot hervatten? Al gepubliceerde pagina’s blijven gepubliceerd; ook de rest kan niet ongedaan worden gemaakt.',
    eo: 'Ĉu daŭrigi la publikigon de ĉi tiu loto? La jam publikigitaj paĝoj restas publikigitaj; ankaŭ la resto ne estas malfarebla.',
    el: 'Συνέχιση της δημοσίευσης αυτής της παρτίδας; Οι σελίδες που έχουν ήδη δημοσιευτεί παραμένουν· ούτε το υπόλοιπο αναιρείται.',
  },
  'catalogacao.batch.publication.progress': {
    fr: 'Publication en cours : page {page}, {notices, plural, one {# notice publiée} other {# notices publiées}} sur {total}…',
    'pt-BR': 'Publicação em andamento: página {page}, {notices, plural, one {# ficha publicada} other {# fichas publicadas}} de {total}…',
    en: 'Publishing: page {page}, {notices, plural, one {# record published} other {# records published}} out of {total}…',
    es: 'Publicación en curso: página {page}, {notices, plural, one {# registro publicado} other {# registros publicados}} de {total}…',
    ca: 'Publicació en curs: pàgina {page}, {notices, plural, one {# fitxa publicada} other {# fitxes publicades}} de {total}…',
    it: 'Pubblicazione in corso: pagina {page}, {notices, plural, one {# scheda pubblicata} other {# schede pubblicate}} su {total}…',
    de: 'Veröffentlichung läuft: Seite {page}, {notices, plural, one {# Datensatz veröffentlicht} other {# Datensätze veröffentlicht}} von {total}…',
    nl: 'Publicatie bezig: pagina {page}, {notices, plural, one {# fiche gepubliceerd} other {# fiches gepubliceerd}} van {total}…',
    eo: 'Publikigo daŭras: paĝo {page}, {notices, plural, one {# katalogero publikigita} other {# katalogeroj publikigitaj}} el {total}…',
    el: 'Δημοσίευση σε εξέλιξη: σελίδα {page}, {notices, plural, one {# εγγραφή δημοσιεύτηκε} other {# εγγραφές δημοσιεύτηκαν}} από {total}…',
  },
  'catalogacao.batch.publication.donePages': {
    fr: 'Lot publié en {pages} pages : {notices, plural, one {# notice} other {# notices}} et {exemplaires, plural, one {# exemplaire} other {# exemplaires}}.',
    'pt-BR': 'Lote publicado em {pages} páginas: {notices, plural, one {# ficha} other {# fichas}} e {exemplaires, plural, one {# exemplar} other {# exemplares}}.',
    en: 'Batch published in {pages} pages: {notices, plural, one {# record} other {# records}} and {exemplaires, plural, one {# copy} other {# copies}}.',
    es: 'Lote publicado en {pages} páginas: {notices, plural, one {# registro} other {# registros}} y {exemplaires, plural, one {# ejemplar} other {# ejemplares}}.',
    ca: 'Lot publicat en {pages} pàgines: {notices, plural, one {# fitxa} other {# fitxes}} i {exemplaires, plural, one {# exemplar} other {# exemplars}}.',
    it: 'Lotto pubblicato in {pages} pagine: {notices, plural, one {# scheda} other {# schede}} e {exemplaires, plural, one {# esemplare} other {# esemplari}}.',
    de: 'Stapel in {pages} Seiten veröffentlicht: {notices, plural, one {# Datensatz} other {# Datensätze}} und {exemplaires, plural, one {# Exemplar} other {# Exemplare}}.',
    nl: 'Lot gepubliceerd in {pages} pagina’s: {notices, plural, one {# fiche} other {# fiches}} en {exemplaires, plural, one {# exemplaar} other {# exemplaren}}.',
    eo: 'Loto publikigita en {pages} paĝoj: {notices, plural, one {# katalogero} other {# katalogeroj}} kaj {exemplaires, plural, one {# ekzemplero} other {# ekzempleroj}}.',
    el: 'Η παρτίδα δημοσιεύτηκε σε {pages} σελίδες: {notices, plural, one {# εγγραφή} other {# εγγραφές}} και {exemplaires, plural, one {# αντίτυπο} other {# αντίτυπα}}.',
  },
  'catalogacao.batch.publication.beforeRefusal': {
    fr: 'Avant ce refus, {pages, plural, one {# page a été publiée} other {# pages ont été publiées}} ({notices, plural, one {# notice} other {# notices}}, {exemplaires, plural, one {# exemplaire} other {# exemplaires}}) : elles le restent.',
    'pt-BR': 'Antes desta recusa, {pages, plural, one {# página foi publicada} other {# páginas foram publicadas}} ({notices, plural, one {# ficha} other {# fichas}}, {exemplaires, plural, one {# exemplar} other {# exemplares}}): elas continuam publicadas.',
    en: 'Before this refusal, {pages, plural, one {# page was published} other {# pages were published}} ({notices, plural, one {# record} other {# records}}, {exemplaires, plural, one {# copy} other {# copies}}): they stay published.',
    es: 'Antes de este rechazo, {pages, plural, one {se publicó # página} other {se publicaron # páginas}} ({notices, plural, one {# registro} other {# registros}}, {exemplaires, plural, one {# ejemplar} other {# ejemplares}}): siguen publicadas.',
    ca: 'Abans d’aquest rebuig, {pages, plural, one {s’ha publicat # pàgina} other {s’han publicat # pàgines}} ({notices, plural, one {# fitxa} other {# fitxes}}, {exemplaires, plural, one {# exemplar} other {# exemplars}}): continuen publicades.',
    it: 'Prima di questo rifiuto, {pages, plural, one {è stata pubblicata # pagina} other {sono state pubblicate # pagine}} ({notices, plural, one {# scheda} other {# schede}}, {exemplaires, plural, one {# esemplare} other {# esemplari}}): restano pubblicate.',
    de: 'Vor dieser Ablehnung {pages, plural, one {wurde # Seite} other {wurden # Seiten}} veröffentlicht ({notices, plural, one {# Datensatz} other {# Datensätze}}, {exemplaires, plural, one {# Exemplar} other {# Exemplare}}): sie bleiben veröffentlicht.',
    nl: 'Vóór deze weigering {pages, plural, one {is # pagina} other {zijn # pagina’s}} gepubliceerd ({notices, plural, one {# fiche} other {# fiches}}, {exemplaires, plural, one {# exemplaar} other {# exemplaren}}): die blijven gepubliceerd.',
    eo: 'Antaŭ ĉi tiu rifuzo, {pages, plural, one {# paĝo estis publikigita} other {# paĝoj estis publikigitaj}} ({notices, plural, one {# katalogero} other {# katalogeroj}}, {exemplaires, plural, one {# ekzemplero} other {# ekzempleroj}}): ili restas publikigitaj.',
    el: 'Πριν από αυτή την άρνηση, {pages, plural, one {δημοσιεύτηκε # σελίδα} other {δημοσιεύτηκαν # σελίδες}} ({notices, plural, one {# εγγραφή} other {# εγγραφές}}, {exemplaires, plural, one {# αντίτυπο} other {# αντίτυπα}}): παραμένουν δημοσιευμένες.',
  },
  'catalogacao.batch.publication.howToResume': {
    fr: 'Le lot reste « Publication en cours » : « Reprendre la publication » relance la page refusée. Pour corriger un brouillon, il faut un nouveau tour de révision (l’administration du réseau rouvre la révision).',
    'pt-BR': 'O lote continua em “Publicação em andamento”: “Retomar a publicação” tenta de novo a página recusada. Para corrigir um rascunho, é preciso uma nova rodada de revisão (a administração da rede reabre a revisão).',
    en: 'The batch stays “Publication in progress”: “Resume publication” retries the refused page. To fix a draft, a new review round is needed (the network administration reopens the review).',
    es: 'El lote sigue en «Publicación en curso»: «Reanudar la publicación» vuelve a intentar la página rechazada. Para corregir un borrador hace falta una nueva vuelta de revisión (la administración de la red reabre la revisión).',
    ca: 'El lot continua en «Publicació en curs»: «Reprendre la publicació» torna a intentar la pàgina rebutjada. Per corregir un esborrany cal una nova volta de revisió (l’administració de la xarxa reobre la revisió).',
    it: 'Il lotto resta in «Pubblicazione in corso»: «Riprendi la pubblicazione» ritenta la pagina rifiutata. Per correggere una bozza serve un nuovo giro di revisione (l’amministrazione della rete riapre la revisione).',
    de: 'Der Stapel bleibt „Veröffentlichung läuft“: „Veröffentlichung fortsetzen“ versucht die abgelehnte Seite erneut. Um einen Entwurf zu korrigieren, braucht es eine neue Prüfrunde (die Netzwerkverwaltung öffnet die Prüfung wieder).',
    nl: 'Het lot blijft op „Publicatie bezig”: „Publicatie hervatten” probeert de geweigerde pagina opnieuw. Om een concept te verbeteren is een nieuwe beoordelingsronde nodig (het netwerkbeheer heropent de beoordeling).',
    eo: 'La loto restas „Publikigo daŭras“: „Daŭrigi la publikigon“ reprovas la rifuzitan paĝon. Por korekti malneton necesas nova revizia rondo (la reta administrado remalfermas la revizion).',
    el: 'Η παρτίδα παραμένει «Δημοσίευση σε εξέλιξη»: η «Συνέχιση της δημοσίευσης» ξαναδοκιμάζει τη σελίδα που απορρίφθηκε. Για να διορθώσεις ένα πρόχειρο, χρειάζεται νέος γύρος αναθεώρησης (η διαχείριση του δικτύου ανοίγει ξανά την αναθεώρηση).',
  },
  'error.batch.publishing_locked': {
    fr: 'Ce lot est en cours de publication : rien ne s’y ajoute ni ne s’y retouche sans un nouveau tour de révision.',
    'pt-BR': 'Este lote está em publicação: nada é acrescentado nem retocado sem uma nova rodada de revisão.',
    en: 'This batch is being published: nothing can be added to it or edited without a new review round.',
    es: 'Este lote se está publicando: no se le añade ni se retoca nada sin una nueva vuelta de revisión.',
    ca: 'Aquest lot s’està publicant: no s’hi afegeix ni s’hi retoca res sense una nova volta de revisió.',
    it: 'Questo lotto è in pubblicazione: non vi si aggiunge né vi si ritocca nulla senza un nuovo giro di revisione.',
    de: 'Dieser Stapel wird gerade veröffentlicht: Ohne neue Prüfrunde lässt sich nichts hinzufügen oder ändern.',
    nl: 'Dit lot wordt gepubliceerd: er wordt niets aan toegevoegd of aan veranderd zonder een nieuwe beoordelingsronde.',
    eo: 'Ĉi tiu loto estas publikigata: nenio aldoniĝas nek retuŝiĝas sen nova revizia rondo.',
    el: 'Αυτή η παρτίδα δημοσιεύεται: τίποτα δεν προστίθεται ούτε διορθώνεται χωρίς νέο γύρο αναθεώρησης.',
  },
  'error.batch.publication_busy': {
    fr: 'Ce lot est déjà en train d’être publié par un autre appel (autre onglet ou autre personne) : attends la fin, puis recharge la page.',
    'pt-BR': 'Este lote já está sendo publicado por outra chamada (outra aba ou outra pessoa): espere terminar e depois recarregue a página.',
    en: 'This batch is already being published by another call (another tab or another person): wait for it to finish, then reload the page.',
    es: 'Este lote ya se está publicando desde otra llamada (otra pestaña u otra persona): espera a que termine y luego recarga la página.',
    ca: 'Aquest lot ja s’està publicant des d’una altra crida (una altra pestanya o una altra persona): espera que acabi i després torna a carregar la pàgina.',
    it: 'Questo lotto è già in pubblicazione da un’altra chiamata (un’altra scheda o un’altra persona): aspetta che finisca, poi ricarica la pagina.',
    de: 'Dieser Stapel wird bereits durch einen anderen Aufruf veröffentlicht (anderer Tab oder andere Person): Warte, bis er fertig ist, und lade dann die Seite neu.',
    nl: 'Dit lot wordt al gepubliceerd door een andere aanroep (ander tabblad of iemand anders): wacht tot die klaar is en laad dan de pagina opnieuw.',
    eo: 'Ĉi tiu loto jam estas publikigata de alia alvoko (alia langeto aŭ alia persono): atendu la finon, poste reŝargu la paĝon.',
    el: 'Αυτή η παρτίδα δημοσιεύεται ήδη από άλλη κλήση (άλλη καρτέλα ή άλλο άτομο): περίμενε να τελειώσει και μετά φόρτωσε ξανά τη σελίδα.',
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
