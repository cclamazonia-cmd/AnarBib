// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/import-file-kind.test.js
//
// CE QUE CE TEST PROTÈGE (H28, 26/09/2026). Le format d'un import est écrit à
// deux endroits — le front (p_detected_format de fn_import_create) et l'EF
// process-partner-catalog-import (UPDATE final du run) — et lu par une CHECK en
// base. Jusqu'au 26/09 le front envoyait 'marc21' et l'EF écrivait
// 'marc_iso2709', deux mots absents de la CHECK : AUCUN fichier ISO 2709 ne
// pouvait s'importer, et rien ne le disait (aucun run MARC n'avait jamais
// tourné). Ce test lit la CHECK dans la DERNIÈRE migration qui la pose et
// exige que chaque mot écrit y figure : une dérive rougit ici, pas en prod.

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { detectFileKind, IMPORT_FILE_KINDS, ACCEPTED_IMPORT_EXTENSIONS } from '../lib/importFileKind.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const racine = path.resolve(here, '..', '..');
const lire = (rel) => readFileSync(path.resolve(racine, rel), 'utf8');

const CONTRAINTE = 'partner_catalog_import_runs_detected_format_check';

function valeursDeLaCheck() {
  const dir = 'supabase/migrations';
  const fichiers = readdirSync(path.resolve(racine, dir))
    .filter((f) => /^\d{14}_.*\.sql$/.test(f))
    .sort();
  let derniere = null;
  for (const f of fichiers) {
    if (new RegExp(`add\\s+constraint\\s+${CONTRAINTE}`, 'i').test(lire(`${dir}/${f}`))) derniere = f;
  }
  if (!derniere) throw new Error(`aucune migration ne pose ${CONTRAINTE}`);
  const sql = lire(`${dir}/${derniere}`);
  const debut = sql.search(new RegExp(`add\\s+constraint\\s+${CONTRAINTE}`, 'i'));
  const corps = sql.slice(debut, sql.indexOf(']))', debut));
  const sansCommentaires = corps.replace(/--[^\n]*/g, '');
  return { derniere, valeurs: new Set([...sansCommentaires.matchAll(/'([a-z0-9_]+)'/g)].map((m) => m[1])) };
}

describe('format d\'import : ce que le front et l\'EF écrivent est admis par la base (H28)', () => {
  const { derniere, valeurs } = valeursDeLaCheck();

  it(`la CHECK (${derniere}) admet chaque format que le front peut envoyer`, () => {
    for (const k of IMPORT_FILE_KINDS) expect(valeurs, `front : '${k}'`).toContain(k);
  });

  it('la CHECK admet chaque format que l\'EF process-partner-catalog-import écrit', () => {
    const marc = lire('supabase/functions/process-partner-catalog-import/marc.ts');
    const index = lire('supabase/functions/process-partner-catalog-import/index.ts');
    const ecrits = new Set([
      ...[...marc.matchAll(/format:\s*'([a-z0-9_]+)'/g)].map((m) => m[1]),
      ...[...index.matchAll(/detectedFormat\s*=\s*'([a-z0-9_]+)'/g)].map((m) => m[1]),
      ...[...index.matchAll(/\?\s*'([a-z0-9_]+)'\s*:\s*'([a-z0-9_]+)'/g)].flatMap((m) => [m[1], m[2]])
        .filter((v) => ['csv', 'tsv'].includes(v)),
    ]);
    expect([...ecrits].sort()).toEqual(expect.arrayContaining(['csv', 'marc_iso2709', 'marcxml', 'ris', 'tsv']));
    for (const f of ecrits) expect(valeurs, `EF : '${f}'`).toContain(f);
  });

  it('un fichier MARC binaire est « marc_iso2709 », jamais un vocabulaire (marc21/unimarc)', () => {
    for (const nom of ['catalogue.mrc', 'EXPORT.MARC', 'dira.iso', 'export489681.marc']) {
      expect(detectFileKind(nom)).toBe('marc_iso2709');
    }
    expect(valeurs.has('marc21')).toBe(false);
    expect(valeurs.has('unimarc')).toBe(false);
    expect(detectFileKind('notices.marcxml')).toBe('marcxml');
    expect(detectFileKind('notices.xml')).toBe('xml');
    expect(detectFileKind('inconnu.bin')).toBe('unknown');
  });

  it('la page et l\'assistant n\'ont plus leur propre copie, et acceptent le suffixe .iso', () => {
    for (const rel of ['src/pages/importacoes/ImportacoesPage.jsx', 'src/pages/importacoes/ImportWizard.jsx']) {
      const src = lire(rel);
      expect(src, rel).not.toMatch(/function detectFileKind/);
      expect(src, rel).toContain("from '../../lib/importFileKind.js'");
      expect(src, rel).not.toContain("'marc21';");
    }
    expect(ACCEPTED_IMPORT_EXTENSIONS.split(',')).toEqual(expect.arrayContaining(['.mrc', '.marc', '.iso', '.marcxml']));
    expect(lire('src/pages/importacoes/ImportWizard.jsx')).toMatch(/accept="[^"]*\.iso[^"]*"/);
  });
});
