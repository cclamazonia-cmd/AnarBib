// ═══════════════════════════════════════════════════════════
// AnarBib — I30 (05/10/2026) : une restauration rend une base qui sert.
//
// Les deux flux #BG2 étaient pris en --no-privileges, et les schémas private
// et api n'étaient dans aucun flux. Mesuré au banc le 05/10 (dump de
// structure des quatre schémas, rejoué, empreinte des droits et des objets
// comparée à la production) : 2 empreintes identiques sur 19 avec les flux
// d'alors. Avec les privilèges seuls, 13 / 19 : une instance neuve accorde
// d'office des droits à chaque objet créé (anon EXECUTE sur des fonctions
// SECURITY DEFINER…) et le dump ne les retire pas. Avec la repose
// (bg2-repose-droits.sh), 19 / 19 sur l'image Supabase de la production ;
// 18 / 19 sur un Postgres nu, la seule différence étant les privilèges par
// défaut de supabase_admin, rôle de la plateforme.
//
// Ce banc garde : les dumps sans --no-privileges, private et api au flux long,
// la repose (exécutée pour de vrai sur des dumps factices), et restore-test
// qui repose les droits puis compare l'empreinte à la production.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, rmSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

const RACINE = path.resolve(__dirname, '../..');
const chemin = (rel) => path.join(RACINE, rel);
const lire = (rel) => readFileSync(chemin(rel), 'utf8');
const SCRIPT = lire('deploy/ops/anarbib-bg2.sh');
const REPOSE = chemin('deploy/ops/bg2-repose-droits.sh');
const EMPREINTE = lire('deploy/ops/bg2-empreinte-droits.sql');

function fonction(source, nom) {
  const bloc = source.match(new RegExp(`^${nom}\\(\\) \\{[\\s\\S]*?^\\}`, 'm'));
  if (!bloc) throw new Error(`fonction introuvable : ${nom}`);
  return bloc[0];
}

