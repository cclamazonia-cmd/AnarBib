import { useState } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { SUPPORTED_LOCALES, setLocale } from '@/i18n';
import './LocaleSwitcher.css';

/**
 * Sélecteur de langue réutilisable.
 *
 * Variantes :
 *   - "header" (défaut)  : compact, intégré dans la topbar
 *   - "footer"           : plus visible, pour le pied de page
 *
 * Comportement :
 *   - Lit la locale active via react-intl (useIntl().locale) — réactive au swap
 *   - Au changement :
 *       1. Si user connecté, écrit profile.preferred_language en base
 *       2. Appelle setLocale() (localStorage + événement de swap live, pas de reload)
 *   - Si l'écriture en base échoue, on procède quand même au changement
 *     local (l'utilisateur ne doit pas être bloqué par un problème réseau)
 */
export function LocaleSwitcher({ variant = 'header' }) {
  const { formatMessage: t, locale: currentLocale } = useIntl();
  const { user } = useAuth();
  const [updating, setUpdating] = useState(false);

  // La locale active vient de react-intl (IntlProvider) : elle se met à jour
  // toute seule au swap live (événement 'anarbib:locale-change' → App.jsx), donc
  // le <select> reflète immédiatement la langue choisie. (Avant : useMemo(detectLocale)
  // figé au montage → le sélecteur restait coincé sur l'ancienne langue.)

  async function handleChange(e) {
    const newLocale = e.target.value;
    if (newLocale === currentLocale) return;

    setUpdating(true);
    try {
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

      // 2. Appliquer localement (swap live, plus de reload)
      setLocale(newLocale);
    } finally {
      // setLocale ne recharge plus la page : il FAUT relâcher "updating" nous-mêmes,
      // sinon le <select> reste disabled indéfiniment — grisé + cursor:wait, qui sous
      // Windows s'affiche comme un rond bleu tournant (le « composant bloqué »).
      setUpdating(false);
    }
  }

  const className = `ab-locale-switcher ab-locale-switcher--${variant}`;

  return (
    // #fix-android (18/07) : le tiroir mobile (.ab-topbar__nav) ferme le menu
    // au clic via bubbling (onClick sur le conteneur parent) pour les liens
    // de nav. Sans stopPropagation, ce clic remonte aussi depuis le <select>
    // ici, qui passe alors en display:none (tiroir ferme) dans le meme tick
    // que le tap -> le picker natif Android n'a plus d'ancrage et ne s'ouvre
    // jamais (bouton visuellement mort).
    <div className={className} onClick={(e) => e.stopPropagation()}>
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
            {l.label}
          </option>
        ))}
      </select>
    </div>
  );
}

export default LocaleSwitcher;
