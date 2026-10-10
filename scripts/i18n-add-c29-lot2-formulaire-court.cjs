/* ===========================================================================
 * i18n-add-c29-lot2-formulaire-court.cjs — C29 lot 2 (10/10/2026) : créer un
 * exemplaire sans quitter la fiche (ExemplaresPanel, formulaire court en
 * quatre temps : où, rangement, circulation, détails).
 * Titre du formulaire, les quatre temps, la bibliothèque unique choisie
 * d'avance, l'absence de bibliothèque où ranger, les deux aides du numéro
 * d'inventaire (proposé par la série / à saisir), la circulation héritée,
 * l'étiquette déduite, les deux boutons, les trois issues (publié, gardé en
 * brouillon, publication refusée), le renvoi vers l'éditeur complet.
 * Vocabulaire repris des clés voisines (catalogacao.exemplar.*,
 * catalogacao.copies.*). Tutoiement partout ; pt-BR au « você ».
 * Idempotent : une clé déjà posée n'est réécrite que si sa valeur a changé ici.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const CLES = {
  'catalogacao.copies.form.title': {
    fr: 'Nouvel exemplaire de cette fiche', 'pt-BR': 'Novo exemplar desta ficha', en: 'New copy of this record',
    es: 'Nuevo ejemplar de esta ficha', ca: 'Nou exemplar d’aquesta fitxa', it: 'Nuovo esemplare di questa scheda',
    de: 'Neues Exemplar zu diesem Datensatz', nl: 'Nieuw exemplaar van deze fiche', eo: 'Nova ekzemplero de ĉi tiu skedo',
    el: 'Νέο αντίτυπο αυτής της καρτέλας',
  },
  'catalogacao.copies.form.where': {
    fr: 'Où ranger l’exemplaire ?', 'pt-BR': 'Onde guardar o exemplar?', en: 'Where does the copy go?',
    es: '¿Dónde guardar el ejemplar?', ca: 'On desar l’exemplar?', it: 'Dove va l’esemplare?',
    de: 'Wohin kommt das Exemplar?', nl: 'Waar hoort het exemplaar?', eo: 'Kien meti la ekzempleron?',
    el: 'Πού τοποθετείται το αντίτυπο;',
  },
  'catalogacao.copies.form.whereOne': {
    fr: 'Rangé à {library}, la seule bibliothèque où tu es de l’équipe.',
    'pt-BR': 'Guardado em {library}, a única biblioteca em que você é da equipe.',
    en: 'Kept at {library}, the only library where you are on the team.',
    es: 'Guardado en {library}, la única biblioteca en la que formas parte del equipo.',
    ca: 'Desat a {library}, l’única biblioteca on ets de l’equip.',
    it: 'Collocato a {library}, l’unica biblioteca in cui fai parte dell’équipe.',
    de: 'Aufgestellt in {library}, der einzigen Bibliothek, in der du zum Team gehörst.',
    nl: 'Geplaatst bij {library}, de enige bibliotheek waar je in het team zit.',
    eo: 'Metita en {library}, la sola biblioteko kie vi estas en la teamo.',
    el: 'Τοποθετείται στη {library}, τη μόνη βιβλιοθήκη όπου είσαι στην ομάδα.',
  },
  'catalogacao.copies.form.noLibrary': {
    fr: 'Tu n’es de l’équipe d’aucune bibliothèque : un exemplaire ne peut pas être rangé depuis ce compte.',
    'pt-BR': 'Você não é da equipe de nenhuma biblioteca: um exemplar não pode ser guardado a partir desta conta.',
    en: 'You are not on any library team: a copy cannot be filed from this account.',
    es: 'No formas parte del equipo de ninguna biblioteca: no se puede guardar un ejemplar desde esta cuenta.',
    ca: 'No ets de l’equip de cap biblioteca: no es pot desar cap exemplar des d’aquest compte.',
    it: 'Non fai parte dell’équipe di nessuna biblioteca: nessun esemplare può essere collocato da questo account.',
    de: 'Du gehörst zu keinem Bibliotheksteam: von diesem Konto aus kann kein Exemplar aufgestellt werden.',
    nl: 'Je zit in geen enkel bibliotheekteam: vanuit dit account kan geen exemplaar worden geplaatst.',
    eo: 'Vi estas en la teamo de neniu biblioteko: ekzemplero ne povas esti metita el ĉi tiu konto.',
    el: 'Δεν είσαι στην ομάδα καμίας βιβλιοθήκης: δεν μπορεί να τοποθετηθεί αντίτυπο από αυτόν τον λογαριασμό.',
  },
  'catalogacao.copies.form.shelf': {
    fr: 'Rangement', 'pt-BR': 'Localização', en: 'Shelving', es: 'Ubicación', ca: 'Ubicació', it: 'Collocazione',
    de: 'Aufstellung', nl: 'Plaatsing', eo: 'Lokigo', el: 'Ταξιθέτηση',
  },
  'catalogacao.copies.form.tomboHint': {
    fr: 'Proposé par la série de la bibliothèque. Change-le seulement si l’exemplaire porte déjà un numéro.',
    'pt-BR': 'Proposto pela série da biblioteca. Mude só se o exemplar já tiver um número.',
    en: 'Proposed from the library’s series. Change it only if the copy already bears a number.',
    es: 'Propuesto por la serie de la biblioteca. Cámbialo solo si el ejemplar ya lleva un número.',
    ca: 'Proposat per la sèrie de la biblioteca. Canvia’l només si l’exemplar ja porta un número.',
    it: 'Proposto dalla serie della biblioteca. Cambialo solo se l’esemplare porta già un numero.',
    de: 'Aus der Reihe der Bibliothek vorgeschlagen. Ändere sie nur, wenn das Exemplar schon eine Nummer trägt.',
    nl: 'Voorgesteld uit de reeks van de bibliotheek. Wijzig het alleen als het exemplaar al een nummer draagt.',
    eo: 'Proponita el la serio de la biblioteko. Ŝanĝu ĝin nur se la ekzemplero jam portas numeron.',
    el: 'Προτείνεται από τη σειρά της βιβλιοθήκης. Άλλαξέ τον μόνο αν το αντίτυπο φέρει ήδη αριθμό.',
  },
  'catalogacao.copies.form.tomboManual': {
    fr: 'Cette bibliothèque n’a pas de série de numéros : indique le numéro d’inventaire.',
    'pt-BR': 'Esta biblioteca não tem série de números: indique o tombo.',
    en: 'This library has no number series: enter the accession number.',
    es: 'Esta biblioteca no tiene serie de números: indica el número de registro.',
    ca: 'Aquesta biblioteca no té sèrie de números: indica el número de registre.',
    it: 'Questa biblioteca non ha una serie di numeri: indica il numero di inventario.',
    de: 'Diese Bibliothek hat keine Nummernreihe: gib die Inventarnummer an.',
    nl: 'Deze bibliotheek heeft geen nummerreeks: vul het inventarisnummer in.',
    eo: 'Ĉi tiu biblioteko ne havas serion de numeroj: indiku la inventarnumeron.',
    el: 'Αυτή η βιβλιοθήκη δεν έχει σειρά αριθμών: δώσε τον αριθμό εισαγωγής.',
  },
  'catalogacao.copies.form.circulation': {
    fr: 'Circulation et visibilité', 'pt-BR': 'Circulação e visibilidade', en: 'Circulation and visibility',
    es: 'Circulación y visibilidad', ca: 'Circulació i visibilitat', it: 'Circolazione e visibilità',
    de: 'Ausleihe und Sichtbarkeit', nl: 'Uitleen en zichtbaarheid', eo: 'Cirkulado kaj videbleco', el: 'Κυκλοφορία και ορατότητα',
  },
  'catalogacao.copies.form.circulationInherited': {
    fr: 'Héritées de la fiche. Change seulement si cet exemplaire déroge.',
    'pt-BR': 'Herdadas da ficha. Mude só se este exemplar for exceção.',
    en: 'Inherited from the record. Change only if this copy is an exception.',
    es: 'Heredadas de la ficha. Cambia solo si este ejemplar es una excepción.',
    ca: 'Heretades de la fitxa. Canvia-ho només si aquest exemplar és una excepció.',
    it: 'Ereditate dalla scheda. Cambia solo se questo esemplare fa eccezione.',
    de: 'Vom Datensatz übernommen. Ändere es nur, wenn dieses Exemplar eine Ausnahme ist.',
    nl: 'Overgenomen van de fiche. Wijzig alleen als dit exemplaar een uitzondering is.',
    eo: 'Hereditaj de la skedo. Ŝanĝu nur se ĉi tiu ekzemplero estas escepto.',
    el: 'Κληρονομούνται από την καρτέλα. Άλλαξέ τα μόνο αν αυτό το αντίτυπο αποτελεί εξαίρεση.',
  },
  'catalogacao.copies.form.details': {
    fr: 'Détails : acquisition, provenance, notes, étiquette',
    'pt-BR': 'Detalhes: aquisição, procedência, notas, etiqueta',
    en: 'Details: acquisition, provenance, notes, label',
    es: 'Detalles: adquisición, procedencia, notas, etiqueta',
    ca: 'Detalls: adquisició, procedència, notes, etiqueta',
    it: 'Dettagli: acquisizione, provenienza, note, etichetta',
    de: 'Details: Erwerb, Herkunft, Notizen, Etikett',
    nl: 'Details: verwerving, herkomst, notities, etiket',
    eo: 'Detaloj: akiro, deveno, notoj, etikedo',
    el: 'Λεπτομέρειες: απόκτηση, προέλευση, σημειώσεις, ετικέτα',
  },
  'catalogacao.copies.form.labelDeduced': {
    fr: 'Étiquette prête : {author} — {title}. Remplis les champs ci-dessous seulement si elle doit différer de la fiche.',
    'pt-BR': 'Etiqueta pronta: {author} — {title}. Preencha os campos abaixo só se ela precisar diferir da ficha.',
    en: 'Label ready: {author} — {title}. Fill the fields below only if it must differ from the record.',
    es: 'Etiqueta lista: {author} — {title}. Rellena los campos de abajo solo si debe diferir de la ficha.',
    ca: 'Etiqueta a punt: {author} — {title}. Omple els camps de sota només si ha de diferir de la fitxa.',
    it: 'Etichetta pronta: {author} — {title}. Compila i campi qui sotto solo se deve differire dalla scheda.',
    de: 'Etikett bereit: {author} — {title}. Fülle die Felder unten nur aus, wenn es vom Datensatz abweichen soll.',
    nl: 'Etiket klaar: {author} — {title}. Vul de velden hieronder alleen in als het van de fiche moet afwijken.',
    eo: 'Etikedo preta: {author} — {title}. Plenigu la subajn kampojn nur se ĝi devas diferenci de la skedo.',
    el: 'Ετικέτα έτοιμη: {author} — {title}. Συμπλήρωσε τα παρακάτω πεδία μόνο αν πρέπει να διαφέρει από την καρτέλα.',
  },
  'catalogacao.copies.form.submitPublish': {
    fr: 'Enregistrer et publier', 'pt-BR': 'Salvar e publicar', en: 'Save and publish', es: 'Guardar y publicar',
    ca: 'Desar i publicar', it: 'Salvare e pubblicare', de: 'Speichern und veröffentlichen', nl: 'Opslaan en publiceren',
    eo: 'Konservi kaj publikigi', el: 'Αποθήκευση και δημοσίευση',
  },
  'catalogacao.copies.form.submitDraft': {
    fr: 'Garder en brouillon', 'pt-BR': 'Manter como rascunho', en: 'Keep as draft', es: 'Guardar como borrador',
    ca: 'Desar com a esborrany', it: 'Tenere come bozza', de: 'Als Entwurf behalten', nl: 'Als concept bewaren',
    eo: 'Konservi kiel malneton', el: 'Διατήρηση ως προσχέδιο',
  },
  'catalogacao.copies.form.created': {
    fr: 'Exemplaire {tombo} publié, rangé à {library}.',
    'pt-BR': 'Exemplar {tombo} publicado, guardado em {library}.',
    en: 'Copy {tombo} published, kept at {library}.',
    es: 'Ejemplar {tombo} publicado, guardado en {library}.',
    ca: 'Exemplar {tombo} publicat, desat a {library}.',
    it: 'Esemplare {tombo} pubblicato, collocato a {library}.',
    de: 'Exemplar {tombo} veröffentlicht, aufgestellt in {library}.',
    nl: 'Exemplaar {tombo} gepubliceerd, geplaatst bij {library}.',
    eo: 'Ekzemplero {tombo} publikigita, metita en {library}.',
    el: 'Το αντίτυπο {tombo} δημοσιεύτηκε και τοποθετήθηκε στη {library}.',
  },
  'catalogacao.copies.form.draftKept': {
    fr: 'Brouillon d’exemplaire gardé : il attend dans la liste, « Modifier » l’ouvre dans l’éditeur complet.',
    'pt-BR': 'Rascunho de exemplar mantido: ele espera na lista, « Editar » o abre no editor completo.',
    en: 'Copy draft kept: it waits in the list, “Edit” opens it in the full editor.',
    es: 'Borrador de ejemplar guardado: espera en la lista, « Editar » lo abre en el editor completo.',
    ca: 'Esborrany d’exemplar desat: espera a la llista, « Modificar » l’obre a l’editor complet.',
    it: 'Bozza di esemplare tenuta: aspetta nell’elenco, « Modifica » la apre nell’editor completo.',
    de: 'Exemplar-Entwurf behalten: er wartet in der Liste, „Bearbeiten“ öffnet ihn im vollständigen Editor.',
    nl: 'Exemplaarconcept bewaard: het wacht in de lijst, „Bewerken“ opent het in de volledige editor.',
    eo: 'Malneto de ekzemplero konservita: ĝi atendas en la listo, « Redakti » malfermas ĝin en la plena redaktilo.',
    el: 'Το προσχέδιο αντιτύπου διατηρήθηκε: περιμένει στη λίστα, η «Επεξεργασία» το ανοίγει στον πλήρη επεξεργαστή.',
  },
  'catalogacao.copies.form.publishFailed': {
    fr: 'Le brouillon est enregistré mais la publication a été refusée : {message}. « Modifier » l’ouvre dans l’éditeur complet.',
    'pt-BR': 'O rascunho foi salvo mas a publicação foi recusada: {message}. « Editar » o abre no editor completo.',
    en: 'The draft is saved but publication was refused: {message}. “Edit” opens it in the full editor.',
    es: 'El borrador está guardado pero la publicación fue rechazada: {message}. « Editar » lo abre en el editor completo.',
    ca: 'L’esborrany s’ha desat però la publicació s’ha refusat: {message}. « Modificar » l’obre a l’editor complet.',
    it: 'La bozza è salvata ma la pubblicazione è stata rifiutata: {message}. « Modifica » la apre nell’editor completo.',
    de: 'Der Entwurf ist gespeichert, aber die Veröffentlichung wurde abgelehnt: {message}. „Bearbeiten“ öffnet ihn im vollständigen Editor.',
    nl: 'Het concept is opgeslagen maar de publicatie is geweigerd: {message}. „Bewerken“ opent het in de volledige editor.',
    eo: 'La malneto estas konservita sed la publikigo estis rifuzita: {message}. « Redakti » malfermas ĝin en la plena redaktilo.',
    el: 'Το προσχέδιο αποθηκεύτηκε αλλά η δημοσίευση απορρίφθηκε: {message}. Η «Επεξεργασία» το ανοίγει στον πλήρη επεξεργαστή.',
  },
  'catalogacao.copies.form.fullEditor': {
    fr: 'Éditeur complet', 'pt-BR': 'Editor completo', en: 'Full editor', es: 'Formulario completo', ca: 'Editor complet',
    it: 'Modulo completo', de: 'Vollständiger Editor', nl: 'Volledige editor', eo: 'Plena redaktilo', el: 'Πλήρης επεξεργαστής',
  },
  'catalogacao.copies.form.fullEditorHint': {
    fr: 'Ouvre l’onglet Indexation, pré-ciblé sur cette fiche : lots, étiquette, réattribution.',
    'pt-BR': 'Abre a aba Indexação, já apontada para esta ficha: lotes, etiqueta, reatribuição.',
    en: 'Opens the Indexing tab, already targeting this record: batches, label, reassignment.',
    es: 'Abre la pestaña Indexación, ya apuntando a esta ficha: lotes, etiqueta, reasignación.',
    ca: 'Obre la pestanya Indexació, ja apuntant a aquesta fitxa: lots, etiqueta, reassignació.',
    it: 'Apre la scheda Indicizzazione, già puntata su questa scheda: lotti, etichetta, riassegnazione.',
    de: 'Öffnet den Reiter Indexierung, bereits auf diesen Datensatz gerichtet: Stapel, Etikett, Neuzuordnung.',
    nl: 'Opent het tabblad Indexering, al gericht op deze fiche: partijen, etiket, hertoewijzing.',
    eo: 'Malfermas la langeton Indeksado, jam celantan ĉi tiun skedon: aroj, etikedo, reatribuo.',
    el: 'Ανοίγει την καρτέλα Ευρετηρίαση, ήδη στοχευμένη σε αυτή την καρτέλα: παρτίδες, ετικέτα, ανακατανομή.',
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
