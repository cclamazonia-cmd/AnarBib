// Le formulaire de notice découpé (E6, 23/10/2026) : la page, son hook
// d'enregistrement et ses sections, lus ensemble — les tests qui cherchaient un
// geste ou un appel « dans BookDraftForm » le trouvent dans le fichier où il vit
// désormais, tel quel. La page vient en premier : un ordre lu dans la page
// (indexOf) reste celui de la page.
import { readFileSync } from 'node:fs';
import path from 'node:path';

export const FICHIERS_NOTICE = [
  'BookDraftForm.jsx', 'useNoticePersistance.js', 'BookCoverPanel.jsx',
  'BookCreationChoice.jsx', 'BookWorkPanel.jsx', 'BookDuplicatesPanel.jsx',
];

export function sourceNotice() {
  return FICHIERS_NOTICE
    .map((f) => readFileSync(path.resolve(__dirname, `../../pages/catalogacao/${f}`), 'utf8'))
    .join('\n');
}
