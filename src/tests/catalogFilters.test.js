import { describe, it, expect } from 'vitest';
import { lireFiltresURL, buildServerFilters, SEARCH_COLS } from '@/lib/catalogFilters';

// Base : tous les filtres « neutres » (équivalent d'un écran de catalogue vierge).
const base = {
  search: '', authorFilter: '', authorIdFilter: '', alphaFilter: '',
  publisherFilter: '', yearFilter: '', libraryShortNames: [],
  availabilityFilter: '__all__', isAuth: false, isbnFilter: '',
  languageFilter: '', cddFilter: '', subjectsFilter: '',
  materialFilter: '__all__', collectionFilter: '', placeFilter: '',
};

const orGroup = (term) => `or(${SEARCH_COLS.map(c => `${c}.ilike.%${term}%`).join(',')})`;

// E6 : la lecture de l'URL est sortie de CatalogPage, qui était à 256 octets de
// la limite de 65 Ko que sa garde fige. L'URL est la source de vérité d'un lien
// profond : ce qu'elle ne porte pas ne doit pas être hérité de la session.
describe("lireFiltresURL — les filtres d'un lien profond", () => {
  const sp = (s) => new URLSearchParams(s);

  it("sans intention, le dit — l'appelant ne doit alors rien remettre à zéro", () => {
    expect(lireFiltresURL(sp('')).hasIntent).toBe(false);
    expect(lireFiltresURL(sp('tri=titre')).hasIntent).toBe(false);
  });

  it('rend des chaînes vides, jamais null', () => {
    const u = lireFiltresURL(sp('q=kropotkine'));
    expect(u.q).toBe('kropotkine');
    expect(u.autor).toBe('');
    expect(u.idioma).toBe('');
    expect(u.library).toBe('');
  });

  it('idioma porte un code de langue, et compte comme une intention', () => {
    const u = lireFiltresURL(sp('idioma=nl'));
    expect(u.idioma).toBe('nl');
    expect(u.hasIntent).toBe(true);
  });

  it('un paramètre présent mais vide est une intention : il remet le filtre à zéro', () => {
    expect(lireFiltresURL(sp('q=')).hasIntent).toBe(true);
  });

  it('la bibliothèque de la route primé sur ?biblioteca=', () => {
    expect(lireFiltresURL(sp('biblioteca=cira'), 'ccl').library).toBe('ccl');
    expect(lireFiltresURL(sp('biblioteca=cira')).library).toBe('cira');
    expect(lireFiltresURL(sp(''), 'ccl').hasIntent).toBe(true);
  });
});

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

