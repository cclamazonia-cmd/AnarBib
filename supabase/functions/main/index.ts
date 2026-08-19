// =============================================================================
// AnarBib — routeur `main` des Edge Functions (auto-hébergé)
// =============================================================================
// Sur la plateforme Supabase, chaque fonction est déployée séparément et la
// plateforme applique le `verify_jwt` déclaré dans `supabase/config.toml`.
// Hors plateforme, `edge-runtime` ne fait rien de tout ça : il passe TOUTES les
// requêtes à un service unique. Ce fichier est ce service.
//
// Ses trois responsabilités, dans l'ordre d'importance :
//   1. rejouer la politique d'authentification de `config.toml` ;
//   2. refuser ce qui n'existe pas ;
//   3. déléguer à la bonne fonction.
//
// PRINCIPE DIRECTEUR : refus par défaut.
// `config.toml` ne déclare que les fonctions DISPENSÉES de JWT (28 sur 44, et
// aucune déclaration `verify_jwt = true` — les autres reposent sur le défaut).
// On lit donc la liste des dispenses, et TOUT le reste exige un JWT valide.
// Une fonction nouvelle, ou oubliée, ou mal orthographiée, est protégée —
// jamais ouverte.
//
// FAIL CLOSED : si `config.toml` est illisible, le routeur REFUSE de démarrer.
// Mieux vaut une panne franche au déploiement qu'une ouverture silencieuse.
// =============================================================================

import { jwtVerify } from 'https://esm.sh/jose@5.9.6';

const FUNCTIONS_ROOT = '/home/deno/functions';
const CONFIG_PATH = Deno.env.get('ANARBIB_CONFIG_PATH') ?? '/home/deno/config.toml';

const JWT_SECRET = Deno.env.get('SUPABASE_JWT_SECRET') ?? Deno.env.get('JWT_SECRET') ?? '';
if (!JWT_SECRET) {
  throw new Error('[main] SUPABASE_JWT_SECRET absent — refus de démarrer.');
}
const JWT_KEY = new TextEncoder().encode(JWT_SECRET);

// --- Lecture de la politique -------------------------------------------------
// Parse minimal et volontairement strict : on ne cherche que les blocs
// [functions.<nom>] suivis d'un verify_jwt. Toute autre clé est ignorée.
function loadJwtExemptions(tomlText: string): Set<string> {
  const exempt = new Set<string>();
  let current: string | null = null;

  for (const rawLine of tomlText.split('\n')) {
    const line = rawLine.trim();
    if (line.startsWith('#')) continue;                    // commentaire

    const header = line.match(/^\[functions\.([A-Za-z0-9_-]+)\]$/);
    if (header) { current = header[1]; continue; }
    if (line.startsWith('[')) { current = null; continue; } // autre section

    if (current) {
      const kv = line.match(/^verify_jwt\s*=\s*(true|false)\s*$/);
      if (kv && kv[1] === 'false') exempt.add(current);
    }
  }
  return exempt;
}

let JWT_EXEMPT: Set<string>;
try {
  JWT_EXEMPT = loadJwtExemptions(Deno.readTextFileSync(CONFIG_PATH));
} catch (err) {
  // Pas de repli permissif. On s'arrête.
  throw new Error(`[main] config.toml illisible (${CONFIG_PATH}) : ${err}. Refus de démarrer.`);
}
console.log(`[main] ${JWT_EXEMPT.size} fonction(s) dispensée(s) de JWT ; toutes les autres l'exigent.`);

// --- Inventaire des fonctions présentes sur le disque ------------------------
// Évite qu'un nom inventé serve de sonde (on répond 404 sans rien exécuter).
const AVAILABLE = new Set<string>();
for (const entry of Deno.readDirSync(FUNCTIONS_ROOT)) {
  if (entry.isDirectory && !entry.name.startsWith('_') && entry.name !== 'main') {
    AVAILABLE.add(entry.name);
  }
}
console.log(`[main] ${AVAILABLE.size} fonction(s) montée(s).`);

// Garde-fou de cohérence : une dispense qui ne correspond à aucune fonction
// signale une dérive entre config.toml et le dépôt. On le dit, sans bloquer.
for (const name of JWT_EXEMPT) {
  if (!AVAILABLE.has(name)) {
    console.warn(`[main] AVERTISSEMENT : config.toml dispense « ${name} », absente du disque.`);
  }
}

// --- Réponses ----------------------------------------------------------------
const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8' },
  });

// CORS : le front appelle certaines fonctions directement depuis le navigateur.
// À restreindre au domaine réel du front via ALLOWED_ORIGIN.
const ALLOWED_ORIGIN = Deno.env.get('ALLOWED_ORIGIN') ?? '*';
const CORS_HEADERS = {
  'access-control-allow-origin': ALLOWED_ORIGIN,
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type, x-webhook-secret',
  'access-control-allow-methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'access-control-max-age': '86400',
};

// --- Vérification du JWT -----------------------------------------------------
async function hasValidJwt(req: Request): Promise<boolean> {
  const header = req.headers.get('authorization') ?? '';
  const token = header.toLowerCase().startsWith('bearer ') ? header.slice(7).trim() : '';
  if (!token) return false;
  try {
    // jwtVerify contrôle la signature ET l'expiration.
    await jwtVerify(token, JWT_KEY, { algorithms: ['HS256'] });
    return true;
  } catch {
    return false;
  }
}

// --- Boucle principale -------------------------------------------------------
Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  const url = new URL(req.url);
  // Caddy retire déjà le préfixe /functions/v1 ; on tolère les deux formes.
  const segments = url.pathname.split('/').filter(Boolean);
  if (segments[0] === 'functions' && segments[1] === 'v1') segments.splice(0, 2);
  const name = segments[0] ?? '';

  if (!name || !AVAILABLE.has(name)) {
    return json(404, { error: 'not_found' });   // pas de détail : rien à sonder
  }

  // ---- LA décision de sécurité ----------------------------------------------
  if (!JWT_EXEMPT.has(name) && !(await hasValidJwt(req))) {
    return json(401, { error: 'unauthorized' });
  }
  // Note : les fonctions dispensées portent LEUR PROPRE contrôle
  // (`x-webhook-secret` pour les notifieurs, gate applicatif pour l'OAI-PMH).
  // Le routeur ne s'y substitue pas — il se contente de ne pas exiger de JWT.

  try {
    const worker = await EdgeRuntime.userWorkers.create({
      servicePath: `${FUNCTIONS_ROOT}/${name}`,
      memoryLimitMb: Number(Deno.env.get('WORKER_MEMORY_MB') ?? 256),
      workerTimeoutMs: Number(Deno.env.get('WORKER_TIMEOUT_MS') ?? 300_000),
      noModuleCache: false,
      envVars: Object.entries(Deno.env.toObject()),
    });
    const res = await worker.fetch(req);

    const headers = new Headers(res.headers);
    for (const [k, v] of Object.entries(CORS_HEADERS)) headers.set(k, v);
    return new Response(res.body, { status: res.status, headers });
  } catch (err) {
    console.error(`[main] échec de « ${name} » :`, err);
    return json(500, { error: 'function_error' });
  }
});
