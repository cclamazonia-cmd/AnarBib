import { useIntl } from 'react-intl';
import { useConfirm } from '@/contexts/ConfirmContext';
import { useState, useEffect, useMemo, useRef, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import SubjectAuthorityPicker from './SubjectAuthorityPicker';
import { useStaffLibraries, bibliothequesProposables, lotsProposables, lotDeLaBibliotheque, libelleLot } from '@/lib/useStaffLibraries';
import SerialAuthorityPicker from './SerialAuthorityPicker';
import AudioSegmentsBlock from './AudioSegmentsBlock';
import DigitalResourcesPanel from './DigitalResourcesPanel';
import ContributorsPanel from './ContributorsPanel';
import ReviewPanel from './ReviewPanel';
import BookCoverPanel from './BookCoverPanel.jsx';
import { useNoticePersistance } from './useNoticePersistance.js';
import BookDuplicatesPanel from './BookDuplicatesPanel.jsx';
import BookWorkPanel from './BookWorkPanel.jsx';
import BookCreationChoice from './BookCreationChoice.jsx';
import ShelfLabelPreview from './ShelfLabelPreview';
import ExemplaresPanel from './ExemplaresPanel';
import ReassignPanel from './ReassignPanel';
import InfoCards from './InfoCards';
import DivergencesNotice from '@/components/catalog/DivergencesNotice';
import TitleCaseAssist from '@/components/catalog/TitleCaseAssist';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { useSaveConfirmation } from '@/hooks/useSaveConfirmation';
import CatalogStatusBar from '@/components/catalog/CatalogStatusBar';
import AfterPublishPanel from './AfterPublishPanel';
import { useUntouchedRetake } from '@/hooks/useUntouchedRetake';
import { localizeError } from '@/lib/localizeError';
import { canArbitrateDuplicates } from '@/lib/dedupRoles';
import { visibleGroups, tierFromMode } from './fieldRegistry.js';
import { renderMaterialSection, renderRegistryField } from './CatalogFieldRenderer.jsx';
import Modal from '@/components/ui/Modal';

// Constantes et fonctions pures du formulaire : src/lib/catalogacao/bookDraft.js (E6, lot 1)
import { MATERIAL_TYPE_KEYS, SERIAL_TYPES, TRACT_TYPES, MATERIAL_SECTION_IDS, roleKeysForMaterial, AUTHOR_DISPLAY_ROLES, EMPTY_FORM } from '@/lib/catalogacao/bookDraft';

// ═══════════════════════════════════════════════════════════
// BookDraftForm
// ═══════════════════════════════════════════════════════════

export default function BookDraftForm({ batches = [], mode = 'simple', onSaved, onOpenBook, onAttachToBook, editingId = null, onConsumed, onNavigateTab, onEditExemplar, onEditExemplarDraft, prefillRecord = null, prefillFile = null, panelActive = true, onOpenDraft }) {
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
  const [lastPublished, setLastPublished] = useState(null); // { bookId, draftId, title, workId, autor } | null — « Publié — et maintenant ? » (AfterPublishPanel)
  // C29 lot 4 : « Ajouter un exemplaire » rouvre la fiche publiée et demande au
  // panneau Exemplaires d'ouvrir son formulaire court ({ bookId, nonce }).
  const [copieDemandee, setCopieDemandee] = useState(null);
  const [isbnDupHint, setIsbnDupHint] = useState(null); // { bookId, titulo, bibRef, libraries } | null — live ISBN check
  const [pubSuggestions, setPubSuggestions] = useState([]); // publisher typeahead results
  // Doublons de documents (detection + fusion, P2a/P2b)
  const [bookDupMatches, setBookDupMatches] = useState(null); // null = pas cherche
  const [bookDupLoading, setBookDupLoading] = useState(false);
  const [bookDupBusy, setBookDupBusy] = useState(null); // book_id en cours de fusion
  // Œuvre rattachée (P4) : { id, uniform_title, count } | null
  const [work, setWork] = useState(null);
  const [workNonce, setWorkNonce] = useState(0);
  // P4 v2 : suggestions d'éditions à regrouper (même auteur·rice + titre proche)
  const [editionSugg, setEditionSugg] = useState(null); // null = pas cherché
  // 28/09/2026 (décision Xavier) : une édition suggérée qui est en fait la MÊME
  // édition (année fautive : BTL-TL-000880/881) se fusionne d'ici, par l'aperçu
  // de l'assistant — la détection de doublons, elle, garde sa règle stricte.
  // { bookId, titulo, apercu, saisie, reprises } ; la survivante est la notice éditée.
  const [fusionEdition, setFusionEdition] = useState(null);
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
  // {thumbnailUrl, thumbnailData, fullUrl, source, license}
  // thumbnailData = l'aperçu rapatrié côté serveur, seul à finir dans un `src`.
  const [coverCandidates, setCoverCandidates] = useState([]);

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
  // Enregistrer, publier, recharger la notice, ses contributeur·rices et ses
  // ressources : useNoticePersistance.js (E6, 23/10/2026).
  const {
    fillFromRecord, findBookDuplicates, groupAsEditions, handlePublish, handleSave, isbdData,
    loadDigitalResources, pill, uploadCover, ZONE_LABELS,
  } = useNoticePersistance({
    attachOcrPdf, confirmer, confirmSaved, contributors, coverFile, draftState, f, form, isArtigo,
    isAudio, isAudiovisual, isDigitalNative, isDossier, isNetworkAdmin, isRelatorio, isTese,
    isTract, isZine, materialType, ocrFileRef, onSaved, resetForm, set, setBookDupBusy,
    setBookDupLoading, setBookDupMatches, setContributors, setCoverCandidates, setCoverFile,
    setCoverUploading, setCreationChoice, setDigitalResources, setDraftState, setDupBanner,
    setDupModal, setEditionSugg, setForm, setFusionEdition, setImportedCheck, setIsbnDupHint,
    setLastPublished, setMsg, setSaving, setWork, setWorkNonce, showMsg, t, trackRetake, user,
  });

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
        <InfoCards contributors={contributors} onNavigateTab={onNavigateTab} />
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

      {/* H21 lot 5 (IMP-32 a) : un réimport a trouvé cette notice partagée
          différente sans la réécrire — bandeau et détail pour la coordination
          d'une détentrice (vide pour les autres). */}
      {f('published_book_id') && (
        <DivergencesNotice bookId={f('published_book_id')} onOpenDraft={onOpenDraft} />
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
            // C29 lot 4 : on reste dans la fiche — elle se rouvre publiée, et le
            // panneau Exemplaires ouvre son formulaire court (bibliothèque et
            // numéro proposés). L'éditeur complet reste à un clic dans le panneau.
            onOpenDraft && lastPublished.draftId && { id: 'exemplar', primary: true,
              label: t({ id: 'catalogacao.next.addExemplar' }), hint: t({ id: 'catalogacao.next.addExemplarHint' }),
              onClick: () => {
                setCopieDemandee({ bookId: lastPublished.bookId, nonce: Date.now() });
                onOpenDraft(lastPublished.draftId);
                setLastPublished(null);
              } },
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
        <BookCreationChoice {...{
            creationChoice, editingId, editionQuery, editionResults, editionSearching, f,
            panelActive, prefillRecord, selectEditionAsWork, set, setCreationChoice,
            setEditionQuery, setLinkedWorkLabel,
        }} />
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
        <BookCoverPanel {...{
            confirmSaved, contributors, coverCandidates, coverFile, coverPreviewUrl, coverUploading,
            digitalResources, draftState, f, set, setContributors, setCoverCandidates, setCoverFile,
            setCoverPreviewUrl, setDraftState, setForm, setMany, setMsg, uploadCover,
        }} />
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
          <BookWorkPanel {...{
              arbitreDoublons, bookDupBusy, catalogTier, confirmSaved, confirmer, draftState,
              editionSugg, f, fillFromRecord, findBookDuplicates, fusionEdition, groupAsEditions,
              setEditionSugg, setFusionEdition, setMsg, setWorkNonce, work,
          }} />
          {/* ── Segments sonores (P3b — #AUDIO-fonds) — notice audio/audiovisuelle publiée ─────── */}
          {f('published_book_id') && (isAudio || isAudiovisual) && (
            <div className="ab-span3" style={{ gridColumn: 'span 3' }}>
              <AudioSegmentsBlock bookId={f('published_book_id')} onMsg={(text, kind) => (kind === 'ok' ? confirmSaved(text) : setMsg({ text, kind }))} />
            </div>
          )}

          {/* ── Doublons possibles (documents, lecture seule P2a) — palier avancé/complet ─────── */}
          <BookDuplicatesPanel {...{
              arbitreDoublons, bookDupBusy, bookDupLoading, bookDupMatches, catalogTier, confirmer,
              draftState, f, fillFromRecord, findBookDuplicates, groupAsEditions, setBookDupBusy,
              setMsg,
          }} />
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

          {/* ═══ Exemplaires de la notice (C29 lot 1 : ExemplaresPanel ; lot 4 : un seul endroit —
              les exemplaires initiaux d'une fiche non publiée y vivent aussi, et « Ajouter un
              exemplaire » après publication y ouvre le formulaire court) ═══ */}
          <ExemplaresPanel publishedBookId={form.published_book_id} draftId={f('id')} reloadKey={importedCheck}
            onNewCopy={onAttachToBook} onEditPublished={onEditExemplar} onEditDraft={onEditExemplarDraft}
            ouvrirNouveau={copieDemandee}
            initialCopies={{ importedItems, copies: f('initial_copies'), libraryIdValue: f('initial_copies_library_id'),
              isNetworkAdmin, libraries: catalogLibraries, onChange: set, fichierSansExemplaire }} />

          {/* ═══ MARC JSON (registry-driven, tier 3) ═══ */}
          {rrf('marc_json')}

        </div>

        {/* ═══ Painel de revisão da ficha (E6 lot 5 : ReviewPanel) ═══ */}
        <ReviewPanel f={f} draftId={f('id')}
          materialLabel={MATERIAL_TYPES.find(m => m.value === materialType)?.label || materialType}
          isbdData={isbdData} zoneLabels={ZONE_LABELS} />

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
