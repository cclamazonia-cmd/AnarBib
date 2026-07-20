import { useState, useEffect, useCallback, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

// =============================================================================
// WorkspaceInspectorModal (EA-01, chantier-cadre Biblioteca, 21/05/2026)
// =============================================================================
// Modale de lecture de la configuration institutionnelle brute d'une
// bibliotheque. Restaure le sous-encart « workspace JSON / Ver tudo » du
// HTML d'origine, absent du JSX.
// Cf. docs/journal/chantiers/CHANTIER_audit_biblioteca_parite_doctrinale_2026-05-21.md
//
// Outil de DIAGNOSTIC en lecture seule : affiche l'objet renvoye par
// api.get_library_institutional_workspace (10 blocs : library, service_state,
// contact_profile, document_governance, notification_context, theme_config,
// active_regulation_document, regulation_documents, active_policy_set,
// policy_sets), formate et colore legerement pour la lisibilite.
//
// Securite (verifie en base 21/05) : le retour de la RPC ne contient AUCUN
// secret technique (la cle API Resend vit dans les Edge Function Secrets,
// espace separe, jamais expose par une RPC). Il contient des adresses mail
// de configuration, donnees personnelles que le coordenador gere deja.
// Garde : la modale est ouverte depuis l'onglet identity, lui-meme
// isCoord-only. Aucun masquage de champ necessaire.
//
// Doctrine RPC v3 : lecture via RPC api.get_library_institutional_workspace
// (lecture, autorisee). Appel a l'ouverture de la modale (etat frais).
// =============================================================================

// Coloration syntaxique JSON legere : enveloppe les tokens dans des <span>.
// Retourne un tableau de fragments React (cles + valeurs + ponctuation).
function colorizeJson(jsonText) {
  // Regex sur les tokens JSON : chaines (cle ou valeur), nombres, mots-cles.
  const tokenRe = /("(\\.|[^"\\])*"(\s*:)?|\b(true|false|null)\b|-?\d+(\.\d+)?([eE][+-]?\d+)?)/g;
  const out = [];
  let lastIndex = 0;
  let m;
  let key = 0;
  while ((m = tokenRe.exec(jsonText)) !== null) {
    if (m.index > lastIndex) {
      out.push(jsonText.slice(lastIndex, m.index));
    }
    const tok = m[0];
    let color = null;
    if (/^"/.test(tok)) {
      // chaine : cle si suivie de ':', sinon valeur
      color = /:\s*$/.test(tok) ? 'var(--anar-json-key, #6cb6ff)' : 'var(--anar-json-str, #7ee0a8)';
    } else if (/^(true|false|null)$/.test(tok)) {
      color = 'var(--anar-json-kw, #f5c878)';
    } else {
      color = 'var(--anar-json-num, #f5c878)';
    }
    out.push(<span key={key++} style={{ color }}>{tok}</span>);
    lastIndex = m.index + tok.length;
  }
  if (lastIndex < jsonText.length) out.push(jsonText.slice(lastIndex));
  return out;
}

