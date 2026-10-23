// Ajouter des notices : fichier, recherche externe, OAI-PMH, nouvelle source de dépôt, mon catalogue — section de la face Import, sortie d'ImportacoesPage.jsx telle
// quelle (E6, 23/10/2026), avec l'état et les actions qu'elle est seule à lire
// (calculés par @babel/traverse) ; la page lui passe le reste.
// Garde : src/tests/importacoes-sections-montees.test.jsx.
import { useIntl } from 'react-intl';
import { useState } from 'react';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { assertRpcOk } from '../../lib/rpcStatus.js';
import { detectFileKind, ACCEPTED_IMPORT_EXTENSIONS as ACCEPTED_EXTENSIONS } from '../../lib/importFileKind.js';
import { BUCKET, formatDate } from './importacoesOutils.jsx';

// La pastille d'état, la même que celle de la page.
function Pill({ children, variant = 'muted' }) {
  return <span className={`cat-pill ${variant}`}>{children}</span>;
}

export default function ImportAddRecords(p) {
  const { formatMessage: t } = useIntl();
  const {
    adapterEncoding, adapterFormat, adapterProfile, adapterVocabulary, canDeposit, destLibraries,
    initialHash, loadOaiSources, loadRuns, loadSources, newSourceOpen, oaiLoading, oaiSources,
    setMsg, setNewSourceOpen, setUploading, sources, uploading,
  } = p;

  // Origine d'ajout (fusion des 3 ex-circuits) : fichier / busca / oai.
  const [addMode, setAddMode] = useState(['arquivo', 'busca', 'oai'].includes(initialHash) ? initialHash : 'arquivo');

  // ── Arquivo upload state ───────────────────────────────
  const [file, setFile] = useState(null);
  const [sourceId, setSourceId] = useState('');
  const [newSourceName, setNewSourceName] = useState('');

  // 15/09/2026 : la biblio qui DETIENT les livres du depot, si elle est deja
  // admise au reseau. Sinon on la laisse vide : les brouillons naitront « sans
  // bibliotheque » et l'administration reattribuera le lot le jour de
  // l'admission (Catalogacao > Lots > Reattribuer…).
  const [newSourceDest, setNewSourceDest] = useState('');
  const [registeringSource, setRegisteringSource] = useState(false);

  // H21 lot 7 (09/10/2026, IMP-26 f) : « export complet » déclaré au dépôt —
  // sans lui, aucune disparition n'est proposée au retrait. Posé avant le
  // dispatch (fn_import_set_export_complet), jamais après.
  const [exportComplet, setExportComplet] = useState(false);

  // ── Fontes externas search ─────────────────────────────
  const [searchQuery, setSearchQuery] = useState('');
  const [searchSource, setSearchSource] = useState('bn');
  const [searchResults, setSearchResults] = useState([]);
  const [searching, setSearching] = useState(false);

  const fileSources = sources.filter(s => canDeposit || s.source_kind !== 'partner_deposit');

  // ── Upload + dispatch (arquivo circuit) ────────────────
  async function handleUploadAndProcess() {
    if (!file) { setMsg({ text: t({ id: 'importacoes.selectFile' }), kind: 'error' }); return; }
    if (!sourceId) { setMsg({ text: t({ id: 'importacoes.selectSource' }), kind: 'error' }); return; }
    setUploading(true);
    setMsg({ text: t({ id: 'importacoes.sendingFile' }), kind: 'info' });
    try {
      const slug = 'import';
      const path = `partner/manual/${slug}/${new Date().toISOString().slice(0, 10)}/${Date.now()}-${(file.name || 'file').replace(/[^a-zA-Z0-9._-]/g, '_')}`;
      const { error: upErr } = await supabase.storage.from(BUCKET).upload(path, file, { upsert: true });
      if (upErr) throw upErr;

      const { data: createData, error: createErr } = await supabase.rpc('fn_import_create', {
        p_source_id: Number(sourceId),
        p_storage_path: path,
        p_original_filename: file.name,
        p_bucket_id: BUCKET,
        p_mime_type: file.type || 'application/octet-stream',
        p_size_bytes: file.size,
        p_detected_format: detectFileKind(file.name),
      });
      if (createErr) throw createErr;
      assertRpcOk(createData);
      const runId = createData?.run_id;
      if (!runId) throw new Error(t({ id: 'importacoes.noRunId' }));

      // Adaptateur : si l'usager a forcé un axe, on le pose sur le run avant le dispatch.
      //
      // DETTE B15 LEVÉE (31/08/2026). Ces deux appels ne jetaient pas seulement
      // le `ok` : ils ne regardaient RIEN, pas même `error`. Or les deux
      // fonctions LÈVENT sur refus — vérifié en base le 31/08 :
      // coordenador requis, forced_format hors marc/ris/csv/tsv,
      // forced_vocabulary hors unimarc/marc21, profil d'une autre bibliothèque.
      // Le refus repartait donc en silence et le run était dispatché avec
      // l'axe demandé NON POSÉ : l'import tournait sur un autre adaptateur que
      // celui choisi, et personne ne pouvait le savoir avant de lire le résultat.
      //
      // Ce qu'on décide de faire d'un échec : ARRÊTER. Un import muet sur le
      // mauvais adaptateur coûte plus cher qu'un import qui ne part pas. Le
      // `throw` rejoint le catch en bas de la fonction (toast localizeError) ;
      // le run reste créé et non dispatché, donc reprenable.
      if (adapterFormat !== 'auto' || adapterVocabulary !== 'auto' || adapterEncoding !== 'auto') {
        const { data: overridesData, error: overridesErr } = await supabase.rpc('fn_import_set_adapter_overrides', {
          p_run_id: Number(runId),
          p_forced_format: adapterFormat === 'auto' ? null : adapterFormat,
          p_forced_vocabulary: adapterVocabulary === 'auto' ? null : adapterVocabulary,
          p_forced_encoding: adapterEncoding === 'auto' ? null : adapterEncoding,
        });
        if (overridesErr) throw overridesErr;
        assertRpcOk(overridesData);
      }
      // Adaptateur (axe Perfil) : associe le profil choisi au run. Depuis H15
      // (26/09/2026) les overrides FUSIONNENT : l'ordre n'importe plus.
      if (adapterProfile) {
        const { data: profileData, error: profileErr } = await supabase.rpc('fn_import_set_profile', { p_run_id: Number(runId), p_profile_id: Number(adapterProfile) });
        if (profileErr) throw profileErr;
        assertRpcOk(profileData);
      }
      // H21 lot 7 : l'export complet se déclare AVANT le dispatch (la base le
      // refuse ensuite) ; un refus arrête tout, comme les réglages ci-dessus.
      if (exportComplet) {
        const { data: completData, error: completErr } = await supabase.rpc('fn_import_set_export_complet', {
          p_run_id: Number(runId), p_export_complet: true,
        });
        if (completErr) throw completErr;
        assertRpcOk(completData);
      }
      setMsg({ text: t({ id: 'importacoes.runCreatedDispatching' }, { id: runId }), kind: 'info' });
      // DOC-RPC-4. Cet appel ignorait `error` autant que ses deux voisins, mais
      // il rate DAVANTAGE : `fn_import_dispatch` lève quatre refus (accès
      // bibliothécaire, coordenador requis, run introuvable, run d'une autre
      // bibliothèque) puis relaie `ingest.fn_dispatch_partner_catalog_import`,
      // qui en lève deux de plus — dont « secret d'import absent du vault ».
      // Six refus au total, aucun `ok:false` : le relais rend `{ok:true, …}` ou
      // il lève. Sans cette ligne, l'écran affichait « run expédié » dans les
      // six cas, et l'import n'avait pas commencé.
      const { data: dispatchData, error: dispatchErr } = await supabase.rpc('fn_import_dispatch', { p_run_id: Number(runId) });
      if (dispatchErr) throw dispatchErr;
      assertRpcOk(dispatchData);

      setMsg({ text: t({ id: 'importacoes.runDispatched' }, { id: runId }), kind: 'ok' });
      setFile(null);
      setExportComplet(false);
      await loadRuns();
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally { setUploading(false); }
  }

  // ── Nouvelle source de dépôt (sans entité catalog_partners) ────────────
  // La RPC est idempotente : created=false = le nom existait déjà, on
  // sélectionne la source retrouvée plutôt que d'en signaler l'échec.
  async function handleRegisterDepositSource() {
    const name = newSourceName.trim();
    if (!name) return;
    setRegisteringSource(true);
    try {
      const { data, error } = await supabase.rpc('fn_import_register_deposit_source', {
        p_partner_name: name,
        p_destination_library_id: newSourceDest || null,
      });
      if (error) throw error;
      assertRpcOk(data);
      await loadSources();
      if (data?.source_id) setSourceId(String(data.source_id));
      setMsg({
        text: t({ id: data?.created ? 'importacoes.deposit.registered' : 'importacoes.deposit.alreadyExists' }, { name }),
        kind: 'ok',
      });
      setNewSourceName('');
      setNewSourceDest('');
      setNewSourceOpen(false);
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally { setRegisteringSource(false); }
  }

  // ── Mon propre catalogue (own_catalog) ──────────────────────────────────
  // La voie qui reste a la coordination : fn_import_own_source retrouve ou
  // cree la source own_catalog de la biblio active (une seule, idempotente).
  async function handleOwnSource() {
    setRegisteringSource(true);
    try {
      const { data, error } = await supabase.rpc('fn_import_own_source');
      if (error) throw error;
      assertRpcOk(data);
      await loadSources();
      if (data?.source_id) setSourceId(String(data.source_id));
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally { setRegisteringSource(false); }
  }

  // ── Fontes externas search (ISBN lookup via EF) ────────
  async function handleSearch() {
    if (!searchQuery.trim()) return;
    setSearching(true);
    setSearchResults([]);
    try {
      const { data } = await supabase.functions.invoke('catalog_metadata_lookup', {
        body: { isbn: searchQuery.trim() },
      });
      if (data?.candidates?.length) {
        setSearchResults(data.candidates);
        setMsg({ text: t({ id: 'importacoes.isbnResults' }, { count: data.candidates.length, isbn: searchQuery.trim() }), kind: 'ok' });
      } else {
        setMsg({ text: t({ id: 'importacoes.isbnNotFound' }), kind: 'info' });
      }
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally { setSearching(false); }
  }

  // ── Trigger OAI harvest (manual) ────────────────────────
  async function handleHarvestOai(sourceId) {
    setMsg({ text: t({ id: 'importacoes.oai.harvesting' }), kind: 'info' });
    try {
      const { data, error } = await supabase.rpc('fn_import_harvest_oai', {
        p_source_id: Number(sourceId),
      });
      if (error) throw error;
      assertRpcOk(data);
      if (data?.note) {
        setMsg({ text: data.note, kind: 'info' });
      } else {
        setMsg({ text: t({ id: 'importacoes.oai.harvestStarted' }, { id: data?.run_id || '?' }), kind: 'ok' });
      }
      await loadOaiSources();
      await loadRuns();
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    }
  }

  // ── Ingest candidate → staging_row (Lot 2) ────────────
  async function handleIngestCandidate(candidate) {
    setMsg({ text: t({ id: 'importacoes.fontes.importingCandidate' }), kind: 'info' });
    try {
      const { error } = await supabase.rpc('fn_import_ingest_candidate', {
        p_candidate: candidate,
      });
      if (error) throw error;
      setMsg({ text: t({ id: 'importacoes.fontes.candidateImported' }, { title: candidate.title || '—' }), kind: 'ok' });
      await loadRuns();
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    }
  }

  return (
    <div className="imp-sheet" style={{ marginBottom: 18 }}>
            <div className="imp-sheet__head">
              <span className="imp-sheet__title">{t({ id: 'importacoes.add.title' })}</span>
            </div>
            <div className="imp-sheet__body">
              <div className="imp-seg" role="group" style={{ marginBottom: 14 }}>
                {['arquivo', 'busca', 'oai'].map(m => (
                  <button key={m} className={addMode === m ? 'on' : ''} onClick={() => setAddMode(m)}>
                    {t({ id: 'importacoes.add.mode.' + m })}
                  </button>
                ))}
              </div>

              {/* Origine : fichier — upload unifié, toute source, via fn_import_create */}
              {addMode === 'arquivo' && (
                <>
                  <div className="imp-row3" style={{ marginBottom: 14 }}>
                    <div className="ab-field">
                      <label className="ab-field__label">{t({ id: 'importacoes.file.source' })}</label>
                      <select className="ab-select" value={sourceId} onChange={e => setSourceId(e.target.value)}>
                        <option value="">{t({ id: 'importacoes.reception.selectSourcePlaceholder' })}</option>
                        {fileSources.map(s => <option key={s.id} value={String(s.id)}>{s.partner_name}</option>)}
                      </select>
                      {!fileSources.some(s => s.source_kind === 'own_catalog') && (
                        <button type="button" className="imp-linkbtn" onClick={handleOwnSource} disabled={registeringSource}>
                          + {t({ id: 'importacoes.deposit.ownCatalog' })}
                        </button>
                      )}
                      {canDeposit && !newSourceOpen && (
                        <button type="button" className="imp-linkbtn" onClick={() => setNewSourceOpen(true)}>
                          + {t({ id: 'importacoes.deposit.newPartner' })}
                        </button>
                      )}
                      {!canDeposit && (
                        <span className="imp-note" style={{ display: 'block', marginTop: 4 }}>
                          {t({ id: 'importacoes.deposit.adminOnlyNote' })}
                        </span>
                      )}
                      {newSourceOpen && (
                        <div className="imp-newsource">
                          <input className="ab-input" value={newSourceName}
                            onChange={e => setNewSourceName(e.target.value)}
                            placeholder={t({ id: 'importacoes.deposit.partnerPlaceholder' })}
                            onKeyDown={e => { if (e.key === 'Enter') handleRegisterDepositSource(); }} />
                          <select className="ab-input" value={newSourceDest}
                            onChange={e => setNewSourceDest(e.target.value)}
                            aria-label={t({ id: 'importacoes.deposit.destinationLibrary' })}
                            title={t({ id: 'importacoes.deposit.destinationLibrary' })}>
                            <option value="">{t({ id: 'importacoes.deposit.destinationLibraryNone' })}</option>
                            {destLibraries.map(l => <option key={l.id} value={l.id}>{l.name}</option>)}
                          </select>
                          <button type="button" className="cat-btn secondary imp-newsource__ok"
                            onClick={handleRegisterDepositSource}
                            disabled={registeringSource || !newSourceName.trim()}>
                            {registeringSource ? t({ id: 'common.saving' }) : t({ id: 'common.add' })}
                          </button>
                          <button type="button" className="imp-linkbtn"
                            onClick={() => { setNewSourceOpen(false); setNewSourceName(''); setNewSourceDest(''); }}>
                            {t({ id: 'common.cancel' })}
                          </button>
                        </div>
                      )}
                    </div>
                    <div className="ab-field" style={{ gridColumn: 'span 2' }}>
                      <label className="ab-field__label">{t({ id: 'importacoes.arquivo.fileLabel' })}</label>
                      <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                        <label className="cat-btn secondary" style={{ cursor: 'pointer', fontSize: '.85rem' }}>
                          {t({ id: 'importacoes.reception.chooseFile' })}
                          <input type="file" accept={ACCEPTED_EXTENSIONS} onChange={e => setFile(e.target.files?.[0] || null)} style={{ display: 'none' }} />
                        </label>
                        {file && <span style={{ fontSize: '.85rem', color: 'var(--brand-muted)' }}>{file.name} ({(file.size / 1024).toFixed(0)} KB)</span>}
                      </div>
                    </div>
                  </div>
                  <label className="imp-note" data-testid="import-export-complet"
                    style={{ display: 'flex', gap: 8, alignItems: 'flex-start', margin: '0 0 10px', cursor: 'pointer' }}>
                    <input type="checkbox" checked={exportComplet} disabled={uploading}
                      onChange={e => setExportComplet(e.target.checked)} style={{ marginTop: 3 }} />
                    <span>
                      <strong>{t({ id: 'importacoes.exportComplet.label' })}</strong>
                      <br />{t({ id: 'importacoes.exportComplet.hint' })}
                    </span>
                  </label>
                  <button className="cat-btn primary" onClick={handleUploadAndProcess} disabled={uploading || !file || !sourceId}>
                    {uploading ? t({ id: 'importacoes.uploading' }) : t({ id: 'importacoes.arquivo.uploadAndProcess' })}
                  </button>
                </>
              )}

              {/* Origine : recherche externe (BN / WorldCat) */}
              {addMode === 'busca' && (
                <>
                  <div className="imp-row3" style={{ marginBottom: 12 }}>
                    <div className="ab-field">
                      <label className="ab-field__label">{t({ id: 'importacoes.fontes.sourceLabel' })}</label>
                      <select className="ab-select" value={searchSource} onChange={e => setSearchSource(e.target.value)}>
                        <option value="bn">Biblioteca Nacional</option>
                        <option value="worldcat">WorldCat / OCLC</option>
                      </select>
                    </div>
                    <div className="ab-field" style={{ gridColumn: 'span 2' }}>
                      <label className="ab-field__label">{t({ id: 'importacoes.fontes.searchLabel' })}</label>
                      <div style={{ display: 'flex', gap: 8 }}>
                        <input className="ab-input" value={searchQuery} onChange={e => setSearchQuery(e.target.value)}
                          placeholder="9788575591360"
                          onKeyDown={e => { if (e.key === 'Enter') handleSearch(); }} />
                        <button className="cat-btn primary" onClick={handleSearch} disabled={searching} style={{ flexShrink: 0 }}>
                          {searching ? t({ id: 'common.searching' }) : t({ id: 'importacoes.fontes.search' })}
                        </button>
                      </div>
                    </div>
                  </div>
                  {searchResults.length > 0 && (
                    <table className="imp-map">
                      <thead><tr>
                        <th>{t({ id: 'importacoes.fontes.result' })}</th>
                        <th>{t({ id: 'importacoes.fontes.author' })}</th>
                        <th>{t({ id: 'importacoes.fontes.format' })}</th>
                        <th></th>
                      </tr></thead>
                      <tbody>
                        {searchResults.map((c, i) => (
                          <tr key={i}>
                            <td style={{ fontWeight: 600 }}>{c.title}</td>
                            <td style={{ color: 'var(--brand-muted)' }}>{c.responsibility_statement || c.contributors?.[0]?.label || '—'}</td>
                            <td><Pill>{c.source || '—'}</Pill></td>
                            <td>
                              <button className="cat-btn primary" style={{ fontSize: '.78rem', padding: '4px 10px', minHeight: 0 }}
                                onClick={() => handleIngestCandidate(c)}>
                                {t({ id: 'importacoes.fontes.importCandidate' })}
                              </button>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  )}
                </>
              )}

              {/* Origine : moisson OAI-PMH */}
              {addMode === 'oai' && (
                <>
                  <p className="imp-note" style={{ marginBottom: 12 }}>{t({ id: 'importacoes.oai.desc' })}</p>
                  {oaiLoading && <p className="imp-note">{t({ id: 'common.loading' })}</p>}
                  {!oaiLoading && oaiSources.length === 0 && (
                    <p className="imp-note">{t({ id: 'importacoes.oai.noSources' })}</p>
                  )}
                  {oaiSources.length > 0 && (
                    <div className="imp-partners">
                      {oaiSources.map(s => (
                        <div key={s.id} className="imp-pcard">
                          <div className="imp-pcard__top">
                            <h4>{s.partner_name}</h4>
                            <Pill variant={s.harvest_status === 'idle' ? 'muted' : s.harvest_status === 'in_progress' ? 'info' : s.harvest_status === 'error' ? 'danger' : s.harvest_status === 'completed' ? 'ok' : 'warn'}>
                              {t({ id: `importacoes.oai.status.${s.harvest_status || 'idle'}` })}
                            </Pill>
                          </div>
                          <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)', marginBottom: 6 }}>
                            {s.oai_endpoint_url}
                            {s.oai_set && <span> — set: {s.oai_set}</span>}
                          </div>
                          <div className="imp-flags" style={{ marginBottom: 8 }}>
                            <span className="imp-flagchip imp-flagchip--on">{s.oai_metadata_prefix || 'marcxml'}</span>
                            <span className="imp-flagchip">{t({ id: 'importacoes.oai.lotsPerCycle' }, { n: s.lots_per_cycle || 5 })}</span>
                            {/* import_enabled decide desormais des DEUX chemins : le cron
                                hebdomadaire et le bouton ci-dessous. Tant qu'elle n'etait lue
                                par personne, l'afficher n'aurait rien voulu dire ; maintenant
                                elle explique pourquoi le bouton est eteint. Meme cle que la
                                liste des Fontes : le meme mot pour la meme chose. */}
                            <span className={`imp-flagchip ${s.import_enabled ? 'imp-flagchip--on' : 'imp-flagchip--off'}`}>
                              {t({ id: 'importacoes.fontes.flag.import' })}
                            </span>
                            {s.total_records_harvested > 0 && (
                              <span className="imp-flagchip imp-flagchip--on">{t({ id: 'importacoes.oai.totalHarvested' }, { n: s.total_records_harvested })}</span>
                            )}
                            {s.last_harvest_at && (
                              <span className="imp-flagchip">{t({ id: 'importacoes.oai.lastHarvest' })} {formatDate(s.last_harvest_at)}</span>
                            )}
                          </div>
                          {s.last_error && (
                            <p style={{ fontSize: '.8rem', color: 'var(--color-danger)', margin: '0 0 8px' }}>{s.last_error}</p>
                          )}
                          {/* Une source decochee est refusee par fn_import_harvest_oai
                              (HINT error.oai.sourceDisabled). L'ecran n'a pas a proposer un
                              geste que la base rejettera : on eteint le bouton, la pastille
                              ci-dessus dit pourquoi. La RPC reste l'autorite — ce grisage est
                              une politesse, pas une garde. */}
                          {/* 04/09/2026 : moissonner est un geste de reseau (fn_import_harvest_oai
                              admin seulement). La coordination voit l'etat, pas le bouton. */}
                          {canDeposit ? (
                            <button className="cat-btn primary" style={{ fontSize: '.82rem', padding: '5px 14px', minHeight: 0 }}
                              onClick={() => handleHarvestOai(s.id)}
                              title={!s.import_enabled ? t({ id: 'error.oai.sourceDisabled' }) : undefined}
                              disabled={s.harvest_status === 'in_progress' || !s.import_enabled}>
                              {s.harvest_status === 'in_progress' ? t({ id: 'importacoes.oai.harvesting' }) : t({ id: 'importacoes.oai.harvestNow' })}
                            </button>
                          ) : (
                            <span className="imp-note">{t({ id: 'importacoes.oai.adminOnlyNote' })}</span>
                          )}
                        </div>
                      ))}
                    </div>
                  )}
                </>
              )}
            </div>
          </div>

  );
}
