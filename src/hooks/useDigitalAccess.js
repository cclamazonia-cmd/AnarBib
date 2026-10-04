import { useEffect, useMemo, useState } from 'react';
import { supabase } from '@/lib/supabase';

// ════════════════════════════════════════════════════════════════════════
// Accès numérique des livres affichés (migration 20261004215035).
//
// Remplace has_online_reading des vues matérialisées, qui ne comptait que les
// PDF réservés : 19 livres à PDF public n'avaient aucun badge (04/10/2026).
// La RPC rend, par livre visible de l'appelant : les usages publics (lire,
// écouter, voir, lien), la présence d'une ressource réservée, si l'appelant
// peut la lire, et les bibliothèques détentrices à nommer.
//
// Renvoie une Map book_id → ligne. Un livre absent n'a rien en ligne.
// ════════════════════════════════════════════════════════════════════════

const MAX_IDS = 500; // borne de la RPC

export function useDigitalAccess(bookIds, userId = null) {
  // Clé stable : même ensemble d'identifiants = pas de nouvelle requête.
  const cle = useMemo(() => {
    const ids = [...new Set((bookIds || []).map(Number).filter((n) => Number.isFinite(n) && n > 0))];
    ids.sort((a, b) => a - b);
    return ids.slice(0, MAX_IDS).join(',');
  }, [bookIds]);
  const [acces, setAcces] = useState(() => new Map());

  useEffect(() => {
    if (!cle) { setAcces(new Map()); return; }
    let annule = false;
    supabase.rpc('catalog_digital_access_v1', { p_book_ids: cle.split(',').map(Number) })
      .then(({ data, error }) => {
        if (annule) return;
        if (error) { console.warn('catalog_digital_access_v1:', error.message); return; }
        setAcces(new Map((data || []).map((r) => [Number(r.book_id), r])));
      });
    return () => { annule = true; };
  }, [cle, userId]);

  return acces;
}

// Ce que le badge doit dire pour un livre (ou l'union des éditions d'une
// œuvre). null : rien en ligne.
//   { kind: 'public', usage }       — lisible par toutes et tous
//   { kind: 'reserved-open', libs } — réservé, et l'appelant peut lire
//   { kind: 'reserved', libs }      — réservé à d'autres lecteur·rices
const ORDRE_USAGES = ['leitura_online', 'escuta_online', 'visualizacao_online', 'link_externo'];

export function digitalBadge(rows) {
  const lignes = (Array.isArray(rows) ? rows : [rows]).filter(Boolean);
  if (!lignes.length) return null;
  const usages = new Set(lignes.flatMap((r) => r.public_usages || []));
  const usage = ORDRE_USAGES.find((u) => usages.has(u));
  if (usage) return { kind: 'public', usage };
  const reserves = lignes.filter((r) => r.has_restricted);
  if (!reserves.length) return null;
  const libs = [...new Map(reserves.flatMap((r) => r.restricted_libraries || [])
    .map((l) => [l.slug || l.name, l.name || l.slug])).values()];
  return { kind: reserves.some((r) => r.can_read_restricted) ? 'reserved-open' : 'reserved', libs };
}
