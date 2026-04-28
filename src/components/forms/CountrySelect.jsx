// ═══════════════════════════════════════════════════════════
// AnarBib — CountrySelect
// ───────────────────────────────────────────────────────────
// Sélecteur de pays hybride :
//   1. Pays prioritaires en haut (cf. countryData.PRIORITY_COUNTRIES)
//   2. Séparateur visuel
//   3. Tous les autres pays par ordre alphabétique
//
// Les noms de pays sont localisés via i18n-iso-countries dans la
// langue active de react-intl.
//
// Valeur stockée : code ISO 3166-1 alpha-2 (ex: 'BR', 'FR', 'AR').
// ═══════════════════════════════════════════════════════════

import { useMemo } from 'react';
import { useIntl } from 'react-intl';
import countries from 'i18n-iso-countries';

// Locales chargées au démarrage. Si une nouvelle langue est ajoutée
// au projet, l'enregistrer ici.
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

import { PRIORITY_COUNTRIES } from './countryData';

/**
 * Map les locales react-intl vers les codes locales i18n-iso-countries.
 * pt-BR utilise les noms portugais (pt) car i18n-iso-countries ne distingue
 * pas pt-PT et pt-BR — les différences de noms de pays sont marginales.
 */
function intlToIsoLocale(intlLocale) {
  if (intlLocale.startsWith('pt')) return 'pt';
  return intlLocale.split('-')[0];
}

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
  const isoLocale = intlToIsoLocale(locale);

  /**
   * Construit la liste des options en deux groupes :
   * prioritaires (dans l'ordre PRIORITY_COUNTRIES) puis tous les autres
   * triés alphabétiquement dans la langue active.
   */
  const { priorityOptions, otherOptions } = useMemo(() => {
    const allCountries = countries.getNames(isoLocale, { select: 'official' });
    // allCountries = { 'BR': 'Brasil', 'FR': 'França', ... }
    const prioritySet = new Set(PRIORITY_COUNTRIES);

    const priority = PRIORITY_COUNTRIES
      .filter(code => allCountries[code])
      .map(code => ({ code, name: allCountries[code] }));

    const others = Object.entries(allCountries)
      .filter(([code]) => !prioritySet.has(code))
      .map(([code, name]) => ({ code, name }))
      .sort((a, b) => a.name.localeCompare(b.name, isoLocale));

    return { priorityOptions: priority, otherOptions: others };
  }, [isoLocale]);

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

      {/* Pays prioritaires */}
      <optgroup label={formatMessage({ id: 'address.country.priority' })}>
        {priorityOptions.map(({ code, name }) => (
          <option key={`p-${code}`} value={code}>
            {name}
          </option>
        ))}
      </optgroup>

      {/* Tous les autres pays */}
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
