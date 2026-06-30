#!/usr/bin/env node
/* Ajoute le point « vocabulaire matière / thésaurus FICEDL » aux questions de
 * fond prévisionnelles de la 1re AG réseau (federacao.assembleias.firstPoints.q9).
 * Réf : docs/journal/cadrages/CADRAGE_ficedl_vocabulaire_indexation_2026-06-30.md.
 * Append textuel, parité stricte 10 locales, idempotent (DOC-I18N-1). */
const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const KEY = 'federacao.assembleias.firstPoints.q9';
const T = {
  'pt-BR': 'Vocabulário matéria: até onde apoiar-se no tesauro partilhado FICEDL? (a decidir com a FICEDL)',
  fr: "Vocabulaire matière : jusqu'où s'appuyer sur le thésaurus partagé FICEDL ? (à trancher avec la FICEDL)",
  es: 'Vocabulario de materias: ¿hasta dónde apoyarse en el tesauro compartido FICEDL? (a decidir con la FICEDL)',
  en: 'Subject vocabulary: how far to rely on the shared FICEDL thesaurus? (to be decided with FICEDL)',
  it: 'Vocabolario per soggetto: fino a che punto appoggiarsi al thesaurus condiviso FICEDL? (da decidere con la FICEDL)',
  de: 'Sachvokabular: wie weit sollen wir uns auf den gemeinsamen FICEDL-Thesaurus stützen? (mit FICEDL zu entscheiden)',
  ca: 'Vocabulari de matèria: fins on recolzar-se en el tesaurus compartit FICEDL? (a decidir amb la FICEDL)',
  eo: 'Tema-vortaro: ĝis kie apogi sin sur la komuna tezaŭro FICEDL? (decidota kun FICEDL)',
  nl: 'Onderwerpsvocabulaire: hoever leunen op de gedeelde FICEDL-thesaurus? (te beslissen met FICEDL)',
  el: 'Θεματικό λεξιλόγιο: ως πού να στηριχτούμε στον κοινό θησαυρό FICEDL; (προς απόφαση με τη FICEDL)',
};

let changed = 0;
for (const [loc, val] of Object.entries(T)) {
  const file = path.join(dir, `${loc}.json`);
  const txt = fs.readFileSync(file, 'utf8');
  const obj = JSON.parse(txt);
  if (KEY in obj) { console.log(`${loc}: déjà à jour`); continue; }
  const eol = txt.includes('\r\n') ? '\r\n' : '\n';
  const close = txt.lastIndexOf('}');
  const head = txt.slice(0, close).replace(/\s+$/, '');
  const tail = txt.slice(close);
  const out = `${head},${eol}  ${JSON.stringify(KEY)}: ${JSON.stringify(val)}${eol}${tail}`;
  JSON.parse(out); // valide avant écriture
  fs.writeFileSync(file, out, 'utf8');
  console.log(`${loc}: +1 clé`);
  changed += 1;
}
console.log(`Terminé (${changed} fichier(s) modifié(s)).`);
