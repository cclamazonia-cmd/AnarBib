// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/admins-reseau-destinataires.test.js
//
// F15 (24/09/2026) — À QUI on écrit quand on écrit « aux admins du réseau ».
//
// Le 24/09 au soir, « Mise à jour d'une demande institutionnelle » n'est arrivé
// que sur la boîte personnelle de l'unique administrateur actif : neuf endroits
// rechargeaient `network_administrators` chacun à leur façon, et la boîte
// collective (déjà destinataire des alertes de supervision et des rapports
// DMARC) ne voyait rien passer. La résolution vit désormais dans
// `_shared/context/network-admins.ts` : admins actif·ves dans leur langue + la
// boîte collective en pt-BR (langue de référence d'AnarBib), dédoublonnés.
//
// Ce banc tient trois choses :
//   1. le module lui-même, cas par cas (table vide, variable vide, casse,
//      séparateurs, repli NETWORK_ADMIN_CC → HEALTH_ALERT_CC, extras) ;
//   2. deux LISTES FERMÉES : les fonctions INSTITUTIONNELLES passent par le
//      module, et seuls les modules de GOUVERNANCE lisent encore la table en
//      direct (cooptation, retrait collectif, assemblée, gazette, atelier,
//      profil de bibliothèque — adressés à des personnes, jamais à la boîte).
//      Une fonction neuve qui recopie l'ancienne recette rougit ici ;
//   3. le rendu réel de trois fonctions converties, sur les vrais modules
//      (helpers/monter-ef.js) : la boîte reçoit, en pt-BR, et les personnes
//      gardent leur langue.

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { monterEF, FONCTIONS, mailA } from './helpers/monter-ef.js';

const lire = (rel) => readFileSync(join(FONCTIONS, rel), 'utf8');

// ── 1. Le module ────────────────────────────────────────────────────────────
const ADMINS = [
  { id: 'u-1', email: 'Xavier@Exemplo.test', first_name: 'Xavier', preferred_language: 'fr' },
  { id: 'u-2', email: 'dois@exemplo.test', first_name: 'Dois', preferred_language: 'de-CH' },
  { id: 'u-3', email: 'pas-une-adresse', first_name: 'Trois', preferred_language: 'el' },
];

function monterModule({ env = {}, admins = ADMINS, tableVide = false, erreurTable = false } = {}) {
  const ef = monterEF({
    env,
    repondre: (_s, table, a) => {
      if (table === 'network_administrators') {
        if (erreurTable) return { data: null, error: { message: 'panne' } };
        return { data: tableVide ? [] : admins.map((p) => ({ user_id: p.id })), error: null };
      }
      if (table === 'profiles') {
        const ids = a('in')?.args?.[1] || [];
        return { data: admins.filter((p) => ids.includes(p.id)), error: null };
      }
      return { data: null, error: null };
    },
  });
  // Le faux client du banc, tel que les fonctions le reçoivent (env.ts le crée
  // depuis deps.ts, substitué par monter-ef).
  const client = ef.charger('_shared/core/env.ts').supabaseAdmin;
  return { mod: ef.charger('_shared/context/network-admins.ts'), client };
}

