# Backlog AnarBib v34 — Réécriture intégrale sur état vérifié — outil de travail pour les collaboratrices et collaborateurs à venir

**2026-08-29** · mis à jour le **2026-09-08** · 86 items · Versão em português : `AnarBib-Backlog-2026-08-29-v34.pt-BR.md`

> Fichier **engendré** par `scripts/build-backlog.cjs` depuis `backlog-v34.json`. Ne le modifiez pas à la main.

---

## Sommaire

- [Pourquoi une réécriture](#pourquoi-une-réécriture)
- [Mode d'emploi](#mode-demploi)
- [L'état réel au 8 septembre 2026](#létat-réel-au-8-septembre-2026)
- [Écarts relevés entre le réel et l'écrit](#écarts-relevés-entre-le-réel-et-lécrit)
- [Le calendrier contraint](#le-calendrier-contraint)
- [Dix règles payées par un incident](#dix-règles-payées-par-un-incident)
- [Les chantiers](#les-chantiers)
    - [A — Soutenabilité collective](#a--soutenabilité-collective) · 4
    - [B — Base de données, sécurité, RLS](#b--base-de-données-sécurité-rls) · 6
    - [C — Catalogage et données documentaires](#c--catalogage-et-données-documentaires) · 9
    - [D — Périodiques, éphémères, ressources numériques](#d--périodiques-éphémères-ressources-numériques) · 4
    - [E — Front, OPAC, i18n, accessibilité](#e--front-opac-i18n-accessibilité) · 12
    - [F — Courriel et notifications](#f--courriel-et-notifications) · 7
    - [G — Réseau, gouvernance, fédération](#g--réseau-gouvernance-fédération) · 10
    - [H — Interopérabilité, thésaurus, moisson](#h--interopérabilité-thésaurus-moisson) · 7
    - [I — Auto-hébergement, exploitation, sauvegardes, CI](#i--auto-hébergement-exploitation-sauvegardes-ci) · 13
    - [J — Documentation et corpus](#j--documentation-et-corpus) · 5
    - [K — Caisse, communication, formation](#k--caisse-communication-formation) · 9
- [Clôtures et entrées caduques](#clôtures-et-entrées-caduques)
- [Ce qui n'est pas au backlog](#ce-qui-nest-pas-au-backlog)
- [Maintenance de ce document](#maintenance-de-ce-document)

---

## Pourquoi une réécriture

Ce document remplace le backlog v33 du 17 juin 2026. Le v33 portait un bandeau d'avertissement de fraîcheur ajouté le 28 août ; il ne suffisait plus.

Le v34 n'est pas une mise à jour du v33 : c'est une **réécriture sur état vérifié**. À sa rédaction, le 29 août 2026, chaque affirmation d'état a été relue contre deux sources primaires — la base de production interrogée en lecture seule, et le dépôt Codeberg au commit `1d00ed2c`. Aucun item n'a été reporté sur la foi d'un document. Entre le v33 et ce jour-là, 216 des 221 migrations alors appliquées avaient été écrites, ainsi que 655 commits.

**Ce paragraphe raconte une genèse, pas un état.** Les chiffres qui décrivent le présent vivent dans « L'état réel », relevé à part et daté ; celui-ci a été refait le 1er septembre 2026, et la moitié des valeurs du 29 août avaient bougé en trois jours. Confondre les deux est exactement l'erreur qui a rendu le v33 inutilisable.

Ce travail a produit un résultat qui commande la lecture de tout le reste : **la documentation se trompe dans les deux sens**. Elle déclare ouverts des chantiers livrés depuis des semaines, et elle déclare livrées des choses que personne n'a jamais exercées. La section « Écarts relevés » les nomme un par un.

---

## Mode d'emploi

**Ce document n'arbitre rien.** La préséance documentaire du projet reste celle de `docs/INDEX.md` : le `REGISTRE_decisions.md` fait foi, puis la spec du domaine, puis ce backlog. Si une ligne d'ici contredit le REGISTRE, c'est le REGISTRE qui a raison et cette ligne est un défaut à signaler.

**Pour commencer sans rien demander à personne**, lisez `docs/CHANTIERS_OUVERTS.md` : sept portes d'entrée qui ne demandent aucune coordination. Le présent backlog est ce qui vient après, quand on veut savoir ce qui reste et pourquoi.

**Avant de prendre un item, ouvrez un ticket sur Codeberg.** Deux personnes qui écrivent le même correctif, c'est une soirée perdue pour l'une des deux. C'est la seule règle de coordination du projet, et elle tient en une ligne.

**Chaque fiche dit six choses** : ce que c'est, l'état vérifié au 29/08, pourquoi ça compte, ce qui compte comme fini, ce que ça demande, et ce dont ça dépend. Si l'une manque, la fiche est incomplète — dites-le plutôt que de deviner.

**Les identifiants ne sont jamais réutilisés.** Un item soldé garde son numéro et passe à la section des clôtures. Les renvois entre crochets pointent vers le REGISTRE, une spec ou un identifiant hérité d'un backlog antérieur : ils permettent de retrouver la trace, ils ne font pas autorité par eux-mêmes.

---

## L'état réel au 8 septembre 2026

Relevé du **8 septembre 2026** à 1 h 30 — production interrogée en lecture seule et dépôt recompté au commit `e3a15243`. Il prolonge les relevés du 06 et du 07/09. Dans la nuit, la session voisine a livré **E5** : la dernière exception anti-pistage tombe, le fond de carte est un fichier PMTiles auto-hébergé dans le bucket public `map-tiles` (18 Go, planet Protomaps du 07/09, zoom 12), plus aucun appel du navigateur vers `tile.openstreetmap.org`, gardé par un test. Les volumétries métier n'ont pas bougé. Les lignes qui changent portent la date.

**Fraîcheur des constats au 2026-09-08.** **68 items sur 86** portent une vérification datée qui leur est propre (A1, A3, A4, B10, B13, B19, B20, B22, B23, C2, C3, C4, C7, C8, C9, C10, C11, D3, D6, E1, E2, E6, E9, E12, E14, E15, E16, E17, F1, F3, F4, F6, F7, F9, F10, G1, G6, G8, G10, G11, G12, G13, G14, H2, H9, H10, H11, H13, I1, I2, I3, I6, I12, I13, I15, I16, I18, I19, I21, J2, J3, J4, J9, K2, K5, K7, K9, K10). Les **18** autres reposent encore sur le relevé du 2026-08-29 et sont signalés comme tels sous chaque fiche. Un constat non revérifié n'est pas faux : il est seulement vieux, et la différence se voit ici plutôt qu'à l'usage. Cette ligne est recalculée à chaque engendrement du document.

### Base

| | | |
|---|---:|---|
| Tables `public` | **191** | toutes avec RLS activé, **332 policies** — +4 tables depuis le 03/09 (`work_titles`, `work_not_same`, `volume_group_dismissals`, `catalog_batch_reviews`), toutes classées au filet BG2 (191 sur 191 au rejeu local du 05/09). |
| Tables `ingest` | **10** | toutes avec RLS depuis le 29/08 au soir (item **B1**, soldé). Le schéma n'a jamais été exposé : ni `anon` ni `authenticated` n'y a `USAGE` |
| Vues `api` | **68** | **67 SECURITY INVOKER, 1 DEFINER** — contre 65/3 le 29/08 : deux vues de gouvernance sont repassées en invoker. `CREATE OR REPLACE VIEW` réinitialise cette option, et le T2 de `vues_api_definer_tests` la garde |
| Fonctions applicatives | **907** | `public` · `api` · `ingest` · `private` — +1 le 07/09 (les trois migrations du jour : H8, I20, et `api.thesaurus_export_v1` réécrite pour dire vers quelle liste pointe un alignement). Dont 694 SECURITY DEFINER au 06/09, toutes justifiées (audit 0029, complément du 06/09). **Aucune fonction sans `search_path` figé** : gardé par la suite `hygiene_search_path_et_initplan` depuis le 06/09. |
| Migrations appliquées | **314** | 314 migrations numérotées au dépôt = **314 appliquées, alignement exact** (vérifié le 08/09 à 1 h 30). La 314ᵉ, `20260907234500`, crée le bucket public `map-tiles` (E5) — **17 buckets** désormais, celui-ci **exclu du flux restic `storage`** à dessein : 18 Go reconstructibles en trente minutes depuis Protomaps (`scripts/maptiles/README.md`), il triplerait le dépôt. Cinq migrations le 07/09 avant elle (H8, I20, alignement FICEDL, E18 ×2). |
| Jobs `pg_cron` | **38** | actifs — +1 depuis le 03/09 (le tick de pré-traduction des titres d'œuvre, `work-titles-autofill`). |
| Avis de sécurité | **463** | 0 ERROR · **411** + **28** WARN sur les fonctions DEFINER exposées · 24 INFO « RLS sans policy » (liste attendue de `bootstrap.sh`, verdicts B4 posés). Le WARN `function_search_path_mutable` du matin est **parti** (`20260906111308`). Le 28 (`anon`) est la **valeur attendue** (T10, `DOC-GRANT-1`). **Le 411 (`authenticated`) est entièrement justifié depuis le 06/09** : 395 hérités des paquets du 01/09 et **16 RPC nées les 04–05/09, lues corps par corps** — « Complément du 06/09 » de `AUDIT_execute_authenticated_2026-09-01` : aucune faille, deux limites fonctionnelles (liste et rapport des lots transversaux au réseau ; `fn_batch_review_request` ne rapproche pas le lot de la bibliothèque de l'appelant·e). |
| Avis de performance | **440** | **368 « index inutilisés »** (403 le 03/09 — les compteurs repartent du redémarrage du 02/09 ; à relire dans un mois). **38 clés étrangères non indexées, toutes assumées et gardées** (`fk_sans_index_garde`). 25 tables à policies permissives multiples. **8 tables sans clé primaire** (14 le 03/09 : les six du schéma de mai sont parties avec lui). L'`auth_rls_initplan` du matin sur `catalog_batch_reviews_read_staff` est **résorbé** (`(select auth.uid())`, `20260906111308`) et la suite d'hygiène refuse désormais toute policy qui réévaluerait `auth.uid()` par ligne — le motif de **B5** est gardé, plus seulement corrigé. |
| Schémas de rebut | **1** | `conv_backup` seul — il porte les trois tables de revue humaine de C3 et **ne se purge pas**. `backup_2026_05_07` est parti le 04/09 au soir (B9, décision de Xavier après relecture des 50 lignes). |

### Fonctions Edge

| | | |
|---|---:|---|
| Dossiers au dépôt | **53** | + `_shared` ; **+1 depuis le 03/09 : `work-titles-autofill`** (pré-traduction des titres d'œuvre, « corrige-moi »). Dont le routeur `main`, jamais déployé sur Supabase, et c'est voulu. |
| Déclarations `verify_jwt` | **38** | **toutes à `false`** — compte des lignes `^verify_jwt = ` ; +1 depuis le 03/09 (`work-titles-autofill`, appelée par cron avec son secret). |

### Catalogue

| | | |
|---|---:|---|
| Notices | **2 656** | 2 758 exemplaires, **2 449 œuvres** (2 495 le 03/09 : 35 œuvres vides supprimées et des fusions — lot 1 de l'OPAC par œuvre), **1 505 autorités** (1 532 le 03/09 : 17 fusions du lot C5 et les doublons exacts du 03/09), **3 497 titres d'œuvre** dans `work_titles` (pré-traduits, « corrige-moi », 1 452 à relire — C11). Trois notices de moins : les fusions d'éditions. 0 proposition sur une œuvre encore : l'atelier des œuvres est ouvert depuis le 05/09 au soir, jamais emprunté (G1). |
| Brouillons de catalogage | **2 250** | deux états ce matin : `draft` 1 820, `published` 430 — l'état `cancelled` vu le 03/09 n'a plus d'occurrence (corbeille vidée). **Aucune révision de lot encore** (`catalog_batch_reviews` vide) : la garde « un lot importé se publie après révision » est en place depuis le 05/09, jamais exercée. |
| Indexation matière | **1 184 / 2 656** | notices avec au moins un sujet — **1 472 sans aucun** (1 537 le 03/09 : les « Assuntos importados » de MLEG devenus matières quand le thésaurus les avait, 04/09 soir). Reste l'objet de **C7**. |
| Thésaurus FICEDL | **621** | termes, **10 locales complètes**, 159 dates (1868-2027) depuis le 03/09 (H1), onglet « Dates » en ligne. 98 alignements vers les sujets locaux, intacts. |
| Périodiques | **4** | titres, 7 fascicules rattachés. Leur **arbitrage de doublons** est ouvert à tout rôle `librarian` alors que celui des livres est réservé à la coordination : écart mesuré le 01/09, décidé, en attente de préavis |

### Réseau

| | | |
|---|---:|---|
| Bibliothèques | **4** | `blmf` 248 · `btl` 2 187 · `mleg` 269 · `blmf-teste` 5. **`cira-marseille` a été retirée du réseau** — suppression volontaire confirmée par la coordination le 01/09, tracée dans `NOTE_retrait_cira_marseille_2026-09-01`. Cascade propre (0 fonds, 0 orphelin) ; thème conservé en storage, source d'import close |
| Comptes | **19** | **23** appartenances actives — inchangé depuis le 03/09 (Emma, Errico et Voltairine de Teste sur `blmf-teste` pour la formation du 08/09). **0 contributeur·rice réseau** : le circuit « contributeur » de l'atelier n'a jamais été emprunté (G1). |
| Administrateur·rices réseau | **1** | **c'est l'item A1, et il commande tout le reste** |
| Circulation vivante | **6 / 19 / 22 / 0** | emprunts / réservations / consultations / PEB ouverts — inchangé depuis le 03/09. Deux PEB de mai 2026 (n° 24 et 25, rendus, `devolvido`) restent en base comme historique ; le 03/09 ne comptait que les ouverts, cette ligne aussi. Dernière écriture d'emprunt le 31/08. |

### Dépôt

| | | |
|---|---:|---|
| Commits | **2 634** | sur `main`, au 08/09 à 1 h 30 — 40 commits depuis le relevé du 06/09, de deux sessions ; les deux derniers (00 h 10 et 01 h 21) sont E5 et son correctif de greffon (`theme`, pas `flavor`). |
| Fichiers `src/` | **314** | 81 pages, 93 composants ; +2 cette nuit : `src/lib/mapTiles.js` (adresse du PMTiles, zooms, langue des étiquettes) et le test `carte-sans-domaine-tiers`. Les trois composants de carte lisent `mapTiles.js` au lieu de `tile.openstreetmap.org`. |
| Clés i18n | **6 571** | par locale, **parité stricte sur les 10**, gardée en CI ; +1 ce soir (la phrase liminaire `privacy.register`) ; onze clés grecques provisoires et cinq locales où « Organization or collective » dormait en anglais, corrigées (audit des diacritiques et de l'anglais résiduel du 07/09). |
| Tests | **457 + 98** | 457 tests JS (vitest, gate bloquant ; +5 cette nuit : `carte-sans-domaine-tiers`, qui refuse toute citation de `tile.openstreetmap.org` dans `src/` et vérifie l'empreinte du greffon vendorisé) + **98 suites SQL** dans `ci-suites.txt` (le stub `storage` de la CI précharge désormais `map-tiles`). CI verte sur chaque push. |
| Marqueurs de dette | **21** | dont 4 dans `src/` (motifs `TODO`/`FIXME`, casse exacte ; 17 le 03/09 — les quatre de plus sont hors `src/`, dans le code du 05/09). Aucun n'est une tâche ouverte : la dette nommée vit au backlog, pas dans le code. |

---

## Écarts relevés entre le réel et l'écrit

Voici pourquoi le v33 ne pouvait plus servir. **Cette table est un relevé du 29 août 2026 et le reste** : c'est le compte rendu d'une comparaison faite ce jour-là, pas un état courant. Plusieurs de ces écarts ont été soldés depuis (`ingest` sous RLS, périodiques livrés, crons réactivés, vues remises en invoker), et les items concernés le disent dans leur propre fiche. On ne réécrit pas ce tableau à chaque relevé : le réécrire effacerait ce qu'il démontre.

Ces écarts ne sont pas des négligences : ils sont la trace normale d'un projet qui a livré 655 commits pendant que ses documents de pilotage restaient figés. Ce qui compte n'est pas de les déplorer, c'est de savoir qu'ils vont **dans les deux sens** — et donc qu'un document non revérifié peut aussi bien faire perdre du temps à refaire l'existant qu'à croire acquis ce qui ne l'est pas.

### Déclaré ouvert, en réalité livré

**Les six migrations de conventions catalographiques**

- *Ce que dit la documentation* — « écrites, jamais appliquées » — `REPRISE_claude_code_conventions_2026-08-20`
- *Ce que dit la base ou le dépôt* — **19 migrations `conventions_00` à `conventions_17` appliquées le 21/08**, soit bien au-delà des six annoncées. Le chantier a été mené presque entièrement.

**La collégialité de promotion à coordenador·a**

- *Ce que dit la documentation* — « écrite, testée hors production, non appliquée » + runbook de déploiement en 11 étapes
- *Ce que dit la base ou le dépôt* — `20260826120000_team_coordenador_collegial_promotion` **est en production**. Le runbook de déploiement est caduc ; la répétition sur `blmf-teste` reste à faire (item **G3**).

**Les périodiques**

- *Ce que dit la documentation* — « spec cadrée, non implémentée — neuf paquets à livrer » — `spec-periodiques-v0.1`, 27/08
- *Ce que dit la base ou le dépôt* — **P1 à P9 livrés en 24 heures les 27-28/08** : table `serials`, RPC, anti-faux-doublons, état de collection, Atelier, reprise, UI de catalogage, page publique, dix langues. La spec était périmée le lendemain de sa rédaction.

**Altcha — AR-3 et AR-4**

- *Ce que dit la documentation* — « 🔴 à mettre en œuvre » et « condition de mise en service, non négociable » — `DECISION_anti_robots_2026-08-20`
- *Ce que dit la base ou le dépôt* — Fonction `altcha-challenge` déployée le 19/08, migration `20260820180000_altcha_anti_rejeu` appliquée le 20/08. Les deux sont faits.

**Le plafond des PDF, le vocabulaire des droits, `api.resolve_reader_card`**

- *Ce que dit la documentation* — trois items ouverts dans `PLAN_DE_MARCHE` et `PLAN_formation_BLMF`
- *Ce que dit la base ou le dépôt* — `plafond_pdf_500mo_recueils_illustres`, `vocabulaire_rights_status` et `resolve_reader_card_motif_neutre` sont appliquées depuis les 20 et 21/08. Les trois lignes sont caduques.

**Les crons prétendus inactifs**

- *Ce que dit la documentation* — « crons RGPD #6/#7 désactivés — clarifier » et « trois crons inactifs à trancher par la coordination »
- *Ce que dit la base ou le dépôt* — **Les 36 jobs sont actifs.** `20260821070000_reactiver_crons_gouvernance` et `20260827080000_activer_cron_request_eval_digest` ont soldé la question. Aucune décision de coordination n'est due.

**Le doublon `login` / `login-with-identifier` et la double signature de `fn_v2_set_reserva_linhas_workflow`**

- *Ce que dit la documentation* — deux entrées de dette technique reconduites de backlog en backlog
- *Ce que dit la base ou le dépôt* — `login-with-identifier` **n'existe pas**. `fn_v2_set_reserva_linhas_workflow` n'a **qu'une seule signature**. Plus largement : il n'existe **aucun doublon de signature** dans les quatre schémas applicatifs. Les deux entrées sont caduques.

**Les tables `_backup_*_20260408`**

- *Ce que dit la documentation* — « nettoyer 3 tables `_backup_*_20260408` + `book_authors_backup_suspect_mono` »
- *Ce que dit la base ou le dépôt* — Aucune n'existe dans `public`. En revanche **`backup_2026_05_07` (6 tables vides) est toujours là**, alors que `BG2-9` prescrit sa purge depuis juin (item **B9**).

### Déclaré livré, jamais exercé

**Sept blocs fonctionnels entiers**

- *Ce que dit la documentation* — livrés, déployés, cochés ✅ au REGISTRE et aux specs
- *Ce que dit la base ou le dépôt* — **62 tables métier n'ont jamais reçu la moindre insertion.** Assemblées du réseau (3 tables), notes de lecture (2), propositions d'autorités (3), référentiels de catalogage `catalog_ref_*` (8 sur 9), gouvernance des profils de bibliothèque (4 — alors que **deux crons tournent dessus**), délibération sur les demandes d'adhésion (5). Le code existe ; l'usage n'existe pas. C'est l'item **G1**.

**Le circuit d'invitation d'équipe**

- *Ce que dit la documentation* — livré : lots 1, 2, 3a, 3b + fonction `notify-library-invitation` en dix langues
- *Ce que dit la base ou le dépôt* — `library_team_invitations` : **0 ligne**, une seule insertion historique. Le réglage `team_admission_mode = 'cosignature'` de la BLMF n'a jamais eu d'effet sur quoi que ce soit. Or la migration de collégialité fait de ce circuit jamais exercé **le chemin critique** de toute promotion.

**L'accessibilité**

- *Ce que dit la documentation* — panneau de réglages livré sur toutes les pages, `html lang` conforme WCAG 3.1.1
- *Ce que dit la base ou le dépôt* — Des fonctionnalités d'accessibilité sont implémentées. **Aucun audit d'accessibilité indépendant n'a jamais été mené.** Dire l'un sans l'autre serait une faute (item **E1**).

**La moisson OAI-PMH**

- *Ce que dit la documentation* — chemin exécutable, fonction `harvest-oai-pmh` déployée, cron hebdomadaire posé
- *Ce que dit la base ou le dépôt* — Le cron `anarbib-oai-harvest-weekly` **n'a jamais tourné** (première occurrence : mardi 04h20). `oai_harvest_state` : 9 insertions, 0 ligne vivante. Le point d'accès OAI n'a jamais été moissonné de l'extérieur non plus.

**Aucune suite de tests ne savait simuler un appel anonyme**

- *Ce que dit la documentation* — des dizaines de tests annoncent « rejet `auth` (28000) : appel anonyme » et passaient au vert
- *Ce que dit la base ou le dépôt* — `set_config('request.jwt.claims', NULL)` ne met pas NULL mais la chaîne vide, et les helpers `auth.uid()`, `auth.role()`, `auth.email()` du stub de CI castaient en `jsonb` **avant** de la neutraliser : `''::jsonb` levait une erreur de syntaxe là où la vraie fonction Supabase renvoie NULL. Les tests éprouvaient donc un plantage du banc d'essai, et leur garde-fou (`SQLERRM LIKE '%uthenticat%'`) ne pouvait pas correspondre. `auth.jwt()`, quatre lignes plus bas, avait la forme correcte depuis toujours. **Corrigé le 29/08.** Le harnais passe au vert de bout en bout depuis le 29/08 au soir, sur 45 suites.

### Chiffre ou affirmation faux

**Les chiffres de `CLAUDE.md`**

- *Ce que dit la documentation* — 200 migrations · 48 fonctions Edge · 6 154 clés i18n · 36 déclarations `verify_jwt` dont 5 à `true` · `i18n.test.js` couvre 8 locales · 492 fonctions DEFINER
- *Ce que dit la base ou le dépôt* — 221 · 49 dossiers pour 48 déployées · 6 177 · **31 déclarations, toutes à `false`, aucune à `true`** · **10 locales** depuis le 27/08 · 664. Le plus grave est la ligne `verify_jwt` : elle décrit une protection qui n'existe pas.

**Le nombre de migrations, à travers le corpus**

- *Ce que dit la documentation* — 309 (10/06) → 128 (20/08) → 146 (`ETAT-AVANCEMENT`) → 221 (28/08)
- *Ce que dit la base ou le dépôt* — **221 appliquées, 224 fichiers.** La série documentaire n'est pas monotone : le chiffre du 10 juin est supérieur à ceux de deux relevés postérieurs. Ne jamais reprendre un compte de migrations depuis un document.

**`deploy/README.md`**

- *Ce que dit la documentation* — « Ce document décrit un état à atteindre, pas un état atteint. **Rien de tout ceci n'a encore tourné.** »
- *Ce que dit la base ou le dépôt* — Trois commits du 26/08 décrivent des exécutions réelles de `bootstrap.sh`, avec huit défauts relevés et corrigés. Le README est en retard sur ses propres commits voisins (item **I8**).

**`spec-flux-consultations-v2.2` et `spec-gouvernance-roles` §14**

- *Ce que dit la documentation* — l'une affirme trois profils de bibliothèque « vérifiés en prod » ; l'autre liste comme « à implémenter » l'audit, les colonnes de carence, les mails `team.*` et deux crons
- *Ce que dit la base ou le dépôt* — La première est **fausse** (`BLT-test` n'existe pas, la BTL est en `full_sigb`) ; la seconde **sous-estime** ce qui tourne. Deux dérives de sens inverse, relevées le même jour (items **J3** et **J4**).

**Des identifiants de comptes réels servaient de fixtures de test**

- *Ce que dit la documentation* — `tests/sql/README.md` les présentait comme des personas — « Xavier », « Lívia », « Arthur », « Patricia »
- *Ce que dit la base ou le dépôt* — Le même README les datait : « UUIDs BLMF, **vérifiés le 11/05/2026** ». Ils avaient été relevés en base réelle, et **trois des quatre correspondaient à des lignes existantes en production**. Les prénoms, eux, étaient fictifs — ce qui est le vrai piège : une étiquette inventée sur une ligne réelle éteint la vigilance au lieu de l'appeler. Les suites tournent en `BEGIN/ROLLBACK` sur une base jetable, donc rien n'est arrivé, mais la convention qui rendait cela sûr n'était écrite nulle part. **Corrigé le 29/08** — 89 remplacements sur 12 fichiers, personas synthétiques fournies par le seed. La règle est mécanique depuis la nuit du 29/08 : sixième règle bloquante du hook, liste blanche lue dans le seed, doctrine `DOC-FIXT-1` (item **I14**, soldé).

### Jamais écrit nulle part

**Le schéma `ingest` n'avait pas de RLS — mais il n'était pas ouvert pour autant**

- *Ce que dit la documentation* — rien — aucun document du corpus ne mentionne l'état RLS de `ingest`
- *Ce que dit la base ou le dépôt* — **8 des 10 tables du schéma `ingest` n'avaient pas RLS activé**, dont `partner_catalog_staging_rows` (2 172 lignes) et `partner_catalog_row_to_draft` (2 084) — des données de bibliothèques tierces. Le discours « 0 table sans RLS » est vrai pour `public` et ne l'a jamais été pour la base entière. **Mais la vérification des droits, faite ensuite, a corrigé le diagnostic** : `anon` et `authenticated` n'ont même pas `USAGE` sur ce schéma, et aucune de ses tables ne leur accorde quoi que ce soit. Rien n'était atteignable. C'est une leçon sur la méthode autant que sur la sécurité : l'absence de RLS ne dit rien à elle seule, il faut lire les droits avec. Soldé le 29/08 (item **B1**) comme second verrou — la fermeture ne tient plus au seul fait qu'aucun GRANT n'a été posé.

**Les 35 sujets Solidaires sont en base, leur migration ne l'est pas**

- *Ce que dit la documentation* — « jouer `20260828_sujets_solidaires_ficedl.sql` et vérifier 35 sujets + 44 liens » — chantier annoncé à faire
- *Ce que dit la base ou le dépôt* — **35 sujets ont été créés en base le 27/08** et les alignements sont passés de 51 à 98. Mais le fichier vit toujours dans `docs/drafts/`, hors de `supabase/migrations/`. Une instance neuve n'aura donc pas ces sujets. Item **C1**.

**La table la plus volumineuse de la base est la table de supervision**

- *Ce que dit la documentation* — rien
- *Ce que dit la base ou le dépôt* — `service_health_probes` : **13 932 lignes**, +288 par jour, sans aucun cron de purge — alors que sept autres purges existent. Item **I6**.

**Sept vues du schéma `api` sont en SECURITY DEFINER**

- *Ce que dit la documentation* — le hook `pre-commit` interdit pourtant toute `CREATE VIEW` sans `security_invoker = true`
- *Ce que dit la base ou le dépôt* — Sept vues antérieures au hook y échappaient : `collective_removal_proposals_current_v1`, `cooptation_proposals_current_v1`, `gazette_issues_public_v1`, `gazette_locales_public_v1`, `lettre_locales_public_v1`, `lettre_public_v1`, `library_email_identity`. **Soldé le 29/08** (item **B3**) : quatre passées en `security_invoker`, les deux vues de gouvernance gardées hors policies mais dotées dans la vue de la clause de visibilité reprise de la policy des tables de base, la septième accordée à aucun rôle applicatif. Le hook ne couvrait que `CREATE VIEW` : il couvre désormais aussi `CREATE OR REPLACE VIEW`, et une suite refuse toute vue nouvelle hors des deux dérogations nommées.

---

## Le calendrier contraint

Trois dates gouvernent la fenêtre en cours, et deux d'entre elles sont des gels. Elles ne sont pas négociables au coup par coup : elles ont été posées parce qu'une démonstration publique tourne sur la production.

| Date | Ce qui s'applique |
|---|---|
| **jusqu'au 14/09/2026** | Gel de la chaîne de bascule auto-hébergée **sur la production**. Hors périmètre nommément : alignement de l'image GoTrue, première exécution de `bootstrap.sh`, découplage de la CI, proxy inverse et tunnel, toute modification de `deploy/compose.yml` et du `Caddyfile`. Le travail en environnement d'essai reste entièrement ouvert. |
| **à partir du 08/09/2026** | Plus aucune modification du code en production. |
| **11-13/09/2026** | FICEDL Bologne. Atelier AnarBib le 12 au matin, assemblée ouverte le 13. |
| **à partir du 14/09/2026** | Dégel. Le domaine I redevient le chantier principal. |

Un item marqué **gelé** n'est pas un item mort : c'est un item dont la date de reprise est écrite.

---

## Dix règles payées par un incident

Ces règles ne sont pas des préférences. Chacune a été payée par un incident dont la trace existe dans `docs/journal/`.

1. **Le seul chemin de déploiement est `git push` → intégration continue.** Jamais `apply_migration` par MCP, jamais l'éditeur SQL, jamais la CLI en direct. Une migration appliquée à la main casse la CI pour tout le monde : `supabase db push` refuse dès qu'il voit une version absente du dépôt. *(REGISTRE `DOC-DEPLOY-1` et `-3`)*
2. **Ne jamais mélanger documentation et code dans un même push.** Le 26/08, un push mixte n'a déclenché aucun workflow et une migration n'a pas été appliquée, **sans aucun rouge**. Vérifier en base après tout push censé appliquer une migration. *(REGISTRE `GOUV-9`)*
3. **Toute migration qui crée une table dans `public` casse la sauvegarde suivante** tant que la table n'est pas inscrite dans `deploy/bg2-known-tables.txt`. La migration et les fichiers d'exploitation bougent ensemble. L'échec est silencieux : `altcha_consumed_challenges` a fait échouer toutes les sauvegardes pendant 36 heures.
4. **Livrer des correctifs complets éprouvés sur un clone propre, ou des fichiers entiers.** Jamais « remplacez la ligne 42 ».
5. **Dix locales en une seule passe.** Une clé ajoutée dans une seule langue casse le build, et c'est voulu. *(REGISTRE `DOC-I18N-1`)*
6. **Jamais de secret au dépôt.** `deploy/.env` et `deploy/functions.env` sont ignorés par git ; la `SERVICE_ROLE_KEY` n'a sa place ni au dépôt, ni au front, ni dans un message.
7. **Le runner d'intégration continue vit sur la machine du mainteneur.** Machine éteinte, rien ne se déploie. Ce n'est pas une panne, c'est l'état du projet — et c'est l'item **A3**.
8. **Avant toute séance, récupérer l'état du dépôt distant.** Le 28/08, un clone en retard de 26 commits a produit la conclusion fausse que onze migrations tournaient en production sans exister au dépôt.
9. **Trois familles de tâches ne s'automatisent pas** : les trois tables de revue du schéma `conv_backup`, la revue des doubles patronymes hispaniques (14 % de faux positifs mesurés), et le tri des sous-titres et diacritiques. Toute proposition de les mécaniser est une régression documentaire.
10. **Avant d'inscrire une lacune, chercher la source qui l'infirme.** Sur sept erreurs analysées dans `PLAN_DE_MARCHE`, quatre venaient d'une source non lue.

---

## Les chantiers

**Identifiant** = lettre de domaine + numéro. Les numéros ne sont jamais réutilisés. **Priorité** : `P0` Structurel · `P1` Prioritaire · `P2` Courant · `P3` Différé.

- `P0` **Structurel** — Le projet reste fragile tant que ce n'est pas fait. Aucun code ne le remplace.
- `P1` **Prioritaire** — Corrige un défaut réel, ou débloque plusieurs autres chantiers.
- `P2` **Courant** — Utile, non bloquant, à prendre quand un créneau se libère.
- `P3` **Différé** — Différé volontairement, avec la raison écrite. Ne pas le reprendre sans rouvrir la raison.

### A — Soutenabilité collective

*Ce que ni le code ni une seule personne ne régleront. Ce domaine passe avant tous les autres.*

| | | | |
|---|---|---|---|
| **A1** | Obtenir au moins deux autres administrateur·rices réseau | `P0` | Décision collective |
| **A2** | Éprouver la reconstruction complète par quelqu'un d'autre que le mainteneur | `P0` | Ouvert |
| **A3** | Sortir le runner d'intégration continue de la machine du mainteneur | `P0` | Ouvert |
| **A4** | Accueillir une contribution extérieure sans la perdre ni s'y noyer | `P1` | En cours |

#### A1 — Obtenir au moins deux autres administrateur·rices réseau

`P0` Structurel · État : **Décision collective** · Charge : non chiffré · Ce que ça demande : délibération collective, aucune compétence technique

**État.** Vérifié en base le 29/08 : le réseau compte **un seul administrateur**. Les tables `network_administrators`, `network_administrator_cooptation_proposals` et `network_administrator_cooptation_votes` sont vides après quelques insertions historiques.

*Vérifié : 31/08 — `network_administrators` : 1 ligne. Rien n'a bougé.*

**Ce que c'est.** Trouver et coopter deux personnes de plus, dans deux collectifs différents, disposées à porter les décisions fédérales : admission d'une bibliothèque, arbitrage entre bibliothèques, ouverture de la moisson.

**Pourquoi ça compte.** C'est l'item qui commande tous les autres. Des décisions fédérales sont **volontairement différées** faute de pouvoir être prises à plusieurs — l'admission de la Bibliothèque SOLIDAIRES au premier chef. Tant qu'il n'y a qu'une personne, le mécanisme de cooptation reste un dispositif sans usage, et le réseau reste suspendu à quelqu'un qui peut tomber malade.

**Ce qui compte comme fini.**

- Deux personnes supplémentaires portent le rôle `network_administrator` en base.
- Une décision fédérale a été prise à trois de bout en bout, avec sa trace dans `network_administrator_audit`.
- Le circuit de cooptation a été emprunté au moins une fois : proposition, délai, ratification.

**Dépendances.** Bloque **G7** (décision sur SOLIDAIRES) et conditionne **A2**.

*Renvois : `docs/CHANTIERS_OUVERTS.md §7` · `REGISTRE §1 RES-D11` · `CALENDRIER_bologne_2026-08-27`*

#### A2 — Éprouver la reconstruction complète par quelqu'un d'autre que le mainteneur

`P0` Structurel · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : administration système, SQL / PostgreSQL, React / JavaScript

**État.** Jamais fait. `deploy/README.md`, `deploy/REPETITION.md` et `deploy/bootstrap.sh` existent et ont été exécutés — **sur la seule machine du mainteneur**.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Cloner le dépôt sur une machine tierce, monter la pile complète en suivant `deploy/README.md`, et écrire ce qui casse. Aucun secret, aucun accès, aucune coordination : la pile se rebâtit depuis le dépôt seul. Docker, une machine, une soirée.

**Pourquoi ça compte.** C'est la réponse à la seule question qui décide de tout le reste : *ce projet est-il reprenable par quelqu'un d'autre que celui qui l'a écrit ?* Un rapport d'échec détaillé vaut ici plus qu'un correctif : c'est la liste de ce qui ne marche que sur une seule machine.

**Ce qui compte comme fini.**

- La pile démarre sur une machine qui n'a jamais vu le projet, en suivant la documentation seule.
- Chaque écart entre la documentation et la réalité est consigné, avec sa commande et son message d'erreur.
- Le journal d'exécution devient une section de `deploy/README.md`.

**Dépendances.** Aucune. **C'est le meilleur premier pas pour quelqu'un qui arrive.**

*Renvois : `docs/CHANTIERS_OUVERTS.md §1` · `deploy/REPETITION.md`*

#### A3 — Sortir le runner d'intégration continue de la machine du mainteneur

`P0` Structurel · État : **Ouvert** · Charge : plusieurs semaines · Ce que ça demande : administration système

**État.** `.forgejo/workflows/ci.yml` et `sql-tests.yml` portent tous deux `runs-on: anarbib-local` — un `act_runner` auto-hébergé sur le WSL2 du mainteneur. Machine éteinte, **rien ne se déploie**, et l'échec est parfois silencieux.

*Vérifié : 31/08 — 7 occurrences de `runs-on: anarbib-local` dans `.forgejo/workflows/`. Rien n'a bougé.*

**Ce que c'est.** Faire tourner le runner ailleurs que sur un poste de travail personnel : machine de l'hébergeur, seconde machine du réseau, ou runner partagé. La logique de déploiement est déjà extraite dans `scripts/ci/deployer-backend.sh` et rejouable à la main — la moitié du travail est faite.

**Pourquoi ça compte.** Tant que le runner est unique et personnel, aucune procédure ne peut rendre le déploiement fiable, et personne d'autre ne peut fusionner une contribution. C'est la seconde moitié de la dépendance à une seule personne, après **A1**.

**Ce qui compte comme fini.**

- Un push sur `main` déclenche un déploiement sans que la machine du mainteneur soit allumée.
- Le garde-fou d'exclusion du routeur `main` est préservé aux deux endroits (workflow et script).
- La procédure de remise en route du runner est écrite pour quelqu'un qui ne l'a pas installé.

**Dépendances.** Lié à **I2** (bascule auto-hébergée). Peut se faire avant, sur l'infrastructure actuelle.

*Renvois : `CLAUDE.md, piège connu n°1` · `REPRISE_bascule_autohebergee_2026-08-26`*

#### A4 — Accueillir une contribution extérieure sans la perdre ni s'y noyer

`P1` Prioritaire · État : **En cours** · Charge : une soirée · Ce que ça demande : délibération collective, aucune compétence technique

**État.** Le 06/09, la première contribution extérieure (Bastien, `ASR2026`) a produit en un après-midi trois PR sur deux dépôts, cinq réécritures d'historique et 46 fichiers touchés, dont du code de production. Aucune règle écrite ne dit ce qu'une PR peut contenir, si l'historique peut être réécrit pendant une relecture, ni comment on scinde. Le mainteneur a répondu le soir même, par un commentaire long ; sans règle, la prochaine contribution rejouera la même scène. **Tranché le 06/09 au soir (Xavier) : A** — les trois règles et la contrepartie du mainteneur sont écrites dans `CONTRIBUTING.md` (fr et en, les deux langues du fichier) le soir même (`DOC-CONTRIB-1` ✅). Reste : la PR #28 scindée selon ces règles.

*Vérifié : 06/09 — PR #28 relue en entier (46 fichiers, tête `b5782ec1`), production interrogée en lecture seule, constat `CONSTAT_PR28_rejeu_vs_production_revoke_anon_2026-09-06`.*

**Ce que c'est.** Écrire dans `CONTRIBUTING.md` trois règles courtes : une PR = un sujet ; le code déployé en production (frontend, Edge Functions) va dans une PR distincte de l'outillage ; pendant une relecture, on ajoute des commits, on ne force-pousse pas. Et dire ce que le mainteneur promet en retour : un premier retour sous une semaine.

**Pourquoi ça compte.** Un projet à un mainteneur ne survit à ses contributeurs que s'il dit à l'avance ce qu'il peut relire. Une règle écrite protège la contribution autant que le projet : elle évite qu'un travail sincère finisse refusé en bloc parce qu'il était impossible à lire.

**Ce qui compte comme fini.**

- `CONTRIBUTING.md` porte les trois règles, en français, portugais et anglais.
- La PR #28 a été scindée selon ces règles, ou fusionnée en connaissance de cause.

**Dépendances.** Décision du mainteneur ; question posée dans `journal/arbitrages/QUESTIONS_pr28_contribution_exterieure_2026-09-06.md` (Q4). REGISTRE `DOC-CONTRIB-1` (ouvert).

*Renvois : `CONTRIBUTING.md` · `REGISTRE §0 DOC-CONTRIB-1` · `journal/arbitrages/QUESTIONS_pr28_contribution_exterieure_2026-09-06` · `codeberg.org/anarbib/anarbib/pulls/28`*

---

### B — Base de données, sécurité, RLS

*191 tables, 694 fonctions SECURITY DEFINER, 332 policies (relevé du 06/09). La surface la plus large du projet.*

| | | | |
|---|---|---|---|
| **B10** | Hygiène de performance : 170 index inutilisés, 38 clés étrangères non indexées, 24 policies permissives en double | `P3` | Ouvert |
| **B13** | Décider du sort des 221 migrations : squash ou pas | `P3` | Ouvert |
| **B19** | Révoquer l'ancienne clé de signature HS256 — le bouton qui déconnecterait tout le monde | `P2` | Gelé |
| **B20** | Le repli sur la clé legacy ne doit pas pouvoir revenir : une garde, pas un commentaire | `P1` | Ouvert |
| **B22** | Quarante-sept fonctions ouvertes à anon sans qu'aucune ligne du dépôt ne le dise | `P2` | Ouvert |
| **B23** | `api.library_email_identity` est la seule vue `api` encore en SECURITY DEFINER — le dire, ou la basculer | `P3` | Ouvert |

#### B10 — Hygiène de performance : 170 index inutilisés, 38 clés étrangères non indexées, 24 policies permissives en double

`P3` Différé · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : SQL / PostgreSQL

**État.** 256 avis de performance au 29/08. Les tables les plus chargées en index inutilisés sont `library_partnerships` (6), `books` (5), `membership_payments` (4). Les 24 policies permissives en double portent toutes sur le rôle `authenticated` en `SELECT`, sur des tables centrales (`books`, `authors`, `exemplares`, `subjects`, `works`).

**Requalifié par la mesure (GLB v17 ch. 8.1, contre-vérifiée le 02/09).** Le volet clés étrangères avait été « soldé » le 02/07 (151 → 15) ; il est à **38** (32 `public` + 6 `ingest`) huit semaines plus tard, par le fonctionnement normal du projet et sans qu'aucune faute soit commise — chaque table de qualité catalographique apporte ses colonnes d'acteur, chaque colonne d'acteur sa FK non indexée. La campagne reste différée à raison ; **le garde qui l'empêche de se rouvrir est extrait en B21** et, lui, n'attend pas la volumétrie.

*Vérifié : 31/08 — 254 avis : 167 index inutilisés, 38 clés étrangères non indexées, **25** tables en policies permissives en double (`book_reading_notes` s'y est ajoutée avec les notes de lecture), 14 tables sans clé primaire, 1 avis de connexions.*

**Ce que c'est.** Trois passes distinctes, à ne pas mélanger : fusionner les paires de policies permissives ; indexer les clés étrangères qui servent réellement ; ne supprimer un index inutilisé que si l'on comprend pourquoi il avait été créé.

**Pourquoi ça compte.** À la volumétrie actuelle — 2 676 notices, 16 comptes — **rien de ceci ne se voit**. C'est un chantier de pré-montée en charge, différé à dessein depuis juillet. Le noter permet de ne pas le redécouvrir en urgence le jour où une bibliothèque arrive avec 100 000 notices.

**Ce qui compte comme fini.**

- Les 24 avis de policies en double sont résorbés — c'est la passe la plus rentable.
- Les clés étrangères des tables réellement écrites sont indexées.
- Les index supprimés le sont avec la raison écrite.

**Dépendances.** À reprendre si une bibliothèque à gros fonds rejoint le réseau.

*Renvois : `ETAT-lancement-consolide-2026-07-03 §2 item 7` · `Advisors performance du 29/08/2026`*

#### B13 — Décider du sort des 221 migrations : squash ou pas

`P3` Différé · État : **Ouvert** · Charge : plusieurs semaines · Ce que ça demande : SQL / PostgreSQL, administration système

**État.** 221 migrations appliquées, dont la première est un `baseline_live` de **2,4 Mo** — le plus gros fichier du dépôt. Le squash est marqué « décidé, non commencé » depuis le 20/08, à une époque où le compte était de 146.

*Vérifié : 31/08 — 243 migrations appliquées : vingt-deux de plus qu'au 29/08. L'argument du squash grossit tout seul.*

**Ce que c'est.** Soit reconstruire un `baseline` à partir du schéma courant et archiver les migrations antérieures, soit assumer la chaîne longue et documenter pourquoi. Le rejeu complet prend aujourd'hui environ 25 minutes, mesuré.

**Pourquoi ça compte.** Le risque du squash est entier : il réécrit la seule trace ordonnée de ce qui a été fait, et le harnais de tests SQL rejoue toute la chaîne à chaque fois. Ne pas le faire coûte du temps de CI ; le faire mal coûte la capacité à reconstruire. **Ne pas s'y engager avant que A2 ait réussi au moins une fois.**

**Ce qui compte comme fini.**

- Une décision écrite au REGISTRE, dans un sens ou dans l'autre.
- Si squash : la reconstruction depuis le nouveau baseline a été éprouvée sur une machine tierce.

**Dépendances.** **Bloqué par A2.** Ne pas commencer avant.

*Renvois : `ETAT-AVANCEMENT-multisessions` · `docs/schema/baseline_schema_2026-06-11.sql`*

#### B19 — Révoquer l'ancienne clé de signature HS256 — le bouton qui déconnecterait tout le monde

`P2` Courant · État : **Gelé** · Charge : une soirée · Ce que ça demande : administration système

**État.** Les clés de signature JWT sont migrées : la clé courante est une ECC P-256, l'ancienne HS256 est rangée en « Previously used keys » et ne fait plus que vérifier. Le dashboard affiche à côté d'elle un bouton Revoke et un texte qui invite gentiment à cliquer « une fois les jetons expirés ». Or cette clé valide encore la clé anon legacy qu'envoient les navigateurs au bundle en cache — 2 026 requêtes par jour au relevé du 01/09.

*Vérifié : 01/09 — page Settings → JWT Keys lue : ECC P-256 courante, HS256 en « previously used », dernière rotation il y a 5 mois.*

**Ce que c'est.** Rien avant que B18 soit terminé et digéré. Ensuite seulement : vérifier qu'aucun jeton ni URL signée de longue durée ne dépend encore de la HS256, puis révoquer. Item gelé exprès pour que personne ne « range » ce bouton en passant.

**Pourquoi ça compte.** C'est le seul geste réellement irréversible de tout le chantier des clés, et il est à un clic d'un écran qu'on visite pour d'autres raisons. Révoquée trop tôt, la HS256 invalide d'un coup tout ce qu'elle validait encore : la déconnexion serait générale et immédiate.

**Ce qui compte comme fini.**

- B18 est clos depuis assez longtemps pour que plus aucun jeton signé HS256 ne circule.
- La révocation est faite et une connexion, une inscription et une récupération de mot de passe ont été vérifiées juste après.

**Dépendances.** Item B18 terminé.

*Renvois : `item B18`*

#### B20 — Le repli sur la clé legacy ne doit pas pouvoir revenir : une garde, pas un commentaire

`P1` Prioritaire · État : **Ouvert** · Charge : une soirée · Ce que ça demande : Deno / TypeScript

**État.** `_shared/core/secret-key.ts` a retiré le 02/09 (B18) le repli sur `SUPABASE_SERVICE_ROLE_KEY`, avec un commentaire qui dit pourquoi. La PR #28 le réintroduit (`return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")`) — de bonne foi, pour sa pile, où la même PR pose déjà `SUPABASE_SECRET_KEYS` dans `compose.yml`. Un commentaire n'a pas suffi ; la clé legacy est désactivée en prod, un repli vers elle masquerait une panne au lieu de la dire (`DOC-SILENCE-1`).

*Vérifié : 06/09 — PR #28 relue en entier (46 fichiers, tête `b5782ec1`), production interrogée en lecture seule, constat `CONSTAT_PR28_rejeu_vs_production_revoke_anon_2026-09-06`.*

**Ce que c'est.** Une garde dans `scripts/ci/` (grep sur `supabase/functions/**` : aucun `SUPABASE_SERVICE_ROLE_KEY` hors de `env.ts`/commentaires, liste fermée) et une ligne dans `CONTRIBUTING.md`. Demander le retrait dans la PR #28.

**Pourquoi ça compte.** Une décision de sécurité qui ne tient qu'à un commentaire est annulée par la première personne qui ne l'a pas lu. Les gardes à liste fermée sont la forme que ce dépôt sait tenir (`DOC-GRANT-1`, `T10`).

**Ce qui compte comme fini.**

- La garde existe et rougit sur la branche de la PR #28 telle qu'elle est le 06/09.
- `secret-key.ts` est revenu à sa forme du 02/09 dans la PR.

**Dépendances.** Aucune.

*Renvois : `supabase/functions/_shared/core/secret-key.ts` · `item B18` · `REGISTRE §0 DOC-SILENCE-1` · `codeberg.org/anarbib/anarbib/pulls/28`*

#### B22 — Quarante-sept fonctions ouvertes à anon sans qu'aucune ligne du dépôt ne le dise

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL

**État.** Mesuré le 07/09 en préparant la spec d'`I17` (§4 de `CADRAGE_rejeu_fidele_privileges_par_defaut_2026-09-07`). **Classe A** : 98 fonctions portent `anon=X` dans leur ACL ; pour **12** d'entre elles, aucun `GRANT … TO anon` n'existe dans le dépôt — elles ne sont ouvertes que par le privilège par défaut du moment de leur création (quatre DEFINER pourtant listées dans `T10`, dont `fn_book_restricted_pdf_state` et sa sœur appelées par le front ; six triggers et helpers des périodiques et des tomes ; `fn_current_user_is_member_of_holding_library`, `fn_reading_notes_enabled_for`). **Classe B** : 35 fonctions sont exécutables par `anon` via `PUBLIC` — `=X` explicite sur **dix RPC de circulation de `api`** (`advance_consulta`, `create_loan_at_counter`, `return_loan_total`…), 17 helpers et triggers d'`ingest`, 5 de `public` ; ACL nulle sur `api.extend_loan_item_as_library`, `api.renew_my_loan_item`, `private.fn_book_work_id`. Toutes INVOKER : la RLS tient, le lint 0028 ne les voit pas — mais une RPC de prêt appelable par un visiteur anonyme est une surface laissée par oubli, pas par décision (`DOC-GRANT-1`). **07/09, expérience d'`I17`** : même mécanisme côté **relations**. Cinq vues du socle sans `security_invoker` (`v_author_alias_candidates_unique`, `v_author_alias_worklist`, `v_author_seed_candidates`, `v_terra_livre_books_ready`, `v_terra_livre_books_ready_stats`) naissent lisibles par `anon`/`authenticated` au rejeu (défaut de l'image sur les tables : `anon=arwdm`) alors que la prod ne leur laisse que `anon=m` : le `REVOKE SELECT` qui les a fermées n'est écrit nulle part (`20260830110000` ne retire qu'`insert, update, delete`). T7 de `grants_herites` est rouge au rejeu, vert en CI (template0). Deux voies : étendre A.1 aux tables avant le socle, ou une migration nominative — vues et policies à chercher avant.

*Vérifié : 07/09 — mesure complémentaire, pas la même que les 47 : **28** fonctions SECURITY DEFINER de `api`+`public` sont exécutables par `anon`. La « migration de REVOKE avant le 8 » de la reprise du 06/09 n'a pas été jouée ; le constat écrit, c'est cet item.

07/09 — mesures faites pour la spec d'I17 : image `supabase/postgres:17.6.1.136` sondée à vide (conteneur jetable), production interrogée en lecture seule, dépôt au commit `fb64c996`.*

**Ce que c'est.** Une migration nominative, après le 14 : pour chacune des 47, un `GRANT EXECUTE … TO anon` écrit si l'ouverture sert (à confirmer sous session anonyme pour les deux `fn_book_restricted_pdf_state*`), sinon `REVOKE EXECUTE … FROM PUBLIC, anon` + `GRANT … TO authenticated` (les RPC de circulation) ou rien de plus que le retrait (triggers, helpers). **Avant chaque REVOKE, chercher les vues et les policies** qui appellent la fonction sous le rôle du lecteur (`pg_rewrite`, `pg_policy`) — REGISTRE « avant un REVOKE, chercher les VUES ». Compléter `T10` si une DEFINER change de camp. **Recommandation du 07/09 pour les cinq vues de T7** : d'abord une **migration nominative** qui écrit le `REVOKE SELECT` sur les cinq vues (sûre, elle documente l'état réel de la prod : `anon=m, authenticated=m`), après avoir cherché qui les appelle (`pg_rewrite` pour les vues, `pg_policy` pour les policies — une lecture publique qui passerait par elles tomberait en silence, l'app avale le 403 en liste vide). L'**extension d'A.1 aux tables** (retirer `anon` du défaut des relations avant le socle, laisser les `GRANT` du dump rouvrir) reste une **question**, à instruire avec Bastien quand A.1 lui sera proposé : elle touche la trajectoire du rejeu et mérite sa propre expérience (vérifier que le socle rétablit bien le défaut des tables pour `postgres`, l. 61226-61229).

**Pourquoi ça compte.** `DOC-GRANT-1` dit qu'une ouverture à `anon` est un acte écrit. Quarante-sept fonctions contredisent la règle en silence ; le jour où un rejeu ferme le défaut, `T10` rougit pour quatre d'entre elles sans qu'aucune ligne n'explique pourquoi elles devaient être ouvertes.

**Ce qui compte comme fini.**

- Chacune des 47 a une ligne écrite qui dit son ouverture ou sa fermeture.
- `grants_herites_tests.sql` porte une assertion « aucune fonction exécutable par anon sans GRANT écrit » — une liste fermée, comme `T10`.
- Le lint 0028 rend toujours 28, ou le nouveau nombre attendu, écrit.

**Dépendances.** Après le 14/09 (gel). Indépendant d'`I17`, mais la spec d'`I17` en est la source.

*Renvois : `journal/cadrages/CADRAGE_rejeu_fidele_privileges_par_defaut_2026-09-07 §4` · `REGISTRE §0 DOC-GRANT-1` · `tests/sql/grants_herites_tests.sql T10` · `item I17`*

#### B23 — `api.library_email_identity` est la seule vue `api` encore en SECURITY DEFINER — le dire, ou la basculer

`P3` Différé · État : **Ouvert** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL

**État.** Le GLB v17 (01/09) comptait 67 vues `api` sur 68 en `security_invoker`. **Vérifié le 07/09** : `pg_class.reloptions` de `api.library_email_identity` est vide — elle lit donc sous le propriétaire. Peut-être voulu (elle sert l'identité d'expéditeur aux fonctions de courriel), mais aucun commentaire ne le dit.

*Vérifié : 07/09 — `reloptions` vide, donc DEFINER.*

**Ce que c'est.** Soit `ALTER VIEW … SET (security_invoker = on)` et une suite qui vérifie que le courriel part encore, soit un `COMMENT ON VIEW` qui explique l'exception. Une soirée dans les deux cas.

**Pourquoi ça compte.** Une exception non écrite se rejoue un jour comme une erreur — par quelqu'un qui « corrige » ce qui était voulu.

**Ce qui compte comme fini.**

- La vue est en invoker, ou porte le commentaire qui dit pourquoi elle ne l'est pas.

**Dépendances.** Aucune.

*Renvois : `claude/GLB_v17_releve_et_constats_2026-09-01`*

---

### C — Catalogage et données documentaires

*La dette ici n'est pas du code : ce sont des fiches à relire une par une.*

| | | | |
|---|---|---|---|
| **C2** | Importer le fonds SOLIDAIRES par l'outil d'import, et consigner ce qui casse | `P1` | Bloqué |
| **C3** | Mener la revue humaine des autorités : patronymes, casse, titres | `P1` | Ouvert |
| **C4** | Renseigner les pays manquants sur 722 fiches d'autorité | `P2` | Ouvert |
| **C6** | Livrer les trois assistances de saisie prévues par la spec des conventions | `P2` | Ouvert |
| **C7** | Indexer par matière les 1 549 notices qui n'ont aucun sujet | `P2` | Ouvert |
| **C8** | Enrichir les autorités : dates, identifiants externes, formes variantes | `P3` | Ouvert |
| **C9** | Les huit questions des conventions sont tranchées : reste une clé, un rafraîchissement et cinq gestes à la main | `P2` | Ouvert |
| **C10** | Renommer l'une des deux colonnes `rights_status` | `P2` | Ouvert |
| **C11** | Arbitrer ce que l'OPAC par œuvre a mis en file : tomes, œuvres scindées, titres pré-traduits, notes MLEG | `P2` | Ouvert |

#### C2 — Importer le fonds SOLIDAIRES par l'outil d'import, et consigner ce qui casse

`P1` Prioritaire · État : **Bloqué** · Charge : quelques jours · Ce que ça demande : bibliothéconomie, SQL / PostgreSQL

**État.** 1 685 notices dans `SOLIDAIRES_import_test.csv`. **Constat corrigé le 31/08 : le fichier a bel et bien été confronté à l'importeur.** `book_drafts` porte 1 673 brouillons de source `SOLIDAIRES_import_v2.csv`, créés en un seul lot le 29/08 à 1 h 48 — la nuit précédant l'écriture du constat « jamais confrontés ». Tous sont à l'état `draft`, **aucun n'est publié** : le catalogue public n'est pas touché. La décision de Xavier (29/08) reste entière pour la suite : pas de promotion tant que la candidature de SOLIDAIRES n'est pas acceptée à plusieurs (G7). Ce qui reste de l'item n'est donc plus « importer », mais consigner ce que l'import a cassé, puis promouvoir après l'admission.

*Vérifié : 07/09 — inchangé : 1 673 brouillons `SOLIDAIRES_import_v2.csv`, candidature `pendente` depuis le 27/08.

31/08 — `book_drafts` : 1 673 lignes de source `SOLIDAIRES_import_v2.csv`, toutes créées le 29/08 à 1 h 48 en un seul lot, toutes `draft`, 0 publiée, 0 rattachée à un périodique. Le premier critère de fin (« l'admission avant que le fichier soit touché ») est caduc dans sa lettre : le fichier a été touché — mais rien n'est entré au catalogue.*

**Ce que c'est.** Adapter les en-têtes au format réellement attendu (environ une heure), faire passer le fichier **par l'outil d'import du dépôt et non par des `INSERT` à la main**, relire une vingtaine de fiches au hasard, puis faire une démonstration en visio écran partagé.

**Pourquoi ça compte.** L'objet reste autant d'éprouver l'importeur que d'obtenir les notices : **le livrable le plus utile du chantier est la liste de ce qui casse, de ce qui est mal deviné et de ce qui se perd** — pas les 1 685 fiches. Mais faire entrer un fonds avant que le réseau ait dit oui reviendrait à trancher par le fait ce qu'on dit vouloir trancher à plusieurs. C'est le même raisonnement qui interdisait de créer la fiche bibliothèque ; il s'étend maintenant au lot lui-même.

**Ce qui compte comme fini.**

- **L'admission a été prononcée à plusieurs (G7) avant que le fichier soit touché.**
- Le lot est passé par l'outil d'import du dépôt, pas par des `INSERT` à la main.
- Un compte rendu écrit dit ce qui a cassé, ligne par ligne quand c'est possible.
- Vingt fiches tirées au hasard ont été relues.
- **Aucune coquille d'accent de la source n'a été corrigée en silence** : les corrections vivent dans `assunto_local_sugerido`.

**Dépendances.** **Bloqué par G7**, lui-même bloqué par **A1**. Rien ne bouge tant que le réseau n'a qu'un seul administrateur.

*Renvois : `REPRISE_claude_code_2026-08-27 chantier 2` · `CALENDRIER_bologne_2026-08-27`*

#### C3 — Mener la revue humaine des autorités : patronymes, casse, titres

`P1` Prioritaire · État : **Ouvert** · Charge : plusieurs semaines · Ce que ça demande : bibliothéconomie

**État.** Les 19 migrations `conventions_*` sont appliquées depuis le 21/08 : les référentiels sont normalisés, les mécaniques sûres ont été passées, la file de vérification existe et l'application permet d'y travailler. **Ce qui reste est la part qu'aucune machine ne fait.**

*Vérifié : 31/08 — la file `catalog_review_queue` mesurée, 310 lignes : le lot **patronymes est terminé** (20 validés, 2 écartés, 0 à revoir — les 9 suffixes de filiation, donnés pour le défaut le plus grave, sont derrière), `autorite_casse` presque (3 à revoir sur 61), `titre_casse` porte le gros du reste (174 à revoir sur 211), et un quatrième lot `autorite_collectivite` s'est ajouté (2 à revoir sur 16). **179 verdicts humains restent.** **03/09** — 1 532 autorités (1 305 à midi : +227 créées par le lot C5 le soir même, jamais relues, non typées), 1 468 non typées, `name_lang` sur 22, 6 orphelines, 2 doublons de forme de tri sans casse ; `conv_backup` : titres 211, casse 1 274, patronymes 22, inchangés. **Xavier demande un audit en profondeur des autorités et une correction propre, en nouvelle session** : cadrage écrit, `docs/journal/cadrages/REPRISE_audit_autorites_en_profondeur_2026-09-03.md` — recompter d'abord, rejouer l'audit du 20/08, corriger par lots de la file ou migrations testées, jamais en masse. **03/09, nuit — audit fait** (`journal/audits/AUDIT_autorites_2026-09-03.md`) : 1 532 autorités, 23 livres sans autorité (18 écartés + 5 à `autor` NULL), 3 orphelines (pas 6), **13 paires de doublons exacts** dont 9 nées du lot C5, 17 `preferred_name` en capitales après la correction du 21/08, 14 collectivités inversées ratées par le motif, 12 fiches doubles (O8). **Livré** : cinq migrations testées (CONV-2 sur 17 fiches ; homonymie sans casse ni accents + 8 signalements (les 5 paires de fixtures de formation exclues) ; motif des collectivités + re-semis ~36 ; second semis casse ~40 ; nouveau lot `autorite_forme` ~95). **La file porte désormais ~170 verdicts de plus**, tous humains : lots `autorite_collectivite`, `autorite_casse`, `autorite_forme` dans `/atelier-autoridades`. **Puis, le soir même, sur décision de Xavier (« corrige ce qui est évident ») : quatre migrations d'évidences** — 10 doublons exacts fusionnés, 4 non-agents retirés, 24 contributeurs liés à leur fiche homonyme exacte, 43 lignes évidentes de la file tranchées et appliquées (Xavier en avait posé 87 lui-même entre 20 h 00 et 20 h 07). Restent à la main : les fiches doubles (décision O8), les périodiques et l'éditeur logés dans `authors`, les pseudonymes et les formes hispaniques ambiguës.*

**Ce que c'est.** Reprendre les trois tables de revue du schéma `conv_backup` — `titres_a_revoir_20260820` (211), `autorites_casse_a_revoir_20260820` (1 274), `autorites_patronyme_a_revoir_20260820` (22) — et les traiter fiche par fiche depuis l'Atelier autorités.

**Pourquoi ça compte.** Sur les 22 doubles patronymes hispaniques signalés automatiquement, **trois sont des faux positifs connus** (Mechoso, Borges, Marcos) : 14 % d'erreur. Et sur les 13 points d'accès sur particule, **quatre sont corrects** (Van der Walt, De Amicis, Di Paolo, De Greef). Un script qui « finirait » ce travail introduirait des fautes dans un catalogue qui n'en a pas.

**Ce qui compte comme fini.**

- Les trois tables sont vidées par validation humaine, pas par script.
- **Interdiction absolue** : décommenter le SQL d'application, le compléter, ou passer `valide = true` en masse.
- Les 9 points d'accès posés sur un suffixe de filiation — type `FILHO, Fábio Luz` — sont traités en premier : l'audit les donne pour **le défaut le plus grave du lot**.

**Dépendances.** Se fait dans l'application, sans migration. C'est un chantier de bibliothéconomie, ouvert à qui sait cataloguer.

*Renvois : `AUDIT_conventions_catalographiques_2026-08-20` · `REGISTRE §37 CONV`*

#### C4 — Renseigner les pays manquants sur 722 fiches d'autorité

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : bibliothéconomie

**État.** **722 fiches sur 1 305 (55 %) n'ont pas de `country`.** Or c'est `country` qui pilote la règle d'entrée du nom : sans lui, la détection des doubles patronymes hispaniques ne voit qu'une fraction des cas. Les 22 signalements sont un **plancher**, pas un total.

*Vérifié : 31/08 — 726 fiches sur 1 305 sans `country` (55,6 %) : quatre de plus qu'au 29/08. La dette avance plus vite que sa résorption.*

**Ce que c'est.** Renseigner `country` par lots, à partir des notices, des sources externes déjà branchées (Wikidata, VIAF) et de la connaissance du fonds. Puis rejouer la détection des patronymes.

**Pourquoi ça compte.** C'est le prérequis dur de toute la chaîne de conventions : `CONV-7` fait de `country` en ISO 3166-1 α-2 une condition, et `CONV-3` fait piloter la casse par la langue. Un catalogue à 55 % sans pays applique ses propres règles à moitié.

**Ce qui compte comme fini.**

- La proportion de fiches sans `country` est descendue sous 20 %.
- La détection des doubles patronymes a été rejouée et la nouvelle liste est passée en revue humaine.

**Dépendances.** Prérequis de la seconde passe de **C3**.

*Renvois : `AUDIT_conventions_catalographiques_2026-08-20 A5` · `REGISTRE §37 CONV-7`*

#### C6 — Livrer les trois assistances de saisie prévues par la spec des conventions

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : React / JavaScript, bibliothéconomie

**État.** La base sait normaliser ; l'interface de saisie n'assiste pas encore. Trois dispositifs sont spécifiés et non livrés : l'assistant de découpage du nom (§7.1), le bouton « Normalizar maiúsculas » avec aperçu (§7.2), et la file de contrôles de cohérence en arrière-plan (§7.3).

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Trois écrans, dans cet ordre de valeur : le bouton de normalisation de casse (le plus simple, actif seulement si la langue est renseignée) ; l'assistant de découpage, qui propose mot par mot avec un bouton « Corrigir » et une explication d'une ligne ; la file de contrôles, qui signale sans bloquer.

**Pourquoi ça compte.** C'est la contrainte de conception la plus ferme du projet : **toute règle doit être soit invisible parce que calculée, soit assistée parce que proposée et confirmée, jamais un savoir préalable exigé à la saisie.** Les personnes qui cataloguent ne sont ni bibliothécaires ni informaticiennes. Sans ces trois écrans, les conventions restent une doctrine que seul leur auteur sait appliquer.

**Ce qui compte comme fini.**

- Les trois dispositifs existent et **aucun n'est bloquant**.
- Chaque proposition est refusable, avec l'original conservé.
- Les libellés existent dans les dix locales en une seule passe.

**Dépendances.** S'appuie sur les migrations `conventions_*` déjà en place.

*Renvois : `spec-conventions-catalographiques-v0.1 §7`*

#### C7 — Indexer par matière les 1 549 notices qui n'ont aucun sujet

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : bibliothéconomie, aucune compétence technique

**État.** Vérifié le 29/08 : **1 127 notices indexées sur 2 676**, soit 42 %. 1 284 affectations réparties sur 89 sujets locaux. Côté public anonyme, la couverture est encore plus basse.

*Vérifié : 31/08 — 1 122 notices indexées sur 2 659 (42,2 %), 1 279 affectations, 89 sujets. Les quatre comptes ont légèrement baissé depuis le 29/08 : les fusions de doublons du 31/08 ont retiré des notices, pas des indexations.*

**Ce que c'est.** Indexer, notice par notice, avec le vocabulaire local et le thésaurus FICEDL déjà chargé. Aucune compétence technique : c'est un travail de bibliothèque, fait depuis l'application.

**Pourquoi ça compte.** Un catalogue à 42 % d'indexation ne se parcourt pas : il se cherche par titre, ce qui suppose de savoir ce qu'on cherche. Le sujet est le seul chemin d'entrée pour quelqu'un qui vient voir ce qu'il y a sur une question. Et le thésaurus étant traduit en dix langues, chaque affectation vaut simultanément pour les dix.

**Ce qui compte comme fini.**

- La couverture dépasse 70 % des notices publiques.
- Le sujet parasite `pierre-joseph-proudhon` (0 livre) est supprimé, et `anarcocomunismo` est vérifié.
- Les huit sujets AnarBib sans équivalent FICEDL restent rattachés à un terme plus large et sont **portés à la fédération comme contribution, pas comme plainte** : éducation libertaire (64 livres), abolitionnisme pénal (13), écologie sociale (10), anarcha-féminisme, communisme libertaire, anarcho-punk, especifismo, cabanagem.

**Dépendances.** Aucune. **Entrée sans compétence technique.**

*Renvois : `AnarBib-Backlog-2026-06-17-v33 §5` · `ETAT-lancement-consolide-2026-07-03 §2 item 6`*

#### C8 — Enrichir les autorités : dates, identifiants externes, formes variantes

`P3` Différé · État : **Ouvert** · Charge : plusieurs semaines · Ce que ça demande : bibliothéconomie

**État.** Sur 1 305 autorités : **726 (56 %) sans date de naissance**, environ **1 272 (98 %) sans identifiant VIAF, ISNI ou Wikidata**, environ **1 275 (98 %) sans `variant_forms`**. Le code d'enrichissement existe et fonctionne ; la couverture est de l'ordre de 1 à 2 %.

*Vérifié : 31/08 — sur 1 305 autorités : 728 sans année de naissance (56 %), 1 276 sans identifiant VIAF, ISNI ou Wikidata (98 %), 1 280 sans `variant_forms` (98 %). Le constat tient.*

**Ce que c'est.** Passes d'enrichissement par les sources déjà branchées, avec relecture. Les pseudonymes militants sont un cas à part : l'entrée se fait à la forme la plus connue du mouvement, avec renvoi depuis le nom civil, **jamais l'inverse**.

**Pourquoi ça compte.** Les identifiants externes sont ce qui permettra à un autre catalogue de reconnaître nos autorités sans les redécrire. Les formes variantes sont ce qui permet de trouver quelqu'un sous le nom qu'on connaît. Et pour un pseudonyme militant, la forme d'usage **porte souvent la seule trace d'une répression** : elle ne s'écrase pas.

**Ce qui compte comme fini.**

- La couverture en identifiants externes dépasse 20 % sur les autorités les plus citées.
- Aucun pseudonyme militant n'a été remplacé par un nom civil.

**Dépendances.** Après **C4** (les pays aident les alignements).

*Renvois : `AUDIT_conventions_catalographiques_2026-08-20 A7-A9` · `REGISTRE §12 CAT-D6`*

#### C9 — Les huit questions des conventions sont tranchées : reste une clé, un rafraîchissement et cinq gestes à la main

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : bibliothéconomie

**État.** `CONV-6` reste « à confirmer » et `CONV-O1` à `CONV-O8` sont ouverts. Deux d'entre eux portent du travail chiffré : `CONV-O7` (le type d'autorité existe mais reste illisible par le SQL — **16 verdicts de collectivités restent à poser**) et `CONV-O8` (la scission d'autorité n'existe pas — **3 découpages restent**).

*Vérifié : 31/08 — sur les 16 verdicts de collectivités, **14 sont posés** (lot `autorite_collectivite` de la file : 14 validés, 2 à revoir) ; `authors.authority_type` porte 19 `collective`, 45 `person`, 1 241 fiches non typées. La scission d'autorité n'existe toujours pas : aucune table ni fonction en base. Rien de mesuré sur les huit questions `CONV-O*` elles-mêmes. **03/09** — un verdict proposé par question dans la page des cinq décisions (O1 oui ; O2 convention provisoire ; O3 = C5 ; O4 pas de bascule sans déclencheur ; O5 le périmètre est la file ; O6 garde stricte + rafraîchissement ; O7 `authority_type` est la vérité ; O8 pas de scission avant la quatrième) ; file : collectivités 14 appliqués, 2 à revoir ; 1 241 autorités non typées. **Recommandé A**. Verdict attendu. **03/09 — tranché : A, les huit.** Passe de « décision » à « ouvert », effort S. **03/09, après-midi** — O5 livré, O6 constaté déjà fait ; il ne reste que f[3], le travail de main (2 collectivités à revoir, 3 découpages), à l'Atelier autorités. **03/09, nuit — f[3] a changé de taille** : l'audit des autorités compte **12 fiches doubles**, pas 3 (trois anciennes non vues, six nées du lot C5) ; le verdict O8 « pas de scission avant la quatrième » est dépassé par les faits et `fn_authority_split` existe depuis la migration 17 — **décision à reprendre** (REGISTRE §37, MàJ 03/09 nuit). Les 2 collectivités à revoir restent ; le lot en reçoit ~36 de plus (motif refait).*

**Ce que c'est.** **Tranché le 03/09 (C9 = A, les huit — `CONV-6`, `CONV-O1..O8` actés au REGISTRE v0.16).** Ce qui reste est du code petit et du travail à la main : **O5** renommer l'intitulé de `/atelier-autoridades` en « file de vérification du catalogue » (une clé, dix locales) ; **O6** rafraîchir `avant` à l'affichage de la file ; **O2** poser les deux verdicts de collectivités « à revoir » ; **O8** traiter à la main les trois fiches doubles (créer, repointer, fusion inverse). `O7` : vérifier que le SQL lit `authority_type` là où il affiche.

**Pourquoi ça compte.** La colonne `name_lang` a été créée nullable et sans contrainte validée : **la créer n'engage rien, l'utiliser oui**. Tant que la question reste ouverte, chaque nouvelle règle d'entrée doit se demander sur quoi elle s'appuie.

**Ce qui compte comme fini.**

- [object Object]
- [object Object]
- [object Object]
- [object Object]

**Dépendances.** Éclaire **C6**.

*Renvois : `REGISTRE §37 CONV-6, CONV-O1..O8`*

#### C10 — Renommer l'une des deux colonnes `rights_status`

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL

**État.** `digital_assets.rights_status` est un **état de workflow** (`to_review`, `public_domain_confirmed`) qui commande la visibilité. Le vocabulaire des droits d'auteur porte le même nom depuis la migration `20260820235000_vocabulaire_rights_status`. Deux sens, un nom.

*Vérifié : 31/08 — le nom vit désormais dans **trois** tables, pas deux : `digital_assets`, `book_digital_resources` et `book_draft_digital_resources` portent chacune une colonne `rights_status`, en plus du vocabulaire homonyme. Le télescopage s'étend au lieu de se résorber.*

**Ce que c'est.** Renommer la colonne de workflow — `review_state` par exemple — et propager au front et aux RPC. Le vocabulaire des droits garde le nom, puisque c'est lui qui parle de droits.

**Pourquoi ça compte.** Confusion garantie sinon, et sur un sujet où la confusion se paie : c'est l'état des droits qui décide si un document est visible du public. Un piège documenté s'y ajoute — `access_scope` vaut `conta_ativa` **par défaut**, si bien qu'un document du domaine public reste réservé aux comptes actifs tant que personne n'a posé `publico` explicitement.

**Ce qui compte comme fini.**

- Les deux notions portent deux noms distincts, en base et à l'écran.
- Le piège `access_scope` est rappelé dans le formulaire de catalogage, pas seulement dans une note.

**Dépendances.** Aucune.

*Renvois : `PLAN_DE_MARCHE §8` · `DECISION_profil_numerisation_2026-08-20`*

#### C11 — Arbitrer ce que l'OPAC par œuvre a mis en file : tomes, œuvres scindées, titres pré-traduits, notes MLEG

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : bibliothéconomie

**État.** L'OPAC se lit par œuvre depuis le 04/09 (`OPAC-OEU1..6`). Le code est livré ; ce qui reste est **de la bibliothéconomie, dans l'application**. Compté en production le 05/09 : **9 groupes de tomes** (30 notices) dans l'onglet « Volumes », **90 paires** proposées dans « Œuvres scindées », **3 doublons de notices** dans « À décider » (1458/2333, 1451/1446, 1359/1353), **1 452 titres automatiques** « corrige-moi » sur 162 œuvres (pré-traduction terminée, zéro erreur), **176 notes MLEG** « Assuntos importados » sans matière au thésaurus (huit catégories, dont Anarquismo no Brasil 50 et Anarquismo Internacional 42), et **161 œuvres à plusieurs éditions** dont une seule (Thoreau 97) a son titre uniforme vérifié dans la langue de l'œuvre.

*Vérifié : 05/09 — compté en production (session coordination) : 9 groupes / 30 notices ; 90 paires ; 3 doublons ; 1 452 titres auto à relire sur 162 œuvres ; 176 notes MLEG ; 161 œuvres multi-éditions, 0 sans titre uniforme (colonne obligatoire), 1 vérifiée.*

**Ce que c'est.** Dans l'assistant de dédoublonnage : trancher les groupes de tomes ligne à ligne (numéro posé à la main), les paires d'œuvres scindées (« Fusionner » ou « Garder séparées »), les trois doublons. Dans la fiche : relire les « Titres par langue » d'une œuvre quand on l'ouvre, poser le « Titre uniforme » dans la langue de l'œuvre. Pour les 176 notes MLEG, une décision **par catégorie** : laisser en note, ou choisir une matière proche **existante** — jamais créer d'entrée (`THES-4`), jamais convertir vers plus générique.

**Pourquoi ça compte.** Un OPAC par œuvre vaut ce que valent ses œuvres : chaque bibliothèque entrante ajoute ses éditions, et huit « Desobediência civil » sur six œuvres, c'est ce que voyait la lectrice le 04/09 au matin. La machine propose et mémorise, elle ne décide jamais (`OPAC-OEU3`, `OPAC-OEU5`, `DEDUP-7`) : deux tomes ne sont pas un doublon, deux éditions ne sont pas deux œuvres, et seul un regard le sait.

**Ce qui compte comme fini.**

- Les onglets « Volumes » et « Œuvres scindées » sont vides, ou ce qui y reste est mémorisé comme « pas des tomes » / « garder séparées ».
- Plus aucun titre « corrige-moi » sur une œuvre ouverte au moins une fois au catalogage.
- Les 176 notes MLEG ont chacune une décision écrite (matière existante posée, ou note conservée par choix), et `subjects` n'a pas gagné une entrée.
- Les œuvres à plusieurs éditions ont un titre uniforme dans leur langue d'origine.

**Dépendances.** Aucune migration : tout se fait dans l'application, par la coordination catalogage. Les compteurs se relisent en base (`suggest_volume_groups`, `suggest_split_works`, `work_titles.needs_review`, `books.notas ~ 'Assuntos importados'`).

*Renvois : `DECISION_opac_par_oeuvre_2026-09-04` · `REGISTRE §18 OPAC-OEU1..6` · `REGISTRE §30 THES-4` · `REGISTRE §40 DEDUP-10`*

---

### D — Périodiques, éphémères, ressources numériques

*Ce que la bibliothéconomie du livre ne sait pas décrire, et qui fait une part énorme de nos fonds.*

| | | | |
|---|---|---|---|
| **D3** | Rattacher les 91 fascicules et les 87 monographies suspectes de SOLIDAIRES | `P2` | Bloqué |
| **D4** | Le matériel éphémère : tracts, affiches, autocollants, zines | `P1` | Ouvert |
| **D5** | Éprouver la chaîne de numérisation sur dix ouvrages avant d'équiper qui que ce soit | `P2` | Ouvert |
| **D6** | Reprendre ou remplacer le lecteur EPUB | `P3` | Ouvert |

#### D3 — Rattacher les 91 fascicules et les 87 monographies suspectes de SOLIDAIRES

`P2` Courant · État : **Bloqué** · Charge : quelques jours · Ce que ça demande : bibliothéconomie

**État.** Le fichier SOLIDAIRES porte déjà des colonnes `revue` et `numero` : **12 titres à créer, 91 fascicules à lier**. En plus, **87 monographies portent « n° » dans leur titre** et sont marquées par un drapeau `numero_dans_titre` : ce sont des candidates au rattachement.

*Vérifié : 31/08 — les 1 673 brouillons SOLIDAIRES sont en base (voir C2) et **aucun ne porte de `serial_id`** : le rattachement des fascicules n'a pas commencé. Toujours derrière G7.*

**Ce que c'est.** Créer les 12 titres, lier les 91 fascicules, puis **soumettre** les 87 candidates à quelqu'un qui connaît le fonds. Ne pas les rattacher automatiquement.

**Pourquoi ça compte.** Un titre qui contient « n° » n'est pas toujours un fascicule — c'est parfois un titre de collection, parfois une coquille. Le drapeau signale, il ne décide pas. Et le réseau ne compte aujourd'hui que 4 titres de périodiques : ce lot les multiplierait par quatre, et éprouverait le sous-système pour de bon.

**Ce qui compte comme fini.**

- Les 12 titres existent et les 91 fascicules y sont rattachés.
- Les 87 candidates ont été soumises, et chaque verdict est humain.
- Le comportement observé sur les quatre notices *Encontros com a Civilização brasileira* confirme la règle anti-faux-doublons : deux paires en sortent, deux y restent.

**Dépendances.** **Bloqué par C2**, donc par **G7** et **A1**. La révision de la spec (**D1**) peut se faire sans attendre.

*Renvois : `spec-periodiques-v0.1 §10` · `REPRISE_claude_code_2026-08-27`*

#### D4 — Le matériel éphémère : tracts, affiches, autocollants, zines

`P1` Prioritaire · État : **Ouvert** · Charge : un chantier long · Ce que ça demande : bibliothéconomie, React / JavaScript, délibération collective

**État.** Rien n'existe. Le modèle de notice hérité de la bibliothéconomie du livre ne sait pas décrire ce matériel, et AnarBib ne fait pas exception. C'est le besoin **le plus mal couvert**, pour une part énorme de nos fonds.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Ce matériel n'a ni ISBN, ni éditeur, souvent ni auteur ni titre. Il est visuel autant que textuel : une affiche ne se résume pas à son océrisation. Le chantier commence par de la réflexion documentaire — que décrit-on, avec quoi, et pour qui — avant toute table.

**Pourquoi ça compte.** C'est ce que les bibliothèques militantes ont de plus spécifique et de moins outillé. Les vocabulaires d'éphémères construits ailleurs — NORLA, avec ses facettes *Tactics* et *Social Movement* — sont **monolingues** et sans lien avec le thésaurus FICEDL : il y a là un travail commun à faire, pas un module à écrire seul.

**Ce qui compte comme fini.**

- Un cadrage documentaire écrit, discuté avec au moins un autre fonds.
- Un modèle minimal éprouvé sur cinquante pièces réelles.
- **Ce n'est pas un chantier pour quelqu'un qui veut seulement écrire des fonctions.**

**Dépendances.** À relier à **H6** (alignement des vocabulaires militants) et à la rencontre de Bologne.

*Renvois : `docs/CHANTIERS_OUVERTS.md §3` · `VEILLE_leftovers_maydayrooms_2026-08-19`*

#### D5 — Éprouver la chaîne de numérisation sur dix ouvrages avant d'équiper qui que ce soit

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : bibliothéconomie

**État.** La règle est actée et tient en une phrase : « on capture en niveaux de gris, on livre en bitonal, on ne garde en ligne que ce qui est livré ». Les plafonds de buckets sont posés en production. **L'outil de dérivation n'est pas choisi**, et la fiche pratique d'une page n'est pas écrite.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Comparer ScanTailor + `img2pdf` avec `unpaper` ou ImageMagick sur dix ouvrages réels et variés, mesurer le poids et la lisibilité, choisir. Puis écrire la fiche : trois réglages, cinq contrôles, rien d'autre.

**Pourquoi ça compte.** Équiper une bibliothèque avec une chaîne non éprouvée, c'est lui faire scanner deux cents pages qu'il faudra refaire. Et le seuillage bitonal est **destructeur et irréversible** : on ne scanne jamais directement en bitonal, jamais.

**Ce qui compte comme fini.**

- Un outil est choisi, avec les mesures qui ont décidé.
- La fiche pratique d'une page existe, en portugais et en français.
- Le sort des images de capture est écrit : archivage hors ligne systématique ou effacement après validation — **la réponse appartient à chaque bibliothèque, mais elle doit être écrite quelque part**.

**Dépendances.** Le dimensionnement annoncé (20 Go pour démarrer, jusqu'à 50 Go sur 3-5 ans) dépend du choix d'outil.

*Renvois : `DECISION_profil_numerisation_2026-08-20 §9`*

#### D6 — Reprendre ou remplacer le lecteur EPUB

`P3` Différé · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : React / JavaScript, Deno / TypeScript

**État.** `epubjs ^0.3.93` est la seule dépendance clairement pré-1.0 sur un chemin critique — le lecteur EPUB, `src/lib/reader/epubEngine.js` et `src/components/viewers/EpubReader.jsx`. La bibliothèque n'a pas connu de publication majeure depuis des années.

*Vérifié : 31/08 — `package.json` : `epubjs ^0.3.93`, inchangé.*

**Ce que c'est.** Évaluer ce qui casse aujourd'hui, ce qui cassera avec les navigateurs à venir, et s'il existe une alternative libre maintenue. Décider entre épingler et assumer, ou remplacer.

**Pourquoi ça compte.** Le lecteur est ce qui rend un fonds numérisé consultable sans téléchargement. S'il tombe, ce n'est pas un confort qui disparaît, c'est l'accès. Rien ne presse aujourd'hui — mais il vaut mieux savoir.

**Ce qui compte comme fini.**

- Un verdict écrit : conserver et épingler, ou remplacer par quoi.
- Si conservation : un test qui vérifie l'ouverture d'un EPUB réel.

**Dépendances.** Aucune.

*Renvois : `package.json` · `Relevé du 29/08/2026`*

---

### E — Front, OPAC, i18n, accessibilité

*10 locales à parité stricte, 6 570 clés chacune (06/09), vérifiées en intégration continue.*

| | | | |
|---|---|---|---|
| **E1** | Faire auditer l'accessibilité par quelqu'un qui n'a pas écrit le code | `P1` | Ouvert |
| **E2** | Trancher les conventions néerlandaise et grecque | `P1` | Ouvert |
| **E3** | Uniformiser le registre d'adresse entre les dix locales | `P2` | Décision collective |
| **E4** | Régler les paires irrégulières de l'italien | `P2` | Ouvert |
| **E6** | Découper les cinq écrans qui pèsent plus de cent kilooctets | `P2` | Ouvert |
| **E9** | Finir la mise en page mobile : trois lots identifiés | `P2` | Ouvert |
| **E10** | Le reste du socle terrain : permanence mobile, notification poussée, planche de codes | `P3` | Ouvert |
| **E12** | La page Importations parle la langue de la machine — et l'export a une adresse que personne ne trouve | `P2` | En cours |
| **E14** | Une page pour signaler un bug depuis l'application | `P2` | Ouvert |
| **E15** | Les mots de confirmation « vider l'historique » et « supprimer le compte » sont le même mot dans huit locales sur neuf | `P2` | Ouvert |
| **E16** | La sous-page Privacidade de la Biblioteca afficherait deux messages contradictoires sur la purge automatique | `P2` | À vérifier |
| **E17** | Le bloc « Explorer » du catalogue s'ouvre replié, pour que la première notice soit visible sans défiler | `P2` | Ouvert |

#### E1 — Faire auditer l'accessibilité par quelqu'un qui n'a pas écrit le code

`P1` Prioritaire · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : aucune compétence technique, React / JavaScript

**État.** Des fonctionnalités d'accessibilité sont implémentées : panneau de réglages sur toutes les pages depuis le 26/08, `html lang` qui suit la langue affichée (WCAG 3.1.1) avec son test, champs à 16 px minimum, cibles tactiles à 44 px, `viewport-fit=cover`. **Aucun audit d'accessibilité indépendant n'a jamais été mené.**

*Vérifié : **03/09** — la formation (soirée 1 le 08/09/2026) comporte un **témoin léger** (étape 8 de `docs/journal/chantiers/PARCOURS_formation_BLMF_seance1_2026-09-08.md` : chercher, ouvrir, réserver au clavier seul, souris retournée). Ce n'est pas l'audit demandé par cette fiche : pas de lecteur d'écran, pas de personne concernée ; E1 reste ouvert et le discours reste « implémenté, pas audité ». La liste de blocages clavier qui en sortira entre ici. **03/09, fin de journée** — le témoin clavier léger se cale dans n'importe quelle soirée de la formation (sept soirées, plan du 01/09), pas « le 13/09 ». **06/09** — la navigation a changé le 05/09 : la page **« Je veux… »** (`/inicio`, 51 intentions par rôle, raccourcis en `localStorage`) et les **liens profonds vers les recueils PDF** (`#page=N` par langue). L'audit demandé devra parcourir ces deux chemins ; le témoin clavier de la formation peut commencer par « Je veux… ».*

**Ce que c'est.** Faire parcourir les parcours principaux — chercher, ouvrir une notice, réserver, s'inscrire — par une personne qui utilise un lecteur d'écran ou une navigation au clavier seul, et écrire ce qui bloque.

**Pourquoi ça compte.** « Implémenté » et « audité » ne sont pas le même mot, et les confondre est la faute la plus facile à commettre dans une présentation publique. Dire les deux, toujours : des fonctionnalités existent, personne d'extérieur ne les a éprouvées.

**Ce qui compte comme fini.**

- Un parcours complet a été fait au lecteur d'écran, avec un compte rendu écrit.
- Les blocages sont dans le backlog avec leur écran.
- Le discours public dit désormais « implémenté et audité par X », ou continue de dire les deux séparément.

**Dépendances.** **Entrée sans compétence technique** pour la partie parcours.

*Renvois : `Mémoire de projet, 25/08/2026` · `Commits 69af3cf5, df472bed`*

#### E2 — Trancher les conventions néerlandaise et grecque

`P1` Prioritaire · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : langue maternelle

**État.** Les dix locales sont à parité stricte de clés — 6 177 chacune, vérifiée en intégration continue depuis le 27/08. Mais les **conventions** de deux d'entre elles ne sont pas tranchées : le néerlandais est à l'état de brouillon, le grec reste à définir. Le test de parité ne voit pas ça : il compte les clés, pas leur justesse.

*Vérifié : 31/08 — les dix fichiers `anarbib-charte-langage-inclusif-v2-*.md` existent depuis le 05/06, `nl` et `el` compris ; mais dedans, la convention `nl` est marquée « provisoire » et la `el` « à définir avec une personne locutrice grecque militante ». Les documents existent, les décisions non : le constat tient sur le fond.*

**Ce que c'est.** Une locutrice ou un locuteur natif reprend la charte de langage inclusif, décide de la forme neutre pour sa langue, et relit les 6 177 chaînes en priorité sur les écrans les plus vus.

**Pourquoi ça compte.** Deux langues qui cessent d'être des traductions approximatives. C'est un des trois chantiers qui **ne demandent aucune compétence technique** — et le seul que personne d'autre ne peut faire à la place.

**Ce qui compte comme fini.**

- Les conventions `nl` et `el` sont écrites dans `docs/notes-audit/anarbib-charte-langage-inclusif-v2-*.md`.
- Les chaînes des écrans principaux sont relues.
- La liste néerlandaise est déjà partie chez Ludwig — le suivi en fait partie.

**Dépendances.** Aucune. **Entrée sans compétence technique.**

*Renvois : `docs/CHANTIERS_OUVERTS.md §5` · `docs/notes-audit/anarbib-charte-langage-inclusif-v2.md`*

#### E3 — Uniformiser le registre d'adresse entre les dix locales

`P2` Courant · État : **Décision collective** · Charge : quelques jours · Ce que ça demande : langue maternelle, délibération collective

**État.** `DOC-ADDR-1` fixe le tutoiement comme registre de l'interface. En pratique, **`nl` et `el` tutoient, les huit autres vouvoient**. L'écart est documenté et assumé comme « un chantier à décider, pas à subir au détour d'un correctif ».

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Décider une fois pour les dix, en tenant compte du fait que la valeur politique du tutoiement n'est pas la même dans chaque langue, puis passer les locales concernées en une seule opération.

**Pourquoi ça compte.** AnarBib propose à d'autres catalogues des conventions d'interopérabilité, dont l'une dit explicitement que le vocabulaire commun n'impose pas l'écriture inclusive de chacun. **La cohérence interne se règle avant de prêcher la convention.**

**Ce qui compte comme fini.**

- Une décision au REGISTRE, avec la raison.
- Les dix locales appliquent le même registre, ou l'écart est justifié langue par langue.

**Dépendances.** À faire après **E2** (les conventions décident du registre).

*Renvois : `REGISTRE §0 DOC-ADDR-1` · `VERIF_confidentialite_tiers_2026-08-20`*

#### E4 — Régler les paires irrégulières de l'italien

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : langue maternelle

**État.** `it.json` n'est pas conforme à la convention de l'astérisque final : les paires irrégulières comme `lettore` / `lettrice` ne se réduisent pas à `lettor*`. Le test de charte vérifie une seule chose sur l'italien — que `camerata` et `camerati` n'y figurent jamais, terme fasciste, échec dur — et rien d'autre.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Décider du traitement des paires irrégulières avec un locuteur natif, puis l'appliquer aux chaînes concernées. C'est un travail de langue, pas de code.

**Pourquoi ça compte.** L'italien est la langue de la présentation de Bologne. Une interface qui applique sa convention à moitié se voit à l'écran partagé.

**Ce qui compte comme fini.**

- Le traitement des paires irrégulières est écrit dans la charte italienne.
- Les chaînes concernées sont corrigées.
- Les trois chaînes restées en français dans l'interface italienne sont traduites (716 chaînes vues, 3 fautives).

**Dépendances.** Avant le 08/09 si possible, sinon octobre.

*Renvois : `CLAUDE.md, piège connu n°9` · `CALENDRIER_bologne_2026-08-27`*

#### E6 — Découper les cinq écrans qui pèsent plus de cent kilooctets

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : React / JavaScript

**État.** `BookDraftForm.jsx` fait **197 Ko**, `BibliotecaPage.jsx` 184 Ko, `AccountPage.jsx` 154 Ko, `PanelPage.jsx` 114 Ko, `ImportacoesPage.jsx` 109 Ko. 29 des 38 routes sont déjà en chargement paresseux, et `vite.config.js` déclare quatre lots de dépendances — le problème n'est pas le chargement initial, c'est la taille d'un fichier unique.

*Vérifié : 31/08 — les cinq mêmes fichiers, aux tailles voisines : `BookDraftForm.jsx` 197 Ko, `BibliotecaPage.jsx` 186 Ko, `AccountPage.jsx` 155 Ko, `PanelPage.jsx` 116 Ko, `ImportacoesPage.jsx` 111 Ko.*

**Ce que c'est.** Extraire les sous-formulaires et les onglets en composants séparés, sans changer le comportement. Commencer par `BookDraftForm`, le plus gros et le plus édité.

**Pourquoi ça compte.** Un fichier de 197 Ko n'est pas relisible par quelqu'un qui arrive, et deux personnes ne peuvent pas y travailler en même temps sans conflit. C'est un obstacle à la contribution avant d'être un problème de performance.

**Ce qui compte comme fini.**

- Aucun fichier de `src/` ne dépasse 60 Ko.
- Le comportement est inchangé, vérifié écran par écran.
- Découpage par lots, un écran à la fois, jamais une refonte.

**Dépendances.** Reprend `#PERF-accountpage-split`, hérité du v32.

*Renvois : `AnarBib-Backlog-2026-06-17-v33 §2.5` · `Relevé du 29/08/2026`*

#### E9 — Finir la mise en page mobile : trois lots identifiés

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : React / JavaScript

**État.** Les phases A, B et C sont livrées et la doctrine graduée est actée. Trois questions restent ouvertes au REGISTRE : `MOB-Q1` (24 grilles déclarées en ligne dans le JSX avec des pistes `fr` nues), `MOB-Q2` (20 requêtes de média héritées à rapatrier dans `src/styles/mobile.css`), `MOB-Q3` (les onglets Validações et Inventário à convertir en cartes).

*Vérifié : 31/08 — `MOB-Q1` est soldée dans le code : sur 49 pistes `1fr` du JSX, toutes sont en `minmax(0,1fr)` sauf un commentaire qui énonce la règle (`AtelierAutoridadesPage.jsx:278`). `MOB-Q2` a fondu : 8 requêtes de média hors `mobile.css` (2 dans `breakpoints.css`, 1 dans `tabbar.css`, 5 dans le JSX) au lieu des 20 citées. `MOB-Q3` non mesuré. Verdict posé le soir même sur `MOB-Q2` : rien à rapatrier, chaque requête restante est à sa place (voir le critère barré). Reste `MOB-Q3`.*

**Ce que c'est.** Trois passes mécaniques, dans cet ordre de valeur : les 24 grilles (`minmax(0, Nfr)` partout, c'est la règle `MOB-1`), les deux onglets en cartes selon le patron livré, puis le rapatriement des requêtes de média.

**Pourquoi ça compte.** Une piste `fr` nue déborde dès que son contenu est plus large que la colonne, et un débordement **se constate par la mesure, jamais à l'œil** (`MOB-9`). Les 24 grilles sont autant de débordements en attente d'un titre long.

**Ce qui compte comme fini.**

- ~~Aucune grille du JSX ne porte de piste `fr` nue~~ — 31/08 : plus une seule, la dernière occurrence est un commentaire qui rappelle la règle.
- Les deux onglets sont en cartes sous 640 px.
- ~~Les requêtes de média héritées vivent dans `mobile.css`~~ — les 20 héritées y sont ; les 8 restantes ont chacune une raison d'être ailleurs (4 dans des documents engendrés — étiquettes, gazette, impression du catalogue — dont le CSS d'impression voyage avec le document ; 1 dans `breakpoints.css`, la source canonique des paliers ; 1 dans le CSS du composant tabbar, aligné sur le palier 640). Verdict du 31/08.

**Dépendances.** Aucune. Chantier découpable en trois.

*Renvois : `REGISTRE §36 MOB-Q1..Q3`*

#### E10 — Le reste du socle terrain : permanence mobile, notification poussée, planche de codes

`P3` Différé · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : React / JavaScript

**État.** Le socle terrain est livré : application installable, lecture de codes QR et ISBN, récolement, mise en page adaptative. Trois éléments restent, hérités du v32 et non revérifiés depuis : la permanence mobile (P3), la notification poussée (P5), et la planche de codes QR au format A4.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Commencer par vérifier lequel des trois est encore un manque réel. La notification poussée pose une question de fond avant une question de code : elle suppose un service tiers, ce que la doctrine anti-pistage regarde de près.

**Pourquoi ça compte.** La planche A4 est la plus simple et la plus utile au comptoir : elle permet d'étiqueter un fonds sans imprimante à étiquettes. Les deux autres méritent d'abord une conversation.

**Ce qui compte comme fini.**

- La planche A4 existe et s'imprime correctement.
- Pour la notification poussée, un verdict écrit : faisable sans tiers, ou renoncement assumé.

**Dépendances.** Hérité de `#MOBILE P3`, `#MOBILE P5`, `#MOB-QR-A4`.

*Renvois : `AnarBib-Backlog-2026-06-17-v33 §2.1`*

#### E12 — La page Importations parle la langue de la machine — et l'export a une adresse que personne ne trouve

`P2` Courant · État : **En cours** · Charge : quelques jours · Ce que ça demande : React / JavaScript, langue maternelle

**État.** **Constat de Xavier le 02/09, sur sa propre capture d'écran, après avoir exercé le circuit OAI dans les deux sens** : « pas très ergonomique ce bazar, surtout pour des camarades qui sont pas informaticiens ». Trois défauts distincts se cachent derrière le mot.

**(1) Le vocabulaire est celui du pipeline, pas du geste.** « Traitements », « Lignes en staging », « Promu·e·s », « Brouillons créés », « File de révision », « Journal d'importation » décrivent exactement staging → révision → promotion — pour qui l'a construit. Une bibliothécaire veut *faire entrer des notices* : « Notices reçues », « À vérifier », « Entrées au catalogue ».

**(2) Des codes bruts fuient à l'écran.** Sous « Bibliothèques compagnes », les pastilles affichent `mapeada` et `importacao_autorizada` : des valeurs d'énumération non traduites — `relation_status || '—'` dans `ImportacoesPage.jsx`, et **aucune clé i18n** pour ces valeurs dans les dix locales (vérifié le 02/09). C'est le défaut le plus net et le moins cher.

**(3) L'import et l'export sont mélangés, et l'export est ailleurs.** La page s'appelle « Importations » mais héberge « Moisson OAI » (un import) ; « être source » — l'export par moissonnage, exercé puis refermé le 02/09 (H5) — vit dans l'onglet réseau de `RedePage` ; l'export d'un lot se cache derrière deux icônes sans libellé à droite du lot. Quelqu'un qui veut « donner nos notices à un autre catalogue » n'a aucun endroit qui s'appelle comme ça. Et le parcours impose un concept de « source partenaire » même pour un simple fichier sous la main : quatre étapes là où l'attente est « je choisis mon fichier, je vérifie, c'est entré ».

**Correction du soir même, sur une seconde capture de Xavier (« voilà pourquoi je trouve que l'import fait un peu usine à gaz »).** L'export **a** une adresse : un commutateur « Sens : Importation / Exportation » en tête de page — si petit que le mainteneur lui-même ne l'avait pas en tête. Le volet 3 se reformule donc : l'adresse existe, elle est illisible, et ce qu'elle ouvre est le vrai « bazar » — **six blocs de trois natures différentes empilés dans le même onglet** : *(a)* geste de bibliothécaire — « Exportation par lot » (CSV / MARCXML / JSON), le seul que la plupart cherchent ; *(b)* gestes de coordination sur le fonds numérique — « Export de fonds » (ZIP), « envoi direct à une bibliothèque partenaire », « Attacher les fichiers reçus » ; *(c)* gestes juridiques — « Préparer l'éligibilité à l'export », « Vérifications de domaine public ». Plus un bloc « Partage ILL » qui annonce **« fonctionnalité en développement » à l'écran** (un chantier ne s'affiche pas aux usagères), et un vocabulaire qui fuit : *éligibilité*, *assets*, *bucket* (« le retire du bucket », lisible par une coordination). Le commutateur « Sens » est d'ailleurs la bonne idée : c'est sa **visibilité** et le **tri de ce qu'il ouvre** qui manquent.

**Troisième constat, sur la page livrée (Xavier, 02/09 soir)** : « Comment un coordinateur qui n'est pas admin fait-il pour demander à ce que sa bibliothèque puisse être moissonnée ? » Réponse : il ne pouvait pas depuis l'interface. Le circuit existe (`fn_oai_request_open_library` accepte une coordination active, `RedePage` l'accueille directement sur l'onglet « Être source », le bouton de demande y est) — mais le lien « Réseau » de la barre n'apparaît qu'aux admins réseau (`canSeeRede(isNetworkAdmin)`). Une coordination devait taper `/rede` à la main. Même maladie que le commutateur « Sens » : une adresse que personne ne trouve.

*Vérifié : 02/09 — constat porté par la personne qui exerce l'outil, vérifié dans le code (`relation_status || '—'` rendu brut ; aucune clé i18n pour ces valeurs, grep sur `fr.json`). **06/09** — depuis le 05/09, **un lot né d'un import ne se publie qu'après une révision de l'administration, sur rapport** (`catalog_batch_reviews`, garde dans `publish_book_draft`, cloche ; onglet Révisions de Rede). C'est un troisième volet à ajouter à la page : la coordination doit comprendre pourquoi son lot attend, et où. Aucune révision n'a encore eu lieu.*

**Ce que c'est.** Trois lots, du moins cher au plus structurant. **Lot A — avant la soirée 1 de la formation, le 08/09** : traduire les statuts bruts (`relation_status`, états de lot, états de ligne) dans les dix locales, et donner un libellé aux deux icônes du lot — une soirée, et la page peut être montrée sans rougir. **Lot B** : renommer vers le geste (les six libellés de l'en-tête et des sections), sans toucher au pipeline. **Lot C** : rendre le commutateur « Sens » visible (deux vrais onglets, pas un interrupteur), et **trier l'onglet Exportation par nature** — d'abord le geste de bibliothécaire (« Exporter notre catalogue », CSV/MARCXML/JSON, seul bloc visible par défaut), puis un volet « Mutualiser un fonds numérique » (ZIP, envoi direct, fichiers reçus, éligibilité, domaine public) réservé à la coordination et replié ; retirer de l'écran ce qui est « en développement » (ILL) tant qu'il l'est ; bannir *assets* et *bucket* des textes ; et réunir là aussi « être source » (OAI) et le flux OPDS, qui sont des exports. Côté import, le parcours guidé « j'ai un fichier » en deux écrans, source partenaire facultative. Éprouver chaque lot avec une personne qui n'a pas écrit le code (E1 a la même exigence).

**Pourquoi ça compte.** C'est la doctrine anti-méga-machine appliquée à l'écran le plus technique du logiciel : un outil qui cache les camarades derrière son vocabulaire fait le contraire de ce qu'il promet (`DOC-COLLECTIVE-1`). Et la formation BLMF (soirée 1 le 08/09/2026, sept soirées) montrera cette page aux coordinations — le lot A est daté par ce calendrier.

**Ce qui compte comme fini.**

- [object Object]
- [object Object]
- [object Object]
- [object Object]
- [object Object]

**Dépendances.** Né de l'épreuve **H5** (l'export par moissonnage vit à Rede, pas ici). Voisin de **E9** (mobile) et **C6** (assistances de saisie) sans les recouvrir ; même exigence de regard extérieur que **E1**. Le lot A est daté par **K7** (soirée 1 le 08/09/2026).

*Renvois : `src/pages/importacoes/ImportacoesPage.jsx` · `src/components/rede/OaiSourcePanel.jsx` · `supabase/functions/export-catalog-lote` · `capture d'écran de Xavier du 02/09 (contexte blmf-teste)`*

#### E14 — Une page pour signaler un bug depuis l'application

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : React / JavaScript, Deno / TypeScript, SQL / PostgreSQL, langue maternelle

**État.** **Demande de Xavier le 07/09/2026.** Vérifié le même jour : **aucun mécanisme de signalement n'existe dans l'app**, à aucun niveau. Pas de table (`bug_reports`, `feedback`, `signalements` — rien ; la seule table d'incidents, `service_health_incidents`, est la supervision automatique), aucune des 52 Edge Functions, aucune route dans `App.jsx` (pas de `/bug`, `/feedback`, `/contato`, `/aide`), aucune clé i18n (`*.bug.*`, `*.feedback.*`), aucun lien vers les issues Codeberg dans `src/` (les seules URL Codeberg de l'app sont dans la politique de confidentialité et le DPA). Le seul courriel de contact général, `mailto:contato@anarbib.org`, est enterré dans `PrivacyPolicyPage.jsx` ; les deux `mailto:anarbib@proton.me` sont réservés à l'onboarding. Le canal documenté vit hors de l'app et côté développeur : `CONTRIBUTING.md` et le README disent « ouvrir une issue sur Codeberg » — inaccessible à une bibliothécaire qui n'a pas de compte là-bas.

**Trois patrons maison existent déjà**, et il n'y a rien à inventer : *(1)* `authority_duplicate_reports` + `report_authority_pair` (staff → coordination, index unique partiel anti-flood sur `status='open'`, `HINT` = clés i18n, `DO $$` de vérification — et son en-tête explique pourquoi une table générique à `entity_type` a été refusée) ; *(2)* `book_reading_note_reports` (modération, `UNIQUE (note_id, reporter)`) ; *(3)* **`cartography_submissions`** — le seul ouvert à `anon` : table verrouillée, Edge Function publique `submit-cartography-entry` avec défi altcha, outbox → `notify-event` vers `fede@anarbib.org`, trio `list/approve/reject`, écran de modération. C'est le modèle 3 qui couvre le besoin, avec l'anti-flood du modèle 1.

*Vérifié : 07/09 — grep sur `src/`, `supabase/functions/` (52 EF), `App.jsx` (routes), `fr.json` ; dépôt `eb790c33`. Aucun mécanisme, aucun item au backlog avant celui-ci.*

**Ce que c'est.** Une page publique « Signaler un problème » (route à nommer, `/signalar` ou `/problema`), accessible **sans compte** et depuis **toutes** les pages : un lien dans le `Footer` (`src/components/layout/index.jsx`, aujourd'hui trois éléments : mention, confidentialité, langue) et une intention « Je veux signaler un problème » dans `intentions.js` (groupe lecteur — une ligne). Formulaire minimal : ce qui s'est passé, ce qui était attendu, comment refaire ; **le contexte se remplit seul** (page d'origine, locale, rôle et bibliothèque de session si connecté, navigateur) ; courriel de réponse facultatif ; jamais de mot de passe ni de capture obligatoire. Côté serveur, calquer `cartography_submissions` : table `bug_reports` verrouillée (`REVOKE ALL FROM anon, authenticated`), Edge Function `submit-bug-report` avec altcha pour les anonymes, outbox → `notify-event` vers `admins@anarbib.org` (le destinataire de supervision, F-domaine), statut `open/closed`, index unique partiel anti-flood, RPC `list/close` réservées aux admins réseau, et un onglet dans Rede (ou la page de modération existante) pour la file. **Deux décisions à prendre en écrivant** : *(a)* pont vers Codeberg (un admin recopie à la main vers une issue — le plus simple et le plus honnête) ou pas de pont ; *(b)* accusé de réception par courriel au signaleur quand il a laissé une adresse. Dix locales d'emblée (parité stricte, `i18n.test.js`), et un test qui garde la route et le `Footer`.

**Pourquoi ça compte.** La formation BLMF commence le 08/09 (sept soirées) : des coordinations vont buter sur des défauts, et la seule voie de retour aujourd'hui est l'oreille de Xavier. Un outil dont on ne peut pas dire qu'il est cassé sans passer par le mainteneur contredit `DOC-COLLECTIVE-1` ; et la promesse d'**A4** (« un premier retour sous une semaine ») n'a pas de porte d'entrée pour qui ne code pas.

**Ce qui compte comme fini.**

- [object Object]
- [object Object]
- [object Object]

**Dépendances.** Aucune bloquante. Voisin de **A4** (accueillir une contribution) et **E12** (le premier retour ergonomique de Xavier n'avait, lui non plus, pas de canal). Réutilise `notify-event` et altcha tels quels.

*Renvois : `src/components/layout/index.jsx (Footer)` · `src/pages/inicio/intentions.js` · `supabase/migrations/20260618182516_cartography_submissions.sql` · `supabase/functions/submit-cartography-entry` · `supabase/migrations/20260821130001_signaler_un_doublon_d_autorite.sql` · `CONTRIBUTING.md`*

#### E15 — Les mots de confirmation « vider l'historique » et « supprimer le compte » sont le même mot dans huit locales sur neuf

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : langue maternelle

**État.** **Vérifié dans `src/i18n/locales/` le 07/09.** En pt-BR, `account.history.deleteAll.confirmWord` = `APAGAR` et `account.deleteAccount.confirmText` = `EXCLUIR` : deux gestes, deux mots. Dans fr, en, es, it, de, nl, el et eo, **les deux clés portent le même mot** (`SUPPRIMER`/`SUPPRIMER`, `DELETE`/`DELETE`…). Seul le catalan distingue (`ELIMINA` / `SUPRIMIR`). Relevé d'abord par le manuel lecteur v2 du 03/09.

*Vérifié : 07/09 — huit paires identiques constatées dans les fichiers de locale.*

**Ce que c'est.** Choisir deux mots distincts par locale, avec les locuteur·rices quand il y en a (**E2** pour nl et el), et mettre le manuel en accord.

**Pourquoi ça compte.** Un mot de confirmation sert à ce qu'on ne confonde pas deux destructions. Quand c'est le même, il ne sert à rien — et c'est précisément `DOC-DESTR-2` : dire ce qu'on détruit.

**Ce qui compte comme fini.**

- Neuf locales, deux mots différents chacune ; le test i18n passe.

**Dépendances.** Aucune.

*Renvois : `claude/MANUEL_LECTEUR_v2_refonte_2026-09-03` · `REGISTRE §0 DOC-DESTR-2`*

#### E16 — La sous-page Privacidade de la Biblioteca afficherait deux messages contradictoires sur la purge automatique

`P2` Courant · État : **À vérifier** · Charge : une soirée · Ce que ça demande : React / JavaScript

**État.** Relevé par la refonte du manuel v5 (01/09) : « deux messages contradictoires sur l'activation de la purge automatique — le manuel demande de vérifier l'instance ». **Non vérifié le 07/09** : c'est un défaut d'écran, à constater dans l'application, pas dans les fichiers.

*Vérifié : 07/09 — non vérifié, constat d'écran seulement.*

**Ce que c'est.** Ouvrir la sous-page sur `blmf-teste`, lire les deux messages, décider lequel dit vrai en regardant le réglage en base, corriger l'autre.

**Pourquoi ça compte.** Un écran de confidentialité qui se contredit fait douter de tout le reste de la page — et c'est la page qu'une coordination lit en premier.

**Ce qui compte comme fini.**

- Un seul message, conforme à l'état réel du réglage.

**Dépendances.** Aucune.

*Renvois : `claude/MANUEL_v5_refonte_2026-09-01 (points à trancher)`*

#### E17 — Le bloc « Explorer » du catalogue s'ouvre replié, pour que la première notice soit visible sans défiler

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : React / JavaScript, langue maternelle

**État.** **Demande de Xavier le 07/09/2026, pour la lisibilité du catalogue.** Dans `CatalogPage.jsx`, le bloc « Explorer » (modes de parcours, alphabet, arbre des sujets, facettes) est escamotable depuis le 21/08 — en-tête `ab-collapse-header`, chevron, `aria-expanded` — mais il naît **ouvert** : `const [exploreOpen, setExploreOpen] = useState(true)`. À chaque visite, la page ouvre donc sur un mur de commandes au-dessus des résultats ; sur mobile, la première notice est sous la ligne de flottaison. Le choix de replier n'est **pas mémorisé** : `saveFilters` enregistre dix-sept préférences dans `anarbib:catalog:filters` (recherche, filtres, tri, `compact`, regroupement par œuvre), pas `exploreOpen` — on replie, on recharge, c'est rouvert. Deux faits qui rendent le repli sans perte : les filtres actifs s'affichent en **puces au-dessus des résultats**, indépendamment du panneau (`hasActiveFilters`, l. 1366), et l'arbre des sujets ne se charge qu'à l'ouverture du panneau (l. 704-715) — replié par défaut, c'est aussi une requête de moins à l'arrivée.

*Vérifié : 07/09 — lu dans le code au commit `4c235923` : `useState(true)`, `saveFilters` sans `exploreOpen`, puces indépendantes du panneau, arbre chargé à l'ouverture.*

**Ce que c'est.** Trois gestes, une soirée. **(1)** `useState(false)` par défaut, et `exploreOpen` ajouté à `saveFilters` / `loadSavedFilters` — le choix de la personne survit au rechargement, comme `compact`. **(2)** L'en-tête replié dit ce qu'il cache, sinon la découverte se perd : « Explorer : sujets, facettes, alphabet », et le nombre de facettes actives en badge quand il y en a (dix locales, clé `catalog.section.explore` à enrichir). **(3)** Un test de source (`src/tests/catalog-explore-replie.test.js`, patron `serial-picker-monte.test.js`) qui garde `useState(false)` et la présence d'`exploreOpen` dans la sauvegarde. Puis vérifier à l'écran, mobile compris : la première notice visible sans défiler, les puces de filtres toujours là panneau replié. Ne pas rouvrir automatiquement quand un filtre est actif : les puces suffisent, et c'est le retour au mur de commandes par la petite porte.

**Pourquoi ça compte.** Le catalogue est la porte d'entrée de toute personne qui n'a pas de compte — celle que la vitrine et la formation montrent en premier. Ce qu'on y cherche, c'est une notice, pas un tableau de bord ; la surface d'exploration doit être à portée de main, pas devant les yeux. Voisin direct de **E9** (mobile) et de la doctrine « la première chose utile visible sans geste ».

**Ce qui compte comme fini.**

- [object Object]
- [object Object]
- [object Object]

**Dépendances.** Aucune. **G13** (réseaux constitués) ajoutera un sélecteur à côté du filtre de bibliothèques, qui est hors du bloc « Explorer » : pas d'interférence.

*Renvois : `src/pages/public/CatalogPage.jsx (exploreOpen l. 325, saveFilters l. 352-355, arbre des sujets l. 704-715, bloc l. 1410-1416)` · `src/pages/public/CatalogPage.css (.ab-explore-toggle, .ab-explore-panel, .ab-collapse-header)` · `src/i18n/locales/*.json (catalog.section.explore)` · `src/tests/serial-picker-monte.test.js (patron de test de source)`*

---

### F — Courriel et notifications

*13 fonctions notify-*, 5 files d'attente, 6 déclencheurs de dépêche. Personne n'a jamais audité l'ensemble.*

| | | | |
|---|---|---|---|
| **F1** | Auditer la chaîne de courriel de bout en bout | `P1` | Ouvert |
| **F3** | Consolider les fonctions de notification redondantes | `P2` | Ouvert |
| **F4** | Trois bibliothèques avaient activé des rappels que personne n'envoyait | `P1` | En cours |
| **F6** | `notify-internal-task` tourne sur une copie gelée de toute la pile courriel | `P2` | Ouvert |
| **F7** | Un transport mail sans service configuré lève ; il ne simule pas en silence | `P1` | Ouvert |
| **F9** | SPF, DKIM et DMARC de `notifications.anarbib.org` n'ont jamais été relevés — trente-six crons envoient du courrier depuis ce domaine | `P1` | À vérifier |
| **F10** | Sortir de Resend : un relais militant à demander, un transport à écrire, l'aiguillage à rétablir — et `sendViaBrevo` traîne encore dans `email.ts` | `P2` | Ouvert |

#### F1 — Auditer la chaîne de courriel de bout en bout

`P1` Prioritaire · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : Deno / TypeScript, SQL / PostgreSQL

**État.** **14 fonctions `notify-*` déployées**, cinq files d'attente, six déclencheurs de dépêche. Trois files n'ont jamais reçu la moindre insertion : `authority_proposal_notification_outbox`, `membership_expiry_notifications`, `painel_internal_task_invitation_outbox`. Une quatrième, `painel_internal_task_notification_outbox`, est vide après 34 insertions dont la dernière date du 04/06. Personne n'a jamais audité l'ensemble.

*Vérifié : 31/08 — **15** fonctions `notify-*` déployées désormais, la quinzième (`notify-loan-cycle`) née le matin même avec F4. Les trois files jamais servies sont toujours à zéro insertion, et `painel_internal_task_notification_outbox` toujours vide après 34. Le périmètre grossit plus vite que l'audit.*

**Ce que c'est.** Dresser la carte : pour chaque événement métier, quel déclencheur, quelle file, quelle fonction, quel gabarit, quelles dix langues. Puis marquer les branches mortes et les branches jamais empruntées.

**Pourquoi ça compte.** Une notification qui ne part pas ne fait aucun bruit. C'est le même angle mort que les sauvegardes, et il a déjà mordu deux fois : les mails `retirada_efetivada`, `retirada_reagendada`, `retirada_no_show` et `liberada_para_circulacao` ont été signalés comme ne partant pas, sans que le diagnostic soit mené à son terme.

**Ce qui compte comme fini.**

- Une carte écrite, événement par événement.
- Les quatre mails signalés comme non partants ont un verdict : corrigés, ou expliqués.
- Les branches mortes sont supprimées ou documentées comme dormantes.

**Dépendances.** Prérequis de **F2** et **F3**.

*Renvois : `Mémoire de projet, reliquats de la chaîne courriel` · `AUDITORIA_NOTIFY_FUNCTIONS_2026-05-06`*

#### F3 — Consolider les fonctions de notification redondantes

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : Deno / TypeScript

**État.** Quatre fonctions font des récapitulatifs : `notify-weekly-report`, `notify-network-weekly-report`, `notify-cross-library-digest`, `notify-rede-digest`. Trois fonctions servent des documents : `read-pdf`, `read-digital-asset`, `read-ill-shared-asset`. Deux exportent des lots : `export-catalog-lote`, `export-fonds-bundle`. Et `mail-i18n-test`, fonction de test, est déployée en production en version 1553.

*Vérifié : 31/08 — `mail-i18n-test` est toujours déployée en production (version 1 566, retouchée le jour même par un déploiement groupé). Le dépôt compte 50 dossiers de fonctions hors `_shared`, et `config.toml` porte 38 déclarations `verify_jwt`.*

**Ce que c'est.** Vérifier ce que chacune fait vraiment avant de conclure à la redondance — elles ont probablement des destinataires et des portées différentes. Puis fusionner ce qui doit l'être, et retirer `mail-i18n-test` de la production.

**Pourquoi ça compte.** 48 fonctions déployées, c'est beaucoup à maintenir pour un projet à un mainteneur. Chacune porte son propre gabarit, ses propres dix langues, ses propres secrets. Ce n'est pas un problème de performance, c'est un problème de surface à relire.

**Ce qui compte comme fini.**

- Chaque groupe a un verdict : fusion, ou raison écrite de la séparation.
- `mail-i18n-test` n'est plus déployée en production.
- Le compte de fonctions déployées est à jour dans `CLAUDE.md` et dans `config.toml`.

**Dépendances.** Après **F1**. Attention : le déploiement de `notify-event` ne passe pas par MCP, son paquet est trop gros.

*Renvois : `PLAN_DE_MARCHE §8` · `Relevé du 29/08/2026`*

#### F4 — Trois bibliothèques avaient activé des rappels que personne n'envoyait

`P1` Prioritaire · État : **En cours** · Charge : quelques jours · Ce que ça demande : SQL / PostgreSQL

**État.** `spec-flux-emprunts.md` §10.2 prévoit des rappels à J-5, J-3 et le jour même, puis des relances à J+1, J+7 et J+30. **Aucun job dédié n'est identifiable** parmi les 36 crons ; le seul voisin est `anarbib-notify-mid-loan-reading-daily`, qui fait autre chose. `membership_expiry_notifications` n'a jamais reçu la moindre ligne.

**Vérifié le 30/08 : le manque est confirmé.** Les onze crons dont le nom évoque une échéance ou une relance ont été relus un par un — cooptation, adhésions, invitations d'équipe, votes OAI, réservations, autorités, cercles, et `anarbib-peb-detect-overdue-daily` qui concerne le **prêt entre bibliothèques**, pas le prêt aux lectrices. **Aucun ne rappelle une échéance d'emprunt ni ne relance un retard.** Le doute est levé : ce n'est plus un item à vérifier, c'est une décision à prendre.

**Instruit et livré le 31/08 — et le constat était encore trop petit.** Les rappels n'existaient pas, c'était établi. Ce qui ne l'était pas : **les interrupteurs qui les commandent, eux, existent**. `library_notification_policies` porte `loan_reminders_enabled` et `loan_overdue_enabled`, exposés dans `v_library_notification_context` — la vue que lit la pile courriel. En production, **les trois bibliothèques dotées d'une politique les ont à `true`** : non parce qu'elles les ont activés, mais parce qu'ils naissent activés (« Default : tous à `true` », §2.4). Trois bibliothèques se croyaient couvertes par un dispositif absent — cas *(a)* de `DOC-SILENCE-1`, et même mécanique que le privilège `anon` retourné le même jour.

**La référence de l'item était fausse** : la règle n'est pas au §10.2 — qui dit « hors périmètre, dette à confirmer » — mais au **§2.4**. Les deux sections sont amendées.

**Six moments deviennent trois** (`DOC-RAPPEL-1`) : J-3, le jour de l'échéance, J+7. Motif `OPS-8` — un signal qui se répète cesse d'être lu, et une lectrice émoussée ne referme pas un ticket, elle cesse d'emprunter.

**Un quatrième envoi en remplace un autre.** `notify-mid-loan-reading` demandait « Como vai a leitura? » — une question à laquelle un courriel ne permet pas de répondre — **en portugais en dur**, quelle que soit la langue de la lectrice. À mi-parcours, on invite désormais à déposer une **note de lecture sous pseudonyme** dans le catalogue : `book_reading_notes` est construite, déployée, et n'avait jamais reçu une seule ligne, et l'écran d'écriture existe déjà sur la page de l'œuvre. Son cron est désactivé — garder les deux, ce serait deux courriels le même jour.

**Livré** : EF `notify-loan-cycle` (quatre moments, dix locales, 120 chaînes), table `loan_cycle_notifications` avec unicité (item, moment) — sans elle un cron rejoué enverrait deux fois le même rappel —, interrupteur `reading_notes_invite_enabled` né en même temps que l'envoi qu'il gouverne, cron quotidien à 9h15 UTC, suite `rappels_echeance_tests.sql` (7 tests, dont un qui écrit).

*Vérifié : 31/08 — relevé en base (36 crons relus, aucun pour le prêt aux lectrices ; 3 bibliothèques avec les deux interrupteurs à `true` ; `book_reading_notes` à zéro ligne) et dans le dépôt (l'ancien mi-parcours écrit en portugais en dur, aucune colonne de blog nulle part). Livré le jour même ; **pas encore éprouvé en envoi réel**.*

**Ce que c'est.** Voir la CI verte, déployer, puis **éprouver pour de bon** : créer un emprunt dont l'échéance tombe à J-3 et vérifier qu'un courriel part, dans la bonne langue, une seule fois. C'est la leçon d'`I5` : ne pas livrer un envoi sans l'avoir vu partir.

**Pourquoi ça compte.** Le suivi de huit semaines de la formation BLMF prévoit qu'une consulta soit menée de bout en bout avec négociation réelle : c'est le moment où l'absence de rappel se verra. Autant le savoir avant.

**Ce qui compte comme fini.**

- [object Object]
- [object Object]
- [object Object]
- [object Object]
- [object Object]

**Dépendances.** Se vérifie en même temps que **F1**.

*Renvois : `spec-flux-emprunts §2.4 et §10.2` · `REGISTRE DOC-RAPPEL-1, OPS-8, DOC-SILENCE-1` · `supabase/functions/notify-loan-cycle/` · `migration 20260831111700` · `tests/sql/rappels_echeance_tests.sql` · `public.book_reading_notes`*

#### F6 — `notify-internal-task` tourne sur une copie gelée de toute la pile courriel

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : Deno / TypeScript

**État.** **La divergence de signature est refermée le 30/08.** `resolveMailRouting` de la copie accepte désormais une locale et lit `signature_short_i18n[locale]`, à l'identique du canonique ; `renderEmail` la transmet, et les trois envois du gestionnaire passent la leur — elle était déjà calculée quatre lignes plus haut à chaque fois, par `normalizeTaskLocale`. Un avis de tâche à la BLMF est maintenant signé dans la langue de qui le lit. Gardé par `src/tests/notify-internal-task-signature.test.js`, 6 tests qui exercent le vrai fichier sur le contexte réel de la BLMF — dont un qui vérifie que **sans locale, le comportement est exactement celui d'avant**.

**Ce qui reste ouvert, et c'est le gros :** les 9 fichiers d'infrastructure dupliqués. Le relevé ci-dessous ne bouge pas.

**Mesuré le 30/08, après ouverture de l'item.** Il y a bien trois arbres `_shared` sous `supabase/functions/`, mais ils ne pèsent pas le même poids : celui de `catalog_metadata_lookup` ne contient qu'un `cors.ts` sans équivalent canonique — ce n'est pas une duplication. Le cas réel est `notify-internal-task`.

Ses 12 fichiers se répartissent ainsi : **3 sont légitimement privés** (`data/internal-tasks.ts`, `handlers/internal-task.ts`, `i18n/task-mail-strings.ts`, absents du canonique) et **9 sont de l'infrastructure dupliquée, toute divergente** — `library-mail-routing` (116 lignes d'écart), `library-notification-context` (122), `mail/layout` (140), `transport/email` (121), `shared/format` (89), `context/policies` (42), `core/webhook` (30), `core/env` (10), `shared/branding` (4). Environ **694 lignes** au total.

**Pourquoi ces copies existent : la question n'a pas de réponse dans le dépôt.** Elles apparaissent dans le TOUT PREMIER commit (`e6ec991a`, 21/08/2026) — 1 479 fichiers et 615 892 insertions sous un message qui parle d'un bouton de l'écran de catalogage. C'est l'import initial du dépôt : l'histoire ne commence pas avant. Aucune décision n'est écrite nulle part.

**Ce qui diverge vraiment, vérifié :** le canonique résout la signature de pied de page en `signature_short_i18n[locale]` avec repli sur `signature_short` ; la copie ne connaît que `signature_short`, et son `resolveMailRouting` n'accepte même pas de locale. **La BLMF a `signature_short_i18n` rempli en six langues.** Ses avis de tâche interne sont donc signés « Equipe da BLMF » quelle que soit la langue de la personne, là où tous les autres courriels de la même bibliothèque disent « L'équipe de la BLMF » à qui lit en français.

**Ce qui NE diverge pas, vérifié aussi :** `transportDisabledReason` est identique octet pour octet dans les deux copies, et le contexte de la copie lit bien `channel_active`. L'interrupteur d'envoi rendu réel le 30/08 est donc honoré ici comme ailleurs. `policyEnabled` et `resolveNetworkLogoUrl`, présents dans la copie seule, ne sont appelés par personne.

*Vérifié : 30/08 — relevé fait fichier par fichier, après ouverture de l'item : 9 fichiers dupliqués et tous divergents, ~694 lignes, et **une seule divergence à effet observable** — la signature de pied de page non traduite, **refermée le soir même et gardée par 6 tests**. L'origine des copies n'a pas de réponse dans le dépôt : elles sont dans le premier commit. Ce qui reste est une décision de portée, pas une mesure.*

**Ce que c'est.** La première question de l'item — *pourquoi ces copies existent* — est close : elles précèdent l'histoire du dépôt, aucune décision n'est écrite. Il faut donc trancher **sur le fond**, pas par archéologie.

**Le plus petit geste utile**, si on ne veut pas ouvrir le chantier : donner à `resolveMailRouting` de la copie le paramètre `locale` et la lecture de `signature_short_i18n`, à l'identique du canonique. Ça referme la seule divergence dont on a constaté l'effet.

**Le geste complet** : faire pointer les 9 fichiers d'infrastructure de `notify-internal-task` vers `../../_shared/`, et ne garder en propre que les 3 fichiers de tâches. Le risque n'est pas nul — 694 lignes d'écart contiennent peut-être d'autres différences voulues — donc chaque fichier se reprend un par un, en comparant les envois avant/après sur un avis de tâche réel.

**Et dans les deux cas** : écrire en tête de `notify-internal-task/_shared/` ce qui y vit et pourquoi, pour que la prochaine personne n'ait pas à refaire ce relevé.

**Pourquoi ça compte.** Parce que le routage du courriel est justement l'endroit où une divergence ne se voit pas. Un logo résolu autrement, une règle d'extinction appliquée dans une copie et pas dans l'autre : le message part quand même, et personne ne compare deux courriels envoyés par deux fonctions différentes.

C'est exactement ce qui vient de se produire à l'échelle d'une seule colonne — `register` résolvait le logo autrement que toutes les autres fonctions, et l'écart a tenu des mois. Ici l'écart porte sur 139 lignes.

**Ce qui compte comme fini.**

- ~~La divergence de signature localisée est refermée~~ — fait le 30/08, gardé par 6 tests.
- Le sort des 9 fichiers d'infrastructure dupliqués est tranché — réunis, ou assumés par écrit.
- Un en-tête dans `notify-internal-task/_shared/` dit ce qui y vit et pourquoi.
- La collision de nom sur `resolveLibraryLogoUrl` est levée.

**Dépendances.** Aucune. Le relevé est fait — il est dans cet item. Ce qui reste est une décision de portée, pas une enquête.

*Renvois : `supabase/functions/_shared/context/library-mail-routing.ts` · `supabase/functions/notify-internal-task/_shared/ (12 fichiers, dont 9 dupliqués)` · `library_notification_profiles.signature_short_i18n (BLMF, 6 langues)` · `commit e6ec991a — import initial du dépôt, 21/08/2026` · `src/tests/notify-internal-task-signature.test.js`*

#### F7 — Un transport mail sans service configuré lève ; il ne simule pas en silence

`P1` Prioritaire · État : **Ouvert** · Charge : une soirée · Ce que ça demande : Deno / TypeScript

**État.** La PR #28 ajoute un transport hybride SMTP / Resend / « mock » dans `_shared/transport/email.ts` et dans les deux copies locales de `notify-library-request` et `notify-document-permission-request` : sans `SMTP_HOST` ni `RESEND_API_KEY`, `sendEmail` rend `{ok:true, mocked:true}` et journalise. C'est le cas *(a)* de `DOC-SILENCE-1`, et la forme exacte de son occurrence (1). En prod la clé Resend existe, rien ne change aujourd'hui ; le jour où le secret manque, la prod répondra 200 en n'envoyant rien. L'aiguillage SMTP/Resend, lui, est correct (`SMTP_HOST` posé ⇒ SMTP sauf `MAIL_TRANSPORT=resend`), et le client SMTP maison (`smtp.ts`) est propre. **D4 (21 h 30)** : côté installateur, la simulation devient l'option 3, jamais par défaut.

*Vérifié : 06/09 — PR #28 relue en entier (46 fichiers, tête `b5782ec1`), production interrogée en lecture seule, constat `CONSTAT_PR28_rejeu_vs_production_revoke_anon_2026-09-06`.*

**Ce que c'est.** Règle à demander dans la PR et à écrire dans `spec-migration-mail-resend` : le mock **uniquement** sur `MAIL_TRANSPORT=mock` explicite (c'est ce qu'`install.sh` écrit déjà pour l'option 1) ; sans configuration, lever comme avant. Et une seule implémentation : les deux `notify-*` doivent appeler `_shared/transport/email.ts` au lieu d'en porter une copie — la PR a étendu les trois.

**Pourquoi ça compte.** Une coordination a cru pendant des mois avoir coupé ses notifications ; le contraire — croire qu'elles partent — coûte les rappels d'échéance et les circuits collégiaux, qui s'arrêtent sans bruit (`GOUV-17`).

**Ce qui compte comme fini.**

- Sans `MAIL_TRANSPORT=mock`, une fonction sans service mail configuré lève et son appel rend une erreur lisible.
- Une seule fonction d'envoi dans `_shared/`, appelée par toutes les EF qui écrivent.

**Dépendances.** Relecture de la PR « code applicatif » (**I16**).

*Renvois : `supabase/functions/_shared/transport/email.ts` · `REGISTRE §0 DOC-SILENCE-1` · `docs/specs/spec-migration-mail-resend.md` · `codeberg.org/anarbib/anarbib/pulls/28`*

#### F9 — SPF, DKIM et DMARC de `notifications.anarbib.org` n'ont jamais été relevés — trente-six crons envoient du courrier depuis ce domaine

`P1` Prioritaire · État : **À vérifier** · Charge : une soirée · Ce que ça demande : administration système

**État.** Relevé le 31/08 dans la reprise : « jamais relevés ; trois `Resolve-DnsName` suffisent ; à faire avant le 10/09 ». **Le 07/09, impossible à vérifier** : ni le conteneur ni la VM de travail n'atteignent un résolveur DNS. Aucune trace ailleurs que ce relevé ne dit que c'est fait.

*Vérifié : 07/09 — non vérifiable depuis ici ; aucune trace que ce soit fait.*

**Ce que c'est.** Depuis PowerShell : `Resolve-DnsName notifications.anarbib.org -Type TXT`, `Resolve-DnsName _dmarc.notifications.anarbib.org -Type TXT`, et le sélecteur DKIM affiché par le tableau de bord Resend. Coller les trois réponses ici, datées. Si DMARC manque, poser `p=none` avec une adresse de rapport avant de durcir.

**Pourquoi ça compte.** Le 10/09, l'invitation de **F4** part sur ce domaine, deux jours avant Bologne. Un courrier qui tombe en indésirable ne se voit pas dans les logs — il se voit dans le silence de la lectrice.

**Ce qui compte comme fini.**

- Les trois enregistrements relevés et collés dans cet item, avec la date.

**Dépendances.** Avant **F4** (10/09). Entre dans **F1** (audit) mais ne l'attend pas.

*Renvois : `claude/REPRISE_2026-09-01_douze_jours_avant_bologne`*

#### F10 — Sortir de Resend : un relais militant à demander, un transport à écrire, l'aiguillage à rétablir — et `sendViaBrevo` traîne encore dans `email.ts`

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : Deno / TypeScript, délibération collective

**État.** **Vérifié dans le dépôt le 07/09** : `supabase/functions/_shared/transport/email.ts` connaît deux transports, `sendViaResend` et `sendViaBrevo` — le second survit au retrait de Brevo (R.6/R.7, annoncé clos). Aucun transport SMTP générique, donc aucun moyen de brancher un relais militant (ARN, Nodo50, bida.im) le jour où l'un dit oui. La note du 05-06/09 place cette sortie après Bologne, derrière la demande d'un relais SMTP le 12.

*Vérifié : 07/09 — deux transports dans `email.ts`, aucun SMTP.*

**Ce que c'est.** Demander avant de choisir (les relais militants d'abord, Scaleway en repli) ; écrire `sendViaSmtp` (ou le transport retenu) et rétablir un aiguillage par variable ; supprimer `sendViaBrevo` ; ne faire lever que ce qui doit lever (**F7** est clos là-dessus).

**Pourquoi ça compte.** Resend est le dernier service états-unien après Supabase. Sortir de l'un sans l'autre laisse la moitié de la dépendance, et la moitié la plus bavarde : le courriel des lectrices.

**Ce qui compte comme fini.**

- Un courriel réel part par le nouveau transport, depuis la production, vers une boîte tierce.
- `sendViaBrevo` n'existe plus dans le dépôt.

**Dépendances.** Après **K5** (relais demandé à Bologne). Pas avant **I2** : changer de transport et d'hébergeur la même semaine, c'est deux inconnues.

*Renvois : `claude/NOTE_sortie_services_etats_uniens_2026-09-05 (chemin, étape 4)` · `spec-migration-mail-resend`*

---

### G — Réseau, gouvernance, fédération

*Beaucoup de circuits construits, très peu empruntés. C'est le principal enseignement du relevé.*

| | | | |
|---|---|---|---|
| **G1** | Emprunter les circuits construits et jamais utilisés | `P0` | Ouvert |
| **G6** | Donner un écran au prêt entre bibliothèques | `P2` | Ouvert |
| **G7** | Décider de l'admission de la Bibliothèque SOLIDAIRES | `P1` | Bloqué |
| **G8** | Compléter la cartographie avec les archives repérées ailleurs | `P2` | Ouvert |
| **G9** | Implémenter la cartographie du réseau selon la spec v1.0 | `P3` | Gelé |
| **G10** | Solder les trois questions d'onboarding marquées « au plus vite » | `P2` | Ouvert |
| **G11** | Le premier administrateur d'une instance : écrire la règle d'amorçage | `P0` | Ouvert |
| **G12** | Une instance = un réseau ; entre instances, seul le catalogue traverse | `P2` | Ouvert |
| **G13** | Un commutateur « réseaux constitués » à l'OPAC : ne voir que les catalogues FICEDL, RebAL, NORLA… | `P2` | Ouvert |
| **G14** | Une invitation d'équipe attend depuis le 30/08 et expirera le 29/09 — la personne ne le sait peut-être pas | `P2` | Ouvert |

#### G1 — Emprunter les circuits construits et jamais utilisés

`P0` Structurel · État : **Ouvert** · Charge : plusieurs semaines · Ce que ça demande : délibération collective, aucune compétence technique

**État.** Vérifié le 29/08 : **62 tables métier n'ont jamais reçu la moindre insertion.** Sept blocs entiers sont concernés — assemblées du réseau (3 tables), notes de lecture (2), propositions et objections d'autorité (3), référentiels de catalogage `catalog_ref_*` (8 sur 9), gouvernance des profils de bibliothèque (4, **alors que deux crons tournent dessus toutes les quinze minutes**), délibération sur les demandes d'adhésion (5, dont `library_request_votes` et `library_request_messages`).

**Remesuré le 31/08 : toujours 62, et ce n'est pas une bonne nouvelle.** Le compte n'a pas bougé en deux jours — 62 tables de `public` sur 189 n'ont jamais reçu la moindre insertion. Mais ce n'est pas la même liste : `loan_cycle_notifications`, née ce matin avec les rappels d'échéance, y est entrée **le jour de sa création**. Un circuit livré aujourd'hui rejoint aussitôt la colonne des circuits jamais empruntés — c'est exactement le mécanisme que cet item nomme, et il continue de tourner pendant qu'on le décrit.

**Un premier livre circule.** L'emprunt **#69** a été ouvert ce matin à 11 h 43 à la BLMF — item 84, *O Anarquismo na Escola, no Teatro, na Poesia* d'Edgar Rodrigues, échéance **21/09**. Il donne au bloc *notes de lecture* sa première chance réelle : le mi-parcours calculé par `notify-loan-cycle` tombe le **10 septembre**, et l'invitation à déposer une note sous pseudonyme partira ce jour-là (item **F4**). `book_reading_notes` est encore à zéro ligne ; si elle en porte une le 11, un des sept blocs sera sorti de cette liste pour de bon — et pas parce qu'on l'aura décidé, parce que quelqu'un l'aura emprunté.

Les six autres blocs sont inchangés au 31/08, vérifiés table par table : assemblées du réseau (3), propositions et objections d'autorité (3), référentiels `catalog_ref_*` (8), gouvernance des profils de bibliothèque (4, **et les deux crons tournent toujours dessus toutes les quinze minutes**), délibération des demandes d'adhésion (5). Tous à zéro insertion.

*Vérifié : 31/08 — remesuré en production : **62 tables de `public` sur 189** à zéro insertion (`pg_stat_user_tables.n_tup_ins`, croisé avec un décompte de lignes sur les tables citées). Le compte est stable, la liste ne l'est pas — `loan_cycle_notifications` y est entrée le jour de sa naissance. Emprunt **#69** ouvert à la BLMF ; l'invitation à écrire une note de lecture est attendue le **10/09**, et c'est la première sortie possible de cette liste. **06/09** — deux circuits de plus sont construits sans être empruntés : **l'atelier ouvert aux œuvres** (05/09 soir, cinq types de proposition, file « corrige-moi » de 1 452 titres) compte **0 proposition** ; la **révision des lots importés** (05/09) compte **0 révision** (`catalog_batch_reviews` vide) ; et `network_contributors` est toujours à **0** — l'atelier des autorités lui-même n'avait jamais reçu une proposition avant le 05/09. La liste des circuits jamais empruntés s'allonge plus vite qu'elle ne se vide.*

**Ce que c'est.** Choisir un bloc et l'emprunter pour de vrai, du premier geste au dernier : tenir une assemblée du réseau, déposer une note de lecture, proposer une autorité et laisser quelqu'un objecter, faire délibérer une demande d'adhésion. Consigner ce qui manque, ce qui surprend, ce qui bloque.

**Pourquoi ça compte.** C'est le principal enseignement du relevé du 29 août, et il ne figure dans aucun document du corpus. **Le projet ne souffre pas d'un manque de fonctionnalités : il souffre d'un manque d'usage.** Un circuit jamais emprunté n'est pas livré — il est seulement écrit. Et le jour où il devient le chemin critique, comme le circuit d'invitation vient de le devenir pour les promotions, il casse sur des choses qu'un seul passage aurait révélées.

**Ce qui compte comme fini.**

- Au moins trois des sept blocs ont été empruntés de bout en bout, sur `blmf-teste` puis en réel.
- Chaque passage a produit un compte rendu écrit de ce qui manque.
- Les blocs dont l'usage n'est pas souhaité aujourd'hui sont marqués **dormants**, avec la raison — ce n'est pas un échec, c'est une information.

**Dépendances.** Le bloc « assemblée » dépend de **A1**. Les autres non.

*Renvois : `Relevé du 29/08/2026` · `REGISTRE §32 AG, §28 ATE, §26 ONBO` · `emprunt #69 (BLMF, item 84, échéance 21/09)` · `item F4` · `public.book_reading_notes`*

#### G6 — Donner un écran au prêt entre bibliothèques

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : React / JavaScript, bibliothéconomie

**État.** Le cycle de vie du prêt entre bibliothèques est spécifié et implémenté en base : machine à états verrouillée, quatre triggers, cron `anarbib-peb-detect-overdue-daily` actif. **Aucun écran n'existe.** La base porte 2 prêts pour 20 insertions historiques.

*Vérifié : 31/08 — `interlibrary_loans_v2` : 2 prêts vivants pour 20 insertions historiques, comme au 29/08.*

**Ce que c'est.** Un écran de demande côté bibliothèque emprunteuse, un écran de traitement côté prêteuse, et l'affichage de l'état pour les deux. Les vues `interlibrary_loans_painel_ui` et `interlibrary_loan_items_ui` existent déjà.

**Pourquoi ça compte.** Le prêt entre bibliothèques est ce qui rend un réseau fédératif utile à ses lectrices, plutôt qu'une simple juxtaposition de catalogues. Aujourd'hui il a « une amorce en base, même sans écran » — ce qui veut dire que personne ne peut s'en servir.

**Ce qui compte comme fini.**

- Un prêt complet a été fait entre deux bibliothèques du réseau, par l'interface.
- Le flux « livre perdu ou abîmé » a un traitement écrit — **aucun flux ne le couvre aujourd'hui**, il se traite hors SIGB avec remontée en coordination.

**Dépendances.** `EA-12 phase 2` (parité PEB, environ 45 fonctions) est gelée par `BIBLIO-9` — à ne pas confondre avec cet item.

*Renvois : `spec-cycle-vie-peb.md` · `PLAN_formation_coordination_BLMF §5` · `REGISTRE §14 PEB`*

#### G7 — Décider de l'admission de la Bibliothèque SOLIDAIRES

`P1` Prioritaire · État : **Bloqué** · Charge : non chiffré · Ce que ça demande : délibération collective

**État.** Décision fédérale **volontairement différée**, faute de pouvoir être prise à plusieurs. Échéance envisagée : octobre ou novembre, après Bologne.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Une fois **A1** abouti, instruire la demande à plusieurs et trancher.

**Pourquoi ça compte.** La contrainte est écrite noir sur blanc au collectif et elle est absolue : **ne pas créer de bibliothèque « SOLIDAIRES » en base** tant que la décision n'est pas prise, ni membre, ni partenaire, ni cible. « Créer la fiche reviendrait à inscrire en base une décision qu'on dit ne pas prendre. » **Et depuis le 29/08 la même règle vaut pour le fonds : l'import des 1 685 notices (C2) ne se fera qu'après l'admission.** Cet item ne décide donc pas seulement d'une adhésion : il débloque un chantier de catalogage entier.

**Ce qui compte comme fini.**

- La décision est prise à trois au moins, et tracée dans `network_administrator_audit`.
- Quelle qu'elle soit, elle est communiquée au collectif SOLIDAIRES avec sa raison.
- Une fois l'admission prononcée, **C2** et **D3** se débloquent dans cet ordre.

**Dépendances.** **Bloqué par A1.** Même remarque pour la demande d'adhésion belge en cours d'évaluation.

*Renvois : `REPRISE_claude_code_2026-08-27` · `CALENDRIER_bologne_2026-08-27`*

#### G8 — Compléter la cartographie avec les archives repérées ailleurs

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : bibliothéconomie, aucune compétence technique

**État.** `cartography_entries` porte 187 fiches et le fichier `anarbib_bibliotheques_libertaires.geojson` en compte 121. Neuf archives repérées dans le réseau NORLA n'ont pas été confrontées à cette liste.

*Vérifié : 31/08 — 187 fiches en base, inchangé. Le fichier public a changé d'adresse et de contenu : `data/carte-publique.geojson` du dépôt vitrine, **109** entrées (l'item en citait 121 sous l'ancien nom). Les neuf archives NORLA restent à confronter.*

**Ce que c'est.** Vérifier lesquelles des neuf figurent déjà, et faire entrer les manquantes avec `source = "FICEDL"` ou `"NORLA"` selon leur provenance.

**Pourquoi ça compte.** La carte n'a d'intérêt que si elle est plus complète que ce que chacun connaît déjà. Et la traçabilité de la source est ce qui permettra plus tard de dire d'où vient chaque fiche sans avoir à redemander.

**Ce qui compte comme fini.**

- Les neuf archives ont un verdict : déjà présente, ou ajoutée avec sa source.
- Rappel : `statut_public` est à `FALSE` par défaut et **aucun import en masse** n'est autorisé (`MAP-E`).

**Dépendances.** Aucune. **Entrée sans compétence technique.**

*Renvois : `VEILLE_leftovers_maydayrooms_2026-08-19 §3.4` · `REGISTRE §34 MAP-E`*

#### G9 — Implémenter la cartographie du réseau selon la spec v1.0

`P3` Différé · État : **Gelé** · Charge : plusieurs semaines · Ce que ça demande : React / JavaScript

**État.** Les arbitrages sont tranchés depuis le 18/06 : table dédiée, i18n hybride, carte publique comme route de l'application, moteur Leaflet, OpenStreetMap et Nominatim auto-hébergés, entrées non membres affichées avec un filtre clair. `MAP-I` (statut du prêt entre bibliothèques sur la carte interne) et `MAP-J` (auto-déclaration « ajouter ma bibliothèque » avec modération) restent différés. **L'implémentation est calendée post-Bologne, fin 2026 ou 2027.**

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Reprendre la spec v1.0 quand la fenêtre s'ouvre. Attention : le REGISTRE porte **deux sections `MAP`** — le §2 est un squelette où tout est ouvert, le §34 est la version tranchée. Le §2 n'a ni tampon de supersession ni renvoi vers le §34 : **c'est le §34 qui vaut**.

**Pourquoi ça compte.** La carte est le premier objet qu'une bibliothèque qui découvre le réseau va regarder. Elle mérite d'être faite quand il y aura du temps pour la faire bien, et pas dans la fenêtre d'avant Bologne.

**Ce qui compte comme fini.**

- La carte publique est une route de l'application, servie sans requête vers un tiers (voir **E5**).
- Le §2 du REGISTRE porte un renvoi vers le §34.

**Dépendances.** Après Bologne. Lié à **E5** et **J5**.

*Renvois : `spec-cartographie-reseau.md v1.0` · `REGISTRE §34 MAP`*

#### G10 — Solder les trois questions d'onboarding marquées « au plus vite »

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : délibération collective

**État.** Trois points sont marqués 🔴 « à résoudre au plus vite » depuis juin et n'ont pas bougé : `#111` (évaluation collaborative d'un·e administrateur·rice réseau, dormante), `ONBO-Q13` (transfert technique du mandat de coordination), et la finition du volet 10 de l'atelier d'onboarding.

*Vérifié : 07/09 — dans le dépôt : `fn_activate_approved_library_request` n'est appelée par **aucun** composant de `src/` — « Concluir a constituição » ne vaut donc pas activation, comme le manuel v5 l'avait relevé le 01/09. C'est la quatrième question d'onboarding, ou la première.*

**Ce que c'est.** Les trois se traitent ensemble parce qu'ils portent la même question : que se passe-t-il quand quelqu'un arrive, et quand quelqu'un part ?

**Pourquoi ça compte.** `ONBO-Q13` est le cas de figure d'une coordination qui change de mains. Aujourd'hui, une bibliothèque dont la personne coordinatrice disparaît n'a pas de chemin écrit. C'est exactement le risque que **A1** décrit à l'échelle du réseau, à l'échelle d'une bibliothèque cette fois.

**Ce qui compte comme fini.**

- Le transfert de mandat a un chemin écrit et éprouvé sur `blmf-teste`.
- `#111` a un verdict : réveillée, ou fermée.
- Le volet 10 est fini.

**Dépendances.** Éclairé par **G3** (le circuit d'invitation est le même).

*Renvois : `REGISTRE §26 ONBO-Q13` · `spec-onboarding-biblioteca-v2.0`*

#### G11 — Le premier administrateur d'une instance : écrire la règle d'amorçage

`P0` Structurel · État : **Ouvert** · Charge : une soirée · Ce que ça demande : administration système

**État.** Le circuit des administrateurs réseau est entièrement collégial (cooptation, retrait) et suppose qu'il en existe déjà un ; sur une base vide, personne ne peut proposer personne. La première ligne de `network_administrators` s'est écrite à la main en mai 2026 et cette exception n'est inscrite nulle part. `seed-admin.mjs` (PR #28) refait ce geste par script : compte GoTrue, profil, bibliothèque `demo` si la table est vide (reste `private`), rôles `coordenador` + `librarian`, ligne admin ; il refuse de tourner s'il existe déjà un admin actif. En mode local, identifiants en dur `admin@anarbib.local` / `anarbib-admin` — publiés par le guide vitrine (pages PR #2). Le script est juste vis-à-vis du schéma prod (colonnes, `UNIQUE (user_id, library_id, role)`, PK). **Tranché le 06/09 au soir (Xavier) : A + B + C + D′** — amorçage unique hors circuit, mot de passe aléatoire dans tous les modes, premier compte = coordination de la première biblio et admin réseau, l'installateur demande le nom de la bibliothèque. Reste à l'appliquer dans `seed-admin.mjs` et `install.sh` (PR #28) et à le dire dans `deploy/README.md`. **D3 tranchée (21 h 30)** : sur entrée vide, l'installateur **refuse et redemande** le nom — pas de « Bibliothèque Autonome » par défaut.

*Vérifié : 06/09 — PR #28 relue en entier (46 fichiers, tête `b5782ec1`), production interrogée en lecture seule, constat `CONSTAT_PR28_rejeu_vs_production_revoke_anon_2026-09-06`.*

**Ce que c'est.** Trancher et inscrire au REGISTRE (`GOUV-19`) : *(a)* l'amorçage d'une base vide écrit un premier compte hors circuit, une fois, et le script refuse sinon ; *(b)* mot de passe aléatoire dans tous les modes, affiché une fois ; *(c)* le premier compte est-il coordinateur de la première biblio, admin réseau, ou les deux ? *(d)* la biblio `demo` : la créer, ou demander son nom à l'installation ?

**Pourquoi ça compte.** Sans règle écrite, l'amorçage devient une porte : un script qui « crée un admin » se relance, se copie, se documente comme une commodité. Avec une règle, c'est un geste unique, nommé, refusé dès qu'il existe quelqu'un.

**Ce qui compte comme fini.**

- `GOUV-19` est acté au REGISTRE avec les quatre réponses.
- `seed-admin.mjs` les applique et `deploy/README.md` le présente comme l'amorçage, pas comme une création de compte.

**Dépendances.** PR #28 scindée (**I16**) : le morceau est à proposer à Bastien.

*Renvois : `REGISTRE §41 GOUV-19` · `deploy/scripts/seed-admin.mjs (PR #28)` · `journal/arbitrages/QUESTIONS_pr28_contribution_exterieure_2026-09-06`*

#### G12 — Une instance = un réseau ; entre instances, seul le catalogue traverse

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : langue maternelle, aucune compétence technique

**État.** Chaque installation auto-hébergée est un réseau à elle seule : sa base, ses bibliothèques, ses admins, ses assemblées. Ce qui traverse d'une instance à l'autre aujourd'hui : le catalogue, par OAI-PMH — chaque instance le sert (`oai-pmh-provider`) et peut moissonner celui d'une autre (`harvest-oai-pmh`) vers sa file de révision, sur décision admin. Ce qui ne traverse pas : comptes, appartenances, prêts entre bibliothèques, gouvernance, gazette. Le guide vitrine de Bastien promet « coopérer avec les autres camarades du réseau » sans cette distinction. **Tranché le 06/09 au soir (Xavier) : A** — la doctrine est inscrite telle quelle (`FED-O11` ✅) ; aucun annuaire d'instances ouvert. Reste : faire dire la phrase au guide vitrine (**J3**) et à `deploy/README.md`.

*Vérifié : 06/09 — PR #28 relue en entier (46 fichiers, tête `b5782ec1`), production interrogée en lecture seule, constat `CONSTAT_PR28_rejeu_vs_production_revoke_anon_2026-09-06`.*

**Ce que c'est.** Inscrire la doctrine au REGISTRE (`FED-O11`) et la faire dire au site vitrine dans les mêmes termes. Un **annuaire des instances** (pour que la moisson ne dépende pas d'une adresse tapée à la main) serait le premier pas utile — c'est un domaine nouveau, donc un arbitrage écrit selon `DOC-GEL-1`, pas un item de code. Prêts, comptes et gouvernance entre instances = une fédération de protocole, hors de portée sans redessiner le modèle ; ne pas l'annoncer.

**Pourquoi ça compte.** L'auto-hébergement va multiplier les instances. Si le projet ne dit pas ce qui les relie, chaque guide le dira à sa façon, et la première déception sera une bibliothèque qui croyait rejoindre le réseau en installant le logiciel.

**Ce qui compte comme fini.**

- `FED-O11` acté ; le guide vitrine et `deploy/README.md` emploient la même phrase.
- La question de l'annuaire a une décision datée dans `journal/arbitrages/`, dans un sens ou dans l'autre.

**Dépendances.** Aucune ; **J3** en dépend.

*Renvois : `REGISTRE §24 FED-O11` · `supabase/functions/oai-pmh-provider` · `supabase/functions/harvest-oai-pmh` · `REGISTRE §0 DOC-GEL-1`*

#### G13 — Un commutateur « réseaux constitués » à l'OPAC : ne voir que les catalogues FICEDL, RebAL, NORLA…

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : SQL / PostgreSQL, React / JavaScript, langue maternelle, bibliothéconomie

**État.** **Demande de Xavier le 07/09/2026** : pouvoir restreindre l'affichage aux catalogues des bibliothèques qui appartiennent à un réseau constitué **avant** AnarBib — FICEDL, RebAL, NORLA (le corpus écrit NORLA, pas NORMA).

**Le modèle ne connaît pas ces réseaux.** `libraries` n'a ni colonne ni table d'affiliation externe — `network_mode` (`isolated|observer|federated`), `visibility_level='network'`, `catalog_mode='network_published'` et `network_administrators` parlent tous du rapport au réseau **AnarBib**, faux amis. Deux seuls porteurs, en texte libre : **`cartography_entries.reseau`** (spec-cartographie, sans vocabulaire contrôlé) et `library_commons.affiliation_label` (éditorial : « CCLA »). Sur les 187 fiches de carte : `FICEDL` 34, `RebAL ; FICEDL` 11, `RebAL` 6, `FAI Reggiana` 2, `ABABA`, `RebAL, FAI`, `FAO, AFI`, `UK Social Centre Network, Radical Routes` — 130 vides ; séparateurs `;` et `,` mélangés ; fédérations de centres de documentation et organisations politiques dans le même champ. **NORLA n'apparaît nulle part dans les données** (seulement aux items G8, H6, D4). Le champ n'est affiché qu'en infobulle de la carte (`CartographyMap.jsx`), jamais filtrable, et absent du formulaire d'édition. Aucune vue publique ne l'expose : `api.libraries_public_v1` (celle de l'OPAC) sert `id, slug, name, short_name, city, state` ; `api.public_libraries` sert `affiliation_label` mais pas `reseau`.

**Côté OPAC**, le filtre par bibliothèque passe par les **noms courts** (`p_filters.libraries` → `api.catalog_works_v1`, `holding_library_names_json`), mémorisé dans `localStorage` (`anarbib:catalog:filters`) — pas de `library_ids`, pas de notion de réseau.

**Mesuré en production le 07/09** : trois bibliothèques seulement ont une fiche de carte rattachée (`library_id`) — BLMF (FICEDL, 248 exemplaires), BTL (FICEDL, 2 184), MLEG (aucun réseau, 269). Un commutateur « FICEDL seulement » montrerait donc aujourd'hui BLMF + BTL, et « RebAL » ou « NORLA » rien : l'item vaut pour ce que le réseau devient (Bologne, admissions), pas pour ce qu'il est.

*Vérifié : 07/09 — production interrogée en lecture seule (jointure `cartography_entries` × `libraries` : trois lignes, réseaux et exemplaires ci-dessus) ; valeurs de `reseau` comptées sur `carte-reseau.umap` ; dépôt `eb790c33`.*

**Ce que c'est.** Trois pas, dans cet ordre. **(1) Normaliser** : un vocabulaire contrôlé des réseaux (table `networks` : slug, libellé, site — `ficedl`, `rebal`, `norla`, `fai`…, en excluant ou en typant les organisations politiques) et une colonne `reseaux text[]` — ou une table de jointure — sur `cartography_entries`, remplie depuis `reseau` (couper sur `;` et `,`, normaliser la casse), le champ ajouté à `CartographyEditModal` avec ses clés i18n ; l'appartenance reste déclarée par la fiche de carte, qui a déjà sa modération — **aucun circuit nouveau**. **(2) Exposer** : une colonne `networks` dans `api.libraries_public_v1` par jointure sur `cartography_entries.library_id` — en réécrivant la vue **avec** `security_invoker` (un `CREATE OR REPLACE VIEW` sans `WITH` la ferait retomber en DEFINER). **(3) Filtrer** : dans `CatalogPage.jsx`, à côté du sélecteur de bibliothèques, un sélecteur de réseaux qui réduit `libraryOptions` et alimente `libraryShortNames` — **sans toucher au RPC** ni aux vues matérialisées `catalog_list_*` ; mémorisé dans `anarbib:catalog:filters`, visible en puce, remis à zéro par « effacer les filtres ». **Décision à prendre en écrivant** : un interrupteur unique « réseaux constitués seulement » ou un filtre par réseau (FICEDL / RebAL / NORLA) — le second coûte le même prix et répond à « où sont nos catalogues ? » posé par un réseau à la fois ; l'interrupteur peut être le raccourci « tous les réseaux ». Une biblio hors de toute fiche de carte n'apparaît dans aucun réseau : le dire à l'écran plutôt que la faire disparaître en silence.

**Pourquoi ça compte.** Bologne (13/09) réunit des gens dont les réseaux existaient avant AnarBib ; la première chose qu'ils chercheront à l'écran, c'est le leur. Les conventions d'interopérabilité posent qu'il n'y a « rien à rejoindre » : montrer les réseaux tels qu'ils existent, plutôt que les fondre dans un annuaire AnarBib, est la traduction de cette phrase dans l'interface.

**Ce qui compte comme fini.**

- [object Object]
- [object Object]
- [object Object]

**Dépendances.** **G8** (compléter la carte : les neuf archives NORLA) enrichit le résultat sans le conditionner. **G9** (cartographie v1.0) est gelé : ne pas l'attendre, le pas (1) lui servira. Voisin de **H6** (vocabulaires NORLA ↔ FICEDL). Le pas (2) touche une vue : relire `CREATE OR REPLACE VIEW` et ses options avant.

*Renvois : `supabase/migrations/20260618142238_cartography_schema.sql (colonne reseau)` · `docs/specs/spec-cartographie-reseau.md` · `src/pages/public/CatalogPage.jsx (libraryFilter, libraryShortNames, FILTER_STORAGE_KEY)` · `supabase/migrations/20260904150000_l_opac_par_oeuvre_se_lit_sans_session.sql (p_filters.libraries)` · `api.libraries_public_v1 (baseline)` · `src/pages/federacao/CartographyMap.jsx` · `docs/cartographie/carte-reseau.umap`*

#### G14 — Une invitation d'équipe attend depuis le 30/08 et expirera le 29/09 — la personne ne le sait peut-être pas

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : aucune compétence technique

**État.** **Vérifié en base le 07/09** : dans `library_team_invitations`, une invitation créée le 30/08 est toujours `ready`, expiration le 29/09 (deux autres du 01/09 sont `accepted` et `pending_ratification`). Le plan de formation du 01/09 la signalait déjà : « il faut la prévenir ». Le cron d'expiration la fermera en silence.

*Vérifié : 07/09 — `ready` depuis le 30/08, expiration 29/09.*

**Ce que c'est.** Un message à la personne invitée, par le canal humain (`DOC-COLLECTIVE-1`). Puis regarder pourquoi l'invitation par courriel n'a pas suffi — c'est **G1** en miniature.

**Pourquoi ça compte.** Un circuit qui expire sans que personne ne s'en aperçoive est un circuit qui n'existe pas.

**Ce qui compte comme fini.**

- L'invitation est `accepted` ou `declined` avant le 29/09, pas expirée.

**Dépendances.** Aucune.

*Renvois : `claude/PLAN_formation_coordination_BLMF_2026-08-26 (annexe)` · `REGISTRE §0 DOC-COLLECTIVE-1`*

---

### H — Interopérabilité, thésaurus, moisson

*Sortir vers les autres catalogues, et accepter d'être pointé en retour.*

| | | | |
|---|---|---|---|
| **H2** | Poser à la FICEDL les sept questions qui bloquent l'export du thésaurus | `P1` | Bloqué |
| **H6** | Aligner les vocabulaires militants qui ne se connaissent pas | `P2` | Ouvert |
| **H9** | Ouvrir les cinq relations SKOS aux consommateurs — RPC, page-sujet, sérialiseur, trente clés i18n, d'un bloc | `P1` | Gelé |
| **H10** | Relire à la main les 98 alignements FICEDL — 54 `close` dont une part sont des `broad` — et aligner enfin les quatre rubriques historiques de Solidaires | `P2` | Ouvert |
| **H11** | Le dépôt dit 462 descripteurs FICEDL, la production en porte 621 — régénérer la migration de données avant qu'un rejeu depuis zéro ne casse | `P2` | Ouvert |
| **H12** | Les listes hors thésaurus de la FICEDL — communes du Bettini, lieux d'édition du Bianco : demander l'export tel quel, jamais l'intégration | `P3` | Ouvert |
| **H13** | L'esquisse SKOS des 26 descripteurs n'est ni au dépôt ni au projet — la verser à `docs/journal/ficedl/` pour qu'elle soit donnable et versionnée | `P2` | À vérifier |

#### H2 — Poser à la FICEDL les sept questions qui bloquent l'export du thésaurus

`P1` Prioritaire · État : **Bloqué** · Charge : une soirée · Ce que ça demande : délibération collective

**État.** L'export complet des 620 descripteurs dans les deux formats est **à une soirée de travail** — dès que les sept questions ont une réponse. Elles sont écrites et personne ne les a encore posées.

*Vérifié : 07/09, soir — **deux réponses de plus de la source.** (1) `X (généralités)` **est** la tête de hiérarchie : les 45 parents « introuvables » sont 45 `broader` réels ; 138 descripteurs sur 148 sont rattachés, 10 ne le sont pas — et la question restante est devenue : `guerres` et `art : courants` sont-ils des **groupes de mots-clés SPIP** ? (2) Identifiants : la forme canonique SPIP est `?motNN` quel que soit le type d'URL affiché ; les « URL propres » sont des adresses, pas des identités. La question 1 tombe — URI `https://thesaurus.ficedl.info/?motNN`, `skos:notation` = le numéro, proposition `/id/motNN` retirée. Restent : la question des groupes, le format (un fichier à deux schémas ou deux), les liens vers les catalogues, le grec, la licence, la régénération.

07/09 — **Réponse partielle reçue de la source** : « guerre » est dans les deux thésaurus qu'elle tient séparés, *liste commune* et *géo-histo* ; les listes de communes (Bettini, Bianco) sont hors thésaurus. Ça répond à la question 3 (dates) et déplace la question 2 : les sept deviennent trois — `X` = `X (généralités)` ? ; `guerres`, `art : courants` = regroupements ou termes ? ; un fichier à deux schémas ou deux fichiers ? Les autres (identifiants, liens, grec, licence, régénération) restent posées. Le même jour, `thesaurus.ficedl.info` est **hors service** (« problème technique (serveur SQL) »).*

**Ce que c'est.** Les sept : la forme des identifiants ; **la hiérarchie, qui est la vraie question** ; le statut de la facette « dates » ; le sort des 2 842 liens vers six catalogues ; le grec romanisé ; la licence ; et la manière dont le fichier se régénère.

**Pourquoi ça compte.** Sur 148 descripteurs à libellé arborescent, **93 parents sont retrouvés et 55 sont introuvables** : « art », « économie », « guerres », « littérature », « presse », « syndicalisme » ne sont pas des descripteurs, ou portent un autre nom. Vu de l'extérieur, **la hiérarchie n'est pas une donnée, c'est une convention d'affichage dans une chaîne de caractères** — et on ne peut pas écrire `skos:broader` honnêtement là-dessus. Seule la FICEDL peut dire si le site tient une vraie relation parent-enfant.

**Ce qui compte comme fini.**

- Les sept questions sont posées, avec l'audit de qualité produit à la première aspiration en pièce jointe — **les corrections appartiennent à la source, pas aux copies**.
- Quatre anomalies vues en passant sont remontées : deux sites différents sous le même intitulé « catalogue du CCL » ; les archives du *Monde libertaire* apparaissant deux fois par terme sous deux formes d'adresse ; `mot228` (« populations autochtones ») présent dans deux facettes ; 29 libellés portugais portant astérisque, point d'interrogation ou espace finale.
- La question 7 est la plus rentable : un squelette SPIP qui imprime les termes en CSV règle aussi la charge robots — **une requête au lieu de 620, par consommateur et par mise à jour**, pour une demi-journée de travail côté FICEDL.

**Dépendances.** Bloque **H3**. À poser à Bologne ou avant.

*Renvois : `NOTE_export_thesaurus_questions_ouvertes_2026-08-28`*

#### H6 — Aligner les vocabulaires militants qui ne se connaissent pas

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : bibliothéconomie, délibération collective

**État.** NORLA a bâti son vocabulaire — avec ses facettes *Tactics* et *Social Movement* — **sans lien avec le thésaurus FICEDL**. Deux vocabulaires militants, construits en parallèle, qui s'ignorent. Par ailleurs, les 11 catégories thématiques d'AnarcosyndicalismeBOOK ne sont alignées sur rien.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Commencer par le plus petit et le plus faisable : les 11 catégories d'AnarcosyndicalismeBOOK, **un premier pas concret, borné, faisable en une soirée** — et comme le thésaurus est déjà en dix langues, l'alignement vaut simultanément pour les dix. Puis ouvrir la conversation avec NORLA.

**Pourquoi ça compte.** Chaque vocabulaire construit isolément est un fonds que les autres ne trouveront pas. Réserve à garder en tête : les vocabulaires d'éphémères sont **monolingues**, l'alignement y sera plus lourd que sur des sujets.

**Ce qui compte comme fini.**

- Les 11 catégories d'AnarcosyndicalismeBOOK sont alignées.
- Une conversation est ouverte avec NORLA sur l'alignement des facettes.
- La réciprocité est demandée : **les catalogues partenaires ne pointent pas en retour** aujourd'hui.

**Dépendances.** Octobre-novembre, si Bastien s'y met. Lié à **D4**.

*Renvois : `ORIENTATION_outils_bibliotheques_militantes_2026-08-26 §6` · `VEILLE_leftovers_maydayrooms_2026-08-19`*

#### H9 — Ouvrir les cinq relations SKOS aux consommateurs — RPC, page-sujet, sérialiseur, trente clés i18n, d'un bloc

`P1` Prioritaire · État : **Gelé** · Charge : quelques jours · Ce que ça demande : SQL / PostgreSQL, React / JavaScript, langue maternelle

**État.** **Vérifié en base et dans le dépôt le 07/09.** Le domaine de `subject_ficedl_links.match_type` porte désormais `exact`, `close`, `broad`, `narrow`, `related` (migration `20260907172508`), mais la porte est restée fermée exprès : `api.fn_subject_add_ficedl_match` n'accepte que `exact`/`close`, parce que **deux rendus sont binaires** — `src/pages/public/SubjectPage.jsx` (l. 163) affiche « exacte » pour tout ce qui n'est pas `close`, et `src/lib/skosExport.js` sérialise en `skos:exactMatch` tout ce qui n'est pas `close`, dans le Turtle et le JSON-LD publiés. Un `broad` créé aujourd'hui serait publié comme correspondance exacte.

*Vérifié : 07/09 — domaine étendu en base, porte fermée, deux rendus binaires constatés dans le dépôt.*

**Ce que c'est.** Étendre la garde de la RPC aux trois valeurs ; remplacer les deux ternaires par une table à cinq entrées (`skos:broadMatch`, `skos:narrowMatch`, `skos:relatedMatch`) ; ajouter trois clés `subject.matchBroad/Narrow/Related` dans les dix locales (le test i18n bloque sinon). Livrer les trois ensemble, jamais l'un sans les autres.

**Pourquoi ça compte.** Tant que le domaine existe en base sans consommateur capable de le dire, chaque alignement « plus large » reste tassé en `close` — une sur-affirmation publiée. Et l'ouvrir sans les rendus ferait pire : un `broad` sortirait en `exactMatch` dans un fichier que d'autres catalogues peuvent moissonner.

**Ce qui compte comme fini.**

- Un alignement `broad` posé depuis l'écran s'affiche « plus large » sur la page-sujet et sort en `skos:broadMatch` dans le Turtle et le JSON-LD.
- `npm test` passe avec les trente clés.
- La migration `20260907172508` voit son bloc de vérification 4.2 (porte fermée) retiré ou inversé le même jour.

**Dépendances.** Gelé jusqu'au 14/09 (code de production). Précède **H10**.

*Renvois : `REGISTRE §0 DOC-THES-1` · `REGISTRE §30 THES-FIC4, THES-FIC5` · `claude/VERIF_subject_ficedl_links_schema_2026-09-07` · `migration 20260907172508`*

#### H10 — Relire à la main les 98 alignements FICEDL — 54 `close` dont une part sont des `broad` — et aligner enfin les quatre rubriques historiques de Solidaires

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : bibliothéconomie

**État.** **Vérifié en base le 07/09.** 98 liens dans `subject_ficedl_links` : 44 `exact`, 54 `close`. Jusqu'au 07/09 le domaine n'avait que ces deux valeurs, donc tout ce qui est réellement « plus large » ou « voisin » a été tassé en `close`. Par vocabulaire visé : 72 vers la liste commune, 26 vers la géo-histo, **0 vers la facette `dates`** — les quatre rubriques historiques de Solidaires (guerres, périodes) ne sont donc toujours pas alignées, alors que les 159 dates sont en base depuis le 03/09 (H1 clos).

*Vérifié : 07/09 — 98 liens, 54 `close`, 0 vers `dates`.*

**Ce que c'est.** Fiche par fiche, jamais par passe automatique (`CONV-EXEC-3`) : pour chaque `close`, décider s'il reste `close` ou devient `broad`/`narrow`/`related` ; poser les alignements manquants vers la facette `dates` pour les rubriques historiques ; passer aussi les 44 alignements du lot Solidaires du 28/08.

**Pourquoi ça compte.** Un `skos:closeMatch` dit « presque le même concept ». Quand le sujet local est plus étroit, c'est faux — et c'est publié dans l'export que d'autres catalogues peuvent lire.

**Ce qui compte comme fini.**

- Chaque lien porte une relation choisie, pas héritée d'un domaine à deux valeurs.
- Au moins un alignement vers un descripteur `dates` existe.

**Dépendances.** Après **H9** : sans les cinq valeurs ouvertes à l'écran, la relecture n'a pas d'outil pour dire ce qu'elle voit.

*Renvois : `REGISTRE §30 THES-FIC4, THES-FIC-O1` · `claude/VERIF_subject_ficedl_links_schema_2026-09-07` · `CALENDRIER_bologne_2026-08-27 (rubriques historiques)`*

#### H11 — Le dépôt dit 462 descripteurs FICEDL, la production en porte 621 — régénérer la migration de données avant qu'un rejeu depuis zéro ne casse

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL

**État.** **Vérifié le 07/09, dépôt et production.** `20260826191000_donnees_ficedl_thesaurus.sql` insère 462 lignes (227 sujets, 234 geo, 1 double, **0 date**) — figée sur l'aspiration du 30/06. La production porte l'aspiration du 03/09 : **621** (159 dates en plus) parce que `ficedl_thesaurus_sync.mjs` a été rejoué. Le rejeu depuis une base vide passe encore : les 47 `mot_id` référencés par la migration d'alignement sont tous dans les 462. Il cassera le jour où un alignement visera un terme postérieur au 30/06 — c'est exactement ce que **H10** va faire. Deux dates de l'aspiration (161) manquent en base (159) : sans libellé, écartées par `isSyncable`.

*Vérifié : 07/09 — 462 au dépôt, 621 en production, rejeu encore vert.*

**Ce que c'est.** Régénérer la migration de données depuis `docs/journal/ficedl/ficedl_thesaurus_2026-09-03.json` (ou la remplacer par un seed rejoué par le sync en CI), et regarder les deux fiches sans libellé. Ne jamais lancer le sync avec `--prune`.

**Pourquoi ça compte.** Une reconstruction depuis zéro (**A2**, la bascule **I2**) qui ne rejoue pas les données de production n'est pas une reconstruction — c'est une autre base.

**Ce qui compte comme fini.**

- `count(*)` de `ficedl_thesaurus_terms` identique en CI et en production.
- Le rejeu de `sql-tests.yml` passe avec un alignement vers un descripteur `dates`.

**Dépendances.** Avant **H10**. Conditionne **A2** et **I2**.

*Renvois : `REGISTRE §30 THES-FIC-O4` · `claude/VERIF_subject_ficedl_links_schema_2026-09-07` · `REPRISE_claude_code_2026-08-27 (piège --prune)`*

#### H12 — Les listes hors thésaurus de la FICEDL — communes du Bettini, lieux d'édition du Bianco : demander l'export tel quel, jamais l'intégration

`P3` Différé · État : **Ouvert** · Charge : une soirée · Ce que ça demande : aucune compétence technique, délibération collective

**État.** Réponse de la source, 07/09 : deux référentiels existent hors thésaurus — les communes des biographies du *Bettini* (avec cartographie) et les lieux d'édition du *Bianco* — « pas intégrées au thésaurus, probablement trop lourd à gérer ». AnarBib n'a aucune autorité de lieux : `local_publicacao` est un champ libre (audit du 20/08 : `BELEM`), et la spec périodiques a écarté l'alignement FICEDL au motif que le thésaurus indexe des matières — vrai pour les matières, faux pour les lieux.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Après Bologne, et hors de la demande du 12 (qui tient parce qu'elle demande *une* chose) : demander les deux listes comme fichiers séparés, telles qu'elles sont. Puis aligner sur un référentiel géographique existant (Wikidata, GeoNames) avec la liste du Bianco en surcouche militante — pas construire une n-ième liste de communes.

**Pourquoi ça compte.** Demander l'intégration, c'est demander la charge que la source dit ne pas pouvoir porter. Une liste n'a pas besoin d'être dans le thésaurus pour être utile ; elle a besoin d'être copiable.

**Ce qui compte comme fini.**

- Les deux listes reçues sous une forme machine-lisible, versées à `docs/journal/ficedl/`.
- Une décision écrite sur l'autorité de lieux d'AnarBib.

**Dépendances.** Après **K5**. Touche `spec-periodiques` et **C3** (autorités).

*Renvois : `REGISTRE §30 THES-FIC-O2` · `claude/REPONSE_hortical_deux_thesaurus_2026-09-07` · `claude/spec-periodiques-v0.1 §5`*

#### H13 — L'esquisse SKOS des 26 descripteurs n'est ni au dépôt ni au projet — la verser à `docs/journal/ficedl/` pour qu'elle soit donnable et versionnée

`P2` Courant · État : **À vérifier** · Charge : une soirée · Ce que ça demande : aucune compétence technique

**État.** Le dossier Bologne du 03/09 le dit : `ficedl_thesaurus_ESQUISSE.csv` et `.jsonld` « ne sont pas dans le projet », à emporter sur clé USB. **Vérifié le 07/09** : `docs/journal/ficedl/` contient les quatre aspirations et les audits, **aucun fichier `ESQUISSE`** ; le projet Claude non plus. Le racleur et le sync, eux, sont au dépôt (`scripts/ficedl_thesaurus_scrape.mjs`, `_sync.mjs`) — cette moitié-là est déjà donnable.

*Vérifié : 07/09 — absents du dépôt et du projet ; leur existence sur disque n'a pas été vérifiée.*

**Ce que c'est.** Retrouver les deux fichiers (Downloads ?) ou les régénérer depuis l'aspiration du 03/09, et les commiter avec la note du 28/08 à côté. Depuis le 07/09 l'esquisse est à réviser : deux `skos:ConceptScheme`, les têtes `guerres`/`art : courants` en `skos:Collection`, jamais d'URI de schéma inventé — et, depuis la note de la source sur les URL : URI canonique `https://thesaurus.ficedl.info/?motNN`, `skos:notation` = le numéro, la forme `/id/motNN` retirée.

**Pourquoi ça compte.** C'est la pièce que tu poses sur la table à Bologne. Une pièce qui n'existe que sur une clé n'est pas une contribution, c'est une démonstration.

**Ce qui compte comme fini.**

- Les deux fichiers au dépôt, régénérables par une commande documentée.

**Dépendances.** Lié à **H2** et **K6**.

*Renvois : `claude/DOSSIER_rencontre_leftovers_bologne_2026-09-12 §B.1` · `claude/NOTE_export_thesaurus_questions_ouvertes_2026-08-28`*

---

### I — Auto-hébergement, exploitation, sauvegardes, CI

*Gelé jusqu'au 14/09/2026 sur la production. Le travail en environnement d'essai reste ouvert.*

| | | | |
|---|---|---|---|
| **I1** | Aligner l'image GoTrue sur l'état réel des migrations d'authentification | `P1` | Gelé |
| **I2** | Achever la bascule vers l'auto-hébergement | `P1` | Gelé |
| **I3** | Tester le routeur `main` de la pile auto-hébergée | `P1` | Gelé |
| **I6** | Purger les relevés de la sonde de santé | `P2` | À vérifier |
| **I12** | Automatiser le rafraîchissement du miroir froid | `P2` | Ouvert |
| **I13** | Finir la bascule vers le nouveau moteur de pages | `P3` | Ouvert |
| **I15** | Le secret Forgejo de la clé publiable porte encore son ancien nom | `P3` | Ouvert |
| **I16** | Suivre la PR #28 jusqu'à sa fusion : scission, quatre points bloquants, gel jusqu'au 14/09 | `P1` | En cours |
| **I18** | Le banc CI ne rejoue pas sur une image Supabase — il faut un rejeu qui le fasse | `P2` | Ouvert |
| **I19** | `pg_cron` doit exister sur la pile auto-hébergée, et son absence doit se voir | `P1` | Ouvert |
| **I21** | Ce qui doit être vrai avant la bascule chez Les Herbes Folles, et ne l'est pas encore — huit conditions, aucune technique difficile | `P1` | Ouvert |
| **I22** | Trancher `DOC-DEPLOY-1` après l'écart du 07/09 : tolérer et tracer, ou interdire et contrôler | `P2` | Ouvert |
| **I23** | Déposer un ccTLD européen et en faire l'alias d'`anarbib.org` — le `.org` reste sous registre états-unien | `P2` | Ouvert |

#### I1 — Aligner l'image GoTrue sur l'état réel des migrations d'authentification

`P1` Prioritaire · État : **Gelé** · Charge : quelques jours · Ce que ça demande : administration système

**État.** La production porte **77 migrations `auth`** (remesuré le 31/08), la dernière datée du 25/06. **Le constat sur l'épinglage est périmé : `deploy/.env` et `deploy/.env.example` portent tous deux `GOTRUE_TAG=v2.192.0` désormais.** Ce que v2.192.0 embarque comme migrations n'a pas été mesuré : l'alignement reste à prouver, et l'item reste gelé avec I2.

*Vérifié : 31/08 — `auth.schema_migrations` : 77 ; `deploy/.env` et `.env.example` relus : `v2.192.0` des deux côtés.*

**Ce que c'est.** Une méthode qui **se mesure et ne se devine pas** : monter d'un palier, démarrer sur un volume vierge, `select count(*) from auth.schema_migrations;`, recommencer jusqu'à atteindre au moins 77.

**Pourquoi ça compte.** La règle est simple et absolue : **l'image doit être supérieure ou égale à la production, jamais l'inverse.** Une image en retard démarre sur un schéma qu'elle ne connaît pas et peut le corrompre en tentant de le migrer.

**Ce qui compte comme fini.**

- Un tag est retenu, avec le compte mesuré à chaque palier écrit.
- `deploy/.env.example` est corrigé et la documentation de `deploy/` suit.
- Les douze dernières versions de production sont listées pour recoupement.

**Dépendances.** **Gelé sur la production jusqu'au 14/09.** Le travail en environnement d'essai est ouvert. Premier maillon de la chaîne de bascule.

*Renvois : `REPRISE_bascule_autohebergee_2026-08-26 §1`*

#### I2 — Achever la bascule vers l'auto-hébergement

`P1` Prioritaire · État : **Gelé** · Charge : plusieurs semaines · Ce que ça demande : administration système

**État.** La pile est réduite de douze à **six conteneurs** (`db`, `rest`, `auth`, `storage`, `functions`, `caddy`), les versions sont épinglées, `bootstrap.sh` a été exécuté pour de vrai le 26/08 avec huit défauts relevés et corrigés, et la répétition du 18/08 a rejoué 124 migrations et restauré un dump de production en 17 secondes. Reconstruction complète mesurée : **25 minutes**.

*Vérifié : 08/09 — l'hôte de la visio est Framatalk depuis ce jour (commits `88bba888`, `b75d4b2a`, REGISTRE FED-O9/AG-7) ; aucune réponse d'hébergeur sur un Jitsi n'a encore été demandée. Le fond de carte est un fichier de 18 Go dans le Storage (`map-tiles`), à faire suivre.*

**Ce que c'est.** Ce qui reste : découpler la chaîne de déploiement de l'intégration continue (**de l'extraction, pas de la création** — `scripts/ci/deployer-backend.sh` existe déjà), poser un proxy inverse avec tunnel devant la pile, passer des tags aux empreintes `sha256`, et refaire la répétition à froid un mois plus tard pour vérifier que rien n'a divergé. **Ajouté le 08/09/2026, à poser à l'hébergeur pressenti (Les Herbes Folles), ou à un ou plusieurs autres** : **un Jitsi à nous.** La visio d'entraide et d'assemblées vivait chez Autistici/Inventati ; A/I a été désigné « SDGT » par les États-Unis le 26/08 et a fermé ; le 08/09 on a basculé sur Framatalk (Framasoft, Hetzner en Allemagne) — un tiers de confiance, mais un tiers, et sur une infrastructure qu'une mesure du même genre peut atteindre. Un Jitsi hébergé par nous (ou par un collectif d'hébergement allié, ou réparti entre plusieurs) est la seule sortie complète. Ce n'est pas la même charge que le reste de la pile : le videobridge consomme de la bande passante montante à proportion des participantes, et une assemblée de vingt personnes n'est pas une aide à deux. **Questions à poser** : la VM peut-elle tenir un Jitsi (RAM, bande passante, ports UDP 10000) ; préfèrent-ils une seconde machine ; un autre hébergeur allié (Chapril, Systemli, une instance amie) accepterait-il de porter la visio pour le réseau, quitte à ce qu'elle ne vive pas au même endroit que la base ? Le même jour, **le fichier de fond de carte** (`map-tiles/planet-z12.pmtiles`, 18 Go, à réextraire en z15 depuis la VM : 138 Go) est entré dans ce qui déménage — à compter dans le disque demandé (I21).

**Pourquoi ça compte.** C'est l'objectif que le projet s'est donné et qu'il n'a pas encore atteint : la fin de la dépendance à un hébergeur tiers. **C'est le chantier le plus technique et le plus autonome du lot** — quelqu'un peut le prendre sans coordination.

**Ce qui compte comme fini.**

- La pile tourne derrière un proxy inverse, avec les versions en empreintes.
- Une reconstruction complète a été refaite un mois après la première.
- Garde-fou à préserver impérativement : la boucle de déploiement parcourt `supabase/functions/*/` **en excluant `_shared` et `main`** — sans quoi le routeur partirait sur le Supabase hébergé.
- Piège déjà rencontré : les rôles de service n'ont pas de mot de passe dans l'image `supabase/postgres` (SQLSTATE 28P01 en boucle), `postgres` n'est pas superutilisateur (c'est `supabase_admin`), `authenticator` est réservé, et un `set -e` dans la boucle tue le script au premier rôle en échec.
- La question d'un Jitsi (chez l'hébergeur, chez un allié, ou réparti) a été posée, et la réponse est consignée ici — même si c'est « non ».

**Dépendances.** **Gelé sur la production jusqu'au 14/09.** Dépend de **I1**. À faire avant de louer quoi que ce soit : reprendre la connexion authentifiée en local, bloquée par une résolution IPv6 sans route — **ce blocage a probablement disparu de lui-même**, le vérifier coûte cinq minutes et peut épargner une machine montée pour rien.

*Renvois : `docs/CHANTIERS_OUVERTS.md §2` · `deploy/README.md` · `REPRISE_bascule_autohebergee_2026-08-26` · `SETUP_fonds_de_carte_pmtiles_2026-09-07` · `REGISTRE FED-O9 (08/09)`*

#### I3 — Tester le routeur `main` de la pile auto-hébergée

`P1` Prioritaire · État : **Gelé** · Charge : une soirée · Ce que ça demande : Deno / TypeScript

**État.** `supabase/functions/main/index.ts` existe (6,9 Ko), lit `config.toml` au démarrage, applique un **refus par défaut** — seules les dispenses `verify_jwt = false` sont lues, tout le reste exige un jeton — et refuse de démarrer si le fichier est illisible. **Les quatre tests prévus n'ont pas été passés.**

*Vérifié : 31/08 — `supabase/functions/main/index.ts` : 6 885 octets, présent ; aucun test ne le mentionne dans `src/tests/` ni `tests/`. Le constat tient.*

**Ce que c'est.** Les quatre tests de l'étape 5 de `deploy/REPETITION.md` : fonction protégée sans en-tête d'autorisation → 401 ; avec un jeton valide → 200 ; `health-probe` sans jeton → 200 ; nom inexistant → 404.

**Pourquoi ça compte.** Le routeur est ce qui remplace la protection par défaut de la plateforme le jour de la bascule. Comme `config.toml` ne déclare que 31 fonctions sur 48, **le refus par défaut du routeur fermera dix-huit fonctions qui fonctionnent aujourd'hui** — il faut le savoir avant, pas après.

**Ce qui compte comme fini.**

- Les quatre tests passent.
- Le comportement pour les 18 fonctions non déclarées est connu et voulu.

**Dépendances.** **Bloqué par B6.** Gelé sur la production jusqu'au 14/09 ; le test en environnement d'essai est ouvert.

*Renvois : `deploy/README.md` · `deploy/REPETITION.md étape 5`*

#### I6 — Purger les relevés de la sonde de santé

`P2` Courant · État : **À vérifier** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL

**État.** **Constat corrigé le 31/08 au soir : la purge existe — elle vit dans la sonde elle-même, pas dans un cron.** `health-probe/index.ts` supprime à chaque tour les relevés de plus de `RETENTION_JOURS = 30` jours (vérifié dans le source déployé, pas seulement au dépôt). Elle n'a encore jamais rien supprimé — `n_tup_del = 0` pour 16 268 insertions — pour une raison simple : la table est née le 17/08, plus jeune que sa rétention. Le relevé initial cherchait un *cron* de purge ; le dispositif était dans le corps de la fonction. La forme `DOC-RECENS-1`, une fois de plus — et écrire le cron demandé aurait fait une purge en double.

*Vérifié : 31/08 — source déployé de `health-probe` relu (`RETENTION_JOURS = 30`, purge en fin de tour) ; `pg_stat_user_tables` : 16 268 insertions, **0 suppression**, plus ancien relevé du 17/08 — la naissance de la table, pas un effet de purge. Premier effet attendu vers le **16/09** : c'est là que le constat se prouve. **03/09** — relevé : 19 396 relevés, le plus ancien toujours du 17/08 14:36 UTC, aucune suppression (`n_tup_del = 0` — les compteurs ont été remis à zéro par le redémarrage du 02/09, `n_tup_ins = 724` depuis) ; source déployé relu, `RETENTION_JOURS = 30` inchangé. Rien à faire avant le 16/09 : c'est la date où le constat se prouve.*

**Ce que c'est.** Un cron de purge sur le modèle de `anarbib-catalog-audit-snapshot-purge`, avec une rétention à décider — trente jours suffisent probablement, les incidents étant conservés à part dans `service_health_incidents`.

**Pourquoi ça compte.** C'est la table la plus volumineuse de la base, et elle ne contient que du bruit dont l'utile a déjà été extrait. À ce rythme elle atteindra cent mille lignes avant la fin de l'année, ce qui alourdira chaque sauvegarde pour rien.

**Ce qui compte comme fini.**

- ~~Un cron de purge existe, avec une rétention écrite~~ — la purge existe depuis l'origine, dans la fonction elle-même, rétention écrite de 30 jours ; le cron demandé aurait fait doublon.
- ~~`service_health_incidents` n'est pas touchée par la purge~~ — vérifié : la purge ne vise que `service_health_probes`.
- La purge a supprimé pour de vrai : `n_tup_del > 0`, à relever après le 16/09.

**Dépendances.** Aucune.

*Renvois : `Relevé du 29/08/2026` · `REGISTRE §38 OPS`*

#### I12 — Automatiser le rafraîchissement du miroir froid

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : administration système

**État.** **Constat corrigé le 05/09 : le minuteur tourne.** Le journal systemd de l'utilisateur le prouve : `anarbib-mirror-refresh.timer` se déclenche chaque jour à 18 h 02, et le 04/09 le service a pris 32 commits (`a1656516 → 63630c2f`, « Miroir froid à jour, 243 Mo »). `systemctl` ment sur ce poste, mais `journalctl --user -u anarbib-mirror-refresh.service` ne ment pas. Le script (`deploy/ops/anarbib-mirror-refresh.sh`) refuse un remote inconnu et **s'arrête sur une réécriture d'historique** — mais son échec ne va nulle part d'autre que le journal, et la fraîcheur du miroir n'apparaît pas dans le témoin de sauvegarde (`fn_backup_heartbeat_status`).

*Vérifié : 31/08 — les unités sont bien versionnées, dans `deploy/ops/systemd/` (`anarbib-mirror-refresh.service` + `.timer`, avec toute la famille sauvegardes). Le miroir froid porte un HEAD du 30/08 à 16 h — au plus un jour de retard — mais rien d'ici ne distingue un timer actif d'un rafraîchissement manuel, et `systemctl` ment sur ce poste : mise en service toujours non confirmée. **05/09** — `journalctl --user` : timer actif, dernier passage 04/09 18:02:19, prochain 05/09 18:03 ; le miroir portait `3b1f71c1` le soir même (rafraîchi à la main en plus). Le `die` du script n'a pas de destinataire.*

**Ce que c'est.** Ce qui reste : faire remonter l'échec du service (un `OnFailure=` vers l'unité d'alerte des sauvegardes, ou une ligne dans `backup_heartbeats`) et écrire la date du dernier rafraîchissement là où le témoin la lira. Le `die` du script est le bon signal, il n'a pas encore de destinataire.

**Pourquoi ça compte.** Une reconstruction demande **trois** choses et non deux : le dépôt, une sauvegarde, **et les secrets du Vault**. Le miroir froid est la troisième copie du dépôt, après Codeberg et le miroir GitHub. Il ne sert que s'il est à jour — et le miroir GitHub a déjà accumulé 6 878 objets de retard une fois.

**Ce qui compte comme fini.**

- [object Object]
- [object Object]

**Dépendances.** Lié à **I4**.

*Renvois : `RUNBOOK_exploitation_v0.3 §4 §9.1`*

#### I13 — Finir la bascule vers le nouveau moteur de pages

`P3` Différé · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : administration système

**État.** L'étape 0 est concluante depuis le 20/08 : `test.anarbib.org` est servi par le nouveau moteur en parallèle. La chaîne d'intégration continue utilise déjà l'action `git-pages`. **Codeberg Pages en version historique est en mode maintenance, pas en fin de vie** — la documentation dit qu'il continuera de fonctionner indéfiniment. D'où la priorité basse.

*Vérifié : 31/08 — une partie du nettoyage est déjà faite : la branche `pages` n'existe plus sur la forge, `public/.domains` a disparu, et `public/CNAME` est bien préservé. Restent à confirmer le service lui-même et les secrets devenus inutiles.*

**Ce que c'est.** Poser l'enregistrement TXT de liste blanche, créer `public/_redirects` avec la règle de réécriture, vérifier qu'une route inconnue renvoie 200 avec le bon contenu, puis nettoyer **seulement après** vérification verte.

**Pourquoi ça compte.** Deux points de vigilance sont écrits. **Ne pas toucher aux enregistrements A et AAAA**, qui sont bons. Et **vérifier la casse de l'URL** : le workflow écrit `AnarBib`, la documentation écrit `anarbib` — en cas de doute, poser les deux enregistrements TXT.

**Ce qui compte comme fini.**

- Le site est servi par le nouveau moteur, avec les routes inconnues en 200.
- Le nettoyage est fait après vérification : `public/.domains`, la branche `pages`, les secrets devenus inutiles.
- **Laisser `public/CNAME`** — il sert au miroir GitHub.
- Incertitudes assumées : la réversibilité de la bascule n'est documentée nulle part, aucune limite chiffrée n'est publiée (taille, bande passante, délai), et les fichiers vendorisés pèsent lourd — **point à surveiller au premier déploiement**.

**Dépendances.** P1, pas P0 — la version historique n'a pas de date d'arrêt annoncée.

*Renvois : `PLAN_migration_git_pages_2026-08-19` · `RUNBOOK_exploitation_v0.3`*

#### I15 — Le secret Forgejo de la clé publiable porte encore son ancien nom

`P3` Différé · État : **Ouvert** · Charge : une soirée · Ce que ça demande : administration système

**État.** Depuis le 01/09, le code lit `VITE_SUPABASE_PUBLISHABLE_KEY` et sa valeur est bien la clé publiable — mais en CI, cette variable est alimentée par le secret Forgejo au nom historique `VITE_SUPABASE_ANON_KEY`. Découplage voulu : il évitait d'exiger un renommage de secret et un merge au même instant. Le piège est documenté dans `ci.yml` : `prebuild` fait `exit 0` si la variable manque, un nom désaccordé ne casse pas le build, il publie un instantané de catalogue périmé en silence.

*Vérifié : 01/09 — `ci.yml` relu après la bascule : mappage `VITE_SUPABASE_PUBLISHABLE_KEY: ${{ secrets.VITE_SUPABASE_ANON_KEY }}` en place, commenté.*

**Ce que c'est.** Créer le secret `VITE_SUPABASE_PUBLISHABLE_KEY` dans les réglages Forgejo (même valeur), aligner la ligne de `ci.yml`, vérifier un build complet — la fraîcheur du `catalogue-snapshot.json` fait preuve — puis supprimer l'ancien secret.

**Pourquoi ça compte.** Le chantier des clés a payé deux fois le prix d'un nom qui ment — une variable de plateforme dont le contenu avait changé sans prévenir, et un contrôle `verify_jwt` que satisfaisait une clé publique. Autant ne pas en laisser un troisième en place, même bénin.

**Ce qui compte comme fini.**

- La ligne de `ci.yml` lit un secret du même nom que la variable, l'ancien secret n'existe plus, et un build postérieur a produit un snapshot daté du jour.

**Dépendances.** Accès aux réglages du dépôt Forgejo (Settings → Actions → Secrets).

*Renvois : `.forgejo/workflows/ci.yml` · `item B18`*

#### I16 — Suivre la PR #28 jusqu'à sa fusion : scission, quatre points bloquants, gel jusqu'au 14/09

`P1` Prioritaire · État : **En cours** · Charge : quelques jours · Ce que ça demande : administration système, SQL / PostgreSQL, Deno / TypeScript

**État.** La PR #28 (installateur `install.sh`, `deploy/`, seed admin, transport mail, résolveur d'URL, neuf migrations retouchées) est relue ; réponse du mainteneur posée le 06/09 au soir. Bloquant avant fusion, indépendamment du gel : **(1)** scinder — le code de production (`src/lib/supabase.js`, `coverThumbs.js`, `AltchaWidget`, six pages, `secret-key.ts`, `email.ts`, `smtp.ts`, deux `notify-*`) dans une PR à part ; **(2)** retirer le repli sur `SUPABASE_SERVICE_ROLE_KEY` de `secret-key.ts` (la ligne `SUPABASE_SECRET_KEYS` de `compose.yml` suffit) ; **(3)** le mode « mock » du mail réservé à `MAIL_TRANSPORT=mock` explicite ; **(4)** `docs/CHANTIERS_OUVERTS.md` rendu au mainteneur. Puis : mot de passe admin aléatoire en local, `pg_cron` créé plutôt que sauté, explication de la regex `uid()` (`20260906111308`), « UUID déterministes » introuvables dans le diff. Détails : `.gitignore` `deploy/.env.*` couvre `.env.example` ; Caddy sur `5173` contre `npm run dev` ; `Referrer-Policy` changé pour toute l'API ; `deploy/README.md` perd la section `bg2-known-tables.txt`. **MàJ 06/09, 21 h.** Bastien a scindé (#28 auto-hébergement, tête `c0e7d3c2` ; #29 code applicatif, tête `1f3745fa`) et réglé le soir même : `CONTRIBUTING.md` identique à `main`, migration `20260904130100` restaurée, `pg_cron` créé dans `01-roles.sh`, mot de passe aléatoire et nom de biblio demandés, courriel admin demandé, confirmation `--rebuild`, attente `pg_isready`, `.env.local` préservé, redirection http→https Caddy. **Deux points nouveaux pour la relecture d'après le 14** : *(a)* `install.sh` écrit désormais `VITE_SUPABASE_URL=auto`, que seul le `resolveSupabaseUrl` de la #29 comprend — sur `main`, `auto` serait pris pour une URL : **la #28 dépend de la #29**, ou doit écrire l'URL réelle ; *(b)* l'init `pg_cron` est enveloppée dans `if` le rôle `postgres` existe → un saut silencieux est de retour par une autre porte. Les tickets « [CI rouge] » #2/#3 touchés ce soir sont d'août, fermés, seulement cross-référencés ; tous les runs Actions sont verts. **21 h 06 (`73eb3462`)** : il a réglé la dépendance en mettant dans la #28 un `resolveSupabaseUrl` **minimal** — seul `auto` bascule sur `window.location.origin`, une URL explicite est respectée telle quelle (ce qui répare aussi l'heuristique `localhost` de la #29). Conséquences : *(a)* un fichier de production (`src/lib/supabase.js`) revient dans la PR d'auto-hébergement — acceptable **s'il reste le seul** et sous cette forme minimale, à dire explicitement à la fusion ; *(b)* la #29 porte encore sa propre version du même fichier, avec l'heuristique `localhost` : **conflit entre les deux PR**, la #29 devra être rebasée sur la #28 fusionnée et abandonner sa version ; *(c)* le `throw` « `VITE_SUPABASE_URL` requis » qui suit devient inatteignable (repli sur l'origine ou `http://localhost`) — à trancher : garder le `throw` quand la variable est absente, réserver le repli au seul `auto`. **Tranché le 06/09 à 21 h 30 (Xavier)** : D9 — `src/lib/supabase.js` accepté dans la #28, seul et minimal, `throw` conservé hors `auto`, exception dite à la fusion ; D6 — la #29 se rebase sur la #28 fusionnée en un ou deux commits et abandonne sa version du résolveur ; D8 — la #29 se fusionne entre deux soirées de formation, jamais la veille d'une séance, tests verts.

*Vérifié : 06/09 — PR #28 relue en entier (46 fichiers, tête `b5782ec1`), production interrogée en lecture seule, constat `CONSTAT_PR28_rejeu_vs_production_revoke_anon_2026-09-06`.*

**Ce que c'est.** Attendre la réponse de Bastien ; relire la PR scindée « auto-hébergement » au retour de Bologne ; la fusionner quand les points (1)-(4) sont réglés ; ouvrir la relecture de la PR « code applicatif » comme du code de production, avec tests. Ne rien fusionner avant le 14/09.

**Pourquoi ça compte.** C'est la première reconstruction depuis le dépôt seul faite par quelqu'un d'autre que le mainteneur — la réponse à la question qui décide de tout le reste (`CHANTIERS_OUVERTS` §1). La perdre en la laissant traîner, ou la fusionner sans la lire, coûterait la même chose.

**Ce qui compte comme fini.**

- La PR « auto-hébergement » est fusionnée, ses quatre points bloquants réglés, `install.sh` exécuté une fois sur une machine qui n'est pas celle de son auteur.
- La PR « code applicatif » est ouverte à part, avec un test pour chaque changement de comportement.
- Le REGISTRE porte la règle d'amorçage du premier administrateur (`GOUV-19`).

**Dépendances.** Réponse de Bastien ; retour du 14/09. Lié à **A4**, **I17**, **I19**, **B20**, **F7**, **G11**, **J3**, **J4**.

*Renvois : `codeberg.org/anarbib/anarbib/pulls/28` · `journal/operations/CONSTAT_PR28_rejeu_vs_production_revoke_anon_2026-09-06 §9` · `REGISTRE §0 DOC-GRANT-2`*

#### I18 — Le banc CI ne rejoue pas sur une image Supabase — il faut un rejeu qui le fasse

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : administration système

**État.** `scripts/ci/run-sql-suites.sh` crée `anarbib_test` depuis `template0` : `pg_default_acl` y est vide, les fonctions naissent fermées, la vérification des migrations du 29/08 passe — et une image réelle la fait lever. Le vert de `sql-tests` n'atteste donc pas qu'une image Supabase rejoue le dépôt (`DOC-GRANT-2`, même limite structurelle que `DOC-MIGR-1` par l'autre bout). Le choix de `template0` est motivé (pas d'event triggers hérités) et reste bon pour les suites. **07/09** : la spec d'`I17` (§8) rend cet item bon marché — le service `sql-tests` lance déjà l'image ; il suffit d'un second job qui rejoue les migrations dans la base `postgres` du service (défauts et extensions de l'init posés) au lieu d'une base `template0`. **07/09, confirmé par l'expérience d'`I17`** : avec A.1 avant le socle et `CREATE EXTENSION pg_cron`, la base `postgres` de l'image rejoue les 310 migrations sous `postgres` ; le job serait vert aujourd'hui.

*Vérifié : 06/09 — PR #28 relue en entier (46 fichiers, tête `b5782ec1`), production interrogée en lecture seule, constat `CONSTAT_PR28_rejeu_vs_production_revoke_anon_2026-09-06`.*

**Ce que c'est.** Un second job, ou une étape hebdomadaire : rejouer les migrations dans la base `postgres` de l'image `supabase/postgres` du stack (celle que `sql-tests.yml` lance déjà en `services:`), avec ses privilèges par défaut et son `pg_cron`, sans suites — juste « ça passe ou ça casse ». Rouge = un contributeur extérieur cassera au même endroit.

**Pourquoi ça compte.** Toute assertion « N migrations rejouent de zéro » se mesure sur une image Supabase, jamais sur le banc CI. Sans ce job, c'est la prochaine personne extérieure qui fera la mesure, à ses frais.

**Ce qui compte comme fini.**

- Un job de la forge rejoue les migrations sur `supabase/postgres` et son résultat est lisible dans Actions.
- Il a été rouge une fois pour une vraie raison, et la raison a été corrigée.

**Dépendances.** Après **I17** (sinon le job sera rouge pour la raison déjà connue).

*Renvois : `scripts/ci/run-sql-suites.sh` · `REGISTRE §0 DOC-GRANT-2` · `REGISTRE §0 DOC-MIGR-1`*

#### I19 — `pg_cron` doit exister sur la pile auto-hébergée, et son absence doit se voir

`P1` Prioritaire · État : **Ouvert** · Charge : une soirée · Ce que ça demande : administration système, SQL / PostgreSQL

**État.** La PR #28 enveloppe `cron.schedule` de `20260904130100` dans une garde `to_regnamespace('cron') IS NULL → NOTICE + RETURN`, étiquetée « banc d'essai ». Le banc CI a un stub `cron` depuis le 31/08 : la garde ne sert que sur la pile de Bastien, donc **elle n'a pas `pg_cron`** — et les 15 migrations antérieures qui planifient y sont déjà passées en silence par leurs anciens `EXCEPTION`. Sur une installation réelle : pas de rappels d'échéance, pas de moisson OAI, pas de digests, pas de témoin de sauvegarde, sans un mot (`DOC-SILENCE-1`). `compose.yml` note pourtant que le code appelle `cron.` 36 fois.

*Vérifié : 06/09 — PR #28 relue en entier (46 fichiers, tête `b5782ec1`), production interrogée en lecture seule, constat `CONSTAT_PR28_rejeu_vs_production_revoke_anon_2026-09-06`. **07/09, expérience d'`I17`** (`NOTE_experience-I17-rejeu-fidele_2026-09-07`) : sur l'image 17.6.1.136 vierge, la bibliothèque est préchargée (« pg_cron scheduler started ») mais l'extension n'existe pas dans `postgres` — `cron.job` absent, `20260904130100` rouge à la 288e migration. `CREATE EXTENSION IF NOT EXISTS pg_cron` sous `postgres` non superutilisateur réussit, puis 288→310 vertes. Piège : `initdb.d/*` est traité dans l'ordre du glob, `99-roles.sh` avant `migrate.sh` ; un `exit 1` dans le script sourcé tue l'init.*

**Ce que c'est.** Créer l'extension dans `deploy/init-db/` (l'image la charge déjà : le journal de la pile du 27/08 montre « pg_cron scheduler started ») ; faire lever, pas sauter, quand elle manque ; ajouter une ligne au contrôle de santé de `deploy.sh --controle` : nombre de jobs `cron.job` attendus.

**Pourquoi ça compte.** Une bibliothèque auto-hébergée sans `pg_cron` est une bibliothèque sans rappels ni sauvegardes surveillées, qui croit en avoir. C'est la forme la plus coûteuse du silence.

**Ce qui compte comme fini.**

- `select count(*) from cron.job` sur une pile fraîche rend le nombre de jobs du dépôt.
- Une migration qui planifie sans `pg_cron` est rouge, pas silencieuse.

**Dépendances.** À proposer à Bastien dans la PR scindée (**I16**) ou à faire au retour.

*Renvois : `supabase/migrations/20260904130100_les_oeuvres_ont_un_titre_par_langue.sql` · `deploy/compose.yml` · `deploy/init-db/` · `REGISTRE §0 DOC-SILENCE-1`*

#### I21 — Ce qui doit être vrai avant la bascule chez Les Herbes Folles, et ne l'est pas encore — huit conditions, aucune technique difficile

`P1` Prioritaire · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : administration système, délibération collective

**État.** La décision du 07/09 (offre confirmée : VM IPv4, Debian, sauvegardes déjà chez eux) et la note du 05-06/09 laissent une liste que rien ne tient ensemble. **Vérifié le 07/09 dans `deploy/`** : aucune trace d'`unattended-upgrades`, de pare-feu ni d'authentification par clé seule. Le reste est humain ou local : la connexion authentifiée sur la pile locale jamais retestée depuis le retrait de Turnstile ; `deploy/.env` écrasé par `install.sh` (domaines sur `localhost`) sans copie connue ; l'essai depuis un réseau mobile brésilien (NAT64) jamais fait ; le délai d'intervention des Herbes Folles jamais demandé ; le moyen de leur verser de l'argent « demandé depuis juillet, sans réponse » ; un second détenteur des accès ; et la règle posée le 07/09 : **on ne bascule pas avant que la sauvegarde soit partie chez un tiers** — aujourd'hui les trois flux restic sont chez l'hébergeur de destination lui-même.

*Vérifié : 07/09 — `deploy/` sans durcissement ; les sept autres conditions non vérifiables depuis la base.*

**Ce que c'est.** Tenir la liste ici, cocher chaque condition avec sa preuve (fichier, courriel, essai daté). Le durcissement entre dans `deploy/` ; le dépôt de sauvegarde tiers se demande à Bologne (**I12** dit ce que le miroir froid couvre, et ce n'est pas ça).

**Pourquoi ça compte.** Chacune de ces conditions est petite. Ensemble, c'est la différence entre une bascule et un déménagement de la fragilité.

**Ce qui compte comme fini.**

- Les huit conditions cochées avec preuve, dans cet item.
- `deploy/` porte le durcissement, rejoué par `bootstrap.sh`.

**Dépendances.** Bloque **I2**. Le dépôt tiers et le second détenteur relèvent de la même conversation que **A1** (Bologne).

*Renvois : `claude/DECISION_herbesfolles_offre_confirmee_2026-09-07` · `claude/NOTE_sortie_services_etats_uniens_2026-09-05` · `claude/REPRISE_claude_code_PR28_revoke_anon_2026-09-06 (deploy/.env)`*

#### I22 — Trancher `DOC-DEPLOY-1` après l'écart du 07/09 : tolérer et tracer, ou interdire et contrôler

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : aucune compétence technique

**État.** Le 07/09, la migration `20260907172508` a été appliquée en production par `apply_migration` (MCP) — ce que `DOC-DEPLOY-1` interdit en toutes lettres. Écart constaté après coup, tracé au REGISTRE §30, rattrapé sans double application (fichier renommé sur l'horodatage enregistré dans `supabase_migrations.schema_migrations`). Le registre laisse la question ouverte et rappelle que, tant qu'elle l'est, **la règle écrite vaut**.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Deux issues, une ligne au registre chacune : tolérer à titre exceptionnel et tracé, sur le modèle de `DOC-DEPLOY-3` — ou réaffirmer l'interdiction et poser le contrôle qui la rend vérifiable : une version présente dans `supabase_migrations.schema_migrations` dont le fichier n'est pas au dépôt est la signature exacte de l'écart (une requête, jouable en CI).

**Pourquoi ça compte.** Une règle enfreinte sans suite devient une règle décorative. La suite peut être une exception écrite ; ce ne peut pas être le silence.

**Ce qui compte comme fini.**

- La ligne `DOC-DEPLOY-1` du registre ne porte plus le ⚠️ du 07/09.

**Dépendances.** Aucune.

*Renvois : `REGISTRE §0 DOC-DEPLOY-1` · `REGISTRE §30 (écart tracé)` · `claude/VERIF_subject_ficedl_links_schema_2026-09-07 §4`*

#### I23 — Déposer un ccTLD européen et en faire l'alias d'`anarbib.org` — le `.org` reste sous registre états-unien

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : administration système

**État.** La note du 05-06/09 le met en tête de chemin : « cette semaine — déposer un ccTLD européen et en faire un alias », compatible avec le gel parce que ça ne touche pas la production. Motif : le registre du `.org` (Public Interest Registry) est états-unien, comme les deux services dont le projet sort. **Non vérifié** — pas de résolution DNS possible depuis ici ; rien dans le dépôt ne le mentionne.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Choisir le domaine, le déposer chez OVH, poser une redirection vers `anarbib.org` (et non l'inverse, pour l'instant), et l'écrire dans la politique de confidentialité s'il y figure.

**Pourquoi ça compte.** Un alias coûte un euro par mois et donne une adresse qui survit à une décision étrangère sur le `.org`.

**Ce qui compte comme fini.**

- Le domaine résout et redirige.

**Dépendances.** Aucune. Indépendant du gel.

*Renvois : `claude/NOTE_sortie_services_etats_uniens_2026-09-05 (chemin, étape 1)`*

---

### J — Documentation et corpus

*Le corpus est vaste et sa dérive est mesurée. Ce backlog en fait partie.*

| | | | |
|---|---|---|---|
| **J2** | Réparer l'index des backlogs et trancher la convention d'archivage | `P2` | Ouvert |
| **J3** | Le guide d'auto-hébergement du site vitrine (pages PR #2) : quatre phrases, un avertissement, et attendre la PR #28 | `P2` | Ouvert |
| **J4** | `CHANTIERS_OUVERTS` §1 : écrire l'état réel après la première reconstruction extérieure | `P2` | Ouvert |
| **J9** | Manuel v5 : le reliquat des captures — 180 emplacements en repli pt-BR, IMG-31 à refaire, IMG-08 à confirmer, tout à recapturer en 900-1000 px | `P2` | À vérifier |
| **J10** | Sept domaines sont entrés dans le v17 sans avoir été arbitrés contre leur coût d'achèvement | `P3` | Ouvert |

#### J2 — Réparer l'index des backlogs et trancher la convention d'archivage

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : aucune compétence technique

**État.** **Corrigé le 31/08 : la ligne du v32 est rétablie depuis le 29/08** (`INDEX.md`, avec la note « elle manquait à ce tableau depuis juin »). Restent : les deux conventions de nommage qui coexistent — 9 archives avec le préfixe `-archive-`, 27 sans — et un en-tête d'INDEX qui dérive déjà : « 90 items » puis « les items restent 84 » dans le même paragraphe, quand le JSON en compte 83.

*Vérifié : 31/08 — `INDEX.md` relu, archives comptées : 9 avec le préfixe `-archive-`, 27 sans.*

**Ce que c'est.** Ajouter la ligne du v32, celles du v33 et du v34, et trancher la convention d'archivage en une phrase inscrite au REGISTRE.

**Pourquoi ça compte.** L'index des backlogs est ce qui permet de savoir quelle version fait foi. Une lignée avec un trou et deux conventions concurrentes ne remplit pas cet office.

**Ce qui compte comme fini.**

- Le tableau est complet du v8 au v34.
- Une seule convention de nommage est inscrite au REGISTRE.

**Dépendances.** Se fait en posant ce backlog.

*Renvois : `docs/backlogs/INDEX.md`*

#### J3 — Le guide d'auto-hébergement du site vitrine (pages PR #2) : quatre phrases, un avertissement, et attendre la PR #28

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : langue maternelle, aucune compétence technique

**État.** PR #2 sur `AnarBib/pages` (la #1, même contenu, est fermée) : guide pas à pas en 10 langues engendrées par `tools/build-selfhosting-pages.py`, lien dans la navigation de `fr/`, `en/`, `es/`, `pt/`, renvoi dans le formulaire d'adhésion, README du dépôt en 4 langues. Ton juste, découpage juste, boutons « copier ». Il documente `./install.sh`, qui n'est pas dans `main`. Quatre affirmations à corriger : « coopérer avec les autres camarades du réseau » (vrai pour le catalogue par OAI-PMH, faux pour comptes, prêts, gouvernance — **G12**) ; « 2 Go suffisent largement » et « Raspberry Pi 4/5 » (non mesuré : six conteneurs dont Postgres et l'edge-runtime, plus `npm run build`) ; les identifiants par défaut (**G11**) ; le « mode simulation silencieux » présenté comme recommandé (**F7**). Pas d'avertissement « traduit automatiquement, corrigez-moi » sur les pages engendrées. **Tranché le 06/09 à 21 h (Xavier)** : le lien « Auto-hébergement » va dans le **pied de page** et sur la page Contribuer, **pas dans la barre de navigation principale** ; Bastien l'a posé dans les deux sur toutes les sous-pages des dix langues (point 4 de sa réponse de 20 h 45) — à retirer de la navigation avant fusion. Les quatre phrases et le bandeau « corrige-moi » sont réglés (tête `aca61fb1`). **21 h 12 (`832e2196`)** : fait — le lien a quitté la barre de navigation des dix langues et vit dans le pied de page et sur la page Contribuer (section dédiée) ; à 21 h 09 (`5c53ba58`) le guide dit aussi que l'installateur demande le nom de la biblio et le courriel admin, sans mot de passe par défaut. **Il ne reste plus que l'attente de la #28** et le mode simulation à ne plus proposer par défaut. **D4 tranchée (21 h 30)** : le mode simulation passe en **option 3, jamais par défaut**, dans `install.sh` comme dans le guide.

*Vérifié : 06/09 — PR #28 relue en entier (46 fichiers, tête `b5782ec1`), production interrogée en lecture seule, constat `CONSTAT_PR28_rejeu_vs_production_revoke_anon_2026-09-06`.*

**Ce que c'est.** Fusionner **après** la PR « auto-hébergement » (#28). Reste, côté Bastien : ne plus faire du mode simulation l'option 1 par défaut. Le README multilingue est parti seul dans la PR #3, fusionnable quand on veut.

**Pourquoi ça compte.** Le site vitrine est la seule chose que lit quelqu'un qui ne connaît pas encore le projet. Une promesse fausse y coûte plus qu'un bug : elle se lit dix fois avant qu'on la corrige.

**Ce qui compte comme fini.**

- Les quatre phrases sont corrigées dans les 10 langues, l'avertissement est là, la PR #28 « auto-hébergement » est fusionnée, puis celle-ci.

**Dépendances.** **I16**, **G11**, **G12**, **F7**.

*Renvois : `codeberg.org/AnarBib/pages/pulls/2` · `journal/operations/CONSTAT_PR28_rejeu_vs_production_revoke_anon_2026-09-06 §9.6` · `anarbib-vitrine-site-repo`*

#### J4 — `CHANTIERS_OUVERTS` §1 : écrire l'état réel après la première reconstruction extérieure

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : aucune compétence technique

**État.** L'entrée 1 (« Éprouver la reconstruction — le meilleur premier pas ») disait « personne ne l'a jamais vérifié ». Depuis le 06/09, quelqu'un l'a fait : Bastien a rebâti la pile depuis le dépôt seul et a trouvé les défauts du chemin de rejeu (`DOC-GRANT-2`). Sa PR réécrit l'entrée en « Validé le 28 août 2026, rejeu des 218 migrations » — date antérieure à la PR, chiffre retiré par lui-même, paragraphes « ce que ça demande / ce que ça apporte » supprimés ; c'est `DOC-CONSTAT-1`, et c'est le document d'orientation du mainteneur. Un état daté a été ajouté sous l'entrée le 06/09, sans toucher au texte.

*Vérifié : 06/09 — PR #28 relue en entier (46 fichiers, tête `b5782ec1`), production interrogée en lecture seule, constat `CONSTAT_PR28_rejeu_vs_production_revoke_anon_2026-09-06`.*

**Ce que c'est.** Au retour : le mainteneur réécrit l'entrée 1 lui-même — ce qui a été éprouvé, par qui, ce qui a cassé, ce qui reste (I17, I18, I19) — et décide si « le meilleur premier pas » reste l'entrée 1 ou passe à l'entrée 2.

**Pourquoi ça compte.** Ce document est la porte d'entrée des contributeurs. Y écrire « validé » avant que ce soit vrai renvoie la prochaine personne vers un chantier qu'elle croira clos.

**Ce qui compte comme fini.**

- L'entrée 1 porte une mesure datée, signée, et la PR #28 ne la réécrit plus.

**Dépendances.** Fusion de la PR « auto-hébergement » (**I16**).

*Renvois : `docs/CHANTIERS_OUVERTS.md` · `REGISTRE §0 DOC-CONSTAT-1` · `REGISTRE §0 DOC-ACTIF-1`*

#### J9 — Manuel v5 : le reliquat des captures — 180 emplacements en repli pt-BR, IMG-31 à refaire, IMG-08 à confirmer, tout à recapturer en 900-1000 px

`P2` Courant · État : **À vérifier** · Charge : quelques jours · Ce que ça demande : aucune compétence technique

**État.** Le portfolio du 02/09 laisse cinq choses ouvertes : 320 emplacements remplis dont **180 par repli pt-BR** (pas de capture en langue propre pour neuf locales) ; **IMG-31** reproduit une demande d'adhésion réelle encore en analyse (Solidaires) ; **IMG-08** laisse lisibles l'adresse et le courriel de la BLMF, « probablement délibéré, à confirmer » ; le texte fait ≈ 4,5 pt sur papier, d'où recapture à 900-1000 px et rognage du fond ; **IMG-20** attend le déploiement du correctif du sélecteur de périodique. Le manuel lecteur v2 du 03/09 a réutilisé les mêmes captures sans ce correctif. **Vérifié le 07/09 dans le dépôt** : les dix `docs/manual*.md` sont en v1.1 de septembre — cette partie-là est faite ; la branche et le worktree `manualv5` n'existent plus — fait aussi. Les captures elles-mêmes sont sur la machine de Xavier, hors de portée.

*Vérifié : 07/09 — manuels .md en v1.1 et branche supprimée (fait) ; captures non vérifiables depuis ici.*

**Ce que c'est.** Trancher IMG-31 (demande fictive ou floutage) et IMG-08 ; puis une passe de recapture à 900-1000 px, locale par locale, en commençant par celles qui ont des lectrices.

**Pourquoi ça compte.** Un manuel qu'on ne peut pas lire sur papier, et dont une image montre le dossier d'une bibliothèque qui attend une réponse, ne s'imprime pas pour Bologne.

**Ce qui compte comme fini.**

- IMG-31 et IMG-08 tranchées, avec la raison écrite.
- Les captures relues lisibles à l'impression.

**Dépendances.** IMG-31 touche **G7** (ne pas exposer une candidature en cours).

*Renvois : `claude/MANUEL_v5_portfolio_captures_2026-09-02` · `claude/MANUEL_LECTEUR_v2_refonte_2026-09-03`*

#### J10 — Sept domaines sont entrés dans le v17 sans avoir été arbitrés contre leur coût d'achèvement

`P3` Différé · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : aucune compétence technique

**État.** Le relevé du GLB v17 (01/09) le dit sans action datée : périodiques, notes de lecture, moisson OAI entrante, OPDS, sondes, témoin de sauvegarde, file des conventions — « aucun n'a été arbitré contre son coût d'achèvement ». Depuis, H5 (OAI) et I4 (témoin) sont clos ; les cinq autres sont livrés en partie et non arbitrés.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Cinq lignes : ce qui est livré, ce qui manque pour que ce soit fini, ce que ça coûte, et si on le finit ou si on le gèle avec la raison écrite (`P3`).

**Pourquoi ça compte.** Le gel de périmètre (`DOC-GEL-1`) ne vaut que si ce qui est entré pendant le gel est jugé — sinon il n'y a pas eu de gel.

**Ce qui compte comme fini.**

- Cinq verdicts au registre ou au backlog, datés.

**Dépendances.** Après Bologne. Sans dépendance technique.

*Renvois : `claude/GLB_v17_releve_et_constats_2026-09-01` · `REGISTRE §0 DOC-GEL-1`*

---

### K — Caisse, communication, formation

*Ce qui décide si le projet a des moyens et des bras, et non seulement du code.*

| | | | |
|---|---|---|---|
| **K1** | Faire adopter l'acte de création du Fonds AnarBib | `P0` | Bloqué |
| **K2** | Ouvrir les canaux d'encaissement dormants | `P1` | Bloqué |
| **K3** | Tenir le registre public des comptes | `P2` | Ouvert |
| **K5** | Tenir l'intervention de Bologne et en tirer les suites | `P1` | En cours |
| **K6** | Préparer la rencontre avec leftove.rs et May Day Rooms | `P2` | En cours |
| **K7** | Mener la formation des deux coordinations BLMF jusqu'à l'autonomie | `P1` | En cours |
| **K8** | Finir le texte d'orientation sur les outils de bibliothèques militantes | `P2` | Ouvert |
| **K9** | Les chiffres de Bologne sont périmés : « 620 descripteurs » est 623, « 55 parents introuvables » est « 138 rattachés, 10 sans tête » — quatre textes à corriger avant le 12 | `P1` | Ouvert |
| **K10** | Trois articles promis au *Monde libertaire*, un par mois — et une émission proposée à *Trous Noirs* | `P2` | À vérifier |

#### K1 — Faire adopter l'acte de création du Fonds AnarBib

`P0` Structurel · État : **Bloqué** · Charge : une soirée · Ce que ça demande : délibération collective

**État.** Un projet d'acte est rédigé et archivé. Il n'a pas été adopté. **C'est le préalable politique à l'ouverture de tout canal d'encaissement : rien ne bouge avant.**

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** L'acte doit faire quatre choses : créer le fonds, désigner nommément la personne qui tient la clé Pix, désigner la personne dépositaire de la part européenne, et fixer le principe du rapport annuel.

**Pourquoi ça compte.** Les frais de fonctionnement — environ **36 € par mois, 430 € par an**, intégralement adossés à des factures — sortent aujourd'hui de la poche d'une seule personne. Deux caisses sont prévues, avec un seul registre : la caisse brésilienne finance les dépenses locales, la caisse européenne finance l'infrastructure. **L'argent doit atterrir là où les factures se paient.**

**Ce qui compte comme fini.**

- L'acte est adopté et archivé.
- La personne qui tient la clé Pix l'accepte en connaissance de cause.
- Le nom public de la caisse est arrêté.
- **Son article 1 suffit à lui seul à publier un canal honnêtement, si l'assemblée tarde.**

**Dépendances.** Bloque **K2**.

*Renvois : `PLAN_financement_AnarBib_2026-08-25 §9` · `MINUTA_ata_fundo_anarbib_CCLA_2026-08-26`*

#### K2 — Ouvrir les canaux d'encaissement dormants

`P1` Prioritaire · État : **Bloqué** · Charge : quelques jours · Ce que ça demande : délibération collective

**État.** Liberapay est en ligne et a reçu son premier don le 27/08. L'encart « soutenir financièrement » est publié dans les dix locales et nomme Liberapay comme unique canal ouvert. **Pix et IBAN dorment** dans un bloc de commentaire HTML entre les marqueurs `ENCART-DORMANT-START` et `ENCART-DORMANT-END`. Wero est en attente d'une réponse de l'établissement bancaire.

*Vérifié : 31/08 — les marqueurs `ENCART-DORMANT-START` sont en place dans les dix fichiers du dépôt vitrine. Rien de neuf mesurable d'ici sur Pix, IBAN ou Wero.*

**Ce que c'est.** Côté Brésil : une clé aléatoire dédiée créée par la personne mandatée, et l'ouverture d'un compte au numéro d'entreprise — une coopérative de crédit est plus cohérente qu'une banque commerciale. Côté Europe : décider quel compte reçoit. Puis remplir les gabarits, retirer les deux marqueurs de commentaire, et supprimer les deux paragraphes « en cours d'ouverture ».

**Pourquoi ça compte.** Le Pix ne peut pas être créé depuis la France — l'élargissement d'août 2026 ne vaut que pour envoyer. Et une clé posée sur le numéro fiscal personnel d'un compa l'expose au contrôle fiscal : d'où l'urgence du compte au numéro d'entreprise. Sur l'IBAN, la recommandation écrite est de le publier **en clair** — un « demander par courriel » fera perdre plus de dons qu'il n'évitera d'ennuis.

**Ce qui compte comme fini.**

- Au moins un canal supplémentaire est ouvert et publié dans les dix locales.
- Le générateur des pages de comptes a été relancé après chaque édition de `FINANCES.md`.
- Si la réponse sur Wero est négative, **la phrase Wero est retirée du bloc dormant des dix fichiers** — le gabarit y est encore.
- Rappel : le hook `pre-push` refuse la poussée tant qu'un gabarit est visible hors du bloc dormant.

**Dépendances.** **Bloqué par K1.**

*Renvois : `PLAN_financement_AnarBib_2026-08-25` · `FINANCES.md`*

#### K3 — Tenir le registre public des comptes

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : aucune compétence technique

**État.** `FINANCES.md` est à la racine du dépôt vitrine et dix pages publiques en sont engendrées, par langue. Le générateur signale nommément toute cellule non traduite. Un tableau distinct porte ce qu'une personne a avancé avant que le fonds existe — environ **228 € de mars à août 2026** — et la question de savoir si c'est une dette à rembourser est laissée à l'assemblée.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Consigner chaque recette et chaque dépense au fil de l'eau, et relancer le générateur après chaque édition.

**Pourquoi ça compte.** **Consigner les avances passées dès maintenant, avant la délibération** — dans un an, personne ne se souviendra des montants. Le régime de transparence choisi est le rapport annuel plus les comptes sur demande ; il ne tient que si le registre est à jour.

**Ce qui compte comme fini.**

- Le registre est à jour et les dix pages reflètent son contenu.
- Anticipation notée : le renouvellement du domaine en mars 2027 coûtera plus cher, la promotion de première année ne se reconduisant pas.

**Dépendances.** Indépendant de **K1** et **K2**.

*Renvois : `PLAN_financement_AnarBib_2026-08-25` · `tools/build-finances-pages.cjs`*

#### K5 — Tenir l'intervention de Bologne et en tirer les suites

`P1` Prioritaire · État : **En cours** · Charge : quelques jours · Ce que ça demande : délibération collective

**État.** Atelier AnarBib le 12/09 au matin, assemblée ouverte le 13. Un jeu de 29 diapositives italien-anglais est prêt, ainsi qu'une brochure manifeste bilingue. Trois objectifs annoncés : la genèse et la conception, le panorama des fonctionnalités, et **un appel à participation**.

*Vérifié : 07/09 — deux chiffres des textes sont périmés (620 → 623 ; 55 parents → 10), sortis en **K9**. La clause Stripe de l'encart de soutien est en ligne dans les dix locales (vérifié sur `anarbib.org/fr/contribuer/`).

**03/09** — **collision de dates signalée** : le backlog place la formation BLMF le 13/09 (K7, E12, GOUV-18 « fenêtre d'objection à la formation du 13/09 ») et Bologne les 11-13/09 (atelier le 12, assemblée le 13). À trancher par Xavier : séance à distance depuis Bologne avec relais à Belém, ou autre date. La liste K5 (créneau, chronométrage, papier, démonstration hors ligne) est reprise en §5 de `docs/journal/chantiers/PARCOURS_formation_BLMF_seance1_2026-09-08.md`. **03/09, fin de journée — fausse alerte retirée.** Le plan de formation du 01/09 ne date pas la première soirée : il n'y avait pas de collision avec Bologne, seulement un « 13/09 » posé par hypothèse dans le backlog. K5 garde sa propre liste.*

**Ce que c'est.** Demander le créneau d'intervention à l'assemblée du 13, chronométrer la version italienne à voix haute, imprimer le dossier sur papier — tout le monde n'ouvre pas un PDF dans une salle —, et répéter la démonstration **hors ligne**, au cas où le réseau manque.

**Pourquoi ça compte.** L'appel à participation est ce qui décide de **A1** et de **A3**. Le but énoncé est qu'AnarBib cesse d'être un projet solitaire : que le code évolue par des contributions humaines plutôt que par de l'assistance automatique, et que les coûts soient mutualisés. Point de vigilance : la colonne « manquant » de la diapositive 21 est **largement périmée** — beaucoup de ce qu'elle liste a été livré depuis.

**Ce qui compte comme fini.**

- L'intervention a eu lieu et l'appel a été porté à l'assemblée.
- Les contacts pris sont consignés, avec ce que chacun a proposé.
- Sur l'accessibilité, dire les deux : des fonctionnalités sont implémentées, aucun audit indépendant n'a été mené (voir **E1**).

**Dépendances.** Gel du code en production à partir du 08/09.

*Renvois : `CALENDRIER_bologne_2026-08-27` · `PLAN_intervention_FICEDL_Bologne_2026-09-12`*

#### K6 — Préparer la rencontre avec leftove.rs et May Day Rooms

`P2` Courant · État : **En cours** · Charge : une soirée · Ce que ça demande : délibération collective

**État.** **Le message est parti** — autour du 19/08, soit trois semaines avant la rencontre, ce qui était exactement la fenêtre visée : assez tôt pour qu'ils regardent AnarBib sans que ce soit urgent. **L'atelier AnarBib est le matin, l'atelier leftove.rs l'après-midi du 12/09, même salle, même journée.** Ce qui reste ouvert, ce sont les réponses et la préparation de la journée.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Relancer si besoin, et préparer les trois questions posées pour qu'elles se discutent sur place : le vocabulaire de sujets, le profil de numérisation (ils ont 16 000 documents océrisés), et NORLA et la cartographie. Plus la question sur l'auto-hébergement au collectif technique présent.

**Pourquoi ça compte.** Deux ateliers le même jour dans la même salle, sur des sujets voisins, sans que les deux équipes se soient parlé, serait un gâchis. Et il y a un point à regarder avant, pas après : **leftove.rs est sous licence CC BY-NC-SA, et la clause non commerciale n'est pas une licence libre au sens strict.**

**Ce qui compte comme fini.**

- Les trois questions ont une réponse, ou un créneau de discussion est calé pour le 12/09.
- **Point à regarder avant la rencontre, pas après** : leftove.rs est sous licence CC BY-NC-SA, et la clause non commerciale n'est pas une licence libre au sens strict.

**Dépendances.** Le 12/09, dans la journée. Lié à **D4** (matériel éphémère) et **H6** (alignement des vocabulaires).

*Renvois : `VEILLE_leftovers_maydayrooms_2026-08-19` · `CALENDRIER_bologne_2026-08-27`*

#### K7 — Mener la formation des deux coordinations BLMF jusqu'à l'autonomie

`P1` Prioritaire · État : **En cours** · Charge : plusieurs semaines · Ce que ça demande : délibération collective

**État.** Le matériel est livré : 89 diapositives en portugais du Brésil, six modules, trois rencontres, six exercices pratiques, notes d'animation dans chaque diapositive. Ni l'une ni l'autre des deux personnes n'est bibliothécaire ou informaticienne.

*Vérifié : 07/09 — en base : la lectrice fictive « Voltairine de Teste » n'a **jamais** ouvert de session (`auth.users.last_sign_in_at` nul) ; aucun exemplaire créé depuis le 01/09, donc l'engagement « aucun exemplaire sans mode d'acquisition » n'est pas encore éprouvé. L'invitation BTL en attente est sortie en **G14**.

**03/09 — préparation de la séance 1, vérifiée en base.** Les deux coordinations ont leur compte sur `blmf-teste` (Mariana S. active le 30/08 ; **Rafael G. sans connexion depuis le 24/06** — à vérifier au début de séance) ; les cinq fiches fautives de l'exercice 2 y sont depuis le 26/08 (`TESTE-9001-1`…`9005-1`) ; **mais aucun lecteur fictif** (le seul retiré le 02/09) et **aucune règle de circulation ni horaire** — impossible d'y jouer une réservation. Posé le 03/09 : le jeu de règles de la BLMF (six règles) et ses horaires copiés sur `blmf-teste`. Reste à la main de Xavier : inviter deux lecteur·rices fictif·ves (le bac à sable n'accepte pas l'inscription publique), vérifier l'entrée de Rafael, **trancher la collision de dates avec Bologne (11-13/09)**, et retrouver le plan et le gabarit — **absents du dépôt, du poste et des transcripts** (les références `PLAN_formation…` et `GABARITO…` de cette fiche sont des fantômes tant qu'ils ne sont pas déposés). Le parcours de la séance, étape par étape, page par page, compte par compte : `docs/journal/chantiers/PARCOURS_formation_BLMF_seance1_2026-09-08.md`. **03/09, fin de journée — les documents sont au dépôt et le dispositif n'est plus celui de la fiche.** Xavier a fourni le plan (révisé le 01/09), le conducteur de la séance 1, le roteiro de la capsule, les 89 diapositives et « O salto colegial » : déposés dans `docs/journal/chantiers/formation-BLMF/`. Le plan dit **sept soirées de 2 h 15, six modules, six exercices, une capsule de 40 minutes** — plus trois rencontres ; l'exercice 0 devient un travail personnel ; l'engagement chiffré est inchangé (5 exemplaires sur 2 758 avec mode d'acquisition). **Le « 13/09 » n'apparaît dans aucun document** : la première soirée n'est pas datée, et « collision avec Bologne » était une fausse alerte née d'une hypothèse du backlog. Bac à sable : deux lecteur·rices fictif·ves créé·es sur `blmf-teste` (Emma Teste, Errico Teste, adresses de Xavier ; mot de passe à poser par « Esqueci minha senha ») ; Voltairine de Teste existe mais ses adhésions ont été remaniées le 02/09 (lectrice retirée) ; règles et horaires copiés de la BLMF. La page `docs/journal/chantiers/PARCOURS_formation_BLMF_seance1_2026-09-08.md` est réécrite en **compléments au conducteur**. Reste : dater la soirée 1, poser les mots de passe, Rafael G., et corriger dans les diapositives les quatre réserves dépassées listées au §7 du plan avant la soirée 4. **Soirée 1 datée par Xavier : le 08/09/2026** (17 h 00 – 19 h 15). Voltairine de Teste repassée **lectrice** (bibliothécaire retirée) ; Emma et Errico Teste se sont connecté·es le 03/09 à 16 h 15 et 16 h 18 : le bac à sable a ses trois lecteur·rices.*

**Ce que c'est.** Avant la première séance : créer sur `blmf-teste` les deux comptes de coordination, un ou deux comptes de lecture fictifs, et les cinq fiches fautives de l'exercice 2. Puis le suivi de huit semaines : cinq fiches par semaine **toutes avec leur provenance**, un jour de comptoir par semaine, une consultation menée de bout en bout avec négociation réelle, et le vote du profil de la bibliothèque porté en assemblée.

**Pourquoi ça compte.** Deux personnes autonomes sur la coordination d'une bibliothèque, c'est **A1** à l'échelle locale. Le principe pédagogique tient en trois mots — *« cliqua, não vai quebrar nada ! »* — et il est tenable parce que les transitions impossibles ne s'affichent pas, les boutons bloqués sont pré-désactivés avec une explication, et la base refuse les combinaisons impossibles. Les neuf gestes irréversibles sont nommés explicitement.

**Ce qui compte comme fini.**

- Les huit semaines sont faites, avec le rituel hebdomadaire de trente minutes et ses trois questions fixes.
- La feuille de lacunes alimentée par ce rituel devient l'ordre du jour suivant **et un matériau de contribution au projet**.
- L'engagement chiffré est tenu : **aucune fiche nouvelle sans mode d'acquisition** — le rattrapage rétroactif des 2 450 fiches sans donnée d'acquisition n'est pas demandé, seul l'arrêt de la dette l'est.

**Dépendances.** S'appuie sur **G3** et **G4** pour le bac à sable.

*Renvois : `docs/journal/chantiers/formation-BLMF/PLAN_formation_coordination_BLMF_2026-09-01.docx` · `docs/journal/chantiers/formation-BLMF/CONDUCTEUR_seance1_BLMF.pdf` · `docs/journal/chantiers/formation-BLMF/ROTEIRO_capsula_sessao1_BLMF.pdf` · `docs/journal/chantiers/formation-BLMF/Formacao_coordenacao_BLMF_AnarBib.pptx` · `docs/journal/chantiers/PARCOURS_formation_BLMF_seance1_2026-09-08.md`*

#### K8 — Finir le texte d'orientation sur les outils de bibliothèques militantes

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : délibération collective

**État.** `ORIENTATION_outils_bibliotheques_militantes_2026-08-26` est un **squelette destiné à être co-signé**. Six points sont explicitement à vérifier ou à trancher, et la section finale — celle qui porte l'appel — reste à écrire.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Lister quelques hébergeurs associatifs, vérifier la vitalité actuelle de PMB, vérifier la licence exacte de Pandora et ce qu'implique l'entrée d'une archive partenaire, vérifier l'adresse de contact du réseau ALN, trancher la ligne « catalogue consultable, pas de prêt » du tableau, faire compléter la description d'AnarcosyndicalismeBOOK, et **écrire ensemble la section finale « Ce qui manque » — c'est l'appel**.

**Pourquoi ça compte.** Trois positions du texte méritent d'être tenues telles quelles. **La question qui décide de tout : qui tiendra le serveur, et pendant combien de temps ?** **Soyez honnêtes sur l'échelle** — en dessous de quelques centaines de documents sans prêt, un tableur fait le travail, et **AnarBib est surdimensionné pour un petit fonds sans prêt**. Et la déclaration d'intérêt explicite : les deux projets comparés sont libres, les deux sont tenus par une seule personne — **se le dire vaut mieux que de le découvrir**.

**Ce qui compte comme fini.**

- Les six vérifications sont faites.
- La section finale est écrite à plusieurs.
- Le texte est traduit une fois stabilisé, pas avant.

**Dépendances.** Lié à **K5** et **H7**.

*Renvois : `ORIENTATION_outils_bibliotheques_militantes_2026-08-26`*

#### K9 — Les chiffres de Bologne sont périmés : « 620 descripteurs » est 623, « 55 parents introuvables » est « 138 rattachés, 10 sans tête » — quatre textes à corriger avant le 12

`P1` Prioritaire · État : **Ouvert** · Charge : une soirée · Ce que ça demande : aucune compétence technique

**État.** **Mesuré sur l'aspiration du 03/09, le 07/09.** 620 → **623** descripteurs entre le 30/06 et le 03/09 (trois dates apparues : `1927`, `2026`, `2027`, zéro disparition). Et sur les 148 descripteurs hiérarchisés, 55 parents étaient introuvables au 28/08 — **45 se résolvent par la variante `X (généralités)`** ; il reste **10** vrais regroupements sans concept (`guerres` ×9, `art : courants` ×1). Les deux chiffres sont dans la présentation du 12, l'intervention du 13, le texte d'orientation et les conventions d'interopérabilité.

*Vérifié : 07/09, soir — la source confirme que `X (généralités)` est la tête : le « 45 / 10 » devient « 138 rattachés / 10 sans tête ».

07/09 — chiffres mesurés ; textes non encore corrigés.*

**Ce que c'est.** Dire « plus de six cents » ou « 623 au 3 septembre » ; remplacer « 55 sur 148 n'existent pas » par « 138 sur 148 sont rattachés à leur tête `X (généralités)`, confirmé par la source ; 10 ne le sont pas » — et poser la seule question qui reste : « `guerres` et `art : courants` sont-ils des groupes de mots-clés dans SPIP ? ».

**Pourquoi ça compte.** Le vocabulaire a bougé sans que personne l'apprenne : c'est l'argument de l'intervention, mesuré sur ta propre copie. Mais prononcer un chiffre faux devant les gens qui tiennent le site, c'est perdre l'argument.

**Ce qui compte comme fini.**

- Les quatre textes portent les chiffres du 03/09 et la question reformulée.
- Le foglio italien imprimé est la version corrigée.

**Dépendances.** Avant **K5** (12/09). Sans dépendance technique.

*Renvois : `claude/REPONSE_hortical_deux_thesaurus_2026-09-07 §5-6` · `claude/PRESENTATION_samedi_bologne_2026-09-12` · `claude/INTERVENTION_assemblee_ouverte_bologne_2026-09-13` · `claude/ORIENTATION_outils_bibliotheques_militantes_2026-08-26` · `claude/CONVENTIONS_interoperabilite_catalogues_libertaires_2026-08-26`*

#### K10 — Trois articles promis au *Monde libertaire*, un par mois — et une émission proposée à *Trous Noirs*

`P2` Courant · État : **À vérifier** · Charge : quelques jours · Ce que ça demande : langue maternelle

**État.** Session du 30/08 : le courriel à Monique et Serge (Radio Libertaire, *Trous Noirs*) écrit « Le Monde libertaire en publie trois articles dans les mois qui viennent, un par mois ». **Non vérifié** : ni la remise du premier article, ni l'envoi du courriel, ni la réponse. Aucun item du backlog ne portait cet engagement.

*Vérifié : 07/09 — engagement relevé dans une session, aucune trace de suivi ailleurs.*

**Ce que c'est.** Dire ici où en sont les trois articles (rendu, relu, publié) et si le courriel est parti ; puis tenir le rythme — un article par mois est une dette qui se voit.

**Pourquoi ça compte.** Une promesse faite à un journal militant engage le projet autant qu'un déploiement : elle se lit dans les numéros où l'article manque.

**Ce qui compte comme fini.**

- Trois dates de parution, ou une renégociation écrite du rythme.

**Dépendances.** Voisin de **K5** ; sans dépendance technique.

*Renvois : `session Cowork « Monde libertaire article publication », 30/08/2026`*

---

## Clôtures et entrées caduques

Ces entrées figuraient dans le v33, dans `ETAT-AVANCEMENT-multisessions`, dans `ETAT-lancement-consolide` ou dans les notes d'août. Elles sont closes, vérifiées le 29/08. Elles sont listées pour que personne ne les rouvre en croyant avoir trouvé un oubli.

| | | |
|---|---|---|
| #25 · #33 | Cotisations : cron d'expiration et test de blocage | Livrés le 03/07. Le cron `anarbib-membership-expiry-daily` tourne à 6 h 40. |
| #4 | Les cinq livrables de la session de juin | Intégrés le 03/07 (commit `cd5c7d967`). Attention : l'identifiant `#4` désigne deux objets différents selon le document — celui-ci et un item sans intitulé du v32. |
| #5 | Performance du rapprochement à l'import | Volets A, B et C confirmés le 03/07 ; la rustine `statement_timeout=0` a été remplacée par une borne de 120 s (migration `20260703182035`). La ligne « toujours ouvert » d'`ETAT-AVANCEMENT` est fausse et corrigée par le fichier lui-même. |
| AR-1 · AR-2 | Plancher de durée sur la connexion, retrait de Turnstile | Faits le 20/08. Turnstile est retiré côté client et serveur, **sans substitut** : sa réapparition serait une régression. |
| AR-3 · AR-4 | Altcha auto-hébergé et anti-rejeu | Fonction déployée le 19/08, migration `altcha_anti_rejeu` appliquée le 20/08. Les notes qui les donnent « à mettre en œuvre » sont périmées. |
| Crons RGPD n°6 et n°7 | « Désactivés — à clarifier » | **Faux.** Les 36 jobs sont actifs. Entrée caduque. |
| Trois crons de gouvernance | « Désactivation volontaire ou oubli ? À trancher par la coordination » | Réactivés par `20260821070000` et `20260827080000`. Aucune décision n'est due. |
| login-with-identifier | Doublon de fonction Edge à supprimer | **La fonction n'existe pas.** Seule `login` est déployée. |
| fn_v2_set_reserva_linhas_workflow | Coexistence des signatures à 5 et 7 arguments | **Une seule signature existe.** Et il n'y a plus aucun doublon de signature dans les quatre schémas applicatifs. |
| _backup_*_20260408 | Tables de rebut à nettoyer | Aucune n'existe dans `public`. Reste `backup_2026_05_07`, qui est l'item **B9**. |
| api.resolve_reader_card | Résolution de carte de lecture absente | Livrée. Migration `20260821020000_resolve_reader_card_motif_neutre` appliquée le 21/08. |
| Plafond des PDF | « Relever de 300 à 500 Mo — un chiffre dans une migration, cinq minutes » | Fait le 20/08 (`plafond_pdf_500mo_recueils_illustres`). |
| Lot « vocabulaire des droits » | « Douze fichiers posés sur disque, à commiter » | Commité et appliqué le 20/08 (`vocabulaire_rights_status`). Reste la collision de nom, item **C10**. |
| Six migrations de conventions | « Écrites, jamais appliquées » | **Dix-neuf migrations `conventions_*` appliquées le 21/08.** Le chantier est allé bien au-delà. Reste la revue humaine, item **C3**. |
| Collégialité de la promotion | « Migration écrite, non appliquée » + runbook en 11 étapes | Appliquée le 26/08. Le runbook est caduc ; restent la répétition (**G3**) et la décision politique (**G2**). |
| Périodiques P1 à P9 | « Neuf paquets à livrer » | **Les neuf livrés les 27-28/08.** Reste la révision de la spec, item **D1**. **Nuance du 02/09 : P7 était livré, pas exercé.** Le sélecteur de titre de revue (`SerialAuthorityPicker`) était dans le bundle depuis le 27/08 et **jamais monté** dans la fiche de catalogage — déclaré dans un point d'extension (`sectionExtras`) que la fiche ne lit pas pour la zone Periódico, dont les champs sont rendus un par un. Six jours sans qu'un fascicule puisse être rattaché depuis la fiche, lint, tests et build verts. Constaté en prod le 02/09, corrigé le jour même (`9d9b7744`), vérifié à l'écran avec une session de coordination, gardé par `src/tests/serial-picker-monte.test.js` ; consigné dans `spec-periodiques-v1.0-etat-livre`. Même famille que « déclaré livré, jamais exercé ». |
| notify-cross-library-digest | Fonction signalée absente du dépôt | Présente, déployée, confirmée trois fois. **Ne rien supprimer.** |
| #PUBLIB · #FED · #ASSEMBLEIAS · #THES · #GAZ · #MOBILE (socle) | Macro-chantiers du v33 | Livrés et en production. À nuancer d'un point : plusieurs de ces circuits **n'ont jamais été empruntés** — c'est l'item **G1**, qui n'est pas une réouverture mais un constat d'usage. |
| npm ci | Réparation des dépendances locales | Fait le 27/08. `@supabase/auth-js` a retrouvé son point d'entrée. **Ne pas le rejouer sans raison.** |
| Encart de soutien financier | « À rédiger dans les dix locales » | Publié le 26/08 (`47d23fa`). Liberapay en ligne, premier don reçu le 27/08. Registre public en place depuis le 27/08. |
| A5 | Configuration git à deux URL de poussée | **Déjà corrigé.** Constaté le 29/08 dans `.git/config` : `origin` ne porte qu'une seule URL de poussée (Codeberg) et GitHub est un remote nommé à part. Le correctif prévu après les quatre incidents du 19/08 a été appliqué. Il n'y a plus d'alias `git publish-app` : on pousse sur les deux remotes explicitement. |
| B1 | Huit tables du schéma `ingest` sans RLS | **Livré le 29/08** — migration `20260830140000_ingest_ne_depend_plus_d_un_grant`, suite `ingest_ferme_tests.sql` (7 tests) au manifeste, hook `pre-commit` étendu à `ingest`. Vérifié en base après déploiement : 10 tables sous RLS, aucune en FORCE, les 2 172 lignes de staging et les 2 084 liens intacts. **Mais la fiche avait tort sur l'essentiel** : `anon` et `authenticated` n'ont jamais eu `USAGE` sur ce schéma, donc aucune faille n'était ouverte. Le paquet est un second verrou, pas une correction — et la « priorité haute » annoncée reposait sur l'absence de RLS sans avoir regardé les droits. |
| A4 | Une porte d'entrée pour qui veut aider sans coder | **Livré le 29/08** — `AIDER.md` à la racine, en français, portugais et anglais : sept entrées, chacune avec son identifiant de backlog, ce qu'elle demande, ce qu'elle apporte et **le chiffre du jour**. C'est ce que la page `/contribuer` du site ne fait pas, à raison : elle est générique et intemporelle. Deux erreurs de `CONTRIBUTING.md` corrigées au passage — il renvoyait vers `specs/REGISTRE_decisions.md`, chemin inexistant (le fichier est dans `docs/specs/`), deux fois, en français et en anglais ; et il annonçait encore Woodpecker. |
| B3 | Les sept vues `api` restées hors des policies | Soldé le 29/08 (migration `20260830160000`), **puis corrigé le 30/08** (`20260830180000`). Les quatre vues gazette/lettre sont passées en `security_invoker` dès le premier jour. Les deux vues de gouvernance avaient été gardées hors des policies avec la clause de visibilité recopiée dans la vue : motif exact — en invoker, la jointure sur `profiles` renvoie NULL à l'administratrice qui doit décider — mais c'était le **symptôme d'une policy manquante**, pas une raison de contourner. L'advisor Supabase le signalait en `ERROR`, à raison. Le lendemain, deux policies étroites ont remplacé la dérogation : `profiles_select_gouvernance_en_cours` (les personnes concernées par une délibération **en cours**, admins réseau et personne visée) et `rls_crv_select` élargie à la personne visée — qui, sans elle, aurait lu **« 0 vote » au lieu du décompte réel**, un chiffre faux et silencieux. État vérifié en base : **une seule** vue hors des policies (`library_email_identity`, accordée à aucun rôle applicatif). Suite `vues_api_definer_tests.sql`, 7 tests. |
| J5 | Les incohérences du corpus documentaire | Soldé le 29/08. `PRIV` quitte le §17 qu'il partageait avec `IMP` et devient §42 sans renuméroter le normatif déjà inscrit (`#HYG-REG-1`) ; le §2 `MAP` porte son renvoi vers le §34 ; les sept specs orphelines sont référencées dans `docs/specs/INDEX.md` ; Woodpecker corrigé en Forgejo Actions ; les chiffres de `docs/INDEX.md` remis au réel (970 lignes, 44 sections, 42 specs, 10 locales). Et les deux identifiants cités depuis juin sans jamais figurer à la table des doctrines — `DOC-COLLECTIVE-1`, `USER-EMAIL-1` — y sont inscrits, le second après vérification du trigger en base. REGISTRE en v0.5. |
| I7 | Les six suites SQL oubliées de l'intégration continue | Soldé le 29/08 au soir. Les six suites sont au manifeste — 45 en tout — et **le harnais passe au vert de bout en bout**. Elles ont d'abord produit 35 échecs pour **quatre causes, dont une seule tenait au produit**. (1) Le stub d'authentification castait `current_setting('request.jwt.claims')` en `jsonb` avant de neutraliser la chaîne vide, si bien qu'`''::jsonb` levait une erreur là où la vraie fonction Supabase renvoie NULL : **aucune suite du corpus ne testait le rejet d'un appel anonyme**, elles éprouvaient un plantage du banc d'essai. (2) Le seed n'avait ni lecteur ni exemplaire. (3) Quatre tests avaient tort contre un produit qui avait raison, et leur correction les a rendus **plus** exigeants — le partage `anon`/`authenticated` est désormais gardé dans les deux sens, et le refus d'`administrador` est testé pour lui-même. (4) `paquetA` et `paquetA1` se terminaient par un `SELECT` d'une chaîne **constante** annonçant « 15/15 tests passent », imprimée même après un échec ; `paquet19`, `paquet25` et `paquet26` réussissaient et étaient comptées rouges faute d'un bilan à la forme que lit la CI — l'une d'elles sur deux espaces autour d'une barre oblique. Le sort des onze SKIP restants passe à **I15**, où il relève de la réécriture. |
| I14 | Les identifiants de production dans les fixtures de test | Soldé le 29/08 dans la nuit, le jour même du constat. Sixième règle bloquante du hook `pre-commit` : dans `tests/sql/`, tout UUID d'apparence réelle absent du seed est refusé. La liste blanche est **lue** dans `supabase/seed.sql` plutôt que recopiée — ajouter un acteur, c'est l'ajouter au seed ; les valeurs visiblement synthétiques restent tolérées pour que chaque suite forge ses fixtures dans sa transaction. Doctrine `DOC-FIXT-1` au REGISTRE (v0.6). En s'installant, la règle a fait sortir `cleanup-frt-2026-05-15.sql` de `tests/sql/` : script de ménage ponctuel qui nommait légitimement une bibliothèque réelle — un script de maintenance doit nommer du réel, c'est sa place parmi des fixtures qui était fausse. Il part en archive, vérification faite que la bibliothèque n'existe plus. **Limite assumée** : le seed contient l'identifiant réel de BLMF, dont dépend la suite cotisation ; la règle le tolère parce qu'il est au seed, pas parce qu'il serait synthétique. |
| I15 | Les trois suites de circulation d'avant la CI, et les deux chemins E2E | **Soldé le 30/08.** Douze branches `jwt sim` retirées ; les dénominateurs de `paquet25`, `paquet_emprestimos` et `paquet_reservas` incluent désormais les skips — sans quoi une régression du stub d'authentification aurait fait passer une suite de `32/32` à `20/20` en restant verte ; six gardes qui cherchaient un texte de HINT dans `SQLERRM` (qui porte le MESSAGE) remplacées par le code levé ; trois tests qui comptaient un succès dans toutes leurs branches réécrits ; deux étiquettes qui nommaient des personnes renommées. Les **deux chemins E2E sont écrits** — emprunts (prêt → entête ouverte → renouvellement → retour → exemplaire libéré) et réservations (création → refus du second envoi → annulation → invariant entête↔lignes) — et le seed porte le jeu de règles de circulation sans lequel renouveler était impossible. Plus aucun SKIP dans les cinq suites. **Ce que la journée a appris, trois fois : le produit avait raison et le test lisait le mauvais champ** — le hint au lieu du message, l'effet au lieu du contrat, `due_at` au lieu de `extended_until`. Et deux fois, la garde qui protège n'était pas celle qui porte le nom du risque : RLS ferme avant le contrôle d'appartenance, la disponibilité ferme avant le doublon. La question de produit qui en sort — un refus qui ne lève pas — est devenue l'item **B15**. |
| F5 | Le délai de négociation de 21 jours des réservations | **Vérifié et clos le 30/08.** Le mécanisme est implémenté, et mieux que ne le disait la spec : `fn_expire_negotiation_timeout()` **lit le délai par bibliothèque** dans `library_notification_policies.reservation_negotiation_timeout_days` au lieu de le figer, la colonne porte exactement le `DEFAULT 21` et le `CHECK BETWEEN 7 AND 60` décrits au §5 de la spec, et les trois bibliothèques du réseau sont à 21 jours. Le cron `anarbib-reservation-expire-negotiation` tourne toutes les heures. La spec portait encore « À valider avant implémentation » : son en-tête est corrigé le même jour, en distinguant ce qui est **bâti** de ce qui reste à **voter** — le principe politique de la négociation symétrique n'a pas été soumis au CCLA sous cette forme. |
| I9 | Les migrations horodatées dans le futur | **Clos le 30/08 par une règle, pas par une correction.** L'item signalait trois migrations datées en avance. Vérification faite le 30/08 : elles n'y sont plus — **mais parce que l'heure les a rattrapées**, pas parce qu'on les a corrigées. Un item qui se résout par l'écoulement du temps ne se résout pas, il repousse : le soir même, deux nouvelles migrations apparaissaient, datées de 20:30 et 21:00 UTC alors qu'il était 19:15. Corriger les trois fichiers nommés n'aurait donc rien réglé. **Huitième règle du hook `pre-commit`** : une migration ajoutée dont l'horodatage dépasse l'heure UTC réelle (tolérance 60 s pour l'écart d'horloges WSL/Windows) est refusée. Ce que coûtait le défaut, tant que l'heure n'avait pas passé : toute migration écrite entre-temps à l'heure réelle trie **avant** celle du futur et sera rejouée après elle en CI — l'ordre du dépôt cesse d'être l'ordre d'application, même dégât qu'une collision par un autre chemin. Complète `DOC-DEPLOY-4`. |
| B8 | Les vues « en double » entre `public` et `api` | **Vérifié et clos le 30/08 — l'item se trompait de diagnostic.** `my_access` et `my_session_context` n'existent pas en double : les versions de `public` sont des **projections** de celles de `api` (300 caractères contre 2 100). Un seul foyer, une façade par-dessus : c'est bien construit, il n'y a rien à réconcilier.

Mais la vérification a trouvé autre chose, qui valait le détour. **La façade énumère ses colonnes** : ajouter une colonne à `api.my_access` ne la fait pas apparaître dans `public.my_access`, qui continue de projeter la liste écrite le jour de sa création. Et **31 fonctions déclarent `v_actor public.my_access%rowtype`** — la forme de la façade est devenue un *type*. Une divergence ne lèverait donc rien : les 31 compileraient et ne verraient simplement jamais la colonne neuve. Une divergence par **omission**, la seule qui ne fasse aucun bruit.

Au 30/08 les deux couples concordent (20/20 et 13/13 colonnes). Gardé par le **T8** de `vues_api_definer_tests.sql`, qui n'y répare rien mais empêche que ça cesse d'être vrai sans que personne ne le voie. |
| B6 | `config.toml` et les 48 fonctions déployées | **Réconcilié et clos le 30/08 — le fichier était juste depuis le début.** L'item annonçait que « 18 des 48 fonctions déployées ne sont pas déclarées du tout ». Comparaison faite, section par section, contre `supabase functions list` : **31 déclarées, toutes à `false`, et toutes à `false` en production ; 17 non déclarées, toutes à `true` en production. Aucun désaccord, dans aucun sens** — pas une déclaration orpheline, pas une valeur divergente.

La conclusion de l'item reposait sur un contresens : **ne pas déclarer une fonction n'est pas un oubli, c'est la façon de lui laisser le défaut de la plateforme** — et ce défaut est le réglage le *plus fermé*. Déclarer les 48 ajouterait du bruit et une seconde source de vérité à tenir à jour. La doctrine écrite en tête du fichier disait déjà exactement cela.

Ce qui était faux, ce sont les **chiffres du commentaire** — « 17 en `false` et 6 en `true` », datés du 07/05 — et ceux de `CLAUDE.md`. Trois documents se contredisaient au sujet d'un fichier qui, lui, avait raison. Le commentaire est refait, daté, et dit désormais où est la source de vérité : la liste des sections `[functions.*]`, pas la prose qui la commente. |
| J3 | Les affirmations fausses de la spec des consultations | **Corrigé et clos le 30/08 — et le constat était en dessous de la vérité.** L'item relevait trois affirmations fausses : BLMF en `full_sigb`, BTL en `informal`, `BLT-test` en `informal`, le tout « vérifié en prod ». Relevé sur `public.libraries` le 30/08 : les **cinq** bibliothèques — `blmf`, `blmf-teste`, `btl`, `cira-marseille`, `mleg` — sont **toutes** en `circulation_mode = full_sigb`. La spec ne se trompait pas sur trois lignes : elle illustrait une **diversité de profils qui n'existe pas**.

Ce qui en découle vaut plus que la correction elle-même. La doctrine reste juste — elle décrit ce que le produit fait selon le profil — mais les comportements adaptatifs `informal` et `off` **n'ont jamais été éprouvés sur une bibliothèque réelle**, contrairement à ce que « validés au paquet E.0-E.5 » laissait entendre. Ce qui a été validé l'a été sur des bascules de test, pas sur un usage. La ligne le dit désormais, avec la date du relevé. |
| J1 | Les chiffres de `CLAUDE.md` et du `README.md` | **Clos le 30/08, et par la seconde branche de l'alternative que l'item posait lui-même** — « peut-être un renvoi vers le backlog vaut-il mieux qu'une copie ».

Le matin, la section d'état du `README` a été recomptée en base et son titre neutralisé : il annonçait « État au 7 juillet » tout en décrivant des faits d'août, ce qui est la façon la plus discrète de vieillir — le lecteur date le contenu d'après le titre. **Le soir du même jour, le recomptage du matin était déjà faux** : « 224 migrations, la dernière étant `20260830180000` » alors que la base en portait **231**, la dernière étant `20260830210000`. Sept migrations en douze heures, et rien dans un `README` ne signale qu'un nombre a vieilli.

La démonstration étant faite en une journée, les chiffres cèdent la place à un **renvoi vers `docs/backlogs/`**, qui porte une photo datée et dit d'où vient chaque nombre. **Un renvoi ne périme pas ; une copie, si.**

`CLAUDE.md` a reçu les mêmes corrections, mais il est gitignoré depuis le 23/07 : **rien de ce qui n'y est écrit n'atteint un·e contributeur·rice**, et tout y disparaît au re-clonage. Le `README` le dit déjà à sa section Architecture. C'est un argument de plus pour que l'état chiffré vive au dépôt, et un seul endroit. |
| J4 | La section 14 de la spec de gouvernance des rôles | **Clos le 30/08 — le travail avait été fait le 26/08, seul le pointeur ne l'avait pas suivi.** L'item demandait de réécrire les §14 et §5.3, qui listaient « à implémenter » des objets tournant en production. C'est déjà fait : la spec porte **v1.4.1 (26/08/2026)**, son §14 est refait sur état constaté, et il va plus loin que l'item ne demandait — il note que la liste précédente annonçait « à faire » des objets présents dans le dump de référence **antérieur de cinq jours**, et il distingue **« livré » de « éprouvé »** : le circuit d'invitation était livré depuis deux mois et n'avait jamais servi, zéro ligne au 26/08. Son §14.2 nomme même les deux affirmations qu'il n'a **pas** vérifiées, plutôt que de les recopier comme si elles l'étaient.

Ce qui restait faux était l'**index des specs**, qui annonçait v1.3 (24/05) — trois mois et une refonte en arrière. Corrigé, avec la mention de l'écart. Un second écart a été trouvé au passage : `spec-migration-mail-resend`, index v0.4 contre v0.6 dans le fichier archivé.

Contrôle mécanique fait sur les **48 liens** de l'index : **aucun lien mort**. La quatrième fois de la journée qu'un item du backlog décrivait le pointeur et non l'objet — après B6, J1 et J3. |
| B16 | Le slug d'une bibliothèque perdait ses majuscules et ses accents | **Corrigé et clos le 30/08, le jour même de son ouverture — et le constat était en dessous de la vérité.** L'item disait « perd ses majuscules » en citant la première lettre. Mesuré en base : ce sont **toutes** les majuscules qui tombaient, `lower()` étant appliqué après le filtre `[^a-z0-9]`. « Biblioteca Terra Livre » ne donnait pas `iblioteca-terra-livre` mais **`iblioteca-erra-ivre`**. Les accents tombaient dans le même filtre, le `translate()` censé les replier étant un no-op : « Associação Cultural Ñandú » donnait `associa-o-cultural-and`.

Le calcul sort du corps de `fn_provision_preactive_library` pour devenir `fn_library_slug_from_name`, nommée et testable seule : minuscules d'abord, accents repliés par `extensions.unaccent` (l'extension était déjà installée), tout le reste en tirets. Vérifié en provisionnant réellement une bibliothèque de test en transaction annulée — « Associação Cultural Ñandú » ressort en `associacao-cultural-nandu`.

**Les slugs existants ne sont pas renommés**, et c'est écrit dans la migration : un slug vit dans les URL publiques, dans `library_commons.library_slug` et dans le chemin de stockage `themes/<slug>/logo.png`. Les renommer casserait les trois d'un coup, dont l'affichage des logos. La correction ne vaut que pour les bibliothèques à venir.

Suite `tests/sql/slug_biblioteca_tests.sql`, 7 tests. Le T5 est celui qui compte sur la durée : il refuse qu'on réinsère le calcul dans le corps de la fonction de provisionnement, ce qui réintroduirait le défaut sans qu'aucun voyant ne rougisse. |
| I5 | Une alerte de CI qui se répète à chaque itération n'alerte plus | **Clos le 31/08 — et c'est le premier item de la série fermé parce que le problème est résolu, non parce que le constat était faux.** Le constat, lui, l'était aussi : il disait qu'un rouge de CI passait inaperçu. La forge portait 24 tickets `[CI rouge]`, dix pour la seule journée du 30/08, et les courriels étaient bien partis. L'alerte ne manquait pas — **elle débordait**.

**La cause n'était pas dans le code mais dans l'usage qu'il imposait.** L'anti-doublon d'`OPS-6` ne joue que tant que le ticket reste *ouvert* ; or la convention écrite disait « refermer vaut acquittement », et pendant une soirée de mise au point refermer veut dire « j'ai vu ». Chaque clic réarmait l'alarme pour l'itération suivante : dix tickets et dix courriels **pour un seul et même rouge**. C'est très exactement la panne qu'`OPS-6` voulait éviter — *un pipeline qui échoue une fois sur deux cesse d'être lu* — arrivée par l'autre bout.

**L'épreuve a trouvé deux défauts que la relecture n'avait pas vus.** Le troisième rouge d'une heure n'a ouvert aucun ticket : **HTTP 429**, *« posted 2 similairy named issues in the last hour: rate limited »*. Codeberg plafonne à deux tickets de titre semblable par heure — la protection censée fermer l'angle mort du 17-20/08 le rouvrait donc d'elle-même dès qu'une heure devenait chargée, c'est-à-dire précisément quand on en a besoin. Et le job affichait **`Job succeeded`** : un `continue-on-error` et un `|| echo 000` faisaient que l'alerte se taisait sur sa propre panne. `DOC-SILENCE-1` violé à l'intérieur du dispositif d'alerte.

**Livré** : un job `acquittement` symétrique de `alerte` dans les deux workflows, et `alerte` refondu autour d'un modèle différent — **un seul ticket par workflow, pour toujours**. Ouvert au premier rouge, **rouvert** aux suivants avec le commit et le run en commentaire, refermé au retour au vert. Son état est le miroir vivant de la santé de la CI, ses commentaires en sont le journal. La limite de la forge devient inatteignable puisqu'on ne crée plus jamais de second ticket, et l'anti-doublon cesse d'être une comparaison de chaînes pour devenir un état. `continue-on-error` retiré de `alerte` — sur le chemin de l'échec il n'y a rien à masquer — et conservé sur `acquittement`, qui tourne sur un run vert.

**Éprouvé de bout en bout, cinq états, cinq observations**, à l'aide d'une suite jetable écrite pour échouer puis retirée le jour même. Rouge → ticket ouvert. Vert → `Fermeture du ticket #27 : HTTP 200`, refermé une seconde après son propre commentaire. Rouge → `Reouverture du ticket #27 : commentaire HTTP 201, etat HTTP 201`. Rouge encore, ticket déjà ouvert → `Ticket #27 deja ouvert : cet episode rouge est deja signale, rien a faire.` — aucun courriel, aucun commentaire, aucun ticket neuf. Vert → `Fermeture du ticket #27 : HTTP 201`. La condition en crochets `needs['sql-tests'].result`, jamais exercée jusque-là, a tourné pour de bon.

Doctrine `OPS-8` : **l'acquittement d'une alerte est l'état du système, pas un geste humain répété.** Revers exact de `DOC-SILENCE-1` — un dispositif qui parle sans arrêt ne dit plus rien ; dans les deux cas ce qui manque n'est pas le mécanisme, c'est la restitution. |
| B12 | Un envoi non effectué ne disait pas pourquoi — et dans un cas, la table affirmait le contraire | **Clos le 31/08.** Le constat n'était pas faux, il était trop petit — et l'instruction a sorti trois choses.

**Les quatre lignes sont un seul event.** Elles portent toutes `network.cross_library_critical_action`, et ce sont les **seules** de cet event : il n'est jamais parti depuis le 8 juin, quand tous les autres partent à 100 %. La cause est un handler absent dans `_shared/domain/network.ts` — onze events `network.*` y sont traités, pas celui-là. Il tombe dans le `else` final, journalise en console, marque `skipped` et retourne **`ok: true`**. C'est devenu l'item **B17**, en P1 : la spec §6.3 promettait « mail immédiat aux coordenadores actifs de la biblio », c'est-à-dire le contrepoids au seul pouvoir transverse du réseau. Pas un défaut d'envoi, un défaut de gouvernance.

**Le silence n'était pas cantonné à cet event.** Le dépôt compte **sept** tables d'outbox ; cinq ont un handler qui peut décider de ne pas envoyer, et **aucune** ne recevait la raison — que le code nomme pourtant (`unknown_*_event`, `no_recipients`) avant de la jeter faute d'une colonne. Toutes posaient `sent_at` sur une ligne dont rien n'était parti.

**Et `authority.ts` faisait pire.** Il marquait **`sent`** quoi qu'il arrive, y compris quand son propre routage venait de retourner `{skipped: "unknown_event"}`. Sa table n'ignorait pas qu'un envoi avait manqué : **elle affirmait qu'il avait eu lieu**. Son enum de statut n'avait même pas le mot `skipped` — il n'avait pas le vocabulaire pour dire la vérité.

**Livré** : colonne `skip_reason` sur les cinq tables ; deux `CHECK` par table — pas de saut sans raison, pas de `sent_at` sur un saut — pour que l'oubli soit **impossible** plutôt que déconseillé ; `skipped` ajouté à l'enum d'`authority` ; les sept sites du code qui sautent écrivent leur raison ; les quatre lignes reprises. Suite `outbox_raison_du_saut_tests.sql`, 8 tests dont quatre qui **écrivent** — vérifier qu'une colonne existe ne prouve rien, ce qui doit rester vrai c'est que la base **refuse** une ligne muette.

**Vérifié en production après déploiement** : 5 colonnes, 10 gardes, 4 lignes portant `unknown_network_event` avec `sent_at` à `NULL`, 0 ligne muette.

**Et l'échec en chemin a valu une doctrine.** La première version posait les gardes *avant* la reprise : verte en CI, refusée par la production — `check constraint … is violated by some row`. La CI ne pouvait pas le voir, elle reconstruit une base vide. **Une migration qui ne casse que sur des données existantes est invisible à un banc d'essai qui part de zéro.** D'où `DOC-MIGR-1` : colonne, puis reprise, puis garde — jamais l'inverse.

Hors portée, délibérément : les deux tables `painel_internal_task_*`, servies par la copie gelée de la pile courriel (**F6**). |
| B15 | Un refus qui ressemblait à un succès : 26 appels sur 34 ne lisaient pas le `ok` | **Clos le 31/08 — et le recensement a retourné l'item.** `api.renew_my_loan`, citée comme le cas fautif qui a fait naître B15, est l'une des rares **conformes** : le front y lit bien le `ok`. Le défaut était ailleurs, et bien plus large.

**Le relevé.** 34 RPC appelées par le front rendent `{ok, reason, …}` au lieu de lever. **26 appels n'inspectaient pas `ok`**, et dix-huit écrivaient `const { error } = await supabase.rpc(...)` : la charge utile jetée à la destructuration, le `ok` non pas ignoré mais **inatteignable**. Trois sites relus à la main pour vérifier que l'outil ne mentait pas — motif identique. `BookPage` affichait « consultation demandée » sur un `ok:false` ; `LeitoresPanel`, « promue » pour une promotion qui n'avait pas eu lieu ; quatre autres étaient dans `AccountPage`, côté lectrice.

**La doctrine, tranchée** (`DOC-RPC-4`, qui règle la question laissée ouverte par `DOC-SILENCE-1` *(b)*). Le contrat de statut est **gardé** : une RPC qui lève coupe le lot en cours, une RPC qui rend un statut permet le traitement ligne par ligne — c'est exactement ce que fait `skipped` dans les paquets multi-lignes. On ne casse pas ce contrat pour vingt-six appels distraits ; on impose de le lire.

**Et le correctif n'a coûté aucune chaîne i18n.** `src/lib/rpcStatus.js` expose `assertRpcOk(data)`, qui lève un `Error` portant le `reason` en message. On entre alors dans le chemin d'erreur **déjà en place** : le `try/catch` de l'appelante, `localizeError`, le toast. `localizeError` n'ayant aucune liste blanche, le code est traduit via `panel.apiError.<reason>` s'il existe et retombe sinon sur la clé contextuelle de l'action. Ce qui avait déjà une clé s'affiche mieux qu'avant ; rien de neuf à traduire dans dix locales.

**23 gardes posées. 4 sites laissés, et nommés** : deux demandent de restructurer un `let error` partagé entre branches, deux sont des appels sans aucune destructuration — les reprendre, c'est décider quoi faire d'un échec, pas seulement lire un `ok`. Les forcer aurait été la correction mécanique qui casse en silence.

**Ce qui remplace un item de suivi** : `src/tests/rpc-statut-ok-lu.test.js` échoue si un appel à une RPC à statut ignore le résultat. La dette est une liste explicite, chaque entrée avec sa raison, et un **second test refuse une entrée devenue sans objet** — la liste ne peut donc que rétrécir. C'est le test qui porte la dette, pas un item qui dormirait.

CI verte : lint et suite unitaire. |
| K4 | Corriger le générateur des pages de vie privée sur la langue déclarée | **Clos le 31/08 au soir, corrigé dans la foulée de la campagne de revérification.** Le générateur émettait `lang="pt"` là où tout le texte est en portugais du Brésil ; les pages écrites à la main portaient `pt-BR` et avaient raison. Le modèle du correctif dormait à la ligne d'à côté : `build-finances-pages.cjs` faisait la conversion depuis toujours (`HTML_LANG`). Carte posée dans le générateur de vie privée, dix pages régénérées — seule `pt/privacidade` change de langue, et la régénération a resynchronisé au passage l'en-tête des dix pages avec leur chrome, qui avait dérivé (« Appli », « Aplicativo »). **Vérifié en ligne après publication** : `anarbib.org/pt/privacidade` sert `lang="pt-BR"`. Commit `2fb4796` du dépôt vitrine. |
| H3 | Publier les correspondances vers le thésaurus FICEDL en SKOS | **Clos le 31/08 au soir — et le constat était faux à moitié.** Les correspondances FICEDL étaient déjà exposées en SKOS : `skosExport.js` émettait `skos:exactMatch`/`closeMatch` depuis le 30/06, alimenté par `api.thesaurus_export_v1`. Ce qui manquait n'était pas l'export, c'était **l'adresse** — le fichier n'existait qu'en bouton de téléchargement, introuvable pour une machine. Livré : `scripts/build-thesaurus-skos.mjs` sur le patron de l'instantané du catalogue (prebuild, RPC `anon`, même sérialiseur que le bouton — aucune divergence possible, échec silencieux qui ne casse pas le build). **Vérifié en ligne après déploiement** : `app.anarbib.org/thesaurus.ttl` répond 200 en `text/turtle` (et `.jsonld` aussi), 51 alignements, `exactMatch` distinct de `closeMatch`, rien d'affirmé sur la hiérarchie FICEDL (le vocabulaire ne connaît qu'`exact` et `close`, et c'est voulu tant que H2 attend). Les 47 liens restants portent sur les 35 sujets SOLIDAIRES encore `proposto` : ils entreront dans le fichier à leur promotion, sans un geste. Commit `472db13b`. |
| F2 | Corriger le gabarit des courriels d'alerte d'exploitation | **Clos le 31/08 au soir, livré et éprouvé en conditions réelles dans la même soirée.** Les alertes d'exploitation partaient avec le pied de page lectrice — « En cas de question, contacte la bibliothèque » suivi du téléphone : on disait à l'opérateur·rice de se téléphoner à soi-même. Livré : `footerOps` dans `layout.ts` (d'où vient l'alerte, où regarder, et OPS-8 — rien à acquitter, l'incident se clôt seul), trois clés dans les dix locales, branché dans `alerter()` de `health-probe`, l'entonnoir unique des huit envois. **Le piège attrapé en chemin** : la version texte de `renderEmail` fabriquait son propre pied (téléphone compris) sans regarder `footerHtml` — couverte par `footerTextLines`, gardée dans les deux sens par `mail-footer-ops.test.js`. **Éprouvé sur une alerte réelle** : incident d'essai `#9` ouvert à la main à 18 h 40 UTC (raison traçant l'essai dans la ligne même), refermé par la sonde elle-même à 18 h 45 — quatre minutes, zéro acquittement, exactement ce que le pied de page promet — et les deux courriels **reçus et relus par Xavier**, qui n'a pas écrit le code. Commits `4b1d8a86` et `12d4b760`. |
| B2 | Trier les 36 fonctions `SECURITY DEFINER` ouvertes à `anon` | **Clos le 01/09, les quatre lots exécutés et le compte tenu.** Lot 1 (30/08) : les trois grants que la fonction contredisait, retirés. Lot 2 : les cinq intouchables — 107 policies, dont 39 évaluées par `anon` — commentées et gardées par T8/T9. Lot 4 : les 33 relues une à une contre la question du 18/05 (`AUDIT_execute_anon_2026-08-30.md`) — 5 intouchables, 23 légitimes, 5 à traiter ; C.1–C.4 fermées le soir même (`20260830191108`, dont l'oracle de délibération et l'énumération du réseau par les fuseaux), C.5 tranchée le 01/09 par les faits : l'unique appelant est le choix de bibliothèque cible du catalogage, admin réseau **par décision du 17/08** — garde voulue, nom documenté par `COMMENT`, grant mort retiré (`20260831195348`). Lot 3 (31/08) : le défaut du schéma retourné (`20260831105114`) — une fonction créée dans `public` naît fermée à `anon` ; doctrine au REGISTRE (`DOC-GRANT-1`), pièges nommés (l'entrée `pg_default_acl` qui ne doit jamais se vider ; l'entrée `FOR ROLE supabase_admin` qui reste et revient à B14). **L'invariant est gardé** : la liste nommée du T10 compte 28 fonctions, dans les deux sens, et **le lint 0028 affiche exactement 28** — remesuré après déploiement. Un avertissement attendu n'est plus un avertissement. Le tri des 464 d'`authenticated` est B14. |
| B5 | Résorber les neuf policies qui réévaluent `auth.*()` par ligne | **Clos le 01/09/2026, sur mesure et non sur intention.** L'item demandait de résorber les neuf policies qui réévaluaient `auth.*()` **par ligne** au lieu d'une fois par requête. Le wrap idempotent du 03/07 existait déjà : il avait été écrit, puis la dérive était revenue par l'exemple nu du `_TEMPLATE.sql`, que les neuf avaient recopié. Le rejeu du 31/08 (`20260831171526`) referme les neuf **et** corrige la source — sans quoi la dixième serait née du même modèle. <br><br>**Ce qui autorise la clôture est un chiffre, pas un commit** : l'advisor de performance comptait 9 `auth_rls_initplan` le 29/08 ; il en compte **0** le 01/09, remesuré deux fois dans la journée, avant et après les paquets de `B14`. C'est la seule preuve qui vaut ici — une migration appliquée ne dit pas que le défaut a disparu, elle dit qu'on a agi. |
| B14 | Auditer les fonctions `SECURITY DEFINER` ouvertes à `authenticated` | **Clos le 01/09/2026, en onze paquets et une journée, par la clôture à deux chemins de `DOC-RECENS-1`** : dix critères thématiques (`api` 138/138, `public` 315/315), le complément des critères **vide** après lecture des 24 fonctions qu'il rendait, et les schémas hors hypothèse balayés — `private` (6 lues, et le dernier constat du lot y vivait : la carte réseau montrait 79 entrées non publiques, dont de possibles attentes de consentement, à tout compte authentifié) et `ingest` (0 exposée). **459 fonctions lues en tout.** Fuites corrigées, toutes dormantes : deux sur `api`, le foyer derrière la façade, la volumétrie des fonds (`fn_next_tombo`), une écriture sans garde, la vue `my_access` (37 fonctions ouvraient le panneau de la mauvaise bibliothèque), 23 oracles d'existence, 5 fonctions mortes dont une joignant identité et rôle militant, la carte réseau. **Trois décisions collectives** posées et tranchées le jour même (refus muets, arbitrage des périodiques — après préavis aux quatre personnes —, carte réseau aux membres). **Neuf suites de garde** nées du lot, toutes en CI : le lot n'a pas corrigé, il a rendu chaque invariant regardable. Coût assumé : quatre CI rouges, tous la même faute sous trois formes — changer ce qu'une fonction dit, rend ou a le droit de faire sans chercher qui l'observe — d'où les trois volets de `DOC-MSG-1` et deux corollaires de `DOC-RECENS-1`. L'advisor 0029 passe de 464 à 453, **et ce chiffre n'est plus un avertissement : chacune des 453 restantes a été lue, et sa raison d'être exposée est écrite.** La chronique complète, paquet par paquet, vit dans `AUDIT_execute_authenticated_2026-09-01.md`. |
| H4 | Exposer le catalogue en OPDS | **Clos le 01/09/2026, onze jours avant Bologne, sur épreuve réelle.** Le flux OPDS 1.2 est vivant : `/functions/v1/opds` (navigation) et `/opds/all` (acquisition) — les **18 documents numériques publics** du catalogue, lisibles par toute application de lecture sans passer par notre interface. La convention n°1 du texte d'interopérabilité (« les flux OPDS existent de part et d'autre mais ne pointent nulle part ») est **tenue avant d'être proposée**. Prouvé au `curl` : Atom conforme, 18 entrées aux titres tous distincts (les six tomes de Reclus se départagent par volume et sous-titre), langues normalisées (7 fr, 7 pt-BR, 2 es, 2 it — `language_code` avait dérivé, `idioma` fait foi), droits et attribution Gallica/BnF portés, couvertures liées, lien retour vers `/livro/<bib_ref>`, et un PDF réellement servi (10,4 Mo, apostrophes et espaces des chemins URL-encodés). Autodécouverte posée dans `index.html`. **Le périmètre est strict et gardé** : uniquement `access_scope='publico'` actif — le prédicat même de `documents_numeriques_tests` ; le flux ne crée aucun accès, il rend trouvable ce qui est déjà public. **Deux constats au passage** : `book_digital_resources` ne porte **aucune clé étrangère** — pas même vers `books` — d'où une jointure en deux requêtes dans la fonction (l'embed PostgREST exige une FK) ; à poser un jour, pas à la veille de Bologne. Et le premier déploiement a répondu 500 sur `/all` : *l'épreuve au `curl` fait partie de la livraison*, pas de la vérification d'après. |
| G3 | Éprouver le circuit de promotion collégiale sur `blmf-teste` | **Clos le 01/09/2026 au soir : le circuit a été emprunté pas à pas sur `blmf-teste`, et il a validé du même coup la fonctionnalité livrée quelques heures plus tôt.** Sept pas, le négatif d'abord : (0) le saut collégial reader → coordenador est **refusé** tant que `allow_direct_coordenador` est éteint — message historique conservé ; (1) opt-in allumé sur la seule bibliothèque d'essai ; (2) proposition de Voltairine (reader) à la coordination par un coordenador — et le mécanisme se révèle : **la signature du proposant compte comme première des deux** (« cosignature » au sens littéral) ; (3) Voltairine ne peut pas ratifier sa propre promotion (refus) ; (4) deuxième signature → `ready` ; (5) acceptation par l'intéressée, sous son propre JWT, avec revérification de l'opt-in ; (6) état final conforme : `coordenador:active`, la ligne `reader` **fermée** (rôle exclusif), audit `promoted_to_coordenador [from reader]` + `removal_completed` — le `from_role` que GOUV-11/12 promettait. Les trois événements d'outbox (`invitation_proposed`, `invitation_ready`, `promoted_to_coordenador`) sont partis vers la fonction d'envoi. **Une réserve, dite** : le non-envoi effectif (mails `disabled` sur la biblio d'essai) n'a pas pu être observé le soir même — l'API des journaux Edge répondait en erreur — mais la boîte destinataire est une boîte de test réelle consultable en un coup d'œil, et l'épreuve du **contenu** des courriels d'équipe est précisément l'objet de `G4`, qui reste ouvert. Le réglage `team_admission_mode='cosignature'` de la BLMF, jamais exercé jusqu'ici, a maintenant un circuit prouvé de bout en bout ; l'invitation réelle de la BTL (`ebd78fb9`) est en `ready` et n'attend plus que le geste de la personne concernée. L'opt-in reste allumé sur `blmf-teste` seulement — c'est le bac à sable, et `G4` s'en servira. |
| G4 | Exercer les quatre courriels d'équipe jamais envoyés | **Clos le 01/09/2026 au soir, sur envoi réel ET lecture par la coordination (« rien à redire »).** Les quatre courriels les plus délicats du système — jamais partis en production — sont partis et ont été lus, plus deux bonus jamais servis non plus (`removal_cancelled`, `unsuspended`) : cinq en pt-BR chez la persona visée, la diffusion `self_demoted` en français chez l'autre coordination, les copies admin en locale de la bibliothèque sur un alias contrôlé. **Le protocole de confinement a tenu deux fois** : quatre des six membres de la coordination d'essai sont de vraies personnes — salle vidée par rétrogradation directe silencieuse avant chaque diffusion, tout restauré à l'identique après. **Le premier tir a fait mouche en échouant** : aucun courriel reçu, parce que le canal porte DEUX interrupteurs sur la même ligne (`delivery_mode` et `active`) et qu'un seul avait été tourné — même famille que le faux interrupteur du 30/08 : *deux interrupteurs pour un seul geste finissent toujours par n'être tournés qu'à moitié*. Le diagnostic a pris trois requêtes parce que chaque saut portait sa raison (`skipped: delivery_disabled`) dans la réponse : **la doctrine B12 prouvée en situation réelle**. Au rejeu, les deux voyants vérifiés dans la vue que la fonction lit (`v_library_notification_context`) AVANT de tirer. **L'angle mort des dix langues est fermé dans la foulée** : les gabarits vivent dans `mail-strings.ts`, hors du périmètre de la garde de parité du front — mesuré 648 clés toutes complètes sur les dix locales, et gardé désormais par `src/tests/mail-strings-parity.test.js` (dont la première exécution a attrapé un faux positif exemplaire : l'en-tête du fichier qui énonce « JAMAIS camerata »). Nuance consignée au passage : `self_demote` passe le rôle quitté en `inactive` là où la promotion l'avait `removed`. |
| F8 | Le domaine d'envoi, relevé : en règle pour envoyer, ses rapports partent chez Brevo | **Clos le 01/09/2026, sur deux relevés DNS encadrant les gestes — neuf jours avant l'échéance du 10/09.** Le relevé du matin (jamais fait auparavant) a confirmé l'item mot pour mot : **en règle pour envoyer** — SPF porté par le sous-domaine Resend (`send.notifications` : `v=spf1 include:amazonses.com` + MX feedback SES), DKIM présent (sélecteur `resend`) — mais DMARC en `p=none` avec `rua` chez **Brevo**, le prestataire quitté, sur le sous-domaine ET la racine : les rapports d'authentification partaient chez quelqu'un d'autre, et un canal de rapports qui pointe chez un prestataire quitté est un dispositif de surveillance qui se tait (`DOC-SILENCE-1`). Plus deux TXT `brevo-code` résiduels, jetons de vérification qui disaient publiquement « ce domaine a été chez Brevo ». **Les gestes, faits par la coordination chez OVH le jour même, vérifiés au relevé du soir via un résolveur externe** : les deux `_dmarc` pointent vers `admins@anarbib.org` (déjà destinataire des alertes santé), les deux `brevo-code` ont disparu, et rien d'autre n'a bougé — le SPF OVH de la racine (les boîtes `admins@` en dépendent) et toute la zone Resend sont intacts. **La politique DMARC est décidée, pas différée** : `p=none` maintenu le temps de lire les premiers rapports — qui arrivent désormais chez nous, quotidiennement, en petits XML zippés — et le durcissement (`quarantine`) se tranchera sur leur contenu, dans quelques semaines. Le critère est écrit ; il n'y a plus de décision en suspens, seulement un rendez-vous. |
| C1 | Faire entrer les 35 sujets SOLIDAIRES dans les migrations | **Clos le 01/09/2026, par décision écrite plutôt que par migration** — c'était l'une des deux issues que l'item prévoyait, et la doctrine FICEDL du 26/08 la commandait : *le vocabulaire fédéral embarque, les sujets locaux et leurs alignements n'embarquent pas*. État mesuré le jour de la décision : **35 sujets** `solidaires-*` en base, tous `proposto`, **47 alignements** FICEDL (sur 98). Le brouillon le disait lui-même — « les libellés sont ceux du collectif, non retraduits » : un vocabulaire *situé*, que traduire ou normaliser pour l'embarquer trahirait. Une installation neuve naît avec le thésaurus ; chaque bibliothèque apporte ses mots, et les alignements font le pont. Le brouillon SQL est rangé en archive (`docs/drafts/archive/`), la décision est datée (`DECISION_sujets_solidaires_2026-09-01.md`) avec sa clause de révision : si d'autres bibliothèques adoptent un jour ces rubriques telles quelles, c'est le critère « fédéral » qui commande, pas le préfixe — et la migration se réécrira depuis la base, pas depuis le brouillon. |
| D1 | Réviser la spec des périodiques contre ce qui a été livré | **Clos le 01/09/2026 — et le premier constat est que la spec à réviser n'existe pas.** `spec-periodiques-v0.1`, citée par cet item avec ses numéros de section (§11, §14), est **introuvable** — ni au dépôt, ni dans les archives de travail : elle avait vécu dans Downloads, collée en session le 27/08 (« On met ça en œuvre »), puis le fichier a été supprimé — **retrouvée le soir même, intégrale (391 lignes), dans le transcript de cette session**, et archivée : `docs/specs/archive-spec-periodiques-v0.1-retrouvee.md`. Les §11 et §14 cités existent bien, les six gardes sont au §9. *La précision d'une citation n'est pas une preuve d'existence* (`DOC-RECENS-1`). Plutôt que de réviser un fantôme, l'état livré est écrit depuis le code : `docs/specs/spec-periodiques-v1.0-etat-livre.md` — une spec *a posteriori* qui l'assume, où le code fait foi et le document le suit. **Les six gardes annoncées sont vérifiées une à une** : l'anti-cycle borné à 20 sauts relu à la ligne (`WHILE v_hops < 20`, trigger `serials_filiation_no_cycle`), la réciprocité par trigger (`serials_filiation_symmetry`), l'interdiction du `serial_id` hors fascicule (`books_serial_id_requires_periodico`), la clé `issue_key` **générée** qu'aucun chemin d'import ne référence, l'état déclaré/calculé en colonnes séparées, l'index de tri. Et surtout : **les six sont exercées en continu** par `periodiques_tests.sql` (35/35 en CI, verte encore ce soir) — la preuve n'est pas le document, c'est la suite, à chaque commit. Le document nouveau porte aussi le changement du jour (arbitrage aligné sur les livres) et les trois gestes manuels restants, qui ne sont pas des défauts. |
| H7 | Décider du sort du texte de conventions d'interopérabilité | **Clos le 01/09/2026, au terme d'une soirée de traque : décidé, perdu, retrouvé, préparé.** La coordination a tranché « porter à Bologne » — et le texte s'est révélé introuvable : jamais dans git, jamais en pièce jointe de session (inventaire intégral, Windows et WSL), jamais écrit par un outil. L'enquête a établi qu'il n'était jamais passé par les machines : écrit dans une **conversation claude.ai du 26/08**, comme le v34 lui-même (l'export PDF du 29/08 à 20:08 dans le dossier E: en est la signature). **Retrouvé le soir même par la coordination dans cette conversation**, exporté, et versé au dépôt en deux exemplaires aux rôles clairs : l'original intact, notes de travail comprises (`docs/journal/cadrages/CONVENTIONS_interop_catalogues_libertaires_brouillon-original_2026-08-26.md`) ; et la **version à porter** (`docs/CONVENTIONS_interoperabilite_catalogues_libertaires.md`), dont les deux seuls retraits sont ceux que le texte s'ordonnait lui-même — la section « Notes de travail *(à retirer avant diffusion)* » et la note crochetée sur l'audit à joindre. Le chapeau « ce texte n'engage personne » reste : c'est sa politique, pas une note. **Et il arrive à Bologne avec ses preuves** : la convention n°1 (OPDS) est tenue par AnarBib depuis le matin même, la n°2 (SKOS) depuis H3 — le texte ne propose plus, il montre. Même leçon que la spec des périodiques, deux fois le même soir : *ce qui sert de référence à un item doit être versé quelque part de durable, le jour où il sert.* |
| F8 (rappel avant péremption) | Le rappel avant péremption : une proposition d'équipe ne peut plus mourir en silence | **Clos le 02/09/2026, livré dans la nuit du 01 au 02.** L'item disait que la cloche annonçait l'existence d'une proposition sans jamais dire qu'elle allait expirer, et que `fn_team_expire_invitations` refermait à 30 jours sans un mot — un silence tenant lieu de refus, alors que **toute** nomination au staff passe par ce circuit depuis `GOUV-11` et `GOUV-13`.

**L'arbitrage a écarté la transposition mécanique du précédent réseau.** `RES-Q3` place ses rappels à J+14 et J+25 d'une fenêtre de 60 jours, soit dans sa **première moitié** : des échéances faites pour entretenir l'élan d'un vote à l'unanimité. Transposées proportionnellement à 30 jours (J+7 et J+12), elles auraient laissé **dix-huit jours de silence avant l'expiration** — le trou même qu'il fallait boucher. Retenu à la place : **un rappel à J+21**, neuf jours restants, et **un avis à l'expiration**. Ce dernier vaut mieux qu'un second rappel : répéter ne fait que répéter, tandis que l'avis transforme une disparition silencieuse en fait consigné. Son texte dit ce que le silence signifiait — « ce n'est pas un refus : personne n'a tranché ; elle peut être reproposée ».

**Qui a proposé est prévenu dans les deux cas.** L'objection était qu'iel ne peut rien débloquer seul·e, donc culpabilité sans pouvoir. C'est l'inverse : ça lui rend le seul pouvoir qui vaille ici, aller parler aux gens (`DOC-COLLECTIVE-1`, `RES-D9`).

**Mesures datées.** Migration `20260901213921`, horodatée à la seconde UTC réelle (`DOC-DEPLOY-4`). **Aucune colonne ajoutée** : le cron passant une fois par jour, le rappel se déclenche sur l'égalité de date `created_at + 21 jours` = aujourd'hui — une fois, une seule, sans marqueur « déjà relancé » qui pourrait dériver. Cron `anarbib-team-invitations-remind` à **09 h 35 UTC**, relevé actif dans `cron.job` après déploiement. `fn_team_expire_invitations` passe d'un `UPDATE` global à une boucle — il faut savoir **qui** prévenir. Les deux canaux : in-app (`user_notifications`, la voie qu'on maîtrise, tout l'objet de `GOUV-17`) et courriel.

**Ce qui a été vérifié, et ce qui ne l'est pas encore.** 64 suites SQL vertes avant le push — dont `crons_planifies_tests.sql`, qui a **refusé la migration** tant que le nouveau cron n'y était pas déclaré : le garde-fou a fait son travail. Après déploiement, `fn_team_invitation_remind()` a été **réellement exécutée** contre le schéma de production : retour `0`, aucune notification écrite — aucune invitation n'atteignait J+21 ce jour-là. Cela établit que le chemin s'exécute, pas encore qu'il relance. **La première exécution réelle est datée** : le 20/09/2026 pour l'invitation BTL en attente depuis le 30/08, puis le 22/09 pour celle de `blmf-teste`. C'est à ces dates que l'item sera éprouvé, et non avant.

**Reste ouvert, hors périmètre de cet item** : rien. Le rappel avant péremption était le seul point laissé en suspens par `GOUV-17`, et `GOUV-17b` peut passer d'ouvert à acté. **Contre-vérification indépendante (seconde session, nuit du 01 au 02/09) — le code tient sur les deux chemins.** Structurel : migration `20260901213921` appliquée en production, cron `anarbib-team-invitations-remind` posé à 09h35 (l'expiration restant à 03h20), `EXECUTE` des deux fonctions réservé à `service_role`, les 4 clés i18n présentes dans les dix locales, les 49 lignes neuves de `mail-strings` validées par la garde de parité née la veille, la cloche routant les deux `link_type`. Comportemental, en transaction annulée sur `blmf-teste` avec fixtures synthétiques à J-21 et J+31 : le rappel touche **exactement** les 5 staff hors invité (l'invité 0), le proposant **une seule fois** — la garde anti-doublon mord alors qu'il est aussi dans la diffusion —, 1 ligne d'outbox e-mail ; l'expiration ferme (`expired`) et avise les **deux** bonnes personnes. Le déclenchement par égalité de date ne laisse aucun marqueur à désynchroniser. **Sur la fixture `f8504c47`, l'objection de la session livreuse l'emporte sur ma consigne de l'annuler**, mesures à l'appui : seule invitation vivante de la persona (la contrainte d'unicité ne bloque rien d'autre) et rappel du 22/09 tombant après la formation — conservée, elle devient la **seconde épreuve réelle datée**, après celle du 20/09 sur la BTL. Deux verdicts indépendants, une réserve commune et écrite : la fonction n'a encore rien relancé en réel, et c'est aux deux dates ci-dessus que l'item se prouvera. |
| B20 | 2026-09-02 | **La surface morte mesurée par le GLB v17 est entièrement traitée — 2 branchées, 65 fermées, 1 rejugée ailleurs — en une journée, chaque geste éprouvé en CI et contre-vérifié en production.** Les 17 fonctions `api` sans appelant : la **messagerie de candidature branchée** (RedePage reçoit la section échanges que la spec onboarding v2.0 §4.5/§5.7 promettait — fil, réponse avec bascule `aguardando_info`, proposition d'échange, clôture ; 5 clés × 10 locales) ; le **retrait de fiche cartographique branché** (seul chemin de suppression, 105 entrées publiques sur des collectifs tiers ne doivent pas dépendre d'un SQL à la main) ; les 15 autres fermées par quatre migrations racontées (redondance des deux côtés, générations supplantées, instruments de console rendus à la console, chaîne d'agendamento jamais servie fermée entière avec ses 3 implémentations `fn_v2`). L'échéance des 48 différées de `public` : **soldée avec un mois d'avance** — 47 fermées sur remesure, `fn_book_due_dates` sortie du solde (verdict B2/T10, sa contradiction se rejuge là-bas). Le lint 0029 passe de 442 à 395, chaque exposition restante ayant sa raison écrite.

**Ce que la journée a coûté et appris** : trois rouges CI, tous du même motif (un test qui énumère garde ce qui n'est vrai que d'un), et trois leçons versées dans les fichiers — une convention d'appel se lit test par test, jamais par le voisin ; une assertion de droits a trois formes (`has_function_privilege`, `routine_privileges`, `proacl`) et le balayage doit croiser les noms avec chacune ; un REVOKE se prépare en lisant `proacl`, pas en devinant le grant. Cinq suites nées de l'item gardent l'état final en CI.

**Rattrapage du soir même, et la leçon qui manquait à la méthode.** Trois des fonctions fermées par les campagnes du 01-02/09 — `fn_circle_member_count`, `api.get_remaining_renewals` (fermées ici) et `fn_assembleia_facilitator_name` (fermée par le paquet 7 de B14) — sont appelées par des **vues `api` en `security_invoker`**, que le front lit à la place des fonctions ; une telle vue exécute ses fonctions sous le rôle de la personne qui la lit, donc l'EXECUTE lui est nécessaire, et PostgREST rend 403 sinon. Constat de Xavier en préparant les captures du Manuel v5 : l'onglet Cercles de la BLMF affichait « aucun cercle » pour une bibliothèque membre de trois. Les deux mesures (« 0 appelant SQL/policy/cron », « 0 occurrence dans src/ ») étaient vraies et la conclusion fausse : **`pg_depend` le savait (`classid = pg_rewrite`), `prosrc` et le grep ne pouvaient pas le voir.** Rouvertes à `authenticated` par la migration `20260902175631` (session voisine, quelques heures de casse sur trois écrans : Cercles, Assembleias, échéances de renouvellement), suites de fermeture réalignées. Balayage rétroactif des 62 fermetures du jour contre `pg_views` : aucune autre. **Dette soldée le soir même** (arbitrage Xavier, solution 2, migration `20260902183505`) : `fn_assembleia_facilitator_name` reçoit aussi l'assemblée et ne rend le nom qu'à qui la voit — la même porte que `assembleias_select` — et seulement pour cette assemblée ; la forme (uuid), l'annuaire par ricochet, n'existe plus ; la vue est recréée en `security_invoker`. Suite `FACILITATEUR_NOM_SCOPE` : membre rattachée → nom, mauvaise assemblée → rien, intruse sans appartenance → rien, sans session → rien. La checklist pré-REVOKE gagne son point zéro : *une vue appelle aussi*. **Reste ouvert, hors périmètre** : l'épreuve réelle de la messagerie attend la première candidature vivante — SOLIDAIRES, exactement le cas (`DOC-ACTIF-1` : branché n'est pas éprouvé) ; et la contradiction `fn_book_due_dates` au registre de B2. |
| J7 | 2026-09-02 | **Les lignes rouges des Livres blancs ont désormais leurs codes — REGISTRE v0.14.** Trois inscriptions : **`DOC-GEL-1`** (le gel de périmètre v16, avec sa fenêtre d'arbitrage : ouvrir un domaine exige une décision datée dans `docs/journal/arbitrages/` qui pèse le coût contre la fenêtre et nomme qui arbitre — une spec ou un item **tracent**, ils n'**arbitrent** pas) ; **`DOC-ACTIF-1`** (aucune couche livrée à l'actif avant un exercice réel — la pratique des clôtures sur épreuve devient opposable, et donne son sens à G1) ; **`DOC-GLB-1`** (la règle méta : toute ligne rouge d'un Livre blanc reçoit son code sous une semaine, sans quoi elle est un vœu — preuve expérimentale à l'appui : sept ouvertures en huit semaines sur une ligne jamais inscrite). Vérifiable d'un grep : « gel de périmètre » a maintenant un foyer normatif. |
| J8 | 2026-09-02 | **Un seul « v17 », et c'est le bon — la série du Grand Livre blanc est versée au dépôt** (arbitrage du 02/09 : « verser ce qui sert de référence, le jour où ça sert » — la leçon des documents fantômes du 01/09 appliquée à celui qui les avait diagnostiqués). Le docx du 29 mai est archivé sous un nom qui porte sa date sans revendiquer de numéro (`GLB/archive/AnarBib_Grand_Livre_blanc_refonte_2026-05-29.docx`) ; le **v17 du 01/09 entre dans `docs/GLB/`** comme référence vivante ; l'INDEX ne désigne plus un état de mai — il raconte l'anomalie résorbée et nomme le chaînon manquant. Détail piquant : le PDF avait déjà quitté `Downloads` au moment du geste — **reconstitué à l'octet près (762 814) depuis le transcript de la session qui l'avait lu**, la recette des pièces avalées servant cette fois pour du binaire.

**Reste ouvert, hors périmètre** : le **v16 du 2 juillet** — la troisième lecture exacte, base du v17 — n'a jamais été versé et reste à retrouver ; le jour où il refait surface, il entre dans `GLB/archive/` sans autre décision (c'est écrit dans l'INDEX). |
| B21 | 2026-09-02 | **Le compteur des clés étrangères sans index a son garde, et il a mordu dès son premier tour de CI** (run vert du 02/09 sur `dfc96a8b`). `tests/sql/fk_sans_index_garde_tests.sql` : 38 entrées assumées en trois familles motivées d'une ligne (15 vers les tables de codes `catalog_ref_*` — les résiduelles voulues du solde du 02/07, intactes —, 17 colonnes d'acteur de la qualité catalographique, 6 transit d'import `ingest`), l'en-tête portant la requête qui produit le relevé ET son angle mort (`DOC-RECENS-1` : index d'expression et partiels non vus, même méthode que l'advisor, accord à l'unité au 02/09). Gardé dans les deux sens : T1 — toute FK neuve sans index rougit la CI au moment où la migration s'écrit, son issue est un index ou une entrée motivée par un commit ; T2 — une entrée indexée ou disparue rougit aussi, la liste ne rétrécit que consciemment. Et T3 prouve la morsure à chaque run en créant une FK notoirement nue dans la transaction du test (fixture en tables temporaires — le hook pre-commit exige à raison RLS+GRANT de toute table qui naît dans `public`, même éphémère). La doctrine v17 est servie : le chantier n'est pas « soldé », il est **instrumenté** — la campagne d'indexation reste où elle est (B10, différée avec sa raison), et le compteur ne remontera plus en silence. |
| F7 | 2026-09-02 | **Treize secrets vides, treize verdicts — et il n'en reste que deux, qui le sont exprès et le disent.** Le relevé rejoué le 02/09 donnait les mêmes treize empreintes de chaîne vide qu'au 30/08. Tri en trois classes, chaque lecteur relu : **11 supprimés** (`supabase secrets unset`) — dix doublons de tête de chaîne de repli dont la variante `ANARBIB_*` renseignée gagnait déjà, plus `REGIMENTO_URL` sur décision : aucun règlement réseau n'est publié, la branche morte qui l'attendait est **retirée du code** (trois endroits — dont une chaîne mal nommée dans `notify-document-permission-request` qui cherchait l'URL du *manuel* en essayant d'abord celle du *règlement* : inoffensive vide, fausse le jour où on l'aurait remplie ; le jour où un regimento existera, le rétablir sera un geste conscient). **2 conservés et documentés** : `BLMF_/BTL_INTERNAL_REDIRECT_EMAIL`, dont le vide EST le réglage (la redirection des avis internes est inactive, vérifié le 30/08 sur l'inscription BTL) — commentaire posé dans `register/index.ts`, là où on les lit, pour que personne ne les « répare ». Un `secrets list` dit désormais la vérité : deux empreintes vides, toutes deux voulues. |
| B18 | 2026-09-02 | **Les clés API legacy sont désactivées — et le feu vert fut un chiffre, comme la fiche l'exigeait.** La jauge refaite le matin même (sur le marqueur JWT, après que le critère « préfixe vide » se soit révélé compter les requêtes SANS clé comme legacy) donnait : zéro `service_role` depuis la bascule du 01/09, et côté `anon` **un seul user-agent navigateur** — un onglet Chrome/Windows connecté, jamais rechargé depuis la bascule — plus Googlebot rejouant son cache d'ancien bundle. L'onglet rechargé, le toggle basculé au dashboard (geste réversible), et la contre-preuve lue dans les logs : **zéro JWT legacy et zéro 401 sur 857 requêtes vivantes** — l'application entière sur la clé publiable et `sb_secret`. Le code a suivi dans l'heure : le repli `SUPABASE_SERVICE_ROLE_KEY` retiré de `secret-key.ts` (une clé morte ne mérite pas de chemin de code, et un repli vers elle masquerait une panne de `SUPABASE_SECRET_KEYS` au lieu de la dire — DOC-SILENCE-1), `.env.example` nettoyé, et le vestige vault `anarbib_staging_anon_key` supprimé (migration `20260902163600`, zéro appelant vérifié). La bascule `service_role` → `sb_secret` entamée le 01/09 est close de bout en bout. |
| G2 | 2026-09-02 | **L'écart P2/P8 est tranché — le texte s'aligne sur le code, et la forme de la décision est aussi importante que son fond.** Option 1 des trois écrites : la pratique vivante (le circuit collégial que la BTL exerce depuis le 01/09) devient la règle. Spec v1.11 : P2 dit que **l'exécution elle-même est collégiale** ; P8 clarifie la frontière sans rien céder — les quorums du code ne sont pas des votes mais des **garanties d'exécution** (une ratification atteste qu'une décision collective existe hors logiciel, elle ne la remplace pas) : « modéliser la délibération, jamais ; exiger plusieurs mains pour exécuter, toujours ». Aucune ligne de code. **Décision prise seule, en le disant** — mode dégradé assumé (aucun collectif ne s'est encore saisi de l'outil), daté à `DECISION_G2_alignement_textes_promotion_2026-09-02.md`, `GOUV-18` au REGISTRE (v0.15), **fenêtre d'objection à la soirée 1 de la formation, le 08/09/2026** : le jour où le collectif existe, il trouve une décision contestable, pas un état de fait muet. Au passage, le fil-piège de `GOUV-17b` est réparé (livré ce matin, la ligne du registre avait un jour de retard). |
| H5 | 2026-09-02 | **La moisson OAI-PMH est éprouvée dans les deux sens, avec de vraies données des deux côtés — et deux circuits civiques exercés pour la première fois le même soir.** **Sens entrant** : première source réelle enregistrée (Persée, fascicules de sociologie, volume borné à 2 lots/cycle — répétition en transaction annulée puis geste réel, garde admin réseau sous l'identité de Xavier) ; le déclencheur du cron lancé à la main a ramené **40 fascicules réels** (les *Actes de la recherche en sciences sociales* de 1975 en tête de file) : run `ready_for_review`, verrou reposé sur `paused`, **jeton de reprise conservé** — le cron de mardi 04h20 continuera là où l'épreuve s'est arrêtée. **Sens sortant** : l'entrepôt répondait conformément mais vide — « aucune bibliothèque ouverte » — car le circuit « être source » n'avait jamais servi ; **la BLMF s'est ouverte par le circuit réel** (demande → décision, notification comprise — décision de Xavier, mode dégradé assumé comme G2), et un client tiers a moissonné **200 notices en deux lots**, reprise par `resumptionToken` honorée, `GetRecord` exact *(nuancé le 07/09 : l'essai portait sur la première notice — la fonction ignore l'identifiant demandé, voir **H8**)*, `Identify`/`ListMetadataFormats`/`ListSets` conformes. **Deux constats en chemin, pour Bologne** : *(1)* les deux partenaires PMB connus (CIRA Lausanne, CSL Milano) n'exposent pas `oai2.php` — le diagnostic des conventions (« les flux ne pointent nulle part ») est en-deçà de la réalité : côté PMB ils n'existent pas, et c'est un sujet pour H6/K6 ; *(2)* `blmf-teste` échoue l'éligibilité sur ses trois verrous de profil — sa recette de bibliothèque masquée tient, y compris face à l'OAI. **Rien ne survit à l'épreuve, sur décision de Xavier le soir même** : les 40 notices Persée n'appartenaient à aucune bibliothèque réelle (run rattaché au bac à sable, donc invisible depuis un contexte de biblio ordinaire — c'est ce qui les rendait introuvables à l'écran) ; run, lignes et source sont purgés par le chemin propre (`fn_import_delete_run`, puis retrait de la source et de son état) — **zéro source OAI reste armée, le cron de mardi ne moissonnera rien**. L'ouverture de la BLMF est refermée de la main de Xavier. L'épreuve, elle, est acquise : ce qui a été prouvé n'a pas besoin des données qui l'ont prouvé. **Reste ouvert, hors périmètre** : un moissonneur vraiment tiers — une autre machine, un autre collectif — que Bologne peut fournir. |
| B17 | 2026-09-02 | **L'avertissement immédiat des actions transverses est éprouvé de bout en bout — y compris, ce soir, sur le type pour lequel il a été écrit.** L'étage immédiat livré et éprouvé en envoi réel le 31/08 (ligne #72 rejouée : 200, 3 destinataires, courriel reçu et relu) ne l'avait été que sur la promotion collégiale — un type à trois canaux, où l'immédiat fait doublon. Restait à le voir sur un type **sans autre canal avant le lundi**. Fait le 02/09, en transaction annulée sur `blmf-teste` avec une actrice synthétique (admin réseau fixture, non staff de la biblio — le critère `fn_is_cross_library_action` exclut à raison l'admin qui est aussi staff local, ce qui disqualifiait l'identité de Xavier pour l'épreuve) : `fn_team_suspend_member` → membership `suspended`, **ligne d'outbox `network.cross_library_critical_action` avec `action_type=team_suspend_member`**, ligne de journal — la chaîne SQL exacte qui tombait dans le `else` du handler avant le 31/08. La jambe EF n'a pas besoin d'être rejouée : le handler est agnostique au type (un seul événement, le type ne choisit que le libellé, et `cross-library-strings` porte « Suspension d'une personne de l'équipe » dans les dix locales — vérifié). Sanité post-rollback : Voltairine `active`, l'actrice fixture disparue, zéro ligne résiduelle. **Vu en chemin** : le canal mail de `blmf-teste` est retombé sur `disabled`/`inactive` après l'épreuve G4 — c'est l'hygiène attendue d'une biblio de formation, et la raison de plus pour l'épreuve en transaction. |
| G5 | 2026-09-02 | **Le drapeau commande quelque chose de réel, il est posé juste, et la Terra Livre n'est pas en mode test.** La fiche regardait `libraries.is_test_mode` : cette colonne **n'existe plus** — la migration du 30/08 (`06f933d7`, « on retire la copie figée et le réglage qui ne réglait rien ») a déjà tranché l'autre moitié de G5 en retirant `email_delivery_mode` et en nommant la vraie colonne. Le drapeau vit dans `library_commons.is_test_mode` (défaut `false`), exposé par la vue `api.library_email_identity`, posé au provisionnement par `fn_provision_preactive_library` et par `register`. **Valeurs le 02/09 : `blmf-teste = true`, les trois bibliothèques réelles = `false`.** Ce qu'il commande, et rien d'autre : le **bandeau « contexte de test »** dans les avis internes d'inscription (`register`, `buildInternalMail` — `isTestContext = is_test_mode OU redirection interne posée`), le même mécanisme que les deux secrets vides-exprès de F7. Aucun front ne le lit, aucune policy, aucun filtre d'affichage : son nom ne ment pas sur sa portée. Des trois issues écrites dans la fiche, c'est la première — et il n'y a rien à demander à la BTL, qui n'a jamais été en mode test ailleurs que dans une colonne morte. **Limite écrite** : le drapeau se pose à la création et n'a pas d'interrupteur ensuite — le jour où une bibliothèque de formation doit devenir réelle (ou l'inverse), c'est un UPDATE de coordination, pas un bouton. |
| I14 (config.toml et la CI) | 2026-09-02 | **L'angle mort était déjà fermé — depuis le 01/09, par le commit `5e129c54` — et l'item ne l'avait pas suivi.** `deployer-backend.sh` surveille désormais `supabase/config.toml` à côté de `supabase/functions/` (`git diff --name-only <marqueur> <tête> -- supabase/functions/ supabase/config.toml`, ligne 308), redéploie **tout** quand le fichier de configuration bouge, et raconte l'incident du 01/09 dans son propre récit (lignes 244-250 : le commit `c152e7fa` ne changeait que `config.toml`, la CI est restée verte et n'a rien déployé) — la même famille d'angle mort que `--depuis event.before` du 27/08, et la même parade : le journal DIT ce que le diff couvre. **Éprouvé au banc le 02/09**, en local, sur une branche jetable : un commit ne touchant que `config.toml` fait apparaître le fichier dans la liste des déclencheurs — l'étape ne se sauterait plus. **Limite écrite (`DOC-ACTIF-1`)** : aucun push ne changeant que `config.toml` n'a eu lieu depuis le correctif ; l'épreuve en conditions réelles sera le prochain — et c'est le journal du job `backend` qui en fera foi. |
| E13 | 2026-09-03 | **Livré le matin même, commit `18ac8676`.** Le panneau « Ma demande » de Mon compte (`MinhaSolicitacaoPanel`) fait trois choses qu'il ne faisait pas la veille : **(1)** une phrase en tête dit ce qu'il est — « la demande d'adhésion de votre bibliothèque au réseau, et vos échanges avec l'administration du réseau pendant son examen » ; **(2)** une demande approuvée porte un bouton « Aller à l'atelier de constitution » vers `/atelier` — le circuit réel y emmène d'office quand le profil est en constitution (`LoginPage`, `ProtectedRoute`), mais dès que cet état manque la phrase désignait une adresse à deviner ; **(3)** une condition de fin : demande approuvée dont la bibliothèque est née (`completed_at` de `my_constitution_progress_v1`, lu par la requête filtrée sur la demande) ou refusée depuis plus de trente jours → le bloc se replie derrière « Historique de mes demandes » au lieu de coiffer Mon compte à vie. Dix locales, +3 clés (6 237). Banc 362/362. **Le regard extérieur du circuit complet reste dû** — même exigence qu'E12 f[3], à confier pendant la formation BLMF (soirée 1 le 08/09/2026) ; la fixture Voltairine qui avait révélé le défaut a été retirée par la session des captures dans la nuit (0 demande depuis le 02/09, vérifié en base le 03/09). |
| I4 | 2026-09-03 | **Le témoin de provenance était fini depuis le 20/08 — sous d'autres noms que ceux de la fiche.** La fiche cherchait une migration `20260827180000_temoin_sauvegarde_provenance` et un correctif `health_probe_provenance.patch` : ni l'un ni l'autre n'existent nulle part (dépôt, Windows, WSL, transcripts — cherchés le 03/09). Mais ce qu'ils devaient produire est **en production** : *(base)* `fn_backup_heartbeat_status` expose `host`, `temoin_amorcage` (= « aucun témoin réel, ligne d'amorçage ») et `instantane_atteste` — posés par `20260820012343_backup_heartbeat_status_expose_host_et_amorcage`, affinés jusqu'à `20260901101901` ; le 03/09 les trois flux répondent `host = ACCATTONE`, `temoin_amorcage = false`, `instantane_atteste = true` (instantanés `973e398e`, `fb17d44c`, `e1428cff`). *(fonction)* la `health-probe` **déployée** (source relu via l'API le 03/09, pas seulement le dépôt) rend cette provenance dans chaque incident et chaque courriel (`provenanceTexte` / `provenanceHtml`, commit `ba0d2433` « le champ qui devait éclairer l'angle mort n'était lu par personne »). Forme `DOC-RECENS-1` : la fiche décrivait comme à faire un chantier fait sous un autre nom. Deux fantômes à ne plus chercher : la migration `…180000` et les deux `.patch`. |
| H1 | 2026-09-03 | **Les 159 dates sont en base, avec libellé et liens — et l'épreuve a trouvé un second retour précoce.** Le correctif que la fiche disait « jamais éprouvé contre le site » était commité depuis le 27/08 (`04b86dd7`, `36d33bfc`) avec son test ; ce qui manquait, c'était l'aspiration. Faite le 03/09 (623 fiches, concurrence 2, un 503 du site absorbé par une reprise à 90 s) : les 161 dates sortent avec leur `title_fr`… **mais sans leurs liens** — Placard et Cartoliste pointent bien vers chaque année, et la section des liens venait *après* les deux retours précoces, exactement comme le H1 la veille. `collectCatalogLinks` est désormais appelée en tête de `parseDescriptor` (`2f314f15`) ; ré-aspiration : 159 dates avec libellé, 147 avec liens (275 liens), 2 fiches nues sur 623. **Synchro en base le 03/09** à la sémantique du script (upsert sur `mot_id`, jamais de purge) mais par la base directement, la CLI masquant les clés secrètes et la clé legacy étant désactivée depuis la veille : 159 dates nouvelles, 32 fiches mises à jour (l'astérisque final des libellés portugais, détaché par le scraper depuis le 28/08 et jamais synchronisé depuis le 30/06), 430 inchangées ; `harvested_at` 03/09 sur les 621 ; `subject_ficedl_links` intact (98). Contrôle : « 1936 » → Placard `mot6725` + Cartoliste `parution&date=1936`. Deux pièges tenus : `--json` explicite, pas de `--prune`. La page publique du thésaurus n'offrait que Sujets et Lieux : **onglet « Dates » ajouté** (`d42f54a5`, +1 clé, 6238). Reste hors fiche : le domaine `bianco.ficedl.info` n'est pas dans `CATALOG_HOSTS` (les dates y renvoient aussi) — à décider avec le thésaurus, pas ici. |
| I16 | 2026-09-03 | **Tranché A et livré le matin même.** `supabase/functions/_shared/deps.ts` épingle `@supabase/supabase-js@2.114.0` (dernière 2.x au registre npm le 03/09) et ré-exporte `createClient` ; les **trente** fonctions et `env.ts` importent de là — plus un seul `esm.sh/…@2` ni `npm:…@2` dans une fonction. La règle est écrite dans `CONTRIBUTING.md` (§3.4, fr et en) et **gardée par un banc** : `src/tests/supabase-js-epingle.test.js` refuse tout import direct et exige une version exacte dans `deps.ts`. Les deux bancs d'EF (`gazette`, `harvest`) reconnaissent `deps.ts` comme le client. La montée de version est désormais un geste daté : changer un nombre, redéployer tout (le déployeur redéploie l'ensemble dès que `supabase/functions/` bouge — c'est écrit dans `deployer-backend.sh`, lignes 211-258), noter la date ; le recompte mensuel de CLAUDE.md relit ce nombre. Le mélange du 01/09 — une épinglée en retard, trente flottantes en avance — ne peut plus se reproduire. |
| C5 | 2026-09-03 | **B, livré l'après-midi même — et la dette était deux fois plus grande que la fiche ne le disait.** *(1) Le rendu unique* « autorité sinon transcription » était **déjà** la règle de l'OPAC (`author_display || autor` dans `BookPage` et `CatalogPage`, `author_display` venant de `v_book_authors_canonical`) — rien à écrire, forme `DOC-RECENS-1`. *(2) Le formulaire* ne pré-remplit que la transcription (recherche ISBN, œuvre parente) et n'a jamais pré-rempli d'autorité depuis `autor` ; le libellé du champ dit désormais « auteur tel qu'imprimé », dix locales. *(3) Le lot* `autor_sans_autorite` existe (`7618ccfc`, migration `20260903150117`) : CHECK élargie, semis rejouable, `conv_revue_list` rend la transcription comme « actuel », `conv_revue_appliquer` **pose un lien** au lieu de réécrire un texte — autorité retrouvée par l'une des deux formes sans casse ou créée, lien sur le contributeur homonyme ou ligne neuve, anti-écrasement CONV-O6 ; « Anônimo », « Coletivo », « AA. VV. » ne reçoivent aucune proposition. **464 livres semés en production, pas 226** : la fiche comptait les livres sans ligne `book_authors`, table *dérivée* par trigger ; la vérité des contributeurs vit dans `book_contributors`, et 464 livres n'y ont aucun `author_id` (247 sans contributeur du tout, 217 avec des noms non liés). Suite SQL de 8 tests, verte en local avec O7 et O8 ; carte « Auteurs sans autorité » dans l'atelier. Le travail des 464 est un travail de main, à l'Atelier autorités, sans échéance — la file le porte. **Le soir même, Xavier a tranché les 464** dans l'Atelier (16 h 05 – 16 h 10) : 446 validés et appliqués — 446 liens posés, **227 autorités créées** par l'application (`source_kind = 'conv_revue'`) —, 18 écartés (anonymes, collectifs). Il reste 18 livres sans autorité, tous écartés à dessein. Les 227 autorités neuves et les secondes personnes des 125 chaînes multi-noms sont le premier objet de l'audit en profondeur cadré dans `docs/journal/cadrages/REPRISE_audit_autorites_en_profondeur_2026-09-03.md`. **03/09, nuit — l'audit est fait** : les 227 sont classées (98 formes inversées correctes, 60 formes directes, 35 mononymes, 48 en capitales, ~20 collectivités non typées, 7 mentions de rôle, 8 fiches doubles, `??`, `identificado, Não`) ; **9 sont des doublons** de fiches corrigées le 21/08 — la recherche d'homonyme du lot comparait à la lettre. Corrigé (recherche `fn_conv_autorite_homonyme`, sans casse ni accents, forme dérivée ; proposition qui lit « identificado, Não ») ; les 227 sont versées aux lots `autorite_casse`, `autorite_collectivite` et au nouveau `autorite_forme` ; 8 doublons exacts sont signalés à l'Atelier (les 5 paires de fixtures de formation exclues). Les 333 secondes personnes restent : lot par contributeur à écrire, après l'homonymie. |
| D2 | 2026-09-03 | **A, les cinq — et le seul geste de code est livré.** Verdicts inscrits (spec périodiques v1.0 §13, `5f63e75f`) en accord avec le code : `periodicidade` libre, deux liens de filiation, pas de `library_id`, promotion = un geste, page dédiée. La liste de suggestions non contraignante de `periodicidade` (huit valeurs, `datalist`, dix locales) est dans `SerialDetailEditor` depuis `5f43a247` ; elle ne se fermera que le jour où un fonds réel (Anarchief) en fera apparaître le besoin. 4 titres en base, `periodicidade` jamais renseignée : la liste arrive avant le premier usage. |
| E11 | 2026-09-03 | **A — les tags fermés, le flux requalifié et livré le jour même.** `OPAC-TAG1` fermé au REGISTRE (un tag signé dit qui a lu quoi ; un tag anonyme ne se modère pas ; le besoin est couvert par l'autorité matière et le thésaurus). `OPAC-RSS1` requalifié puis **livré** (`e7a8acab`) : Edge Function `rss-novidades` — `GET /functions/v1/rss-novidades/<slug>`, **deux gardes et rien d'autre** (la bibliothèque est publique via `api.libraries_public_v1` ; les notices viennent de `v_books_public_catalog_v2`, la vue que l'OPAC anonyme lit déjà), RSS 2.0, autorité sinon transcription, lien vers la notice, cache d'une heure ; banc d'essai de 5 tests (même recette que gazette, `@vitest-environment node`) ; lien « Nouveautés (RSS) » sur la page publique et en tête du catalogue de chaque bibliothèque, dix locales. Sans requête, sans compte : rien à pister. **Ce que le banc ne voit pas, la production l'a montré** : à la première requête, 500 « permission denied for view libraries_public_v1 » — la vue `security_invoker` n'était accordée qu'à `anon` et `authenticated`, pas au rôle de service de la fonction ; un grant `SELECT` (`3677442a`, `20260903150755`) a suffi, le prédicat de publicité reste dans la vue. Vérifié ensuite en production : `/rss-novidades/blmf` répond un flux valide. |
| B4 | 2026-09-04 | **Verdict écrit le 04/09 (`04b5c298`, migration `20260904184501`) : les quatre sont fermées exprès.** `author_name_aliases` (1 644 lignes) est lue par six fonctions `SECURITY DEFINER` (`merge_author`, `preview_merge_author`, `suggest_author_duplicates`, `suggest_authority_duplicates`, `fn_conv_fusionner_doublon_exact`, `api.search_catalog_v1`) et deux vues (`v_author_alias_candidates_unique`, `v_author_alias_worklist`) — rien ne la lit directement, et rien ne devrait. `library_themes` (7 lignes) et `library_theme_configs` (vide) passent par `get/set_library_theme_config*` et `fn_ensure_library_theme` ; `interlibrary_loan_events` (vide) n'est écrite que par `fn_v2_log_emprestimo_interbibliotecas_event` — le PEB n'a pas d'écran (G6). Chaque table porte le verdict en `COMMENT ON TABLE`, avec les noms. **Le second critère était déjà rempli** : `deploy/bootstrap.sh` liste nommément les 15 tables fermées attendues (`SANS_POLICY_ATTENDUES`) et échoue si l'une manque ou s'il y en a une de trop — `DOC-RECENS-1`. |
| I11 | 2026-09-04 | **`node:22` depuis le 04/09 (`04b5c298`)** — sept occurrences dans `ci.yml` et `sql-tests.yml`. La CLI Supabase `v2.98.1` est un binaire téléchargé par `curl`, pas un paquet npm : rien à réinstaller. Preuve en deux runs : le run 1191 (premier sur `node:22`) a passé `app` (lint, tests, build, 2 min 41) et `sql-tests`, et `backend` est allé jusqu'au `db push` — qui a échoué sur le garde de **B9**, pas sur l'image ; le run suivant (`ea813837`) a passé `backend` de bout en bout, migrations appliquées en production. |
| I8 | 2026-09-04 | **Réécrit le 04/09 (`04b5c298`).** L'en-tête de `deploy/README.md` dit désormais ce qui a tourné le 26/08 — trois passes de `bootstrap.sh` (volumes vierges : 183/183 migrations en 12 s, 184 tables, 0 sans RLS, 77 migrations GoTrue ; dump factice ; **dump réel de la production**, objet Storage servi octet pour octet), **huit défauts** trouvés et corrigés (collision du nom de projet Docker, `--wait`, faux vert de l'étape 8, buckets qu'aucune migration ne crée, Storage démarré après la restauration, image Storage `v1.60.4` → `v1.70.7`, disposition des fichiers Storage ≠ sauvegarde), la doctrine d'ordre qui en sort, **huit étapes plus une « 7 bis »** — et ce qui n'a pas tourné (la bascule, le routeur `main` en conditions réelles, un vrai domaine). Les quatre points « à confirmer » ont leur verdict : `notify-cross-library-digest` **clos** (elle est au dépôt), le rejeu des migrations **fait** (étape 5 à deux branches), `CADDY_TAG=2` **justifié** dans `.env.example` (seule entorse au « jamais de `latest` », à épingler le jour de la répétition finale) ; GoTrue/courriel et `PGRST_DB_SCHEMAS` restent marqués à vérifier, honnêtement. |
| E8 | 2026-09-04 | **Clos le 04/09 sur mesure consignée — le travail datait du 06/05 (`dba21cd3`).** Avant : deux TTF bloquants, `titre.ttf` 1 Mo + `accent.ttf` 484 Ko, soit **≈ 1,5 Mo** avant tout texte. Après : **19 fichiers woff2 auto-hébergés, 1 296 308 octets en tout** (Bitter + Fira Sans, graphies latine, grecque, cyrillique), chargés à la demande par face et par graphie, **tous en `font-display: swap`** (10 déclarations dans `src/styles/fonts.css`) ; **seuls deux fichiers sont préchargés** au premier rendu (`index.html:47-48`) : `FiraSans-Regular.woff2` 44 904 octets + `Bitter-Regular.woff2` 36 516 octets = **81 420 octets**. Sur une connexion de comptoir, le texte s'affiche avec la police de substitution puis bascule ; rien ne bloque. Le sous-ensemblage (troisième idée du constat) n'a pas lieu d'être : le découpage par graphie fait déjà ce travail. Mesuré dans le dépôt le 04/09. |
| J6 | 2026-09-04 | **Le constat était faux depuis le 17/05 — `DOC-RECENS-1`.** Les cinq doctrines sont **au dépôt depuis la refonte bilingue du README** (`fbe8969b`, 17/05/2026), section « Doctrines internalisées / Internalized doctrines », en français et en anglais, avec quatre autres (traçabilité R8, proposeur silencieux, qui notifier, compte auth en SQL direct). Ce qui manquait tenait en une ligne : **aucun chemin depuis `CONTRIBUTING.md`**. Ajouté le 04/09 (`04b5c298`) dans la table « selon ce que vous touchez » : une RPC qui écrit plusieurs tables, un courriel sortant, l'auth côté front, un script sous Windows → le README. Les incidents d'origine sont dans le code lui-même là où ils existent (`AuthContext.jsx` : la boucle de re-fetch qui saturait le pool ; baseline `paquet 141.2.E`, fix B3 du 16/05). |
| I10 | 2026-09-04 | **Clos le 04/09 (`04b5c298`).** `tmp-ficedl/` supprimé du disque (740 Ko, ignoré par git depuis le 28/08). Le secret de fonction `TURNSTILE_SECRET_KEY` — dernière trace hors historique — **retiré** (`supabase secrets unset`, après vérification que les sept mentions restantes dans le code sont des commentaires « remplace Turnstile »). `docs/drafts/` a sa règle, écrite dans `docs/drafts/README.md` : **un sas, pas une réserve** — ce qui y entre en sort dans le mois, promu, tranché par décision ou supprimé ; `archive/` garde la trace. Et le sas est vidé dans le même geste : le brouillon de recherche par accents, **périmé depuis le 03/07** (remplacé par `api.catalog_search_ids_v1`, son en-tête le disait), rejoint `archive/` sous sa date d'entrée. `.env.example` garde une mention historique en commentaire, à dessein. |
| B9 | 2026-09-05 | **Purgé le 04/09 au soir, par décision de Xavier après relecture** (`6295f256`, migration `20260904223000`, session voisine) : le schéma portait les vingt opérations d'essai de la circulation v2 (mars–avril 2026, deux comptes), pas « zéro ligne » — le constat du 30/08 lisait `pg_stat_user_tables`, remis à zéro par le redémarrage du 02/09. Ma première migration (`04b5c298`) avait refusé la purge et fait tomber le job `backend` ; la version différée (`ea813837`) a passé, puis la purge relue a suivi le soir même. Vérifié le 05/09 : `to_regnamespace('backup_2026_05_07')` est nul. `deploy/bg2-known-tables.txt` n'avait rien à changer (il ne classe que `public`). Six avis « pas de clé primaire » en moins. |
| B11 | 2026-09-05 | **Trouvé le 05/09 : c'est le harnais de test de charge, pas une boucle du front.** `scripts/loadtest/anarbib-loadtest.mjs` (versé au dépôt le 17/08, campagne des plafonds de capacité) écrit exprès dans `user_wishlist` — étape `w_wishlist`, `POST /rest/v1/user_wishlist?on_conflict=user_id,book_id` puis retrait — parce que c'est l'une des deux tables sans déclencheur de courriel (le README du harnais le dit : « ne jamais mettre dans le volume une opération qui déclenche un e-mail »). Neuf mille allers-retours pour une ligne survivante, c'est la signature d'une campagne de charge, et le compte de la base ne connaît aucune autre écriture : les six fonctions qui touchent la table sont des fusions, des suppressions et l'export RGPD. **Contre-épreuve** : depuis la remise à zéro des compteurs le 02/09, zéro insertion, zéro suppression, une ligne vivante. La ligne est retirée du constat, comme la fiche le prévoyait. |
| E7 | 2026-09-05 | **Clos le 05/09 (`7434c1b6`) — le constat avait déjà été corrigé le 31/08, il restait à compter.** Compté sur `App.jsx` : 31 routes ; toutes les pages routées portent `useDocumentTitle`, y compris celles servies par `ContaRouter` (compte, compte contributeur·rice, écrans d'attente et de refus) et l'atelier de constitution. Deux manquaient : la **page 404** (définie dans `App.jsx`) et la page d'essai OCR (`/dev/ocr`, jetable). Posées le 05/09 avec deux clés (`pageTitle.notFound`, `pageTitle.ocrDev`) dans les dix locales — 6 395 clés, parité stricte. Le test `documentTitle.test.js` (31/08) couvre le hook ; les 35 fichiers de `src/pages/` sans hook sont des onglets et composants, pas des routes. |
| B7 | 2026-09-05 | **Départagés le 05/09 (`7434c1b6`, migration `20260905132602`, suite `homonymes_ingest_public_tests.sql`).** Mesuré en production : tous les appels vivants sont **qualifiés par schéma** et visent `ingest.*` (`fn_import_promote`, `fn_import_set_editorial`, `fn_import_reconcile_duplicates`) — le risque du `search_path` décrit par la fiche n'avait pas de chemin réel. Les trois de `public` n'étaient appelées par **rien** : ni fonction (hors elles-mêmes, en chaîne fermée), ni vue, ni trigger, ni Edge Function, ni fichier du front — et elles étaient `SECURITY DEFINER`, exécutables par `authenticated` : trois entrées de plus au lint 0029 (399 → 396). Supprimées, avec un garde qui refuse si un corps ou une vue cite encore `public.<nom>` ; les versions `ingest` portent leur commentaire. `set_updated_at` reste, comme prévu. Six tests : plus d'homonyme, un seul exemplaire par nom, `ingest.*` DEFINER à `search_path` figé, fermées à `anon` et `authenticated`, appelants qualifiés, aucune citation résiduelle. |
| OPAC par œuvre | 2026-09-05 | **Livré les 04-05/09** (`cac464fd` → `06b928ed`, douze migrations `20260904095317` → `20260905154500`, quatre suites SQL, Edge Function `work-titles-autofill`) : une ligne par œuvre à l'OPAC, éditions puis exemplaires par bibliothèque dépliables, titre dans la langue de la lectrice (`work_titles`, pré-traduction « corrige-moi »), rattachement et fusion d'œuvres au catalogage, onglets « Œuvres scindées » et « Volumes » de l'assistant, champ « Tome / volume », titre uniforme dans la langue de l'œuvre. Trente groupes scindés arbitrés à la main et appliqués ; 2 125 notes d'import effacées ; 68 « Assuntos importados » convertis vers des matières existantes. Doctrine au REGISTRE : `OPAC-OEU1..6`, `DEDUP-10`, `THES-4`. Ce qui reste à arbitrer est l'item **C11**. |
| H8 | 2026-09-07 | **Clos le 07/09, le jour même du constat** (migration `20260907120000_getrecord_sert_la_notice_demandee`, suite `oai_getrecord_tests.sql` au manifeste). `fn_oai_harvestable_records` appliquait `p_book_id` au comptage et pas aux notices : `GetRecord` servait la première notice de la bibliothèque quel que soit l'identifiant demandé, et une notice pour un identifiant inexistant. La fonction est réécrite **depuis sa définition lue en production** (identique à la migration de juin, vérifié), avec le même prédicat dans les deux requêtes ; grants et liste T10 inchangés. La suite demande la **seconde** notice d'une bibliothèque ouverte à deux notices (T3) et un identifiant inconnu (T4) — la seule forme de test qui voit le défaut, puisque l'essai du 02/09 (H5) portait sur la première notice. Sans effet en production : aucune bibliothèque n'est ouverte au moissonnage, aucune source enregistrée. Reste à faire à la prochaine ouverture réelle : rejouer `GetRecord` sur un identifiant qui n'est pas le premier. |
| I20 | 2026-09-07 | **Clos le 07/09, le jour même du constat** (migration `20260907123000_l_adresse_des_fonctions_n_est_plus_codee_en_dur`, suite `adresse_des_fonctions_tests.sql`, garde `src/tests/migrations-sans-url-cloud.test.js`, `bootstrap.sh` étape 5 bis + contrôle (g), note dans `.env.example`). Une source de vérité : le réglage de base `anarbib.functions_base_url` (`ALTER DATABASE … SET`, lu à l'ouverture de chaque session par PostgREST, pg_cron et psql), servi par `private.fn_functions_base_url()` — INVOKER, fermé à anon/authenticated — qui se replie sur le projet cloud quand le réglage manque : **la production ne change pas de comportement**. Les douze fonctions (relevé `pg_proc`, toutes à `postgres`) sont réécrites **par motif sur leur définition réelle** au moment de l'application, depuis une liste nominative et fermée (une absente fait échouer la migration) — c'est ce qui permet de repartir de la définition réelle sur douze corps sans les recopier, et le nom de chaque fonction reste trouvable au grep. Le job cron `anarbib-health-probe`, qui portait l'URL dans sa commande même, est replanifié par `cron.schedule` (idempotent par nom). Le vitest n'accepte le littéral `supabase.co/functions/v1/` que dans les huit migrations historiques et celle-ci. `bootstrap.sh` pose le réglage depuis `API_EXTERNAL_URL` **dans les deux modes** (un dump de production ne l'emporte pas) et le vérifie en fin de course dans une session neuve. Non exercé sur une pile réelle : le domaine I est gelé sur la production jusqu'au 14/09 ; c'est le premier contrôle à regarder à la prochaine répétition (I2). |
| I17 | 2026-09-07 | **Clos le 07/09 sur le constat de l'expérience du §7** (`journal/operations/NOTE_experience-I17-rejeu-fidele_2026-09-07`), pas sur le code. Sur `main` à `c28baac0`, sans la PR #28, image `supabase/postgres:17.6.1.136`, volume vierge : avec A.1 (`anon` retiré du défaut *fonctions* des **deux** rôles dans `01-roles.sh`, entrées vérifiées non vides) et A.2 (migrations sous `postgres`), **310/310 migrations vertes**, dont celles du 29/08, 30/08, 02/09 et 04/09 sans aucun `REVOKE` ni tolérance ajoutés ; 676 fonctions possédées par `postgres` ; **133 fonctions exécutables par `anon`, empreinte MD5 identique à la production** interrogée en lecture seule à la même minute ; `pg_default_acl` sans `anon=` pour les deux rôles, l'entrée `postgres` rétablie par le socle puis refermée par `20260831105114` ; T8-T11 verts. L'option B n'a pas eu à être considérée. Appris en chemin : l'entrypoint traite `initdb.d/*` dans l'ordre du glob, `99-roles.sh` passe **avant** `migrate.sh` (le commentaire de `compose.yml` est faux, `bootstrap.sh` rejoue le script à l'étape 2) ; `cron.job` absent à la 288e, `CREATE EXTENSION pg_cron` sous `postgres` réussit (→ `I19`). Reste **T7** rouge : cinq vues du socle lisibles par `anon` au rejeu, `anon=m` en prod, `REVOKE SELECT` écrit nulle part — versé à `B22`. Le code A.1/A.2 reste à proposer à Bastien après la fusion de la #28 (D7). |
| E18 | 2026-09-07 | **Constaté et clos le 07/09 par Xavier, sur `/obra/133` (« L'Homme et la Terre », Reclus)** : six « éditions » strictement identiques à l'écran — « 1905 · Librairie Universelle · Français » six fois, dans l'ordre VI, V, IV, I, III, II. Les données étaient justes (les six notices portent `volume` = I à VI et le sous-titre « Tome N ») : `api.work_public_detail` ne servait pas `volume` et triait par année puis titre, six clés égales. La liste du catalogue, elle, servait déjà le tome par édition avec son badge « Tome N » (`catalog.works.volumeLabel`, dix locales) — la page Œuvre était la seule surface à l'ignorer. Migration `20260907220000_la_page_oeuvre_dit_le_tome` (RPC reprise de sa définition en production : `volume` dans chaque édition, tri année → `fn_volume_rank` → titre, grants conservés), badge « Tome N » dans `WorkPage.jsx` avec la clé existante, suite `oeuvre_tomes_page_tests.sql` au manifeste (trois tomes insérés III, I, II qui doivent sortir I, II, III ; une édition sans tome garde `volume` NULL). Vérifié à l'écran sur `/obra/133` après déploiement. **Second geste le soir même, sur remarque de Xavier** (« c'est pas six éditions, c'est six tomes d'une seule édition ») : l'en-tête disait encore « 6 édition(s) ». Migration `20260907233000` : la RPC sert `edition_count` (une notice sans tome = 1 ; les tomes d'une même année/éditeur/langue = 1) et `volume_count` (tomes distincts, même règle que la liste), l'en-tête compose « 1 édition · 6 volumes » avec les clés plurielles existantes ; T6-T7 ajoutés à la suite. |
| E5 | 2026-09-07 | **Livré et en production le soir même — la dernière exception anti-pistage tombe, et pas par la voie que la fiche proposait.** La fiche voulait un *relais* de `tile.openstreetmap.org` avec cache ; la politique des tuiles d'OSM déconseille les proxys et interdit tout préchargement, et un relais aurait gardé la dépendance. Fait à la place : **un seul fichier PMTiles** (planet Protomaps du 07/09, dérivé d'OpenStreetMap, ODbL) extrait à **z12 = 18 Go** (`pmtiles extract --maxzoom=12`, mesures à vide : z10 3,7 Go, z11 7,9, z13 36, z14 68, z15 138), déposé dans le bucket public **`map-tiles`** (créé en base + migration `20260907234500` inerte ensuite, plafond global Storage monté de 500 Mo à 20 Gio par l'API de gestion, les cinq buckets sans plafond propre figés à leurs 500 Mo de fait) et lu par le navigateur **par requêtes Range** (Storage répond 206 + CORS `*`, vérifié). Rendu dans le Leaflet vendorisé par **`protomaps-leaflet` 4.0.1** (vendorisé, BSD-3, canvas + polices web, pas de serveur de glyphes) via `src/lib/mapTiles.js` ; les trois cartes (`CartographyMap`, `CartographyEditModal`, `CartografiaAjouterPage`) n'ont plus une ligne `L.tileLayer`. Garde CI `src/tests/carte-sans-domaine-tiers.test.js` (aucun `tile.openstreetmap.org` dans `src/`, toute `L.map(` passe par `addBasemap`). `privacy.s6.maptiles` et `federacao.carte.attribution` réécrits dans les dix locales. Recette et rythme de rafraîchissement : `scripts/maptiles/README.md` + `extraire-planet.sh` (mesure par défaut, n'agit que sur demande). **Deux limites écrites** : (1) le fichier est sur le Storage Supabase — la fuite d'IP vers un tiers est close, pas le périmètre Cloud Act, qui tombe avec **I2** (copier le fichier là où Caddy le sert, poser `VITE_MAPTILES_URL`, et compter ces 18 Go dans le disque demandé aux Herbes Folles — **I21**) ; (2) `map-tiles` est volontairement hors du flux storage de **BG2** (reconstructible en 30 min). Étiquettes : `ca` et `eo` absents du fond → noms locaux, sans repli vers une autre langue. Accessoirement : l'échec de juin 2026 dont tout le monde se souvenait comme « les fonds de carte » était **Nominatim** (géocodage, MAP-F), qui reste non configuré. Incident de méthode : la mesure à vide de z15 (177 M d'entrées) lancée en même temps que l'extraction a figé WSL à son plafond de 15 Go — `wsl --shutdown` avec l'accord de Xavier, aucune autre session active, rien perdu ; mesurer seul, ou pas z15. |

---

## Ce qui n'est pas au backlog

Trois choses ne sont pas au backlog, et il faut le dire pour que personne ne les y remette.

**Les décisions actées au REGISTRE ne se rouvrent pas au détour d'une tâche.** `text` + `CHECK` plutôt qu'un type énuméré PostgreSQL, la casse naturelle en base avec le rendu calculé à l'affichage, l'absence de captcha hébergé par un tiers, l'opt-in strict de la lettre, le refus du paiement en ligne self-service, l'absence de hiérarchie à la Library of Congress pour les collectivités — ce sont des positions, pas des choix par défaut. Elles se rouvrent par une décision inscrite au REGISTRE, jamais par un correctif.

**Les tâches de revue humaine ne deviennent pas des scripts.** Le SQL d'application des trois tables `conv_backup` est en commentaire, derrière une garde anti-écrasement. Le décommenter, le compléter, ou écrire un script qui passe `valide = true` en masse : non. C'est le plan de travail de l'Atelier autorités, pas un reste à liquider.

**Les chantiers collectifs n'ont pas de date fixée par une seule personne.** La révision portugaise complète du thésaurus, le vocabulaire des questions LGBTQI+, la gouvernance du commun, le rapprochement avec leftove.rs et NORLA : leur calendrier ne s'écrit pas ici. Prétendre le fixer seul serait exactement l'erreur que ce projet cherche à ne pas commettre.

---

## Maintenance de ce document

Le backlog se maintient comme les précédents, avec une addition.

1. Déplacer la version courante dans `docs/backlogs/archive/` en conservant son nom d'origine.
2. Placer la nouvelle version à la racine de `docs/backlogs/`.
3. Mettre à jour `docs/backlogs/INDEX.md` : version courante et ligne d'historique. *(La ligne du v32 y manque encore — c'est l'item **J2**.)*
4. Si l'incrément porte une décision normative, inscrire l'identifiant au `REGISTRE_decisions.md`. Le backlog porte le travail à faire ; le registre porte ce qui fait foi.
5. **Nouveauté du v34** : les deux versions linguistiques et la page consultable sont **engendrées** depuis `docs/backlogs/backlog-v34.json` par `scripts/build-backlog.cjs`. Ne modifiez jamais les `.md` à la main : ils seront écrasés. Modifiez le JSON, relancez `node scripts/build-backlog.cjs`, commitez les trois fichiers ensemble.

Si cette mécanique gêne plus qu'elle n'aide, elle se jette sans dommage : les `.md` engendrés sont autonomes et le JSON peut être supprimé. C'est un outil, pas une doctrine.

---

## Colophon

Backlog v34, écrit le 2026-08-29, mis à jour le 2026-09-08. Remplace `AnarBib-Backlog-2026-06-17-v33.md`. 86 items sur 11 domaines. L'état chiffré a été relevé le 2026-09-08 contre la base de production en lecture seule et contre le dépôt Codeberg au commit `e3a15243` ; les items retouchés depuis portent leur propre date dans leur texte. Ce document n'arbitre rien : le `REGISTRE_decisions.md` fait foi.
