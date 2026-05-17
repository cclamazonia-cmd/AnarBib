// ============================================================
// Patch 143.3.b — i18n pour listes historiques (20 cles × 6 locales)
// ============================================================
// Premier sous-patch du #143.3 (fetch + affichage donnees historiques).
//
// Ajoute 20 nouvelles cles dans les 6 fichiers de locale pour :
//   - 3 titres de sections collapsibles (reservations/consultas/emprestimos)
//   - 9 colonnes (title, status, reader, requested, scheduled, closed, 
//     motif, items, type, returned)
//   - 2 types d'emprunt (uni/groupe)
//   - 1 bouton "load more"
//   - 2 tooltips toggle (expand/collapse)
//   - 1 count format
//   - 1 details toggle (mobile cards)
//   - 1 message "no items" specifique
//
// NOTE : les statuts (reservation.stage.*, consultation.stage.*)
// existent deja - on les reutilisera dans le JSX.
//
// NOTE : on reutilise panel.history.empty cree en 143.2.a comme
// fallback quand une section a 0 items. On AJOUTE en plus
// panel.history.section.empty pour le message specifique a une section.
// ============================================================

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const LOCALES_DIR = path.join(REPO_ROOT, 'src/i18n/locales');

const TRANSLATIONS = {
  'pt-BR': {
    'panel.history.section.reservations': 'Reservas',
    'panel.history.section.consultas': 'Consultas',
    'panel.history.section.emprestimos': 'Empréstimos',
    'panel.history.col.title': 'Documento',
    'panel.history.col.status': 'Estado',
    'panel.history.col.reader': 'Leitor(a/e)',
    'panel.history.col.requested': 'Solicitada em',
    'panel.history.col.scheduled': 'Prevista para',
    'panel.history.col.closed': 'Arquivada em',
    'panel.history.col.motif': 'Motivo',
    'panel.history.col.items': 'Documentos',
    'panel.history.col.type': 'Tipo',
    'panel.history.col.returned': 'Devolvido em',
    'panel.history.type.uni': 'Único',
    'panel.history.type.groupe': 'Agrupado',
    'panel.history.loadMore': 'Carregar mais',
    'panel.history.expandSection': 'Mostrar',
    'panel.history.collapseSection': 'Ocultar',
    'panel.history.itemsCount': '{count} {count, plural, one {item} other {itens}}',
    'panel.history.detailsToggle': '+ detalhes',
    'panel.history.section.empty': 'Nenhum item arquivado neste tipo.'
  },
  'fr': {
    'panel.history.section.reservations': 'Réservations',
    'panel.history.section.consultas': 'Consultations',
    'panel.history.section.emprestimos': 'Emprunts',
    'panel.history.col.title': 'Document',
    'panel.history.col.status': 'État',
    'panel.history.col.reader': 'Lecteur·rice',
    'panel.history.col.requested': 'Demandée le',
    'panel.history.col.scheduled': 'Prévue le',
    'panel.history.col.closed': 'Archivée le',
    'panel.history.col.motif': 'Motif',
    'panel.history.col.items': 'Documents',
    'panel.history.col.type': 'Type',
    'panel.history.col.returned': 'Rendu·e le',
    'panel.history.type.uni': 'Unique',
    'panel.history.type.groupe': 'Groupé',
    'panel.history.loadMore': 'Charger plus',
    'panel.history.expandSection': 'Afficher',
    'panel.history.collapseSection': 'Masquer',
    'panel.history.itemsCount': '{count} {count, plural, one {item} other {items}}',
    'panel.history.detailsToggle': '+ détails',
    'panel.history.section.empty': 'Aucun item archivé dans ce type.'
  },
  'es': {
    'panel.history.section.reservations': 'Reservas',
    'panel.history.section.consultas': 'Consultas',
    'panel.history.section.emprestimos': 'Préstamos',
    'panel.history.col.title': 'Documento',
    'panel.history.col.status': 'Estado',
    'panel.history.col.reader': 'Lector(a/e)',
    'panel.history.col.requested': 'Solicitada el',
    'panel.history.col.scheduled': 'Prevista para',
    'panel.history.col.closed': 'Archivada el',
    'panel.history.col.motif': 'Motivo',
    'panel.history.col.items': 'Documentos',
    'panel.history.col.type': 'Tipo',
    'panel.history.col.returned': 'Devuelta el',
    'panel.history.type.uni': 'Único',
    'panel.history.type.groupe': 'Agrupado',
    'panel.history.loadMore': 'Cargar más',
    'panel.history.expandSection': 'Mostrar',
    'panel.history.collapseSection': 'Ocultar',
    'panel.history.itemsCount': '{count} {count, plural, one {item} other {items}}',
    'panel.history.detailsToggle': '+ detalles',
    'panel.history.section.empty': 'Sin items archivados de este tipo.'
  },
  'en': {
    'panel.history.section.reservations': 'Reservations',
    'panel.history.section.consultas': 'Consultations',
    'panel.history.section.emprestimos': 'Loans',
    'panel.history.col.title': 'Document',
    'panel.history.col.status': 'Status',
    'panel.history.col.reader': 'Reader',
    'panel.history.col.requested': 'Requested on',
    'panel.history.col.scheduled': 'Scheduled for',
    'panel.history.col.closed': 'Archived on',
    'panel.history.col.motif': 'Reason',
    'panel.history.col.items': 'Documents',
    'panel.history.col.type': 'Type',
    'panel.history.col.returned': 'Returned on',
    'panel.history.type.uni': 'Single',
    'panel.history.type.groupe': 'Grouped',
    'panel.history.loadMore': 'Load more',
    'panel.history.expandSection': 'Show',
    'panel.history.collapseSection': 'Hide',
    'panel.history.itemsCount': '{count} {count, plural, one {item} other {items}}',
    'panel.history.detailsToggle': '+ details',
    'panel.history.section.empty': 'No archived items of this type.'
  },
  'it': {
    'panel.history.section.reservations': 'Prenotazioni',
    'panel.history.section.consultas': 'Consultazioni',
    'panel.history.section.emprestimos': 'Prestiti',
    'panel.history.col.title': 'Documento',
    'panel.history.col.status': 'Stato',
    'panel.history.col.reader': 'Lettore/trice',
    'panel.history.col.requested': 'Richiesta il',
    'panel.history.col.scheduled': 'Prevista per',
    'panel.history.col.closed': 'Archiviata il',
    'panel.history.col.motif': 'Motivo',
    'panel.history.col.items': 'Documenti',
    'panel.history.col.type': 'Tipo',
    'panel.history.col.returned': 'Restituito il',
    'panel.history.type.uni': 'Singolo',
    'panel.history.type.groupe': 'Raggruppato',
    'panel.history.loadMore': 'Carica altri',
    'panel.history.expandSection': 'Mostra',
    'panel.history.collapseSection': 'Nascondi',
    'panel.history.itemsCount': '{count} {count, plural, one {voce} other {voci}}',
    'panel.history.detailsToggle': '+ dettagli',
    'panel.history.section.empty': 'Nessuna voce archiviata di questo tipo.'
  },
  'de': {
    'panel.history.section.reservations': 'Reservierungen',
    'panel.history.section.consultas': 'Konsultationen',
    'panel.history.section.emprestimos': 'Ausleihen',
    'panel.history.col.title': 'Dokument',
    'panel.history.col.status': 'Status',
    'panel.history.col.reader': 'Leser·in',
    'panel.history.col.requested': 'Angefragt am',
    'panel.history.col.scheduled': 'Vorgesehen für',
    'panel.history.col.closed': 'Archiviert am',
    'panel.history.col.motif': 'Grund',
    'panel.history.col.items': 'Dokumente',
    'panel.history.col.type': 'Typ',
    'panel.history.col.returned': 'Zurückgegeben am',
    'panel.history.type.uni': 'Einzeln',
    'panel.history.type.groupe': 'Gruppiert',
    'panel.history.loadMore': 'Mehr laden',
    'panel.history.expandSection': 'Anzeigen',
    'panel.history.collapseSection': 'Verbergen',
    'panel.history.itemsCount': '{count} {count, plural, one {Eintrag} other {Einträge}}',
    'panel.history.detailsToggle': '+ Details',
    'panel.history.section.empty': 'Keine archivierten Einträge dieses Typs.'
  }
};

