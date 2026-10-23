// AnarBib — le texte d'auteur d'un brouillon suit ses contributeurs DANS l'envoi (18/10/2026).
// Vu par Xavier : « Casamento Indissolúvel… » (BTL-TL-000674), ses auteurs remplacés par
// Wilhelm Reich, restait trouvée par « Auteur : kropotkin » au catalogue. Le formulaire envoyait
// le texte d'auteur d'avant et ne le recomposait qu'après l'enregistrement ; la publication le
// recopiait sur la notice. Garde de source : la recomposition précède la charge utile, et la
// charge utile la porte.
import { describe, it, expect } from 'vitest';
// E6 (23/10/2026) : le formulaire de notice se lit avec son hook et ses sections (sourceNotice).
import { sourceNotice } from './helpers/noticeSource';

const src = sourceNotice();
const save = src.slice(src.indexOf('async function handleSave('), src.indexOf('async function handleSave(') + 9000);

describe('le texte d\'auteur suit les contributeurs à l\'enregistrement', () => {
  it('il est recomposé AVANT la charge utile, et la charge utile le porte', () => {
    const recompose = save.indexOf('const autorDesContributeurs = contributors');
    const charge = save.indexOf('const payload = {');
    expect(recompose).toBeGreaterThan(-1);
    expect(charge).toBeGreaterThan(recompose);
    expect(save).toContain("autor: autorDesContributeurs || f('autor') || null,");
    expect(save).not.toMatch(/\n\s+autor: f\('autor'\) \|\| null,/);
  });

  it('même règle que l\'écran : les contributeurs nommés, dans l\'ordre, séparés par « ; »', () => {
    const corps = save.slice(save.indexOf('const autorDesContributeurs'), save.indexOf('const payload = {'));
    expect(corps).toContain(".filter((c) => (c.name || '').trim())");
    expect(corps).toContain(".join(' ; ')");
    expect(src).toContain("set('autor', named.map(c => c.name.trim()).join(' ; '));");
  });
});
