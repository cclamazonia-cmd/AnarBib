// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/doctrine-migrations-garde.test.js
//
// I28 (27/09/2026). Les règles bloquantes de la doctrine vivaient dans un seul
// endroit, le hook .githooks/pre-commit — et ce hook ne tourne que dans le
// checkout Windows (`core.hooksPath = .githooks`) : ni ~/anarbib ni ses
// worktrees WSL, où les sessions travaillent depuis le 21/08, ne le règlent, et
// son lanceur appelle powershell.exe. Mesure du 27/09 : 15 migrations à l'heure
// ronde depuis le 31/08, 12 écarts à la doctrine SQL entre le 21/08 et le
// 31/08, et le soir même cinq migrations de B10 datées dans le futur, sans que
// rien ne l'arrête. I9 avait été clos le 30/08 « par une règle » : la règle ne
// tournait pas là où l'on travaille.
//
// Cette garde porte les mêmes règles, à l'identique (mêmes expressions que
// pre-commit.ps1), dans `npm test` : elle tourne donc avant chaque push dans la
// chaîne de livraison, et en CI pour tout le monde. Le hook reste utile côté
// Windows ; il n'est plus le seul rempart.
//
// Ce qui ne peut pas se vérifier ici, et pourquoi : le hook ne regarde que les
// fichiers AJOUTÉS au commit ; la CI part d'un clone superficiel, sans
// l'historique qui dirait quand un fichier est entré. D'où le seuil : les règles
// de nom et de doctrine s'appliquent à toute migration datée du 31/08 ou après
// (DOC-DEPLOY-4 est acté du 30/08), avec la liste fermée de ce qui est déjà
// appliqué en production et ne se renomme plus.

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';

const racine = new URL('../../', import.meta.url);
const lire = (p) => readFileSync(new URL(p, racine), 'utf8');

const DEPUIS = '20260831000000';

const fichiers = readdirSync(new URL('supabase/migrations/', racine)).filter((n) => n.endsWith('.sql'));
// Les fichiers préfixés par _ ne sont pas des migrations : le gabarit et les
// scripts de retour arrière (qui portent en NOM la version qu'ils annulent).
const migrations = fichiers.filter((n) => !n.startsWith('_'));
const version = (n) => n.slice(0, 14);

// Déjà appliquées en production à l'heure ronde, après le 30/08 : on ne renomme
// pas une migration inscrite au journal (le push suivant échouerait sur « Remote
// migration versions not found »). La liste ne peut que rester close.
const HEURE_RONDE_ASSUMEE = new Set([
  '20260901220000', '20260904130000', '20260904150000', '20260904160000',
  '20260904170000', '20260904190000', '20260904200000', '20260904210000',
  '20260905160000', '20260905180000', '20260905220000', '20260907120000',
  '20260907220000', '20260927160000', '20260927180000',
]);

// Écarts à la doctrine SQL déjà appliqués, avec leur motif.
const DOCTRINE_ASSUMEE = {
  // v_author_alias_worklist et v_author_seed_candidates : vues de travail du lot
  // C5, jamais accordées à anon ni à authenticated — c'est le T7 de
  // grants_herites_tests.sql qui garde la classe dangereuse (vue sans
  // security_invoker LISIBLE par un rôle applicatif).
  '20260905160000_rapport_reseau_evidences_du_05_09.sql': ['R4'],
};

