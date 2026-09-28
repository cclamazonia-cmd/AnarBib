#!/usr/bin/env node
/**
 * i18n-add-export-unimarc.cjs — H23/H24 (28/09/2026), aller-retour PMB.
 *
 *  - importacoes.export.lote.desc : les formats offerts deviennent
 *    « UNIMARC, MARC21, CSV, JSON » (UNIMARC en ISO 2709 et en XML, MARC21 en
 *    ISO 2709 et en MARCXML) ;
 *  - importacoes.export.lote.warnings : ce que le format n'a pas pu porter en
 *    entier (en-tête X-Export-Warnings de l'EF export-catalog-lote) ;
 *  - importacoes.export.lote.progress : H26, la lecture du catalogue par pages.
 * Tutoiement partout ; pt-BR au « você ». Idempotent.
 */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const AVANT = '(CSV, MARCXML, JSON)';
const APRES = '(UNIMARC, MARC21, CSV, JSON)';

const WARNINGS = {
  fr: "Le fichier est prêt, avec {n, plural, one {# remarque} other {# remarques}} : le format n’a pas pu tout porter (zone raccourcie ou découpée, notes ou zones d’origine omises, ou notice de plus de 99 999 octets écartée).",
  'pt-BR': "O arquivo está pronto, com {n, plural, one {# observação} other {# observações}}: o formato não comportou tudo (campo encurtado ou dividido, notas ou campos de origem omitidos, ou registro com mais de 99 999 bytes deixado de fora).",
  es: "El archivo está listo, con {n, plural, one {# observación} other {# observaciones}}: el formato no pudo llevarlo todo (campo acortado o dividido, notas o campos de origen omitidos, o registro de más de 99 999 bytes dejado fuera).",
  en: "The file is ready, with {n, plural, one {# note} other {# notes}}: the format could not carry everything (a field shortened or split, notes or original fields left out, or a record over 99,999 bytes left out).",
  ca: "El fitxer és a punt, amb {n, plural, one {# observació} other {# observacions}}: el format no ho ha pogut portar tot (camp escurçat o dividit, notes o camps d’origen omesos, o registre de més de 99 999 octets deixat fora).",
  de: "Die Datei ist fertig, mit {n, plural, one {# Hinweis} other {# Hinweisen}}: Das Format konnte nicht alles aufnehmen (Feld gekürzt oder geteilt, Anmerkungen oder Ursprungsfelder weggelassen oder ein Datensatz über 99 999 Bytes ausgelassen).",
  el: "Το αρχείο είναι έτοιμο, με {n, plural, one {# παρατήρηση} other {# παρατηρήσεις}}: η μορφή δεν μπόρεσε να τα χωρέσει όλα (πεδίο συντομεύτηκε ή χωρίστηκε, σημειώσεις ή αρχικά πεδία παραλείφθηκαν, ή εγγραφή πάνω από 99 999 byte αφέθηκε εκτός).",
  eo: "La dosiero pretas, kun {n, plural, one {# rimarko} other {# rimarkoj}}: la formato ne povis porti ĉion (kampo mallongigita aŭ dividita, notoj aŭ originaj kampoj preterlasitaj, aŭ registro de pli ol 99 999 bajtoj preterlasita).",
  it: "Il file è pronto, con {n, plural, one {# osservazione} other {# osservazioni}}: il formato non ha potuto contenere tutto (campo accorciato o diviso, note o campi d’origine omessi, o record di oltre 99 999 byte escluso).",
  nl: "Het bestand is klaar, met {n, plural, one {# opmerking} other {# opmerkingen}}: het formaat kon niet alles bevatten (veld ingekort of gesplitst, noten of oorspronkelijke velden weggelaten, of een record van meer dan 99 999 bytes weggelaten).",
};

const PROGRESS = {
  fr: '{n} / {total} notices lues…',
  'pt-BR': '{n} / {total} registros lidos…',
  es: '{n} / {total} registros leídos…',
  en: '{n} / {total} records read…',
  ca: '{n} / {total} registres llegits…',
  de: '{n} / {total} Datensätze gelesen…',
  el: '{n} / {total} εγγραφές διαβάστηκαν…',
  eo: '{n} / {total} registroj legitaj…',
  it: '{n} / {total} record letti…',
  nl: '{n} / {total} records gelezen…'
};

let n = 0;
for (const loc of LOCALES) {
  const f = path.join(DIR, `${loc}.json`);
  const j = JSON.parse(fs.readFileSync(f, 'utf8'));
  const d = j['importacoes.export.lote.desc'];
  if (typeof d !== 'string') throw new Error(`${loc} : importacoes.export.lote.desc absente`);
  if (d.includes(AVANT)) { j['importacoes.export.lote.desc'] = d.replace(AVANT, APRES); n++; }
  else if (!d.includes(APRES)) throw new Error(`${loc} : description sans la liste des formats`);
  if (!WARNINGS[loc]) throw new Error(`${loc} : traduction absente`);
  if (j['importacoes.export.lote.warnings'] !== WARNINGS[loc]) { j['importacoes.export.lote.warnings'] = WARNINGS[loc]; n++; }
  if (!('importacoes.export.lote.progress' in j)) { j['importacoes.export.lote.progress'] = PROGRESS[loc]; n++; }
  fs.writeFileSync(f, JSON.stringify(j, null, 2) + '\n');
}
console.log(`écrit : ${n}`);
