// src/pages/catalogacao/DigitalResourcesPanel.jsx
//
// Ressources numériques d'un brouillon de notice — refonte du 05/10/2026
// (Xavier : « partir du statut des droits, puis du choix de la bibliothèque
// quant à l'accès ; le seau doit en découler »). Migration 20261005092916.
//
// Le formulaire se remplit dans l'ordre, chaque étape s'ouvrant quand la
// précédente est faite :
//   1. Quoi ?            un fichier (PDF, EPUB, audio, vidéo, image) ou un lien ;
//   2. Les droits        domaine public, licence libre, cession, sous droits ;
//   3. Qui lit ?         proposé selon les droits : tout le monde, ou les
//                        lecteur·rices des bibliothèques détentrices ; la lecture
//                        publique d'une œuvre sous droits n'existe que si la
//                        bibliothèque l'a ouverte (Atelier → Catalogage), avec
//                        un avertissement sur sa responsabilité légale ;
//   4. Le fichier / lien l'espace de stockage est DÉDUIT de l'accès (plus de
//                        champ « seau » à la main) ; changer l'accès d'un
//                        fichier déjà versé le déplace d'un espace à l'autre ;
//   5. Description       libellé, source, attribution, langue, notes.
// Type de ressource et usage (lire, écouter, voir) sont déduits du fichier.
// La base garde la même cohérence (trg_draft_digital_resource_coherence).
import { useState, useEffect } from 'react';
import { useIntl } from 'react-intl';
import { useConfirm } from '@/contexts/ConfirmContext';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

const DROITS = ['dominio_publico', 'licenca_livre', 'cessao_autoral', 'sob_direitos'];
// Seau [public, réservé] par famille de fichier.
const SEAUX = {
  pdf: ['anarbib-pdf-public', 'pdf-restrito'],
  epub: ['anarbib-epub-public', 'anarbib-epub-restricted'],
  audio: ['anarbib-media-public', 'anarbib-media-restricted'],
  video: ['anarbib-media-public', 'anarbib-media-restricted'],
  image: ['anarbib-media-public', 'anarbib-media-restricted'],
};
const USAGE = { pdf: 'leitura_online', epub: 'leitura_online', audio: 'escuta_online', video: 'visualizacao_online', image: 'visualizacao_online' };
const TAILLE_MAX = 100 * 1024 * 1024;

export function familleDe(mime, nom = '') {
  const m = (mime || '').toLowerCase();
  const n = (nom || '').toLowerCase();
  if (m === 'application/pdf' || n.endsWith('.pdf')) return 'pdf';
  if (m === 'application/epub+zip' || n.endsWith('.epub')) return 'epub';
  if (m.startsWith('audio/')) return 'audio';
  if (m.startsWith('video/')) return 'video';
  if (m.startsWith('image/')) return 'image';
  return null;
}
export function seauPour(famille, acces) {
  const s = SEAUX[famille];
  return s ? s[acces === 'conta_ativa' ? 1 : 0] : null;
}
export function typePour(famille, acces) {
  if (!famille) return 'link_externo';
  if (famille === 'pdf') return acces === 'conta_ativa' ? 'pdf_restrito' : 'pdf_publico';
  return famille;
}
// Accès proposés selon les droits ; la lecture publique d'une œuvre sous
// droits dépend du réglage de la bibliothèque.
export function accesPossibles(droits, bibliothequeOuverte) {
  if (!droits) return [];
  if (droits === 'sob_direitos') return [
    { value: 'conta_ativa', enabled: true },
    { value: 'publico', enabled: !!bibliothequeOuverte },
  ];
  return [{ value: 'publico', enabled: true }, { value: 'conta_ativa', enabled: true }];
}
// C10 (05/10/2026) — le piège access_scope : la base met « conta_ativa » par
// défaut. Une œuvre libre (domaine public, licence libre) née ailleurs que dans
// ce formulaire — import, attachement d'un fonds reçu — reste ainsi réservée
// aux comptes tant que personne n'a choisi « Tout le monde ». Rappelé dans la
// liste et à l'étape 3, jamais corrigé en silence : c'est un choix.
export function libreMaisReservee(droits, acces) {
  return (droits === 'dominio_publico' || droits === 'licenca_livre') && acces === 'conta_ativa';
}
export function justificationRequise(droits, acces) {
  return droits === 'licenca_livre' || droits === 'cessao_autoral' || (droits === 'sob_direitos' && acces === 'publico');
}

