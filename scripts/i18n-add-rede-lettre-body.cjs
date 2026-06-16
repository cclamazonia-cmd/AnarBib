/* ===========================================================================
 * i18n-add-rede-lettre-body.cjs
 * L4 — édition du corps par locale dans LettreStaffPanel : 7 clés × 10 locales.
 * Idempotent (sentinelle rede.lettre.ts.original).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'rede.lettre.ts.original';

const ADD = {
  'pt-BR': {
    'rede.lettre.body': 'Corpo da carta (markdown), por idioma',
    'rede.lettre.bodyTitle': 'Título (este idioma)',
    'rede.lettre.bodyPlaceholder': 'Escreve a carta em markdown (títulos, listas, negrito, links…)',
    'rede.lettre.saveLocale': 'Guardar este idioma',
    'rede.lettre.ts.machine': 'Tradução automática',
    'rede.lettre.ts.reviewed': 'Revisado por pessoa',
    'rede.lettre.ts.original': 'Original (idioma fonte)',
  },
  fr: {
    'rede.lettre.body': 'Corps de la lettre (markdown), par langue',
    'rede.lettre.bodyTitle': 'Titre (cette langue)',
    'rede.lettre.bodyPlaceholder': 'Écris la lettre en markdown (titres, listes, gras, liens…)',
    'rede.lettre.saveLocale': 'Enregistrer cette langue',
    'rede.lettre.ts.machine': 'Traduction machine',
    'rede.lettre.ts.reviewed': 'Relu·e par une personne',
    'rede.lettre.ts.original': 'Original (langue source)',
  },
  es: {
    'rede.lettre.body': 'Cuerpo de la carta (markdown), por idioma',
    'rede.lettre.bodyTitle': 'Título (este idioma)',
    'rede.lettre.bodyPlaceholder': 'Escribe la carta en markdown (títulos, listas, negrita, enlaces…)',
    'rede.lettre.saveLocale': 'Guardar este idioma',
    'rede.lettre.ts.machine': 'Traducción automática',
    'rede.lettre.ts.reviewed': 'Revisado por persona',
    'rede.lettre.ts.original': 'Original (idioma fuente)',
  },
  en: {
    'rede.lettre.body': 'Letter body (markdown), per language',
    'rede.lettre.bodyTitle': 'Title (this language)',
    'rede.lettre.bodyPlaceholder': 'Write the letter in markdown (headings, lists, bold, links…)',
    'rede.lettre.saveLocale': 'Save this language',
    'rede.lettre.ts.machine': 'Machine translation',
    'rede.lettre.ts.reviewed': 'Human-reviewed',
    'rede.lettre.ts.original': 'Original (source language)',
  },
  it: {
    'rede.lettre.body': 'Corpo della lettera (markdown), per lingua',
    'rede.lettre.bodyTitle': 'Titolo (questa lingua)',
    'rede.lettre.bodyPlaceholder': 'Scrivi la lettera in markdown (titoli, elenchi, grassetto, link…)',
    'rede.lettre.saveLocale': 'Salva questa lingua',
    'rede.lettre.ts.machine': 'Traduzione automatica',
    'rede.lettre.ts.reviewed': 'Rivisto da persona',
    'rede.lettre.ts.original': 'Originale (lingua sorgente)',
  },
  de: {
    'rede.lettre.body': 'Brieftext (Markdown), pro Sprache',
    'rede.lettre.bodyTitle': 'Titel (diese Sprache)',
    'rede.lettre.bodyPlaceholder': 'Schreibe den Brief in Markdown (Überschriften, Listen, fett, Links…)',
    'rede.lettre.saveLocale': 'Diese Sprache speichern',
    'rede.lettre.ts.machine': 'Maschinelle Übersetzung',
    'rede.lettre.ts.reviewed': 'Von Mensch geprüft',
    'rede.lettre.ts.original': 'Original (Ausgangssprache)',
  },
  ca: {
    'rede.lettre.body': 'Cos de la carta (markdown), per llengua',
    'rede.lettre.bodyTitle': 'Títol (aquesta llengua)',
    'rede.lettre.bodyPlaceholder': 'Escriu la carta en markdown (títols, llistes, negreta, enllaços…)',
    'rede.lettre.saveLocale': 'Desa aquesta llengua',
    'rede.lettre.ts.machine': 'Traducció automàtica',
    'rede.lettre.ts.reviewed': 'Revisat per persona',
    'rede.lettre.ts.original': 'Original (llengua font)',
  },
  eo: {
    'rede.lettre.body': 'Korpo de la letero (markdown), laŭ lingvo',
    'rede.lettre.bodyTitle': 'Titolo (ĉi tiu lingvo)',
    'rede.lettre.bodyPlaceholder': 'Verku la leteron en markdown (titoloj, listoj, grasa, ligiloj…)',
    'rede.lettre.saveLocale': 'Konservi ĉi tiun lingvon',
    'rede.lettre.ts.machine': 'Maŝina traduko',
    'rede.lettre.ts.reviewed': 'Reviziita de homo',
    'rede.lettre.ts.original': 'Originalo (fontlingvo)',
  },
  nl: {
    'rede.lettre.body': 'Brieftekst (markdown), per taal',
    'rede.lettre.bodyTitle': 'Titel (deze taal)',
    'rede.lettre.bodyPlaceholder': 'Schrijf de brief in markdown (koppen, lijsten, vet, links…)',
    'rede.lettre.saveLocale': 'Deze taal opslaan',
    'rede.lettre.ts.machine': 'Machinevertaling',
    'rede.lettre.ts.reviewed': 'Door mens nagekeken',
    'rede.lettre.ts.original': 'Origineel (brontaal)',
  },
  el: {
    'rede.lettre.body': 'Σώμα της επιστολής (markdown), ανά γλώσσα',
    'rede.lettre.bodyTitle': 'Τίτλος (αυτή η γλώσσα)',
    'rede.lettre.bodyPlaceholder': 'Γράψε την επιστολή σε markdown (τίτλοι, λίστες, έντονα, σύνδεσμοι…)',
    'rede.lettre.saveLocale': 'Αποθήκευση αυτής της γλώσσας',
    'rede.lettre.ts.machine': 'Αυτόματη μετάφραση',
    'rede.lettre.ts.reviewed': 'Ελεγμένο από άνθρωπο',
    'rede.lettre.ts.original': 'Πρωτότυπο (γλώσσα πηγής)',
  },
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
    fs.writeFileSync(file, content, 'utf8');
  }
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ': 7 clés rede.lettre.body (si absentes), JSON valide.');
}
console.log('\nTerminé.');
