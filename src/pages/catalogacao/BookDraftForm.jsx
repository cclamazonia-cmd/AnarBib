import { useIntl } from 'react-intl';
import { useConfirm } from '@/contexts/ConfirmContext';
import { useState, useEffect, useMemo, useRef, useCallback } from 'react';
import { supabase, SUPABASE_URL } from '@/lib/supabase';
import SubjectAuthorityPicker from './SubjectAuthorityPicker';
import { useStaffLibraries, bibliothequesProposables, lotsProposables, lotDeLaBibliotheque, libelleLot } from '@/lib/useStaffLibraries';
import SerialAuthorityPicker from './SerialAuthorityPicker';
import AudioSegmentsBlock from './AudioSegmentsBlock';
import WorkToolsBlock from './WorkToolsBlock';
import { ApercuFusion } from './DedupAssistantPanel';
import DigitalResourcesPanel from './DigitalResourcesPanel';
import LookupPanel from './LookupPanel';
import ContributorsPanel from './ContributorsPanel';
import ReviewPanel from './ReviewPanel';
import ShelfLabelPreview from './ShelfLabelPreview';
import InitialCopiesBlock from './InitialCopiesBlock';
import ReassignPanel from './ReassignPanel';
import InfoCards from './InfoCards';
import TitleCaseAssist from '@/components/catalog/TitleCaseAssist';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { useSaveConfirmation } from '@/hooks/useSaveConfirmation';
import CatalogStatusBar from '@/components/catalog/CatalogStatusBar';
import AfterPublishPanel from './AfterPublishPanel';
import { useUntouchedRetake } from '@/hooks/useUntouchedRetake';
import { localizeError } from '@/lib/localizeError';
import { canArbitrateDuplicates } from '@/lib/dedupRoles';
import { writeCoverThumb, removeCoverThumb, cheminCapaNeuf, nomCapaNeuf, extensionCapa } from '@/lib/coverThumbs';
import { messageRechercheCapas, accordEdition, parIsbn, etiquetteCandidate, ordonnerCandidates } from '@/lib/coverSources';
import { volumesDifferents } from '@/lib/volumes';
import { visibleGroups, tierFromMode } from './fieldRegistry.js';
import { renderMaterialSection, renderRegistryField } from './CatalogFieldRenderer.jsx';
import Modal from '@/components/ui/Modal';

// Constantes et fonctions pures du formulaire : src/lib/catalogacao/bookDraft.js (E6, lot 1)
import { MATERIAL_TYPE_KEYS, SERIAL_TYPES, TRACT_TYPES, NON_LOANABLE_TYPES, MATERIAL_SECTION_IDS, roleKeysForMaterial, AUTHOR_DISPLAY_ROLES, PDFJS_BASE, loadPdfjsCat, inferContributorRole, autoMatchContributors, EMPTY_FORM, construireZonesIsbd } from '@/lib/catalogacao/bookDraft';

// ═══════════════════════════════════════════════════════════
// BookDraftForm
// ═══════════════════════════════════════════════════════════

