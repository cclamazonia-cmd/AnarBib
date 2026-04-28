// =============================================================================
// AnarBib -- CountrySelect
// =============================================================================
// Hybrid country selector:
//   1. Priority countries on top (cf. countryData.PRIORITY_COUNTRIES)
//   2. Visual separator
//   3. All other countries in alphabetical order
//
// Country names are localized via i18n-iso-countries in the active locale.
// Locale registration is handled by the central @/lib/countries helper.
//
// Stored value: ISO 3166-1 alpha-2 code (e.g. 'BR', 'FR', 'AR').
// =============================================================================

import { useMemo } from 'react';
import { useIntl } from 'react-intl';

// Importing this helper auto-registers all 6 locales for i18n-iso-countries.
// See src/lib/countries.js for details.
import { getCountryNames } from '@/lib/countries';

import { PRIORITY_COUNTRIES } from './countryData';

export default function CountrySelect({
  value,
  onChange,
  required = false,
  disabled = false,
  style = {},
  id,
  name,
  ariaLabel,
}) {
  const { locale, formatMessage } = useIntl();

  /**
   * Builds the option list in two groups:
   * priority (in PRIORITY_COUNTRIES order) then all others
   * sorted alphabetically in the active language.
   */
  const { priorityOptions, otherOptions } = useMemo(() => {
    const allCountries = getCountryNames(locale);
    // allCountries = { 'BR': 'Brasil', 'FR': 'Franca', ... }
    const prioritySet = new Set(PRIORITY_COUNTRIES);

    const priority = PRIORITY_COUNTRIES
      .filter(code => allCountries[code])
      .map(code => ({ code, name: allCountries[code] }));

    const others = Object.entries(allCountries)
      .filter(([code]) => !prioritySet.has(code))
      .map(([code, name]) => ({ code, name }))
      .sort((a, b) => a.name.localeCompare(b.name, locale));

    return { priorityOptions: priority, otherOptions: others };
  }, [locale]);

  const placeholder = formatMessage({ id: 'address.country.placeholder' });
  const separatorLabel = formatMessage({ id: 'address.country.separator' });

  return (
    <select
      id={id}
      name={name}
      value={value || ''}
      onChange={e => onChange(e.target.value)}
      required={required}
      disabled={disabled}
      style={style}
      aria-label={ariaLabel || formatMessage({ id: 'address.country' })}
    >
      <option value="">{placeholder}</option>

      {/* Priority countries */}
      <optgroup label={formatMessage({ id: 'address.country.priority' })}>
        {priorityOptions.map(({ code, name }) => (
          <option key={`p-${code}`} value={code}>
            {name}
          </option>
        ))}
      </optgroup>

      {/* All other countries */}
      <optgroup label={separatorLabel}>
        {otherOptions.map(({ code, name }) => (
          <option key={code} value={code}>
            {name}
          </option>
        ))}
      </optgroup>
    </select>
  );
}
