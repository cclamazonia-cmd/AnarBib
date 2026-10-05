import { useState } from 'react';
import { useIntl } from 'react-intl';

// ── ContaTabHeader (chantier #CL — recommandation B, refresh par onglet, 31/05/2026) ───
// Header standard pour les onglets de la page Conta qui méritent un bouton refresh.
// Pattern inspiré de TabHeader dans src/pages/painel/_shared.jsx (paquet E.2 du 28/05),
// mais avec les classes CSS de Conta (ab-conta-section-title) plutôt que celles de
// Painel (ab-painel-h2). Composant local — pas de promotion en src/components/ui/
// pour l'instant, à arbitrer dans une future session de rangement si le pattern
// se généralise.
//
// Props :
//   - title       (string)   : libellé de l'onglet
//   - onRefresh   (function) : callback de rechargement (typiquement loadData)
//   - actions     (node)     : slot optionnel pour boutons supplémentaires à droite
//                              (ex. "Marquer tout comme lu" sur l'onglet avisos)
function ContaTabHeader({ title, onRefresh, actions }) {
  const { formatMessage: t } = useIntl();
  const [busy, setBusy] = useState(false);
  const handleClick = async () => {
    if (busy) return;
    setBusy(true);
    try { await onRefresh(); }
    finally {
      // Délai mini 400ms pour que le feedback visuel soit perceptible
      // même quand l'appel est ultra-rapide (cf. TabHeader Painel).
      setTimeout(() => setBusy(false), 400);
    }
  };
  const label = t({ id: 'common.refresh' });
  return (
    <div style={{
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'center',
      marginBottom: 10,
      gap: 8,
      flexWrap: 'wrap',
    }}>
      <h2 className="ab-conta-section-title" style={{ margin: 0 }}>{title}</h2>
      <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexShrink: 0 }}>
        {actions}
        {onRefresh && (
          <button
            type="button"
            className="ab-button ab-button--secondary ab-button--mini"
            onClick={handleClick}
            disabled={busy}
            title={label}
            style={busy ? { opacity: 0.5, cursor: 'wait' } : undefined}
          >
            ↻ {busy ? `${label}…` : label}
          </button>
        )}
      </div>
    </div>
  );
}

export default ContaTabHeader;
