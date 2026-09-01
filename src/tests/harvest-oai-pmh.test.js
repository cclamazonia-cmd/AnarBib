// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/harvest-oai-pmh.test.js
//
// Les edge functions ne sont couvertes par AUCUN test du dépôt : vitest.config.js
// exclut supabase/functions/** (« Deno, pas Node »). Même harnais que
// gazette-monthly-build.test.js : esbuild transpile EN MÉMOIRE le VRAI
// supabase/functions/harvest-oai-pmh/index.ts, et on l'évalue avec un `require`
// détourné (faux client supabase), un Deno minimal et un fetch stubé qui rend des
// réponses OAI-PMH canoniques. Aucun réseau, aucune base.
//
// CE QU'IL FAUT GARDER ICI PLUS QUE TOUT : LE RELÂCHEMENT DU VERROU.
// fn_import_harvest_oai pose harvest_status='in_progress' avant d'appeler l'EF et
// refuse tout nouveau moissonnage tant qu'il tient. Si cette EF sort d'un chemin
// — succès, erreur OAI, entrepôt injoignable — sans le reposer, la source devient
// inmoissonnable POUR TOUJOURS, et rien ne le dit : la RPC répond « déjà en
// cours » comme si un travail tournait. C'est le défaut que tout le Lot 3b vient
// réparer, donc c'est lui qu'on mesure, sur CHAQUE sortie (T1, T5, T6, T7).
//
// Le second piège gardé ici est de lecture : en MARCXML, l'élément qui porte une
// notice s'appelle <record> — comme celui de l'enveloppe OAI. Une expression
// non gourmande ouvrirait sur l'un et fermerait sur l'autre. T2 compte les
// notices d'une réponse à deux <record> imbriqués : elle doit en trouver deux,
// avec les bons titres, pas un fragment à cheval.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { transformSync } from 'esbuild';

const SRC = new URL('../../supabase/functions/harvest-oai-pmh/index.ts', import.meta.url);
const MARC = new URL('../../supabase/functions/process-partner-catalog-import/marc.ts', import.meta.url);
const OAI = new URL('../../supabase/functions/harvest-oai-pmh/oai.ts', import.meta.url);
const CLE = new URL('../../supabase/functions/_shared/core/secret-key.ts', import.meta.url);

const cjs = (url) => transformSync(readFileSync(url, 'utf8'), {
  loader: 'ts', format: 'cjs', target: 'es2022',
}).code;

const SECRET = 's3cr3t-de-test';
const ENV = { SUPABASE_URL: 'http://stub', SUPABASE_SERVICE_ROLE_KEY: 'stub', ANARBIB_PARTNER_IMPORT_SECRET: SECRET };

// ── Réponses OAI-PMH canoniques ───────────────────────────────────────────
const enveloppe = (inner) =>
  `<?xml version="1.0" encoding="UTF-8"?>\n<OAI-PMH xmlns="http://www.openarchives.org/OAI/2.0/">` +
  `<responseDate>2026-08-28T00:00:00Z</responseDate>${inner}</OAI-PMH>`;

// Notice MARCXML : son <record> à elle est IMBRIQUÉ dans le <record> OAI.
const recMarc = (oaiId, titre, sousTitre, isbn) =>
  `<record><header><identifier>${oaiId}</identifier><datestamp>2026-08-01</datestamp>` +
  `<setSpec>colecao:anarquismo</setSpec></header><metadata>` +
  `<record xmlns="http://www.loc.gov/MARC21/slim">` +
  `<leader>00000nam a2200000 a 4500</leader>` +
  `<controlfield tag="001">ctrl-${oaiId}</controlfield>` +
  `<datafield tag="245" ind1="1" ind2="0"><subfield code="a">${titre}</subfield>` +
  (sousTitre ? `<subfield code="b">${sousTitre}</subfield>` : '') +
  `<subfield code="c">Piotr Kropotkin</subfield></datafield>` +
  `<datafield tag="260" ind1=" " ind2=" "><subfield code="a">Sao Paulo</subfield>` +
  `<subfield code="b">Editora Teste</subfield><subfield code="c">1892</subfield></datafield>` +
  (isbn ? `<datafield tag="020" ind1=" " ind2=" "><subfield code="a">${isbn}</subfield></datafield>` : '') +
  `</record></metadata></record>`;

