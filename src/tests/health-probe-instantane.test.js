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
import { transformSync } from 'esbuild';

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
  // départs. Les deux fonctions pures sont transpilées depuis le vrai fichier.
  const debut = src.indexOf('function ccsSupplementaires');
  const finBloc = src.indexOf('async function destinataires');
  if (debut < 0 || finBloc < 0) throw new Error('les helpers de destinataires sont introuvables');
  const { code } = transformSync(src.slice(debut, finBloc), { loader: 'ts', format: 'cjs', target: 'es2022' });
  const { ccsSupplementaires, fusionnerDestinataires } = (() => {
    const exports = {};
    new Function('exports', code + '\nexports.ccsSupplementaires = ccsSupplementaires;\nexports.fusionnerDestinataires = fusionnerDestinataires;')(exports);
    return exports;
  })();

  it('une variable vide ne change rien', () => {
    expect(ccsSupplementaires('')).toEqual([]);
    const admins = [{ email: 'x@exemple.org', name: 'X' }];
    expect(fusionnerDestinataires(admins, [])).toEqual(admins);
  });

  it.each([
    ['admins@anarbib.org'],
    [' admins@anarbib.org '],
    ['admins@anarbib.org,autre@anarbib.org'],
    ['admins@anarbib.org; autre@anarbib.org'],
    ['admins@anarbib.org autre@anarbib.org'],
  ])('accepte la forme %s', (brut) => {
    const r = ccsSupplementaires(brut);
    expect(r[0].email).toBe('admins@anarbib.org');
  });

  it('ignore ce qui n’est pas une adresse', () => {
    expect(ccsSupplementaires('pas-une-adresse, ni-celle-ci')).toEqual([]);
  });

  it('ajoute l’adresse institutionnelle aux administrateurs', () => {
    const r = fusionnerDestinataires(
      [{ email: 'xavier@exemple.org', name: 'Xavier' }],
      ccsSupplementaires('admins@anarbib.org'),
    );
    expect(r.map((c) => c.email)).toEqual(['xavier@exemple.org', 'admins@anarbib.org']);
  });

  it('n’envoie pas deux fois à la même adresse, quelle que soit la casse', () => {
    const r = fusionnerDestinataires(
      [{ email: 'Admins@AnarBib.org', name: 'Coordination' }],
      ccsSupplementaires('admins@anarbib.org'),
    );
    expect(r).toHaveLength(1);
  });

  it('alerte quand même si AUCUN administrateur n’est actif', () => {
    // C'est le cas que l'ancien `if (!ids.length) return []` rendait muet.
    const r = fusionnerDestinataires([], ccsSupplementaires('admins@anarbib.org'));
    expect(r.map((c) => c.email)).toEqual(['admins@anarbib.org']);
  });

  it('le garde-fou du code : plus de sortie prématurée sur table vide', () => {
    expect(src).not.toContain('if (!ids.length) return [];');
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
