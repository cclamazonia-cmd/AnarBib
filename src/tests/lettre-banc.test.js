// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/lettre-banc.test.js
//
// BANC DE LA LETTRE DE LA FÉDÉRATION (21/09/2026) — trois pièces, aucune n'avait
// de test qui l'exécute :
//   - _shared/domain/lettre.ts : les deux mails (confirmation du double opt-in,
//     envoi d'un numéro), appelés par notify-event via le dispatch ;
//   - lettre-confirm et lettre-unsubscribe : les deux pages publiques d'un clic.
// Écrit AVANT de toucher à leurs adresses (dette app-url-dette.test.js), sur les
// vrais fichiers, par l'aide commune src/tests/helpers/monter-ef.js. Le rendu
// Markdown (`marked`, esm.sh) est remplacé par l'aide : ce n'est pas lui qu'on
// teste, et c'est dit.
//
// DÉFAUT CONNU, épinglé et non corrigé ici (autre item) : quand le transport
// refuse l'envoi, safeSendEmail rend { ok:false } sans lever, et la ligne de la
// file passe quand même à « sent ». Un envoi manqué est tenu pour fait — la
// forme exacte que notify-loan-cycle évite (DOC-SILENCE-1). Voir le dernier cas.

import { describe, it, expect } from 'vitest';
import { monterEF, liens } from './helpers/monter-ef.js';

const FONCTIONS_V1 = 'http://stub/functions/v1';

function monterLettre({ env = {}, outbox, corpsParLocale = {}, resend } = {}) {
  const ef = monterEF({
    env, resend,
    repondre: (_s, table, a, chaine) => {
      if (table === 'lettre_notification_outbox') return a('update') ? { data: null, error: null } : { data: outbox, error: null };
      if (table === 'lettre_issue_locales') {
        const loc = chaine.find((c) => c.op === 'eq' && c.args[0] === 'locale')?.args?.[1];
        return { data: corpsParLocale[loc] || null, error: null };
      }
      return { data: null, error: null };
    },
  });
  const { handleLettreEvent } = ef.charger('_shared/domain/lettre.ts');
  const tMail = ef.charger('_shared/i18n/mail-strings.ts').tMail;
  const etatFile = () => ef.ecrits.filter((e) => e.table === 'lettre_notification_outbox').map((e) => e.donnees);
  return { ef, handleLettreEvent, tMail, etatFile };
}

const NUMERO = {
  id: 7, status: 'pending', event: 'lettre.issue.sent',
  payload: {
    to: 'louise@exemplo.test', to_name: 'Louise', locale: 'fr', number: 4, intro: 'Un mot de la coordination.',
    unsub_token: 'jeton+stable', issue_id: '',
    items: [{ kind: 'circle', name: 'Cercle de lecture' }, { kind: 'assembly', title: 'Assemblée d\'automne', scheduled_at: '2026-10-10T18:00:00Z' }, { kind: 'gazette', number: 4 }],
  },
};

describe('domain/lettre — un numéro de la Lettre', () => {
  it('digest structuré : cercles, assemblées, lien vers la gazette, désabonnement d\'un clic ; la file passe à « sent »', async () => {
    const { ef, handleLettreEvent, tMail, etatFile } = monterLettre({ outbox: NUMERO });
    const r = await handleLettreEvent(7);
    expect(r).toMatchObject({ ok: true, event: 'lettre.issue.sent', recipients_count: 1 });
    expect(ef.envois).toHaveLength(1);
    const m = ef.envois[0];
    expect(m.to).toEqual(['louise@exemplo.test']);
    expect(m.subject).toBe(tMail('fr', 'lettre.issue.subject', { number: '4' }));
    expect(m.html).toContain('Cercle de lecture');
    expect(m.html).toContain('Un mot de la coordination.');
    expect(liens(m.html)).toEqual(expect.arrayContaining([
      'https://app.anarbib.org/federacao/gazeta',
      `${FONCTIONS_V1}/lettre-unsubscribe?token=${encodeURIComponent('jeton+stable')}`,
    ]));
    expect(etatFile().map((d) => d.status)).toEqual(['sent']);
  });

  it('sans jeton de désabonnement, le repli mène au compte', async () => {
    const { ef, handleLettreEvent } = monterLettre({ outbox: { ...NUMERO, payload: { ...NUMERO.payload, unsub_token: '' } } });
    await handleLettreEvent(7);
    expect(liens(ef.envois[0].html)).toContain('https://app.anarbib.org/conta');
    expect(liens(ef.envois[0].html).some((h) => h.includes('lettre-unsubscribe'))).toBe(false);
  });

  it('Lettre v2 : le corps rédigé de la locale l\'emporte sur le digest, avec repli sur le français', async () => {
    const corps = { fr: { title: 'La Lettre n° 4', body_md: 'Corps rédigé en français.' } };
    const { ef, handleLettreEvent } = monterLettre({ outbox: { ...NUMERO, payload: { ...NUMERO.payload, locale: 'el', issue_id: 'issue-4' } }, corpsParLocale: corps });
    await handleLettreEvent(7);
    expect(ef.envois[0].subject).toBe('La Lettre n° 4');
    expect(ef.envois[0].html).toContain('Corps rédigé en français.');
    expect(ef.envois[0].html).not.toContain('Cercle de lecture');
  });

  it('sans adresse : rien ne part, et la file dit pourquoi (« skipped », no_recipients)', async () => {
    const { ef, handleLettreEvent, etatFile } = monterLettre({ outbox: { ...NUMERO, payload: { ...NUMERO.payload, to: '' } } });
    await handleLettreEvent(7);
    expect(ef.envois).toHaveLength(0);
    expect(etatFile()).toEqual([{ status: 'skipped', skip_reason: 'no_recipients' }]);
  });

  it('événement inconnu : sauté, nommé, sans mail', async () => {
    const { ef, handleLettreEvent, etatFile } = monterLettre({ outbox: { ...NUMERO, event: 'lettre.autre' } });
    const r = await handleLettreEvent(7);
    expect(r).toMatchObject({ ignored: true, reason: 'unknown_lettre_event' });
    expect(ef.envois).toHaveLength(0);
    expect(etatFile()).toEqual([{ status: 'skipped', skip_reason: 'unknown_lettre_event' }]);
  });

  it('DÉFAUT CONNU : un envoi refusé par le transport laisse quand même la file à « sent »', async () => {
    const { ef, handleLettreEvent, etatFile } = monterLettre({ outbox: NUMERO, resend: () => new Response('panne', { status: 500 }) });
    const r = await handleLettreEvent(7);
    expect(ef.envois).toHaveLength(0);
    expect(r.result).toMatchObject({ ok: false });
    // Ce qu'on VOUDRAIT : 'failed'. Ce qui est : 'sent'. À corriger à part, en retournant ce test.
    expect(etatFile().map((d) => d.status)).toEqual(['sent']);
  });
});

