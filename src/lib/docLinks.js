// src/lib/docLinks.js
//
// Quel document, à quelle page, pour quelle page de l'app (05/09/2026).
//
// Les trois PDF publiés (manuel complet, manuel de la·du lecteur·rice, guide
// de gouvernance) sont des recueils à dix langues, sans signets. Jusqu'ici
// chaque page de l'app ouvrait le PDF à la couverture, dans la langue du
// premier recueil. Ici : la langue de la personne et le BLOC qui correspond à
// ce que la page permet, par l'ancre `#page=N` que tout navigateur comprend.
//
// Les numéros sont ceux des PDF publiés le 01-03/09/2026 dans
// library-ui-assets/manuals/network/published/ — sauf le manuel de la·du
// lecteur·rice, republié le 13/10/2026 (B42, chapitre 24 « double
// authentification », pages remesurées dans le PDF publié). Republier un recueil avec
// une pagination différente impose de relever à nouveau cette table :
// src/tests/doc-links.test.js garde au moins la forme (dix langues, blocs
// croissants), pas les valeurs.

import { SUPABASE_URL } from './supabase';

export const DOC_BASE =
  `${SUPABASE_URL}/storage/v1/object/public/library-ui-assets/manuals/network/published/`;

export const DOC_FILES = {
  reader: 'Manual%20Leitor-a-e.pdf',
  complete: 'Manual_do_AnarBib.pdf',
  governance: 'Guia_de_governanca_AnarBib.pdf',
};

// Manuel complet — page PDF où commence chaque bloc (0 à 9), par langue.
// 0 Commencer · 1 Catalogue public · 2 Compte · 3 Qui peut quoi · 4 Panneau
// 5 Catalogage et importations · 6 Bibliothèque · 7 Fédération · 8 Réseau · 9 Règles d'or
// Remesuré le 14/10/2026 (B42 : double authentification aux chapitres 25 et 113) dans le PDF publié,
// couverture multilingue comprise (page PDF = numéro de pied + 1).
export const COMPLETE_BLOCKS = {
  'pt-BR': [6, 11, 20, 32, 35, 45, 62, 70, 81, 87],
  fr:      [93, 98, 107, 120, 124, 134, 152, 160, 171, 178],
  de:      [184, 189, 199, 212, 216, 226, 246, 254, 265, 273],
  en:      [279, 284, 293, 305, 308, 317, 335, 343, 354, 360],
  es:      [366, 371, 380, 393, 396, 406, 424, 432, 443, 449],
  it:      [455, 460, 469, 482, 485, 495, 513, 521, 532, 538],
  ca:      [544, 549, 558, 571, 574, 583, 600, 608, 619, 625],
  nl:      [631, 636, 646, 659, 663, 673, 692, 700, 711, 718],
  el:      [724, 729, 740, 753, 757, 767, 787, 795, 806, 814],
  eo:      [820, 825, 834, 846, 849, 858, 875, 883, 894, 900],
};

// Manuel de la·du lecteur·rice — page de titre de chaque langue et décalage
// de chaque section. Depuis le 13/10/2026 (B42) : 19 pages par langue (le
// chapitre 24, « double authentification », a sa propre page en fin de
// langue, sans rien déplacer avant lui), dans l'ordre du docx v5 :
// …, ca, nl, el, eo (l'ancien PDF avait eo avant nl et el).
export const READER_START = {
  'pt-BR': 3, fr: 22, de: 41, en: 60, es: 79, it: 98, ca: 117, nl: 136, el: 155, eo: 174,
};
export const READER_SECTIONS = {
  start: 0,        // « Le manuel complet existe pour… » — la porte d'entrée
  catalogue: 2,    // chercher un livre, une autorité, un thème ; la fiche
  libraries: 6,    // les bibliothèques du réseau et la carte
  account: 9,      // entrer, mot de passe, « Mon compte »
  myLibraries: 10, // appartenir à plus d'une bibliothèque
  card: 11,        // carte de lecteur·rice
  notices: 12,     // avis, cloche, bulletin, gazette
  reserve: 13,     // réserver un livre, convenir du retrait
  loans: 15,       // emprunts : délais, renouvellement, retour
  notes: 16,       // notes de lecture et événements
  twoFactor: 18,   // protéger son compte : la double authentification (B42)
};
// La maquette n'est pas tout à fait la même partout : mesuré le 13/10/2026 dans
// le PDF publié, le grec et l'espéranto ont quelques chapitres une page plus
// loin (ou plus tôt). Ces écarts existaient déjà dans le PDF du 03/09 ; les
// liens tombaient alors une page à côté.
export const READER_SECTION_EXCEPTIONS = {
  el: { myLibraries: 11, card: 12, reserve: 14 },
  eo: { notes: 15 },
};

// Guide de gouvernance — page de titre de chaque langue.
export const GOVERNANCE_START = {
  fr: 2, 'pt-BR': 85, es: 140, it: 195, en: 250, de: 304, ca: 363, eo: 417, nl: 470, el: 527,
};

const FALLBACK_LOCALE = 'pt-BR';

