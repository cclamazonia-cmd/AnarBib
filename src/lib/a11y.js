// ═══════════════════════════════════════════════════════════════════════════
// AnarBib — préférences d'accessibilité
//
// Modèle de données + application au DOM, séparés du composant qui les pilote
// (AccessibilityWidget.jsx). Cette séparation a une raison précise : les
// préférences doivent être appliquées AVANT le premier rendu de React, sinon
// la page s'affiche une fraction de seconde en taille/contraste normaux avant
// de sauter aux réglages du lecteur — exactement le clignotement que ces
// réglages servent à éviter chez les personnes photosensibles. main.jsx appelle
// donc applyStoredPrefs() au chargement du module, hors de React.
//
// Mécanique : chaque préférence devient un attribut `data-a11y-*` sur <html>,
// et la feuille AccessibilityWidget.css réagit à ces attributs. Aucun style
// n'est écrit en JS : le CSS reste la source de vérité, et les règles restent
// inspectables dans le navigateur.
//
// ⚠️ Les surcharges de variables `--brand-*` (contraste, police) doivent porter
// `!important` DANS LE CSS : le ThemeLoader (lib/theme.js) pose les variables de
// marque en style INLINE sur <html>, et un style inline bat toute règle de
// feuille — sauf une déclaration `!important`. Sans ça, le contraste élevé
// serait sans effet sur les bibliothèques qui ont un thème.
// ═══════════════════════════════════════════════════════════════════════════

const STORAGE_KEY = 'anarbib.a11y';

// Paliers de taille du texte, en pourcentage de la taille de base du
// navigateur. 100 % = réglage du navigateur respecté (donc déjà la préférence
// système de la personne : on part de SA taille, pas de 16 px codés en dur).
// Plafond à 150 % : au-delà, les grilles du catalogage cassent, et le zoom
// natif du navigateur reste disponible pour aller plus loin.
export const TEXT_SCALES = [90, 100, 115, 130, 150];

export const DEFAULT_PREFS = {
  textScale: 100,
  contrast: false,
  readableFont: false,
  spacing: false,
  underlineLinks: false,
  bigCursor: false,
  reduceMotion: false,
  strongFocus: false,
};

// Correspondance préférence → attribut sur <html>. La valeur de l'attribut est
// portée par le tableau : elle décrit ce que fait le réglage, pour rester
// lisible dans l'inspecteur (`data-a11y-motion="off"` plutôt que `="true"`).
const FLAG_ATTRS = {
  contrast: ['data-a11y-contrast', 'on'],
  readableFont: ['data-a11y-font', 'readable'],
  spacing: ['data-a11y-spacing', 'on'],
  underlineLinks: ['data-a11y-links', 'underlined'],
  bigCursor: ['data-a11y-cursor', 'big'],
  reduceMotion: ['data-a11y-motion', 'off'],
  strongFocus: ['data-a11y-focus', 'strong'],
};

// Normalise n'importe quel objet venu du stockage vers la forme attendue.
// Défensif par construction : le localStorage peut contenir la version d'un
// déploiement précédent, ou une valeur bricolée à la main.
function normalize(raw) {
  const prefs = { ...DEFAULT_PREFS };
  if (!raw || typeof raw !== 'object') return prefs;
  if (TEXT_SCALES.includes(raw.textScale)) prefs.textScale = raw.textScale;
  for (const key of Object.keys(FLAG_ATTRS)) {
    prefs[key] = raw[key] === true;
  }
  return prefs;
}

// Lecture des préférences stockées. Tout accès au localStorage est gardé :
// en navigation privée (Safari) ou avec les cookies tiers bloqués, la simple
// lecture peut lever — et une exception ici empêcherait l'app de démarrer.
export function readPrefs() {
  try {
    return normalize(JSON.parse(window.localStorage.getItem(STORAGE_KEY)));
  } catch {
    return { ...DEFAULT_PREFS };
  }
}

export function writePrefs(prefs) {
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(prefs));
  } catch {
    // Stockage indisponible : les réglages valent pour la session en cours,
    // ce qui reste préférable à une erreur visible.
  }
}

// Applique les préférences au document. Idempotent : rappelable autant de fois
// que voulu, et remet à zéro ce qui n'est plus actif.
export function applyPrefs(prefs) {
  const root = document.documentElement;
  if (!root) return;

  // Taille du texte : une variable, consommée par la règle `html { font-size }`
  // d'AccessibilityWidget.css. Comme l'app dimensionne son texte en `rem`
  // (≈ 1 950 déclarations contre 15 en px), agir sur la racine suffit à tout
  // mettre à l'échelle, sans toucher une seule page.
  root.style.setProperty('--a11y-text-scale', `${prefs.textScale}%`);

  for (const [key, [attr, value]] of Object.entries(FLAG_ATTRS)) {
    if (prefs[key]) root.setAttribute(attr, value);
    else root.removeAttribute(attr);
  }
}

// Point d'entrée appelé par main.jsx, avant le rendu de React.
export function applyStoredPrefs() {
  applyPrefs(readPrefs());
}
