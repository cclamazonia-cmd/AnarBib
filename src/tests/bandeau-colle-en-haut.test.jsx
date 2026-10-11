// CHEMIN DÉPÔT : src/tests/bandeau-colle-en-haut.test.jsx
//
// CE QUE CE TEST PROTÈGE. Le menu des pages (Topbar, `.ab-topbar`) reste visible
// en haut de l'écran où que l'on soit dans la page (Xavier, 11/10/2026). Trois
// choses tiennent ensemble et aucune n'est vue par lint, build ou la suite :
//   1. le bandeau est collant, au-dessus de ce qui se colle dans les pages et
//      sous les fenêtres modales et les toasts ;
//   2. Topbar publie sa hauteur réelle dans `--ab-topbar-h` sur <html>, et la
//      retire au démontage ; tiroir mobile ouvert, il ne la publie pas ;
//   3. tout AUTRE élément collant d'une page qui monte le bandeau pose son `top`
//      sous cette hauteur — sinon il se glisse derrière le bandeau. La liste des
//      éléments collants des pages est FERMÉE : un nouveau doit passer ici.

import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, cleanup } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { MemoryRouter } from 'react-router-dom';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';

const racine = path.resolve(__dirname, '..');
const src = (rel) => readFileSync(path.resolve(racine, rel), 'utf8');

vi.mock('@/contexts/AuthContext', () => ({ useAuth: () => ({ user: null, signOut: () => {} }) }));
vi.mock('@/contexts/LibraryContext', () => ({ useLibrary: () => ({ libraryName: '', libraryId: null, role: null, isNetworkAdmin: false }) }));
vi.mock('@/components/notifications/NotificationBell', () => ({ default: () => null }));
vi.mock('@/components/LocaleSwitcher', () => ({ LocaleSwitcher: () => null }));
vi.mock('@/components/ui', () => ({ Button: ({ children }) => <button type="button">{children}</button> }));
vi.mock('@/lib/theme', () => ({ resolveLibraryLogo: () => null, DEFAULT_BRAND_LOGO: '/img/logo.png' }));
vi.mock('@/lib/supabase', () => ({ supabase: { from: () => ({ select: () => ({ eq: () => ({ maybeSingle: async () => ({ data: null }) }) }) }) } }));

const { Topbar } = await import('@/components/layout');

afterEach(() => { cleanup(); document.documentElement.style.removeProperty('--ab-topbar-h'); });

const monter = () => render(
  <IntlProvider locale="fr" messages={{}} onError={() => {}}>
    <MemoryRouter initialEntries={['/catalogacao']}><Topbar /></MemoryRouter>
  </IntlProvider>,
);

describe('le bandeau publie sa hauteur dans --ab-topbar-h', () => {
  it('pose la variable au montage et la retire au démontage', () => {
    const { unmount } = monter();
    expect(document.documentElement.style.getPropertyValue('--ab-topbar-h')).toMatch(/^\d+px$/);
    unmount();
    expect(document.documentElement.style.getPropertyValue('--ab-topbar-h')).toBe('');
  });

  it('tiroir ouvert : la hauteur du tiroir n’est pas publiée', () => {
    const racineCss = document.documentElement.style;
    const { container } = monter();
    const avant = racineCss.getPropertyValue('--ab-topbar-h');
    const nav = container.querySelector('.ab-topbar__nav');
    nav.classList.add('ab-topbar__nav--open');
    window.dispatchEvent(new Event('resize'));
    expect(racineCss.getPropertyValue('--ab-topbar-h')).toBe(avant);
  });
});

