// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/bg2-ingest-flux-long.test.js
//
// CE QUE CE TEST PROTÈGE (BG2-13, décision de Xavier du 05/10/2026). Le schéma
// `ingest` (import catalogue : sources, lots, lignes de staging, bases d'import
// H21) devait aller au flux long depuis le cadrage du 30/06 ; la ligne BG2-13
// du registre disait ✅, mais deploy/ops/anarbib-bg2.sh faisait
// `pg_dump --schema=public` et son filet ne lisait que `public` : AUCUN flux ne
// sauvegardait ingest. Désormais :
//   - le flux long prend public ET ingest, dans le MÊME fichier anarbib-long.sql
//     (un second fichier ouvrirait une lignée restic neuve, piège BG2-15) ;
//   - les listes (classement, denylist, exclusions) acceptent des noms
//     qualifiés : `books` = public.books, `ingest.<table>` = son schéma ;
//   - le filet compare les tables de public ET d'ingest au classement ;
//   - le classement contient les 13 tables d'ingest (11, puis H21 lot 5 le 07/10/2026,
//     puis H21 lot 6b le 08/10/2026) ;
//   - la CI (scripts/ci/run-sql-suites.sh) et le poste lisent le classement
//     avec les MÊMES fonctions, ici extraites telles quelles et exécutées.
// Les fonctions du script sont éprouvées en bash, avec pg_dump, psql et restic
// remplacés par des doublures : aucun tir réel, aucune base.

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, readFileSync, readdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const lire = (rel) => readFileSync(fileURLToPath(new URL(`../../${rel}`, import.meta.url)), 'utf8');
const SCRIPT = lire('deploy/ops/anarbib-bg2.sh');
const CI = lire('scripts/ci/run-sql-suites.sh');
const CLASSEMENT = lire('deploy/bg2-known-tables.txt');

const INGEST_ATTENDUES = [
  'ingest.book_import_baselines',
  'ingest.book_import_divergences',   // H21 lot 5 (07/10/2026)
  'ingest.exemplar_import_baselines', // H21 lot 6b (08/10/2026)
  'ingest.import_profiles',
  'ingest.oai_harvest_state',
  'ingest.partner_catalog_import_dispatch_log',
  'ingest.partner_catalog_import_files',
  'ingest.partner_catalog_import_runs',
  'ingest.partner_catalog_match_candidates',
  'ingest.partner_catalog_received_assets',
  'ingest.partner_catalog_row_to_draft',
  'ingest.partner_catalog_sources',
  'ingest.partner_catalog_staging_rows',
];

function fonction(source, nom) {
  const ligne = source.match(new RegExp(`^${nom}\\(\\) +\\{.*\\}$`, 'm'));
  if (ligne) return ligne[0];
  const bloc = source.match(new RegExp(`^${nom}\\(\\) \\{[\\s\\S]*?^\\}`, 'm'));
  if (!bloc) throw new Error(`fonction introuvable : ${nom}`);
  return bloc[0];
}
function ligneConfig(source, nom) {
  const m = source.match(new RegExp(`^${nom}=.*$`, 'm'));
  if (!m) throw new Error(`réglage introuvable : ${nom}`);
  return m[0];
}

