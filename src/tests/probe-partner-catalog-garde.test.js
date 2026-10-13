// ═══════════════════════════════════════════════════════════
// AnarBib — B43 (13/10/2026) : probe-partner-catalog réservée à
// l'administration du réseau.
//   * _shared/core/admin-reseau.ts : demande fn_caller_is_network_admin sous
//     le jeton de l'appelant ; seule la réponse `true` ouvre (échec fermé) ;
//   * probe-partner-catalog : la garde passe AVANT le premier geste à la clé
//     de service (aucun client à la clé de service au niveau du module) ;
//   * la réponse ne rend plus la ligne catalog_partners entière.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi } from 'vitest';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { appelantAdministreLeReseau } from '../../supabase/functions/_shared/core/admin-reseau.ts';

const RACINE = path.resolve(__dirname, '../..');
const SOURCE = readFileSync(path.join(RACINE, 'supabase/functions/probe-partner-catalog/index.ts'), 'utf8');
const reponse = (status, corps) => ({ ok: status >= 200 && status < 300, status, json: async () => corps });

describe('appelantAdministreLeReseau', () => {
  const appel = (fetchFn, auth = 'Bearer jeton-de-l-appelant') =>
    appelantAdministreLeReseau('https://exemple.supabase.co', 'cle-publique', auth, fetchFn);

  it('interroge fn_caller_is_network_admin sous le jeton de l’appelant', async () => {
    const f = vi.fn(async () => reponse(200, true));
    expect(await appel(f)).toBe(true);
    const [url, init] = f.mock.calls[0];
    expect(url).toBe('https://exemple.supabase.co/rest/v1/rpc/fn_caller_is_network_admin');
    expect(init.method).toBe('POST');
    expect(init.headers.Authorization).toBe('Bearer jeton-de-l-appelant');
    expect(init.headers.apikey).toBe('cle-publique');
  });

  it('un compte qui n’administre pas le réseau est refusé', async () => {
    expect(await appel(async () => reponse(200, false))).toBe(false);
  });

  it('échec fermé : erreur (dont 403 de la double authentification), corps inattendu, réseau', async () => {
    expect(await appel(async () => reponse(403, { code: 'AAL2_REQUIRED' }))).toBe(false);
    expect(await appel(async () => reponse(500, {}))).toBe(false);
    expect(await appel(async () => reponse(200, 'true'))).toBe(false);
    expect(await appel(async () => reponse(200, [true]))).toBe(false);
    expect(await appel(async () => reponse(200, null))).toBe(false);
    expect(await appel(async () => { throw new Error('réseau'); })).toBe(false);
  });

  it('sans en-tête, ou en-tête qui n’est pas un Bearer : refus sans même demander', async () => {
    const f = vi.fn(async () => reponse(200, true));
    expect(await appel(f, null)).toBe(false);
    expect(await appel(f, '')).toBe(false);
    expect(await appel(f, 'Basic abc')).toBe(false);
    expect(await appelantAdministreLeReseau('https://exemple.supabase.co', '', 'Bearer x', f)).toBe(false);
    expect(f).not.toHaveBeenCalled();
  });
});

describe('probe-partner-catalog', () => {
  it('aucun client à la clé de service au niveau du module', () => {
    const avantServe = SOURCE.slice(0, SOURCE.indexOf('Deno.serve('));
    expect(avantServe).not.toMatch(/=\s*createClient\(/);
  });

  it('la garde passe avant le premier geste à la clé de service et avant la lecture du corps', () => {
    const serve = SOURCE.slice(SOURCE.indexOf('Deno.serve('));
    const garde = serve.indexOf('await appelantAdministreLeReseau(SUPABASE_URL, ANON_KEY, authHeader)');
    const client = serve.indexOf('createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)');
    const corps = serve.indexOf('await req.json()');
    expect(garde).toBeGreaterThan(-1);
    expect(client).toBeGreaterThan(garde);
    expect(corps).toBeGreaterThan(garde);
    expect(serve.slice(garde, client)).toMatch(/status:\s*403/);
  });

  it('la ligne catalog_partners n’est jamais rendue entière', () => {
    // Toute mention de `partner` dans une réponse passe par partenairePublic.
    expect(SOURCE).not.toMatch(/^\s*partner\s*,?\s*$/m);
    expect(SOURCE).not.toMatch(/partner:\s*partner\b/);
    expect(SOURCE.match(/partner:\s*partenairePublic\(partner\)/g)).toHaveLength(2);
    expect(SOURCE).toMatch(/return \{\s*id: partner\.id,\s*slug: partner\.slug,\s*display_name: partner\.display_name\s*\};/);
  });
});
