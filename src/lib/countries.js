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
//   - AuthorPage / ReaderPage / etc. : getCountryName(code, locale) returns one
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
 * Returns the localized name of a country given its ISO 3166-1 alpha-2 code.
 * Falls back to the code itself if the country is not found.
 *
 * @param {string} isoCode - ISO 3166-1 alpha-2 country code (e.g. 'BR', 'FR')
 * @param {string} intlLocale - react-intl locale (e.g. 'pt-BR', 'fr')
 * @returns {string|null} Localized country name, or the code if not found, or null if no isoCode
 *
 * @example
 *   getCountryName('BR', 'fr')    // => 'Bresil'
 *   getCountryName('BR', 'pt-BR') // => 'Brasil'
 *   getCountryName('XX', 'en')    // => 'XX' (unknown code, returns code itself)
 *   getCountryName(null, 'fr')    // => null
 */
export function getCountryName(isoCode, intlLocale) {
  if (!isoCode) return null;
  const isoLocale = intlToIsoLocale(intlLocale);
  return countries.getName(isoCode, isoLocale, { select: 'official' }) || isoCode;
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
