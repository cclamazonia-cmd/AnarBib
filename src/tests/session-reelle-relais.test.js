// ═══════════════════════════════════════════════════════════
// AnarBib — B44 (13/10/2026) : verify_jwt = true n'exige pas de session.
//
// Mesuré en prod : un POST avec la seule clé publiable, sans Authorization,
// atteint le code de toutes les fonctions en verify_jwt = true. Celles qui
// appellent des services tiers sans rien demander d'abord sous le jeton de
// l'appelant étaient des relais ouverts.
//   * _shared/core/session-reelle.ts : api.fn_mon_etat_double_facteur sous le
//     jeton de l'appelant ; seule une réponse lisible ouvre (échec fermé) ;
//   * les sept relais posent la garde avant la lecture du corps et avant tout
//     appel sortant ;
//   * LISTE FERMÉE : toute fonction laissée au défaut verify_jwt = true doit
//     être rangée ici dans une des trois familles. Une fonction nouvelle, non
//     rangée, fait échouer ce banc.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';
import { sessionManquante, statutDuRefus } from '../../supabase/functions/_shared/core/session-reelle.ts';

const RACINE = path.resolve(__dirname, '../..');
const FONCTIONS = path.join(RACINE, 'supabase/functions');
const source = (f) => readFileSync(path.join(FONCTIONS, f, 'index.ts'), 'utf8');
const reponse = (status, corps) => ({ ok: status >= 200 && status < 300, status, json: async () => corps });

// Les relais : garde sessionManquante. La valeur = le début du gestionnaire.
const RELAIS = {
  catalog_metadata_lookup: 'export const createLookupHttpHandler',
  cover_lookup: 'runtime.serve(',
  authority_lookup: 'Deno.serve(',
  author_portrait_lookup: 'Deno.serve(',
  geocode: 'async function traiter(',
  audio_fingerprint_lookup: 'Deno.serve(',
  'fetch-url-metadata': 'Deno.serve(', // verify_jwt = false, même garde
};
// Réservée à l'administration du réseau (B43).
const ADMIN_RESEAU = ['probe-partner-catalog'];
// Première requête sous le jeton de l'appelant, à une RPC qu'anon ne peut pas
// exécuter (relevé du 13/10 : fn_export_catalog_lote, fn_export_fonds_records,
// fn_create_library_request_invitation, fn_revoke_digital_asset_record ;
// attach-received-asset passe d'abord par doubleFacteurManquant).
const JETON_APPELANT = {
  'export-catalog-lote': "supabase.rpc('fn_export_catalog_lote'",
  'export-fonds-bundle': "userClient.rpc('fn_export_fonds_records'",
  'deposit-fonds-direct': "userClient.rpc('fn_export_fonds_records'",
  'attach-received-asset': 'await doubleFacteurManquant(supabaseUrl, anonKey, authHeader)',
  'revoke-digital-asset': "userClient.rpc('fn_revoke_digital_asset_record'",
  'notify-library-invitation': 'await asCaller.rpc(',
};

describe('sessionManquante', () => {
  const appel = (fetchFn, auth = 'Bearer jeton-de-l-appelant') =>
    sessionManquante('https://exemple.supabase.co', 'cle-publique', auth, fetchFn);

  it('interroge api.fn_mon_etat_double_facteur sous le jeton de l’appelant', async () => {
    const f = vi.fn(async () => reponse(200, { mode: 'off', aal: 'aal1', exige: false }));
    expect(await appel(f)).toBe(null);
    const [url, init] = f.mock.calls[0];
    expect(url).toBe('https://exemple.supabase.co/rest/v1/rpc/fn_mon_etat_double_facteur');
    expect(init.method).toBe('POST');
    expect(init.headers.Authorization).toBe('Bearer jeton-de-l-appelant');
    expect(init.headers.apikey).toBe('cle-publique');
    expect(init.headers['Content-Profile']).toBe('api');
  });

  it('second facteur exigé : aal1 refusée (403), aal2 acceptée', async () => {
    expect(await appel(async () => reponse(200, { aal: 'aal1', exige: true }))).toBe('aal2_required');
    expect(await appel(async () => reponse(200, { aal: 'aal2', exige: true }))).toBe(null);
    expect(statutDuRefus('aal2_required')).toBe(403);
    expect(statutDuRefus('auth_required')).toBe(401);
  });

  it('échec fermé : anon (401/42501), erreur, corps inattendu, réseau', async () => {
    expect(await appel(async () => reponse(401, { code: '42501' }))).toBe('auth_required');
    expect(await appel(async () => reponse(403, { code: '42501', message: 'not_authenticated' }))).toBe('auth_required');
    expect(await appel(async () => reponse(500, {}))).toBe('auth_required');
    expect(await appel(async () => reponse(200, null))).toBe('auth_required');
    expect(await appel(async () => reponse(200, true))).toBe('auth_required');
    expect(await appel(async () => reponse(200, { exige: 'false', aal: 'aal1' }))).toBe('auth_required');
    expect(await appel(async () => reponse(200, { exige: false }))).toBe('auth_required');
    expect(await appel(async () => { throw new Error('réseau'); })).toBe('auth_required');
  });

  it('sans en-tête, ou en-tête qui n’est pas un Bearer : refus sans même demander', async () => {
    const f = vi.fn(async () => reponse(200, { aal: 'aal1', exige: false }));
    expect(await appel(f, null)).toBe('auth_required');
    expect(await appel(f, '')).toBe('auth_required');
    expect(await appel(f, 'Bearer ')).toBe('auth_required');
    expect(await appel(f, 'Basic abc')).toBe('auth_required');
    expect(await sessionManquante('https://exemple.supabase.co', '', 'Bearer x', f)).toBe('auth_required');
    expect(await sessionManquante(undefined, 'cle', 'Bearer x', f)).toBe('auth_required');
    expect(f).not.toHaveBeenCalled();
  });
});

