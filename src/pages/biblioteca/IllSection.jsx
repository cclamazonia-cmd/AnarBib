// src/pages/biblioteca/IllSection.jsx — E6, BibliotecaPage lot 1 (28/09/2026)
// L'onglet « Empréstimos interbibliotecas » (PEB) de la page Bibliothèque,
// sorti de BibliotecaPage.jsx sans en changer une ligne de logique : le
// formulaire d'un nouveau prêt (prêteuse, emprunteuse, exemplaires cherchés
// dans le fonds de la prêteuse, contact, logistique), la file des prêts actifs
// avec leur statut, le pointage du retour exemplaire par exemplaire, l'archivage,
// et le partage numérique (7b). La liste des prêts et leurs exemplaires restent
// chargés par le parent (le rapport les lit aussi) et arrivent en props ; la
// section prévient par `onChanged` quand la base a bougé.
import { useState } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import LibraryDigitalSharesSection from '@/components/library/LibraryDigitalSharesSection';
import { fs, ls, bx, lr, lw } from './styles';

export default function IllSection({ libraryId, illLoans, illItemsByLoan, allLibraries, pebEligibleLibraries, isCoord, setMsg, onChanged }) {
  const { formatMessage: t } = useIntl();
  const [saving, setSaving] = useState(false);
  const [illForm, setIllForm] = useState({ lender:'', borrower:'', status:'preparacao', contactName:'', contactEmail:'', startDate:'', dueDate:'', logisticsNote:'', meetingPoint:'', logisticsMode:'' });
  const [illItems, setIllItems] = useState([]);
  const [illDocSearch, setIllDocSearch] = useState('');
  const [illDocResults, setIllDocResults] = useState([]);
  // Prêts dont le bloc d'exemplaires est déplié (Set d'ids).
  const [illExpanded, setIllExpanded] = useState(() => new Set());
  // Pointages de retour en cours de saisie, par prêt :
  // { [loanId]: { [itemRowId]: { checked: bool, status: 'devolvido'|... } } }
  const [illReturnDraft, setIllReturnDraft] = useState({});
  // Feedback LOCAL au bloc de pointage, par prêt (option B) :
  // { [loanId]: { busy: bool, msg: string|null, kind: 'ok'|'error'|null } }
  const [illReturnFeedback, setIllReturnFeedback] = useState({});

  // ── ILL: search documents for item adding ───────────────
  async function searchIllDocs() {
    if (!illDocSearch.trim()) return;
    // #ILL-search-scope + #ILL-availability : la recherche exige la
    // bibliotheque prêteuse (fn_peb_search_exemplares filtre sur elle et
    // sur la disponibilite). Sans prêteuse choisie, on ne cherche pas.
    if (!illForm.lender) {
      setMsg({ text: t({ id: 'biblioteca.ill.pickLenderFirst' }), kind: 'error' });
      return;
    }
    // EA-12 phase 2 (dette 4) - correctif : la recherche passe par la RPC
    // fn_peb_search_exemplares (exemplares -> book_holdings -> books).
    const { data, error } = await supabase.rpc('fn_peb_search_exemplares', {
      p_query: illDocSearch.trim(),
      p_lender_library_id: illForm.lender,
    });
    if (error) {
      setIllDocResults([]);
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(error, t) }), kind: 'error' });
      return;
    }
    setIllDocResults(data || []);
  }

  // EA-12 phase 2 (dette 4) : un item PEB est un EXEMPLAIRE physique precis.
  // On stocke item_id (= exemplar_id), holding_id et book_id, tous exiges
  // ou utilises par fn_peb_create_loan_with_items. La cle d'unicite est
  // l'exemplaire (item_id) : deux exemplaires d'un meme titre sont distincts.
  function addIllItem(ex) {
    if (illItems.find(it => it.item_id === ex.exemplar_id)) return;
    setIllItems(prev => [...prev, {
      item_id: ex.exemplar_id,
      holding_id: ex.holding_id,
      book_id: ex.book_id,
      bib_ref: ex.bib_ref,
      titulo: ex.titulo,
      autor: ex.autor,
      tombo: ex.tombo,
    }]);
  }

  function removeIllItem(itemId) { setIllItems(prev => prev.filter(it => it.item_id !== itemId)); }

  async function saveIll() {
    if (!illForm.lender || !illForm.borrower) { setMsg({ text: t({id:'biblioteca.ill.selectBoth'}), kind: 'error' }); return; }
    if (illForm.lender === illForm.borrower) { setMsg({ text: t({id:'biblioteca.ill.differentLibraries'}), kind: 'error' }); return; }
    // #ILL-front — champs obligatoires : contact de coordination, e-mail
    // valide, au moins un exemplaire, mode logistique choisi.
    if (!illForm.contactName.trim()) { setMsg({ text: t({id:'biblioteca.ill.contactRequired'}), kind: 'error' }); return; }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(illForm.contactEmail.trim())) { setMsg({ text: t({id:'biblioteca.ill.contactEmailInvalid'}), kind: 'error' }); return; }
    if (illItems.length === 0) { setMsg({ text: t({id:'biblioteca.ill.itemsRequired'}), kind: 'error' }); return; }
    if (!illForm.logisticsMode) { setMsg({ text: t({id:'biblioteca.ill.logisticsModeRequired'}), kind: 'error' }); return; }
    setSaving(true); setMsg({ text: '', kind: '' });
    try {
      // EA-12 phase 1 (21/05/2026) : bascule sur fn_peb_create_loan_with_items
      // pour atomicite loan+items et securite RLS heritee. La RPC valide
      // automatiquement user_can_manage_library + fn_peb_authorized.
      const payload_loan = {
        lender_library_id: illForm.lender,
        borrower_library_id: illForm.borrower,
        initiated_by_library_id: libraryId,
        status_global: illForm.status || 'preparacao',
        coordination_contact_name: illForm.contactName || null,
        coordination_contact_email: illForm.contactEmail || null,
        start_date: illForm.startDate || null,
        due_date: illForm.dueDate || null,
        notes: illForm.logisticsNote || null,
        // meeting_point n'a de sens que pour les modes de remise physique.
        meeting_point: (illForm.logisticsMode === 'entrega_em_maos'
                        || illForm.logisticsMode === 'transporte_militante')
                       ? (illForm.meetingPoint || null) : null,
        // #ILL-logistics : mode choisi par l'utilisateur·rice.
        logistics_mode: illForm.logisticsMode,
      };
      // EA-12 phase 2 (dette 4) : holding_id et item_id viennent desormais
      // reellement de l'exemplaire choisi (etaient undefined avant le patch).
      const payload_items = illItems.map((it, i) => ({
        line_no: i + 1,
        holding_id: it.holding_id,
        item_id: it.item_id,
        book_id: it.book_id || null,
        bib_ref: it.bib_ref,
        titulo_cache: it.titulo,
        autor_cache: it.autor,
        item_status: 'reservado_para_saida',
      }));
      const { data, error } = await supabase.rpc('fn_peb_create_loan_with_items', {
        p_loan: payload_loan,
        p_items: payload_items,
      });
      if (error) throw error;
      const newLoan = data?.loan;
      const newItems = data?.items || [];
      setMsg({ text: t({id:'biblioteca.ill.created'},{id:newLoan?.id,count:newItems.length}), kind: 'ok' });
      setIllForm({ lender:'', borrower:'', status:'preparacao', contactName:'', contactEmail:'', startDate:'', dueDate:'', logisticsNote:'', meetingPoint:'', logisticsMode:'' });
      setIllItems([]); setIllDocSearch(''); setIllDocResults([]);
      await onChanged?.();
    } catch (err) {
      // EA-12 phase 2 (dette 3) : un rejet RLS / fn_peb_authorized renvoie
      // un message Postgres technique. On le traduit en message clair :
      // le PEB exige que les deux bibliotheques soient federees.
      const raw = String(err?.message || '');
      const isAuthz = /row-level security|fn_peb_authorized|violates row-level|permission denied/i.test(raw);
      setMsg({
        text: isAuthz
          ? t({ id: 'biblioteca.ill.notAuthorized' })
          : t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }),
        kind: 'error',
      });
    }
    finally { setSaving(false); }
  }

  async function updateIllStatus(loanId, newStatus) {
    // EA-12 phase 1 (21/05/2026) : bascule sur fn_peb_update_status (RPC).
    try {
      const { error } = await supabase.rpc('fn_peb_update_status', {
        p_loan_id: loanId,
        p_new_status: newStatus,
      });
      if (error) throw error;
      await onChanged?.();
    } catch (err) {
      setMsg({ text: t({id:'common.errorPrefix'},{message:localizeError(err, t)}), kind: 'error' });
    }
  }

  // ── #ILL-partial : pointage du retour des exemplaires ─────
  // Statuts de prêt où le pointage d'un retour a un sens (aligné sur le
  // garde-fou de phase du trigger trg_peb_consolidate_loan_status).
  const ILL_RETURN_PHASES = ['emprestado', 'em_devolucao', 'atrasado', 'parcialmente_devolvido'];
  // Un exemplaire est « réglé » s'il a atteint une issue de retour.
  const ILL_ITEM_SETTLED = ['devolvido', 'perdido', 'danificado', 'cancelado'];
  // Statuts où un prêt se supprime : ceux de la politique DELETE de
  // interlibrary_loans_v2 (un prêt jamais sorti). Sorti, il se termine et
  // s'archive ; la base refuse sa suppression.
  const ILL_DISCARDABLE = ['preparacao', 'aguardando_saida'];

  function toggleIllExpanded(loanId) {
    setIllExpanded(prev => {
      const next = new Set(prev);
      next.has(loanId) ? next.delete(loanId) : next.add(loanId);
      return next;
    });
  }

  // Met à jour le brouillon de pointage d'un exemplaire (case cochée / statut).
  function setIllReturnField(loanId, itemRowId, field, value) {
    setIllReturnDraft(prev => {
      const loanDraft = { ...(prev[loanId] || {}) };
      const itemDraft = { ...(loanDraft[itemRowId] || { checked: false, status: 'devolvido' }) };
      itemDraft[field] = value;
      loanDraft[itemRowId] = itemDraft;
      return { ...prev, [loanId]: loanDraft };
    });
  }

  // Envoie le lot d'exemplaires cochés à la RPC fn_peb_update_item_status.
  // Feedback LOCAL au bloc (option B) : message + état occupé propres au prêt.
  async function submitIllItemReturn(loanId) {
    const loanDraft = illReturnDraft[loanId] || {};
    const p_items = Object.entries(loanDraft)
      .filter(([, d]) => d.checked)
      .map(([itemRowId, d]) => ({ id: Number(itemRowId), new_status: d.status }));
    if (p_items.length === 0) {
      setIllReturnFeedback(prev => ({ ...prev, [loanId]: {
        busy: false, kind: 'error',
        msg: t({ id: 'biblioteca.ill.return.nothingSelected' }),
      }}));
      return;
    }
    // État occupé : le bouton se désactive et affiche « Validation… ».
    setIllReturnFeedback(prev => ({ ...prev, [loanId]: { busy: true, msg: null, kind: null }}));
    try {
      const { data, error } = await supabase.rpc('fn_peb_update_item_status', {
        p_loan_id: loanId,
        p_items,
      });
      if (error) throw error;
      // La RPC renvoie { loan, items } : on lit le nouveau statut du prêt
      // pour le nommer dans le message de confirmation.
      const newStatus = data?.loan?.status_global || '';
      const statusLabel = newStatus
        ? t({ id: `ill.status.${newStatus}` })
        : '';
      setIllReturnDraft(prev => { const n = { ...prev }; delete n[loanId]; return n; });
      await onChanged?.();
      // Message de résultat : nombre traité + nouveau statut du prêt.
      setIllReturnFeedback(prev => ({ ...prev, [loanId]: {
        busy: false, kind: 'ok',
        msg: t({ id: 'biblioteca.ill.return.done' },
                { count: p_items.length, status: statusLabel }),
      }}));
    } catch (err) {
      setIllReturnFeedback(prev => ({ ...prev, [loanId]: {
        busy: false, kind: 'error',
        msg: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }),
      }}));
    }
  }

  async function deleteIll(loanId) {
    if (!confirm(t({id:'biblioteca.ill.discardConfirm'},{id:loanId}))) return;
    try {
      // EA-12 phase 1 (21/05/2026) : bascule sur fn_peb_delete_loan (atomique).
      const { error } = await supabase.rpc('fn_peb_delete_loan', {
        p_loan_id: loanId,
      });
      if (error) throw error;
      setMsg({ text: t({id:'biblioteca.ill.discarded'},{id:loanId}), kind: 'ok' });
      await onChanged?.();
    } catch (err) {
      // Le prêt est sorti entre l'affichage et le clic (l'autre bibliothèque
      // l'a fait avancer) : la fonction dit « refusé par RLS ». On dit pourquoi.
      const raw = String(err?.message || '');
      const sorti = /refus[ée] par RLS|row-level security/i.test(raw);
      setMsg({
        text: sorti
          ? t({ id: 'biblioteca.ill.discardAfterDeparture' }, { id: loanId })
          : t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }),
        kind: 'error',
      });
    }
  }

  // #ILL-archive (25/05/2026) : archivage manuel d'un PEB terminé. Le PEB
  // sort de la file active et devient consultable dans l'onglet Rapports.
  // RPC fn_peb_archive_loan — réservée au staff, vérifie le statut terminal.
  async function archiveIllLoan(loanId) {
    if (!confirm(t({id:'biblioteca.ill.archiveConfirm'},{id:loanId}))) return;
    try {
      const { error } = await supabase.rpc('fn_peb_archive_loan', {
        p_loan_id: loanId,
      });
      if (error) throw error;
      setMsg({ text: t({id:'biblioteca.ill.archived'},{id:loanId}), kind: 'ok' });
      await onChanged?.();
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:localizeError(err, t)}), kind: 'error' }); }
  }

  return (
    <div>
      <h3 style={{ marginBottom:12 }}>{t({ id: 'biblioteca.ill.title' })}</h3>
      <div style={{ fontSize:'.85rem', color:'var(--brand-muted)', marginBottom:14 }}>{t({id:'biblioteca.ill.hint'})}</div>

      <div style={bx}>
        <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.ill.prepare' })}</h4>
        <div className="cat-book-grid" style={{ marginBottom:10 }}>
          {/* EA-12 phase 2 (dette 2) : seules les bibliotheques eligibles
              au PEB sont proposees - federees, circulation active, actives.
              C'est la regle de fn_peb_authorized, appliquee des le dropdown. */}
          <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.lender' })}</label>
            <select value={illForm.lender} onChange={e=>{
              const v = e.target.value;
              setIllForm(p=>({...p,lender:v}));
              // #ILL-search-scope : changer de prêteuse invalide le panier
              // (les exemplaires appartenaient a l'ancienne prêteuse) et
              // les resultats de recherche. On purge les deux.
              setIllItems([]);
              setIllDocResults([]);
              setIllDocSearch('');
            }} style={fs}>
              <option value="">{t({ id: 'biblioteca.ill.select' })}</option>{pebEligibleLibraries.map(l=><option key={l.id} value={l.id}>{l.name} ({l.short_name})</option>)}
            </select>
          </div>
          <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.borrower' })}</label>
            <select value={illForm.borrower} onChange={e=>setIllForm(p=>({...p,borrower:e.target.value}))} style={fs}>
              <option value="">{t({ id: 'biblioteca.ill.select' })}</option>{pebEligibleLibraries.map(l=><option key={l.id} value={l.id}>{l.name} ({l.short_name})</option>)}
            </select>
          </div>
          <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.status' })}</label>
            <select value={illForm.status} onChange={e=>setIllForm(p=>({...p,status:e.target.value}))} style={fs}>
              <option value="preparacao">{t({ id: 'ill.status.preparacao' })}</option><option value="aguardando_saida">{t({ id: 'ill.status.aguardando_saida' })}</option>
              <option value="emprestado">{t({ id: 'ill.status.emprestado' })}</option><option value="em_devolucao">{t({ id: 'ill.status.em_devolucao' })}</option>
              <option value="devolvido">{t({ id: 'ill.status.devolvido' })}</option><option value="cancelado">{t({ id: 'ill.status.cancelado' })}</option>
            </select>
          </div>
        </div>

        <div style={{ ...bx, background:'rgba(0,0,0,.1)', marginBottom:12 }}>
          <h4 style={{ margin:'0 0 8px', fontSize:'.95rem' }}>{t({ id: 'biblioteca.ill.items' })} *</h4>
          {/* #ILL-search-scope : la recherche d'exemplaires exige qu'une
              bibliotheque prêteuse soit choisie (la recherche est filtree
              sur ses fonds disponibles). Tant qu'aucune n'est selectionnee,
              champ et bouton desactives, avec une invite. */}
          {!illForm.lender && (
            <div style={{ fontSize:'.82rem', color:'var(--brand-muted)', fontStyle:'italic', marginBottom:8 }}>
              {t({ id: 'biblioteca.ill.pickLenderFirst' })}
            </div>
          )}
          <div style={{ display:'flex', gap:8, marginBottom:8 }}>
            <input type="text" value={illDocSearch} disabled={!illForm.lender}
              onChange={e=>setIllDocSearch(e.target.value)}
              onKeyDown={e=>e.key==='Enter'&&searchIllDocs()}
              placeholder={t({ id: 'biblioteca.ill.fullSearchPlaceholder' })}
              style={{...fs,flex:1,opacity:illForm.lender?1:0.5}} />
            <button className="cat-btn secondary" onClick={searchIllDocs}
              disabled={!illForm.lender}
              style={{ fontSize:'.85rem', padding:'7px 14px', flexShrink:0, opacity:illForm.lender?1:0.5 }}>
              {t({ id: 'common.search' })}
            </button>
          </div>
          {/* Finition UX PEB : la ligne entiere ajoute l'exemplaire au clic
              (le bouton « Adicionar » faisait doublon, retire). Le survol
              signale que la ligne est cliquable. */}
          {illDocResults.length>0 && <div style={{...lw,marginBottom:8,maxHeight:150,overflowY:'auto'}}>{illDocResults.map((d,i)=>(
            <div key={d.exemplar_id}
              style={{...lr(i),cursor:'pointer'}}
              title={t({ id: 'biblioteca.ill.clickToAdd' })}
              onClick={()=>addIllItem(d)}
              onMouseEnter={e=>{e.currentTarget.style.background='rgba(255,255,255,.06)';}}
              onMouseLeave={e=>{e.currentTarget.style.background='';}}>
              <div style={{ fontSize:'.88rem' }}><strong>{d.titulo}</strong> — {d.autor||'—'} · {t({ id: 'biblioteca.ill.tombo' })}: {d.tombo||'—'}</div>
              <span aria-hidden="true" style={{ fontSize:'.78rem', color:'var(--brand-muted)' }}>+</span>
            </div>
          ))}</div>}
          {illItems.length===0 && <div style={{ fontSize:'.85rem', color:'var(--brand-muted)' }}>{t({id:'biblioteca.ill.emptyItems'})}</div>}
          {illItems.length>0 && <div style={lw}>{illItems.map((it,i)=>(
            <div key={it.item_id} style={lr(i)}>
              <div style={{ fontSize:'.88rem' }}><strong>{it.titulo}</strong> — {it.autor||'—'} · {t({ id: 'biblioteca.ill.tombo' })}: {it.tombo||'—'}</div>
              <button className="cat-btn ghost" style={{ fontSize:'.78rem', padding:'3px 8px', color:'#f87171' }} onClick={()=>removeIllItem(it.item_id)}>{t({ id: 'common.remove' })}</button>
            </div>
          ))}</div>}
        </div>

        {/* Finition UX PEB : le PEB est bidirectionnel, le libelle des
            champs de contact ne peut pas dire « preteuse » ou « emprunteuse ».
            Cette phrase leve l'ambiguite : c'est le contact de SA biblio. */}
        <div style={{ fontSize:'.8rem', color:'var(--brand-muted)', marginBottom:8 }}>
          {t({ id: 'biblioteca.ill.coordinationHelp' })}
        </div>
        <div className="cat-book-grid" style={{ marginBottom:10 }}>
          <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.contact' })} *</label><input type="text" value={illForm.contactName} onChange={e=>setIllForm(p=>({...p,contactName:e.target.value}))} style={fs} placeholder={t({ id: 'biblioteca.ill.contactNamePlaceholder' })} /></div>
          <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.contactEmail' })} *</label><input type="email" value={illForm.contactEmail} onChange={e=>setIllForm(p=>({...p,contactEmail:e.target.value}))} style={fs} placeholder="contato@biblioteca.org" /></div>
          {/* #ILL-logistics : mode de transmission des documents. */}
          <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.logisticsMode' })} *</label>
            <select value={illForm.logisticsMode} onChange={e=>setIllForm(p=>({...p,logisticsMode:e.target.value}))} style={fs}>
              <option value="">{t({ id: 'biblioteca.ill.select' })}</option>
              <option value="envio_postal">{t({ id: 'ill.logistics.envio_postal' })}</option>
              <option value="entrega_em_maos">{t({ id: 'ill.logistics.entrega_em_maos' })}</option>
              <option value="transporte_militante">{t({ id: 'ill.logistics.transporte_militante' })}</option>
              <option value="a_combinar">{t({ id: 'ill.logistics.a_combinar' })}</option>
            </select>
          </div>
          {/* meeting_point : seulement pour les modes de remise physique
              (remise en main propre, portage militant). */}
          {(illForm.logisticsMode === 'entrega_em_maos' || illForm.logisticsMode === 'transporte_militante') && (
            <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.meetingPoint' })}</label><input type="text" value={illForm.meetingPoint} onChange={e=>setIllForm(p=>({...p,meetingPoint:e.target.value}))} style={fs} placeholder={t({ id: 'biblioteca.ill.pickupPlaceholder' })} /></div>
          )}
          <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.startDate' })}</label><input type="date" value={illForm.startDate} onChange={e=>setIllForm(p=>({...p,startDate:e.target.value}))} style={fs} /></div>
          <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.dueDate' })}</label><input type="date" value={illForm.dueDate} onChange={e=>setIllForm(p=>({...p,dueDate:e.target.value}))} style={fs} /></div>
          <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.ill.notes' })}</label><textarea value={illForm.logisticsNote} onChange={e=>setIllForm(p=>({...p,logisticsNote:e.target.value}))} rows={2} style={{...fs,resize:'vertical'}} placeholder={t({ id: 'biblioteca.ill.packagingPlaceholder' })} /></div>
        </div>
        <div style={{ display:'flex', gap:8 }}>
          <button className="cat-btn primary" onClick={saveIll} disabled={saving} style={{ fontSize:'.9rem' }}>{saving?t({id:'common.saving'}):t({id:'biblioteca.ill.save'})}</button>
          <button className="cat-btn ghost" onClick={()=>{setIllForm({lender:'',borrower:'',status:'preparacao',contactName:'',contactEmail:'',startDate:'',dueDate:'',logisticsNote:'',meetingPoint:'',logisticsMode:''});setIllItems([]);}} style={{ fontSize:'.88rem' }}>{t({ id: 'biblioteca.ill.clear' })}</button>
        </div>
      </div>

      {/* Liste des empréstimos existants */}
      {illLoans.length>0 && (<div style={{ marginTop:16 }}>
        <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.ill.existing' })}</h4>
        <div style={lw}>{illLoans.map((loan,i)=>{
          const isLender = loan.lender_library_id===libraryId;
          const lenderLib = allLibraries.find(l=>l.id===loan.lender_library_id);
          const borrowerLib = allLibraries.find(l=>l.id===loan.borrower_library_id);
          // #ILL-partial — exemplaires de ce prêt, état déplié, phase de retour.
          const items = illItemsByLoan[loan.id] || [];
          const expanded = illExpanded.has(loan.id);
          const inReturnPhase = ILL_RETURN_PHASES.includes(loan.status_global);
          // status_global déduit (parcialmente_devolvido, devolvido) : le
          // <select> l'affiche mais ne permet pas de le choisir à la main.
          const statusIsDerived = loan.status_global==='parcialmente_devolvido' || loan.status_global==='devolvido';
          const loanDraft = illReturnDraft[loan.id] || {};
          // #ILL-archive — un PEB terminé (devolvido/cancelado) est archivable.
          // Garde-fou visuel : s'il est terminé depuis plus de 30 jours, on
          // le signale (closed_at approché par returned_at, sinon updated_at).
          const isTerminal = loan.status_global==='devolvido' || loan.status_global==='cancelado';
          const closedAt = loan.returned_at || loan.updated_at;
          const staleForArchive = isTerminal && closedAt &&
            (Date.now() - new Date(closedAt).getTime()) > 30*24*60*60*1000;
          return(<div key={loan.id} style={{ borderBottom:'1px solid rgba(255,255,255,.04)' }}>
            <div style={{ ...lr(i), borderBottom:'none' }}>
            <div style={{ flex:1 }}>
              <div style={{ fontSize:'.9rem', fontWeight:600 }}>
                {items.length>0 && (
                  <button onClick={()=>toggleIllExpanded(loan.id)} className="cat-btn ghost"
                    style={{ fontSize:'.78rem', padding:'0 6px', marginRight:6 }}>
                    {expanded?'▾':'▸'} {t({ id:'biblioteca.ill.itemsCount' },{count:items.length})}
                  </button>
                )}
                #{loan.id} — {isLender?t({ id: 'biblioteca.ill.lender' }):t({ id: 'biblioteca.ill.borrower' })}
                {/* #ILL-archive — garde-fou visuel : PEB terminé depuis longtemps */}
                {staleForArchive && (
                  <span style={{ marginLeft:8, fontSize:'.7rem', fontWeight:600, padding:'2px 7px',
                    borderRadius:10, background:'rgba(251,191,36,.16)', color:'#fbbf24' }}>
                    {t({ id: 'biblioteca.ill.staleForArchive' })}
                  </span>
                )}
              </div>
              <div style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>
                {lenderLib?.short_name||'—'} → {borrowerLib?.short_name||'—'}
                {loan.start_date&&` · ${t({ id: 'biblioteca.ill.startDateLabel' })}: ${loan.start_date}`}{loan.due_date&&` · ${t({ id: 'biblioteca.ill.dueDateLabel' })}: ${loan.due_date}`}
                {loan.meeting_point&&` · ${loan.meeting_point}`}
              </div>
            </div>
            <select value={loan.status_global||''} disabled={statusIsDerived}
              onChange={e=>updateIllStatus(loan.id,e.target.value)}
              style={{ fontSize:'.82rem', padding:'4px 8px', borderRadius:6, border:'1px solid rgba(255,255,255,.12)', background:'rgba(0,0,0,.3)', color:'#f4f4f4', opacity:statusIsDerived?0.6:1 }}>
              <option value="preparacao">{t({ id: 'ill.status.preparacao' })}</option><option value="aguardando_saida">{t({ id: 'ill.status.aguardando_saida' })}</option>
              <option value="emprestado">{t({ id: 'ill.status.emprestado' })}</option><option value="em_devolucao">{t({ id: 'ill.status.em_devolucao' })}</option>
              {/* #ILL-partial — affiché pour ne pas casser le select quand le
                  statut est déduit ; non sélectionnable (select disabled). */}
              <option value="parcialmente_devolvido">{t({ id: 'ill.status.parcialmente_devolvido' })}</option>
              <option value="devolvido">{t({ id: 'ill.status.devolvido' })}</option><option value="cancelado">{t({ id: 'ill.status.cancelado' })}</option>
            </select>
            {/* #ILL-archive — bouton d'archivage, seulement sur un PEB terminé */}
            {isTerminal && (
              <button className="cat-btn ghost" style={{ fontSize:'.78rem', padding:'4px 8px' }}
                onClick={()=>archiveIllLoan(loan.id)}>
                {t({ id: 'biblioteca.ill.archive' })}
              </button>
            )}
            {/* #ILL-archive — descartar (suppression définitive) n'a de
                sens que sur un PEB jamais sorti (créé par erreur). Sorti,
                prêté ou en partie rendu, le bon geste est de pointer les
                retours puis d'archiver : la base refuse la suppression, et
                le bouton ne s'offre pas (29/09/2026). */}
            {ILL_DISCARDABLE.includes(loan.status_global) && (
              <button className="cat-btn ghost" style={{ fontSize:'.78rem', padding:'4px 8px', color:'#f87171' }} onClick={()=>deleteIll(loan.id)}>{t({ id: 'common.discard' })}</button>
            )}
            </div>
            {/* #ILL-partial — bloc dépliable : exemplaires + pointage du retour */}
            {expanded && items.length>0 && (
              <div style={{ padding:'4px 12px 12px 28px', background:'rgba(0,0,0,.12)' }}>
                {items.map(it=>{
                  const settled = ILL_ITEM_SETTLED.includes(it.item_status);
                  const draft = loanDraft[it.id] || { checked:false, status: settled?it.item_status:'devolvido' };
                  const ref = [it.titulo_cache, it.autor_cache].filter(Boolean).join(' — ') || it.bib_ref || '—';
                  return(<div key={it.id} style={{ display:'flex', alignItems:'center', gap:8, padding:'5px 0', fontSize:'.82rem', borderBottom:'1px solid rgba(255,255,255,.03)' }}>
                    <input type="checkbox" checked={!!draft.checked} disabled={!inReturnPhase}
                      onChange={e=>setIllReturnField(loan.id, it.id, 'checked', e.target.checked)} />
                    <span style={{ flex:1 }}>
                      {ref}{it.rotulo_cache?` (${it.rotulo_cache})`:''}
                      <span style={{ color:'var(--brand-muted)', marginLeft:6 }}>
                        · {t({ id:`ill.itemStatus.${it.item_status}` })}
                      </span>
                    </span>
                    {/* corrigeables : un select de statut de retour pour chaque
                        exemplaire (réglé ou non — la RPC autorise la correction) */}
                    <select value={draft.status} disabled={!inReturnPhase}
                      onChange={e=>setIllReturnField(loan.id, it.id, 'status', e.target.value)}
                      style={{ fontSize:'.78rem', padding:'2px 6px', borderRadius:5, border:'1px solid rgba(255,255,255,.12)', background:'rgba(0,0,0,.3)', color:'#f4f4f4' }}>
                      <option value="devolvido">{t({ id:'ill.itemStatus.devolvido' })}</option>
                      <option value="perdido">{t({ id:'ill.itemStatus.perdido' })}</option>
                      <option value="danificado">{t({ id:'ill.itemStatus.danificado' })}</option>
                      <option value="cancelado">{t({ id:'ill.itemStatus.cancelado' })}</option>
                    </select>
                  </div>);
                })}
                {inReturnPhase ? (
                  <>
                    <button className="cat-btn"
                      disabled={illReturnFeedback[loan.id]?.busy}
                      style={{ fontSize:'.8rem', padding:'5px 12px', marginTop:8,
                               opacity: illReturnFeedback[loan.id]?.busy ? 0.6 : 1 }}
                      onClick={()=>submitIllItemReturn(loan.id)}>
                      {illReturnFeedback[loan.id]?.busy
                        ? t({ id:'biblioteca.ill.return.submitting' })
                        : t({ id:'biblioteca.ill.return.submit' })}
                    </button>
                    {/* Message de résultat LOCAL, juste sous le bouton (option B). */}
                    {illReturnFeedback[loan.id]?.msg && (
                      <div style={{ fontSize:'.8rem', marginTop:6, padding:'5px 9px',
                                    borderRadius:6,
                                    background: illReturnFeedback[loan.id].kind==='ok'
                                      ? 'rgba(74,222,128,.12)' : 'rgba(248,113,113,.12)',
                                    color: illReturnFeedback[loan.id].kind==='ok'
                                      ? '#4ade80' : '#f87171' }}>
                        {illReturnFeedback[loan.id].msg}
                      </div>
                    )}
                  </>
                ) : (
                  <div style={{ fontSize:'.78rem', color:'var(--brand-muted)', marginTop:8, fontStyle:'italic' }}>
                    {t({ id:'biblioteca.ill.return.notInPhase' })}
                  </div>
                )}
              </div>
            )}
          </div>);
        })}</div>
      </div>)}

      {/* ═══ 7b. Partage numérique inter-biblios (ILL-digital, I3) ═══ */}
      <LibraryDigitalSharesSection libraryId={libraryId} canEdit={isCoord} />
    </div>
  );
}