function pick(table, locale) {
  if (locale && table[locale] !== undefined) return table[locale];
  const short = (locale || '').split('-')[0];
  if (short && table[short] !== undefined) return table[short];
  return table[FALLBACK_LOCALE];
}

export function completeManualUrl(locale, block) {
  const pages = pick(COMPLETE_BLOCKS, locale);
  const page = Number.isInteger(block) && pages[block] ? pages[block] : pages[0];
  return `${DOC_BASE}${DOC_FILES.complete}#page=${page}`;
}

export function readerManualUrl(locale, section = 'start') {
  const start = pick(READER_START, locale);
  const exceptions = pick(READER_SECTION_EXCEPTIONS, locale) ?? {};
  const offset = exceptions[section] ?? READER_SECTIONS[section] ?? 0;
  return `${DOC_BASE}${DOC_FILES.reader}#page=${start + offset}`;
}

export function governanceGuideUrl(locale) {
  return `${DOC_BASE}${DOC_FILES.governance}#page=${pick(GOVERNANCE_START, locale)}`;
}

// Lit l'onglet courant quelle que soit la convention de la page :
// ?tab= (Mon compte), #tab= (Catalogage, Réseau, Bibliothèque, Importations),
// /page/:tab (Fédération, Panneau).
export function currentTab(pathname, search = '', hash = '') {
  const h = (hash || '').replace(/^#/, '');
  const hm = h.match(/(?:^|&)tab=([^&]+)/);
  if (hm) return decodeURIComponent(hm[1]);
  const sm = (search || '').match(/[?&]tab=([^&]+)/);
  if (sm) return decodeURIComponent(sm[1]);
  const pm = (pathname || '').match(/^\/(federacao|painel)\/([^/]+)/);
  if (pm) return pm[2];
  return null;
}

const READER_TAB_SECTION = {
  perfil: 'account', reservar: 'reserve', curso: 'loans', historico: 'loans',
  avisos: 'notices', desejos: 'catalogue', notas: 'notes', eventos: 'notes', biblios: 'myLibraries',
};

/**
 * Ce que le hero d'une page doit proposer.
 * @returns {{ reader: string|null, complete: number|null, governance: boolean, communs: string[] }}
 *   reader     : section du manuel lecteur·rice (clé de READER_SECTIONS) ou null
 *   complete   : bloc du manuel complet (0-9) ou null — réservé au staff
 *   governance : guide de gouvernance
 *   communs    : identifiants de documents des Communs (vade-mecums) à proposer
 */
export function docsForLocation({ pathname = '/', search = '', hash = '', isStaff = false } = {}) {
  const path = pathname || '/';
  const tab = currentTab(path, search, hash);
  const none = { reader: null, complete: null, governance: false, communs: [] };

  // ── Lectorat : le scope prime sur le rôle ──
  if (path === '/' || path.startsWith('/catalogo') || path.startsWith('/catálogo')
      || path.startsWith('/livro/') || path.startsWith('/obra/') || path.startsWith('/autor/')
      || path.startsWith('/periodico/') || path.startsWith('/thesaurus')) {
    return { ...none, reader: 'catalogue' };
  }
  if (path === '/bibliotecas' || path.startsWith('/bibliotecas/')
      || path === '/cartografia' || path === '/cartografia/ajouter') {
    return { ...none, reader: 'libraries' };
  }
  if (path.startsWith('/conta')) {
    return { ...none, reader: READER_TAB_SECTION[tab] || 'account' };
  }

  // ── Réseau : guide de gouvernance pour qui y entre, manuel bloc 8 pour le staff ──
  if (path.startsWith('/rede')) {
    return { ...none, complete: isStaff ? 8 : null, governance: true };
  }

  if (!isStaff) return none;

  // ── Staff : politique (manuel + guide) ──
  if (path.startsWith('/painel')) return { ...none, complete: 4, governance: true };
  if (path.startsWith('/biblioteca')) return { ...none, complete: 6, governance: true };
  if (path.startsWith('/federacao')) return { ...none, complete: 7, governance: true };
  if (path === '/atelier' || path.startsWith('/atelier/')) return { ...none, complete: 8, governance: true };
  if (path.startsWith('/solicitar-biblioteca')) return { ...none, complete: 8, governance: true };
  if (path.startsWith('/cartografia/moderacao')) return { ...none, complete: 7 };

  // ── Staff : technique (manuel + vade-mecums des Communs) ──
  if (path.startsWith('/catalogacao') || path.startsWith('/catalogção')) {
    const communs = ['guide-conventions'];
    if (tab === 'materiaPanel' || tab === 'indexPanel') communs.push('guide-indexar');
    if (tab === 'ocrPanel') communs.push('guide-scan', 'guide-numerisation');
    if (tab === 'labelsPanel') communs.push('cotation');
    return { ...none, complete: 5, communs };
  }
  if (path.startsWith('/atelier-autoridades')) return { ...none, complete: 5, communs: ['guide-conventions'] };
  if (path.startsWith('/importacoes') || path.startsWith('/importações')) {
    return { ...none, complete: 5 };
  }
  return none;
}

export function communsDocUrl(docId) {
  return `/federacao/communs?doc=${encodeURIComponent(docId)}`;
}
