// ═══════════════════════════════════════════════════════════
// AnarBib — H21 lot 7 (09/10/2026, REGISTRE IMP-26 d/e/f, IMP-34) : les
// exemplaires retirés. Module pur (sans React ni icône) : Importations, le
// rapport de révision, le catalogage et le récolement le partagent.
//
// « Retiré » est un constat réversible, pas un désherbage : un exemplaire
// importé qui a disparu d'un export COMPLET de sa source est proposé en
// révision du lot ; posé, il est « sorti du catalogue d'origine » — non
// prêtable, masqué à l'OPAC, exclu de l'export, jamais supprimé ; levé s'il
// réapparaît.
//
// Lu dans public.fn_import_retraits(run, limite, décalage) : {export_complet,
// confirme, confirme_par, confirme_le, items_du_fichier, lignes_en_echec,
// bloque_retraits, bloque_levees, counts:{disparu, disparu_engage,
// disparu_brouillon, retire_reapparu, hors_fichier, retires}, seuil:{disparus,
// total, taux, pourcentage, minimum, atteint}, proposables:{retraits, levees},
// items:[{exemplar_id, verdict, motif, draft_id, draft_nature, book_id,
// titulo, tombo, code, expl_id, constat}]}.
// ═══════════════════════════════════════════════════════════

// Les verdicts du constat, dans l'ordre de l'écran.
export const VERDICTS_RETRAITS = ['disparu', 'disparu_engage', 'disparu_brouillon', 'retire_reapparu'];

// Ce qui engage un disparu (il n'est pas proposé, il le sera au réimport
// suivant ; rien n'est annulé chez personne).
export const MOTIFS_ENGAGE = ['pret', 'reservation', 'peb', 'consultation'];

// Pourquoi rien n'est proposé (la base le dit : bloque_retraits, bloque_levees).
// run_archive / run_perime (revue sceptique du 10/10) : seul le fichier ACTUEL
// de la source — son run le plus récent non archivé — propose.
export const BLOCAGES = ['sans_bibliotheque', 'run_archive', 'run_perime', 'run_en_cours', 'lignes_en_echec', 'fichier_sans_exemplaires',
  'pas_export_complet', 'seuil_non_confirme'];

// Le plafond de brouillons par appel du geste (ingest.fn_h21_retraits_par_appel) :
// l'écran rappelle tant qu'il en reste.
export const RETRAITS_PAR_APPEL = 1000;
// Une page de la liste des exemplaires constatés.
export const PAGE_RETRAITS = 200;

const n = (v) => (Number.isFinite(Number(v)) ? Number(v) : 0);

// Le nombre de brouillons que « Proposer les retraits » créerait.
export function proposables(bilan) {
  if (!bilan || typeof bilan !== 'object') return 0;
  return n(bilan.proposables?.retraits) + n(bilan.proposables?.levees);
}

// La confirmation « c'est bien un export complet » est demandée (IMP-34 a).
export function confirmationDemandee(bilan) {
  return !!bilan && bilan.bloque_retraits === 'seuil_non_confirme' && !!bilan.export_complet && !bilan.confirme;
}

// Le total des disparus (tous verdicts) et des réapparus : y a-t-il quelque
// chose à montrer ?
export function aDesConstats(bilan) {
  const c = bilan?.counts || {};
  return VERDICTS_RETRAITS.some((v) => n(c[v]) > 0);
}

// Les clés i18n d'un exemplaire constaté : son verdict, et le motif d'un engagé
// ou la nature d'un brouillon vivant.
export function cleVerdict(it) {
  return `importacoes.retraits.verdict.${VERDICTS_RETRAITS.includes(it?.verdict) ? it.verdict : 'disparu'}`;
}
export function cleDetail(it) {
  if (it?.verdict === 'disparu_engage' && MOTIFS_ENGAGE.includes(it.motif)) {
    return `importacoes.retraits.motif.${it.motif}`;
  }
  if (it?.draft_id && ['retrait', 'levee', 'mise_a_jour', 'autre'].includes(it.draft_nature)) {
    return `importacoes.retraits.brouillon.${it.draft_nature}`;
  }
  if (it?.verdict === 'retire_reapparu' && ['deja_la', 'reetiquete'].includes(it.constat)) {
    return `importacoes.retraits.constat.${it.constat}`;
  }
  return null;
}

// Le message de « Proposer les retraits » (somme de plusieurs appels).
export function cumulerPropositions(total, res) {
  const t = total || { retraits: 0, levees: 0, batch_id: null, reste: 0 };
  return {
    retraits: t.retraits + n(res?.retraits),
    levees: t.levees + n(res?.levees),
    batch_id: res?.batch_id ?? t.batch_id,
    reste: n(res?.reste),
  };
}

// Un exemplaire est-il « sorti du catalogue d'origine » ?
export function estRetire(exemplaire) {
  return !!(exemplaire && exemplaire.retire_at);
}
