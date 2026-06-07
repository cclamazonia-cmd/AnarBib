import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
export const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
export const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
// Note (audit P4 du 06/05/2026) : la const WEBHOOK_SECRET qui pointait vers
// WEBHOOK_SECRET_NOTIFY_EVENT a �t� supprim�e car (1) jamais import�e ailleurs
// dans notify-internal-task, (2) s�mantiquement incorrecte (pointait vers le
// secret de notify-event au lieu de celui d'internal-task). Le secret r�el est
// d�fini localement dans index.ts � partir de WEBHOOK_SECRET_NOTIFY_INTERNAL_TASK.
// R.7 : variables sender harmonisees sur le couple canonique SENDER_EMAIL /
// SENDER_NAME (anciens fallbacks ANARBIB_*/NETWORK_*/LIBRARY_* alignes).
export const SENDER_EMAIL = Deno.env.get("SENDER_EMAIL") || "no-reply@example.org";
export const SENDER_NAME = Deno.env.get("SENDER_NAME") || "Biblioteca da rede AnarBib";
export const ADMIN_EMAIL = (Deno.env.get("ADMIN_EMAIL") || Deno.env.get("LIBRARY_ADMIN_EMAIL") || Deno.env.get("ANARBIB_ADMIN_EMAIL") || Deno.env.get("NETWORK_ADMIN_EMAIL") || Deno.env.get("ADMIN_EMAIL_NOTIFY_EVENT") || Deno.env.get("BLMF_ADMIN_EMAIL") || "").trim();
export const ADMIN_NAME = (Deno.env.get("ADMIN_NAME") || Deno.env.get("LIBRARY_ADMIN_NAME") || Deno.env.get("ANARBIB_ADMIN_NAME") || Deno.env.get("NETWORK_ADMIN_NAME") || Deno.env.get("BLMF_ADMIN_NAME") || "Equipe da biblioteca").trim();
export const LIBRARIAN_PHONE = Deno.env.get("LIBRARIAN_PHONE") || Deno.env.get("ANARBIB_LIBRARIAN_PHONE") || Deno.env.get("NETWORK_LIBRARIAN_PHONE") || "";
export const REGIMENTO_URL = Deno.env.get("REGIMENTO_URL") || Deno.env.get("ANARBIB_REGIMENTO_URL") || Deno.env.get("NETWORK_REGIMENTO_URL") || "";
export const BRAND_NAME = Deno.env.get("BRAND_NAME") || Deno.env.get("LIBRARY_BRAND_NAME") || Deno.env.get("ANARBIB_BRAND_NAME") || Deno.env.get("NETWORK_BRAND_NAME") || Deno.env.get("BLMF_BRAND_NAME") || "AnarBib";
export const FOOTER_TEXT = Deno.env.get("FOOTER_TEXT") || Deno.env.get("LIBRARY_FOOTER_TEXT") || Deno.env.get("ANARBIB_FOOTER_TEXT") || Deno.env.get("NETWORK_FOOTER_TEXT") || Deno.env.get("BLMF_FOOTER_TEXT") || "Mensagem automática da biblioteca. Responde apenas se o campo de resposta indicar um contato local.";
export const LOGO_URL = Deno.env.get("LOGO_URL") || Deno.env.get("LIBRARY_LOGO_URL") || Deno.env.get("ANARBIB_LOGO_URL") || Deno.env.get("NETWORK_LOGO_URL") || Deno.env.get("BLMF_LOGO_URL") || "";
export const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: {
    persistSession: false
  }
});
