import { useState } from 'react';
import { useIntl } from 'react-intl';
import Markdown from 'react-markdown';
import { COMMUNS_DOCS, COMMUNS_CATS, resolveDocMd } from './communsRegistry';

// ═══════════════════════════════════════════════════════════════════════════
// CommunsTab — onglet « Communs » de la Fédération.
//
// Rend lisibles DANS l'app les documents vivants du réseau (chartes, cadrages).
// v1 : lecture seule, contenu bundlé (cf. communsRegistry). La traduction par
// communauté de langue et l'édition par consentement viendront avec le backend
// Supabase (v2). Passe la grille de la charte : ouvert sur demande, registre
// d'offre, pas de surveillance ni de gamification → « ça tend ».
// ═══════════════════════════════════════════════════════════════════════════

export default function CommunsTab() {
  const { formatMessage: t, locale } = useIntl();
  const [openId, setOpenId] = useState(null);
  const doc = openId ? COMMUNS_DOCS.find((d) => d.id === openId) : null;

  if (doc) {
    return (
      <div className="ab-communs">
        <button type="button" className="cat-btn ghost" onClick={() => setOpenId(null)}>
          ← {t({ id: 'federacao.communs.back' })}
        </button>
        <article className="ab-communs-reader">
          <Markdown>{resolveDocMd(doc, locale)}</Markdown>
        </article>
      </div>
    );
  }

  return (
    <div className="ab-communs">
      <p className="ab-communs-intro">{t({ id: 'federacao.communs.intro' })}</p>

      {COMMUNS_CATS.map((cat) => {
        const docs = COMMUNS_DOCS.filter((d) => d.cat === cat);
        if (docs.length === 0) return null;
        return (
          <div key={cat}>
            <div className="ab-fed-label">{t({ id: `federacao.communs.cat.${cat}` })}</div>
            <div className="ab-communs-grid">
              {docs.map((d) => (
                <button key={d.id} type="button" className="ab-communs-card" onClick={() => setOpenId(d.id)}>
                  <span className="ab-communs-card-t">{t({ id: d.titleKey })}</span>
                  <span className="ab-communs-card-d">{t({ id: d.descKey })}</span>
                  <span className="ab-communs-card-go">{t({ id: 'federacao.communs.read' })} →</span>
                </button>
              ))}
            </div>
          </div>
        );
      })}

      <p className="ab-communs-note">{t({ id: 'federacao.communs.note' })}</p>
    </div>
  );
}
