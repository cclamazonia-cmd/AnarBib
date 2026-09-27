// src/components/catalog/TitleCaseAssist.jsx
// C6 — « Normaliser la casse » du titre (spec conventions-catalographiques §4.1, §7.2).
//
// Trois exigences de la spec, tenues ici :
//   * actif seulement si la langue est renseignée (et couverte par la règle) ;
//   * un APERÇU avant / après, puis « Appliquer » ou « Laisser tel quel » ;
//   * annulable après coup : l'original est gardé jusqu'à la sortie de la fiche.
// Jamais automatique à la frappe. La règle vit dans src/lib/titleCase.js ; elle
// ne sait pas reconnaître un nom propre : dans l'aperçu, un clic sur un mot lui
// rend (ou lui retire) sa majuscule.
import { useState } from 'react';
import { useIntl } from 'react-intl';
import { proposerCasse, titleCaseRule, avecMajuscule } from '@/lib/titleCase';

const joindre = (mots) => mots.map((m) => m.texte).join(' ');
const EXPLICATION = { phrase: 'explainSentence', titre: 'explainTitle', outils: 'explain' };

export default function TitleCaseAssist({ titulo, subtitulo, idioma, onApply }) {
  const { formatMessage: t } = useIntl();
  const [apercu, setApercu] = useState(null);     // { titre: mots[], sous: mots[] } proposés, modifiables
  const [original, setOriginal] = useState(null); // { titulo, subtitulo } avant application

  const regle = titleCaseRule(idioma);
  const couverte = regle !== null;
  const propose = couverte
    ? { titre: proposerCasse(titulo || '', idioma).mots, sous: proposerCasse(subtitulo || '', idioma, { sousTitre: true }).mots }
    : null;
  const change = !!propose && (joindre(propose.titre) !== (titulo || '').replace(/\s+/g, ' ').trim()
    || joindre(propose.sous) !== (subtitulo || '').replace(/\s+/g, ' ').trim());

  const loc = String(idioma || '').split('-')[0];
  const basculer = (champ, i) => setApercu((a) => ({
    ...a,
    [champ]: a[champ].map((m, j) => {
      if (j !== i || m.fige) return m;
      const k = m.texte.search(/\p{L}/u);
      if (k < 0) return m;
      const maj = m.texte[k] !== m.texte[k].toLocaleLowerCase(loc);
      return { ...m, texte: maj ? m.texte.slice(0, k) + m.texte[k].toLocaleLowerCase(loc) + m.texte.slice(k + 1) : avecMajuscule(m.texte, loc) };
    }),
  }));

  const muted = { fontSize: '.72rem', color: 'var(--brand-muted, #aaa)' };
  const ligne = { display: 'grid', gridTemplateColumns: 'minmax(0, 6rem) minmax(0, 1fr)', gap: 6, fontSize: '.8rem', alignItems: 'baseline' };
  const motBtn = { background: 'none', border: 'none', borderBottom: '1px dotted rgba(255,255,255,.35)', color: 'inherit', font: 'inherit', fontWeight: 600, padding: 0, cursor: 'pointer' };
  const mots = (champ) => apercu[champ].map((m, i) => (
    <span key={`${champ}-${i}`}>
      {i > 0 && ' '}
      {m.fige ? <strong>{m.texte}</strong> : (
        <button type="button" style={motBtn} onClick={() => basculer(champ, i)}>{m.texte}</button>
      )}
    </span>
  ));

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
          <div style={muted}>{t({ id: `catalogacao.titleCase.${EXPLICATION[regle]}` })}</div>
          <div style={ligne}><span style={muted}>{t({ id: 'catalogacao.titleCase.before' })}</span>
            <span>{titulo}{subtitulo ? ` : ${subtitulo}` : ''}</span></div>
          <div style={ligne}><span style={muted}>{t({ id: 'catalogacao.titleCase.after' })}</span>
            <span data-testid="title-case-after">{mots('titre')}{apercu.sous.length > 0 && <> : {mots('sous')}</>}</span></div>
          {regle !== 'outils' && <div style={muted}>{t({ id: 'catalogacao.titleCase.properHint' })}</div>}
          <div style={{ display: 'flex', gap: 8, marginTop: 4 }}>
            <button type="button" className="ab-button ab-button--sm"
              onClick={() => { setOriginal({ titulo: titulo || '', subtitulo: subtitulo || '' }); onApply(joindre(apercu.titre), joindre(apercu.sous)); setApercu(null); }}>
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
