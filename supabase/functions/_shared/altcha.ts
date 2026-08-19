// ═══════════════════════════════════════════════════════════════════════════
// AnarBib — Altcha : émission et vérification, sans aucune dépendance
// ═══════════════════════════════════════════════════════════════════════════
//
// Remplace Cloudflare Turnstile sur `register` et `submit-cartography-entry`.
// Cf. docs/journal/arbitrages/DECISION_anti_robots_2026-08-20.md (AR-3, AR-4).
//
// AUCUN APPEL SORTANT. Le serveur émet un défi signé, le navigateur le résout
// par force brute, le serveur vérifie la signature et la solution. Personne
// d'autre n'est dans la boucle — c'est tout l'intérêt par rapport à Turnstile.
//
// POURQUOI PAS LE PAQUET OFFICIEL. Le widget d'Altcha tire un composant web
// depuis le npm d'une société commerciale, pour ce qui tient en cinquante
// lignes : une boucle de hachage. Le protocole, lui, est simple et documenté.
// On garde le mécanisme, on perd la dépendance.
//
// LE PROTOCOLE, EN QUATRE TEMPS
//   1. le serveur tire un `salt` aléatoire et un `number` secret dans [0, max] ;
//   2. il publie `challenge = sha256(salt + number)`, le `salt`, le `max`, et
//      une signature `HMAC-SHA256(challenge, secret)` ;
//   3. le navigateur essaie n = 0, 1, 2… jusqu'à retrouver le `challenge` ;
//   4. le serveur revérifie le hachage ET la signature.
//
// La signature est ce qui empêche de forger un défi facile : un attaquant peut
// résoudre n'importe quel défi, il ne peut pas en fabriquer un.
//
// ⚠️ LIMITE ASSUMÉE : Argon2 n'existe pas sous Deno, on est donc sur SHA-256.
// C'est la variante la moins coûteuse pour une ferme de calcul. La preuve de
// travail arrête le tout-venant automatisé, pas un attaquant déterminé — et
// c'est exactement ce qu'on lui demande ici.
// ═══════════════════════════════════════════════════════════════════════════

const ENC = new TextEncoder();

/** Difficulté. 300 000 hachages ≈ 0,3 s sur un ordinateur de bureau, ~1,5 s sur
 *  un téléphone ancien. Assez pour rendre le déversement de masse pénible, pas
 *  assez pour exclure quelqu'un. À NE PAS monter sans mesurer sur mobile. */
const MAX_NUMBER = 300_000;

/** Durée de validité d'un défi. Assez long pour remplir un formulaire
 *  d'inscription sans se presser, assez court pour borner la fenêtre de rejeu
 *  si jamais la table d'anti-rejeu venait à manquer. */
const TTL_SECONDES = 20 * 60;

function hex(buf: ArrayBuffer): string {
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

async function sha256Hex(s: string): Promise<string> {
  return hex(await crypto.subtle.digest('SHA-256', ENC.encode(s)));
}

async function hmacHex(message: string, secret: string): Promise<string> {
  const cle = await crypto.subtle.importKey(
    'raw', ENC.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  return hex(await crypto.subtle.sign('HMAC', cle, ENC.encode(message)));
}

/** Comparaison à durée constante : une comparaison naïve fuit, par sa durée,
 *  la longueur du préfixe correct — de quoi reconstruire une signature octet
 *  par octet. Même motif que le plancher de durée de `login`. */
function egaliteConstante(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function secret(): string {
  const s = Deno.env.get('ALTCHA_HMAC_SECRET') ?? '';
  if (s.length < 32) {
    throw new Error('ALTCHA_HMAC_SECRET absent ou trop court (32 caractères minimum)');
  }
  return s;
}

export interface DefiAltcha {
  algorithm: 'SHA-256';
  challenge: string;
  salt: string;
  signature: string;
  maxnumber: number;
}

/** Émet un défi. À servir tel quel au navigateur. */
export async function creerDefi(): Promise<DefiAltcha> {
  const alea = hex(crypto.getRandomValues(new Uint8Array(12)).buffer);
  const expire = Math.floor(Date.now() / 1000) + TTL_SECONDES;
  // L'expiration voyage DANS le sel : elle est donc couverte par la signature
  // et ne peut pas être repoussée par le client.
  const salt = `${alea}?expires=${expire}`;
  const nombre = crypto.getRandomValues(new Uint32Array(1))[0] % MAX_NUMBER;
  const challenge = await sha256Hex(salt + nombre);
  return {
    algorithm: 'SHA-256',
    challenge,
    salt,
    signature: await hmacHex(challenge, secret()),
    maxnumber: MAX_NUMBER,
  };
}

export interface ResultatVerification {
  ok: boolean;
  motif?: string;
  /** Le défi, à passer à fn_consume_altcha_challenge. */
  challenge?: string;
  expiresAt?: Date;
}

/**
 * Vérifie une solution. NE FAIT PAS l'anti-rejeu : l'appelant DOIT ensuite
 * passer `challenge` et `expiresAt` à fn_consume_altcha_challenge, et refuser
 * si elle renvoie false. Sans ça, une solution valide se rejoue à volonté.
 *
 * @param charge la charge utile base64 renvoyée par le widget
 */
export async function verifierSolution(charge: string): Promise<ResultatVerification> {
  let p: Record<string, unknown>;
  try {
    p = JSON.parse(atob(charge));
  } catch {
    return { ok: false, motif: 'charge illisible' };
  }

  const { algorithm, challenge, number, salt, signature } = p as {
    algorithm?: string; challenge?: string; number?: number;
    salt?: string; signature?: string;
  };

  if (algorithm !== 'SHA-256') return { ok: false, motif: 'algorithme inattendu' };
  if (typeof challenge !== 'string' || typeof salt !== 'string'
      || typeof signature !== 'string' || typeof number !== 'number') {
    return { ok: false, motif: 'champs manquants' };
  }
  if (!Number.isInteger(number) || number < 0 || number > MAX_NUMBER) {
    return { ok: false, motif: 'nombre hors bornes' };
  }

  // Expiration, lue dans le sel signé.
  const m = salt.match(/[?&]expires=(\d+)/);
  if (!m) return { ok: false, motif: 'sel sans expiration' };
  const expiresAt = new Date(Number(m[1]) * 1000);
  if (expiresAt.getTime() <= Date.now()) return { ok: false, motif: 'défi périmé' };

  // La signature d'abord : elle est bon marché, et elle écarte les défis forgés
  // avant qu'on dépense un hachage.
  if (!egaliteConstante(signature, await hmacHex(challenge, secret()))) {
    return { ok: false, motif: 'signature invalide' };
  }

  // Puis la solution elle-même.
  if (!egaliteConstante(challenge, await sha256Hex(salt + number))) {
    return { ok: false, motif: 'solution incorrecte' };
  }

  return { ok: true, challenge, expiresAt };
}
