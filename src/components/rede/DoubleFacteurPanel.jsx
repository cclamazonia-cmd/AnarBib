// ============================================================================
// src/components/rede/DoubleFacteurPanel.jsx — B42, lot 2 (13/10/2026)
// ============================================================================
//
// Onglet « Double authentification » de RedePage (administration du réseau).
//
//   * L'exigence en vigueur (mode du serveur : off / facteurs / equipes), lue
//     par api.fn_mon_etat_double_facteur.
//   * Les comptes d'équipe actifs (administration du réseau, bibliothécaires,
//     coordinations) et les comptes qui ont choisi la double authentification,
//     ceux SANS appareil d'abord : de quoi préparer et suivre la bascule
//     (api.fn_admin_double_facteur_comptes).
//   * Retirer les appareils d'un compte (appareil perdu), APRÈS avoir vérifié
//     l'identité de la personne par un autre moyen : motif obligatoire,
//     journalisé ; le compte est déconnecté partout ; l'administration doit
//     elle-même être en aal2 (api.fn_admin_retirer_double_facteur).
// ============================================================================

import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { apiRpc } from '@/lib/supabase';
import { Button } from '@/components/ui';

const TH = { textAlign: 'left', padding: '6px 8px', fontSize: '.8rem', color: 'var(--brand-muted)', borderBottom: '1px solid rgba(255,255,255,.12)' };
const TD = { padding: '8px', verticalAlign: 'top', borderBottom: '1px solid rgba(255,255,255,.06)' };

// Un refus de PostgREST arrive en texte JSON dans error.message (apiRpc).
function cleRefus(error) {
  let msg = '';
  try { msg = JSON.parse(error?.message ?? '{}').message ?? ''; } catch { msg = String(error?.message ?? ''); }
  if (msg.includes('aal2_required')) return 'twoFactor.error.needCode';
  if (msg.includes('motif_required')) return 'twoFactor.admin.motifRequired';
  return 'twoFactor.error.generic';
}

