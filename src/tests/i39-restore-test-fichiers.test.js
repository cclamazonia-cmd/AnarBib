// ═══════════════════════════════════════════════════════════
// AnarBib — I39 (20/10/2026) : le restore-test restaure aussi des fichiers.
//
// Le restore-test ne couvrait que les flux de base (long, court). Les flux de
// fichiers (storage, vers Les Herbes Folles ; lourd, dépôt local) n'avaient
// été restaurés qu'une fois, à la main, le 19/10. Désormais `cmd_restore_test`
// tire un échantillon de chaque flux, le restaure depuis restic, le
// retélécharge de Storage et compare les empreintes (éprouvé le 20/10 sur les
// vrais dépôts : 3/3 et 3/3 identiques).
//
// Ce banc garde : les deux flux appelés, les bornes de l'échantillon (taille,
// antériorité à l'instantané), la comparaison SHA-256, un verdict qui ne
// nomme pas l'objet, et l'absence d'échec du test pour un écart (il le dit).
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const SCRIPT = readFileSync(path.resolve(__dirname, '../../deploy/ops/anarbib-bg2.sh'), 'utf8');

function fonction(source, nom) {
  const bloc = source.match(new RegExp(`^${nom}\\(\\) \\{[\\s\\S]*?^\\}`, 'm'));
  if (!bloc) throw new Error(`fonction introuvable : ${nom}`);
  return bloc[0];
}

describe('I39 — storage et lourd au restore-test', () => {
  const rt = fonction(SCRIPT, 'cmd_restore_test');
  const vf = fonction(SCRIPT, 'verifier_fichiers');

  it('restore-test vérifie les deux flux de fichiers, après le verdict de la base', () => {
    expect(rt).toMatch(/verifier_fichiers storage "\$RESTIC_BASE\/anarbib-storage" "\$STORAGE_WORK" "\$\{BUCKETS\[@\]\}"/);
    expect(rt).toMatch(/verifier_fichiers lourd "\$LOURD_REPO" "\$LOURD_WORK" "\$\{BUCKETS_LOURDS\[@\]\}"/);
    expect(rt.indexOf('verifier_fichiers storage')).toBeGreaterThan(rt.indexOf('VERDICT'));
  });

  it('un dépôt lourd absent se dit, sans interrompre le test', () => {
    expect(rt).toContain('[ -f "$LOURD_REPO/config" ]');
    expect(rt).toContain('fichiers lourd : depot local introuvable');
  });

  it('l’échantillon : objets antérieurs à l’instantané, de 1 octet à 50 Mo, tirés au sort', () => {
    expect(vf).toContain("updated_at < '$quand'::timestamptz - interval '3 hours'");
    expect(vf).toContain('between 1 and 52428800');
    expect(vf).toContain('order by random()');
    expect(vf).toContain('BG2_RT_ECHANTILLON:-4');
  });

  it('restauré depuis restic, retéléchargé de Storage, comparé par SHA-256', () => {
    expect(vf).toMatch(/restic restore latest --tag "flux-\$flux" --include "\$racine\/\$b\/\$nom"/);
    expect(vf).toMatch(/supabase storage cp --linked --experimental "ss:\/\/\/\$b\/\$nom"/);
    expect(vf).toContain('sha256sum < "$rest"');
    expect(vf).toContain('sha256sum < "$live"');
  });

  it('le verdict ne nomme pas l’objet et ne fait pas échouer le test', () => {
    const echos = vf.split('\n').filter((l) => /echo "/.test(l));
    expect(echos.length).toBeGreaterThan(4);
    for (const l of echos) expect(l).not.toContain('$nom');
    expect(vf).not.toMatch(/\bdie\b/);
    expect(vf).not.toMatch(/\bexit\b/);
  });

  it('les fichiers restaurés vivent dans le bac à sable, nettoyé à la sortie', () => {
    expect(vf).toContain('cible="$RT_DIR/fichiers-$flux"');
    expect(vf).toContain('vif="$RT_DIR/vif-$flux"');
    expect(fonction(SCRIPT, 'cleanup_restore_test')).toContain('rm -rf "$RT_DIR"');
  });
});
