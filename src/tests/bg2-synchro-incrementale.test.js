// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/bg2-synchro-incrementale.test.js
//
// CE QUE CE TEST PROTÈGE (18/10/2026). Le tir `storage` du 18/10 a été tué par
// sa borne d'une heure : il purgeait son miroir et retéléchargeait TOUS les
// buckets à chaque fois, et 18 Go de PDF venaient d'arriver en une semaine.
// deploy/ops/anarbib-bg2.sh compare désormais la liste des objets (base) à un
// manifeste local, et ne télécharge que le nouveau ou le modifié.
//
// Une synchronisation fausse est pire qu'une synchronisation lente : elle
// produit des sauvegardes vertes et incomplètes. D'où les cas : rien à
// retélécharger au second tir, un objet REMPLACÉ sous le même nom, un objet
// supprimé, un téléchargement en échec (jamais de fichier tronqué sous le vrai
// nom, et le tir se dit incomplet), l'amorçage sur un miroir existant, le lien
// dur de map-tiles qu'on ne doit pas abîmer, la base injoignable.
//
// On exécute les VRAIES fonctions `telecharger_objet` et `synchro_bucket`,
// extraites du script, avec un `psql` et un `supabase` stubés.

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { execFileSync } from 'node:child_process';
import {
  mkdtempSync, mkdirSync, writeFileSync, rmSync, readFileSync, existsSync, linkSync, readdirSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const SCRIPT = fileURLToPath(new URL('../../deploy/ops/anarbib-bg2.sh', import.meta.url));

// Même choix que fraicheur-relance.test.js : Git Bash sous Windows.
const BASH = process.platform === 'win32'
  ? ['C:\\Program Files\\Git\\bin\\bash.exe', 'C:\\Program Files\\Git\\usr\\bin\\bash.exe'].find((p) => existsSync(p)) ?? null
  : 'bash';
const DELAI = process.platform === 'win32' ? 240_000 : 30_000;
const posix = (p) => p.replace(/\\/g, '/');

// Le corps d'une fonction bash, de « nom() { » à la première « } » en colonne 0.
function fonction(source, nom) {
  const lignes = source.split('\n');
  const debut = lignes.findIndex((l) => l.startsWith(`${nom}() {`));
  if (debut < 0) throw new Error(`fonction ${nom} introuvable dans anarbib-bg2.sh`);
  const fin = lignes.findIndex((l, i) => i > debut && l === '}');
  return lignes.slice(debut, fin + 1).join('\n');
}

let racine;
let stub;
let harnais;

beforeAll(() => {
  racine = mkdtempSync(path.join(tmpdir(), 'anarbib-synchro-'));
  stub = path.join(racine, 'stub');
  mkdirSync(stub, { recursive: true });
  const source = readFileSync(SCRIPT, 'utf8');

  // psql : rend la liste préparée par le cas (nom, taille, eTag), ou échoue.
  writeFileSync(path.join(stub, 'psql'), [
    '#!/bin/bash',
    '[ "${FAUX_PSQL_KO:-0}" = 1 ] && { echo "connexion refusee" >&2; exit 2; }',
    'cat "$FAUX_LISTE"',
    '',
  ].join('\n'), { mode: 0o755 });

  // supabase storage cp … ss:///<bucket>/<nom> <destination> : copie depuis
  // FAUX_STORAGE, journalise l'appel. Un nom listé dans FAUX_ECHECS échoue
  // APRÈS avoir écrit quelques octets — comme un transfert coupé.
  writeFileSync(path.join(stub, 'supabase'), [
    '#!/bin/bash',
    'src="${@: -2:1}"; dst="${@: -1}"',
    'nom="${src#ss:///*/}"',
    'echo "$nom" >> "$FAUX_APPELS"',
    'if grep -qxF -- "$nom" "$FAUX_ECHECS" 2>/dev/null; then printf "tronq" > "$dst"; exit 1; fi',
    'cp -- "$FAUX_STORAGE/$nom" "$dst"',
    '',
  ].join('\n'), { mode: 0o755 });

  harnais = path.join(racine, 'harnais.sh');
  writeFileSync(harnais, [
    '#!/bin/bash',
    'set -euo pipefail',
    'PGCONN="host=essai"',
    'SUPABASE_REPO="$FAUX_REPO"',
    'SYNCHRO_PARALLELE=3',
    fonction(source, 'telecharger_objet'),
    fonction(source, 'synchro_bucket'),
    'if synchro_bucket "$FAUX_BUCKET" "$FAUX_RACINE"; then echo "RC=0"; else echo "RC=1"; fi',
    '',
  ].join('\n'), { mode: 0o755 });
}, DELAI);

afterAll(() => {
  if (racine) rmSync(racine, { recursive: true, force: true });
});

let n = 0;
// Un « Storage » distant : { nom: { contenu, etag } }.
function nouveauCas() {
  const dir = path.join(racine, `cas-${++n}`);
  const cas = {
    dir,
    storage: path.join(dir, 'storage'),
    miroir: path.join(dir, 'miroir'),
    objets: {},
    echecs: [],
    psqlKo: false,
  };
  mkdirSync(cas.storage, { recursive: true });
  mkdirSync(path.join(dir, 'repo'), { recursive: true });
  return cas;
}
function poser(cas, nom, contenu, etag) {
  cas.objets[nom] = { contenu, etag };
  const f = path.join(cas.storage, nom);
  mkdirSync(path.dirname(f), { recursive: true });
  writeFileSync(f, contenu);
}
function retirer(cas, nom) {
  delete cas.objets[nom];
  rmSync(path.join(cas.storage, nom));
}
function tir(cas) {
  const liste = path.join(cas.dir, 'liste.tsv');
  const appels = path.join(cas.dir, 'appels.txt');
  const echecs = path.join(cas.dir, 'echecs.txt');
  writeFileSync(liste, Object.entries(cas.objets).sort(([a], [b]) => (a < b ? -1 : 1))
    .map(([nom, o]) => `${nom}\t${Buffer.byteLength(o.contenu)}\t${o.etag}\n`).join(''));
  writeFileSync(appels, '');
  writeFileSync(echecs, cas.echecs.map((e) => `${e}\n`).join(''));
  const sortie = execFileSync(BASH, [posix(harnais)], {
    encoding: 'utf8',
    env: {
      ...process.env,
      PATH: `${posix(stub)}:${process.env.PATH}`,
      FAUX_LISTE: posix(liste),
      FAUX_APPELS: posix(appels),
      FAUX_ECHECS: posix(echecs),
      FAUX_STORAGE: posix(cas.storage),
      FAUX_REPO: posix(path.join(cas.dir, 'repo')),
      FAUX_BUCKET: 'pdf',
      FAUX_RACINE: posix(cas.miroir),
      FAUX_PSQL_KO: cas.psqlKo ? '1' : '0',
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  const telecharges = readFileSync(appels, 'utf8').split('\n').filter(Boolean).sort();
  return { sortie, rc: sortie.includes('RC=0') ? 0 : 1, telecharges };
}
const dansMiroir = (cas, nom) => path.join(cas.miroir, 'pdf', nom);
const lire = (cas, nom) => readFileSync(dansMiroir(cas, nom), 'utf8');
const manifeste = (cas) => readFileSync(path.join(cas.miroir, '.manifestes', 'pdf.tsv'), 'utf8')
  .split('\n').filter(Boolean);
function fichiers(dir) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { withFileTypes: true }).flatMap((e) => (e.isDirectory()
    ? fichiers(path.join(dir, e.name)).map((f) => `${e.name}/${f}`)
    : [e.name]));
}

describe.skipIf(!BASH)('#BG2 — synchronisation incrémentale des buckets (18/10/2026)', { timeout: DELAI }, () => {
  it('premier tir : tout est téléchargé, noms à espaces et sous-dossiers compris, et le manifeste suit', () => {
    const cas = nouveauCas();
    poser(cas, 'books/1/a.pdf', 'AAAA', '"e1"');
    poser(cas, 'books/2/CCL-1993 (1).pdf', 'BBBBBB', '"e2"');
    poser(cas, 'racine.pdf', 'C', '"e3"');
    const r = tir(cas);
    expect(r.rc).toBe(0);
    expect(r.telecharges).toEqual(['books/1/a.pdf', 'books/2/CCL-1993 (1).pdf', 'racine.pdf']);
    expect(lire(cas, 'books/2/CCL-1993 (1).pdf')).toBe('BBBBBB');
    expect(manifeste(cas)).toHaveLength(3);
    expect(r.sortie).toMatch(/OK\s+pdf : 3 objets — 3 telecharges, 0 deja la, 0 retires/);
  });

  it('second tir sans changement : AUCUN téléchargement — tout le sujet', () => {
    const cas = nouveauCas();
    poser(cas, 'a.pdf', 'AAAA', '"e1"');
    poser(cas, 'b.pdf', 'BB', '"e2"');
    tir(cas);
    const r = tir(cas);
    expect(r.rc).toBe(0);
    expect(r.telecharges).toEqual([]);
    expect(r.sortie).toMatch(/0 telecharges, 2 deja la/);
  });

  it('objet remplacé sous le même nom, même taille : l’eTag le trahit, lui seul est repris', () => {
    const cas = nouveauCas();
    poser(cas, 'a.pdf', 'AAAA', '"e1"');
    poser(cas, 'b.pdf', 'BB', '"e2"');
    tir(cas);
    poser(cas, 'a.pdf', 'ZZZZ', '"e1-bis"');
    const r = tir(cas);
    expect(r.telecharges).toEqual(['a.pdf']);
    expect(lire(cas, 'a.pdf')).toBe('ZZZZ');
  });

  it('objet supprimé dans Storage : retiré du miroir, dossier vide compris', () => {
    const cas = nouveauCas();
    poser(cas, 'books/9/parti.pdf', 'X', '"e1"');
    poser(cas, 'reste.pdf', 'Y', '"e2"');
    tir(cas);
    retirer(cas, 'books/9/parti.pdf');
    const r = tir(cas);
    expect(r.rc).toBe(0);
    expect(fichiers(path.join(cas.miroir, 'pdf'))).toEqual(['reste.pdf']);
    expect(r.sortie).toMatch(/1 retires/);
  });

  it('téléchargement en échec : tir INCOMPLET, aucun fichier tronqué, et le tir suivant réessaie', () => {
    const cas = nouveauCas();
    poser(cas, 'bon.pdf', 'OK', '"e1"');
    poser(cas, 'casse.pdf', 'CONTENU-COMPLET', '"e2"');
    cas.echecs = ['casse.pdf'];
    const r = tir(cas);
    expect(r.rc).toBe(1);
    expect(r.sortie).toMatch(/!!\s+pdf : .*1 EN ECHEC/);
    expect(existsSync(dansMiroir(cas, 'casse.pdf'))).toBe(false);
    expect(fichiers(path.join(cas.miroir, 'pdf'))).toEqual(['bon.pdf']); // ni .bg2-part ni tronqué
    expect(manifeste(cas).some((l) => l.startsWith('casse.pdf\t'))).toBe(false);

    cas.echecs = [];
    const r2 = tir(cas);
    expect(r2.rc).toBe(0);
    expect(r2.telecharges).toEqual(['casse.pdf']);
    expect(lire(cas, 'casse.pdf')).toBe('CONTENU-COMPLET');
  });

  it('amorçage sans manifeste : un fichier déjà là à la bonne taille est adopté, une taille fausse est reprise', () => {
    const cas = nouveauCas();
    poser(cas, 'deja.pdf', 'AAAA', '"e1"');
    poser(cas, 'faux.pdf', 'BBBBBB', '"e2"');
    mkdirSync(path.join(cas.miroir, 'pdf'), { recursive: true });
    writeFileSync(dansMiroir(cas, 'deja.pdf'), 'AAAA');
    writeFileSync(dansMiroir(cas, 'faux.pdf'), 'BB'); // transfert coupé d'un ancien tir
    const r = tir(cas);
    expect(r.rc).toBe(0);
    expect(r.telecharges).toEqual(['faux.pdf']);
    expect(lire(cas, 'faux.pdf')).toBe('BBBBBB');
    expect(manifeste(cas)).toHaveLength(2);
  });

  it('lien dur (amorçage de map-tiles) : un objet modifié remplace le lien, l’original reste intact', () => {
    const cas = nouveauCas();
    poser(cas, 'planet.pmtiles', 'TUILES-V1', '"v1"');
    const original = path.join(cas.dir, 'original.pmtiles');
    writeFileSync(original, 'TUILES-V1');
    mkdirSync(path.join(cas.miroir, 'pdf'), { recursive: true });
    linkSync(original, dansMiroir(cas, 'planet.pmtiles'));
    expect(tir(cas).telecharges).toEqual([]); // adopté : même taille
    poser(cas, 'planet.pmtiles', 'TUILES-V2', '"v2"');
    tir(cas);
    expect(lire(cas, 'planet.pmtiles')).toBe('TUILES-V2');
    expect(readFileSync(original, 'utf8')).toBe('TUILES-V1');
  });

  it('base injoignable : tir incomplet, miroir laissé tel quel (rien n’est retiré sur une liste vide)', () => {
    const cas = nouveauCas();
    poser(cas, 'a.pdf', 'AAAA', '"e1"');
    tir(cas);
    cas.psqlKo = true;
    const r = tir(cas);
    expect(r.rc).toBe(1);
    expect(r.sortie).toMatch(/liste des objets illisible/);
    expect(lire(cas, 'a.pdf')).toBe('AAAA');
  });
});
