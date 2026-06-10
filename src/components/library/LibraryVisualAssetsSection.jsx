// ════════════════════════════════════════════════════════════════════════════
// Paquet 24c — LibraryVisualAssetsSection
// Path : src/components/library/LibraryVisualAssetsSection.jsx
//
// Module d'identité visuelle d'une bibliothèque.
// Permet à un·e coordenador·a d'uploader les 5 fichiers du thème dans
// `library-ui-assets/themes/{library_slug}/` :
//   - manifest.json (obligatoire, structure JSON)
//   - logo.png      (obligatoire, raster)
//   - favicon.png   (obligatoire, raster ≤ 256×256 conseillé)
//   - bg.webp       (recommandé, image de fond)
//   - logo.svg      (optionnel, version vectorielle)
//
// Comportement :
//   - À l'ouverture : appelle fn_ensure_library_theme(libraryId) pour
//     garantir une ligne library_themes ; charge la liste des fichiers
//     déjà présents dans le dossier ; affiche un aperçu de chacun.
//   - Pour chaque slot : input file + preview + bouton "Substituir"
//     (et "Remover" pour les optionnels).
//   - Upload via supabase.storage.upload avec upsert:true. Les RLS du
//     paquet 24c gèrent l'autorisation.
//   - Les URLs publiques sont reconstruites côté client (bucket public).
// ════════════════════════════════════════════════════════════════════════════