describe('I30 — les flux portent leurs droits, private et api compris (source)', () => {
  it('aucun pg_dump du script n’est pris en --no-privileges', () => {
    const dumps = SCRIPT.split('\n').filter((l) => /^\s*pg_dump /.test(l));
    expect(dumps.length).toBeGreaterThanOrEqual(2);
    for (const d of dumps) expect(d).not.toContain('--no-privileges');
  });

  it('le long et le court refusent un dump sans GRANT', () => {
    expect(fonction(SCRIPT, 'backup_long')).toContain('aucun GRANT dans le dump long');
    expect(fonction(SCRIPT, 'backup_court')).toContain('aucun GRANT dans le dump court');
  });

  it('private et api sont au flux long', () => {
    expect(SCRIPT).toMatch(/^LONG_SCHEMAS=\(public ingest private api\)$/m);
  });

  it('restore-test : extensions et fonctions auth, repose des deux dumps, empreinte comparée à la production', () => {
    const rt = fonction(SCRIPT, 'cmd_restore_test');
    for (const e of ['pg_trgm', 'unaccent', 'pgcrypto', '"uuid-ossp"']) expect(rt).toContain(`CREATE EXTENSION IF NOT EXISTS ${e}`);
    expect(rt).toContain('FUNCTION auth.jwt()');
    expect(rt).toMatch(/bg2-repose-droits\.sh" "\$long" "\$court"/);
    // la repose vient APRÈS le rejeu du court, l'empreinte après la repose
    expect(rt.indexOf('"$court" > "$dir/court.log"')).toBeLessThan(rt.indexOf('bg2-repose-droits.sh'));
    expect(rt.indexOf('bg2-repose-droits.sh')).toBeLessThan(rt.indexOf('bg2-empreinte-droits.sql'));
    expect(rt).toContain('psql "$PGCONN" -X -q -A -F \' \' -t -f "$OPS_DIR/bg2-empreinte-droits.sql"');
    expect(rt).toContain("grep -v '/defaut:supabase_admin '");
  });

  it('l’empreinte couvre les quatre schémas : fonctions (DEFINER compris), tables, vues, séquences, schémas, défauts', () => {
    expect(EMPREINTE).toContain("('public', 'ingest', 'private', 'api')");
    for (const k of ["'fonctions'", "'tables'", "'vues'", "'sequences'", "'schema'", "'defaut:'"]) expect(EMPREINTE).toContain(k);
    expect(EMPREINTE).toContain("' DEFINER'");
    // le concédant (grantor) n'entre pas dans l'empreinte : seul compte qui a quel droit
    expect(EMPREINTE).toContain('pg_get_userbyid(a.grantee)');
    expect(EMPREINTE).not.toContain('a.grantor');
  });

  it('le runbook dit les extensions, la repose et le contrôle', () => {
    const rb = lire('docs/journal/operations/RUNBOOK_restauration_BG2_2026-07-01.md');
    expect(rb).toContain('3.2-quater');
    expect(rb).toContain('bg2-repose-droits.sh');
    expect(rb).toContain('bg2-empreinte-droits.sql');
    expect(rb).toMatch(/CREATE EXTENSION IF NOT EXISTS pg_trgm/);
  });
});

const BASH = process.platform === 'win32' ? null : 'bash';
let racine;
beforeAll(() => { if (BASH) racine = mkdtempSync(path.join(tmpdir(), 'anarbib-i30-')); });
afterAll(() => { if (racine) rmSync(racine, { recursive: true, force: true }); });

function repose(dumps, env = {}) {
  const fichiers = dumps.map((contenu, i) => {
    const f = path.join(racine, `dump-${i}-${Math.random().toString(36).slice(2)}.sql`);
    writeFileSync(f, contenu);
    return f;
  });
  try {
    return { code: 0, sortie: execFileSync(BASH, [REPOSE, ...fichiers], { encoding: 'utf8', env: { ...process.env, ...env }, stdio: ['pipe', 'pipe', 'pipe'] }) };
  } catch (e) {
    return { code: e.status, sortie: `${e.stdout || ''}${e.stderr || ''}` };
  }
}

const LONG = [
  'CREATE TABLE public.books (id bigint);',
  'REVOKE ALL ON FUNCTION public.fn_secrete(uuid) FROM PUBLIC;',
  'GRANT ALL ON FUNCTION public.fn_secrete(uuid) TO service_role;',
  'GRANT SELECT ON TABLE public.books TO anon;',
  'GRANT USAGE ON SCHEMA api TO anon;',
  'GRANT ALL ON TABLE public_bis.t TO anon;',
  'ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO anon;',
  'ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO service_role;',
  '',
].join('\n');
const COURT = [
  'GRANT SELECT ON TABLE public.profiles TO authenticated;',
  'GRANT ALL ON TABLE auth.users TO dashboard_user;',
  '',
].join('\n');

describe.skipIf(!BASH)('I30 — bg2-repose-droits.sh, exécuté', () => {
  it('remet chaque schéma aux droits par défaut de Postgres AVANT de rejouer ceux du dump, dans une transaction', () => {
    const r = repose([LONG, COURT]);
    expect(r.code, r.sortie).toBe(0);
    const l = r.sortie.split('\n');
    expect(l.find((x) => x.trim() && !x.startsWith('--'))).toBe('BEGIN;');
    expect(l.filter(Boolean).at(-1)).toBe('COMMIT;');
    for (const s of ['public', 'ingest', 'private', 'api']) {
      expect(l).toContain(`REVOKE ALL ON ALL TABLES    IN SCHEMA ${s} FROM PUBLIC, anon, authenticated, service_role;`);
      expect(l).toContain(`REVOKE ALL ON ALL ROUTINES  IN SCHEMA ${s} FROM anon, authenticated, service_role;`);
      expect(l).toContain(`GRANT EXECUTE ON ALL ROUTINES IN SCHEMA ${s} TO PUBLIC;`);
    }
    const derniereRemise = Math.max(...l.map((x, i) => (/^(REVOKE ALL ON ALL|GRANT EXECUTE ON ALL|ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA \w+ REVOKE)/.test(x) ? i : -1)));
    expect(derniereRemise).toBeLessThan(l.indexOf('GRANT SELECT ON TABLE public.books TO anon;'));
  });

  it('rejoue les droits des quatre schémas, des DEUX dumps — et seulement eux', () => {
    const r = repose([LONG, COURT]);
    for (const x of ['REVOKE ALL ON FUNCTION public.fn_secrete(uuid) FROM PUBLIC;', 'GRANT ALL ON FUNCTION public.fn_secrete(uuid) TO service_role;',
      'GRANT SELECT ON TABLE public.books TO anon;', 'GRANT USAGE ON SCHEMA api TO anon;', 'GRANT SELECT ON TABLE public.profiles TO authenticated;',
      'ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO service_role;']) {
      expect(r.sortie, x).toContain(x);
    }
    // auth.* (rôles et propriétaire de la plateforme), un schéma au nom voisin,
    // et les défauts de supabase_admin : jamais rejoués par `postgres`
    expect(r.sortie).not.toContain('auth.users');
    expect(r.sortie).not.toContain('public_bis');
    expect(r.sortie).not.toContain('FOR ROLE supabase_admin');
  });

  it('BG2_SCHEMAS restreint les schémas remis à zéro et rejoués', () => {
    const r = repose([LONG], { BG2_SCHEMAS: 'public' });
    expect(r.sortie).toContain('IN SCHEMA public FROM');
    expect(r.sortie).not.toContain('IN SCHEMA api');
    expect(r.sortie).not.toContain('GRANT USAGE ON SCHEMA api TO anon;');
  });

  it('refuse un dump pris en --no-privileges, et un dump introuvable', () => {
    const sans = repose(['CREATE TABLE public.books (id bigint);\n']);
    expect(sans.code).toBe(3);
    expect(sans.sortie).toMatch(/aucun GRANT ni REVOKE : pris en --no-privileges \? \(repose impossible\)/);
    let code = 0;
    try { execFileSync(BASH, [REPOSE, path.join(racine, 'absent.sql')], { stdio: 'pipe' }); } catch (e) { code = e.status; }
    expect(code).toBe(2);
  });
});
