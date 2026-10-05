// ═══════════════════════════════════════════════════════════
// AnarBib — E25 (05/10/2026) : le pt-BR des documents et des dernières valeurs
// que la passe du 27/09 n'avait pas touchées.
//
// Les gardes du 27/09 (TU_EUROPEU, PT_EUROPEU, FRANCES_EM_PT) ne lisaient que
// les locales et les courriels. Le guide de gouvernance pt-BR — source du
// recueil PDF du bucket —, la charte inclusive et le DPA disaient encore
// « concernida », « gerir », « partilhar » (angles morts déclarés des gardes),
// et le guide tutoyait (« Se a regra te incomoda »). Dans pt-BR.json, 28 valeurs
// gardaient l'espace français avant « : » et « ; », trois écrivaient le genre
// avec « @ » (proscrit par la charte pt-BR), et une restait en anglais.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { TU_EUROPEU } from './helpers/ptbr-tu-europeu.js';
import { PT_EUROPEU } from './helpers/ptbr-pt-europeu.js';
import { FRANCES_EM_PT } from './helpers/ptbr-frances.js';

const RACINE = path.resolve(__dirname, '../..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');
const GUIDE = 'docs/governance/guide-gouvernance-pt-BR.md';
const DOCS = [GUIDE, 'docs/notes-audit/anarbib-charte-langage-inclusif-v2-pt-BR.md', 'docs/legal/dpa-pt-BR.md'];

// Lignes légitimes, nommées une à une (aucun motif) :
//  — la narration à la 3e personne du guide (« A rede […] Diz apenas »,
//    « Emma […] Vai / Clica », « Insere a identidade ») : même forme que
//    l'impératif du tu, sujet différent ;
//  — « utente », cité par la charte comme mot ITALIEN épicène.
const LEGITIMES = [
  'Diz apenas com quem elas se reconhecem',
  'Vai em `/biblioteca`, aba **Equipe**',
  'Clica **« Convidar para a equipe »**',
  'Insere a identidade de Mohammed',
  '(`utente`, `responsabile`, `persona`',
  '`responsable` fr, `utente` it',
];
const legitime = (ligne) => LEGITIMES.some((l) => ligne.includes(l));

const fautes = (texte, re) => texte.split('\n')
  .map((l, i) => [i + 1, l])
  .filter(([, l]) => re.test(l) && !legitime(l))
  .map(([n, l]) => `${n}: ${l.slice(0, 100)}`);

describe('E25 — les documents pt-BR', () => {
  for (const f of DOCS) {
    it(`${f} : ni « concernid- », ni « gerir », ni « partilh- » hors « compartilh- »`, () => {
      expect(fautes(lire(f), /concernid|(?<![\p{L}])ger(ir|e|em)(?![\p{L}])|(?<!com)partilh/iu)).toEqual([]);
    });
    it(`${f} : les gardes du pt-BR (TU_EUROPEU, PT_EUROPEU, FRANCES_EM_PT) y passent`, () => {
      const t = lire(f);
      expect(fautes(t, TU_EUROPEU)).toEqual([]);
      expect(fautes(t, PT_EUROPEU)).toEqual([]);
      expect(fautes(t, FRANCES_EM_PT)).toEqual([]);
    });
  }
});

describe('E25 — pt-BR.json', () => {
  const j = JSON.parse(lire('src/i18n/locales/pt-BR.json'));
  it("aucune valeur hors zones ISBD n'a d'espace avant « : » ou « ; »", () => {
    const fautives = Object.entries(j)
      .filter(([k, v]) => !k.startsWith('catalogacao.isbd.') && / [:;](\s|$)/.test(v))
      .map(([k]) => k);
    expect(fautives).toEqual([]);
  });
  it("le genre ne s'écrit pas avec « @ » (une adresse, si)", () => {
    const fautives = Object.entries(j).filter(([, v]) => /\p{L}@(?![\w.-]+\.\w)/u.test(v)).map(([k]) => k);
    expect(fautives).toEqual([]);
  });
  it('catalogacao.queue.crossPage est traduite', () => {
    expect(j['catalogacao.queue.crossPage']).not.toMatch(/cross-page/);
  });
});
