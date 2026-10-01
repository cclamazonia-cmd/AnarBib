// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/mail-status-footer-i18n.test.js
//
// BANC DE NON-RÉGRESSION i18n DES COURRIELS (F21)
//
// Relevé par la carte F1 (30/09/2026) :
// Sans `footer_local` (cas des bibliothèques réelles), le contexte de repli
// posait un pied de page et une signature en portugais que `tMail` ne traduisait
// plus : tout courriel de bibliothèque se terminait en pt-BR, quelle que soit
// la langue de la personne. Et la ligne « Status » des courriels de réservation
// venait d'une table codée en dur en pt-BR (WF_LABELS).
//
// Ce test vérifie qu'un courriel rendu en français (fr), néerlandais (nl) ou
// grec (el) ne contient AUCUNE trace de portugais résiduel.

import { describe, it, expect } from 'vitest';
import { monterEF, mailA } from './helpers/monter-ef.js';

// Morceaux de texte portugais caractéristiques des anciens fallbacks et WF_LABELS
const MOTS_PORTUGAIS = [
  'Mensagem automática da biblioteca',
  'Responda apenas se o campo',
  'Equipe da biblioteca',
  'Reserva recebida',
  'Livro em preparação',
  'Retirada agendada',
  'Retirada a combinar',
  'Livro pronto para retirada',
  'Retirada não realizada',
  'Item devolvido à circulação',
  'Cancelada pelo leitor',
  'Cancelada pela biblioteca',
];

const CTX_SANS_FOOTER = {
  library_id: 'lib-fr',
  library_name: 'Bibliothèque Louise Michel',
  library_short_name: 'BLM',
  default_locale: 'fr',
  footer_local: null,
  signature_short: null,
  admin_notification_email: 'equipe@blm.test',
  delivery_mode: 'platform_shared',
  channel_active: true,
};

const ligneReserva = (stage = 'retirada_agendada') => ({
  reserva_id: 'r-1',
  user_id: 'u-1',
  line_no: 1,
  sub_id: 'a',
  bib_ref: 'BLM-001',
  autor: 'Élisée Reclus',
  titulo: "L'Homme et la Terre",
  rotulo: null,
  item_status: 'ativa',
  workflow_stage_effective: stage,
  workflow_note: null,
  pickup_scheduled_for: '2026-10-05T14:00:00Z',
  pickup_reply_status: null,
  pickup_reply_note: null,
  pickup_reply_at: null,
  pickup_proposed_by: 'biblio',
  negotiation_iteration_count: 0,
});

function monter({ lang = 'fr', ctx = CTX_SANS_FOOTER, stage = 'retirada_agendada', env = {} } = {}) {
  const lectrice = {
    id: 'u-1',
    email: 'lectrice@exemplo.test',
    first_name: 'Louise',
    last_name: 'Michel',
    consent_email: true,
    preferred_language: lang,
  };
  const ef = monterEF({
    env,
    repondre: (_s, table) => {
      if (table === 'reservas_v2') return { data: { id: 'r-1', user_id: 'u-1', library_id: ctx.library_id, status_global: 'ativa', notes: null }, error: null };
      if (table === 'profiles') return { data: lectrice, error: null };
      if (table === 'reserva_itens_followup_ui') return { data: [ligneReserva(stage)], error: null };
      if (table === 'v_library_notification_context') return { data: ctx, error: null };
      return { data: null, error: null };
    },
  });
  const lancerReserva = (event) => ef.charger('_shared/domain/reservas.ts').handleReservaV2WorkflowEvent('r-1', event, {});
  const layout = ef.charger('_shared/mail/layout.ts');
  const libContext = ef.charger('_shared/context/library-notification-context.ts');
  return { ef, lancerReserva, layout, libContext };
}

