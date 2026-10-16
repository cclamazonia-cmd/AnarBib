import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { describe, expect, it } from 'vitest';

const bootstrap = readFileSync(resolve(process.cwd(), 'deploy/bootstrap.sh'), 'utf8');
const reference = bootstrap.match(/SANS_POLICY_ATTENDUES="([\s\S]*?)"\n\nSANS_POLICY_VUES=/)?.[1] ?? '';

describe('contrôle des tables fermées du bootstrap', () => {
  it.each([
    'ingest.book_import_divergences',
    'ingest.exemplar_import_baselines',
    'public.bug_reports',
    'public.bug_report_notification_outbox',
    'public.cover_proposals',
    'public.tombos_attribues',
  ])('référence la table protégée %s', (table) => {
    expect(reference.split('\n')).toContain(table);
  });
});
