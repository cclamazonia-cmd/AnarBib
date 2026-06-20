import { lazy, Suspense, useState, useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { IntlProvider, useIntl } from 'react-intl';
import { AuthProvider } from '@/contexts/AuthContext';
import { LibraryProvider } from '@/contexts/LibraryContext';
import { ToastProvider } from '@/contexts/ToastContext';
import { detectLocale, loadMessages, defaultMessages, DEFAULT_LOCALE, isSupported } from '@/i18n';
import { ProtectedRoute } from '@/components/layout/ProtectedRoute';
import IdleTimerGuard from '@/components/IdleTimerGuard';
import ScrollButtons from '@/components/ScrollButtons';
import { ErrorBoundary } from '@/components/ErrorBoundary';
import { Spinner } from '@/components/ui';

// ── Lazy-loaded pages ────────────────────────────────────────────────
const CatalogPage = lazy(() => import('@/pages/public/CatalogPage'));
const BookPage = lazy(() => import('@/pages/public/BookPage'));
const AuthorPage = lazy(() => import('@/pages/public/AuthorPage'));
const WorkPage = lazy(() => import('@/pages/public/WorkPage'));
const ReaderPage = lazy(() => import('@/pages/public/ReaderPage'));
const ContaRouter = lazy(() => import('@/pages/account/ContaRouter'));
const PanelPage = lazy(() => import('@/pages/painel/PanelPage'));
const CatalogacaoPage = lazy(() => import('@/pages/catalogacao/CatalogacaoPage'));
const CriarContaPage = lazy(() => import('@/pages/public/CriarContaPage'));
const LoginPage = lazy(() => import('@/pages/public/LoginPage'));
const SolicitarBibliotecaPage = lazy(() => import('@/pages/public/SolicitarBibliotecaPage'));
const PrivacyPolicyPage = lazy(() => import('@/pages/public/PrivacyPolicyPage'));
const BibliotecasPage = lazy(() => import('@/pages/public/BibliotecasPage'));
const BibliotecaPublicaPage = lazy(() => import('@/pages/public/BibliotecaPublicaPage'));
const CartografiaPage = lazy(() => import('@/pages/public/CartografiaPage'));
const CartografiaAjouterPage = lazy(() => import('@/pages/public/CartografiaAjouterPage'));
const CartografiaModeracaoPage = lazy(() => import('@/pages/federacao/CartografiaModeracaoPage'));
const ImportacoesPage = lazy(() => import('@/pages/importacoes/ImportacoesPage'));
const ImportWizard = lazy(() => import('@/pages/importacoes/ImportWizard'));
const BibliotecaPage = lazy(() => import('@/pages/biblioteca/BibliotecaPage'));
const RedePage = lazy(() => import('@/pages/rede/RedePage'));
const FederacaoPage = lazy(() => import('@/pages/federacao/FederacaoPage'));
const AtelierConstituicaoPage = lazy(() => import('@/pages/atelier/AtelierConstituicaoPage'));
const AtelierAutoridadesPage = lazy(() => import('@/pages/atelier/AtelierAutoridadesPage'));
// Route jetable de test du POC OCR navigateur (piste B, P1/P2) — cf. /dev/ocr.
// Gardee derriere import.meta.env.DEV : en prod, le ternaire devient `null`,
// l'import() dynamique est elimine (dead-code) => aucun chunk OCR ni tesseract.js
// ne part dans le build public.
const OcrPocPage = import.meta.env.DEV
  ? lazy(() => import('@/pages/dev/OcrPocPage'))
  : null;

// ── Fallback de chargement ───────────────────────────────────────────
function LoadingFallback() {
  return (
    <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: '60vh' }}>
      <Spinner size={36} />
    </div>
  );
}

// ── 404 ── Composant dédié (consommateur d'IntlProvider, qu'App fournit mais ne
// consomme pas) : permet d'i18n le message d'erreur via useIntl.
function NotFound() {
  const { formatMessage: t } = useIntl();
  return (
    <div style={{ textAlign: 'center', padding: 60, color: 'var(--brand-muted)' }}>
      <h1>404</h1>
      <p>{t({ id: 'notfound.message' })}</p>
    </div>
  );
}

