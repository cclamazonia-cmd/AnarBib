// src/pages/catalogacao/DigitalResourcesPanel.jsx — E6, lot 2 (28/09/2026)
// Le panneau « Recursos digitais vinculados » du formulaire de notice, sorti de
// BookDraftForm.jsx sans en changer une ligne de logique : liste des ressources
// numériques d'un brouillon, formulaire d'édition, téléversement dans le bon
// seau (le seau porte la restriction, pas le libellé — correctif du 21/08),
// enregistrement, suppression. Le parent garde la LISTE et son chargement
// (la couverture tirée du PDF la lit) ; ce panneau lui dit quand la recharger.
import { useState, useEffect } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

export default function DigitalResourcesPanel({ draftId, resources, onChanged, setMsg }) {
  const { formatMessage: t } = useIntl();
  const [digitalForm, setDigitalForm] = useState(null); // resource being edited
  const [digitalSaving, setDigitalSaving] = useState(false);
  const [digitalUploading, setDigitalUploading] = useState(false);
  // Le brouillon change (fiche vierge, autre brouillon chargé) : l'édition en
  // cours ne le concerne plus, elle se referme. Avant l'extraction, seule la
  // fiche vierge le faisait (resetForm) ; une ressource en cours d'édition
  // aurait été enregistrée sur le brouillon chargé ensuite.
  useEffect(() => { setDigitalForm(null); }, [draftId]);

  const RESOURCE_TYPES = [
    { value: 'pdf_publico', label: t({id:'catalogacao.digital.pdf'}) },
    { value: 'pdf_restrito', label: t({ id: 'catalogacao.digital.typePdf' }) },
    { value: 'audio', label: t({id:'catalogacao.digital.audio'}) },
    { value: 'video', label: t({id:'catalogacao.digital.video'}) },
    { value: 'image', label: t({ id: 'catalogacao.digital.typeImage' }) },
    { value: 'link_externo', label: t({ id: 'catalogacao.digital.typeLink' }) },
  ];

  const USAGE_TYPES = [
    { value: 'leitura_online', label: t({ id: 'catalogacao.digital.usageReadOnline' }) },
    { value: 'download', label: t({ id: 'catalogacao.digital.usageDownload' }) },
    { value: 'escuta_online', label: t({ id: 'catalogacao.digital.usageListenOnline' }) },
    { value: 'visualizacao_online', label: t({id:'catalogacao.digital.online'}) },
    { value: 'link_externo', label: t({ id: 'catalogacao.digital.typeLink' }) },
  ];

  const ACCESS_SCOPES = [
    { value: 'publico', label: t({id:'catalogacao.digital.public'}) },
    { value: 'conta_ativa', label: t({ id: 'catalogacao.digital.accessActiveAccount' }) },
  ];

  const EMPTY_DIGITAL = {
    id: '', resource_type: 'pdf_publico', usage_type: 'leitura_online',
    access_scope: 'publico', storage_bucket: '', storage_path: '',
    mime_type: 'application/pdf', language_code: '', source_name: '',
    source_url: '', attribution_text: '', rights_status: '', rights_justification: '',
    is_primary: false, bibliographic_match_validated: false,
    label: '', notes: '',
  };

  function startNewDigitalResource() {
    setDigitalForm({ ...EMPTY_DIGITAL });
  }

  function editDigitalResource(resource) {
    setDigitalForm({
      id: String(resource.id || ''),
      resource_type: resource.resource_type || 'pdf_publico',
      usage_type: resource.usage_type || 'leitura_online',
      access_scope: resource.access_scope || 'publico',
      storage_bucket: resource.storage_bucket || '',
      storage_path: resource.storage_path || '',
      mime_type: resource.mime_type || 'application/pdf',
      language_code: resource.language_code || '',
      source_name: resource.source_name || '',
      source_url: resource.source_url || '',
      attribution_text: resource.attribution_text || '',
      rights_status: resource.rights_status || '',
      rights_justification: resource.rights_justification || '',
      is_primary: !!resource.is_primary,
      bibliographic_match_validated: !!resource.bibliographic_match_validated,
      label: resource.label || '',
      notes: resource.notes || '',
    });
  }

  function setDf(key, value) {
    setDigitalForm(prev => prev ? { ...prev, [key]: value } : prev);
  }

  async function saveDigitalResource() {
    if (!draftId) { setMsg({ text: t({ id: 'catalogacao.msg.saveBeforeDigital' }), kind: 'error' }); return; }
    if (!digitalForm) return;
    if (!digitalForm.storage_path && !digitalForm.source_url) {
      setMsg({ text: t({ id: 'catalogacao.msg.needPathOrUrl' }), kind: 'error' });
      return;
    }

    setDigitalSaving(true);
    try {
      const payload = {
        book_draft_id: Number(draftId),
        resource_type: digitalForm.resource_type,
        usage_type: digitalForm.usage_type,
        access_scope: digitalForm.access_scope,
        status: 'draft',
        is_active: true,
        storage_bucket: digitalForm.storage_bucket || null,
        storage_path: digitalForm.storage_path || null,
        mime_type: digitalForm.mime_type || 'application/pdf',
        language_code: digitalForm.language_code || null,
        source_name: digitalForm.source_name || null,
        source_url: digitalForm.source_url || null,
        attribution_text: digitalForm.attribution_text || null,
        rights_status: digitalForm.rights_status || null,
        rights_justification: digitalForm.rights_justification || null,
        is_primary: digitalForm.is_primary,
        bibliographic_match_validated: digitalForm.bibliographic_match_validated,
        label: digitalForm.label || digitalForm.source_name || 'Recurso digital',
        notes: digitalForm.notes || null,
      };

      // GARDE-FOU : le seau doit correspondre à la portée d'accès. Sans lui,
      // une fiche peut déclarer « restreint » tout en pointant un fichier
      // public — ou pointer un seau où le fichier n'a jamais été versé. Les
      // deux sont arrivés sur le livre 1434. Mieux vaut refuser d'enregistrer
      // que produire une fiche qui ment sur la protection du document.
      const seauAttendu = DIGITAL_BUCKET_FOR(payload.mime_type, payload.access_scope);
      if (payload.storage_bucket && seauAttendu && payload.storage_bucket !== seauAttendu) {
        throw new Error(t(
          { id: 'catalogacao.digital.bucketScopeMismatch' },
          { expected: seauAttendu, actual: payload.storage_bucket },
        ));
      }

      if (digitalForm.id) {
        const { error } = await supabase.from('book_draft_digital_resources')
          .update(payload).eq('id', Number(digitalForm.id));
        if (error) throw error;
      } else {
        const { error } = await supabase.from('book_draft_digital_resources')
          .insert(payload);
        if (error) throw error;
      }

      setDigitalForm(null);
      await onChanged();
      setMsg({ text: t({ id: 'catalogacao.msg.digitalSaved' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.msg.digitalError' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setDigitalSaving(false);
    }
  }

  // CORRECTIF 21/08/2026 — LA RESTRICTION EST PORTÉE PAR LE SEAU, PAS PAR LE
  // LIBELLÉ. Le seau était choisi d'après le seul type MIME, donc TOUJOURS le
  // seau public pour un PDF, quelle que soit la portée d'accès demandée.
  // Vécu sur le livre 1434 : la fiche déclarait « restreint » et `pdf-restrito`
  // (champ corrigé à la main), le fichier était resté dans `anarbib-pdf-public`.
  // Double conséquence : lecture en ligne impossible — le fichier n'est pas là
  // où la fiche le cherche — ET PDF téléchargeable par quiconque connaît l'URL,
  // alors qu'il est catalogué restreint.
  const DIGITAL_BUCKET_FOR = (mime, scope) => {
    const restreint = scope === 'conta_ativa';
    if (mime === 'application/pdf') return restreint ? 'pdf-restrito' : 'anarbib-pdf-public';
    if (/^(image|audio|video)\//.test(mime || '')) return restreint ? 'anarbib-media-restricted' : 'anarbib-media-public';
    return null;
  };
  const DIGITAL_RTYPE_BY_MIME = (mime, scope) => {
    if (mime === 'application/pdf') return scope === 'conta_ativa' ? 'pdf_restrito' : 'pdf_publico';
    if ((mime || '').startsWith('image/')) return 'image';
    if ((mime || '').startsWith('audio/')) return 'audio';
    if ((mime || '').startsWith('video/')) return 'video';
    return 'link_externo';
  };

  // Outil d'import simplifié : téléverse le fichier dans le bon bucket public
  // selon son type, et remplit automatiquement bucket/chemin/mime/type.
  async function uploadDigitalFile(file) {
    if (!draftId) { setMsg({ text: t({ id: 'catalogacao.msg.saveBeforeDigital' }), kind: 'error' }); return; }
    if (!file) return;
    const mime = file.type || '';
    // La portée d'accès choisie AVANT le téléversement décide du seau. Si elle
    // change ensuite, le garde-fou de l'enregistrement refuse la fiche et
    // demande de reverser le fichier — c'est le seul moyen sûr : déplacer un
    // objet entre seaux depuis le navigateur n'est pas possible.
    const scope = (digitalForm && digitalForm.access_scope) || 'publico';
    const bucket = DIGITAL_BUCKET_FOR(mime, scope);
    if (!bucket) { setMsg({ text: t({ id: 'catalogacao.digital.unsupportedType' }), kind: 'error' }); return; }
    if (file.size > 100 * 1024 * 1024) { setMsg({ text: t({ id: 'catalogacao.digital.fileTooLarge' }), kind: 'error' }); return; }
    setDigitalUploading(true);
    try {
      const safe = file.name.normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-zA-Z0-9._-]/g, '_');
      const path = `books/${draftId}/${Date.now()}_${safe}`;
      const { error } = await supabase.storage.from(bucket).upload(path, file, { upsert: false, contentType: mime });
      if (error) throw error;
      setDigitalForm(prev => ({
        ...(prev || {}),
        storage_bucket: bucket,
        storage_path: path,
        mime_type: mime,
        resource_type: DIGITAL_RTYPE_BY_MIME(mime, scope),
        label: (prev && prev.label) || file.name,
      }));
      setMsg({ text: t({ id: 'catalogacao.digital.uploaded' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.msg.digitalError' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setDigitalUploading(false);
    }
  }

  async function deleteDigitalResource(resourceId) {
    if (!confirm(t({id:'catalogacao.digital.confirmDelete'}))) return;
    try {
      const { error } = await supabase.from('book_draft_digital_resources')
        .delete().eq('id', Number(resourceId));
      if (error) throw error;
      await onChanged();
      setMsg({ text: t({ id: 'catalogacao.msg.digitalDeleted' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    }
  }

  if (!draftId) return null;
  return (
    <div className="cat-material-section" style={{ gridColumn: 'span 3' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10, flexWrap: 'wrap', gap: 6 }}>
        <h4 style={{ margin: 0 }}>{t({ id: 'catalogacao.digital.sectionTitle' })}</h4>
        <button type="button" className="ab-button ab-button--secondary ab-button--sm"
          onClick={startNewDigitalResource}>
          {t({ id: 'catalogacao.digital.newResource' })}
        </button>
      </div>

      {/* Existing resources list */}
      {resources.length > 0 && (
        <div style={{ marginBottom: 12 }}>
          {resources.map(res => (
            <div key={res.id} style={{
              display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8, flexWrap: 'wrap',
              padding: '8px 10px', borderRadius: 6, marginBottom: 4,
              background: 'rgba(0,0,0,.15)', border: '1px solid rgba(255,255,255,.06)',
            }}>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: '.82rem', fontWeight: 600 }}>
                  {res.label || res.source_name || t({ id: 'catalogacao.digital.defaultLabel' })}
                  {res.is_primary && <span className="cat-pill ok" style={{ marginLeft: 6, fontSize: '.65rem' }}>{t({ id: 'catalogacao.ui.primary' })}</span>}
                </div>
                <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #aaa)' }}>
                  {RESOURCE_TYPES.find(t => t.value === res.resource_type)?.label || res.resource_type}
                  {' · '}{ACCESS_SCOPES.find(s => s.value === res.access_scope)?.label || res.access_scope}
                  {res.storage_path && ` · ${res.storage_path}`}
                  {res.source_url && !res.storage_path && ` · ${res.source_url}`}
                </div>
              </div>
              <div style={{ display: 'flex', gap: 4, flexShrink: 0 }}>
                <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                  onClick={() => editDigitalResource(res)}>{t({ id: 'common.edit' })}</button>
                <button type="button" className="ab-button ab-button--danger ab-button--sm"
                  onClick={() => deleteDigitalResource(res.id)}>{t({ id: 'common.delete' })}</button>
              </div>
            </div>
          ))}
        </div>
      )}

      {resources.length === 0 && !digitalForm && (
        <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #888)', padding: '8px 0' }}>
          {t({ id: 'catalogacao.digital.empty' })}
        </div>
      )}

      {/* Digital resource edit form */}
      {digitalForm && (
        <div style={{ padding: 14, borderRadius: 8, background: 'rgba(0,0,0,.2)', border: '1px solid rgba(255,255,255,.1)' }}>
          <h4 style={{ margin: '0 0 10px', fontSize: '.85rem' }}>
            {digitalForm.id ? t({ id: 'catalogacao.digital.editTitle' }) : t({ id: 'catalogacao.digital.newTitle' })}
          </h4>
          {/* Outil d'import simplifié — téléverser directement le fichier (auto-remplit bucket/chemin/mime) */}
          <div style={{ marginBottom: 12, padding: 10, borderRadius: 6, background: 'rgba(90,160,255,.08)', border: '1px dashed rgba(120,180,255,.35)' }}>
            <label style={{ display: 'block', fontSize: '.8rem', fontWeight: 600, marginBottom: 5 }}>
              {t({ id: 'catalogacao.digital.uploadFile' })}
            </label>
            <input type="file" accept="application/pdf,image/*,audio/*,video/*"
              disabled={digitalUploading}
              onChange={e => { const file = e.target.files && e.target.files[0]; if (file) uploadDigitalFile(file); e.target.value = ''; }}
              style={{ fontSize: '.8rem', color: '#f4f4f4' }} />
            <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #9ab)', marginTop: 5 }}>
              {digitalUploading ? t({ id: 'catalogacao.digital.uploading' }) : t({ id: 'catalogacao.digital.uploadHint' })}
            </div>
            {digitalForm.storage_bucket && digitalForm.storage_path && (
              <div style={{ fontSize: '.72rem', color: '#7fd18f', marginTop: 5, wordBreak: 'break-all' }}>
                ✓ {digitalForm.storage_bucket} · {digitalForm.storage_path}
              </div>
            )}
          </div>
          <div className="cat-book-grid">
            <div className="cat-field">
              <label>{t({ id: 'catalogacao.digital.type' })}</label>
              <select value={digitalForm.resource_type} onChange={e => setDf('resource_type', e.target.value)}
                style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }}>
                {RESOURCE_TYPES.map(t => <option key={t.value} value={t.value}>{t.label}</option>)}
              </select>
            </div>
            <div className="cat-field">
              <label>{t({ id: 'catalogacao.digital.usage' })}</label>
              <select value={digitalForm.usage_type} onChange={e => setDf('usage_type', e.target.value)}
                style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }}>
                {USAGE_TYPES.map(t => <option key={t.value} value={t.value}>{t.label}</option>)}
              </select>
            </div>
            <div className="cat-field">
              <label>{t({ id: 'catalogacao.digital.access' })}</label>
              <select value={digitalForm.access_scope} onChange={e => setDf('access_scope', e.target.value)}
                style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }}>
                {ACCESS_SCOPES.map(s => <option key={s.value} value={s.value}>{s.label}</option>)}
              </select>
            </div>
            <div className="cat-field">
              <label>{t({ id: 'catalogacao.digital.bucket' })}</label>
              <input type="text" value={digitalForm.storage_bucket} onChange={e => setDf('storage_bucket', e.target.value)}
                placeholder="digital-assets-public" style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
            </div>
            <div className="cat-field" style={{ gridColumn: 'span 2' }}>
              <label>{t({ id: 'catalogacao.digital.path' })}</label>
              <input type="text" value={digitalForm.storage_path} onChange={e => setDf('storage_path', e.target.value)}
                placeholder="books/12345/documento.pdf" style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
            </div>
            <div className="cat-field" style={{ gridColumn: 'span 2' }}>
              <label>{t({ id: 'catalogacao.digital.sourceUrl' })}</label>
              <input type="text" value={digitalForm.source_url} onChange={e => setDf('source_url', e.target.value)}
                placeholder="https://archive.org/..." style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
            </div>
            <div className="cat-field">
              <label>{t({ id: 'catalogacao.digital.sourceName' })}</label>
              <input type="text" value={digitalForm.source_name} onChange={e => setDf('source_name', e.target.value)}
                placeholder="Internet Archive" style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
            </div>
            <div className="cat-field">
              <label>{t({id:'catalogacao.digital.attribution'})}</label>
              <input type="text" value={digitalForm.attribution_text} onChange={e => setDf('attribution_text', e.target.value)}
                placeholder={t({ id: 'catalogacao.ph.scannedBy' })} style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
            </div>
            <div className="cat-field">
              <label>{t({ id: 'catalogacao.digital.rightsStatus' })}</label>
              <select value={digitalForm.rights_status || ''} onChange={e => setDf('rights_status', e.target.value)}
                style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }}>
                <option value="">{t({ id: 'catalogacao.digital.rights.unset' })}</option>
                <option value="dominio_publico">{t({ id: 'catalogacao.digital.rights.dominio_publico' })}</option>
                <option value="cessao_autoral">{t({ id: 'catalogacao.digital.rights.cessao_autoral' })}</option>
                <option value="licenca_livre">{t({ id: 'catalogacao.digital.rights.licenca_livre' })}</option>
                <option value="sob_direitos">{t({ id: 'catalogacao.digital.rights.sob_direitos' })}</option>
              </select>
              <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #aaa)', marginTop: 6 }}>{t({ id: 'catalogacao.digital.rights.hint' })}</div>
            </div>
            <div className="cat-field" style={{ gridColumn: 'span 2' }}>
              <label>{t({ id: 'catalogacao.digital.rightsJustification' })}</label>
              <input type="text" value={digitalForm.rights_justification || ''} onChange={e => setDf('rights_justification', e.target.value)}
                placeholder={t({ id: 'catalogacao.digital.rightsJustification.ph' })} style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
            </div>
            <div className="cat-field">
              <label>{t({ id: 'catalogacao.form.language' })}</label>
              <input type="text" value={digitalForm.language_code} onChange={e => setDf('language_code', e.target.value)}
                placeholder="pt" style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
            </div>
            <div className="cat-field">
              <label>{t({ id: 'catalogacao.digital.mime' })}</label>
              <input type="text" value={digitalForm.mime_type} onChange={e => setDf('mime_type', e.target.value)}
                placeholder="application/pdf" style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
            </div>
            <div className="cat-field" style={{ gridColumn: 'span 3' }}>
              <label>{t({ id: 'catalogacao.digital.notes' })}</label>
              <input type="text" value={digitalForm.notes || ''} onChange={e => setDf('notes', e.target.value)}
                placeholder={t({ id: 'catalogacao.ph.internalNotes' })} style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
            </div>
            <div style={{ gridColumn: 'span 3', display: 'flex', gap: 16, alignItems: 'center' }}>
              <label style={{ display: 'flex', gap: 5, alignItems: 'center', fontSize: '.82rem', cursor: 'pointer' }}>
                <input type="checkbox" checked={digitalForm.is_primary} onChange={e => setDf('is_primary', e.target.checked)} />
                {t({ id: 'catalogacao.digital.isPrimary' })}
              </label>
              <label style={{ display: 'flex', gap: 5, alignItems: 'center', fontSize: '.82rem', cursor: 'pointer' }}>
                <input type="checkbox" checked={digitalForm.bibliographic_match_validated} onChange={e => setDf('bibliographic_match_validated', e.target.checked)} />
                {t({ id: 'catalogacao.digital.matchValidated' })}
              </label>
              <label style={{ display: 'flex', gap: 5, alignItems: 'center', fontSize: '.82rem', cursor: 'pointer' }}>
                <input type="checkbox"
                  checked={digitalForm.rights_status === 'dominio_publico' && digitalForm.access_scope === 'publico'}
                  onChange={e => { if (e.target.checked) { setDf('rights_status', 'dominio_publico'); setDf('access_scope', 'publico'); } else { setDf('rights_status', ''); } }} />
                {t({ id: 'catalogacao.digital.freeRights' })}
              </label>
            </div>
          </div>
          <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
            <button type="button" className="ab-button ab-button--sm"
              onClick={saveDigitalResource} disabled={digitalSaving}>
              {digitalSaving ? t({ id: 'common.saving' }) : (digitalForm.id ? t({ id: 'catalogacao.digital.update' }) : t({ id: 'catalogacao.digital.sendToAnarbib' }))}
            </button>
            <button type="button" className="ab-button ab-button--ghost ab-button--sm"
              onClick={() => setDigitalForm(null)}>{t({ id: 'common.cancel' })}</button>
          </div>
        </div>
      )}
    </div>
  );
}
