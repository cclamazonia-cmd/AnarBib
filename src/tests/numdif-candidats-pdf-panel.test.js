// =====================================================================
// NUMDIF D15 (15/10/2026, REGISTRE §47 NUMDIF-1, 2, 5) — l'onglet « Candidats
// PDF » de la page Importations. Session : File de candidats PDF.
//
// La portée (une autre bibliothèque ne voit rien) est tenue par la base et
// gardée par tests/sql/numdif_file_candidats_tests.sql ; ici, ce que l'écran
// doit tenir de son côté : il lit le fichier de l'outil D14, il ne valide
// qu'une même édition, il demande la mention et sa page pour une licence
// libre, il parle toutes les locales servies.
// =====================================================================
import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { lireFichierCandidats, justificationSuggeree, CAS, CAS_LICENCE, STATUTS, VERDICTS } from '@/pages/importacoes/CandidatsPdfPanel.jsx';

const RACINE = path.resolve(__dirname, '../..');
const lire = (rel) => readFileSync(path.join(RACINE, rel), 'utf8');
const PANNEAU = lire('src/pages/importacoes/CandidatsPdfPanel.jsx');
const PAGE = lire('src/pages/importacoes/ImportacoesPage.jsx');
const LOC = path.join(RACINE, 'src/i18n/locales');
const locales = readdirSync(LOC).filter((f) => f.endsWith('.json')).map((f) => [f, JSON.parse(readFileSync(path.join(LOC, f), 'utf8'))]);
const t = ({ id }, v = {}) => `${id}|${Object.entries(v).map(([k, x]) => `${k}=${x}`).join(',')}`;

describe('le fichier de l’outil D14', () => {
  it('se range par bibliothèque détentrice, la bibliothèque active à défaut', () => {
    const f = JSON.stringify({ candidates: [
      { book_id: 1, library_id: 'A', file_url: 'https://x/1.pdf' },
      { book_id: 2, file_url: 'https://x/2.pdf' },
    ] });
    const m = lireFichierCandidats(f, 'B');
    expect([...m.keys()].sort()).toEqual(['A', 'B']);
    expect(m.get('B')[0].book_id).toBe(2);
  });
  it('un fichier mal formé ou vide est refusé avec une clé traduite', () => {
    expect(() => lireFichierCandidats('pas du json', 'A')).toThrow('error.digital_candidate.bad_payload');
    expect(() => lireFichierCandidats('{"candidates": []}', 'A')).toThrow('error.digital_candidate.bad_payload');
    expect(() => lireFichierCandidats('[{"book_id": 1}]', null)).toThrow('importacoes.pdfCandidates.import.noLibrary');
  });
});

describe('la justification suggérée suit le cas', () => {
  const c = { library_name: 'BTL', book: { bib_ref: 'BTL-TL-000083' }, tool_notes: { deces: ['Élisée Reclus (†1905)'] },
    proposed_mention: 'permitida y alentada por los editores', proposed_mention_page: '4' };
  it('domaine public : les décès', () => expect(justificationSuggeree(c, 'domaine_public', t)).toContain('Élisée Reclus (†1905)'));
  it('licence libre : la mention et sa page', () => {
    const j = justificationSuggeree(c, 'anti_copyright', t);
    expect(j).toContain('page=4');
    expect(j).toContain('alentada');
  });
  it('statut inconnu : l’exemplaire détenu et sa cote', () => expect(justificationSuggeree(c, 'statut_inconnu', t)).toContain('BTL-TL-000083'));
});

describe('ce que l’écran tient de son côté', () => {
  it('passe par les trois portes de la file, et par aucune table', () => {
    for (const rpc of ['fn_digital_candidates_list', 'fn_digital_candidates_propose', 'fn_digital_candidate_decide']) {
      expect(PANNEAU).toContain(`supabase.rpc('${rpc}'`);
    }
    expect(PANNEAU).not.toMatch(/supabase\s*\.\s*(from|schema)\(/);
  });
  it('NUMDIF-1 : le bouton « valider » ne s’ouvre qu’à la même édition', () => {
    expect(PANNEAU).toMatch(/disabled=\{occupe \|\| verdict !== 'meme_edition'\}/);
  });
  it('NUMDIF-2 : mention et page demandées pour les deux cas de licence libre', () => {
    expect([...CAS_LICENCE].sort()).toEqual(['anti_copyright', 'diffusion_autorisee']);
    expect(PANNEAU).toContain('p_rights_mention_page: CAS_LICENCE.has(cas) ? mentionPage : null');
  });
  it('l’onglet est branché sur la page Importations (#tab=pdf)', () => {
    expect(PAGE).toContain("import CandidatsPdfPanel from './CandidatsPdfPanel.jsx';");
    expect(PAGE).toContain("['export', 'pdf'].includes(initialHash)");
    expect(PAGE).toContain("{sentido === 'pdf' && <CandidatsPdfPanel libraryId={libraryId} />}");
  });
});

describe('toutes les locales servies (DOC-I18N-1)', () => {
  const statiques = [...PANNEAU.matchAll(/id: '([a-zA-Z.]+)'/g)].map((m) => m[1]);
  const dynamiques = [
    ...CAS.flatMap((x) => [`case.${x}`, `caseHint.${x}`]), ...STATUTS.map((x) => `status.${x}`),
    ...VERDICTS.map((x) => `verdict.${x}`),
    ...['titre', 'editeur', 'lieu', 'annee', 'traduction', 'isbn'].map((x) => `control.${x}`),
    ...['sans_couche_texte', 'isbn_different', 'titre_peu_trouve', 'lieu_absent_de_la_notice', 'traduction_a_verifier'].map((x) => `warning.${x}`),
  ].map((k) => `importacoes.pdfCandidates.${k}`);
  const cles = [...new Set([...statiques, ...dynamiques, 'importacoes.sentido.pdf'])];
  for (const [f, j] of locales) {
    it(`${f} : chaque clé de l’écran a son libellé`, () => {
      expect(cles.filter((k) => typeof j[k] !== 'string' || !j[k])).toEqual([]);
    });
  }
});
