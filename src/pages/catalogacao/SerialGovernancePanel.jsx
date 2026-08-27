import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

// ═══════════════════════════════════════════════════════════════════════════
// SerialGovernancePanel — coordination des titres de périodiques.
//
// POURQUOI CE PANNEAU EXISTE. Les paquets P1→P9 (27/08/2026) ont livré
// api.fn_serial_set_status et api.fn_serial_upsert_holdings sans AUCUN
// appelant côté interface. Conséquence pratique : un titre créé à la volée au
// catalogage naissait `proposto` — donc invisible du public — et rien dans
// l'app ne permettait de le promouvoir. Même trou pour l'état de collection
// déclaré, qui est pourtant l'information qui décide d'une demande de PEB.
// Deux RPC sans surface, c'est une fonctionnalité qui ne boucle pas.
//
// DEUX GESTES, DEUX RÔLES DIFFÉRENTS, et c'est délibéré :
//   · PROMOUVOIR / DÉPRÉCIER un titre → coordination catalogage
//     (fn_is_catalog_coordinator, gardé serveur). C'est une décision de
//     RÉSEAU : le titre est une autorité partagée.
//   · DÉCLARER l'état de collection → coordination DE LA BIBLIOTHÈQUE
//     concernée (fn_team_caller_is_coordenador, gardé serveur). C'est une
//     déclaration LOCALE : seule la bibliothèque sait ce qu'elle possède.
// Le panneau se lit donc différemment selon qui l'ouvre, et n'affiche que les
// gestes réellement permis — plutôt que des boutons qui lèveraient.
//
// LA DOCTRINE DU DÉCLARÉ EST RENDUE VISIBLE ICI. Le calculé s'affiche à côté
// du champ de saisie, en lecture seule et annoncé comme calculé. On ne
// pré-remplit PAS le déclaré avec lui : ce serait faire dire à la bibliothèque
// une chose qu'elle n'a pas dite. Le calcul ne sait pas qu'une lacune est
// définitive ; une archive, si.
//
// `isActive` est indispensable : tous les panneaux du catalogage restent
// montés (masqués en CSS seulement), on ne charge donc qu'à l'ouverture.
// ═══════════════════════════════════════════════════════════════════════════

const COMPLETENESS = ['completa', 'quase_completa', 'parcial', 'esparsa', 'desconhecida'];

// Dates de parution, même règle que la page publique : le tiret ouvert dit
// « paraît toujours », son absence ne dit rien plutôt que de laisser croire à
// une fin.
function yearSpan(s) {
  if (s.start_year && s.end_year) return `${s.start_year}–${s.end_year}`;
  if (s.start_year && s.is_continuing) return `${s.start_year}–`;
  return s.start_year || (s.end_year ? `–${s.end_year}` : '');
}

