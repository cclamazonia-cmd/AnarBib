// ═══════════════════════════════════════════════════════════
// AnarBib — B45 (13/10/2026) : une adresse DONNÉE PAR L'APPELANT ne mène
// jamais le serveur vers un réseau interne.
//
// cover_lookup (`pdf`, `store`, aperçus d'une og:image) et fetch-url-metadata
// vont chercher des adresses fournies par le navigateur ou trouvées dans une
// page tierce. Jusqu'ici : fetch-url-metadata sans aucune garde ; cover_lookup
// avec une garde sur le NOM écrit dans l'adresse seulement. Trois façons de
// passer à côté d'une garde de nom :
//   1. une redirection : une page publique répond 302 vers http://10.0.0.5/ —
//      `redirect: 'follow'` la suivait sans rien revérifier ;
//   2. un nom qui SE RÉSOUT en adresse privée (un domaine pointé sur 127.0.0.1,
//      ou, sur une pile auto-hébergée, un nom d'une seule étiquette comme
//      `kong`, `db`, `rest`, que le réseau Docker résout) ;
//   3. une adresse écrite autrement : IPv6 qui embarque une IPv4
//      (`[::ffff:7f00:1]`), plages oubliées (100.64/10, 198.18/15…).
// D'où : chaque saut est vérifié (redirections suivies à la main, cinq au
// plus), le nom est résolu (A et AAAA) et TOUTES ses adresses doivent être
// publiques. Échec fermé : un nom qui ne se résout pas, ou une résolution
// indisponible, refuse.
//
// Reste hors d'atteinte : la re-résolution entre notre vérification et la
// connexion de fetch (rebinding DNS à TTL nul). Il faudrait se connecter à
// l'adresse vérifiée elle-même, ce que fetch ne permet pas en TLS.
//
// Éprouvé le 13/10 dans edge-runtime v1.77.1 (l'image de la pile) :
// Deno.resolveDns répond (A, AAAA, NotFound propre) et `redirect: 'manual'`
// rend le 3xx avec son Location.
//
// Sans dépendance à Deno : chargé tel quel par vitest
// (src/tests/adresse-sortante.test.js), résolveur et fetch injectables.
// ═══════════════════════════════════════════════════════════

export class AdresseRefusee extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AdresseRefusee';
  }
}

// ── Adresses IP ─────────────────────────────────────────────────────────────

function octetsIpv4(ip: string): number[] | null {
  const m = ip.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (!m) return null;
  const o = m.slice(1).map(Number);
  return o.every((x) => x <= 255) ? o : null;
}

function ipv4Interdite([a, b, c]: number[]): boolean {
  return a === 0                                   // « ce réseau »
    || a === 10                                    // privé
    || (a === 100 && b >= 64 && b <= 127)          // CGNAT
    || a === 127                                   // boucle locale
    || (a === 169 && b === 254)                    // lien local (métadonnées de nuage)
    || (a === 172 && b >= 16 && b <= 31)           // privé
    || (a === 192 && b === 0 && (c === 0 || c === 2))  // IETF, documentation
    || (a === 192 && b === 88 && c === 99)         // relais 6to4
    || (a === 192 && b === 168)                    // privé
    || (a === 198 && (b === 18 || b === 19))       // bancs d'essai
    || (a === 198 && b === 51 && c === 100)        // documentation
    || (a === 203 && b === 0 && c === 113)         // documentation
    || a >= 224;                                   // multidiffusion, réservé, diffusion
}

