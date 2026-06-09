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

/**
 * Hook React qui expose le slug de thème "settled" de la bibliothèque active.
 * Usage : const { settledSlug } = useTheme('blmf');
 *
 * #THEME-FETCH-DROP (10/06/2026) : suppression du chemin de fetch de manifest.
 * Historique : useTheme tentait `fetchManifest(slug)` puis, en cas d'échec,
 * `fetchManifest('default')` pour appeler `applyManifest` (couleurs, assets,
 * polices, layout via variables CSS --brand-*). Or :
 *   - aucun `public/themes/<slug>/manifest.json` n'est déployé → CHAQUE fetch
 *     renvoie un 404 LENT (~7 s) ; la séquence slug→default coûtait ~14 s de
 *     requêtes inutiles à chaque login / chargement de page (biblio non-default) ;
 *   - `applyManifest` ne s'exécutait donc JAMAIS — et même s'il l'avait fait, les
 *     PATCH 02/05 et 06/05/2026 avaient déjà retiré le chargement des couleurs et
 *     des polices depuis le manifest. Le thème est désormais ENTIÈREMENT piloté
 *     par le CSS statique (src/styles/theme-base.css, importé dans main.jsx) ;
 *     le slug ne pilote aucune classe/variable côté JS.
 * Toute la machinerie morte (fetchManifest, applyManifest, applyColors,
 * applyBrandAssets, applyLayout, installFont, hexToRgbTriplet, setCssVar) a été
 * supprimée. Pour réactiver des thèmes par manifest un jour, voir l'historique
 * git de ce fichier ET déployer réellement les manifests + un timeout
 * AbortController pour échouer vite.
 *
 * Comme il n'y a plus aucun asynchronisme, le slug demandé est immédiatement
 * "settled" : `settledSlug === themeSlug` à chaque rendu. Les consommateurs qui
 * dérivent `themeReady = settledSlug === ctx.themeSlug` (LibraryContext) le
 * voient donc toujours vrai — cohérent avec #LOGIN-FIX H3 (la navigation
 * post-login ne dépend plus du thème).
 */
export function useTheme(themeSlug = 'default') {
  return { settledSlug: themeSlug };
}