describe('domain/lettre — confirmation du double opt-in', () => {
  const OPTIN = { id: 8, status: 'pending', event: 'lettre.optin.confirm', payload: { to: 'louise@exemplo.test', to_name: 'Louise', locale: 'it', token: 'jeton/opt in' } };

  it('le bouton mène à la fonction publique lettre-confirm, jeton encodé, dans la langue de la personne', async () => {
    const { ef, handleLettreEvent, tMail } = monterLettre({ outbox: OPTIN });
    await handleLettreEvent(8);
    expect(ef.envois[0].subject).toBe(tMail('it', 'lettre.optin.confirm.sub'));
    expect(liens(ef.envois[0].html)).toContain(`${FONCTIONS_V1}/lettre-confirm?token=${encodeURIComponent('jeton/opt in')}`);
  });

  it('sans jeton : rien ne part', async () => {
    const { ef, handleLettreEvent, etatFile } = monterLettre({ outbox: { ...OPTIN, payload: { ...OPTIN.payload, token: '' } } });
    await handleLettreEvent(8);
    expect(ef.envois).toHaveLength(0);
    expect(etatFile()).toEqual([{ status: 'skipped', skip_reason: 'no_recipients' }]);
  });
});

function monterPage(entree, { env = {}, statutRpc = 'confirmed', erreurRpc = null } = {}) {
  const ef = monterEF({
    entree, env,
    rpc: () => (erreurRpc ? { data: null, error: erreurRpc } : { data: statutRpc, error: null }),
    repondre: (_s, table) => {
      if (table === 'lettre_consent_tokens') return { data: { user_id: 'u-1' }, error: null };
      if (table === 'profiles') return { data: { preferred_language: 'it' }, error: null };
      return { data: null, error: null };
    },
  });
  const tMail = ef.charger('_shared/i18n/mail-strings.ts').tMail;
  const ouvrir = (requete = '?token=abc') => ef.appeler(new Request(`http://ef.local/${requete}`));
  return { ef, tMail, ouvrir };
}

describe('lettre-confirm et lettre-unsubscribe — les deux pages d\'un clic', () => {
  it('confirm : chaque statut de la RPC a sa page, dans la langue de la personne, avec le bouton vers l\'application', async () => {
    for (const [statutRpc, cle, http] of [['confirmed', 'lettre.landing.confirmed', 200], ['already', 'lettre.landing.already', 200], ['expired', 'lettre.landing.expired', 410], ['nimporte', 'lettre.landing.invalid', 400]]) {
      const { ef, tMail, ouvrir } = monterPage('lettre-confirm/index.ts', { statutRpc });
      const r = await ouvrir();
      expect(r.statut, statutRpc).toBe(http);
      expect(r.texte).toContain(`<h1>${tMail('it', cle)}</h1>`);
      expect(r.texte).toContain('<html lang="it">');
      expect(liens(r.texte)).toEqual(['https://app.anarbib.org']);
      expect(ef.rpcs[0]).toMatchObject({ schema: 'api', nom: 'fn_lettre_confirm', args: { p_token: 'abc' } });
    }
  });

  it('confirm : sans jeton 400 sans appeler la RPC ; RPC en erreur 500', async () => {
    const a = monterPage('lettre-confirm/index.ts');
    expect((await a.ouvrir('')).statut).toBe(400);
    expect(a.ef.rpcs).toHaveLength(0);
    const b = monterPage('lettre-confirm/index.ts', { erreurRpc: { message: 'panne' } });
    expect((await b.ouvrir()).statut).toBe(500);
  });

  it('unsubscribe : désabonné 200, tout autre statut 400, et le même bouton', async () => {
    const ok = monterPage('lettre-unsubscribe/index.ts', { statutRpc: 'unsubscribed' });
    const r = await ok.ouvrir();
    expect(r.statut).toBe(200);
    expect(r.texte).toContain(`<h1>${ok.tMail('it', 'lettre.landing.unsubscribed')}</h1>`);
    expect(liens(r.texte)).toEqual(['https://app.anarbib.org']);
    expect(ok.ef.rpcs[0]).toMatchObject({ schema: 'api', nom: 'fn_lettre_unsubscribe' });
    const ko = monterPage('lettre-unsubscribe/index.ts', { statutRpc: 'inconnu' });
    expect((await ko.ouvrir()).statut).toBe(400);
  });
});
