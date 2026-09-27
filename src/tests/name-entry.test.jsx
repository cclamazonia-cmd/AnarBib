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
import { proposerPointAcces, formeDepuis, proposerCasseNom, basculerMajuscule, proposerCasseCollectivite } from '../lib/nameEntry.js';
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

const casse = (n) => proposerCasseNom(n).mots.map((m) => m.texte).join(' ');

describe('proposerPointAcces — la langue du nom décide (CONV-6, spec §3.1)', () => {
  it.each([
    ['Edmondo De Amicis', 'it', 'De Amicis, Edmondo', 'conservee'],
    ['Lucien van der Walt', 'af', 'Van der Walt, Lucien', 'conservee'],
    ['Walter de la Mare', 'en', 'De la Mare, Walter', 'conservee'],
    ['Charles Le Brun', 'fr', 'Le Brun, Charles', 'article'],
    ['Jean de La Fontaine', 'fr', 'La Fontaine, Jean de', 'article'],
    ['Simone de Beauvoir', 'fr', 'Beauvoir, Simone de', 'direct'],
    ['Juan Gómez Casas', 'es', 'Gómez Casas, Juan', 'hispanique'],
    ['Santiago Ramón y Cajal', 'es', 'Ramón y Cajal, Santiago', 'hispanique'],
    ['Osvaldo Bayer', 'es', 'Bayer, Osvaldo', 'direct'],
    ['Fabiano de Oliveira Bringel', 'pt-BR', 'Bringel, Fabiano de Oliveira', 'direct'],
    ['Rudolf de Jong', 'nl', 'Jong, Rudolf de', 'direct'],
    ['Max von Nettlau', 'de', 'Nettlau, Max von', 'direct'],
    ['Fábio Luz Filho', 'pt-BR', 'Luz Filho, Fábio', 'filiation'],
  ])('%s (%s) → %s', (nom, nameLang, forme, regle) => {
    expect(proposerPointAcces(nom, { nameLang })).toMatchObject({ forme, regle });
  });

  it('espagnol : le seul dernier nom reste offert en variante', () => {
    expect(proposerPointAcces('Juan Carlos Mechoso', { nameLang: 'es' }).variante).toMatchObject({ forme: 'Mechoso, Juan Carlos', regle: 'direct' });
  });

  it('sans langue du nom : la règle prudente, le pays n’offre qu’une variante (jamais deviné, CONV-6)', () => {
    const p = proposerPointAcces('Edmondo De Amicis', { country: 'IT' });
    expect(p.forme).toBe('Amicis, Edmondo De');
    expect(p.regle).toBe('direct');
  });
});

describe('proposerCasseNom — la casse naturelle (CONV-1)', () => {
  it.each([
    ['osvaldo BAYER', 'Osvaldo Bayer'],
    ['Eric HOBSBAWM', 'Eric Hobsbawm'],
    ['FABIANO DE OLIVEIRA BRINGEL', 'Fabiano de Oliveira Bringel'],
    ['jean-paul SARTRE', 'Jean-Paul Sartre'],
    ['e. p. THOMPSON', 'E. P. Thompson'],
    ["conor O'BRIEN", "Conor O'Brien"],
    ["jean le rond D'ALEMBERT", "Jean le Rond d'Alembert"],
    ['alfredo VEIGA-NETO', 'Alfredo Veiga-Neto'],
    ['Mary Alice MC CABE', 'Mary Alice Mc Cabe'],
    ['VOLINE', 'Voline'],
  ])('%s → %s', (nom, attendu) => {
    expect(casse(nom)).toBe(attendu);
    expect(proposerCasseNom(nom).change).toBe(true);
  });

  it('un nom déjà en casse naturelle ne bouge pas', () => {
    for (const n of ['Osvaldo Bayer', 'Fabiano de Oliveira Bringel', 'Pio XII', 'Louis XIV', "Conor O'Brien", 'E. P. Thompson']) {
      expect(proposerCasseNom(n).change, n).toBe(false);
    }
  });

  it('chiffres romains et initiales sont figés ; le clic bascule la majuscule', () => {
    expect(proposerCasseNom('JEAN XXIII').mots.map((m) => m.fige)).toEqual([false, true]);
    expect(basculerMajuscule('hooks')).toBe('Hooks');
    expect(basculerMajuscule('De')).toBe('de');
  });
});

const casseOrg = (n, nameLang) => proposerCasseCollectivite(n, { nameLang });

