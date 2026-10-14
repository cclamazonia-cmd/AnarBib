// ═════════════════════════════════════════════════
// AnarBib — recherche manuelle du catalogage (13/10/2026)
// Le bouton « Ouvrir la recherche manuelle » (onglet Document) n'ouvrait que la
// BN Brasil. Il est précédé d'une liste déroulante des catalogues qu'AnarBib
// interroge automatiquement ; le bouton ouvre la recherche dans le catalogue
// choisi, retenu par navigateur.
//   * la liste couvre exactement les sources de la recherche automatique ;
//   * chaque adresse cherche l'ISBN, sinon l'ISSN, sinon titre + auteur·rice ;
//   * le panneau rendu ouvre le bon catalogue et retient le choix ; sans choix
//     retenu, il part du catalogue de la langue ; la BN Brasil, qui n'accepte
//     que les connexions depuis le Brésil (Cloudflare, mesuré le 13/10), le dit ;
//   * intitulé, liste et bouton forment un seul groupe nommé (le lien entre la
//     liste et le bouton doit se voir et s'entendre) ;
//   * les clés existent dans les dix locales, les anciennes ont disparu.
// ═════════════════════════════════════════════════

import { describe, it, expect, vi, afterEach, beforeEach } from 'vitest';
import { render, screen, fireEvent, cleanup } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';

vi.mock('@/lib/supabase', () => ({ supabase: { functions: { invoke: vi.fn() } } }));
vi.mock('@/pages/painel/tabs/CardScanner', () => ({ default: () => null }));

import LookupPanel from '@/pages/catalogacao/LookupPanel';
import { LOOKUP_SOURCE_LABELS } from '@/lib/catalogacao/bookDraft';
import { CATALOGUES_MANUELS, CLE_CATALOGUE_MANUEL, adresseRechercheManuelle, requeteManuelle, catalogueParDefaut } from '@/lib/catalogacao/rechercheManuelle';
import { LOCALE_CODES } from '../i18n/locales.js';

const RACINE = path.resolve(__dirname, '../..');
const fr = JSON.parse(readFileSync(path.join(RACINE, 'src/i18n/locales/fr.json'), 'utf8'));
const champs = (v) => (k) => v[k] || '';

beforeEach(() => { try { localStorage.clear(); } catch { /* jsdom sans stockage */ } });
afterEach(() => { cleanup(); vi.restoreAllMocks(); });

describe('recherche manuelle — liste des catalogues', () => {
  it('couvre exactement les sources de la recherche automatique, BN Brasil en tête', () => {
    expect(CATALOGUES_MANUELS.map((c) => c.id).sort()).toEqual(Object.keys(LOOKUP_SOURCE_LABELS).sort());
    expect(CATALOGUES_MANUELS[0].id).toBe('bn_brasil');
    for (const c of CATALOGUES_MANUELS) {
      expect(c.label, c.id).toBe(LOOKUP_SOURCE_LABELS[c.id]);
      expect(c.accueil.startsWith('https://'), c.id).toBe(true);
      expect(c.url('x').startsWith('https://'), c.id).toBe(true);
    }
  });

  it('cherche l ISBN nettoyé, sinon l ISSN, sinon titre + auteur·rice ; rien saisi : la page d accueil', () => {
    expect(requeteManuelle(champs({ isbn: '90-6550-017-0', titulo: 'T' }))).toBe('9065500170');
    expect(requeteManuelle(champs({ issn: '0028-0836', titulo: 'T' }))).toBe('0028-0836');
    expect(requeteManuelle(champs({ titulo: ' Max Havelaar ', autor: 'Multatuli' }))).toBe('Max Havelaar Multatuli');
    expect(adresseRechercheManuelle('iccu', champs({ titulo: 'Max Havelaar' })))
      .toBe('https://opac.sbn.it/web/opacsbn/risultati-ricerca-avanzata?monocampo=Max%20Havelaar');
    expect(adresseRechercheManuelle('bne', champs({ isbn: '9789065500175' })))
      .toBe('https://catalogo.bne.es/discovery/search?query=any,contains,9789065500175&vid=34BNE_INST:CATALOGO');
    expect(adresseRechercheManuelle('dbnl', champs({}))).toBe('https://www.dbnl.org/');
    // DNB : /opac/ répond 404, la page du catalogue est opac.htm (13/10/2026)
    expect(adresseRechercheManuelle('dnb', champs({}))).toBe('https://portal.dnb.de/opac.htm');
    expect(adresseRechercheManuelle('dnb', champs({ titulo: 'Max Havelaar' })))
      .toBe('https://portal.dnb.de/opac.htm?method=simpleSearch&query=Max%20Havelaar');
    expect(adresseRechercheManuelle('inconnu', champs({ titulo: 'x' }))).toBe('https://acervo.bn.gov.br/sophia_web/busca/acervo/?q=x');
    expect(adresseRechercheManuelle('inconnu', champs({ titulo: 'x' }), 'fr')).toBe('https://catalogue.bnf.fr/rechercher.do?motRecherche=x');
  });

  it('sans choix retenu, le catalogue de la langue de l interface', () => {
    expect(catalogueParDefaut('pt-BR')).toBe('bn_brasil');
    expect(catalogueParDefaut('fr')).toBe('bnf');
    expect(catalogueParDefaut('es')).toBe('bne');
    expect(catalogueParDefaut('ca')).toBe('bne');
    expect(catalogueParDefaut('de')).toBe('dnb');
    expect(catalogueParDefaut('it')).toBe('iccu');
    expect(catalogueParDefaut('nl')).toBe('dbnl');
    expect(catalogueParDefaut('en')).toBe('loc');
    expect(catalogueParDefaut('eo')).toBe('openlibrary');
    expect(catalogueParDefaut('el')).toBe('openlibrary');
    expect(catalogueParDefaut(undefined)).toBe('bn_brasil');
  });
});

