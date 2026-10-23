// Barre de l'adaptateur : structure, vocabulaire, encodage, profils d'import — section de la face Import, sortie d'ImportacoesPage.jsx telle
// quelle (E6, 23/10/2026), avec l'état et les actions qu'elle est seule à lire
// (calculés par @babel/traverse) ; la page lui passe le reste.
// Garde : src/tests/importacoes-sections-montees.test.jsx.
import { useIntl } from 'react-intl';
import { useState } from 'react';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { assertRpcOk } from '../../lib/rpcStatus.js';
import { PROFILE_FIELDS, PROFILE_ITEM_KEYS, PROFILE_ITEM_HINTS } from './importacoesOutils.jsx';

// La pastille d'état, la même que celle de la page.
function Pill({ children, variant = 'muted' }) {
  return <span className={`cat-pill ${variant}`}>{children}</span>;
}

export default function ImportAdapterStrip(p) {
  const { formatMessage: t } = useIntl();
  const {
    adapterEncoding, adapterFormat, adapterProfile, adapterVocabulary, libraryId, profiles,
    setAdapterEncoding, setAdapterFormat, setAdapterProfile, setAdapterVocabulary, setMsg,
    setProfiles, uploading,
  } = p;

  const [profileFormOpen, setProfileFormOpen] = useState(false);
  const [profileName, setProfileName] = useState('');
  const [profileMapRows, setProfileMapRows] = useState([{ field: 'title', column: '' }]);
  const [profileDefRows, setProfileDefRows] = useState([{ field: 'language', value: '' }]);

  // H19 (IMP-21 c) : correspondance des sous-zones d'exemplaire (995/852) ;
  // une case vide garde la convention de PMB 8.1 (DEFAULT_ITEM_MAPPINGS, marc.ts).
  const [profileItems, setProfileItems] = useState(() => Object.fromEntries(PROFILE_ITEM_KEYS.map(k => [k, ''])));
  const [profileSaving, setProfileSaving] = useState(false);

  // ── Profils d'import (axe Perfil) : liste / création / suppression ──────────
  async function reloadProfiles() {
    if (!libraryId) return;
    const { data, error } = await supabase.rpc('fn_import_profiles_list', { p_library_id: libraryId });
    if (!error && data) setProfiles(Array.isArray(data) ? data : []);
  }

  async function handleCreateProfile() {
    if (!libraryId || !profileName.trim()) return;
    const mappings = {};
    for (const r of profileMapRows) { if (r.field && r.column.trim()) mappings[r.field] = r.column.trim(); }
    const defaults = {};
    for (const r of profileDefRows) { if (r.field && r.value.trim()) defaults[r.field] = r.value.trim(); }
    // H19 : seules les cases remplies partent ; aucune = convention PMB 8.1 (NULL en base).
    const items = {};
    for (const k of PROFILE_ITEM_KEYS) { const v = (profileItems[k] || '').trim().toLowerCase(); if (v) items[k] = v; }
    setProfileSaving(true);
    try {
      const { data, error } = await supabase.rpc('fn_import_profile_create', {
        p_library_id: libraryId, p_name: profileName.trim(),
        p_column_mappings: mappings, p_default_values: defaults,
        p_items_mapping: Object.keys(items).length ? items : null,
      });
      if (error) throw error;
      assertRpcOk(data);
      setMsg({ text: t({ id: 'importacoes.adapter.profileCreated' }, { name: profileName.trim() }), kind: 'ok' });
      setProfileName(''); setProfileMapRows([{ field: 'title', column: '' }]); setProfileDefRows([{ field: 'language', value: '' }]);
      setProfileItems(Object.fromEntries(PROFILE_ITEM_KEYS.map(k => [k, ''])));
      setProfileFormOpen(false);
      await reloadProfiles();
      if (data?.id) setAdapterProfile(String(data.id));
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally { setProfileSaving(false); }
  }

  async function handleDeleteProfile(id) {
    if (!window.confirm(t({ id: 'importacoes.adapter.profileDeleteConfirm' }))) return;
    try {
      const { data: rpcData, error } = await supabase.rpc('fn_import_profile_delete', { p_profile_id: Number(id) });
      if (error) throw error;
      assertRpcOk(rpcData);
      if (String(id) === adapterProfile) setAdapterProfile('');
      await reloadProfiles();
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    }
  }

  return (
    <div className="imp-sheet" style={{ marginBottom: 18 }}>
            <div className="imp-sheet__head">
              <span className="imp-sheet__title">
                {t({ id: 'importacoes.adapter.title' })}
                <Pill>{t({ id: 'importacoes.adapter.orthogonal' })}</Pill>
              </span>
            </div>
            <div className="imp-sheet__body">
              <div className="imp-row3" style={{ marginBottom: 10 }}>
                <div className="ab-field">
                  <label className="ab-field__label">{t({ id: 'importacoes.adapter.structure' })}</label>
                  <select className="ab-select" value={adapterFormat} onChange={e => setAdapterFormat(e.target.value)} disabled={uploading}>
                    <option value="auto">{t({ id: 'importacoes.adapter.autoDetect' })}</option>
                    <option value="marc">MARC</option>
                    <option value="ris">RIS</option>
                    <option value="csv">CSV</option>
                    <option value="tsv">TSV</option>
                  </select>
                </div>
                <div className="ab-field">
                  <label className="ab-field__label">{t({ id: 'importacoes.adapter.vocabulary' })}</label>
                  <select className="ab-select" value={adapterVocabulary} onChange={e => setAdapterVocabulary(e.target.value)} disabled={uploading}>
                    <option value="auto">{t({ id: 'importacoes.adapter.autoDetect' })}</option>
                    <option value="unimarc">UNIMARC</option>
                    <option value="marc21">MARC21</option>
                  </select>
                </div>
                <div className="ab-field">
                  <label className="ab-field__label">{t({ id: 'importacoes.adapter.encoding' })}</label>
                  <select className="ab-select" value={adapterEncoding} onChange={e => setAdapterEncoding(e.target.value)} disabled={uploading}>
                    <option value="auto">{t({ id: 'importacoes.adapter.autoDetect' })}</option>
                    <option value="utf-8">{t({ id: 'importacoes.adapter.encodingUtf8' })}</option>
                    <option value="windows-1252">{t({ id: 'importacoes.adapter.encodingLatin1' })}</option>
                  </select>
                </div>
                <div className="ab-field">
                  <label className="ab-field__label">{t({ id: 'importacoes.adapter.profile' })}</label>
                  <select className="ab-select" value={adapterProfile} onChange={e => setAdapterProfile(e.target.value)} disabled={uploading}>
                    <option value="">{t({ id: 'importacoes.adapter.defaultProfile' })}</option>
                    {profiles.map(p => <option key={p.id} value={p.id}>{p.name}</option>)}
                  </select>
                </div>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap', marginBottom: 8 }}>
                <button className="cat-btn secondary" type="button" onClick={() => setProfileFormOpen(o => !o)}>
                  {profileFormOpen ? t({ id: 'importacoes.adapter.profileClose' }) : t({ id: 'importacoes.adapter.profileManage' })}
                </button>
                {adapterProfile && (
                  <button className="cat-btn secondary" type="button" onClick={() => handleDeleteProfile(adapterProfile)}
                    style={{ borderColor: 'var(--brand-danger, #b42318)', color: 'var(--brand-danger, #b42318)' }}>
                    {t({ id: 'importacoes.adapter.profileDelete' })}
                  </button>
                )}
              </div>
              {profileFormOpen && (
                <div style={{ padding: '10px 12px', borderRadius: 8, background: 'rgba(127,127,127,0.08)', marginBottom: 10 }}>
                  <input className="ab-input" value={profileName} onChange={e => setProfileName(e.target.value)}
                    placeholder={t({ id: 'importacoes.adapter.profileName' })} style={{ width: '100%', marginBottom: 10 }} />
                  <p className="imp-note" style={{ margin: '0 0 4px', fontWeight: 600 }}>{t({ id: 'importacoes.adapter.profileMappings' })}</p>
                  {profileMapRows.map((row, idx) => (
                    <div key={idx} style={{ display: 'flex', gap: 8, marginBottom: 6 }}>
                      <input className="ab-input" value={row.column}
                        onChange={e => setProfileMapRows(rows => rows.map((r, i) => i === idx ? { ...r, column: e.target.value } : r))}
                        placeholder={t({ id: 'importacoes.adapter.profileColumn' })} style={{ flex: 1 }} />
                      <span style={{ alignSelf: 'center' }}>→</span>
                      <select className="ab-select" value={row.field} style={{ width: 150 }}
                        onChange={e => setProfileMapRows(rows => rows.map((r, i) => i === idx ? { ...r, field: e.target.value } : r))}>
                        {PROFILE_FIELDS.map(f => <option key={f} value={f}>{f}</option>)}
                      </select>
                      <button className="cat-btn secondary" type="button" onClick={() => setProfileMapRows(rows => rows.filter((_, i) => i !== idx))}>×</button>
                    </div>
                  ))}
                  <button className="cat-btn secondary" type="button" style={{ marginBottom: 12 }}
                    onClick={() => setProfileMapRows(rows => [...rows, { field: 'title', column: '' }])}>
                    {t({ id: 'importacoes.adapter.profileAddRow' })}
                  </button>
                  <p className="imp-note" style={{ margin: '0 0 4px', fontWeight: 600 }}>{t({ id: 'importacoes.adapter.profileDefaults' })}</p>
                  {profileDefRows.map((row, idx) => (
                    <div key={idx} style={{ display: 'flex', gap: 8, marginBottom: 6 }}>
                      <select className="ab-select" value={row.field} style={{ width: 150 }}
                        onChange={e => setProfileDefRows(rows => rows.map((r, i) => i === idx ? { ...r, field: e.target.value } : r))}>
                        {PROFILE_FIELDS.map(f => <option key={f} value={f}>{f}</option>)}
                      </select>
                      <span style={{ alignSelf: 'center' }}>=</span>
                      <input className="ab-input" value={row.value}
                        onChange={e => setProfileDefRows(rows => rows.map((r, i) => i === idx ? { ...r, value: e.target.value } : r))}
                        placeholder={t({ id: 'importacoes.adapter.profileValue' })} style={{ flex: 1 }} />
                      <button className="cat-btn secondary" type="button" onClick={() => setProfileDefRows(rows => rows.filter((_, i) => i !== idx))}>×</button>
                    </div>
                  ))}
                  <button className="cat-btn secondary" type="button" style={{ marginBottom: 12 }}
                    onClick={() => setProfileDefRows(rows => [...rows, { field: 'language', value: '' }])}>
                    {t({ id: 'importacoes.adapter.profileAddRow' })}
                  </button>
                  {/* H19 (IMP-21 c) : la correspondance des exemplaires (995 / 852) */}
                  <p className="imp-note" style={{ margin: '0 0 2px', fontWeight: 600 }}>{t({ id: 'importacoes.adapter.profileItems' })}</p>
                  <p className="imp-note" style={{ margin: '0 0 6px', fontSize: '.76rem' }}>{t({ id: 'importacoes.adapter.profileItemsHelp' })}</p>
                  <div data-testid="profile-items" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(min(100%, 150px), 1fr))', gap: 8, marginBottom: 12 }}>
                    {PROFILE_ITEM_KEYS.map(k => (
                      <label key={k} className="ab-field" style={{ minWidth: 0 }}>
                        <span className="ab-field__label">{t({ id: `importacoes.adapter.profileItems.${k}` })}</span>
                        <input className="ab-input" value={profileItems[k]} maxLength={k === 'tag' ? 3 : 4}
                          placeholder={PROFILE_ITEM_HINTS[k]}
                          onChange={e => setProfileItems(p => ({ ...p, [k]: e.target.value }))} />
                      </label>
                    ))}
                  </div>
                  <div>
                    <button className="cat-btn primary" type="button" disabled={profileSaving || !profileName.trim()} onClick={handleCreateProfile}>
                      {profileSaving ? t({ id: 'importacoes.adapter.profileSaving' }) : t({ id: 'importacoes.adapter.profileSave' })}
                    </button>
                  </div>
                </div>
              )}
              <p className="imp-note" style={{ margin: 0 }}>
                {t({ id: 'importacoes.adapter.explanation' })}
              </p>
            </div>
          </div>

  );
}
