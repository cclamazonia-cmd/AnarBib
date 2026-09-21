// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/pins-images-coherence.test.js
//
// Le 21/09/2026, les pins GoTrue et Storage de deploy/ ont été trouvés SOUS la
// production : l'hébergeur avait monté les deux services de lui-même, et le
// seul contrôle comparait à un chiffre écrit en dur un mois plus tôt
// (docs/journal/operations/NOTE_pins-images-remesures_2026-09-21.md).
//
// Depuis, ce que les pins savent construire est écrit à TROIS endroits, qui
// servent trois moments différents :
//   * deploy/.env.example          — le pin lui-même (le jour où l'on installe) ;
//   * deploy/bootstrap.sh          — les seuils du contrôle (le jour où l'on reconstruit) ;
//   * private.fn_images_pins_attendus() — l'attendu de la sonde (tous les jours).
// Trois copies d'un même fait divergent dès la première remesure faite à
// moitié. Cette garde refuse la moitié : qui remesure touche les trois, ou la
// CI est rouge.
//
// Elle tient aussi le branchement : le genre `images_pins` doit exister à la
// fois dans health-probe et dans la CHECK des incidents — sans la seconde,
// l'insertion échoue et l'alerte est retenue à chaque tour (20260821060000).

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';

const racine = new URL('../../', import.meta.url);
const lire = (p) => readFileSync(new URL(p, racine), 'utf8');

const dossier = new URL('supabase/migrations/', racine);
const migrations = readdirSync(dossier)
  .filter((f) => /^\d{14}_.*\.sql$/.test(f))
  .sort();

// La DERNIÈRE migration qui définit l'attendu fait foi : c'est elle qui tourne.
const definit = (f, motif) => motif.test(readFileSync(new URL(f, dossier), 'utf8'));
const derniere = (motif) => [...migrations].reverse().find((f) => definit(f, motif));

const fAttendus = derniere(/create or replace function private\.fn_images_pins_attendus\(\)/i);
if (!fAttendus) throw new Error('aucune migration ne définit private.fn_images_pins_attendus()');
const sqlAttendus = readFileSync(new URL(fAttendus, dossier), 'utf8');

const bloc = (composant) => {
  const m = sqlAttendus.match(
    new RegExp(`'${composant}',\\s*jsonb_build_object\\('tag',\\s*'([^']+)',\\s*'migrations',\\s*(\\d+),\\s*'derniere',\\s*'([^']+)'\\)`),
  );
  if (!m) throw new Error(`attendu illisible pour ${composant} dans ${fAttendus}`);
  return { tag: m[1], migrations: Number(m[2]), derniere: m[3] };
};
const attendu = { gotrue: bloc('gotrue'), storage: bloc('storage') };

const env = lire('deploy/.env.example');
const pin = (nom) => (env.match(new RegExp(`^${nom}=(.+)$`, 'm')) || [])[1]?.trim();

const bootstrap = lire('deploy/bootstrap.sh');
const seuil = (nom) => Number((bootstrap.match(new RegExp(`^${nom}=(\\d+)$`, 'm')) || [])[1]);

describe('pins d’images — un seul fait, trois endroits', () => {
  it('le pin GoTrue de .env.example est celui que la sonde attend', () => {
    expect(pin('GOTRUE_TAG')).toBe(attendu.gotrue.tag);
  });

  it('le pin Storage de .env.example est celui que la sonde attend', () => {
    expect(pin('STORAGE_TAG')).toBe(attendu.storage.tag);
  });

  it('les seuils de bootstrap.sh sont ceux de la sonde', () => {
    expect(seuil('PROD_AUTH_MIG')).toBe(attendu.gotrue.migrations);
    expect(seuil('PROD_STORAGE_MIG')).toBe(attendu.storage.migrations);
  });

  it('le tableau du README de deploy/ annonce les mêmes pins', () => {
    const readme = lire('deploy/README.md');
    expect(readme).toContain(`supabase/gotrue:${attendu.gotrue.tag}`);
    expect(readme).toContain(`supabase/storage-api:${attendu.storage.tag}`);
  });
});

describe('pins d’images — la sonde est branchée des deux côtés', () => {
  const probe = lire('supabase/functions/health-probe/index.ts');

  it('health-probe lit la sonde sous le genre images_pins', () => {
    expect(probe).toMatch(/kind:\s*'images_pins'/);
    expect(probe).toMatch(/rpc:\s*'fn_healthcheck_images_pins'/);
  });

  it('la dernière définition de la CHECK des incidents accepte images_pins', () => {
    const fCheck = derniere(/add constraint service_health_incidents_kind_check/i);
    expect(fCheck).toBeTruthy();
    const sql = readFileSync(new URL(fCheck, dossier), 'utf8');
    const corps = sql.slice(sql.search(/add constraint service_health_incidents_kind_check/i));
    expect(corps.slice(0, corps.indexOf(';'))).toContain("'images_pins'");
  });

  it('tout genre de sonde structurelle de health-probe est dans cette CHECK', () => {
    const fCheck = derniere(/add constraint service_health_incidents_kind_check/i);
    const sql = readFileSync(new URL(fCheck, dossier), 'utf8');
    const corps = sql.slice(sql.search(/add constraint service_health_incidents_kind_check/i));
    const check = corps.slice(0, corps.indexOf(';'));
    const debut = probe.indexOf('const sondesStructurelles');
    const liste = probe.slice(debut, probe.indexOf('];', debut));
    const genres = [...liste.matchAll(/kind:\s*'([a-z_]+)'/g)].map((m) => m[1]);
    expect(genres.length).toBeGreaterThanOrEqual(3);
    for (const g of genres) expect(check).toContain(`'${g}'`);
  });
});
