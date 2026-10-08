// ═════════════════════════════════════════════════
// AnarBib — G19 lot 2 (08/10/2026) : l'onglet « Correspondance » de la page
// Bibliothèque (CorrespondanceSection), REGISTRE CORR-1 à CORR-6.
//   * la liste : un fil par participation de ma bibliothèque, l'autre
//     bibliothèque nommée, le non-lu compté (messages après ma dernière
//     lecture), les archivés sous leur filtre ;
//   * ouvrir un fil appelle api.fn_correspondance_lue et montre les messages
//     (bibliothèque, langue, texte) ;
//   * répondre appelle api.fn_correspondance_envoyer au nom de ma
//     bibliothèque, avec la langue choisie ;
//   * « Écrire à une bibliothèque » appelle api.fn_correspondance_ouvrir ; la
//     liste des destinataires exclut ma bibliothèque et les inactives ;
//   * archiver appelle api.fn_correspondance_archiver ;
//   * la page monte l'onglet pour les coordinations seulement ;
//   * les clés existent dans les dix locales.
// ═════════════════════════════════════════════════

import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, fireEvent, cleanup, waitFor } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';

const LIB_A = 'aaaaaaaa-0000-4000-8000-000000000001';
const LIB_B = 'bbbbbbbb-0000-4000-8000-000000000002';
const LIB_C = 'cccccccc-0000-4000-8000-000000000003';
const DONNEES = {
  library_conversation_participants: {
    moi: [
      { conversation_id: 11, archived_at: null, library_conversations: { id: 11, subject: 'Des doubles de Reclus ?', last_message_at: '2026-10-08T10:00:00Z', created_at: '2026-10-07T10:00:00Z' } },
      { conversation_id: 12, archived_at: '2026-10-01T00:00:00Z', library_conversations: { id: 12, subject: 'Vieux fil', last_message_at: '2026-09-30T10:00:00Z', created_at: '2026-09-29T10:00:00Z' } },
    ],
    tous: [
      { conversation_id: 11, library_id: LIB_A }, { conversation_id: 11, library_id: LIB_B },
      { conversation_id: 12, library_id: LIB_A }, { conversation_id: 12, library_id: LIB_C },
    ],
  },
  library_messages: [
    { id: 1, conversation_id: 11, library_id: LIB_A, body: 'Bonjour, avez-vous des doubles ?', lang: 'fr', created_at: '2026-10-07T10:00:00Z' },
    { id: 2, conversation_id: 11, library_id: LIB_B, body: 'Sim, temos dois exemplares.', lang: 'pt-BR', created_at: '2026-10-08T10:00:00Z' },
    { id: 3, conversation_id: 12, library_id: LIB_C, body: 'Hola.', lang: 'es', created_at: '2026-09-30T10:00:00Z' },
  ],
  library_conversation_reads: [{ conversation_id: 11, last_read_message_id: 1 }, { conversation_id: 12, last_read_message_id: 3 }],
  libraries: [{ id: LIB_B, default_locale: 'pt-BR' }, { id: LIB_C, default_locale: 'es' }],
};
const rpc = vi.fn(async (nom) => ({ data: nom === 'fn_correspondance_ouvrir' ? 13 : 1, error: null }));
// Un constructeur de requête minimal : chaque méthode rend le constructeur,
// l'attente rend les données de la table (les participations « de ma
// bibliothèque » quand .eq('library_id') a été appelé, toutes sinon).
function constructeur(table) {
  const etat = { eqLibrary: false };
  const b = {
    select: () => b, order: () => b, limit: () => b, in: () => b,
    eq: (col) => { if (col === 'library_id') etat.eqLibrary = true; return b; },
    then: (ok) => {
      let data = DONNEES[table];
      if (table === 'library_conversation_participants') data = etat.eqLibrary ? data.moi : data.tous;
      return Promise.resolve({ data, error: null }).then(ok);
    },
  };
  return b;
}
vi.mock('@/lib/supabase', () => ({
  supabase: { from: (table) => constructeur(table), schema: () => ({ rpc: (...a) => rpc(...a) }) },
  SUPABASE_URL: 'https://exemple.invalid',
}));

import CorrespondanceSection from '@/pages/biblioteca/CorrespondanceSection';

