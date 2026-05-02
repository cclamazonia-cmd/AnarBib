export function esc(s: string) { return s.replace(/[&<>"']/g,(c)=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"}[c] as string)); }
export function isValidEmail(e: unknown) { return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(e||"").trim()); }
export function formatDateBR(d: string|Date|null|undefined) { if (!d) return ""; const v = d instanceof Date?d:new Date(d); if (isNaN(v.getTime())) return String(d); return `${String(v.getUTCDate()).padStart(2,"0")}/${String(v.getUTCMonth()+1).padStart(2,"0")}/${v.getUTCFullYear()}`; }
export const DEFAULT_NOTIFICATION_TIMEZONE = Deno.env.get("DEFAULT_NOTIFICATION_TIMEZONE")||Deno.env.get("DEFAULT_TIMEZONE")||"UTC";
export function formatDateTimeInZone(d: string|Date|null|undefined, tz=DEFAULT_NOTIFICATION_TIMEZONE) { if (!d) return ""; const v = d instanceof Date?d:new Date(d); if (isNaN(v.getTime())) return String(d); try { const p=new Intl.DateTimeFormat("pt-BR",{timeZone:tz,year:"numeric",month:"2-digit",day:"2-digit",hour:"2-digit",minute:"2-digit",hour12:false}).formatToParts(v); const g=(t:string)=>p.find(x=>x.type===t)?.value||""; return `${g("day")}/${g("month")}/${g("year")} às ${g("hour")}:${g("minute")}`; } catch { return String(d); } }
export function onlyUnique<T>(a: T[]) { return Array.from(new Set(a)); }
export function joinTitles(items: string[], sep=" | ") { return onlyUnique(items.map(x=>x.trim()).filter(Boolean)).join(sep); }
export function fullName(p: Record<string,unknown>) { return [p.first_name,p.last_name].map(x=>String(x||"").trim()).filter(Boolean).join(" "); }
export function fullNameFromParts(f: unknown, l: unknown) { return [f,l].map(x=>String(x||"").trim()).filter(Boolean).join(" "); }
export function firstNameOnly(v: unknown) { const s=String(v||"").trim(); return s?s.split(/\s+/)[0]||"":""; }
export function adminDisplayName(n: unknown, e?: unknown) { const f=String(n||"").trim(); return f||String(e||"").trim()||"(sem e-mail válido)"; }
