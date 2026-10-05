// ═══════════════════════════════════════════════════════════
// AnarBib — E23 (05/10/2026) : chaque HINT `error.*` posé par une fonction de
// la base a son libellé dans les dix locales.
//
// Une fonction SQL qui refuse pose une clé dans son HINT
// (`USING HINT = 'error.x.y'`) et `localizeError` la traduit. Si la clé manque,
// l'écran montre le message SQL brut ou un repli vague. La garde i18n lit le
// code du front, pas les migrations : cette garde-ci lit les migrations.
//
// Méthode :
//   · les migrations sont lues dans l'ordre (nom = horodatage) ;
//   · commentaires SQL retirés (`--` et `/* */`) : `error.foo.bar` cité en
//     exemple dans un commentaire n'est pas une clé posée ;
//   · chaque CREATE [OR REPLACE] FUNCTION remplace les clés de la définition
//     précédente de la MÊME fonction (schéma, nom, arguments) ; un DROP
//     FUNCTION les retire : une clé que plus aucune fonction en service ne pose
//     ne compte plus ;
//   · une clé posée hors d'un corps CREATE FUNCTION (une réécriture par
//     remplacement dans un bloc DO, par exemple) compte, sans retrait possible ;
//   · rollbacks et gabarit (fichiers « _… ») ignorés.
// Le 05/10, ce compte a été comparé aux définitions RÉELLES de la production
// (pg_proc.prosrc, commentaires retirés) : mêmes clés (verif de E23).
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';

const MIG_DIR = path.resolve(__dirname, '../../supabase/migrations');
const LOC_DIR = path.resolve(__dirname, '../i18n/locales');
const HINT_RE = /hint\s*:?=\s*'(error\.[A-Za-z0-9_.]+)'/gi;

// Retire les commentaires sans toucher aux chaînes entre apostrophes ni aux
// corps entre dollars (où un « -- » de commentaire PL/pgSQL compte aussi
// comme commentaire, ce qui est voulu).
function sansCommentaires(sql) {
  let out = '';
  let i = 0;
  let inStr = false;
  while (i < sql.length) {
    const c = sql[i];
    if (inStr) {
      out += c;
      if (c === "'") {
        if (sql[i + 1] === "'") { out += "'"; i += 2; continue; }
        inStr = false;
      }
      i += 1;
      continue;
    }
    if (c === "'") { inStr = true; out += c; i += 1; continue; }
    if (c === '-' && sql[i + 1] === '-') {
      const fin = sql.indexOf('\n', i);
      i = fin === -1 ? sql.length : fin;
      continue;
    }
    if (c === '/' && sql[i + 1] === '*') {
      const fin = sql.indexOf('*/', i + 2);
      i = fin === -1 ? sql.length : fin + 2;
      continue;
    }
    out += c;
    i += 1;
  }
  return out;
}

const cles = (txt) => new Set([...txt.matchAll(HINT_RE)].map((m) => m[1]));

function identite(schema, nom, args) {
  const s = (schema || 'public').replace(/"/g, '').toLowerCase();
  const n = nom.replace(/"/g, '').toLowerCase();
  const a = args.toLowerCase().replace(/\s+/g, ' ').replace(/\s*,\s*/g, ',').replace(/\s*default\s+[^,]+/g, '').trim();
  return `${s}.${n}(${a})`;
}

// Fin de la liste d'arguments, parenthèses imbriquées comprises.
function finDesArguments(sql, ouvrante) {
  let prof = 0;
  for (let i = ouvrante; i < sql.length; i += 1) {
    if (sql[i] === '(') prof += 1;
    else if (sql[i] === ')') { prof -= 1; if (prof === 0) return i; }
  }
  return -1;
}

function hintsEnService(dir = MIG_DIR) {
  const parFonction = new Map();
  const horsFonction = new Set();
  const fichiers = readdirSync(dir).filter((f) => /^\d{14}_.*\.sql$/.test(f)).sort();
  const CREATE = /create\s+(?:or\s+replace\s+)?function\s+(?:("?[\w]+"?)\.)?("?[\w]+"?)\s*\(/gi;
  const DROP = /drop\s+function\s+(?:if\s+exists\s+)?(?:("?[\w]+"?)\.)?("?[\w]+"?)\s*\(([^)]*)\)/gi;
  for (const f of fichiers) {
    const sql = sansCommentaires(readFileSync(path.join(dir, f), 'utf8'));
    // Repère les corps de fonctions, dans l'ordre du fichier.
    const evenements = [];
    let reste = '';
    let curseur = 0;
    for (const m of sql.matchAll(CREATE)) {
      const ouvrante = m.index + m[0].length - 1;
      const fermante = finDesArguments(sql, ouvrante);
      if (fermante < 0) continue;
      const args = sql.slice(ouvrante + 1, fermante);
      const as = /\bas\s+(\$[A-Za-z0-9_]*\$)/i.exec(sql.slice(fermante));
      if (!as) continue;
      const debut = fermante + as.index + as[0].length;
      const finCorps = sql.indexOf(as[1], debut);
      if (finCorps < 0) continue;
      if (m.index < curseur) continue; // CREATE cité dans le corps d'une autre
      reste += sql.slice(curseur, m.index);
      evenements.push({ pos: m.index, type: 'create', id: identite(m[1], m[2], args), cles: cles(sql.slice(debut, finCorps)) });
      curseur = finCorps + as[1].length;
    }
    reste += sql.slice(curseur);
    for (const m of sql.matchAll(DROP)) {
      evenements.push({ pos: m.index, type: 'drop', id: identite(m[1], m[2], m[3]) });
    }
    evenements.sort((a, b) => a.pos - b.pos);
    for (const e of evenements) {
      if (e.type === 'create') parFonction.set(e.id, e.cles);
      else parFonction.delete(e.id);
    }
    for (const k of cles(reste)) horsFonction.add(k);
  }
  const toutes = new Set(horsFonction);
  for (const s of parFonction.values()) for (const k of s) toutes.add(k);
  return toutes;
}

describe('E23 — chaque HINT error.* de la base a son libellé', () => {
  const hints = [...hintsEnService()].sort();
  const locales = readdirSync(LOC_DIR).filter((f) => f.endsWith('.json'));

  it('la lecture des migrations trouve les HINT (garde-fou du lecteur)', () => {
    expect(locales).toHaveLength(10);
    expect(hints.length).toBeGreaterThan(150);
    expect(hints).toContain('error.publish.exemplar_moved');   // posé par une réécriture en bloc DO (C14)
    expect(hints).toContain('error.catalog.staff_only');
  });

  it('un commentaire qui cite une clé n\'en pose pas', () => {
    expect(sansCommentaires("-- USING HINT = 'error.foo.bar'\nselect 1")).not.toMatch(/error\.foo/);
    expect(sansCommentaires("select '--', 'a''b' -- x\n")).toBe("select '--', 'a''b' \n");
  });

  for (const f of locales) {
    it(`${f} : aucune clé posée par la base ne manque`, () => {
      const j = JSON.parse(readFileSync(path.join(LOC_DIR, f), 'utf8'));
      const manquantes = hints.filter((k) => !(k in j));
      expect(manquantes).toEqual([]);
    });
  }
});
