// ─────────────────────────────────────────────────────────────────────────────
// AnarBib — /lettre : ce que devient un clic dans un courriel de la Lettre.
//
// 05/10/2026 : lettre-confirm et lettre-unsubscribe rendaient une page HTML,
// mais la plateforme sert les Edge Functions en text/plain (avec une CSP
// « sandbox ») sur son domaine : la personne lisait le code source, accents
// décodés en Latin-1 (« inscriÃ§Ã£o »). Les fonctions font leur travail puis
// renvoient ici (303) avec ?etat=…&lang=… ; la page dit le résultat dans la
// langue de la personne.
// ─────────────────────────────────────────────────────────────────────────────

import { useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { PageShell, Topbar, Footer } from '@/components/layout';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { SUPPORTED_LOCALES, setLocale } from '@/i18n';

export const ETATS_LETTRE = ['confirmed', 'already', 'expired', 'invalid', 'error', 'unsubscribed'];

export default function LettrePage() {
  const { formatMessage: t, locale } = useIntl();
  useDocumentTitle(t({ id: 'lettre.page.title' }));
  const params = new URLSearchParams(useLocation().search);
  const etatBrut = params.get('etat') || '';
  const etat = ETATS_LETTRE.includes(etatBrut) ? etatBrut : 'invalid';
  const lang = params.get('lang') || '';

  // La langue du profil de la personne, que la fonction a lue : sans session,
  // l'application ne la connaîtrait pas.
  useEffect(() => {
    if (lang && lang !== locale && SUPPORTED_LOCALES.some((l) => l.code === lang)) setLocale(lang);
  }, [lang, locale]);

  const reussi = etat === 'confirmed' || etat === 'already' || etat === 'unsubscribed';
  return (
    <PageShell>
      <Topbar />
      <main className="ab-page" style={{ maxWidth: 640, margin: '3rem auto', padding: '0 16px', textAlign: 'center' }}>
        <h1 style={{ fontSize: '1.4rem', marginBottom: '1rem' }}>{t({ id: 'lettre.page.title' })}</h1>
        <p role={reussi ? 'status' : 'alert'} style={{ fontSize: '1.05rem', lineHeight: 1.5 }}>
          {t({ id: `lettre.page.${etat}` })}
        </p>
        <a href="/" className="ab-button ab-button--primary" style={{ display: 'inline-block', marginTop: '1.6rem' }}>
          {t({ id: 'lettre.page.cta' })}
        </a>
      </main>
      <Footer />
    </PageShell>
  );
}
