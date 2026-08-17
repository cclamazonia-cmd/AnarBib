/* i18n-add-catalog-degraded-keys.cjs
 *
 * Bandeau du mode dégradé du catalogue : affiché quand l'API n'a pas répondu et
 * que la liste provient de l'instantané statique embarqué au build
 * (cf. src/lib/catalogueFallback.js, scripts/build-catalogue-snapshot.mjs).
 *
 * Append textuel, parité 10 locales, idempotent (DOC-PS-1 / DOC-I18N-1).
 * Charte de langue inclusive : on évite les formes bureaucratiques « (a) » /
 * « /a » ; en es on utilise le e neutre, en pt-BR la forme « (a/e) ».
 */
const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const KEYS = ['catalog.degraded.notice'];
const T = {
  'pt-BR': ['Modo degradado: o serviço não respondeu. Exibindo uma cópia do catálogo de {date}. A busca funciona, mas a disponibilidade pode estar desatualizada e não é possível reservar.'],
  fr: ['Mode dégradé : le service n’a pas répondu. Voici une copie du catalogue datée du {date}. La recherche fonctionne, mais la disponibilité peut être périmée et la réservation est impossible.'],
  es: ['Modo degradado: el servicio no respondió. Mostramos una copia del catálogo del {date}. La búsqueda funciona, pero la disponibilidad puede estar desactualizada y no se puede reservar.'],
  en: ['Degraded mode: the service did not respond. Showing a copy of the catalogue from {date}. Search works, but availability may be out of date and reserving is unavailable.'],
  it: ['Modalità degradata: il servizio non ha risposto. Mostriamo una copia del catalogo del {date}. La ricerca funziona, ma la disponibilità può essere superata e non è possibile prenotare.'],
  de: ['Eingeschränkter Modus: Der Dienst hat nicht geantwortet. Angezeigt wird eine Kopie des Katalogs vom {date}. Die Suche funktioniert, aber die Verfügbarkeit kann veraltet sein und Vormerkungen sind nicht möglich.'],
  ca: ['Mode degradat: el servei no ha respost. Mostrem una còpia del catàleg del {date}. La cerca funciona, però la disponibilitat pot estar desactualitzada i no es pot reservar.'],
  eo: ['Difektita reĝimo: la servo ne respondis. Ni montras kopion de la katalogo de {date}. La serĉo funkcias, sed la disponebleco povas esti malaktuala kaj rezervi ne eblas.'],
  nl: ['Beperkte modus: de dienst reageerde niet. Dit is een kopie van de catalogus van {date}. Zoeken werkt, maar de beschikbaarheid kan verouderd zijn en reserveren is niet mogelijk.'],
  el: ['Υποβαθμισμένη λειτουργία: η υπηρεσία δεν απάντησε. Εμφανίζεται αντίγραφο του καταλόγου της {date}. Η αναζήτηση λειτουργεί, αλλά η διαθεσιμότητα μπορεί να μην είναι ενημερωμένη και δεν είναι δυνατή η κράτηση.'],
};

let changed = 0;
for (const [loc, vals] of Object.entries(T)) {
  const file = path.join(dir, `${loc}.json`);
  const txt = fs.readFileSync(file, 'utf8');
  const obj = JSON.parse(txt);
  const toAdd = KEYS.map((k, i) => [k, vals[i]]).filter(([k]) => !(k in obj));
  if (!toAdd.length) { console.log(`${loc}: déjà à jour`); continue; }

  const eol = txt.includes('\r\n') ? '\r\n' : '\n';
  const close = txt.lastIndexOf('}');
  const head = txt.slice(0, close).replace(/\s+$/, '');
  const tail = txt.slice(close);
  const additions = toAdd
    .map(([k, v]) => `  ${JSON.stringify(k)}: ${JSON.stringify(v)}`)
    .join(`,${eol}`);
  const out = `${head},${eol}${additions}${eol}${tail}`;
  JSON.parse(out);
  fs.writeFileSync(file, out, 'utf8');
  console.log(`${loc}: +${toAdd.length} clé(s)`);
  changed += 1;
}
console.log(`Terminé (${changed} fichier(s) modifié(s)).`);
