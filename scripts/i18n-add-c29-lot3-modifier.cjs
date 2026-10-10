/* ===========================================================================
 * i18n-add-c29-lot3-modifier.cjs — C29 lot 3 (10/10/2026) : modifier un
 * exemplaire publié sans voir le brouillon (ExemplaresPanel, migration
 * 20261010204944, fn_exemplaire_modifier_et_publier).
 * Titre et bibliothèque du formulaire de modification, le numéro qui ne
 * change pas ici, le renvoi vers l'éditeur complet pour réattribuer, le
 * bouton, la confirmation ; et les quatre HINT de la fonction
 * (error.copies.*), que localizeError traduit.
 * Vocabulaire repris des clés voisines (catalogacao.copies.*,
 * catalogacao.exemplar.*). Tutoiement partout ; pt-BR au « você ».
 * Idempotent : une clé déjà posée n'est réécrite que si sa valeur a changé ici.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const CLES = {
  'catalogacao.copies.edit.title': {
    fr: 'Modifier l’exemplaire {tombo}', 'pt-BR': 'Editar o exemplar {tombo}', en: 'Edit copy {tombo}',
    es: 'Modificar el ejemplar {tombo}', ca: 'Modificar l’exemplar {tombo}', it: 'Modificare l’esemplare {tombo}',
    de: 'Exemplar {tombo} bearbeiten', nl: 'Exemplaar {tombo} bewerken', eo: 'Redakti la ekzempleron {tombo}',
    el: 'Επεξεργασία του αντιτύπου {tombo}',
  },
  'catalogacao.copies.edit.library': {
    fr: 'Rangé à {library}.', 'pt-BR': 'Guardado em {library}.', en: 'Kept at {library}.', es: 'Guardado en {library}.',
    ca: 'Desat a {library}.', it: 'Collocato a {library}.', de: 'Aufgestellt in {library}.', nl: 'Geplaatst bij {library}.',
    eo: 'Metita en {library}.', el: 'Τοποθετημένο στη {library}.',
  },
  'catalogacao.copies.edit.tomboFixed': {
    fr: 'Le numéro d’inventaire ne change pas ici : un numéro donné ne se redonne jamais.',
    'pt-BR': 'O tombo não muda aqui: um número dado nunca se dá de novo.',
    en: 'The accession number does not change here: a number once given is never given again.',
    es: 'El número de registro no cambia aquí: un número dado nunca se vuelve a dar.',
    ca: 'El número de registre no canvia aquí: un número donat no es torna a donar mai.',
    it: 'Il numero di inventario non cambia qui: un numero dato non si ridà mai.',
    de: 'Die Inventarnummer ändert sich hier nicht: eine vergebene Nummer wird nie neu vergeben.',
    nl: 'Het inventarisnummer verandert hier niet: een uitgegeven nummer wordt nooit opnieuw uitgegeven.',
    eo: 'La inventarnumero ne ŝanĝiĝas ĉi tie: donita numero neniam estas redonita.',
    el: 'Ο αριθμός εισαγωγής δεν αλλάζει εδώ: ένας αριθμός που δόθηκε δεν ξαναδίνεται ποτέ.',
  },
  'catalogacao.copies.edit.reassign': {
    fr: 'Changer de bibliothèque ou de lot : éditeur complet', 'pt-BR': 'Mudar de biblioteca ou de lote: editor completo',
    en: 'Change library or batch: full editor', es: 'Cambiar de biblioteca o de lote: editor completo',
    ca: 'Canviar de biblioteca o de lot: editor complet', it: 'Cambiare biblioteca o lotto: editor completo',
    de: 'Bibliothek oder Stapel wechseln: vollständiger Editor', nl: 'Bibliotheek of partij wijzigen: volledige editor',
    eo: 'Ŝanĝi bibliotekon aŭ aron: plena redaktilo', el: 'Αλλαγή βιβλιοθήκης ή παρτίδας: πλήρης επεξεργαστής',
  },
  'catalogacao.copies.edit.submit': {
    fr: 'Enregistrer les changements', 'pt-BR': 'Salvar as alterações', en: 'Save the changes', es: 'Guardar los cambios',
    ca: 'Desar els canvis', it: 'Salvare le modifiche', de: 'Änderungen speichern', nl: 'Wijzigingen opslaan',
    eo: 'Konservi la ŝanĝojn', el: 'Αποθήκευση των αλλαγών',
  },
  'catalogacao.copies.edit.updated': {
    fr: 'Exemplaire {tombo} mis à jour et republié.', 'pt-BR': 'Exemplar {tombo} atualizado e republicado.',
    en: 'Copy {tombo} updated and republished.', es: 'Ejemplar {tombo} actualizado y vuelto a publicar.',
    ca: 'Exemplar {tombo} actualitzat i tornat a publicar.', it: 'Esemplare {tombo} aggiornato e ripubblicato.',
    de: 'Exemplar {tombo} aktualisiert und neu veröffentlicht.', nl: 'Exemplaar {tombo} bijgewerkt en opnieuw gepubliceerd.',
    eo: 'Ekzemplero {tombo} ĝisdatigita kaj republikigita.', el: 'Το αντίτυπο {tombo} ενημερώθηκε και δημοσιεύτηκε ξανά.',
  },
  'error.copies.not_found': {
    fr: 'Cet exemplaire n’existe plus.', 'pt-BR': 'Este exemplar não existe mais.', en: 'This copy no longer exists.',
    es: 'Este ejemplar ya no existe.', ca: 'Aquest exemplar ja no existeix.', it: 'Questo esemplare non esiste più.',
    de: 'Dieses Exemplar existiert nicht mehr.', nl: 'Dit exemplaar bestaat niet meer.', eo: 'Ĉi tiu ekzemplero ne plu ekzistas.',
    el: 'Αυτό το αντίτυπο δεν υπάρχει πια.',
  },
  'error.copies.changes_invalid': {
    fr: 'Les changements envoyés ne sont pas lisibles.', 'pt-BR': 'As alterações enviadas não são legíveis.',
    en: 'The submitted changes cannot be read.', es: 'Los cambios enviados no se pueden leer.', ca: 'Els canvis enviats no es poden llegir.',
    it: 'Le modifiche inviate non sono leggibili.', de: 'Die gesendeten Änderungen sind nicht lesbar.',
    nl: 'De verzonden wijzigingen zijn niet leesbaar.', eo: 'La senditaj ŝanĝoj ne estas legeblaj.', el: 'Οι αλλαγές που στάλθηκαν δεν είναι αναγνώσιμες.',
  },
  'error.copies.field_not_allowed': {
    fr: 'Ce champ ne se change pas ici : ni le numéro d’inventaire, ni la bibliothèque. Passe par l’éditeur complet.',
    'pt-BR': 'Este campo não muda aqui: nem o tombo, nem a biblioteca. Use o editor completo.',
    en: 'This field cannot be changed here: neither the accession number nor the library. Use the full editor.',
    es: 'Este campo no se cambia aquí: ni el número de registro ni la biblioteca. Usa el editor completo.',
    ca: 'Aquest camp no es canvia aquí: ni el número de registre ni la biblioteca. Fes servir l’editor complet.',
    it: 'Questo campo non si cambia qui: né il numero di inventario né la biblioteca. Usa l’editor completo.',
    de: 'Dieses Feld lässt sich hier nicht ändern: weder die Inventarnummer noch die Bibliothek. Nutze den vollständigen Editor.',
    nl: 'Dit veld verander je hier niet: noch het inventarisnummer, noch de bibliotheek. Gebruik de volledige editor.',
    eo: 'Ĉi tiu kampo ne ŝanĝiĝas ĉi tie: nek la inventarnumero, nek la biblioteko. Uzu la plenan redaktilon.',
    el: 'Αυτό το πεδίο δεν αλλάζει εδώ: ούτε ο αριθμός εισαγωγής ούτε η βιβλιοθήκη. Χρησιμοποίησε τον πλήρη επεξεργαστή.',
  },
  'error.copies.update_pending': {
    fr: 'Cet exemplaire a déjà une mise à jour en cours : reprends-la dans l’éditeur plutôt que d’en ouvrir une seconde.',
    'pt-BR': 'Este exemplar já tem uma atualização em curso: retome-a no editor em vez de abrir uma segunda.',
    en: 'This copy already has an update in progress: resume it in the editor rather than opening a second one.',
    es: 'Este ejemplar ya tiene una actualización en curso: retómala en el editor en vez de abrir una segunda.',
    ca: 'Aquest exemplar ja té una actualització en curs: reprèn-la a l’editor en lloc d’obrir-ne una segona.',
    it: 'Questo esemplare ha già un aggiornamento in corso: riprendilo nell’editor invece di aprirne un secondo.',
    de: 'Dieses Exemplar hat schon eine laufende Aktualisierung: setze sie im Editor fort, statt eine zweite zu öffnen.',
    nl: 'Dit exemplaar heeft al een lopende bijwerking: hervat die in de editor in plaats van een tweede te openen.',
    eo: 'Ĉi tiu ekzemplero jam havas kurantan ĝisdatigon: daŭrigu ĝin en la redaktilo anstataŭ malfermi duan.',
    el: 'Αυτό το αντίτυπο έχει ήδη μια ενημέρωση σε εξέλιξη: συνέχισέ την στον επεξεργαστή αντί να ανοίξεις δεύτερη.',
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
