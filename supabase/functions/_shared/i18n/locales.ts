// ============================================================================
// locales.ts — la liste des locales, côté Edge Functions (DOC-I18N-4)
// ============================================================================
// Même contenu, même ordre que src/i18n/locales.js (le front) et que
// public.fn_supported_locales() (la base) ; le test
// src/tests/locales-source-unique.test.js les compare et refuse toute autre
// liste en dur dans supabase/functions/.
//
// Avant le 13/10/2026, chaque fonction validait la locale reçue contre SA
// liste : celle de `register` n'avait ni nl ni el (mails de bienvenue en
// portugais pendant des semaines, corrigé le 27/08), et le repli vers pt-BR
// rendait l'oubli silencieux. Une fonction qui valide une locale importe
// d'ici ; un dictionnaire de chaînes reste indexé par code, tenu par les
// tests de parité (mail-strings-parity, etc.).
//
// L'ordre est celui du sélecteur de l'app. gazette-monthly-build traduit dans
// cet ordre avec un curseur en base (gazette_build_jobs.cursor_locale) :
// changer l'ordre ne se déploie pas pendant qu'un numéro est « translating ».
// ============================================================================

export const LOCALES = [
  { code: "pt-BR", label: "Português", siteCode: "pt", phraseCase: true, listed: true },
  { code: "fr", label: "Français", siteCode: "fr", phraseCase: true, listed: true },
  { code: "es", label: "Castellano", siteCode: "es", phraseCase: true, listed: true },
  { code: "en", label: "English", siteCode: "en", phraseCase: false, listed: true },
  { code: "it", label: "Italiano", siteCode: "it", phraseCase: true, listed: true },
  { code: "de", label: "Deutsch", siteCode: "de", phraseCase: false, listed: true },
  { code: "ca", label: "Català", siteCode: "ca", phraseCase: true, listed: true },
  { code: "eo", label: "Esperanto", siteCode: "eo", phraseCase: true, listed: true },
  { code: "nl", label: "Nederlands", siteCode: "nl", phraseCase: true, listed: true },
  { code: "el", label: "Ελληνικά", siteCode: "el", phraseCase: true, listed: true },
] as const;

export type SupportedLocale = typeof LOCALES[number]["code"];
export type SiteLocale = typeof LOCALES[number]["siteCode"];

export const DEFAULT_LOCALE: SupportedLocale = "pt-BR";

/** Les codes de l'app, dans l'ordre canonique. */
export const LOCALE_CODES: readonly SupportedLocale[] = LOCALES.map((l) => l.code);

/** Les codes du site et de la carte (« pt » pour pt-BR), même ordre. */
export const SITE_CODES: readonly SiteLocale[] = LOCALES.map((l) => l.siteCode);

const CODES: ReadonlySet<string> = new Set(LOCALE_CODES);
const SITES: ReadonlySet<string> = new Set(SITE_CODES);

/** La valeur est-elle exactement l'un des codes de l'app ? */
export function isSupportedLocale(x: unknown): x is SupportedLocale {
  return typeof x === "string" && CODES.has(x);
}

/** La valeur est-elle exactement l'un des codes du site (« pt », « fr »…) ? */
export function isSiteLocale(x: unknown): x is SiteLocale {
  return typeof x === "string" && SITES.has(x);
}
