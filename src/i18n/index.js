// ═══════════════════════════════════════════════════════════
// AnarBib — i18n
// Architecture multilingue avec react-intl.
// Le portugais du Brésil est la locale par défaut.
//
// Chargement : pt-BR est embarqué statiquement (défaut + fallback,
// toujours disponible immédiatement). Les 7 autres langues sont chargées
// à la demande via import() dynamique — Vite produit un chunk par langue,
// et chaque visiteur ne télécharge que la sienne.
// ═══════════════════════════════════════════════════════════

import ptBR from './locales/pt-BR.json';

export const DEFAULT_LOCALE = 'pt-BR';

// Liste des locales supportées.
// Décision politique acta-anarchiste (paquet 21, 2026-05-11) :
// - Pas de drapeaux d'États (un drapeau, même combiné, reste un drapeau d'État)
// - Pas de codes d'État (« PT », « FR », « ES », « GB », « IT », « DE »)
// - Chaque langue s'affiche dans son propre nom, dans sa propre langue
// Le code BCP 47 (`code`) reste inchangé : c'est l'identifiant technique
// stocké en DB (profile.preferred_language, library.default_locale).
export const SUPPORTED_LOCALES = [
  { code: 'pt-BR', label: 'Português' },
  { code: 'fr', label: 'Français' },
  { code: 'es', label: 'Castellano' },
  { code: 'en', label: 'English' },
  { code: 'it', label: 'Italiano' },
  { code: 'de', label: 'Deutsch' },
  { code: 'ca', label: 'Català' },
  { code: 'eo', label: 'Esperanto' },
];

// Source de vérité des codes supportés (remplace l'ancien map MESSAGES,
// qui importait toutes les langues statiquement).
const SUPPORTED_CODES = new Set(SUPPORTED_LOCALES.map((l) => l.code));

// Chargeurs dynamiques des langues non-défaut. pt-BR n'y figure pas :
// il est embarqué statiquement ci-dessus (fallback immédiat, sans réseau).
const LOADERS = {
  fr: () => import('./locales/fr.json'),
  es: () => import('./locales/es.json'),
  en: () => import('./locales/en.json'),
  it: () => import('./locales/it.json'),
  de: () => import('./locales/de.json'),
  ca: () => import('./locales/ca.json'),
  eo: () => import('./locales/eo.json'),
};

const STORAGE_KEY = 'anarbib.locale';
const SCROLL_RESTORE_KEY = 'anarbib.scrollRestore';

// Messages de la locale par défaut, disponibles synchroniquement.
export const defaultMessages = ptBR;

// Charge les messages d'une locale.
// pt-BR (ou toute locale inconnue) est retourné immédiatement ; les autres
// sont importées à la demande, avec repli sur pt-BR si le chunk échoue.
export async function loadMessages(locale) {
  if (locale === DEFAULT_LOCALE || !LOADERS[locale]) return ptBR;
  try {
    const mod = await LOADERS[locale]();
    return mod.default;
  } catch {
    return ptBR;
  }
}

export function isSupported(locale) {
  return Boolean(locale && SUPPORTED_CODES.has(locale));
}

export function detectLocale() {
  // 1. URL param ?lang=xx
  try {
    const url = new URL(window.location.href);
    const param = url.searchParams.get('lang');
    if (isSupported(param)) return param;
  } catch {
    // ignore (SSR, etc.)
  }

  // 2. localStorage
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (isSupported(stored)) return stored;
  } catch {
    // ignore (privacy mode, etc.)
  }

  // 3. Navigateur (match partiel: pt → pt-BR, fr-FR → fr)
  try {
    const codes = SUPPORTED_LOCALES.map((l) => l.code);
    const navLangs = navigator.languages || [navigator.language];
    for (const lang of navLangs) {
      if (isSupported(lang)) return lang;
      const short = (lang || '').split('-')[0];
      const match = codes.find((k) => k.startsWith(short));
      if (match) return match;
    }
  } catch {
    // ignore
  }

  return DEFAULT_LOCALE;
}

// ── Restauration de la position scroll au reload ───────────
//
// Quand on change de langue, on est obligés de reload la page (react-intl
// ne sait pas changer de messages dynamiquement sans remount). Pour éviter
// que l'utilisateur perde sa place dans la page, on sauvegarde scroll +
// hash dans sessionStorage avant le reload, et on les restaure au mount.

function saveScrollState() {
  try {
    const state = {
      scrollY: window.scrollY,
      scrollX: window.scrollX,
      hash: window.location.hash,
      pathname: window.location.pathname,
      search: window.location.search,
      timestamp: Date.now(),
    };
    sessionStorage.setItem(SCROLL_RESTORE_KEY, JSON.stringify(state));
  } catch {
    // ignore
  }
}

export function consumeScrollRestore() {
  try {
    const raw = sessionStorage.getItem(SCROLL_RESTORE_KEY);
    if (!raw) return null;
    sessionStorage.removeItem(SCROLL_RESTORE_KEY);
    const state = JSON.parse(raw);
    // N'accepte que si récent (< 5 secondes) et même URL
    if (Date.now() - state.timestamp > 5000) return null;
    if (state.pathname !== window.location.pathname) return null;
    return state;
  } catch {
    return null;
  }
}

// Appelé une seule fois au démarrage de l'app pour restaurer le scroll.
export function applyScrollRestoreIfAny() {
  const state = consumeScrollRestore();
  if (!state) return;
  // Différer pour laisser le rendu initial se faire
  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      window.scrollTo(state.scrollX || 0, state.scrollY || 0);
    });
  });
}

// ── Setters ────────────────────────────────────────────────

// Changement "soft" de locale : sauvegarde scroll + reload.
export function setLocale(locale) {
  if (!isSupported(locale)) return;
  try {
    localStorage.setItem(STORAGE_KEY, locale);
  } catch {
    // ignore
  }
  saveScrollState();
  window.location.reload();
}

// Synchronise la locale stockée localement avec celle du profil utilisateur.
// Appelée au login depuis AuthContext. Si la locale stockée diffère de
// celle du profil, on aligne sur le profil (autorité = base) puis on reload
// avec restoration de scroll.
//
// Retourne true si un reload a été déclenché, false sinon.
export function syncLocaleFromProfile(profileLanguage) {
  if (!isSupported(profileLanguage)) return false;
  let stored = null;
  try {
    stored = localStorage.getItem(STORAGE_KEY);
  } catch {
    // ignore
  }
  if (stored === profileLanguage) return false;
  try {
    localStorage.setItem(STORAGE_KEY, profileLanguage);
  } catch {
    // ignore
  }
  saveScrollState();
  window.location.reload();
  return true;
}
