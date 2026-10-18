import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { useAuth } from '@/contexts/AuthContext';
import { useIntl } from 'react-intl';
import { useToast } from '@/contexts/ToastContext';
import { useConfirm } from '@/contexts/ConfirmContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { useCoordLibraries } from '@/lib/useStaffLibraries';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import AppIcon from '@/components/ui/AppIcon';
import './CatalogacaoPage.css';
import BookDraftForm from './BookDraftForm';
import OcrDepositTab from './OcrDepositTab';
import AuthorDraftForm from './AuthorDraftForm';
import ExemplarDraftForm from './ExemplarDraftForm';
import LabelSheetPrinter from './LabelSheetPrinter';
import QueuePanel from './QueuePanel';
import CatalogPanel from './CatalogPanel';
import SubjectGovernancePanel from './SubjectGovernancePanel';
import SerialGovernancePanel from './SerialGovernancePanel';
import DedupAssistantPanel from './DedupAssistantPanel';
import DivergencesPanel from './DivergencesPanel';
import BatchesPanel from './BatchesPanel';
import { canArbitrateDuplicates } from '@/lib/dedupRoles';
import CatalogacaoWizard, { shouldShowWizard } from './CatalogacaoWizard';
import UserHeroBadge from '@/components/UserHeroBadge';
import HeroDocumentationActions from '@/components/HeroDocumentationActions';

// ── Storage keys ────────────────────────────────────────────
const MODE_KEY = 'catalogacaoMode';
// Onglet de reference a l'ouverture de la page (sans #tab= dans l'adresse).
// L'ancienne cle `catalogacaoActiveTab` (dernier onglet visite) n'est plus
// lue ni ecrite depuis le 28/09/2026 ; ce qui en reste dans un navigateur
// est inerte.
const DEFAULT_TAB = 'catalogPanel';

// ═══════════════════════════════════════════════════════════
// CatalogacaoPage — Tranche 1 : squelette complet
// ═══════════════════════════════════════════════════════════

