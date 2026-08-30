#!/usr/bin/env node
/**
 * build-backlog.cjs — engendre les livrables du backlog depuis une source unique.
 *
 * Source   : docs/backlogs/backlog-v34.json
 * Produits : docs/backlogs/AnarBib-Backlog-2026-08-29-v34.md      (français)
 *            docs/backlogs/AnarBib-Backlog-2026-08-29-v34.pt-BR.md (portugais)
 *            docs/backlogs/backlog-v34.html                        (page consultable, filtrable)
 *
 * Ne modifiez JAMAIS les .md à la main : ils sont écrasés à chaque exécution.
 * Modifiez le JSON, relancez ce script, commitez les fichiers ensemble.
 *
 * Usage : node scripts/build-backlog.cjs [chemin/vers/backlog-v34.json]
 */

const fs = require('fs');
const path = require('path');

const SRC = process.argv[2] || path.join(__dirname, '..', 'docs', 'backlogs', 'backlog-v34.json');
const OUTDIR = path.dirname(SRC);
const D = JSON.parse(fs.readFileSync(SRC, 'utf8'));

const LANGS = [
  { k: 'fr', file: 'AnarBib-Backlog-2026-08-29-v34.md' },
  { k: 'pt', file: 'AnarBib-Backlog-2026-08-29-v34.pt-BR.md' },
];

// ---------------------------------------------------------------- vocabulaire
const T = {
  fr: {
    toc: 'Sommaire', intro: 'Pourquoi une réécriture', howto: "Mode d'emploi",
    photo: "L'état réel au 29 août 2026", ecarts: 'Écarts relevés entre le réel et l\'écrit',
    calendrier: 'Le calendrier contraint', regles: 'Dix règles payées par un incident',
    chantiers: 'Les chantiers', clotures: 'Clôtures et entrées caduques',
    nonouvert: "Ce qui n'est pas au backlog", maintenance: 'Maintenance de ce document',
    etat: 'État', quoi: "Ce que c'est", pourquoi: 'Pourquoi ça compte',
    verif_non: 'Constat du 29/08, non revérifié depuis',
    verif_oui: 'Vérifié',
    fini: 'Ce qui compte comme fini', demande: 'Ce que ça demande', dep: 'Dépendances',
    refs: 'Renvois', prio: 'Priorité', statut: 'État', charge: 'Charge',
    dit: 'Ce que dit la documentation', reel: 'Ce que dit la base ou le dépôt',
    total: 'items', colophon: 'Colophon',
    lang_other: 'Versão em português : `AnarBib-Backlog-2026-08-29-v34.pt-BR.md`',
  },
  pt: {
    toc: 'Sumário', intro: 'Por que uma reescrita', howto: 'Modo de usar',
    photo: 'O estado real em 29 de agosto de 2026', ecarts: 'Desvios levantados entre o real e o escrito',
    calendrier: 'O calendário restrito', regles: 'Dez regras pagas por um incidente',
    chantiers: 'Os canteiros', clotures: 'Encerramentos e entradas caducas',
    nonouvert: 'O que não está no backlog', maintenance: 'Manutenção deste documento',
    etat: 'Estado', quoi: 'O que é', pourquoi: 'Por que importa',
    verif_non: 'Constato de 29/08, não reverificado desde então',
    verif_oui: 'Verificado',
    fini: 'O que conta como terminado', demande: 'O que exige', dep: 'Dependências',
    refs: 'Remissões', prio: 'Prioridade', statut: 'Estado', charge: 'Carga',
    dit: 'O que diz a documentação', reel: 'O que diz o banco ou o repositório',
    total: 'itens', colophon: 'Colofão',
    lang_other: 'Version française : `AnarBib-Backlog-2026-08-29-v34.md`',
  },
};

