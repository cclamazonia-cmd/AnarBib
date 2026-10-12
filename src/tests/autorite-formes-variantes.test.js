// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/autorite-formes-variantes.test.js
//
// CE QUE CE TEST PROTÈGE (AUT-VAR, 12/10/2026).
// Les graphies d'une autorité (variant_forms : Wikidata par langue, fusions)
// étaient effacées sans bruit : le formulaire ne les rechargeait pas en
// rouvrant une fiche, renvoyait NULL à l'enregistrement, et publish_author_draft
// réécrivait la fiche entière. Quatre autorités y ont perdu les leurs. Et même
// présentes, « Rattacher aux œuvres » ne les lisait pas, pas plus que le champ
// « Formes variantes » saisi à la main. Le comportement est éprouvé au banc
// (tests/sql/aut_var_formes_variantes_tests.sql) ; ici, les points de source
// qu'un remaniement pourrait défaire sans qu'aucun écran ne le montre.

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const RACINE = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');

function derniereDefinition(schema, nom) {
  const dossier = path.join(RACINE, 'supabase', 'migrations');
  const fichiers = readdirSync(dossier).filter((f) => f.endsWith('.sql') && !f.startsWith('_')).sort();
  for (let i = fichiers.length - 1; i >= 0; i--) {
    const sql = readFileSync(path.join(dossier, fichiers[i]), 'utf8');
    const m = sql.match(new RegExp(`CREATE OR REPLACE FUNCTION ${schema}\\.${nom}\\([\\s\\S]*?\\$function\\$;`, 'i'));
    if (m) return { fichier: fichiers[i], corps: m[0] };
  }
  throw new Error(`${schema}.${nom} introuvable dans les migrations`);
}

describe('formes variantes des autorités — gardées et lues', () => {
  it('le formulaire recharge variant_forms et le renvoie tel quel', () => {
    const src = lire('src/pages/catalogacao/AuthorDraftForm.jsx');
    expect(src).toContain('variant_forms: r.variant_forms || null');
    expect(src).toContain('variant_forms: form.variant_forms || null');
  });

  it('publier un brouillon sans graphies garde celles de l autorité', () => {
    const { corps } = derniereDefinition('public', 'publish_author_draft');
    expect(corps).toMatch(/variant_forms = coalesce\(v_draft\.variant_forms, variant_forms\)/);
  });

  it('« Rattacher aux œuvres » lit toutes les formes de l autorité', () => {
    const { corps } = derniereDefinition('public', 'suggest_author_book_matches');
    expect(corps).toContain('private.fn_formes_d_un_auteur(p_author_id)');
    const aide = derniereDefinition('private', 'fn_formes_d_un_auteur').corps;
    expect(aide).toContain("'variantNames'");
    expect(aide).toContain("'pseudonyms'");
    expect(aide).toContain('jsonb_each');
    expect(aide).toContain("e->>'form'");
  });

  it('les deux détections de doublons reconnaissent un identifiant commun (DEDUP-6)', () => {
    expect(derniereDefinition('public', 'suggest_author_duplicates').corps).toContain('meme_id');
    expect(derniereDefinition('public', 'suggest_authority_duplicates').corps).toContain('meme_ident');
  });
});
