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
    expect(screen.getByText('História do Anarquismo : Uma Introdução ao Tema')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: fr['catalogacao.titleCase.apply'] }));
    expect(onApply).toHaveBeenCalledWith('História do Anarquismo', 'Uma Introdução ao Tema');
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
});
