// ═══════════════════════════════════════════════════════════
// AnarBib — PhoneInput
// ───────────────────────────────────────────────────────────
// Wrapper autour de react-phone-number-input qui :
//   - Affiche un dropdown pays (drapeau + indicatif international)
//   - Sépare visuellement l'indicatif (+33, +55, +49…) du numéro local
//   - Stocke la valeur au format E.164 (ex: '+5511999999999')
//   - Pré-sélectionne le pays selon la langue active (heuristique
//     simple : pt-BR → BR, fr → FR, es → ES, etc.) si countryCode
//     n'est pas fourni.
//   - Valide à la volée et signale visuellement les numéros invalides
//
// Référence : https://gitlab.com/catamphetamine/react-phone-number-input
// ═══════════════════════════════════════════════════════════

import { useIntl } from 'react-intl';
import PhoneInputBase, { isValidPhoneNumber } from 'react-phone-number-input';
import 'react-phone-number-input/style.css';

/**
 * Heuristique simple : à partir de la locale react-intl,
 * deviner un pays par défaut pour le composant téléphone.
 * Permet d'éviter à l'utilisateur·rice de sélectionner manuellement
 * son pays dans le cas le plus fréquent.
 */
function defaultCountryFromLocale(locale) {
  const map = {
    'pt-BR': 'BR',
    'pt': 'PT',
    'fr': 'FR',
    'es': 'ES',
    'en': 'US',
    'it': 'IT',
    'de': 'DE',
  };
  return map[locale] || map[locale.split('-')[0]] || undefined;
}

export default function PhoneInput({
  value,
  onChange,
  countryCode,
  required = false,
  disabled = false,
  style = {},
  id,
  name,
  ariaLabel,
}) {
  const { locale, formatMessage } = useIntl();

  // Si countryCode est fourni explicitement (formulaire avec champ pays
  // séparé), l'utiliser. Sinon, deviner depuis la locale.
  const defaultCountry = countryCode || defaultCountryFromLocale(locale);

  const isInvalid = value && !isValidPhoneNumber(value);

  return (
    <div className="anarbib-phone-input-wrapper" style={{ ...style }}>
      <PhoneInputBase
        id={id}
        name={name}
        international
        countryCallingCodeEditable={false}
        defaultCountry={defaultCountry}
        value={value}
        onChange={onChange}
        disabled={disabled}
        aria-label={ariaLabel || formatMessage({ id: 'auth.create.phone' })}
        aria-invalid={isInvalid || undefined}
        aria-required={required || undefined}
        // Placeholder traduit pour le numéro (l'indicatif est géré par le drapeau)
        placeholder={formatMessage({ id: 'address.phone.placeholder' })}
      />
      {isInvalid && (
        <div
          className="anarbib-phone-input-error"
          style={{
            fontSize: '.78rem',
            color: '#f87171',
            marginTop: 4,
          }}
        >
          {formatMessage({ id: 'address.phone.invalid' })}
        </div>
      )}
    </div>
  );
}

// Re-export pour usage externe (validation côté formulaire avant submit)
export { isValidPhoneNumber };
