// =============================================================================
// ExchangeProposalForm.jsx
// =============================================================================
// Etape 10 du chantier-cadre Biblioteca (EA-11, exchanges) — PAQUET 1 :
// fondations + proposition de troca interbibliotecas.
//
// Ce composant encapsule :
//   1.A — fondations de donnees : chargement des documents en surplus de la
//         bibliotheque locale et de la bibliotheque partenaire selectionnee.
//   1.B — formulaire de proposition vivant : selecteurs partenaire / document
//         local / document partenaire, message (avec generation d'un message
//         suggere), note interne.
//   1.C — saveExchangeRequest : envoi via la RPC create_document_permission_request
//         (object_type 'interlibrary_exchange'), avec gestion explicite de
//         l'erreur.
//
// PERIMETRE PAQUET 1 — eligibilite MINIMALE (arbitrage du 22/05) : un document
// est « en surplus » s'il a au moins 2 exemplaires. La version complete de
// buildExchangeEligibility (regles de gouvernance cfg.interlibrary_exchange :
// min_total_copies, min_available_copies, require_available_now, etc.) est
// reportee au PAQUET 2.
//
// Backend : entierement en place. create_document_permission_request insere
// dans document_permission_requests (status 'pending'), valide les deux
// library_id + user_can_manage_library, exige un message non vide.
//
// Doctrine RPC v3 : les lectures (exemplares, book_holdings, books) passent par
// supabase.from() — lectures simples protegees par RLS. L'ecriture passe par
// la RPC. Aucun DDL : le backend exchanges preexiste.
// =============================================================================

import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '@/lib/supabase';

// Styles alignes sur ceux de BibliotecaPage (champs, labels, lignes, wrappers).
const fs = { width:'100%', padding:'10px 12px', borderRadius:8, border:'1px solid rgba(255,255,255,.12)', background:'rgba(0,0,0,.3)', color:'#f4f4f4', fontSize:'.9rem' };
const ls = { display:'block', fontSize:'.85rem', fontWeight:600, marginBottom:3, color:'var(--brand-muted, #ccc)' };

// --- Helper : groupe les exemplaires par bib_ref et calcule le surplus -------
// Eligibilite minimale paquet 1 : count >= 2.
function groupSurplusDocs(exemplares, booksByRef) {
  const grouped = new Map();
  for (const row of (exemplares || [])) {
    const bibRef = String(row?.bib_ref || '').trim();
    if (!bibRef) continue;
    if (!grouped.has(bibRef)) {
      grouped.set(bibRef, { bib_ref: bibRef, exemplar_ids: [], tombos: [] });
    }
    const bucket = grouped.get(bibRef);
    bucket.exemplar_ids.push(row.id);
    if (row.tombo) bucket.tombos.push(row.tombo);
  }
  const docs = [];
  for (const doc of grouped.values()) {
    const count = doc.exemplar_ids.length;
    // Eligibilite minimale : au moins 2 exemplaires (un cessible, un conserve).
    if (count < 2) continue;
    const book = booksByRef.get(doc.bib_ref) || {};
    docs.push({
      bib_ref: doc.bib_ref,
      count,
      titulo: book.titulo || doc.bib_ref,
      autor: book.autor || '',
      ano: book.ano || '',
    });
  }
  // Tri : plus d'exemplaires d'abord, puis par titre.
  docs.sort((a, b) => (b.count - a.count) || String(a.titulo).localeCompare(String(b.titulo)));
  return docs;
}

// --- Helper : libelle d'affichage d'un document -------------------------------
function formatDocLabel(doc) {
  if (!doc) return '—';
  const head = doc.titulo || doc.bib_ref;
  const bits = [];
  if (doc.autor) bits.push(doc.autor);
  bits.push(`${doc.count} exemplar(es)`);
  bits.push(`bib_ref ${doc.bib_ref}`);
  return `${head} · ${bits.join(' · ')}`;
}