// Règles 1 à 5 de pre-commit.ps1, portées à l'identique : on retire les
// commentaires (faux positifs #80), pas les chaînes (une fonction créée en SQL
// dynamique vit dans une chaîne, et doit rester attrapée).
function ecartsDoctrine(texte) {
  let s = texte.replace(/\/\*[\s\S]*?\*\//g, ' ');
  s = s.replace(/--.*$/gm, '');
  const e = [];
  const creeUneFonction = /(CREATE\s+(OR\s+REPLACE\s+)?FUNCTION|ALTER\s+FUNCTION)/i.test(s);
  if (creeUneFonction && /SECURITY\s+DEFINER/i.test(s) && !/SET\s+"?search_path"?/i.test(s)) e.push('R1');
  if (/CREATE\s+FUNCTION[^;]+SECURITY\s+DEFINER/i.test(s) && !/REVOKE\s+EXECUTE.+FROM\s+PUBLIC/i.test(s)) e.push('R2');
  if (/CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:public|ingest)\.(?!__)\w+/im.test(s)
      && !/ENABLE\s+ROW\s+LEVEL\s+SECURITY/i.test(s)) e.push('R3');
  if (/CREATE\s+(?:OR\s+REPLACE\s+)?VIEW\s+(?!.*MATERIALIZED)/im.test(s) && !/security_invoker\s*=\s*true/i.test(s)) e.push('R4');
  const t = /CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?public\.(?!__)(\w+)/im.exec(s);
  if (t && !new RegExp(`GRANT\\s+\\w+.*ON\\s+(?:TABLE\\s+)?public\\.${t[1]}\\s+TO`, 'im').test(s)) e.push('R5');
  return e;
}
const LIBELLES = {
  R1: 'SECURITY DEFINER sans SET search_path',
  R2: 'nouvelle fonction SECURITY DEFINER sans REVOKE EXECUTE … FROM PUBLIC',
  R3: 'CREATE TABLE public/ingest sans ENABLE ROW LEVEL SECURITY',
  R4: 'CREATE VIEW sans security_invoker = true',
  R5: 'CREATE TABLE public sans GRANT explicite',
};