describe('network-admins — la résolution des destinataires', () => {
  it('admins actif·ves dans leur langue, adresse invalide écartée, casse normalisée', async () => {
    const { mod, client } = monterModule();
    const r = await mod.destinatairesAdminsReseau(client);
    expect(r.map((d) => [d.email, d.locale, d.source])).toEqual([
      ['xavier@exemplo.test', 'fr', 'admin'],
      ['dois@exemplo.test', 'de', 'admin'],
    ]);
    expect(r[0].name).toBe('Xavier');
  });

  it('la boîte collective vient de NETWORK_ADMIN_CC, en pt-BR, après les personnes', async () => {
    const { mod, client } = monterModule({ env: { NETWORK_ADMIN_CC: 'admins@exemplo.test' } });
    const r = await mod.destinatairesAdminsReseau(client);
    expect(r.map((d) => d.email)).toEqual(['xavier@exemplo.test', 'dois@exemplo.test', 'admins@exemplo.test']);
    expect(r[2]).toMatchObject({ locale: 'pt-BR', source: 'boite' });
  });

  it('NETWORK_ADMIN_CC absente : repli sur HEALTH_ALERT_CC ; présente : elle l\'emporte', async () => {
    const a = monterModule({ env: { HEALTH_ALERT_CC: 'alertes@exemplo.test' } });
    expect((await a.mod.destinatairesAdminsReseau(a.client)).map((d) => d.email)).toContain('alertes@exemplo.test');
    const b = monterModule({ env: { HEALTH_ALERT_CC: 'alertes@exemplo.test', NETWORK_ADMIN_CC: 'admins@exemplo.test' } });
    const emails = (await b.mod.destinatairesAdminsReseau(b.client)).map((d) => d.email);
    expect(emails).toContain('admins@exemplo.test');
    expect(emails).not.toContain('alertes@exemplo.test');
  });

  it('`cc` passé par l\'appelant remplace la variable (health-probe garde la sienne)', async () => {
    const { mod, client } = monterModule({ env: { NETWORK_ADMIN_CC: 'admins@exemplo.test' } });
    const r = await mod.destinatairesAdminsReseau(client, { cc: 'sante@exemplo.test' });
    expect(r.map((d) => d.email)).toEqual(['xavier@exemplo.test', 'dois@exemplo.test', 'sante@exemplo.test']);
    const vide = await mod.destinatairesAdminsReseau(client, { cc: '' });
    expect(vide.map((d) => d.email)).toEqual(['xavier@exemplo.test', 'dois@exemplo.test']);
  });

  it('écrit quand même si AUCUN admin n\'est actif, ou si la table ne répond pas : la boîte est le filet', async () => {
    const a = monterModule({ tableVide: true, env: { NETWORK_ADMIN_CC: 'admins@exemplo.test' } });
    expect((await a.mod.destinatairesAdminsReseau(a.client)).map((d) => d.email)).toEqual(['admins@exemplo.test']);
    const b = monterModule({ erreurTable: true, env: { NETWORK_ADMIN_CC: 'admins@exemplo.test' } });
    expect((await b.mod.destinatairesAdminsReseau(b.client)).map((d) => d.email)).toEqual(['admins@exemplo.test']);
    const c = monterModule({ tableVide: true });
    expect(await c.mod.destinatairesAdminsReseau(c.client)).toEqual([]);
  });

  it('n\'envoie pas deux fois à la même adresse, quelle que soit la casse — et les extras passent en dernier, en pt-BR', async () => {
    const { mod, client } = monterModule({ env: { NETWORK_ADMIN_CC: 'XAVIER@exemplo.test, admins@exemplo.test' } });
    const r = await mod.destinatairesAdminsReseau(client, { extras: [{ email: 'Admins@Exemplo.test' }, { email: 'rapport@exemplo.test', name: 'Rapport' }] });
    expect(r.map((d) => d.email)).toEqual(['xavier@exemplo.test', 'dois@exemplo.test', 'admins@exemplo.test', 'rapport@exemplo.test']);
    expect(r[3]).toMatchObject({ source: 'extra', locale: 'pt-BR', name: 'Rapport' });
  });

  it.each([
    ['admins@exemplo.test', ['admins@exemplo.test']],
    [' admins@exemplo.test ', ['admins@exemplo.test']],
    ['a@exemplo.test,b@exemplo.test', ['a@exemplo.test', 'b@exemplo.test']],
    ['a@exemplo.test; b@exemplo.test', ['a@exemplo.test', 'b@exemplo.test']],
    ['a@exemplo.test b@exemplo.test', ['a@exemplo.test', 'b@exemplo.test']],
    ['pas-une-adresse, ni-celle-ci', []],
    ['', []],
    [null, []],
  ])('lit la variable sous la forme %j', (brut, attendu) => {
    const { mod } = monterModule();
    expect(mod.adressesSupplementaires(brut)).toEqual(attendu);
  });

  it('la langue d\'un profil est l\'une des dix, sinon pt-BR', () => {
    const { mod } = monterModule();
    const l = mod.localeDeProfil;
    expect([l('fr'), l('pt-BR'), l('pt'), l('pt_BR'), l('de-CH'), l('en-US'), l(''), l(null), l('xx')])
      .toEqual(['fr', 'pt-BR', 'pt-BR', 'pt-BR', 'de', 'en', 'pt-BR', 'pt-BR', 'pt-BR']);
    expect(mod.LOCALE_BOITE_COLLECTIVE).toBe('pt-BR');
  });
});

