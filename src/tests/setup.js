// ═══════════════════════════════════════════════════════════
// AnarBib — Test setup
// Mocks for Supabase, Auth, Library contexts
// ═══════════════════════════════════════════════════════════

import { vi } from 'vitest';

// Mock Supabase
// SUPABASE_URL : le vrai module l'exporte depuis VITE_SUPABASE_URL ; depuis le
// 20/09/2026 les pages la lisent au lieu de porter l'adresse du projet en dur,
// donc le mock doit la donner — sinon les URL construites valent « undefined/… ».
vi.mock('@/lib/supabase', () => ({
  SUPABASE_URL: 'https://projet-de-test.supabase.co',
  supabase: {
    from: () => ({ select: () => ({ eq: () => ({ data: [], error: null }) }) }),
    rpc: () => ({ data: null, error: null }),
    auth: { getSession: () => ({ data: { session: null } }) },
  },
  apiQuery: () => Promise.resolve({ data: [], error: null }),
}));

// Mock Auth context
vi.mock('@/contexts/AuthContext', () => ({
  useAuth: () => ({ user: null, loading: false }),
  AuthProvider: ({ children }) => children,
}));

// Mock Library context
vi.mock('@/contexts/LibraryContext', () => ({
  useLibrary: () => ({ libraryId: 'test-lib', libraryName: 'Test Library', role: 'reader' }),
  LibraryProvider: ({ children }) => children,
}));

// Mock react-router-dom
vi.mock('react-router-dom', async () => {
  const actual = await vi.importActual('react-router-dom');
  return {
    ...actual,
    useParams: () => ({ id: '1' }),
    useSearchParams: () => [new URLSearchParams(), vi.fn()],
    useNavigate: () => vi.fn(),
    Link: ({ children, to }) => children,
  };
});
