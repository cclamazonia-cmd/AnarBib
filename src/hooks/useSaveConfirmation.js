import { useCallback, useEffect, useState } from 'react';
import { useToast } from '@/contexts/ToastContext';

// ════════════════════════════════════════════════════════════════════════
// Confirmation d'un enregistrement en catalogage (Xavier, 03/10/2026) : la page
// remonte jusqu'au message de confirmation, et celui-ci apparaît aussi en
// fenêtre temporaire (toast, ToastContext : disparaît seul après 5 s).
//
// setMsg / msgRef : l'état et la référence du message du formulaire. Le
// défilement attend le rendu du message (effet après commit) — un
// requestAnimationFrame peut passer AVANT que React n'ait peint le message
// quand l'enregistrement se termine hors d'un événement.
// ════════════════════════════════════════════════════════════════════════

export function useSaveConfirmation(setMsg, msgRef) {
  const { notify } = useToast();
  const [tick, setTick] = useState(0);

  useEffect(() => {
    if (tick) msgRef.current?.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }, [tick, msgRef]);

  // kind : 'ok' (succès) ou 'warn' (enregistré, avec réserves).
  return useCallback((text, kind = 'ok') => {
    if (!text) return;
    setMsg({ text, kind });
    notify({ kind: kind === 'ok' ? 'success' : 'info', message: text });
    setTick((n) => n + 1);
  }, [setMsg, notify]);
}
