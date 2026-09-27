// ═══════════════════════════════════════════════════════════
// AnarBib — l'onglet « Couvertures » du Painel : la photo prise en rayon (27/09/2026).
//
// Le VRAI TabCapas, avec le vrai dictionnaire fr, sur un faux Supabase qui
// répond comme api.capas_photo_* (formes figées par tests/sql/capas_photo_tests.sql).
// La préparation de la photo (toile, EXIF) est remplacée : elle a son banc à
// elle (photo-capa.test.js) ; ici on garde l'ENCHAÎNEMENT :
//   * retrouver la notice — liste de campagne, recherche, scan d'étiquette ;
//   * la photo préparée d'abord, rangée sous un nom neuf `photo-…` dans le
//     dossier de la notice, vignette dérivée, puis la RPC ;
//   * une couverture présente n'est remplacée que si l'écran l'a annoncé ;
//     « deja_une_capa » ou refus : le fichier rangé pour rien est retiré ;
//   * après une pose, la notice suivante est prise : la campagne avance.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { IntlProvider, useIntl } from 'react-intl';
import fr from '@/i18n/locales/fr.json';

const etat = vi.hoisted(() => ({ appels: [], retraits: [], envois: [], reponses: {} }));

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
          upload: async (chemin, blob, options) => { etat.envois.push({ chemin, blob, options }); return etat.reponses.upload ?? { data: { path: chemin }, error: null }; },
          remove: async (chemins) => { etat.retraits.push(...chemins); return { error: null }; },
        }),
      },
    },
  };
});

vi.mock('@/lib/coverThumbs', () => ({
  COVER_BUCKET: 'covers',
  writeCoverThumb: vi.fn(async (p) => `${p}.thumb.jpg`),
  removeCoverThumb: vi.fn(async (p) => { etat.retraits.push(`${p}.thumb.jpg`); }),
}));

// La photo « préparée » : un Blob reconnaissable, et le quart de tour noté.
vi.mock('@/lib/photoCapa', async (importOriginal) => {
  const vrai = await importOriginal();
  return {
    ...vrai,
    preparerPhoto: vi.fn(async (fichier, quarts) => new Blob([`prepare:${fichier.name}:${quarts}`], { type: 'image/jpeg' })),
  };
});

// Le scanner : un bouton qui « lit » l'étiquette d'un exemplaire.
vi.mock('@/pages/painel/tabs/CardScanner', () => ({
  default: ({ onScan }) => <button type="button" onClick={() => onScan('https://app.anarbib.is/livro/447?ex=9001')}>lire l’étiquette</button>,
}));

vi.mock('@/lib/localizeError', () => ({ localizeError: (e) => String(e?.message || e) }));

import TabCapas from '@/pages/painel/tabs/TabCapas.jsx';
import { preparerPhoto } from '@/lib/photoCapa';
import { writeCoverThumb } from '@/lib/coverThumbs';

const LIB = '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
const CONQUISTA = { book_id: 447, bib_ref: 'BTL-TL-000447', titulo: 'A Conquista do Pão', subtitulo: null, autor: 'Kropotkin, Piotr',
  editora: 'Guimarães', ano: '1975', volume: null, isbn: null, tombos: ['BTL-TL-EX-000447'], a_une_capa: false };
const DEUS = { book_id: 448, bib_ref: 'BTL-TL-000448', titulo: 'Deus e o Estado', subtitulo: null, autor: 'Bakunin, Mikhail',
  editora: 'Imaginário', ano: '2000', volume: null, isbn: null, tombos: ['BTL-TL-EX-000448'], a_une_capa: false };
const COUVERT = { ...DEUS, book_id: 500, bib_ref: 'BTL-TL-000500', titulo: 'Já coberto', tombos: ['BTL-TL-EX-000500'], a_une_capa: true };

function reponsesParDefaut() {
  etat.reponses = {
    capas_photo_resume: { data: { sans_capa: 2094, photographiees: 0, total: 2363 }, error: null },
    capas_photo_liste: (a) => ({ data: a.p_recherche ? [DEUS] : [CONQUISTA, DEUS], error: null }),
    capas_photo_poser: { data: 'posee', error: null },
  };
}

// Le composant reçoit `t` du Painel (formatMessage) : on lui donne le vrai.
function AvecIntl() { const { formatMessage } = useIntl(); return <TabCapas t={formatMessage} libraryId={LIB} />; }
const rendreIntl = () => render(<IntlProvider locale="fr" messages={fr}><AvecIntl /></IntlProvider>);

const appels = (nom) => etat.appels.filter(([n]) => n === nom).map(([, a]) => a);
const photographier = (conteneur, nom = 'IMG_0001.jpg') => {
  const entree = conteneur.querySelector('[data-capas-entree]');
  fireEvent.change(entree, { target: { files: [new File(['x'], nom, { type: 'image/jpeg' })] } });
};

beforeEach(() => {
  etat.appels = []; etat.retraits = []; etat.envois = [];
  reponsesParDefaut();
  vi.mocked(preparerPhoto).mockClear();
  vi.mocked(writeCoverThumb).mockClear();
  globalThis.URL.createObjectURL = vi.fn(() => 'blob:apercu-local');
  globalThis.URL.revokeObjectURL = vi.fn();
});

