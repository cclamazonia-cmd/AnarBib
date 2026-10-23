// Aides de la page Importations — constantes, fonctions pures et le détail
// d'une comparaison (DetailComparaison) — sorties d'ImportacoesPage.jsx telles
// quelles (E6, 23/10/2026), pour être partagées par la page et ses sections.
import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useIntl } from 'react-intl';
import { partiesExemplaires, CHAMPS_EXEMPLAIRE } from '../../lib/importItemUpdates.js';
import { REGISTRY } from '../catalogacao/fieldRegistry.js';

export const BUCKET = 'catalogos_parceiros_raw';
// Champs cibles d'un profil d'import (mapping colonne→champ + valeurs par défaut).
// Clés techniques alignées sur le parseur (process-partner-catalog-import).
export const PROFILE_FIELDS = ['title', 'subtitle', 'author', 'publisher', 'place', 'year', 'language', 'subjects', 'isbn', 'issn', 'edition', 'itemType', 'externalKey'];
// H19 : clés de la correspondance des exemplaires, et la convention de PMB 8.1
// (UNIMARC 995) montrée en exemple — même défaut que DEFAULT_ITEM_MAPPINGS (marc.ts).
export const PROFILE_ITEM_KEYS = ['tag', 'code', 'call_number', 'note', 'owner', 'item_type', 'public', 'status'];
// Grisés : la convention appliquée à une case VIDE, UNIMARC (PMB 8.1, 995) · MARC21 (852) —
// marc.ts DEFAULT_ITEM_MAPPINGS. Une case remplie vaut pour les deux dialectes.
export const PROFILE_ITEM_HINTS = { tag: '995 · 852', code: 'f · p', call_number: 'k · hi', note: 'u · z', owner: 'a · b', item_type: 'r · —', public: 'q · —', status: '— · —' };

export function formatDate(iso) {
  if (!iso) return '—';
  const d = new Date(iso);
  return d.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' })
    + ' ' + d.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
}

// Provenances qui ne sont PAS des bibliotheques companheiras : elles ont
// leur propre encart et n'ont accorde aucune relation. Les afficher parmi
// les « Fontes companheiras » leur collerait un badge de relation invente.
//   institutional_lookup : source creee par fn_import_ingest_candidate
//   oai_pmh              : entrepot moissonne, encart « oai » dedie
//   own_catalog          : le catalogue PROPRE de la biblio (fn_import_own_source)
export const NON_COMPANHEIRA_KINDS = ['institutional_lookup', 'oai_pmh', 'own_catalog'];

// H21 lot 0 (REGISTRE IMP-26 h et IMP-27, 29/09/2026) : une ligne se coche tant
// qu'elle n'a ni brouillon de notice ni brouillon d'exemplaire, et que sa
// décision lui laisse un geste :
//  * en attente (nulle ou 'pending') : nouveautés ET doublons ;
//  * « Accepté (nouveau) » sur une nouveauté : « Promouvoir la sélection » ne
//    promeut plus que la sélection (p_row_ids). Une ligne restée acceptée sans
//    brouillon (promotion échouée après la décision, deux appels) n'aurait
//    plus aucun chemin à l'écran ;
//  * « Accepté (rattaché) » : elle ne devient plus jamais une notice (IMP-26 h) ;
//    il lui reste « Rapprocher » ou « Rejeter ».
// Un seul prédicat, pour la case « tout cocher » (selectableIds) et pour la
// case de chaque ligne (reviewable).
// H21 lot 1 (REGISTRE IMP-28, 05/10/2026) : une ligne « Déjà importée »
// (known_record) se coche tant qu'elle n'est pas décidée (en attente) ou
// qu'elle est rattachée sans exemplaire ; jamais en « Accepté (nouveau) » :
// elle ne devient jamais une notice neuve (seulement « Rapprocher » ou
// « Rejeter »). La règle accept_new ne vaut que pour new_record.
// H21 lot 4 (décision de Xavier du 06/10, IMP-31 d) : « Préparer la mise à
// jour » et « Rapprocher » sont deux gestes indépendants. Une ligne « Déjà
// importée » qui a une mise à jour à préparer (même règle qu'estPreparable,
// écrite ici en entier : ce prédicat se lit seul) reste cochable même
// rapprochée, ou marquée rejetée par « Rapprocher » parce que tous ses
// exemplaires étaient déjà là (H19) — la base rend update_applicable = 0 pour
// une ligne rejetée par choix ou écartée.
// H21 lot 6b (IMP-33 c) : de même une ligne dont un exemplaire « déjà là » a une
// cote ou une note à mettre à jour (exemplaires_maj.applicables, compté par la
// base : 0 pour une ligne rejetée par choix).
export function estSelectionnable(r) {
  if (!r || r.created_book_draft_id) return false;
  if (r.match_status === 'known_record' && r.proposed_book_id && r.proposed_book_held !== false
      && Number(r.update_applicable || 0) > 0 && !r.update_draft_id) return true;
  if (r.match_status === 'known_record' && r.proposed_book_id && Number(r.exemplaires_maj?.applicables || 0) > 0) return true;
  if (r.created_exemplar_draft_id) return false;
  const ed = r.editorial_decision;
  return ed == null || ed === 'pending'
    || (ed === 'accept_new' && r.match_status === 'new_record')
    || ed === 'accept_duplicate';
}

