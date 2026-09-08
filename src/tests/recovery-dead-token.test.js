import { describe, it, expect } from 'vitest';
import { hashHintsRecovery, decideHashRecovery } from '@/lib/recoveryView';

// Jeton mort dans l'URL (08/09/2026). Le lien de récupération reste dans
// l'historique avec son #access_token ; rechargé après usage, auth-js prend un
// 403 session_not_found, ne pose rien et laisse le fragment. LoginPage, qui a
// ouvert le formulaire « nouveau mot de passe » sur la foi du fragment, doit
// l'abandonner dès que l'auth a fini de charger sans session ni flag recovery.

describe('hashHintsRecovery — le fragment ressemble-t-il à un lien de récupération ?', () => {
  it('reconnaît un atterrissage de lien de récupération', () => {
    expect(hashHintsRecovery('#access_token=eyJ&refresh_token=x&type=recovery')).toBe(true);
    expect(hashHintsRecovery('#type=recovery')).toBe(true);
  });
  it('reconnaît aussi un magic link (access_token sans type=recovery)', () => {
    expect(hashHintsRecovery('#access_token=eyJ&token_type=bearer')).toBe(true);
  });
  it('ignore un fragment vide, absent, ou une erreur GoTrue (lien réutilisé)', () => {
    expect(hashHintsRecovery('')).toBe(false);
    expect(hashHintsRecovery('#')).toBe(false);
    expect(hashHintsRecovery(undefined)).toBe(false);
    expect(hashHintsRecovery('#error=access_denied&error_code=otp_expired')).toBe(false);
  });
});

describe('decideHashRecovery — verdict sur la vue ouverte par le fragment', () => {
  it("ne décide rien si la vue n'a pas été ouverte par le fragment", () => {
    expect(decideHashRecovery({ authLoading: false, hashHinted: false, recovery: false, user: false })).toBe('none');
    // Même avec un flag recovery : c'est le chemin PASSWORD_RECOVERY qui commande, pas nous.
    expect(decideHashRecovery({ authLoading: false, hashHinted: false, recovery: true, user: true })).toBe('none');
  });

  it("attend tant qu'auth-js n'a pas fini", () => {
    expect(decideHashRecovery({ authLoading: true, hashHinted: true, recovery: false, user: false })).toBe('wait');
  });

  it('garde la vue quand le jeton était valide : la session est posée avant que authLoading retombe', () => {
    expect(decideHashRecovery({ authLoading: false, hashHinted: true, recovery: false, user: true })).toBe('keep');
  });

  it('garde la vue quand PASSWORD_RECOVERY est arrivé', () => {
    expect(decideHashRecovery({ authLoading: false, hashHinted: true, recovery: true, user: true })).toBe('keep');
    expect(decideHashRecovery({ authLoading: false, hashHinted: true, recovery: true, user: false })).toBe('keep');
  });

  it('abandonne la vue quand le jeton est mort : auth chargée, ni session ni flag', () => {
    expect(decideHashRecovery({ authLoading: false, hashHinted: true, recovery: false, user: false })).toBe('abandon');
  });

  it("le parcours nominal complet ne produit jamais 'abandon'", () => {
    // 1. montage : fragment présent, auth en cours
    expect(decideHashRecovery({ authLoading: true, hashHinted: true, recovery: false, user: false })).toBe('wait');
    // 2. getSession().then : session + loading=false dans le même lot
    expect(decideHashRecovery({ authLoading: false, hashHinted: true, recovery: false, user: true })).toBe('keep');
    // 3. PASSWORD_RECOVERY un tick plus tard : LoginPage éteint l'indice
    expect(decideHashRecovery({ authLoading: false, hashHinted: false, recovery: true, user: true })).toBe('none');
    // 4. reset réussi, signOut → SIGNED_OUT : indice éteint, plus de verdict
    expect(decideHashRecovery({ authLoading: false, hashHinted: false, recovery: false, user: false })).toBe('none');
  });
});