describe('TabCapas — la campagne photo', () => {
  it('le compte, et la liste de campagne de la bibliothèque courante', async () => {
    const { container } = rendreIntl();
    await screen.findByText('A Conquista do Pão');
    expect(container.querySelector('[data-capas-compte]').textContent).toMatch(/2\s094 notices sans couverture · 0 photographiée/);
    expect(appels('capas_photo_liste')[0]).toEqual({ p_library_id: LIB, p_recherche: null, p_limite: 20, p_decalage: 0 });
  });

  it('photographier, tourner, poser : nom neuf dans le dossier de la notice, vignette, RPC, puis la suivante', async () => {
    const { container } = rendreIntl();
    fireEvent.click(await screen.findByText('A Conquista do Pão'));
    expect(screen.getByRole('button', { name: /Photographier la couverture/ })).toBeTruthy();
    photographier(container);
    await waitFor(() => expect(container.querySelector('img[src="blob:apercu-local"]')).toBeTruthy());
    expect(preparerPhoto).toHaveBeenLastCalledWith(expect.objectContaining({ name: 'IMG_0001.jpg' }), 0);

    fireEvent.click(screen.getByRole('button', { name: 'Tourner vers la droite' }));
    await waitFor(() => expect(preparerPhoto).toHaveBeenLastCalledWith(expect.objectContaining({ name: 'IMG_0001.jpg' }), 1));

    fireEvent.click(screen.getByRole('button', { name: 'Poser cette photo' }));
    await screen.findByText('Couverture posée : A Conquista do Pão.');
    const [envoi] = etat.envois;
    expect(envoi.chemin).toMatch(/^books\/BTL-TL-000447\/photo-[a-z0-9]{1,20}\.jpg$/);
    expect(envoi.options).toEqual({ contentType: 'image/jpeg', upsert: false });
    expect(await envoi.blob.text()).toBe('prepare:IMG_0001.jpg:1');   // c'est la photo PRÉPARÉE qui part, tournée
    expect(writeCoverThumb).toHaveBeenCalledWith(envoi.chemin, envoi.blob);
    expect(appels('capas_photo_poser')).toEqual([{ p_book_id: 447, p_object_path: envoi.chemin, p_remplacer: false }]);
    // la campagne avance : la notice suivante est prise, prête à photographier
    expect(screen.queryByText('A Conquista do Pão')).toBeNull();
    expect(container.querySelector('.ab-capas-photo__fiche').textContent).toContain('Deus e o Estado');
    expect(container.querySelector('[data-capas-compte]').textContent).toMatch(/2\s093 notices sans couverture · 1 photographiée/);
    expect(etat.retraits).toEqual([]);
  });

  it('une couverture présente : annoncée, et remplacée seulement parce que l’écran l’a dit', async () => {
    etat.reponses.capas_photo_liste = () => ({ data: [COUVERT], error: null });
    const { container } = rendreIntl();
    fireEvent.change(screen.getByPlaceholderText(fr['capas.photo.recherche']), { target: { value: 'coberto' } });
    await waitFor(() => expect(container.querySelector('.ab-capas-photo__fiche')).toBeTruthy());   // un seul résultat : pris d'office
    expect(screen.getByText(fr['capas.photo.dejaUneCapa'])).toBeTruthy();
    photographier(container);
    fireEvent.click(await screen.findByRole('button', { name: 'Remplacer la couverture par cette photo' }));
    await screen.findByText('Couverture posée : Já coberto.');
    expect(appels('capas_photo_poser')[0]).toMatchObject({ p_book_id: 500, p_remplacer: true });
  });

  it('« deja_une_capa » (posée entre-temps) : rien n’est remplacé, le fichier est retiré', async () => {
    etat.reponses.capas_photo_poser = { data: 'deja_une_capa', error: null };
    const { container } = rendreIntl();
    fireEvent.click(await screen.findByText('A Conquista do Pão'));
    photographier(container);
    fireEvent.click(await screen.findByRole('button', { name: 'Poser cette photo' }));
    await screen.findByText(/a reçu une couverture entre-temps : rien n'a été remplacé/);
    const chemin = etat.envois[0].chemin;
    expect(etat.retraits).toEqual([chemin, `${chemin}.thumb.jpg`]);
  });

  it('la RPC refuse : l’erreur est dite, le fichier est retiré, la notice reste', async () => {
    etat.reponses.capas_photo_poser = { data: null, error: { message: 'capa_hors_perimetre' } };
    const { container } = rendreIntl();
    fireEvent.click(await screen.findByText('A Conquista do Pão'));
    photographier(container);
    fireEvent.click(await screen.findByRole('button', { name: 'Poser cette photo' }));
    await screen.findByText("L'opération a échoué : capa_hors_perimetre");
    expect(etat.retraits).toHaveLength(2);
    // toujours dans la liste, et toujours la notice en cours
    expect(screen.getAllByText('A Conquista do Pão')).toHaveLength(2);
  });

  it('scanner l’étiquette : la recherche porte le code lu, une seule notice est prise d’office', async () => {
    const { container } = rendreIntl();
    await screen.findByText('A Conquista do Pão');
    fireEvent.click(screen.getByRole('button', { name: 'Scanner' }));
    fireEvent.click(screen.getByRole('button', { name: 'lire l’étiquette' }));
    await waitFor(() => expect(appels('capas_photo_liste').some((a) => a.p_recherche === 'https://app.anarbib.is/livro/447?ex=9001')).toBe(true));
    await waitFor(() => expect(container.querySelector('.ab-capas-photo__fiche')?.textContent).toContain('Deus e o Estado'));
  });

  it('l’envoi échoue (bucket) : rien à retirer, la RPC n’est pas appelée', async () => {
    etat.reponses.upload = { data: null, error: { message: 'new row violates row-level security policy' } };
    const { container } = rendreIntl();
    fireEvent.click(await screen.findByText('A Conquista do Pão'));
    photographier(container);
    fireEvent.click(await screen.findByRole('button', { name: 'Poser cette photo' }));
    await screen.findByText(/L'opération a échoué/);
    expect(appels('capas_photo_poser')).toEqual([]);
    expect(etat.retraits).toEqual([]);
  });
});
