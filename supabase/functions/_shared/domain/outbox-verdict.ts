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
// Trouvé le 21/09/2026 en écrivant lettre-banc.test.js.
//
// Fonction PURE : elle lit ce que le handler a rendu et dit le statut de la ligne.
//   - aucun destinataire                      → skipped, no_recipients
//   - au moins un envoi refusé par le transport → failed (le détail part dans last_error)
//   - tous les envois délibérément sautés      → skipped, transport:<raison>
//   - sinon (au moins un parti, aucun refus)   → sent
// Adopté par domain/lettre.ts. gazette.ts, team.ts et network.ts suivent le même
// patron et portent le même défaut : à reprendre, chacun derrière son banc.
// ============================================================================

export type VerdictEnvoi = { status: "sent" | "skipped" | "failed"; detail: string | null };

export function verdictEnvois(r): VerdictEnvoi {
  if (!r || r.recipients_count === 0) return { status: "skipped", detail: "no_recipients" };
  const envois = Array.isArray(r.results) ? r.results : (r.result ? [r.result] : []);
  if (envois.length === 0) return { status: "sent", detail: null };
  const refus = envois.filter((e) => e && e.ok === false && !e.skipped);
  if (refus.length) {
    const detail = refus.map((e) => `${e.email || "?"} : ${e.error || "envoi refuse"}`).join(" | ").slice(0, 500);
    return { status: "failed", detail };
  }
  const sautes = envois.filter((e) => e && e.skipped);
  if (sautes.length === envois.length) return { status: "skipped", detail: `transport:${sautes[0].reason || "raison_non_precisee"}` };
  return { status: "sent", detail: null };
}
