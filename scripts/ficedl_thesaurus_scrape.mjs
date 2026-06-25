#!/usr/bin/env node
// =============================================================================
// scripts/ficedl_thesaurus_scrape.mjs
// POC — Récupération + audit du thésaurus FICEDL (thesaurus.ficedl.info)
//
// Objet : prouver la faisabilité du « harvest réel » du thésaurus partagé
//   FICEDL et produire la liste des coquilles multilingues à reverser en amont
//   (posture « faire évoluer collectivement », cf. mail de Claude / CCL Lille).
//
// Le site est en SPIP, sans export SKOS/RDF/CSV : on parse le HTML rendu, qui
//   est d'une régularité parfaite (bloc `[fr]… [ca]… … [pt]…`).
//
// Sortie :
//   - /tmp/ficedl_thesaurus.json        (données structurées, 1 objet / descripteur)
//   - /tmp/ficedl_thesaurus_audit.md    (rapport d'audit lisible)
//   + résumé concis sur stdout.
//
// Étiquette serveur : UA navigateur (le site 403 les UA « robot »), en-tête
//   From de contact, concurrence basse (5) + délai entre requêtes.
//
// Le script est autonome : il énumère lui-même les descripteurs des 3 facettes
//   (groupes SPIP 1=sujets, 2=géo/histoire, 3=dates) puis crawle chaque fiche.
//
// Usage  : node scripts/ficedl_thesaurus_scrape.mjs [dossier_sortie]
//          (défaut : le dossier temporaire du système)
//
// Session : Thésaurus FICEDL — harvest & audit (POC)
// Auteur  : AnarBib / Claude Code
// =============================================================================

import { writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const BASE = "https://thesaurus.ficedl.info/spip.php?";
const UA =
  "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36";
const CONTACT = "x.vanwelden@gmail.com";
const LANGS = ["fr", "ca", "de", "el", "en", "eo", "es", "it", "nl", "pt"];
const CONCURRENCY = 2;
const DELAY_MS = 350;

const CATALOG_HOSTS =
  /(cira\.ch|cira-marseille\.info|placard\.ficedl\.info|cartoliste\.ficedl\.info|ml\.ficedl\.info|lille\.cybertaria\.org|raforum)/i;

// --- petits utilitaires -----------------------------------------------------
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function decode(s) {
  if (!s) return "";
  return s
    .replace(/&#x([0-9a-fA-F]+);/g, (_, h) => String.fromCodePoint(parseInt(h, 16)))
    .replace(/&#(\d+);/g, (_, d) => String.fromCodePoint(parseInt(d, 10)))
    .replace(/&nbsp;/g, " ")
    .replace(/&mdash;/g, "—")
    .replace(/&ndash;/g, "–")
    .replace(/&laquo;/g, "«")
    .replace(/&raquo;/g, "»")
    .replace(/&(?:apos|#39);/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&");
}

function stripTags(raw) {
  return raw
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ");
}

function extractLocalIds(raw) {
  const ids = new Set();
  const re = /href="(?:spip\.php\?mot|mot)(\d+)(?:\.html)?"/g;
  let m;
  while ((m = re.exec(raw))) ids.add("mot" + m[1]);
  return ids;
}

async function fetchText(url, tries = 6) {
  for (let t = 0; t < tries; t++) {
    try {
      const r = await fetch(url, {
        headers: { "User-Agent": UA, From: CONTACT, "Accept-Language": "fr" },
        redirect: "follow",
      });
      if (r.status === 200) return await r.text();
      throw new Error("HTTP " + r.status);
    } catch (e) {
      if (t === tries - 1) throw e;
      await sleep(900 * (t + 1) + Math.floor(Math.random() * 500)); // backoff + jitter
    }
  }
}

async function pool(items, n, worker) {
  const out = new Array(items.length);
  let i = 0;
  let done = 0;
  async function run() {
    while (i < items.length) {
      const idx = i++;
      try {
        out[idx] = await worker(items[idx], idx);
      } catch (e) {
        out[idx] = { id: items[idx], error: String(e && e.message ? e.message : e) };
      }
      done++;
      if (done % 50 === 0) process.stderr.write(`  …${done}/${items.length}\n`);
      await sleep(DELAY_MS);
    }
  }
  await Promise.all(Array.from({ length: n }, run));
  return out;
}

// --- parsing d'une fiche descripteur ---------------------------------------
const TERMINATOR_RE =
  /(?:Voir sur|Voir :|~\s*:|Liste commune|Liste géographie|Liste matière|Mots-clés|Notices|Quelques|date de parution|autre entrée|Articles trouvés|Se connecter|site catalogues)/;

// Isole le bloc de traduction du descripteur en évitant le menu « Langues du
// site » (dont la valeur [fr] est le mot « français »).
function findBlock(text) {
  const re = /\[fr\]\s*([^[]*)/g;
  let m;
  while ((m = re.exec(text))) {
    const v = m[1].trim();
    if (!v || v.toLowerCase() === "français") continue;
    const start = m.index;
    // Fin du bloc = le plus proche parmi : terminateur de navigation, un SECOND
    // [fr] (= le bloc re-rendu en double par SPIP sur certaines fiches), 800 car.
    const t = text.slice(start).search(TERMINATOR_RE);
    const next = text.slice(start + 4).search(/\[fr\]/);
    const rel = [800];
    if (t >= 0) rel.push(t);
    if (next >= 0) rel.push(next + 4);
    const end = Math.min(start + Math.min(...rel), text.length);
    return text.slice(start, end);
  }
  return null;
}

function parseDescriptor(id, raw) {
  const text = decode(stripTags(raw)).replace(/\s+/g, " ").trim();
  const rec = { id, labels: {}, hierarchy: null, depth: null, catalog_links: [], flags: [] };

  const region = findBlock(text);
  if (!region) {
    rec.flags.push("no_translation_block");
    return rec;
  }

  // Scan tolérant : récupère chaque balise [xx]valeur, et signale les balises
  // inconnues (ex. [il] pour [it]), les doublons et les langues manquantes —
  // exactement les coquilles structurelles qu'un parseur rigide laisse filer.
  const tags = [...region.matchAll(/\[([a-z]{2})\]\s*([^[]*)/g)].map((x) => [x[1], x[2].trim()]);
  const seenLang = new Set();
  for (const [lg, val] of tags) {
    if (!LANGS.includes(lg)) {
      rec.flags.push(`bad_lang_tag:${lg}→${val}`);
      continue;
    }
    if (seenLang.has(lg)) {
      rec.flags.push(`dup_lang:${lg}`);
      continue;
    }
    seenLang.add(lg);
    rec.labels[lg] = val;
  }
  for (const lg of LANGS) if (!seenLang.has(lg)) rec.flags.push(`missing_lang:${lg}`);

  // grec : séparer écriture native / romanisation (« άμεση δράση = ámesi̱ drási̱ »)
  if (rec.labels.el && rec.labels.el.includes("=")) {
    const [native, ...rom] = rec.labels.el.split(/\s*=\s*/);
    rec.labels.el = native.trim();
    rec.labels.el_roman = rom.join("=").trim();
  }

  // hiérarchie depuis le libellé FR (précoordination par « : »)
  const fr = rec.labels.fr || "";
  const levels = fr.split(/\s*:\s*/).map((s) => s.trim()).filter(Boolean);
  rec.hierarchy = levels;
  rec.depth = levels.length;

  // liens catalogues (cross-catalogues du réseau), scopés par hôte connu
  const anchorRe = /<a\b([^>]*\bclass="spip_out"[^>]*)>([\s\S]*?)<\/a>/gi;
  const seen = new Set();
  let a;
  while ((a = anchorRe.exec(raw))) {
    const attrs = a[1];
    const href = (attrs.match(/href="([^"]+)"/) || [])[1];
    if (!href || !/^https?:\/\//.test(href) || !CATALOG_HOSTS.test(href)) continue;
    const title = decode((attrs.match(/title="([^"]*)"/) || [])[1] || "");
    const label = decode(a[2].replace(/<[^>]+>/g, " ")).replace(/\s+/g, " ").trim();
    const url = href.replace(/\s+/g, ""); // SPIP insère parfois un saut de ligne dans l'URL
    if (seen.has(url)) continue;
    seen.add(url);
    rec.catalog_links.push({ name: title || label, href: url });
  }

  return rec;
}

// --- audit des coquilles ----------------------------------------------------
const ENGLISH_MARKERS =
  /\b(capitalism|anarchism|socialism|communism|feminism|movement|workers?|history|against|society|economy|education|woman|women|freedom|struggle|the|and|with|without)\b/i;

// graphies pré-réforme (Acordo Ortográfico 1990) susceptibles d'apparaître
const PT_OLD =
  /(cç|óptim|\bdirect[oa]s?\b|\bdirector\b|\bobject[oa]?s?\b|\bfact[oa]s?\b|\bact[oa]s?\b|\bexact|colecç|direcç|secç|protecç|aspect[oa]|\bEgipto\b|baptism)/i;

function auditDescriptor(rec) {
  if (rec.error || rec.flags.includes("no_translation_block")) return;
  const L = rec.labels;
  const fr = (L.fr || "").toLowerCase();

  for (const lg of LANGS) {
    const v = (L[lg] || "").trim();
    if (!v) {
      if (!rec.flags.includes(`missing_lang:${lg}`)) rec.flags.push(`empty:${lg}`);
      continue;
    }
    if (lg !== "fr" && v.toLowerCase() === fr) rec.flags.push(`eq_fr:${lg}`);
    if (lg !== "en" && lg !== "fr" && ENGLISH_MARKERS.test(v))
      rec.flags.push(`english_leak:${lg}:${v}`);
    if (/ {2,}|^\s|\s$/.test(L[lg])) rec.flags.push(`whitespace:${lg}`);
  }

  // allemand : aucune majuscule => nom commun non capitalisé (faute DE)
  if (L.de && !/[A-ZÄÖÜ]/.test(L.de)) rec.flags.push(`de_no_caps:${L.de}`);

  // grec : doit contenir des lettres grecques + (idéalement) une romanisation
  if (L.el && !/[Ͱ-Ͽ]/.test(L.el)) rec.flags.push(`el_no_greek:${L.el}`);
  if (L.el && !L.el_roman) rec.flags.push(`el_no_roman`);

  // portugais : graphie pré-réforme ?
  if (L.pt) {
    const mo = L.pt.match(PT_OLD);
    if (mo) rec.flags.push(`pt_old_ortho:${mo[0]}`);
  }
}

// --- main -------------------------------------------------------------------
const outDir = process.argv[2] || tmpdir();
console.error("Énumération des descripteurs (facettes 1=sujets, 2=géo, 3=dates)…");
const [g1, g2, g3] = await Promise.all(
  [1, 2, 3].map(async (g) =>
    extractLocalIds(await fetchText(BASE + "page=groupe&groupe=" + g))
  )
);
const all = [...new Set([...g1, ...g2, ...g3])].sort(
  (a, b) => parseInt(a.slice(3)) - parseInt(b.slice(3))
);
const facetOf = (id) =>
  [g1.has(id) && "sujets", g2.has(id) && "geo", g3.has(id) && "dates"].filter(Boolean);

console.error(`Crawl de ${all.length} descripteurs (concurrence ${CONCURRENCY})…`);

async function scrapeOne(id) {
  const raw = await fetchText(BASE + id);
  const rec = parseDescriptor(id, raw);
  rec.facet = facetOf(id);
  rec.url = BASE + id;
  auditDescriptor(rec);
  return rec;
}

let records = await pool(all, CONCURRENCY, scrapeOne);

// passe de rattrapage : refait séquentiellement (concurrence 1) les fiches en erreur
const failedIdx = records.map((r, i) => (r && r.error ? i : -1)).filter((i) => i >= 0);
if (failedIdx.length) {
  console.error(`Rattrapage séquentiel de ${failedIdx.length} fiches en erreur…`);
  for (const i of failedIdx) {
    try {
      records[i] = await scrapeOne(all[i]);
    } catch (e) {
      records[i] = { id: all[i], error: String(e && e.message ? e.message : e), facet: facetOf(all[i]), url: BASE + all[i], flags: [] };
    }
    await sleep(600);
  }
}

// --- agrégats ---------------------------------------------------------------
const ok = records.filter((r) => !r.error && !r.flags.includes("no_translation_block"));
const errored = records.filter((r) => r.error);
const noBlock = records.filter((r) => !r.error && r.flags.includes("no_translation_block"));

const flat = ok.flatMap((r) => r.flags.map((f) => ({ id: r.id, facet: r.facet.join("+"), f })));
const byKind = {};
for (const { f } of flat) {
  const kind = f.split(":")[0];
  byKind[kind] = (byKind[kind] || 0) + 1;
}

const emptyByLang = {},
  eqFrByLang = {};
for (const { f } of flat) {
  if (f.startsWith("empty:")) emptyByLang[f.split(":")[1]] = (emptyByLang[f.split(":")[1]] || 0) + 1;
  if (f.startsWith("eq_fr:")) eqFrByLang[f.split(":")[1]] = (eqFrByLang[f.split(":")[1]] || 0) + 1;
}

// eq_fr segmenté par facette : sur la géo/dates, un libellé = fr est souvent
// LÉGITIME (noms propres : « Angola », « 1936 »…). Le signal « non traduit »
// n'a vraiment de sens que sur la facette SUJETS.
const facets = ["sujets", "geo", "dates"];
const okByFacet = (fc) => ok.filter((r) => r.facet.includes(fc));
const eqFrByFacetLang = {};
for (const fc of facets) {
  eqFrByFacetLang[fc] = {};
  for (const r of okByFacet(fc))
    for (const f of r.flags)
      if (f.startsWith("eq_fr:")) {
        const lg = f.split(":")[1];
        eqFrByFacetLang[fc][lg] = (eqFrByFacetLang[fc][lg] || 0) + 1;
      }
}

const englishLeaks = ok
  .flatMap((r) => r.flags.filter((f) => f.startsWith("english_leak:")).map((f) => ({ id: r.id, url: r.url, f })))
  .map((x) => {
    const [, lg, ...rest] = x.f.split(":");
    return { id: x.id, url: x.url, lang: lg, value: rest.join(":") };
  });

const deNoCaps = ok
  .filter((r) => r.flags.some((f) => f.startsWith("de_no_caps:")))
  .map((r) => ({ id: r.id, url: r.url, fr: r.labels.fr, de: r.labels.de }));

const ptOld = ok
  .filter((r) => r.flags.some((f) => f.startsWith("pt_old_ortho:")))
  .map((r) => ({ id: r.id, url: r.url, fr: r.labels.fr, pt: r.labels.pt }));

const elNoGreek = ok.filter((r) => r.flags.some((f) => f.startsWith("el_no_greek:")));
const elNoRoman = ok.filter((r) => r.flags.includes("el_no_roman"));

const missingByLang = {};
for (const { f } of flat)
  if (f.startsWith("missing_lang:")) {
    const lg = f.split(":")[1];
    missingByLang[lg] = (missingByLang[lg] || 0) + 1;
  }
const STRUCT_RE = /^(bad_lang_tag|dup_lang|missing_lang):/;
const structural = ok
  .filter((r) => r.flags.some((f) => STRUCT_RE.test(f)))
  .map((r) => ({
    id: r.id,
    url: r.url,
    facet: r.facet.join("+"),
    fr: r.labels.fr,
    issues: r.flags.filter((f) => STRUCT_RE.test(f)),
  }));

const mostFlagged = [...ok]
  .filter((r) => r.flags.length)
  .sort((a, b) => b.flags.length - a.flags.length)
  .slice(0, 25);

// --- écriture JSON ----------------------------------------------------------
const jsonPath = join(outDir, "ficedl_thesaurus.json");
const mdPath = join(outDir, "ficedl_thesaurus_audit.md");
writeFileSync(jsonPath, JSON.stringify(records, null, 2));

// --- rapport markdown -------------------------------------------------------
const pct = (n) => ((100 * n) / (ok.length || 1)).toFixed(1) + "%";
let md = "";
md += "# Audit du thésaurus FICEDL — POC harvest + coquilles multilingues\n\n";
md += `Source : https://thesaurus.ficedl.info (SPIP). Récupération par scraping HTML (aucun export SKOS/RDF/CSV exposé).\n\n`;
md += "## Couverture\n\n";
md += `- Descripteurs ciblés : **${all.length}** — sujets ${g1.size}, géo ${g2.size}, dates ${g3.size}.\n`;
md += `- Fiches parsées avec bloc 10 langues : **${ok.length}**.\n`;
md += `- Sans bloc de traduction détecté : ${noBlock.length}${noBlock.length ? " (" + noBlock.slice(0, 12).map((r) => r.id).join(", ") + (noBlock.length > 12 ? "…" : "") + ")" : ""}.\n`;
md += `- Erreurs réseau : ${errored.length}${errored.length ? " (" + errored.slice(0, 12).map((r) => r.id).join(", ") + ")" : ""}.\n\n`;

md += "## Synthèse des anomalies (par type)\n\n";
md += "| Type | Occurrences |\n|---|---|\n";
for (const [k, v] of Object.entries(byKind).sort((a, b) => b[1] - a[1])) md += `| ${k} | ${v} |\n`;
md += "\n";

md += "## Langues non traduites (libellé = français), segmenté par facette\n\n";
md += "_Sur **géo** et **dates**, « = fr » est souvent légitime (noms propres : Angola, 1936…). Le signal « non-traduit » à corriger est surtout celui de la colonne **sujets**._\n\n";
md += `| Langue | sujets (/${okByFacet("sujets").length}) | géo (/${okByFacet("geo").length}) | dates (/${okByFacet("dates").length}) | vide |\n|---|---|---|---|---|\n`;
for (const lg of LANGS)
  md += `| ${lg} | ${eqFrByFacetLang.sujets[lg] || 0} | ${eqFrByFacetLang.geo[lg] || 0} | ${eqFrByFacetLang.dates[lg] || 0} | ${emptyByLang[lg] || 0} |\n`;
md += "\n";

// liste détaillée des SUJETS non traduits (le signal exploitable)
md += "### Sujets non traduits (= fr) — détail\n\n";
for (const r of okByFacet("sujets")) {
  const langs = r.flags.filter((f) => f.startsWith("eq_fr:")).map((f) => f.split(":")[1]);
  if (langs.length) md += `- [${r.id}](${r.url}) « ${r.labels.fr} » → recopié en : ${langs.join(", ")}\n`;
}
md += "\n";

md += `## Portugais (réponse à la question « pas trop mal traduit ? »)\n\n`;
md += `- Fiches où le **pt = fr** (probable non-traduit) : **${eqFrByLang.pt || 0}** / ${ok.length} (${pct(eqFrByLang.pt || 0)}).\n`;
md += `- Fiches en **graphie pré-réforme** (acção, directo, óptimo…) : **${ptOld.length}** ${ptOld.length ? "" : "→ base déjà conforme à l'Acordo Ortográfico (compatible BR + PT)"}\n`;
md += `- Fuites d'anglais dans le champ pt : ${englishLeaks.filter((x) => x.lang === "pt").length}.\n\n`;
if (ptOld.length) {
  md += "Graphies pt à revoir :\n\n";
  for (const r of ptOld.slice(0, 40)) md += `- [${r.id}](${r.url}) — « ${r.pt} » (fr : ${r.fr})\n`;
  md += "\n";
}

md += "## Fuites d'anglais (champ non-EN contenant un mot anglais)\n\n";
if (!englishLeaks.length) md += "_aucune_\n\n";
for (const x of englishLeaks.slice(0, 60))
  md += `- [${x.id}](${x.url}) — **${x.lang}** : « ${x.value} »\n`;
md += "\n";

md += "## Allemand non capitalisé (nom commun en minuscule)\n\n";
if (!deNoCaps.length) md += "_aucune_\n\n";
for (const r of deNoCaps.slice(0, 60)) md += `- [${r.id}](${r.url}) — de : « ${r.de} » (fr : ${r.fr})\n`;
md += "\n";

md += "## Grec\n\n";
md += `- Sans écriture grecque : ${elNoGreek.length}${elNoGreek.length ? " (" + elNoGreek.slice(0, 20).map((r) => r.id).join(", ") + ")" : ""}\n`;
md += `- Sans romanisation : ${elNoRoman.length}\n\n`;

md += "## Coquilles structurelles (balises de langue)\n\n";
md += "_Fiches récupérées par le parseur tolérant : balise mal orthographiée (ex. `[il]`→`[it]`), dupliquée, ou langue absente._\n\n";
md += `Langues manquantes (balise absente) : ${LANGS.map((l) => `${l}:${missingByLang[l] || 0}`).join("  ")}\n\n`;
for (const r of structural)
  md += `- [${r.id}](${r.url}) (${r.facet}) « ${r.fr} » — ${r.issues.join(" · ")}\n`;
md += "\n";

md += "## 25 fiches les plus problématiques\n\n";
for (const r of mostFlagged)
  md += `- [${r.id}](${r.url}) (${r.facet.join("+")}) — ${r.flags.length} drapeaux : ${r.flags.join(" · ")}\n`;
md += "\n";

writeFileSync(mdPath, md);

// --- résumé stdout ----------------------------------------------------------
console.log("\n================= RÉSUMÉ =================");
console.log(`Descripteurs parsés : ${ok.length}/${all.length}  (sujets ${g1.size} / géo ${g2.size} / dates ${g3.size})`);
console.log(`Sans bloc traduction : ${noBlock.length} | erreurs réseau : ${errored.length}`);
console.log("\nAnomalies par type :");
for (const [k, v] of Object.entries(byKind).sort((a, b) => b[1] - a[1])) console.log(`  ${k.padEnd(16)} ${v}`);
console.log("\n'= français' SUR LA FACETTE SUJETS (signal exploitable) :");
console.log("  " + LANGS.map((l) => `${l}:${eqFrByFacetLang.sujets[l] || 0}`).join("  "));
console.log("  (rappel : sur géo/dates, '=fr' est souvent légitime — noms propres)");
console.log("\nPORTUGAIS :");
console.log(`  pt = fr (non traduit) : ${eqFrByLang.pt || 0}/${ok.length}`);
console.log(`  pt graphie pré-réforme : ${ptOld.length}`);
console.log(`  pt fuite d'anglais     : ${englishLeaks.filter((x) => x.lang === "pt").length}`);
console.log(`\nAllemand non capitalisé : ${deNoCaps.length}`);
console.log(`Fuites d'anglais (toutes langues) : ${englishLeaks.length}`);
console.log(`Grec sans script grec : ${elNoGreek.length} | sans romanisation : ${elNoRoman.length}`);
console.log(`\nCoquilles structurelles (balise manquante/dupliquée/erronée) : ${structural.length} fiches`);
console.log("  langues manquantes : " + LANGS.map((l) => `${l}:${missingByLang[l] || 0}`).join("  "));
console.log("\nÉcrits :");
console.log("  " + jsonPath);
console.log("  " + mdPath);
