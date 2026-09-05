// Le bon recueil, à la bonne page, dans la langue de la personne (05/09/2026).
// Garde la FORME des tables (dix langues, blocs croissants) et le sens de la
// table « page → documents » — pas les numéros de page, qui suivent les PDF.
import { describe, it, expect } from 'vitest';
import {
  COMPLETE_BLOCKS, READER_START, READER_SECTIONS, GOVERNANCE_START,
  completeManualUrl, readerManualUrl, governanceGuideUrl, docsForLocation, currentTab,
} from '../lib/docLinks.js';

const LOCALES = ['pt-BR', 'fr', 'es', 'it', 'en', 'de', 'ca', 'eo', 'nl', 'el'];

describe('tables des recueils', () => {
  it('couvrent les dix langues servies', () => {
    for (const l of LOCALES) {
      expect(COMPLETE_BLOCKS[l], l).toBeDefined();
      expect(READER_START[l], l).toBeDefined();
      expect(GOVERNANCE_START[l], l).toBeDefined();
    }
  });
  it('dix blocs croissants par langue, et les langues ne se chevauchent pas', () => {
    const starts = [];
    for (const l of LOCALES) {
      const b = COMPLETE_BLOCKS[l];
      expect(b).toHaveLength(10);
      for (let i = 1; i < b.length; i++) expect(b[i]).toBeGreaterThan(b[i - 1]);
      starts.push(b[0]);
    }
    const sorted = [...starts].sort((a, b) => a - b);
    for (let i = 1; i < sorted.length; i++) expect(sorted[i] - sorted[i - 1]).toBeGreaterThanOrEqual(60);
  });
  it('le manuel lecteur·rice : dix-huit pages par langue, sections dans l’ordre', () => {
    const s = LOCALES.map(l => READER_START[l]).sort((a, b) => a - b);
    for (let i = 1; i < s.length; i++) expect(s[i] - s[i - 1]).toBe(18);
    expect(READER_SECTIONS.catalogue).toBeLessThan(READER_SECTIONS.account);
    expect(READER_SECTIONS.reserve).toBeLessThan(READER_SECTIONS.loans);
    expect(Math.max(...Object.values(READER_SECTIONS))).toBeLessThan(18);
  });
});

describe('URL', () => {
  it('ouvre le bloc dans la langue, et retombe sur pt-BR pour une langue inconnue', () => {
    expect(completeManualUrl('fr', 5)).toMatch(/Manual_do_AnarBib\.pdf#page=133$/);
    expect(completeManualUrl('xx', 0)).toMatch(/#page=6$/);
    expect(readerManualUrl('el', 'reserve')).toMatch(/#page=178$/);
    expect(governanceGuideUrl('nl')).toMatch(/Guia_de_governanca_AnarBib\.pdf#page=470$/);
  });
});

describe('page → documents', () => {
  it('le lectorat a le manuel lecteur·rice, jamais le manuel complet', () => {
    expect(docsForLocation({ pathname: '/', isStaff: false })).toMatchObject({ reader: 'catalogue', complete: null });
    expect(docsForLocation({ pathname: '/livro/12', isStaff: true })).toMatchObject({ reader: 'catalogue', complete: null });
    expect(docsForLocation({ pathname: '/conta', search: '?tab=reservar' })).toMatchObject({ reader: 'reserve' });
    expect(docsForLocation({ pathname: '/bibliotecas' })).toMatchObject({ reader: 'libraries' });
  });
  it('les pages staff n’exposent rien à qui n’est pas staff', () => {
    expect(docsForLocation({ pathname: '/catalogacao', isStaff: false })).toEqual({ reader: null, complete: null, governance: false, communs: [] });
  });
  it('le staff a le bloc qui va avec la page, et les vade-mecums du geste', () => {
    expect(docsForLocation({ pathname: '/painel', isStaff: true })).toMatchObject({ complete: 4, governance: true });
    expect(docsForLocation({ pathname: '/biblioteca', isStaff: true })).toMatchObject({ complete: 6, governance: true });
    expect(docsForLocation({ pathname: '/federacao/assembleias', isStaff: true })).toMatchObject({ complete: 7, governance: true });
    expect(docsForLocation({ pathname: '/importacoes', hash: '#tab=export', isStaff: true })).toMatchObject({ complete: 5 });
    const cat = docsForLocation({ pathname: '/catalogacao', hash: '#tab=materiaPanel', isStaff: true });
    expect(cat.complete).toBe(5);
    expect(cat.communs).toEqual(['guide-conventions', 'guide-indexar']);
  });
  it('la page Réseau garde le guide pour tout le monde', () => {
    expect(docsForLocation({ pathname: '/rede', isStaff: false })).toMatchObject({ governance: true, complete: null });
    expect(docsForLocation({ pathname: '/rede', hash: '#tab=reviews', isStaff: true })).toMatchObject({ governance: true, complete: 8 });
  });
  it('lit l’onglet quelle que soit la convention de la page', () => {
    expect(currentTab('/conta', '?tab=curso', '')).toBe('curso');
    expect(currentTab('/catalogacao', '', '#tab=batchesPanel')).toBe('batchesPanel');
    expect(currentTab('/federacao/communs', '?doc=cotation', '')).toBe('communs');
    expect(currentTab('/painel/reservas', '', '')).toBe('reservas');
    expect(currentTab('/rede', '', '')).toBeNull();
  });
});
