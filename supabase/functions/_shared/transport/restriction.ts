// ============================================================================
// transport/restriction.ts — « ne servir que ceux-là », le temps d'un rejeu (F12)
// ============================================================================
// Quand le cron anarbib-notify-outbox-retry repose une ligne de file en échec à
// notify-event, il joint la liste des destinataires que le transport avait
// refusés (`seulement`). Le handler de domaine, lui, ne change pas : il refait
// son fan-out tel quel. C'est le transport qui, pendant ce rejeu, SAUTE tout
// destinataire hors de la liste — il avait déjà reçu son courriel — en le
// comptant comme servi (outbox-verdict ne voit donc ni refus ni saut).
//
// Pourquoi AsyncLocalStorage : une Edge Function peut traiter plusieurs requêtes
// dans le même isolat ; une variable de module « restriction en cours » fuirait
// d'un rejeu à un envoi ordinaire concurrent. Le contexte asynchrone, lui, suit
// la requête et elle seule.
//
// Règle écrite en tête de outbox-verdict.ts depuis le 21/09 : rejouer PAR
// DESTINATAIRE refusé, jamais la ligne entière — les autres ont reçu leur courriel.
// ============================================================================
import { AsyncLocalStorage } from "node:async_hooks";

const stockage = new AsyncLocalStorage<Set<string>>();

const normaliser = (e: unknown) => String(e ?? "").trim().toLowerCase();

/** Exécute `fn` en ne laissant partir que les courriels adressés à `seulement`. */
export function executerPour<T>(seulement: unknown[], fn: () => Promise<T>): Promise<T> {
  const liste = new Set(seulement.map(normaliser).filter(Boolean));
  return stockage.run(liste, fn);
}

/** Vrai si un rejeu est en cours ET que cette adresse n'en fait pas partie (déjà servie). */
export function dejaServi(email: unknown): boolean {
  const liste = stockage.getStore();
  if (!liste) return false;
  return !liste.has(normaliser(email));
}
