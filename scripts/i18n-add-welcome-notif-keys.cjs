#!/usr/bin/env node
/* Ajoute les clés i18n de la notif de bienvenue in-app (cloche + onglet Avisos)
 * aux 10 locales. Insérées par l'EF register pour les lecteur·rices
 * (reader_pending / reader_orphan). Append textuel avant le `}` final :
 * préserve le contenu existant (clés plates, 2 espaces). Conforme DOC-PS-1
 * (Node .cjs, UTF-8) et DOC-I18N-1 (parité). Idempotent. */
const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const KEYS = ['notif.welcome.title', 'notif.welcome.body'];
const T = {
  'pt-BR': [
    'Boas-vindas à rede AnarBib!',
    'A tua conta foi criada. Para começar: explora o catálogo, faz a tua primeira reserva ou consulta, e completa o teu perfil em «Minha conta».',
  ],
  fr: [
    'Bienvenue dans le réseau AnarBib !',
    'Ton compte est créé. Pour commencer : explore le catalogue, fais ta première réservation ou consultation, et complète ton profil dans « Mon compte ».',
  ],
  es: [
    '¡Te damos la bienvenida a la red AnarBib!',
    'Tu cuenta fue creada. Para empezar: explora el catálogo, haz tu primera reserva o consulta, y completa tu perfil en «Mi cuenta».',
  ],
  en: [
    'Welcome to the AnarBib network!',
    'Your account is set up. To get started: explore the catalogue, make your first reservation or consultation, and complete your profile in “My account”.',
  ],
  it: [
    'Ti diamo il benvenuto nella rete AnarBib!',
    'Il tuo account è stato creato. Per iniziare: esplora il catalogo, fai la tua prima prenotazione o consultazione, e completa il tuo profilo in «Il mio account».',
  ],
  de: [
    'Willkommen im AnarBib-Netzwerk!',
    'Dein Konto wurde erstellt. Für den Anfang: erkunde den Katalog, mach deine erste Reservierung oder Einsichtnahme, und vervollständige dein Profil unter «Mein Konto».',
  ],
  ca: [
    'Et donem la benvinguda a la xarxa AnarBib!',
    "El teu compte s'ha creat. Per començar: explora el catàleg, fes la teva primera reserva o consulta, i completa el teu perfil a «El meu compte».",
  ],
  eo: [
    'Bonvenon al la reto AnarBib!',
    'Via konto estas kreita. Por komenci: esploru la katalogon, faru vian unuan rezervon aŭ konsulton, kaj kompletigu vian profilon en «Mia konto».',
  ],
  nl: [
    'Welkom bij het AnarBib-netwerk!',
    'Je account is aangemaakt. Om te beginnen: verken de catalogus, maak je eerste reservering of raadpleging, en vul je profiel aan bij «Mijn account».',
  ],
  el: [
    'Καλώς ήρθες στο δίκτυο AnarBib!',
    'Ο λογαριασμός σου δημιουργήθηκε. Για να ξεκινήσεις: εξερεύνησε τον κατάλογο, κάνε την πρώτη σου κράτηση ή επιτόπια χρήση, και συμπλήρωσε το προφίλ σου στο «Ο λογαριασμός μου».',
  ],
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
  JSON.parse(out); // garde-fou
  fs.writeFileSync(file, out, 'utf8');
  console.log(`${loc}: +${toAdd.length} clé(s)`);
  changed += 1;
}
console.log(`Terminé (${changed} fichier(s) modifié(s)).`);
