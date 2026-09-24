// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/confirmation-deux-gestes-deux-mots.test.js
//
// CE QUE CE TEST PROTÈGE (E15, 24/09/2026). Deux gestes irréversibles de Mon compte se
// confirment en tapant un mot : « vider l'historique » (account.history.deleteAll.confirmWord)
// et « supprimer le compte » (account.deleteAccount.confirmText). Dans huit locales sur dix,
// c'était LE MÊME MOT (SUPPRIMER/SUPPRIMER, DELETE/DELETE…) : le mot appris pour vider
// l'historique ouvrait aussi la suppression du compte. Relevé par le manuel lecteur v2
// (03/09), corrigé le 24/09 sur le modèle de pt-BR (APAGAR / EXCLUIR) et de ca.
//   1. dans chaque locale, les deux mots existent, sont en capitales et diffèrent ;
//   2. la page compare la saisie au mot de SA locale, et à rien d'autre : l'historique
//      tolère la casse (toUpperCase), le compte exige le mot exact — deux pages.
// Un test de source n'est pas un test de rendu : le rendu se vérifie à l'écran.

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const racine = path.resolve(here, '..', '..');
const dirLocales = path.resolve(racine, 'src/i18n/locales');
const K_HIST = 'account.history.deleteAll.confirmWord';
const K_CPT = 'account.deleteAccount.confirmText';

describe('Mon compte — vider l’historique et supprimer le compte ne se confirment pas par le même mot (E15)', () => {
  const locales = readdirSync(dirLocales).filter((f) => f.endsWith('.json'));

  it('dix locales, deux mots par locale, en capitales, jamais le même', () => {
    expect(locales).toHaveLength(10);
    for (const f of locales) {
      const m = JSON.parse(readFileSync(path.join(dirLocales, f), 'utf8'));
      const hist = m[K_HIST], cpt = m[K_CPT];
      expect(typeof hist, f).toBe('string');
      expect(typeof cpt, f).toBe('string');
      expect(hist.trim().length, f).toBeGreaterThan(2);
      expect(cpt.trim().length, f).toBeGreaterThan(2);
      expect(hist, f).toBe(hist.toUpperCase().normalize('NFC'));
      expect(cpt, f).toBe(cpt.toUpperCase().normalize('NFC'));
      expect(hist, `${f} : ${hist} sert aux deux gestes`).not.toBe(cpt);
    }
  });

  it('chaque geste compare la saisie au mot de sa locale', () => {
    const conta = readFileSync(path.resolve(racine, 'src/pages/account/AccountPage.jsx'), 'utf8');
    const contrib = readFileSync(path.resolve(racine, 'src/pages/account/ContributorAccountPage.jsx'), 'utf8');
    // l'historique : saisie normalisée en capitales, comparée au mot de l'historique
    expect(conta).toContain("deleteAllConfirmText.trim().toUpperCase() !== t({ id: 'account.history.deleteAll.confirmWord' })");
    // le compte : mot exact, sur les deux pages qui offrent la suppression
    for (const [nom, src] of [['AccountPage', conta], ['ContributorAccountPage', contrib]]) {
      expect(src, nom).toContain("deleteConfirm !== t({ id: 'account.deleteAccount.confirmText' })");
      expect(src, nom).not.toContain("deleteConfirm !== t({ id: 'account.history.deleteAll.confirmWord' })");
    }
    // et aucun mot de confirmation n'est écrit en dur dans la source
    for (const mot of ['SUPPRIMER', 'DELETE', 'EXCLUIR', 'APAGAR', 'EFFACER', 'ERASE']) {
      expect(conta, mot).not.toContain(`'${mot}'`);
      expect(contrib, mot).not.toContain(`'${mot}'`);
    }
  });
});
