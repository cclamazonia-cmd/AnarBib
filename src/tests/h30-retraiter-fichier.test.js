// ═══════════════════════════════════════════════════════════
// AnarBib — H30 (04/10/2026) : « Retraiter » exige le fichier.
//
// La migration 20261005064758_retraiter_exige_le_fichier réécrit
// fn_import_dispatch (substitution comptée sur la définition vivante) : un
// retraitement (p_force_reparse) d'un run dont l'objet n'est pas dans
// storage.objects est refusé, RAISE … USING HINT = 'error.import.reparse_no_file'
// (convention (a) de localizeError). Ce test lit le SQL : la HINT est LEVÉE
// (commentaires SQL retirés avant la recherche), sous la condition de
// retraitement et l'absence d'objet ; le texte de remplacement rend l'ancre
// intacte ; la clé est traduite (non vide) dans les 10 locales, avec la valeur
// de scripts/i18n-add-h30.cjs, sa source.
//
// La garde i18n (i18n.test.js) ne lit pas le SQL : sans ce test, le refus
// s'afficherait en message brut portugais.
//
// Contre-épreuve (04/10/2026, miroir hors dépôt) : la ligne USING HINT mise en
// commentaire → « LÈVE », « seule HINT » et « sous la condition » tombent ; les locales
// du commit 07111e3d (sans la clé) → les 10 « traduite » et les 10 « valeur du
// script » tombent.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const MIGRATION = '20261005064758_retraiter_exige_le_fichier.sql';
const HINT = 'error.import.reparse_no_file';

const lireMigration = () => readFileSync(path.resolve(__dirname, '../../supabase/migrations', MIGRATION), 'utf8');
const lireLocale = (loc) => JSON.parse(readFileSync(path.resolve(__dirname, `../i18n/locales/${loc}.json`), 'utf8'));
// Les commentaires SQL `--` retirés (aucun littéral de la migration ne contient `--`).
const sansCommentaires = (sql) => sql.replace(/--[^\n]*/g, '');
// Le texte d'ancre ($a$…$a$) et son remplacement ($b$…$b$).
const morceau = (sql, tag) => {
  const m = sql.match(new RegExp(`\\$${tag}\\$([\\s\\S]*?)\\$${tag}\\$`));
  if (!m) throw new Error(`$${tag}$ introuvable dans la migration H30`);
  return m[1];
};

describe('H30 — la HINT de la migration', () => {
  it('la migration LÈVE error.import.reparse_no_file (RAISE … USING HINT, pas un commentaire)', () => {
    const code = sansCommentaires(lireMigration());
    expect(code).toMatch(/RAISE\s+EXCEPTION\s+'[^']*'\s*,\s*p_run_id\s+USING\s+HINT\s*=\s*'error\.import\.reparse_no_file'/i);
  });

  it('c\'est la seule HINT levée par la migration (les autres ne sont que vérifiées par position())', () => {
    const code = sansCommentaires(lireMigration());
    const levees = [...new Set([...code.matchAll(/hint\s*=\s*'(error\.[A-Za-z0-9_.]+)'/gi)].map((m) => m[1]))];
    expect(levees).toEqual([HINT]);
  });

  it('le refus est sous la condition de retraitement et l\'absence de l\'objet dans storage.objects', () => {
    const remplacement = sansCommentaires(morceau(lireMigration(), 'b'));
    const bloc = remplacement.match(/IF\s+coalesce\(p_force_reparse,\s*false\)([\s\S]*?)END IF;/i);
    expect(bloc, 'bloc IF coalesce(p_force_reparse, false) … END IF introuvable').not.toBeNull();
    expect(bloc[1]).toMatch(/AND\s+NOT\s+EXISTS\s*\(\s*SELECT\s+1\s+FROM\s+ingest\.partner_catalog_import_runs/i);
    expect(bloc[1]).toMatch(/JOIN\s+storage\.objects\s+o/i);
    // Le chemin comparé comme l'edge function le prend (clean() : blancs ôtés).
    expect(bloc[1]).toMatch(/o\.name\s*=\s*btrim\(\s*r\.storage_path\s*\)/i);
    expect(bloc[1]).toContain(`USING HINT = '${HINT}'`);
  });

  it('le remplacement rend l\'ancre intacte (la garde H19 qui suit n\'est pas perdue)', () => {
    const sql = lireMigration();
    const ancre = morceau(sql, 'a');
    expect(ancre.trim()).not.toBe('');
    expect(morceau(sql, 'b').endsWith(ancre)).toBe(true);
  });

  it.each(LOCALES)('%s — la HINT est traduite (texte non vide)', (loc) => {
    const d = lireLocale(loc);
    expect(typeof d[HINT]).toBe('string');
    expect(d[HINT].trim()).not.toBe('');
  });
});

describe('H30 — le script est la source de la clé', () => {
  // L'objet CLES du script, lu comme DONNÉES : le script écrit les locales dès
  // qu'on le charge, il n'est donc pas importé.
  const cles = () => {
    const src = readFileSync(path.resolve(__dirname, '../../scripts/i18n-add-h30.cjs'), 'utf8');
    const debut = src.indexOf('const CLES = {');
    const fin = src.indexOf('\n};\n', debut);
    expect(debut, 'const CLES introuvable dans le script').toBeGreaterThanOrEqual(0);
    expect(fin, 'fin de CLES introuvable dans le script').toBeGreaterThan(debut);
    return Function(`return ${src.slice(debut + 'const CLES = '.length, fin + 2)};`)();
  };

  it('le script porte la seule clé H30, dans les 10 langues', () => {
    const c = cles();
    expect(Object.keys(c)).toEqual([HINT]);
    expect(Object.keys(c[HINT]).sort()).toEqual([...LOCALES].sort());
  });

  it.each(LOCALES)('%s — la clé porte la valeur du script (le script a été joué)', (loc) => {
    expect(lireLocale(loc)[HINT]).toBe(cles()[HINT][loc]);
  });
});
