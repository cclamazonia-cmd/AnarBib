// Helper partage pour formater un creneau de consultation.
// Utilise dans AccountPage (cote lecteur) et PanelPage (cote biblio).
// Paquet 27.A.6 (5.C, 14/05/2026).

// Fuseau de repli quand la biblio n'a pas de consultation_timezone renseigne
// (= defaut de la colonne library_service_state.consultation_timezone).
const DEFAULT_TZ = 'America/Belem';

/**
 * Formate un creneau de consultation pour affichage humain, TOUJOURS dans le
 * fuseau de reference de la bibliotheque concernee (et non celui du navigateur).
 * Les timestamps sont stockes en UTC (timestamptz) ; on les projette dans
 * `timeZone` a l'affichage pour que lecteur et painel voient la meme heure
 * (celle de la biblio). Fuseau fourni via fn_library_timezones (cote lecteur)
 * ou l'etat consultationTz (cote painel). Repli America/Belem.
 * @param {{ consultation_starts_at?: string, consultation_ends_at?: string, consultation_scheduled_for?: string }} c
 * @param {string} [timeZone] IANA (ex. 'America/Belem').
 * @returns {string} ex: "lundi 15 mai 2026 — 14:00–15:30" ou "" si pas de creneau
 */
export function formatSchedule(c, timeZone) {
  if (!c) return '';
  const starts = c.consultation_starts_at || c.consultation_scheduled_for;
  const ends = c.consultation_ends_at;
  if (!starts) return '';
  const tz = timeZone || DEFAULT_TZ;
  try {
    const startDate = new Date(starts);
    const dateStr = startDate.toLocaleDateString(undefined, {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      year: 'numeric',
      timeZone: tz,
    });
    const startTime = startDate.toLocaleTimeString(undefined, {
      hour: '2-digit',
      minute: '2-digit',
      timeZone: tz,
    });
    if (ends) {
      const endTime = new Date(ends).toLocaleTimeString(undefined, {
        hour: '2-digit',
        minute: '2-digit',
        timeZone: tz,
      });
      return `${dateStr} — ${startTime}–${endTime}`;
    }
    return `${dateStr} — ${startTime}`;
  } catch {
    return starts;
  }
}
