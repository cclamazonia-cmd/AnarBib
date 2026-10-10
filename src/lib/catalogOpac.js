// src/lib/catalogOpac.js — E6, Catalogue public, lot 1 (10/10/2026)
//
// Les aides PURES de la page du catalogue public (CatalogPage.jsx), sorties
// telles quelles, sans ressaisie : constantes de colonnes et de pagination,
// libellés de matière et de CDD, noms de bibliothèques d'une ligne, état de
// disponibilité d'une notice, exports CSV et impression, filtres mémorisés.
// Aucun état React : tout se teste sans monter la page
// (src/tests/catalog-opac-lot1-2.test.jsx).
import { coverUrl } from '@/lib/coverThumbs';
import { authorLabel } from '@/lib/authorLabel';

export const PAGE_SIZE = 100;
export const ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split(''); // #OPAC10 parcours A–Z
// #OPAC7 — divisions CDD avec libellé curé (sens anarchiste, cf. cotation-et-cdd.md).
// Les autres codes retombent sur la classe principale Dewey.
export function localizedSubjectLabel(li, locale) {
  if (!li || typeof li !== 'object') return '';
  return li[locale] || li[(locale || '').split('-')[0]] || li['pt-BR'] || Object.values(li)[0] || '';
}
export const CDD_DIV_LABELS = new Set([
  '070', '301', '303', '305', '320', '321', '322', '323', '324', '331',
  '333', '334', '335', '355', '365', '370', '909', '920', '944', '946',
  '972', '980', '981',
]);

// URLs des manuels (stockes sur Supabase Storage, bucket library-ui-assets).
// Le manuel lecteur est un PDF multilingue unique (8 langues en interne).
export const PUBLIC_COLS = [
  'book_id','bib_ref','titulo','subtitulo','autor','author_display',
  'author_id','author_chips',
  'editora','publisher_display','ano','cdd','tipo_material','idioma',
  'isbn','issn','assuntos','colecao','local_publicacao',
  'library_slug','library_name','biblioteca',
  'global_available_count','global_exemplares_total','available_count',
  'exemplares_total','loanable','bibliotecas_count',
  'has_online_reading','holding_library_names_json','cover_object_path',
  // work_id manquait ici depuis le lot C : le repli client ne regroupait jamais rien.
  'work_id',
].join(',');

export const SESSION_COLS = [
  'book_id','bib_ref','titulo','subtitulo','autor','author_display',
  'author_id','author_chips',
  'editora','publisher_display','ano','cdd','tipo_material','idioma',
  'isbn','issn','assuntos','colecao','local_publicacao',
  'library_slug','library_name','biblioteca',
  'global_available_count','global_exemplares_total',
  'exemplares_total','loanable','bibliotecas_count',
  'has_online_reading','holding_library_names_json',
  'session_library_id','session_library_slug','session_library_name',
  'session_exemplares_total','session_has_holding','session_status_hint',
  'session_available_count','session_loanable','cover_object_path',
  'work_id',
].join(',');

// Sort options, availability options, and status labels are built inside the component using t()
// See useMemo blocks inside CatalogPage

export const TIPO_ICONS = {
  livro:'📕', periodico:'📰', folheto:'📄', boletim:'📰',
  arquivo:'📂', zine:'✊', tract:'📜', cartaz:'🪧',
  audio:'🎧', audiovisual:'🎬', recurso_digital:'💻',
  dossie:'📁', outro:'📎',
};

// Miniatures de couverture : dérivés pré-générés servis en `object/public`.
// On n'appelle plus `render/image` — voir l'en-tête de src/lib/coverThumbs.js
// (imgproxy est exclu de la pile auto-hébergée, et la transformation est
// facturée à l'image d'origine distincte par mois).
//
// Repli : une capa déposée avant la reprise, ou dont le dérivé a échoué, n'a
// pas de vignette. Plutôt qu'une image cassée — ce que faisait cette grille,
// seul <img> du dépôt sans onError — on retombe sur l'original, puis on masque.
export function handleThumbError(e, path) {
  const img = e.currentTarget;
  if (img.dataset.abFallback) { img.style.display = 'none'; return; }
  img.dataset.abFallback = '1';
  img.src = coverUrl(path);
}

