import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui';
import { codeBienForme, nettoyerCode, secretParGroupes, cleErreurDoubleFacteur } from '@/lib/doubleFacteur';

// ═══════════════════════════════════════════════════════════
// AnarBib — la double authentification dans Mon compte (B42, lot 1,
// 13/10/2026), sous le changement de mot de passe.
//
// TOTP natif de Supabase Auth : GoTrue fabrique le secret et le code QR (en
// SVG, aucune bibliothèque de QR), la personne le range dans une application
// libre et hors ligne. Rien ne sort vers un tiers ; le secret n'est montré
// qu'ici, pendant l'inscription, et n'est gardé nulle part dans l'app.
//
// Inscrire = enroll (facteur « non vérifié ») puis un premier code
// (challengeAndVerify) qui le vérifie ET élève la session en aal2. Une
// inscription abandonnée laisse un facteur non vérifié : on les retire avant
// d'en commencer une autre (ils comptent dans le plafond de GoTrue).
//
// Plusieurs appareils sont permis et conseillés : c'est la seule « clé de
// secours » que Supabase connaisse. Retirer un facteur vérifié exige une
// session aal2 (refus insufficient_aal sinon).
//
// Facultatif à ce lot pour tout le monde. L'obligation des comptes d'équipe
// (bibliothécaires, coordinations, administration du réseau) et l'exigence
// côté serveur viennent au lot 2.
// ═══════════════════════════════════════════════════════════

const CADRE = { marginTop: 32, padding: 20, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)' };
const TITRE = { margin: '0 0 4px', fontSize: '1.05rem', fontFamily: 'var(--brand-font-body)', textTransform: 'none' };
const AIDE = { fontSize: '.85rem', color: 'var(--brand-muted)', marginBottom: 14 };

