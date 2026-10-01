// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/aiguillage-branches-mortes.test.js
//
// F1, troisième critère (01/10/2026) : les branches de courriel sans émetteur sont
// SUPPRIMÉES — carte docs/journal/audits/CARTE_chaine_courriel_2026-09-30.md, section
// « Les branches mortes ». Ce banc monte le VRAI aiguillage (core/dispatch.ts et tout
// ce qu'il importe, par src/tests/helpers/monter-ef.js) et prouve deux choses :
//   - un événement retiré rend null SANS rien lire : notify-event répond « ignored » ;
//   - chaque événement VIVANT est encore aiguillé vers un handler (qui lit sa table,
//     rend un résultat, ou lève faute de données — tout sauf null).
// La liste VIVANTS est celle de l'aiguillage du 30/09 moins les retraits : un
// événement vivant retiré par mégarde rougit ici.
// Ce que le banc ne prouve pas : que la base n'émet plus les événements retirés —
// c'est la suite tests/sql/branches_mortes_courriel_tests.sql (déclencheur) et le
// relevé de prosrc noté dans la carte.

import { describe, it, expect } from 'vitest';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { monterEF, FONCTIONS } from './helpers/monter-ef.js';

const MORTS = [
  // branche legacy v1 (legacy.ts)
  'reserva_criada', 'emprestimo_criado', 'emprestimo_devolvido', 'lembrete_devolucao_5d', 'aviso_atraso_7d',
  // créneau replanifié (stage re-retirada_agendada interdit depuis la v3)
  'reserva_retirada_reagendada', 'retirada_reagendada',
  // réponse au créneau, modèle v2
  'reserva_leitor_confirma_horario', 'retirada_confirmada_leitor', 'reserva_leitor_recusa_horario', 'retirada_recusada_leitor',
  // retour programmé, annulé, manqué
  'emprestimo_devolucao_agendada', 'emprestimo_devolucao_cancelada', 'emprestimo_devolucao_nao_realizada',
  // rappels et relances d'avant F4 (notify-loan-cycle les remplace)
  'lembrete_v2_devolucao_5d', 'lembrete_v2_devolucao_3d', 'lembrete_v2_devolucao_hoje',
  'aviso_v2_atraso_1d', 'aviso_v2_atraso_7d', 'aviso_v2_atraso_30d',
  // refus de réservation et alias : le déclencheur n'émet que les noms canoniques
  'reserva_v2_recusada', 'reserva_v2_cancelada_staff', 'reserva_v2_cancelada_reader', 'expirada',
  'convertida_em_emprestimo', 'reserva_em_preparacao', 'reserva_retirada_a_combinar', 'reserva_retirada_agendada',
  'reserva_pronta_para_retirada', 'retirada_nao_realizada', 'retirada_no_show', 'reserva_liberada_para_circulacao',
];

const VIVANTS = [
  'team.invitation_created', 'network.assembleia.convocada', 'network.cooptation_proposed', 'authority.proposal_opened',
  'gazette.contribution.received', 'cartography.submission_received', 'bug_report.received', 'lettre.optin.confirm',
  'reader_message_sent', 'library_message_sent',
  'cotisation_payment_recorded', 'cotisation_expiring', 'deposit_collected', 'deposit_refunded',
  'validation_confirmed', 'reader_identity_assigned', 'membership_validation_requested', 'membership_refused',
  'member_restricted_local', 'member_unrestricted_local', 'member_frozen_global', 'member_unfrozen_global',
  // les douze noms que trg_notify_reserva_workflow_change émet (relevé du 01/10)
  'reserva_v2_criada', 'em_preparacao', 'retirada_a_combinar', 'retirada_agendada', 'pronta_para_retirada',
  'reserva_nao_retirada', 'liberada_para_circulacao', 'reserva_cancelada_biblioteca', 'reserva_cancelada_leitor',
  'reserva_expirada', 'reserva_convertida_em_emprestimo',
  'emprestimo_v2_criado', 'emprestimo_v2_prorrogado', 'emprestimo_v2_devolvido',
  'emprestimo_v2_parcialmente_devolvido', 'emprestimo_v2_devolvido_apos_parcial',
  'consulta_v2_criada', 'consulta_v2_realizada', 'consulta_v2_cancelada', 'consulta_v2_expirada',
  'consulta_v2_em_preparacao', 'consulta_v2_agendada', 'consulta_v2_nao_compareceu', 'consulta_v2_resposta_creneau',
  'rgpd_purge_warning_loans', 'rgpd_purge_warning_reservations', 'rgpd_purge_warning_consultations',
  'partnership_proposed', 'partnership_accepted', 'partnership_refused', 'partnership_broken',
  'partnership_transparence_enabled', 'partnership_config_expanded',
  'entraide_request_circle',
];

