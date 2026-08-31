// ─────────────────────────────────────────────────────────────────────────────
// AnarBib — src/lib/rpcStatus.js
//
// Un refus qui ressemble à un succès (item B15, doctrine DOC-SILENCE-1).
//
// LE PROBLÈME, MESURÉ LE 31/08/2026. Trente-quatre RPC appelées par le front
// rendent un jsonb `{ ok, reason, … }` au lieu de lever. Vingt-six appels
// n'inspectaient pas le `ok`, et dix-huit d'entre eux écrivaient
// `const { error } = await supabase.rpc(...)` : la charge utile était jetée à
// la destructuration, le `ok` n'était pas seulement non lu, il était
// INATTEIGNABLE. Sur `BookPage`, un `ok:false` affichait « consultation
// demandée » à une lectrice dont rien n'avait été créé.
//
// POURQUOI LE CONTRAT DE STATUT EST GARDÉ. Une RPC qui lève coupe le lot en
// cours ; une RPC qui rend un statut permet de traiter ligne par ligne, ce que
// fait précisément `skipped` dans les paquets multi-lignes. On ne casse pas ce
// contrat pour vingt-six appels distraits : on impose de lire le `ok`.
//
// POURQUOI AUCUNE CHAÎNE i18n N'EST NÉCESSAIRE. `localizeError` n'a pas de
// liste blanche : un code court posé en `message` est traduit via
// `panel.apiError.<code>` s'il existe, sinon on retombe sur la clé
// contextuelle de l'action, sinon sur un message générique. En jetant le
// `reason` sous cette forme, on entre dans le chemin d'erreur DÉJÀ EN PLACE :
// le `try/catch` de l'appelant, `localizeError`, le toast. Rien de neuf à
// traduire, et ce qui a déjà une clé s'affiche mieux qu'avant.
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Lève si une RPC à statut a refusé. À placer juste après `if (error) throw error`.
 *
 *   const { data, error } = await supabase.rpc('create_consulta_local', params);
 *   if (error) throw error;
 *   assertRpcOk(data);
 *
 * Ne fait rien si la charge utile n'est pas un statut (`ok` absent) : les RPC
 * qui rendent autre chose passent au travers sans bruit.
 *
 * @param {*} data - charge utile rendue par la RPC
 * @param {string} [fallbackCode] - code à utiliser si la RPC refuse sans `reason`
 * @throws {Error} portant le code de refus en `message`, lisible par localizeError
 */
export function assertRpcOk(data, fallbackCode = 'rpc_refused') {
  if (!data || typeof data !== 'object') return;
  if (data.ok !== false) return;
  const code = (typeof data.reason === 'string' && data.reason.trim()) || fallbackCode;
  const err = new Error(code);
  // `reason` reste accessible à l'appelant qui veut traiter un cas nommé sans
  // reparser le message ; `rpcStatus` marque l'origine pour le diagnostic.
  err.reason = code;
  err.rpcStatus = data;
  throw err;
}
