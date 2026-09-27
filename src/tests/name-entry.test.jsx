// CHEMIN DÉPÔT : src/tests/name-entry.test.jsx
//
// C6 §7.1 — le point d'accès d'une personne proposé à la saisie. La règle
// (src/lib/nameEntry.js) : entrée au dernier nom de famille, particules avec
// le prénom, filiation attachée au nom, double nom hispanique en VARIANTE
// seulement. L'assistant (NameEntryAssist) propose, explique, laisse corriger,
// et n'écrit rien sans un clic.

import { describe, it, expect, vi } from 'vitest';
import { readFileSync } from 'node:fs';
import { render, screen, fireEvent } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import fr from '../i18n/locales/fr.json';
import { proposerPointAcces, formeDepuis } from '../lib/nameEntry.js';
import NameEntryAssist from '../components/catalog/NameEntryAssist.jsx';

describe('proposerPointAcces', () => {
  it('entrée au dernier nom, particules avec le prénom', () => {
    const p = proposerPointAcces('Fabiano de Oliveira Bringel');
    expect(p.forme).toBe('Bringel, Fabiano de Oliveira');
    expect(p.regle).toBe('direct');
  });

  it('la filiation va avec le nom qui la précède', () => {
    expect(proposerPointAcces('José Oiticica Sousa Filho')).toMatchObject({ forme: 'Sousa Filho, José Oiticica', regle: 'filiation' });
    expect(proposerPointAcces('Edgar Rodrigues Júnior').forme).toBe('Rodrigues Júnior, Edgar');
  });

  it('deux mots dont une filiation : pas d’entrée au prénom seul', () => {
    // « Filho » seul derrière un prénom : on ne rattache pas au premier mot.
    expect(proposerPointAcces('Pedro Filho').forme).toBe('Filho, Pedro');
  });

  it('un seul mot : entrée directe', () => {
    expect(proposerPointAcces('Voline')).toMatchObject({ forme: 'Voline', regle: 'mononyme' });
  });

  it('déjà inversé ou vide : rien à proposer', () => {
    expect(proposerPointAcces('Bayer, Osvaldo').regle).toBe('inverse');
    expect(proposerPointAcces('   ').regle).toBe('vide');
  });

  it('la variante hispanique n’est offerte que pour un pays hispanophone', () => {
    const ar = proposerPointAcces('Juan Carlos Mechoso', { country: 'AR' });
    expect(ar.forme).toBe('Mechoso, Juan Carlos');            // la proposition reste prudente
    expect(ar.variante).toMatchObject({ forme: 'Carlos Mechoso, Juan', regle: 'hispanique' });
    expect(proposerPointAcces('José Ortega y Gasset', { country: 'es' }).variante.forme).toBe('Ortega y Gasset, José');
    expect(proposerPointAcces('Juan Carlos Mechoso', { country: 'BR' }).variante).toBeNull();
    expect(proposerPointAcces('Juan Carlos Mechoso').variante).toBeNull();
  });

  it('particule en tête du nom composé : Abad de Santillán', () => {
    const p = proposerPointAcces('Diego Abad de Santillán', { country: 'ES' });
    expect(p.forme).toBe('Santillán, Diego Abad de');
    expect(p.variante.forme).toBe('Abad de Santillán, Diego');
  });

  it('formeDepuis découpe où l’on clique, et rend le nom entier hors bornes', () => {
    const tokens = ['Diego', 'Abad', 'de', 'Santillán'];
    expect(formeDepuis(tokens, 1)).toBe('Abad de Santillán, Diego');
    expect(formeDepuis(tokens, 0)).toBe('Diego Abad de Santillán');
    expect(formeDepuis([], 1)).toBe('');
  });

  it('les espaces multiples ne créent pas de mots vides', () => {
    expect(proposerPointAcces('  Osvaldo   Bayer ').forme).toBe('Bayer, Osvaldo');
  });

  it('le formulaire d’autorité dérive la forme de tri par la règle et monte l’assistant', () => {
    const src = readFileSync('src/pages/catalogacao/AuthorDraftForm.jsx', 'utf8');
    expect(src).toMatch(/proposerPointAcces\(clean\)\.forme/);
    expect(src).toMatch(/<NameEntryAssist nom=\{f\('preferred_name'\)\}/);
    expect(src).not.toMatch(/BAYER/);                          // CONV-1 : pas de capitales
  });
});

const monter = (props) => render(
  <IntlProvider locale="fr" messages={fr}><NameEntryAssist {...props} /></IntlProvider>,
);
const bouton = (cle) => screen.queryByRole('button', { name: fr[`catalogacao.nameEntry.${cle}`] });

describe('NameEntryAssist', () => {
  it('propose et explique ; confirmer écrit la forme proposée', () => {
    const onChoisir = vi.fn();
    monter({ nom: 'Fabiano de Oliveira Bringel', country: '', formeActuelle: '', onChoisir });
    expect(screen.getByText('Bringel, Fabiano de Oliveira')).toBeTruthy();
    expect(screen.getByText(fr['catalogacao.nameEntry.rule.direct'])).toBeTruthy();
    expect(onChoisir).not.toHaveBeenCalled();
    fireEvent.click(bouton('confirm'));
    expect(onChoisir).toHaveBeenCalledWith('Bringel, Fabiano de Oliveira');
  });

  it('forme déjà en usage : pas de bouton Confirmer', () => {
    monter({ nom: 'Osvaldo Bayer', formeActuelle: 'Bayer, Osvaldo', onChoisir: vi.fn() });
    expect(bouton('confirm')).toBeNull();
    expect(screen.getByText(/en usage/)).toBeTruthy();
  });

  it('corriger : un clic sur le mot où commence le nom de famille', () => {
    const onChoisir = vi.fn();
    monter({ nom: 'Diego Abad de Santillán', formeActuelle: '', onChoisir });
    fireEvent.click(bouton('correct'));
    fireEvent.click(screen.getByRole('button', { name: 'Abad' }));
    expect(onChoisir).toHaveBeenCalledWith('Abad de Santillán, Diego');
  });

  it('nom unique / pseudonyme : le nom tel quel', () => {
    const onChoisir = vi.fn();
    monter({ nom: 'Han Ryner', formeActuelle: 'Ryner, Han', onChoisir });
    fireEvent.click(bouton('single'));
    expect(onChoisir).toHaveBeenCalledWith('Han Ryner');
  });

  it('pays hispanophone : la variante à deux noms est offerte', () => {
    const onChoisir = vi.fn();
    monter({ nom: 'José Ortega y Gasset', country: 'ES', formeActuelle: '', onChoisir });
    fireEvent.click(screen.getByRole('button', { name: 'Ortega y Gasset, José' }));
    expect(onChoisir).toHaveBeenCalledWith('Ortega y Gasset, José');
  });

  it('rien pour un nom vide ou déjà inversé', () => {
    const { container } = monter({ nom: 'Bayer, Osvaldo', formeActuelle: '', onChoisir: vi.fn() });
    expect(container.querySelector('[data-testid="name-entry-assist"]')).toBeNull();
  });
});
