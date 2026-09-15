import { useEffect, useState } from 'react';
import { useIntl } from 'react-intl';
import { callEdgeFunction } from '@/lib/supabase';

// ═══════════════════════════════════════════════════════════════════════════
// GazetteContributeForm — volet « Proposer une brève » de l'onglet Gazette.
//
// Poste vers l'Edge Function publique submit-gazette-contribution avec la clé
// ANON uniquement (jamais service_role). Le backend valide, rate-limite, insère
// dans gazette_submissions et enfile une notif → fede@anarbib.org. Les brèves
// n'apparaissent PAS automatiquement : network_staff les trie (accepted/rejected).
// UI app-native (thème sombre du SIGB), pas le style papier de la gazette.
//
// REPRISE (GAZ-7, 15/09/2026). Avec `resubmitToken` (le ?reprise=<jeton> du lien
// reçu par courriel au rejet), le formulaire se pré-remplit depuis l'EF (action
// « prefill » : texte d'origine + motif écrit par le staff), affiche le motif, et
// l'envoi porte le jeton : la nouvelle brève est chaînée à la rejetée, le jeton
// est consommé. Un jeton mort (inventé, révoqué, consommé, périmé) est dit tel
// quel — et renvoie vers le formulaire habituel, jamais vers un mur.
// ═══════════════════════════════════════════════════════════════════════════

const RUBRICS = ['une', 'reseau', 'luttes', 'international', 'cultures', 'agenda', 'autre'];
const EF = 'submit-gazette-contribution';

function tokenErrorId(data) {
  const code = data?.error;
  if (code === 'token_used') return 'federacao.gazeta.resubmit.error.used';
  if (code === 'token_expired') return 'federacao.gazeta.resubmit.error.expired';
  return 'federacao.gazeta.resubmit.error.invalid';
}

