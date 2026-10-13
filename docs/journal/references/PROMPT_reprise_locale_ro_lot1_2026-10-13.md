# Prompt de reprise — chantier « locale ro », après le lot 1 (13/10/2026)

Document de référence : « AnarBib — passer de 10 à 11 locales : inventaire et
plan pour le roumain » (https://claude.ai/code/artifact/50a03cff-ad18-4211-8581-e94207565e73).
Backlog : `E39`. Doctrine : `DOC-I18N-4` (REGISTRE v0.87).

## Où on en est

Le lot 1 (« source unique des locales ») est livré, **sans roumain** : l'app
se comporte comme avant avec ses dix langues.

| Couche | Source | Tenue par |
|---|---|---|
| front | `src/i18n/locales.js` (`LOCALES`, `LOCALE_CODES`, `SITE_CODES`, `SITE_CODE`, `PHRASE_CASE_CODES` ; champ `listed`) | `locales-parite.test.js` |
| Edge Functions | `supabase/functions/_shared/i18n/locales.ts` (`SupportedLocale`, `isSupportedLocale`, `SITE_CODES`) | `locales-source-unique.test.js` (mêmes champs, même ordre) |
| SQL | `public.fn_supported_locales()` (`20261013194812`), lue par 8 contraintes et 8 fonctions | `tests/sql/locales_source_unique_tests.sql` |
| install.sh | ses propres listes (en-tête, détection, `--lang` ×2, `err_lang`, table `t()`) | `install-sh-locales.test.js` |
| vitrine (`anarbib/pages`) | `tools/locales.json`, `tools/slugs.json`, `tools/pose-selecteur.cjs` | `pose-selecteur.cjs --check` |

Garde anti-dérive : `src/tests/locales-source-unique.test.js` refuse toute
liste littérale d'au moins cinq codes hors des sources ; les listes d'une autre
nature sont dans `AUTRES_LISTES` (fermée dans les deux sens).

L'ordre canonique est celui du sélecteur : pt-BR, fr, es, en, it, de, ca, eo,
nl, el. Il range aussi `libraries.read_languages` (déclencheur). La gazette
traduit dans cet ordre (curseur `gazette_build_jobs.cursor_locale`) : ne pas
déployer un changement d'ordre pendant un numéro « translating ».

## Ajouter le roumain, couche par couche (lot 3, après les décisions)

1. `src/i18n/locales.js` : une ligne `{ code: 'ro', label: 'Română', siteCode: 'ro', phraseCase: true, listed: false }` ; `src/i18n/locales/ro.json`.
2. `_shared/i18n/locales.ts` : la même ligne (la garde compare les deux).
3. Une migration qui redéfinit `public.fn_supported_locales()` avec `'ro'` en plus (la garde lit la dernière définition) ; rien d'autre côté SQL.
4. `install.sh` : les quatre listes + `ro:<clé>)` pour les 83+ clés de `t()` (le test le dira).
5. Les dictionnaires par langue que `locales-parite.test.js` fera échouer (noms de la gazette et de la lettre, titres des biographies, pistes de sous-titres, pages des recueils, documents des Communs) ; les chaînes de mails (tests de parité).
6. Vitrine : une ligne dans `tools/locales.json`, les slugs `ro` dans `tools/slugs.json`, les pages, puis `node tools/pose-selecteur.cjs`.

## Restes et défauts vus pendant le lot 1 (non traités)

- Lot 2 : police des PDF jspdf (Helvetica, jeu WinAnsi) — à confirmer sur un rapport en grec ; `fn_locale_from_idioma`, `ingest.fn_idioma_bcp47`, `fn_notify_fonds_deposit_received`, regex de casse de phrase de `20260904130100`, `WD_LANGUAGES` d'`authority_lookup`, `_shared/marc/ecriture.ts`.
- Vitrine : le sélecteur des dix pages du guide d'accueil renvoie vers les pages Contribuer (le générateur copie le chrome de la page sœur, sélecteur compris) — à décider ; aucune page n'a de `hreflang` (proposition : poser les `<link rel="alternate">` par `pose-selecteur.cjs`).
- `libraries.default_locale` n'a pas de contrainte CHECK (seul le sélecteur la tient).
- Décisions D1 à D7 non tranchées ; `DOC-I18N-1` non amendé.
- Manuel (lot 4) : la section « Double authentification » se pose en roumain en ajoutant `ro: { fichier: 'manual-ro.md', A, B }` à l'objet T de `scripts/manuel-b42-double-authentification.cjs` (session B42, `aad3617c`) puis en le rejouant, une fois `docs/manual-ro.md` créé ; libellés à reprendre de ro.json (twoFactor.*, nav.account, account.tab.profile, rede.tab.twoFactor, nav.network).
