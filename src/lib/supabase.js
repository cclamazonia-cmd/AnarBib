import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL
  || 'https://uflwmikiyjfnikiphtcp.supabase.co';

const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY
  || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVmbHdtaWtpeWpmbmlraXBodGNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4MzIyNDUsImV4cCI6MjA4OTQwODI0NX0.kCs7nPg08ofjb9CWwRH9xVN6BjanrAC5pj418line1o';

export const PROJECT_REF = 'uflwmikiyjfnikiphtcp';

// Client principal — schéma public (auth, profiles, tables métier, rpc)
export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
});

/**
 * Déclenche une notification mail via l'edge function notify-event.
 *
 * Appelée après chaque action de circulation réussie (réservation, workflow, emprunt, devolução).
 * Le edge function gère : quel mail envoyer, à qui (lecteur, bibliothèque, réseau),
 * et respecte les politiques de notification de chaque bibliothèque.
 *
 * @param {string} event - Type d'événement (ex: 'reserva_v2_criada', 'emprestimo_v2_criado', etc.)
 * @param {number} recordId - ID de la réservation ou de l'emprunt
 * @param {object} extra - Données supplémentaires optionnelles (line_nos, workflow_stage, etc.)
 */
export async function notifyEvent(event, recordId, extra = {}) {
  try {
    const { data, error } = await supabase.functions.invoke('notify-event', {
      body: { event, record_id: recordId, ...extra },
    });
    if (error) console.warn(`notifyEvent(${event}, ${recordId}) error:`, error);
    else console.log(`notifyEvent(${event}, ${recordId}) ok:`, data);
    return { data, error };
  } catch (err) {
    // Ne pas bloquer l'UX si la notification échoue
    console.warn(`notifyEvent(${event}, ${recordId}) failed silently:`, err);
    return { data: null, error: err };
  }
}

/**
 * Requête REST directe vers une vue du schéma "api".
 *
 * Reproduit exactement l'approche du frontend original :
 *   fetch(`${SUPABASE_URL}/rest/v1/${viewName}?select=...`, {
 *     headers: { 'Accept-Profile': 'api', Authorization: `Bearer ${token}` }
 *   })
 *
 * @param {string} viewName - Nom de la vue dans le schéma api
 * @param {object} options
 * @param {string} options.select - Colonnes à sélectionner (défaut: '*')
 * @param {string} options.order - Ordre de tri (ex: 'titulo.asc')
 * @param {number} options.rangeFrom - Début de pagination
 * @param {number} options.rangeTo - Fin de pagination
 * @param {object} options.filters - Filtres supplémentaires { column: 'eq.value' }
 * @returns {Promise<{ data: any[], error: any }>}
 */
export async function apiQuery(viewName, options = {}) {
  const {
    select = '*',
    order,
    rangeFrom,
    rangeTo,
    filters = {},
  } = options;

  // Construire l'URL
  const params = new URLSearchParams();
  params.set('select', select);
  if (order) params.set('order', order);

  // Filtres
  for (const [col, condition] of Object.entries(filters)) {
    params.set(col, condition);
  }

  const url = `${SUPABASE_URL}/rest/v1/${viewName}?${params.toString()}`;

  // Headers — exactement comme l'original
  const headers = {
    'apikey': SUPABASE_ANON_KEY,
    'Accept-Profile': 'api',
    'Content-Type': 'application/json',
  };

  // Ajouter le token auth si connecté
  try {
    const { data: { session } } = await supabase.auth.getSession();
    if (session?.access_token) {
      headers['Authorization'] = `Bearer ${session.access_token}`;
    } else {
      headers['Authorization'] = `Bearer ${SUPABASE_ANON_KEY}`;
    }
  } catch {
    headers['Authorization'] = `Bearer ${SUPABASE_ANON_KEY}`;
  }

  // Range header pour la pagination
  if (rangeFrom != null && rangeTo != null) {
    headers['Range'] = `${rangeFrom}-${rangeTo}`;
    headers['Range-Unit'] = 'items';
    // Prefer pour obtenir le count si nécessaire
    headers['Prefer'] = 'count=exact';
  }

  try {
    const res = await fetch(url, { headers });
    if (!res.ok) {
      const text = await res.text();
      console.error(`apiQuery ${viewName} failed:`, res.status, text);
      return { data: [], error: { status: res.status, message: text } };
    }
    const data = await res.json();
    return { data: data || [], error: null };
  } catch (err) {
    console.error(`apiQuery ${viewName} network error:`, err);
    return { data: [], error: err };
  }
}
