// ═══════════════════════════════════════════════════════════
// AnarBib — l'onglet « Couvertures » : la page 1 des PDF en lot (20/10/2026).
//
// Le VRAI CapasPdfLot, avec le vrai dictionnaire fr, sur un faux Supabase qui
// répond comme api.capas_pdf_* (formes figées par tests/sql/capas_pdf_tests.sql).
// Le rendu pdf.js est remplacé (une toile factice) ; on garde l'ENCHAÎNEMENT :
//   * rien ne s'affiche pour une bibliothèque sans PDF ;
//   * la page 1 est lue par l'adresse PUBLIQUE du PDF, rangée sous un nom neuf
//     `capa-…` dans le dossier de la notice, vignette dérivée, puis la RPC ;
//   * un PDF illisible n'arrête pas la passe et ne revient pas (p_exclure) ;
//   * « deja_une_capa » : le fichier rangé pour rien est retiré ;
//   * un PDF restreint est lu par URL signée (décision du 20/10 : sa page 1
//     devient publique, l'écran l'annonce), et, si elle échoue, par le
//     fichier entier.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { IntlProvider, useIntl } from 'react-intl';
import fr from '@/i18n/locales/fr.json';

const etat = vi.hoisted(() => ({ appels: [], retraits: [], envois: [], reponses: {}, rendus: [], illisibles: new Set(), telecharges: [] }));

vi.mock('@/lib/supabase', () => {
  const rpc = async (nom, args) => {
    etat.appels.push([nom, args]);
    const r = etat.reponses[nom];
    return typeof r === 'function' ? r(args) : (r ?? { data: null, error: null });
  };
  return {
    supabase: {
      schema: () => ({ rpc }),
      storage: {
        from: () => ({
          upload: async (chemin, blob, options) => { etat.envois.push({ chemin, options }); return { data: { path: chemin }, error: null }; },
          remove: async (chemins) => { etat.retraits.push(...chemins); return { error: null }; },
          createSignedUrl: async (chemin) => ({ data: { signedUrl: `https://exemple.test/sign/${chemin}?token=t` }, error: null }),
          download: async (chemin) => { etat.telecharges.push(chemin); return { data: new Blob(['%PDF']), error: null }; },
        }),
      },
    },
  };
});

vi.mock('@/lib/coverThumbs', async (importOriginal) => {
  const vrai = await importOriginal();
  return {
    ...vrai,
    writeCoverThumb: vi.fn(async (p) => `${p}.thumb.jpg`),
    removeCoverThumb: vi.fn(async (p) => { etat.retraits.push(`${p}.thumb.jpg`); }),
  };
});

vi.mock('@/lib/capaPdf', async (importOriginal) => {
  const vrai = await importOriginal();
  return {
    ...vrai,
    urlPdfPublic: (chemin) => `https://exemple.test/public/anarbib-pdf-public/${chemin}`,
    rendrePage1: vi.fn(async (source) => {
      etat.rendus.push(source);
      if (source?.url && [...etat.illisibles].some((c) => source.url.includes(c))) throw new Error('Invalid PDF structure');
      return { width: 800, height: 1131 };
    }),
    canvasEnJpeg: vi.fn(async () => new Blob(['jpeg'], { type: 'image/jpeg' })),
  };
});

vi.mock('@/lib/localizeError', () => ({ localizeError: (e) => String(e?.message || e) }));

import CapasPdfLot from '@/pages/painel/tabs/CapasPdfLot.jsx';

const LIB = '1bb157fd-4d1f-415b-9e5d-490f4f8d0895';
const MAAGD = { book_id: 2751, bib_ref: 'ANARCHIEF-21156', titulo: 'De Roode Maagd', storage_bucket: 'anarbib-pdf-public', storage_path: 'books/2751/maagd.pdf' };
const LUIS = { book_id: 2752, bib_ref: 'ANARCHIEF-362', titulo: 'De libertaire luis', storage_bucket: 'anarbib-pdf-public', storage_path: 'books/2752/luis.pdf' };
const RESERVE = { book_id: 2790, bib_ref: 'ANARCHIEF-900', titulo: 'Overige', storage_bucket: 'pdf-restrito', storage_path: 'books/2790/overige.pdf' };

