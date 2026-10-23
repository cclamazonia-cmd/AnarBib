// La page Importations découpée (E6, 23/10/2026) : la page, ses aides et ses
// sections, lues ensemble — les tests qui cherchaient un geste ou un appel
// « dans la page » le trouvent dans le fichier où il vit désormais, tel quel.
import { readFileSync } from 'node:fs';
import path from 'node:path';

export const FICHIERS_IMPORTACOES = [
  'ImportacoesPage', 'importacoesOutils', 'ImportAdapterStrip', 'ImportAddRecords',
  'ImportRunsList', 'ImportReviewQueue', 'ImportExportFace',
];

export function sourceImportacoes() {
  return FICHIERS_IMPORTACOES
    .map((f) => readFileSync(path.resolve(__dirname, `../../pages/importacoes/${f}.jsx`), 'utf8'))
    .join('\n');
}
