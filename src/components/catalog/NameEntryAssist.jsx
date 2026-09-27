// src/components/catalog/NameEntryAssist.jsx
// C6 — l'assistant de découpage du nom (spec conventions-catalographiques §7.1).
//
// Sous le nom tapé « comme on le dit », il montre le point d'accès proposé et
// la règle en une ligne, avec trois gestes : Confirmer, Corriger (choisir le
// mot où commence le nom de famille), Nom unique / pseudonyme. Quand le pays
// est hispanophone, il offre en plus la variante à deux noms de famille.
// Rien n'est jamais bloquant : c'est une proposition, la fiche part quand même.
import { useState } from 'react';
import { useIntl } from 'react-intl';
import { proposerPointAcces, formeDepuis } from '@/lib/nameEntry';

export default function NameEntryAssist({ nom, country, formeActuelle, onChoisir }) {
  const { formatMessage: t } = useIntl();
  const [corriger, setCorriger] = useState(false);
  const p = proposerPointAcces(nom, { country });
  if (p.regle === 'vide' || p.regle === 'inverse') return null;

  const muted = { fontSize: '.72rem', color: 'var(--brand-muted, #aaa)' };
  const chip = (actif) => ({
    border: '1px solid rgba(255,255,255,.25)', borderRadius: 999, padding: '2px 10px', fontSize: '.78rem', cursor: 'pointer',
    background: actif ? 'rgba(255,255,255,.18)' : 'transparent', color: 'inherit',
  });
  const choisir = (forme) => { onChoisir(forme); setCorriger(false); };
  const regleCle = p.regle === 'mononyme' ? 'single' : p.regle;   // direct | filiation | single

  return (
    <div data-testid="name-entry-assist" style={{ marginTop: 6, display: 'flex', flexDirection: 'column', gap: 4 }}>
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
          <span style={muted}>{t({ id: 'catalogacao.nameEntry.rule.hispanic' })}</span>
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
    </div>
  );
}
