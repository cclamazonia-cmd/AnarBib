/**
 * OcrDepositTab.jsx — dépôt de fonds scanné par OCR navigateur (piste B, P3b).
 *
 * Cadrage : docs/journal/cadrages/CADRAGE_ocr_import_navigateur_2026-06-17.md
 *           (amendement 2026-06-17 : intégration par Catalogação direct).
 *
 * Flux : déposer un PDF → OCR 100 % navigateur (ou texte natif si born-digital)
 * → pré-remplissage heuristique (regex, zéro LLM) → handoff vers BookDraftForm
 * pré-rempli (prefillRecord + prefillFile) pour révision humaine et création du
 * brouillon réel (book_drafts + PDF + subjects, via le chemin catalogação
 * existant). Réutilise les modules purs ocrPipeline + heuristics (P1/P2).
 */

import { useCallback, useRef, useState } from 'react';
import { useIntl } from 'react-intl';
import { processPdf } from '@/components/ocr/ocrPipeline';
import { extractFields } from '@/components/ocr/heuristics';
import { OCR_ASSET_BASE } from '@/components/ocr/assetBase';
import BookDraftForm from './BookDraftForm';
import '@/components/ocr/OcrImportPanel.css';

const STAGE_KEY = {
  reading: 'catalogacao.ocr.stage.reading',
  opening: 'catalogacao.ocr.stage.opening',
  detecting: 'catalogacao.ocr.stage.detecting',
  'extracting-text': 'catalogacao.ocr.stage.extractingText',
  rasterizing: 'catalogacao.ocr.stage.rasterizing',
  ocr: 'catalogacao.ocr.stage.ocr',
};

function confidenceClass(c) {
  if (c >= 80) return 'ab-ocr__score--good';
  if (c >= 55) return 'ab-ocr__score--mid';
  return 'ab-ocr__score--low';
}