const recDc = (oaiId, titre) =>
  `<record><header><identifier>${oaiId}</identifier><datestamp>2026-08-02</datestamp></header><metadata>` +
  `<oai_dc:dc xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" xmlns:dc="http://purl.org/dc/elements/1.1/">` +
  `<dc:title>${titre}</dc:title><dc:creator>KROPOTKIN, Piotr</dc:creator>` +
  `<dc:subject>anarquismo</dc:subject><dc:publisher>Editora Teste</dc:publisher>` +
  `<dc:date>1892-05-01</dc:date><dc:language>pt</dc:language>` +
  `<dc:identifier>ISBN:9788575591234</dc:identifier>` +
  `</metadata></record>`.replace('</metadata>', '</oai_dc:dc></metadata>');

const recSupprime = (oaiId) =>
  `<record><header status="deleted"><identifier>${oaiId}</identifier>` +
  `<datestamp>2026-08-03</datestamp></header></record>`;

const listRecords = (recs, token = null, size = null) =>
  enveloppe(`<ListRecords>${recs.join('')}` +
    (token === null ? '' : `<resumptionToken${size !== null ? ` completeListSize="${size}"` : ''}>${token}</resumptionToken>`) +
    `</ListRecords>`);

const erreurOai = (code, msg) => enveloppe(`<error code="${code}">${msg}</error>`);

const listFormats = (prefixes) => enveloppe('<ListMetadataFormats>' +
  prefixes.map((p) => `<metadataFormat><metadataPrefix>${p}</metadataPrefix></metadataFormat>`).join('') +
  '</ListMetadataFormats>');

// ── Harnais ───────────────────────────────────────────────────────────────
// `etat` décrit la base ; `reponses` est la liste des corps XML rendus par
// fetch, dans l'ordre ; `urlsVues` collecte les URL appelées (c'est ainsi qu'on
// vérifie la négociation et la reprise sans lire le code).
function monterEF(etat, reponses) {
  const ecrits = [];
  const urlsVues = [];
  const entetesVues = [];

  const table = (schema, nom) => {
    const chaine = [];
    const proxy = new Proxy({}, {
      get(_c, prop) {
        if (prop === 'then') return (ok) => ok(repondre(nom, chaine));
        return (...args) => {
          chaine.push({ op: prop, args });
          if (['insert', 'update', 'upsert', 'delete'].includes(prop)) {
            ecrits.push({ schema, table: nom, op: prop, donnees: args[0] });
          }
          return proxy;
        };
      },
    });
    return proxy;
  };

  const repondre = (nom, chaine) => {
    if (chaine.some((c) => ['insert', 'update', 'upsert', 'delete'].includes(c.op))) {
      return { data: null, error: null };
    }
    if (nom === 'partner_catalog_import_runs') return { data: etat.run, error: null };
    if (nom === 'partner_catalog_sources') return { data: etat.source, error: null };
    if (nom === 'oai_harvest_state') return { data: etat.state, error: null };
    if (nom === 'partner_catalog_staging_rows') return { data: etat.rowsExistantes ?? [], error: null };
    return { data: null, error: null };
  };

  const client = (schema) => ({
    schema: (s) => client(s),
    from: (nom) => table(schema, nom),
    rpc: (nom, args) => {
      ecrits.push({ schema, table: `rpc:${nom}`, op: 'rpc', donnees: args });
      return Promise.resolve({ data: { ok: true }, error: null });
    },
  });

  let handler = null;
  const DenoStub = { env: { get: (k) => ENV[k] }, serve: (h) => { handler = h; } };
  let i = 0;
  const fetchStub = async (url, options) => {
    urlsVues.push(String(url));
    entetesVues.push(options?.headers ?? {});
    const r = reponses[Math.min(i, reponses.length - 1)];
    i += 1;
    if (r instanceof Error) throw r;
    if (typeof r === 'object' && r.status) {
      return new Response(r.body ?? '', { status: r.status, headers: r.headers ?? {} });
    }
    return new Response(r, { status: 200 });
  };
  const requireStub = (spec) => {
    if (spec.includes('supabase-js')) return { createClient: () => client('public') };
    if (spec.endsWith('marc.ts')) return evaluer(cjs(MARC), {});
    if (spec.endsWith('oai.ts')) return evaluer(cjs(OAI), {});
    // Le vrai module, pas un stub : son repli sur SUPABASE_SERVICE_ROLE_KEY
    // (seule cle presente dans l'ENV du banc) doit rester exerce.
    if (spec.endsWith('secret-key.ts')) return evaluer(cjs(CLE), {});
    if (spec.includes('edge-runtime.d.ts')) return {};
    throw new Error(`import inattendu : ${spec}`);
  };

  function evaluer(code, extra) {
    const mod = { exports: {} };
    new Function('require', 'module', 'exports', 'Deno', 'fetch', code)(
      requireStub, mod, mod.exports, DenoStub, fetchStub, extra,
    );
    return mod.exports;
  }

  evaluer(cjs(SRC), {});
  if (!handler) throw new Error("Deno.serve n'a pas été appelé : l'EF n'a pas démarré");

  return async function appeler(corps = { run_id: 19 }, { secret = SECRET } = {}) {
    ecrits.length = 0;
    urlsVues.length = 0;
    entetesVues.length = 0;
    const res = await handler(new Request('http://ef.local/', {
      method: 'POST',
      headers: { 'x-import-secret': secret, 'content-type': 'application/json' },
      body: JSON.stringify(corps),
    }));
    const rendu = await res.json().catch(() => ({}));
    return {
      statut: res.status, corps: rendu, ecrits: [...ecrits],
      urls: [...urlsVues], entetes: [...entetesVues],
    };
  };
}

