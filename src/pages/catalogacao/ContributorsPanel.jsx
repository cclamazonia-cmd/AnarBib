// src/pages/catalogacao/ContributorsPanel.jsx — E6, lot 4 (28/09/2026)
// Le bloc « Autores e outras responsabilidades » du formulaire de notice.
// La LISTE reste au parent : la sauvegarde, le chargement depuis la base, la
// synthèse du champ « autor », l'application d'une candidate et la publication
// la lisent tous. Le panneau la modifie par `setContributors` et prévient le
// parent d'un changement à enregistrer par `onDirty`.
//
// Refonte du 17/10/2026 : un SEUL champ d'ajout, qui cherche les autorités à
// la frappe et propose en dernier recours le nom libre. Plus de bouton par
// rôle (doublon du menu de chaque ligne) ni de geste « Lier » à part :
//   · le rôle se déduit de la position (1re entrée auteur·rice, les suivantes
//     coauteur·rice), le menu de la ligne corrige le reste ;
//   · l'entrée principale se marque d'une étoile ;
//   · une ligne non liée (reprise d'une candidate, saisie libre) cherche
//     d'elle-même son autorité et propose la liaison en un clic.
import { useEffect, useRef, useState } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import AppIcon from '@/components/ui/AppIcon';

// Une ligne sans nom ni autorité n'est rien : le parent en garde une à vide
// au départ, la sauvegarde l'ignore, le panneau ne l'affiche pas.
const isBlank = c => !(c.name || '').trim() && !c.author_id;

// Toujours une principale, dès qu'il y a une entrée ; positions recalculées.
function normalize(list) {
  const out = list.map((c, i) => ({ ...c, position: i + 1 }));
  if (out.length && !out.some(c => c.is_primary)) out[0] = { ...out[0], is_primary: true };
  return out;
}

function lifeDates(a) {
  if (!a.birth_year && !a.death_year) return '';
  return ` (${a.birth_year || ''}${a.death_year ? `–${a.death_year}` : (a.birth_year ? '–' : '')})`;
}

const fieldStyle = { padding: '6px 8px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.82rem' };
const iconButtonStyle = { background: 'none', border: 'none', cursor: 'pointer', padding: '2px 4px', lineHeight: 0, flexShrink: 0 };
// Fond OPAQUE : la liste flotte au-dessus des champs suivants (les variables
// --brand-panel-* sont translucides, le formulaire transparaissait).
const listStyle = { border: '1px solid rgba(255,255,255,.12)', borderRadius: 8, overflowY: 'auto', maxHeight: 240, background: 'rgb(20,17,15)' };

function AuthorityOption({ a, active, onPick }) {
  return (
    <div role="option" aria-selected={active} onMouseDown={e => e.preventDefault()} onClick={onPick}
      style={{ padding: '6px 10px', cursor: 'pointer', borderBottom: '1px solid rgba(255,255,255,.06)', background: active ? 'rgba(255,255,255,.08)' : 'transparent' }}>
      <div style={{ fontSize: '.8rem', fontWeight: 600 }}>
        {a.preferred_name}
        <span style={{ fontWeight: 400, color: 'var(--brand-muted, #aaa)' }}>{lifeDates(a)}</span>
      </div>
      <div style={{ fontSize: '.68rem', color: 'rgba(255,255,255,.45)' }}>
        {[a.sort_name, a.country].filter(Boolean).join(' · ')}
      </div>
    </div>
  );
}

