import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { useLibrary } from '@/contexts/LibraryContext';
import { canArbitrateDuplicates } from '@/lib/dedupRoles';
import { localizeError } from '@/lib/localizeError';

/**
 * Assistant de dédoublonnage en TROIS TEMPS (paquet DOUBLONS P6, lot 3).
 *
 * POURQUOI UN ASSISTANT. Le balayage global présente 266 paires dans une liste
 * où « Même œuvre », « Pas un doublon » et la fusion sont trois boutons de même
 * taille. Or 254 de ces paires relèvent de « Même œuvre » : on expose un geste
 * destructeur sur une liste dont 95 % des lignes n'appellent aucune destruction.
 * L'assistant pose UNE question à la fois, dans l'ordre décroissant de
 * réversibilité, et la plupart des paires sortent avant qu'on ne détruise rien.
 *
 *   Temps 1 — « Est-ce le même texte ? »   non → écarter la paire (réversible)
 *   Temps 2 — « Est-ce la même édition ? » non → « Même œuvre » (rien détruit)
 *   Temps 3 — l'aperçu de ce qui disparaît, puis confirmation saisie au clavier
 *
 * CE QUI DISTINGUE LE TEMPS 3. Jusqu'ici la confirmation disait « cette action
 * est irréversible » sans dire ce qu'elle détruisait. `preview_merge_book`
 * répond enfin : quelles métadonnées n'existeront plus nulle part, lesquelles
 * sont seulement écrasées, quels exemplaires migrent et sous quels tombos.
 *
 * UN PANNEAU, PAS UNE MODALE. Les panneaux du catalogage restent tous montés et
 * ne sont masqués qu'en CSS : une modale ouverte depuis un panneau inactif
 * devient invisible et bloque le défilement de la page. Tout se joue en ligne.
 *
 * PAS DE SCORING MAISON. On appelle `suggest_catalog_duplicates` telle quelle.
 * Un calcul de similarité réimplémenté ici finirait par diverger de celui du
 * balayage, et deux vues qui se contredisent sont pires qu'une seule imparfaite.
 *
 * CHARGEMENT PARESSEUX. Le balayage coûte ~4 s sur 2 700 notices. Comme le
 * panneau est monté en permanence, on ne le lance qu'à l'ouverture de l'onglet :
 * sinon chaque personne qui catalogue paierait ces 4 s sans jamais s'en servir.
 */