describe('contrat de source — layout.css et Topbar', () => {
  const css = src('components/layout/layout.css');
  const bloc = css.slice(css.indexOf('.ab-topbar {'), css.indexOf('}', css.indexOf('.ab-topbar {')));

  it('le bandeau est collant, sous l’encoche, au-dessus des pages et sous les modales', () => {
    expect(bloc).toMatch(/position:\s*sticky/);
    expect(bloc).toMatch(/top:\s*env\(safe-area-inset-top, 0px\)/);
    expect(bloc).toMatch(/z-index:\s*100;/);
    expect(bloc).toMatch(/backdrop-filter/);
    // Sous les fenêtres modales et les toasts, au-dessus de la barre d'état du catalogage (30).
    expect(src('components/ui/Modal.css')).toMatch(/z-index:\s*1000;/);
    expect(src('pages/catalogacao/CatalogacaoPage.css')).toMatch(/\.cat-status \{\s*position: sticky;[^}]*z-index: 30;/);
  });

  it('le défilement vers une ancre s’arrête sous le bandeau', () => {
    expect(css).toMatch(/html \{ scroll-padding-top: calc\(var\(--ab-topbar-h, 0px\) \+ 8px\); \}/);
  });

  it('tiroir mobile ouvert : le bandeau ne dépasse pas l’écran', () => {
    expect(css).toMatch(/\.ab-topbar:has\(\.ab-topbar__nav--open\) \{\s*max-height: calc\(100dvh - env\(safe-area-inset-top, 0px\)\);\s*overflow-y: auto;/);
  });

  it('Topbar mesure le <nav> lui-même et se passe de ResizeObserver quand il manque', () => {
    const jsx = src('components/layout/index.jsx');
    expect(jsx).toContain('<nav className="ab-topbar" ref={barRef}>');
    expect(jsx).toContain("racine.style.setProperty('--ab-topbar-h'");
    expect(jsx).toContain("typeof ResizeObserver === 'undefined'");
    expect(jsx).toContain("racine.style.removeProperty('--ab-topbar-h')");
  });
});

describe('ce qui se colle dans les pages passe SOUS le bandeau', () => {
  // Éléments collants connus des feuilles de style des pages, hors conteneurs à
  // défilement propre (thead d'une table dans .ab-table-wrap) et hors pages
  // sans bandeau (ReaderPage). Liste fermée : un nouveau `position: sticky`
  // dans src/pages/**/*.css doit soit poser son top sur --ab-topbar-h, soit
  // être ajouté ici avec sa raison.
  const SANS_OFFSET = new Set([
    'pages/public/CatalogPage.css',   // thead de .ab-table-wrap (overflow: auto) : défile dans son cadre
    'pages/public/ReaderPage.css',    // la salle de lecture ne monte pas le bandeau
  ]);

  function cssDesPages(dir, acc = []) {
    for (const nom of readdirSync(dir)) {
      const p = path.join(dir, nom);
      if (statSync(p).isDirectory()) cssDesPages(p, acc);
      else if (nom.endsWith('.css')) acc.push(p);
    }
    return acc;
  }

  it('chaque `position: sticky` d’une page pose son top sur --ab-topbar-h', () => {
    const fautifs = [];
    for (const fichier of cssDesPages(path.resolve(racine, 'pages'))) {
      const rel = path.relative(racine, fichier).split(path.sep).join('/');
      if (SANS_OFFSET.has(rel)) continue;
      const css = readFileSync(fichier, 'utf8');
      const re = /position:\s*sticky;?([^}]*)\}/g;
      let m;
      while ((m = re.exec(css))) {
        const corps = m[1];
        // `top` peut précéder `position` dans la même règle : on relit la règle entière.
        const debut = css.lastIndexOf('{', m.index);
        const regle = css.slice(debut, m.index + m[0].length);
        if (!/var\(--ab-topbar-h/.test(regle) && !/var\(--ab-topbar-h/.test(corps)) fautifs.push(`${rel} : ${regle.replace(/\s+/g, ' ').slice(0, 90)}`);
      }
    }
    expect(fautifs).toEqual([]);
  });

  it('les trois éléments connus sont décalés', () => {
    expect(src('pages/catalogacao/CatalogacaoPage.css')).toContain('.cat-status {\n  position: sticky; top: calc(var(--ab-topbar-h, 0px) + 8px); z-index: 30;');
    expect(src('pages/catalogacao/CatalogacaoPage.css')).toContain('.ab-preview { position: sticky; top: calc(var(--ab-topbar-h, 0px) + 18px); }');
    expect(src('pages/atelier/AtelierConstituicaoPage.css')).toContain('.ab-atl-anchor{ position:sticky; top:calc(var(--ab-topbar-h, 0px) + 18px);');
  });
});
