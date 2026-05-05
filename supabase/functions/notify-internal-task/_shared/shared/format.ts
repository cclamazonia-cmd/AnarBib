export function esc(s) {
  return s.replace(/[&<>"']/g, (c)=>({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#039;"
    })[c]);
}
export function isValidEmail(email) {
  const s = String(email || "").trim();
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s);
}
export function formatDateBR(isoOrDate) {
  if (!isoOrDate) return "";
  const d = isoOrDate instanceof Date ? isoOrDate : new Date(isoOrDate);
  if (isNaN(d.getTime())) return String(isoOrDate);
  const dd = String(d.getUTCDate()).padStart(2, "0");
  const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
  const yyyy = d.getUTCFullYear();
  return `${dd}/${mm}/${yyyy}`;
}
export const DEFAULT_NOTIFICATION_TIMEZONE = Deno.env.get("DEFAULT_NOTIFICATION_TIMEZONE") || Deno.env.get("DEFAULT_TIMEZONE") || Deno.env.get("NETWORK_DEFAULT_TIMEZONE") || "UTC";
export function formatDateTimeInZone(isoOrDate, timeZone = DEFAULT_NOTIFICATION_TIMEZONE) {
  if (!isoOrDate) return "";
  const d = isoOrDate instanceof Date ? isoOrDate : new Date(isoOrDate);
  if (isNaN(d.getTime())) return String(isoOrDate);
  try {
    const parts = new Intl.DateTimeFormat("pt-BR", {
      timeZone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hour12: false
    }).formatToParts(d);
    const pick = (type)=>parts.find((p)=>p.type === type)?.value || "";
    const dd = pick("day");
    const mm = pick("month");
    const yyyy = pick("year");
    const hh = pick("hour");
    const mi = pick("minute");
    return `${dd}/${mm}/${yyyy} às ${hh}:${mi}`;
  } catch  {
    return String(isoOrDate);
  }
}
export function onlyUnique(arr) {
  return Array.from(new Set(arr));
}
export function joinTitles(items, sep = " | ") {
  const clean = items.map((x)=>x.trim()).filter(Boolean);
  return onlyUnique(clean).join(sep);
}
export function fullName(profile) {
  return [
    profile.first_name,
    profile.last_name
  ].map((x)=>String(x || "").trim()).filter(Boolean).join(" ");
}
export function fullNameFromParts(first, last) {
  return [
    first,
    last
  ].map((x)=>String(x || "").trim()).filter(Boolean).join(" ");
}
export function firstNameOnly(value) {
  const s = String(value || "").trim();
  if (!s) return "";
  return s.split(/\s+/)[0] || "";
}
export function adminDisplayName(name, email) {
  const full = String(name || "").trim();
  if (full) return full;
  return String(email || "").trim() || "(sem e-mail válido)";
}
