// AnarBib — Panneau, les tâches du jour (E6, lot A, 12/10/2026).
// Déplacé tel quel depuis PanelPage.jsx : une fonction pure qui lit les listes
// du panneau et rend les tâches triées (priorité haute d'abord). Même source
// pour l'onglet « Travail du jour » et pour le compteur du bandeau.
import { fmtD } from './_shared';
import { decodeSystemNote } from '@/lib/systemNotes';
import { taskStatusLabel } from '@/lib/taskStatus';

export function construireTachesDuJour({ t, displayTz, activeRes, overdueLoans, activeLoans, consultations, internalTasks }) {
    const tasks = [];
    const today = new Date().toISOString().slice(0, 10);

    activeRes.forEach(r => {
      const stage = r.workflow_stage_effective || '';
      const pickupDay = r.pickup_scheduled_for ? new Date(r.pickup_scheduled_for).toISOString().slice(0, 10) : '';

      // PATCH 09/05/2026 paquet 5b : refactor sémantique v3.
      // retirada_agendada = créneau verrouillé : si pickupDay = aujourd'hui,
      // c'est un retrait prévu aujourd'hui → tâche prioritaire bucket 'hoje'.
      // re-retirada_agendada conservé en filet pour résas historiques fossiles.
      if (['retirada_agendada', 're-retirada_agendada'].includes(stage) && pickupDay === today) {
        tasks.push({ priority: 'alta', bucket: 'hoje', kind: t({id:'panel.task.scheduledToday'}), label: `${r.user_name || r.user_email || r.user_public_id || '?'} · ${r.titulo}`, detail: t({id:'panel.task.detail.pickup'}) + ': ' + fmtD(r.pickup_scheduled_for, displayTz), actionType: 'reserva', reserva_id: r.reserva_id });
      }
      if (stage === 'solicitada') {
        tasks.push({ priority: 'media', bucket: 'atencao', kind: t({id:'panel.task.newReservation'}), label: `${r.user_name || r.user_email || r.user_public_id || '?'} · ${r.titulo}`, detail: `${t({id:'panel.task.detail.ref'})}: ${r.bib_ref} · ${t({id:'panel.task.detail.created'})}: ${fmtD(r.reserva_created_at)}`, actionType: 'reserva', reserva_id: r.reserva_id });
      }
      if (stage === 'pronta_para_retirada') {
        tasks.push({ priority: 'media', bucket: 'atencao', kind: t({id:'panel.task.readyForPickup'}), label: `${r.user_name || r.user_email || r.user_public_id || '?'} · ${r.titulo}`, detail: `${t({id:'panel.task.detail.validity'})}: ${fmtD(r.expires_at, displayTz)}`, actionType: 'reserva', reserva_id: r.reserva_id });
      }
      if (String(r.pickup_reply_status || '') === 'recusado_leitor') {
        tasks.push({ priority: 'alta', bucket: 'atencao', kind: t({id:'panel.task.readerRefused'}), label: `${r.user_name || r.user_email || r.user_public_id || '?'} · ${r.titulo}`, detail: r.pickup_reply_note || t({id:'panel.task.detail.reschedule'}), actionType: 'reserva', reserva_id: r.reserva_id });
      }
      // PATCH 08/05/2026 paquet 3B : tâche prioritaire "Leitor(a/e) contra-propôs"
      // déclenchée quand pickup_proposed_by = 'leitor' (= le lecteur a renvoyé
      // une contre-proposition que le staff doit traiter rapidement).
      // Priorité haute : la balle est dans le camp staff, action requise.
      // PATCH 09/05/2026 paquet 5b : refactor sémantique v3.
      // La négociation se déroule désormais dans retirada_a_combinar (forme
      // verbale = action en cours), plus dans retirada_agendada/re-retirada_agendada.
      if (r.pickup_proposed_by === 'leitor' && stage === 'retirada_a_combinar') {
        const iter = r.negotiation_iteration_count ?? 0;
        tasks.push({
          priority: 'alta',
          bucket: 'atencao',
          kind: t({id:'panel.task.readerCounterProposed'}),
          label: `${r.user_name || r.user_email || r.user_public_id || '?'} · ${r.titulo}`,
          detail: t({id:'panel.task.detail.proposedSlot'}) + ': ' + fmtD(r.pickup_scheduled_for, displayTz)
                  + ' · ' + t({id:'panel.task.detail.iteration'}, { count: iter, max: 3 }),
          actionType: 'reserva',
          reserva_id: r.reserva_id,
        });
      }
      if (stage === 'nao_retirada') {
        tasks.push({ priority: 'alta', bucket: 'atencao', kind: t({id:'panel.task.notPickedUp'}), label: `${r.user_name || r.user_email || r.user_public_id || '?'} · ${r.titulo}`, detail: decodeSystemNote(r.workflow_note, t) || t({id:'panel.task.detail.check'}), actionType: 'reserva', reserva_id: r.reserva_id });
      }
      // PATCH 09/05/2026 paquet 4 (approche A) : rendre visible le stage
      // retirada_a_combinar dans Trabalho do dia. Sinon ces résas restent
      // invisibles côté staff et le travail d'agendamento est oublié.
      // Priorité moyenne : action attendue mais sans urgence comme un
      // contra-proposta. Bucket atencao pour cohérence avec les autres
      // « il y a quelque chose à faire ».
      if (stage === 'retirada_a_combinar') {
        tasks.push({
          priority: 'media',
          bucket: 'atencao',
          kind: t({id:'panel.task.toScheduleWithReader'}),
          label: `${r.user_name || r.user_email || r.user_public_id || '?'} · ${r.titulo}`,
          detail: decodeSystemNote(r.workflow_note, t) || t({id:'panel.task.detail.scheduleHint'}),
          actionType: 'reserva',
          reserva_id: r.reserva_id,
        });
      }
    });

    overdueLoans.forEach(l => {
      const effectiveDue = l.extended_until || l.due_at;
      const due = effectiveDue ? new Date(effectiveDue) : null;
      const diff = due ? Math.ceil((new Date() - due) / 86400000) : 0;
      tasks.push({ priority: 'alta', bucket: 'atencao', kind: t({id:'panel.task.overdueItem'}), label: `${l.user_name || l.user_email || l.user_public_id || '?'} · ${l.titulo}`, detail: t({id:'panel.task.detail.deadline'}) + ': ' + fmtD(effectiveDue) + ' · ' + t({id:'panel.task.detail.daysOverdue'},{days:diff}) + ' · ' + l.sub_id, actionType: 'emprestimo', emprestimo_id: l.emprestimo_id });
    });

    activeLoans.filter(l => {
      const effectiveDue = l.extended_until || l.due_at;
      return effectiveDue && new Date(effectiveDue).toISOString().slice(0, 10) === today;
    }).forEach(l => {
      const effectiveDue = l.extended_until || l.due_at;
      tasks.push({ priority: 'media', bucket: 'hoje', kind: t({id:'panel.task.dueTodayItem'}), label: `${l.user_name || l.user_email || l.user_public_id || '?'} · ${l.titulo}`, detail: `${t({id:'panel.task.detail.deadline'})}: ${fmtD(effectiveDue)} · ${l.sub_id}`, actionType: 'emprestimo', emprestimo_id: l.emprestimo_id });
    });

    consultations.filter(c => c.workflow_stage_effective === 'solicitada').forEach(c => {
      tasks.push({ priority: 'media', bucket: 'atencao', kind: t({id:'panel.task.consultToProcess'}), label: `${c.user_name || c.user_email || c.user_public_id || '?'} · ${c.titulo}`, detail: `${t({id:'panel.task.detail.ref'})}: ${c.bib_ref}`, actionType: 'consulta', consulta_id: c.consulta_id });
    });

    // Internal tasks from biblioteca
    internalTasks.forEach(tk => {
      const dueDay = tk.due_date || '';
      const isOverdue = dueDay && dueDay < today;
      const isDueToday = dueDay === today;
      const priLabel = tk.priority === 'alta' ? t({id:'panel.task.priority.high'}) : tk.priority === 'baixa' ? t({id:'panel.task.priority.low'}) : t({id:'panel.task.priority.normal'});
      const statusLabel = taskStatusLabel(t, tk.status);
      tasks.push({
        priority: isOverdue || tk.priority === 'alta' ? 'alta' : 'media',
        bucket: isDueToday ? 'hoje' : isOverdue ? 'atencao' : 'acompanhamento',
        kind: `${t({id:'panel.summary.internalTasks'})} (${priLabel})`,
        label: tk.title || '—',
        detail: `${statusLabel}${tk.owner ? ` · ${tk.owner}` : ''}${dueDay ? ` · ${t({id:'panel.task.detail.prazo'})}: ${dueDay}` : ''}${isOverdue ? ` · ${t({id:'panel.task.detail.overdue'})}` : ''}`,
        actionType: 'tarefa', task_id: tk.id,
      });
    });

    return tasks.sort((a, b) => (a.priority === 'alta' ? 0 : 1) - (b.priority === 'alta' ? 0 : 1));
}
