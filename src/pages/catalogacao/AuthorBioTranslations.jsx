// Traductions de la biographie d'une autorité publiée (une par langue servie) — sorti d'AuthorDraftForm.jsx tel quel (E6, 23/10/2026). Les traductions
// elles-mêmes restent à l'état du formulaire (il les charge avec la fiche et les
// relit pour la note de bas de page) ; le panneau garde la bascule de revue et
// l'enregistrement, et remonte ses messages par onMessage.
// Garde : src/tests/autorite-panneaux-montes.test.js.
import { useState } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { LOCALE_CODES } from '@/i18n/locales';

// Locales du widget bio multilingue (= CHECK author_translations.lang).
export const ALLOWED_BIO_LANGS = LOCALE_CODES;
// Titre de chaque champ (11/10/2026) : « Biographie en français », etc. —
// les dix champs par langue SONT la biographie ; plus de champ général au-dessus
// une fois l'autorité publiée.
export const BIO_TITLE_KEYS = {
  'pt-BR': 'catalogacao.bio.titleIn.ptBR', fr: 'catalogacao.bio.titleIn.fr', es: 'catalogacao.bio.titleIn.es',
  en: 'catalogacao.bio.titleIn.en', it: 'catalogacao.bio.titleIn.it', de: 'catalogacao.bio.titleIn.de',
  ca: 'catalogacao.bio.titleIn.ca', eo: 'catalogacao.bio.titleIn.eo', nl: 'catalogacao.bio.titleIn.nl',
  el: 'catalogacao.bio.titleIn.el', ro: 'catalogacao.bio.titleIn.ro',
};

export default function AuthorBioTranslations({ authorId, bioTranslations, setBioTranslations, bioDirty, setBioDirty, user, onMessage, confirmSaved }) {
  const { formatMessage: t } = useIntl();
  const [bioReviewBusy, setBioReviewBusy] = useState(null); // lang en cours de bascule de revue

  // Recharge les traductions bio (après save ou bascule de revue).
  async function reloadBioTranslations() {
    if (!authorId) return;
    const { data } = await supabase.from('author_translations')
      .select('lang, biography, author_id, status, reviewed_at').eq('author_id', Number(authorId));
    if (data) setBioTranslations(data);
    setBioDirty(new Set());
  }

  // Bascule le statut de revue d'une traduction (RPC staff).
  async function toggleBioReview(lang, toReviewed) {
    if (!authorId) return;
    setBioReviewBusy(lang);
    try {
      const { error } = await supabase.rpc('set_author_translation_review', {
        p_author_id: Number(authorId), p_lang: lang, p_reviewed: toReviewed,
      });
      if (error) throw error;
      await reloadBioTranslations();
    } catch (err) {
      onMessage({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setBioReviewBusy(null); }
  }

  return (
    <>
          {/* ── Biography translations widget (auteur publie uniquement) ─── */}
          {/* Cle sur published_author_id : jamais l'id de brouillon (collision
              avec les id d'auteurs reels). Editable seulement apres publication. */}
          {!authorId && (
            <div className="cat-field" style={{ gridColumn: 'span 3' }}>
              <div style={{ fontSize: '.78rem', color: 'var(--brand-muted, #aaa)', fontStyle: 'italic' }}>
                {t({id:'catalogacao.bio.translationsAfterPublish'})}
              </div>
            </div>
          )}
          {authorId && (
            <div className="cat-field" style={{ gridColumn: 'span 3' }}>
              <div>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 320px), 1fr))', gap: 8 }}>
                  {ALLOWED_BIO_LANGS.map(lang => {
                    const existing = bioTranslations.find(bt => bt.lang === lang);
                    const isDirty = bioDirty.has(lang);
                    const filled = !!existing?.biography?.trim();
                    const reviewed = existing?.status === 'reviewed' && !isDirty;
                    return (
                      <div key={lang} style={{ padding: '8px 10px', borderRadius: 8, background: 'rgba(0,0,0,.15)', border: '1px solid rgba(255,255,255,.06)' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4, gap: 6, flexWrap: 'wrap' }}>
                          <label htmlFor={`bio-${lang}`} style={{ fontWeight: 700, fontSize: '.82rem' }}>{t({ id: BIO_TITLE_KEYS[lang] })}</label>
                          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                            {isDirty ? (
                              <span style={{ fontSize: '.66rem', color: '#fbbf24' }}>{t({id:'catalogacao.bio.statusModified'})}</span>
                            ) : reviewed ? (
                              <span style={{ fontSize: '.66rem', color: '#4ade80' }}>✓ {t({id:'catalogacao.bio.statusReviewed'})}</span>
                            ) : filled ? (
                              <span style={{ fontSize: '.66rem', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.bio.statusDraft'})}</span>
                            ) : null}
                            {filled && !isDirty && (
                              <button type="button" disabled={bioReviewBusy === lang}
                                onClick={() => toggleBioReview(lang, !reviewed)}
                                style={{ background: 'none', border: '1px solid rgba(255,255,255,.15)', borderRadius: 5, color: 'var(--brand-muted, #aaa)', cursor: 'pointer', fontSize: '.62rem', padding: '2px 6px' }}
                                title={reviewed ? t({id:'catalogacao.bio.markDraft'}) : t({id:'catalogacao.bio.markReviewed'})}>
                                {bioReviewBusy === lang ? '…' : (reviewed ? '↺' : '✓')}
                              </button>
                            )}
                          </span>
                        </div>
                        <textarea
                          id={`bio-${lang}`}
                          lang={lang}
                          rows={3}
                          style={{ width: '100%', fontSize: '.82rem', padding: '6px 8px', borderRadius: 6, border: '1px solid rgba(255,255,255,.1)', background: 'rgba(0,0,0,.2)', color: '#f4f4f4', resize: 'vertical' }}
                          value={existing?.biography || ''}
                          placeholder={t({id:'catalogacao.bio.placeholder'}, {lang})}
                          onChange={e => {
                            const val = e.target.value;
                            setBioDirty(prev => new Set(prev).add(lang));
                            setBioTranslations(prev => {
                              const copy = prev.filter(bt => bt.lang !== lang);
                              copy.push({ ...(existing || {}), lang, biography: val, author_id: Number(authorId) });
                              return copy;
                            });
                          }}
                        />
                      </div>
                    );
                  })}
                </div>
                <button type="button" className="ab-button ab-button--secondary ab-button--sm" style={{ marginTop: 8 }} disabled={bioDirty.size === 0} onClick={async () => {
                  try {
                    for (const lang of bioDirty) {
                      const bt = bioTranslations.find(x => x.lang === lang);
                      const bio = bt?.biography?.trim();
                      if (!bio) continue;
                      // Une édition (re)pose status=draft : une bio modifiée doit être re-revue (§3.1).
                      await supabase.from('author_translations').upsert({
                        author_id: Number(authorId), lang, biography: bio,
                        status: 'draft', reviewed_by: null, reviewed_at: null,
                        updated_by: user?.id || null, updated_at: new Date().toISOString(),
                      }, { onConflict: 'author_id,lang' });
                    }
                    await reloadBioTranslations();
                    confirmSaved(t({id:'common.dataSaved'}));
                  } catch (err) { onMessage({ text: t({id:'common.errorPrefix'},{message:localizeError(err, t)}), kind: 'error' }); }
                }}>{t({id:'catalogacao.bio.save'})}</button>
              </div>
            </div>
          )}
    </>
  );
}
