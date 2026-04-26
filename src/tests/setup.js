// ═══════════════════════════════════════════════════════════
// AnarBib — Test setup
// Mocks for Supabase, Auth, Library contexts
// ═══════════════════════════════════════════════════════════

import { vi } from 'vitest';

// Mock Supabase
vi.mock('@/lib/supabase', () => ({
  supabase: {
    from: () => ({ select: () => ({ eq: () => ({ data: [], error: null }) }) }),
    rpc: () => ({ data: null, error: null }),
    auth: { getSession: () => ({ data: { session: null } }) },
  },
  apiQuery: () => Promise.resolve({ data: [], error: null }),
  notifyEvent: () => Promise.resolve(),
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
