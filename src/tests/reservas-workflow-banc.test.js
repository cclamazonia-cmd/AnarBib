// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/reservas-workflow-banc.test.js
//
// BANC DES MAILS DE NÉGOCIATION DU RETRAIT (21/09/2026) — domain/reservas.ts,
// handleReservaV2WorkflowEvent. Aucun test ne l'exécutait. Écrit avant de toucher à
// sa dernière adresse en dur (dette app-url, dernier fichier) : le bouton « ouvrir le
// panneau » du mail à la bibliothèque, qui n'existe que lorsqu'une action du staff est
// attendue (contre-proposition de la personne). Vrais modules — données comprises
// (_shared/data/reservas.ts) — par src/tests/helpers/monter-ef.js.
// Il ne couvre PAS les trois autres handlers du fichier (création, changement de
// statut, réponse au créneau).

import { describe, it, expect } from 'vitest';
import { monterEF, liens, mailA } from './helpers/monter-ef.js';

const CTX = { library_id: 'lib-1', library_name: 'Biblioteca Louise Michel', library_short_name: 'BLMF', default_locale: 'pt-BR', admin_notification_email: 'coordination@biblio.test', delivery_mode: 'platform_shared', channel_active: true };
const LECTRICE = { id: 'u-1', email: 'lectrice@exemplo.test', first_name: 'Lou', last_name: 'M', consent_email: true, preferred_language: 'fr' };
const ligne = (over = {}) => ({ reserva_id: 'r-1', user_id: 'u-1', line_no: 1, sub_id: 'a', bib_ref: 'BLMF-0012', autor: 'RECLUS', titulo: "L'Homme et la Terre", rotulo: null, item_status: 'ativa', workflow_stage_effective: 'retirada_a_combinar', workflow_note: null, pickup_scheduled_for: '2026-10-02T17:00:00Z', pickup_reply_status: null, pickup_reply_note: null, pickup_reply_at: null, pickup_proposed_by: 'leitor', negotiation_iteration_count: 1, ...over });

function monter({ env = {}, ctx = CTX, item = ligne(), resend } = {}) {
  const ef = monterEF({
    env,
    resend,
    repondre: (_s, table) => {
      if (table === 'reservas_v2') return { data: { id: 'r-1', user_id: 'u-1', library_id: 'lib-1', status_global: 'ativa', notes: null }, error: null };
      if (table === 'profiles') return { data: LECTRICE, error: null };
      if (table === 'reserva_itens_followup_ui') return { data: [item], error: null };
      if (table === 'v_library_notification_context') return { data: ctx, error: null };
      return { data: null, error: null };
    },
  });
  const lancer = (event, payload = {}) => ef.charger('_shared/domain/reservas.ts').handleReservaV2WorkflowEvent('r-1', event, payload);
  return { ef, lancer };
}

describe('domain/reservas — la négociation du retrait', () => {
  it('contre-proposition de la personne : elle reçoit son mail dans SA langue ; la biblio, dans la sienne, avec le bouton vers le panneau', async () => {
    const { ef, lancer } = monter();
    const r = await lancer('retirada_a_combinar');
    expect(r.user_result).toMatchObject({ ok: true, email: 'lectrice@exemplo.test' });
    expect(r.admin_result).toMatchObject({ ok: true, email: 'coordination@biblio.test' });
    const staff = mailA(ef.envois, 'coordination@biblio.test');
    expect(liens(staff.html)).toContain('https://app.anarbib.org/painel');
    expect(staff.html).toContain('Homme et la Terre');
    expect(liens(mailA(ef.envois, 'lectrice@exemplo.test').html)).not.toContain('https://app.anarbib.org/painel');
  });

  // ROUGE sur le code intact (adresse écrite en dur) ; vert depuis _shared/core/app-url.ts.
  it('le bouton vers le panneau suit APP_BASE_URL (barre finale tolérée)', async () => {
    const { ef, lancer } = monter({ env: { APP_BASE_URL: 'https://app.anarbib.is/' } });
    await lancer('retirada_a_combinar');
    const l = liens(mailA(ef.envois, 'coordination@biblio.test').html);
    expect(l).toContain('https://app.anarbib.is/painel');
    expect(l.filter((h) => h.startsWith('https://app.anarbib.org'))).toEqual([]);
  });

  it('créneau verrouillé (rien à faire côté biblio) : mail d\'information, SANS bouton', async () => {
    const { ef, lancer } = monter({ item: ligne({ workflow_stage_effective: 'retirada_agendada' }) });
    await lancer('retirada_agendada');
    expect(ef.envois).toHaveLength(2);
    expect(liens(mailA(ef.envois, 'coordination@biblio.test').html)).not.toContain('https://app.anarbib.org/painel');
  });

  it('en préparation : la personne seule est prévenue ; copie biblio coupée par réglage : sautée en le disant', async () => {
    const a = monter({ item: ligne({ workflow_stage_effective: 'em_preparacao', pickup_proposed_by: null }) });
    const r1 = await a.lancer('em_preparacao');
    expect(a.ef.envois.map((e) => e.to[0])).toEqual(['lectrice@exemplo.test']);
    expect(r1.admin_result).toMatchObject({ skipped: true, reason: 'em_preparacao_no_admin_mail' });
    const b = monter({ ctx: { ...CTX, admin_copy_reservations_enabled: false } });
    const r2 = await b.lancer('retirada_a_combinar');
    expect(r2.admin_result).toMatchObject({ skipped: true, reason: 'reservation_admin_copy_disabled' });
    expect(b.ef.envois.map((e) => e.to[0])).toEqual(['lectrice@exemplo.test']);
  });
});
