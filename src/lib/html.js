// AnarBib — petites protections pour le HTML écrit à la main (17-19/10/2026).
//
// Trois besoins, une seule source :
//   - echapperHtml : une valeur venue de la base (titre, auteur, éditeur…)
//     insérée dans une chaîne HTML que React ne protège pas (document.write,
//     popups Leaflet, gabarits d'impression) ;
//   - urlWebSure / normaliserUrlWeb : un lien externe n'est rendu ou accepté
//     que s'il est http(s) — jamais javascript:, data:, vbscript:… ;
//   - assainirNoteHtml : le HTML d'une note d'EPUB ne garde que la mise en
//     forme du texte (liste blanche de balises, aucun attribut d'événement ni
//     de style, liens http(s) seulement) avant d'entrer dans la page.

const ENTITES = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };

export function echapperHtml(valeur) {
  return String(valeur ?? '').replace(/[&<>"']/g, (c) => ENTITES[c]);
}

const URL_WEB = /^https?:\/\/[^\s<>"'`]+$/i;
const DOMAINE_NU = /^(?:www\.)?[a-z0-9][a-z0-9.-]*\.[a-z]{2,}(?:[/?#][^\s<>"'`]*)?$/i;

// L'adresse si elle est http(s) et sans caractère suspect, sinon null.
export function urlWebSure(valeur) {
  const v = String(valeur ?? '').trim();
  return URL_WEB.test(v) ? v : null;
}

// Pour une saisie : « exemple.org » devient « https://exemple.org » ;
// vide → { ok: true, url: null } ; tout autre schéma → { ok: false }.
export function normaliserUrlWeb(valeur) {
  const v = String(valeur ?? '').trim();
  if (!v) return { ok: true, url: null };
  if (URL_WEB.test(v)) return { ok: true, url: v };
  if (DOMAINE_NU.test(v)) return { ok: true, url: `https://${v}` };
  return { ok: false, url: null };
}

// ── Notes d'EPUB ────────────────────────────────────────────────────────
// Balises gardées telles quelles (mise en forme du texte).
const BALISES = new Set([
  'p', 'br', 'em', 'strong', 'i', 'b', 'u', 's', 'sup', 'sub', 'small', 'span',
  'cite', 'q', 'abbr', 'code', 'del', 'ins', 'blockquote', 'ul', 'ol', 'li',
  'dl', 'dt', 'dd', 'hr', 'a',
]);
// Conteneurs ramenés à un <div> (la structure se lit, la sémantique EPUB n'importe pas).
const CONTENEURS = new Set(['div', 'aside', 'section', 'article', 'header', 'footer', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6']);
// Retirés avec tout leur contenu.
const INTERDITS = new Set([
  'script', 'style', 'iframe', 'frame', 'frameset', 'object', 'embed', 'applet', 'svg', 'math',
  'template', 'noscript', 'form', 'input', 'button', 'select', 'textarea', 'option', 'link',
  'meta', 'base', 'img', 'picture', 'source', 'video', 'audio', 'track', 'canvas', 'title', 'head',
]);
const ATTRIBUTS_TEXTE = ['lang', 'dir', 'title'];

function copier(source, cible, doc) {
  for (const n of Array.from(source.childNodes)) {
    if (n.nodeType === 3) { cible.appendChild(doc.createTextNode(n.nodeValue)); continue; }
    if (n.nodeType !== 1) continue;                       // commentaires, PI… : retirés
    const nom = (n.localName || n.nodeName || '').toLowerCase();
    if (INTERDITS.has(nom)) continue;
    if (!BALISES.has(nom) && !CONTENEURS.has(nom)) { copier(n, cible, doc); continue; } // balise inconnue : son texte seul
    const el = doc.createElement(CONTENEURS.has(nom) ? 'div' : nom);
    for (const a of ATTRIBUTS_TEXTE) {
      const v = n.getAttribute && n.getAttribute(a);
      if (v) el.setAttribute(a, v);
    }
    if (nom === 'a') {
      const href = urlWebSure(n.getAttribute && n.getAttribute('href'));
      if (!href) { copier(n, cible, doc); continue; }   // lien interne ou douteux : le texte seul
      el.setAttribute('href', href);
      el.setAttribute('target', '_blank');
      el.setAttribute('rel', 'noopener noreferrer');
    }
    copier(n, el, doc);
    cible.appendChild(el);
  }
}

export function assainirNoteHtml(html) {
  const brut = String(html ?? '');
  if (!brut.trim() || typeof DOMParser === 'undefined' || typeof document === 'undefined') return '';
  // Document INERTE : ni script exécuté, ni ressource chargée.
  const lu = new DOMParser().parseFromString(`<!DOCTYPE html><html><body>${brut}</body></html>`, 'text/html');
  const doc = document.implementation.createHTMLDocument('');
  const boite = doc.createElement('div');
  copier(lu.body, boite, doc);
  return boite.innerHTML;
}