export default function DoubleFacteurPanel() {
  const { formatMessage: t, formatDate } = useIntl();
  const [comptes, setComptes] = useState(null);
  const [mode, setMode] = useState(null);
  const [erreur, setErreur] = useState('');
  const [ouvert, setOuvert] = useState(null);
  const [motif, setMotif] = useState('');
  const [enCours, setEnCours] = useState(false);
  const [msg, setMsg] = useState({ text: '', err: false });

  const charger = useCallback(async () => {
    const [liste, etat] = await Promise.all([
      apiRpc('fn_admin_double_facteur_comptes'),
      apiRpc('fn_mon_etat_double_facteur'),
    ]);
    if (liste.error) { setErreur(t({ id: cleRefus(liste.error) })); setComptes([]); }
    else { setErreur(''); setComptes(liste.data ?? []); }
    setMode(etat.error ? null : etat.data?.mode ?? null);
  }, [t]);

  useEffect(() => { charger(); }, [charger]);

  async function retirer(e, compte) {
    e.preventDefault();
    if (motif.trim().length < 10) {
      setMsg({ text: t({ id: 'twoFactor.admin.motifRequired' }), err: true });
      return;
    }
    setEnCours(true);
    setMsg({ text: '', err: false });
    const { data, error } = await apiRpc('fn_admin_retirer_double_facteur', { p_user: compte.user_id, p_motif: motif.trim() });
    setEnCours(false);
    if (error) { setMsg({ text: t({ id: cleRefus(error) }), err: true }); return; }
    setOuvert(null);
    setMotif('');
    setMsg({ text: t({ id: 'twoFactor.admin.done' }, { n: data?.facteurs_retires ?? 0 }), err: false });
    await charger();
  }

  const sansAppareil = (comptes ?? []).filter((c) => c.facteurs === 0).length;

  return (
    <section data-testid="rede-double-facteur">
      <h3 style={{ margin: '0 0 4px' }}>{t({ id: 'twoFactor.title' })}</h3>
      {mode && (
        <p style={{ fontWeight: 600 }}>
          {t({ id: 'twoFactor.admin.mode' }, { mode: t({ id: `twoFactor.admin.mode.${mode}` }) })}
        </p>
      )}
      <p style={{ color: 'var(--brand-muted)' }}>{t({ id: 'twoFactor.admin.intro' })}</p>
      {comptes && comptes.length > 0 && (
        <p>{t({ id: 'twoFactor.admin.count' }, { total: comptes.length, sans: sansAppareil })}</p>
      )}
      {erreur && <p role="alert" style={{ color: 'var(--color-bad)' }}>{erreur}</p>}
      {msg.text && (
        <p role={msg.err ? 'alert' : 'status'} style={{ color: msg.err ? 'var(--color-bad)' : 'var(--color-ok)', fontWeight: 600 }}>
          {msg.text}
        </p>
      )}
      {comptes && comptes.length === 0 && !erreur && <p>{t({ id: 'twoFactor.admin.empty' })}</p>}
      {comptes && comptes.length > 0 && (
        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr>
                <th style={TH}>{t({ id: 'twoFactor.admin.col.account' })}</th>
                <th style={TH}>{t({ id: 'twoFactor.admin.col.teams' })}</th>
                <th style={TH}>{t({ id: 'twoFactor.admin.col.devices' })}</th>
                <th style={TH} />
              </tr>
            </thead>
            <tbody>
              {comptes.map((c) => (
                <tr key={c.user_id}>
                  <td style={TD}>
                    <div style={{ fontWeight: 600 }}>{c.nom || c.email}</div>
                    {c.nom && <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)' }}>{c.email}</div>}
                  </td>
                  <td style={{ ...TD, fontSize: '.88rem' }}>
                    {[c.administration ? t({ id: 'twoFactor.admin.networkAdmin' }) : null, c.equipes].filter(Boolean).join(' · ') || '—'}
                  </td>
                  <td style={TD}>
                    {c.facteurs === 0
                      ? <strong style={{ color: 'var(--color-bad)' }}>{t({ id: 'twoFactor.admin.none' })}</strong>
                      : <>
                          {c.facteurs}
                          {c.dernier_facteur && (
                            <div style={{ fontSize: '.8rem', color: 'var(--brand-muted)' }}>
                              {t({ id: 'twoFactor.list.since' }, { date: formatDate(c.dernier_facteur, { dateStyle: 'medium' }) })}
                            </div>
                          )}
                        </>}
                  </td>
                  <td style={TD}>
                    {c.facteurs > 0 && ouvert !== c.user_id && (
                      <Button variant="secondary" type="button" onClick={() => { setOuvert(c.user_id); setMotif(''); setMsg({ text: '', err: false }); }}>
                        {t({ id: 'twoFactor.admin.remove' })}
                      </Button>
                    )}
                    {ouvert === c.user_id && (
                      <form onSubmit={(e) => retirer(e, c)} style={{ display: 'flex', flexDirection: 'column', gap: 8, minWidth: 260 }}>
                        <span style={{ fontSize: '.82rem', color: 'var(--brand-muted)' }}>{t({ id: 'twoFactor.admin.removeHint' })}</span>
                        <label style={{ display: 'flex', flexDirection: 'column', gap: 4, fontSize: '.85rem' }}>
                          {t({ id: 'twoFactor.admin.motifLabel' })}
                          <input type="text" value={motif} onChange={(e) => setMotif(e.target.value)} minLength={10} maxLength={300} required />
                        </label>
                        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                          <Button variant="danger" type="submit" loading={enCours}>{t({ id: 'twoFactor.admin.confirm' })}</Button>
                          <Button variant="secondary" type="button" onClick={() => setOuvert(null)}>{t({ id: 'twoFactor.cancel' })}</Button>
                        </div>
                      </form>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}
