// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/mails-federation-banc.test.js
//
// BANC DE TROIS MAILS DE LA FÉDÉRATION (21/09/2026) — cartographie (une
// auto-déclaration à modérer), entraide (une demande dans un cercle), assemblées
// (convocation, ordre du jour, point proposé). Trois handlers de domaine appelés
// par notify-event, qu'aucun test n'exécutait. Écrit avant de toucher à leurs
// adresses (dette app-url), sur les vrais modules, par src/tests/helpers/monter-ef.js.
//
// DÉFAUT ÉPINGLÉ PUIS CORRIGÉ le 21/09 : cartographie et assemblées marquaient la
// ligne de file « sent » sans lire le résultat de l'envoi — même forme que la
// Lettre. Les deux adoptent _shared/domain/outbox-verdict.ts ; les cas « envoi
// refusé » ci-dessous étaient rouges sur le code du matin.

import { describe, it, expect } from 'vitest';
import { monterEF, liens, mailA } from './helpers/monter-ef.js';

const eq = (chaine, nom) => chaine.find((c) => c.op === 'eq' && c.args[0] === nom)?.args?.[1];

describe('domain/cartography — une auto-déclaration à modérer', () => {
  const LIGNE = { id: 3, status: 'queued', event: 'cartography.submission_received', payload: { name: 'Ateneu Llibertari', city: 'Barcelona', country: 'ES', categorie: 'ateneu', site_url: 'https://ateneu.exemple.test' } };
  function monter({ env = {}, ligne = LIGNE, resend } = {}) {
    const ef = monterEF({ env, resend, repondre: (_s, table, a) => (table === 'cartography_submission_notification_outbox' && !a('update') ? { data: ligne, error: null } : { data: null, error: null }) });
    return { ef, handle: ef.charger('_shared/domain/cartography.ts').handleCartographyEvent, etat: () => ef.ecrits.map((e) => e.donnees.status) };
  }

  it('la boîte éditoriale reçoit la fiche et le lien de modération ; la file passe à « sent »', async () => {
    const { ef, handle, etat } = monter();
    const r = await handle(3);
    expect(r).toMatchObject({ ok: true, recipients_count: 1 });
    const m = mailA(ef.envois, 'fede@anarbib.org');
    expect(m.html).toContain('Ateneu Llibertari');
    expect(liens(m.html)).toEqual(expect.arrayContaining(['https://ateneu.exemple.test', 'https://app.anarbib.org/cartografia/moderacao']));
    expect(etat()).toEqual(['sent']);
  });

  it('une adresse de site qui n\'est pas http(s) n\'est pas rendue en lien ; événement inconnu : sauté, nommé', async () => {
    const a = monter({ ligne: { ...LIGNE, payload: { ...LIGNE.payload, site_url: 'javascript:alert(1)' } } });
    await a.handle(3);
    expect(a.ef.envois[0].html).not.toContain('javascript:');
    const b = monter({ ligne: { ...LIGNE, event: 'cartography.autre' } });
    expect(await b.handle(3)).toMatchObject({ ignored: true, reason: 'unknown_cartography_event' });
    expect(b.ef.envois).toHaveLength(0);
  });

  it('envoi refusé par le transport : la file dit « failed », avec le destinataire et la cause, sans sent_at', async () => {
    const { ef, handle, etat } = monter({ resend: () => new Response('panne', { status: 500 }) });
    const r = await handle(3);
    expect(r).toMatchObject({ ok: false, outbox_status: 'failed' });
    expect(ef.envois).toHaveLength(0);
    expect(etat()).toEqual(['failed']);
    const d = ef.ecrits[0].donnees;
    expect(d.last_error).toContain('fede@anarbib.org');
    expect(d.last_error).toContain('500');
    expect(d.sent_at).toBeUndefined();
  });
});

