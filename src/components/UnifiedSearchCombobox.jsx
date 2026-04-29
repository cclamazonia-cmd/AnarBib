import { useState, useEffect, useRef, useCallback, useId } from 'react';
import { useNavigate } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { apiRpc } from '@/lib/supabase';
import './UnifiedSearchCombobox.css';

const MIN_QUERY_LENGTH = 4;
const DEBOUNCE_MS = 250;
const MAX_SUGGESTIONS = 10;

/**
 * Composant de recherche unifiée à autocomplétion.
 *
 * Affiche un champ de saisie qui, à partir de 4 caractères, propose en temps réel
 * jusqu'à 10 suggestions typées (auteurs et livres) issues de la fonction RPC
 * api.search_catalog_v1. Respecte la sémantique visibility_level via la matérialisée
 * appropriée selon le statut de l'utilisateur (anon, membre du réseau).
 *
 * Phase B.7.4 — voir backlog AnarBib.
 *
 * @param {Object} props
 * @param {Function} props.onAuthorPick   — callback(author) appelé au clic sur une suggestion auteur.
 *                                          author = { id, label } — utilisé par CatalogPage pour
 *                                          alimenter authorFilter et filtrer la grille.
 */
export default function UnifiedSearchCombobox({ onAuthorPick }) {
  const intl = useIntl();
  const t = intl.formatMessage;
  const navigate = useNavigate();

  const [query, setQuery] = useState('');
  const [suggestions, setSuggestions] = useState([]);
  const [isOpen, setIsOpen] = useState(false);
  const [activeIndex, setActiveIndex] = useState(-1);
  const [loading, setLoading] = useState(false);

  const inputRef = useRef(null);
  const listboxRef = useRef(null);
  const debounceTimerRef = useRef(null);
  const lastQueryRef = useRef('');

  // IDs ARIA stables pour ce combobox
  const id = useId();
  const listboxId = `${id}-listbox`;
  const optionId = (i) => `${id}-option-${i}`;

  // Debounced fetch
  useEffect(() => {
    // Reset si saisie trop courte
    if (query.trim().length < MIN_QUERY_LENGTH) {
      setSuggestions([]);
      setIsOpen(false);
      setActiveIndex(-1);
      setLoading(false);
      // Annule un debounce en cours
      if (debounceTimerRef.current) {
        clearTimeout(debounceTimerRef.current);
        debounceTimerRef.current = null;
      }
      return;
    }

    // Annule le timer précédent (debouncing)
    if (debounceTimerRef.current) {
      clearTimeout(debounceTimerRef.current);
    }

    setLoading(true);

    debounceTimerRef.current = setTimeout(async () => {
      const q = query.trim();
      lastQueryRef.current = q;
      const { data, error } = await apiRpc('search_catalog_v1', { q });

      // Si une nouvelle saisie est arrivée pendant l'attente réseau, ignore
      if (lastQueryRef.current !== q) return;

      if (error) {
        // En cas d'erreur, on ferme silencieusement plutôt que d'afficher un message agressif
        // (l'utilisateur reste libre d'utiliser la recherche avancée)
        setSuggestions([]);
        setIsOpen(false);
        setLoading(false);
        return;
      }

      const list = Array.isArray(data) ? data.slice(0, MAX_SUGGESTIONS) : [];
      setSuggestions(list);
      setIsOpen(list.length > 0);
      setActiveIndex(list.length > 0 ? 0 : -1);
      setLoading(false);
    }, DEBOUNCE_MS);

    return () => {
      if (debounceTimerRef.current) {
        clearTimeout(debounceTimerRef.current);
      }
    };
  }, [query]);

  // Sélection d'une suggestion
  const handleSelect = useCallback((item) => {
    if (!item) return;
    if (item.kind === 'book') {
      // Navigation directe vers la page livre
      navigate(`/livro/${item.id}`);
    } else if (item.kind === 'author') {
      // On délègue au parent pour qu'il filtre la grille par auteur.
      // filter_value est la forme NOM, Prénom qui matche la colonne autor (B.7 décision pragmatique).
      // À long terme : basculer sur un filtre par author_id via author_chips (cf. backlog).
      if (onAuthorPick) {
        onAuthorPick({ 
          id: item.id, 
          label: item.label,
          filterValue: item.filter_value || item.label
        });
      }
    }
    // Reset UI après sélection
    setQuery('');
    setSuggestions([]);
    setIsOpen(false);
    setActiveIndex(-1);
  }, [navigate, onAuthorPick]);

  // Navigation clavier
  const handleKeyDown = useCallback((e) => {
    if (!isOpen || suggestions.length === 0) {
      // Ouvre la liste si on appuie sur ↓ alors qu'on a déjà un résultat caché
      if (e.key === 'ArrowDown' && suggestions.length > 0) {
        e.preventDefault();
        setIsOpen(true);
        setActiveIndex(0);
      }
      return;
    }

    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        setActiveIndex((i) => (i + 1) % suggestions.length);
        break;
      case 'ArrowUp':
        e.preventDefault();
        setActiveIndex((i) => (i - 1 + suggestions.length) % suggestions.length);
        break;
      case 'Enter':
        e.preventDefault();
        if (activeIndex >= 0 && activeIndex < suggestions.length) {
          handleSelect(suggestions[activeIndex]);
        }
        break;
      case 'Escape':
        e.preventDefault();
        setIsOpen(false);
        setActiveIndex(-1);
        inputRef.current?.blur();
        break;
      case 'Home':
        e.preventDefault();
        setActiveIndex(0);
        break;
      case 'End':
        e.preventDefault();
        setActiveIndex(suggestions.length - 1);
        break;
      default:
        break;
    }
  }, [isOpen, suggestions, activeIndex, handleSelect]);

  // Fermeture sur clic en dehors
  useEffect(() => {
    if (!isOpen) return;
    const handleClickOutside = (e) => {
      if (
        inputRef.current && !inputRef.current.contains(e.target) &&
        listboxRef.current && !listboxRef.current.contains(e.target)
      ) {
        setIsOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [isOpen]);

  // Scroll sur option active (utile au clavier)
  useEffect(() => {
    if (activeIndex < 0 || !listboxRef.current) return;
    const opt = listboxRef.current.querySelector(`#${CSS.escape(optionId(activeIndex))}`);
    if (opt) {
      opt.scrollIntoView({ block: 'nearest' });
    }
  }, [activeIndex]); // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <div className="ab-unified-search">
      <div className="ab-unified-search__inputwrap">
        <input
          ref={inputRef}
          type="search"
          className="ab-input ab-unified-search__input"
          placeholder={t({ id: 'catalog.search.suggestions.placeholder' })}
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={handleKeyDown}
          onFocus={() => { if (suggestions.length > 0) setIsOpen(true); }}
          role="combobox"
          aria-autocomplete="list"
          aria-expanded={isOpen}
          aria-controls={listboxId}
          aria-activedescendant={
            isOpen && activeIndex >= 0 ? optionId(activeIndex) : undefined
          }
          aria-label={t({ id: 'catalog.search.suggestions.label' })}
          autoComplete="off"
          spellCheck={false}
        />
        {loading && (
          <span className="ab-unified-search__loading" aria-hidden="true">…</span>
        )}
      </div>

      {isOpen && suggestions.length > 0 && (
        <ul
          ref={listboxRef}
          id={listboxId}
          role="listbox"
          className="ab-unified-search__listbox"
          aria-label={t({ id: 'catalog.search.suggestions.listLabel' })}
        >
          {suggestions.map((item, i) => (
            <li
              key={`${item.kind}-${item.id}`}
              id={optionId(i)}
              role="option"
              aria-selected={i === activeIndex}
              className={
                'ab-unified-search__option' +
                (i === activeIndex ? ' ab-unified-search__option--active' : '')
              }
              // onMouseDown plutôt qu'onClick pour ne pas perdre le focus avant
              onMouseDown={(e) => {
                e.preventDefault();
                handleSelect(item);
              }}
              onMouseEnter={() => setActiveIndex(i)}
            >
              <span className="ab-unified-search__kind" aria-hidden="true">
                {item.kind === 'author' ? '👤' : '📕'}
              </span>
              <span className="ab-unified-search__main">
                <span className="ab-unified-search__label">{item.label}</span>
                {item.sublabel && (
                  <span className="ab-unified-search__sublabel">{item.sublabel}</span>
                )}
              </span>
            </li>
          ))}
        </ul>
      )}

      {/* Annonce vocale ARIA pour lecteurs d'écran */}
      <div
        className="ab-unified-search__sr-only"
        role="status"
        aria-live="polite"
      >
        {isOpen && suggestions.length > 0
          ? t(
              { id: 'catalog.search.suggestions.countAnnounce' },
              { count: suggestions.length }
            )
          : ''}
      </div>
    </div>
  );
}
