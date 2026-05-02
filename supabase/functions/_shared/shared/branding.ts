import { ADMIN_NAME, BRAND_NAME } from "../core/env.ts";
import type { LibraryNotificationContext } from "../core/types.ts";
export function resolvedBrandName(ctx?: LibraryNotificationContext|null) { return String(ctx?.library_name||ctx?.library_short_name||BRAND_NAME||"AnarBib").trim()||"AnarBib"; }
export function resolvedSubjectTag(ctx?: LibraryNotificationContext|null) { return String(ctx?.library_short_name||ctx?.library_name||BRAND_NAME||"AnarBib").trim()||"AnarBib"; }
export function replaceBrandTokens(text: string, ctx?: LibraryNotificationContext|null) {
  const brand = resolvedBrandName(ctx); const tag = resolvedSubjectTag(ctx);
  const an = String(ctx?.reply_to_name||ctx?.signature_short||ADMIN_NAME||"Equipe da biblioteca").trim()||"Equipe da biblioteca";
  return String(text||"").replace(/^\[BLMF\]/gm,`[${tag}]`).replace(/\bBLMF\s*\|/g,`${tag} |`).replace(/Biblioteca Libertária Maxwell Ferreira/g,brand).replace(/Equipe da BLMF/g,an).replace(/\bna BLMF\b/g,`na ${brand}`).replace(/\bda BLMF\b/g,`da ${brand}`).replace(/\bde BLMF\b/g,`de ${brand}`).replace(/\bem BLMF\b/g,`em ${brand}`).replace(/\bBLMF\b/g,tag);
}
export function adminTaggedSubject(text: string, ctx?: LibraryNotificationContext|null) { const tag = resolvedSubjectTag(ctx); return replaceBrandTokens(String(text||"").replace(/^\[BLMF\]/,`[${tag}]`), ctx); }