export default function DedupAssistantPanel({ isActive, onChanged }) {
  const { formatMessage: t } = useIntl();
  const { effectiveRole } = useLibrary();
  const arbitre = canArbitrateDuplicates(effectiveRole);

  const [charge, setCharge] = useState(false);   // le balayage a-t-il deja tourne ?
  const [loading, setLoading] = useState(false);
  const [rows, setRows] = useState([]);
  const [err, setErr] = useState('');
  const [bucket, setBucket] = useState('decider');
  const [busy, setBusy] = useState(false);

  // Paire en cours d'examen : { r, etape, survivant, apercu, motif, saisie }
  const [ex, setEx] = useState(null);

  const key = (r) => `${r.book_id_a}:${r.book_id_b}`;

  const charger = useCallback(async () => {
    setLoading(true); setErr('');
    const { data, error } = await supabase.rpc('suggest_catalog_duplicates', { p_max: 500 });
    if (error) setErr(localizeError(error, t));
    else setRows(data || []);
    setLoading(false); setCharge(true);
  }, [t]);

  useEffect(() => {
    if (isActive && !charge && !loading) charger();
  }, [isActive, charge, loading, charger]);

  // Temps 0 — le tri. « À décider » = ISBN, ou titre + année (+ éditeur) : une
  // douzaine de paires examinables. « À rapprocher » = titre seul, la bande
  // pleine de faux positifs où la seule action offerte est non destructive.
  const aDecider = rows.filter((r) => r.niveau_preuve !== 'titre_seul');
  const aRapprocher = rows.filter((r) => r.niveau_preuve === 'titre_seul');
  const listeAffichee = bucket === 'decider' ? aDecider : aRapprocher;

  const retirer = (r) => {
    setRows((prev) => prev.filter((x) => key(x) !== key(r)));
    setEx(null);
    onChanged?.();
  };

  async function appeler(fn, r) {
    setBusy(true); setErr('');
    const { error } = await fn();
    if (error) { setErr(localizeError(error, t)); setBusy(false); return false; }
    setBusy(false);
    retirer(r);
    return true;
  }

  // ── Temps 1 : ce ne sont pas les mêmes textes → écarter (réversible) ──────
  const ecarter = (r, motif) => appeler(() => supabase.rpc('mark_books_not_duplicate', {
    p_a: r.book_id_a, p_b: r.book_id_b, p_reason: motif?.trim() || null,
  }), r);

  // ── Temps 2 : même texte, éditions différentes → rapprocher (rien détruit) ─
  const memeOeuvre = (r) => appeler(() => supabase.rpc('group_books_as_editions', {
    p_book_ids: [r.book_id_a, r.book_id_b],
  }), r);

  // ── Temps 3 : charger l'aperçu pour le survivant choisi ───────────────────
  const chargerApercu = useCallback(async (r, survivant) => {
    setBusy(true); setErr('');
    const duplicate = survivant === r.book_id_a ? r.book_id_b : r.book_id_a;
    const { data, error } = await supabase.rpc('preview_merge_book', {
      p_canonical_id: survivant, p_duplicate_id: duplicate,
    });
    if (error) setErr(localizeError(error, t));
    setBusy(false);
    return error ? null : data;
  }, [t]);

  async function allerAuTemps2(r) {
    setBusy(true); setErr('');
    const { data, error } = await supabase
      .from('books').select('id, editora, isbn').in('id', [r.book_id_a, r.book_id_b]);
    setBusy(false);
    if (error) { setErr(localizeError(error, t)); return; }
    const details = Object.fromEntries((data || []).map((b) => [String(b.id), b]));
    setEx((p) => ({ ...p, etape: 2, details }));
  }

  async function allerAuTemps3(r, survivant) {
    const apercu = await chargerApercu(r, survivant);
    if (apercu) setEx({ r, etape: 3, survivant, apercu, saisie: '' });
  }

  async function changerSurvivant(survivant) {
    const apercu = await chargerApercu(ex.r, survivant);
    if (apercu) setEx((p) => ({ ...p, survivant, apercu, saisie: '' }));
  }

  const fusionner = (r, survivant) => appeler(() => supabase.rpc('merge_book', {
    p_canonical_id: survivant,
    p_duplicate_id: survivant === r.book_id_a ? r.book_id_b : r.book_id_a,
  }), r);

  // ── Rendu ────────────────────────────────────────────────────────────────
  const cote = (r, p) => ({
    id: r[`book_id_${p}`], ref: r[`ref_${p}`], titulo: r[`titulo_${p}`],
    autor: r[`autor_${p}`], ano: r[`ano_${p}`], libs: r[`bibliotecas_${p}`],
    ex: r[`exemplares_${p}`],
  });

  const boiteInfo = (contenu, ton = 'neutre') => (
    <div style={{
      padding: '10px 13px', borderRadius: 8, fontSize: '.85rem', marginBottom: 10,
      background: ton === 'danger' ? 'rgba(220,38,38,.12)' : 'rgba(255,255,255,.05)',
      color: ton === 'danger' ? '#f87171' : 'var(--brand-muted, #bbb)',
    }}>{contenu}</div>
  );

  const carteCote = (c, actif = false) => (
    <div key={c.id} style={{
      border: `1px solid ${actif ? 'var(--brand-color-primary, #7a0b14)' : 'rgba(255,255,255,.12)'}`,
      borderRadius: 8, padding: 10, fontSize: '.86rem',
    }}>
      <div style={{ fontWeight: 600 }}>{c.titulo}</div>
      <div style={{ color: 'var(--brand-muted, #aaa)' }}>{c.autor}</div>
      <div style={{ color: 'var(--brand-muted, #888)', fontSize: '.8rem', marginTop: 4 }}>
        {c.ref} · {c.libs || '—'} · {t({ id: 'catalogacao.dedup.copies' }, { count: c.ex })}
      </div>
      <div style={{ marginTop: 6 }}>
        <a className="ab-button ab-button--mini" href={`/livro/${c.id}`}>
          {t({ id: 'catalogacao.dedup.scanOpen' })}
        </a>
      </div>
    </div>
  );

  // Temps 2 : ce qui distingue une edition d'un doublon se lit sur trois
  // champs, donc on les montre GROS et cote a cote, pas noyes dans la fiche.
  const champEdition = (label, va, vb) => {
    const differe = (va || '') !== (vb || '');
    return (
      <div style={{ display: 'grid', gridTemplateColumns: 'minmax(0, 1fr) minmax(0, 1fr)', gap: 8, marginBottom: 6 }}>
        <div style={{
          padding: '8px 10px', borderRadius: 6, fontSize: '1rem',
          background: differe ? 'rgba(234,179,8,.12)' : 'rgba(255,255,255,.04)',
        }}>
          <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #999)' }}>{label}</div>
          {va || '—'}
        </div>
        <div style={{
          padding: '8px 10px', borderRadius: 6, fontSize: '1rem',
          background: differe ? 'rgba(234,179,8,.12)' : 'rgba(255,255,255,.04)',
        }}>
          <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #999)' }}>{label}</div>
          {vb || '—'}
        </div>
      </div>
    );
  };

  if (!arbitre) {
    return <p style={{ color: 'var(--brand-muted, #999)' }}>{t({ id: 'catalogacao.dedup.arbiterOnly' })}</p>;
  }

  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap', marginBottom: 8 }}>
        <span style={{ fontWeight: 600 }}>{t({ id: 'catalogacao.dedupAssist.title' })}</span>
        <button type="button" className="ab-button ab-button--secondary ab-button--sm"
          onClick={charger} disabled={loading || busy}>
          {loading ? t({ id: 'catalogacao.dedup.finding' }) : t({ id: 'catalogacao.dedup.find' })}
        </button>
      </div>

      <p style={{ fontSize: '.84rem', color: 'var(--brand-muted, #999)', marginTop: 0 }}>
        {t({ id: 'catalogacao.dedupAssist.intro' })}
      </p>

      {err && boiteInfo(err, 'danger')}

      {!loading && charge && (
        <>
          <div style={{ display: 'flex', borderBottom: '2px solid rgba(255,255,255,.08)', marginBottom: 12, flexWrap: 'wrap' }}>
            {[['decider', 'catalogacao.dedupAssist.bucketDecide', aDecider.length],
              ['rapprocher', 'catalogacao.dedupAssist.bucketGroup', aRapprocher.length]].map(([id, cle, n]) => (
              <button key={id} type="button" onClick={() => { setBucket(id); setEx(null); }}
                style={{
                  padding: '8px 16px', fontSize: '.88rem', fontWeight: 600, background: 'none',
                  border: 'none', cursor: 'pointer', marginBottom: -2,
                  borderBottom: `2px solid ${bucket === id ? 'var(--brand-color-primary, #7a0b14)' : 'transparent'}`,
                  color: bucket === id ? 'var(--brand-text, #f4f4f4)' : 'var(--brand-muted, #aaa)',
                }}>
                {t({ id: cle })} ({n})
              </button>
            ))}
          </div>

          <p style={{ fontSize: '.82rem', color: 'var(--brand-muted, #888)', marginTop: 0, marginBottom: 12 }}>
            {t({ id: bucket === 'decider' ? 'catalogacao.dedupAssist.helpDecide' : 'catalogacao.dedupAssist.helpGroup' })}
          </p>

          {listeAffichee.length === 0 && <p>{t({ id: 'catalogacao.dedup.none' })}</p>}

          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {listeAffichee.map((r) => {
              const ouvert = ex && key(ex.r) === key(r);
              const a = cote(r, 'a'); const b = cote(r, 'b');
              return (
                <div key={key(r)} style={{
                  border: '1px solid rgba(255,255,255,.12)', borderRadius: 10, padding: 12,
                  opacity: busy && ouvert ? 0.6 : 1,
                }}>
                  <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 8, flexWrap: 'wrap' }}>
                    <span style={{ fontWeight: 600, fontSize: '.9rem' }}>{a.titulo}</span>
                    <span style={{ fontSize: '.78rem', color: 'var(--brand-muted, #999)' }}>{a.autor}</span>
                    {!ouvert && (
                      <button type="button" className="ab-button ab-button--mini ab-button--secondary"
                        style={{ marginLeft: 'auto' }} disabled={busy}
                        onClick={() => setEx({ r, etape: 1, motif: '' })}>
                        {t({ id: 'catalogacao.dedupAssist.examine' })}
                      </button>
                    )}
                  </div>

                  {/* ── TEMPS 1 : est-ce le même texte ? ───────────────── */}
                  {ouvert && ex.etape === 1 && (
                    <div>
                      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: 10, marginBottom: 10 }}>
                        {carteCote(a)}{carteCote(b)}
                      </div>
                      <div style={{ fontWeight: 600, fontSize: '1.05rem', marginBottom: 8 }}>
                        {t({ id: 'catalogacao.dedupAssist.step1Question' })}
                      </div>
                      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center' }}>
                        <button type="button" className="ab-button ab-button--sm" disabled={busy}
                          onClick={() => allerAuTemps2(r)}>
                          {t({ id: 'catalogacao.dedupAssist.step1Yes' })}
                        </button>
                        <input type="text" value={ex.motif || ''} disabled={busy}
                          onChange={(e) => setEx((p) => ({ ...p, motif: e.target.value }))}
                          placeholder={t({ id: 'catalogacao.dedup.reasonPlaceholder' })}
                          style={{
                            flex: '1 1 200px', minWidth: 0, padding: '7px 10px', borderRadius: 8,
                            border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)',
                            color: '#f4f4f4', fontSize: '.85rem',
                          }} />
                        <button type="button" className="ab-button ab-button--sm ab-button--secondary" disabled={busy}
                          onClick={() => ecarter(r, ex.motif)}>
                          {t({ id: 'catalogacao.dedupAssist.step1No' })}
                        </button>
                        <button type="button" className="ab-button ab-button--mini ab-button--secondary"
                          disabled={busy} onClick={() => setEx(null)}>
                          {t({ id: 'common.cancel' })}
                        </button>
                      </div>
                    </div>
                  )}

                  {/* ── TEMPS 2 : est-ce la même édition ? ─────────────── */}
                  {ouvert && ex.etape === 2 && (
                    <div>
                      {champEdition(t({ id: 'catalogacao.field.year' }), a.ano, b.ano)}
                      {champEdition(t({ id: 'catalogacao.field.publisher' }),
                        ex.details?.[String(a.id)]?.editora, ex.details?.[String(b.id)]?.editora)}
                      {champEdition('ISBN',
                        ex.details?.[String(a.id)]?.isbn, ex.details?.[String(b.id)]?.isbn)}
                      <div style={{ fontWeight: 600, fontSize: '1.05rem', margin: '10px 0 8px' }}>
                        {t({ id: 'catalogacao.dedupAssist.step2Question' })}
                      </div>
                      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                        <button type="button" className="ab-button ab-button--sm" disabled={busy}
                          onClick={() => allerAuTemps3(r, r.book_id_a)}>
                          {t({ id: 'catalogacao.dedupAssist.step2Yes' })}
                        </button>
                        <button type="button" className="ab-button ab-button--sm ab-button--secondary" disabled={busy}
                          onClick={() => memeOeuvre(r)}>
                          {t({ id: 'catalogacao.dedupAssist.step2No' })}
                        </button>
                        <button type="button" className="ab-button ab-button--mini ab-button--secondary"
                          disabled={busy} onClick={() => setEx((p) => ({ ...p, etape: 1 }))}>
                          {t({ id: 'catalogacao.dedupAssist.back' })}
                        </button>
                      </div>
                    </div>
                  )}

                  {/* ── TEMPS 3 : ce que la fusion détruit ─────────────── */}
                  {ouvert && ex.etape === 3 && ex.apercu && (
                    <ApercuFusion
                      ex={ex} r={r} busy={busy} t={t}
                      onSurvivant={changerSurvivant}
                      onRetour={() => setEx((p) => ({ ...p, etape: 2 }))}
                      onSaisie={(v) => setEx((p) => ({ ...p, saisie: v }))}
                      onFusion={() => fusionner(r, ex.survivant)}
                    />
                  )}
                </div>
              );
            })}
          </div>
        </>
      )}
    </div>
  );
}

