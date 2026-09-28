// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/health-probe-ci.test.js
//
// A3 (28/09/2026) — la CI en retard ouvre un incident. Deux bancs :
//   1. la RÈGLE, pure (_shared/ci/forgejo-tasks.ts) : sur la liste des tâches
//      telle que l'API de Codeberg la rend — dont la vraie soirée du 27/09 —,
//      quand est-ce « en retard », et que décide-t-on face à l'incident ;
//   2. la SONDE, dans le vrai gestionnaire de health-probe : la mesure réseau
//      est remplacée (helpers/monter-ef.js, par suffixe), la règle est la vraie.
// Un 504 de la forge (`null`) ne change rien, jamais.

import { describe, it, expect } from 'vitest';
import { monterEF } from './helpers/monter-ef.js';

const reel = monterEF().charger('_shared/ci/forgejo-tasks.ts');
const { diagnostiquerCi, decisionSondeCi, SEUIL_ATTENTE_MIN, SEUIL_ECHEC_MIN } = reel;

// La soirée du 27/09 telle que l'API l'a rendue le 28/09 à 11 h 43 (extrait) :
// le job app de 911ad1db figé à 22:40 (veille du portable), déclaré en échec à
// 23:45 ; puis, le matin, app vert sur 6bdd4331 et sql-tests rouge.
const t = (id, name, status, head, created, updated) => ({ id, name, status, head_sha: head, created_at: created, updated_at: updated });
const SOIREE = [
  t(9896583, 'app', 'failure', '911ad1dbxx', '2026-09-27T22:40:28+02:00', '2026-09-27T23:45:41+02:00'),
  t(9896370, 'app', 'failure', '738283d5xx', '2026-09-27T22:30:45+02:00', '2026-09-27T22:39:44+02:00'),
  t(9896337, 'acquittement', 'success', '1948b78dxx', '2026-09-27T22:29:16+02:00', '2026-09-27T22:30:08+02:00'),
  t(9895647, 'backend', 'success', '1948b78dxx', '2026-09-27T22:06:47+02:00', '2026-09-27T22:09:52+02:00'),
];
const MATIN = [
  t(9913497, 'sql-tests', 'failure', '6bdd4331xx', '2026-09-28T11:40:46+02:00', '2026-09-28T11:42:51+02:00'),
  t(9913443, 'app', 'success', '6bdd4331xx', '2026-09-28T11:37:18+02:00', '2026-09-28T11:39:59+02:00'),
  ...SOIREE,
];

