// src/pages/catalogacao/ReviewPanel.jsx — E6, lot 5 (28/09/2026)
// Le « Painel de revisão da ficha » du formulaire de notice, sorti de
// BookDraftForm.jsx sans en changer une ligne de logique : trois onglets —
// résumé de la fiche et architecture documentale, sortie publique (ligne de
// catalogue, ouverture ISBD), pacote ISBD (énoncé et zones 0 à 8) — et les
// boutons « préparer / effacer » l'ISBD. Le panneau ne fait qu'AFFICHER : l'état
// ISBD, sa préparation (qui écrit marc_json) et les libellés de zones restent au
// parent, qui les passe en props ; seul l'onglet courant vit ici, remis sur le
// résumé quand le brouillon change (comme resetForm le faisait pour la fiche vierge).
import { useState, useEffect } from 'react';
import { useIntl } from 'react-intl';

export default function ReviewPanel({ f, draftId, materialLabel, isbdEnabled, isbdData, zoneLabels, onPrepareIsbd, onClearIsbd }) {
  const { formatMessage: t } = useIntl();
  const [reviewTab, setReviewTab] = useState('summary');
  useEffect(() => { setReviewTab('summary'); }, [draftId]);

  return (
    <div className="cat-material-section" style={{ marginTop: 18 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10, flexWrap: 'wrap', gap: 6 }}>
        <h4 style={{ margin: 0 }}>{t({id:'catalogacao.ui.reviewTitle'})}</h4>
        <div style={{ display: 'flex', gap: 6, alignItems: 'center', flexWrap: 'wrap' }}>
          <span className={`cat-pill ${isbdEnabled ? 'ok' : 'warn'}`}>
            {isbdEnabled ? t({id:'catalogacao.ui.isbdReady'}) : t({id:'catalogacao.ui.isbdNotReady'})}
          </span>
          <button type="button" className="ab-button ab-button--secondary ab-button--sm"
            onClick={onPrepareIsbd}>
            {isbdEnabled ? t({id:'catalogacao.ui.isbdUpdate'}) : t({id:'catalogacao.ui.isbdPrepare'})}
          </button>
          {isbdEnabled && (
            <button type="button" className="ab-button ab-button--ghost ab-button--sm"
              onClick={onClearIsbd}>{t({id:'catalogacao.ui.clearIsbd'})}</button>
          )}
        </div>
      </div>
      <div style={{ fontSize: '.78rem', color: 'var(--brand-muted, #aaa)', marginBottom: 10 }}>
        {t({id:'catalogacao.ui.reviewHint'})}
      </div>

      {/* Sub-tabs — barre partagee de second niveau (`.ab-tabbar--sub`).
          Elle REVIENT A LA LIGNE au lieu de defiler : sous 720 px les trois
          onglets (~348 px) ne tenaient pas dans le panneau et partaient en
          defilement horizontal, ou personne n'allait les chercher. */}
      <div className="ab-tabbar ab-tabbar--sub">
        {[
          { id: 'summary', label: t({id:'catalogacao.ui.tabSummary'}) },
          { id: 'public', label: t({id:'catalogacao.ui.tabPublic'}) },
          { id: 'isbd', label: t({id:'catalogacao.ui.tabIsbd'}) },
        ].map(t => (
          <button key={t.id} type="button"
            className={`ab-tabbar__tab${reviewTab === t.id ? ' active' : ''}`}
            onClick={() => setReviewTab(t.id)}>
            {t.label}
          </button>
        ))}
      </div>

      {/* ── Resumo da ficha ─────────────────────── */}
      {reviewTab === 'summary' && (
        <div>
          <div style={{ padding: '12px 14px', background: 'rgba(0,0,0,.15)', borderRadius: 8, marginBottom: 12 }}>
            <h4 style={{ margin: '0 0 8px', fontSize: '.85rem' }}>{t({id:'catalogacao.ui.commonRecord'})}</h4>
            <div style={{ fontSize: '.82rem' }}>
              <div style={{ fontWeight: 600, marginBottom: 4 }}>
                {materialLabel}
              </div>
              <div style={{ fontSize: '.95rem', fontWeight: 700, marginBottom: 6 }}>
                {f('titulo') || t({id:'catalogacao.ui.titleMissing'})}
                {f('subtitulo') && <span style={{ fontWeight: 400, color: 'var(--brand-muted, #aaa)' }}> : {f('subtitulo')}</span>}
              </div>
              <div style={{ color: 'var(--brand-muted, #aaa)', marginBottom: 3 }}>
                {t({ id: 'catalogacao.ui.recordLabel' })} {[f('autor'), f('editora'), f('local_publicacao'), f('ano')].filter(Boolean).join(' · ') || '—'}
              </div>
              <div style={{ color: 'var(--brand-muted, #aaa)', marginBottom: 3 }}>
                {t({id:'catalogacao.ui.circulationLabel'})}: {(() => { const c = f('circulation_default') || 'emprestavel'; return c === 'consulta' ? t({id:'catalogacao.ui.consultOnly'}) : c === 'ambos' ? t({id:'catalogacao.ui.circulationBoth'}) : t({id:'catalogacao.ui.loanable'}); })()}
                {f('cdd') && ` · CDD: ${f('cdd')}`}
                {f('idioma') && ` · ${f('idioma')}`}
              </div>
              {f('subjects') && (
                <div style={{ color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.ui.subjectsLabel' })} {f('subjects')}</div>
              )}
            </div>
          </div>

          {/* Architecture documentale */}
          <div style={{ padding: '12px 14px', background: 'rgba(0,0,0,.1)', borderRadius: 8, border: '1px dashed rgba(255,255,255,.08)' }}>
            <h4 style={{ margin: '0 0 6px', fontSize: '.82rem' }}>{t({id:'catalogacao.ui.archTitle'})}</h4>
            <div style={{ fontSize: '.75rem', color: 'var(--brand-muted, #888)', lineHeight: 1.6 }}>
              {/* #fix-android (19/07) : ces 4 lignes (badge + description longue)
                  n'avaient ni flexWrap ni minWidth sur la description -> sur
                  Android (police systeme agrandie), le texte debordait de la
                  page au lieu de passer a la ligne (confirme par capture reelle,
                  texte coupe en plein mot). */}
              <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 3, flexWrap: 'wrap' }}>
                <span className="cat-pill info" style={{ fontSize: '.62rem' }}>{t({id:'catalogacao.ui.layer1'})}</span>
                <span style={{ flex: 1, minWidth: 'min(200px, 100%)' }}>{t({id:'catalogacao.ui.layer1desc'})} {f('titulo') ? t({id:'catalogacao.ui.layer1editing'}) : t({id:'catalogacao.ui.layer1empty'})}</span>
              </div>
              <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 3, flexWrap: 'wrap' }}>
                <span className="cat-pill warn" style={{ fontSize: '.62rem' }}>{t({id:'catalogacao.ui.layer2'})}</span>
                <span style={{ flex: 1, minWidth: 'min(200px, 100%)' }}>{t({id:'catalogacao.ui.layer2desc'})} {f('bib_ref') || f('owner_library') ? t({id:'catalogacao.ui.layer1editing'}) : t({id:'catalogacao.ui.layer2pending'})}</span>
              </div>
              <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 3, flexWrap: 'wrap' }}>
                <span className="cat-pill warn" style={{ fontSize: '.62rem' }}>{t({id:'catalogacao.ui.layer3'})}</span>
                <span style={{ flex: 1, minWidth: 'min(200px, 100%)' }}>{t({id:'catalogacao.ui.layer3desc'})}</span>
              </div>
              <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
                <span className="cat-pill warn" style={{ fontSize: '.62rem' }}>{t({id:'catalogacao.ui.layer4'})}</span>
                <span style={{ flex: 1, minWidth: 'min(200px, 100%)' }}>{t({id:'catalogacao.ui.layer4desc'})}</span>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ── Saída pública ──────────────────────── */}
      {reviewTab === 'public' && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 240px), 1fr))', gap: 12 }}>
          <div style={{ padding: '12px 14px', background: 'rgba(0,0,0,.15)', borderRadius: 8 }}>
            <div style={{ fontSize: '.7rem', textTransform: 'uppercase', letterSpacing: '.04em', color: 'var(--brand-muted, #888)', marginBottom: 6 }}>{t({id:'catalogacao.public.catalogLine'})}</div>
            <div style={{ display: 'flex', gap: 6, marginBottom: 6, flexWrap: 'wrap' }}>
              <span className="cat-pill info">{materialLabel}</span>
            </div>
            <div style={{ fontSize: '.92rem', fontWeight: 700, marginBottom: 4 }}>{f('titulo') || t({ id: 'catalogacao.ui.titleFallback' })}</div>
            <div style={{ fontSize: '.78rem', color: 'var(--brand-muted, #aaa)' }}>
              {[f('autor'), f('editora'), f('ano')].filter(Boolean).join(' · ') || '—'}
            </div>
            {f('isbn') && <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #888)', marginTop: 3 }}>ISBN {f('isbn')}</div>}
          </div>
          <div style={{ padding: '12px 14px', background: 'rgba(0,0,0,.15)', borderRadius: 8 }}>
            <div style={{ fontSize: '.7rem', textTransform: 'uppercase', letterSpacing: '.04em', color: 'var(--brand-muted, #888)', marginBottom: 6 }}>{t({ id: 'catalogacao.ui.isbdOpening' })}</div>
            <div style={{ fontSize: '.92rem', fontWeight: 700, marginBottom: 4 }}>{f('titulo') || t({ id: 'catalogacao.ui.titleFallback' })}</div>
            <div style={{ fontSize: '.78rem', color: 'var(--brand-muted, #aaa)', marginBottom: 3 }}>
              {f('subtitulo') && <span>{f('subtitulo')}<br /></span>}
              {f('autor') && <span>{f('autor')}<br /></span>}
              {[f('editora'), f('local_publicacao'), f('ano')].filter(Boolean).join(', ')}
            </div>
            {f('subjects') && <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #888)' }}>{t({ id: 'catalogacao.ui.subjectsLabel' })} {f('subjects')}</div>}
          </div>
        </div>
      )}

      {/* ── Pacote ISBD ───────────────────────── */}
      {reviewTab === 'isbd' && (
        <div>
          <div style={{ fontSize: '.78rem', color: 'var(--brand-muted, #aaa)', marginBottom: 10 }}>
            {t({id:'catalogacao.isbd.hint'})}
          </div>
          {isbdData ? (
            <>
              <div style={{ fontSize: '.78rem', marginBottom: 10 }}>
                <strong>ISBD:</strong> {t({id:'catalogacao.isbd.zonesFilled'}, {count: isbdData.nonEmptyCount})}
              </div>
              {/* Statement */}
              <div className="cat-field" style={{ marginBottom: 12 }}>
                <label>{t({id:'catalogacao.isbd.prepared'})}</label>
                <textarea value={isbdData.statement} readOnly rows={3}
                  style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.2)', color: '#f4f4f4', fontSize: '.82rem', resize: 'vertical', fontFamily: 'inherit' }}
                />
              </div>
              {/* Individual zones */}
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 200px), 1fr))', gap: 10 }}>
                {['0','1','2','3','4','5','6','7','8'].map(z => (
                  <div key={z} className="cat-field">
                    <label>{t({id:'catalogacao.isbd.zonePrefix'}, {zone: z})} — {zoneLabels[z]}</label>
                    <textarea value={isbdData.zones[z]?.value || ''} readOnly rows={2}
                      style={{ width: '100%', padding: '6px 8px', borderRadius: 6, border: '1px solid rgba(255,255,255,.08)', background: isbdData.zones[z]?.value ? 'rgba(0,0,0,.2)' : 'rgba(0,0,0,.08)', color: isbdData.zones[z]?.value ? '#f4f4f4' : 'var(--brand-muted, #666)', fontSize: '.78rem', resize: 'vertical', fontFamily: 'inherit' }}
                      placeholder={t({ id: 'catalogacao.ph.notPrepared' })}
                    />
                  </div>
                ))}
              </div>
            </>
          ) : (
            <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #888)', padding: '16px 0', textAlign: 'center' }}>
              {t({id:'catalogacao.isbd.notGenerated'})}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
