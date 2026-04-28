// =============================================================================
// AnarBib -- Country names helper
// =============================================================================
// Centralizes i18n-iso-countries locale registration and exposes utilities
// to get country names in the user's active locale.
//
// Importing this module from anywhere automatically registers all 6 locales
// (idempotent thanks to i18n-iso-countries internal dedup, safe to import
// from multiple files).
//
// Use cases:
//   - <CountrySelect> (forms) : getCountryNames() returns the full map
//   - AuthorPage / ReaderPage / etc. : getCountryName(input, locale) returns one
//
// getCountryName accepts EITHER an ISO 3166-1 alpha-2 code (e.g. 'BR')
// OR a textual name (e.g. 'Brasil', 'Brazil', 'Bresil'). This tolerance is
// needed for legacy data where country names were stored as text instead
// of ISO codes.
// =============================================================================

import countries from 'i18n-iso-countries';

import enLocale from 'i18n-iso-countries/langs/en.json';
import frLocale from 'i18n-iso-countries/langs/fr.json';
import esLocale from 'i18n-iso-countries/langs/es.json';
import ptLocale from 'i18n-iso-countries/langs/pt.json';
import itLocale from 'i18n-iso-countries/langs/it.json';
import deLocale from 'i18n-iso-countries/langs/de.json';

countries.registerLocale(enLocale);
countries.registerLocale(frLocale);
countries.registerLocale(esLocale);
countries.registerLocale(ptLocale);
countries.registerLocale(itLocale);
countries.registerLocale(deLocale);

/**
 * Manual mapping for legacy textual values that i18n-iso-countries
 * cannot recognize automatically (acronyms with dots, compound names,
 * historical entities, etc.).
 *
 * Add new entries here as they are encountered in the database.
 * Keys should match the EXACT textual value as stored in the DB.
 */
const LEGACY_NAME_MAP = {
  // Brazilian Portuguese acronyms
  'E.U.A.': 'US',
  'EUA': 'US',
  'EE.UU.': 'US',
  'U.R.S.S.': 'RU',  // Soviet Union -> Russia (closest successor)
  'URSS': 'RU',

  // Compound entries (pick first listed country)
  'Franca/Espanha': 'FR',
  'Franca / Espanha': 'FR',
  // The actual DB value uses the cedilla character; both forms below
  // catch it whether the source code is read as UTF-8 or fallback.
  // (See LEGACY_NAME_MAP_UNICODE below for the cedilla entries.)
};

// Same map but with proper Unicode characters (cedilla, accents).
// JS engine reads this file as UTF-8 so these keys match DB values literally.
const LEGACY_NAME_MAP_UNICODE = {
  'França/Espanha': 'FR',
  'França / Espanha': 'FR',
};

/**
 * Maps react-intl locales to i18n-iso-countries locale codes.
 * pt-BR uses Portuguese (pt) names, since i18n-iso-countries does not
 * distinguish pt-PT and pt-BR (country name differences are marginal).
 *
 * @param {string} intlLocale - react-intl locale (e.g. 'pt-BR', 'fr', 'en')
 * @returns {string} i18n-iso-countries locale code (e.g. 'pt', 'fr', 'en')
 */
export function intlToIsoLocale(intlLocale) {
  if (!intlLocale) return 'en';
  if (intlLocale.startsWith('pt')) return 'pt';
  return intlLocale.split('-')[0];
}

/**
 * Resolves an input value to an ISO 3166-1 alpha-2 code, or null if unrecognizable.
 * Accepts:
 *   - an ISO code directly (e.g. 'BR', 'br', 'IT')
 *   - a textual name in any of the 6 supported languages
 *   - a known legacy text name (cf. LEGACY_NAME_MAP)
 *
 * @param {string} input - country code or name
 * @returns {string|null} uppercase ISO code, or null if not resolvable
 */
function resolveToIsoCode(input) {
  if (!input || typeof input !== 'string') return null;
  const trimmed = input.trim();

  // 1. Looks like an ISO code already (2 letters)
  if (trimmed.length === 2 && /^[a-zA-Z]{2}$/.test(trimmed)) {
    const upper = trimmed.toUpperCase();
    // Validate: does i18n-iso-countries know this code?
    if (countries.getName(upper, 'en')) return upper;
    return null;
  }

  // 2. Manual legacy mapping (acronyms, compound names)
  if (LEGACY_NAME_MAP[trimmed]) return LEGACY_NAME_MAP[trimmed];
  if (LEGACY_NAME_MAP_UNICODE[trimmed]) return LEGACY_NAME_MAP_UNICODE[trimmed];

  // 3. Try i18n-iso-countries reverse lookup in all 6 supported languages.
  // We start with pt because the legacy database is in Brazilian Portuguese,
  // then try the others in case of mixed data.
  const tryLocales = ['pt', 'fr', 'en', 'es', 'it', 'de'];
  for (const loc of tryLocales) {
    const code = countries.getAlpha2Code(trimmed, loc);
    if (code) return code;
  }

  return null;
}

/**
 * Returns the localized name of a country given its ISO 3166-1 alpha-2 code
 * OR a textual name (in any supported language).
 *
 * @param {string} input - ISO code (e.g. 'BR') or textual name (e.g. 'Brasil')
 * @param {string} intlLocale - react-intl locale (e.g. 'pt-BR', 'fr')
 * @returns {string|null} Localized country name, or the input if not resolvable, or null if no input
 *
 * @example
 *   getCountryName('BR', 'fr')           // => 'Bresil'
 *   getCountryName('Brasil', 'fr')       // => 'Bresil' (legacy text input)
 *   getCountryName('Italia', 'de')       // => 'Italien' (legacy text input)
 *   getCountryName('E.U.A.', 'fr')       // => 'Etats-Unis' (legacy acronym)
 *   getCountryName('XX', 'en')           // => 'XX' (unknown, returns input)
 *   getCountryName(null, 'fr')           // => null
 */
export function getCountryName(input, intlLocale) {
  if (!input) return null;
  const isoLocale = intlToIsoLocale(intlLocale);

  const code = resolveToIsoCode(input);
  if (code) {
    return countries.getName(code, isoLocale, { select: 'official' }) || input;
  }

  // Fallback: return input as-is if we can't resolve it
  return input;
}

/**
 * Returns all country names in the given locale, as a {code: name} object.
 * Used by <CountrySelect> to build the dropdown options.
 *
 * @param {string} intlLocale - react-intl locale
 * @returns {Object} Map of ISO code (e.g. 'BR') to localized name (e.g. 'Brasil')
 */
export function getCountryNames(intlLocale) {
  const isoLocale = intlToIsoLocale(intlLocale);
  return countries.getNames(isoLocale, { select: 'official' });
}
