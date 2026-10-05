// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/journal-sans-adresse.test.js
//
// CE QUE CE TEST PROTÈGE (backlog F19, 30/09/2026). La carte de la chaîne de
// courriel (F1) a trouvé des adresses en clair dans les journaux des fonctions
// Edge — « [user_mail] sent to <adresse> » depuis au moins le 04/08 — : toute
// personne qui ouvre les journaux lisait les adresses des lectrices et du staff.
//
// Trois gardes :
//   1. le masque lui-même (supabase/functions/_shared/core/journal-masque.ts) :
//      « lectrice@exemple.org » devient « l…@exemple.org », y compris au milieu
//      d'un message d'erreur de Postgres, et sans abîmer un spécificateur npm ;
//   2. le filet : chaque fonction Edge atteint ce module par ses imports (il
//      s'installe au chargement sous Deno), aucune n'y échappe ;
//   3. aucune ligne de journal n'imprime un destinataire sans `masquerAdresse`.

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { transformSync } from 'esbuild';

const FONCTIONS = fileURLToPath(new URL('../../supabase/functions/', import.meta.url));
const MASQUE = path.join(FONCTIONS, '_shared', 'core', 'journal-masque.ts');

function charger() {
  const code = transformSync(readFileSync(MASQUE, 'utf8'), { loader: 'ts', format: 'cjs', target: 'es2022' }).code;
  const mod = { exports: {} };
  new Function('module', 'exports', code)(mod, mod.exports);
  return mod.exports;
}
const { masquerAdresses, masquerAdresse, installerMasque } = charger();

describe('le masque des adresses', () => {
  it('garde la première lettre et le domaine, rien d’autre', () => {
    expect(masquerAdresses('[user_mail] sent to lectrice@exemple.org')).toBe('[user_mail] sent to l…@exemple.org');
    expect(masquerAdresse('  a.b+tag@sous.domaine.fr ')).toBe('a…@sous.domaine.fr');
    expect(masquerAdresses('à x@y.com, zoe.martin@proton.me')).toBe('à x…@y.com, z…@proton.me');
  });

  it('masque une adresse citée par Postgres dans une erreur', () => {
    expect(masquerAdresses('duplicate key value violates unique constraint "profiles_email_key" Key (email)=(lectrice@exemple.org) already exists.'))
      .toContain('Key (email)=(l…@exemple.org)');
  });

  it('n’abîme ni un spécificateur npm, ni une date, ni un texte sans adresse', () => {
    for (const s of ['npm:@supabase/supabase-js@2.114.0', 'jsr:@std/assert@1.0.0', 'livre@2026', 'aucune adresse ici', '']) {
      expect(masquerAdresses(s)).toBe(s);
    }
    expect(masquerAdresse(null)).toBe('');
  });

  it('le filet masque chaînes, objets et erreurs, et ne s’installe qu’une fois', () => {
    const vus = [];
    const faux = { log: (...a) => vus.push(['log', ...a]), error: (...a) => vus.push(['error', ...a]), warn: () => {}, info: () => {}, debug: () => {} };
    installerMasque(faux);
    installerMasque(faux); // idempotent : pas de double enveloppe
    faux.log('envoi à lectrice@exemple.org', 3, null);
    faux.error({ row: { email: 'staff@biblio.org', id: 7 } }, new Error('Key (email)=(lectrice@exemple.org) already exists'));
    expect(vus[0]).toEqual(['log', 'envoi à l…@exemple.org', 3, null]);
    expect(vus[1][1]).toBe('{"row":{"email":"s…@biblio.org","id":7}}');
    expect(vus[1][2]).toMatch(/^Error: Key \(email\)=\(l…@exemple\.org\) already exists/);
    expect(JSON.stringify(vus)).not.toMatch(/lectrice@|staff@/);
  });
});

// Imports relatifs d'un fichier TypeScript (import … from, import '…', export … from).
function importsDe(fichier) {
  const src = readFileSync(fichier, 'utf8');
  const out = [];
  for (const m of src.matchAll(/(?:import|export)\s+(?:[^'"]*?\sfrom\s+)?['"](\.{1,2}\/[^'"]+)['"]/g)) {
    const cible = path.resolve(path.dirname(fichier), m[1]);
    if (existsSync(cible) && statSync(cible).isFile()) out.push(cible);
  }
  return out;
}
function atteint(entree, but) {
  const vus = new Set();
  const pile = [entree];
  while (pile.length) {
    const f = pile.pop();
    if (vus.has(f)) continue;
    vus.add(f);
    if (f === but) return true;
    pile.push(...importsDe(f));
  }
  return false;
}

describe('le filet : chaque fonction Edge charge le masque', () => {
  const fonctions = readdirSync(FONCTIONS).filter((n) => !n.startsWith('_') && existsSync(path.join(FONCTIONS, n, 'index.ts')));

  // 55 → 54 le 01/10/2026 : notify-mid-loan-reading retirée (F1, branche morte).
  // 54 → 52 le 05/10/2026 : read-pdf et mail-i18n-test retirées (F3, sans appel).
  it('les 52 fonctions sont là', () => {
    expect(fonctions.length).toBeGreaterThanOrEqual(52);
  });

  it('aucune n’échappe au masque (par deps.ts, la couche d’envoi, ou un import direct)', () => {
    const echappent = fonctions.filter((n) => !atteint(path.join(FONCTIONS, n, 'index.ts'), MASQUE));
    expect(echappent).toEqual([]);
  });
});

describe('aucun destinataire journalisé en clair', () => {
  function tous(dir) {
    return readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
      const p = path.join(dir, e.name);
      if (e.isDirectory()) return tous(p);
      return e.name.endsWith('.ts') && !e.name.endsWith('.test.ts') ? [p] : [];
    });
  }
  it('toute ligne console.* qui cite un destinataire passe par masquerAdresse', () => {
    const fautes = [];
    for (const f of tous(FONCTIONS)) {
      readFileSync(f, 'utf8').split('\n').forEach((ligne, i) => {
        if (!/console\.(log|info|warn|error|debug)\(/.test(ligne)) return;
        if (/\$\{(em|email|to|toEmail|destinataire|adresse)\}|target\.email|\.toEmail\b|destinataires\(/.test(ligne) && !/masquerAdresse/.test(ligne)) {
          fautes.push(`${path.relative(FONCTIONS, f)}:${i + 1}`);
        }
      });
    }
    expect(fautes).toEqual([]);
  });
});
