// src/pages/biblioteca/RegulationSection.jsx — E6, BibliotecaPage lot 5 (12/10/2026)
// L'onglet « Regimento e circulação » : l'encart du régime, les règlements
// (téléversement d'un PDF dans library-regimentos-public, un seul actif par
// sorte ; retrait réversible par remove_library_regulation_document), les jeux
// de règles de circulation (PolicySetManager), la cotisation et le dépôt de
// garantie (sections du lot 3). Les règlements et les règles arrivent du
// parent ; onChanged fait recharger le parent après un téléversement ou un retrait.
import { useState, useRef } from 'react';
import { useIntl } from 'react-intl';
import { supabase, SUPABASE_URL } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import RegimeStateBox from '@/components/library/RegimeStateBox';
import PolicySetManager from '@/components/library/PolicySetManager';
import MembershipSection from './MembershipSection';
import DepositSection from './DepositSection';
import { bx } from './styles';

export default function RegulationSection({ libraryId, isCoord, user, lib, setLib, regDocs, membershipRules, setMembershipRules, depositRules, setDepositRules, setMsg, onChanged }) {
  const { formatMessage: t, locale } = useIntl();
  const [saving, setSaving] = useState(false);
  const regFileRef = useRef(null);

  // Helper i18n : pour les seeds système (system_seed_key non-NULL), tente de
  // traduire via i18n applicative ; sinon retombe sur le texte stocké en base.
  // Usage : seedT(rule, 'rule_label', 'rule.label') → cherche
  // `circulation.systemRule.{key}.label` ; si pas trouvée, retourne rule.rule_label.
  function seedT(entity, fallbackField, i18nSubKey) {
    if (entity?.system_seed_key) {
      const fullKey = `circulation.${i18nSubKey.startsWith('set.') ? 'systemSet' : 'systemRule'}.${entity.system_seed_key}.${i18nSubKey.split('.').pop()}`;
      const translated = t({ id: fullKey, defaultMessage: '__MISSING__' });
      if (translated !== '__MISSING__') return translated;
    }
    return entity?.[fallbackField];
  }

  // ── Upload regimento ────────────────────────────────────
  async function uploadRegimento() {
    const file = regFileRef.current?.files?.[0];
    if (!file) { setMsg({ text: 'Selecione um arquivo PDF.', kind: 'error' }); return; }
    setSaving(true); setMsg({ text: t({id:'biblioteca.regulation.sending'}), kind: 'info' });
    try {
      const slug = lib?.slug || 'library';
      const path = `regimentos/${slug}/${Date.now()}-${file.name.replace(/[^a-zA-Z0-9._-]/g, '_')}`;
      const { error: upErr } = await supabase.storage.from('library-regimentos-public').upload(path, file, { upsert: true });
      if (upErr) throw upErr;
      // FIX A.1 BUG #6: deactivate any existing active regimento before
      // inserting the new one. There's a unique constraint
      // uq_library_regulation_documents_one_active_per_kind that allows only
      // one active document per kind per library.
      await supabase.from('library_regulation_documents')
        .update({ is_active: false })
        .eq('library_id', libraryId)
        .eq('doc_kind', 'regimento')
        .eq('is_active', true);
      // FIX BUG #3: 'publicado' is rejected by CHECK constraint; valid values are
      // 'draft_only', 'published', 'archived'. Was breaking the upload silently.
      const { error: insErr } = await supabase.from('library_regulation_documents').insert({
        library_id: libraryId, doc_kind: 'regimento', publication_status: 'published',
        is_active: true, storage_bucket: 'library-regimentos-public', storage_path_public: path,
        version_label: t({ id: 'biblioteca.regulation.versionPrefix' }, { date: new Date().toLocaleDateString(locale) }),
        created_by: user?.id,
      });
      if (insErr) throw insErr;
      setMsg({ text: t({ id: 'biblioteca.regulation.published' }), kind: 'ok' });
      regFileRef.current.value = '';
      await onChanged?.();
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:localizeError(err, t)}), kind: 'error' }); }
    finally { setSaving(false); }
  }

  // ── Retrait d'un règlement périmé ────────────────────────
  // Archivage réversible par défaut ; suppression dure réservée aux brouillons
  // jamais publiés (côté RPC). Jamais le règlement actif ni un doc référencé.
  async function removeRegimento(doc) {
    const isDraft = doc.publication_status === 'draft_only' && !doc.is_active;
    const label = doc.version_label || String(doc.id);
    const confirmMsg = isDraft
      ? t({ id: 'biblioteca.regulation.removeConfirmDelete' }, { label })
      : t({ id: 'biblioteca.regulation.removeConfirmArchive' }, { label });
    if (!window.confirm(confirmMsg)) return;
    setSaving(true); setMsg({ text: '', kind: '' });
    try {
      const { data, error } = await supabase.rpc('remove_library_regulation_document', { p_document_id: doc.id });
      if (error) throw error;
      if (data?.action === 'deleted' && Array.isArray(data.storage_paths) && data.storage_paths.length) {
        // Suppression best-effort du PDF (le fichier peut déjà être absent).
        try { await supabase.storage.from(data.storage_bucket || 'library-regimentos-public').remove(data.storage_paths); } catch { /* no-op */ }
      }
      setMsg({ text: t({ id: data?.action === 'deleted' ? 'biblioteca.regulation.deleted' : 'biblioteca.regulation.archived' }), kind: 'ok' });
      await onChanged?.();
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setSaving(false); }
  }

  return (<div>
          <h3 style={{ marginBottom:12 }}>{t({ id: 'biblioteca.regulation.title' })}</h3>
          {/* EA-06 (21/05/2026) : encart de lecture du regime.
              Diagnostic synthetique du croisement jeu actif x texte actif. */}
          <RegimeStateBox libraryId={libraryId} regulationDocs={regDocs} />
          <div style={bx}>
            <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.regulation.docs' })}</h4>
            {regDocs.filter(doc => !doc.archived_at).map(doc => (
              <div key={doc.id} style={{ padding:'8px 10px', borderRadius:6, background:'rgba(0,0,0,.15)', marginBottom:6, display:'flex', justifyContent:'space-between', alignItems:'center', gap:8 }}>
                <div>
                  <div style={{ fontSize:'.9rem', fontWeight:600 }}>{doc.version_label||t({ id: 'biblioteca.regulation.versionFallback' }, { id: doc.id })}</div>
                  <div style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>
                    {doc.doc_kind ? t({ id: `biblioteca.regulation.docKind.${doc.doc_kind}`, defaultMessage: doc.doc_kind }) : '—'}
                    {' · '}
                    {doc.publication_status ? t({ id: `biblioteca.regulation.pubStatus.${doc.publication_status}`, defaultMessage: doc.publication_status }) : '—'}
                    {doc.is_active && <> · <span className="cat-pill ok" style={{ fontSize:'.65rem' }}>{t({ id: 'common.active' })}</span></>}
                  </div>
                </div>
                <div style={{ display:'flex', gap:8, alignItems:'center', flexShrink:0 }}>
                  {doc.storage_path_public && <a href={`${SUPABASE_URL}/storage/v1/object/public/${doc.storage_bucket||'library-regimentos-public'}/${doc.storage_path_public}`} target="_blank" rel="noopener" className="cat-btn secondary" style={{ fontSize:'.82rem', padding:'5px 12px' }}>{t({ id: 'biblioteca.regulation.openPdf' })}</a>}
                  {isCoord && !doc.is_active && (
                    <button type="button" className="cat-btn secondary" disabled={saving}
                      onClick={() => removeRegimento(doc)}
                      title={t({ id: 'biblioteca.regulation.removeHint' })}
                      style={{ fontSize:'.82rem', padding:'5px 12px', color:'var(--danger, #e06666)' }}>
                      {t({ id: 'biblioteca.regulation.remove' })}
                    </button>
                  )}
                </div>
              </div>
            ))}
            <div style={{ marginTop:12, display:'flex', gap:8, alignItems:'center', flexWrap:'wrap' }}>
              <label style={{ display:'inline-block', padding:'8px 16px', borderRadius:8, background:'var(--brand-panel-bg)', border:'1px solid rgba(255,255,255,.15)', cursor:'pointer', fontSize:'.88rem', fontWeight:600 }}>
                {t({ id: 'biblioteca.regulation.choosePdf' })}
                <input type="file" accept=".pdf,application/pdf" ref={regFileRef} style={{ display:'none' }} />
              </label>
              <button className="cat-btn primary" onClick={uploadRegimento} disabled={saving} style={{ fontSize:'.88rem' }}>
                {saving ? t({ id: 'biblioteca.regulation.uploading' }) : t({ id: 'biblioteca.regulation.uploadNew' })}
              </button>
            </div>
          </div>
          {/* EA-05 (21/05/2026) : gestionnaire de jeux de regles de circulation.
              Remplace l'editeur inline mono-jeu par PolicySetManager, qui
              gere tous les jeux (draft/active/archived) + leurs regles via RPC. */}
          <PolicySetManager
            libraryId={libraryId}
            canEdit={isCoord}
            regulationDocs={regDocs}
            seedT={seedT}
          />

          {/* ─── Cotisation associative (E6 lot 3 : MembershipSection) ─── */}
          <MembershipSection libraryId={libraryId} lib={lib} setLib={setLib}
            rules={membershipRules} setRules={setMembershipRules} setMsg={setMsg} />

          {/* ─── Dépôt de garantie (DEPOT-1/6 ; E6 lot 3 : DepositSection) ───
              Opt-in strict par biblio : OFF par défaut → rien n'apparaît
              au comptoir / dans /conta / dans les rapports. */}
          <DepositSection libraryId={libraryId} lib={lib} setLib={setLib}
            rules={depositRules} setRules={setDepositRules} setMsg={setMsg} />
  </div>);
}
