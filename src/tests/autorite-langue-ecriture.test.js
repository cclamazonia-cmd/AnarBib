// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/autorite-langue-ecriture.test.js
//
// CE QUE CE TEST PROTÈGE (26/09/2026).
// `authors.writing_language` vit en quatre endroits : la table et le brouillon
// (migration 20260926191225), les deux fonctions de recopie, le formulaire
// (chargement, enregistrement, champ) et la page publique. Le défaut à craindre
// n'est pas la panne mais l'effacement silencieux : un brouillon qui ne recopie
// pas la colonne la remet à NULL à la publication suivante (publish_author_draft
// réécrit la fiche entière), et l'enrichissement du 26/09 disparaîtrait à la
// première correction d'une virgule.

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const RACINE = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');

function derniereDefinition(nom) {
  const dossier = path.join(RACINE, 'supabase', 'migrations');
  const fichiers = readdirSync(dossier).filter((f) => f.endsWith('.sql')).sort();
  for (let i = fichiers.length - 1; i >= 0; i--) {
    const sql = readFileSync(path.join(dossier, fichiers[i]), 'utf8');
    const m = sql.match(new RegExp(`CREATE OR REPLACE FUNCTION public\\.${nom}\\([\\s\\S]*?\\$function\\$;`, 'i'));
    if (m) return { fichier: fichiers[i], corps: m[0] };
  }
  throw new Error(`${nom} introuvable dans les migrations`);
}

describe('langue d écriture des autorités — la colonne suit partout', () => {
  it('publish_author_draft la recopie à l insertion ET à la mise à jour', () => {
    const { corps } = derniereDefinition('publish_author_draft');
    expect(corps).toMatch(/structured_meta, writing_language,/);
    expect(corps).toMatch(/v_draft\.writing_language,/);
    expect(corps).toMatch(/writing_language = v_draft\.writing_language/);
  });

  it('create_author_draft_from_author la recopie vers le brouillon', () => {
    const { corps } = derniereDefinition('create_author_draft_from_author');
    expect(corps).toMatch(/structured_meta, writing_language,/);
    expect(corps).toMatch(/a\.writing_language/);
  });

  it('le formulaire la charge, l enregistre et la propose au référentiel des notices', () => {
    const src = lire('src/pages/catalogacao/AuthorDraftForm.jsx');
    expect(src).toContain("writing_language: r.writing_language || ''");
    expect(src).toContain("writing_language: f('writing_language') || null");
    expect(src).toContain('languageOptions(t)');
  });

  it('la page publique affiche un libellé, jamais le code brut', () => {
    const src = lire('src/pages/public/AuthorPage.jsx');
    expect(src).toContain('languageLabel(author.writing_language, t)');
  });
});
