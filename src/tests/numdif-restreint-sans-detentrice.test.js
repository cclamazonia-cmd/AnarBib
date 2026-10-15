// =====================================================================
// NUMDIF D19 (15/10/2026, décision du 20/08, DOC-SILENCE-1) — un PDF restreint
// dont le livre perd sa dernière détention se signale. Session : File de
// candidats PDF.
//
// Le signal et le contrôle vivent en base (tests/sql/restreint_sans_detentrice_tests.sql) ;
// ici, ce que l'écran doit en faire : la cloche traduit la notification dans
// toutes les locales et mène à la fiche du livre.
// =====================================================================
import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';

const RACINE = path.resolve(__dirname, '../..');
const CLOCHE = readFileSync(path.join(RACINE, 'src/components/notifications/NotificationBell.jsx'), 'utf8');
const MIGRATION = readFileSync(path.join(RACINE, 'supabase/migrations/20261015202816_restreint_sans_detentrice_observable.sql'), 'utf8');
const LOC = path.join(RACINE, 'src/i18n/locales');

describe('D19 — le signal « restreint sans détentrice » se lit', () => {
  it('la base pose les clés et le lien que la cloche connaît', () => {
    expect(MIGRATION).toContain("'notif.restrictedOrphan.title', 'notif.restrictedOrphan.body'");
    expect(MIGRATION).toContain("'restricted_without_holder', OLD.book_id::text");
    expect(CLOCHE).toMatch(/case 'restricted_without_holder':\s*\n\s*return n\.link_id \? `\/livro\/\$\{n\.link_id\}` : null;/);
  });

  for (const f of readdirSync(LOC).filter((x) => x.endsWith('.json'))) {
    it(`${f} : titre et corps de la notification traduits`, () => {
      const j = JSON.parse(readFileSync(path.join(LOC, f), 'utf8'));
      expect(j['notif.restrictedOrphan.title']).toBeTruthy();
      expect(j['notif.restrictedOrphan.body']).toBeTruthy();
    });
  }
});