console.log('===== Patch 143.3.b i18n listes historiques =====\n');

const locales = Object.keys(TRANSLATIONS);
let totalAdded = 0;
let totalSkipped = 0;
let allOk = true;

for (const locale of locales) {
  const filePath = path.join(LOCALES_DIR, `${locale}.json`);
  
  if (!fs.existsSync(filePath)) {
    console.error(`[FATAL] Fichier introuvable : ${filePath}`);
    allOk = false;
    continue;
  }
  
  console.log(`\n[${locale}] ${filePath}`);
  
  const content = fs.readFileSync(filePath, 'utf8');
  const data = JSON.parse(content);
  
  const beforeKeys = Object.keys(data).length;
  let addedThisLocale = 0;
  let skippedThisLocale = 0;
  
  for (const [key, value] of Object.entries(TRANSLATIONS[locale])) {
    if (key in data) {
      skippedThisLocale++;
    } else {
      data[key] = value;
      addedThisLocale++;
    }
  }
  
  const afterKeys = Object.keys(data).length;
  console.log(`  Cles : ${beforeKeys} -> ${afterKeys} (+${addedThisLocale} ajoutees, ${skippedThisLocale} sautees)`);
  
  if (addedThisLocale === 0) {
    console.log(`  [INFO] Aucune modification, fichier non reecrit.`);
    totalSkipped += skippedThisLocale;
    continue;
  }
  
  // Tri alphabetique pour conserver le pattern du repo
  const sortedKeys = Object.keys(data).sort();
  const sortedData = {};
  for (const k of sortedKeys) {
    sortedData[k] = data[k];
  }
  
  const newContent = JSON.stringify(sortedData, null, 2) + '\n';
  fs.writeFileSync(filePath, newContent, 'utf8');
  
  totalAdded += addedThisLocale;
  totalSkipped += skippedThisLocale;
  console.log(`  Ecrit : ${newContent.length} bytes`);
}

console.log('\n===== Resume =====');
console.log(`  Total cles ajoutees : ${totalAdded}`);
console.log(`  Total cles sautees  : ${totalSkipped}`);
console.log(`  Fichiers traites    : ${locales.length}`);

if (totalAdded === 0 && totalSkipped > 0) {
  console.log('\n[INFO] Patch deja applique. Aucune modification.');
  process.exit(0);
}

const expectedTotal = Object.keys(TRANSLATIONS['pt-BR']).length * locales.length;
if (totalAdded !== expectedTotal && totalAdded !== 0) {
  console.error(`\n[WARN] Compteur inattendu : ${totalAdded} ajoutees (attendu ${expectedTotal})`);
}

console.log('\n===== Patch 143.3.b applique =====');
console.log('\nProchaines etapes :');
console.log('  1. git diff src/i18n/locales/');
console.log('  2. Enchaîner sur 143.3.c (CSS) puis 143.3.d (JSX)');

process.exit(allOk ? 0 : 1);