describe('buildServerFilters — filtre texte par auteur·rice', () => {
  // Chaque mot : dans la saisie libre OU dans le nom d'autorité affiché.
  const mot = (w) => `or(autor.ilike.%${w}%,author_display.ilike.%${w}%)`;

  it('un seul mot → un groupe or() saisie libre / nom affiché', () => {
    const f = buildServerFilters({ ...base, authorFilter: 'Goldman' });
    expect(f.autor).toBeUndefined();
    expect(f.and).toBe(`(${mot('Goldman')})`);
  });

  it('« Confederación » cherche aussi le nom d\'autorité affiché (notice saisie « C.N.T. »)', () => {
    const f = buildServerFilters({ ...base, authorFilter: 'Confederación' });
    expect(f.and).toContain('author_display.ilike.%Confederación%');
  });

  it('« Emma Goldman » → un groupe par mot, pour trouver « GOLDMAN, Emma »', () => {
    const f = buildServerFilters({ ...base, authorFilter: 'Emma Goldman' });
    expect(f.autor).toBeUndefined();
    expect(f.and).toBe(`(${mot('Emma')},${mot('Goldman')})`);
  });

  it('virgule et caractères structurels retirés', () => {
    const f = buildServerFilters({ ...base, authorFilter: 'Goldman, (Emma)' });
    expect(f.and).toBe(`(${mot('Goldman')},${mot('Emma')})`);
  });

  it('cohabite avec la recherche libre dans le même and', () => {
    const f = buildServerFilters({ ...base, search: 'vida', authorFilter: 'Emma Goldman' });
    expect(f.and).toBe(`(${orGroup('vida')},${mot('Emma')},${mot('Goldman')})`);
  });

  // E38 (12/10/2026) : la page résout le nom en identifiants d'autorité ; le
  // filtre accepte le lien (author_id, author_chips) OU le texte mot à mot.
  it('avec des identifiants d\'autorité : lien principal, contributeurs, OU le texte mot à mot', () => {
    const f = buildServerFilters({ ...base, authorFilter: 'Kropotkine', authorIds: [5] });
    expect(f.and).toBe(`(or(author_id.in.(5),author_chips.cs.[{"author_id":5}],and(${mot('Kropotkine')})))`);
  });

  it('plusieurs identifiants et plusieurs mots', () => {
    const f = buildServerFilters({ ...base, authorFilter: 'Pierre Kropotkine', authorIds: [5, 77] });
    expect(f.and).toBe(`(or(author_id.in.(5,77),author_chips.cs.[{"author_id":5}],author_chips.cs.[{"author_id":77}],and(${mot('Pierre')},${mot('Kropotkine')})))`);
  });

  it('sans identifiant (aucune autorité trouvée, ou porte indisponible) : le texte seul, comme avant', () => {
    expect(buildServerFilters({ ...base, authorFilter: 'Goldman', authorIds: [] }).and).toBe(`(${mot('Goldman')})`);
    expect(buildServerFilters({ ...base, authorFilter: 'Goldman', authorIds: null }).and).toBe(`(${mot('Goldman')})`);
    expect(buildServerFilters({ ...base, authorFilter: 'Goldman', authorIds: ['x'] }).and).toBe(`(${mot('Goldman')})`);
  });

  it('le filtre par identifiant choisi (authorIdFilter) et le parcours A–Z passent avant', () => {
    const f = buildServerFilters({ ...base, authorFilter: 'Kropotkine', authorIdFilter: '5', authorIds: [5, 6] });
    expect(f.author_id).toBe('eq.5');
    expect(f.and).toBeUndefined();
    const g = buildServerFilters({ ...base, authorFilter: 'Kropotkine', alphaFilter: 'K', authorIds: [5] });
    expect(g.autor).toBe('ilike.K%');
    expect(g.and).toBeUndefined();
  });
});

// CONV-7 protège qu'un code de langue ne tombe pas dans un ILIKE large, et
// l'exprimait par une égalité stricte. Mais une égalité stricte sur un code
// COURT rate ses variantes régionales : « pt » ne trouvait aucune des 1 278
// notices en « pt-BR », ce qui s'est vu le 23/10/2026 quand les descripteurs de
// langue du thésaurus FICEDL — nommés par le code court — ont mené au catalogue.
// Un code court prend donc ses variantes, par un or() borné, jamais par un
// ILIKE. ⚠️ La MÊME règle est dans `api.catalog_works_v1` (migration du 23/10),
// qui filtre le mode « œuvres » : les deux doivent bouger ensemble.
describe('buildServerFilters — filtre de langue (CONV-7)', () => {
  it('un code court prend ses variantes régionales, par un or() borné', () => {
    expect(buildServerFilters({ ...base, languageFilter: 'pt' }).and)
      .toBe('(or(idioma.eq.pt,idioma.like.pt-*))');
    expect(buildServerFilters({ ...base, languageFilter: 'fr' }).and)
      .toBe('(or(idioma.eq.fr,idioma.like.fr-*))');
    expect(buildServerFilters({ ...base, languageFilter: 'pt' }).idioma).toBeUndefined();
  });

  it('un code COMPLET reste une égalité stricte', () => {
    expect(buildServerFilters({ ...base, languageFilter: 'pt-BR' }).idioma).toBe('eq.pt-BR');
    expect(buildServerFilters({ ...base, languageFilter: 'pt-BR' }).and).toBeUndefined();
  });

  it('aucun code ne tombe dans un ilike large — ce que CONV-7 protège', () => {
    for (const lang of ['pt', 'fr', 'pt-BR']) {
      const f = buildServerFilters({ ...base, languageFilter: lang });
      expect(String(f.idioma ?? '') + String(f.and ?? ''), lang).not.toContain('ilike');
    }
  });

  it('une saisie libre héritée reste tolérée en ilike', () => {
    // Favori d'avant la normalisation, ou URL forgée à la main : le résidu
    // hors table de correspondance doit rester atteignable.
    expect(buildServerFilters({ ...base, languageFilter: 'Português' }).idioma)
      .toBe('ilike.%Português%');
  });

  it('vide → aucune clause', () => {
    expect(buildServerFilters({ ...base, languageFilter: '   ' }).idioma).toBeUndefined();
    expect(buildServerFilters({ ...base, languageFilter: '   ' }).and).toBeUndefined();
  });
});
