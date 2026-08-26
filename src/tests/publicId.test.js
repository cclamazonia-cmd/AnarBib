import { describe, it, expect } from 'vitest';
import { formatPublicId, normalizePublicId } from '@/lib/publicId';

const CANON = '7b3f0c9a2e5d18406c1f';
const GROUPED = '7b3f 0c9a 2e5d 1840 6c1f';

describe('formatPublicId — affichage par groupes de quatre', () => {
  it('découpe un identifiant canonique', () => {
    expect(formatPublicId(CANON)).toBe(GROUPED);
  });

  it('met en minuscules au passage (les identifiants sont stockés ainsi)', () => {
    expect(formatPublicId(CANON.toUpperCase())).toBe(GROUPED);
  });

  it("laisse intact un identifiant séquentiel d'avant le 20/08/2026", () => {
    expect(formatPublicId('U000085')).toBe('U000085');
  });

  it('laisse intact ce qui n\'est pas un identifiant', () => {
    expect(formatPublicId('lecteur@exemple.org')).toBe('lecteur@exemple.org');
    expect(formatPublicId('Jean Dupont')).toBe('Jean Dupont');
    expect(formatPublicId('')).toBe('');
  });

  it('supporte null/undefined sans casser le rendu', () => {
    expect(formatPublicId(null)).toBe(null);
    expect(formatPublicId(undefined)).toBe(undefined);
  });
});

describe('normalizePublicId — recollage avant envoi au serveur', () => {
  it('recolle un identifiant copié depuis l\'écran', () => {
    expect(normalizePublicId(GROUPED)).toBe(CANON);
  });

  it('tolère les espaces surnuméraires et la casse', () => {
    expect(normalizePublicId('  7B3F 0c9a 2e5d  1840 6c1f  ')).toBe(CANON);
  });

  it('laisse passer un identifiant déjà canonique', () => {
    expect(normalizePublicId(CANON)).toBe(CANON);
  });

  it('ne touche pas aux espaces intérieurs d\'une identité locale', () => {
    expect(normalizePublicId('  Jean Dupont ')).toBe('Jean Dupont');
  });

  it('ne touche pas à une adresse e-mail ni à un U000xxx', () => {
    expect(normalizePublicId(' lecteur@exemple.org ')).toBe('lecteur@exemple.org');
    expect(normalizePublicId(' U000085 ')).toBe('U000085');
  });

  it('rend une chaîne vide pour null/undefined (champ non saisi)', () => {
    expect(normalizePublicId(null)).toBe('');
    expect(normalizePublicId(undefined)).toBe('');
  });
});

describe('les deux fonctions sont réciproques', () => {
  it('normalize(format(x)) === x', () => {
    expect(normalizePublicId(formatPublicId(CANON))).toBe(CANON);
  });
});