const L = (o, k) => (o && typeof o === 'object' && !Array.isArray(o) ? (o[k] ?? o.fr ?? '') : o);
const lab = (list, key, k) => { const e = list.find((x) => x.key === key); return e ? L(e.label, k) : key; };
// Reproduit l'ancre engendrée par Forgejo et GitHub : minuscules, ponctuation
// retirée (accents conservés), espaces en tirets, sans collapse des tirets.
const slug = (s) => s.toLowerCase().replace(/[^\p{L}\p{N} _-]/gu, '').replace(/ /g, '-');

const items = D.items;
const byDomain = (dk) => items.filter((i) => i.d === dk);

// ---------------------------------------------------------------- markdown
function markdown(k) {
  const t = T[k];
  const out = [];
  const p = (s = '') => out.push(s);

  p(`# ${L(D.meta.title, k)} — ${L(D.meta.subtitle, k)}`);
  p();
  p(`**${D.meta.date}**${D.meta.maj ? (k === 'fr' ? ` · mis à jour le **${D.meta.maj}**` : ` · atualizado em **${D.meta.maj}**`) : ''} · ${items.length} ${t.total} · ${t.lang_other}`);
  p();
  p(`> ${k === 'fr'
    ? "Fichier **engendré** par `scripts/build-backlog.cjs` depuis `backlog-v34.json`. Ne le modifiez pas à la main."
    : 'Arquivo **gerado** por `scripts/build-backlog.cjs` a partir de `backlog-v34.json`. Não o modifique à mão.'}`);
  p();
  p('---');
  p();

  // sommaire
  p(`## ${t.toc}`);
  p();
  const secs = [t.intro, t.howto, t.photo, t.ecarts, t.calendrier, t.regles];
  secs.forEach((s) => p(`- [${s}](#${slug(s)})`));
  p(`- [${t.chantiers}](#${slug(t.chantiers)})`);
  D.domains.forEach((d) => {
    const n = byDomain(d.key).length;
    // L'ancre se calcule sur le TITRE REEL, pas sur une recomposition : le
    // titre porte un tiret cadratin (« B — Base de donnees »), que slug()
    // retire en laissant les deux espaces qui l'entouraient -- donc un DOUBLE
    // tiret dans l'ancre. La recomposition `key + '-' + label` n'en produisait
    // qu'un seul, et les onze liens de domaine du sommaire ne pointaient nulle
    // part. Corrige le 29/08/2026 : une ancre se derive de son titre.
    const titreDom = `${d.key} — ${L(d.label, k)}`;
    p(`    - [${titreDom}](#${slug(titreDom)}) · ${n}`);
  });
  [t.clotures, t.nonouvert, t.maintenance].forEach((s) => p(`- [${s}](#${slug(s)})`));
  p();
  p('---');
  p();

  // sections narratives
  p(`## ${t.intro}`); p(); p(L(D.sections.intro, k)); p(); p('---'); p();
  p(`## ${t.howto}`); p(); p(L(D.sections.howto, k)); p(); p('---'); p();

  // photo
  p(`## ${t.photo}`); p(); p(L(D.etat.photo_intro, k)); p();
  D.etat.photo.forEach((g) => {
    p(`### ${L(g.g, k)}`); p();
    p('| | | |'); p('|---|---:|---|');
    g.rows.forEach((r) => p(`| ${L(r[0], k)} | **${r[1]}** | ${L(r[2], k)} |`));
    p();
  });
  p('---'); p();

  // écarts
  p(`## ${t.ecarts}`); p(); p(L(D.etat.ecarts_intro, k)); p();
  Object.keys(D.etat.sens_labels).forEach((sens) => {
    const rows = D.etat.ecarts.filter((e) => e.sens === sens);
    if (!rows.length) return;
    p(`### ${L(D.etat.sens_labels[sens], k)}`); p();
    rows.forEach((e) => {
      p(`**${L(e.quoi, k)}**`); p();
      p(`- *${t.dit}* — ${L(e.dit, k)}`);
      p(`- *${t.reel}* — ${L(e.reel, k)}`);
      p();
    });
  });
  p('---'); p();

  p(`## ${t.calendrier}`); p(); p(L(D.sections.calendrier, k)); p(); p('---'); p();
  p(`## ${t.regles}`); p(); p(L(D.sections.regles, k)); p(); p('---'); p();

  // chantiers
  p(`## ${t.chantiers}`); p();
  p(k === 'fr'
    ? `**Identifiant** = lettre de domaine + numéro. Les numéros ne sont jamais réutilisés. **Priorité** : ${D.priorities.map((x) => `\`${x.key}\` ${L(x.label, k)}`).join(' · ')}.`
    : `**Identificador** = letra de domínio + número. Os números nunca são reutilizados. **Prioridade**: ${D.priorities.map((x) => `\`${x.key}\` ${L(x.label, k)}`).join(' · ')}.`);
  p();
  D.priorities.forEach((x) => p(`- \`${x.key}\` **${L(x.label, k)}** — ${L(x.desc, k)}`));
  p();

  D.domains.forEach((d) => {
    const list = byDomain(d.key);
    p(`### ${d.key} — ${L(d.label, k)}`); p();
    p(`*${L(d.note, k)}*`); p();
    p(`| | | | |`); p(`|---|---|---|---|`);
    list.forEach((i) => p(`| **${i.id}** | ${L(i.t, k)} | \`${i.p}\` | ${lab(D.states, i.s, k)} |`));
    p();
    list.forEach((i) => {
      p(`#### ${i.id} — ${L(i.t, k)}`); p();
      p(`\`${i.p}\` ${lab(D.priorities, i.p, k)} · ${t.statut} : **${lab(D.states, i.s, k)}** · ${t.charge} : ${lab(D.efforts, i.e, k)} · ${t.demande} : ${i.sk.map((s) => lab(D.skills, s, k)).join(', ')}`);
      p();
      p(`**${t.etat}.** ${L(i.v, k)}`); p();
      p(i.verif
        ? `*${t.verif_oui} : ${L(i.verif, k)}*`
        : `*${t.verif_non}.*`); p();
      p(`**${t.quoi}.** ${L(i.w, k)}`); p();
      p(`**${t.pourquoi}.** ${L(i.y, k)}`); p();
      p(`**${t.fini}.**`); p();
      (L(i.f, k) || []).forEach((f) => p(`- ${f}`));
      p();
      p(`**${t.dep}.** ${L(i.dep, k)}`); p();
      p(`*${t.refs} : ${i.r.map((r) => `\`${r}\``).join(' · ')}*`); p();
    });
    p('---'); p();
  });

  // clôtures
  p(`## ${t.clotures}`); p(); p(L(D.clotures.intro, k)); p();
  p('| | | |'); p('|---|---|---|');
  D.clotures.rows.forEach((r) => p(`| ${L(r[0], k)} | ${L(r[1], k)} | ${L(r[2], k)} |`));
  p(); p('---'); p();

  p(`## ${t.nonouvert}`); p(); p(L(D.sections.nonouvert, k)); p(); p('---'); p();
  p(`## ${t.maintenance}`); p(); p(L(D.sections.maintenance, k)); p(); p('---'); p();

  p(`## ${t.colophon}`); p();
  p(k === 'fr'
    ? `Backlog v34, écrit le ${D.meta.date}${D.meta.maj ? `, mis à jour le ${D.meta.maj}` : ''}. Remplace \`${D.meta.previous}\`. ${items.length} items sur ${D.domains.length} domaines. L'état de départ a été vérifié le ${D.meta.date} contre la base de production en lecture seule et contre le dépôt Codeberg au commit \`1d00ed2c\` ; les items retouchés depuis portent leur propre date dans leur texte. Ce document n'arbitre rien : le \`REGISTRE_decisions.md\` fait foi.`
    : `Backlog v34, escrito em ${D.meta.date}${D.meta.maj ? `, atualizado em ${D.meta.maj}` : ''}. Substitui \`${D.meta.previous}\`. ${items.length} itens em ${D.domains.length} domínios. O estado inicial foi verificado em ${D.meta.date} contra o banco de produção em somente-leitura e contra o repositório Codeberg no commit \`1d00ed2c\`; os itens retocados desde então trazem a própria data no seu texto. Este documento não arbitra nada: o \`REGISTRE_decisions.md\` faz fé.`);
  p();
  return out.join('\n');
}

// ---------------------------------------------------------------- html
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const md = (s) => esc(s)
  .replace(/`([^`]+)`/g, '<code>$1</code>')
  .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
  .replace(/\*([^*]+)\*/g, '<em>$1</em>');

function html() {
  const payload = {
    meta: D.meta, domains: D.domains, priorities: D.priorities, states: D.states,
    efforts: D.efforts, skills: D.skills, items: D.items, etat: D.etat,
    sections: D.sections, clotures: D.clotures, T,
  };
  return `<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Backlog AnarBib v34</title>
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Big+Shoulders+Display:wght@500;700&family=Bitter:ital,wght@0,400;0,600;0,700;1,400&display=swap">
<style>
/* Identite AnarBib : fond bordeaux sombre, Bitter en labeur, Big Shoulders
   en titraille (la police de la brochure manifeste), rouge AnarBib reserve
   aux signaux semantiques. Concu en sombre d'abord ; la variante claire
   garde le meme biais bordeaux plutot qu'un gris neutre. */
:root{
  color-scheme:light dark;
  /* clair */
  --bg:#f6f1ef; --panel:#fffdfc; --ink:#1a1012; --mut:#6d5b58; --line:#e3d6d2;
  --rule:#cbb8b3; --accent:#a81c1c; --accent-soft:#f5e7e6; --chip:#ece1de;
  --p0:#a81c1c; --p1:#9a6410; --p2:#4d6136; --p3:#6d5b58;
  --sp:clamp(16px,3vw,22px);
}
@media (prefers-color-scheme: dark){ :root:not([data-theme="light"]){
  --bg:#12090a; --panel:#1c1113; --ink:#ece2df; --mut:#a08e8a; --line:#33211f;
  --rule:#4a3230; --accent:#d95a4c; --accent-soft:#2c1414; --chip:#261719;
  --p0:#d95a4c; --p1:#cd9440; --p2:#8fa864; --p3:#a08e8a;
}}
:root[data-theme="dark"]{
  --bg:#12090a; --panel:#1c1113; --ink:#ece2df; --mut:#a08e8a; --line:#33211f;
  --rule:#4a3230; --accent:#d95a4c; --accent-soft:#2c1414; --chip:#261719;
  --p0:#d95a4c; --p1:#cd9440; --p2:#8fa864; --p3:#a08e8a;
}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);
  font:16px/1.62 Bitter,Georgia,"Times New Roman",serif;
  -webkit-text-size-adjust:100%}
