/**
 * OcrImportPanel.jsx — POC P1 « dépose un PDF scanné → texte + confiance »
 *
 * Cadrage : docs/journal/cadrages/CADRAGE_ocr_import_navigateur_2026-06-17.md
 * Session : OCR import navigateur (piste B)
 *
 * P1 = PREUVE DE CONCEPT. Contrat :
 *   - OCR 100 % navigateur (tesseract.js WASM self-host) ; born-digital → texte
 *     natif sans OCR (pdf.js getTextContent).
 *   - AUCUNE écriture base. On affiche le texte extrait + le score de confiance.
 *
 * ⚠️ i18n : ce panneau est volontairement EN FRANÇAIS EN DUR. C'est un écran de
 *    dev (/dev/ocr), pas un circuit du wizard d'import. La traduction dans les
 *    10 locales (charte + parité CI) arrive en P2, quand l'OCR rejoint le vrai
 *    wizard (cadrage §4, §8). Ne pas câbler react-intl ici pour un POC jetable.
 */

import { useCallback, useRef, useState } from 'react';
import { processPdf } from './ocrPipeline';
import { extractFields, MATERIAL_TYPES } from './heuristics';
import { OCR_ASSET_BASE } from './assetBase';
import './OcrImportPanel.css';

// Champs du brouillon affichés dans le formulaire pré-rempli (P2).
// `key` = nom de champ book_drafts réel (cf. EMPTY_FORM). type 'select' → enum.
const DRAFT_FIELDS = [
  { key: 'titulo', label: 'Titre', wide: true },
  { key: 'tipo_material', label: 'Type de matériel', type: 'select', options: MATERIAL_TYPES },
  { key: 'ano', label: 'Année' },
  { key: 'data_edicao', label: 'Date d’édition' },
  { key: 'numero', label: 'Numéro' },
  { key: 'volume', label: 'Volume / ano' },
  { key: 'isbn', label: 'ISBN' },
  { key: 'issn', label: 'ISSN' },
  { key: 'emitter_org', label: 'Organisation émettrice' },
  { key: 'idioma', label: 'Langue' },
  { key: 'paginas', label: 'Pages' },
];

// Libellés d'étape (FR, dev only — cf. en-tête)
const STAGE_LABELS = {
  reading: 'Lecture du fichier…',
  opening: 'Ouverture du PDF…',
  detecting: 'Détection texte natif / scan…',
  'extracting-text': 'Extraction du texte natif…',
  rasterizing: 'Rastérisation des pages clés…',
  ocr: 'OCR en cours…',
  'ocr-page': 'OCR en cours…',
};

function confidenceClass(c) {
  if (c >= 80) return 'ab-ocr__score--good';
  if (c >= 55) return 'ab-ocr__score--mid';
  return 'ab-ocr__score--low';
}

