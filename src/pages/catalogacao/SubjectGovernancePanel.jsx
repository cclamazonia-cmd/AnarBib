import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

// ═══════════════════════════════════════════════════════════════════════════
// SubjectGovernancePanel — thésaurus v1 étape 2c : coordination matière.
//
// Les termes proposés au catalogage (subjects.status = 'proposto') attendent ici
// leur activation. LECTURE pour tout staff catalogage (transparence, évite les
// doublons) ; ACTIVATION / DÉPRÉCIATION réservées à la coordination catalogage
// (api.fn_subject_set_status, gardé serveur par fn_is_catalog_coordinator). Le
// défaut penche vers « oui, et » : on active + on range, plutôt que « non » sec.
// ═══════════════════════════════════════════════════════════════════════════

function localizedLabel(labelI18n, locale) {
  if (!labelI18n || typeof labelI18n !== 'object') return '';
  return labelI18n[locale]
    || labelI18n[(locale || '').split('-')[0]]
    || labelI18n['pt-BR']
    || Object.values(labelI18n)[0]
    || '';
}

export default function SubjectGovernancePanel() {
  const { formatMessage: t, locale } = useIntl();
  const [proposed, setProposed] = useState([]);
  const [isCoord, setIsCoord] = useState(false);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(null);
  const [msg, setMsg] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    const [subsRes, coordRes] = await Promise.all([
      supabase.from('subjects')
        .select('id, slug, label_i18n, scope_note, created_at')
        .eq('status', 'proposto').order('created_at', { ascending: true }),
      supabase.rpc('fn_is_catalog_coordinator'),
    ]);
    setProposed(subsRes.data || []);
    setIsCoord(coordRes.data === true);
    setLoading(false);
  }, []);
  useEffect(() => { load(); }, [load]);

  async function setStatus(id, status) {
    setBusy(id);
    setMsg(null);
    const { error } = await supabase.schema('api').rpc('fn_subject_set_status', { p_subject_id: id, p_status: status });
    if (error) { setMsg({ text: localizeError(error, t), kind: 'error' }); }
    else {
      setProposed(prev => prev.filter(s => s.id !== id));
      setMsg({ text: t({ id: 'catalogacao.subjectGov.statusUpdated' }), kind: 'ok' });
    }
    setBusy(null);
  }

  const fmtDate = (d) => { try { return new Date(d).toLocaleDateString(locale); } catch { return d; } };

  return (
    <div>
      <div className="cat-panel-header"><h3>{t({ id: 'catalogacao.subjectGov.title' })}</h3></div>
      <p style={{ fontSize: '.85rem', color: 'var(--brand-muted, #aaa)', marginTop: 0 }}>
        {t({ id: 'catalogacao.subjectGov.intro' })}
      </p>

      {!loading && !isCoord && (
        <div style={{ fontSize: '.8rem', color: 'var(--brand-muted, #999)', padding: '8px 12px', borderRadius: 8, background: 'rgba(255,255,255,.04)', marginBottom: 12 }}>
          {t({ id: 'catalogacao.subjectGov.coordOnly' })}
        </div>
      )}
      {msg && <div style={{ marginBottom: 10, fontSize: '.82rem', color: msg.kind === 'error' ? '#f87171' : '#4ade80' }}>{msg.text}</div>}

      {loading ? (
        <div className="cat-placeholder">{t({ id: 'common.loading' })}</div>
      ) : proposed.length === 0 ? (
        <div className="cat-placeholder">{t({ id: 'catalogacao.subjectGov.empty' })}</div>
      ) : (
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '.84rem' }}>
          <tbody>
            {proposed.map(s => (
              <tr key={s.id} style={{ borderBottom: '1px solid rgba(255,255,255,.07)' }}>
                <td style={{ padding: '8px' }}>
                  <div style={{ fontWeight: 600 }}>{localizedLabel(s.label_i18n, locale)}</div>
                  {s.scope_note && <div style={{ fontSize: '.74rem', color: 'var(--brand-muted, #999)' }}>{s.scope_note}</div>}
                  <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #777)' }}>
                    {t({ id: 'catalogacao.subjectGov.proposedAt' }, { date: fmtDate(s.created_at) })}
                  </div>
                </td>
                <td style={{ padding: '8px', textAlign: 'right', whiteSpace: 'nowrap' }}>
                  {isCoord && (
                    <>
                      <button className="ab-button ab-button--secondary" style={{ marginRight: 6, fontSize: '.75rem', padding: '4px 10px' }}
                        disabled={busy === s.id} onClick={() => setStatus(s.id, 'ativo')}>
                        {t({ id: 'catalogacao.subjectGov.activate' })}
                      </button>
                      <button className="ab-button ab-button--ghost" style={{ fontSize: '.75rem', padding: '4px 10px', color: '#f87171' }}
                        disabled={busy === s.id} onClick={() => setStatus(s.id, 'depreciado')}>
                        {t({ id: 'catalogacao.subjectGov.deprecate' })}
                      </button>
                    </>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