img{max-width:100%}
[hidden]{display:none!important}
.wrap{max-width:1080px;margin:0 auto;padding:0 var(--sp) 96px}
header{padding:52px 0 20px;border-bottom:2px solid var(--rule);margin-bottom:0}
.eyebrow{font-family:"Big Shoulders Display",Impact,"Haettenschweiler",sans-serif;
  font-weight:700;font-size:14px;letter-spacing:.14em;text-transform:uppercase;
  color:var(--accent);margin:0 0 10px}
h1{font-family:"Big Shoulders Display",Impact,"Haettenschweiler",sans-serif;
  font-weight:700;font-size:clamp(38px,7vw,68px);line-height:.95;letter-spacing:.005em;
  text-transform:uppercase;margin:0 0 12px;text-wrap:balance}
.sub{color:var(--ink);font-size:clamp(16px,2.1vw,19px);margin:0;max-width:60ch}
.mta{margin:14px 0 0;font-size:13.5px;color:var(--mut);font-variant-numeric:tabular-nums}
.bar{position:sticky;top:0;z-index:20;background:var(--bg);
  border-bottom:1px solid var(--line);padding:11px 0;margin:0 0 8px;
  display:flex;flex-wrap:wrap;gap:7px;align-items:center}
button{font-family:"Big Shoulders Display",Impact,sans-serif;font-weight:500;
  font-size:15px;letter-spacing:.06em;text-transform:uppercase;
  background:transparent;color:var(--mut);border:1px solid var(--line);
  border-radius:2px;padding:4px 11px;cursor:pointer;line-height:1.4}
