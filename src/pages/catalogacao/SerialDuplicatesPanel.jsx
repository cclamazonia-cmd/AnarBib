import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

// ═══════════════════════════════════════════════════════════════════════════
// SerialDuplicatesPanel — doublons parmi les TITRES de périodiques.
//
// Symétrique inverse de la règle anti-faux-doublons du catalogue : deux
// FASCICULES de désignations différentes ne sont pas des doublons, mais deux
// TITRES proches en sont de vrais candidats. D'où une détection à part,
// public.suggest_serial_duplicates, triée par niveau de preuve :
//   issn > titre_exact > issn_de_liaison > titre_proche.
//
// DEUX GESTES SEULEMENT, ET C'EST DÉLIBÉRÉ :
//
//   · « Ce ne sont pas des doublons » — immédiat, et RÉVERSIBLE dès l'origine.
//     L'irréversibilité de book_not_duplicate a été un défaut du réseau, qu'il
//     a fallu corriger après coup ; on ne le reproduit pas. Les paires écartées
//     restent listées en bas, avec qui a tranché et pourquoi, et se rétablissent
//     d'un clic. Une décision qu'on ne peut pas relire ne peut pas être
//     contestée.
//
//   · « Proposer la fusion » — qui MÈNE À L'ATELIER, et n'y fusionne rien
//     tout de suite. Le commentaire de public.serials le dit depuis le premier
//     paquet : création, correction et fusion des autorités passent par
//     l'Atelier. Une fusion supprime une autorité que d'autres bibliothèques
//     utilisent peut-être — elle se délibère (14 jours de délai), elle ne se
//     clique pas au fil du catalogage. C'est aussi pour cela qu'il n'y a pas
//     d'aperçu de fusion ici : ce qui serait détruit se lit dans la
//     proposition, pas dans une modale qu'on ferme trop vite.
//
// Le sens de la fusion est un choix humain : deux boutons, « garder celui-ci »
// de chaque côté. Rien ne devine lequel des deux titres est le bon.
// ═══════════════════════════════════════════════════════════════════════════

const NIVEAUX = { issn: 1, titre_exact: 2, issn_de_liaison: 3, titre_proche: 4 };

