// CHEMIN DÉPÔT : src/tests/title-case-assist.test.jsx
//
// C6 §7.2 — le bouton « Normaliser la casse » : inactif sans langue couverte,
// un aperçu avant / après avant toute écriture, puis appliquer, et annuler
// après coup en rendant l'original. Rien ne s'écrit sans un clic.

import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import fr from '../i18n/locales/fr.json';
import TitleCaseAssist from '../components/catalog/TitleCaseAssist.jsx';

const monter = (props) => render(
  <IntlProvider locale="fr" messages={fr}><TitleCaseAssist {...props} /></IntlProvider>,
);

describe('TitleCaseAssist', () => {
  it('sans langue : bouton inactif, rien n’est proposé', () => {
    const onApply = vi.fn();
    monter({ titulo: 'História Do Anarquismo', subtitulo: '', idioma: '', onApply });
    expect(screen.getByRole('button', { name: fr['catalogacao.titleCase.button'] }).disabled).toBe(true);
    expect(onApply).not.toHaveBeenCalled();
  });

  it('aperçu, puis appliquer : le titre et le sous-titre passent par onApply', () => {
    const onApply = vi.fn();
    monter({ titulo: 'História Do Anarquismo', subtitulo: 'Uma Introdução Ao Tema', idioma: 'pt-BR', onApply });
    fireEvent.click(screen.getByRole('button', { name: fr['catalogacao.titleCase.button'] }));
    expect(onApply).not.toHaveBeenCalled();                                   // l'aperçu n'écrit rien
    expect(screen.getByTestId('title-case-after').textContent).toBe('História do anarquismo : uma introdução ao tema');
    fireEvent.click(screen.getByRole('button', { name: fr['catalogacao.titleCase.apply'] }));
    expect(onApply).toHaveBeenCalledWith('História do anarquismo', 'uma introdução ao tema');
  });

  it('« Laisser tel quel » referme l’aperçu sans rien écrire', () => {
    const onApply = vi.fn();
    monter({ titulo: 'História Do Anarquismo', subtitulo: '', idioma: 'pt-BR', onApply });
    fireEvent.click(screen.getByRole('button', { name: fr['catalogacao.titleCase.button'] }));
    fireEvent.click(screen.getByRole('button', { name: fr['catalogacao.titleCase.cancel'] }));
    expect(onApply).not.toHaveBeenCalled();
  });

  it('annuler après coup rend l’original', () => {
    const onApply = vi.fn();
    monter({ titulo: 'História Do Anarquismo', subtitulo: '', idioma: 'pt-BR', onApply });
    fireEvent.click(screen.getByRole('button', { name: fr['catalogacao.titleCase.button'] }));
    fireEvent.click(screen.getByRole('button', { name: fr['catalogacao.titleCase.apply'] }));
    fireEvent.click(screen.getByRole('button', { name: fr['catalogacao.titleCase.undo'] }));
    expect(onApply).toHaveBeenLastCalledWith('História Do Anarquismo', '');
  });

  it('le titre de Xavier : le bouton est actif et rend la casse de phrase', () => {
    const onApply = vi.fn();
    monter({ titulo: 'lE tRuc qui FAIT cHIER', subtitulo: '', idioma: 'fr', onApply });
    const b = screen.getByRole('button', { name: fr['catalogacao.titleCase.button'] });
    expect(b.disabled).toBe(false);
    fireEvent.click(b);
    fireEvent.click(screen.getByRole('button', { name: fr['catalogacao.titleCase.apply'] }));
    expect(onApply).toHaveBeenCalledWith('Le truc qui fait chier', '');
  });

  it('un clic sur un mot de l’aperçu lui rend sa majuscule (nom propre)', () => {
    const onApply = vi.fn();
    // « France » est dans le dictionnaire des noms propres ; « Zorglub » non : un clic le rattrape.
    monter({ titulo: 'Le Voyage De Zorglub En France', subtitulo: '', idioma: 'fr', onApply });
    fireEvent.click(screen.getByRole('button', { name: fr['catalogacao.titleCase.button'] }));
    expect(screen.getByText(fr['catalogacao.titleCase.properHint'])).toBeTruthy();
    expect(screen.getByTestId('title-case-after').textContent).toBe('Le voyage de zorglub en France');
    fireEvent.click(screen.getByRole('button', { name: 'zorglub' }));
    fireEvent.click(screen.getByRole('button', { name: fr['catalogacao.titleCase.apply'] }));
    expect(onApply).toHaveBeenCalledWith('Le voyage de Zorglub en France', '');
  });

  it('un titre déjà en casse de phrase garde ses noms propres : rien à proposer', () => {
    monter({ titulo: 'Le mouvement anarchiste en France', subtitulo: '', idioma: 'fr', onApply: vi.fn() });
    expect(screen.getByRole('button', { name: fr['catalogacao.titleCase.button'] }).disabled).toBe(true);
    expect(screen.getByText(fr['catalogacao.titleCase.unchanged'])).toBeTruthy();
  });
});
