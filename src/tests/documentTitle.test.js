// ═══════════════════════════════════════════════════════════
// AnarBib — titre du document (item E7)
//
// Le hook `useDocumentTitle` existe depuis le 05/05/2026 et 32 pages
// l'utilisent — mais rien ne le testait, et le backlog a porté pendant des
// mois un constat affirmant que le titre ne suivait pas la navigation. Un
// mécanisme sans test est un mécanisme dont on finit par douter par écrit.
//
// Sur le modèle de documentLanguage.test.js : ce qui ne se voit pas à
// l'écran — l'onglet du navigateur, l'historique, le lecteur d'écran qui
// annonce la page — doit se vérifier. On teste ici le CONTRAT du hook,
// navigation comprise ; la couverture des pages qui ne l'appellent pas
// reste l'affaire du premier critère de E7.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, beforeEach } from 'vitest';
import { render, cleanup } from '@testing-library/react';
import { createElement } from 'react';
import { useDocumentTitle } from '@/lib/useDocumentTitle';

function Page({ title }) {
  useDocumentTitle(title);
  return null;
}

describe('titre du document', () => {
  beforeEach(() => {
    cleanup();
    // Valeur volontairement fausse : un test qui passerait parce que le titre
    // valait déjà la bonne chose ne prouverait rien.
    document.title = '__titre-perime__';
  });

  it('affiche « <page> — AnarBib » quand la page donne un titre', () => {
    render(createElement(Page, { title: 'Catálogo' }));
    expect(document.title).toBe('Catálogo — AnarBib');
  });

  it('retombe sur « AnarBib » seul quand la page ne donne rien', () => {
    render(createElement(Page, { title: '' }));
    expect(document.title).toBe('AnarBib');
  });

  it('ne double pas la marque quand le titre EST la marque', () => {
    render(createElement(Page, { title: 'AnarBib' }));
    expect(document.title).toBe('AnarBib');
  });

  it('suit la navigation : la page suivante remplace la précédente', () => {
    const a = render(createElement(Page, { title: 'Biblioteca' }));
    expect(document.title).toBe('Biblioteca — AnarBib');
    a.unmount();
    render(createElement(Page, { title: 'Conta' }));
    expect(document.title).toBe('Conta — AnarBib');
  });

  it('suit un titre qui change en place (page dynamique, livre chargé)', () => {
    const r = render(createElement(Page, { title: 'Carregando…' }));
    expect(document.title).toBe('Carregando… — AnarBib');
    r.rerender(createElement(Page, { title: 'Germinal' }));
    expect(document.title).toBe('Germinal — AnarBib');
  });

  it('ne restaure PAS le titre au démontage — choix documenté du hook', () => {
    // Entre l'unmount d'une page et le mount de la suivante, restaurer ferait
    // clignoter l'onglet vers « AnarBib ». Le hook de la page suivante prend
    // le relais ; en attendant, le dernier titre reste.
    const r = render(createElement(Page, { title: 'Federação' }));
    r.unmount();
    expect(document.title).toBe('Federação — AnarBib');
  });
});
