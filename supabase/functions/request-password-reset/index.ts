// ============================================================================
// request-password-reset — mail de récupération MDP LOCALISÉ (langue de l'usager)
// ============================================================================
// Remplace l'appel direct supabase.auth.resetPasswordForEmail (qui déclenchait
// le mail NATIF Supabase, à langue figée = pt-BR). Ici on :
//   1. rate-limite (anti-spam, clés namespacées `pwreset:` pour ne PAS partager
//      le compteur avec le login),
//   2. résout la langue de l'usager (profiles.preferred_language),
//   3. génère le lien de récup via admin.generateLink({type:'recovery'}),
//   4. envoie un e-mail rendu dans la langue de l'usager via Resend.
// Toujours 200 (anti-énumération : ne révèle pas si l'adresse existe).
//
// verify_jwt : défaut (true) — NON déclarée dans config.toml, comme login/register.
// Appelée depuis le formulaire « mot de passe oublié » via supabase.functions.invoke,
// qui envoie la clé anon (un JWT valide) → la garde verify_jwt=true est satisfaite.
// ============================================================================
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const SENDER_EMAIL = (Deno.env.get("SENDER_EMAIL") || "no-reply@notifications.anarbib.org").trim();
const SENDER_NAME = (Deno.env.get("SENDER_NAME") || Deno.env.get("BRAND_NAME") || "AnarBib").trim();
const LOGO_URL = (Deno.env.get("LOGO_URL") || "").trim();
const APP_BASE_URL = (Deno.env.get("APP_BASE_URL") || "https://app.anarbib.org").trim();

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ── i18n du mail de récupération (10 langues, fallback pt-BR) ────────────────
const SUPPORTED = ["pt-BR", "fr", "es", "en", "it", "de", "ca", "eo", "nl", "el"];
const T: Record<string, { subject: string; heading: string; intro: string; cta: string; expiry: string; ignore: string; footer: string }> = {
  "pt-BR": { subject: "Redefinir sua senha", heading: "Redefinição de senha", intro: "Recebemos um pedido para redefinir a senha da sua conta. Clique no botão abaixo para escolher uma nova senha.", cta: "Redefinir a senha", expiry: "Este link expira em 1 hora e só pode ser usado uma vez.", ignore: "Se você não pediu isto, ignore este e-mail — sua senha permanece inalterada.", footer: "AnarBib — Rede de bibliotecas libertárias" },
  fr: { subject: "Réinitialiser votre mot de passe", heading: "Réinitialisation du mot de passe", intro: "Nous avons reçu une demande de réinitialisation du mot de passe de ton compte. Clique sur le bouton ci-dessous pour choisir un nouveau mot de passe.", cta: "Réinitialiser le mot de passe", expiry: "Ce lien expire dans 1 heure et ne peut servir qu'une seule fois.", ignore: "Si tu n'es pas à l'origine de cette demande, ignore cet e-mail — ton mot de passe reste inchangé.", footer: "AnarBib — Réseau de bibliothèques libertaires" },
  es: { subject: "Restablecer tu contraseña", heading: "Restablecimiento de contraseña", intro: "Recibimos una solicitud para restablecer la contraseña de tu cuenta. Hacé clic en el botón de abajo para elegir una nueva contraseña.", cta: "Restablecer la contraseña", expiry: "Este enlace caduca en 1 hora y solo puede usarse una vez.", ignore: "Si no solicitaste esto, ignorá este correo — tu contraseña no cambia.", footer: "AnarBib — Red de bibliotecas libertarias" },
  en: { subject: "Reset your password", heading: "Password reset", intro: "We received a request to reset your account password. Click the button below to choose a new password.", cta: "Reset password", expiry: "This link expires in 1 hour and can be used only once.", ignore: "If you didn't request this, ignore this email — your password stays unchanged.", footer: "AnarBib — Network of libertarian libraries" },
  it: { subject: "Reimposta la tua password", heading: "Reimpostazione della password", intro: "Abbiamo ricevuto una richiesta di reimpostazione della password del tuo account. Clicca sul pulsante qui sotto per scegliere una nuova password.", cta: "Reimposta la password", expiry: "Questo link scade tra 1 ora e può essere usato una sola volta.", ignore: "Se non hai richiesto questo, ignora questa email — la tua password resta invariata.", footer: "AnarBib — Rete di biblioteche libertarie" },
  de: { subject: "Passwort zurücksetzen", heading: "Passwort zurücksetzen", intro: "Wir haben eine Anfrage zum Zurücksetzen des Passworts deines Kontos erhalten. Klicke auf die Schaltfläche unten, um ein neues Passwort zu wählen.", cta: "Passwort zurücksetzen", expiry: "Dieser Link läuft in 1 Stunde ab und kann nur einmal verwendet werden.", ignore: "Falls du das nicht angefordert hast, ignoriere diese E-Mail — dein Passwort bleibt unverändert.", footer: "AnarBib — Netzwerk libertärer Bibliotheken" },
  ca: { subject: "Restablir la teva contrasenya", heading: "Restabliment de la contrasenya", intro: "Hem rebut una sol·licitud per restablir la contrasenya del teu compte. Fes clic al botó de sota per triar una contrasenya nova.", cta: "Restablir la contrasenya", expiry: "Aquest enllaç caduca d'aquí a 1 hora i només es pot fer servir un cop.", ignore: "Si no ho has demanat, ignora aquest correu — la teva contrasenya no canvia.", footer: "AnarBib — Xarxa de biblioteques llibertàries" },
  eo: { subject: "Restarigi vian pasvorton", heading: "Restarigo de pasvorto", intro: "Ni ricevis peton restarigi la pasvorton de via konto. Klaku la butonon sube por elekti novan pasvorton.", cta: "Restarigi la pasvorton", expiry: "Ĉi tiu ligilo eksvalidiĝas post 1 horo kaj uzeblas nur unufoje.", ignore: "Se vi ne petis tion, ignoru ĉi tiun retmesaĝon — via pasvorto restas senŝanĝa.", footer: "AnarBib — Reto de liberecanaj bibliotekoj" },
  nl: { subject: "Je wachtwoord opnieuw instellen", heading: "Wachtwoord opnieuw instellen", intro: "We hebben een verzoek ontvangen om het wachtwoord van je account opnieuw in te stellen. Klik op de knop hieronder om een nieuw wachtwoord te kiezen.", cta: "Wachtwoord opnieuw instellen", expiry: "Deze link verloopt over 1 uur en kan maar één keer worden gebruikt.", ignore: "Als je dit niet hebt aangevraagd, negeer deze e-mail — je wachtwoord blijft ongewijzigd.", footer: "AnarBib — Netwerk van libertaire bibliotheken" },
  el: { subject: "Επαναφορά του κωδικού σας", heading: "Επαναφορά κωδικού πρόσβασης", intro: "Λάβαμε αίτημα επαναφοράς του κωδικού πρόσβασης του λογαριασμού σας. Κάντε κλικ στο παρακάτω κουμπί για να επιλέξετε νέο κωδικό.", cta: "Επαναφορά κωδικού", expiry: "Αυτός ο σύνδεσμος λήγει σε 1 ώρα και μπορεί να χρησιμοποιηθεί μόνο μία φορά.", ignore: "Αν δεν το ζητήσατε εσείς, αγνοήστε αυτό το email — ο κωδικός σας παραμένει ίδιος.", footer: "AnarBib — Δίκτυο ελευθεριακών βιβλιοθηκών" },
};
function pickLocale(raw: string | null | undefined): string {
  const v = String(raw || "").trim();
  if (SUPPORTED.includes(v)) return v;
  const base = v.split("-")[0];
  const hit = SUPPORTED.find((l) => l.split("-")[0] === base);
  return hit || "pt-BR";
}