describe('diagnostiquerCi — la règle', () => {
  it('la soirée du 27/09 : à minuit, le dernier app est en échec depuis 15 min → pas encore (délai de grâce)', () => {
    const d = diagnostiquerCi(SOIREE, new Date('2026-09-28T00:00:00+02:00'));
    expect(d.ok).toBe(true);
  });

  it('à 1 h du matin : le dernier app en échec depuis plus de 30 min, rien de plus récent → en retard', () => {
    const d = diagnostiquerCi(SOIREE, new Date('2026-09-28T01:00:00+02:00'));
    expect(d.ok).toBe(false);
    expect(d.echecs.map((e) => e.id)).toEqual([9896583]);
    expect(d.raison).toMatch(/dernier job app en échec \(commit 911ad1db/);
  });

  it('le matin, un app vert plus récent : à jour — un sql-tests rouge n’est pas un déploiement', () => {
    const d = diagnostiquerCi(MATIN, new Date('2026-09-28T12:30:00+02:00'));
    expect(d.ok).toBe(true);
  });

  it('un job en attente depuis plus de deux heures : en retard ; depuis moins : file normale', () => {
    const base = [t(1, 'backend', 'waiting', 'abcdef01xx', '2026-09-28T10:00:00+02:00', '2026-09-28T10:00:00+02:00')];
    expect(diagnostiquerCi(base, new Date('2026-09-28T11:30:00+02:00')).ok).toBe(true);
    const d = diagnostiquerCi(base, new Date('2026-09-28T12:30:00+02:00'));
    expect(d.ok).toBe(false);
    expect(d.enAttente).toHaveLength(1);
    expect(d.raison).toMatch(/1 tâche\(s\) non terminée\(s\) depuis plus de 120 min/);
  });

  it('un job `running` figé compte comme non terminé (le portable en veille)', () => {
    const base = [t(1, 'app', 'running', 'abcdef01xx', '2026-09-27T22:40:28+02:00', '2026-09-27T22:40:30+02:00')];
    expect(diagnostiquerCi(base, new Date('2026-09-28T01:00:00+02:00')).ok).toBe(false);
  });

  it('un backend en échec masqué par un app vert plus récent reste un échec (le backend suit app)', () => {
    const base = [
      t(3, 'app', 'success', 'bbbbbbbbxx', '2026-09-28T10:00:00+02:00', '2026-09-28T10:02:00+02:00'),
      t(2, 'backend', 'failure', 'aaaaaaaaxx', '2026-09-28T09:00:00+02:00', '2026-09-28T09:05:00+02:00'),
    ];
    expect(diagnostiquerCi(base, new Date('2026-09-28T12:00:00+02:00')).echecs.map((e) => e.name)).toEqual(['backend']);
  });

  it('les seuils exportés sont ceux de la doctrine', () => {
    expect(SEUIL_ATTENTE_MIN).toBe(120);
    expect(SEUIL_ECHEC_MIN).toBe(30);
  });
});

describe('decisionSondeCi', () => {
  const rouge = { ok: false, raison: 'x', enAttente: [], echecs: [] };
  const vert = { ok: true, raison: '', enAttente: [], echecs: [] };
  it('forge injoignable : rien, incident ouvert ou pas', () => {
    expect(decisionSondeCi(null, null)).toBe('rien');
    expect(decisionSondeCi(null, { id: 1 })).toBe('rien');
  });
  it('rouge : ouvrir une fois, puis rien', () => {
    expect(decisionSondeCi(rouge, null)).toBe('ouvrir');
    expect(decisionSondeCi(rouge, { id: 1 })).toBe('rien');
  });
  it('vert : clore s’il y a un incident, sinon rien', () => {
    expect(decisionSondeCi(vert, { id: 1 })).toBe('clore');
    expect(decisionSondeCi(vert, null)).toBe('rien');
  });
});

// ── La sonde dans le vrai gestionnaire ────────────────────────────────────
function monter({ taches, incident = null }) {
  let lectures = 0;
  const ef = monterEF({
    entree: 'health-probe/index.ts',
    env: { HEALTH_ALERT_CC: '' },
    rpc: (_s, nom) => (nom === 'fn_check_health_probe_secret' ? { data: true, error: null } : { data: null, error: null }),
    repondre: (_s, table, a) => {
      if (table === 'service_health_incidents' && a('select') && a('eq')?.args?.[1] === 'ci_en_retard') {
        return { data: incident, error: null };
      }
      if (table === 'service_health_incidents' && a('insert')) return { data: { id: 77 }, error: null };
      if (table === 'network_administrators') return { data: [{ user_id: 'u-0' }], error: null };
      if (table === 'profiles') return { data: [{ id: 'u-0', email: 'admin@exemple.org', first_name: 'A' }], error: null };
      return { data: null, error: null };
    },
    remplacements: {
      'ci/forgejo-tasks.ts': {
        lireTachesForgejo: async () => { lectures++; return taches; },
        diagnostiquerCi: reel.diagnostiquerCi,
        decisionSondeCi: reel.decisionSondeCi,
      },
    },
  });
  const appeler = (corps) => ef.appeler(new Request('http://stub/functions/v1/health-probe', {
    method: 'POST',
    headers: { 'x-webhook-secret': 'secret-de-test', 'content-type': 'application/json' },
    body: JSON.stringify(corps),
  }));
  const incidentsCi = () => ef.ecrits.filter((e) => e.table === 'service_health_incidents'
    && (e.op !== 'insert' || e.donnees?.kind === 'ci_en_retard'));
  const sujets = () => ef.envois.map((e) => e.subject);
  return { ef, appeler, incidentsCi, sujets, lectures: () => lectures };
}

const SUJET_ALERTE = 'AnarBib — la chaîne de déploiement est en retard';
const SUJET_RETOUR = 'AnarBib — chaîne de déploiement : à jour';
// Une tâche en attente depuis hier : en retard quelle que soit l'heure du banc.
const BLOQUEE = [t(1, 'backend', 'waiting', 'abcdef01xx', '2026-09-27T22:40:28+02:00', '2026-09-27T22:40:30+02:00')];
const A_JOUR = [t(2, 'app', 'success', 'abcdef01xx', '2026-09-28T11:37:18+02:00', '2026-09-28T11:39:59+02:00')];

describe('health-probe — la sonde de la CI', () => {
  it('sans `ci: true` hors du tick horaire : aucune lecture de la forge', async () => {
    const s = monter({ taches: BLOQUEE });
    const minute = new Date().getUTCMinutes();
    const { corps: r } = await s.appeler({});
    if (minute >= 5 && minute < 10) {
      expect(s.lectures()).toBe(1);   // c'est le tick : la lecture a eu lieu
    } else {
      expect(s.lectures()).toBe(0);
      expect(r.action_ci).toMatch(/une par heure/);
    }
  });

  it('en retard, sans incident : un incident ouvert et UN courriel qui dit quoi faire', async () => {
    const s = monter({ taches: BLOQUEE });
    const { corps: r } = await s.appeler({ ci: true });
    expect(r.ci.ok).toBe(false);
    expect(s.incidentsCi().some((e) => e.op === 'insert')).toBe(true);
    expect(s.sujets()).toEqual([SUJET_ALERTE]);
    expect(s.ef.envois[0].html).toMatch(/relancer/);
    expect(s.ef.envois[0].html).toMatch(/deploy\/ops\/RUNNER\.md/);
    expect(r.action_ci).toMatch(/incident ouvert, 1 destinataire/);
  });

  it('en retard, incident déjà ouvert : rien de plus', async () => {
    const s = monter({ taches: BLOQUEE, incident: { id: 5, opened_at: '2026-09-28T01:05:00Z', reason: 'x' } });
    const { corps: r } = await s.appeler({ ci: true });
    expect(s.sujets()).toEqual([]);
    expect(r.action_ci).toMatch(/déjà signalé/);
  });

  it('à jour, incident ouvert : clos, un courriel de retour', async () => {
    const s = monter({ taches: A_JOUR, incident: { id: 5, opened_at: '2026-09-28T01:05:00Z', reason: 'x' } });
    const { corps: r } = await s.appeler({ ci: true });
    expect(s.incidentsCi().some((e) => e.op === 'update' && e.donnees?.closed_at)).toBe(true);
    expect(s.sujets()).toEqual([SUJET_RETOUR]);
    expect(r.action_ci).toMatch(/incident clos/);
  });

  it('forge injoignable (null) : rien décidé, même avec un incident ouvert', async () => {
    const s = monter({ taches: null, incident: { id: 5, opened_at: '2026-09-28T01:05:00Z', reason: 'x' } });
    const { corps: r } = await s.appeler({ ci: true });
    expect(s.sujets()).toEqual([]);
    expect(s.incidentsCi().filter((e) => e.op === 'update')).toEqual([]);
    expect(r.action_ci).toMatch(/injoignable/);
  });
});