button:hover{color:var(--ink);border-color:var(--rule)}
button[aria-pressed="true"]{background:var(--ink);border-color:var(--ink);color:var(--bg)}
button:focus-visible,input:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
.sep{width:1px;height:20px;background:var(--line);margin:0 3px}
input[type=search]{font:inherit;font-size:13.5px;padding:5px 11px;border:1px solid var(--line);
  border-radius:2px;background:var(--panel);color:var(--ink);min-width:170px;flex:1 1 170px}
h2{font-family:"Big Shoulders Display",Impact,sans-serif;font-weight:700;
  font-size:clamp(26px,3.6vw,34px);letter-spacing:.02em;text-transform:uppercase;
  margin:52px 0 4px;padding-bottom:6px;border-bottom:2px solid var(--rule);text-wrap:balance}
h3{font-family:"Big Shoulders Display",Impact,sans-serif;font-weight:500;
  font-size:23px;letter-spacing:.05em;text-transform:uppercase;margin:34px 0 6px}
p{margin:0 0 14px;max-width:74ch}
.note{color:var(--mut);font-size:15px;font-style:italic;max-width:70ch}
.tbl{overflow-x:auto;margin:0 0 22px}
table{border-collapse:collapse;width:100%;font-size:14.5px}
td{text-align:left;padding:9px 12px 9px 0;border-bottom:1px solid var(--line);vertical-align:top}
.photo td:nth-child(1){width:32%}
.photo td:nth-child(2){text-align:right;white-space:nowrap;font-variant-numeric:tabular-nums;
  font-weight:700;color:var(--accent);padding-right:18px}
