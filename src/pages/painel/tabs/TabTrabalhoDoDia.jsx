import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useToast } from '@/contexts/ToastContext';
import { SummaryCard, TaskBucket, TabHeader } from '../_shared';

// ═══════════════════════════════════════════════════════════
// TabTrabalhoDoDia — onglet « Travail du jour » (chantier E.1 / OT-4)
// ───────────────────────────────────────────────────────────
// Extrait de PanelPage.jsx (bloc tab === 'trabalho-do-dia', qui était
// une IIFE). Présentational : données et handlers restent dans
// PanelPage, passés en props. buildDailyTasks() est appelé ici comme
// dans l'original (calcul à chaque rendu de l'onglet). notifyError via
// hook (le <select> des tâches internes appelle fn_task_update_status).
// Iso-comportement strict.
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
  const tasks = buildDailyTasks();
  const hoje = tasks.filter(t => t.bucket === 'hoje');
  const atencao = tasks.filter(t => t.bucket === 'atencao');
  const acomp = tasks.filter(t => t.bucket === 'acompanhamento');
  return (
    <div>
      <TabHeader title={t({ id: 'panel.tab.dailyWork.hint' })} onRefresh={loadData} />
      <div className="ab-painel-summary-grid">
        <SummaryCard label={t({id:'panel.summary.today'})} count={hoje.length} variant="warn" />
        <SummaryCard label={t({id:'panel.summary.attention'})} count={atencao.length} variant="bad" />
        <SummaryCard label={t({ id: 'panel.summary.pendingReservations' })} count={activeRes.filter(r => r.workflow_stage_effective === 'solicitada').length} variant="warn" />
        <SummaryCard label={t({ id: 'panel.summary.overdueLoans' })} count={overdueLoans.length} variant="bad" />
        <SummaryCard label={t({ id: 'panel.summary.pendingConsultations' })} count={consultations.filter(c => c.workflow_stage_effective === 'solicitada').length} variant="warn" />
        <SummaryCard label={t({ id: 'panel.summary.internalTasks' })} count={internalTasks.length} variant={internalTasks.some(t => t.priority === 'alta') ? 'bad' : 'warn'} />
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
    </div>
  );
}
