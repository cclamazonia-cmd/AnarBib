import { useIntl } from 'react-intl';
import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useAuth } from '@/contexts/AuthContext';
import PortraitCropper from '@/components/catalogacao/PortraitCropper';

// ── Authority types ───────────────────────────────────────
const AUTHORITY_TYPE_KEYS = {
  person: 'catalogacao.author.type.person',
  collective: 'catalogacao.author.type.collective',
  publisher_series: 'catalogacao.author.type.publisherSeries',
  place_campaign_theme: 'catalogacao.author.type.placeCampaignTheme',
  other: 'catalogacao.author.type.other',
};
const AUTHORITY_TYPE_VALUES = ['person', 'collective', 'publisher_series', 'place_campaign_theme', 'other'];

// Locales du widget bio multilingue (= CHECK author_translations.lang).
const ALLOWED_BIO_LANGS = ['pt-BR', 'fr', 'es', 'en', 'it', 'de', 'ca', 'eo', 'nl', 'el'];

const SOURCE_KIND_KEYS = {
  '': 'catalogacao.author.sourceKind.select',
  catalog: 'catalogacao.author.sourceKind.catalog',
  viaf: 'catalogacao.author.sourceKind.viaf',
  wikidata: 'catalogacao.author.sourceKind.wikidata',
  publisher: 'catalogacao.author.sourceKind.publisher',
  book: 'catalogacao.author.sourceKind.book',
  other: 'catalogacao.author.sourceKind.other',
};
const SOURCE_KIND_VALUES = ['', 'catalog', 'viaf', 'wikidata', 'publisher', 'book', 'other'];

// ── Status keys (for draft list display) ─────────────────
const STATUS_KEYS = {
  draft: 'catalogacao.status.draft',
  ready: 'catalogacao.status.ready',
  published: 'catalogacao.status.published',
  cancelled: 'catalogacao.status.cancelled',
};
const ACTION_KEYS = {
  create: 'catalogacao.status.new',
  update: 'catalogacao.status.retaken',
};

// ── Name helpers (sort name from preferred name) ──────────
function stripDiacritics(v) { return (v || '').normalize('NFD').replace(/[̀-ͯ]/g, ''); }

function buildSortName(preferredName, authorityType) {
  const clean = (preferredName || '').replace(/\s+/g, ' ').trim();
  if (!clean) return '';
  if (authorityType !== 'person') return clean;
  // Person: "Osvaldo BAYER" → "BAYER, Osvaldo"
  const tokens = clean.split(/\s+/);
  if (tokens.length < 2) return clean;
  const particles = new Set(['da', 'de', 'del', 'della', 'di', 'do', 'dos', 'das', 'du', 'des', 'e', 'la', 'le', 'los', 'las', 'van', 'von', 'y']);
  // Find the last non-particle token
  let surnameIdx = tokens.length - 1;
  for (let i = tokens.length - 1; i >= 0; i--) {
    if (!particles.has(stripDiacritics(tokens[i]).toLowerCase())) { surnameIdx = i; break; }
  }
  const surname = tokens[surnameIdx];
  const rest = [...tokens.slice(0, surnameIdx), ...tokens.slice(surnameIdx + 1)].join(' ').trim();
  return rest ? `${surname}, ${rest}` : surname;
}

// ── Structured meta (dedicated jsonb column) ─────────────
// Legacy: meta was packed as JSON markers inside notes. Now stored in
// authors.structured_meta / author_drafts.structured_meta (jsonb).
// The pack/extract helpers are removed; we read/write the column directly.

