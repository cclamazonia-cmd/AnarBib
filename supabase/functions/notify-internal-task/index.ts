// FOYER-UNIQUE (30/08/2026, item F6). Cette fonction tournait sur une copie
// privee de TOUTE la pile courriel : 9 fichiers d infrastructure dupliques,
// ~694 lignes d ecart avec le tronc, geles depuis le premier commit du depot.
// Une divergence y avait deja pris — la signature de pied de page ignorait la
// langue du message. Les 3 fichiers reellement propres aux taches ont rejoint
// le tronc a la place que la convention leur donne (domain/, data/, i18n/),
// et la copie a disparu.
import { serveJsonWebhook } from "../_shared/core/webhook.ts";
import { handleInternalTaskNotification } from "../_shared/domain/internal-tasks.ts";
const WEBHOOK_SECRET = (Deno.env.get("WEBHOOK_SECRET_NOTIFY_INTERNAL_TASK") || "").trim();
Deno.serve((req)=>serveJsonWebhook(req, {
    secretEnv: WEBHOOK_SECRET
  }, async (payload)=>handleInternalTaskNotification(payload || {})));
