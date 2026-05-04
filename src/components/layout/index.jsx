import { useState, useEffect } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { publicAssetUrl } from '@/lib/theme';
import {
  canSeeAccount,
  canSeePainel,
  canSeeCatalogacao,
  canSeeImportacoes,
  canSeeBiblioteca,
  canSeeRede,
} from '@/lib/roles';
import { Button } from '@/components/ui';
import { SUPPORTED_LOCALES, setLocale, detectLocale } from '@/i18n';
import './layout.css';

// ── Résolution du logo de la bibliothèque de session ───────

const LIBRARY_LOGO_MAP = {
  blmf: { path: 'themes/blmf/logo-blmf.png', alt: 'Biblioteca Libertária Maxwell Ferreira' },
  btl:  { path: 'themes/btl/logo-btl.png', alt: 'Biblioteca Terra Livre' },
};

function resolveLibraryLogo(slug) {
  if (!slug) return null;
  const entry = LIBRARY_LOGO_MAP[slug.toLowerCase()];
  if (!entry) return null;
  return { src: publicAssetUrl(entry.path), alt: entry.alt };
}

// ── Page shell ─────────────────────────────────────────────

export function PageShell({ children }) {
  return <div className="ab-page-shell">{children}</div>;
}

// ── Topbar ─────────────────────────────────────────────────

export function Topbar() {
  const { formatMessage: t } = useIntl();
  const { user, signOut } = useAuth();
  const { libraryName, librarySlug, role } = useLibrary();
  const location = useLocation();

  const isActive = (path) => location.pathname.startsWith(path);

  // Logo de la bibliothèque de session
  const sessionLogo = user ? resolveLibraryLogo(librarySlug) : null;
  const [logoError, setLogoError] = useState(false);

  // Reset l'erreur si le slug change
  useEffect(() => { setLogoError(false); }, [librarySlug]);

  return (
    <nav className="ab-topbar">
      <Link to="/" className="ab-topbar__brand">
        <img
          src="https://cclamazonia.noblogs.org/files/2026/03/AnarBib_logo.png"
          alt="AnarBib"
          className="ab-topbar__logo"
          data-brand-logo
        />
        {sessionLogo && !logoError && (
          <img
            src={sessionLogo.src}
            alt={sessionLogo.alt}
            className="ab-topbar__logo ab-topbar__library-logo"
            onError={() => setLogoError(true)}
          />
        )}
      </Link>

      <div className="ab-topbar__nav">
        {/* ── Groupe 1 : accessible à tout user ─────────────── */}
        <Link to="/" className={isActive('/catalogo') || location.pathname === '/' ? 'active' : ''}>
          {t({ id: 'nav.catalog' })}
        </Link>

        {user && canSeeAccount(role) && (
          <Link to="/conta" className={isActive('/conta') ? 'active' : ''}>
            {t({ id: 'nav.account' })}
          </Link>
        )}

        {/* ── Groupe 2 : ≥ librarian (Painel + Catalogação) ── */}
        {canSeePainel(role) && (
          <>
            <span className="ab-topbar__sep" aria-hidden="true">|</span>
            <Link to="/painel" className={isActive('/painel') ? 'active' : ''}>
              {t({ id: 'nav.panel' })}
            </Link>
          </>
        )}

        {canSeeCatalogacao(role) && (
          <Link to="/catalogacao" className={isActive('/catalogacao') ? 'active' : ''}>
            {t({ id: 'nav.catalogacao' })}
          </Link>
        )}

        {/* ── Groupe 3 : ≥ coordenador (Importações + Biblioteca) ── */}
        {canSeeImportacoes(role) && (
          <>
            <span className="ab-topbar__sep" aria-hidden="true">|</span>
            <Link to="/importacoes" className={isActive('/importacoes') ? 'active' : ''}>
              {t({ id: 'nav.importacoes' })}
            </Link>
          </>
        )}

        {canSeeBiblioteca(role) && (
          <Link to="/biblioteca" className={isActive('/biblioteca') ? 'active' : ''}>
            {t({ id: 'nav.library' })}
          </Link>
        )}

        {/* ── Groupe 4 : administrador AnarBib uniquement (Rede) ── */}
        {canSeeRede(role) && (
          <>
            <span className="ab-topbar__sep" aria-hidden="true">|</span>
            <Link to="/rede" className={isActive('/rede') ? 'active' : ''}>
              {t({ id: 'nav.network' })}
            </Link>
          </>
        )}

        {/* ── Sortie / Inscription ─────────────────────────── */}
        {user ? (
          <button className="ab-topbar__logout" onClick={signOut}>
            {t({ id: 'nav.logout' })}
          </button>
        ) : (
          <>
            <Link to="/cadastro">
              <Button variant="mini">{t({ id: 'nav.login' })}</Button>
            </Link>
            <Link to="/criar-conta" style={{ fontSize: '.78rem', color: 'var(--brand-muted, #aaa)' }}>
              {t({ id: 'nav.register' })}
            </Link>
          </>
        )}

        {/* Language selector */}
        <select
          value={detectLocale()}
          onChange={e => setLocale(e.target.value)}
          style={{ fontSize: '.78rem', padding: '3px 6px', borderRadius: 6, border: '1px solid rgba(255,255,255,.15)', background: 'rgba(0,0,0,.3)', color: '#ccc', cursor: 'pointer', marginLeft: 4 }}
          aria-label={t({ id: 'language.selector' })}
        >
          {SUPPORTED_LOCALES.map(l => (
            <option key={l.code} value={l.code}>{l.flag} {l.label}</option>
          ))}
        </select>
      </div>
    </nav>
  );
}

// ── Hero ───────────────────────────────────────────────────

export function Hero({ title, subtitle, actions, children }) {
  return (
    <div className="ab-hero">
      <div className="ab-hero__content">
        {title && <h1>{title}</h1>}
        {subtitle && <p>{subtitle}</p>}
      </div>
      {actions && <div className="ab-hero__actions">{actions}</div>}
      {children}
    </div>
  );
}

// ── Footer ─────────────────────────────────────────────────

export function Footer() {
  const { formatMessage: t } = useIntl();
  return (
    <footer className="ab-footer">
      {t({ id: 'app.footer' })}
    </footer>
  );
}
