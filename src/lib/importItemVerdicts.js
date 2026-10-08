// ═══════════════════════════════════════════════════════════
// AnarBib — H21 lot 6a (08/10/2026, REGISTRE IMP-33) : les verdicts du constat
// des exemplaires d'un fichier importé (ingest.fn_h21_constat_exemplaire), leur
// libellé et le résumé du message de « Rapprocher ». Module pur (sans React ni
// icône) : Importations et le rapport de révision le partagent.
// ═══════════════════════════════════════════════════════════

export const VERDICTS = ['nouveau', 'deja_la', 'deja_en_brouillon', 'sans_code', 'deplace', 'reetiquete', 'code_repris'];
// Les verdicts qui demandent un regard (la ligne n'est pas rejetée d'office).
export const SIGNAUX = ['sans_code', 'deplace', 'reetiquete', 'code_repris'];

// Le libellé d'un verdict, avec ses paramètres (notice de la ligne, notice où
// l'exemplaire est dans AnarBib, ancien code).
export function libelleVerdict(t, it, titreLigne) {
  const v = it?.verdict;
  if (!v || !VERDICTS.includes(v)) return t({ id: 'importacoes.items.verdict.none' });
  return t({ id: `importacoes.items.verdict.${v}` }, {
    notice: titreLigne || '—',
    ailleurs: it.book_titulo || (it.book_id ? `#${it.book_id}` : '—'),
    ancien: it.ancien_code || '—',
    nouveau: it.code || '—',
  });
}

// Le message de « Rapprocher » : les comptes par verdict (ceux qui valent plus
// de zéro, dans l'ordre de VERDICTS) et les lignes signalées, laissées sans
// brouillon ni rejet. '' sans verdicts (serveur d'avant le lot 6a).
export function resumeVerdicts(t, verdicts, lignesSignalees = 0) {
  if (!verdicts || typeof verdicts !== 'object') return '';
  const parts = VERDICTS.filter((v) => Number(verdicts[v] || 0) > 0)
    .map((v) => t({ id: `importacoes.items.count.${v}` }, { n: Number(verdicts[v]) }));
  if (!parts.length) return '';
  const texte = t({ id: 'importacoes.items.counts' }, { list: parts.join(', ') });
  return Number(lignesSignalees) > 0
    ? `${texte} ${t({ id: 'importacoes.items.rowsSignalled' }, { n: Number(lignesSignalees) })}`
    : texte;
}