export default function OcrImportPanel() {
  const [status, setStatus] = useState('idle'); // idle | working | done | error
  const [stageLabel, setStageLabel] = useState('');
  const [progress, setProgress] = useState(0); // 0..1, OCR uniquement
  const [result, setResult] = useState(null);
  const [draft, setDraft] = useState(null);      // champs pré-remplis éditables (P2)
  const [draftMeta, setDraftMeta] = useState(null); // sources + drapeaux « à vérifier »
  const [errorMsg, setErrorMsg] = useState('');
  const [fileName, setFileName] = useState('');
  const inputRef = useRef(null);

  const handleFile = useCallback(async (file) => {
    if (!file) return;
    if (file.type && file.type !== 'application/pdf' && !/\.pdf$/i.test(file.name)) {
      setStatus('error');
      setErrorMsg('Ce POC n’accepte que des fichiers PDF.');
      return;
    }
    setStatus('working');
    setResult(null);
    setErrorMsg('');
    setProgress(0);
    setFileName(file.name);
    setStageLabel(STAGE_LABELS.reading);

    const t0 = performance.now();
    try {
      const res = await processPdf(file, {
        lang: 'por',
        tessBase: OCR_ASSET_BASE,
        onStage: (stage, info) => {
          setStageLabel(STAGE_LABELS[stage] || stage);
          if (stage === 'ocr-page' && info?.total) {
            setStageLabel(`OCR page ${info.done}/${info.total}…`);
          }
        },
        onProgress: (m) => {
          // logger tesseract : { status, progress: 0..1 }
          if (typeof m?.progress === 'number') setProgress(m.progress);
        },
      });
      res.elapsedMs = Math.round(performance.now() - t0);
      setResult(res);
      // P2 — pré-remplissage heuristique (regex, zéro LLM). Éditable.
      const { fields, meta } = extractFields(res.text, {
        numPages: res.numPages,
        lang: 'por',
        confidence: res.confidence,
      });
      setDraft(fields);
      setDraftMeta(meta);
      setStatus('done');
    } catch (err) {
      console.error('[OcrImportPanel] erreur:', err);
      setStatus('error');
      setErrorMsg(String(err?.message || err));
    }
  }, []);

  const onInputChange = useCallback((e) => {
    handleFile(e.target.files?.[0]);
  }, [handleFile]);

  const onDrop = useCallback((e) => {
    e.preventDefault();
    handleFile(e.dataTransfer.files?.[0]);
  }, [handleFile]);

  const onDragOver = useCallback((e) => { e.preventDefault(); }, []);

  const reset = useCallback(() => {
    setStatus('idle');
    setResult(null);
    setDraft(null);
    setDraftMeta(null);
    setErrorMsg('');
    setStageLabel('');
    setProgress(0);
    setFileName('');
    if (inputRef.current) inputRef.current.value = '';
  }, []);

  const onField = useCallback((key, value) => {
    setDraft((d) => ({ ...d, [key]: value }));
  }, []);

  return (
    <div className="ab-ocr">
      <header className="ab-ocr__head">
        <h1>OCR navigateur — POC (P1)</h1>
        <p className="ab-ocr__sub">
          Dépose un PDF scanné. S’il a déjà une couche texte (<em>born-digital</em>),
          on la prend telle quelle ; sinon on rastérise les pages clés et on les
          OCRise avec tesseract.js (langue <code>por</code>) — 100 % dans le
          navigateur, rien ne sort. <strong>Aucune écriture en base.</strong>
        </p>
      </header>

      {/* Zone de dépôt */}
      <div
        className={`ab-ocr__drop ${status === 'working' ? 'ab-ocr__drop--busy' : ''}`}
        onDrop={onDrop}
        onDragOver={onDragOver}
        onClick={() => inputRef.current?.click()}
        role="button"
        tabIndex={0}
      >
        <input
          ref={inputRef}
          type="file"
          accept="application/pdf,.pdf"
          onChange={onInputChange}
          hidden
        />
        {status === 'working'
          ? <span>⏳ {fileName}</span>
          : <span>📄 Glisse un PDF ici, ou clique pour choisir un fichier</span>}
      </div>

      {/* Progression */}
      {status === 'working' && (
        <div className="ab-ocr__progress">
          <div className="ab-ocr__stage">{stageLabel}</div>
          {progress > 0 && (
            <div className="ab-ocr__bar">
              <div className="ab-ocr__bar-fill" style={{ width: `${Math.round(progress * 100)}%` }} />
            </div>
          )}
        </div>
      )}

      {/* Erreur */}
      {status === 'error' && (
        <div className="ab-ocr__error" role="alert">
          <strong>Erreur :</strong> {errorMsg}
          <button type="button" className="ab-ocr__btn" onClick={reset}>Recommencer</button>
        </div>
      )}

      {/* Résultat */}
      {status === 'done' && result && (
        <div className="ab-ocr__result">
          <div className="ab-ocr__meta">
            <span className={`ab-ocr__badge ${result.mode === 'born-digital' ? 'ab-ocr__badge--native' : 'ab-ocr__badge--ocr'}`}>
              {result.mode === 'born-digital' ? '🅣 Texte natif (pas d’OCR)' : '🅞 OCR tesseract'}
            </span>
            <span className={`ab-ocr__score ${confidenceClass(result.confidence)}`}>
              Confiance : {result.confidence.toFixed(1)} %
            </span>
            <span className="ab-ocr__detail">{result.numPages} page(s)</span>
            {result.pages && <span className="ab-ocr__detail">Pages OCRisées : {result.pages.join(', ')}</span>}
            <span className="ab-ocr__detail">⏱ {result.elapsedMs} ms</span>
            <button type="button" className="ab-ocr__btn" onClick={reset}>Nouveau</button>
          </div>

          {/* P2 — Brouillon pré-rempli (heuristique, éditable, ZÉRO base) */}
          {draft && (
            <fieldset className="ab-ocr__form">
              <legend>
                Brouillon pré-rempli <span className="ab-ocr__form-note">(heuristique regex — éditable, rien n’est enregistré)</span>
              </legend>
              {draftMeta?.lowConfidence && (
                <p className="ab-ocr__warn">
                  ⚠ Confiance OCR faible — tous les champs sont marqués « à vérifier ».
                </p>
              )}
              <div className="ab-ocr__grid">
                {DRAFT_FIELDS.map((fld) => {
                  const flagged = draftMeta?.flagged?.[fld.key];
                  return (
                    <div
                      key={fld.key}
                      className={`ab-ocr__field ${fld.wide ? 'ab-ocr__field--wide' : ''}`}
                    >
                      <label htmlFor={`ab-ocr-f-${fld.key}`}>
                        {fld.label}
                        {flagged && <span className="ab-ocr__flag" title="à vérifier"> ⚠</span>}
                      </label>
                      {fld.type === 'select' ? (
                        <select
                          id={`ab-ocr-f-${fld.key}`}
                          value={draft[fld.key] || ''}
                          onChange={(e) => onField(fld.key, e.target.value)}
                        >
                          {fld.options.map((o) => <option key={o} value={o}>{o}</option>)}
                        </select>
                      ) : (
                        <input
                          id={`ab-ocr-f-${fld.key}`}
                          type="text"
                          value={draft[fld.key] || ''}
                          onChange={(e) => onField(fld.key, e.target.value)}
                        />
                      )}
                    </div>
                  );
                })}
              </div>
              {draftMeta?.orgsFound?.length > 1 && (
                <p className="ab-ocr__hint">Autres sigles repérés : {draftMeta.orgsFound.join(', ')}</p>
              )}
              {draftMeta?.yearsFound?.length > 1 && (
                <p className="ab-ocr__hint">Autres années repérées : {draftMeta.yearsFound.join(', ')}</p>
              )}
            </fieldset>
          )}

          {/* Détail détection (transparence du POC) */}
          <details className="ab-ocr__diag">
            <summary>Diagnostic born-digital + heuristiques</summary>
            <pre>{JSON.stringify({ detection: result.detection, sources: draftMeta?.sources }, null, 2)}</pre>
          </details>

          <label className="ab-ocr__label" htmlFor="ab-ocr-text">Texte extrait</label>
          <textarea
            id="ab-ocr-text"
            className="ab-ocr__text"
            readOnly
            value={result.text || '(aucun texte extrait)'}
            rows={18}
          />
        </div>
      )}
    </div>
  );
}
