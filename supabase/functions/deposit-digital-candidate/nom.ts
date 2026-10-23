// Nom de fichier d'un PDF versé (NUMDIF D16 ; points fusionnés le 16/10/2026).
// Session : File de candidats PDF.
//
// Le chemin final est books/<book_id>/<horodatage>_<nom>.pdf, et
// ingest.fn_digital_candidate_deposit_record refuse tout chemin qui contient
// « .. » (garde anti-traversée, à garder). Or un nom de wiki peut porter des
// points de suspension : « …_slot....pdf », « …_2016-2-10_..pdf »,
// « Nationalisme..._een… » — la première version les gardait, le chemin
// contenait « .. » et quatre candidats d'Anarchief étaient refusés le 15/10.
// Désormais : suites de points fusionnées en un seul, points de fin de base
// retirés (sinon « base. » + « .pdf » referait « .. »).
// D25 (23/10/2026) : un document Word/ODT garde SON extension (.doc, .docx,
// .odt) — c'est à elle que la base le reconnaît ; par défaut, .pdf comme avant.
// Garde : src/tests/numdif-nom-de-fichier.test.js.

export function sanitize(name: string, ext = 'pdf'): string {
  const base = String(name || 'candidat').replace(new RegExp(`\\.${ext}$`, 'i'), '').normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^\w.\-]+/g, '_').replace(/_+/g, '_').replace(/\.{2,}/g, '.')
    .slice(0, 100).replace(/\.+$/, '') || 'candidat';
  return `${base}.${ext}`;
}
