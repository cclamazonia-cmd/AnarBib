import { useIntl } from 'react-intl';
import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import DuplicateCompareModal from './DuplicateCompareModal';
import { assertRpcOk } from '../../lib/rpcStatus.js';

// Labels resolved inside component via t()
const TYPE_KEYS = { book: 'catalogacao.type.book', author: 'catalogacao.type.author', exemplar: 'catalogacao.type.exemplar' };
const STATUS_KEYS = { draft: 'catalogacao.status.draft', ready: 'catalogacao.status.ready', published: 'catalogacao.status.published', cancelled: 'catalogacao.status.cancelled' };
const PAGE_SIZE = 100;

// Les gestes de masse passaient UNE requete PAR LIGNE : jeter 300 brouillons,
// c'etait 300 allers-retours, et la vue ne se reconciliait qu'a la toute fin
// (d'ou l'impression tenace qu'il faut recharger la page plusieurs fois).
// PostgREST accepte un filtre `in` sur une liste d'ids : une requete par
// paquet suffit.
const TABLE_FOR = { book: 'book_drafts', author: 'author_drafts', exemplar: 'exemplar_drafts' };
const ID_CHUNK = 200;

// Portee d'un geste de corbeille : '' = toute la corbeille (donc tout le
// reseau, la corbeille n'etant cloisonnee ni par lot ni par bibliotheque),
// 'none' = les brouillons sans lot, sinon l'id d'un lot. Meme vocabulaire que
// le filtre de la file au-dessus, pour que les deux se lisent pareil.
//
// Ce qui est repare ici n'est pas un droit mais une PORTEE : « Vider la
// corbeille » atteignait 259 brouillons de 5 bibliotheques la ou on voulait
// nettoyer un seul lot (28/08/2026). Le bouton porte desormais exactement sur
// ce que la liste affiche, et la confirmation nomme cette portee.
function scopeToBatch(q, batch) {
  if (batch === 'none') return q.is('batch_id', null);
  if (batch) return q.eq('batch_id', Number(batch));
  return q;
}

function chunkIds(ids, size = ID_CHUNK) {
  const out = [];
  for (let i = 0; i < ids.length; i += size) out.push(ids.slice(i, i + size));
  return out;
}

// Rend le nombre de lignes REELLEMENT traitees : un paquet en echec ne compte
// pas, la ou le `catch {}` par ligne des boucles d'origine incrementait quand
// meme et pouvait annoncer « 300 traites » sans que rien ne bouge.
// Rendre la propriete LISIBLE plutot que la cloisonner : on ne cloisonne pas
// les rascunhos par bibliotheque (les lots n'en portent pas, 1784 rascunhos sur
// 2227 non plus, et une autorite est un commun federal), mais on peut au moins
// dire A QUI appartient le travail qu'on s'apprete a toucher.
//
// La destination vient de la vue v_book_draft_destination, qui appelle la MEME
// fonction que la publication : afficher une destination calculee autrement
// serait pire que ne rien afficher — on ferait confiance a une information
// fausse. `enregistree` distingue ce que le rascunho declare de ce qui est
// seulement deduit de l'adhesion de qui a catalogue.
async function attacherDestinations(items) {
  const ids = items.filter(it => it._type === 'book').map(it => it.id);
  if (!ids.length) return items;
  try {
    const { data } = await supabase.from('v_book_draft_destination')
      .select('draft_id, library_id, enregistree').in('draft_id', ids);
    const par = new Map((data || []).map(r => [r.draft_id, r]));
    for (const it of items) {
      if (it._type !== 'book') continue;
      const d = par.get(it.id);
      if (d) { it._libId = d.library_id; it._libEnregistree = d.enregistree; }
    }
  } catch { /* l information de propriete est un confort, pas un pre-requis */ }
  return items;
}

async function bulkByType(sel, run) {
  const byType = new Map();
  for (const { type, id } of sel) {
    if (!byType.has(type)) byType.set(type, []);
    byType.get(type).push(id);
  }
  let ok = 0;
  for (const [type, ids] of byType) {
    for (const part of chunkIds(ids)) {
      const { error } = await run(TABLE_FOR[type], part);
      if (!error) ok += part.length;
    }
  }
  return ok;
}
// Colonnes physiques présentes dans les 3 tables brouillon → triables côté serveur.
const SERVER_SORT_COLS = ['updated_at', 'last_opened_at', 'status'];
// Largeurs de colonnes partagées entre l'en-tête cliquable et les lignes (alignement).
const COLW = { check: 16, type: 66, status: 78, opened: 80, updated: 84, actions: 210 };

// Comparateur de la file fusionnée (multi-couches) selon la colonne de tri choisie.
// Les colonnes physiques sont aussi poussées au serveur (cf. loadQueue) pour cadrer
// la fenêtre ; ce tri client réordonne la fusion des 3 couches de façon cohérente.
function makeComparator(sortBy, sortDir) {
  const dir = sortDir === 'asc' ? 1 : -1;
  return (a, b) => {
    if (sortBy === 'last_opened_at') {
      const ta = a.last_opened_at ? new Date(a.last_opened_at).getTime() : null;
      const tb = b.last_opened_at ? new Date(b.last_opened_at).getTime() : null;
      if (ta === null && tb === null) return 0;
      if (ta === null) return 1;   // jamais ouvert → toujours en bas
      if (tb === null) return -1;
      return (ta - tb) * dir;
    }
    if (sortBy === 'type' || sortBy === 'label' || sortBy === 'status') {
      const key = sortBy === 'type' ? '_type' : sortBy === 'label' ? '_label' : 'status';
      const va = (a[key] || '').toString().toLowerCase();
      const vb = (b[key] || '').toString().toLowerCase();
      return va < vb ? -dir : va > vb ? dir : 0;
    }
    return (new Date(a.updated_at).getTime() - new Date(b.updated_at).getTime()) * dir;  // updated_at (défaut)
  };
}

