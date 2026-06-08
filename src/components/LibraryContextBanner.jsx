import { useIntl } from 'react-intl';
import { useLibrary } from '@/contexts/LibraryContext';

// MULTI P5b — Bandeau de contexte « biblio courante » (spec §3, B.2 option a /
// Zone 19 option b). N'apparaît qu'à partir de 2 appartenances DISTINCTES. Les
// chips appellent setLibrary(slug) du LibraryContext, qui bascule le contexte,
// re-thème les variables --brand-* (via useTheme(ctx.themeSlug)) et persiste en
// sessionStorage — toute l'infra existait déjà, P5b n'ajoute que l'UI explicite.

export default function LibraryContextBanner() {
  const { formatMessage: t } = useIntl();
  const { libraries, librarySlug, setLibrary } = useLibrary();

  if (!Array.isArray(libraries) || libraries.length < 2) return null;

  // Dédup par bibliothèque (une lectrice peut avoir 2 lignes d'appartenance pour
  // la même biblio via des rôles distincts — clé unique (user, library, role)).
  const libs = [];
  const seen = new Set();
  for (const m of libraries) {
    const l = m?.libraries;
    if (l?.slug && !seen.has(l.slug)) { seen.add(l.slug); libs.push(l); }
  }
  if (libs.length < 2) return null;

  return (
    <div
      role="region"
      aria-label={t({ id: 'libctx.label' })}
      style={{
        display: 'flex', alignItems: 'center', gap: 12, flexWrap: 'wrap',
        padding: '10px 16px', marginBottom: 16, borderRadius: 10,
        background: 'var(--brand-panel-bg, rgba(18,18,18,.82))',
        border: '1px solid var(--brand-panel-border, rgba(255,255,255,.14))',
      }}
    >
      <span style={{ fontSize: '.8rem', color: 'var(--brand-muted)', fontWeight: 600 }}>
        {t({ id: 'libctx.label' })} :
      </span>
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', flex: 1 }}>
        {libs.map((l) => {
          const active = l.slug === librarySlug;
          return (
            <button
              key={l.slug}
              type="button"
              onClick={() => { if (!active) setLibrary(l.slug); }}
              aria-pressed={active}
              style={{
                padding: '4px 12px', borderRadius: 999, fontSize: '.82rem',
                cursor: active ? 'default' : 'pointer',
                border: '1px solid',
                borderColor: active ? 'transparent' : 'var(--brand-panel-border, rgba(255,255,255,.14))',
                background: active ? 'var(--brand-action, #b32025)' : 'transparent',
                color: active ? '#fff' : 'var(--brand-text)',
                fontWeight: active ? 700 : 400,
              }}
            >
              {l.short_name || l.name || l.slug}
            </button>
          );
        })}
      </div>
      <span style={{ fontSize: '.74rem', color: 'var(--brand-muted)', flexBasis: '100%' }}>
        {t({ id: 'libctx.hint' })}
      </span>
    </div>
  );
}
