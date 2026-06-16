/* ===========================================================================
 * i18n-add-federacao-assembleias-lang.cjs
 * Section « Langues » de l'onglet Assemblées : 4 clés federacao.assembleias.lang.*
 * (title / body / prep / note) dans les 10 locales. Régime linguistique :
 * séance plurilingue, langues-pivots pt/es/en, PV multilingue (cadrage §6quater).
 * Insertion idempotente (sentinelle federacao.assembleias.lang.title).
 * Auteur : Claude (assistant)
 * Session : Fédération — Assemblée du réseau (AG)
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'federacao.assembleias.lang.title';

const ADD = {
  'pt-BR': {
    "federacao.assembleias.lang.title": "Em que língua?",
    "federacao.assembleias.lang.body": "A assembleia é plurilíngue: cada pessoa fala na sua língua. Nenhuma língua é imposta — muito menos o inglês por padrão. Para nos entendermos, as falas são resumidas em algumas línguas-pivô (português, espanhol, inglês), com apoio mútuo na interpretação e um fio escrito em paralelo à voz.",
    "federacao.assembleias.lang.prep": "Sobretudo, a ordem do dia e a justificativa de cada ponto são traduzidas e divulgadas antes da assembleia: chega-se tendo lido, na própria língua, o que vai se decidir. E as decisões e suas justificativas ficam registradas numa ata multilíngue — é ela que vale para a sua biblioteca.",
    "federacao.assembleias.lang.note": "A secretaria é designada na abertura; estas regras de língua, a assembleia pode confirmá-las ou ajustá-las."
  },
  fr: {
    "federacao.assembleias.lang.title": "Dans quelle langue ?",
    "federacao.assembleias.lang.body": "L’assemblée est plurilingue : on intervient dans sa langue. Aucune langue n’est imposée — surtout pas l’anglais par défaut. Pour se comprendre, les échanges sont résumés vers quelques langues-pivots (portugais, espagnol, anglais), avec de l’entraide à l’interprétation et un fil écrit en parallèle de la voix.",
    "federacao.assembleias.lang.prep": "Surtout, l’ordre du jour et la motivation de chaque point sont traduits et diffusés avant l’assemblée : on arrive en ayant lu, dans sa langue, ce qui va se décider. Et les décisions et leurs motivations sont consignées dans un compte rendu multilingue — c’est lui qui fait foi pour ta bibliothèque.",
    "federacao.assembleias.lang.note": "Le secrétariat est désigné à l’ouverture ; ces règles de langue, l’assemblée peut les confirmer ou les ajuster."
  },
  es: {
    "federacao.assembleias.lang.title": "¿En qué lengua?",
    "federacao.assembleias.lang.body": "La asamblea es plurilingüe: cada quien interviene en su lengua. Ninguna lengua se impone — y mucho menos el inglés por defecto. Para entendernos, las intervenciones se resumen en algunas lenguas-pivote (portugués, español, inglés), con apoyo mutuo en la interpretación y un hilo escrito en paralelo a la voz.",
    "federacao.assembleias.lang.prep": "Sobre todo, el orden del día y la motivación de cada punto se traducen y difunden antes de la asamblea: se llega habiendo leído, en la propia lengua, lo que se va a decidir. Y las decisiones y sus motivaciones quedan registradas en un acta multilingüe — es ella la que vale para tu biblioteca.",
    "federacao.assembleias.lang.note": "La secretaría se designa en la apertura; estas reglas de lengua, la asamblea puede confirmarlas o ajustarlas."
  },
  en: {
    "federacao.assembleias.lang.title": "In which language?",
    "federacao.assembleias.lang.body": "The assembly is plurilingual: everyone speaks in their own language. No language is imposed — least of all English by default. To understand one another, contributions are summarised into a few pivot languages (Portuguese, Spanish, English), with mutual aid for interpretation and a written thread alongside the voice.",
    "federacao.assembleias.lang.prep": "Above all, the agenda and the rationale for each item are translated and circulated before the assembly: you arrive having read, in your own language, what is to be decided. And decisions and their rationale are recorded in multilingual minutes — these are what count for your library.",
    "federacao.assembleias.lang.note": "The secretariat is appointed at the opening; these language rules can be confirmed or adjusted by the assembly."
  },
  it: {
    "federacao.assembleias.lang.title": "In che lingua?",
    "federacao.assembleias.lang.body": "L’assemblea è plurilingue: ognun* interviene nella propria lingua. Nessuna lingua è imposta — tanto meno l’inglese per default. Per capirci, gli interventi sono riassunti in alcune lingue-perno (portoghese, spagnolo, inglese), con aiuto reciproco nell’interpretazione e un filo scritto in parallelo alla voce.",
    "federacao.assembleias.lang.prep": "Soprattutto, l’ordine del giorno e la motivazione di ogni punto sono tradotti e diffusi prima dell’assemblea: si arriva avendo letto, nella propria lingua, ciò che si deciderà. E le decisioni e le loro motivazioni sono messe a verbale in un resoconto multilingue — è esso a fare fede per la tua biblioteca.",
    "federacao.assembleias.lang.note": "La segreteria è designata all’apertura; queste regole linguistiche, l’assemblea può confermarle o modificarle."
  },
  de: {
    "federacao.assembleias.lang.title": "In welcher Sprache?",
    "federacao.assembleias.lang.body": "Die Versammlung ist mehrsprachig: jede*r spricht in der eigenen Sprache. Keine Sprache wird aufgezwungen — schon gar nicht Englisch als Standard. Um sich zu verstehen, werden die Beiträge in einige Pivot-Sprachen zusammengefasst (Portugiesisch, Spanisch, Englisch), mit gegenseitiger Hilfe beim Dolmetschen und einem schriftlichen Strang parallel zur Stimme.",
    "federacao.assembleias.lang.prep": "Vor allem werden die Tagesordnung und die Begründung jedes Punktes vor der Versammlung übersetzt und verteilt: du kommst an, nachdem du in deiner eigenen Sprache gelesen hast, was entschieden werden soll. Und die Entscheidungen und ihre Begründungen werden in einem mehrsprachigen Protokoll festgehalten — dieses ist für deine Bibliothek maßgeblich.",
    "federacao.assembleias.lang.note": "Das Sekretariat wird zu Beginn bestimmt; diese Sprachregeln kann die Versammlung bestätigen oder anpassen."
  },
  ca: {
    "federacao.assembleias.lang.title": "En quina llengua?",
    "federacao.assembleias.lang.body": "L’assemblea és plurilingüe: cadascú intervé en la seva llengua. Cap llengua no s’imposa — i molt menys l’anglès per defecte. Per entendre’ns, les intervencions es resumeixen en algunes llengües-pivot (portuguès, espanyol, anglès), amb ajuda mútua en la interpretació i un fil escrit en paral·lel a la veu.",
    "federacao.assembleias.lang.prep": "Sobretot, l’ordre del dia i la motivació de cada punt es tradueixen i es difonen abans de l’assemblea: s’hi arriba havent llegit, en la pròpia llengua, el que es decidirà. I les decisions i les seves motivacions queden registrades en una acta multilingüe — és ella la que fa fe per a la teva biblioteca.",
    "federacao.assembleias.lang.note": "La secretaria es designa a l’obertura; aquestes regles de llengua, l’assemblea pot confirmar-les o ajustar-les."
  },
  eo: {
    "federacao.assembleias.lang.title": "En kiu lingvo?",
    "federacao.assembleias.lang.body": "La asembleo estas plurlingva: ĉiu parolas en sia propra lingvo. Neniu lingvo estas altrudata — des malpli la angla defaŭlte. Por interkompreniĝi, la kontribuoj estas resumataj en kelkajn pivot-lingvojn (portugala, hispana, angla), kun reciproka helpo por interpretado kaj skriba fadeno paralele al la voĉo.",
    "federacao.assembleias.lang.prep": "Precipe, la tagordo kaj la motivigo de ĉiu punkto estas tradukataj kaj diskonigataj antaŭ la asembleo: oni alvenas leginte, en sia propra lingvo, kio estos decidata. Kaj la decidoj kaj iliaj motivigoj estas registrataj en plurlingva protokolo — ĝi estas tiu, kiu validas por via biblioteko.",
    "federacao.assembleias.lang.note": "La sekretario estas nomumata ĉe la malfermo; tiujn lingvajn regulojn la asembleo povas konfirmi aŭ ĝustigi."
  },
  nl: {
    "federacao.assembleias.lang.title": "In welke taal?",
    "federacao.assembleias.lang.body": "De vergadering is meertalig: iedereen spreekt in de eigen taal. Geen enkele taal wordt opgelegd — al helemaal niet het Engels als standaard. Om elkaar te begrijpen worden de bijdragen samengevat in enkele spiltalen (Portugees, Spaans, Engels), met onderlinge hulp bij het tolken en een geschreven draad naast de stem.",
    "federacao.assembleias.lang.prep": "Vooral worden de agenda en de motivering van elk punt vóór de vergadering vertaald en verspreid: je komt aan nadat je, in je eigen taal, hebt gelezen wat er beslist gaat worden. En de besluiten en hun motivering worden vastgelegd in een meertalig verslag — dat is wat telt voor jouw bibliotheek.",
    "federacao.assembleias.lang.note": "Het secretariaat wordt bij de opening aangewezen; deze taalregels kan de vergadering bevestigen of bijstellen."
  },
  el: {
    "federacao.assembleias.lang.title": "Σε ποια γλώσσα;",
    "federacao.assembleias.lang.body": "Η συνέλευση είναι πολύγλωσση: κάθε άτομο μιλά στη γλώσσα του. Καμία γλώσσα δεν επιβάλλεται — πολύ περισσότερο τα αγγλικά ως προεπιλογή. Για να συνεννοούμαστε, οι παρεμβάσεις συνοψίζονται σε λίγες γλώσσες-πυλώνες (πορτογαλικά, ισπανικά, αγγλικά), με αλληλοβοήθεια στη διερμηνεία και ένα γραπτό νήμα παράλληλα με τη φωνή.",
    "federacao.assembleias.lang.prep": "Πάνω απ’ όλα, η ημερήσια διάταξη και η αιτιολόγηση κάθε θέματος μεταφράζονται και διανέμονται πριν από τη συνέλευση: φτάνει κανείς έχοντας διαβάσει, στη δική του γλώσσα, αυτό που πρόκειται να αποφασιστεί. Και οι αποφάσεις και οι αιτιολογήσεις τους καταγράφονται σε πολύγλωσσα πρακτικά — αυτά είναι που ισχύουν για τη βιβλιοθήκη σου.",
    "federacao.assembleias.lang.note": "Η γραμματεία ορίζεται κατά την έναρξη· αυτούς τους γλωσσικούς κανόνες η συνέλευση μπορεί να τους επιβεβαιώσει ή να τους προσαρμόσει."
  }
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes('"' + SENTINEL + '"')) {
    const map = ADD[loc];
    const keys = Object.keys(ADD['pt-BR']);
    const entries = keys.map((k) => {
      if (map[k] == null) throw new Error('Traduction manquante: ' + k + ' / ' + loc);
      return '  ' + JSON.stringify(k) + ': ' + JSON.stringify(map[k]);
    });
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entries.join(',\n') + '\n' + content.slice(marker);
    if (!content.endsWith('\n')) content += '\n';
  }
  fs.writeFileSync(file, content, 'utf8');
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ': 4 clés assembleias.lang.* (si absentes), JSON valide.');
}
console.log('\nTerminé.');