export default function ContributorsPanel({ contributors, setContributors, availableRoleKeys, roleLabel, autor, setMsg, onDirty }) {
  const { formatMessage: t } = useIntl();

  // ── Champ d'ajout : recherche d'autorité à la frappe ──
  const [query, setQuery] = useState('');
  const [results, setResults] = useState([]);
  const [searching, setSearching] = useState(false);
  const [open, setOpen] = useState(false);
  const [highlight, setHighlight] = useState(0);

  // ── Suggestions de liaison des lignes non liées, par nom ──
  const [suggestions, setSuggestions] = useState({});   // nom → autorités trouvées
  const asked = useRef(new Set());
  const [othersFor, setOthersFor] = useState(null);     // index de la ligne dont la liste est dépliée
  const [focusedRow, setFocusedRow] = useState(null);   // une ligne vidée reste visible tant qu'on la saisit

  const q = query.trim();
  useEffect(() => {
    if (q.length < 2) { setResults([]); setSearching(false); return undefined; }
    setSearching(true);
    let alive = true;
    const timer = setTimeout(async () => {
      try {
        const { data, error } = await supabase.rpc('search_authors_by_name', { p_query: q, p_limit: 8 });
        if (error) throw error;
        if (alive) { setResults(data || []); setHighlight(0); }
      } catch (err) {
        if (alive) { setResults([]); setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' }); }
      } finally {
        if (alive) setSearching(false);
      }
    }, 250);
    return () => { alive = false; clearTimeout(timer); };
  }, [q, setMsg, t]);

  const pendingKey = [...new Set(contributors
    .filter(c => !c.author_id && (c.name || '').trim())
    .map(c => c.name.trim()))].join('\n');
  useEffect(() => {
    const todo = (pendingKey ? pendingKey.split('\n') : []).filter(n => !asked.current.has(n));
    if (!todo.length) return undefined;
    const timer = setTimeout(() => {
      for (const n of todo) {
        asked.current.add(n);
        supabase.rpc('search_authors_by_name', { p_query: n, p_limit: 6 })
          .then(({ data, error }) => setSuggestions(prev => ({ ...prev, [n]: error ? [] : (data || []) })));
      }
    }, 600);
    return () => clearTimeout(timer);
  }, [pendingKey]);

  // ═══════════════════════════════════════════════════════
  // Contributors management
  // ═══════════════════════════════════════════════════════

  function addEntry(name, author = null) {
    setContributors(prev => {
      const kept = prev.filter(c => !isBlank(c));
      return normalize([...kept, {
        position: 0, name, role: kept.length ? 'coautor' : 'autor', is_primary: false,
        author_id: author?.id ?? null, author_label: author?.preferred_name || '',
      }]);
    });
    setQuery(''); setResults([]); setOpen(false);
    onDirty();
  }

  function removeContributor(index) {
    setContributors(prev => normalize(prev.filter((_, i) => i !== index)));
    setOthersFor(null);
    onDirty();
  }

  function updateContributor(index, field, value) {
    // H18 : le code de fonction d'origine ($4) ne vaut que pour le rôle importé ;
    // un rôle corrigé à la main le perd (l'export écrira celui du rôle).
    setContributors(prev => prev.map((c, i) => {
      if (i !== index) return c;
      const next = { ...c, [field]: value };
      if (field === 'role' && value !== c.role) next.role_code = null;
      return next;
    }));
    onDirty();
  }

  function togglePrimary(index) {
    setContributors(prev => prev.map((c, i) => ({ ...c, is_primary: i === index })));
    onDirty();
  }

  function linkAuthorToRow(index, author) {
    setContributors(prev => prev.map((c, i) => i === index
      ? { ...c, author_id: author.id, author_label: author.preferred_name || '' }
      : c));
    setOthersFor(null);
    onDirty();
  }

  function unlinkAuthorFromRow(index) {
    setContributors(prev => prev.map((c, i) => i === index
      ? { ...c, author_id: null, author_label: '' }
      : c));
    onDirty();
  }

  // ── Options du champ d'ajout : les autorités, puis le nom libre ──
  const options = [
    ...results.map(a => ({ key: `a${a.id}`, pick: () => addEntry(a.sort_name || a.preferred_name || q, a), a })),
    ...(q ? [{ key: 'free', pick: () => addEntry(q) }] : []),
  ];

  function onAddKeyDown(e) {
    if (e.key === 'ArrowDown') { e.preventDefault(); setOpen(true); setHighlight(h => Math.min(h + 1, options.length - 1)); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); setHighlight(h => Math.max(h - 1, 0)); }
    else if (e.key === 'Enter') {
      e.preventDefault();   // jamais de soumission du formulaire de notice depuis ce champ
      if (!searching) options[Math.min(highlight, options.length - 1)]?.pick();
    } else if (e.key === 'Escape') { setOpen(false); }
  }

  function linkStatus(c, i) {
    if (c.author_id) {
      return (
        <span className="cat-pill ok" style={{ fontSize: '.66rem', display: 'inline-flex', alignItems: 'center', gap: 4, minWidth: 0, maxWidth: 220 }}
          title={t({ id: 'catalogacao.authlink.linkedTitle' })}>
          <AppIcon name="link" size={12} />
          <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{c.author_label || `#${c.author_id}`}</span>
          <button type="button" onClick={() => unlinkAuthorFromRow(i)} style={{ ...iconButtonStyle, color: 'inherit', padding: 0 }}
            title={t({ id: 'catalogacao.authlink.unlink' })} aria-label={t({ id: 'catalogacao.authlink.unlink' })}>
            <AppIcon name="close" size={12} />
          </button>
        </span>
      );
    }
    const found = suggestions[(c.name || '').trim()];
    const muted = { fontSize: '.7rem', color: 'var(--brand-muted, #aaa)', flexShrink: 0 };
    if (!found) return <span style={muted} aria-hidden="true">…</span>;
    if (!found.length) return <span style={muted}>{t({ id: 'catalogacao.authlink.none' })}</span>;
    const best = found[0];
    // La liaison en un clic n'est offerte qu'à une correspondance EXACTE (nom
    // normalisé égal) : « Robert, Roberto » rapprochait Roberto Zani. Au-delà,
    // on montre les autorités proches et la personne choisit.
    if (best.match_kind !== 'exact') {
      return (
        <button type="button" onClick={() => setOthersFor(othersFor === i ? null : i)} aria-expanded={othersFor === i}
          style={{ display: 'inline-flex', alignItems: 'center', gap: 4, flexShrink: 0, background: 'none', border: '1px solid rgba(255,255,255,.15)', borderRadius: 6, color: 'var(--brand-muted, #aaa)', cursor: 'pointer', fontSize: '.7rem', padding: '5px 8px' }}
          title={t({ id: 'catalogacao.authlink.linkTitle' })}>
          <AppIcon name="search" size={12} />
          {t({ id: 'catalogacao.authlink.nearby' }, { count: found.length })}
        </button>
      );
    }
    return (
      <span style={{ display: 'inline-flex', gap: 4, minWidth: 0, maxWidth: 260 }}>
        <button type="button" onClick={() => linkAuthorToRow(i, best)}
          style={{ display: 'inline-flex', alignItems: 'center', gap: 4, minWidth: 0, background: 'none', border: '1px dashed rgba(255,255,255,.25)', borderRadius: 6, color: '#f4f4f4', cursor: 'pointer', fontSize: '.7rem', padding: '5px 8px' }}
          title={t({ id: 'catalogacao.authlink.linkTitle' })}>
          <AppIcon name="link" size={12} />
          <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
            {t({ id: 'catalogacao.authlink.suggest' }, { name: `${best.preferred_name}${lifeDates(best)}` })}
          </span>
        </button>
        {found.length > 1 && (
          <button type="button" onClick={() => setOthersFor(othersFor === i ? null : i)} aria-expanded={othersFor === i}
            style={{ flexShrink: 0, background: 'none', border: '1px solid rgba(255,255,255,.15)', borderRadius: 6, color: 'var(--brand-muted, #aaa)', cursor: 'pointer', fontSize: '.7rem', padding: '5px 8px' }}>
            {t({ id: 'catalogacao.authlink.others' }, { count: found.length - 1 })}
          </button>
        )}
      </span>
    );
  }

  const showList = open && q.length >= 2;
  return (
    <div style={{ gridColumn: 'span 3' }}>
      <label htmlFor="contributor-add" style={{ display: 'block', fontSize: '.75rem', color: 'var(--brand-muted, #aaa)', marginBottom: 6 }}>
        {t({ id: 'catalogacao.ui.contributors' })}
      </label>
      {contributors.map((c, i) => (isBlank(c) && focusedRow !== i) ? null : (
        <div key={i} style={{ marginBottom: 5 }}>
          <div style={{ display: 'flex', gap: 6, alignItems: 'center', flexWrap: 'wrap' }}>
            <button type="button" onClick={() => togglePrimary(i)} aria-pressed={!!c.is_primary}
              title={t({ id: 'catalogacao.contributor.primaryTitle' })} aria-label={t({ id: 'catalogacao.contributor.primaryTitle' })}
              style={{ ...iconButtonStyle, color: c.is_primary ? '#facc15' : 'rgba(255,255,255,.3)' }}>
              <AppIcon name="star" size={16} fill={c.is_primary ? 'currentColor' : 'none'} />
            </button>
            <input type="text" value={c.name} placeholder={t({ id: 'catalogacao.contributor.namePlaceholder' })}
              onChange={e => updateContributor(i, 'name', e.target.value)}
              onFocus={() => setFocusedRow(i)}
              onBlur={() => { setFocusedRow(null); if (isBlank(c)) removeContributor(i); }}
              /* 1 1 160px : sur mobile le nom prend la ligne entière et le rôle
                 passe dessous, au lieu d'être écrasé à ~115 px (cf. mobile.css). */
              style={{ ...fieldStyle, flex: '1 1 160px' }}
            />
            {/* Rôle, liaison et retrait passent à la ligne ENSEMBLE : sur mobile,
                le × ne reste pas seul sur sa ligne. */}
            <div style={{ display: 'flex', gap: 6, alignItems: 'center', flexWrap: 'wrap', minWidth: 0 }}>
              <select value={c.role} onChange={e => updateContributor(i, 'role', e.target.value)}
                style={{ ...fieldStyle, minWidth: 130, maxWidth: '100%', fontSize: '.78rem' }}
              >
                {/* Garde : un rôle déjà posé hors-liste (notice reprise) reste sélectionnable */}
                {(availableRoleKeys.includes(c.role) ? availableRoleKeys : [c.role, ...availableRoleKeys]).map(k => (
                  <option key={k} value={k}>{roleLabel(k)}</option>
                ))}
              </select>
              {/* la liaison se tronque plutôt que de laisser le × seul */}
              <span style={{ display: 'flex', gap: 6, alignItems: 'center', minWidth: 0, flex: '0 1 auto' }}>
                {linkStatus(c, i)}
                <button type="button" onClick={() => removeContributor(i)} style={{ ...iconButtonStyle, color: '#f87171' }}
                  title={t({ id: 'catalogacao.contributor.removeTitle' })} aria-label={t({ id: 'catalogacao.contributor.removeTitle' })}>
                  <AppIcon name="close" size={14} />
                </button>
              </span>
            </div>
          </div>
          {othersFor === i && !c.author_id && (
            <div role="listbox" style={{ ...listStyle, marginLeft: 28, marginTop: 4, maxHeight: 180 }}>
              {(suggestions[(c.name || '').trim()] || []).map(a => (
                <AuthorityOption key={a.id} a={a} active={false} onPick={() => linkAuthorToRow(i, a)} />
              ))}
            </div>
          )}
        </div>
      ))}

      {/* Champ d'ajout unique : autorités d'abord, nom libre en dernier recours */}
      <div style={{ position: 'relative', marginTop: 4 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <span style={{ color: 'var(--brand-muted, #aaa)', lineHeight: 0, padding: '0 4px', flexShrink: 0 }}><AppIcon name="search" size={16} /></span>
          <input id="contributor-add" type="text" value={query} autoComplete="off"
            role="combobox" aria-expanded={showList} aria-controls="contributor-add-list" aria-autocomplete="list"
            placeholder={t({ id: 'catalogacao.contributor.addPlaceholder' })}
            onChange={e => { setQuery(e.target.value); setOpen(true); }}
            onFocus={() => setOpen(true)}
            onBlur={() => setOpen(false)}
            onKeyDown={onAddKeyDown}
            style={{ ...fieldStyle, flex: '1 1 auto', minWidth: 0, borderStyle: 'dashed' }}
          />
        </div>
        {showList && (
          <div id="contributor-add-list" role="listbox"
            style={{ ...listStyle, position: 'absolute', top: '100%', left: 28, right: 0, marginTop: 4, zIndex: 20, boxShadow: '0 8px 24px rgba(0,0,0,.45)' }}>
            {searching && results.length === 0 && (
              <div style={{ fontSize: '.74rem', color: 'var(--brand-muted, #aaa)', padding: '6px 10px' }}>…</div>
            )}
            {!searching && results.length === 0 && (
              <div style={{ fontSize: '.74rem', color: 'var(--brand-muted, #aaa)', padding: '6px 10px' }}>{t({ id: 'catalogacao.authlink.noResults' })}</div>
            )}
            {options.map((o, k) => o.a
              ? <AuthorityOption key={o.key} a={o.a} active={k === highlight} onPick={o.pick} />
              : (
                <div key={o.key} role="option" aria-selected={k === highlight} onMouseDown={e => e.preventDefault()} onClick={o.pick}
                  style={{ padding: '7px 10px', cursor: 'pointer', fontSize: '.76rem', color: 'var(--brand-muted, #aaa)', fontStyle: 'italic', background: k === highlight ? 'rgba(255,255,255,.08)' : 'transparent' }}>
                  {t({ id: 'catalogacao.contributor.addFree' }, { name: q })}
                </div>
              ))}
          </div>
        )}
      </div>

      {/* Champ autor synthétisé (readonly) */}
      <input type="text" value={autor} readOnly
        style={{ width: '100%', padding: '5px 8px', borderRadius: 6, border: '1px solid rgba(255,255,255,.06)', background: 'rgba(0,0,0,.15)', color: 'var(--brand-muted, #aaa)', fontSize: '.78rem', marginTop: 8 }}
        title={t({ id: 'catalogacao.contributor.synthTitle' })}
      />
    </div>
  );
}