describe('F21 — Absence de portugais dans les courriels traduits', () => {
  it('fallbackLibraryNotificationContext pose footer_local et signature_short à null par défaut', () => {
    const { libContext } = monter();
    const fb = libContext.fallbackLibraryNotificationContext('lib-test');
    expect(fb.footer_local).toBeNull();
    expect(fb.signature_short).toBeNull();
  });

  it('ADMIN_NAME configuré est conservé dans signature_short', () => {
    const { ef } = monter({ env: { ADMIN_NAME: 'Coordination BLM' } });
    const libContext = ef.charger('_shared/context/library-notification-context.ts');
    const fb = libContext.fallbackLibraryNotificationContext('lib-custom');
    expect(fb.signature_short).toBe('Coordination BLM');
  });

  it('FOOTER_TEXT personnalisé est préservé dans footer_local', () => {
    const { ef } = monter({ env: { FOOTER_TEXT: 'Pied de page militant personnalisé' } });
    const libContext = ef.charger('_shared/context/library-notification-context.ts');
    const fb = libContext.fallbackLibraryNotificationContext('lib-custom');
    expect(fb.footer_local).toBe('Pied de page militant personnalisé');
  });

  it('wf.stage.cancelada_leitor applique l\'écriture inclusive en de, it et ca', () => {
    const { ef } = monter();
    const { tMail } = ef.charger('_shared/i18n/mail-strings.ts');
    expect(tMail('de', 'wf.stage.cancelada_leitor')).toBe('Von der*dem Leser*in storniert');
    expect(tMail('it', 'wf.stage.cancelada_leitor')).toBe('Annullata dal/la lettore/trice');
    expect(tMail('ca', 'wf.stage.cancelada_leitor')).toBe('Cancel·lada per le lector-a-e');
  });

  for (const [lang, nomLang, labelStatutAttendu] of [
    ['fr', 'français', 'Retrait planifié'],
    ['nl', 'néerlandais', 'Ophaling ingepland'],
    ['el', 'grec', 'Παραλαβή προγραμματισμένη'],
  ]) {
    it(`un courriel de réservation en ${nomLang} (${lang}) ne contient aucun résidu de portugais`, async () => {
      const { ef, lancerReserva } = monter({ lang, stage: 'retirada_agendada' });
      await lancerReserva('retirada_agendada');
      const userMail = mailA(ef.envois, 'lectrice@exemplo.test');
      expect(userMail).toBeTruthy();

      // Vérification du statut traduit
      expect(userMail.html).toContain(labelStatutAttendu);

      // Refus strict de tout résidu de portugais
      for (const phrase of MOTS_PORTUGAIS) {
        expect(userMail.html, `Présence de portugais en ${lang} : « ${phrase} »`).not.toContain(phrase);
        expect(userMail.text, `Présence de portugais (texte) en ${lang} : « ${phrase} »`).not.toContain(phrase);
      }
    });
  }

  it('les statuts de réservation sont traduits selon la langue (ex: em_preparacao -> En préparation)', async () => {
    const { ef, lancerReserva } = monter({ lang: 'fr', stage: 'em_preparacao' });
    await lancerReserva('em_preparacao');
    const userMail = mailA(ef.envois, 'lectrice@exemplo.test');
    expect(userMail.html).toContain('En préparation');
    expect(userMail.html).not.toContain('Livro em preparação');
    expect(userMail.html).not.toContain('Em preparação');
  });

  it('la copie équipe dans une bibliothèque francophone est en français', async () => {
    const ctxFR = { ...CTX_SANS_FOOTER, default_locale: 'fr' };
    const { ef, lancerReserva } = monter({ lang: 'fr', ctx: ctxFR, stage: 'retirada_agendada' });
    await lancerReserva('retirada_agendada');
    const staffMail = mailA(ef.envois, 'equipe@blm.test');
    expect(staffMail).toBeTruthy();
    expect(staffMail.html).toContain('Retrait planifié');
    expect(staffMail.html).not.toContain('Retirada agendada');
    for (const phrase of MOTS_PORTUGAIS) {
      expect(staffMail.html, `Présence de portugais dans la copie staff : « ${phrase} »`).not.toContain(phrase);
    }
  });
});
