import { useIntl } from 'react-intl';
import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { useStaffLibraries, bibliothequesProposables, lotsProposables, lotDeLaBibliotheque, libelleLot } from '@/lib/useStaffLibraries';
import { parseShelfLocation, formatShelfLocation, emptyShelfLocation } from '@/lib/shelfLocation';

// Localisation : src/lib/shelfLocation.js (la cote importée brute est gardée, H19).

// ── Label helpers (trigramme from BookDraftForm) ──────────
function stripDia(v) { return (v||'').normalize('NFD').replace(/[̀-ͯ]/g, ''); }
function extractSurname(name) {
  const c = (name||'').replace(/\s+/g,' ').trim(); if (!c) return '';
  if (c.includes(',')) return c.split(',')[0].trim();
  const particles = new Set(['da','de','del','della','di','do','dos','das','du','des','e','la','le','los','las','van','von','y']);
  const tokens = c.split(/\s+/);
  for (let i = tokens.length - 1; i >= 0; i--) { if (!particles.has(stripDia(tokens[i]).toLowerCase())) return tokens[i]; }
  return tokens[tokens.length-1] || '';
}
function getTrigram(name) {
  const raw = (name||'').trim(); if (!raw) return '---';
  const base = raw.includes(',') ? raw.split(',')[0] : (raw.split(/\s+/).slice(-1)[0]||raw);
  const clean = stripDia(base).replace(/[^a-zA-Z0-9]/g,'').toUpperCase();
  return clean ? clean.slice(0,3).padEnd(3,'X') : '---';
}

