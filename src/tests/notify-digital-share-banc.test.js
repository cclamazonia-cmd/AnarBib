// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/notify-digital-share-banc.test.js
//
// BANC DU PARTAGE NUMÉRIQUE ENTRE BIBLIOTHÈQUES (21/09/2026) — notify-digital-share
// écrit aux équipes des deux bibliothèques à chaque étape d'un partage. Aucun test
// ne l'exécutait. Écrit avant de toucher à son adresse (dette app-url), sur la
// vraie fonction, par src/tests/helpers/monter-ef.js.
//
// Le 21/09, le dernier cas épinglait un défaut : `sent_count` comptait un envoi
// même quand le transport l'avait refusé (safeSendEmail ne lève jamais, et la
// fonction ne lisait pas son résultat — la même forme que le défaut de la Lettre).
// Corrigé le 24/09 (F13) : la fonction lit le verdict de chaque envoi ; `sent_count`
// ne compte que les partis, les refusés sont rendus nommés, les sautés comptés.

import { describe, it, expect } from 'vitest';
import { monterEF, liens } from './helpers/monter-ef.js';

const SECRET = 'secret-du-partage';
const PARTAGE = { id: 'share-1', requester_library_id: 'lib-dem', source_library_id: 'lib-src', book_id: 7, refusal_reason: 'fonds fragile' };
const BIBLIOS = { 'lib-dem': { name: 'Biblioteca Demandeuse', default_locale: 'fr' }, 'lib-src': { name: 'Biblioteca Source', default_locale: 'it' } };
const EQUIPES = { 'lib-dem': ['u-d1'], 'lib-src': ['u-s1', 'u-s2'] };
const PROFILS = { 'u-d1': { email: 'dem@exemplo.test', first_name: 'Dem' }, 'u-s1': { email: 'src1@exemplo.test', first_name: 'Uno' }, 'u-s2': { email: 'src2@exemplo.test', first_name: 'Due' } };

function monter({ env = {}, resend } = {}) {
  const eq = (chaine, nom) => chaine.find((c) => c.op === 'eq' && c.args[0] === nom)?.args?.[1];
  const ef = monterEF({
    entree: 'notify-digital-share/index.ts', resend,
    env: { WEBHOOK_SECRET_NOTIFY_DIGITAL_SHARE: SECRET, ...env },
    repondre: (_s, table, a, chaine) => {
      if (table === 'ill_digital_shares') return { data: eq(chaine, 'id') === 'share-1' ? PARTAGE : null, error: null };
      if (table === 'libraries') return { data: BIBLIOS[eq(chaine, 'id')] || null, error: null };
      if (table === 'books') return { data: { titulo: 'La Conquête du pain' }, error: null };
      if (table === 'user_library_memberships') return { data: (EQUIPES[eq(chaine, 'library_id')] || []).map((user_id) => ({ user_id })), error: null };
      if (table === 'profiles') return { data: (a('in')?.args?.[1] || []).map((id) => PROFILS[id]), error: null };
      return { data: null, error: null };
    },
  });
  const tMail = ef.charger('_shared/i18n/mail-strings.ts').tMail;
  async function notifier(corps, secret = SECRET) {
    ef.vider();
    const r = await ef.appeler(new Request('http://ef.local/', {
      method: 'POST', headers: { 'content-type': 'application/json', ...(secret ? { 'x-webhook-secret': secret } : {}) }, body: JSON.stringify(corps),
    }));
    return { ...r, envois: [...ef.envois] };
  }
  return { notifier, tMail };
}

describe('notify-digital-share — qui est prévenu à chaque étape', () => {
  it('sans le secret : 401 ; charge utile incomplète ou partage introuvable : rien ne part', async () => {
    const { notifier } = monter();
    expect((await notifier({ event: 'ill_requested', share_id: 'share-1' }, null)).statut).toBe(401);
    expect((await notifier({ event: 'ill_requested' })).corps).toMatchObject({ ok: false, error: 'bad_payload' });
    const r = await notifier({ event: 'ill_requested', share_id: 'autre' });
    expect(r.corps).toMatchObject({ ok: false, error: 'share_not_found' });
    expect(r.envois).toHaveLength(0);
  });

  it('demande : toute l\'équipe de la bibliothèque SOURCE, dans sa langue, avec le lien du comptoir', async () => {
    const { notifier, tMail } = monter();
    const r = await notifier({ event: 'ill_requested', share_id: 'share-1' });
    expect(r.corps).toMatchObject({ ok: true, sent_count: 2 });
    expect(r.envois.map((e) => e.to[0]).sort()).toEqual(['src1@exemplo.test', 'src2@exemplo.test']);
    expect(r.envois[0].subject).toBe(tMail('it', 'ill.requested.sub', { requester: 'Biblioteca Demandeuse', book: 'La Conquête du pain' }));
    expect(liens(r.envois[0].html)).toContain('https://app.anarbib.org/painel');
  });

  it('acceptation, refus, indisponibilité, transmission : la bibliothèque DEMANDEUSE ; clôture : les deux', async () => {
    const { notifier, tMail } = monter();
    for (const ev of ['ill_accepted', 'ill_refused', 'ill_unavailable', 'ill_transmitted']) {
      const r = await notifier({ event: ev, share_id: 'share-1' });
      expect(r.envois.map((e) => e.to[0]), ev).toEqual(['dem@exemplo.test']);
    }
    const refus = await notifier({ event: 'ill_refused', share_id: 'share-1' });
    expect(refus.envois[0].subject).toBe(tMail('fr', 'ill.refused.sub', { source: 'Biblioteca Source', book: 'La Conquête du pain', reason: 'fonds fragile' }));
    const fin = await notifier({ event: 'ill_closed', share_id: 'share-1' });
    expect(fin.envois.map((e) => e.to[0]).sort()).toEqual(['dem@exemplo.test', 'src1@exemplo.test', 'src2@exemplo.test']);
  });

  it('événement inconnu : ignoré, nommé, sans mail', async () => {
    const { notifier } = monter();
    const r = await notifier({ event: 'ill_autre', share_id: 'share-1' });
    expect(r.corps).toMatchObject({ ok: true, ignored: true, event: 'ill_autre' });
    expect(r.envois).toHaveLength(0);
  });

  it('APP_BASE_URL réglé : le lien du comptoir suit (barre finale tolérée)', async () => {
    const { notifier } = monter({ env: { APP_BASE_URL: 'https://app.anarbib.is/' } });
    const r = await notifier({ event: 'ill_accepted', share_id: 'share-1' });
    expect(liens(r.envois[0].html)).toContain('https://app.anarbib.is/painel');
  });

  it('un envoi refusé par le transport ne compte pas : sent_count 0, le refus est nommé (F13)', async () => {
    const { notifier } = monter({ resend: () => new Response('panne', { status: 500 }) });
    const r = await notifier({ event: 'ill_accepted', share_id: 'share-1' });
    expect(r.envois).toHaveLength(0);
    expect(r.corps.sent_count).toBe(0);
    expect(r.corps.refused_count).toBe(1);
    expect(r.corps.refused).toHaveLength(1);
    expect(r.corps.refused[0].email).toBe('dem@exemplo.test');
    expect(String(r.corps.refused[0].reason)).not.toBe('');
    expect(r.corps.skipped_count).toBe(0);
  });

  it('les envois partis sont comptés, et la réponse porte les trois comptes', async () => {
    const { notifier } = monter();
    const r = await notifier({ event: 'ill_requested', share_id: 'share-1' });
    expect(r.corps).toMatchObject({ ok: true, sent_count: 2, refused_count: 0, refused: [], skipped_count: 0 });
  });
});
