// =============================================================================
// ExchangeProposalForm.jsx
// =============================================================================
// Etape 10 du chantier-cadre Biblioteca (EA-11, exchanges).
//
//   PAQUET 1 — fondations + proposition de troca (livre le 23/05).
//   PAQUET 2 — eligibilite & gouvernance completes (ce fichier).
//
// PAQUET 2 : le filtre minimal « >= 2 exemplaires » du paquet 1 est remplace
// par le vrai filtrage d'eligibilite, fonde sur la politique de gouvernance
// de la bibliotheque (library_document_governance.config.interlibrary_exchange).
//
//   - Les regles sont normalisees par normalizeExchangeRules(), reprise A
//     L'IDENTIQUE de la logique interlibrary_exchange de normalizeConfig()
//     dans DocumentGovernanceSection.jsx (EA-08). Cette reprise garantit que
//     l'eligibilite cote exchanges utilise exactement les memes regles que
//     celles que l'editeur de gouvernance ecrit. Memes conventions de defaut :
//     enabled/require_available_now !== false ; mutualization_only === true ;
//     min_total_copies plancher 2 ; min_available_copies plancher 1.
//
//   - buildExchangeEligibility() porte le verdict du HTML d'origine : un
//     document est `ready` si total >= min_total_copies ET (si
//     require_available_now) available >= min_available_copies. Fournit aussi
//     keep_after_exchange et un summary lisible.
//
//   - La disponibilite reelle vient de book_holdings.available_count. Quand un
//     document n'a pas de holding (cas legacy), on retombe sur la contagem
//     simple d'exemplaires et on le signale (caution), fidele au HTML.
//
// NOTE PERIMETRE : l'EDITEUR de la politique interlibrary_exchange n'est PAS
// ici. Il appartient a l'onglet gouvernance (DocumentGovernanceSection, EA-08).
// Ce composant LIT la politique, il ne l'ecrit pas. Si la cle
// interlibrary_exchange est absente du config (cas frequent), les regles par
// defaut s'appliquent.
//
// Doctrine RPC v3 : lectures (exemplares, book_holdings, books,
// library_document_governance) via supabase.from() - lectures simples
// protegees par RLS. Ecriture de la proposition via la RPC
// create_document_permission_request. Aucun DDL.
// =============================================================================

import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

// Styles alignes sur ceux de BibliotecaPage (champs, labels).
const fs = { width:'100%', padding:'10px 12px', borderRadius:8, border:'1px solid rgba(255,255,255,.12)', background:'rgba(0,0,0,.3)', color:'#f4f4f4', fontSize:'.9rem' };
const ls = { display:'block', fontSize:'.85rem', fontWeight:600, marginBottom:3, color:'var(--brand-muted, #ccc)' };

// --- Normalisation des regles d'echange -------------------------------------
// REPRISE A L'IDENTIQUE de la partie interlibrary_exchange de normalizeConfig()
// dans DocumentGovernanceSection.jsx (EA-08). Toute evolution des conventions
// de defaut doit rester synchronisee entre les deux composants.
function normalizeExchangeRules(rawConfig) {
  const cfg = rawConfig && typeof rawConfig === 'object' ? rawConfig : {};
  const ie = cfg.interlibrary_exchange && typeof cfg.interlibrary_exchange === 'object'
    ? cfg.interlibrary_exchange : {};
  return {
    enabled:               ie.enabled !== false,
    mutualization_only:    ie.mutualization_only === true,
    require_available_now: ie.require_available_now !== false,
    min_total_copies:      Math.max(2, Number(ie.min_total_copies || 2) || 2),
    min_available_copies:  Math.max(1, Number(ie.min_available_copies || 2) || 2),
    policy_note:           typeof ie.policy_note === 'string' ? ie.policy_note : '',
    guardrail_note:        typeof ie.guardrail_note === 'string' ? ie.guardrail_note : '',
  };
}

