// ─────────────────────────────────────────────────────────────────────────────
// NUMDIF D15 (15/10/2026, REGISTRE §47 NUMDIF-1, 2, 5) — « Candidats PDF » :
// la file des PDF trouvés ailleurs pour les notices que détient la
// bibliothèque. L'outil de recherche (scripts/numdif_recherche_pdf.mjs, D14)
// propose ; la coordination de la bibliothèque détentrice décide, PDF ouvert.
//
// Pour chaque candidat : la notice (l'exemplaire détenu) à côté de ce que
// l'outil a lu sur la page de titre du fichier téléchargé, l'extrait de cette
// page, les liens vers le fichier et la page de la source ; puis la décision —
// valider (même édition seulement, cas de source, justification, et pour une
// licence libre la mention citée avec sa page) ou rejeter avec motif. Un
// candidat validé passe « à verser ».
//
// Portes : fn_digital_candidates_list, fn_digital_candidates_propose (charger
// le fichier de l'outil), fn_digital_candidate_decide. La portée est tenue par
// la base : une autre bibliothèque ne voit rien.
// ─────────────────────────────────────────────────────────────────────────────
import { useCallback, useEffect, useRef, useState } from 'react';
import { useIntl } from 'react-intl';
import { supabase, SUPABASE_URL } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { erreurDeFonction } from '@/lib/edgeError';

const PAGE = 20;
export const STATUTS = ['propose', 'valide', 'rejete', 'verse'];
export const VERDICTS = ['meme_edition', 'autre_edition', 'texte_ressaisi'];
export const CAS = ['domaine_public', 'diffusion_autorisee', 'anti_copyright', 'statut_inconnu'];
export const CAS_LICENCE = new Set(['diffusion_autorisee', 'anti_copyright']);
const CONTROLES = ['titre', 'editeur', 'lieu', 'annee', 'traduction', 'isbn'];
const AVERTISSEMENTS = ['sans_couche_texte', 'isbn_different', 'titre_peu_trouve', 'lieu_absent_de_la_notice', 'traduction_a_verifier'];

// Le fichier de l'outil D14 : { candidates: [...] } ou une liste nue. Chaque
// candidat porte sa bibliothèque détentrice (library_id) ; à défaut, la
// bibliothèque active. Rend Map(bibliothèque → candidats).
export function lireFichierCandidats(texte, bibliothequeParDefaut) {
  let brut;
  try { brut = JSON.parse(texte); } catch { throw new Error('error.digital_candidate.bad_payload'); }
  const liste = Array.isArray(brut) ? brut : brut?.candidates;
  if (!Array.isArray(liste) || liste.length === 0) throw new Error('error.digital_candidate.bad_payload');
  const parBib = new Map();
  for (const c of liste) {
    if (!c || typeof c !== 'object') continue;
    const lib = c.library_id || bibliothequeParDefaut;
    if (!lib) throw new Error('importacoes.pdfCandidates.import.noLibrary');
    if (!parBib.has(lib)) parBib.set(lib, []);
    parBib.get(lib).push(c);
  }
  return parBib;
}

// Une justification à relire, pas à signer : le cas la suggère.
export function justificationSuggeree(c, cas, t) {
  const b = c.book || {};
  if (cas === 'domaine_public') {
    const deces = Array.isArray(c.tool_notes?.deces) ? c.tool_notes.deces.join(', ') : '';
    return t({ id: 'importacoes.pdfCandidates.justif.domainePublic' }, { deces: deces || '…' });
  }
  if (CAS_LICENCE.has(cas)) {
    return t({ id: 'importacoes.pdfCandidates.justif.licence' },
      { page: c.rights_mention_page || c.proposed_mention_page || '…', mention: c.rights_mention || c.proposed_mention || '…' });
  }
  return t({ id: 'importacoes.pdfCandidates.justif.statutInconnu' }, { library: c.library_name || '…', ref: b.bib_ref || '…' });
}

const editionNotice = (b) => [b.editora, b.local_publicacao, b.ano].filter(Boolean).join(', ');
const editionTrouvee = (c) => [c.found_publisher, c.found_place, c.found_year].filter(Boolean).join(', ');
const muted = { fontSize: '.8rem', color: 'var(--brand-muted, #94a3b8)' };
const pill = (fond) => ({
  display: 'inline-block', padding: '1px 8px', borderRadius: 999, fontSize: '.75rem', marginRight: 6,
  background: fond, color: 'var(--brand-text, inherit)', border: '1px solid rgba(255,255,255,.12)',
});
const FOND_VERDICT = { meme_edition: 'rgba(34,197,94,.18)', autre_edition: 'rgba(234,179,8,.18)', texte_ressaisi: 'rgba(239,68,68,.15)' };

