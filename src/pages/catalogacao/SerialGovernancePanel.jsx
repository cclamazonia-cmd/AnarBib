import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import SerialDetailEditor from './SerialDetailEditor';
import SerialDuplicatesPanel from './SerialDuplicatesPanel';

// ═══════════════════════════════════════════════════════════════════════════
// SerialGovernancePanel — coordination des titres de périodiques.
//
// Ce fichier ne fait plus que trois choses : lister les titres, promouvoir ou
// déprécier, et déplier. Tout ce qu'on peut faire SUR un titre est dans
// SerialDetailEditor ; les doublons sont dans SerialDuplicatesPanel. Le
// découpage n'est pas cosmétique : la liste doit rester lisible d'un coup
// d'œil, et c'est elle qu'on ouvre pour traiter la file des titres proposés.
//
// DEUX GESTES, DEUX RÔLES DIFFÉRENTS, et c'est délibéré :
//   · PROMOUVOIR / DÉPRÉCIER un titre → coordination catalogage
//     (fn_is_catalog_coordinator, gardé serveur). Décision de RÉSEAU : le
//     titre est une autorité partagée.
//   · DÉCLARER l'état de collection → coordination DE LA BIBLIOTHÈQUE
//     (fn_team_caller_is_coordenador, gardé serveur). Déclaration LOCALE :
//     seule la bibliothèque sait ce qu'elle possède.
// Le panneau n'affiche que les gestes réellement permis — plutôt que des
// boutons qui lèveraient. Les gardes restent tenues serveur ; l'interface se
// contente de ne pas mentir.
//
// La LECTURE reste ouverte à tout le staff catalogage : voir quels titres
// existent est ce qui évite d'en recréer un doublon à la saisie suivante.
//
// `isActive` : tous les panneaux du catalogage restent montés (masqués en CSS
// seulement), on ne charge donc qu'à l'ouverture.
// ═══════════════════════════════════════════════════════════════════════════

function yearSpan(s) {
  // Le tiret ouvert dit « paraît toujours » ; son absence ne dit rien plutôt
  // que de laisser croire à une fin.
  if (s.start_year && s.end_year) return `${s.start_year}–${s.end_year}`;
  if (s.start_year && s.is_continuing) return `${s.start_year}–`;
  return s.start_year || (s.end_year ? `–${s.end_year}` : '');
}

export default function SerialGovernancePanel({ isActive }) {
  const { formatMessage: t } = useIntl();
  const [serials, setSerials] = useState([]);
  const [isCoord, setIsCoord] = useState(false);
  const [myLibraries, setMyLibraries] = useState([]);
  const [loading, setLoading] = useState(true);
  const [loaded, setLoaded] = useState(false);
  const [busy, setBusy] = useState(null);
  const [msg, setMsg] = useState(null);
  const [openId, setOpenId] = useState(null);
  const [filtre, setFiltre] = useState('');

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

  const badge = (status) => (
    <span style={{
      fontSize: '.62rem', textTransform: 'uppercase', letterSpacing: '.03em',
      padding: '1px 6px', borderRadius: 4, whiteSpace: 'nowrap',
      background: status === 'ativo' ? 'rgba(74,222,128,.16)' : 'rgba(255,255,255,.12)',
      color: status === 'ativo' ? '#4ade80' : 'var(--brand-muted, #bbb)',
    }}>{t({ id: `catalogacao.serialGov.status.${status}` })}</span>
  );

  const q = filtre.trim().toLowerCase();
  const visibles = q
    ? serials.filter(s => (s.uniform_title || '').toLowerCase().includes(q)
        || (s.slug || '').includes(q) || (s.issn || '').includes(q))
    : serials;

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

      {/* Un filtre plutôt qu'une pagination : la centaine de titres d'Anarchief
          tiendra dans une liste, mais pas dans un coup d'œil. */}
      {serials.length > 8 && (
        <input className="ab-input" type="search" value={filtre} style={{ marginBottom: 10 }}
          placeholder={t({ id: 'catalogacao.serialGov.filterPh' })}
          onChange={e => setFiltre(e.target.value)} />
      )}

      {loading ? (
        <div className="cat-placeholder">{t({ id: 'common.loading' })}</div>
      ) : visibles.length === 0 ? (
        <div className="cat-placeholder">
          {t({ id: serials.length === 0 ? 'catalogacao.serialGov.empty' : 'catalogacao.serialGov.noMatch' })}
        </div>
      ) : (
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '.84rem' }}>
          <tbody>
            {visibles.map(s => {
              const open = openId === s.id;
              return [
                <tr key={s.id} style={{ borderBottom: '1px solid rgba(255,255,255,.07)' }}>
                  <td style={{ padding: '8px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                      <button type="button" onClick={() => setOpenId(open ? null : s.id)}
                        style={titleBtn} aria-expanded={open}>
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
                  <tr key={`${s.id}-d`}>
                    <td colSpan={2} style={{ padding: '0 8px 16px 4px' }}>
                      <SerialDetailEditor serial={s} myLibraries={myLibraries} onChanged={load} />
                    </td>
                  </tr>
                ),
              ];
            })}
          </tbody>
        </table>
      )}

      <SerialDuplicatesPanel isActive={isActive} onChanged={load} />
    </div>
  );
}

const sub = { fontSize: '.74rem', color: 'var(--brand-muted, #999)', marginTop: 2 };
const btnSm = { marginLeft: 6, fontSize: '.75rem', padding: '4px 10px' };
const notice = { fontSize: '.8rem', color: 'var(--brand-muted, #999)', padding: '8px 12px', borderRadius: 8, background: 'rgba(255,255,255,.04)', marginBottom: 12 };
const titleBtn = { background: 'transparent', border: 'none', color: 'var(--brand-text, #f5f2ea)', cursor: 'pointer', font: 'inherit', fontWeight: 600, padding: 0, textAlign: 'left' };
