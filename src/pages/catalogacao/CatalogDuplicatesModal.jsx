import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { useLibrary } from '@/contexts/LibraryContext';
import { canArbitrateDuplicates } from '@/lib/dedupRoles';
import Modal from '@/components/ui/Modal';
import { localizeError } from '@/lib/localizeError';

/**
 * Dédoublonnage du catalogue PUBLIÉ (balayage global).
 *
 * Pendant global de la détection par notice qui existe déjà dans BookDraftForm
 * pendant le catalogage : `suggest_catalog_duplicates()` applique exactement
 * les mêmes règles (ISBN normalisé identique, ou titre ≥ 0,5 avec auteur
 * compatible ≥ 0,4, hors même œuvre et hors paires déjà écartées), mais sur
 * tout le catalogue d'un coup. Les deux vues ne peuvent donc pas se contredire.
 *
 * Deux natures de doublons, volontairement séparées à l'écran :
 *   • INTERNE — les deux notices ont les mêmes bibliothèques détentrices.
 *     C'est du ménage : la fusion est proposée.
 *   • INTER-BIBLIOTHÈQUES — la même œuvre cataloguée séparément par des
 *     bibliothèques différentes. Fusionner revient à MUTUALISER, ce qui engage
 *     une bibliothèque dont on n'est pas forcément membre : on liste et on
 *     signale, sans bouton destructeur. `fusion_possible` est calculé côté
 *     base, pour que l'interface ne puisse pas se tromper — et merge_book
 *     refuserait de toute façon (garde de rattachement, 20/08/2026).
 *
 * QUI FAIT QUOI (paquet DOUBLONS P4, 21/08/2026). Les gestes destructeurs —
 * fusionner, écarter, rétablir, classer sans suite — sont réservés à la
 * coordination. Le reste du staff garde les deux gestes qui ne détruisent
 * rien : « Même œuvre » et « Signaler à la coordination ». Le masquage ici
 * n'est qu'un confort : la garde opposable est en base (fn_is_dedup_arbiter).
 *
 * QUATRE ONGLETS :
 *   • À fusionner / À mutualiser — le balayage, comme avant.
 *   • Signalés — la file venue du poste de catalogage. Visible par tout le
 *     staff (une bibliothécaire doit pouvoir vérifier que son signalement est
 *     bien parti, sinon elle signalera de nouveau), mais actionnable par la
 *     seule coordination. On y trie ; la fusion, elle, se fait depuis le
 *     balayage, qui seul calcule `fusion_possible`.
 *   • Écartées — les paires « pas un doublon », avec leur motif et de quoi
 *     revenir dessus (paquet P3). Écarter retirait la paire de TOUTES les
 *     détections du réseau sans aucun retour arrière possible.
 *
 * Motif et note se saisissent EN LIGNE, dans la carte — surtout pas dans une
 * seconde modale : les panneaux du catalogage restent montés et ne sont masqués
 * qu'en CSS, une modale ouverte par-dessus devient invisible et bloque le
 * défilement de la page.
 *
 * L'appel de balayage coûte ~4 s sur 2 700 notices (index GIN trigrammes). On
 * charge donc TOUT une fois, puis on filtre en mémoire : un seul temps d'attente.
 */
// Libelle de la pastille selon le NIVEAU DE PREUVE renvoye par la RPC.
// L'ordre d'affichage vient du serveur (order by rang_preuve) : la similarite de
// titre seule est un mauvais signal — c'est la coincidence titre + annee +
// editeur qui distingue un vrai doublon de deux editions differentes.
const NIVEAU_CLE = {
  isbn:                'catalogacao.dedup.scanKindIsbn',
  titre_annee_editeur: 'catalogacao.dedup.scanKindTitleYearPublisher',
  titre_annee:         'catalogacao.dedup.scanKindTitleYear',
  titre_seul:          'catalogacao.dedup.scanKindApprox',
};

