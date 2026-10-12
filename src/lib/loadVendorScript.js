// =============================================================================
// loadVendorScript.js — charge un script vendorisé (public/vendor/…) à la demande
// =============================================================================
// Remplace les trois copies de `loadScript` des pages de carte (12/10/2026).
// Leur défaut commun : une balise <script> restée dans la page après un échec
// (502 de Codeberg Pages, coupure réseau) faisait croire au script suivant que la
// bibliothèque était chargée — `loadScript` répondait « déjà là » sans qu'elle
// existe, et la carte restait en erreur jusqu'à un rechargement complet. Codeberg
// Pages a affiché 94,8 % de disponibilité sur 24 h le 12/10 : l'échec n'est pas rare.
//
// Ici :
//   • la bibliothèque est cherchée par son nom global (`window.L`, `window.protomapsL`),
//     pas par la présence d'une balise ;
//   • une balise en cours de chargement est attendue, pas ignorée ;
//   • une balise en échec est RETIRÉE, et le chargement est retenté (3 essais,
//     1 puis 2 s d'attente) avant d'abandonner.
// =============================================================================

const ESSAIS = 3;
const attendre = (ms) => new Promise((r) => setTimeout(r, ms));

function balise(src) {
  return [...document.scripts].find((s) => s.getAttribute('src') === src || s.src.endsWith(src));
}

function unEssai(src) {
  return new Promise((resolve, reject) => {
    let s = balise(src);
    if (!s) {
      s = document.createElement('script');
      s.src = src;
      s.async = true;
      document.head.appendChild(s);
    }
    const fini = () => { s.removeEventListener('load', ok); s.removeEventListener('error', ko); };
    const ok = () => { fini(); s.dataset.charge = '1'; resolve(); };
    const ko = () => { fini(); s.remove(); reject(new Error(`échec du chargement de ${src}`)); };
    if (s.dataset.charge === '1') { resolve(); return; }
    s.addEventListener('load', ok);
    s.addEventListener('error', ko);
  });
}

/**
 * @param {string} src        chemin du script (ex. '/vendor/leaflet/leaflet.js')
 * @param {string} globalName nom global que le script définit (ex. 'L')
 * @returns {Promise<any>}    la bibliothèque (`window[globalName]`)
 */
export async function loadVendorScript(src, globalName) {
  if (globalName && window[globalName]) return window[globalName];
  let derniere;
  for (let essai = 1; essai <= ESSAIS; essai++) {
    try {
      await unEssai(src);
      if (!globalName || window[globalName]) return globalName ? window[globalName] : undefined;
      // Script chargé mais nom global absent : contenu inattendu (page d'erreur servie
      // en 200, par exemple). On retire la balise et on retente comme pour un échec.
      balise(src)?.remove();
      derniere = new Error(`${src} chargé sans définir window.${globalName}`);
    } catch (e) {
      derniere = e;
    }
    if (essai < ESSAIS) await attendre(1000 * essai);
  }
  throw derniere;
}

/** Ajoute une feuille de style une seule fois (une feuille manquante ne bloque rien). */
export function loadVendorCss(href) {
  if ([...document.querySelectorAll('link[rel="stylesheet"]')].some((l) => l.getAttribute('href') === href || l.href.endsWith(href))) return;
  const l = document.createElement('link');
  l.rel = 'stylesheet';
  l.href = href;
  document.head.appendChild(l);
}
