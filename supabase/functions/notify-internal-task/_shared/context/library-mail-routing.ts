import { ADMIN_EMAIL, ADMIN_NAME, FOOTER_TEXT, LOGO_URL, SENDER_EMAIL, SENDER_NAME, supabaseAdmin } from "../core/env.ts";
import { replaceBrandTokens, resolvedBrandName, resolvedSubjectTag } from "../shared/branding.ts";
const LIBRARY_UI_ASSETS_BUCKET = "library-ui-assets";
function isHttpUrl(value) {
  try {
    const url = new URL(String(value || "").trim());
    return url.protocol === "http:" || url.protocol === "https:";
  } catch  {
    return false;
  }
}
function normalizeLibraryAssetKey(value) {
  const raw = String(value || "").trim();
  if (!raw) return null;
  return raw.replace(new RegExp(`^https?://[^/]+/storage/v1/object/public/${LIBRARY_UI_ASSETS_BUCKET}/`, "i"), "").replace(new RegExp(`^${LIBRARY_UI_ASSETS_BUCKET}/`, "i"), "").replace(/^\/+/, "").trim() || null;
}
function publicUrlFromLibraryAssetKey(value) {
  const assetKey = normalizeLibraryAssetKey(value);
  if (!assetKey) return "";
  try {
    const { data } = supabaseAdmin.storage.from(LIBRARY_UI_ASSETS_BUCKET).getPublicUrl(assetKey);
    return String(data?.publicUrl || "").trim();
  } catch (error) {
    console.warn("publicUrlFromLibraryAssetKey fallback:", error);
    return "";
  }
}
function resolveLibraryLogoUrl(ctx) {
  if (ctx?.use_library_logo === false) {
    return "";
  }
  const libraryLogoFromFileKey = publicUrlFromLibraryAssetKey(ctx?.logo_file_key || null);
  if (libraryLogoFromFileKey) {
    return libraryLogoFromFileKey;
  }
  const explicitLogoUrl = String(ctx?.logo_url || "").trim();
  if (explicitLogoUrl && isHttpUrl(explicitLogoUrl)) {
    return explicitLogoUrl;
  }
  const libraryLogoFromUrlAsAsset = publicUrlFromLibraryAssetKey(ctx?.logo_url || null);
  if (libraryLogoFromUrlAsAsset) {
    return libraryLogoFromUrlAsAsset;
  }
  return "";
}
function resolveNetworkLogoUrl() {
  return String(LOGO_URL || "").trim();
}
export function subjectTag(ctx) {
  return resolvedSubjectTag(ctx);
}
export function brandName(ctx) {
  return resolvedBrandName(ctx);
}
export function applyBrandingText(text, ctx) {
  return replaceBrandTokens(text, ctx);
}
export function policyEnabled(ctx, key, fallback = true) {
  const value = ctx?.[key];
  return typeof value === "boolean" ? value : fallback;
}
export function resolveMailRouting(ctx) {
  const senderName = String(ctx?.sender_display_name || (ctx?.use_library_name_as_sender !== false ? ctx?.library_short_name || ctx?.library_name || "" : "") || SENDER_NAME).trim() || SENDER_NAME;
  const replyToEmail = String(ctx?.delivery_mode === "platform_shared_local_reply" || ctx?.delivery_mode === "library_own_transport" ? ctx?.reply_to_email || ctx?.admin_notification_email || "" : "").trim() || null;
  const footerPieces = [];
  if (ctx?.signature_short) footerPieces.push(String(ctx.signature_short).trim());
  if (ctx?.footer_local) footerPieces.push(String(ctx.footer_local).trim());
  if (!footerPieces.length) footerPieces.push(FOOTER_TEXT);
  const networkLogoUrl = resolveNetworkLogoUrl();
  const libraryLogoUrl = resolveLibraryLogoUrl(ctx);
  const logoUrl = libraryLogoUrl || networkLogoUrl;
  return {
    brandName: brandName(ctx),
    subjectTag: subjectTag(ctx),
    senderName,
    senderEmail: String(ctx?.sender_visible_email || SENDER_EMAIL || "").trim() || SENDER_EMAIL,
    replyToName: String(ctx?.reply_to_name || senderName || ADMIN_NAME || "").trim() || null,
    replyToEmail,
    logoUrl,
    networkLogoUrl,
    libraryLogoUrl,
    footerText: footerPieces.join(" — "),
    footerHtml: footerPieces.join("<br>"),
    adminEmail: String(ctx?.admin_notification_email || ADMIN_EMAIL || "").trim() || null,
    adminName: String(ctx?.reply_to_name || ADMIN_NAME || senderName || "").trim() || null,
    deliveryMode: String(ctx?.delivery_mode || "platform_shared").trim() || "platform_shared",
    channelActive: ctx?.channel_active !== false && String(ctx?.delivery_mode || "platform_shared") !== "disabled"
  };
}
export function transportDisabledReason(ctx) {
  if (ctx?.channel_active === false || String(ctx?.delivery_mode || "") === "disabled") return "delivery_disabled";
  if (String(ctx?.delivery_mode || "") === "library_own_transport" && !String(ctx?.admin_notification_email || "").trim()) return "missing_local_channel";
  return null;
}