export default function AuthorDraftForm({ mode, batches, editingId = null, onConsumed, onChanged }) {
  const { formatMessage: t, locale } = useIntl();
  const { user } = useAuth();
  const [drafts, setDrafts] = useState([]);
  const [draftsLoading, setDraftsLoading] = useState(false);
  const [form, setForm] = useState({});
  const [meta, setMeta] = useState({
    authorityType: 'person', acronym: '', activityPeriod: '', affiliation: '', variantNames: '',
    pseudonyms: '', activityPlace: '', contextLinks: '',
  });
  const [assistRaw, setAssistRaw] = useState('');
  const [draftState, setDraftState] = useState('new');
  const [saving, setSaving] = useState(false);
  const [publishing, setPublishing] = useState(false);
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [photoFile, setPhotoFile] = useState(null);
  const [photoPreviewUrl, setPhotoPreviewUrl] = useState('');
  const [photoUploading, setPhotoUploading] = useState(false);
  // ── Portrait lookup (Wikidata P18 → Commons) ──
  const [portraitCandidates, setPortraitCandidates] = useState(null);
  const [portraitLoading, setPortraitLoading] = useState(false);
  const [portraitStoring, setPortraitStoring] = useState('');
  // Recadrage « foto 3×4 » : { src (blob URL), attribution } | null
  const [cropState, setCropState] = useState(null);
  const [bioTranslations, setBioTranslations] = useState([]);
  const [bioDirty, setBioDirty] = useState(new Set()); // langues éditées (à upserter en status=draft)
  const [bioReviewBusy, setBioReviewBusy] = useState(null); // lang en cours de bascule de revue
  // Rattachement aux oeuvres (liaison autorite<->livres)
  const [linkMatches, setLinkMatches] = useState(null); // null = pas cherche ; [] = cherche, vide
  const [linkLoading, setLinkLoading] = useState(false);
  const [linkSelected, setLinkSelected] = useState(new Set());
  const [linkBusy, setLinkBusy] = useState(false);
  // Doublons d'autorite
  const [dupMatches, setDupMatches] = useState(null); // null = pas cherche
  const [dupLoading, setDupLoading] = useState(false);
  const [dupBusy, setDupBusy] = useState(null); // author_id en cours de fusion
  // Recherche d'autorite externe (Wikidata → VIAF/ISNI/variant_forms)
  const [authLookupResults, setAuthLookupResults] = useState(null);
  const [authLookupLoading, setAuthLookupLoading] = useState(false);

  const PROJECT_URL = 'https://uflwmikiyjfnikiphtcp.supabase.co';
  const photoDisplayUrl = photoPreviewUrl
    || (form.photo_object_path ? `${PROJECT_URL}/storage/v1/object/public/authors/${form.photo_object_path}` : '');

  const EMPTY_FORM = {
    id: '', published_author_id: '', batch_id: '', action: 'create', status: 'draft',
    preferred_name: '', sort_name: '', biography: '', birth_year: '', death_year: '',
    country: '', source_kind: '', source_label: '', source_url: '',
    viaf_id: '', isni: '', wikidata_id: '', photo_object_path: '', notes: '',
  };

  function f(k) { return form[k] || ''; }
  function set(k, v) { setForm(p => ({ ...p, [k]: v })); if (draftState === 'saved' || draftState === 'ready') setDraftState('dirty'); }
  function setM(k, v) { setMeta(p => ({ ...p, [k]: v })); if (draftState === 'saved' || draftState === 'ready') setDraftState('dirty'); }

  // ── Load drafts list ────────────────────────────────────
  const loadDrafts = useCallback(async () => {
    setDraftsLoading(true);
    try {
      const { data } = await supabase.from('author_drafts')
        .select('id, preferred_name, sort_name, status, action, published_author_id, batch_id, updated_at')
        .order('updated_at', { ascending: false }).limit(100);
      setDrafts(data || []);
    } catch {} finally { setDraftsLoading(false); }
  }, []);

  useEffect(() => { loadDrafts(); }, [loadDrafts]);

  // -- Lot 0 -- charger un brouillon a editer (handoff catalogo/fila -> editeur) --
  useEffect(() => {
    if (!editingId) return;
    let cancelled = false;
    (async () => {
      try {
        const { data, error } = await supabase.from('author_drafts').select('*').eq('id', Number(editingId)).single();
        if (cancelled) return;
        if (error) throw error;
        if (data) fillFromRecord(data);
      } catch (e) {
        if (!cancelled) setMsg({ text: t({ id: 'catalogacao.author.loadError' }, { message: localizeError(e, t) }), kind: 'error' });
      } finally {
        if (!cancelled) onConsumed?.();
      }
    })();
    return () => { cancelled = true; };
  }, [editingId]);

  // ── Reset / Fill ────────────────────────────────────────
  function resetForm() {
    setForm({ ...EMPTY_FORM });
    setMeta({ authorityType: 'person', acronym: '', activityPeriod: '', affiliation: '', variantNames: '', pseudonyms: '', activityPlace: '', contextLinks: '' });
    setAssistRaw('');
    setDraftState('new');
    setMsg({ text: '', kind: '' });
    setPhotoFile(null);
    setPhotoPreviewUrl('');
  }

  // ── Photo upload ────────────────────────────────────────
  function handlePhotoFileChange(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    setCropState({ src: URL.createObjectURL(file), attribution: null });
    e.target.value = '';
  }

  async function uploadPhoto() {
    if (!photoFile) return null;
    const draftId = form.id || 'new';
    const ext = photoFile.name.split('.').pop() || 'jpg';
    const storagePath = `authors/${draftId}_${Date.now()}.${ext}`;
    try {
      setPhotoUploading(true);
      const { error } = await supabase.storage.from('authors').upload(storagePath, photoFile, { upsert: true });
      if (error) throw error;
      set('photo_object_path', storagePath);
      setPhotoPreviewUrl('');
      setMsg({ text: t({ id: 'catalogacao.author.photoSaved' }), kind: 'ok' });
      return storagePath;
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.author.photoError' }, { message: localizeError(err, t) }), kind: 'error' });
      return null;
    } finally {
      setPhotoUploading(false);
    }
  }

  // ── Portrait : recherche Wikidata/Commons ──────────────
  async function searchPortraits() {
    const wid = f('wikidata_id').trim();
    const nm = f('preferred_name').trim();
    if (!wid && !nm) { setMsg({ text: t({ id: 'catalogacao.author.portraitNeedName' }), kind: 'error' }); return; }
    setPortraitLoading(true); setPortraitCandidates(null);
    try {
      const { data, error } = await supabase.functions.invoke('author_portrait_lookup', {
        body: { wikidata_id: wid || undefined, name: nm || undefined },
      });
      if (error) throw error;
      setPortraitCandidates(data?.candidates || []);
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.author.portraitError' }, { message: localizeError(err, t) }), kind: 'error' });
      setPortraitCandidates([]);
    } finally {
      setPortraitLoading(false);
    }
  }

  // Récupère l'image choisie et la stocke dans le bucket authors + attribution
  // (licence/crédit) dans structured_meta.portrait — stockée, non exposée.
  async function storePortrait(cand) {
    if (portraitStoring) return;
    setPortraitStoring(cand.filename);
    try {
      const resp = await fetch(cand.full_url);
      if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
      const blob = await resp.blob();
      // Ouvre le recadreur ; l'upload se fait à la confirmation du cadrage.
      setCropState({
        src: URL.createObjectURL(blob),
        attribution: {
          license: cand.license || '', credit: cand.credit || '',
          source_url: cand.source_url || '', wikidata_id: cand.wikidata_id || '',
        },
      });
      setPortraitCandidates(null);
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.author.portraitError' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setPortraitStoring('');
    }
  }

  // Confirmation du recadrage : upload du JPEG 3×4 + attribution (si portrait Wikidata)
  async function onCropConfirm(blob) {
    const cs = cropState;
    try {
      const draftId = form.id || 'new';
      const storagePath = `authors/${draftId}_${Date.now()}.jpg`;
      const { error } = await supabase.storage.from('authors').upload(storagePath, blob, { upsert: true, contentType: 'image/jpeg' });
      if (error) throw error;
      set('photo_object_path', storagePath);
      if (cs?.attribution) setM('portrait', cs.attribution);
      setPhotoPreviewUrl('');
      setMsg({ text: t({ id: 'catalogacao.author.portraitStored' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.author.portraitError' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      if (cs?.src) URL.revokeObjectURL(cs.src);
      setCropState(null);
    }
  }
  function onCropCancel() {
    if (cropState?.src) URL.revokeObjectURL(cropState.src);
    setCropState(null);
  }

  function fillFromRecord(r) {
    const sm = r.structured_meta || {};
    setForm({
      id: String(r.id || ''),
      published_author_id: String(r.published_author_id || ''),
      batch_id: String(r.batch_id || ''),
      action: r.published_author_id ? 'update' : (r.action || 'create'),
      status: r.status || 'draft',
      preferred_name: r.preferred_name || '',
      sort_name: r.sort_name || '',
      biography: r.biography || '',
      birth_year: r.birth_year ? String(r.birth_year) : '',
      death_year: r.death_year ? String(r.death_year) : '',
      country: r.country || '',
      source_kind: r.source_kind || '',
      source_label: r.source_label || '',
      source_url: r.source_url || '',
      viaf_id: r.viaf_id || '',
      isni: r.isni || '',
      wikidata_id: r.wikidata_id || '',
      photo_object_path: r.photo_object_path || '',
      notes: r.notes || '',
    });
    // Charger les traductions UNIQUEMENT pour un auteur publie (jamais l'id de
    // brouillon : il collisionne avec les id d'auteurs reels — bug corrige 05/06).
    const authorId = r.published_author_id || null;
    if (authorId) {
      supabase.from('author_translations').select('lang, biography, author_id, status, reviewed_at').eq('author_id', authorId)
        .then(({ data }) => { if (data) setBioTranslations(data); });
      setBioDirty(new Set());
    } else {
      setBioTranslations([]);
      setBioDirty(new Set());
    }
    setMeta({
      authorityType: sm.authorityType || 'person',
      acronym: sm.acronym || '',
      activityPeriod: sm.activityPeriod || '',
      affiliation: sm.affiliation || '',
      variantNames: sm.variantNames || '',
      pseudonyms: sm.pseudonyms || '',
      activityPlace: sm.activityPlace || '',
      contextLinks: sm.contextLinks || '',
      portrait: sm.portrait || null,
    });
    setDraftState(r.status === 'ready' ? 'ready' : r.status === 'published' ? 'published' : r.id ? 'saved' : 'new');
    setMsg({ text: '', kind: '' });
  }

  // ── Preferred name → sort name sync ─────────────────────
  function handlePreferredNameChange(val) {
    const prev = f('preferred_name');
    const currentSort = f('sort_name');
    set('preferred_name', val);
    // Forme de tri auto-remplie tant qu'elle n'a pas ete personnalisee (vide,
    // ou = derivation du nom precedent). Vaut aussi pour les autorites deja
    // publiees (l'ancien garde-fou !published_author_id les excluait a tort).
    if (!currentSort.trim() || currentSort === buildSortName(prev, meta.authorityType)) {
      set('sort_name', buildSortName(val, meta.authorityType));
    }
  }

  function handleAuthorityTypeChange(val) {
    const prevType = meta.authorityType;
    const currentSort = f('sort_name');
    const pref = f('preferred_name');
    setM('authorityType', val);
    // Le sigle ne concerne qu'une autorite collective : on le vide sinon.
    if (val !== 'collective') setM('acronym', '');
    // Pseudonymes / noms de guerre : notion individuelle -> vider hors personne.
    if (val !== 'person') setM('pseudonyms', '');
    // Naissance/deces : ni personne ni collectivite -> champs masques, on vide.
    if (val !== 'person' && val !== 'collective') { set('birth_year', ''); set('death_year', ''); }
    // Re-derive la forme de tri si elle n'a pas ete personnalisee.
    if (!currentSort.trim() || currentSort === buildSortName(pref, prevType)) {
      set('sort_name', buildSortName(pref, val));
    }
  }

  // ── Name assist ─────────────────────────────────────────
  function applyNameAssist() {
    if (!assistRaw.trim()) return;
    const raw = assistRaw.trim();
    // Try "Surname, Given, dates" format (e.g. "Bakunin, Mikhail Aleksandrovich, 1814-1876")
    const commaMatch = raw.match(/^([^,]+),\s*([^,]+?)(?:,\s*(\d{4})\s*-\s*(\d{4})?)?\s*$/);
    if (commaMatch) {
      const surname = commaMatch[1].trim();
      const given = commaMatch[2].trim();
      if (!f('preferred_name')) set('preferred_name', `${given} ${surname}`);
      if (!f('sort_name')) set('sort_name', `${surname}, ${given}`);
      if (commaMatch[3] && !f('birth_year')) set('birth_year', commaMatch[3]);
      if (commaMatch[4] && !f('death_year')) set('death_year', commaMatch[4]);
      setMsg({ text: t({ id: 'catalogacao.author.suggestionApplied' }, { name: `${given} ${surname}` }), kind: 'ok' });
      return;
    }
    // Simple name — just apply as preferred name
    if (!f('preferred_name')) {
      set('preferred_name', raw);
      set('sort_name', buildSortName(raw, meta.authorityType));
      setMsg({ text: t({ id: 'catalogacao.author.nameApplied' }, { name: raw }), kind: 'ok' });
    } else {
      setMsg({ text: t({ id: 'catalogacao.author.nameAlreadyFilled' }), kind: 'info' });
    }
  }

  // ── Save draft ──────────────────────────────────────────
  async function handleSave(e) {
    e?.preventDefault();
    if (!f('preferred_name').trim()) { setMsg({ text: t({ id: 'catalogacao.author.nameRequired' }), kind: 'error' }); return; }

    setSaving(true); setMsg({ text: '', kind: '' });
    try {
      // Upload photo if file selected
      if (photoFile) { await uploadPhoto(); }
      const isUpdate = !!f('id');
      // Build structured_meta: only include non-empty values
      const smPayload = {};
      for (const [k, v] of Object.entries(meta)) { if (v) smPayload[k] = v; }
      const payload = {
        ...(isUpdate ? { id: Number(f('id')) } : {}),
        published_author_id: f('published_author_id') ? Number(f('published_author_id')) : null,
        batch_id: f('batch_id') ? Number(f('batch_id')) : null,
        action: f('published_author_id') ? 'update' : 'create',
        status: 'draft',
        preferred_name: f('preferred_name').trim(),
        sort_name: f('sort_name').trim() || buildSortName(f('preferred_name'), meta.authorityType),
        biography: f('biography') || null,
        birth_year: f('birth_year') ? Number(f('birth_year')) : null,
        death_year: f('death_year') ? Number(f('death_year')) : null,
        country: f('country') || null,
        source_kind: f('source_kind') || null,
        source_label: f('source_label') || null,
        source_url: f('source_url') || null,
        viaf_id: f('viaf_id') || null,
        isni: f('isni') || null,
        wikidata_id: f('wikidata_id') || null,
        variant_forms: form.variant_forms || null,
        photo_object_path: f('photo_object_path') || null,
        notes: f('notes') || null,
        structured_meta: Object.keys(smPayload).length ? smPayload : {},
        updated_by: user?.id || null,
        ...(isUpdate ? {} : { created_by: user?.id || null }),
      };

      let result;
      if (isUpdate) {
        const { data, error } = await supabase.from('author_drafts').update(payload).eq('id', Number(f('id'))).select().single();
        if (error) throw error;
        result = data;
      } else {
        const { data, error } = await supabase.from('author_drafts').insert(payload).select().single();
        if (error) throw error;
        result = data;
      }

      fillFromRecord(result);
      setDraftState('saved');
      await loadDrafts();
      onChanged?.();
      setMsg({ text: isUpdate ? t({ id: 'catalogacao.author.draftUpdated' }) : t({ id: 'catalogacao.author.draftCreated' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally { setSaving(false); }
  }

  // ── Publish draft ───────────────────────────────────────
  async function handlePublish() {
    if (!f('id')) { setMsg({ text: t({ id: 'catalogacao.msg.saveBeforePublish' }), kind: 'error' }); return; }
    if (!confirm(t({ id: 'catalogacao.author.publishConfirm' }))) return;

    setPublishing(true); setMsg({ text: '', kind: '' });
    try {
      const { data: newAuthorId, error } = await supabase.rpc('publish_author_draft', { p_draft_id: Number(f('id')) });
      if (error) throw error;
      // Seed bio par défaut dans author_translations (Q1 : locale de l'UI, défaut pt-BR).
      // ON CONFLICT DO NOTHING : ne jamais écraser une traduction existante (revue).
      const bio = f('biography')?.trim();
      const seedLang = ALLOWED_BIO_LANGS.includes(locale) ? locale : 'pt-BR';
      if (newAuthorId && bio) {
        await supabase.from('author_translations').upsert(
          { author_id: Number(newAuthorId), lang: seedLang, biography: bio, status: 'draft', updated_by: user?.id || null },
          { onConflict: 'author_id,lang', ignoreDuplicates: true },
        );
      }
      setDraftState('published');
      await loadDrafts();
      onChanged?.();
      setMsg({ text: t({ id: 'catalogacao.author.publishSuccess' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.author.publishError' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setPublishing(false); }
  }

  // Recharge les traductions bio (après save ou bascule de revue).
  async function reloadBioTranslations() {
    const authorId = f('published_author_id');
    if (!authorId) return;
    const { data } = await supabase.from('author_translations')
      .select('lang, biography, author_id, status, reviewed_at').eq('author_id', Number(authorId));
    if (data) setBioTranslations(data);
    setBioDirty(new Set());
  }

  // Bascule le statut de revue d'une traduction (RPC staff).
  async function toggleBioReview(lang, toReviewed) {
    const authorId = f('published_author_id');
    if (!authorId) return;
    setBioReviewBusy(lang);
    try {
      const { error } = await supabase.rpc('set_author_translation_review', {
        p_author_id: Number(authorId), p_lang: lang, p_reviewed: toReviewed,
      });
      if (error) throw error;
      await reloadBioTranslations();
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setBioReviewBusy(null); }
  }

  // Note : la reprise d'un auteur publie (create_author_draft_from_author) est
  // pilotee par CatalogPanel.retakeItem -> onEdit('author', draftId) -> openForEdit.
  // Pas de duplication ici.

  // ── Rattachement aux oeuvres (liaison autorite<->livres) ────────────────
  async function findAuthorBookMatches() {
    const authorId = f('published_author_id');
    if (!authorId) return;
    setLinkLoading(true); setLinkSelected(new Set());
    try {
      const { data, error } = await supabase.rpc('suggest_author_book_matches', { p_author_id: Number(authorId) });
      if (error) throw error;
      setLinkMatches(data || []);
      // Pre-cocher les correspondances exactes (validation humaine = un clic global).
      setLinkSelected(new Set((data || []).filter(m => m.match_kind === 'exact').map(m => m.contributor_id)));
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setLinkLoading(false); }
  }

  async function confirmAuthorLinks() {
    const authorId = f('published_author_id');
    if (!authorId || linkSelected.size === 0) return;
    setLinkBusy(true);
    let ok = 0;
    try {
      for (const cid of linkSelected) {
        const { error } = await supabase.rpc('confirm_author_book_link', {
          p_author_id: Number(authorId), p_contributor_id: Number(cid),
        });
        if (!error) ok++;
      }
      setMsg({ text: t({ id: 'catalogacao.link.confirmed' }, { count: ok }), kind: 'ok' });
      await findAuthorBookMatches(); // rafraichir (les rattaches disparaissent de la liste)
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setLinkBusy(false); }
  }

  // ── Doublons d'autorite : detection + fusion ────────────────────────────
  async function findAuthorDuplicates() {
    const authorId = f('published_author_id');
    if (!authorId) return;
    setDupLoading(true); setDupMatches(null);
    try {
      const { data, error } = await supabase.rpc('suggest_author_duplicates', { p_author_id: Number(authorId) });
      if (error) throw error;
      setDupMatches(data || []);
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setDupLoading(false); }
  }

  // Fusionne le doublon `dupId` DANS l'autorite courante (= canonique).
  async function mergeDuplicateIntoCurrent(dupId, dupName) {
    const canonicalId = f('published_author_id');
    if (!canonicalId) return;
    if (!confirm(t({ id: 'catalogacao.dedup.confirm' }, { dup: dupName, canonical: f('preferred_name') }))) return;
    setDupBusy(dupId);
    try {
      const { error } = await supabase.rpc('merge_author', {
        p_canonical_id: Number(canonicalId), p_duplicate_id: Number(dupId),
      });
      if (error) throw error;
      setMsg({ text: t({ id: 'catalogacao.dedup.merged' }, { dup: dupName }), kind: 'ok' });
      await findAuthorDuplicates(); // rafraichir
      await loadDrafts();
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setDupBusy(null); }
  }

  // ── State pill ──────────────────────────────────────────
  const pills = {
    new: { label: t({ id: 'catalogacao.ui.newDraft' }), cls: 'info' },
    saved: { label: t({ id: 'catalogacao.state.saved' }), cls: 'ok' },
    dirty: { label: t({ id: 'catalogacao.msg.unsavedChanges' }), cls: 'warn' },
    ready: { label: t({ id: 'catalogacao.msg.readyToPublish' }), cls: 'ok' },
    published: { label: t({ id: 'catalogacao.msg.alreadyPublished' }), cls: 'ok' },
  };
  const pill = pills[draftState] || pills.new;

  // ── Authority lookup (Wikidata → VIAF/ISNI/variant_forms) ──
  async function runAuthorityLookup() {
    const name = f('preferred_name')?.trim();
    if (!name) { setMsg({ text: t({id:'catalogacao.authority.needName'}), kind: 'error' }); return; }
    setAuthLookupLoading(true);
    setAuthLookupResults(null);
    try {
      const { data, error } = await supabase.functions.invoke('authority_lookup', { body: { name, maxResults: 5 } });
      if (error && !data) throw error;
      if (!data?.ok) throw new Error(data?.error || t({ id: 'catalogacao.msg.lookupFailed' }));
      setAuthLookupResults(data.candidates || []);
      setMsg({ text: data.candidates?.length ? t({id:'catalogacao.authority.found'}, {count: data.candidates.length}) : t({id:'catalogacao.authority.notFound'}), kind: data.candidates?.length ? 'ok' : 'info' });
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally {
      setAuthLookupLoading(false);
    }
  }

  function applyAuthorityCandidate(candidate) {
    if (!candidate) return;
    const updates = {};
    if (candidate.viaf_id) updates.viaf_id = candidate.viaf_id;
    if (candidate.isni) updates.isni = candidate.isni;
    if (candidate.wikidata_id) updates.wikidata_id = candidate.wikidata_id;
    if (candidate.birth_year && !f('birth_year')) updates.birth_year = candidate.birth_year;
    if (candidate.death_year && !f('death_year')) updates.death_year = candidate.death_year;
    if (!f('source_kind')) updates.source_kind = 'wikidata';
    if (!f('source_label')) updates.source_label = 'Wikidata';
    if (!f('source_url')) updates.source_url = candidate.source_url;
    if (candidate.variant_forms && Object.keys(candidate.variant_forms).length) {
      updates.variant_forms = candidate.variant_forms;
    }
    setForm(prev => ({ ...prev, ...updates }));
    if (draftState === 'saved' || draftState === 'ready') setDraftState('dirty');
    setMsg({ text: t({id:'catalogacao.authority.linked'}, {name: candidate.preferred_name, id: candidate.wikidata_id}), kind: 'ok' });
    setAuthLookupResults(null);
  }

  // ── Render helpers ──────────────────────────────────────
  const fs = { width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' };
  const ls = { display: 'block', fontSize: '.78rem', fontWeight: 600, marginBottom: 2, color: 'var(--brand-muted, #bbb)' };
  const isComplete = mode === 'complete';

  function inp(key, label, opts = {}) {
    if (opts.completeOnly && !isComplete) return null;
    return (
      <div className="cat-field" style={opts.span ? { gridColumn: `span ${opts.span}` } : undefined}>
        <label style={ls}>{label}</label>
        {opts.rows ? (
          <textarea value={f(key)} onChange={e => set(key, e.target.value)} rows={opts.rows} placeholder={opts.placeholder || ''} style={{ ...fs, resize: 'vertical', minHeight: opts.rows * 22 }} />
        ) : (
          <input type={opts.type || 'text'} value={f(key)} onChange={e => set(key, e.target.value)} placeholder={opts.placeholder || ''} style={fs} readOnly={opts.readOnly} />
        )}
        {opts.hint && <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #888)', marginTop: 2 }}>{opts.hint}</div>}
      </div>
    );
  }

  return (
    <div>
      {/* ── Toolbar ──────────────────────────────────── */}
      <div className="cat-panel-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 8, marginBottom: 12 }}>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <h3 style={{ margin: 0 }}>{t({ id: 'catalogacao.author.heading' })}</h3>
          <span className={`cat-pill ${pill.cls}`} style={{ fontSize: '.68rem' }}>{pill.label}</span>
        </div>
        <div style={{ display: 'flex', gap: 6 }}>
          <button type="button" className="ab-button ab-button--sm" onClick={resetForm}>{t({id:'catalogacao.ui.newDraft'})}</button>
          <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={resetForm}>{t({id:'catalogacao.ui.clearForm'})}</button>
          <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={loadDrafts} disabled={draftsLoading}>
            {draftsLoading ? t({ id: 'catalogacao.ui.refreshing' }) : t({ id: 'catalogacao.ui.refreshList' })}
          </button>
        </div>
      </div>

      {/* ── Message ──────────────────────────────────── */}
      {msg.text && (
        <div style={{
          padding: '8px 12px', borderRadius: 6, fontSize: '.82rem', marginBottom: 12,
          background: msg.kind === 'ok' ? 'rgba(21,128,61,.12)' : msg.kind === 'info' ? 'rgba(29,78,216,.1)' : 'rgba(220,38,38,.12)',
          color: msg.kind === 'ok' ? '#4ade80' : msg.kind === 'info' ? '#60a5fa' : '#f87171',
        }}>{msg.text}</div>
      )}

      {/* ── Existing drafts list ──────────────────────── */}
      {drafts.length > 0 && (
        <div style={{ marginBottom: 16, maxHeight: 200, overflowY: 'auto', border: '1px solid rgba(255,255,255,.06)', borderRadius: 8 }}>
          {drafts.map((d, i) => (
            <div key={d.id} style={{
              display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8,
              padding: '6px 10px', cursor: 'pointer',
              background: String(d.id) === f('id') ? 'rgba(29,78,216,.12)' : i % 2 === 0 ? 'rgba(0,0,0,.1)' : 'transparent',
              borderBottom: '1px solid rgba(255,255,255,.04)',
            }} onClick={async () => {
              const { data } = await supabase.from('author_drafts').select('*').eq('id', d.id).single();
              if (data) fillFromRecord(data);
            }}>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: '.82rem', fontWeight: 600 }}>{d.preferred_name || t({ id: 'catalogacao.queue.noName' })}</div>
                <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #888)' }}>
                  {d.sort_name || '—'} · {t({ id: STATUS_KEYS[d.status] || d.status }).toLowerCase()} · {t({ id: ACTION_KEYS[d.action] || d.action }).toLowerCase()}
                  {d.published_author_id ? ` · pub #${d.published_author_id}` : ''}
                </div>
              </div>
              <span className={`cat-pill ${d.status === 'draft' ? 'info' : 'ok'}`} style={{ fontSize: '.62rem', flexShrink: 0 }}>
                {t({ id: STATUS_KEYS[d.status] || d.status })}
              </span>
            </div>
          ))}
        </div>
      )}

      {/* ── Form ─────────────────────────────────────── */}
      <form onSubmit={handleSave}>
        {cropState && (
          <PortraitCropper src={cropState.src} onConfirm={onCropConfirm} onCancel={onCropCancel} />
        )}

        {/* ── Name assist (parse un nom de personne BN : personne uniquement) ── */}
        {meta.authorityType === 'person' && (
        <div style={{ padding: 12, borderRadius: 8, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.06)', marginBottom: 14 }}>
          <div style={{ fontSize: '.82rem', fontWeight: 700, marginBottom: 4 }}>{t({ id: 'catalogacao.author.nameAssist' })}</div>
          <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #999)', marginBottom: 8 }}>
            {t({ id: 'catalogacao.author.nameAssistDesc' })}
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <input type="text" value={assistRaw} onChange={e => setAssistRaw(e.target.value)}
              placeholder="Bakunin, Mikhail Aleksandrovich, 1814-1876" style={{ ...fs, flex: 1 }} />
            <button type="button" className="ab-button ab-button--secondary ab-button--sm"
              onClick={applyNameAssist}>{t({ id: 'catalogacao.author.nameAssistFill' })}</button>
          </div>
        </div>
        )}

        <div className="cat-book-grid">
          {/* Photo de l'autorité — en tête du formulaire (cohérence avec le document) */}
          <div className="cat-field" style={{ gridColumn: 'span 2' }}>
            <label style={ls}>{t({ id: 'catalogacao.author.photoLabel' })}</label>
            <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start' }}>
              <div style={{ width: 80, flexShrink: 0 }}>
                {photoDisplayUrl ? (
                  <img src={photoDisplayUrl} alt="Foto" style={{ width: '100%', borderRadius: 8, border: '1px solid rgba(255,255,255,.1)', objectFit: 'cover', maxHeight: 100 }} />
                ) : (
                  <div style={{ width: '100%', height: 80, borderRadius: 8, border: '1px dashed rgba(255,255,255,.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '.7rem', color: 'var(--brand-muted, #888)' }}>
                    {t({ id: 'catalogacao.author.noPhoto' })}
                  </div>
                )}
              </div>
              <div style={{ flex: 1 }}>
                <label className="ab-button ab-button--secondary ab-button--sm" style={{ display: 'inline-block', textAlign: 'center', cursor: 'pointer', marginBottom: 4 }}>
                  {t({ id: 'catalogacao.author.chooseImage' })}
                  <input type="file" accept="image/*" onChange={handlePhotoFileChange} style={{ display: 'none' }} />
                </label>
                <button type="button" className="ab-button ab-button--secondary ab-button--sm" style={{ marginLeft: 6 }}
                  onClick={searchPortraits} disabled={portraitLoading}>
                  {portraitLoading ? t({ id: 'catalogacao.author.portraitSearching' }) : t({ id: 'catalogacao.author.portraitSearch' })}
                </button>
                {photoFile && (
                  <button type="button" className="ab-button ab-button--sm" style={{ marginLeft: 6 }}
                    onClick={uploadPhoto} disabled={photoUploading}>
                    {photoUploading ? t({ id: 'catalogacao.author.uploadingPhoto' }) : t({ id: 'catalogacao.author.uploadPhoto' })}
                  </button>
                )}
                {f('photo_object_path') && (
                  <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #888)', marginTop: 4 }}>{f('photo_object_path')}</div>
                )}
                {portraitCandidates && portraitCandidates.length > 0 && (
                  <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginTop: 8 }}>
                    {portraitCandidates.map(c => (
                      <button key={c.filename} type="button" onClick={() => storePortrait(c)} disabled={!!portraitStoring}
                        title={`${c.label || ''}${c.license ? ' — ' + c.license : ''}`}
                        style={{ padding: 0, border: '1px solid rgba(255,255,255,.15)', borderRadius: 6, overflow: 'hidden', cursor: 'pointer', background: 'none', width: 64 }}>
                        <img src={c.thumb_url} alt={c.label || ''} style={{ width: 64, height: 64, objectFit: 'cover', display: 'block', opacity: portraitStoring === c.filename ? 0.4 : 1 }} />
                        <div style={{ fontSize: '.55rem', padding: '2px 3px', color: 'var(--brand-muted, #aaa)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{c.license || '?'}</div>
                      </button>
                    ))}
                  </div>
                )}
                {portraitCandidates && portraitCandidates.length === 0 && (
                  <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #888)', marginTop: 6 }}>{t({ id: 'catalogacao.author.portraitNone' })}</div>
                )}
              </div>
            </div>
          </div>

          {/* ── Name fields ──────────────────────────── */}
          <div className="cat-field" style={{ gridColumn: 'span 2' }}>
            <label style={ls}>{t({ id: meta.authorityType === 'person' ? 'catalogacao.author.preferredNameLabel' : meta.authorityType === 'collective' ? 'catalogacao.author.preferredNameLabelOrg' : 'catalogacao.author.preferredNameLabelGeneric' })}</label>
            <input type="text" value={f('preferred_name')} onChange={e => handlePreferredNameChange(e.target.value)}
              placeholder={meta.authorityType === 'person' ? 'Osvaldo BAYER' : meta.authorityType === 'collective' ? 'Confederación Nacional del Trabajo' : ''} required style={fs} />
          </div>

          <div className="cat-field">
            <label style={ls}>{t({ id: 'catalogacao.author.sortNameLabel' })}</label>
            <input type="text" value={f('sort_name')} onChange={e => set('sort_name', e.target.value)}
              placeholder={meta.authorityType === 'person' ? 'BAYER, Osvaldo' : meta.authorityType === 'collective' ? 'Confederación Nacional del Trabajo' : ''} style={{ ...fs, opacity: f('published_author_id') ? 1 : 0.7 }}
              readOnly={!f('published_author_id')} />
            <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #888)', marginTop: 2 }}>{t({ id: 'catalogacao.author.sortNameHint' })}</div>
          </div>

          {/* ── Authority type + enrichment ──────────── */}
          <div className="cat-field">
            <label style={ls}>{t({ id: 'catalogacao.author.authorityTypeLabel' })}</label>
            <select value={meta.authorityType} onChange={e => handleAuthorityTypeChange(e.target.value)} style={fs}>
              {AUTHORITY_TYPE_VALUES.map(at => <option key={at} value={at}>{t({ id: AUTHORITY_TYPE_KEYS[at] })}</option>)}
            </select>
          </div>

          {/* Sigle : uniquement pour une autorite COLLECTIVE (sigle de l'org, a la
              place du nom d'une personne). Pour les autres types, redondant avec
              Affiliation -> masque. La cellule vide cale la grille en regard du type. */}
          {isComplete && meta.authorityType === 'collective' && <div className="cat-field" aria-hidden="true" />}

          {isComplete && meta.authorityType === 'collective' && (
            <div className="cat-field">
              <label style={ls}>{t({ id: 'catalogacao.author.acronym' })}</label>
              <input type="text" value={meta.acronym} onChange={e => setM('acronym', e.target.value)}
                placeholder="CGT / FAG / CSL / CIRA" style={fs} />
              <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #888)', marginTop: 2 }}>{t({ id: 'catalogacao.author.acronymHint' })}</div>
            </div>
          )}

          <div className="cat-field">
            <label style={ls}>{t({ id: 'catalogacao.author.activityPeriod' })}</label>
            <input type="text" value={meta.activityPeriod} onChange={e => setM('activityPeriod', e.target.value)}
              placeholder={t({ id: 'catalogacao.author.activityPeriod.ph' })} style={fs} />
          </div>

          <div className="cat-field">
            <label style={ls}>{t({ id: 'catalogacao.author.affiliation' })}</label>
            <input type="text" value={meta.affiliation} onChange={e => setM('affiliation', e.target.value)}
              placeholder="CNT-FAI / FORA / Federação Anarquista Gaúcha…" style={fs} />
          </div>

          {isComplete && (
            <div className="cat-field" style={{ gridColumn: 'span 3' }}>
              <label style={ls}>{t({ id: 'catalogacao.author.variantNames' })}</label>
              <textarea value={meta.variantNames} onChange={e => setM('variantNames', e.target.value)}
                placeholder={t({ id: 'catalogacao.author.variantNames.ph' })} style={{ ...fs, resize: 'vertical', minHeight: 44 }} />
            </div>
          )}

          {isComplete && meta.authorityType === 'person' && (
            <div className="cat-field" style={{ gridColumn: 'span 2' }}>
              <label style={ls}>{t({ id: 'catalogacao.author.pseudonyms' })}</label>
              <input type="text" value={meta.pseudonyms} onChange={e => setM('pseudonyms', e.target.value)}
                placeholder={t({ id: 'catalogacao.author.pseudonyms.ph' })} style={fs} />
            </div>
          )}

          {isComplete && (
            <>
              <div className="cat-field">
                <label style={ls}>{t({ id: 'catalogacao.author.activityPlace' })}</label>
                <input type="text" value={meta.activityPlace} onChange={e => setM('activityPlace', e.target.value)}
                  placeholder="Belém, Buenos Aires…" style={fs} />
              </div>
              <div className="cat-field" style={{ gridColumn: 'span 3' }}>
                <label style={ls}>{t({ id: 'catalogacao.author.contextLinks' })}</label>
                <input type="text" value={meta.contextLinks} onChange={e => setM('contextLinks', e.target.value)}
                  placeholder={t({ id: 'catalogacao.author.contextLinks.ph' })} style={fs} />
              </div>
            </>
          )}

          {/* ── Donnees temporelles ──────────────────────
              Personne : naissance/deces. Collectivite : fondation/dissolution
              (memes colonnes, libelle adapte). Autres types : masque. */}
          {(meta.authorityType === 'person' || meta.authorityType === 'collective') &&
            inp('birth_year', t({ id: meta.authorityType === 'collective' ? 'catalogacao.author.foundingYear' : 'catalogacao.author.birthYear' }), { type: 'number' })}
          {(meta.authorityType === 'person' || meta.authorityType === 'collective') &&
            inp('death_year', t({ id: meta.authorityType === 'collective' ? 'catalogacao.author.dissolutionYear' : 'catalogacao.author.deathYear' }), { type: 'number' })}
          {inp('country', t({ id: 'catalogacao.author.country' }), { placeholder: 'Brasil' })}

          {/* ── Source + identifiers ──────────────────── */}
          <div className="cat-field">
            <label style={ls}>{t({ id: 'catalogacao.author.sourceKindLabel' })}</label>
            <select value={f('source_kind')} onChange={e => set('source_kind', e.target.value)} style={fs}>
              {SOURCE_KIND_VALUES.map(s => <option key={s} value={s}>{t({ id: SOURCE_KIND_KEYS[s] })}</option>)}
            </select>
          </div>
          {inp('source_label', t({ id: 'catalogacao.author.sourceLabel' }), { placeholder: 'VIAF, BnF, site da editora…' })}
          {inp('source_url', t({ id: 'catalogacao.author.sourceUrl' }), { placeholder: 'https://...' })}

          {isComplete && (
            <>
              <div className="cat-field" style={{ gridColumn: 'span 3' }}>
                <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 6 }}>
                  <button type="button" className="ab-button ab-button--sm"
                    onClick={runAuthorityLookup} disabled={authLookupLoading || !f('preferred_name')?.trim()}>
                    {authLookupLoading ? t({id:'catalogacao.authority.searching'}) : t({id:'catalogacao.authority.search'})}
                  </button>
                  {(f('viaf_id') || f('wikidata_id')) && (
                    <span style={{ fontSize: '.72rem', color: '#4ade80' }}>
                      ✓ {[f('wikidata_id') && `WD: ${f('wikidata_id')}`, f('viaf_id') && `VIAF: ${f('viaf_id')}`, f('isni') && `ISNI: ${f('isni')}`].filter(Boolean).join(' · ')}
                    </span>
                  )}
                </div>
                {authLookupResults && authLookupResults.length > 0 && (
                  <div style={{ border: '1px solid rgba(255,255,255,.1)', borderRadius: 8, overflow: 'hidden', maxHeight: 240, overflowY: 'auto', marginBottom: 6 }}>
                    {authLookupResults.map((c, i) => (
                      <div key={c.wikidata_id || i} style={{
                        padding: '8px 10px', cursor: 'pointer',
                        background: i % 2 === 0 ? 'rgba(0,0,0,.15)' : 'transparent',
                        borderBottom: '1px solid rgba(255,255,255,.06)',
                      }} onClick={() => applyAuthorityCandidate(c)}>
                        <div style={{ fontSize: '.82rem', fontWeight: 600 }}>
                          {c.preferred_name}
                          {c.birth_year && <span style={{ fontWeight: 400, color: 'var(--brand-muted, #aaa)' }}> ({c.birth_year}{c.death_year ? `–${c.death_year}` : '–'})</span>}
                        </div>
                        <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #aaa)' }}>{c.description}</div>
                        <div style={{ fontSize: '.68rem', color: 'rgba(255,255,255,.45)', marginTop: 2 }}>
                          {[c.wikidata_id, c.viaf_id && `VIAF: ${c.viaf_id}`, c.isni && `ISNI: ${c.isni}`].filter(Boolean).join(' · ')}
                          {c.variant_forms && ` · ${t({id:'catalogacao.authority.langCount'}, {count: Object.keys(c.variant_forms).length})}`}
                        </div>
                      </div>
                    ))}
                    <div style={{ fontSize: '.68rem', color: 'var(--brand-muted, #666)', padding: '6px 10px' }}>
                      {t({id:'catalogacao.authority.clickToLink'})}
                    </div>
                  </div>
                )}
                {authLookupResults && authLookupResults.length === 0 && (
                  <div style={{ fontSize: '.78rem', color: 'var(--brand-muted, #aaa)', marginBottom: 6 }}>{t({id:'catalogacao.authority.notFound'})}</div>
                )}
              </div>
              {inp('viaf_id', 'VIAF', { placeholder: '12345678' })}
              {inp('isni', 'ISNI', { placeholder: '0000 0001 2345 6789' })}
              {inp('wikidata_id', 'Wikidata', { placeholder: 'Q12345' })}
            </>
          )}

          {/* ── Biography + Notes ─────────────────────── */}
          {inp('biography', t({id:'catalogacao.author.bio'}), { span: 3, rows: 3, placeholder: t({id:'catalogacao.ph.bioPlaceholder'}), hint: t({id:'catalogacao.ph.bioHint'}) })}

          {/* ── Biography translations widget (auteur publie uniquement) ─── */}
          {/* Cle sur published_author_id : jamais l'id de brouillon (collision
              avec les id d'auteurs reels). Editable seulement apres publication. */}
          {!f('published_author_id') && (
            <div className="cat-field" style={{ gridColumn: 'span 3' }}>
              <div style={{ fontSize: '.78rem', color: 'var(--brand-muted, #aaa)', fontStyle: 'italic' }}>
                {t({id:'catalogacao.bio.translationsAfterPublish'})}
              </div>
            </div>
          )}
          {f('published_author_id') && (
            <div className="cat-field" style={{ gridColumn: 'span 3' }}>
              <details>
                <summary style={{ cursor: 'pointer', fontWeight: 600, fontSize: '.88rem', marginBottom: 6 }}>
                  {t({id:'catalogacao.bio.translations'})} {bioTranslations.length > 0 && `(${bioTranslations.map(bt => bt.lang).join(', ')})`}
                </summary>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, marginTop: 8 }}>
                  {ALLOWED_BIO_LANGS.map(lang => {
                    const existing = bioTranslations.find(bt => bt.lang === lang);
                    const isDirty = bioDirty.has(lang);
                    const filled = !!existing?.biography?.trim();
                    const reviewed = existing?.status === 'reviewed' && !isDirty;
                    return (
                      <div key={lang} style={{ padding: '8px 10px', borderRadius: 8, background: 'rgba(0,0,0,.15)', border: '1px solid rgba(255,255,255,.06)' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4, gap: 6, flexWrap: 'wrap' }}>
                          <span style={{ fontWeight: 700, fontSize: '.82rem' }}>{lang}</span>
                          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                            {isDirty ? (
                              <span style={{ fontSize: '.66rem', color: '#fbbf24' }}>{t({id:'catalogacao.bio.statusModified'})}</span>
                            ) : reviewed ? (
                              <span style={{ fontSize: '.66rem', color: '#4ade80' }}>✓ {t({id:'catalogacao.bio.statusReviewed'})}</span>
                            ) : filled ? (
                              <span style={{ fontSize: '.66rem', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.bio.statusDraft'})}</span>
                            ) : null}
                            {filled && !isDirty && (
                              <button type="button" disabled={bioReviewBusy === lang}
                                onClick={() => toggleBioReview(lang, !reviewed)}
                                style={{ background: 'none', border: '1px solid rgba(255,255,255,.15)', borderRadius: 5, color: 'var(--brand-muted, #aaa)', cursor: 'pointer', fontSize: '.62rem', padding: '2px 6px' }}
                                title={reviewed ? t({id:'catalogacao.bio.markDraft'}) : t({id:'catalogacao.bio.markReviewed'})}>
                                {bioReviewBusy === lang ? '…' : (reviewed ? '↺' : '✓')}
                              </button>
                            )}
                          </span>
                        </div>
                        <textarea
                          rows={3}
                          style={{ width: '100%', fontSize: '.82rem', padding: '6px 8px', borderRadius: 6, border: '1px solid rgba(255,255,255,.1)', background: 'rgba(0,0,0,.2)', color: '#f4f4f4', resize: 'vertical' }}
                          value={existing?.biography || ''}
                          placeholder={t({id:'catalogacao.bio.placeholder'}, {lang})}
                          onChange={e => {
                            const val = e.target.value;
                            setBioDirty(prev => new Set(prev).add(lang));
                            setBioTranslations(prev => {
                              const copy = prev.filter(bt => bt.lang !== lang);
                              copy.push({ ...(existing || {}), lang, biography: val, author_id: Number(f('published_author_id')) });
                              return copy;
                            });
                          }}
                        />
                      </div>
                    );
                  })}
                </div>
                <button type="button" className="ab-button ab-button--secondary ab-button--sm" style={{ marginTop: 8 }} disabled={bioDirty.size === 0} onClick={async () => {
                  try {
                    for (const lang of bioDirty) {
                      const bt = bioTranslations.find(x => x.lang === lang);
                      const bio = bt?.biography?.trim();
                      if (!bio) continue;
                      // Une édition (re)pose status=draft : une bio modifiée doit être re-revue (§3.1).
                      await supabase.from('author_translations').upsert({
                        author_id: Number(f('published_author_id')), lang, biography: bio,
                        status: 'draft', reviewed_by: null, reviewed_at: null,
                        updated_by: user?.id || null, updated_at: new Date().toISOString(),
                      }, { onConflict: 'author_id,lang' });
                    }
                    await reloadBioTranslations();
                    setMsg({ text: t({id:'common.dataSaved'}), kind: 'ok' });
                  } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:localizeError(err, t)}), kind: 'error' }); }
                }}>{t({id:'catalogacao.bio.save'})}</button>
              </details>
            </div>
          )}

          {/* ── Rattacher aux oeuvres (liaison autorite<->livres) ─────── */}
          {f('published_author_id') && (
            <div className="cat-field" style={{ gridColumn: 'span 3' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap', marginBottom: 6 }}>
                <span style={{ fontWeight: 600, fontSize: '.88rem' }}>{t({ id: 'catalogacao.link.title' })}</span>
                <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                  onClick={findAuthorBookMatches} disabled={linkLoading}>
                  {linkLoading ? t({ id: 'catalogacao.link.finding' }) : t({ id: 'catalogacao.link.find' })}
                </button>
              </div>
              {linkMatches !== null && linkMatches.length === 0 && (
                <div style={{ fontSize: '.8rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.link.none' })}</div>
              )}
              {linkMatches !== null && linkMatches.length > 0 && (
                <>
                  <div style={{ border: '1px solid rgba(255,255,255,.08)', borderRadius: 8, overflow: 'hidden', maxHeight: 280, overflowY: 'auto' }}>
                    {linkMatches.map(m => {
                      const sel = linkSelected.has(m.contributor_id);
                      return (
                        <label key={m.contributor_id} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 10px', cursor: 'pointer', borderBottom: '1px solid rgba(255,255,255,.04)', background: sel ? 'rgba(29,78,216,.1)' : 'transparent' }}>
                          <input type="checkbox" checked={sel} onChange={() => setLinkSelected(prev => { const n = new Set(prev); n.has(m.contributor_id) ? n.delete(m.contributor_id) : n.add(m.contributor_id); return n; })} />
                          <span style={{ flex: 1, minWidth: 0, fontSize: '.82rem' }}>{m.book_title}</span>
                          <span style={{ fontSize: '.72rem', color: 'var(--brand-muted, #aaa)' }}>{m.contributor_name}</span>
                          <span className={`cat-pill ${m.match_kind === 'exact' ? 'ok' : 'warn'}`} style={{ fontSize: '.6rem' }}>
                            {t({ id: m.match_kind === 'exact' ? 'catalogacao.link.exact' : 'catalogacao.link.approx' })} {Math.round(m.score * 100)}%
                          </span>
                        </label>
                      );
                    })}
                  </div>
                  <button type="button" className="ab-button ab-button--sm" style={{ marginTop: 8 }}
                    onClick={confirmAuthorLinks} disabled={linkBusy || linkSelected.size === 0}>
                    {linkBusy ? '…' : t({ id: 'catalogacao.link.confirm' }, { count: linkSelected.size })}
                  </button>
                </>
              )}
            </div>
          )}

          {/* ── Doublons possibles (fusion d'autorites) ─────────────── */}
          {f('published_author_id') && (
            <div className="cat-field" style={{ gridColumn: 'span 3' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap', marginBottom: 6 }}>
                <span style={{ fontWeight: 600, fontSize: '.88rem' }}>{t({ id: 'catalogacao.dedup.title' })}</span>
                <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                  onClick={findAuthorDuplicates} disabled={dupLoading}>
                  {dupLoading ? t({ id: 'catalogacao.dedup.finding' }) : t({ id: 'catalogacao.dedup.find' })}
                </button>
              </div>
              {dupMatches !== null && dupMatches.length === 0 && (
                <div style={{ fontSize: '.8rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.dedup.none' })}</div>
              )}
              {dupMatches !== null && dupMatches.length > 0 && (
                <div style={{ border: '1px solid rgba(255,255,255,.08)', borderRadius: 8, overflow: 'hidden' }}>
                  {dupMatches.map(d => (
                    <div key={d.author_id} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 10px', borderBottom: '1px solid rgba(255,255,255,.04)' }}>
                      <span style={{ flex: 1, minWidth: 0, fontSize: '.82rem' }}>{d.preferred_name}</span>
                      <span style={{ fontSize: '.72rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.dedup.books' }, { count: d.linked_books })}</span>
                      <span className={`cat-pill ${d.match_kind === 'exact' ? 'ok' : 'warn'}`} style={{ fontSize: '.6rem' }}>
                        {t({ id: d.match_kind === 'exact' ? 'catalogacao.link.exact' : 'catalogacao.link.approx' })} {Math.round(d.score * 100)}%
                      </span>
                      <button type="button" className="ab-button ab-button--danger ab-button--sm"
                        onClick={() => mergeDuplicateIntoCurrent(d.author_id, d.preferred_name)} disabled={dupBusy != null}>
                        {dupBusy === d.author_id ? '…' : t({ id: 'catalogacao.dedup.merge' })}
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {inp('notes', t({id:'catalogacao.author.notes'}), { span: 3, rows: 3, placeholder: t({id:'catalogacao.ph.notesPlaceholder'}), hint: t({id:'catalogacao.ph.notesHint'}), completeOnly: true })}

          {/* ── Batch (lot de catalogage) ─────────────── */}
          <div className="cat-field" style={isComplete ? undefined : { display: 'none' }}>
            <label style={ls}>{t({ id: 'catalogacao.author.batchLabel' })}</label>
            <select value={f('batch_id')} onChange={e => set('batch_id', e.target.value)} style={fs}>
              <option value="">{t({ id: 'catalogacao.author.noBatch' })}</option>
              {batches.filter(b => b.status === 'open').map(b => <option key={b.id} value={String(b.id)}>{b.name}</option>)}
            </select>
          </div>
        </div>

        {/* ── Architecture documentale ─────────────── */}
        {isComplete && (
          <div style={{ marginTop: 14, padding: 12, borderRadius: 8, background: 'rgba(0,0,0,.1)', border: '1px dashed rgba(255,255,255,.08)' }}>
            <h4 style={{ margin: '0 0 6px', fontSize: '.82rem' }}>{t({ id: 'catalogacao.author.archTitle' })}</h4>
            <div style={{ fontSize: '.75rem', color: 'var(--brand-muted, #888)', lineHeight: 1.6 }}>
              <div style={{ marginBottom: 3 }}>
                <strong>{t({ id: 'catalogacao.author.archRetained' })}</strong> {f('preferred_name') || '—'} → {f('sort_name') || '—'}
              </div>
              <div style={{ marginBottom: 3 }}>
                <strong>{t({ id: 'catalogacao.author.archType' })}</strong> {AUTHORITY_TYPE_KEYS[meta.authorityType] ? t({ id: AUTHORITY_TYPE_KEYS[meta.authorityType] }) : meta.authorityType}
                {meta.acronym && ` · Sigla: ${meta.acronym}`}
                {meta.activityPeriod && ` · Período: ${meta.activityPeriod}`}
              </div>
              <div style={{ marginBottom: 3 }}>
                <strong>{t({ id: 'catalogacao.author.archProvenance' })}</strong> {[f('source_kind'), f('source_label'), f('viaf_id') && `VIAF: ${f('viaf_id')}`, f('wikidata_id') && `WD: ${f('wikidata_id')}`].filter(Boolean).join(' · ') || '—'}
              </div>
              <div style={{ marginBottom: 3 }}>
                <strong>{t({ id: 'catalogacao.author.archPublicOutput' })}</strong> {[f('biography') ? t({ id: 'catalogacao.author.archBioYes' }) : t({ id: 'catalogacao.author.archBioNo' }), f('birth_year') && `${f('birth_year')}–${f('death_year') || '…'}`, f('country')].filter(Boolean).join(' · ')}
              </div>
              <div>
                <strong>{t({ id: 'catalogacao.author.archDraft' })}</strong> {draftState === 'new' ? t({ id: 'catalogacao.author.archNew' }) : draftState === 'saved' ? t({ id: 'catalogacao.author.archSaved' }, { id: f('id') }) : draftState === 'dirty' ? t({ id: 'catalogacao.msg.unsavedChanges' }) : draftState === 'published' ? t({ id: 'catalogacao.msg.alreadyPublished' }) : draftState}
                {f('batch_id') && ` · ${t({ id: 'catalogacao.author.archBatch' }, { id: f('batch_id') })}`}
              </div>
            </div>
          </div>
        )}

        {/* ── Actions ─────────────────────────────────── */}
        <div style={{ display: 'flex', gap: 8, marginTop: 16, flexWrap: 'wrap' }}>
          <button type="submit" className="ab-button" disabled={saving}>
            {saving ? t({ id: 'catalogacao.saving' }) : t({ id: 'catalogacao.ui.saveDraft' })}
          </button>
          <button type="button" className="ab-button" style={{ background: 'rgba(21,128,61,.7)' }}
            disabled={publishing || !f('id')} onClick={handlePublish}>
            {publishing ? t({ id: 'catalogacao.author.publishing' }) : t({ id: 'catalogacao.author.publishDraft' })}
          </button>
          <button type="button" className="ab-button ab-button--ghost" onClick={resetForm}>{t({id:'catalogacao.ui.clear'})}</button>
        </div>
      </form>
    </div>
  );
}
