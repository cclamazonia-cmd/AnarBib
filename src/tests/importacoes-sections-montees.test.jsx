// =====================================================================
// E6, Importations (23/10/2026) — la face Import sort en quatre sections
// (ImportAdapterStrip, ImportAddRecords, ImportRunsList, ImportReviewQueue),
// les aides du module dans importacoesOutils.jsx. Ce test garde le montage :
// la face Import toujours montée, masquée hors de son onglet (l'état de ses
// sections survit à un passage par l'onglet Export), chaque section montée
// une fois, aucune déclaration en double ni manquante (le piège du commentaire
// de fin de ligne, rattrapé le jour même), et la page sous 60 Kio.
// Les gestes de la file de révision sont joués, page montée, par h21-lot0/1.
// =====================================================================
import { describe, it, expect } from 'vitest';
import { readFileSync, statSync } from 'node:fs';
import path from 'node:path';

const racine = path.resolve(__dirname, '..', '..');
const lire = (p) => readFileSync(path.join(racine, p), 'utf8');
const PAGE = 'src/pages/importacoes/ImportacoesPage.jsx';
const SECTIONS = ['ImportAdapterStrip', 'ImportAddRecords', 'ImportRunsList', 'ImportReviewQueue'];

describe('la face Import des Importations, en sections', () => {
  it('la face Import est toujours montée, masquée hors de son onglet', () => {
    const page = lire(PAGE);
    expect(page).toContain("<div hidden={sentido !== 'import'}>");
    expect(page).not.toContain("{sentido === 'import' && (<>");
  });
  it('chaque section est importée et montée une fois', () => {
    const page = lire(PAGE);
    for (const s of SECTIONS) {
      expect(page, s).toContain(`import ${s} from './${s}.jsx';`);
      expect(page.match(new RegExp(`<${s} \\{\\.\\.\\.\\{`, 'g')), s).toHaveLength(1);
    }
  });
  it('aucune section ne redéclare ce qu\'elle reçoit en prop', () => {
    for (const s of SECTIONS) {
      const src = lire(`src/pages/importacoes/${s}.jsx`);
      const bloc = src.match(/const \{\n([\s\S]*?)\n {2}\} = p;/);
      const props = (bloc ? bloc[1] : '').split(',').map((x) => x.trim()).filter(Boolean);
      for (const n of props) {
        expect(src, `${s} : ${n}`).not.toMatch(new RegExp(`const \\[${n},|const ${n} =|function ${n}\\(`));
      }
    }
  });
  it('la page tient sous 60 Kio (E6)', () => {
    expect(statSync(path.join(racine, PAGE)).size).toBeLessThan(60 * 1024);
  });
});
