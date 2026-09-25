// =============================================================================
// scripts/ficedl_thesaurus_esquisse.mjs — the 28-descriptor SKOS sketch of the FICEDL thesaurus
//
// Rebuilds ficedl_thesaurus_ESQUISSE.csv (; BOM CRLF) and
// ficedl_thesaurus_ESQUISSE.jsonld (LF) from a parsed aspiration (the JSON
// produced by ficedl_thesaurus.mjs). Port, line for line, of the Python
// generator of 2026-09-09; its output is byte-identical to the files of that
// day when fed the aspiration of 2026-09-03.
//
// What the sketch encodes (answers of the source, 2026-09-07):
//   - two skos:ConceptScheme ("liste commune" = subjects; "géo-histo" = geo
//     + dates), no invented scheme URI (blank nodes);
//   - canonical URI https://thesaurus.ficedl.info/?motNN, skos:notation = bare
//     number, the /id/motNN form withdrawn;
//   - "X (généralités)" confirmed as head of hierarchy: broader written as
//     confirmed;
//   - "art : courants" as a provisional skos:Collection (question (b) open);
//   - the "dates" facet has its label (page H1) and its links;
//   - the out-of-block asterisk is data (hors_liste_cira).
// The sketch is NOT an official export; its open questions belong to the
// people who keep the site. Texts inside are in French on purpose: they are
// addressed to the FICEDL.
//
// Standalone use:  node build_esquisse.mjs <aspiration.json> [outdir]
//
// In the AnarBib repository (backlog v34 H13, 25/09/2026) the sketch lives in
// docs/journal/ficedl/ next to the aspiration it is built from. Regenerate:
//   node scripts/ficedl_thesaurus_esquisse.mjs docs/journal/ficedl/ficedl_thesaurus_2026-09-03.json docs/journal/ficedl
// The file is a copy of build_esquisse.mjs from the Bologna package
// (ficedl-thesaurus-scraper, 09/09); a change here goes there too.
// =============================================================================

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join, basename } from "node:path";
import { fileURLToPath } from "node:url";

const IDS = ("mot1 mot20 mot24 mot2 mot14 mot51 mot303 mot331 mot228 mot87 mot515 mot516 " +
  "mot8 mot17 mot22 mot23 mot25 mot26 mot27 mot28 mot29 mot31 mot32 mot34 " +
  "mot88 mot90 mot91 mot93").split(" ");
const LANGS = ["fr", "en", "es", "it", "pt", "de", "nl", "ca", "el", "eo"];
const BASE = "https://thesaurus.ficedl.info/";
const SCHEME = { sujets: "_:liste-commune", geo: "_:geo-histo", dates: "_:geo-histo" };
const SCHEME_LABEL = { "_:liste-commune": "liste commune", "_:geo-histo": "géo-histo" };
const COLL_ART_COURANTS = "_:collection-art-courants";
// The structural revision of the sketch (two schemes, ?motNN…) is dated; it
// does not move with the aspiration.
const REVISION_FR = "09/09/2026";

const MOIS = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"];
function dateFr(iso) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso || "");
  if (!m) return iso || "date inconnue";
  const d = parseInt(m[3], 10);
  return `${d === 1 ? "1er" : d} ${MOIS[parseInt(m[2], 10) - 1]} ${m[1]}`;
}

// Python truthiness for the fields we read: {} and [] and "" are falsy.
const nonEmpty = (x) => (x == null ? false : Array.isArray(x) ? x.length > 0 : typeof x === "object" ? Object.keys(x).length > 0 : !!x);

// notes particulières (diagnostic à renvoyer à la source, jamais corrigé ici)
const NOTES = {
  mot24: "Parent « art : courants » : pas un descripteur. Question (b) du 07/09, ouverte : groupe de mots-clés SPIP (alors la hiérarchie est une donnée du site) ou convention d'affichage (alors skos:Collection) ? Écrit ici comme skos:Collection, à titre provisoire.",
  mot303: "Corrigé à la source entre le 27/08 et le 03/09 : les parenthèses sont entrées dans chaque langue (plus de « ) » orphelin). Reste, en grec, la fermante tombée dans la romanisation : « (Ανατολή » / « Anatolí̱) ».",
  mot331: "Corrigé à la source entre le 27/08 et le 03/09 : « 1886 (Haymarket) » en français, le segment portugais vide (« : ) * ») a disparu — le portugais s'arrête désormais à « história ». L'astérisque porte sur la fiche.",
  mot515: "Facette « dates » : aucun bloc de traduction (par construction, une année n'en a pas besoin). Libellé relevé dans le titre de la page, lien Placard relevé.",
  mot516: "Facette « dates » : aucun bloc de traduction (par construction). Libellé relevé dans le titre de la page, lien Placard relevé.",
  mot228: "Deux facettes (sujets, geo) : le descripteur appartient aux deux vocabulaires.",
};

