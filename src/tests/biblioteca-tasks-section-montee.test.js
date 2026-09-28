// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/biblioteca-tasks-section-montee.test.js
//
// CE QUE CE TEST PROTÈGE. E6, BibliotecaPage lot 2 (28/09/2026) : l'onglet
// « Tarefas internas » sort de BibliotecaPage.jsx (TasksSection.jsx). Même
// méthode que le lot 1 : on lit la SOURCE et on garde le contrat que ni lint,
// ni build, ni suite ne verraient casser :
//   1. la section est MONTÉE sous l'onglet `tasks`, après la modération des
//      notes de lecture, et reçoit les trois listes, les libellés de priorité
//      et `onChanged` ;
//   2. les listes restent chargées par le parent (loadHeavy ; le rapport lit
//      les tâches et leurs libellés) ; les états de formulaire, les fonctions
//      et les deux mémos par échéance ont suivi ;
//   3. la section appelle les RPC des tâches et des modèles, prévient par
//      onChanged, jamais par loadAll, et prend ses styles au module commun.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const src = (rel) => readFileSync(path.resolve(here, '..', rel), 'utf8');

const page = src('pages/biblioteca/BibliotecaPage.jsx');
const section = src('pages/biblioteca/TasksSection.jsx');

describe('section des tâches internes (E6, lot 2) — réellement montée', () => {
  it('est rendue sous l’onglet tasks, après la modération des notes', () => {
    const notes = page.indexOf("{tab==='notas'");
    const mount = page.indexOf('<TasksSection');
    expect(notes).toBeGreaterThan(-1);
    expect(mount).toBeGreaterThan(notes);
    expect(page.slice(mount - 40, mount)).toMatch(/\{tab==='tasks' && \(\s*$/);
    expect(page.indexOf("import TasksSection from './TasksSection';")).toBeGreaterThan(-1);
  });

  it('reçoit les trois listes, les priorités et onChanged', () => {
    const mount = page.indexOf('<TasksSection');
    const props = page.slice(mount, page.indexOf('/>', mount));
    expect(props).toMatch(/libraryId=\{libraryId\} tasks=\{tasks\} templates=\{templates\} suggestions=\{suggestions\}/);
    expect(props).toMatch(/taskPrio=\{TASK_PRIO\} setMsg=\{setMsg\} onChanged=\{loadAll\}/);
    // les listes et les libellés restent au parent : loadHeavy les charge, le rapport les lit
    for (const stays of ['const [tasks, setTasks] = useState([])', 'const [templates, setTemplates] = useState([])', 'const [suggestions, setSuggestions] = useState([])', 'const TASK_PRIO = useMemo', 'const TASK_STATUS = useMemo', "supabase.from('painel_internal_tasks')"]) {
      expect(page.includes(stays), `${stays} devrait rester dans BibliotecaPage`).toBe(true);
    }
    expect(section.includes('painel_internal_tasks')).toBe(false);
  });

  it('a emporté les états de formulaire, les fonctions et les mémos', () => {
    for (const gone of ['newTask', 'tasksSubtab', 'editingTemplate', 'instantiateFor', 'instantiateDate', 'localizedText', 'createTask', 'updateTaskStatus', 'saveTemplate', 'deleteTemplate', 'instantiateTemplate', 'adoptSuggestion', 'inviteToTask', 'tasksByBucket', 'closedTasks']) {
      expect(page.includes(gone), `${gone} encore dans BibliotecaPage`).toBe(false);
      expect(section.includes(gone), `${gone} absent de TasksSection`).toBe(true);
    }
    expect((section.match(/useState\(/g) || []).length).toBe(6); // cinq états + saving local
    for (const rpc of ['fn_task_create', 'fn_task_update_status', 'fn_task_delete', 'fn_task_invite', 'fn_recurring_task_rule_create', 'fn_recurring_task_rule_update', 'fn_recurring_task_rule_delete', 'fn_task_instantiate_template', 'fn_task_adopt_suggestion']) {
      expect(section.includes(rpc), `${rpc} absent de TasksSection`).toBe(true);
    }
  });

  it('prévient par onChanged et prend ses styles au module commun', () => {
    expect((section.match(/await onChanged\?\.\(\);/g) || []).length).toBe(8);
    expect(section.includes('loadAll')).toBe(false);
    expect(section).toMatch(/import \{ fs, ls, bx, lr, lw \} from '\.\/styles';/);
    expect(section).toMatch(/const \{ formatMessage: t, locale \} = useIntl\(\);/);
    expect(section).toMatch(/const TASK_PRIO = taskPrio;/);
  });
});