export default function OcrDepositTab({ batches = [], mode = 'simple', onSaved }) {
  const { formatMessage: t } = useIntl();
  const [phase, setPhase] = useState('idle'); // idle | working | review | draft
  const [stageLabel, setStageLabel] = useState('');
  const [progress, setProgress] = useState(0);
  const [result, setResult] = useState(null);
  const [draftRecord, setDraftRecord] = useState(null);
  const [pendingFile, setPendingFile] = useState(null);
  const [errorMsg, setErrorMsg] = useState('');
  const [fileName, setFileName] = useState('');
  const inputRef = useRef(null);

  const handleFile = useCallback(async (file) => {
    if (!file) return;
    if (file.type && file.type !== 'application/pdf' && !/\.pdf$/i.test(file.name)) {
      setPhase('idle');
      setErrorMsg(t({ id: 'catalogacao.ocr.onlyPdf' }));
      return;
    }
    setPhase('working');
    setErrorMsg('');
    setProgress(0);
    setFileName(file.name);
    setStageLabel(t({ id: 'catalogacao.ocr.stage.reading' }));

    const t0 = performance.now();
    try {
      const res = await processPdf(file, {
        lang: 'por',
        tessBase: OCR_ASSET_BASE,
        onStage: (stage, info) => {
          if (stage === 'ocr-page' && info?.total) {
            setStageLabel(t({ id: 'catalogacao.ocr.stage.ocrPage' }, { done: info.done, total: info.total }));
          } else if (STAGE_KEY[stage]) {
            setStageLabel(t({ id: STAGE_KEY[stage] }));
          }
        },
        onProgress: (m) => { if (typeof m?.progress === 'number') setProgress(m.progress); },
      });
      res.elapsedMs = Math.round(performance.now() - t0);
      const { fields } = extractFields(res.text, {
        numPages: res.numPages,
        lang: 'por',
        confidence: res.confidence,
      });
      setResult(res);
      setDraftRecord(fields);
      setPendingFile(file);
      setPhase('review');
    } catch (err) {
      console.error('[OcrDepositTab] erreur:', err);
      setPhase('idle');
      setErrorMsg(String(err?.message || err));
    }
  }, [t]);

  const onInputChange = useCallback((e) => handleFile(e.target.files?.[0]), [handleFile]);
  const onDrop = useCallback((e) => { e.preventDefault(); handleFile(e.dataTransfer.files?.[0]); }, [handleFile]);
  const onDragOver = useCallback((e) => { e.preventDefault(); }, []);

  const reset = useCallback(() => {
    setPhase('idle');
    setResult(null);
    setDraftRecord(null);
    setPendingFile(null);
    setErrorMsg('');
    setStageLabel('');
    setProgress(0);
    setFileName('');
    if (inputRef.current) inputRef.current.value = '';
  }, []);

  // ── Handoff : formulaire de brouillon pré-rempli ───────────────────────
  if (phase === 'draft' && draftRecord) {
    return (
      <div className="ab-ocr ab-ocr--embed">
        <div className="ab-ocr__meta">
          <span className="ab-ocr__detail">{t({ id: 'catalogacao.ocr.handoffIntro' })}</span>
          <button type="button" className="ab-ocr__btn" onClick={reset}>
            {t({ id: 'catalogacao.ocr.restart' })}
          </button>
        </div>
        <BookDraftForm
          batches={batches}
          mode={mode}
          onSaved={onSaved}
          prefillRecord={draftRecord}
          prefillFile={pendingFile}
        />
      </div>
    );
  }

  return (
    <div className="ab-ocr ab-ocr--embed">
      <header className="ab-ocr__head">
        <h1>{t({ id: 'catalogacao.ocr.title' })}</h1>
        <p className="ab-ocr__sub">{t({ id: 'catalogacao.ocr.intro' })}</p>
      </header>

      <div
        className={`ab-ocr__drop ${phase === 'working' ? 'ab-ocr__drop--busy' : ''}`}
        onDrop={onDrop}
        onDragOver={onDragOver}
        onClick={() => phase !== 'working' && inputRef.current?.click()}
        role="button"
        tabIndex={0}
      >
        <input ref={inputRef} type="file" accept="application/pdf,.pdf" onChange={onInputChange} hidden />
        {phase === 'working'
          ? <span>⏳ {fileName}</span>
          : <span>📄 {t({ id: 'catalogacao.ocr.dropHint' })}</span>}
      </div>

      {phase === 'idle' && (
        <p className="ab-ocr__hint">{t({ id: 'catalogacao.ocr.firstLoadNote' })}</p>
      )}

      {phase === 'working' && (
        <div className="ab-ocr__progress">
          <div className="ab-ocr__stage">{stageLabel}</div>
          {progress > 0 && (
            <div className="ab-ocr__bar">
              <div className="ab-ocr__bar-fill" style={{ width: `${Math.round(progress * 100)}%` }} />
            </div>
          )}
        </div>
      )}

      {errorMsg && (
        <div className="ab-ocr__error" role="alert">
          <strong>{t({ id: 'catalogacao.ocr.errorPrefix' })}</strong> {errorMsg}
          <button type="button" className="ab-ocr__btn" onClick={reset}>{t({ id: 'catalogacao.ocr.restart' })}</button>
        </div>
      )}

      {phase === 'review' && result && (
        <div className="ab-ocr__result">
          <div className="ab-ocr__meta">
            <span className={`ab-ocr__badge ${result.mode === 'born-digital' ? 'ab-ocr__badge--native' : 'ab-ocr__badge--ocr'}`}>
              {result.mode === 'born-digital'
                ? t({ id: 'catalogacao.ocr.badgeNative' })
                : t({ id: 'catalogacao.ocr.badgeOcr' })}
            </span>
            <span className={`ab-ocr__score ${confidenceClass(result.confidence)}`}>
              {t({ id: 'catalogacao.ocr.confidence' }, { value: result.confidence.toFixed(1) })}
            </span>
            <span className="ab-ocr__detail">{t({ id: 'catalogacao.ocr.pagesCount' }, { count: result.numPages })}</span>
            {result.pages && <span className="ab-ocr__detail">{t({ id: 'catalogacao.ocr.ocrPages' }, { pages: result.pages.join(', ') })}</span>}
          </div>

          {result.confidence < 70 && (
            <p className="ab-ocr__warn">{t({ id: 'catalogacao.ocr.lowConfidenceWarn' })}</p>
          )}

          <div className="ab-ocr__meta">
            <button type="button" className="ab-ocr__btn" onClick={() => setPhase('draft')} style={{ marginLeft: 0 }}>
              {t({ id: 'catalogacao.ocr.continueDraft' })}
            </button>
            <button type="button" className="ab-ocr__btn" onClick={reset}>
              {t({ id: 'catalogacao.ocr.restart' })}
            </button>
          </div>

          <details className="ab-ocr__diag">
            <summary>{t({ id: 'catalogacao.ocr.extractedText' })}</summary>
            <textarea className="ab-ocr__text" readOnly value={result.text || t({ id: 'catalogacao.ocr.noText' })} rows={14} />
          </details>
        </div>
      )}
    </div>
  );
}