export default function QueuePanel({ batches, onEditItem, onChanged, isActive = false }) {
  // ── Filters ─────────────────────────────────────────────
  const { formatMessage: t, formatDate } = useIntl();
  const [typeFilter, setTypeFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [actionFilter, setActionFilter] = useState('');
  // Filtre par lot (Mission 3) : '' = tous les lots, 'none' = sans lot
  // (batch_id null), sinon l'id du lot. Branche loadQueue ET selectAllInFilter
  // pour que la selection cross-pages capture exactement le lot choisi.
  const [batchFilter, setBatchFilter] = useState('');
  const [search, setSearch] = useState('');

  // ── Active queue ────────────────────────────────────────
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(false);
  const [selected, setSelected] = useState(new Set());
  const [msg, setMsg] = useState({ text: '', kind: '' });
  // #152 : brouillon (book) en cours de comparaison de doublons (modale)
  const [dupItem, setDupItem] = useState(null);

  // ── Tri par en-tête de colonne ──────────────────────────
  const [sortBy, setSortBy] = useState('updated_at');
  const [sortDir, setSortDir] = useState('desc');
  function toggleSort(col) {
    if (sortBy === col) { setSortDir(d => (d === 'asc' ? 'desc' : 'asc')); }
    else { setSortBy(col); setSortDir(col === 'updated_at' || col === 'last_opened_at' ? 'desc' : 'asc'); }
    setPage(0);
  }

  // ── Pagination (serveur) ────────────────────────────────
  const [page, setPage] = useState(0);
  const [total, setTotal] = useState(0);
  const [totalPages, setTotalPages] = useState(1);
  // Recherche cote serveur, debounce 300ms ; toute nouvelle recherche revient page 1
  const [dSearch, setDSearch] = useState('');
  useEffect(() => {
    const id = setTimeout(() => { setDSearch(search); setPage(0); }, 300);
    return () => clearTimeout(id);
  }, [search]);

  // ── Trash ───────────────────────────────────────────────
  const [trash, setTrash] = useState([]);
  const [trashLoading, setTrashLoading] = useState(false);
  const [trashSelected, setTrashSelected] = useState(new Set());
  // Ce que la corbeille contient reellement, distinct de ce que la liste
  // affiche : sans ce compte, le pop-up de vidage annoncait 259 et la liste
  // en montrait 100 sans le dire — l'ecart se lit comme une incoherence.
  const [trashTotal, setTrashTotal] = useState(0);
  const [trashBatch, setTrashBatch] = useState('');
  // La suppression definitive est reservee a la coordination (policies
  // restrictives du 29/08, par alignement sur l'ecran d'import). Une policy qui
  // refuse un DELETE ne leve PAS d'erreur : PostgREST supprime zero ligne et
  // repond 204. Sans cette garde cote ecran, le bouton dirait « supprimes »
  // sans que rien ne bouge — le pire des deux mondes.
  const [isCoord, setIsCoord] = useState(false);
  const [libs, setLibs] = useState({});
  // Journal des suppressions DEFINITIVES, et leur rejeu. Sans cet ecran, la
  // RPC de restauration serait un chemin que personne n'emprunte — donc un
  // chemin dont on ne saurait pas qu'il est casse.
  const [deleted, setDeleted] = useState([]);
  const [deletedLoading, setDeletedLoading] = useState(false);

  // ── Load active queue ───────────────────────────────────
  const loadQueue = useCallback(async () => {
    setLoading(true); setSelected(new Set());
    try {
      const from = page * PAGE_SIZE, to = from + PAGE_SIZE - 1;
      const statuses = statusFilter ? [statusFilter] : ['draft', 'ready'];
      // Sanitise pour la syntaxe .or() de PostgREST (virgules/parentheses la cassent)
      const s = dSearch.trim().replace(/[,()]/g, ' ').trim();
      const allItems = [];
      let totalCount = 0, maxCount = 0;
      // Tri : colonnes physiques → ordre serveur ; sinon fenêtre récente (updated_at desc) + tri client.
      const orderCol = SERVER_SORT_COLS.includes(sortBy) ? sortBy : 'updated_at';
      const orderAsc = SERVER_SORT_COLS.includes(sortBy) ? sortDir === 'asc' : false;
      const orderOpts = { ascending: orderAsc, nullsFirst: false };

      // Books
      if (!typeFilter || typeFilter === 'book') {
        let q = supabase.from('book_drafts')
          .select('id, titulo, subtitulo, autor, status, action, batch_id, published_book_id, bib_ref, updated_at, last_opened_at', { count: 'exact' })
          .in('status', statuses);
        if (actionFilter) q = q.eq('action', actionFilter);
        if (batchFilter === 'none') q = q.is('batch_id', null);
        else if (batchFilter) q = q.eq('batch_id', Number(batchFilter));
        if (s) q = q.or(`titulo.ilike.%${s}%,subtitulo.ilike.%${s}%,autor.ilike.%${s}%,bib_ref.ilike.%${s}%`);
        const { data, count } = await q.order(orderCol, orderOpts).range(from, to);
        totalCount += count || 0; maxCount = Math.max(maxCount, count || 0);
        (data || []).forEach(d => allItems.push({ ...d, _type: 'book', _label: d.titulo || t({ id: 'catalogacao.queue.noTitle' }), _sub: d.autor || '' }));
      }

      // Authors
      if (!typeFilter || typeFilter === 'author') {
        let q = supabase.from('author_drafts')
          .select('id, preferred_name, sort_name, status, action, batch_id, published_author_id, updated_at, last_opened_at', { count: 'exact' })
          .in('status', statuses);
        if (actionFilter) q = q.eq('action', actionFilter);
        if (batchFilter === 'none') q = q.is('batch_id', null);
        else if (batchFilter) q = q.eq('batch_id', Number(batchFilter));
        if (s) q = q.or(`preferred_name.ilike.%${s}%,sort_name.ilike.%${s}%`);
        const { data, count } = await q.order(orderCol, orderOpts).range(from, to);
        totalCount += count || 0; maxCount = Math.max(maxCount, count || 0);
        (data || []).forEach(d => allItems.push({ ...d, _type: 'author', _label: d.preferred_name || t({ id: 'catalogacao.queue.noName' }), _sub: d.sort_name || '' }));
      }

      // Exemplars
      if (!typeFilter || typeFilter === 'exemplar') {
        let q = supabase.from('exemplar_drafts')
          .select('id, target_bib_ref, tombo, status, label_status, action, batch_id, published_exemplar_id, target_library_id, updated_at, last_opened_at', { count: 'exact' })
          .in('status', statuses);
        if (actionFilter) q = q.eq('action', actionFilter);
        if (batchFilter === 'none') q = q.is('batch_id', null);
        else if (batchFilter) q = q.eq('batch_id', Number(batchFilter));
        if (s) q = q.or(`tombo.ilike.%${s}%,target_bib_ref.ilike.%${s}%`);
        const { data, count } = await q.order(orderCol, orderOpts).range(from, to);
        totalCount += count || 0; maxCount = Math.max(maxCount, count || 0);
        (data || []).forEach(d => allItems.push({ ...d, _type: 'exemplar', _label: d.tombo || d.target_bib_ref || t({ id: 'catalogacao.queue.noTombo' }), _sub: `ref: ${d.target_bib_ref || '—'}`, _libId: d.target_library_id, _libEnregistree: true }));
      }

      // Tri de la fusion des couches de la page courante selon la colonne choisie.
      allItems.sort(makeComparator(sortBy, sortDir));
      await attacherDestinations(allItems);
      setItems(allItems);
      setTotal(totalCount);
      // Pages basees sur la couche la plus volumineuse (evite des pages vides en "Todas")
      setTotalPages(Math.max(1, Math.ceil(maxCount / PAGE_SIZE)));
    } catch (err) { setMsg({ text: localizeError(err, t), kind: 'error' }); }
    finally { setLoading(false); }
  }, [typeFilter, statusFilter, actionFilter, batchFilter, dSearch, page, sortBy, sortDir, t]);

  useEffect(() => { loadQueue(); }, [loadQueue]);

  // Rafraîchit la file à chaque (ré)activation de l'onglet « Fila ». Le panneau est
  // monté en permanence (masqué en CSS) et une publication / un rejet effectués
  // depuis l'éditeur (BookDraftForm / ExemplarDraftForm) ne le notifient pas ; sans
  // ce rechargement, un brouillon déjà publié (passé en status='published', donc
  // hors de la file active) resterait affiché jusqu'au prochain changement de filtre
  // ou rechargement de page. Cf. motif isActive de LabelSheetPrinter.
  useEffect(() => {
    if (isActive) loadQueue();
  }, [isActive]); // eslint-disable-line react-hooks/exhaustive-deps

  // ── Load trash ──────────────────────────────────────────
  const loadTrash = useCallback(async () => {
    setTrashLoading(true); setTrashSelected(new Set());
    try {
      const all = [];
      const { data: bk } = await scopeToBatch(supabase.from('book_drafts').select('id, titulo, autor, status, updated_at').eq('status', 'cancelled'), trashBatch).order('updated_at', { ascending: false }).limit(100);
      (bk || []).forEach(d => all.push({ ...d, _type: 'book', _label: d.titulo || t({ id: 'catalogacao.queue.noTitle' }), _sub: d.autor || '' }));
      const { data: au } = await scopeToBatch(supabase.from('author_drafts').select('id, preferred_name, status, updated_at').eq('status', 'cancelled'), trashBatch).order('updated_at', { ascending: false }).limit(100);
      (au || []).forEach(d => all.push({ ...d, _type: 'author', _label: d.preferred_name || t({ id: 'catalogacao.queue.noName' }), _sub: '' }));
      const { data: ex } = await scopeToBatch(supabase.from('exemplar_drafts').select('id, tombo, target_bib_ref, status, target_library_id, updated_at').eq('status', 'cancelled'), trashBatch).order('updated_at', { ascending: false }).limit(100);
      (ex || []).forEach(d => all.push({ ...d, _type: 'exemplar', _label: d.tombo || d.target_bib_ref || t({ id: 'catalogacao.queue.noTombo' }), _sub: '', _libId: d.target_library_id, _libEnregistree: true }));
      all.sort((a, b) => new Date(b.updated_at) - new Date(a.updated_at));
      await attacherDestinations(all);
      setTrash(all);
      setTrashTotal(await countTrash());
    } catch {} finally { setTrashLoading(false); }
  }, [t, trashBatch]);

  useEffect(() => { loadTrash(); }, [loadTrash]);

  // ── Load deletion log ───────────────────────────────────
  const loadDeleted = useCallback(async () => {
    setDeletedLoading(true);
    try {
      const { data } = await supabase.from('catalog_audit_log')
        .select('id, occurred_at, entity_type, entity_id, label, details')
        .eq('action', 'delete')
        .order('occurred_at', { ascending: false })
        .limit(50);
      // Une entree dont l'instantane a ete purge (90 jours) reste une trace,
      // mais elle n'est plus rejouable : on la montre sans bouton.
      setDeleted(data || []);
    } catch { setDeleted([]); } finally { setDeletedLoading(false); }
  }, []);

  useEffect(() => { loadDeleted(); }, [loadDeleted]);

  useEffect(() => {
    let vivant = true;
    supabase.from('libraries').select('id, slug, name')
      .then(({ data }) => {
        if (!vivant) return;
        const m = {};
        (data || []).forEach(l => { m[l.id] = l.slug || l.name; });
        setLibs(m);
      })
      .catch(() => {});
    return () => { vivant = false; };
  }, []);

  useEffect(() => {
    let vivant = true;
    supabase.rpc('fn_is_catalog_coordinator')
      .then(({ data }) => { if (vivant) setIsCoord(data === true); })
      .catch(() => {});
    return () => { vivant = false; };
  }, []);

  // ── Selection helpers ───────────────────────────────────
  function toggleSelect(key) { setSelected(prev => { const n = new Set(prev); n.has(key) ? n.delete(key) : n.add(key); return n; }); }
  function selectAll() { if (selected.size === items.length) setSelected(new Set()); else setSelected(new Set(items.map(it => `${it._type}:${it.id}`))); }
  function toggleTrashSelect(key) { setTrashSelected(prev => { const n = new Set(prev); n.has(key) ? n.delete(key) : n.add(key); return n; }); }
  function selectAllTrash() { if (trashSelected.size === trash.length) setTrashSelected(new Set()); else setTrashSelected(new Set(trash.map(it => `${it._type}:${it.id}`))); }

  // Selectionner TOUS les items correspondant au filtre (cross-pages).
  // Fetch leger : IDs seulement, sans .range(), limite haute de securite.
  async function selectAllInFilter() {
    setLoading(true);
    try {
      const statuses = statusFilter ? [statusFilter] : ['draft', 'ready'];
      const s = dSearch.trim().replace(/[,()]/g, ' ').trim();
      const allIds = [];

      if (!typeFilter || typeFilter === 'book') {
        let q = supabase.from('book_drafts').select('id').in('status', statuses).limit(5000);
        if (actionFilter) q = q.eq('action', actionFilter);
        if (batchFilter === 'none') q = q.is('batch_id', null);
        else if (batchFilter) q = q.eq('batch_id', Number(batchFilter));
        if (s) q = q.or(`titulo.ilike.%${s}%,subtitulo.ilike.%${s}%,autor.ilike.%${s}%,bib_ref.ilike.%${s}%`);
        const { data } = await q;
        (data || []).forEach(d => allIds.push(`book:${d.id}`));
      }
      if (!typeFilter || typeFilter === 'author') {
        let q = supabase.from('author_drafts').select('id').in('status', statuses).limit(5000);
        if (actionFilter) q = q.eq('action', actionFilter);
        if (batchFilter === 'none') q = q.is('batch_id', null);
        else if (batchFilter) q = q.eq('batch_id', Number(batchFilter));
        if (s) q = q.or(`preferred_name.ilike.%${s}%,sort_name.ilike.%${s}%`);
        const { data } = await q;
        (data || []).forEach(d => allIds.push(`author:${d.id}`));
      }
      if (!typeFilter || typeFilter === 'exemplar') {
        let q = supabase.from('exemplar_drafts').select('id').in('status', statuses).limit(5000);
        if (actionFilter) q = q.eq('action', actionFilter);
        if (batchFilter === 'none') q = q.is('batch_id', null);
        else if (batchFilter) q = q.eq('batch_id', Number(batchFilter));
        if (s) q = q.or(`tombo.ilike.%${s}%,target_bib_ref.ilike.%${s}%`);
        const { data } = await q;
        (data || []).forEach(d => allIds.push(`exemplar:${d.id}`));
      }

      setSelected(new Set(allIds));
    } catch (err) { setMsg({ text: localizeError(err, t), kind: 'error' }); }
    finally { setLoading(false); }
  }

  function getSelectedItems() { return [...selected].map(k => { const [t, id] = k.split(':'); return { type: t, id: Number(id) }; }); }
  function getTrashSelectedItems() { return [...trashSelected].map(k => { const [t, id] = k.split(':'); return { type: t, id: Number(id) }; }); }

  function tableFor(type) { return TABLE_FOR[type]; }

  // Un filtre qui propose un lot VIDE propose un filtre qui ne peut rien rendre :
  // le lot 58, clos et vide, encombrait le menu alors qu'il n'avait plus un seul
  // brouillon. On ne liste donc que les lots qui retiennent encore quelque chose,
  // et on dit lesquels sont clos — l'onglet « Lots » reste, lui, exhaustif.
  // « Porte encore quelque chose », les fiches publiees comprises : le filtre
  // « Situation » permet de les afficher, donc retirer ces lots du menu rendrait
  // cette combinaison inatteignable.
  const lotsFiltrables = batches.filter(
    b => ((b._enCours ?? 0) + (b._publies ?? 0) + (b._corbeille ?? 0)) > 0);

  function labelLot(b) {
    return b.status === 'open' ? b.name : `${b.name} (${t({ id: 'catalogacao.queue.batchClosed' })})`;
  }

  // Compte reel de la corbeille, toutes tables. La LISTE affichee est plafonnee
  // a 100 par type : s'appuyer sur elle pour compter ou pour vider ne traite
  // qu'une tranche, en laissant croire que le reste a resiste.
  async function countTrash() {
    const rs = await Promise.all(Object.values(TABLE_FOR).map(tb =>
      scopeToBatch(supabase.from(tb).select('id', { count: 'exact', head: true }).eq('status', 'cancelled'), trashBatch)));
    return rs.reduce((s, r) => s + (r.count || 0), 0);
  }

  // ── Batch actions ───────────────────────────────────────
  async function publishSelected() {
    const sel = getSelectedItems();
    if (!sel.length) { setMsg({ text: t({ id: 'catalogacao.queue.selectAtLeast' }), kind: 'error' }); return; }
    if (!confirm(t({ id: 'catalogacao.queue.publishConfirm' }, { count: sel.length }))) return;
    setMsg({ text: '', kind: '' });
    let ok = 0, fail = 0; const errs = [];
    for (const { type, id } of sel) {
      try {
        const rpc = type === 'book' ? 'publish_book_draft' : type === 'author' ? 'publish_author_draft' : 'publish_exemplar_draft';
        const param = type === 'book' ? { p_draft_id: id } : type === 'author' ? { p_draft_id: id } : { p_draft_id: id };
        const { error } = await supabase.rpc(rpc, param);
        if (error) throw error;
        ok++;
      } catch (err) {
        fail++;
        const m = localizeError(err, t);
        if (m && !errs.includes(m)) errs.push(m);
      }
    }
    setMsg({
      text: t({ id: 'catalogacao.queue.publishResult' }, { ok, fail }) + (errs.length ? ` ${errs.join(' ')}` : ''),
      kind: fail ? 'warn' : 'ok',
    });
    await loadQueue(); await loadTrash();
    onChanged?.();
  }

  async function discardSelected() {
    const sel = getSelectedItems();
    if (!sel.length) { setMsg({ text: t({ id: 'catalogacao.queue.selectAtLeast' }), kind: 'error' }); return; }
    if (!confirm(t({ id: 'catalogacao.queue.discardConfirm' }, { count: sel.length }))) return;
    setMsg({ text: '', kind: '' });
    const ok = await bulkByType(sel, (table, ids) =>
      supabase.from(table).update({ status: 'cancelled' }).in('id', ids));
    setMsg({ text: t({ id: 'catalogacao.queue.discardResult' }, { count: ok }), kind: 'ok' });
    await loadQueue(); await loadTrash();
    onChanged?.();
  }

  async function markSelectedReady() {
    const sel = getSelectedItems();
    if (!sel.length) { setMsg({ text: t({ id: 'catalogacao.queue.selectAtLeast' }), kind: 'error' }); return; }
    const ok = await bulkByType(sel, (table, ids) =>
      supabase.from(table).update({ status: 'ready' }).in('id', ids));
    setMsg({ text: t({ id: 'catalogacao.queue.markedReadyResult' }, { count: ok }), kind: 'ok' });
    await loadQueue();
    onChanged?.();
  }

  async function assignBatchToSelected(batchId) {
    if (!batchId) return;
    const sel = getSelectedItems();
    if (!sel.length) { setMsg({ text: t({ id: 'catalogacao.queue.selectAtLeast' }), kind: 'error' }); return; }
    const ok = await bulkByType(sel, (table, ids) =>
      supabase.from(table).update({ batch_id: Number(batchId) }).in('id', ids));
    setMsg({ text: t({ id: 'catalogacao.queue.batchAssignResult' }, { count: ok }), kind: 'ok' });
    await loadQueue();
    onChanged?.();
  }

  // ── Trash actions ───────────────────────────────────────
  async function restoreTrashSelected() {
    const sel = getTrashSelectedItems();
    if (!sel.length) return;
    const ok = await bulkByType(sel, (table, ids) =>
      supabase.from(table).update({ status: 'draft' }).in('id', ids));
    setMsg({ text: t({ id: 'catalogacao.queue.restoreResult' }, { count: ok }), kind: 'ok' });
    await loadQueue(); await loadTrash();
    onChanged?.();
  }

  async function deleteTrashItem(type, id) {
    if (!confirm(t({ id: 'catalogacao.queue.deleteConfirm' }))) return;
    try { await supabase.from(tableFor(type)).delete().eq('id', id); } catch {}
    await loadTrash();
    // Le decompte de brouillons du lot depend de cette ligne : sans cet appel,
    // l'onglet « Lots » gardait son ancien compte jusqu'a un rechargement.
    onChanged?.();
  }

  async function emptyTrash() {
    // Le compte vient de la BASE, pas de la liste affichee : celle-ci s'arrete a
    // 100 par type, donc au-dela le bouton supprimait une tranche, annoncait le
    // compte de cette tranche, et laissait le reste — ce qui se lit comme un echec.
    const total = await countTrash();
    if (!total) return;
    // Une corbeille non filtree porte sur tout le reseau : le dire, plutot que
    // de poser la meme question anodine dans les deux cas.
    const lot = trashBatch === 'none'
      ? t({ id: 'catalogacao.queue.noBatch' })
      : (batches.find(b => String(b.id) === String(trashBatch))?.name || trashBatch);
    const question = trashBatch
      ? t({ id: 'catalogacao.queue.emptyTrashBatchConfirm' }, { count: total, batch: lot })
      : t({ id: 'catalogacao.queue.emptyTrashConfirm' }, { count: total });
    if (!confirm(question)) return;
    setMsg({ text: '', kind: '' });
    for (const table of Object.values(TABLE_FOR)) {
      const { error } = await scopeToBatch(supabase.from(table).delete().eq('status', 'cancelled'), trashBatch);
      if (error) { setMsg({ text: localizeError(error, t), kind: 'error' }); break; }
    }
    // Le compte annonce est ce que la base a REELLEMENT perdu, pas ce qu'on
    // croyait lui demander.
    const reste = await countTrash();
    setMsg({ text: t({ id: 'catalogacao.queue.emptyTrashResult' }, { count: total - reste }), kind: 'ok' });
    await loadTrash();
    onChanged?.();
  }

  async function restoreDeleted(auditId) {
    if (!confirm(t({ id: 'catalogacao.queue.restoreDeletedConfirm' }))) return;
    try {
      const { data, error } = await supabase.rpc('fn_restore_deleted_draft', { p_audit_id: auditId });
      if (error) throw error;
      assertRpcOk(data);
      setMsg({ text: t({ id: 'catalogacao.queue.restoreDeletedResult' }, { id: data?.draft_id ?? auditId }), kind: 'ok' });
      await loadTrash(); await loadDeleted(); await loadQueue();
      onChanged?.();
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
      await loadDeleted();
    }
  }

  // ── Render ──────────────────────────────────────────────
  const fs = { padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem', width: '100%' };
  const ls = { display: 'block', fontSize: '.78rem', fontWeight: 600, marginBottom: 2, color: 'var(--brand-muted, #bbb)' };

  // En-tête de colonne cliquable : tri asc/desc avec indicateur (▲/▼ actif, ↕ inactif).
  // Le nom de la bibliotheque, et surtout si elle est ENREGISTREE ou seulement
  // deduite : le « ≈ » n'est pas un ornement, il dit que rien ne rattache
  // formellement ce brouillon a cette bibliotheque.
  function renderLib(it) {
    if (!it._libId || !libs[it._libId]) return null;
    const sure = it._libEnregistree;
    return (
      <span
        title={t({ id: sure ? 'catalogacao.queue.libraryRecorded' : 'catalogacao.queue.libraryInferred' })}
        style={{ color: 'var(--brand-muted, #888)', fontStyle: sure ? 'normal' : 'italic' }}>
        {' · '}{sure ? '' : '≈'}{libs[it._libId]}
      </span>
    );
  }

  function renderHeaderCell(col, label, cellStyle) {
    const active = sortBy === col;
    return (
      <button type="button" onClick={() => toggleSort(col)} title={label}
        style={{
          ...cellStyle, display: 'flex', alignItems: 'center', gap: 3,
          background: 'none', border: 'none', cursor: 'pointer', padding: 0, font: 'inherit',
          fontSize: '.68rem', fontWeight: active ? 700 : 600,
          color: active ? '#cbd5e1' : 'var(--brand-muted, #888)',
        }}>
        <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{label}</span>
        <span style={{ flexShrink: 0, opacity: active ? 1 : 0.3 }}>{active ? (sortDir === 'asc' ? '▲' : '▼') : '↕'}</span>
      </button>
    );
  }

  return (
    <div>
      <div className="cat-panel-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 8, marginBottom: 12 }}>
        <div>
          <h3 style={{ margin: 0 }}>{t({ id: 'catalogacao.queue.title' })}</h3>
          <div style={{ fontSize: '.75rem', color: 'var(--brand-muted, #999)', marginTop: 2 }}>
            {t({ id: 'catalogacao.queue.description' })}
          </div>
        </div>
        <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={() => { loadQueue(); loadTrash(); }} disabled={loading}>
          {loading ? t({ id: 'catalogacao.queue.refreshing' }) : t({ id: 'catalogacao.queue.refresh' })}
        </button>
      </div>

      {msg.text && <div style={{ padding: '8px 12px', borderRadius: 6, fontSize: '.82rem', marginBottom: 12, background: msg.kind === 'ok' ? 'rgba(21,128,61,.12)' : msg.kind === 'warn' ? 'rgba(180,83,9,.12)' : 'rgba(220,38,38,.12)', color: msg.kind === 'ok' ? '#4ade80' : msg.kind === 'warn' ? '#fbbf24' : '#f87171' }}>{msg.text}</div>}

      {/* ── Filters ──────────────────────────────────── */}
      <div className="cat-book-grid" style={{ marginBottom: 14 }}>
        <div className="cat-field">
          <label style={ls}>{t({ id: 'catalogacao.queue.layerLabel' })}</label>
          <select value={typeFilter} onChange={e => { setTypeFilter(e.target.value); setPage(0); }} style={fs}>
            <option value="">{t({ id: 'catalogacao.queue.allTypes' })}</option>
            <option value="book">{t({ id: 'catalogacao.catalog.documents' })}</option>
            <option value="author">{t({ id: 'catalogacao.catalog.authorities' })}</option>
            <option value="exemplar">{t({ id: 'catalogacao.catalog.exemplars' })}</option>
          </select>
        </div>
        <div className="cat-field">
          <label style={ls}>{t({ id: 'catalogacao.queue.statusLabel' })}</label>
          <select value={statusFilter} onChange={e => { setStatusFilter(e.target.value); setPage(0); }} style={fs}>
            <option value="">{t({ id: 'catalogacao.queue.allActive' })}</option>
            <option value="draft">{t({ id: 'catalogacao.status.draft' })}</option>
            <option value="ready">{t({ id: 'catalogacao.status.ready' })}</option>
          </select>
        </div>
        <div className="cat-field">
          <label style={ls}>{t({ id: 'catalogacao.queue.actionLabel' })}</label>
          <select value={actionFilter} onChange={e => { setActionFilter(e.target.value); setPage(0); }} style={fs}>
            <option value="">{t({ id: 'catalogacao.queue.allActions' })}</option>
            <option value="create">{t({ id: 'catalogacao.queue.actionCreate' })}</option>
            <option value="update">{t({ id: 'catalogacao.queue.actionUpdate' })}</option>
          </select>
        </div>
        <div className="cat-field">
          <label style={ls}>{t({ id: 'catalogacao.queue.batchLabel' })}</label>
          <select value={batchFilter} onChange={e => { setBatchFilter(e.target.value); setPage(0); }} style={fs}>
            <option value="">{t({ id: 'catalogacao.queue.allBatches' })}</option>
            <option value="none">{t({ id: 'catalogacao.queue.noBatch' })}</option>
            {lotsFiltrables.map(b => <option key={b.id} value={String(b.id)}>{labelLot(b)}</option>)}
          </select>
        </div>
        <div className="cat-field" style={{ gridColumn: 'span 2' }}>
          <label style={ls}>{t({ id: 'catalogacao.queue.searchLabel' })}</label>
          <input type="text" value={search} onChange={e => setSearch(e.target.value)}
            placeholder={t({ id: 'catalogacao.queue.searchPlaceholder' })} style={fs} />
        </div>
      </div>

      {/* ── Batch actions bar ────────────────────────── */}
      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center', marginBottom: 10, padding: '8px 10px', borderRadius: 8, background: 'rgba(0,0,0,.15)', border: '1px solid rgba(255,255,255,.06)' }}>
        <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={selectAll}>
          {selected.size === items.length && items.length > 0 ? t({ id: 'catalogacao.queue.deselectAll' }) : t({ id: 'catalogacao.queue.selectAllCount' }, { count: items.length })}
        </button>
        {total > items.length && (
          <button type="button" className="ab-button ab-button--secondary ab-button--sm"
            onClick={selectAllInFilter} disabled={loading || selected.size === total}>
            {selected.size >= total ? t({ id: 'catalogacao.queue.selectedAllFilter' }, { count: total }) : t({ id: 'catalogacao.queue.selectAllFilter' }, { count: total })}
          </button>
        )}
        <span style={{ fontSize: '.75rem', color: selected.size > items.length ? '#4ade80' : 'var(--brand-muted, #aaa)', fontWeight: selected.size > items.length ? 700 : 400 }}>
          {t({ id: 'catalogacao.queue.selectedCount' }, { count: selected.size })}{selected.size > items.length ? t({ id: 'catalogacao.queue.crossPage' }) : ''}
        </span>
        <div style={{ flex: 1 }} />
        {onEditItem && (
          <button type="button" className="ab-button ab-button--secondary ab-button--sm"
            disabled={selected.size !== 1}
            onClick={() => { const [s] = getSelectedItems(); if (s) onEditItem(s.type, s.id); }}>
            {t({ id: 'catalogacao.queue.resume' })}
          </button>
        )}
        <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={markSelectedReady} disabled={!selected.size}>
          {t({ id: 'catalogacao.queue.markReady' })}
        </button>
        <button type="button" className="ab-button ab-button--sm" onClick={publishSelected} disabled={!selected.size}>
          {t({ id: 'catalogacao.queue.publishSelected' })}
        </button>
        <select style={{ ...fs, width: 'auto', fontSize: '.72rem', padding: '4px 8px' }}
          onChange={e => { if (e.target.value) { assignBatchToSelected(e.target.value); e.target.value = ''; } }}>
          <option value="">{t({ id: 'catalogacao.queue.assignBatch' })}</option>
          {batches.filter(b => b.status === 'open').map(b => <option key={b.id} value={String(b.id)}>{b.name}</option>)}
        </select>
        <button type="button" className="ab-button ab-button--danger ab-button--sm" onClick={discardSelected} disabled={!selected.size}>
          {t({ id: 'catalogacao.queue.discardBatch' })}
        </button>
      </div>

      {/* ── Queue table ──────────────────────────────── */}
      <div style={{ border: '1px solid rgba(255,255,255,.06)', borderRadius: 8, maxHeight: 400, overflowY: 'auto', overflowX: 'auto', marginBottom: 10 }}>
        {/* En-têtes cliquables (tri asc/desc) — alignées sur les cellules via COLW */}
        <div style={{
          display: 'flex', alignItems: 'center', gap: 8, padding: '7px 10px',
          position: 'sticky', top: 0, zIndex: 1, background: 'rgba(18,20,24,.97)',
          borderBottom: '1px solid rgba(255,255,255,.12)',
        }}>
          <span style={{ width: COLW.check, flexShrink: 0 }} />
          {renderHeaderCell('type', t({ id: 'catalogacao.queue.colType' }), { width: COLW.type, flexShrink: 0, justifyContent: 'center' })}
          {renderHeaderCell('label', t({ id: 'catalogacao.queue.colTitle' }), { flex: 1, minWidth: 0 })}
          {renderHeaderCell('status', t({ id: 'catalogacao.queue.statusLabel' }), { width: COLW.status, flexShrink: 0 })}
          {renderHeaderCell('last_opened_at', t({ id: 'catalogacao.queue.colOpened' }), { width: COLW.opened, flexShrink: 0, justifyContent: 'flex-end' })}
          {renderHeaderCell('updated_at', t({ id: 'catalogacao.queue.colUpdated' }), { width: COLW.updated, flexShrink: 0, justifyContent: 'flex-end' })}
          <span style={{ width: COLW.actions, flexShrink: 0 }} />
        </div>
        {items.length === 0 && !loading && (
          <div style={{ padding: 16, textAlign: 'center', fontSize: '.85rem', color: 'var(--brand-muted, #888)' }}>
            {t({ id: 'catalogacao.queue.empty' })}
          </div>
        )}
        {items.map((it, i) => {
          const key = `${it._type}:${it.id}`;
          const isSelected = selected.has(key);
          return (
            <div key={key} style={{
              display: 'flex', alignItems: 'center', gap: 8, padding: '7px 10px',
              background: isSelected ? 'rgba(29,78,216,.1)' : i % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent',
              borderBottom: '1px solid rgba(255,255,255,.04)',
            }}>
              <span style={{ width: COLW.check, flexShrink: 0, display: 'flex', alignItems: 'center' }}>
                <input type="checkbox" checked={isSelected} onChange={() => toggleSelect(key)} />
              </span>
              <span className={`cat-pill ${it._type === 'book' ? 'info' : it._type === 'author' ? 'warn' : 'ok'}`}
                style={{ fontSize: '.6rem', flexShrink: 0, width: COLW.type, textAlign: 'center' }}>
                {t({ id: TYPE_KEYS[it._type] })}
              </span>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: '.82rem', fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {it._label}
                </div>
                <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #888)' }}>
                  {it._sub}{it.batch_id ? ` · ${t({ id: 'catalogacao.queue.batchPrefix' }, { id: it.batch_id })}` : ''}{renderLib(it)} · {it.action === 'create' ? t({ id: 'catalogacao.queue.actionCreate' }) : it.action === 'update' ? t({ id: 'catalogacao.queue.actionUpdate' }) : it.action}
                </div>
              </div>
              <span style={{ width: COLW.status, flexShrink: 0, display: 'flex' }}>
                <span className={`cat-pill ${it.status === 'ready' ? 'ok' : 'info'}`} style={{ fontSize: '.6rem' }}>
                  {STATUS_KEYS[it.status] ? t({ id: STATUS_KEYS[it.status] }) : it.status}
                </span>
              </span>
              <div style={{ fontSize: '.65rem', color: 'var(--brand-muted, #666)', flexShrink: 0, width: COLW.opened, textAlign: 'right' }}>
                {it.last_opened_at ? formatDate(it.last_opened_at, { year: 'numeric', month: '2-digit', day: '2-digit' }) : '—'}
              </div>
              <div style={{ fontSize: '.65rem', color: 'var(--brand-muted, #666)', flexShrink: 0, width: COLW.updated, textAlign: 'right' }}>
                {formatDate(it.updated_at, { year: 'numeric', month: '2-digit', day: '2-digit' })}
              </div>
              <div style={{ width: COLW.actions, flexShrink: 0, display: 'flex', gap: 6, justifyContent: 'flex-end', flexWrap: 'wrap' }}>
                {it._type === 'book' && (
                  <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                    title={t({ id: 'catalogacao.dup.title' })} onClick={() => setDupItem(it)}>
                    {t({ id: 'catalogacao.dup.check' })}
                  </button>
                )}
                {onEditItem && (
                  <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                    onClick={() => onEditItem(it._type, it.id)}>
                    {t({ id: 'catalogacao.queue.resume' })}
                  </button>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* ── Pagination (serveur) ─────────────────────── */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8, marginBottom: 20, fontSize: '.8rem', flexWrap: 'wrap' }}>
        <span style={{ color: 'var(--brand-muted, #999)' }}>
          {t({ id: 'catalogacao.queue.paginationInfo' }, { total, showing: items.length, page: page + 1, pages: totalPages })}
        </span>
        <div style={{ display: 'flex', gap: 6 }}>
          <button type="button" className="ab-button ab-button--secondary ab-button--sm"
            onClick={() => setPage(p => Math.max(0, p - 1))} disabled={page <= 0 || loading}>{t({ id: 'catalogacao.queue.prevPage' })}</button>
          <button type="button" className="ab-button ab-button--secondary ab-button--sm"
            onClick={() => setPage(p => Math.min(totalPages - 1, p + 1))} disabled={page >= totalPages - 1 || loading}>{t({ id: 'catalogacao.queue.nextPage' })}</button>
        </div>
      </div>

      {/* ═══════════════════════════════════════════════ */}
      {/*  TRASH                                          */}
      {/* ═══════════════════════════════════════════════ */}
      <div style={{ padding: 14, borderRadius: 10, background: 'rgba(220,38,38,.04)', border: '1px solid rgba(220,38,38,.12)' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10, flexWrap: 'wrap', gap: 6 }}>
          <div>
            <h4 style={{ margin: '0 0 4px', fontSize: '.9rem' }}>{t({ id: 'catalogacao.queue.trashTitle' })}</h4>
            <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #999)' }}>
              {t({ id: 'catalogacao.queue.trashDescription' })}
              {trashTotal > trash.length && (
                <> — {t({ id: 'catalogacao.queue.trashShowing' }, { shown: trash.length, total: trashTotal })}</>
              )}
            </div>
          </div>
          <div style={{ display: 'flex', gap: 6, alignItems: 'center', flexWrap: 'wrap' }}>
            {/* Le selecteur est colle au bouton rouge : on ne peut pas vider sans
                avoir la portee sous les yeux. */}
            <select value={trashBatch} onChange={e => setTrashBatch(e.target.value)}
              title={t({ id: 'catalogacao.queue.batchLabel' })}
              style={{ ...fs, width: 'auto', maxWidth: 220, fontSize: '.78rem', padding: '4px 8px' }}>
              <option value="">{t({ id: 'catalogacao.queue.allBatches' })}</option>
              <option value="none">{t({ id: 'catalogacao.queue.noBatch' })}</option>
              {lotsFiltrables.map(b => <option key={b.id} value={b.id}>{labelLot(b)}</option>)}
            </select>
            <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={loadTrash} disabled={trashLoading}>
              {trashLoading ? '…' : t({ id: 'catalogacao.queue.refreshShort' })}
            </button>
            {isCoord ? (
              <button type="button" className="ab-button ab-button--danger ab-button--sm"
                onClick={emptyTrash} disabled={!trash.length}>
                {t({ id: 'catalogacao.queue.emptyTrash' })}
              </button>
            ) : (
              <span style={{ fontSize: '.72rem', color: 'var(--brand-muted, #888)' }}>
                {t({ id: 'catalogacao.coordOnlyDelete' })}
              </span>
            )}
          </div>
        </div>

        {trash.length > 0 && (
          <>
            <div style={{ display: 'flex', gap: 6, alignItems: 'center', marginBottom: 8 }}>
              <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={selectAllTrash}>
                {trashSelected.size === trash.length ? t({ id: 'catalogacao.queue.deselectAll' }) : t({ id: 'catalogacao.queue.selectAllCount' }, { count: trash.length })}
              </button>
              <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={restoreTrashSelected} disabled={!trashSelected.size}>
                {t({ id: 'catalogacao.queue.restoreSelected' }, { count: trashSelected.size })}
              </button>
            </div>
            <div style={{ border: '1px solid rgba(255,255,255,.06)', borderRadius: 8, maxHeight: 200, overflowY: 'auto' }}>
              {trash.map((it, i) => {
                const key = `${it._type}:${it.id}`;
                return (
                  <div key={key} style={{
                    display: 'flex', alignItems: 'center', gap: 8, padding: '6px 10px',
                    background: trashSelected.has(key) ? 'rgba(220,38,38,.08)' : i % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent',
                    borderBottom: '1px solid rgba(255,255,255,.04)',
                  }}>
                    <input type="checkbox" checked={trashSelected.has(key)} onChange={() => toggleTrashSelect(key)} style={{ flexShrink: 0 }} />
                    <span className={`cat-pill ${it._type === 'book' ? 'info' : it._type === 'author' ? 'warn' : 'ok'}`}
                      style={{ fontSize: '.6rem', flexShrink: 0 }}>{t({ id: TYPE_KEYS[it._type] })}</span>
                    <div style={{ flex: 1, minWidth: 0, fontSize: '.82rem' }}>{it._label}{renderLib(it)}</div>
                    {isCoord && (
                      <button type="button" className="ab-button ab-button--danger ab-button--sm"
                        onClick={() => deleteTrashItem(it._type, it.id)}>{t({ id: 'catalogacao.queue.deletePermanent' })}</button>
                    )}
                  </div>
                );
              })}
            </div>
          </>
        )}
        {trash.length === 0 && (
          <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #888)', padding: 8 }}>{t({ id: 'catalogacao.queue.trashEmpty' })}</div>
        )}
        <div style={{ fontSize: '.7rem', color: '#ffe0e0', marginTop: 8 }}>
          {t({ id: 'catalogacao.queue.trashWarning' })}
        </div>

        {/* Journal des suppressions definitives — la contrepartie du bouton
            rouge : ce qu'il a emporte, et de quoi le rejouer. */}
        <details style={{ marginTop: 12 }}>
          <summary style={{ cursor: 'pointer', fontSize: '.82rem', color: 'var(--brand-muted, #aaa)' }}>
            {t({ id: 'catalogacao.queue.deletedTitle' })}{deleted.length ? ` (${deleted.length})` : ''}
          </summary>
          <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #999)', margin: '6px 0 8px' }}>
            {t({ id: 'catalogacao.queue.deletedDescription' })}
          </div>
          {deletedLoading && <div style={{ fontSize: '.8rem', padding: 6 }}>…</div>}
          {!deletedLoading && deleted.length === 0 && (
            <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #888)', padding: 8 }}>
              {t({ id: 'catalogacao.queue.deletedEmpty' })}
            </div>
          )}
          {deleted.map(it => (
            <div key={it.id} style={{
              display: 'flex', alignItems: 'center', gap: 8, padding: '5px 6px',
              borderBottom: '1px solid rgba(255,255,255,.06)', fontSize: '.8rem',
            }}>
              <span className="cat-pill" style={{ flexShrink: 0 }}>{t({ id: TYPE_KEYS[it.entity_type] || 'catalogacao.type.book' })}</span>
              <span style={{ flex: 1, minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {it.label || `#${it.entity_id}`}
                {it.details?.batch_id && (
                  <span style={{ color: 'var(--brand-muted, #888)' }}> · {t({ id: 'catalogacao.queue.batchPrefix' }, { id: it.details.batch_id })}</span>
                )}
              </span>
              <span style={{ color: 'var(--brand-muted, #888)', flexShrink: 0 }}>{formatDate(it.occurred_at)}</span>
              {it.details?.snapshot ? (
                <button type="button" className="ab-button ab-button--secondary ab-button--sm" style={{ flexShrink: 0 }}
                  onClick={() => restoreDeleted(it.id)}>
                  {t({ id: 'catalogacao.queue.restoreDeleted' })}
                </button>
              ) : (
                <span style={{ color: 'var(--brand-muted, #666)', flexShrink: 0, fontSize: '.72rem' }}>—</span>
              )}
            </div>
          ))}
        </details>
      </div>

      {dupItem && (
        <DuplicateCompareModal
          draftId={dupItem.id}
          draftLabel={dupItem._label}
          onClose={() => setDupItem(null)}
          onEditItem={onEditItem}
          onMerged={async () => {
            setMsg({ text: t({ id: 'catalogacao.dup.mergeOk' }), kind: 'ok' });
            await loadQueue(); await loadTrash(); onChanged?.();
          }}
        />
      )}
    </div>
  );
}
