import { useCallback } from 'react';
import { useToast } from '@/contexts/ToastContext';

// ════════════════════════════════════════════════════════════════════════
// Confirmation d'un enregistrement en catalogage.
//
// 03/10/2026 : la page remontait jusqu'au message, doublé d'un toast.
// 04/10/2026 (décision de Xavier, « barre collante + toast ») : le message vit
// dans la CatalogStatusBar, collante en haut du panneau — toujours visible,
// la page ne saute plus. Ce hook pose le message et ouvre le toast temporaire
// (ToastContext : disparaît seul après 5 s).
// ════════════════════════════════════════════════════════════════════════

export function useSaveConfirmation(setMsg) {
  const { notify } = useToast();

  // kind : 'ok' (succès) ou 'warn' (enregistré, avec réserves).
  return useCallback((text, kind = 'ok') => {
    if (!text) return;
    setMsg({ text, kind });
    notify({ kind: kind === 'ok' ? 'success' : 'info', message: text });
  }, [setMsg, notify]);
}
