// ═══════════════════════════════════════════════════════════
// AnarBib — l'écran de revue des capas proposées par le lot (27/09/2026).
//
// On rend le VRAI CapasRevuePanel avec le vrai dictionnaire fr, sur un faux
// Supabase qui répond comme les RPC api.capas_revue_* (formes figées par
// tests/sql/capas_lot_tests.sql) et comme cover_lookup (actions apercus et
// store, figées par cover-lookup-banc.test.js). Ce que l'écran doit garder :
//   * aucune image tierce dans un src : les vignettes sont des data: URI
//     rapatriées par le serveur (spec capas §4.3) ;
//   * une capa se range sous un nom NEUF (`capa-…`), jamais `front`, puis la
//     RPC tranche ; « perimee » ou échec : le fichier rangé pour rien est retiré ;
//   * « Aucune ne convient » se défait (« Annuler ») ;
//   * l'avertissement d'édition de l'ISBN, comme au formulaire ;
//   * hors du staff, l'écran se tait.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import fr from '@/i18n/locales/fr.json';

const etat = vi.hoisted(() => ({ appels: [], retraits: [], reponses: {} }));

vi.mock('@/lib/supabase', () => {
  const rpc = async (nom, args) => {
    etat.appels.push([nom, args]);
    const r = etat.reponses[nom];
    return typeof r === 'function' ? r(args) : (r ?? { data: null, error: null });
  };
  return {
    supabase: {
      schema: () => ({ rpc }),
      functions: {
        invoke: async (nom, { body }) => {
          etat.appels.push([`${nom}:${body.action}`, body]);
          const r = etat.reponses[`${nom}:${body.action}`];
          return typeof r === 'function' ? r(body) : r;
        },
      },
      storage: { from: () => ({ remove: async (chemins) => { etat.retraits.push(...chemins); return { error: null }; } }) },
    },
  };
});

vi.mock('@/lib/coverThumbs', () => ({
  COVER_BUCKET: 'covers',
  writeCoverThumb: vi.fn(async (p) => `${p}.thumb.jpg`),
  removeCoverThumb: vi.fn(async (p) => { etat.retraits.push(`${p}.thumb.jpg`); }),
}));

vi.mock('@/lib/localizeError', () => ({ localizeError: (e) => String(e?.message || e) }));

import CapasRevuePanel from '@/pages/catalogacao/CapasRevuePanel.jsx';

const OL_M = 'https://covers.openlibrary.org/b/id/951719-M.jpg';
const OL_L = 'https://covers.openlibrary.org/b/id/951719-L.jpg';
const INV_M = 'https://inventaire.io/img/entities/200x300/e927b2b4f326d4380fe7bff821a170f0a570360e';
const INV_L = 'https://inventaire.io/img/entities/e927b2b4f326d4380fe7bff821a170f0a570360e';

// BTL-TL-002335, le cas réel du 27/09 : Ramparts Press 1971, ISBN de l'édition AK Press 2004.
const RAMPARTS = {
  book_id: 2335, bib_ref: 'BTL-TL-002335', titulo: 'Post-Scarcity Anarchism', subtitulo: null, autor: 'Bookchin, Murray',
  editora: 'Ramparts Press', ano: '1971', volume: null, isbn: '1904859062', idioma: 'en', cherche_le: '2026-09-27T10:00:00Z',
  candidates: [{ thumbnailUrl: OL_M, fullUrl: OL_L, source: 'openlibrary', license: null, voie: 'isbn',
    label: 'Post-scarcity anarchism · AK Press, 2004', edition: { annee: '2004', editeurs: ['AK Press'] } }],
};
const GARCIA = {
  book_id: 1992, bib_ref: 'BTL-TL-001992', titulo: "L'anarchisme aujourd'hui", subtitulo: null, autor: 'García, Vivien',
  editora: "L'Harmattan", ano: '2007', volume: null, isbn: '9782296035072', idioma: 'fr', cherche_le: '2026-09-27T10:00:00Z',
  candidates: [{ thumbnailUrl: INV_M, fullUrl: INV_L, source: 'inventaire', license: null, voie: 'isbn',
    label: "L'anarchisme aujourd'hui · Éditions L'Harmattan, 2007", edition: { annee: '2007', editeurs: ["Éditions L'Harmattan"] } }],
};

function reponsesParDefaut() {
  etat.reponses = {
    capas_revue_resume: { data: { a_revoir: 2, a_chercher: 1500, sans_resultat: 0, en_panne: 0, acceptee: 0, ecartee: 0 }, error: null },
    capas_revue_liste: { data: [GARCIA, RAMPARTS], error: null },
    capas_revue_accepter: { data: 'acceptee', error: null },
    capas_revue_ecarter: { data: 'ecartee', error: null },
    capas_revue_rouvrir: { data: 'a_revoir', error: null },
    'cover_lookup:apercus': (body) => ({
      data: { ok: true, apercus: Object.fromEntries(body.urls.map((u) => [u, 'data:image/jpeg;base64,AAAA'])) }, error: null,
    }),
    'cover_lookup:store': (body) => ({ data: { ok: true, storagePath: `books/${body.key}/${body.nom}.jpg` }, error: null }),
  };
}

const rendre = () => render(<IntlProvider locale="fr" messages={fr}><CapasRevuePanel /></IntlProvider>);
const ouvrir = async () => {
  fireEvent.click(await screen.findByRole('button', { name: /Couvertures proposées/ }));
  await screen.findByText("L'anarchisme aujourd'hui");
};
const appels = (nom) => etat.appels.filter(([n]) => n === nom).map(([, a]) => a);

beforeEach(() => {
  etat.appels = [];
  etat.retraits = [];
  reponsesParDefaut();
});

