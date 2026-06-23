import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';

// Centre de notifications lecteur·rice (cloche in-app).
// Source : table public.user_notifications, lisible sous RLS (policy
// « read own »). Écritures via RPC SECURITY DEFINER fn_mark_notifications_read
// (p_ids bigint[]). Conforme DOC-RPC-3 (lecture from() sous RLS, écriture RPC).
const PAGE = 30;
const POLL_MS = 60_000;

export function useNotifications() {
  const { user } = useAuth();
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(false);

  const load = useCallback(async () => {
    if (!user?.id) { setItems([]); return; }
    setLoading(true); setError(false);
    const { data, error: err } = await supabase
      .from('user_notifications')
      .select('id, category, title, body, link_type, link_id, is_read, read_at, created_at')
      .is('archived_at', null)
      .order('created_at', { ascending: false })
      .limit(PAGE);
    if (err) { setError(true); setItems([]); }
    else { setItems(data || []); }
    setLoading(false);
  }, [user?.id]);

  useEffect(() => {
    load();
    if (!user?.id) return undefined;
    const t = setInterval(load, POLL_MS);
    return () => clearInterval(t);
  }, [load, user?.id]);

  const unreadCount = items.reduce((acc, n) => acc + (n.is_read ? 0 : 1), 0);

  const markRead = useCallback(async (ids) => {
    const list = (Array.isArray(ids) ? ids : [ids]).filter(Boolean);
    if (!list.length) return;
    // Optimiste : on marque lu localement, on resynchronise si l'RPC échoue.
    setItems(prev => prev.map(n => (list.includes(n.id) ? { ...n, is_read: true } : n)));
    const { error: err } = await supabase.rpc('fn_mark_notifications_read', { p_ids: list });
    if (err) load();
  }, [load]);

  const markAllRead = useCallback(async () => {
    const unread = items.filter(n => !n.is_read).map(n => n.id);
    if (unread.length) await markRead(unread);
  }, [items, markRead]);

  return { items, unreadCount, loading, error, reload: load, markRead, markAllRead };
}