const etatNeuf = (over = {}) => ({
  run: { id: 19, source_id: 23, detected_format: 'oai_pmh', library_id: 'lib-1', error_log: [] },
  source: { id: 23, oai_endpoint_url: 'https://entrepot.invalid/oai', oai_metadata_prefix: 'marcxml', oai_set: null },
  state: {
    source_id: 23, harvest_status: 'in_progress', lots_per_cycle: 3,
    pending_resumption_token: null, last_harvest_at: null, total_records_harvested: 0,
  },
  rowsExistantes: [],
  ...over,
});

// Dernière écriture sur oai_harvest_state = celle du `finally`, donc l'état
// dans lequel le verrou est laissé.
const verrou = (ecrits) => {
  const w = ecrits.filter((e) => e.table === 'oai_harvest_state' && e.op === 'update');
  return w.length ? w[w.length - 1].donnees : null;
};
const lignesInserees = (ecrits) => ecrits
  .filter((e) => e.table === 'partner_catalog_staging_rows' && e.op === 'insert')
  .flatMap((e) => e.donnees);
const majRun = (ecrits) => ecrits
  .filter((e) => e.table === 'partner_catalog_import_runs' && e.op === 'update')
  .map((e) => e.donnees);

// ── Tests ─────────────────────────────────────────────────────────────────

describe("l'EF reste fermée sans l'en-tête x-import-secret", () => {
  it("un secret faux ne fait rien démarrer, et ne touche pas au verrou", async () => {
    const appeler = monterEF(etatNeuf(), [listRecords([])]);
    const r = await appeler({ run_id: 19 }, { secret: 'pas-le-bon' });
    expect(r.statut).toBe(401);
    expect(r.ecrits).toEqual([]);
  });
});