export default function CatalogDuplicatesModal({ isOpen, onClose, onChanged }) {
  const { formatMessage: t, formatDate } = useIntl();
  const { effectiveRole } = useLibrary();
  const arbitre = canArbitrateDuplicates(effectiveRole);

  const [loading, setLoading] = useState(false);
  const [rows, setRows] = useState([]);
  const [signales, setSignales] = useState([]);
  const [ecartees, setEcartees] = useState([]);
  const [err, setErr] = useState('');
  const [scope, setScope] = useState('interne');
  const [busyPair, setBusyPair] = useState(null);
  // Saisie en ligne : { key, texte, action } où action vaut 'ecarter' | 'signaler'
  const [saisie, setSaisie] = useState(null);

  // Trois sources : le balayage (lent), les signalements et les paires
  // ecartees (instantanes). On les lance ensemble, un seul temps d'attente.
  const load = useCallback(async () => {
    setLoading(true);
    setErr('');
    const [scan, reports, discarded] = await Promise.all([
      supabase.rpc('suggest_catalog_duplicates', { p_max: 500 }),
      supabase.rpc('list_duplicate_reports', { p_max: 200 }),
      supabase.rpc('list_books_not_duplicate', { p_max: 200 }),
    ]);
    const premiereErreur = scan.error || reports.error || discarded.error;
    if (premiereErreur) setErr(localizeError(premiereErreur, t));
    if (!scan.error) setRows(scan.data || []);
    if (!reports.error) setSignales(reports.data || []);
    if (!discarded.error) setEcartees(discarded.data || []);
    setLoading(false);
  }, [t]);

  // Rechargements cibles : inutile de repayer les 4 s du balayage.
  const loadLegers = useCallback(async () => {
    const [reports, discarded] = await Promise.all([
      supabase.rpc('list_duplicate_reports', { p_max: 200 }),
      supabase.rpc('list_books_not_duplicate', { p_max: 200 }),
    ]);
    if (!reports.error) setSignales(reports.data || []);
    if (!discarded.error) setEcartees(discarded.data || []);
  }, []);

  useEffect(() => { if (isOpen) load(); }, [isOpen, load]);

  const key = (r) => `${r.book_id_a}:${r.book_id_b}`;
  const shown = rows.filter((r) => (scope === 'interne' ? r.fusion_possible : !r.fusion_possible));
  const nbInterne = rows.filter((r) => r.fusion_possible).length;
  const nbCroise = rows.length - nbInterne;

  const retirer = (r) => setRows((prev) => prev.filter((x) => key(x) !== key(r)));

  async function agir(r, fn, { retirerDeLaListe = true } = {}) {
    setBusyPair(key(r));
    setErr('');
    const { error } = await fn();
    if (error) setErr(localizeError(error, t));
    else {
      if (retirerDeLaListe) retirer(r);
      onChanged?.();
      loadLegers();
    }
    setBusyPair(null);
  }

  // Saisie en ligne : le motif d'un ecart, ou la note d'un signalement. Le
  // motif rend la decision relisible — donc contestable — six mois plus tard,
  // quand personne ne se souvient du raisonnement.
  const ouvrirSaisie = (r, action) => setSaisie({ key: key(r), texte: '', action });

  async function validerSaisie(r) {
    const texte = (saisie?.key === key(r) ? saisie.texte : '').trim() || null;
    const action = saisie?.action;
    setSaisie(null);
    if (action === 'signaler') {
      await agir(r, () => supabase.rpc('report_duplicate_pair', {
        p_a: r.book_id_a, p_b: r.book_id_b, p_note: texte,
      }), { retirerDeLaListe: false });
    } else {
      await agir(r, () => supabase.rpc('mark_books_not_duplicate', {
        p_a: r.book_id_a, p_b: r.book_id_b, p_reason: texte,
      }));
    }
  }

  const memeOeuvre = (r) => agir(r, () =>
    supabase.rpc('group_books_as_editions', { p_book_ids: [r.book_id_a, r.book_id_b] }));

  function fusionner(r, canonicalId) {
    const garde = canonicalId === r.book_id_a ? r.titulo_a : r.titulo_b;
    const perdu = canonicalId === r.book_id_a ? r.titulo_b : r.titulo_a;
    const duplicateId = canonicalId === r.book_id_a ? r.book_id_b : r.book_id_a;
    if (!window.confirm(t({ id: 'catalogacao.dedup.confirm' }, { dup: perdu, canonical: garde }))) return;
    return agir(r, () =>
      supabase.rpc('merge_book', { p_canonical_id: canonicalId, p_duplicate_id: duplicateId }));
  }

  // ── Actions sur un signalement (coordination) ────────────────────────
  async function actionSignalement(s, fn) {
    const k = key(s);
    setBusyPair(k);
    setErr('');
    const { error } = await fn();
    if (error) setErr(localizeError(error, t));
    else {
      setSignales((prev) => prev.filter((x) => key(x) !== k));
      onChanged?.();
      loadLegers();
    }
    setBusyPair(null);
  }

  // « Même œuvre » ne clôt pas le signalement tout seul (group_books_as_editions
  // ignore la file) : on le clôt explicitement, sinon la coordination reverrait
  // une paire déjà tranchée.
  const signalementMemeOeuvre = (s) => actionSignalement(s, async () => {
    const grp = await supabase.rpc('group_books_as_editions', { p_book_ids: [s.book_id_a, s.book_id_b] });
    if (grp.error) return grp;
    return supabase.rpc('close_duplicate_report', { p_a: s.book_id_a, p_b: s.book_id_b });
  });

  // mark_books_not_duplicate clôt le signalement côté base : rien à ajouter ici.
  const signalementEcarter = (s) => actionSignalement(s, () =>
    supabase.rpc('mark_books_not_duplicate', { p_a: s.book_id_a, p_b: s.book_id_b, p_reason: null }));

  const signalementClasser = (s) => actionSignalement(s, () =>
    supabase.rpc('close_duplicate_report', { p_a: s.book_id_a, p_b: s.book_id_b }));

  // Retablir : la paire redevient detectable. Aucun document n'est modifie, donc
  // pas de confirmation destructive — c'est justement le geste de rattrapage.
  async function retablir(e) {
    const k = key(e);
    setBusyPair(k);
    setErr('');
    const { error } = await supabase.rpc('unmark_books_not_duplicate', {
      p_a: e.book_id_a, p_b: e.book_id_b,
    });
    if (error) setErr(localizeError(error, t));
    else {
      setEcartees((prev) => prev.filter((x) => key(x) !== k));
      onChanged?.();
      load(); // la paire doit reapparaitre dans le balayage
    }
    setBusyPair(null);
  }

  const cote = (r, p) => ({
    id: r[`book_id_${p}`],
    ref: r[`ref_${p}`],
    titulo: r[`titulo_${p}`],
    autor: r[`autor_${p}`],
    ano: r[`ano_${p}`],
    libs: r[`bibliotecas_${p}`],
    ex: r[`exemplares_${p}`],
  });

  const tabBtn = (id, label, n) => (
    <button
      type="button"
      onClick={() => { setScope(id); setSaisie(null); }}
      style={{
        padding: '8px 16px', fontSize: '.88rem', fontWeight: 600, background: 'none',
        border: 'none', cursor: 'pointer', marginBottom: -2,
        borderBottom: `2px solid ${scope === id ? 'var(--brand-color-primary, #7a0b14)' : 'transparent'}`,
        color: scope === id ? 'var(--brand-text, #f4f4f4)' : 'var(--brand-muted, #aaa)',
      }}
    >
      {label} ({n})
    </button>
  );

  // Les deux colonnes d'une paire, rendues pareil partout : une paire doit se
  // lire de la meme facon qu'elle vienne du balayage, de la file ou des ecarts.
  const renderCote = (c, extra = null) => (
    <div key={c.id} style={{ fontSize: '.86rem' }}>
      <div style={{ fontWeight: 600 }}>{c.titulo}</div>
      <div style={{ color: 'var(--brand-muted, #aaa)' }}>
        {c.autor}{c.ano ? ` · ${c.ano}` : ''}
      </div>
      <div style={{ color: 'var(--brand-muted, #888)', fontSize: '.8rem', marginTop: 2 }}>
        {c.ref}{c.libs != null ? ` · ${c.libs || '—'}` : ''}
        {c.ex != null ? ` · ${t({ id: 'catalogacao.dedup.copies' }, { count: c.ex })}` : ''}
      </div>
      <div style={{ marginTop: 6, display: 'flex', gap: 6, flexWrap: 'wrap' }}>
        <a className="ab-button ab-button--mini" href={`/livro/${c.id}`}>
          {t({ id: 'catalogacao.dedup.scanOpen' })}
        </a>
        {extra}
      </div>
    </div>
  );

  const carte = (k, busy, children) => (
    <div key={k} style={{
      border: '1px solid rgba(255,255,255,.12)', borderRadius: 10, padding: 12,
      opacity: busy ? 0.5 : 1,
    }}>{children}</div>
  );

  const HELP = {
    interne:  'catalogacao.dedup.scanHelpInternal',
    croise:   'catalogacao.dedup.scanHelpCross',
    signales: 'catalogacao.dedup.reportedHelp',
    ecartees: 'catalogacao.dedup.discardedHelp',
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} size="large" title={t({ id: 'catalogacao.dedup.title' })}>
      {loading && (
        <p style={{ color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.dedup.finding' })}</p>
      )}

      {err && (
        <div style={{
          padding: '10px 14px', borderRadius: 8, marginBottom: 12,
          background: 'rgba(220,38,38,.12)', color: '#f87171', fontSize: '.9rem',
        }}>{err}</div>
      )}

      {/* Les onglets s'affichent meme sans doublon actif : sinon « Signales » et
          « Ecartees » deviendraient inatteignables des que le catalogue est
          propre, et leur contenu invisible pour toujours. */}
      {!loading && (
        <>
          <div style={{ display: 'flex', borderBottom: '2px solid rgba(255,255,255,.08)', marginBottom: 14, flexWrap: 'wrap' }}>
            {tabBtn('interne', t({ id: 'catalogacao.dedup.scanTabInternal' }), nbInterne)}
            {tabBtn('croise', t({ id: 'catalogacao.dedup.scanTabCross' }), nbCroise)}
            {tabBtn('signales', t({ id: 'catalogacao.dedup.scanTabReported' }), signales.length)}
            {tabBtn('ecartees', t({ id: 'catalogacao.dedup.scanTabDiscarded' }), ecartees.length)}
          </div>

          <p style={{ fontSize: '.84rem', color: 'var(--brand-muted, #999)', marginTop: 0, marginBottom: 6 }}>
            {t({ id: HELP[scope] })}
          </p>

          {/* Dire pourquoi les boutons destructeurs manquent vaut mieux que de
              laisser croire a une panne. */}
          {!arbitre && (
            <p style={{ fontSize: '.8rem', color: 'var(--brand-muted, #888)', marginTop: 0, marginBottom: 14 }}>
              {t({ id: 'catalogacao.dedup.arbiterOnly' })}
            </p>
          )}

          {scope === 'interne' || scope === 'croise' ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {shown.length === 0 && <p>{t({ id: 'catalogacao.dedup.none' })}</p>}
              {shown.map((r) => {
                const busy = busyPair === key(r);
                const enSaisie = saisie?.key === key(r);
                return carte(key(r), busy, (
                  <>
                    <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 8, flexWrap: 'wrap' }}>
                      <span className={`ab-pill ${(r.rang_preuve ?? 4) <= 2 ? 'ab-pill--warn' : ''}`}>
                        {t({ id: NIVEAU_CLE[r.niveau_preuve] || 'catalogacao.dedup.scanKindApprox' })}
                      </span>
                      <span style={{ fontSize: '.8rem', color: 'var(--brand-muted, #999)' }}>
                        {Math.round((r.score || 0) * 100)}%
                      </span>
                    </div>

                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: 10 }}>
                      {[cote(r, 'a'), cote(r, 'b')].map((c) => renderCote(c,
                        arbitre && r.fusion_possible ? (
                          <button type="button" className="ab-button ab-button--mini" disabled={busy}
                            onClick={() => fusionner(r, c.id)}>
                            {t({ id: 'catalogacao.dedup.merge' })}
                          </button>
                        ) : null
                      ))}
                    </div>

                    {!enSaisie && (
                      <div style={{ marginTop: 10, display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                        <button type="button" className="ab-button ab-button--mini ab-button--secondary"
                          disabled={busy} onClick={() => memeOeuvre(r)}
                          title={t({ id: 'catalogacao.dedup.sameWorkHint' })}>
                          {t({ id: 'catalogacao.dedup.sameWork' })}
                        </button>
                        {arbitre ? (
                          <button type="button" className="ab-button ab-button--mini ab-button--secondary"
                            disabled={busy} onClick={() => ouvrirSaisie(r, 'ecarter')}
                            title={t({ id: 'catalogacao.dedup.notDuplicateHint' })}>
                            {t({ id: 'catalogacao.dedup.notDuplicate' })}
                          </button>
                        ) : (
                          <button type="button" className="ab-button ab-button--mini ab-button--secondary"
                            disabled={busy} onClick={() => ouvrirSaisie(r, 'signaler')}
                            title={t({ id: 'catalogacao.dedup.reportHint' })}>
                            {t({ id: 'catalogacao.dedup.report' })}
                          </button>
                        )}
                      </div>
                    )}

                    {enSaisie && (
                      <div style={{ marginTop: 10, display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center' }}>
                        <input
                          type="text"
                          autoFocus
                          value={saisie.texte}
                          onChange={(ev) => setSaisie({ ...saisie, texte: ev.target.value })}
                          onKeyDown={(ev) => {
                            if (ev.key === 'Enter') { ev.preventDefault(); validerSaisie(r); }
                            if (ev.key === 'Escape') setSaisie(null);
                          }}
                          placeholder={t({ id: saisie.action === 'signaler'
                            ? 'catalogacao.dedup.reportPlaceholder'
                            : 'catalogacao.dedup.reasonPlaceholder' })}
                          style={{
                            flex: '1 1 220px', minWidth: 0, padding: '7px 10px', borderRadius: 8,
                            border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)',
                            color: '#f4f4f4', fontSize: '.85rem',
                          }}
                        />
                        <button type="button" className="ab-button ab-button--mini"
                          disabled={busy} onClick={() => validerSaisie(r)}>
                          {t({ id: saisie.action === 'signaler'
                            ? 'catalogacao.dedup.reportConfirm'
                            : 'catalogacao.dedup.reasonConfirm' })}
                        </button>
                        <button type="button" className="ab-button ab-button--mini ab-button--secondary"
                          disabled={busy} onClick={() => setSaisie(null)}>
                          {t({ id: 'common.cancel' })}
                        </button>
                      </div>
                    )}
                  </>
                ));
              })}
            </div>
          ) : null}

          {/* ── Signalements venus du poste de catalogage ─────────────── */}
          {scope === 'signales' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {signales.length === 0 && <p>{t({ id: 'catalogacao.dedup.reportedNone' })}</p>}
              {signales.map((s) => {
                const busy = busyPair === key(s);
                return carte(key(s), busy, (
                  <>
                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: 10 }}>
                      {[cote(s, 'a'), cote(s, 'b')].map((c) => renderCote(c))}
                    </div>

                    <div style={{ marginTop: 10, fontSize: '.8rem', color: 'var(--brand-muted, #888)' }}>
                      {t({ id: 'catalogacao.dedup.reportedBy' }, {
                        who: s.reported_by_name || t({ id: 'catalogacao.dedup.discardedByUnknown' }),
                        when: s.created_at ? formatDate(s.created_at, { dateStyle: 'medium' }) : '—',
                      })}
                      {s.note ? ` — « ${s.note} »` : ''}
                    </div>

                    {arbitre && (
                      <div style={{ marginTop: 10, display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                        <button type="button" className="ab-button ab-button--mini ab-button--secondary"
                          disabled={busy} onClick={() => signalementMemeOeuvre(s)}
                          title={t({ id: 'catalogacao.dedup.sameWorkHint' })}>
                          {t({ id: 'catalogacao.dedup.sameWork' })}
                        </button>
                        <button type="button" className="ab-button ab-button--mini ab-button--secondary"
                          disabled={busy} onClick={() => signalementEcarter(s)}
                          title={t({ id: 'catalogacao.dedup.notDuplicateHint' })}>
                          {t({ id: 'catalogacao.dedup.notDuplicate' })}
                        </button>
                        <button type="button" className="ab-button ab-button--mini ab-button--secondary"
                          disabled={busy} onClick={() => signalementClasser(s)}
                          title={t({ id: 'catalogacao.dedup.dismissHint' })}>
                          {busy ? '…' : t({ id: 'catalogacao.dedup.dismiss' })}
                        </button>
                      </div>
                    )}
                  </>
                ));
              })}
            </div>
          )}

          {/* ── Paires ecartees (rattrapage) ──────────────────────────── */}
          {scope === 'ecartees' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {ecartees.length === 0 && <p>{t({ id: 'catalogacao.dedup.discardedNone' })}</p>}
              {ecartees.map((e) => {
                const busy = busyPair === key(e);
                return carte(key(e), busy, (
                  <>
                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: 10 }}>
                      {[cote(e, 'a'), cote(e, 'b')].map((c) => renderCote(c))}
                    </div>

                    <div style={{ marginTop: 10, fontSize: '.8rem', color: 'var(--brand-muted, #888)' }}>
                      {t({ id: 'catalogacao.dedup.discardedBy' }, {
                        who: e.created_by_name || t({ id: 'catalogacao.dedup.discardedByUnknown' }),
                        when: e.created_at ? formatDate(e.created_at, { dateStyle: 'medium' }) : '—',
                      })}
                      {e.reason ? ` — « ${e.reason} »` : ''}
                    </div>

                    {arbitre && (
                      <div style={{ marginTop: 10 }}>
                        <button type="button" className="ab-button ab-button--mini ab-button--secondary"
                          disabled={busy} onClick={() => retablir(e)}
                          title={t({ id: 'catalogacao.dedup.restoreHint' })}>
                          {busy ? '…' : t({ id: 'catalogacao.dedup.restore' })}
                        </button>
                      </div>
                    )}
                  </>
                ));
              })}
            </div>
          )}
        </>
      )}
    </Modal>
  );
}
