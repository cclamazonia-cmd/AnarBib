// ═══════════════════════════════════════════════════════════
// AnarBib — attach-received-asset décide la permission AVANT la clé de service
// (13/10/2026, constat de l'audit B42 des Edge Functions ; migration
// 20261013182842).
//   * la garde fn_attach_received_asset_garde part sous le jeton de
//     l'appelant (userClient), après la double authentification et avant le
//     premier geste à la clé de service (lecture d'ingest, dépôt, upload) ;
//   * son refus rend avant tout geste à la clé, en échec fermé : une erreur
//     ou une réponse autre que true refuse ;
//   * la migration ouvre la garde à authenticated, pas à anon, et retire le
//     retour « déjà attaché » d'avant les gardes de la RPC d'écriture.
// Le comportement des règles est tenu en base par
// tests/sql/attach_recu_garde_tests.sql.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';

const RACINE = path.resolve(__dirname, '../..');
const src = readFileSync(path.join(RACINE, 'supabase/functions/attach-received-asset/index.ts'), 'utf8');
const MIGRATIONS = path.join(RACINE, 'supabase/migrations');
const migration = readdirSync(MIGRATIONS).find((f) => f.endsWith('_attacher_un_fichier_recu_se_decide_avant_la_cle_de_service.sql'));

describe('attach-received-asset : la permission avant la clé de service', () => {
  const doubleFacteur = src.indexOf('await doubleFacteurManquant(supabaseUrl, anonKey, authHeader)');
  const garde = src.indexOf("await userClient.rpc('fn_attach_received_asset_garde'");
  const premierService = src.search(/await service\b/);

  it('la garde part sous le jeton de l’appelant, après la double authentification', () => {
    expect(doubleFacteur).toBeGreaterThan(-1);
    expect(garde).toBeGreaterThan(doubleFacteur);
  });

  it('aucun geste à la clé de service ne précède la garde', () => {
    expect(premierService).toBeGreaterThan(garde);
    expect(src.indexOf("await service.schema('ingest')")).toBeGreaterThan(garde);
    expect(src.indexOf('service.storage')).toBeGreaterThan(garde);
  });

  it('le refus rend avant la clé de service, en échec fermé', () => {
    const entre = src.slice(garde, premierService);
    expect(entre).toMatch(/if \(gardeErr \|\| autorise !== true\)/);
    expect(entre).toContain("return refus('received_asset_not_found'");
    expect(entre).toContain("return refus('forbidden'");
  });

  it('la migration ouvre la garde à authenticated seulement et ferme l’oracle « déjà attaché »', () => {
    expect(migration, 'migration de la garde').toBeTruthy();
    const sql = readFileSync(path.join(MIGRATIONS, migration), 'utf8');
    expect(sql).toMatch(/REVOKE ALL ON FUNCTION public\.fn_attach_received_asset_garde\(bigint, bigint\) FROM PUBLIC, anon, authenticated;/);
    expect(sql).toMatch(/GRANT EXECUTE ON FUNCTION public\.fn_attach_received_asset_garde\(bigint, bigint\) TO authenticated, service_role;/);
    // dans la RPC d'écriture, le seul retour « déjà attaché » vient après les gardes
    const corps = sql.slice(sql.indexOf('CREATE OR REPLACE FUNCTION public.fn_attach_received_asset_record'));
    const retour = corps.indexOf("RETURN jsonb_build_object('ok', true, 'asset_id', ra.attached_digital_asset_id");
    expect(retour).toBeGreaterThan(corps.indexOf('IF NOT v_authorized THEN'));
    expect(corps.indexOf("RETURN jsonb_build_object('ok', true, 'asset_id', ra.attached_digital_asset_id", retour + 1)).toBe(-1);
  });
});
