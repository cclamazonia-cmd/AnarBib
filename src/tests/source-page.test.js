// CHEMIN DÉPÔT : src/tests/source-page.test.js
//
// 15/10/2026 — D17 (REGISTRE §47, NUMDIF-3) : qui lit la copie restreinte voit
// le lien vers la PAGE de la copie d'origine, jamais vers le fichier. Pour
// Archive.org, la page se déduit du fichier ; ailleurs elle se saisit.

import { describe, it, expect } from 'vitest';
import { archiveOrgPage, sourceLabel } from '@/lib/sourcePage';

describe('archiveOrgPage — la page Archive.org d un fichier Archive.org', () => {
  it('fichier servi par un nœud de stockage', () => {
    expect(archiveOrgPage('https://dn720005.ca.archive.org/0/items/kropotkin-piotr.-el-apoyo-mutuo.-un-factor-de-evolucion-ocr-2020/Kropotkin%2C%20Piotr.pdf'))
      .toBe('https://archive.org/details/kropotkin-piotr.-el-apoyo-mutuo.-un-factor-de-evolucion-ocr-2020');
  });

  it('lien de téléchargement et fiche déjà donnée', () => {
    expect(archiveOrgPage('https://archive.org/download/lesvangiles0000prou/lesvangiles0000prou.pdf'))
      .toBe('https://archive.org/details/lesvangiles0000prou');
    expect(archiveOrgPage('https://archive.org/details/oceanatmospherel00recl'))
      .toBe('https://archive.org/details/oceanatmospherel00recl');
  });

  it('ailleurs qu Archive.org : rien à déduire', () => {
    expect(archiveOrgPage('https://www.anarquista.net/wp-content/uploads/2013/04/x.pdf')).toBeNull();
    expect(archiveOrgPage('https://notarchive.org.example/details/x')).toBeNull();
    expect(archiveOrgPage('')).toBeNull();
    expect(archiveOrgPage(null)).toBeNull();
  });
});

describe('sourceLabel — le nom montré pour « aussi en ligne »', () => {
  it('le nom saisi d abord', () => {
    expect(sourceLabel('Internet Archive', 'https://archive.org/details/x')).toBe('Internet Archive');
  });

  it('sans nom : l hôte de la page, sans www', () => {
    expect(sourceLabel(null, 'https://pdfcoffee.com/a-anarquia-perante-os-tribunais-pdf-free.html')).toBe('pdfcoffee.com');
    expect(sourceLabel('  ', 'https://www.anarquista.net/ajuda-mutua/')).toBe('anarquista.net');
  });

  it('ni nom ni adresse lisible : rien', () => {
    expect(sourceLabel('', 'pas une adresse')).toBe('');
    expect(sourceLabel(null, null)).toBe('');
  });
});
