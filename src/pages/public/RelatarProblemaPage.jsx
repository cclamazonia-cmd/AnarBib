// CHEMIN DÉPÔT : src/pages/public/RelatarProblemaPage.jsx
//
// « Signaler un problème » (E14, 24/09/2026). Accessible depuis toutes les pages
// (lien au pied, intention « Je veux… »), SANS compte et sans Codeberg. Trois
// champs libres, une adresse facultative pour l'accusé de réception, la preuve de
// travail Altcha ; le contexte (page d'origine lue dans ?de=, langue, rôle et
// bibliothèque de session) part avec, sans que la personne ait à le saisir.
// Jamais de mot de passe ni de capture obligatoire. Soumission → Edge Function
// publique submit-bug-report (Altcha + compteur bug_ip), qui refuse un doublon
// encore ouvert au lieu d'en créer un second. Modèle : CartografiaAjouterPage.

import { useState } from 'react';
import { useLocation } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { PageShell, Topbar, Footer } from '@/components/layout';
import { useLibrary } from '@/contexts/LibraryContext';
import { callEdgeFunction } from '@/lib/supabase';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import AltchaWidget from '@/components/ui/AltchaWidget';
import { Button } from '@/components/ui';

export default function RelatarProblemaPage() {
  const { formatMessage: t, locale } = useIntl();
  useDocumentTitle(t({ id: 'relatar.title' }));
  const location = useLocation();
  const { libraryName, role } = useLibrary();
  const de = new URLSearchParams(location.search).get('de') || '';
  const page = de.startsWith('/') ? de.slice(0, 300) : '';

  const [f, setF] = useState({ what: '', expected: '', steps: '', email: '', website: '' });
  const [state, setState] = useState('idle'); // idle | sending | done | duplicate | error
  const [ref, setRef] = useState('');
  const [errMsg, setErrMsg] = useState('');
  const [altchaCharge, setAltchaCharge] = useState(null);
  const [altchaReset, setAltchaReset] = useState(0);
  const set = (k) => (e) => setF((p) => ({ ...p, [k]: e.target.value }));

  async function submit(e) {
    e.preventDefault();
    if (f.what.trim().length < 10) { setErrMsg(t({ id: 'relatar.tooShort' })); setState('error'); return; }
    // Garde-fou d'interface : la vraie vérification est côté serveur.
    if (!altchaCharge) { setErrMsg(t({ id: 'relatar.error' })); setState('error'); return; }
    setState('sending'); setErrMsg('');
    const res = await callEdgeFunction('submit-bug-report', {
      what_happened: f.what, expected: f.expected, steps: f.steps, reporter_email: f.email,
      // Sans session, le contexte de bibliothèque vaut « AnarBib » par défaut : ne rien envoyer
      // plutôt qu'une bibliothèque qui n'est pas celle de la personne (premier signalement réel, 24/09).
      page_path: page || null, locale, role_hint: role || null, library_hint: role ? (libraryName || null) : null,
      altcha_payload: altchaCharge, website: f.website,
    });
    if (res.ok && res.data?.id) {
      setRef(String(res.data.id).slice(0, 8));
      setState(res.data.duplicate ? 'duplicate' : 'done');
    } else {
      setErrMsg(t({ id: 'relatar.error' })); setState('error');
    }
    // Une solution ne vaut qu'une fois (AR-4) : on en redemande une neuve dans tous les cas.
    setAltchaCharge(null);
    setAltchaReset((n) => n + 1);
  }

  const panel = {
    backgroundColor: 'var(--brand-panel-bg)',
    backgroundImage: 'var(--brand-panel-overlay-solid), var(--brand-panel-bg-image)',
    backgroundPosition: 'center', backgroundSize: 'cover',
    border: '1px solid var(--brand-panel-border)', borderRadius: 'calc(var(--brand-radius) + 2px)',
    boxShadow: 'var(--brand-shadow)', padding: '24px 24px 32px',
  };
  const label = { display: 'block', fontSize: '.85rem', fontWeight: 600, margin: '14px 0 4px' };
  const hint = { fontSize: '.78rem', color: 'var(--brand-muted)', margin: '0 0 4px' };
  const input = {
    width: '100%', boxSizing: 'border-box', padding: '10px 12px', borderRadius: 8, fontSize: '16px',
    border: '1px solid rgba(255,255,255,.14)', background: 'rgba(255,255,255,.04)', color: 'inherit', fontFamily: 'inherit',
  };

  return (
    <PageShell>
      <Topbar />
      <div style={{ maxWidth: 640, margin: '0 auto', padding: '24px 16px 48px' }}>
        <div style={panel}>
          <h1 style={{ fontSize: '1.6rem', fontWeight: 800, marginBottom: 6, fontFamily: 'var(--brand-font-body)' }}>
            {t({ id: 'relatar.title' })}
          </h1>
          <p style={{ color: 'var(--brand-muted)', marginBottom: 8 }}>{t({ id: 'relatar.intro' })}</p>
          <p style={{ color: 'var(--brand-muted)', fontSize: '.82rem', marginBottom: 4 }}>{t({ id: 'relatar.consent' })}</p>
          <p style={{ color: 'var(--brand-muted)', fontSize: '.82rem', marginBottom: 12 }}>
            {t({ id: 'relatar.context' }, { page: page || t({ id: 'relatar.noPage' }) })}
          </p>

          {state === 'done' || state === 'duplicate' ? (
            <div role="status">
              <p style={{ color: '#86efac', fontSize: '1rem' }}>{t({ id: state === 'done' ? 'relatar.success' : 'relatar.duplicate' })}</p>
              <p style={{ color: 'var(--brand-muted)', fontSize: '.9rem' }}>{t({ id: 'relatar.ref' }, { ref })}</p>
            </div>
          ) : (
            <form onSubmit={submit}>
              {/* honeypot anti-bot (caché) */}
              <input type="text" name="website" autoComplete="off" tabIndex={-1} value={f.website} onChange={set('website')}
                style={{ position: 'absolute', left: -9999, opacity: 0, height: 0 }} aria-hidden="true" />

              <label htmlFor="relatar-what" style={label}>{t({ id: 'relatar.what' })}</label>
              <p style={hint}>{t({ id: 'relatar.whatHint' })}</p>
              <textarea id="relatar-what" required minLength={10} maxLength={4000} rows={5} value={f.what} onChange={set('what')} style={{ ...input, resize: 'vertical' }} />

              <label htmlFor="relatar-expected" style={label}>{t({ id: 'relatar.expected' })}</label>
              <textarea id="relatar-expected" maxLength={2000} rows={3} value={f.expected} onChange={set('expected')} style={{ ...input, resize: 'vertical' }} />

              <label htmlFor="relatar-steps" style={label}>{t({ id: 'relatar.steps' })}</label>
              <textarea id="relatar-steps" maxLength={4000} rows={3} value={f.steps} onChange={set('steps')} style={{ ...input, resize: 'vertical' }} />

              <label htmlFor="relatar-email" style={label}>{t({ id: 'relatar.email' })}</label>
              <p style={hint}>{t({ id: 'relatar.emailHint' })}</p>
              <input id="relatar-email" type="email" maxLength={200} value={f.email} onChange={set('email')} style={input} />

              {/* Anti-robots : preuve de travail résolue dans le navigateur. */}
              <div style={{ margin: '16px 0' }}>
                <AltchaWidget onSolved={setAltchaCharge} resetKey={altchaReset} />
              </div>

              {state === 'error' && <p role="alert" style={{ color: '#fca5a5', fontSize: '.88rem' }}>{errMsg}</p>}
              <Button variant="primary" type="submit" disabled={state === 'sending'}>
                {t({ id: state === 'sending' ? 'relatar.sending' : 'relatar.submit' })}
              </Button>
            </form>
          )}
        </div>
      </div>
      <Footer />
    </PageShell>
  );
}
