// @vitest-environment node
//
// D27 (20/10/2026) — la limite d'un versement par le serveur se dit avant l'essai.
//
// deposit-digital-candidate meurt à 2 s de CPU (HTTP 546) vers 150-180 Mo de
// PDF : l'appel s'arrêtait en route, sans refus noté ni message, un objet
// partiel laissé dans la zone privée — alors que les seaux acceptent 500 Mo et
// que l'écran annonçait « 150 Mo au plus ». Désormais une seule limite,
// LIMITE_APPEL (140 Mo), dite par l'écran avant l'appel et tenue par la
// fonction AVANT le téléchargement (taille relevée, taille annoncée), puis en
// flux. Ce banc garde l'accord des trois.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const RACINE = path.resolve(__dirname, '../..');
const lire = (rel) => readFileSync(path.join(RACINE, rel), 'utf8');
const EF = lire('supabase/functions/deposit-digital-candidate/index.ts');
const ECRAN = lire('src/pages/importacoes/CandidatsPdfPanel.jsx');
const LOCALES = ['fr', 'pt-BR', 'es', 'it', 'en', 'de', 'ca', 'eo', 'nl', 'el', 'ro'];

const valeur = (src, nom) => {
  const m = src.match(new RegExp(`${nom} = (\\d+) \\* 1000 \\* 1000;`));
  return m ? Number(m[1]) : null;
};

describe('D27 — une seule limite par appel, dite avant l’essai', () => {
  it('la fonction et l’écran portent la même limite, 140 Mo', () => {
    expect(valeur(EF, 'LIMITE_APPEL')).toBe(140);
    expect(valeur(ECRAN, 'LIMITE_VERSEMENT_SERVEUR')).toBe(140);
  });

  it('la fonction refuse sur la taille relevée AVANT de télécharger', () => {
    const iRelevee = EF.indexOf('if (relevee > LIMITE_APPEL)');
    expect(iRelevee).toBeGreaterThan(0);
    expect(iRelevee).toBeLessThan(EF.indexOf('fetchSortant(g.file_url'));
    expect(EF).toContain('Number(g.file_size_bytes)');
  });

  it('la taille annoncée par la source et le flux s’arrêtent à la même limite, refus noté', () => {
    expect(EF).toContain('if (annonce > LIMITE_APPEL)');
    expect(EF).toContain('lu > Math.min(MAX_OCTETS, LIMITE_APPEL)');
    const tropLourd = EF.slice(EF.indexOf('const tropLourd'), EF.indexOf('// D27 : la taille relevée'));
    expect(tropLourd).toContain('noterEchec(');
    expect(tropLourd).toContain("'file_too_large'");
  });

  it('l’écran le dit avant l’appel et ne propose pas le bouton', () => {
    expect(ECRAN).toContain('Number(c.file_size_bytes) > LIMITE_VERSEMENT_SERVEUR');
    expect(ECRAN).toContain("'importacoes.pdfCandidates.deposit.tooLarge'");
    expect(ECRAN).toContain('disabled={occupe || tropLourd}');
  });

  it('les onze langues disent la même limite, et la clé neuve existe partout', () => {
    for (const l of LOCALES) {
      const d = JSON.parse(lire(`src/i18n/locales/${l}.json`));
      expect(d['error.edge.file_too_large'], l).toContain('140');
      expect(d['error.edge.file_too_large'], l).not.toContain('150');
      expect(d['importacoes.pdfCandidates.deposit.tooLarge'], l).toMatch(/\{size\}[\s\S]*\{max\}/);
    }
  });
});
