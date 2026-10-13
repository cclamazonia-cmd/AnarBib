import { useIntl } from 'react-intl';
import { LOCALES, DEFAULT_LOCALE } from '@/i18n/locales';

// ─────────────────────────────────────────────────────────────
// LocaleSelector — composant de sélection de la locale d'une biblio
// ─────────────────────────────────────────────────────────────
// Paquet 6.3 (2026-05-09) — sélecteur de la langue d'identité de la biblio.
//
// Décision politique acta-anarchiste :
// - Pas de drapeaux (pas d'États dans un projet anarchiste)
// - Pas de codes d'État (« ES », « GB », « FR »)
// - Chaque langue s'affiche dans son propre nom, dans sa propre langue
//
// Les options viennent de src/i18n/locales.js (DOC-I18N-4). Jusqu'au
// 13/10/2026 le composant gardait sa propre liste, restée à six langues
// (pt-BR, de, en, es, fr, it) : une bibliothèque ne pouvait pas choisir ca,
// eo, nl ni el comme langue par défaut, alors que l'app les sert depuis juin.
// libraries.default_locale n'a pas de contrainte CHECK en base.
//
// Le composant est volontairement minimal : juste un <select> natif HTML
// avec les options. Pas d'autocomplete, pas de search, pas de drapeaux.
// Une langue nouvelle s'ajoute dans src/i18n/locales.js, pas ici.
//
// Props :
//   - value      : code locale actuel (ex: 'pt-BR'), peut être null/undefined
//   - onChange   : callback (newLocale: string) => void
//   - disabled   : optionnel, désactive le select
//   - className  : optionnel, classe CSS du select pour styling parent
//   - style      : optionnel, style inline du select
//
// Usage :
//   <LocaleSelector
//     value={lib.default_locale}
//     onChange={loc => setL('default_locale', loc)}
//     style={fs}
//   />
// ─────────────────────────────────────────────────────────────

// Liste des locales supportées par AnarBib.
// Ordre : pt-BR (langue de référence) en tête, puis ordre alphabétique
// des codes BCP 47.
//
// L'option `name` est le nom de la langue dans sa propre langue.
// Pas de drapeau, pas de code pays/État dans le label visible.
export const LOCALE_OPTIONS = [
  ...LOCALES.filter((l) => l.code === DEFAULT_LOCALE),
  ...LOCALES.filter((l) => l.code !== DEFAULT_LOCALE).sort((a, b) => a.code.localeCompare(b.code)),
].map(({ code, label }) => ({ code, name: label }));

export default function LocaleSelector({ value, onChange, disabled = false, className, style }) {
  const { formatMessage: t } = useIntl();
  const current = value || 'pt-BR';
  // Si la valeur ne correspond à aucune option connue (ex: locale ajoutée en
  // DB mais pas encore dans le composant), on l'affiche quand même via une
  // option « ghost » pour ne pas la perdre silencieusement au prochain save.
  const isKnown = LOCALE_OPTIONS.some(opt => opt.code === current);
  return (
    <select
      value={current}
      onChange={e => onChange(e.target.value)}
      disabled={disabled}
      className={className}
      style={style}
      aria-label={t({ id: 'biblioteca.identity.defaultLocale' })}
    >
      {!isKnown && (
        <option value={current}>{current} — {t({ id: 'biblioteca.identity.defaultLocale.unknown' })}</option>
      )}
      {LOCALE_OPTIONS.map(opt => (
        <option key={opt.code} value={opt.code}>
          {opt.name}
        </option>
      ))}
    </select>
  );
}