describe('domain/entraide — une demande dans un cercle', () => {
  const PROFILS = [{ id: 'u-2', email: 'dois@exemplo.test', first_name: 'Dois', preferred_language: 'pt-BR' }, { id: 'u-3', email: 'trois@exemplo.test', first_name: 'Trois', preferred_language: 'fr' }];
  function monter({ env = {} } = {}) {
    const ef = monterEF({
      env,
      repondre: (_s, table, a, chaine) => {
        if (table === 'circles') return { data: { name: 'Cercle du Sud' }, error: null };
        if (table === 'circle_memberships') return { data: [{ library_id: 'lib-a' }, { library_id: 'lib-b' }, { library_id: 'lib-c' }], error: null };
        if (table === 'user_library_memberships') {
          if (eq(chaine, 'user_id')) return { data: [{ library_id: 'lib-a' }], error: null };             // la biblio de l'auteur·rice
          return { data: [{ user_id: 'u-1' }, { user_id: 'u-2' }, { user_id: 'u-3' }], error: null };     // staff des AUTRES biblios (+ l'auteur·rice, à écarter)
        }
        if (table === 'profiles') return { data: PROFILS.filter((p) => (a('in')?.args?.[1] || []).includes(p.id)), error: null };
        return { data: null, error: null };
      },
    });
    const mod = ef.charger('_shared/domain/entraide.ts');
    return { ef, handle: mod.handleEntraideRequestCircle, tMail: ef.charger('_shared/i18n/mail-strings.ts').tMail };
  }

  it('le staff des AUTRES bibliothèques du cercle, chacun·e dans sa langue, jamais l\'auteur·rice ; lien vers l\'entraide', async () => {
    const { ef, handle, tMail } = monter();
    const r = await handle({ circle_id: 'c-1', subject: 'Reliure', author_user_id: 'u-1' });
    expect(r).toMatchObject({ ok: true, recipients_count: 2 });
    expect(ef.envois.map((e) => e.to[0]).sort()).toEqual(['dois@exemplo.test', 'trois@exemplo.test']);
    expect(mailA(ef.envois, 'trois@exemplo.test').subject).toBe(tMail('fr', 'entraide.request_circle.sub', { circle: 'Cercle du Sud' }));
    expect(liens(ef.envois[0].html)).toContain('https://app.anarbib.org/federacao/entreajuda');
    const cercleDemande = ef.ecrits;                     // ce handler n'écrit rien
    expect(cercleDemande).toHaveLength(0);
  });

  it('sans cercle : ignoré, nommé', async () => {
    const { ef, handle } = monter();
    expect(await handle({ subject: 'x' })).toMatchObject({ ignored: true, reason: 'no_circle_id' });
    expect(ef.envois).toHaveLength(0);
  });
});

describe('domain/assembleia — convocation, ordre du jour, point proposé', () => {
  const COORDS = [{ id: 'u-7', email: 'sete@exemplo.test', first_name: 'Sete', last_name: 'A', preferred_language: 'pt-BR' }, { id: 'u-8', email: 'huit@exemplo.test', first_name: 'Huit', last_name: 'B', preferred_language: 'fr' }];
  function monter({ env = {}, resend, event = 'network.assembleia.convocada', payload = { title: 'Assemblée d\'automne', agenda_deadline_at: '2026-10-01T00:00:00Z' } } = {}) {
    const ef = monterEF({
      env,
      resend,
      repondre: (_s, table, a) => {
        if (table === 'team_notification_outbox') return a('update') ? { data: null, error: null } : { data: { id: 11, status: 'queued', event, payload }, error: null };
        if (table === 'libraries') return { data: [{ id: 'lib-a' }, { id: 'lib-b' }], error: null };
        if (table === 'user_library_memberships') return { data: [{ user_id: 'u-7' }, { user_id: 'u-8' }], error: null };
        if (table === 'network_administrators') return { data: [{ user_id: 'u-7' }], error: null };
        if (table === 'assembleia_facilitators') return { data: [{ user_id: 'u-8' }], error: null };
        if (table === 'profiles') return { data: COORDS, error: null };
        return { data: null, error: null };
      },
    });
    return { ef, handle: ef.charger('_shared/domain/assembleia.ts').handleAssembleiaEvent, etat: () => ef.ecrits.filter((e) => e.table === 'team_notification_outbox').map((e) => e.donnees.status) };
  }

  it('convocation : chaque coordination fédérée, dans sa langue, avec le bouton vers les assemblées', async () => {
    const { ef, handle, etat } = monter();
    const r = await handle(11);
    expect(r).toMatchObject({ ok: true, event: 'network.assembleia.convocada', recipients_count: 2 });
    expect(ef.envois.map((e) => e.to[0]).sort()).toEqual(['huit@exemplo.test', 'sete@exemplo.test']);
    for (const m of ef.envois) expect(liens(m.html)).toContain('https://app.anarbib.org/federacao/assembleias');
    expect(mailA(ef.envois, 'huit@exemplo.test').html).toContain('Assemblée d&#');   // le titre, échappé, dans le mail français
    expect(etat()).toEqual(['sent']);
  });

  it('point proposé : la facilitation (admins réseau + facilitateur·rices désigné·es) ; événement inconnu : sauté', async () => {
    const a = monter({ event: 'network.assembleia.item_proposed', payload: { assembleia_id: 'ag-1', assembly_title: 'AG', item_title: 'Tarifs', proposing_library_name: 'BLMF' } });
    expect(await a.handle(11)).toMatchObject({ recipients_count: 2 });
    const b = monter({ event: 'network.assembleia.autre' });
    expect(await b.handle(11)).toMatchObject({ ignored: true, reason: 'unknown_assembleia_event' });
    expect(b.etat()).toEqual(['skipped']);
  });

  it('convocation, une coordination sur deux refusée par le transport : « failed », et le détail dit qui relancer', async () => {
    const { ef, handle } = monter({ resend: (p) => (p.to[0] === 'huit@exemplo.test' ? new Response('panne', { status: 500 }) : new Response('{}', { status: 200 })) });
    const r = await handle(11);
    expect(r).toMatchObject({ ok: false, outbox_status: 'failed', recipients_count: 2 });
    expect(ef.envois.map((e) => e.to[0])).toEqual(['sete@exemplo.test']);
    const [d] = ef.ecrits.filter((e) => e.table === 'team_notification_outbox').map((e) => e.donnees);
    expect(d.status).toBe('failed');
    expect(d.last_error).toMatch(/^1 parti\(s\), 1 refuse\(s\)/);
    expect(d.last_error).toContain('huit@exemplo.test');
    expect(d.sent_at).toBeUndefined();
  });
});