export default function GazetteContributeForm({ onClose, resubmitToken }) {
  const { formatMessage: t, locale } = useIntl();
  const isResubmit = !!resubmitToken;
  const [rubric, setRubric] = useState('');
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [link, setLink] = useState('');
  const [eventDate, setEventDate] = useState('');
  const [name, setName] = useState('');
  const [collective, setCollective] = useState('');
  const [email, setEmail] = useState('');
  const [website, setWebsite] = useState(''); // honeypot anti-bot (doit rester vide)
  const [reviewNote, setReviewNote] = useState(''); // motif du rejet, en reprise
  // prefill (reprise en cours de chargement) | idle | sending | done | error | dead (jeton mort)
  const [phase, setPhase] = useState(isResubmit ? 'prefill' : 'idle');
  const [errId, setErrId] = useState(null);

  useEffect(() => {
    if (!resubmitToken) return undefined;
    let cancelled = false;
    (async () => {
      const { ok, data } = await callEdgeFunction(EF, { action: 'prefill', resubmit_token: resubmitToken });
      if (cancelled) return;
      if (!ok || !data?.original) {
        setErrId(tokenErrorId(data));
        setPhase('dead');
        return;
      }
      const o = data.original;
      setRubric(o.rubric || '');
      setTitle(o.title || '');
      setBody(o.body || '');
      setLink(o.link || '');
      setEventDate(o.event_date || '');
      setName(o.contributor_name || '');
      setCollective(o.contributor_collective || '');
      setEmail(o.contributor_email || '');
      setReviewNote(o.review_note || '');
      setPhase('idle');
    })();
    return () => { cancelled = true; };
  }, [resubmitToken]);

  const titleLen = title.trim().length;
  const bodyLen = body.trim().length;
  const titleOk = titleLen >= 2 && titleLen <= 200;
  const bodyOk = bodyLen >= 2 && bodyLen <= 6000;
  const canSubmit = !!rubric && titleOk && bodyOk && phase !== 'sending';

  async function submit(e) {
    e.preventDefault();
    if (!canSubmit) return;
    setPhase('sending');
    setErrId(null);
    const payload = {
      rubric,
      title: title.trim(),
      body: body.trim(),
      locale,
      link: link.trim() || undefined,
      event_date: rubric === 'agenda' && eventDate ? eventDate : undefined,
      contributor_name: name.trim() || undefined,
      contributor_collective: collective.trim() || undefined,
      contributor_email: email.trim() || undefined,
      target_issue_number: undefined,
      resubmit_token: resubmitToken || undefined,
      website, // honeypot
    };
    const { ok, status, data } = await callEdgeFunction(EF, payload);
    if (ok) { setPhase('done'); return; }
    if (isResubmit && (status === 404 || status === 410)) {
      // Le jeton est mort entre l'ouverture et l'envoi : le texte reste à l'écran
      // derrière le message, rien n'a été inséré côté base.
      setErrId(tokenErrorId(data));
      setPhase('dead');
      return;
    }
    setPhase('error');
    if (status === 429) setErrId('federacao.gazeta.contribute.error.rateLimited');
    else if (status === 422) setErrId('federacao.gazeta.contribute.error.validation');
    else setErrId('federacao.gazeta.contribute.error.generic');
  }

  if (phase === 'prefill') {
    return (
      <div className="ab-gz-form ab-gz-form-done" role="status">
        <p>{t({ id: 'federacao.gazeta.resubmit.loading' })}</p>
        <button type="button" className="cat-btn ghost" onClick={onClose}>{t({ id: 'common.cancel' })}</button>
      </div>
    );
  }

  if (phase === 'dead') {
    return (
      <div className="ab-gz-form ab-gz-form-done" role="alert">
        <p>{t({ id: errId })}</p>
        <button type="button" className="cat-btn ghost" onClick={onClose}>{t({ id: 'common.close' })}</button>
      </div>
    );
  }

  if (phase === 'done') {
    return (
      <div className="ab-gz-form ab-gz-form-done" role="status">
        <p>{isResubmit ? t({ id: 'federacao.gazeta.resubmit.success' }) : t({ id: 'federacao.gazeta.contribute.success' })}</p>
        <button type="button" className="cat-btn ghost" onClick={onClose}>{t({ id: 'common.close' })}</button>
      </div>
    );
  }

  return (
    <form className="ab-gz-form" onSubmit={submit} noValidate>
      <div className="ab-gz-form-head">
        <h3>{isResubmit ? t({ id: 'federacao.gazeta.resubmit.title' }) : t({ id: 'federacao.gazeta.contribute.title' })}</h3>
        <button type="button" className="cat-btn ghost" onClick={onClose}>{t({ id: 'common.cancel' })}</button>
      </div>
      <p className="ab-gz-form-intro">{isResubmit ? t({ id: 'federacao.gazeta.resubmit.intro' }) : t({ id: 'federacao.gazeta.contribute.intro' })}</p>

      {isResubmit && reviewNote && (
        <div style={{ margin: '0 0 14px', padding: '10px 12px', borderLeft: '3px solid #cf1f27', background: 'rgba(207,31,39,.08)', borderRadius: 6 }}>
          <div className="ab-gz-flabel" style={{ marginTop: 0 }}>{t({ id: 'federacao.gazeta.resubmit.reason' })}</div>
          <blockquote style={{ margin: 0, whiteSpace: 'pre-wrap', fontSize: '.92rem' }}>{reviewNote}</blockquote>
        </div>
      )}

      <label className="ab-gz-flabel" htmlFor="gz-rubric">{t({ id: 'federacao.gazeta.contribute.rubric' })} *</label>
      <select id="gz-rubric" value={rubric} onChange={(e) => setRubric(e.target.value)} required>
        <option value="" disabled>—</option>
        {RUBRICS.map((r) => <option key={r} value={r}>{t({ id: `federacao.gazeta.rubric.${r}` })}</option>)}
      </select>

      <label className="ab-gz-flabel" htmlFor="gz-title">{t({ id: 'federacao.gazeta.contribute.field.title' })} *</label>
      <input id="gz-title" value={title} onChange={(e) => setTitle(e.target.value)} maxLength={200} required />
      <div className="ab-gz-count">{titleLen}/200</div>

      <label className="ab-gz-flabel" htmlFor="gz-body">{t({ id: 'federacao.gazeta.contribute.field.body' })} *</label>
      <textarea id="gz-body" value={body} onChange={(e) => setBody(e.target.value)} maxLength={6000} rows={5} required />
      <div className="ab-gz-count">{bodyLen}/6000</div>

      <label className="ab-gz-flabel" htmlFor="gz-link">{t({ id: 'federacao.gazeta.contribute.field.link' })}</label>
      <input id="gz-link" type="url" value={link} onChange={(e) => setLink(e.target.value)} maxLength={500} placeholder="https://" />

      {rubric === 'agenda' && (
        <>
          <label className="ab-gz-flabel" htmlFor="gz-date">{t({ id: 'federacao.gazeta.contribute.field.eventDate' })}</label>
          <input id="gz-date" type="date" value={eventDate} onChange={(e) => setEventDate(e.target.value)} />
        </>
      )}

      <div className="ab-gz-flabel ab-gz-you">{t({ id: 'federacao.gazeta.contribute.you' })}</div>
      <input
        value={name} onChange={(e) => setName(e.target.value)} maxLength={160}
        placeholder={t({ id: 'federacao.gazeta.contribute.field.name' })}
        aria-label={t({ id: 'federacao.gazeta.contribute.field.name' })}
      />
      <input
        value={collective} onChange={(e) => setCollective(e.target.value)} maxLength={160}
        placeholder={t({ id: 'federacao.gazeta.contribute.field.collective' })}
        aria-label={t({ id: 'federacao.gazeta.contribute.field.collective' })}
      />
      <input
        type="email" value={email} onChange={(e) => setEmail(e.target.value)} maxLength={200}
        placeholder={t({ id: 'federacao.gazeta.contribute.field.email' })}
        aria-label={t({ id: 'federacao.gazeta.contribute.field.email' })}
      />

      {/* Honeypot : invisible, hors tabulation. Un bot qui le remplit est silencieusement accepté côté EF. */}
      <input
        className="ab-gz-hp" type="text" value={website} onChange={(e) => setWebsite(e.target.value)}
        tabIndex={-1} autoComplete="off" aria-hidden="true"
      />

      {errId && <div className="ab-gz-form-err" role="alert">{t({ id: errId })}</div>}

      <div className="ab-gz-form-actions">
        <button type="submit" className="cat-btn primary" disabled={!canSubmit}>
          {phase === 'sending'
            ? t({ id: 'federacao.gazeta.contribute.sending' })
            : isResubmit
              ? t({ id: 'federacao.gazeta.resubmit.submit' })
              : t({ id: 'federacao.gazeta.contribute.submit' })}
        </button>
      </div>
    </form>
  );
}
