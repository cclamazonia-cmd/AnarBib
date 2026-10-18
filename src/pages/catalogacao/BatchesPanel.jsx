// ═══════════════════════════════════════════════════════════════════════════
// AnarBib — le panneau des lots du catalogage (onglet « Lots »).
// E6 (19/10/2026) : sorti tel quel de CatalogacaoPage.jsx, qui en garde le
// montage ; aucune ligne du composant n'a été réécrite.
// ═══════════════════════════════════════════════════════════════════════════
import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useIntl } from 'react-intl';
import { useConfirm } from '@/contexts/ConfirmContext';
import { useSaveConfirmation } from '@/hooks/useSaveConfirmation';
import { useLibrary } from '@/contexts/LibraryContext';
import { useStaffLibraries, useCoordLibraries, bibliothequesProposables, bibliothequeDuLot, brouillonsDAutresBibliotheques, peutRouvrirRevision } from '@/lib/useStaffLibraries';
import BatchReviewReport from '@/components/catalog/BatchReviewReport';
import ContributorCandidates from '@/components/catalog/ContributorCandidates';
import CatalogStatusBar from '@/components/catalog/CatalogStatusBar';
import { publierLotParPages } from '@/lib/publicationParPages';

// ═══════════════════════════════════════════════════════════
// BatchesPanel — mini componente funcional de gestão de lotes
// ═══════════════════════════════════════════════════════════

// Libelles des etats d'un lot. La base accepte open | published | closed |
// cancelled | archived (CHECK catalog_batches_status_check, elargie le
// 29/08/2026) ; « open » et « archived » ont leur propre section, seuls les
// autres passent par la pastille.
// H34 lot 2 (IMP-36) : « publishing » = publication par pages en cours ; le lot
// reste dans la section des lots ouverts, avec « Reprendre la publication ».
const BATCH_STATUS_LABEL_IDS = {
  publishing: 'catalogacao.batch.status.publishing',
  published: 'catalogacao.published',
  closed: 'catalogacao.batch.status.closed',
  cancelled: 'catalogacao.cancelled',
};

// Les trois tables de brouillons rattachables a un lot.
const BATCH_DRAFT_TABLES = ['book_drafts', 'author_drafts', 'exemplar_drafts'];

// B30 : valeur du choix « Administration du réseau » à la création d'un lot
// (library_id nulle, réservée à l'administration du réseau).
const LOT_RESEAU = '__reseau__';

// H21 lot 0 (REGISTRE IMP-27 b, 29/09/2026) : l'approbation d'un tour couvre
// les brouillons que ce tour a soumis, figés à la demande. Un brouillon rangé
// ensuite dans le lot attend un nouveau tour (publish_book_draft et
// publish_exemplar_draft : HINT error.publish.added_after_review) ;
// fn_batch_reviews_list les compte (after_review) sur le dernier tour
// approuvé. Colonne absente (écran publié avant la migration) : 0, rien ne
// s'affiche et rien ne se verrouille de plus.
function ajoutsApresRevision(r) {
  return r?.imported && r.status === 'approved' ? Number(r.after_review) || 0 : 0;
}

