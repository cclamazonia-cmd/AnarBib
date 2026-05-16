export function esc(s) {
  return s.replace(/[&<>"']/g, (c)=>({
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
export function fullNameFromParts(f, l) {
  return [
    f,
    l
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
