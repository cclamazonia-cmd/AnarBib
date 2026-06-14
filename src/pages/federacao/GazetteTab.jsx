import { useState, useEffect, useRef, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { apiQuery } from '@/lib/supabase';

// ═══════════════════════════════════════════════════════════════════════════
// GazetteTab — onglet « Gazette » de la page Fédération.
//
// Porte la maquette de référence anarbib-gazette.html (CSS + emblème SVG +
// renderBlock/render) telle quelle, mais remplace la source statique GAZETTE
// par un fetch des vues publiques api.gazette_*_public_v1 (lecture anon, RLS).
//
// Isolation : le document journal est monté dans une <iframe srcdoc> sandboxée
// (allow-same-origin allow-modals, SANS allow-scripts). Conséquences :
//   • isolation CSS totale — le design system du SIGB est intouchable, et la
//     maquette (html,body{}, p{}, *{}) reste reprise verbatim sans collision ;
//   • PDF = iframe.contentWindow.print() → la mise en page @media print A4 de la
//     maquette s'applique au seul document journal (1 page gazette = 1 A4) ;
//   • aucun <script> injecté dans le contenu ne peut s'exécuter (pas de scripts).
// La sanitisation whitelist (S) reste appliquée en défense en profondeur.
// ═══════════════════════════════════════════════════════════════════════════

const GZ_LOCALES = ['pt-BR', 'fr', 'es', 'en', 'it', 'de', 'el', 'ca', 'eo', 'nl'];

const LOCALE_NAMES = {
  'pt-BR': 'Português (BR)', fr: 'Français', es: 'Español', en: 'English',
  it: 'Italiano', de: 'Deutsch', el: 'Ελληνικά', ca: 'Català', eo: 'Esperanto', nl: 'Nederlands',
};

// Chaînes UI propres à la gazette (libellés de rendu + bandeau de repli), traduites
// pour les 10 locales — reprises de la maquette. Indépendantes du contenu éditorial.
const UI = {
  'pt-BR': { lang: 'Idioma', pdf: 'Baixar PDF', page: 'Página', sources: 'Fontes',
    pending: 'Tradução da comunidade em andamento — exibindo o conteúdo em francês.' },
  fr: { lang: 'Langue', pdf: 'Télécharger le PDF', page: 'Page', sources: 'Sources',
    pending: '' },
  es: { lang: 'Idioma', pdf: 'Descargar PDF', page: 'Página', sources: 'Fuentes',
    pending: 'Traducción comunitaria en curso — mostrando el contenido en francés.' },
  en: { lang: 'Language', pdf: 'Download PDF', page: 'Page', sources: 'Sources',
    pending: 'Community translation in progress — showing the French content.' },
  it: { lang: 'Lingua', pdf: 'Scarica PDF', page: 'Pagina', sources: 'Fonti',
    pending: 'Traduzione della comunità in corso — viene mostrato il contenuto in francese.' },
  de: { lang: 'Sprache', pdf: 'PDF herunterladen', page: 'Seite', sources: 'Quellen',
    pending: 'Community-Übersetzung in Arbeit — angezeigt wird der französische Inhalt.' },
  el: { lang: 'Γλώσσα', pdf: 'Λήψη PDF', page: 'Σελίδα', sources: 'Πηγές',
    pending: 'Μετάφραση από την κοινότητα σε εξέλιξη — εμφανίζεται το γαλλικό περιεχόμενο.' },
  ca: { lang: 'Idioma', pdf: 'Baixa el PDF', page: 'Pàgina', sources: 'Fonts',
    pending: 'Traducció comunitària en curs — es mostra el contingut en francès.' },
  eo: { lang: 'Lingvo', pdf: 'Elŝuti PDF', page: 'Paĝo', sources: 'Fontoj',
    pending: 'Komunuma traduko daŭras — montrante la francan enhavon.' },
  nl: { lang: 'Taal', pdf: 'PDF downloaden', page: 'Pagina', sources: 'Bronnen',
    pending: 'Vertaling door de gemeenschap in uitvoering — de Franse inhoud wordt getoond.' },
};

// Emblème « Le Noyau » — SVG inline repris verbatim de la maquette.
const EMBLEM = `<svg class="emblem" viewBox="18 52 196 196" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
 <g transform="translate(20,52)">
  <circle cx="98" cy="98" r="80.36" fill="none" stroke="#cf1f27" stroke-width="16.66" stroke-dasharray="15.78 15.78"/>
  <circle cx="98" cy="98" r="63.7" fill="none" stroke="#cf1f27" stroke-width="1.5" opacity=".6"/>
  <g stroke="#a3161c">
   <line x1="58" y1="40" x2="80" y2="28" stroke-width="1.6" opacity=".7"/>
   <line x1="80" y1="28" x2="98" y2="24" stroke-width="1.6" opacity=".7"/>
   <line x1="98" y1="24" x2="116" y2="28" stroke-width="1.6" opacity=".7"/>
   <line x1="116" y1="28" x2="138" y2="40" stroke-width="1.6" opacity=".7"/>
   <line x1="98" y1="24" x2="98" y2="70" stroke-width="1.4" stroke-dasharray="2 4" opacity=".7"/>
  </g>
  <g fill="#cf1f27"><circle cx="58" cy="40" r="3"/><circle cx="80" cy="28" r="3"/><circle cx="98" cy="24" r="4.4"/><circle cx="116" cy="28" r="3"/><circle cx="138" cy="40" r="3"/></g>
  <g transform="translate(40,117.3) scale(0.9667)">
   <polygon points="60,9 8,17 8,42 60,34" fill="#17120f"/>
   <polygon points="60,9 112,17 112,42 60,34" fill="#17120f"/>
   <line x1="60" y1="9" x2="60" y2="34" stroke="#cf1f27" stroke-width="2.4"/>
   <g stroke="#f6f3ec" stroke-width="1.4" opacity=".85">
    <line x1="14" y1="20" x2="52" y2="16"/><line x1="14" y1="25" x2="52" y2="21"/><line x1="14" y1="30" x2="52" y2="26"/>
    <line x1="68" y1="16" x2="106" y2="20"/><line x1="68" y1="21" x2="106" y2="25"/><line x1="68" y1="26" x2="106" y2="30"/>
   </g>
  </g>
  <g transform="translate(55,54) scale(0.86)" stroke="#17120f" stroke-width="8" fill="none">
   <circle cx="50" cy="50" r="38"/>
   <path d="M29 75 L50 25 L71 75" stroke-linejoin="miter" stroke-linecap="square"/>
   <line x1="13" y1="60" x2="87" y2="60" stroke-linecap="square"/>
  </g>
 </g>
</svg>`;

// Feuille de style de la maquette, reprise verbatim. Vivra dans l'iframe : aucun
// risque de collision avec le SIGB. Les sélecteurs .controls/.pending de la
// maquette restent inertes ici (la barre de contrôle est rendue en React).
const GZ_CSS = `
  :root{
    --red:#cf1f27; --red-dark:#a3161c; --ink:#17120f; --paper:#f6f3ec;
    --paper-2:#efe9dc; --line:#d8d0bf; --muted:#6b6155;
    --serif:"Iowan Old Style","Palatino Linotype",Palatino,"Book Antiqua",Georgia,serif;
    --sans:"Helvetica Neue",Arial,"Segoe UI",system-ui,sans-serif;
    --cond:"Arial Narrow","Helvetica Neue",Arial,sans-serif;
  }
  *{box-sizing:border-box}
  html,body{margin:0;padding:0;background:var(--paper-2);color:var(--ink);
    font-family:var(--serif);-webkit-font-smoothing:antialiased}

  /* ---------- Pending-translation banner (inerte ici) ---------- */
  .pending{display:none}

  /* ---------- Page canvas ---------- */
  .sheet{max-width:920px;margin:1.4rem auto;padding:0 1rem}
  .page{background:var(--paper);border:1px solid var(--line);
    box-shadow:0 6px 26px rgba(23,18,15,.14);padding:30px 34px 26px;margin:0 0 1.6rem;
    position:relative}
  .page::after{content:attr(data-foot);position:absolute;left:34px;right:34px;bottom:10px;
    font-family:var(--sans);font-size:.62rem;letter-spacing:.12em;text-transform:uppercase;
    color:var(--muted);display:flex;justify-content:space-between;border-top:1px solid var(--line);
    padding-top:6px}

  /* ---------- Masthead (page 1) ---------- */
  .masthead{border-bottom:3px solid var(--ink);padding-bottom:14px;margin-bottom:6px}
  .masthead .topline{display:flex;justify-content:space-between;align-items:center;
    font-family:var(--sans);font-size:.66rem;letter-spacing:.18em;text-transform:uppercase;
    color:var(--ink);border-bottom:1px solid var(--ink);padding-bottom:6px;margin-bottom:14px}
  .masthead .topline .mid{color:var(--red);font-weight:700}
  .lockup{display:flex;align-items:center;gap:18px}
  .lockup .emblem{width:118px;height:118px;flex:0 0 auto}
  .wordmark{font-family:var(--cond);font-weight:900;font-size:4.6rem;line-height:.86;
    letter-spacing:-.02em;color:var(--ink);font-stretch:condensed}
  .wordmark b{color:var(--red)}
  .wordmark .tag{display:block;font-family:var(--sans);font-weight:600;font-size:.74rem;
    letter-spacing:.42em;text-transform:uppercase;color:var(--ink);margin-top:.5rem;
    border-top:1px solid var(--line);padding-top:.45rem}

  /* page kicker / section header */
  .kicker{display:flex;align-items:baseline;justify-content:space-between;
    border-bottom:2px solid var(--ink);padding-bottom:6px;margin:0 0 14px}
  .kicker .sec{font-family:var(--sans);font-weight:800;font-size:1.05rem;letter-spacing:.05em;
    text-transform:uppercase}
  .kicker .sec .n{color:var(--red);margin-right:.45rem}
  .kicker .pg{font-family:var(--sans);font-size:.66rem;letter-spacing:.16em;text-transform:uppercase;color:var(--muted)}

  h2.lead{font-family:var(--cond);font-weight:900;font-size:2.15rem;line-height:1.02;
    letter-spacing:-.01em;margin:.2rem 0 .5rem;font-stretch:condensed}
  .label{display:inline-block;font-family:var(--sans);font-weight:800;font-size:.64rem;
    letter-spacing:.16em;text-transform:uppercase;color:#fff;background:var(--red);
    padding:.18rem .5rem;border-radius:2px;margin-bottom:.5rem}
  .edito-h{font-family:var(--cond);font-weight:800;font-size:1.5rem;font-stretch:condensed;margin:.1rem 0 .1rem}
  .byline{font-family:var(--sans);font-size:.68rem;letter-spacing:.1em;text-transform:uppercase;
    color:var(--red-dark);font-weight:700;margin-bottom:.5rem}
  h3.art{font-family:var(--cond);font-weight:800;font-size:1.28rem;line-height:1.06;
    font-stretch:condensed;margin:1.05rem 0 .3rem}
  h3.art:first-child{margin-top:0}
  p{font-size:.94rem;line-height:1.5;margin:.42rem 0;text-align:justify;hyphens:auto}
  .dropcap::first-letter{font-family:var(--cond);font-weight:900;float:left;font-size:3.1rem;
    line-height:.8;padding:.05em .12em 0 0;color:var(--red)}
  .src{font-family:var(--sans);font-size:.66rem;font-style:normal;color:var(--muted);
    letter-spacing:.02em;margin:.25rem 0 .2rem}
  .src b{color:var(--ink)}
  .tbc{color:var(--muted);font-style:italic;font-size:.8rem}

  /* columns */
  .cols{column-count:2;column-gap:26px;column-rule:1px solid var(--line)}
  .cols > *{break-inside:avoid}
  @media(max-width:640px){.cols{column-count:1}.wordmark{font-size:3.2rem}.lockup .emblem{width:84px;height:84px}}

  /* TOC */
  .toc{border:1px solid var(--ink);padding:12px 14px;margin:.4rem 0 0;background:var(--paper-2)}
  .toc h4{font-family:var(--sans);font-weight:800;font-size:.72rem;letter-spacing:.14em;
    text-transform:uppercase;margin:0 0 .5rem;color:var(--red)}
  .toc ul{list-style:none;margin:0;padding:0}
  .toc li{font-family:var(--sans);font-size:.8rem;padding:.22rem 0;border-bottom:1px dotted var(--line);display:flex;gap:.5rem}
  .toc li:last-child{border-bottom:0}
  .toc li b{color:var(--red-dark);min-width:2.4em}

  /* callout / note box */
  .callout{border:2px solid var(--red);background:#fbeceb;padding:11px 13px;margin:.7rem 0 0}
  .callout h3{font-family:var(--cond);font-weight:800;font-size:1.15rem;margin:0 0 .25rem;color:var(--red-dark);font-stretch:condensed}
  .callout p{margin:.2rem 0}

  /* agenda */
  ul.agenda{list-style:none;margin:.3rem 0 0;padding:0}
  ul.agenda li{padding:.4rem 0;border-bottom:1px solid var(--line);font-size:.9rem;line-height:1.4}
  ul.agenda li .d{font-family:var(--sans);font-weight:800;font-size:.74rem;letter-spacing:.04em;
    text-transform:uppercase;color:var(--red-dark);display:block}
  ul.support{list-style:none;margin:.3rem 0 0;padding:0}
  ul.support li{padding:.32rem 0 .32rem 1rem;position:relative;font-size:.9rem;line-height:1.4}
  ul.support li::before{content:"▸";position:absolute;left:0;color:var(--red)}
  ul.support li b{font-family:var(--sans);font-size:.78rem;letter-spacing:.02em}

  .colophon{border-top:3px double var(--ink);margin-top:1rem;padding-top:.7rem;
    font-family:var(--sans);font-size:.74rem;line-height:1.5;color:#3a322c}
  .colophon b{color:var(--ink)}

  /* ---------- Print ---------- */
  @media print{
    @page{size:A4 portrait;margin:13mm}
    html,body{background:#fff}
    .pending{display:none !important}
    .sheet{max-width:none;margin:0;padding:0}
    .page{box-shadow:none;border:0;margin:0;padding:0 0 0;break-after:page;page-break-after:always}
    .page:last-child{break-after:auto;page-break-after:auto}
    .page::after{position:fixed;left:0;right:0;bottom:4mm}
    .cols{column-gap:8mm}
    h2.lead{font-size:2rem}
  }
`;

// Sanitisation whitelist : tout échapper, puis ré-autoriser une poignée de balises
// inline simples SANS attribut (le contenu maîtrisé n'utilise que <b>). Toute balise
// avec attribut ou hors liste reste échappée. Appliquée à chaque champ de contenu.
function S(v) {
  const esc = String(v == null ? '' : v)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  return esc.replace(/&lt;(\/?)(b|i|em|strong)&gt;/gi, '<$1$2>');
}

function renderBlock(b, ui) {
  switch (b.type) {
    case 'edito':
      return `<div class="label">${S(b.label)}</div>
        <div class="edito-h">${S(b.h)}</div>
        <div class="byline">${S(b.byline)}</div>
        ${(b.p || []).map((tx, i) => `<p class="${i === 0 ? 'dropcap' : ''}">${S(tx)}</p>`).join('')}`;
    case 'toc':
      return `<div class="toc"><h4>${S(b.title)}</h4><ul>${
        (b.items || []).map((it) => `<li><b>${S(it[0])}</b><span>${S(it[1])}</span></li>`).join('')}</ul></div>`;
    case 'lead':
      return `<div class="label">${S(b.label)}</div>
        <h2 class="lead">${S(b.h)}</h2>
        ${(b.p || []).map((tx, i) => `<p class="${i === 0 ? 'dropcap' : ''}">${S(tx)}</p>`).join('')}
        ${b.src ? `<div class="src"><b>${S(ui.sources)} :</b> ${S(b.src)}</div>` : ''}`;
    case 'art':
      return `<h3 class="art">${S(b.h)}</h3>
        ${(b.p || []).map((tx) => `<p>${S(tx)}</p>`).join('')}
        ${b.tbc ? `<p class="tbc">— ${S(b.tbc)}</p>` : ''}
        ${b.src ? `<div class="src"><b>${S(ui.sources)} :</b> ${S(b.src)}</div>` : ''}`;
    case 'callout':
      return `<div class="callout"><h3>${S(b.h)}</h3>${(b.p || []).map((tx) => `<p>${S(tx)}</p>`).join('')}</div>`;
    case 'agenda':
      return `<h3 class="art">${S(b.h)}</h3><ul class="agenda">${
        (b.items || []).map((it) => `<li><span class="d">${S(it[0])}</span>${S(it[1])}</li>`).join('')}</ul>`;
    case 'support':
      return `<h3 class="art">${S(b.h)}</h3><ul class="support">${
        (b.items || []).map((it) => `<li><b>${S(it[0])}</b>${S(it[1])}</li>`).join('')}</ul>`;
    case 'colophon':
      return `<div class="colophon">${S(b.p)}</div>`;
    default:
      return '';
  }
}

// Construit le document HTML autonome (journal 6 pages) injecté dans l'iframe srcdoc.
function buildDocHTML(data, ui, locale) {
  const m = data.masthead || {};
  const pages = Array.isArray(data.content) ? data.content : [];
  const n = pages.length;
  const body = pages.map((pg, idx) => {
    let inner = '';
    if (idx === 0) {
      inner += `<div class="masthead">
        <div class="topline"><span>${S(m.left)}</span><span class="mid">${S(m.mid)}</span><span>${S(m.right)}</span></div>
        <div class="lockup">${EMBLEM}
          <div class="wordmark">Anar<b>Bib</b><span class="tag">${S(data.tagline)}</span></div>
        </div></div>`;
    }
    inner += `<div class="kicker"><div class="sec"><span class="n">${String(idx + 1).padStart(2, '0')}</span>${S(pg.sec)}</div>
      <div class="pg">${S(ui.page)} ${idx + 1} / ${n}</div></div>`;
    if (pg.intro) inner += `<p class="src" style="font-size:.78rem;font-style:italic;margin-bottom:.6rem">${S(pg.intro)}</p>`;
    inner += `<div class="cols">${(pg.blocks || []).map((b) => renderBlock(b, ui)).join('')}</div>`;
    const foot = `AnarBib · ${S(ui.page)} ${idx + 1}/${n} · ${S(m.mid)}`;
    return `<section class="page" data-foot="${foot}">${inner}</section>`;
  }).join('');
  return `<!DOCTYPE html><html lang="${S(locale)}"><head><meta charset="utf-8">`
    + `<meta name="viewport" content="width=device-width, initial-scale=1">`
    + `<style>${GZ_CSS}</style></head>`
    + `<body><div class="sheet">${body}</div></body></html>`;
}

export default function GazetteTab() {
  const { formatMessage: t, locale: appLocale } = useIntl();
  const [state, setState] = useState({ status: 'loading', number: null, byLocale: {} });
  // Locale de lecture : synchronisée sur la locale de l'app à l'ouverture de l'onglet.
  const [loc, setLoc] = useState(() => (GZ_LOCALES.includes(appLocale) ? appLocale : 'fr'));
  const frameRef = useRef(null);
  const [frameH, setFrameH] = useState(640);

  const fetchGazette = useCallback(async () => {
    setState((s) => ({ ...s, status: 'loading' }));
    const iss = await apiQuery('gazette_issues_public_v1', { select: 'number', order: 'number.desc' });
    if (iss.error) { setState({ status: 'error', number: null, byLocale: {} }); return; }
    const number = iss.data?.[0]?.number;
    if (number == null) { setState({ status: 'empty', number: null, byLocale: {} }); return; }
    const locs = await apiQuery('gazette_locales_public_v1', {
      select: 'locale,tagline,masthead,content,translation_status,pdf_object_path',
      filters: { issue_number: `eq.${number}` },
    });
    if (locs.error) { setState({ status: 'error', number: null, byLocale: {} }); return; }
    const byLocale = Object.fromEntries((locs.data || []).map((r) => [r.locale, r]));
    setState({ status: 'ready', number, byLocale });
  }, []);

  useEffect(() => { fetchGazette(); }, [fetchGazette]);

  // Hauteur de l'iframe = hauteur réelle du document journal (pas de scroll interne).
  const measure = useCallback(() => {
    const doc = frameRef.current?.contentDocument;
    if (doc) setFrameH(doc.documentElement.scrollHeight);
  }, []);
  useEffect(() => {
    window.addEventListener('resize', measure);
    return () => window.removeEventListener('resize', measure);
  }, [measure]);

  const printPdf = () => {
    const win = frameRef.current?.contentWindow;
    if (win) { win.focus(); win.print(); }
  };

  if (state.status === 'loading') {
    return <div className="ab-fed-placeholder"><p>{t({ id: 'common.loading' })}</p></div>;
  }
  if (state.status === 'error') {
    return (
      <div className="ab-fed-placeholder">
        <h3>{t({ id: 'federacao.tab.gazeta' })}</h3>
        <p>{t({ id: 'federacao.gazeta.error' })}</p>
        <button className="cat-btn ghost" onClick={fetchGazette} style={{ marginTop: 12 }}>
          {t({ id: 'federacao.gazeta.retry' })}
        </button>
      </div>
    );
  }
  if (state.status === 'empty') {
    return (
      <div className="ab-fed-placeholder">
        <h3>{t({ id: 'federacao.tab.gazeta' })}</h3>
        <p>{t({ id: 'federacao.gazeta.empty' })}</p>
      </div>
    );
  }

  const ui = UI[loc] || UI.fr;
  const hasLoc = !!state.byLocale[loc];
  const data = state.byLocale[loc] || state.byLocale.fr || null;

  if (!data) {
    return (
      <div className="ab-fed-placeholder">
        <h3>{t({ id: 'federacao.tab.gazeta' })}</h3>
        <p>{t({ id: 'federacao.gazeta.empty' })}</p>
      </div>
    );
  }

  return (
    <div className="ab-gz">
      <div className="ab-gz-bar">
        <label htmlFor="ab-gz-locale">{ui.lang}</label>
        <select id="ab-gz-locale" value={loc} onChange={(e) => setLoc(e.target.value)}>
          {GZ_LOCALES.map((l) => (
            <option key={l} value={l}>{LOCALE_NAMES[l]}{state.byLocale[l] ? '' : ' ·…'}</option>
          ))}
        </select>
        <span className="ab-gz-spacer" />
        <button type="button" className="cat-btn primary" onClick={printPdf}>{ui.pdf}</button>
      </div>

      {!hasLoc && ui.pending && <div className="ab-gz-pending">{ui.pending}</div>}

      <iframe
        ref={frameRef}
        className="ab-gz-frame"
        title={t({ id: 'federacao.tab.gazeta' })}
        sandbox="allow-same-origin allow-modals"
        srcDoc={buildDocHTML(data, ui, loc)}
        onLoad={measure}
        style={{ height: frameH }}
      />
    </div>
  );
}
