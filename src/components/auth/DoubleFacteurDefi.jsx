import { useState } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { Input, Button } from '@/components/ui';
import { facteursVerifies, codeBienForme, nettoyerCode, cleErreurDoubleFacteur } from '@/lib/doubleFacteur';

// ═══════════════════════════════════════════════════════════
// AnarBib — le code du second facteur à la connexion (B42, lot 1, 13/10/2026).
//
// Affiché par LoginPage (vue 'mfa') quand la session n'est qu'en aal1 alors
// que le compte a un facteur vérifié. challengeAndVerify élève la session en
// aal2 ; auth-js émet alors MFA_CHALLENGE_VERIFIED, AuthContext remplace la
// session, et LoginPage reprend sa redirection habituelle d'elle-même. Ce
// composant ne navigue donc jamais : il ne fait que présenter le code.
//
// Plusieurs facteurs (téléphone + KeePassXC, conseillé pour ne pas être
// bloqué·e) : on choisit lequel. Appareil perdu : seule l'administration du
// réseau peut retirer un facteur, après vérification hors bande (lot 2).
// ═══════════════════════════════════════════════════════════

// Même rendu que les messages d'erreur de LoginPage (ms('error')).
const STYLE_ERREUR = {
  padding: '10px 14px',
  borderRadius: 8,
  fontSize: '.85rem',
  background: 'rgba(220,38,38,.12)',
  color: '#f87171',
  border: '1px solid rgba(220,38,38,.25)',
};

export default function DoubleFacteurDefi({ session, onDeconnexion }) {
  const { formatMessage: t } = useIntl();
  const facteurs = facteursVerifies(session?.user).filter((f) => f.factor_type === 'totp');
  const [factorId, setFactorId] = useState(facteurs[0]?.id ?? '');
  const [code, setCode] = useState('');
  const [enCours, setEnCours] = useState(false);
  const [erreur, setErreur] = useState('');

  async function valider(e) {
    e.preventDefault();
    if (!codeBienForme(code)) {
      setErreur(t({ id: 'twoFactor.error.malformed' }));
      return;
    }
    setEnCours(true);
    setErreur('');
    try {
      const { error } = await supabase.auth.mfa.challengeAndVerify({ factorId, code: nettoyerCode(code) });
      if (error) {
        setErreur(t({ id: cleErreurDoubleFacteur(error) }));
        setCode('');
      }
    } catch {
      setErreur(t({ id: 'twoFactor.error.generic' }));
    } finally {
      setEnCours(false);
    }
  }

  return (
    <div>
      <form onSubmit={valider} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
        {facteurs.length > 1 && (
          <label style={{ display: 'flex', flexDirection: 'column', gap: 6, fontSize: '.9rem' }}>
            {t({ id: 'twoFactor.challenge.factorLabel' })}
            <select value={factorId} onChange={(e) => setFactorId(e.target.value)}>
              {facteurs.map((f) => (
                <option key={f.id} value={f.id}>{f.friendly_name || f.id.slice(0, 8)}</option>
              ))}
            </select>
          </label>
        )}
        <Input
          label={t({ id: 'twoFactor.code.label' })}
          type="text"
          inputMode="numeric"
          autoComplete="one-time-code"
          maxLength={9}
          value={code}
          onChange={(e) => setCode(e.target.value)}
          autoFocus
          required
        />
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <Button variant="primary" type="submit" loading={enCours} disabled={!factorId}>
            {t({ id: 'twoFactor.challenge.submit' })}
          </Button>
          {onDeconnexion && (
            <Button variant="secondary" type="button" onClick={onDeconnexion}>
              {t({ id: 'twoFactor.challenge.signOut' })}
            </Button>
          )}
        </div>
        {erreur && (
          <div role="alert" style={STYLE_ERREUR}>{erreur}</div>
        )}
      </form>
      <p style={{ fontSize: '.82rem', color: 'var(--brand-muted)', marginTop: 16 }}>
        {t({ id: 'twoFactor.challenge.lost' })}
      </p>
    </div>
  );
}
