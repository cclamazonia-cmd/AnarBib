// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/health-probe-kinds-check.test.js
//
// CE QUE CE TEST PROTÈGE (I22, 25/09/2026).
// Chaque sonde de health-probe insère un incident d'un `kind` que la base
// contraint (service_health_incidents_kind_check). Les deux endroits se tiennent
// à la main, et la migration 20260821060000 le disait déjà : un kind ajouté dans
// la fonction sans élargir la CHECK fait échouer l'insertion — l'alerte est alors
// retenue à CHAQUE tour, sans rien de rouge nulle part. C'est arrivé de justesse
// deux fois (images_pins le 21/09, mail_transport le 24/09) ; la troisième
// (deploiement, I22) passe par ce test.
//
// On lit la DERNIÈRE migration qui repose la CHECK — c'est elle qui fait foi en
// production — et on exige que tout kind littéral de health-probe y figure.

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const RACINE = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const MIGRATIONS = path.join(RACINE, 'supabase', 'migrations');
const SONDE = readFileSync(path.join(RACINE, 'supabase', 'functions', 'health-probe', 'index.ts'), 'utf8');

function derniereCheck() {
  const fichiers = readdirSync(MIGRATIONS).filter((f) => f.endsWith('.sql')).sort();
  for (let i = fichiers.length - 1; i >= 0; i--) {
    const sql = readFileSync(path.join(MIGRATIONS, fichiers[i]), 'utf8');
    const m = sql.match(/add constraint service_health_incidents_kind_check\s+check\s*\(kind = any \(array\[([\s\S]*?)\]\)\)/i);
    if (m) {
      const sansCommentaires = m[1].replace(/--[^\n]*/g, '');
      return { fichier: fichiers[i], kinds: [...sansCommentaires.matchAll(/'([a-z_]+)'/g)].map((x) => x[1]) };
    }
  }
  throw new Error('aucune migration ne pose service_health_incidents_kind_check');
}

describe('health-probe — les kinds et la CHECK de la base se tiennent', () => {
  const { fichier, kinds } = derniereCheck();
  const utilises = [...new Set([...SONDE.matchAll(/kind: '([a-z_]+)'/g)].map((x) => x[1]))].sort();

  it('lit bien une liste de kinds dans la dernière CHECK', () => {
    expect(kinds.length).toBeGreaterThanOrEqual(8);
    expect(utilises.length).toBeGreaterThanOrEqual(8);
  });

  it('tout kind inséré par health-probe est admis par la dernière CHECK (' + fichier + ')', () => {
    expect(utilises.filter((k) => !kinds.includes(k))).toEqual([]);
  });

  it('la sonde de déploiement (I22) est branchée des deux côtés', () => {
    expect(kinds).toContain('deploiement');
    expect(SONDE).toContain("rpc: 'fn_healthcheck_deploiement'");
  });
});
