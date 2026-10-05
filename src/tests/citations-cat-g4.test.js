// CAT-G4 — un contributeur lie se cite sous la forme inversee de son autorite,
// un contributeur non lie sous sa transcription (E28, 05/10/2026).
import { describe, it, expect } from 'vitest';
import { citeName, citeAuthorString, citeAuthorList, citationContributors, buildRis } from '@/lib/citations';

const russell = { position: 1, name: 'Russel, Bertrand', role: 'autor', author_id: 10187,
  authority_name: 'Bertrand Russell', authority_sort_name: 'Russell, Bertrand' };
const nonLie = { position: 2, name: 'Vázquez, Juan José', role: 'ilustrador', author_id: null,
  authority_name: null, authority_sort_name: null };
const coauteur = { position: 2, name: 'Whitehead, Alfred North', role: 'coautor', author_id: null };
const trad = { position: 3, name: 'Gómez, Ana', role: 'tradutor', author_id: null };
const orga = { position: 1, name: 'Mintz, Frank', role: 'organizador', author_id: 12,
  authority_name: 'Frank Mintz', authority_sort_name: 'Mintz, Frank' };
const prefa = { position: 2, name: 'Coelho, Plínio', role: 'prefaciador', author_id: null };

describe('CAT-G4 — citations', () => {
  it('cite un contributeur lie sous la forme inversee de son autorite, pas sa transcription', () => {
    expect(citeName(russell)).toBe('Russell, Bertrand');
  });

  it('cite un contributeur non lie sous sa transcription', () => {
    expect(citeName(nonLie)).toBe('Vázquez, Juan José');
  });

  it('se replie sur la forme directe, puis la transcription, si la forme inversee manque', () => {
    expect(citeName({ ...russell, authority_sort_name: null })).toBe('Bertrand Russell');
    expect(citeName({ ...russell, authority_sort_name: null, authority_name: null })).toBe('Russel, Bertrand');
  });

  it('assemble la mention et la liste RIS dans l\'ordre des auteur·rices', () => {
    const book = { titulo: 'Essai', ano: '1950' };
    expect(citeAuthorString(book, [russell, coauteur])).toBe('Russell, Bertrand; Whitehead, Alfred North');
    const ris = buildRis(book, citeAuthorList(book, [russell, coauteur]), null);
    expect(ris).toContain('AU  - Russell, Bertrand');
    expect(ris).toContain('AU  - Whitehead, Alfred North');
    expect(ris).not.toContain('Russel, Bertrand');
  });

  it('ne cite ni l\'illustration, ni la traduction, ni la préface comme auteur·rices', () => {
    const book = { titulo: 'La Balada de Robin Hood', tipo_material: 'livro' };
    expect(citeAuthorString(book, [russell, nonLie, trad])).toBe('Russell, Bertrand');
    expect(citeAuthorList(book, [russell, nonLie, trad])).toEqual(['Russell, Bertrand']);
  });

  it('sans auteur·rice, cite l\'organisation (écrit), la réalisation (audiovisuel), la composition (son)', () => {
    expect(citeAuthorString({ tipo_material: 'livro' }, [orga, prefa])).toBe('Mintz, Frank');
    const real = { name: 'Wertmüller, Lina', role: 'realizador' };
    const acteur = { name: 'Giannini, Giancarlo', role: 'ator' };
    expect(citeAuthorString({ tipo_material: 'audiovisual' }, [real, acteur])).toBe('Wertmüller, Lina');
    const compo = { name: 'Ferré, Léo', role: 'compositor' };
    const interp = { name: 'X, Y', role: 'interprete' };
    expect(citeAuthorString({ tipo_material: 'audio' }, [interp, compo])).toBe('Ferré, Léo');
  });

  it('à défaut de tout responsable principal, garde tout le monde plutôt qu\'aucun nom', () => {
    expect(citationContributors([trad, prefa], 'livro')).toEqual([trad, prefa]);
    expect(citeAuthorString({ tipo_material: 'livro' }, [trad])).toBe('Gómez, Ana');
  });

  it('un contributeur sans rôle compte comme auteur·rice (rôle par défaut du catalogage)', () => {
    expect(citationContributors([{ name: 'Sans, Rôle' }, trad], 'livro')).toEqual([{ name: 'Sans, Rôle' }]);
  });

  it('sans contributeurs, garde le repli sur author_display puis autor', () => {
    expect(citeAuthorString({ author_display: 'RUSSELL, Bertrand', autor: 'x' }, [])).toBe('RUSSELL, Bertrand');
    expect(citeAuthorString({ autor: 'Anônimo' }, null)).toBe('Anônimo');
  });
});