describe('BG2-13 — ingest au flux long (source)', () => {
  it('le flux long déclare public ET ingest, et le pg_dump les prend dans le même fichier anarbib-long.sql', () => {
    // I30 (05/10/2026) : private et api entrent au flux long.
    expect(ligneConfig(SCRIPT, 'LONG_SCHEMAS')).toBe('LONG_SCHEMAS=(public ingest private api)');
    const corps = fonction(SCRIPT, 'backup_long');
    expect(corps).toContain('local dump="$WORK/anarbib-long.sql"');
    expect(corps).toMatch(/for s in "\$\{LONG_SCHEMAS\[@\]\}"; do SCHEMAS\+=\(--schema="\$s"\); done/);
    const dumps = corps.match(/^\s*pg_dump .*$/gm);
    expect(dumps).toHaveLength(1);
    expect(dumps[0]).toContain('"${SCHEMAS[@]}"');
    expect(dumps[0]).toContain('--file="$dump"');
    expect(dumps[0]).not.toContain('--schema=public');
    // le même envoi restic qu'avant : la lignée du dépôt long ne change pas
    expect(corps).toMatch(/restic backup "\$dump" "\$vault" --tag flux-long --tag bg2/);
  });

  it('les exclusions et l’allowlist du court passent par bg2_qualifier, plus aucun préfixe public. en dur', () => {
    for (const f of ['backup_long', 'backup_court']) {
      const corps = fonction(SCRIPT, f);
      expect(corps, f).not.toMatch(/"public\.\$t"/);
      expect(corps, f).toContain('"$(bg2_qualifier "$t")"');
    }
  });

  it('le filet et la CI lisent public ET ingest avec des définitions identiques', () => {
    for (const f of ['bg2_sql_tables', 'bg2_normaliser']) {
      expect(fonction(CI, f), f).toBe(fonction(SCRIPT, f));
    }
    const sql = fonction(SCRIPT, 'bg2_sql_tables');
    expect(sql).toContain("n.nspname in ('public', 'ingest', 'private', 'api')");
    expect(sql).toContain("when n.nspname = 'public' then c.relname else n.nspname || '.' || c.relname");
    expect(fonction(SCRIPT, 'real_tables')).toContain('"$(bg2_sql_tables)" | bg2_normaliser');
    expect(CI).toContain('PT -At -c "$(bg2_sql_tables)" | bg2_normaliser > /tmp/bg2-real.txt');
    expect(CI).toContain('bg2_normaliser < "$KNOWN" > /tmp/bg2-known.txt');
    expect(CI).not.toMatch(/nspname = 'public' and c\.relkind = 'r'/);
  });

  it('le classement contient les 13 tables d’ingest, qualifiées, et public reste en noms nus', () => {
    const lignes = CLASSEMENT.split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
    const ingest = lignes.filter((l) => l.startsWith('ingest.')).sort();
    expect(ingest).toEqual(INGEST_ATTENDUES);
    expect(lignes.filter((l) => l.includes('.') && !l.startsWith('ingest.'))).toEqual([]);
    expect(lignes).not.toContain('book_import_baselines');
    expect(lignes).toContain('books');
  });

  it('les 13 tables classées sont exactement celles que les migrations créent dans ingest', () => {
    const dir = fileURLToPath(new URL('../../supabase/migrations', import.meta.url));
    const creees = new Set();
    for (const f of readdirSync(dir).filter((x) => /^[0-9].*\.sql$/.test(x))) {
      const sql = readFileSync(path.join(dir, f), 'utf8');
      for (const m of sql.matchAll(/CREATE TABLE (?:IF NOT EXISTS )?"?ingest"?\."?([a-z0-9_]+)"?/g)) creees.add(`ingest.${m[1]}`);
      expect(sql, f).not.toMatch(/DROP TABLE (?:IF EXISTS )?"?ingest"?\./);
    }
    expect([...creees].sort()).toEqual(INGEST_ATTENDUES);
  });
});

const BASH = process.platform === 'win32' ? null : 'bash';
const outilsPresents = BASH ? (() => {
  try { execFileSync(BASH, ['-c', 'command -v comm && command -v sed && command -v sort'], { stdio: 'ignore' }); return true; } catch { return false; }
})() : false;

let racine;
let harnaisPoste;
let harnaisCi;
// Une fonction introuvable (script d'avant BG2-13) fait échouer chaque test
// fonctionnel au lieu de sauter tout le fichier : les tests de source, eux,
// disent alors chacun ce qui manque.
let erreurHarnais;

beforeAll(() => {
  if (!outilsPresents) return;
  racine = mkdtempSync(path.join(tmpdir(), 'anarbib-bg2-ingest-'));
  try { construireHarnais(); } catch (e) { erreurHarnais = e; }
});