export default function ExchangeProposalForm({ libraryId, allLibraries = [], t }) {
  // --- Etats : donnees -------------------------------------------------------
  const [localDocs, setLocalDocs] = useState([]);       // surplus de la biblio locale
  const [partnerDocs, setPartnerDocs] = useState([]);   // surplus du partenaire choisi
  const [loadingLocal, setLoadingLocal] = useState(false);
  const [loadingPartner, setLoadingPartner] = useState(false);

  // --- Etats : formulaire ----------------------------------------------------
  const [partnerId, setPartnerId] = useState('');
  const [localBibRef, setLocalBibRef] = useState('');
  const [partnerBibRef, setPartnerBibRef] = useState('');
  const [message, setMessage] = useState('');
  const [note, setNote] = useState('');

  // --- Etats : envoi ---------------------------------------------------------
  const [saving, setSaving] = useState(false);
  const [feedback, setFeedback] = useState(null); // { text, kind: 'ok'|'error' }

  // --- Chargement des documents en surplus d'une bibliotheque ----------------
  // Lit exemplares -> groupe par bib_ref -> enrichit via books. RLS gere l'acces.
  const fetchSurplusDocs = useCallback(async (targetLibraryId) => {
    if (!targetLibraryId) return [];
    const { data: exemplares, error: exErr } = await supabase
      .from('exemplares')
      .select('id, bib_ref, tombo, library_id')
      .eq('library_id', targetLibraryId)
      .order('bib_ref', { ascending: true });
    if (exErr) throw exErr;

    const bibRefs = [...new Set((exemplares || []).map(e => String(e.bib_ref || '').trim()).filter(Boolean))];
    const booksByRef = new Map();
    if (bibRefs.length > 0) {
      const { data: books, error: bkErr } = await supabase
        .from('books')
        .select('bib_ref, titulo, autor, ano')
        .in('bib_ref', bibRefs);
      if (bkErr) throw bkErr;
      for (const b of (books || [])) booksByRef.set(String(b.bib_ref || '').trim(), b);
    }
    return groupSurplusDocs(exemplares, booksByRef);
  }, []);

  // --- 1.A : chargement initial des surplus locaux ---------------------------
  useEffect(() => {
    let cancelled = false;
    if (!libraryId) return;
    setLoadingLocal(true);
    fetchSurplusDocs(libraryId)
      .then(docs => { if (!cancelled) setLocalDocs(docs); })
      .catch(err => {
        if (!cancelled) {
          setLocalDocs([]);
          setFeedback({ text: t({ id: 'common.errorPrefix' }, { message: err.message }), kind: 'error' });
        }
      })
      .finally(() => { if (!cancelled) setLoadingLocal(false); });
    return () => { cancelled = true; };
  }, [libraryId, fetchSurplusDocs, t]);

  // --- 1.A : chargement des surplus du partenaire au changement de selection -
  useEffect(() => {
    let cancelled = false;
    if (!partnerId) { setPartnerDocs([]); setPartnerBibRef(''); return; }
    setLoadingPartner(true);
    fetchSurplusDocs(partnerId)
      .then(docs => { if (!cancelled) setPartnerDocs(docs); })
      .catch(err => {
        if (!cancelled) {
          setPartnerDocs([]);
          setFeedback({ text: t({ id: 'common.errorPrefix' }, { message: err.message }), kind: 'error' });
        }
      })
      .finally(() => { if (!cancelled) setLoadingPartner(false); });
    return () => { cancelled = true; };
  }, [partnerId, fetchSurplusDocs, t]);

  // --- Documents selectionnes (objets complets) ------------------------------
  const selectedLocalDoc = useMemo(
    () => localDocs.find(d => d.bib_ref === localBibRef) || null,
    [localDocs, localBibRef]
  );
  const selectedPartnerDoc = useMemo(
    () => partnerDocs.find(d => d.bib_ref === partnerBibRef) || null,
    [partnerDocs, partnerBibRef]
  );
  const partnerRow = useMemo(
    () => allLibraries.find(l => l.id === partnerId) || null,
    [allLibraries, partnerId]
  );

  // --- 1.B : generation du message suggere -----------------------------------
  // Porte l'esprit de buildExchangeSuggestedMessage du HTML d'origine, via i18n.
  function generateSuggestedMessage() {
    if (!partnerRow) {
      setFeedback({ text: t({ id: 'biblioteca.exchanges.needPartner' }), kind: 'error' });
      return;
    }
    if (!selectedLocalDoc || !selectedPartnerDoc) {
      setFeedback({ text: t({ id: 'biblioteca.exchanges.needBothDocs' }), kind: 'error' });
      return;
    }
    const suggested = t({ id: 'biblioteca.exchanges.suggestedMessage' }, {
      partner: partnerRow.name || partnerRow.short_name || '',
      localDoc: formatDocLabel(selectedLocalDoc),
      partnerDoc: formatDocLabel(selectedPartnerDoc),
    });
    setMessage(suggested);
    setFeedback(null);
  }

  // --- 1.B : reference de l'objet d'echange (object_ref) ---------------------
  // Construit une reference JSON compacte des deux documents (tracabilite).
  function buildObjectRef() {
    return JSON.stringify({
      type: 'interlibrary_exchange',
      local: selectedLocalDoc ? { bib_ref: selectedLocalDoc.bib_ref, titulo: selectedLocalDoc.titulo } : null,
      partner: selectedPartnerDoc ? { bib_ref: selectedPartnerDoc.bib_ref, titulo: selectedPartnerDoc.titulo } : null,
      note: note.trim() || undefined,
    });
  }

  // --- 1.C : envoi de la proposition -----------------------------------------
  async function saveExchangeRequest() {
    setFeedback(null);
    // Validations cote client (la RPC revalide de toute facon).
    if (!partnerId) {
      setFeedback({ text: t({ id: 'biblioteca.exchanges.needPartner' }), kind: 'error' });
      return;
    }
    if (partnerId === libraryId) {
      setFeedback({ text: t({ id: 'biblioteca.exchanges.partnerSameAsLocal' }), kind: 'error' });
      return;
    }
    if (!selectedLocalDoc || !selectedPartnerDoc) {
      setFeedback({ text: t({ id: 'biblioteca.exchanges.needBothDocs' }), kind: 'error' });
      return;
    }
    if (!message.trim()) {
      setFeedback({ text: t({ id: 'biblioteca.exchanges.needMessage' }), kind: 'error' });
      return;
    }

    setSaving(true);
    try {
      const { error } = await supabase.rpc('create_document_permission_request', {
        p_requester_library_id: libraryId,
        p_target_library_id: partnerId,
        p_request: {
          requested_action: 'proposta_troca_exemplares',
          object_type: 'interlibrary_exchange',
          object_ref: buildObjectRef(),
          message: message.trim(),
        },
      });
      if (error) throw error;

      setFeedback({ text: t({ id: 'biblioteca.exchanges.created' }), kind: 'ok' });
      // Reinitialise le formulaire (le partenaire reste, pour enchainer).
      setLocalBibRef('');
      setPartnerBibRef('');
      setMessage('');
      setNote('');
    } catch (err) {
      setFeedback({ text: t({ id: 'common.errorPrefix' }, { message: err.message }), kind: 'error' });
    } finally {
      setSaving(false);
    }
  }

  // --- Rendu -----------------------------------------------------------------
  const otherLibraries = allLibraries.filter(l => l.id !== libraryId);
  const fbColor = feedback?.kind === 'ok' ? '#34d399' : '#f87171';

  return (
    <div>
      <div style={{ border:'1px solid rgba(255,255,255,.08)', borderRadius:10, padding:14, marginBottom:14 }}>
        <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.exchanges.prepare' })}</h4>

        <div className="cat-book-grid" style={{ marginBottom:10 }}>
          {/* Partenaire */}
          <div className="cat-field">
            <label style={ls}>{t({ id: 'biblioteca.exchanges.partner' })}</label>
            <select value={partnerId} onChange={e => setPartnerId(e.target.value)} style={fs}>
              <option value="">{t({ id: 'biblioteca.exchanges.selectPartner' })}</option>
              {otherLibraries.map(l => (
                <option key={l.id} value={l.id}>{l.name} ({l.short_name})</option>
              ))}
            </select>
          </div>

          {/* Document local en surplus */}
          <div className="cat-field">
            <label style={ls}>{t({ id: 'biblioteca.exchanges.localDoc' })}</label>
            <select value={localBibRef} onChange={e => setLocalBibRef(e.target.value)} style={fs} disabled={loadingLocal}>
              <option value="">
                {loadingLocal
                  ? t({ id: 'biblioteca.exchanges.loading' })
                  : (localDocs.length ? t({ id: 'biblioteca.exchanges.selectDoc' }) : t({ id: 'biblioteca.exchanges.noSurplus' }))}
              </option>
              {localDocs.map(d => (
                <option key={d.bib_ref} value={d.bib_ref}>{formatDocLabel(d)}</option>
              ))}
            </select>
          </div>

          {/* Document du partenaire */}
          <div className="cat-field">
            <label style={ls}>{t({ id: 'biblioteca.exchanges.wantedDoc' })}</label>
            <select value={partnerBibRef} onChange={e => setPartnerBibRef(e.target.value)} style={fs} disabled={!partnerId || loadingPartner}>
              <option value="">
                {!partnerId
                  ? t({ id: 'biblioteca.exchanges.selectPartnerFirst' })
                  : loadingPartner
                    ? t({ id: 'biblioteca.exchanges.loading' })
                    : (partnerDocs.length ? t({ id: 'biblioteca.exchanges.selectDoc' }) : t({ id: 'biblioteca.exchanges.partnerNoSurplus' }))}
              </option>
              {partnerDocs.map(d => (
                <option key={d.bib_ref} value={d.bib_ref}>{formatDocLabel(d)}</option>
              ))}
            </select>
          </div>

          {/* Note interne */}
          <div className="cat-field">
            <label style={ls}>{t({ id: 'biblioteca.exchanges.note' })}</label>
            <textarea value={note} onChange={e => setNote(e.target.value)} style={{ ...fs, resize:'vertical' }} rows={3}
              placeholder={t({ id: 'biblioteca.exchanges.notePlaceholder' })} />
          </div>

          {/* Message de la proposition */}
          <div className="cat-field" style={{ gridColumn:'span 2' }}>
            <label style={ls}>{t({ id: 'biblioteca.exchanges.message' })}</label>
            <textarea value={message} onChange={e => setMessage(e.target.value)} style={{ ...fs, resize:'vertical' }} rows={6}
              placeholder={t({ id: 'biblioteca.exchanges.messagePlaceholder' })} />
          </div>
        </div>

        <div style={{ display:'flex', gap:8, flexWrap:'wrap' }}>
          <button className="cat-btn secondary" style={{ fontSize:'.88rem' }} onClick={generateSuggestedMessage}>
            {t({ id: 'biblioteca.exchanges.generateMessage' })}
          </button>
          <button className="cat-btn primary" style={{ fontSize:'.88rem' }} onClick={saveExchangeRequest} disabled={saving}>
            {saving ? t({ id: 'biblioteca.exchanges.registering' }) : t({ id: 'biblioteca.exchanges.register' })}
          </button>
        </div>

        {feedback && (
          <div style={{ fontSize:'.84rem', color:fbColor, marginTop:10 }}>
            {feedback.text}
          </div>
        )}
      </div>
    </div>
  );
}