// ── Helpers ────────────────────────────────────────────────

export function parseLibraryNames(book) {
  try {
    const n = book.holding_library_names_json;
    if (!n) return book.biblioteca || book.library_name || '';
    if (typeof n === 'string') { const p = JSON.parse(n); return Array.isArray(p) ? p.join(', ') : typeof p === 'object' ? Object.values(p).join(', ') : String(n); }
    if (Array.isArray(n)) return n.join(', ');
    if (typeof n === 'object') return Object.values(n).join(', ');
    return String(n);
  } catch { return book.biblioteca || book.library_name || ''; }
}

// Nombre de bibliotheques nommees dans une ligne du catalogue. Au-dela, un
// compteur depliable : un ouvrage detenu par 25 biblios ferait sinon exploser la
// ligne (et la carte mobile, ou la cellule s'empile sous son libelle).
// Les exports (CSV, impression) restent complets : ils passent par
// parseLibraryNames() directement.
export const MAX_VISIBLE_LIBS = 3;

export function libraryNameList(book) {
  const raw = parseLibraryNames(book);
  return raw ? raw.split(', ').filter(Boolean) : [];
}

// L'ordre decide de l'utilite de la troncature : on remonte d'abord les biblios
// cochees dans le filtre, puis celle de la lectrice. Sans ca, un resultat filtre
// sur MLEG pourrait n'afficher que trois autres biblios, et la ligne sortirait
// sans que rien n'explique pourquoi.
export function orderLibraryNames(names, priority) {
  if (names.length <= MAX_VISIBLE_LIBS || !priority.size) return names;
  const first = [];
  const rest = [];
  for (const nm of names) (priority.has(nm.toLowerCase()) ? first : rest).push(nm);
  return [...first, ...rest];
}

export function getStatusInfo(book, isAuth, t) {
  // Doctrine A1/A2/A3 (tableau BLMF) : pour un anon, l'affichage reste public et
  // non personnalise. Ne PAS exposer la distinction pret/consultation (loanable)
  // a un visiteur non connecte.
  if (!isAuth) {
    return { label: t({ id: 'catalog.avail.check' }), cls: 'muted' };
  }
  const h = (book.session_status_hint || '').toLowerCase();
  if (!h || h === 'sem_biblioteca_de_sessao') {
    if (book.loanable === false) return { label: t({ id: 'catalog.avail.consult' }), cls: 'warn' };
    return { label: t({ id: 'catalog.avail.check' }), cls: 'muted' };
  }
  if (h === 'indisponivel_para_voce') return { label: t({ id: 'catalog.avail.unavailUser' }), cls: 'bad' };
  if (h === 'consultavel_no_local') return { label: t({ id: 'catalog.avail.consult' }), cls: 'warn' };
  if (h === 'no_acervo_da_sua_biblioteca') {
    const c = Number(book.session_available_count) || 0;
    if (c > 0) return { label: t({ id: 'catalog.avail.availableCount' }, { count: c }), cls: 'ok' };
    return { label: t({ id: 'catalog.avail.unavailNow' }), cls: 'bad' };
  }
  return { label: t({ id: 'catalog.avail.check' }), cls: 'muted' };
}

// buildServerFilters est désormais une fonction pure extraite dans
// src/lib/catalogFilters.js (recherche multi-mots + tests unitaires
// src/tests/catalogFilters.test.js).

export function sortLabel(v, opts) { return opts.find(o => o.value === v)?.label || ''; }

// ── Export helpers ──────────────────────────────────────────

