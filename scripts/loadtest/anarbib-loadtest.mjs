// AnarBib — harnais de test de charge (lecture + écriture)
// Cible : projet uflwmikiyjfnikiphtcp. Écritures confinées à la biblio jetable zzz-charge-test.
// Usage : node anarbib-loadtest.mjs --vu=40 --duration=120 --write-pct=20 --label=baseline

import { setTimeout as sleep } from 'node:timers/promises';
import { writeFileSync } from 'node:fs';

const BASE = 'https://uflwmikiyjfnikiphtcp.supabase.co';
const ANON =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVmbHdtaWtpeWpmbmlraXBodGNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4MzIyNDUsImV4cCI6MjA4OTQwODI0NX0.kCs7nPg08ofjb9CWwRH9xVN6BjanrAC5pj418line1o';

const PWD = 'LoadTest!2026-Bologna';
const RUN_TAG = `LOADTEST-${Date.now()}`;

const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, v] = a.replace(/^--/, '').split('=');
    return [k, v ?? true];
  }),
);
const VU = Number(args.vu ?? 20);
const DURATION = Number(args.duration ?? 60);
const WRITE_PCT = Number(args['write-pct'] ?? 20);
const LABEL = args.label ?? 'run';
const N_ACCOUNTS = Number(args.accounts ?? 30);
// --exclude=op1,op2 : retire des opérations du mix (ex. simuler la vue lourde corrigée)
const EXCLUDE = new Set(String(args.exclude ?? '').split(',').filter(Boolean));
// UUID de la bibliothèque jetable créée par bac-a-sable.sql. Il CHANGE à chaque
// création : le passer avec --lib=..., sinon les écritures échoueront.
const TEST_LIB = args.lib || '';

// ---------------------------------------------------------------- métriques
const samples = []; // { op, ms, status, ok }
const errorBodies = {}; // "op status" -> [corps]
let stopped = false;

function record(op, ms, status, ok) {
  samples.push({ op, ms, status, ok, t: Date.now() });
}

async function timed(op, fn) {
  const t0 = performance.now();
  try {
    const res = await fn();
    const ms = performance.now() - t0;
    record(op, ms, res.status, res.ok);
    if (!res.ok) {
      const body = await res.text().catch(() => '');
      const key = `${op} ${res.status}`;
      if ((errorBodies[key] ??= []).length < 3) errorBodies[key].push(body.slice(0, 220));
      return { ok: false, status: res.status, body: body.slice(0, 200) };
    }
    // vider le corps pour libérer la connexion
    await res.arrayBuffer().catch(() => {});
    return { ok: true, status: res.status };
  } catch (e) {
    const ms = performance.now() - t0;
    record(op, ms, 0, false);
    return { ok: false, status: 0, body: String(e.message ?? e).slice(0, 200) };
  }
}

