// src/lib/taskStatus.js — le vocabulaire des tâches internes, en un seul lieu
// (29/09/2026).
//
// LE CONSTAT. Le 31/08 (item F6), la base a reçu les sept états du cycle de vie
// d'une tâche, tenus par `painel_internal_tasks_status_check`, et `aberta` pour
// défaut. Les écrans, eux, ont gardé l'ancien vocabulaire — `pendente`,
// `em_andamento`, `concluida`, `cancelada` — chacun dans sa propre liste, et
// cinq fonctions SQL écrivaient encore `pendente` : créer une tâche, instancier
// un modèle, régénérer une tâche récurrente levaient 23514. Aucune tâche n'a pu
// être créée entre le 31/08 et le 29/09 (constat de Xavier à l'écran).
//
// LA RÈGLE. Les listes vivent ici et nulle part ailleurs ; le banc
// `task-status-vocabulaire.test.js` compare TASK_STATES à la contrainte de la
// base, lue dans les migrations. Ajouter un état = la contrainte, cette liste,
// et les dix locales.

// Le cycle de vie, dans l'ordre : ouverte → à faire → en cours → bloquée →
// terminée | annulée | archivée.
export const TASK_STATES = ['aberta', 'a_fazer', 'em_andamento', 'bloqueada', 'concluida', 'cancelada', 'arquivada'];

// Les états vivants : ceux qu'un tableau de bord montre et qu'une échéance concerne.
export const TASK_LIVE = ['aberta', 'a_fazer', 'em_andamento', 'bloqueada'];

// Les états de sortie : la tâche n'appelle plus d'action.
export const TASK_CLOSED = ['concluida', 'cancelada', 'arquivada'];

// Ce que le menu « avancer » d'une tâche vivante propose (on ne revient pas à
// « ouverte », et l'archivage se fait depuis la page Bibliothèque).
export const TASK_ADVANCE = ['a_fazer', 'em_andamento', 'bloqueada', 'concluida', 'cancelada'];

// Les priorités, telles que la base les tient (CHECK des modèles, défaut des tâches).
export const TASK_PRIORITIES = ['baixa', 'media', 'alta'];

export const isTaskClosed = (status) => TASK_CLOSED.includes(status);

// Identifiants i18n écrits en toutes lettres : la garde code ↔ locales ne suit
// pas un identifiant composé à l'exécution. `pendente` reste libellé pour une
// ligne qu'une reprise manuelle aurait écrite avant la contrainte.
const LABEL_IDS = {
  aberta: 'task.status.aberta',
  a_fazer: 'task.status.a_fazer',
  em_andamento: 'task.status.em_andamento',
  bloqueada: 'task.status.bloqueada',
  concluida: 'task.status.concluida',
  cancelada: 'task.status.cancelada',
  arquivada: 'task.status.arquivada',
  pendente: 'task.status.pendente',
};

export function taskStatusLabel(t, status) {
  const id = LABEL_IDS[status];
  return id ? t({ id }) : (status || '—');
}
