// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/library-profile-banc.test.js
//
// BANC DES MAILS « PROFIL DE LA BIBLIOTHÈQUE » (21/09/2026) — domain/library_profile.ts,
// appelé par team.ts (team.library_profile.*) et network.ts (network.library_profile.*).
// Aucun test ne l'exécutait. Écrit AVANT d'y toucher, sur le vrai module, par
// src/tests/helpers/monter-ef.js. Un sous-événement suffit à éprouver ce qu'on va
// changer (l'adresse du bouton, le statut de la file) : `proposed`.
//
// DÉFAUTS ÉPINGLÉS PUIS CORRIGÉS (21/09) :
//   1. la ligne passait à « sent » sans lire le résultat des envois (même forme que la
//      Lettre et que les cinq modules repris le même jour par outbox-verdict.ts) ;
//   2. « sent » aussi quand il n'y avait AUCUN destinataire, et pour un sous-événement
//      inconnu — le module n'avait pas de markOutboxSkipped (B12 / DOC-SILENCE-1).

import { describe, it, expect } from 'vitest';
import { monterEF, liens, mailA } from './helpers/monter-ef.js';

const eq = (chaine, nom) => chaine.find((c) => c.op === 'eq' && c.args[0] === nom)?.args?.[1];
const PROFILS = {
  'u-1': { id: 'u-1', email: 'propose@exemplo.test', first_name: 'Propose', last_name: 'A', preferred_language: 'fr' },
  'u-2': { id: 'u-2', email: 'dois@exemplo.test', first_name: 'Dois', last_name: 'B', preferred_language: 'pt-BR' },
  'u-3': { id: 'u-3', email: 'trois@exemplo.test', first_name: 'Trois', last_name: 'C', preferred_language: 'fr' },
};
const CTX = { library_id: 'lib-1', library_name: 'Biblioteca Louise Michel', library_short_name: 'BLMF', default_locale: 'fr', admin_notification_email: 'coordination@biblio.test', delivery_mode: 'platform_shared', channel_active: true };
const PAYLOAD = { library_id: 'lib-1', proposal_id: 'p-1', axis: 'network_mode', old_value: 'autonomous', new_value: 'federated', transition_type: 3, motivation: 'Rejoindre la fédération.', proposed_by: 'u-1', expires_at: '2026-10-05T00:00:00Z' };

function monter({ env = {}, resend, event = 'team.library_profile.proposed', staff = ['u-1', 'u-2', 'u-3'] } = {}) {
  const ligne = { id: 31, status: 'queued', attempts: 0, event, payload: PAYLOAD };
  const ef = monterEF({
    env,
    resend,
    repondre: (_s, table, a, chaine) => {
      if (table === 'team_notification_outbox') return a('update') ? { data: null, error: null } : { data: ligne, error: null };
      if (table === 'libraries') return { data: { id: 'lib-1', name: 'Biblioteca Louise Michel', short_name: 'BLMF' }, error: null };
      if (table === 'v_library_notification_context') return { data: CTX, error: null };
      if (table === 'user_library_memberships') return { data: staff.map((user_id) => ({ user_id })), error: null };
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

describe('domain/library_profile — une proposition de changement de profil', () => {
  it('le staff actif SAUF la personne qui propose, chacun·e dans sa langue, avec le bouton vers la proposition', async () => {
    const { ef, etat } = monter();
    const r = await ef.charger('_shared/domain/library_profile.ts').handleLibraryProfileEvent(31);
    expect(r).toMatchObject({ ok: true, event: 'team.library_profile.proposed', recipients_count: 2 });
    expect(ef.envois.map((e) => e.to[0]).sort()).toEqual(['dois@exemplo.test', 'trois@exemplo.test']);
    for (const m of ef.envois) expect(liens(m.html)).toContain('https://app.anarbib.org/painel/biblioteca/lib-1/profil?proposal=p-1');
    expect(mailA(ef.envois, 'trois@exemplo.test').html).toContain('Rejoindre la fédération.');
    expect(etat().map((d) => d.status)).toEqual(['sent']);
  });

  it('par le vrai chemin : team.ts délègue au module, qui marque la file une seule fois', async () => {
    const { ef, etat } = monter();
    const r = await ef.charger('_shared/domain/team.ts').handleTeamEvent(31);
    expect(r).toMatchObject({ ok: true, recipients_count: 2 });
    expect(etat()).toHaveLength(1);
  });

  it('sans library_id : « failed », et l\'erreur remonte', async () => {
    const ef = monterEF({ repondre: (_s, table, a) => (table === 'team_notification_outbox' && !a('update') ? { data: { id: 31, status: 'queued', event: 'team.library_profile.proposed', payload: {} }, error: null } : { data: null, error: null }) });
    await expect(ef.charger('_shared/domain/library_profile.ts').handleLibraryProfileEvent(31)).rejects.toThrow(/without library_id/);
    expect(ef.ecrits.map((e) => e.donnees.status)).toEqual(['failed']);
  });

  // Les trois cas qui suivent étaient épinglés « DÉFAUT CONNU » (file à « sent ») sur
  // le code intact ; ROUGES puis verts avec outbox-verdict.ts et markOutboxSkipped.
  it('personne à prévenir (la seule staff est celle qui propose) : « skipped », no_recipients, sans sent_at', async () => {
    const { ef, etat } = monter({ staff: ['u-1'] });
    const r = await ef.charger('_shared/domain/library_profile.ts').handleLibraryProfileEvent(31);
    expect(r).toMatchObject({ ok: true, outbox_status: 'skipped' });
    expect(ef.envois).toHaveLength(0);
    expect(etat()).toEqual([{ status: 'skipped', skip_reason: 'no_recipients' }]);
  });

  it('sous-événement inconnu : « skipped », nommé', async () => {
    const { ef, etat } = monter({ event: 'team.library_profile.autre' });
    expect(await ef.charger('_shared/domain/library_profile.ts').handleLibraryProfileEvent(31)).toMatchObject({ ignored: true, reason: 'unknown_library_profile_sub_event' });
    expect(etat()).toEqual([{ status: 'skipped', skip_reason: 'unknown_library_profile_sub_event' }]);
  });

  it('transport en panne : « failed », et last_error nomme les deux refusés', async () => {
    const { ef, etat } = monter({ resend: () => new Response('panne', { status: 500 }) });
    const r = await ef.charger('_shared/domain/library_profile.ts').handleLibraryProfileEvent(31);
    expect(r).toMatchObject({ ok: false, outbox_status: 'failed' });
    expect(ef.envois).toHaveLength(0);
    const [d] = etat();
    expect(d.status).toBe('failed');
    expect(d.last_error).toMatch(/^0 parti\(s\), 2 refuse\(s\)/);
    expect(d.last_error).toContain('dois@exemplo.test');
    expect(d.sent_at).toBeUndefined();
  });

  it('le bouton suit APP_BASE_URL (barre finale tolérée) — plus aucun lien vers le canonique', async () => {
    const { ef } = monter({ env: { APP_BASE_URL: 'https://app.anarbib.is/' } });
    await ef.charger('_shared/domain/library_profile.ts').handleLibraryProfileEvent(31);
    for (const m of ef.envois) {
      expect(liens(m.html)).toContain('https://app.anarbib.is/painel/biblioteca/lib-1/profil?proposal=p-1');
      expect(liens(m.html).filter((h) => h.startsWith('https://app.anarbib.org'))).toEqual([]);
    }
  });
});
