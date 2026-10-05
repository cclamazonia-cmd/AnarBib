// ═══════════════════════════════════════════════════════════
// AnarBib — 05/10/2026 : un lien construit par une Edge Function mène à une
// route qui existe dans l'application.
//
// Le camarade coopté a cliqué sur le bouton de son courriel et reçu une 404 :
// /painel/admin-rede/cooptation/<id> n'a jamais été une route. Le même défaut
// touchait le retrait collectif et les transitions de profil
// (/painel/biblioteca/<id>/profil). Les bancs des courriels vérifiaient le
// DOMAINE des liens (APP_BASE_URL), jamais que le chemin existe : ils avaient
// même épinglé les adresses mortes. Cette garde lit chaque appUrl(…) des
// fonctions et le confronte aux <Route path> de src/App.jsx.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';

const RACINE = path.resolve(__dirname, '../..');
const FONCTIONS = path.join(RACINE, 'supabase/functions');

function fichiersTs(dossier) {
  const out = [];
  for (const n of readdirSync(dossier)) {
    const p = path.join(dossier, n);
    if (statSync(p).isDirectory()) out.push(...fichiersTs(p));
    else if (n.endsWith('.ts')) out.push(p);
  }
  return out;
}

// Les routes de l'application, en expressions : « :param » = un segment.
const ROUTES = [...readFileSync(path.join(RACINE, 'src/App.jsx'), 'utf8').matchAll(/<Route path="([^"]+)"/g)]
  .map((m) => m[1]).filter((r) => r !== '*')
  .map((r) => new RegExp('^' + r.replace(/:[A-Za-z]+/g, '[^/]+') + '$'));

// Chaque appUrl(…) à chemin littéral ; une interpolation ${…} vaut un segment.
const LIENS = fichiersTs(FONCTIONS).flatMap((f) => {
  const src = readFileSync(f, 'utf8');
  return [...src.matchAll(/appUrl\(\s*([`'"])(\/[^`'"]*)\1\s*\)/g)].map((m) => ({
    fichier: path.relative(RACINE, f).replace(/\\/g, '/'),
    brut: m[2],
    chemin: m[2].replace(/\$\{[^}]+\}/g, 'x').split(/[?#]/)[0] || '/',
  }));
});

describe('les liens des courriels', () => {
  it('la lecture trouve les liens et les routes (garde-fou du lecteur)', () => {
    expect(ROUTES.length).toBeGreaterThan(20);
    expect(LIENS.length).toBeGreaterThan(8);
    expect(LIENS.map((l) => l.brut)).toContain('/rede#tab=admins');
  });

  it('chaque chemin construit par une fonction est une route de l\'application', () => {
    const morts = LIENS.filter((l) => !ROUTES.some((re) => re.test(l.chemin)))
      .map((l) => `${l.fichier} : ${l.brut}`);
    expect(morts).toEqual([]);
  });
});
