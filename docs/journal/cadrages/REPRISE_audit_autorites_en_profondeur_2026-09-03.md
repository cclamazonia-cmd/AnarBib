# Reprise — audit en profondeur des autorités, et correction propre

> **Cadrage pour une nouvelle session Code**, écrit le 03/09/2026 au soir à la
> demande de Xavier : « une fois les 464 cas tranchés, les autorités doivent
> être à nouveau auditées en profondeur et corrigées proprement ».
> Genre : cadrage (intention, pas état des lieux — **vérifier l'état réel avant
> d'implémenter**, c'est la leçon des quatre `DOC-RECENS-1` de cette semaine).

---

## 1. Ce qu'on attend de la session

1. **Un audit daté** des autorités (`public.authors`) et de leurs liens
   (`public.book_contributors`), sur le modèle de
   `journal/audits/AUDIT_conventions_catalographiques_2026-08-20.md`
   (sections A1–A9 autorités, T1–T6 titres, R1–R2 référentiels) : **rejouer
   ses requêtes**, mesurer ce qui a bougé depuis le 21/08, et ajouter ce que
   l'audit du 20/08 n'avait pas vu.
2. **Des corrections propres** : par **lots de la file de vérification**
   (`catalog_review_queue`, RPC `api.conv_revue_*`, écran `/atelier-autoridades`)
   quand le jugement est humain ; par **migration testée** quand la règle est
   mécanique et sûre (comme les dix-neuf `conventions_*` du 21/08). **Jamais** un
   `UPDATE authors` direct en production.
3. Le REGISTRE §37 `CONV` et les fiches du backlog v34 (**C3**, **C9 f[3]**,
   **C5** close mais son lot vit) mis à jour avec ce qui a été mesuré et fait.

## 2. L'état de départ, mesuré le 03/09/2026

| Mesure | Valeur | Source |
|---|---|---|
| Autorités | **1 532** (1 305 à midi) | `authors` |
| … typées `person` / `collective` / **non typées** | 45 / 19 / **1 468** | `authority_type` |
| … avec `name_lang` renseigné / `country` renseigné | 22 / 579 | CONV-6 / O1 : la règle de coupe ne s'applique que si renseigné, jamais deviné depuis `country` |
| … **créées le 03/09 entre 16 h 08 et 16 h 10 par le lot C5** (`source_kind = 'conv_revue'`) | **227** | **c'est le premier objet de l'audit** : des autorités nées d'une transcription (« NOM, Prénom », 9 tout en capitales, formes « Prénom Nom » sans virgule), non typées, jamais relues |
| … orphelines (aucun lien) / doublons de forme de tri sans casse | 6 / 2 | à recompter avec `unaccent` |
| Livres sans aucune autorité liée | **18** (464 le matin) | le lot `autor_sans_autorite` a été **tranché le 03/09 par Xavier** : 446 validés et appliqués (446 liens posés), 18 écartés (anonymes, collectifs, « AA. VV. ») |
| … chaînes multi-personnes (« ; ») dans le lot | 125 | seule la première personne est liée ; les autres restent des noms sans autorité dans `book_contributors` |
| Tables de revue du 20/08 (`conv_backup`) | titres 211 · casse 1 274 · patronymes 22 | fiche C3 : à traiter fiche par fiche, **jamais en masse** |
| Collectivités « à revoir » (O2) | 2 | lot `autorite_collectivite` |
| Fiches doubles à découper (O8) | 3 | autorités 10748, 10859, 10429 — pas de fonction de scission : à la main |

(Les deux dernières lignes du tableau et les compteurs de doublons sont à
recompter au début de la session : ce document est un cadrage.)

## 3. Ce qu'il faut savoir avant de toucher quoi que ce soit

- **`book_authors` est une table DÉRIVÉE** (trigger `trg_sync_book_authors`).
  La vérité des auteurs d'un livre est `book_contributors` (`name` tel
  qu'imprimé, `author_id` nullable, `role`, `position`, `is_primary`). Lier une
  autorité = écrire `book_contributors.author_id`. Mémoire
  `anarbib-book-authors-derivee`.
- **`books.autor` est la transcription** (C5 = B, 03/09) : elle reste, elle ne
  se « corrige » pas vers l'autorité ; l'OPAC affiche `author_display || autor`.
- **L'outil propose, l'humain tranche.** Chaque lot de la file porte
  `apres_propose` ; les verdicts sont `valide` / `corrige` (avec valeur) /
  `ecarte` ; l'application (`conv_revue_appliquer`) refuse d'écrire si l'entité
  a changé depuis le semis (CONV-O6). **Interdiction absolue** (fiche C3) de
  valider en masse, de décommenter un SQL d'application, ou de passer les
  verdicts par script.
- **Le lot `autor_sans_autorite`** est un cas particulier : « appliquer » y pose
  un lien (autorité retrouvée par l'une des deux formes sans casse, créée
  sinon), ne réécrit rien. Migration `20260903150117`, suite
  `tests/sql/conv_c5_autor_sans_autorite_tests.sql`.
