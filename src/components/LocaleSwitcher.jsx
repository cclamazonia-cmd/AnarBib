import { useState, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { SUPPORTED_LOCALES, detectLocale, setLocale } from '@/i18n';
import './LocaleSwitcher.css';

/**
 * Sélecteur de langue réutilisable.
 *
 * Variantes :
 *   - "header" (défaut)  : compact, intégré dans la topbar
 *   - "footer"           : plus visible, pour le pied de page
 *
 * Comportement :
 *   - Lit la locale active via detectLocale()
 *   - Au changement :
 *       1. Si user connecté, écrit profile.preferred_language en base
 *       2. Appelle setLocale() qui sauvegarde localStorage + scroll puis reload
 *   - Si l'écriture en base échoue, on procède quand même au changement
 *     local (l'utilisateur ne doit pas être bloqué par un problème réseau)
 */
export function LocaleSwitcher({ variant = 'header' }) {
  const { formatMessage: t } = useIntl();
  const { user } = useAuth();
  const [updating, setUpdating] = useState(false);

  // Mémoïsé pour ne pas recalculer à chaque render
  const currentLocale = useMemo(() => detectLocale(), []);

  async function handleChange(e) {
    const newLocale = e.target.value;
    if (newLocale === currentLocale) return;

    setUpdating(true);

    // 1. Écrire en base si connecté (best effort)
    if (user?.id) {
      try {
        await supabase
          .from('profiles')
          .update({ preferred_language: newLocale })
          .eq('id', user.id);
      } catch (err) {
        // On continue malgré l'erreur : le changement local est plus important
        console.warn('[LocaleSwitcher] Failed to persist preferred_language:', err);
      }
    }

    // 2. Appliquer localement (sauvegarde scroll + reload)
    setLocale(newLocale);
  }

  const className = `ab-locale-switcher ab-locale-switcher--${variant}`;

  return (
    <div className={className}>
      <label
        htmlFor={`ab-locale-select-${variant}`}
        className="ab-locale-switcher__label"
      >
        {t({ id: 'language.selector' })}
      </label>
      <select
        id={`ab-locale-select-${variant}`}
        className="ab-locale-switcher__select"
        value={currentLocale}
        onChange={handleChange}
        disabled={updating}
        aria-label={t({ id: 'language.selector' })}
      >
        {SUPPORTED_LOCALES.map(l => (
          <option key={l.code} value={l.code}>
            {l.shortCode} • {l.label} {l.flag}
          </option>
        ))}
      </select>
    </div>
  );
}

export default LocaleSwitcher;
