// ═══════════════════════════════════════════════════════════
// AnarBib — i18n
// Architecture multilingue avec react-intl.
// Le portugais du Brésil est la locale par défaut.
// ═══════════════════════════════════════════════════════════

import ptBR from './locales/pt-BR.json';
import fr from './locales/fr.json';
import es from './locales/es.json';
import en from './locales/en.json';
import it from './locales/it.json';
import de from './locales/de.json';

export const DEFAULT_LOCALE = 'pt-BR';

export const SUPPORTED_LOCALES = [
  { code: 'pt-BR', label: 'Português', flag: '🇧🇷🇵🇹' },
  { code: 'fr', label: 'Français', flag: '🇫🇷' },
  { code: 'es', label: 'Castellano', flag: '🇪🇸' },
  { code: 'en', label: 'English', flag: '🇬🇧' },
  { code: 'it', label: 'Italiano', flag: '🇮🇹' },
  { code: 'de', label: 'Deutsch', flag: '🇩🇪' },
];

const MESSAGES = {
  'pt-BR': ptBR,
  'fr': fr,
  'es': es,
  'en': en,
  'it': it,
  'de': de,
};

export function getMessages(locale) {
  return MESSAGES[locale] || MESSAGES[DEFAULT_LOCALE];
}

export function detectLocale() {
  // 1. URL param ?lang=xx
  const url = new URL(window.location.href);
  const param = url.searchParams.get('lang');
  if (param && MESSAGES[param]) return param;

  // 2. localStorage
  try {
    const stored = localStorage.getItem('anarbib.locale');
    if (stored && MESSAGES[stored]) return stored;
  } catch {
    // ignore
  }

  // 3. Navigateur (match partiel: pt → pt-BR, fr-FR → fr)
  const navLangs = navigator.languages || [navigator.language];
  for (const lang of navLangs) {
    if (MESSAGES[lang]) return lang;
    const short = lang.split('-')[0];
    const match = Object.keys(MESSAGES).find(k => k.startsWith(short));
    if (match) return match;
  }

  return DEFAULT_LOCALE;
}

export function setLocale(locale) {
  try {
    localStorage.setItem('anarbib.locale', locale);
  } catch {
    // ignore
  }
  // Reload to apply the new locale throughout the app
  window.location.reload();
}
