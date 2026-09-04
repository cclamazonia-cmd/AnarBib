import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { languageLabel } from '@/lib/languages';

/**
 * Œuvre d'une notice publiée — deux gestes du 04/09/2026 (OPAC par œuvre) :
 *
 *  1. « Rattacher à une autre œuvre » (lot 1b) : chercher une œuvre par titre
 *     ou auteur·rice (search_works_for_link) et y rattacher la notice
 *     (assign_book_to_work, qui supprime l'œuvre quittée si elle reste vide).
 *  2. « Titres par langue » (lot 3) : les dix locales, chacune avec sa source
 *     (saisi / titre d'une édition / traduction automatique « corrige-moi »).
 *     Enregistrer un titre le rend manuel ; l'effacer rend la main au titre
 *     d'édition, puis au titre uniforme (set_work_title).
 *
 * Composant monté dans le formulaire de catalogage, sous la ligne « Œuvre ».
 * Aucune modale (les panneaux restent montés, masqués en CSS).
 */
const LOCALES = ['pt-BR', 'fr', 'es', 'it', 'en', 'de', 'ca', 'eo', 'nl', 'el'];

export default function WorkToolsBlock({ bookId, workId, onChanged, onMsg }) {
  const { formatMessage: t } = useIntl();

  // ── 1. Rattacher à une autre œuvre ──────────────────────────
  const [linkOpen, setLinkOpen] = useState(false);
  const [q, setQ] = useState('');
  const [results, setResults] = useState(null); // null = pas cherché
  const [searching, setSearching] = useState(false);
  const [linking, setLinking] = useState(null);

  useEffect(() => {
    if (!linkOpen) return;
    const term = q.trim();
    if (term.length < 2) { setResults(null); return; }
    let alive = true;
    const h = setTimeout(async () => {
      setSearching(true);
      try {
        const { data, error } = await supabase.rpc('search_works_for_link', { p_q: term, p_limit: 12 });
        if (error) throw error;
        if (alive) setResults((data || []).filter(r => r.work_id !== workId));
      } catch (err) {
        if (alive) { setResults([]); onMsg?.(t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), 'error'); }
      } finally { if (alive) setSearching(false); }
    }, 300);
    return () => { alive = false; clearTimeout(h); };
  }, [q, linkOpen, workId, t, onMsg]);

  async function link(targetWorkId) {
    if (!bookId) return;
    setLinking(targetWorkId);
    try {
      const { error } = await supabase.rpc('assign_book_to_work', { p_book_id: Number(bookId), p_work_id: Number(targetWorkId) });
      if (error) throw error;
      onMsg?.(t({ id: 'catalogacao.work.linked' }), 'ok');
      setLinkOpen(false); setQ(''); setResults(null);
      onChanged?.();
    } catch (err) {
      onMsg?.(t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), 'error');
    } finally { setLinking(null); }
  }

  // ── 2. Titres par langue, et le titre uniforme ───────────────
  // Décision 5 du 04/09/2026 : le titre uniforme s'écrit dans la langue de
  // l'œuvre elle-même (set_work_uniform_title) ; il ne s'affiche qu'aux locales
  // sans titre.
  const [titlesOpen, setTitlesOpen] = useState(false);
  const [titles, setTitles] = useState({});   // lang -> { title, source, needs_review }
  const [drafts, setDrafts] = useState({});   // lang -> saisie en cours
  const [saving, setSaving] = useState(null);
  const [uniform, setUniform] = useState('');       // titre uniforme en base
  const [uniformDraft, setUniformDraft] = useState('');

  const loadTitles = useCallback(async () => {
    if (!workId) { setTitles({}); setDrafts({}); setUniform(''); setUniformDraft(''); return; }
    const [{ data }, { data: w }] = await Promise.all([
      supabase.from('work_titles').select('lang, title, source, needs_review').eq('work_id', workId),
      supabase.from('works').select('uniform_title').eq('id', workId).maybeSingle(),
    ]);
    const m = {};
    for (const r of data || []) m[r.lang] = r;
    setTitles(m);
    setDrafts(Object.fromEntries(LOCALES.map(l => [l, m[l]?.title || ''])));
    setUniform(w?.uniform_title || ''); setUniformDraft(w?.uniform_title || '');
  }, [workId]);

  useEffect(() => { if (titlesOpen) loadTitles(); }, [titlesOpen, loadTitles]);

  async function saveUniform() {
    if (!workId) return;
    setSaving('__uniform__');
    try {
      const { error } = await supabase.rpc('set_work_uniform_title', { p_work_id: Number(workId), p_title: uniformDraft });
      if (error) throw error;
      onMsg?.(t({ id: 'catalogacao.work.uniformTitleSaved' }), 'ok');
      await loadTitles();
      onChanged?.();
    } catch (err) {
      onMsg?.(t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), 'error');
    } finally { setSaving(null); }
  }

  async function saveTitle(lang) {
    if (!workId) return;
    setSaving(lang);
    try {
      const { error } = await supabase.rpc('set_work_title', { p_work_id: Number(workId), p_lang: lang, p_title: drafts[lang] || '' });
      if (error) throw error;
      onMsg?.(t({ id: 'catalogacao.work.titleSaved' }), 'ok');
      await loadTitles();
    } catch (err) {
      onMsg?.(t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), 'error');
    } finally { setSaving(null); }
  }

  const inputStyle = {
    flex: '1 1 220px', minWidth: 0, padding: '5px 8px', borderRadius: 6,
    border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.25)', color: 'inherit', fontSize: '.82rem',
  };

  return (
    <div style={{ marginTop: 6, display: 'flex', flexDirection: 'column', gap: 6 }}>
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        <button type="button" className="ab-button ab-button--secondary ab-button--sm"
          onClick={() => setLinkOpen(o => !o)} aria-expanded={linkOpen}>
          {t({ id: 'catalogacao.work.linkOther' })}
        </button>
        {workId && (
          <button type="button" className="ab-button ab-button--secondary ab-button--sm"
            onClick={() => setTitlesOpen(o => !o)} aria-expanded={titlesOpen}>
            {t({ id: 'catalogacao.work.titles' })}
          </button>
        )}
      </div>

      {linkOpen && (
        <div style={{ border: '1px solid rgba(255,255,255,.08)', borderRadius: 8, padding: 8 }}>
          <input type="text" value={q} onChange={e => setQ(e.target.value)} style={{ ...inputStyle, width: '100%' }}
            placeholder={t({ id: 'catalogacao.work.linkSearchPlaceholder' })} autoFocus />
          {searching && <div style={{ fontSize: '.76rem', color: 'var(--brand-muted, #aaa)', marginTop: 4 }}>{t({ id: 'catalogacao.dedup.finding' })}</div>}
          {!searching && results !== null && results.length === 0 && (
            <div style={{ fontSize: '.76rem', color: 'var(--brand-muted, #aaa)', marginTop: 4 }}>{t({ id: 'catalogacao.work.linkNoResult' })}</div>
          )}
          {results && results.length > 0 && (
            <div style={{ marginTop: 6, display: 'flex', flexDirection: 'column' }}>
              {results.map(r => (
                <div key={r.work_id} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '5px 4px', borderTop: '1px solid rgba(255,255,255,.05)' }}>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: '.82rem' }}>{r.uniform_title}</div>
                    <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #aaa)' }}>
                      {[r.author_name, t({ id: 'catalogacao.work.editions' }, { count: r.editions || 0 }), r.years].filter(Boolean).join(' · ')}
                    </div>
                  </div>
                  <button type="button" className="ab-button ab-button--sm" disabled={linking != null}
                    onClick={() => link(r.work_id)}>
                    {linking === r.work_id ? '…' : t({ id: 'catalogacao.work.link' })}
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {titlesOpen && workId && (
        <div style={{ border: '1px solid rgba(255,255,255,.08)', borderRadius: 8, padding: 8 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap', padding: '3px 0', marginBottom: 6, borderBottom: '1px solid rgba(255,255,255,.08)' }}>
            <span style={{ width: 120, fontSize: '.78rem', fontWeight: 600, flex: '0 0 auto' }} title={t({ id: 'catalogacao.work.uniformTitleHint' })}>
              {t({ id: 'catalogacao.work.uniformTitle' })}
            </span>
            <input type="text" value={uniformDraft} style={inputStyle} title={t({ id: 'catalogacao.work.uniformTitleHint' })}
              onChange={e => setUniformDraft(e.target.value)} />
            {uniformDraft.trim() !== uniform && uniformDraft.trim() && (
              <button type="button" className="ab-button ab-button--sm" disabled={saving != null} onClick={saveUniform}>
                {saving === '__uniform__' ? '…' : t({ id: 'catalogacao.work.titleSave' })}
              </button>
            )}
          </div>
          <div style={{ fontSize: '.74rem', color: 'var(--brand-muted, #aaa)', marginBottom: 6 }}>{t({ id: 'catalogacao.work.titlesHint' })}</div>
          {LOCALES.map(lang => {
            const cur = titles[lang];
            const dirty = (drafts[lang] ?? '') !== (cur?.title ?? '');
            return (
              <div key={lang} style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap', padding: '3px 0' }}>
                <span style={{ width: 120, fontSize: '.78rem', flex: '0 0 auto' }}>{languageLabel(lang, t) || lang}</span>
                <input type="text" value={drafts[lang] ?? ''} style={inputStyle}
                  onChange={e => setDrafts(d => ({ ...d, [lang]: e.target.value }))} />
                {cur && (
                  <span style={{ fontSize: '.66rem', color: cur.source === 'auto' ? 'var(--color-warn, #eab308)' : 'var(--brand-muted, #aaa)' }}>
                    {t({ id: `catalogacao.work.titleSource.${cur.source}` })}
                  </span>
                )}
                {dirty && (
                  <button type="button" className="ab-button ab-button--sm" disabled={saving != null} onClick={() => saveTitle(lang)}>
                    {saving === lang ? '…' : t({ id: 'catalogacao.work.titleSave' })}
                  </button>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
