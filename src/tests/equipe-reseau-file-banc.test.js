// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/equipe-reseau-file-banc.test.js
//
// BANC DE LA FILE DES MAILS D'ÉQUIPE ET DE RÉSEAU (21/09/2026) — domain/team.ts et
// domain/network.ts partagent team_notification_outbox et le patron
// « recipients_count === 0 → skipped, sinon sent ». Aucun test ne les exécutait.
// Un événement représentatif par module suffit à éprouver CE patron (le statut de
// la ligne après l'envoi) ; il ne couvre pas la vingtaine d'autres événements.
//   - team.promoted_to_librarian : un mail à la personne + une copie à la biblio ;
//   - network.request_eval_digest : un fan-out vers les admins du réseau.
// Vrais modules, par src/tests/helpers/monter-ef.js.

import { describe, it, expect } from 'vitest';
import { monterEF, mailA } from './helpers/monter-ef.js';

const eq = (chaine, nom) => chaine.find((c) => c.op === 'eq' && c.args[0] === nom)?.args?.[1];
const PROFILS = {
  'u-1': { id: 'u-1', email: 'actrice@exemplo.test', first_name: 'Actrice', last_name: 'A', preferred_language: 'fr' },
  'u-2': { id: 'u-2', email: 'promue@exemplo.test', first_name: 'Promue', last_name: 'B', preferred_language: 'fr' },
  'u-8': { id: 'u-8', email: 'admin1@exemplo.test', first_name: 'Un', last_name: 'C', preferred_language: 'pt-BR' },
  'u-9': { id: 'u-9', email: 'admin2@exemplo.test', first_name: 'Deux', last_name: 'D', preferred_language: 'fr' },
};
const CTX = { library_id: 'lib-1', library_name: 'Biblioteca Louise Michel', library_short_name: 'BLMF', default_locale: 'fr', admin_notification_email: 'coordination@biblio.test', delivery_mode: 'platform_shared', channel_active: true };

function monter({ ligne, resend } = {}) {
  const ef = monterEF({
    resend,
    repondre: (_s, table, a, chaine) => {
      if (table === 'team_notification_outbox') return a('update') ? { data: null, error: null } : { data: ligne, error: null };
      if (table === 'libraries') return { data: { id: 'lib-1', name: 'Biblioteca Louise Michel', short_name: 'BLMF', regimento_published_url: '' }, error: null };
      if (table === 'v_library_notification_context') return { data: CTX, error: null };
      if (table === 'network_administrators') return { data: [{ user_id: 'u-8' }, { user_id: 'u-9' }], error: null };
      if (table === 'profiles') {
        if (a('in')) return { data: (a('in').args[1] || []).map((id) => PROFILS[id]).filter(Boolean), error: null };
        return { data: PROFILS[eq(chaine, 'id')] || null, error: null };
      }
      return { data: null, error: null };
    },
  });
  const etat = () => ef.ecrits.filter((e) => e.table === 'team_notification_outbox').map((e) => e.donnees);
  return { ef, etat };
}

const PROMOTION = { id: 21, status: 'queued', attempts: 0, event: 'team.promoted_to_librarian', payload: { library_id: 'lib-1', target_user_id: 'u-2', actor_user_id: 'u-1' } };
const DIGEST = { id: 22, status: 'queued', attempts: 0, event: 'network.request_eval_digest', payload: { kind: 'pending_backlog', pending_count: 3 } };