export default function BatchesPanel({ batches, onRefresh, isCoord, isNetworkAdmin }) {
  const { formatMessage: t } = useIntl();
  const confirmer = useConfirm();
  const { libraryId } = useLibrary();
  const [creating, setCreating] = useState(false);
  const [newName, setNewName] = useState('');
  const [newNotes, setNewNotes] = useState('');
  // null = pas encore choisie : la valeur par défaut (bibliothèque active, ou
  // seule bibliothèque de staff) s'applique ; '' = à choisir.
  const [newLibraryId, setNewLibraryId] = useState(null);
  const [msg, setMsg] = useState(null);
  // Un geste réussi se dit dans la barre d'état, doublé d'un toast.
  const confirmSaved = useSaveConfirmation(setMsg);

  // ── B30 (27/09/2026) : le lot a SA bibliothèque ─────────────────────
  // catalog_batches.library_id (nulle = lot de l'administration du réseau)
  // décide de qui voit et agit sur le lot : staff de cette bibliothèque pour
  // le modifier (publier, fermer, archiver, cotes, classes, rapport),
  // coordination de cette bibliothèque pour le supprimer ou en demander la
  // révision. Les deux prédicats ci-dessous ne font que l'affichage ; la base
  // (politiques de catalog_batches, RPC) reste l'autorité. Tant que les listes
  // ne sont pas chargées — ou que la colonne n'existe pas encore (écran publié
  // avant la migration : library_id undefined) —, on garde l'affichage d'avant.
  const { staffLibraryIds, loaded: staffConnu } = useStaffLibraries();
  const { coordLibraryIds, loaded: coordConnu } = useCoordLibraries();
  function peutModifier(b, avant = true) {
    if (isNetworkAdmin) return true;
    if (!staffConnu || b.library_id === undefined) return avant;
    return b.library_id != null && staffLibraryIds.includes(b.library_id);
  }
  function coordonne(b) {
    if (isNetworkAdmin) return true;
    if (!coordConnu || b.library_id === undefined) return isCoord;
    return b.library_id != null && coordLibraryIds.includes(b.library_id);
  }

  // ── Revision des lots importes (05/09/2026) ──────────────────────────
  // Un lot ne d'un import ne se publie qu'apres une revision approuvee par
  // l'administration du reseau (garde dans publish_book_draft, HINT
  // error.publish.review_required). Le rapport est lisible ICI, avant la
  // demande : la coordination corrige d'abord ce qu'elle peut. Le grisage du
  // bouton Publier est une politesse ; la RPC reste l'autorite.
  const [reviews, setReviews] = useState({});           // batch_id -> dernier tour
  const [reportModal, setReportModal] = useState(null); // { batch, report, loading }
  const loadReviews = useCallback(async () => {
    try {
      const { data, error } = await supabase.rpc('fn_batch_reviews_list');
      if (error) throw error;
      const map = {};
      (data || []).forEach(r => { map[r.batch_id] = r; });
      setReviews(map);
    } catch { /* la colonne reste muette, la garde en base tient */ }
  }, []);
  useEffect(() => { loadReviews(); }, [loadReviews, batches]);

  // ── A qui appartient le lot (15/09/2026) ─────────────────────────────
  // La creation des brouillons d'un import ne posait jamais de biblio
  // proprietaire, et la publication retombait sur la biblio de qui publie.
  // Le lot Solidaires (1673 brouillons) n'avait aucun geste pour etre
  // rattache a sa biblio, creee le 14/09. Desormais fn_import_promote
  // tamponne la biblio a la promotion, l'ecran montre « sans bibliotheque »
  // AVANT la publication, et l'administration du reseau reattribue un lot
  // entier ici (fn_batch_reassign_library : brouillons en cours seulement,
  // fiches publiees intactes, source d'import alignee, trace dans les notes).
  const [owners, setOwners] = useState({});             // batch_id -> [{ library_id, library_name, drafts }]
  const [reassign, setReassign] = useState(null);       // { batch, libraryId }
  const [reassigning, setReassigning] = useState(false);
  const [libraries, setLibraries] = useState([]);
  const loadOwners = useCallback(async () => {
    try {
      const { data, error } = await supabase.rpc('fn_batch_owner_libraries');
      if (error) throw error;
      const map = {};
      (data || []).forEach(r => { (map[r.batch_id] = map[r.batch_id] || []).push(r); });
      setOwners(map);
    } catch { /* la colonne reste muette ; la regle de destination est en base */ }
  }, []);
  useEffect(() => { loadOwners(); }, [loadOwners, batches]);
  // B30 : la liste des bibliothèques sert dès l'ouverture — choisir la
  // bibliothèque d'un lot à sa création, puis en changer (administration).
  useEffect(() => {
    let vivant = true;
    supabase.from('libraries').select('id, name, short_name, is_active').order('name').then(({ data, error }) => {
      if (vivant && !error && data) setLibraries(data);
    });
    return () => { vivant = false; };
  }, []);

  // B30 : la colonne « Bibliothèque » nomme la bibliothèque DU LOT (nulle :
  // administration du réseau). fn_batch_owner_libraries ne sert plus qu'au
  // contrôle : des brouillons en cours d'une AUTRE bibliothèque (rangés avant
  // la règle) se signalent en ambre. Une notice sans owner_library_id (d'avant
  // B29) ne compte pas : la fonction rend la colonne brute, non résolue, et sa
  // bibliothèque réelle (celle de son créateur) est souvent celle du lot.
  function brouillonsAutres(b) {
    return b ? brouillonsDAutresBibliotheques(b, owners[b.id]) : 0;
  }
  function renderLibrary(b) {
    const nom = bibliothequeDuLot(b, t);
    const autres = brouillonsAutres(b);
    return (
      <span style={{ display: 'inline-flex', flexDirection: 'column', gap: 2 }}>
        {nom
          ? (
            <span style={b.library_id === null ? { color: 'var(--brand-muted, #aaa)' } : undefined}
              title={b.library_id === null ? t({ id: 'catalogacao.batch.library.noneHint' }) : undefined}>
              {nom}
            </span>
          )
          : <span style={{ color: 'var(--brand-muted, #666)' }}>—</span>}
        {autres > 0 && (
          <span style={{ color: '#fbbf24' }} title={t({ id: 'catalogacao.batch.library.mismatchHint' })}>
            {t({ id: 'catalogacao.batch.library.mismatch' }, { count: autres })}
          </span>
        )}
      </span>
    );
  }

  // ── Cotes manquantes et classes de rangement d'un lot (E21, 15/09/2026) ──
  // publish_book_draft refuse tout brouillon sans cote, et le formulaire ne
  // la genere qu'une notice a la fois : un lot importe en recoit ici en un
  // geste, dans l'ordre du lot, a la suite de la serie de sa bibliotheque
  // (fn_batch_assign_bib_refs : apercu, puis application). Et le numero
  // d'inventaire ne range rien : c'est la classe (champ cdd) qui fait la cote
  // de rangement de l'etiquette — la rubrique laissee par l'import se reporte
  // dans la classe par une table rubrique -> code relue par la coordination
  // (fn_batch_rubrics / fn_batch_apply_rubric_classes).
  const [bibRefs, setBibRefs] = useState(null);     // { batch, preview, loading, applying }
  const [rubrics, setRubrics] = useState(null);     // { batch, rows, map, overwrite, loading, applying }

  async function openBibRefs(b) {
    setBibRefs({ batch: b, preview: null, loading: true, applying: false });
    try {
      const { data, error } = await supabase.rpc('fn_batch_assign_bib_refs', { p_batch_id: Number(b.id), p_apply: false });
      if (error) throw error;
      setBibRefs({ batch: b, preview: data, loading: false, applying: false });
    } catch (err) {
      setBibRefs(null);
      setMsg({ text: localizeError(err, t), kind: 'error' });
    }
  }

  async function applyBibRefs() {
    if (!bibRefs?.batch) return;
    setBibRefs(prev => ({ ...prev, applying: true }));
    try {
      const { data, error } = await supabase.rpc('fn_batch_assign_bib_refs', { p_batch_id: Number(bibRefs.batch.id), p_apply: true });
      if (error) throw error;
      setMsg({ text: t({ id: 'catalogacao.batch.bibrefs.ok' }, { count: Number(data?.updated ?? 0), first: data?.first || '', last: data?.last || '' }), kind: 'ok' });
      setBibRefs(null);
      onRefresh();
    } catch (err) {
      setBibRefs(prev => (prev ? { ...prev, applying: false } : prev));
      setMsg({ text: localizeError(err, t), kind: 'error' });
    }
  }

  async function openRubrics(b) {
    setRubrics({ batch: b, rows: [], map: {}, overwrite: false, loading: true, applying: false });
    try {
      const { data, error } = await supabase.rpc('fn_batch_rubrics', { p_batch_id: Number(b.id) });
      if (error) throw error;
      setRubrics({ batch: b, rows: data || [], map: {}, overwrite: false, loading: false, applying: false });
    } catch (err) {
      setRubrics(null);
      setMsg({ text: localizeError(err, t), kind: 'error' });
    }
  }

  async function applyRubrics() {
    if (!rubrics?.batch) return;
    const map = {};
    Object.entries(rubrics.map).forEach(([k, v]) => { if (String(v || '').trim()) map[k] = String(v).trim(); });
    if (Object.keys(map).length === 0) return;
    setRubrics(prev => ({ ...prev, applying: true }));
    try {
      const { data, error } = await supabase.rpc('fn_batch_apply_rubric_classes', {
        p_batch_id: Number(rubrics.batch.id), p_map: map, p_overwrite: rubrics.overwrite === true,
      });
      if (error) throw error;
      setMsg({ text: t({ id: 'catalogacao.batch.rubrics.ok' }, {
        updated: Number(data?.updated ?? 0), kept: Number(data?.skipped_has_class ?? 0), unmapped: Number(data?.skipped_unmapped ?? 0),
      }), kind: 'ok' });
      setRubrics(null);
      onRefresh();
    } catch (err) {
      setRubrics(prev => (prev ? { ...prev, applying: false } : prev));
      setMsg({ text: localizeError(err, t), kind: 'error' });
    }
  }

  // B30 : « Changer la bibliothèque du lot » est LE geste qui change
  // catalog_batches.library_id (la colonne est figée pour l'API). Un lot vide
  // change aussi de bibliothèque : le message nomme la nouvelle bibliothèque
  // même quand aucun brouillon n'a bougé. Même bibliothèque : rien à faire,
  // sauf s'il reste des brouillons en cours d'une autre bibliothèque — le
  // geste les rattache alors à celle du lot.
  function reassignInchange(r) {
    if (!r?.libraryId) return true;
    return r.libraryId === (r.batch.library_id || '') && brouillonsAutres(r.batch) === 0;
  }

  async function submitReassign() {
    if (!reassign?.libraryId || reassignInchange(reassign)) return;
    setReassigning(true);
    setMsg(null);
    try {
      const { data, error } = await supabase.rpc('fn_batch_reassign_library', {
        p_batch_id: Number(reassign.batch.id), p_library_id: reassign.libraryId,
      });
      if (error) throw error;
      const warnings = Array.isArray(data?.warnings) ? data.warnings : [];
      const choisie = libraries.find(l => l.id === reassign.libraryId);
      const parts = [t({ id: 'catalogacao.batch.reassign.okBatch' }, {
        name: reassign.batch.name,
        library: data?.library_name || choisie?.name || '',
        count: Number(data?.drafts_updated ?? 0),
      })];
      // Des avertissements, pas des refus : reattribuer et preparer la biblio
      // (serie de tombos, activation) sont deux responsabilites.
      if (warnings.includes('library_without_tombo_pattern')) parts.push(t({ id: 'catalogacao.batch.reassign.warn.tombo' }));
      if (warnings.includes('library_inactive')) parts.push(t({ id: 'catalogacao.batch.reassign.warn.inactive' }));
      // B29 : les exemplaires saisis d'une autre bibliothèque sortent du lot.
      if (warnings.includes('items_detached')) parts.push(t({ id: 'catalogacao.batch.reassign.warn.itemsDetached' }, { count: Number(data?.items_detached ?? 0) }));
      // B30 : les autorités d'une personne qui n'est pas staff de la nouvelle bibliothèque aussi.
      if (warnings.includes('authors_detached')) parts.push(t({ id: 'catalogacao.batch.reassign.warn.authorsDetached' }, { count: Number(data?.authors_detached ?? 0) }));
      setMsg({ text: parts.join(' '), kind: 'ok' });
      setReassign(null);
      await loadOwners();
      onRefresh();
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally {
      setReassigning(false);
    }
  }

  function reviewLocked(b) {
    const r = reviews[b.id];
    // IMP-27 (b) : approuvé, mais des brouillons sont entrés après la demande —
    // le lot attend un nouveau tour.
    return !!r && r.imported && (r.status !== 'approved' || ajoutsApresRevision(r) > 0);
  }

  async function openReport(b) {
    setReportModal({ batch: b, report: null, loading: true });
    try {
      const { data, error } = await supabase.rpc('fn_batch_review_report', { p_batch_id: Number(b.id) });
      if (error) throw error;
      setReportModal({ batch: b, report: data, loading: false });
    } catch (err) {
      setReportModal(null);
      setMsg({ text: localizeError(err, t), kind: 'error' });
    }
  }

  // B30 : rouvrir = un nouveau tour sur un lot approuvé (administration seule) —
  // la sortie qu'annonce error.batch.reassign.review_approved.
  async function requestReview(b, rouvrir = false) {
    if (rouvrir && !(await confirmer({ message: t({ id: 'catalogacao.batch.review.reopenConfirm' }, { name: b.name }), confirmLabel: t({ id: 'confirm.action.reopenReview' }) }))) return;
    const message = window.prompt(t({ id: 'catalogacao.batch.review.requestPrompt' }), '');
    if (message === null) return;
    try {
      const { error } = await supabase.rpc('fn_batch_review_request', {
        p_batch_id: Number(b.id), p_message: message.trim() || null,
      });
      if (error) throw error;
      setMsg({ text: t({ id: 'catalogacao.batch.review.requested.ok' }, { name: b.name }), kind: 'ok' });
      await loadReviews();
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    }
  }

  function renderReview(b) {
    const r = reviews[b.id];
    if (!r || !r.imported) return <span style={{ color: 'var(--brand-muted, #666)' }}>{t({ id: 'catalogacao.batch.review.notImported' })}</span>;
    const color = r.status === 'approved' ? '#4ade80'
      : r.status === 'changes_requested' ? '#fbbf24'
        : r.status === 'requested' ? '#60a5fa' : 'var(--brand-muted, #aaa)';
    const label = !r.status ? t({ id: 'catalogacao.batch.review.none' })
      : r.status === 'requested' ? t({ id: 'catalogacao.batch.review.requested' }, { date: formatDate(r.requested_at) })
        : t({ id: `catalogacao.batch.review.${r.status}` });
    const ajouts = ajoutsApresRevision(r);
    return (
      <span style={{ display: 'inline-flex', flexDirection: 'column', gap: 2 }}>
        <span style={{ color }}>{label}</span>
        {ajouts > 0 && (
          <span data-after-review={ajouts} style={{ fontSize: '.74rem', color: '#fbbf24' }}>
            {t({ id: 'catalogacao.batch.review.afterReview' }, { n: ajouts })}
          </span>
        )}
        {r.status === 'changes_requested' && r.admin_notes && (
          <span style={{ fontSize: '.74rem', color: 'var(--brand-muted, #aaa)' }} title={r.admin_notes}>
            {t({ id: 'catalogacao.batch.review.adminNotes' })} : {r.admin_notes}
          </span>
        )}
      </span>
    );
  }

  // ── B30 : bibliothèque d'un lot neuf ────────────────────────────────
  // Staff d'une seule bibliothèque : fixée (affichée). Plusieurs : à choisir
  // parmi ses bibliothèques de staff, la bibliothèque active présélectionnée
  // si elle en fait partie. Administration du réseau : toutes, plus
  // « Administration du réseau » (library_id nulle). La politique d'INSERT
  // refuse une bibliothèque hors de ses adhésions de staff (localizeError :
  // error.batch.library_not_yours).
  const bibsCreation = isNetworkAdmin
    ? libraries
    : bibliothequesProposables(libraries, { isNetworkAdmin: false, staffLibraryIds });
  const bibCreationFixee = !isNetworkAdmin && staffConnu && staffLibraryIds.length === 1 ? staffLibraryIds[0] : null;
  const bibCreationDefaut = bibCreationFixee
    || (libraryId && (isNetworkAdmin || staffLibraryIds.includes(libraryId)) ? libraryId : '');
  const bibCreation = bibCreationFixee || (newLibraryId ?? bibCreationDefaut);
  const creationPrete = isNetworkAdmin || staffConnu;

  async function createBatch() {
    if (!newName.trim()) { setMsg({text: t({id:'catalogacao.batchNameRequired'}), kind:'error'}); return; }
    if (!creationPrete) return;
    if (!bibCreation) { setMsg({text: t({id:'catalogacao.batch.libraryRequired'}), kind:'error'}); return; }
    setCreating(true);
    setMsg(null);
    try {
      const lot = {
        name: newName.trim(),
        notes: newNotes.trim() || null,
        status: 'open',
      };
      let { error } = await supabase.from('catalog_batches').insert({
        ...lot,
        library_id: bibCreation === LOT_RESEAU ? null : bibCreation,
      });
      // PGRST204 : colonne pas encore là (écran publié avant la migration B30).
      if (error?.code === 'PGRST204' && /library_id/.test(error.message || '')) {
        ({ error } = await supabase.from('catalog_batches').insert(lot));
      }
      if (error) throw error;
      setNewName('');
      setNewNotes('');
      setNewLibraryId(null);
      setMsg({text: t({id:'common.dataSaved'}), kind:'ok'});
      onRefresh();
    } catch (err) {
      setMsg({text: t({id:'common.errorPrefix'},{message:localizeError(err, t)}), kind:'error'});
    } finally {
      setCreating(false);
    }
  }

  async function closeBatch(id) {
    if (!(await confirmer({ message: t({id:'catalogacao.closeBatchConfirm'}), confirmLabel: t({ id: 'confirm.action.closeBatch' }) }))) return;
    try {
      const { data, error } = await supabase.from('catalog_batches')
        .update({ status: 'closed' })
        .eq('id', id).select('id');
      if (error) throw error;
      // B30 : un lot d'une bibliothèque où l'on n'est pas staff (ou de
      // l'administration du réseau) ne se ferme pas — la base filtre, on le dit.
      if (!data?.length) setMsg({ text: t({id:'catalogacao.batchUpdateNothing'}), kind: 'warn' });
      else confirmSaved(t({ id: 'catalogacao.batch.closedDone' }));
      onRefresh();
    } catch (err) {
      setMsg({ text: t({id:'common.errorPrefix'},{message:localizeError(err, t)}), kind: 'error' });
    }
  }

  // H34 lot 2 (REGISTRE IMP-36) : la base publie au plus une page par appel
  // (60 notices et 400 exemplaires ; une notice et ses exemplaires ne se
  // séparent jamais) ; le geste enchaîne les appels jusqu'au bout et montre
  // l'avancement. Une page refusée n'écrit rien : on dit ce qui a été publié,
  // puis le refus, puis comment reprendre (le lot reste « publishing »).
  const [publication, setPublication] = useState(null);   // batch_id en cours
  async function publishBatch(id, reprise = false) {
    const confirmId = reprise ? 'catalogacao.batch.publication.resumeConfirm' : 'catalogacao.publishBatchConfirm';
    if (!(await confirmer({ message: t({ id: confirmId }), confirmLabel: t({ id: 'confirm.action.publishBatch' }), tone: 'danger' }))) return;
    setPublication(id);
    try {
      const res = await publierLotParPages(async () => {
        const { data, error } = await supabase.rpc('publish_catalog_batch', { p_batch_id: Number(id) });
        if (error) throw error;
        return data;
      }, {
        surPage: ({ page, notices, total }) => {
          setMsg({ text: t({ id: 'catalogacao.batch.publication.progress' }, { page, notices, total: Math.max(total, notices) }), kind: 'info' });
        },
      });
      if (res.ok) {
        confirmSaved(res.pages > 1
          ? t({ id: 'catalogacao.batch.publication.donePages' }, { pages: res.pages, notices: res.notices, exemplaires: res.exemplaires })
          : t({ id: 'catalogacao.batch.publishedDone' }));
      } else {
        const refus = t({ id: 'common.errorPrefix' }, { message: localizeError(res.erreur, t) });
        const parts = [];
        if (res.pages > 0) {
          parts.push(t({ id: 'catalogacao.batch.publication.beforeRefusal' }, { pages: res.pages, notices: res.notices, exemplaires: res.exemplaires }));
        }
        parts.push(refus);
        if (res.pages > 0 || reprise) parts.push(t({ id: 'catalogacao.batch.publication.howToResume' }));
        setMsg({ text: parts.join(' '), kind: 'error' });
      }
      onRefresh();
    } finally {
      setPublication(null);
    }
  }

  async function archiveBatch(id) {
    if (!(await confirmer({ message: t({id:'catalogacao.archiveBatchConfirm'}), confirmLabel: t({ id: 'confirm.action.archive' }) }))) return;
    try {
      const { data, error } = await supabase.from('catalog_batches')
        .update({ status: 'archived' })
        .eq('id', id).select('id');
      if (error) throw error;
      if (!data?.length) setMsg({ text: t({id:'catalogacao.batchUpdateNothing'}), kind: 'warn' });   // B29
      else confirmSaved(t({ id: 'catalogacao.batch.archivedDone' }));
      onRefresh();
    } catch (err) {
      setMsg({ text: t({id:'common.errorPrefix'},{message:localizeError(err, t)}), kind: 'error' });
    }
  }

  // Un lot ne se supprime que s'il ne retient plus de travail. Un brouillon MIS
  // A LA CORBEILLE (status='cancelled') n'en est pas : le compter comme bloquant
  // rendait le lot indestructible, parce que la corbeille de la file editoriale
  // est globale — elle ne se filtre ni ne se vide lot par lot, et son affichage
  // est plafonne. Vecu le 28/08/2026 sur le lot CIRA Marseille : 237 brouillons
  // jetes a la corbeille, 0 actif, et « ce lot contient encore 237 brouillons ».
  // Ils sont donc supprimes AVEC le lot, apres une confirmation qui les compte.
  async function deleteBatch(id) {
    if (!(await confirmer({ message: t({id:'catalogacao.deleteBatchConfirm'}), confirmLabel: t({ id: 'confirm.action.deleteForever' }), tone: 'danger' }))) return;
    try {
      // Les comptes viennent de la vue, une seule definition — la meme que celle
      // du trigger qui refusera en base si on passe outre.
      const { data: c } = await supabase.from('v_catalog_batch_draft_counts')
        .select('en_cours, publies, corbeille').eq('batch_id', id).maybeSingle();
      // B30 : la vue ne compte que ce qu'on voit ; le garde de suppression
      // compte TOUT le lot (fiches publiées d'une autre bibliothèque avant une
      // réattribution, IMP-20 c). fn_batch_delete_blockers donne ses comptes à
      // la coordination du lot (aucune ligne sinon : les RPC ci-dessous le disent).
      const { data: bloq, error: eBloq } = await supabase
        .rpc('fn_batch_delete_blockers', { p_batch_id: Number(id) }).maybeSingle();
      if (eBloq && eBloq.code !== 'PGRST202') throw eBloq;
      const enCours = Number((bloq ?? c)?.en_cours ?? 0);
      const publies = Number((bloq ?? c)?.publies ?? 0);
      const jetes = Number(c?.corbeille ?? 0);

      // Du travail vivant : le traiter ou le jeter, pas l'effacer par la bande.
      if (enCours > 0) {
        setMsg({ text: t({id:'catalogacao.batchHasDrafts'},{count: enCours}), kind: 'warn' });
        return;
      }
      // Des fiches publiees : le lot est la memoire d'une seance. On archive.
      // Sans ce message distinct, on lisait « supprimez les brouillons d'abord »
      // pour des fiches qui sont au catalogue depuis deux semaines.
      if (publies > 0) {
        setMsg({ text: t({id:'catalogacao.batchPublishedArchiveInstead'},{count: publies}), kind: 'warn' });
        return;
      }
      // B30 : supprimer un lot revient à la coordination de SA bibliothèque
      // (ou à l'administration du réseau) — le savoir AVANT d'avoir vidé sa
      // corbeille pour rien. Les deux RPC lisent désormais la bibliothèque du
      // lot ; elles restent la vérité, le bouton n'est qu'un affichage.
      const [{ data: aMoi, error: eOwn }, { data: coord, error: eCoord }] = await Promise.all([
        supabase.rpc('fn_caller_owns_batch', { p_batch_id: Number(id) }),
        supabase.rpc('fn_caller_coordinates_batch', { p_batch_id: Number(id) }),
      ]);
      // (PGRST202 : fonction pas encore là — l'écran est publié avant la
      // migration ; la base, alors, n'applique pas encore B29 non plus.)
      if (eOwn && eOwn.code !== 'PGRST202') throw eOwn;
      if (eCoord && eCoord.code !== 'PGRST202') throw eCoord;
      if (aMoi === false || coord === false) { setMsg({ text: t({id:'catalogacao.batchDeleteNothing'}), kind: 'warn' }); return; }
      if (jetes > 0 && !(await confirmer({ message: t({id:'catalogacao.batchTrashedWillBeDeleted'},{count: jetes}), confirmLabel: t({ id: 'confirm.action.deleteForever' }), tone: 'danger' }))) return;

      // Une requete par table, pas une par ligne : PostgREST filtre le DELETE
      // cote serveur, sous exactement les memes policies que la suppression a
      // l'unite depuis la corbeille. B29 : ce qui RESTE a la corbeille du lot
      // (jetes d'une autre bibliotheque ou d'une autre personne) est recompte
      // apres coup — une somme des lignes supprimees manquerait les exemplaires
      // importes, partis en cascade avec leur notice.
      let restants = 0;
      if (jetes > 0) {
        for (const table of BATCH_DRAFT_TABLES) {
          const { error } = await supabase.from(table).delete()
            .eq('batch_id', id).eq('status', 'cancelled');
          if (error) throw error;
        }
        const { data: c2 } = await supabase.from('v_catalog_batch_draft_counts')
          .select('corbeille').eq('batch_id', id).maybeSingle();
        restants = Number(c2?.corbeille ?? 0);
      }
      const { data: suppr, error } = await supabase.from('catalog_batches')
        .delete()
        .eq('id', id).select('id');
      if (error) throw error;
      // B29/B30 : une personne qui ne coordonne pas la bibliothèque du lot, ou
      // un lot qui porte encore des fiches d'autres bibliothèques (comptes
      // ci-dessus : nos brouillons seulement), et la base ne supprime rien — le dire.
      if (!suppr?.length) setMsg({ text: t({id:'catalogacao.batchDeleteNothing'}), kind: 'warn' });
      else if (restants > 0) setMsg({ text: t({id:'catalogacao.batchTrashedLeft'},{count: restants}), kind: 'warn' });
      else confirmSaved(t({ id: 'catalogacao.batch.deletedDone' }));
      onRefresh();
    } catch (err) {
      setMsg({ text: t({id:'common.errorPrefix'},{message:localizeError(err, t)}), kind: 'error' });
    }
  }

  // H34 lot 2 : un lot « publishing » (publication par pages en cours) reste
  // parmi les ouverts — on y reprend la publication.
  const enPublication = (b) => b.status === 'publishing';
  const openBatches = batches.filter(b => b.status === 'open' || enPublication(b));
  const closedBatches = batches.filter(b => b.status !== 'open' && !enPublication(b) && b.status !== 'archived');
  const archivedBatches = batches.filter(b => b.status === 'archived');

  function statusLabel(status) {
    const id = BATCH_STATUS_LABEL_IDS[status];
    return id ? t({ id }) : status;
  }

  // Ce que le lot retient. Un lot a zero est supprimable : le montrer evite
  // d'avoir a cliquer pour lire l'alerte de refus.
  // TROIS comptes, pas un total. Un seul nombre melangeait le travail en cours,
  // les fiches deja publiees et la corbeille — et faisait refuser une suppression
  // en annoncant des « brouillons » que la file editoriale ne montrait pas
  // (lot Mutirão du 15/08 : 0 en cours, 9 publies, et un refus incomprehensible).
  function renderCounts(b) {
    const enCours = b._enCours ?? 0;
    const publies = b._publies ?? 0;
    const corbeille = b._corbeille ?? 0;
    if (!enCours && !publies && !corbeille) return <span style={{ color: 'var(--brand-muted, #666)' }}>—</span>;
    const secondaire = { color: 'var(--brand-muted, #888)', fontSize: '.78rem' };
    const parts = [];
    if (enCours > 0) parts.push(<span key="c">{t({ id: 'catalogacao.batch.draftsInProgress' }, { count: enCours })}</span>);
    if (publies > 0) parts.push(<span key="p" style={secondaire}>{t({ id: 'catalogacao.batch.draftsPublished' }, { count: publies })}</span>);
    if (corbeille > 0) parts.push(<span key="t" style={secondaire}>{t({ id: 'catalogacao.batch.draftsTrashed' }, { count: corbeille })}</span>);
    return parts.map((p, i) => <span key={i}>{i > 0 ? ' · ' : ''}{p}</span>);
  }

  // Un lot qui ne retient RIEN n'a pas besoin d'etre ferme avant d'etre
  // supprime : le detour par « Fermer » est ce qui a fait croire, le 29/08,
  // qu'un lot ferme etait un lot supprime.
  //
  // La CORBEILLE ne compte pas : elle part avec le lot. Les PUBLIES, si — un lot
  // publie garde la memoire d'une seance de catalogage, il s'archive (decision du
  // 30/08). Meme regle que le trigger fn_guard_catalog_batch_delete, qui la tient
  // en base ; ici c'est du confort d'ecran, pas la garantie.
  function estVide(b) { return (b._enCours ?? 0) === 0 && (b._publies ?? 0) === 0; }

  function formatDate(v) {
    if (!v) return '—';
    try { return new Date(v).toLocaleDateString(); } catch { return v; }
  }

  return (
    <div>
      {/* Créer un lote */}
      <div style={{
        padding: 16, marginBottom: 16, borderRadius: 10,
        background: 'var(--brand-panel-bg, rgba(16,16,16,.86))',
        border: '1px solid var(--brand-panel-border, rgba(255,255,255,.1))',
      }}>
        <h4 style={{ margin: '0 0 10px', fontSize: '.9rem', fontWeight: 700 }}>{t({id:'catalogacao.batch.createTitle'})}</h4>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'flex-end' }}>
          <div style={{ flex: '1 1 200px' }}>
            <label style={{ fontSize: '.75rem', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batchName'})}</label>
            <input
              type="text" value={newName} onChange={e => setNewName(e.target.value)}
              placeholder={t({id:'catalogacao.batchNamePlaceholder'})}
              style={{
                width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)',
                background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem',
              }}
            />
          </div>
          <div style={{ flex: '1 1 200px' }}>
            <label style={{ fontSize: '.75rem', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batch.notesLabel'})}</label>
            <input
              type="text" value={newNotes} onChange={e => setNewNotes(e.target.value)}
              placeholder={t({id:'catalogacao.batchNotesPlaceholder'})}
              style={{
                width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)',
                background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem',
              }}
            />
          </div>
          {/* B30 : la bibliothèque du lot (fixée si l'on n'est staff que d'une seule) */}
          <div style={{ flex: '1 1 200px' }}>
            <label style={{ fontSize: '.75rem', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batch.libraryLabel'})}</label>
            {bibCreationFixee ? (
              <div style={{ padding: '7px 10px', fontSize: '.85rem' }}>
                {(() => { const l = libraries.find(x => x.id === bibCreationFixee); return l ? l.name : t({ id: 'common.loading' }); })()}
              </div>
            ) : (
              <select value={bibCreation} onChange={e => setNewLibraryId(e.target.value)} disabled={!creationPrete}
                style={{
                  width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)',
                  background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem',
                }}>
                <option value="">{t({ id: 'catalogacao.batch.reassign.pickPlaceholder' })}</option>
                {isNetworkAdmin && <option value={LOT_RESEAU}>{t({ id: 'catalogacao.batch.library.network' })}</option>}
                {bibsCreation.map(l => (
                  <option key={l.id} value={l.id}>
                    {l.name}{l.is_active === false ? ' ' + t({ id: 'catalogacao.batch.reassign.libraryInactive' }) : ''}
                  </option>
                ))}
              </select>
            )}
          </div>
          <button className="ab-button" onClick={createBatch} disabled={creating || !creationPrete}>
            {creating ? t({id:'common.saving'}) : t({id:'catalogacao.createBatch'})}
          </button>
        </div>
        <CatalogStatusBar msg={msg} onClose={() => setMsg(null)} />
      </div>

      {/* Rapport de revision d'un lot (lisible avant la demande) */}
      {reportModal && (
        <div role="dialog" aria-modal="true" onClick={() => setReportModal(null)}
          style={{ position: 'fixed', inset: 0, zIndex: 1000, background: 'rgba(0,0,0,.6)', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16 }}>
          <div onClick={e => e.stopPropagation()}
            style={{ maxWidth: 760, width: '100%', maxHeight: '85vh', overflow: 'auto', padding: 18, borderRadius: 12, background: 'var(--brand-panel-bg, #161616)', border: '1px solid var(--brand-panel-border, rgba(255,255,255,.12))' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 10, marginBottom: 10 }}>
              <h4 style={{ margin: 0, fontSize: '.95rem' }}>{t({ id: 'review.report.title' })} — {reportModal.batch.name}</h4>
              <button className="ab-button ab-button--ghost" style={{ fontSize: '.75rem', padding: '4px 10px' }} onClick={() => setReportModal(null)}>{t({ id: 'common.close' })}</button>
            </div>
            {reportModal.loading ? <p style={{ color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'common.loading' })}</p> : <BatchReviewReport report={reportModal.report} />}
            {/* H18 : les rapprochements d'autorité se proposent ici, jamais d'office. */}
            {!reportModal.loading && reportModal.batch?.id && <ContributorCandidates batchId={reportModal.batch.id} />}
          </div>
        </div>
      )}

      {/* Cotes manquantes d'un lot : apercu puis application (E21) */}
      {bibRefs && (
        <div role="dialog" aria-modal="true" onClick={() => !bibRefs.applying && setBibRefs(null)}
          style={{ position: 'fixed', inset: 0, zIndex: 1000, background: 'rgba(0,0,0,.6)', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16 }}>
          <div onClick={e => e.stopPropagation()}
            style={{ maxWidth: 520, width: '100%', padding: 18, borderRadius: 12, background: 'var(--brand-panel-bg, #161616)', border: '1px solid var(--brand-panel-border, rgba(255,255,255,.12))' }}>
            <h4 style={{ margin: '0 0 8px', fontSize: '.95rem' }}>{t({ id: 'catalogacao.batch.bibrefs.title' })}</h4>
            {bibRefs.loading ? (
              <p style={{ color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'common.loading' })}</p>
            ) : Number(bibRefs.preview?.candidates ?? 0) === 0 ? (
              <p style={{ fontSize: '.85rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.batch.bibrefs.none' })}</p>
            ) : (
              <p style={{ margin: '0 0 12px', fontSize: '.85rem' }}>
                {t({ id: 'catalogacao.batch.bibrefs.preview' }, {
                  count: Number(bibRefs.preview.candidates), name: bibRefs.batch.name,
                  library: bibRefs.preview.library_name || '', first: bibRefs.preview.first, last: bibRefs.preview.last,
                })}
              </p>
            )}
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 14 }}>
              <button className="ab-button ab-button--ghost" style={{ fontSize: '.8rem', padding: '6px 12px' }}
                disabled={bibRefs.applying} onClick={() => setBibRefs(null)}>{t({ id: 'common.cancel' })}</button>
              {Number(bibRefs.preview?.candidates ?? 0) > 0 && (
                <button className="ab-button ab-button--secondary" style={{ fontSize: '.8rem', padding: '6px 12px' }}
                  disabled={bibRefs.applying || bibRefs.loading} onClick={applyBibRefs}>
                  {bibRefs.applying ? t({ id: 'common.saving' }) : t({ id: 'catalogacao.batch.bibrefs.apply' })}
                </button>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Classes de rangement depuis les rubriques du lot (E21, voie 2) */}
      {rubrics && (
        <div role="dialog" aria-modal="true" onClick={() => !rubrics.applying && setRubrics(null)}
          style={{ position: 'fixed', inset: 0, zIndex: 1000, background: 'rgba(0,0,0,.6)', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16 }}>
          <div onClick={e => e.stopPropagation()}
            style={{ maxWidth: 760, width: '100%', maxHeight: '85vh', overflow: 'auto', padding: 18, borderRadius: 12, background: 'var(--brand-panel-bg, #161616)', border: '1px solid var(--brand-panel-border, rgba(255,255,255,.12))' }}>
            <h4 style={{ margin: '0 0 8px', fontSize: '.95rem' }}>{t({ id: 'catalogacao.batch.rubrics.title' })}</h4>
            <p style={{ margin: '0 0 12px', fontSize: '.82rem', color: 'var(--brand-muted, #aaa)' }}>
              {t({ id: 'catalogacao.batch.rubrics.intro' }, { name: rubrics.batch.name })}
            </p>
            {rubrics.loading ? (
              <p style={{ color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'common.loading' })}</p>
            ) : rubrics.rows.length === 0 ? (
              <p style={{ fontSize: '.85rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.batch.rubrics.empty' })}</p>
            ) : (
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '.82rem' }}>
                <thead>
                  <tr style={{ borderBottom: '1px solid rgba(255,255,255,.1)' }}>
                    <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.batch.rubrics.thRubric' })}</th>
                    <th style={{ textAlign: 'right', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.batch.rubrics.thDrafts' })}</th>
                    <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.batch.rubrics.thCode' })}</th>
                  </tr>
                </thead>
                <tbody>
                  {rubrics.rows.map((r, i) => (
                    <tr key={i} style={{ borderBottom: '1px solid rgba(255,255,255,.06)' }}>
                      <td style={{ padding: '6px 8px' }}>{r.rubric ?? <span style={{ color: 'var(--brand-muted, #888)' }}>{t({ id: 'catalogacao.batch.rubrics.noRubric' })}</span>}</td>
                      <td style={{ padding: '6px 8px', textAlign: 'right', whiteSpace: 'nowrap' }}>
                        {r.drafts} <span style={{ color: 'var(--brand-muted, #888)' }}>({r.without_class} {t({ id: 'catalogacao.batch.rubrics.thWithout' })})</span>
                      </td>
                      <td style={{ padding: '6px 8px' }}>
                        {r.rubric != null && (
                          <input type="text" value={rubrics.map[r.rubric] || ''} maxLength={40}
                            onChange={e => setRubrics(prev => ({ ...prev, map: { ...prev.map, [r.rubric]: e.target.value } }))}
                            style={{ width: '100%', padding: '5px 8px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.82rem' }} />
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
            <label style={{ display: 'flex', gap: 8, alignItems: 'center', marginTop: 12, fontSize: '.8rem', color: 'var(--brand-muted, #aaa)' }}>
              <input type="checkbox" checked={rubrics.overwrite} onChange={e => setRubrics(prev => ({ ...prev, overwrite: e.target.checked }))} />
              {t({ id: 'catalogacao.batch.rubrics.overwrite' })}
            </label>
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 14 }}>
              <button className="ab-button ab-button--ghost" style={{ fontSize: '.8rem', padding: '6px 12px' }}
                disabled={rubrics.applying} onClick={() => setRubrics(null)}>{t({ id: 'common.cancel' })}</button>
              <button className="ab-button ab-button--secondary" style={{ fontSize: '.8rem', padding: '6px 12px' }}
                disabled={rubrics.applying || rubrics.loading || !Object.values(rubrics.map).some(v => String(v || '').trim())} onClick={applyRubrics}>
                {rubrics.applying ? t({ id: 'common.saving' }) : t({ id: 'catalogacao.batch.rubrics.apply' })}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Changer la bibliotheque d'un lot (administration du reseau, B30) */}
      {reassign && (
        <div role="dialog" aria-modal="true" onClick={() => !reassigning && setReassign(null)}
          style={{ position: 'fixed', inset: 0, zIndex: 1000, background: 'rgba(0,0,0,.6)', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16 }}>
          <div onClick={e => e.stopPropagation()}
            style={{ maxWidth: 520, width: '100%', padding: 18, borderRadius: 12, background: 'var(--brand-panel-bg, #161616)', border: '1px solid var(--brand-panel-border, rgba(255,255,255,.12))' }}>
            <h4 style={{ margin: '0 0 8px', fontSize: '.95rem' }}>{t({ id: 'catalogacao.batch.reassign.title' })}</h4>
            <p style={{ margin: '0 0 12px', fontSize: '.82rem', color: 'var(--brand-muted, #aaa)' }}>
              {t({ id: 'catalogacao.batch.reassign.intro' }, { name: reassign.batch.name })}
            </p>
            {reassign.batch.library_id !== undefined && (
              <p style={{ margin: '0 0 12px', fontSize: '.85rem' }}>
                {t({ id: 'catalogacao.batch.reassign.current' }, { library: bibliothequeDuLot(reassign.batch, t) || '—' })}
              </p>
            )}
            <label style={{ display: 'block', fontSize: '.75rem', color: 'var(--brand-muted, #aaa)', marginBottom: 4 }}>
              {t({ id: 'catalogacao.batch.reassign.pick' })}
            </label>
            <select value={reassign.libraryId} onChange={e => setReassign({ ...reassign, libraryId: e.target.value })}
              style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }}>
              <option value="">{t({ id: 'catalogacao.batch.reassign.pickPlaceholder' })}</option>
              {libraries.map(l => (
                <option key={l.id} value={l.id}>
                  {l.name}{l.is_active ? '' : ' ' + t({ id: 'catalogacao.batch.reassign.libraryInactive' })}
                </option>
              ))}
            </select>
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 14 }}>
              <button className="ab-button ab-button--ghost" style={{ fontSize: '.8rem', padding: '6px 12px' }}
                disabled={reassigning} onClick={() => setReassign(null)}>{t({ id: 'common.cancel' })}</button>
              <button className="ab-button ab-button--secondary" style={{ fontSize: '.8rem', padding: '6px 12px' }}
                disabled={reassigning || reassignInchange(reassign)} onClick={submitReassign}>
                {reassigning ? t({ id: 'common.saving' }) : t({ id: 'catalogacao.batch.reassign.submit' })}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Lotes ouverts */}
      {openBatches.length > 0 && (
        <div style={{ marginBottom: 16 }}>
          <h4 style={{ margin: '0 0 10px', fontSize: '.88rem', fontWeight: 700 }}>{t({id:'catalogacao.batch.openBatchesCount'}, {count: openBatches.length})}</h4>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '.82rem' }}>
            <thead>
              <tr style={{ borderBottom: '1px solid rgba(255,255,255,.1)' }}>
                <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batch.thName'})}</th>
                <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batch.thNotes'})}</th>
                <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batch.thCreatedAt'})}</th>
                <th style={{ textAlign: 'right', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batch.thDrafts'})}</th>
                <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batch.thLibrary'})}</th>
                <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batch.review.th'})}</th>
                <th style={{ textAlign: 'right', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batchActions'})}</th>
              </tr>
            </thead>
            <tbody>
              {openBatches.map(b => (
                <tr key={b.id} style={{ borderBottom: '1px solid rgba(255,255,255,.06)' }} data-batch-status={b.status}>
                  <td style={{ padding: '8px' }}>
                    {b.name}
                    {enPublication(b) && (
                      <span className="cat-pill warn" data-publishing="1" style={{ marginLeft: 6 }}>{statusLabel(b.status)}</span>
                    )}
                  </td>
                  <td style={{ padding: '8px', color: 'var(--brand-muted, #aaa)' }}>{b.notes || '—'}</td>
                  <td style={{ padding: '8px' }}>{formatDate(b.created_at)}</td>
                  <td style={{ padding: '8px', textAlign: 'right', whiteSpace: 'nowrap' }}>{renderCounts(b)}</td>
                  <td style={{ padding: '8px', fontSize: '.78rem' }}>{renderLibrary(b)}</td>
                  <td style={{ padding: '8px', fontSize: '.78rem' }}>{renderReview(b)}</td>
                  <td style={{ padding: '8px', textAlign: 'right' }}>
                    {reviews[b.id]?.imported && (
                      <>
                        {peutModifier(b) && (
                          <button className="ab-button ab-button--ghost" style={{ marginRight: 6, fontSize: '.75rem', padding: '4px 10px' }}
                            onClick={() => openReport(b)}>{t({id:'catalogacao.batch.review.report'})}</button>
                        )}
                        {/* IMP-27 (b) : sur un lot approuvé où des brouillons sont
                            entrés après la demande, la coordination redemande
                            elle-même un tour (fn_batch_review_request l'accepte
                            tant que fn_batch_ajouts_apres_revision > 0) ;
                            l'administration garde « Rouvrir ». */}
                        {coordonne(b) && (!reviews[b.id].status || reviews[b.id].status === 'changes_requested'
                          || (ajoutsApresRevision(reviews[b.id]) > 0 && !isNetworkAdmin)) && (
                          <button className="ab-button ab-button--secondary" style={{ marginRight: 6, fontSize: '.75rem', padding: '4px 10px' }}
                            onClick={() => requestReview(b)}>{t({id:'catalogacao.batch.review.request'})}</button>
                        )}
                        {peutRouvrirRevision(reviews[b.id], b, isNetworkAdmin) && (
                          <button className="ab-button ab-button--ghost" style={{ marginRight: 6, fontSize: '.75rem', padding: '4px 10px' }}
                            onClick={() => requestReview(b, true)}>{t({id:'catalogacao.batch.review.reopen'})}</button>
                        )}
                      </>
                    )}
                    {/* H34 lot 2 : pendant « publishing », rien ne se retouche (la base
                        refuse) — seule la reprise de la publication reste. */}
                    {enPublication(b) && peutModifier(b) && (
                      <button className="ab-button ab-button--secondary" style={{ marginRight: 6, fontSize: '.75rem', padding: '4px 10px' }}
                        disabled={publication != null}
                        onClick={() => publishBatch(b.id, true)}>{t({ id: 'catalogacao.batch.publication.resume' })}</button>
                    )}
                    {!enPublication(b) && peutModifier(b, isCoord) && (
                      <>
                        <button className="ab-button ab-button--ghost" style={{ marginRight: 6, fontSize: '.75rem', padding: '4px 10px' }}
                          onClick={() => openBibRefs(b)}>{t({id:'catalogacao.batch.bibrefs'})}</button>
                        <button className="ab-button ab-button--ghost" style={{ marginRight: 6, fontSize: '.75rem', padding: '4px 10px' }}
                          onClick={() => openRubrics(b)}>{t({id:'catalogacao.batch.rubrics'})}</button>
                      </>
                    )}
                    {isNetworkAdmin && !enPublication(b) && (
                      <button className="ab-button ab-button--ghost" style={{ marginRight: 6, fontSize: '.75rem', padding: '4px 10px' }}
                        onClick={() => setReassign({ batch: b, libraryId: b.library_id || '' })}>{t({id:'catalogacao.batch.reassign'})}</button>
                    )}
                    {!enPublication(b) && peutModifier(b) && (
                      <>
                        <button className="ab-button ab-button--secondary" style={{ marginRight: 6, fontSize: '.75rem', padding: '4px 10px' }}
                          disabled={reviewLocked(b) || publication != null}
                          title={!reviewLocked(b) ? undefined
                            : ajoutsApresRevision(reviews[b.id]) > 0
                              ? t({id:'catalogacao.batch.review.afterReview'}, { n: ajoutsApresRevision(reviews[b.id]) })
                              : t({id:'catalogacao.batch.review.publishLocked'})}
                          onClick={() => publishBatch(b.id)}>{t({id:'catalogacao.publishBatch'})}</button>
                        <button className="ab-button ab-button--ghost" style={{ fontSize: '.75rem', padding: '4px 10px' }}
                          onClick={() => closeBatch(b.id)}>{t({id:'catalogacao.closeBatch'})}</button>
                      </>
                    )}
                    {!enPublication(b) && coordonne(b) && estVide(b) && (
                      <button className="ab-button ab-button--ghost" style={{ marginLeft: 6, fontSize: '.75rem', padding: '4px 10px', color: '#f87171' }}
                        onClick={() => deleteBatch(b.id)}>{t({id:'catalogacao.deleteBatch'})}</button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Lotes fermés (non archivés) */}
      {closedBatches.length > 0 && (
        <details style={{ marginTop: 12 }}>
          <summary style={{ cursor: 'pointer', fontSize: '.82rem', color: 'var(--brand-muted, #aaa)' }}>
            {t({id:'catalogacao.closedBatches'},{count: closedBatches.length})}
          </summary>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '.82rem', marginTop: 8 }}>
            <thead>
              <tr style={{ borderBottom: '1px solid rgba(255,255,255,.1)' }}>
                <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batch.thName'})}</th>
                <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batch.thStatus'})}</th>
                <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batch.thCreatedAt'})}</th>
                <th style={{ textAlign: 'right', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batch.thDrafts'})}</th>
                <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batch.thLibrary'})}</th>
                <th style={{ textAlign: 'right', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batchActions'})}</th>
              </tr>
            </thead>
            <tbody>
              {closedBatches.map(b => (
                <tr key={b.id} style={{ borderBottom: '1px solid rgba(255,255,255,.06)', opacity: 0.6 }}>
                  <td style={{ padding: '8px' }}>{b.name}</td>
                  <td style={{ padding: '8px' }}>
                    <span className={`cat-pill ${b.status === 'published' ? 'ok' : 'warn'}`}>
                      {statusLabel(b.status)}
                    </span>
                  </td>
                  <td style={{ padding: '8px' }}>{formatDate(b.created_at)}</td>
                  <td style={{ padding: '8px', textAlign: 'right', whiteSpace: 'nowrap' }}>{renderCounts(b)}</td>
                  <td style={{ padding: '8px', fontSize: '.78rem' }}>{renderLibrary(b)}</td>
                  <td style={{ padding: '8px', textAlign: 'right' }}>
                    {peutModifier(b) && (
                      <button className="ab-button ab-button--ghost" style={{ marginRight: 6, fontSize: '.75rem', padding: '4px 10px' }}
                        onClick={() => archiveBatch(b.id)}>{t({id:'catalogacao.archiveBatch'})}</button>
                    )}
                    {coordonne(b) && (
                      <button className="ab-button ab-button--ghost" style={{ fontSize: '.75rem', padding: '4px 10px', color: '#f87171' }}
                        onClick={() => deleteBatch(b.id)}>{t({id:'catalogacao.deleteBatch'})}</button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </details>
      )}

      {/* Lotes archivés */}
      {archivedBatches.length > 0 && (
        <details style={{ marginTop: 12 }}>
          <summary style={{ cursor: 'pointer', fontSize: '.82rem', color: 'var(--brand-muted, #666)' }}>
            {t({id:'catalogacao.archivedBatches'},{count: archivedBatches.length})}
          </summary>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '.82rem', marginTop: 8 }}>
            <thead>
              <tr style={{ borderBottom: '1px solid rgba(255,255,255,.1)' }}>
                <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batch.thName'})}</th>
                <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batch.thCreatedAt'})}</th>
                <th style={{ textAlign: 'right', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batch.thDrafts'})}</th>
                <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batch.thLibrary'})}</th>
                <th style={{ textAlign: 'right', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batchActions'})}</th>
              </tr>
            </thead>
            <tbody>
              {archivedBatches.map(b => (
                <tr key={b.id} style={{ borderBottom: '1px solid rgba(255,255,255,.06)', opacity: 0.4 }}>
                  <td style={{ padding: '8px' }}>{b.name}</td>
                  <td style={{ padding: '8px' }}>{formatDate(b.created_at)}</td>
                  <td style={{ padding: '8px', textAlign: 'right', whiteSpace: 'nowrap' }}>{renderCounts(b)}</td>
                  <td style={{ padding: '8px', fontSize: '.78rem' }}>{renderLibrary(b)}</td>
                  <td style={{ padding: '8px', textAlign: 'right' }}>
                    {coordonne(b) && (
                      <button className="ab-button ab-button--ghost" style={{ fontSize: '.75rem', padding: '4px 10px', color: '#f87171' }}
                        onClick={() => deleteBatch(b.id)}>{t({id:'catalogacao.deleteBatch'})}</button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </details>
      )}

      {batches.length === 0 && (
        <div className="cat-placeholder">{t({id:'catalogacao.noBatches'})}</div>
      )}
    </div>
  );
}
