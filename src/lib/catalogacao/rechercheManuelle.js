// src/lib/catalogacao/rechercheManuelle.js — 13/10/2026
// La recherche MANUELLE du panneau de recherche (onglet Document) : la personne
// qui catalogue choisit un catalogue dans une liste déroulante et le bouton
// ouvre sa page de recherche publique dans un nouvel onglet. La liste est celle
// des sources qu'AnarBib interroge automatiquement (LOOKUP_SOURCE_LABELS) — le
// test catalogacao-recherche-manuelle le vérifie : une source ajoutée à la
// recherche automatique doit avoir aussi son adresse ici.
// Chaque adresse a été ouverte le 13/10/2026 dans un navigateur, avec un titre
// (« Max Havelaar ») et un ISBN : toutes rendent des résultats. BNE, DNB et LoC
// sont des applications JavaScript (un curl n'en voit que la coquille) ; l'ICCU
// passe par le champ unique `monocampo` de sa recherche avancée.
// La BN Brasil filtre ses visiteurs par pays (Cloudflare) : mesuré le 13/10/2026,
// sa page de recherche répond 200 depuis São Paulo et 403 depuis la France,
// l'Allemagne, le Portugal et les États-Unis — tout bn.gov.br, accueil compris.
// Aucune adresse ne contourne ce filtre : l'option le dit (`depuisLeBresil`), et
// le catalogue proposé d'emblée suit la langue de l'interface.
// Ce ne sont pas des appels automatiques : un clic humain ouvre une page, ce que
// le robots.txt de dbnl.org (qui interdit les robots) n'empêche pas.
import { LOOKUP_SOURCE_LABELS } from './bookDraft';

const e = encodeURIComponent;

// Ordre de la liste : BN Brasil d'abord (ancien bouton), puis
// les bibliothèques nationales, puis les catalogues collectifs ouverts.
export const CATALOGUES_MANUELS = [
  { id: 'bn_brasil', depuisLeBresil: true, accueil: 'https://acervo.bn.gov.br/sophia_web/busca/acervo/', url: (q) => `https://acervo.bn.gov.br/sophia_web/busca/acervo/?q=${e(q)}` },
  { id: 'bne', accueil: 'https://catalogo.bne.es/discovery/search?vid=34BNE_INST:CATALOGO', url: (q) => `https://catalogo.bne.es/discovery/search?query=any,contains,${e(q)}&vid=34BNE_INST:CATALOGO` },
  { id: 'bnf', accueil: 'https://catalogue.bnf.fr/', url: (q) => `https://catalogue.bnf.fr/rechercher.do?motRecherche=${e(q)}` },
  { id: 'dnb', accueil: 'https://portal.dnb.de/opac/', url: (q) => `https://portal.dnb.de/opac/simpleSearch?query=${e(q)}` },
  { id: 'iccu', accueil: 'https://opac.sbn.it/', url: (q) => `https://opac.sbn.it/web/opacsbn/risultati-ricerca-avanzata?monocampo=${e(q)}` },
  { id: 'loc', accueil: 'https://search.catalog.loc.gov/', url: (q) => `https://search.catalog.loc.gov/search?query=${e(q)}` },
  { id: 'dbnl', accueil: 'https://www.dbnl.org/', url: (q) => `https://www.dbnl.org/zoeken/zoekeninteksten/index.php?zoek=${e(q)}` },
  { id: 'openlibrary', accueil: 'https://openlibrary.org/', url: (q) => `https://openlibrary.org/search?q=${e(q)}` },
  { id: 'wikidata', accueil: 'https://www.wikidata.org/', url: (q) => `https://www.wikidata.org/w/index.php?search=${e(q)}` },
].map((c) => ({ ...c, label: LOOKUP_SOURCE_LABELS[c.id] }));

export const CATALOGUE_MANUEL_DEFAUT = 'bn_brasil';
// Sans choix retenu : le catalogue de la langue de l'interface.
const CATALOGUE_PAR_LANGUE = { pt: 'bn_brasil', es: 'bne', ca: 'bne', fr: 'bnf', de: 'dnb', it: 'iccu', nl: 'dbnl', en: 'loc', eo: 'openlibrary', el: 'openlibrary' };
export function catalogueParDefaut(locale) {
  return CATALOGUE_PAR_LANGUE[String(locale || '').toLowerCase().split(/[-_]/)[0]] || CATALOGUE_MANUEL_DEFAUT;
}
// Le dernier catalogue choisi, retenu par navigateur (une commodité, pas une donnée).
export const CLE_CATALOGUE_MANUEL = 'anarbib.catalogacao.rechercheManuelle';

// Un identifiant inconnu (retiré de la liste, valeur retenue périmée) retombe sur
// le catalogue de la langue, à défaut sur BN Brasil.
export function catalogueManuel(id, locale) {
  return CATALOGUES_MANUELS.find((c) => c.id === id) || CATALOGUES_MANUELS.find((c) => c.id === catalogueParDefaut(locale));
}

// Ce qu'on cherche : l'ISBN s'il y en a un, sinon l'ISSN, sinon titre + auteur·rice.
export function requeteManuelle(f) {
  const isbn = (f('isbn') || '').replace(/[^0-9Xx]/g, '');
  if (isbn) return isbn;
  const issn = (f('issn') || '').trim();
  if (issn) return issn;
  return [f('titulo'), f('autor')].map((v) => (v || '').trim()).filter(Boolean).join(' ');
}

export function adresseRechercheManuelle(id, f, locale) {
  const c = catalogueManuel(id, locale);
  const q = requeteManuelle(f);
  return q ? c.url(q) : c.accueil;
}