// ── Temps 3, isolé pour rester lisible ─────────────────────────────────────
// Ne prend AUCUNE décision : il affiche ce que `preview_merge_book` a renvoyé.
// La confirmation exige de saisir la référence de la fiche qui disparaît —
// taper le titre serait pénible, cliquer serait trop peu : la référence est
// courte, et la lire oblige à regarder LAQUELLE des deux meurt.
function ApercuFusion({ ex, r, busy, t, onSurvivant, onRetour, onSaisie, onFusion }) {
  const ap = ex.apercu;
  const perdues = ap.metadonnees_perdues || [];
  const divergentes = ap.metadonnees_divergentes || [];
  const exemplaires = ap.exemplaires || [];
  const refSupprimee = ap.doublon?.ref || String(ap.doublon?.id || '');
  const peutFusionner = (ex.saisie || '').trim() === refSupprimee && !busy;

  const ligne = (cle, valeur) => (
    <div key={cle} style={{ fontSize: '.82rem', padding: '3px 0' }}>
      <span style={{ color: 'var(--brand-muted, #999)' }}>{cle}</span> — {valeur}
    </div>
  );

  return (
    <div>
      <div style={{ fontWeight: 600, fontSize: '1.05rem', marginBottom: 8 }}>
        {t({ id: 'catalogacao.dedupAssist.step3Title' })}
      </div>

      <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #bbb)', marginBottom: 6 }}>
        {t({ id: 'catalogacao.dedupAssist.keepWhich' })}
      </div>
      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 12 }}>
        {[r.book_id_a, r.book_id_b].map((id) => (
          <button key={id} type="button" disabled={busy}
            className={`ab-button ab-button--sm${ex.survivant === id ? '' : ' ab-button--secondary'}`}
            onClick={() => onSurvivant(id)}>
            {id === r.book_id_a ? r.ref_a : r.ref_b} — {id === r.book_id_a ? r.titulo_a : r.titulo_b}
          </button>
        ))}
      </div>

      {/* La perte sèche d'abord : ces valeurs n'existeront plus nulle part. */}
      <div style={{
        border: '1px solid rgba(220,38,38,.35)', borderRadius: 8, padding: 10, marginBottom: 10,
      }}>
        <div style={{ fontWeight: 600, fontSize: '.85rem', color: '#f87171', marginBottom: 4 }}>
          {t({ id: 'catalogacao.dedupAssist.lost' })} ({perdues.length})
        </div>
        {perdues.length === 0
          ? <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #999)' }}>
              {t({ id: 'catalogacao.dedupAssist.nothingLost' })}
            </div>
          : perdues.map((m) => ligne(m.champ, String(m.valeur)))}
      </div>

      {divergentes.length > 0 && (
        <div style={{ border: '1px solid rgba(234,179,8,.3)', borderRadius: 8, padding: 10, marginBottom: 10 }}>
          <div style={{ fontWeight: 600, fontSize: '.85rem', color: '#eab308', marginBottom: 4 }}>
            {t({ id: 'catalogacao.dedupAssist.diverging' })} ({divergentes.length})
          </div>
          {divergentes.map((m) => ligne(m.champ,
            `${String(m.valeur_perdue)} → ${String(m.valeur_conservee)}`))}
        </div>
      )}

      <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #bbb)', marginBottom: 10 }}>
        {t({ id: 'catalogacao.dedupAssist.copiesMove' }, { count: ap.exemplaires_total || 0 })}
        {exemplaires.length > 0 && ' : '}
        {exemplaires.map((e) => `${e.tombo} (${e.bibliotheque})`).join(', ')}
      </div>

      {(ap.circulation?.emprestimos || ap.circulation?.reservas
        || ap.circulation?.peb || ap.circulation?.consultas || ap.ressources_numeriques) > 0 && (
        <div style={{ fontSize: '.8rem', color: 'var(--brand-muted, #999)', marginBottom: 10 }}>
          {t({ id: 'catalogacao.dedupAssist.circulation' }, {
            emprestimos: ap.circulation?.emprestimos || 0,
            reservas: ap.circulation?.reservas || 0,
            consultas: ap.circulation?.consultas || 0,
            numeriques: ap.ressources_numeriques || 0,
          })}
        </div>
      )}

      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center' }}>
        <span style={{ fontSize: '.82rem', color: 'var(--brand-muted, #bbb)' }}>
          {t({ id: 'catalogacao.dedupAssist.confirmPrompt' }, { ref: refSupprimee })}
        </span>
        <input type="text" value={ex.saisie || ''} disabled={busy}
          onChange={(e) => onSaisie(e.target.value)}
          placeholder={refSupprimee}
          style={{
            flex: '0 1 160px', minWidth: 0, padding: '7px 10px', borderRadius: 8,
            border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)',
            color: '#f4f4f4', fontSize: '.85rem',
          }} />
        <button type="button" className="ab-button ab-button--danger ab-button--sm"
          disabled={!peutFusionner} onClick={onFusion}>
          {t({ id: 'catalogacao.dedupAssist.doMerge' })}
        </button>
        <button type="button" className="ab-button ab-button--mini ab-button--secondary"
          disabled={busy} onClick={onRetour}>
          {t({ id: 'catalogacao.dedupAssist.back' })}
        </button>
      </div>
    </div>
  );
}