// H21 lot 3 (05/10/2026) : la comparaison à trois états d'une ligne « Déjà
// importée » (base de l'import précédent, notice AnarBib, nouveau fichier),
// résumée pour la colonne Correspondance depuis
// fn_import_list_run_rows.comparison_counts (comptes par verdict). Les
// changements que le fichier apporte : « source seule » (le fichier seul a
// changé) et « conflit » (les deux, différemment) ; à revoir : « sans base ».
// Ce qu'AnarBib seule a changé, ou ce qui est déjà pareil, n'est pas un
// changement du fichier. null sans comptes (ligne d'avant le lot 3, pas encore
// comparée) : rien n'est dit.
export function resumeComparaison(r) {
  const c = r && r.comparison_counts;
  if (!c || typeof c !== 'object') return null;
  const n = (k) => Number(c[k] || 0);
  return { changements: n('source_seule') + n('conflit'), conflits: n('conflit'), aRevoir: n('sans_base') };
}

// H21 lot 3 (06/10/2026) : la comparaison n'est plus calculée au rapprochement
// (délai de 8 s des edge functions) ; l'écran la demande, par pages de 200
// (fn_import_recomparer), pour les lignes « Déjà importées » dont les comptes
// manquent : jamais calculée, effacée par un nouveau rapprochement, ou faite
// contre une autre notice (fusion : la liste rend alors NULL). Une ligne d'un
// serveur d'avant le lot 3 n'a pas la clé comparison_counts : rien à demander.
// H21 lot 6b : de même la comparaison des exemplaires (exemplaires_maj NULL).
export const PAGE_COMPARAISON = 200;
export function lignesAComparer(r) {
  return (Array.isArray(r) ? r : [])
    .filter(x => x && x.match_status === 'known_record' && x.proposed_book_id
      && ((Object.prototype.hasOwnProperty.call(x, 'comparison_counts') && x.comparison_counts === null)
          || (Object.prototype.hasOwnProperty.call(x, 'exemplaires_maj') && x.exemplaires_maj === null)))
    .map(x => x.id);
}

// H21 lot 4 (06/10/2026, REGISTRE IMP-31) : « Préparer la mise à jour » —
// une ligne « Déjà importée » dont la comparaison valide a au moins un champ
// changé dans le fichier seulement, hors responsabilités (update_applicable,
// compté par la base), encore détenue par ta bibliothèque, sans brouillon de
// mise à jour. La base juge seule ce que l'écran ne voit pas (notice partagée
// avec une bibliothèque hors de ta vue, comparaison recalculée) et dit les
// lignes ignorées, par raison.
// H21 lot 6b (IMP-33 c) : le même geste prépare aussi les exemplaires « déjà
// là » dont la cote ou la note n'a changé que dans le fichier — indépendamment
// de la notice (partagée, ou sans rien à appliquer) : la ligne est préparable
// si sa notice l'est OU si un de ses exemplaires l'est.
export function estPreparable(r) {
  if (!r || r.match_status !== 'known_record' || !r.proposed_book_id) return false;
  const notice = r.proposed_book_held !== false && Number(r.update_applicable || 0) > 0 && !r.update_draft_id;
  return notice || Number(r.exemplaires_maj?.applicables || 0) > 0;
}
// L'ordre du message : ce qui demande une action d'abord.
export const RAISONS_IGNOREES = ['partagee', 'plus_detenue', 'sans_base', 'rien_a_appliquer', 'deja_preparee', 'rejetee',
  'pas_reconnue', 'hors_run', 'non_comparee'];

