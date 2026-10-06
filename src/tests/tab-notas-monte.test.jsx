// ═══════════════════════════════════════════════════════════
// AnarBib — E6, AccountPage lot 3 (06/10/2026) : l'onglet « Mes notes de
// lecture » de Mon compte sort dans TabNotas.jsx.
//   * une note se rend, avec le lien vers son œuvre et le message du parent ;
//   * « Modifier » ouvre l'édition (setEditNoteId, setEditNoteBody) ;
//     « Enregistrer » appelle saveReadingNote(id), désactivé si le texte est
//     vide ; « Annuler » referme ;
//   * « Supprimer » appelle deleteReadingNote(id) ;
//   * le parent monte l'onglet et ne garde plus son corps.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, fireEvent, cleanup } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { MemoryRouter } from 'react-router-dom';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import TabNotas from '@/pages/account/TabNotas';

const RACINE = path.resolve(__dirname, '../..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');
const fr = JSON.parse(lire('src/i18n/locales/fr.json'));

afterEach(cleanup);

const NOTE = { id: 12, work_id: 133, body: 'Un livre qui tient debout.', created_at: '2026-10-01T10:00:00Z',
  edited: false, status: 'published', works: { uniform_title: 'L’Homme et la Terre' } };

function monter(sur = {}) {
  const props = { myReadingNotes: [NOTE], noteMsg: { text: '', kind: '' }, saving: false,
    editNoteId: null, setEditNoteId: vi.fn(), editNoteBody: '', setEditNoteBody: vi.fn(),
    saveReadingNote: vi.fn(), deleteReadingNote: vi.fn(), ...sur };
  render(<IntlProvider locale="fr" messages={fr}><MemoryRouter><TabNotas {...props} /></MemoryRouter></IntlProvider>);
  return props;
}

describe('l’onglet Mes notes de lecture, sorti d’AccountPage', () => {
  it('rend la note, le lien vers son œuvre et le message du parent', () => {
    monter({ noteMsg: { text: 'Note mise à jour.', kind: 'ok' } });
    expect(screen.getByText(fr['account.readingNotes.title'])).toBeTruthy();
    expect(screen.getByText('Un livre qui tient debout.')).toBeTruthy();
    expect(screen.getByText('L’Homme et la Terre')).toBeTruthy();
    // setup.js remplace Link par ses enfants : le lien se lit dans la source
    expect(lire('src/pages/account/TabNotas.jsx')).toMatch(/<Link to=\{`\/obra\/\$\{n\.work_id\}`\}/);
    expect(screen.getByText('Note mise à jour.')).toBeTruthy();
  });

  it('sans note, le vide est dit', () => {
    monter({ myReadingNotes: [] });
    expect(screen.getByText(fr['account.readingNotes.empty'])).toBeTruthy();
  });

  it('« Modifier » ouvre l’édition avec le texte de la note', () => {
    const p = monter();
    fireEvent.click(screen.getByText(fr['common.edit']));
    expect(p.setEditNoteId).toHaveBeenCalledWith(12);
    expect(p.setEditNoteBody).toHaveBeenCalledWith('Un livre qui tient debout.');
  });

  it('en édition : « Enregistrer » appelle saveReadingNote, désactivé sur un texte vide ; « Annuler » referme', () => {
    const p = monter({ editNoteId: 12, editNoteBody: 'Corrigé.' });
    fireEvent.click(screen.getByText(fr['common.save']));
    expect(p.saveReadingNote).toHaveBeenCalledWith(12);
    fireEvent.click(screen.getByText(fr['common.cancel']));
    expect(p.setEditNoteId).toHaveBeenCalledWith(null);
    expect(p.setEditNoteBody).toHaveBeenCalledWith('');
    cleanup();
    monter({ editNoteId: 12, editNoteBody: '   ' });
    expect(screen.getByText(fr['common.save']).closest('button').disabled).toBe(true);
  });

  it('« Supprimer » appelle deleteReadingNote', () => {
    const p = monter();
    fireEvent.click(screen.getByText(fr['common.delete']));
    expect(p.deleteReadingNote).toHaveBeenCalledWith(12);
  });

  it('le parent monte TabNotas et ne garde plus le corps de l’onglet', () => {
    const page = lire('src/pages/account/AccountPage.jsx');
    expect(page).toMatch(/<TabNotas\b/);
    expect(page).not.toMatch(/onClick=\{\(\) => saveReadingNote\(n\.id\)\}/);
    expect(page).not.toMatch(/account\.readingNotes\.workFallback/);
  });
});
