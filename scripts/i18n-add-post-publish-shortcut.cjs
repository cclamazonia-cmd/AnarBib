/* ===========================================================================
 * i18n-add-post-publish-shortcut.cjs
 * Bandeau « raccourci post-publication » (BookDraftForm) : après publication et
 * réinitialisation de la fiche, propose d'ajouter un exemplaire du document publié.
 * 4 clés × 10 locales. Idempotent (sentinelle catalogacao.postPublish.title).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'catalogacao.postPublish.title';

const ADD = {
  'pt-BR': {
    'catalogacao.postPublish.title': '« {title} » publicado',
    'catalogacao.postPublish.body': 'Adicionar um exemplar deste documento ao catálogo?',
    'catalogacao.postPublish.addExemplar': 'Adicionar exemplar',
    'catalogacao.postPublish.openBook': 'Ver a ficha',
  },
  fr: {
    'catalogacao.postPublish.title': '« {title} » publié',
    'catalogacao.postPublish.body': 'Ajouter un exemplaire de ce document au catalogue ?',
    'catalogacao.postPublish.addExemplar': 'Ajouter un exemplaire',
    'catalogacao.postPublish.openBook': 'Voir la fiche',
  },
  es: {
    'catalogacao.postPublish.title': '« {title} » publicado',
    'catalogacao.postPublish.body': '¿Añadir un ejemplar de este documento al catálogo?',
    'catalogacao.postPublish.addExemplar': 'Añadir un ejemplar',
    'catalogacao.postPublish.openBook': 'Ver la ficha',
  },
  en: {
    'catalogacao.postPublish.title': '“{title}” published',
    'catalogacao.postPublish.body': 'Add a copy of this document to the catalogue?',
    'catalogacao.postPublish.addExemplar': 'Add a copy',
    'catalogacao.postPublish.openBook': 'View record',
  },
  it: {
    'catalogacao.postPublish.title': '« {title} » pubblicato',
    'catalogacao.postPublish.body': 'Aggiungere una copia di questo documento al catalogo?',
    'catalogacao.postPublish.addExemplar': 'Aggiungi una copia',
    'catalogacao.postPublish.openBook': 'Vedi la scheda',
  },
  de: {
    'catalogacao.postPublish.title': '„{title}“ veröffentlicht',
    'catalogacao.postPublish.body': 'Ein Exemplar dieses Dokuments zum Katalog hinzufügen?',
    'catalogacao.postPublish.addExemplar': 'Exemplar hinzufügen',
    'catalogacao.postPublish.openBook': 'Datensatz ansehen',
  },
  ca: {
    'catalogacao.postPublish.title': '« {title} » publicat',
    'catalogacao.postPublish.body': 'Voleu afegir un exemplar d’aquest document al catàleg?',
    'catalogacao.postPublish.addExemplar': 'Afegeix un exemplar',
    'catalogacao.postPublish.openBook': 'Veure la fitxa',
  },
  eo: {
    'catalogacao.postPublish.title': '« {title} » publikigita',
    'catalogacao.postPublish.body': 'Ĉu aldoni ekzempleron de ĉi tiu dokumento al la katalogo?',
    'catalogacao.postPublish.addExemplar': 'Aldoni ekzempleron',
    'catalogacao.postPublish.openBook': 'Vidi la karton',
  },
  nl: {
    'catalogacao.postPublish.title': '„{title}“ gepubliceerd',
    'catalogacao.postPublish.body': 'Een exemplaar van dit document aan de catalogus toevoegen?',
    'catalogacao.postPublish.addExemplar': 'Exemplaar toevoegen',
    'catalogacao.postPublish.openBook': 'Record bekijken',
  },
  el: {
    'catalogacao.postPublish.title': '«{title}» δημοσιεύτηκε',
    'catalogacao.postPublish.body': 'Προσθήκη αντιτύπου αυτού του εγγράφου στον κατάλογο;',
    'catalogacao.postPublish.addExemplar': 'Προσθήκη αντιτύπου',
    'catalogacao.postPublish.openBook': 'Προβολή καρτέλας',
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
  console.log(loc + ': 4 clés (si absentes), JSON valide.');
}
console.log('\nTerminé.');
