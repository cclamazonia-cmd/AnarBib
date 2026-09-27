// ═══════════════════════════════════════════════════════════
// AnarBib — la localisation d'un exemplaire (src/lib/shelfLocation.js).
//
// H19 (27/09/2026, revue contradictoire) : un exemplaire importé porte sa
// cote brute (995 $k « GR 949.5 PAP ») dans shelf_location. Le formulaire ne
// reconnaissait que le format structuré et réécrivait une localisation vide
// à l'enregistrement : la cote se perdait sans un mot, puis la republication
// l'effaçait sur l'exemplaire. Ce qui n'est pas reconnu se garde désormais.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { parseShelfLocation, formatShelfLocation, emptyShelfLocation } from '@/lib/shelfLocation';

describe('localisation d\'un exemplaire', () => {
  it('une cote importée brute est gardée, et se réécrit telle quelle', () => {
    const p = parseShelfLocation('GR 949.5 PAP');
    expect(p).toEqual({ ...emptyShelfLocation(), raw: 'GR 949.5 PAP' });
    expect(formatShelfLocation(p)).toBe('GR 949.5 PAP');
  });

  it('le format structuré fait l\'aller-retour, accents et abréviation compris', () => {
    const s = 'Biblioteca: BLMF · Setor/sala: Sala 2 · Estante: E3 · Prateleira: 4 · Observação: fragile';
    const p = parseShelfLocation(s);
    expect(p).toMatchObject({ library: 'BLMF', sector: 'Sala 2', shelfUnit: 'E3', shelfLevel: '4', note: 'fragile', raw: '' });
    expect(formatShelfLocation(p)).toBe(s);
    expect(parseShelfLocation('obs: dédicacé').note).toBe('dédicacé');
  });

  it('structuré + brut : rien ne se perd (partie sans étiquette, étiquette inconnue ou répétée)', () => {
    const p = parseShelfLocation('Estante: E3 · 027.6 GAR · Cote: X1 · Estante: E9');
    expect(p.shelfUnit).toBe('E3');
    expect(p.raw).toBe('027.6 GAR · Cote: X1 · Estante: E9');
    expect(formatShelfLocation(p)).toBe('Estante: E3 · 027.6 GAR · Cote: X1 · Estante: E9');
  });

  it('une étiquette connue sans valeur ne porte rien ; vide reste vide', () => {
    expect(parseShelfLocation('Estante: · Prateleira: 2')).toMatchObject({ shelfUnit: '', shelfLevel: '2', raw: '' });
    expect(formatShelfLocation(parseShelfLocation(''))).toBe('');
    expect(formatShelfLocation(parseShelfLocation(null))).toBe('');
  });
});
