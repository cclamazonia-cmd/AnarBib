// ═══════════════════════════════════════════════════════════
// AnarBib — un enregistrement en catalogage se confirme (03/10/2026) : la page
// remonte jusqu'au message, doublé d'un toast temporaire.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi } from 'vitest';
import { renderHook, act } from '@testing-library/react';

const notify = vi.fn();
vi.mock('@/contexts/ToastContext', () => ({ useToast: () => ({ notify }) }));

const { useSaveConfirmation } = await import('@/hooks/useSaveConfirmation');

describe('useSaveConfirmation', () => {
  it('pose le message, ouvre un toast et fait défiler jusqu\'au message', () => {
    const setMsg = vi.fn();
    const scrollIntoView = vi.fn();
    const msgRef = { current: { scrollIntoView } };
    const { result } = renderHook(() => useSaveConfirmation(setMsg, msgRef));
    act(() => result.current('Brouillon enregistré'));
    expect(setMsg).toHaveBeenCalledWith({ text: 'Brouillon enregistré', kind: 'ok' });
    expect(notify).toHaveBeenCalledWith({ kind: 'success', message: 'Brouillon enregistré' });
    expect(scrollIntoView).toHaveBeenCalledWith({ behavior: 'smooth', block: 'center' });
  });

  it('avec réserves : toast d\'information, toujours temporaire', () => {
    notify.mockClear();
    const { result } = renderHook(() => useSaveConfirmation(vi.fn(), { current: null }));
    act(() => result.current('Enregistré, mais…', 'warn'));
    expect(notify).toHaveBeenCalledWith({ kind: 'info', message: 'Enregistré, mais…' });
  });

  it('défile à chaque enregistrement, même au même texte', () => {
    const scrollIntoView = vi.fn();
    const { result } = renderHook(() => useSaveConfirmation(vi.fn(), { current: { scrollIntoView } }));
    act(() => result.current('Enregistré'));
    act(() => result.current('Enregistré'));
    expect(scrollIntoView).toHaveBeenCalledTimes(2);
  });
});
