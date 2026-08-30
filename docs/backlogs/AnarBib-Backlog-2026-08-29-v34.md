# Backlog AnarBib v34 — Réécriture intégrale sur état vérifié — outil de travail pour les collaboratrices et collaborateurs à venir

**2026-08-29** · 90 items · Versão em português : `AnarBib-Backlog-2026-08-29-v34.pt-BR.md`

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
    - [B — Base de données, sécurité, RLS](#b--base-de-données-sécurité-rls) · 12
    - [C — Catalogage et données documentaires](#c--catalogage-et-données-documentaires) · 10
    - [D — Périodiques, éphémères, ressources numériques](#d--périodiques-éphémères-ressources-numériques) · 6
    - [E — Front, OPAC, i18n, accessibilité](#e--front-opac-i18n-accessibilité) · 11
    - [F — Courriel et notifications](#f--courriel-et-notifications) · 5
    - [G — Réseau, gouvernance, fédération](#g--réseau-gouvernance-fédération) · 10
    - [H — Interopérabilité, thésaurus, moisson](#h--interopérabilité-thésaurus-moisson) · 7
    - [I — Auto-hébergement, exploitation, sauvegardes, CI](#i--auto-hébergement-exploitation-sauvegardes-ci) · 13
    - [J — Documentation et corpus](#j--documentation-et-corpus) · 5
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

**État vérifié au 29/08.** Vérifié en base le 29/08 : le réseau compte **un seul administrateur**. Les tables `network_administrators`, `network_administrator_cooptation_proposals` et `network_administrator_cooptation_votes` sont vides après quelques insertions historiques.

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

**État vérifié au 29/08.** Jamais fait. `deploy/README.md`, `deploy/REPETITION.md` et `deploy/bootstrap.sh` existent et ont été exécutés — **sur la seule machine du mainteneur**.

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

**État vérifié au 29/08.** `.forgejo/workflows/ci.yml` et `sql-tests.yml` portent tous deux `runs-on: anarbib-local` — un `act_runner` auto-hébergé sur le WSL2 du mainteneur. Machine éteinte, **rien ne se déploie**, et l'échec est parfois silencieux.

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
| **B2** | Trier les 36 fonctions `SECURITY DEFINER` ouvertes à `anon` | `P1` | Ouvert |
| **B14** | Auditer les 464 fonctions `SECURITY DEFINER` ouvertes à `authenticated` | `P2` | Ouvert |
| **B4** | Examiner les quatre tables à RLS sans policy qui ne sont pas du transit | `P2` | Ouvert |
| **B5** | Résorber les neuf policies qui réévaluent `auth.*()` par ligne | `P2` | Ouvert |
| **B6** | Réconcilier `config.toml` avec les 48 fonctions réellement déployées | `P1` | Ouvert |
| **B7** | Départager les homonymes de fonctions entre `ingest` et `public` | `P2` | Ouvert |
| **B8** | Départager les vues qui existent en double entre `public` et `api` | `P2` | Ouvert |
| **B9** | Purger le schéma `backup_2026_05_07` | `P2` | Ouvert |
| **B10** | Hygiène de performance : 170 index inutilisés, 38 clés étrangères non indexées, 24 policies permissives en double | `P3` | Ouvert |
| **B11** | Comprendre `user_wishlist` : une ligne vivante pour 9 092 insertions | `P2` | À vérifier |
| **B12** | Élucider les trois actions critiques inter-bibliothèques restées en `skipped` | `P2` | À vérifier |
| **B13** | Décider du sort des 221 migrations : squash ou pas | `P3` | Ouvert |

#### B2 — Trier les 36 fonctions `SECURITY DEFINER` ouvertes à `anon`

`P1` Prioritaire · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : SQL / PostgreSQL

**État vérifié au 29/08.** Complété le 30/08. Le Security Advisor de Supabase affiche **500 avertissements** ; l'export CSV le dit : ce sont **deux lints et rien d'autre** — `anon_security_definer_function_executable` (0028) et `authenticated_security_definer_function_executable` (0029). Compté en production : **36** fonctions exécutables par `anon`, **464** par `authenticated`, total exactement 500.

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

**Ce que c'est.** La règle, corrigée par ce relevé : **est ouvert à `anon` ce qui sert une page publique, ou ce qu'une policy évaluée par `anon` appelle. Rien d'autre — et surtout pas par défaut.**

Quatre lots, dans cet ordre :

1. `REVOKE EXECUTE … FROM anon` sur les trois grants que la fonction contredit. Aucun changement de comportement : elles refusaient déjà.
2. Un `COMMENT ON FUNCTION` sur les cinq intouchables, qui dit *pourquoi* et cite le décompte de policies daté. Sans lui, la prochaine lecture du tableau de bord refera ce travail — ou fera le revoke.
3. **Retourner le défaut du schéma** : `ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM anon;`. Ne change rien aux 621 fonctions existantes — seulement aux suivantes. À partir de là, ouvrir à `anon` est un acte écrit, et une ouverture oubliée casse une page publique de façon visible au lieu d'exposer une fonction en silence. C'est une décision de doctrine : elle demande une entrée au `REGISTRE_decisions`, pas seulement une migration.
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

**État vérifié au 29/08.** L'autre part des 500 avertissements de l'advisor : le lint 0029, **464 fonctions** — 138 dans `api` sur 142, 326 dans `public` sur 498. L'audit du 18/05 a passé en revue une partie de `public` et fermé cinq failles réelles ; **il ne portait pas sur `api`.**

Comme pour `anon` (item **B2**), ce nombre est d'abord l'effet d'un défaut de schéma : `ALTER DEFAULT PRIVILEGES … GRANT ALL ON FUNCTIONS TO … authenticated` s'applique à toute fonction créée dans `public`. La différence est qu'ici, le défaut est **presque toujours celui qu'on veut** : la surface d'écriture de l'application est faite de RPC `SECURITY DEFINER` derrière `api`, appelées par des personnes connectées (doctrine `DOC-RPC-3`). Le nombre ne descendra pas à zéro, et ce n'est pas l'objectif. L'advisor signale une architecture qu'il ne peut pas connaître.

**Ce que c'est.** Le critère n'est pas *« est-elle `SECURITY DEFINER` ? »* — elles le sont toutes, par construction. C'est : **que peut demander une inconnue qui s'est simplement inscrite ?** Un compte `authenticated` s'obtient en trois clics ; il ne prouve l'appartenance à aucune bibliothèque.

Reprendre la question d'audit du 18/05 — *que renvoie-t-elle, à partir de quel paramètre, et qu'est-ce qui interdit à un tiers de le demander ?* — et l'appliquer aux 138 fonctions de `api` d'abord, qui sont la surface exposée par `/rest/v1/rpc/`. Chercher `auth.uid()` dans le corps ne prouve rien : les cinq failles de mai en contenaient.

Les oracles trouvés en mai avaient tous la même forme : un identifiant en paramètre, une donnée nominative en retour. Chercher cette forme en priorité.

**Pourquoi ça compte.** C'est la moitié non auditée de la surface d'API du projet. Les cinq failles trouvées dans `public` étaient des oracles — numéro vers courriel, identifiant vers nom — et rien ne dit que `api` n'en porte pas. Pour une bibliothèque militante, un oracle qui rend un nom à partir d'un numéro n'est pas un défaut technique : c'est une liste de personnes.

**Ce qui compte comme fini.**

- Les 138 fonctions de `api` ont un verdict écrit : légitime, à restreindre, ou à supprimer.
- Les fonctions à restreindre ont perdu leur `EXECUTE` par migration, après vérification qu'aucune policy ne les appelle.
- Le compte rendu vit dans `docs/journal/audits/`, au format de celui du 18/05.
- Le reste de `public` suit, par paquets.

**Dépendances.** Se fait par lots. Un lot de vingt fonctions est déjà utile. Ne commence pas avant B2, dont le lot 2 pose le vocabulaire des commentaires.

*Renvois : `PLAN_DE_MARCHE §8` · `PLAN_DE_MARCHE règle 13.3` · `AUDIT_securite_fonctions_privees_2026-05-18` · `REGISTRE_decisions DOC-RPC-3`*

#### B4 — Examiner les quatre tables à RLS sans policy qui ne sont pas du transit

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL

**État vérifié au 29/08.** 15 tables ont RLS activé et zéro policy. Onze sont des tables de transit ou vides. Quatre ne le sont pas : `author_name_aliases` (**1 647 lignes**), `library_themes` (3 lignes), `library_theme_configs`, `interlibrary_loan_events`.

**Ce que c'est.** Pour chacune, trancher : soit l'accès passe par une RPC et l'absence de policy est correcte — l'écrire en commentaire SQL —, soit une lecture légitime est aujourd'hui impossible et il manque une policy ou une fonction.

**Pourquoi ça compte.** Une table avec RLS et sans policy est fermée à tout le monde sauf aux fonctions `DEFINER`. C'est parfois exactement ce qu'on veut, et parfois une fonctionnalité qui ne marche pas sans que personne l'ait remarqué — `author_name_aliases` porte 1 647 lignes que rien ne lit peut-être.

**Ce qui compte comme fini.**

- Les quatre tables ont un verdict écrit.
- Le contrôle de restauration du runbook liste nommément les tables sans policy attendues.

**Dépendances.** Aucune.

*Renvois : `PLAN_DE_MARCHE §8` · `MATRICE_rls_deny_all_2026-06-23`*

#### B5 — Résorber les neuf policies qui réévaluent `auth.*()` par ligne

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL

**État vérifié au 29/08.** La migration `20260703203953_perf_rls_initplan_wrap_auth_calls` a traité les policies d'alors. Neuf policies écrites depuis y échappent : `book_reading_notes` (4), `book_reading_note_reports` (2), `catalog_duplicate_reports` (1), `authority_duplicate_reports` (1), `author_not_duplicate` (1).

**Ce que c'est.** Envelopper les appels `auth.uid()` / `auth.jwt()` dans un sous-select, comme la migration de juillet l'a fait pour les autres.

**Pourquoi ça compte.** Sans cet enveloppement, la fonction est appelée une fois par ligne examinée. Les cinq tables concernées sont vides aujourd'hui, donc le coût est nul — et c'est précisément le bon moment pour corriger, avant que les notes de lecture servent.

**Ce qui compte comme fini.**

- Le lint `auth_rls_initplan` ne remonte plus aucun avis.
- Le patron d'enveloppement est rappelé dans le modèle de migration.

**Dépendances.** Aucune.

*Renvois : `Advisors performance, relevé du 29/08/2026`*

#### B6 — Réconcilier `config.toml` avec les 48 fonctions réellement déployées

`P1` Prioritaire · État : **Ouvert** · Charge : une soirée · Ce que ça demande : Deno / TypeScript, administration système

**État vérifié au 29/08.** `supabase/config.toml` porte **31 sections `[functions.*]`, toutes à `verify_jwt = false`, aucune à `true`**. Les commentaires du fichier annoncent « 17 en `false` et 6 en `true` » ; `CLAUDE.md` annonce « 36 dont 5 à `true` ». Les trois se contredisent, et **18 des 48 fonctions déployées ne sont pas déclarées du tout**.

**Ce que c'est.** Établir la liste réelle des 48 fonctions et, pour chacune, ce qui doit la protéger : JWT de la plateforme, secret de webhook, ou rien parce qu'elle est publique par nature. Écrire cette liste dans `config.toml` et corriger les commentaires et `CLAUDE.md`.

**Pourquoi ça compte.** C'est la seule ligne de la documentation qui décrit une protection **qui n'existe pas**. Les 18 fonctions non déclarées reposent sur le comportement par défaut de la plateforme — un comportement qui disparaîtra le jour de la bascule auto-hébergée, où c'est le routeur `main` qui décidera, en refus par défaut.

**Ce qui compte comme fini.**

- `config.toml` déclare les 48 fonctions déployées, sans exception.
- Chaque `verify_jwt = false` porte une ligne de commentaire disant ce qui protège la fonction à la place.
- Le routeur `main` a été relu contre cette liste.

**Dépendances.** Prérequis de **I3** (test du routeur `main`).

*Renvois : `Relevé du 29/08/2026` · `deploy/README.md` · `supabase/functions/main/index.ts`*

#### B7 — Départager les homonymes de fonctions entre `ingest` et `public`

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL

**État vérifié au 29/08.** Quatre noms de fonction existent dans les deux schémas avec des signatures et des sémantiques différentes : `fn_bulk_create_book_drafts_from_run`, `fn_bulk_set_partner_catalog_editorial_decision`, `fn_set_partner_catalog_editorial_decision`, et `set_updated_at()`. Aucun doublon de signature dans un même schéma — le problème est le nom partagé.

**Ce que c'est.** Vérifier laquelle des deux est appelée par le front et par les RPC, renommer celle qui ne l'est pas, ou supprimer la version morte. `set_updated_at()` est un trigger banal et peut rester.

**Pourquoi ça compte.** Un `search_path` qui change d'ordre suffit à faire appeler l'autre fonction, avec des paramètres qui ne correspondent pas. C'est une panne difficile à diagnostiquer, et le projet a déjà payé une fois pour un `search_path` mal épinglé.

**Ce qui compte comme fini.**

- Les trois fonctions métier homonymes sont départagées.
- Aucune ne dépend de l'ordre du `search_path` pour être résolue correctement.

**Dépendances.** Aucune.

*Renvois : `Relevé du 29/08/2026`*

#### B8 — Départager les vues qui existent en double entre `public` et `api`

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL

**État vérifié au 29/08.** Quatre paires de vues homonymes ou quasi : `public.my_access` / `api.my_access`, `public.my_session_context` / `api.my_session_context`, `public.v_library_service_public` / `api.library_service_public`, `public.v_book_detail_public_v2` / `api.catalog_book_detail_public_v2`. Et dans `public`, `catalog_partners_policy_flags` coexiste avec `catalog_partners_policy_flags_v2`.

**Ce que c'est.** Vérifier laquelle est lue par le front — le schéma exposé par PostgREST est `public,api,storage` — et supprimer les autres, ou expliciter que la vue `public` est le socle et la vue `api` l'exposition.

**Pourquoi ça compte.** Deux vues du même nom dans deux schémas tous deux exposés par PostgREST, c'est une ambiguïté à l'appel. Et une vue `_v2` qui n'a jamais remplacé sa `v1` est du code mort qui ressemble à du code vivant.

**Ce qui compte comme fini.**

- Chaque paire a un verdict : socle + exposition assumés, ou suppression de la morte.
- La vue `_v2` a remplacé sa devancière, ou l'inverse.

**Dépendances.** Aucune.

*Renvois : `Relevé du 29/08/2026`*

#### B9 — Purger le schéma `backup_2026_05_07`

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL

**État vérifié au 29/08.** Six tables, **toutes à zéro ligne et zéro insertion depuis leur création**, sans clé primaire, sans RLS : `emprestimos_v2`, `emprestimo_itens_v2`, `reservas_v2`, `reserva_linhas_v2`, `reserva_item_workflow_v2`, `loan_midpoint_message_log`. La décision `BG2-9` prescrit cette purge depuis juin.

**Ce que c'est.** `DROP SCHEMA backup_2026_05_07 CASCADE` par migration, après avoir confirmé une dernière fois que les six tables sont vides.

**Pourquoi ça compte.** Six tables de sauvegarde vides polluent chaque relevé d'advisors — elles portent à elles seules six des quatorze avis « pas de clé primaire ». Et un schéma nommé `backup_` qui ne contient rien est un piège pour qui reprendra le projet.

**Ce qui compte comme fini.**

- Le schéma n'existe plus.
- `deploy/bg2-known-tables.txt` a été mis à jour dans le même mouvement.

**Dépendances.** Ne pas confondre avec `conv_backup`, qui porte des données de revue humaine et **ne se purge pas** (voir **C4**).

*Renvois : `REGISTRE §BG2 BG2-9`*

#### B10 — Hygiène de performance : 170 index inutilisés, 38 clés étrangères non indexées, 24 policies permissives en double

`P3` Différé · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : SQL / PostgreSQL

**État vérifié au 29/08.** 256 avis de performance au 29/08. Les tables les plus chargées en index inutilisés sont `library_partnerships` (6), `books` (5), `membership_payments` (4). Les 24 policies permissives en double portent toutes sur le rôle `authenticated` en `SELECT`, sur des tables centrales (`books`, `authors`, `exemplares`, `subjects`, `works`).

**Ce que c'est.** Trois passes distinctes, à ne pas mélanger : fusionner les paires de policies permissives ; indexer les clés étrangères qui servent réellement ; ne supprimer un index inutilisé que si l'on comprend pourquoi il avait été créé.

**Pourquoi ça compte.** À la volumétrie actuelle — 2 676 notices, 16 comptes — **rien de ceci ne se voit**. C'est un chantier de pré-montée en charge, différé à dessein depuis juillet. Le noter permet de ne pas le redécouvrir en urgence le jour où une bibliothèque arrive avec 100 000 notices.

**Ce qui compte comme fini.**

- Les 24 avis de policies en double sont résorbés — c'est la passe la plus rentable.
- Les clés étrangères des tables réellement écrites sont indexées.
- Les index supprimés le sont avec la raison écrite.

**Dépendances.** À reprendre si une bibliothèque à gros fonds rejoint le réseau.

*Renvois : `ETAT-lancement-consolide-2026-07-03 §2 item 7` · `Advisors performance du 29/08/2026`*

#### B11 — Comprendre `user_wishlist` : une ligne vivante pour 9 092 insertions

`P2` Courant · État : **À vérifier** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL

**État vérifié au 29/08.** La table `public.user_wishlist` porte **1 ligne vivante** pour **9 092 insertions cumulées**. C'est le rapport écriture/suppression le plus extrême de la base, de deux ordres de grandeur.

**Ce que c'est.** Trouver ce qui écrit et efface : un test rejoué, un chargement de page qui insère puis annule, un composant React qui appelle la RPC à chaque rendu. Regarder `OPAC-W1`, dont la note dit « reste `WITH CHECK` ».

**Pourquoi ça compte.** Neuf mille écritures pour une ligne, ce n'est pas un usage : c'est une boucle. Elle coûte peu aujourd'hui et coûtera exactement autant par utilisatrice le jour où il y en aura cent.

**Ce qui compte comme fini.**

- La cause est identifiée et écrite.
- Si c'est une boucle du front, elle est corrigée ; si c'est un test, la ligne est retirée du constat.

**Dépendances.** Aucune.

*Renvois : `REGISTRE §18 OPAC-W1` · `Relevé du 29/08/2026`*

#### B12 — Élucider les trois actions critiques inter-bibliothèques restées en `skipped`

`P2` Courant · État : **À vérifier** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL, Deno / TypeScript

**État vérifié au 29/08.** Trois lignes de `network.cross_library_critical_action` sont en `status = 'skipped'` depuis le 08/06/2026, avec `attempts = 1`, `last_error` nul et un `pg_net_request_id` présent. Le signalement date du 26/08 et n'a pas été instruit.

**Ce que c'est.** Croiser les `pg_net_request_id` avec les journaux de `notify-event` pour savoir si l'appel est parti, s'il a échoué, ou s'il a été volontairement ignoré. Puis décider : rejouer, ou clore avec la raison.

**Pourquoi ça compte.** Ces lignes tracent des actions d'administration réseau qui touchent une bibliothèque autre que celle de la personne qui agit. Un statut `skipped` sans erreur, c'est soit une notification qui n'est jamais partie, soit une trace mal posée. Les deux méritent d'être sues.

**Ce qui compte comme fini.**

- Les trois lignes ont une explication écrite.
- Si le mécanisme peut sauter une notification en silence, il est corrigé.

**Dépendances.** Lié à **F1** (audit de la chaîne de courriel).

*Renvois : `VERIF_etat_reel_gouvernance_et_crons_2026-08-26 §4`*

#### B13 — Décider du sort des 221 migrations : squash ou pas

`P3` Différé · État : **Ouvert** · Charge : plusieurs semaines · Ce que ça demande : SQL / PostgreSQL, administration système

**État vérifié au 29/08.** 221 migrations appliquées, dont la première est un `baseline_live` de **2,4 Mo** — le plus gros fichier du dépôt. Le squash est marqué « décidé, non commencé » depuis le 20/08, à une époque où le compte était de 146.

**Ce que c'est.** Soit reconstruire un `baseline` à partir du schéma courant et archiver les migrations antérieures, soit assumer la chaîne longue et documenter pourquoi. Le rejeu complet prend aujourd'hui environ 25 minutes, mesuré.

**Pourquoi ça compte.** Le risque du squash est entier : il réécrit la seule trace ordonnée de ce qui a été fait, et le harnais de tests SQL rejoue toute la chaîne à chaque fois. Ne pas le faire coûte du temps de CI ; le faire mal coûte la capacité à reconstruire. **Ne pas s'y engager avant que A2 ait réussi au moins une fois.**

**Ce qui compte comme fini.**

- Une décision écrite au REGISTRE, dans un sens ou dans l'autre.
- Si squash : la reconstruction depuis le nouveau baseline a été éprouvée sur une machine tierce.

**Dépendances.** **Bloqué par A2.** Ne pas commencer avant.

*Renvois : `ETAT-AVANCEMENT-multisessions` · `docs/schema/baseline_schema_2026-06-11.sql`*

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

**État vérifié au 29/08.** Vérifié le 29/08 : **35 sujets ont été créés en base le 27/08** et les alignements FICEDL sont passés de 51 à **98**. Mais `docs/drafts/20260828_sujets_solidaires_ficedl.sql` est toujours dans `docs/drafts/`, hors de `supabase/migrations/`. Une instance neuve n'aura donc pas ces sujets.

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

**État vérifié au 29/08.** 1 685 notices dans `SOLIDAIRES_import_test.csv`. Les en-têtes suivent `spec-catalogacao-fiche-et-paliers` et **n'ont jamais été confrontés à l'importeur**. **Décision de Xavier, 29/08 : l'import ne se fera que si la candidature de SOLIDAIRES est acceptée par plusieurs administrateur·rices réseau.** L'échéance de fin août tombe donc, et l'ordre des deux chantiers s'inverse par rapport aux notes d'août : l'admission d'abord, l'import ensuite.

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

**État vérifié au 29/08.** Les 19 migrations `conventions_*` sont appliquées depuis le 21/08 : les référentiels sont normalisés, les mécaniques sûres ont été passées, la file de vérification existe et l'application permet d'y travailler. **Ce qui reste est la part qu'aucune machine ne fait.**

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

**État vérifié au 29/08.** **722 fiches sur 1 305 (55 %) n'ont pas de `country`.** Or c'est `country` qui pilote la règle d'entrée du nom : sans lui, la détection des doubles patronymes hispaniques ne voit qu'une fraction des cas. Les 22 signalements sont un **plancher**, pas un total.

**Ce que c'est.** Renseigner `country` par lots, à partir des notices, des sources externes déjà branchées (Wikidata, VIAF) et de la connaissance du fonds. Puis rejouer la détection des patronymes.

**Pourquoi ça compte.** C'est le prérequis dur de toute la chaîne de conventions : `CONV-7` fait de `country` en ISO 3166-1 α-2 une condition, et `CONV-3` fait piloter la casse par la langue. Un catalogue à 55 % sans pays applique ses propres règles à moitié.

**Ce qui compte comme fini.**

- La proportion de fiches sans `country` est descendue sous 20 %.
- La détection des doubles patronymes a été rejouée et la nouvelle liste est passée en revue humaine.

**Dépendances.** Prérequis de la seconde passe de **C3**.

*Renvois : `AUDIT_conventions_catalographiques_2026-08-20 A5` · `REGISTRE §37 CONV-7`*

#### C5 — Trancher le sort du champ libre `books.autor`

`P2` Courant · État : **Décision collective** · Charge : une soirée · Ce que ça demande : bibliothéconomie, SQL / PostgreSQL

**État vérifié au 29/08.** `CONV-O3` est ouvert : déprécier `books.autor` maintenant, ou à l'Atelier ? Le champ coexiste avec la table `authors` et porte les mêmes défauts **en pire** — on y trouve `identificado, Não`, `REICH, Hilhem`, `Rosamund Bartlett (Org.)`. L'audit du 20/08 l'a explicitement laissé hors périmètre : sa dette n'est pas chiffrée.

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

**État vérifié au 29/08.** La base sait normaliser ; l'interface de saisie n'assiste pas encore. Trois dispositifs sont spécifiés et non livrés : l'assistant de découpage du nom (§7.1), le bouton « Normalizar maiúsculas » avec aperçu (§7.2), et la file de contrôles de cohérence en arrière-plan (§7.3).

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

**État vérifié au 29/08.** Vérifié le 29/08 : **1 127 notices indexées sur 2 676**, soit 42 %. 1 284 affectations réparties sur 89 sujets locaux. Côté public anonyme, la couverture est encore plus basse.

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

**État vérifié au 29/08.** Sur 1 305 autorités : **726 (56 %) sans date de naissance**, environ **1 272 (98 %) sans identifiant VIAF, ISNI ou Wikidata**, environ **1 275 (98 %) sans `variant_forms`**. Le code d'enrichissement existe et fonctionne ; la couverture est de l'ordre de 1 à 2 %.

**Ce que c'est.** Passes d'enrichissement par les sources déjà branchées, avec relecture. Les pseudonymes militants sont un cas à part : l'entrée se fait à la forme la plus connue du mouvement, avec renvoi depuis le nom civil, **jamais l'inverse**.

**Pourquoi ça compte.** Les identifiants externes sont ce qui permettra à un autre catalogue de reconnaître nos autorités sans les redécrire. Les formes variantes sont ce qui permet de trouver quelqu'un sous le nom qu'on connaît. Et pour un pseudonyme militant, la forme d'usage **porte souvent la seule trace d'une répression** : elle ne s'écrase pas.

**Ce qui compte comme fini.**

- La couverture en identifiants externes dépasse 20 % sur les autorités les plus citées.
- Aucun pseudonyme militant n'a été remplacé par un nom civil.

**Dépendances.** Après **C4** (les pays aident les alignements).

*Renvois : `AUDIT_conventions_catalographiques_2026-08-20 A7-A9` · `REGISTRE §12 CAT-D6`*

#### C9 — Fermer les huit questions ouvertes des conventions catalographiques

`P2` Courant · État : **Décision collective** · Charge : une soirée · Ce que ça demande : bibliothéconomie

**État vérifié au 29/08.** `CONV-6` reste « à confirmer » et `CONV-O1` à `CONV-O8` sont ouverts. Deux d'entre eux portent du travail chiffré : `CONV-O7` (le type d'autorité existe mais reste illisible par le SQL — **16 verdicts de collectivités restent à poser**) et `CONV-O8` (la scission d'autorité n'existe pas — **3 découpages restent**).

**Ce que c'est.** Trancher les huit en une session, en s'aidant du fonds réel : `name_lang` distinct de `country` ou non, conventions des collectivités, sort de `books.autor` (voir **C5**), critère de bascule EDTF, périmètre de l'écran de vérification, et les deux lots manuels.

**Pourquoi ça compte.** La colonne `name_lang` a été créée nullable et sans contrainte validée : **la créer n'engage rien, l'utiliser oui**. Tant que la question reste ouverte, chaque nouvelle règle d'entrée doit se demander sur quoi elle s'appuie.

**Ce qui compte comme fini.**

- Les huit ont un verdict au REGISTRE.
- Les 16 collectivités et les 3 découpages sont traités à la main — ils sont explicitement **non automatisables**.

**Dépendances.** Éclaire **C6**.

*Renvois : `REGISTRE §37 CONV-6, CONV-O1..O8`*

#### C10 — Renommer l'une des deux colonnes `rights_status`

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL

**État vérifié au 29/08.** `digital_assets.rights_status` est un **état de workflow** (`to_review`, `public_domain_confirmed`) qui commande la visibilité. Le vocabulaire des droits d'auteur porte le même nom depuis la migration `20260820235000_vocabulaire_rights_status`. Deux sens, un nom.

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

**État vérifié au 29/08.** `spec-periodiques-v0.1` (27/08) annonce « neuf paquets à livrer ». **Les neuf ont été livrés les 27 et 28/08**, en une journée : `serials`, RPC, anti-faux-doublons, état de collection, entrée dans l'Atelier, reprise des notices existantes, UI de catalogage, page publique, et les libellés dans les dix langues. La base porte 4 titres et 7 fascicules rattachés.

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

**État vérifié au 29/08.** Cinq arbitrages étaient laissés en attente dans la spec, avec un penchant écrit pour chacun : vocabulaire de `periodicidade` libre ou fermé ; filiation n-n ou deux liens simples ; `serials` doit-elle porter un `library_id` ; promotion automatique d'un titre proposé ; page publique dédiée ou facette.

**Ce que c'est.** Les trancher sur des cas réels plutôt que dans l'abstrait — le fonds Anarchief (une centaine de titres depuis 1860) et le fonds SOLIDAIRES (12 titres, 91 fascicules) sont la matière à éprouver.

**Pourquoi ça compte.** Deux des cinq sont déjà tranchés de fait par le code livré (page dédiée `/periodico/<slug>`, pas de `library_id`). Les laisser « ouverts » au REGISTRE alors que le code a choisi crée exactement le genre d'écart que ce backlog corrige.

**Ce qui compte comme fini.**

- Les cinq ont un verdict inscrit, en accord avec le code livré ou en le corrigeant.
- La promotion d'un titre reste **un geste et non un seuil** — c'était le penchant, et il vaut d'être confirmé.

**Dépendances.** Après **D1**.

*Renvois : `spec-periodiques-v0.1 §13`*

#### D3 — Rattacher les 91 fascicules et les 87 monographies suspectes de SOLIDAIRES

`P2` Courant · État : **Bloqué** · Charge : quelques jours · Ce que ça demande : bibliothéconomie

**État vérifié au 29/08.** Le fichier SOLIDAIRES porte déjà des colonnes `revue` et `numero` : **12 titres à créer, 91 fascicules à lier**. En plus, **87 monographies portent « n° » dans leur titre** et sont marquées par un drapeau `numero_dans_titre` : ce sont des candidates au rattachement.

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

**État vérifié au 29/08.** Rien n'existe. Le modèle de notice hérité de la bibliothéconomie du livre ne sait pas décrire ce matériel, et AnarBib ne fait pas exception. C'est le besoin **le plus mal couvert**, pour une part énorme de nos fonds.

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

**État vérifié au 29/08.** La règle est actée et tient en une phrase : « on capture en niveaux de gris, on livre en bitonal, on ne garde en ligne que ce qui est livré ». Les plafonds de buckets sont posés en production. **L'outil de dérivation n'est pas choisi**, et la fiche pratique d'une page n'est pas écrite.

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

**État vérifié au 29/08.** `epubjs ^0.3.93` est la seule dépendance clairement pré-1.0 sur un chemin critique — le lecteur EPUB, `src/lib/reader/epubEngine.js` et `src/components/viewers/EpubReader.jsx`. La bibliothèque n'a pas connu de publication majeure depuis des années.

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

**État vérifié au 29/08.** Des fonctionnalités d'accessibilité sont implémentées : panneau de réglages sur toutes les pages depuis le 26/08, `html lang` qui suit la langue affichée (WCAG 3.1.1) avec son test, champs à 16 px minimum, cibles tactiles à 44 px, `viewport-fit=cover`. **Aucun audit d'accessibilité indépendant n'a jamais été mené.**

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

**État vérifié au 29/08.** Les dix locales sont à parité stricte de clés — 6 177 chacune, vérifiée en intégration continue depuis le 27/08. Mais les **conventions** de deux d'entre elles ne sont pas tranchées : le néerlandais est à l'état de brouillon, le grec reste à définir. Le test de parité ne voit pas ça : il compte les clés, pas leur justesse.

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

**État vérifié au 29/08.** `DOC-ADDR-1` fixe le tutoiement comme registre de l'interface. En pratique, **`nl` et `el` tutoient, les huit autres vouvoient**. L'écart est documenté et assumé comme « un chantier à décider, pas à subir au détour d'un correctif ».

**Ce que c'est.** Décider une fois pour les dix, en tenant compte du fait que la valeur politique du tutoiement n'est pas la même dans chaque langue, puis passer les locales concernées en une seule opération.

**Pourquoi ça compte.** AnarBib propose à d'autres catalogues des conventions d'interopérabilité, dont l'une dit explicitement que le vocabulaire commun n'impose pas l'écriture inclusive de chacun. **La cohérence interne se règle avant de prêcher la convention.**

**Ce qui compte comme fini.**

- Une décision au REGISTRE, avec la raison.
- Les dix locales appliquent le même registre, ou l'écart est justifié langue par langue.

**Dépendances.** À faire après **E2** (les conventions décident du registre).

*Renvois : `REGISTRE §0 DOC-ADDR-1` · `VERIF_confidentialite_tiers_2026-08-20`*

#### E4 — Régler les paires irrégulières de l'italien

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : langue maternelle

**État vérifié au 29/08.** `it.json` n'est pas conforme à la convention de l'astérisque final : les paires irrégulières comme `lettore` / `lettrice` ne se réduisent pas à `lettor*`. Le test de charte vérifie une seule chose sur l'italien — que `camerata` et `camerati` n'y figurent jamais, terme fasciste, échec dur — et rien d'autre.

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

**État vérifié au 29/08.** C'est la **seule exception anti-pistage restante** : les tuiles de `tile.openstreetmap.org` sont chargées par le navigateur de la visiteuse, qui livre donc son adresse IP à un tiers. L'intention de relayer est **déjà annoncée publiquement** dans la clé `privacy.s6.maptiles` des dix locales.

**Ce que c'est.** Reprendre le modèle déjà en place pour Nominatim : un relais côté serveur, avec cache, et l'adresse du relais dans la configuration du front.

**Pourquoi ça compte.** La règle de conformité du projet est écrite et générale : **toute dépendance qui reçoit une adresse IP de visiteuse doit être déclarée, y compris quand elle n'est pas un sous-traitant au sens du RGPD.** Le raisonnement inverse est précisément ce qui avait laissé Turnstile invisible pendant des mois. Ici la dépendance est déclarée — il reste à la supprimer, comme annoncé.

**Ce qui compte comme fini.**

- Aucune requête ne part du navigateur vers un domaine tiers sur les pages de carte.
- La clé `privacy.s6.maptiles` est mise à jour dans les dix locales pour décrire le nouvel état.

**Dépendances.** Plus simple après **I2** (pile auto-hébergée), mais faisable avant.

*Renvois : `VERIF_confidentialite_tiers_2026-08-20` · `PLAN_DE_MARCHE §8` · `scripts/nominatim/`*

#### E6 — Découper les cinq écrans qui pèsent plus de cent kilooctets

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : React / JavaScript

**État vérifié au 29/08.** `BookDraftForm.jsx` fait **197 Ko**, `BibliotecaPage.jsx` 184 Ko, `AccountPage.jsx` 154 Ko, `PanelPage.jsx` 114 Ko, `ImportacoesPage.jsx` 109 Ko. 29 des 38 routes sont déjà en chargement paresseux, et `vite.config.js` déclare quatre lots de dépendances — le problème n'est pas le chargement initial, c'est la taille d'un fichier unique.

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

**État vérifié au 29/08.** `document.title` ne se met pas à jour lors d'une navigation dans l'application ; il ne change qu'au rechargement complet de la page.

**Ce que c'est.** Poser le titre à chaque changement de route, à partir des clés i18n existantes.

**Pourquoi ça compte.** Le titre de page est ce que lisent les lecteurs d'écran à l'arrivée, ce qui s'inscrit dans l'historique du navigateur, et ce qui apparaît dans un onglet épinglé. Un titre figé rend les trois inutilisables.

**Ce qui compte comme fini.**

- Le titre suit la route, dans les dix langues.
- Un test le vérifie, sur le modèle de `documentLanguage.test.js`.

**Dépendances.** Complément naturel de **E1**.

*Renvois : `Mémoire de projet, dette technique`*

#### E8 — Charger les deux polices sans bloquer l'affichage

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : React / JavaScript

**État vérifié au 29/08.** `titre.ttf` pèse 1 Mo et `accent.ttf` 484 Ko ; les deux sont chargées sans préchargement déclaré, sans `font-display: swap`, et sans `preconnect` vers Supabase.

**Ce que c'est.** Ajouter `font-display: swap`, précharger la police de titre seule, sous-ensembler les fichiers aux caractères réellement utilisés — dix langues dont le grec, donc le sous-ensemble n'est pas trivial.

**Pourquoi ça compte.** 1,5 Mo de polices sur une connexion de comptoir, c'est plusieurs secondes d'écran blanc. Le public d'AnarBib inclut des bibliothèques qui n'ont pas la fibre.

**Ce qui compte comme fini.**

- Le texte s'affiche avant les polices, avec une substitution acceptable.
- Le poids total des polices chargées à la première visite est mesuré avant et après.

**Dépendances.** Ne pas toucher à l'identité visuelle : `IDENT-1` à `IDENT-4` sont actés.

*Renvois : `Mémoire de projet, dette technique` · `REGISTRE §39 IDENT`*

#### E9 — Finir la mise en page mobile : trois lots identifiés

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : React / JavaScript

**État vérifié au 29/08.** Les phases A, B et C sont livrées et la doctrine graduée est actée. Trois questions restent ouvertes au REGISTRE : `MOB-Q1` (24 grilles déclarées en ligne dans le JSX avec des pistes `fr` nues), `MOB-Q2` (20 requêtes de média héritées à rapatrier dans `src/styles/mobile.css`), `MOB-Q3` (les onglets Validações et Inventário à convertir en cartes).

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

**État vérifié au 29/08.** Le socle terrain est livré : application installable, lecture de codes QR et ISBN, récolement, mise en page adaptative. Trois éléments restent, hérités du v32 et non revérifiés depuis : la permanence mobile (P3), la notification poussée (P5), et la planche de codes QR au format A4.

**Ce que c'est.** Commencer par vérifier lequel des trois est encore un manque réel. La notification poussée pose une question de fond avant une question de code : elle suppose un service tiers, ce que la doctrine anti-pistage regarde de près.

**Pourquoi ça compte.** La planche A4 est la plus simple et la plus utile au comptoir : elle permet d'étiqueter un fonds sans imprimante à étiquettes. Les deux autres méritent d'abord une conversation.

**Ce qui compte comme fini.**

- La planche A4 existe et s'imprime correctement.
- Pour la notification poussée, un verdict écrit : faisable sans tiers, ou renoncement assumé.

**Dépendances.** Hérité de `#MOBILE P3`, `#MOBILE P5`, `#MOB-QR-A4`.

*Renvois : `AnarBib-Backlog-2026-06-17-v33 §2.1`*

#### E11 — Les deux différés assumés de l'OPAC : tags contributifs et flux RSS

`P3` Différé · État : **Décision collective** · Charge : une soirée · Ce que ça demande : délibération collective, React / JavaScript

**État vérifié au 29/08.** `#OPAC5` (folksonomie, tags posés par les lectrices) est bloqué sur une décision de communauté et de vie privée. `#OPAC11` (flux RSS de recherche) est différé pour raison anti-pistage. Les deux sont ouverts depuis mai et n'ont jamais été instruits.

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
| **F4** | Vérifier les rappels d'échéance et les relances de retard | `P2` | À vérifier |
| **F5** | Vérifier que le délai de négociation de 21 jours est bien appliqué | `P2` | À vérifier |

#### F1 — Auditer la chaîne de courriel de bout en bout

`P1` Prioritaire · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : Deno / TypeScript, SQL / PostgreSQL

**État vérifié au 29/08.** **14 fonctions `notify-*` déployées**, cinq files d'attente, six déclencheurs de dépêche. Trois files n'ont jamais reçu la moindre insertion : `authority_proposal_notification_outbox`, `membership_expiry_notifications`, `painel_internal_task_invitation_outbox`. Une quatrième, `painel_internal_task_notification_outbox`, est vide après 34 insertions dont la dernière date du 04/06. Personne n'a jamais audité l'ensemble.

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

**État vérifié au 29/08.** Les courriels d'alerte d'exploitation — sauvegarde en échec, incident de sonde — utilisent le gabarit destiné aux lectrices. Ils finissent donc par « contacte la bibliothèque » suivi d'un numéro de téléphone.

**Ce que c'est.** Un gabarit d'exploitation distinct : pas de pied de page destiné au public, la commande à lancer, et le lien vers la section du runbook.

**Pourquoi ça compte.** **À corriger avant qu'un second administrateur réseau existe.** Aujourd'hui une seule personne reçoit ces alertes et sait les lire ; le jour où **A1** aboutit, elles partent à quelqu'un qui découvrira un courriel d'incident lui conseillant d'appeler la bibliothèque.

**Ce qui compte comme fini.**

- Un gabarit d'exploitation existe, distinct du gabarit lectrice.
- Une alerte de test a été reçue et relue par quelqu'un qui n'a pas écrit le code.

**Dépendances.** Doit précéder l'aboutissement de **A1**.

*Renvois : `RUNBOOK_exploitation_v0.3 §7` · `PLAN_DE_MARCHE §8`*

#### F3 — Consolider les fonctions de notification redondantes

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : Deno / TypeScript

**État vérifié au 29/08.** Quatre fonctions font des récapitulatifs : `notify-weekly-report`, `notify-network-weekly-report`, `notify-cross-library-digest`, `notify-rede-digest`. Trois fonctions servent des documents : `read-pdf`, `read-digital-asset`, `read-ill-shared-asset`. Deux exportent des lots : `export-catalog-lote`, `export-fonds-bundle`. Et `mail-i18n-test`, fonction de test, est déployée en production en version 1553.

**Ce que c'est.** Vérifier ce que chacune fait vraiment avant de conclure à la redondance — elles ont probablement des destinataires et des portées différentes. Puis fusionner ce qui doit l'être, et retirer `mail-i18n-test` de la production.

**Pourquoi ça compte.** 48 fonctions déployées, c'est beaucoup à maintenir pour un projet à un mainteneur. Chacune porte son propre gabarit, ses propres dix langues, ses propres secrets. Ce n'est pas un problème de performance, c'est un problème de surface à relire.

**Ce qui compte comme fini.**

- Chaque groupe a un verdict : fusion, ou raison écrite de la séparation.
- `mail-i18n-test` n'est plus déployée en production.
- Le compte de fonctions déployées est à jour dans `CLAUDE.md` et dans `config.toml`.

**Dépendances.** Après **F1**. Attention : le déploiement de `notify-event` ne passe pas par MCP, son paquet est trop gros.

*Renvois : `PLAN_DE_MARCHE §8` · `Relevé du 29/08/2026`*

#### F4 — Vérifier les rappels d'échéance et les relances de retard

`P2` Courant · État : **À vérifier** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL

**État vérifié au 29/08.** `spec-flux-emprunts.md` §10.2 prévoit des rappels à J-5, J-3 et le jour même, puis des relances à J+1, J+7 et J+30. **Aucun job dédié n'est identifiable** parmi les 36 crons ; le seul voisin est `anarbib-notify-mid-loan-reading-daily`, qui fait autre chose. `membership_expiry_notifications` n'a jamais reçu la moindre ligne.

**Ce que c'est.** Vérifier en base si les rappels partent par un autre chemin, et sinon, décider : les implémenter, ou amender la spec. Un emprunt en retard qui ne déclenche rien est un emprunt que personne ne réclame.

**Pourquoi ça compte.** Le suivi de huit semaines de la formation BLMF prévoit qu'une consulta soit menée de bout en bout avec négociation réelle : c'est le moment où l'absence de rappel se verra. Autant le savoir avant.

**Ce qui compte comme fini.**

- Un verdict écrit : les rappels existent par tel chemin, ou ils n'existent pas.
- Si absents : soit implémentés, soit la spec amendée.

**Dépendances.** Se vérifie en même temps que **F1**.

*Renvois : `spec-flux-emprunts.md §10.2` · `VERIF_etat_reel_gouvernance_et_crons_2026-08-26 §3` · `PLAN_formation_coordination_BLMF §5`*

#### F5 — Vérifier que le délai de négociation de 21 jours est bien appliqué

`P2` Courant · État : **À vérifier** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL

**État vérifié au 29/08.** Le cron `anarbib-reservation-expire-negotiation` tourne toutes les heures (`25 * * * *`) — alors que la spec de réservation v2 donnait ce délai comme **non implémenté**. Le mécanisme existe donc ; ce qu'il fait exactement n'a pas été vérifié.

**Ce que c'est.** Lire `fn_expire_negotiation_timeout()`, vérifier le délai qu'elle applique, et corriger la spec ou la fonction selon ce qu'on trouve.

**Pourquoi ça compte.** Un écart du même type a déjà été trouvé : la spec et le support de formation annonçaient une expiration des réservations toutes les six heures, alors que le cron tourne **toutes les heures**. Le support a été corrigé, la spec pas forcément.

**Ce qui compte comme fini.**

- Le délai réel est écrit dans la spec.
- Les fréquences annoncées dans les supports de formation correspondent aux crons réels.

**Dépendances.** Aucune.

*Renvois : `VERIF_etat_reel_gouvernance_et_crons_2026-08-26 §3` · `spec-workflow-reservation-v2-negotiation.md`*

---

### G — Réseau, gouvernance, fédération

*Beaucoup de circuits construits, très peu empruntés. C'est le principal enseignement du relevé.*

| | | | |
|---|---|---|---|
| **G1** | Emprunter les circuits construits et jamais utilisés | `P0` | Ouvert |
| **G2** | Trancher politiquement l'écart entre P2 et P8 sur la promotion à coordenador·a | `P1` | Décision collective |
| **G3** | Éprouver le circuit de promotion collégiale sur `blmf-teste` | `P1` | Ouvert |
| **G4** | Exercer les quatre courriels d'équipe jamais envoyés | `P1` | Ouvert |
| **G5** | Clarifier le statut de la Biblioteca Terra Livre | `P2` | À vérifier |
| **G6** | Donner un écran au prêt entre bibliothèques | `P2` | Ouvert |
| **G7** | Décider de l'admission de la Bibliothèque SOLIDAIRES | `P1` | Bloqué |
| **G8** | Compléter la cartographie avec les archives repérées ailleurs | `P2` | Ouvert |
| **G9** | Implémenter la cartographie du réseau selon la spec v1.0 | `P3` | Gelé |
| **G10** | Solder les trois questions d'onboarding marquées « au plus vite » | `P2` | Ouvert |

#### G1 — Emprunter les circuits construits et jamais utilisés

`P0` Structurel · État : **Ouvert** · Charge : plusieurs semaines · Ce que ça demande : délibération collective, aucune compétence technique

**État vérifié au 29/08.** Vérifié le 29/08 : **62 tables métier n'ont jamais reçu la moindre insertion.** Sept blocs entiers sont concernés — assemblées du réseau (3 tables), notes de lecture (2), propositions et objections d'autorité (3), référentiels de catalogage `catalog_ref_*` (8 sur 9), gouvernance des profils de bibliothèque (4, **alors que deux crons tournent dessus toutes les quinze minutes**), délibération sur les demandes d'adhésion (5, dont `library_request_votes` et `library_request_messages`).

**Ce que c'est.** Choisir un bloc et l'emprunter pour de vrai, du premier geste au dernier : tenir une assemblée du réseau, déposer une note de lecture, proposer une autorité et laisser quelqu'un objecter, faire délibérer une demande d'adhésion. Consigner ce qui manque, ce qui surprend, ce qui bloque.

**Pourquoi ça compte.** C'est le principal enseignement du relevé du 29 août, et il ne figure dans aucun document du corpus. **Le projet ne souffre pas d'un manque de fonctionnalités : il souffre d'un manque d'usage.** Un circuit jamais emprunté n'est pas livré — il est seulement écrit. Et le jour où il devient le chemin critique, comme le circuit d'invitation vient de le devenir pour les promotions, il casse sur des choses qu'un seul passage aurait révélées.

**Ce qui compte comme fini.**

- Au moins trois des sept blocs ont été empruntés de bout en bout, sur `blmf-teste` puis en réel.
- Chaque passage a produit un compte rendu écrit de ce qui manque.
- Les blocs dont l'usage n'est pas souhaité aujourd'hui sont marqués **dormants**, avec la raison — ce n'est pas un échec, c'est une information.

**Dépendances.** Le bloc « assemblée » dépend de **A1**. Les autres non.

*Renvois : `Relevé du 29/08/2026` · `REGISTRE §32 AG, §28 ATE, §26 ONBO`*

#### G2 — Trancher politiquement l'écart entre P2 et P8 sur la promotion à coordenador·a

`P1` Prioritaire · État : **Décision collective** · Charge : une soirée · Ce que ça demande : délibération collective

**État vérifié au 29/08.** La migration `20260826120000` **est en production** et tranche dans le sens de P2 : collégialité obligatoire, ratification préalable, repli à une signature quand il n'y a qu'une seule personne coordinatrice, consentement explicite de la personne promue, exclusion de cette personne du décompte du quorum. **Mais la décision politique n'a jamais été prise.**

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

**État vérifié au 29/08.** La migration est en production ; le runbook de déploiement en onze étapes est donc caduc. Ce qui reste est la **répétition en six pas sur `blmf-teste`**, jamais faite. Or `library_team_invitations` porte **zéro ligne** depuis sa création : le circuit que la migration rend obligatoire n'a jamais été emprunté une seule fois.

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

**État vérifié au 29/08.** Quatre courriels existent, sont câblés, et ne sont jamais passés en production : `team.self_demoted`, `team.suspended`, `team.removal_requested`, `team.inactive_warning_*`. Le mécanisme fonctionne — `team_notification_outbox` compte 21 envois et zéro échec — mais ces quatre-là n'ont jamais été déclenchés.

**Ce que c'est.** Provoquer chacun des quatre cas sur `blmf-teste`, lire le courriel reçu, vérifier qu'il dit ce qu'il doit dire dans les dix langues.

**Pourquoi ça compte.** Ces courriels annoncent à quelqu'un qu'il perd un rôle, qu'il est suspendu, ou qu'on demande son retrait. Ce sont les messages les plus délicats du système, et personne ne les a jamais lus tels qu'ils arrivent. Les deux personnes en formation à la coordination BLMF seront les premières concernées.

**Ce qui compte comme fini.**

- Les quatre courriels ont été reçus et relus.
- Le ton et le contenu sont validés par quelqu'un qui n'a pas écrit les gabarits.
- **D'abord sur `blmf-teste`, jamais directement sur la BLMF.**

**Dépendances.** Se fait avec **G3**, même bac à sable.

*Renvois : `VERIF_etat_reel_gouvernance_et_crons_2026-08-26 §2`*

#### G5 — Clarifier le statut de la Biblioteca Terra Livre

`P2` Courant · État : **À vérifier** · Charge : une soirée · Ce que ça demande : délibération collective

**État vérifié au 29/08.** La BTL porte `is_test_mode = true` et `email_delivery_mode = 'test_only'`, **alors qu'elle contient 2 187 exemplaires** — le plus gros fonds du réseau — et qu'elle est publiée sur le réseau. Posture voulue, ou reliquat de configuration ?

**Ce que c'est.** Demander à la BTL ce qu'elle veut, puis aligner la configuration. Si le mode d'essai est voulu, l'écrire quelque part pour que personne ne le « corrige ».

**Pourquoi ça compte.** En mode d'essai, les courriels ne partent pas. Une bibliothèque avec 2 187 exemplaires publiés dont les lectrices ne reçoivent aucune notification, c'est soit un choix, soit une panne silencieuse depuis des mois. La BTL a rejoint le réseau avec un statut « expérimental » assumé — mais un statut politique et un réglage technique ne sont pas la même chose.

**Ce qui compte comme fini.**

- La BTL a répondu, et la configuration correspond à sa réponse.
- Le statut est écrit là où quelqu'un le cherchera.

**Dépendances.** Aucune. Une conversation.

*Renvois : `PLAN_formation_coordination_BLMF §8`*

#### G6 — Donner un écran au prêt entre bibliothèques

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : React / JavaScript, bibliothéconomie

**État vérifié au 29/08.** Le cycle de vie du prêt entre bibliothèques est spécifié et implémenté en base : machine à états verrouillée, quatre triggers, cron `anarbib-peb-detect-overdue-daily` actif. **Aucun écran n'existe.** La base porte 2 prêts pour 20 insertions historiques.

**Ce que c'est.** Un écran de demande côté bibliothèque emprunteuse, un écran de traitement côté prêteuse, et l'affichage de l'état pour les deux. Les vues `interlibrary_loans_painel_ui` et `interlibrary_loan_items_ui` existent déjà.

**Pourquoi ça compte.** Le prêt entre bibliothèques est ce qui rend un réseau fédératif utile à ses lectrices, plutôt qu'une simple juxtaposition de catalogues. Aujourd'hui il a « une amorce en base, même sans écran » — ce qui veut dire que personne ne peut s'en servir.

**Ce qui compte comme fini.**

- Un prêt complet a été fait entre deux bibliothèques du réseau, par l'interface.
- Le flux « livre perdu ou abîmé » a un traitement écrit — **aucun flux ne le couvre aujourd'hui**, il se traite hors SIGB avec remontée en coordination.

**Dépendances.** `EA-12 phase 2` (parité PEB, environ 45 fonctions) est gelée par `BIBLIO-9` — à ne pas confondre avec cet item.

*Renvois : `spec-cycle-vie-peb.md` · `PLAN_formation_coordination_BLMF §5` · `REGISTRE §14 PEB`*

#### G7 — Décider de l'admission de la Bibliothèque SOLIDAIRES

`P1` Prioritaire · État : **Bloqué** · Charge : non chiffré · Ce que ça demande : délibération collective

**État vérifié au 29/08.** Décision fédérale **volontairement différée**, faute de pouvoir être prise à plusieurs. Échéance envisagée : octobre ou novembre, après Bologne.

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

**État vérifié au 29/08.** `cartography_entries` porte 187 fiches et le fichier `anarbib_bibliotheques_libertaires.geojson` en compte 121. Neuf archives repérées dans le réseau NORLA n'ont pas été confrontées à cette liste.

**Ce que c'est.** Vérifier lesquelles des neuf figurent déjà, et faire entrer les manquantes avec `source = "FICEDL"` ou `"NORLA"` selon leur provenance.

**Pourquoi ça compte.** La carte n'a d'intérêt que si elle est plus complète que ce que chacun connaît déjà. Et la traçabilité de la source est ce qui permettra plus tard de dire d'où vient chaque fiche sans avoir à redemander.

**Ce qui compte comme fini.**

- Les neuf archives ont un verdict : déjà présente, ou ajoutée avec sa source.
- Rappel : `statut_public` est à `FALSE` par défaut et **aucun import en masse** n'est autorisé (`MAP-E`).

**Dépendances.** Aucune. **Entrée sans compétence technique.**

*Renvois : `VEILLE_leftovers_maydayrooms_2026-08-19 §3.4` · `REGISTRE §34 MAP-E`*

#### G9 — Implémenter la cartographie du réseau selon la spec v1.0

`P3` Différé · État : **Gelé** · Charge : plusieurs semaines · Ce que ça demande : React / JavaScript

**État vérifié au 29/08.** Les arbitrages sont tranchés depuis le 18/06 : table dédiée, i18n hybride, carte publique comme route de l'application, moteur Leaflet, OpenStreetMap et Nominatim auto-hébergés, entrées non membres affichées avec un filtre clair. `MAP-I` (statut du prêt entre bibliothèques sur la carte interne) et `MAP-J` (auto-déclaration « ajouter ma bibliothèque » avec modération) restent différés. **L'implémentation est calendée post-Bologne, fin 2026 ou 2027.**

**Ce que c'est.** Reprendre la spec v1.0 quand la fenêtre s'ouvre. Attention : le REGISTRE porte **deux sections `MAP`** — le §2 est un squelette où tout est ouvert, le §34 est la version tranchée. Le §2 n'a ni tampon de supersession ni renvoi vers le §34 : **c'est le §34 qui vaut**.

**Pourquoi ça compte.** La carte est le premier objet qu'une bibliothèque qui découvre le réseau va regarder. Elle mérite d'être faite quand il y aura du temps pour la faire bien, et pas dans la fenêtre d'avant Bologne.

**Ce qui compte comme fini.**

- La carte publique est une route de l'application, servie sans requête vers un tiers (voir **E5**).
- Le §2 du REGISTRE porte un renvoi vers le §34.

**Dépendances.** Après Bologne. Lié à **E5** et **J5**.

*Renvois : `spec-cartographie-reseau.md v1.0` · `REGISTRE §34 MAP`*

#### G10 — Solder les trois questions d'onboarding marquées « au plus vite »

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : délibération collective

**État vérifié au 29/08.** Trois points sont marqués 🔴 « à résoudre au plus vite » depuis juin et n'ont pas bougé : `#111` (évaluation collaborative d'un·e administrateur·rice réseau, dormante), `ONBO-Q13` (transfert technique du mandat de coordination), et la finition du volet 10 de l'atelier d'onboarding.

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

**État vérifié au 29/08.** `parseDescriptor` sort par retour précoce avant d'atteindre le titre de page quand une fiche n'a pas de bloc de traduction. Résultat : **158 descripteurs de la facette « dates », soit un quart du thésaurus, sont enregistrés comme identifiants nus, sans libellé, donc non alignables.** Leurs liens vers les catalogues se perdent de la même façon. Le correctif `ficedl_scrape_titre_dates.patch` existe, passe `node --check`, et **n'a jamais été éprouvé contre le site**.

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

**État vérifié au 29/08.** L'export complet des 620 descripteurs dans les deux formats est **à une soirée de travail** — dès que les sept questions ont une réponse. Elles sont écrites et personne ne les a encore posées.

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

**État vérifié au 29/08.** 98 alignements existent en base entre les sujets locaux et les descripteurs FICEDL, en `exact` ou `close`. Le vocabulaire matière d'AnarBib est déjà exposé en SKOS. **Les correspondances vers la FICEDL ne le sont pas.**

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

**État vérifié au 29/08.** Le point d'accès OAI-PMH est déployé. **OPDS n'existe pas.** Or « les flux OPDS existent de part et d'autre mais ne pointent nulle part », et c'est la convention 1 du texte proposé aux autres catalogues.

**Ce que c'est.** Un flux OPDS 1.2 ou 2.0 sur le catalogue public, avec les facettes déjà disponibles. Quelques heures pour un premier flux.

**Pourquoi ça compte.** OPDS est ce que lisent les liseuses et les applications de lecture. C'est le format par lequel un fonds numérisé devient consultable sans passer par notre interface — et c'est la première des quatre conventions qu'AnarBib propose aux autres. **Il serait difficile de la proposer sans l'appliquer.**

**Ce qui compte comme fini.**

- Un flux OPDS est servi et lisible par au moins un client réel.
- Il respecte la visibilité : rien qui ne soit déjà public ne sort.

**Dépendances.** Aucune.

*Renvois : `docs/CHANTIERS_OUVERTS.md §4` · `CONVENTIONS_interoperabilite_catalogues_libertaires_2026-08-26 convention 1`*

#### H5 — Éprouver la moisson OAI-PMH dans les deux sens

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : Deno / TypeScript, administration système

**État vérifié au 29/08.** Le chemin est exécutable depuis le 28/08 : fonction `harvest-oai-pmh` déployée, cron `anarbib-oai-harvest-weekly` posé. **Le cron n'a jamais tourné** — première occurrence prévue mardi à 04h20. Et le point d'accès `oai-pmh-provider` **n'a jamais été moissonné depuis l'extérieur**.

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

**État vérifié au 29/08.** NORLA a bâti son vocabulaire — avec ses facettes *Tactics* et *Social Movement* — **sans lien avec le thésaurus FICEDL**. Deux vocabulaires militants, construits en parallèle, qui s'ignorent. Par ailleurs, les 11 catégories thématiques d'AnarcosyndicalismeBOOK ne sont alignées sur rien.

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

**État vérifié au 29/08.** `CONVENTIONS_interoperabilite_catalogues_libertaires_2026-08-26` est un **brouillon qui n'engage personne et n'a jamais été discuté avec aucune organisation**. Il propose quatre conventions et une demande unique à la FICEDL.

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
| **I5** | Faire savoir qu'un workflow a échoué | `P1` | Ouvert |
| **I6** | Purger les relevés de la sonde de santé | `P2` | Ouvert |
| **I8** | Mettre `deploy/README.md` en accord avec ce qui a été exécuté | `P2` | Ouvert |
| **I9** | Corriger les trois migrations horodatées dans le futur | `P2` | Ouvert |
| **I10** | Nettoyer les traces de Turnstile et les fichiers de rebut | `P2` | Ouvert |
| **I11** | Sortir de `node:20`, en fin de maintenance | `P2` | Ouvert |
| **I12** | Automatiser le rafraîchissement du miroir froid | `P2` | Ouvert |
| **I13** | Finir la bascule vers le nouveau moteur de pages | `P3` | Ouvert |
| **I15** | Réécrire les trois suites de circulation d'avant la CI | `P2` | En cours |

#### I1 — Aligner l'image GoTrue sur l'état réel des migrations d'authentification

`P1` Prioritaire · État : **Gelé** · Charge : quelques jours · Ce que ça demande : administration système

**État vérifié au 29/08.** La production porte **77 migrations `auth`**, la dernière datée du 25/06. L'image épinglée dans `deploy/.env` est `GOTRUE_TAG=v2.189.0`, qui en porte **69**. `deploy/.env.example` indique `v2.192.0`. L'écart est un **bloquant de correction**, pas de confort.

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

**État vérifié au 29/08.** La pile est réduite de douze à **six conteneurs** (`db`, `rest`, `auth`, `storage`, `functions`, `caddy`), les versions sont épinglées, `bootstrap.sh` a été exécuté pour de vrai le 26/08 avec huit défauts relevés et corrigés, et la répétition du 18/08 a rejoué 124 migrations et restauré un dump de production en 17 secondes. Reconstruction complète mesurée : **25 minutes**.

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

**État vérifié au 29/08.** `supabase/functions/main/index.ts` existe (6,9 Ko), lit `config.toml` au démarrage, applique un **refus par défaut** — seules les dispenses `verify_jwt = false` sont lues, tout le reste exige un jeton — et refuse de démarrer si le fichier est illisible. **Les quatre tests prévus n'ont pas été passés.**

**Ce que c'est.** Les quatre tests de l'étape 5 de `deploy/REPETITION.md` : fonction protégée sans en-tête d'autorisation → 401 ; avec un jeton valide → 200 ; `health-probe` sans jeton → 200 ; nom inexistant → 404.

**Pourquoi ça compte.** Le routeur est ce qui remplace la protection par défaut de la plateforme le jour de la bascule. Comme `config.toml` ne déclare que 31 fonctions sur 48, **le refus par défaut du routeur fermera dix-huit fonctions qui fonctionnent aujourd'hui** — il faut le savoir avant, pas après.

**Ce qui compte comme fini.**

- Les quatre tests passent.
- Le comportement pour les 18 fonctions non déclarées est connu et voulu.

**Dépendances.** **Bloqué par B6.** Gelé sur la production jusqu'au 14/09 ; le test en environnement d'essai est ouvert.

*Renvois : `deploy/README.md` · `deploy/REPETITION.md étape 5`*

#### I4 — Finir le témoin de provenance des sauvegardes

`P1` Prioritaire · État : **Ouvert** · Charge : une soirée · Ce que ça demande : administration système

**État vérifié au 29/08.** La migration `20260827180000_temoin_sauvegarde_provenance.sql` est **éprouvée sur un PostgreSQL 16 jetable, avec sept contrôles passés, mais jamais jouée contre la production**. Le correctif `health_probe_provenance.patch` **ne s'applique pas** : `patch failed … index.ts:286`. Il a été produit contre le miroir GitHub. Échéance du 28/08, donc échue.

**Ce que c'est.** Départager le conflit par `git hash-object` sur le fichier cible, comparé au blob de base `0d00dc0e016fdfb86ef314e4e707abd4a84d1d2c`. **Empreinte identique → `git apply --3way` passe. Empreinte différente → refaire le correctif à la main sur la version réelle : ne pas forcer, ne pas écraser.** Puis déployer `health-probe`.

**Pourquoi ça compte.** Ce que le correctif doit obtenir, quelle que soit la voie : dans le courriel, chaque flux affiche son hôte (ou « aucune ») et une mention explicite quand il s'agit d'un amorçage ; dans la raison de sauvegarde, `(dernière source : …)` ou `(aucun signal reçu)`. Sans cela, un courriel vert ne dit pas d'où vient le vert — et c'est exactement le défaut qui a laissé les sauvegardes échouer 36 heures en silence.

**Ce qui compte comme fini.**

- La migration est posée dans `supabase/migrations/` et appliquée.
- `health-probe` est déployée avec le comportement de provenance.
- **`temoin_sauvegarde_provenance.patch` est périmé : à ignorer, ne pas l'appliquer.**

**Dépendances.** Ne pas confondre avec le `snapshot_id` nul sur cinq lignes : le remède tient en trois lignes mais **`anarbib-bg2.sh` vit sur le poste de travail, hors dépôt** — c'est à signaler, pas à tenter depuis le dépôt.

*Renvois : `NOTE_temoin_sauvegarde_2026-08-27` · `REPRISE_claude_code_2026-08-27 chantier 1`*

#### I5 — Faire savoir qu'un workflow a échoué

`P1` Prioritaire · État : **Ouvert** · Charge : une soirée · Ce que ça demande : administration système

**État vérifié au 29/08.** Un job d'alerte existe dans les deux workflows : il ouvre une issue sur la forge, avec anti-doublon. Pourtant `sql-tests` **est resté rouge du 17 au 20 août sans que personne le voie**. Le constat écrit est clair : « même angle mort que les sauvegardes, et il n'est pas couvert ».

**Ce que c'est.** Faire sortir l'alerte de la forge : un courriel, ou le même canal que les alertes de sauvegarde. Une issue ouverte sur un dépôt que personne ne surveille n'alerte personne.

**Pourquoi ça compte.** Le principe est déjà écrit pour les sauvegardes : **une alarme jamais déclenchée n'est pas une alarme.** Et un pipeline qui échoue une fois sur deux cesse d'être lu — ce qui est exactement ce qui s'est passé.

**Ce qui compte comme fini.**

- Un échec de workflow produit un signal hors de la forge.
- Le signal a été éprouvé en le déclenchant volontairement.
- Leçon de méthode déjà payée : **ne pas livrer de CI sans l'avoir vue passer au vert et au rouge.**

**Dépendances.** Aucune.

*Renvois : `RUNBOOK_exploitation_v0.3 §7 §9.3` · `REGISTRE §38 OPS-6`*

#### I6 — Purger les relevés de la sonde de santé

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL

**État vérifié au 29/08.** `service_health_probes` porte **13 932 lignes** et croît de 288 par jour, sans aucun cron de purge — alors que sept autres purges existent dans les 36 jobs.

**Ce que c'est.** Un cron de purge sur le modèle de `anarbib-catalog-audit-snapshot-purge`, avec une rétention à décider — trente jours suffisent probablement, les incidents étant conservés à part dans `service_health_incidents`.

**Pourquoi ça compte.** C'est la table la plus volumineuse de la base, et elle ne contient que du bruit dont l'utile a déjà été extrait. À ce rythme elle atteindra cent mille lignes avant la fin de l'année, ce qui alourdira chaque sauvegarde pour rien.

**Ce qui compte comme fini.**

- Un cron de purge existe, avec une rétention écrite.
- `service_health_incidents` n'est pas touchée par la purge.

**Dépendances.** Aucune.

*Renvois : `Relevé du 29/08/2026` · `REGISTRE §38 OPS`*

#### I8 — Mettre `deploy/README.md` en accord avec ce qui a été exécuté

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : administration système

**État vérifié au 29/08.** Le document affirme en gras : « Rien de tout ceci n'a encore tourné ». Trois commits du 26/08 décrivent des exécutions réelles avec huit défauts relevés. Par ailleurs `bootstrap.sh` a **huit étapes** plus une « 7 bis » et une vérification, là où le README en annonce sept ; et le README déclare `notify-cross-library-digest` « absente du dépôt » alors qu'elle y est.

**Ce que c'est.** Réécrire la section d'état à partir des journaux d'exécution du 26/08, corriger le compte d'étapes, et retirer l'affirmation sur `notify-cross-library-digest`.

**Pourquoi ça compte.** `deploy/README.md` est le document que lira quelqu'un qui prend **A2** — la reconstruction par un tiers. Une phrase qui dit « rien n'a tourné » va lui faire croire qu'il essuie les plâtres alors que huit défauts ont déjà été trouvés et corrigés pour lui.

**Ce qui compte comme fini.**

- La section d'état décrit ce qui a tourné et ce qui n'a pas tourné.
- Les quatre points « à confirmer avant bascule » ont un verdict : GoTrue et le courriel, `PGRST_DB_SCHEMAS` mis à `public,api,storage` par déduction, le cas `notify-cross-library-digest` (clos), et le rejeu des migrations.
- `CADDY_TAG=2` est un tag majeur flottant dans un fichier qui proclame « aucun `latest`, jamais » : à épingler ou à justifier.

**Dépendances.** Prérequis moral de **A2**.

*Renvois : `deploy/README.md` · `Commits 57321385, 35c03dd5, 90266600`*

#### I9 — Corriger les trois migrations horodatées dans le futur

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : administration système

**État vérifié au 29/08.** `20260830090000`, `20260830110000` et `20260830130000` sont appliquées en production alors que la date du jour est le **29/08**. Elles portent un horodatage du lendemain.

**Ce que c'est.** Rien à défaire — les migrations sont appliquées et fonctionnent. Ce qu'il faut, c'est comprendre d'où vient le décalage (fuseau horaire du poste, ou choix manuel) et poser un garde-fou.

**Pourquoi ça compte.** Le nom d'une migration est aussi sa position dans l'ordre de rejeu. Un horodatage en avance sur l'horloge crée une fenêtre où une migration écrite plus tard trie avant elle. La doctrine dit déjà de vérifier l'horodatage UTC avant de choisir — le garde-fou manque.

**Ce qui compte comme fini.**

- La cause est identifiée.
- Le hook `pre-commit` refuse une migration dont l'horodatage est dans le futur.

**Dépendances.** Aucune.

*Renvois : `Relevé du 29/08/2026` · `REPRISE_claude_code_conventions_2026-08-20`*

#### I10 — Nettoyer les traces de Turnstile et les fichiers de rebut

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : administration système

**État vérifié au 29/08.** Turnstile a été entièrement retiré du code le 20/08 — sa réapparition serait une régression. Mais des **clés de test subsistent** dans `.env.example` (deux entrées), `.env.local`, `deploy/functions.env`, une référence dans `package.json`, et un secret au Vault. Par ailleurs `tmp-ficedl/` (754 Ko, doublon exact d'un fichier versionné) traîne à la racine, et `docs/drafts/` est versionné sans règle.

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

**État vérifié au 29/08.** Les trois jobs d'intégration continue tournent dans un conteneur `node:20`, dont la fenêtre de maintenance à long terme s'est achevée en avril 2026. C'est le point de fin de vie le plus net de la chaîne.

**Ce que c'est.** Passer à la version en maintenance longue suivante, vérifier que le build, les tests et le lint passent, et que la CLI Supabase épinglée `v2.98.1` s'y installe.

**Pourquoi ça compte.** Une image sans mises à jour de sécurité fait tourner tout le déploiement. Le changement est mécanique et se vérifie en une exécution.

**Ce qui compte comme fini.**

- Les trois jobs tournent sur une version maintenue.
- Le lint reste à zéro erreur (environ cent avertissements est l'état normal).

**Dépendances.** Aucune.

*Renvois : `.forgejo/workflows/ci.yml` · `package.json`*

#### I12 — Automatiser le rafraîchissement du miroir froid

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : administration système

**État vérifié au 29/08.** Le miroir froid `anarbib-mirror.git` existe sur le poste de travail et son rafraîchissement est manuel. Les unités systemd `anarbib-mirror-refresh.service` et `.timer` sont versionnées dans `deploy/ops/` mais leur mise en service n'est pas confirmée.

**Ce que c'est.** Vérifier que le minuteur tourne, et sinon le mettre en service. Consigner la fraîcheur du miroir quelque part de lisible.

**Pourquoi ça compte.** Une reconstruction demande **trois** choses et non deux : le dépôt, une sauvegarde, **et les secrets du Vault**. Le miroir froid est la troisième copie du dépôt, après Codeberg et le miroir GitHub. Il ne sert que s'il est à jour — et le miroir GitHub a déjà accumulé 6 878 objets de retard une fois.

**Ce qui compte comme fini.**

- Le rafraîchissement est automatique et son échec alerte.
- La fraîcheur du miroir apparaît dans le témoin de sauvegarde.

**Dépendances.** Lié à **I4**.

*Renvois : `RUNBOOK_exploitation_v0.3 §4 §9.1`*

#### I13 — Finir la bascule vers le nouveau moteur de pages

`P3` Différé · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : administration système

**État vérifié au 29/08.** L'étape 0 est concluante depuis le 20/08 : `test.anarbib.org` est servi par le nouveau moteur en parallèle. La chaîne d'intégration continue utilise déjà l'action `git-pages`. **Codeberg Pages en version historique est en mode maintenance, pas en fin de vie** — la documentation dit qu'il continuera de fonctionner indéfiniment. D'où la priorité basse.

**Ce que c'est.** Poser l'enregistrement TXT de liste blanche, créer `public/_redirects` avec la règle de réécriture, vérifier qu'une route inconnue renvoie 200 avec le bon contenu, puis nettoyer **seulement après** vérification verte.

**Pourquoi ça compte.** Deux points de vigilance sont écrits. **Ne pas toucher aux enregistrements A et AAAA**, qui sont bons. Et **vérifier la casse de l'URL** : le workflow écrit `AnarBib`, la documentation écrit `anarbib` — en cas de doute, poser les deux enregistrements TXT.

**Ce qui compte comme fini.**

- Le site est servi par le nouveau moteur, avec les routes inconnues en 200.
- Le nettoyage est fait après vérification : `public/.domains`, la branche `pages`, les secrets devenus inutiles.
- **Laisser `public/CNAME`** — il sert au miroir GitHub.
- Incertitudes assumées : la réversibilité de la bascule n'est documentée nulle part, aucune limite chiffrée n'est publiée (taille, bande passante, délai), et les fichiers vendorisés pèsent lourd — **point à surveiller au premier déploiement**.

**Dépendances.** P1, pas P0 — la version historique n'a pas de date d'arrêt annoncée.

*Renvois : `PLAN_migration_git_pages_2026-08-19` · `RUNBOOK_exploitation_v0.3`*

#### I15 — Réécrire les trois suites de circulation d'avant la CI

`P2` Courant · État : **En cours** · Charge : plusieurs semaines · Ce que ça demande : SQL / PostgreSQL

**État vérifié au 29/08.** `paquet19`, `paquet24` et `paquet25` sont des artefacts écrits pour le SQL Editor, avant que la CI existe. **Première passe faite le 30/08** : le seed fournit désormais un monde de circulation complet — deux emprunts (un ouvert, un clos), un emprunt de la coordination, une consulta en `em_preparacao` et une réservation active, sur **trois holdings distincts** parce que le modèle porte deux invariants croisés (on ne réserve pas ce qui est en consulta, on ne consulte pas ce qui est réservé) et que les entasser fabriquerait un état que le produit refuse. Les SKIP sont passés de vingt et un à quelques-uns. Restent les défauts de **conception** : des gardes qui reconnaissent une erreur par une sous-chaîne de son message plutôt que par son code, et onze branches de `paquet25` qui se désactivent au motif que « la simulation de JWT ne marche pas dans le SQL Editor » — vestige d'un temps où il n'y avait pas de CI, et faux depuis que le stub d'authentification est réparé.

**Ce que c'est.** Reprendre chaque garde d'erreur pour qu'elle teste un code, pas une phrase — et supprimer les onze branches `jwt sim`, qui mentent sur ce que la CI sait faire. Écrire les deux chemins nominaux encore annoncés « E2E non écrit » dans `emprestimos` et `reservas`.

**Pourquoi ça compte.** Elles couvrent le cœur de la circulation — emprunts et consultations. Les rafistoler a permis de savoir ce qu'elles cachaient ; les rafistoler encore reviendrait à entretenir un filet dont on connaît les trous. Une garde qui reconnaît une erreur à une sous-chaîne se tait le jour où le message change de langue.

**Ce qui compte comme fini.**

- Aucune branche `jwt sim` ne subsiste : la simulation de JWT fonctionne, et une suite ne se désactive pas sur une croyance périmée.
- Chaque garde d'erreur teste un code (`loan_not_found`, `loan_action_not_allowed`…), pas une sous-chaîne de message — un message change de langue, un code non.
- Les deux chemins nominaux `emprestimos` et `reservas` sont écrits, ou l'on dit pourquoi ils ne le seront pas.
- Les trois bilans suivent la convention `NOM OK : N/N`.

**Dépendances.** Aucune. **I7** a livré le run vert de référence et le seed étoffé ; les onze SKIP de `paquet19` relèvent désormais de cet item.

*Renvois : `Journaux de CI sql-tests des 29 et 30/08/2026` · `supabase/seed.sql` · `tests/sql/paquet19_loan_wrappers_tests.sql`*

---

### J — Documentation et corpus

*Le corpus est vaste et sa dérive est mesurée. Ce backlog en fait partie.*

| | | | |
|---|---|---|---|
| **J1** | Mettre à jour les chiffres de `CLAUDE.md` et du `README.md` | `P1` | Ouvert |
| **J2** | Réparer l'index des backlogs et trancher la convention d'archivage | `P2` | Ouvert |
| **J3** | Corriger les trois affirmations fausses de la spec des consultations | `P1` | Ouvert |
| **J4** | Réécrire la section 14 de la spec de gouvernance des rôles | `P1` | Ouvert |
| **J6** | Écrire les cinq doctrines internalisées là où un tiers les trouverait | `P2` | Ouvert |

#### J1 — Mettre à jour les chiffres de `CLAUDE.md` et du `README.md`

`P1` Prioritaire · État : **Ouvert** · Charge : une soirée · Ce que ça demande : aucune compétence technique

**État vérifié au 29/08.** `CLAUDE.md` se trompe sur sept chiffres — dont la ligne `verify_jwt`, qui décrit une protection inexistante (voir **B6**). La section d'état du `README.md` est **datée du 7 juillet 2026**, soit 345 commits en arrière.

**Ce que c'est.** Reprendre la photo chiffrée de ce backlog et l'y reporter, en datant chaque chiffre. Puis décider si ces chiffres ont leur place dans un document qu'on ne relit pas : peut-être un renvoi vers le backlog vaut-il mieux qu'une copie.

**Pourquoi ça compte.** `CLAUDE.md` n'est pas versionné — il vit sur une seule machine, retiré du dépôt le 07/07. Ses chiffres faux ne sont donc corrigibles que par une personne, et invisibles pour toutes les autres. C'est un cas particulier de **A2**.

**Ce qui compte comme fini.**

- Les sept chiffres sont corrigés et datés.
- La section d'état du `README.md` porte une date récente.
- Une décision est prise sur l'endroit où ces chiffres doivent vivre — un seul.

**Dépendances.** Aucune.

*Renvois : `Relevé du 29/08/2026` · `CLAUDE.md`*

#### J2 — Réparer l'index des backlogs et trancher la convention d'archivage

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : aucune compétence technique

**État vérifié au 29/08.** Le tableau d'historique de `docs/backlogs/INDEX.md` s'arrête au v31 : **la ligne du v32 manque**, alors que le fichier est bien dans `archive/`. Et deux conventions de nommage des archives coexistent — avec ou sans le préfixe `-archive-` —, point ouvert explicite jamais porté au REGISTRE.

**Ce que c'est.** Ajouter la ligne du v32, celles du v33 et du v34, et trancher la convention d'archivage en une phrase inscrite au REGISTRE.

**Pourquoi ça compte.** L'index des backlogs est ce qui permet de savoir quelle version fait foi. Une lignée avec un trou et deux conventions concurrentes ne remplit pas cet office.

**Ce qui compte comme fini.**

- Le tableau est complet du v8 au v34.
- Une seule convention de nommage est inscrite au REGISTRE.

**Dépendances.** Se fait en posant ce backlog.

*Renvois : `docs/backlogs/INDEX.md`*

#### J3 — Corriger les trois affirmations fausses de la spec des consultations

`P1` Prioritaire · État : **Ouvert** · Charge : une soirée · Ce que ça demande : aucune compétence technique

**État vérifié au 29/08.** `spec-flux-consultations-v2.2.md` affirme, section profils, que la BLMF est en `full_sigb`, la BTL en `informal` et `BLT-test` en `informal`, le tout « vérifié en prod ». **Les trois sont fausses aujourd'hui** : `BLT-test` n'existe pas en base, et la BTL est en `full_sigb`.

**Ce que c'est.** Relever l'état réel des cinq bibliothèques et le reporter, avec la date du relevé.

**Pourquoi ça compte.** Une affirmation marquée « vérifié en prod » qui ne l'est plus est plus dangereuse qu'une affirmation non marquée : elle décourage la vérification. C'est la leçon centrale de ce backlog.

**Ce qui compte comme fini.**

- La section décrit l'état réel, daté.
- Toute affirmation « vérifié en prod » du corpus porte désormais sa date.

**Dépendances.** Lié à **G5** (statut de la BTL).

*Renvois : `PLAN_formation_coordination_BLMF §8`*

#### J4 — Réécrire la section 14 de la spec de gouvernance des rôles

`P1` Prioritaire · État : **Ouvert** · Charge : une soirée · Ce que ça demande : aucune compétence technique

**État vérifié au 29/08.** `spec-gouvernance-roles.md` §14 liste comme « à implémenter » des choses **qui tournent en production** : la table d'audit `library_membership_audit` (alimentée, huit entrées récentes), les colonnes de carence `pending_removal_until` et `pending_removal_requested_by`, les courriels `team.*` (21 envois, zéro échec), et les deux crons `anarbib-team-pending-removal-complete` et `anarbib-team-inactive-cleanup`. La §5.3 est également périmée : la transition T2 n'est plus unilatérale.

**Ce que c'est.** Réécrire les deux sections d'après l'état vérifié du 26/08, et passer la version à jour — le REGISTRE cite déjà une v1.4 que l'index des specs ignore.

**Pourquoi ça compte.** Une spec qui sous-estime le livré fait refaire ce qui existe. C'est la dérive de sens inverse de **J3**, et les deux ont été relevées le même jour.

**Ce qui compte comme fini.**

- Les §14 et §5.3 décrivent l'état réel.
- La version de la spec est la même au REGISTRE et dans `docs/specs/INDEX.md`.
- La doctrine du rôle exclusif est notée comme appliquée par la RPC elle-même, pas seulement écrite — la promotion du 26/08 en donne la trace : ligne `coordenador` créée active, ligne `librarian` passée à `removed` au même horodatage, deux entrées d'audit, notification en 2,5 secondes.

**Dépendances.** Aucune.

*Renvois : `VERIF_etat_reel_gouvernance_et_crons_2026-08-26 §2` · `REGISTRE §41 GOUV`*

#### J6 — Écrire les cinq doctrines internalisées là où un tiers les trouverait

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : aucune compétence technique

**État vérifié au 29/08.** Cinq règles de conception sont appliquées partout et écrites nulle part d'accessible : l'ordre des mises à jour dans une RPC (le récit avant l'état), la distinction entre `workflow_note` et `schedule_reply_note`, l'interdiction d'`async` dans `onAuthStateChange`, les pièges d'encodage sous PowerShell, et le contrat `actionBox` de la fonction de rendu des courriels.

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

**État vérifié au 29/08.** Un projet d'acte est rédigé et archivé. Il n'a pas été adopté. **C'est le préalable politique à l'ouverture de tout canal d'encaissement : rien ne bouge avant.**

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

**État vérifié au 29/08.** Liberapay est en ligne et a reçu son premier don le 27/08. L'encart « soutenir financièrement » est publié dans les dix locales et nomme Liberapay comme unique canal ouvert. **Pix et IBAN dorment** dans un bloc de commentaire HTML entre les marqueurs `ENCART-DORMANT-START` et `ENCART-DORMANT-END`. Wero est en attente d'une réponse de l'établissement bancaire.

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

**État vérifié au 29/08.** `FINANCES.md` est à la racine du dépôt vitrine et dix pages publiques en sont engendrées, par langue. Le générateur signale nommément toute cellule non traduite. Un tableau distinct porte ce qu'une personne a avancé avant que le fonds existe — environ **228 € de mars à août 2026** — et la question de savoir si c'est une dette à rembourser est laissée à l'assemblée.

**Ce que c'est.** Consigner chaque recette et chaque dépense au fil de l'eau, et relancer le générateur après chaque édition.

**Pourquoi ça compte.** **Consigner les avances passées dès maintenant, avant la délibération** — dans un an, personne ne se souviendra des montants. Le régime de transparence choisi est le rapport annuel plus les comptes sur demande ; il ne tient que si le registre est à jour.

**Ce qui compte comme fini.**

- Le registre est à jour et les dix pages reflètent son contenu.
- Anticipation notée : le renouvellement du domaine en mars 2027 coûtera plus cher, la promotion de première année ne se reconduisant pas.

**Dépendances.** Indépendant de **K1** et **K2**.

*Renvois : `PLAN_financement_AnarBib_2026-08-25` · `tools/build-finances-pages.cjs`*

#### K4 — Corriger le générateur des pages de vie privée sur la langue déclarée

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : aucune compétence technique

**État vérifié au 29/08.** Les pages écrites à la main portent `<html lang="pt-BR">` ; `tools/build-privacy-pages.cjs` émet `lang="pt"`. **Les pages ont raison, le script a tort.**

**Ce que c'est.** Corriger le script pour qu'il émette l'étiquette complète, et vérifier que le générateur des pages de comptes, bâti sur le même modèle, ne reproduit pas le défaut.

**Pourquoi ça compte.** L'attribut de langue est ce qu'utilisent les lecteurs d'écran pour choisir leur prononciation. `pt` fera lire du portugais du Portugal à un public brésilien. C'est le même critère WCAG 3.1.1 que le projet a déjà corrigé côté application.

**Ce qui compte comme fini.**

- Le script émet l'étiquette complète.
- Les pages engendrées et les pages écrites à la main concordent.

**Dépendances.** Aucune.

*Renvois : `Dépôt vitrine anarbib/pages` · `tools/build-privacy-pages.cjs`*

#### K5 — Tenir l'intervention de Bologne et en tirer les suites

`P1` Prioritaire · État : **En cours** · Charge : quelques jours · Ce que ça demande : délibération collective

**État vérifié au 29/08.** Atelier AnarBib le 12/09 au matin, assemblée ouverte le 13. Un jeu de 29 diapositives italien-anglais est prêt, ainsi qu'une brochure manifeste bilingue. Trois objectifs annoncés : la genèse et la conception, le panorama des fonctionnalités, et **un appel à participation**.

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

**État vérifié au 29/08.** **Le message est parti** — autour du 19/08, soit trois semaines avant la rencontre, ce qui était exactement la fenêtre visée : assez tôt pour qu'ils regardent AnarBib sans que ce soit urgent. **L'atelier AnarBib est le matin, l'atelier leftove.rs l'après-midi du 12/09, même salle, même journée.** Ce qui reste ouvert, ce sont les réponses et la préparation de la journée.

**Ce que c'est.** Relancer si besoin, et préparer les trois questions posées pour qu'elles se discutent sur place : le vocabulaire de sujets, le profil de numérisation (ils ont 16 000 documents océrisés), et NORLA et la cartographie. Plus la question sur l'auto-hébergement au collectif technique présent.

**Pourquoi ça compte.** Deux ateliers le même jour dans la même salle, sur des sujets voisins, sans que les deux équipes se soient parlé, serait un gâchis. Et il y a un point à regarder avant, pas après : **leftove.rs est sous licence CC BY-NC-SA, et la clause non commerciale n'est pas une licence libre au sens strict.**

**Ce qui compte comme fini.**

- Les trois questions ont une réponse, ou un créneau de discussion est calé pour le 12/09.
- **Point à regarder avant la rencontre, pas après** : leftove.rs est sous licence CC BY-NC-SA, et la clause non commerciale n'est pas une licence libre au sens strict.

**Dépendances.** Le 12/09, dans la journée. Lié à **D4** (matériel éphémère) et **H6** (alignement des vocabulaires).

*Renvois : `VEILLE_leftovers_maydayrooms_2026-08-19` · `CALENDRIER_bologne_2026-08-27`*

#### K7 — Mener la formation des deux coordinations BLMF jusqu'à l'autonomie

`P1` Prioritaire · État : **En cours** · Charge : plusieurs semaines · Ce que ça demande : délibération collective

**État vérifié au 29/08.** Le matériel est livré : 89 diapositives en portugais du Brésil, six modules, trois rencontres, six exercices pratiques, notes d'animation dans chaque diapositive. Ni l'une ni l'autre des deux personnes n'est bibliothécaire ou informaticienne.

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

**État vérifié au 29/08.** `ORIENTATION_outils_bibliotheques_militantes_2026-08-26` est un **squelette destiné à être co-signé**. Six points sont explicitement à vérifier ou à trancher, et la section finale — celle qui porte l'appel — reste à écrire.

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

Backlog v34, 2026-08-29. Remplace `AnarBib-Backlog-2026-06-17-v33.md`. 90 items sur 11 domaines. Chaque état a été vérifié le 29/08/2026 contre la base de production en lecture seule et contre le dépôt Codeberg au commit `1d00ed2c`. Ce document n'arbitre rien : le `REGISTRE_decisions.md` fait foi.
