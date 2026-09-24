// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/health-probe-instantane.test.js
//
// vitest.config.js exclut supabase/functions/** (« Deno, pas Node »). Le
// prédicat qui décide de signaler un instantané non attesté n'était donc
// protégé par rien — et c'est un prédicat dont les DEUX conditions comptent.
//
// `instantane_atteste` (migration 20260826170000) ne bascule pas `ok` : un
// instantané non attesté n'est pas une panne, c'est un angle mort. Personne ne
// lisait le champ, il était mort ; health-probe lui ouvre désormais un incident
// de genre `backup_snapshot` (migration 20260828234500).
//
// Les deux gardes que ce test tient :
//   * `!f.muet` — un flux muet est DÉJÀ signalé par l'alerte de sauvegarde ;
//     l'enlever ferait partir deux courriels pour une seule cause, et userait la
//     crédibilité des deux ;
//   * `=== false` et non `!f.instantane_atteste` — sur une base dont la RPC
//     n'expose pas encore le champ, la version laxiste signalerait les trois
//     flux d'un coup, sur rien.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { monterEF } from './helpers/monter-ef.js';

const SRC = new URL('../../supabase/functions/health-probe/index.ts', import.meta.url);
const src = readFileSync(SRC, 'utf8');

const ligne = src.split('\n').find((l) => l.includes('const sansInstantane ='));
if (!ligne) throw new Error('le prédicat sansInstantane est introuvable dans health-probe');

const debut = ligne.indexOf('filter(') + 'filter('.length;
const fin = ligne.lastIndexOf(')');
const predicat = new Function('return ' + ligne.slice(debut, fin))();

const flux = (o) => ({ flow: 'court', muet: false, instantane_atteste: true, ...o });

describe('health-probe — quand signaler un instantané non attesté', () => {
  it('signale un flux qui tire bien mais sans identifiant d’instantané', () => {
    expect(predicat(flux({ instantane_atteste: false }))).toBe(true);
  });

  it('ne signale pas un flux dont l’instantané est attesté', () => {
    expect(predicat(flux({ instantane_atteste: true }))).toBe(false);
  });

  it('ne signale PAS un flux muet : l’alerte de sauvegarde parle déjà de lui', () => {
    expect(predicat(flux({ muet: true, instantane_atteste: false }))).toBe(false);
  });

  it('ne signale pas un tir interrompu non plus (il est muet)', () => {
    expect(predicat(flux({ muet: true, interrompu: true, instantane_atteste: false }))).toBe(false);
  });

  it('ne signale rien si la RPC n’expose pas le champ (base plus ancienne)', () => {
    const sansChamp = { flow: 'court', muet: false };
    expect(predicat(sansChamp)).toBe(false);
  });

  it('ne signale rien sur un champ nul — l’absence n’est pas une négation', () => {
    expect(predicat(flux({ instantane_atteste: null }))).toBe(false);
  });
});

describe('health-probe — à qui part l’alerte', () => {
  // `destinataires()` ne lisait que `network_administrators`. Le réseau n'ayant
  // qu'UN administrateur, une alerte de supervision ne tenait qu'à une seule
  // boîte — et si la table est vide, elle ne partait NULLE PART, en silence.
  // `HEALTH_ALERT_CC` ajoute une adresse institutionnelle qui survit aux
  // départs. F15 (24/09/2026) : la résolution vit dans le module partagé
  // `_shared/context/network-admins.ts` (même règles, mêmes cas) ; health-probe
  // lui passe SA variable. Le module réel est monté par helpers/monter-ef.js.
  function module(admins = [], env = {}) {
    const ef = monterEF({
      env,
      repondre: (_s, table) => {
        if (table === 'network_administrators') return { data: admins.map((_p, i) => ({ user_id: `u-${i}` })), error: null };
        if (table === 'profiles') return { data: admins.map((p, i) => ({ id: `u-${i}`, ...p })), error: null };
        return { data: null, error: null };
      },
    });
    return { mod: ef.charger('_shared/context/network-admins.ts'), client: ef.charger('_shared/core/env.ts').supabaseAdmin };
  }
  const emails = (r) => r.map((c) => c.email);

  it('une variable vide ne change rien', async () => {
    const { mod, client } = module([{ email: 'x@exemple.org', first_name: 'X' }]);
    expect(mod.adressesSupplementaires('')).toEqual([]);
    expect(emails(await mod.destinatairesAdminsReseau(client, { cc: '' }))).toEqual(['x@exemple.org']);
  });

  it.each([
    ['admins@anarbib.org'],
    [' admins@anarbib.org '],
    ['admins@anarbib.org,autre@anarbib.org'],
    ['admins@anarbib.org; autre@anarbib.org'],
    ['admins@anarbib.org autre@anarbib.org'],
  ])('accepte la forme %s', (brut) => {
    const { mod } = module();
    expect(mod.adressesSupplementaires(brut)[0]).toBe('admins@anarbib.org');
  });

  it('ignore ce qui n’est pas une adresse', () => {
    const { mod } = module();
    expect(mod.adressesSupplementaires('pas-une-adresse, ni-celle-ci')).toEqual([]);
  });

  it('ajoute l’adresse institutionnelle aux administrateurs', async () => {
    const { mod, client } = module([{ email: 'xavier@exemple.org', first_name: 'Xavier' }]);
    expect(emails(await mod.destinatairesAdminsReseau(client, { cc: 'admins@anarbib.org' }))).toEqual(['xavier@exemple.org', 'admins@anarbib.org']);
  });

  it('n’envoie pas deux fois à la même adresse, quelle que soit la casse', async () => {
    const { mod, client } = module([{ email: 'Admins@AnarBib.org', first_name: 'Coordination' }]);
    expect(await mod.destinatairesAdminsReseau(client, { cc: 'admins@anarbib.org' })).toHaveLength(1);
  });

  it('alerte quand même si AUCUN administrateur n’est actif', async () => {
    // C'est le cas que l'ancien `if (!ids.length) return []` rendait muet.
    const { mod, client } = module([]);
    expect(emails(await mod.destinatairesAdminsReseau(client, { cc: 'admins@anarbib.org' }))).toEqual(['admins@anarbib.org']);
  });

  it('le garde-fou du code : plus de sortie prématurée sur table vide, et health-probe passe SA variable au module', () => {
    expect(src).not.toContain('if (!ids.length) return [];');
    expect(src).toContain("cc: Deno.env.get('HEALTH_ALERT_CC')");
    expect(src).toMatch(/context\/network-admins\.ts'/);
  });
});

describe('health-probe — le genre d’incident est distinct de `backup`', () => {
  // Sous le même genre, l'index unique (kind, subject) ferait que le flux muet et
  // le flux sans instantané se disputent la même ligne — et c'est le muet qui
  // compte. Ce test garde la séparation.
  it('ouvre et referme sur kind = backup_snapshot', () => {
    expect(src).toContain("kind: 'backup_snapshot'");
    expect(src).toContain("eq('kind', 'backup_snapshot')");
  });

  it('n’a pas remplacé le genre `backup` des flux muets', () => {
    expect(src).toContain("kind: 'backup', subject: f.flow");
  });
});
