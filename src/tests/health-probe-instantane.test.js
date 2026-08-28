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