- **Conventions actées** : `CONV-1..7` (REGISTRE §37), `CONV-6`/`O1` (la langue
  du nom pilote la coupe), `O2` (collectivités : nom officiel, langue de la
  collectivité, pas d'inversion), `O4` (pas d'EDTF sans déclencheur), `O7`
  (`authority_type` est la vérité ; les non typées s'affichent personnes à
  l'écran seulement), `O8` (pas de scission avant la quatrième fiche double).
- **Anti-fork** : le thésaurus FICEDL est une source qu'on ne corrige pas chez
  nous ; les autorités de personnes sont à nous. Ne pas confondre les deux.
- **Ce que l'audit du 20/08 tenait pour le plus grave** : les points d'accès
  posés sur un suffixe de filiation (« FILHO, Fábio Luz »), neuf cas — à
  traiter en premier (C3).

## 4. Méthode proposée

1. **Recompter** (§2) et rejouer les requêtes de l'audit du 20/08 ; écrire
   `AUDIT_autorites_2026-09-XX.md` avec un tableau de bord avant/après 21/08.
2. **Chercher ce que le 20/08 n'a pas vu** : doublons sans casse ou avec
   diacritiques (`unaccent`), autorités orphelines (aucun lien), autorités
   créées par le lot C5 (`source_kind = 'conv_revue'`) à relire, formes
   « Prénom Nom » sans virgule (113 dans le lot), collectivités logées comme
   personnes, dates et pays (A5, A7), identifiants externes (A8/A9).
3. **Classer** chaque défaut : mécanique et sûr → migration + suite SQL ;
   jugement → nouveau lot de la file (élargir la CHECK `lot`, une branche
   dans `conv_revue_appliquer`, une carte dans `ConvRevuePanel`, une clé i18n
   ×10 — le patron est `20260903150117`).
4. **Ne pas refaire ce qui existe** : `merge_author` (fusion), la file, les
   dix-neuf migrations `conventions_*`, `fn_conv_cible`, les vues
   `private.v_conv_*`. Chercher dans `prosrc` avant de créer.
5. **Livrer par petits commits**, chacun vert en local (recette §6), avec la
   suite SQL dans `tests/sql/ci-suites.txt`.

## 5. Les mémoires et documents à lire d'abord

- Mémoires : `anarbib-book-authors-derivee`, `anarbib-rpc-jamais-empruntee`,
  `anarbib-advisor-secdef-grants` (checklist pré-REVOKE, point 0 : une vue
  appelle aussi), `anarbib-drop-objet-chercher-dans-prosrc`,
  `anarbib-sql-suites-collision-locale`, `anarbib-migrations-avant-seed`.
- `docs/specs/REGISTRE_decisions.md` §37 `CONV` ; `docs/specs/spec-conventions-catalographiques.md` ;
  `docs/journal/audits/AUDIT_conventions_catalographiques_2026-08-20.md` ;
  `docs/journal/arbitrages/DECISIONS_bloc3_cinq_questions_2026-09-03.md` (C5, C9).
- `supabase/migrations/2026082113*_conventions_*` à `20260821200000` (la
  mécanique), `20260903150117` (le lot C5), `tests/sql/conv_*_tests.sql`.

## 6. Pièges vécus cette semaine

- Le hook pre-commit refuse un horodatage de migration à l'heure ronde :
  `date -u +%Y%m%d%H%M%S`, jamais de mémoire.
- Un `CREATE TABLE public.*` dans un test est bloqué par le hook : `TEMP`.
- Suites SQL en local : `supabase start` dans WSL, puis depuis
  `/mnt/c/Users/accat/Codeberg/anarbib` :
  `PGHOST=127.0.0.1 PGPORT=54322 SQL_SUITES_MANIFEST=<fichier> bash scripts/ci/run-sql-suites.sh`
  (les 273 migrations rejouent en ~2 min) ; `supabase stop` après. Une seule
  session à la fois (chemins `/tmp` fixes).
- La CLI masque les clés secrètes et la clé legacy est désactivée : écrire en
  production = MCP `execute_sql`, jamais un script avec une clé.
- Avant un `REVOKE` : lire `proacl`, chercher les vues appelantes, les trois
  formes d'assertion des suites.
- Un banc d'essai vert ne voit pas les grants : la production les éprouve
  (E11, 03/09).

## 7. Ce qui n'est pas à cette session

- Les **464 verdicts** du lot C5 : **faits** par Xavier le 03/09 (446 validés,
  18 écartés). Ce qui en reste pour cette session, c'est la **relecture des 227
  autorités créées** par l'application (casse, forme, doublons avec des fiches
  existantes sous une autre graphie, type) et les **secondes personnes** des 125
  chaînes multi-noms, restées sans autorité.
- Les trois assistances de saisie (C6) : autre chantier.
- Le thésaurus FICEDL (H1 clos) : hors périmètre.

---

## Amorce à coller au début de la nouvelle session

```
Reprends le cadrage docs/journal/cadrages/REPRISE_audit_autorites_en_profondeur_2026-09-03.md.
Commence par recompter le §2 en production (MCP execute_sql, lecture seule), rejoue les
requêtes de l'audit du 20/08, puis écris l'audit daté avant toute correction. Corrections
uniquement par lots de la file ou par migrations testées ; jamais d'UPDATE direct ; jamais
de validation en masse. Un commit par correction, vert en local.
```
