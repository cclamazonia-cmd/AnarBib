// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/mail-nom-equipe-repli-garde.test.js
//
// F21, suite (01/10/2026). Relevé en relisant la PR #31 : `ADMIN_NAME` valait
// par défaut « Equipe da biblioteca » (core/env.ts), et `replaceBrandTokens`
// (shared/branding.ts) retombait sur la même phrase. Une instance sans
// ADMIN_NAME — le cas des trois bibliothèques — signait donc ses courriels en
// pt-BR quelle que soit la langue : la correction du pied de page (PR #31)
// remettait ce nom dans `signature_short`, et le portugais revenait par là.
//
// Sans nom configuré, on signe désormais du nom de la bibliothèque, qui se lit
// dans toutes les langues. Un nom configuré reste prioritaire.

import { describe, it, expect } from 'vitest';
import { monterEF } from './helpers/monter-ef.js';

const charger = (env = {}) => {
  const ef = monterEF({ env });
  return {
    env: ef.charger('_shared/core/env.ts'),
    branding: ef.charger('_shared/shared/branding.ts'),
    libContext: ef.charger('_shared/context/library-notification-context.ts'),
  };
};

const CTX = { library_name: 'Bibliothèque Louise Michel', library_short_name: 'BLM' };

describe('nom d\'équipe — aucun repli pt-BR sans ADMIN_NAME', () => {
  it('ADMIN_NAME est vide quand aucune variable n\'est définie', () => {
    expect(charger().env.ADMIN_NAME).toBe('');
  });

  it('la signature de repli du contexte bibliothèque n\'est pas « Equipe da biblioteca »', () => {
    const fb = charger().libContext.fallbackLibraryNotificationContext('lib-test');
    expect(fb.signature_short ?? '').not.toContain('Equipe da biblioteca');
    expect(fb.reply_to_name ?? '').not.toContain('Equipe da biblioteca');
  });

  it('replaceBrandTokens signe du nom de la bibliothèque sans nom configuré', () => {
    const { branding } = charger();
    expect(branding.replaceBrandTokens('Equipe da BLMF', CTX)).toBe('Bibliothèque Louise Michel');
  });

  it('un ADMIN_NAME configuré reste prioritaire', () => {
    const { env, branding } = charger({ ADMIN_NAME: 'Coordination BLM' });
    expect(env.ADMIN_NAME).toBe('Coordination BLM');
    expect(branding.replaceBrandTokens('Equipe da BLMF', CTX)).toBe('Coordination BLM');
  });
});