const RACINE = path.resolve(__dirname, '../..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');
const fr = JSON.parse(lire('src/i18n/locales/fr.json'));
const LIBS = [
  { id: LIB_A, name: 'Biblio A', short_name: 'A', is_active: true, read_languages: ['fr', 'es'] },
  { id: LIB_B, name: 'Biblio B', short_name: 'B', is_active: true, read_languages: ['pt-BR', 'es'] },
  { id: LIB_C, name: 'Biblio C', short_name: 'C', is_active: true, read_languages: [], default_locale: 'es' },
  { id: 'dddddddd-0000-4000-8000-000000000004', name: 'Biblio D', short_name: 'D', is_active: false },
  { id: 'eeeeeeee-0000-4000-8000-000000000005', name: 'Biblio E', short_name: 'E', is_active: true, network_mode: 'isolated' },
  { id: 'eeeeeeee-0000-4000-8000-000000000006', name: 'Biblio G', short_name: 'G', is_active: true, read_languages: ['el'] },
];
const setMsg = vi.fn();
const monter = () => render(<IntlProvider locale="fr" messages={fr}><CorrespondanceSection libraryId={LIB_A} allLibraries={LIBS} setMsg={setMsg} /></IntlProvider>);

afterEach(() => { cleanup(); rpc.mockClear(); setMsg.mockClear(); });

