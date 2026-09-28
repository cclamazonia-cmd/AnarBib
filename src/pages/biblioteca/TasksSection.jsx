// src/pages/biblioteca/TasksSection.jsx — E6, BibliotecaPage lot 2 (28/09/2026)
// L'onglet « Tarefas internas » de la page Bibliothèque, sorti de
// BibliotecaPage.jsx sans en changer une ligne de logique : la liste par
// échéance (en retard, aujourd'hui, à venir, sans échéance, closes), la
// création d'une tâche, le statut, l'invitation par courriel ; les
// tâches-types (créer, modifier, activer, supprimer, instancier) ; le
// catalogue de suggestions à adopter. Les trois listes (tâches, modèles,
// suggestions) restent chargées par le parent — le rapport lit les tâches —
// et arrivent en props ; la section prévient par `onChanged` quand la base
// a bougé. Les cinq états de formulaire et les deux mémos vivent ici.
import { useState, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { fs, ls, bx, lr, lw } from './styles';

export default function TasksSection({ libraryId, tasks, templates, suggestions, taskPrio, setMsg, onChanged }) {
  const { formatMessage: t, locale } = useIntl();
  const TASK_PRIO = taskPrio;
  const [saving, setSaving] = useState(false);
  // i18n titres/descriptions de taches-types et taches : jsonb {locale: texte}
  // herite du catalogue. Repli locale courante -> pt-BR -> 1re cle -> texte simple.
  const localizedText = (obj, fallback) => {
    if (obj && typeof obj === 'object') {
      const v = obj[locale] || obj['pt-BR'] || Object.values(obj).find(x => x && String(x).trim());
      if (v && String(v).trim()) return v;
    }
    return fallback || '';
  };
  const [newTask, setNewTask] = useState({ title: '', description: '', priority: 'normal', owner: '' });
  // Chantier #TASKS etape 6 (24/05/2026) : sous-onglets de l'onglet « Tarefas
  // internas ». Paquet 1 ne remplit que 'lista' (vue par echeance + drapeau
  // stale) ; 'modelos' et 'catalogo' sont des placeholders, remplis aux
  // paquets 2 et 3.
  const [tasksSubtab, setTasksSubtab] = useState('lista');
  // Chantier #TASKS etape 6 paquet 2 (24/05/2026) : tâches-types locales.
  // templates = liste chargee depuis painel_recurring_task_rules.
  // editingTemplate = null (aucun) | 'new' (creation) | {id,...} (edition).
  // instantiateFor = id du modele dont le mini-formulaire d'echeance est
  // ouvert (un seul a la fois), null sinon. instantiateDate = sa date.
  const [editingTemplate, setEditingTemplate] = useState(null);
  const [instantiateFor, setInstantiateFor] = useState(null);
  const [instantiateDate, setInstantiateDate] = useState('');

  // ── Create task ─────────────────────────────────────────
  async function createTask() {
    if (!newTask.title.trim()) { setMsg({ text: t({ id: 'biblioteca.tasks.titleRequired' }), kind: 'error' }); return; }
    try {
      // EA-15 (21/05/2026) : bascule sur fn_task_create (RPC).
      // Les defaults backend ('pendente' pour status, '{}' pour tags) sont
      // appliques cote RPC si les params sont absents ou vides.
      const tags = (newTask.tagsText || '').split(',').map(tag => tag.trim()).filter(Boolean);
      const { error } = await supabase.rpc('fn_task_create', {
        p_library_id: libraryId,
        p_title: newTask.title.trim(),
        p_description: newTask.description.trim() || null,
        p_priority: newTask.priority || 'media',
        p_owner: newTask.owner.trim() || null,
        p_due_date: newTask.dueDate || null,
        p_tags: tags,
      });
      if (error) throw error;
      setNewTask({ title: '', description: '', priority: 'media', owner: '', dueDate: '', tagsText: '' });
      setMsg({ text: t({ id: 'biblioteca.tasks.created' }), kind: 'ok' });
      await onChanged?.();
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:localizeError(err, t)}), kind: 'error' }); }
  }

  async function updateTaskStatus(taskId, status) {
    // EA-15 (21/05/2026) : bascule sur fn_task_update_status (RPC).
    try {
      const { error } = await supabase.rpc('fn_task_update_status', {
        p_task_id: taskId,
        p_new_status: status,
      });
      if (error) throw error;
      await onChanged?.();
    } catch (err) {
      setMsg({ text: t({id:'common.errorPrefix'},{message:localizeError(err, t)}), kind: 'error' });
    }
  }

  // ── Tâches-types : CRUD + instanciation (chantier #TASKS p2) ─────────
  // Toutes les ecritures passent par les RPC fn_recurring_task_rule_*
  // (doctrine RPC v3 : RPC obligatoire pour les ecritures avec validation
  // metier). La distinction recurrent / ponctuel est portee par un champ
  // `recurrent` (bool) dans le formulaire ; cote RPC, un modele recurrent
  // exige interval_count + interval_unit, un ponctuel les laisse NULL.

  // Ouvre le formulaire en mode creation, avec des valeurs par defaut.
  function startNewTemplate() {
    setEditingTemplate({
      id: 'new', template_title: '', template_description: '',
      template_priority: 'media', tagsText: '', label: '',
      recurrent: false, interval_count: 1, interval_unit: 'semana',
      is_active: true,
    });
    setMsg({ text: '', kind: '' });
  }

  // Ouvre le formulaire en mode edition pour un modele existant.
  function startEditTemplate(tpl) {
    setEditingTemplate({
      id: tpl.id,
      template_title: tpl.template_title || '',
      template_description: tpl.template_description || '',
      template_priority: tpl.template_priority || 'media',
      tagsText: (tpl.template_tags || []).join(', '),
      label: tpl.label || '',
      recurrent: tpl.interval_count != null && tpl.interval_unit != null,
      interval_count: tpl.interval_count || 1,
      interval_unit: tpl.interval_unit || 'semana',
      is_active: tpl.is_active !== false,
    });
    setMsg({ text: '', kind: '' });
  }

  function cancelEditTemplate() { setEditingTemplate(null); }

  async function saveTemplate() {
    if (!editingTemplate) return;
    const e = editingTemplate;
    if (!e.template_title.trim()) {
      setMsg({ text: t({ id: 'biblioteca.templates.titleRequired' }), kind: 'error' });
      return;
    }
    const tags = (e.tagsText || '').split(',').map(s => s.trim()).filter(Boolean);
    // Modele ponctuel => cadence NULL ; recurrent => les deux champs.
    const intervalCount = e.recurrent ? Number(e.interval_count) || null : null;
    const intervalUnit  = e.recurrent ? e.interval_unit : null;
    setSaving(true);
    try {
      if (e.id === 'new') {
        const { error } = await supabase.rpc('fn_recurring_task_rule_create', {
          p_library_id: libraryId,
          p_template_title: e.template_title.trim(),
          p_template_description: e.template_description.trim() || null,
          p_template_priority: e.template_priority || 'media',
          p_template_tags: tags,
          p_label: e.label.trim() || null,
          p_interval_count: intervalCount,
          p_interval_unit: intervalUnit,
        });
        if (error) throw error;
        setMsg({ text: t({ id: 'biblioteca.templates.created' }), kind: 'ok' });
      } else {
        const { error } = await supabase.rpc('fn_recurring_task_rule_update', {
          p_template_id: e.id,
          p_template_title: e.template_title.trim(),
          p_template_description: e.template_description.trim() || null,
          p_template_priority: e.template_priority || 'media',
          p_template_tags: tags,
          p_label: e.label.trim() || null,
          p_interval_count: intervalCount,
          p_interval_unit: intervalUnit,
          p_is_active: e.is_active,
        });
        if (error) throw error;
        setMsg({ text: t({ id: 'biblioteca.templates.saved' }), kind: 'ok' });
      }
      setEditingTemplate(null);
      await onChanged?.();
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setSaving(false);
    }
  }

  async function deleteTemplate(tpl) {
    if (!confirm(t({ id: 'biblioteca.templates.deleteConfirm' }, { title: tpl.template_title || '—' }))) return;
    setSaving(true);
    try {
      const { error } = await supabase.rpc('fn_recurring_task_rule_delete', { p_template_id: tpl.id });
      if (error) throw error;
      setMsg({ text: t({ id: 'biblioteca.templates.deleted' }), kind: 'ok' });
      await onChanged?.();
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setSaving(false);
    }
  }

  // Instancie une tache depuis un modele. p_due_date optionnel : si vide,
  // la tache nait sans echeance (seau « Sem prazo »). Pour un modele
  // recurrent, fournir une date donne le point de depart de la serie.
  async function instantiateTemplate(templateId, dueDate) {
    try {
      const { error } = await supabase.rpc('fn_task_instantiate_template', {
        p_template_id: templateId,
        p_due_date: dueDate || null,
      });
      if (error) throw error;
      setInstantiateFor(null);
      setInstantiateDate('');
      setMsg({ text: t({ id: 'biblioteca.templates.instantiated' }), kind: 'ok' });
      await onChanged?.();
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    }
  }

  // Adopte une suggestion du catalogue : la RPC fn_task_adopt_suggestion copie
  // la suggestion en tache-type locale (painel_recurring_task_rules). On passe
  // la locale courante pour que le titre/description copies soient dans la
  // langue de l'interface ; le backend retombe sur pt-BR si la cle manque.
  async function adoptSuggestion(code) {
    try {
      const { error } = await supabase.rpc('fn_task_adopt_suggestion', {
        p_suggestion_code: code,
        p_library_id: libraryId,
        p_locale: locale || 'pt-BR',
      });
      if (error) throw error;
      setMsg({ text: t({ id: 'biblioteca.catalog.adopted' }), kind: 'ok' });
      await onChanged?.();
      // La tache-type bascule dans le sous-onglet « modeles » et disparait du
      // catalogue ; on y amene directement l'utilisateur·rice.
      setTasksSubtab('modelos');
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    }
  }

  // ── Task invite ─────────────────────────────────────────
  async function inviteToTask(taskId, email) {
    if (!email?.trim()) return;
    try {
      // EA-15 (21/05/2026) : bascule sur fn_task_invite (RPC intelligente).
      // La RPC ajoute l'email aux tags de la task, et le trigger
      // tg_sync_task_invites_from_task cree l'invite proprement.
      // Idempotente (si email deja dans tags, ne fait rien).
      const { error } = await supabase.rpc('fn_task_invite', {
        p_task_id: taskId,
        p_invite_email: email.trim(),
      });
      if (error) throw error;
      setMsg({ text: t({ id: 'biblioteca.tasks.inviteSent' }, { email: email.trim() }), kind: 'ok' });
      await onChanged?.();
    } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:localizeError(err, t)}), kind: 'error' }); }
  }

  // Chantier #TASKS etape 6 paquet 1 (24/05/2026) : regroupement des taches
  // par echeance pour la vue « Lista ». Quatre seaux : en retard, aujourd'hui,
  // a venir, sans echeance. Les taches terminees (concluida) ou annulees
  // (cancelada) sont ecartees de la vue par echeance — elles n'appellent plus
  // d'action. due_date est de type date (pas timestamp) : comparaison de
  // chaines YYYY-MM-DD suffit et evite tout decalage de fuseau.
  const tasksByBucket = useMemo(() => {
    const today = new Date().toISOString().slice(0, 10);
    const buckets = { atrasada: [], hoje: [], futura: [], sem_prazo: [] };
    for (const tk of tasks) {
      if (tk.status === 'concluida' || tk.status === 'cancelada') continue;
      if (!tk.due_date) { buckets.sem_prazo.push(tk); continue; }
      if (tk.due_date < today) buckets.atrasada.push(tk);
      else if (tk.due_date === today) buckets.hoje.push(tk);
      else buckets.futura.push(tk);
    }
    // Tri intra-seau par due_date croissante (les sans-echeance gardent
    // l'ordre de chargement, created_at desc).
    const byDue = (a, b) => (a.due_date || '').localeCompare(b.due_date || '');
    buckets.atrasada.sort(byDue);
    buckets.hoje.sort(byDue);
    buckets.futura.sort(byDue);
    return buckets;
  }, [tasks]);

  // Taches deja closes (concluida/cancelada), affichees a part en bas de la
  // vue Lista pour ne pas encombrer les seaux d'echeance.
  const closedTasks = useMemo(
    () => tasks.filter(tk => tk.status === 'concluida' || tk.status === 'cancelada'),
    [tasks],
  );

  // Rendu d'une ligne de tache. Closure pour reutilisation dans chaque
  // seau d'echeance et dans la liste des taches closes. Le markup et
  // le comportement (select de statut, suppression, invitation) sont
  // identiques a l'ancienne liste plate ; on ajoute seulement deux
  // marqueurs : drapeau « recurrence en retard » (recurrence_stale_
  // flagged_at) et badge « serie » (recurrence_rule_id non nul).
  const renderTaskRow = (tk, i) => {
    const isStale = !!tk.recurrence_stale_flagged_at;
    const isRecurring = !!tk.recurrence_rule_id;
    const tkTitle = localizedText(tk.title_i18n, tk.title);
    const tkDesc = localizedText(tk.description_i18n, tk.description);
    return (
    <div key={tk.id} style={{ ...lr(i), flexDirection:'column', alignItems:'stretch', gap:6 }}>
      <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', gap:8 }}>
        <div style={{ flex:1 }}>
          <div style={{ fontSize:'.9rem', fontWeight:600, display:'flex', alignItems:'center', gap:6, flexWrap:'wrap' }}>
            {tkTitle||t({ id: 'common.noTitle' })}
            {isRecurring && (
              <span className="cat-pill info" style={{ fontSize:'.62rem', padding:'1px 6px' }}
                title={t({ id: 'biblioteca.tasks.recurring.hint' })}>
                {t({ id: 'biblioteca.tasks.recurring.badge' })}
              </span>
            )}
            {isStale && (
              <span className="cat-pill danger" style={{ fontSize:'.62rem', padding:'1px 6px' }}
                title={t({ id: 'biblioteca.tasks.staleRecurrence.hint' })}>
                {t({ id: 'biblioteca.tasks.staleRecurrence.badge' })}
              </span>
            )}
          </div>
          <div style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>
            {tk.owner||'—'}{tk.due_date&&` · ${t({ id: 'biblioteca.tasks.deadlineLabel' })}: ${tk.due_date}`}
            {tk.tags?.length>0&&` · ${tk.tags.join(', ')}`}
          </div>
          {tkDesc && <div style={{ fontSize:'.82rem', color:'var(--brand-muted)', marginTop:2 }}>{tkDesc}</div>}
        </div>
        <div style={{ display:'flex', gap:4, flexShrink:0, alignItems:'center' }}>
          <span className={`cat-pill ${tk.priority==='alta'?'danger':tk.priority==='baixa'?'info':'warn'}`} style={{ fontSize:'.65rem' }}>{TASK_PRIO[tk.priority]||tk.priority}</span>
          <select value={tk.status} onChange={e=>updateTaskStatus(tk.id,e.target.value)} style={{ fontSize:'.82rem', padding:'4px 8px', borderRadius:6, border:'1px solid rgba(255,255,255,.12)', background:'rgba(0,0,0,.3)', color:'#f4f4f4' }}>
            <option value="pendente">{t({ id: 'task.status.pendente' })}</option><option value="em_andamento">{t({ id: 'task.status.em_andamento' })}</option><option value="concluida">{t({ id: 'task.status.concluida' })}</option><option value="cancelada">{t({ id: 'task.status.cancelada' })}</option>
          </select>
          <button className="cat-btn ghost" style={{ fontSize:'.78rem', padding:'4px 8px', color:'#f87171' }} onClick={async()=>{if(!confirm(t({ id: 'biblioteca.tasks.discardConfirm' })))return;try{const{error}=await supabase.rpc('fn_task_delete',{p_task_id:tk.id});if(error)throw error;await onChanged?.();}catch(err){setMsg({text:t({id:'common.errorPrefix'},{message:localizeError(err, t)}),kind:'error'});}}}>{t({ id: 'common.discard' })}</button>
        </div>
      </div>
      {/* Invite row */}
      <div style={{ display:'flex', gap:6, alignItems:'center' }}>
        <input type="email" placeholder={t({ id: 'biblioteca.tasks.invitePlaceholder' })} style={{...fs, flex:1, padding:'6px 10px', fontSize:'.82rem'}}
          onKeyDown={async e=>{if(e.key==='Enter'&&e.target.value.trim()){await inviteToTask(tk.id,e.target.value);e.target.value='';}}} />
        <button className="cat-btn secondary" style={{ fontSize:'.78rem', padding:'4px 10px', flexShrink:0 }}
          onClick={async e=>{const inp=e.target.previousElementSibling;if(inp?.value?.trim()){await inviteToTask(tk.id,inp.value);inp.value='';}}}>{t({ id: 'biblioteca.tasks.invite' })}</button>
      </div>
    </div>
    );
  };

  // Rendu d'un seau d'echeance : titre + compteur + lignes. Masque si
  // vide (sauf le bloc « sans echeance » qui reste utile a montrer).
  const renderBucket = (key, labelId, accent) => {
    const list = tasksByBucket[key];
    if (!list.length) return null;
    return (
      <div style={{ marginBottom:14 }}>
        <h4 style={{ margin:'0 0 8px', fontSize:'.92rem', color:accent }}>
          {t({ id: labelId })} ({list.length})
        </h4>
        <div style={lw}>{list.map((tk,i)=>renderTaskRow(tk,i))}</div>
      </div>
    );
  };

  const hasActiveTasks = (
    tasksByBucket.atrasada.length
    + tasksByBucket.hoje.length
    + tasksByBucket.futura.length
    + tasksByBucket.sem_prazo.length
  ) > 0;

  return (
  <div>
    <h3 style={{ marginBottom:12 }}>{t({ id: 'biblioteca.tasks.title' })}</h3>

    {/* Sous-onglets internes : Lista / Modelos / Catalogo. Barre
        partagee de second niveau (`.ab-tabbar--sub`), la meme partout. */}
    <div className="ab-tabbar ab-tabbar--sub" style={{ marginBottom:16 }}>
      <button className={`ab-tabbar__tab${tasksSubtab==='lista'?' active':''}`} onClick={()=>setTasksSubtab('lista')}>{t({ id: 'biblioteca.tasks.subtab.list' })}</button>
      <button className={`ab-tabbar__tab${tasksSubtab==='modelos'?' active':''}`} onClick={()=>setTasksSubtab('modelos')}>{t({ id: 'biblioteca.tasks.subtab.templates' })}</button>
      <button className={`ab-tabbar__tab${tasksSubtab==='catalogo'?' active':''}`} onClick={()=>setTasksSubtab('catalogo')}>{t({ id: 'biblioteca.tasks.subtab.catalog' })}</button>
    </div>

    {/* ── Sous-onglet LISTA ── */}
    {tasksSubtab==='lista' && (<div>
      <div style={bx}>
        <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.tasks.new' })}</h4>
        <div className="cat-book-grid" style={{ marginBottom:10 }}>
          <div className="cat-field" style={{ gridColumn:'span 2' }}><label style={ls}>{t({ id: 'biblioteca.tasks.titleField' })}</label><input type="text" value={newTask.title} onChange={e=>setNewTask(p=>({...p,title:e.target.value}))} style={fs} placeholder={t({ id: 'biblioteca.tasks.titlePlaceholder' })} /></div>
          <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.tasks.priority' })}</label><select value={newTask.priority} onChange={e=>setNewTask(p=>({...p,priority:e.target.value}))} style={fs}><option value="baixa">{t({ id: 'biblioteca.tasks.priority.low' })}</option><option value="normal">{t({ id: 'biblioteca.tasks.priority.normal' })}</option><option value="alta">{t({ id: 'biblioteca.tasks.priority.high' })}</option></select></div>
          <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.tasks.owner' })}</label><input type="text" value={newTask.owner} onChange={e=>setNewTask(p=>({...p,owner:e.target.value}))} style={fs} placeholder={t({ id: 'biblioteca.tasks.ownerPlaceholder' })} /></div>
          <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.tasks.dueDate' })}</label><input type="date" value={newTask.dueDate||''} onChange={e=>setNewTask(p=>({...p,dueDate:e.target.value}))} style={fs} /></div>
          <div className="cat-field"><label style={ls}>{t({ id: 'biblioteca.tasks.tags' })}</label><input type="text" value={newTask.tagsText||''} onChange={e=>setNewTask(p=>({...p,tagsText:e.target.value}))} style={fs} placeholder={t({ id: 'biblioteca.tasks.tagsPlaceholder' })} /></div>
          <div className="cat-field" style={{ gridColumn:'span 3' }}><label style={ls}>{t({ id: 'biblioteca.tasks.description' })}</label><textarea value={newTask.description} onChange={e=>setNewTask(p=>({...p,description:e.target.value}))} rows={2} style={{...fs,resize:'vertical'}} placeholder={t({ id: 'biblioteca.tasks.descPlaceholder' })} /></div>
        </div>
        <button className="cat-btn primary" onClick={createTask} style={{ fontSize:'.88rem' }}>{t({ id: 'biblioteca.tasks.create' })}</button>
      </div>

      {/* Vue par echeance. Quatre seaux ordonnes du plus urgent au
          moins urgent. Le bloc « sans echeance » ferme la marche. */}
      {!hasActiveTasks && (
        <div style={{ fontSize:'.88rem', color:'var(--brand-muted)', fontStyle:'italic', padding:'8px 2px' }}>
          {t({ id: 'biblioteca.tasks.empty' })}
        </div>
      )}
      {renderBucket('atrasada', 'biblioteca.tasks.bucket.overdue', '#f87171')}
      {renderBucket('hoje', 'biblioteca.tasks.bucket.today', '#fbbf24')}
      {renderBucket('futura', 'biblioteca.tasks.bucket.upcoming', 'var(--brand-text)')}
      {renderBucket('sem_prazo', 'biblioteca.tasks.bucket.undated', 'var(--brand-muted)')}

      {/* Taches closes (concluida / cancelada), repliees sous un
          separateur discret pour ne pas encombrer les seaux actifs. */}
      {closedTasks.length>0 && (
        <details style={{ marginTop:10 }}>
          <summary style={{ cursor:'pointer', fontSize:'.85rem', color:'var(--brand-muted)' }}>
            {t({ id: 'biblioteca.tasks.closed.toggle' }, { count: closedTasks.length })}
          </summary>
          <div style={{ ...lw, marginTop:8, opacity:.7 }}>
            {closedTasks.map((tk,i)=>renderTaskRow(tk,i))}
          </div>
        </details>
      )}
    </div>)}

    {/* ── Sous-onglet MODELOS (chantier #TASKS p2) ── */}
    {tasksSubtab==='modelos' && (<div>
      <div style={{ fontSize:'.85rem', color:'var(--brand-muted)', marginBottom:12 }}>
        {t({ id: 'biblioteca.templates.hint' })}
      </div>

      {/* Bouton « Nouveau modèle » — masque tant qu'un formulaire est ouvert */}
      {!editingTemplate && (
        <button className="cat-btn primary" onClick={startNewTemplate} style={{ fontSize:'.88rem', marginBottom:12 }}>
          {t({ id: 'biblioteca.templates.new' })}
        </button>
      )}

      {/* Formulaire créer / éditer */}
      {editingTemplate && (
        <div style={bx}>
          <h4 style={{ margin:'0 0 10px' }}>
            {editingTemplate.id==='new'
              ? t({ id: 'biblioteca.templates.new' })
              : t({ id: 'biblioteca.templates.edit' })}
          </h4>
          <div className="cat-book-grid" style={{ marginBottom:10 }}>
            <div className="cat-field" style={{ gridColumn:'span 2' }}>
              <label style={ls}>{t({ id: 'biblioteca.templates.titleField' })}</label>
              <input type="text" value={editingTemplate.template_title}
                onChange={e=>setEditingTemplate(p=>({...p,template_title:e.target.value}))}
                style={fs} placeholder={t({ id: 'biblioteca.templates.titlePlaceholder' })} />
            </div>
            <div className="cat-field">
              <label style={ls}>{t({ id: 'biblioteca.tasks.priority' })}</label>
              <select value={editingTemplate.template_priority}
                onChange={e=>setEditingTemplate(p=>({...p,template_priority:e.target.value}))} style={fs}>
                <option value="baixa">{t({ id: 'biblioteca.tasks.priority.low' })}</option>
                <option value="media">{t({ id: 'biblioteca.tasks.priority.normal' })}</option>
                <option value="alta">{t({ id: 'biblioteca.tasks.priority.high' })}</option>
              </select>
            </div>
            <div className="cat-field">
              <label style={ls}>{t({ id: 'biblioteca.templates.label' })}</label>
              <input type="text" value={editingTemplate.label}
                onChange={e=>setEditingTemplate(p=>({...p,label:e.target.value}))}
                style={fs} placeholder={t({ id: 'biblioteca.templates.labelPlaceholder' })} />
            </div>
            <div className="cat-field">
              <label style={ls}>{t({ id: 'biblioteca.tasks.tags' })}</label>
              <input type="text" value={editingTemplate.tagsText}
                onChange={e=>setEditingTemplate(p=>({...p,tagsText:e.target.value}))}
                style={fs} placeholder={t({ id: 'biblioteca.tasks.tagsPlaceholder' })} />
            </div>
            <div className="cat-field" style={{ gridColumn:'span 3' }}>
              <label style={ls}>{t({ id: 'biblioteca.tasks.description' })}</label>
              <textarea value={editingTemplate.template_description}
                onChange={e=>setEditingTemplate(p=>({...p,template_description:e.target.value}))}
                rows={2} style={{...fs,resize:'vertical'}}
                placeholder={t({ id: 'biblioteca.tasks.descPlaceholder' })} />
            </div>
          </div>

          {/* Bascule récurrent / ponctuel + cadence */}
          <div style={{ padding:10, borderRadius:8, background:'rgba(0,0,0,.12)', marginBottom:10 }}>
            <label style={{ display:'flex', gap:8, alignItems:'center', fontSize:'.88rem', cursor:'pointer' }}>
              <input type="checkbox" checked={editingTemplate.recurrent}
                onChange={e=>setEditingTemplate(p=>({...p,recurrent:e.target.checked}))} />
              {t({ id: 'biblioteca.templates.recurrentToggle' })}
            </label>
            {editingTemplate.recurrent ? (
              <div style={{ display:'flex', gap:8, alignItems:'center', marginTop:8, flexWrap:'wrap' }}>
                <span style={{ fontSize:'.85rem', color:'var(--brand-muted)' }}>
                  {t({ id: 'biblioteca.templates.cadencePrefix' })}
                </span>
                <input type="number" min={1} value={editingTemplate.interval_count}
                  onChange={e=>setEditingTemplate(p=>({...p,interval_count:e.target.value}))}
                  style={{...fs, width:80}} />
                <select value={editingTemplate.interval_unit}
                  onChange={e=>setEditingTemplate(p=>({...p,interval_unit:e.target.value}))}
                  style={{...fs, width:'auto'}}>
                  <option value="dia">{t({ id: 'biblioteca.templates.unit.dia' })}</option>
                  <option value="semana">{t({ id: 'biblioteca.templates.unit.semana' })}</option>
                  <option value="mes">{t({ id: 'biblioteca.templates.unit.mes' })}</option>
                </select>
              </div>
            ) : (
              <div style={{ fontSize:'.8rem', color:'var(--brand-muted)', fontStyle:'italic', marginTop:6 }}>
                {t({ id: 'biblioteca.templates.punctualHint' })}
              </div>
            )}
          </div>

          {/* Actif / inactif — seulement en édition */}
          {editingTemplate.id!=='new' && (
            <label style={{ display:'flex', gap:8, alignItems:'center', fontSize:'.88rem', cursor:'pointer', marginBottom:10 }}>
              <input type="checkbox" checked={editingTemplate.is_active}
                onChange={e=>setEditingTemplate(p=>({...p,is_active:e.target.checked}))} />
              {t({ id: 'biblioteca.templates.activeToggle' })}
            </label>
          )}

          <div style={{ display:'flex', gap:8 }}>
            <button className="cat-btn primary" onClick={saveTemplate} disabled={saving} style={{ fontSize:'.88rem' }}>
              {saving ? t({ id: 'common.saving' }) : t({ id: 'common.save' })}
            </button>
            <button className="cat-btn secondary" onClick={cancelEditTemplate} disabled={saving} style={{ fontSize:'.88rem' }}>
              {t({ id: 'common.cancel' })}
            </button>
          </div>
        </div>
      )}

      {/* Liste des modèles */}
      {templates.length===0 && !editingTemplate && (
        <div style={{ fontSize:'.88rem', color:'var(--brand-muted)', fontStyle:'italic', padding:'8px 2px' }}>
          {t({ id: 'biblioteca.templates.empty' })}
        </div>
      )}
      {templates.length>0 && (
        <div style={lw}>
          {templates.map((tpl,i)=>{
            const isRecurrent = tpl.interval_count!=null && tpl.interval_unit!=null;
            return (
            <div key={tpl.id} style={{ ...lr(i), flexDirection:'column', alignItems:'stretch', gap:6 }}>
              <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', gap:8 }}>
                <div style={{ flex:1 }}>
                  <div style={{ fontSize:'.9rem', fontWeight:600, display:'flex', alignItems:'center', gap:6, flexWrap:'wrap' }}>
                    {localizedText(tpl.title_i18n, tpl.template_title) || t({ id: 'common.noTitle' })}
                    {!tpl.is_active && (
                      <span className="cat-pill" style={{ fontSize:'.62rem', padding:'1px 6px', background:'rgba(255,255,255,.1)' }}>
                        {t({ id: 'biblioteca.rules.inactive' })}
                      </span>
                    )}
                    <span className={`cat-pill ${isRecurrent?'info':''}`} style={{ fontSize:'.62rem', padding:'1px 6px' }}>
                      {isRecurrent
                        ? t({ id: 'biblioteca.templates.cadenceBadge' }, { count: tpl.interval_count, unit: t({ id: `biblioteca.templates.unit.${tpl.interval_unit}` }) })
                        : t({ id: 'biblioteca.templates.punctualBadge' })}
                    </span>
                  </div>
                  <div style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>
                    {tpl.label || '—'}
                    {tpl.template_tags?.length>0 && ` · ${tpl.template_tags.join(', ')}`}
                  </div>
                  {localizedText(tpl.description_i18n, tpl.template_description) && (
                    <div style={{ fontSize:'.82rem', color:'var(--brand-muted)', marginTop:2 }}>
                      {localizedText(tpl.description_i18n, tpl.template_description)}
                    </div>
                  )}
                </div>
                <div style={{ display:'flex', gap:4, flexShrink:0, alignItems:'center' }}>
                  <span className={`cat-pill ${tpl.template_priority==='alta'?'danger':tpl.template_priority==='baixa'?'info':'warn'}`} style={{ fontSize:'.65rem' }}>
                    {TASK_PRIO[tpl.template_priority]||tpl.template_priority}
                  </span>
                  <button className="cat-btn secondary" onClick={()=>{ setInstantiateFor(instantiateFor===tpl.id?null:tpl.id); setInstantiateDate(''); }}
                    disabled={!!editingTemplate} style={{ fontSize:'.78rem', padding:'4px 10px' }}>
                    {t({ id: 'biblioteca.templates.instantiate' })}
                  </button>
                  <button className="cat-btn secondary" onClick={()=>startEditTemplate(tpl)}
                    disabled={!!editingTemplate} style={{ fontSize:'.78rem', padding:'4px 10px' }}>
                    {t({ id: 'membership.config.action.edit' })}
                  </button>
                  <button className="cat-btn ghost" onClick={()=>deleteTemplate(tpl)}
                    disabled={!!editingTemplate} style={{ fontSize:'.78rem', padding:'4px 8px', color:'#f87171' }}>
                    {t({ id: 'common.discard' })}
                  </button>
                </div>
              </div>
              {/* Mini-formulaire d'instanciation : champ date optionnel */}
              {instantiateFor===tpl.id && (
                <div style={{ display:'flex', gap:8, alignItems:'center', flexWrap:'wrap', padding:'8px 10px', borderRadius:8, background:'rgba(251,191,36,.08)' }}>
                  <span style={{ fontSize:'.82rem', color:'var(--brand-muted)' }}>
                    {t({ id: 'biblioteca.templates.instantiateDateLabel' })}
                  </span>
                  <input type="date" value={instantiateDate}
                    onChange={e=>setInstantiateDate(e.target.value)}
                    style={{...fs, width:'auto'}} />
                  <button className="cat-btn primary" onClick={()=>instantiateTemplate(tpl.id, instantiateDate)}
                    style={{ fontSize:'.8rem', padding:'4px 10px' }}>
                    {t({ id: 'biblioteca.templates.instantiateConfirm' })}
                  </button>
                  <span style={{ fontSize:'.75rem', color:'var(--brand-muted)', fontStyle:'italic' }}>
                    {isRecurrent
                      ? t({ id: 'biblioteca.templates.instantiateRecurrentHint' })
                      : t({ id: 'biblioteca.templates.instantiateDateHint' })}
                  </span>
                </div>
              )}
            </div>
            );
          })}
        </div>
      )}
    </div>)}

    {/* ── Sous-onglet CATALOGO (chantier #TASKS p3) ── */}
    {tasksSubtab==='catalogo' && (() => {
      // Le texte des suggestions vient de la donnee (jsonb 8 langues).
      // Helper de lecture localisee avec repli sur pt-BR puis 1re cle.
      const i18nField = (obj) => {
        if (!obj) return '';
        return obj[locale] || obj['pt-BR'] || Object.values(obj)[0] || '';
      };
      // Regroupement par categorie, ordre = display_order (deja trie
      // au chargement). On conserve l'ordre d'apparition des categories.
      // Masquer les suggestions deja adoptees en tache-type (lien via
      // adopted_from_suggestion_code). Supprimer le modele les fait
      // reapparaitre. Le backfill par titre (migration) couvre l'historique.
      const adoptedCodes = new Set((templates || []).map(tp => tp.adopted_from_suggestion_code).filter(Boolean));
      const availableSuggestions = suggestions.filter(s => !adoptedCodes.has(s.code));
      const byCategory = [];
      const seen = new Map();
      for (const s of availableSuggestions) {
        if (!seen.has(s.category)) {
          const grp = { category: s.category, items: [] };
          seen.set(s.category, grp);
          byCategory.push(grp);
        }
        seen.get(s.category).items.push(s);
      }
      return (
      <div>
        <div style={{ fontSize:'.85rem', color:'var(--brand-muted)', marginBottom:12 }}>
          {t({ id: 'biblioteca.catalog.hint' })}
        </div>
        {availableSuggestions.length===0 && (
          <div style={{ fontSize:'.88rem', color:'var(--brand-muted)', fontStyle:'italic', padding:'8px 2px' }}>
            {t({ id: 'biblioteca.catalog.empty' })}
          </div>
        )}
        {byCategory.map(grp => (
          <div key={grp.category} style={{ marginBottom:16 }}>
            <h4 style={{ margin:'0 0 8px', fontSize:'.92rem' }}>
              {t({ id: `biblioteca.catalog.category.${grp.category}`, defaultMessage: grp.category })}
            </h4>
            <div style={lw}>
              {grp.items.map((s,i)=>{
                const isRecurrent = s.suggested_interval_count!=null && s.suggested_interval_unit!=null;
                return (
                <div key={s.id} style={{ ...lr(i), alignItems:'flex-start', gap:10 }}>
                  <div style={{ flex:1, minWidth:0 }}>
                    <div style={{ fontSize:'.9rem', fontWeight:600, display:'flex', alignItems:'center', gap:6, flexWrap:'wrap' }}>
                      {i18nField(s.title_i18n)}
                      <span className={`cat-pill ${isRecurrent?'info':''}`} style={{ fontSize:'.62rem', padding:'1px 6px' }}>
                        {isRecurrent
                          ? t({ id: 'biblioteca.templates.cadenceBadge' }, { count: s.suggested_interval_count, unit: t({ id: `biblioteca.templates.unit.${s.suggested_interval_unit}` }) })
                          : t({ id: 'biblioteca.templates.punctualBadge' })}
                      </span>
                    </div>
                    <div style={{ fontSize:'.82rem', color:'var(--brand-muted)', marginTop:2 }}>
                      {i18nField(s.description_i18n)}
                    </div>
                  </div>
                  <button className="cat-btn secondary" onClick={()=>adoptSuggestion(s.code)}
                    style={{ fontSize:'.78rem', padding:'4px 10px', flexShrink:0 }}>
                    {t({ id: 'biblioteca.catalog.adopt' })}
                  </button>
                </div>
                );
              })}
            </div>
          </div>
        ))}
      </div>
      );
    })()}
  </div>
  );
}