describe('T1 — un moissonnage nominal ramène les notices ET relâche le verrou', () => {
  it('deux notices MARCXML, run prêt à revoir, verrou sur completed', async () => {
    const appeler = monterEF(etatNeuf(), [
      listRecords([recMarc('oai:x:1', 'A Conquista do Pao', 'edicao de teste', '9788575591234'),
        recMarc('oai:x:2', 'Palavras de um Revoltado', null, null)], null, 2),
    ]);
    const r = await appeler();
    expect(r.statut).toBe(200);
    expect(r.corps.ok).toBe(true);
    expect(r.corps.inserted_rows).toBe(2);
    expect(r.corps.harvest_complete).toBe(true);

    const v = verrou(r.ecrits);
    expect(v).not.toBeNull();
    expect(v.harvest_status).toBe('completed');       // ← le verrou est RELÂCHÉ
    expect(v.pending_resumption_token).toBeNull();
    expect(v.last_error).toBeNull();
    expect(v.total_records_harvested).toBe(2);
    expect(v.last_harvest_at).toBeTruthy();

    expect(majRun(r.ecrits).some((u) => u.run_status === 'ready_for_review')).toBe(true);
    expect(r.ecrits.some((e) => e.table === 'rpc:fn_match_partner_catalog_run')).toBe(true);
  });
});

describe("T2 — les <record> MARC imbriqués dans les <record> OAI sont lus deux fois, pas une fois à cheval", () => {
  it('deux notices distinctes, titres et clés externes justes', async () => {
    const appeler = monterEF(etatNeuf(), [
      listRecords([recMarc('oai:x:1', 'A Conquista do Pao', 'edicao de teste', '9788575591234'),
        recMarc('oai:x:2', 'Palavras de um Revoltado', null, null)]),
    ]);
    const lignes = lignesInserees((await appeler()).ecrits);
    expect(lignes).toHaveLength(2);
    expect(lignes.map((l) => l.title)).toEqual(['A Conquista do Pao', 'Palavras de um Revoltado']);
    expect(lignes[0].subtitle).toBe('edicao de teste');
    expect(lignes[0].isbn).toBe('9788575591234');
    // L'identifiant OAI de l'en-tête prime sur la zone de contrôle MARC (001) :
    // c'est lui qui est stable d'un moissonnage à l'autre.
    expect(lignes.map((l) => l.external_key)).toEqual(['oai:x:1', 'oai:x:2']);
    // Et la notice n'arrive JAMAIS pré-rapprochée : c'est le moteur qui décide.
    expect(lignes.every((l) => l.match_status === 'unreviewed')).toBe(true);
  });
});

describe('T3 — la reprise par resumptionToken respecte lots_per_cycle', () => {
  it('trois lots demandés, trois lots pris, jeton restant conservé et verrou sur paused', async () => {
    const appeler = monterEF(etatNeuf(), [
      listRecords([recMarc('oai:x:1', 'Un', null, null)], 'tok-1', 9),
      listRecords([recMarc('oai:x:2', 'Deux', null, null)], 'tok-2'),
      listRecords([recMarc('oai:x:3', 'Trois', null, null)], 'tok-3'),
      listRecords([recMarc('oai:x:4', 'Quatre', null, null)], null),
    ]);
    const r = await appeler();
    expect(r.corps.lots_harvested).toBe(3);          // pas 4 : lots_per_cycle=3
    expect(r.corps.inserted_rows).toBe(3);
    expect(r.corps.harvest_complete).toBe(false);
    expect(r.corps.complete_list_size).toBe(9);

    const v = verrou(r.ecrits);
    expect(v.harvest_status).toBe('paused');          // relâché, mais pas fini
    expect(v.pending_resumption_token).toBe('tok-3');
    // last_harvest_at ne doit PAS avancer sur un cycle partiel, sinon le
    // prochain from= sauterait tout ce que le jeton n'a pas encore rendu.
    expect(v.last_harvest_at).toBeUndefined();

    // Avec un jeton, la norme impose verb + resumptionToken et RIEN d'autre.
    expect(r.urls[1]).toContain('resumptionToken=tok-1');
    expect(r.urls[1]).not.toContain('metadataPrefix');
  });
});

