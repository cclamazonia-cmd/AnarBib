import { useIntl } from 'react-intl';

// ═══════════════════════════════════════════════════════════
// AnarBib — « Le service est momentanément indisponible » (E33, 07/10/2026).
//
// Le 07/10, la base de production s'est tue vingt et une minutes. Les
// requêtes du navigateur n'ont aucun délai : certaines ont pendu, d'autres
// ont reçu un 522. Mon compte a tourné sans fin, puis, rechargée, n'a montré
// que le fond de la page — ContaRouter attendait trois réponses avant de
// choisir quelle page monter et rendait `null` en attendant. Une page vide
// fait croire à une perte de compte ; ce bloc dit d'attendre et propose de
// réessayer. Il sert en plein écran (ContaRouter, squelette qui s'éternise)
// et en version compacte dans le panneau d'une page déjà montée.
// ═══════════════════════════════════════════════════════════
export default function ServiceIndisponible({ onRetry, compact = false }) {
  const { formatMessage: t } = useIntl();
  const Titre = compact ? 'h2' : 'h1';
  return (
    <div
      role="alert"
      className="ab-service-indisponible"
      style={{ minHeight: compact ? undefined : '70vh', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 24 }}
    >
      <div style={{ maxWidth: 540, width: '100%', textAlign: 'center', border: '1px solid rgba(0,0,0,0.12)', borderRadius: 12, padding: compact ? '28px 24px' : '40px 32px' }}>
        <Titre style={{ fontSize: '1.4rem', margin: '0 0 16px' }}>{t({ id: 'service.unavailable.title' })}</Titre>
        <p style={{ color: 'var(--brand-muted)', lineHeight: 1.6, margin: '0 0 24px' }}>{t({ id: 'service.unavailable.body' })}</p>
        <button type="button" className="ab-button" onClick={onRetry}>{t({ id: 'common.retry' })}</button>
      </div>
    </div>
  );
}
