import { createContext, useCallback, useContext, useRef, useState } from 'react';
import { useIntl } from 'react-intl';
import Modal from '@/components/ui/Modal';

/* ════════════════════════════════════════════════════════════════════════
   AnarBib — ConfirmContext
   Fenêtre de confirmation de l'application, à la place de window.confirm()
   (Xavier, 04/10/2026 : « rendre plus pratique, lisible et clair »).

   const confirmer = useConfirm();
   if (!(await confirmer({ message, title, confirmLabel, tone: 'danger' }))) return;

   - message      : chaîne déjà traduite (obligatoire). Les sauts de ligne
                    deviennent des paragraphes.
   - title        : titre court (défaut « Confirmer »).
   - confirmLabel : le bouton nomme l'action (« Supprimer définitivement »,
                    « Publier »…) plutôt qu'un « OK » muet.
   - tone         : 'danger' pour une action destructive ou irréversible.

   Échap, clic sur le voile et « Annuler » répondent non. La modale est en
   portail : elle reste visible même ouverte depuis un panneau masqué du
   catalogage. Sans fournisseur (tests isolés), repli sur window.confirm.
   ════════════════════════════════════════════════════════════════════════ */

const ConfirmContext = createContext(null);

export function ConfirmProvider({ children }) {
  const { formatMessage: t } = useIntl();
  const [demande, setDemande] = useState(null); // { message, title, confirmLabel, cancelLabel, tone }
  const resoudre = useRef(null);

  const confirmer = useCallback((options) => {
    const o = typeof options === 'string' ? { message: options } : (options || {});
    // Une seule fenêtre à la fois : une demande pendante répond non.
    if (resoudre.current) resoudre.current(false);
    return new Promise((resolve) => {
      resoudre.current = resolve;
      setDemande(o);
    });
  }, []);

  const repondre = useCallback((oui) => {
    const r = resoudre.current;
    resoudre.current = null;
    setDemande(null);
    if (r) r(oui);
  }, []);

  const paragraphes = String(demande?.message || '').split(/\n+/).filter(Boolean);

  return (
    <ConfirmContext.Provider value={confirmer}>
      {children}
      <Modal isOpen={!!demande} onClose={() => repondre(false)} size="small"
        title={demande?.title || t({ id: 'common.confirm' })}>
        {paragraphes.map((p, i) => <p key={i} style={{ margin: '0 0 10px' }}>{p}</p>)}
        <div className="ab-modal__actions">
          <button type="button" className="ab-button ab-button--secondary" onClick={() => repondre(false)}>
            {demande?.cancelLabel || t({ id: 'common.cancel' })}
          </button>
          <button type="button"
            className={`ab-button${demande?.tone === 'danger' ? ' ab-button--danger' : ''}`}
            onClick={() => repondre(true)}>
            {demande?.confirmLabel || t({ id: 'common.confirm' })}
          </button>
        </div>
      </Modal>
    </ConfirmContext.Provider>
  );
}

export function useConfirm() {
  const ctx = useContext(ConfirmContext);
  return ctx || ((o) => Promise.resolve(window.confirm(typeof o === 'string' ? o : o?.message || '')));
}