// ── 2. Les deux listes fermées ──────────────────────────────────────────────
function fichiersTs(dir, acc = []) {
  for (const n of readdirSync(dir)) {
    const p = join(dir, n);
    if (statSync(p).isDirectory()) fichiersTs(p, acc);
    else if (n.endsWith('.ts')) acc.push(p);
  }
  return acc;
}
const rel = (p) => p.slice(FONCTIONS.length + 1).replace(/\\/g, '/');

// GOUVERNANCE et ÉDITORIAL : adressés à des personnes, jamais à la boîte.
const LISENT_LA_TABLE_EN_DIRECT = [
  '_shared/context/network-admins.ts',      // le module lui-même
  '_shared/domain/assembleia.ts',           // facilitation d'assemblée
  '_shared/domain/authority.ts',            // coordination de l'atelier des autorités
  '_shared/domain/gazette.ts',              // comité éditorial
  '_shared/domain/library_profile.ts',      // profil de bibliothèque (staff + admins)
  '_shared/domain/network.ts',              // cooptation, retrait collectif, digest d'évaluation
  '_shared/domain/team.ts',                 // escalade « dernière coordination »
];

// INSTITUTIONNEL et SUPERVISION : passent par le module (admins + boîte).
const PASSENT_PAR_LE_MODULE = [
  '_shared/domain/membership-restriction.ts',
  'health-probe/index.ts',
  'notify-cross-library-digest/index.ts',
  'notify-document-permission-request/index.ts',
  'notify-library-request/index.ts',
  'notify-network-weekly-report/index.ts',
];