// ── Les liens suivent APP_BASE_URL (21/09/2026) ────────────────────────────────
// ROUGES sur le code du matin (adresse écrite en dur dans les trois modules), verts
// depuis qu'ils passent par _shared/core/app-url.ts.
describe('mails de la fédération — les liens vers l\'application suivent APP_BASE_URL', () => {
  const ENV = { APP_BASE_URL: 'https://app.anarbib.is/' };
  const sansCanonique = (envois) => envois.flatMap((e) => liens(e.html)).filter((h) => h.startsWith('https://app.anarbib.org'));

  it('cartographie : le lien de modération', async () => {
    const ligne = { id: 3, status: 'queued', event: 'cartography.submission_received', payload: { name: 'Ateneu' } };
    const ef = monterEF({ env: ENV, repondre: (_s, table, a) => (table === 'cartography_submission_notification_outbox' && !a('update') ? { data: ligne, error: null } : { data: null, error: null }) });
    await ef.charger('_shared/domain/cartography.ts').handleCartographyEvent(3);
    expect(liens(ef.envois[0].html)).toContain('https://app.anarbib.is/cartografia/moderacao');
    expect(sansCanonique(ef.envois)).toEqual([]);
  });

  it('entraide : le lien vers la page d\'entraide', async () => {
    const ef = monterEF({
      env: ENV,
      repondre: (_s, table, a, chaine) => {
        if (table === 'circles') return { data: { name: 'Cercle' }, error: null };
        if (table === 'circle_memberships') return { data: [{ library_id: 'lib-a' }, { library_id: 'lib-b' }], error: null };
        if (table === 'user_library_memberships') return eq(chaine, 'user_id') ? { data: [{ library_id: 'lib-a' }], error: null } : { data: [{ user_id: 'u-2' }], error: null };
        if (table === 'profiles') return { data: [{ id: 'u-2', email: 'dois@exemplo.test', first_name: 'Dois', preferred_language: 'fr' }], error: null };
        return { data: null, error: null };
      },
    });
    await ef.charger('_shared/domain/entraide.ts').handleEntraideRequestCircle({ circle_id: 'c-1', subject: 'x', author_user_id: 'u-1' });
    expect(liens(ef.envois[0].html)).toContain('https://app.anarbib.is/federacao/entreajuda');
    expect(sansCanonique(ef.envois)).toEqual([]);
  });

  it('assemblées : le bouton de la convocation', async () => {
    const ef = monterEF({
      env: ENV,
      repondre: (_s, table, a) => {
        if (table === 'team_notification_outbox') return a('update') ? { data: null, error: null } : { data: { id: 11, status: 'queued', event: 'network.assembleia.agenda_published', payload: { title: 'AG' } }, error: null };
        if (table === 'libraries') return { data: [{ id: 'lib-a' }], error: null };
        if (table === 'user_library_memberships') return { data: [{ user_id: 'u-7' }], error: null };
        if (table === 'profiles') return { data: [{ id: 'u-7', email: 'sete@exemplo.test', first_name: 'Sete', last_name: 'A', preferred_language: 'pt-BR' }], error: null };
        return { data: null, error: null };
      },
    });
    await ef.charger('_shared/domain/assembleia.ts').handleAssembleiaEvent(11);
    expect(liens(ef.envois[0].html)).toContain('https://app.anarbib.is/federacao/assembleias');
    expect(sansCanonique(ef.envois)).toEqual([]);
  });
});
