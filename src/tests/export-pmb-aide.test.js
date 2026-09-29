// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/export-pmb-aide.test.js
//
// CE QUE CE TEST PROTÈGE (revues de la fin de H27, 29/09/2026). L'écran
// Importations dit, sous le format d'export choisi, comment entrer le fichier
// dans PMB. Deux réglages de PMB décident de tout, et l'aide les taisait :
//   - l'onglet : « Exemplaires UNIMARC » importe notices et exemplaires ;
//     l'onglet voisin, « Notices UNIMARC », ignore les 995 sans le dire ;
//   - « Générer les liens entre notices ? » : « Non » par défaut ; sans lui,
//     aucun article n'est rattaché à sa revue (mesuré au banc : 0 sur 15).
// Et elle recommandait « Oui » à « Tenir compte des notices d'autorités » avec
// l'origine AnarBib, que le formulaire de PMB 8.1.1.1 ne transmet pas (mesuré :
// des liens vers des sources absentes, aucun auteur de plus rapproché).
// Les libellés sont ceux que PMB affiche dans la langue de la locale
// (includes/messages/<langue>.xml, codes 520, 500, import_genere_liens) ; le
// grec et l'espéranto, que PMB ne connaît pas, citent le PMB français.
// Mesures et marche à suivre : docs/interop/couverture-pmb.md, tests/pmb/README.md.
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const RACINE = path.resolve(here, '..', '..');
const locale = (l) => JSON.parse(readFileSync(path.join(RACINE, 'src', 'i18n', 'locales', `${l}.json`), 'utf8'));
const ecran = readFileSync(path.join(RACINE, 'src', 'pages', 'importacoes', 'ImportacoesPage.jsx'), 'utf8');

const FR = ['Exemplaires UNIMARC', 'Notices UNIMARC', 'Générer les liens entre notices ?'];
const PMB = {
  fr: FR, el: FR, eo: FR,
  'pt-BR': ['Itens UNIMARC', 'Registros UNIMARC', 'Gerar vínculo entre registros?'],
  es: ['Ejemplares UNIMARC', 'Registro UNIMARC', '¿Generar enlace entre noticias?'],
  en: ['UNIMARC Items', 'UNIMARC Records', 'Generate links between records?'],
  de: ['UNIMARC Items', 'UNIMARC Records', 'Generate links between records?'],
  ca: ['Exemplars UNIMARC', 'Registres UNIMARC', 'Generar els enllaços entre registres ?'],
  it: ['Esemplari UNIMARC', 'Schede UNIMARC', 'Generare i collegamenti tra le schede ?'],
  nl: ['UNIMARC exemplaren', 'UNIMARC beschrijvingen', 'Générer les liens entre notices ?'],
};
const LOCALES = Object.keys(PMB);

describe('export vers PMB — l\'aide de l\'écran dit les réglages qui décident', () => {
  it('dix locales', () => expect(LOCALES).toHaveLength(10));

  it.each(LOCALES)('%s : sous le catalogue, l\'onglet qui importe les exemplaires, celui qui les ignore, le réglage des liens', (l) => {
    const aide = locale(l)['importacoes.export.lote.pmbHint'];
    expect(aide, 'clé absente').toBeTruthy();
    for (const libelle of PMB[l]) expect(aide).toContain(libelle);
    expect(aide).toContain('Catégories RAMEAU');
  });

  it.each(LOCALES)('%s : sous les autorités, l\'ordre des fichiers, et « Non » à l\'option que PMB 8.1 ne sait pas servir', (l) => {
    const aide = locale(l)['importacoes.export.lote.autoritesHint'];
    expect(aide).toContain('PMB 8.1');
    expect(aide).toContain('UNIMARC — ISO 2709');
    // l'origine AnarBib n'est plus recommandée : le formulaire de PMB ne la transmet pas
    expect(aide).not.toContain('AnarBib');
  });

  it('chaque aide est montrée sous son format', () => {
    expect(ecran).toMatch(/exportFormat === 'unimarc_iso2709' && \(\s*<p [^>]*>\{t\(\{ id: 'importacoes\.export\.lote\.pmbHint' \}\)\}<\/p>/);
    expect(ecran).toMatch(/exportFormat === 'unimarc_autorites' && \(\s*<p [^>]*>\{t\(\{ id: 'importacoes\.export\.lote\.autoritesHint' \}\)\}<\/p>/);
  });
});
