// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/request-password-reset-banc.test.js
//
// BANC DE LA RÉINITIALISATION DU MOT DE PASSE (21/09/2026) — fonction publique,
// sans jeton, qui écrit à n'importe quelle adresse connue : aucun test ne
// l'exécutait. Écrit avant de toucher à son adresse (dette app-url), sur la vraie
// fonction, par src/tests/helpers/monter-ef.js.
//
// Particularité : les compteurs sont ceux de helpers/compteur-memoire.js, qui
// rejoue public.fn_compteur_frapper ET les deux contraintes de
// public.auth_rate_limits — `kind` dans une liste fermée, `key` = empreinte de
// 64 caractères hexadécimaux. Sans cela le banc ne pouvait pas voir ce qu'il a
// trouvé : la fonction écrivait des clés EN CLAIR (« pwreset:adresse »), que la
// base refusait depuis le 16/09 sans que personne ne lise l'erreur. Les demandes
// de réinitialisation n'étaient donc PLUS LIMITÉES du tout (la refonte B25/B26
// avait repris quatre fonctions ; celle-ci était la cinquième). Voir le second
// describe. (19/10/2026 : le compte se fait d'un seul geste, par RPC ; l'IP est
// celle de cf-connecting-ip, par _shared/core/ip-client.ts.)

import { describe, it, expect } from 'vitest';
import { monterEF, liens } from './helpers/monter-ef.js';
import { compteurEnMemoire } from './helpers/compteur-memoire.js';

const LIEN = 'http://stub/auth/v1/verify?token=abc&type=recovery';

function monter({ env = {}, profils = [{ preferred_language: 'de' }], lien = { data: { properties: { action_link: LIEN } }, error: null }, tablePanne = false, resend } = {}) {
  const compteur = compteurEnMemoire({ panne: tablePanne ? { message: 'table injoignable' } : null });
  const liensDemandes = [];
  const ef = monterEF({
    entree: 'request-password-reset/index.ts', env, resend,
    auth: { admin: { generateLink: async (o) => { liensDemandes.push(o); return lien; } } },
    rpc: (_s, nom, args) => compteur.rpc(nom, args),
    repondre: (_s, table) => (table === 'profiles' ? { data: profils, error: null } : { data: null, error: null }),
  });
  async function demander(email, { methode = 'POST', ip = '203.0.113.7' } = {}) {
    const avant = ef.envois.length;
    const r = await ef.appeler(new Request('http://ef.local/', {
      method: methode, headers: { 'content-type': 'application/json', 'cf-connecting-ip': ip },
      ...(methode === 'POST' ? { body: JSON.stringify({ email }) } : {}),
    }));
    return { ...r, nouveaux: ef.envois.slice(avant) };
  }
  return { ef, demander, compteurs: compteur.lignes, refus: compteur.refus, liensDemandes };
}

describe('request-password-reset — toujours 200, et un mail seulement à qui existe', () => {
  it('GET : 405 ; adresse vide ou sans @ : 200, rien ne se passe', async () => {
    const { demander, ef, liensDemandes } = monter();
    expect((await demander('x', { methode: 'GET' })).statut).toBe(405);
    for (const e of ['', 'pas-une-adresse']) {
      const r = await demander(e);
      expect(r.statut).toBe(200); expect(r.corps).toEqual({ ok: true });
    }
    expect(ef.envois).toHaveLength(0); expect(liensDemandes).toHaveLength(0); expect(ef.ecrits).toHaveLength(0);
  });

  it('adresse inconnue : 200, ni lien ni mail — on ne révèle rien', async () => {
    const { demander, liensDemandes } = monter({ profils: [] });
    const r = await demander('inconnue@exemplo.test');
    expect(r.corps).toEqual({ ok: true });
    expect(r.nouveaux).toHaveLength(0); expect(liensDemandes).toHaveLength(0);
  });

  it('adresse connue : lien de récupération qui ramène à /login de l\'application, mail dans la langue du profil', async () => {
    const { demander, liensDemandes } = monter();
    const r = await demander('  Louise@Exemplo.test ');
    expect(r.corps).toEqual({ ok: true });
    expect(liensDemandes).toEqual([{ type: 'recovery', email: 'louise@exemplo.test', options: { redirectTo: 'https://app.anarbib.org/login' } }]);
    expect(r.nouveaux).toHaveLength(1);
    const m = r.nouveaux[0];
    expect(m.to).toEqual(['louise@exemplo.test']);
    expect(m.subject).toBe('Passwort zurücksetzen');
    expect(liens(m.html)).toEqual([LIEN]);
    expect(m.text).toContain(LIEN);
  });

  it('le lien ne peut pas être fabriqué, ou le transport refuse : 200 quand même, et rien de plus', async () => {
    const a = monter({ lien: { data: null, error: { message: 'panne auth' } } });
    const ra = await a.demander('louise@exemplo.test');
    expect(ra.corps).toEqual({ ok: true }); expect(ra.nouveaux).toHaveLength(0);
    const b = monter({ resend: () => new Response('panne', { status: 500 }) });
    expect((await b.demander('louise@exemplo.test')).corps).toEqual({ ok: true });
  });
});