// --- Verdict d'eligibilite d'un document ------------------------------------
// Porte buildExchangeEligibility du HTML d'origine. `doc` doit porter :
//   count (total exemplaires), available_count, has_holding_data.
function buildExchangeEligibility(doc, rules, t) {
  const totalCopies = Math.max(Number(doc?.count || 0) || 0, 0);
  const availableCount = Math.max(Number(doc?.available_count ?? totalCopies) || 0, 0);
  const reasons = [];
  if (totalCopies < rules.min_total_copies) {
    reasons.push(t({ id: 'biblioteca.exchanges.elig.reasonTotal' }, { min: rules.min_total_copies }));
  }
  if (rules.require_available_now && availableCount < rules.min_available_copies) {
    reasons.push(t({ id: 'biblioteca.exchanges.elig.reasonAvailable' }, { min: rules.min_available_copies }));
  }
  const ready = reasons.length === 0;
  return {
    ready,
    total_copies: totalCopies,
    available_count: availableCount,
    keep_after_exchange: Math.max(availableCount - 1, 0),
    reasons,
    // Caution : disponibilite calculee par simple comptage faute de holding.
    caution: !doc?.has_holding_data ? t({ id: 'biblioteca.exchanges.elig.caution' }) : '',
    summary: ready
      ? t({ id: 'biblioteca.exchanges.elig.ready' }, { total: totalCopies, available: availableCount })
      : t({ id: 'biblioteca.exchanges.elig.blocked' }, { reasons: reasons.join(' ; ') }),
  };
}

// --- Groupe les exemplaires par bib_ref, enrichit, evalue l'eligibilite -----
// Le filtrage retient TOUS les documents et marque leur eligibilite ; le
// rendu separe ensuite les documents aptes des bloques.
function groupAndEvaluate(exemplares, holdingsByRef, booksByRef, rules, t) {
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
  for (const g of grouped.values()) {
    const count = g.exemplar_ids.length;
    const book = booksByRef.get(g.bib_ref) || {};
    const holding = holdingsByRef.get(g.bib_ref) || null;
    const hasHolding = !!holding;
    // Disponibilite : holding si dispo, sinon comptage simple d'exemplaires.
    const availableCount = hasHolding
      ? Math.max(Number(holding.available_count || 0) || 0, 0)
      : count;
    const doc = {
      bib_ref: g.bib_ref,
      count,
      titulo: book.titulo || g.bib_ref,
      autor: book.autor || '',
      ano: book.ano || '',
      available_count: availableCount,
      has_holding_data: hasHolding,
    };
    doc.eligibility = buildExchangeEligibility(doc, rules, t);
    docs.push(doc);
  }
  // Tri : aptes d'abord, puis par disponibilite, puis par titre.
  docs.sort((a, b) =>
    (Number(b.eligibility.ready) - Number(a.eligibility.ready))
    || (b.available_count - a.available_count)
    || String(a.titulo).localeCompare(String(b.titulo))
  );
  return docs;
}

// --- Libelle d'affichage d'un document --------------------------------------
function formatDocLabel(doc) {
  if (!doc) return '—';
  const head = doc.titulo || doc.bib_ref;
  const bits = [];
  if (doc.autor) bits.push(doc.autor);
  bits.push(`${doc.count} ex. · ${doc.available_count} disp.`);
  bits.push(`bib_ref ${doc.bib_ref}`);
  return `${head} · ${bits.join(' · ')}`;
}

