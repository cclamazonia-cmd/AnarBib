/**
 * Ajoute les clés de SÉCURITÉ DÉDUP du wizard (bannière + badge + plan de
 * promotion) aux 10 locales. Méthode SÛRE : insertion TEXTUELLE additive.
 * Run : node scripts/merge-imp-wizard-dedup-keys.cjs
 */
const fs = require('fs');
const path = require('path');
const DIR = path.resolve(__dirname, '../src/i18n/locales');
const FILES = { 'pt-BR': 'pt-BR.json', fr: 'fr.json', es: 'es.json', en: 'en.json', it: 'it.json', de: 'de.json', ca: 'ca.json', eo: 'eo.json', nl: 'nl.json', el: 'el.json' };

const K = (dupTitle, dupBody, dupBadge, plan, heldBack) => ({
  'importacoes.wizard.preview.dupTitle': dupTitle,
  'importacoes.wizard.preview.dupBody': dupBody,
  'importacoes.wizard.preview.dupBadge': dupBadge,
  'importacoes.wizard.promote.plan': plan,
  'importacoes.wizard.promote.heldBack': heldBack,
});

const KEYS = {
  'pt-BR': K('{n} notícia(s) já presente(s) no catálogo da rede', 'Num catálogo mutualizado, criar um duplicado gera incoerências graves. Estas linhas NÃO serão promovidas automaticamente — verifique-as e prefira o vínculo à notícia existente.', 'já no catálogo', '{novos} nova(s) notícia(s) → rascunhos. {retenus} linha(s) retida(s) (duplicados ou a revisar).', '{n} linha(s) retida(s), não promovidas (duplicados potenciais ou a revisar) — trate-as manualmente para evitar incoerências.'),
  fr: K('{n} notice(s) déjà présente(s) dans le catalogue réseau', 'Sur un catalogue mutualisé, créer un doublon génère des incohérences graves. Ces lignes ne seront PAS promues automatiquement — vérifiez-les et privilégiez le rattachement à la notice existante.', 'déjà au catalogue', '{novos} nouvelle(s) notice(s) → brouillons. {retenus} ligne(s) retenue(s) (doublons ou à revoir).', '{n} ligne(s) retenue(s), non promues (doublons potentiels ou à revoir) — traitez-les manuellement pour éviter les incohérences.'),
  es: K('{n} ficha(s) ya presente(s) en el catálogo de la red', 'En un catálogo mutualizado, crear un duplicado genera incoherencias graves. Estas líneas NO se promoverán automáticamente — verifíquelas y prefiera vincular a la ficha existente.', 'ya en el catálogo', '{novos} nueva(s) ficha(s) → borradores. {retenus} línea(s) retenida(s) (duplicados o a revisar).', '{n} línea(s) retenida(s), no promovidas (duplicados potenciales o a revisar) — trátelas manualmente para evitar incoherencias.'),
  en: K('{n} record(s) already in the network catalog', 'On a shared catalog, creating a duplicate causes serious inconsistencies. These rows will NOT be promoted automatically — review them and prefer linking to the existing record.', 'already in catalog', '{novos} new record(s) → drafts. {retenus} row(s) held back (duplicates or to review).', '{n} row(s) held back, not promoted (potential duplicates or to review) — handle them manually to avoid inconsistencies.'),
  it: K('{n} scheda/e già presente/i nel catalogo della rete', 'In un catalogo mutualizzato, creare un duplicato genera incoerenze gravi. Queste righe NON saranno promosse automaticamente — verificatele e preferite il collegamento alla scheda esistente.', 'già in catalogo', '{novos} nuova/e scheda/e → bozze. {retenus} riga/righe trattenuta/e (duplicati o da rivedere).', '{n} riga/righe trattenuta/e, non promosse (potenziali duplicati o da rivedere) — gestitele manualmente per evitare incoerenze.'),
  de: K('{n} Datensatz/Datensätze bereits im Netzwerkkatalog', 'In einem geteilten Katalog erzeugt ein Duplikat schwere Inkonsistenzen. Diese Zeilen werden NICHT automatisch übernommen — prüfe sie und verknüpfe bevorzugt mit dem bestehenden Datensatz.', 'schon im Katalog', '{novos} neue(r) Datensatz/Datensätze → Entwürfe. {retenus} Zeile(n) zurückgehalten (Duplikate oder zu prüfen).', '{n} Zeile(n) zurückgehalten, nicht übernommen (mögliche Duplikate oder zu prüfen) — manuell behandeln, um Inkonsistenzen zu vermeiden.'),
  ca: K('{n} fitxa/fitxes ja present(s) al catàleg de la xarxa', 'En un catàleg mutualitzat, crear un duplicat genera incoherències greus. Aquestes línies NO es promouran automàticament — verifiqueu-les i prefereixu vincular a la fitxa existent.', 'ja al catàleg', '{novos} nova/es fitxa/es → esborranys. {retenus} línia/es retinguda/es (duplicats o a revisar).', '{n} línia/es retinguda/es, no promogudes (duplicats potencials o a revisar) — tracteu-les manualment per evitar incoherències.'),
  eo: K('{n} registro(j) jam en la reta katalogo', 'En komuna katalogo, krei duplikaton kaŭzas gravajn malkoherecojn. Ĉi tiuj linioj NE estos aŭtomate promociitaj — kontrolu ilin kaj preferu ligon al la ekzistanta registro.', 'jam en katalogo', '{novos} nova(j) registro(j) → malnetoj. {retenus} linio(j) retenita(j) (duplikatoj aŭ por revizii).', '{n} linio(j) retenita(j), ne promociitaj (eblaj duplikatoj aŭ por revizii) — traktu ilin permane por eviti malkoherecojn.'),
  nl: K('{n} record(s) al aanwezig in de netwerkcatalogus', 'In een gedeelde catalogus veroorzaakt een duplicaat ernstige inconsistenties. Deze rijen worden NIET automatisch gepromoveerd — controleer ze en koppel bij voorkeur aan het bestaande record.', 'al in catalogus', '{novos} nieuw(e) record(s) → concepten. {retenus} rij(en) achtergehouden (duplicaten of te beoordelen).', '{n} rij(en) achtergehouden, niet gepromoveerd (mogelijke duplicaten of te beoordelen) — behandel ze handmatig om inconsistenties te voorkomen.'),
  el: K('{n} εγγραφή/ές ήδη στον κατάλογο του δικτύου', 'Σε έναν κοινό κατάλογο, η δημιουργία διπλότυπου προκαλεί σοβαρές ασυνέπειες. Αυτές οι γραμμές ΔΕΝ θα προαχθούν αυτόματα — ελέγξτε τες και προτιμήστε τη σύνδεση με την υπάρχουσα εγγραφή.', 'ήδη στον κατάλογο', '{novos} νέα/ες εγγραφή/ές → προσχέδια. {retenus} γραμμή/ές σε αναμονή (διπλότυπα ή προς έλεγχο).', '{n} γραμμή/ές σε αναμονή, δεν προήχθησαν (πιθανά διπλότυπα ή προς έλεγχο) — χειριστείτε τες χειροκίνητα για αποφυγή ασυνεπειών.'),
};

let total = 0;
for (const [loc, file] of Object.entries(FILES)) {
  const p = path.join(DIR, file);
  let txt = fs.readFileSync(p, 'utf8');
  const toAdd = Object.entries(KEYS[loc]).filter(([k]) => !txt.includes('"' + k + '"'));
  if (toAdd.length) {
    const ins = toAdd.map(([k, v]) => '  ' + JSON.stringify(k) + ': ' + JSON.stringify(v)).join(',\n');
    const i = txt.lastIndexOf('}');
    txt = txt.slice(0, i).replace(/\s*,?\s*$/, '') + ',\n' + ins + '\n' + txt.slice(i);
    fs.writeFileSync(p, txt, 'utf8');
  }
  JSON.parse(fs.readFileSync(p, 'utf8'));
  console.log(loc.padEnd(6), '+' + toAdd.length);
  total += toAdd.length;
}
console.log('\nTotal :', total);