function monter() {
  const lus = [];
  const ef = monterEF({ repondre: (schema, table) => { lus.push(`${schema}.${table}`); return { data: null, error: null }; } });
  const dispatch = ef.charger('_shared/core/dispatch.ts').dispatchNotifyEvent;
  const taches = ef.charger('_shared/domain/internal-tasks.ts').handleInternalTaskNotification;
  return { ef, lus, dispatch, taches };
}

const issue = (p) => p.then((r) => r, (e) => ({ leve: String(e?.message || e) }));

describe('F1 — les branches mortes ne sont plus aiguillées', () => {
  it.each(MORTS)('%s rend null sans rien lire', async (ev) => {
    const { dispatch, lus, ef } = monter();
    expect(await dispatch(ev, 123, { event: ev, record_id: 123 })).toBeNull();
    expect(lus).toEqual([]);
    expect(ef.envois).toEqual([]);
  });

  it.each(VIVANTS)('%s reste aiguillé vers un handler', async (ev) => {
    const { dispatch } = monter();
    const r = await issue(dispatch(ev, 123, { event: ev, record_id: 123 }));
    expect(r).not.toBeNull();
  });

  it('aucun nom n’est à la fois mort et vivant', () => {
    expect(MORTS.filter((e) => VIVANTS.includes(e))).toEqual([]);
  });
});

describe('F1 — notify-internal-task ne connaît que trois « kind »', () => {
  it('sans kind (l’ancienne branche assigned / reminder) : rejeté, rien lu, rien envoyé', async () => {
    const { taches, lus, ef } = monter();
    for (const payload of [{ task_id: 't1' }, { task_id: 't1', event_type: 'due_today', owner_email: 'x@exemple.test' }, { task_id: 't1', kind: 'assigned' }]) {
      await expect(taches(payload)).rejects.toThrow(/^unknown_kind:/);
    }
    expect(lus).toEqual([]);
    expect(ef.envois).toEqual([]);
  });

  it.each(['task_invitation', 'task_owner_notice', 'task_library_notice'])('%s est toujours traité', async (kind) => {
    const { taches } = monter();
    const r = await issue(taches({ task_id: 't1', kind, email: 'x@exemple.test' }));
    expect(String(r?.leve || '')).not.toMatch(/unknown_kind/);
  });
});

describe('F1 — ce qui a été retiré ne revient pas', () => {
  const lire = (rel) => readFileSync(path.join(FONCTIONS, rel), 'utf8');

  it('legacy.ts et notify-mid-loan-reading n’existent plus, ni leur section de config.toml', () => {
    expect(existsSync(path.join(FONCTIONS, '_shared/domain/legacy.ts'))).toBe(false);
    expect(existsSync(path.join(FONCTIONS, 'notify-mid-loan-reading'))).toBe(false);
    expect(lire('../config.toml')).not.toMatch(/\[functions\.notify-mid-loan-reading\]/);
  });

  it('le secret du mi-parcours reste lu par notify-loan-cycle (il ne part pas avec la fonction)', () => {
    expect(lire('notify-loan-cycle/index.ts')).toContain("Deno.env.get('WEBHOOK_SECRET_NOTIFY_MID_LOAN')");
  });

  it('le rapport hebdomadaire n’écrit plus dans une table qui n’existe pas', () => {
    const src = lire('notify-weekly-report/index.ts');
    expect(src).not.toContain('from("weekly_admin_report_runs")');
    expect(src).not.toMatch(/run_id:|body\?\.run_id/);
  });
});
