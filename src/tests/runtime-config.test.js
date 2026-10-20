import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

vi.unmock('@/lib/supabase');

describe('configuration runtime (Zero-Build)', () => {
  beforeEach(() => {
    vi.resetModules();
  });

  afterEach(() => {
    delete window.__ANARBIB_CONFIG__;
    vi.unstubAllEnvs();
  });

  it('lit la clé anonKey depuis window.__ANARBIB_CONFIG__ si présente', async () => {
    window.__ANARBIB_CONFIG__ = { anonKey: 'cle-test-runtime-123' };
    vi.stubEnv('VITE_SUPABASE_URL', 'http://localhost');
    const { SUPABASE_ANON_KEY } = await import('@/lib/supabase');
    expect(SUPABASE_ANON_KEY).toBe('cle-test-runtime-123');
  });

  it('utilise VITE_SUPABASE_PUBLISHABLE_KEY si window.__ANARBIB_CONFIG__ est vide', async () => {
    window.__ANARBIB_CONFIG__ = {};
    vi.stubEnv('VITE_SUPABASE_URL', 'http://localhost');
    vi.stubEnv('VITE_SUPABASE_PUBLISHABLE_KEY', 'cle-test-build-456');
    const { SUPABASE_ANON_KEY } = await import('@/lib/supabase');
    expect(SUPABASE_ANON_KEY).toBe('cle-test-build-456');
  });
});