// ── Le frein compte, ou rien ne part (21/09/2026) ──────────────────────────────
// ROUGES sur le code du matin. La fonction gardait son propre compteur, à clés en
// clair (« pwreset:adresse »), que la contrainte auth_rate_limits_key_empreinte
// refuse depuis le 16/09 : aucune écriture ne passait, personne ne lisait
// l'erreur, et six demandes de suite envoyaient six courriels. Elle passe
// désormais par _shared/core/rate-limit.ts (empreintes, échec fermé).
describe('request-password-reset — l\'adresse de retour suit APP_BASE_URL', () => {
  // ROUGE sur le code du matin : la fonction lisait bien APP_BASE_URL, mais sans
  // retirer la barre finale — le retour se faisait sur « …//login ». Le foyer
  // unique (_shared/core/app-url.ts) normalise.
  it('barre finale tolérée : le retour se fait sur <adresse>/login', async () => {
    const { demander, liensDemandes } = monter({ env: { APP_BASE_URL: 'https://app.anarbib.is/' } });
    await demander('louise@exemplo.test');
    expect(liensDemandes[0].options.redirectTo).toBe('https://app.anarbib.is/login');
  });
});

describe('request-password-reset — le frein', () => {
  it('quatre demandes par quart d\'heure et par adresse, pas une de plus — et toujours 200', async () => {
    const { demander, ef } = monter();
    for (let i = 0; i < 6; i += 1) expect((await demander('louise@exemplo.test')).corps).toEqual({ ok: true });
    expect(ef.envois).toHaveLength(4);
  });

  it('la limite vaut aussi par adresse IP, d\'une adresse à l\'autre', async () => {
    const { demander, ef } = monter();
    for (let i = 0; i < 6; i += 1) await demander(`personne${i}@exemplo.test`, { ip: '198.51.100.9' });
    expect(ef.envois).toHaveLength(4);
  });

  it('la base ne voit que des empreintes : ni courriel ni IP en clair, et aucune écriture refusée', async () => {
    const { demander, compteurs, refus, ef } = monter();
    await demander('louise@exemplo.test');
    expect(refus).toEqual([]);
    expect([...compteurs.keys()].sort().map((k) => k.split('|')[0])).toEqual(['email', 'ip']);
    for (const k of compteurs.keys()) expect(k.split('|')[1]).toMatch(/^[0-9a-f]{64}$/);
    expect(JSON.stringify([ef.ecrits, ef.rpcs])).not.toMatch(/louise@|203\.0\.113\.7/);
  });

  it('compteur injoignable : échec FERMÉ — aucun mail, et toujours 200', async () => {
    const { demander, liensDemandes } = monter({ tablePanne: true });
    const r = await demander('louise@exemplo.test');
    expect(r.corps).toEqual({ ok: true });
    expect(r.nouveaux).toHaveLength(0); expect(liensDemandes).toHaveLength(0);
  });
});
