import { describe, it, expect } from 'vitest';
import { classifyAuthorString, authorLabel } from '@/lib/authorLabel';

// CONV-8 : « AA. VV. » n'est pas un auteur — étiquette localisée entre crochets,
// transcription conservée, collectif nommé laissé tel quel.
const t = ({ id }) => ({ 'book.author.anonymous': 'anonyme', 'book.author.various': 'auteurs divers' })[id] || id;

describe('classifyAuthorString', () => {
  it('reconnaît les formes « auteurs divers » dans les langues du réseau', () => {
    for (const s of ['AA. VV.', 'AA. VV', 'VV. AA.', 'Vários Autores', 'Varios autores', 'Autori vari', 'Collectif', 'Coletivo', 'Various authors', 'Verschiedene Autoren']) {
      expect(classifyAuthorString(s), s).toBe('various');
    }
  });
  it('reconnaît les formes anonymes, dans les deux ordres, et le bruit', () => {
    for (const s of ['Anônimo', 'Anónimo', 'Anonyme', 'Não identificado', 'identificado, Não', 'Sem Autoria', 's.n.', '??', 'Unknown']) {
      expect(classifyAuthorString(s), s).toBe('anonymous');
    }
  });
  it('ne juge que le premier segment, et laisse un collectif nommé', () => {
    expect(classifyAuthorString('AA. VV. ; XERRI, Elio')).toBe('various');
    expect(classifyAuthorString('Coletivo de Ex-Trabalhadores')).toBeNull();
    expect(classifyAuthorString('Leueroth, Pelo Coletivo Edgar')).toBeNull();
    expect(classifyAuthorString('Kropotkin, Piotr')).toBeNull();
    expect(classifyAuthorString('')).toBeNull();
    expect(classifyAuthorString(null)).toBeNull();
  });
});

describe('authorLabel', () => {
  it("l'autorité l'emporte sur la transcription", () => {
    expect(authorLabel({ author_display: 'KROPOTKIN, Piotr', autor: 'AA. VV.' }, t)).toBe('KROPOTKIN, Piotr');
  });
  it('un author_display égal à la transcription est le repli des vues, pas une autorité', () => {
    expect(authorLabel({ author_display: 'Sem Autoria', autor: 'Sem Autoria' }, t)).toBe('[anonyme]');
    expect(authorLabel({ author_display: 'AA. VV', autor: 'AA. VV' }, t)).toBe('[auteurs divers]');
  });
  it('remplace le premier segment par l’étiquette entre crochets et garde le reste', () => {
    expect(authorLabel({ autor: 'AA. VV. ; XERRI, Elio ; BURATTI, Simone' }, t)).toBe('[auteurs divers] ; XERRI, Elio ; BURATTI, Simone');
    expect(authorLabel({ autor: 'Anônimo' }, t)).toBe('[anonyme]');
    expect(authorLabel({ autor: '??' }, t)).toBe('[anonyme]');
  });
  it('laisse une transcription ordinaire telle quelle', () => {
    expect(authorLabel({ autor: 'GARCÍA, Luis Lamela' }, t)).toBe('GARCÍA, Luis Lamela');
    expect(authorLabel({ autor: 'Coletivo de Ex-Trabalhadores' }, t)).toBe('Coletivo de Ex-Trabalhadores');
    expect(authorLabel({}, t)).toBe('');
    expect(authorLabel(null, t)).toBe('');
  });
});
