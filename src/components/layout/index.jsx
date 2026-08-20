import { useState, useEffect } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { useAuth } from '@/contexts/AuthContext';
import NotificationBell from '@/components/notifications/NotificationBell';
import { useLibrary } from '@/contexts/LibraryContext';
import { supabase } from '@/lib/supabase';
import { resolveLibraryLogo, DEFAULT_BRAND_LOGO } from '@/lib/theme';
import {
  canSeeAccount,
  canSeePainel,
  canSeeCatalogacao,
  canSeeImportacoes,
  canSeeBiblioteca,
  canSeeFederacao,
  canSeeRede,
} from '@/lib/roles';
import { Button } from '@/components/ui';
import { LocaleSwitcher } from '@/components/LocaleSwitcher';
import './layout.css';

// Logo de la bibliothèque de session : résolu data-driven depuis
// library_commons (logo_url / logo_file_key) via resolveLibraryLogo de
// @/lib/theme — source partagée avec la carte lecteur (plus de logique
// dupliquée ici, item 2 ; plus de map codé en dur, TR-6.2b).

// Pages d'authentification : depuis elles, le bouton « Connexion » ne doit pas
// se passer un `next` pointant sur lui-meme (boucle).
const AUTH_PATHS = new Set(['/login', '/cadastro', '/criar-conta']);

// ── Page shell ─────────────────────────────────────────────

export function PageShell({ children }) {
  return <div className="ab-page-shell">{children}</div>;
}

// ── Topbar ─────────────────────────────────────────────────