describe('recherche manuelle — le panneau rendu', () => {
  const monter = (valeurs) => {
    const setMsg = vi.fn();
    render(
      <IntlProvider locale="fr" messages={fr}>
        <LookupPanel f={champs(valeurs)} draftId="" setMsg={setMsg} onIsbnScanned={() => {}} onApplyCandidate={() => {}} />
      </IntlProvider>,
    );
    return setMsg;
  };

  it('la liste propose les neuf catalogues, la BnF d emblée en français, BN Brasil signalée ; le bouton ouvre le catalogue choisi', () => {
    const ouvrir = vi.spyOn(window, 'open').mockImplementation(() => null);
    const setMsg = monter({ titulo: 'Max Havelaar', autor: 'Multatuli' });
    const liste = screen.getByRole('combobox', { name: 'Recherche manuelle dans' });
    expect([...liste.options].map((o) => o.textContent)).toEqual(
      CATALOGUES_MANUELS.map((c) => (c.id === 'bn_brasil' ? 'BN Brasil (depuis le Brésil seulement)' : c.label)),
    );
    expect(liste.value).toBe('bnf');
    fireEvent.change(liste, { target: { value: 'dbnl' } });
    fireEvent.click(screen.getByRole('button', { name: 'Ouvrir' }));
    expect(ouvrir).toHaveBeenCalledWith('https://www.dbnl.org/zoeken/zoekeninteksten/index.php?zoek=Max%20Havelaar%20Multatuli', '_blank', 'noopener');
    expect(setMsg).toHaveBeenLastCalledWith({ text: 'DBNL : recherche ouverte dans un nouvel onglet.', kind: 'info' });
    expect(localStorage.getItem(CLE_CATALOGUE_MANUEL)).toBe('dbnl');
  });

  it('intitulé, liste et bouton forment un seul groupe nommé « Recherche manuelle dans »', () => {
    monter({});
    const groupe = screen.getByRole('group', { name: 'Recherche manuelle dans' });
    expect(groupe.classList.contains('cat-recherche-manuelle')).toBe(true);
    expect(groupe.querySelector('select')).toBe(screen.getByRole('combobox', { name: 'Recherche manuelle dans' }));
    const bouton = screen.getByRole('button', { name: 'Ouvrir' });
    expect(groupe.contains(bouton)).toBe(true);
    expect(bouton.parentElement).toBe(groupe.querySelector('select').parentElement); // soudés dans le même champ
  });

  it('retient le dernier catalogue choisi ; une valeur retenue inconnue retombe sur le catalogue de la langue', () => {
    localStorage.setItem(CLE_CATALOGUE_MANUEL, 'loc');
    monter({});
    expect(screen.getByRole('combobox', { name: 'Recherche manuelle dans' }).value).toBe('loc');
    cleanup();
    localStorage.setItem(CLE_CATALOGUE_MANUEL, 'disparu');
    monter({});
    expect(screen.getByRole('combobox', { name: 'Recherche manuelle dans' }).value).toBe('bnf');
  });
});

describe('recherche manuelle — locales', () => {
  it('les quatre clés existent dans les dix locales, les deux anciennes ont disparu', () => {
    const dir = path.join(RACINE, 'src/i18n/locales');
    const fichiers = readdirSync(dir).filter((f) => f.endsWith('.json'));
    expect(fichiers).toHaveLength(LOCALE_CODES.length);
    for (const f of fichiers) {
      const j = JSON.parse(readFileSync(path.join(dir, f), 'utf8'));
      for (const k of ['catalogacao.ui.manualSearch', 'catalogacao.ui.manualSearchCatalog', 'catalogacao.msg.manualSearchOpened', 'catalogacao.ui.manualSearchBrazilOnly']) {
        expect(typeof j[k], `${f} ${k}`).toBe('string');
      }
      expect(j['catalogacao.msg.manualSearchOpened'], f).toContain('{catalogue}');
      expect(j['catalogacao.ui.manualSearchBrazilOnly'], f).toContain('{catalogue}');
      expect(j['catalogacao.ui.bnManual'], f).toBeUndefined();
      expect(j['catalogacao.msg.bnOpened'], f).toBeUndefined();
    }
  });
});
