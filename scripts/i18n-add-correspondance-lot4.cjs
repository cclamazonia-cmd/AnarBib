/* ===========================================================================
 * i18n-add-correspondance-lot4.cjs — G19 lot 4 (08/10/2026, CORR-3 sans traduction)
 * Les langues lues par l'équipe : 5 clés × 10 locales. Idempotent, source des clés.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const CLES = {
  'biblioteca.identity.readLanguages': { fr: 'Les langues que notre équipe lit', 'pt-BR': 'As línguas que a nossa equipe lê', en: 'The languages our team reads', es: 'Las lenguas que lee nuestro equipo', ca: 'Les llengües que llegeix el nostre equip', it: 'Le lingue che il nostro gruppo legge', de: 'Die Sprachen, die unser Team liest', nl: 'De talen die ons team leest', eo: 'La lingvoj kiujn nia teamo legas', el: 'Οι γλώσσες που διαβάζει η ομάδα μας' },
  'biblioteca.identity.readLanguagesHelp': {
    fr: 'Montré aux bibliothèques qui écrivent à celle-ci, pour qu’elles choisissent une langue que l’équipe lit : il n’y a pas de traduction automatique.',
    'pt-BR': 'Mostrado às bibliotecas que escrevem para esta, para que escolham uma língua que a equipe lê: não há tradução automática.',
    en: 'Shown to the libraries that write to this one, so they can pick a language the team reads: there is no automatic translation.',
    es: 'Se muestra a las bibliotecas que escriben a esta, para que elijan una lengua que lee el equipo: no hay traducción automática.',
    ca: 'Es mostra a les biblioteques que escriuen a aquesta, perquè triïn una llengua que l’equip llegeix: no hi ha traducció automàtica.',
    it: 'Mostrato alle biblioteche che scrivono a questa, perché scelgano una lingua che il gruppo legge: non c’è traduzione automatica.',
    de: 'Wird den Bibliotheken gezeigt, die dieser schreiben, damit sie eine Sprache wählen, die das Team liest: Es gibt keine automatische Übersetzung.',
    nl: 'Getoond aan de bibliotheken die deze bibliotheek schrijven, zodat ze een taal kiezen die het team leest: er is geen automatische vertaling.',
    eo: 'Montrata al la bibliotekoj kiuj skribas al ĉi tiu, por ke ili elektu lingvon kiun la teamo legas: ne estas aŭtomata tradukado.',
    el: 'Εμφανίζεται στις βιβλιοθήκες που γράφουν σε αυτήν, ώστε να διαλέξουν μια γλώσσα που διαβάζει η ομάδα: δεν υπάρχει αυτόματη μετάφραση.',
  },
  'biblioteca.correspondance.readsLanguages': { fr: 'Cette bibliothèque lit : {langs}', 'pt-BR': 'Esta biblioteca lê: {langs}', en: 'This library reads: {langs}', es: 'Esta biblioteca lee: {langs}', ca: 'Aquesta biblioteca llegeix: {langs}', it: 'Questa biblioteca legge: {langs}', de: 'Diese Bibliothek liest: {langs}', nl: 'Deze bibliotheek leest: {langs}', eo: 'Ĉi tiu biblioteko legas: {langs}', el: 'Αυτή η βιβλιοθήκη διαβάζει: {langs}' },
  'biblioteca.correspondance.commonLanguage': { fr: 'Langue commune proposée : {lang}', 'pt-BR': 'Língua comum proposta: {lang}', en: 'Suggested common language: {lang}', es: 'Lengua común propuesta: {lang}', ca: 'Llengua comuna proposada: {lang}', it: 'Lingua comune proposta: {lang}', de: 'Vorgeschlagene gemeinsame Sprache: {lang}', nl: 'Voorgestelde gemeenschappelijke taal: {lang}', eo: 'Proponata komuna lingvo: {lang}', el: 'Προτεινόμενη κοινή γλώσσα: {lang}' },
  'biblioteca.correspondance.noCommonLanguage': {
    fr: 'Aucune langue commune déclarée : écris dans la tienne, le message sera lu tel quel — il n’y a pas de traduction automatique.',
    'pt-BR': 'Nenhuma língua comum declarada: escreva na sua, a mensagem será lida como está — não há tradução automática.',
    en: 'No common language declared: write in yours, the message will be read as is — there is no automatic translation.',
    es: 'Ninguna lengua común declarada: escribe en la tuya, el mensaje se leerá tal cual — no hay traducción automática.',
    ca: 'Cap llengua comuna declarada: pots escriure en la teva, el missatge es llegirà tal qual — no hi ha traducció automàtica.',
    it: 'Nessuna lingua comune dichiarata: scrivi nella tua, il messaggio sarà letto così com’è — non c’è traduzione automatica.',
    de: 'Keine gemeinsame Sprache angegeben: schreib in deiner, die Nachricht wird so gelesen, wie sie ist — es gibt keine automatische Übersetzung.',
    nl: 'Geen gemeenschappelijke taal opgegeven: schrijf in de jouwe, het bericht wordt gelezen zoals het is — er is geen automatische vertaling.',
    eo: 'Neniu komuna lingvo deklarita: skribu en la via, la mesaĝo estos legata tia kia ĝi estas — ne estas aŭtomata tradukado.',
    el: 'Δεν δηλώθηκε κοινή γλώσσα: γράψε στη δική σου, το μήνυμα θα διαβαστεί ως έχει — δεν υπάρχει αυτόματη μετάφραση.',
  },
};
const ligneDe = (cle) => new RegExp('^  ' + JSON.stringify(cle).replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ': (".*?")(,?)$', 'm');
for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  let ajoutees = 0, corrigees = 0;
  for (const [cle, valeurs] of Object.entries(CLES)) {
    const val = valeurs[loc];
    if (!val) throw new Error(`Valeur manquante : ${cle} / ${loc}`);
    const m = content.match(ligneDe(cle));
    if (m) {
      if (JSON.parse(m[1]) !== val) { content = content.replace(m[0], '  ' + JSON.stringify(cle) + ': ' + JSON.stringify(val) + m[2]); corrigees++; }
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