export function buildEsquisse(recordsArray, { outDir, aspIso }) {
  mkdirSync(outDir, { recursive: true });
  const ASPIRATION = dateFr(aspIso);
  const ASP_ISO = aspIso;

  const recs = {};
  for (const r of recordsArray) recs[r.id] = r;
  const values = Object.values(recs);
  const n_fiches = values.length;
  const n_par_facette = {};
  for (const r of values) for (const f of r.facet || []) n_par_facette[f] = (n_par_facette[f] || 0) + 1;
  const hasContent = (r) => nonEmpty(r.labels) || nonEmpty(r.title_fr);
  const n_aspirees = values.filter(hasContent).length;
  const injoignables = values.filter((r) => !hasContent(r)).map((r) => r.id).sort((a, b) => parseInt(a.slice(3)) - parseInt(b.slice(3)));
  const n_liens = values.reduce((n, r) => n + (r.catalog_links || []).length, 0);
  const dates = values.filter((r) => (r.facet || []).includes("dates"));
  const dates_lab = dates.filter((r) => nonEmpty(r.title_fr)).map((r) => r.title_fr).sort();
  const n_dates_liens = dates.filter((r) => nonEmpty(r.catalog_links)).length;
  const missing = IDS.filter((i) => !recs[i]);
  const ids = IDS.filter((i) => recs[i]);
  const n_sel = ids.length;

  // Index libellé fr -> id (pour résoudre les parents)
  const fr_index = {};
  for (const r of values) {
    const lab = (nonEmpty(r.labels) && r.labels.fr) || r.title_fr;
    if (lab) fr_index[lab.trim().replace(/\s+/g, " ")] = r.id;
  }

  const uri = (i) => `${BASE}?${i}`;
  const notation = (i) => i.slice(3);

  // (parent_id, regle) — regle ∈ racine | direct | generalites_confirme_source | introuvable:<segment>
  function parent_of(r) {
    const h = r.hierarchy || [];
    if (!h.length && (r.facet || []).includes("dates")) return [null, "aucune_hierarchie (dates)"];
    if (h.length < 2) return [null, "racine"];
    const parent = h.slice(0, -1).join(" : ");
    if (parent in fr_index) return [fr_index[parent], "direct"];
    if (parent + " (généralités)" in fr_index) return [fr_index[parent + " (généralités)"], "generalites_confirme_source"];
    return [null, "INTROUVABLE:" + parent];
  }
  const label_fr = (r) => (nonEmpty(r.labels) && r.labels.fr) || r.title_fr || "";

  // ── CSV ────────────────────────────────────────────────────────────────
  const cols = ["id", "notation", "uri_canonique", "page", "vocabulaire", "facette", "profondeur", "parent",
    "regle_du_parent", "libelle_hierarchique_fr", ...LANGS.map((l) => "label_" + l),
    "el_latn", "hors_liste_cira", "liens_catalogues", "remarque"];

  const entete = `# ESQUISSE — aspiration du ${ASPIRATION} (révisée le ${REVISION_FR} après les réponses de la source du 07/09) ` +
    `— ${n_sel} descripteurs sur ${n_fiches} fiches (${n_aspirees} aspirées, ${injoignables.length} injoignables le jour même) ` +
    `— deux vocabulaires : liste commune (sujets) et géo-histo (geo + dates) — URI canonique ?motNN, la forme /id/motNN est retirée — non officiel`;

  const byScheme = (r) => {
    const set = [...new Set((r.facet || []).map((f) => SCHEME[f]))];
    return set.sort((a, b) => (a !== "_:liste-commune") - (b !== "_:liste-commune"));
  };

  const rows = [];
  for (const i of ids) {
    const r = recs[i];
    const labs = nonEmpty(r.labels) ? r.labels : {};
    let [pid, regle] = parent_of(r);
    if (i === "mot24") {
      regle = "collection:art : courants";
      pid = null;
    }
    const h = r.hierarchy || [];
    const vocab = [...new Set((r.facet || []).map((f) => SCHEME_LABEL[SCHEME[f]]))]
      .sort((a, b) => (a !== "liste commune") - (b !== "liste commune")).join(" | ");
    const remarque = NOTES[i] || "";
    const row = [i, notation(i), uri(i), `${BASE}spip.php?${i}`, vocab, (r.facet || []).join("|"),
      h.length ? String(h.length) : "", pid || "", regle, label_fr(r)];
    for (const l of LANGS) row.push(nonEmpty(r.labels) ? labs[l] || "" : l === "fr" ? r.title_fr || "" : "");
    row.push(nonEmpty(r.labels) ? labs.el_roman || "" : "");
    row.push((r.flags || []).includes("hors_liste_cira") ? "oui" : "");
    row.push(String((r.catalog_links || []).length));
    row.push(remarque);
    rows.push(row);
  }
  const csv_lines = [entete, cols.join(";"), ...rows.map((row) => row.map((v) => String(v).replace(/;/g, ",")).join(";"))];
  writeFileSync(join(outDir, "ficedl_thesaurus_ESQUISSE.csv"), Buffer.concat([Buffer.from([0xef, 0xbb, 0xbf]), Buffer.from(csv_lines.join("\r\n") + "\r\n", "utf8")]));

  // ── JSON-LD ────────────────────────────────────────────────────────────
  const ctx = {
    skos: "http://www.w3.org/2004/02/skos/core#",
    dct: "http://purl.org/dc/terms/",
    rdfs: "http://www.w3.org/2000/01/rdf-schema#",
    prefLabel: { "@id": "skos:prefLabel", "@container": "@language" },
    scopeNote: { "@id": "skos:scopeNote", "@container": "@language" },
    editorialNote: { "@id": "skos:editorialNote", "@container": "@language" },
    notation: "skos:notation",
    broader: { "@id": "skos:broader", "@type": "@id" },
    inScheme: { "@id": "skos:inScheme", "@type": "@id" },
    member: { "@id": "skos:member", "@type": "@id" },
    seeAlso: { "@id": "rdfs:seeAlso", "@type": "@id" },
    type: "@type",
    id: "@id",
  };

  const desc_commune = `ESQUISSE — ${n_sel} descripteurs sur ${n_fiches} fiches (${n_aspirees} aspirées), produits hors du site à partir ` +
    `d'une aspiration du ${ASPIRATION}, révisée le ${REVISION_FR} après les réponses de la source du 07/09/2026. ` +
    `Ce fichier n'est PAS l'export officiel.`;
  const rights = "À FIXER. Réponse informelle de juin 2026 : « pas de droits dessus, tout le monde peut le partager, " +
    "à condition que les évolutions se fassent collectivement ».";
  const note_schemes = "Deux vocabulaires, pas un — confirmé par la source le 07/09/2026 : la « liste commune » (facette sujets) et " +
    "la « géo-histo » (facettes geo et dates). La FICEDL ne publie aucun URI de schéma : aucun n'est inventé ici, " +
    "les deux schémas sont des nœuds anonymes à nommer par la source. Un fichier à deux schémas ou deux fichiers : question (c) ouverte.";
  const note_uri = "Identifiants (question 1 du 28/08), close le 07/09 : la forme canonique SPIP est ?motNN quel que soit le type d'URL affiché ; " +
    "les « URL propres » sont des adresses, pas des identités. La proposition /id/motNN est retirée ; skos:notation porte le numéro nu.";

  const d0 = dates_lab.length ? dates_lab[0] : "?";
  const d1 = dates_lab.length ? dates_lab[dates_lab.length - 1] : "?";
  const graph = [];
  graph.push({
    id: "_:liste-commune", type: "skos:ConceptScheme",
    "dct:title": { "@value": "Thésaurus partagé de la FICEDL — liste commune (sujets)", "@language": "fr" },
    "dct:creator": "Anne Cassani, CIRA de Lausanne, 1985 — et les traductrices et traducteurs depuis",
    "dct:description": { "@value": desc_commune + ` Vocabulaire des sujets : ${n_par_facette.sujets || 0} descripteurs.`, "@language": "fr" },
    "dct:date": ASP_ISO,
    "dct:rights": { "@value": rights, "@language": "fr" },
    editorialNote: { fr: note_schemes + " " + note_uri },
  });
  graph.push({
    id: "_:geo-histo", type: "skos:ConceptScheme",
    "dct:title": { "@value": "Thésaurus partagé de la FICEDL — géo-histo (lieux, histoire, dates)", "@language": "fr" },
    "dct:description": { "@value": desc_commune + ` Vocabulaire géo-histo : ${n_par_facette.geo || 0} descripteurs geo et ${n_par_facette.dates || 0} dates ` +
      `(${d0}-${d1} ; ${dates_lab.length} avec libellé, ${n_dates_liens} avec liens Placard / Cartoliste ; ` +
      `${injoignables.join(", ")} injoignables le ${ASP_ISO}).`, "@language": "fr" },
    "dct:date": ASP_ISO,
    "dct:rights": { "@value": rights, "@language": "fr" },
    editorialNote: { fr: note_schemes + " Créateur·rice et date de la géo-histo : non établis depuis l'extérieur. " +
      "Les dates n'ont pas de bloc de traduction : leur libellé est le titre de la page." },
  });
  graph.push({
    id: COLL_ART_COURANTS, type: "skos:Collection",
    prefLabel: { fr: "art : courants" },
    member: [uri("mot24")],
    inScheme: "_:liste-commune",
    editorialNote: { fr: "Tête de libellé qui n'est pas un descripteur (comme « guerres », neuf fois, dans la géo-histo). " +
      "Question (b) du 07/09, ouverte : groupe de mots-clés SPIP — alors la hiérarchie est une donnée du site, exportable en skos:broader — " +
      "ou convention d'affichage — alors skos:Collection, comme écrit ici à titre provisoire." },
  });

  for (const i of ids) {
    const r = recs[i];
    const labs = nonEmpty(r.labels) ? r.labels : {};
    const node = { id: uri(i), type: "skos:Concept", notation: notation(i) };
    const schemes = byScheme(r);
    node.inScheme = schemes.length > 1 ? schemes : schemes[0];
    const pl = {};
    if (nonEmpty(r.labels)) {
      for (const l of LANGS) if (labs[l]) pl[l] = labs[l];
      if (labs.el_roman) pl["el-Latn"] = labs.el_roman;
    } else if (nonEmpty(r.title_fr)) pl.fr = r.title_fr;
    if (Object.keys(pl).length) node.prefLabel = pl;
    const [pid, regle] = parent_of(r);
    const ed = [];
    if (i === "mot24") {
      // collection, no broader
    } else if (regle === "direct") {
      node.broader = uri(pid);
      ed.push("broader DÉDUIT du libellé (le parent existe tel quel comme descripteur) ; la nature de la hiérarchie côté site reste la question (b) du 07/09.");
    } else if (regle === "generalites_confirme_source") {
      node.broader = uri(pid);
      ed.push("broader CONFIRMÉ par la source le 07/09/2026 : « X (généralités) » est la tête de hiérarchie.");
    }
    if ((r.flags || []).includes("hors_liste_cira")) {
      node.scopeNote = { fr: "Marqué d'une astérisque à la source : mot absent, à l'époque, de la liste d'origine du CIRA." };
      ed.push("L'astérisque est posée hors du bloc de traduction : elle porte sur la fiche, pas sur une langue.");
    }
    if (i in NOTES) ed.push(NOTES[i]);
    if (ed.length) node.editorialNote = { fr: ed.join(" ") };
    const links = (r.catalog_links || []).map((l) => l.href);
    if (links.length) node.seeAlso = links;
    node["rdfs:isDefinedBy"] = { "@id": `${BASE}spip.php?${i}` };
    graph.push(node);
  }

  const doc = { "@context": ctx, "@graph": graph };
  writeFileSync(join(outDir, "ficedl_thesaurus_ESQUISSE.jsonld"), JSON.stringify(doc, null, 2) + "\n", "utf8");

  return { selection: n_sel, missing, n_fiches, n_aspirees, injoignables, n_liens };
}

// --- standalone -------------------------------------------------------------
if (process.argv[1] && basename(fileURLToPath(import.meta.url)) === basename(process.argv[1])) {
  const src = process.argv[2];
  if (!src) {
    console.error("usage: node scripts/ficedl_thesaurus_esquisse.mjs <aspiration.json> [outdir]");
    process.exit(2);
  }
  const outDir = process.argv[3] || ".";
  const m = basename(src).match(/(\d{4}-\d{2}-\d{2})/);
  const res = buildEsquisse(JSON.parse(readFileSync(src, "utf8")), { outDir, aspIso: m ? m[1] : "unknown" });
  console.log(`fiches=${res.n_fiches} aspirees=${res.n_aspirees} injoignables=${res.injoignables.join(",")} liens=${res.n_liens} selection=${res.selection}${res.missing.length ? " MISSING=" + res.missing.join(",") : ""}`);
}