const VIDE = {
  id: '', kind: '', rights_status: '', rights_justification: '', access_scope: '',
  storage_bucket: '', storage_path: '', mime_type: '', source_url: '', source_name: '',
  attribution_text: '', language_code: '', label: '', notes: '', is_primary: false,
  bibliographic_match_validated: true,
};

const champ = { width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' };

export default function DigitalResourcesPanel({ draftId, ownerLibraryId, resources, onChanged, setMsg }) {
  const { formatMessage: t } = useIntl();
  const confirmer = useConfirm();
  const [df, setDfState] = useState(null);         // ressource en cours d'édition
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [bibliotheque, setBibliotheque] = useState({ ouverte: false, nom: '' });

  // Le brouillon change : l'édition en cours ne le concerne plus.
  useEffect(() => { setDfState(null); }, [draftId]);

  // Le réglage de la bibliothèque du brouillon (Atelier → Catalogage).
  useEffect(() => {
    let annule = false;
    if (!ownerLibraryId) { setBibliotheque({ ouverte: false, nom: '' }); return undefined; }
    supabase.from('libraries').select('name, digital_public_under_rights').eq('id', ownerLibraryId).maybeSingle()
      .then(({ data }) => { if (!annule) setBibliotheque({ ouverte: !!data?.digital_public_under_rights, nom: data?.name || '' }); });
    return () => { annule = true; };
  }, [ownerLibraryId]);

  const set = (k, v) => setDfState((p) => (p ? { ...p, [k]: v } : p));

  function nouvelle() { setDfState({ ...VIDE }); }
  function editer(r) {
    setDfState({
      ...VIDE,
      id: String(r.id || ''),
      kind: r.storage_path ? 'file' : 'link',
      rights_status: r.rights_status || '',
      rights_justification: r.rights_justification || '',
      access_scope: r.access_scope || '',
      storage_bucket: r.storage_bucket || '', storage_path: r.storage_path || '', mime_type: r.mime_type || '',
      source_url: r.source_url || '', source_name: r.source_name || '', attribution_text: r.attribution_text || '',
      language_code: r.language_code || '', label: r.label || '', notes: r.notes || '',
      is_primary: !!r.is_primary, bibliographic_match_validated: r.bibliographic_match_validated !== false,
    });
  }

  // ── 2. Droits : l'accès par défaut en découle ─────────────────────────
  function choisirDroits(droits) {
    setDfState((p) => {
      if (!p) return p;
      let acces = p.access_scope;
      if (droits === 'sob_direitos') acces = 'conta_ativa';      // sous droits : réservé d'abord
      else if (!acces) acces = 'publico';
      return { ...p, rights_status: droits, access_scope: acces };
    });
  }

  // ── 3. Accès : la lecture publique d'une œuvre sous droits se confirme ─
  async function choisirAcces(acces) {
    if (!df) return;
    if (acces === 'publico' && df.rights_status === 'sob_direitos') {
      if (!bibliotheque.ouverte) return;
      const ok = await confirmer({
        title: t({ id: 'catalogacao.dep.legal.title' }),
        message: t({ id: 'catalogacao.dep.legal.body' }, { library: bibliotheque.nom || '—' }),
        confirmLabel: t({ id: 'catalogacao.dep.legal.confirm' }),
        tone: 'danger',
      });
      if (!ok) return;
    }
    set('access_scope', acces);
  }

  // ── 4. Fichier : versé dans l'espace que l'accès désigne ───────────────
  async function verser(file) {
    if (!draftId || !df || !file) return;
    const famille = familleDe(file.type, file.name);
    if (!famille) { setMsg({ text: t({ id: 'catalogacao.digital.unsupportedType' }), kind: 'error' }); return; }
    if (file.size > TAILLE_MAX) { setMsg({ text: t({ id: 'catalogacao.digital.fileTooLarge' }), kind: 'error' }); return; }
    const seau = seauPour(famille, df.access_scope);
    setUploading(true);
    try {
      const sur = file.name.normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-zA-Z0-9._-]/g, '_');
      const chemin = `books/${draftId}/${Date.now()}_${sur}`;
      const mime = file.type || (famille === 'epub' ? 'application/epub+zip' : famille === 'pdf' ? 'application/pdf' : '');
      const { error } = await supabase.storage.from(seau).upload(chemin, file, { upsert: false, contentType: mime || undefined });
      if (error) throw error;
      setDfState((p) => ({ ...p, storage_bucket: seau, storage_path: chemin, mime_type: mime, label: p.label || file.name }));
      setMsg({ text: t({ id: 'catalogacao.digital.uploaded' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.msg.digitalError' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setUploading(false); }
  }

  // L'accès a changé après le versement : le fichier change d'espace. Un
  // document passé en « réservé » ne doit pas rester lisible dans l'espace
  // public — l'ancien objet est retiré. Rend faux si ce retrait a échoué : la
  // personne doit le savoir (une copie peut rester lisible là où elle ne
  // devrait plus l'être), pas seulement la console.
  async function deplacer(seauSource, chemin, seauCible) {
    const { data: blob, error: e1 } = await supabase.storage.from(seauSource).download(chemin);
    if (e1) throw e1;
    const { error: e2 } = await supabase.storage.from(seauCible).upload(chemin, blob, { upsert: true, contentType: blob.type || undefined });
    if (e2) throw e2;
    const { data: retires, error: e3 } = await supabase.storage.from(seauSource).remove([chemin]);
    if (e3 || !retires?.length) { console.warn('retrait de l’ancien fichier :', e3?.message || 'aucun objet retiré'); return false; }
    return true;
  }

  // ── Enregistrer ────────────────────────────────────────────────────────
  async function enregistrer() {
    if (!draftId) { setMsg({ text: t({ id: 'catalogacao.msg.saveBeforeDigital' }), kind: 'error' }); return; }
    if (!df) return;
    if (!df.rights_status) { setMsg({ text: t({ id: 'catalogacao.dep.err.rights' }), kind: 'error' }); return; }
    if (justificationRequise(df.rights_status, df.access_scope) && !df.rights_justification.trim()) {
      setMsg({ text: t({ id: 'catalogacao.dep.err.justification' }), kind: 'error' }); return;
    }
    if (df.kind === 'file' && !df.storage_path) { setMsg({ text: t({ id: 'catalogacao.dep.err.file' }), kind: 'error' }); return; }
    if (df.kind === 'link' && !/^https?:\/\//i.test(df.source_url.trim())) { setMsg({ text: t({ id: 'catalogacao.dep.err.link' }), kind: 'error' }); return; }

    setSaving(true);
    try {
      const famille = df.kind === 'file' ? familleDe(df.mime_type, df.storage_path) : null;
      let seau = df.kind === 'file' ? df.storage_bucket : null;
      let deplace = false;
      let copieRestee = null;   // « seau/chemin » d'une ancienne copie non retirée
      if (df.kind === 'file') {
        const attendu = seauPour(famille, df.access_scope);
        if (attendu && seau && seau !== attendu) {
          if (!(await deplacer(seau, df.storage_path, attendu))) copieRestee = `${seau}/${df.storage_path}`;
          seau = attendu; deplace = true;
        }
      }
      const payload = {
        book_draft_id: Number(draftId),
        resource_type: typePour(famille, df.access_scope),
        usage_type: famille ? USAGE[famille] : 'link_externo',
        access_scope: df.access_scope,
        status: 'draft',
        is_active: true,
        storage_bucket: seau,
        storage_path: df.kind === 'file' ? df.storage_path : null,
        mime_type: df.kind === 'file' ? (df.mime_type || null) : 'text/html',
        language_code: df.language_code || null,
        source_name: df.source_name || null,
        source_url: df.source_url.trim() || null,
        attribution_text: df.attribution_text || null,
        rights_status: df.rights_status,
        rights_justification: df.rights_justification.trim() || null,
        is_primary: df.is_primary,
        bibliographic_match_validated: df.bibliographic_match_validated,
        label: df.label || df.source_name || t({ id: 'catalogacao.digital.defaultLabel' }),
        notes: df.notes || null,
      };
      const q = df.id
        ? supabase.from('book_draft_digital_resources').update(payload).eq('id', Number(df.id))
        : supabase.from('book_draft_digital_resources').insert(payload);
      const { error } = await q;
      if (error) throw error;
      setDfState(null);
      await onChanged();
      if (copieRestee) {
        setMsg({ text: t({ id: 'catalogacao.dep.oldCopyNotRemoved' }, { path: copieRestee }), kind: 'error' });
        return;
      }
      setMsg({ text: deplace
        ? t({ id: 'catalogacao.dep.moved' }, { space: t({ id: df.access_scope === 'conta_ativa' ? 'catalogacao.dep.storage.reserved' : 'catalogacao.dep.storage.public' }) })
        : t({ id: 'catalogacao.msg.digitalSaved' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.msg.digitalError' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setSaving(false); }
  }

  async function supprimer(id) {
    if (!(await confirmer({ message: t({ id: 'catalogacao.digital.confirmDelete' }), confirmLabel: t({ id: 'confirm.action.delete' }), tone: 'danger' }))) return;
    try {
      const { error } = await supabase.from('book_draft_digital_resources').delete().eq('id', Number(id));
      if (error) throw error;
      await onChanged();
      setMsg({ text: t({ id: 'catalogacao.msg.digitalDeleted' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    }
  }

  if (!draftId) return null;

  const droitsLabel = (d) => (d ? t({ id: `catalogacao.digital.rights.${d}` }) : t({ id: 'catalogacao.digital.rights.unset' }));
  const accesLabel = (a) => t({ id: a === 'conta_ativa' ? 'catalogacao.dep.access.reserved' : 'catalogacao.dep.access.public' });
  const options = df ? accesPossibles(df.rights_status, bibliotheque.ouverte) : [];
  const etape3 = !!df?.rights_status;
  const etape4 = etape3 && !!df?.access_scope;
  const requise = df ? justificationRequise(df.rights_status, df.access_scope) : false;

  return (
    <div className="cat-material-section cat-dep" style={{ gridColumn: 'span 3' }}>
      <div className="cat-dep__head">
        <h4 style={{ margin: 0 }}>{t({ id: 'catalogacao.digital.sectionTitle' })}</h4>
        {!df && (
          <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={nouvelle}>
            {t({ id: 'catalogacao.digital.newResource' })}
          </button>
        )}
      </div>

      {resources.length > 0 && (
        <ul className="cat-dep__list">
          {resources.map((r) => (
            <li key={r.id} className="cat-dep__item">
              <div style={{ flex: 1, minWidth: 0 }}>
                <div className="cat-dep__item-title">
                  {r.label || r.source_name || t({ id: 'catalogacao.digital.defaultLabel' })}
                  {r.is_primary && <span className="cat-pill ok" style={{ marginLeft: 6, fontSize: '.65rem' }}>{t({ id: 'catalogacao.ui.primary' })}</span>}
                </div>
                <div className="cat-dep__item-meta">
                  {droitsLabel(r.rights_status)} · {accesLabel(r.access_scope)}
                  {r.source_url && !r.storage_path && ` · ${r.source_url}`}
                </div>
                {libreMaisReservee(r.rights_status, r.access_scope) && (
                  <div className="cat-dep__note" role="note">{t({ id: 'catalogacao.dep.access.freeButReserved' })}</div>
                )}
              </div>
              <div style={{ display: 'flex', gap: 4, flexShrink: 0 }}>
                <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={() => editer(r)}>{t({ id: 'common.edit' })}</button>
                <button type="button" className="ab-button ab-button--danger ab-button--sm" onClick={() => supprimer(r.id)}>{t({ id: 'common.delete' })}</button>
              </div>
            </li>
          ))}
        </ul>
      )}
      {resources.length === 0 && !df && (
        <div className="cat-dep__empty">{t({ id: 'catalogacao.digital.empty' })}</div>
      )}

      {df && (
        <div className="cat-dep__form">
          <h4 style={{ margin: '0 0 12px', fontSize: '.9rem' }}>
            {df.id ? t({ id: 'catalogacao.digital.editTitle' }) : t({ id: 'catalogacao.digital.newTitle' })}
          </h4>

          {/* 1. Quoi ? */}
          <fieldset className="cat-dep__step">
            <legend>{t({ id: 'catalogacao.dep.step.kind' })}</legend>
            <div className="cat-dep__choices">
              {['file', 'link'].map((k) => (
                <label key={k} className={`cat-dep__choice${df.kind === k ? ' is-on' : ''}`}>
                  <input type="radio" name="dep-kind" checked={df.kind === k} disabled={!!df.storage_path && k === 'link'}
                    onChange={() => set('kind', k)} />
                  <span>{t({ id: `catalogacao.dep.kind.${k}` })}</span>
                </label>
              ))}
            </div>
          </fieldset>

          {/* 2. Les droits */}
          {df.kind && (
            <fieldset className="cat-dep__step">
              <legend>{t({ id: 'catalogacao.dep.step.rights' })}</legend>
              <div className="cat-dep__choices">
                {DROITS.map((d) => (
                  <label key={d} className={`cat-dep__choice${df.rights_status === d ? ' is-on' : ''}`}>
                    <input type="radio" name="dep-rights" checked={df.rights_status === d} onChange={() => choisirDroits(d)} />
                    <span>
                      <b>{t({ id: `catalogacao.digital.rights.${d}` })}</b>
                      <small>{t({ id: `catalogacao.dep.rightsHint.${d}` })}</small>
                    </span>
                  </label>
                ))}
              </div>
            </fieldset>
          )}

          {/* 3. Qui lit ? */}
          {etape3 && (
            <fieldset className="cat-dep__step">
              <legend>{t({ id: 'catalogacao.dep.step.access' })}</legend>
              <div className="cat-dep__choices">
                {options.map((o) => (
                  <label key={o.value} className={`cat-dep__choice${df.access_scope === o.value ? ' is-on' : ''}${o.enabled ? '' : ' is-off'}`}>
                    <input type="radio" name="dep-access" checked={df.access_scope === o.value} disabled={!o.enabled}
                      onChange={() => choisirAcces(o.value)} />
                    <span>
                      <b>{accesLabel(o.value)}</b>
                      <small>{o.enabled
                        ? t({ id: o.value === 'conta_ativa' ? 'catalogacao.dep.access.reservedHint' : 'catalogacao.dep.access.publicHint' })
                        : t({ id: 'catalogacao.dep.access.publicLocked' })}</small>
                    </span>
                  </label>
                ))}
              </div>
              {df.rights_status === 'sob_direitos' && (
                <div className="cat-dep__note">{t({ id: 'catalogacao.dep.access.noDeposit' })}</div>
              )}
              {libreMaisReservee(df.rights_status, df.access_scope) && (
                <div className="cat-dep__note" role="note">{t({ id: 'catalogacao.dep.access.freeButReserved' })}</div>
              )}
              {requise && (
                <div className="cat-field" style={{ marginTop: 10 }}>
                  <label>{t({ id: `catalogacao.dep.justification.${df.rights_status}` })} *</label>
                  <input type="text" value={df.rights_justification} onChange={(e) => set('rights_justification', e.target.value)}
                    placeholder={t({ id: `catalogacao.dep.justification.${df.rights_status}.ph` })} style={champ} />
                </div>
              )}
            </fieldset>
          )}

          {/* 4. Le fichier, ou le lien */}
          {etape4 && df.kind === 'file' && (
            <fieldset className="cat-dep__step">
              <legend>{t({ id: 'catalogacao.dep.step.file' })}</legend>
              <input type="file" accept="application/pdf,application/epub+zip,.epub,audio/*,video/*,image/*"
                disabled={uploading}
                onChange={(e) => { const f = e.target.files && e.target.files[0]; if (f) verser(f); e.target.value = ''; }}
                style={{ fontSize: '.8rem', color: '#f4f4f4' }} />
              <div className="cat-dep__note">
                {uploading ? t({ id: 'catalogacao.digital.uploading' })
                  : t({ id: df.access_scope === 'conta_ativa' ? 'catalogacao.dep.storage.reservedHint' : 'catalogacao.dep.storage.publicHint' })}
              </div>
              {df.storage_path && (
                <div className="cat-dep__file">
                  ✓ {df.storage_path.split('/').pop()}
                  {' — '}
                  {t({ id: (seauPour(familleDe(df.mime_type, df.storage_path), df.access_scope) || df.storage_bucket) === df.storage_bucket
                    ? (df.access_scope === 'conta_ativa' ? 'catalogacao.dep.storage.reserved' : 'catalogacao.dep.storage.public')
                    : 'catalogacao.dep.storage.willMove' })}
                </div>
              )}
            </fieldset>
          )}
          {etape4 && df.kind === 'link' && (
            <fieldset className="cat-dep__step">
              <legend>{t({ id: 'catalogacao.dep.step.link' })}</legend>
              <input type="url" value={df.source_url} onChange={(e) => set('source_url', e.target.value)}
                placeholder="https://…" style={champ} />
            </fieldset>
          )}

          {/* 5. Description */}
          {etape4 && (
            <fieldset className="cat-dep__step">
              <legend>{t({ id: 'catalogacao.dep.step.describe' })}</legend>
              <div className="cat-book-grid">
                <div className="cat-field" style={{ gridColumn: 'span 2' }}>
                  <label>{t({ id: 'catalogacao.dep.label' })}</label>
                  <input type="text" value={df.label} onChange={(e) => set('label', e.target.value)} style={champ} />
                </div>
                <div className="cat-field">
                  <label>{t({ id: 'catalogacao.form.language' })}</label>
                  <input type="text" value={df.language_code} onChange={(e) => set('language_code', e.target.value)} placeholder="pt" style={champ} />
                </div>
                {df.kind === 'file' && (
                  <div className="cat-field" style={{ gridColumn: 'span 2' }}>
                    <label>{t({ id: 'catalogacao.dep.foundAt' })}</label>
                    <input type="url" value={df.source_url} onChange={(e) => set('source_url', e.target.value)} placeholder="https://archive.org/…" style={champ} />
                  </div>
                )}
                <div className="cat-field">
                  <label>{t({ id: 'catalogacao.digital.sourceName' })}</label>
                  <input type="text" value={df.source_name} onChange={(e) => set('source_name', e.target.value)} placeholder="Internet Archive" style={champ} />
                </div>
                <div className="cat-field" style={{ gridColumn: 'span 2' }}>
                  <label>{t({ id: 'catalogacao.digital.attribution' })}</label>
                  <input type="text" value={df.attribution_text} onChange={(e) => set('attribution_text', e.target.value)}
                    placeholder={t({ id: 'catalogacao.ph.scannedBy' })} style={champ} />
                </div>
                <div className="cat-field">
                  <label>{t({ id: 'catalogacao.digital.notes' })}</label>
                  <input type="text" value={df.notes} onChange={(e) => set('notes', e.target.value)}
                    placeholder={t({ id: 'catalogacao.ph.internalNotes' })} style={champ} />
                </div>
              </div>
              <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap', marginTop: 8 }}>
                <label className="cat-dep__check">
                  <input type="checkbox" checked={df.is_primary} onChange={(e) => set('is_primary', e.target.checked)} />
                  {t({ id: 'catalogacao.digital.isPrimary' })}
                </label>
                <label className="cat-dep__check">
                  <input type="checkbox" checked={df.bibliographic_match_validated} onChange={(e) => set('bibliographic_match_validated', e.target.checked)} />
                  {t({ id: 'catalogacao.digital.matchValidated' })}
                </label>
              </div>
            </fieldset>
          )}

          <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
            <button type="button" className="ab-button ab-button--sm" onClick={enregistrer} disabled={saving || uploading || !etape4}>
              {saving ? t({ id: 'common.saving' }) : (df.id ? t({ id: 'catalogacao.digital.update' }) : t({ id: 'catalogacao.digital.sendToAnarbib' }))}
            </button>
            <button type="button" className="ab-button ab-button--ghost ab-button--sm" onClick={() => setDfState(null)}>{t({ id: 'common.cancel' })}</button>
          </div>
        </div>
      )}
    </div>
  );
}