.photo td:nth-child(3){color:var(--mut)}
.clot td:nth-child(1){width:24%;font-weight:600}
.clot td:nth-child(2){width:30%;color:var(--mut)}
.card{background:var(--panel);border:1px solid var(--line);border-left:3px solid var(--p2);
  border-radius:2px;padding:18px 20px;margin:0 0 12px}
.card.P0{border-left-color:var(--p0)}.card.P1{border-left-color:var(--p1)}
.card.P2{border-left-color:var(--p2)}.card.P3{border-left-color:var(--p3)}
.card h4{margin:0 0 10px;font-size:18.5px;line-height:1.32;font-weight:600;text-wrap:balance}
.id{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:13px;font-weight:400;
  color:var(--accent);background:var(--accent-soft);padding:2px 7px;border-radius:2px;margin-right:9px}
.chips{display:flex;flex-wrap:wrap;gap:6px;margin:0 0 4px}
.chip{font-family:"Big Shoulders Display",Impact,sans-serif;font-weight:500;font-size:13px;
  letter-spacing:.07em;text-transform:uppercase;background:var(--chip);color:var(--mut);
  padding:2px 9px;border-radius:2px;line-height:1.5}
.chip.pr{color:var(--bg);background:var(--p2)}
.card.P0 .chip.pr{background:var(--p0)}.card.P1 .chip.pr{background:var(--p1)}
.card.P3 .chip.pr{background:var(--p3)}
.f{margin:14px 0 0}
.f dt{font-family:"Big Shoulders Display",Impact,sans-serif;font-weight:500;font-size:13.5px;
  letter-spacing:.1em;text-transform:uppercase;color:var(--mut);margin-top:14px}
.f dd{margin:2px 0 0;max-width:74ch}
.f dd p{margin:0 0 9px}
.f dd p:last-child{margin-bottom:0}
.f ul,.f ol{margin:4px 0 9px;padding-left:19px}
.f dd>ol:last-child,.f dd>ul:last-child{margin-bottom:0}
.f li{margin:4px 0;max-width:72ch}
pre{background:var(--chip);border-left:2px solid var(--line);padding:10px 13px;
  margin:9px 0;overflow-x:auto;max-width:74ch}
