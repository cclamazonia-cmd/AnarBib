#!/usr/bin/env node
/*
 * i18n-patch-acolhimento.cjs — ajoute les cles du guide d'accueil aux dix
 * locales React de src/i18n/locales/.
 *
 *   node scripts/i18n-patch-acolhimento.cjs           # applique
 *   node scripts/i18n-patch-acolhimento.cjs --check   # verifie sans ecrire
 *
 * Doctrine i18n du projet, appliquee telle quelle :
 *   - script .cjs additif et idempotent : le relancer ne fait rien de plus ;
 *   - insertion TEXTUELLE avant le } final, jamais de ConvertFrom-Json ni de
 *     reserialisation : une reecriture complete casse les sequences echappees ;
 *   - fichiers plats, LF, sans BOM, indentation 2 ;
 *   - les dix locales en une seule passe, jamais en deux ;
 *   - validation JSON.parse apres patch, restauration si elle echoue.
 *
 * A lancer depuis la racine du depot de l'application.
 * Ensuite : npm test (vitest, dont src/tests/i18n-ecriture.test.js) puis npm run build.
 */

'use strict';

const fs = require('fs');
const path = require('path');

const DATA = {
  "pt-BR": {
    "account.constitution.banner.title": "A sua candidatura foi aceita — agora é a constituição",
    "account.constitution.banner.body": "A sua biblioteca está pré-ativa. Complete a oficina de constituição e leve o regimento à assembleia; o guia de acolhimento acompanha você passo a passo.",
    "account.constitution.banner.cta": "Abrir o guia de acolhimento",
    "account.constitution.guideUrl": "https://anarbib.org/pt/acolhimento/",
    "atelier.guide.callout": "Cada escolha desta oficina é uma decisão do coletivo, não um campo a preencher. O guia de acolhimento diz o que cada uma muda na prática."
  },
  "fr": {
    "account.constitution.banner.title": "Ta candidature est acceptée — place à la constitution",
    "account.constitution.banner.body": "Ta bibliothèque est pré-active. Termine l'atelier de constitution et porte le règlement en assemblée ; le guide d'accueil t'accompagne pas à pas.",
    "account.constitution.banner.cta": "Ouvrir le guide d'accueil",
    "account.constitution.guideUrl": "https://anarbib.org/fr/accueil/",
    "atelier.guide.callout": "Chaque choix de cet atelier est une décision du collectif, pas un champ à remplir. Le guide d'accueil dit ce que chacun change en pratique."
  },
  "es": {
    "account.constitution.banner.title": "Tu candidatura fue aceptada — ahora la constitución",
    "account.constitution.banner.body": "Tu biblioteca está preactiva. Terminá el taller de constitución y llevá el reglamento a la asamblea; la guía de acogida te acompaña paso a paso.",
    "account.constitution.banner.cta": "Abrir la guía de acogida",
    "account.constitution.guideUrl": "https://anarbib.org/es/acogida/",
    "atelier.guide.callout": "Cada elección de este taller es una decisión del colectivo, no un campo a llenar. La guía de acogida dice lo que cada una cambia en la práctica."
  },
  "en": {
    "account.constitution.banner.title": "Your application is accepted — now the constitution",
    "account.constitution.banner.body": "Your library is pre-active. Finish the constitution workshop and take the bylaws to the assembly; the welcome guide walks you through it step by step.",
    "account.constitution.banner.cta": "Open the welcome guide",
    "account.constitution.guideUrl": "https://anarbib.org/en/welcome/",
    "atelier.guide.callout": "Every choice in this workshop is a decision of the collective, not a field to fill in. The welcome guide says what each one changes in practice."
  },
  "it": {
    "account.constitution.banner.title": "La candidatura è accettata — ora la costituzione",
    "account.constitution.banner.body": "La tua biblioteca è pre-attiva. Completa il laboratorio di costituzione e porta il regolamento in assemblea; la guida di accoglienza ti accompagna passo passo.",
    "account.constitution.banner.cta": "Apri la guida di accoglienza",
    "account.constitution.guideUrl": "https://anarbib.org/it/accoglienza/",
    "atelier.guide.callout": "Ogni scelta di questo laboratorio è una decisione del collettivo, non un campo da riempire. La guida di accoglienza dice che cosa ciascuna cambia nella pratica."
  },
  "de": {
    "account.constitution.banner.title": "Deine Bewerbung ist angenommen — jetzt die Gründung",
    "account.constitution.banner.body": "Deine Bibliothek ist vor-aktiv. Beende die Gründungswerkstatt und bring die Geschäftsordnung in die Versammlung; der Willkommensleitfaden begleitet dich Schritt für Schritt.",
    "account.constitution.banner.cta": "Willkommensleitfaden öffnen",
    "account.constitution.guideUrl": "https://anarbib.org/de/willkommen/",
    "atelier.guide.callout": "Jede Wahl in dieser Werkstatt ist eine Entscheidung des Kollektivs und kein auszufüllendes Feld; der Willkommensleitfaden sagt dir, was jede davon in der Praxis ändert."
  },
  "ca": {
    "account.constitution.banner.title": "La teva candidatura és acceptada — ara, la constitució",
    "account.constitution.banner.body": "La teva biblioteca és preactiva. Acaba el taller de constitució i porta el reglament a l'assemblea; la guia d'acollida t'acompanya pas a pas.",
    "account.constitution.banner.cta": "Obrir la guia d'acollida",
    "account.constitution.guideUrl": "https://anarbib.org/ca/acollida/",
    "atelier.guide.callout": "Cada tria d'aquest taller és una decisió del col·lectiu i no un camp per omplir; la guia d'acollida diu què canvia cadascuna a la pràctica."
  },
  "eo": {
    "account.constitution.banner.title": "Via kandidatiĝo estas akceptita — nun la konstituiĝo",
    "account.constitution.banner.body": "Via biblioteko estas antaŭaktiva. Finu la metiejon de konstituiĝo kaj portu la regularon al la asembleo; la akcepta gvidilo akompanas vin paŝon post paŝo.",
    "account.constitution.banner.cta": "Malfermi la akceptan gvidilon",
    "account.constitution.guideUrl": "https://anarbib.org/eo/akcepto/",
    "atelier.guide.callout": "Ĉiu elekto en ĉi tiu metiejo estas decido de la kolektivo kaj ne kampo plenigenda; la akcepta gvidilo diras kion ĉiu el ili ŝanĝas praktike."
  },
  "nl": {
    "account.constitution.banner.title": "Jouw kandidatuur is aanvaard — nu de oprichting",
    "account.constitution.banner.body": "Jouw bibliotheek is pre-actief. Maak het oprichtingsatelier af en breng het reglement naar de assemblee; de welkomstgids begeleidt je stap voor stap.",
    "account.constitution.banner.cta": "De welkomstgids openen",
    "account.constitution.guideUrl": "https://anarbib.org/nl/onthaal/",
    "atelier.guide.callout": "Elke keuze in dit atelier is een beslissing van het collectief, geen veld om in te vullen; de welkomstgids zegt wat elke keuze in de praktijk verandert."
  },
  "el": {
    "account.constitution.banner.title": "Η υποψηφιότητά σου έγινε δεκτή — τώρα η σύσταση",
    "account.constitution.banner.body": "Η βιβλιοθήκη σου είναι προ-ενεργή. Ολοκλήρωσε το εργαστήρι σύστασης και πήγαινε τον κανονισμό στη συνέλευση· ο οδηγός υποδοχής σε συνοδεύει βήμα βήμα.",
    "account.constitution.banner.cta": "Άνοιξε τον οδηγό υποδοχής",
    "account.constitution.guideUrl": "https://anarbib.org/el/ypodochi/",
    "atelier.guide.callout": "Κάθε επιλογή σε αυτό το εργαστήρι είναι απόφαση της συλλογικότητας, όχι πεδίο προς συμπλήρωση· ο οδηγός υποδοχής λέει τι αλλάζει η καθεμία στην πράξη."
  }
};