function construireHarnais() {
  const poste = ['die', 'info', 'bg2_sql_tables', 'bg2_normaliser', 'bg2_qualifier', 'real_tables', 'filet',
    'backup_long', 'attendu_apres_restauration'].map((f) => fonction(SCRIPT, f)).join('\n');
  harnaisPoste = path.join(racine, 'poste.sh');
  writeFileSync(harnaisPoste, [
    '#!/bin/bash',
    'set -euo pipefail',
    'OPS_DIR="$1"; WORK="$OPS_DIR/.work"; mkdir -p "$WORK"',
    'DENYLIST="$OPS_DIR/denylist.txt"; EXCLUDELONG="$OPS_DIR/exclude-long.txt"; KNOWN="$OPS_DIR/known.txt"',
    'PGCONN="host=doublure"; RESTIC_BASE="doublure:"',
    ligneConfig(SCRIPT, 'LONG_SCHEMAS'),
    ligneConfig(SCRIPT, 'PII_CANARIES'),
    poste,
    // doublures : rien ne sort de la machine
    'preflight() { :; }; heartbeat() { :; }; unlock_stale() { :; }; snapshot_id_de() { :; }',
    'dump_vault() { echo "select vault.create_secret(1);" > "$1"; }',
    'psql() { cat "$OPS_DIR/tables-reelles.txt"; }',
    'restic() { printf "%s\\n" "$*" >> "$OPS_DIR/restic.log"; }',
    'pg_dump() {',
    '  printf "%s\\n" "$@" > "$OPS_DIR/pg_dump.args"',
    '  local a f=""; for a in "$@"; do case "$a" in --file=*) f="${a#--file=}" ;; esac; done',
    '  cp "$OPS_DIR/faux-dump.sql" "$f"',
    '}',
    'case "$2" in',
    '  backup_long) backup_long ;;',
    '  filet) filet ;;',
    '  normaliser) bg2_normaliser ;;',
    '  sql) bg2_sql_tables ;;',
    '  qualifier) bg2_qualifier "$3" ;;',
    '  attendu) attendu_apres_restauration "$3" ;;',
    'esac',
    '',
  ].join('\n'), { mode: 0o755 });
  harnaisCi = path.join(racine, 'ci.sh');
  writeFileSync(harnaisCi, [
    '#!/bin/bash',
    'set -uo pipefail', // comme run-sql-suites.sh
    fonction(CI, 'bg2_sql_tables'),
    fonction(CI, 'bg2_normaliser'),
    'case "$1" in normaliser) bg2_normaliser ;; sql) bg2_sql_tables ;; esac',
    '',
  ].join('\n'), { mode: 0o755 });
}

afterAll(() => {
  if (racine) rmSync(racine, { recursive: true, force: true });
});

function lancer(harnais, args, entree) {
  if (erreurHarnais) throw erreurHarnais;
  try {
    const sortie = execFileSync(BASH, [harnais, ...args], { encoding: 'utf8', input: entree ?? '', stdio: ['pipe', 'pipe', 'pipe'] });
    return { code: 0, sortie };
  } catch (e) {
    return { code: e.status, sortie: `${e.stdout || ''}${e.stderr || ''}` };
  }
}

const REELLES = ['books', 'profiles', 'user_library_memberships', 'team_notification_outbox',
  'ingest.book_import_baselines', 'ingest.secret_test', 'ingest.partner_catalog_import_dispatch_log'];

function poste(cas, { reelles = REELLES, known = REELLES, denylist, dump } = {}) {
  const ops = path.join(racine, cas);
  mkdirSync(ops, { recursive: true });
  writeFileSync(path.join(ops, 'tables-reelles.txt'), `${reelles.join('\n')}\n`);
  writeFileSync(path.join(ops, 'known.txt'), `${known.join('\n')}\n`);
  writeFileSync(path.join(ops, 'denylist.txt'), denylist ?? 'profiles\nuser_library_memberships\ningest.secret_test\n');
  writeFileSync(path.join(ops, 'exclude-long.txt'),
    '# transitoires (BG2-14)\nteam_notification_outbox\r\ningest.partner_catalog_import_dispatch_log   # journal d\'envoi\n\n');
  writeFileSync(path.join(ops, 'faux-dump.sql'), dump ?? [
    'CREATE TABLE public.books (', '    id bigint', ');',
    'CREATE TABLE ingest.book_import_baselines (', '    id bigint', ');',
    'COPY ingest.book_import_baselines (id) FROM stdin;', '1', '\\.', '',
    // I30 : private et api n'ont que des vues et des fonctions ; et les droits sont là.
    'CREATE VIEW private.catalog_public_rows AS', ' SELECT 1;',
    'CREATE FUNCTION api.catalog_works_v1() RETURNS integer', '    LANGUAGE sql', '    AS $$ select 1 $$;',
    'GRANT SELECT ON TABLE public.books TO anon;', '',
  ].join('\n'));
  return ops;
}

