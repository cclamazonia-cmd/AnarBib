// =====================================================================
// NUMDIF D16 (16/10/2026) — le nom de fichier d'un PDF versé
// (supabase/functions/deposit-digital-candidate/nom.ts) ne produit jamais
// un chemin que la garde anti-traversée de
// ingest.fn_digital_candidate_deposit_record refuse (« .. », LIKE '%..%').
// Le 15/10, quatre candidats aux noms à points de suspension étaient refusés.
// Noms inventés : aucun contenu de source réelle.
// Session : File de candidats PDF.
// =====================================================================
import { describe, it, expect } from 'vitest';
import { sanitize } from '../../supabase/functions/deposit-digital-candidate/nom.ts';

// le chemin tel que index.ts le construit, et la condition de la garde SQL
const chemin = (nom) => `books/42/1760000000000_${sanitize(nom)}`;
const refuseParLaGarde = (p) => p.includes('..');

describe('sanitize — noms à points', () => {
  it.each([
    ['rapport_final....pdf', 'rapport_final.pdf'],
    ['bulletin_2001-1-1_..pdf', 'bulletin_2001-1-1_.pdf'],
    ['Essai..._suite_texte.pdf', 'Essai._suite_texte.pdf'],
    ['a.b..c...d.PDF', 'a.b.c.d.pdf'],
    ['....pdf', 'candidat.pdf'],
    ['..', 'candidat.pdf'],
    ['../../etc/passwd', '._._etc_passwd.pdf'],
  ])('%s → %s', (entree, attendu) => {
    expect(sanitize(entree)).toBe(attendu);
    expect(refuseParLaGarde(chemin(entree))).toBe(false);
  });

  it('une coupe à 100 caractères qui tombe sur un point ne laisse pas « base. » + « .pdf »', () => {
    const nom = `${'x'.repeat(99)}.suite.pdf`;
    expect(sanitize(nom)).toBe(`${'x'.repeat(99)}.pdf`);
    expect(refuseParLaGarde(chemin(nom))).toBe(false);
  });

  it('les noms ordinaires ne changent pas de forme', () => {
    expect(sanitize('Auteur,_Prenom_-_Un_titre_(1977)001.pdf')).toBe('Auteur_Prenom_-_Un_titre_1977_001.pdf');
    expect(sanitize('Pensée_et_action.pdf')).toBe('Pensee_et_action.pdf');
    expect(sanitize('')).toBe('candidat.pdf');
    expect(sanitize(null)).toBe('candidat.pdf');
  });

  it('aucun nom, même hostile, ne produit « .. » ni « / »', () => {
    const morceaux = ['.', '..', '...', '_', '-', '/', '\\', 'a', 'é', ' ', '.pdf'];
    for (let i = 0; i < 2000; i++) {
      let nom = '';
      for (let k = 0; k < 1 + (i % 12); k++) nom += morceaux[(i * 7 + k * 13) % morceaux.length];
      const p = sanitize(nom);
      expect(p.includes('..'), JSON.stringify(nom)).toBe(false);
      expect(p.includes('/'), JSON.stringify(nom)).toBe(false);
      expect(p.endsWith('.pdf')).toBe(true);
    }
  });
});
