// src/pages/inicio/intentions.js
//
// La page « Je veux… » (05/09/2026) : une intention = un libellé, des mots
// pour la retrouver en tapant, un rôle minimum, et l'adresse EXACTE de la page
// et de l'onglet qui la réalisent. Toutes les pages lisent désormais leur
// onglet dans l'adresse (?tab=, #tab=, /page/:tab) — c'est ce socle qui
// permet de mener directement au geste.
//
// Les libellés et les mots-clés vivent dans les locales :
//   inicio.i.<id>  — « Réserver un livre dans ma bibliothèque »
//   inicio.kw.<id> — « réserver, retrait, rendez-vous, livre »
//
// Groupes : reader (tout compte), librarian (≥ bibliothécaire),
// coord (≥ coordination), admin (administration du réseau).

export const GROUPS = ['reader', 'librarian', 'coord', 'admin'];

export const INTENTIONS = [
  // ── Lire et emprunter ──────────────────────────────────────────────
  { id: 'search',        group: 'reader',    icon: 'search', to: '/' },
  { id: 'reserve',       group: 'reader',    icon: 'book', to: '/conta?tab=reservar' },
  { id: 'loans',         group: 'reader',    icon: 'archive', to: '/conta?tab=curso' },
  { id: 'history',       group: 'reader',    icon: 'archive', to: '/conta?tab=historico' },
  { id: 'notes',         group: 'reader',    icon: 'penLine', to: '/conta?tab=notas' },
  { id: 'wish',          group: 'reader',    icon: 'sparkles', to: '/conta?tab=desejos' },
  { id: 'notices',       group: 'reader',    icon: 'bell', to: '/conta?tab=avisos' },
  { id: 'joinLibrary',   group: 'reader',    icon: 'landmark', to: '/conta?tab=biblios' },
  { id: 'events',        group: 'reader',    icon: 'calendar', to: '/conta?tab=eventos' },
  { id: 'libraries',     group: 'reader',    icon: 'library', to: '/bibliotecas' },
  { id: 'map',           group: 'reader',    icon: 'map', to: '/cartografia' },
  { id: 'gazette',       group: 'reader',    icon: 'newspaper', to: '/federacao/gazeta' },
  { id: 'profile',       group: 'reader',    icon: 'user', to: '/conta?tab=perfil' },
  { id: 'report',        group: 'reader',    icon: 'warning', to: '/relatar-problema' }, /* E14 (24/09/2026) : sans compte aussi, par le pied de page */

  // ── Au comptoir et au catalogage ───────────────────────────────────
  { id: 'dayWork',       group: 'librarian', icon: 'dashboard', to: '/painel' },
  { id: 'reservations',  group: 'librarian', icon: 'inbox', to: '/painel/reservas' },
  { id: 'loansDesk',     group: 'librarian', icon: 'arrowLeftRight', to: '/painel/emprestimos' },
  { id: 'consultsDesk',  group: 'librarian', icon: 'message', to: '/painel/consultas-locais' },
  { id: 'welcomeReader', group: 'librarian', icon: 'users', to: '/painel/leitor' },
  { id: 'validate',      group: 'librarian', icon: 'check', to: '/painel/validacoes' },
  { id: 'recolement',    group: 'librarian', icon: 'clipboard', to: '/painel/recolement' },
  { id: 'coverPhotos',   group: 'librarian', icon: 'image', to: '/painel/capas' },          /* capas, 27/09/2026 */
  { id: 'catalog',       group: 'librarian', icon: 'document', to: '/catalogacao#tab=booksPanel' },
  { id: 'coverReview',   group: 'librarian', icon: 'image', to: '/catalogacao#tab=catalogPanel' }, /* capas en lot, 27/09/2026 */
  { id: 'authors',       group: 'librarian', icon: 'penLine', to: '/catalogacao#tab=authorsPanel' },
  { id: 'subjects',      group: 'librarian', icon: 'folder', to: '/catalogacao#tab=materiaPanel' },
  { id: 'labels',        group: 'librarian', icon: 'tags', to: '/catalogacao#tab=labelsPanel' },
  { id: 'queue',         group: 'librarian', icon: 'mail', to: '/catalogacao#tab=queuePanel' },
  { id: 'lots',          group: 'librarian', icon: 'package', to: '/catalogacao#tab=batchesPanel' },
  { id: 'duplicates',    group: 'librarian', icon: 'arrowLeftRight', to: '/catalogacao#tab=dedupPanel' },
  { id: 'periodicals',   group: 'librarian', icon: 'newspaper', to: '/catalogacao#tab=periodicosPanel' },
  { id: 'workshop',      group: 'librarian', icon: 'wrench', to: '/atelier-autoridades#tab=obras' },

  // ── Coordonner ma bibliothèque ─────────────────────────────────────
  { id: 'loanRules',     group: 'coord',     icon: 'scale', to: '/biblioteca#tab=regulation' },
  { id: 'identity',      group: 'coord',     icon: 'palette', to: '/biblioteca#tab=identity' },
  { id: 'comms',         group: 'coord',     icon: 'megaphone', to: '/biblioteca#tab=comms' },
  { id: 'team',          group: 'coord',     icon: 'users', to: '/biblioteca#tab=team' },
  { id: 'transitions',   group: 'coord',     icon: 'arrowLeftRight', to: '/biblioteca#tab=transicoes' },
  { id: 'readers',       group: 'coord',     icon: 'user', to: '/biblioteca#tab=leitores' },
  { id: 'import',        group: 'coord',     icon: 'arrowUp', to: '/importacoes#tab=arquivo' },
  { id: 'export',        group: 'coord',     icon: 'package', to: '/importacoes#tab=export' },
  { id: 'reviewRequest', group: 'coord',     icon: 'search', to: '/catalogacao#tab=batchesPanel' },
  { id: 'eventsCoord',   group: 'coord',     icon: 'calendar', to: '/biblioteca#tab=eventos' },
  { id: 'reports',       group: 'coord',     icon: 'gauge', to: '/biblioteca#tab=reports' },
  { id: 'ill',           group: 'coord',     icon: 'truck', to: '/biblioteca#tab=ill' },
  { id: 'tasks',         group: 'coord',     icon: 'document', to: '/biblioteca#tab=tasks' },
  { id: 'assemblies',    group: 'coord',     icon: 'message', to: '/federacao/assembleias' },
  { id: 'circles',       group: 'coord',     icon: 'users', to: '/federacao/circulos' },
  { id: 'communs',       group: 'coord',     icon: 'sparkles', to: '/federacao/communs' },

  // ── Administrer le réseau ──────────────────────────────────────────
  { id: 'welcomeLibrary', group: 'admin',    icon: 'building', to: '/rede#tab=requests' },
  { id: 'invitations',   group: 'admin',     icon: 'mail', to: '/rede#tab=invitations' },
  { id: 'reviewLots',    group: 'admin',     icon: 'search', to: '/rede#tab=reviews' },
  { id: 'networkReports', group: 'admin',    icon: 'gauge', to: '/rede#tab=reports' },
  { id: 'gazetteAdmin',  group: 'admin',     icon: 'document', to: '/rede#tab=gazeta' },
  { id: 'lettre',        group: 'admin',     icon: 'mail', to: '/rede#tab=lettre' },
  { id: 'admins',        group: 'admin',     icon: 'key', to: '/rede#tab=admins' },
];

