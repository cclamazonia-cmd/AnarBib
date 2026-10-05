import { useIntl } from 'react-intl';

/* ════════════════════════════════════════════════════════════════════════
   AnarBib — « Publié — et maintenant ? » (Xavier, 04/10/2026).

   Après une publication, le catalogage empilait jusqu'ici un message, un
   toast, un bandeau « Ajouter un exemplaire ? » et la fenêtre « œuvre
   nouvelle ou nouvelle édition ? » — qui revenait à chaque publication et
   recouvrait le reste. Un seul encadré les remplace : il dit ce qui vient
   d'être publié et propose toutes les suites utiles.

   <AfterPublishPanel title="…" actions={[{ id, label, hint, onClick, primary }]} onClose={…} />
   Une action à `null`/`false` est simplement omise.
   ════════════════════════════════════════════════════════════════════════ */

export default function AfterPublishPanel({ title, actions, onClose }) {
  const { formatMessage: t } = useIntl();
  const liste = (actions || []).filter(Boolean);
  return (
    <section className="cat-next" role="status" aria-live="polite">
      <header className="cat-next__head">
        <span className="cat-next__check" aria-hidden="true">✓</span>
        <h3 className="cat-next__title">{title}</h3>
        {onClose && (
          <button type="button" className="cat-next__close" onClick={onClose}
            aria-label={t({ id: 'common.close' })} title={t({ id: 'common.close' })}>×</button>
        )}
      </header>
      <div className="cat-next__actions">
        {liste.map((a) => (
          <button key={a.id} type="button" className={`cat-next__action${a.primary ? ' is-primary' : ''}`} onClick={a.onClick}>
            <span className="cat-next__label">{a.label}</span>
            {a.hint && <span className="cat-next__hint">{a.hint}</span>}
          </button>
        ))}
      </div>
    </section>
  );
}
