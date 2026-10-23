// Bloc « Œuvre » de la notice publiée (palier avancé/complet) : rattacher,
// détacher, suggestions d'éditions, fusion d'une même édition (DEDUP-9).
// Sorti de BookDraftForm.jsx tel quel (E6, 23/10/2026), avec l'état et les
// actions qu'il est seul à lire (calculés par @babel/traverse).
// Garde : src/tests/notice-sections-montees.test.jsx.
import { useIntl } from 'react-intl';
import { useState } from 'react';
import { supabase } from '@/lib/supabase';
import WorkToolsBlock from './WorkToolsBlock';
import { ApercuFusion } from './DedupAssistantPanel';
import { localizeError } from '@/lib/localizeError';

export default function BookWorkPanel(p) {
  const { formatMessage: t } = useIntl();
  const {
    arbitreDoublons, bookDupBusy, catalogTier, confirmSaved, confirmer, draftState, editionSugg, f,
    fillFromRecord, findBookDuplicates, fusionEdition, groupAsEditions, setEditionSugg,
    setFusionEdition, setMsg, setWorkNonce, work,
  } = p;

  const [workBusy, setWorkBusy] = useState(false);

  const [editionSuggLoading, setEditionSuggLoading] = useState(false);

  const [fusionBusy, setFusionBusy] = useState(false);

  const [champsInterdits, setChampsInterdits] = useState([]); // demandés à la base, une fois

  // P4 : œuvre — créer depuis la notice, détacher, regrouper des éditions.
  async function createWork() {
    const bid = f('published_book_id'); if (!bid) return;
    setWorkBusy(true);
    try {
      const { error } = await supabase.rpc('create_work_from_book', { p_book_id: Number(bid) });
      if (error) throw error;
      setMsg({ text: t({ id: 'catalogacao.work.created' }), kind: 'ok' });
      setWorkNonce(n => n + 1);
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setWorkBusy(false); }
  }

  async function detachWork() {
    const bid = f('published_book_id'); if (!bid) return;
    // 17/10/2026 : « Détacher » sort l'édition de son groupe — elle reçoit une œuvre à elle. Il
    // demande confirmation : trois notices s'étaient retrouvées sans œuvre (dont un double-clic,
    // le bouton prenant la place de « Créer l'œuvre »).
    if (!(await confirmer({ message: t({ id: 'catalogacao.work.detachConfirm' }, { title: work?.uniform_title || '' }), confirmLabel: t({ id: 'catalogacao.work.detach' }), tone: 'danger' }))) return;
    setWorkBusy(true);
    try {
      const { error } = await supabase.rpc('detach_book_from_work', { p_book_id: Number(bid) });
      if (error) throw error;
      setMsg({ text: t({ id: 'catalogacao.work.detached' }), kind: 'ok' });
      setWorkNonce(n => n + 1);
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setWorkBusy(false); }
  }

  // P4 v2 : suggérer des éditions à regrouper (même auteur·rice + titre proche).
  async function findEditionSuggestions() {
    const bid = f('published_book_id'); if (!bid) return;
    setEditionSuggLoading(true);
    try {
      const { data, error } = await supabase.rpc('suggest_editions_for_book', { p_book_id: Number(bid) });
      if (error) throw error;
      setEditionSugg(data || []);
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setEditionSuggLoading(false); }
  }

  // Même édition (28/09/2026) : ouvrir l'aperçu de fusion pour une édition suggérée.
  // La notice éditée survit ; l'autre disparaît. Mêmes gardes que le bouton des
  // doublons : coordination seule (opposable en base), brouillon enregistré d'abord.
  async function ouvrirFusionEdition(s) {
    const canonicalId = f('published_book_id');
    if (!canonicalId || !arbitreDoublons) return;
    if (draftState === 'dirty') {
      setMsg({ text: t({ id: 'catalogacao.dedup.saveBeforeMerge' }), kind: 'error' });
      return;
    }
    setFusionBusy(true);
    try {
      let interdits = champsInterdits;
      if (!interdits.length) {
        const { data } = await supabase.rpc('fn_dedup_non_transferable_fields');
        if (Array.isArray(data)) { interdits = data; setChampsInterdits(data); }
      }
      const { data: apercu, error } = await supabase.rpc('preview_merge_book', {
        p_canonical_id: Number(canonicalId), p_duplicate_id: Number(s.book_id),
      });
      if (error) throw error;
      // Cochées par défaut : les pertes sèches, et elles seules (comme l'assistant).
      const reprises = (apercu?.metadonnees_perdues || []).map((m) => m.champ).filter((c) => !interdits.includes(c));
      setFusionEdition({ bookId: Number(s.book_id), titulo: s.titulo, apercu, saisie: '', reprises });
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setFusionBusy(false); }
  }

  async function fusionnerEdition() {
    const canonicalId = f('published_book_id');
    if (!canonicalId || !fusionEdition) return;
    setFusionBusy(true);
    try {
      const { error } = await supabase.rpc('merge_book_with_fields', {
        p_canonical_id: Number(canonicalId), p_duplicate_id: fusionEdition.bookId,
        p_fields: fusionEdition.reprises || [],
      });
      if (error) throw error;
      const titre = fusionEdition.titulo;
      setFusionEdition(null);
      if (f('id')) {
        const { data: rechargé } = await supabase.from('book_drafts').select('*').eq('id', Number(f('id'))).single();
        if (rechargé) fillFromRecord(rechargé);   // efface le message : le nôtre vient après
      }
      setMsg({ text: t({ id: 'catalogacao.dedup.mergedBook' }, { dup: titre }), kind: 'ok' });
      setWorkNonce(n => n + 1);
      await findEditionSuggestions();
      await findBookDuplicates();
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setFusionBusy(false); }
  }

  return (
    <>{catalogTier >= 2 && f('published_book_id') && (
            <div className="ab-span3" style={{ gridColumn: 'span 3', marginBottom: 6 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
                <span style={{ fontWeight: 600, fontSize: '.88rem' }}>{t({ id: 'catalogacao.work.title' })}</span>
                {work ? (
                  <>
                    <span style={{ fontSize: '.82rem' }}>{work.uniform_title} · {t({ id: 'catalogacao.work.editions' }, { count: work.count })}</span>
                    {/* Seule édition de son œuvre : rien à détacher (17/10/2026). */}
                    {work.count > 1 && (
                      <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={detachWork} disabled={workBusy}>
                        {t({ id: 'catalogacao.work.detach' })}
                      </button>
                    )}
                  </>
                ) : (
                  <>
                    <span style={{ fontSize: '.8rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.work.none' })}</span>
                    <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={createWork} disabled={workBusy}>
                      {t({ id: 'catalogacao.work.create' })}
                    </button>
                  </>
                )}
                <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                  onClick={findEditionSuggestions} disabled={editionSuggLoading || workBusy}>
                  {editionSuggLoading ? t({ id: 'catalogacao.dedup.finding' }) : t({ id: 'catalogacao.work.suggest' })}
                </button>
              </div>
              {/* OPAC par œuvre (04/09/2026) : rattacher à une autre œuvre (lot 1b),
                  titres par langue (lot 3). */}
              <WorkToolsBlock
                bookId={Number(f('published_book_id'))}
                workId={work?.id || null}
                onChanged={() => setWorkNonce(n => n + 1)}
                onMsg={(text, kind) => (kind === 'ok' ? confirmSaved(text) : setMsg({ text, kind }))}
              />
              {editionSugg !== null && editionSugg.length === 0 && (
                <div style={{ fontSize: '.8rem', color: 'var(--brand-muted, #aaa)', marginTop: 6 }}>{t({ id: 'catalogacao.work.noSuggestions' })}</div>
              )}
              {editionSugg !== null && editionSugg.length > 0 && (
                <div style={{ marginTop: 6, border: '1px solid rgba(255,255,255,.08)', borderRadius: 8, overflow: 'hidden' }}>
                  {editionSugg.map(s => (
                    <div key={s.book_id} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 10px', borderBottom: '1px solid rgba(255,255,255,.04)' }}>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ fontSize: '.82rem' }}>{s.titulo}{s.ano ? ` (${s.ano})` : ''}</div>
                        <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #aaa)' }}>{[s.editora, s.work_id ? t({ id: 'catalogacao.work.alreadyInWork' }) : null].filter(Boolean).join(' · ')}</div>
                      </div>
                      <span style={{ fontSize: '.6rem', color: 'var(--brand-muted, #aaa)' }}>{Math.round((Number(s.score) || 0) * 100)}%</span>
                      <button type="button" className="ab-button ab-button--sm" disabled={bookDupBusy != null || fusionBusy}
                        onClick={async () => { await groupAsEditions(s.book_id); findEditionSuggestions(); }}>
                        {bookDupBusy === s.book_id ? '…' : t({ id: 'catalogacao.work.group' })}
                      </button>
                      {arbitreDoublons && (
                        <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                          disabled={bookDupBusy != null || fusionBusy}
                          title={t({ id: 'catalogacao.work.sameEditionHint' })}
                          onClick={() => ouvrirFusionEdition(s)}>
                          {t({ id: 'catalogacao.work.sameEditionMerge' })}
                        </button>
                      )}
                    </div>
                  ))}
                </div>
              )}
              {/* L'aperçu de l'assistant (temps 3), en ligne — jamais de modale (DEDUP-9). */}
              {fusionEdition && (
                <div style={{ marginTop: 8, border: '1px solid rgba(220,38,38,.35)', borderRadius: 8, padding: 10 }}>
                  <div style={{ fontSize: '.8rem', color: 'var(--brand-muted, #bbb)', marginBottom: 8 }}>
                    {t({ id: 'catalogacao.work.sameEditionHint' })}
                  </div>
                  <ApercuFusion
                    ex={{ ...fusionEdition, survivant: Number(f('published_book_id')) }}
                    r={{
                      book_id_a: Number(f('published_book_id')), book_id_b: fusionEdition.bookId,
                      ref_a: f('bib_ref'), ref_b: fusionEdition.apercu?.doublon?.ref || '',
                      titulo_a: f('titulo'), titulo_b: fusionEdition.titulo,
                    }}
                    busy={fusionBusy} t={t} interdits={champsInterdits} survivantFixe
                    onSurvivant={() => {}}
                    onRetour={() => setFusionEdition(null)}
                    onSaisie={(v) => setFusionEdition((p) => (p ? { ...p, saisie: v } : p))}
                    onReprise={(champ) => setFusionEdition((p) => {
                      if (!p) return p;
                      const reprises = p.reprises.includes(champ) ? p.reprises.filter((c) => c !== champ) : [...p.reprises, champ];
                      return { ...p, reprises };
                    })}
                    onFusion={fusionnerEdition}
                  />
                </div>
              )}
            </div>
          )}</>
  );
}
