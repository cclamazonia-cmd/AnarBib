// src/components/catalog/CatalogExportActions.jsx — E6, Catalogue public, lot 2 (10/10/2026)
// Les deux boutons d'export de la bannière du catalogue (impression, CSV), sortis de
// CatalogPage.jsx tels quels ; ils reçoivent la liste affichée et le traducteur.
import { Button } from '@/components/ui';
import { exportCSV, exportPDF } from '@/lib/catalogOpac';

export default function CatalogExportActions({ books, t }) {
  return (
    <>
      <Button onClick={() => exportPDF(books, t)}>{t({ id: 'catalog.export.pdf' })}</Button>
      <Button variant="secondary" onClick={() => exportCSV(books)}>{t({ id: 'catalog.export.csv' })}</Button>
    </>
  );
}
