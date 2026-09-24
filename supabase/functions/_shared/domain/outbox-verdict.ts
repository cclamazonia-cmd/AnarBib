// ============================================================================
// outbox-verdict.ts — ce qu'une ligne de file doit dire après une tentative d'envoi
// ============================================================================
// DOC-SILENCE-1 : un refus qui ressemble à un succès est proscrit. Or les handlers
// de domaine qui suivent le patron « recipients_count === 0 → skipped, sinon sent »
// marquaient « sent » dès qu'il y avait un destinataire, SANS regarder le résultat
// de safeSendEmail — qui ne lève jamais : il rend { ok:false, error } quand le
// transport refuse, et { ok:false, skipped:true, reason } quand il s'abstient
// (canal coupé, adresse invalide). Un numéro de la Lettre non parti était donc
// tenu pour envoyé, et `sent_at` datait un courriel qui n'existait pas.
// Trouvé le 21/09/2026 en écrivant lettre-banc.test.js ; le même patron vivait dans
// gazette.ts, team.ts, network.ts, cartography.ts et assembleia.ts, repris le soir même.
//
// Fonction PURE : elle lit ce que le handler a rendu et dit le statut de la ligne.
//   - aucun destinataire                        → skipped, no_recipients
//   - au moins un envoi refusé par le transport → failed (détail dans last_error)
//   - tous les envois délibérément sautés       → skipped, transport:<raison>
//   - sinon (au moins un parti, aucun refus)    → sent
//
// Les envois sont lus sous TOUTES les formes que les handlers rendent : `result`,
// `results`, `user_result(s)`, `admin_result(s)` — toute clé finissant par
// « result » ou « results ». Une valeur nulle (pas de copie admin) ne compte pas.
//
// ENVOIS MULTIPLES. Le vocabulaire de la file n'a que quatre statuts, et une ligne
// vaut pour tous ses destinataires. Un seul refus suffit à dire « failed » : dire
// « sent » cacherait le refus. Le détail compte alors les partis et nomme les
// refusés, pour qu'on sache QUI relancer. Conséquence à garder en tête le jour où
// l'on rejouera les lignes « failed » (rien ne le fait aujourd'hui) : rejouer PAR
// DESTINATAIRE refusé, jamais la ligne entière — les autres ont reçu leur courriel.
// ============================================================================

// `refuses` (F12, 25/09/2026) : les adresses refusées par le transport, EN DONNÉES —
// c'est elles, et elles seules, que le cron de rejeu fera repartir. Vide hors échec.
export type VerdictEnvoi = { status: "sent" | "skipped" | "failed"; detail: string | null; refuses: string[] };

/** Les colonnes qu'une ligne de file en échec doit porter (F12) : la cause lisible et la liste des refusés. */
export function champsEchec(verdictOuMessage: VerdictEnvoi | string) {
  if (typeof verdictOuMessage === "string") return { status: "failed", last_error: verdictOuMessage, refused_recipients: null };
  const v = verdictOuMessage;
  return { status: "failed", last_error: v.detail, refused_recipients: v.refuses.length ? v.refuses : null };
}

function envoisDe(r): unknown[] {
  const out: unknown[] = [];
  for (const [cle, valeur] of Object.entries(r || {})) {
    if (!/(^|_)results?$/.test(cle) || valeur == null) continue;
    if (Array.isArray(valeur)) out.push(...valeur.filter((v) => v != null));
    else if (typeof valeur === "object") out.push(valeur);
  }
  return out;
}

export function verdictEnvois(r): VerdictEnvoi {
  if (!r || r.recipients_count === 0) return { status: "skipped", detail: "no_recipients", refuses: [] };
  // deno-lint-ignore no-explicit-any
  const envois = envoisDe(r) as any[];
  if (envois.length === 0) return { status: "sent", detail: null, refuses: [] };
  const refus = envois.filter((e) => e.ok === false && !e.skipped);
  if (refus.length) {
    const liste = refus.map((e) => `${e.email || e.label || "?"} : ${e.error || "envoi refuse"}`).join(" | ");
    const partis = envois.filter((e) => e.ok !== false && !e.skipped).length;
    const detail = envois.length === 1 ? liste : `${partis} parti(s), ${refus.length} refuse(s) — ${liste}`;
    const refuses = [...new Set(refus.map((e) => String(e.email || "").trim().toLowerCase()).filter(Boolean))];
    return { status: "failed", detail: detail.slice(0, 500), refuses };
  }
  const sautes = envois.filter((e) => e.skipped);
  if (sautes.length === envois.length) return { status: "skipped", detail: `transport:${sautes[0].reason || "raison_non_precisee"}`, refuses: [] };
  return { status: "sent", detail: null, refuses: [] };
}