export default function WorkspaceInspectorModal({ libraryId, open, onClose }) {
  const { formatMessage: t } = useIntl();

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [workspace, setWorkspace] = useState(null);
  const [copied, setCopied] = useState(false);

  // ── Chargement du workspace via RPC (a l'ouverture) ───────────────────────
  const load = useCallback(async () => {
    if (!libraryId) return;
    setLoading(true);
    setError('');
    setCopied(false);
    try {
      const { data, error: rpcError } = await supabase
        .schema('api')
        .rpc('get_library_institutional_workspace', { p_library_id: libraryId });
      if (rpcError) throw rpcError;
      setWorkspace(data ?? null);
    } catch (err) {
      setError(localizeError(err, t));
      setWorkspace(null);
    } finally {
      setLoading(false);
    }
  }, [libraryId]);

  // Charge a chaque ouverture (etat frais)
  useEffect(() => {
    if (open) load();
  }, [open, load]);

  // Fermeture sur Echap
  useEffect(() => {
    if (!open) return;
    const onKey = (e) => { if (e.key === 'Escape') onClose?.(); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onClose]);

  const jsonText = useMemo(
    () => (workspace ? JSON.stringify(workspace, null, 2) : ''),
    [workspace]
  );
  const colorized = useMemo(
    () => (jsonText ? colorizeJson(jsonText) : null),
    [jsonText]
  );

  async function copyJson() {
    if (!jsonText) return;
    try {
      await navigator.clipboard.writeText(jsonText);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      setError(t({ id: 'biblioteca.workspaceInspector.copyFailed' }));
    }
  }

  if (!open) return null;

  const blockCount = workspace && typeof workspace === 'object'
    ? Object.keys(workspace).length : 0;

  return (
    <div
      onClick={onClose}
      style={{
        position: 'fixed', inset: 0, zIndex: 1000,
        background: 'rgba(0,0,0,.55)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        padding: 16,
      }}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        role="dialog" aria-modal="true"
        style={{
          background: '#1c1c1e', color: '#f4f4f4',
          border: '1px solid rgba(255,255,255,.12)', borderRadius: 12,
          width: '100%', maxWidth: 620, maxHeight: '82vh',
          display: 'flex', flexDirection: 'column',
        }}
      >
        {/* En-tete */}
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap',
          padding: '0.85rem 1.1rem', borderBottom: '1px solid rgba(255,255,255,.1)',
        }}>
          <div style={{ fontSize: '.95rem', fontWeight: 600 }}>
            {t({ id: 'biblioteca.workspaceInspector.title' })}
          </div>
          <button className="cat-btn secondary" onClick={onClose}
            aria-label={t({ id: 'common.close' })}
            style={{ fontSize: '.85rem', padding: '3px 9px' }}>
            ✕
          </button>
        </div>

        {/* Barre d'actions */}
        <div style={{
          display: 'flex', alignItems: 'center', gap: 8,
          padding: '0.55rem 1.1rem', borderBottom: '1px solid rgba(255,255,255,.1)',
        }}>
          <button className="cat-btn secondary" onClick={copyJson}
            disabled={loading || !jsonText}
            style={{ fontSize: '.78rem', padding: '3px 10px' }}>
            {copied
              ? t({ id: 'biblioteca.workspaceInspector.copied' })
              : t({ id: 'biblioteca.workspaceInspector.copy' })}
          </button>
          <button className="cat-btn secondary" onClick={load}
            disabled={loading}
            style={{ fontSize: '.78rem', padding: '3px 10px' }}>
            {t({ id: 'biblioteca.workspaceInspector.reload' })}
          </button>
          <span style={{
            fontSize: '.72rem', color: 'var(--brand-muted)', marginLeft: 'auto',
          }}>
            {t({ id: 'biblioteca.workspaceInspector.meta' }, { count: blockCount })}
          </span>
        </div>

        {/* Corps */}
        <div style={{ padding: '0.9rem 1.1rem', overflow: 'auto' }}>
          {loading && (
            <div style={{ fontSize: '.85rem', color: 'var(--brand-muted)' }}>
              {t({ id: 'common.loading' })}
            </div>
          )}
          {!loading && error && (
            <div style={{ fontSize: '.85rem', color: '#e89090' }}>
              {t({ id: 'common.errorPrefix' }, { message: error })}
            </div>
          )}
          {!loading && !error && colorized && (
            <pre style={{
              margin: 0, fontFamily: 'var(--font-mono, monospace)',
              fontSize: '.76rem', lineHeight: 1.6,
              whiteSpace: 'pre-wrap', wordBreak: 'break-word',
            }}>
              {colorized}
            </pre>
          )}
          {!loading && !error && !colorized && (
            <div style={{ fontSize: '.85rem', color: 'var(--brand-muted)' }}>
              {t({ id: 'biblioteca.workspaceInspector.empty' })}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