// Le détail d'une ligne « Déjà importée », champ par champ (base de l'import
// précédent / AnarBib / fichier / verdict), lu à l'ouverture par
// fn_import_row_comparison (calculé à la lecture). Les champs inchangés sont
// comptés, pas listés ; valeurs AnarBib masquées d'une notice hors de ta vue.
export const LIBELLE_CHAMP = {
  ...Object.fromEntries(REGISTRY.flatMap(g => (Array.isArray(g.fields) ? g.fields : []).map(f => [f.id, f.label]))),
  contributors: 'catalogacao.ui.contributors',
};
export function valeurDuChamp(v) {
  if (v == null || (Array.isArray(v) && v.length === 0)) return '∅';
  if (Array.isArray(v)) return v.map(x => (Array.isArray(x) ? `${x[0] ?? '?'}${x[1] ? ` (${x[1]})` : ''}` : String(x))).join(' ; ');
  const s = String(v);
  return s.length > 160 ? `${s.slice(0, 157)}…` : s;
}
// H21 lot 6b : les exemplaires (préparés, ignorés par raison) à la suite des
// notices ; « Aucune mise à jour préparée » seulement si rien du tout ne l'est.
export function messagePreparation(t, prepares, lot, ignorees, ex = { prepares: 0, ignorees: {} }) {
  const exPrepares = Number(ex?.prepares || 0);
  const parties = [];
  if (prepares > 0) parties.push(t({ id: 'importacoes.fila.prepared' }, { n: prepares, batch: lot ?? '—' }));
  else if (exPrepares === 0) parties.push(t({ id: 'importacoes.fila.preparedNone' }));
  const exemplaires = partiesExemplaires(t, exPrepares, lot, ex?.ignorees || {});
  if (exemplaires.parties.length && exPrepares > 0) parties.push(exemplaires.parties.shift());
  const liste = RAISONS_IGNOREES.filter(k => Number(ignorees[k] || 0) > 0)
    .map(k => t({ id: `importacoes.fila.prepareSkip.${k}` }, { n: Number(ignorees[k]) }));
  if (liste.length) parties.push(t({ id: 'importacoes.fila.prepareSkipped' }, { list: liste.join(', ') }));
  parties.push(...exemplaires.parties);
  const total = prepares + exPrepares;
  return { text: parties.join(' '), kind: total > 0 ? (liste.length || exemplaires.ignorees ? 'info' : 'ok') : 'error' };
}
export function DetailComparaison({ runId, rowId }) {
  const { formatMessage: t } = useIntl();
  const [etat, setEtat] = useState({ charge: true, data: null, erreur: null });
  useEffect(() => {
    let actif = true;
    supabase.rpc('fn_import_row_comparison', { p_run_id: Number(runId), p_row_id: Number(rowId) })
      .then(({ data, error }) => { if (actif) setEtat({ charge: false, data: error ? null : data, erreur: error || null }); })
      .catch((e) => { if (actif) setEtat({ charge: false, data: null, erreur: e }); });
    return () => { actif = false; };
  }, [runId, rowId]);
  if (etat.charge) return <div className="imp-note" style={{ fontSize: '.72rem' }}>{t({ id: 'importacoes.fila.detail.loading' })}</div>;
  if (etat.erreur || !etat.data) {
    return <div className="imp-note" style={{ fontSize: '.72rem' }}>{etat.erreur ? localizeError(etat.erreur, t) : t({ id: 'importacoes.fila.comparison.notComputed' })}</div>;
  }
  const champs = Array.isArray(etat.data.champs) ? etat.data.champs.filter(Boolean) : [];
  const ecarts = champs.filter(c => c.verdict !== 'inchange');
  const masque = !!etat.data.a_masque;
  const libelle = (champ) => (LIBELLE_CHAMP[champ] ? t({ id: LIBELLE_CHAMP[champ] }) : champ);
  // H21 lot 6b (IMP-33 c) : les exemplaires « déjà là », cote et note à trois
  // états (base / AnarBib / fichier / verdict) ; valeurs AnarBib masquées d'un
  // exemplaire hors de ta vue.
  const exemplaires = Array.isArray(etat.data.exemplaires?.items)
    ? etat.data.exemplaires.items.filter(x => x && Array.isArray(x.champs)) : [];
  const libelleExemplaire = (champ) => (CHAMPS_EXEMPLAIRE.includes(champ) ? t({ id: `importacoes.items.field.${champ}` }) : champ);
  return (
    <div data-testid="known-detail" className="imp-known-detail" style={{ marginTop: 4, fontSize: '.72rem' }}>
      {masque && <div className="imp-note" data-testid="known-detail-masked">{t({ id: 'importacoes.fila.detail.masked' })}</div>}
      {ecarts.length === 0
        ? <div className="imp-note">{t({ id: 'importacoes.fila.comparison.none' })}</div>
        : (
          <ul style={{ margin: '2px 0 0 16px', padding: 0, lineHeight: 1.45 }}>
            {ecarts.map(c => (
              <li key={c.champ} data-champ={c.champ} data-verdict={c.verdict}>
                <strong>{libelle(c.champ)}</strong>{' — '}{t({ id: `review.report.updates.verdict.${c.verdict}` })}
                {/* IMP-31 c : un champ que le fichier vide est montré, jamais appliqué */}
                {c.verdict === 'source_seule' && c.champ !== 'contributors' && c.n == null
                  ? <span data-testid="known-detail-erased"> · {t({ id: 'review.report.prepared.erased' })}</span> : null}
                <div style={{ color: 'var(--brand-muted, #94a3b8)' }}>
                  {t({ id: 'review.report.updates.values' }, {
                    b: valeurDuChamp(c.b),
                    a: masque ? t({ id: 'review.report.updates.masked' }) : valeurDuChamp(c.a),
                    n: valeurDuChamp(c.n),
                  })}
                </div>
              </li>
            ))}
          </ul>
        )}
      {champs.length - ecarts.length > 0 && (
        <div className="imp-note">{t({ id: 'importacoes.fila.detail.unchanged' }, { n: champs.length - ecarts.length })}</div>
      )}
      {exemplaires.length > 0 && (
        <div data-testid="known-detail-items" style={{ marginTop: 4 }}>
          <div className="imp-note"><strong>{t({ id: 'importacoes.fila.detail.items' })}</strong></div>
          <ul style={{ margin: '2px 0 0 16px', padding: 0, lineHeight: 1.45 }}>
            {exemplaires.map(x => {
              const bougent = x.champs.filter(c => c && c.verdict !== 'inchange');
              return (
                <li key={x.n} data-item-n={x.n} data-exemplar={x.exemplar_id ?? ''}>
                  <span style={{ fontFamily: 'monospace', overflowWrap: 'anywhere' }}>{x.code || '—'}</span>
                  {x.tombo ? <> · {t({ id: 'importacoes.items.exemplar' }, { tombo: x.tombo })}</> : null}
                  {x.a_masque && (
                    <div className="imp-note" data-testid="known-detail-item-masked">{t({ id: 'importacoes.fila.detail.itemsMasked' })}</div>
                  )}
                  {bougent.length === 0
                    ? <div className="imp-note">{t({ id: 'importacoes.fila.detail.itemUnchanged' })}</div>
                    : (
                      <ul style={{ margin: '2px 0 0 16px', padding: 0 }}>
                        {bougent.map(c => (
                          <li key={c.champ} data-champ={c.champ} data-verdict={c.verdict}>
                            {/* hors de vue (revue sceptique du 08/10) : ni verdict fin, ni base, ni AnarBib — le fichier seul */}
                            <strong>{libelleExemplaire(c.champ)}</strong>{' — '}{c.verdict === 'masque'
                              ? t({ id: 'importacoes.fila.detail.itemFieldMasked' })
                              : t({ id: `review.report.updates.verdict.${c.verdict}` })}
                            {/* comme IMP-31 c : un champ que le fichier vide est montré, jamais vidé */}
                            {c.verdict === 'source_seule' && c.n == null
                              ? <span data-testid="known-detail-item-erased"> · {t({ id: 'review.report.prepared.erased' })}</span> : null}
                            <div style={{ color: 'var(--brand-muted, #94a3b8)' }}>
                              {c.verdict === 'masque'
                                ? t({ id: 'importacoes.fila.detail.itemFieldFile' }, { n: valeurDuChamp(c.n) })
                                : t({ id: 'review.report.updates.values' }, {
                                  b: valeurDuChamp(c.b),
                                  a: x.a_masque ? t({ id: 'review.report.updates.masked' }) : valeurDuChamp(c.a),
                                  n: valeurDuChamp(c.n),
                                })}
                            </div>
                          </li>
                        ))}
                      </ul>
                    )}
                </li>
              );
            })}
          </ul>
        </div>
      )}
    </div>
  );
}