export default function BookDraftForm({ batches = [], mode = 'simple', onSaved, onOpenBook, onAttachToBook, editingId = null, onConsumed, onNavigateTab, onEditExemplar, prefillRecord = null, prefillFile = null, panelActive = true }) {
  const { formatMessage: t } = useIntl();
  const confirmer = useConfirm();
  const { user } = useAuth();
  const { isNetworkAdmin, libraryId, effectiveRole } = useLibrary();
  // B29 (CAT-E18) : un brouillon se range dans une bibliothèque où l'on est staff.
  const { staffLibraryIds, loaded: staffConnu } = useStaffLibraries();
  // Paquet DOUBLONS P4 (21/08/2026) : fusionner et ecarter sont reserves a la
  // coordination. Le poste de catalogage garde « Meme oeuvre » et le signalement.
  const arbitreDoublons = canArbitrateDuplicates(effectiveRole);

  // Attribution réseau (admin réseau) : notice + exemplaires → bibliothèque cible
  const [catalogLibraries, setCatalogLibraries] = useState([]);

  // i18n-aware lists built from t()
  const MATERIAL_TYPES = useMemo(() => MATERIAL_TYPE_KEYS.map(k => ({ value: k, label: t({ id: `catalogacao.material.${k}` }) })), [t]);
  const roleLabel = useCallback((k) => t({ id: `catalogacao.role.${k}` }), [t]);

  // Admin réseau : charge les bibliothèques cibles (catalogue présent).
  useEffect(() => {
    if (!isNetworkAdmin) return;
    let cancelled = false;
    supabase.rpc('list_catalog_libraries').then(({ data }) => {
      if (!cancelled && Array.isArray(data)) setCatalogLibraries(data);
    });
    return () => { cancelled = true; };
  }, [isNetworkAdmin]);

  const [form, setForm] = useState({ ...EMPTY_FORM });
  const [msg, setMsg] = useState({ text: '', kind: '' });
  // Un enregistrement se confirme dans la barre d'état collante, doublé d'un toast.
  const confirmSaved = useSaveConfirmation(setMsg);
  // Une reprise quittée sans enregistrement s'oublie (migration 20261003202521).
  const trackRetake = useUntouchedRetake('book', form.id);

  // H19 (27/09/2026) : une notice importée porte ses exemplaires du fichier
  // (995/852). Ils sont publiés avec elle, À LA PLACE des exemplaires initiaux,
  // dans la bibliothèque qui leur a été attribuée : le nombre et le choix de
  // bibliothèque ci-dessous ne s'appliquent pas, l'écran le dit.
  const [importedItems, setImportedItems] = useState(0);
  // Relu à chaque chargement de la notice (fillFromRecord), pas seulement quand
  // son id change : une fusion ou un écart faits dans la file entre-temps.
  const [importedCheck, setImportedCheck] = useState(0);
  useEffect(() => {
    const id = Number(form.id);
    if (!id || form.published_book_id) { setImportedItems(0); return undefined; }
    let cancelled = false;
    (async () => {
      const { count } = await supabase.from('exemplar_drafts')
        .select('id', { count: 'exact', head: true })
        .eq('book_draft_id', id).in('status', ['draft', 'ready']);
      if (!cancelled) setImportedItems(count || 0);
    })();
    return () => { cancelled = true; };
  }, [form.id, form.published_book_id, importedCheck]);
  // IMP-25 (28/09/2026) : un fichier MARC lu avec sa zone d'exemplaire (995 /
  // 852) qui n'en décrit aucun pour cette notice — la publication n'en crée pas
  // (publish_book_draft). Un CSV ou un RIS garde l'exemplaire automatique.
  const fichierSansExemplaire = useMemo(() => {
    try { return !!JSON.parse(form.marc_json || '{}')?.ingest?.raw_payload?.item_tag; } catch { return false; }
  }, [form.marc_json]);

  // La barre d'état est collante (04/10/2026) : plus besoin de faire défiler
  // jusqu'au message, il est toujours visible.
  const showMsg = useCallback((text, kind) => setMsg({ text, kind }), []);
  const [dupBanner, setDupBanner] = useState(null); // { bookId } | null — doublon ISBN détecté au publish
  const [dupModal, setDupModal] = useState(null); // { kind, detail, bookId } | null — modale d'avertissement doublon AVANT sauvegarde du brouillon
  const [lastPublished, setLastPublished] = useState(null); // { bookId, title, workId, autor } | null — « Publié — et maintenant ? » (AfterPublishPanel)
  const [isbnDupHint, setIsbnDupHint] = useState(null); // { bookId, titulo, bibRef, libraries } | null — live ISBN check
  const [pubSuggestions, setPubSuggestions] = useState([]); // publisher typeahead results
  // Doublons de documents (detection + fusion, P2a/P2b)
  const [bookDupMatches, setBookDupMatches] = useState(null); // null = pas cherche
  const [bookDupLoading, setBookDupLoading] = useState(false);
  const [bookDupBusy, setBookDupBusy] = useState(null); // book_id en cours de fusion
  // Œuvre rattachée (P4) : { id, uniform_title, count } | null
  const [work, setWork] = useState(null);
  const [workBusy, setWorkBusy] = useState(false);
  const [workNonce, setWorkNonce] = useState(0);
  // P4 v2 : suggestions d'éditions à regrouper (même auteur·rice + titre proche)
  const [editionSugg, setEditionSugg] = useState(null); // null = pas cherché
  const [editionSuggLoading, setEditionSuggLoading] = useState(false);
  // 28/09/2026 (décision Xavier) : une édition suggérée qui est en fait la MÊME
  // édition (année fautive : BTL-TL-000880/881) se fusionne d'ici, par l'aperçu
  // de l'assistant — la détection de doublons, elle, garde sa règle stricte.
  // { bookId, titulo, apercu, saisie, reprises } ; la survivante est la notice éditée.
  const [fusionEdition, setFusionEdition] = useState(null);
  const [fusionBusy, setFusionBusy] = useState(false);
  const [champsInterdits, setChampsInterdits] = useState([]); // demandés à la base, une fois
  // Pop-up de création : œuvre nouvelle vs nouvelle édition d'une œuvre existante
  const [creationChoice, setCreationChoice] = useState(null); // null (non choisi) | 'work' | 'edition'
  const [linkedWorkLabel, setLinkedWorkLabel] = useState(''); // titre de l'œuvre rattachée (affichage)
  const [editionQuery, setEditionQuery] = useState('');
  const [editionResults, setEditionResults] = useState([]);
  const [editionSearching, setEditionSearching] = useState(false);
  const [saving, setSaving] = useState(false);
  const [draftState, setDraftState] = useState('new'); // new | saved | dirty | ready | published


  // ── Cover upload state ─────────────────────────────────
  const [coverFile, setCoverFile] = useState(null);
  const [coverPreviewUrl, setCoverPreviewUrl] = useState('');
  const [coverUploading, setCoverUploading] = useState(false);
  // ── Cover lookup state (capas P2) ──────────────────────
  const [coverLookupLoading, setCoverLookupLoading] = useState(false);
  // {thumbnailUrl, thumbnailData, fullUrl, source, license}
  // thumbnailData = l'aperçu rapatrié côté serveur, seul à finir dans un `src`.
  const [coverCandidates, setCoverCandidates] = useState([]);
  const [coverStoring, setCoverStoring] = useState(''); // fullUrl en cours d'enregistrement
  const [coverPdfBusy, setCoverPdfBusy] = useState(false); // generation capa depuis page 1 PDF

  // ── Contributors state ─────────────────────────────────
  const [contributors, setContributors] = useState([
    { position: 1, name: '', role: 'autor', is_primary: true, author_id: null, author_label: '' },
  ]);
  // H18 (revue du 28/09) : un rattachement fait dans le rapport du lot
  // (ContributorCandidates) sur le brouillon ouvert ici : le formulaire, toujours
  // monté, le reprend — sinon son prochain enregistrement (qui réécrit les
  // contributeurs) l'effaçait sans bruit.
  useEffect(() => {
    function surRattachement(e) {
      const d = e?.detail || {};
      if (!d.draftId || String(d.draftId) !== String(form.id ?? '')) return;
      setContributors(prev => prev.map(c => (!c.author_id && (c.name || '').trim() === d.name)
        ? { ...c, author_id: d.authorId, author_label: d.authorLabel || '', nature: c.nature ?? d.nature ?? null }
        : c));
    }
    window.addEventListener('anarbib:draft-contributor-linked', surRattachement);
    return () => window.removeEventListener('anarbib:draft-contributor-linked', surRattachement);
  }, [form.id]);
  // Sélecteur d'autorité (volet préventif) : un panneau de recherche ouvert à la fois

  // ── ISBD state ─────────────────────────────────────────
  const [isbdEnabled, setIsbdEnabled] = useState(false);
  const [isbdData, setIsbdData] = useState(null);

  // ── Digital resources state ────────────────────────────
  const [digitalResources, setDigitalResources] = useState([]);

  // ── Field helpers ──────────────────────────────────────
  // -- Lot 0 -- charger un brouillon a editer (handoff catalogo/fila -> editeur) --
  useEffect(() => {
    if (!editingId) return;
    let cancelled = false;
    (async () => {
      try {
        const { data, error } = await supabase.from('book_drafts').select('*').eq('id', Number(editingId)).single();
        if (cancelled) return;
        if (error) throw error;
        if (data) fillFromRecord(data);
      } catch (e) {
        if (!cancelled) setMsg({ text: t({ id: 'catalogacao.msg.loadDraftError' }, { message: localizeError(e, t) }), kind: 'error' });
      } finally {
        if (!cancelled) onConsumed?.();
      }
    })();
    return () => { cancelled = true; };
  }, [editingId]);

  // ── P3 : réinitialiser l'état transitoire de couverture au changement de fiche ──
  // (sinon les vignettes/preview d'une édition « bavent » sur l'édition suivante du
  //  même titre, la recherche de cover étant par titre).
  useEffect(() => {
    setCoverPreviewUrl('');
    setCoverCandidates([]);
    setCoverFile(null);
  }, [editingId]);

  // ── Œuvre rattachée (P4) : charge l'œuvre du livre publié + nb d'éditions ──
  useEffect(() => {
    const bid = form.published_book_id;
    if (!bid) { setWork(null); return; }
    let alive = true;
    (async () => {
      try {
        const { data: bk } = await supabase.from('books').select('work_id').eq('id', Number(bid)).maybeSingle();
        if (!alive) return;
        if (!bk?.work_id) { setWork(null); return; }
        const [{ data: w }, headRes] = await Promise.all([
          supabase.from('works').select('id, uniform_title').eq('id', bk.work_id).maybeSingle(),
          supabase.from('books').select('id', { count: 'exact', head: true }).eq('work_id', bk.work_id),
        ]);
        if (!alive) return;
        setWork(w ? { id: w.id, uniform_title: w.uniform_title, count: headRes.count || 0 } : null);
      } catch { if (alive) setWork(null); }
    })();
    return () => { alive = false; };
  }, [form.published_book_id, workNonce]);

  // ── Pré-remplissage OCR (piste B, P3b) ─────────────────────
  // Quand le composant est monté depuis le dépôt OCR (et non en édition d'un
  // brouillon existant), on amorce le formulaire avec les champs heuristiques
  // et on retient le PDF déposé pour le rattacher automatiquement au save.
  const ocrFileRef = useRef(null);
  const prefillSeededRef = useRef(false);
  useEffect(() => {
    if (editingId || prefillSeededRef.current || !prefillRecord) return;
    prefillSeededRef.current = true;
    fillFromRecord(prefillRecord);
    ocrFileRef.current = prefillFile || null;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [prefillRecord, editingId]);

  // Rattache le PDF scanné (déposé via le dépôt OCR) à un brouillon fraîchement
  // créé : upload dans le bucket public + insertion de la ressource numérique.
  // Réutilise exactement la convention de uploadDigitalFile (books/<id>/...).
  // 05/10/2026 : le scan déposé depuis l'OCR allait TOUJOURS dans l'espace
  // public, quels que soient ses droits — un scan sous droits devenait lisible
  // par quiconque avait l'URL. Il part désormais en accès réservé (bibliothèques
  // détentrices), droits à préciser dans le panneau des ressources numériques ;
  // le passer en public reste un choix explicite.
  async function attachOcrPdf(draftId, file) {
    if (!draftId || !file) return;
    const bucket = 'pdf-restrito';
    const safe = file.name.normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-zA-Z0-9._-]/g, '_');
    const path = `books/${draftId}/${Date.now()}_${safe}`;
    const { error: upErr } = await supabase.storage.from(bucket).upload(path, file, { upsert: false, contentType: 'application/pdf' });
    if (upErr) throw upErr;
    const { error: insErr } = await supabase.from('book_draft_digital_resources').insert({
      book_draft_id: Number(draftId),
      resource_type: 'pdf_restrito',
      usage_type: 'leitura_online',
      access_scope: 'conta_ativa',
      status: 'draft',
      is_active: true,
      storage_bucket: bucket,
      storage_path: path,
      mime_type: 'application/pdf',
      is_primary: true,
      // Déposé depuis la notice elle-même : la correspondance est acquise
      // (avant : jamais posée, et le PDF restait invisible sur la fiche).
      bibliographic_match_validated: true,
      label: file.name,
    });
    if (insErr) throw insErr;
  }

  function f(key) { return form[key] || ''; }
  function set(key, value) {
    setForm(prev => ({ ...prev, [key]: value }));
    if (draftState === 'saved' || draftState === 'ready') setDraftState('dirty');
  }

  // ── Live ISBN duplicate check (debounced 600ms) ─────────
  useEffect(() => {
    const raw = (form.isbn || '').replace(/[^0-9Xx]/g, '').toUpperCase();
    if (raw.length < 10) { setIsbnDupHint(null); return; }
    const publishedId = form.published_book_id;
    const timer = setTimeout(async () => {
      try {
        const { data } = await supabase.from('books')
          .select('id, titulo, bib_ref, owner_library_id, libraries:owner_library_id(name)')
          .ilike('isbn', `%${raw}%`)
          .limit(3);
        const match = (data || []).find(b => !publishedId || String(b.id) !== String(publishedId));
        if (match) {
          const libName = match.libraries?.name || '';
          setIsbnDupHint({ bookId: match.id, titulo: match.titulo, bibRef: match.bib_ref, library: libName });
        } else {
          setIsbnDupHint(null);
        }
      } catch { setIsbnDupHint(null); }
    }, 600);
    return () => clearTimeout(timer);
  }, [form.isbn, form.published_book_id]);

  // ── Live publisher typeahead (debounced 700ms) ──────────
  useEffect(() => {
    const q = (form.editora || '').trim();
    if (q.length < 2) { setPubSuggestions([]); return; }
    const timer = setTimeout(async () => {
      try {
        const { data, error } = await supabase.rpc('search_publishers_by_name', { p_query: q, p_limit: 6 });
        if (!error && data?.length) {
          setPubSuggestions(data);
        } else {
          setPubSuggestions([]);
        }
      } catch { setPubSuggestions([]); }
    }, 700);
    return () => clearTimeout(timer);
  }, [form.editora]);

  function selectPublisher(pub) {
    set('editora', pub.name);
    set('publisher_id', pub.id);
    setPubSuggestions([]);
    if (draftState === 'saved' || draftState === 'ready') setDraftState('dirty');
  }

  function setMany(obj) {
    setForm(prev => ({ ...prev, ...obj }));
  }

  // ── #3b : convention de bib_ref de la biblio active (souple) ──
  // Charge la convention puis pre-remplit la prochaine reference (next_bib_ref)
  // pour une NOUVELLE fiche encore sans bib_ref. Suggestion non bloquante.
  const [bibRefConv, setBibRefConv] = useState(null); // { bib_ref_prefix, bib_ref_pad, bib_ref_auto }
  useEffect(() => {
    if (!libraryId) { setBibRefConv(null); return; }
    let cancelled = false;
    (async () => {
      const { data: conv } = await supabase.from('libraries')
        .select('bib_ref_prefix, bib_ref_pad, bib_ref_auto').eq('id', libraryId).single();
      if (cancelled) return;
      setBibRefConv(conv || null);
      if (conv?.bib_ref_auto && f('action') === 'create' && !f('bib_ref') && !f('published_book_id')) {
        const { data: next } = await supabase.rpc('next_bib_ref', { p_library_id: libraryId });
        if (!cancelled && next) set('bib_ref', next);
      }
    })();
    return () => { cancelled = true; };
  }, [libraryId]); // eslint-disable-line react-hooks/exhaustive-deps

  // ── Liste des bibliotheques pour les selects owner/holder ──
  const [networkLibraries, setNetworkLibraries] = useState([]);
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const { data } = await supabase.from('libraries')
        .select('id, name, short_name, slug').order('name');
      if (!cancelled && data) setNetworkLibraries(data);
    })();
    return () => { cancelled = true; };
  }, []);

  // Auto-populate owner/holder with active library on new draft
  // B29 (CAT-E18) : seulement une bibliothèque où l'on est staff (la
  // bibliothèque active peut être celle d'une adhésion de lectrice : la base
  // refuserait le brouillon). Sinon, sa seule bibliothèque de staff ; plusieurs
  // → à choisir (la base pose la principale si on n'en choisit aucune).
  // B30 : seulement pour une notice NEUVE — une notice enregistrée sans
  // bibliothèque (d'avant B29) reçoit à l'enregistrement celle de son créateur
  // (tg_drafts_library_fixed), pas la bibliothèque active. Et un lot déjà
  // choisi l'emporte : la liste de staff a pu arriver APRÈS le choix du lot,
  // et une notice d'une bibliothèque rangée dans le lot d'une autre serait
  // refusée à la création (42501 error.batch.library_mismatch). Lot hors de
  // portée : la notice prend la bibliothèque active et sort du lot.
  useEffect(() => {
    if (!networkLibraries.length) return;
    if (f('id')) return;
    if (f('action') !== 'create' && f('action') !== '') return;
    if (f('owner_library_id')) return; // already set
    if (!isNetworkAdmin && !staffConnu) return; // B29 : attendre la liste (l'effet se rejoue)
    const peutRanger = (id) => isNetworkAdmin || staffLibraryIds.includes(id);
    const lot = f('batch_id') ? batches.find(b => String(b.id) === String(f('batch_id'))) : null;
    const cible = lot?.library_id && peutRanger(lot.library_id)
      ? lot.library_id
      : libraryId && peutRanger(libraryId)
        ? libraryId
        : (!isNetworkAdmin && staffLibraryIds.length === 1 ? staffLibraryIds[0] : null);
    const lib = cible ? networkLibraries.find(l => l.id === cible) : null;
    if (lib) {
      setMany({
        owner_library_id: lib.id,
        owner_library: lib.name,
        holder_library_id: lib.id,
        holder_library: lib.name,
        ...(lot && !lotDeLaBibliotheque(lot, lib.id) ? { batch_id: '' } : {}),
      });
    }
  }, [libraryId, networkLibraries.length, isNetworkAdmin, staffLibraryIds.join(','), staffConnu]); // eslint-disable-line react-hooks/exhaustive-deps

  // ── Reset ──────────────────────────────────────────────
  function resetForm() {
    setForm({ ...EMPTY_FORM });
    setDraftState('new');
    setMsg({ text: '', kind: '' });
    // le panneau de recherche catalographique se remet à zéro dans LookupPanel (effet sur draftId)
    setCoverFile(null);
    setCoverPreviewUrl('');
    setContributors([{ position: 1, name: '', role: 'autor', is_primary: true }]);
    setIsbdEnabled(false);
    setIsbdData(null);
    // l'onglet de revision revient au résumé dans ReviewPanel (effet sur draftId)
    setDigitalResources([]);
    // le formulaire d'édition d'une ressource numérique se referme dans DigitalResourcesPanel (effet sur draftId)
    setLastPublished(null);
    // Nouvelle fiche vierge → on re-pose la question œuvre/édition.
    setCreationChoice(null);
    setLinkedWorkLabel('');
    setEditionQuery('');
    setEditionResults([]);
  }

  // ── Recherche d'une œuvre existante via ses éditions publiées (débounce 350ms) ──
  // Pour « nouvelle édition d'une œuvre déjà au catalogue » : on cherche parmi les
  // fiches publiées ; sélectionner une fiche rattache le brouillon à SON work_id.
  useEffect(() => {
    const q = editionQuery.trim();
    if (q.length < 3) { setEditionResults([]); setEditionSearching(false); return; }
    let cancelled = false;
    setEditionSearching(true);
    const timer = setTimeout(async () => {
      try {
        const { data } = await supabase.from('books')
          .select('id, work_id, titulo, autor, ano, edicao, editora, bib_ref')
          .not('work_id', 'is', null)
          .ilike('titulo', `%${q}%`)
          .order('titulo').limit(8);
        if (!cancelled) setEditionResults(data || []);
      } catch { if (!cancelled) setEditionResults([]); }
      finally { if (!cancelled) setEditionSearching(false); }
    }, 350);
    return () => { cancelled = true; clearTimeout(timer); };
  }, [editionQuery]);

  // Rattache le brouillon à l'œuvre de la fiche choisie + pré-remplit l'identité
  // partagée (titre/auteur), en laissant les champs propres à l'édition vides.
  function selectEditionAsWork(bk) {
    set('work_id', bk.work_id ? String(bk.work_id) : '');
    setForm(prev => ({ ...prev, titulo: prev.titulo || bk.titulo || '', autor: prev.autor || bk.autor || '' }));
    setLinkedWorkLabel(bk.titulo || '');
    setCreationChoice('edition');
    setEditionQuery('');
    setEditionResults([]);
  }

  // ── Derived state ──────────────────────────────────────
  const materialType = f('tipo_material');
  // Rôles proposés dans le menu déroulant, conditionnés au type de document.
  const availableRoleKeys = roleKeysForMaterial(materialType);
  const isTract = TRACT_TYPES.has(materialType);
  const isAudio = materialType === 'audio';
  const isAudiovisual = materialType === 'audiovisual';
  const isDigitalNative = materialType === 'recurso_digital';
  const isDossier = materialType === 'dossie';
  const isTese = materialType === 'tese';
  const isArtigo = materialType === 'artigo';
  // #périodiques P7 — le sélecteur de titre de revue se montre pour un
  // fascicule, et pour un article seulement si la notice porte déjà un
  // rattachement (la garde G3 admet `artigo`, mais le registre ne lui donne
  // pas les champs de fascicule : on ne propose pas de rattacher, on montre
  // ce qui l'est). Même couple de types que le payload d'enregistrement.
  const showSerialPicker = materialType === 'periodico' || (isArtigo && !!f('serial_id'));
  const isRelatorio = materialType === 'relatorio';
  const isZine = materialType === 'zine';
  // Track A Lot 3 — ternary tiers: simple→1, advanced→2, complete→3.
  const catalogTier = tierFromMode(mode);

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

  function applyBnResult(item) {
    if (!item) return;
    const updates = {};
    // Parse title
    if (item.title && !f('titulo')) {
      const parts = item.title.split(/\s*:\s*/);
      updates.titulo = parts[0] || '';
      if (parts[1] && !f('subtitulo')) updates.subtitulo = parts[1];
    }
    // Parse author
    if (item.author && !f('autor')) updates.autor = item.author;
    // Parse publication (format: "Local : Editora, Ano")
    if (item.publication) {
      const pubMatch = item.publication.match(/^([^:]+?)(?:\s*:\s*(.+?))?(?:,\s*(\d{4}))?\s*$/);
      if (pubMatch) {
        if (pubMatch[1] && !f('local_publicacao')) updates.local_publicacao = pubMatch[1].trim();
        if (pubMatch[2] && !f('editora')) updates.editora = pubMatch[2].trim();
        if (pubMatch[3] && !f('ano')) updates.ano = pubMatch[3];
      }
    }
    // Subjects
    if (item.subject && !f('subjects')) updates.subjects = item.subject;
    // Provenance note
    if (!f('provenance_note')) {
      updates.provenance_note = `BN Brasil — ${item.detail_url || 'acervo.bn.gov.br'}`;
    }

    setMany(updates);
    if (draftState === 'saved' || draftState === 'ready') setDraftState('dirty');
    setMsg({ text: t({ id: 'catalogacao.msg.bnApplied' }, { title: item.title }), kind: 'ok' });
  }

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

  async function uploadCover() {
    if (!coverFile) return null;
    // P1 capas — clé de stockage stable (bib_ref || id), jamais 'new' :
    // un brouillon non sauvegardé n'a pas d'ancre stable et collisionnerait
    // sur books/new/ (perte de données). On exige une sauvegarde préalable.
    const stableKey = f('bib_ref') || f('id');
    if (!stableKey) {
      setMsg({ text: t({ id: 'catalogacao.ui.coverSaveFirst' }), kind: 'error' });
      return null;
    }
    const ext = extensionCapa(coverFile.name);
    // Adresse NEUVE à chaque dépôt, jamais `upsert` : une image remplacée en
    // place restait servie une heure par le cache (coverThumbs.js, 28/09/2026).
    const storagePath = cheminCapaNeuf(stableKey, ext);

    setCoverUploading(true);
    try {
      const { error } = await supabase.storage
        .from('covers')
        .upload(storagePath, coverFile, { upsert: false });
      if (error) throw error;
      // Dérivé pour la grille du catalogue, produit depuis le fichier déjà en
      // mémoire (pas de retéléchargement). Best-effort : voir coverThumbs.js.
      await writeCoverThumb(storagePath, coverFile);
      set('cover_object_path', storagePath);
      // Provenance de l'image qu'on vient d'envoyer : sans ça, elle héritait de
      // celle de la capa précédente (une candidate Open Library, par exemple).
      set('cover_source', 'manual');
      set('cover_license', '');
      setCoverFile(null);
      return storagePath;
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.ui.coverUploadError' }, { message: localizeError(err, t) }), kind: 'error' });
      return null;
    } finally {
      setCoverUploading(false);
    }
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

      // 2. Rendre la page 1 sur un canvas hors-ecran.
      const pdfjs = await loadPdfjsCat();
      const pdf = await pdfjs.getDocument({
        data: arrayBuffer,
        cMapUrl: `${PDFJS_BASE}/web/cmaps/`,
        cMapPacked: true,
        standardFontDataUrl: `${PDFJS_BASE}/web/standard_fonts/`,
      }).promise;
      const page = await pdf.getPage(1);
      const base = page.getViewport({ scale: 1 });
      const targetW = 800;
      const viewport = page.getViewport({ scale: targetW / base.width });
      const canvas = document.createElement('canvas');
      canvas.width = Math.floor(viewport.width);
      canvas.height = Math.floor(viewport.height);
      const ctx = canvas.getContext('2d');
      await page.render({ canvasContext: ctx, viewport }).promise;
      pdf.destroy();

      // 3. Canvas -> blob -> upload bucket covers (blob local, pas de CORS).
      const blob = await new Promise((resolve) => canvas.toBlob(resolve, 'image/jpeg', 0.9));
      if (!blob) throw new Error('toBlob failed');
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

  // Synchronise le champ "autor" à partir des contributeurs
  function syncAutorFromContributors() {
    const named = contributors.filter(c => c.name.trim());
    if (!named.length) return;
    const _primary = named.find(c => c.is_primary) || named[0];
    set('autor', named.map(c => c.name.trim()).join(' ; '));
  }

  // Charge les contributeurs depuis la DB pour un draft existant.
  // Fallback (publishedBookId) : si le brouillon n'a aucun contributeur
  // structure (cas d'une reprise de livre publie, dont les book_contributors
  // ne sont pas copies dans le brouillon), on charge ceux du livre publie via
  // get_book_contributors_public -> lignes editables, sauvegardees au prochain
  // enregistrement du brouillon.
  // Remplit author_label (preferred_name) pour les lignes deja liees a une autorite.
  async function enrichAuthorLabels(rows) {
    const ids = [...new Set(rows.map(r => r.author_id).filter(Boolean))];
    if (!ids.length) return rows;
    try {
      const { data } = await supabase.from('authors').select('id, preferred_name').in('id', ids);
      const byId = new Map((data || []).map(a => [a.id, a.preferred_name]));
      return rows.map(r => r.author_id ? { ...r, author_label: byId.get(r.author_id) || '' } : r);
    } catch {
      return rows;
    }
  }

  async function loadContributors(draftId, publishedBookId = null) {
    if (!draftId) return;
    try {
      const { data, error } = await supabase.from('book_draft_contributors')
        .select('*')
        .eq('draft_id', Number(draftId))
        .order('position', { ascending: true });
      if (error) throw error;
      if (data?.length) {
        setContributors(await enrichAuthorLabels(data.map(c => ({
          position: c.position,
          name: c.name || '',
          role: c.role || 'autor',
          is_primary: c.is_primary || false,
          author_id: c.author_id || null,
          author_label: '',
          nature: c.nature ?? null,        // H18
          role_code: c.role_code ?? null,  // H18 : code de fonction d'origine
        }))));
        return;
      }
      // Fallback : reprise d'un livre publie sans contributeurs de brouillon.
      if (publishedBookId) {
        // H18 : la table d'abord (nature, code d'origine, que la RPC publique
        // ne rend pas) ; la RPC en repli.
        let { data: pub, error: pubErr } = await supabase.from('book_contributors')
          .select('position, name, role, is_primary, author_id, nature, role_code')
          .eq('book_id', Number(publishedBookId))
          .order('position', { ascending: true });
        if (pubErr || !pub?.length) {
          ({ data: pub } = await supabase.rpc('get_book_contributors_public', { p_book_id: Number(publishedBookId) }));
        }
        if (Array.isArray(pub) && pub.length) {
          setContributors(await enrichAuthorLabels(pub.map(c => ({
            position: c.position,
            name: c.name || '',
            role: c.role || 'autor',
            is_primary: c.is_primary || false,
            author_id: c.author_id || null,
            author_label: '',
            nature: c.nature ?? null,
            role_code: c.role_code ?? null,
          }))));
        }
      }
    } catch (err) {
      console.warn('loadContributors error:', err);
    }
  }

  // Doublons de documents : detection (lecture seule, P2a)
  async function findBookDuplicates() {
    const bookId = f('published_book_id');
    if (!bookId) return;
    setBookDupLoading(true); setBookDupMatches(null);
    try {
      const { data, error } = await supabase.rpc('suggest_book_duplicates', { p_book_id: Number(bookId) });
      if (error) throw error;
      setBookDupMatches(data || []);
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setBookDupLoading(false); }
  }

  // Fusionne le livre doublon `dupId` DANS le livre courant (= canonique).
  // La fusion reporte sur CE brouillon (ouvert sur la notice gardée) ce qu'elle
  // reprend du doublon — champs vides, sujets, contributeur·rices — : on le
  // recharge, sinon la prochaine publication réécrirait la notice avec ce qui
  // est à l'écran, et effacerait tout. Des modifications non enregistrées
  // seraient perdues au rechargement : on demande d'enregistrer d'abord.
  async function mergeBookDuplicateIntoCurrent(dupId, dupTitle) {
    const canonicalId = f('published_book_id');
    if (!canonicalId) return;
    if (draftState === 'dirty') {
      setMsg({ text: t({ id: 'catalogacao.dedup.saveBeforeMerge' }), kind: 'error' });
      return;
    }
    if (!(await confirmer({ message: t({ id: 'catalogacao.dedup.confirm' }, { dup: dupTitle, canonical: f('titulo') }), confirmLabel: t({ id: 'confirm.action.merge' }), tone: 'danger' }))) return;
    setBookDupBusy(dupId);
    try {
      const { error } = await supabase.rpc('merge_book', {
        p_canonical_id: Number(canonicalId), p_duplicate_id: Number(dupId),
      });
      if (error) throw error;
      if (f('id')) {
        const { data: rechargé } = await supabase.from('book_drafts').select('*').eq('id', Number(f('id'))).single();
        if (rechargé) fillFromRecord(rechargé);   // efface le message : le nôtre vient après
      }
      setMsg({ text: t({ id: 'catalogacao.dedup.mergedBook' }, { dup: dupTitle }), kind: 'ok' });
      await findBookDuplicates(); // rafraichir
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setBookDupBusy(null); }
  }

  // P1b : marquer une paire « ce n'est pas un doublon » (éditions distinctes) →
  // la paire est masquée définitivement des suggestions (table book_not_duplicate).
  async function markBooksNotDuplicate(dupId) {
    const canonicalId = f('published_book_id');
    if (!canonicalId) return;
    setBookDupBusy(dupId);
    try {
      const { error } = await supabase.rpc('mark_books_not_duplicate', { p_a: Number(canonicalId), p_b: Number(dupId) });
      if (error) throw error;
      setMsg({ text: t({ id: 'catalogacao.dedup.markedNotDuplicate' }), kind: 'ok' });
      await findBookDuplicates(); // rafraîchir : la paire écartée disparaît
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setBookDupBusy(null); }
  }

  // DOUBLONS P4 : signaler la paire à la coordination. C'est ce qui remplace,
  // au poste de catalogage, les boutons qui détruisaient. Rien n'est modifié au
  // catalogue ; la personne qui a le livre en main transmet ce qu'elle a vu.
  async function reportDuplicatePair(dupId) {
    const canonicalId = f('published_book_id');
    if (!canonicalId) return;
    setBookDupBusy(dupId);
    try {
      const { error } = await supabase.rpc('report_duplicate_pair', {
        p_a: Number(canonicalId), p_b: Number(dupId), p_note: null,
      });
      if (error) throw error;
      setMsg({ text: t({ id: 'catalogacao.dedup.reported' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setBookDupBusy(null); }
  }

  // P4 : œuvre — créer depuis la notice, détacher, regrouper des éditions.
  async function createWork() {
    const bid = f('published_book_id'); if (!bid) return;
    setWorkBusy(true);
    try {
      const { error } = await supabase.rpc('create_work_from_book', { p_book_id: Number(bid) });
      if (error) throw error;
      setMsg({ text: t({ id: 'catalogacao.work.created' }), kind: 'ok' });
      setWorkNonce(n => n + 1);
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setWorkBusy(false); }
  }
  async function detachWork() {
    const bid = f('published_book_id'); if (!bid) return;
    setWorkBusy(true);
    try {
      const { error } = await supabase.rpc('detach_book_from_work', { p_book_id: Number(bid) });
      if (error) throw error;
      setMsg({ text: t({ id: 'catalogacao.work.detached' }), kind: 'ok' });
      setWorkNonce(n => n + 1);
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setWorkBusy(false); }
  }
  // P4 v2 : suggérer des éditions à regrouper (même auteur·rice + titre proche).
  async function findEditionSuggestions() {
    const bid = f('published_book_id'); if (!bid) return;
    setEditionSuggLoading(true);
    try {
      const { data, error } = await supabase.rpc('suggest_editions_for_book', { p_book_id: Number(bid) });
      if (error) throw error;
      setEditionSugg(data || []);
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setEditionSuggLoading(false); }
  }

  // Regroupe la notice courante + un autre document comme éditions d'une même œuvre.
  async function groupAsEditions(otherBookId) {
    const bid = f('published_book_id'); if (!bid) return;
    setBookDupBusy(otherBookId);
    try {
      const { error } = await supabase.rpc('group_books_as_editions', { p_book_ids: [Number(bid), Number(otherBookId)] });
      if (error) throw error;
      setMsg({ text: t({ id: 'catalogacao.work.grouped' }), kind: 'ok' });
      setWorkNonce(n => n + 1);
      await findBookDuplicates(); // l'édition regroupée quitte les doublons
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setBookDupBusy(null); }
  }

  // Même édition (28/09/2026) : ouvrir l'aperçu de fusion pour une édition suggérée.
  // La notice éditée survit ; l'autre disparaît. Mêmes gardes que le bouton des
  // doublons : coordination seule (opposable en base), brouillon enregistré d'abord.
  async function ouvrirFusionEdition(s) {
    const canonicalId = f('published_book_id');
    if (!canonicalId || !arbitreDoublons) return;
    if (draftState === 'dirty') {
      setMsg({ text: t({ id: 'catalogacao.dedup.saveBeforeMerge' }), kind: 'error' });
      return;
    }
    setFusionBusy(true);
    try {
      let interdits = champsInterdits;
      if (!interdits.length) {
        const { data } = await supabase.rpc('fn_dedup_non_transferable_fields');
        if (Array.isArray(data)) { interdits = data; setChampsInterdits(data); }
      }
      const { data: apercu, error } = await supabase.rpc('preview_merge_book', {
        p_canonical_id: Number(canonicalId), p_duplicate_id: Number(s.book_id),
      });
      if (error) throw error;
      // Cochées par défaut : les pertes sèches, et elles seules (comme l'assistant).
      const reprises = (apercu?.metadonnees_perdues || []).map((m) => m.champ).filter((c) => !interdits.includes(c));
      setFusionEdition({ bookId: Number(s.book_id), titulo: s.titulo, apercu, saisie: '', reprises });
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setFusionBusy(false); }
  }

  async function fusionnerEdition() {
    const canonicalId = f('published_book_id');
    if (!canonicalId || !fusionEdition) return;
    setFusionBusy(true);
    try {
      const { error } = await supabase.rpc('merge_book_with_fields', {
        p_canonical_id: Number(canonicalId), p_duplicate_id: fusionEdition.bookId,
        p_fields: fusionEdition.reprises || [],
      });
      if (error) throw error;
      const titre = fusionEdition.titulo;
      setFusionEdition(null);
      if (f('id')) {
        const { data: rechargé } = await supabase.from('book_drafts').select('*').eq('id', Number(f('id'))).single();
        if (rechargé) fillFromRecord(rechargé);   // efface le message : le nôtre vient après
      }
      setMsg({ text: t({ id: 'catalogacao.dedup.mergedBook' }, { dup: titre }), kind: 'ok' });
      setWorkNonce(n => n + 1);
      await findEditionSuggestions();
      await findBookDuplicates();
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setFusionBusy(false); }
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

  // Sauvegarde les contributeurs (delete all + re-insert)
  async function saveContributors(draftId) {
    if (!draftId) return;
    const named = contributors.filter(c => c.name.trim());
    try {
      await supabase.from('book_draft_contributors').delete().eq('draft_id', Number(draftId));
      if (!named.length) return;
      const payload = named.map((c, i) => ({
        draft_id: Number(draftId),
        position: i + 1,
        name: c.name.trim(),
        role: c.role,
        is_primary: c.is_primary,
        author_id: c.author_id || null,
        // H18 : ne pas les perdre à l'enregistrement — et ne les envoyer que
        // lorsqu'elles portent une valeur : un écran publié avant la migration
        // ne doit pas échouer (colonne inconnue) après avoir effacé les lignes.
        ...(c.nature != null ? { nature: c.nature } : {}),
        ...(c.role_code != null ? { role_code: c.role_code } : {}),
      }));
      const { error } = await supabase.from('book_draft_contributors').insert(payload);
      if (error) throw error;
    } catch (err) {
      console.warn('saveContributors error:', err);
      throw err;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ISBD preparation (zones 0–8)
  // ═══════════════════════════════════════════════════════

  const ZONE_LABELS = {
    '0': t({id:'catalogacao.isbd.zone0'}),
    '1': t({id:'catalogacao.isbd.zone1'}),
    '2': t({id:'catalogacao.isbd.zone2'}),
    '3': t({id:'catalogacao.isbd.zone3'}),
    '4': t({id:'catalogacao.isbd.zone4'}),
    '5': t({id:'catalogacao.isbd.zone5'}),
    '6': t({id:'catalogacao.isbd.zone6'}),
    '7': t({id:'book.isbd.zone7'}),
    '8': t({id:'catalogacao.isbd.zone8'}),
  };


  function prepareIsbd() {
    const zones = {};
    construireZonesIsbd(form, t).forEach((valeur, i) => {
      zones[String(i)] = { label: ZONE_LABELS[String(i)], value: valeur || null };
    });
    const statement = Object.values(zones).map(z => z.value).filter(Boolean).join('. - ');
    const nonEmptyCount = Object.values(zones).filter(z => z.value).length;

    const data = {
      enabled: true,
      standard: 'IFLA_ISBD_integrada_2011_guided_local',
      generated_at: new Date().toISOString(),
      statement,
      zones,
    };

    setIsbdEnabled(true);
    setIsbdData({ statement, zones, nonEmptyCount, data });

    // Sync into marc_json
    try {
      const raw = f('marc_json') ? JSON.parse(f('marc_json')) : {};
      raw.anarbib_isbd = data;
      set('marc_json', JSON.stringify(raw, null, 2));
    } catch {}

    setMsg({ text: t({ id: 'catalogacao.msg.isbdPrepared' }, { count: nonEmptyCount }), kind: 'ok' });
    if (draftState === 'saved' || draftState === 'ready') setDraftState('dirty');
  }

  function clearIsbd() {
    setIsbdEnabled(false);
    setIsbdData(null);
    try {
      const raw = f('marc_json') ? JSON.parse(f('marc_json')) : {};
      delete raw.anarbib_isbd;
      set('marc_json', JSON.stringify(raw, null, 2));
    } catch {}
  }

  // ═══════════════════════════════════════════════════════
  // Duplicate detection (ISBN + title/author)
  // ═══════════════════════════════════════════════════════

  // Détecte un doublon probable AVANT la sauvegarde du brouillon.
  // Ne montre aucune UI : retourne { kind: 'isbn'|'approx', detail, bookId, score }
  // pour le meilleur candidat, sinon null (l'appelant ouvre la modale).
  //
  // Délègue à la RPC public.suggest_duplicates_for_fields (pg_trgm) : ISBN exact
  // + titre/auteur trigramme (tolère les variantes de titre), inter-bibliothèques.
  // Fonctionne aussi en ÉDITION d'une fiche publiée : p_exclude_book_id retire la
  // fiche elle-même et les paires déjà arbitrées « pas un doublon ».
  // Fail-open : toute erreur (RPC absente le temps du déploiement, réseau…) ->
  // null, on ne bloque jamais la sauvegarde.
  async function detectDuplicate() {
    const isbn = (f('isbn') || '').replace(/[^0-9Xx]/g, '').toUpperCase();
    const title = f('titulo').trim();
    const author = f('autor').trim();
    const excludeId = f('published_book_id') ? Number(f('published_book_id')) : null;

    if (!isbn && !title) return null; // rien a verifier

    try {
      const { data, error } = await supabase.rpc('suggest_duplicates_for_fields', {
        p_title: title || null,
        p_author: author || null,
        p_isbn: isbn || null,
        p_exclude_book_id: excludeId,
      });
      if (error) throw error;
      let suggestions = data || [];
      // Un autre VOLUME du même ensemble n'est pas un doublon, même ISBN (même
      // règle que publish_book_draft, lib/volumes.js). Sinon l'avertissement
      // poussait à enregistrer le volume 4 comme un exemplaire du volume 2.
      const idsIsbn = suggestions.filter((s) => s.match_kind === 'isbn').map((s) => s.book_id);
      if (f('volume').trim() && idsIsbn.length) {
        const { data: vols } = await supabase.from('books').select('id, volume').in('id', idsIsbn);
        const autres = new Set((vols || []).filter((b) => volumesDifferents(b.volume, f('volume'))).map((b) => b.id));
        suggestions = suggestions.filter((s) => !(s.match_kind === 'isbn' && autres.has(s.book_id)));
      }
      const top = suggestions[0];
      if (!top) return null;
      const detail = [
        top.titulo || '',
        top.ano ? `(${top.ano})` : '',
        top.bib_ref ? `ref. ${top.bib_ref}` : '',
        top.library_name || '',
      ].filter(Boolean).join(' · ');
      return {
        kind: top.match_kind === 'isbn' ? 'isbn' : 'approx',
        detail,
        bookId: top.book_id,
        score: top.score,
      };
    } catch (err) {
      console.warn('Duplicate check error:', err);
      return null; // fail-open
    }
  }

  // ═══════════════════════════════════════════════════════
  // Digital resources CRUD
  // ═══════════════════════════════════════════════════════


  async function loadDigitalResources(draftId) {
    if (!draftId) return;
    try {
      const { data, error } = await supabase.from('book_draft_digital_resources')
        .select('*')
        .eq('book_draft_id', Number(draftId))
        .order('is_primary', { ascending: false })
        .order('id', { ascending: true });
      if (error) throw error;
      setDigitalResources(data || []);
    } catch (err) {
      console.warn('loadDigitalResources error:', err);
    }
  }


  // ── Draft state pill ───────────────────────────────────
  const statePills = {
    new: { label: t({id:'catalogacao.ui.newDraft'}), cls: 'info' },
    saved: { label: t({id:'catalogacao.state.saved'}), cls: 'ok' },
    dirty: { label: t({id:'catalogacao.msg.unsavedChanges'}), cls: 'warn' },
    ready: { label: t({id:'catalogacao.msg.readyToPublish'}), cls: 'ok' },
    published: { label: t({id:'catalogacao.msg.alreadyPublished'}), cls: 'ok' },
  };
  const pill = statePills[draftState] || statePills.new;

  // ── Save draft ─────────────────────────────────────────
  async function handleSave(e, { skipDupCheck = false } = {}) {
    e?.preventDefault();
    if (!f('titulo').trim()) { setMsg({ text: t({id:'catalogacao.msg.enterTitle'}), kind: 'error' }); return; }

    // Avertissement doublon — nouveaux brouillons ET mises à jour de fiches déjà
    // publiées (detectDuplicate exclut la fiche courante + les paires arbitrées
    // « pas un doublon »). On ouvre une modale centrée et on interrompt la
    // sauvegarde ; « Enregistrer quand même » rappelle handleSave avec skipDupCheck.
    if (!skipDupCheck) {
      const dup = await detectDuplicate();
      if (dup) { setDupModal(dup); return; }
    }

    setDupModal(null);
    setSaving(true);
    setMsg({ text: '', kind: '' });

    try {
      // Upload cover if file selected. Le chemin vient du RETOUR d'uploadCover :
      // `f()` lit l'état de CE rendu, d'avant l'envoi — la charge utile
      // repartait sans le chemin du fichier qu'on venait d'envoyer.
      const envoye = coverFile ? await uploadCover() : null;
      const isUpdate = !!f('id');
      const payload = {
        ...(isUpdate ? { id: Number(f('id')) } : {}),
        published_book_id: f('published_book_id') ? Number(f('published_book_id')) : null,
        batch_id: f('batch_id') ? Number(f('batch_id')) : null,
        action: f('published_book_id') ? 'update' : 'create',
        status: 'draft',
        // Œuvre parente (nouvelle édition) + exemplaires initiaux à la publication.
        // initial_copies_library_id n'est honoré côté serveur que pour un·e admin réseau.
        work_id: f('work_id') ? Number(f('work_id')) : null,
        initial_copies: Math.max(1, Math.min(50, parseInt(f('initial_copies'), 10) || 1)),
        initial_copies_library_id: (isNetworkAdmin && f('initial_copies_library_id')) ? f('initial_copies_library_id') : null,
        bib_ref: f('bib_ref') || null,
        titulo: f('titulo').trim(),
        subtitulo: f('subtitulo') || null,
        autor: f('autor') || null,
        edicao: f('edicao') || null,
        local_publicacao: f('local_publicacao') || null,
        editora: f('editora') || null,
        publisher_id: f('publisher_id') ? Number(f('publisher_id')) : null,
        ano: f('ano') || null,
        isbn: f('isbn') || null,
        issn: f('issn') || null,
        // #périodiques P7 : forcé à NULL hors fascicule/article — c'est aussi
        // ce qu'exige la garde G3, autant ne pas lui envoyer de quoi lever.
        serial_id: (materialType === 'periodico' || materialType === 'artigo') && f('serial_id')
          ? Number(f('serial_id')) : null,
        titulo_periodico: f('titulo_periodico') || null,
        volume: f('volume') || null,
        numero: f('numero') || null,
        fasciculo: f('fasciculo') || null,
        data_edicao: f('data_edicao') || null,
        periodicidade: f('periodicidade') || null,
        cdd: f('cdd') || null,
        idioma: f('idioma') || null,
        paginas: f('paginas') ? parseInt(f('paginas'), 10) || null : null,
        notas: f('notas') || null,
        tipo_material: materialType,
        circulation_default: NON_LOANABLE_TYPES.has(materialType) ? 'consulta' : (f('circulation_default') || 'emprestavel'),
        loanable: NON_LOANABLE_TYPES.has(materialType) ? false : (f('circulation_default') || 'emprestavel') !== 'consulta',
        colecao: f('colecao') || null,
        cover_object_path: envoye || f('cover_object_path') || null,
        // Provenance et licence suivent l'image (spec capas §4.3). Elles étaient
        // posées dans l'état et jamais envoyées : 0 capa attribuée sur 250.
        cover_source: envoye ? 'manual' : (f('cover_source') || null),
        cover_license: envoye ? null : (f('cover_license') || null),
        marc_json: f('marc_json') ? JSON.parse(f('marc_json')) : null,
        // Acquisition
        acquisition_mode: f('acquisition_mode') || null,
        acquisition_date: f('acquisition_date') || null,
        owner_library: f('owner_library') || null,
        holder_library: f('holder_library') || null,
        owner_library_id: f('owner_library_id') || null,
        holder_library_id: f('holder_library_id') || null,
        source_label: f('source_label') || null,
        partner_source: f('partner_source') || null,
        source_record_id: f('source_record_id') || null,
        source_record_url: f('source_record_url') || null,
        import_format: f('import_format') || null,
        import_method: f('import_method') || null,
        provenance_note: f('provenance_note') || null,
        mutualization_status: f('mutualization_status') || null,
        // Material-specific
        tract_campaign: isTract ? (f('tract_campaign') || null) : null,
        emitter_org: isTract ? (f('emitter_org') || null) : null,
        approximate_date: isTract ? (f('approximate_date') || null) : null,
        diffusion_place: isTract ? (f('diffusion_place') || null) : null,
        recto_verso: isTract ? (f('recto_verso') || null) : null,
        physical_format: isTract ? (f('physical_format') || null) : null,
        print_technique: isTract ? (f('print_technique') || null) : null,
        physical_state: isTract ? (f('physical_state') || null) : null,
        audio_duration: isAudio ? (f('audio_duration') || null) : null,
        audio_support: isAudio ? (f('audio_support') || null) : null,
        audio_format: isAudio ? (f('audio_format') || null) : null,
        audio_language: isAudio ? (f('audio_language') || null) : null,
        audio_participants: isAudio ? (f('audio_participants') || null) : null,
        audio_recording_type: isAudio ? (f('audio_recording_type') || null) : null,
        audiovisual_duration: isAudiovisual ? (f('audiovisual_duration') || null) : null,
        audiovisual_support: isAudiovisual ? (f('audiovisual_support') || null) : null,
        audiovisual_language: isAudiovisual ? (f('audiovisual_language') || null) : null,
        audiovisual_director: isAudiovisual ? (f('audiovisual_director') || null) : null,
        audiovisual_participants: isAudiovisual ? (f('audiovisual_participants') || null) : null,
        audiovisual_subtitles: isAudiovisual ? (f('audiovisual_subtitles') || null) : null,
        audiovisual_access_note: isAudiovisual ? (f('audiovisual_access_note') || null) : null,
        distribuidora: isAudiovisual ? (f('distribuidora') || null) : null,
        gravadora: isAudio ? (f('gravadora') || null) : null,
        digital_native_url: isDigitalNative ? (f('digital_native_url') || null) : null,
        digital_native_access: isDigitalNative ? (f('digital_native_access') || null) : null,
        digital_native_restriction: isDigitalNative ? (f('digital_native_restriction') || null) : null,
        digital_native_usage: isDigitalNative ? (f('digital_native_usage') || null) : null,
        digital_native_file_note: isDigitalNative ? (f('digital_native_file_note') || null) : null,
        dossier_scope: isDossier ? (f('dossier_scope') || null) : null,
        dossier_period: isDossier ? (f('dossier_period') || null) : null,
        dossier_organizations: isDossier ? (f('dossier_organizations') || null) : null,
        dossier_context: isDossier ? (f('dossier_context') || null) : null,
        // Tese
        tese_university: isTese ? (f('tese_university') || null) : null,
        tese_advisor: isTese ? (f('tese_advisor') || null) : null,
        // Artigo
        artigo_source: isArtigo ? (f('artigo_source') || null) : null,
        artigo_volume: isArtigo ? (f('artigo_volume') || null) : null,
        artigo_issue: isArtigo ? (f('artigo_issue') || null) : null,
        artigo_pages: isArtigo ? (f('artigo_pages') || null) : null,
        // Relatorio
        relatorio_org: isRelatorio ? (f('relatorio_org') || null) : null,
        relatorio_recipient: isRelatorio ? (f('relatorio_recipient') || null) : null,
        relatorio_internal_notes: isRelatorio ? (f('relatorio_internal_notes') || null) : null,
        // Zine
        zine_print_run: isZine ? (f('zine_print_run') || null) : null,
        zine_technique: isZine ? (f('zine_technique') || null) : null,
        zine_format: isZine ? (f('zine_format') || null) : null,
        // Subjects (transversal)
        subjects: f('subjects') || null,
        updated_by: user?.id || null,
      };

      let result;
      if (isUpdate) {
        const id = payload.id;
        delete payload.id;
        const { data, error } = await supabase.from('book_drafts').update(payload).eq('id', id).select().single();
        if (error) throw error;
        result = data;
      } else {
        delete payload.id;
        const { data, error } = await supabase.from('book_drafts').insert(payload).select().single();
        if (error) throw error;
        result = data;
      }

      // B30 : l'écran montre ce que la base a GARDÉ, pas ce qui a été demandé.
      // Une notice d'avant B29 reçoit à l'enregistrement la bibliothèque de
      // son créateur (tg_drafts_library_fixed), et un rangement dans le lot
      // d'une autre bibliothèque est refusé en silence (le brouillon reste dans
      // son ancien lot) : sans cette relecture, le menu afficherait un lot que
      // la notice n'a pas.
      const lotDemande = String(f('batch_id') || '');
      const lotGarde = 'batch_id' in result ? String(result.batch_id || '') : lotDemande;
      setForm(prev => ({
        ...prev,
        id: String(result.id),
        batch_id: lotGarde,
        ...(result.owner_library_id ? { owner_library_id: result.owner_library_id, owner_library: result.owner_library || prev.owner_library } : {}),
      }));

      // Save contributors
      const warnings = [];
      if (lotGarde !== lotDemande) warnings.push(t({ id: 'error.batch.library_mismatch' }));
      try {
        syncAutorFromContributors();
        await saveContributors(result.id);
      } catch (contribErr) {
        warnings.push(t({id:'catalogacao.msg.contribWarning'}, {message: contribErr.message}));
      }

      // OCR (piste B) : rattache le PDF scanné déposé au brouillon créé.
      if (!isUpdate && ocrFileRef.current) {
        try {
          await attachOcrPdf(result.id, ocrFileRef.current);
          ocrFileRef.current = null;
          await loadDigitalResources(result.id);
        } catch (pdfErr) {
          warnings.push(t({ id: 'catalogacao.msg.ocrPdfWarning' }, { message: localizeError(pdfErr, t) }));
        }
      }

      setDraftState('saved');
      confirmSaved(
        warnings.length
          ? t({id:'catalogacao.msg.draftSavedWithWarnings'}, {warnings: warnings.join(' ; ')})
          : t({id:'catalogacao.msg.draftSaved'}),
        warnings.length ? 'warn' : 'ok',
      );
      onSaved?.();
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setSaving(false);
    }
  }

  // ── Publish draft ──────────────────────────────────────
  async function handlePublish() {
    const draftId = f('id');
    if (!draftId) { showMsg(t({ id: 'catalogacao.msg.saveBeforePublish' }), 'error'); return; }

    // Validation côté client AVANT l'appel serveur (chantier B — UX immédiate)
    if (!f('titulo')?.trim()) {
      showMsg(t({ id: 'error.publish.titulo_required' }), 'error');
      return;
    }
    if (!f('bib_ref')?.trim()) {
      showMsg(t({ id: 'error.publish.bib_ref_required' }), 'error');
      return;
    }
    if (!f('tipo_material')?.trim()) {
      showMsg(t({ id: 'error.publish.tipo_material_required' }), 'error');
      return;
    }

    if (!(await confirmer({ message: t({id:'catalogacao.msg.publishConfirm'}), confirmLabel: t({ id: 'confirm.action.publish' }) }))) return;
    setDupBanner(null);

    try {
      // Mark as ready first + fige les paramètres œuvre/exemplaires les plus récents
      // (indépendamment d'une éventuelle sauvegarde antérieure). initial_copies_library_id
      // n'est de toute façon honoré côté serveur que pour un·e admin réseau.
      await supabase.from('book_drafts').update({
        status: 'ready',
        work_id: f('work_id') ? Number(f('work_id')) : null,
        initial_copies: Math.max(1, Math.min(50, parseInt(f('initial_copies'), 10) || 1)),
        initial_copies_library_id: (isNetworkAdmin && f('initial_copies_library_id')) ? f('initial_copies_library_id') : null,
      }).eq('id', Number(draftId));
      const { data: newBookId, error } = await supabase.rpc('publish_book_draft', { p_draft_id: Number(draftId) });
      if (error) throw error;

      // Try linking contributors to authors (publish_book_draft renvoie l'id du livre créé)
      const publishedId = newBookId || f('published_book_id');
      // H18 : une notice importée ne se rattache pas d'office aux autorités ;
      // ses rapprochements se proposent en révision du lot.
      let importee = false;
      try { const mj = JSON.parse(f('marc_json') || '{}'); importee = !!(mj && typeof mj === 'object' && 'ingest' in mj); } catch { importee = false; }
      if (publishedId && !importee) {
        try {
          await supabase.rpc('link_book_contributors_to_authors', { p_book_id: Number(publishedId) });
        } catch {}
      }

      // UX catalogage en série (2026-07) : après publication, on repart aussitôt
      // sur une fiche vierge pour enchaîner un nouveau brouillon. On capture le
      // titre et l'auteur·rice AVANT reset (resetForm les efface).
      const publishedTitle = f('titulo');
      const publishedAutor = f('autor');
      onSaved?.();
      resetForm();
      setCoverCandidates([]);
      setDupBanner(null);
      setIsbnDupHint(null);
      setWork(null);
      // 04/10/2026 : un seul encadré « Publié — et maintenant ? » remplace le
      // message, le toast, le bandeau « Ajouter un exemplaire ? » et la fenêtre
      // œuvre/édition qui revenait à chaque publication. La fenêtre ne s'ouvre
      // plus que sur « Nouveau document » (creationChoice non nul ici).
      setCreationChoice('work');
      let workId = null;
      if (publishedId) {
        try {
          const { data: pub } = await supabase.from('books').select('work_id').eq('id', Number(publishedId)).maybeSingle();
          workId = pub?.work_id || null;
        } catch { /* l'action « autre édition » sera simplement omise */ }
      }
      setLastPublished(publishedId ? { bookId: publishedId, title: publishedTitle, autor: publishedAutor, workId } : null);
      if (!publishedId) confirmSaved(t({ id: 'catalogacao.msg.bookPublishedNext' }, { title: publishedTitle }));
    } catch (err) {
      const raw = typeof err?.message === 'string' ? err.message : '';
      const code = raw.split(':', 1)[0].trim();
      if (code === 'isbn_duplicado') {
        const idPart = raw.includes(':') ? raw.slice(raw.indexOf(':') + 1).trim() : '';
        const bookId = /^\d+$/.test(idPart) ? Number(idPart) : null;
        setDupBanner({ bookId });
        showMsg('', '');
      } else if (code === 'bib_ref_duplicado') {
        const idPart = raw.includes(':') ? raw.slice(raw.indexOf(':') + 1).trim() : '';
        const bookId = /^\d+$/.test(idPart) ? idPart : '?';
        setDupBanner(null);
        showMsg(t({ id: 'catalogacao.msg.bibRefDuplicate' }, { bibRef: f('bib_ref') || '?', bookId }), 'error');
      } else {
        setDupBanner(null);
        showMsg(localizeError(err, t), 'error');
      }
    }
  }

  // ── Load existing draft ────────────────────────────────
  function fillFromRecord(record) {
    const r = record || {};
    trackRetake(r);
    setImportedCheck((c) => c + 1);   // H19 : relire les exemplaires importés
    // Les éditions suggérées et l'aperçu de fusion appartiennent à la notice
    // précédente : vu le 28/09, « Aucune édition à regrouper » restait affiché
    // sur la notice ouverte ensuite.
    setEditionSugg(null);
    setFusionEdition(null);
    setForm({
      id: String(r.id || ''),
      published_book_id: String(r.published_book_id || ''),
      batch_id: String(r.batch_id || ''),
      action: r.action || 'create',
      bib_ref: r.bib_ref || '',
      tipo_material: (r.tipo_material || 'livro').toLowerCase(),
      titulo: r.titulo || '',
      subtitulo: r.subtitulo || '',
      autor: r.autor || '',
      edicao: r.edicao || '',
      editora: r.editora || '',
      publisher_id: r.publisher_id ? String(r.publisher_id) : '',
      colecao: r.colecao || '',
      local_publicacao: r.local_publicacao || '',
      ano: r.ano || '',
      isbn: r.isbn || '',
      issn: r.issn || '',
      serial_id: r.serial_id != null ? String(r.serial_id) : '',
      titulo_periodico: r.titulo_periodico || '',
      volume: r.volume || '',
      numero: r.numero || '',
      fasciculo: r.fasciculo || '',
      data_edicao: r.data_edicao || '',
      periodicidade: r.periodicidade || '',
      cdd: r.cdd || '',
      idioma: r.idioma || '',
      paginas: r.paginas != null ? String(r.paginas) : '',
      loanable: String(r.loanable ?? true),
      circulation_default: r.loanable === false ? 'consulta' : (r.circulation_default || 'emprestavel'),
      notas: r.notas || '',
      subjects: r.marc_json?.anarbib_subjects?.join(' ; ') || '',
      cover_object_path: r.cover_object_path || '',
      cover_source: r.cover_source || '',
      cover_license: r.cover_license || '',
      marc_json: r.marc_json ? JSON.stringify(r.marc_json, null, 2) : '',
      acquisition_mode: r.acquisition_mode || '',
      acquisition_date: r.acquisition_date || '',
      owner_library: r.owner_library || '',
      holder_library: r.holder_library || '',
      owner_library_id: r.owner_library_id || '',
      holder_library_id: r.holder_library_id || '',
      source_label: r.source_label || '',
      partner_source: r.partner_source || '',
      source_record_id: r.source_record_id || '',
      source_record_url: r.source_record_url || '',
      import_format: r.import_format || '',
      import_method: r.import_method || '',
      provenance_note: r.provenance_note || '',
      mutualization_status: r.mutualization_status || '',
      tract_campaign: r.tract_campaign || '',
      emitter_org: r.emitter_org || '',
      approximate_date: r.approximate_date || '',
      diffusion_place: r.diffusion_place || '',
      recto_verso: r.recto_verso || '',
      physical_format: r.physical_format || '',
      print_technique: r.print_technique || '',
      physical_state: r.physical_state || '',
      audio_duration: r.audio_duration || '',
      audio_support: r.audio_support || '',
      audio_format: r.audio_format || '',
      audio_language: r.audio_language || '',
      audio_participants: r.audio_participants || '',
      audio_recording_type: r.audio_recording_type || '',
      audiovisual_duration: r.audiovisual_duration || '',
      audiovisual_support: r.audiovisual_support || '',
      audiovisual_language: r.audiovisual_language || '',
      audiovisual_director: r.audiovisual_director || '',
      audiovisual_participants: r.audiovisual_participants || '',
      audiovisual_subtitles: r.audiovisual_subtitles || '',
      audiovisual_access_note: r.audiovisual_access_note || '',
      distribuidora: r.distribuidora || '',
      gravadora: r.gravadora || '',
      digital_native_url: r.digital_native_url || '',
      digital_native_access: r.digital_native_access || '',
      digital_native_restriction: r.digital_native_restriction || '',
      digital_native_usage: r.digital_native_usage || '',
      digital_native_file_note: r.digital_native_file_note || '',
      dossier_scope: r.dossier_scope || '',
      dossier_period: r.dossier_period || '',
      dossier_organizations: r.dossier_organizations || '',
      dossier_context: r.dossier_context || '',
    });
    setDraftState(r.status === 'ready' ? 'ready' : (r.status === 'published' ? 'published' : (r.id ? 'saved' : 'new')));
    setMsg({ text: '', kind: '' });
    // Load contributors from DB if draft exists (fallback : livre publie repris)
    if (r.id) loadContributors(r.id, r.published_book_id);
    // Load digital resources
    if (r.id) loadDigitalResources(r.id);
    // Restore ISBD state from marc_json if available
    if (r.marc_json?.anarbib_isbd?.enabled) {
      const isbd = r.marc_json.anarbib_isbd;
      setIsbdEnabled(true);
      const nonEmptyCount = isbd.zones ? Object.values(isbd.zones).filter(z => z?.value).length : 0;
      setIsbdData({
        statement: isbd.statement || '',
        zones: isbd.zones || {},
        nonEmptyCount,
        data: isbd,
      });
    } else {
      setIsbdEnabled(false);
      setIsbdData(null);
    }
  }

  // ── Registry-driven context (Lot 2: toutes les entrées passent par le registre) ──
  // (Le sélecteur de titre de revue n'est plus déclaré ici via `sectionExtras` :
  // voir le montage en ligne, en tête de la zone Periódico, et le commentaire
  // qui l'accompagne.)
  // B29 : la bibliothèque PROPRIÉTAIRE ne se choisit que parmi les siennes
  // (l'administration : toutes) ; la détentrice reste libre.
  const ownerLibraries = staffConnu
    ? bibliothequesProposables(networkLibraries, { isNetworkAdmin, staffLibraryIds, garder: f('owner_library_id') })
    : networkLibraries;   // B29 : liste inconnue — la base tranchera
  // B30 : le lot a SA bibliothèque. Changer la bibliothèque propriétaire
  // d'une notice rangée dans le lot d'une autre bibliothèque la sort du lot
  // (la base ferait de même au prochain enregistrement). Pour tout le monde,
  // administration du réseau comprise — que la base, elle, ne trie pas : un
  // lot, une bibliothèque, comme ExemplarDraftForm (champ Biblioteca et
  // réattribution d'un exemplaire).
  function setChamp(key, value) {
    set(key, value);
    if (key !== 'owner_library_id' || !value || !f('batch_id')) return;
    const lot = batches.find(b => String(b.id) === String(f('batch_id')));
    if (lot && !lotDeLaBibliotheque(lot, value)) set('batch_id', '');
  }
  // B30 : les lots proposés sont ceux de la bibliothèque de la notice (tous
  // pour l'administration) ; le lot enregistré reste toujours proposé. Liste
  // de staff inconnue : pas de filtre, la base tranche.
  const lotsDeLaNotice = lotsProposables(batches, {
    isNetworkAdmin,
    staffLibraryIds: staffConnu ? staffLibraryIds : null,
    libraryId: f('owner_library_id') || null,
    garder: f('batch_id') || null,
  });
  // Choisir un lot pour une notice NEUVE sans bibliothèque (staff de plusieurs
  // bibliothèques, l'active n'en étant pas une ; ou liste de staff pas encore
  // chargée) : le lot la fixe — le champ propriétaire n'est visible qu'en mode
  // complet. Liste de staff inconnue : on pose quand même, la base vérifiera
  // (sinon l'effet de pré-remplissage poserait ensuite la bibliothèque active,
  // peut-être une autre que celle du lot). Une notice ENREGISTRÉE sans
  // bibliothèque (d'avant B29) n'en reçoit pas ici : la base lui donne celle
  // de son créateur à l'enregistrement, et juge le lot sur celle-là.
  function choisirLot(valeur) {
    set('batch_id', valeur);
    if (!valeur || f('owner_library_id') || f('id')) return;
    const lot = batches.find(b => String(b.id) === String(valeur));
    if (!lot?.library_id) return;
    if (!isNetworkAdmin && staffConnu && !staffLibraryIds.includes(lot.library_id)) return;
    const nom = networkLibraries.find(l => l.id === lot.library_id)?.name || lot.library?.name || '';
    setMany({
      owner_library_id: lot.library_id,
      owner_library: nom,
      ...(f('holder_library_id') ? {} : { holder_library_id: lot.library_id, holder_library: nom }),
    });
  }
  const ctx = { f, set: setChamp, t, networkLibraries, ownerLibraries };
  const rrf = (id) => renderRegistryField(id, ctx, catalogTier, materialType);

  // ── Aperçu live de la fiche (maquette v3, TRA-v3) ──────
  function renderLivePreview() {
    const title = f('titulo').trim();
    // #auteur-collectif (17/06) — repli sur les contributeurs (rôles auteur, collectifs
    // inclus) quand le texte legacy `autor` est vide ; sinon l'aperçu affichait
    // « auteur·rice non renseigné·e » alors qu'un collectif est lié.
    const author = f('autor').trim()
      || contributors.filter(c => (c.name || '').trim() && AUTHOR_DISPLAY_ROLES.includes(c.role))
                     .map(c => c.name.trim()).join(' ; ');
    const year = f('ano').trim();
    const publisher = f('editora').trim();
    const place = f('local_publicacao').trim();
    const language = f('idioma').trim();
    const cdd = f('cdd').trim();
    const subjects = f('subjects').split(/[;\n]+/).map(s => s.trim()).filter(Boolean);
    const typeLabel = MATERIAL_TYPES.find(m => m.value === materialType)?.label || materialType;
    const circ = f('circulation_default') || 'emprestavel';
    const isConsult = circ === 'consulta';
    const circLabel = circ === 'consulta' ? t({ id: 'catalogacao.ui.consultOnly' })
      : circ === 'ambos' ? t({ id: 'catalogacao.ui.circulationBoth' })
        : t({ id: 'catalogacao.ui.loanable' });
    const meta = [publisher, place, language].filter(Boolean).join(' · ');
    const essentials = [title, author, year].filter(Boolean).length;
    const chipCls = essentials >= 3 ? 'ok' : essentials === 2 ? 'warn' : 'danger';
    // Validations légères
    const isbnDigits = (f('isbn') || '').replace(/[^0-9Xx]/g, '');
    const yr = parseInt(year, 10);
    const warns = [];
    if (isbnDigits && isbnDigits.length !== 10 && isbnDigits.length !== 13) warns.push(t({ id: 'catalogacao.validate.isbn' }));
    if (year && (Number.isNaN(yr) || yr < 1700 || yr > 2027)) warns.push(t({ id: 'catalogacao.validate.year' }));
    return (
      <aside className="ab-preview">
        <div className="ab-sheet">
          <div className="ab-sheet__head">
            <span className="ab-sheet__title">{t({ id: 'catalogacao.preview.title' })}</span>
            <span className={`cat-pill ${chipCls}`}>{t({ id: 'catalogacao.preview.essentials' }, { n: essentials })}</span>
          </div>
          <div className="ab-pv-card">
            <div className="ab-pv-row">
              <span className="ab-pv-type">{typeLabel}</span>
              <span className={`cat-pill ${isConsult ? 'warn' : 'ok'}`}>{circLabel}</span>
            </div>
            <div className={`ab-pv-title ${title ? '' : 'empty'}`}>{title || t({ id: 'catalogacao.preview.noTitle' })}</div>
            <div className="ab-pv-author">
              {author || <span className="yr">{t({ id: 'catalogacao.preview.noAuthor' })}</span>}
              {year && <span className="yr"> · {year}</span>}
            </div>
            {meta && <div className="ab-pv-meta">{meta}</div>}
            {cdd && <span className="ab-pv-cdd">CDD {cdd}</span>}
            {subjects.length > 0 && <div className="ab-pv-subjects">{subjects.map((s, i) => <span key={i}>{s}</span>)}</div>}
            {warns.map((w, i) => <div key={i} className="ab-warnline">⚠ {w}</div>)}
            <div className="ab-pv-status"><span className="ab-pv-dot" /> {t({ id: 'catalogacao.preview.draftStatus' })}</div>
          </div>
          <div className="ab-pv-explain">{t({ id: 'catalogacao.preview.explain' })}</div>
        </div>
        {/* Cards « para informação » (E6 lot 8 : InfoCards) */}
        <InfoCards publishedBookId={form.published_book_id} catalogLibraries={catalogLibraries} libraryId={libraryId}
          contributors={contributors} onNavigateTab={onNavigateTab} onEditExemplar={onEditExemplar} />
      </aside>
    );
  }

  // ── Render ─────────────────────────────────────────────
  return (
    <div>
      {/* Header bar */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10, flexWrap: 'wrap', marginBottom: 14 }}>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <span className={`cat-pill ${pill.cls}`}>{pill.label}</span>
          {f('id') && <span style={{ fontSize: '.75rem', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.ui.draftId'}, {id: f('id')})}</span>}
        </div>
        <button className="ab-button ab-button--ghost ab-button--sm" onClick={resetForm} type="button">{t({id:'catalogacao.ui.clearForm'})}</button>
      </div>

      {/* ── Admin réseau : attribuer la notice + exemplaires à une bibliothèque (E6 lot 7 : ReassignPanel) ── */}
      {isNetworkAdmin && f('published_book_id') && (
        <ReassignPanel bookId={f('published_book_id')} catalogLibraries={catalogLibraries}
          setMsg={setMsg} onSaved={onSaved} />
      )}

      {/* Message */}
      <CatalogStatusBar msg={msg} onClose={() => setMsg({ text: '', kind: '' })} />
      {/* ── « Publié — et maintenant ? » ── survit à la fiche vierge : on peut
          enchaîner un nouveau brouillon OU choisir une suite. */}
      {lastPublished && (
        <AfterPublishPanel
          title={t({ id: 'catalogacao.next.title' }, { title: lastPublished.title })}
          onClose={() => setLastPublished(null)}
          actions={[
            onAttachToBook && { id: 'exemplar', primary: true,
              label: t({ id: 'catalogacao.next.addExemplar' }), hint: t({ id: 'catalogacao.next.addExemplarHint' }),
              onClick: () => { onAttachToBook(lastPublished.bookId); setLastPublished(null); } },
            lastPublished.workId && { id: 'edition',
              label: t({ id: 'catalogacao.next.otherEdition' }), hint: t({ id: 'catalogacao.next.otherEditionHint' }),
              onClick: () => {
                selectEditionAsWork({ work_id: lastPublished.workId, titulo: lastPublished.title, autor: lastPublished.autor });
                setLastPublished(null);
              } },
            { id: 'new',
              label: t({ id: 'catalogacao.next.newDocument' }), hint: t({ id: 'catalogacao.next.newDocumentHint' }),
              onClick: () => { setLastPublished(null); setCreationChoice(null); } },
            onOpenBook && { id: 'open',
              label: t({ id: 'catalogacao.next.openBook' }), hint: t({ id: 'catalogacao.next.openInNewTab' }),
              onClick: () => onOpenBook(lastPublished.bookId) },
            onNavigateTab && { id: 'queue',
              label: t({ id: 'catalogacao.next.queue' }), hint: t({ id: 'catalogacao.next.queueHint' }),
              onClick: () => { setLastPublished(null); onNavigateTab('queuePanel'); } },
          ]}
        />
      )}

      {/* ── Bandeau doublon (Lot 6 anchor — logique dans CAT-B5) ── */}
      <div className={`ab-dup${dupBanner ? ' show' : ''}`}>
        <span className="ab-pill ab-pill--warn">{t({ id: 'catalogacao.duplicate.badge' })}</span>
        <div>
          <b>{t({ id: 'catalogacao.duplicate.title' })}</b>
          <div>{t({ id: 'catalogacao.duplicate.body' })}</div>
          <div className="ab-dup__actions">
            {dupBanner?.bookId && onOpenBook && (
              <button type="button" className="ab-button ab-button--mini" onClick={() => onOpenBook(dupBanner.bookId)}>
                {t({ id: 'catalogacao.duplicate.openExisting' })}
              </button>
            )}
            {dupBanner?.bookId && onAttachToBook && (
              <button type="button" className="ab-button ab-button--mini" onClick={() => { onAttachToBook(dupBanner.bookId); setDupBanner(null); }}>
                {t({ id: 'catalogacao.duplicate.attachHere' })}
              </button>
            )}
            <button type="button" className="ab-button ab-button--mini" onClick={() => setDupBanner(null)}>
              {t({ id: 'catalogacao.duplicate.reviseIsbn' })}
            </button>
          </div>
        </div>
      </div>

      {/* ── Modale d'avertissement doublon AVANT sauvegarde du brouillon ──
          Remplace le confirm() natif : plus visible pour un·e catalogueur·euse
          débutant·e. Bouton par défaut = revenir corriger ; « Enregistrer quand
          même » force la sauvegarde. */}
      {/* Meme garde `panelActive` que la modale de creation ci-dessous : si on
          change d'onglet alors que cet avertissement est ouvert, il devient
          invisible (panneau en display:none) tout en gardant le verrou de
          defilement. Le fermer ici relache le verrou ; l'etat dupModal est
          conserve, l'avertissement reapparait au retour sur l'onglet. */}
      <Modal
        isOpen={panelActive && !!dupModal}
        onClose={() => setDupModal(null)}
        title={t({ id: 'catalogacao.presave.dupModalTitle' })}
        size="small"
      >
        <p style={{ whiteSpace: 'pre-line', margin: '0 0 1rem' }}>
          {t(
            { id: dupModal?.kind === 'isbn' ? 'catalogacao.presave.isbnExists' : 'catalogacao.presave.approxExists' },
            { detail: dupModal?.detail || '' }
          )}
        </p>
        <div className="ab-modal__actions">
          {dupModal?.bookId && onOpenBook && (
            <button
              type="button"
              className="ab-button ab-button--ghost"
              onClick={() => { const id = dupModal.bookId; setDupModal(null); onOpenBook(id); }}
            >
              {t({ id: 'catalogacao.duplicate.openExisting' })}
            </button>
          )}
          <button type="button" className="ab-button ab-button--secondary" onClick={() => setDupModal(null)}>
            {t({ id: 'common.cancel' })}
          </button>
          <button
            type="button"
            className="ab-button ab-button--primary"
            onClick={() => handleSave(null, { skipDupCheck: true })}
          >
            {t({ id: 'catalogacao.presave.saveAnyway' })}
          </button>
        </div>
      </Modal>

      {/* Form + aperçu live (maquette v3, TRA-v3). La surface .ab-sheet est portée
          par le conteneur d'onglet .cat-panel (§7.3, toute la page) ; l'aperçu reste
          un sheet distinct (carte « catalogue »). */}
      <div className="ab-work">
      <form onSubmit={handleSave}>

        {/* ── Pop-up création : œuvre nouvelle vs nouvelle édition d'une œuvre existante ── */}
        {/* `panelActive` est INDISPENSABLE ici. Les 11 panneaux d'onglets de la
            page de catalogage restent MONTES en permanence : seul le CSS les
            masque (.cat-panel { display: none }). Sans ce garde, cette modale
            s'ouvrait des l'arrivee sur la page — sur un brouillon vierge,
            creationChoice vaut null — et restait ouverte quel que soit l'onglet
            consulte. Son voile etant a l'interieur d'un panneau en display:none,
            elle etait INVISIBLE et impossible a fermer, tout en gardant le
            verrou de defilement du body : plus d'ascenseur sur toute la page,
            sans aucune modale a l'ecran. Constate le 19/08/2026. */}
        <Modal
          isOpen={panelActive && creationChoice === null && !f('id') && !f('published_book_id') && !editingId && !prefillRecord}
          onClose={() => setCreationChoice('work')}
          title={t({ id: 'catalogacao.create.title' })}
          size="medium"
        >
          <p style={{ margin: '0 0 12px', fontSize: '.9rem' }}>{t({ id: 'catalogacao.create.question' })}</p>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <button type="button" className="ab-button" style={{ textAlign: 'left', display: 'block' }}
              onClick={() => { set('work_id', ''); setLinkedWorkLabel(''); setCreationChoice('work'); }}>
              <div style={{ fontWeight: 700 }}>{t({ id: 'catalogacao.create.newWork' })}</div>
              <div style={{ fontSize: '.72rem', opacity: .85 }}>{t({ id: 'catalogacao.create.newWorkDesc' })}</div>
            </button>
            <div style={{ padding: 10, borderRadius: 8, border: '1px solid rgba(255,255,255,.12)' }}>
              <div style={{ fontWeight: 700, fontSize: '.85rem' }}>{t({ id: 'catalogacao.create.newEdition' })}</div>
              <div style={{ fontSize: '.72rem', opacity: .85, marginBottom: 6 }}>{t({ id: 'catalogacao.create.newEditionDesc' })}</div>
              <input type="text" value={editionQuery} onChange={e => setEditionQuery(e.target.value)}
                placeholder={t({ id: 'catalogacao.create.searchEdition' })}
                style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
              {editionQuery.trim().length >= 3 && (
                <div style={{ marginTop: 4, maxHeight: 220, overflowY: 'auto', border: '1px solid rgba(255,255,255,.1)', borderRadius: 6 }}>
                  {editionSearching && <div style={{ padding: '8px 12px', fontSize: '.74rem', color: 'var(--brand-muted,#999)' }}>{t({ id: 'common.searching' })}</div>}
                  {!editionSearching && editionResults.length === 0 && <div style={{ padding: '8px 12px', fontSize: '.74rem', color: 'var(--brand-muted,#999)' }}>{t({ id: 'catalogacao.create.noEditionFound' })}</div>}
                  {editionResults.map(bk => (
                    <button type="button" key={bk.id} onClick={() => selectEditionAsWork(bk)}
                      style={{ display: 'block', width: '100%', textAlign: 'left', padding: '8px 12px', background: 'none', border: 'none', borderBottom: '1px solid rgba(255,255,255,.06)', cursor: 'pointer', color: 'inherit' }}>
                      <div style={{ fontSize: '.8rem', fontWeight: 700 }}>{bk.titulo}{bk.ano ? ` (${bk.ano})` : ''}</div>
                      <div style={{ fontSize: '.7rem', color: 'var(--brand-muted,#aaa)' }}>{[bk.autor, bk.edicao, bk.editora, bk.bib_ref ? `ref. ${bk.bib_ref}` : ''].filter(Boolean).join(' · ')}</div>
                    </button>
                  ))}
                </div>
              )}
            </div>
          </div>
        </Modal>

        {/* Bandeau : fiche rattachée à une œuvre existante */}
        {f('work_id') && !f('published_book_id') && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap', marginBottom: 12, padding: '8px 12px', borderRadius: 8, background: 'rgba(16,185,129,.08)', border: '1px solid rgba(16,185,129,.25)' }}>
            <span style={{ fontSize: '.8rem' }}>{t({ id: 'catalogacao.create.linkedWork' }, { title: linkedWorkLabel || `#${f('work_id')}` })}</span>
            <button type="button" className="ab-button ab-button--secondary ab-button--sm"
              onClick={() => { set('work_id', ''); setLinkedWorkLabel(''); }}>
              {t({ id: 'catalogacao.work.detach' })}
            </button>
          </div>
        )}

        {/* ── Cover anchor (Lot 6 — logique lookup dans CAT-C3/C4) ── */}
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
              onApplyCandidate={applyCandidate} onApplyBnResult={applyBnResult} />
          </div>
        </div>

        <div className="cat-book-grid">

          {/* ── Lote (hors registre — options dynamiques depuis le prop batches) ── */}
          <div className="ab-field">
            <label className="ab-field__label">{t({ id: 'catalogacao.field.batch' })}</label>
            <select className="ab-select" value={f('batch_id')} onChange={e => choisirLot(e.target.value)}>
              <option value="">{t({id:'catalogacao.ui.noLot'})}</option>
              {lotsDeLaNotice.map(b => <option key={b.id} value={String(b.id)}>{libelleLot(b, t)}</option>)}
            </select>
          </div>

          {/* ── Type de matériel (registry-driven) ──── */}
          {rrf('tipo_material')}

          {/* ── Guide contextuel ─────────────────────── */}
          {(() => {
            const mt = materialType || 'livro';
            return (
              <div style={{ gridColumn: 'span 1' }}>
                <div style={{ padding: '10px 12px', borderRadius: 8, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.06)', fontSize: '.78rem' }}>
                  {/* #fix-android (19/07) : meme cause que le panneau "Arquitetura
                      documental" (commit 57ea0a30d) -- flexWrap manquant sur cette
                      ligne titre+badge, confirme en overflow reel sur Android. */}
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4, flexWrap: 'wrap', gap: 6 }}>
                    <strong style={{ fontSize: '.82rem' }}>{t({ id: `catalogacao.guide.${mt}.title` })}</strong>
                    <span className={`cat-pill ${mode === 'simple' ? 'info' : 'ok'}`} style={{ fontSize: '.62rem' }}>
                      {mode === 'simple' ? t({ id: 'catalogacao.modeSimple' }) : t({ id: 'catalogacao.modeComplete' })}
                    </span>
                  </div>
                  <div style={{ color: 'var(--brand-muted, #aaa)', marginBottom: 6 }}>{t({ id: `catalogacao.guide.${mt}.hint` })}</div>
                  <div><strong>{t({ id: 'catalogacao.field.focusNow', defaultMessage: 'Focus:' })}</strong> {t({ id: `catalogacao.guide.${mt}.simple` })}</div>
                  {mode === 'complete' && (
                    <div style={{ marginTop: 4, color: 'var(--brand-muted, #aaa)' }}>
                      <strong>{t({ id: 'catalogacao.modeComplete' })}:</strong> {t({ id: `catalogacao.guide.${mt}.complete` })}
                    </div>
                  )}
                </div>
              </div>
            );
          })()}

          {/* ── Core fields (registry-driven, Lot 2) ── */}
          {rrf('bib_ref')}
          {(() => {
            const v = f('bib_ref').trim();
            if (!v || !bibRefConv?.bib_ref_auto) return null;
            const pad = Math.max(bibRefConv.bib_ref_pad || 1, 1);
            const re = new RegExp('^' + (bibRefConv.bib_ref_prefix || '') + '\\d{' + pad + ',}$');
            return re.test(v) ? null : (
              <div style={{ fontSize: '.72rem', color: '#fbbf24', marginTop: 2 }}>
                {t({ id: 'catalogacao.bibref.offConvention' })}
              </div>
            );
          })()}
          {rrf('titulo')}
          {rrf('subtitulo')}
          {/* C6 §7.2 — normaliser la casse du titre selon sa langue, avec aperçu (jamais à la frappe) */}
          <TitleCaseAssist titulo={f('titulo')} subtitulo={f('subtitulo')} idioma={f('idioma')}
            onApply={(ti, st) => { set('titulo', ti); set('subtitulo', st); }} />

          {/* ── Autores e outras responsabilidades (E6 lot 4 : ContributorsPanel) ── */}
          <ContributorsPanel contributors={contributors} setContributors={setContributors}
            availableRoleKeys={availableRoleKeys} roleLabel={roleLabel} autor={f('autor')} setMsg={setMsg}
            onDirty={() => { if (draftState === 'saved' || draftState === 'ready') setDraftState('dirty'); }} />

          {/* ── Tome / volume (décision 6 du 04/09/2026 : les tomes vivent dans
              l'œuvre). Même colonne `volume` que les périodiques, qui ont déjà
              leur champ ; pour une monographie il dit « quel tome de l'œuvre ».
              Visible dès qu'une œuvre est en jeu (rattachée ou publiée). */}
          {!SERIAL_TYPES.has(f('tipo_material')) && (f('work_id') || f('published_book_id')) && (
            <div className="ab-span3" style={{ gridColumn: 'span 3', marginBottom: 6, display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
              <label htmlFor="ab-work-volume" style={{ fontWeight: 600, fontSize: '.88rem' }} title={t({ id: 'catalogacao.work.volumeHint' })}>
                {t({ id: 'catalogacao.work.volume' })}
              </label>
              <input id="ab-work-volume" type="text" value={f('volume')} list="ab-work-volume-list"
                onChange={(e) => set('volume', e.target.value)} placeholder="I, 2, 1/2"
                title={t({ id: 'catalogacao.work.volumeHint' })}
                style={{ width: 90, padding: '5px 8px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.25)', color: 'inherit', fontSize: '.82rem' }} />
              <datalist id="ab-work-volume-list">
                {['1', '2', '3', '4', 'I', 'II', 'III', 'IV'].map((v) => <option key={v} value={v} />)}
              </datalist>
              <span style={{ fontSize: '.74rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.work.volumeHint' })}</span>
            </div>
          )}

          {/* ── Œuvre (P4) — palier avancé/complet ───────── */}
          {catalogTier >= 2 && f('published_book_id') && (
            <div className="ab-span3" style={{ gridColumn: 'span 3', marginBottom: 6 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
                <span style={{ fontWeight: 600, fontSize: '.88rem' }}>{t({ id: 'catalogacao.work.title' })}</span>
                {work ? (
                  <>
                    <span style={{ fontSize: '.82rem' }}>{work.uniform_title} · {t({ id: 'catalogacao.work.editions' }, { count: work.count })}</span>
                    <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={detachWork} disabled={workBusy}>
                      {t({ id: 'catalogacao.work.detach' })}
                    </button>
                  </>
                ) : (
                  <>
                    <span style={{ fontSize: '.8rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.work.none' })}</span>
                    <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={createWork} disabled={workBusy}>
                      {t({ id: 'catalogacao.work.create' })}
                    </button>
                  </>
                )}
                <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                  onClick={findEditionSuggestions} disabled={editionSuggLoading || workBusy}>
                  {editionSuggLoading ? t({ id: 'catalogacao.dedup.finding' }) : t({ id: 'catalogacao.work.suggest' })}
                </button>
              </div>
              {/* OPAC par œuvre (04/09/2026) : rattacher à une autre œuvre (lot 1b),
                  titres par langue (lot 3). */}
              <WorkToolsBlock
                bookId={Number(f('published_book_id'))}
                workId={work?.id || null}
                onChanged={() => setWorkNonce(n => n + 1)}
                onMsg={(text, kind) => (kind === 'ok' ? confirmSaved(text) : setMsg({ text, kind }))}
              />
              {editionSugg !== null && editionSugg.length === 0 && (
                <div style={{ fontSize: '.8rem', color: 'var(--brand-muted, #aaa)', marginTop: 6 }}>{t({ id: 'catalogacao.work.noSuggestions' })}</div>
              )}
              {editionSugg !== null && editionSugg.length > 0 && (
                <div style={{ marginTop: 6, border: '1px solid rgba(255,255,255,.08)', borderRadius: 8, overflow: 'hidden' }}>
                  {editionSugg.map(s => (
                    <div key={s.book_id} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 10px', borderBottom: '1px solid rgba(255,255,255,.04)' }}>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ fontSize: '.82rem' }}>{s.titulo}{s.ano ? ` (${s.ano})` : ''}</div>
                        <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #aaa)' }}>{[s.editora, s.work_id ? t({ id: 'catalogacao.work.alreadyInWork' }) : null].filter(Boolean).join(' · ')}</div>
                      </div>
                      <span style={{ fontSize: '.6rem', color: 'var(--brand-muted, #aaa)' }}>{Math.round((Number(s.score) || 0) * 100)}%</span>
                      <button type="button" className="ab-button ab-button--sm" disabled={bookDupBusy != null || fusionBusy}
                        onClick={async () => { await groupAsEditions(s.book_id); findEditionSuggestions(); }}>
                        {bookDupBusy === s.book_id ? '…' : t({ id: 'catalogacao.work.group' })}
                      </button>
                      {arbitreDoublons && (
                        <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                          disabled={bookDupBusy != null || fusionBusy}
                          title={t({ id: 'catalogacao.work.sameEditionHint' })}
                          onClick={() => ouvrirFusionEdition(s)}>
                          {t({ id: 'catalogacao.work.sameEditionMerge' })}
                        </button>
                      )}
                    </div>
                  ))}
                </div>
              )}
              {/* L'aperçu de l'assistant (temps 3), en ligne — jamais de modale (DEDUP-9). */}
              {fusionEdition && (
                <div style={{ marginTop: 8, border: '1px solid rgba(220,38,38,.35)', borderRadius: 8, padding: 10 }}>
                  <div style={{ fontSize: '.8rem', color: 'var(--brand-muted, #bbb)', marginBottom: 8 }}>
                    {t({ id: 'catalogacao.work.sameEditionHint' })}
                  </div>
                  <ApercuFusion
                    ex={{ ...fusionEdition, survivant: Number(f('published_book_id')) }}
                    r={{
                      book_id_a: Number(f('published_book_id')), book_id_b: fusionEdition.bookId,
                      ref_a: f('bib_ref'), ref_b: fusionEdition.apercu?.doublon?.ref || '',
                      titulo_a: f('titulo'), titulo_b: fusionEdition.titulo,
                    }}
                    busy={fusionBusy} t={t} interdits={champsInterdits} survivantFixe
                    onSurvivant={() => {}}
                    onRetour={() => setFusionEdition(null)}
                    onSaisie={(v) => setFusionEdition((p) => (p ? { ...p, saisie: v } : p))}
                    onReprise={(champ) => setFusionEdition((p) => {
                      if (!p) return p;
                      const reprises = p.reprises.includes(champ) ? p.reprises.filter((c) => c !== champ) : [...p.reprises, champ];
                      return { ...p, reprises };
                    })}
                    onFusion={fusionnerEdition}
                  />
                </div>
              )}
            </div>
          )}

          {/* ── Segments sonores (P3b — #AUDIO-fonds) — notice audio/audiovisuelle publiée ─────── */}
          {f('published_book_id') && (isAudio || isAudiovisual) && (
            <div className="ab-span3" style={{ gridColumn: 'span 3' }}>
              <AudioSegmentsBlock bookId={f('published_book_id')} onMsg={(text, kind) => (kind === 'ok' ? confirmSaved(text) : setMsg({ text, kind }))} />
            </div>
          )}

          {/* ── Doublons possibles (documents, lecture seule P2a) — palier avancé/complet ─────── */}
          {catalogTier >= 2 && f('published_book_id') && (
            <div className="ab-span3" style={{ gridColumn: 'span 3' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap', marginBottom: 6 }}>
                <span style={{ fontWeight: 600, fontSize: '.88rem' }}>{t({ id: 'catalogacao.dedup.title' })}</span>
                <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                  onClick={findBookDuplicates} disabled={bookDupLoading}>
                  {bookDupLoading ? t({ id: 'catalogacao.dedup.finding' }) : t({ id: 'catalogacao.dedup.find' })}
                </button>
              </div>
              {bookDupMatches !== null && bookDupMatches.length === 0 && (
                <div style={{ fontSize: '.8rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.dedup.none' })}</div>
              )}
              {bookDupMatches !== null && bookDupMatches.length > 0 && (
                <div style={{ border: '1px solid rgba(255,255,255,.08)', borderRadius: 8, overflow: 'hidden' }}>
                  {bookDupMatches.map(d => (
                    <div key={d.book_id} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 10px', borderBottom: '1px solid rgba(255,255,255,.04)' }}>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ fontSize: '.82rem' }}>{d.titulo}{d.ano ? ` (${d.ano})` : ''}</div>
                        <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #aaa)' }}>{d.autor}{d.editora ? ` · ${d.editora}` : ''}{d.isbn ? ` · ISBN ${d.isbn}` : ''}</div>
                      </div>
                      <span style={{ fontSize: '.7rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.dedup.copies' }, { count: d.exemplares })}</span>
                      <span className={`cat-pill ${d.match_kind === 'isbn' ? 'ok' : 'warn'}`} style={{ fontSize: '.6rem' }}>
                        {d.match_kind === 'isbn' ? 'ISBN' : t({ id: 'catalogacao.link.approx' })} {Math.round(d.score * 100)}%
                      </span>
                      <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                        onClick={() => groupAsEditions(d.book_id)} disabled={bookDupBusy != null}
                        title={t({ id: 'catalogacao.dedup.sameWorkHint' })}>
                        {t({ id: 'catalogacao.dedup.sameWork' })}
                      </button>
                      {arbitreDoublons ? (
                        <>
                          <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                            onClick={() => markBooksNotDuplicate(d.book_id)} disabled={bookDupBusy != null}
                            title={t({ id: 'catalogacao.dedup.notDuplicateHint' })}>
                            {t({ id: 'catalogacao.dedup.notDuplicate' })}
                          </button>
                          <button type="button" className="ab-button ab-button--danger ab-button--sm"
                            onClick={() => mergeBookDuplicateIntoCurrent(d.book_id, d.titulo)} disabled={bookDupBusy != null}
                            title={t({ id: 'catalogacao.dedup.deleteThisRecordHint' })}>
                            {bookDupBusy === d.book_id ? '…' : t({ id: 'catalogacao.dedup.deleteThisRecord' })}
                          </button>
                        </>
                      ) : (
                        <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                          onClick={() => reportDuplicatePair(d.book_id)} disabled={bookDupBusy != null}
                          title={t({ id: 'catalogacao.dedup.reportHint' })}>
                          {bookDupBusy === d.book_id ? '…' : t({ id: 'catalogacao.dedup.report' })}
                        </button>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {rrf('edicao')}
          {rrf('editora')}
          {pubSuggestions.length > 0 && (
            <div className="cat-pub-suggestions" style={{ margin: '-6px 0 8px 0', border: '1px solid var(--brand-panel-border, rgba(255,255,255,.18))', borderRadius: 6, background: 'var(--brand-panel-bg-strong, rgba(10,10,10,.94))', color: 'var(--brand-text, #f5f2ea)', maxHeight: 180, overflowY: 'auto', fontSize: '.78rem' }}>
              {pubSuggestions.map(pub => (
                <div key={pub.id} onClick={() => selectPublisher(pub)}
                  style={{ padding: '4px 10px', cursor: 'pointer', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 6, borderBottom: '1px solid var(--brand-panel-border, rgba(255,255,255,.1))' }}
                  onMouseEnter={e => e.currentTarget.style.background = 'rgba(255,255,255,.08)'}
                  onMouseLeave={e => e.currentTarget.style.background = 'transparent'}>
                  <span style={{ fontWeight: 500 }}>{pub.name}</span>
                  <span style={{ fontSize: '.65rem', color: 'var(--brand-muted, #d4cec3)' }}>
                    {pub.city || ''}{pub.match_kind === 'exact' ? ' ✓' : ` ${Math.round(pub.score * 100)}%`}
                  </span>
                </div>
              ))}
            </div>
          )}
          {rrf('colecao')}

          {rrf('local_publicacao')}
          {rrf('ano')}
          {rrf('idioma')}

          {/* ── ISBN / ISSN / CDD ────────────────────── */}
          {rrf('isbn')}
          {isbnDupHint && (
            <div className="cat-isbn-dup-hint" style={{ fontSize: '.75rem', color: 'var(--brand-warn, #b45309)', margin: '-6px 0 8px 0', display: 'flex', alignItems: 'center', gap: 6 }}>
              <span style={{ fontWeight: 600 }}>{t({ id: 'catalogacao.isbnDup.badge' })}</span>
              <span>{isbnDupHint.titulo}{isbnDupHint.library ? ` (${isbnDupHint.library})` : ''}</span>
              {isbnDupHint.bookId && onOpenBook && (
                <button type="button" className="ab-button ab-button--mini" style={{ fontSize: '.65rem', padding: '1px 6px' }} onClick={() => onOpenBook(isbnDupHint.bookId)}>
                  {t({ id: 'catalogacao.duplicate.openExisting' })}
                </button>
              )}
            </div>
          )}
          {rrf('issn')}
          {rrf('cdd')}

          {/* ── Périodique fields (registry-driven, in-grid) ── */}
          {/* #périodiques P7 — sélecteur de titre de revue, EN TÊTE de la zone :
              on choisit la revue avant de décrire le numéro. Il est monté ICI,
              et non via `sectionExtras` + renderMaterialSection comme livré le
              27/08/2026 : le groupe `periodico` du registre n'est pas une section
              « matériel » (absent de MATERIAL_SECTION_IDS), ses champs sont rendus
              un par un dans la grille principale, et l'entrée `sectionExtras.periodico`
              n'a donc JAMAIS été rendue — constaté en prod le 02/09/2026, aux trois
              paliers. Ajouter `periodico` à MATERIAL_SECTION_IDS aurait été la
              fausse correction : les six champs seraient apparus deux fois.
              Il écrit dans le formulaire (serial_id est une colonne du brouillon),
              jamais en base : la publication recopie (P7a). */}
          {showSerialPicker && (
            <SerialAuthorityPicker
              value={f('serial_id')}
              onChange={(v) => set('serial_id', v)}
              publishedBookId={f('published_book_id')}
            />
          )}
          {rrf('titulo_periodico')}
          {rrf('volume')}
          {rrf('numero')}
          {rrf('data_edicao')}
          {rrf('fasciculo')}
          {rrf('periodicidade')}

          {/* ── Pages + circulação (seg = segmented control, spec §5.6) ── */}
          {rrf('paginas')}
          {rrf('circulation_default')}

          {/* ── Prévia de cote / étiquette (tier 3 ; E6 lot 6 : ShelfLabelPreview) ── */}
          {catalogTier >= 3 && <ShelfLabelPreview author={f('autor')} title={f('titulo')} cdd={f('cdd')} />}

          {/* ── Assuntos + Notas + Cover path ─────────── */}
          {rrf('subjects')}
          <SubjectAuthorityPicker draftId={f('id')} reloadKey={importedCheck} />
          {rrf('notas')}
          {rrf('cover_object_path')}

          {/* ═══ Material-specific panels + Acquisition (registry-driven) ═══ */}
          {visibleGroups(catalogTier, materialType)
            .filter(g => MATERIAL_SECTION_IDS.includes(g.id) || g.id === 'aquisicao')
            .map(g => renderMaterialSection(g, ctx))}

          {/* ═══ Recursos digitais vinculados (E6 lot 2 : DigitalResourcesPanel) ═══ */}
          <DigitalResourcesPanel draftId={f('id')} ownerLibraryId={f('owner_library_id')} resources={digitalResources}
            onChanged={() => loadDigitalResources(f('id'))} setMsg={setMsg} />

          {/* ═══ MARC JSON (registry-driven, tier 3) ═══ */}
          {rrf('marc_json')}

        </div>

        {/* ═══ Painel de revisão da ficha (E6 lot 5 : ReviewPanel) ═══ */}
        <ReviewPanel f={f} draftId={f('id')}
          materialLabel={MATERIAL_TYPES.find(m => m.value === materialType)?.label || materialType}
          isbdEnabled={isbdEnabled} isbdData={isbdData} zoneLabels={ZONE_LABELS}
          onPrepareIsbd={prepareIsbd} onClearIsbd={clearIsbd} />

        {/* ── Exemplaires initiaux (fiche non encore publiée ; E6 lot 6 : InitialCopiesBlock) ── */}
        {!f('published_book_id') && (
          <InitialCopiesBlock importedItems={importedItems} copies={f('initial_copies')}
            libraryIdValue={f('initial_copies_library_id')} isNetworkAdmin={isNetworkAdmin}
            libraries={catalogLibraries} onChange={set} fichierSansExemplaire={fichierSansExemplaire} />
        )}

        {/* ── Action buttons ─────────────────────────── */}
        <div style={{ display: 'flex', gap: 10, marginTop: 18, flexWrap: 'wrap' }}>
          <button type="submit" className="ab-button" disabled={saving}>
            {saving ? t({id:'common.saving'}) : t({id:'catalogacao.ui.saveDraft'})}
          </button>
          {f('id') && draftState !== 'published' && (
            <button type="button" className="ab-button ab-button--secondary" onClick={handlePublish}>
              {t({id:'catalogacao.publish'})}
            </button>
          )}
          <button type="button" className="ab-button ab-button--ghost" onClick={resetForm}>
            {t({id:'catalogacao.ui.clear'})}
          </button>
        </div>
      </form>
      {renderLivePreview()}
      </div>
    </div>
  );
}