describe('CapasRevuePanel — la revue des capas proposées', () => {
  it('replié : le compte à revoir ; ouvert : les notices, et ce qui reste à chercher', async () => {
    rendre();
    const entete = await screen.findByRole('button', { name: /Couvertures proposées/ });
    expect(entete.textContent).toContain('2 à revoir');
    expect(appels('capas_revue_liste')).toHaveLength(0);   // rien de chargé tant que c'est replié
    await ouvrir();
    expect(screen.getByText('Post-Scarcity Anarchism')).toBeTruthy();
    // ICU formate le nombre à la française : « 1 500 », espace fine insécable.
    expect(document.body.textContent).toMatch(/1\s500 notices restent à parcourir/);
  });

  it('aucune image tierce dans un src : les vignettes viennent du serveur, en data: URI', async () => {
    const { container } = rendre();
    await ouvrir();
    await waitFor(() => expect(container.querySelectorAll('img').length).toBe(2));
    for (const img of container.querySelectorAll('img')) expect(img.getAttribute('src')).toMatch(/^data:image\//);
    expect(appels('cover_lookup:apercus')[0].urls.sort()).toEqual([INV_M, OL_M].sort());
  });

  it('l’ISBN qui désigne une autre édition est signalé, et sa vignette dit « À vérifier »', async () => {
    rendre();
    await ouvrir();
    expect(document.body.textContent).toContain("Cet ISBN désigne l'édition AK Press, 2004 ; la notice indique Ramparts Press, 1971.");
    expect(screen.getByRole('button', { name: /Poser cette couverture · Post-scarcity anarchism/ }).textContent).toContain('À vérifier');
    expect(screen.getByRole('button', { name: /Poser cette couverture · L'anarchisme aujourd'hui/ }).textContent).toContain('ISBN concordant');
  });

  it('choisir : rangée sous un nom neuf, vignette dérivée, puis la RPC tranche ; la notice quitte la liste', async () => {
    rendre();
    await ouvrir();
    fireEvent.click(screen.getByRole('button', { name: /Poser cette couverture · L'anarchisme aujourd'hui/ }));
    await screen.findByText("Couverture posée : L'anarchisme aujourd'hui.");
    const [store] = appels('cover_lookup:store');
    expect(store).toMatchObject({ imageUrl: INV_L, key: 'BTL-TL-001992', source: 'inventaire' });
    expect(store.nom).toMatch(/^capa-[a-z0-9]{1,20}$/);
    const chemin = `books/BTL-TL-001992/${store.nom}.jpg`;
    const { writeCoverThumb } = await import('@/lib/coverThumbs');
    expect(writeCoverThumb).toHaveBeenCalledWith(chemin);
    expect(appels('capas_revue_accepter')).toEqual([{ p_book_id: 1992, p_full_url: INV_L, p_object_path: chemin }]);
    expect(screen.queryByText("L'anarchisme aujourd'hui")).toBeNull();
    expect(etat.retraits).toEqual([]);
  });

  it('« perimee » : rien n’est remplacé, et le fichier rangé pour rien est retiré', async () => {
    etat.reponses.capas_revue_accepter = { data: 'perimee', error: null };
    rendre();
    await ouvrir();
    fireEvent.click(screen.getByRole('button', { name: /Poser cette couverture · L'anarchisme aujourd'hui/ }));
    await screen.findByText(/a reçu une couverture entre-temps : rien n'a été remplacé/);
    const chemin = `books/BTL-TL-001992/${appels('cover_lookup:store')[0].nom}.jpg`;
    expect(etat.retraits).toEqual([chemin, `${chemin}.thumb.jpg`]);
  });

  it('la RPC refuse : l’erreur est dite, le fichier est retiré, la notice reste', async () => {
    etat.reponses.capas_revue_accepter = { data: null, error: { message: 'capa_proposition_close' } };
    rendre();
    await ouvrir();
    fireEvent.click(screen.getByRole('button', { name: /Poser cette couverture · L'anarchisme aujourd'hui/ }));
    await screen.findByText("L'opération a échoué : capa_proposition_close");
    expect(etat.retraits).toHaveLength(2);
    expect(screen.getByText("L'anarchisme aujourd'hui")).toBeTruthy();
  });

  it('« Aucune ne convient » écarte, « Annuler » rétablit', async () => {
    rendre();
    await ouvrir();
    const [aucune] = screen.getAllByRole('button', { name: 'Aucune ne convient' });
    fireEvent.click(aucune);
    await screen.findByText(/Proposition écartée : L'anarchisme aujourd'hui/);
    expect(appels('capas_revue_ecarter')).toEqual([{ p_book_id: 1992 }]);
    fireEvent.click(screen.getByRole('button', { name: 'Annuler' }));
    await screen.findByText("Proposition rétablie : L'anarchisme aujourd'hui.");
    expect(appels('capas_revue_rouvrir')).toEqual([{ p_book_id: 1992 }]);
  });

  it('hors du staff (la RPC refuse) : l’écran se tait', async () => {
    etat.reponses.capas_revue_resume = { data: null, error: { code: '42501', message: 'Acesso restrito' } };
    const { container } = rendre();
    await waitFor(() => expect(appels('capas_revue_resume')).toHaveLength(1));
    expect(container.textContent).toBe('');
  });

  it('rien à revoir et rien à chercher : l’écran se tait aussi', async () => {
    etat.reponses.capas_revue_resume = { data: { a_revoir: 0, a_chercher: 0 }, error: null };
    const { container } = rendre();
    await waitFor(() => expect(appels('capas_revue_resume')).toHaveLength(1));
    expect(container.textContent).toBe('');
  });
});
