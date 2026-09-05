import { useState, useEffect, useMemo, useRef, useCallback } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import UserHeroBadge from '@/components/UserHeroBadge';
import { INTENTIONS, GROUPS, visibleGroups, matchIntentions } from './intentions';
import './InicioPage.css';

// InicioPage — « Je veux… » (05/09/2026).
//
// Une page pour dire ce qu'on veut faire, et y être mené : un champ qui
// propose les actions à mesure qu'on tape, les raccourcis épinglés par la
// personne, puis les rubriques de son rôle. Chaque intention mène à la page
// ET à l'onglet du geste (cf. intentions.js).
//
// Les raccourcis sont une commodité de ce navigateur (localStorage, par
// compte) : ils ne quittent pas l'appareil et ne sont pas synchronisés.

const PINS_PREFIX = 'anarbib.inicio.pins.';

function readPins(userId) {
  if (!userId) return [];
  try {
    const raw = localStorage.getItem(PINS_PREFIX + userId);
    const arr = raw ? JSON.parse(raw) : [];
    return Array.isArray(arr) ? arr.filter(id => INTENTIONS.some(i => i.id === id)) : [];
  } catch { return []; }
}

function writePins(userId, pins) {
  if (!userId) return;
  try { localStorage.setItem(PINS_PREFIX + userId, JSON.stringify(pins)); } catch { /* commodité seulement */ }
}

export default function InicioPage() {
  const { formatMessage: t } = useIntl();
  const navigate = useNavigate();
  const { user, profile } = useAuth();
  const { role, isNetworkAdmin, libraryName } = useLibrary();

  const groups = useMemo(() => visibleGroups({ role, isNetworkAdmin }), [role, isNetworkAdmin]);
  const items = useMemo(() => INTENTIONS.filter(i => groups.includes(i.group)), [groups]);

  const labelOf = useCallback((it) => t({ id: `inicio.i.${it.id}` }), [t]);
  const kwOf = useCallback((it) => t({ id: `inicio.kw.${it.id}`, defaultMessage: '' }), [t]);

  // ── Champ « Je veux… » ──
  const [query, setQuery] = useState('');
  const [focus, setFocus] = useState(false);
  const inputRef = useRef(null);
  const suggestions = useMemo(
    () => matchIntentions(query, items, labelOf, kwOf).slice(0, 8),
    [query, items, labelOf, kwOf],
  );
  useEffect(() => { inputRef.current?.focus(); }, []);

  function go(it) {
    setQuery('');
    navigate(it.to);
  }
  function onKeyDown(e) {
    if (e.key === 'Enter' && suggestions.length > 0) { e.preventDefault(); go(suggestions[0]); }
    if (e.key === 'Escape') { setQuery(''); }
  }

  // ── Raccourcis ──
  const [pins, setPins] = useState(() => readPins(user?.id));
  useEffect(() => { setPins(readPins(user?.id)); }, [user?.id]);
  function togglePin(id) {
    setPins(prev => {
      const next = prev.includes(id) ? prev.filter(x => x !== id) : [...prev, id];
      writePins(user?.id, next);
      return next;
    });
  }
  const pinned = pins.map(id => items.find(i => i.id === id)).filter(Boolean);

  const firstName = profile?.first_name || null;

  return (
    <PageShell><Topbar />
      <Hero
        title={firstName ? t({ id: 'inicio.greeting' }, { name: firstName }) : t({ id: 'inicio.greetingNoName' })}
        subtitle={libraryName && libraryName !== 'AnarBib'
          ? t({ id: 'inicio.subtitleLibrary' }, { library: libraryName })
          : t({ id: 'inicio.subtitle' })}
      >
        <UserHeroBadge />
      </Hero>

      <div className="ab-inicio">
        {/* ── Le champ ── */}
        <section className="ab-inicio__ask" aria-label={t({ id: 'inicio.title' })}>
          <label className="ab-inicio__label" htmlFor="ab-inicio-input">{t({ id: 'inicio.title' })}</label>
          <div className={`ab-inicio__field${focus ? ' is-focus' : ''}`}>
            <span className="ab-inicio__glyph" aria-hidden="true">→</span>
            <input
              id="ab-inicio-input" ref={inputRef} type="text" value={query}
              onChange={e => setQuery(e.target.value)} onKeyDown={onKeyDown}
              onFocus={() => setFocus(true)} onBlur={() => setTimeout(() => setFocus(false), 120)}
              placeholder={t({ id: 'inicio.searchPlaceholder' })}
              autoComplete="off" spellCheck="false"
              aria-autocomplete="list" aria-controls="ab-inicio-suggest"
            />
          </div>
          {query.trim() !== '' && (
            <ul id="ab-inicio-suggest" className="ab-inicio__suggest" role="listbox">
              {suggestions.length === 0 && (
                <li className="ab-inicio__nomatch">{t({ id: 'inicio.noMatch' })}</li>
              )}
              {suggestions.map((it, i) => (
                <li key={it.id} role="option" aria-selected={i === 0}>
                  <button type="button" className={`ab-inicio__sugg${i === 0 ? ' is-first' : ''}`} onClick={() => go(it)}>
                    <span className="ab-inicio__icon" aria-hidden="true">{it.icon}</span>
                    <span className="ab-inicio__sugg-label">{labelOf(it)}</span>
                    {i === 0 && <kbd className="ab-inicio__kbd">↵</kbd>}
                  </button>
                </li>
              ))}
            </ul>
          )}
          {query.trim() === '' && <p className="ab-inicio__hint">{t({ id: 'inicio.searchHint' })}</p>}
        </section>

        {/* ── Mes raccourcis ── */}
        <section className="ab-inicio__pins">
          <h2 className="ab-inicio__h2">{t({ id: 'inicio.pins.title' })}</h2>
          {pinned.length === 0
            ? <p className="ab-inicio__empty">{t({ id: 'inicio.pins.empty' })}</p>
            : (
              <div className="ab-inicio__chips">
                {pinned.map(it => (
                  <Link key={it.id} to={it.to} className="ab-inicio__chip">
                    <span aria-hidden="true">{it.icon}</span> {labelOf(it)}
                  </Link>
                ))}
              </div>
            )}
        </section>

        {/* ── Les rubriques du rôle ── */}
        {GROUPS.filter(g => groups.includes(g)).map(g => (
          <section key={g} className="ab-inicio__group">
            <h2 className="ab-inicio__h2">{t({ id: `inicio.group.${g}` })}</h2>
            <ul className="ab-inicio__grid">
              {items.filter(i => i.group === g).map(it => {
                const isPinned = pins.includes(it.id);
                return (
                  <li key={it.id} className={`ab-inicio__card${isPinned ? ' is-pinned' : ''}`}>
                    <Link to={it.to} className="ab-inicio__card-link">
                      <span className="ab-inicio__icon" aria-hidden="true">{it.icon}</span>
                      <span className="ab-inicio__card-label">{labelOf(it)}</span>
                    </Link>
                    <button type="button" className="ab-inicio__star" onClick={() => togglePin(it.id)}
                      aria-pressed={isPinned}
                      title={t({ id: isPinned ? 'inicio.unpin' : 'inicio.pin' })}
                      aria-label={t({ id: isPinned ? 'inicio.unpin' : 'inicio.pin' })}>
                      {isPinned ? '★' : '☆'}
                    </button>
                  </li>
                );
              })}
            </ul>
          </section>
        ))}

        <p className="ab-inicio__foot">{t({ id: 'inicio.footer' })}</p>
      </div>
    <Footer /></PageShell>
  );
}