function Ligne({ label, value }) {
  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'minmax(0, 9rem) minmax(0, 1fr)', gap: 8, fontSize: '.85rem', padding: '2px 0' }}>
      <span style={muted}>{label}</span>
      <span style={{ overflowWrap: 'anywhere' }}>{value || '—'}</span>
    </div>
  );
}

function Decision({ c, t, onDone }) {
  const [verdict, setVerdict] = useState(c.verdict || c.proposed_verdict || 'meme_edition');
  const [cas, setCas] = useState(c.source_case || c.proposed_case || 'statut_inconnu');
  const [mention, setMention] = useState(c.rights_mention || c.proposed_mention || '');
  const [mentionPage, setMentionPage] = useState(c.rights_mention_page || c.proposed_mention_page || '');
  const [justification, setJustification] = useState(() => justificationSuggeree(c, c.source_case || c.proposed_case || 'statut_inconnu', t));
  const [pageUrl, setPageUrl] = useState(c.page_url || '');
  const [motif, setMotif] = useState(() => (editionTrouvee(c)
    ? t({ id: 'importacoes.pdfCandidates.reason.otherEdition' }, { edition: editionTrouvee(c) }) : ''));
  const [occupe, setOccupe] = useState(false);
  const [erreur, setErreur] = useState('');

  const changerCas = (v) => {
    setCas(v);
    // la suggestion suit le cas tant qu'on ne l'a pas réécrite
    setJustification((j) => (j === justificationSuggeree(c, cas, t) ? justificationSuggeree(c, v, t) : j));
  };

  const decider = async (decision) => {
    setOccupe(true); setErreur('');
    try {
      const { data, error } = await supabase.rpc('fn_digital_candidate_decide', {
        p_id: c.id, p_decision: decision,
        p_verdict: verdict, p_source_case: cas,
        p_justification: decision === 'valider' ? justification : null,
        p_rights_mention: CAS_LICENCE.has(cas) ? mention : null,
        p_rights_mention_page: CAS_LICENCE.has(cas) ? mentionPage : null,
        p_page_url: pageUrl || null,
        p_rejection_reason: decision === 'rejeter' ? motif : null,
      });
      if (error) throw error;
      onDone?.(data?.status === 'valide'
        ? t({ id: 'importacoes.pdfCandidates.done.validated' }) : t({ id: 'importacoes.pdfCandidates.done.rejected' }));
    } catch (e) {
      setErreur(localizeError(e, t));
    } finally {
      setOccupe(false);
    }
  };

  const peutValider = c.status === 'propose';
  return (
    <div data-testid="pdf-candidate-decision" style={{ marginTop: 12, paddingTop: 10, borderTop: '1px solid rgba(255,255,255,.08)' }}>
      {peutValider && (<>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 14rem), 1fr))', gap: 10 }}>
          <div className="ab-field">
            <label className="ab-field__label" htmlFor={`pdfc-verdict-${c.id}`}>{t({ id: 'importacoes.pdfCandidates.form.verdict' })}</label>
            <select id={`pdfc-verdict-${c.id}`} className="ab-select" value={verdict} onChange={(e) => setVerdict(e.target.value)} disabled={occupe}>
              {VERDICTS.map((v) => <option key={v} value={v}>{t({ id: `importacoes.pdfCandidates.verdict.${v}` })}</option>)}
            </select>
          </div>
          <div className="ab-field">
            <label className="ab-field__label" htmlFor={`pdfc-case-${c.id}`}>{t({ id: 'importacoes.pdfCandidates.form.case' })}</label>
            <select id={`pdfc-case-${c.id}`} className="ab-select" value={cas} onChange={(e) => changerCas(e.target.value)} disabled={occupe}>
              {CAS.map((v) => <option key={v} value={v}>{t({ id: `importacoes.pdfCandidates.case.${v}` })}</option>)}
            </select>
          </div>
          <div className="ab-field">
            <label className="ab-field__label" htmlFor={`pdfc-page-${c.id}`}>{t({ id: 'importacoes.pdfCandidates.form.pageUrl' })}</label>
            <input id={`pdfc-page-${c.id}`} className="ab-input" type="url" value={pageUrl} onChange={(e) => setPageUrl(e.target.value)} disabled={occupe} />
          </div>
        </div>
        <p style={{ ...muted, margin: '6px 0' }}>{t({ id: `importacoes.pdfCandidates.caseHint.${cas}` })}</p>
        {CAS_LICENCE.has(cas) && (
          <div style={{ display: 'grid', gridTemplateColumns: 'minmax(0, 1fr) minmax(0, 7rem)', gap: 10 }}>
            <div className="ab-field">
              <label className="ab-field__label" htmlFor={`pdfc-mention-${c.id}`}>{t({ id: 'importacoes.pdfCandidates.form.mention' })}</label>
              <textarea id={`pdfc-mention-${c.id}`} className="ab-input" rows={3} value={mention} onChange={(e) => setMention(e.target.value)} disabled={occupe} />
            </div>
            <div className="ab-field">
              <label className="ab-field__label" htmlFor={`pdfc-mpage-${c.id}`}>{t({ id: 'importacoes.pdfCandidates.form.mentionPage' })}</label>
              <input id={`pdfc-mpage-${c.id}`} className="ab-input" value={mentionPage} onChange={(e) => setMentionPage(e.target.value)} disabled={occupe} />
            </div>
          </div>
        )}
        <div className="ab-field">
          <label className="ab-field__label" htmlFor={`pdfc-justif-${c.id}`}>{t({ id: 'importacoes.pdfCandidates.form.justification' })}</label>
          <textarea id={`pdfc-justif-${c.id}`} className="ab-input" rows={2} value={justification} onChange={(e) => setJustification(e.target.value)} disabled={occupe} />
        </div>
        {verdict !== 'meme_edition' && (
          <p data-testid="pdf-candidate-same-edition-only" style={{ ...muted, color: 'var(--brand-warning, #eab308)' }}>
            {t({ id: 'importacoes.pdfCandidates.form.sameEditionOnly' })}
          </p>
        )}
      </>)}
      <div className="ab-field">
        <label className="ab-field__label" htmlFor={`pdfc-reason-${c.id}`}>{t({ id: 'importacoes.pdfCandidates.form.reason' })}</label>
        <textarea id={`pdfc-reason-${c.id}`} className="ab-input" rows={2} value={motif} onChange={(e) => setMotif(e.target.value)} disabled={occupe} />
      </div>
      {erreur && <div className="cat-message error" role="alert" style={{ margin: '8px 0' }}>{erreur}</div>}
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginTop: 8 }}>
        {peutValider && (
          <button type="button" className="cat-btn primary" data-testid="pdf-candidate-validate"
            disabled={occupe || verdict !== 'meme_edition'} onClick={() => decider('valider')}>
            {t({ id: 'importacoes.pdfCandidates.validate' })}
          </button>
        )}
        <button type="button" className="cat-btn secondary" data-testid="pdf-candidate-reject"
          disabled={occupe} onClick={() => decider('rejeter')}>
          {t({ id: 'importacoes.pdfCandidates.reject' })}
        </button>
      </div>
    </div>
  );
}