pre code{background:none;padding:0;font-size:.84em;line-height:1.5;
  white-space:pre;word-break:normal}
.refs{font-size:12.5px;color:var(--mut);margin-top:15px;font-style:italic;max-width:none}
.prov{font-size:12.5px;color:var(--mut);font-style:italic;margin:6px 0 0}
code{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.86em;
  background:var(--chip);padding:1px 5px;border-radius:2px;word-break:break-word}
.count{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;color:var(--mut);
  font-size:14px;font-weight:400;letter-spacing:0;text-transform:none}
.ecart{border-left:2px solid var(--line);padding-left:16px;margin:0 0 18px;max-width:80ch}
.ecart b{display:block;margin-bottom:5px;font-weight:600}
.ecart span{display:block;font-size:15px;color:var(--mut);margin-bottom:4px}
.empty{color:var(--mut);font-style:italic;padding:26px 0}
@media (max-width:640px){
  header{padding-top:34px}
  .card{padding:14px 15px}
  .photo td:nth-child(1),.clot td:nth-child(1),.clot td:nth-child(2){width:auto}
}
@media (prefers-reduced-motion:reduce){*{animation:none!important;transition:none!important}}
</style>
</head>
<body>
<div class="wrap">
<header>
  <p class="eyebrow" id="eyb"></p>
  <h1 id="ttl"></h1>
  <p class="sub" id="sub"></p>
  <p class="mta" id="mta"></p>