describe('T4 — le préfixe est négocié quand celui demandé n’est pas servi', () => {
  it('cannotDisseminateFormat → ListMetadataFormats → oai_dc, et la source est mise à jour', async () => {
    const appeler = monterEF(etatNeuf(), [
      erreurOai('cannotDisseminateFormat', 'marcxml inconnu'),
      listFormats(['oai_dc']),
      listRecords([recDc('oai:d:1', 'A Conquista do Pao : edicao de teste')]),
    ]);
    const r = await appeler();
    expect(r.statut).toBe(200);
    expect(r.corps.prefix_negotiated).toBe(true);
    expect(r.corps.oai_metadata_prefix).toBe('oai_dc');
    expect(r.urls[1]).toContain('verb=ListMetadataFormats');

    // Le préfixe négocié est écrit sur la source : la négociation ne se rejoue
    // pas à chaque cycle, et l'écran montre ce qui est vraiment servi.
    const majSrc = r.ecrits.filter((e) => e.table === 'partner_catalog_sources' && e.op === 'update');
    expect(majSrc.at(-1).donnees.oai_metadata_prefix).toBe('oai_dc');

    // Le Dublin Core aboutit dans les mêmes colonnes que le MARC, et ' : '
    // (séparateur ISBD, celui que produit notre propre fournisseur) est défait.
    const l = lignesInserees(r.ecrits)[0];
    expect(l.title).toBe('A Conquista do Pao');
    expect(l.subtitle).toBe('edicao de teste');
    expect(l.isbn).toBe('9788575591234');
    expect(l.authors).toEqual(['KROPOTKIN, Piotr']);
    expect(l.publication_year).toBe('1892');
    // DC n'a pas de lieu d'édition : on rend null plutôt que d'inventer.
    expect(l.place_of_publication).toBeNull();
    expect(verrou(r.ecrits).harvest_status).toBe('completed');
  });
});

describe('T5 — une erreur OAI relâche quand même le verrou', () => {
  it('badArgument → run failed, harvest_status error, last_error renseigné', async () => {
    const appeler = monterEF(etatNeuf(), [erreurOai('badArgument', 'metadataPrefix requis')]);
    const r = await appeler();
    expect(r.statut).toBe(500);
    expect(majRun(r.ecrits).some((u) => u.run_status === 'failed')).toBe(true);

    const v = verrou(r.ecrits);
    expect(v.harvest_status).toBe('error');           // ← relâché, pas in_progress
    expect(v.last_error).toContain('badArgument');
  });
});

describe("T6 — un entrepôt injoignable relâche aussi le verrou", () => {
  it('fetch qui jette → error, et le message est conservé', async () => {
    const appeler = monterEF(etatNeuf(), [new Error('connexion refusee')]);
    const r = await appeler();
    expect(r.statut).toBe(500);
    const v = verrou(r.ecrits);
    expect(v.harvest_status).toBe('error');
    expect(v.last_error).toContain('connexion refusee');
  });
});

describe('T7 — « rien de neuf » n’est pas une panne', () => {
  it('noRecordsMatch → run prêt à revoir avec 0 ligne, verrou sur completed', async () => {
    const appeler = monterEF(etatNeuf(), [erreurOai('noRecordsMatch', 'aucune notice')]);
    const r = await appeler();
    expect(r.statut).toBe(200);
    expect(r.corps.inserted_rows).toBe(0);
    expect(r.corps.harvest_complete).toBe(true);
    expect(majRun(r.ecrits).some((u) => u.run_status === 'ready_for_review')).toBe(true);
    expect(majRun(r.ecrits).some((u) => u.run_status === 'failed')).toBe(false);
    expect(verrou(r.ecrits).harvest_status).toBe('completed');
    // Aucune ligne, donc aucun rapprochement à demander.
    expect(r.ecrits.some((e) => e.table === 'rpc:fn_match_partner_catalog_run')).toBe(false);
  });
});

