// ═══════════════════════════════════════════════════════════
// AnarBib — B42, lot 3 (13/10/2026) : la double authentification dans les
// Edge Functions qui travaillent avec la clé de service.
//   * _shared/core/double-facteur.ts : refuse quand l'état serveur dit « aal2
//     exigé, session aal1 », et quand l'état ne se lit pas (échec fermé) ;
//     interroge la seule RPC de la liste blanche, sous le jeton de l'appelant ;
//   * attach-received-asset : la garde passe AVANT le premier geste à la clé
//     de service (la lecture du dépôt), et refuse avec le code aal2_required ;
//   * les fonctions de l'audit dites couvertes font bien leur première
//     requête sous le jeton de l'appelant, avant tout geste à la clé de
//     service (si l'une change d'ordre, ce test le dit).
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi } from 'vitest';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { doubleFacteurManquant, CODE_AAL2 } from '../../supabase/functions/_shared/core/double-facteur.ts';

const RACINE = path.resolve(__dirname, '../..');
const source = (f) => readFileSync(path.join(RACINE, 'supabase/functions', f, 'index.ts'), 'utf8');
const reponse = (status, corps) => ({ ok: status >= 200 && status < 300, status, json: async () => corps });

describe('doubleFacteurManquant', () => {
  const appel = (fetchFn, auth = 'Bearer jeton-de-l-appelant') =>
    doubleFacteurManquant('https://exemple.supabase.co', 'cle-publique', auth, fetchFn);

  it('interroge api.fn_mon_etat_double_facteur sous le jeton de l’appelant', async () => {
    const f = vi.fn(async () => reponse(200, { exige: false, aal: 'aal1' }));
    expect(await appel(f)).toBe(false);
    const [url, init] = f.mock.calls[0];
    expect(url).toBe('https://exemple.supabase.co/rest/v1/rpc/fn_mon_etat_double_facteur');
    expect(init.headers.Authorization).toBe('Bearer jeton-de-l-appelant');
    expect(init.headers['Accept-Profile']).toBe('api');
    expect(init.headers.apikey).toBe('cle-publique');
  });

  it('aal2 exigé et session aal1 : refus ; session aal2 : passe', async () => {
    expect(await appel(async () => reponse(200, { exige: true, aal: 'aal1' }))).toBe(true);
    expect(await appel(async () => reponse(200, { exige: true, aal: 'aal2' }))).toBe(false);
  });

  it('échec fermé : réponse en erreur, corps inattendu, réseau, en-tête absent', async () => {
    expect(await appel(async () => reponse(500, {}))).toBe(true);
    expect(await appel(async () => reponse(200, null))).toBe(true);
    expect(await appel(async () => reponse(200, { mode: 'off' }))).toBe(true);
    expect(await appel(async () => { throw new Error('réseau'); })).toBe(true);
    expect(await appel(async () => reponse(200, { exige: false }), null)).toBe(true);
  });

  it('le code de refus a son libellé dans les dix locales', () => {
    expect(CODE_AAL2).toBe('aal2_required');
    for (const loc of ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR']) {
      const j = JSON.parse(readFileSync(path.join(RACINE, 'src/i18n/locales', `${loc}.json`), 'utf8'));
      expect(j['error.edge.aal2_required'], loc).toBeTruthy();
    }
  });
});

describe('les Edge Functions à la clé de service', () => {
  it('attach-received-asset : la garde passe avant le premier geste à la clé de service', () => {
    const src = source('attach-received-asset');
    const garde = src.indexOf('await doubleFacteurManquant(supabaseUrl, anonKey, authHeader)');
    const premierService = src.indexOf("await service.schema('ingest')");
    expect(garde).toBeGreaterThan(-1);
    expect(premierService).toBeGreaterThan(garde);
    expect(src.slice(garde, premierService)).toContain("return refus('aal2_required'");
  });

  // Audit du 13/10 : la première requête part sous le jeton de l'appelant, donc
  // la fonction d'avant-requête la refuse avant tout geste à la clé de service.
  const COUVERTES = [
    ['deposit-fonds-direct', 'await userClient.rpc(', /await (service|ingestRpc)\b/],
    ['export-fonds-bundle', 'await userClient.rpc(', /await service\b/],
    ['read-digital-asset', 'await userClient.rpc(', /await service\b/],
    ['read-ill-shared-asset', 'await userClient.rpc(', /await service\b/],
    ['revoke-digital-asset', 'await userClient.rpc(', /await service\b/],
  ];
  for (const [nom, sousJeton, aLaCle] of COUVERTES) {
    it(`${nom} : première requête sous le jeton de l’appelant`, () => {
      const src = source(nom);
      const i = src.indexOf(sousJeton);
      const m = src.match(aLaCle);
      expect(i, 'requête sous le jeton').toBeGreaterThan(-1);
      if (m) expect(m.index, 'geste à la clé de service avant la porte').toBeGreaterThan(i);
    });
  }
});