describe.skipIf(!outilsPresents)('BG2-13 — fonctions réelles du script, doublures pour pg_dump/psql/restic', () => {
  it('backup_long : un seul pg_dump, --schema=public ET --schema=ingest, un seul --file = anarbib-long.sql, envoyé avec le Vault', () => {
    const ops = poste('long-ok');
    const r = lancer(harnaisPoste, [ops, 'backup_long']);
    expect(r.code, r.sortie).toBe(0);
    const args = readFileSync(path.join(ops, 'pg_dump.args'), 'utf8').split('\n').filter(Boolean);
    expect(args.filter((a) => a.startsWith('--schema='))).toEqual(['--schema=public', '--schema=ingest', '--schema=private', '--schema=api']);
    expect(args.filter((a) => a.startsWith('--file='))).toEqual([`--file=${ops}/.work/anarbib-long.sql`]);
    expect(args).toContain('--no-owner');
    // I30 : les droits voyagent avec le dump.
    expect(args).not.toContain('--no-privileges');
    expect(r.sortie).toMatch(/Dump long OK : 2 tables \(public 1, ingest 1\)/);
    const restic = readFileSync(path.join(ops, 'restic.log'), 'utf8').split('\n').filter(Boolean);
    expect(restic[0]).toBe(`backup ${ops}/.work/anarbib-long.sql ${ops}/.work/anarbib-vault.sql --tag flux-long --tag bg2`);
  });

  it('exclusions : noms nus → public., noms qualifiés gardés, commentaires et espaces ignorés', () => {
    const ops = poste('long-exclusions');
    expect(lancer(harnaisPoste, [ops, 'backup_long']).code).toBe(0);
    const excl = readFileSync(path.join(ops, 'pg_dump.args'), 'utf8').split('\n').filter((a) => a.startsWith('--exclude-table='));
    expect(excl.sort()).toEqual([
      '--exclude-table=ingest.partner_catalog_import_dispatch_log',
      '--exclude-table=ingest.secret_test',
      '--exclude-table=public.profiles',
      '--exclude-table=public.team_notification_outbox',
      '--exclude-table=public.user_library_memberships',
    ]);
    expect(lancer(harnaisPoste, [ops, 'qualifier', 'books']).sortie).toBe('public.books\n');
    expect(lancer(harnaisPoste, [ops, 'qualifier', 'ingest.import_profiles']).sortie).toBe('ingest.import_profiles\n');
  });

  it('anti-fuite : une table exclue d’ingest présente dans le dump annule l’envoi', () => {
    const ops = poste('long-fuite-ingest', {
      dump: 'CREATE TABLE public.books (\n);\nCREATE TABLE ingest.book_import_baselines (\n);\nCREATE TABLE ingest.secret_test (\n);\n',
    });
    const r = lancer(harnaisPoste, [ops, 'backup_long']);
    expect(r.code).not.toBe(0);
    expect(r.sortie).toMatch(/FUITE : table exclue ingest\.secret_test presente dans le dump long — ANNULE\./);
    expect(() => readFileSync(path.join(ops, 'restic.log'))).toThrow();
  });

  it('anti-fuite : les témoins PII de public annulent toujours l’envoi', () => {
    const ops = poste('long-fuite-public', {
      dump: 'CREATE TABLE public.books (\n);\nCREATE TABLE public.profiles (\n);\nCREATE TABLE ingest.book_import_baselines (\n);\n',
    });
    const r = lancer(harnaisPoste, [ops, 'backup_long']);
    expect(r.code).not.toBe(0);
    expect(r.sortie).toMatch(/FUITE PII dans le dump long — ANNULE\./);
  });

  it('un dump sans ingest n’est pas une sauvegarde complète : envoi annulé', () => {
    const ops = poste('long-sans-ingest', { dump: 'CREATE TABLE public.books (\n);\n' });
    const r = lancer(harnaisPoste, [ops, 'backup_long']);
    expect(r.code).not.toBe(0);
    expect(r.sortie).toMatch(/schema ingest ABSENT du dump long — ANNULE\./);
  });

  it('I30 : un schéma sans table (api) se reconnaît à ses vues ou fonctions ; absent, l’envoi est annulé', () => {
    const sansApi = poste('long-sans-api', {
      dump: 'CREATE TABLE public.books (\n);\nCREATE TABLE ingest.book_import_baselines (\n);\nCREATE VIEW private.v AS\n SELECT 1;\nGRANT SELECT ON TABLE public.books TO anon;\n',
    });
    const r = lancer(harnaisPoste, [sansApi, 'backup_long']);
    expect(r.code).not.toBe(0);
    expect(r.sortie).toMatch(/schema api ABSENT du dump long — ANNULE\./);
  });

  it('I30 : un dump sans aucun GRANT (un --no-privileges revenu) annule l’envoi', () => {
    const ops = poste('long-sans-droits', {
      dump: 'CREATE TABLE public.books (\n);\nCREATE TABLE ingest.book_import_baselines (\n);\nCREATE VIEW private.v AS\n SELECT 1;\nCREATE FUNCTION api.f() RETURNS integer\n    AS $$ select 1 $$;\n',
    });
    const r = lancer(harnaisPoste, [ops, 'backup_long']);
    expect(r.code).not.toBe(0);
    expect(r.sortie).toMatch(/aucun GRANT dans le dump long \(--no-privileges \?\) — ANNULE\./);
    expect(() => readFileSync(path.join(ops, 'restic.log'))).toThrow();
  });

  it('filet : une table d’ingest non classée bloque, nommée qualifiée ; classée, le filet passe', () => {
    const ops = poste('filet-nouvelle', { reelles: [...REELLES, 'ingest.nouvelle'] });
    const r = lancer(harnaisPoste, [ops, 'filet']);
    expect(r.code).not.toBe(0);
    expect(r.sortie).toMatch(/TABLES NON CLASSEES[\s\S]*- ingest\.nouvelle/);
    expect(r.sortie).not.toMatch(/- book_import_baselines/);
    const ok = lancer(harnaisPoste, [poste('filet-ok'), 'filet']);
    expect(ok.code, ok.sortie).toBe(0);
    expect(ok.sortie).toMatch(/Filet OK/);
  });

  it('filet : l’ancien classement (public seul) ne suffit plus — ingest non classé bloque', () => {
    const ops = poste('filet-ancien', { known: REELLES.filter((t) => !t.startsWith('ingest.')) });
    const r = lancer(harnaisPoste, [ops, 'filet']);
    expect(r.code).not.toBe(0);
    expect(r.sortie).toMatch(/- ingest\.book_import_baselines/);
  });

  it('filet : une entrée qualifiée de la denylist introuvable en base est signalée', () => {
    const ops = poste('filet-gone', { denylist: 'profiles\ningest.disparue\n' });
    const r = lancer(harnaisPoste, [ops, 'filet']);
    expect(r.code).not.toBe(0);
    expect(r.sortie).toMatch(/denylist : tables introuvables en base :\n {4}- ingest\.disparue/);
  });

  it('la CI et le poste normalisent le classement à l’identique (fichier réel et cas tordus)', () => {
    const tordu = 'books\r\n  authors  \n# commentaire\n\ningest.book_import_baselines # base H21\nbooks\nzeta\nIngest\n';
    const p = lancer(harnaisPoste, [racine, 'normaliser'], tordu);
    const c = lancer(harnaisCi, ['normaliser'], tordu);
    expect(p.code).toBe(0);
    expect(c.sortie).toBe(p.sortie);
    expect(p.sortie).toBe('Ingest\nauthors\nbooks\ningest.book_import_baselines\nzeta\n');
    const pr = lancer(harnaisPoste, [racine, 'normaliser'], CLASSEMENT);
    const cr = lancer(harnaisCi, ['normaliser'], CLASSEMENT);
    expect(cr.sortie).toBe(pr.sortie);
    for (const t of INGEST_ATTENDUES) expect(pr.sortie.split('\n')).toContain(t);
    expect(lancer(harnaisCi, ['sql']).sortie).toBe(lancer(harnaisPoste, [racine, 'sql']).sortie);
    // une liste vide ne fait pas mourir la CI (set -uo pipefail, pas de -e)
    expect(lancer(harnaisCi, ['normaliser'], '# rien\n\n').code).toBe(0);
  });

  it('restore-test : les attendus viennent du classement moins les exclusions du long, par schéma', () => {
    const ops = poste('attendus');
    // classement : books, profiles, user_library_memberships, team_notification_outbox (exclue)
    //              + 3 ingest dont partner_catalog_import_dispatch_log (exclue)
    expect(lancer(harnaisPoste, [ops, 'attendu', 'public']).sortie.trim()).toBe('3');
    expect(lancer(harnaisPoste, [ops, 'attendu', 'ingest']).sortie.trim()).toBe('2');
  });
});
