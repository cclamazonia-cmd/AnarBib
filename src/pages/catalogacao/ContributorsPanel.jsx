// src/pages/catalogacao/ContributorsPanel.jsx — E6, lot 4 (28/09/2026)
// Le bloc « Autores e outras responsabilidades » du formulaire de notice, sorti
// de BookDraftForm.jsx sans en changer une ligne de logique : lignes de
// contributeur·rices (nom, rôle, principal·e), ajout par rôle, retrait, et le
// sélecteur d'autorité par ligne (recherche par nom, liaison, déliaison).
// La LISTE reste au parent : la sauvegarde, le chargement depuis la base, la
// synthèse du champ « autor », l'application d'une candidate et la publication
// la lisent tous. Le panneau la modifie par `setContributors` et prévient le
// parent d'un changement à enregistrer par `onDirty`. Seul l'état du sélecteur
// d'autorité vit ici.
import { useState } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

export default function ContributorsPanel({ contributors, setContributors, availableRoleKeys, roleLabel, autor, setMsg, onDirty }) {
  const { formatMessage: t } = useIntl();
  const [authorSearch, setAuthorSearch] = useState({ index: null, results: [], loading: false });

  // ═══════════════════════════════════════════════════════
  // Contributors management
  // ═══════════════════════════════════════════════════════

  function addContributor(role = 'autor') {
    setContributors(prev => [
      ...prev,
      { position: prev.length + 1, name: '', role, is_primary: prev.length === 0, author_id: null, author_label: '' },
    ]);
    onDirty();
  }

  function removeContributor(index) {
    setContributors(prev => prev.filter((_, i) => i !== index).map((c, i) => ({ ...c, position: i + 1 })));
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
  }

  // Sélecteur d'autorité (volet préventif) : recherche locale par nom de ligne
  async function searchAuthorForRow(index) {
    const name = (contributors[index]?.name || '').trim();
    if (!name) { setMsg({ text: t({id:'catalogacao.authlink.needName'}), kind: 'error' }); return; }
    setAuthorSearch({ index, results: [], loading: true });
    try {
      const { data, error } = await supabase.rpc('search_authors_by_name', { p_query: name, p_limit: 8 });
      if (error) throw error;
      setAuthorSearch({ index, results: data || [], loading: false });
    } catch (err) {
      setAuthorSearch({ index: null, results: [], loading: false });
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    }
  }

  function linkAuthorToRow(index, author) {
    setContributors(prev => prev.map((c, i) => i === index
      ? { ...c, author_id: author.id, author_label: author.preferred_name || '' }
      : c));
    setAuthorSearch({ index: null, results: [], loading: false });
    onDirty();
  }

  function unlinkAuthorFromRow(index) {
    setContributors(prev => prev.map((c, i) => i === index
      ? { ...c, author_id: null, author_label: '' }
      : c));
    onDirty();
  }

  return (
    <div style={{ gridColumn: 'span 3' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6, flexWrap: 'wrap', gap: 6 }}>
        <label style={{ fontSize: '.75rem', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.ui.contributors'})}</label>
        <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
          <button type="button" className="ab-button ab-button--secondary ab-button--sm"
            onClick={() => addContributor('autor')}>{t({id:'catalogacao.ui.addAuthor'})}</button>
          <button type="button" className="ab-button ab-button--secondary ab-button--sm"
            onClick={() => addContributor('coautor')}>{t({id:'catalogacao.ui.addCoauthor'})}</button>
          <button type="button" className="ab-button ab-button--secondary ab-button--sm"
            onClick={() => addContributor('organizacao')}>{t({id:'catalogacao.ui.addCollective'})}</button>
          <button type="button" className="ab-button ab-button--secondary ab-button--sm"
            onClick={() => addContributor('tradutor')}>{t({id:'catalogacao.ui.addTranslator'})}</button>
        </div>
      </div>
      {contributors.map((c, i) => (
        <div key={i} style={{ marginBottom: 5 }}>
          <div style={{ display: 'flex', gap: 6, alignItems: 'center', flexWrap: 'wrap' }}>
            <input type="radio" name="primary_contributor" checked={c.is_primary}
              onChange={() => togglePrimary(i)} title={t({ id: 'catalogacao.contributor.primaryTitle' })}
              style={{ flexShrink: 0 }} />
            <input type="text" value={c.name} placeholder={t({ id: 'catalogacao.contributor.namePlaceholder' })}
              onChange={e => updateContributor(i, 'name', e.target.value)}
              /* 1 1 160px : sur mobile le nom prend la ligne entière et le rôle
                 passe dessous, au lieu d'être écrasé à ~115 px (cf. mobile.css). */
              style={{ flex: '1 1 160px', padding: '6px 8px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.82rem' }}
            />
            <select value={c.role} onChange={e => updateContributor(i, 'role', e.target.value)}
              style={{ width: 130, padding: '6px 8px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.78rem' }}
            >
              {/* Garde : un rôle déjà posé hors-liste (notice reprise) reste sélectionnable */}
              {(availableRoleKeys.includes(c.role) ? availableRoleKeys : [c.role, ...availableRoleKeys]).map(k => (
                <option key={k} value={k}>{roleLabel(k)}</option>
              ))}
            </select>
            {c.author_id ? (
              <span className="cat-pill ok" style={{ fontSize: '.66rem', display: 'inline-flex', alignItems: 'center', gap: 4, flexShrink: 0 }}
                title={t({id:'catalogacao.authlink.linkedTitle'})}>
                🔗 {c.author_label || `#${c.author_id}`}
                <button type="button" onClick={() => unlinkAuthorFromRow(i)}
                  style={{ background: 'none', border: 'none', color: 'inherit', cursor: 'pointer', fontSize: '.8rem', padding: 0, lineHeight: 1 }}
                  title={t({id:'catalogacao.authlink.unlink'})}>×</button>
              </span>
            ) : (
              <button type="button" onClick={() => searchAuthorForRow(i)}
                disabled={authorSearch.loading && authorSearch.index === i}
                style={{ flexShrink: 0, background: 'none', border: '1px solid rgba(255,255,255,.15)', borderRadius: 6, color: 'var(--brand-muted, #aaa)', cursor: 'pointer', fontSize: '.7rem', padding: '5px 8px' }}
                title={t({id:'catalogacao.authlink.linkTitle'})}>
                {authorSearch.loading && authorSearch.index === i ? '…' : `🔗 ${t({id:'catalogacao.authlink.link'})}`}
              </button>
            )}
            {contributors.length > 1 && (
              <button type="button" onClick={() => removeContributor(i)}
                style={{ background: 'none', border: 'none', color: '#f87171', cursor: 'pointer', fontSize: '1rem', padding: '2px 6px' }}
                title={t({ id: 'catalogacao.contributor.removeTitle' })}>×</button>
            )}
          </div>
          {/* Panneau de résultats du sélecteur d'autorité (volet préventif) */}
          {authorSearch.index === i && !authorSearch.loading && (
            <div style={{ marginLeft: 24, marginTop: 4, border: '1px solid rgba(255,255,255,.1)', borderRadius: 8, overflow: 'hidden', maxHeight: 180, overflowY: 'auto' }}>
              {authorSearch.results.length === 0 ? (
                <div style={{ fontSize: '.74rem', color: 'var(--brand-muted, #aaa)', padding: '6px 10px' }}>{t({id:'catalogacao.authlink.noResults'})}</div>
              ) : authorSearch.results.map(a => (
                <div key={a.id} onClick={() => linkAuthorToRow(i, a)}
                  style={{ padding: '6px 10px', cursor: 'pointer', borderBottom: '1px solid rgba(255,255,255,.06)' }}>
                  <div style={{ fontSize: '.8rem', fontWeight: 600 }}>
                    {a.preferred_name}
                    {(a.birth_year || a.death_year) && <span style={{ fontWeight: 400, color: 'var(--brand-muted, #aaa)' }}> ({a.birth_year || ''}{a.death_year ? `–${a.death_year}` : (a.birth_year ? '–' : '')})</span>}
                  </div>
                  <div style={{ fontSize: '.68rem', color: 'rgba(255,255,255,.45)' }}>
                    {[a.sort_name, a.country, `${a.match_kind} ${Math.round(a.score * 100)}%`].filter(Boolean).join(' · ')}
                  </div>
                </div>
              ))}
              <div style={{ display: 'flex', justifyContent: 'flex-end', padding: '4px 8px' }}>
                <button type="button" onClick={() => setAuthorSearch({ index: null, results: [], loading: false })}
                  style={{ background: 'none', border: 'none', color: 'var(--brand-muted, #888)', cursor: 'pointer', fontSize: '.7rem' }}>
                  {t({id:'catalogacao.authlink.close'})}
                </button>
              </div>
            </div>
          )}
        </div>
      ))}
      {/* Champ autor synthétisé (readonly) */}
      <input type="text" value={autor} readOnly
        style={{ width: '100%', padding: '5px 8px', borderRadius: 6, border: '1px solid rgba(255,255,255,.06)', background: 'rgba(0,0,0,.15)', color: 'var(--brand-muted, #aaa)', fontSize: '.78rem', marginTop: 4 }}
        title={t({ id: 'catalogacao.contributor.synthTitle' })}
      />
    </div>
  );
}
