import { useState, useEffect, useRef } from 'react';
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

// E20 : un groupe de la barre — un bouton qui ouvre (clic, Entrée, Espace) un
// menu de liens. Le menu reste dans le DOM, masqué (`hidden`) quand il est
// fermé. Le clic sur le bouton ne remonte pas au tiroir mobile, qui se
// fermerait ; le clic sur un lien, si.
function NavGroupe({ id, label, ouvert, actif, onBasculer, refBouton, children }) {
  return (
    <div className={`ab-topbar__groupe${ouvert ? ' ab-topbar__groupe--open' : ''}`}>
      <button
        type="button"
        ref={(el) => { refBouton.current[id] = el; }}
        className={`ab-topbar__groupe-btn${actif ? ' active' : ''}`}
        aria-haspopup="true"
        aria-expanded={ouvert}
        aria-controls={`ab-topbar-menu-${id}`}
        onClick={(e) => { e.stopPropagation(); onBasculer(id); }}
      >
        {label}
        <span className="ab-topbar__chevron" aria-hidden="true">▾</span>
      </button>
      <div id={`ab-topbar-menu-${id}`} className="ab-topbar__menu" hidden={!ouvert}>
        {children}
      </div>
    </div>
  );
}

export function Topbar() {
  const { formatMessage: t } = useIntl();
  const { user, signOut } = useAuth();
  const { libraryName, libraryId, role, isNetworkAdmin } = useLibrary();
  const location = useLocation();

  // Par segment : « /biblioteca » ne s'allume plus sur « /bibliotecas » (E20 —
  // sinon le menu Travail se dirait actif sur l'annuaire public).
  const isActive = (path) => location.pathname === path || location.pathname.startsWith(`${path}/`);

  // E20 : le menu ouvert (un seul à la fois), et les boutons pour y rendre le
  // focus à Échap. Les entrées de Travail, chacune sous son `canSee*`.
  const [groupe, setGroupe] = useState(null);
  const refsBoutons = useRef({});
  const basculer = (id) => setGroupe((g) => (g === id ? null : id));
  const travail = [
    canSeePainel(role) && { to: '/painel', label: 'nav.panel' },
    canSeeCatalogacao(role) && { to: '/catalogacao', label: 'nav.catalogacao' },
    canSeeImportacoes(role) && { to: '/importacoes', label: 'nav.importacoes' },
    // Le lien porte le titre réel de la page (« Gestion de la bibliothèque »),
    // pas « Bibliothèque » : à côté de « Bibliothèques » (l'annuaire public),
    // un singulier seul ne disait pas ce qu'on y trouve (Xavier, 15/09/2026).
    // `nav.library` reste en usage comme en-tête de colonne dans RedePage.
    canSeeBiblioteca(role) && { to: '/biblioteca', label: 'nav.biblioteca' },
    // Outils fédéralistes : tout membre rattaché (FED-2).
    canSeeFederacao(role) && { to: '/federacao', label: 'nav.federacao' },
    canSeeRede(isNetworkAdmin) && { to: '/rede', label: 'nav.network' },
  ].filter(Boolean);

  // Un menu se ferme à chaque navigation, à Échap (le focus revient à son
  // bouton) et au clic hors des menus.
  useEffect(() => { setGroupe(null); }, [location.pathname]);
  useEffect(() => {
    if (!groupe) return undefined;
    const surTouche = (e) => {
      if (e.key !== 'Escape') return;
      const bouton = refsBoutons.current[groupe];
      setGroupe(null);
      bouton?.focus();
    };
    const surClic = (e) => { if (!e.target.closest?.('.ab-topbar__groupe')) setGroupe(null); };
    document.addEventListener('keydown', surTouche);
    document.addEventListener('mousedown', surClic);
    return () => { document.removeEventListener('keydown', surTouche); document.removeEventListener('mousedown', surClic); };
  }, [groupe]);

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

  // Bandeau collant (Xavier, 11/10/2026) : le menu des pages reste visible en
  // haut de l'écran où que l'on soit dans la page (layout.css, .ab-topbar). Sa
  // hauteur varie (logos, retour à la ligne des liens, largeur d'écran) : on la
  // publie en variable CSS `--ab-topbar-h` sur <html>, pour que ce qui se colle
  // aussi (barre d'état du catalogage, prévia de cote, ancre de l'Atelier) et le
  // défilement vers une ancre (scroll-padding-top) s'arrêtent SOUS le bandeau,
  // pas derrière lui. Tiroir mobile ouvert : on ne publie pas sa hauteur, le
  // reste de la page n'a pas à descendre d'un écran. Sans ResizeObserver
  // (jsdom), une mesure au montage puis à chaque redimensionnement.
  const barRef = useRef(null);
  useEffect(() => {
    const el = barRef.current;
    if (!el) return undefined;
    const racine = document.documentElement;
    const publier = () => {
      if (el.querySelector('.ab-topbar__nav--open')) return;
      racine.style.setProperty('--ab-topbar-h', `${Math.round(el.getBoundingClientRect().height)}px`);
    };
    publier();
    if (typeof ResizeObserver === 'undefined') {
      window.addEventListener('resize', publier);
      return () => { window.removeEventListener('resize', publier); racine.style.removeProperty('--ab-topbar-h'); };
    }
    const observateur = new ResizeObserver(publier);
    observateur.observe(el);
    return () => { observateur.disconnect(); racine.style.removeProperty('--ab-topbar-h'); };
  }, []);


  return (
    <nav className="ab-topbar" ref={barRef}>
      <Link to="/" className="ab-topbar__brand">
        {/* Deux emplacements, deux echelles : le RESEAU, puis la BIBLIOTHEQUE
            de session. C'est le sens du bandeau et il ne change pas.

            Logo auto-heberge (19/08/2026) : il etait hotlinke sur un WordPress
            externe (cclamazonia.noblogs.org), ce qui exposait l'IP de chaque
            visiteur a un tiers et faisait dependre le bandeau d'un site que
            nous ne maitrisons pas. Le fichier vit desormais dans public/img/.

            Le 20/08, un essai a rendu ce premier emplacement pilotable par
            thema de bibliotheque. Deux raisons de l'avoir retire :
              1. il faisait DOUBLON — le logo de la biblio est deja le second
                 emplacement, tire de library_commons. Sur BLMF, le bandeau
                 affichait deux fois le meme embleme, par deux fichiers
                 distincts (themes/blmf/logo-v2.png au manifeste,
                 themes/blmf/logo-blmf-v2.png dans library_commons) ;
              2. il effacait AnarBib de sa propre application : sur une biblio
                 a thema, le reseau disparaissait du bandeau. */}
        <img
          src={DEFAULT_BRAND_LOGO}
          alt="AnarBib"
          className="ab-topbar__logo"
          data-brand-logo
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
        {/* E20 (Xavier, 08/09/2026) : la barre se regroupe par NATURE, pas par
            rôle — une coordination est aussi bibliothécaire et lectrice, un
            menu par rôle lui en montrerait deux pour elle seule. Le catalogue
            reste un lien direct (la porte publique) ; puis trois menus, Public,
            Moi, Travail, qui s'ouvrent au clic ou au clavier (Entrée, Espace),
            se ferment à Échap, au clic ailleurs et à chaque navigation — jamais
            au survol. Chaque entrée garde son `canSee*` ; un groupe sans
            entrée n'apparaît pas. Aucun chemin ne change (les 51 intentions de
            « Je veux… » et les liens du Manuel restent valides). Dans le
            tiroir mobile, les menus se déplient sur place. */}
        <Link to="/" className={isActive('/catalogo') || location.pathname === '/' ? 'active' : ''}>
          {t({ id: 'nav.catalog' })}
        </Link>

        <NavGroupe id="public" label={t({ id: 'nav.group.public' })} ouvert={groupe === 'public'} onBasculer={basculer}
          actif={['/bibliotecas', '/cartografia', '/thesaurus-ficedl'].some(isActive)} refBouton={refsBoutons}>
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
        </NavGroupe>

        {user && (
          <NavGroupe id="moi" label={t({ id: 'nav.group.me' })} ouvert={groupe === 'moi'} onBasculer={basculer}
            actif={['/conta', '/inicio'].some(isActive)} refBouton={refsBoutons}>
            {user && canSeeAccount(role) && (
              <Link to="/conta" className={isActive('/conta') ? 'active' : ''}>
                {t({ id: 'nav.account' })}
              </Link>
            )}
            {/* « Je veux… » : dire ce qu'on veut faire, et y être mené (05/09/2026). */}
            <Link to="/inicio" className={isActive('/inicio') ? 'active' : ''}>
              {t({ id: 'nav.inicio' })}
            </Link>
          </NavGroupe>
        )}

        {travail.length > 0 && (
          <NavGroupe id="travail" label={t({ id: 'nav.group.work' })} ouvert={groupe === 'travail'} onBasculer={basculer}
            actif={travail.some((e) => isActive(e.to))} refBouton={refsBoutons}>
            {travail.map((e) => (
              <Link key={e.to} to={e.to} className={isActive(e.to) ? 'active' : ''}>
                {t({ id: e.label })}
              </Link>
            ))}
          </NavGroupe>
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
  const location = useLocation();
  return (
    <footer className="ab-footer">
      <span>{t({ id: 'app.footer' })}</span>
      <span aria-hidden="true" style={{ margin: '0 8px', color: 'var(--brand-muted, #888)' }}>·</span>
      <Link to="/privacidade" style={{ color: 'inherit', textDecoration: 'underline', textUnderlineOffset: 2 }}>
        {t({ id: 'nav.privacy' })}
      </Link>
      <span aria-hidden="true" style={{ margin: '0 8px', color: 'var(--brand-muted, #888)' }}>·</span>
      {/* E14 (24/09/2026) : signaler un problème depuis n'importe quelle page, sans compte ; la page d'origine part avec. */}
      <Link to={`/relatar-problema?de=${encodeURIComponent(location.pathname)}`} style={{ color: 'inherit', textDecoration: 'underline', textUnderlineOffset: 2 }}>
        {t({ id: 'nav.report' })}
      </Link>
      <span aria-hidden="true" style={{ margin: '0 8px', color: 'var(--brand-muted, #888)' }}>·</span>
      <LocaleSwitcher variant="footer" />
    </footer>
  );
}
