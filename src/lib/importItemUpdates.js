// ═══════════════════════════════════════════════════════════
// AnarBib — H21 lot 6b (08/10/2026, REGISTRE IMP-33 c) : la cote et la note
// d'un exemplaire, comme les notices. Module pur (sans React ni icône) :
// Importations et le rapport de révision le partagent.
//
// Lu dans fn_import_list_run_rows.exemplaires_maj (et les lignes que rend
// fn_import_recomparer) : {computed_at, deja_la, applicables, counts,
// items:[{n, constat, exemplar_id, tombo, verdicts:{shelf_location, notes},
// applicables, sans_base, draft_id, draft_status}]} — verdicts SANS valeurs
// (le détail, fn_import_row_comparison.exemplaires, les lit) ; NULL quand la
// comparaison manque ou est périmée (l'écran la redemande).
// ═══════════════════════════════════════════════════════════

// Les champs d'un exemplaire comparés à trois états, dans l'ordre de l'écran.
export const CHAMPS_EXEMPLAIRE = ['shelf_location', 'notes'];

// Les raisons pour lesquelles « Préparer la mise à jour » ignore un exemplaire
// (ingest.fn_h21_preparer_exemplaires), dans l'ordre du message : ce qui
// demande une action d'abord.
export const RAISONS_EXEMPLAIRES = ['signale', 'sans_base', 'rien_a_appliquer', 'brouillon_en_cours', 'deja_preparee',
  'rejetee', 'pas_au_catalogue', 'autre_bibliotheque', 'non_comparee'];

const aLaCle = (o, k) => !!o && Object.prototype.hasOwnProperty.call(o, k);

// Le plafond d'un appel de recalcul ou de préparation : 200 lignes ET 5 000
// exemplaires du fichier au plus (la base refuse au-delà :
// error.import.update_page_too_many_items ; même nombre que
// ingest.fn_h21_exemplaires_par_appel — revue sceptique du 08/10).
export const PLAFOND_LIGNES = 200;
export const PLAFOND_EXEMPLAIRES = 5000;

// Le nombre d'exemplaires du fichier d'une ligne (la liste les rend).
export function nombreExemplaires(r) {
  return r && Array.isArray(r.exemplaires) ? r.exemplaires.length : 0;
}

// Découpe des lignes en pages : au plus maxLignes lignes et maxExemplaires
// exemplaires par page (une ligne seule au-delà du plafond reste seule : la
// base dira le refus).
export function pagesParExemplaires(lignes, maxLignes = PLAFOND_LIGNES, maxExemplaires = PLAFOND_EXEMPLAIRES) {
  const pages = [];
  let page = [];
  let n = 0;
  for (const r of Array.isArray(lignes) ? lignes : []) {
    const k = nombreExemplaires(r);
    if (page.length && (page.length >= maxLignes || n + k > maxExemplaires)) {
      pages.push(page);
      page = [];
      n = 0;
    }
    page.push(r.id);
    n += k;
  }
  if (page.length) pages.push(page);
  return pages;
}

// Le nombre d'exemplaires « déjà là » que le geste préparerait sur cette ligne
// (cote ou note changée dans le fichier seulement, base présente, pas encore
// préparé, ligne non rejetée) — compté par la base.
export function exemplairesPreparables(r) {
  const m = r && r.exemplaires_maj;
  return m && typeof m === 'object' ? Number(m.applicables || 0) : 0;
}

// La comparaison des exemplaires manque (jamais calculée, ou périmée) : une
// ligne d'un serveur d'avant le lot 6b n'a pas la clé, rien à demander.
export function exemplairesAComparer(r) {
  return aLaCle(r, 'exemplaires_maj') && r.exemplaires_maj === null;
}

// L'exemplaire comparé d'un exemplaire du fichier (même rang n).
export function majDeLItem(maj, n) {
  if (!maj || !Array.isArray(maj.items)) return null;
  return maj.items.find((x) => x && Number(x.n) === Number(n)) || null;
}

// Les champs qui ont bougé (verdict autre que « inchangé »), dans l'ordre.
export function champsQuiBougent(verdicts) {
  if (!verdicts || typeof verdicts !== 'object') return [];
  return CHAMPS_EXEMPLAIRE.filter((c) => verdicts[c] && verdicts[c] !== 'inchange')
    .map((c) => ({ champ: c, verdict: verdicts[c] }));
}

// La partie « exemplaires » du message de « Préparer la mise à jour ».
export function partiesExemplaires(t, prepares, lot, ignorees) {
  const parties = [];
  if (Number(prepares || 0) > 0) {
    parties.push(t({ id: 'importacoes.fila.preparedItems' }, { n: Number(prepares), batch: lot ?? '—' }));
  }
  const liste = RAISONS_EXEMPLAIRES.filter((k) => Number(ignorees?.[k] || 0) > 0)
    .map((k) => t({ id: `importacoes.fila.prepareItemSkip.${k}` }, { n: Number(ignorees[k]) }));
  if (liste.length) parties.push(t({ id: 'importacoes.fila.prepareItemsSkipped' }, { list: liste.join(', ') }));
  return { parties, ignorees: liste.length };
}
