// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/privacidade-un-seul-message-sur-la-purge.test.js
//
// CE QUE CE TEST PROTÈGE (E16, 21/09/2026). La refonte du Manuel v5 (01/09) avait
// relevé « deux messages contradictoires sur l'activation de la purge
// automatique » dans la sous-page Confidentialité de la Bibliothèque. Constat :
//   * l'écran n'en affiche qu'UN depuis le 03/06 (`8d3dd444`) — « la suppression
//     automatique est active » ;
//   * le second, « pas encore active, elle le sera en Phase 4b », n'était plus
//     employé nulle part mais vivait toujours dans les dix fichiers de langue :
//     c'est là que le manuel l'a lu ;
//   * et le message affiché DIT VRAI : le cron `anarbib-rgpd-purge-weekly` est
//     actif en production, avec `p_dry_run := false` (16 passages au 21/09, le
//     dernier la veille, réussi).
// La clé morte est retirée. Ce test garde les trois faits ensemble : si un jour
// la purge cesse d'être planifiée pour de bon, le bandeau ne doit pas continuer
// à l'affirmer — et l'ancien message ne doit pas revenir par un copier-coller.

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const racine = path.resolve(here, '..', '..');
const lire = (rel) => readFileSync(path.resolve(racine, rel), 'utf8');

const section = lire('src/components/library/RetentionPolicySection.jsx');
const dirLocales = path.resolve(racine, 'src/i18n/locales');
const locales = readdirSync(dirLocales).filter((f) => f.endsWith('.json'));

describe('Bibliothèque › Confidentialité — un seul message sur la purge, et il dit vrai (E16)', () => {
  it("l'écran affiche le bandeau « purge active », une fois, sans condition cachée", () => {
    expect(section.split("biblioteca.privacy.purgeActiveNotice").length - 1).toBe(1);
    expect(section).not.toContain('phase4a');
  });

  it("le message « pas encore active » n'existe plus dans aucune des dix locales", () => {
    expect(locales).toHaveLength(10);
    for (const f of locales) {
      const m = JSON.parse(readFileSync(path.join(dirLocales, f), 'utf8'));
      expect(Object.keys(m).filter((k) => /phase4a/i.test(k)), f).toEqual([]);
      expect(m['biblioteca.privacy.purgeActiveNotice'], f).toBeTruthy();
      // aucune valeur de la sous-page ne renvoie encore à une « Phase 4b » à venir
      const perime = Object.keys(m).filter((k) => k.startsWith('biblioteca.privacy.') && /4b\b/i.test(String(m[k])));
      expect(perime, f).toEqual([]);
    }
  });

  it('le bandeau dit vrai : la purge est planifiée pour de bon, pas à blanc', () => {
    // la planification vit au socle ; la liste fermée des crons la garde en CI
    const socle = lire('supabase/migrations/20260510000000_baseline_live.sql');
    expect(socle).toMatch(/'anarbib-rgpd-purge-weekly','0 3 \* \* 0','SELECT public\.fn_purge_expired_data\(p_dry_run := false\);', true/);
    const garde = lire('tests/sql/crons_planifies_tests.sql');
    expect(garde).toMatch(/'anarbib-rgpd-purge-weekly',\s*'0 3 \* \* 0',\s*true/);
    // et aucune migration ultérieure ne la déplanifie ni ne la repasse à blanc
    const dirMig = path.resolve(racine, 'supabase/migrations');
    for (const f of readdirSync(dirMig).filter((x) => /^\d{14}_.*\.sql$/.test(x) && !x.startsWith('20260510000000'))) {
      const sql = readFileSync(path.join(dirMig, f), 'utf8');
      if (!sql.includes('anarbib-rgpd-purge-weekly')) continue;
      expect(sql, f).not.toMatch(/unschedule\(\s*'anarbib-rgpd-purge-weekly'/);
      expect(sql, f).not.toMatch(/fn_purge_expired_data\(\s*p_dry_run\s*:=\s*true/);
    }
  });
});
