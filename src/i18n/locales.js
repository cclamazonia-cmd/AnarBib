// ═══════════════════════════════════════════════════════════
// AnarBib — la liste des locales de l'app, et nulle part ailleurs (DOC-I18N-4)
// ═══════════════════════════════════════════════════════════
//
// Au 13/10/2026, la liste des dix codes était recopiée une soixantaine de
// fois (front, Edge Functions, contraintes et fonctions SQL, install.sh,
// outils de la vitrine, tests), dans au moins quatre ordres différents. Une
// copie oubliée refuse une langue EN SILENCE : `register` sans nl ni el
// (mails de bienvenue en portugais, 27/08), install.sh à trois langues sur
// dix (DOC-I18N-2, 20/09), LocaleSelector à six (une bibliothèque ne pouvait
// pas choisir ca, eo, nl ni el comme langue par défaut — réparé ici).
//
// Une couche, une source :
//   - front ............ ce fichier ;
//   - Edge Functions ... supabase/functions/_shared/i18n/locales.ts ;
//   - SQL .............. public.fn_supported_locales() ;
//   - vitrine .......... tools/locales.json (dépôt anarbib/pages).
// install.sh, qui ne peut rien importer, garde ses listes : un test les tient
// (src/tests/install-sh-locales.test.js). La garde anti-dérive
// (src/tests/locales-source-unique.test.js) refuse toute nouvelle liste en dur,
// et vérifie que les quatre sources disent la même chose, dans le même ordre.
//
// L'ORDRE compte, et c'est celui du sélecteur de langue : il range aussi les
// langues lues d'une bibliothèque (ReadLanguagesField, et le déclencheur
// tg_libraries_read_languages_normaliser côté base).
//
// Champs :
//   code       — étiquette BCP 47 de l'app (profiles.preferred_language,
//                libraries.default_locale, <html lang>) ;
//   label      — le nom de la langue dans sa propre langue (paquet 21 : ni
//                drapeau, ni code d'État) ;
//   siteCode   — le code du site vitrine et des données de la carte (« pt »
//                et non « pt-BR ») ;
//   phraseCase — un titre dans cette langue s'écrit en casse de phrase
//                (titleCase.js ; l'anglais a le title case, l'allemand garde
//                ses substantifs) ;
//   listed     — la langue figure dans les sélecteurs. Toutes y sont au
//                13/10 ; le champ prépare une langue « livrée mais hors du
//                sélecteur » le temps de sa relecture, si ce choix est retenu.

export const LOCALES = [
  { code: 'pt-BR', label: 'Português', siteCode: 'pt', phraseCase: true, listed: true },
  { code: 'fr', label: 'Français', siteCode: 'fr', phraseCase: true, listed: true },
  { code: 'es', label: 'Castellano', siteCode: 'es', phraseCase: true, listed: true },
  { code: 'en', label: 'English', siteCode: 'en', phraseCase: false, listed: true },
  { code: 'it', label: 'Italiano', siteCode: 'it', phraseCase: true, listed: true },
  { code: 'de', label: 'Deutsch', siteCode: 'de', phraseCase: false, listed: true },
  { code: 'ca', label: 'Català', siteCode: 'ca', phraseCase: true, listed: true },
  { code: 'eo', label: 'Esperanto', siteCode: 'eo', phraseCase: true, listed: true },
  { code: 'nl', label: 'Nederlands', siteCode: 'nl', phraseCase: true, listed: true },
  { code: 'el', label: 'Ελληνικά', siteCode: 'el', phraseCase: true, listed: true },
];

export const DEFAULT_LOCALE = 'pt-BR';

/** Les codes de l'app, dans l'ordre canonique. */
export const LOCALE_CODES = LOCALES.map((l) => l.code);

/** Les codes du site et de la carte (« pt » pour pt-BR), même ordre. */
export const SITE_CODES = LOCALES.map((l) => l.siteCode);

/** Code de l'app → code du site (« pt-BR » → « pt »). */
export const SITE_CODE = Object.fromEntries(LOCALES.map((l) => [l.code, l.siteCode]));

/** Codes du site des langues dont les titres vont en casse de phrase. */
export const PHRASE_CASE_CODES = LOCALES.filter((l) => l.phraseCase).map((l) => l.siteCode);