export default function CatalogacaoPage() {
  const { user } = useAuth();
  const { config, effectiveRole, isNetworkAdmin } = useLibrary();
  // L'assistant de dedoublonnage n'a de sens que pour qui peut arbitrer :
  // ses trois temps se terminent par une fusion. Ailleurs il n'offrirait
  // que des impasses.
  const arbitreDoublons = canArbitrateDuplicates(effectiveRole);
  const { formatMessage: t } = useIntl();
  // H21 lot 5 (07/10/2026, IMP-32 a) : « Divergences à traiter » — la
  // coordination d'une bibliothèque (détentrice : la base filtre) et
  // l'administration du réseau ; le librarian ne les voit pas. La pastille dit
  // le nombre de notices à traiter.
  const { coordLibraryIds } = useCoordLibraries();
  const voitDivergences = !!isNetworkAdmin || (coordLibraryIds?.length ?? 0) > 0;
  const [nbDivergences, setNbDivergences] = useState(0);
  useEffect(() => {
    if (!voitDivergences) { setNbDivergences(0); return undefined; }
    let actif = true;
    supabase.rpc('fn_divergences_a_traiter', { p_library_id: null, p_limit: 1, p_offset: 0 })
      .then(({ data, error }) => { if (actif && !error) setNbDivergences(Number(data?.total || 0)); })
      .catch(() => {});
    return () => { actif = false; };
  }, [voitDivergences]);
  useDocumentTitle(t({ id: 'pageTitle.cataloging' }));
  const confirmer = useConfirm();
  const { notifyError } = useToast();

  // Barre de pastilles partagee `.ab-tabbar` (src/styles/tabbar.css) : meme
  // forme que « Mon compte », le tableau de bord, la bibliotheque, la federation
  // et le reseau. `icon` = repere visuel du premier niveau ; `separator` marque
  // le debut d'un groupe (ancien `.tab-separator`, meme semantique : l'ecart est
  // AVANT la pastille marquee).
  //
  // Le catalogue deja publie ouvre la barre et c'est l'onglet de reference a
  // l'ouverture de la page (demande de Xavier, 28/09/2026) : on part de ce qui
  // existe avant de saisir. Le groupe de la saisie commence donc APRES lui.
  const TABS = [
    { id: 'catalogPanel',   icon: 'library', label: t({ id: 'catalogacao.tab.catalogo' }) },
    { id: 'booksPanel',     icon: 'document', label: t({ id: 'catalogacao.tab.documento' }), separator: true },
    { id: 'authorsPanel',   icon: 'penLine', label: t({ id: 'catalogacao.tab.autoria' }) },
    { id: 'indexPanel',     icon: 'bookmark', label: t({ id: 'catalogacao.tab.indexacao' }) },
    { id: 'labelsPanel',    icon: 'tags', label: t({ id: 'catalogacao.tab.etiquetas' }) },
    // Flux d'ingestion distinct (depot de scans OCR) — isole entre 2 separateurs.
    { id: 'ocrPanel',       icon: 'image', label: t({ id: 'catalogacao.tab.ocr' }), separator: true },
    { id: 'queuePanel',     icon: 'inbox', label: t({ id: 'catalogacao.tab.fila' }), separator: true },
    { id: 'batchesPanel',   icon: 'package', label: t({ id: 'catalogacao.tab.lotes' }) },
    ...(voitDivergences
      ? [{ id: 'divergencesPanel', icon: 'scale', label: t({ id: 'catalogacao.tab.divergences' }), count: nbDivergences }]
      : []),
    { id: 'materiaPanel',   icon: 'folder', label: t({ id: 'catalogacao.tab.materia' }), separator: true },
    { id: 'periodicosPanel', icon: 'newspaper', label: t({ id: 'catalogacao.tab.periodicos' }) },
    ...(arbitreDoublons
      ? [{ id: 'dedupPanel', icon: 'arrowLeftRight', label: t({ id: 'catalogacao.tab.dedup' }) }]
      : []),
  ];

  // ── Mode simple / completo ─────────────────────────────
  const [mode, setMode] = useState(() => {
    try { return localStorage.getItem(MODE_KEY) || 'simple'; } catch { return 'simple'; }
  });

  // ── Active tab ─────────────────────────────────────────
  // A l'ouverture, la page montre le catalogue deja publie, sauf lien profond
  // (#tab=…, pose par « Je veux… », la cloche ou un rechargement de la page).
  // L'onglet visite en dernier n'est plus retenu d'une visite a l'autre : il
  // masquait l'onglet de reference a toute personne ayant deja ouvert la page.
  const [activeTab, setActiveTab] = useState(() => {
    const hash = window.location.hash.replace('#tab=', '');
    if (TABS.some(t => t.id === hash)) return hash;
    return DEFAULT_TAB;
  });

  // ── Stats ──────────────────────────────────────────────
  const [stats, setStats] = useState({ openBatches: 0, drafts: 0, books: 0, authors: 0, exemplares: 0 });

  // ── Wizard de découverte ───────────────────────────────
  const [wizardOpen, setWizardOpen] = useState(() => shouldShowWizard());

  // ── Dados de catálogo ────────────────────────────────────
  const [batches, setBatches] = useState([]);
  // Cf. QueuePanel : supprimer un lot emporte sa corbeille, meme porte donc,
  // et un DELETE refuse par RLS ne leve pas d'erreur.
  // B30 : ce booléen global (« coordination QUELQUE PART ») ne sert plus que
  // de repli tant que la liste des bibliothèques coordonnées n'est pas
  // chargée — les gestes de coordination se décident lot par lot.
  const [isCoord, setIsCoord] = useState(false);
  const [loading, setLoading] = useState(true);
  const [editTarget, setEditTarget] = useState(null); // { kind, id } -- handoff catalogo/fila -> editeur (Lot 0)
  // Pilotage de la sous-vue du CatalogPanel depuis les compteurs (nonce pour re-declencher meme vue)
  const [catalogReq, setCatalogReq] = useState({ view: 'book', nonce: 0 });

  // ═══════════════════════════════════════════════════════
  // Load stats + batches (same pattern as PanelPage)
  // ═══════════════════════════════════════════════════════

  const loadStats = useCallback(async () => {
    try {
      const [batchRes, bookDraftRes, authorDraftRes, exemplarDraftRes, booksRes, authorsRes, exemplaresRes] = await Promise.allSettled([
        supabase.from('catalog_batches').select('id', { count: 'exact', head: true }).eq('status', 'open'),
        supabase.from('book_drafts').select('id', { count: 'exact', head: true }).in('status', ['draft', 'ready']).eq('retake_untouched', false),
        supabase.from('author_drafts').select('id', { count: 'exact', head: true }).in('status', ['draft', 'ready']).eq('retake_untouched', false),
        supabase.from('exemplar_drafts').select('id', { count: 'exact', head: true }).in('status', ['draft', 'ready']).eq('retake_untouched', false),
        supabase.from('books').select('id', { count: 'exact', head: true }),
        supabase.from('authors').select('id', { count: 'exact', head: true }),
        supabase.from('exemplares').select('id', { count: 'exact', head: true }),
      ]);

      const count = (r) => r.status === 'fulfilled' ? (r.value.count ?? 0) : 0;

      setStats({
        openBatches: count(batchRes),
        drafts: count(bookDraftRes) + count(authorDraftRes) + count(exemplarDraftRes),
        books: count(booksRes),
        authors: count(authorsRes),
        exemplares: count(exemplaresRes),
      });
    } catch (err) {
      console.warn('loadStats error:', err);
    }
  }, []);

  const loadBatches = useCallback(async () => {
    try {
      // Les comptes viennent de v_catalog_batch_draft_counts, la meme definition
      // que celle qu'interroge deleteBatch avant de refuser. Sans eux, on
      // n'apprend qu'un lot est vide — donc supprimable — qu'en cliquant.
      // B30 : chaque lot porte SA bibliothèque (catalog_batches.library_id,
      // nulle = lot de l'administration du réseau), embarquée ici pour que
      // tous les menus et le tableau Lots la nomment sans rien déduire des
      // brouillons. L'embarquement exige la clé étrangère : si l'écran est
      // publié avant la migration (PGRST200), on relit sans elle plutôt que
      // de vider tous les menus de lots.
      const [lotsAvecBib, comptes] = await Promise.all([
        supabase.from('catalog_batches')
          .select('*, library:libraries(id, name, short_name, slug, is_active)')
          .order('created_at', { ascending: false }),
        supabase.from('v_catalog_batch_draft_counts').select('batch_id, en_cours, publies, corbeille'),
      ]);
      const lots = lotsAvecBib.error
        ? await supabase.from('catalog_batches').select('*').order('created_at', { ascending: false })
        : lotsAvecBib;
      const par = new Map((comptes.data || []).map(c => [c.batch_id, c]));
      const data = (lots.data || []).map(b => {
        const c = par.get(b.id);
        return {
          ...b,
          // library_id absente = colonne pas encore là (undefined) : on la
          // laisse telle quelle, les droits par lot retombent sur l'affichage
          // d'avant B30.
          library: b.library || null,
          _enCours: c ? Number(c.en_cours) : 0,
          _publies: c ? Number(c.publies) : 0,
          _corbeille: c ? Number(c.corbeille) : 0,
        };
      });
      setBatches(data || []);
    } catch (err) {
      console.warn('loadBatches error:', err);
    }
  }, []);

  const refreshAll = useCallback(async () => {
    setLoading(true);
    await Promise.allSettled([loadStats(), loadBatches()]);
    setLoading(false);
  }, [loadStats, loadBatches]);

  // Initial load — ProtectedRoute guarantees user is logged in.
  // NE PAS y mettre `majTout` : `refreshAll` tourne a CHAQUE ouverture de la
  // page, et regenerer le catalogue public a chaque visite serait absurde.
  useEffect(() => { refreshAll(); }, [refreshAll]);

  useEffect(() => {
    let vivant = true;
    supabase.rpc('fn_is_catalog_coordinator')
      .then(({ data }) => { if (vivant) setIsCoord(data === true); })
      .catch(() => {});
    return () => { vivant = false; };
  }, []);

  // Le bouton d'en-tete fait DEUX choses de portees differentes, et c'est
  // voulu : `refreshAll` ne change que ce que voit la personne connectee ;
  // `request_catalog_refresh` regenere ce que voient les LECTRICES. L'action
  // utile etait auparavant enfermee dans l'onglet « Catalogue(s) publie(s) »,
  // donc invisible depuis les autres onglets — alors que le bouton bien place
  // ne faisait presque rien. On les fusionne, et le retour nomme les deux
  // effets : un bouton qui republie sans le dire serait un nom de plus qui
  // ment.
  //
  // Cote SQL, l'operation est sure : REFRESH ... CONCURRENTLY (les lectrices
  // ne sont jamais bloquees) sous verrou consultatif non bloquant, qui rend
  // « busy » plutot que d'empiler les rafraichissements.
  const [majMsg, setMajMsg] = useState(null);

  const majTout = useCallback(async () => {
    setLoading(true);
    setMajMsg(null);
    try {
      const { data, error } = await supabase.rpc('request_catalog_refresh');
      if (error) throw error;
      await refreshAll();
      setMajMsg({
        text: data === 'busy'
          ? t({ id: 'catalogacao.catalog.refreshBusy' })
          : t({ id: 'catalogacao.header.refreshDone' }),
        kind: 'ok',
      });
    } catch (err) {
      setMajMsg({
        text: t({ id: 'catalogacao.catalog.refreshError' }, { message: localizeError(err, t) }),
        kind: 'error',
      });
    } finally { setLoading(false); }
  }, [refreshAll, t]);

  // ═══════════════════════════════════════════════════════
  // Mode toggle
  // ═══════════════════════════════════════════════════════

  // Track A Lot 3 — ternary tiers: simple | advanced | complete
  function switchMode(nextMode) {
    const VALID = ['simple', 'advanced', 'complete'];
    const m = VALID.includes(nextMode) ? nextMode : 'simple';
    setMode(m);
    try { localStorage.setItem(MODE_KEY, m); } catch {}
  }

  // Apply mode to body for CSS selectors
  useEffect(() => {
    document.body.setAttribute('data-catalog-mode', mode);
    return () => document.body.removeAttribute('data-catalog-mode');
  }, [mode]);

  // ═══════════════════════════════════════════════════════
  // Tab management
  // ═══════════════════════════════════════════════════════

  // P1.6-b.2 : pré-ciblage de l'attache depuis le bandeau doublon (BookDraftForm).
  const [attachTarget, setAttachTarget] = useState(null); // { bibRef, nonce } — C29 lot 1
  // Ouverture de la fiche existante depuis le bandeau / la modale « doublon ».
  //
  // PAS de 'noopener' ici, et c'est délibéré. Les sessions STAFF vivent dans
  // sessionStorage (cf. src/lib/staffStorage.js, backlog #76) ; or un onglet
  // ouvert avec 'noopener' est un contexte de navigation NEUF, qui n'hérite pas
  // de la copie du sessionStorage de l'onglet source. La session staff ne
  // suivait donc pas : le nouvel onglet s'ouvrait en ANONYME et la fiche
  // n'apparaissait pas (constaté le 19/08/2026 sur une fiche BTL, dont la
  // bibliothèque est en visibility_level = 'network', donc invisible hors
  // session).
  //
  // La cible est interne et de même origine : 'noopener' n'y apporte aucune
  // protection, le tabnabbing ne concernant que les cibles externes. Il reste
  // en place sur les liens sortants (BN, WorldCat, ISSN, Jitsi).
  function openBook(bookId) {
    if (bookId) window.open(`/livro/${bookId}`, '_blank');
  }
  async function attachToBook(bookId) {
    if (!bookId) return;
    try {
      const { data } = await supabase.from('books').select('bib_ref').eq('id', Number(bookId)).single();
      if (data?.bib_ref) setAttachTarget({ bibRef: String(data.bib_ref), nonce: Date.now() });
    } catch {}
    switchTab('indexPanel');
  }

  function openForEdit(kind, id) {
    const tabByKind = { book: 'booksPanel', author: 'authorsPanel', exemplar: 'indexPanel' };
    // Trace la dernière ouverture du brouillon (colonne « Ouvert le » de la file
    // éditoriale). Fire-and-forget : ne bloque pas la navigation et n'altère pas
    // updated_at (cf. RPC fn_touch_draft_opened + garde anarbib.skip_touch_updated_at).
    if (id != null) {
      supabase.rpc('fn_touch_draft_opened', { p_type: kind, p_id: Number(id) })
        .then(({ error }) => { if (error) console.warn('fn_touch_draft_opened:', error.message); });
    }
    setEditTarget({ kind, id: id != null ? String(id) : null });
    switchTab(tabByKind[kind] || 'booksPanel');
  }

  // Ouvre un exemplaire PUBLIÉ dans l'éditeur d'exemplaires (depuis la fiche
  // document). Le modèle de l'app édite des brouillons : on « retake » l'exemplaire
  // (création d'un brouillon d'édition) puis on bascule sur l'éditeur. Le RPC n'est
  // PAS idempotent → on confirme, comme CatalogPanel, pour éviter les doublons.
  async function editPublishedExemplar(exemplarId) {
    if (exemplarId == null) return;
    const typeLabel = t({ id: 'catalogacao.type.exemplar' }).toLowerCase();
    if (!(await confirmer({ message: t({ id: 'catalogacao.catalog.retakeConfirm' }, { type: typeLabel }), confirmLabel: t({ id: 'confirm.action.retake' }) }))) return;
    try {
      const { data, error } = await supabase.rpc('create_exemplar_draft_from_exemplar', { p_exemplar_id: Number(exemplarId) });
      if (error) throw error;
      if (data) openForEdit('exemplar', data);
    } catch (err) {
      notifyError(localizeError(err, t), err);
    }
  }

  function switchTab(tabId) {
    if (!TABS.some(t => t.id === tabId)) return;
    setActiveTab(tabId);
    try { window.history.replaceState(null, '', `#tab=${tabId}`); } catch {}
  }

  // Ouvre l'onglet Catalogo sur la sous-vue voulue (depuis les compteurs)
  function openCatalog(view) {
    setCatalogReq((r) => ({ view, nonce: r.nonce + 1 }));
    switchTab('catalogPanel');
  }

  // Listen for hash changes
  useEffect(() => {
    function onHashChange() {
      const hash = window.location.hash.replace('#tab=', '');
      if (TABS.some(t => t.id === hash)) setActiveTab(hash);
    }
    window.addEventListener('hashchange', onHashChange);
    return () => window.removeEventListener('hashchange', onHashChange);
  }, []);

  // ═══════════════════════════════════════════════════════
  // Render
  // ═══════════════════════════════════════════════════════

  const modeHint = mode === 'simple'
    ? t({ id: 'catalogacao.modeSimple' })
    : mode === 'advanced'
      ? t({ id: 'catalogacao.modeAdvanced' })
      : t({ id: 'catalogacao.modeComplete' });

  return (
    <PageShell>
      <Topbar />

      <Hero title={t({ id: 'catalogacao.areaTitle' })} subtitle={t({ id: 'catalogacao.areaSubtitle' })}>
        <UserHeroBadge />
        <HeroDocumentationActions
          extraActions={<>
            <button className="ab-button ab-button--secondary" onClick={majTout} disabled={loading}
              title={t({ id: 'catalogacao.header.refreshHint' })}>
              {loading ? t({ id: 'common.loading' }) : t({ id: 'catalogacao.header.updateCatalog' })}
            </button>
            <button className="ab-button ab-button--secondary" onClick={() => setWizardOpen(true)} style={{ gap: 6 }}>
              <span aria-hidden="true">?</span> {t({ id: 'catalogacao.wizard.helpButton' })}
            </button>
          </>}
        />
        {majMsg && (
          <div style={{ marginTop: 8, fontSize: '.82rem', maxWidth: 640,
                        color: majMsg.kind === 'error' ? '#f87171' : '#4ade80' }}>
            {majMsg.text}
          </div>
        )}
      </Hero>

      {/* ── Wizard de découverte ── */}
      {wizardOpen && (
        <CatalogacaoWizard
          onClose={() => setWizardOpen(false)}
          onSwitchTab={(tabId) => { switchTab(tabId); setWizardOpen(false); }}
        />
      )}

      <div className="catalogacao-wrap">

        {/* ── Toolbar: mode toggle ──────────────────────────── */}
        <div className="cat-toolbar">
          <div className="cat-mode-switch">
          <span className="cat-mode-switch-label">{t({ id: 'catalogacao.modeLabel' })}</span>
          <div className="cat-mode-switch-buttons">
            {['simple', 'advanced', 'complete'].map(m => (
              <button
                key={m}
                className={mode === m ? 'is-mode-active' : ''}
                aria-pressed={mode === m ? 'true' : 'false'}
                onClick={() => switchMode(m)}
              >
                {t({ id: `catalogacao.interface${m.charAt(0).toUpperCase() + m.slice(1)}` })}
              </button>
            ))}
          </div>
          <span className="cat-mode-hint">{modeHint}</span>
        </div>
      </div>

      {/* ── Statusbar (stats) ────────────────────────────── */}
      <div className="cat-statusbar">
            <div className="cat-stat">
              <div className="cat-stat-label">{t({id:'catalogacao.stats.openBatches'})}</div>
              <div
                className="cat-stat-value clickable"
                role="button"
                tabIndex={0}
                title={t({id:'catalogacao.stats.openBatchesTitle'})}
                onClick={() => switchTab('batchesPanel')}
                onKeyDown={(e) => e.key === 'Enter' && switchTab('batchesPanel')}
              >
                {stats.openBatches}
              </div>
            </div>
            <div className="cat-stat">
              <div className="cat-stat-label">{t({id:'catalogacao.stats.activeDrafts'})}</div>
              <div
                className="cat-stat-value clickable"
                role="button"
                tabIndex={0}
                title={t({id:'catalogacao.stats.activeDraftsTitle'})}
                onClick={() => switchTab('queuePanel')}
                onKeyDown={(e) => e.key === 'Enter' && switchTab('queuePanel')}
              >
                {stats.drafts}
              </div>
            </div>
            <div className="cat-stat">
              <div className="cat-stat-label">{t({id:'catalogacao.stats.publishedBooks'})}</div>
              <div
                className="cat-stat-value clickable"
                role="button"
                tabIndex={0}
                title={t({id:'catalogacao.stats.publishedBooksTitle'})}
                onClick={() => openCatalog('book')}
                onKeyDown={(e) => e.key === 'Enter' && openCatalog('book')}
              >
                {stats.books}
              </div>
            </div>
            <div className="cat-stat">
              <div className="cat-stat-label">{t({id:'catalogacao.stats.registeredAuthors'})}</div>
              <div
                className="cat-stat-value clickable"
                role="button"
                tabIndex={0}
                title={t({id:'catalogacao.stats.registeredAuthorsTitle'})}
                onClick={() => openCatalog('author')}
                onKeyDown={(e) => e.key === 'Enter' && openCatalog('author')}
              >
                {stats.authors}
              </div>
            </div>
            <div className="cat-stat">
              <div className="cat-stat-label">{t({id:'catalogacao.stats.publishedExemplars'})}</div>
              <div
                className="cat-stat-value clickable"
                role="button"
                tabIndex={0}
                title={t({id:'catalogacao.stats.publishedExemplarsTitle'})}
                onClick={() => openCatalog('exemplar')}
                onKeyDown={(e) => e.key === 'Enter' && openCatalog('exemplar')}
              >
                {stats.exemplares}
              </div>
            </div>
          </div>

          {/* ── Tabs ─────────────────────────────────────── */}
          <nav className="ab-tabbar" role="tablist">
            {TABS.map((tab) => (
              <button
                key={tab.id}
                className={`ab-tabbar__tab${tab.separator ? ' ab-tabbar__tab--group' : ''}${activeTab === tab.id ? ' active' : ''}`}
                onClick={() => switchTab(tab.id)}
                role="tab"
                aria-selected={activeTab === tab.id}
              >
                <AppIcon className="ab-tabbar__icon" name={tab.icon} size="1em" />
                {tab.label}
                {tab.count > 0 && <span className="ab-tabbar__badge" data-testid="tab-badge-divergences">{tab.count}</span>}
              </button>
            ))}
          </nav>

          {/* ── Panels ───────────────────────────────────── */}

          {/* 0. Catálogo(s) já publicado(s) — onglet de reference, en tete comme dans la barre */}
          <div className={`cat-panel${activeTab === 'catalogPanel' ? ' active' : ''}`}>
            <CatalogPanel onEdit={openForEdit} requestedView={catalogReq.view} requestNonce={catalogReq.nonce} onChanged={refreshAll} />
          </div>

          {/* 1. Documento */}
          <div className={`cat-panel${activeTab === 'booksPanel' ? ' active' : ''}`}>
            <div className="cat-panel-header">
              <h3>{t({id:'catalogacao.tab.documento'})}</h3>
            </div>
            <BookDraftForm panelActive={activeTab === 'booksPanel'} batches={batches} mode={mode} onSaved={refreshAll} onOpenBook={openBook} onAttachToBook={attachToBook} editingId={editTarget?.kind === 'book' ? editTarget.id : null} onConsumed={() => setEditTarget(null)} onNavigateTab={switchTab} onEditExemplar={editPublishedExemplar} onEditExemplarDraft={(id) => openForEdit('exemplar', id)} onOpenDraft={(id) => openForEdit('book', id)} />
          </div>

          {/* 2. Autoria */}
          <div className={`cat-panel${activeTab === 'authorsPanel' ? ' active' : ''}`}>
            <AuthorDraftForm mode={mode} batches={batches} editingId={editTarget?.kind === 'author' ? editTarget.id : null} onConsumed={() => setEditTarget(null)} onChanged={refreshAll} onNavigateTab={switchTab} />
          </div>

          {/* 3. Indexação (exemplar + rótulo) */}
          <div className={`cat-panel${activeTab === 'indexPanel' ? ' active' : ''}`}>
            <ExemplarDraftForm mode={mode} batches={batches} prefill={attachTarget} editingId={editTarget?.kind === 'exemplar' ? editTarget.id : null} onConsumed={() => setEditTarget(null)} onChanged={refreshAll} onNavigateTab={switchTab} />
          </div>

          {/* 3b. Etiquetas (impressão das etiquetas de cote) */}
          <div className={`cat-panel${activeTab === 'labelsPanel' ? ' active' : ''}`}>
            <LabelSheetPrinter onChanged={refreshAll} isActive={activeTab === 'labelsPanel'} />
          </div>

          {/* 3c. Fundo escaneado (OCR navegador) — piste B, flux d'ingestion distinct */}
          <div className={`cat-panel${activeTab === 'ocrPanel' ? ' active' : ''}`}>
            <div className="cat-panel-header">
              <h3>{t({id:'catalogacao.tab.ocr'})}</h3>
            </div>
            {activeTab === 'ocrPanel' && (
              <OcrDepositTab batches={batches} mode={mode} onSaved={refreshAll} />
            )}
          </div>

          {/* 4. Fila editorial */}
          <div className={`cat-panel${activeTab === 'queuePanel' ? ' active' : ''}`}>
            <QueuePanel batches={batches} onEditItem={openForEdit} onChanged={refreshAll} isActive={activeTab === 'queuePanel'} />
          </div>

          {/* 6. Lotes */}
          <div className={`cat-panel${activeTab === 'batchesPanel' ? ' active' : ''}`}>
            <div className="cat-panel-header">
              <h3>{t({id:'catalogacao.tab.lotes'})}</h3>
            </div>
            <BatchesPanel batches={batches} onRefresh={refreshAll} isCoord={isCoord} isNetworkAdmin={isNetworkAdmin} />
          </div>

          {/* 6 bis. Divergences à traiter (H21 lot 5) : notices partagées qu'un
              réimport a trouvées différentes, sans les réécrire. */}
          {voitDivergences && (
            <div className={`cat-panel${activeTab === 'divergencesPanel' ? ' active' : ''}`}>
              <DivergencesPanel isActive={activeTab === 'divergencesPanel'} onOpenDraft={(id) => openForEdit('book', id)}
                onCount={setNbDivergences} />
            </div>
          )}

          {/* 7. Coordenação de matéria (gouvernance thésaurus — étape 2c) */}
          <div className={`cat-panel${activeTab === 'materiaPanel' ? ' active' : ''}`}>
            <SubjectGovernancePanel />
          </div>

          {/* 7 bis. Coordination des titres de périodiques (#périodiques, 27/08).
              La LECTURE est ouverte à tout le staff catalogage — voir quels
              titres existent évite d'en recréer un doublon au catalogage ; les
              GESTES sont gardés serveur, et le panneau ne montre que ceux que
              l'appelant peut réellement poser. `isActive` : tous les panneaux
              restent montés, on ne charge qu'à l'ouverture. */}
          <div className={`cat-panel${activeTab === 'periodicosPanel' ? ' active' : ''}`}>
            <SerialGovernancePanel isActive={activeTab === 'periodicosPanel'} />
          </div>

          {/* 8. Assistant de dedoublonnage en trois temps (coordination).
              `isActive` est indispensable : tous les panneaux restent montes,
              et le balayage coute ~4 s — on ne le lance qu'a l'ouverture. */}
          {arbitreDoublons && (
            <div className={`cat-panel${activeTab === 'dedupPanel' ? ' active' : ''}`}>
              <DedupAssistantPanel isActive={activeTab === 'dedupPanel'} onChanged={refreshAll} />
            </div>
          )}
      </div>
      <Footer />
    </PageShell>
  );
}
