// Rattacher une autorité publiée aux œuvres où son nom figure — sorti d'AuthorDraftForm.jsx tel quel (E6, 23/10/2026). Le panneau garde ses
// résultats et sa sélection ; monté avec key={authorId}, il repart de zéro pour
// une autre autorité (avant, les résultats d'une autre restaient affichés).
// Garde : src/tests/autorite-panneaux-montes.test.js.
import { useState } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

export default function AuthorBookLinksPanel({ authorId, onMessage }) {
  const { formatMessage: t } = useIntl();
  // Rattachement aux oeuvres (liaison autorite<->livres)
  const [linkMatches, setLinkMatches] = useState(null); // null = pas cherche ; [] = cherche, vide
  const [linkLoading, setLinkLoading] = useState(false);
  const [linkSelected, setLinkSelected] = useState(new Set());
  const [linkBusy, setLinkBusy] = useState(false);

  // ── Rattachement aux oeuvres (liaison autorite<->livres) ────────────────
  async function findAuthorBookMatches() {
    if (!authorId) return;
    setLinkLoading(true); setLinkSelected(new Set());
    try {
      const { data, error } = await supabase.rpc('suggest_author_book_matches', { p_author_id: Number(authorId) });
      if (error) throw error;
      setLinkMatches(data || []);
      // Pre-cocher les correspondances exactes (validation humaine = un clic global).
      setLinkSelected(new Set((data || []).filter(m => m.match_kind === 'exact').map(m => m.contributor_id)));
    } catch (err) {
      onMessage({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setLinkLoading(false); }
  }

  async function confirmAuthorLinks() {
    if (!authorId || linkSelected.size === 0) return;
    setLinkBusy(true);
    let ok = 0;
    try {
      for (const cid of linkSelected) {
        const { error } = await supabase.rpc('confirm_author_book_link', {
          p_author_id: Number(authorId), p_contributor_id: Number(cid),
        });
        if (!error) ok++;
      }
      onMessage({ text: t({ id: 'catalogacao.link.confirmed' }, { count: ok }), kind: 'ok' });
      await findAuthorBookMatches(); // rafraichir (les rattaches disparaissent de la liste)
    } catch (err) {
      onMessage({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setLinkBusy(false); }
  }

  return (
    <>
          {/* ── Rattacher aux oeuvres (liaison autorite<->livres) ─────── */}
          {authorId && (
            <div className="cat-field" style={{ gridColumn: 'span 3' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap', marginBottom: 6 }}>
                <span style={{ fontWeight: 600, fontSize: '.88rem' }}>{t({ id: 'catalogacao.link.title' })}</span>
                <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                  onClick={findAuthorBookMatches} disabled={linkLoading}>
                  {linkLoading ? t({ id: 'catalogacao.link.finding' }) : t({ id: 'catalogacao.link.find' })}
                </button>
              </div>
              {linkMatches !== null && linkMatches.length === 0 && (
                <div style={{ fontSize: '.8rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.link.none' })}</div>
              )}
              {linkMatches !== null && linkMatches.length > 0 && (
                <>
                  <div style={{ border: '1px solid rgba(255,255,255,.08)', borderRadius: 8, overflow: 'hidden', maxHeight: 280, overflowY: 'auto' }}>
                    {linkMatches.map(m => {
                      const sel = linkSelected.has(m.contributor_id);
                      return (
                        <label key={m.contributor_id} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 10px', cursor: 'pointer', borderBottom: '1px solid rgba(255,255,255,.04)', background: sel ? 'rgba(29,78,216,.1)' : 'transparent' }}>
                          <input type="checkbox" checked={sel} onChange={() => setLinkSelected(prev => { const n = new Set(prev); n.has(m.contributor_id) ? n.delete(m.contributor_id) : n.add(m.contributor_id); return n; })} />
                          <span style={{ flex: 1, minWidth: 0, fontSize: '.82rem' }}>{m.book_title}</span>
                          <span style={{ fontSize: '.72rem', color: 'var(--brand-muted, #aaa)' }}>{m.contributor_name}</span>
                          <span className={`cat-pill ${m.match_kind === 'exact' ? 'ok' : 'warn'}`} style={{ fontSize: '.6rem' }}>
                            {t({ id: m.match_kind === 'exact' ? 'catalogacao.link.exact' : 'catalogacao.link.approx' })} {Math.round(m.score * 100)}%
                          </span>
                        </label>
                      );
                    })}
                  </div>
                  <button type="button" className="ab-button ab-button--sm" style={{ marginTop: 8 }}
                    onClick={confirmAuthorLinks} disabled={linkBusy || linkSelected.size === 0}>
                    {linkBusy ? '…' : t({ id: 'catalogacao.link.confirm' }, { count: linkSelected.size })}
                  </button>
                </>
              )}
            </div>
          )}
    </>
  );
}
