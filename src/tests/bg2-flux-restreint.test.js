// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/bg2-flux-restreint.test.js
//
// CE QUE CE TEST PROTÈGE (22/10/2026). Le flux `restreint` copie chez un tiers
// les buckets lourds à accès RESTREINT — ceux qu'on ne retrouverait nulle part
// ailleurs (« cas C » de la note « Sortir des services états-uniens » v4.3).
// Sa liste, BUCKETS_RESTREINTS, est tenue à la main à côté de BUCKETS_LOURDS :
// un PDF restreint versé dans un nouveau bucket lourd, oublié dans la seconde
// liste, serait sauvegardé sur le poste mais jamais chez le tiers, sans que
// rien ne le dise. Le test lit les deux listes dans le vrai script.
//
// Il garde aussi la règle d'activation : tant que le flux n'est pas actif, il
// reste hors de `backup all` (son dépôt n'existe pas encore).

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const SCRIPT = fileURLToPath(new URL('../../deploy/ops/anarbib-bg2.sh', import.meta.url));
const source = readFileSync(SCRIPT, 'utf8');

// Une liste bash `NOM=(a b\n  c)` : ses éléments.
function liste(nom) {
  const m = source.match(new RegExp(`^${nom}=\\(([^)]*)\\)`, 'm'));
  if (!m) throw new Error(`liste ${nom} introuvable dans anarbib-bg2.sh`);
  return m[1].split(/\s+/).filter(Boolean);
}

describe('#BG2 — flux restreint (22/10/2026)', () => {
  const lourds = liste('BUCKETS_LOURDS');
  const restreints = liste('BUCKETS_RESTREINTS');

  it('ses buckets sont des buckets lourds (le miroir D: les synchronise déjà)', () => {
    expect(restreints.length).toBeGreaterThan(0);
    for (const b of restreints) expect(lourds).toContain(b);
  });

  it('tout bucket lourd dont le nom dit « restreint » y figure', () => {
    const parNom = lourds.filter((b) => /restri/.test(b));
    expect(parNom.length).toBeGreaterThan(0);
    for (const b of parNom) expect(restreints).toContain(b);
  });

  it('aucun bucket public ni le fond de carte n’y entre', () => {
    for (const b of restreints) {
      expect(b).not.toMatch(/public/);
      expect(b).not.toBe('map-tiles');
    }
  });

  it('hors de `backup all` tant qu’il n’est pas actif, mais appelable seul', () => {
    const all = source.match(/^\s*all\)\s*(.*)$/m);
    expect(all).not.toBeNull();
    expect(all[1]).not.toMatch(/backup_restreint/);
    expect(source).toMatch(/^\s*restreint\)\s*backup_restreint ;;/m);
  });
});
