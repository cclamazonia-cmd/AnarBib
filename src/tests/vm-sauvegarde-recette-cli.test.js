// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/vm-sauvegarde-recette-cli.test.js
//
// deploy/ops/vm/anarbib-vm-sauvegarde.sh produit, dans le conteneur db d'une
// pile auto-hébergée, les trois fichiers que deploy/scripts/restore.sh attend
// — avec la recette EXACTE de `supabase db dump` (CLI v2.98.1,
// pkg/migration/dump.go et pkg/migration/scripts/dump_*.sh), parce que c'est
// cette forme-là qui a été restaurée pour de vrai (21/09/2026). Cette garde
// fige la recette : les deux listes de schémas, les filtres qui rendent le
// schéma rejouable (IF NOT EXISTS, OR REPLACE), l'en-tête qui suspend les
// triggers côté données, et les trois tables d'historique exclues. Qui monte
// la version du CLI relit dump.go et change les trois endroits ensemble.
//
// Elle tient aussi les unités systemd sur le script, et le README sur les
// mêmes noms de flux que la sonde en base (contrainte sur backup_heartbeats).

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';

const racine = new URL('../../', import.meta.url);
const lire = (p) => readFileSync(new URL(p, racine), 'utf8');
const script = lire('deploy/ops/vm/anarbib-vm-sauvegarde.sh');

// pkg/migration/dump.go, v2.98.1 — InternalSchemas (dump du schéma)
const INTERNES_CLI = [
  'information_schema', 'pg_*', '_analytics', '_realtime', '_supavisor', 'auth', 'etl',
  'extensions', 'pgbouncer', 'realtime', 'storage', 'supabase_functions', 'supabase_migrations',
  'cron', 'dbdev', 'graphql', 'graphql_public', 'net', 'pgmq', 'pgsodium', 'pgsodium_masks',
  'pgtle', 'repack', 'tiger', 'tiger_data', 'timescaledb_*', '_timescaledb_*', 'topology', 'vault',
];
// pkg/migration/dump.go, v2.98.1 — excludedSchemas (dump des données) : auth, storage,
// cron, net, pgmq et supabase_functions y restent volontairement INCLUS.
const EXCLUS_DONNEES_CLI = [
  'information_schema', 'pg_*', 'graphql', 'graphql_public', 'pgsodium', 'pgsodium_masks',
  'pgtle', 'repack', 'tiger', 'tiger_data', 'timescaledb_*', '_timescaledb_*', 'topology',
  'vault', 'etl', 'extensions', 'pgbouncer', 'realtime', 'supabase_migrations',
  '_analytics', '_realtime', '_supavisor',
];

const variable = (nom) => (script.match(new RegExp(`^${nom}='([^']+)'$`, 'm')) || [])[1]?.split('|');

