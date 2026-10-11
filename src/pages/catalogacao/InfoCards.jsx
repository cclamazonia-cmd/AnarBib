// src/pages/catalogacao/InfoCards.jsx — E6, lot 8 (28/09/2026) ; C29 lot 4 (11/10/2026)
// La carte « para informação » de l'aperçu de la fiche : les auteur·rices,
// liées ou non à une autorité, avec le rappel vers l'onglet Autorité.
//
// La carte des exemplaires qui vivait ici (liste de mes exemplaires cliquables
// vers une reprise dans Indexation, compte des autres bibliothèques) a été
// retirée le 11/10/2026 (C29 lot 4, décision de Xavier) : elle redisait le
// panneau Exemplaires de la fiche (ExemplaresPanel), où les exemplaires se
// lisent, se créent et se modifient sur place. Le parent passe les
// contributeur·rices et le rappel de navigation. Rien ici n'écrit le
// formulaire ni ne lit la base.
import { useIntl } from 'react-intl';

export default function InfoCards({ contributors, onNavigateTab }) {
  const { formatMessage: t } = useIntl();

  const cardStyle = { marginTop: 12, border: '1px solid rgba(255,255,255,.12)', borderRadius: 8, padding: '10px 12px', cursor: 'pointer', background: 'rgba(0,0,0,.18)' };
  const headStyle = { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6, flexWrap: 'wrap', gap: 6 };
  const titleStyle = { fontWeight: 700, fontSize: '.82rem' };
  const tagStyle = { fontSize: '.6rem', textTransform: 'uppercase', letterSpacing: '.04em', color: 'var(--brand-muted,#9aa)', border: '1px solid rgba(255,255,255,.15)', borderRadius: 4, padding: '1px 5px' };
  const lineStyle = { display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8, fontSize: '.8rem', padding: '2px 0', flexWrap: 'wrap' };
  const ctaStyle = { marginTop: 6, fontSize: '.74rem', color: 'var(--brand-color-primary,#c0392b)', fontWeight: 600 };
  const emptyStyle = { fontSize: '.78rem', color: 'var(--brand-muted,#888)', fontStyle: 'italic' };
  const pillStyle = { flexShrink: 0, fontSize: '.6rem' };
  const authors = (contributors || []).filter(c => (c.name || '').trim());
  const goAuthor = () => onNavigateTab?.('authorsPanel');
  return (
    <div className="ab-info-cards">
      {/* Card AUTORIA */}
      <div style={cardStyle} role="button" tabIndex={0} onClick={goAuthor}
        onKeyDown={e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); goAuthor(); } }}
        title={t({ id: 'catalogacao.infocard.goAuthor' })}>
        <div style={headStyle}>
          <span style={titleStyle}>{t({ id: 'catalogacao.infocard.authorTitle' })}</span>
          <span style={tagStyle}>{t({ id: 'catalogacao.infocard.forInfo' })}</span>
        </div>
        {authors.length === 0
          ? <div style={emptyStyle}>{t({ id: 'catalogacao.infocard.noAuthor' })}</div>
          : authors.map((c, i) => (
              <div key={i} style={lineStyle}>
                <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{c.name}</span>
                <span className={`cat-pill ${c.author_id ? 'ok' : 'warn'}`} style={pillStyle}>
                  {c.author_id ? t({ id: 'catalogacao.infocard.linked' }) : t({ id: 'catalogacao.infocard.unlinked' })}
                </span>
              </div>
            ))}
        <div style={ctaStyle}>{t({ id: 'catalogacao.infocard.goAuthor' })} →</div>
      </div>
    </div>
  );
}
