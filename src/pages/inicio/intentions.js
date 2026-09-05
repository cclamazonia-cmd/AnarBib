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
  { id: 'search',        group: 'reader',    icon: '🔍', to: '/' },
  { id: 'reserve',       group: 'reader',    icon: '📗', to: '/conta?tab=reservar' },
  { id: 'loans',         group: 'reader',    icon: '⏳', to: '/conta?tab=curso' },
  { id: 'history',       group: 'reader',    icon: '🕰️', to: '/conta?tab=historico' },
  { id: 'notes',         group: 'reader',    icon: '✍️', to: '/conta?tab=notas' },
  { id: 'wish',          group: 'reader',    icon: '💭', to: '/conta?tab=desejos' },
  { id: 'notices',       group: 'reader',    icon: '🔔', to: '/conta?tab=avisos' },
  { id: 'joinLibrary',   group: 'reader',    icon: '🏛️', to: '/conta?tab=biblios' },
  { id: 'events',        group: 'reader',    icon: '🗓️', to: '/conta?tab=eventos' },
  { id: 'libraries',     group: 'reader',    icon: '📚', to: '/bibliotecas' },
  { id: 'map',           group: 'reader',    icon: '🗺️', to: '/cartografia' },
  { id: 'gazette',       group: 'reader',    icon: '📰', to: '/federacao/gazeta' },
  { id: 'profile',       group: 'reader',    icon: '🪪', to: '/conta?tab=perfil' },

  // ── Au comptoir et au catalogage ───────────────────────────────────
  { id: 'dayWork',       group: 'librarian', icon: '☀️', to: '/painel' },
  { id: 'reservations',  group: 'librarian', icon: '📥', to: '/painel/reservas' },
  { id: 'loansDesk',     group: 'librarian', icon: '🔁', to: '/painel/emprestimos' },
  { id: 'consultsDesk',  group: 'librarian', icon: '🪑', to: '/painel/consultas-locais' },
  { id: 'welcomeReader', group: 'librarian', icon: '🤝', to: '/painel/leitor' },
  { id: 'validate',      group: 'librarian', icon: '✅', to: '/painel/validacoes' },
  { id: 'recolement',    group: 'librarian', icon: '📋', to: '/painel/recolement' },
  { id: 'catalog',       group: 'librarian', icon: '📄', to: '/catalogacao#tab=booksPanel' },
  { id: 'authors',       group: 'librarian', icon: '✒️', to: '/catalogacao#tab=authorsPanel' },
  { id: 'subjects',      group: 'librarian', icon: '🗂️', to: '/catalogacao#tab=materiaPanel' },
  { id: 'labels',        group: 'librarian', icon: '🏷️', to: '/catalogacao#tab=labelsPanel' },
  { id: 'queue',         group: 'librarian', icon: '📨', to: '/catalogacao#tab=queuePanel' },
  { id: 'lots',          group: 'librarian', icon: '📦', to: '/catalogacao#tab=batchesPanel' },
  { id: 'duplicates',    group: 'librarian', icon: '🔀', to: '/catalogacao#tab=dedupPanel' },
  { id: 'periodicals',   group: 'librarian', icon: '🗞️', to: '/catalogacao#tab=periodicosPanel' },
  { id: 'workshop',      group: 'librarian', icon: '🛠️', to: '/atelier-autoridades#tab=obras' },

  // ── Coordonner ma bibliothèque ─────────────────────────────────────
  { id: 'loanRules',     group: 'coord',     icon: '⚖️', to: '/biblioteca#tab=regulation' },
  { id: 'identity',      group: 'coord',     icon: '🎨', to: '/biblioteca#tab=identity' },
  { id: 'comms',         group: 'coord',     icon: '📣', to: '/biblioteca#tab=comms' },
  { id: 'team',          group: 'coord',     icon: '👥', to: '/biblioteca#tab=team' },
  { id: 'transitions',   group: 'coord',     icon: '🔄', to: '/biblioteca#tab=transicoes' },
  { id: 'readers',       group: 'coord',     icon: '👤', to: '/biblioteca#tab=leitores' },
  { id: 'import',        group: 'coord',     icon: '📤', to: '/importacoes#tab=arquivo' },
  { id: 'export',        group: 'coord',     icon: '🎁', to: '/importacoes#tab=export' },
  { id: 'reviewRequest', group: 'coord',     icon: '🔎', to: '/catalogacao#tab=batchesPanel' },
  { id: 'eventsCoord',   group: 'coord',     icon: '🎪', to: '/biblioteca#tab=eventos' },
  { id: 'reports',       group: 'coord',     icon: '📊', to: '/biblioteca#tab=reports' },
  { id: 'ill',           group: 'coord',     icon: '🚚', to: '/biblioteca#tab=ill' },
  { id: 'tasks',         group: 'coord',     icon: '🧾', to: '/biblioteca#tab=tasks' },
  { id: 'assemblies',    group: 'coord',     icon: '🗣️', to: '/federacao/assembleias' },
  { id: 'circles',       group: 'coord',     icon: '🫂', to: '/federacao/circulos' },
  { id: 'communs',       group: 'coord',     icon: '🌱', to: '/federacao/communs' },

  // ── Administrer le réseau ──────────────────────────────────────────
  { id: 'welcomeLibrary', group: 'admin',    icon: '🏠', to: '/rede#tab=requests' },
  { id: 'invitations',   group: 'admin',     icon: '💌', to: '/rede#tab=invitations' },
  { id: 'reviewLots',    group: 'admin',     icon: '🧐', to: '/rede#tab=reviews' },
  { id: 'networkReports', group: 'admin',    icon: '📈', to: '/rede#tab=reports' },
  { id: 'gazetteAdmin',  group: 'admin',     icon: '🖨️', to: '/rede#tab=gazeta' },
  { id: 'lettre',        group: 'admin',     icon: '✉️', to: '/rede#tab=lettre' },
  { id: 'admins',        group: 'admin',     icon: '🔑', to: '/rede#tab=admins' },
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
