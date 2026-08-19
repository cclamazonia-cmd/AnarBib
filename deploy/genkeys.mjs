// =============================================================================
// AnarBib — génération des secrets de la pile auto-hébergée
// =============================================================================
// Usage, depuis le dossier deploy/ :
//
//   node genkeys.mjs           → remplit les secrets manquants dans .env
//   node genkeys.mjs --local   → idem + bascule les domaines sur localhost
//                                 (pour la répétition sur votre machine)
//
// Le script N'AFFICHE JAMAIS les secrets : il les écrit dans .env et se
// contente de dire ce qu'il a rempli. Ce fichier est ignoré par git
// (.gitignore, ligne 97), tout comme .env.
//
// Relancer le script ne réécrit PAS une valeur déjà présente : il ne remplit
// que ce qui est vide. Pour tout regénérer, videz les lignes concernées.
// =============================================================================

import crypto from 'node:crypto';
import fs from 'node:fs';

const ENV = '.env';
const LOCAL = process.argv.includes('--local');

if (!fs.existsSync(ENV)) {
  console.error(`✗ ${ENV} introuvable. Lancez ce script depuis le dossier deploy/,`);
  console.error(`  après avoir fait :  copy .env.example .env`);
  process.exit(1);
}

let txt = fs.readFileSync(ENV, 'utf8');
const rempli = [];
const deja = [];

// --- helpers ---------------------------------------------------------------

const lire = (cle) => {
  const m = txt.match(new RegExp(`^${cle}=(.*)$`, 'm'));
  return m ? m[1].trim() : null;
};

// Écrit une valeur SEULEMENT si la clé existe et qu'elle est vide.
const poser = (cle, valeur, { force = false } = {}) => {
  const re = new RegExp(`^${cle}=(.*)$`, 'm');
  const m = txt.match(re);
  if (!m) { console.warn(`  ! clé absente du fichier : ${cle}`); return false; }
  if (m[1].trim() !== '' && !force) { deja.push(cle); return false; }
  txt = txt.replace(re, `${cle}=${valeur}`);
  rempli.push(cle);
  return true;
};

const alea = (octets) => {
  const b = crypto.randomBytes(octets);
  // base64 sans caractères gênants dans une URL de connexion Postgres
  return b.toString('base64').replace(/[+/=]/g, '').slice(0, Math.round(octets * 1.2));
};

const b64url = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64url');

const jwt = (role, secret) => {
  const now = Math.floor(Date.now() / 1000);
  const tete = b64url({ alg: 'HS256', typ: 'JWT' });
  const corps = b64url({
    role,
    iss: 'supabase',
    iat: now,
    exp: now + 60 * 60 * 24 * 365 * 10,   // 10 ans
  });
  const sig = crypto.createHmac('sha256', secret)
    .update(`${tete}.${corps}`).digest('base64url');
  return `${tete}.${corps}.${sig}`;
};

// --- 1. mot de passe Postgres ----------------------------------------------

poser('POSTGRES_PASSWORD', alea(36));

// --- 2. secret de signature JWT --------------------------------------------

poser('JWT_SECRET', alea(48));
const secret = lire('JWT_SECRET');

if (!secret || secret.length < 32) {
  console.error('✗ JWT_SECRET absent ou trop court — impossible de dériver les clés.');
  process.exit(1);
}

// --- 3. les deux clés dérivées ---------------------------------------------
// ANON_KEY est publique (elle finit dans le bundle du navigateur).
// SERVICE_ROLE_KEY ouvre tout : jamais dans le front, jamais dans le dépôt.

poser('ANON_KEY', jwt('anon', secret));
poser('SERVICE_ROLE_KEY', jwt('service_role', secret));

// --- 4. mode local (répétition sur votre machine) --------------------------

if (LOCAL) {
  poser('API_DOMAIN', 'localhost', { force: true });
  poser('API_EXTERNAL_URL', 'http://localhost', { force: true });
  poser('SITE_URL', 'http://localhost:5173', { force: true });
  poser('URI_ALLOW_LIST', 'http://localhost:5173,http://localhost:5173/*', { force: true });
}

// --- écriture ---------------------------------------------------------------

fs.writeFileSync(ENV, txt);

console.log('');
if (rempli.length) {
  console.log('✓ Rempli dans .env :');
  for (const c of rempli) console.log(`    ${c}`);
} else {
  console.log('· Rien à remplir : toutes les valeurs étaient déjà présentes.');
}
if (deja.length) {
  console.log('');
  console.log('· Laissé tel quel (déjà renseigné) :');
  for (const c of deja) console.log(`    ${c}`);
}

console.log('');
console.log('Aucun secret n\'a été affiché. Ils sont dans .env, qui est ignoré par git.');
if (LOCAL) {
  console.log('Mode local : domaines basculés sur localhost.');
  console.log('⚠️  Pensez aussi à remplacer, dans le Caddyfile, la première ligne');
  console.log('    «  {$API_DOMAIN} {  »  par  «  http://localhost {  ».');
}
console.log('');
