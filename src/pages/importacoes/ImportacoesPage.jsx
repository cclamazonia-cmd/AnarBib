import { useState, useEffect, useCallback, useMemo, useRef } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { useIntl } from 'react-intl';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import UserHeroBadge from '@/components/UserHeroBadge';
import AppIcon from '@/components/ui/AppIcon';
import HeroDocumentationActions from '@/components/HeroDocumentationActions';
import './ImportacoesPage.css';
import CandidatsPdfPanel from './CandidatsPdfPanel.jsx';
import ImportExportFace from './ImportExportFace.jsx';
import ImportRunsList from './ImportRunsList.jsx';
import ImportAdapterStrip from './ImportAdapterStrip.jsx';
import ImportAddRecords from './ImportAddRecords.jsx';
import ImportReviewQueue from './ImportReviewQueue.jsx';
import { pagesParExemplaires } from '../../lib/importItemUpdates.js';
import {
  formatDate, NON_COMPANHEIRA_KINDS, estSelectionnable, PAGE_COMPARAISON, lignesAComparer,
} from './importacoesOutils.jsx';

export default function ImportacoesPage() {
  useAuth();
  const { role, libraryId, isNetworkAdmin, libraryResolved } = useLibrary();
  const { formatMessage: t } = useIntl();
  useDocumentTitle(t({ id: 'importacoes.title' }));

  // ── Core UI state ──────────────────────────────────────
  // #tab=export ouvre le sens export ; #tab=arquivo|busca|oai ouvre l'import sur
  // cette origine (liens profonds, meme convention que Catalogage — 05/09/2026).
  const initialHash = (typeof window !== 'undefined' ? window.location.hash : '').replace('#tab=', '');
  // #tab=pdf ouvre la file des candidats PDF (NUMDIF D15, 15/10/2026).
  const [sentido, setSentido] = useState(['export', 'pdf'].includes(initialHash) ? initialHash : 'import');
  const [msg, setMsg] = useState({ text: '', kind: '' });

  // ── Data state ─────────────────────────────────────────
  const [sources, setSources] = useState([]);
  const [runs, setRuns] = useState([]);
  const [_runsLoading, setRunsLoading] = useState(false);
  const [selectedRunId, setSelectedRunId] = useState(null);
  const [runRows, setRunRows] = useState([]);
  const [runRowsLoading, setRunRowsLoading] = useState(false);

  const [filaStateFilter, setFilaStateFilter] = useState('');

  const [uploading, setUploading] = useState(false);
  // ── Enregistrer une source de dépôt sans entité partenaire ──────────
  // Voie volontairement plus pauvre que ExternalDepositPartnerSection : ici
  // on reçoit le fichier d'un collectif SANS l'admettre comme partenaire du
  // réseau (décision fédérale, parfois délibérément différée — cf. le fonds
  // Solidaires du 27/08/2026). Seule fn_import_register_deposit_source fait ça.
  const [newSourceOpen, setNewSourceOpen] = useState(false);
  const [destLibraries, setDestLibraries] = useState([]);
  // ── Adaptateur : overrides Estrutura / Vocabulário / Encodage ('auto' = laisser l'auto-détection) ──
  const [adapterFormat, setAdapterFormat] = useState('auto');
  const [adapterVocabulary, setAdapterVocabulary] = useState('auto');
  // H15 (26/09/2026) : sans forçage, l'EF lit en UTF-8 strict puis SUPPOSE
  // windows-1252 (latin-1) et le dit ; forcer sert quand la supposition est fausse.
  const [adapterEncoding, setAdapterEncoding] = useState('auto');
  // ── Profils d'import (axe Perfil) ──────────────────────
  const [adapterProfile, setAdapterProfile] = useState(''); // '' = Padrão (aucun)
  const [profiles, setProfiles] = useState([]);


  // ── OAI-PMH harvesting ────────────────────────────────
  const [oaiSources, setOaiSources] = useState([]);
  const [oaiLoading, setOaiLoading] = useState(false);


  // ── Load sources via Lot 0 API ─────────────────────────
  const loadSources = useCallback(async () => {
    try {
      const { data, error } = await supabase.rpc('fn_import_list_sources');
      if (!error && data) setSources(data);
    } catch { /* guard */ }
  }, []);

  // ── Load runs via Lot 0 API ────────────────────────────
  const loadRuns = useCallback(async () => {
    setRunsLoading(true);
    try {
      const { data, error } = await supabase.rpc('fn_import_list_runs');
      if (!error && data) setRuns(data);
    } catch { /* guard */ }
    finally { setRunsLoading(false); }
  }, []);

  // ── Load run rows via Lot 0 API ────────────────────────
  const loadRunRows = useCallback(async (runId) => {
    if (!runId) return;
    setRunRowsLoading(true);
    setRunRows([]);
    try {
      const { data, error } = await supabase.rpc('fn_import_list_run_rows', { p_run_id: Number(runId) });
      if (!error && data) {
        setRunRows(data);
        // Revue du lot 0 (29/09/2026) : une ligne qui n'est plus cochable
        // (promue, rapprochée ou rejetée entre-temps, dans un autre onglet) sort
        // de la sélection — sinon sa case, cachée, ne se décoche plus et
        // « Rejeter » la renverrait à chaque clic. Ici, une fois les lignes
        // arrivées : jamais sur la liste vide du rechargement.
        const encore = new Set(data.filter(estSelectionnable).map(r => r.id));
        setSelectedRows(prev => {
          if (!prev.size) return prev;
          const next = new Set([...prev].filter(id => encore.has(id)));
          return next.size === prev.size ? prev : next;
        });
      } else {
        // Chargement échoué : aucune ligne n'est affichée, la sélection ne
        // désigne plus rien de visible (et le filet « doublons » de « Rejeter »
        // ne verrait rien).
        setSelectedRows(new Set());
      }
    } catch { setSelectedRows(new Set()); }
    finally { setRunRowsLoading(false); }
  }, []);

  // ── Load OAI sources ────────────────────────────────────
  const loadOaiSources = useCallback(async () => {
    setOaiLoading(true);
    try {
      const { data, error } = await supabase.rpc('fn_import_list_oai_sources');
      if (!error && data) setOaiSources(data);
    } catch { /* guard */ }
    finally { setOaiLoading(false); }
  }, []);

  // ── H21 lot 3 : comparer les lignes « Déjà importées », par pages ──
  // La coordination ou l'administration seulement (le recalcul leur est
  // réservé, comme les décisions) ; une ligne n'est demandée qu'une fois par
  // ouverture de l'écran (pas de boucle si une ligne reste sans comparaison).
  // Les comptes rendus par la RPC sont posés sur les lignes, sans recharger
  // (la sélection en cours n'est pas touchée).
  const peutComparer = role === 'coordenador' || !!isNetworkAdmin;
  const comparaisonsDemandees = useRef(new Set());
  useEffect(() => {
    if (!peutComparer || !selectedRunId || runRowsLoading) return;
    const ids = lignesAComparer(runRows).filter(id => !comparaisonsDemandees.current.has(`${selectedRunId}:${id}`));
    if (!ids.length) return;
    ids.forEach(id => comparaisonsDemandees.current.add(`${selectedRunId}:${id}`));
    const runId = selectedRunId;
    // H21 lot 6b : pages de 200 lignes ET de 5 000 exemplaires du fichier au plus
    const parId = new Map(runRows.map(r => [r.id, r]));
    const pages = pagesParExemplaires(ids.map(id => parId.get(id) || { id }), PAGE_COMPARAISON);
    (async () => {
      for (const page of pages) {
        try {
          const { data, error } = await supabase.rpc('fn_import_recomparer', { p_run_id: Number(runId), p_row_ids: page });
          if (error || !data || !Array.isArray(data.rows)) return;
          const comptes = new Map(data.rows.map(x => [x.id, x]));
          // H21 lot 6b : la comparaison des exemplaires (exemplaires_maj) avec
          // les comptes de la notice, quand le serveur la rend.
          setRunRows(prev => prev.map(r => (r.run_id === runId && comptes.has(r.id)
            ? { ...r, comparison_counts: comptes.get(r.id).counts,
                ...(Object.prototype.hasOwnProperty.call(comptes.get(r.id), 'exemplaires_maj')
                  ? { exemplaires_maj: comptes.get(r.id).exemplaires_maj } : {}) }
            : r)));
        } catch { return; }
      }
    })();
  }, [peutComparer, selectedRunId, runRows, runRowsLoading]);

  useEffect(() => { loadSources(); loadRuns(); loadOaiSources(); }, [loadSources, loadRuns, loadOaiSources]);

  // Refresh manuel : le traitement (parse + matching) est asynchrone côté EF ;
  // les compteurs/états ne se mettent pas à jour en direct. Ce bouton recharge.
  const [refreshing, setRefreshing] = useState(false);
  const [rowLimit, setRowLimit] = useState(50);
  // Validation par-ligne : sélection de nouveautés à promouvoir en lot.
  const [selectedRows, setSelectedRows] = useState(() => new Set());
  const [filaMatchFilter, setFilaMatchFilter] = useState('');
  async function handleRefresh() {
    setRefreshing(true);
    try {
      await Promise.all([loadSources(), loadRuns(), loadOaiSources()]);
      if (selectedRunId) await loadRunRows(selectedRunId);
    } finally { setRefreshing(false); }
  }

  // ── Derived data (hooks must be before early returns) ──
  const runStats = useMemo(() => {
    const total = runs.length;
    const draftsCreated = runs.filter(r => r.run_status === 'drafts_created').length;
    const pending = runs.filter(r => r.run_status === 'ready_for_review').length;
    const totalRows = runs.reduce((s, r) => s + (r.imported_rows || 0), 0);
    return { total, draftsCreated, pending, totalRows };
  }, [runs]);




  // H21 lot 4 : les lignes dont le détail champ par champ est ouvert.
  const [detailsOuverts, setDetailsOuverts] = useState(() => new Set());
  useEffect(() => { setDetailsOuverts(new Set()); }, [selectedRunId]);

  // Réinitialise pagination + sélection quand on change de run ou de filtre.
  useEffect(() => { setRowLimit(50); setSelectedRows(new Set()); }, [selectedRunId, filaStateFilter, filaMatchFilter]);

  // Profils d'import de la biblio (axe Perfil de l'adaptateur).
  useEffect(() => {
    if (!libraryId) return undefined;
    let active = true;
    supabase.rpc('fn_import_profiles_list', { p_library_id: libraryId }).then(({ data, error }) => {
      if (!active) return;
      if (!error && data) setProfiles(Array.isArray(data) ? data : []);
    });
    return () => { active = false; };
  }, [libraryId]);

  // ── Role gating ────────────────────────────────────────
  // Rôle connu, OU résolution finie sans rôle (compte sans bibliothèque) :
  // sinon un tel compte chargeait sans fin (05/10/2026).
  const roleLoaded = (role !== null && role !== undefined) || libraryResolved;
  // IMP-14 : import/export sous l'autorité des coordinateurs (aligné sur le
  // backend fn_import_* coordenador-only + la nav canSeeImportacoes=isCoord).
  // Les librarians sont volontairement exclus ici.
  const canImport = role === 'coordenador' || role === 'administrador' || isNetworkAdmin;
  // 04/09/2026 : deposer le catalogue d'une bibliotheque COMPAGNE (source
  // partner_deposit) engage le reseau — la biblio ne detient pas ces livres,
  // et la publication leur donnera quand meme une biblio de destination. Ce
  // geste passe a l'administration du reseau ; la coordination garde son
  // propre catalogue (own_catalog). Miroir des gardes fn_import_create /
  // fn_import_promote / fn_import_register_deposit_source (HINT
  // error.import.deposit_admin_only).
  const canDeposit = isNetworkAdmin;
  useEffect(() => {
    if (!newSourceOpen || !canDeposit) return undefined;
    let active = true;
    supabase.from('libraries').select('id, name').order('name').then(({ data, error }) => {
      if (active && !error && data) setDestLibraries(data);
    });
    return () => { active = false; };
  }, [newSourceOpen, canDeposit]);

  if (!roleLoaded) return (
    <PageShell><Topbar />
      <div style={{ textAlign: 'center', padding: 60, color: 'var(--brand-muted)' }}>{t({ id: 'common.loading' })}</div>
    <Footer /></PageShell>
  );

  if (!canImport) return (
    <PageShell><Topbar />
      <Hero title={t({ id: 'importacoes.title' })} subtitle={t({ id: 'importacoes.restricted' })} />
    <Footer /></PageShell>
  );



























  // ── Pill helper ────────────────────────────────────────
  function Pill({ children, variant = 'muted' }) {
    return <span className={`cat-pill ${variant}`}>{children}</span>;
  }

  // ══════════════════════════════════════════════════════════
  //  RENDER
  // ══════════════════════════════════════════════════════════
  return (
    <PageShell><Topbar />

      <Hero title={t({ id: 'importacoes.title' })} subtitle={t({ id: 'importacoes.v7.subtitle' })}>
        <UserHeroBadge />
        <HeroDocumentationActions />
      </Hero>

      <div className="imp-wrap">

        {/* ── Message bar ───────────────────────────────── */}
        {msg.text && (
          <div className={`cat-message ${msg.kind}`} style={{ marginBottom: 14 }}>
            {msg.text}
            <button onClick={() => setMsg({ text: '', kind: '' })} style={{ marginLeft: 'auto', background: 'none', border: 0, color: 'inherit', cursor: 'pointer', fontSize: '1.1rem' }}>×</button>
          </div>
        )}

        {/* ── Sens : deux vrais onglets (E12 lot C) ──────────────
            L'ancien commutateur « Sens » était si discret que l'export n'avait,
            aux yeux de qui cherche, pas d'adresse. La barre de pastilles partagée
            `.ab-tabbar` (src/styles/tabbar.css) est celle de toutes les pages à
            onglets : on la reconnaît, et elle se voit. */}
        <nav className="ab-tabbar" role="tablist" aria-label={t({ id: 'importacoes.sentido.label' })} style={{ marginBottom: 10 }}>
          <button className={`ab-tabbar__tab${sentido === 'import' ? ' active' : ''}`}
            role="tab" aria-selected={sentido === 'import'} onClick={() => setSentido('import')}>
            <AppIcon className="ab-tabbar__icon" name="inbox" size="1em" />
            {t({ id: 'importacoes.sentido.import' })}
          </button>
          <button className={`ab-tabbar__tab${sentido === 'export' ? ' active' : ''}`}
            role="tab" aria-selected={sentido === 'export'} onClick={() => setSentido('export')}>
            <AppIcon className="ab-tabbar__icon" name="arrowUp" size="1em" />
            {t({ id: 'importacoes.sentido.export' })}
          </button>
          <button className={`ab-tabbar__tab${sentido === 'pdf' ? ' active' : ''}`}
            role="tab" aria-selected={sentido === 'pdf'} onClick={() => setSentido('pdf')}>
            <AppIcon className="ab-tabbar__icon" name="document" size="1em" />
            {t({ id: 'importacoes.sentido.pdf' })}
          </button>
        </nav>
        <p className="imp-sentido__hint" style={{ margin: '0 0 16px' }}>
          {t({ id: 'importacoes.sentido.hint' })}
        </p>

        {/* ════════════════════════════════════════════════ */}
        {/*  FACE IMPORT                                    */}
        {/* ════════════════════════════════════════════════ */}
        {/* E6 (23/10/2026) : la face Import et ses sections (ImportAdapterStrip,
            ImportAddRecords, ImportRunsList, ImportReviewQueue) — montée toujours,
            masquée hors de son onglet : filtres, sélection et recherches gardent leur
            état au passage par l'onglet Export, comme quand il vivait dans la page. */}
        <div hidden={sentido !== 'import'}>

          {/* ── Frontier banner ─────────────────────────── */}
          <div className="imp-frontier">
            <span aria-hidden="true">⇄</span>
            <div>
              <b>{t({ id: 'importacoes.import.frontier.title' })}</b>{' '}
              {t({ id: 'importacoes.import.frontier.desc' })}
            </div>
          </div>

          {/* ── CTA : assistant « Novo import » (wizard IMP-8) ─── */}
          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginBottom: 14 }}>
            <button className="cat-btn secondary" type="button" onClick={handleRefresh} disabled={refreshing}>
              {refreshing ? t({ id: 'importacoes.refreshing' }) : t({ id: 'importacoes.refresh' })}
            </button>
            <Link to="/importacoes/novo" style={{ textDecoration: 'none' }}>
              <button className="cat-btn primary" type="button">
                {t({ id: 'importacoes.wizard.launch' })}
              </button>
            </Link>
          </div>

          {/* ── Adapter strip (read-only) ───────────────── */}
          <ImportAdapterStrip {...{
            adapterEncoding, adapterFormat, adapterProfile, adapterVocabulary, libraryId, profiles,
            setAdapterEncoding, setAdapterFormat, setAdapterProfile, setAdapterVocabulary, setMsg,
            setProfiles, uploading,
          }} />
          {/* ── Tableau de bord ─────────────────────────── */}
          <div className="imp-sheet" style={{ marginBottom: 18 }}>
            <div className="imp-sheet__head">
              <span className="imp-sheet__title">{t({ id: 'importacoes.dashboard.title' })}</span>
            </div>
            <div className="imp-sheet__body">
              <div className="imp-stats">
                <div className="imp-stat"><div className="imp-stat__n">{runStats.total}</div><div className="imp-stat__l">{t({ id: 'importacoes.stat.runs' })}</div></div>
                <div className="imp-stat"><div className="imp-stat__n">{runStats.totalRows}</div><div className="imp-stat__l">{t({ id: 'importacoes.stat.stagingRows' })}</div></div>
                <div className="imp-stat"><div className="imp-stat__n">{runStats.pending}</div><div className="imp-stat__l">{t({ id: 'importacoes.stat.pending' })}</div></div>
                <div className="imp-stat"><div className="imp-stat__n">{runStats.draftsCreated}</div><div className="imp-stat__l">{t({ id: 'importacoes.stat.promoted' })}</div></div>
              </div>
            </div>
          </div>

          {/* ── Adicionar registros (origine unique : fichier / busca / oai) ── */}
          <ImportAddRecords {...{
            adapterEncoding, adapterFormat, adapterProfile, adapterVocabulary, canDeposit,
            destLibraries, initialHash, loadOaiSources, loadRuns, loadSources, newSourceOpen,
            oaiLoading, oaiSources, setMsg, setNewSourceOpen, setUploading, sources, uploading,
          }} />
          {/* ── Lotes de importação (liste unique : archiver / supprimer) ── */}
          <ImportRunsList {...{
            loadRunRows, loadRuns, runs, selectedRunId, setMsg, setRunRows, setSelectedRunId,
          }} />
          {/* ── Fontes parceiras (référence : qui autorise l'import) ── */}
          {/* La source « Recherche institutionnelle », créée automatiquement par
              fn_import_ingest_candidate, n'est pas une companheira : personne n'a
              rien accordé. Le filtre visait 'institutional', valeur qu'aucune
              ligne ne porte — le vrai source_kind est 'institutional_lookup'.
              Le masquage ne marchait donc pas ; ça ne se voyait pas tant que la
              RPC était cassée et qu'aucune source de ce type n'existait. */}
          {sources.filter(s => !NON_COMPANHEIRA_KINDS.includes(s.source_kind)).length > 0 && (
            <div className="imp-sheet">
              <div className="imp-sheet__head">
                <span className="imp-sheet__title">
                  {t({ id: 'importacoes.fontes.companheiras' })}
                  <Pill>{t({ id: 'importacoes.fontes.consentFirst' })}</Pill>
                </span>
              </div>
              <div className="imp-sheet__body">
                <div className="imp-partners">
                  {sources.filter(s => !NON_COMPANHEIRA_KINDS.includes(s.source_kind)).map(s => (
                    <div key={s.id} className="imp-pcard">
                      <div className="imp-pcard__top">
                        <h4>{s.partner_name}</h4>
                        {/* E12 lot A : le statut de relation est un code du vocabulaire
                            partner_catalog_sources_relation_status_check ; il se traduit,
                            il ne s'affiche pas brut (repli sur le code si une valeur
                            neuve arrive avant sa clé). */}
                        <span className="imp-rel-badge">{s.relation_status ? t({ id: `importacoes.fontes.relation.${s.relation_status}`, defaultMessage: s.relation_status }) : '—'}</span>
                      </div>
                      <div className="imp-flags">
                        <span className={`imp-flagchip ${s.import_enabled ? 'imp-flagchip--on' : 'imp-flagchip--off'}`}>
                          {t({ id: 'importacoes.fontes.flag.import' })}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* ── Fila de revisão ───────────────────────────── */}
          <ImportReviewQueue {...{
            canDeposit, detailsOuverts, filaMatchFilter, filaStateFilter, handleRefresh,
            loadRunRows, loadRuns, peutComparer, refreshing, rowLimit, runRows, runRowsLoading,
            runs, selectedRows, selectedRunId, setDetailsOuverts, setFilaMatchFilter,
            setFilaStateFilter, setMsg, setRowLimit, setRunRows, setSelectedRows, setSelectedRunId,
            sources,
          }} />
          {/* ── Diário de importação ──────────────────────── */}
          <div className="imp-sheet">
            <div className="imp-sheet__head">
              <span className="imp-sheet__title">
                {t({ id: 'importacoes.diario.title' })}
              </span>
            </div>
            <div className="imp-sheet__body">
              {runs.length === 0 && <p className="imp-note">{t({ id: 'importacoes.history.empty' })}</p>}
              <ul className="imp-timeline">
                {runs.slice(0, 10).map(r => (
                  <li key={r.id}>
                    <span className="imp-timeline__when">{formatDate(r.created_at)}</span>
                    <div className="imp-timeline__ev">
                      <b>{r.run_status === 'drafts_created' ? t({ id: 'importacoes.diario.promoted' }) : t({ id: 'importacoes.diario.runCreated' })}</b>
                      {' — '}{r.original_filename || t({ id: 'importacoes.noFile' })}
                      {r.source_name && ` (${r.source_name})`}
                      <div className="imp-timeline__meta">
                        <Pill>{r.detected_format || '—'}</Pill>
                        {r.imported_rows != null && <Pill>{t({ id: 'importacoes.rowsCount' }, { count: r.imported_rows })}</Pill>}
                        {r.created_drafts != null && r.created_drafts > 0 && <Pill variant="ok">{t({ id: 'importacoes.draftsCount' }, { count: r.created_drafts })}</Pill>}
                      </div>
                    </div>
                  </li>
                ))}
              </ul>
            </div>
          </div>

        </div>

        {/* ════════════════════════════════════════════════ */}
        {/*  FACE EXPORT (placeholder — Lot 5)              */}
        {/* ════════════════════════════════════════════════ */}
        {/* ── Candidats PDF (NUMDIF D15) : l'outil propose, la coordination décide ── */}
        {sentido === 'pdf' && <CandidatsPdfPanel libraryId={libraryId} />}

        {/* E6 (23/10/2026) : la face Export vit dans ImportExportFace.jsx — montée
            toujours, masquée hors de son onglet : ses listes chargées survivent à
            un passage par l'onglet Import, comme avant le découpage. */}
        <div hidden={sentido !== 'export'}>
          <ImportExportFace {...{
            libraryId, setMsg,
          }} />
        </div>
      </div>
    <Footer /></PageShell>
  );
}
