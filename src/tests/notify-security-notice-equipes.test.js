// ═══════════════════════════════════════════════════════════
// AnarBib — B42 (13/10/2026) : notify-security-notice sait viser les ÉQUIPES.
// L'annonce de la double authentification obligatoire part aux comptes
// d'équipe (bibliothécaires, coordinations, administration du réseau), pas au
// lectorat : la fonction prend désormais `roles`, `library_slugs: ["*"]` et
// `network_admins: true`. Sans ces champs, elle se comporte comme avant
// (toutes les adhésions actives des bibliothèques nommées). Garde sur le
// source : la fonction tourne sous Deno.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const src = readFileSync(path.resolve(__dirname, '../../supabase/functions/notify-security-notice/index.ts'), 'utf8');

describe('notify-security-notice — viser les équipes', () => {
  it('les rôles sont une liste fermée, vérifiée avant toute requête', () => {
    expect(src).toContain("const ROLES_PERMIS = ['reader', 'librarian', 'coordenador'];");
    expect(src).toMatch(/roles\.some\(\(r\) => !ROLES_PERMIS\.includes\(r\)\)/);
    expect(src.indexOf('ROLES_PERMIS.includes')).toBeLessThan(src.indexOf(".from('user_library_memberships')"));
  });

  it('le filtre de rôle et le « toutes les bibliothèques » portent sur les adhésions actives', () => {
    const debut = src.indexOf('let memQuery');
    const bloc = src.slice(debut, src.indexOf('const userIds', debut));
    expect(bloc).toContain(".eq('status', 'active')");
    expect(bloc).toContain("if (!toutes) memQuery = memQuery.in('library_id', libIds);");
    expect(bloc).toContain("if (roles) memQuery = memQuery.in('role', roles);");
  });

  it("l'administration du réseau active s'ajoute sur demande, sans doublon", () => {
    expect(src).toContain('const networkAdmins = payload.network_admins === true;');
    expect(src).toContain("import { adminsReseauActifs } from '../_shared/context/network-admins.ts';");
    expect(src).toContain('for (const a of await adminsReseauActifs(supabaseAdmin))');
    expect(src).not.toMatch(/from\(\s*['"]network_administrators['"]\s*\)/);
    expect(src).toContain('const userIds = [...new Set(ids.filter(Boolean))];');
  });

  it("l'envoi reste simulé par défaut", () => {
    expect(src).toContain('const dryRun = payload.dry_run !== false;');
  });
});