export function exportCSV(books) {
  const header = ['ref','autor','titulo','ano','editora','biblioteca'];
  const rows = books.map(b => [b.bib_ref||'', (b.author_display||b.autor||'').replace(/"/g,'""'), (b.titulo||'').replace(/"/g,'""'), b.ano||'', ((b.publisher_display||b.editora)||'').replace(/"/g,'""'), parseLibraryNames(b).replace(/"/g,'""')]);
  const csv = [header.join(','), ...rows.map(r => r.map(c => `"${c}"`).join(','))].join('\n');
  const blob = new Blob(['\uFEFF'+csv], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a'); a.href = url; a.download = 'anarbib-catalogo.csv'; a.click();
  URL.revokeObjectURL(url);
}

export function exportPDF(books, t) {
  const now = new Date().toLocaleDateString('pt-BR');
  const rows = books.map(b =>
    `<tr><td>${b.bib_ref||'—'}</td><td>${authorLabel(b, t)||'—'}</td><td>${b.titulo||'—'}${b.subtitulo?` — ${b.subtitulo}`:''}</td><td>${b.ano||'—'}</td><td>${b.publisher_display||b.editora||'—'}</td><td>${parseLibraryNames(b)||'—'}</td></tr>`
  ).join('');
  const html = `<!DOCTYPE html><html><head><meta charset="utf-8"><title>AnarBib — ${t({id:'catalog.title'})} — ${now}</title>
<style>
  body{font-family:Georgia,serif;margin:24px;color:#111;font-size:11px;}
  h1{font-size:18px;margin:0 0 4px;}h2{font-size:12px;font-weight:normal;color:#555;margin:0 0 16px;}
  table{width:100%;border-collapse:collapse;margin-top:8px;}
  th{text-align:left;font-size:10px;text-transform:uppercase;letter-spacing:.5px;border-bottom:2px solid #111;padding:4px 6px;color:#333;}
  td{padding:4px 6px;border-bottom:1px solid #ddd;font-size:10.5px;vertical-align:top;}
  tr:nth-child(even){background:#f7f7f7;}
  .footer{margin-top:16px;font-size:9px;color:#888;text-align:center;border-top:1px solid #ccc;padding-top:8px;}
  @media print{body{margin:12px;}@page{size:A4 landscape;margin:10mm;}}
</style></head><body>
<h1>AnarBib — ${t({id:'catalog.title'})}</h1>
<h2>${books.length} ${t({id:'catalog.results.count'},{count:books.length})} — ${now}</h2>
<table><thead><tr><th>${t({id:'catalog.table.ref'})}</th><th>${t({id:'catalog.table.author'})}</th><th>${t({id:'catalog.table.bookTitle'})}</th><th>${t({id:'catalog.table.year'})}</th><th>${t({id:'catalog.table.publisher'})}</th><th>${t({id:'catalog.table.libraries'})}</th></tr></thead><tbody>${rows}</tbody></table>
<div class="footer">AnarBib — ${t({id:'app.subtitle'})} — ${now}</div>
<script>window.onload=()=>window.print();</${'script'}>
</body></html>`;
  const w = window.open('', '_blank');
  if (w) { w.document.write(html); w.document.close(); }
}

// ── Persistance des filtres ─────────────────────────────────

export const FILTER_STORAGE_KEY = 'anarbib:catalog:filters';

export function loadSavedFilters() {
  try {
    const raw = localStorage.getItem(FILTER_STORAGE_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch { return null; }
}

// E17 : écran étroit = le seuil du filet mobile (src/styles/mobile.css, 640 px). Lu une fois, à
// la naissance de la page ou au moment d'un geste — jamais écouté : tourner son téléphone ne doit
// pas replier un bloc qu'on vient d'ouvrir.
export function ecranEtroit() {
  return typeof window !== 'undefined' && typeof window.matchMedia === 'function'
    && window.matchMedia('(max-width: 640px)').matches;
}

export function saveFilters(filters) {
  try { localStorage.setItem(FILTER_STORAGE_KEY, JSON.stringify(filters)); } catch {}
}
