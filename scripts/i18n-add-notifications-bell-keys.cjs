#!/usr/bin/env node
/* Ajoute les clés i18n de la cloche de notifications (MVP) aux 10 locales.
 * Append textuel avant le `}` final : préserve le contenu existant octet par
 * octet (clés plates, 2 espaces, fin de ligne du fichier conservée). Conforme
 * DOC-PS-1 (script Node .cjs, UTF-8) et DOC-I18N-1 (parité + clés plates).
 * Idempotent : ne réécrit pas une clé déjà présente. */
const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const KEYS = [
  'notifications.bell',
  'notifications.title',
  'notifications.empty',
  'notifications.markAllRead',
  'notifications.loadError',
];
const T = {
  'pt-BR': ['Notificações', 'Notificações', 'Nenhuma notificação', 'Marcar todas como lidas', 'Não foi possível carregar as notificações'],
  fr: ['Notifications', 'Notifications', 'Aucune notification', 'Tout marquer comme lu', 'Impossible de charger les notifications'],
  es: ['Notificaciones', 'Notificaciones', 'Sin notificaciones', 'Marcar todas como leídas', 'No se pudieron cargar las notificaciones'],
  it: ['Notifiche', 'Notifiche', 'Nessuna notifica', 'Segna tutte come lette', 'Impossibile caricare le notifiche'],
  de: ['Benachrichtigungen', 'Benachrichtigungen', 'Keine Benachrichtigungen', 'Alle als gelesen markieren', 'Benachrichtigungen konnten nicht geladen werden'],
  en: ['Notifications', 'Notifications', 'No notifications', 'Mark all as read', "Couldn't load notifications"],
  ca: ['Notificacions', 'Notificacions', 'Cap notificació', 'Marca-ho tot com a llegit', "No s'han pogut carregar les notificacions"],
  eo: ['Sciigoj', 'Sciigoj', 'Neniu sciigo', 'Marki ĉion kiel legitan', 'Ne eblis ŝargi la sciigojn'],
  nl: ['Meldingen', 'Meldingen', 'Geen meldingen', 'Alles als gelezen markeren', 'Kon meldingen niet laden'],
  el: ['Ειδοποιήσεις', 'Ειδοποιήσεις', 'Καμία ειδοποίηση', 'Επισήμανση όλων ως αναγνωσμένων', 'Δεν ήταν δυνατή η φόρτωση των ειδοποιήσεων'],
};

let changed = 0;
for (const [loc, vals] of Object.entries(T)) {
  const file = path.join(dir, `${loc}.json`);
  const txt = fs.readFileSync(file, 'utf8');
  const obj = JSON.parse(txt); // valide le JSON + détecte les clés présentes
  const toAdd = KEYS.map((k, i) => [k, vals[i]]).filter(([k]) => !(k in obj));
  if (!toAdd.length) { console.log(`${loc}: déjà à jour`); continue; }

  const eol = txt.includes('\r\n') ? '\r\n' : '\n';
  const close = txt.lastIndexOf('}');
  const head = txt.slice(0, close).replace(/\s+$/, ''); // jusqu'à la dernière "clé": "valeur"
  const tail = txt.slice(close); // `}` + éventuelle fin de ligne
  const additions = toAdd
    .map(([k, v]) => `  ${JSON.stringify(k)}: ${JSON.stringify(v)}`)
    .join(`,${eol}`);
  const out = `${head},${eol}${additions}${eol}${tail}`;
  JSON.parse(out); // garde-fou : le résultat doit rester un JSON valide
  fs.writeFileSync(file, out, 'utf8');
  console.log(`${loc}: +${toAdd.length} clé(s)`);
  changed += 1;
}
console.log(`Terminé (${changed} fichier(s) modifié(s)).`);