describe.each(Object.entries(RELAIS))('relais %s', (fonction, debut) => {
  const src = source(fonction);
  const gestionnaire = src.slice(src.indexOf(debut));

  it('importe la garde partagée', () => {
    expect(src).toMatch(/import \{ sessionManquante, statutDuRefus \} from ['"]\.\.\/_shared\/core\/session-reelle\.ts['"];/);
    expect(src.indexOf(debut)).toBeGreaterThan(-1);
  });

  it('la garde passe avant la lecture du corps et avant tout appel sortant', () => {
    const garde = gestionnaire.indexOf('await sessionManquante(');
    const corps = gestionnaire.indexOf('req.json()');
    expect(garde).toBeGreaterThan(-1);
    expect(corps).toBeGreaterThan(garde);
    const avant = gestionnaire.slice(0, garde);
    expect(avant).not.toMatch(/fetch\w*\(|createClient\(|handle\w*\(/);
  });

  it('le refus sort aussitôt, avec le statut de statutDuRefus', () => {
    const garde = gestionnaire.indexOf('await sessionManquante(');
    const suite = gestionnaire.slice(garde, garde + 400);
    expect(suite).toMatch(/if \(refus\)[\s\S]{0,120}?return [\s\S]{0,80}?error: refus[\s\S]{0,40}?statutDuRefus\(refus\)\)/);
    expect(suite).toMatch(/req\.headers\.get\(['"]Authorization['"]\)|authHeader\)/);
  });
});

describe('liste fermée des fonctions en verify_jwt = true', () => {
  const config = readFileSync(path.join(RACINE, 'supabase/config.toml'), 'utf8');
  const declarees = new Set([...config.matchAll(/^\[functions\.([^\]]+)\]/gm)].map((m) => m[1]));
  const fonctions = readdirSync(FONCTIONS).filter((f) =>
    !f.startsWith('_') && f !== 'main' && statSync(path.join(FONCTIONS, f)).isDirectory());
  const auDefaut = fonctions.filter((f) => !declarees.has(f)).sort();

  it('chaque fonction laissée au défaut est rangée dans une famille', () => {
    const rangees = [
      ...Object.keys(RELAIS).filter((f) => !declarees.has(f)),
      ...ADMIN_RESEAU,
      ...Object.keys(JETON_APPELANT),
    ].sort();
    expect(auDefaut).toEqual(rangees);
  });

  it('les fonctions « jeton de l’appelant » font bien cette requête d’abord', () => {
    for (const [fonction, premiere] of Object.entries(JETON_APPELANT)) {
      const src = source(fonction);
      const serve = src.slice(src.search(/\b(Deno\.)?serve\(/));
      const ici = serve.indexOf(premiere);
      expect(ici, fonction).toBeGreaterThan(-1);
      // Rien à la clé de service ni vers un tiers avant elle.
      expect(serve.slice(0, ici), fonction).not.toMatch(/service\.|ingestRpc\.|fetch\(|safeSendEmail\(/);
    }
  });

  it('la fonction réservée à l’administration du réseau garde sa garde', () => {
    for (const fonction of ADMIN_RESEAU) {
      expect(source(fonction)).toMatch(/await appelantAdministreLeReseau\(/);
    }
  });
});
