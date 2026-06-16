// ═══════════════════════════════════════════════════════════════════════════
// skosExport — sérialise le thésaurus (api.thesaurus_export_v1) en SKOS.
//
// Thésaurus v3-B : le commun « thésaurus matière » exporté en donnée liée
// (Turtle + JSON-LD), réutilisable par d'autres institutions. URI de base des
// concepts : https://app.anarbib.org/thesaurus/<slug>. Mapping :
//   label_i18n  -> skos:prefLabel @lang        notation   -> skos:notation
//   alt_i18n    -> skos:altLabel @lang         scope_note -> skos:scopeNote
//   hidden_i18n -> skos:hiddenLabel @lang      parent     -> skos:broader
//   relations   -> skos:related (symétrique)   depreciado -> owl:deprecated
// ═══════════════════════════════════════════════════════════════════════════

export const THESAURUS_BASE = 'https://app.anarbib.org/thesaurus/';

const esc = (s) => String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\r/g, '').replace(/\n/g, '\\n');
const iri = (base, slug) => base + encodeURIComponent(slug);

function relationsMap(relations) {
  const m = {};
  for (const { a, b } of (relations || [])) {
    (m[a] ||= []).push(b);
    (m[b] ||= []).push(a);
  }
  return m;
}

// ── Turtle ──────────────────────────────────────────────────────────────────
export function toTurtle(data, base = THESAURUS_BASE) {
  const concepts = data?.concepts || [];
  const relMap = relationsMap(data?.relations);
  const L = [];
  L.push('@prefix skos: <http://www.w3.org/2004/02/skos/core#> .');
  L.push('@prefix owl: <http://www.w3.org/2002/07/owl#> .');
  L.push('@prefix dct: <http://purl.org/dc/terms/> .');
  L.push(`@base <${base}> .`);
  L.push('');
  L.push('<> a skos:ConceptScheme ;');
  L.push('   dct:title "Thésaurus AnarBib"@fr, "Tesauro AnarBib"@pt-BR ;');
  L.push('   dct:description "Thésaurus matière du réseau de bibliothèques anarchistes AnarBib."@fr .');
  L.push('');
  for (const c of concepts) {
    const P = ['   a skos:Concept', '   skos:inScheme <>'];
    for (const [loc, val] of Object.entries(c.label_i18n || {})) if (val) P.push(`   skos:prefLabel "${esc(val)}"@${loc}`);
    for (const [loc, arr] of Object.entries(c.alt_i18n || {})) if (Array.isArray(arr)) for (const v of arr) if (v) P.push(`   skos:altLabel "${esc(v)}"@${loc}`);
    for (const [loc, arr] of Object.entries(c.hidden_i18n || {})) if (Array.isArray(arr)) for (const v of arr) if (v) P.push(`   skos:hiddenLabel "${esc(v)}"@${loc}`);
    if (c.notation) P.push(`   skos:notation "${esc(c.notation)}"`);
    if (c.scope_note) P.push(`   skos:scopeNote "${esc(c.scope_note)}"@pt-BR`);
    if (c.parent_slug) P.push(`   skos:broader <${encodeURIComponent(c.parent_slug)}>`);
    for (const rel of (relMap[c.slug] || [])) P.push(`   skos:related <${encodeURIComponent(rel)}>`);
    if (c.deprecated) P.push('   owl:deprecated true');
    L.push(`<${encodeURIComponent(c.slug)}>`);
    L.push(P.join(' ;\n') + ' .');
    L.push('');
  }
  return L.join('\n');
}

// ── JSON-LD ─────────────────────────────────────────────────────────────────
export function toJsonLd(data, base = THESAURUS_BASE) {
  const concepts = data?.concepts || [];
  const relMap = relationsMap(data?.relations);
  const langVals = (i18n) => Object.entries(i18n || {}).filter(([, v]) => v).map(([loc, v]) => ({ '@language': loc, '@value': v }));
  const langValsArr = (i18n) => {
    const out = [];
    for (const [loc, arr] of Object.entries(i18n || {})) if (Array.isArray(arr)) for (const v of arr) if (v) out.push({ '@language': loc, '@value': v });
    return out;
  };
  const graph = concepts.map((c) => {
    const node = {
      '@id': iri(base, c.slug), '@type': 'skos:Concept',
      'skos:inScheme': { '@id': base },
      'skos:prefLabel': langVals(c.label_i18n),
    };
    const alt = langValsArr(c.alt_i18n); if (alt.length) node['skos:altLabel'] = alt;
    const hid = langValsArr(c.hidden_i18n); if (hid.length) node['skos:hiddenLabel'] = hid;
    if (c.notation) node['skos:notation'] = c.notation;
    if (c.scope_note) node['skos:scopeNote'] = { '@language': 'pt-BR', '@value': c.scope_note };
    if (c.parent_slug) node['skos:broader'] = { '@id': iri(base, c.parent_slug) };
    const rels = relMap[c.slug] || []; if (rels.length) node['skos:related'] = rels.map((r) => ({ '@id': iri(base, r) }));
    if (c.deprecated) node['owl:deprecated'] = true;
    return node;
  });
  return JSON.stringify({
    '@context': {
      skos: 'http://www.w3.org/2004/02/skos/core#',
      owl: 'http://www.w3.org/2002/07/owl#',
      dct: 'http://purl.org/dc/terms/',
    },
    '@graph': [
      { '@id': base, '@type': 'skos:ConceptScheme', 'dct:title': 'Thésaurus AnarBib' },
      ...graph,
    ],
  }, null, 2);
}

// ── Téléchargement ──────────────────────────────────────────────────────────
export function downloadText(filename, text, mime) {
  const blob = new Blob([text], { type: `${mime};charset=utf-8` });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url; a.download = filename;
  document.body.appendChild(a); a.click(); document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
