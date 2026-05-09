import { useIntl } from 'react-intl';

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
// La liste des locales supportées est définie ici (LOCALE_OPTIONS), à
// enrichir au fur et à mesure que de nouvelles biblios pilotes en
// demandent (basque, catalan, occitan, kurde, etc.). Pas de validation
// CHECK constraint côté DB pour permettre cet ajout sans migration.
//
// Le composant est volontairement minimal : juste un <select> natif HTML
// avec les options. Pas d'autocomplete, pas de search, pas de drapeaux.
// Si une biblio veut une langue qui n'est pas encore dans la liste, elle
// nous demande et on enrichit le composant.
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
//
// Pour ajouter une locale (ex: euskera) :
//   1. Créer src/i18n/locales/eu.json
//   2. Ajouter la locale à mail-strings.ts (les 6 colonnes existantes)
//   3. Ajouter ici : { code: 'eu', name: 'Euskara' }
export const LOCALE_OPTIONS = [
  { code: 'pt-BR', name: 'Português' },
  { code: 'de',    name: 'Deutsch' },
  { code: 'en',    name: 'English' },
  { code: 'es',    name: 'Castellano' },
  { code: 'fr',    name: 'Français' },
  { code: 'it',    name: 'Italiano' },
];

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
