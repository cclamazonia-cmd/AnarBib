// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/mail-expediteur-par-defaut.test.js
//
// F24 (06/10/2026, décision de Xavier). Sans secret SENDER_NAME, une
// bibliothèque qui n'a ni nom d'expéditeur ni nom court — et tout courriel
// passé par le contexte de repli — partait au nom de « Biblioteca da rede
// AnarBib », en portugais quelle que soit la langue du courriel. Le défaut est
// désormais « AnarBib » seul. Un secret configuré, le nom choisi par une
// bibliothèque ou son nom court restent prioritaires.

import { describe, it, expect } from 'vitest';
import { monterEF } from './helpers/monter-ef.js';

const charger = (env = {}) => {
  const ef = monterEF({ env });
  return {
    env: ef.charger('_shared/core/env.ts'),
    routage: ef.charger('_shared/context/library-mail-routing.ts'),
    libContext: ef.charger('_shared/context/library-notification-context.ts'),
  };
};

describe('nom d\'expéditeur par défaut — « AnarBib », pas de portugais', () => {
  it('SENDER_NAME vaut « AnarBib » sans secret', () => {
    expect(charger().env.SENDER_NAME).toBe('AnarBib');
  });

  it('le contexte de repli d\'une bibliothèque expédie au nom « AnarBib »', () => {
    const { routage, libContext } = charger();
    const fb = libContext.fallbackLibraryNotificationContext('lib-test');
    expect(routage.resolveMailRouting(fb, 'fr').senderName).toBe('AnarBib');
  });

  it('une bibliothèque sans nom d\'expéditeur ni nom court expédie au nom « AnarBib », en toute langue', () => {
    const { routage } = charger();
    for (const loc of ['fr', 'es', 'it', 'de', 'en', 'pt-BR']) {
      const r = routage.resolveMailRouting({ use_library_name_as_sender: false }, loc);
      expect(r.senderName).toBe('AnarBib');
      expect(r.senderName).not.toMatch(/Biblioteca da rede/);
    }
  });

  it('le nom court de la bibliothèque, puis un secret configuré, restent prioritaires', () => {
    expect(charger().routage.resolveMailRouting({ library_short_name: 'BLMF', library_name: 'Biblioteca Libertária' }, 'fr').senderName).toBe('BLMF');
    const { env, routage } = charger({ SENDER_NAME: 'Réseau AnarBib' });
    expect(env.SENDER_NAME).toBe('Réseau AnarBib');
    expect(routage.resolveMailRouting({ use_library_name_as_sender: false }, 'fr').senderName).toBe('Réseau AnarBib');
  });
});
