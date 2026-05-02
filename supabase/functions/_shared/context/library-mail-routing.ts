import { ADMIN_EMAIL, ADMIN_NAME, FOOTER_TEXT, LOGO_URL, SENDER_EMAIL, SENDER_NAME, supabaseAdmin } from "../core/env.ts";
import type { LibraryNotificationContext, ResolvedMailRouting } from "../core/types.ts";
import { replaceBrandTokens, resolvedBrandName, resolvedSubjectTag } from "../shared/branding.ts";
const BUCKET = "library-ui-assets";
function isHttp(v?: string|null) { try { const u = new URL(String(v||"").trim()); return u.protocol==="http:"||u.protocol==="https:"; } catch { return false; } }
function assetKey(v?: string|null) { const r = String(v||"").trim(); if (!r) return null; return r.replace(new RegExp(`^https?://[^/]+/storage/v1/object/public/${BUCKET}/`,"i"),"").replace(new RegExp(`^${BUCKET}/`,"i"),"").replace(/^\/+/,"").trim()||null; }
function pubUrl(v?: string|null) { const k = assetKey(v); if (!k) return ""; try { const { data } = supabaseAdmin.storage.from(BUCKET).getPublicUrl(k); return String(data?.publicUrl||"").trim(); } catch { return ""; } }
function libLogo(ctx?: LibraryNotificationContext|null) { if (ctx?.use_library_logo===false) return ""; const fk = pubUrl(ctx?.logo_file_key); if (fk) return fk; const lu = String(ctx?.logo_url||"").trim(); if (lu && isHttp(lu)) return lu; const la = pubUrl(ctx?.logo_url); if (la) return la; return ""; }
export function subjectTag(ctx?: LibraryNotificationContext|null) { return resolvedSubjectTag(ctx); }
export function brandName(ctx?: LibraryNotificationContext|null) { return resolvedBrandName(ctx); }
export function applyBrandingText(text: string, ctx?: LibraryNotificationContext|null) { return replaceBrandTokens(text, ctx); }
export function resolveMailRouting(ctx?: LibraryNotificationContext|null): ResolvedMailRouting {
  const sn = String(ctx?.sender_display_name||(ctx?.use_library_name_as_sender!==false?(ctx?.library_short_name||ctx?.library_name||""): "")||SENDER_NAME).trim()||SENDER_NAME;
  const rte = String((ctx?.delivery_mode==="platform_shared_local_reply"||ctx?.delivery_mode==="library_own_transport")?(ctx?.reply_to_email||ctx?.admin_notification_email||""): "").trim()||null;
  const fp: string[] = []; if (ctx?.signature_short) fp.push(String(ctx.signature_short).trim()); if (ctx?.footer_local) fp.push(String(ctx.footer_local).trim()); if (!fp.length) fp.push(FOOTER_TEXT);
  const nlu = String(LOGO_URL||"").trim(); const llu = libLogo(ctx);
  return { brandName: brandName(ctx), subjectTag: subjectTag(ctx), senderName: sn, senderEmail: String(ctx?.sender_visible_email||SENDER_EMAIL||"").trim()||SENDER_EMAIL, replyToName: String(ctx?.reply_to_name||sn||ADMIN_NAME||"").trim()||null, replyToEmail: rte, logoUrl: llu||nlu, networkLogoUrl: nlu, libraryLogoUrl: llu, footerText: fp.join(" — "), footerHtml: fp.join("<br>"), adminEmail: String(ctx?.admin_notification_email||ADMIN_EMAIL||"").trim()||null, adminName: String(ctx?.reply_to_name||ADMIN_NAME||sn||"").trim()||null, deliveryMode: String(ctx?.delivery_mode||"platform_shared").trim()||"platform_shared", channelActive: ctx?.channel_active!==false&&String(ctx?.delivery_mode||"platform_shared")!=="disabled" };
}
export function transportDisabledReason(ctx?: LibraryNotificationContext|null) { if (ctx?.channel_active===false||String(ctx?.delivery_mode||"")==="disabled") return "delivery_disabled"; if (String(ctx?.delivery_mode||"")==="library_own_transport"&&!String(ctx?.admin_notification_email||"").trim()) return "missing_local_channel"; return null; }
