#!/usr/bin/env node
/* eslint-disable */
// Clés i18n du bouton de géocodage (MAP-F / spec §7). Parité 10 locales, idempotent.
// Auteur : AnarBib · Session : Carte réseau 10 locales.
const fs = require('node:fs');
const path = require('node:path');
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const T = {
  'federacao.carte.edit.geocode': { fr:"Localiser depuis l'adresse", 'pt-BR':'Localizar pelo endereço', es:'Localizar desde la dirección', it:"Localizza dall'indirizzo", de:'Aus Adresse lokalisieren', en:'Locate from address', ca:"Localitza des de l'adreça", eo:'Lokalizi laŭ adreso', nl:'Lokaliseren via adres', el:'Εντοπισμός από τη διεύθυνση' },
  'federacao.carte.edit.geocodeFail': { fr:'Adresse introuvable — placez le point manuellement.', 'pt-BR':'Endereço não encontrado — posicione o ponto manualmente.', es:'Dirección no encontrada — coloca el punto manualmente.', it:'Indirizzo non trovato — posiziona il punto manualmente.', de:'Adresse nicht gefunden — Punkt manuell setzen.', en:'Address not found — place the point manually.', ca:'Adreça no trobada — col·loca el punt manualment.', eo:'Adreso netrovita — metu la punkton permane.', nl:'Adres niet gevonden — plaats het punt handmatig.', el:'Η διεύθυνση δεν βρέθηκε — τοποθετήστε το σημείο χειροκίνητα.' },
};

let total = 0;
for (const file of fs.readdirSync(DIR).filter((f) => f.endsWith('.json'))) {
  const loc = file.replace(/\.json$/, '');
  const p = path.join(DIR, file);
  const obj = JSON.parse(fs.readFileSync(p, 'utf8'));
  let added = 0;
  for (const [key, byLoc] of Object.entries(T)) {
    const val = byLoc[loc];
    if (val == null) { console.warn(`[warn] ${key} manque pour ${loc}`); continue; }
    if (!(key in obj)) { obj[key] = val; added++; }
  }
  if (added) { fs.writeFileSync(p, JSON.stringify(obj, null, 2) + '\n', 'utf8'); total += added; }
  console.log(`${file.padEnd(11)} +${added}`);
}
console.log(`Total : ${total}`);