// ---------------------------------------------------------------- auth
async function login(i) {
  const email = `loadtest-${String(i).padStart(2, '0')}@loadtest.invalid`;
  const r = await fetch(`${BASE}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { apikey: ANON, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: PWD }),
  });
  if (!r.ok) throw new Error(`login ${email}: ${r.status} ${(await r.text()).slice(0, 200)}`);
  const j = await r.json();
  return { email, token: j.access_token, userId: j.user.id, role: i <= 6 ? 'librarian' : 'reader' };
}

// ---------------------------------------------------------------- opérations
const H_ANON = { apikey: ANON, Authorization: `Bearer ${ANON}` };
const hAuth = (tok) => ({ apikey: ANON, Authorization: `Bearer ${tok}` });

const SEARCH_TERMS = [
  'anarchisme', 'bakounine', 'kropotkine', 'liberté', 'malatesta', 'commune',
  'syndicalisme', 'autogestion', 'proudhon', 'goldman', 'revolution', 'ferrer',
];
const pick = (a) => a[Math.floor(Math.random() * a.length)];

// -- lectures anonymes (le gros du trafic d'une rencontre publique)
const READS_ANON = [
  {
    name: 'catalog_search',
    run: () =>
      fetch(`${BASE}/rest/v1/rpc/catalog_search_ids_v1`, {
        method: 'POST',
        headers: { ...H_ANON, 'Content-Type': 'application/json', 'Accept-Profile': 'api', 'Content-Profile': 'api' },
        body: JSON.stringify({ p_q: pick(SEARCH_TERMS) }),
      }),
  },
  {
    name: 'catalog_facets',
    run: () =>
      fetch(`${BASE}/rest/v1/rpc/catalog_facets_v1`, {
        method: 'POST',
        headers: { ...H_ANON, 'Content-Type': 'application/json', 'Accept-Profile': 'api', 'Content-Profile': 'api' },
        body: JSON.stringify({ p_filters: {} }),
      }),
  },
  {
    name: 'subject_tree',
    run: () =>
      fetch(`${BASE}/rest/v1/rpc/subject_tree_v1`, {
        method: 'POST',
        headers: { ...H_ANON, 'Content-Type': 'application/json', 'Accept-Profile': 'api', 'Content-Profile': 'api' },
        body: JSON.stringify({}),
      }),
  },
  // NB : v_book_detail_public_v2 renvoie 401 à anon (cf. rapport) — le vrai chemin
  // anonyme effectif est le repli sur `books` de BookPage.jsx:151. C'est lui qu'on mesure.
  {
    name: 'catalog_list',
    run: () =>
      fetch(
        `${BASE}/rest/v1/books?select=id,titulo,autor,ano&limit=24&offset=${Math.floor(Math.random() * 40) * 24}`,
        { headers: H_ANON },
      ),
  },
  {
    name: 'book_detail',
    run: (ctx) =>
      fetch(`${BASE}/rest/v1/books?select=*&id=eq.${pick(ctx.bookIds)}&limit=1`, { headers: H_ANON }),
  },
  {
    name: 'similar_books',
    run: (ctx) =>
      fetch(`${BASE}/rest/v1/rpc/similar_books`, {
        method: 'POST',
        headers: { ...H_ANON, 'Content-Type': 'application/json', 'Accept-Profile': 'api', 'Content-Profile': 'api' },
        body: JSON.stringify({ p_book_id: pick(ctx.bookIds) }),
      }),
  },
  {
    name: 'public_libraries',
    run: () => fetch(`${BASE}/rest/v1/public_libraries?select=*`, { headers: { ...H_ANON, 'Accept-Profile': 'api' } }),
  },
];

// -- lectures authentifiées (usager connecté)
const READS_AUTH = [
  {
    name: 'my_library_context',
    run: (ctx, u) =>
      fetch(`${BASE}/rest/v1/my_library_context?select=*`, {
        headers: { ...hAuth(u.token), 'Accept-Profile': 'api' },
      }),
  },
  {
    name: 'my_access',
    run: (ctx, u) =>
      fetch(`${BASE}/rest/v1/my_access?select=*`, { headers: { ...hAuth(u.token), 'Accept-Profile': 'api' } }),
  },
  {
    name: 'book_detail_auth',
    run: (ctx, u) =>
      fetch(`${BASE}/rest/v1/v_book_detail_public_v2?select=*&book_id=eq.${pick(ctx.bookIds)}&limit=1`, {
        headers: hAuth(u.token),
      }),
  },
  // variante : même donnée, via une fonction (plan mis en cache par connexion)
  {
    name: 'book_detail_rpc',
    run: (ctx, u) =>
      fetch(`${BASE}/rest/v1/rpc/zz_test_book_detail`, {
        method: 'POST',
        headers: { ...hAuth(u.token), 'Content-Type': 'application/json', 'Accept-Profile': 'api', 'Content-Profile': 'api' },
        body: JSON.stringify({ p_book_id: pick(ctx.bookIds) }),
      }),
  },
];

// -- écritures (confinées : wishlist = par usager ; book_drafts = biblio jetable)
const WRITES = [
  {
    name: 'w_wishlist',
    weight: 6,
    run: (ctx, u) =>
      fetch(`${BASE}/rest/v1/user_wishlist?on_conflict=user_id,book_id`, {
        method: 'POST',
        headers: {
          ...hAuth(u.token),
          'Content-Type': 'application/json',
          Prefer: 'resolution=merge-duplicates,return=minimal',
        },
        body: JSON.stringify({ user_id: u.userId, book_id: pick(ctx.bookIds) }),
      }),
  },
  {
    name: 'w_book_draft',
    weight: 4,
    staffOnly: true,
    run: (ctx, u) =>
      fetch(`${BASE}/rest/v1/book_drafts`, {
        method: 'POST',
        headers: { ...hAuth(u.token), 'Content-Type': 'application/json', Prefer: 'return=minimal' },
        body: JSON.stringify({
          titulo: `${RUN_TAG} ${pick(SEARCH_TERMS)} ${Math.random().toString(36).slice(2, 8)}`,
          autor: 'Charge Test',
          ano: '2026',
          editora: 'Test de charge',
          idioma: 'fr',
          status: 'draft',
          action: 'create',
          owner_library_id: TEST_LIB,
          holder_library_id: TEST_LIB,
          created_by: u.userId,
          notas: RUN_TAG,
        }),
      }),
  },
];

// ---------------------------------------------------------------- boucle VU
const readsAnon = READS_ANON.filter((o) => !EXCLUDE.has(o.name));
const readsAuth = READS_AUTH.filter((o) => !EXCLUDE.has(o.name));

async function virtualUser(ctx, u, endAt) {
  while (Date.now() < endAt && !stopped) {
    const roll = Math.random() * 100;
    if (roll < WRITE_PCT) {
      const pool = WRITES.filter((w) => (!w.staffOnly || u.role === 'librarian') && !EXCLUDE.has(w.name));
      const total = pool.reduce((s, w) => s + w.weight, 0);
      let r = Math.random() * total;
      const op = pool.find((w) => (r -= w.weight) <= 0) ?? pool[0];
      await timed(op.name, () => op.run(ctx, u));
    } else if (roll < WRITE_PCT + 15 && readsAuth.length) {
      const op = pick(readsAuth);
      await timed(op.name, () => op.run(ctx, u));
    } else {
      const op = pick(readsAnon);
      await timed(op.name, () => op.run(ctx, u));
    }
    // temps de réflexion humain : 200-700 ms
    await sleep(200 + Math.random() * 500);
  }
}

// ---------------------------------------------------------------- rapport
function pct(arr, p) {
  if (!arr.length) return 0;
  const s = [...arr].sort((a, b) => a - b);
  return s[Math.min(s.length - 1, Math.floor((p / 100) * s.length))];
}

function report() {
  const byOp = {};
  for (const s of samples) {
    (byOp[s.op] ??= []).push(s);
  }
  const rows = Object.entries(byOp)
    .map(([op, ss]) => {
      const ms = ss.map((x) => x.ms);
      const errs = ss.filter((x) => !x.ok);
      const codes = {};
      for (const e of errs) codes[e.status] = (codes[e.status] ?? 0) + 1;
      return {
        op,
        n: ss.length,
        err: errs.length,
        errPct: ((errs.length / ss.length) * 100).toFixed(1),
        p50: Math.round(pct(ms, 50)),
        p95: Math.round(pct(ms, 95)),
        p99: Math.round(pct(ms, 99)),
        max: Math.round(Math.max(...ms)),
        codes: Object.entries(codes).map(([c, n]) => `${c}×${n}`).join(' ') || '-',
      };
    })
    .sort((a, b) => b.n - a.n);

  const all = samples.map((s) => s.ms);
  const allErr = samples.filter((s) => !s.ok);
  const wall = (Math.max(...samples.map((s) => s.t)) - Math.min(...samples.map((s) => s.t))) / 1000;

  console.log(`\n===== ${LABEL} — ${VU} VU, ${DURATION}s, ${WRITE_PCT}% écritures =====`);
  console.table(rows);
  console.log(
    `TOTAL: ${samples.length} req | ${(samples.length / wall).toFixed(1)} req/s | ` +
      `erreurs ${allErr.length} (${((allErr.length / samples.length) * 100).toFixed(2)}%) | ` +
      `p50 ${Math.round(pct(all, 50))}ms  p95 ${Math.round(pct(all, 95))}ms  p99 ${Math.round(pct(all, 99))}ms`,
  );

  const codes = {};
  for (const e of allErr) codes[e.status] = (codes[e.status] ?? 0) + 1;
  if (allErr.length) console.log('Codes d\'erreur:', codes);
  for (const [k, v] of Object.entries(errorBodies)) {
    console.log(`  [${k}] ${v[0]}`);
  }

  writeFileSync(
    `${LABEL}-result.json`,
    JSON.stringify({ label: LABEL, vu: VU, duration: DURATION, writePct: WRITE_PCT, runTag: RUN_TAG, rows, total: samples.length, errors: allErr.length, codes }, null, 2),
  );
}

// ---------------------------------------------------------------- main
(async () => {
  process.on('SIGINT', () => {
    stopped = true;
  });

  console.log(`[${LABEL}] connexion de ${N_ACCOUNTS} comptes de test…`);
  const users = [];
  for (let i = 1; i <= N_ACCOUNTS; i++) {
    try {
      users.push(await login(i));
    } catch (e) {
      console.error('  échec:', e.message);
    }
    await sleep(120); // ne pas déclencher le rate-limit GoTrue
  }
  console.log(`  ${users.length} jetons obtenus (${users.filter((u) => u.role === 'librarian').length} catalogueurs)`);
  if (!users.length) process.exit(1);

  // jeu d'ID de livres réels pour des lectures représentatives
  const br = await fetch(`${BASE}/rest/v1/books?select=id&limit=300`, { headers: H_ANON });
  const bookIds = (await br.json()).map((b) => b.id);
  console.log(`  ${bookIds.length} livres pour l'échantillonnage des lectures`);
  const ctx = { bookIds };

  console.log(`[${LABEL}] démarrage: ${VU} VU pendant ${DURATION}s (tag ${RUN_TAG})`);
  const endAt = Date.now() + DURATION * 1000;
  const vus = [];
  for (let i = 0; i < VU; i++) {
    vus.push(virtualUser(ctx, users[i % users.length], endAt));
    await sleep(50); // montée en charge progressive
  }
  await Promise.all(vus);
  report();
})();
