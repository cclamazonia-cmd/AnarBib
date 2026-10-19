// @vitest-environment node
// 19/10/2026 — une bibliothèque sans prêt (circulation_mode = 'off', par
// exemple une bibliothèque « source ») ne voit pas, dans le volet « données »
// de l'atelier ni dans la gestion de la bibliothèque, les durées de
// conservation des prêts, réservations et consultations qu'elle n'a pas.
// Demande d'Anarchief.Org (J/M, 19/10) : « hoe lang gegevens van uitleningen
// worden bijgehouden » n'a pas de sens sans uitleningen.
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

const src = readFileSync(new URL('../components/library/RetentionPolicySection.jsx', import.meta.url), 'utf8');

describe('volet données sans prêt', () => {
  it('lit le mode de circulation de la bibliothèque', () => {
    expect(src).toMatch(/from\('libraries'\)\.select\('circulation_mode'\)/);
    expect(src).toMatch(/circulation_mode === 'off'/);
  });
  it('cache les trois durées de circulation, garde les notifications', () => {
    const blocs = src.split('{!circulationOff && (<>');
    expect(blocs.length).toBe(3); // durées effectives + formulaire
    for (const b of blocs.slice(1)) {
      const garde = b.split('</>)}')[0];
      expect(garde).toMatch(/privacy\.loans/);
      expect(garde).toMatch(/privacy\.reservations/);
      expect(garde).toMatch(/privacy\.consultations/);
      expect(garde).not.toMatch(/privacy\.notifications/);
    }
  });
  it('dit pourquoi', () => {
    expect(src).toMatch(/biblioteca\.privacy\.noCirculation/);
  });
});