export default function SerialGovernancePanel({ isActive }) {
  const { formatMessage: t } = useIntl();
  const [serials, setSerials] = useState([]);
  const [isCoord, setIsCoord] = useState(false);
  const [myLibraries, setMyLibraries] = useState([]); // bibliothèques où je coordonne
  const [loading, setLoading] = useState(true);
  const [loaded, setLoaded] = useState(false);
  const [busy, setBusy] = useState(null);
  const [msg, setMsg] = useState(null);
  const [openId, setOpenId] = useState(null);
  const [holdings, setHoldings] = useState({});  // serial_id -> [lignes]
  const [drafts, setDrafts] = useState({});      // `${serial_id}:${library_id}` -> formulaire

  const load = useCallback(async () => {
    setLoading(true);
    const api = supabase.schema('api');
    const [srv, coordRes, memRes] = await Promise.all([
      api.from('serials_list_v1')
        .select('id, slug, uniform_title, status, issn, start_year, end_year, is_continuing, emitter_org, periodicidade, issues_count')
        .order('uniform_title'),
      supabase.rpc('fn_is_catalog_coordinator'),
      api.rpc('fn_my_memberships_status'),
    ]);
    const rows = Array.isArray(srv.data) ? srv.data : [];
    // Les titres PROPOSÉS d'abord : c'est ce que ce panneau sert à traiter.
    rows.sort((a, b) => (a.status === 'proposto' ? 0 : 1) - (b.status === 'proposto' ? 0 : 1)
      || (a.uniform_title || '').localeCompare(b.uniform_title || ''));
    setSerials(rows);
    setIsCoord(coordRes.data === true);
    setMyLibraries((Array.isArray(memRes.data) ? memRes.data : [])
      .filter(m => m.role === 'coordenador' && m.status === 'active'));
    setLoading(false);
    setLoaded(true);
  }, []);

  useEffect(() => { if (isActive && !loaded) load(); }, [isActive, loaded, load]);

  async function setStatus(id, status) {
    setBusy(id); setMsg(null);
    const { error } = await supabase.schema('api')
      .rpc('fn_serial_set_status', { p_serial_id: id, p_status: status });
    if (error) {
      setMsg({ text: localizeError(error, t, 'catalogacao.serialGov.statusFailed'), kind: 'error' });
    } else {
      setSerials(prev => prev.map(s => (s.id === id ? { ...s, status } : s)));
      setMsg({ text: t({ id: 'catalogacao.serialGov.statusUpdated' }), kind: 'ok' });
    }
    setBusy(null);
  }

  async function toggle(serial) {
    if (openId === serial.id) { setOpenId(null); return; }
    setOpenId(serial.id);
    if (holdings[serial.id]) return;
    const { data } = await supabase.schema('api').from('serial_holdings_public_v1')
      .select('*').eq('serial_id', serial.id);
    const rows = Array.isArray(data) ? data : [];
    setHoldings(prev => ({ ...prev, [serial.id]: rows }));
    // Un brouillon par bibliothèque que je coordonne, pré-rempli avec le
    // DÉCLARÉ existant uniquement — jamais avec le calculé.
    setDrafts(prev => {
      const next = { ...prev };
      for (const lib of myLibraries) {
        const row = rows.find(r => r.library_id === lib.library_id);
        next[`${serial.id}:${lib.library_id}`] = {
          statement: row?.statement || '',
          gaps_note: row?.gaps_note || '',
          completeness: row?.completeness || 'desconhecida',
          is_public: row ? row.is_public !== false : true,
        };
      }
      return next;
    });
  }

  function setDraft(key, patch) {
    setDrafts(prev => ({ ...prev, [key]: { ...prev[key], ...patch } }));
  }

  async function saveHoldings(serialId, libraryId) {
    const key = `${serialId}:${libraryId}`;
    const d = drafts[key];
    if (!d) return;
    setBusy(key); setMsg(null);
    const { error } = await supabase.schema('api').rpc('fn_serial_upsert_holdings', {
      p_serial_id: serialId,
      p_library_id: libraryId,
      p_statement: d.statement || null,
      p_gaps_note: d.gaps_note || null,
      p_completeness: d.completeness,
      p_is_public: d.is_public,
    });
    if (error) {
      setMsg({ text: localizeError(error, t, 'catalogacao.serialGov.holdings.failed'), kind: 'error' });
    } else {
      const { data } = await supabase.schema('api').from('serial_holdings_public_v1')
        .select('*').eq('serial_id', serialId);
      setHoldings(prev => ({ ...prev, [serialId]: Array.isArray(data) ? data : [] }));
      setMsg({ text: t({ id: 'catalogacao.serialGov.holdings.saved' }), kind: 'ok' });
    }
    setBusy(null);
  }

  const badge = (status) => (
    <span style={{
      fontSize: '.62rem', textTransform: 'uppercase', letterSpacing: '.03em',
      padding: '1px 6px', borderRadius: 4, whiteSpace: 'nowrap',
      background: status === 'ativo' ? 'rgba(74,222,128,.16)' : 'rgba(255,255,255,.12)',
      color: status === 'ativo' ? '#4ade80' : 'var(--brand-muted, #bbb)',
    }}>{t({ id: `catalogacao.serialGov.status.${status}` })}</span>
  );

  return (
    <div>
      <div className="cat-panel-header"><h3>{t({ id: 'catalogacao.serialGov.title' })}</h3></div>
      <p style={{ fontSize: '.85rem', color: 'var(--brand-muted, #aaa)', marginTop: 0 }}>
        {t({ id: 'catalogacao.serialGov.intro' })}
      </p>

      {loaded && !isCoord && (
        <div style={notice}>{t({ id: 'catalogacao.serialGov.coordOnly' })}</div>
      )}
      {msg && (
        <div style={{ marginBottom: 10, fontSize: '.82rem', color: msg.kind === 'error' ? '#f87171' : '#4ade80' }}>
          {msg.text}
        </div>
      )}

      {loading ? (
        <div className="cat-placeholder">{t({ id: 'common.loading' })}</div>
      ) : serials.length === 0 ? (
        <div className="cat-placeholder">{t({ id: 'catalogacao.serialGov.empty' })}</div>
      ) : (
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '.84rem' }}>
          <tbody>
            {serials.map(s => {
              const rows = holdings[s.id] || [];
              const open = openId === s.id;
              return [
                <tr key={s.id} style={{ borderBottom: '1px solid rgba(255,255,255,.07)' }}>
                  <td style={{ padding: '8px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                      <button type="button" onClick={() => toggle(s)} style={titleBtn}
                        aria-expanded={open}>
                        {open ? '▾' : '▸'} {s.uniform_title}
                      </button>
                      {badge(s.status)}
                    </div>
                    <div style={sub}>
                      {[yearSpan(s), s.emitter_org, s.issn && `ISSN ${s.issn}`, s.periodicidade]
                        .filter(Boolean).join(' · ')}
                    </div>
                    <div style={sub}>
                      {t({ id: 'catalogacao.serialGov.issues' }, { count: s.issues_count || 0 })}
                      {s.status === 'ativo' && (
                        <> · <Link to={`/periodico/${s.slug}`} style={{ color: '#93c5fd' }}>
                          {t({ id: 'catalogacao.serialGov.viewPublic' })}
                        </Link></>
                      )}
                    </div>
                  </td>
                  <td style={{ padding: '8px', textAlign: 'right', whiteSpace: 'nowrap' }}>
                    {isCoord && s.status !== 'ativo' && (
                      <button className="ab-button ab-button--secondary" style={btnSm}
                        disabled={busy === s.id} onClick={() => setStatus(s.id, 'ativo')}>
                        {t({ id: 'catalogacao.serialGov.promote' })}
                      </button>
                    )}
                    {isCoord && s.status !== 'depreciado' && (
                      <button className="ab-button ab-button--ghost" style={{ ...btnSm, color: '#f87171' }}
                        disabled={busy === s.id} onClick={() => setStatus(s.id, 'depreciado')}>
                        {t({ id: 'catalogacao.serialGov.deprecate' })}
                      </button>
                    )}
                  </td>
                </tr>,
                open && (
                  <tr key={`${s.id}-h`}>
                    <td colSpan={2} style={{ padding: '0 8px 14px 20px' }}>
                      <div style={{ fontSize: '.78rem', textTransform: 'uppercase', letterSpacing: '.05em',
                        color: 'var(--brand-muted, #999)', fontWeight: 700, margin: '4px 0 6px' }}>
                        {t({ id: 'catalogacao.serialGov.holdings' })}
                      </div>
                      <p style={{ ...sub, marginTop: 0 }}>{t({ id: 'catalogacao.serialGov.holdings.declaredWins' })}</p>

                      {/* Ce que les autres bibliothèques déclarent : en lecture. */}
                      {rows.filter(r => !myLibraries.some(l => l.library_id === r.library_id)).map(r => (
                        <div key={r.library_id} style={otherLib}>
                          <strong>{r.library_name || r.library_slug}</strong>
                          <div>{r.has_statement ? r.statement : t({ id: 'catalogacao.serialGov.holdings.computed' }, {
                            first: r.computed_first || '?', last: r.computed_last || '?', count: r.computed_count || 0,
                          })}</div>
                        </div>
                      ))}

                      {myLibraries.length === 0 ? (
                        <div style={notice}>{t({ id: 'catalogacao.serialGov.holdings.noLibrary' })}</div>
                      ) : myLibraries.map(lib => {
                        const key = `${s.id}:${lib.library_id}`;
                        const d = drafts[key] || { statement: '', gaps_note: '', completeness: 'desconhecida', is_public: true };
                        const row = rows.find(r => r.library_id === lib.library_id);
                        return (
                          <div key={lib.library_id} style={myLib}>
                            <div style={{ fontWeight: 600, marginBottom: 4 }}>{lib.library_name || lib.library_slug}</div>
                            {/* Le calculé, à côté et jamais à la place. */}
                            <div style={{ ...sub, marginBottom: 6 }}>
                              {t({ id: 'catalogacao.serialGov.holdings.computed' }, {
                                first: row?.computed_first || '?', last: row?.computed_last || '?',
                                count: row?.computed_count || 0,
                              })}
                            </div>
                            <label style={lbl}>{t({ id: 'catalogacao.serialGov.holdings.statement' })}</label>
                            <textarea className="ab-input" rows={2} value={d.statement}
                              placeholder={t({ id: 'catalogacao.serialGov.holdings.statementPh' })}
                              onChange={e => setDraft(key, { statement: e.target.value })} />
                            <label style={lbl}>{t({ id: 'catalogacao.serialGov.holdings.gaps' })}</label>
                            <input className="ab-input" type="text" value={d.gaps_note}
                              onChange={e => setDraft(key, { gaps_note: e.target.value })} />
                            <div style={{ display: 'flex', gap: 14, alignItems: 'flex-end', flexWrap: 'wrap', marginTop: 6 }}>
                              <div>
                                <label style={lbl}>{t({ id: 'catalogacao.serialGov.holdings.completeness' })}</label>
                                <select className="ab-input" value={d.completeness}
                                  onChange={e => setDraft(key, { completeness: e.target.value })}>
                                  {COMPLETENESS.map(c => (
                                    <option key={c} value={c}>
                                      {c === 'desconhecida'
                                        ? t({ id: 'catalogacao.serialGov.holdings.unknown' })
                                        : t({ id: `serial.completeness.${c}` })}
                                    </option>
                                  ))}
                                </select>
                              </div>
                              <label style={{ fontSize: '.8rem', display: 'flex', alignItems: 'center', gap: 6 }}>
                                <input type="checkbox" checked={d.is_public}
                                  onChange={e => setDraft(key, { is_public: e.target.checked })} />
                                {t({ id: 'catalogacao.serialGov.holdings.isPublic' })}
                              </label>
                              <button className="ab-button ab-button--secondary" style={btnSm}
                                disabled={busy === key} onClick={() => saveHoldings(s.id, lib.library_id)}>
                                {t({ id: 'catalogacao.serialGov.holdings.save' })}
                              </button>
                            </div>
                          </div>
                        );
                      })}
                    </td>
                  </tr>
                ),
              ];
            })}
          </tbody>
        </table>
      )}
    </div>
  );
}

const sub = { fontSize: '.74rem', color: 'var(--brand-muted, #999)', marginTop: 2 };
const btnSm = { marginLeft: 6, fontSize: '.75rem', padding: '4px 10px' };
const lbl = { display: 'block', fontSize: '.74rem', color: 'var(--brand-muted, #999)', margin: '6px 0 2px' };
const notice = { fontSize: '.8rem', color: 'var(--brand-muted, #999)', padding: '8px 12px', borderRadius: 8, background: 'rgba(255,255,255,.04)', marginBottom: 12 };
const otherLib = { fontSize: '.8rem', color: 'var(--brand-muted, #bbb)', borderLeft: '2px solid rgba(255,255,255,.12)', paddingLeft: 10, marginBottom: 8 };
const myLib = { border: '1px solid rgba(255,255,255,.12)', borderRadius: 8, padding: '10px 12px', marginBottom: 10 };
const titleBtn = { background: 'transparent', border: 'none', color: 'var(--brand-text, #f5f2ea)', cursor: 'pointer', font: 'inherit', fontWeight: 600, padding: 0, textAlign: 'left' };