const LOCALES_DIR = path.join(process.cwd(), 'src', 'i18n', 'locales');
const CHECK = process.argv.includes('--check');

let added = 0;
let missing = 0;
const problems = [];

function jsonStr(s) { return JSON.stringify(s); }

for (const [locale, entries] of Object.entries(DATA)) {
  const file = path.join(LOCALES_DIR, `${locale}.json`);
  if (!fs.existsSync(file)) { problems.push(`${locale}: fichier absent (${file})`); continue; }

  const raw = fs.readFileSync(file);
  if (raw[0] === 0xef && raw[1] === 0xbb && raw[2] === 0xbf) {
    problems.push(`${locale}: BOM en tete — a retirer avant de patcher.`);
    continue;
  }
  let text = raw.toString('utf8');
  if (text.includes('\r')) {
    problems.push(`${locale}: fins de ligne CRLF — a normaliser en LF avant de patcher.`);
    continue;
  }

  const toAdd = Object.entries(entries).filter(([k]) => {
    const re = new RegExp(`^\\s*${jsonStr(k).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\s*:`, 'm');
    return !re.test(text);
  });

  if (toAdd.length === 0) { console.log(`  ${locale.padEnd(6)} deja a jour`); continue; }

  if (CHECK) {
    missing += toAdd.length;
    console.log(`  ${locale.padEnd(6)} ${toAdd.length} cle(s) manquante(s) : ${toAdd.map(([k]) => k).join(', ')}`);
    continue;
  }

  const closing = text.lastIndexOf('}');
  if (closing === -1) { problems.push(`${locale}: pas d'accolade fermante.`); continue; }

  let head = text.slice(0, closing).replace(/\s*$/, '');
  if (!head.endsWith(',') && !head.endsWith('{')) head += ',';

  const body = toAdd.map(([k, v]) => `\n  ${jsonStr(k)}: ${jsonStr(v)},`).join('');
  const patched = `${head}${body.replace(/,$/, '')}\n}\n`;

  try {
    JSON.parse(patched);
  } catch (e) {
    problems.push(`${locale}: le resultat n'est pas du JSON valide (${e.message}) — fichier laisse intact.`);
    continue;
  }

  fs.writeFileSync(file, patched, { encoding: 'utf8' });
  added += toAdd.length;
  console.log(`  ${locale.padEnd(6)} +${toAdd.length} cle(s)`);
}

if (problems.length) {
  console.error('\nProblemes :');
  problems.forEach((p) => console.error(`  ${p}`));
}

if (CHECK) {
  console.log(`\n${missing === 0 ? 'Les dix locales ont toutes les cles.' : `${missing} cle(s) manquante(s).`}`);
  process.exit(problems.length || missing ? 1 : 0);
}

console.log(`\n${added} cle(s) ajoutee(s).`);
console.log('Etapes suivantes : npx eslint --ext .json src/i18n/locales (si configure), npm test, npm run build.');
process.exit(problems.length ? 1 : 0);
