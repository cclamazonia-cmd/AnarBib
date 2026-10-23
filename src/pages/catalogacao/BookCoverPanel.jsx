// En-tête « couverture » du formulaire de notice — choisir une image, galerie
// multi-sources (capas P2), page 1 du PDF, retrait, et la colonne de recherche
// catalographique (LookupPanel, applyCandidate) — sorti de BookDraftForm.jsx tel
// quel (E6, 23/10/2026), avec l'état et les actions qu'il est seul à lire
// (calculés par @babel/traverse). L'envoi du fichier choisi reste à
// l'enregistrement (uploadCover, useNoticePersistance.js). Il ne modifie le
// formulaire que par les fonctions que la page lui passe (set, setForm…).
// Garde : src/tests/notice-couverture-montee.test.jsx.
import { useIntl } from 'react-intl';
import { useState } from 'react';
import { supabase, SUPABASE_URL } from '@/lib/supabase';
import LookupPanel from './LookupPanel';
import { localizeError } from '@/lib/localizeError';
import { writeCoverThumb, removeCoverThumb, cheminCapaNeuf, nomCapaNeuf } from '@/lib/coverThumbs';
import { rendrePage1, canvasEnJpeg } from '@/lib/capaPdf';
import { messageRechercheCapas, accordEdition, parIsbn, etiquetteCandidate, ordonnerCandidates } from '@/lib/coverSources';
import { inferContributorRole, autoMatchContributors, provenanceFromCandidate } from '@/lib/catalogacao/bookDraft';

