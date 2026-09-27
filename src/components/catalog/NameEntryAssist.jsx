// src/components/catalog/NameEntryAssist.jsx
// C6 — l'assistant de découpage du nom (spec conventions-catalographiques §7.1).
//
// Sous le nom tapé « comme on le dit », il montre le point d'accès proposé et
// la règle en une ligne, avec trois gestes : Confirmer, Corriger (choisir le
// mot où commence le nom de famille), Nom unique / pseudonyme. Quand le pays
// est hispanophone, il offre en plus la variante à deux noms de famille.
// Rien n'est jamais bloquant : c'est une proposition, la fiche part quand même.
//
// Depuis le 27/09, il propose aussi la CASSE NATURELLE du nom (CONV-1 : « osvaldo
// BAYER » → « Osvaldo Bayer »), comme le bouton des titres : un aperçu où chaque
// mot se clique pour lui rendre ou lui retirer sa majuscule, appliquer, annuler.
import { useState } from 'react';
import { useIntl } from 'react-intl';
import { proposerPointAcces, formeDepuis, proposerCasseNom, proposerCasseCollectivite, basculerMajuscule } from '@/lib/nameEntry';

// `collectivite` : seul le bloc de casse (la découpe « Nom, Prénom » ne vaut que pour une personne).
export default function NameEntryAssist({ nom, country, nameLang, formeActuelle, onChoisir, onNom, collectivite = false }) {
  const { formatMessage: t } = useIntl();
  const [corriger, setCorriger] = useState(false);
  const [casse, setCasse] = useState(null);       // mots proposés, modifiables
  const [original, setOriginal] = useState(null); // le nom avant la normalisation
  const p = proposerPointAcces(nom, { country, nameLang });
  const pc = collectivite ? proposerCasseCollectivite(nom, { nameLang }) : proposerCasseNom(nom);
  if (collectivite ? !(nom || '').trim() : (p.regle === 'vide' || p.regle === 'inverse')) return null;
  const motBtn = { background: 'none', border: 'none', borderBottom: '1px dotted rgba(255,255,255,.35)', color: 'inherit', font: 'inherit', fontWeight: 600, padding: 0, cursor: 'pointer' };

  const muted = { fontSize: '.72rem', color: 'var(--brand-muted, #aaa)' };
  const chip = (actif) => ({
    border: '1px solid rgba(255,255,255,.25)', borderRadius: 999, padding: '2px 10px', fontSize: '.78rem', cursor: 'pointer',
    background: actif ? 'rgba(255,255,255,.18)' : 'transparent', color: 'inherit',
  });
  const choisir = (forme) => { onChoisir(forme); setCorriger(false); };
  // Clé de l'explication : direct | filiation | single | hispanic | kept | article
  const CLE_REGLE = { mononyme: 'single', hispanique: 'hispanic', conservee: 'kept' };
  const regleCle = CLE_REGLE[p.regle] || p.regle;

  return (
    <div data-testid="name-entry-assist" style={{ marginTop: 6, display: 'flex', flexDirection: 'column', gap: 4 }}>
      {onNom && (pc.change || original !== null) && !casse && (
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center' }}>
          {pc.change && (
            <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={() => setCasse(pc.mots)}>
              {t({ id: 'catalogacao.titleCase.button' })}
            </button>
          )}
          {original !== null && (
            <button type="button" className="ab-button ab-button--ghost ab-button--sm"
              onClick={() => { onNom(original); setOriginal(null); }}>
              {t({ id: 'catalogacao.titleCase.undo' })}
            </button>
          )}
        </div>
      )}
      {casse && (
        <div role="group" aria-label={t({ id: 'catalogacao.titleCase.preview' })}
          style={{ border: '1px solid rgba(255,255,255,.15)', borderRadius: 8, padding: 8, display: 'flex', flexDirection: 'column', gap: 4 }}>
          <div style={muted}>{t({ id: collectivite ? 'catalogacao.nameEntry.caseExplainOrg' : 'catalogacao.nameEntry.caseExplain' })}</div>
          <div style={{ fontSize: '.85rem' }} data-testid="name-case-after">
            {casse.map((m, i) => (
              <span key={`${m.texte}-${i}`}>
                {i > 0 && ' '}
                {m.fige ? <strong>{m.texte}</strong> : (
                  <button type="button" style={motBtn}
                    onClick={() => setCasse((c) => c.map((x, j) => (j === i ? { ...x, texte: basculerMajuscule(x.texte) } : x)))}>
                    {m.texte}
                  </button>
                )}
              </span>
            ))}
          </div>
          <div style={muted}>{t({ id: collectivite ? 'catalogacao.titleCase.properHint' : 'catalogacao.nameEntry.caseHint' })}</div>
          <div style={{ display: 'flex', gap: 6 }}>
            <button type="button" className="ab-button ab-button--sm"
              onClick={() => { setOriginal(nom); onNom(casse.map((m) => m.texte).join(' ')); setCasse(null); }}>
              {t({ id: 'catalogacao.titleCase.apply' })}
            </button>
            <button type="button" className="ab-button ab-button--ghost ab-button--sm" onClick={() => setCasse(null)}>
              {t({ id: 'catalogacao.titleCase.cancel' })}
            </button>
          </div>
        </div>
      )}
      {!collectivite && (<>
      <div style={{ fontSize: '.8rem' }}>
        <span style={muted}>{t({ id: 'catalogacao.nameEntry.proposed' })} </span>
        <strong>{p.forme}</strong>
        {formeActuelle === p.forme && <span style={muted}> · {t({ id: 'catalogacao.nameEntry.inUse' })}</span>}
      </div>
      <div style={muted}>{t({ id: `catalogacao.nameEntry.rule.${regleCle}` })}</div>
      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
        {formeActuelle !== p.forme && (
          <button type="button" className="ab-button ab-button--sm" onClick={() => choisir(p.forme)}>
            {t({ id: 'catalogacao.nameEntry.confirm' })}
          </button>
        )}
        {p.tokens.length > 1 && (
          <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={() => setCorriger((v) => !v)}>
            {t({ id: 'catalogacao.nameEntry.correct' })}
          </button>
        )}
        {p.tokens.length > 1 && formeActuelle !== nom.replace(/\s+/g, ' ').trim() && (
          <button type="button" className="ab-button ab-button--ghost ab-button--sm" onClick={() => choisir(p.tokens.join(' '))}>
            {t({ id: 'catalogacao.nameEntry.single' })}
          </button>
        )}
      </div>
      {p.variante && (
        <div style={{ fontSize: '.78rem', display: 'flex', gap: 6, alignItems: 'baseline', flexWrap: 'wrap' }}>
          <span style={muted}>{t({ id: `catalogacao.nameEntry.rule.${CLE_REGLE[p.variante.regle] || p.variante.regle}` })}</span>
          <button type="button" className="ab-button ab-button--ghost ab-button--sm" onClick={() => choisir(p.variante.forme)}>
            {p.variante.forme}
          </button>
        </div>
      )}
      {corriger && (
        <div role="group" aria-label={t({ id: 'catalogacao.nameEntry.pickSurname' })} style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
          <span style={muted}>{t({ id: 'catalogacao.nameEntry.pickSurname' })}</span>
          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
            {p.tokens.map((mot, i) => (
              <button key={`${mot}-${i}`} type="button" style={chip(i === p.debut)} disabled={i === 0}
                onClick={() => choisir(formeDepuis(p.tokens, i))}>
                {mot}
              </button>
            ))}
          </div>
        </div>
      )}
      </>)}
    </div>
  );
}