describe('proposerCasseCollectivite — la casse d’un nom de collectivité', () => {
  it.each([
    ['CONFEDERACIÓN NACIONAL DEL TRABAJO', 'es', 'Confederación Nacional del Trabajo'],
    ['confederación nacional del trabajo', '', 'Confederación Nacional del Trabajo'],
    ['industrial workers of the world', 'en', 'Industrial Workers of the World'],
    ['Fédération Anarchiste', 'fr', 'Fédération anarchiste'],
    ['FÉDÉRATION ANARCHISTE', 'fr', 'Fédération anarchiste'],
  ])('%s (%s) → %s', (nom, lang, attendu) => {
    const p = casseOrg(nom, lang);
    expect(p.mots.map((m) => m.texte).join(' ')).toBe(attendu);
    expect(p.change).toBe(true);
  });

  it('sigles de toute longueur, noms déjà justes : rien à proposer', () => {
    for (const [n, l] of [['DIEESE', ''], ['CIRA Marseille', 'fr'], ['Centro de Cultura Social', ''],
      ['Confédération générale du travail', 'fr'], ['MOVIMENTO - Centro de Cultura e Autoformação', 'pt-BR'],
      ['Federação Operária de São Paulo', 'pt-BR']]) {
      expect(casseOrg(n, l).change, n).toBe(false);
    }
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

  it('casse : aperçu, clic sur un mot, appliquer puis annuler', () => {
    const onNom = vi.fn();
    const { rerender } = monter({ nom: 'EDMONDO DE AMICIS', formeActuelle: '', onChoisir: vi.fn(), onNom });
    fireEvent.click(screen.getByRole('button', { name: fr['catalogacao.titleCase.button'] }));
    expect(screen.getByTestId('name-case-after').textContent).toBe('Edmondo de Amicis');
    fireEvent.click(screen.getByRole('button', { name: 'de' }));            // l'usage italien : « De »
    fireEvent.click(screen.getByRole('button', { name: fr['catalogacao.titleCase.apply'] }));
    expect(onNom).toHaveBeenLastCalledWith('Edmondo De Amicis');
    rerender(<IntlProvider locale="fr" messages={fr}><NameEntryAssist nom="Edmondo De Amicis" formeActuelle="" onChoisir={vi.fn()} onNom={onNom} /></IntlProvider>);
    fireEvent.click(screen.getByRole('button', { name: fr['catalogacao.titleCase.undo'] }));
    expect(onNom).toHaveBeenLastCalledWith('EDMONDO DE AMICIS');
  });

  it('casse : rien à proposer pour un nom déjà naturel', () => {
    monter({ nom: 'Osvaldo Bayer', formeActuelle: '', onChoisir: vi.fn(), onNom: vi.fn() });
    expect(bouton('confirm')).toBeTruthy();
    expect(screen.queryByRole('button', { name: fr['catalogacao.titleCase.button'] })).toBeNull();
  });

  it('le formulaire d’autorité passe le nom par handlePreferredNameChange', () => {
    const src = readFileSync('src/pages/catalogacao/AuthorDraftForm.jsx', 'utf8');
    expect(src).toMatch(/onNom={handlePreferredNameChange}/);
  });

  it('la langue du nom est passée à la règle et son explication s’affiche', () => {
    monter({ nom: 'Edmondo De Amicis', nameLang: 'it', formeActuelle: '', onChoisir: vi.fn() });
    expect(screen.getByText('De Amicis, Edmondo')).toBeTruthy();
    expect(screen.getByText(fr['catalogacao.nameEntry.rule.kept'])).toBeTruthy();
  });

  it('le formulaire d’autorité saisit name_lang et la passe à l’assistant', () => {
    const src = readFileSync('src/pages/catalogacao/AuthorDraftForm.jsx', 'utf8');
    expect(src).toContain("nameLang={f('name_lang')}");
    expect(src).toMatch(/id="ab-author-name-lang"/);
  });

  it('collectivité : seul le bloc de casse, sans découpe « Nom, Prénom »', () => {
    const onNom = vi.fn();
    monter({ collectivite: true, nom: 'FÉDÉRATION ANARCHISTE', nameLang: 'fr', formeActuelle: '', onChoisir: vi.fn(), onNom });
    expect(screen.queryByText(fr['catalogacao.nameEntry.proposed'])).toBeNull();
    fireEvent.click(screen.getByRole('button', { name: fr['catalogacao.titleCase.button'] }));
    expect(screen.getByText(fr['catalogacao.nameEntry.caseExplainOrg'])).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: fr['catalogacao.titleCase.apply'] }));
    expect(onNom).toHaveBeenCalledWith('Fédération anarchiste');
  });

  it('le formulaire monte l’assistant pour une collectivité et y montre la langue du nom', () => {
    const src = readFileSync('src/pages/catalogacao/AuthorDraftForm.jsx', 'utf8');
    expect(src).toContain("<NameEntryAssist collectivite nom={f('preferred_name')}");
    expect(src).toContain("name_lang: ['person', 'collective'].includes(meta.authorityType) ? (f('name_lang') || null) : null");
  });
});