describe('domain/team — une promotion', () => {
  it('la personne promue et la coordination de la biblio reçoivent chacune leur mail ; la file passe à « sent »', async () => {
    const { ef, etat } = monter({ ligne: PROMOTION });
    const r = await ef.charger('_shared/domain/team.ts').handleTeamEvent(21);
    expect(r).toMatchObject({ ok: true, event: 'team.promoted_to_librarian' });
    expect(mailA(ef.envois, 'promue@exemplo.test')).toBeTruthy();
    expect(mailA(ef.envois, 'coordination@biblio.test')).toBeTruthy();
    expect(etat().map((d) => d.status)).toEqual(['sent']);
  });

  it('événement inconnu : sauté, nommé, sans mail', async () => {
    const { ef, etat } = monter({ ligne: { ...PROMOTION, event: 'team.autre' } });
    expect(await ef.charger('_shared/domain/team.ts').handleTeamEvent(21)).toMatchObject({ ignored: true, reason: 'unknown_team_event' });
    expect(ef.envois).toHaveLength(0);
    expect(etat()).toEqual([{ status: 'skipped', skip_reason: 'unknown_team_event' }]);
  });
});

describe('domain/network — le digest des demandes à évaluer', () => {
  it('chaque admin du réseau reçoit le digest, dans sa langue ; la file passe à « sent »', async () => {
    const { ef, etat } = monter({ ligne: DIGEST });
    const r = await ef.charger('_shared/domain/network.ts').handleNetworkEvent(22);
    expect(r).toMatchObject({ ok: true, event: 'network.request_eval_digest', recipients_count: 2 });
    expect(ef.envois.map((e) => e.to[0]).sort()).toEqual(['admin1@exemplo.test', 'admin2@exemplo.test']);
    expect(etat().map((d) => d.status)).toEqual(['sent']);
  });
});

// ── La file dit ce qui s'est passé (21/09/2026) ────────────────────────────────
// ROUGES sur le code du matin : les deux modules marquaient « sent » sans lire le
// résultat de l'envoi. Ils adoptent _shared/domain/outbox-verdict.ts.
describe('équipe et réseau — un envoi refusé ne passe plus pour envoyé', () => {
  const panne = () => new Response('panne', { status: 500 });

  it('promotion, transport en panne : « failed », et last_error nomme les deux destinataires', async () => {
    const { ef, etat } = monter({ ligne: PROMOTION, resend: panne });
    const r = await ef.charger('_shared/domain/team.ts').handleTeamEvent(21);
    expect(r).toMatchObject({ ok: false, outbox_status: 'failed' });
    const [d] = etat();
    expect(d.status).toBe('failed');
    expect(d.last_error).toContain('promue@exemplo.test');
    expect(d.last_error).toContain('coordination@biblio.test');
    expect(d.sent_at).toBeUndefined();
  });

  it('promotion, seule la copie à la biblio est refusée : « failed », et le détail dit qui a reçu (1 parti, 1 refusé)', async () => {
    const { ef, etat } = monter({ ligne: PROMOTION, resend: (p) => (p.to[0] === 'coordination@biblio.test' ? panne() : new Response('{}', { status: 200 })) });
    await ef.charger('_shared/domain/team.ts').handleTeamEvent(21);
    expect(mailA(ef.envois, 'promue@exemplo.test')).toBeTruthy();
    const [d] = etat();
    expect(d.status).toBe('failed');
    expect(d.last_error).toMatch(/^1 parti\(s\), 1 refuse\(s\)/);
    expect(d.last_error).toContain('coordination@biblio.test');
    expect(d.last_error).not.toContain('promue@exemplo.test');
  });

  it('digest du réseau, un admin sur deux refusé : « failed », avec le compte et le nom du refusé', async () => {
    const { ef, etat } = monter({ ligne: DIGEST, resend: (p) => (p.to[0] === 'admin2@exemplo.test' ? panne() : new Response('{}', { status: 200 })) });
    const r = await ef.charger('_shared/domain/network.ts').handleNetworkEvent(22);
    expect(r).toMatchObject({ ok: false, outbox_status: 'failed' });
    expect(ef.envois.map((e) => e.to[0])).toEqual(['admin1@exemplo.test']);
    const [d] = etat();
    expect(d.status).toBe('failed');
    expect(d.last_error).toMatch(/^1 parti\(s\), 1 refuse\(s\)/);
    expect(d.last_error).toContain('admin2@exemplo.test');
  });
});
