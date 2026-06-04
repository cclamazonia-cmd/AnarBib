import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useToast } from '@/contexts/ToastContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { SummaryCard, TaskBucket, TabHeader } from '../_shared';
import WriteToReaderBox from './WriteToReaderBox';

// ═══════════════════════════════════════════════════════════
// TabTrabalhoDoDia — onglet « Travail du jour » (chantier E.1 / OT-4)
// ───────────────────────────────────────────────────────────
// Extrait de PanelPage.jsx (bloc tab === 'trabalho-do-dia', qui était
// une IIFE). Présentational : données et handlers restent dans
// PanelPage, passés en props. buildDailyTasks() est appelé ici comme
// dans l'original (calcul à chaque rendu de l'onglet). notifyError via
// hook (le <select> des tâches internes appelle fn_task_update_status).
// Iso-comportement strict.
//
// AJOUT (item 1 — boîte de réception lecteurs, 04/06) :
//   7e card « Messages reçus » + section listant les messages
//   reader_library_messages entrants, avec réponse inline (réutilise
//   WriteToReaderBox). Dérogation ASSUMÉE à la pureté présentationnelle :
//   ces données sont chargées LOCALEMENT ici (useLibrary + from()), pas
//   via PanelPage — pour ne pas toucher PanelPage (2149 lignes) et par
//   cohérence avec WriteToReaderBox (déjà autonome). Lecture seule
//   (RLS staff SELECT de reader_library_messages, posée étape 4/A).
//   Pas de migration. Un entrant est « à répondre » tant qu'aucun
//   sortant (direction='library') vers ce·tte lecteur·rice ne lui est
//   postérieur.
// ═══════════════════════════════════════════════════════════
export default function TabTrabalhoDoDia({
  t,
  buildDailyTasks,
  activeRes,
  overdueLoans,
  consultations,
  internalTasks,
  setTab,
  loadData,
}) {
  const { notifyError } = useToast();
  const { libraryId } = useLibrary();

  // ── Messages lecteurs (chargement local — cf. note d'archi en tête) ──
  const [readerMsgs, setReaderMsgs] = useState([]);
  const [replyTo, setReplyTo] = useState(null);

  async function loadReaderMessages() {
    if (!libraryId) { setReaderMsgs([]); return; }
    try {
      const { data, error } = await supabase
        .from('reader_library_messages')
        .select('id, sender_id, recipient_id, direction, subject, body, created_at, sender:profiles!reader_library_messages_sender_id_fkey(id, first_name, last_name, email)')
        .eq('library_id', libraryId)
        .order('created_at', { ascending: false })
        .limit(200);
      if (error) throw error;
      setReaderMsgs(data || []);
    } catch (err) {
      notifyError(localizeError(err, t, 'panel.error.readerMessages'), err);
    }
  }

  useEffect(() => {
    loadReaderMessages();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [libraryId]);

  const incoming = readerMsgs.filter(m => m.direction === 'reader');
  const outgoing = readerMsgs.filter(m => m.direction === 'library');
  const isAnswered = (m) => outgoing.some(o => o.recipient_id === m.sender_id && o.created_at > m.created_at);
  const pendingReaderMsgs = incoming.filter(m => !isAnswered(m));

  const readerName = (s) => {
    if (!s) return t({ id: 'panel.readerInbox.unknownReader' });
    const n = [s.first_name, s.last_name].filter(Boolean).join(' ').trim();
    return n || s.email || t({ id: 'panel.readerInbox.unknownReader' });
  };

  const tasks = buildDailyTasks();
  const hoje = tasks.filter(t => t.bucket === 'hoje');
  const atencao = tasks.filter(t => t.bucket === 'atencao');
  const acomp = tasks.filter(t => t.bucket === 'acompanhamento');
  return (
    <div>
      <TabHeader title={t({ id: 'panel.tab.dailyWork.hint' })} onRefresh={() => { loadData(); loadReaderMessages(); }} />
      <div className="ab-painel-summary-grid">
        <SummaryCard label={t({id:'panel.summary.today'})} count={hoje.length} variant="warn" />
        <SummaryCard label={t({id:'panel.summary.attention'})} count={atencao.length} variant="bad" />
        <SummaryCard label={t({ id: 'panel.summary.pendingReservations' })} count={activeRes.filter(r => r.workflow_stage_effective === 'solicitada').length} variant="warn" />
        <SummaryCard label={t({ id: 'panel.summary.overdueLoans' })} count={overdueLoans.length} variant="bad" />
        <SummaryCard label={t({ id: 'panel.summary.pendingConsultations' })} count={consultations.filter(c => c.workflow_stage_effective === 'solicitada').length} variant="warn" />
        <SummaryCard label={t({ id: 'panel.summary.internalTasks' })} count={internalTasks.length} variant={internalTasks.some(t => t.priority === 'alta') ? 'bad' : 'warn'} />
        <SummaryCard label={t({ id: 'panel.summary.readerMessages' })} count={pendingReaderMsgs.length} variant="warn" />
      </div>

      {tasks.length === 0 ? (
        <p className="ab-painel-hint">{t({ id: 'panel.noAutoTasks' })}</p>
      ) : (
        <>
          {hoje.length > 0 && <TaskBucket title={t({ id: 'panel.summary.today' })} tasks={hoje} setTab={setTab} onTaskAction={loadData} />}
          {atencao.length > 0 && <TaskBucket title={t({ id: 'panel.summary.attention' })} tasks={atencao} setTab={setTab} onTaskAction={loadData} />}
          {acomp.length > 0 && <TaskBucket title={t({ id: 'panel.summary.monitoring' })} tasks={acomp} setTab={setTab} onTaskAction={loadData} />}
        </>
      )}

      {/* ── Tarefas internas — sempre visível ──── */}
      <div className="ab-painel-itask-box">
        <div className="ab-painel-itask-head">
          <h3 className="ab-painel-h3">{t({ id: 'panel.tasks.title' })} ({internalTasks.length})</h3>
          <a href="/biblioteca" className="ab-painel-itask-manage">{t({ id: 'panel.tasks.manage' })}</a>
        </div>
        {internalTasks.length === 0 ? (
          <p className="ab-painel-itask-empty">
            {t({ id: 'panel.tasks.empty' })}{' '}
            {t({ id: 'panel.tasks.emptyHint' }, {
              link: chunks => <a href="/biblioteca">{chunks}</a>,
            })}
          </p>
        ) : (
          <div className="ab-painel-itask-list">
            {internalTasks.map((tk, i) => {
              const isOverdue = tk.due_date && tk.due_date < new Date().toISOString().slice(0, 10);
              return (
                <div key={tk.id} className="ab-painel-itask-row">
                  <div className="ab-painel-itask-cell">
                    <div className="ab-painel-itask-title">
                      {tk.title || '—'}
                      {isOverdue && <span className="ab-painel-itask-overdue">{t({ id: 'panel.overdue' })}</span>}
                    </div>
                    <div className="ab-painel-itask-meta">
                      {tk.status === 'em_andamento' ? t({id:'task.status.em_andamento'}) : t({id:'task.status.pendente'})}
                      {tk.owner && ` · ${tk.owner}`}
                      {tk.due_date && ` · ${t({id:'panel.task.detail.prazo'})}: ${tk.due_date}`}
                      {tk.tags?.length > 0 && ` · ${tk.tags.join(', ')}`}
                    </div>
                  </div>
                  <div className="ab-painel-itask-actions">
                    <span className={`ab-painel-itask-prio ab-painel-itask-prio--${tk.priority === 'alta' ? 'alta' : tk.priority === 'baixa' ? 'baixa' : 'normal'}`}>
                      {tk.priority === 'alta' ? t({id:'panel.task.priority.high'}) : tk.priority === 'baixa' ? t({id:'panel.task.priority.low'}) : t({id:'panel.task.priority.normal'})}
                    </span>
                    <select value={tk.status} className="ab-painel-itask-select"
                      onChange={async e => {
                        // Chantier #TASKS : router par fn_task_update_status (RPC)
                        // au lieu d'un update() direct. Le update() court-circuitait
                        // la regeneration des taches recurrentes a l'achevement.
                        try {
                          const { error } = await supabase.rpc('fn_task_update_status', {
                            p_task_id: tk.id, p_new_status: e.target.value,
                          });
                          if (error) throw error;
                          loadData();
                        } catch (err) {
                          notifyError(localizeError(err, t, 'panel.error.taskStatus'), err);
                        }
                      }}>
                      <option value="pendente">{t({ id: 'task.status.pendente' })}</option>
                      <option value="em_andamento">{t({ id: 'task.status.em_andamento' })}</option>
                      <option value="concluida">{t({ id: 'task.status.concluida' })}</option>
                      <option value="cancelada">{t({ id: 'task.status.cancelada' })}</option>
                    </select>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* ── Mensagens de leitores recebidas — sempre visível (item 1) ──── */}
      <div className="ab-painel-itask-box">
        <div className="ab-painel-itask-head">
          <h3 className="ab-painel-h3">{t({ id: 'panel.readerInbox.title' })} ({incoming.length})</h3>
        </div>
        {incoming.length === 0 ? (
          <p className="ab-painel-itask-empty">{t({ id: 'panel.readerInbox.empty' })}</p>
        ) : (
          <div className="ab-painel-itask-list">
            {incoming.map(m => {
              const answered = isAnswered(m);
              return (
                <div key={m.id} className="ab-painel-itask-row">
                  <div className="ab-painel-itask-cell">
                    <div className="ab-painel-itask-title">
                      {(m.subject && m.subject.trim()) || t({ id: 'panel.readerInbox.noSubject' })}
                      {!answered && <span className="ab-painel-itask-overdue">{t({ id: 'panel.readerInbox.pendingBadge' })}</span>}
                    </div>
                    <div className="ab-painel-itask-meta">
                      {readerName(m.sender)}{' · '}{(m.created_at || '').slice(0, 10)}
                    </div>
                    {m.body ? (
                      <div style={{ whiteSpace: 'pre-line', marginTop: 6, fontSize: '.85rem', color: '#d4d4d4', wordBreak: 'break-word' }}>{m.body}</div>
                    ) : null}
                    {replyTo === m.id && (
                      <WriteToReaderBox
                        t={t}
                        libraryId={libraryId}
                        reader={{ id: m.sender_id }}
                        onSent={() => { setReplyTo(null); loadReaderMessages(); }}
                      />
                    )}
                  </div>
                  <div className="ab-painel-itask-actions">
                    <button
                      type="button"
                      className="ab-painel-itask-manage"
                      style={{ background: 'none', border: 'none', cursor: 'pointer', font: 'inherit' }}
                      onClick={() => setReplyTo(replyTo === m.id ? null : m.id)}
                    >
                      {t({ id: 'panel.readerInbox.reply' })}
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