describe('l’onglet Correspondance (G19 lot 2)', () => {
  it('liste les fils en cours avec l’autre bibliothèque et le non-lu ; les archivés sous leur filtre', async () => {
    monter();
    expect(await screen.findByText('Des doubles de Reclus ?')).toBeTruthy();
    expect(screen.getByText(/^Avec B/)).toBeTruthy();   // suivi du dernier expéditeur et de la date, dans le même bloc
    expect(screen.getByText('1 non lu')).toBeTruthy();            // le message 2 est après ma dernière lecture (1)
    expect(screen.queryByText('Vieux fil')).toBeNull();            // archivé : pas sous « En cours »
    fireEvent.click(screen.getByRole('tab', { name: fr['biblioteca.correspondance.filterArchived'] }));
    expect(screen.getByText('Vieux fil')).toBeTruthy();
    expect(screen.queryByText('Des doubles de Reclus ?')).toBeNull();
  });

  it('ouvrir un fil marque lu (api.fn_correspondance_lue) et montre les messages, leur bibliothèque et leur langue', async () => {
    monter();
    fireEvent.click(await screen.findByText('Des doubles de Reclus ?'));
    await waitFor(() => expect(rpc).toHaveBeenCalledWith('fn_correspondance_lue', { p_conversation_id: 11 }));
    expect(screen.getByText('Sim, temos dois exemplares.')).toBeTruthy();
    expect(screen.getByText('Bonjour, avez-vous des doubles ?')).toBeTruthy();
    expect(screen.getAllByText('pt-BR').length).toBeGreaterThan(0);
    expect(screen.getByText(/Bibliothèques du fil/).textContent).toContain('A · B');
  });

  it('répondre appelle api.fn_correspondance_envoyer au nom de ma bibliothèque, avec la langue choisie', async () => {
    monter();
    fireEvent.click(await screen.findByText('Des doubles de Reclus ?'));
    const zone = await screen.findByLabelText(fr['biblioteca.correspondance.reply']);
    fireEvent.change(zone, { target: { value: 'Parfait, je passe.' } });
    const langues = screen.getAllByLabelText(fr['biblioteca.correspondance.lang']);
    fireEvent.change(langues[langues.length - 1], { target: { value: 'es' } });
    fireEvent.click(screen.getByRole('button', { name: fr['biblioteca.correspondance.send'] }));
    await waitFor(() => expect(rpc).toHaveBeenCalledWith('fn_correspondance_envoyer',
      { p_conversation_id: 11, p_library_id: LIB_A, p_corps: 'Parfait, je passe.', p_lang: 'es' }));
    expect(setMsg).toHaveBeenCalledWith({ text: fr['biblioteca.correspondance.sent'], kind: 'ok' });
  });

  it('« Écrire à une bibliothèque » appelle api.fn_correspondance_ouvrir ; ni ma bibliothèque ni une inactive en destinataire', async () => {
    monter();
    await screen.findByText('Des doubles de Reclus ?');
    fireEvent.click(screen.getByRole('button', { name: fr['biblioteca.correspondance.write'] }));
    const dest = screen.getByLabelText(fr['biblioteca.correspondance.to']);
    const noms = [...dest.querySelectorAll('option')].map((o) => o.textContent);
    expect(noms).toContain('Biblio B');
    expect(noms).not.toContain('Biblio A');     // la mienne
    expect(noms).not.toContain('Biblio D');     // inactive
    expect(noms).not.toContain('Biblio E');     // isolée du réseau
    fireEvent.change(dest, { target: { value: LIB_C } });
    // C n'a rien déclaré : sa locale ; aucune langue commune avec A (fr, es) ? si : es
    expect((await screen.findByText(/Langue de cette bibliothèque/)).textContent).toContain('espagnol');
    expect(screen.getByText(/Langue commune proposée/).textContent).toContain('espagnol');
    fireEvent.change(screen.getByLabelText(fr['biblioteca.correspondance.subject']), { target: { value: 'Un prêt de longue durée ?' } });
    fireEvent.change(screen.getByLabelText(fr['biblioteca.correspondance.body']), { target: { value: 'Bonjour C.' } });
    fireEvent.click(screen.getByRole('button', { name: fr['biblioteca.correspondance.send'] }));
    // la langue proposée (commune : es) est présélectionnée
    await waitFor(() => expect(rpc).toHaveBeenCalledWith('fn_correspondance_ouvrir',
      { p_library_id: LIB_A, p_destinataire_id: LIB_C, p_sujet: 'Un prêt de longue durée ?', p_corps: 'Bonjour C.', p_lang: 'es' }));
  });

  it('lot 4 : « Cette bibliothèque lit » vient des langues déclarées, la langue commune est proposée, et son absence est dite', async () => {
    monter();
    await screen.findByText('Des doubles de Reclus ?');
    fireEvent.click(screen.getByRole('button', { name: fr['biblioteca.correspondance.write'] }));
    const dest = screen.getByLabelText(fr['biblioteca.correspondance.to']);
    fireEvent.change(dest, { target: { value: LIB_B } });
    expect(screen.getByText(/Cette bibliothèque lit/).textContent).toContain('portugais');
    expect(screen.getByText(/Langue commune proposée/).textContent).toContain('espagnol');
    const langues = screen.getAllByLabelText(fr['biblioteca.correspondance.lang']);
    expect(langues[0].value).toBe('es');
    fireEvent.change(dest, { target: { value: 'eeeeeeee-0000-4000-8000-000000000006' } });
    expect(screen.getByText(fr['biblioteca.correspondance.noCommonLanguage'])).toBeTruthy();
  });

  it('archiver appelle api.fn_correspondance_archiver pour ma bibliothèque', async () => {
    monter();
    fireEvent.click(await screen.findByText('Des doubles de Reclus ?'));
    fireEvent.click(await screen.findByRole('button', { name: fr['biblioteca.correspondance.archive'] }));
    await waitFor(() => expect(rpc).toHaveBeenCalledWith('fn_correspondance_archiver', { p_conversation_id: 11, p_library_id: LIB_A, p_archiver: true }));
  });

  it('la page Bibliothèque monte l’onglet pour les coordinations seulement (source)', () => {
    const page = lire('src/pages/biblioteca/BibliotecaPage.jsx');
    expect(page).toContain("import CorrespondanceSection from './CorrespondanceSection'");
    expect(page).toMatch(/\{ id: 'correspondance', icon: 'mail', label: t\(\{ id: 'biblioteca\.tab\.correspondance' \}\), coordOnly: true \}/);
    expect(page).toContain("{tab==='correspondance' && isCoord && (");
    expect(page).toContain('<CorrespondanceSection libraryId={libraryId} allLibraries={allLibraries} setMsg={setMsg} />');
  });

  it('les clés de l’onglet existent dans les dix locales', () => {
    const dir = path.join(RACINE, 'src/i18n/locales');
    const fichiers = readdirSync(dir).filter((f) => f.endsWith('.json'));
    expect(fichiers).toHaveLength(10);
    const cles = Object.keys(fr).filter((k) => k.startsWith('biblioteca.correspondance.') || k === 'biblioteca.tab.correspondance');
    expect(cles.length).toBeGreaterThanOrEqual(20);
    for (const f of fichiers) {
      const j = JSON.parse(readFileSync(path.join(dir, f), 'utf8'));
      for (const k of cles) expect(typeof j[k], `${f} ${k}`).toBe('string');
    }
  });
});