describe('I28 — les règles du hook pre-commit tournent en CI', () => {
  it('T1 toute migration porte un horodatage à 14 chiffres', () => {
    const fautives = migrations.filter((n) => !/^\d{14}_/.test(n));
    expect(fautives, 'le nom doit commencer par AAAAMMJJHHMMSS_ (UTC) : c\'est ce préfixe qui ordonne la CI et identifie la migration en production').toEqual([]);
  });

  it('T2 aucune version n\'est portée par deux fichiers', () => {
    const vues = new Map();
    for (const n of migrations) vues.set(version(n), [...(vues.get(version(n)) || []), n]);
    const doubles = [...vues.values()].filter((l) => l.length > 1).map((l) => l.join(' + '));
    expect(doubles, 'supabase db push indexe par version : il sauterait l\'un des deux SANS ERREUR (déploiement vert, migration jamais exécutée). Prendre l\'heure UTC réelle : date -u +%Y%m%d%H%M%S').toEqual([]);
  });

  it('T3 pas d\'heure ronde (…0000) depuis le 31/08, hors la liste close', () => {
    const rondes = migrations.filter((n) => version(n) >= DEPUIS && version(n).endsWith('0000') && !HEURE_RONDE_ASSUMEE.has(version(n)));
    expect(rondes, 'DOC-DEPLOY-4 : une migration s\'horodate à la seconde UTC réelle (date -u +%Y%m%d%H%M%S). Une heure ronde revient à choisir de mémoire dans douze créneaux par jour — c\'est ainsi qu\'on se retrouve à deux sur le même numéro').toEqual([]);
  });

  it('T3b la liste close ne désigne que des migrations présentes', () => {
    const presentes = new Set(migrations.map(version));
    expect([...HEURE_RONDE_ASSUMEE].filter((v) => !presentes.has(v))).toEqual([]);
  });

  it('T4 aucune migration n\'est datée dans le futur', () => {
    // Dix minutes de tolérance : horloges WSL, Windows et runner.
    const limite = new Date(Date.now() + 10 * 60 * 1000).toISOString().replace(/[-:T]/g, '').slice(0, 14);
    const futures = migrations.filter((n) => version(n) > limite);
    expect(futures, `DOC-DEPLOY-4 : datée en avance, une migration trie APRÈS des migrations qui n'existent pas encore — l'ordre du dépôt cesse d'être l'ordre d'application. Maintenant (UTC, +10 min) : ${limite}`).toEqual([]);
  });

  it('T5 doctrine SQL des migrations depuis le 31/08', () => {
    const ecarts = [];
    for (const n of migrations.filter((m) => version(m) >= DEPUIS)) {
      const e = ecartsDoctrine(lire(`supabase/migrations/${n}`)).filter((r) => !(DOCTRINE_ASSUMEE[n] || []).includes(r));
      if (e.length) ecarts.push(`${n} : ${e.map((r) => LIBELLES[r]).join(' ; ')}`);
    }
    expect(ecarts, 'voir docs/decisions/CHANTIER_doctrine_creation_objets_securises_2026-05-12.md et supabase/migrations/_TEMPLATE.sql').toEqual([]);
  });

  it('T5b la liste des écarts assumés ne désigne que des écarts réels', () => {
    const perimees = Object.entries(DOCTRINE_ASSUMEE)
      .filter(([n, regles]) => !fichiers.includes(n) || regles.some((r) => !ecartsDoctrine(lire(`supabase/migrations/${n}`)).includes(r)))
      .map(([n]) => n);
    expect(perimees, 'écart corrigé ou fichier disparu : retirer l\'entrée — la liste ne rétrécit que consciemment').toEqual([]);
  });

  it('T6 doctrine SQL des suites tests/sql', () => {
    const suites = readdirSync(new URL('tests/sql/', racine)).filter((n) => n.endsWith('.sql'));
    const ecarts = suites
      .map((n) => [n, ecartsDoctrine(lire(`tests/sql/${n}`))])
      .filter(([, e]) => e.length)
      .map(([n, e]) => `${n} : ${e.map((r) => LIBELLES[r]).join(' ; ')}`);
    expect(ecarts, 'une suite ne crée ses objets éphémères que dans pg_temp (tables et fonctions temporaires), jamais dans public').toEqual([]);
  });

  it('T7 aucun UUID d\'apparence réelle dans tests/sql', () => {
    // Règle 6 du hook (I14, 29/08) : un acteur de test se demande au seed, il ne
    // se prélève pas en base. Tolérés : ceux du seed, et ceux dont les 32 chiffres
    // n'emploient pas plus de 8 caractères distincts (visiblement synthétiques).
    const uuidRe = /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/g;
    const seed = new Set((lire('supabase/seed.sql').match(uuidRe) || []).map((u) => u.toLowerCase()));
    const suspects = [];
    for (const n of readdirSync(new URL('tests/sql/', racine))) {
      const trouves = [...new Set((lire(`tests/sql/${n}`).match(uuidRe) || []).map((u) => u.toLowerCase()))]
        .filter((u) => !seed.has(u) && new Set(u.replace(/-/g, '')).size > 8);
      if (trouves.length) suspects.push(`${n} : ${trouves.join(', ')}`);
    }
    expect(suspects, 'une fixture relevée en production reste une donnée de production : l\'ajouter au seed si elle est synthétique').toEqual([]);
  });

  it('T8 les règles mordent (fixtures en mémoire)', () => {
    expect(ecartsDoctrine('CREATE FUNCTION public.f() RETURNS int LANGUAGE sql SECURITY DEFINER AS $$ select 1 $$;')).toEqual(['R1', 'R2']);
    expect(ecartsDoctrine('CREATE FUNCTION public.f() RETURNS int LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$ select 1 $$; REVOKE EXECUTE ON FUNCTION public.f() FROM PUBLIC;')).toEqual([]);
    expect(ecartsDoctrine('CREATE TABLE public.t (id int);')).toEqual(['R3', 'R5']);
    expect(ecartsDoctrine('CREATE VIEW public.v AS SELECT 1;')).toEqual(['R4']);
    expect(ecartsDoctrine('-- CREATE VIEW public.v AS SELECT 1;')).toEqual([]);
    expect(ecartsDoctrine('CREATE TABLE pg_temp.t (id int); CREATE TEMP TABLE _x (id int);')).toEqual([]);
  });
});
