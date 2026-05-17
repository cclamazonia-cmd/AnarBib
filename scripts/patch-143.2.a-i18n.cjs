// ============================================================
// Patch 143.2.a — i18n pour l'onglet Historique (9 cles × 6 locales)
// ============================================================
// Premier sous-patch du #143.2 (structure UI onglet Historique).
//
// Ajoute 9 nouvelles cles dans les 6 fichiers de locale :
//   - panel.tab.history (label tab)
//   - panel.tab.history.hint (sous-titre tab)
//   - panel.history.title (h2 de la section)
//   - panel.history.subtitle (paragraphe d'intro)
//   - panel.history.filter.reservas (pill)
//   - panel.history.filter.consultas (pill)
//   - panel.history.filter.emprestimos (pill)
//   - panel.history.noFilter (message quand aucun type coche)
//   - panel.history.empty (placeholder #143.2, sera remplace par les
//     vraies donnees en #143.3)
//
// Pattern : insertion alphabetique apres les cles 'panel.history.*' 
// existantes (s'il y en a), sinon a la fin du bloc 'panel.*'.
//
// Methode UTF-8 safe : utilise fs.readFileSync().toString('utf8') puis
// JSON.parse pour modification structuree, puis JSON.stringify avec
// indentation 2 espaces (pattern existant du repo).
// ============================================================

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const LOCALES_DIR = path.join(REPO_ROOT, 'src/i18n/locales');

const TRANSLATIONS = {
  'pt-BR': {
    'panel.tab.history': 'Histórico',
    'panel.tab.history.hint': 'Itens arquivados',
    'panel.history.title': 'Histórico de itens',
    'panel.history.subtitle': 'Reservas, consultas e empréstimos arquivados.',
    'panel.history.filter.reservas': 'Reservas',
    'panel.history.filter.consultas': 'Consultas',
    'panel.history.filter.emprestimos': 'Empréstimos',
    'panel.history.noFilter': 'Selecione ao menos um tipo.',
    'panel.history.empty': 'Nenhum item arquivado por enquanto.'
  },
  'fr': {
    'panel.tab.history': 'Historique',
    'panel.tab.history.hint': 'Items archivés',
    'panel.history.title': 'Historique des items',
    'panel.history.subtitle': 'Réservations, consultations et emprunts archivés.',
    'panel.history.filter.reservas': 'Réservations',
    'panel.history.filter.consultas': 'Consultations',
    'panel.history.filter.emprestimos': 'Emprunts',
    'panel.history.noFilter': 'Sélectionne au moins un type.',
    'panel.history.empty': 'Aucun item archivé pour l\'instant.'
  },
  'es': {
    'panel.tab.history': 'Historial',
    'panel.tab.history.hint': 'Items archivados',
    'panel.history.title': 'Historial de items',
    'panel.history.subtitle': 'Reservas, consultas y préstamos archivados.',
    'panel.history.filter.reservas': 'Reservas',
    'panel.history.filter.consultas': 'Consultas',
    'panel.history.filter.emprestimos': 'Préstamos',
    'panel.history.noFilter': 'Selecciona al menos un tipo.',
    'panel.history.empty': 'Sin items archivados por ahora.'
  },
  'en': {
    'panel.tab.history': 'History',
    'panel.tab.history.hint': 'Archived items',
    'panel.history.title': 'Items history',
    'panel.history.subtitle': 'Archived reservations, consultations, and loans.',
    'panel.history.filter.reservas': 'Reservations',
    'panel.history.filter.consultas': 'Consultations',
    'panel.history.filter.emprestimos': 'Loans',
    'panel.history.noFilter': 'Select at least one type.',
    'panel.history.empty': 'No archived items yet.'
  },
  'it': {
    'panel.tab.history': 'Storico',
    'panel.tab.history.hint': 'Voci archiviate',
    'panel.history.title': 'Storico delle voci',
    'panel.history.subtitle': 'Prenotazioni, consultazioni e prestiti archiviati.',
    'panel.history.filter.reservas': 'Prenotazioni',
    'panel.history.filter.consultas': 'Consultazioni',
    'panel.history.filter.emprestimos': 'Prestiti',
    'panel.history.noFilter': 'Seleziona almeno un tipo.',
    'panel.history.empty': 'Nessuna voce archiviata per ora.'
  },
  'de': {
    'panel.tab.history': 'Verlauf',
    'panel.tab.history.hint': 'Archivierte Einträge',
    'panel.history.title': 'Verlauf der Einträge',
    'panel.history.subtitle': 'Archivierte Reservierungen, Konsultationen und Ausleihen.',
    'panel.history.filter.reservas': 'Reservierungen',
    'panel.history.filter.consultas': 'Konsultationen',
    'panel.history.filter.emprestimos': 'Ausleihen',
    'panel.history.noFilter': 'Wähle mindestens einen Typ aus.',
    'panel.history.empty': 'Noch keine archivierten Einträge.'
  }
};

console.log('===== Patch 143.2.a i18n onglet Historique =====\n');

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
  
  // Lecture UTF-8 explicite (mais Node fait deja UTF-8 par defaut)
  const content = fs.readFileSync(filePath, 'utf8');
  const data = JSON.parse(content);
  
  const beforeKeys = Object.keys(data).length;
  let addedThisLocale = 0;
  let skippedThisLocale = 0;
  
  for (const [key, value] of Object.entries(TRANSLATIONS[locale])) {
    if (key in data) {
      skippedThisLocale++;
      console.log(`  SKIP : ${key} deja present (= '${data[key]}')`);
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
  
  // Tri alphabetique des cles pour conserver le pattern du repo
  const sortedKeys = Object.keys(data).sort();
  const sortedData = {};
  for (const k of sortedKeys) {
    sortedData[k] = data[k];
  }
  
  // Reecriture avec indentation 2 espaces + newline final
  const newContent = JSON.stringify(sortedData, null, 2) + '\n';
  fs.writeFileSync(filePath, newContent, 'utf8');
  
  totalAdded += addedThisLocale;
  totalSkipped += skippedThisLocale;
  console.log(`  Ecrit : ${newContent.length} bytes (${addedThisLocale} cles ajoutees)`);
}

console.log('\n===== Resume =====');
console.log(`  Total cles ajoutees : ${totalAdded}`);
console.log(`  Total cles sautees  : ${totalSkipped}`);
console.log(`  Fichiers traites    : ${locales.length}`);

if (totalAdded === 0 && totalSkipped > 0) {
  console.log('\n[INFO] Patch deja applique. Aucune modification.');
  process.exit(0);
}

if (totalAdded !== 9 * locales.length && totalAdded !== 0) {
  console.error(`\n[WARN] Compteur inattendu : ${totalAdded} ajoutees (attendu ${9 * locales.length} ou 0)`);
}

console.log('\n===== Patch 143.2.a applique =====');
console.log('\nProchaines etapes :');
console.log('  1. git diff src/i18n/locales/');
console.log('  2. (optionnel) Verifier qu\'aucune cle existante n\'a ete modifiee accidentellement');
console.log('  3. Enchaîner sur 143.2.b (CSS) puis 143.2.c (JSX)');

process.exit(allOk ? 0 : 1);
