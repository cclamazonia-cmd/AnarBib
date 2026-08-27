import { describe, it, expect } from 'vitest';
import { partnerOf, partnerLinkName, normalizePartnerLinks } from '@/lib/ficedlPartners';

// Les liens de mot1 « action directe », tels qu'aspirés du SPIP FICEDL le
// 30/06/2026 — trois libellés y sont faux en amont, et ml.ficedl.info y figure
// deux fois pour la même cible (mot3).
const MOT1 = [
  { name: 'Ce mot dans le catalogue du CIRA Lausanne', href: 'https://www.cira.ch/catalogue/index.php?lvl=categ_see&id=5' },
  { name: 'mot marseille', href: 'https://bibliotheque.cira-marseille.info/opac_css/index.php?lvl=categ_see&id=7112' },
  { name: 'Placard : affiches anarchistes', href: 'https://placard.ficedl.info/mot98.html' },
  { name: 'Ce mot dans le site Cartoliste', href: 'https://cartoliste.ficedl.info/mot538.html' },
  { name: 'Ce mot dans les archives du Monde libertaire', href: 'https://ml.ficedl.info/?mot3' },
  { name: 'Ce mot dans le catalogue du CCL', href: 'https://lille.cybertaria.org/biblio/spip.php?mot97' },
  { name: 'Ce mot dans le catalogue du CCL', href: 'https://archives.cira-marseille.info/raforum/spip.php?mot370' },
  { name: 'action directe ', href: 'https://ml.ficedl.info/mot3.html' },
];

describe('partnerOf — le partenaire se lit sur l\'hôte, pas sur le libellé', () => {
  it('reconnaît les sept catalogues du réseau', () => {
    const ids = MOT1.map((l) => partnerOf(l.href)?.id);
    expect(ids).toEqual([
      'cira-lausanne', 'cira-marseille', 'placard', 'cartoliste',
      'monde-libertaire', 'ccl-lille', 'raforum', 'monde-libertaire',
    ]);
  });

  it('ne confond pas les deux hôtes du CIRA Marseille', () => {
    expect(partnerOf('https://bibliotheque.cira-marseille.info/opac_css/').id).toBe('cira-marseille');
    expect(partnerOf('https://archives.cira-marseille.info/raforum/spip.php?mot1').id).toBe('raforum');
  });

  it('rend null sur un hôte inconnu ou une URL invalide', () => {
    expect(partnerOf('https://exemple.org/mot1')).toBe(null);
    expect(partnerOf('pas une url')).toBe(null);
    expect(partnerOf('')).toBe(null);
  });
});

describe('partnerLinkName — corrige les libellés faux en amont', () => {
  it('nomme le CIRA Marseille malgré « mot marseille »', () => {
    expect(partnerLinkName(MOT1[1])).toBe('CIRA Marseille');
  });

  it('nomme RA.forum, que FICEDL annonce comme le CCL', () => {
    expect(partnerLinkName(MOT1[6])).toBe('RA.forum');
  });

  it('nomme Le Monde libertaire, que FICEDL annonce sous le libellé du terme', () => {
    expect(partnerLinkName(MOT1[7])).toBe('Le Monde libertaire');
  });

  it('laisse le CCL de Lille au CCL de Lille', () => {
    expect(partnerLinkName(MOT1[5])).toBe('CCL Lille');
  });

  it('retombe sur le libellé aspiré pour un hôte inconnu, puis sur l\'URL', () => {
    expect(partnerLinkName({ name: 'Ailleurs', href: 'https://exemple.org/mot1' })).toBe('Ailleurs');
    expect(partnerLinkName({ href: 'https://exemple.org/mot1' })).toBe('https://exemple.org/mot1');
  });
});

describe('normalizePartnerLinks', () => {
  it('fond les deux URL du Monde libertaire (?mot3 et mot3.html) en une', () => {
    const out = normalizePartnerLinks(MOT1);
    expect(out).toHaveLength(7);
    expect(out.filter((l) => l.displayName === 'Le Monde libertaire')).toHaveLength(1);
  });

  it('ordonne les partenaires, hôtes inconnus en dernier', () => {
    const out = normalizePartnerLinks([...MOT1, { name: 'Ailleurs', href: 'https://exemple.org/mot1' }]);
    expect(out.map((l) => l.displayName)).toEqual([
      'CIRA Lausanne', 'CIRA Marseille', 'RA.forum', 'CCL Lille',
      'Placard', 'Cartoliste', 'Le Monde libertaire', 'Ailleurs',
    ]);
  });

  it('garde les descripteurs DISTINCTS d\'un même partenaire, et les numérote (mot37 « autonomie »)', () => {
    const out = normalizePartnerLinks([
      { name: 'Ce mot dans le catalogue du CCL', href: 'https://archives.cira-marseille.info/raforum/spip.php?mot1141' },
      { name: 'Ce mot dans le catalogue du CCL', href: 'https://archives.cira-marseille.info/raforum/spip.php?mot1326' },
    ]);
    expect(out.map((l) => l.displayName)).toEqual(['RA.forum (1)', 'RA.forum (2)']);
  });

  it('ne numérote pas un partenaire qui n\'apparaît qu\'une fois', () => {
    expect(normalizePartnerLinks(MOT1).map((l) => l.displayName)).not.toContain('RA.forum (1)');
  });

  it('supporte une entrée vide, nulle ou sans href', () => {
    expect(normalizePartnerLinks(null)).toEqual([]);
    expect(normalizePartnerLinks([null, { name: 'sans href' }])).toEqual([]);
  });
});
