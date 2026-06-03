import { useEffect, useState } from 'react';
import { useIntl } from 'react-intl';
import ReactMarkdown from 'react-markdown';
import { supabase } from '@/lib/supabase';

// ─── Configuration ───────────────────────────────────────────────────────────
// On récupère l'URL Supabase directement depuis le client déjà initialisé,
// ce qui évite de dépendre de VITE_SUPABASE_URL qui n'est pas toujours défini.
const SUPABASE_URL = supabase.supabaseUrl;
const BUCKET = 'library-privacy-public';
const FALLBACK_LOCALE = 'pt-BR';

// Map des locales utilisées par l'app vers les noms de fichier dans le bucket
const LOCALE_TO_FILE = {
  'pt-BR': 'privacy-pt-BR.md',
  'fr': 'privacy-fr.md',
  'es': 'privacy-es.md',
  'en': 'privacy-en.md',
  'it': 'privacy-it.md',
  'de': 'privacy-de.md',
  'ca': 'privacy-ca.md',
  'eo': 'privacy-eo.md',
};

// ─── Helper : construit l'URL du fichier .md ────────────────────────────────
function buildPrivacyUrl(slug, locale) {
  const filename = LOCALE_TO_FILE[locale] || LOCALE_TO_FILE[FALLBACK_LOCALE];
  return `${SUPABASE_URL}/storage/v1/object/public/${BUCKET}/${slug}/${filename}`;
}

// ─── Styles ──────────────────────────────────────────────────────────────────
const sectionStyle = {
  marginTop: 32,
  marginBottom: 24,
  padding: '20px 22px',
  background: 'rgba(255,255,255,.025)',
  borderLeft: '3px solid var(--brand-accent, #c44)',
  borderRadius: '0 8px 8px 0',
};

const titleStyle = {
  fontSize: '1.05rem',
  fontWeight: 700,
  marginTop: 0,
  marginBottom: 14,
  color: 'var(--brand-fg, #f4f4f4)',
  fontFamily: 'var(--brand-font-body)',
  textTransform: 'none',
};

const fallbackNoticeStyle = {
  fontSize: '.78rem',
  color: 'var(--brand-muted, #999)',
  fontStyle: 'italic',
  marginBottom: 12,
  marginTop: -8,
};

// Personnaliser le rendu Markdown pour rester cohérent avec le design de la page
const markdownComponents = {
  h1: ({ children }) => (
    <h3 style={{ fontSize: '1rem', fontWeight: 700, marginTop: 14, marginBottom: 8 }}>
      {children}
    </h3>
  ),
  h2: ({ children }) => (
    <h4 style={{ fontSize: '.95rem', fontWeight: 700, marginTop: 12, marginBottom: 6 }}>
      {children}
    </h4>
  ),
  h3: ({ children }) => (
    <h5 style={{ fontSize: '.92rem', fontWeight: 600, marginTop: 10, marginBottom: 6 }}>
      {children}
    </h5>
  ),
  p: ({ children }) => (
    <p style={{ fontSize: '.92rem', lineHeight: 1.6, marginTop: 0, marginBottom: 10 }}>
      {children}
    </p>
  ),
  ul: ({ children }) => (
    <ul style={{ fontSize: '.92rem', lineHeight: 1.6, paddingLeft: 22, marginBottom: 10 }}>
      {children}
    </ul>
  ),
  ol: ({ children }) => (
    <ol style={{ fontSize: '.92rem', lineHeight: 1.6, paddingLeft: 22, marginBottom: 10 }}>
      {children}
    </ol>
  ),
  a: ({ href, children }) => (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      style={{ color: 'var(--brand-accent, #c44)' }}
    >
      {children}
    </a>
  ),
  code: ({ children }) => (
    <code style={{
      fontSize: '.85rem',
      background: 'rgba(255,255,255,.06)',
      padding: '1px 6px',
      borderRadius: 3,
    }}>
      {children}
    </code>
  ),
};

// ─── Helper : vérifie qu'une réponse fetch est bien un .md (pas du HTML) ────
// Sécurité : si l'URL est incorrecte et que Vite/le serveur sert un index.html
// avec un 200 OK, on doit le détecter pour ne pas afficher du HTML brut.
function isMarkdownResponse(text, contentType) {
  if (contentType && contentType.includes('text/html')) return false;
  // Heuristique : un .md ne commence jamais par <!DOCTYPE ou <html
  const trimmed = text.trim().slice(0, 50).toLowerCase();
  if (trimmed.startsWith('<!doctype') || trimmed.startsWith('<html')) return false;
  return true;
}

// ─── Composant principal ─────────────────────────────────────────────────────
/**
 * LibraryPrivacySection
 * Charge et affiche la section spécifique de confidentialité d'une bibliothèque.
 *
 * Props:
 *   library: { slug: string, name: string, short_name?: string }
 *   locale:  string (ex. 'pt-BR', 'fr', 'es', 'en', 'it', 'de')
 *
 * Comportement:
 *   1. Tente de charger privacy-{locale}.md depuis le bucket Supabase Storage
 *   2. Si 404, tente le fallback privacy-pt-BR.md (avec notice)
 *   3. Si 404 aussi, n'affiche rien (silencieux)
 */
export default function LibraryPrivacySection({ library, locale }) {
  const { formatMessage: t } = useIntl();
  const [markdown, setMarkdown] = useState(null);
  const [usedFallback, setUsedFallback] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;

    async function tryFetch(targetLocale) {
      try {
        const res = await fetch(buildPrivacyUrl(library.slug, targetLocale), {
          cache: 'no-cache',
        });
        if (!res.ok) return null;
        const text = await res.text();
        const contentType = res.headers.get('content-type') || '';
        if (!isMarkdownResponse(text, contentType)) return null;
        return text;
      } catch (e) {
        return null;
      }
    }

    async function load() {
      setLoading(true);
      setMarkdown(null);
      setUsedFallback(false);

      // Tentative 1 : locale demandée
      const primary = await tryFetch(locale);
      if (cancelled) return;
      if (primary !== null) {
        setMarkdown(primary);
        setLoading(false);
        return;
      }

      // Tentative 2 : fallback pt-BR (sauf si on était déjà en pt-BR)
      if (locale !== FALLBACK_LOCALE) {
        const fallback = await tryFetch(FALLBACK_LOCALE);
        if (cancelled) return;
        if (fallback !== null) {
          setMarkdown(fallback);
          setUsedFallback(true);
          setLoading(false);
          return;
        }
      }

      // Aucun fichier disponible : on n'affiche rien
      setMarkdown(null);
      setLoading(false);
    }

    load();
    return () => { cancelled = true; };
  }, [library.slug, locale]);

  // Pendant le chargement, on n'affiche rien (évite un flash)
  if (loading) return null;

  // Pas de contenu disponible : on n'affiche rien (silencieux)
  if (!markdown) return null;

  return (
    <section style={sectionStyle} aria-labelledby={`privacy-lib-${library.slug}`}>
      <h2 id={`privacy-lib-${library.slug}`} style={titleStyle}>
        {t({ id: 'privacy.lib.title' }, { name: library.name })}
      </h2>
      {usedFallback && (
        <p style={fallbackNoticeStyle}>
          {t({ id: 'privacy.lib.fallback' })}
        </p>
      )}
      <div style={{ color: 'var(--brand-fg, #e8e8e8)' }}>
        <ReactMarkdown components={markdownComponents}>
          {markdown}
        </ReactMarkdown>
      </div>
    </section>
  );
}
