import { useEffect, useState, useCallback } from 'react';
import { PROJECT_REF } from './supabase';

const THEME_BUCKET = 'library-ui-assets';
const SUPABASE_URL = `https://${PROJECT_REF}.supabase.co`;

export function publicAssetUrl(path) {
  return `${SUPABASE_URL}/storage/v1/object/public/${THEME_BUCKET}/${path}`;
}

// ── Résolution data-driven du logo d'une bibliothèque (source partagée) ──────
// Source unique utilisée par la carte lecteur (MyLibraryContactCard) ET le
// header (Topbar). Auparavant la même logique était DUPLIQUÉE dans les deux
// (resolveLogo / resolveLogoData), d'où un risque de désync (item 2).
//   - logo_url retenu SEULEMENT si URL absolue http(s) (les valeurs relatives
//     héritées, ex. ./assets/.../logo-btl.png, sont ignorées — cf. TR-6.2b) ;
//   - sinon logo_file_key : chemin complet dans le bucket (convention cible)
//     OU slug nu hérité (filet : expansé en themes/<slug>/logo-<slug>.png) ;
//   - sinon null (le composant retombe sur son repli texte).
export function resolveLibraryLogo(commons) {
  if (!commons) return null;
  const url = typeof commons.logo_url === 'string' ? commons.logo_url.trim() : '';
  if (/^https?:\/\//i.test(url)) return url;
  const key = commons.logo_file_key;
  if (typeof key === 'string' && key.trim() !== '') {
    const tail = key.includes('/') ? key : `themes/${key}/logo-${key}.png`;
    return publicAssetUrl(tail);
  }
  return null;
}

// ── Logo de marque du bandeau (data-brand-logo) ──────────────────────────────
// Fichier servi par notre propre origine, versionne par le deploiement.
export const DEFAULT_BRAND_LOGO = '/img/logo-anarbib.png';

// Le bandeau porte TOUJOURS ce logo : il dit le reseau, et le logo de la
// bibliotheque de session occupe le second emplacement (resolveLibraryLogo
// ci-dessus). Un `resolveBrandLogo` a existe le 20/08, qui rendait ce premier
// emplacement pilotable par le manifeste d'un thema de biblio ; il a ete retire
// le jour meme : il faisait doublon avec le second emplacement (deux fichiers
// distincts, le meme embleme, affiche deux fois sur BLMF) et effacait AnarBib
// de sa propre application. Un thema de bibliotheque habille l'application —
// couleurs, fond, favicon — il ne remplace pas la marque du reseau.

function setCssVar(name, value) {
  if (value == null || value === '') return;
  document.documentElement.style.setProperty(name, value);
}

// Convertit '#RRGGBB' en triplet 'r, g, b' pour --brand-action-rgb (compose
// avec des alphas variés via rgba() dans ui.css). null si format invalide.
function hexToRgbTriplet(hex) {
  const m = /^#?([0-9a-f]{6})$/i.exec(String(hex || '').trim());
  if (!m) return null;
  const n = parseInt(m[1], 16);
  return `${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}`;
}

async function installFont(definition, cssVarName) {
  if (!definition?.family || !definition?.url) return;
  try {
    const fontFace = new FontFace(
      definition.family,
      `url(${definition.url})`,
      {
        style: definition.style || 'normal',
        weight: definition.weight || '400',
        display: definition.display || 'swap',
      }
    );
    const loaded = await fontFace.load();
    document.fonts.add(loaded);
    setCssVar(cssVarName, `"${definition.family}"`);
  } catch (err) {
    console.warn('[AnarBib] Font load failed:', definition.family, err);
  }
}

function applyColors(colors) {
  if (!colors) return;
  setCssVar('--brand-color-primary', colors.primary);
  setCssVar('--brand-color-secondary', colors.secondary);
  setCssVar('--brand-color-accent', colors.accent);
  setCssVar('--brand-panel-bg', colors.panelBg);
  setCssVar('--brand-panel-border', colors.panelBorder);
  setCssVar('--brand-text', colors.text);
  setCssVar('--brand-muted', colors.muted);
  // PATCH 02/05/2026 : --brand-link n'est plus injecté depuis le manifest.
  // La couleur des liens (notamment titres et auteurs dans les tableaux) est
  // désormais définie par theme-base.css à #ffffff (blanc cassé), pour
  // garantir la lisibilité sur le dégradé rouge des briques.
  // setCssVar('--brand-link', colors.link);
  setCssVar('--brand-bg-overlay', colors.bgOverlay);
  setCssVar('--brand-button-text', colors.buttonText);
  // Couleur d'action themable (boutons primaires, focus-ring, bordures). Le
  // manifest fournit un hex ; on le convertit en triplet RGB. Sans colors.action,
  // --brand-action-rgb garde le rouge AnarBib defini dans theme-base.css.
  if (colors.action) {
    const rgb = hexToRgbTriplet(colors.action);
    if (rgb) {
      setCssVar('--brand-action-rgb', rgb);
      setCssVar('--brand-accent-rgb', rgb);
    }
  }
}

// Instantané des <link rel="icon"> déclarés par index.html, pris AVANT toute
// réécriture. Sert à restaurer les icônes AnarBib quand on revient au thème
// `default` (déconnexion, sortie d'une bibliothèque) : sans lui, l'icône de la
// dernière bibliothèque visitée resterait collée dans l'onglet.
const BASE_ICON_LINKS = typeof document === 'undefined'
  ? []
  : [...document.querySelectorAll("link[rel='icon']")].map((el) => ({
      el,
      href: el.getAttribute('href'),
      sizes: el.getAttribute('sizes'),
    }));

function applyBrandAssets(assets, themeSlug) {
  if (!assets) return;
  const bg = assets.backgroundPage || assets.background || assets.bgImage || '';
  // PATCH 02/05/2026 : on n'utilise plus l'image de fond pour les briques.
  // --brand-panel-bg-image conserve sa valeur par défaut de theme-base.css
  // (un dégradé rouge AnarBib opaque). Le manifest peut toujours définir
  // --brand-bg-image (image de fond globale de la page), mais les panels/cards
  // utilisent un dégradé pour rester lisibles et identitaires.
  if (bg) {
    // #LOGIN-FIX H3 : précharger l'image AVANT d'appliquer la variable CSS, pour
    // que le basculement de fond (AnarBib → biblio) soit instantané (peint depuis
    // le cache) au lieu d'un fetch-puis-paint visible. background-image n'étant pas
    // animable en CSS, le préchargement est le principal levier anti-flash.
    const apply = () => setCssVar('--brand-bg-image', `url("${bg}")`);
    const pre = new Image();
    pre.onload = apply;
    pre.onerror = apply; // filet : appliquer quand même si le préchargement échoue
    pre.src = bg;
  }
  setCssVar('--brand-bg-position', assets.backgroundPosition || 'center center');
  setCssVar('--brand-bg-size', assets.backgroundSize || 'cover');
  setCssVar('--brand-bg-repeat', assets.backgroundRepeat || 'no-repeat');

  if (assets.favicon) {
    // PATCH 07/06/2026 : reecrire TOUS les <link rel="icon"> (32/192/512), pas
    // seulement le premier. index.html declare 3 tailles dont 192/512 pointent
    // sur /img/ (emblème AnarBib) ; le navigateur privilegiant la plus grande
    // icone, il affichait toujours AnarBib et le favicon par bibliotheque ne
    // s'appliquait jamais dans l'onglet. On pointe toutes les tailles vers le
    // favicon du theme (256px, downscale propre par le navigateur).
    // PATCH 19/08/2026 : le theme `default` ne reecrit plus rien. Son favicon
    // EST celui d'index.html — meme dessin, mais servi par notre propre origine
    // et renouvele a chaque deploiement. Le detour par la copie Supabase
    // n'apportait aucune difference visuelle et coutait cher : URL jamais
    // versionnee, `max-age=3600`, autre domaine. Resultat observe, l'icone
    // attendue s'affichait puis etait SUPPLANTEE par l'ancienne, que le
    // navigateur ressortait de son cache HTTP pendant une heure apres chaque
    // changement de logo. On restaure donc l'instantane d'index.html.
    // Les themes de BIBLIOTHEQUE, eux, doivent toujours supplanter AnarBib.
    if (themeSlug === 'default') {
      BASE_ICON_LINKS.forEach(({ el, href, sizes }) => {
        if (href) el.setAttribute('href', href);
        if (sizes) el.setAttribute('sizes', sizes);
      });
      return;
    }

    const iconLinks = document.querySelectorAll("link[rel='icon']");
    if (iconLinks.length === 0) {
      const link = document.createElement('link');
      link.rel = 'icon';
      link.href = assets.favicon;
      document.head.appendChild(link);
    } else {
      iconLinks.forEach((l) => {
        l.href = assets.favicon;
        // Un favicon de theme fait 256 px. Laisser le `sizes="512x512"` herite
        // d'index.html ferait MENTIR la declaration : le navigateur choisit son
        // icone d'apres ce chiffre, puis recoit une image d'une autre taille.
        // On retire l'attribut, il se fie alors a l'image elle-meme.
        l.removeAttribute('sizes');
      });
    }
  }
}

function applyLayout(layout) {
  if (!layout) return;
  setCssVar('--brand-radius', layout.radius);
  setCssVar('--brand-shadow', layout.shadow);
  setCssVar('--brand-hero-max-width', layout.heroMaxWidth);
  setCssVar('--brand-container-max-width', layout.containerMaxWidth);
}

async function applyManifest(manifest) {
  applyBrandAssets(manifest.assets, manifest.__resolvedSlug);
  applyColors(manifest.colors);
  applyLayout(manifest.layout);
  // PATCH 02/05/2026 : on ne charge plus les polices heading/accent depuis le manifest.
  // Le manifest BLMF chargeait "THE BOLD FONT - Free Version" (titre.ttf), une police
  // display all-caps qui ne contient pas les minuscules accentuées (â, è, é...).
  // Résultat : "TâCHES INTERNES DE LA BIBLIOTHèQUE" avec un mélange capitales/Times
  // New Roman fallback sur les diacritiques. Bitter (la valeur par défaut de
  // theme-base.css) supporte tous les diacritiques nécessaires.
  //
  // PATCH 06/05/2026 : on ne charge plus non plus la police body depuis le manifest.
  // Le manifest default chargeait interface.ttf (~107 kB) depuis le bucket Supabase.
  // Désormais, Bitter et Fira Sans sont auto-hébergées en woff2 subseté Latin Extended
  // dans public/fonts/, déclarées dans src/styles/fonts.css avec font-display: swap.
  // Cela élimine la dépendance au bucket Supabase pour les polices et économise
  // ~204 kB par chargement (interface.ttf chargée 2x à cause des montages concurrents
  // de useTheme). Si un jour on veut réactiver les polices custom par biblio, il
  // suffira de décommenter ces 3 lignes — mais il faudra aussi vider/désactiver
  // public/fonts/ pour éviter le double chargement.
  // if (manifest.fonts?.heading) await installFont(manifest.fonts.heading, '--brand-font-heading');
  // if (manifest.fonts?.body) await installFont(manifest.fonts.body, '--brand-font-body');
  // if (manifest.fonts?.accent) await installFont(manifest.fonts.accent, '--brand-font-accent');
}

async function fetchManifest(themeSlug) {
  const slug = String(themeSlug || 'default').trim().toLowerCase() || 'default';
  const url = publicAssetUrl(`themes/${slug}/manifest.json`);
  const res = await fetch(url, { cache: 'no-store' });
  if (!res.ok) throw new Error(`Theme manifest not found: ${slug}`);
  const manifest = await res.json();
  manifest.__resolvedSlug = slug;
  return manifest;
}

/**
 * Hook React qui charge le thème de la bibliothèque active.
 * Usage : const { manifest, loading } = useTheme('blmf');
 *
 * `ready` (P1, 12/06/2026) : quand false, le hook NE charge AUCUN manifest. Sert
 * à attendre que le slug effectif de la biblio soit résolu (cf. LibraryContext)
 * avant de fetcher, pour ne pas charger `default` puis le vrai thème (double
 * chargement). Pendant l'attente, le CSS de base (theme-base.css) fait le rendu.
 */
export function useTheme(themeSlug = 'default', ready = true) {
  const [manifest, setManifest] = useState(null);
  const [loading, setLoading] = useState(true);
  // #LOGIN-FIX H1 : slug pour lequel le thème est RÉELLEMENT appliqué (succès ou
  // fallback). Exposé pour que les consommateurs dérivent `themeReady` de façon
  // SYNCHRONE au rendu (settledSlug === themeSlug demandé) : au changement de
  // themeSlug, settledSlug garde l'ancienne valeur tant que le nouveau manifest
  // n'est pas appliqué → pas de race d'ordre d'effets, pas de deadlock (le
  // fallback marque aussi le slug demandé comme settled).
  const [settledSlug, setSettledSlug] = useState(null);

  useEffect(() => {
    // P1 : tant que le slug effectif n'est pas résolu (ready=false), on ne charge
    // aucun manifest -> évite le fetch 'default' transitoire suivi du fetch du vrai
    // thème. Le CSS de base (theme-base.css) assure le rendu pendant ce court délai.
    if (!ready) return;
    let cancelled = false;
    setLoading(true);

    (async () => {
      try {
        const m = await fetchManifest(themeSlug);
        if (!cancelled) {
          await applyManifest(m);
          setManifest(m);
        }
      } catch {
        if (themeSlug !== 'default') {
          try {
            const fallback = await fetchManifest('default');
            if (!cancelled) {
              await applyManifest(fallback);
              setManifest(fallback);
            }
          } catch {
            // no theme at all — CSS defaults will apply
          }
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
          setSettledSlug(themeSlug);
        }
      }
    })();

    return () => { cancelled = true; };
  }, [themeSlug, ready]);

  return { manifest, loading, settledSlug };
}
