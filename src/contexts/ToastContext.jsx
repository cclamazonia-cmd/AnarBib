import { createContext, useContext, useState, useCallback, useRef } from 'react';
import ToastViewport from '@/components/ui/ToastViewport';

/* ════════════════════════════════════════════════════════════════════════
   AnarBib — ToastContext
   Système de notification non-bloquant, appelable depuis n'importe quel
   composant via le hook useToast(). Remplace les alert() bruts du navigateur
   (chantier A, écart EA-09 de l'audit Painel — 26/05/2026).

   Doctrine de comportement (décisions de cadrage 26/05/2026) :
   - succès  : auto-disparition après TOAST_SUCCESS_TTL ms ;
   - erreur  : persistant, ne disparaît qu'au clic de fermeture
               (au comptoir, une erreur ne doit pas se rater) ;
   - le message technique brut (e.message) n'est JAMAIS affiché : il part
     en console.error. L'écran ne montre qu'un message humain traduit.
   ════════════════════════════════════════════════════════════════════════ */

const TOAST_SUCCESS_TTL = 5000; // ms — durée de vie d'un toast de succès

const ToastContext = createContext({
  toasts: [],
  notify: () => {},
  notifySuccess: () => {},
  notifyError: () => {},
  dismiss: () => {},
});

export function ToastProvider({ children }) {
  const [toasts, setToasts] = useState([]);
  const idRef = useRef(0);

  const dismiss = useCallback((id) => {
    setToasts((list) => list.filter((t) => t.id !== id));
  }, []);

  // notify({ kind, message }) — primitive bas niveau.
  //  kind : 'success' | 'error' | 'info'
  //  message : chaîne DÉJÀ traduite et compréhensible par un humain.
  const notify = useCallback(({ kind = 'info', message }) => {
    if (!message) return;
    const id = ++idRef.current;
    setToasts((list) => [...list, { id, kind, message }]);
    // Auto-disparition pour succès et info ; les erreurs restent.
    if (kind !== 'error') {
      setTimeout(() => {
        setToasts((list) => list.filter((t) => t.id !== id));
      }, TOAST_SUCCESS_TTL);
    }
    return id;
  }, []);

  const notifySuccess = useCallback(
    (message) => notify({ kind: 'success', message }),
    [notify]
  );

  // notifyError(message, technicalError?)
  //  message        : chaîne humaine traduite, affichée à l'écran.
  //  technicalError : optionnel — l'objet Error ou le message brut Supabase.
  //                   Jamais affiché ; uniquement logué pour le diagnostic dev.
  const notifyError = useCallback(
    (message, technicalError) => {
      if (technicalError) {
        // Seul canal du détail technique : la console.
        console.error('[AnarBib]', message, '—', technicalError);
      }
      return notify({ kind: 'error', message });
    },
    [notify]
  );

  return (
    <ToastContext.Provider
      value={{ toasts, notify, notifySuccess, notifyError, dismiss }}
    >
      {children}
      <ToastViewport toasts={toasts} onDismiss={dismiss} />
    </ToastContext.Provider>
  );
}

export function useToast() {
  return useContext(ToastContext);
}
