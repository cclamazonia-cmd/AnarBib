// ═══════════════════════════════════════════════════════════
// AnarBib — StateSelect
// ───────────────────────────────────────────────────────────
// Sélecteur d'état/province adaptatif au pays :
//   - Si le pays a une liste fermée définie (BR, FR, ES, IT, DE, AR, MX, CH),
//     affiche un <select> avec les noms locaux des subdivisions.
//   - Sinon, retombe sur un <input type="text"> libre.
//
// Le composant remplace transparemment les deux modes selon countryCode.
// ═══════════════════════════════════════════════════════════

import { useIntl } from 'react-intl';
import { STATES_BY_COUNTRY, hasStatesList } from './countryData';

export default function StateSelect({
  countryCode,
  value,
  onChange,
  required = false,
  disabled = false,
  style = {},
  id,
  name,
  ariaLabel,
}) {
  const { formatMessage } = useIntl();
  const list = STATES_BY_COUNTRY[countryCode];

  // Pas de pays sélectionné → input désactivé pour signaler la dépendance.
  if (!countryCode) {
    return (
      <input
        type="text"
        value={value || ''}
        onChange={e => onChange(e.target.value)}
        disabled
        placeholder={formatMessage({ id: 'address.state.selectCountryFirst' })}
        style={style}
        id={id}
        name={name}
        aria-label={ariaLabel}
      />
    );
  }

  // Pays sans liste fermée → input texte libre.
  if (!hasStatesList(countryCode)) {
    return (
      <input
        type="text"
        value={value || ''}
        onChange={e => onChange(e.target.value)}
        required={required}
        disabled={disabled}
        placeholder={formatMessage({ id: 'address.state.placeholder.generic' })}
        style={style}
        id={id}
        name={name}
        aria-label={ariaLabel}
      />
    );
  }

  // Pays avec liste fermée → dropdown.
  return (
    <select
      id={id}
      name={name}
      value={value || ''}
      onChange={e => onChange(e.target.value)}
      required={required}
      disabled={disabled}
      style={style}
      aria-label={ariaLabel}
    >
      <option value="">
        {formatMessage({ id: 'address.state.placeholder' })}
      </option>
      {list.map(({ code, name }) => (
        <option key={code} value={code}>
          {name}
        </option>
      ))}
    </select>
  );
}
