// =====================================================================
// NUMDIF D15 (15/10/2026) — l'onglet « Candidats PDF », monté avec un faux
// supabase. Session : File de candidats PDF.
//
// Deux candidats pour la notice 86 (Reclus, Harper 1873) : le scan de 1873,
// « même édition », se valide en domaine public avec la justification
// suggérée ; le scan de 1874, « autre édition », ne peut que se rejeter — et
// son motif suggéré porte l'édition trouvée. La notice est à côté de la page
// de titre lue par l'outil.
// =====================================================================
import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, cleanup, waitFor, fireEvent, within } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const LIVRE = { id: 86, titulo: 'The Ocean, Atmosphere, and Life', autor: 'RECLUS, Élisée', editora: 'Harper & Brothers Publishers',
  local_publicacao: 'New York', ano: '1873', bib_ref: 'BTL-TL-000083', idioma: 'en' };
const candidat = (id, annee, verdict) => ({
  id, book_id: 86, library_id: 'bib-1', library_name: 'BTL', status: 'propose', holding: true,
  file_url: `https://archive.org/download/scan${annee}/scan${annee}.pdf`, page_url: `https://archive.org/details/scan${annee}`,
  source_name: 'Internet Archive', found_publisher: 'Harper & Brothers Publishers', found_place: 'New York', found_year: String(annee),
  title_page_number: 6, title_page_text: `— p. 6 —\nHARPER & BROTHERS, PUBLISHERS,\nFRANKLIN SQUARE.\n${annee}.`,
  proposed_verdict: verdict, proposed_case: 'domaine_public', sha256: 'ab'.repeat(32), file_size_bytes: 51164474, page_count: 632,
  tool_notes: { controles: { titre: true, editeur: true, lieu: true, annee: verdict === 'meme_edition' }, avertissements: [], deces: ['Élisée Reclus (†1905)'] },
  destination: { access_scope: 'publico', storage_bucket: 'anarbib-pdf-public' }, book: LIVRE,
});

const rpc = vi.fn(async (nom) => {
  if (nom === 'fn_digital_candidates_list') {
    return { data: { total: 2, counts: { propose: 2 }, candidates: [candidat(1, 1873, 'meme_edition'), candidat(2, 1874, 'autre_edition')] }, error: null };
  }
  if (nom === 'fn_digital_candidate_decide') return { data: { id: 1, status: 'valide' }, error: null };
  return { data: null, error: null };
});
vi.mock('@/lib/supabase', () => ({ supabase: { rpc: (...a) => rpc(...a) }, SUPABASE_URL: 'https://exemple.invalid' }));

const fr = JSON.parse(readFileSync(path.resolve(__dirname, '../i18n/locales/fr.json'), 'utf8'));
const { default: CandidatsPdfPanel } = await import('@/pages/importacoes/CandidatsPdfPanel.jsx');

afterEach(() => { cleanup(); rpc.mockClear(); });
const monter = () => render(<IntlProvider locale="fr" messages={fr}><CandidatsPdfPanel libraryId="bib-1" /></IntlProvider>);

describe('Candidats PDF — l’écran de validation (D15)', () => {
  it('la notice à côté de la page de titre ; « même édition » se valide avec la justification suggérée', async () => {
    monter();
    const cartes = await screen.findAllByTestId('pdf-candidate');
    expect(cartes).toHaveLength(2);
    fireEvent.click(within(cartes[0]).getByRole('button', { name: fr['importacoes.pdfCandidates.examine'] }));
    expect(within(cartes[0]).getByTestId('pdf-candidate-title-page').textContent).toContain('FRANKLIN SQUARE');
    expect(within(cartes[0]).getByText(fr['importacoes.pdfCandidates.notice.title'])).toBeTruthy();
    expect(within(cartes[0]).getByRole('link', { name: fr['importacoes.pdfCandidates.openPdf'] }).getAttribute('href')).toContain('scan1873.pdf');
    const valider = within(cartes[0]).getByTestId('pdf-candidate-validate');
    expect(valider.disabled).toBe(false);
    fireEvent.click(valider);
    await waitFor(() => expect(rpc).toHaveBeenCalledWith('fn_digital_candidate_decide', expect.objectContaining({
      p_id: 1, p_decision: 'valider', p_verdict: 'meme_edition', p_source_case: 'domaine_public',
      p_justification: expect.stringContaining('Élisée Reclus (†1905)'), p_rejection_reason: null,
    })));
    expect(await screen.findByText(fr['importacoes.pdfCandidates.done.validated'])).toBeTruthy();
  });

  it('« autre édition » ne se valide pas ; le motif suggéré porte l’édition trouvée', async () => {
    monter();
    const cartes = await screen.findAllByTestId('pdf-candidate');
    fireEvent.click(within(cartes[1]).getByRole('button', { name: fr['importacoes.pdfCandidates.examine'] }));
    expect(within(cartes[1]).getByTestId('pdf-candidate-validate').disabled).toBe(true);
    expect(within(cartes[1]).getByTestId('pdf-candidate-same-edition-only')).toBeTruthy();
    const motif = within(cartes[1]).getByLabelText(fr['importacoes.pdfCandidates.form.reason']);
    expect(motif.value).toContain('1874');
    fireEvent.click(within(cartes[1]).getByTestId('pdf-candidate-reject'));
    await waitFor(() => expect(rpc).toHaveBeenCalledWith('fn_digital_candidate_decide', expect.objectContaining({
      p_id: 2, p_decision: 'rejeter', p_rejection_reason: expect.stringContaining('1874'), p_justification: null,
    })));
  });
});
