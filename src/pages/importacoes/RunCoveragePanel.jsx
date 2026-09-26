// ── Couverture d'un import (H16, 26/09/2026) ──────────────────────────────
// Ce que l'import a REPRIS du fichier, relu en INDICE (collection, cote
// locale), ou gardé seulement en BRUT — par zone MARC, colonne CSV ou balise
// RIS (summary.coverage, écrit par l'EF). Jusqu'ici la perte ne se voyait
// nulle part : l'import Solidaires n'avait repris que 4 colonnes sur 17 sans
// que rien ne le dise. Le rapport complet se télécharge en CSV : c'est le
// compte rendu qu'on renvoie à la bibliothèque qui a fourni le fichier.
import { useIntl } from 'react-intl';
import { coverageItems, coverageItemLabel, coverageToCsv } from '../../lib/importCoverage.js';

const muted = { color: 'var(--brand-muted, #999)' };
const cell = { padding: '3px 8px', borderBottom: '1px solid var(--brand-border, rgba(0,0,0,.08))', textAlign: 'left', verticalAlign: 'top' };
const MAX_LIGNES = 60;

function telecharger(texte, nom) {
  const blob = new Blob(['﻿' + texte], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = nom;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

export default function RunCoveragePanel({ run }) {
  const { formatMessage: t } = useIntl();
  const coverage = run?.summary?.coverage || null;
  const counts = run?.summary?.coverage_counts || null;
  const skipped = Number(run?.summary?.skipped_rows || 0);
  if (!coverage) {
    return run?.summary ? (
      <p className="imp-note" style={{ margin: '0 0 12px', fontSize: '.78rem' }} data-testid="run-coverage-none">
        {t({ id: 'importacoes.coverage.none' })}
      </p>
    ) : null;
  }
  const nonRepris = coverageItems(coverage).filter((it) => it.status !== 'repris')
    .sort((a, b) => (b.occurrences || 0) - (a.occurrences || 0));
  const surplus = coverageItems(coverage).filter((it) => it.status === 'repris' && (it.surplus || 0) > 0);
  return (
    <div className="imp-sheet" style={{ marginBottom: 12 }} data-testid="run-coverage">
      <div className="imp-sheet__body">
        <span className="ab-field__label">{t({ id: 'importacoes.coverage.title' })}</span>
        {counts && (
          <p className="imp-note" style={{ margin: '4px 0 0' }} data-coverage-counts>
            {t({ id: 'importacoes.coverage.counts' }, counts)}
          </p>
        )}
        {skipped > 0 && (
          <p className="imp-note" style={{ margin: '4px 0 0', color: 'var(--brand-warning, #9a6700)', fontWeight: 600 }}>
            {t({ id: 'importacoes.coverage.skipped' }, { n: skipped })}
          </p>
        )}
        <p className="imp-note" style={{ margin: '4px 0 8px', fontSize: '.76rem' }}>{t({ id: 'importacoes.coverage.explain' })}</p>
        {(nonRepris.length > 0 || surplus.length > 0) && (
          <details>
            <summary style={{ cursor: 'pointer' }}>
              {t({ id: 'importacoes.coverage.notTaken' })} · <strong>{nonRepris.length}</strong>
            </summary>
            <div style={{ overflowX: 'auto', maxWidth: '100%' }}>
              <table style={{ borderCollapse: 'collapse', fontSize: '.78rem', marginTop: 6, width: '100%' }}>
                <tbody>
                  {nonRepris.slice(0, MAX_LIGNES).map((it) => (
                    <tr key={`${it.dialect || ''}|${coverageItemLabel(it)}`} data-coverage-item={coverageItemLabel(it)}>
                      <td style={{ ...cell, whiteSpace: 'nowrap', fontFamily: 'monospace' }}>{coverageItemLabel(it)}</td>
                      <td style={cell}>{t({ id: `importacoes.coverage.status.${it.status}` })}</td>
                      <td style={{ ...cell, whiteSpace: 'nowrap' }}>{t({ id: 'importacoes.coverage.occurrences' }, { n: it.occurrences || 0 })}</td>
                      <td style={{ ...cell, ...muted, wordBreak: 'break-word' }}>{it.example || ''}</td>
                    </tr>
                  ))}
                  {surplus.map((it) => (
                    <tr key={`surplus|${coverageItemLabel(it)}`} data-coverage-item={coverageItemLabel(it)}>
                      <td style={{ ...cell, whiteSpace: 'nowrap', fontFamily: 'monospace' }}>{coverageItemLabel(it)}</td>
                      <td style={cell} colSpan={3}>{t({ id: 'importacoes.coverage.surplus' }, { n: it.surplus })}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {nonRepris.length > MAX_LIGNES && (
                <p className="imp-note" style={{ margin: '4px 0 0' }}>{t({ id: 'importacoes.coverage.more' }, { n: nonRepris.length - MAX_LIGNES })}</p>
              )}
            </div>
          </details>
        )}
        <button className="cat-btn secondary" type="button" style={{ marginTop: 8 }}
          onClick={() => telecharger(coverageToCsv(coverage, { filename: run.original_filename || '', runId: run.id }),
            `couverture-import-${run.id}.csv`)}>
          {t({ id: 'importacoes.coverage.download' })}
        </button>
      </div>
    </div>
  );
}
