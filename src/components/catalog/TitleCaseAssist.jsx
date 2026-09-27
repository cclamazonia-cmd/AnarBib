// src/components/catalog/TitleCaseAssist.jsx
// C6 — « Normaliser la casse » du titre (spec conventions-catalographiques §7.2).
//
// Trois exigences de la spec, tenues ici :
//   * actif seulement si la langue est renseignée (et couverte par la règle) ;
//   * un APERÇU avant / après, puis « Appliquer » ou « Laisser tel quel » ;
//   * annulable après coup : l'original est gardé jusqu'à la sortie de la fiche.
// Jamais automatique à la frappe. La règle vit dans src/lib/titleCase.js.
import { useState } from 'react';
import { useIntl } from 'react-intl';
import { lowerStopwords, hasTitleCaseRule } from '@/lib/titleCase';

export default function TitleCaseAssist({ titulo, subtitulo, idioma, onApply }) {
  const { formatMessage: t } = useIntl();
  const [apercu, setApercu] = useState(null);     // { titulo, subtitulo } proposés
  const [original, setOriginal] = useState(null); // { titulo, subtitulo } avant application

  const couverte = hasTitleCaseRule(idioma);
  const propose = couverte
    ? { titulo: lowerStopwords(titulo || '', idioma), subtitulo: lowerStopwords(subtitulo || '', idioma) }
    : null;
  const change = !!propose && (propose.titulo !== (titulo || '') || propose.subtitulo !== (subtitulo || ''));

  const muted = { fontSize: '.72rem', color: 'var(--brand-muted, #aaa)' };
  const ligne = { display: 'grid', gridTemplateColumns: 'minmax(0, 6rem) minmax(0, 1fr)', gap: 6, fontSize: '.8rem', alignItems: 'baseline' };

  return (
    <div style={{ gridColumn: 'span 3', display: 'flex', flexDirection: 'column', gap: 6 }} data-testid="title-case-assist">
      <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
        <button type="button" className="ab-button ab-button--secondary ab-button--sm"
          disabled={!couverte || !change || !!apercu}
          title={!couverte ? t({ id: 'catalogacao.titleCase.needLanguage' }) : undefined}
          onClick={() => setApercu(propose)}>
          {t({ id: 'catalogacao.titleCase.button' })}
        </button>
        {!couverte && <span style={muted}>{t({ id: 'catalogacao.titleCase.needLanguage' })}</span>}
        {couverte && !change && !original && titulo && <span style={muted}>{t({ id: 'catalogacao.titleCase.unchanged' })}</span>}
        {original && !apercu && (
          <button type="button" className="ab-button ab-button--ghost ab-button--sm"
            onClick={() => { onApply(original.titulo, original.subtitulo); setOriginal(null); }}>
            {t({ id: 'catalogacao.titleCase.undo' })}
          </button>
        )}
      </div>
      {apercu && (
        <div role="group" aria-label={t({ id: 'catalogacao.titleCase.preview' })}
          style={{ border: '1px solid rgba(255,255,255,.15)', borderRadius: 8, padding: 10, display: 'flex', flexDirection: 'column', gap: 4 }}>
          <div style={muted}>{t({ id: 'catalogacao.titleCase.explain' })}</div>
          <div style={ligne}><span style={muted}>{t({ id: 'catalogacao.titleCase.before' })}</span>
            <span>{titulo}{subtitulo ? ` : ${subtitulo}` : ''}</span></div>
          <div style={ligne}><span style={muted}>{t({ id: 'catalogacao.titleCase.after' })}</span>
            <strong>{apercu.titulo}{apercu.subtitulo ? ` : ${apercu.subtitulo}` : ''}</strong></div>
          <div style={{ display: 'flex', gap: 8, marginTop: 4 }}>
            <button type="button" className="ab-button ab-button--sm"
              onClick={() => { setOriginal({ titulo: titulo || '', subtitulo: subtitulo || '' }); onApply(apercu.titulo, apercu.subtitulo); setApercu(null); }}>
              {t({ id: 'catalogacao.titleCase.apply' })}
            </button>
            <button type="button" className="ab-button ab-button--ghost ab-button--sm" onClick={() => setApercu(null)}>
              {t({ id: 'catalogacao.titleCase.cancel' })}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
