import { useEffect, useState, useCallback } from 'react';
import { PROJECT_REF } from './supabase';

const THEME_BUCKET = 'library-ui-assets';
const SUPABASE_URL = `https://${PROJECT_REF}.supabase.co`;

export function publicAssetUrl(path) {
  return `${SUPABASE_URL}/storage/v1/object/public/${THEME_BUCKET}/${path}`;
}

function setCssVar(name, value) {
  if (value == null || value === '') return;
  document.documentElement.style.setProperty(name, value);
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
}

function applyBrandAssets(assets) {
  if (!assets) return;
  const bg = assets.backgroundPage || assets.background || assets.bgImage || '';
  // PATCH 02/05/2026 : on n'utilise plus l'image de fond pour les briques.
  // --brand-panel-bg-image conserve sa valeur par défaut de theme-base.css
  // (un dégradé rouge AnarBib opaque). Le manifest peut toujours définir
  // --brand-bg-image (image de fond globale de la page), mais les panels/cards
  // utilisent un dégradé pour rester lisibles et identitaires.
  if (bg) setCssVar('--brand-bg-image', `url("${bg}")`);
  setCssVar('--brand-bg-position', assets.backgroundPosition || 'center center');
  setCssVar('--brand-bg-size', assets.backgroundSize || 'cover');
  setCssVar('--brand-bg-repeat', assets.backgroundRepeat || 'no-repeat');

  if (assets.favicon) {
    let link = document.querySelector("link[rel='icon']");
    if (!link) {
      link = document.createElement('link');
      link.rel = 'icon';
      document.head.appendChild(link);
    }
    link.href = assets.favicon;
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
  applyBrandAssets(manifest.assets);
  applyColors(manifest.colors);
  applyLayout(manifest.layout);
  // PATCH 02/05/2026 : on ne charge plus les polices heading/accent depuis le manifest.
  // Le manifest BLMF chargeait "THE BOLD FONT - Free Version" (titre.ttf), une police
  // display all-caps qui ne contient pas les minuscules accentuées (â, è, é...).
  // Résultat : "TâCHES INTERNES DE LA BIBLIOTHèQUE" avec un mélange capitales/Times
  // New Roman fallback sur les diacritiques. Bitter (la valeur par défaut de
  // theme-base.css) supporte tous les diacritiques nécessaires.
  // if (manifest.fonts?.heading) await installFont(manifest.fonts.heading, '--brand-font-heading');
  if (manifest.fonts?.body) await installFont(manifest.fonts.body, '--brand-font-body');
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
 */
export function useTheme(themeSlug = 'default') {
  const [manifest, setManifest] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
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
        if (!cancelled) setLoading(false);
      }
    })();

    return () => { cancelled = true; };
  }, [themeSlug]);

  return { manifest, loading };
}