function esc(s: string): string {
  return String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#039;" }[c]!));
}

function renderHtml(loc: string, actionUrl: string): string {
  const s = T[loc] || T["pt-BR"];
  const logo = LOGO_URL
    ? `<img src="${esc(LOGO_URL)}" alt="AnarBib" style="display:block;max-width:120px;max-height:64px;width:auto;height:auto;object-fit:contain;margin:0 auto 8px;">`
    : "";
  return `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${esc(s.subject)}</title></head>` +
    `<body style="margin:0;background:#0f0f10;color:#ffffff;font-family:system-ui,-apple-system,Segoe UI,Roboto,Arial,sans-serif;">` +
    `<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse;"><tr><td align="center" style="padding:24px 12px;">` +
    `<table role="presentation" width="560" cellspacing="0" cellpadding="0" style="border-collapse:collapse;max-width:560px;width:100%;">` +
    `<tr><td style="background:rgba(27,27,27,0.94);border:1px solid rgba(255,255,255,0.12);border-radius:18px;overflow:hidden;">` +
    `<div style="padding:20px 18px 8px;text-align:center;">${logo}</div>` +
    `<div style="height:3px;background:#c00000;"></div>` +
    `<div style="padding:22px;">` +
    `<h1 style="margin:0 0 14px;font-size:20px;line-height:1.25;">${esc(s.heading)}</h1>` +
    `<p style="margin:0 0 18px;font-size:16px;line-height:1.55;color:#f2f2f2;">${esc(s.intro)}</p>` +
    `<div style="margin:0 0 18px;"><a href="${esc(actionUrl)}" style="display:inline-block;padding:12px 22px;background:#c00000;color:#ffffff;text-decoration:none;border-radius:8px;font-weight:700;font-size:15px;">${esc(s.cta)}</a></div>` +
    `<p style="margin:0 0 10px;font-size:13px;line-height:1.5;color:#cfcfcf;">${esc(s.expiry)}</p>` +
    `<p style="margin:0;font-size:13px;line-height:1.5;color:#9c9c9c;">${esc(s.ignore)}</p>` +
    `</div></td></tr>` +
    `<tr><td style="padding:12px 6px 0;color:#9c9c9c;font-size:12px;text-align:center;">${esc(s.footer)}</td></tr>` +
    `</table></td></tr></table></body></html>`;
}

