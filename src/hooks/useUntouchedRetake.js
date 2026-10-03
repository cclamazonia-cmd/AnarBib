import { useCallback, useEffect, useRef } from 'react';
import { supabase, SUPABASE_URL, SUPABASE_ANON_KEY } from '@/lib/supabase';

// ════════════════════════════════════════════════════════════════════════
// Une reprise jamais enregistrée s'oublie (Xavier, 03/10/2026 ; migration
// 20261003202521_une_reprise_non_enregistree_s_oublie).
//
// « Reprendre » une notice, une autorité ou un exemplaire publiés crée un
// brouillon (create_*_draft_from_*). La base le marque retake_untouched tant
// qu'aucune écriture ne l'a suivi ; la file éditoriale ne le montre pas. Quand
// l'éditeur le quitte — autre brouillon, formulaire vidé, écran démonté, onglet
// fermé — on demande à la base de l'oublier. C'est elle qui décide : une
// reprise enregistrée entre-temps (même sans publication) n'est pas touchée, et
// l'appel rend simplement false. Un onglet tué sans pagehide est rattrapé par
// le job horaire (reprises vierges de plus de 24 h).
// ════════════════════════════════════════════════════════════════════════

export function discardUntouchedRetake(kind, id) {
  return supabase
    .rpc('discard_untouched_retake', { p_type: kind, p_id: Number(id) })
    .then(({ error }) => { if (error) console.warn('discard_untouched_retake:', error.message); });
}

// kind : 'book' | 'author' | 'exemplar' ; currentId : l'id du brouillon ouvert
// dans l'éditeur ('' quand le formulaire est vide).
// Rend track(record) — à appeler à chaque chargement d'un brouillon dans le
// formulaire ; seul un enregistrement encore vierge est retenu.
export function useUntouchedRetake(kind, currentId) {
  const pending = useRef(null);   // id (string) de la reprise vierge ouverte
  const token = useRef(null);     // jeton courant, lu sans attendre au pagehide

  const track = useCallback((record) => {
    const id = record?.id != null ? String(record.id) : '';
    // Un autre brouillon arrive alors qu'une reprise vierge était ouverte : le
    // formulaire passe de l'une à l'autre dans le même rendu, l'effet plus bas
    // ne verrait jamais le départ.
    if (pending.current && pending.current !== id) discardUntouchedRetake(kind, pending.current);
    pending.current = record?.retake_untouched && id ? id : null;
  }, [kind]);

  // Quitter la reprise : l'éditeur montre un autre brouillon, ou plus rien.
  useEffect(() => {
    const id = pending.current;
    if (id && id !== String(currentId ?? '')) {
      pending.current = null;
      discardUntouchedRetake(kind, id);
    }
  }, [kind, currentId]);

  // Démontage de l'éditeur (navigation dans l'application).
  useEffect(() => () => {
    const id = pending.current;
    pending.current = null;
    if (id) discardUntouchedRetake(kind, id);
  }, [kind]);

  // Fermeture ou rechargement de l'onglet : supabase-js n'a pas le temps de
  // répondre, d'où un fetch keepalive. Le jeton est tenu à jour à côté (pas
  // d'async dans onAuthStateChange : simple affectation).
  useEffect(() => {
    const { data } = supabase.auth.onAuthStateChange((_event, session) => {
      token.current = session?.access_token || null;
    });
    supabase.auth.getSession().then(({ data: d }) => { token.current = d?.session?.access_token || null; });
    function onPageHide() {
      const id = pending.current;
      if (!id || !token.current) return;
      pending.current = null;
      try {
        fetch(`${SUPABASE_URL}/rest/v1/rpc/discard_untouched_retake`, {
          method: 'POST',
          keepalive: true,
          headers: {
            apikey: SUPABASE_ANON_KEY,
            Authorization: `Bearer ${token.current}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ p_type: kind, p_id: Number(id) }),
        });
      } catch { /* le job horaire prendra le relais */ }
    }
    window.addEventListener('pagehide', onPageHide);
    return () => {
      window.removeEventListener('pagehide', onPageHide);
      data?.subscription?.unsubscribe();
    };
  }, [kind]);

  return track;
}