export default function SerialDuplicatesPanel({ isActive, onChanged }) {
  const { formatMessage: t } = useIntl();
  const [paires, setPaires] = useState([]);
  const [ecartees, setEcartees] = useState([]);
  const [loading, setLoading] = useState(true);
  const [loaded, setLoaded] = useState(false);
  const [busy, setBusy] = useState(null);
  const [msg, setMsg] = useState(null);
  const [motifs, setMotifs] = useState({});

  const load = useCallback(async () => {
    setLoading(true);
    const [dup, nd] = await Promise.all([
      supabase.rpc('suggest_serial_duplicates', { p_max: 200 }),
      supabase.rpc('list_serials_not_duplicate', { p_max: 100 }),
    ]);
    setPaires(Array.isArray(dup.data) ? dup.data : []);
    setEcartees(Array.isArray(nd.data) ? nd.data : []);
    setLoading(false);
    setLoaded(true);
  }, []);

  // `isActive` : le panneau reste monté (masqué en CSS), et la détection coûte
  // un balayage trigramme sur toute la table — on ne la lance qu'à l'ouverture.
  useEffect(() => { if (isActive && !loaded) load(); }, [isActive, loaded, load]);

  async function act(key, fn, okKey, failKey) {
    setBusy(key); setMsg(null);
    const { error } = await fn();
    if (error) setMsg({ text: localizeError(error, t, failKey), kind: 'error' });
    else { setMsg({ text: t({ id: okKey }), kind: 'ok' }); await load(); onChanged?.(); }
    setBusy(null);
  }

  const ecarter = (r) => act(`nd-${r.serial_id_a}-${r.serial_id_b}`,
    () => supabase.rpc('mark_serials_not_duplicate', {
      p_a: r.serial_id_a, p_b: r.serial_id_b,
      p_reason: (motifs[`${r.serial_id_a}-${r.serial_id_b}`] || '').trim() || null }),
    'catalogacao.serialDup.discarded', 'catalogacao.serialDup.failed');

  const retablir = (r) => act(`un-${r.serial_id_a}-${r.serial_id_b}`,
    () => supabase.rpc('unmark_serials_not_duplicate', { p_a: r.serial_id_a, p_b: r.serial_id_b }),
    'catalogacao.serialDup.restored', 'catalogacao.serialDup.failed');

  // La proposition part à l'Atelier : rien n'est fusionné maintenant.
  const proposer = (r, keepA) => {
    const can = keepA ? r.serial_id_a : r.serial_id_b;
    const dup = keepA ? r.serial_id_b : r.serial_id_a;
    const canT = keepA ? r.titre_a : r.titre_b;
    const dupT = keepA ? r.titre_b : r.titre_a;
    return act(`pr-${r.serial_id_a}-${r.serial_id_b}`,
      () => supabase.schema('api').rpc('fn_authority_propose', {
        p_kind: 'fusion', p_target_kind: 'serial',
        p_target_id: dup, p_merge_into_id: can,
        p_payload: { duplicate_name: dupT, canonical_name: canT },
        p_rationale: t({ id: 'catalogacao.serialDup.rationale' },
          { dup: dupT, dupId: dup, can: canT, canId: can, niveau: r.niveau_preuve }) }),
      'catalogacao.serialDup.proposed', 'catalogacao.serialDup.failed');
  };

  const cote = (titre, slug, issn, nb) => (
    <div style={{ flex: '1 1 220px', minWidth: 0 }}>
      <div style={{ fontWeight: 600, fontSize: '.86rem' }}>{titre}</div>
      <div style={sub}>
        {[slug, issn && `ISSN ${issn}`, t({ id: 'catalogacao.serialGov.issues' }, { count: nb || 0 })]
          .filter(Boolean).join(' · ')}
      </div>
    </div>
  );

  return (
    <div style={{ marginTop: 26 }}>
      <div style={{ fontSize: '.78rem', textTransform: 'uppercase', letterSpacing: '.05em',
        color: 'var(--brand-muted, #999)', fontWeight: 700, marginBottom: 4 }}>
        {t({ id: 'catalogacao.serialDup.title' })}
      </div>
      <p style={{ ...sub, marginTop: 0 }}>{t({ id: 'catalogacao.serialDup.intro' })}</p>

      {msg && <div style={{ fontSize: '.82rem', margin: '6px 0', color: msg.kind === 'error' ? '#f87171' : '#4ade80' }}>{msg.text}</div>}

      {loading ? (
        <div className="cat-placeholder">{t({ id: 'common.loading' })}</div>
      ) : paires.length === 0 ? (
        <div className="cat-placeholder">{t({ id: 'catalogacao.serialDup.empty' })}</div>
      ) : (
        paires.map(r => {
          const key = `${r.serial_id_a}-${r.serial_id_b}`;
          return (
            <div key={key} style={carte}>
              <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', alignItems: 'flex-start' }}>
                {cote(r.titre_a, r.slug_a, r.issn_a, r.fascicules_a)}
                <div style={{ alignSelf: 'center' }}>
                  <span style={{ ...badge, ...(NIVEAUX[r.niveau_preuve] <= 2 ? badgeFort : {}) }}>
                    {t({ id: `catalogacao.serialDup.level.${r.niveau_preuve}` })}
                  </span>
                </div>
                {cote(r.titre_b, r.slug_b, r.issn_b, r.fascicules_b)}
              </div>
              <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center', marginTop: 8 }}>
                <button className="ab-button ab-button--secondary" style={btnSm} disabled={busy === `pr-${key}`}
                  onClick={() => proposer(r, true)}>
                  {t({ id: 'catalogacao.serialDup.keepThis' }, { titre: r.titre_a })}
                </button>
                <button className="ab-button ab-button--secondary" style={btnSm} disabled={busy === `pr-${key}`}
                  onClick={() => proposer(r, false)}>
                  {t({ id: 'catalogacao.serialDup.keepThis' }, { titre: r.titre_b })}
                </button>
                <input className="ab-input" style={{ flex: '1 1 160px', fontSize: '.78rem' }}
                  placeholder={t({ id: 'catalogacao.serialDup.reasonPh' })}
                  value={motifs[key] || ''} onChange={e => setMotifs(p => ({ ...p, [key]: e.target.value }))} />
                <button className="ab-button ab-button--ghost" style={btnSm} disabled={busy === `nd-${key}`}
                  onClick={() => ecarter(r)}>
                  {t({ id: 'catalogacao.serialDup.notDuplicate' })}
                </button>
              </div>
            </div>
          );
        })
      )}

      {/* Les paires écartées restent lisibles et se rétablissent : une décision
          qu'on ne peut pas relire ne peut pas être contestée. */}
      {ecartees.length > 0 && (
        <>
          <div style={{ ...sub, marginTop: 14, fontWeight: 700 }}>
            {t({ id: 'catalogacao.serialDup.discardedList' }, { count: ecartees.length })}
          </div>
          <ul style={{ listStyle: 'none', padding: 0, margin: 0 }}>
            {ecartees.map(r => (
              <li key={`${r.serial_id_a}-${r.serial_id_b}`} style={{ ...sub, padding: '3px 0' }}>
                « {r.titre_a} » / « {r.titre_b} »
                {r.reason && <> — {r.reason}</>}
                {r.created_by_name && <> · {r.created_by_name}</>}
                <button className="ab-button ab-button--ghost" style={btnXs}
                  disabled={busy === `un-${r.serial_id_a}-${r.serial_id_b}`} onClick={() => retablir(r)}>
                  {t({ id: 'catalogacao.serialDup.restore' })}
                </button>
              </li>
            ))}
          </ul>
        </>
      )}
    </div>
  );
}

const sub = { fontSize: '.74rem', color: 'var(--brand-muted, #999)', marginTop: 2 };
const carte = { border: '1px solid rgba(255,255,255,.12)', borderRadius: 8, padding: '10px 12px', marginBottom: 10 };
const badge = { fontSize: '.62rem', textTransform: 'uppercase', letterSpacing: '.03em', padding: '1px 6px',
  borderRadius: 4, background: 'rgba(255,255,255,.10)', color: 'var(--brand-muted, #bbb)', whiteSpace: 'nowrap' };
const badgeFort = { background: 'rgba(248,113,113,.16)', color: '#f87171' };
const btnSm = { fontSize: '.75rem', padding: '4px 10px' };
const btnXs = { fontSize: '.7rem', padding: '2px 8px', marginLeft: 6 };
