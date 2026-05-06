// ============================================================================
// _shared/mail/inline-images.ts — Embed des images logos en base64 dans le HTML
// ============================================================================
// Objectif : résoudre le bug logos Brevo (cf. BUG_LOGOS_BREVO_TRACKER_2026-05-06.md).
//
// Problème : Brevo réécrit toutes les <img src="https://..."> pour passer par
// son CDN tracker (sendibt3.com). Cette CDN a une durée de vie courte → les
// logos cassent rapidement dans les archives mail.
//
// Solution : avant l'envoi via Brevo, télécharger les images des logos depuis
// leur URL source (typiquement Supabase Storage) et les embarquer directement
// dans le HTML sous forme `data:image/png;base64,...`. Brevo ne peut pas
// réécrire ce qui n'est pas une URL distante.
//
// Performance : un cache mémoire (Map globale) évite de re-télécharger les
// mêmes logos à chaque envoi. Les logos AnarBib + biblio sont stables (pas
// de TTL nécessaire). Le cache vit la durée de vie de l'instance EF Deno
// (typiquement quelques minutes à quelques heures), puis se reconstruit
// automatiquement à froid.
//
// Sécurité : on n'inline QUE les images dont l'URL contient "supabase.co" ou
// "supabase.in". Si une notification contient une image externe (ex.
// couverture de livre Open Library), elle reste en URL distante et Brevo la
// gère comme avant.
//
// Cette transformation est appliquée dans transport/email.ts juste avant
// l'envoi via sendBrevoEmail. Aucune modification nécessaire dans les
// fichiers domain ou dans renderEmail (qui reste synchrone).
// ============================================================================

// Cache mémoire global : URL source -> data URI base64
const logoCache = new Map<string, string>();

/**
 * Télécharge une image depuis une URL et la convertit en data URI base64.
 * Utilise un cache mémoire pour éviter les téléchargements répétés.
 *
 * @param url URL source de l'image (typiquement Supabase Storage)
 * @returns Le data URI `data:<mime>;base64,<b64>`, ou l'URL d'origine en cas d'échec
 */
export async function inlineImageUrl(url: string): Promise<string> {
  if (!url) return url;
  if (url.startsWith("data:")) return url; // déjà inliné

  const cached = logoCache.get(url);
  if (cached) return cached;

  try {
    const res = await fetch(url);
    if (!res.ok) {
      console.warn(`[inline-image] fetch ${res.status} for ${url}`);
      return url; // fallback à l'URL originale
    }

    const contentType = res.headers.get("content-type") || "image/png";
    const buffer = await res.arrayBuffer();
    const bytes = new Uint8Array(buffer);

    // Conversion en base64 via btoa (chunks pour éviter les limites de stack)
    let binary = "";
    const chunkSize = 0x8000; // 32 KB
    for (let i = 0; i < bytes.length; i += chunkSize) {
      const chunk = bytes.subarray(i, i + chunkSize);
      binary += String.fromCharCode(...chunk);
    }
    const base64 = btoa(binary);
    const dataUri = `data:${contentType};base64,${base64}`;

    logoCache.set(url, dataUri);
    console.log(`[inline-image] cached ${url} (${bytes.length} bytes -> ${dataUri.length} chars b64)`);
    return dataUri;

  } catch (e) {
    console.warn(`[inline-image] error for ${url}:`, e);
    return url; // fallback à l'URL originale
  }
}

/**
 * Vérifie si une URL doit être inlinée. On inline uniquement les images
 * hébergées sur Supabase Storage (logos AnarBib + biblio), pas les images
 * externes.
 */
function shouldInline(url: string): boolean {
  if (!url) return false;
  if (url.startsWith("data:")) return false;
  // Cible : URLs Supabase Storage uniquement
  return url.includes("supabase.co") || url.includes("supabase.in");
}

/**
 * Parcourt un HTML et remplace toutes les `<img src="https://...">` par
 * leur version base64 inline, pour les URLs qui matchent shouldInline().
 *
 * Comportement défensif : si le téléchargement d'une image échoue, l'URL
 * d'origine est conservée et l'envoi du mail continue normalement.
 *
 * @param html HTML source
 * @returns HTML modifié avec les data URIs à la place des URLs distantes
 */
export async function inlineLogosInHtml(html: string): Promise<string> {
  if (!html) return html;

  // Match toutes les balises <img ... src="..."> et capture l'URL
  const matches = [...html.matchAll(/<img[^>]+src="([^"]+)"/gi)];
  if (matches.length === 0) return html;

  const urlsToInline = new Set<string>();
  for (const m of matches) {
    const url = m[1];
    if (shouldInline(url)) urlsToInline.add(url);
  }

  if (urlsToInline.size === 0) return html;

  // Inline en parallèle pour économiser du temps
  const replacements = await Promise.all(
    Array.from(urlsToInline).map(async (url) => {
      const dataUri = await inlineImageUrl(url);
      return { url, dataUri };
    })
  );

  // Applique les remplacements (split/join est sûr car les URLs ne
  // contiennent pas de caractères spéciaux regex)
  let result = html;
  for (const { url, dataUri } of replacements) {
    if (dataUri !== url) {
      result = result.split(url).join(dataUri);
    }
  }

  return result;
}

/**
 * Vide le cache mémoire des logos. Utile pour les tests ou si on change
 * un logo et qu'on ne veut pas attendre le redémarrage de l'instance EF.
 */
export function clearLogoCache(): void {
  logoCache.clear();
}

/**
 * Retourne le nombre d'entrées dans le cache (debug/monitoring).
 */
export function getLogoCacheSize(): number {
  return logoCache.size;
}