export default function ExchangeProposalForm({ libraryId, allLibraries = [], t }) {
  // --- Etats : donnees -------------------------------------------------------
  const [localDocs, setLocalDocs] = useState([]);
  const [partnerDocs, setPartnerDocs] = useState([]);
  const [loadingLocal, setLoadingLocal] = useState(false);
  const [loadingPartner, setLoadingPartner] = useState(false);
  // Regles d'echange de la bibliotheque locale (gouvernance).
  const [rules, setRules] = useState(() => normalizeExchangeRules({}));
  const [rulesLoaded, setRulesLoaded] = useState(false);

  // --- Etats : formulaire ----------------------------------------------------
  const [partnerId, setPartnerId] = useState('');
  const [localBibRef, setLocalBibRef] = useState('');
  const [partnerBibRef, setPartnerBibRef] = useState('');
  const [message, setMessage] = useState('');
  const [note, setNote] = useState('');

  // --- Etats : envoi ---------------------------------------------------------
  const [saving, setSaving] = useState(false);
  const [feedback, setFeedback] = useState(null);

  // --- Chargement des regles de gouvernance (politique d'echange locale) -----
  // Lecture simple .from() sous RLS, identique a DocumentGovernanceSection.
  useEffect(() => {
    let cancelled = false;
    if (!libraryId) return;
    supabase
      .from('library_document_governance')
      .select('config')
      .eq('library_id', libraryId)
      .maybeSingle()
      .then(({ data, error }) => {
        if (cancelled) return;
        if (error) {
          // Pas bloquant : on retombe sur les regles par defaut.
          setRules(normalizeExchangeRules({}));
        } else {
          setRules(normalizeExchangeRules(data?.config || {}));
        }
        setRulesLoaded(true);
      });
    return () => { cancelled = true; };
  }, [libraryId]);

  // --- Chargement des documents evalues d'une bibliotheque -------------------
  const fetchEvaluatedDocs = useCallback(async (targetLibraryId) => {
    if (!targetLibraryId) return [];
    // 1. Exemplaires de la bibliotheque.
    const { data: exemplares, error: exErr } = await supabase
      .from('exemplares')
      .select('id, bib_ref, tombo, library_id')
      .eq('library_id', targetLibraryId)
      .order('bib_ref', { ascending: true });
    if (exErr) throw exErr;

    const bibRefs = [...new Set((exemplares || []).map(e => String(e.bib_ref || '').trim()).filter(Boolean))];

    // 2. Books (titre, auteur) + holdings (disponibilite reelle), en parallele.
    const booksByRef = new Map();
    const holdingsByRef = new Map();
    if (bibRefs.length > 0) {
      const [booksRes, holdingsRes] = await Promise.all([
        supabase.from('books')
          .select('bib_ref, titulo, autor, ano')
          .in('bib_ref', bibRefs),
        supabase.from('book_holdings')
          .select('local_bib_ref, library_id, available_count, exemplares_total')
          .eq('library_id', targetLibraryId)
          .in('local_bib_ref', bibRefs),
      ]);
      if (booksRes.error) throw booksRes.error;
      if (holdingsRes.error) throw holdingsRes.error;
      for (const b of (booksRes.data || [])) {
        booksByRef.set(String(b.bib_ref || '').trim(), b);
      }
      for (const h of (holdingsRes.data || [])) {
        const ref = String(h.local_bib_ref || '').trim();
        if (ref) holdingsByRef.set(ref, h);
      }
    }
    return groupAndEvaluate(exemplares, holdingsByRef, booksByRef, rules, t);
  }, [rules, t]);

  // --- Chargement des surplus locaux (apres chargement des regles) -----------
  useEffect(() => {
    let cancelled = false;
    if (!libraryId || !rulesLoaded) return;
    setLoadingLocal(true);
    fetchEvaluatedDocs(libraryId)
      .then(docs => { if (!cancelled) setLocalDocs(docs); })
      .catch(err => {
        if (!cancelled) {
          setLocalDocs([]);
          setFeedback({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
        }
      })
      .finally(() => { if (!cancelled) setLoadingLocal(false); });
    return () => { cancelled = true; };
  }, [libraryId, rulesLoaded, fetchEvaluatedDocs, t]);

  // --- Chargement des documents du partenaire --------------------------------
  useEffect(() => {
    let cancelled = false;
    if (!partnerId || !rulesLoaded) { setPartnerDocs([]); setPartnerBibRef(''); return; }
    setLoadingPartner(true);
    fetchEvaluatedDocs(partnerId)
      .then(docs => { if (!cancelled) setPartnerDocs(docs); })
      .catch(err => {
        if (!cancelled) {
          setPartnerDocs([]);
          setFeedback({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
        }
      })
      .finally(() => { if (!cancelled) setLoadingPartner(false); });
    return () => { cancelled = true; };
  }, [partnerId, rulesLoaded, fetchEvaluatedDocs, t]);

  // --- Documents selectionnes ------------------------------------------------
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

  // Documents aptes (pour les selecteurs) et bloques (pour information).
  const localReady = useMemo(() => localDocs.filter(d => d.eligibility.ready), [localDocs]);
  const localBlocked = useMemo(() => localDocs.filter(d => !d.eligibility.ready), [localDocs]);
  const partnerReady = useMemo(() => partnerDocs.filter(d => d.eligibility.ready), [partnerDocs]);

  // --- Generation du message suggere -----------------------------------------
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

  // --- Reference de l'objet d'echange ----------------------------------------
  function buildObjectRef() {
    return JSON.stringify({
      type: 'interlibrary_exchange',
      local: selectedLocalDoc ? { bib_ref: selectedLocalDoc.bib_ref, titulo: selectedLocalDoc.titulo } : null,
      partner: selectedPartnerDoc ? { bib_ref: selectedPartnerDoc.bib_ref, titulo: selectedPartnerDoc.titulo } : null,
      note: note.trim() || undefined,
    });
  }

  // --- Envoi de la proposition -----------------------------------------------
  async function saveExchangeRequest() {
    setFeedback(null);
    if (!rules.enabled) {
      setFeedback({ text: t({ id: 'biblioteca.exchanges.disabledByPolicy' }), kind: 'error' });
      return;
    }
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
    // Securite : les documents choisis doivent etre aptes.
    if (!selectedLocalDoc.eligibility.ready || !selectedPartnerDoc.eligibility.ready) {
      setFeedback({ text: t({ id: 'biblioteca.exchanges.docNotEligible' }), kind: 'error' });
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
      setLocalBibRef('');
      setPartnerBibRef('');
      setMessage('');
      setNote('');
    } catch (err) {
      setFeedback({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setSaving(false);
    }
  }

  // --- Rendu -----------------------------------------------------------------
  const otherLibraries = allLibraries.filter(l => l.id !== libraryId);
  const fbColor = feedback?.kind === 'ok' ? '#34d399' : '#f87171';

  // Politique : trocas desactivees -> bandeau et formulaire neutralise.
  const policyDisabled = rulesLoaded && !rules.enabled;

  return (
    <div>
      <div style={{ border:'1px solid rgba(255,255,255,.08)', borderRadius:10, padding:14, marginBottom:14 }}>
        <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.exchanges.prepare' })}</h4>

        {/* Bandeau : trocas desactivees par la politique locale */}
        {policyDisabled && (
          <div style={{ fontSize:'.84rem', color:'#fbbf24', background:'rgba(251,191,36,.08)',
            border:'1px solid rgba(251,191,36,.2)', borderRadius:8, padding:'8px 10px', marginBottom:10 }}>
            {t({ id: 'biblioteca.exchanges.disabledByPolicy' })}
          </div>
        )}

        {/* Rappel des criteres d'eligibilite en vigueur */}
        {rulesLoaded && !policyDisabled && (
          <div style={{ fontSize:'.8rem', color:'var(--brand-muted)', marginBottom:10 }}>
            {t({ id: 'biblioteca.exchanges.elig.criteria' }, {
              total: rules.min_total_copies,
              available: rules.require_available_now
                ? t({ id: 'biblioteca.exchanges.elig.criteriaAvailable' }, { min: rules.min_available_copies })
                : t({ id: 'biblioteca.exchanges.elig.criteriaNoAvailable' }),
            })}
          </div>
        )}

        <div className="cat-book-grid" style={{ marginBottom:10 }}>
          {/* Partenaire */}
          <div className="cat-field">
            <label style={ls}>{t({ id: 'biblioteca.exchanges.partner' })}</label>
            <select value={partnerId} onChange={e => setPartnerId(e.target.value)} style={fs} disabled={policyDisabled}>
              <option value="">{t({ id: 'biblioteca.exchanges.selectPartner' })}</option>
              {otherLibraries.map(l => (
                <option key={l.id} value={l.id}>{l.name} ({l.short_name})</option>
              ))}
            </select>
          </div>

          {/* Document local apte */}
          <div className="cat-field">
            <label style={ls}>{t({ id: 'biblioteca.exchanges.localDoc' })}</label>
            <select value={localBibRef} onChange={e => setLocalBibRef(e.target.value)} style={fs}
              disabled={policyDisabled || loadingLocal}>
              <option value="">
                {loadingLocal
                  ? t({ id: 'biblioteca.exchanges.loading' })
                  : (localReady.length ? t({ id: 'biblioteca.exchanges.selectDoc' }) : t({ id: 'biblioteca.exchanges.noSurplus' }))}
              </option>
              {localReady.map(d => (
                <option key={d.bib_ref} value={d.bib_ref}>{formatDocLabel(d)}</option>
              ))}
            </select>
            {/* Information : documents locaux bloques par les criteres */}
            {!loadingLocal && localBlocked.length > 0 && (
              <div style={{ fontSize:'.76rem', color:'var(--brand-muted)', marginTop:4 }}>
                {t({ id: 'biblioteca.exchanges.elig.blockedCount' }, { count: localBlocked.length })}
              </div>
            )}
          </div>

          {/* Document du partenaire apte */}
          <div className="cat-field">
            <label style={ls}>{t({ id: 'biblioteca.exchanges.wantedDoc' })}</label>
            <select value={partnerBibRef} onChange={e => setPartnerBibRef(e.target.value)} style={fs}
              disabled={policyDisabled || !partnerId || loadingPartner}>
              <option value="">
                {!partnerId
                  ? t({ id: 'biblioteca.exchanges.selectPartnerFirst' })
                  : loadingPartner
                    ? t({ id: 'biblioteca.exchanges.loading' })
                    : (partnerReady.length ? t({ id: 'biblioteca.exchanges.selectDoc' }) : t({ id: 'biblioteca.exchanges.partnerNoSurplus' }))}
              </option>
              {partnerReady.map(d => (
                <option key={d.bib_ref} value={d.bib_ref}>{formatDocLabel(d)}</option>
              ))}
            </select>
          </div>

          {/* Note interne */}
          <div className="cat-field">
            <label style={ls}>{t({ id: 'biblioteca.exchanges.note' })}</label>
            <textarea value={note} onChange={e => setNote(e.target.value)} style={{ ...fs, resize:'vertical' }} rows={3}
              placeholder={t({ id: 'biblioteca.exchanges.notePlaceholder' })} disabled={policyDisabled} />
          </div>

          {/* Message */}
          <div className="cat-field" style={{ gridColumn:'span 2' }}>
            <label style={ls}>{t({ id: 'biblioteca.exchanges.message' })}</label>
            <textarea value={message} onChange={e => setMessage(e.target.value)} style={{ ...fs, resize:'vertical' }} rows={6}
              placeholder={t({ id: 'biblioteca.exchanges.messagePlaceholder' })} disabled={policyDisabled} />
          </div>
        </div>

        {/* Verdict d'eligibilite des deux documents choisis */}
        {(selectedLocalDoc || selectedPartnerDoc) && (
          <div style={{ fontSize:'.8rem', color:'var(--brand-muted)', marginBottom:10 }}>
            {selectedLocalDoc && (
              <div>{t({ id: 'biblioteca.exchanges.localDoc' })} : {selectedLocalDoc.eligibility.summary}
                {selectedLocalDoc.eligibility.caution && ` (${selectedLocalDoc.eligibility.caution})`}</div>
            )}
            {selectedPartnerDoc && (
              <div>{t({ id: 'biblioteca.exchanges.wantedDoc' })} : {selectedPartnerDoc.eligibility.summary}
                {selectedPartnerDoc.eligibility.caution && ` (${selectedPartnerDoc.eligibility.caution})`}</div>
            )}
          </div>
        )}

        <div style={{ display:'flex', gap:8, flexWrap:'wrap' }}>
          <button className="cat-btn secondary" style={{ fontSize:'.88rem' }}
            onClick={generateSuggestedMessage} disabled={policyDisabled}>
            {t({ id: 'biblioteca.exchanges.generateMessage' })}
          </button>
          <button className="cat-btn primary" style={{ fontSize:'.88rem' }}
            onClick={saveExchangeRequest} disabled={saving || policyDisabled}>
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
