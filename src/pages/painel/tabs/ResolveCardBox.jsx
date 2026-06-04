import { useState, useEffect } from 'react';
import { Button } from '@/components/ui';
import { supabase } from '@/lib/supabase';

// ═══════════════════════════════════════════════════════════
// ResolveCardBox — résolution staff d'une carte-lecteur
// ───────────────────────────────────────────────────────────
// Spec-carte-lecteur v0.2 §5.3. Le staff saisit le jeton (le scan
// caméra viendra avec le socle PWA + scanner) -> api.resolve_reader_card
// -> identité du·de la lecteur·rice. Réservé staff : la RPC re-vérifie
// côté serveur la qualité staff (librarian/coordenador) + RLS sur la
// bibliothèque du jeton. token_not_found et not_staff_of_library
// partagent un message NEUTRE (pas de fuite inter-bibliothèques). Le
// clair n'est jamais conservé ni loggé. onResolved(result) (optionnel)
// remonte l'identité au parent (ici : pré-remplir la recherche avec le
// public_id, pour ouvrir la fiche complète sans course d'état).
// ═══════════════════════════════════════════════════════════
export default function ResolveCardBox({ t, libraryId, onResolved }) {
  const [token, setToken] = useState('');
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState(null);
  const [errMsg, setErrMsg] = useState('');

  // Capacité opt-in par bibliothèque (libraries.reader_cards_enabled).
  // Le résolveur n'a de sens que là où la carte est activée : on ne
  // l'affiche pas du tout sinon. Défaut sûr = caché tant que non confirmé
  // (erreur de lecture / capacité absente → résolveur masqué).
  const [enabled, setEnabled] = useState(false);
  useEffect(() => {
    let alive = true;
    if (!libraryId) { setEnabled(false); return undefined; }
    (async () => {
      const { data, error } = await supabase
        .from('libraries')
        .select('reader_cards_enabled')
        .eq('id', libraryId)
        .maybeSingle();
      if (alive) setEnabled(!error && data?.reader_cards_enabled === true);
    })();
    return () => { alive = false; };
  }, [libraryId]);

  const resolve = async () => {
    const tok = token.trim();
    if (!tok || busy) return;
    setBusy(true); setErrMsg(''); setResult(null);
    try {
      const { data, error } = await supabase.schema('api').rpc('resolve_reader_card', { p_token: tok });
      if (error) { setErrMsg(t({ id: 'card.resolve.error.generic' })); return; }
      if (!data?.ok) {
        const reason = data?.reason;
        // token_not_found + not_staff_of_library -> message neutre commun (anti-fuite)
        const key = (reason === 'token_not_found' || reason === 'not_staff_of_library')
          ? 'card.resolve.error.unrecognized'
          : `card.resolve.error.${reason || 'generic'}`;
        setErrMsg(t({ id: key, defaultMessage: t({ id: 'card.resolve.error.generic' }) }));
        return;
      }
      setToken('');                 // ne jamais conserver le clair
      setResult(data);
      if (onResolved) onResolved(data);
    } catch {
      setErrMsg(t({ id: 'card.resolve.error.generic' }));
    } finally {
      setBusy(false);
    }
  };

  if (!enabled) return null;

  return (
    <div>
      <div className="ab-painel-reader-search">
        <input
          type="text"
          value={token}
          autoComplete="off"
          onChange={e => setToken(e.target.value)}
          placeholder={t({ id: 'card.resolve.placeholder' })}
          className="ab-painel-input"
          onKeyDown={e => e.key === 'Enter' && resolve()}
        />
        <Button onClick={resolve} disabled={busy}>
          {busy ? t({ id: 'card.resolve.loading' }) : t({ id: 'card.resolve.action' })}
        </Button>
      </div>
      {errMsg && <p className="ab-painel-msg">{errMsg}</p>}
      {result && (
        <div className="ab-painel-reader-card">
          <h3>{result.display_name || result.public_id}</h3>
          <p>{t({ id: 'panel.reader.id' })}: {result.public_id}</p>
          {result.is_restricted && (
            <div className="ab-painel-frozen-badge">
              <span className="ab-painel-frozen-badge__text">{t({ id: 'card.resolve.result.restricted' })}</span>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
