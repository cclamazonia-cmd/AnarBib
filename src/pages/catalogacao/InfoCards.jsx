// src/pages/catalogacao/InfoCards.jsx — E6, lot 8 (28/09/2026)
// Les cartes « para informação » de l'aperçu de la fiche, sorties de
// BookDraftForm.jsx sans en changer une ligne : les auteur·rices (liées ou
// non à une autorité) et les exemplaires — ceux de la bibliothèque active,
// cliquables vers l'éditeur d'exemplaire, et le compte des autres
// bibliothèques détentrices (anti-orphelin). Le chargement des exemplaires
// (fonds puis exemplaires de la notice publiée) vit ici avec ses deux états ;
// le parent passe la notice, les contributeur·rices et les deux rappels de
// navigation. Rien ici n'écrit le formulaire.
import { useState, useEffect } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import BadgeRetire from '@/components/catalog/BadgeRetire';

export default function InfoCards({ publishedBookId, catalogLibraries, libraryId, contributors, onNavigateTab, onEditExemplar }) {
  const { formatMessage: t } = useIntl();
  // ── Exemplaires liés (card "para informação", anti-orphelin) ──
  const [linkedExemplars, setLinkedExemplars] = useState([]); // [{ library_id, library_name, count }]
  // Exemplaires DÉTENUS PAR LA BIBLIOTHÈQUE ACTIVE pour ce document : liste
  // individuelle, en lecture seule, chaque ligne cliquable pour ouvrir l'éditeur
  // d'exemplaire (cf. prop onEditExemplar → retake + bascule onglet Indexação).
  const [myExemplars, setMyExemplars] = useState([]); // [{ id, tombo, shelf_location }]
  useEffect(() => {
    const pubId = publishedBookId;
    if (!pubId) { setLinkedExemplars([]); setMyExemplars([]); return; }
    let cancelled = false;
    (async () => {
      const { data: holdings } = await supabase.from('book_holdings').select('id, library_id').eq('book_id', Number(pubId));
      if (cancelled) return;
      if (!holdings || holdings.length === 0) { setLinkedExemplars([]); setMyExemplars([]); return; }
      const { data: exs } = await supabase.from('exemplares')
        .select('id, library_id, tombo, shelf_location, retire_at')
        .in('holding_id', holdings.map(h => h.id));
      if (cancelled) return;
      const byLib = {};
      for (const e of (exs || [])) byLib[e.library_id] = (byLib[e.library_id] || 0) + 1;
      const lname = (lid) => {
        const l = catalogLibraries.find(x => x.id === lid);
        return l?.short_name || l?.name || lid;
      };
      setLinkedExemplars(Object.entries(byLib).map(([lid, count]) => ({ library_id: lid, count, library_name: lname(lid) })));
      // Exemplaires de la bibliothèque active, triés par tombo (ordre naturel).
      const mine = (exs || [])
        .filter(e => e.library_id === libraryId)
        .map(e => ({ id: e.id, tombo: e.tombo || '', shelf_location: e.shelf_location || '', retire_at: e.retire_at || null }))
        .sort((a, b) => a.tombo.localeCompare(b.tombo, undefined, { numeric: true, sensitivity: 'base' }));
      setMyExemplars(mine);
    })();
    return () => { cancelled = true; };
  }, [publishedBookId, catalogLibraries, libraryId]);

    const cardStyle = { marginTop: 12, border: '1px solid rgba(255,255,255,.12)', borderRadius: 8, padding: '10px 12px', cursor: 'pointer', background: 'rgba(0,0,0,.18)' };
    const headStyle = { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6, flexWrap: 'wrap', gap: 6 };
    const titleStyle = { fontWeight: 700, fontSize: '.82rem' };
    const tagStyle = { fontSize: '.6rem', textTransform: 'uppercase', letterSpacing: '.04em', color: 'var(--brand-muted,#9aa)', border: '1px solid rgba(255,255,255,.15)', borderRadius: 4, padding: '1px 5px' };
    const lineStyle = { display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8, fontSize: '.8rem', padding: '2px 0', flexWrap: 'wrap' };
    const ctaStyle = { marginTop: 6, fontSize: '.74rem', color: 'var(--brand-color-primary,#c0392b)', fontWeight: 600 };
    const emptyStyle = { fontSize: '.78rem', color: 'var(--brand-muted,#888)', fontStyle: 'italic' };
    const pillStyle = { flexShrink: 0, fontSize: '.6rem' };
    const authors = contributors.filter(c => (c.name || '').trim());
    const goAuthor = () => onNavigateTab?.('authorsPanel');
    const goExemplar = () => onNavigateTab?.('indexPanel');
    return (
      <div className="ab-info-cards">
        {/* Card AUTORIA */}
        <div style={cardStyle} role="button" tabIndex={0} onClick={goAuthor}
          onKeyDown={e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); goAuthor(); } }}
          title={t({ id: 'catalogacao.infocard.goAuthor' })}>
          <div style={headStyle}>
            <span style={titleStyle}>{t({ id: 'catalogacao.infocard.authorTitle' })}</span>
            <span style={tagStyle}>{t({ id: 'catalogacao.infocard.forInfo' })}</span>
          </div>
          {authors.length === 0
            ? <div style={emptyStyle}>{t({ id: 'catalogacao.infocard.noAuthor' })}</div>
            : authors.map((c, i) => (
                <div key={i} style={lineStyle}>
                  <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{c.name}</span>
                  <span className={`cat-pill ${c.author_id ? 'ok' : 'warn'}`} style={pillStyle}>
                    {c.author_id ? t({ id: 'catalogacao.infocard.linked' }) : t({ id: 'catalogacao.infocard.unlinked' })}
                  </span>
                </div>
              ))}
          <div style={ctaStyle}>{t({ id: 'catalogacao.infocard.goAuthor' })} →</div>
        </div>
        {/* Card EXEMPLARES */}
        <div style={cardStyle} role="button" tabIndex={0} onClick={goExemplar}
          onKeyDown={e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); goExemplar(); } }}
          title={t({ id: 'catalogacao.infocard.goExemplar' })}>
          <div style={headStyle}>
            <span style={titleStyle}>{t({ id: 'catalogacao.infocard.exemplarTitle' })}</span>
            <span style={tagStyle}>{t({ id: 'catalogacao.infocard.forInfo' })}</span>
          </div>
          {!publishedBookId
            ? <div style={emptyStyle}>{t({ id: 'catalogacao.infocard.exemplarUnsaved' })}</div>
            : (myExemplars.length === 0 && linkedExemplars.length === 0)
              ? <div style={emptyStyle}>{t({ id: 'catalogacao.infocard.noExemplar' })}</div>
              : <>
                  {/* Exemplaires de la bibliothèque active : lignes cliquables → éditeur */}
                  {myExemplars.map((ex) => {
                    const open = (e) => { e.stopPropagation(); onEditExemplar?.(ex.id); };
                    return (
                      <div key={ex.id} role="button" tabIndex={0}
                        className="cat-exemplar-row"
                        style={{ ...lineStyle, cursor: 'pointer' }}
                        onClick={open}
                        onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); open(e); } }}
                        title={ex.shelf_location || undefined}>
                        <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{ex.tombo || '—'}</span>
                        {/* H21 lot 7 : sorti du catalogue d'origine */}
                        <BadgeRetire exemplaire={ex} />
                        <span style={{ ...pillStyle, color: 'var(--brand-color-primary,#c0392b)', fontWeight: 700 }} aria-hidden="true">→</span>
                      </div>
                    );
                  })}
                  {/* Autres bibliothèques détentrices : agrégat informatif, non éditable */}
                  {linkedExemplars.filter(r => r.library_id !== libraryId).map((r, i) => (
                    <div key={`agg-${i}`} style={lineStyle}>
                      <span>{r.library_name}</span>
                      <span className="cat-pill ok" style={pillStyle}>{t({ id: 'catalogacao.infocard.exemplarCount' }, { n: r.count })}</span>
                    </div>
                  ))}
                </>}
          <div style={ctaStyle}>{t({ id: 'catalogacao.infocard.goExemplar' })} →</div>
        </div>
      </div>
    );
}
