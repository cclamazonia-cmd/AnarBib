/* ===========================================================================
 * i18n-add-h33.cjs — H33 (12/10/2026) : « Rapprocher » et « Promouvoir » un
 * gros fichier sous le plafond de 8 s des appels de l'API. Une page d'appel
 * porte au plus 200 lignes et 5 000 exemplaires du fichier, comme « Préparer
 * la mise à jour » (lot 6b) ; l'écran découpe la sélection, la base refuse
 * au-delà. Le refus des 5 000 exemplaires reprend
 * error.import.update_page_too_many_items ; celui des 200 lignes est neuf
 * (error.import.update_page_too_large dit « par préparation »). Une page
 * refusée après d'autres : ce que les pages déjà envoyées ont créé
 * (importacoes.fila.pagesAvantRefus), puis le refus.
 * Tutoiement partout ; pt-BR au « você ». Vocabulaire repris des clés voisines.
 * Idempotent : une clé déjà posée n'est réécrite que si sa valeur a changé ici.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const CLES = {
  'error.import.page_too_large': {
    fr: 'Au plus 200 lignes par appel : sélectionne-en moins.',
    'pt-BR': 'No máximo 200 linhas por chamada: selecione menos.',
    en: 'At most 200 lines per call: select fewer.',
    es: 'Como máximo 200 líneas por llamada: selecciona menos.',
    ca: 'Com a màxim 200 línies per crida: selecciona’n menys.',
    it: 'Al massimo 200 righe per chiamata: selezionane meno.',
    de: 'Höchstens 200 Zeilen pro Aufruf: wähle weniger aus.',
    nl: 'Hoogstens 200 regels per aanroep: selecteer er minder.',
    eo: 'Maksimume 200 linioj por alvoko: elektu malpli.',
    el: 'Το πολύ 200 γραμμές ανά κλήση: επίλεξε λιγότερες.',
  },
  // Une page refusée après d'autres (« Créer », assistant) : ce que les pages
  // déjà envoyées ont créé, avant le refus traduit.
  'importacoes.fila.pagesAvantRefus': {
    fr: 'Avant ce refus, {created, plural, one {# brouillon a été créé} other {# brouillons ont été créés}} par les pages déjà envoyées.',
    'pt-BR': 'Antes desta recusa, {created, plural, one {# rascunho foi criado} other {# rascunhos foram criados}} pelas páginas já enviadas.',
    en: 'Before this refusal, {created, plural, one {# draft was created} other {# drafts were created}} by the pages already sent.',
    es: 'Antes de este rechazo, {created, plural, one {se creó # borrador} other {se crearon # borradores}} con las páginas ya enviadas.',
    ca: 'Abans d’aquest rebuig, {created, plural, one {s’ha creat # esborrany} other {s’han creat # esborranys}} amb les pàgines ja enviades.',
    it: 'Prima di questo rifiuto, {created, plural, one {è stata creata # bozza} other {sono state create # bozze}} dalle pagine già inviate.',
    de: 'Vor dieser Ablehnung {created, plural, one {wurde # Entwurf} other {wurden # Entwürfe}} durch die bereits gesendeten Seiten angelegt.',
    nl: 'Vóór deze weigering {created, plural, one {is # concept} other {zijn # concepten}} aangemaakt door de al verzonden pagina’s.',
    eo: 'Antaŭ ĉi tiu rifuzo, {created, plural, one {# malneto estis kreita} other {# malnetoj estis kreitaj}} de la jam senditaj paĝoj.',
    el: 'Πριν από αυτή την άρνηση, {created, plural, one {δημιουργήθηκε # πρόχειρο} other {δημιουργήθηκαν # πρόχειρα}} από τις σελίδες που έχουν ήδη σταλεί.',
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
