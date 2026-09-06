// =============================================================================
// AnarBib — initialisation du compte administrateur initial
// =============================================================================
// Utilisé par ./install.sh lors de la première installation ou après --rebuild.
// Crée un compte administrateur réseau + coordinateur de bibliothèque si aucun
// administrateur actif n'existe encore dans la base.
//
// Usage :
//   node deploy/scripts/seed-admin.mjs [local|prod] [domaine]
// =============================================================================

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { execSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DEPLOY_DIR = path.resolve(__dirname, '..');
const ENV_FILE = path.join(DEPLOY_DIR, '.env');

const mode = process.argv[2] || 'local';
const rawDomain = process.argv[3] || '';

if (!fs.existsSync(ENV_FILE)) {
  console.error(`✗ Fichier ${ENV_FILE} introuvable.`);
  process.exit(1);
}

const envContent = fs.readFileSync(ENV_FILE, 'utf8');
const matchKey = envContent.match(/^SERVICE_ROLE_KEY=(.*)$/m);
if (!matchKey) {
  console.error('✗ SERVICE_ROLE_KEY introuvable dans deploy/.env');
  process.exit(1);
}
const serviceRoleKey = matchKey[1].trim();

function getAdminCount() {
  try {
    const out = execSync(
      `docker compose -f "${path.join(DEPLOY_DIR, 'compose.yml')}" exec -T db psql -U supabase_admin -d postgres -tAc "SELECT count(*) FROM public.network_administrators WHERE status='active';"`,
      { encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'] }
    );
    return parseInt(out.trim(), 10) || 0;
  } catch {
    return 0;
  }
}

async function main() {
  const adminCount = getAdminCount();
  if (adminCount > 0) {
    return;
  }

  let adminEmail = 'admin@anarbib.local';
  let adminPassword = 'anarbib-admin';

  if (mode === 'prod') {
    const cleanDomain = rawDomain
      .replace(/^https?:\/\//, '')
      .replace(/\/.*$/, '')
      .trim();
    adminEmail = cleanDomain ? `admin@${cleanDomain}` : 'admin@anarbib.org';
    adminPassword = crypto.randomBytes(12).toString('base64url');
  }

  let userId = null;
  try {
    const res = await fetch('http://127.0.0.1:80/auth/v1/admin/users', {
      method: 'POST',
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email: adminEmail,
        password: adminPassword,
        email_confirm: true,
        user_metadata: { first_name: 'Admin', last_name: 'AnarBib' },
      }),
    });

    const data = await res.json();
    if (data.id) {
      userId = data.id;
    } else if (data.error_code === 'email_exists' || (data.msg || data.message || '').includes('already')) {
      const idOut = execSync(
        `docker compose -f "${path.join(DEPLOY_DIR, 'compose.yml')}" exec -T db psql -U supabase_admin -d postgres -tAc "SELECT id FROM auth.users WHERE email='${adminEmail}';"`,
        { encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'] }
      );
      userId = idOut.trim();
    } else {
      throw new Error(data.message || data.msg || JSON.stringify(data));
    }
  } catch (err) {
    console.error(`✗ Échec création GoTrue: ${err.message}`);
    process.exit(1);
  }

  if (!userId) {
    console.error('✗ Impossible de récupérer l\'ID utilisateur.');
    process.exit(1);
  }

  const sql = `
DO $$
DECLARE
  v_uid uuid := '${userId}'::uuid;
  v_lib_id uuid;
BEGIN
  INSERT INTO public.profiles (id, email, first_name, last_name, is_librarian, preferred_language)
  VALUES (v_uid, '${adminEmail}', 'Admin', 'AnarBib', true, 'fr')
  ON CONFLICT (id) DO UPDATE SET is_librarian = true, preferred_language = 'fr';

  IF NOT EXISTS (SELECT 1 FROM public.libraries LIMIT 1) THEN
    INSERT INTO public.libraries (slug, name, is_active, is_default, accepts_public_signup, default_locale)
    VALUES ('demo', 'Bibliothèque AnarBib Démo', true, true, true, 'fr')
    RETURNING id INTO v_lib_id;
  ELSE
    SELECT id INTO v_lib_id FROM public.libraries ORDER BY created_at ASC LIMIT 1;
  END IF;

  IF v_lib_id IS NOT NULL THEN
    INSERT INTO public.user_library_memberships (user_id, library_id, role, is_primary, status)
    VALUES (v_uid, v_lib_id, 'coordenador', true, 'active')
    ON CONFLICT (user_id, library_id, role) DO UPDATE SET status = 'active';

    INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
    VALUES (v_uid, v_lib_id, 'librarian', 'active')
    ON CONFLICT (user_id, library_id, role) DO UPDATE SET status = 'active';
  END IF;

  INSERT INTO public.network_administrators (user_id, status)
  VALUES (v_uid, 'active')
  ON CONFLICT (user_id) DO UPDATE SET status = 'active';
END $$;
`;

  try {
    // Le SQL contient des délimiteurs $$ (PL/pgSQL) qui seraient interprétés
    // par le shell si passés via -c "...". On pipe via stdin pour éviter ça.
    execSync(
      `docker compose -f "${path.join(DEPLOY_DIR, 'compose.yml')}" exec -T db psql -U supabase_admin -d postgres`,
      { input: sql, encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'] }
    );
  } catch (err) {
    console.error(`✗ Erreur attribution rôles SQL: ${err.message}`);
    process.exit(1);
  }

  const credsFile = path.join(DEPLOY_DIR, '.initial_admin_creds');
  fs.writeFileSync(
    credsFile,
    `ADMIN_EMAIL=${adminEmail}\nADMIN_PASSWORD=${adminPassword}\n`
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