import { useState, useEffect, useCallback, useRef, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

const BUCKET = 'library-ui-assets';
const PROJECT_URL = 'https://uflwmikiyjfnikiphtcp.supabase.co';

// Slots canoniques. `optional:true` n'affiche pas d'alerte si manquant.
// `accept` aligne le picker fichier ; `kind` pilote la preview.
const SLOTS = [
  { key: 'manifest.json', accept: 'application/json,.json', kind: 'json',  optional: false },
  { key: 'logo.png',      accept: 'image/png',              kind: 'image', optional: false },
  { key: 'favicon.png',   accept: 'image/png',              kind: 'image', optional: false },
  { key: 'bg.webp',       accept: 'image/webp',             kind: 'image', optional: false },
  { key: 'logo.svg',      accept: 'image/svg+xml,.svg',     kind: 'image', optional: true  },
];

function publicUrl(slug, fileName, cacheBuster) {
  const u = `${PROJECT_URL}/storage/v1/object/public/${BUCKET}/themes/${slug}/${fileName}`;
  return cacheBuster ? `${u}?v=${cacheBuster}` : u;
}

export default function LibraryVisualAssetsSection({ libraryId, librarySlug, libraryName, canEdit }) {
  const { formatMessage: t } = useIntl();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState({});      // { 'logo.png': true, ... }
  const [present, setPresent] = useState({});    // { 'logo.png': { size, updatedAt } }
  const [cacheBust, setCacheBust] = useState(Date.now()); // re-render previews après upload
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [manifestText, setManifestText] = useState(null); // contenu JSON parsé/affiché
  const fileRefs = useRef({});

  // Charge la liste des fichiers déjà uploadés dans themes/{slug}/
  const reload = useCallback(async () => {
    if (!librarySlug) return;
    setLoading(true);
    try {
      const { data, error } = await supabase
        .storage
        .from(BUCKET)
        .list(`themes/${librarySlug}`, { limit: 100, sortBy: { column: 'name', order: 'asc' } });
      if (error) throw error;
      const map = {};
      for (const o of data || []) {
        map[o.name] = {
          size: o.metadata?.size ?? null,
          updatedAt: o.updated_at || o.created_at,
        };
      }
      setPresent(map);
      // Charger manifest.json si présent
      if (map['manifest.json']) {
        try {
          const r = await fetch(publicUrl(librarySlug, 'manifest.json', Date.now()));
          const text = await r.text();
          setManifestText(text);
        } catch {
          setManifestText(null);
        }
      } else {
        setManifestText(null);
      }
      setCacheBust(Date.now());
    } catch (err) {
      setMsg({ text: t({ id: 'biblioteca.visualAssets.error.load' }, { msg: localizeError(err, t) }), kind: 'error' });
    } finally {
      setLoading(false);
    }
  }, [librarySlug, t]);

  // Au mount : s'assurer qu'une ligne library_themes existe (idempotent), puis charger.
  useEffect(() => {
    if (!libraryId || !librarySlug) return;
    let cancelled = false;
    (async () => {
      if (canEdit) {
        try {
          await supabase.rpc('fn_ensure_library_theme', { p_library_id: libraryId });
        } catch {
          // pas bloquant en lecture
        }
      }
      if (!cancelled) await reload();
    })();
    return () => { cancelled = true; };
  }, [libraryId, librarySlug, canEdit, reload]);

  async function handleUpload(slotKey, file) {
    if (!file || !canEdit || !librarySlug) return;
    setSaving(s => ({ ...s, [slotKey]: true }));
    setMsg({ text: '', kind: '' });
    try {
      // Validation minimale côté client pour manifest.json
      if (slotKey === 'manifest.json') {
        const text = await file.text();
        try { JSON.parse(text); }
        catch {
          throw new Error(t({ id: 'biblioteca.visualAssets.error.invalidJson' }));
        }
      }
      const path = `themes/${librarySlug}/${slotKey}`;
      const { error } = await supabase
        .storage
        .from(BUCKET)
        .upload(path, file, {
          upsert: true,
          cacheControl: '3600',
          contentType: file.type || undefined,
        });
      if (error) throw error;
      // #PN-2 : un manifeste vient d'etre depose -> marquer la biblio comme thematisee
      // (LibraryContext resoudra alors themeSlug = slug, et non 'default'). Non bloquant.
      if (slotKey === 'manifest.json' && libraryId) {
        try {
          await supabase.schema('api').rpc('fn_set_library_theme_active', { p_library_id: libraryId, p_active: true });
        } catch (e) {
          console.warn('[AnarBib] fn_set_library_theme_active(true) failed:', e);
        }
      }
      setMsg({ text: t({ id: 'biblioteca.visualAssets.success.uploaded' }, { name: slotKey }), kind: 'ok' });
      await reload();
    } catch (err) {
      setMsg({ text: t({ id: 'biblioteca.visualAssets.error.upload' }, { name: slotKey, msg: localizeError(err, t) }), kind: 'error' });
    } finally {
      setSaving(s => ({ ...s, [slotKey]: false }));
      if (fileRefs.current[slotKey]) fileRefs.current[slotKey].value = '';
    }
  }

  async function handleRemove(slotKey) {
    if (!canEdit || !librarySlug) return;
    if (!window.confirm(t({ id: 'biblioteca.visualAssets.confirm.remove' }, { name: slotKey }))) return;
    setSaving(s => ({ ...s, [slotKey]: true }));
    setMsg({ text: '', kind: '' });
    try {
      const path = `themes/${librarySlug}/${slotKey}`;
      const { error } = await supabase.storage.from(BUCKET).remove([path]);
      if (error) throw error;
      // #PN-2 : manifeste supprime -> la biblio repasse au theme par defaut. Non bloquant.
      if (slotKey === 'manifest.json' && libraryId) {
        try {
          await supabase.schema('api').rpc('fn_set_library_theme_active', { p_library_id: libraryId, p_active: false });
        } catch (e) {
          console.warn('[AnarBib] fn_set_library_theme_active(false) failed:', e);
        }
      }
      setMsg({ text: t({ id: 'biblioteca.visualAssets.success.removed' }, { name: slotKey }), kind: 'ok' });
      await reload();
    } catch (err) {
      setMsg({ text: t({ id: 'biblioteca.visualAssets.error.remove' }, { name: slotKey, msg: localizeError(err, t) }), kind: 'error' });
    } finally {
      setSaving(s => ({ ...s, [slotKey]: false }));
    }
  }

  // Générateur de manifest minimal pour aider à démarrer
  const generateManifestTemplate = useCallback(() => {
    const template = {
      slug: librarySlug,
      name: libraryName || librarySlug,
      assets: {
        logo:    `themes/${librarySlug}/logo.png`,
        favicon: `themes/${librarySlug}/favicon.png`,
        bg:      `themes/${librarySlug}/bg.webp`,
        logoSvg: `themes/${librarySlug}/logo.svg`,
      },
      palette: {
        // Palette indicative — ajuster selon l'identité du collectif.
        // Les clés correspondent aux CSS vars utilisées par l'app.
        brandBg:     '#0f1011',
        brandFg:     '#f4f4f4',
        brandAccent: '#d97706',
        brandMuted:  '#9ca3af',
      },
      fonts: {
        body:   'system-ui, -apple-system, sans-serif',
        accent: 'serif',
      },
      generated_at: new Date().toISOString(),
    };
    return JSON.stringify(template, null, 2);
  }, [librarySlug, libraryName]);

  function handleDownloadTemplate() {
    const blob = new Blob([generateManifestTemplate()], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'manifest.json';
    a.click();
    URL.revokeObjectURL(url);
  }

  const fs = { width: '100%', padding: '8px 10px', borderRadius: 8, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' };
  const bx = { padding: 12, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)', marginTop: 16 };

  if (!librarySlug) {
    return (
      <div style={{ ...bx, color: 'var(--brand-muted)', fontStyle: 'italic' }}>
        {t({ id: 'biblioteca.visualAssets.noSlug' })}
      </div>
    );
  }

  return (
    <div style={bx}>
      <h4 style={{ margin: '0 0 4px' }}>{t({ id: 'biblioteca.visualAssets.title' })}</h4>
      <p style={{ fontSize: '.82rem', color: 'var(--brand-muted)', margin: '0 0 12px', lineHeight: 1.5 }}>
        {t({ id: 'biblioteca.visualAssets.helper' })}
      </p>
      <p style={{ fontSize: '.78rem', color: 'var(--brand-muted)', margin: '0 0 14px', lineHeight: 1.5, fontStyle: 'italic' }}>
        {t({ id: 'biblioteca.visualAssets.path' }, { path: `themes/${librarySlug}/` })}
      </p>

      {msg.text && (
        <div style={{
          padding: '8px 12px', borderRadius: 8, fontSize: '.82rem', marginBottom: 12,
          background: msg.kind === 'ok' ? 'rgba(21,128,61,.12)' : 'rgba(220,38,38,.12)',
          color:      msg.kind === 'ok' ? '#4ade80' : '#f87171',
          border:    `1px solid ${msg.kind === 'ok' ? 'rgba(21,128,61,.25)' : 'rgba(220,38,38,.25)'}`,
        }}>{msg.text}</div>
      )}

      {loading && <p style={{ fontSize: '.85rem', color: 'var(--brand-muted)' }}>{t({ id: 'common.loading' })}</p>}

      {!loading && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: 12 }}>
          {SLOTS.map(slot => {
            const exists = !!present[slot.key];
            const isSaving = !!saving[slot.key];
            const sizeKb = exists && present[slot.key].size ? Math.round(present[slot.key].size / 1024) : null;
            return (
              <div key={slot.key} style={{
                padding: 10, borderRadius: 8,
                background: 'rgba(0,0,0,.25)',
                border: `1px solid ${exists ? 'rgba(74,222,128,.2)' : (slot.optional ? 'rgba(255,255,255,.08)' : 'rgba(248,113,113,.2)')}`,
              }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 6 }}>
                  <strong style={{ fontSize: '.85rem', fontFamily: 'monospace' }}>{slot.key}</strong>
                  {slot.optional && (
                    <span style={{ fontSize: '.7rem', color: 'var(--brand-muted)' }}>
                      {t({ id: 'biblioteca.visualAssets.optional' })}
                    </span>
                  )}
                </div>

                {/* Preview */}
                <div style={{
                  height: 90, display: 'flex', alignItems: 'center', justifyContent: 'center',
                  borderRadius: 6, background: 'rgba(255,255,255,.02)', marginBottom: 8, overflow: 'hidden',
                }}>
                  {exists ? (
                    slot.kind === 'image' ? (
                      <img
                        src={publicUrl(librarySlug, slot.key, cacheBust)}
                        alt={slot.key}
                        style={{ maxHeight: '100%', maxWidth: '100%', objectFit: 'contain' }}
                      />
                    ) : (
                      <span style={{ fontSize: '.72rem', color: '#4ade80', fontFamily: 'monospace' }}>
                        ✓ JSON {sizeKb !== null ? `· ${sizeKb} KB` : ''}
                      </span>
                    )
                  ) : (
                    <span style={{ fontSize: '.78rem', color: slot.optional ? 'var(--brand-muted)' : '#f87171' }}>
                      {slot.optional ? t({ id: 'biblioteca.visualAssets.empty.optional' }) : t({ id: 'biblioteca.visualAssets.empty.required' })}
                    </span>
                  )}
                </div>

                {exists && sizeKb !== null && slot.kind === 'image' && (
                  <p style={{ fontSize: '.7rem', color: 'var(--brand-muted)', margin: '0 0 6px' }}>
                    {sizeKb} KB
                  </p>
                )}

                {canEdit && (
                  <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                    <label style={{
                      flex: 1, cursor: isSaving ? 'wait' : 'pointer',
                      padding: '6px 8px', borderRadius: 6, fontSize: '.78rem',
                      background: 'rgba(29,78,216,.15)', border: '1px solid rgba(29,78,216,.3)',
                      color: '#93c5fd', textAlign: 'center',
                      opacity: isSaving ? 0.6 : 1,
                    }}>
                      {isSaving
                        ? t({ id: 'biblioteca.visualAssets.uploading' })
                        : exists
                          ? t({ id: 'biblioteca.visualAssets.replace' })
                          : t({ id: 'biblioteca.visualAssets.upload' })}
                      <input
                        ref={el => { fileRefs.current[slot.key] = el; }}
                        type="file"
                        accept={slot.accept}
                        disabled={isSaving}
                        onChange={e => {
                          const f = e.target.files?.[0];
                          if (f) handleUpload(slot.key, f);
                        }}
                        style={{ display: 'none' }}
                      />
                    </label>
                    {exists && slot.optional && (
                      <button
                        onClick={() => handleRemove(slot.key)}
                        disabled={isSaving}
                        style={{
                          padding: '6px 8px', borderRadius: 6, fontSize: '.78rem',
                          background: 'rgba(220,38,38,.1)', border: '1px solid rgba(220,38,38,.25)',
                          color: '#f87171', cursor: 'pointer',
                        }}
                      >
                        {t({ id: 'biblioteca.visualAssets.remove' })}
                      </button>
                    )}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}

      {/* Manifest template helper */}
      {canEdit && (
        <div style={{
          marginTop: 14, padding: 10, borderRadius: 8,
          background: 'rgba(29,78,216,.06)', border: '1px solid rgba(29,78,216,.15)',
        }}>
          <p style={{ fontSize: '.8rem', color: 'var(--brand-muted, #ccc)', margin: '0 0 8px', lineHeight: 1.5 }}>
            {t({ id: 'biblioteca.visualAssets.manifestHelp' })}
          </p>
          <button
            onClick={handleDownloadTemplate}
            style={{
              padding: '6px 10px', borderRadius: 6, fontSize: '.8rem',
              background: 'rgba(29,78,216,.15)', border: '1px solid rgba(29,78,216,.3)',
              color: '#93c5fd', cursor: 'pointer',
            }}
          >
            {t({ id: 'biblioteca.visualAssets.downloadTemplate' })}
          </button>
        </div>
      )}

      {/* Manifest preview */}
      {manifestText && (
        <details style={{ marginTop: 12 }}>
          <summary style={{ cursor: 'pointer', fontSize: '.82rem', color: 'var(--brand-muted)' }}>
            {t({ id: 'biblioteca.visualAssets.showManifest' })}
          </summary>
          <pre style={{
            marginTop: 8, padding: 10, borderRadius: 6,
            background: 'rgba(0,0,0,.4)', fontSize: '.72rem',
            overflow: 'auto', maxHeight: 240, color: '#cbd5e1',
          }}>{manifestText}</pre>
        </details>
      )}
    </div>
  );
}
