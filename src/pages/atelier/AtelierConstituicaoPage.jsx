import { useState, useEffect, useCallback, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { apiQuery, apiRpc, supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useToast } from '@/contexts/ToastContext';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import LibraryProfileWizard from '@/components/LibraryProfileWizard';
import HumanChannelInlineCallout from '@/components/atelier/HumanChannelInlineCallout';
import AtelierVoletEditor, { WIRED_VOLETS } from '@/components/atelier/AtelierVoletEditor';
import { buildRegimentoPdf } from '@/lib/regimentoPdf';
import './AtelierConstituicaoPage.css';

// ═══════════════════════════════════════════════════════════════════════════
// AtelierConstituicaoPage — « Oficina de constituição » (spec onboarding §6)
//
// Hub-and-spoke (ONBO-Q2) : volet 0 (profil) déverrouille les volets 1-10, dont
// l'applicabilité dépend des 4 axes. Chaque volet = panneau slide-over avec
// canal humain en tête (ONBO-D1) + action « discuté en collectif » (≠ formulaire :
// la décision est politique). Persistance via les RPC fn_constitution_* (paquet
// ATELIER-A1) ; lecture via api.my_constitution_progress_v1.
//
// NB : pendant la constitution la biblio n'existe pas encore comme row libraries
// → les champs des volets restent des LEURRES (cadrage : « champs des panneaux →
// vrais composants ONBO-Q2 » = lot ultérieur, suppose une biblio pré-active).
// Ici on porte la mécanique « marquer comme discutido em coletivo » de la maquette.
// ═══════════════════════════════════════════════════════════════════════════

// Volets 1-10 : applicabilité = conception validée de la maquette.
const VOLETS = [
  { n: 1, key: 'volet_1_identite', flag: 'volet_1_identite_done', comp: 'LocaleSelector · LibraryVisualAssetsSection · LibraryContactProfileSection', applies: () => true },
  { n: 2, key: 'volet_2_horaires', flag: 'volet_2_horaires_done', comp: 'service_state (in-page)', applies: () => true },
  { n: 3, key: 'volet_3_pessoas', flag: 'volet_3_pessoas_done', comp: 'TeamPanel', applies: p => p.governance !== 'informal' },
  { n: 4, key: 'volet_4_catalogacao', flag: 'volet_4_catalogacao_done', comp: 'CatalogaçãoPage (política)', applies: p => p.catalog !== 'local_only' },
  { n: 5, key: 'volet_5_circulacao', flag: 'volet_5_circulacao_done', comp: 'PolicySetManager · RegimeStateBox', applies: p => p.circulation !== 'off' },
  { n: 6, key: 'volet_6_adhesion', flag: 'volet_6_adhesion_done', comp: 'LeitoresPanel · membership rules', applies: p => p.governance !== 'informal' && p.circulation !== 'off' },
  { n: 7, key: 'volet_7_emails', flag: 'volet_7_emails_done', comp: 'comms (in-page)', applies: () => true },
  { n: 8, key: 'volet_8_visibilidade', flag: 'volet_8_visibilidade_done', comp: 'LibraryPartnershipsSection · DocumentGovernanceSection', applies: p => p.network !== 'isolated' },
  { n: 9, key: 'volet_9_dados', flag: 'volet_9_dados_done', comp: 'RetentionPolicySection', applies: () => true },
  { n: 10, key: 'volet_10_regimento', flag: 'volet_10_regimento_done', comp: 'geração PDF (§6.6)', applies: () => true, regimento: true },
];

const RING_C = 2 * Math.PI * 36;

export default function AtelierConstituicaoPage() {
  const { formatMessage: t } = useIntl();
  const { notifySuccess, notifyError } = useToast();
  useDocumentTitle(t({ id: 'atelier.pageTitle' }));

  const [loading, setLoading] = useState(true);
  const [prog, setProg] = useState(null);      // ligne my_constitution_progress_v1
  const [busy, setBusy] = useState(false);
  const [openVolet, setOpenVolet] = useState(null); // n du volet ouvert (slide-over)
  const [regUrl, setRegUrl] = useState('');

  // Axes profil (volet 0), en state local miroir de la progression.
  const [axes, setAxes] = useState({ catalog_mode: '', circulation_mode: '', network_mode: '', governance_mode: '', profile_template_chosen: null });

  const load = useCallback(async () => {
    setLoading(true);
    const { data } = await apiQuery('my_constitution_progress_v1');
    const row = (data && data[0]) || null;
    setProg(row);
    if (row) {
      setAxes({
        catalog_mode: row.volet_0_catalog_mode || '',
        circulation_mode: row.volet_0_circulation_mode || '',
        network_mode: row.volet_0_network_mode || '',
        governance_mode: row.volet_0_governance_mode || '',
        profile_template_chosen: null,
      });
      setRegUrl(row.regimento_pdf_url || '');
    }
    setLoading(false);
  }, []);

  useEffect(() => { load(); }, [load]);

  // Profil « court » pour les fonctions applies (axes).
  const profile = useMemo(() => ({
    catalog: axes.catalog_mode || 'network_published',
    circulation: axes.circulation_mode || 'full_sigb',
    network: axes.network_mode || 'federated',
    governance: axes.governance_mode || 'full_governance',
  }), [axes]);

  const profilDone = !!prog?.volet_0_profil_done;
  const applicable = useMemo(() => VOLETS.filter(v => v.applies(profile)), [profile]);
  const doneCount = applicable.filter(v => prog?.[v.flag]).length;
  const den = applicable.length;
  // Verrou regimento (ONBO-Q2 Lot 3) : générer/sauver le regimento exige que TOUS
  // les volets applicables hors regimento soient marqués terminés.
  const deliberationDone = applicable.filter(v => !v.regimento).every(v => !!prog?.[v.flag]);

  const daysLeft = useMemo(() => {
    if (!prog?.deadline_at) return null;
    return Math.ceil((new Date(prog.deadline_at) - new Date()) / 86400000);
  }, [prog]);

  async function run(fn, okMsgId) {
    setBusy(true);
    try {
      const { error } = await fn();
      if (error) { notifyError(localizeError(error, t)); return false; }
      if (okMsgId) notifySuccess(t({ id: okMsgId }));
      await load();
      return true;
    } catch (e) { notifyError(localizeError(e, t)); return false; }
    finally { setBusy(false); }
  }

  const saveProfile = () => {
    if (!axes.catalog_mode || !axes.circulation_mode || !axes.network_mode || !axes.governance_mode) {
      notifyError(t({ id: 'atelier.volet0.incomplete' })); return;
    }
    return run(() => apiRpc('fn_constitution_set_profile', {
      p_request_id: prog.request_id, p_catalog: axes.catalog_mode, p_circulation: axes.circulation_mode,
      p_network: axes.network_mode, p_governance: axes.governance_mode,
    }), 'atelier.toast.profileSaved');
  };

  const markVolet = (v, done) => run(() => apiRpc('fn_constitution_set_volet', {
    p_request_id: prog.request_id, p_volet: v.key, p_done: done,
  }), done ? 'atelier.toast.markedDone' : 'atelier.toast.saved');

  const saveRegimento = () => run(() => apiRpc('fn_constitution_set_regimento', {
    p_request_id: prog.request_id, p_url: regUrl.trim() || null,
  }), 'atelier.toast.regimentoSaved');

  const complete = () => run(() => apiRpc('fn_constitution_complete', { p_request_id: prog.request_id }), 'atelier.toast.completed');

  // Décisions provisoires réellement saisies aux volets, agrégées pour le regimento
  // (ONBO-Q2 Lot 3). Lecture best-effort sur la biblio pré-active (RLS staff) ;
  // si une lecture échoue, la section reste générique. Valeurs déjà localisées.
  async function buildVoletConfig(libraryId) {
    const cfg = {};
    if (!libraryId) return cfg;
    const yn = b => t({ id: b ? 'common.yes' : 'common.no' });
    try {
      const [{ data: lib }, { data: ss }, { data: lc }] = await Promise.all([
        supabase.from('libraries').select('cataloging_classification_system, cataloging_mandatory_fields, cataloging_policy_notes, accepts_public_signup, reader_validation_mode, membership_enabled').eq('id', libraryId).maybeSingle(),
        supabase.from('library_service_state').select('service_mode, allows_new_loans, allows_new_reservations, public_message').eq('library_id', libraryId).maybeSingle(),
        supabase.from('library_commons').select('contact_email, reply_to_email, email_delivery_mode').eq('library_id', libraryId).maybeSingle(),
      ]);
      if (ss) {
        const e = [];
        if (ss.service_mode) e.push(`${t({ id: 'biblioteca.identity.serviceMode' })} : ${t({ id: `rede.serviceMode.${ss.service_mode}` })}`);
        e.push(`${t({ id: 'biblioteca.identity.allowsLoans' })} : ${yn(ss.allows_new_loans)}`);
        e.push(`${t({ id: 'biblioteca.identity.allowsReservations' })} : ${yn(ss.allows_new_reservations)}`);
        if (ss.public_message) e.push(`${t({ id: 'biblioteca.identity.publicMessage' })} : ${ss.public_message}`);
        cfg[2] = e;
      }
      if (lib) {
        const e4 = [];
        if (lib.cataloging_classification_system) e4.push(`${t({ id: 'atelier.volet4.classifSystem' })} : ${t({ id: `atelier.volet4.classif.${lib.cataloging_classification_system}` })}`);
        if (lib.cataloging_mandatory_fields?.length) e4.push(`${t({ id: 'atelier.volet4.mandatoryFields' })} : ${lib.cataloging_mandatory_fields.map(f => t({ id: `catalogacao.field.${f}` })).join(', ')}`);
        if (lib.cataloging_policy_notes) e4.push(`${t({ id: 'atelier.volet4.notes' })} : ${lib.cataloging_policy_notes}`);
        if (e4.length) cfg[4] = e4;
      }
      if (lib) cfg[6] = [
        `${t({ id: 'biblioteca.readerIdentity.publicSignup' })} : ${yn(lib.accepts_public_signup)}`,
        `${t({ id: 'biblioteca.readerIdentity.mode' })} : ${t({ id: `biblioteca.readerIdentity.mode.${lib.reader_validation_mode || 'presential'}` })}`,
        `${t({ id: 'membership.config.enabled' })} : ${yn(lib.membership_enabled)}`,
      ];
      if (lc) {
        const e = [];
        if (lc.contact_email) e.push(`${t({ id: 'biblioteca.comms.sendEmail' })} : ${lc.contact_email}`);
        if (lc.reply_to_email) e.push(`${t({ id: 'biblioteca.identity.replyEmail' })} : ${lc.reply_to_email}`);
        e.push(`${t({ id: 'biblioteca.comms.sendMode' })} : ${t({ id: `biblioteca.comms.sendMode.${lc.email_delivery_mode || 'normal'}` })}`);
        cfg[7] = e;
      }
    } catch { /* best-effort : PDF générique si lecture KO */ }
    return cfg;
  }

  async function downloadRegimento() {
    if (!deliberationDone) { notifyError(t({ id: 'atelier.regimento.locked' })); return; }
    setBusy(true);
    try {
      const config = await buildVoletConfig(prog.library_id);
      await buildRegimentoPdf({ progress: prog, axes, applicable, t, config });
    } catch (e) { notifyError(localizeError(e, t)); }
    finally { setBusy(false); }
  }

  if (loading) {
    return <PageShell><Topbar /><div style={{ textAlign: 'center', padding: 60, color: 'var(--brand-muted)' }}>{t({ id: 'common.loading' })}</div><Footer /></PageShell>;
  }
  if (!prog) {
    return (
      <PageShell><Topbar />
        <Hero title={t({ id: 'atelier.title' })} subtitle={t({ id: 'atelier.empty.sub' })} />
        <div className="ab-atl-wrap"><div className="ab-atl-empty">{t({ id: 'atelier.empty' })}</div></div>
        <Footer />
      </PageShell>
    );
  }

  const completed = !!prog.completed_at;
  const cur = VOLETS.find(v => v.n === openVolet);

  return (
    <PageShell><Topbar />
      <Hero title={t({ id: 'atelier.title' })} subtitle={prog.library_name || t({ id: 'atelier.subtitle' })} />

      <div className="ab-atl-wrap">
        {/* Bandeau échéance (ONBO-Q5) */}
        {!completed && daysLeft != null && (
          <div className={`ab-atl-deadline${daysLeft < 0 ? ' is-frozen' : ''}`}>
            <span className="ab-atl-dot" aria-hidden="true" />
            {daysLeft >= 0
              ? t({ id: 'atelier.deadline' }, { days: daysLeft })
              : t({ id: 'atelier.deadline.frozen' })}
          </div>
        )}
        {completed && <div className="ab-atl-deadline is-done">{t({ id: 'atelier.completed' })}</div>}

        <div className="ab-atl-grid">
          {/* Colonne ancre */}
          <aside className="ab-atl-anchor">
            <div className="ab-atl-ring-card">
              <div className="ab-atl-ring">
                <svg width="84" height="84" viewBox="0 0 84 84">
                  <circle cx="42" cy="42" r="36" fill="none" stroke="rgba(255,255,255,.08)" strokeWidth="7" />
                  <circle cx="42" cy="42" r="36" fill="none" stroke="var(--color-ok,#7ee0a8)" strokeWidth="7"
                    strokeLinecap="round" strokeDasharray={RING_C}
                    strokeDashoffset={RING_C * (1 - (den ? doneCount / den : 0))}
                    style={{ transition: 'stroke-dashoffset .5s', transform: 'rotate(-90deg)', transformOrigin: 'center' }} />
                </svg>
                <div className="ab-atl-ring-num"><b>{doneCount}</b><span>/ {den}</span></div>
              </div>
              <div className="ab-atl-ring-meta">
                <h3>{t({ id: 'atelier.progress.title' })}</h3>
                <p>{t({ id: 'atelier.progress.sub' })}</p>
              </div>
            </div>

            <div className="ab-atl-doctrine">
              <div className="ab-atl-doctrine-tag">{t({ id: 'atelier.doctrine.tag' })}</div>
              <h3>{t({ id: 'atelier.doctrine.title' })}</h3>
              <p>{t({ id: 'atelier.doctrine.text' })}</p>
            </div>

            <HumanChannelInlineCallout volet={0} subjectLabel={t({ id: 'atelier.volet0.title' })} />
          </aside>

          {/* Colonne scène */}
          <main className="ab-atl-stage">
            <section className="ab-atl-profile">
              <div className="ab-atl-profile-head">
                <span className="ab-atl-vnum">{t({ id: 'atelier.volet0.vnum' })}</span>
                <h2>{t({ id: 'atelier.volet0.title' })}</h2>
              </div>
              <p className="ab-atl-profile-sub">{t({ id: 'atelier.volet0.sub' })}</p>
              <LibraryProfileWizard value={axes} onChange={completed ? () => {} : setAxes} />
              <div className="ab-atl-profile-foot">
                <button className="ab-atl-btn primary" disabled={busy || completed} onClick={saveProfile}>
                  {profilDone ? t({ id: 'atelier.volet0.update' }) : t({ id: 'atelier.volet0.confirm' })}
                </button>
                {profilDone && <span className="ab-atl-ok">✓ {t({ id: 'atelier.volet0.saved' })}</span>}
              </div>
            </section>

            <div className="ab-atl-stage-title">
              <h2>{t({ id: 'atelier.stageTitle' })}</h2>
              <span className="ab-atl-rule" />
              <span className="ab-atl-count">{t({ id: 'atelier.applicCount' }, { count: den })}</span>
            </div>

            {!profilDone && <p className="ab-atl-locked">{t({ id: 'atelier.locked' })}</p>}

            <div className="ab-atl-cards">
              {VOLETS.map(v => {
                const ap = v.applies(profile);
                const done = !!prog[v.flag];
                const cls = `ab-atl-card${!ap ? ' is-moot' : ''}${done ? ' is-done' : ''}`;
                return (
                  <div key={v.n} className={cls} onClick={() => ap && profilDone && setOpenVolet(v.n)}
                    role={ap && profilDone ? 'button' : undefined} tabIndex={ap && profilDone ? 0 : undefined}>
                    <div className="ab-atl-edge" />
                    <div className="ab-atl-card-num">{t({ id: 'atelier.voletLabel' }, { n: v.n })}</div>
                    <h4>{t({ id: `atelier.${v.key}.title` })}</h4>
                    <p>{ap ? t({ id: `atelier.${v.key}.sub` }) : t({ id: 'atelier.card.moot' })}</p>
                    <span className={`ab-atl-pill ${!ap ? 'moot' : done ? 'done' : 'todo'}`}>
                      {!ap ? t({ id: 'atelier.status.moot' }) : done ? t({ id: 'atelier.status.done' }) : t({ id: 'atelier.status.todo' })}
                    </span>
                  </div>
                );
              })}
            </div>

            {profilDone && !completed && doneCount === den && den > 0 && (
              <button className="ab-atl-btn primary ab-atl-complete" disabled={busy} onClick={complete}>
                {t({ id: 'atelier.completeBtn' })}
              </button>
            )}
          </main>
        </div>
      </div>

      {/* Slide-over volet */}
      {cur && (
        <>
          <div className="ab-atl-scrim is-open" onClick={() => setOpenVolet(null)} />
          <div className="ab-atl-panel is-open" role="dialog" aria-modal="true">
            <div className="ab-atl-panel-head">
              <div>
                <div className="ab-atl-vnum">{t({ id: 'atelier.voletLabel' }, { n: cur.n })}</div>
                <h3>{t({ id: `atelier.${cur.key}.title` })}</h3>
                <p>{t({ id: `atelier.${cur.key}.sub` })}</p>
              </div>
              <button className="ab-atl-x" onClick={() => setOpenVolet(null)} aria-label={t({ id: 'common.close' })}>✕</button>
            </div>
            <div className="ab-atl-panel-body">
              <HumanChannelInlineCallout volet={cur.n} subjectLabel={t({ id: `atelier.${cur.key}.title` })} />

              {cur.regimento ? (
                <>
                  <div className="ab-atl-regimento">{t({ id: 'atelier.regimento.banner' })}</div>
                  {!deliberationDone && <p className="ab-atl-locked">{t({ id: 'atelier.regimento.locked' })}</p>}
                  <button className="ab-atl-btn" disabled={busy || !deliberationDone} onClick={downloadRegimento}>↓ {t({ id: 'atelier.regimento.download' })}</button>
                  <div className="ab-atl-field">
                    <label>{t({ id: 'atelier.regimento.uploadLabel' })}</label>
                    <input type="url" value={regUrl} onChange={e => setRegUrl(e.target.value)} placeholder="https://…" disabled={completed || !deliberationDone} />
                    <span className="ab-atl-hint">{t({ id: 'atelier.regimento.uploadHint' })}</span>
                  </div>
                </>
              ) : WIRED_VOLETS.has(cur.n) && prog.library_id ? (
                /* ONBO-Q2 — volet câblé sur la biblio pré-active (fin du leurre) */
                <AtelierVoletEditor voletN={cur.n} libraryId={prog.library_id} canEdit={!completed} />
              ) : (
                <div className="ab-atl-reuse">
                  <div className="ab-atl-reuse-lbl">{t({ id: 'atelier.panel.reuseLabel' })}</div>
                  <code className="ab-atl-reuse-comp">{cur.comp}</code>
                  <p className="ab-atl-hint">{t({ id: 'atelier.panel.reuseHint' })}</p>
                </div>
              )}
            </div>
            <div className="ab-atl-panel-foot">
              {cur.regimento ? (
                <button className="ab-atl-btn primary" disabled={busy || completed || !deliberationDone} onClick={() => { saveRegimento(); }}>
                  {t({ id: 'atelier.regimento.save' })}
                </button>
              ) : (
                <button className="ab-atl-btn primary" disabled={busy || completed} onClick={() => { markVolet(cur, true); setOpenVolet(null); }}>
                  {t({ id: 'atelier.panel.markDone' })}
                </button>
              )}
              <button className="ab-atl-btn" disabled={busy} onClick={() => setOpenVolet(null)}>{t({ id: 'atelier.panel.saveLater' })}</button>
              <div className="ab-atl-foot-hint">{t({ id: 'atelier.panel.markDoneHint' })}</div>
            </div>
          </div>
        </>
      )}
      <Footer />
    </PageShell>
  );
}
