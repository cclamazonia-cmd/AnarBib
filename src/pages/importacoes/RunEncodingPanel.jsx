// ── Encodage d'un import (H15, 26/09/2026) ────────────────────────────────
// Ce que l'EF process-partner-catalog-import a lu (summary.encoding : used,
// forced, fallback, declared_unimarc) et, tant que l'import n'a produit aucun
// brouillon, le geste « Retraiter » : relire le même fichier avec un encodage
// imposé. Les phrases viennent des dix locales, à partir des champs
// structurés du résumé — pas des avertissements de l'EF, écrits dans une seule
// langue pour la file de révision.
//
// Pourquoi « supposé » : sans forçage, l'EF lit en UTF-8 strict et, si le
// fichier n'en est pas, SUPPOSE Windows-1252 (latin-1). Un export MacRoman ou
// ISO 5426 serait mal lu sans erreur : c'est à la personne de vérifier les
// accents, et de retraiter en imposant l'encodage.
import { useIntl } from 'react-intl';

const ENCODING_LABEL = { 'utf-8': 'UTF-8', 'windows-1252': 'Windows-1252 (latin-1)' };

export default function RunEncodingPanel({ run, reprocessEncoding, setReprocessEncoding, reprocessing, onReprocess }) {
  const { formatMessage: t } = useIntl();
  const enc = run?.summary?.encoding || null;
  const promoted = (run?.created_drafts || 0) > 0 || run?.run_status === 'drafts_created';
  const label = enc ? (ENCODING_LABEL[enc.used] || enc.used) : null;
  const declared = Array.isArray(enc?.declared_unimarc) ? enc.declared_unimarc : [];
  const unsupported = declared.filter((c) => c !== '50' && c !== '01');
  const lines = [];
  if (enc) {
    if (enc.forced) lines.push({ key: 'forced', text: t({ id: 'importacoes.run.encoding.forced' }, { enc: label }) });
    else if (enc.fallback) lines.push({ key: 'fallback', warn: true, text: t({ id: 'importacoes.run.encoding.fallback' }, { enc: label }) });
    else lines.push({ key: 'auto', text: t({ id: 'importacoes.run.encoding.auto' }, { enc: label }) });
    if (declared.includes('50') && enc.fallback) {
      lines.push({ key: 'declaredUnicode', warn: true, text: t({ id: 'importacoes.run.encoding.declaredUnicode' }) });
    }
    if (unsupported.length) {
      lines.push({ key: 'declaredUnsupported', warn: true, text: t({ id: 'importacoes.run.encoding.declaredUnsupported' }, { codes: unsupported.join(', ') }) });
    }
  }
  // Un import promu sans résumé d'encodage (antérieur à H15) : rien à dire.
  if (!enc && promoted) return null;
  return (
    <div className="imp-sheet" style={{ marginBottom: 12 }} data-testid="run-encoding">
      <div className="imp-sheet__body">
        {enc && (
          <div style={{ marginBottom: promoted ? 0 : 10 }}>
            <span className="ab-field__label">{t({ id: 'importacoes.run.encoding.label' })}</span>
            {lines.map((l) => (
              <p key={l.key} className="imp-note" data-encoding-line={l.key}
                style={{ margin: '4px 0 0', ...(l.warn ? { color: 'var(--brand-warning, #9a6700)', fontWeight: 600 } : {}) }}>
                {l.text}
              </p>
            ))}
          </div>
        )}
        {promoted ? (
          <p className="imp-note" style={{ margin: '6px 0 0', fontSize: '.78rem' }}>{t({ id: 'importacoes.run.reprocess.locked' })}</p>
        ) : (
          <div style={{ display: 'flex', alignItems: 'flex-end', gap: 10, flexWrap: 'wrap' }}>
            <div className="ab-field" style={{ minWidth: 0 }}>
              <label className="ab-field__label" htmlFor="imp-reprocess-encoding">{t({ id: 'importacoes.run.reprocess.title' })}</label>
              <select id="imp-reprocess-encoding" className="ab-select" value={reprocessEncoding}
                onChange={(e) => setReprocessEncoding(e.target.value)} disabled={reprocessing}>
                <option value="auto">{t({ id: 'importacoes.adapter.autoDetect' })}</option>
                <option value="utf-8">{t({ id: 'importacoes.adapter.encodingUtf8' })}</option>
                <option value="windows-1252">{t({ id: 'importacoes.adapter.encodingLatin1' })}</option>
              </select>
            </div>
            <button className="cat-btn secondary" type="button" disabled={reprocessing} onClick={onReprocess}>
              {reprocessing ? t({ id: 'importacoes.refreshing' }) : t({ id: 'importacoes.run.reprocess.button' })}
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