export default function ContaDoubleFacteur() {
  const { formatMessage: t, formatDate } = useIntl();
  const [facteurs, setFacteurs] = useState([]);
  const [chargement, setChargement] = useState(true);
  const [inscription, setInscription] = useState(null);
  const [nom, setNom] = useState('');
  const [code, setCode] = useState('');
  const [enCours, setEnCours] = useState(false);
  const [aRetirer, setARetirer] = useState(null);
  const [msg, setMsg] = useState({ text: '', err: false });

  const verifies = facteurs.filter((f) => f.status === 'verified');

  const charger = useCallback(async () => {
    const { data, error } = await supabase.auth.mfa.listFactors();
    if (!error) setFacteurs((data?.all ?? []).filter((f) => f.factor_type === 'totp'));
    setChargement(false);
    return error ? [] : (data?.all ?? []).filter((f) => f.factor_type === 'totp');
  }, []);

  useEffect(() => { charger(); }, [charger]);

  const refus = (error) => setMsg({ text: t({ id: cleErreurDoubleFacteur(error) }), err: true });

  async function commencer(e) {
    e.preventDefault();
    setEnCours(true);
    setMsg({ text: '', err: false });
    try {
      const actuels = await charger();
      for (const f of actuels.filter((x) => x.status !== 'verified')) {
        await supabase.auth.mfa.unenroll({ factorId: f.id });
      }
      const friendlyName = nom.trim() || `${t({ id: 'twoFactor.enroll.defaultName' })} ${verifies.length + 1}`;
      const { data, error } = await supabase.auth.mfa.enroll({ factorType: 'totp', friendlyName, issuer: 'AnarBib' });
      if (error) { refus(error); return; }
      setInscription({ id: data.id, qr: data.totp?.qr_code, secret: data.totp?.secret });
      setCode('');
    } catch {
      refus(null);
    } finally {
      setEnCours(false);
    }
  }

  async function confirmer(e) {
    e.preventDefault();
    if (!codeBienForme(code)) {
      setMsg({ text: t({ id: 'twoFactor.error.malformed' }), err: true });
      return;
    }
    setEnCours(true);
    setMsg({ text: '', err: false });
    try {
      const { error } = await supabase.auth.mfa.challengeAndVerify({ factorId: inscription.id, code: nettoyerCode(code) });
      if (error) { refus(error); setCode(''); return; }
      setInscription(null);
      setNom('');
      setCode('');
      setMsg({ text: t({ id: 'twoFactor.enroll.done' }), err: false });
      await charger();
    } catch {
      refus(null);
    } finally {
      setEnCours(false);
    }
  }

  async function abandonner() {
    const id = inscription?.id;
    setInscription(null);
    setCode('');
    setMsg({ text: '', err: false });
    if (id) await supabase.auth.mfa.unenroll({ factorId: id });
    await charger();
  }

  async function retirer(factorId) {
    setEnCours(true);
    setMsg({ text: '', err: false });
    try {
      const { error } = await supabase.auth.mfa.unenroll({ factorId });
      if (error) { refus(error); return; }
      setARetirer(null);
      setMsg({ text: t({ id: 'twoFactor.remove.done' }), err: false });
      await charger();
    } catch {
      refus(null);
    } finally {
      setEnCours(false);
    }
  }

  async function copierSecret() {
    try { await navigator.clipboard.writeText(inscription?.secret ?? ''); } catch { /* presse-papiers indisponible */ }
  }

  return (
    <div style={CADRE} data-testid="conta-double-facteur">
      <h3 style={TITRE}>{t({ id: 'twoFactor.title' })}</h3>
      <div style={AIDE}>{t({ id: 'twoFactor.intro' })}</div>

      {!chargement && (
        <div style={{ fontSize: '.9rem', fontWeight: 600, marginBottom: 12 }}>
          {verifies.length > 0
            ? t({ id: 'twoFactor.status.on' }, { n: verifies.length })
            : t({ id: 'twoFactor.status.off' })}
        </div>
      )}

      {verifies.length > 0 && (
        <ul style={{ listStyle: 'none', padding: 0, margin: '0 0 14px', display: 'flex', flexDirection: 'column', gap: 8 }}>
          {verifies.map((f) => (
            <li key={f.id} style={{ display: 'flex', gap: 12, alignItems: 'center', flexWrap: 'wrap' }}>
              <span style={{ fontWeight: 600 }}>{f.friendly_name || f.id.slice(0, 8)}</span>
              <span style={{ fontSize: '.82rem', color: 'var(--brand-muted)' }}>
                {t({ id: 'twoFactor.list.since' }, { date: formatDate(f.created_at, { dateStyle: 'medium' }) })}
              </span>
              {aRetirer === f.id ? (
                <>
                  <span style={{ fontSize: '.85rem' }}>{t({ id: 'twoFactor.remove.confirm' })}</span>
                  <Button variant="danger" type="button" loading={enCours} onClick={() => retirer(f.id)}>
                    {t({ id: 'twoFactor.remove.yes' })}
                  </Button>
                  <Button variant="secondary" type="button" onClick={() => setARetirer(null)}>
                    {t({ id: 'twoFactor.cancel' })}
                  </Button>
                </>
              ) : (
                <Button variant="secondary" type="button" onClick={() => { setARetirer(f.id); setMsg({ text: '', err: false }); }}>
                  {t({ id: 'twoFactor.remove.button' })}
                </Button>
              )}
            </li>
          ))}
        </ul>
      )}

      {!inscription && !chargement && (
        <form onSubmit={commencer} className="ab-conta-form">
          {verifies.length > 0 && <div style={AIDE}>{t({ id: 'twoFactor.backupAdvice' })}</div>}
          <label>
            {t({ id: 'twoFactor.enroll.nameLabel' })}
            <input
              type="text"
              value={nom}
              onChange={(e) => setNom(e.target.value)}
              placeholder={t({ id: 'twoFactor.enroll.namePh' })}
              maxLength={60}
            />
          </label>
          <div className="ab-conta-form-actions">
            <Button type="submit" loading={enCours}>
              {verifies.length > 0 ? t({ id: 'twoFactor.enroll.addAnother' }) : t({ id: 'twoFactor.enroll.start' })}
            </Button>
          </div>
        </form>
      )}

      {inscription && (
        <form onSubmit={confirmer} className="ab-conta-form">
          <div style={AIDE}>{t({ id: 'twoFactor.enroll.scan' })}</div>
          {inscription.qr && (
            <div style={{ background: '#fff', padding: 12, borderRadius: 8, width: 'fit-content', maxWidth: '100%' }}>
              <img src={inscription.qr} alt={t({ id: 'twoFactor.enroll.qrAlt' })} width={180} height={180} style={{ display: 'block', maxWidth: '100%', height: 'auto' }} />
            </div>
          )}
          <div style={{ ...AIDE, marginTop: 12, marginBottom: 6 }}>{t({ id: 'twoFactor.enroll.manual' })}</div>
          <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap', marginBottom: 14 }}>
            <code style={{ fontSize: '.95rem', letterSpacing: '.05em', wordBreak: 'break-all' }}>{secretParGroupes(inscription.secret)}</code>
            <Button variant="secondary" type="button" onClick={copierSecret}>{t({ id: 'twoFactor.enroll.copy' })}</Button>
          </div>
          <label>
            {t({ id: 'twoFactor.code.label' })}
            <input
              type="text"
              inputMode="numeric"
              autoComplete="one-time-code"
              maxLength={9}
              value={code}
              onChange={(e) => setCode(e.target.value)}
              required
            />
          </label>
          <div className="ab-conta-form-actions">
            <Button type="submit" loading={enCours}>{t({ id: 'twoFactor.enroll.confirm' })}</Button>
            <Button variant="secondary" type="button" onClick={abandonner}>{t({ id: 'twoFactor.cancel' })}</Button>
          </div>
        </form>
      )}

      {msg.text && (
        <div role={msg.err ? 'alert' : 'status'} className={`ab-conta-msg ${msg.err ? 'ab-conta-msg--error' : ''}`} style={{ marginTop: 10 }}>
          {msg.text}
        </div>
      )}

      <div style={{ ...AIDE, marginTop: 14, marginBottom: 0 }}>{t({ id: 'twoFactor.lostAdvice' })}</div>
    </div>
  );
}