// Quels groupes une personne voit, selon son rôle local et son rang réseau.
export function visibleGroups({ role, isNetworkAdmin }) {
  const g = ['reader'];
  const r = role || '';
  if (['librarian', 'coordenador', 'administrador'].includes(r) || isNetworkAdmin) g.push('librarian');
  if (['coordenador', 'administrador'].includes(r) || isNetworkAdmin) g.push('coord');
  if (isNetworkAdmin) g.push('admin');
  return g;
}

// Normalisation pour la recherche : minuscules, sans accents, sans ponctuation.
export function normalize(s) {
  return (s || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .trim();
}

// Les intentions qui répondent à ce qui est tapé : chaque mot tapé doit se
// retrouver au début d'un mot du libellé ou des mots-clés (« rés » trouve
// « réserver » et « réservations »). Classement : libellé avant mots-clés.
export function matchIntentions(query, items, labelOf, keywordsOf) {
  const q = normalize(query);
  if (!q) return [];
  const tokens = q.split(' ').filter(Boolean);
  const scored = [];
  for (const it of items) {
    const label = normalize(labelOf(it));
    const kw = normalize(keywordsOf(it));
    const labelWords = label.split(' ');
    const kwWords = kw.split(' ');
    let score = 0;
    let ok = true;
    for (const t of tokens) {
      if (labelWords.some(w => w.startsWith(t))) score += 2;
      else if (kwWords.some(w => w.startsWith(t))) score += 1;
      else { ok = false; break; }
    }
    if (ok) scored.push({ it, score });
  }
  scored.sort((a, b) => b.score - a.score);
  return scored.map(s => s.it);
}
