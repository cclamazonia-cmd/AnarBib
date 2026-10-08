// src/pages/biblioteca/ReadLanguagesField.jsx — G19 lot 4 (08/10/2026)
//
// « Les langues que notre équipe lit » : une case par locale, dans l'onglet
// Identité de la page Bibliothèque. Déclaration de l'équipe par sa
// coordination ; l'onglet Correspondance la montre à qui écrit à cette
// bibliothèque et propose une langue commune — il n'y a pas de traduction
// automatique (REGISTRE CORR-3). Chaque langue se nomme dans sa propre langue,
// sans drapeau ni code d'État (même règle que LocaleSelector).
import { useIntl } from 'react-intl';
import { SUPPORTED_LOCALES } from '@/i18n';

export default function ReadLanguagesField({ value, onChange, disabled = false }) {
  const { formatMessage: t } = useIntl();
  const choisies = Array.isArray(value) ? value : [];
  const basculer = (code) => {
    const suivantes = choisies.includes(code) ? choisies.filter((c) => c !== code) : [...choisies, code];
    onChange?.(SUPPORTED_LOCALES.map((l) => l.code).filter((c) => suivantes.includes(c)));   // l'ordre canonique, sans doublon
  };
  return (
    <fieldset className="ab-read-languages" style={{ border: 'none', padding: 0, margin: 0, gridColumn: 'span 2' }}>
      <legend style={{ fontSize: '.85rem', fontWeight: 600, marginBottom: 3, color: 'var(--brand-muted, #ccc)' }}>
        {t({ id: 'biblioteca.identity.readLanguages' })}
      </legend>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px 14px' }}>
        {SUPPORTED_LOCALES.map((l) => (
          <label key={l.code} lang={l.code} style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: '.9rem' }}>
            <input type="checkbox" checked={choisies.includes(l.code)} disabled={disabled} onChange={() => basculer(l.code)} />
            {l.label}
          </label>
        ))}
      </div>
      <p style={{ fontSize: '.8rem', opacity: .75, margin: '6px 0 0' }}>{t({ id: 'biblioteca.identity.readLanguagesHelp' })}</p>
    </fieldset>
  );
}
