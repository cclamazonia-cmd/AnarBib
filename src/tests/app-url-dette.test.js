// ═══════════════════════════════════════════════════════════
// AnarBib — l'adresse de l'APPLICATION dans les Edge Functions : un foyer, et une
// dette nommée qui ne peut que rétrécir (21/09/2026)
//
// Foyer : supabase/functions/_shared/core/app-url.ts (secret APP_BASE_URL,
// ré-exporté par _shared/core/env.ts). Le relevé du 21/09, fait en posant le
// foyer de la vitrine, a compté « https://app.anarbib.org » écrit en dur dans
// vingt-quatre fichiers. `register` a été repris le jour même, DERRIÈRE un banc
// (register-banc.test.js), puis les mails des prêts et de la Lettre
// (notify-loan-cycle-banc, lettre-banc) ; les autres attendent le leur — on ne retouche pas un
// mail qu'aucun test ne rend.
//
// Trois listes, chacune avec son motif :
//   TOLERE : l'adresse y est une DONNÉE et non un lien (liste d'origines CORS,
//            en-tête CORS par défaut réécrit par avecOrigine, User-Agent) ;
//   DETTE  : un lien vers l'application écrit en toutes lettres, sourd à
//            APP_BASE_URL. Compte exact par fichier.
// Le test échoue si un fichier hors listes écrit l'adresse, si un compte MONTE,
// ou si une entrée de dette n'a plus d'objet (on la retire : la liste rétrécit).
//
// ANGLE MORT ASSUMÉ : le motif est textuel. Une adresse assemblée par morceaux
// (« https://app. » + domaine) lui échappe ; il n'y en a pas au 21/09/2026.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const BASE = 'supabase/functions';
const MOTIF = /https:\/\/app\.anarbib\.org(?![.\w])/g;          // pas app.anarbib.org.br

const FOYER = '_shared/core/app-url.ts';
const TOLERE = {
  '_shared/core/cors.ts': 2,                       // liste fermée des origines autorisées + son commentaire
  'geocode/index.ts': 1,                           // en-tête CORS par défaut, réécrit par avecOrigine
  'submit-cartography-entry/index.ts': 1,          // idem
  'submit-gazette-contribution/index.ts': 1,       // idem
  'gazette-monthly-build/index.ts': 1,             // User-Agent du moissonneur : une identité, pas un lien servi
};
const DETTE = {
  '_shared/domain/network.ts': 3,
  '_shared/domain/reservas.ts': 1,
  'notify-rede-digest/index.ts': 1,
  'opds/index.ts': 1,
  'rss-novidades/index.ts': 1,
};

function releve() {
  const out = {};
  (function parcourir(rel) {
    for (const e of readdirSync(join(ROOT, BASE, rel), { withFileTypes: true })) {
      const p = rel ? `${rel}/${e.name}` : e.name;
      if (e.isDirectory()) parcourir(p);
      else if (/\.ts$/.test(e.name) && !/\.test\.ts$/.test(e.name)) {
        const n = (readFileSync(join(ROOT, BASE, p), 'utf8').match(MOTIF) || []).length;
        if (n) out[p] = n;
      }
    }
  })('');
  return out;
}

describe("adresse de l'application dans les Edge Functions", () => {
  const vu = releve();

  it('le foyer porte le défaut, une fois', () => {
    expect(vu[FOYER]).toBe(1);
  });

  it('register ne l\'écrit plus nulle part (repris le 21/09/2026 derrière son banc)', () => {
    expect(vu['register/index.ts']).toBeUndefined();
    expect(vu['_shared/core/env.ts']).toBeUndefined();
  });

  it('aucun fichier hors listes, aucun compte qui monte', () => {
    const connus = { [FOYER]: 1, ...TOLERE, ...DETTE };
    const ecarts = Object.entries(vu).filter(([f, n]) => !(f in connus) || n > connus[f]).map(([f, n]) => `${f} : ${n} (attendu ≤ ${connus[f] ?? 0})`);
    expect(ecarts, "passer par appUrl() / APP_BASE_URL — _shared/core/app-url.ts").toEqual([]);
  });

  it('une entrée de dette ou de tolérance sans objet se retire : la liste ne peut que rétrécir', () => {
    const perimees = Object.entries({ ...TOLERE, ...DETTE }).filter(([f, n]) => (vu[f] || 0) < n).map(([f, n]) => `${f} : liste ${n}, relevé ${vu[f] || 0}`);
    expect(perimees, 'mettre la liste à jour dans ce fichier').toEqual([]);
  });
});
