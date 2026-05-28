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
      <div style={{ marginTop: 20, padding: 16, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
          <h3 className="ab-painel-h3" style={{ margin: 0 }}>{t({ id: 'panel.tasks.title' })} ({internalTasks.length})</h3>
          <a href="/biblioteca" style={{ fontSize: '.85rem', color: 'var(--brand-muted)' }}>{t({ id: 'panel.tasks.manage' })}</a>
        </div>
        {internalTasks.length === 0 ? (
          <p style={{ fontSize: '.88rem', color: 'var(--brand-muted)', margin: 0 }}>
            {t({ id: 'panel.tasks.empty' })}{' '}
            {t({ id: 'panel.tasks.emptyHint' }, {
              link: chunks => <a href="/biblioteca" style={{ color: 'var(--brand-text)' }}>{chunks}</a>,
            })}
          </p>
        ) : (
          <div style={{ border: '1px solid rgba(255,255,255,.06)', borderRadius: 8, overflow: 'hidden' }}>
            {internalTasks.map((tk, i) => {
              const isOverdue = tk.due_date && tk.due_date < new Date().toISOString().slice(0, 10);
              return (
                <div key={tk.id} style={{ padding: '10px 12px', background: i % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent', borderBottom: '1px solid rgba(255,255,255,.04)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: '.9rem', fontWeight: 600 }}>
                      {tk.title || '—'}
                      {isOverdue && <span style={{ color: '#f87171', fontWeight: 700, marginLeft: 8, fontSize: '.78rem' }}>{t({ id: 'panel.overdue' })}</span>}
                    </div>
                    <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)' }}>
                      {tk.status === 'em_andamento' ? t({id:'task.status.em_andamento'}) : t({id:'task.status.pendente'})}
                      {tk.owner && ` · ${tk.owner}`}
                      {tk.due_date && ` · ${t({id:'panel.task.detail.prazo'})}: ${tk.due_date}`}
                      {tk.tags?.length > 0 && ` · ${tk.tags.join(', ')}`}
                    </div>
                  </div>
                  <div style={{ display: 'flex', gap: 4, flexShrink: 0, alignItems: 'center' }}>
                    <span style={{ fontSize: '.7rem', padding: '2px 8px', borderRadius: 4, fontWeight: 700, background: tk.priority === 'alta' ? 'rgba(220,38,38,.18)' : tk.priority === 'baixa' ? 'rgba(29,78,216,.18)' : 'rgba(180,83,9,.18)', color: tk.priority === 'alta' ? '#f87171' : tk.priority === 'baixa' ? '#60a5fa' : '#fbbf24' }}>
                      {tk.priority === 'alta' ? t({id:'panel.task.priority.high'}) : tk.priority === 'baixa' ? t({id:'panel.task.priority.low'}) : t({id:'panel.task.priority.normal'})}
                    </span>
                    <select value={tk.status} style={{ fontSize: '.82rem', padding: '4px 8px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4' }}
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
