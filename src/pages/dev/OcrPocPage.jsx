/**
 * OcrPocPage.jsx — page jetable de test du POC OCR navigateur (P1).
 *
 * Route /dev/ocr (publique, non gardée) pour tester en `npm run dev`.
 * À retirer / remplacer quand l'OCR rejoint le wizard d'import (P2+).
 * Cadrage : docs/journal/cadrages/CADRAGE_ocr_import_navigateur_2026-06-17.md
 */

import OcrImportPanel from '@/components/ocr/OcrImportPanel';

export default function OcrPocPage() {
  return <OcrImportPanel />;
}