// ── App ──────────────────────────────────────────────────────────────
export default function App() {
  // pt-BR est embarqué : disponible synchroniquement, aucun délai au démarrage.
  // #LOGIN-FIX H2 : la locale est désormais un STATE re-settable. setLocale /
  // syncLocaleFromProfile (i18n/index.js) émettent l'événement 'anarbib:locale-change'
  // au lieu de window.location.reload() → swap live des messages, sans remonter
  // toute l'app (plus de cascade de fonds en plein login).
  const [locale, setLocaleState] = useState(() => detectLocale());
  const [messages, setMessages] = useState(() => detectLocale() === DEFAULT_LOCALE ? defaultMessages : null);

  useEffect(() => {
    function onLocaleChange(e) {
      const next = e?.detail?.locale;
      if (next && isSupported(next)) setLocaleState(next);
    }
    window.addEventListener('anarbib:locale-change', onLocaleChange);
    return () => window.removeEventListener('anarbib:locale-change', onLocaleChange);
  }, []);

  useEffect(() => {
    // pt-BR embarqué (synchrone) ; les autres locales chargées à la volée.
    // On NE remet PAS messages à null sur changement : on garde l'ancien jeu
    // jusqu'à l'arrivée du nouveau pour éviter un flash de fallback.
    if (locale === DEFAULT_LOCALE) { setMessages(defaultMessages); return; }
    let alive = true;
    loadMessages(locale).then((m) => {
      if (alive) setMessages(m);
    });
    return () => {
      alive = false;
    };
  }, [locale]);

  // Bref fallback uniquement pour une langue ≠ pt-BR, le temps de charger
  // son chunk (~une centaine de Ko). pt-BR n'y passe jamais.
  if (!messages) return <LoadingFallback />;

  return (
    <IntlProvider locale={locale} messages={messages} defaultLocale="pt-BR">
      <BrowserRouter basename="/">
        <AuthProvider>
          <LibraryProvider>
            <IdleTimerGuard>
            <ToastProvider>
              <ErrorBoundary>
              <Suspense fallback={<LoadingFallback />}>
                <Routes>
                  {/* ── Pages publiques ───────────── */}
                  <Route path="/" element={<CatalogPage />} />
                  <Route path="/catalogo" element={<CatalogPage />} />
                  {/* Alias profond : catalogue scopé sur une bibliothèque (galerie anarbib.org). */}
                  <Route path="/catalogo/:slug" element={<CatalogPage />} />
                  <Route path="/livro/:id" element={<BookPage />} />
                  <Route path="/autor/:id" element={<AuthorPage />} />
                  <Route path="/obra/:id" element={<WorkPage />} />
                  <Route path="/entrar" element={<Navigate to="/login" replace />} />
                  <Route path="/ler/:id" element={<ReaderPage />} />
                  <Route path="/ler-recurso" element={<ReaderPage />} />
                  <Route path="/privacidade" element={<PrivacyPolicyPage />} />
                  <Route path="/privacidade/:slug" element={<PrivacyPolicyPage />} />
                  {/* Annuaire & fiche publics des bibliothèques (chantier PUBLIB, REGISTRE §31) */}
                  <Route path="/bibliotecas" element={<BibliotecasPage />} />
                  <Route path="/bibliotecas/:slug" element={<BibliotecaPublicaPage />} />
                  {/* Carte publique du réseau (MAP-C, REGISTRE §34) */}
                  <Route path="/cartografia" element={<CartografiaPage />} />
                  {/* Auto-déclaration publique « ajouter ma biblio » (MAP-J) */}
                  <Route path="/cartografia/ajouter" element={<CartografiaAjouterPage />} />
                  {/* Modération des auto-déclarations (coordination réseau, MAP-J) */}
                  <Route path="/cartografia/moderacao" element={<ProtectedRoute><CartografiaModeracaoPage /></ProtectedRoute>} />

                  {/* ── Pages authentifiées ────────── */}
                  <Route path="/conta" element={<ProtectedRoute><ContaRouter /></ProtectedRoute>} />
                  {/* Oficina de constituição (coordenador_em_constituicao) — auto-gardée */}
                  <Route path="/atelier" element={<ProtectedRoute><AtelierConstituicaoPage /></ProtectedRoute>} />
                  {/* Oficina de autoridades (atelier autorités) — file de propositions */}
                  <Route path="/atelier-autoridades" element={<ProtectedRoute><AtelierAutoridadesPage /></ProtectedRoute>} />
                  <Route path="/painel" element={<ProtectedRoute><PanelPage /></ProtectedRoute>} />
                  <Route path="/painel/:tab" element={<ProtectedRoute><PanelPage /></ProtectedRoute>} />

                  {/* ── Biblioteca ───────────────────────── */}
                  <Route path="/biblioteca" element={
                    <ProtectedRoute><BibliotecaPage /></ProtectedRoute>
                  } />

                  {/* ── Federacao (tout membre rattache, FED-2) ── */}
                  <Route path="/federacao" element={
                    <ProtectedRoute><FederacaoPage /></ProtectedRoute>
                  } />
                  <Route path="/federacao/:tab" element={
                    <ProtectedRoute><FederacaoPage /></ProtectedRoute>
                  } />

                  {/* ── Rede (administrador only) ──────────── */}
                  <Route path="/rede" element={
                    <ProtectedRoute><RedePage /></ProtectedRoute>
                  } />

                  {/* ── Inscription / Login / Solicitation ───── */}
                  <Route path="/criar-conta" element={<CriarContaPage />} />
                  <Route path="/login" element={<LoginPage />} />
                  {/* Legacy redirect — preserves recovery email links sent before the rename */}
                  <Route
                    path="/cadastro"
                    element={<Navigate to={`/login${window.location.hash || ''}`} replace />}
                  />
                  <Route path="/solicitar-biblioteca" element={<SolicitarBibliotecaPage />} />

                  {/* ── Importações ──────────────────────── */}
                  <Route path="/importacoes" element={
                    <ProtectedRoute><ImportacoesPage /></ProtectedRoute>
                  } />
                  <Route path="/importacoes/novo" element={
                    <ProtectedRoute><ImportWizard /></ProtectedRoute>
                  } />

                  {/* ── Catalogação ─────────────────────── */}
                  <Route path="/catalogacao" element={
                    <ProtectedRoute>
                      <CatalogacaoPage />
                    </ProtectedRoute>
                  } />

                  {/* ── POC OCR navigateur (piste B, P1/P2) — route dev jetable ──
                      Dev uniquement : import.meta.env.DEV => tree-shakee du build
                      prod, l'ecran de test n'est pas expose sur le site public. */}
                  {OcrPocPage && (
                    <Route path="/dev/ocr" element={<OcrPocPage />} />
                  )}

                  {/* ── 404 ────────────────────── */}
                  <Route path="*" element={<NotFound />} />
                </Routes>
              </Suspense>
              </ErrorBoundary>
              <ScrollButtons />
            </ToastProvider>
            </IdleTimerGuard>
          </LibraryProvider>
        </AuthProvider>
      </BrowserRouter>
    </IntlProvider>
  );
}
