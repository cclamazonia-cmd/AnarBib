// Échapper UNE fois (19/10/2026). tMail échappe désormais ses paramètres
// (_shared/i18n/mail-strings.ts) : une phrase traduite qui passe ensuite par esc()
// — un titre, une salutation, un libellé que renderEmail échappe lui-même — ne
// doit pas l'être deux fois (« L&amp;#039;Insoumise » à l'écran). esc() rend
// donc d'abord leur caractère aux entités qu'il produit lui-même, puis échappe.
// Une valeur brute est échappée comme avant ; une valeur déjà échappée ne bouge pas.
const ENTITE_SURE = /&(amp|lt|gt|quot|#0*39|#x0*27);/gi;
const DESENTITE = { amp: "&", lt: "<", gt: ">", quot: '"' };
/** Rend leur caractère aux cinq entités que produit esc() (pour un objet, un texte brut). */
export function desechapper(s) {
  return String(s ?? "").replace(ENTITE_SURE, (_m, n)=>DESENTITE[n.toLowerCase()] ?? "'");
}
export function esc(s) {
  return desechapper(s).replace(/[&<>"']/g, (c)=>({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#039;"
    })[c]);
}
export function isValidEmail(e) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(e || "").trim());
}
export function formatDateBR(d) {
  if (!d) return "";
  const v = d instanceof Date ? d : new Date(d);
  if (isNaN(v.getTime())) return String(d);
  return `${String(v.getUTCDate()).padStart(2, "0")}/${String(v.getUTCMonth() + 1).padStart(2, "0")}/${v.getUTCFullYear()}`;
}
export const DEFAULT_NOTIFICATION_TIMEZONE = Deno.env.get("DEFAULT_NOTIFICATION_TIMEZONE") || Deno.env.get("DEFAULT_TIMEZONE") || "UTC";
export function formatDateTimeInZone(d, tz = DEFAULT_NOTIFICATION_TIMEZONE) {
  if (!d) return "";
  const v = d instanceof Date ? d : new Date(d);
  if (isNaN(v.getTime())) return String(d);
  try {
    const p = new Intl.DateTimeFormat("pt-BR", {
      timeZone: tz,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hour12: false
    }).formatToParts(v);
    const g = (t)=>p.find((x)=>x.type === t)?.value || "";
    // B1 fix (15/05/2026) : retrait du séparateur narratif "às" qui cassait
    // le split(" ") dans buildSlotVars de _shared/domain/consultas.ts.
    // La fonction retourne désormais "DD/MM/YYYY HH:MM" (un seul espace).
    // Le séparateur narratif ("às" en pt-BR, "à" en fr, "at" en en, etc.)
    // reste dans les templates i18n par locale (cohérent doctrine i18n).
    return `${g("day")}/${g("month")}/${g("year")} ${g("hour")}:${g("minute")}`;
  } catch  {
    return String(d);
  }
}
export function onlyUnique(a) {
  return Array.from(new Set(a));
}
export function joinTitles(items, sep = " | ") {
  return onlyUnique(items.map((x)=>x.trim()).filter(Boolean)).join(sep);
}
export function fullName(p) {
  return [
    p.first_name,
    p.last_name
  ].map((x)=>String(x || "").trim()).filter(Boolean).join(" ");
}
export function firstNameOnly(v) {
  const s = String(v || "").trim();
  return s ? s.split(/\s+/)[0] || "" : "";
}
export function adminDisplayName(n, e) {
  const f = String(n || "").trim();
  return f || String(e || "").trim() || "(sem e-mail válido)";
}
