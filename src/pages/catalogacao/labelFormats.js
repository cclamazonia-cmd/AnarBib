// ═══════════════════════════════════════════════════════════
// Catalogue de formats de planches d'étiquettes commerciales pour
// LabelSheetPrinter. Cotes en millimètres.
//
// `verified: true`  → cotes ET marges reprises des fiches techniques
//                      officielles du fabricant (voir sources dans la
//                      conversation qui a introduit ce fichier).
// `verified: false` → dimensions de l'étiquette confirmées, mais marges
//                      ESTIMÉES (grille centrée sur la page, sans
//                      gouttière) faute de fiche technique accessible en
//                      ligne au moment de l'écriture. À affiner via le
//                      format "Personalizado" si l'impression réelle sur
//                      planche achetée dans le commerce ne tombe pas pile.
// ═══════════════════════════════════════════════════════════

export const CUSTOM_FORMAT_ID = 'custom';

export const PAGE_SIZES = {
  a4: { width: 210, height: 297, label: 'A4' },
  carta: { width: 215.9, height: 279.4, label: 'Carta (Letter)' },
};

export const LABEL_FORMATS = [
  {
    id: 'avery_l7160',
    name: 'Avery L7160 / Zweckform L7160 / Herma 4677',
    page: 'a4',
    cell: { width: 63.5, height: 38.1, radius: 1.5 },
    cols: 3,
    rows: 7,
    margin: { top: 15.15, bottom: 15.15, left: 7.25, right: 7.25 },
    gap: { h: 2.5, v: 0 },
    verified: true,
  },
  {
    id: 'avery_l7163',
    name: 'Avery L7163 / Zweckform L7163',
    page: 'a4',
    cell: { width: 99.1, height: 38.1, radius: 1.5 },
    cols: 2,
    rows: 7,
    margin: { top: 15.15, bottom: 15.15, left: 4.9, right: 4.9 },
    gap: { h: 2, v: 0 },
    verified: true,
  },
  {
    id: 'avery_l7654',
    name: 'Avery L7654 / Zweckform L7654',
    page: 'a4',
    cell: { width: 45.7, height: 25.4, radius: 1.5 },
    cols: 4,
    rows: 10,
    margin: { top: 21.5, bottom: 21.5, left: 13.65, right: 13.65 },
    gap: { h: 0, v: 0 },
    verified: false,
  },
  {
    id: 'pimaco_6180',
    name: 'Pimaco 6080 / 6180 / 6280',
    page: 'carta',
    cell: { width: 66.7, height: 25.4, radius: 0 },
    cols: 3,
    rows: 10,
    margin: { top: 12.7, bottom: 12.7, left: 7.9, right: 7.9 },
    gap: { h: 0, v: 0 },
    verified: false,
  },
  {
    id: 'pimaco_6183',
    name: 'Pimaco 6083 / 6183 / 6283',
    page: 'carta',
    cell: { width: 101.6, height: 50.8, radius: 0 },
    cols: 2,
    rows: 5,
    margin: { top: 12.7, bottom: 12.7, left: 6.35, right: 6.35 },
    gap: { h: 0, v: 0 },
    verified: false,
  },
];

export const DEFAULT_FORMAT_ID = 'avery_l7160';

// Valeurs de départ raisonnables quand on bascule sur "Personalizado" sans
// format actif à copier (ne devrait normalement pas arriver, cf. l'appelant
// qui pré-remplit toujours depuis le format precedemment selectionne).
export const BLANK_CUSTOM_FORMAT = {
  page: 'a4',
  cell: { width: 63.5, height: 38.1, radius: 0 },
  cols: 3,
  rows: 7,
  margin: { top: 15, bottom: 15, left: 7, right: 7 },
  gap: { h: 2, v: 0 },
};

export function labelsPerPage(format) {
  return format.cols * format.rows;
}

export function pageSizeOf(format) {
  return PAGE_SIZES[format.page] || PAGE_SIZES.a4;
}
