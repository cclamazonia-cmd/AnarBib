# Backlog AnarBib v34 — Réécriture intégrale sur état vérifié — outil de travail pour les collaboratrices et collaborateurs à venir

**2026-08-29** · mis à jour le **2026-08-31** · 83 items · Versão em português : `AnarBib-Backlog-2026-08-29-v34.pt-BR.md`

> Fichier **engendré** par `scripts/build-backlog.cjs` depuis `backlog-v34.json`. Ne le modifiez pas à la main.

---

## Sommaire

- [Pourquoi une réécriture](#pourquoi-une-réécriture)
- [Mode d'emploi](#mode-demploi)
- [L'état réel au 29 août 2026](#létat-réel-au-29-août-2026)
- [Écarts relevés entre le réel et l'écrit](#écarts-relevés-entre-le-réel-et-lécrit)
- [Le calendrier contraint](#le-calendrier-contraint)
- [Dix règles payées par un incident](#dix-règles-payées-par-un-incident)
- [Les chantiers](#les-chantiers)
    - [A — Soutenabilité collective](#a--soutenabilité-collective) · 3
    - [B — Base de données, sécurité, RLS](#b--base-de-données-sécurité-rls) · 10
    - [C — Catalogage et données documentaires](#c--catalogage-et-données-documentaires) · 10
    - [D — Périodiques, éphémères, ressources numériques](#d--périodiques-éphémères-ressources-numériques) · 6
    - [E — Front, OPAC, i18n, accessibilité](#e--front-opac-i18n-accessibilité) · 11
    - [F — Courriel et notifications](#f--courriel-et-notifications) · 6
    - [G — Réseau, gouvernance, fédération](#g--réseau-gouvernance-fédération) · 10
    - [H — Interopérabilité, thésaurus, moisson](#h--interopérabilité-thésaurus-moisson) · 7
    - [I — Auto-hébergement, exploitation, sauvegardes, CI](#i--auto-hébergement-exploitation-sauvegardes-ci) · 10
    - [J — Documentation et corpus](#j--documentation-et-corpus) · 2
    - [K — Caisse, communication, formation](#k--caisse-communication-formation) · 8
- [Clôtures et entrées caduques](#clôtures-et-entrées-caduques)
- [Ce qui n'est pas au backlog](#ce-qui-nest-pas-au-backlog)
- [Maintenance de ce document](#maintenance-de-ce-document)

---

## Pourquoi une réécriture

Ce document remplace le backlog v33 du 17 juin 2026. Entre les deux, **216 des 221 migrations appliquées en production** ont été écrites, ainsi que 655 commits. Le v33 portait un bandeau d'avertissement de fraîcheur ajouté le 28 août ; il ne suffisait plus.

Le v34 n'est pas une mise à jour du v33 : c'est une **réécriture sur état vérifié**. Chaque affirmation d'état a été relue le 29 août 2026 contre deux sources primaires — la base de données de production interrogée en lecture seule, et le dépôt Codeberg au commit `1d00ed2c`. Aucun item n'a été reporté sur la foi d'un document.

Ce travail a produit un résultat qui commande la lecture de tout le reste : **la documentation se trompe dans les deux sens**. Elle déclare ouverts des chantiers livrés depuis des semaines, et elle déclare livrées des choses que personne n'a jamais exercées. La section « Écarts relevés » les nomme un par un.

---

## Mode d'emploi

**Ce document n'arbitre rien.** La préséance documentaire du projet reste celle de `docs/INDEX.md` : le `REGISTRE_decisions.md` fait foi, puis la spec du domaine, puis ce backlog. Si une ligne d'ici contredit le REGISTRE, c'est le REGISTRE qui a raison et cette ligne est un défaut à signaler.

**Pour commencer sans rien demander à personne**, lisez `docs/CHANTIERS_OUVERTS.md` : sept portes d'entrée qui ne demandent aucune coordination. Le présent backlog est ce qui vient après, quand on veut savoir ce qui reste et pourquoi.

**Avant de prendre un item, ouvrez un ticket sur Codeberg.** Deux personnes qui écrivent le même correctif, c'est une soirée perdue pour l'une des deux. C'est la seule règle de coordination du projet, et elle tient en une ligne.

**Chaque fiche dit six choses** : ce que c'est, l'état vérifié au 29/08, pourquoi ça compte, ce qui compte comme fini, ce que ça demande, et ce dont ça dépend. Si l'une manque, la fiche est incomplète — dites-le plutôt que de deviner.

**Les identifiants ne sont jamais réutilisés.** Un item soldé garde son numéro et passe à la section des clôtures. Les renvois entre crochets pointent vers le REGISTRE, une spec ou un identifiant hérité d'un backlog antérieur : ils permettent de retrouver la trace, ils ne font pas autorité par eux-mêmes.

---

## L'état réel au 29 août 2026

Relevé du **29 août 2026**. Base de production `uflwmikiyjfnikiphtcp` interrogée en lecture seule ; dépôt `codeberg.org/anarbib/anarbib` au commit `1d00ed2c`. Ces chiffres ne sont pas des estimations : ils sont la réponse d'une requête ou d'un `ls`. Ils périmeront vite — c'est normal, et c'est la raison pour laquelle ils sont datés.

**Fraîcheur des constats au 2026-08-31.** **10 items sur 83** portent une vérification datée qui leur est propre (B2, B7, B9, B11, B14, B17, F4, F6, G1, G5). Les **73** autres reposent encore sur le relevé du 2026-08-29 et sont signalés comme tels sous chaque fiche. Un constat non revérifié n'est pas faux : il est seulement vieux, et la différence se voit ici plutôt qu'à l'usage. Cette ligne est recalculée à chaque engendrement du document.

### Base

| | | |
|---|---:|---|
| Tables `public` | **187** | toutes avec RLS activé, 279 policies sur 174 tables |
| Tables `ingest` | **10** | 8 étaient sans RLS le 29/08 au matin — **les 10 le sont depuis le soir** (item **B1**, soldé). Le schéma n'a jamais été exposé : ni `anon` ni `authenticated` n'y a `USAGE` |
| Vues `api` | **68** | **65 SECURITY INVOKER**, 3 DEFINER — les trois assumées et commentées `API-VUES-DEFINER` (item **B3**, soldé le 29/08) |
| Fonctions applicatives | **847** | dont **664 SECURITY DEFINER** ; aucune sans `search_path` épinglé |
| Migrations appliquées | **221** | 224 fichiers au dépôt ; 3 horodatées au 30/08 (item **I9**) |
| Jobs `pg_cron` | **36** | **tous actifs** ; 0 échec depuis le 17/08 ; 1 jamais exécuté (`oai-harvest-weekly`) |
| Avis de sécurité | **515** | 0 ERROR · 464 + 36 WARN sur les fonctions DEFINER exposées · 15 INFO RLS sans policy |
| Avis de performance | **256** | 170 index inutilisés · 38 clés étrangères non indexées · 24 policies permissives · 9 `auth_rls_initplan` |
| Schémas de rebut | **2** | `backup_2026_05_07` (6 tables vides) et `conv_backup` (7 tables de revue humaine) |

### Fonctions Edge

| | | |
|---|---:|---|
| Déployées et actives | **48** | toutes redéployées en bloc le 28/08 à 02h24 |
| Dossiers au dépôt | **49** | + `_shared` ; la 49ᵉ est le routeur `main`, **jamais déployé sur Supabase, et c'est voulu** |
| Déclarations `verify_jwt` | **31** | **toutes à `false`** ; 18 fonctions déployées ne sont pas déclarées du tout (item **B6**) |

### Catalogue

| | | |
|---|---:|---|
| Notices | **2 676** | 2 741 exemplaires, 2 495 œuvres, 1 305 autorités |
| Brouillons de catalogage | **2 237** | 5 671 insertions cumulées, 310 en file de revue |
| Indexation matière | **1 127 / 2 676** | 42 % des notices ; 1 284 affectations sur 89 sujets locaux |
| Thésaurus FICEDL | **462** | termes, **10 locales complètes** ; 98 alignements vers les sujets locaux |
| Périodiques | **4** | titres, 7 fascicules rattachés — P1→P9 livrés les 27-28/08 |

### Réseau

| | | |
|---|---:|---|
| Bibliothèques | **5** | `blmf` 248 · `btl` 2 187 · `mleg` 269 · `cira-marseille` 0 · `blmf-teste` 0 |
| Comptes | **16** | 28 appartenances actives |
| Administrateur·rices réseau | **1** | **c'est l'item A1, et il commande tout le reste** |
| Circulation vivante | **5 / 19 / 22 / 2** | emprunts / réservations / consultations / PEB — dernières écritures : 01/08 pour les emprunts, 18/06 pour le reste |

### Dépôt

| | | |
|---|---:|---|
| Commits | **2 265** | 655 depuis le v33 ; 345 sur le seul mois d'août |
| Fichiers `src/` | **280** | 38 routes, 79 pages, 89 composants |
| Clés i18n | **6 177** | × 10 locales, parité stricte vérifiée en CI |
| Tests | **171 + 43** | 171 cas JavaScript, 43 suites SQL — **6 suites ne tournent pas en CI** (item **I7**) |
| Marqueurs de dette | **17** | dont 4 dans `src/` et **aucun** n'est une vraie tâche ouverte : la dette n'est pas dans le code |

---

## Écarts relevés entre le réel et l'écrit

Voici pourquoi le v33 ne pouvait plus servir. Ces écarts ne sont pas des négligences : ils sont la trace normale d'un projet qui a livré 655 commits pendant que ses documents de pilotage restaient figés. Ce qui compte n'est pas de les déplorer, c'est de savoir qu'ils vont **dans les deux sens** — et donc qu'un document non revérifié peut aussi bien faire perdre du temps à refaire l'existant qu'à croire acquis ce qui ne l'est pas.

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

#### A1 — Obtenir au moins deux autres administrateur·rices réseau

`P0` Structurel · État : **Décision collective** · Charge : non chiffré · Ce que ça demande : délibération collective, aucune compétence technique

**État.** Vérifié en base le 29/08 : le réseau compte **un seul administrateur**. Les tables `network_administrators`, `network_administrator_cooptation_proposals` et `network_administrator_cooptation_votes` sont vides après quelques insertions historiques.

*Constat du 29/08, non revérifié depuis.*

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

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Faire tourner le runner ailleurs que sur un poste de travail personnel : machine de l'hébergeur, seconde machine du réseau, ou runner partagé. La logique de déploiement est déjà extraite dans `scripts/ci/deployer-backend.sh` et rejouable à la main — la moitié du travail est faite.

**Pourquoi ça compte.** Tant que le runner est unique et personnel, aucune procédure ne peut rendre le déploiement fiable, et personne d'autre ne peut fusionner une contribution. C'est la seconde moitié de la dépendance à une seule personne, après **A1**.

**Ce qui compte comme fini.**

- Un push sur `main` déclenche un déploiement sans que la machine du mainteneur soit allumée.
- Le garde-fou d'exclusion du routeur `main` est préservé aux deux endroits (workflow et script).
- La procédure de remise en route du runner est écrite pour quelqu'un qui ne l'a pas installé.

**Dépendances.** Lié à **I2** (bascule auto-hébergée). Peut se faire avant, sur l'infrastructure actuelle.

*Renvois : `CLAUDE.md, piège connu n°1` · `REPRISE_bascule_autohebergee_2026-08-26`*

---

### B — Base de données, sécurité, RLS

*187 tables, 664 fonctions SECURITY DEFINER, 279 policies. La surface la plus large du projet.*

| | | | |
|---|---|---|---|
| **B2** | Trier les 36 fonctions `SECURITY DEFINER` ouvertes à `anon` | `P1` | En cours |
| **B14** | Auditer les 464 fonctions `SECURITY DEFINER` ouvertes à `authenticated` | `P2` | Ouvert |
| **B4** | Examiner les quatre tables à RLS sans policy qui ne sont pas du transit | `P2` | Ouvert |
| **B5** | Résorber les neuf policies qui réévaluent `auth.*()` par ligne | `P2` | Ouvert |
| **B7** | Départager les homonymes de fonctions entre `ingest` et `public` | `P2` | Ouvert |
| **B9** | Purger le schéma `backup_2026_05_07` | `P2` | Ouvert |
| **B10** | Hygiène de performance : 170 index inutilisés, 38 clés étrangères non indexées, 24 policies permissives en double | `P3` | Ouvert |
| **B11** | Comprendre `user_wishlist` : une ligne vivante pour 9 092 insertions | `P3` | Ouvert |
| **B13** | Décider du sort des 221 migrations : squash ou pas | `P3` | Ouvert |
| **B17** | L'avertissement qui devait rendre visibles les actions d'un administrateur réseau n'existe pas | `P1` | En cours |

#### B2 — Trier les 36 fonctions `SECURITY DEFINER` ouvertes à `anon`

`P1` Prioritaire · État : **En cours** · Charge : quelques jours · Ce que ça demande : SQL / PostgreSQL

**État.** **Lots 1 et 2 livrés le 30/08** — migration `20260830181207_un_grant_que_la_fonction_contredit`, tests `T8`/`T9` dans `grants_herites_tests.sql`, CI verte, déployé. Le compteur de l'advisor est passé de **500 à 497** : trois exactement, comme annoncé. Restent les lots 3 et 4.

Complété le 30/08. Le Security Advisor de Supabase affiche **500 avertissements** ; l'export CSV le dit : ce sont **deux lints et rien d'autre** — `anon_security_definer_function_executable` (0028) et `authenticated_security_definer_function_executable` (0029). Compté en production : **36** fonctions exécutables par `anon`, **464** par `authenticated`, total exactement 500.

**Ce ne sont pas 36 décisions.** Le schéma `public` porte, depuis le socle Supabase :

```sql
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT ALL ON FUNCTIONS TO anon, authenticated, service_role;
```

Les 621 fonctions de `public` appartiennent toutes à `postgres`. **Toute fonction créée dans `public` naît donc exécutable par `anon`**, sans qu'aucune migration ne l'ait demandé. Ce défaut figure dans le baseline (`20260510000000_baseline_live.sql`), donc la CI le rejoue à l'identique : ce n'est pas une dérive de production.

La contre-preuve est dans le dépôt : **141 lignes `REVOKE … anon`** réparties dans les migrations, et trois lots de durcissement en masse les 17, 19 et 20/08. Le projet corrige ce défaut une fonction à la fois depuis des mois. Il en reste 79 ouvertes à `anon` dans `public` (33 en `SECURITY DEFINER`, 46 en `SECURITY INVOKER`, où la RLS s'applique encore), plus 3 dans `api`.

Relues une par une, les 36 se répartissent en trois groupes très inégaux :

1. **Cinq intouchables.** `user_can_act_as_staff_on_library`, `fn_library_visible_to_caller`, `user_can_engage_library`, `fn_caller_is_network_admin`, `fn_caller_is_library_staff` sont appelées par **107 policies RLS, dont 39 évaluées par `anon`**. Leur retirer `EXECUTE` ne ferme rien : cela fait échouer la lecture publique avec `permission denied for function`.
2. **Une vingtaine d'usages anonymes réels** : catalogue public (`api.search_catalog_v1`, `api.audio_tracklist_public`, `api.subject_related_v1`), les quatre lecteurs de mode, le moissonnage OAI, le parcours de candidature d'une bibliothèque par jeton.
3. **Trois grants que la fonction elle-même contredit** : `search_authors_by_name`, `search_publishers_by_name` et `remove_library_regulation_document` **refusent `anon` dans leur propre corps** (`RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.'`, `'authentication required'`).

**Lot 3 livré le 31/08 — la cause est retournée.** `ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM anon` : une fonction créée dans `public` **naît désormais fermée à `anon`**. Aucune des 621 existantes n'a bougé.

**Deux vérifications faites avant d'écrire ont corrigé le constat.** *(a)* `pg_default_acl` porte **deux** entrées sur les fonctions de `public` — une pour `postgres`, une pour `supabase_admin`. Nos migrations tournent en `postgres` et les fonctions lui appartiennent : c'est celle-là qui décide ; l'autre est hors de notre portée et ne s'appliquerait qu'à une fonction créée par `supabase_admin`, ce que le dépôt ne fait jamais. *(b)* **Aucune des 621 fonctions n'a d'ACL nulle**, et c'est ce qui rend l'opération sûre : dès qu'une entrée `pg_default_acl` existe, elle **remplace** le défaut natif de PostgreSQL — lequel accorde `EXECUTE` à `PUBLIC`. Retirer `anon` ne fait donc pas retomber sur `PUBLIC`.

**Le piège, nommé pour qu'il ne se retrouve pas :** ne jamais révoquer *tous* les rôles du défaut. Une entrée devenue vide est **supprimée** par Postgres, et le défaut natif `PUBLIC=X` reprend — on croirait fermer et on ouvrirait à tout le monde. `postgres`, `authenticated` et `service_role` restent pour que la ligne survive. Le même piège attend **B14**.

**Ce qui change pour la suite** : une fonction servant une page publique doit porter un `GRANT EXECUTE … TO anon` explicite (`DOC-OBJ-2`, corollaire). Une ligne oubliée casse la page avec `permission denied for function` — visible et réparable, jamais silencieux. Gardé par le `T11` de `grants_herites_tests.sql`, dans les deux sens.

*Vérifié : 31/08 — lots 1, 2 et 3 livrés et vérifiés en base ; `pg_default_acl` relevé avant écriture (deux entrées, pas une), et l'absence d'ACL nulle sur les 621 fonctions vérifiée pour s'assurer que la fermeture ne retombe pas sur `PUBLIC`. Reste le tri des fonctions ouvertes à `authenticated`, qui est l'item **B14**.*

**Ce que c'est.** La règle, corrigée par ce relevé : **est ouvert à `anon` ce qui sert une page publique, ou ce qu'une policy évaluée par `anon` appelle. Rien d'autre — et surtout pas par défaut.**

Quatre lots, dans cet ordre :

1. `REVOKE EXECUTE … FROM anon` sur les trois grants que la fonction contredit. Aucun changement de comportement : elles refusaient déjà.
2. Un `COMMENT ON FUNCTION` sur les cinq intouchables, qui dit *pourquoi* et cite le décompte de policies daté. Sans lui, la prochaine lecture du tableau de bord refera ce travail — ou fera le revoke.
3. **Retourner le défaut du schéma** : `ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM anon;`. Ne change rien aux 621 fonctions existantes — seulement aux suivantes. À partir de là, ouvrir à `anon` est un acte écrit, et une ouverture oubliée casse une page publique de façon visible au lieu d'exposer une fonction en silence. C'est une décision de doctrine : elle demande une entrée au `REGISTRE_decisions`, pas seulement une migration. **Et elle a une limite connue** : le chapeau de `grants_herites_tests.sql` la note depuis le 29/08 pour les tables — le défaut posé par `supabase_admin` n'est pas modifiable depuis une migration. Celui de `postgres` l'est, et c'est celui qui s'applique aux fonctions créées par les migrations ; mais la plateforme peut le reposer. D'où le dernier critère de fin : une suite, pas seulement un `ALTER`.
4. Passer les ~28 restantes au crible de la question d'audit du 18/05 : *que renvoie-t-elle, à partir de quel paramètre, et qu'est-ce qui interdit à un tiers non connecté de le demander ?*

**Avant tout `REVOKE` nominatif, vérifier :**
```sql
SELECT c.relname, p.polname, p.polroles::regrole[]
  FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid
 WHERE coalesce(pg_get_expr(p.polqual, p.polrelid), '')
     || coalesce(pg_get_expr(p.polwithcheck, p.polrelid), '')
       LIKE '%nom_de_la_fonction%';
```

**Pourquoi ça compte.** Parce qu'un défaut permissif ne se voit jamais. Une fonction créée demain dans `public` sera exécutable par `anon` sans que personne ne l'ait décidé, et le seul endroit où cela apparaîtra est un compteur à trois chiffres sur un tableau de bord que plus personne ne lit. Les 141 `REVOKE` du dépôt sont la trace de cette lutte, menée à la main, sans jamais retourner la cause.

Et parce qu'un grant que le corps de la fonction contredit est exactement ce qui cesse d'être relu. Le jour où quelqu'un retire la garde `auth.uid() is null` de `remove_library_regulation_document` pour réparer autre chose, le grant sera toujours là — et personne ne l'aura mis ce jour-là.

**Ce qui compte comme fini.**

- Les trois grants morts sont retirés par migration ; aucune suite ne rougit.
- Les cinq intouchables portent un `COMMENT ON FUNCTION` qui nomme la raison et le décompte daté de policies.
- Le privilège par défaut de `public` ne donne plus `EXECUTE` à `anon` sur les fonctions à venir, et la décision est écrite au `REGISTRE_decisions`.
- Les ~28 restantes ont un verdict écrit dans `docs/journal/audits/`.
- Une suite SQL garde l'invariant : *aucune fonction ouverte à `anon` hors d'une liste nommée* — sur le modèle du TEST 15 de `paquetA`, qui garde déjà le partage dans les deux sens sur dix helpers.
- Le lint 0028 tombe à la taille de cette liste, et ce nombre est écrit quelque part. Un avertissement attendu n'est plus un avertissement.

**Dépendances.** Les lots 1 et 2 tiennent dans une soirée et ne dépendent de rien. Le lot 3 est une décision de doctrine — il ne se prend pas seul et se pose après le lot 4, quand on sait ce qui doit rester ouvert. Le lot 4 est une revue, par paquets de dix.

*Renvois : `PLAN_DE_MARCHE §8` · `PLAN_DE_MARCHE règle 13.3` · `AUDIT_securite_fonctions_privees_2026-05-18` · `migration 20260702103557 (durcissement advisor 0028)` · `baseline 20260510000000 lignes 61206-61220 (ALTER DEFAULT PRIVILEGES)` · `tests/sql/paquetA_profils_tests.sql TEST 13 et TEST 15`*

#### B14 — Auditer les 464 fonctions `SECURITY DEFINER` ouvertes à `authenticated`

`P2` Courant · État : **Ouvert** · Charge : plusieurs semaines · Ce que ça demande : SQL / PostgreSQL

**État.** L'autre part des 500 avertissements de l'advisor : le lint 0029, **464 fonctions** — 138 dans `api` sur 142, 326 dans `public` sur 498. L'audit du 18/05 a passé en revue une partie de `public` et fermé cinq failles réelles ; **il ne portait pas sur `api`.**

Comme pour `anon` (item **B2**), ce nombre est d'abord l'effet d'un défaut de schéma : `ALTER DEFAULT PRIVILEGES … GRANT ALL ON FUNCTIONS TO … authenticated` s'applique à toute fonction créée dans `public`. La différence est qu'ici, le défaut est **presque toujours celui qu'on veut** : la surface d'écriture de l'application est faite de RPC `SECURITY DEFINER` derrière `api`, appelées par des personnes connectées (doctrine `DOC-RPC-3`). Le nombre ne descendra pas à zéro, et ce n'est pas l'objectif. L'advisor signale une architecture qu'il ne peut pas connaître.

**Ce que le lot 3 de B2 change ici (31/08).** Le défaut du schéma a été retourné pour `anon` : une fonction créée dans `public` naît désormais fermée à ce rôle. **Rien n'a été fait pour `authenticated`, et rien ne doit l'être à l'aveugle** — c'est toute la différence entre les deux items. Fermer `authenticated` par défaut casserait la surface d'écriture de l'application, faite de RPC `SECURITY DEFINER` derrière `api` appelées par des personnes connectées : la panne serait immédiate, générale, et sans rapport avec une décision de sécurité.

**Et le piège nommé dans B2 vaut ici, en pire.** Une entrée `pg_default_acl` devenue vide est *supprimée* par PostgreSQL, et le défaut natif `PUBLIC=X` reprend la main : on croirait fermer, on ouvrirait à tout le monde. Après le lot 3, la ligne de `postgres` sur les fonctions de `public` ne porte plus que `postgres`, `authenticated` et `service_role`. **Retirer `authenticated` sans en laisser d'autres viderait la ligne** — et rendrait exécutables par n'importe qui les fonctions que le lot 3 vient de protéger pour l'avenir. Si cet item aboutit un jour à un `ALTER DEFAULT PRIVILEGES`, il devra retirer `authenticated` *et* laisser `postgres` et `service_role`, puis **vérifier que la ligne existe encore** : le bloc de vérification de la migration `20260831105114` est écrit pour être recopié.

Le travail réel de B14 n'est donc pas un `ALTER` — c'est l'audit des 138 fonctions de `api`, une par une. Le défaut n'y sera retourné, si jamais il l'est, qu'à la fin.

*Vérifié : 31/08 — relu à la lumière du lot 3 de **B2**, livré le jour même : le défaut de `public` sur les fonctions porte désormais `postgres`, `authenticated`, `service_role` — `anon` retiré, la ligne `pg_default_acl` vérifiée présente après coup. Le comptage du 30/08 (138 de `api` sur 142, 326 de `public` sur 498) n'a pas été refait ; **l'audit lui-même reste entier**.*

**Ce que c'est.** Le critère n'est pas *« est-elle `SECURITY DEFINER` ? »* — elles le sont toutes, par construction. C'est : **que peut demander une inconnue qui s'est simplement inscrite ?** Un compte `authenticated` s'obtient en trois clics ; il ne prouve l'appartenance à aucune bibliothèque.

Reprendre la question d'audit du 18/05 — *que renvoie-t-elle, à partir de quel paramètre, et qu'est-ce qui interdit à un tiers de le demander ?* — et l'appliquer aux 138 fonctions de `api` d'abord, qui sont la surface exposée par `/rest/v1/rpc/`. Chercher `auth.uid()` dans le corps ne prouve rien : les cinq failles de mai en contenaient.

Les oracles trouvés en mai avaient tous la même forme : un identifiant en paramètre, une donnée nominative en retour. Chercher cette forme en priorité.

**Pourquoi ça compte.** C'est la moitié non auditée de la surface d'API du projet. Les cinq failles trouvées dans `public` étaient des oracles — numéro vers courriel, identifiant vers nom — et rien ne dit que `api` n'en porte pas. Pour une bibliothèque militante, un oracle qui rend un nom à partir d'un numéro n'est pas un défaut technique : c'est une liste de personnes.

**Ce qui compte comme fini.**

- Les 138 fonctions de `api` ont un verdict écrit : légitime, à restreindre, ou à supprimer.
- Les fonctions à restreindre ont perdu leur `EXECUTE` par migration, après vérification qu'aucune policy ne les appelle.
- Le compte rendu vit dans `docs/journal/audits/`, au format de celui du 18/05.
- Le reste de `public` suit, par paquets.

**Dépendances.** Se fait par lots. Un lot de vingt fonctions est déjà utile. Ne commence pas avant **B2**, dont le lot 2 pose le vocabulaire des commentaires et dont le lot 3 pose le piège à ne pas répéter.

*Renvois : `PLAN_DE_MARCHE §8` · `PLAN_DE_MARCHE règle 13.3` · `AUDIT_securite_fonctions_privees_2026-05-18` · `REGISTRE_decisions DOC-RPC-3` · `item B2, lot 3` · `migration 20260831105114` · `tests/sql/grants_herites_tests.sql T11`*

#### B4 — Examiner les quatre tables à RLS sans policy qui ne sont pas du transit

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL

**État.** 15 tables ont RLS activé et zéro policy. Onze sont des tables de transit ou vides. Quatre ne le sont pas : `author_name_aliases` (**1 647 lignes**), `library_themes` (3 lignes), `library_theme_configs`, `interlibrary_loan_events`.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Pour chacune, trancher : soit l'accès passe par une RPC et l'absence de policy est correcte — l'écrire en commentaire SQL —, soit une lecture légitime est aujourd'hui impossible et il manque une policy ou une fonction.

**Pourquoi ça compte.** Une table avec RLS et sans policy est fermée à tout le monde sauf aux fonctions `DEFINER`. C'est parfois exactement ce qu'on veut, et parfois une fonctionnalité qui ne marche pas sans que personne l'ait remarqué — `author_name_aliases` porte 1 647 lignes que rien ne lit peut-être.

**Ce qui compte comme fini.**

- Les quatre tables ont un verdict écrit.
- Le contrôle de restauration du runbook liste nommément les tables sans policy attendues.

**Dépendances.** Aucune.

*Renvois : `PLAN_DE_MARCHE §8` · `MATRICE_rls_deny_all_2026-06-23`*

#### B5 — Résorber les neuf policies qui réévaluent `auth.*()` par ligne

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL

**État.** La migration `20260703203953_perf_rls_initplan_wrap_auth_calls` a traité les policies d'alors. Neuf policies écrites depuis y échappent : `book_reading_notes` (4), `book_reading_note_reports` (2), `catalog_duplicate_reports` (1), `authority_duplicate_reports` (1), `author_not_duplicate` (1).

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Envelopper les appels `auth.uid()` / `auth.jwt()` dans un sous-select, comme la migration de juillet l'a fait pour les autres.

**Pourquoi ça compte.** Sans cet enveloppement, la fonction est appelée une fois par ligne examinée. Les cinq tables concernées sont vides aujourd'hui, donc le coût est nul — et c'est précisément le bon moment pour corriger, avant que les notes de lecture servent.

**Ce qui compte comme fini.**

- Le lint `auth_rls_initplan` ne remonte plus aucun avis.
- Le patron d'enveloppement est rappelé dans le modèle de migration.

**Dépendances.** Aucune.

*Renvois : `Advisors performance, relevé du 29/08/2026`*

#### B7 — Départager les homonymes de fonctions entre `ingest` et `public`

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL

**État.** Quatre noms de fonction existent dans les deux schémas avec des signatures et des sémantiques différentes : `fn_bulk_create_book_drafts_from_run`, `fn_bulk_set_partner_catalog_editorial_decision`, `fn_set_partner_catalog_editorial_decision`, et `set_updated_at()`. Aucun doublon de signature dans un même schéma — le problème est le nom partagé.

*Vérifié : 30/08 — quatre homonymes relevés : `set_updated_at` (trivial) et trois qui touchent aux décisions éditoriales sur catalogue partenaire. Les corps n'ont pas été comparés.*

**Ce que c'est.** Vérifier laquelle des deux est appelée par le front et par les RPC, renommer celle qui ne l'est pas, ou supprimer la version morte. `set_updated_at()` est un trigger banal et peut rester.

**Pourquoi ça compte.** Un `search_path` qui change d'ordre suffit à faire appeler l'autre fonction, avec des paramètres qui ne correspondent pas. C'est une panne difficile à diagnostiquer, et le projet a déjà payé une fois pour un `search_path` mal épinglé.

**Ce qui compte comme fini.**

- Les trois fonctions métier homonymes sont départagées.
- Aucune ne dépend de l'ordre du `search_path` pour être résolue correctement.

**Dépendances.** Aucune.

*Renvois : `Relevé du 29/08/2026`*

#### B9 — Purger le schéma `backup_2026_05_07`

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL

**État.** Six tables, **toutes à zéro ligne et zéro insertion depuis leur création**, sans clé primaire, sans RLS : `emprestimos_v2`, `emprestimo_itens_v2`, `reservas_v2`, `reserva_linhas_v2`, `reserva_item_workflow_v2`, `loan_midpoint_message_log`. La décision `BG2-9` prescrit cette purge depuis juin.

*Vérifié : 30/08 — le schéma pèse 6 tables et 0,1 Mo. Ce qui le lit encore n'a pas été cherché.*

**Ce que c'est.** `DROP SCHEMA backup_2026_05_07 CASCADE` par migration, après avoir confirmé une dernière fois que les six tables sont vides.

**Pourquoi ça compte.** Six tables de sauvegarde vides polluent chaque relevé d'advisors — elles portent à elles seules six des quatorze avis « pas de clé primaire ». Et un schéma nommé `backup_` qui ne contient rien est un piège pour qui reprendra le projet.

**Ce qui compte comme fini.**

- Le schéma n'existe plus.
- `deploy/bg2-known-tables.txt` a été mis à jour dans le même mouvement.

**Dépendances.** Ne pas confondre avec `conv_backup`, qui porte des données de revue humaine et **ne se purge pas** (voir **C4**).

*Renvois : `REGISTRE §BG2 BG2-9`*

#### B10 — Hygiène de performance : 170 index inutilisés, 38 clés étrangères non indexées, 24 policies permissives en double

`P3` Différé · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : SQL / PostgreSQL

**État.** 256 avis de performance au 29/08. Les tables les plus chargées en index inutilisés sont `library_partnerships` (6), `books` (5), `membership_payments` (4). Les 24 policies permissives en double portent toutes sur le rôle `authenticated` en `SELECT`, sur des tables centrales (`books`, `authors`, `exemplares`, `subjects`, `works`).

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Trois passes distinctes, à ne pas mélanger : fusionner les paires de policies permissives ; indexer les clés étrangères qui servent réellement ; ne supprimer un index inutilisé que si l'on comprend pourquoi il avait été créé.

**Pourquoi ça compte.** À la volumétrie actuelle — 2 676 notices, 16 comptes — **rien de ceci ne se voit**. C'est un chantier de pré-montée en charge, différé à dessein depuis juillet. Le noter permet de ne pas le redécouvrir en urgence le jour où une bibliothèque arrive avec 100 000 notices.

**Ce qui compte comme fini.**

- Les 24 avis de policies en double sont résorbés — c'est la passe la plus rentable.
- Les clés étrangères des tables réellement écrites sont indexées.
- Les index supprimés le sont avec la raison écrite.

**Dépendances.** À reprendre si une bibliothèque à gros fonds rejoint le réseau.

*Renvois : `ETAT-lancement-consolide-2026-07-03 §2 item 7` · `Advisors performance du 29/08/2026`*

#### B11 — Comprendre `user_wishlist` : une ligne vivante pour 9 092 insertions

`P3` Différé · État : **Ouvert** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL

**État.** **Mesuré le 30/08 : 1 ligne vivante, 9 092 insertions, 9 082 suppressions.** Le rapport n'est donc pas une fuite d'écriture mais un **cycle** : presque tout ce qui entre ressort. Une liste d'envies dont on retire ce qu'on ajoute, à raison de neuf mille allers-retours pour une seule ligne survivante, ne ressemble pas à un usage de lectrices — le réseau n'a pas ce volume.

La question n'est donc plus « qu'est-ce qui écrit », mais **« qu'est-ce qui écrit puis efface aussitôt »** : un test rejoué en boucle, un composant qui insère à chaque rendu et nettoie derrière lui, ou un chargement de page qui bascule l'état deux fois.

*Vérifié : 30/08 — `pg_stat_user_tables` : 1 ligne vivante, 9 092 insertions, 9 082 suppressions. Ce qui écrit puis efface reste inconnu.*

**Ce que c'est.** Trouver ce qui écrit et efface : un test rejoué, un chargement de page qui insère puis annule, un composant React qui appelle la RPC à chaque rendu. Regarder `OPAC-W1`, dont la note dit « reste `WITH CHECK` ».

**Pourquoi ça compte.** Neuf mille écritures pour une ligne, ce n'est pas un usage : c'est une boucle. Elle coûte peu aujourd'hui et coûtera exactement autant par utilisatrice le jour où il y en aura cent.

**Ce qui compte comme fini.**

- La cause est identifiée et écrite.
- Si c'est une boucle du front, elle est corrigée ; si c'est un test, la ligne est retirée du constat.

**Dépendances.** Aucune.

*Renvois : `REGISTRE §18 OPAC-W1` · `Relevé du 29/08/2026`*

#### B13 — Décider du sort des 221 migrations : squash ou pas

`P3` Différé · État : **Ouvert** · Charge : plusieurs semaines · Ce que ça demande : SQL / PostgreSQL, administration système

**État.** 221 migrations appliquées, dont la première est un `baseline_live` de **2,4 Mo** — le plus gros fichier du dépôt. Le squash est marqué « décidé, non commencé » depuis le 20/08, à une époque où le compte était de 146.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Soit reconstruire un `baseline` à partir du schéma courant et archiver les migrations antérieures, soit assumer la chaîne longue et documenter pourquoi. Le rejeu complet prend aujourd'hui environ 25 minutes, mesuré.

**Pourquoi ça compte.** Le risque du squash est entier : il réécrit la seule trace ordonnée de ce qui a été fait, et le harnais de tests SQL rejoue toute la chaîne à chaque fois. Ne pas le faire coûte du temps de CI ; le faire mal coûte la capacité à reconstruire. **Ne pas s'y engager avant que A2 ait réussi au moins une fois.**

**Ce qui compte comme fini.**

- Une décision écrite au REGISTRE, dans un sens ou dans l'autre.
- Si squash : la reconstruction depuis le nouveau baseline a été éprouvée sur une machine tierce.

**Dépendances.** **Bloqué par A2.** Ne pas commencer avant.

*Renvois : `ETAT-AVANCEMENT-multisessions` · `docs/schema/baseline_schema_2026-06-11.sql`*

#### B17 — L'avertissement qui devait rendre visibles les actions d'un administrateur réseau n'existe pas

`P1` Prioritaire · État : **En cours** · Charge : quelques jours · Ce que ça demande : Deno / TypeScript, i18n

**État.** **Trouvé le 31/08 en instruisant B12, et le constat était faux par excès.** La spec `spec-administrateur-reseau-v0.4` §6.3 l'écrit : « *Si action critique → INSERT dans outbox d'event `network.cross_library_critical_action` → **mail immédiat aux coordenadores actifs de la biblio*** ». Ce mail-là n'est jamais parti. Le déclencheur SQL fonctionne — quatre lignes en file, la dernière du **30/08/2026** — mais `_shared/domain/network.ts` connaissait onze events `network.*` et pas celui-là : il tombait dans le `else` final, marqué `skipped`.

**Ce qui manquait au constat, trouvé le soir même.** Le dispositif a **deux étages**, et l'autre marche. `notify-cross-library-digest`, écrite le 17/08, envoie chaque lundi à 8 h 30 le récapitulatif hebdomadaire des actions inter-bibliothèques — **aux mêmes destinataires** (les coordenador·es actif·ves de chaque biblio touchée), dans leur langue, avec des libellés humains pour les dix types d'action. Le cron a tourné le 31/08 à 8 h 30 comme les lundis précédents.

Le premier relevé ne l'avait pas vue parce qu'il cherchait le **nom de l'event** : le récapitulatif ne lit pas l'outbox, il lit la table de journal `network_admin_cross_library_actions_log`. Aucun `grep` sur `cross_library_critical_action` ne pouvait le trouver — d'où `DOC-RECENS-1`.

**Le manque réel n'était donc pas la visibilité, mais le délai** : jusqu'à sept jours entre une action décidée du dehors et le moment où la bibliothèque l'apprend. Pour une promotion, l'attente est tenable ; pour `team_suspend_member` ou `team_request_remove_member`, elle ne l'est pas.

**Et l'en-tête de `notify-cross-library-digest` affirmait depuis le 17/08 que l'étage immédiat fonctionnait.** Un commentaire qui décrit un mécanisme absent est exactement ce qui fait qu'on ne le cherche pas.

**Livré le 31/08.** `_shared/domain/cross_library.ts` (handler, destinataires = coordenador·es actif·ves hors acteur·rice, identité d'expéditeur *réseau* et non *bibliothèque*), branché dans `handleNetworkEvent`. Les libellés des dix actions et six objets **ne sont pas réécrits** : le fichier de chaînes du récapitulatif a quitté `notify-cross-library-digest/` pour `_shared/i18n/cross-library-strings.ts`, lu par les deux étages — trois nouvelles clés × dix locales au lieu de cent vingt, et surtout aucune divergence possible entre ce que les deux étages appellent le même geste. Le qualifiant « proposition, N ratifications requises — rien n'est encore fait » est partagé lui aussi.

**Neuf types d'action, pas sept.** `fn_is_critical_action_type()` en énumère sept ; deux RPC de réattribution d'ouvrage passent `p_is_critical := true` en dur. Les dix libellés couvrent les neuf.

**Éprouvé le 31/08 à 15 h 23 : le courriel est parti et il a été lu.** La ligne `#72` rejouée, `notify-event` a répondu `200` avec `recipients_count: 3` et trois `ok: true` — les trois coordenador·es actif·ves de la Terra Livre. Le message reçu porte l'identité **AnarBib**, pas celle de la bibliothèque (à comparer avec l'invitation à endosser de la veille, qui porte le logo de la Terra Livre : la distinction se voit à l'œil nu, et c'est tout l'objet). Il dit *« Promoção ao papel de coordenação (proposta, 2 ratificação(ões) necessária(s) — nada feito ainda) »* : le qualifiant partagé avec le récapitulatif fait son travail, l'avertissement n'annonce pas un fait accompli. La ligne est passée à `sent`, `sent_at` rempli, `skip_reason` revenu à `NULL`.

**Deux choses vues en éprouvant, qui ne sont pas dans le code.**

*(a)* **Un recouvrement partiel, pour ce seul type d'action.** La destinataire a reçu le même jour le récapitulatif hebdomadaire à 10 h 30 et l'avertissement immédiat à 15 h 23, tous deux sur la même promotion — plus, la veille, l'invitation à endosser, qui nommait déjà Xavier comme proposeur. C'est un artefact du rejeu (en régime normal l'immédiat précède le lundi de plusieurs jours), mais il montre que pour `team_promote_to_coordenador` **trois canaux parlent du même geste**. Les six autres types critiques n'en ont qu'un : `team_suspend_member`, `team_request_remove_member`, `update_library`, les deux réattributions d'ouvrage et les changements de politique n'envoient rien à personne avant le lundi. **C'est là que l'étage immédiat gagne ses sept jours** — et c'est là qu'il faudra l'éprouver ensuite. Question ouverte, une occurrence ne suffit pas à trancher : faut-il taire l'immédiat quand une invitation a déjà été émise pour la même entité ? Relève d'`OPS-8`, pas d'un correctif.

*(b)* **Le courriel a été trouvé dans la corbeille** de la boîte Hotmail destinataire. Peut-être un geste de la personne, peut-être un classement automatique. À vérifier avant de compter sur ce canal pour une alerte de gouvernance : un avertissement qui arrive dans la corbeille est un avertissement qui n'arrive pas. **C'est un item à ouvrir, pas une retouche de B17.**

*Vérifié : 31/08 — instruit, **corrigé**, livré et **éprouvé en envoi réel le jour même**. Cinq sources : la base (4 lignes en file ; `#72` passée à `sent` à 15 h 23 h 35, `skip_reason` à `NULL`), la réponse HTTP de `notify-event` (`200`, `recipients_count: 3`, trois `ok: true`), **le courriel reçu et relu** (identité réseau, qualifiant de proposition correct), le code (aucune branche pour cet event avant ce jour ; un récapitulatif hebdomadaire qui sert les mêmes destinataires depuis le 17/08), et le déclencheur `trg_team_outbox_dispatch`, `AFTER INSERT` sans rejeu. **Reste à éprouver sur un type d'action sans autre canal.***

**Ce que c'est.** **Il reste une chose, et une seule** : éprouver sur un type d'action qui n'a pas d'autre canal. La promotion collégiale en a trois ; une suspension n'en a aucun avant le lundi. Tant que l'étage immédiat n'a été vu qu'au seul endroit où il fait doublon, on n'a pas éprouvé ce pour quoi il a été écrit.

**Les trois lignes de juin ne sont pas retouchées.** Leur `skip_reason` dit `unknown_network_event`, et c'est exact : ce jour-là, l'event était inconnu du handler. Le réécrire en septembre falsifierait un journal au lieu de le compléter.

**Pourquoi ça compte.** Un pouvoir transverse sans trace visible par celles qui le subissent n'est pas un pouvoir contrôlé. La spec l'avait compris et l'avait écrit ; le code ne l'a jamais fait. À Bologne, c'est exactement le genre d'écart qu'on ne peut pas présenter comme acquis.

**Ce qui compte comme fini.**

- [object Object]
- [object Object]
- [object Object]
- [object Object]
- [object Object]
- [object Object]

**Dépendances.** Éclairé par **B12** (la raison du saut est écrite). Résonne avec **A1** : un seul administrateur réseau, donc un seul émetteur possible de ces actions. Partage son vocabulaire avec le récapitulatif hebdomadaire, ce qui **allège F6** d'un fichier au lieu de l'alourdir.

*Renvois : `docs/specs/spec-administrateur-reseau-v0.4.md §6.3` · `supabase/functions/_shared/domain/cross_library.ts` · `supabase/functions/_shared/i18n/cross-library-strings.ts` · `supabase/functions/notify-cross-library-digest/` · `public.team_notification_outbox lignes 56, 58, 61, 72` · `public.fn_is_critical_action_type` · `REGISTRE DOC-RECENS-1` · `item B12` · `item F6`*

---

### C — Catalogage et données documentaires

*La dette ici n'est pas du code : ce sont des fiches à relire une par une.*

| | | | |
|---|---|---|---|
| **C1** | Faire entrer les 35 sujets SOLIDAIRES dans les migrations | `P1` | Ouvert |
| **C2** | Importer le fonds SOLIDAIRES par l'outil d'import, et consigner ce qui casse | `P1` | Bloqué |
| **C3** | Mener la revue humaine des autorités : patronymes, casse, titres | `P1` | Ouvert |
| **C4** | Renseigner les pays manquants sur 722 fiches d'autorité | `P2` | Ouvert |
| **C5** | Trancher le sort du champ libre `books.autor` | `P2` | Décision collective |
| **C6** | Livrer les trois assistances de saisie prévues par la spec des conventions | `P2` | Ouvert |
| **C7** | Indexer par matière les 1 549 notices qui n'ont aucun sujet | `P2` | Ouvert |
| **C8** | Enrichir les autorités : dates, identifiants externes, formes variantes | `P3` | Ouvert |
| **C9** | Fermer les huit questions ouvertes des conventions catalographiques | `P2` | Décision collective |
| **C10** | Renommer l'une des deux colonnes `rights_status` | `P2` | Ouvert |

#### C1 — Faire entrer les 35 sujets SOLIDAIRES dans les migrations

`P1` Prioritaire · État : **Ouvert** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL, bibliothéconomie

**État.** Vérifié le 29/08 : **35 sujets ont été créés en base le 27/08** et les alignements FICEDL sont passés de 51 à **98**. Mais `docs/drafts/20260828_sujets_solidaires_ficedl.sql` est toujours dans `docs/drafts/`, hors de `supabase/migrations/`. Une instance neuve n'aura donc pas ces sujets.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Comparer le contenu du brouillon à l'état réel de la base, en faire une migration idempotente qui ne recrée pas ce qui existe, et la ranger dans `supabase/migrations/`. Ou décider que ces sujets sont propres à une bibliothèque et n'ont pas à embarquer — mais l'écrire.

**Pourquoi ça compte.** C'est exactement la question tranchée le 26/08 pour le thésaurus FICEDL : le vocabulaire fédéral embarque, les sujets locaux et leur alignement n'embarquent pas, parce que ce sont le fonds et l'acte de chaque collectif. Si cette règle vaut ici, il faut le dire ; sinon, la migration manque. Dans les deux cas, l'écart entre `docs/drafts/` et la base est une dette de traçabilité.

**Ce qui compte comme fini.**

- `docs/drafts/20260828_sujets_solidaires_ficedl.sql` a disparu : soit devenu migration, soit archivé avec la raison.
- Le compte de contrôle est écrit : 89 sujets, 98 alignements au 29/08.
- Rappel : `subject_ficedl_links.match_type` n'accepte que `exact` et `close` — il n'y a pas de `broad`.

**Dépendances.** Lié à **C2** (import du fonds SOLIDAIRES).

*Renvois : `REPRISE_claude_code_2026-08-27 chantier 2` · `REGISTRE §30 THES`*

#### C2 — Importer le fonds SOLIDAIRES par l'outil d'import, et consigner ce qui casse

`P1` Prioritaire · État : **Bloqué** · Charge : quelques jours · Ce que ça demande : bibliothéconomie, SQL / PostgreSQL

**État.** 1 685 notices dans `SOLIDAIRES_import_test.csv`. Les en-têtes suivent `spec-catalogacao-fiche-et-paliers` et **n'ont jamais été confrontés à l'importeur**. **Décision de Xavier, 29/08 : l'import ne se fera que si la candidature de SOLIDAIRES est acceptée par plusieurs administrateur·rices réseau.** L'échéance de fin août tombe donc, et l'ordre des deux chantiers s'inverse par rapport aux notes d'août : l'admission d'abord, l'import ensuite.

*Constat du 29/08, non revérifié depuis.*

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

*Constat du 29/08, non revérifié depuis.*

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

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Renseigner `country` par lots, à partir des notices, des sources externes déjà branchées (Wikidata, VIAF) et de la connaissance du fonds. Puis rejouer la détection des patronymes.

**Pourquoi ça compte.** C'est le prérequis dur de toute la chaîne de conventions : `CONV-7` fait de `country` en ISO 3166-1 α-2 une condition, et `CONV-3` fait piloter la casse par la langue. Un catalogue à 55 % sans pays applique ses propres règles à moitié.

**Ce qui compte comme fini.**

- La proportion de fiches sans `country` est descendue sous 20 %.
- La détection des doubles patronymes a été rejouée et la nouvelle liste est passée en revue humaine.

**Dépendances.** Prérequis de la seconde passe de **C3**.

*Renvois : `AUDIT_conventions_catalographiques_2026-08-20 A5` · `REGISTRE §37 CONV-7`*

#### C5 — Trancher le sort du champ libre `books.autor`

`P2` Courant · État : **Décision collective** · Charge : une soirée · Ce que ça demande : bibliothéconomie, SQL / PostgreSQL

**État.** `CONV-O3` est ouvert : déprécier `books.autor` maintenant, ou à l'Atelier ? Le champ coexiste avec la table `authors` et porte les mêmes défauts **en pire** — on y trouve `identificado, Não`, `REICH, Hilhem`, `Rosamund Bartlett (Org.)`. L'audit du 20/08 l'a explicitement laissé hors périmètre : sa dette n'est pas chiffrée.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** D'abord chiffrer : combien de notices ont un `autor` sans contributeur lié, et à quoi ressemble le contenu. Puis trancher : dépréciation immédiate avec migration des valeurs récupérables, ou conservation comme forme transcrite au sens de `P3` des périodiques.

**Pourquoi ça compte.** Deux vérités concurrentes sur l'auteur d'un livre, c'est le contraire de `DOC-CONV-1` (« une seule vérité en base, plusieurs rendus »). Tant que le champ vit, chaque écran doit choisir lequel afficher, et les deux divergent.

**Ce qui compte comme fini.**

- La dette est chiffrée.
- Une décision est inscrite au REGISTRE, dans un sens ou dans l'autre.
- Si dépréciation : le champ n'est plus écrit par aucun formulaire.

**Dépendances.** Renvoie à `INV-4`.

*Renvois : `REGISTRE §37 CONV-O3` · `AUDIT_conventions_catalographiques_2026-08-20`*

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

*Constat du 29/08, non revérifié depuis.*

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

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Passes d'enrichissement par les sources déjà branchées, avec relecture. Les pseudonymes militants sont un cas à part : l'entrée se fait à la forme la plus connue du mouvement, avec renvoi depuis le nom civil, **jamais l'inverse**.

**Pourquoi ça compte.** Les identifiants externes sont ce qui permettra à un autre catalogue de reconnaître nos autorités sans les redécrire. Les formes variantes sont ce qui permet de trouver quelqu'un sous le nom qu'on connaît. Et pour un pseudonyme militant, la forme d'usage **porte souvent la seule trace d'une répression** : elle ne s'écrase pas.

**Ce qui compte comme fini.**

- La couverture en identifiants externes dépasse 20 % sur les autorités les plus citées.
- Aucun pseudonyme militant n'a été remplacé par un nom civil.

**Dépendances.** Après **C4** (les pays aident les alignements).

*Renvois : `AUDIT_conventions_catalographiques_2026-08-20 A7-A9` · `REGISTRE §12 CAT-D6`*

#### C9 — Fermer les huit questions ouvertes des conventions catalographiques

`P2` Courant · État : **Décision collective** · Charge : une soirée · Ce que ça demande : bibliothéconomie

**État.** `CONV-6` reste « à confirmer » et `CONV-O1` à `CONV-O8` sont ouverts. Deux d'entre eux portent du travail chiffré : `CONV-O7` (le type d'autorité existe mais reste illisible par le SQL — **16 verdicts de collectivités restent à poser**) et `CONV-O8` (la scission d'autorité n'existe pas — **3 découpages restent**).

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Trancher les huit en une session, en s'aidant du fonds réel : `name_lang` distinct de `country` ou non, conventions des collectivités, sort de `books.autor` (voir **C5**), critère de bascule EDTF, périmètre de l'écran de vérification, et les deux lots manuels.

**Pourquoi ça compte.** La colonne `name_lang` a été créée nullable et sans contrainte validée : **la créer n'engage rien, l'utiliser oui**. Tant que la question reste ouverte, chaque nouvelle règle d'entrée doit se demander sur quoi elle s'appuie.

**Ce qui compte comme fini.**

- Les huit ont un verdict au REGISTRE.
- Les 16 collectivités et les 3 découpages sont traités à la main — ils sont explicitement **non automatisables**.

**Dépendances.** Éclaire **C6**.

*Renvois : `REGISTRE §37 CONV-6, CONV-O1..O8`*

#### C10 — Renommer l'une des deux colonnes `rights_status`

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL

**État.** `digital_assets.rights_status` est un **état de workflow** (`to_review`, `public_domain_confirmed`) qui commande la visibilité. Le vocabulaire des droits d'auteur porte le même nom depuis la migration `20260820235000_vocabulaire_rights_status`. Deux sens, un nom.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Renommer la colonne de workflow — `review_state` par exemple — et propager au front et aux RPC. Le vocabulaire des droits garde le nom, puisque c'est lui qui parle de droits.

**Pourquoi ça compte.** Confusion garantie sinon, et sur un sujet où la confusion se paie : c'est l'état des droits qui décide si un document est visible du public. Un piège documenté s'y ajoute — `access_scope` vaut `conta_ativa` **par défaut**, si bien qu'un document du domaine public reste réservé aux comptes actifs tant que personne n'a posé `publico` explicitement.

**Ce qui compte comme fini.**

- Les deux notions portent deux noms distincts, en base et à l'écran.
- Le piège `access_scope` est rappelé dans le formulaire de catalogage, pas seulement dans une note.

**Dépendances.** Aucune.

*Renvois : `PLAN_DE_MARCHE §8` · `DECISION_profil_numerisation_2026-08-20`*

---

### D — Périodiques, éphémères, ressources numériques

*Ce que la bibliothéconomie du livre ne sait pas décrire, et qui fait une part énorme de nos fonds.*

| | | | |
|---|---|---|---|
| **D1** | Réviser la spec des périodiques contre ce qui a été livré | `P1` | À vérifier |
| **D2** | Trancher les cinq questions restées ouvertes sur les périodiques | `P2` | Décision collective |
| **D3** | Rattacher les 91 fascicules et les 87 monographies suspectes de SOLIDAIRES | `P2` | Bloqué |
| **D4** | Le matériel éphémère : tracts, affiches, autocollants, zines | `P1` | Ouvert |
| **D5** | Éprouver la chaîne de numérisation sur dix ouvrages avant d'équiper qui que ce soit | `P2` | Ouvert |
| **D6** | Reprendre ou remplacer le lecteur EPUB | `P3` | Ouvert |

#### D1 — Réviser la spec des périodiques contre ce qui a été livré

`P1` Prioritaire · État : **À vérifier** · Charge : une soirée · Ce que ça demande : bibliothéconomie, SQL / PostgreSQL

**État.** `spec-periodiques-v0.1` (27/08) annonce « neuf paquets à livrer ». **Les neuf ont été livrés les 27 et 28/08**, en une journée : `serials`, RPC, anti-faux-doublons, état de collection, entrée dans l'Atelier, reprise des notices existantes, UI de catalogage, page publique, et les libellés dans les dix langues. La base porte 4 titres et 7 fascicules rattachés.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Relire la spec, marquer les neuf paquets comme livrés, puis vérifier une par une les six gardes annoncées — anti-cycle de filiation borné à 20 sauts, réciprocité prédécesseur/successeur par trigger, interdiction de `serial_id` sur un non-fascicule, symétrie de l'importeur face à la colonne générée, fusion des états de collection sans écrasement, ordre de tri.

**Pourquoi ça compte.** Une spec qui dit « à livrer » sur du code livré fait exactement le dégât inverse d'une spec en retard : elle fait refaire. Et les six gardes sont ce qui distingue un sous-système qui tient d'un sous-système qui casse au premier import de masse.

**Ce qui compte comme fini.**

- La spec passe en v1.0 et décrit l'état livré.
- Les six gardes sont vérifiées en base, avec le résultat écrit.
- La garde `G2` (réciprocité) est bien un trigger : « la discipline ne survit pas à six mois ».

**Dépendances.** Prérequis de **D2**.

*Renvois : `spec-periodiques-v0.1 §11 §14` · `Migrations 20260827163000 à 20260827210000`*

#### D2 — Trancher les cinq questions restées ouvertes sur les périodiques

`P2` Courant · État : **Décision collective** · Charge : une soirée · Ce que ça demande : bibliothéconomie

**État.** Cinq arbitrages étaient laissés en attente dans la spec, avec un penchant écrit pour chacun : vocabulaire de `periodicidade` libre ou fermé ; filiation n-n ou deux liens simples ; `serials` doit-elle porter un `library_id` ; promotion automatique d'un titre proposé ; page publique dédiée ou facette.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Les trancher sur des cas réels plutôt que dans l'abstrait — le fonds Anarchief (une centaine de titres depuis 1860) et le fonds SOLIDAIRES (12 titres, 91 fascicules) sont la matière à éprouver.

**Pourquoi ça compte.** Deux des cinq sont déjà tranchés de fait par le code livré (page dédiée `/periodico/<slug>`, pas de `library_id`). Les laisser « ouverts » au REGISTRE alors que le code a choisi crée exactement le genre d'écart que ce backlog corrige.

**Ce qui compte comme fini.**

- Les cinq ont un verdict inscrit, en accord avec le code livré ou en le corrigeant.
- La promotion d'un titre reste **un geste et non un seuil** — c'était le penchant, et il vaut d'être confirmé.

**Dépendances.** Après **D1**.

*Renvois : `spec-periodiques-v0.1 §13`*

#### D3 — Rattacher les 91 fascicules et les 87 monographies suspectes de SOLIDAIRES

`P2` Courant · État : **Bloqué** · Charge : quelques jours · Ce que ça demande : bibliothéconomie

**État.** Le fichier SOLIDAIRES porte déjà des colonnes `revue` et `numero` : **12 titres à créer, 91 fascicules à lier**. En plus, **87 monographies portent « n° » dans leur titre** et sont marquées par un drapeau `numero_dans_titre` : ce sont des candidates au rattachement.

*Constat du 29/08, non revérifié depuis.*

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

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Évaluer ce qui casse aujourd'hui, ce qui cassera avec les navigateurs à venir, et s'il existe une alternative libre maintenue. Décider entre épingler et assumer, ou remplacer.

**Pourquoi ça compte.** Le lecteur est ce qui rend un fonds numérisé consultable sans téléchargement. S'il tombe, ce n'est pas un confort qui disparaît, c'est l'accès. Rien ne presse aujourd'hui — mais il vaut mieux savoir.

**Ce qui compte comme fini.**

- Un verdict écrit : conserver et épingler, ou remplacer par quoi.
- Si conservation : un test qui vérifie l'ouverture d'un EPUB réel.

**Dépendances.** Aucune.

*Renvois : `package.json` · `Relevé du 29/08/2026`*

---

### E — Front, OPAC, i18n, accessibilité

*10 locales à parité stricte, 6 177 clés chacune, vérifiées en intégration continue.*

| | | | |
|---|---|---|---|
| **E1** | Faire auditer l'accessibilité par quelqu'un qui n'a pas écrit le code | `P1` | Ouvert |
| **E2** | Trancher les conventions néerlandaise et grecque | `P1` | Ouvert |
| **E3** | Uniformiser le registre d'adresse entre les dix locales | `P2` | Décision collective |
| **E4** | Régler les paires irrégulières de l'italien | `P2` | Ouvert |
| **E5** | Relayer les tuiles OpenStreetMap par le serveur | `P2` | Ouvert |
| **E6** | Découper les cinq écrans qui pèsent plus de cent kilooctets | `P2` | Ouvert |
| **E7** | Corriger le titre de page qui ne suit pas la navigation | `P2` | Ouvert |
| **E8** | Charger les deux polices sans bloquer l'affichage | `P2` | Ouvert |
| **E9** | Finir la mise en page mobile : trois lots identifiés | `P2` | Ouvert |
| **E10** | Le reste du socle terrain : permanence mobile, notification poussée, planche de codes | `P3` | Ouvert |
| **E11** | Les deux différés assumés de l'OPAC : tags contributifs et flux RSS | `P3` | Décision collective |

#### E1 — Faire auditer l'accessibilité par quelqu'un qui n'a pas écrit le code

`P1` Prioritaire · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : aucune compétence technique, React / JavaScript

**État.** Des fonctionnalités d'accessibilité sont implémentées : panneau de réglages sur toutes les pages depuis le 26/08, `html lang` qui suit la langue affichée (WCAG 3.1.1) avec son test, champs à 16 px minimum, cibles tactiles à 44 px, `viewport-fit=cover`. **Aucun audit d'accessibilité indépendant n'a jamais été mené.**

*Constat du 29/08, non revérifié depuis.*

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

*Constat du 29/08, non revérifié depuis.*

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

#### E5 — Relayer les tuiles OpenStreetMap par le serveur

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : React / JavaScript

**État.** C'est la **seule exception anti-pistage restante** : les tuiles de `tile.openstreetmap.org` sont chargées par le navigateur de la visiteuse, qui livre donc son adresse IP à un tiers. L'intention de relayer est **déjà annoncée publiquement** dans la clé `privacy.s6.maptiles` des dix locales.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Reprendre le modèle déjà en place pour Nominatim : un relais côté serveur, avec cache, et l'adresse du relais dans la configuration du front.

**Pourquoi ça compte.** La règle de conformité du projet est écrite et générale : **toute dépendance qui reçoit une adresse IP de visiteuse doit être déclarée, y compris quand elle n'est pas un sous-traitant au sens du RGPD.** Le raisonnement inverse est précisément ce qui avait laissé Turnstile invisible pendant des mois. Ici la dépendance est déclarée — il reste à la supprimer, comme annoncé.

**Ce qui compte comme fini.**

- Aucune requête ne part du navigateur vers un domaine tiers sur les pages de carte.
- La clé `privacy.s6.maptiles` est mise à jour dans les dix locales pour décrire le nouvel état.

**Dépendances.** Plus simple après **I2** (pile auto-hébergée), mais faisable avant.

*Renvois : `VERIF_confidentialite_tiers_2026-08-20` · `PLAN_DE_MARCHE §8` · `scripts/nominatim/`*

#### E6 — Découper les cinq écrans qui pèsent plus de cent kilooctets

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : React / JavaScript

**État.** `BookDraftForm.jsx` fait **197 Ko**, `BibliotecaPage.jsx` 184 Ko, `AccountPage.jsx` 154 Ko, `PanelPage.jsx` 114 Ko, `ImportacoesPage.jsx` 109 Ko. 29 des 38 routes sont déjà en chargement paresseux, et `vite.config.js` déclare quatre lots de dépendances — le problème n'est pas le chargement initial, c'est la taille d'un fichier unique.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Extraire les sous-formulaires et les onglets en composants séparés, sans changer le comportement. Commencer par `BookDraftForm`, le plus gros et le plus édité.

**Pourquoi ça compte.** Un fichier de 197 Ko n'est pas relisible par quelqu'un qui arrive, et deux personnes ne peuvent pas y travailler en même temps sans conflit. C'est un obstacle à la contribution avant d'être un problème de performance.

**Ce qui compte comme fini.**

- Aucun fichier de `src/` ne dépasse 60 Ko.
- Le comportement est inchangé, vérifié écran par écran.
- Découpage par lots, un écran à la fois, jamais une refonte.

**Dépendances.** Reprend `#PERF-accountpage-split`, hérité du v32.

*Renvois : `AnarBib-Backlog-2026-06-17-v33 §2.5` · `Relevé du 29/08/2026`*

#### E7 — Corriger le titre de page qui ne suit pas la navigation

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : React / JavaScript

**État.** `document.title` ne se met pas à jour lors d'une navigation dans l'application ; il ne change qu'au rechargement complet de la page.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Poser le titre à chaque changement de route, à partir des clés i18n existantes.

**Pourquoi ça compte.** Le titre de page est ce que lisent les lecteurs d'écran à l'arrivée, ce qui s'inscrit dans l'historique du navigateur, et ce qui apparaît dans un onglet épinglé. Un titre figé rend les trois inutilisables.

**Ce qui compte comme fini.**

- Le titre suit la route, dans les dix langues.
- Un test le vérifie, sur le modèle de `documentLanguage.test.js`.

**Dépendances.** Complément naturel de **E1**.

*Renvois : `Mémoire de projet, dette technique`*

#### E8 — Charger les deux polices sans bloquer l'affichage

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : React / JavaScript

**État.** `titre.ttf` pèse 1 Mo et `accent.ttf` 484 Ko ; les deux sont chargées sans préchargement déclaré, sans `font-display: swap`, et sans `preconnect` vers Supabase.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Ajouter `font-display: swap`, précharger la police de titre seule, sous-ensembler les fichiers aux caractères réellement utilisés — dix langues dont le grec, donc le sous-ensemble n'est pas trivial.

**Pourquoi ça compte.** 1,5 Mo de polices sur une connexion de comptoir, c'est plusieurs secondes d'écran blanc. Le public d'AnarBib inclut des bibliothèques qui n'ont pas la fibre.

**Ce qui compte comme fini.**

- Le texte s'affiche avant les polices, avec une substitution acceptable.
- Le poids total des polices chargées à la première visite est mesuré avant et après.

**Dépendances.** Ne pas toucher à l'identité visuelle : `IDENT-1` à `IDENT-4` sont actés.

*Renvois : `Mémoire de projet, dette technique` · `REGISTRE §39 IDENT`*

#### E9 — Finir la mise en page mobile : trois lots identifiés

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : React / JavaScript

**État.** Les phases A, B et C sont livrées et la doctrine graduée est actée. Trois questions restent ouvertes au REGISTRE : `MOB-Q1` (24 grilles déclarées en ligne dans le JSX avec des pistes `fr` nues), `MOB-Q2` (20 requêtes de média héritées à rapatrier dans `src/styles/mobile.css`), `MOB-Q3` (les onglets Validações et Inventário à convertir en cartes).

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Trois passes mécaniques, dans cet ordre de valeur : les 24 grilles (`minmax(0, Nfr)` partout, c'est la règle `MOB-1`), les deux onglets en cartes selon le patron livré, puis le rapatriement des requêtes de média.

**Pourquoi ça compte.** Une piste `fr` nue déborde dès que son contenu est plus large que la colonne, et un débordement **se constate par la mesure, jamais à l'œil** (`MOB-9`). Les 24 grilles sont autant de débordements en attente d'un titre long.

**Ce qui compte comme fini.**

- Aucune grille du JSX ne porte de piste `fr` nue.
- Les deux onglets sont en cartes sous 640 px.
- Les requêtes de média héritées vivent dans `mobile.css`.

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

#### E11 — Les deux différés assumés de l'OPAC : tags contributifs et flux RSS

`P3` Différé · État : **Décision collective** · Charge : une soirée · Ce que ça demande : délibération collective, React / JavaScript

**État.** `#OPAC5` (folksonomie, tags posés par les lectrices) est bloqué sur une décision de communauté et de vie privée. `#OPAC11` (flux RSS de recherche) est différé pour raison anti-pistage. Les deux sont ouverts depuis mai et n'ont jamais été instruits.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Les instruire une bonne fois : qu'est-ce qu'un tag public révèle de qui l'a posé, et qu'est-ce qu'un flux RSS révèle de qui le suit ? Puis trancher, ou fermer.

**Pourquoi ça compte.** Un item différé sans instruction reste à l'ordre du jour de chaque relecture et coûte de l'attention à chaque fois. Fermer un item est une décision aussi valable que le livrer.

**Ce qui compte comme fini.**

- Les deux ont un verdict au REGISTRE : livré, ou fermé avec la raison.
- `OPAC-RSS1` est mis à jour en conséquence.

**Dépendances.** Aucune.

*Renvois : `REGISTRE §18 OPAC-RSS1` · `AnarBib-Backlog-2026-06-17-v33 §2.4`*

---

### F — Courriel et notifications

*13 fonctions notify-*, 5 files d'attente, 6 déclencheurs de dépêche. Personne n'a jamais audité l'ensemble.*

| | | | |
|---|---|---|---|
| **F1** | Auditer la chaîne de courriel de bout en bout | `P1` | Ouvert |
| **F2** | Corriger le gabarit des courriels d'alerte d'exploitation | `P1` | Ouvert |
| **F3** | Consolider les fonctions de notification redondantes | `P2` | Ouvert |
| **F4** | Trois bibliothèques avaient activé des rappels que personne n'envoyait | `P1` | En cours |
| **F6** | `notify-internal-task` tourne sur une copie gelée de toute la pile courriel | `P2` | Ouvert |
| **F7** | Treize secrets de fonction sont déclarés et vides, sans qu'on sache lesquels le sont exprès | `P2` | Ouvert |

#### F1 — Auditer la chaîne de courriel de bout en bout

`P1` Prioritaire · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : Deno / TypeScript, SQL / PostgreSQL

**État.** **14 fonctions `notify-*` déployées**, cinq files d'attente, six déclencheurs de dépêche. Trois files n'ont jamais reçu la moindre insertion : `authority_proposal_notification_outbox`, `membership_expiry_notifications`, `painel_internal_task_invitation_outbox`. Une quatrième, `painel_internal_task_notification_outbox`, est vide après 34 insertions dont la dernière date du 04/06. Personne n'a jamais audité l'ensemble.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Dresser la carte : pour chaque événement métier, quel déclencheur, quelle file, quelle fonction, quel gabarit, quelles dix langues. Puis marquer les branches mortes et les branches jamais empruntées.

**Pourquoi ça compte.** Une notification qui ne part pas ne fait aucun bruit. C'est le même angle mort que les sauvegardes, et il a déjà mordu deux fois : les mails `retirada_efetivada`, `retirada_reagendada`, `retirada_no_show` et `liberada_para_circulacao` ont été signalés comme ne partant pas, sans que le diagnostic soit mené à son terme.

**Ce qui compte comme fini.**

- Une carte écrite, événement par événement.
- Les quatre mails signalés comme non partants ont un verdict : corrigés, ou expliqués.
- Les branches mortes sont supprimées ou documentées comme dormantes.

**Dépendances.** Prérequis de **F2** et **F3**.

*Renvois : `Mémoire de projet, reliquats de la chaîne courriel` · `AUDITORIA_NOTIFY_FUNCTIONS_2026-05-06`*

#### F2 — Corriger le gabarit des courriels d'alerte d'exploitation

`P1` Prioritaire · État : **Ouvert** · Charge : une soirée · Ce que ça demande : Deno / TypeScript

**État.** Les courriels d'alerte d'exploitation — sauvegarde en échec, incident de sonde — utilisent le gabarit destiné aux lectrices. Ils finissent donc par « contacte la bibliothèque » suivi d'un numéro de téléphone.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Un gabarit d'exploitation distinct : pas de pied de page destiné au public, la commande à lancer, et le lien vers la section du runbook.

**Pourquoi ça compte.** **À corriger avant qu'un second administrateur réseau existe.** Aujourd'hui une seule personne reçoit ces alertes et sait les lire ; le jour où **A1** aboutit, elles partent à quelqu'un qui découvrira un courriel d'incident lui conseillant d'appeler la bibliothèque.

**Ce qui compte comme fini.**

- Un gabarit d'exploitation existe, distinct du gabarit lectrice.
- Une alerte de test a été reçue et relue par quelqu'un qui n'a pas écrit le code.

**Dépendances.** Doit précéder l'aboutissement de **A1**.

*Renvois : `RUNBOOK_exploitation_v0.3 §7` · `PLAN_DE_MARCHE §8`*

#### F3 — Consolider les fonctions de notification redondantes

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : Deno / TypeScript

**État.** Quatre fonctions font des récapitulatifs : `notify-weekly-report`, `notify-network-weekly-report`, `notify-cross-library-digest`, `notify-rede-digest`. Trois fonctions servent des documents : `read-pdf`, `read-digital-asset`, `read-ill-shared-asset`. Deux exportent des lots : `export-catalog-lote`, `export-fonds-bundle`. Et `mail-i18n-test`, fonction de test, est déployée en production en version 1553.

*Constat du 29/08, non revérifié depuis.*

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

#### F7 — Treize secrets de fonction sont déclarés et vides, sans qu'on sache lesquels le sont exprès

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : administration système

**État.** Relevé le 30/08 en vérifiant tout autre chose — que le secret des avis de tâche était bien le même des deux côtés.

`supabase secrets list` ne montre pas les valeurs mais leur **empreinte SHA-256**. Or `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` est l'empreinte de la **chaîne vide** — et treize secrets la portent :

```
ADMIN_EMAIL_NOTIFY_EVENT   ADMIN_NAME            BRAND_NAME
FOOTER_TEXT                REPLY_TO_EMAIL        REGIMENTO_URL
LIBRARY_ADMIN_EMAIL        LIBRARY_ADMIN_NAME    LIBRARY_BRAND_NAME
LIBRARY_FOOTER_TEXT        LIBRARY_LOGO_URL
BLMF_INTERNAL_REDIRECT_EMAIL   BTL_INTERNAL_REDIRECT_EMAIL
```

Dans le tableau de bord, un secret vide et un secret renseigné se ressemblent : les deux existent, les deux affichent une valeur masquée. **Seule l'empreinte les distingue.**

**Deux sont vides exprès, et c'est vérifiable :** les deux `*_INTERNAL_REDIRECT_EMAIL`. C'est ainsi que la redirection des avis internes reste inactive — le 30/08, la notification d'inscription de la BTL est bien partie à l'adresse réelle de la bibliothèque, précisément parce que ce secret est vide.

**Onze sont dans une chaîne de repli**, donc sans conséquence visible : `_shared/core/env.ts` lit `ADMIN_NAME || LIBRARY_ADMIN_NAME || ANARBIB_ADMIN_NAME || …`, et les variantes `ANARBIB_*` / `NETWORK_*` sont, elles, renseignées.

**Sauf une.** `REGIMENTO_URL` est vide, et ses deux replis — `ANARBIB_REGIMENTO_URL`, `NETWORK_REGIMENTO_URL` — **n'existent pas du tout** dans la liste. La constante vaut donc la chaîne vide, et `footerPadrao` omet purement et simplement la ligne « Regimento : ouvrir » de tous les courriels qui l'utilisent. Le lien vers le règlement de la bibliothèque n'a jamais été affiché.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** **D'abord le seul qui a une conséquence** : décider si le lien vers le règlement doit figurer au pied des courriels. Si oui, renseigner `REGIMENTO_URL` — une seule variable, et la ligne apparaît. Si non, retirer le code qui l'attend dans `footerPadrao`, plutôt que de laisser une branche morte.

**Puis le ménage** : pour chacun des douze autres, trancher entre *vide exprès* et *jamais rempli*. Les deux redirections sont clairement dans le premier cas — elles méritent un commentaire quelque part, parce qu'un secret vide qui EST le réglage est exactement le genre de chose qu'on « répare » par erreur. Les dix autres sont des doublons de chaînes de repli : s'ils ne servent à rien, les supprimer vaut mieux que les garder vides.

**Et retenir la technique**, parce qu'elle ne coûte rien : `supabase secrets list` publie un SHA-256, `sha256()` est natif côté base. Comparer un secret de fonction et un secret du vault, ou repérer les vides, se fait donc sans qu'aucune valeur ne soit lue par personne.

**Pourquoi ça compte.** Parce qu'un secret vide ne se signale pas. Il n'y a ni erreur au démarrage, ni ligne de journal : la constante vaut `""`, le repli joue ou pas, et le courriel part avec un champ en moins que personne ne remarque — c'est le cas de `REGIMENTO_URL` depuis toujours.

Et parce que l'inverse est plus dangereux encore : les deux redirections sont vides **exprès**, et c'est ce vide qui fait le réglage. Quelqu'un qui « complète les secrets manquants » sans savoir lesquels sont délibérés rebrancherait la redirection des avis d'inscription sans s'en apercevoir.

**Ce qui compte comme fini.**

- Le sort du lien « Regimento » est tranché : la variable est renseignée, ou le code qui l'attend est retiré.
- Chacun des douze autres secrets vides est classé — voulu, ou à remplir, ou à supprimer.
- Les deux redirections portent une note écrite disant que leur vide EST le réglage.
- La méthode de comparaison par empreinte est notée quelque part de retrouvable.

**Dépendances.** Aucune. Le relevé est fait et tient dans l'item ; ce qui reste demande surtout de savoir ce qu'on voulait.

*Renvois : `supabase secrets list --project-ref … (colonne DIGEST = SHA-256)` · `empreinte de la chaîne vide : e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` · `supabase/functions/_shared/core/env.ts (chaînes de repli)` · `footerPadrao — ligne « Regimento », jamais affichée`*

---

### G — Réseau, gouvernance, fédération

*Beaucoup de circuits construits, très peu empruntés. C'est le principal enseignement du relevé.*

| | | | |
|---|---|---|---|
| **G1** | Emprunter les circuits construits et jamais utilisés | `P0` | Ouvert |
| **G2** | Trancher politiquement l'écart entre P2 et P8 sur la promotion à coordenador·a | `P1` | Décision collective |
| **G3** | Éprouver le circuit de promotion collégiale sur `blmf-teste` | `P1` | Ouvert |
| **G4** | Exercer les quatre courriels d'équipe jamais envoyés | `P1` | Ouvert |
| **G5** | Ce que commande vraiment `is_test_mode` sur la Biblioteca Terra Livre | `P2` | Ouvert |
| **G6** | Donner un écran au prêt entre bibliothèques | `P2` | Ouvert |
| **G7** | Décider de l'admission de la Bibliothèque SOLIDAIRES | `P1` | Bloqué |
| **G8** | Compléter la cartographie avec les archives repérées ailleurs | `P2` | Ouvert |
| **G9** | Implémenter la cartographie du réseau selon la spec v1.0 | `P3` | Gelé |
| **G10** | Solder les trois questions d'onboarding marquées « au plus vite » | `P2` | Ouvert |

#### G1 — Emprunter les circuits construits et jamais utilisés

`P0` Structurel · État : **Ouvert** · Charge : plusieurs semaines · Ce que ça demande : délibération collective, aucune compétence technique

**État.** Vérifié le 29/08 : **62 tables métier n'ont jamais reçu la moindre insertion.** Sept blocs entiers sont concernés — assemblées du réseau (3 tables), notes de lecture (2), propositions et objections d'autorité (3), référentiels de catalogage `catalog_ref_*` (8 sur 9), gouvernance des profils de bibliothèque (4, **alors que deux crons tournent dessus toutes les quinze minutes**), délibération sur les demandes d'adhésion (5, dont `library_request_votes` et `library_request_messages`).

**Remesuré le 31/08 : toujours 62, et ce n'est pas une bonne nouvelle.** Le compte n'a pas bougé en deux jours — 62 tables de `public` sur 189 n'ont jamais reçu la moindre insertion. Mais ce n'est pas la même liste : `loan_cycle_notifications`, née ce matin avec les rappels d'échéance, y est entrée **le jour de sa création**. Un circuit livré aujourd'hui rejoint aussitôt la colonne des circuits jamais empruntés — c'est exactement le mécanisme que cet item nomme, et il continue de tourner pendant qu'on le décrit.

**Un premier livre circule.** L'emprunt **#69** a été ouvert ce matin à 11 h 43 à la BLMF — item 84, *O Anarquismo na Escola, no Teatro, na Poesia* d'Edgar Rodrigues, échéance **21/09**. Il donne au bloc *notes de lecture* sa première chance réelle : le mi-parcours calculé par `notify-loan-cycle` tombe le **10 septembre**, et l'invitation à déposer une note sous pseudonyme partira ce jour-là (item **F4**). `book_reading_notes` est encore à zéro ligne ; si elle en porte une le 11, un des sept blocs sera sorti de cette liste pour de bon — et pas parce qu'on l'aura décidé, parce que quelqu'un l'aura emprunté.

Les six autres blocs sont inchangés au 31/08, vérifiés table par table : assemblées du réseau (3), propositions et objections d'autorité (3), référentiels `catalog_ref_*` (8), gouvernance des profils de bibliothèque (4, **et les deux crons tournent toujours dessus toutes les quinze minutes**), délibération des demandes d'adhésion (5). Tous à zéro insertion.

*Vérifié : 31/08 — remesuré en production : **62 tables de `public` sur 189** à zéro insertion (`pg_stat_user_tables.n_tup_ins`, croisé avec un décompte de lignes sur les tables citées). Le compte est stable, la liste ne l'est pas — `loan_cycle_notifications` y est entrée le jour de sa naissance. Emprunt **#69** ouvert à la BLMF ; l'invitation à écrire une note de lecture est attendue le **10/09**, et c'est la première sortie possible de cette liste.*

**Ce que c'est.** Choisir un bloc et l'emprunter pour de vrai, du premier geste au dernier : tenir une assemblée du réseau, déposer une note de lecture, proposer une autorité et laisser quelqu'un objecter, faire délibérer une demande d'adhésion. Consigner ce qui manque, ce qui surprend, ce qui bloque.

**Pourquoi ça compte.** C'est le principal enseignement du relevé du 29 août, et il ne figure dans aucun document du corpus. **Le projet ne souffre pas d'un manque de fonctionnalités : il souffre d'un manque d'usage.** Un circuit jamais emprunté n'est pas livré — il est seulement écrit. Et le jour où il devient le chemin critique, comme le circuit d'invitation vient de le devenir pour les promotions, il casse sur des choses qu'un seul passage aurait révélées.

**Ce qui compte comme fini.**

- Au moins trois des sept blocs ont été empruntés de bout en bout, sur `blmf-teste` puis en réel.
- Chaque passage a produit un compte rendu écrit de ce qui manque.
- Les blocs dont l'usage n'est pas souhaité aujourd'hui sont marqués **dormants**, avec la raison — ce n'est pas un échec, c'est une information.

**Dépendances.** Le bloc « assemblée » dépend de **A1**. Les autres non.

*Renvois : `Relevé du 29/08/2026` · `REGISTRE §32 AG, §28 ATE, §26 ONBO` · `emprunt #69 (BLMF, item 84, échéance 21/09)` · `item F4` · `public.book_reading_notes`*

#### G2 — Trancher politiquement l'écart entre P2 et P8 sur la promotion à coordenador·a

`P1` Prioritaire · État : **Décision collective** · Charge : une soirée · Ce que ça demande : délibération collective

**État.** La migration `20260826120000` **est en production** et tranche dans le sens de P2 : collégialité obligatoire, ratification préalable, repli à une signature quand il n'y a qu'une seule personne coordinatrice, consentement explicite de la personne promue, exclusion de cette personne du décompte du quorum. **Mais la décision politique n'a jamais été prise.**

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Porter la question au collectif. Trois options sont écrites : ne rien changer au code et corriger le texte de P2 ; étendre le chemin A comme le code l'a fait ; ou garder la promotion directe mais la rendre visible avec un délai d'objection.

**Pourquoi ça compte.** Il y a aujourd'hui **du code en production qui anticipe une décision collective non prise**. Le rollback est écrit et testé, ce qui rend l'anticipation réversible — mais l'autre lecture, *le SIGB ne modélise pas l'assemblée générale*, reste entièrement défendable. **Ce n'est pas un arbitrage technique.**

**Ce qui compte comme fini.**

- Le collectif a tranché, et la décision est inscrite au REGISTRE.
- Le code est aligné sur la décision, ou le texte de P2 est amendé.
- Rappel : le fichier de rollback porte un tiret bas initial qui empêche la CLI de l'appliquer — **ne pas le renommer**.

**Dépendances.** Question ouverte depuis le 26/08. Bloque **G3** si la réponse est « revenir en arrière ».

*Renvois : `ECART_cosignature_promotion_coordenador_2026-08-26 §5` · `REGISTRE §41 GOUV-1`*

#### G3 — Éprouver le circuit de promotion collégiale sur `blmf-teste`

`P1` Prioritaire · État : **Ouvert** · Charge : une soirée · Ce que ça demande : délibération collective

**État.** La migration est en production ; le runbook de déploiement en onze étapes est donc caduc. Ce qui reste est la **répétition en six pas sur `blmf-teste`**, jamais faite. Or `library_team_invitations` porte **zéro ligne** depuis sa création : le circuit que la migration rend obligatoire n'a jamais été emprunté une seule fois.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Les six pas sur la bibliothèque d'essai `blmf-teste`, dont les courriels sont coupés (`email_delivery_mode = 'disabled'`). **Si un pas échoue, ne rien faire sur la BLMF.**

**Pourquoi ça compte.** Le réglage `team_admission_mode = 'cosignature'` de la BLMF **n'a jamais eu d'effet sur quoi que ce soit** : les treize promotions au rôle bibliothécaire et les cinq à la coordination sont toutes passées par la promotion directe. Le coût réel du choix retenu, écrit noir sur blanc, est que « le workflow d'invitation, jamais exercé, devient d'un coup le chemin critique ».

**Ce qui compte comme fini.**

- Les six pas sont passés sur `blmf-teste`, avec le résultat de chacun écrit.
- Une promotion réelle a emprunté le circuit sur la BLMF.
- Attention : `blmf-teste` **n'est pas une base séparée** — c'est une bibliothèque dans le même projet.

**Dépendances.** Dépend de **G2** si le collectif décide de revenir en arrière.

*Renvois : `RUNBOOK_deploiement_collegialite_coordenador_2026-08-26 étape 10` · `MIGRATION_collegialite_coordenador_2026-08-26`*

#### G4 — Exercer les quatre courriels d'équipe jamais envoyés

`P1` Prioritaire · État : **Ouvert** · Charge : une soirée · Ce que ça demande : délibération collective

**État.** Quatre courriels existent, sont câblés, et ne sont jamais passés en production : `team.self_demoted`, `team.suspended`, `team.removal_requested`, `team.inactive_warning_*`. Le mécanisme fonctionne — `team_notification_outbox` compte 21 envois et zéro échec — mais ces quatre-là n'ont jamais été déclenchés.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Provoquer chacun des quatre cas sur `blmf-teste`, lire le courriel reçu, vérifier qu'il dit ce qu'il doit dire dans les dix langues.

**Pourquoi ça compte.** Ces courriels annoncent à quelqu'un qu'il perd un rôle, qu'il est suspendu, ou qu'on demande son retrait. Ce sont les messages les plus délicats du système, et personne ne les a jamais lus tels qu'ils arrivent. Les deux personnes en formation à la coordination BLMF seront les premières concernées.

**Ce qui compte comme fini.**

- Les quatre courriels ont été reçus et relus.
- Le ton et le contenu sont validés par quelqu'un qui n'a pas écrit les gabarits.
- **D'abord sur `blmf-teste`, jamais directement sur la BLMF.**

**Dépendances.** Se fait avec **G3**, même bac à sable.

*Renvois : `VERIF_etat_reel_gouvernance_et_crons_2026-08-26 §2`*

#### G5 — Ce que commande vraiment `is_test_mode` sur la Biblioteca Terra Livre

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : délibération collective

**État.** **Vérifié le 30/08, et l'item se réduit de moitié.** Le constat reposait sur `library_commons.email_delivery_mode = 'test_only'`. Or **aucun chemin d'envoi ne lit cette colonne** : c'est le sélecteur inerte retiré le jour même côté interface. Le vrai commutateur est `library_mail_channels`, et il dit autre chose — la BTL y porte `delivery_mode = 'platform_shared'` et `active = true`. **Le courrier de la BTL part normalement, et depuis toujours.** Il n'y a donc rien à clarifier de ce côté : la bibliothèque n'était pas en mode d'essai, elle le paraissait.

Ce qui reste tient en une question : la colonne `libraries.is_test_mode`, toujours à `true` sur une bibliothèque de 2 187 exemplaires publiée au réseau. Qu'est-ce qui la lit, et qu'est-ce qu'elle change ?

*Vérifié : 30/08 — `library_mail_channels` interrogée : la BTL est à `platform_shared` / `active = true`. Ce que commande `is_test_mode` n'a pas été cherché.*

**Ce que c'est.** Chercher ce qui lit `libraries.is_test_mode` — en base et dans le front. Trois issues, et il faut trancher entre elles plutôt que de laisser le champ tel quel : ou bien la colonne commande quelque chose de réel, et il faut demander à la BTL ce qu'elle veut ; ou bien elle ne commande rien, et c'est un second sélecteur inerte à retirer (`DOC-SILENCE-1`) ; ou bien elle ne sert qu'à un filtre d'affichage, et son nom ment sur sa portée.

**Pourquoi ça compte.** En mode d'essai, les courriels ne partent pas. Une bibliothèque avec 2 187 exemplaires publiés dont les lectrices ne reçoivent aucune notification, c'est soit un choix, soit une panne silencieuse depuis des mois. La BTL a rejoint le réseau avec un statut « expérimental » assumé — mais un statut politique et un réglage technique ne sont pas la même chose.

**Ce qui compte comme fini.**

- La BTL a répondu, et la configuration correspond à sa réponse.
- Le statut est écrit là où quelqu'un le cherchera.

**Dépendances.** Aucune. Une conversation.

*Renvois : `PLAN_formation_coordination_BLMF §8`*

#### G6 — Donner un écran au prêt entre bibliothèques

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : React / JavaScript, bibliothéconomie

**État.** Le cycle de vie du prêt entre bibliothèques est spécifié et implémenté en base : machine à états verrouillée, quatre triggers, cron `anarbib-peb-detect-overdue-daily` actif. **Aucun écran n'existe.** La base porte 2 prêts pour 20 insertions historiques.

*Constat du 29/08, non revérifié depuis.*

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

*Constat du 29/08, non revérifié depuis.*

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

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Les trois se traitent ensemble parce qu'ils portent la même question : que se passe-t-il quand quelqu'un arrive, et quand quelqu'un part ?

**Pourquoi ça compte.** `ONBO-Q13` est le cas de figure d'une coordination qui change de mains. Aujourd'hui, une bibliothèque dont la personne coordinatrice disparaît n'a pas de chemin écrit. C'est exactement le risque que **A1** décrit à l'échelle du réseau, à l'échelle d'une bibliothèque cette fois.

**Ce qui compte comme fini.**

- Le transfert de mandat a un chemin écrit et éprouvé sur `blmf-teste`.
- `#111` a un verdict : réveillée, ou fermée.
- Le volet 10 est fini.

**Dépendances.** Éclairé par **G3** (le circuit d'invitation est le même).

*Renvois : `REGISTRE §26 ONBO-Q13` · `spec-onboarding-biblioteca-v2.0`*

---

### H — Interopérabilité, thésaurus, moisson

*Sortir vers les autres catalogues, et accepter d'être pointé en retour.*

| | | | |
|---|---|---|---|
| **H1** | Réparer l'aspiration des 158 descripteurs de dates du thésaurus | `P1` | Ouvert |
| **H2** | Poser à la FICEDL les sept questions qui bloquent l'export du thésaurus | `P1` | Bloqué |
| **H3** | Publier les correspondances vers le thésaurus FICEDL en SKOS | `P1` | Ouvert |
| **H4** | Exposer le catalogue en OPDS | `P1` | Ouvert |
| **H5** | Éprouver la moisson OAI-PMH dans les deux sens | `P2` | Ouvert |
| **H6** | Aligner les vocabulaires militants qui ne se connaissent pas | `P2` | Ouvert |
| **H7** | Décider du sort du texte de conventions d'interopérabilité | `P1` | Décision collective |

#### H1 — Réparer l'aspiration des 158 descripteurs de dates du thésaurus

`P1` Prioritaire · État : **Ouvert** · Charge : une soirée · Ce que ça demande : Deno / TypeScript, bibliothéconomie

**État.** `parseDescriptor` sort par retour précoce avant d'atteindre le titre de page quand une fiche n'a pas de bloc de traduction. Résultat : **158 descripteurs de la facette « dates », soit un quart du thésaurus, sont enregistrés comme identifiants nus, sans libellé, donc non alignables.** Leurs liens vers les catalogues se perdent de la même façon. Le correctif `ficedl_scrape_titre_dates.patch` existe, passe `node --check`, et **n'a jamais été éprouvé contre le site**.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Appliquer le correctif, qui relève le titre de page avant les retours précoces et le range dans un champ `title_fr` **distinct de `labels`** — une date a un libellé canonique mais pas de traduction.

**Pourquoi ça compte.** Un quart du thésaurus est aujourd'hui inutilisable. Et il faut le réparer **au moment d'une aspiration déjà prévue**, pas en lançant 620 requêtes spécialement : l'hébergeur du thésaurus a signalé une charge robots excessive.

**Ce qui compte comme fini.**

- Les 158 descripteurs de dates portent un libellé.
- La vérification s'est faite lors d'une aspiration prévue.
- Deux pièges du script de synchronisation à ne pas redécouvrir : **toujours passer `--json` explicitement** (un fichier sans date trie avant les fichiers datés) et **ne jamais utiliser `--prune`** (il supprimerait des descripteurs référencés par `subject_ficedl_links`).

**Dépendances.** Prévu semaine du 14/09. Abandonnable sans regret si le temps manque avant Bologne.

*Renvois : `REPRISE_claude_code_2026-08-27 chantier 3` · `NOTE_export_thesaurus_questions_ouvertes_2026-08-28`*

#### H2 — Poser à la FICEDL les sept questions qui bloquent l'export du thésaurus

`P1` Prioritaire · État : **Bloqué** · Charge : une soirée · Ce que ça demande : délibération collective

**État.** L'export complet des 620 descripteurs dans les deux formats est **à une soirée de travail** — dès que les sept questions ont une réponse. Elles sont écrites et personne ne les a encore posées.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Les sept : la forme des identifiants ; **la hiérarchie, qui est la vraie question** ; le statut de la facette « dates » ; le sort des 2 842 liens vers six catalogues ; le grec romanisé ; la licence ; et la manière dont le fichier se régénère.

**Pourquoi ça compte.** Sur 148 descripteurs à libellé arborescent, **93 parents sont retrouvés et 55 sont introuvables** : « art », « économie », « guerres », « littérature », « presse », « syndicalisme » ne sont pas des descripteurs, ou portent un autre nom. Vu de l'extérieur, **la hiérarchie n'est pas une donnée, c'est une convention d'affichage dans une chaîne de caractères** — et on ne peut pas écrire `skos:broader` honnêtement là-dessus. Seule la FICEDL peut dire si le site tient une vraie relation parent-enfant.

**Ce qui compte comme fini.**

- Les sept questions sont posées, avec l'audit de qualité produit à la première aspiration en pièce jointe — **les corrections appartiennent à la source, pas aux copies**.
- Quatre anomalies vues en passant sont remontées : deux sites différents sous le même intitulé « catalogue du CCL » ; les archives du *Monde libertaire* apparaissant deux fois par terme sous deux formes d'adresse ; `mot228` (« populations autochtones ») présent dans deux facettes ; 29 libellés portugais portant astérisque, point d'interrogation ou espace finale.
- La question 7 est la plus rentable : un squelette SPIP qui imprime les termes en CSV règle aussi la charge robots — **une requête au lieu de 620, par consommateur et par mise à jour**, pour une demi-journée de travail côté FICEDL.

**Dépendances.** Bloque **H3**. À poser à Bologne ou avant.

*Renvois : `NOTE_export_thesaurus_questions_ouvertes_2026-08-28`*

#### H3 — Publier les correspondances vers le thésaurus FICEDL en SKOS

`P1` Prioritaire · État : **Ouvert** · Charge : une soirée · Ce que ça demande : bibliothéconomie, Deno / TypeScript

**État.** 98 alignements existent en base entre les sujets locaux et les descripteurs FICEDL, en `exact` ou `close`. Le vocabulaire matière d'AnarBib est déjà exposé en SKOS. **Les correspondances vers la FICEDL ne le sont pas.**

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Exposer `subject_ficedl_links` en `skos:exactMatch` et `skos:closeMatch`. **Un alignement partiel vaut mieux que pas d'alignement** — c'est la convention 2 du texte d'interopérabilité, et elle s'applique d'abord à nous.

**Pourquoi ça compte.** C'est ce qui permet qu'un fonds catalogué avec un vocabulaire local reste trouvable par qui ne connaît pas ce vocabulaire — et dans dix langues, puisque le thésaurus est déjà traduit. Quelques heures pour un premier flux.

**Ce qui compte comme fini.**

- Un fichier SKOS est servi par l'application, à une adresse stable.
- Il distingue `exactMatch` de `closeMatch`.
- Il n'affirme rien sur la hiérarchie tant que **H2** n'a pas répondu.

**Dépendances.** La partie hiérarchie dépend de **H2**. La partie correspondances, non.

*Renvois : `docs/CHANTIERS_OUVERTS.md §4` · `CONVENTIONS_interoperabilite_catalogues_libertaires_2026-08-26 convention 2`*

#### H4 — Exposer le catalogue en OPDS

`P1` Prioritaire · État : **Ouvert** · Charge : une soirée · Ce que ça demande : Deno / TypeScript

**État.** Le point d'accès OAI-PMH est déployé. **OPDS n'existe pas.** Or « les flux OPDS existent de part et d'autre mais ne pointent nulle part », et c'est la convention 1 du texte proposé aux autres catalogues.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Un flux OPDS 1.2 ou 2.0 sur le catalogue public, avec les facettes déjà disponibles. Quelques heures pour un premier flux.

**Pourquoi ça compte.** OPDS est ce que lisent les liseuses et les applications de lecture. C'est le format par lequel un fonds numérisé devient consultable sans passer par notre interface — et c'est la première des quatre conventions qu'AnarBib propose aux autres. **Il serait difficile de la proposer sans l'appliquer.**

**Ce qui compte comme fini.**

- Un flux OPDS est servi et lisible par au moins un client réel.
- Il respecte la visibilité : rien qui ne soit déjà public ne sort.

**Dépendances.** Aucune.

*Renvois : `docs/CHANTIERS_OUVERTS.md §4` · `CONVENTIONS_interoperabilite_catalogues_libertaires_2026-08-26 convention 1`*

#### H5 — Éprouver la moisson OAI-PMH dans les deux sens

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : Deno / TypeScript, administration système

**État.** Le chemin est exécutable depuis le 28/08 : fonction `harvest-oai-pmh` déployée, cron `anarbib-oai-harvest-weekly` posé. **Le cron n'a jamais tourné** — première occurrence prévue mardi à 04h20. Et le point d'accès `oai-pmh-provider` **n'a jamais été moissonné depuis l'extérieur**.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Attendre le premier passage du cron et lire ce qu'il ramène. En parallèle, moissonner notre propre point d'accès depuis une machine tierce, avec un client OAI standard, et vérifier que les enregistrements sont conformes.

**Pourquoi ça compte.** Un point d'accès jamais moissonné est un point d'accès dont on ignore s'il fonctionne. C'est le même schéma que le circuit d'invitation : construit, déclaré, jamais emprunté. Et la limitation de débit n'est pas en place — le greffon `caddy-ratelimit` n'est pas embarqué dans l'image `caddy:2`, ce qui laisse le point d'accès public non limité.

**Ce qui compte comme fini.**

- Le cron a tourné au moins une fois et son résultat est lu.
- Un moissonnage externe a réussi, avec le compte rendu écrit.
- La limitation de débit a un verdict : rétablie le jour où le moissonnage gênera, ou assumée.

**Dépendances.** La limitation de débit est liée à **I2**.

*Renvois : `Relevé du 29/08/2026` · `REPRISE_bascule_autohebergee_2026-08-26` · `spec-oai-provider-gouvernance.md`*

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

#### H7 — Décider du sort du texte de conventions d'interopérabilité

`P1` Prioritaire · État : **Décision collective** · Charge : une soirée · Ce que ça demande : délibération collective

**État.** `CONVENTIONS_interoperabilite_catalogues_libertaires_2026-08-26` est un **brouillon qui n'engage personne et n'a jamais été discuté avec aucune organisation**. Il propose quatre conventions et une demande unique à la FICEDL.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Retirer les notes de travail, porter le texte à Bologne, et le laisser être repris collectivement — ou rangé.

**Pourquoi ça compte.** Deux choses sont écrites et méritent d'être tenues. D'une part, **un texte qui invite d'autres outils à s'appuyer sur le thésaurus demande une position de la fédération, pas un feu vert individuel** — c'est une question d'assemblée. D'autre part, **si le texte devient utile, il devra cesser d'être celui de qui l'a écrit**. Pas de liste de signataires : appliquer une convention se constate en regardant un catalogue, pas en consultant un registre.

**Ce qui compte comme fini.**

- Les notes de travail sont retirées.
- Le texte a été présenté à Bologne et son sort est décidé.
- S'attendre à ce que la **convention 4 — accepter d'être pointé en retour** — soit la plus discutée : c'est celle qui coûte le plus aux catalogues établis et rapporte le plus aux nouveaux venus. **Ne pas la retirer pour cette raison.**

**Dépendances.** Bologne, 12-13/09.

*Renvois : `CONVENTIONS_interoperabilite_catalogues_libertaires_2026-08-26`*

---

### I — Auto-hébergement, exploitation, sauvegardes, CI

*Gelé jusqu'au 14/09/2026 sur la production. Le travail en environnement d'essai reste ouvert.*

| | | | |
|---|---|---|---|
| **I1** | Aligner l'image GoTrue sur l'état réel des migrations d'authentification | `P1` | Gelé |
| **I2** | Achever la bascule vers l'auto-hébergement | `P1` | Gelé |
| **I3** | Tester le routeur `main` de la pile auto-hébergée | `P1` | Gelé |
| **I4** | Finir le témoin de provenance des sauvegardes | `P1` | Ouvert |
| **I6** | Purger les relevés de la sonde de santé | `P2` | Ouvert |
| **I8** | Mettre `deploy/README.md` en accord avec ce qui a été exécuté | `P2` | Ouvert |
| **I10** | Nettoyer les traces de Turnstile et les fichiers de rebut | `P2` | Ouvert |
| **I11** | Sortir de `node:20`, en fin de maintenance | `P2` | Ouvert |
| **I12** | Automatiser le rafraîchissement du miroir froid | `P2` | Ouvert |
| **I13** | Finir la bascule vers le nouveau moteur de pages | `P3` | Ouvert |

#### I1 — Aligner l'image GoTrue sur l'état réel des migrations d'authentification

`P1` Prioritaire · État : **Gelé** · Charge : quelques jours · Ce que ça demande : administration système

**État.** La production porte **77 migrations `auth`**, la dernière datée du 25/06. L'image épinglée dans `deploy/.env` est `GOTRUE_TAG=v2.189.0`, qui en porte **69**. `deploy/.env.example` indique `v2.192.0`. L'écart est un **bloquant de correction**, pas de confort.

*Constat du 29/08, non revérifié depuis.*

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

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Ce qui reste : découpler la chaîne de déploiement de l'intégration continue (**de l'extraction, pas de la création** — `scripts/ci/deployer-backend.sh` existe déjà), poser un proxy inverse avec tunnel devant la pile, passer des tags aux empreintes `sha256`, et refaire la répétition à froid un mois plus tard pour vérifier que rien n'a divergé.

**Pourquoi ça compte.** C'est l'objectif que le projet s'est donné et qu'il n'a pas encore atteint : la fin de la dépendance à un hébergeur tiers. **C'est le chantier le plus technique et le plus autonome du lot** — quelqu'un peut le prendre sans coordination.

**Ce qui compte comme fini.**

- La pile tourne derrière un proxy inverse, avec les versions en empreintes.
- Une reconstruction complète a été refaite un mois après la première.
- Garde-fou à préserver impérativement : la boucle de déploiement parcourt `supabase/functions/*/` **en excluant `_shared` et `main`** — sans quoi le routeur partirait sur le Supabase hébergé.
- Piège déjà rencontré : les rôles de service n'ont pas de mot de passe dans l'image `supabase/postgres` (SQLSTATE 28P01 en boucle), `postgres` n'est pas superutilisateur (c'est `supabase_admin`), `authenticator` est réservé, et un `set -e` dans la boucle tue le script au premier rôle en échec.

**Dépendances.** **Gelé sur la production jusqu'au 14/09.** Dépend de **I1**. À faire avant de louer quoi que ce soit : reprendre la connexion authentifiée en local, bloquée par une résolution IPv6 sans route — **ce blocage a probablement disparu de lui-même**, le vérifier coûte cinq minutes et peut épargner une machine montée pour rien.

*Renvois : `docs/CHANTIERS_OUVERTS.md §2` · `deploy/README.md` · `REPRISE_bascule_autohebergee_2026-08-26`*

#### I3 — Tester le routeur `main` de la pile auto-hébergée

`P1` Prioritaire · État : **Gelé** · Charge : une soirée · Ce que ça demande : Deno / TypeScript

**État.** `supabase/functions/main/index.ts` existe (6,9 Ko), lit `config.toml` au démarrage, applique un **refus par défaut** — seules les dispenses `verify_jwt = false` sont lues, tout le reste exige un jeton — et refuse de démarrer si le fichier est illisible. **Les quatre tests prévus n'ont pas été passés.**

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Les quatre tests de l'étape 5 de `deploy/REPETITION.md` : fonction protégée sans en-tête d'autorisation → 401 ; avec un jeton valide → 200 ; `health-probe` sans jeton → 200 ; nom inexistant → 404.

**Pourquoi ça compte.** Le routeur est ce qui remplace la protection par défaut de la plateforme le jour de la bascule. Comme `config.toml` ne déclare que 31 fonctions sur 48, **le refus par défaut du routeur fermera dix-huit fonctions qui fonctionnent aujourd'hui** — il faut le savoir avant, pas après.

**Ce qui compte comme fini.**

- Les quatre tests passent.
- Le comportement pour les 18 fonctions non déclarées est connu et voulu.

**Dépendances.** **Bloqué par B6.** Gelé sur la production jusqu'au 14/09 ; le test en environnement d'essai est ouvert.

*Renvois : `deploy/README.md` · `deploy/REPETITION.md étape 5`*

#### I4 — Finir le témoin de provenance des sauvegardes

`P1` Prioritaire · État : **Ouvert** · Charge : une soirée · Ce que ça demande : administration système

**État.** La migration `20260827180000_temoin_sauvegarde_provenance.sql` est **éprouvée sur un PostgreSQL 16 jetable, avec sept contrôles passés, mais jamais jouée contre la production**. Le correctif `health_probe_provenance.patch` **ne s'applique pas** : `patch failed … index.ts:286`. Il a été produit contre le miroir GitHub. Échéance du 28/08, donc échue.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Départager le conflit par `git hash-object` sur le fichier cible, comparé au blob de base `0d00dc0e016fdfb86ef314e4e707abd4a84d1d2c`. **Empreinte identique → `git apply --3way` passe. Empreinte différente → refaire le correctif à la main sur la version réelle : ne pas forcer, ne pas écraser.** Puis déployer `health-probe`.

**Pourquoi ça compte.** Ce que le correctif doit obtenir, quelle que soit la voie : dans le courriel, chaque flux affiche son hôte (ou « aucune ») et une mention explicite quand il s'agit d'un amorçage ; dans la raison de sauvegarde, `(dernière source : …)` ou `(aucun signal reçu)`. Sans cela, un courriel vert ne dit pas d'où vient le vert — et c'est exactement le défaut qui a laissé les sauvegardes échouer 36 heures en silence.

**Ce qui compte comme fini.**

- La migration est posée dans `supabase/migrations/` et appliquée.
- `health-probe` est déployée avec le comportement de provenance.
- **`temoin_sauvegarde_provenance.patch` est périmé : à ignorer, ne pas l'appliquer.**

**Dépendances.** Ne pas confondre avec le `snapshot_id` nul sur cinq lignes : le remède tient en trois lignes mais **`anarbib-bg2.sh` vit sur le poste de travail, hors dépôt** — c'est à signaler, pas à tenter depuis le dépôt.

*Renvois : `NOTE_temoin_sauvegarde_2026-08-27` · `REPRISE_claude_code_2026-08-27 chantier 1`*

#### I6 — Purger les relevés de la sonde de santé

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL

**État.** `service_health_probes` porte **13 932 lignes** et croît de 288 par jour, sans aucun cron de purge — alors que sept autres purges existent dans les 36 jobs.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Un cron de purge sur le modèle de `anarbib-catalog-audit-snapshot-purge`, avec une rétention à décider — trente jours suffisent probablement, les incidents étant conservés à part dans `service_health_incidents`.

**Pourquoi ça compte.** C'est la table la plus volumineuse de la base, et elle ne contient que du bruit dont l'utile a déjà été extrait. À ce rythme elle atteindra cent mille lignes avant la fin de l'année, ce qui alourdira chaque sauvegarde pour rien.

**Ce qui compte comme fini.**

- Un cron de purge existe, avec une rétention écrite.
- `service_health_incidents` n'est pas touchée par la purge.

**Dépendances.** Aucune.

*Renvois : `Relevé du 29/08/2026` · `REGISTRE §38 OPS`*

#### I8 — Mettre `deploy/README.md` en accord avec ce qui a été exécuté

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : administration système

**État.** Le document affirme en gras : « Rien de tout ceci n'a encore tourné ». Trois commits du 26/08 décrivent des exécutions réelles avec huit défauts relevés. Par ailleurs `bootstrap.sh` a **huit étapes** plus une « 7 bis » et une vérification, là où le README en annonce sept ; et le README déclare `notify-cross-library-digest` « absente du dépôt » alors qu'elle y est.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Réécrire la section d'état à partir des journaux d'exécution du 26/08, corriger le compte d'étapes, et retirer l'affirmation sur `notify-cross-library-digest`.

**Pourquoi ça compte.** `deploy/README.md` est le document que lira quelqu'un qui prend **A2** — la reconstruction par un tiers. Une phrase qui dit « rien n'a tourné » va lui faire croire qu'il essuie les plâtres alors que huit défauts ont déjà été trouvés et corrigés pour lui.

**Ce qui compte comme fini.**

- La section d'état décrit ce qui a tourné et ce qui n'a pas tourné.
- Les quatre points « à confirmer avant bascule » ont un verdict : GoTrue et le courriel, `PGRST_DB_SCHEMAS` mis à `public,api,storage` par déduction, le cas `notify-cross-library-digest` (clos), et le rejeu des migrations.
- `CADDY_TAG=2` est un tag majeur flottant dans un fichier qui proclame « aucun `latest`, jamais » : à épingler ou à justifier.

**Dépendances.** Prérequis moral de **A2**.

*Renvois : `deploy/README.md` · `Commits 57321385, 35c03dd5, 90266600`*

#### I10 — Nettoyer les traces de Turnstile et les fichiers de rebut

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : administration système

**État.** Turnstile a été entièrement retiré du code le 20/08 — sa réapparition serait une régression. Mais des **clés de test subsistent** dans `.env.example` (deux entrées), `.env.local`, `deploy/functions.env`, une référence dans `package.json`, et un secret au Vault. Par ailleurs `tmp-ficedl/` (754 Ko, doublon exact d'un fichier versionné) traîne à la racine, et `docs/drafts/` est versionné sans règle.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Retirer les cinq traces, supprimer `tmp-ficedl/` (ignoré par git depuis le 28/08, donc sans risque), et décider du statut de `docs/drafts/` : soit c'est un sas et il s'ignore, soit c'est du contenu et il se documente.

**Pourquoi ça compte.** Une clé de test dans un fichier d'exemple est ce que copiera la prochaine personne qui installe le projet. Et `docs/drafts/` est exactement l'endroit où le SQL des sujets SOLIDAIRES s'est perdu (voir **C1**) : un dossier sans règle est un dossier où les choses restent.

**Ce qui compte comme fini.**

- Aucune trace de Turnstile hors historique git.
- `tmp-ficedl/` a disparu du disque.
- `docs/drafts/` a une règle écrite : ce qui y entre en sort, ou n'y entre pas.

**Dépendances.** Aucune.

*Renvois : `RUNBOOK_exploitation_v0.3 §9.8` · `PLAN_DE_MARCHE §7.4` · `Relevé du 29/08/2026`*

#### I11 — Sortir de `node:20`, en fin de maintenance

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : administration système

**État.** Les trois jobs d'intégration continue tournent dans un conteneur `node:20`, dont la fenêtre de maintenance à long terme s'est achevée en avril 2026. C'est le point de fin de vie le plus net de la chaîne.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Passer à la version en maintenance longue suivante, vérifier que le build, les tests et le lint passent, et que la CLI Supabase épinglée `v2.98.1` s'y installe.

**Pourquoi ça compte.** Une image sans mises à jour de sécurité fait tourner tout le déploiement. Le changement est mécanique et se vérifie en une exécution.

**Ce qui compte comme fini.**

- Les trois jobs tournent sur une version maintenue.
- Le lint reste à zéro erreur (environ cent avertissements est l'état normal).

**Dépendances.** Aucune.

*Renvois : `.forgejo/workflows/ci.yml` · `package.json`*

#### I12 — Automatiser le rafraîchissement du miroir froid

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : administration système

**État.** Le miroir froid `anarbib-mirror.git` existe sur le poste de travail et son rafraîchissement est manuel. Les unités systemd `anarbib-mirror-refresh.service` et `.timer` sont versionnées dans `deploy/ops/` mais leur mise en service n'est pas confirmée.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Vérifier que le minuteur tourne, et sinon le mettre en service. Consigner la fraîcheur du miroir quelque part de lisible.

**Pourquoi ça compte.** Une reconstruction demande **trois** choses et non deux : le dépôt, une sauvegarde, **et les secrets du Vault**. Le miroir froid est la troisième copie du dépôt, après Codeberg et le miroir GitHub. Il ne sert que s'il est à jour — et le miroir GitHub a déjà accumulé 6 878 objets de retard une fois.

**Ce qui compte comme fini.**

- Le rafraîchissement est automatique et son échec alerte.
- La fraîcheur du miroir apparaît dans le témoin de sauvegarde.

**Dépendances.** Lié à **I4**.

*Renvois : `RUNBOOK_exploitation_v0.3 §4 §9.1`*

#### I13 — Finir la bascule vers le nouveau moteur de pages

`P3` Différé · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : administration système

**État.** L'étape 0 est concluante depuis le 20/08 : `test.anarbib.org` est servi par le nouveau moteur en parallèle. La chaîne d'intégration continue utilise déjà l'action `git-pages`. **Codeberg Pages en version historique est en mode maintenance, pas en fin de vie** — la documentation dit qu'il continuera de fonctionner indéfiniment. D'où la priorité basse.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Poser l'enregistrement TXT de liste blanche, créer `public/_redirects` avec la règle de réécriture, vérifier qu'une route inconnue renvoie 200 avec le bon contenu, puis nettoyer **seulement après** vérification verte.

**Pourquoi ça compte.** Deux points de vigilance sont écrits. **Ne pas toucher aux enregistrements A et AAAA**, qui sont bons. Et **vérifier la casse de l'URL** : le workflow écrit `AnarBib`, la documentation écrit `anarbib` — en cas de doute, poser les deux enregistrements TXT.

**Ce qui compte comme fini.**

- Le site est servi par le nouveau moteur, avec les routes inconnues en 200.
- Le nettoyage est fait après vérification : `public/.domains`, la branche `pages`, les secrets devenus inutiles.
- **Laisser `public/CNAME`** — il sert au miroir GitHub.
- Incertitudes assumées : la réversibilité de la bascule n'est documentée nulle part, aucune limite chiffrée n'est publiée (taille, bande passante, délai), et les fichiers vendorisés pèsent lourd — **point à surveiller au premier déploiement**.

**Dépendances.** P1, pas P0 — la version historique n'a pas de date d'arrêt annoncée.

*Renvois : `PLAN_migration_git_pages_2026-08-19` · `RUNBOOK_exploitation_v0.3`*

---

### J — Documentation et corpus

*Le corpus est vaste et sa dérive est mesurée. Ce backlog en fait partie.*

| | | | |
|---|---|---|---|
| **J2** | Réparer l'index des backlogs et trancher la convention d'archivage | `P2` | Ouvert |
| **J6** | Écrire les cinq doctrines internalisées là où un tiers les trouverait | `P2` | Ouvert |

#### J2 — Réparer l'index des backlogs et trancher la convention d'archivage

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : aucune compétence technique

**État.** Le tableau d'historique de `docs/backlogs/INDEX.md` s'arrête au v31 : **la ligne du v32 manque**, alors que le fichier est bien dans `archive/`. Et deux conventions de nommage des archives coexistent — avec ou sans le préfixe `-archive-` —, point ouvert explicite jamais porté au REGISTRE.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Ajouter la ligne du v32, celles du v33 et du v34, et trancher la convention d'archivage en une phrase inscrite au REGISTRE.

**Pourquoi ça compte.** L'index des backlogs est ce qui permet de savoir quelle version fait foi. Une lignée avec un trou et deux conventions concurrentes ne remplit pas cet office.

**Ce qui compte comme fini.**

- Le tableau est complet du v8 au v34.
- Une seule convention de nommage est inscrite au REGISTRE.

**Dépendances.** Se fait en posant ce backlog.

*Renvois : `docs/backlogs/INDEX.md`*

#### J6 — Écrire les cinq doctrines internalisées là où un tiers les trouverait

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : aucune compétence technique

**État.** Cinq règles de conception sont appliquées partout et écrites nulle part d'accessible : l'ordre des mises à jour dans une RPC (le récit avant l'état), la distinction entre `workflow_note` et `schedule_reply_note`, l'interdiction d'`async` dans `onAuthStateChange`, les pièges d'encodage sous PowerShell, et le contrat `actionBox` de la fonction de rendu des courriels.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Les écrire dans le dépôt, pas dans un fichier local. Une page suffit ; chacune tient en trois lignes et un exemple.

**Pourquoi ça compte.** Ces cinq règles vivent aujourd'hui dans `CLAUDE.md`, qui est **explicitement hors dépôt**. Quelqu'un qui clone le projet ne les verra jamais et les enfreindra, une par une, en écrivant du code parfaitement raisonnable.

**Ce qui compte comme fini.**

- Les cinq sont dans le dépôt, atteignables depuis `CONTRIBUTING.md`.
- Chacune porte l'incident qui l'a produite, quand il existe.

**Dépendances.** Sert **A2** et **A4**.

*Renvois : `CLAUDE.md, doctrines internalisées` · `PLAN_DE_MARCHE §8`*

---

### K — Caisse, communication, formation

*Ce qui décide si le projet a des moyens et des bras, et non seulement du code.*

| | | | |
|---|---|---|---|
| **K1** | Faire adopter l'acte de création du Fonds AnarBib | `P0` | Bloqué |
| **K2** | Ouvrir les canaux d'encaissement dormants | `P1` | Bloqué |
| **K3** | Tenir le registre public des comptes | `P2` | Ouvert |
| **K4** | Corriger le générateur des pages de vie privée sur la langue déclarée | `P2` | Ouvert |
| **K5** | Tenir l'intervention de Bologne et en tirer les suites | `P1` | En cours |
| **K6** | Préparer la rencontre avec leftove.rs et May Day Rooms | `P2` | En cours |
| **K7** | Mener la formation des deux coordinations BLMF jusqu'à l'autonomie | `P1` | En cours |
| **K8** | Finir le texte d'orientation sur les outils de bibliothèques militantes | `P2` | Ouvert |

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

*Constat du 29/08, non revérifié depuis.*

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

#### K4 — Corriger le générateur des pages de vie privée sur la langue déclarée

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : aucune compétence technique

**État.** Les pages écrites à la main portent `<html lang="pt-BR">` ; `tools/build-privacy-pages.cjs` émet `lang="pt"`. **Les pages ont raison, le script a tort.**

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Corriger le script pour qu'il émette l'étiquette complète, et vérifier que le générateur des pages de comptes, bâti sur le même modèle, ne reproduit pas le défaut.

**Pourquoi ça compte.** L'attribut de langue est ce qu'utilisent les lecteurs d'écran pour choisir leur prononciation. `pt` fera lire du portugais du Portugal à un public brésilien. C'est le même critère WCAG 3.1.1 que le projet a déjà corrigé côté application.

**Ce qui compte comme fini.**

- Le script émet l'étiquette complète.
- Les pages engendrées et les pages écrites à la main concordent.

**Dépendances.** Aucune.

*Renvois : `Dépôt vitrine anarbib/pages` · `tools/build-privacy-pages.cjs`*

#### K5 — Tenir l'intervention de Bologne et en tirer les suites

`P1` Prioritaire · État : **En cours** · Charge : quelques jours · Ce que ça demande : délibération collective

**État.** Atelier AnarBib le 12/09 au matin, assemblée ouverte le 13. Un jeu de 29 diapositives italien-anglais est prêt, ainsi qu'une brochure manifeste bilingue. Trois objectifs annoncés : la genèse et la conception, le panorama des fonctionnalités, et **un appel à participation**.

*Constat du 29/08, non revérifié depuis.*

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

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Avant la première séance : créer sur `blmf-teste` les deux comptes de coordination, un ou deux comptes de lecture fictifs, et les cinq fiches fautives de l'exercice 2. Puis le suivi de huit semaines : cinq fiches par semaine **toutes avec leur provenance**, un jour de comptoir par semaine, une consultation menée de bout en bout avec négociation réelle, et le vote du profil de la bibliothèque porté en assemblée.

**Pourquoi ça compte.** Deux personnes autonomes sur la coordination d'une bibliothèque, c'est **A1** à l'échelle locale. Le principe pédagogique tient en trois mots — *« cliqua, não vai quebrar nada ! »* — et il est tenable parce que les transitions impossibles ne s'affichent pas, les boutons bloqués sont pré-désactivés avec une explication, et la base refuse les combinaisons impossibles. Les neuf gestes irréversibles sont nommés explicitement.

**Ce qui compte comme fini.**

- Les huit semaines sont faites, avec le rituel hebdomadaire de trente minutes et ses trois questions fixes.
- La feuille de lacunes alimentée par ce rituel devient l'ordre du jour suivant **et un matériau de contribution au projet**.
- L'engagement chiffré est tenu : **aucune fiche nouvelle sans mode d'acquisition** — le rattrapage rétroactif des 2 450 fiches sans donnée d'acquisition n'est pas demandé, seul l'arrêt de la dette l'est.

**Dépendances.** S'appuie sur **G3** et **G4** pour le bac à sable.

*Renvois : `PLAN_formation_coordination_BLMF_2026-08-26` · `GABARITO_exercicio2_formacao_BLMF_2026-08-26`*

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
| Périodiques P1 à P9 | « Neuf paquets à livrer » | **Les neuf livrés les 27-28/08.** Reste la révision de la spec, item **D1**. |
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

Backlog v34, écrit le 2026-08-29, mis à jour le 2026-08-31. Remplace `AnarBib-Backlog-2026-06-17-v33.md`. 83 items sur 11 domaines. L'état de départ a été vérifié le 2026-08-29 contre la base de production en lecture seule et contre le dépôt Codeberg au commit `1d00ed2c` ; les items retouchés depuis portent leur propre date dans leur texte. Ce document n'arbitre rien : le `REGISTRE_decisions.md` fait foi.