export function Topbar() {
  const { formatMessage: t } = useIntl();
  const { user, signOut } = useAuth();
  const { libraryName, libraryId, role, isNetworkAdmin, brandLogoUrl } = useLibrary();
  const location = useLocation();

  const isActive = (path) => location.pathname.startsWith(path);

  // Logo de la bibliothèque de session, résolu data-driven depuis library_commons.
  const [logoSrc, setLogoSrc] = useState(null);
  const [logoError, setLogoError] = useState(false);

  // Menu mobile (≤640px) — tiroir hamburger (chantier mobile Phase B, M6).
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    setLogoError(false);
    setLogoSrc(null);
    if (!user || !libraryId) return;
    let cancelled = false;
    (async () => {
      try {
        const { data } = await supabase
          .from('library_commons')
          .select('logo_url, logo_file_key')
          .eq('library_id', libraryId)
          .maybeSingle();
        if (!cancelled) setLogoSrc(resolveLibraryLogo(data));
      } catch {
        if (!cancelled) setLogoSrc(null);
      }
    })();
    return () => { cancelled = true; };
  }, [libraryId, user?.id]);

  // Referme le tiroir à chaque navigation.
  useEffect(() => { setMenuOpen(false); }, [location.pathname]);

  return (
    <nav className="ab-topbar">
      <Link to="/" className="ab-topbar__brand">
        {/* Logo auto-heberge (19/08/2026). Il etait hotlinke sur un WordPress
            externe (cclamazonia.noblogs.org), ce qui exposait l'IP de chaque
            visiteur a un tiers et faisait dependre le bandeau d'un site que
            nous ne maitrisons pas. Le fichier vit desormais dans public/img/.
            Depuis, il est pilotable par bibliotheque : un theme de biblio qui
            declare `assets.logo` remplace ce logo (cf. resolveBrandLogo). Le
            theme `default` garde le fichier local. En cas d'URL de theme
            cassee, onError ramene le logo AnarBib plutot qu'un bandeau vide. */}
        <img
          src={brandLogoUrl || DEFAULT_BRAND_LOGO}
          alt="AnarBib"
          className="ab-topbar__logo"
          data-brand-logo
          onError={(e) => {
            if (e.currentTarget.src.endsWith(DEFAULT_BRAND_LOGO)) return;
            e.currentTarget.src = DEFAULT_BRAND_LOGO;
          }}
        />
        {logoSrc && !logoError && (
          <img
            src={logoSrc}
            alt={libraryName}
            className="ab-topbar__logo ab-topbar__library-logo"
            onError={() => setLogoError(true)}
          />
        )}
      </Link>

      {user && <NotificationBell />}

      <button
        type="button"
        className="ab-topbar__burger"
        aria-label={t({ id: 'nav.menu' })}
        aria-expanded={menuOpen}
        aria-controls="ab-topbar-nav"
        onClick={() => setMenuOpen((o) => !o)}
      >
        <svg width="22" height="22" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
          <path d="M3 6h18M3 12h18M3 18h18" stroke="currentColor" strokeWidth="2" strokeLinecap="round" fill="none" />
        </svg>
      </button>

      <div
        id="ab-topbar-nav"
        className={`ab-topbar__nav${menuOpen ? ' ab-topbar__nav--open' : ''}`}
        onClick={() => setMenuOpen(false)}
      >
        {/* ── Groupe 1 : accessible à tout user ─────────────── */}
        <Link to="/" className={isActive('/catalogo') || location.pathname === '/' ? 'active' : ''}>
          {t({ id: 'nav.catalog' })}
        </Link>

        {/* Annuaire public des bibliothèques (chantier PUBLIB) — visible de tout le monde, anon compris */}
        <Link to="/bibliotecas" className={isActive('/bibliotecas') ? 'active' : ''}>
          {t({ id: 'nav.bibliotecas' })}
        </Link>

        {/* Carte publique du réseau (cartographie, REGISTRE §34) — visible de tout le monde */}
        <Link to="/cartografia" className={isActive('/cartografia') ? 'active' : ''}>
          {t({ id: 'cartografia.nav' })}
        </Link>

        {/* Thésaurus partagé FICEDL (cache anti-fork, P3a) — visible de tout le monde */}
        <Link to="/thesaurus-ficedl" className={isActive('/thesaurus-ficedl') ? 'active' : ''}>
          {t({ id: 'nav.thesaurus' })}
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

        {/* ── Ferramentas federalistas : tout membre rattache (FED-2),
              entre biblioteca et rede (gradation d'echelle) ── */}
        {canSeeFederacao(role) && (
          <>
            <span className="ab-topbar__sep" aria-hidden="true">|</span>
            <Link to="/federacao" className={isActive('/federacao') ? 'active' : ''}>
              {t({ id: 'nav.federacao' })}
            </Link>
          </>
        )}

        {/* ── Groupe 4 : administrador AnarBib uniquement (Rede) ── */}
        {canSeeRede(isNetworkAdmin) && (
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
            {/* `next` : sans lui, LoginPage retombe sur son defaut /conta, et on
                perd la page consultee. Cas vecu le 19/08/2026 : depuis une fiche
                /livro/:id ouverte sans session, se connecter renvoyait sur « Mon
                compte » — jamais sur la fiche. LoginPage valide `next` et refuse
                les URL externes (getSafeNextUrl), donc pas d'open redirect.
                On n'ajoute rien depuis les pages d'authentification elles-memes,
                pour ne pas boucler. */}
            <Link to={AUTH_PATHS.has(location.pathname)
              ? '/cadastro'
              : `/cadastro?next=${encodeURIComponent(location.pathname + location.search)}`}>
              <Button variant="mini">{t({ id: 'nav.login' })}</Button>
            </Link>
            <Link to="/criar-conta" style={{ fontSize: '.78rem', color: 'var(--brand-muted, #aaa)' }}>
              {t({ id: 'nav.register' })}
            </Link>
          </>
        )}

        {/* Sélecteur de langue */}
        <LocaleSwitcher variant="header" />
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

// ── Footer ───────────────────────────────────────────────────

export function Footer() {
  const { formatMessage: t } = useIntl();
  return (
    <footer className="ab-footer">
      <span>{t({ id: 'app.footer' })}</span>
      <span aria-hidden="true" style={{ margin: '0 8px', color: 'var(--brand-muted, #888)' }}>·</span>
      <Link to="/privacidade" style={{ color: 'inherit', textDecoration: 'underline', textUnderlineOffset: 2 }}>
        {t({ id: 'nav.privacy' })}
      </Link>
      <span aria-hidden="true" style={{ margin: '0 8px', color: 'var(--brand-muted, #888)' }}>·</span>
      <LocaleSwitcher variant="footer" />
    </footer>
  );
}