export default function ExemplarDraftForm({ mode, batches, prefillBibRef, editingId = null, onConsumed, onChanged }) {
  const { formatMessage: t } = useIntl();
  const { user } = useAuth();
  const isComplete = mode === 'complete';

  // ── State ───────────────────────────────────────────────
  const [drafts, setDrafts] = useState([]);
  const [draftsLoading, setDraftsLoading] = useState(false);
  const [form, setForm] = useState({
    id: '', published_exemplar_id: '', batch_id: '', action: 'create', status: 'draft', label_status: 'pending',
    target_bib_ref: '', target_library_id: '', target_holding_id: '',
    book_draft_id: '', import_staging_row_id: '', source_item_code: '',   // H19 : exemplaire importé (lecture seule)
    tombo: '', notes: '',
    circulation_policy: '', visibility: 'public',
    acquisition_mode: '', acquisition_date: '', provenance_note: '', source_library: '',
  });
  const [loc, setLoc] = useState(emptyShelfLocation);
  // H19 : champ « cote / localisation d'origine » (texte non structuré), montré
  // quand le brouillon en porte un ou vient d'un import.
  const [showRawLoc, setShowRawLoc] = useState(false);
  // #UX-CAT (10/06) — aide à la saisie : biblio identifiée intuitivement (slug /
  // nom / nom+ville) → affiche le dernier tombo de sa série au-dessus du Tombo.
  const [libOptions, setLibOptions] = useState([]);
  // B29 (CAT-E18) : un exemplaire se range dans une bibliothèque où l'on est
  // staff (l'administration : toutes) — la base refuserait les autres.
  const { isNetworkAdmin } = useLibrary();
  // Tant que la liste n'est pas connue (chargement, échec, écran publié avant
  // la migration), on ne filtre ni n'avertit : « staff nulle part » serait faux.
  const { staffLibraryIds, loaded: staffConnu } = useStaffLibraries();
  const libChoix = (isNetworkAdmin || !staffConnu) ? libOptions : bibliothequesProposables(libOptions, { isNetworkAdmin, staffLibraryIds });
  const peutReattribuer = isNetworkAdmin || staffLibraryIds.length >= 2;
  const [lastTombo, setLastTombo] = useState(null);
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const { data } = await supabase.from('libraries')
        .select('id, name, short_name, slug, city')
        .eq('is_active', true).order('name');
      if (!cancelled && Array.isArray(data)) setLibOptions(data);
    })();
    return () => { cancelled = true; };
  }, []);
  // B29 : une bibliothèque reconnue dans « Biblioteca » mais où l'on n'est pas
  // staff — l'exemplaire n'y sera pas rangé ; on le dit au lieu de l'ignorer.
  const [libHorsPortee, setLibHorsPortee] = useState(null);
  useEffect(() => {
    const q = String(loc.library || '').trim().toLowerCase();
    const reconnue = (l) => {
      const slug = String(l.slug || '').toLowerCase();
      const sn = String(l.short_name || '').toLowerCase();
      const nm = String(l.name || '').toLowerCase();
      return (slug && q.includes(slug)) || (sn && q.includes(sn)) || (nm && q.includes(nm)) || (nm && nm.includes(q) && q.length >= 3);
    };
    const lib = q ? libChoix.find(reconnue) : null;
    const autre = q && !lib && staffConnu ? libOptions.find(reconnue) : null;
    setLibHorsPortee(autre ? (autre.short_name || autre.name) : null);
    if (!lib) { setLastTombo(null); return; }
    // #fix-attrib (17/07) — la biblio identifiee ici servait deja a suggerer le
    // prochain tombo, mais n'etait jamais ecrite dans target_library_id : un
    // exemplaire d'une autre biblio du reseau retombait alors, en publication,
    // sur la biblio primaire du catalogueur (cf. AnarBib #cross-lib-mismatch).
    setForm(prev => {
      // H19 : un exemplaire importé garde la bibliothèque qui lui a été attribuée
      // (tampon de la promotion, réattribution du lot) : « Biblioteca » n'est ici
      // qu'une partie de la localisation.
      if (prev.book_draft_id || prev.import_staging_row_id) return prev;
      if (prev.target_library_id === lib.id) return prev;
      const next = { ...prev, target_library_id: lib.id };
      if (prev.target_holding_id) next.target_holding_id = ''; // holding d'une autre biblio, invalide desormais
      // B30 : le lot a SA bibliothèque — un exemplaire qui change de
      // bibliothèque sort d'un lot qui n'est pas de la nouvelle (la base ferait
      // de même). Pour tout le monde, administration du réseau comprise (que la
      // base ne trie pas) : même règle que handleReassignLibrary et que le
      // champ propriétaire de BookDraftForm — un lot, une bibliothèque.
      if (prev.batch_id) {
        const lot = (batches || []).find(b => String(b.id) === String(prev.batch_id));
        if (lot && !lotDeLaBibliotheque(lot, lib.id)) next.batch_id = '';
      }
      return next;
    });
    let cancelled = false;
    (async () => {
      const { data } = await supabase.from('exemplares')
        .select('tombo').eq('library_id', lib.id).not('tombo', 'is', null)
        .order('created_at', { ascending: false }).limit(1).maybeSingle();
      if (!cancelled) setLastTombo(data?.tombo || null);
      // #tombo-serie (17/06) — propose le PROCHAIN tombo libre de la serie de la
      // biblio (fn_next_tombo) dans le champ Tombo s'il est encore vide. Remplace
      // l'ancienne convention tombo=bib_ref qui retombait toujours sur le tombo
      // deja pris par l'exemplaire auto-cree -> collision exemplares_unique_tombo.
      try {
        const { data: nextT } = await supabase.rpc('fn_next_tombo', { p_library_id: lib.id });
        // H19 : pas de tombo figé d'avance pour un exemplaire importé — il le reçoit
        // à la publication, du schéma de SA bibliothèque (IMP-21 a).
        if (!cancelled && nextT) setForm(prev => (prev.tombo || prev.book_draft_id || prev.import_staging_row_id) ? prev : { ...prev, tombo: nextT });
      } catch { /* biblio sans tombo_pattern -> saisie manuelle */ }
    })();
    return () => { cancelled = true; };
  }, [loc.library, libOptions, staffLibraryIds.join(','), isNetworkAdmin, staffConnu]); // eslint-disable-line react-hooks/exhaustive-deps
  const [label, setLabel] = useState({ title: '', author: '', cdd: '', note: '' });
  const [parentBook, setParentBook] = useState(null); // resolved book from bib_ref
  // #fix-ux (18/07) — distingue "pas encore verifie" de "verifie et introuvable" :
  // sans ca, le message d'erreur apparaissait des la 1re frappe (parentBook est
  // nul tant qu'aucune recherche n'a tourne), avant meme la sortie du champ.
  const [bibRefChecked, setBibRefChecked] = useState(false);
  // Recherche du document parent par TITRE (pas seulement par bib_ref).
  const [titleQuery, setTitleQuery] = useState('');
  const [titleResults, setTitleResults] = useState([]);
  const [titleSearching, setTitleSearching] = useState(false);
  const [draftState, setDraftState] = useState('new');
  const [saving, setSaving] = useState(false);
  const [publishing, setPublishing] = useState(false);
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [acqModes, setAcqModes] = useState([]);
  // #cross-lib-reassign (19/07) — action dediee, separee du champ texte libre
  // « Biblioteca », pour reattribuer explicitement un exemplaire DEJA PUBLIE a
  // une autre biblioteca du reseau (avec confirmation), plutot que de compter
  // sur la reconnaissance floue du champ de localisation.
  const [reassignTarget, setReassignTarget] = useState('');
  const [reassigning, setReassigning] = useState(false);

  function f(k) { return form[k] || ''; }
  function set(k, v) { setForm(p => ({ ...p, [k]: v })); if (['saved','ready'].includes(draftState)) setDraftState('dirty'); }
  function setL(k, v) { setLoc(p => ({ ...p, [k]: v })); if (['saved','ready'].includes(draftState)) setDraftState('dirty'); }
  function setLb(k, v) { setLabel(p => ({ ...p, [k]: v })); if (['saved','ready'].includes(draftState)) setDraftState('dirty'); }
  // B30 : choisir un lot pour un exemplaire saisi NEUF encore sans
  // bibliothèque (staff de plusieurs bibliothèques) : le lot la fixe — sinon la
  // base poserait la principale et refuserait le rangement. Liste de staff pas
  // encore chargée : on pose quand même, la base vérifiera. Un exemplaire
  // ENREGISTRÉ sans bibliothèque (d'avant B29) n'en reçoit pas ici : la base
  // lui donne à l'enregistrement celle de son créateur, et juge le lot sur
  // celle-là (tg_drafts_library_fixed, puis le garde de rangement).
  function choisirLot(valeur) {
    set('batch_id', valeur);
    if (!valeur || f('id') || f('target_library_id') || f('book_draft_id') || f('import_staging_row_id')) return;
    const lot = (batches || []).find(b => String(b.id) === String(valeur));
    if (!lot?.library_id) return;
    if (isNetworkAdmin || !staffConnu || staffLibraryIds.includes(lot.library_id)) set('target_library_id', lot.library_id);
  }

  // ── Load drafts ─────────────────────────────────────────
  const loadDrafts = useCallback(async () => {
    setDraftsLoading(true);
    try {
      const { data } = await supabase.from('exemplar_drafts')
        .select('id, target_bib_ref, tombo, status, label_status, action, published_exemplar_id, batch_id, shelf_location, updated_at')
        .order('updated_at', { ascending: false }).limit(100);
      setDrafts(data || []);
    } catch {} finally { setDraftsLoading(false); }
  }, []);

  useEffect(() => { loadDrafts(); }, [loadDrafts]);

  // Modes d'acquisition (table de reference) pour le menu deroulant
  useEffect(() => {
    (async () => {
      const { data } = await supabase.from('catalog_ref_acquisition_modes')
        .select('code, label').eq('is_active', true).order('sort_order');
      setAcqModes(data || []);
    })();
  }, []);

  // -- Lot 0 -- charger un brouillon a editer (handoff catalogo/fila -> editeur) --
  useEffect(() => {
    if (!editingId) return;
    let cancelled = false;
    (async () => {
      try {
        const { data, error } = await supabase.from('exemplar_drafts').select('*').eq('id', Number(editingId)).single();
        if (cancelled) return;
        if (error) throw error;
        if (data) fillFromRecord(data);
      } catch (e) {
        if (!cancelled) setMsg({ text: t({ id: 'catalogacao.exemplar.loadError' }, { message: localizeError(e, t) }), kind: 'error' });
      } finally {
        if (!cancelled) onConsumed?.();
      }
    })();
    return () => { cancelled = true; };
  }, [editingId]);

  // P1.6-b.2 : pré-ciblage depuis le bandeau doublon — CatalogacaoPage passe le bib_ref
  // de la ficha existante ; on prépare un exemplaire neuf pointant dessus.
  useEffect(() => {
    if (!prefillBibRef) return;
    resetForm();
    set('target_bib_ref', prefillBibRef);
    resolveParentBook(prefillBibRef);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [prefillBibRef]);

  // ── Reset / Fill ────────────────────────────────────────
  function resetForm() {
    setForm({ id: '', published_exemplar_id: '', batch_id: '', action: 'create', status: 'draft', label_status: 'pending', target_bib_ref: '', target_library_id: '', target_holding_id: '', book_draft_id: '', import_staging_row_id: '', source_item_code: '', tombo: '', notes: '', circulation_policy: '', visibility: 'public', acquisition_mode: '', acquisition_date: '', provenance_note: '', source_library: '' });
    setLoc(emptyShelfLocation());
    setShowRawLoc(false);
    setLabel({ title: '', author: '', cdd: '', note: '' });
    setParentBook(null);
    setBibRefChecked(false);
    setDraftState('new');
    setMsg({ text: '', kind: '' });
    setReassignTarget('');
  }

  function fillFromRecord(r) {
    setForm({
      id: String(r.id || ''), published_exemplar_id: String(r.published_exemplar_id || ''),
      batch_id: String(r.batch_id || ''), action: r.published_exemplar_id ? 'update' : (r.action || 'create'),
      status: r.status || 'draft', label_status: r.label_status || 'pending',
      target_bib_ref: r.target_bib_ref || '', target_library_id: r.target_library_id || '',
      target_holding_id: String(r.target_holding_id || ''), tombo: r.tombo || '', notes: r.notes || '',
      book_draft_id: String(r.book_draft_id || ''), import_staging_row_id: String(r.import_staging_row_id || ''), source_item_code: r.source_item_code || '',
      circulation_policy: r.circulation_policy || '', visibility: r.visibility || 'public',
      acquisition_mode: r.acquisition_mode || '', acquisition_date: r.acquisition_date || '',
      provenance_note: r.provenance_note || '', source_library: r.source_library || '',
    });
    const parsedLoc = parseShelfLocation(r.shelf_location || '');
    setLoc(parsedLoc);
    setShowRawLoc(!!parsedLoc.raw || !!r.book_draft_id || !!r.import_staging_row_id);
    setLabel({ title: r.label_title_override || '', author: r.label_author_override || '', cdd: r.label_cdd_override || '', note: r.label_note || '' });
    setDraftState(r.status === 'ready' ? 'ready' : r.status === 'published' ? 'published' : r.id ? 'saved' : 'new');
    setMsg({ text: '', kind: '' });
    setReassignTarget('');
    // Resolve parent book
    if (r.target_bib_ref) { setBibRefChecked(false); resolveParentBook(r.target_bib_ref); }
    else { setParentBook(null); setBibRefChecked(false); }
  }

  // #UX-CAT (10/06) — auto-tombo (pré-remplissage du champ Tombo au chargement)
  // RETIRÉ à la demande : on ne pré-remplit plus le Tombo. La saisie est manuelle,
  // aidée par le « dernier tombo de la série » affiché au-dessus du champ (lastTombo).

  // ── Resolve parent book from bib_ref ────────────────────
  async function resolveParentBook(bibRef) {
    if (!bibRef?.trim()) { setParentBook(null); setBibRefChecked(false); return; }
    try {
      const { data } = await supabase.from('books')
        .select('id, titulo, subtitulo, autor, cdd, editora, ano, bib_ref, loanable, circulation_default')
        .eq('bib_ref', bibRef.trim()).limit(1).single();
      setParentBook(data || null);
      setBibRefChecked(true);
      if (data) {
        // P1.6-a : pré-remplit la circulation de l'exemplaire depuis le padrão de la ficha.
        // §5.6 : on utilise circulation_default (3 valeurs) quand présent ; repli sur le
        // booléen loanable (DOC-CIRC-1 : true -> 'ambos', sinon 'consulta'). Sans écraser un choix déjà posé.
        setForm(prev => prev.circulation_policy ? prev : { ...prev, circulation_policy: data.circulation_default || (data.loanable ? 'ambos' : 'consulta') });
        // #tombo-serie (17/06) — on ne pre-remplit PLUS le tombo avec le bib_ref :
        // l'exemplaire auto-cree de la fiche occupe deja ce tombo -> collision
        // exemplares_unique_tombo garantie. Le tombo est desormais propose depuis
        // la serie de la biblio (fn_next_tombo) des qu'une biblio est identifiee,
        // cf. le useEffect [loc.library] plus haut.
        // Auto-fill label from parent book if empty
        setLabel(prev => ({
          title: prev.title || data.titulo || '',
          author: prev.author || data.autor || '',
          cdd: prev.cdd || data.cdd || '',
          note: prev.note,
        }));
      }
    } catch { setParentBook(null); setBibRefChecked(true); }
  }

  function handleBibRefBlur() { resolveParentBook(f('target_bib_ref')); }
  function handleBibRefChange(v) { set('target_bib_ref', v); setBibRefChecked(false); }

  // ── Recherche du document parent par TITRE (débounce 350ms) ──
  // Ne propose que des documents PUBLIÉS (donc porteurs d'un bib_ref), seuls
  // rattachables comme parent d'un exemplaire. Un clic remplit le bib_ref et
  // résout la fiche (comme une saisie manuelle).
  useEffect(() => {
    const q = titleQuery.trim();
    if (q.length < 3) { setTitleResults([]); setTitleSearching(false); return; }
    let cancelled = false;
    setTitleSearching(true);
    const timer = setTimeout(async () => {
      try {
        const { data } = await supabase.from('books')
          .select('id, titulo, autor, ano, bib_ref')
          .not('bib_ref', 'is', null)
          .ilike('titulo', `%${q}%`)
          .order('titulo').limit(8);
        if (!cancelled) setTitleResults(data || []);
      } catch { if (!cancelled) setTitleResults([]); }
      finally { if (!cancelled) setTitleSearching(false); }
    }, 350);
    return () => { cancelled = true; clearTimeout(timer); };
  }, [titleQuery]);

  function selectParentByTitle(book) {
    set('target_bib_ref', book.bib_ref);
    setTitleQuery('');
    setTitleResults([]);
    resolveParentBook(book.bib_ref);
  }

  // ── Computed label preview ──────────────────────────────
  const labelAuthor = label.author || parentBook?.autor || '';
  const labelTitle = label.title || parentBook?.titulo || '';
  const labelCdd = label.cdd || parentBook?.cdd || '';
  const trigram = getTrigram(extractSurname(labelAuthor));

  // ── Save ────────────────────────────────────────────────
  async function handleSave(e) {
    e?.preventDefault();
    // H19 : un exemplaire importé est rattaché à sa notice (book_draft_id) ; son
    // tombo viendra du schéma de la bibliothèque à la publication (IMP-21 a).
    if (!f('target_bib_ref').trim() && !f('tombo').trim() && !f('book_draft_id')) { setMsg({ text: t({ id: 'catalogacao.exemplar.refOrTomboRequired' }), kind: 'error' }); return; }

    setSaving(true); setMsg({ text: '', kind: '' });
    try {
      const isUpdate = !!f('id');
      const payload = {
        ...(isUpdate ? { id: Number(f('id')) } : {}),
        published_exemplar_id: f('published_exemplar_id') ? Number(f('published_exemplar_id')) : null,
        batch_id: f('batch_id') ? Number(f('batch_id')) : null,
        action: f('published_exemplar_id') ? 'update' : 'create',
        status: f('status') || 'draft',
        label_status: f('label_status') || 'pending',
        target_bib_ref: f('target_bib_ref').trim() || null,
        target_library_id: f('target_library_id') || null,
        target_holding_id: f('target_holding_id') ? Number(f('target_holding_id')) : null,
        tombo: f('tombo').trim() || null,
        shelf_location: formatShelfLocation(loc) || null,
        label_title_override: label.title.trim() || null,
        label_author_override: label.author.trim() || null,
        label_cdd_override: label.cdd.trim() || null,
        label_note: label.note.trim() || null,
        notes: f('notes').trim() || null,
        circulation_policy: f('circulation_policy') || null,
        visibility: f('visibility') || 'public',
        acquisition_mode: f('acquisition_mode') || null,
        acquisition_date: f('acquisition_date') || null,
        provenance_note: f('provenance_note').trim() || null,
        source_library: f('source_library').trim() || null,
        updated_by: user?.id || null,
        ...(isUpdate ? {} : { created_by: user?.id || null }),
      };

      let result;
      if (isUpdate) {
        const { data, error } = await supabase.from('exemplar_drafts').update(payload).eq('id', Number(f('id'))).select().single();
        if (error) throw error; result = data;
      } else {
        const { data, error } = await supabase.from('exemplar_drafts').insert(payload).select().single();
        if (error) throw error; result = data;
      }
      // B30 : un rangement dans le lot d'une autre bibliothèque est refusé en
      // silence (l'exemplaire reste dans son ancien lot) ; fillFromRecord montre
      // le lot gardé, on dit pourquoi. Un exemplaire importé suit sa notice.
      const lotRefuse = !f('book_draft_id') && 'batch_id' in result
        && String(result.batch_id || '') !== String(f('batch_id') || '');
      fillFromRecord(result);
      setDraftState('saved');
      await loadDrafts();
      onChanged?.();
      const fait = isUpdate ? t({ id: 'catalogacao.exemplar.draftUpdated' }) : t({ id: 'catalogacao.exemplar.draftCreated' });
      setMsg(lotRefuse
        ? { text: `${fait} ${t({ id: 'error.batch.library_mismatch' })}`, kind: 'warn' }
        : { text: fait, kind: 'ok' });
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally { setSaving(false); }
  }

  // ── Mark label as ready ─────────────────────────────────
  function markLabelReady() {
    if (!label.title && !label.author && !label.cdd) { setMsg({ text: t({ id: 'catalogacao.exemplar.labelNeedFields' }), kind: 'error' }); return; }
    set('label_status', 'ready');
    setMsg({ text: t({ id: 'catalogacao.exemplar.labelMarked' }), kind: 'ok' });
  }

  // ── Publish ─────────────────────────────────────────────
  async function handlePublish() {
    if (!f('id')) { setMsg({ text: t({ id: 'catalogacao.msg.saveBeforePublish' }), kind: 'error' }); return; }
    if (!confirm(t({ id: 'catalogacao.exemplar.publishConfirm' }))) return;
    setPublishing(true); setMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase.rpc('publish_exemplar_draft', { p_draft_id: Number(f('id')) });
      if (error) throw error;
      setDraftState('published');
      await loadDrafts();
      onChanged?.();
      setMsg({ text: t({ id: 'catalogacao.exemplar.publishSuccess' }), kind: 'ok' });
    } catch (err) { setMsg({ text: localizeError(err, t), kind: 'error' }); }
    finally { setPublishing(false); }
  }

  // ── Reassign to another library (already-published copy only) ──
  // #cross-lib-reassign (19/07) : deleste target_holding_id et tombo (le
  // serveur regenere le tombo via fn_next_tombo pour la biblioteca de
  // destino, comme a la creation) puis republie immediatement — c'est une
  // action decisive, pas un brouillon qui traine.
  async function handleReassignLibrary() {
    const currentLibId = f('target_library_id');
    if (!f('id') || !reassignTarget || reassignTarget === currentLibId) return;
    const lib = libOptions.find(l => l.id === reassignTarget);
    if (!lib) return;
    const fromLib = libOptions.find(l => l.id === currentLibId);
    const fromLabel = fromLib ? (fromLib.short_name || fromLib.name) : '—';
    const toLabel = lib.short_name || lib.name;
    if (!confirm(t({ id: 'catalogacao.exemplar.reassignConfirm' }, { tombo: f('tombo') || '—', from: fromLabel, to: toLabel }))) return;

    setReassigning(true); setMsg({ text: '', kind: '' });
    try {
      // B30 : un exemplaire ne reste pas dans le lot d'une autre bibliothèque
      // que la sienne — batch_id nul si le lot n'est pas de la nouvelle.
      const lotActuel = f('batch_id') ? (batches || []).find(b => String(b.id) === String(f('batch_id'))) : null;
      const sortDuLot = !!lotActuel && !lotDeLaBibliotheque(lotActuel, lib.id);
      const { error: saveErr } = await supabase.from('exemplar_drafts')
        .update({
          target_library_id: lib.id, target_holding_id: null, tombo: null, updated_by: user?.id || null,
          ...(sortDuLot ? { batch_id: null } : {}),
        })
        .eq('id', Number(f('id')));
      if (saveErr) throw saveErr;
      const { error: pubErr } = await supabase.rpc('publish_exemplar_draft', { p_draft_id: Number(f('id')) });
      if (pubErr) throw pubErr;

      const { data: fresh } = await supabase.from('exemplar_drafts').select('*').eq('id', Number(f('id'))).single();
      if (fresh) fillFromRecord(fresh);
      setReassignTarget('');
      await loadDrafts();
      onChanged?.();
      setMsg({ text: t({ id: 'catalogacao.exemplar.reassignSuccess' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally {
      setReassigning(false);
    }
  }

  // ── UI constants ────────────────────────────────────────
  const fs = { width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' };
  const ls = { display: 'block', fontSize: '.78rem', fontWeight: 600, marginBottom: 2, color: 'var(--brand-muted, #bbb)' };
  const segBtn = { padding: '6px 11px', borderRadius: 6, border: '1px solid rgba(255,255,255,.14)', background: 'rgba(0,0,0,.25)', color: 'var(--brand-muted, #bbb)', fontSize: '.8rem', cursor: 'pointer' };
  const segBtnOn = { background: 'var(--brand-color-primary, #7a0b14)', color: '#fff', borderColor: 'var(--brand-color-primary, #7a0b14)', fontWeight: 700 };
  const pills = {
    new: { l: t({ id: 'catalogacao.exemplar.pillNew' }), c: 'info' },
    saved: { l: t({ id: 'catalogacao.exemplar.pillSaved' }), c: 'ok' },
    dirty: { l: t({ id: 'catalogacao.exemplar.pillDirty' }), c: 'warn' },
    ready: { l: t({ id: 'catalogacao.exemplar.pillReady' }), c: 'ok' },
    published: { l: t({ id: 'catalogacao.exemplar.pillPublished' }), c: 'ok' },
  };
  const pill = pills[draftState] || pills.new;
  const labelPills = {
    pending: { l: t({ id: 'catalogacao.exemplar.labelPending' }), c: 'warn' },
    ready: { l: t({ id: 'catalogacao.exemplar.labelReady' }), c: 'ok' },
    published: { l: t({ id: 'catalogacao.exemplar.labelPublished' }), c: 'ok' },
  };
  const lPill = labelPills[f('label_status')] || labelPills.pending;

  return (
    <div>
      {/* ── Header ───────────────────────────────────── */}
      <div className="cat-panel-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 8, marginBottom: 12 }}>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <h3 style={{ margin: 0 }}>{t({ id: 'catalogacao.exemplar.heading' })}</h3>
          <span className={`cat-pill ${pill.c}`} style={{ fontSize: '.68rem' }}>{pill.l}</span>
          <span className={`cat-pill ${lPill.c}`} style={{ fontSize: '.68rem' }}>{lPill.l}</span>
        </div>
        <div style={{ display: 'flex', gap: 6 }}>
          <button type="button" className="ab-button ab-button--sm" onClick={resetForm}>
            {t({ id: 'catalogacao.exemplar.newCopy' })}
          </button>
          <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={loadDrafts} disabled={draftsLoading}>
            {draftsLoading ? t({ id: 'catalogacao.ui.refreshing' }) : t({ id: 'catalogacao.queue.refreshShort' })}
          </button>
        </div>
      </div>

      {/* ── Bandeau info auto-exemplaire ──────────────── */}
      <div style={{ padding: '8px 12px', borderRadius: 6, fontSize: '.78rem', marginBottom: 12, background: 'rgba(29,78,216,.10)', color: '#93c5fd', border: '1px solid rgba(29,78,216,.2)' }}>
        💡 {t({ id: 'catalogacao.exemplar.autoExemplarInfo' })}
      </div>

      {/* ── Messages ─────────────────────────────────── */}
      {msg.text && <div style={{ padding: '8px 12px', borderRadius: 6, fontSize: '.82rem', marginBottom: 12, background: msg.kind === 'ok' ? 'rgba(21,128,61,.12)' : 'rgba(220,38,38,.12)', color: msg.kind === 'ok' ? '#4ade80' : '#f87171' }}>{msg.text}</div>}

      {/* ── Drafts list ──────────────────────────────── */}
      {drafts.length > 0 && (
        <div style={{ marginBottom: 16, maxHeight: 180, overflowY: 'auto', border: '1px solid rgba(255,255,255,.06)', borderRadius: 8 }}>
          {drafts.map((d, i) => (
            <div key={d.id} style={{
              display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8, flexWrap: 'wrap',
              padding: '6px 10px', cursor: 'pointer',
              background: String(d.id) === f('id') ? 'rgba(29,78,216,.12)' : i % 2 === 0 ? 'rgba(0,0,0,.1)' : 'transparent',
              borderBottom: '1px solid rgba(255,255,255,.04)',
            }} onClick={async () => {
              const { data } = await supabase.from('exemplar_drafts').select('*').eq('id', d.id).single();
              if (data) fillFromRecord(data);
            }}>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: '.82rem', fontWeight: 600 }}>
                  {d.tombo || d.target_bib_ref || t({ id: 'catalogacao.queue.noTombo' })}
                </div>
                <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #888)' }}>
                  ref: {d.target_bib_ref || '—'} · {d.status === 'draft' ? t({ id: 'catalogacao.status.draft' }) : d.status === 'ready' ? t({ id: 'catalogacao.status.ready' }) : d.status === 'published' ? t({ id: 'catalogacao.status.published' }) : d.status}
                  {d.label_status !== 'pending' && ` · ${d.label_status === 'ready' ? t({ id: 'catalogacao.exemplar.labelReady' }) : d.label_status === 'published' ? t({ id: 'catalogacao.exemplar.labelPublished' }) : d.label_status}`}
                </div>
              </div>
              <span className={`cat-pill ${d.status === 'draft' ? 'info' : 'ok'}`} style={{ fontSize: '.62rem', flexShrink: 0 }}>
                {d.status === 'draft' ? t({ id: 'catalogacao.status.draft' }) : d.status === 'ready' ? t({ id: 'catalogacao.status.ready' }) : d.status === 'published' ? t({ id: 'catalogacao.status.published' }) : d.status}
              </span>
            </div>
          ))}
        </div>
      )}

      {/* ═══════════════════════════════════════════════ */}
      {/* ETAPA 1: Documento de origem                   */}
      {/* ═══════════════════════════════════════════════ */}
      <form onSubmit={handleSave}>
        <div style={{ padding: 14, borderRadius: 10, background: 'rgba(29,78,216,.06)', border: '1px solid rgba(29,78,216,.15)', marginBottom: 14 }}>
          <div style={{ fontSize: '.82rem', fontWeight: 700, marginBottom: 6 }}>{t({ id: 'catalogacao.exemplar.originStep' })}</div>
          <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #999)', marginBottom: 8 }}>
            {t({ id: 'catalogacao.exemplar.originStepDesc' })}
          </div>
          <div className="cat-book-grid">
            <div className="cat-field" style={{ gridColumn: 'span 3', position: 'relative' }}>
              <label style={ls}>{t({ id: 'catalogacao.exemplar.findByTitle' })}</label>
              <input type="text" value={titleQuery} onChange={e => setTitleQuery(e.target.value)}
                placeholder={t({ id: 'catalogacao.exemplar.findByTitlePlaceholder' })} style={fs} />
              {titleQuery.trim().length >= 3 && (
                <div style={{ position: 'absolute', zIndex: 20, top: '100%', left: 0, right: 0, background: 'var(--brand-surface, #1b1b1b)', border: '1px solid rgba(255,255,255,.12)', borderRadius: 6, marginTop: 2, maxHeight: 240, overflowY: 'auto', boxShadow: '0 8px 24px rgba(0,0,0,.4)' }}>
                  {titleSearching && (
                    <div style={{ padding: '8px 12px', fontSize: '.74rem', color: 'var(--brand-muted,#999)' }}>{t({ id: 'common.searching' })}</div>
                  )}
                  {!titleSearching && titleResults.length === 0 && (
                    <div style={{ padding: '8px 12px', fontSize: '.74rem', color: 'var(--brand-muted,#999)' }}>{t({ id: 'catalogacao.exemplar.findByTitleNone' })}</div>
                  )}
                  {titleResults.map(bk => (
                    <button type="button" key={bk.id} onClick={() => selectParentByTitle(bk)}
                      style={{ display: 'block', width: '100%', textAlign: 'left', padding: '8px 12px', background: 'none', border: 'none', borderBottom: '1px solid rgba(255,255,255,.06)', cursor: 'pointer', color: 'inherit' }}>
                      <div style={{ fontSize: '.78rem', fontWeight: 700 }}>{bk.titulo}</div>
                      <div style={{ fontSize: '.7rem', color: 'var(--brand-muted,#aaa)' }}>
                        {[bk.autor, bk.ano].filter(Boolean).join(' · ')}{bk.bib_ref ? ` · ref. ${bk.bib_ref}` : ''}
                      </div>
                    </button>
                  ))}
                </div>
              )}
            </div>
            <div className="cat-field" style={{ gridColumn: 'span 2' }}>
              <label style={ls}>{t({ id: 'catalogacao.exemplar.bibRefLabel' })}</label>
              <input type="text" value={f('target_bib_ref')} onChange={e => handleBibRefChange(e.target.value)}
                onBlur={handleBibRefBlur} placeholder="0000123" style={fs} />
              <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #888)', marginTop: 2 }}>
                {t({ id: 'catalogacao.exemplar.bibRefHint' })}
              </div>
            </div>
            <div className="cat-field">
              <label style={ls}>{t({ id: 'catalogacao.author.batchLabel' })}</label>
              {/* B30 : lots de la bibliothèque de l'exemplaire (lot enregistré
                  toujours proposé) ; un exemplaire importé suit le lot de sa
                  notice : champ en lecture seule. */}
              <select value={f('batch_id')} onChange={e => choisirLot(e.target.value)} style={fs}
                disabled={!!f('book_draft_id')}>
                <option value="">{t({ id: 'catalogacao.author.noBatch' })}</option>
                {lotsProposables(batches, {
                  isNetworkAdmin,
                  staffLibraryIds: staffConnu ? staffLibraryIds : null,
                  libraryId: f('target_library_id') || null,
                  garder: f('batch_id') || null,
                }).map(b => <option key={b.id} value={String(b.id)}>{libelleLot(b, t)}</option>)}
              </select>
            </div>
          </div>

          {/* Parent book preview */}
          {parentBook && (
            <div style={{ marginTop: 10, padding: '8px 12px', borderRadius: 6, background: 'rgba(0,0,0,.2)', border: '1px solid rgba(255,255,255,.06)' }}>
              <div style={{ fontSize: '.78rem', fontWeight: 700 }}>{parentBook.titulo}{parentBook.subtitulo ? ` : ${parentBook.subtitulo}` : ''}</div>
              <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #aaa)' }}>
                {[parentBook.autor, parentBook.editora, parentBook.ano].filter(Boolean).join(' · ')}
                {parentBook.cdd && ` · CDD: ${parentBook.cdd}`}
                {parentBook.bib_ref && ` · ref. ${parentBook.bib_ref}`}
              </div>
            </div>
          )}
          {f('target_bib_ref') && !parentBook && bibRefChecked && (
            <div style={{ marginTop: 8, fontSize: '.78rem', color: '#fbbf24' }}>
              {t({ id: 'catalogacao.exemplar.noBookFound' })}
            </div>
          )}
        </div>

        {/* ═══════════════════════════════════════════════ */}
        {/* STEP 2: Physical copy — tombo + location        */}
        {/* ═══════════════════════════════════════════════ */}
        <div style={{ padding: 14, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)', marginBottom: 14 }}>
          <div style={{ fontSize: '.82rem', fontWeight: 700, marginBottom: 6 }}>{t({ id: 'catalogacao.exemplar.materialStep' })}</div>
          <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #999)', marginBottom: 8 }}>
            {t({ id: 'catalogacao.exemplar.materialStepDesc' })}
          </div>
          <div className="cat-book-grid">
            <div className="cat-field">
              <label style={ls}>{t({ id: 'catalogacao.exemplar.library' })}</label>
              <input type="text" list="cat-lib-options" value={loc.library} onChange={e => setL('library', e.target.value)}
                placeholder="BLMF - Belém do Pará" style={fs} />
              <datalist id="cat-lib-options">
                {libChoix.map(l => (
                  <option key={l.id} value={`${l.short_name || l.name}${l.city ? ' - ' + l.city : ''}`} />
                ))}
              </datalist>
              {libHorsPortee && (
                <div data-testid="exemplar-library-not-yours" role="alert" style={{ fontSize: '.7rem', color: 'var(--brand-warn, #e0a44a)', marginTop: 3 }}>
                  {t({ id: 'catalogacao.exemplar.libraryNotYours' }, { library: libHorsPortee })}
                </div>
              )}
            </div>
            <div className="cat-field" style={{ gridColumn: 'span 2' }}>
              <label style={ls}>{t({ id: 'catalogacao.exemplar.tombo' })}</label>
              {lastTombo && (
                <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #aaa)', marginBottom: 3 }}>
                  {t({ id: 'catalogacao.exemplar.lastTomboHint' }, { tombo: lastTombo })}
                </div>
              )}
              <input type="text" value={f('tombo')} onChange={e => set('tombo', e.target.value)}
                placeholder="123-CCLA-2026 ou 123-CCLA-2026-02" style={fs} />
              {f('source_item_code') && (
                <div data-testid="exemplar-source-code" style={{ fontSize: '.7rem', color: 'var(--brand-muted, #aaa)', marginTop: 3 }}>
                  {t({ id: 'catalogacao.exemplar.sourceItemCode' }, { code: f('source_item_code') })}
                </div>
              )}
            </div>
            <div className="cat-field">
              <label style={ls}>{t({ id: 'catalogacao.exemplar.sectorRoom' })}</label>
              <input type="text" value={loc.sector} onChange={e => setL('sector', e.target.value)}
                placeholder={t({ id: 'catalogacao.exemplar.sectorRoom.ph' })} style={fs} />
            </div>
            <div className="cat-field">
              <label style={ls}>{t({ id: 'catalogacao.exemplar.shelfUnit' })}</label>
              <input type="text" value={loc.shelfUnit} onChange={e => setL('shelfUnit', e.target.value)}
                placeholder={t({ id: 'catalogacao.exemplar.shelfUnit.ph' })} style={fs} />
            </div>
            <div className="cat-field">
              <label style={ls}>{t({ id: 'catalogacao.exemplar.shelfLevel' })}</label>
              <input type="text" value={loc.shelfLevel} onChange={e => setL('shelfLevel', e.target.value)}
                placeholder={t({ id: 'catalogacao.exemplar.shelfLevel.ph' })} style={fs} />
            </div>
            <div className="cat-field" style={{ gridColumn: 'span 2' }}>
              <label style={ls}>{t({ id: 'catalogacao.exemplar.locNote' })}</label>
              <input type="text" value={loc.note} onChange={e => setL('note', e.target.value)}
                placeholder={t({ id: 'catalogacao.exemplar.locNote.ph' })} style={fs} />
            </div>
            {(showRawLoc || loc.raw) && (
              <div className="cat-field" style={{ gridColumn: 'span 3' }}>
                <label style={ls}>{t({ id: 'catalogacao.exemplar.shelfRaw' })}</label>
                <input type="text" data-testid="exemplar-shelf-raw" value={loc.raw} onChange={e => setL('raw', e.target.value)}
                  placeholder={t({ id: 'catalogacao.exemplar.shelfRaw.ph' })} style={fs} />
              </div>
            )}
            <div className="cat-field" style={{ gridColumn: 'span 3' }}>
              <label style={ls}>{t({ id: 'catalogacao.exemplar.notes' })}</label>
              <textarea value={f('notes')} onChange={e => set('notes', e.target.value)}
                placeholder={t({ id: 'catalogacao.exemplar.notes.ph' })}
                style={{ ...fs, resize: 'vertical', minHeight: 50 }} />
            </div>
          </div>
        </div>

        {/* ═══════════════════════════════════════════════ */}
        {/* Reattribuer a outra biblioteca (exemplar ja publicado apenas) */}
        {/* ═══════════════════════════════════════════════ */}
        {f('published_exemplar_id') && peutReattribuer && (
          <div style={{ padding: 14, borderRadius: 10, background: 'rgba(180,83,9,.06)', border: '1px solid rgba(180,83,9,.2)', marginBottom: 14 }}>
            <div style={{ fontSize: '.82rem', fontWeight: 700, marginBottom: 6 }}>{t({ id: 'catalogacao.exemplar.reassignStep' })}</div>
            <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #999)', marginBottom: 8 }}>
              {t({ id: 'catalogacao.exemplar.reassignHint' })}
            </div>
            <div className="cat-book-grid">
              <div className="cat-field">
                <label style={ls}>{t({ id: 'catalogacao.exemplar.reassignCurrentLibrary' })}</label>
                <input type="text" value={(() => {
                  const lib = libOptions.find(l => l.id === f('target_library_id'));
                  return lib ? `${lib.short_name || lib.name}${lib.city ? ' - ' + lib.city : ''}` : '—';
                })()} disabled style={{ ...fs, opacity: .7 }} />
              </div>
              <div className="cat-field">
                <label style={ls}>{t({ id: 'catalogacao.exemplar.reassignNewLibrary' })}</label>
                <select value={reassignTarget} onChange={e => setReassignTarget(e.target.value)} style={fs}>
                  <option value="">—</option>
                  {libChoix.filter(l => l.id !== f('target_library_id')).map(l => (
                    <option key={l.id} value={l.id}>{`${l.short_name || l.name}${l.city ? ' - ' + l.city : ''}`}</option>
                  ))}
                </select>
              </div>
              <div className="cat-field" style={{ display: 'flex', alignItems: 'flex-end' }}>
                <button type="button" className="ab-button ab-button--sm" style={{ background: 'rgba(180,83,9,.75)' }}
                  disabled={!reassignTarget || reassigning} onClick={handleReassignLibrary}>
                  {reassigning ? t({ id: 'catalogacao.saving' }) : t({ id: 'catalogacao.exemplar.reassignButton' })}
                </button>
              </div>
            </div>
          </div>
        )}

        {/* ═══════════════════════════════════════════════ */}
        {/* STEP 3: Circulation policy & visibility (P1.6-a) */}
        {/* ═══════════════════════════════════════════════ */}
        <div style={{ padding: 14, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)', marginBottom: 14 }}>
          <div style={{ fontSize: '.82rem', fontWeight: 700, marginBottom: 8 }}>③ {t({ id: 'catalogacao.exemplar.circulationPolicy.label' })} · {t({ id: 'catalogacao.exemplar.visibility.label' })}</div>
          <div className="cat-book-grid">
            <div className="cat-field" style={{ gridColumn: 'span 3' }}>
              <label style={ls}>{t({ id: 'catalogacao.exemplar.circulationPolicy.label' })}</label>
              <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginTop: 2 }}>
                {['emprestavel', 'consulta', 'ambos'].map(v => (
                  <button key={v} type="button" onClick={() => set('circulation_policy', v)}
                    style={{ ...segBtn, ...(f('circulation_policy') === v ? segBtnOn : {}) }}>
                    {t({ id: `catalogacao.exemplar.circulationPolicy.${v}` })}
                  </button>
                ))}
              </div>
              <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #888)', marginTop: 4 }}>
                {t({ id: 'catalogacao.exemplar.circulationPolicy.hint' })}
              </div>
            </div>
            <div className="cat-field" style={{ gridColumn: 'span 3' }}>
              <label style={ls}>{t({ id: 'catalogacao.exemplar.visibility.label' })}</label>
              <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginTop: 2 }}>
                {['public', 'staff_only'].map(v => (
                  <button key={v} type="button" onClick={() => set('visibility', v)}
                    style={{ ...segBtn, ...(f('visibility') === v ? segBtnOn : {}) }}>
                    {t({ id: `catalogacao.exemplar.visibility.${v}` })}
                  </button>
                ))}
              </div>
              <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #888)', marginTop: 4 }}>
                {t({ id: 'catalogacao.exemplar.visibility.hint' })}
              </div>
            </div>
          </div>
        </div>

        {/* ═══════════════════════════════════════════════ */}
        {/* STEP 5: Aquisicao / Proveniencia (repliable)    */}
        {/* ═══════════════════════════════════════════════ */}
        <details style={{ padding: 14, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)', marginBottom: 14 }}>
          <summary style={{ fontSize: '.82rem', fontWeight: 700, cursor: 'pointer' }}>{t({ id: 'catalogacao.exemplar.acquisitionStep' })}</summary>
          <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #888)', margin: '6px 0 10px' }}>
            {t({ id: 'catalogacao.exemplar.acquisitionStepDesc' })}
          </div>
          <div className="cat-book-grid">
            <div className="cat-field" style={{ gridColumn: 'span 2' }}>
              <label style={ls}>{t({ id: 'catalogacao.exemplar.acquisitionMode' })}</label>
              <select value={f('acquisition_mode')} onChange={e => set('acquisition_mode', e.target.value)} style={fs}>
                <option value="">{t({ id: 'catalogacao.exemplar.acquisitionModeDefault' })}</option>
                {acqModes.map(m => <option key={m.code} value={m.code}>{m.label || m.code}</option>)}
              </select>
            </div>
            <div className="cat-field" style={{ gridColumn: 'span 2' }}>
              <label style={ls}>{t({ id: 'catalogacao.exemplar.acquisitionDate' })}</label>
              <input type="date" value={f('acquisition_date')} onChange={e => set('acquisition_date', e.target.value)} style={fs} />
            </div>
            <div className="cat-field" style={{ gridColumn: 'span 2' }}>
              <label style={ls}>{t({ id: 'catalogacao.exemplar.sourceLibrary' })}</label>
              <input type="text" value={f('source_library')} onChange={e => set('source_library', e.target.value)}
                placeholder={t({ id: 'catalogacao.exemplar.sourceLibrary.ph' })} style={fs} />
            </div>
            <div className="cat-field" style={{ gridColumn: 'span 6' }}>
              <label style={ls}>{t({ id: 'catalogacao.exemplar.provenanceNote' })}</label>
              <input type="text" value={f('provenance_note')} onChange={e => set('provenance_note', e.target.value)}
                placeholder={t({ id: 'catalogacao.exemplar.provenanceNote.ph' })} style={fs} />
            </div>
          </div>
        </details>

        {/* ═══════════════════════════════════════════════ */}
        {/* STEP 4: Label — the tag on the spine            */}
        {/* ═══════════════════════════════════════════════ */}
        <div style={{ padding: 14, borderRadius: 10, background: 'rgba(21,128,61,.04)', border: '1px solid rgba(21,128,61,.15)', marginBottom: 14 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6, flexWrap: 'wrap', gap: 6 }}>
            <div style={{ fontSize: '.82rem', fontWeight: 700 }}>{t({ id: 'catalogacao.exemplar.labelStep' })}</div>
            <span className={`cat-pill ${lPill.c}`} style={{ fontSize: '.65rem' }}>{lPill.l}</span>
          </div>
          <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #999)', marginBottom: 10 }}>
            {t({ id: 'catalogacao.exemplar.labelStepDesc' })}
          </div>

          <div style={{ display: 'flex', gap: 16, alignItems: 'flex-start', flexWrap: 'wrap' }}>
            {/* ── Label visual preview ──────────────── */}
            <div style={{
              width: 120, flexShrink: 0, padding: 12, borderRadius: 8,
              background: 'rgba(0,0,0,.25)', border: '1px solid rgba(255,255,255,.08)',
              textAlign: 'center',
            }}>
              <div style={{
                width: 56, height: 56, margin: '0 auto 6px', borderRadius: 8,
                background: 'var(--brand-color-primary, #7a0b14)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontWeight: 900, fontSize: '1rem', color: '#fff', letterSpacing: '.04em',
              }}>{trigram}</div>
              <div style={{ fontSize: '.7rem', fontWeight: 700, lineHeight: 1.2, marginBottom: 2 }}>
                {labelTitle || t({ id: 'catalogacao.ui.titleFallback' })}
              </div>
              <div style={{ fontSize: '.62rem', color: 'var(--brand-muted, #aaa)' }}>
                {labelCdd || '—'}
              </div>
              <div style={{ fontSize: '.62rem', color: 'var(--brand-muted, #888)', marginTop: 2 }}>
                {labelAuthor || '—'}
              </div>
            </div>

            {/* ── Label fields ─────────────────────── */}
            {/* #fix-mobile (18/07) : minWidth fixe en px = plancher absolu qui ignore
                flexWrap sur les petits Android (320-360px) -> debordement. min()
                laisse le plancher jouer des qu'il y a la place, sans jamais depasser
                le conteneur. */}
            <div style={{ flex: 1, minWidth: 'min(280px, 100%)' }}>
              <div className="cat-book-grid">
                <div className="cat-field" style={{ gridColumn: 'span 2' }}>
                  <label style={ls}>{t({ id: 'catalogacao.exemplar.labelAuthor' })}</label>
                  <input type="text" value={label.author} onChange={e => setLb('author', e.target.value)}
                    placeholder={parentBook?.autor || 'Autor do documento de origem'} style={fs} />
                </div>
                <div className="cat-field">
                  <label style={ls}>{t({ id: 'catalogacao.exemplar.labelCdd' })}</label>
                  <input type="text" value={label.cdd} onChange={e => setLb('cdd', e.target.value)}
                    placeholder={parentBook?.cdd || 'CDD'} style={fs} />
                </div>
                <div className="cat-field" style={{ gridColumn: 'span 2' }}>
                  <label style={ls}>{t({ id: 'catalogacao.exemplar.labelTitle' })}</label>
                  <input type="text" value={label.title} onChange={e => setLb('title', e.target.value)}
                    placeholder={parentBook?.titulo || 'Título do documento de origem'} style={fs} />
                </div>
                <div className="cat-field">
                  <label style={ls}>{t({ id: 'catalogacao.exemplar.labelNote' })}</label>
                  <input type="text" value={label.note} onChange={e => setLb('note', e.target.value)}
                    placeholder="Vol. 2 / T. 1 / 2ª ed." style={fs} />
                </div>
              </div>
              <div style={{ marginTop: 8 }}>
                <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                  onClick={markLabelReady} disabled={f('label_status') === 'ready'}>
                  {t({ id: 'catalogacao.exemplar.markLabelReady' })}
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* ── Architecture documentale (mode complet) ── */}
        {isComplete && (
          <div style={{ padding: 12, borderRadius: 8, background: 'rgba(0,0,0,.1)', border: '1px dashed rgba(255,255,255,.08)', marginBottom: 14 }}>
            <h4 style={{ margin: '0 0 6px', fontSize: '.82rem' }}>{t({ id: 'catalogacao.exemplar.archTitle' })}</h4>
            <div style={{ fontSize: '.75rem', color: 'var(--brand-muted, #888)', lineHeight: 1.6 }}>
              <div style={{ marginBottom: 3 }}>
                <strong>{t({ id: 'catalogacao.exemplar.archCommon' })}</strong> {parentBook ? `${parentBook.titulo} (ref. ${parentBook.bib_ref})` : f('target_bib_ref') || '—'}
              </div>
              <div style={{ marginBottom: 3 }}>
                <strong>{t({ id: 'catalogacao.exemplar.archExemplar' })}</strong> {t({ id: 'catalogacao.exemplar.tombo' })} {f('tombo') || '—'} · {formatShelfLocation(loc) || t({ id: 'catalogacao.exemplar.noLocation' })}
              </div>
              <div style={{ marginBottom: 3 }}>
                <strong>{t({ id: 'catalogacao.exemplar.archLabel' })}</strong> {trigram} / {labelCdd || '—'} · {labelTitle || '—'} · {labelAuthor || '—'}
                {label.note && ` · ${label.note}`}
              </div>
              <div>
                <strong>{t({ id: 'catalogacao.exemplar.archState' })}</strong> {pill.l} · {lPill.l}
                {f('batch_id') && ` · ${t({ id: 'catalogacao.exemplar.archBatch' }, { id: f('batch_id') })}`}
              </div>
            </div>
          </div>
        )}

        {/* ── Actions ─────────────────────────────────── */}
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <button type="submit" className="ab-button" disabled={saving}>
            {saving ? t({ id: 'catalogacao.saving' }) : t({ id: 'catalogacao.exemplar.saveExemplar' })}
          </button>
          <button type="button" className="ab-button" style={{ background: 'rgba(21,128,61,.7)' }}
            disabled={publishing || !f('id')} onClick={handlePublish}>
            {publishing ? t({ id: 'catalogacao.author.publishing' }) : t({ id: 'catalogacao.exemplar.publishExemplar' })}
          </button>
          <button type="button" className="ab-button ab-button--ghost" onClick={resetForm}>{t({ id: 'catalogacao.ui.clear' })}</button>
        </div>
      </form>
    </div>
  );
}
