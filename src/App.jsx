import { lazy, Suspense } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { IntlProvider } from 'react-intl';
import { AuthProvider } from '@/contexts/AuthContext';
import { LibraryProvider, useLibrary } from '@/contexts/LibraryContext';
import { useTheme } from '@/lib/theme';
import { detectLocale, getMessages } from '@/i18n';
import { ProtectedRoute } from '@/components/layout/ProtectedRoute';
import { Spinner } from '@/components/ui';

// ── Lazy-loaded pages ──────────────────────────────────────
const CatalogPage = lazy(() => import('@/pages/public/CatalogPage'));
const BookPage = lazy(() => import('@/pages/public/BookPage'));
const AuthorPage = lazy(() => import('@/pages/public/AuthorPage'));
const ReaderPage = lazy(() => import('@/pages/public/ReaderPage'));
const ResourcePage = lazy(() => import('@/pages/public/ResourcePage'));
const AccountPage = lazy(() => import('@/pages/account/AccountPage'));
const PanelPage = lazy(() => import('@/pages/painel/PanelPage'));
const CatalogacaoPage = lazy(() => import('@/pages/catalogacao/CatalogacaoPage'));
const CriarContaPage = lazy(() => import('@/pages/public/CriarContaPage'));
const CadastroPage = lazy(() => import('@/pages/public/CadastroPage'));
const SolicitarBibliotecaPage = lazy(() => import('@/pages/public/SolicitarBibliotecaPage'));
const ImportacoesPage = lazy(() => import('@/pages/importacoes/ImportacoesPage'));
const BibliotecaPage = lazy(() => import('@/pages/biblioteca/BibliotecaPage'));
const RedePage = lazy(() => import('@/pages/rede/RedePage'));

// ── Fallback de chargement ─────────────────────────────────
function LoadingFallback() {
  return (
    <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: '60vh' }}>
      <Spinner size={36} />
    </div>
  );
}

// ── Chargement du thème ────────────────────────────────────
function ThemeGate({ children }) {
  const { themeSlug } = useLibrary();
  useTheme(themeSlug);
  return children;
}

// ── App ────────────────────────────────────────────────────
export default function App() {
  const locale = detectLocale();
  const messages = getMessages(locale);

  return (
    <IntlProvider locale={locale} messages={messages} defaultLocale="pt-BR">
      <BrowserRouter basename="/anarbib">
        <AuthProvider>
          <LibraryProvider>
            <ThemeGate>
              <Suspense fallback={<LoadingFallback />}>
                <Routes>
                  {/* ── Pages publiques ──────────────── */}
                  <Route path="/" element={<CatalogPage />} />
                  <Route path="/catalogo" element={<CatalogPage />} />
                  <Route path="/livro/:id" element={<BookPage />} />
                  <Route path="/autor/:id" element={<AuthorPage />} />
                  <Route path="/entrar" element={<Navigate to="/cadastro" replace />} />
                  <Route path="/ler/:id" element={<ReaderPage />} />
                  <Route path="/ler-recurso" element={<ResourcePage />} />

                  {/* ── Pages authentifiées ──────────── */}
                  <Route path="/conta" element={<ProtectedRoute><AccountPage /></ProtectedRoute>} />
                  <Route path="/painel" element={<ProtectedRoute><PanelPage /></ProtectedRoute>} />
                  <Route path="/painel/:tab" element={<ProtectedRoute><PanelPage /></ProtectedRoute>} />

                  {/* ── Biblioteca ──────────────────────────── */}
                  <Route path="/biblioteca" element={
                    <ProtectedRoute><BibliotecaPage /></ProtectedRoute>
                  } />

                  {/* ── Rede (administrador only) ────────── */}
                  <Route path="/rede" element={
                    <ProtectedRoute><RedePage /></ProtectedRoute>
                  } />

                  {/* ── Inscription / Login / Solicitation ───── */}
                  <Route path="/criar-conta" element={<CriarContaPage />} />
                  <Route path="/cadastro" element={<CadastroPage />} />
                  <Route path="/solicitar-biblioteca" element={<SolicitarBibliotecaPage />} />

                  {/* ── Importações ──────────────────────────── */}
                  <Route path="/importacoes" element={
                    <ProtectedRoute><ImportacoesPage /></ProtectedRoute>
                  } />

                  {/* ── Catalogação ────────────────────────── */}
                  <Route path="/catalogacao" element={
                    <ProtectedRoute>
                      <CatalogacaoPage />
                    </ProtectedRoute>
                  } />

                  {/* ── 404 ─────────────────────────── */}
                  <Route path="*" element={
                    <div style={{ textAlign: 'center', padding: 60, color: 'var(--brand-muted)' }}>
                      <h1>404</h1>
                      <p>Página não encontrada.</p>
                    </div>
                  } />
                </Routes>
              </Suspense>
            </ThemeGate>
          </LibraryProvider>
        </AuthProvider>
      </BrowserRouter>
    </IntlProvider>
  );
}