describe('network-admins — les deux listes fermées', () => {
  it('seuls les modules de gouvernance lisent encore network_administrators en direct', () => {
    const trouves = fichiersTs(FONCTIONS)
      .filter((p) => /from\(\s*['"]network_administrators['"]\s*\)/.test(readFileSync(p, 'utf8')))
      .map(rel)
      .sort();
    expect(trouves).toEqual([...LISENT_LA_TABLE_EN_DIRECT].sort());
  });

  it('chaque fonction institutionnelle importe le module, et aucune ne lit la table en direct', () => {
    for (const f of PASSENT_PAR_LE_MODULE) {
      const src = lire(f);
      expect(src, `${f} n'importe pas network-admins.ts`).toMatch(/context\/network-admins\.ts['"]/);
      expect(src, `${f} lit encore la table en direct`).not.toMatch(/from\(\s*['"]network_administrators['"]\s*\)/);
    }
  });

  it('la liste des lecteurs directs ne s\'allonge que par une entrée nommée ici', () => {
    expect(LISENT_LA_TABLE_EN_DIRECT).toHaveLength(7);
    expect(PASSENT_PAR_LE_MODULE).toHaveLength(6);
  });

  it('la boîte n\'est jamais écrite en dur : le module lit une variable, et health-probe garde la sienne', () => {
    const mod = lire('_shared/context/network-admins.ts');
    expect(mod).not.toMatch(/@anarbib\.org/);
    expect(mod).toContain('Deno.env.get(VARIABLE_BOITE_COLLECTIVE)');
    expect(lire('health-probe/index.ts')).toContain("cc: Deno.env.get('HEALTH_ALERT_CC')");
  });
});

// ── 3. Le rendu réel de trois fonctions converties ──────────────────────────
const SECRET = 'webhook-de-test';
const eq = (chaine, nom) => chaine.find((c) => c.op === 'eq' && c.args[0] === nom)?.args?.[1];
const dansIn = (a, id) => (a('in')?.args?.[1] || []).includes(id);

describe('notify-cross-library-digest — le récapitulatif consolidé atteint la boîte, en pt-BR', () => {
  const ACTION = { id: 1, created_at: '2026-09-21T10:00:00Z', action_type: 'update_library', is_critical: false, target_entity_type: 'library', library_id: 'lib-a', actor_user_id: 'u-act', payload: null };
  const ADMIN = { id: 'u-adm', email: 'xavier@exemplo.test', first_name: 'Xavier', preferred_language: 'fr' };
  function monter(env = {}) {
    return monterEF({
      entree: 'notify-cross-library-digest/index.ts',
      env: { WEBHOOK_SECRET_NOTIFY_CROSS_LIBRARY_DIGEST: SECRET, ...env },
      repondre: (_s, table, a) => {
        if (table === 'network_admin_cross_library_actions_log') return { data: [ACTION], error: null };
        if (table === 'libraries') return { data: [{ id: 'lib-a', name: 'Biblioteca A', default_locale: 'pt-BR' }], error: null };
        if (table === 'user_library_memberships') return { data: [], error: null };
        if (table === 'network_administrators') return { data: [{ user_id: 'u-adm' }], error: null };
        if (table === 'profiles') {
          if (dansIn(a, 'u-adm')) return { data: [ADMIN], error: null };
          return { data: [{ id: 'u-act', first_name: 'Ravachol', last_name: null, email: 'r@exemplo.test' }], error: null };
        }
        return { data: null, error: null };
      },
    });
  }
  const appeler = (ef) => ef.appeler(new Request('http://ef.local/', {
    method: 'POST', headers: { 'x-webhook-secret': SECRET, 'content-type': 'application/json' },
    body: JSON.stringify({ week_start: '2026-09-21', week_end: '2026-09-27', dry_run: true }),
  }));

  it('admin en fr, boîte en pt-BR, cadrage « network » pour les deux', async () => {
    const { statut, corps } = await appeler(monter({ NETWORK_ADMIN_CC: 'admins@exemplo.test' }));
    expect(statut).toBe(200);
    const reseau = corps.details.filter((d) => d.cadrage === 'network').map((d) => [d.email, d.locale]);
    expect(reseau).toEqual([['xavier@exemplo.test', 'fr'], ['admins@exemplo.test', 'pt-BR']]);
    const { tr } = monter().charger('_shared/i18n/cross-library-strings.ts');
    const vars = (loc) => ({ start: new Date('2026-09-21').toLocaleDateString(loc), end: new Date('2026-09-27').toLocaleDateString(loc), count: '1' });
    expect(corps.details.find((d) => d.email === 'admins@exemplo.test').sujet).toBe(tr('pt-BR', 'network.subject', vars('pt-BR')));
    expect(corps.details.find((d) => d.email === 'xavier@exemplo.test').sujet).toBe(tr('fr', 'network.subject', vars('fr')));
  });

  it('sans variable : les personnes seules, comme avant', async () => {
    const { corps } = await appeler(monter());
    expect(corps.details.filter((d) => d.cadrage === 'network').map((d) => d.email)).toEqual(['xavier@exemplo.test']);
  });
});

describe('membership-restriction — le gel global est copié aux admins ET à la boîte', () => {
  const MEMBRE = { id: 'u-m', email: 'membre@exemplo.test', first_name: 'Louise', last_name: 'Michel', preferred_language: 'fr' };
  const ADMIN = { id: 'u-adm', email: 'xavier@exemplo.test', first_name: 'Xavier', preferred_language: 'fr' };
  function monter(env = {}) {
    const ef = monterEF({
      env,
      repondre: (_s, table, a, chaine) => {
        if (table === 'profiles') {
          if (eq(chaine, 'id') === 'u-m') return { data: MEMBRE, error: null };
          if (dansIn(a, 'u-adm')) return { data: [ADMIN], error: null };
        }
        if (table === 'user_library_memberships') return { data: [], error: null };
        if (table === 'network_administrators') return { data: [{ user_id: 'u-adm' }], error: null };
        if (table === 'user_notifications') return { data: null, error: null };
        return { data: null, error: null };
      },
    });
    return { ef, handle: ef.charger('_shared/domain/membership-restriction.ts').handleMembershipRestriction, tMail: ef.charger('_shared/i18n/mail-strings.ts').tMail };
  }

  it('la boîte reçoit en pt-BR, l\'admin en fr, la personne gelée en fr ; le résultat réseau est un tableau', async () => {
    const { ef, handle, tMail } = monter({ NETWORK_ADMIN_CC: 'admins@exemplo.test' });
    const r = await handle('member_frozen_global', { user_id: 'u-m', reason: 'motif' });
    expect(ef.envois.map((e) => e.to[0]).sort()).toEqual(['admins@exemplo.test', 'membre@exemplo.test', 'xavier@exemplo.test']);
    expect(mailA(ef.envois, 'admins@exemplo.test').subject).toContain(tMail('pt-BR', 'restriction.global.subject'));
    expect(mailA(ef.envois, 'xavier@exemplo.test').subject).toContain(tMail('fr', 'restriction.global.subject'));
    expect(Array.isArray(r.network_result)).toBe(true);
    expect(r.network_result.map((x) => x.email).sort()).toEqual(['admins@exemplo.test', 'xavier@exemplo.test']);
  });

  it('un gel LOCAL ne touche pas le réseau', async () => {
    const { ef, handle } = monter({ NETWORK_ADMIN_CC: 'admins@exemplo.test' });
    const r = await handle('member_frozen', { user_id: 'u-m', library_id: 'lib-a' });
    expect(ef.envois.map((e) => e.to[0])).not.toContain('admins@exemplo.test');
    expect(r.network_result).toBeNull();
  });
});

describe('notify-network-weekly-report — le rapport part aux admins, à la boîte et au destinataire historique', () => {
  const ADMIN = { id: 'u-adm', email: 'xavier@exemplo.test', first_name: 'Xavier', preferred_language: 'fr' };
  function monter(env = {}) {
    return monterEF({
      entree: 'notify-network-weekly-report/index.ts',
      env: { WEBHOOK_SECRET_NOTIFY_NETWORK_WEEKLY_REPORT: SECRET, SENDER_EMAIL: 'no-reply@exemplo.test', ...env },
      repondre: (_s, table, a) => {
        if (table === 'libraries') return { data: [{ id: 'lib-a', name: 'Biblioteca A', short_name: 'BA', is_active: true }], error: null };
        if (table === 'network_administrators') return { data: [{ user_id: 'u-adm' }], error: null };
        if (table === 'profiles' && dansIn(a, 'u-adm')) return { data: [ADMIN], error: null };
        return { data: [], error: null };
      },
    });
  }
  const appeler = (ef) => ef.appeler(new Request('http://ef.local/', {
    method: 'POST', headers: { 'x-webhook-secret': SECRET, 'content-type': 'application/json' },
    body: JSON.stringify({ week_start: '2026-09-21', week_end: '2026-09-27' }),
  }));

  it('trois envois du même rapport ; la réponse nomme les adresses', async () => {
    const ef = monter({ NETWORK_ADMIN_CC: 'admins@exemplo.test', NETWORK_WEEKLY_REPORT_EMAIL: 'rapport@exemplo.test' });
    const { statut, corps } = await appeler(ef);
    expect(statut, JSON.stringify(corps)).toBe(200);
    expect(corps.recipient_emails).toEqual(['xavier@exemplo.test', 'admins@exemplo.test', 'rapport@exemplo.test']);
    expect(ef.envois.map((e) => e.to[0])).toEqual(['xavier@exemplo.test', 'admins@exemplo.test', 'rapport@exemplo.test']);
    expect(new Set(ef.envois.map((e) => e.subject)).size).toBe(1);
  });

  it('sans variable ni destinataire historique : les admins actif·ves suffisent (avant, 422)', async () => {
    const ef = monter();
    const { statut, corps } = await appeler(ef);
    expect(statut).toBe(200);
    expect(corps.recipient_emails).toEqual(['xavier@exemplo.test']);
  });

  it('un refus sur une adresse n\'empêche pas les autres, et fait 500 en nommant l\'adresse', async () => {
    const ef = monterEF({
      entree: 'notify-network-weekly-report/index.ts',
      env: { WEBHOOK_SECRET_NOTIFY_NETWORK_WEEKLY_REPORT: SECRET, SENDER_EMAIL: 'no-reply@exemplo.test', NETWORK_ADMIN_CC: 'admins@exemplo.test' },
      resend: (p) => (p.to[0] === 'xavier@exemplo.test' ? new Response('panne', { status: 500 }) : new Response('{}', { status: 200 })),
      repondre: (_s, table, a) => {
        if (table === 'libraries') return { data: [{ id: 'lib-a', name: 'Biblioteca A', short_name: 'BA', is_active: true }], error: null };
        if (table === 'network_administrators') return { data: [{ user_id: 'u-adm' }], error: null };
        if (table === 'profiles' && dansIn(a, 'u-adm')) return { data: [ADMIN], error: null };
        return { data: [], error: null };
      },
    });
    const { statut, corps } = await appeler(ef);
    expect(statut).toBe(500);
    expect(corps.error).toContain('xavier@exemplo.test');
    expect(ef.envois.map((e) => e.to[0])).toEqual(['admins@exemplo.test']);
  });
});