// La liste rend ce qui n'est ni posé ni exclu : comme la vraie RPC.
function parDefaut({ resume = { faisables: 2, restreintes: 40, posees: 0 }, poser = 'posee', notices = [MAAGD, LUIS] } = {}) {
  const posees = new Set();
  etat.reponses = {
    capas_pdf_resume: { data: resume, error: null },
    capas_pdf_liste: (a) => ({
      data: notices.filter((n) => !posees.has(n.book_id) && !(a.p_exclure || []).includes(n.book_id)),
      error: null,
    }),
    capas_pdf_poser: (a) => {
      const statut = typeof poser === 'function' ? poser(a) : poser;
      if (statut === 'posee' || statut === 'deja_une_capa') posees.add(a.p_book_id);
      return { data: statut, error: null };
    },
  };
}

function AvecIntl({ onPosees, lib = LIB, admin = false }) {
  const { formatMessage } = useIntl();
  return <CapasPdfLot t={formatMessage} libraryId={lib} isNetworkAdmin={admin} onPosees={onPosees} />;
}
const rendre = (onPosees = vi.fn(), opts = {}) => render(<IntlProvider locale="fr" messages={fr}><AvecIntl onPosees={onPosees} {...opts} /></IntlProvider>);
const appels = (nom) => etat.appels.filter(([n]) => n === nom).map(([, a]) => a);

beforeEach(() => {
  etat.appels = []; etat.retraits = []; etat.envois = []; etat.rendus = []; etat.illisibles = new Set(); etat.telecharges = [];
  parDefaut();
});

describe('CapasPdfLot — l’administration du réseau choisit la bibliothèque', () => {
  const BLMF = 'b1af0000-0000-4000-8000-000000000001';

  it('un compte sans administration réseau ne demande pas la liste', async () => {
    rendre();
    await screen.findByRole('button', { name: 'Poser la page 1 comme couverture (2)' });
    expect(appels('capas_pdf_bibliotheques')).toHaveLength(0);
    expect(document.querySelector('[data-capas-pdf-choix]')).toBeNull();
  });

  it('depuis BLMF, l’admin réseau prend Anarchief et la passe porte sur Anarchief', async () => {
    parDefaut();
    const resumeAnarchief = etat.reponses.capas_pdf_resume;
    etat.reponses.capas_pdf_resume = (a) => (a.p_library_id === LIB ? resumeAnarchief : { data: { faisables: 0, restreintes: 0, posees: 2 }, error: null });
    etat.reponses.capas_pdf_bibliotheques = { data: [{ library_id: LIB, nom: 'Anarchief.Org', faisables: 612, restreintes: 40 }], error: null };
    const onPosees = vi.fn();
    rendre(onPosees, { lib: BLMF, admin: true });

    const choix = await waitFor(() => { const el = document.querySelector('[data-capas-pdf-choix]'); expect(el).not.toBeNull(); return el; });
    expect([...choix.options].map((o) => o.textContent)).toEqual(['Bibliothèque courante du Painel', 'Anarchief.Org — 612 notices']);
    fireEvent.change(choix, { target: { value: LIB } });
    fireEvent.click(await screen.findByRole('button', { name: 'Poser la page 1 comme couverture (2)' }));
    await screen.findByText('Terminé : 2 couvertures posées, 0 PDF illisible.');

    expect(appels('capas_pdf_liste').every((a) => a.p_library_id === LIB)).toBe(true);
    // Les couvertures posées ne sont pas celles de la bibliothèque du Painel : sa liste photo ne bouge pas.
    expect(onPosees).not.toHaveBeenCalled();
  });
});

