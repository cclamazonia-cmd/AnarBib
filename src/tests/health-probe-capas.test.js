// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/health-probe-capas.test.js
//
// La sonde témoin des sources de capas, dans le VRAI gestionnaire de
// health-probe (27/09/2026).
//
// POURQUOI. La voie ISBN de cover_lookup est restée en 404 chez Open Library
// pendant une durée inconnue sans que rien ne le dise. health-probe appelle
// désormais les sources une fois par heure, par le même code que cover_lookup.
// Ce banc tient la règle d'alerte : RIEN au premier échec (Open Library a des
// pannes passagères), l'alerte au deuxième d'affilée, la clôture au retour —
// avec un courriel seulement si l'on avait alerté.
//
// Harnais : helpers/monter-ef.js démarre health-probe avec ses vrais modules
// partagés (courriel, destinataires, transport). Remplacé ici, par suffixe
// (`remplacements`) : `_shared/capas/sources.ts` — sa mesure réseau rend le bilan
// voulu ; sa règle de décision est la VRAIE, chargée à part. La mesure réseau
// elle-même est éprouvée par cover-lookup-banc.test.js.

import { describe, it, expect, afterEach, vi } from 'vitest';
import { monterEF } from './helpers/monter-ef.js';

const reel = monterEF().charger('_shared/capas/sources.ts');

const ROUGE = { ok: false, sources: [
  { id: 'openlibrary', ok: false, count: 0, error: 'HTTP 404' },
  { id: 'inventaire', ok: true, count: 1 },
  { id: 'openlibrary_search', ok: true, count: 1 },
] };
const VERT = { ok: true, sources: [
  { id: 'openlibrary', ok: true, count: 1 },
  { id: 'inventaire', ok: true, count: 1 },
  { id: 'openlibrary_search', ok: true, count: 1 },
] };
const SUJET_ALERTE = 'AnarBib — une source de couvertures ne répond plus';
const SUJET_RETOUR = 'AnarBib — sources de couvertures : rétablies';

function monter({ bilan, incident = null }) {
  let mesures = 0;
  const ef = monterEF({
    entree: 'health-probe/index.ts',
    env: { HEALTH_ALERT_CC: '' },
    rpc: (_s, nom) => (nom === 'fn_check_health_probe_secret' ? { data: true, error: null } : { data: null, error: null }),
    repondre: (_s, table, a) => {
      if (table === 'service_health_incidents' && a('select') && a('eq')?.args?.[1] === 'capas_sources') {
        return { data: incident, error: null };
      }
      if (table === 'network_administrators') return { data: [{ user_id: 'u-0' }], error: null };
      if (table === 'profiles') return { data: [{ id: 'u-0', email: 'admin@exemple.org', first_name: 'A' }], error: null };
      return { data: null, error: null };
    },
    remplacements: {
      'capas/sources.ts': {
        sonderSourcesCapas: async () => { mesures++; return bilan; },
        decisionSondeCapas: reel.decisionSondeCapas,
      },
    },
  });
  const appeler = (corps) => ef.appeler(new Request('http://stub/functions/v1/health-probe', {
    method: 'POST',
    headers: { 'x-webhook-secret': 'secret-de-test', 'content-type': 'application/json' },
    body: JSON.stringify(corps),
  }));
  const incidentsCapas = () => ef.ecrits.filter((e) => e.table === 'service_health_incidents'
    && (e.op !== 'insert' || e.donnees?.kind === 'capas_sources'));
  const sujets = () => ef.envois.map((e) => e.subject);
  return { ef, appeler, incidentsCapas, sujets, mesures: () => mesures };
}

afterEach(() => { vi.useRealTimers(); });

describe('health-probe — sonde témoin des sources de capas', () => {
  it('premier échec : un incident ouvert, AUCUN courriel', async () => {
    const s = monter({ bilan: ROUGE });
    const { corps } = await s.appeler({ capas: true });
    expect(s.incidentsCapas()).toEqual([
      expect.objectContaining({ op: 'insert', donnees: { kind: 'capas_sources', reason: 'openlibrary : HTTP 404' } }),
    ]);
    expect(s.sujets()).not.toContain(SUJET_ALERTE);
    expect(corps.action_capas).toMatch(/^premier échec/);
    expect(corps.sources_capas).toEqual(ROUGE);
  });

  it('deuxième échec d’affilée : les admins sont alerté·es, l’incident est marqué signalé', async () => {
    const s = monter({ bilan: ROUGE, incident: { id: 7, opened_at: '2026-09-27T12:00:00Z', reason: 'openlibrary : HTTP 404', notified_at: null } });
    const { corps } = await s.appeler({ capas: true });
    expect(s.sujets()).toContain(SUJET_ALERTE);
    const maj = s.incidentsCapas().find((e) => e.op === 'update');
    expect(maj.donnees.notified_at).toBeTruthy();
    expect(maj.chaine.find((c) => c.op === 'eq').args).toEqual(['id', 7]);
    expect(s.incidentsCapas().some((e) => e.op === 'insert')).toBe(false);
    expect(corps.action_capas).toMatch(/^second échec/);
  });

  it('échec persistant, déjà signalé : ni nouvel incident, ni nouveau courriel', async () => {
    const s = monter({ bilan: ROUGE, incident: { id: 7, opened_at: '2026-09-27T12:00:00Z', reason: 'x', notified_at: '2026-09-27T13:00:00Z' } });
    await s.appeler({ capas: true });
    expect(s.incidentsCapas()).toEqual([]);
    expect(s.sujets()).toEqual([]);
  });

  it('retour après un hoquet d’une heure : l’incident se referme en silence', async () => {
    const s = monter({ bilan: VERT, incident: { id: 7, opened_at: '2026-09-27T12:00:00Z', reason: 'x', notified_at: null } });
    const { corps } = await s.appeler({ capas: true });
    expect(s.incidentsCapas()).toEqual([expect.objectContaining({ op: 'update', donnees: { closed_at: expect.any(String) } })]);
    expect(s.sujets()).toEqual([]);
    expect(corps.action_capas).toMatch(/^hoquet/);
  });

  it('retour après une alerte : clôture ET courriel de rétablissement', async () => {
    const s = monter({ bilan: VERT, incident: { id: 7, opened_at: '2026-09-27T12:00:00Z', reason: 'openlibrary : HTTP 404', notified_at: '2026-09-27T13:00:00Z' } });
    await s.appeler({ capas: true });
    expect(s.incidentsCapas()).toEqual([expect.objectContaining({ op: 'update', donnees: { closed_at: expect.any(String) } })]);
    expect(s.sujets()).toEqual([SUJET_RETOUR]);
  });

  it('une fois par heure seulement : hors des minutes 0 à 4, aucune source n’est appelée', async () => {
    vi.useFakeTimers({ toFake: ['Date'] });
    vi.setSystemTime(new Date('2026-09-27T14:07:00Z'));
    const hors = monter({ bilan: VERT });
    const { corps } = await hors.appeler({});
    expect(hors.mesures()).toBe(0);
    expect(corps.sources_capas).toBeNull();

    vi.setSystemTime(new Date('2026-09-27T15:02:00Z'));
    const dans = monter({ bilan: VERT });
    await dans.appeler({});
    expect(dans.mesures()).toBe(1);
  });
});
