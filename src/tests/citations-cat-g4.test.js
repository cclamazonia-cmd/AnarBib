// CAT-G4 — un contributeur lie se cite sous la forme inversee de son autorite,
// un contributeur non lie sous sa transcription (E28, 05/10/2026).
import { describe, it, expect } from 'vitest';
import { citeName, citeAuthorString, citeAuthorList, buildRis } from '@/lib/citations';

const russell = { position: 1, name: 'Russel, Bertrand', role: 'autor', author_id: 10187,
  authority_name: 'Bertrand Russell', authority_sort_name: 'Russell, Bertrand' };
const nonLie = { position: 2, name: 'Vázquez, Juan José', role: 'ilustrador', author_id: null,
  authority_name: null, authority_sort_name: null };

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

  it('assemble la mention et la liste RIS dans l\'ordre des contributeurs', () => {
    const book = { titulo: 'Essai', ano: '1950' };
    expect(citeAuthorString(book, [russell, nonLie])).toBe('Russell, Bertrand; Vázquez, Juan José');
    const ris = buildRis(book, citeAuthorList(book, [russell, nonLie]), null);
    expect(ris).toContain('AU  - Russell, Bertrand');
    expect(ris).not.toContain('Russel, Bertrand');
  });

  it('sans contributeurs, garde le repli sur author_display puis autor', () => {
    expect(citeAuthorString({ author_display: 'RUSSELL, Bertrand', autor: 'x' }, [])).toBe('RUSSELL, Bertrand');
    expect(citeAuthorString({ autor: 'Anônimo' }, null)).toBe('Anônimo');
  });
});