describe('CapasPdfLot — la page 1 des PDF en lot', () => {
  it('rien pour une bibliothèque sans PDF', async () => {
    parDefaut({ resume: { faisables: 0, restreintes: 0, posees: 0 } });
    const { container } = rendre();
    await waitFor(() => expect(appels('capas_pdf_resume')).toHaveLength(1));
    expect(container.querySelector('[data-capas-pdf]')).toBeNull();
  });

  it('annonce les faisables, et parmi elles celles dont la page 1 deviendra publique', async () => {
    rendre();
    expect(await screen.findByRole('button', { name: 'Poser la page 1 comme couverture (2)' })).toBeTruthy();
    expect(screen.getByText('Parmi elles, 40 n’ont qu’un PDF à diffusion restreinte : leur page 1 deviendra une image publique.')).toBeTruthy();
  });

  it('un PDF restreint se lit par URL signée ; si elle échoue, par le fichier entier', async () => {
    parDefaut({ resume: { faisables: 1, restreintes: 1, posees: 0 }, notices: [RESERVE] });
    rendre();
    fireEvent.click(await screen.findByRole('button', { name: 'Poser la page 1 comme couverture (1)' }));
    await screen.findByText('Terminé : 1 couverture posée, 0 PDF illisible.');
    expect(etat.rendus).toEqual([{ url: 'https://exemple.test/sign/books/2790/overige.pdf?token=t' }]);
    expect(etat.telecharges).toEqual([]);

    // Seconde passe : l'URL signée ne se lit pas -> repli sur l'API Storage.
    etat.rendus = [];
    etat.illisibles.add('/sign/');
    parDefaut({ resume: { faisables: 1, restreintes: 1, posees: 0 }, notices: [RESERVE] });
    fireEvent.click(await screen.findByRole('button', { name: 'Poser la page 1 comme couverture (1)' }));
    await waitFor(() => expect(etat.telecharges).toEqual(['books/2790/overige.pdf']));
    expect(etat.rendus[1]).toBeInstanceOf(ArrayBuffer);
  });

  it('pose la page 1 de chaque notice : adresse publique, nom neuf dans le dossier, puis la RPC', async () => {
    const onPosees = vi.fn();
    rendre(onPosees);
    fireEvent.click(await screen.findByRole('button', { name: 'Poser la page 1 comme couverture (2)' }));
    await screen.findByText('Terminé : 2 couvertures posées, 0 PDF illisible.');

    expect(etat.rendus.map((s) => s.url)).toEqual([
      'https://exemple.test/public/anarbib-pdf-public/books/2751/maagd.pdf',
      'https://exemple.test/public/anarbib-pdf-public/books/2752/luis.pdf',
    ]);
    expect(etat.envois).toHaveLength(2);
    expect(etat.envois[0].chemin).toMatch(/^books\/ANARCHIEF-21156\/capa-[a-z0-9]+\.jpg$/);
    expect(etat.envois[0].options).toEqual({ contentType: 'image/jpeg', upsert: false });
    const poses = appels('capas_pdf_poser');
    expect(poses.map((a) => a.p_book_id)).toEqual([2751, 2752]);
    expect(poses[0].p_object_path).toBe(etat.envois[0].chemin);
    expect(etat.retraits).toEqual([]);
    expect(onPosees).toHaveBeenCalledTimes(1);
  });

  it('un PDF illisible n’arrête pas la passe et n’est pas redemandé', async () => {
    etat.illisibles.add('maagd.pdf');
    rendre();
    fireEvent.click(await screen.findByRole('button', { name: 'Poser la page 1 comme couverture (2)' }));
    await screen.findByText('Terminé : 1 couverture posée, 1 PDF illisible.');

    expect(appels('capas_pdf_poser').map((a) => a.p_book_id)).toEqual([2752]);
    expect(etat.envois).toHaveLength(1);
    // La liste suivante écarte la notice ratée : la passe ne tourne pas sur place.
    expect(appels('capas_pdf_liste').at(-1).p_exclure).toEqual([2751]);
    expect(screen.getByText('1 PDF non rendu (fichier illisible ou injoignable)')).toBeTruthy();
  });

  it('une couverture arrivée entre-temps gagne : le fichier rangé pour rien est retiré', async () => {
    parDefaut({ poser: (a) => (a.p_book_id === 2751 ? 'deja_une_capa' : 'posee') });
    rendre();
    fireEvent.click(await screen.findByRole('button', { name: 'Poser la page 1 comme couverture (2)' }));
    await screen.findByText('Terminé : 1 couverture posée, 0 PDF illisible.');
    const premier = etat.envois[0].chemin;
    expect(etat.retraits).toEqual([premier, `${premier}.thumb.jpg`]);
  });
});
