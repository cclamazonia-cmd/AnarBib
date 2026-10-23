// =====================================================================
// E6, formulaire d'autorité (23/10/2026) — les traductions de la biographie, le
// rattachement aux œuvres et les doublons sortent d'AuthorDraftForm.jsx en
// trois panneaux. Ce test garde : le montage (les deux derniers avec
// key={authorId}, pour repartir de zéro sur une autre autorité), les appels
// dans les panneaux et plus dans le formulaire, aucun panneau qui écrit le
// formulaire (setForm, setMeta, set(), setDraftState), la réexportation des
// titres de biographie, et le formulaire sous 60 Kio.
// =====================================================================
import { describe, it, expect } from 'vitest';
import { readFileSync, statSync } from 'node:fs';
import path from 'node:path';
import { BIO_TITLE_KEYS, ALLOWED_BIO_LANGS } from '@/pages/catalogacao/AuthorDraftForm';

const racine = path.resolve(__dirname, '..', '..');
const lire = (p) => readFileSync(path.join(racine, p), 'utf8');
const FORM = 'src/pages/catalogacao/AuthorDraftForm.jsx';
const PANNEAUX = {
  // (le formulaire lit et amorce encore author_translations — chargement de la
  // fiche, première biographie à l'enregistrement : on garde ici la remise en
  // brouillon d'une traduction modifiée, propre au panneau)
  AuthorBioTranslations: ['set_author_translation_review', "status: 'draft', reviewed_by: null, reviewed_at: null"],
  AuthorBookLinksPanel: ['suggest_author_book_matches', 'confirm_author_book_link'],
  AuthorDuplicatesPanel: ['suggest_author_duplicates', 'merge_author', 'report_authority_pair'],
};

describe('les trois panneaux du formulaire d\'autorité', () => {
  it('le formulaire les monte ; liens et doublons repartent de zéro pour une autre autorité', () => {
    const form = lire(FORM);
    expect(form).toContain("<AuthorBioTranslations authorId={f('published_author_id')}");
    expect(form).toContain("<AuthorBookLinksPanel key={`liens-${f('published_author_id')}`}");
    expect(form).toContain("<AuthorDuplicatesPanel key={`doublons-${f('published_author_id')}`}");
    expect(form).toContain('arbitreDoublons={arbitreDoublons}');
  });
  it('les appels vivent dans les panneaux, plus dans le formulaire', () => {
    const form = lire(FORM);
    for (const [nom, appels] of Object.entries(PANNEAUX)) {
      const src = lire(`src/pages/catalogacao/${nom}.jsx`);
      for (const a of appels) {
        expect(src, `${nom} ${a}`).toContain(a);
        expect(form, a).not.toContain(a);
      }
      // un panneau n'écrit jamais le formulaire ; ses messages remontent par onMessage
      expect(src, nom).not.toMatch(/\bsetForm\(|\bsetMeta\(|\bsetDraftState\(|\bsetMsg\(/);
      expect(src, nom).toContain('onMessage(');
    }
  });
  it('la fusion reste réservée à qui arbitre les doublons', () => {
    expect(lire('src/pages/catalogacao/AuthorDuplicatesPanel.jsx')).toMatch(/\{arbitreDoublons \? \(/);
  });
  it('les titres de biographie se lisent toujours depuis le formulaire', () => {
    expect(ALLOWED_BIO_LANGS.length).toBeGreaterThanOrEqual(11);
    for (const l of ALLOWED_BIO_LANGS) expect(BIO_TITLE_KEYS[l], l).toMatch(/^catalogacao\.bio\.titleIn\./);
  });
  it('le formulaire tient sous 60 Kio (E6)', () => {
    expect(statSync(path.join(racine, FORM)).size).toBeLessThan(60 * 1024);
  });
});
