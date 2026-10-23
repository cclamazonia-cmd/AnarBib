// File de révision : lignes du lot, filtres, sélection, promotion, rapprochement, préparation des mises à jour, rejet, retraitement — section de la face Import, sortie d'ImportacoesPage.jsx telle
// quelle (E6, 23/10/2026), avec l'état et les actions qu'elle est seule à lire
// (calculés par @babel/traverse) ; la page lui passe le reste.
// Garde : src/tests/importacoes-sections-montees.test.jsx.
import { useIntl } from 'react-intl';
import { useState, useMemo } from 'react';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import AppIcon from '@/components/ui/AppIcon';
import { assertRpcOk } from '../../lib/rpcStatus.js';
import RunEncodingPanel from './RunEncodingPanel.jsx';
import RunCoveragePanel from './RunCoveragePanel.jsx';
import RunRetraitsPanel from './RunRetraitsPanel.jsx';
import ExemplairesDuFichier from './ExemplairesDuFichier.jsx';
import { resumeVerdicts } from '../../lib/importItemVerdicts.js';
import { exemplairesPreparables, pagesParExemplaires, pagesDePromotion, pagesDePreparation, cumulerReponses } from '../../lib/importItemUpdates.js';
import { estSelectionnable, resumeComparaison, estPreparable, messagePreparation, DetailComparaison } from './importacoesOutils.jsx';

// La pastille d'état, la même que celle de la page.
function Pill({ children, variant = 'muted' }) {
  return <span className={`cat-pill ${variant}`}>{children}</span>;
}

