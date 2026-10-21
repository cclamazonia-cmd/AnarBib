import { secretValide } from "./egalite-constante.ts";

const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8"
};
export function jsonResponse(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: JSON_HEADERS
  });
}
export async function parseJsonPayload(req) {
  const payload = await req.json().catch(()=>null);
  const manualTest = !!(payload && typeof payload === "object" && "manual_test" in payload && payload.manual_test === true);
  return {
    payload,
    manualTest
  };
}
// AUTHENTIFICATION — secret webhook uniquement, aucun repli.
//
// Durci le 2026-08-17. Les deux replis historiques ont été retirés :
//
//   1. `bearerOk` : `ok` était vrai dès qu'un en-tête Authorization contenait
//      un Bearer *bien formé*, sans jamais en vérifier la signature ni le rôle.
//      Or les notifieurs sont déclarés `verify_jwt = false` (cf. config.toml) :
//      la passerelle ne valide rien non plus. N'importe qui pouvait donc
//      déclencher notify-event / notify-digital-share / notify-oai-opening avec
//      `Authorization: Bearer aaaa`, sans connaître le secret.
//   2. `dashboardTestOk` : même faiblesse, simplement conditionnée à
//      `manual_test: true` dans le corps — un drapeau que l'appelant contrôle.
//      Vérifié : `manual_test` ne servait QU'À l'autorisation (il n'altère
//      aucun comportement, il est juste recopié dans la réponse), donc le
//      retirer ne casse aucun usage légitime.
//
// Appelants vérifiés avant durcissement : tous les dispatchers SQL
// (fn_gazette_outbox_dispatch_trigger, fn_team_outbox_dispatch_trigger,
// fn_lettre_outbox_dispatch_trigger, fn_internal_dispatch_ill_notification,
// fn_internal_dispatch_oai_notification…) lisent le secret dans le vault et
// l'envoient en `x-webhook-secret` — aucun n'envoie d'en-tête Authorization.
//
// `manualTest` reste dans la signature pour ne pas toucher aux appelants, mais
// n'a plus d'effet sur l'autorisation. Modèle de référence : notify-security-notice.
//
// 21/10/2026 : le secret se compare à durée constante (secretValide), et la
// garde passe AVANT la lecture du corps : un appel sans secret ne fait plus
// parser du JSON à la fonction. Une erreur du gestionnaire est journalisée et
// rendue sous une forme générique (« internal_error ») : la réponse finit dans
// net._http_response, lisible bien au-delà de qui doit la lire.
export function authorizeWebhook(req, manualTest, options = {}) {
  const webhookOk = secretValide(options.secretEnv, req.headers.get("x-webhook-secret"));
  return {
    ok: webhookOk,
    webhookOk,
    dashboardTestOk: false
  };
}
export async function serveJsonWebhook(req, options, handler) {
  if (req.method !== "POST") return jsonResponse(405, {
    ok: false,
    error: "Method not allowed"
  });
  const auth = authorizeWebhook(req, false, options);
  if (!auth.ok) return jsonResponse(401, {
    ok: false,
    error: "Unauthorized"
  });
  const { payload, manualTest } = await parseJsonPayload(req);
  try {
    const result = await handler(payload, {
      manualTest
    });
    return jsonResponse(200, result);
  } catch (error) {
    console.error("[webhook] erreur du gestionnaire :", error?.message || error);
    return jsonResponse(500, {
      ok: false,
      error: "internal_error"
    });
  }
}
