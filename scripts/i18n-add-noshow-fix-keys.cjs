#!/usr/bin/env node
/* Clés i18n du fix no-show réservation (front) :
 *  - systemNote.noShowAuto : décodage de la sentinelle @@note: dans le Painel /
 *    l'affichage in-app (cf. src/lib/systemNotes.js). Doit refléter mot pour mot
 *    la même clé du catalogue mail (_shared/i18n/mail-strings.ts).
 *  - panel.apiError.pickup_scheduled_for_in_past : message de la garde serveur
 *    (api.advance_reservation refuse un retrait dans le passé), via localizeError.
 * Append textuel, parité 10 locales, idempotent (DOC-PS-1 / DOC-I18N-1). */
const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const KEYS = ['systemNote.noShowAuto', 'panel.apiError.pickup_scheduled_for_in_past'];
const T = {
  'pt-BR': ['Retirada não realizada no prazo (no-show automático).', 'A data de retirada deve estar no futuro.'],
  fr: ['Retrait non effectué dans le délai (no-show automatique).', 'La date de retrait doit être dans le futur.'],
  es: ['Retiro no realizado en el plazo (no-show automático).', 'La fecha de retiro debe ser futura.'],
  en: ['Pickup not completed within the deadline (automatic no-show).', 'The pickup date must be in the future.'],
  it: ['Ritiro non effettuato entro il termine (no-show automatico).', 'La data di ritiro deve essere futura.'],
  de: ['Abholung nicht fristgerecht erfolgt (automatischer No-Show).', 'Das Abholdatum muss in der Zukunft liegen.'],
  ca: ['Recollida no realitzada dins el termini (no-show automàtic).', 'La data de recollida ha de ser futura.'],
  eo: ['Repreno ne plenumita ĝustatempe (aŭtomata neapero).', 'La dato de repreno devas esti estonta.'],
  nl: ['Ophaling niet binnen de termijn voltooid (automatische no-show).', 'De ophaaldatum moet in de toekomst liggen.'],
  el: ['Η παραλαβή δεν ολοκληρώθηκε εντός της προθεσμίας (αυτόματο no-show).', 'Η ημερομηνία παραλαβής πρέπει να είναι μελλοντική.'],
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
