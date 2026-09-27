// Localisation d'un exemplaire (exemplar_drafts.shelf_location) : format
// structuré « Biblioteca: … · Setor/sala: … · Estante: … · Prateleira: … ·
// Observação: … », lu et écrit par le formulaire d'exemplaire.
//
// H19 (27/09/2026) : ce que le format structuré ne reconnaît pas n'est plus
// jeté. Une cote importée (995 $k « GR 949.5 PAP ») ou toute partie sans
// étiquette connue va dans `raw`, s'affiche, et se réécrit telle quelle :
// enregistrer le brouillon pour une autre raison ne l'efface plus.

const LABELS = [
  ['biblioteca', 'library'], ['setor/sala', 'sector'], ['estante', 'shelfUnit'],
  ['prateleira', 'shelfLevel'], ['observação', 'note'], ['observacao', 'note'], ['obs', 'note'],
];

const sansAccents = (s) => s.normalize('NFD').replace(/[̀-ͯ]/g, '');

export function emptyShelfLocation() {
  return { library: '', sector: '', shelfUnit: '', shelfLevel: '', note: '', raw: '' };
}

export function parseShelfLocation(raw) {
  const clean = (raw || '').replace(/\s+/g, ' ').trim();
  const parsed = emptyShelfLocation();
  if (!clean) return parsed;
  const unmatched = [];
  for (const part of clean.split(/\s+·\s+/)) {
    const sep = part.indexOf(':');
    const lbl = sep === -1 ? '' : sansAccents(part.slice(0, sep).replace(/\s+/g, ' ').trim()).toLowerCase();
    const val = sep === -1 ? '' : part.slice(sep + 1).trim();
    const entry = LABELS.find(([l]) => sansAccents(l) === lbl);
    if (entry && !val) continue;                        // « Estante: » vide : rien à garder
    if (entry && !parsed[entry[1]]) parsed[entry[1]] = val;
    else unmatched.push(part);                          // cote brute, étiquette inconnue ou répétée
  }
  parsed.raw = unmatched.join(' · ');
  return parsed;
}

export function formatShelfLocation(parts) {
  const p = parts || {};
  return [
    ...[['Biblioteca', p.library], ['Setor/sala', p.sector], ['Estante', p.shelfUnit], ['Prateleira', p.shelfLevel], ['Observação', p.note]]
      .filter(([, v]) => (v || '').trim()).map(([l, v]) => `${l}: ${v.trim()}`),
    ...((p.raw || '').trim() ? [p.raw.trim()] : []),
  ].join(' · ');
}