</header>
<div class="bar" id="bar"></div>
<main id="main"></main>
</div>
<script>
const D = ${JSON.stringify(payload)};
let K = 'fr';
const st = { dom:'all', prio:'all', q:'' };
const L=(o,k)=>o&&typeof o==='object'&&!Array.isArray(o)?(o[k]??o.fr??''):o;
const esc=s=>String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
// Rendu markdown minimal, cote client. Trois niveaux seulement :
// l'inline (code, gras, italique), les blocs separes par une ligne vide,
// et les listes. Ajout du 30/08/2026 : les blocs de code delimites par trois
// accents graves. Un item de backlog qui donne une requete a copier-coller
// est un item qu'on peut utiliser sans le retaper -- c'etait la raison d'etre
// de ce fichier.
const inl=s=>esc(s).replace(/\`([^\`]+)\`/g,'<code>$1</code>')
  .replace(/\\*\\*([^*]+)\\*\\*/g,'<strong>$1</strong>').replace(/\\*([^*]+)\\*/g,'<em>$1</em>');
const md=s=>{
  const parts=String(s==null?'':s).split(/\`\`\`/);
  let out='';
  parts.forEach((seg,idx)=>{
    if(idx%2===1){
      out+='<pre><code>'+esc(seg.replace(/^[a-z]*\\n/,'').replace(/\\n$/,''))+'</code></pre>';
      return;
    }
    seg.split(/\\n{2,}/).forEach(blk=>{
      const b=blk.trim();
      if(!b) return;
      const li=b.split(/\\n/);
      if(li.every(l=>/^\\d+\\.\\s/.test(l)))
        out+='<ol>'+li.map(l=>'<li>'+inl(l.replace(/^\\d+\\.\\s/,''))+'</li>').join('')+'</ol>';
      else if(li.every(l=>/^[-*]\\s/.test(l)))
        out+='<ul>'+li.map(l=>'<li>'+inl(l.replace(/^[-*]\\s/,''))+'</li>').join('')+'</ul>';
      else
        out+='<p>'+inl(b).replace(/\\n/g,'<br>')+'</p>';
    });
  });
  return out;
};
const lab=(l,key)=>{const e=D[l].find(x=>x.key===key);return e?L(e.label,K):key;};

function bar(){
  const t=D.T[K];
  let h='';
  ['fr','pt'].forEach(l=>{h+='<button type="button" data-k="'+l+'" aria-pressed="'+(K===l)+'">'+l.toUpperCase()+'</button>';});
  h+='<span class="sep"></span>';
  h+='<button type="button" data-d="all" aria-pressed="'+(st.dom==='all')+'">'+(K==='fr'?'Tous':'Todos')+'</button>';
  D.domains.forEach(d=>{h+='<button type="button" data-d="'+d.key+'" aria-pressed="'+(st.dom===d.key)+'" title="'+esc(L(d.label,K))+'">'+d.key+'</button>';});
  h+='<span class="sep"></span>';
  h+='<button type="button" data-p="all" aria-pressed="'+(st.prio==='all')+'">'+(K==='fr'?'Toutes':'Todas')+'</button>';
  D.priorities.forEach(p=>{h+='<button type="button" data-p="'+p.key+'" aria-pressed="'+(st.prio===p.key)+'" title="'+esc(L(p.label,K))+'">'+p.key+'</button>';});
  h+='<input type="search" id="q" aria-label="'+(K==='fr'?'Chercher dans les items':'Buscar nos itens')+'" placeholder="'+(K==='fr'?'chercher…':'buscar…')+'" value="'+esc(st.q)+'">';
  document.getElementById('bar').innerHTML=h;
}

// Delegation posee une seule fois : la barre est reconstruite a chaque rendu,
// des gestionnaires attaches par bouton se perdraient au premier clic.
document.getElementById('bar').addEventListener('click',ev=>{
  const b=ev.target.closest('button'); if(!b)return;
  if(b.dataset.k){ if(b.dataset.k===K)return; K=b.dataset.k; }
  else if(b.dataset.d!==undefined){ st.dom=b.dataset.d; }
  else if(b.dataset.p!==undefined){ st.prio=b.dataset.p; }
  else return;
  render();
});
document.getElementById('bar').addEventListener('input',ev=>{
  if(ev.target.id!=='q')return;
  st.q=ev.target.value; render();
  const e=document.getElementById('q');
  if(e){e.focus();e.setSelectionRange(e.value.length,e.value.length);}
});

function match(i){
  if(st.dom!=='all'&&i.d!==st.dom)return false;
  if(st.prio!=='all'&&i.p!==st.prio)return false;
  if(st.q){const s=(i.id+' '+L(i.t,K)+' '+L(i.w,K)+' '+L(i.v,K)+' '+L(i.y,K)+' '+i.r.join(' ')).toLowerCase();
    if(!s.includes(st.q.toLowerCase()))return false;}
  return true;
}

function card(i){
  const t=D.T[K];
  let h='<article class="card '+i.p+'"><h4><span class="id">'+i.id+'</span>'+md(L(i.t,K))+'</h4>';
  h+='<div class="chips"><span class="chip pr">'+i.p+' · '+lab('priorities',i.p)+'</span>';
  h+='<span class="chip">'+lab('states',i.s)+'</span>';
  h+='<span class="chip">'+lab('efforts',i.e)+'</span>';
  i.sk.forEach(s=>{h+='<span class="chip">'+lab('skills',s)+'</span>';});
  h+='</div><dl class="f">';
  h+='<dt>'+t.etat+'</dt><dd>'+md(L(i.v,K))
    +'<p class="prov">'+(i.verif ? esc(t.verif_oui+' : ')+md(L(i.verif,K)) : esc(t.verif_non+'.'))+'</p>'+'</dd>';
  h+='<dt>'+t.quoi+'</dt><dd>'+md(L(i.w,K))+'</dd>';
  h+='<dt>'+t.pourquoi+'</dt><dd>'+md(L(i.y,K))+'</dd>';
  h+='<dt>'+t.fini+'</dt><dd><ul>'+(L(i.f,K)||[]).map(f=>'<li>'+md(f)+'</li>').join('')+'</ul></dd>';
  h+='<dt>'+t.dep+'</dt><dd>'+md(L(i.dep,K))+'</dd>';
  h+='</dl><p class="refs">'+t.refs+' : '+i.r.map(r=>'<code>'+esc(r)+'</code>').join(' · ')+'</p></article>';
  return h;
}

function render(){
  const t=D.T[K];
  document.documentElement.lang = K==='fr' ? 'fr' : 'pt-BR';
  document.getElementById('eyb').textContent = K==='fr'
    ? 'AnarBib · backlog v34' + (D.meta.maj ? ' · à jour au ' + D.meta.maj : '')
    : 'AnarBib · backlog v34' + (D.meta.maj ? ' · atualizado em ' + D.meta.maj : '');
  document.getElementById('ttl').textContent=L(D.meta.title,K);
  document.getElementById('sub').textContent=L(D.meta.subtitle,K);
  document.getElementById('mta').textContent=
    (K==='fr'?'écrit le ':'escrito em ')+D.meta.date
    +(D.meta.maj?(K==='fr'?', mis à jour le ':', atualizado em ')+D.meta.maj:'')
    +' · '+D.items.length+' '+t.total
    +' · '+(K==='fr'?'remplace ':'substitui ')+D.meta.previous;
  bar();
  const shown=D.items.filter(match);
  let h='';

  if(st.dom==='all'&&st.prio==='all'&&!st.q){
    h+='<h2>'+t.photo+'</h2><p class="note">'+md(L(D.etat.photo_intro,K))+'</p>';
    D.etat.photo.forEach(g=>{
      h+='<h3>'+L(g.g,K)+'</h3><div class="tbl"><table class="photo"><tbody>';
      g.rows.forEach(r=>{h+='<tr><td>'+md(L(r[0],K))+'</td><td>'+r[1]+'</td><td>'+md(L(r[2],K))+'</td></tr>';});
      h+='</tbody></table></div>';
    });
    h+='<h2>'+t.ecarts+'</h2><p class="note">'+md(L(D.etat.ecarts_intro,K))+'</p>';
    Object.keys(D.etat.sens_labels).forEach(sens=>{
      const rows=D.etat.ecarts.filter(e=>e.sens===sens);
      if(!rows.length)return;
      h+='<h3>'+L(D.etat.sens_labels[sens],K)+'</h3>';
      rows.forEach(e=>{h+='<div class="ecart"><b>'+md(L(e.quoi,K))+'</b><span>'+t.dit+' — '+md(L(e.dit,K))+'</span><span>'+t.reel+' — '+md(L(e.reel,K))+'</span></div>';});
    });
  }

  h+='<h2>'+t.chantiers+' <span class="count">'+shown.length+' / '+D.items.length+'</span></h2>';
  if(!shown.length){ h+='<p class="empty">'+(K==='fr'?'Aucun item ne correspond.':'Nenhum item corresponde.')+'</p>'; }
  D.domains.forEach(d=>{
    const list=shown.filter(i=>i.d===d.key);
    if(!list.length)return;
    h+='<h3>'+d.key+' — '+L(d.label,K)+' <span class="count">'+list.length+'</span></h3>';
    h+='<p class="note">'+md(L(d.note,K))+'</p>';
    list.forEach(i=>{h+=card(i);});
  });

  if(st.dom==='all'&&st.prio==='all'&&!st.q){
    h+='<h2>'+t.clotures+'</h2><p class="note">'+md(L(D.clotures.intro,K))+'</p><div class="tbl"><table class="clot"><tbody>';
    D.clotures.rows.forEach(r=>{h+='<tr><td>'+md(L(r[0],K))+'</td><td>'+md(L(r[1],K))+'</td><td>'+md(L(r[2],K))+'</td></tr>';});
    h+='</tbody></table></div>';
  }
  document.getElementById('main').innerHTML=h;
}
render();
</script>
</body>
</html>`;
}

// ---------------------------------------------------------------- écriture
LANGS.forEach(({ k, file }) => {
  const p = path.join(OUTDIR, file);
  fs.writeFileSync(p, markdown(k), 'utf8');
  console.log('écrit :', p);
});
const hp = path.join(OUTDIR, 'backlog-v34.html');
fs.writeFileSync(hp, html(), 'utf8');
console.log('écrit :', hp);
console.log(items.length + ' items sur ' + D.domains.length + ' domaines.');