// NUMDIF D16 : le versement se fait côté serveur (deposit-digital-candidate),
// avec le jeton de la coordination ; la fonction télécharge l'URL validée,
// compare l'empreinte et refuse si elle diffère — le refus se dit ici, et il
// reste noté sur le candidat (deposit_error).
export async function appelerVersement(ids) {
  const { data: { session } } = await supabase.auth.getSession();
  const res = await fetch(`${SUPABASE_URL}/functions/v1/deposit-digital-candidate`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${session?.access_token}`,
      apikey: import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(ids.length === 1 ? { candidate_id: ids[0] } : { candidate_ids: ids }),
  });
  const out = await res.json().catch(() => ({}));
  if (!res.ok || out?.ok !== true) throw erreurDeFonction(out, res.status);
  return out;
}

// Par lots, avec reprise (consigne du 15/10) : les candidats « à verser »
// partent par paquets de LOT ; la fonction rend ce qu'elle n'a pas eu le temps
// de commencer (`remaining`), qui repart en tête. L'état vit en base : un lot
// arrêté ou interrompu se reprend en le relançant, rien de versé ne repasse ;
// les candidats déjà refusés n'y rentrent que si on le demande.
const LOT = 5;
export async function versementParLots(ids, appeler, { arrete = () => false, progres = () => {} } = {}) {
  const file = [...ids];
  const bilan = { total: ids.length, done: 0, failed: 0, arrete: false };
  while (file.length) {
    if (arrete()) { bilan.arrete = true; break; }
    const paquet = file.splice(0, LOT);
    const out = await appeler(paquet);
    const resultats = Array.isArray(out?.results) ? out.results : [{ id: paquet[0], ok: true }];
    for (const r of resultats) { if (r.ok) bilan.done += 1; else bilan.failed += 1; }
    if (Array.isArray(out?.remaining) && out.remaining.length) file.unshift(...out.remaining);
    progres({ ...bilan });
  }
  return bilan;
}

function VerserLeLot({ t, n, onFin }) {
  const [etat, setEtat] = useState(null);
  const [reprendreRefus, setReprendreRefus] = useState(false);
  const [erreur, setErreur] = useState('');
  const arret = useRef(false);
  const lancer = async () => {
    arret.current = false; setErreur('');
    try {
      const ids = [];
      for (let off = 0; ; off += 200) {
        const { data, error } = await supabase.rpc('fn_digital_candidates_list', {
          p_library_id: null, p_status: 'valide', p_book_id: null, p_limit: 200, p_offset: off,
        });
        if (error) throw error;
        const cs = Array.isArray(data?.candidates) ? data.candidates : [];
        ids.push(...cs.filter((c) => c.holding !== false && (reprendreRefus || !c.deposit_error)).map((c) => c.id));
        if (cs.length < 200) break;
      }
      setEtat({ total: ids.length, done: 0, failed: 0, enCours: true });
      const bilan = await versementParLots(ids, appelerVersement, {
        arrete: () => arret.current, progres: (b) => setEtat({ ...b, enCours: true }),
      });
      setEtat({ ...bilan, enCours: false });
      onFin?.();
    } catch (e) {
      setErreur(localizeError(e, t));
      setEtat((x) => (x ? { ...x, enCours: false, arrete: true } : x));
    }
  };
  const enCours = Boolean(etat?.enCours);
  return (
    <div data-testid="pdf-candidates-batch" style={{ margin: '0 0 12px', padding: 10, border: '1px solid rgba(255,255,255,.08)', borderRadius: 6 }}>
      <p style={{ ...muted, margin: '0 0 6px' }}>{t({ id: 'importacoes.pdfCandidates.batch.hint' })}</p>
      <label style={{ ...muted, display: 'flex', gap: 6, alignItems: 'center', marginBottom: 6 }}>
        <input type="checkbox" checked={reprendreRefus} disabled={enCours} onChange={(e) => setReprendreRefus(e.target.checked)} />
        {t({ id: 'importacoes.pdfCandidates.batch.retryFailed' })}
      </label>
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
        <button type="button" className="cat-btn primary" data-testid="pdf-candidates-batch-start" disabled={enCours || !n} onClick={lancer}>
          {t({ id: 'importacoes.pdfCandidates.batch.button' }, { n })}
        </button>
        {enCours && (
          <button type="button" className="cat-btn secondary" onClick={() => { arret.current = true; }}>
            {t({ id: 'importacoes.pdfCandidates.batch.stop' })}
          </button>
        )}
      </div>
      {etat && (
        <div role="status" data-testid="pdf-candidates-batch-state" style={{ fontSize: '.85rem', marginTop: 6 }}>
          {t({ id: etat.enCours ? 'importacoes.pdfCandidates.batch.progress'
            : etat.arrete ? 'importacoes.pdfCandidates.batch.stopped' : 'importacoes.pdfCandidates.batch.done' },
          { done: etat.done, failed: etat.failed, total: etat.total })}
        </div>
      )}
      {erreur && <div className="cat-message error" role="alert" style={{ margin: '8px 0' }}>{erreur}</div>}
    </div>
  );
}

// D27 (20/10/2026) : ce qu'un appel de deposit-digital-candidate tient
// (LIMITE_APPEL, même valeur, gardée égale par src/tests/numdif-limite-appel.test.js).
// Au-delà, la fonction refuse sans télécharger ; l'écran le dit avant l'essai.
export const LIMITE_VERSEMENT_SERVEUR = 140 * 1000 * 1000;

function Verser({ c, t, onDone }) {
  const [occupe, setOccupe] = useState(false);
  const [erreur, setErreur] = useState('');
  const tropLourd = Number(c.file_size_bytes) > LIMITE_VERSEMENT_SERVEUR;
  const verser = async () => {
    setOccupe(true); setErreur('');
    try {
      const out = await appelerVersement([c.id]);
      onDone?.(t({ id: 'importacoes.pdfCandidates.deposit.done' }, {
        id: out.resource_id ?? '?',
        scope: t({ id: out.access_scope === 'conta_ativa' ? 'importacoes.pdfCandidates.dest.restricted' : 'importacoes.pdfCandidates.dest.public' }),
      }));
    } catch (e) {
      setErreur(localizeError(e, t));
    } finally {
      setOccupe(false);
    }
  };
  return (
    <div data-testid="pdf-candidate-deposit" style={{ marginTop: 12, paddingTop: 10, borderTop: '1px solid rgba(255,255,255,.08)' }}>
      <p style={{ ...muted, margin: '0 0 6px' }}>{t({ id: 'importacoes.pdfCandidates.deposit.hint' })}</p>
      {c.deposit_error && (
        <div data-testid="pdf-candidate-deposit-error" style={{ ...muted, color: 'var(--brand-warning, #eab308)', marginBottom: 6 }}>
          {t({ id: 'importacoes.pdfCandidates.deposit.lastError' }, { error: c.deposit_error })}
        </div>
      )}
      {erreur && <div className="cat-message error" role="alert" style={{ margin: '8px 0' }}>{erreur}</div>}
      {tropLourd && (
        <div data-testid="pdf-candidate-too-large" style={{ ...muted, color: 'var(--brand-warning, #eab308)', marginBottom: 6 }}>
          {t({ id: 'importacoes.pdfCandidates.deposit.tooLarge' }, {
            size: (c.file_size_bytes / 1e6).toFixed(0), max: LIMITE_VERSEMENT_SERVEUR / 1e6,
          })}
        </div>
      )}
      <button type="button" className="cat-btn primary" data-testid="pdf-candidate-deposit-button" disabled={occupe || tropLourd} onClick={verser}>
        {occupe ? t({ id: 'importacoes.pdfCandidates.deposit.running' }) : t({ id: 'importacoes.pdfCandidates.deposit.button' })}
      </button>
    </div>
  );
}

function Candidat({ c, ouvert, onToggle, onDone, t, formatDate }) {
  const b = c.book || {};
  const notes = c.tool_notes || {};
  const controles = notes.controles || {};
  const avert = Array.isArray(notes.avertissements) ? notes.avertissements : [];
  const restreint = c.destination?.access_scope === 'conta_ativa';
  const verdict = c.verdict || c.proposed_verdict;
  const cas = c.source_case || c.proposed_case;
  return (
    <div data-testid="pdf-candidate" style={{ padding: '10px 12px', borderBottom: '1px solid rgba(255,255,255,.06)', minWidth: 0 }}>
      <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start', flexWrap: 'wrap' }}>
        <div style={{ flex: '1 1 260px', minWidth: 0 }}>
          <div style={{ fontWeight: 700, overflowWrap: 'anywhere' }}>{b.titulo || '—'}</div>
          <div style={muted}>
            {b.bib_ref && <>ref. {b.bib_ref} · </>}{editionNotice(b) || '—'} · {c.library_name || '—'}
          </div>
          <div style={{ marginTop: 4 }}>
            {verdict && <span style={pill(FOND_VERDICT[verdict])}>{t({ id: `importacoes.pdfCandidates.verdict.${verdict}` })}</span>}
            {cas && <span style={pill('transparent')}>{t({ id: `importacoes.pdfCandidates.case.${cas}` })}</span>}
            {c.destination && (
              <span style={pill('transparent')}>{t({ id: restreint ? 'importacoes.pdfCandidates.dest.restricted' : 'importacoes.pdfCandidates.dest.public' })}</span>
            )}
            <span style={muted}>{c.source_name || ''}</span>
          </div>
          {c.holding === false && (
            <div data-testid="pdf-candidate-not-holding" style={{ ...muted, color: 'var(--brand-warning, #eab308)', marginTop: 4 }}>
              {t({ id: 'importacoes.pdfCandidates.notHolding' })}
            </div>
          )}
        </div>
        <button type="button" className="ab-button ab-button--secondary ab-button--sm" aria-expanded={ouvert} onClick={onToggle}>
          {t({ id: ouvert ? 'importacoes.pdfCandidates.hide' : 'importacoes.pdfCandidates.examine' })}
        </button>
      </div>

      {ouvert && (
        <div style={{ marginTop: 10 }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 20rem), 1fr))', gap: 14 }}>
            <section aria-label={t({ id: 'importacoes.pdfCandidates.notice.title' })} style={{ minWidth: 0 }}>
              <h4 style={{ margin: '0 0 6px' }}>{t({ id: 'importacoes.pdfCandidates.notice.title' })}</h4>
              <Ligne label={t({ id: 'importacoes.pdfCandidates.field.title' })} value={[b.titulo, b.subtitulo].filter(Boolean).join(' : ')} />
              <Ligne label={t({ id: 'importacoes.pdfCandidates.field.author' })} value={b.autor} />
              <Ligne label={t({ id: 'importacoes.pdfCandidates.field.publisher' })} value={b.editora} />
              <Ligne label={t({ id: 'importacoes.pdfCandidates.field.place' })} value={b.local_publicacao} />
              <Ligne label={t({ id: 'importacoes.pdfCandidates.field.year' })} value={b.ano} />
              <Ligne label={t({ id: 'importacoes.pdfCandidates.field.translator' })} value={b.tradutor} />
              <Ligne label={t({ id: 'importacoes.pdfCandidates.field.isbn' })} value={b.isbn} />
              <Ligne label={t({ id: 'importacoes.pdfCandidates.field.language' })} value={b.idioma} />
            </section>
            <section aria-label={t({ id: 'importacoes.pdfCandidates.candidate.title' })} style={{ minWidth: 0 }}>
              <h4 style={{ margin: '0 0 6px' }}>{t({ id: 'importacoes.pdfCandidates.candidate.title' })}</h4>
              <Ligne label={t({ id: 'importacoes.pdfCandidates.field.title' })} value={c.found_title} />
              <Ligne label={t({ id: 'importacoes.pdfCandidates.field.publisher' })} value={c.found_publisher} />
              <Ligne label={t({ id: 'importacoes.pdfCandidates.field.place' })} value={c.found_place} />
              <Ligne label={t({ id: 'importacoes.pdfCandidates.field.year' })} value={c.found_year} />
              <Ligne label={t({ id: 'importacoes.pdfCandidates.field.translator' })} value={c.found_translator} />
              <Ligne label={t({ id: 'importacoes.pdfCandidates.field.isbn' })} value={c.found_isbn} />
              <div style={{ ...muted, marginTop: 6 }}>
                {t({ id: !c.sha256 && c.sha1 ? 'importacoes.pdfCandidates.file.metaSha1' : 'importacoes.pdfCandidates.file.meta' }, {
                  size: c.file_size_bytes ? (c.file_size_bytes / 1e6).toFixed(1) : '?',
                  pages: c.page_count || '?',
                  sha: c.sha256 ? `${c.sha256.slice(0, 12)}…` : c.sha1 ? `${c.sha1.slice(0, 12)}…` : '—',
                })}
              </div>
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginTop: 6 }}>
                <a className="ab-button ab-button--secondary ab-button--sm" href={c.file_url} target="_blank" rel="noopener noreferrer">
                  {t({ id: 'importacoes.pdfCandidates.openPdf' })}
                </a>
                {c.page_url && (
                  <a className="ab-button ab-button--secondary ab-button--sm" href={c.page_url} target="_blank" rel="noopener noreferrer">
                    {t({ id: 'importacoes.pdfCandidates.openPage' })}
                  </a>
                )}
              </div>
            </section>
          </div>

          <h4 style={{ margin: '12px 0 4px' }}>
            {c.title_page_number
              ? t({ id: 'importacoes.pdfCandidates.titlePage.title' }, { n: c.title_page_number })
              : t({ id: 'importacoes.pdfCandidates.titlePage.untitled' })}
          </h4>
          {c.title_page_text
            ? <pre data-testid="pdf-candidate-title-page" style={{ whiteSpace: 'pre-wrap', overflowWrap: 'anywhere', maxHeight: '22rem', overflow: 'auto',
                fontSize: '.8rem', background: 'rgba(0,0,0,.15)', padding: 10, borderRadius: 6, margin: 0 }}>{c.title_page_text}</pre>
            : <p style={muted}>{t({ id: 'importacoes.pdfCandidates.titlePage.none' })}</p>}

          <div style={{ ...muted, marginTop: 8 }}>
            {t({ id: 'importacoes.pdfCandidates.controls.title' })}{' '}
            {CONTROLES.filter((k) => controles[k] !== undefined && controles[k] !== null).map((k) => (
              <span key={k} style={{ marginRight: 8 }}>
                {controles[k] ? '✓' : '✗'} {t({ id: `importacoes.pdfCandidates.control.${k}` })}
              </span>
            ))}
          </div>
          {avert.filter((a) => AVERTISSEMENTS.includes(a)).map((a) => (
            <div key={a} style={{ ...muted, color: 'var(--brand-warning, #eab308)' }}>{t({ id: `importacoes.pdfCandidates.warning.${a}` })}</div>
          ))}
          {c.proposed_mention && (
            <div style={{ ...muted, marginTop: 4 }}>
              {t({ id: 'importacoes.pdfCandidates.mentionFound' }, { page: c.proposed_mention_page || '?', mention: c.proposed_mention })}
            </div>
          )}

          {(c.status === 'rejete' || c.status === 'valide' || c.status === 'verse') && (
            <div data-testid="pdf-candidate-decided" style={{ fontSize: '.85rem', marginTop: 10 }}>
              {t({ id: 'importacoes.pdfCandidates.decided' }, {
                status: t({ id: `importacoes.pdfCandidates.status.${c.status}` }),
                who: c.decided_by_name || '—', date: c.decided_at ? formatDate(c.decided_at) : '—',
              })}
              {c.status === 'rejete' && c.rejection_reason && (
                <div>{t({ id: 'importacoes.pdfCandidates.rejectReason' }, { reason: c.rejection_reason })}</div>
              )}
              {c.justification && c.status !== 'rejete' && <div style={muted}>{c.justification}</div>}
            </div>
          )}
          {c.status === 'valide' && c.holding !== false && <Verser c={c} t={t} onDone={onDone} />}
          {(c.status === 'propose' || c.status === 'valide') && c.holding !== false && <Decision c={c} t={t} onDone={onDone} />}
        </div>
      )}
    </div>
  );
}

export default function CandidatsPdfPanel({ libraryId }) {
  const { formatMessage: t, formatDate } = useIntl();
  const [statut, setStatut] = useState('propose');
  const [page, setPage] = useState(0);
  const [etat, setEtat] = useState({ charge: false, total: 0, counts: {}, candidates: [] });
  const [ouvert, setOuvert] = useState(null);
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [charge, setCharge] = useState(false);

  const charger = useCallback(async () => {
    setEtat((e) => ({ ...e, charge: true }));
    try {
      const { data, error } = await supabase.rpc('fn_digital_candidates_list', {
        p_library_id: null, p_status: statut, p_book_id: null, p_limit: PAGE, p_offset: page * PAGE,
      });
      if (error) throw error;
      setEtat({ charge: false, total: Number(data?.total || 0), counts: data?.counts || {},
        candidates: Array.isArray(data?.candidates) ? data.candidates.filter(Boolean) : [] });
    } catch (e) {
      setEtat({ charge: false, total: 0, counts: {}, candidates: [] });
      setMsg({ text: localizeError(e, t), kind: 'error' });
    }
  }, [statut, page, t]);

  useEffect(() => { charger(); }, [charger]);

  const chargerFichier = async (fichier) => {
    if (!fichier) return;
    setCharge(true); setMsg({ text: '', kind: '' });
    try {
      const parBib = lireFichierCandidats(await fichier.text(), libraryId);
      const bilan = { created: 0, refreshed: 0, skipped: 0 };
      for (const [lib, liste] of parBib) {
        for (let i = 0; i < liste.length; i += 200) {
          const { data, error } = await supabase.rpc('fn_digital_candidates_propose', { p_library_id: lib, p_candidates: liste.slice(i, i + 200) });
          if (error) throw error;
          bilan.created += Number(data?.created || 0);
          bilan.refreshed += Number(data?.refreshed || 0);
          bilan.skipped += Number(data?.skipped_rows || 0);
        }
      }
      setMsg({ text: t({ id: 'importacoes.pdfCandidates.import.done' }, bilan), kind: bilan.created + bilan.refreshed > 0 ? 'ok' : 'info' });
      setStatut('propose'); setPage(0);
      await charger();
    } catch (e) {
      const cle = typeof e?.message === 'string' && /^(error|importacoes)\./.test(e.message) ? e.message : null;
      setMsg({ text: cle ? t({ id: cle }) : localizeError(e, t), kind: 'error' });
    } finally {
      setCharge(false);
    }
  };

  const pages = Math.max(1, Math.ceil(etat.total / PAGE));
  return (
    <div className="imp-sheet" data-testid="pdf-candidates-panel" style={{ marginBottom: 18 }}>
      <div className="imp-sheet__head">
        <span className="imp-sheet__title">{t({ id: 'importacoes.pdfCandidates.title' })}</span>
      </div>
      <div className="imp-sheet__body">
        <p style={{ ...muted, marginTop: 0 }}>{t({ id: 'importacoes.pdfCandidates.intro' })}</p>

        <div className="ab-field" style={{ marginBottom: 12 }}>
          <label className="ab-field__label" htmlFor="pdfc-import">{t({ id: 'importacoes.pdfCandidates.import.label' })}</label>
          <input id="pdfc-import" type="file" accept=".json,application/json" disabled={charge}
            onChange={(e) => { const f = e.target.files?.[0]; e.target.value = ''; chargerFichier(f); }} />
          <span style={muted}>{t({ id: 'importacoes.pdfCandidates.import.hint' })}</span>
        </div>

        {msg.text && (
          <div className={`cat-message ${msg.kind}`} role={msg.kind === 'error' ? 'alert' : 'status'} style={{ marginBottom: 10 }}>
            {msg.text}
            <button type="button" onClick={() => setMsg({ text: '', kind: '' })} aria-label="×"
              style={{ marginLeft: 'auto', background: 'none', border: 0, color: 'inherit', cursor: 'pointer' }}>×</button>
          </div>
        )}

        {statut === 'valide' && (
          <VerserLeLot t={t} n={Number(etat.counts?.valide || 0)} onFin={() => { setPage(0); charger(); }} />
        )}

        <nav className="ab-tabbar" role="tablist" aria-label={t({ id: 'importacoes.pdfCandidates.statusFilter' })} style={{ marginBottom: 10 }}>
          {STATUTS.map((s) => (
            <button key={s} type="button" role="tab" aria-selected={statut === s}
              className={`ab-tabbar__tab${statut === s ? ' active' : ''}`}
              onClick={() => { setStatut(s); setPage(0); setOuvert(null); }}>
              {t({ id: `importacoes.pdfCandidates.status.${s}` })} ({Number(etat.counts?.[s] || 0)})
            </button>
          ))}
        </nav>

        {etat.charge && <div style={{ fontSize: '.85rem' }}>{t({ id: 'importacoes.pdfCandidates.loading' })}</div>}
        {!etat.charge && etat.candidates.length === 0 && (
          <div data-testid="pdf-candidates-empty" style={muted}>{t({ id: 'importacoes.pdfCandidates.empty' })}</div>
        )}
        {etat.candidates.map((c) => (
          <Candidat key={c.id} c={c} t={t} formatDate={(d) => formatDate(d, { dateStyle: 'medium', timeStyle: 'short' })}
            ouvert={ouvert === c.id} onToggle={() => setOuvert((o) => (o === c.id ? null : c.id))}
            onDone={(texte) => { setMsg({ text: texte, kind: 'ok' }); setOuvert(null); charger(); }} />
        ))}
        {etat.total > PAGE && (
          <div style={{ display: 'flex', gap: 8, justifyContent: 'center', alignItems: 'center', marginTop: 10 }}>
            <button type="button" className="ab-button ab-button--secondary ab-button--sm" disabled={page === 0}
              onClick={() => setPage((p) => Math.max(0, p - 1))}>{t({ id: 'catalogacao.catalog.prevPage' })}</button>
            <span style={{ fontSize: '.85rem' }}>{page + 1} / {pages}</span>
            <button type="button" className="ab-button ab-button--secondary ab-button--sm" disabled={page + 1 >= pages}
              onClick={() => setPage((p) => p + 1)}>{t({ id: 'catalogacao.catalog.nextPage' })}</button>
          </div>
        )}
      </div>
    </div>
  );
}