export default function ImportReviewQueue(p) {
  const { formatMessage: t } = useIntl();
  const {
    canDeposit, detailsOuverts, filaMatchFilter, filaStateFilter, handleRefresh, loadRunRows,
    loadRuns, peutComparer, refreshing, rowLimit, runRows, runRowsLoading, runs, selectedRows,
    selectedRunId, setDetailsOuverts, setFilaMatchFilter, setFilaStateFilter, setMsg, setRowLimit,
    setRunRows, setSelectedRows, setSelectedRunId, sources,
  } = p;

  // ── Fila filters ───────────────────────────────────────
  const [filaSourceFilter, setFilaSourceFilter] = useState('');

  // Retraiter un run (relire le même fichier avec un autre encodage).
  const [reprocessEncoding, setReprocessEncoding] = useState('auto');
  const [reprocessing, setReprocessing] = useState(false);
  const [promotingSel, setPromotingSel] = useState(false);

  const filteredRunRows = useMemo(() => {
    let rows = runRows;
    if (filaStateFilter) {
      rows = rows.filter(r => r.review_status === filaStateFilter);
    }
    if (filaMatchFilter === 'new') {
      rows = rows.filter(r => r.match_status === 'new_record');
    } else if (filaMatchFilter === 'dup') {
      rows = rows.filter(r => ['possible_duplicate', 'matched_book', 'matched_draft'].includes(r.match_status));
    } else if (filaMatchFilter === 'known') {
      // H21 lot 1 : les lignes « Déjà importées » à part. Ce ne sont pas des
      // doublons à vérifier (l'identifiant d'import les a reconnues, sans
      // passe floue) : on les rapproche ou on les rejette en bloc, sans les
      // mêler aux doublons possibles qu'il faut lire un par un.
      rows = rows.filter(r => r.match_status === 'known_record');
    }
    return rows;
  }, [runRows, filaStateFilter, filaMatchFilter]);

  // Run sélectionné + barrière : on ne montre les lignes que si le traitement
  // (parse + matching) est terminé. Sinon « en cours » ou « échoué ».
  const selectedRun = useMemo(() => runs.find(r => r.id === selectedRunId) || null, [runs, selectedRunId]);

  // Les etats ou il n'y a encore RIEN a montrer. Aligne sur le vocabulaire
  // reel de partner_catalog_import_runs_run_status_check et sur le decoupage
  // de api.partner_catalog_import_run_policy_ui (dispatch_pending + processing) :
  // la liste precedente citait 'pending' et 'parsing', qui n'existent dans
  // aucun run, et oubliait 'queued' et 'processing', qui existent vraiment.
  const runProcessing = !!selectedRun && ['uploaded', 'queued', 'processing', 'parsed', 'matching'].includes(selectedRun.run_status);

  const runFailed = !!selectedRun && selectedRun.run_status === 'failed';

  // Lignes à traiter (sélectionnables) : non promues, et dont la décision
  // laisse un geste (estSelectionnable, au niveau du module).
  const selectableIds = useMemo(
    () => filteredRunRows
      .filter(estSelectionnable)
      .map(r => r.id),
    [filteredRunRows]
  );

  const allVisibleSelected = selectableIds.length > 0 && selectableIds.every(id => selectedRows.has(id));

  // Combien de sélectionnées sont des nouveautés promouvables (pour le bouton Criar).
  const selectedNewCount = useMemo(
    () => filteredRunRows.filter(r => selectedRows.has(r.id) && r.match_status === 'new_record' && !r.created_book_draft_id).length,
    [filteredRunRows, selectedRows]
  );

  // Combien de sélectionnées sont des doublons rapprochables (livre publié) — bouton Rapprocher.
  // H21 lot 1 : une ligne « Déjà importée » (known_record) se rapproche de la
  // notice reconnue, comme un doublon (même prédicat que handleReconcileSelected).
  const selectedDupCount = useMemo(
    () => filteredRunRows.filter(r => selectedRows.has(r.id)
      && r.proposed_book_id
      && !r.created_exemplar_draft_id
      && (r.match_status === 'possible_duplicate' || r.match_status === 'matched_book' || r.match_status === 'known_record')).length,
    [filteredRunRows, selectedRows]
  );

  // H21 lot 4 : les lignes sélectionnées que « Préparer la mise à jour » prendra.
  const selectedUpdCount = useMemo(
    () => filteredRunRows.filter(r => selectedRows.has(r.id) && estPreparable(r)).length,
    [filteredRunRows, selectedRows]
  );

  const selectedRunSource = selectedRun ? sources.find(s => s.id === selectedRun.source_id) : null;

  // 04/09/2026 apres-midi : un entrepot OAI moissonne est un fonds tiers de
  // meme nature — meme garde (20260904133000), meme HINT.
  const THIRD_PARTY_KINDS = ['partner_deposit', 'oai_pmh'];

  const depositLocked = !canDeposit && THIRD_PARTY_KINDS.includes(selectedRunSource?.source_kind);

  // ── Retraiter un run : relire le MÊME fichier avec un autre encodage (H15) ──
  // Les autres axes sont ceux EMPLOYÉS au passage précédent (summary.adapter,
  // écrit par l'EF) ; le profil reste posé (les overrides fusionnent). Un run
  // déjà promu en brouillons est refusé par fn_import_dispatch (HINT
  // error.import.reparse_after_promotion) : ses brouillons perdraient le lien
  // vers leur import.
  async function handleReprocess() {
    if (!selectedRun) return;
    setReprocessing(true);
    try {
      const ad = selectedRun.summary?.adapter || {};
      const { data: ovData, error: ovErr } = await supabase.rpc('fn_import_set_adapter_overrides', {
        p_run_id: Number(selectedRun.id),
        p_forced_format: ad.forced_format ?? null,
        p_forced_vocabulary: ad.forced_vocabulary ?? null,
        p_forced_encoding: reprocessEncoding === 'auto' ? null : reprocessEncoding,
      });
      if (ovErr) throw ovErr;
      assertRpcOk(ovData);
      const { data: dispatchData, error: dispatchErr } = await supabase.rpc('fn_import_dispatch', {
        p_run_id: Number(selectedRun.id), p_force_reparse: true,
      });
      if (dispatchErr) throw dispatchErr;
      assertRpcOk(dispatchData);
      setMsg({ text: t({ id: 'importacoes.run.reprocess.done' }, { id: selectedRun.id }), kind: 'ok' });
      setRunRows([]);
      setSelectedRows(new Set());
      await loadRuns();
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally { setReprocessing(false); }
  }

  // ── Validation par-ligne : sélection puis promotion en lot ─────
  function toggleRow(id) {
    setSelectedRows(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  }

  function toggleAllVisible() {
    setSelectedRows(prev => {
      const allSel = selectableIds.length > 0 && selectableIds.every(id => prev.has(id));
      return allSel ? new Set() : new Set(selectableIds);
    });
  }

  async function handlePromoteSelected() {
    if (!selectedRunId) return;
    // On ne promeut QUE les nouveautés sélectionnées (les doublons ne se créent
    // pas à l'aveugle — ils s'écartent via Rejeter, ou se rapprochent par
    // l'Adaptador). On filtre donc la sélection sur match_status='new_record'.
    // H21 lot 1 : une ligne « Déjà importée » (known_record) n'y entre jamais.
    const ids = filteredRunRows
      .filter(r => selectedRows.has(r.id) && r.match_status === 'new_record' && !r.created_book_draft_id)
      .map(r => r.id);
    if (!ids.length) return;
    setPromotingSel(true);
    setMsg({ text: t({ id: 'importacoes.generatingDrafts' }), kind: 'info' });
    const reponses = [];
    try {
      // La décision d'abord, et son refus s'arrête ici : on ne promeut pas des
      // lignes dont la décision n'a pas été posée.
      const { error: editorialError } = await supabase.rpc('fn_import_set_editorial', {
        p_run_id: Number(selectedRunId),
        p_row_ids: ids,
        p_editorial_decision: 'accept_new',
        p_editorial_note: 'page import: validation individuelle',
      });
      if (editorialError) throw editorialError;
      // H21 lot 0 (29/09/2026) : la sélection, et elle seule (p_row_ids) ;
      // sans elle, la promotion emportait toutes les lignes acceptées du run.
      // H33 (12/10/2026) : par pages (la base refuse au-delà : le plafond de
      // 8 s des appels) ; chaque page rejoint le lot ouvert du run. Depuis le
      // 14/10, les pages de la promotion : 100 lignes et 2 500 exemplaires du
      // fichier au plus (pagesDePromotion).
      const parId = new Map(filteredRunRows.map(r => [r.id, r]));
      for (const page of pagesDePromotion(ids.map(id => parId.get(id) || { id }))) {
        const { data: reponse, error } = await supabase.rpc('fn_import_promote', { p_run_id: Number(selectedRunId), p_row_ids: page });
        if (error) throw error;
        reponses.push(reponse || {});
      }
      const data = cumulerReponses(reponses);
      // Rien d'éligible (déjà promues, décidées ailleurs entre-temps) : la RPC
      // rend { selected_count: 0 } sans created_drafts ni erreur — ce n'est pas
      // un succès, et l'écran le dit.
      const created = Number(data?.created_drafts || 0);
      setMsg(created === ids.length
        ? { text: t({ id: 'importacoes.draftsCreated' }), kind: 'ok' }
        : { text: t({ id: 'importacoes.fila.promotedPartial' }, { created, asked: ids.length }), kind: created > 0 ? 'info' : 'error' });
      setSelectedRows(new Set());
      await loadRuns();
      await loadRunRows(selectedRunId);
    } catch (err) {
      // une page refusée après d'autres : ce que les pages faites ont créé,
      // puis le refus
      const created = Number(cumulerReponses(reponses).created_drafts || 0);
      setMsg({ text: `${created > 0 ? `${t({ id: 'importacoes.fila.pagesAvantRefus' }, { created })} ` : ''}${localizeError(err, t)}`, kind: 'error' });
      // Deux appels : la décision a pu être posée avant l'échec de la
      // promotion. Recharger montre l'état réel (la ligne reste cochable).
      await loadRunRows(selectedRunId);
    } finally {
      setPromotingSel(false);
    }
  }

  // Rapprocher des doublons (livre déjà publié au catalogue) : crée un brouillon
  // d'exemplaire pour la biblio, rattaché au proposed_book_id (pas un book_draft).
  // H21 lot 1 (IMP-28) : une ligne « Déjà importée » (known_record) part aussi,
  // vers la notice reconnue (proposed_book_id) ; fn_import_reconcile_duplicates
  // l'accepte. C'est son seul chemin vers le catalogue : jamais « Créer ».
  async function handleReconcileSelected() {
    if (!selectedRunId) return;
    const ids = filteredRunRows
      .filter(r => selectedRows.has(r.id) && r.proposed_book_id && !r.created_exemplar_draft_id
        && (r.match_status === 'possible_duplicate' || r.match_status === 'matched_book' || r.match_status === 'known_record'))
      .map(r => r.id);
    if (!ids.length) return;
    setPromotingSel(true);
    setMsg({ text: t({ id: 'importacoes.fila.reconciling' }), kind: 'info' });
    const reponses = [];
    try {
      // H33 (12/10/2026) : par pages de 200 lignes et 5 000 exemplaires du
      // fichier au plus (la base refuse au-delà : le plafond de 8 s des appels).
      // Une page suivante voit les brouillons des précédentes : les verdicts
      // sont ceux d'un seul appel ; les comptes s'additionnent.
      const parId = new Map(filteredRunRows.map(r => [r.id, r]));
      for (const page of pagesParExemplaires(ids.map(id => parId.get(id) || { id }))) {
        const { data: reponse, error } = await supabase.rpc('fn_import_reconcile_duplicates', {
          p_run_id: Number(selectedRunId),
          p_row_ids: page,
        });
        if (error) throw error;
        reponses.push(reponse || {});
      }
      const data = cumulerReponses(reponses);
      // H19 : un exemplaire dont le code d'origine est déjà dans la bibliothèque
      // n'est pas recréé ; une ligne entièrement détenue est marquée rejetée.
      const skipped = Number(data?.items_skipped_code_taken || 0);
      const held = Number(data?.rows_already_held || 0);
      // H21 lot 0 : une ligne traitée, rejetée ou écartée ailleurs entre-temps
      // est ignorée par la RPC (skipped_rows) ; l'écran le dit.
      const ignorees = Number(data?.skipped_rows || 0);
      // H21 lot 6a : les comptes par verdict des exemplaires du fichier (déjà
      // là, déplacé, sans code…) et les lignes signalées, laissées sans brouillon.
      const verdicts = resumeVerdicts(t, data?.verdicts, data?.rows_signalled);
      const signal = Number(data?.rows_signalled || 0) > 0;
      // Les lignes ignorées d'abord, puis ce qui a été fait des autres (comptes
      // H19 compris) : une ligne ignorée ne cache pas une ligne détenue.
      setMsg(ignorees > 0
        ? { text: [`${t({ id: 'importacoes.fila.reconciledPartial' }, { skipped: ignorees, asked: ids.length })} ${
              t({ id: 'importacoes.fila.reconciledCounts' }, { created: Number(data?.created_items || 0), skipped, held })}`,
            verdicts].filter(Boolean).join(' '),
            kind: ignorees >= ids.length ? 'error' : 'info' }
        : {
            // (rien de créé — tout signalé : jamais « Brouillon d'exemplaire créé »)
            text: [skipped || held || Number(data?.created_items || 0) === 0
              ? t({ id: 'importacoes.fila.reconciledCounts' }, { created: Number(data?.created_items || 0), skipped, held })
              : t({ id: 'importacoes.fila.reconciled' }), verdicts].filter(Boolean).join(' '),
            kind: signal ? 'info' : 'ok',
          });
      setSelectedRows(new Set());
      await loadRuns();
      await loadRunRows(selectedRunId);
    } catch (err) {
      // une page refusée après d'autres : ce que les pages faites ont fait
      // (comptes, verdicts des exemplaires, lignes signalées), puis le refus
      const fait = cumulerReponses(reponses);
      setMsg({ text: [
        reponses.length ? t({ id: 'importacoes.fila.reconciledCounts' }, {
          created: Number(fait.created_items || 0), skipped: Number(fait.items_skipped_code_taken || 0),
          held: Number(fait.rows_already_held || 0) }) : '',
        reponses.length ? resumeVerdicts(t, fait.verdicts, fait.rows_signalled) : '',
        localizeError(err, t),
      ].filter(Boolean).join(' '), kind: 'error' });
      await loadRunRows(selectedRunId);
    } finally {
      setPromotingSel(false);
    }
  }

  // H21 lot 4 (06/10/2026, IMP-31) : « Préparer la mise à jour » — pour les
  // lignes « Déjà importées » sélectionnées qui ont un champ changé dans le
  // fichier seulement (estPreparable), un brouillon de mise à jour par notice
  // que ta bibliothèque est seule à détenir, dans le lot du run ; la base
  // recalcule la comparaison et dit les lignes ignorées, par raison. Par pages
  // de 200 (plafond de la RPC). Jamais d'office : seulement ce geste.
  async function handlePrepareUpdates() {
    if (!selectedRunId) return;
    const ids = filteredRunRows.filter(r => selectedRows.has(r.id) && estPreparable(r)).map(r => r.id);
    if (!ids.length) return;
    setPromotingSel(true);
    setMsg({ text: t({ id: 'importacoes.fila.preparing' }), kind: 'info' });
    let prepares = 0;
    let lot = null;
    const ignorees = {};
    // H21 lot 6b : la partie exemplaires (préparés, ignorés par raison)
    const ex = { prepares: 0, ignorees: {} };
    try {
      // 15/10/2026 : pages de 100 lignes ET de 2 500 exemplaires du fichier au
      // plus (pagesDePreparation ; 200 / 5 000 avant)
      const parId = new Map(filteredRunRows.map(r => [r.id, r]));
      for (const page of pagesDePreparation(ids.map(id => parId.get(id) || { id }))) {
        const { data, error } = await supabase.rpc('fn_import_preparer_mises_a_jour', {
          p_run_id: Number(selectedRunId),
          p_row_ids: page,
        });
        if (error) throw error;
        prepares += Number(data?.prepared || 0);
        if (data?.batch_id) lot = data.batch_id;
        Object.entries(data?.skipped || {}).forEach(([k, n]) => { ignorees[k] = (ignorees[k] || 0) + Number(n || 0); });
        ex.prepares += Number(data?.exemplaires?.prepared || 0);
        Object.entries(data?.exemplaires?.skipped || {}).forEach(([k, n]) => { ex.ignorees[k] = (ex.ignorees[k] || 0) + Number(n || 0); });
      }
      setMsg(messagePreparation(t, prepares, lot, ignorees, ex));
      setSelectedRows(new Set());
      await loadRuns();
      await loadRunRows(selectedRunId);
    } catch (err) {
      // une page refusée après d'autres : ce qui a été préparé est dit aussi
      setMsg({ text: `${prepares + ex.prepares > 0 ? `${messagePreparation(t, prepares, lot, ignorees, ex).text} ` : ''}${localizeError(err, t)}`, kind: 'error' });
      await loadRunRows(selectedRunId);
    } finally {
      setPromotingSel(false);
    }
  }

  function basculerDetail(id) {
    setDetailsOuverts(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  }

  // Écarter des lignes (doublons, hors-sujet) : décision 'reject'. Elles ne
  // seront jamais promues et apparaissent « Rejeitada » (rouge).
  async function handleRejectSelected() {
    const ids = [...selectedRows];
    // Pendant un rechargement, les lignes affichées sont vides : le filet
    // « doublons » ci-dessous ne verrait rien. On attend les lignes.
    if (!ids.length || !selectedRunId || runRowsLoading) return;
    // ── Filet de sécurité : ne jamais jeter un exemplaire réel par mégarde ──
    // Une ligne en doublon = la biblio déclare détenir un exemplaire de ce
    // document. « Rejeter » NE l'enregistre PAS (≠ « Rapprocher »).
    // H21 lot 1 : une ligne « Déjà importée » (known_record) aussi — la notice
    // reconnue est au catalogue, et le fichier déclare un exemplaire.
    const heldDupCount = filteredRunRows.filter(r => selectedRows.has(r.id)
      && (r.match_status === 'possible_duplicate' || r.match_status === 'matched_book' || r.match_status === 'matched_draft'
        || r.match_status === 'known_record')).length;
    if (heldDupCount > 0 && !window.confirm(t({ id: 'importacoes.fila.rejectHoldingsWarn' }, { n: heldDupCount }))) {
      return;
    }
    setPromotingSel(true);
    setMsg({ text: t({ id: 'importacoes.fila.rejecting' }), kind: 'info' });
    try {
      const { data, error } = await supabase.rpc('fn_import_set_editorial', {
        p_run_id: Number(selectedRunId),
        p_row_ids: ids,
        p_editorial_decision: 'reject',
        p_editorial_note: 'page import: écarté (doublon / non pertinent)',
      });
      if (error) throw error;
      // H21 lot 0 : une ligne déjà convertie, rejetée ou écartée ailleurs
      // entre-temps, ou sortie du run, est ignorée (skipped_rows), pas refusée
      // — l'écran le dit au lieu d'un succès plein. Le compte des lignes
      // réellement écrites fait foi, même sans ligne déclarée ignorée.
      const ignorees = Number(data?.skipped_rows || 0);
      const rejetees = Number(data?.updated_rows ?? (ids.length - ignorees));
      setMsg(ignorees > 0 || rejetees < ids.length
        ? { text: t({ id: 'importacoes.fila.rejectedPartial' }, { rejected: rejetees, asked: ids.length }),
            kind: rejetees > 0 ? 'info' : 'error' }
        : { text: t({ id: 'importacoes.fila.rejected' }), kind: 'ok' });
      setSelectedRows(new Set());
      await loadRunRows(selectedRunId);
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
      await loadRunRows(selectedRunId);
    } finally {
      setPromotingSel(false);
    }
  }

  return (
    <div className="imp-sheet">
            <div className="imp-sheet__head">
              <span className="imp-sheet__title">
                {t({ id: 'importacoes.fila.title' })}
              </span>
            </div>
            <div className="imp-sheet__body">
              {/* Filters */}
              <div className="imp-filters">
                <span className="imp-filters__label">{t({ id: 'importacoes.fila.filter' })}</span>
                <select className="ab-select" style={{ width: 'auto' }} value={filaSourceFilter} onChange={e => {
                  setFilaSourceFilter(e.target.value);
                  if (e.target.value) {
                    const run = runs.find(r => String(r.source_id) === e.target.value);
                    if (run && run.id !== selectedRunId) { setSelectedRunId(run.id); loadRunRows(run.id); }
                  }
                }}>
                  <option value="">{t({ id: 'importacoes.fila.allSources' })}</option>
                  {sources.map(s => <option key={s.id} value={String(s.id)}>{s.partner_name}</option>)}
                </select>
                <select className="ab-select" style={{ width: 'auto' }} value={filaStateFilter} onChange={e => setFilaStateFilter(e.target.value)}>
                  <option value="">{t({ id: 'importacoes.fila.allStates' })}</option>
                  <option value="pending">{t({ id: 'importacoes.fila.state.pending' })}</option>
                  <option value="approved">{t({ id: 'importacoes.fila.state.approved' })}</option>
                  <option value="rejected">{t({ id: 'importacoes.fila.state.rejected' })}</option>
                </select>
                <select className="ab-select" style={{ width: 'auto' }} value={filaMatchFilter} onChange={e => setFilaMatchFilter(e.target.value)}>
                  <option value="">{t({ id: 'importacoes.fila.allMatches' })}</option>
                  <option value="new">{t({ id: 'importacoes.fila.filterNew' })}</option>
                  <option value="dup">{t({ id: 'importacoes.fila.filterDup' })}</option>
                  <option value="known">{t({ id: 'importacoes.fila.filterKnown' })}</option>
                </select>
              </div>

              {/* Run selector */}
              {!selectedRunId && runs.length > 0 && (
                <p className="imp-note" style={{ marginBottom: 12 }}>
                  {t({ id: 'importacoes.fila.selectRun' })}
                </p>
              )}
              {!selectedRunId && runs.length > 0 && (
                <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 12 }}>
                  {runs.slice(0, 8).map(r => (
                    <button key={r.id} className="cat-btn secondary" style={{ fontSize: '.82rem', padding: '6px 12px' }}
                      onClick={() => { setSelectedRunId(r.id); loadRunRows(r.id); }}>
                      #{r.id} — {r.source_name || r.original_filename || '—'}
                    </button>
                  ))}
                </div>
              )}

              {/* Barrière : import en cours de traitement (parse + matching) */}
              {selectedRunId && runProcessing && (
                <div className="imp-sheet" style={{ textAlign: 'center', padding: '28px 20px' }}>
                  <div style={{ fontSize: '1.6rem', marginBottom: 8 }}>⏳</div>
                  <p style={{ fontWeight: 600, margin: '0 0 6px' }}>{t({ id: 'importacoes.fila.processing.title' })}</p>
                  <p className="imp-note" style={{ maxWidth: 520, margin: '0 auto 14px' }}>{t({ id: 'importacoes.fila.processing.desc' })}</p>
                  <button className="cat-btn secondary" disabled={refreshing} onClick={handleRefresh}>
                    {refreshing ? t({ id: 'importacoes.refreshing' }) : t({ id: 'importacoes.refresh' })}
                  </button>
                </div>
              )}

              {/* Barrière : import échoué */}
              {selectedRunId && runFailed && (
                <div className="imp-sheet" style={{ textAlign: 'center', padding: '28px 20px' }}>
                  <AppIcon name="warning" size={26} style={{ marginBottom: 8 }} />
                  <p style={{ fontWeight: 600, margin: '0 0 6px' }}>{t({ id: 'importacoes.fila.failed.title' })}</p>
                  <p className="imp-note" style={{ maxWidth: 520, margin: '0 auto' }}>{t({ id: 'importacoes.fila.failed.desc' })}</p>
                </div>
              )}

              {/* Encodage lu + retraitement (H15). Le résumé vient de l'EF
                  (summary.encoding) ; on le traduit ici plutôt que d'afficher
                  les phrases de l'EF, écrites en une seule langue. */}
              {selectedRunId && !runProcessing && selectedRun && (
                <RunEncodingPanel
                  run={selectedRun}
                  reprocessEncoding={reprocessEncoding}
                  setReprocessEncoding={setReprocessEncoding}
                  reprocessing={reprocessing}
                  onReprocess={handleReprocess}
                />
              )}
              {/* Couverture : ce que l'import a repris du fichier (H16). */}
              {selectedRunId && !runProcessing && !runFailed && selectedRun && (
                <RunCoveragePanel run={selectedRun} />
              )}
              {/* H21 lot 7 : les exemplaires retirés (constat sur le fichier entier). */}
              {selectedRunId && !runProcessing && !runFailed && selectedRun && (
                <RunRetraitsPanel runId={selectedRunId} canAct={!depositLocked} />
              )}

              {/* Rows table (uniquement si traitement terminé) */}
              {selectedRunId && !runProcessing && !runFailed && (
                <div style={{ overflowX: 'auto' }}>
                  {runRowsLoading && <p className="imp-note">{t({ id: 'importacoes.loadingRows' })}</p>}
                  {!runRowsLoading && filteredRunRows.length === 0 && <p className="imp-note">{t({ id: 'importacoes.noRowsAvailable' })}</p>}
                  {selectedRows.size > 0 && (
                    <div className="imp-batchbar" style={{ display: 'flex', alignItems: 'center', gap: 10, margin: '4px 0 12px', padding: '8px 12px', background: 'var(--brand-surface-2, rgba(0,0,0,.04))', borderRadius: 8, flexWrap: 'wrap' }}>
                      <span className="imp-note">{t({ id: 'importacoes.fila.selectedCount' }, { n: selectedRows.size })}</span>
                      <button className="cat-btn" disabled={promotingSel || selectedNewCount === 0 || depositLocked} onClick={handlePromoteSelected}
                        title={depositLocked ? t({ id: 'importacoes.fila.depositAdminOnly' }) : undefined}>
                        {promotingSel ? t({ id: 'importacoes.generatingDrafts' }) : t({ id: 'importacoes.fila.createSelected' }, { n: selectedNewCount })}
                      </button>
                      {depositLocked && (
                        <span className="imp-note">{t({ id: 'importacoes.fila.depositAdminOnly' })}</span>
                      )}
                      <button className="cat-btn" disabled={promotingSel || selectedDupCount === 0} onClick={handleReconcileSelected} title={t({ id: 'importacoes.fila.reconcileTitle' })}>
                        {t({ id: 'importacoes.fila.reconcile' }, { n: selectedDupCount })}
                      </button>
                      {peutComparer && (
                        <button className="cat-btn" data-testid="prepare-update" disabled={promotingSel || selectedUpdCount === 0}
                          onClick={handlePrepareUpdates} title={t({ id: 'importacoes.fila.prepareUpdateTitle' })}>
                          {t({ id: 'importacoes.fila.prepareUpdate' }, { n: selectedUpdCount })}
                        </button>
                      )}
                      <button className="cat-btn secondary" disabled={promotingSel} onClick={handleRejectSelected}
                        title={t({ id: 'importacoes.fila.rejectTitle' })}
                        style={{ borderColor: 'var(--brand-danger, #b42318)', color: 'var(--brand-danger, #b42318)' }}>
                        {t({ id: 'importacoes.fila.reject' }, { n: selectedRows.size })}
                      </button>
                      <button className="cat-btn secondary" disabled={promotingSel} onClick={() => setSelectedRows(new Set())}>
                        {t({ id: 'importacoes.fila.clearSelection' })}
                      </button>
                      <p className="imp-note" style={{ flexBasis: '100%', margin: '2px 0 0', fontSize: '.72rem', opacity: .85 }}>
                        {t({ id: 'importacoes.fila.gesturesHelp' })}
                      </p>
                    </div>
                  )}
                  {filteredRunRows.length > 0 && (
                    <table className="imp-queue">
                      <thead>
                        <tr>
                          <th style={{ width: 28 }}>
                            <input type="checkbox" aria-label={t({ id: 'importacoes.fila.selectAll' })}
                              checked={allVisibleSelected} disabled={selectableIds.length === 0}
                              onChange={toggleAllVisible} />
                          </th>
                          <th>{t({ id: 'importacoes.fila.col.record' })}</th>
                          <th>{t({ id: 'importacoes.fila.col.source' })}</th>
                          <th>{t({ id: 'importacoes.fila.col.match' })}</th>
                          <th className="imp-hide-sm">{t({ id: 'importacoes.fila.col.decision' })}</th>
                          <th>{t({ id: 'importacoes.fila.col.state' })}</th>
                        </tr>
                      </thead>
                      <tbody>
                        {filteredRunRows.slice(0, rowLimit).map(row => {
                          const ms = row.match_status || 'unreviewed';
                          const isNew = ms === 'new_record';
                          const isMatched = ms === 'matched_book' || ms === 'matched_draft';
                          const isDup = ms === 'possible_duplicate' || isMatched;
                          // H21 lot 1 : « Déjà importée » — l'identifiant d'import de la
                          // ligne est connu pour ta bibliothèque, sur une seule notice.
                          // Ton « info », comme « Déjà au catalogue » : une reconnaissance
                          // sûre, pas un doublon à vérifier (« warn »).
                          const isKnown = ms === 'known_record';
                          // H21 lot 3 : ce que le fichier change, comparé à trois états.
                          const comparaison = isKnown ? resumeComparaison(row) : null;
                          // Comptes absents (la clé existe, la valeur est NULL) : pas encore
                          // calculée — la coordination la demande à l'ouverture (plus haut).
                          const comparaisonAbsente = isKnown && !!row.proposed_book_id && row.comparison_counts === null;
                          const ed = row.editorial_decision || 'pending';
                          // Sélectionnable : même prédicat que « tout cocher ».
                          const reviewable = estSelectionnable(row);
                          return (
                            <tr key={row.id} style={ed === 'reject' ? { opacity: 0.55 } : undefined}>
                              <td>
                                {reviewable && (
                                  <input type="checkbox" checked={selectedRows.has(row.id)}
                                    onChange={() => toggleRow(row.id)} />
                                )}
                              </td>
                              <td>
                                <div className="ttl">{row.title || t({ id: 'importacoes.noTitle' })}</div>
                                <div className="au">{row.responsibility_statement || '—'}</div>
                              </td>
                              <td><Pill>{runs.find(r => r.id === row.run_id)?.source_name || '—'}</Pill></td>
                              <td>
                                <Pill variant={isNew ? 'ok' : isMatched || isKnown ? 'info' : isDup ? 'warn' : 'muted'}>
                                  {t({ id: 'importacoes.fila.match.' + ms })}
                                </Pill>
                                {Number(row.confidence) > 0 && (
                                  <span style={{ marginLeft: 6, fontSize: '.72rem', fontWeight: 700, color: 'var(--brand-muted, #94a3b8)' }}>
                                    {Math.round(Number(row.confidence))}%
                                  </span>
                                )}
                                {isDup && (
                                  <div className="imp-note" style={{ marginTop: 3, fontSize: '.72rem' }}>
                                    {row.proposed_title
                                      ? t({ id: 'importacoes.fila.matchAgainst' }, { title: row.proposed_title })
                                      : t({ id: 'importacoes.fila.matchVerify' })}
                                  </div>
                                )}
                                {isKnown && (
                                  <div className="imp-note imp-known-of" style={{ marginTop: 3, fontSize: '.72rem' }}>
                                    {t({ id: 'importacoes.fila.knownRecordOf' }, { title: row.proposed_title || (row.proposed_book_id ? `#${row.proposed_book_id}` : '—') })}
                                  </div>
                                )}
                                {comparaison && (
                                  <div className="imp-note imp-known-compare" data-testid="known-compare"
                                    style={{ marginTop: 2, fontSize: '.72rem', color: comparaison.conflits > 0 ? 'var(--brand-warning, #fbbf24)' : undefined }}>
                                    {comparaison.changements === 0 && comparaison.aRevoir === 0
                                      ? t({ id: 'importacoes.fila.comparison.none' })
                                      : [
                                        comparaison.changements > 0
                                          ? t({ id: 'importacoes.fila.comparison.changes' }, { n: comparaison.changements, c: comparaison.conflits })
                                          : null,
                                        comparaison.aRevoir > 0
                                          ? t({ id: 'importacoes.fila.comparison.toReview' }, { n: comparaison.aRevoir })
                                          : null,
                                      ].filter(Boolean).join(' · ')}
                                  </div>
                                )}
                                {isKnown && exemplairesPreparables(row) > 0 && (
                                  <div className="imp-note imp-known-items-update" data-testid="known-items-update"
                                    style={{ marginTop: 2, fontSize: '.72rem' }}>
                                    {t({ id: 'importacoes.fila.comparison.items' }, { n: exemplairesPreparables(row) })}
                                  </div>
                                )}
                                {comparaisonAbsente && (
                                  <div className="imp-note imp-known-compare-absente" data-testid="known-compare-absente"
                                    style={{ marginTop: 2, fontSize: '.72rem', color: 'var(--brand-muted, #94a3b8)' }}>
                                    {t({ id: 'importacoes.fila.comparison.notComputed' })}
                                  </div>
                                )}
                                {isKnown && row.update_draft_id && (
                                  <div className="imp-note imp-known-update" data-testid="known-update-draft"
                                    style={{ marginTop: 2, fontSize: '.72rem', color: 'var(--brand-info, #60a5fa)' }}>
                                    {t({ id: `importacoes.fila.update.${row.update_draft_status === 'published' ? 'published'
                                      : row.update_draft_status === 'cancelled' ? 'cancelled' : 'prepared'}` }, { id: row.update_draft_id })}
                                  </div>
                                )}
                                {isKnown && row.proposed_book_id && (
                                  <div style={{ marginTop: 2 }}>
                                    <button type="button" className="cat-btn secondary" data-testid="known-detail-toggle"
                                      aria-expanded={detailsOuverts.has(row.id)} style={{ fontSize: '.7rem', padding: '1px 6px' }}
                                      onClick={() => basculerDetail(row.id)}>
                                      {t({ id: detailsOuverts.has(row.id) ? 'importacoes.fila.detail.hide' : 'importacoes.fila.detail.show' })}
                                    </button>
                                    {detailsOuverts.has(row.id) && <DetailComparaison runId={row.run_id} rowId={row.id} />}
                                  </div>
                                )}
                                {isKnown && row.proposed_book_held === false && (
                                  <div className="imp-note imp-known-not-held" style={{ marginTop: 2, fontSize: '.72rem', color: 'var(--brand-warning, #fbbf24)' }}>
                                    {t({ id: 'importacoes.fila.knownRecordNotHeld' })}
                                  </div>
                                )}
                                {(isDup || isKnown) && row.proposed_book_id && !row.created_exemplar_draft_id && (
                                  <div className="imp-note" style={{ marginTop: 2, fontSize: '.7rem', color: 'var(--brand-info, #60a5fa)' }}>
                                    {t({ id: 'importacoes.fila.reconcileRowHint' })}
                                  </div>
                                )}
                                {/* H21 lot 6a : les exemplaires du fichier et leur verdict */}
                                <ExemplairesDuFichier items={row.exemplaires} titreLigne={row.title} maj={row.exemplaires_maj} />
                              </td>
                              <td className="imp-hide-sm">
                                <Pill variant={ed === 'accept_new' || ed === 'accept_duplicate' ? 'ok' : ed === 'reject' ? 'danger' : 'muted'}>
                                  {t({ id: 'importacoes.fila.decision.' + ed })}
                                </Pill>
                              </td>
                              <td>
                                {row.created_book_draft_id
                                  ? <Pill variant="ok">{t({ id: 'importacoes.fila.draftCreated' })}</Pill>
                                  : row.created_exemplar_draft_id
                                  ? <Pill variant="ok">{t({ id: 'importacoes.fila.exemplarCreated' })}</Pill>
                                  : <Pill>{t({ id: 'importacoes.fila.inQueue' })}</Pill>}
                              </td>
                            </tr>
                          );
                        })}
                      </tbody>
                    </table>
                  )}
                  {filteredRunRows.length > rowLimit && (
                    <div style={{ marginTop: 10, textAlign: 'center' }}>
                      <button className="cat-btn secondary" onClick={() => setRowLimit(rowLimit + 50)}>
                        {t({ id: 'importacoes.fila.loadMore' })}
                      </button>
                      <p className="imp-note" style={{ marginTop: 6 }}>
                        {t({ id: 'importacoes.fila.showing' }, { shown: Math.min(rowLimit, filteredRunRows.length), total: filteredRunRows.length })}
                      </p>
                    </div>
                  )}
                  {filteredRunRows.length > 50 && filteredRunRows.length <= rowLimit && (
                    <p className="imp-note" style={{ marginTop: 8 }}>
                      {t({ id: 'importacoes.fila.showingAll' }, { total: filteredRunRows.length })}
                    </p>
                  )}
                </div>
              )}
            </div>
          </div>

  );
}
