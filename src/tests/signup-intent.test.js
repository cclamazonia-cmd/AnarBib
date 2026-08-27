// AnarBib — non-régression de l'aiguillage d'inscription (27/08/2026).
//
// Écrit pendant le chantier « je représente une bibliothèque » : ce chantier
// touche le select de /criar-conta, or les 8 comptes existants sont tous passés
// par la voie reader_pending du MÊME select. Rien ne surveillait cette voie —
// criar-conta-i18n.test.js ne teste que des chaînes, et aucun test ne rend le
// composant. Le mapping est donc épinglé ici.

import { describe, it, expect } from 'vitest';
import { deriveSignupIntent, isSignupSentinel, SIGNUP_SENTINELS } from '@/lib/signupIntent';

// Les quatre valeurs de la CHECK profiles_signup_intent_chk.
const VALID_INTENTS = ['reader_pending', 'reader_orphan', 'collective_candidate', 'contributor'];

describe('deriveSignupIntent — aiguillage du select /criar-conta', () => {
  it('un slug de bibliothèque du réseau donne reader_pending', () => {
    for (const slug of ['blmf', 'btl', 'mleg', 'cira-marseille', 'une-biblio-future']) {
      expect(deriveSignupIntent(slug)).toBe('reader_pending');
    }
  });

  it('la sentinelle orpheline donne reader_orphan', () => {
    expect(deriveSignupIntent(SIGNUP_SENTINELS.ORPHAN)).toBe('reader_orphan');
  });

  it('la sentinelle collective donne collective_candidate', () => {
    expect(deriveSignupIntent(SIGNUP_SENTINELS.COLLECTIVE)).toBe('collective_candidate');
  });

  it('la sentinelle contributeur donne contributor', () => {
    expect(deriveSignupIntent(SIGNUP_SENTINELS.CONTRIBUTOR)).toBe('contributor');
  });

  it("rend toujours une valeur acceptée par la CHECK et par l'EF register", () => {
    const cases = ['', null, undefined, 'blmf', 'constructor', 'toString', '__proto__',
      ...Object.values(SIGNUP_SENTINELS)];
    for (const c of cases) {
      expect(VALID_INTENTS, `slug ${JSON.stringify(c)}`).toContain(deriveSignupIntent(c));
    }
  });

  it("une biblio dont le slug ressemble à une propriété d'Object reste lecteur·rice", () => {
    // Sans hasOwnProperty, BY_SENTINEL['constructor'] rendrait une fonction.
    expect(deriveSignupIntent('constructor')).toBe('reader_pending');
    expect(deriveSignupIntent('toString')).toBe('reader_pending');
  });

  it('isSignupSentinel ne reconnaît que les trois sentinelles', () => {
    expect(Object.values(SIGNUP_SENTINELS).every(isSignupSentinel)).toBe(true);
    for (const slug of ['', 'blmf', 'constructor', '__unknown__']) {
      expect(isSignupSentinel(slug), slug).toBe(false);
    }
  });
});