export default function BookCoverPanel(p) {
  const { formatMessage: t } = useIntl();
  const {
    confirmSaved, contributors, coverCandidates, coverFile, coverPreviewUrl, coverUploading,
    digitalResources, draftState, f, set, setContributors, setCoverCandidates, setCoverFile,
    setCoverPreviewUrl, setDraftState, setForm, setMany, setMsg, uploadCover,
  } = p;

  // ── Cover lookup state (capas P2) ──────────────────────
  const [coverLookupLoading, setCoverLookupLoading] = useState(false);

  const [coverStoring, setCoverStoring] = useState(''); // fullUrl en cours d'enregistrement

  const [coverPdfBusy, setCoverPdfBusy] = useState(false); // generation capa depuis page 1 PDF

  // ── Cover preview URL ──────────────────────────────────
  const coverDisplayUrl = coverPreviewUrl
    || (f('cover_object_path') ? `${SUPABASE_URL}/storage/v1/object/public/covers/${f('cover_object_path')}` : '');

  // Capas : l'édition que désigne l'ISBN de chaque candidate, confrontée à la
  // notice (lib/coverSources.js). Un écart est dit au-dessus de la galerie et sur
  // la vignette : la candidate n'est plus présentée comme certaine. Vu le 27/09 :
  // une notice Ramparts Press 1971 portait l'ISBN de l'édition AK Press de 2004.
  const accordsCapas = coverCandidates.map((c) => accordEdition(c, { ano: f('ano'), editora: f('editora'), volume: f('volume') }));

  // Les deux avertissements parlent de l'ISBN : on ne les tire que des candidates
  // trouvées par l'ISBN ; celles du titre ont leur étiquette, sous la vignette.
  const ecartCapas = accordsCapas.find((a, i) => parIsbn(coverCandidates[i]) && a?.statut === 'ecart') || null;

  // Notice d'un volume : l'ISBN d'un ensemble peut mener à la couverture d'un autre volume.
  const volumeCapas = ecartCapas ? null : (accordsCapas.find((a, i) => parIsbn(coverCandidates[i]) && a?.statut === 'volume') || null);

  const etiquettesCapas = coverCandidates.map((c, i) => etiquetteCandidate(c, accordsCapas[i]));

  async function applyCandidate(candidate) {
    if (!candidate) return;
    const updates = {};
    if (candidate.title && !f('titulo')) updates.titulo = candidate.title;
    if (candidate.subtitle && !f('subtitulo')) updates.subtitulo = candidate.subtitle;
    if (candidate.edition && !f('edicao')) updates.edicao = candidate.edition;
    if (candidate.publisher && !f('editora')) updates.editora = candidate.publisher;
    if (candidate.place && !f('local_publicacao')) updates.local_publicacao = candidate.place;
    if (candidate.year && !f('ano')) updates.ano = candidate.year;
    if (candidate.language && !f('idioma')) updates.idioma = candidate.language;
    if (candidate.series && !f('colecao')) updates.colecao = candidate.series;
    if (candidate.isbn?.length && !f('isbn')) updates.isbn = candidate.isbn[0];
    if (candidate.issn?.length && !f('issn')) updates.issn = candidate.issn[0];
    if (candidate.subjects?.length && !f('subjects')) updates.subjects = candidate.subjects.join(' ; ');
    if (candidate.classification?.length && !f('cdd')) updates.cdd = candidate.classification[0];
    if (candidate.extent) {
      const pageMatch = candidate.extent.match(/(\d+)\s*p/);
      if (pageMatch && !f('paginas')) updates.paginas = pageMatch[1];
    }
    // Responsibility → autor + contributors list
    if (candidate.contributors?.length && !f('autor')) {
      updates.autor = candidate.contributors.map(c => c.label).join(' ; ');
      // Also populate the contributors UI
      const hasNamedContributors = contributors.some(c => c.name.trim());
      if (!hasNamedContributors) {
        let newContribs = candidate.contributors.map((c, i) => ({
          position: i + 1,
          name: c.label || '',
          role: inferContributorRole(c.role),
          is_primary: i === 0,
          author_id: null,
          author_label: '',
        }));
        // Auto-link contributors to existing authors (VIAF from MARC + name match)
        try {
          newContribs = await autoMatchContributors(newContribs, candidate.contributors, supabase);
          const linked = newContribs.filter(c => c.author_id).length;
          if (linked > 0) {
            setMsg({ text: t({ id: 'catalogacao.authlink.autoLinked' }, { count: linked }), kind: 'ok' });
          }
        } catch { /* auto-match is best-effort */ }
        setContributors(newContribs);
      }
    } else if (candidate.responsibility_statement && !f('autor')) {
      updates.autor = candidate.responsibility_statement;
    }
    // Notes
    if (candidate.notes?.length && !f('notas')) {
      updates.notas = candidate.notes.join('\n');
    }
    // D'où vient la notice (« DBNL — https://… », « BnF 12345 ») : c'était le
    // seul apport du bouton BN Brasil retiré le 13/10, étendu à toutes les sources.
    if (!f('provenance_note')) {
      const provenance = provenanceFromCandidate(candidate);
      if (provenance) updates.provenance_note = provenance;
    }

    setMany(updates);
    if (draftState === 'saved' || draftState === 'ready') setDraftState('dirty');
    setMsg({ text: t({ id: 'catalogacao.msg.candidateApplied' }, { title: candidate.title }), kind: 'ok' });
  }

  // ═══════════════════════════════════════════════════════
  // Cover upload
  // ═══════════════════════════════════════════════════════

  function handleCoverFileChange(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    setCoverFile(file);
    // Local preview
    const url = URL.createObjectURL(file);
    setCoverPreviewUrl(url);
  }

  // ── Cover lookup (capas P2) : galerie multi-sources via EF cover_lookup ──
  async function runCoverLookup() {
    const isbn = (f('isbn') || '').replace(/[^0-9Xx]/g, '');
    const title = f('titulo') || '';
    const author = f('autor') || '';
    const url = f('digital_native_url') || '';
    if (!isbn && !title && !url) {
      setMsg({ text: t({ id: 'catalogacao.ui.coverLookupNeed' }), kind: 'error' });
      return;
    }
    setCoverLookupLoading(true);
    setCoverCandidates([]);
    try {
      const { data, error } = await supabase.functions.invoke('cover_lookup', {
        // idioma : la recherche par titre fait passer devant l'édition dans la langue de la notice.
        body: { action: 'search', isbn: isbn || null, title: title || null, author: author || null, idioma: f('idioma') || null, url: url || null },
      });
      if (error && !data) throw error;
      if (!data?.ok) throw new Error(data?.error || 'lookup failed');
      // ISBN d'abord, puis la plus probable des éditions trouvées par le titre.
      setCoverCandidates(ordonnerCandidates(data.candidates, { ano: f('ano'), editora: f('editora'), volume: f('volume') }));
      // Le bilan des sources dit ce qui a ÉCHOUÉ : une voie en panne ne doit
      // plus passer pour un livre introuvable (cf. lib/coverSources.js).
      const avis = messageRechercheCapas(data);
      if (avis) setMsg({ text: t({ id: avis.id }, avis.values), kind: avis.kind });
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.ui.coverUploadError' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setCoverLookupLoading(false);
    }
  }

  // Selection d'une vignette -> telechargement serveur vers le bucket (CAT-C3).
  async function selectCoverCandidate(candidate) {
    const stableKey = f('bib_ref') || f('id');
    if (!stableKey) {
      setMsg({ text: t({ id: 'catalogacao.ui.coverSaveFirst' }), kind: 'error' });
      return;
    }
    setCoverStoring(candidate.fullUrl);
    try {
      const { data, error } = await supabase.functions.invoke('cover_lookup', {
        body: {
          action: 'store',
          imageUrl: candidate.fullUrl,
          key: stableKey,
          // Un nom neuf, comme l'écran de revue : jamais par-dessus la capa
          // en place (cache d'une heure sur une adresse réécrite, 28/09/2026).
          nom: nomCapaNeuf(),
          source: candidate.source || null,
          license: candidate.license || null,
        },
      });
      if (error && !data) throw error;
      if (!data?.ok) throw new Error(data?.error || 'store failed');
      // L'EF a récupéré l'image côté serveur (anti-tracking, spec §4.3) : le
      // navigateur n'a pas les octets. On les relit par l'API Storage — jamais
      // depuis la source tierce, et jamais par l'URL publique (cf. coverThumbs).
      await writeCoverThumb(data.storagePath);
      set('cover_object_path', data.storagePath);
      set('cover_source', data.source || candidate.source || '');
      set('cover_license', data.license || candidate.license || '');
      setCoverPreviewUrl('');
      setCoverCandidates([]);
      confirmSaved(t({ id: 'catalogacao.ui.coverSaved' }));
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.ui.coverUploadError' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setCoverStoring('');
    }
  }

  // Ressource PDF liee a la fiche (pour la capa page 1).
  function findPdfResource() {
    return (digitalResources || []).find(
      (r) => r.mime_type === 'application/pdf'
        || /\.pdf$/i.test(r.storage_path || '')
        || /\.pdf(\?|$)/i.test(r.source_url || ''),
    ) || null;
  }

  // Capa P3 (cote client) : rend la page 1 du PDF sur un canvas -> upload bucket.
  async function generateCoverFromPdf() {
    const stableKey = f('bib_ref') || f('id');
    if (!stableKey) {
      setMsg({ text: t({ id: 'catalogacao.ui.coverSaveFirst' }), kind: 'error' });
      return;
    }
    const resource = findPdfResource();
    if (!resource) {
      setMsg({ text: t({ id: 'catalogacao.ui.coverPdfNone' }), kind: 'error' });
      return;
    }
    setCoverPdfBusy(true);
    try {
      // 1. Recuperer les octets du PDF (storage de preference, sinon URL source).
      let arrayBuffer;
      if (resource.storage_bucket && resource.storage_path) {
        const { data, error } = await supabase.storage.from(resource.storage_bucket).download(resource.storage_path);
        if (error) throw error;
        arrayBuffer = await data.arrayBuffer();
      } else if (resource.source_url) {
        // Anti-pistage (spec capas §4.3) : le PDF externe est récupéré CÔTÉ
        // SERVEUR par cover_lookup ; le navigateur qui catalogue ne contacte
        // jamais la source (il le faisait jusqu'au 27/09/2026).
        const { data, error } = await supabase.functions.invoke('cover_lookup', {
          body: { action: 'pdf', url: resource.source_url },
        });
        if (error) throw error;
        if (!(data instanceof Blob)) throw new Error(data?.error || 'pdf fetch failed');
        arrayBuffer = await data.arrayBuffer();
      } else {
        throw new Error('no source');
      }

      // 2. Rendre la page 1 sur un canvas hors-ecran (meme rendu que le lot du Painel).
      const canvas = await rendrePage1(arrayBuffer);

      // 3. Canvas -> blob -> upload bucket covers (blob local, pas de CORS).
      const blob = await canvasEnJpeg(canvas);
      // Adresse neuve, sans upsert : même règle que le fichier envoyé (28/09/2026).
      const storagePath = cheminCapaNeuf(stableKey, 'jpg');
      const { error: upErr } = await supabase.storage.from('covers').upload(storagePath, blob, { upsert: false, contentType: 'image/jpeg' });
      if (upErr) throw upErr;
      // Le canvas de la page 1 est encore là : on en tire le dérivé directement.
      await writeCoverThumb(storagePath, canvas);

      set('cover_object_path', storagePath);
      set('cover_source', 'pdf_page1');
      set('cover_license', '');
      setCoverPreviewUrl('');
      confirmSaved(t({ id: 'catalogacao.ui.coverSaved' }));
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.ui.coverUploadError' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setCoverPdfBusy(false);
    }
  }

  // P2 : retirer la couverture (efface les champs + supprime l'objet Storage).
  // Par notice : ne touche jamais la cover d'une autre édition (chemin par bib_ref/id).
  async function removeCover() {
    const path = f('cover_object_path');
    try {
      if (path) {
        await supabase.storage.from('covers').remove([path]);
        await removeCoverThumb(path);
      }
      set('cover_object_path', '');
      set('cover_source', '');
      set('cover_license', '');
      setCoverPreviewUrl('');
      setCoverFile(null);
      setCoverCandidates([]);
      if (draftState === 'saved' || draftState === 'ready') setDraftState('dirty');
      confirmSaved(t({ id: 'catalogacao.ui.coverRemoved' }));
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.ui.coverUploadError' }, { message: localizeError(err, t) }), kind: 'error' });
    }
  }

  return (
    <div style={{ display: 'flex', gap: 16, marginBottom: 18, flexWrap: 'wrap', alignItems: 'flex-start' }}>
          <div className="ab-cover">
            <div className={`ab-cover__frame${coverUploading ? ' loading' : coverDisplayUrl ? ' found' : ''}`}>
              {coverDisplayUrl ? (
                <img src={coverDisplayUrl} alt={t({id:'catalogacao.ui.coverAlt'})} />
              ) : (
                t({id:'catalogacao.ui.noCover'})
              )}
            </div>
            <button type="button" className="ab-button ab-button--mini" style={{ width: '100%', marginTop: 8 }}
              onClick={runCoverLookup} disabled={coverLookupLoading}>
              {coverLookupLoading ? t({id:'catalogacao.ui.coverSearching'}) : t({id:'catalogacao.ui.coverSearch'})}
            </button>
            {findPdfResource() && (
              <button type="button" className="ab-button ab-button--mini" style={{ width: '100%', marginTop: 4 }}
                onClick={generateCoverFromPdf} disabled={coverPdfBusy || !(f('bib_ref') || f('id'))}>
                {coverPdfBusy ? t({id:'catalogacao.ui.coverUploading'}) : t({id:'catalogacao.ui.coverPdfPage1'})}
              </button>
            )}
            <label className="ab-button ab-button--mini" style={{ display: 'block', textAlign: 'center', marginTop: 4, cursor: 'pointer', width: '100%' }}>
              {t({id:'catalogacao.ui.chooseCover'})}
              <input type="file" accept="image/*" onChange={handleCoverFileChange} style={{ display: 'none' }} />
            </label>
            {(f('cover_object_path') || coverPreviewUrl) && (
              <button type="button" className="ab-button ab-button--danger ab-button--mini" style={{ width: '100%', marginTop: 4 }}
                onClick={removeCover} disabled={coverUploading}>
                {t({id:'catalogacao.ui.coverRemove'})}
              </button>
            )}
            {coverFile && (
              <button type="button" className="ab-button ab-button--mini" style={{ width: '100%', marginTop: 4 }}
                onClick={uploadCover} disabled={coverUploading || !(f('bib_ref') || f('id'))}>
                {coverUploading ? t({id:'catalogacao.ui.coverUploading'}) : t({id:'catalogacao.ui.coverUploadBtn'})}
              </button>
            )}
            {coverFile && <div style={{ fontSize: '.68rem', color: 'var(--brand-muted, #aaa)', marginTop: 3, wordBreak: 'break-all' }}>{coverFile.name}</div>}
            {coverFile && !(f('bib_ref') || f('id')) && (
              <div style={{ fontSize: '.68rem', color: '#fbbf24', marginTop: 3 }}>{t({id:'catalogacao.ui.coverSaveFirst'})}</div>
            )}
          </div>

          {/* ── Lookup panel (next to cover) ──────────── */}
          {/* #fix-mobile (18/07) : minWidth fixe = plancher absolu qui ignore
              flexWrap sur les petits Android (320-360px) -> debordement.
              min() garde le plancher tant qu'il y a la place, jamais au-dela. */}
          <div style={{ flex: 1, minWidth: 'min(280px, 100%)' }}>
            {/* Cover candidate gallery (capas P2) */}
            {coverCandidates.length > 0 && (
              <div style={{ marginBottom: 10, padding: 10, borderRadius: 8, background: 'rgba(0,0,0,.15)', border: '1px solid rgba(255,255,255,.08)' }}>
                <div style={{ fontSize: '.75rem', fontWeight: 700, marginBottom: 6 }}>{t({id:'catalogacao.ui.coverGalleryTitle'})}</div>
                {ecartCapas && (
                  <div role="alert" style={{ fontSize: '.72rem', lineHeight: 1.4, color: '#fbbf24', marginBottom: 8 }}>
                    {t({ id: 'catalogacao.ui.coverIsbnEcart' }, { trouvee: ecartCapas.trouvee || '?', notice: ecartCapas.notice || '?' })}
                  </div>
                )}
                {volumeCapas && (
                  <div role="alert" style={{ fontSize: '.72rem', lineHeight: 1.4, color: '#fbbf24', marginBottom: 8 }}>
                    {t({ id: 'catalogacao.ui.coverIsbnVolume' }, { volume: volumeCapas.volume })}
                  </div>
                )}
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                  {/* `label` = ce que la source dit avoir trouvé (titre, auteur·rices,
                      année). Sur une correspondance par titre, elle est FLOUE : Open
                      Library propose volontiers un autre ouvrage du même auteur. C'est
                      ce libellé qui permet de l'écarter avant de le retenir — une capa
                      fausse est pire qu'une capa absente. */}
                  {coverCandidates.map((c, i) => (
                    <button key={i} type="button" title={[c.label, c.source, c.license].filter(Boolean).join(' · ')}
                      onClick={() => selectCoverCandidate(c)} disabled={!!coverStoring}
                      style={{ padding: 0, border: etiquettesCapas[i]?.ton === 'attention' ? '1px solid #fbbf24' : '1px solid rgba(255,255,255,.15)', borderRadius: 6, background: 'rgba(0,0,0,.3)', cursor: coverStoring ? 'default' : 'pointer', width: 72, opacity: coverStoring && coverStoring !== c.fullUrl ? 0.4 : 1 }}>
                      {/* Aperçu rapatrié par l'EF (data: URI), jamais l'URL du
                          tiers : afficher `c.thumbnailUrl` ferait contacter
                          Open Library ou Google par le navigateur qui catalogue,
                          ce que la spec capas exclut (§4.3). Sans aperçu, cadre
                          vide — la candidate reste sélectionnable. */}
                      {c.thumbnailData
                        ? <img src={c.thumbnailData} alt={c.source} style={{ width: '100%', height: 96, objectFit: 'cover', borderRadius: '6px 6px 0 0', display: 'block' }} />
                        : <div aria-hidden="true" style={{ width: '100%', height: 96, borderRadius: '6px 6px 0 0', background: 'rgba(255,255,255,.05)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '1.4rem', opacity: .35 }}>📖</div>}
                      {/* L'édition de la candidate concorde-t-elle avec la notice ?
                          Par l'ISBN comme par le titre ; « Autre édition » pour une
                          couverture d'œuvre (lib/coverSources.js, etiquetteCandidate). */}
                      {etiquettesCapas[i] && (
                        <div style={{ fontSize: '.55rem', fontWeight: 700, padding: '1px 3px 0', textAlign: 'center', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
                          color: etiquettesCapas[i].ton === 'attention' ? '#fbbf24' : etiquettesCapas[i].ton === 'ok' ? '#4ade80' : 'var(--brand-muted, #aaa)' }}>
                          {etiquettesCapas[i].code === 'oeuvre' ? t({ id: 'catalogacao.ui.coverOeuvre' })
                            : etiquettesCapas[i].code === 'verifier' ? t({ id: 'catalogacao.ui.coverIsbnVerifier' })
                            : etiquettesCapas[i].code === 'isbnConcordant' ? t({ id: 'catalogacao.ui.coverIsbnConcordant' })
                            : etiquettesCapas[i].code === 'titreProbable' ? t({ id: 'catalogacao.ui.coverTitreProbable' })
                            : etiquettesCapas[i].code === 'titreSeul' ? t({ id: 'catalogacao.ui.coverTitreSeul' })
                            : t({ id: 'catalogacao.ui.coverIsbnSeul' })}
                        </div>
                      )}
                      <div style={{ fontSize: '.58rem', color: 'var(--brand-muted, #aaa)', padding: '2px 3px', textAlign: 'center', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                        {/* Le titre trouvé plutôt que la source : depuis le retrait de
                            Google, la source est presque toujours la même, alors que
                            savoir QUEL ouvrage a été apparié est ce qui permet de
                            trancher. Le libellé complet reste dans l'infobulle. */}
                        {coverStoring === c.fullUrl ? t({id:'catalogacao.ui.coverUploading'}) : (c.label || c.source)}
                      </div>
                    </button>
                  ))}
                </div>
              </div>
            )}
            {/* ── Recherche catalographique (E6 lot 3 : LookupPanel) ── */}
            <LookupPanel f={f} draftId={f('id')} setMsg={setMsg}
              onIsbnScanned={(isbn) => setForm(prev => ({ ...prev, isbn }))}
              onApplyCandidate={applyCandidate} />
          </div>
        </div>
  );
}