function renderText(loc: string, actionUrl: string): string {
  const s = T[loc] || T["pt-BR"];
  return `${s.heading}\n\n${s.intro}\n\n${s.cta}: ${actionUrl}\n\n${s.expiry}\n${s.ignore}\n\n${s.footer}`;
}

function getClientIP(req: Request): string {
  const xf = req.headers.get("x-forwarded-for");
  if (xf) return xf.split(",")[0].trim();
  return req.headers.get("x-real-ip") || "unknown";
}

// Rate-limit réutilisant auth_rate_limits ; clés namespacées `pwreset:` pour ne
// PAS partager le compteur avec le login (même table, kinds ip/email).
const RL = { maxRequests: 4, windowMinutes: 15, blockMinutes: 30 };
type SB = ReturnType<typeof createClient>;
async function isBlocked(sb: SB, kind: string, key: string): Promise<boolean> {
  const { data } = await sb.from("auth_rate_limits").select("blocked_until").eq("kind", kind).eq("key", key).maybeSingle();
  if (!data?.blocked_until) return false;
  return new Date(data.blocked_until as string) > new Date();
}
async function record(sb: SB, kind: string, key: string): Promise<void> {
  const now = new Date();
  const windowStart = new Date(now.getTime() - RL.windowMinutes * 60000);
  const { data: ex } = await sb.from("auth_rate_limits").select("*").eq("kind", kind).eq("key", key).maybeSingle();
  if (!ex) {
    await sb.from("auth_rate_limits").insert({ kind, key, failure_count: 1, first_failure_at: now.toISOString(), last_failure_at: now.toISOString() });
    return;
  }
  const first = new Date(ex.first_failure_at as string);
  const within = first >= windowStart;
  const count = within ? (ex.failure_count as number) + 1 : 1;
  const blocked = count >= RL.maxRequests ? new Date(now.getTime() + RL.blockMinutes * 60000).toISOString() : null;
  await sb.from("auth_rate_limits").update({ failure_count: count, first_failure_at: (within ? first : now).toISOString(), last_failure_at: now.toISOString(), blocked_until: blocked }).eq("kind", kind).eq("key", key);
}

async function sendViaResend(to: string, subject: string, html: string, text: string): Promise<void> {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${RESEND_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: `${SENDER_NAME} <${SENDER_EMAIL}>`, to: [to], subject, html, text }),
  });
  if (!res.ok) throw new Error(`Resend HTTP ${res.status}: ${await res.text()}`);
}

const OK = () => new Response(JSON.stringify({ ok: true }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  if (req.method !== "POST") return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });

  // Anti-énumération : on renvoie TOUJOURS 200, quoi qu'il arrive en interne.
  try {
    const body = await req.json().catch(() => ({}));
    const email = String(body?.email || "").trim().toLowerCase();
    if (!email || !email.includes("@")) return OK();

    const ip = getClientIP(req);
    const sb = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false, autoRefreshToken: false } });

    // Rate-limit (clés namespacées) : si bloqué, on s'arrête en silence (200).
    if (await isBlocked(sb, "email", `pwreset:${email}`) || await isBlocked(sb, "ip", `pwreset:${ip}`)) return OK();
    await Promise.all([record(sb, "email", `pwreset:${email}`), record(sb, "ip", `pwreset:${ip}`)]);

    // Profil → langue. Pas de profil = adresse inconnue : on ne révèle rien (200).
    // limit(1) plutôt que maybeSingle pour ne pas planter sur un email dupliqué.
    const { data: profs } = await sb.from("profiles").select("preferred_language").eq("email", email).limit(1);
    const prof = profs?.[0];
    if (!prof) return OK();
    const loc = pickLocale(prof.preferred_language as string | null);

    // Lien de récupération (génère le token côté Supabase, sans envoyer le mail natif).
    const { data: linkData, error: linkErr } = await sb.auth.admin.generateLink({
      type: "recovery",
      email,
      options: { redirectTo: `${APP_BASE_URL}/login` },
    });
    if (linkErr || !linkData?.properties?.action_link) {
      console.warn("[request-password-reset] generateLink:", linkErr?.message || "no action_link");
      return OK();
    }
    const actionUrl = linkData.properties.action_link;
    const s = T[loc] || T["pt-BR"];
    await sendViaResend(email, s.subject, renderHtml(loc, actionUrl), renderText(loc, actionUrl));
    console.log(`[request-password-reset] sent (locale=${loc})`);
    return OK();
  } catch (e) {
    console.error("[request-password-reset] error:", e);
    return OK(); // jamais d'erreur visible côté client (anti-énumération)
  }
});
