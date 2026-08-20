import { describe, it, expect } from 'vitest';
import { buildServerFilters, SEARCH_COLS } from '@/lib/catalogFilters';

// Base : tous les filtres « neutres » (équivalent d'un écran de catalogue vierge).
const base = {
  search: '', authorFilter: '', authorIdFilter: '', alphaFilter: '',
  publisherFilter: '', yearFilter: '', libraryShortNames: [],
  availabilityFilter: '__all__', isAuth: false, isbnFilter: '',
  languageFilter: '', cddFilter: '', subjectsFilter: '',
  materialFilter: '__all__', collectionFilter: '', placeFilter: '',
};

const orGroup = (term) => `or(${SEARCH_COLS.map(c => `${c}.ilike.%${term}%`).join(',')})`;

describe('buildServerFilters — recherche multi-mots', () => {
  it('un seul mot → un groupe or() sur toutes les colonnes, sous and', () => {
    const f = buildServerFilters({ ...base, search: 'kropotkin' });
    expect(f.and).toBe(`(${orGroup('kropotkin')})`);
    expect(f.or).toBeUndefined();
  });

  it('deux mots → deux or() ANDés (chaque mot dans au moins une colonne)', () => {
    const f = buildServerFilters({ ...base, search: 'bakounine dieu' });
    expect(f.and).toBe(`(${orGroup('bakounine')},${orGroup('dieu')})`);
  });

  it('recherche + multi-biblio cohabitent (collision or() historique corrigée)', () => {
    const f = buildServerFilters({ ...base, search: 'anarchie', libraryShortNames: ['CIRA', 'CGT'] });
    // La recherche n'est PLUS écrasée par le filtre biblio.
    expect(f.and).toContain(orGroup('anarchie'));
    expect(f.and).toContain('or(holding_library_names_json.cs.["CIRA"],holding_library_names_json.cs.["CGT"])');
    expect(f.or).toBeUndefined();
  });

  it('intervalle d’année consolidé dans le and', () => {
    const f = buildServerFilters({ ...base, search: 'guerra', yearFilter: '1936-1939' });
    expect(f.and).toContain('ano.gte.1936');
    expect(f.and).toContain('ano.lte.1939');
    expect(f.and).toContain(orGroup('guerra'));
  });

  it('caractères structurels [(),] retirés des termes', () => {
    const f = buildServerFilters({ ...base, search: 'a(b),c' });
    expect(f.and).toBe(`(${orGroup('abc')})`);
  });

  it('biblio unique → cs direct, pas de and', () => {
    const f = buildServerFilters({ ...base, libraryShortNames: ['CIRA'] });
    expect(f.holding_library_names_json).toBe('cs.["CIRA"]');
    expect(f.and).toBeUndefined();
  });

  it('année exacte reste sur la clé ano (pas de and)', () => {
    const f = buildServerFilters({ ...base, yearFilter: '1936' });
    expect(f.ano).toBe('eq.1936');
    expect(f.and).toBeUndefined();
  });

  it('plafond de 6 mots (garde-fou anti-URL)', () => {
    const f = buildServerFilters({ ...base, search: 'un deux trois quatre cinq six sept huit' });
    const groups = f.and.slice(1, -1).split('),or(').length; // compte approximatif des or()
    expect(groups).toBe(6);
  });

  it('phrase entre guillemets → un seul terme contigu (pas découpée en mots)', () => {
    const f = buildServerFilters({ ...base, search: '"apoio mútuo"' });
    expect(f.and).toBe(`(${orGroup('apoio mútuo')})`);
  });

  it('phrase entre guillemets + mot libre → deux termes ANDés', () => {
    const f = buildServerFilters({ ...base, search: '"apoio mútuo" anarquia' });
    expect(f.and).toBe(`(${orGroup('apoio mútuo')},${orGroup('anarquia')})`);
  });

  it('guillemet orphelin nettoyé → mots séparés, aucun motif pollué', () => {
    const f = buildServerFilters({ ...base, search: '"apoio mútuo' });
    expect(f.and).toBe(`(${orGroup('apoio')},${orGroup('mútuo')})`);
  });
});

describe('buildServerFilters — filtre de langue (CONV-7)', () => {
  it('un code BCP-47 → égalité stricte, pas ilike', () => {
    expect(buildServerFilters({ ...base, languageFilter: 'fr' }).idioma).toBe('eq.fr');
    expect(buildServerFilters({ ...base, languageFilter: 'pt-BR' }).idioma).toBe('eq.pt-BR');
  });

  it('une saisie libre héritée reste tolérée en ilike', () => {
    // Favori d'avant la normalisation, ou URL forgée à la main : le résidu
    // hors table de correspondance doit rester atteignable.
    expect(buildServerFilters({ ...base, languageFilter: 'Português' }).idioma)
      .toBe('ilike.%Português%');
  });

  it('vide → aucune clause', () => {
    expect(buildServerFilters({ ...base, languageFilter: '   ' }).idioma).toBeUndefined();
  });
});
