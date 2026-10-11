/* ===========================================================================
 * i18n-add-b38-circulation.cjs — B38 (11/10/2026) : deux refus de circulation
 * traduits (HINT des fonctions PEB) — un exemplaire « équipe uniquement » ou
 * « consultation seule » ne part pas en prêt entre bibliothèques.
 * Idempotent : une clé déjà posée n'est réécrite que si sa valeur a changé ici.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const CLES = {
  'error.circulation.item_staff_only': {
    fr: 'Cet exemplaire est réservé à l’équipe (archive) : il ne se prête pas et ne part pas en prêt entre bibliothèques.',
    'pt-BR': 'Este exemplar é reservado à equipe (arquivo): não se empresta e não sai em empréstimo entre bibliotecas.',
    en: 'This copy is staff-only (archive): it cannot be lent and cannot go out on interlibrary loan.',
    es: 'Este ejemplar está reservado al equipo (archivo): no se presta y no sale en préstamo interbibliotecario.',
    ca: 'Aquest exemplar és reservat a l’equip (arxiu): no es presta i no surt en préstec interbibliotecari.',
    it: 'Questo esemplare è riservato all’équipe (archivio): non si presta e non parte in prestito interbibliotecario.',
    de: 'Dieses Exemplar ist nur für das Team (Archiv): Es wird nicht verliehen und geht nicht in die Fernleihe.',
    eo: 'Ĉi tiu ekzemplero estas rezervita al la teamo (arkivo): ĝi ne pruntiĝas kaj ne iras en interbibliotekan prunton.',
    nl: 'Dit exemplaar is alleen voor het team (archief): het wordt niet uitgeleend en gaat niet uit in interbibliothecair leenverkeer.',
    el: 'Αυτό το αντίτυπο είναι μόνο για την ομάδα (αρχείο): δεν δανείζεται και δεν βγαίνει σε διαδανεισμό.',
  },
  'error.circulation.item_consult_only': {
    fr: 'Cet exemplaire est en consultation sur place seulement : il ne se prête pas et ne part pas en prêt entre bibliothèques.',
    'pt-BR': 'Este exemplar é só de consulta local: não se empresta e não sai em empréstimo entre bibliotecas.',
    en: 'This copy is for on-site consultation only: it cannot be lent and cannot go out on interlibrary loan.',
    es: 'Este ejemplar es solo de consulta en sala: no se presta y no sale en préstamo interbibliotecario.',
    ca: 'Aquest exemplar és només de consulta a sala: no es presta i no surt en préstec interbibliotecari.',
    it: 'Questo esemplare è solo di consultazione in sede: non si presta e non parte in prestito interbibliotecario.',
    de: 'Dieses Exemplar ist nur zur Einsicht vor Ort: Es wird nicht verliehen und geht nicht in die Fernleihe.',
    eo: 'Ĉi tiu ekzemplero estas nur por surloka konsultado: ĝi ne pruntiĝas kaj ne iras en interbibliotekan prunton.',
    nl: 'Dit exemplaar is alleen ter inzage ter plaatse: het wordt niet uitgeleend en gaat niet uit in interbibliothecair leenverkeer.',
    el: 'Αυτό το αντίτυπο είναι μόνο για επιτόπια μελέτη: δεν δανείζεται και δεν βγαίνει σε διαδανεισμό.',
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