describe('T8 — un jeton périmé repart de la tête de liste au lieu de bloquer la source', () => {
  it('badResumptionToken → nouvelle requête ListRecords complète', async () => {
    const etat = etatNeuf();
    etat.state.pending_resumption_token = 'tok-mort';
    const appeler = monterEF(etat, [
      erreurOai('badResumptionToken', 'jeton expire'),
      listRecords([recMarc('oai:x:1', 'Un', null, null)]),
    ]);
    const r = await appeler();
    expect(r.statut).toBe(200);
    expect(r.urls[0]).toContain('resumptionToken=tok-mort');
    expect(r.urls[1]).toContain('metadataPrefix=marcxml');
    expect(r.urls[1]).not.toContain('resumptionToken');
    expect(r.corps.inserted_rows).toBe(1);
    expect(verrou(r.ecrits).pending_resumption_token).toBeNull();
  });
});

describe('T9 — notices supprimées, vides et déjà vues sont écartées, pas insérées', () => {
  it('une supprimée + une déjà connue → une seule ligne, et le compte le dit', async () => {
    const etat = etatNeuf();
    etat.rowsExistantes = [{ row_no: 7, external_key: 'oai:x:1' }];
    const appeler = monterEF(etat, [
      listRecords([
        recMarc('oai:x:1', 'Deja vue', null, null),
        recSupprime('oai:x:9'),
        recMarc('oai:x:2', 'Nouvelle', null, null),
      ]),
    ]);
    const r = await appeler();
    expect(r.corps.deleted_skipped).toBe(1);
    expect(r.corps.duplicate_skipped).toBe(1);
    const lignes = lignesInserees(r.ecrits);
    expect(lignes).toHaveLength(1);
    expect(lignes[0].title).toBe('Nouvelle');
    // La numérotation reprend après les lignes déjà présentes dans le run.
    expect(lignes[0].row_no).toBe(8);
  });
});

describe('T10 — le moissonnage incrémental ne redemande que ce qui a bougé', () => {
  it('last_harvest_at renseigné → from= en granularité jour', async () => {
    const etat = etatNeuf();
    etat.state.last_harvest_at = '2026-08-01T12:34:56.000Z';
    const appeler = monterEF(etat, [listRecords([])]);
    const r = await appeler();
    expect(r.urls[0]).toContain('from=2026-08-01');
    expect(r.urls[0]).not.toContain('12%3A34');
  });
});

describe('T12 — un resumptionToken PRÉSENT mais VIDE veut dire « dernier lot »', () => {
  // Subtilité de la norme OAI-PMH qui coûte cher si on la rate : le dernier lot
  // d'une liste porte souvent un <resumptionToken> vide (ou auto-fermant). Ça ne
  // veut pas dire « reprends avec la chaîne vide », ça veut dire « c'était le
  // dernier ». Sans cette règle, le moissonnage redemanderait indéfiniment un
  // jeton vide — et surtout n'écrirait jamais last_harvest_at, donc chaque cycle
  // reprendrait le catalogue entier depuis le début.
  //
  // Ce test n'était pas là au premier jet : une mutation (« le jeton vide n'est
  // plus normalisé ») a survécu à la suite entière. La règle était écrite dans le
  // code et dans un commentaire, gardée par rien.
  it.each([
    ['vide', '<resumptionToken></resumptionToken>'],
    ['auto-fermant', '<resumptionToken/>'],
    ['avec attributs', '<resumptionToken completeListSize="1" cursor="0"></resumptionToken>'],
  ])('forme %s → liste terminée, un seul lot, verrou sur completed', async (_nom, jeton) => {
    const xml = enveloppe(`<ListRecords>${recMarc('oai:x:1', 'Un', null, null)}${jeton}</ListRecords>`);
    const r = await monterEF(etatNeuf(), [xml, listRecords([recMarc('oai:x:2', 'JAMAIS', null, null)])])();
    expect(r.corps.harvest_complete).toBe(true);
    expect(r.corps.lots_harvested).toBe(1);
    expect(r.urls).toHaveLength(1);                 // aucune requête de reprise
    expect(lignesInserees(r.ecrits).map((l) => l.title)).toEqual(['Un']);
    const v = verrou(r.ecrits);
    expect(v.harvest_status).toBe('completed');
    expect(v.pending_resumption_token).toBeNull();
    expect(v.last_harvest_at).toBeTruthy();
  });
});