describe('sauvegarde depuis la VM — la recette du CLI Supabase, figée', () => {
  it('annonce la version du CLI dont elle reproduit les dumps', () => {
    expect(script).toMatch(/^CLI_VERSION_RECETTE="v2\.98\.1"/m);
    expect(lire('.forgejo/workflows/ci.yml')).toContain('cli/releases/download/v2.98.1/');
  });

  it('exclut du schéma exactement les schémas internes du CLI', () => {
    expect(variable('CLI_SCHEMAS_INTERNES')).toEqual(INTERNES_CLI);
  });

  it('exclut des données exactement les schémas que le CLI exclut (auth et storage gardés)', () => {
    const exclus = variable('CLI_SCHEMAS_EXCLUS_DONNEES');
    expect(exclus).toEqual(EXCLUS_DONNEES_CLI);
    for (const garde of ['auth', 'storage', 'cron', 'net', 'supabase_functions']) {
      expect(exclus).not.toContain(garde);
    }
  });

  it('rend le schéma rejouable comme le CLI (IF NOT EXISTS, OR REPLACE, extensions neutralisées)', () => {
    for (const filtre of [
      'CREATE SCHEMA IF NOT EXISTS', 'CREATE TABLE IF NOT EXISTS', 'CREATE SEQUENCE IF NOT EXISTS',
      'CREATE OR REPLACE VIEW', 'CREATE OR REPLACE FUNCTION', 'CREATE OR REPLACE TRIGGER',
      'CREATE EVENT TRIGGER', 'ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin"',
      'CREATE POLICY "cron_job_', 'SET transaction_timeout = 0;',
    ]) {
      expect(script).toContain(filtre);
    }
    expect(script).toMatch(/--schema-only --quote-all-identifier --role postgres --exclude-schema/);
  });

  it('suspend les triggers côté données et exclut les trois historiques, comme le CLI', () => {
    expect(script).toContain('echo "SET session_replication_role = replica;"');
    expect(script).toContain('echo "RESET ALL;"');
    for (const t of ['auth.schema_migrations', 'storage.migrations', 'supabase_functions.migrations']) {
      expect(script).toContain(`--exclude-table "${t}"`);
    }
    expect(script).toMatch(/--data-only --quote-all-identifier --role postgres/);
  });

  it('produit les quatre fichiers que restore.sh et bootstrap.sh attendent', () => {
    for (const f of ['schema.sql', 'data.sql', 'migrations.sql', 'vault.sql']) {
      expect(script).toContain(`"$d/${f}"`);
    }
    expect(script).toContain("'pseudonym_salt'");
  });

  it('témoigne sous les noms que la sonde accepte (court, long, storage, lourd)', () => {
    expect(script).toMatch(/heartbeat court started; heartbeat long started/);
    expect(script).toMatch(/heartbeat storage started; heartbeat lourd started/);
    expect(script).toMatch(/heartbeat storage ok "\$snap"; heartbeat lourd ok "\$snap"/);
    const contrainte = lire('supabase/migrations/20261018213744_le_flux_lourd_a_son_temoin.sql');
    expect(contrainte).toContain("check (flow in ('court', 'long', 'storage', 'lourd'))");
  });

  // 19/10/2026 : le fond de carte est sauvegardé par défaut (décision de
  // Xavier) ; une instance au dépôt trop petit l'exclut par MAP_TILES=exclu.
  it('sauvegarde le fond de carte par défaut, et ne l’exclut que sur MAP_TILES=exclu', () => {
    expect(script).toMatch(/MAP_TILES="\$\{MAP_TILES:-inclus\}"/);
    expect(script).toMatch(/if \[ "\$MAP_TILES" = exclu \]; then\s+exclusions=\(--exclude '\*\/map-tiles'/);
    expect(script).toMatch(/restic backup "\$point" --tag flux-vm-storage --tag anarbib-vm "\$\{exclusions\[@\]\}"/);
    expect(lire('deploy/ops/vm/sauvegarde.env.example')).toMatch(/^#MAP_TILES=exclu$/m);
  });

  it('les unités systemd appellent le script, et chaque service a son minuteur', () => {
    const dossier = new URL('deploy/ops/vm/systemd/', racine);
    const unites = readdirSync(dossier);
    const services = unites.filter((u) => u.endsWith('.service') && !u.includes('@'));
    expect(services.sort()).toEqual([
      'anarbib-vm-sauvegarde-base.service',
      'anarbib-vm-sauvegarde-prune.service',
      'anarbib-vm-sauvegarde-storage.service',
    ]);
    for (const s of services) {
      const texte = readFileSync(new URL(s, dossier), 'utf8');
      expect(texte).toContain('/opt/anarbib/deploy/ops/vm/anarbib-vm-sauvegarde.sh');
      expect(unites).toContain(s.replace('.service', '.timer'));
      expect(readFileSync(new URL(s.replace('.service', '.timer'), dossier), 'utf8')).toMatch(/OnCalendar=.* Europe\/Paris/);
    }
  });

  it('le README dit où vit la configuration et ce que le script ne fait pas', () => {
    const readme = lire('deploy/ops/vm/README.md');
    expect(readme).toContain('/etc/anarbib/sauvegarde.env');
    expect(readme).toContain('Ce que ce script ne fait pas');
    expect(lire('deploy/ops/vm/sauvegarde.env.example')).toMatch(/^RESTIC_REPOSITORY=$/m);
  });
});