/** Les huit groupes de 16 bits d'une IPv6 (forme compacte ou IPv4 finale admises), ou null. */
function groupesIpv6(ip: string): number[] | null {
  let s = ip.toLowerCase();
  const pct = s.indexOf('%');
  if (pct >= 0) s = s.slice(0, pct);               // zone (fe80::1%eth0)
  let fin: number[] = [];
  const v4 = s.match(/^(.*:)(\d{1,3}(?:\.\d{1,3}){3})$/);
  if (v4) {
    const o = octetsIpv4(v4[2]);
    if (!o) return null;
    fin = [(o[0] << 8) | o[1], (o[2] << 8) | o[3]];
    s = v4[1].endsWith('::') ? v4[1] : v4[1].slice(0, -1);
  }
  const parties = s.split('::');
  if (parties.length > 2) return null;
  const lire = (x: string) => (x ? x.split(':') : []);
  const tete = lire(parties[0]);
  const queue = parties.length === 2 ? lire(parties[1]) : [];
  const total = tete.length + queue.length + fin.length;
  if (parties.length === 1 ? total !== 8 : total > 7) return null;
  const hex = [...tete, ...Array(8 - total).fill('0'), ...queue];
  if (parties.length === 1 && tete.length + fin.length !== 8) return null;
  const g = hex.map((h) => (/^[0-9a-f]{1,4}$/.test(h) ? parseInt(h, 16) : NaN));
  if (g.some(Number.isNaN)) return null;
  return [...g, ...fin];
}

function ipv6Interdite(g: number[]): boolean {
  const v4 = (h: number, l: number) => [h >> 8, h & 255, l >> 8, l & 255];
  if (g.slice(0, 6).every((x) => x === 0)) return true;               // ::, ::1, ::a.b.c.d (compatible, obsolète)
  if (g.slice(0, 5).every((x) => x === 0) && g[5] === 0xffff) return ipv4Interdite(v4(g[6], g[7]));  // ::ffff:a.b.c.d
  if (g[0] === 0x64 && g[1] === 0xff9b) return ipv4Interdite(v4(g[6], g[7]));  // NAT64 64:ff9b::/96
  if (g[0] === 0x2002) return ipv4Interdite(v4(g[1], g[2]));         // 6to4
  if ((g[0] & 0xfe00) === 0xfc00) return true;                         // fc00::/7, adresses locales uniques
  if ((g[0] & 0xffc0) === 0xfe80) return true;                         // fe80::/10, lien local
  if ((g[0] & 0xff00) === 0xff00) return true;                         // multidiffusion
  if (g[0] === 0x2001 && g[1] === 0x0db8) return true;                 // documentation
  if (g[0] === 0x0100 && g[1] === 0 && g[2] === 0 && g[3] === 0) return true;  // 100::/64, rejet
  return false;
}

/** Vrai pour toute adresse IP qui n'est pas publique. Une chaîne illisible est refusée. */
export function ipInterdite(ip: string): boolean {
  const s = String(ip || '').trim().replace(/^\[|\]$/g, '');
  const o = octetsIpv4(s);
  if (o) return ipv4Interdite(o);
  const g = groupesIpv6(s);
  return g ? ipv6Interdite(g) : true;
}

// ── Noms ────────────────────────────────────────────────────────────────────

const SUFFIXES_LOCAUX = ['.localhost', '.local', '.internal', '.lan', '.home.arpa', '.arpa', '.intranet', '.corp', '.localdomain'];

function estIpLitterale(h: string): boolean {
  return /^\d{1,3}(\.\d{1,3}){3}$/.test(h) || h.includes(':');
}

/**
 * Vrai quand le nom d'hôte, tel qu'écrit dans l'adresse, est refusé sans même
 * le résoudre : IP non publique, nom local, ou nom d'une seule étiquette (que
 * seul un réseau interne sait résoudre — `kong`, `db` sur la pile Docker).
 */
export function hoteInterdit(hote: string): boolean {
  const h = String(hote || '').toLowerCase().replace(/^\[|\]$/g, '').replace(/\.$/, '');
  if (!h) return true;
  if (estIpLitterale(h)) return ipInterdite(h);
  if (h === 'localhost' || !h.includes('.')) return true;
  return SUFFIXES_LOCAUX.some((s) => h.endsWith(s));
}

// ── Résolution ──────────────────────────────────────────────────────────────

export type Resolveur = (nom: string, type: 'A' | 'AAAA') => Promise<string[]>;

function resolveurParDefaut(): Resolveur | null {
  // deno-lint-ignore no-explicit-any
  const d = (globalThis as any).Deno;
  return typeof d?.resolveDns === 'function' ? (nom, type) => d.resolveDns(nom, type) : null;
}