describe('T13 — un 503 avec Retry-After tenable est HONORÉ, pas traité en panne', () => {
  // 503 et 429 sont la façon normale dont un serveur OAI-PMH dit « pas
  // maintenant » — souvent pendant qu'il prépare un gros lot. Les traiter comme
  // une panne, c'est revenir taper au même endroit au cycle suivant.
  it('attend le délai annoncé puis réessaie, et le cycle aboutit', async () => {
    const r = await monterEF(etatNeuf(), [
      { status: 503, body: '', headers: { 'Retry-After': new Date(Date.now() + 5).toUTCString() } },
      listRecords([recMarc('oai:x:1', 'Un', null, null)]),
    ])();
    expect(r.statut).toBe(200);
    expect(r.corps.inserted_rows).toBe(1);
    expect(r.urls).toHaveLength(2);          // la requête a bien été rejouée
    expect(verrou(r.ecrits).harvest_status).toBe('completed');
  });
});

describe("T14 — un back-off trop long rend la main SANS crier à la panne", () => {
  it("harvest_status=paused (pas error) et le jeton de reprise est CONSERVÉ", async () => {
    const etat = etatNeuf();
    etat.state.pending_resumption_token = 'tok-en-cours';
    const r = await monterEF(etat, [
      { status: 503, body: '', headers: { 'Retry-After': '3600' } },
    ])();

    const v = verrou(r.ecrits);
    // 'error' ferait croire à une source cassée et sortirait la biblio du cycle.
    expect(v.harvest_status).toBe('paused');
    expect(v.last_error).toMatch(/attendre/);
    // Le point le plus facile à casser : sans préservation explicite, le finally
    // reposait null et la position de reprise était perdue à chaque incident.
    expect(v.pending_resumption_token).toBe('tok-en-cours');
  });
});

describe('T15 — le moissonneur se présente avec un contact joignable', () => {
  it('User-Agent porte l’adresse fédérale (convention OAI-PMH)', async () => {
    const r = await monterEF(etatNeuf(), [listRecords([])])();
    const ua = r.entetes[0]['User-Agent'];
    expect(ua).toMatch(/^AnarBib-OAI-Harvester/);
    expect(ua).toContain('@');   // une admin d'en face peut écrire à quelqu'un
  });
});

describe('T16 — les lots ne s’enchaînent pas sans respirer', () => {
  it('une pause sépare deux requêtes consécutives', async () => {
    const debut = Date.now();
    const r = await monterEF(etatNeuf(), [
      listRecords([recMarc('oai:x:1', 'Un', null, null)], 'tok-1'),
      listRecords([recMarc('oai:x:2', 'Deux', null, null)], null),
    ])();
    const ecoule = Date.now() - debut;
    expect(r.corps.lots_harvested).toBe(2);
    // INTER_LOT_PAUSE_MS vaut 1 s ; on garde une marge pour la lenteur du CI.
    expect(ecoule).toBeGreaterThanOrEqual(900);
  });
});

describe("T11 — un run qui n'est pas un moissonnage est refusé", () => {
  it('detected_format=csv → 400, aucune ligne insérée', async () => {
    const etat = etatNeuf();
    etat.run.detected_format = 'csv';
    const r = await monterEF(etat, [listRecords([])])();
    expect(r.statut).toBe(400);
    expect(lignesInserees(r.ecrits)).toHaveLength(0);
    // Et surtout : on ne touche PAS au verrou d une source dont ce run ne parle
    // pas. fn_import_harvest_oai n en a pose aucun pour un run qui n est pas un
    // moissonnage ; ecrire error ici abimerait l etat d une source saine.
    expect(verrou(r.ecrits)).toBeNull();
  });
});
