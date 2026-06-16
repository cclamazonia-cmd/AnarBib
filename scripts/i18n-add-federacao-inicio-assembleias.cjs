/* ===========================================================================
 * i18n-add-federacao-inicio-assembleias.cjs
 * Carte de promotion « Assemblées » sur l'accueil (onglet Início) : 3 clés
 * (federacao.inicio.assembleias / .desc / .toAssembleias) dans les 10 locales.
 * Insertion idempotente (sentinelle federacao.inicio.assembleias).
 * Auteur : Claude (assistant)
 * Session : Fédération — Assemblée du réseau (AG)
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'federacao.inicio.assembleias';

const ADD = {
  'pt-BR': {
    "federacao.inicio.assembleias": "Assembleias gerais",
    "federacao.inicio.assembleias.desc": "Prefiguração da assembleia da rede: princípio, regras, ordem do dia.",
    "federacao.inicio.toAssembleias": "Abrir as assembleias"
  },
  fr: {
    "federacao.inicio.assembleias": "Assemblées générales",
    "federacao.inicio.assembleias.desc": "Préfiguration de l’assemblée du réseau : principe, règles, ordre du jour.",
    "federacao.inicio.toAssembleias": "Ouvrir les assemblées"
  },
  es: {
    "federacao.inicio.assembleias": "Asambleas generales",
    "federacao.inicio.assembleias.desc": "Prefiguración de la asamblea de la red: principio, reglas, orden del día.",
    "federacao.inicio.toAssembleias": "Abrir las asambleas"
  },
  en: {
    "federacao.inicio.assembleias": "General assemblies",
    "federacao.inicio.assembleias.desc": "Prefiguring the network assembly: principle, rules, agenda.",
    "federacao.inicio.toAssembleias": "Open the assemblies"
  },
  it: {
    "federacao.inicio.assembleias": "Assemblee generali",
    "federacao.inicio.assembleias.desc": "Prefigurazione dell’assemblea della rete: principio, regole, ordine del giorno.",
    "federacao.inicio.toAssembleias": "Apri le assemblee"
  },
  de: {
    "federacao.inicio.assembleias": "Vollversammlungen",
    "federacao.inicio.assembleias.desc": "Vorbereitung der Netzwerkversammlung: Prinzip, Regeln, Tagesordnung.",
    "federacao.inicio.toAssembleias": "Versammlungen öffnen"
  },
  ca: {
    "federacao.inicio.assembleias": "Assemblees generals",
    "federacao.inicio.assembleias.desc": "Prefiguració de l’assemblea de la xarxa: principi, regles, ordre del dia.",
    "federacao.inicio.toAssembleias": "Obrir les assemblees"
  },
  eo: {
    "federacao.inicio.assembleias": "Ĝeneralaj asembleoj",
    "federacao.inicio.assembleias.desc": "Antaŭpreparo de la reta asembleo: principo, reguloj, tagordo.",
    "federacao.inicio.toAssembleias": "Malfermi la asembleojn"
  },
  nl: {
    "federacao.inicio.assembleias": "Algemene vergaderingen",
    "federacao.inicio.assembleias.desc": "Voorbereiding van de netwerkvergadering: beginsel, regels, agenda.",
    "federacao.inicio.toAssembleias": "Vergaderingen openen"
  },
  el: {
    "federacao.inicio.assembleias": "Γενικές συνελεύσεις",
    "federacao.inicio.assembleias.desc": "Προετοιμασία της συνέλευσης του δικτύου: αρχή, κανόνες, ημερήσια διάταξη.",
    "federacao.inicio.toAssembleias": "Άνοιγμα των συνελεύσεων"
  }
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes('"' + SENTINEL + '"')) {
    const map = ADD[loc];
    const keys = Object.keys(ADD['pt-BR']);
    const entries = keys.map((k) => {
      if (map[k] == null) throw new Error('Traduction manquante: ' + k + ' / ' + loc);
      return '  ' + JSON.stringify(k) + ': ' + JSON.stringify(map[k]);
    });
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entries.join(',\n') + '\n' + content.slice(marker);
    if (!content.endsWith('\n')) content += '\n';
  }
  fs.writeFileSync(file, content, 'utf8');
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ': 3 clés inicio.assembleias (si absentes), JSON valide.');
}
console.log('\nTerminé.');