/** Refuse (AdresseRefusee) toute adresse dont le schéma, le nom ou une adresse résolue n'est pas admis. */
export async function verifierAdresse(
  url: URL,
  protocoles: string[],
  resoudre: Resolveur | null = resolveurParDefaut(),
): Promise<void> {
  if (!protocoles.includes(url.protocol)) throw new AdresseRefusee(`Protocol not allowed: ${url.protocol}`);
  if (url.username || url.password) throw new AdresseRefusee('Credentials in URL not allowed.');
  const hote = url.hostname.toLowerCase().replace(/^\[|\]$/g, '').replace(/\.$/, '');
  if (hoteInterdit(hote)) throw new AdresseRefusee('Host not allowed.');
  if (estIpLitterale(hote)) return;
  if (!resoudre) throw new AdresseRefusee('Host cannot be checked (no resolver).');
  const reponses = await Promise.allSettled([resoudre(hote, 'A'), resoudre(hote, 'AAAA')]);
  const ips = reponses.flatMap((r) => (r.status === 'fulfilled' && Array.isArray(r.value) ? r.value : []));
  if (!ips.length) throw new AdresseRefusee('Host does not resolve.');
  if (ips.some(ipInterdite)) throw new AdresseRefusee('Host resolves to a non-public address.');
}

// ── Récupération ────────────────────────────────────────────────────────────

const REDIRECTIONS = new Set([301, 302, 303, 307, 308]);

export interface OptionsSortantes {
  protocoles?: string[];
  maxRedirections?: number;
  resoudre?: Resolveur | null;
  fetchFn?: (url: string, init: RequestInit) => Promise<Response>;
}

/**
 * GET d'une adresse donnée par l'appelant : chaque saut vérifié par
 * verifierAdresse, redirections suivies à la main (cinq au plus). Lève
 * AdresseRefusee au premier saut refusé.
 */
export async function fetchSortant(adresse: string, init: RequestInit = {}, options: OptionsSortantes = {}): Promise<Response> {
  const protocoles = options.protocoles ?? ['https:', 'http:'];
  const max = options.maxRedirections ?? 5;
  const fetchFn = options.fetchFn ?? ((u: string, i: RequestInit) => fetch(u, i));
  const resoudre = options.resoudre === undefined ? resolveurParDefaut() : options.resoudre;
  let courante: URL;
  try { courante = new URL(adresse); } catch { throw new AdresseRefusee('Invalid URL.'); }
  for (let saut = 0; ; saut++) {
    await verifierAdresse(courante, protocoles, resoudre);
    const res = await fetchFn(courante.toString(), { ...init, method: 'GET', redirect: 'manual' });
    const suivante = res.headers.get('location');
    if (!REDIRECTIONS.has(res.status) || !suivante) return res;
    await res.body?.cancel().catch(() => {});
    if (saut >= max) throw new AdresseRefusee('Too many redirects.');
    try { courante = new URL(suivante, courante); } catch { throw new AdresseRefusee('Invalid redirect.'); }
  }
}

/** Le corps, sans jamais en lire plus de `max` octets (au-delà : null, la lecture est coupée). */
export async function lireOctetsBornes(res: Response, max: number): Promise<Uint8Array | null> {
  const annonce = Number(res.headers.get('content-length'));
  if (Number.isFinite(annonce) && annonce > max) {
    await res.body?.cancel().catch(() => {});
    return null;
  }
  if (!res.body) return new Uint8Array(0);
  const lecteur = res.body.getReader();
  const morceaux: Uint8Array[] = [];
  let total = 0;
  for (;;) {
    const { done, value } = await lecteur.read();
    if (done) break;
    total += value.byteLength;
    if (total > max) {
      await lecteur.cancel().catch(() => {});
      return null;
    }
    morceaux.push(value);
  }
  const out = new Uint8Array(total);
  let pos = 0;
  for (const m of morceaux) { out.set(m, pos); pos += m.byteLength; }
  return out;
}
