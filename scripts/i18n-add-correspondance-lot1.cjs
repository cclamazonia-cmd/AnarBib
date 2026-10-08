/* ===========================================================================
 * i18n-add-correspondance-lot1.cjs — G19 lot 1 (REGISTRE CORR-1 à CORR-6, 08/10/2026)
 * Dix HINT levés par la migration correspondance_entre_bibliotheques_lot_1
 * (convention (a) de localizeError : RAISE … USING HINT = 'error.…'), dans les
 * dix locales. Tutoiement partout ; pt-BR au « você ».
 * Idempotent : ce script est la SOURCE des clés du lot — une clé déjà posée
 * n'est réécrite que si sa valeur a changé ici.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const CLES = {
  'error.correspondance.not_coordinator': {
    fr: 'Seule une coordination de la bibliothèque peut écrire en son nom.',
    'pt-BR': 'Só uma coordenação da biblioteca pode escrever em nome dela.',
    en: 'Only a coordinator of the library can write on its behalf.',
    es: 'Solo una coordinación de la biblioteca puede escribir en su nombre.',
    ca: 'Només una coordinació de la biblioteca pot escriure en nom seu.',
    it: 'Solo una coordinazione della biblioteca può scrivere a suo nome.',
    de: 'Nur eine Koordination der Bibliothek kann in ihrem Namen schreiben.',
    nl: 'Alleen een coördinatie van de bibliotheek kan in haar naam schrijven.',
    eo: 'Nur kunordiganto de la biblioteko povas skribi en ĝia nomo.',
    el: 'Μόνο ένας συντονισμός της βιβλιοθήκης μπορεί να γράψει εξ ονόματός της.',
  },
  'error.correspondance.not_participant': {
    fr: 'Ce fil n’existe pas, ou ta bibliothèque n’en fait pas partie.',
    'pt-BR': 'Este fio não existe, ou a sua biblioteca não faz parte dele.',
    en: 'This thread does not exist, or your library is not part of it.',
    es: 'Este hilo no existe, o tu biblioteca no forma parte de él.',
    ca: 'Aquest fil no existeix, o la teva biblioteca no en forma part.',
    it: 'Questa conversazione non esiste, o la tua biblioteca non ne fa parte.',
    de: 'Dieser Faden existiert nicht, oder deine Bibliothek gehört nicht dazu.',
    nl: 'Deze draad bestaat niet, of je bibliotheek maakt er geen deel van uit.',
    eo: 'Ĉi tiu fadeno ne ekzistas, aŭ via biblioteko ne partoprenas ĝin.',
    el: 'Αυτό το νήμα δεν υπάρχει, ή η βιβλιοθήκη σου δεν συμμετέχει σε αυτό.',
  },
  'error.correspondance.library_not_found': {
    fr: 'Cette bibliothèque est introuvable ou n’est plus active.',
    'pt-BR': 'Esta biblioteca não foi encontrada ou não está mais ativa.',
    en: 'This library cannot be found or is no longer active.',
    es: 'Esta biblioteca no se encuentra o ya no está activa.',
    ca: 'Aquesta biblioteca no es troba o ja no és activa.',
    it: 'Questa biblioteca non si trova o non è più attiva.',
    de: 'Diese Bibliothek ist nicht zu finden oder nicht mehr aktiv.',
    nl: 'Deze bibliotheek is niet te vinden of niet meer actief.',
    eo: 'Ĉi tiu biblioteko ne troviĝas aŭ ne plu estas aktiva.',
    el: 'Αυτή η βιβλιοθήκη δεν βρέθηκε ή δεν είναι πλέον ενεργή.',
  },
  'error.correspondance.same_library': {
    fr: 'Choisis une autre bibliothèque : on n’écrit pas à la sienne.',
    'pt-BR': 'Escolha outra biblioteca: não se escreve para a própria.',
    en: 'Choose another library: you cannot write to your own.',
    es: 'Elige otra biblioteca: no se escribe a la propia.',
    ca: 'Tria una altra biblioteca: no s’escriu a la pròpia.',
    it: 'Scegli un’altra biblioteca: non si scrive alla propria.',
    de: 'Wähle eine andere Bibliothek: an die eigene schreibt man nicht.',
    nl: 'Kies een andere bibliotheek: aan je eigen schrijf je niet.',
    eo: 'Elektu alian bibliotekon: oni ne skribas al la propra.',
    el: 'Διάλεξε άλλη βιβλιοθήκη: δεν γράφουμε στη δική μας.',
  },
  'error.correspondance.subject_required': {
    fr: 'Donne un sujet au fil (200 caractères au plus).',
    'pt-BR': 'Dê um assunto ao fio (até 200 caracteres).',
    en: 'Give the thread a subject (200 characters at most).',
    es: 'Pon un asunto al hilo (200 caracteres como máximo).',
    ca: 'Posa un assumpte al fil (200 caràcters com a màxim).',
    it: 'Dai un oggetto alla conversazione (al massimo 200 caratteri).',
    de: 'Gib dem Faden einen Betreff (höchstens 200 Zeichen).',
    nl: 'Geef de draad een onderwerp (hoogstens 200 tekens).',
    eo: 'Donu temon al la fadeno (maksimume 200 signoj).',
    el: 'Δώσε ένα θέμα στο νήμα (έως 200 χαρακτήρες).',
  },
  'error.correspondance.empty_body': {
    fr: 'Le message est vide.',
    'pt-BR': 'A mensagem está vazia.',
    en: 'The message is empty.',
    es: 'El mensaje está vacío.',
    ca: 'El missatge és buit.',
    it: 'Il messaggio è vuoto.',
    de: 'Die Nachricht ist leer.',
    nl: 'Het bericht is leeg.',
    eo: 'La mesaĝo estas malplena.',
    el: 'Το μήνυμα είναι κενό.',
  },
  'error.correspondance.body_too_long': {
    fr: 'Le message dépasse 4 000 caractères : raccourcis-le, ou envoie-le en deux fois.',
    'pt-BR': 'A mensagem passa de 4.000 caracteres: encurte-a ou envie em duas partes.',
    en: 'The message exceeds 4,000 characters: shorten it, or send it in two parts.',
    es: 'El mensaje supera los 4 000 caracteres: acórtalo o envíalo en dos partes.',
    ca: 'El missatge supera els 4.000 caràcters: escurça’l o envia’l en dues parts.',
    it: 'Il messaggio supera i 4 000 caratteri: accorcialo, o invialo in due parti.',
    de: 'Die Nachricht ist länger als 4 000 Zeichen: kürze sie oder schicke sie in zwei Teilen.',
    nl: 'Het bericht is langer dan 4 000 tekens: kort het in of stuur het in twee delen.',
    eo: 'La mesaĝo superas 4 000 signojn: mallongigu ĝin, aŭ sendu ĝin en du partoj.',
    el: 'Το μήνυμα ξεπερνά τους 4.000 χαρακτήρες: συντόμευσέ το ή στείλε το σε δύο μέρη.',
  },
  'error.correspondance.lang_invalid': {
    fr: 'La langue du message doit être l’une des dix langues d’AnarBib.',
    'pt-BR': 'A língua da mensagem deve ser uma das dez línguas do AnarBib.',
    en: 'The message language must be one of AnarBib’s ten languages.',
    es: 'La lengua del mensaje debe ser una de las diez lenguas de AnarBib.',
    ca: 'La llengua del missatge ha de ser una de les deu llengües d’AnarBib.',
    it: 'La lingua del messaggio deve essere una delle dieci lingue di AnarBib.',
    de: 'Die Sprache der Nachricht muss eine der zehn Sprachen von AnarBib sein.',
    nl: 'De taal van het bericht moet een van de tien talen van AnarBib zijn.',
    eo: 'La lingvo de la mesaĝo devas esti unu el la dek lingvoj de AnarBib.',
    el: 'Η γλώσσα του μηνύματος πρέπει να είναι μία από τις δέκα γλώσσες του AnarBib.',
  },
  'error.correspondance.rate_limited': {
    fr: 'Trente messages en vingt-quatre heures, c’est déjà beaucoup : reprends demain.',
    'pt-BR': 'Trinta mensagens em vinte e quatro horas já é bastante: continue amanhã.',
    en: 'Thirty messages in twenty-four hours is already a lot: carry on tomorrow.',
    es: 'Treinta mensajes en veinticuatro horas ya es mucho: sigue mañana.',
    ca: 'Trenta missatges en vint-i-quatre hores ja és molt: continua demà.',
    it: 'Trenta messaggi in ventiquattro ore sono già molti: riprendi domani.',
    de: 'Dreißig Nachrichten in vierundzwanzig Stunden sind schon viel: mach morgen weiter.',
    nl: 'Dertig berichten in vierentwintig uur is al veel: ga morgen verder.',
    eo: 'Tridek mesaĝoj en dudek kvar horoj jam estas multe: daŭrigu morgaŭ.',
    el: 'Τριάντα μηνύματα σε είκοσι τέσσερις ώρες είναι ήδη πολλά: συνέχισε αύριο.',
  },
  'error.correspondance.not_found': {
    fr: 'Ce fil est introuvable.',
    'pt-BR': 'Este fio não foi encontrado.',
    en: 'This thread cannot be found.',
    es: 'Este hilo no se encuentra.',
    ca: 'Aquest fil no es troba.',
    it: 'Questa conversazione non si trova.',
    de: 'Dieser Faden ist nicht zu finden.',
    nl: 'Deze draad is niet te vinden.',
    eo: 'Ĉi tiu fadeno ne troviĝas.',
    el: 'Αυτό το νήμα δεν βρέθηκε.',
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
