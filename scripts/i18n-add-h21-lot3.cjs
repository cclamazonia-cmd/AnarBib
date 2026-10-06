/* ===========================================================================
 * i18n-add-h21-lot3.cjs — H21 lot 3 (REGISTRE IMP-23, IMP-29, 05/10/2026) :
 * comparer à trois états (base de l'import précédent, notice AnarBib, nouveau
 * fichier), en lecture seule.
 * Page Importations : la mention des comptes sur une ligne « Déjà importée »
 * (fn_import_list_run_rows.comparison_counts) — changements que le fichier
 * apporte ({n}, dont {c} conflits), champs à revoir sans base ({n}), ou aucun.
 * Rapport de révision (BatchReviewReport, clé `updates`) : titre, résumé
 * ({rows} notices comparées, {changed} qui changent), les six verdicts, les
 * trois valeurs ({b} base, {a} AnarBib, {n} fichier).
 * 15 clés × 10 locales (12 le 05/10, 3 le 06/10 : comparaison non calculée,
 * notices non comparées, valeur masquée). Tutoiement partout ; pt-BR au
 * « você » (« sua visão », masked). Vocabulaire repris des clés
 * voisines de chaque langue (importacoes.fila.*, review.report.*).
 * Idempotent : une clé déjà posée n'est réécrite que si sa valeur a changé ici.
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const CLES = {
  'importacoes.fila.comparison.changes': {
    fr: '{n, plural, one {# changement dans le fichier} other {# changements dans le fichier}}{c, plural, =0 {} one {, dont # conflit} other {, dont # conflits}}',
    'pt-BR': '{n, plural, one {# alteração no arquivo} other {# alterações no arquivo}}{c, plural, =0 {} one {, incluindo # conflito} other {, incluindo # conflitos}}',
    en: '{n, plural, one {# change in the file} other {# changes in the file}}{c, plural, =0 {} one {, including # conflict} other {, including # conflicts}}',
    es: '{n, plural, one {# cambio en el archivo} other {# cambios en el archivo}}{c, plural, =0 {} one {, incluido # conflicto} other {, incluidos # conflictos}}',
    ca: '{n, plural, one {# canvi al fitxer} other {# canvis al fitxer}}{c, plural, =0 {} one {, inclòs # conflicte} other {, inclosos # conflictes}}',
    it: '{n, plural, one {# modifica nel file} other {# modifiche nel file}}{c, plural, =0 {} one {, di cui # conflitto} other {, di cui # conflitti}}',
    de: '{n, plural, one {# Änderung in der Datei} other {# Änderungen in der Datei}}{c, plural, =0 {} one {, davon # Konflikt} other {, davon # Konflikte}}',
    nl: '{n, plural, one {# wijziging in het bestand} other {# wijzigingen in het bestand}}{c, plural, =0 {} one {, waarvan # conflict} other {, waarvan # conflicten}}',
    eo: '{n, plural, one {# ŝanĝo en la dosiero} other {# ŝanĝoj en la dosiero}}{c, plural, =0 {} one {, el kiuj # konflikto} other {, el kiuj # konfliktoj}}',
    el: '{n, plural, one {# αλλαγή στο αρχείο} other {# αλλαγές στο αρχείο}}{c, plural, =0 {} one {, από τις οποίες # σύγκρουση} other {, από τις οποίες # συγκρούσεις}}',
  },
  'importacoes.fila.comparison.toReview': {
    fr: '{n, plural, one {# champ à revoir (sans base)} other {# champs à revoir (sans base)}}',
    'pt-BR': '{n, plural, one {# campo a revisar (sem base)} other {# campos a revisar (sem base)}}',
    en: '{n, plural, one {# field to review (no baseline)} other {# fields to review (no baseline)}}',
    es: '{n, plural, one {# campo por revisar (sin base)} other {# campos por revisar (sin base)}}',
    ca: '{n, plural, one {# camp per revisar (sense base)} other {# camps per revisar (sense base)}}',
    it: '{n, plural, one {# campo da rivedere (senza base)} other {# campi da rivedere (senza base)}}',
    de: '{n, plural, one {# Feld zu prüfen (ohne Basis)} other {# Felder zu prüfen (ohne Basis)}}',
    nl: '{n, plural, one {# veld na te kijken (zonder basis)} other {# velden na te kijken (zonder basis)}}',
    eo: '{n, plural, one {# kampo reviziinda (sen bazo)} other {# kampoj reviziindaj (sen bazo)}}',
    el: '{n, plural, one {# πεδίο προς έλεγχο (χωρίς βάση)} other {# πεδία προς έλεγχο (χωρίς βάση)}}',
  },
  'importacoes.fila.comparison.none': {
    fr: 'Aucun changement dans le fichier',
    'pt-BR': 'Nenhuma alteração no arquivo',
    en: 'No change in the file',
    es: 'Ningún cambio en el archivo',
    ca: 'Cap canvi al fitxer',
    it: 'Nessuna modifica nel file',
    de: 'Keine Änderung in der Datei',
    nl: 'Geen wijziging in het bestand',
    eo: 'Neniu ŝanĝo en la dosiero',
    el: 'Καμία αλλαγή στο αρχείο',
  },
  // 06/10 : la comparaison se calcule à l'ouverture (coordination, administration) ;
  // pour qui ne peut pas la demander, elle reste « non calculée ».
  'importacoes.fila.comparison.notComputed': {
    fr: 'Comparaison non calculée',
    'pt-BR': 'Comparação não calculada',
    en: 'Comparison not computed',
    es: 'Comparación no calculada',
    ca: 'Comparació no calculada',
    it: 'Confronto non calcolato',
    de: 'Vergleich nicht berechnet',
    nl: 'Vergelijking niet berekend',
    eo: 'Komparo ne kalkulita',
    el: 'Η σύγκριση δεν έχει υπολογιστεί',
  },
  'review.report.updates.notCompared': {
    fr: '{n, plural, one {# notice pas encore comparée (ou à recomparer)} other {# notices pas encore comparées (ou à recomparer)}}',
    'pt-BR': '{n, plural, one {# ficha ainda não comparada (ou a comparar de novo)} other {# fichas ainda não comparadas (ou a comparar de novo)}}',
    en: '{n, plural, one {# record not compared yet (or to compare again)} other {# records not compared yet (or to compare again)}}',
    es: '{n, plural, one {# ficha aún no comparada (o por volver a comparar)} other {# fichas aún no comparadas (o por volver a comparar)}}',
    ca: '{n, plural, one {# fitxa encara no comparada (o per tornar a comparar)} other {# fitxes encara no comparades (o per tornar a comparar)}}',
    it: '{n, plural, one {# scheda non ancora confrontata (o da riconfrontare)} other {# schede non ancora confrontate (o da riconfrontare)}}',
    de: '{n, plural, one {# Eintrag noch nicht verglichen (oder neu zu vergleichen)} other {# Einträge noch nicht verglichen (oder neu zu vergleichen)}}',
    nl: '{n, plural, one {# record nog niet vergeleken (of opnieuw te vergelijken)} other {# records nog niet vergeleken (of opnieuw te vergelijken)}}',
    eo: '{n, plural, one {# slipo ankoraŭ ne komparita (aŭ rekomparenda)} other {# slipoj ankoraŭ ne komparitaj (aŭ rekomparendaj)}}',
    el: '{n, plural, one {# εγγραφή δεν έχει συγκριθεί ακόμη (ή θέλει νέα σύγκριση)} other {# εγγραφές δεν έχουν συγκριθεί ακόμη (ή θέλουν νέα σύγκριση)}}',
  },
  'review.report.updates.masked': {
    fr: 'masqué (notice hors de ta vue)',
    'pt-BR': 'oculto (ficha fora da sua visão)',
    en: 'hidden (record outside your view)',
    es: 'oculto (ficha fuera de tu vista)',
    ca: 'amagat (fitxa fora de la teva vista)',
    it: 'nascosto (scheda fuori dalla tua vista)',
    de: 'verborgen (Eintrag außerhalb deiner Sicht)',
    nl: 'verborgen (record buiten jouw zicht)',
    eo: 'kaŝita (slipo ekster via vido)',
    el: 'κρυφό (εγγραφή εκτός της όψης σου)',
  },
  'review.report.updates': {
    fr: 'Mises à jour apportées par le fichier',
    'pt-BR': 'Atualizações trazidas pelo arquivo',
    en: 'Updates brought by the file',
    es: 'Actualizaciones que trae el archivo',
    ca: 'Actualitzacions que porta el fitxer',
    it: 'Aggiornamenti portati dal file',
    de: 'Aktualisierungen aus der Datei',
    nl: 'Updates uit het bestand',
    eo: 'Ĝisdatigoj el la dosiero',
    el: 'Ενημερώσεις από το αρχείο',
  },
  'review.report.updates.summary': {
    fr: '{rows, plural, one {# notice déjà importée comparée} other {# notices déjà importées comparées}} ; {changed, plural, =0 {aucune ne change dans le fichier} one {# change dans le fichier} other {# changent dans le fichier}}',
    'pt-BR': '{rows, plural, one {# ficha já importada comparada} other {# fichas já importadas comparadas}}; {changed, plural, =0 {nenhuma muda no arquivo} one {# muda no arquivo} other {# mudam no arquivo}}',
    en: '{rows, plural, one {# already-imported record compared} other {# already-imported records compared}}; {changed, plural, =0 {none changes in the file} one {# changes in the file} other {# change in the file}}',
    es: '{rows, plural, one {# ficha ya importada comparada} other {# fichas ya importadas comparadas}}; {changed, plural, =0 {ninguna cambia en el archivo} one {# cambia en el archivo} other {# cambian en el archivo}}',
    ca: '{rows, plural, one {# fitxa ja importada comparada} other {# fitxes ja importades comparades}}; {changed, plural, =0 {cap no canvia al fitxer} one {# canvia al fitxer} other {# canvien al fitxer}}',
    it: '{rows, plural, one {# scheda già importata confrontata} other {# schede già importate confrontate}}; {changed, plural, =0 {nessuna cambia nel file} one {# cambia nel file} other {# cambiano nel file}}',
    de: '{rows, plural, one {# schon importierter Eintrag verglichen} other {# schon importierte Einträge verglichen}}; {changed, plural, =0 {keiner ändert sich in der Datei} one {# ändert sich in der Datei} other {# ändern sich in der Datei}}',
    nl: '{rows, plural, one {# al geïmporteerd record vergeleken} other {# al geïmporteerde records vergeleken}}; {changed, plural, =0 {geen enkel verandert in het bestand} one {# verandert in het bestand} other {# veranderen in het bestand}}',
    eo: '{rows, plural, one {# jam importita slipo komparita} other {# jam importitaj slipoj komparitaj}}; {changed, plural, =0 {neniu ŝanĝiĝas en la dosiero} one {# ŝanĝiĝas en la dosiero} other {# ŝanĝiĝas en la dosiero}}',
    el: '{rows, plural, one {# ήδη εισαγμένη εγγραφή συγκρίθηκε} other {# ήδη εισαγμένες εγγραφές συγκρίθηκαν}} · {changed, plural, =0 {καμία δεν αλλάζει στο αρχείο} one {# αλλάζει στο αρχείο} other {# αλλάζουν στο αρχείο}}',
  },
  'review.report.updates.verdict.inchange': {
    fr: 'Inchangé', 'pt-BR': 'Inalterado', en: 'Unchanged', es: 'Sin cambios', ca: 'Sense canvis',
    it: 'Invariato', de: 'Unverändert', nl: 'Ongewijzigd', eo: 'Neŝanĝita', el: 'Αμετάβλητο',
  },
  'review.report.updates.verdict.identique': {
    fr: 'Déjà pareil dans AnarBib', 'pt-BR': 'Já igual no AnarBib', en: 'Already the same in AnarBib',
    es: 'Ya igual en AnarBib', ca: 'Ja igual a AnarBib', it: 'Già uguale in AnarBib', de: 'In AnarBib schon gleich',
    nl: 'Al gelijk in AnarBib', eo: 'Jam sama en AnarBib', el: 'Ήδη ίδιο στο AnarBib',
  },
  'review.report.updates.verdict.source_seule': {
    fr: 'Changé dans le fichier seulement', 'pt-BR': 'Alterado só no arquivo', en: 'Changed in the file only',
    es: 'Cambiado solo en el archivo', ca: 'Canviat només al fitxer', it: 'Modificato solo nel file',
    de: 'Nur in der Datei geändert', nl: 'Alleen in het bestand gewijzigd', eo: 'Ŝanĝita nur en la dosiero',
    el: 'Άλλαξε μόνο στο αρχείο',
  },
  'review.report.updates.verdict.local_seul': {
    fr: 'Changé dans AnarBib seulement (gardé)', 'pt-BR': 'Alterado só no AnarBib (mantido)',
    en: 'Changed in AnarBib only (kept)', es: 'Cambiado solo en AnarBib (se conserva)',
    ca: 'Canviat només a AnarBib (es manté)', it: 'Modificato solo in AnarBib (mantenuto)',
    de: 'Nur in AnarBib geändert (bleibt)', nl: 'Alleen in AnarBib gewijzigd (blijft)',
    eo: 'Ŝanĝita nur en AnarBib (konservata)', el: 'Άλλαξε μόνο στο AnarBib (διατηρείται)',
  },
  'review.report.updates.verdict.conflit': {
    fr: 'Conflit (signalé, jamais appliqué)', 'pt-BR': 'Conflito (sinalizado, nunca aplicado)',
    en: 'Conflict (flagged, never applied)', es: 'Conflicto (señalado, nunca aplicado)',
    ca: 'Conflicte (assenyalat, mai aplicat)', it: 'Conflitto (segnalato, mai applicato)',
    de: 'Konflikt (gemeldet, nie übernommen)', nl: 'Conflict (gemeld, nooit toegepast)',
    eo: 'Konflikto (signalita, neniam aplikata)', el: 'Σύγκρουση (επισημαίνεται, δεν εφαρμόζεται ποτέ)',
  },
  'review.report.updates.verdict.sans_base': {
    fr: 'À revoir (sans base)', 'pt-BR': 'A revisar (sem base)', en: 'To review (no baseline)',
    es: 'Por revisar (sin base)', ca: 'Per revisar (sense base)', it: 'Da rivedere (senza base)',
    de: 'Zu prüfen (ohne Basis)', nl: 'Na te kijken (zonder basis)', eo: 'Reviziinda (sen bazo)',
    el: 'Προς έλεγχο (χωρίς βάση)',
  },
  'review.report.updates.values': {
    fr: 'base : {b} · AnarBib : {a} · fichier : {n}',
    'pt-BR': 'base: {b} · AnarBib: {a} · arquivo: {n}',
    en: 'baseline: {b} · AnarBib: {a} · file: {n}',
    es: 'base: {b} · AnarBib: {a} · archivo: {n}',
    ca: 'base: {b} · AnarBib: {a} · fitxer: {n}',
    it: 'base: {b} · AnarBib: {a} · file: {n}',
    de: 'Basis: {b} · AnarBib: {a} · Datei: {n}',
    nl: 'basis: {b} · AnarBib: {a} · bestand: {n}',
    eo: 'bazo: {b} · AnarBib: {a} · dosiero: {n}',
    el: 'βάση: {b} · AnarBib: {a} · αρχείο: {n}',
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
