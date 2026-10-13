// ═════════════════════════════════════════════════
// AnarBib — recherche manuelle du catalogage (13/10/2026)
// Le bouton « Ouvrir la recherche manuelle » (onglet Document) n'ouvrait que la
// BN Brasil. Il est précédé d'une liste déroulante des catalogues qu'AnarBib
// interroge automatiquement ; le bouton ouvre la recherche dans le catalogue
// choisi, retenu par navigateur.
//   * la liste couvre exactement les sources de la recherche automatique ;
//   * chaque adresse cherche l'ISBN, sinon l'ISSN, sinon titre + auteur·rice ;
//   * le panneau rendu ouvre le bon catalogue et retient le choix ;
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
import { CATALOGUES_MANUELS, CLE_CATALOGUE_MANUEL, adresseRechercheManuelle, requeteManuelle } from '@/lib/catalogacao/rechercheManuelle';

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
    expect(adresseRechercheManuelle('inconnu', champs({ titulo: 'x' }))).toBe('https://acervo.bn.gov.br/sophia_web/busca/acervo/?q=x');
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

  it('la liste propose les neuf catalogues, BN Brasil par défaut ; le bouton ouvre le catalogue choisi', () => {
    const ouvrir = vi.spyOn(window, 'open').mockImplementation(() => null);
    const setMsg = monter({ titulo: 'Max Havelaar', autor: 'Multatuli' });
    const liste = screen.getByLabelText('Catalogue de la recherche manuelle');
    expect([...liste.options].map((o) => o.textContent)).toEqual(CATALOGUES_MANUELS.map((c) => c.label));
    expect(liste.value).toBe('bn_brasil');
    fireEvent.change(liste, { target: { value: 'dbnl' } });
    fireEvent.click(screen.getByText('Ouvrir la recherche manuelle'));
    expect(ouvrir).toHaveBeenCalledWith('https://www.dbnl.org/zoeken/zoekeninteksten/index.php?zoek=Max%20Havelaar%20Multatuli', '_blank', 'noopener');
    expect(setMsg).toHaveBeenLastCalledWith({ text: 'DBNL : recherche ouverte dans un nouvel onglet.', kind: 'info' });
    expect(localStorage.getItem(CLE_CATALOGUE_MANUEL)).toBe('dbnl');
  });

  it('retient le dernier catalogue choisi ; une valeur retenue inconnue retombe sur BN Brasil', () => {
    localStorage.setItem(CLE_CATALOGUE_MANUEL, 'loc');
    monter({});
    expect(screen.getByLabelText('Catalogue de la recherche manuelle').value).toBe('loc');
    cleanup();
    localStorage.setItem(CLE_CATALOGUE_MANUEL, 'disparu');
    monter({});
    expect(screen.getByLabelText('Catalogue de la recherche manuelle').value).toBe('bn_brasil');
  });
});

describe('recherche manuelle — locales', () => {
  it('les trois clés existent dans les dix locales, les deux anciennes ont disparu', () => {
    const dir = path.join(RACINE, 'src/i18n/locales');
    const fichiers = readdirSync(dir).filter((f) => f.endsWith('.json'));
    expect(fichiers).toHaveLength(10);
    for (const f of fichiers) {
      const j = JSON.parse(readFileSync(path.join(dir, f), 'utf8'));
      for (const k of ['catalogacao.ui.manualSearch', 'catalogacao.ui.manualSearchCatalog', 'catalogacao.msg.manualSearchOpened']) {
        expect(typeof j[k], `${f} ${k}`).toBe('string');
      }
      expect(j['catalogacao.msg.manualSearchOpened'], f).toContain('{catalogue}');
      expect(j['catalogacao.ui.bnManual'], f).toBeUndefined();
      expect(j['catalogacao.msg.bnOpened'], f).toBeUndefined();
    }
  });
});
