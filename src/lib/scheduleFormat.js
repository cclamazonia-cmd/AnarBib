// Helper partage pour formater un creneau de consultation.
// Utilise dans AccountPage (cote lecteur) et PanelPage (cote biblio).
// Paquet 27.A.6 (5.C, 14/05/2026).

/**
 * Formate un creneau de consultation pour affichage humain.
 * @param {{ consultation_starts_at?: string, consultation_ends_at?: string, consultation_scheduled_for?: string }} c
 * @returns {string} ex: "lundi 15 mai 2026 — 14:00–15:30" ou "" si pas de creneau
 */
export function formatSchedule(c) {
  if (!c) return '';
  const starts = c.consultation_starts_at || c.consultation_scheduled_for;
  const ends = c.consultation_ends_at;
  if (!starts) return '';
  try {
    const startDate = new Date(starts);
    const dateStr = startDate.toLocaleDateString(undefined, {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    });
    const startTime = startDate.toLocaleTimeString(undefined, {
      hour: '2-digit',
      minute: '2-digit',
    });
    if (ends) {
      const endTime = new Date(ends).toLocaleTimeString(undefined, {
        hour: '2-digit',
        minute: '2-digit',
      });
      return `${dateStr} \u2014 ${startTime}\u2013${endTime}`;
    }
    return `${dateStr} \u2014 ${startTime}`;
  } catch {
    return starts;
  }
}
