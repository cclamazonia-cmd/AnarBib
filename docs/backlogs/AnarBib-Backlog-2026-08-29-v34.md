# Backlog AnarBib v34 — Réécriture intégrale sur état vérifié — outil de travail pour les collaboratrices et collaborateurs à venir

**2026-08-29** · mis à jour le **2026-10-04** · 74 items · Versão em português : `AnarBib-Backlog-2026-08-29-v34.pt-BR.md`

> Fichier **engendré** par `scripts/build-backlog.cjs` depuis `backlog-v34.json`. Ne le modifiez pas à la main.

---

## Sommaire

- [Pourquoi une réécriture](#pourquoi-une-réécriture)
- [Mode d'emploi](#mode-demploi)
- [L'état réel au 29 septembre 2026](#létat-réel-au-29-septembre-2026)
- [Écarts relevés entre le réel et l'écrit](#écarts-relevés-entre-le-réel-et-lécrit)
- [Le calendrier contraint](#le-calendrier-contraint)
- [Dix règles payées par un incident](#dix-règles-payées-par-un-incident)
- [Les chantiers](#les-chantiers)
    - [A — Soutenabilité collective](#a--soutenabilité-collective) · 2
    - [B — Base de données, sécurité, RLS](#b--base-de-données-sécurité-rls) · 3
    - [C — Catalogage et données documentaires](#c--catalogage-et-données-documentaires) · 8
    - [D — Périodiques, éphémères, ressources numériques](#d--périodiques-éphémères-ressources-numériques) · 5
    - [E — Front, OPAC, i18n, accessibilité](#e--front-opac-i18n-accessibilité) · 11
    - [F — Courriel et notifications](#f--courriel-et-notifications) · 8
    - [G — Réseau, gouvernance, fédération](#g--réseau-gouvernance-fédération) · 7
    - [H — Interopérabilité, thésaurus, moisson](#h--interopérabilité-thésaurus-moisson) · 19
    - [I — Auto-hébergement, exploitation, sauvegardes, CI](#i--auto-hébergement-exploitation-sauvegardes-ci) · 3
    - [J — Documentation et corpus](#j--documentation-et-corpus) · 2
    - [K — Caisse, communication, formation](#k--caisse-communication-formation) · 6
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

## L'état réel au 29 septembre 2026

**Relevé du 29 septembre 2026 au soir** (`75ccb035`) — production interrogée en lecture seule et dépôt recompté ; **toutes les lignes ont été remesurées** (précédent relevé complet : 28/09 au soir, `f36b4638`). Une journée à deux sessions : **7 migrations** (398 appliquées = 398 au dépôt, toutes par la CI), 33 commits, 1 531 tests JS et 150 suites SQL, tous verts. Ce qui a bougé et pourquoi : **les fonctions** — sept réécrites depuis leur définition réelle, aucune créée : les cinq des tâches internes, qui écrivaient depuis le 31/08 un état que la base refusait (aucune tâche ne pouvait naître), et les deux de réattribution (**CAT-E19** : une réattribution ne laisse plus de fonds vide, garde le fonds supprimé entier au journal du catalogue et le rend tel quel s'il revient) ; **le catalogue** — inchangé en nombre, mais **plus aucun fonds sans exemplaire** dans le réseau (le fonds BLMF 2747, laissé par l'aller-retour de la notice 771, supprimé) ; **la circulation** — les trois PEB rendus et archivés, les essais du jour effacés ; **le dépôt** — `BibliotecaPage.jsx` passe de 152 à 84 Ko (E6, sections cotisation, dépôt et tâches), le contexte de session suit enfin les réglages changés à l'écran, `robots.txt` refuse les robots d'IA. **Tous les lots du découpage E6 sont vus à l'écran par Xavier** — deux essais y ont fait trouver trois défauts antérieurs (le contexte, les tâches, la réattribution), corrigés le jour même, et un message de PEB en jargon. **Mis à jour dans cette version, après un inventaire des 193 commits du 26 au 29/09 contre le backlog** : huit clôtures qui manquaient (couvertures CAPAS-1 à 6, pt-BR brésilien, fusion de notices DEDUP-11 à 14, sujets effacés THES-5, sigles OPAC-F3, OPAC-OEU7, onglet du catalogue publié, `robots.txt`), sept items ouverts (B36, C14 à C17, E23 à E25), E3 passé en cours (le tu dans les dix langues, quatre valeurs italiennes au « Lei » restantes), F6 à vérifier, et les journaux de vérification remis à jour là où ils s'arrêtaient trop tôt (A3, B29, C3, C4, C10, E2, E6, F3, G1, G6, G15, H17, H18, H19, H21, H23, H24, H28, I18, I21). **Ce qui reste à clore, et par qui** — *par Xavier* : les items « à vérifier » (B29, B30, F6, F15, H15 à H20, H22 à H26, H28, J9, K10) et C17 (à décider) ; *sans code* : A1 (une seule administration réseau), A3 (la machine du runner).

**Fraîcheur des constats au 2026-10-04.** **55 items sur 74** portent une vérification datée qui leur est propre (A1, A3, B29, B30, C3, C4, C10, C18, D3, D6, D8, E1, E2, E4, E6, E9, E20, E27, F3, F6, F10, F15, F16, F19, F21, G1, G6, G8, G10, G13, G15, H2, H15, H16, H17, H18, H19, H20, H21, H22, H23, H24, H25, H26, H28, H29, H30, H31, I2, I18, I21, J9, K2, K7, K10). Les **19** autres reposent encore sur le relevé du 2026-08-29 et sont signalés comme tels sous chaque fiche. Un constat non revérifié n'est pas faux : il est seulement vieux, et la différence se voit ici plutôt qu'à l'usage. Cette ligne est recalculée à chaque engendrement du document.

### Base

| | | |
|---|---:|---|
| Tables `public` | **197** | toutes avec RLS activé, **359 policies** tous schémas confondus (`public` 310, `storage` 47, `cron` 2). Inchangé depuis le relevé du 28/09 : les migrations du 29/09 réécrivent des fonctions, aucune ne crée de table ni de policy. 27 tables ont la RLS sans policy (avis 0008, `ingest` et des tables techniques de `public`) : fermées, voulu. |
| Tables `ingest` | **10** | toutes avec RLS ; aucune n'a de policy (avis 0008, les 10) — le schéma n'a jamais été exposé, ni `anon` ni `authenticated` n'y a `USAGE`. Inchangé depuis le 29/08 (B1). |
| Vues `api` | **68** | **67 SECURITY INVOKER, 1 DEFINER** (`library_email_identity`, la seule tolérée par la suite `vues_api_definer_tests`). Inchangé depuis le 24/09. |
| Fonctions applicatives | **998** | `public` 735 · `api` 201 · `ingest` 42 · `private` 20. Dont **755 SECURITY DEFINER** (inchangé). +1 depuis le 28/09 : `public.f_normalize_search`, la normalisation qui fait lire les sigles sans leurs points à la recherche unifiée (`20260928191324`). Le 29/09 a **réécrit** sept fonctions sans en créer : les cinq des tâches internes (`20260929095411`), les deux de réattribution (`20260929151902`, CAT-E19), par `pg_get_functiondef` et remplacements comptés — droits et options conservés. Une seule a un `search_path` non figé, **voulu** : `public.fn_locale_from_idioma` (avis 0011, B32). |
| Migrations appliquées | **398** | **398 appliquées en production = 398 numérotées au dépôt**, toutes par la CI (`created_by` NULL ; aucune hors CI depuis le 26/09). +7 depuis le relevé du 28/09 : la recherche unifiée et les sigles (28/09 au soir), puis le 29/09 les tâches internes et leurs sept états, le rapprochement ISSN qui distingue le fascicule de sa revue, IMP-25 (une notice MARC sans exemplaire n'en reçoit pas), et la réattribution qui ne laisse plus de fonds vide (CAT-E19). Les 8 fichiers de plus dans `supabase/migrations/` sont le gabarit et sept scripts de retour arrière. |
| Jobs `pg_cron` | **41** | actifs — inchangé depuis le 28/09. Une instance restaurée les retrouve par `private.fn_crons_replanifier()` (I26). La sonde des récurrences de tâches (`fn_cron_tasks_detect_stale_recurrence`) regarde depuis le 29/09 les quatre états vivants. |
| Avis de sécurité | **500** | 0 ERROR · **445** WARN sur les DEFINER exposées à `authenticated` (0029 ; 444 le 28/09, +1), **27** sur celles exposées à `anon` (0028, inchangé), **1** `search_path` non figé (0011, `fn_locale_from_idioma`, voulu, B32), 27 INFO « RLS sans policy » (0008). Les deux fonctions de réattribution réécrites gardent exactement leurs droits (`authenticated` et `service_role`, jamais `anon` — vérifié en production après le déploiement et gardé par la suite `grants_herites`). |
| Avis de performance | **262** | **236 « index inutilisés »** (246 le 28/09, −10 : des index sont empruntés depuis — les compteurs repartent du redémarrage du 02/09), **17** clés étrangères sans index (tables techniques, gardées par la suite à liste fermée), **8** tables sans clé primaire (`conv_backup` et deux tables de lignes d'import BLMF), 1 note sur les connexions `auth`. |
| Schémas de rebut | **1** | `conv_backup` seul — il porte les six tables de revue humaine de C3/C5 et **ne se purge pas** tant que les fiches ne sont pas relues. Inchangé. |

### Fonctions Edge

| | | |
|---|---:|---|
| Dossiers au dépôt | **55** | + `_shared` ; inchangé depuis le 28/09. Dont le routeur `main`, jamais déployé (I3). Toutes déployées par la CI (marqueur `deployed-functions`), plus jamais à la main. |
| Déclarations `verify_jwt` | **40** | **toutes à `false`** — compte des lignes `^verify_jwt = ` dans `supabase/config.toml` ; inchangé. Le Bearer ne prouve donc rien : chaque fonction vérifie son appelant elle-même (secret partagé ou session relue). |

### Catalogue

| | | |
|---|---:|---|
| Notices | **2 609** | 2 759 exemplaires, **2 380 œuvres** (+1), **1 508 autorités** — le catalogue n'a pas bougé depuis le 28/09 au soir : la notice d'essai « Je suis une légende » (29/09) a été créée, publiée puis retirée. **2 661 fonds, et plus aucun sans exemplaire** dans tout le réseau (bibliothèques privées comprises) : le seul, le fonds BLMF 2747 laissé par l'aller-retour de la notice 771, a été supprimé le 29/09 avec sa trace au journal (CAT-E19). |
| Brouillons de catalogage | **2 298** | `draft` 1 823, `published` 475 (+3 et +1 depuis le 28/09). **Chaque brouillon a sa bibliothèque** (B29) et **chaque lot la sienne** (B30 ; 3 lots : MLEG, BLMF, Solidaires). Le lot Solidaires reste à réviser et publier. Depuis le 29/09, un brouillon d'exemplaire publié suit son exemplaire quand une réattribution le déplace. |
| Indexation matière | **2 146 / 2 609** | notices avec au moins un sujet — **463 sans aucun**, inchangé depuis le 28/09 (1 472 le 24/09) : C7 a indexé 851 notices le 27/09 ; THES-5 (28/09) a rendu leurs sujets à 19 des 20 notices qu'une reprise sans sujets avait désindexées (136 brouillons de reprise en cause depuis juin ; BTL-TL-001242 laissée sans matière, sur arbitrage de Xavier). Les 463 restantes sont pour l'essentiel des notices sans vedette d'origine. |
| Thésaurus FICEDL | **621** | termes, **10 locales complètes**, 159 dates ; **110 alignements** vers les sujets locaux. Inchangé depuis le 28/09 ; l'esquisse SKOS révisée et le racleur hors ligne attendent Bologne (H13). |
| Périodiques | **4** | titres, **5 fascicules rattachés**, inchangé. Depuis le 29/09, le rapprochement d'import par ISSN ne prend plus un article pour sa revue (`20260929102719`). |

### Réseau

| | | |
|---|---:|---|
| Bibliothèques | **5** | **actives, sur 6 lignes** (la sixième est la bibliothèque de formation `blmf-teste`, inactive, fixtures en production). Inchangé. Les essais de cotisation et de dépôt de garantie du 29/09 (E6, vus à l'écran par Xavier) ont été faits sur la BLMF, revenue ensuite à l'état qu'elle veut : cotisation désactivée. |
| Comptes | **22** | **25** appartenances actives ; **22 lignes** dans `auth.users`, **20 confirmées** (deux invitations jamais honorées). Inchangé depuis le 28/09. |
| Administrateur·rices réseau | **1** | **c'est l'item A1, et il commande tout le reste** — inchangé depuis le 29/08. |
| Circulation vivante | **6 / 20 / 22 / 0** | emprunts / réservations / consultations / PEB **non archivés** — et **aucun n'est ouvert** : les 6 emprunts, 20 réservations et 22 consultations sont « encerrado ». **Les trois PEB sont rendus et archivés depuis le 29/09** : les deux de mai 2026 (n° 24 et 25) et le PEB d'essai de Xavier (n° 35 : créé, retour pointé en deux fois, archivé — l'onglet PEB découpé par E6, vu à l'écran). **Tâches internes : 0** — celles des essais du 29/09 ont été supprimées. La circulation réelle du réseau se fait hors AnarBib. |

### Dépôt

| | | |
|---|---:|---|
| Commits | **3 043** | +33 depuis le relevé du 28/09 au soir, en une journée et deux sessions : E6 (`BibliotecaPage` lots 2 et 3, les vérifications à l'écran), le contexte de session et ses réglages, les tâches internes, le PEB, la réattribution (CAT-E19), IMP-25 et le rapprochement ISSN, H27 clos et H29 ouvert, le rouge d'action unique, le `robots.txt`. Codeberg, miroir nu, WSL et GitHub alignés à chaque push. |
| Fichiers `src/` | **453** | +13 depuis le 28/09 : `TasksSection.jsx`, `MembershipSection.jsx`, `DepositSection.jsx` et `styles.js` sortis de `BibliotecaPage.jsx` (**152 → 84 Ko**, E6), `contexts/libraryPatch.js` (les réglages que le contexte porte), `lib/taskStatus.js` (le vocabulaire des tâches), et leurs tests de source. `BookDraftForm.jsx` : 131 Ko. Le critère d'E6 (aucun fichier `src/` au-dessus de 60 Ko) reste loin : `AccountPage.jsx` 154, `PanelPage.jsx` 114, `ImportacoesPage.jsx` 109. |
| Clés i18n | **6 939** | parité stricte sur les dix locales (6 939 chacune, gardée en CI). +7 depuis le 28/09 : quatre états de tâche (`task.status.*`), le refus clair d'une suppression de PEB sorti, le message d'IMP-25 (« aucun exemplaire ne sera créé ») et un conseil pour l'export vers PMB. |
| Tests | **1 531 + 150** | **1 531 tests JS** (vitest, gate bloquant, 128 fichiers ; relancés en entier le 29/09 au soir, tous verts ; 1 454 le 28/09 : +77, dont les tests de source des sections de `BibliotecaPage`, du vocabulaire des tâches, du contexte de session, du PEB et du `robots.txt`) + **150 suites SQL** dans `ci-suites.txt` (+4 depuis le 28/09 : `taches_sept_etats`, `import_sans_exemplaire`, `import_rapprochement_issn`, `reattribution_fonds_vide` — cette dernière éprouvée par 13 mutants, chacun tué par le test qui le garde), toutes vertes au dernier run. |
| Marqueurs de dette | **18** | dont 4 dans `src/` — méthode fixe (`git grep -E 'TODO|FIXME'` hors `docs/`) : 18, comme à chaque relevé depuis le 15/09. Aucun n'est une tâche ouverte ; ils nomment des choix assumés. |

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
| **A3** | Sortir le runner d'intégration continue de la machine du mainteneur | `P0` | En cours |

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

#### A3 — Sortir le runner d'intégration continue de la machine du mainteneur

`P0` Structurel · État : **En cours** · Charge : plusieurs semaines · Ce que ça demande : administration système

**État.** `.forgejo/workflows/ci.yml` et `sql-tests.yml` portent tous deux `runs-on: anarbib-local` — un `act_runner` auto-hébergé sur le WSL2 du mainteneur. Machine éteinte, **rien ne se déploie**, et l'échec est parfois silencieux. **28/09 — ce que l'échec silencieux vaut, mesuré : le 27/09 à 22 h 40 min 30 s le portable s'est mis en veille pendant le job `app` de 911ad1db** (journal WSL : fin du boot à cette seconde ; à 22 h 37 déjà `ReportLog error: deadline_exceeded`). Codeberg a déclaré la tâche en échec à 23 h 45 ; le `backend` n'a jamais tourné ; la migration de ce commit a attendu le push suivant, le lendemain à 11 h 37 — sans qu'un mot ne parte. Les runners hébergés par Codeberg ne conviennent pas (mesuré sur `codeberg.org/actions/meta` : 10 min par job au plus, pas de Docker ; `sql-tests` et `rejeu-image` en ont besoin et durent 6 à 12 min). **Trois gestes faits sans machine, sur décision de Xavier** : (1) `deploy/ops/RUNNER.md` — ce que c'est, où il vit (relu sur la machine : binaire v12.10.2, `~/.runner`, unités = liens vers `deploy/ops/systemd/`), le savoir vivant en deux minutes (`journalctl`, jamais `systemctl`), la remise en route, l'installation sur une autre machine avec **le même label** (deux runners peuvent coexister, la bascule se fait sans coupure) et un drop-in local pour l'utilisateur ; (2) la sonde **`ci_en_retard`** de `health-probe` (`_shared/ci/forgejo-tasks.ts`, migration `20260928095045`) : une fois par heure, la liste des tâches de la forge — une tâche non terminée depuis plus de 2 h, ou le dernier `app`/`backend` en échec depuis plus de 30 min sans run plus récent, ouvre l'incident et envoie « que faire : allumer, vérifier, **relancer** » ; un `[skip ci]` n'est pas une fausse alerte (on ne compare pas au marqueur), un 504 de l'API ne change rien ; banc de 15 cas dont la vraie soirée du 27/09 ; (3) `deploy/runner/compose.yml` — le runner en conteneur (`code.forgejo.org/forgejo/runner:12.10.2`, socket Docker partagée), `compose config` valide et image éprouvée ; l'enregistrement demande le jeton du dépôt. **Reste la machine** : Xavier essaie son autre portable ; la VM des Herbes Folles attend I21. Et le runner reste unique, en série : sortir du poste règle la disponibilité, pas la lenteur (`rejeu-image` la nuit, ou un second runner). **Déployé en prod le 28/09 à 12 h 48** (migration `20260928095045` par la CI, CHECK élargie, aucun incident `ci_en_retard`) — après deux pushes de code que Forgejo a sautés sans un rouge parce qu'un commit du lot portait `[skip ci]` (le backlog par-dessus, puis un commit voisin ramené par le rebase) ; le hook `.githooks/pre-push` refuse désormais ce lot mixte vers Codeberg (le miroir GitHub, sans CI, passe).

*Vérifié : 31/08 — 7 occurrences de `runs-on: anarbib-local` dans `.forgejo/workflows/`. Rien n'a bougé. **28/09, prod** : migration `20260928095045` appliquée par la CI (`created_by` vide), CHECK des incidents élargie à `ci_en_retard`, health-probe déployé (marqueur `11da0df8`) ; premier tick horaire à 13 h 05 UTC+2 : la sonde a lu les incidents ouverts, n'en a trouvé ni ouvert aucun — la chaîne était à l'heure. `deploy/ops/RUNNER.md` et `deploy/runner/compose.yml` au dépôt. Trois des quatre critères tenus ; reste le premier (la machine), à la main de Xavier. **27-28/09** — `4ac70cc0` : la suite `ci_en_retard_kind_tests` exerce la CHECK des incidents contre la base (le kind `ci_en_retard` admis, un kind inconnu refusé, les anciens gardés) — la garde vitest ne lisait que le texte de la migration ; et les journaux Docker du runner en conteneur tournent (3 × 10 Mo). Le hook `.githooks/pre-push` vient de `1737bee9`, limité à Codeberg par `8bf62c1d`. `51f6dcd9` (27/09) : le banc du script de déploiement (`deployer-backend-marqueur.test.js`) rougissait à chaque `npm test` sous Windows (9 cas, code 127), parce que `bash` y lance WSL ; il prend Git Bash, ou se saute sans lui, et la CI Linux garde `bash`. **01/10** — preuve par l'usage : deux runs cassés par l'arrêt du poste. Le 30/09 au soir, le `backend` de F16 a bloqué une heure (Codeberg lent, marqueur non repoussé) — tout était pourtant déployé ; le 01/10 à 7 h 55, le poste s'est arrêté une minute après le départ du `sql-tests` de F17 : Docker injoignable, runner coupé, Codeberg a affiché le job « en cours » pendant 11 heures, jusqu'au retour du poste à 18 h 47 ; deux conteneurs orphelins relancés par Docker au redémarrage, retirés à la main. F17 n'a été déployé qu'à 18 h 55. La CI vit et meurt avec la machine du mainteneur.*

**Ce que c'est.** Faire tourner le runner ailleurs que sur un poste de travail personnel : machine de l'hébergeur, seconde machine du réseau, ou runner partagé. La logique de déploiement est déjà extraite dans `scripts/ci/deployer-backend.sh` et rejouable à la main — la moitié du travail est faite.

**Pourquoi ça compte.** Tant que le runner est unique et personnel, aucune procédure ne peut rendre le déploiement fiable, et personne d'autre ne peut fusionner une contribution. C'est la seconde moitié de la dépendance à une seule personne, après **A1**.

**Ce qui compte comme fini.**

- Un push sur `main` déclenche un déploiement sans que la machine du mainteneur soit allumée.
- Le garde-fou d'exclusion du routeur `main` est préservé aux deux endroits (workflow et script).
- La procédure de remise en route du runner est écrite pour quelqu'un qui ne l'a pas installé. — **fait le 28/09 : `deploy/ops/RUNNER.md`.**
- Une panne du runner se voit : un courriel « chaîne de déploiement en retard » part dans les trois heures (sonde `ci_en_retard`, 28/09).

**Dépendances.** Lié à **I2** (bascule auto-hébergée). Peut se faire avant, sur l'infrastructure actuelle.

*Renvois : `CLAUDE.md, piège connu n°1` · `REPRISE_bascule_autohebergee_2026-08-26`*

---

### B — Base de données, sécurité, RLS

*191 tables, 694 fonctions SECURITY DEFINER, 332 policies (relevé du 06/09). La surface la plus large du projet.*

| | | | |
|---|---|---|---|
| **B29** | Les brouillons de catalogage appartiennent à leur bibliothèque : l'administration du réseau voit tout, une coordination ou une bibliothécaire ne voit que les siens | `P1` | À vérifier |
| **B30** | Donner une bibliothèque propre au lot de catalogage (suite de B29) | `P2` | À vérifier |
| **B36** | Relire aux compteurs de production les index gardés sous réserve | `P3` | Ouvert |

#### B29 — Les brouillons de catalogage appartiennent à leur bibliothèque : l'administration du réseau voit tout, une coordination ou une bibliothécaire ne voit que les siens

`P1` Prioritaire · État : **À vérifier** · Charge : plusieurs semaines · Ce que ça demande : SQL / PostgreSQL, React / JavaScript

**État.** Relevé le 27/09 pendant la revue de H19 (baseline, l.53888, 54047, 54406) : les politiques `author_drafts_catalogacao_librarian_all`, `book_drafts_catalogacao_librarian_all` et `exemplar_drafts_catalogacao_librarian_all` ne demandent que `api.my_access.can_access_catalogacao`, **sans aucune portée de bibliothèque**, en lecture comme en écriture. Toute personne qui catalogue, dans n'importe quelle bibliothèque, lit et modifie les brouillons de toutes les autres — y compris ceux d'une bibliothèque privée, et ceux d'un dépôt compagnon en attente d'admission. H19 a fermé ce qui passait par les RPC de publication (garde d'appartenance dans `publish_exemplar_draft`, liens d'import non écrivables par l'API), pas l'accès direct aux tables. **Règle posée par Xavier le 27/09** : possible pour un·e catalogueur·se qui est par ailleurs admin réseau, pas pour une coordination ni une bibliothécaire.

*Vérifié : 27/09 — suite SQL `brouillons_par_bibliotheque_tests` 30/30 (cinq profils : coordination de A, bibliothécaire de B, staff de A et B, lectrice, admin sans adhésion, admin aussi staff) et les 122 suites de la CI ; vitest 1 061 ; relevé de production (1 820 notices en cours, toutes rattachées ; un seul lot, 57, porte des notices publiées sans bibliothèque). **28/09, prod en lecture seule** : les politiques `*_catalogacao_librarian_all` de `book_drafts` et `exemplar_drafts` demandent `can_access_catalogacao` ET (admin réseau OU `COALESCE(owner_library_id, private.fn_book_draft_creator_library(…))` parmi les bibliothèques de staff) ; `author_drafts` : lecture commune au réseau, écriture par l'admin ou l'auteur·e ; `fn_user_staff_library` fermée aux comptes (`postgres`, `service_role`) ; les deux aides déplacées dans `private` par B35 ; 134 brouillons de notice sur 2 260 sans `owner_library_id` (repli par la bibliothèque du créateur), 20/20 brouillons d'exemplaire avec `target_library_id`. Conforme aux trois critères. **27-28/09** — mesuré en production après le déploiement (`a4b66ad4`) : la coordination d'une bibliothèque modifie ses 1 673 notices en cours, et les 147 autres lui sont refusées. Cinq aides de B29 sans appelant sous `authenticated` (`fn_caller_can_edit_draft_library`, `fn_caller_can_edit_exemplar_draft`, `fn_caller_can_edit_author_draft`, `fn_caller_can_edit_batch`, `fn_caller_can_see_batch`) sont fermées aux comptes par `f1808c85` (migration `20260927200627`, déployée par la CI le 28/09 à 10 h 04 UTC) : lint 0029 de 448 à 443 en production (441 après B35). T31 garde ce choix : sous `authenticated`, les DEFINER qui portent ces aides opposent un refus métier, jamais un 42501. Le complément d'audit du 27/09 (`71793cca`) lit les vingt-quatre fonctions neuves de B29, des capas et de B30 : aucune faille. `brouillons_par_bibliotheque_tests` compte désormais 32 tests (T32 vient de B35).*

**Ce que c'est.** Portée par bibliothèque : `book_drafts` par `owner_library_id` (et la destination résolue par `fn_book_draft_destination_library` quand il est nul), `exemplar_drafts` par `target_library_id` (et la bibliothèque de sa notice pour un exemplaire importé) ; `fn_caller_is_network_admin()` voit tout. **À trancher d'abord** : les brouillons sans bibliothèque (dépôt compagnon non admis : administration seule ?) ; `author_drafts`, dont les autorités sont communes au réseau (portée par qui les a créés, ou restées communes ?) ; les lots partagés entre bibliothèques (mutirão) ; les gardes « staff QUELQUE PART » des fonctions de fusion (`api.merge_book_drafts`, `api.merge_draft_into_book`), du journal (`fn_restore_deleted_draft`) et du rapport de révision, à aligner sur la même règle. Chercher les VUES et les RPC `security_invoker` qui lisent ces tables avant de restreindre (une vue invoker appelle sous le rôle du lecteur). Tester avec des comptes de deux bibliothèques et un compte admin. **Tranché le 27/09 par Xavier (REGISTRE `CAT-E18`)** : *(1)* un brouillon sans bibliothèque appartient à celle de l'adhésion de staff active de qui l'a créé — sans le repli sur qui publie, qui rendrait tout visible —, sinon à son créateur et à l'administration ; *(2)* les brouillons d'autorités restent lisibles par toute personne qui catalogue, modifiables par qui les a créés et par l'administration ; *(3)* le mutirão passe par une adhésion temporaire dans la bibliothèque hôte, à laquelle appartiennent ses brouillons. **Livré le 27/09** (`2c8a9af0`, `faea418c`, migration `20260927160000`), règle et choix de réalisation au REGISTRE (CAT-E18, « Mise en œuvre » et « Limites connues ») : politiques par bibliothèque (mêmes noms), autorités en lecture commune et écriture par le créateur, suppression définitive par la coordination DE la bibliothèque du brouillon ; par l'API, `created_by` figé, bibliothèque fixée à la création, rangement dans un lot gardé ; une cinquantaine de fonctions SECURITY DEFINER alignées, refus avant tout autre contrôle ; lots vus, modifiés, révisés et supprimés selon leurs brouillons en cours (lot mixte : l'administration ; suppression et demande de révision : la coordination du lot) ; `publish_book_draft` et `create_book_draft_from_book` repartent de leur version capas. **Une revue contradictoire et quatre vérifications des corrections** (18, 21, 21 et 29 constats, un seul bloquant — NULL lu comme « à soi » —, les importants corrigés) ; pire cas mesuré 20-35 ms (dépôt de 1 800 notices et 1 800 exemplaires sans bibliothèque, appelant d'une troisième bibliothèque).

**Pourquoi ça compte.** Risque de casser des gestes aujourd'hui ouverts (file de catalogage multi-bibliothèques, fusions, corbeille, étiquettes) : une restriction de lecture qui masque une ligne rend des mises à jour silencieusement nulles. Avancer table par table, avec une suite SQL par rôle.

**Ce qui compte comme fini.**

- Une bibliothécaire de A ne lit ni ne modifie un brouillon de B (notice, exemplaire), par l'API comme par les RPC.
- L'administration du réseau garde la vue et l'action sur tout.
- Les trois questions tranchées le 27/09 (`CAT-E18`) sont réalisées telles qu'écrites.

**Dépendances.** Après la livraison de H19 (même zone, colonnes neuves de `exemplar_drafts`).

*Renvois : `supabase/migrations/20260510000000_baseline_live.sql` · `supabase/migrations/20260927113000_h19_exemplaires_importes.sql` · `docs/specs/REGISTRE_decisions.md`*

#### B30 — Donner une bibliothèque propre au lot de catalogage (suite de B29)

`P2` Courant · État : **À vérifier** · Charge : quelques jours · Ce que ça demande : SQL / PostgreSQL, React / JavaScript

**État.** B29 (27/09) déduit « à qui est un lot » de ses brouillons : en cours, publiés, jetés, réattribués (IMP-20 c), exemplaires importés qui suivent leur notice, lots d'import de l'administration. Quatre vérifications de suite ont trouvé à chaque fois de nouveaux cas limites (18, 21, 21, 29 constats) : la règle tient, mais par une dizaine de prédicats (`fn_caller_can_see_batch`, `fn_caller_can_edit_batch`, `fn_caller_owns_batch`, `fn_caller_coordinates_batch`, déclencheur de rangement, politiques de `catalog_batches`). Limites connues au REGISTRE (CAT-E18) : une personne staff de deux bibliothèques peut rendre un lot mixte ; un brouillon restauré qui sort de son lot ne le dit pas ; le lot d'un compte d'administration n'est visible de personne d'autre tant qu'elle ne l'a pas confié.

*Vérifié : 27/09 — suite SQL `lot_a_une_bibliotheque_tests` 17/17 (huit profils) et les 132 suites de la CI ; vitest 107 fichiers ; production en lecture seule après le déploiement (tag `deployed-functions` = `2ecdaea3`, migration `created_by` nul) : lots 8, 57, 63 à MLEG, BLMF, Solidaires, `updated_at` intact, aucun lot à l'administration ; la coordination de chaque bibliothèque voit son lot et seulement lui ; déclencheurs *_zz_batch_guarded posés, anciens retirés ; droits des fonctions neuves conformes (aucune à anon). **28/09, prod en lecture seule** : `catalog_batches.library_id` présente ; 3 lots, tous avec une bibliothèque, aucun lot d'administration ; les quatre politiques de `catalog_batches` (lire, modifier, supprimer, suppression définitive) comparent `library_id` aux bibliothèques de staff ou de coordination de l'appelant·e — plus un prédicat déduit du contenu. Conforme aux trois critères.*

**Ce que c'est.** Colonne `catalog_batches.library_id` (nulle = lot de l'administration), posée à la création (écran : la bibliothèque de staff choisie ; import : bibliothèque du run pour un catalogue propre, destination pour un dépôt, nulle si inconnue ; réattribution : la nouvelle) et figée par l'API ; rangement d'un brouillon seulement si sa bibliothèque est celle du lot ; toutes les règles de lot (voir, modifier, réviser, supprimer) ramenées à cette colonne. Reprise des lots existants : la bibliothèque commune de leurs brouillons en cours et publiés, sinon nulle (administration). Repartir des définitions RÉELLES de `fn_import_promote`, `fn_batch_reassign_library` et des fonctions de rapprochement (H19). **Livré le 27/09** (`3a0e036f`, `2ecdaea3`, migration `20260927191059`), règle et choix au REGISTRE (CAT-E18, paragraphe « B30 ») : colonne posée à la création (écran : la bibliothèque active, un menu pour le staff de plusieurs bibliothèques, « Administration du réseau » pour l'administration), figée par l'API, changée par la seule réattribution (« Changer la bibliothèque du lot » remplace « confier ») ; toutes les règles de lot lues sur la colonne ; un brouillon ne se range que dans un lot de sa bibliothèque ; imports : bibliothèque du run ou destination de la source ; publier ouvert à l'administration sans adhésion (adhésion ACTIVE exigée du staff) ; une notice importée sans bibliothèque ne se publie pas. Reprise en production : lot 8 → MLEG et 63 → Solidaires (brouillons en cours), 57 → BLMF (fiches publiées). **Une revue contradictoire (28 constats, 2 bloquants), deux vérifications des corrections (10 puis 2 constats), contre-épreuve à 17 mutants.**

**Pourquoi ça compte.** Touche les fonctions d'import livrées avec H19 : une revue contradictoire avant tout déploiement.

**Ce qui compte comme fini.**

- Un lot a une bibliothèque, visible à l'écran, ou relève de l'administration.
- Les prédicats de lot déduits du contenu disparaissent au profit de la colonne.
- Les tests de B29 restent verts.

**Dépendances.** Après la vérification de B29 en production.

*Renvois : `supabase/migrations/20260927160000_b29_brouillons_par_bibliotheque.sql` · `docs/specs/REGISTRE_decisions.md` · `supabase/migrations/20260927191059_b30_lot_a_une_bibliotheque.sql` · `tests/sql/lot_a_une_bibliotheque_tests.sql` · `src/lib/useStaffLibraries.js`*

#### B36 — Relire aux compteurs de production les index gardés sous réserve

`P3` Différé · État : **Ouvert** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL

**État.** B10 (27/09) a retiré 22 index et en a gardé d'autres sous réserve. **22 redondants encore empruntés** (jusqu'à 10,8 millions de parcours pour `book_holdings_book_id_idx`) sont nommés avec leurs compteurs dans `index_redondants_garde_tests.sql` (`af98dee8`) : les retirer déplacerait des plans chauds vers l'index couvrant, à mesurer avant de décider. **108 index étaient à zéro parcours**, hors clés étrangères et redondants : 12 retirés (`3ac1c910`), les autres gardés, verdict par verdict, dans `docs/journal/audits/AUDIT_performance_B10_2026-09-27.md`. B32 (28/09) a rendu empruntables les index des vues matérialisées du catalogue ; trois restent sans parcours à son relevé (`autor_norm_trgm_idx`, `library_slug_idx`, `titulo_trgm_idx`), et `autor_norm_trgm_idx` n'a pas de lecteur connu dans le code. Ces rendez-vous ne vivaient que dans les clôtures de B10 et B32.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Vers le 28/10, relire `pg_stat_user_indexes` en production — compteurs remis à zéro au redémarrage du 02/09 (B9) : dater le relevé et noter tout redémarrage depuis. Pour chaque index nommé ci-dessus : le garder, raison écrite, ou le retirer par migration, raison écrite, comme B10 et B33. Pour les 22 redondants empruntés, comparer les plans des requêtes qui les empruntent avec l'index couvrant avant tout retrait.

**Pourquoi ça compte.** Un index sans lecteur coûte une écriture à chaque insertion ; un index retiré à tort fait basculer une requête chaude en parcours séquentiel. Trancher sur un mois de lectures en production, pas sur un banc.

**Ce qui compte comme fini.**

- Chaque index nommé dans v a son verdict écrit, daté du relevé.
- Les index retirés le sont par migration ; aucune clé étrangère ne perd son index, et `index_redondants_garde_tests` est à jour.

**Dépendances.** Différé à dessein : un mois de compteurs de production après B32 (déployé le 28/09), pas avant le 28/10.

*Renvois : `docs/journal/audits/AUDIT_performance_B10_2026-09-27.md` · `docs/journal/audits/AUDIT_catalogue_grande_echelle_B32_2026-09-28.md` · `tests/sql/index_redondants_garde_tests.sql` · `clôtures B10 et B32`*

---

### C — Catalogage et données documentaires

*La dette ici n'est pas du code : ce sont des fiches à relire une par une.*

| | | | |
|---|---|---|---|
| **C3** | Mener la revue humaine des autorités : patronymes, casse, titres | `P1` | Ouvert |
| **C4** | Renseigner les pays manquants des fiches d'autorité (674 sur 1 505 au 27/09) | `P2` | Décision collective |
| **C10** | Renommer la colonne de revue `digital_assets.rights_status` | `P2` | Ouvert |
| **C14** | Un exemplaire qui change de bibliothèque emmène tout avec lui | `P2` | Ouvert |
| **C15** | Corriger huit notices BTL, livre en main | `P2` | Ouvert |
| **C16** | Attribuer les couvertures posées avant le 27/09 | `P2` | Ouvert |
| **C17** | Décider si un numéro d'inventaire supprimé peut être redonné | `P2` | Décision collective |
| **C18** | Relire quatorze rapprochements d'œuvres : une même œuvre scindée en deux fiches ? | `P2` | Ouvert |

#### C3 — Mener la revue humaine des autorités : patronymes, casse, titres

`P1` Prioritaire · État : **Ouvert** · Charge : plusieurs semaines · Ce que ça demande : bibliothéconomie

**État.** Les 19 migrations `conventions_*` sont appliquées depuis le 21/08 : les référentiels sont normalisés, les mécaniques sûres ont été passées, la file de vérification existe et l'application permet d'y travailler. **Ce qui reste est la part qu'aucune machine ne fait.**

*Vérifié : [object Object],[object Object],[object Object]*

**Ce que c'est.** Reprendre les trois tables de revue du schéma `conv_backup` — `titres_a_revoir_20260820` (211), `autorites_casse_a_revoir_20260820` (1 274), `autorites_patronyme_a_revoir_20260820` (22) — et les traiter fiche par fiche depuis l'Atelier autorités.

**Pourquoi ça compte.** Sur les 22 doubles patronymes hispaniques signalés automatiquement, **trois sont des faux positifs connus** (Mechoso, Borges, Marcos) : 14 % d'erreur. Et sur les 13 points d'accès sur particule, **quatre sont corrects** (Van der Walt, De Amicis, Di Paolo, De Greef). Un script qui « finirait » ce travail introduirait des fautes dans un catalogue qui n'en a pas.

**Ce qui compte comme fini.**

- Les trois tables sont vidées par validation humaine, pas par script.
- **Interdiction absolue** : décommenter le SQL d'application, le compléter, ou passer `valide = true` en masse.
- Les 9 points d'accès posés sur un suffixe de filiation — type `FILHO, Fábio Luz` — sont traités en premier : l'audit les donne pour **le défaut le plus grave du lot**.

**Dépendances.** Se fait dans l'application, sans migration. C'est un chantier de bibliothéconomie, ouvert à qui sait cataloguer.

*Renvois : `AUDIT_conventions_catalographiques_2026-08-20` · `REGISTRE §37 CONV`*

#### C4 — Renseigner les pays manquants des fiches d'autorité (674 sur 1 505 au 27/09)

`P2` Courant · État : **Décision collective** · Charge : quelques jours · Ce que ça demande : bibliothéconomie

**État.** **Au 29/08, 722 fiches sur 1 305 (55 %) n'avaient pas de `country` ; au 27/09, après trois passes (Wikidata `b418e149`, Library of Congress `abaa4755`, IdRef `62553dc6`), 674 sur 1 505 (45 %).** Or c'est `country` qui pilote la règle d'entrée du nom : sans lui, la détection des doubles patronymes hispaniques ne voit qu'une fraction des cas. Les 22 signalements sont un **plancher**, pas un total.

*Vérifié : [object Object],[object Object],[object Object],[object Object]*

**Ce que c'est.** Les sources interrogeables automatiquement sont épuisées (Wikidata, Library of Congress, IdRef, 26-27/09). Les bibliothèques nationales du Brésil et d'Argentine ferment l'accès automatisé : on ne le contourne pas. Restent, sur décision de Xavier, la relecture humaine des fichiers `decisions*.csv` et la connaissance du fonds, ou la réécriture du critère 1. La détection des doubles patronymes peut être rejouée dès maintenant sur les pays posés.

**Pourquoi ça compte.** C'est le prérequis dur de toute la chaîne de conventions : `CONV-7` fait de `country` en ISO 3166-1 α-2 une condition, et `CONV-3` fait piloter la casse par la langue. Un catalogue à 45 % sans pays (27/09) applique ses propres règles à moitié.

**Ce qui compte comme fini.**

- La proportion de fiches sans `country` est descendue sous 20 %.
- La détection des doubles patronymes a été rejouée et la nouvelle liste est passée en revue humaine.

**Dépendances.** Prérequis de la seconde passe de **C3**.

*Renvois : `AUDIT_conventions_catalographiques_2026-08-20 A5` · `REGISTRE §37 CONV-7`*

#### C10 — Renommer la colonne de revue `digital_assets.rights_status`

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : SQL / PostgreSQL

**État.** `digital_assets.rights_status` est un **état de workflow** (`to_review`, `public_domain_confirmed`) qui commande la visibilité. Le vocabulaire des droits d'auteur porte le même nom depuis la migration `20260820235000_vocabulaire_rights_status`. Deux sens, un nom. **Mesuré le 27/09 en production — plus gros que « S ».** Quatre colonnes portent le nom : `digital_assets.rights_status` (l'état de revue : `to_review`, `public_domain_confirmed`, `source_reuse_allowed`, `restricted`, `do_not_publish` — **c'est lui qui commande la visibilité publique**), `book_digital_resources` et `book_draft_digital_resources` (le vocabulaire des droits : `dominio_publico`, `cessao_autoral`, `licenca_livre`, `sob_direitos`), `ingest.partner_catalog_received_assets` (le statut déclaré par la partenaire, en clair). Douze fonctions DEFINER contiennent le nom ; **six** visent la colonne de revue : `fn_attach_received_asset_record`, `fn_confirm_digital_asset_rights`, `fn_export_fonds_eligible_count`, `fn_export_fonds_records`, `fn_list_verified_digital_assets`, `fn_publish_digital_asset_from_resource` ; plus l'index `digital_assets_rights_status_idx`. Deux sorties d'API portent le nom (la colonne rendue par `fn_list_verified_digital_assets` — changer son type de retour impose DROP + CREATE et de reposer les droits —, la clé JSON de `fn_attach_received_asset_record`) et **le format d'échange des fonds** (`fn_export_fonds_records`, relu par `deposit-fonds-direct`) : les paquets déjà exportés garderont `rights_status`. Front : 5 fichiers ; Edge Functions : 4.

*Vérifié : [object Object],[object Object],[object Object]*

**Ce que c'est.** **Plan (27/09, décision de Xavier : chantier à part).** (1) Renommer `digital_assets.rights_status` en `review_state` (colonne, CHECK, index), et les six fonctions par remplacements comptés depuis leur définition RÉELLE ; (2) les sorties : `review_state` dans la liste des vérifiés et la clé JSON de l'attachement, le front et les Edge Functions suivent dans le même commit ; (3) l'export écrit `review_state`, l'import (`deposit-fonds-direct`) lit `review_state` puis, à défaut, `rights_status` — un paquet d'avant reste lisible ; (4) un banc qui prouve que la visibilité publique ne bouge pas (mêmes fichiers servis en anonyme avant et après, par empreinte en production) ; (5) le rappel `access_scope` dans le formulaire de catalogage (critère 2).

**Pourquoi ça compte.** Confusion garantie sinon, et sur un sujet où la confusion se paie : c'est l'état des droits qui décide si un document est visible du public. Un piège documenté s'y ajoute — `access_scope` vaut `conta_ativa` **par défaut**, si bien qu'un document du domaine public reste réservé aux comptes actifs tant que personne n'a posé `publico` explicitement.

**Ce qui compte comme fini.**

- Les deux notions portent deux noms distincts, en base et à l'écran.
- Le piège `access_scope` est rappelé dans le formulaire de catalogage, pas seulement dans une note.

**Dépendances.** Aucune.

*Renvois : `PLAN_DE_MARCHE §8` · `DECISION_profil_numerisation_2026-08-20`*

#### C14 — Un exemplaire qui change de bibliothèque emmène tout avec lui

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : SQL / PostgreSQL

**État.** Relevé le 29/09 en corrigeant la réattribution (`CAT-E19`) : trois chemins laissent derrière un exemplaire déplacé des choses qui pointent encore vers sa bibliothèque ou son fonds d'origine. Aucun n'a été vu à l'écran ; tous se lisent dans le code.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** (1) Un brouillon d'exemplaire OUVERT (`draft`, `ready`) sur un exemplaire réattribué garde sa bibliothèque d'origine : publié, il ramènerait l'exemplaire là d'où il vient, sans rien dire — décider s'il suit l'exemplaire (il changerait alors de file, `B29`) ou s'il est refusé à la publication. (2) Les réservations et PEB en cours restent comptés sur le fonds source après un déplacement (`fn_v2_recompute_holdings_availability` compte par `holding_id`, pas par exemplaire) : la disponibilité de la cible est surestimée. (3) Le changement de bibliothèque d'un exemplaire isolé (`publish_exemplar_draft`) et le désherbage (`discard_exemplar`) laissent, eux aussi, des fonds vides que la fiche publique affiche « 0 exemplaire ». (4) Restaurer depuis la corbeille un brouillon d'exemplaire qui visait un fonds supprimé depuis lève 23503 brut (`fn_restore_deleted_draft` réinsère son `target_holding_id`) — conséquence directe de `CAT-E19` : le mettre à NULL s'il n'existe plus, comme `import_staging_row_id`. (5) Le panneau de réattribution ne dit pas qu'un fonds source a été gardé (`holdings_kept`), vide, parce qu'un historique y renvoie.

**Pourquoi ça compte.** Le point (3) est le même défaut que celui de la notice 771, par d'autres portes : tant qu'il reste ouvert, un « 0 exemplaire » peut réapparaître sur une fiche publique.

**Ce qui compte comme fini.**

- Chaque point a sa décision (Xavier pour le (1)) et, s'il est corrigé, une suite qui emprunte le chemin.
- Pour le (3), la règle de `CAT-E19` s'applique telle quelle : supprimer le fonds que le geste vide, sauf renvoi.

**Dépendances.** Aucune.

*Renvois : `REGISTRE CAT-E19` · `migration 20260929151902`*

#### C15 — Corriger huit notices BTL, livre en main

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : bibliothéconomie

**État.** La recherche de couvertures a fait remonter des données fautives, relevées en production le 28/09 (`docs/journal/chantiers/LIVRAISON_capas_2026-09-27.md`). **Six années impossibles** : BTL-TL-002174 `0187`, BTL-TL-002032 `0193`, BTL-TL-000065 et BTL-TL-001935 `0200`, BTL-TL-002053 `8000`, BTL-TL-002278 `2200` — cette dernière a aussi un lieu où s'est collée une ligne de colophon, avec un ISBN incomplet. **Un ISBN à clé de contrôle fausse** : BTL-TL-000503. S'y ajoute BTL-TL-002335, relevée à l'écran le 27/09 : elle décrit l'édition Ramparts Press de 1971 et porte l'ISBN de l'édition AK Press de 2004 (`027e6903`). Les deux « ISBN partagés » du même relevé ne sont pas des fautes : ce sont des paires BTL/BLMF d'une même édition, dont la fusion est une mutualisation (`DEDUP-8`).

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Notice par notice, dans le formulaire, livre en main : lire la valeur sur le livre, corriger, publier. **Jamais par migration** : une migration devinerait (décision de Xavier du 28/09). Les valeurs « probables » de la note de livraison sont des pistes, pas des corrections.

**Pourquoi ça compte.** Une année `8000` ou `0187` fausse le tri par année et le filtre par date de l'OPAC ; un ISBN d'une autre édition fait proposer la couverture de cette autre édition. Seule une personne qui a le livre en main peut trancher, et la liste ne vit aujourd'hui que dans une note de livraison : rien ne dirait quand elle est soldée.

**Ce qui compte comme fini.**

- Chacune des huit notices est corrigée, ou sa valeur confirmée sur le livre.
- Aucune correction n'est faite par migration.

**Dépendances.** Avoir les livres en main (fonds de la BTL) ; Xavier, au formulaire.

*Renvois : `docs/journal/chantiers/LIVRAISON_capas_2026-09-27.md (« à corriger dans le formulaire, livre en main »)` · `REGISTRE §43 CAPAS` · `commit 027e6903 (BTL-TL-002335)`*

#### C16 — Attribuer les couvertures posées avant le 27/09

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : bibliothéconomie, SQL / PostgreSQL

**État.** La spec des capas (§4.3) fait de l'attribution — la source et la licence de chaque couverture — une exigence éthique et de conformité. **Mesuré le 27/09 en production : 0 couverture attribuée sur les 250 notices publiées qui en ont une, et 0 sur les 132 brouillons dans le même cas.** Le formulaire ne mettait pas la paire dans le brouillon (`fd5d2f0e`), et ni la publication ni la reprise ne la recopiaient (`76c6ae3f`, migration `20260927130518`). Depuis, provenance et licence suivent l'image par paire (`CAPAS-4`) — pour les couvertures posées après le 27/09 seulement : aucune migration ne reprend le stock. Et Inventaire ne dit pas la licence de ses images : elle est posée à null, « à vérifier » (`2a80d43b`).

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Relever combien de couvertures publiées restent sans provenance. Puis écrire une règle pour le stock, décidée par Xavier : une provenance retrouvée là où une trace la donne, sinon « inconnue », posée et assumée par écrit. Pour les images d'Inventaire, vérifier la licence à la source, ou assumer son absence par écrit.

**Pourquoi ça compte.** Une couverture est l'image d'un tiers : sans sa source, on ne peut ni la créditer ni la retirer si on nous le demande. La règle par paire tient les poses nouvelles ; le stock d'avant le 27/09 reste muet, et aucun item ne le portait.

**Ce qui compte comme fini.**

- Chaque couverture publiée a une provenance, ou une raison écrite de n'en pas avoir.
- La licence des images d'Inventaire est vérifiée, ou son absence assumée par écrit.

**Dépendances.** Aucune : la règle par paire (`20260927130518`) est en production.

*Renvois : `docs/specs/archive/spec-module-capas.md §4.3` · `REGISTRE §43 CAPAS-4` · `docs/journal/chantiers/LIVRAISON_capas_2026-09-27.md` · `commits fd5d2f0e, 76c6ae3f, 2a80d43b`*

#### C17 — Décider si un numéro d'inventaire supprimé peut être redonné

`P2` Courant · État : **Décision collective** · Charge : une soirée · Ce que ça demande : bibliothéconomie, SQL / PostgreSQL

**État.** `CCLA.2026.93`, créé par erreur le 27/09 depuis un poste BLMF sur BTL-TL-000881, a été retiré le 28/09 (`96b4a104`, migration `20260928111729`, exemplaire 2796). Le 29/09, l'exemplaire initial de la notice d'essai « Je suis une légende » a reçu le même numéro, `CCLA.2026.93` (verif d'E6). Ce n'est pas une panne : `fn_next_tombo` rend le plus grand numéro sous le préfixe, plus un (`20260815145252`), et la contrainte `exemplares_unique_tombo` ne vaut qu'entre exemplaires présents. Supprimer le dernier exemplaire d'une série libère donc son numéro. Rien n'écrit si c'est voulu : ni le REGISTRE, ni les specs.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Xavier tranche entre deux règles, puis on l'écrit au REGISTRE : (a) un numéro donné ne se redonne jamais — compteur par préfixe, ou plus grand numéro jamais attribué, journal compris ; (b) le réemploi est toléré, et la règle le dit. Si (a), `fn_next_tombo` change par une migration testée.

**Pourquoi ça compte.** Un numéro d'inventaire s'écrit sur le livre et dans les registres papier. S'il se redonne après une suppression, deux livres peuvent porter le même numéro — l'un sorti de la base, l'autre dedans — et un prêt, un récolement ou une étiquette peuvent les confondre.

**Ce qui compte comme fini.**

- La règle est écrite au REGISTRE.
- Si un numéro ne doit jamais se redonner, une suite SQL le prouve : supprimer le dernier exemplaire d'une série, puis en créer un.

**Dépendances.** Décision de Xavier.

*Renvois : `supabase/migrations/20260815145252_tombo_collision_robustness.sql` · `supabase/migrations/20260928111729_btl_tl_000881_exemplaire_blmf_retire_et_tirages_notes.sql` · `item E6 (verif du 29/09)`*

#### C18 — Relire quatorze rapprochements d'œuvres : une même œuvre scindée en deux fiches ?

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : bibliothéconomie

**État.** Relevé le 01/10 (lecture seule, production), en cherchant d'autres cas comme l'œuvre 1163 (E26) : un titre « auto » d'une œuvre A qui est le titre réel — d'édition ou saisi — d'une autre œuvre B du même auteur·rice. Quatorze paires, douze œuvres A. La plupart ne sont pas des titres faux mais des **traductions d'une même œuvre rangées sous deux fiches** : Reclus, *L'Homme et la Terre* (133) / *O Homem e a Terra* (880) / *El Hombre y la Tierra* (1131) ; Reclus, *Evolución, Revolución y el Ideal anárquico* (268) / 1387 (fr) / 1203 (pt) ; Kropotkine, *A Conquista do Pão* (19) / 2381, *El Apoyo Mutuo* (79) / *Ajuda Mútua* (396), *A Grande Revolução* (1) / 1084, *Em Tôrno de uma Vida* (115) / 386 ; Tolstoï, *A insubmissão* (28) / 1297 ; Gori (48) / 873 ; Safón (99) / 2428 ; Horowitz (74) / 2484. **À trancher au cas par cas, comme 1163** : Nettlau, *La Anarquía a través de los tiempos* (2036) / *História da Anarquia* (196) — même texte ou non ? — et Kropotkine, *Moral anarquista* (1366) / *La Moral Anarquista y otros escritos* (2064), recueil contre texte seul.

*Vérifié : 01/10 — relevé en production : 14 paires, 12 œuvres A ; aucune modification faite.*

**Ce que c'est.** Relire chaque paire avec les éditions en main ; réunir celles qui sont la même œuvre, depuis l'application ; pour les autres, faire comme pour 1163 : titres « auto » remplacés, note d'œuvre qui dit pourquoi elles restent distinctes.

**Pourquoi ça compte.** Une œuvre scindée s'affiche deux fois au catalogue par œuvre, et chaque fiche ne montre qu'une partie des éditions ; un abrégé fondu dans l'intégrale ferait réserver l'un pour l'autre.

**Ce qui compte comme fini.**

- Les quatorze paires sont tranchées par une personne qui catalogue, pas par script ; la requête de relevé ne renvoie plus que des paires décidées distinctes, chacune avec sa note.

**Dépendances.** Se fait dans l'application. La requête de relevé est dans la session du 01/10 (titres `auto` d'une œuvre = titre d'édition ou `edition`/`manual` d'une autre œuvre de même `primary_author_id`).

---

### D — Périodiques, éphémères, ressources numériques

*Ce que la bibliothéconomie du livre ne sait pas décrire, et qui fait une part énorme de nos fonds.*

| | | | |
|---|---|---|---|
| **D3** | Rattacher les 91 fascicules et les 87 monographies suspectes de SOLIDAIRES | `P2` | Ouvert |
| **D4** | Le matériel éphémère : tracts, affiches, autocollants, zines | `P1` | Ouvert |
| **D5** | Éprouver la chaîne de numérisation sur dix ouvrages avant d'équiper qui que ce soit | `P2` | Ouvert |
| **D6** | Reprendre ou remplacer le lecteur EPUB | `P3` | Ouvert |
| **D8** | Décrire les archives de collectifs selon ISAD(G) : niveaux rattachés, producteurs, accès par niveau, export EAD | `P3` | Bloqué |

#### D3 — Rattacher les 91 fascicules et les 87 monographies suspectes de SOLIDAIRES

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : bibliothéconomie

**État.** Le fichier SOLIDAIRES porte déjà des colonnes `revue` et `numero` : **12 titres à créer, 91 fascicules à lier**. En plus, **87 monographies portent « n° » dans leur titre** et sont marquées par un drapeau `numero_dans_titre` : ce sont des candidates au rattachement.

*Vérifié : [object Object],[object Object]*

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

#### D8 — Décrire les archives de collectifs selon ISAD(G) : niveaux rattachés, producteurs, accès par niveau, export EAD

`P3` Différé · État : **Bloqué** · Charge : un chantier long · Ce que ça demande : SQL / PostgreSQL, React / JavaScript, bibliothéconomie

**État.** Décision **D7** (REGISTRE `ARCH-1` à `ARCH-4`, Xavier, 27/09) : un modèle archivistique complet dans AnarBib. Aujourd'hui, un type « dossier » **à plat** (`dossier_scope`, `dossier_period`, `dossier_organizations`, `dossier_context` sur `books` et `book_drafts`, inutilisées en production le 27/09) : rien ne rattache une pièce à un dossier, un dossier à une série, une série à un fonds ; l'import CSV d'un inventaire ferait une notice par ligne.

*Vérifié : 27/09 — colonnes `dossier_*` présentes sur `books` et `book_drafts` en production, aucune hiérarchie, 0 ligne renseignée.*

**Ce que c'est.** Après l'avis du réseau (`ARCH-4`). *(1)* Des unités de description rattachées (niveau ISAD(G), parent, ordre, cote archivistique), aux zones essentielles d'ISAD(G) (identification, contexte, contenu, conditions d'accès et d'utilisation, sources complémentaires) — en repartant des colonnes `dossier_*`. *(2)* Les producteurs en autorités (ISAAR(CPF)) : l'autorité existe (`authors`, `authority_type` personne, collectivité, congrès) ; y ajouter la famille et l'histoire du producteur si besoin. *(3)* Des conditions d'accès et de reproduction par niveau, héritées du parent, respectées par l'OPAC et par les exports (membres seulement, masqué). *(4)* L'arbre à l'OPAC et au catalogage. *(5)* Un export EAD ; un import d'inventaire en tableur qui reconstruit la hiérarchie (cote hiérarchique ou colonne de niveau et de parent), sur un inventaire réel de DIRA.

**Pourquoi ça compte.** Les archives de collectifs sont une part essentielle des fonds libertaires, et elles sont rarement décrites ailleurs. Les aplatir en notices de livre, c'est perdre justement ce qui en fait des archives : leur contexte.

**Ce qui compte comme fini.**

- Un fonds réel de DIRA décrit à plusieurs niveaux, du fonds à la pièce là où il le faut.
- Une unité restreinte n'apparaît ni à l'OPAC ni dans un export public ; ses enfants en héritent.
- Export EAD validé contre le schéma EAD, et relu par une personne du réseau qui pratique l'archivistique.

**Dépendances.** Bloqué par l'avis de DIRA, du CIRA et du FICEDL sur la décision (`ARCH-4`). Un inventaire réel de DIRA (**G15**) pour éprouver l'import.

*Renvois : `docs/specs/REGISTRE_decisions.md` · `Réponse à DIRA du 26/09/2026`*

---

### E — Front, OPAC, i18n, accessibilité

*10 locales à parité stricte, 6 570 clés chacune (06/09), vérifiées en intégration continue.*

| | | | |
|---|---|---|---|
| **E1** | Faire auditer l'accessibilité par quelqu'un qui n'a pas écrit le code | `P1` | Ouvert |
| **E2** | Trancher les conventions néerlandaise et grecque | `P1` | Ouvert |
| **E4** | Régler les paires irrégulières de l'italien | `P2` | Ouvert |
| **E6** | Découper les cinq écrans qui pèsent plus de cent kilooctets | `P2` | En cours |
| **E9** | Finir la mise en page mobile : trois lots identifiés | `P2` | Ouvert |
| **E10** | Le reste du socle terrain : permanence mobile, notification poussée, planche de codes | `P3` | Ouvert |
| **E20** | La barre de navigation se regroupe par nature — Public, Moi, Travail — en menus qui s'ouvrent au clic, pas au survol | `P2` | Ouvert |
| **E23** | Chaque HINT `error.*` posé par une fonction de la base a son libellé dans les dix locales | `P2` | Ouvert |
| **E24** | Les refus des Edge Functions portent un code que l'écran traduit, pas une phrase en dur | `P3` | Ouvert |
| **E25** | pt-BR : ce que la passe du 27/09 n'a pas touché | `P2` | Ouvert |
| **E27** | Les suggestions de la recherche rapide ignorent encore les titres d'œuvre | `P2` | Ouvert |

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

*Vérifié : 31/08 — les dix fichiers `anarbib-charte-langage-inclusif-v2-*.md` existent depuis le 05/06, `nl` et `el` compris ; mais dedans, la convention `nl` est marquée « provisoire » et la `el` « à définir avec une personne locutrice grecque militante ». Les documents existent, les décisions non : le constat tient sur le fond. **27/09** — `b425dfb1` a réécrit 18 valeurs `nl` (« u/uw » → « je/jouw », et deux « jullie » adressés à une seule personne → « je ») et 172 valeurs `el` (2e personne du pluriel → singulier), par substitutions écrites clé par clé (`scripts/i18n-it-de-nl-el-tu.cjs`), sous `DOC-ADDR-1`. Aucune personne de langue maternelle ne les a relues : le commit n'en cite aucune. La relecture du critère 2 doit commencer par ces 190 valeurs ; la table DE → PARA du script sert de feuille de relecture.*

**Ce que c'est.** Une locutrice ou un locuteur natif reprend la charte de langage inclusif, décide de la forme neutre pour sa langue, et relit les 6 177 chaînes en priorité sur les écrans les plus vus.

**Pourquoi ça compte.** Deux langues qui cessent d'être des traductions approximatives. C'est un des trois chantiers qui **ne demandent aucune compétence technique** — et le seul que personne d'autre ne peut faire à la place.

**Ce qui compte comme fini.**

- Les conventions `nl` et `el` sont écrites dans `docs/notes-audit/anarbib-charte-langage-inclusif-v2-*.md`.
- Les chaînes des écrans principaux sont relues.
- La liste néerlandaise est déjà partie chez Ludwig — le suivi en fait partie.

**Dépendances.** Aucune. **Entrée sans compétence technique.**

*Renvois : `docs/CHANTIERS_OUVERTS.md §5` · `docs/notes-audit/anarbib-charte-langage-inclusif-v2.md`*

#### E4 — Régler les paires irrégulières de l'italien

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : langue maternelle

**État.** `it.json` n'est pas conforme à la convention de l'astérisque final : les paires irrégulières comme `lettore` / `lettrice` ne se réduisent pas à `lettor*`. Le test de charte vérifie une seule chose sur l'italien — que `camerata` et `camerati` n'y figurent jamais, terme fasciste, échec dur — et rien d'autre.

*Vérifié : [object Object]*

**Ce que c'est.** Décider du traitement des paires irrégulières avec un locuteur natif, puis l'appliquer aux chaînes concernées. C'est un travail de langue, pas de code.

**Pourquoi ça compte.** L'italien est la langue de la présentation de Bologne. Une interface qui applique sa convention à moitié se voit à l'écran partagé.

**Ce qui compte comme fini.**

- Le traitement des paires irrégulières est écrit dans la charte italienne.
- Les chaînes concernées sont corrigées.
- Les trois chaînes restées en français dans l'interface italienne sont traduites (716 chaînes vues, 3 fautives).

**Dépendances.** Avant le 08/09 si possible, sinon octobre.

*Renvois : `CLAUDE.md, piège connu n°9` · `CALENDRIER_bologne_2026-08-27`*

#### E6 — Découper les cinq écrans qui pèsent plus de cent kilooctets

`P2` Courant · État : **En cours** · Charge : quelques jours · Ce que ça demande : React / JavaScript

**État.** Au 29/08, `BookDraftForm.jsx` faisait **197 Ko**, `BibliotecaPage.jsx` 184 Ko, `AccountPage.jsx` 154 Ko, `PanelPage.jsx` 114 Ko, `ImportacoesPage.jsx` 109 Ko. 29 des 38 routes sont déjà en chargement paresseux, et `vite.config.js` déclare quatre lots de dépendances — le problème n'est pas le chargement initial, c'est la taille d'un fichier unique. **Lot 1 le 27/09 (`486c71a1` ; mesuré avant : `BookDraftForm.jsx` 214 Ko, 3 803 lignes).** Les constantes et fonctions PURES — types de matériel, rôles, liaison MARC → autorités, cote d'étiquette, formulaire vide, candidat BN Brasil, zones ISBD — sortent dans `src/lib/catalogacao/bookDraft.js` (18 Ko), lignes déplacées par script sans ressaisie ; les zones ISBD reçoivent le formulaire et `t` au lieu de les lire dans la fermeture. `BookDraftForm.jsx` : **198 Ko**. Banc `book-draft-lib.test.js` (11 cas), build Vite vert, 1 160 tests. **Reste l'essentiel** : sous 60 Ko il faut découper le JSX (sous-formulaires, panneaux ressources numériques, ISBD, contributeurs) en composants — un changement qui se vérifie à l'écran, connecté, un panneau à la fois. **Lot 2 le 28/09 : le panneau « Recursos digitais vinculados » devient `DigitalResourcesPanel.jsx`** (`305a7922`, 24 Ko : formulaire d'édition, téléversement dans le bon seau, enregistrement, suppression ; le parent garde la liste, que la couverture tirée du PDF lit, et son chargement). Lignes déplacées par script, une différence voulue : l'édition en cours se referme quand le brouillon change, pas seulement sur une fiche vierge. `BookDraftForm.jsx` : **173 Ko** (214 au départ). Lint, 98 tests de source, build Vite. **Lot 3 le 28/09 : le panneau de recherche catalographique devient `LookupPanel.jsx`** (`006edc8a`, 15,7 Ko : recherche ISBN/ISSN/titre+auteur dans les sources, lecture du code-barres, liens BN/WorldCat/ISSN, candidates, résultats BN Brasil). Le panneau n'écrit jamais le formulaire : l'ISBN lu, la candidate ou la notice BN retenue remontent au parent par trois rappels, qui garde `applyCandidate` et `applyBnResult`. Une différence voulue : les résultats se referment dès que le brouillon change, pas seulement sur une fiche vierge. `BookDraftForm.jsx` : **167 Ko** (214 au départ). Lint, 1 402 tests (test de source `lookup-panel-monte`, 5 cas), build Vite. **Lot 4 le 28/09 : le bloc des contributeurs devient `ContributorsPanel.jsx`** (`3fbbd46e`, 10,6 Ko : lignes nom/rôle/principal·e, ajout par rôle, retrait, sélecteur d'autorité par ligne). La liste reste au parent — sauvegarde, chargement, synthèse d'`autor`, candidates et publication la lisent — et lui est passée avec son setter ; le panneau prévient par `onDirty`. `BookDraftForm.jsx` : **157 Ko**. 1 415 tests (test de source `contributors-panel-monte`, 4 cas), build Vite. **Lot 5 le 28/09 : le panneau de révision de la fiche devient `ReviewPanel.jsx`** (`1df28545`, 12 Ko : résumé et architecture documentale, sortie publique, pacote ISBD et ses boutons). Le panneau n'affiche que ce que le parent lui passe — l'état ISBD, sa préparation (qui écrit `marc_json`) et les libellés de zones restent au parent ; seul l'onglet courant vit dans le panneau, ramené au résumé quand le brouillon change. `BookDraftForm.jsx` : **146 Ko**. 1 427 tests (test de source `review-panel-monte`, 4 cas), build Vite. **Lot 6 le 28/09 : la prévia de cote et les exemplaires initiaux deviennent `ShelfLabelPreview.jsx` et `InitialCopiesBlock.jsx`** (`291793cc`, 2,8 et 2,6 Ko : pur affichage pour la cote, saisies remontées par `onChange` pour les exemplaires ; le parent garde les conditions d'affichage et la lecture à la publication). `BookDraftForm.jsx` : **142 Ko**. 1 431 tests, build Vite. **Lots 7 et 8 le 28/09, sur décision de Xavier (« les deux autres morceaux », pas la couverture)** : la réattribution d'une notice publiée devient `ReassignPanel.jsx` (`1c2300db`, 5,5 Ko : ses quatre états, le chargement des bibliothèques détentrices, les deux RPC ; le parent garde la condition admin réseau + notice publiée et la liste des cibles) ; les cartes « para informação » de l'aperçu deviennent `InfoCards.jsx` (`7aaf9905`, 8 Ko : auteur·rices liées, exemplaires de la bibliothèque active cliquables, compte des autres bibliothèques, avec le chargement fonds → exemplaires). `BookDraftForm.jsx` : **130 Ko**. 1 437 tests, build Vite. Les « sections de matériel » n'étaient pas à couper : `CatalogFieldRenderer.jsx` les rend déjà depuis le registre, le formulaire n'en porte que l'appel. Reste dans ce fichier : l'en-tête couverture (téléversement, galerie, page 1 du PDF, ~130 lignes de JSX et 70 de logique — le plus couplé : formulaire, brouillon, stockage, vignette), et la grille des champs écrite à la main. **`BibliotecaPage.jsx`, lot 1 le 28/09 au soir : l'onglet des prêts entre bibliothèques (PEB) devient `IllSection.jsx`** (`3c33b9f6`, 31,7 Ko : formulaire d'un nouveau prêt, file des prêts actifs, pointage du retour, archivage, partage numérique, avec ses sept états ; la liste des prêts et leurs exemplaires restent chargés par le parent, que le rapport lit, et arrivent en props). Les cinq styles partagés du composant passent dans `styles.js`. `BibliotecaPage.jsx` : **184 → 152 Ko**. **Lot 2 le 28/09 au soir : l'onglet « Tarefas internas » devient `TasksSection.jsx`** (`22083073`, 37 Ko : liste par échéance, création, statut, invitation ; tâches-types ; catalogue de suggestions — avec ses cinq états de formulaire, ses fonctions et ses deux mémos ; les trois listes restent chargées par le parent, que le rapport lit, et arrivent en props). `BibliotecaPage.jsx` : **184 → 117 Ko** en deux lots. **Lot 3 le 29/09 : la cotisation associative et le dépôt de garantie deviennent `MembershipSection.jsx` et `DepositSection.jsx`** (`2ae132fe`, 17,7 et 16 Ko : interrupteur du système, plafonds du dépôt, règles à créer, modifier, activer, supprimer — la cotisation garde sa confirmation à deux niveaux ; les deux listes de règles et la fiche de la bibliothèque restent chargées par le parent et arrivent avec leur setter). `BibliotecaPage.jsx` : **184 → 83 Ko** en trois lots. 1 462 tests, build Vite. Restent dans cette page : les rapports (texte du rapport et envoi, ~180 lignes), l'identité et les communications (deux formulaires, ~240 lignes), les horaires. **Lots 2 et 3 vus à l'écran, connecté, par Xavier le 28/09 : ok.** Chaque lot suivant se voit de même avant de clore.

*Vérifié : **28/09** — `BookDraftForm.jsx` : 214 Ko (27/09) → 198 (lot 1) → 173 (lot 2) → 167 (lot 3) → 157 (lot 4) → 146 (lot 5) → 142 (lot 6) → 137 (lot 7) → **130 Ko** (lot 8) ; neuf modules sortis : `lib/catalogacao/bookDraft.js` (18 Ko), `DigitalResourcesPanel.jsx` (24,6), `LookupPanel.jsx` (15,7), `ContributorsPanel.jsx` (10,6), `ReviewPanel.jsx` (12,1), `ShelfLabelPreview.jsx` (2,8), `InitialCopiesBlock.jsx` (2,6), `ReassignPanel.jsx` (5,5), `InfoCards.jsx` (8,0). Lots 2 et 3 vus à l'écran, connecté, par Xavier : ok. Lots 4 à 8 publiés, à voir de même ; `BibliotecaPage` lots 1 à 3 (onglets PEB, tâches internes, cotisation et dépôt) publiés, à voir aussi : créer un prêt, changer un statut, pointer un retour ; créer une tâche, un modèle, l'instancier, adopter une suggestion ; activer la cotisation, créer une règle, la désactiver ; activer le dépôt, poser un plafond, créer une règle. **29/09, vu à l'écran par Xavier** : l'interrupteur de la cotisation (lot 3) écrit en base ; créer une tâche, changer son état, la supprimer (lot 2) passent — journaux de l'API : création 200 à 12 h 12, changement d'état 200, et la table compte une insertion, une mise à jour, une suppression. Le dépôt de garantie (lot 3) aussi : plafond par lecteur·rice posé, règle « Caution standard » créée, interrupteur basculé — relevé en base après son passage (plafond 3,00, une règle active, une insertion dans `library_deposit_rules`). Puis les tâches en entier (instancier un modèle, adopter une suggestion du catalogue : deux tâches nées et supprimées, un sixième modèle adopté) et les règles de cotisation (désactivation et réactivation d'une règle) : ok. Puis l'onglet des prêts entre bibliothèques (lot 1) : quatre recherches d'exemplaires, un prêt créé avec son exemplaire (la file de notification a reçu son événement), les deux prêts de mai archivés, le prêt d'essai supprimé — journaux de l'API tous en 200 ; le pointage d'un retour n'a pas été essayé. **Les lots 1, 2 et 3 de `BibliotecaPage` sont vus.** Formulaire de notice, lots 4 à 8 : Xavier a créé, publié puis retiré une notice d'essai (« Je suis une légende », brouillon 6317) — journaux de l'API : brouillon créé, contributeur·rices enregistré·es (lot 4), publication acceptée avec son exemplaire initial `CCLA.2026.93` (lot 6), retrait tracé au journal du catalogue ; les onglets de révision et les cartes de l'aperçu (lots 5 et 8) ont été affichés sans erreur. Puis la liaison d'une autorité (lot 4), vérifiée par Xavier sur un brouillon réel : recherche d'autorité par nom, contributeur « Volin » lié à l'autorité 10111, brouillon réenregistré (journaux de l'API à 12 h 49, tous en 200). Puis la réattribution (lot 7), vérifiée par Xavier sur une notice réelle : « A Revolução desconhecida » (notice 771) passée de la BTL à la BLMF à 16 h 34 puis rendue à la BTL à 16 h 35 — relevé par l'API publique (MCP déconnecté) : les deux exemplaires `BTL-TL-EX-000829` et `BTL-TL-EX-000834` sont de retour dans le fonds BTL d'origine (656), publics. **Le panneau marche ; les deux fonctions de réattribution, non** : l'aller a créé un fonds BLMF (2747) que le retour a laissé VIDE, et la fiche publique de la notice annonce depuis « BLMF — 0 exemplaire » (2 bibliothèques au lieu d'une). `network_admin_reassign_book_from_to_library` et `network_admin_reassign_book_to_library` ne suppriment jamais le fonds qu'elles vident (défaut antérieur au découpage) ; 2747 est le seul fonds vide du réseau. Correctif fait le 29/09, autorisé par Xavier (registre `CAT-E19`, migration `20260929151902`) : un fonds que la réattribution vide est supprimé, sauf si un historique y renvoie ; les brouillons publiés des exemplaires déplacés suivent leur exemplaire ; le fonds 2747 est supprimé sous garde. Suite `reattribution_fonds_vide_tests` (`8ee37bde`) : **18/18** au banc, 13 mutants tués, chacun par le test qui le garde ; sa première version, jouée sans la migration, reproduisait le « 2 bibliothèques » de la prod. La relecture contradictoire (quatre angles) a ajouté trois gardes : un fonds recréé par une réattribution revient tel qu'il était (cote locale, prêtabilité, notes) ; chaque fonds supprimé est gardé entier au journal du catalogue, même quand l'admin réseau est staff de la cible ; un brouillon ouvert qui vise la cote retient le fonds. L'état de collection des revues est recompté. En production, au relevé du soir : plus aucun fonds sans exemplaire dans le réseau, et les deux fonctions gardent leurs droits (`authenticated`, `service_role`, jamais `anon`). Les défauts voisins vont en `C14`. Puis le pointage du retour d'un prêt entre bibliothèques (lot 1 de `BibliotecaPage`), vu par Xavier : ok. **Tous les lots des deux découpages sont vus.** Un seul accroc, antérieur au découpage : « Supprimer » s'offrait à un PEB déjà sorti (en partie rendu), la base le refusait et l'écran affichait « DELETE du loan … refusé par RLS » — le bouton ne s'offre plus qu'aux deux statuts que la politique DELETE accepte, et un refus se dit en clair dans les dix langues (`b3ac9d13`). Ces deux essais ont fait trouver deux défauts ANTÉRIEURS au découpage, corrigés le jour même : le contexte de session ne suivait pas un réglage changé à l'écran (`0bf96cb8`), et aucune tâche ne pouvait naître depuis le 31/08 (`455c7f0b`, cinq fonctions et quatre écrans parlaient l'ancien vocabulaire d'états). **29/09 — `BibliotecaPage.jsx` : 184 → 83 Ko** ; cinq sections sorties (`IllSection` 31,7, `TasksSection` 37, `MembershipSection` 17,7, `DepositSection` 16, `styles.js`) — la réattribution (admin réseau, notice publiée) et les cartes exemplaires de l'aperçu (notice publiée avec exemplaires) compris. Onze tests de source gardent les montages : `book-draft-lib`, `lookup-panel-monte`, `contributors-panel-monte`, `review-panel-monte`, `cote-et-exemplaires-initiaux-montes`, `reassign-panel-monte`, `info-cards-montees`, `serial-picker-monte`, et pour la page Bibliothèque `biblioteca-ill-section-montee`, `biblioteca-tasks-section-montee`, `biblioteca-cotisation-depot-montes`. Le critère « aucun fichier de `src/` au-dessus de 60 Ko » reste loin. **Remesuré le 29/09 au soir** (`75ccb035`), neuf fichiers de code le dépassent : `AccountPage.jsx` 156,8 Ko, `BookDraftForm.jsx` 130,9, `ImportacoesPage.jsx` 129,6 (109 le 29/08), `PanelPage.jsx` 118,5, `CatalogPage.jsx` 108,7 (91 le 29/08), `BibliotecaPage.jsx` 83,9, `CatalogacaoPage.jsx` 82,1, `AuthorDraftForm.jsx` 70,9, `QueuePanel.jsx` 60,6. Les dix fichiers de locales (486 à 734 Ko) tombent aussi sous la lettre du critère. **29/09** — deux défauts de plus, trouvés pendant la revue des écrans, antérieurs au découpage. `--brand-accent` n'était défini nulle part : le bouton « Enregistrer » des horaires (`e4814be1`, passé sur `.ab-button`) et une quarantaine d'appels `var(--brand-accent, …)` tombaient chacun sur leur propre rouge de repli. `0d8a0a30` le définit dans `theme-base.css` depuis `--brand-accent-rgb` — il suit donc le thème de la bibliothèque —, définit `.cat-btn` une seule fois (`components/ui/ui.css`) et passe trois écrans sur `.ab-button` (politique de conservation, partenaire de dépôt externe, cartographie). Et `0bf96cb8`, au-delà du contexte de session : `patchLibrary` (règle pure dans `contexts/libraryPatch.js`), appelé par la cotisation, la carte-lecteur et le saut collégial ; l'enregistrement de l'identité affichait « enregistré » même sur un refus de la base, il relève désormais l'erreur (banc `library-context-patch`, 9 cas).*

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

#### E20 — La barre de navigation se regroupe par nature — Public, Moi, Travail — en menus qui s'ouvrent au clic, pas au survol

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : React / JavaScript, langue maternelle

**État.** **Demande de Xavier le 08/09/2026, tranchée après débat.** `src/components/layout/index.jsx` aligne sur **une seule ligne** jusqu'à **douze liens** pour une coordination qui est aussi admin réseau : Catalogue, Je veux…, Bibliothèques, Cartographie, Thésaurus, Mon compte, Panneau (`canSeePainel`), Catalogage, Importations (`canSeeImportacoes`), Bibliothèque, Fédération, Réseau (`canSeeRede`). Et chaque page aligne ses onglets sur une ligne aussi : neuf à Mon compte, douze à Bibliothèque, quinze à Réseau. Tout est aplati : rien ne dit d'un coup d'œil ce qui est public, ce qui est à soi, ce qui est du travail de bibliothèque ou de réseau. Xavier proposait d'abord des menus **par rôle** (« Bibliothécaire », « Coordinateur ») ouverts **au survol** ; le débat a retenu autre chose sur les deux points, voir « ce qu'il faut faire ».

*Vérifié : 08/09 — barre relue : sept liens publics ou personnels + jusqu'à six liens de travail selon `canSee*` (`roles.js` : Painel et Catalogage dès `librarian`, Importations et Bibliothèque dès `coordenador`, Fédération pour tout rôle, Réseau pour l'admin réseau). Onglets comptés : Mon compte 9, Bibliothèque 12, Réseau 15, Fédération 8. Le lien Réseau reste réservé aux admins (décision du 02/09) : le regroupement n'y change rien. **15/09 — un des six liens de Travail a changé de nom** : « Bibliothèque » (`/biblioteca`) s'appelle « Gestion de la bibliothèque » (Xavier, `09165764`, REGISTRE 0.36 `PUBLIB-NAV-2`) — deux liens homonymes au singulier et au pluriel ne disaient pas ce qu'on y trouve. Le groupe Travail listera donc Panneau, Catalogage, Importations, **Gestion de la bibliothèque**, Fédération, Réseau ; les 89 diapositives BLMF montrent l'ancien mot et la barre d'avant : à reprendre dans ce lot.*

**Ce que c'est.** **Regrouper par nature, pas par rôle** — une coordination est aussi bibliothécaire et lectrice, un menu par rôle lui en montrerait deux pour elle seule et une bibliothécaire verrait un menu « Coordinateur » vide. Trois groupes : **Public** (Catalogue, Bibliothèques, Cartographie, Thésaurus), **Moi** (Mon compte, Je veux…), **Travail** (Panneau, Catalogage, Importations, Bibliothèque, Fédération, Réseau — chaque entrée soumise au même `canSee*` qu'aujourd'hui, le groupe n'apparaissant que s'il a une entrée ; le rôle qui ouvre chaque entrée peut être un sous-titre dans le menu). Le catalogue reste un lien direct, c'est la porte d'entrée publique. **Les menus s'ouvrent au clic ou à la touche Entrée, jamais au survol** : le survol n'existe ni au doigt (E9) ni au clavier (E1) ; `aria-haspopup`, `aria-expanded`, fermeture à Échap et au clic dehors, focus rendu au bouton. **Les onglets ne bougent pas dans ce lot** : un troisième niveau ferait pire, et les 51 intentions de « Je veux… » pointent déjà page + onglet exacts ; un regroupement des onglets, s'il s'impose, sera un lot à part. À livrer avec : le registre `intentions.js` relu (les chemins ne changent pas, les libellés de groupe entrent dans ses mots-clés), les dix locales (trois libellés de groupe, les sous-titres de rôle), le Manuel v5 et la formation BLMF (89 diapositives montrent la barre actuelle).

**Pourquoi ça compte.** Une barre de douze liens sans hiérarchie se lit en la parcourant, pas en la regardant — et c'est exactement ce qu'on demande à une coordination le premier soir de sa formation. Grouper par nature tient quel que soit le nombre de rôles d'une personne ; grouper par rôle se casse dès qu'elle en a deux. Et un menu au clic marche partout où l'app tourne, un menu au survol seulement à la souris.

**Ce qui compte comme fini.**

- La barre n'expose plus que les liens directs (Catalogue) et trois boutons de groupe ; chaque groupe s'ouvre au clic et au clavier, se ferme à Échap, et ne montre que ce que le rôle ouvre.
- Une inconnue non connectée ne voit ni Moi ni Travail ; une lectrice voit Moi ; une bibliothécaire voit Travail avec Panneau et Catalogage ; une coordination y voit aussi Importations, Bibliothèque, Fédération ; l'admin réseau y voit Réseau.
- Aucun chemin ne change : les 51 intentions de « Je veux… » et les liens profonds du Manuel v5 restent valides (test à liste fermée d'`intentions.js` vert).
- Dix locales pour les libellés de groupe et de rôle, parité stricte.
- Sur 360 px, la barre tient sans débordement et les menus se ferment au toucher hors du menu.
- Le Manuel v5 et le conducteur de la formation montrent la nouvelle barre — **ou** le lot est daté après la dernière soirée de formation.

**Dépendances.** Après **E9** (mobile) de préférence, ou avec lui ; même exigence de regard extérieur que **E1**. **Ne pas livrer pendant la formation BLMF** (sept soirées à partir du 08/09) : la barre est sur les diapositives — à dater après la dernière soirée, ou à montrer aux coordinations comme changement annoncé. Gel du code jusqu'au 14/09.

*Renvois : `src/components/layout/index.jsx` · `src/lib/roles.js (canSee*)` · `src/pages/inicio (intentions.js)` · `anarbib-rede-perimetre-admins (doctrine : une porte se pose dans la page du geste, pas dans la barre)` · `K7 (formation BLMF)`*

#### E23 — Chaque HINT `error.*` posé par une fonction de la base a son libellé dans les dix locales

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : SQL / PostgreSQL, React / JavaScript

**État.** Une fonction SQL qui refuse pose une clé dans son HINT (`USING HINT = 'error.x.y'`), et `localizeError` la traduit (cas 1). Si la clé manque dans la locale, l'écran montre le message SQL tel quel (cas 3) ou le repli de l'appelant. Aucune garde ne compare ces clés aux locales : la garde i18n lit le code du front, pas les migrations, et le script d'audit annoncé dans l'en-tête de `localizeError.js` (PN-1, 27/05) n'existe pas dans le dépôt. Le 27/09, H19 (`02000b89`) a ainsi trouvé deux HINT posés en juillet sans libellé (`error.catalog.staff_only`, `error.catalog.holding_library_mismatch`), parce que son test relit les HINT de sa migration ; B29 et B30 font de même, chacun pour la sienne. **Compté au dépôt le 29/09** : 198 clés `error.*` posées en HINT, toutes définitions comprises (commentaires exclus), dont 74 sans libellé fr ; 20 de ces 74 ont été posées après le baseline : `error.serial.*` ×5, `error.library_invitation.*` ×6, `error.catalog.merge*` ×3, `error.conv.review.*` ×2, `error.membership.*` ×2, `error.forbidden`, `error.catalog.notDuplicate.invalidPair`.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Une garde vitest qui lit les migrations, garde la dernière définition de chaque fonction (une fonction supprimée sort), en extrait les HINT `error.*`, commentaires exclus (`error.foo.bar` n'est qu'un exemple dans un commentaire), et échoue sur toute clé absente d'une des dix locales. Avant de traduire, recompter sur les définitions réelles de la production (`pg_proc.prosrc`) : le baseline ne dit pas toujours ce qui tourne. Puis écrire les libellés manquants, au registre de chaque langue (`DOC-ADDR-1`).

**Pourquoi ça compte.** Un refus bien expliqué par la base ne sert à rien s'il arrive à l'écran en message SQL brut, ou en « erreur inconnue ». Et chaque nouvelle fonction peut ajouter une clé sans libellé sans que rien ne rougisse : H19 n'a trouvé les siennes que parce que son propre test relisait sa migration.

**Ce qui compte comme fini.**

- Une garde vitest lit les HINT `error.*` de la dernière définition de chaque fonction des migrations, commentaires exclus, et échoue sur toute clé absente d'une des dix locales.
- Le compte est refait sur les définitions de production et noté dans la verif.
- Toutes les clés encore posées par une fonction en service ont leur libellé dans les dix locales.

**Dépendances.** Aucune.

*Renvois : `src/lib/localizeError.js (cas 1 et 3 ; en-tête PN-1)` · `src/tests/import-exemplaires-ecran.test.jsx (H19)` · `src/tests/brouillons-par-bibliotheque.test.js (B29)` · `src/tests/lot-bibliotheque.test.js (B30)` · `REGISTRE §0 DOC-GRANT-2 (un rejeu n'est pas la production)`*

#### E24 — Les refus des Edge Functions portent un code que l'écran traduit, pas une phrase en dur

`P3` Différé · État : **Ouvert** · Charge : une soirée · Ce que ça demande : Deno / TypeScript, React / JavaScript

**État.** Le 27/09, `3cf927e1` a réglé ce défaut pour la seule EF `login` : ses trois phrases françaises, affichées telles quelles dans les dix langues, sont devenues des codes (`LOGIN_INVALID`, `LOGIN_RATE_LIMITED`, `LOGIN_SERVER_ERROR`) que `LoginPage.jsx` traduit. Le même défaut vit ailleurs. Mesuré le 29/09 : `attach-received-asset` refuse en français (« Fichier déjà attaché. », « Aucun fichier déposé à attacher. », « Type MIME … non supporté pour un asset. ») ou dans un portugais mêlé de français (« Recurso recebido … introuvável. ») ; `deposit-fonds-direct` dit « Aucune notice éligible (public_domain_confirmed). » ou « Origem e destino identicos. ». `ImportacoesPage.jsx` passe ce texte à `localizeError` sans repli, qui le rend tel quel (cas 3) : une coordination qui travaille en grec lit un refus en français.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Même geste que pour `login`. Chaque refus porte un code stable ; l'écran le traduit, avec une clé dans les dix locales ; le texte reste en repli, au registre de `DOC-ADDR-1`. Commencer par recenser les EF appelées depuis l'écran dont le texte d'erreur est affiché. Un banc compare les codes émis par chaque EF à ceux que l'écran traduit, comme `login-compteurs-haches` le fait pour `login`.

**Pourquoi ça compte.** Le catalogue se veut utilisable dans dix langues. Un refus écrit dans une seule ne dit pas à la personne quoi faire. Ces deux écrans servent peu, d'où la priorité basse ; mais toute EF écrite sur ce modèle refait le même défaut.

**Ce qui compte comme fini.**

- `attach-received-asset` et `deposit-fonds-direct` ne renvoient plus de phrase à afficher : chaque refus porte un code, traduit dans les dix locales.
- Les autres EF dont l'écran affiche le texte d'erreur sont recensées, et traitées de même ou nommées dans la verif.
- Un banc échoue si une EF émet un code que l'écran ne traduit pas.

**Dépendances.** Aucune. Modèle : `3cf927e1` (`login`).

*Renvois : `supabase/functions/attach-received-asset/index.ts` · `supabase/functions/deposit-fonds-direct/index.ts` · `src/pages/importacoes/ImportacoesPage.jsx (handleAttach, handleDepositFondsDirect)` · `src/lib/localizeError.js (cas 3)` · `src/tests/login-compteurs-haches.test.js (modèle)`*

#### E25 — pt-BR : ce que la passe du 27/09 n'a pas touché

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : langue maternelle

**État.** Le 27/09, l'app et les courriels pt-BR sont passés au « você » (`a805951b`, `36c467fa`) et au vocabulaire brésilien (`faae6e0e`, `49047ae3`, `6f762f8f`, `dfa622f5`). Mesuré le 29/09, hors de cette passe : `docs/governance/guide-gouvernance-pt-BR.md`, inchangé depuis le 01/09 (`74ee6682`), dit encore « concernida » (×13, dont 11 « pessoa concernida »), « gerir » (×3), « gere » (×1) et « partilhar » (×1) ; il nourrit le recueil PDF du bucket. La charte inclusive pt-BR dit « concernida(s) » (×2), le DPA pt-BR « concernidas/concernidos » (×4) et « partilham » (×1). Dans `pt-BR.json`, 28 valeurs hors zones ISBD gardent l'espace français avant « : » ou « ; » (« Velocidade : {rate}× », « Erro ao enviar {name} : {msg} »), et `catalogacao.queue.crossPage` vaut « (cross-page) », en anglais.

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** Réécrire ces passages comme l'app l'a été le 27/09 : « pessoa em questão », « gerenciar », « compartilhar ». Ôter l'espace avant « : » et « ; » dans les 28 valeurs ; la ponctuation prescrite de l'ISBD le garde. Traduire `crossPage`. Les gardes n'y suffiront pas : `PT_EUROPEU` voit « partilhar », mais « gerir » et « concernida » sont des angles morts déclarés (`src/tests/helpers/ptbr-pt-europeu.js`, `ptbr-frances.js`), l'espace avant « : » aussi. Il faut relire. Puis régénérer le `.docx` et le recueil `Guia_de_governanca_AnarBib.pdf` du bucket. Écrire enfin au REGISTRE les décisions de vocabulaire du 27/09 (« número de chamada », « ficha », « feed », EEB, « importação ») : `DOC-ADDR-1` ne couvre que le registre d'adresse.

**Pourquoi ça compte.** Le guide de gouvernance dit à une coordination comment coopter, retirer quelqu'un, traiter un conflit. Écrit dans un portugais d'ailleurs, il lui dit aussi que le projet ne lui parle pas tout à fait, alors que l'écran, lui, est corrigé.

**Ce qui compte comme fini.**

- Le guide de gouvernance, la charte inclusive et le DPA pt-BR n'ont plus ni « concernid- », ni « gerir » (« gere »), ni « partilh- » hors « compartilh- ».
- Aucune valeur de `pt-BR.json` hors zones ISBD n'a d'espace avant « : » ou « ; », et `catalogacao.queue.crossPage` est traduite.
- `PT_EUROPEU` et `FRANCES_EM_PT` passent aussi sur le guide de gouvernance pt-BR.
- Le `.docx` et le recueil PDF du bucket sont régénérés.
- Les décisions de vocabulaire pt-BR du 27/09 sont écrites au REGISTRE.

**Dépendances.** Aucune.

*Renvois : `docs/governance/guide-gouvernance-pt-BR.md` · `docs/governance/guide-gouvernance-pt-BR.docx` · `docs/notes-audit/anarbib-charte-langage-inclusif-v2-pt-BR.md` · `docs/legal/dpa-pt-BR.md` · `src/tests/helpers/ptbr-pt-europeu.js` · `src/tests/helpers/ptbr-frances.js` · `src/lib/docLinks.js (recueil `Guia_de_governanca_AnarBib.pdf`)` · `REGISTRE §0 DOC-ADDR-1 ; commits dfa622f5, faae6e0e`*

#### E27 — Les suggestions de la recherche rapide ignorent encore les titres d'œuvre

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL

**État.** Constaté à l'écran le 01/10, après E26 : dans la barre « Rechercher un titre ou un·e auteur·rice… », « Vivre ma Vie » ne suggère que le livre d'Armand. Les suggestions passent par `api.search_catalog_v1` (`UnifiedSearchCombobox.jsx`), la recherche unifiée, qui n'a pas reçu les titres de l'œuvre que `catalog_search_ids_v1` lit désormais. La grille du catalogue, elle, trouve l'œuvre.

*Vérifié : 01/10 — constaté dans le navigateur sur app.anarbib.org (anonyme) : suggestion unique « Est-ce cela que vous appelez vivre? … » (Armand).*

**Ce que c'est.** Faire lire `work_titles` (toutes langues) à `api.search_catalog_v1`, comme `catalog_search_ids_v1` depuis `20261001190729` : même meule, même pli des sigles, garde md5 d'entrée, suite SQL qui cherche un titre présent seulement dans `work_titles`.

**Pourquoi ça compte.** La barre de recherche rapide est la première chose qu'on touche : elle contredit la grille juste en dessous.

**Ce qui compte comme fini.**

- « Vivre ma vie » suggère l'œuvre 2101 dans la barre de recherche rapide, à l'écran.

**Dépendances.** Aucune.

*Renvois : `supabase/migrations/20261001190729_la_recherche_trouve_l_auteur_dans_tous_les_sens_et_le_titre_de_l_oeuvre.sql`*

---

### F — Courriel et notifications

*13 fonctions notify-*, 5 files d'attente, 6 déclencheurs de dépêche. Personne n'a jamais audité l'ensemble.*

| | | | |
|---|---|---|---|
| **F3** | Consolider les fonctions de notification redondantes | `P2` | Ouvert |
| **F6** | `notify-internal-task` tourne sur une copie gelée de toute la pile courriel | `P2` | À vérifier |
| **F10** | Sortir de Resend : un relais militant à demander, un transport à écrire, l'aiguillage à rétablir — et `sendViaBrevo` traîne encore dans `email.ts` | `P2` | Ouvert |
| **F15** | Les courriels institutionnels aux admins du réseau n'arrivaient que sur une boîte personnelle — une seule résolution des destinataires, avec la boîte collective | `P2` | À vérifier |
| **F16** | L'invitation à une tâche n'a jamais créé d'invitation | `P1` | À vérifier |
| **F19** | Les journaux des fonctions contiennent les adresses des destinataires en clair | `P1` | À vérifier |
| **F20** | Sans ligne de politique, une bibliothèque ne voit jamais une réservation expirer ni une non-venue détectée | `P2` | Ouvert |
| **F21** | Pied de page et ligne « Status » des courriels en pt-BR dans toutes les langues | `P2` | À vérifier |

#### F3 — Consolider les fonctions de notification redondantes

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : Deno / TypeScript

**État.** Quatre fonctions font des récapitulatifs : `notify-weekly-report`, `notify-network-weekly-report`, `notify-cross-library-digest`, `notify-rede-digest`. Trois fonctions servent des documents : `read-pdf`, `read-digital-asset`, `read-ill-shared-asset`. Deux exportent des lots : `export-catalog-lote`, `export-fonds-bundle`. Et `mail-i18n-test`, fonction de test, est déployée en production en version 1553.

*Vérifié : [object Object],[object Object],[object Object]*

**Ce que c'est.** Vérifier ce que chacune fait vraiment avant de conclure à la redondance — elles ont probablement des destinataires et des portées différentes. Puis fusionner ce qui doit l'être, et retirer `mail-i18n-test` de la production.

**Pourquoi ça compte.** 48 fonctions déployées, c'est beaucoup à maintenir pour un projet à un mainteneur. Chacune porte son propre gabarit, ses propres dix langues, ses propres secrets. Ce n'est pas un problème de performance, c'est un problème de surface à relire.

**Ce qui compte comme fini.**

- Chaque groupe a un verdict : fusion, ou raison écrite de la séparation.
- `mail-i18n-test` n'est plus déployée en production.
- Le compte de fonctions déployées est à jour dans `CLAUDE.md` et dans `config.toml`.

**Dépendances.** Après **F1**. Attention : le déploiement de `notify-event` ne passe pas par MCP, son paquet est trop gros.

*Renvois : `PLAN_DE_MARCHE §8` · `Relevé du 29/08/2026`*

#### F6 — `notify-internal-task` tourne sur une copie gelée de toute la pile courriel

`P2` Courant · État : **À vérifier** · Charge : quelques jours · Ce que ça demande : Deno / TypeScript

**État.** **La divergence de signature est refermée le 30/08.** `resolveMailRouting` de la copie accepte désormais une locale et lit `signature_short_i18n[locale]`, à l'identique du canonique ; `renderEmail` la transmet, et les trois envois du gestionnaire passent la leur — elle était déjà calculée quatre lignes plus haut à chaque fois, par `normalizeTaskLocale`. Un avis de tâche à la BLMF est maintenant signé dans la langue de qui le lit. Gardé par `src/tests/notify-internal-task-signature.test.js`, 6 tests qui exercent le vrai fichier sur le contexte réel de la BLMF — dont un qui vérifie que **sans locale, le comportement est exactement celui d'avant**.

**Le gros est refermé le même soir.** Les 9 fichiers d'infrastructure dupliqués sont supprimés : la fonction n'a plus qu'un `index.ts`, et les 3 fichiers propres aux tâches ont rejoint `_shared/` (`domain/`, `data/`, `i18n/`) — `334e852c`, après l'alignement des deux expéditeurs sur l'en-tête standard (`20260830205754`). Le relevé ci-dessous est celui d'avant la réunion.

**Mesuré le 30/08, après ouverture de l'item.** Il y a bien trois arbres `_shared` sous `supabase/functions/`, mais ils ne pèsent pas le même poids : celui de `catalog_metadata_lookup` ne contient qu'un `cors.ts` sans équivalent canonique — ce n'est pas une duplication. Le cas réel est `notify-internal-task`.

Ses 12 fichiers se répartissent ainsi : **3 sont légitimement privés** (`data/internal-tasks.ts`, `handlers/internal-task.ts`, `i18n/task-mail-strings.ts`, absents du canonique) et **9 sont de l'infrastructure dupliquée, toute divergente** — `library-mail-routing` (116 lignes d'écart), `library-notification-context` (122), `mail/layout` (140), `transport/email` (121), `shared/format` (89), `context/policies` (42), `core/webhook` (30), `core/env` (10), `shared/branding` (4). Environ **694 lignes** au total.

**Pourquoi ces copies existent : la question n'a pas de réponse dans le dépôt.** Elles apparaissent dans le TOUT PREMIER commit (`e6ec991a`, 21/08/2026) — 1 479 fichiers et 615 892 insertions sous un message qui parle d'un bouton de l'écran de catalogage. C'est l'import initial du dépôt : l'histoire ne commence pas avant. Aucune décision n'est écrite nulle part.

**Ce qui diverge vraiment, vérifié :** le canonique résout la signature de pied de page en `signature_short_i18n[locale]` avec repli sur `signature_short` ; la copie ne connaît que `signature_short`, et son `resolveMailRouting` n'accepte même pas de locale. **La BLMF a `signature_short_i18n` rempli en six langues.** Ses avis de tâche interne sont donc signés « Equipe da BLMF » quelle que soit la langue de la personne, là où tous les autres courriels de la même bibliothèque disent « L'équipe de la BLMF » à qui lit en français.

**Ce qui NE diverge pas, vérifié aussi :** `transportDisabledReason` est identique octet pour octet dans les deux copies, et le contexte de la copie lit bien `channel_active`. L'interrupteur d'envoi rendu réel le 30/08 est donc honoré ici comme ailleurs. `policyEnabled` et `resolveNetworkLogoUrl`, présents dans la copie seule, ne sont appelés par personne.

*Vérifié : 30/08 — relevé fait fichier par fichier, après ouverture de l'item : 9 fichiers dupliqués et tous divergents, ~694 lignes, et **une seule divergence à effet observable** — la signature de pied de page non traduite, **refermée le soir même et gardée par 6 tests**. L'origine des copies n'a pas de réponse dans le dépôt : elles sont dans le premier commit. Ce qui reste est une décision de portée, pas une mesure. **31/08** — au lendemain de la réunion, et au titre de cet item, `20260831073104` donne à `painel_internal_tasks.status` les sept états des courriels, tenus par une CHECK, avec `aberta` pour défaut — la table était vide. **29/09** — ce second geste avait cassé la création des tâches : cinq fonctions écrivaient ou filtraient encore `pendente`, et aucune tâche interne n'a pu naître pendant quatre semaines (23514). Trouvé par Xavier à l'écran ; corrigé par `455c7f0b` (migration `20260929095411` : les quatre écritures prennent `aberta`, la sonde des récurrences regarde les quatre états vivants ; suite `taches_sept_etats_tests`, 7 tests ; `src/lib/taskStatus.js` tient les listes de l'écran, et le banc `task-status-vocabulaire` les compare à la CHECK lue dans les migrations). Les quatre critères sont tenus ou sans objet depuis la réunion du 30/08. **Reste à vérifier** : qu'un avis de tâche réel parte par la fonction réunie — la table était vide le 31/08, et aucune tâche n'a pu naître ensuite jusqu'au 29/09.*

**Ce que c'est.** La première question de l'item — *pourquoi ces copies existent* — est close : elles précèdent l'histoire du dépôt, aucune décision n'est écrite. Il faut donc trancher **sur le fond**, pas par archéologie.

**Le plus petit geste utile**, si on ne veut pas ouvrir le chantier : donner à `resolveMailRouting` de la copie le paramètre `locale` et la lecture de `signature_short_i18n`, à l'identique du canonique. Ça referme la seule divergence dont on a constaté l'effet.

**Le geste complet** : faire pointer les 9 fichiers d'infrastructure de `notify-internal-task` vers `../../_shared/`, et ne garder en propre que les 3 fichiers de tâches. Le risque n'est pas nul — 694 lignes d'écart contiennent peut-être d'autres différences voulues — donc chaque fichier se reprend un par un, en comparant les envois avant/après sur un avis de tâche réel.

**Et dans les deux cas** : écrire en tête de `notify-internal-task/_shared/` ce qui y vit et pourquoi, pour que la prochaine personne n'ait pas à refaire ce relevé.

**Pourquoi ça compte.** Parce que le routage du courriel est justement l'endroit où une divergence ne se voit pas. Un logo résolu autrement, une règle d'extinction appliquée dans une copie et pas dans l'autre : le message part quand même, et personne ne compare deux courriels envoyés par deux fonctions différentes.

C'est exactement ce qui vient de se produire à l'échelle d'une seule colonne — `register` résolvait le logo autrement que toutes les autres fonctions, et l'écart a tenu des mois. Ici l'écart porte sur 139 lignes.

**Ce qui compte comme fini.**

- ~~La divergence de signature localisée est refermée~~ — fait le 30/08, gardé par 6 tests.
- ~~Le sort des 9 fichiers d'infrastructure dupliqués est tranché — réunis, ou assumés par écrit.~~ — réunis le 30/08 (`334e852c`).
- ~~Un en-tête dans `notify-internal-task/_shared/` dit ce qui y vit et pourquoi.~~ — sans objet : le dossier n'existe plus, l'en-tête d'`index.ts` raconte la réunion.
- ~~La collision de nom sur `resolveLibraryLogoUrl` est levée.~~ — une seule définition, dans `_shared/context/library-mail-routing.ts` (`79207ddb`, puis `334e852c`).

**Dépendances.** Aucune. Le relevé est fait — il est dans cet item. Ce qui reste est une décision de portée, pas une enquête.

*Renvois : `supabase/functions/_shared/context/library-mail-routing.ts` · `supabase/functions/notify-internal-task/_shared/ (12 fichiers, dont 9 dupliqués)` · `library_notification_profiles.signature_short_i18n (BLMF, 6 langues)` · `commit e6ec991a — import initial du dépôt, 21/08/2026` · `src/tests/notify-internal-task-signature.test.js`*

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

#### F15 — Les courriels institutionnels aux admins du réseau n'arrivaient que sur une boîte personnelle — une seule résolution des destinataires, avec la boîte collective

`P2` Courant · État : **À vérifier** · Charge : une soirée · Ce que ça demande : Deno / TypeScript

**État.** **Constaté le 24/09/2026 à 21 h 46** : « [AnarBib] Mise à jour d'une demande institutionnelle » (demande d'Anarchief.Org approuvée), envoyé par `notify-library-request` (`admin_update`), est arrivé sur la boîte personnelle de Xavier et nulle part ailleurs. Lu dans le code : la fonction part en éventail vers les admins actif·ves de `network_administrators`, chacun·e dans sa langue, et `ADMIN_EMAIL` ne sert que de repli si personne n'est résolu·e ; **en production il y a UN admin actif** (relevé SQL du 24/09, profil gmail, fr). La boîte collective `admins@anarbib.org` — destinataire des alertes de santé depuis le 28/08 (`HEALTH_ALERT_CC`), des rapports DMARC depuis le 01/09, et nommée « le destinataire de supervision » par E14 — ne voyait donc passer aucun courriel institutionnel. **Neuf endroits** rechargeaient `network_administrators` + `profiles` chacun à leur façon (`notify-library-request`, `notify-cross-library-digest`, `health-probe`, `network.ts`, `team.ts`, `assembleia.ts`, `gazette.ts`, `authority.ts`, `library_profile.ts`), et trois autres n'écrivaient qu'à `ADMIN_EMAIL` seul (`membership-restriction` pour le gel global, `notify-document-permission-request`, `notify-network-weekly-report` en repli). Le précédent existait : `health-probe` faisait déjà admins actif·ves + variable d'environnement, dédoublonnés — avec la règle « ne pas sortir quand la table est vide » (28/08).

*Vérifié : 24/09/2026 — courriel reçu à 21 h 46 lu (PDF) ; `sendToAdmins` lu dans `notify-library-request/index.ts` ; un admin actif compté en base (`network_administrators` × `profiles`) ; `supabase secrets list` : `HEALTH_ALERT_CC` posée, `NETWORK_ADMIN_CC` absente. **Livré le 24/09 au soir** : module + six conversions + modèles d'environnement + garde et bancs (rendu réel de `notify-library-request`, `notify-cross-library-digest`, `membership-restriction`, `notify-network-weekly-report`). Reste le premier critère : un courriel réel lu dans la boîte, à la main de Xavier.*

**Ce que c'est.** Une seule résolution des destinataires d'administration, `supabase/functions/_shared/context/network-admins.ts` : admins actif·ves (chacun·e dans sa langue) **plus** la boîte collective lue dans `NETWORK_ADMIN_CC` (repli `HEALTH_ALERT_CC`, donc effectif en production sans nouveau secret), en **pt-BR** (langue de référence, décision Xavier 24/09), dédoublonnés, jamais vide tant qu'une boîte est posée. **Ajouter, pas remplacer** : l'éventail par personne reste. **Tout ne mérite pas la boîte** : les courriels de gouvernance entre admins (cooptation, retrait collectif, votes à motif nominatif), la facilitation d'AG, l'éditorial de la gazette et de l'atelier restent adressés aux personnes. Passent par le module : `notify-library-request`, `notify-document-permission-request`, `notify-network-weekly-report` (le destinataire historique reste en extra ; 422 seulement si personne), `notify-cross-library-digest`, `membership-restriction` (gel global), `health-probe` (garde SA variable). Une garde à deux listes fermées (`src/tests/admins-reseau-destinataires.test.js`) rougit si une fonction institutionnelle relit la table en direct. Ne pas prendre le raccourci `ADMIN_EMAIL=admins@` : cette variable alimente aussi des replis de Reply-To et l'inscription (six usages).

**Pourquoi ça compte.** Une adresse institutionnelle survit aux départs, aux absences et aux changements d'adresse — ce que la table des admins ne garantit pas. Le réseau n'a qu'un admin actif : chaque demande de bibliothèque, chaque permission documentaire, chaque gel global ne tient aujourd'hui qu'à une boîte gmail personnelle. Et une fonction neuve qui recopie l'ancienne recette repartirait dans le même angle mort.

**Ce qui compte comme fini.**

- Un courriel institutionnel réel (demande de bibliothèque mise à jour, ou rapport hebdo du lundi) est lu dans la boîte `admins@anarbib.org`, en portugais, ET sur la boîte personnelle de l'admin, dans sa langue.
- La garde à listes fermées est verte, et un essai de mutation (relire la table en direct dans une fonction institutionnelle) la fait rougir.

**Dépendances.** Aucune. `HEALTH_ALERT_CC` est déjà posée en production.

*Renvois : `supabase/functions/_shared/context/network-admins.ts` · `src/tests/admins-reseau-destinataires.test.js` · `deploy/functions.env.example` · `mémoire anarbib-alertes-supervision-destinataires`*

#### F16 — L'invitation à une tâche n'a jamais créé d'invitation

`P1` Prioritaire · État : **À vérifier** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL, React / JavaScript

**État.** Relevé par la carte F1 (30/09). `fn_task_invite` ajoute l'adresse BRUTE aux marqueurs de la tâche, alors que `task_invite_emails_from_tags` ne retient que les marqueurs `convite:…` : aucune invitation n'a jamais été créée (`painel_internal_task_invites` : 0 ligne ; file d'invitation : 0 insertion). L'écran annonce pourtant « invitation envoyée », et l'adresse invitée finit dans les « Marqueurs » des avis de tâche.

*Vérifié : **30/09** — livré (`32cfea66`, migration `20260930195644`, appliquée par la CI ; fonctions redéployées le 30/09 à 22 h 21-22 h 23). `fn_task_invite` pose `convite:<adresse>` ; suite `taches_invitation_tests` 6/6 (inviter crée une invitation et une ligne d'envoi, réinviter ne double rien, adresse invalide refusée, retirer le marqueur annule ; 1/6 contre l'ancienne fonction) ; les marqueurs `convite:` ne s'affichent plus (écrans et avis). Les deux critères sont tenus au banc. **Reste** : qu'une invitation réelle parte — inviter quelqu'un (soi-même) à une tâche et recevoir le courriel ; le secret d'expédition existe en production.*

**Ce que c'est.** Migration depuis la définition réelle : `fn_task_invite` pose `convite:` || adresse (ou `task_invite_emails_from_tags` accepte les deux formes) ; `taskTagsLabel` n'affiche plus les marqueurs `convite:` ; suite SQL : un appel crée une invitation et une ligne de file.

**Pourquoi ça compte.** Une fonction qui dit « envoyé » sans rien envoyer : la personne invitée attend un courriel qui ne vient jamais, et son adresse se retrouve affichée dans les avis.

**Ce qui compte comme fini.**

- Inviter une personne à une tâche crée une invitation et un courriel (suite SQL qui emprunte le chemin).
- Aucune adresse n'apparaît dans les marqueurs affichés.

**Dépendances.** Aucune. Sort de F1.

*Renvois : `docs/journal/audits/CARTE_chaine_courriel_2026-09-30.md`*

#### F19 — Les journaux des fonctions contiennent les adresses des destinataires en clair

`P1` Prioritaire · État : **À vérifier** · Charge : une soirée · Ce que ça demande : Deno / TypeScript

**État.** Relevé par la carte F1 (30/09). Les journaux des fonctions Edge portent des lignes « [user_mail] sent to <adresse> » et « [admin_copy] sent to <adresse> » depuis au moins le 04/08 : toute personne qui consulte les journaux lit les adresses des lectrices et du staff.

*Vérifié : **30/09** — livré et déployé (`4158504a`, CI verte, les 55 fonctions redéployées le 30/09 à 22 h 01 ; puis de nouveau le 01/10 avec F17). `masquerAdresse` à la source (transport, notificateurs) et un filet sur `console.*` installé au chargement sous Deno ; banc `journal-sans-adresse` (les 55 fonctions atteignent le masque) ; éprouvé sous Deno 2.7. **Reste le critère** : une semaine de journaux d'envoi sans adresse complète — à relever le 08/10.*

**Ce que c'est.** Masquer l'adresse dans tous les journaux d'envoi (domaine seul, ou empreinte courte), à la source commune (`_shared/transport/email.ts` et les gestionnaires qui journalisent eux-mêmes) ; un test de source refuse un `console.log` qui imprime une adresse.

**Pourquoi ça compte.** Une fuite de données personnelles continue, dans un outil que plusieurs personnes peuvent lire.

**Ce qui compte comme fini.**

- Plus aucune adresse complète dans les journaux d'envoi (relevé sur une semaine de journaux après le correctif).

**Dépendances.** Aucune.

*Renvois : `docs/journal/audits/CARTE_chaine_courriel_2026-09-30.md`*

#### F20 — Sans ligne de politique, une bibliothèque ne voit jamais une réservation expirer ni une non-venue détectée

`P2` Courant · État : **Ouvert** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL

**État.** Relevé par la contre-vérification de la carte F1 (30/09). `fn_expire_solicitada_reservations`, `fn_expire_negotiation_timeout` et `fn_detect_no_show_reservations` font un INNER JOIN sur `library_notification_policies` : dans les deux bibliothèques actives sans ligne de politique, rien n'expire et aucune non-venue n'est détectée, alors que les déclencheurs de notification y sont ouverts par défaut. Latent (aucune réservation hors BLMF).

*Constat du 29/08, non revérifié depuis.*

**Ce que c'est.** LEFT JOIN avec les délais par défaut, ou création des lignes de politique manquantes (et d'une ligne à chaque bibliothèque admise) ; suite SQL qui emprunte l'expiration dans une bibliothèque sans ligne.

**Pourquoi ça compte.** La première bibliothèque qui ouvre les réservations sans passer par ses réglages aura des réservations éternelles.

**Ce qui compte comme fini.**

- Une réservation expire et une non-venue est détectée dans une bibliothèque sans ligne de politique (suite SQL).

**Dépendances.** Aucune.

*Renvois : `docs/journal/audits/CARTE_chaine_courriel_2026-09-30.md`*

#### F21 — Pied de page et ligne « Status » des courriels en pt-BR dans toutes les langues

`P2` Courant · État : **À vérifier** · Charge : une soirée · Ce que ça demande : Deno / TypeScript, langue maternelle

**État.** Relevé par la carte F1 (30/09). Sans `footer_local` (aucune des trois bibliothèques n'en a), le contexte de repli pose un pied de page et une signature en portugais que `tMail` ne traduit plus : tout courriel de bibliothèque se termine en pt-BR, quelle que soit la langue. Et la ligne « Status » des courriels de réservation vient d'une table codée en dur en pt-BR (`WF_LABELS`, `shared/events.ts`).

*Vérifié : 01/10, le soir — **déployé** (PR #31 d'ASR2026, fusion `da034c83`, CI verte à 22 h 23 ; et `9bdce13a`). Les statuts de réservation passent par une clé `wf.stage.*` dans les dix langues (`WF_LABELS` ne sert plus que de repli) ; les courriels d'équipe des emprunts partent dans la langue de la bibliothèque, comme ceux des réservations (le pt-BR forcé du Paquet 17, `96006b81`, est abandonné). Le pied de page : `FOOTER_TEXT` n'a plus de défaut portugais et `tMail` localise quand il manque ; une valeur configurée reste prioritaire. La revue de la PR a trouvé une seconde source du même défaut : `ADMIN_NAME` valait par défaut « Equipe da biblioteca » et revenait par `signature_short` — un courriel français rendu avec la PR finissait encore en portugais. Corrigé par `9bdce13a` : défaut vide, signature au nom de la bibliothèque (`shared/branding.ts`). Preuves : banc `mail-status-footer-i18n` (9 tests, cas réel d'une bibliothèque sans signature), garde `mail-nom-equipe-repli-garde` (4 tests, rouge sans le correctif), 1 672 tests vitest. **Reste à vérifier** : un vrai courriel de réservation en français, en production, sans un mot de portugais. Hors F21, toujours en pt-BR par défaut : `SENDER_NAME` (« Biblioteca da rede AnarBib »).*

**Ce que c'est.** `footer_local` et `signature_short` à null dans `fallbackLibraryNotificationContext` pour laisser `tMail` localiser ; une clé par stage à la place de `WF_LABELS`, dans les dix langues ; un test de source qui rend un courriel en fr et y refuse le portugais.

**Pourquoi ça compte.** Une lectrice francophone reçoit un courriel qui finit en portugais : l'app a l'air de ne pas savoir à qui elle parle.

**Ce qui compte comme fini.**

- Un courriel rendu en fr, nl ou el ne contient plus de portugais (test de source sur le rendu).

**Dépendances.** Aucune.

*Renvois : `docs/journal/audits/CARTE_chaine_courriel_2026-09-30.md`*

---

### G — Réseau, gouvernance, fédération

*Beaucoup de circuits construits, très peu empruntés. C'est le principal enseignement du relevé.*

| | | | |
|---|---|---|---|
| **G1** | Emprunter les circuits construits et jamais utilisés | `P0` | Ouvert |
| **G6** | Mener un prêt entre bibliothèques de bout en bout par son écran | `P2` | Ouvert |
| **G8** | Compléter la cartographie avec les archives repérées ailleurs | `P2` | Ouvert |
| **G9** | Implémenter la cartographie du réseau selon la spec v1.0 | `P3` | Gelé |
| **G10** | Solder les trois questions d'onboarding marquées « au plus vite » | `P2` | Ouvert |
| **G13** | Un commutateur « réseaux constitués » à l'OPAC : ne voir que les catalogues FICEDL, RebAL, NORLA… | `P2` | Ouvert |
| **G15** | DIRA : un essai d'import sur échantillon avant toute adhésion, PMB restant la base de référence | `P1` | Ouvert |

#### G1 — Emprunter les circuits construits et jamais utilisés

`P0` Structurel · État : **Ouvert** · Charge : plusieurs semaines · Ce que ça demande : délibération collective, aucune compétence technique

**État.** Vérifié le 29/08 : **62 tables métier n'ont jamais reçu la moindre insertion.** Sept blocs entiers sont concernés — assemblées du réseau (3 tables), notes de lecture (2), propositions et objections d'autorité (3), référentiels de catalogage `catalog_ref_*` (8 sur 9), gouvernance des profils de bibliothèque (4, **alors que deux crons tournent dessus toutes les quinze minutes**), délibération sur les demandes d'adhésion (5, dont `library_request_votes` et `library_request_messages`).

**Remesuré le 31/08 : toujours 62, et ce n'est pas une bonne nouvelle.** Le compte n'a pas bougé en deux jours — 62 tables de `public` sur 189 n'ont jamais reçu la moindre insertion. Mais ce n'est pas la même liste : `loan_cycle_notifications`, née ce matin avec les rappels d'échéance, y est entrée **le jour de sa création**. Un circuit livré aujourd'hui rejoint aussitôt la colonne des circuits jamais empruntés — c'est exactement le mécanisme que cet item nomme, et il continue de tourner pendant qu'on le décrit.

**Un premier livre circule.** L'emprunt **#69** a été ouvert ce matin à 11 h 43 à la BLMF — item 84, *O Anarquismo na Escola, no Teatro, na Poesia* d'Edgar Rodrigues, échéance **21/09**. Il donne au bloc *notes de lecture* sa première chance réelle : le mi-parcours calculé par `notify-loan-cycle` tombe le **10 septembre**, et l'invitation à déposer une note sous pseudonyme partira ce jour-là (item **F4**). `book_reading_notes` est encore à zéro ligne ; si elle en porte une le 11, un des sept blocs sera sorti de cette liste pour de bon — et pas parce qu'on l'aura décidé, parce que quelqu'un l'aura emprunté.

Les six autres blocs sont inchangés au 31/08, vérifiés table par table : assemblées du réseau (3), propositions et objections d'autorité (3), référentiels `catalog_ref_*` (8), gouvernance des profils de bibliothèque (4, **et les deux crons tournent toujours dessus toutes les quinze minutes**), délibération des demandes d'adhésion (5). Tous à zéro insertion.

*Vérifié : [object Object],[object Object],[object Object]*

**Ce que c'est.** Choisir un bloc et l'emprunter pour de vrai, du premier geste au dernier : tenir une assemblée du réseau, déposer une note de lecture, proposer une autorité et laisser quelqu'un objecter, faire délibérer une demande d'adhésion. Consigner ce qui manque, ce qui surprend, ce qui bloque.

**Pourquoi ça compte.** C'est le principal enseignement du relevé du 29 août, et il ne figure dans aucun document du corpus. **Le projet ne souffre pas d'un manque de fonctionnalités : il souffre d'un manque d'usage.** Un circuit jamais emprunté n'est pas livré — il est seulement écrit. Et le jour où il devient le chemin critique, comme le circuit d'invitation vient de le devenir pour les promotions, il casse sur des choses qu'un seul passage aurait révélées.

**Ce qui compte comme fini.**

- Au moins trois des sept blocs ont été empruntés de bout en bout, sur `blmf-teste` puis en réel.
- Chaque passage a produit un compte rendu écrit de ce qui manque.
- Les blocs dont l'usage n'est pas souhaité aujourd'hui sont marqués **dormants**, avec la raison — ce n'est pas un échec, c'est une information.

**Dépendances.** Le bloc « assemblée » dépend de **A1**. Les autres non.

*Renvois : `Relevé du 29/08/2026` · `REGISTRE §32 AG, §28 ATE, §26 ONBO` · `emprunt #69 (BLMF, item 84, échéance 21/09)` · `item F4` · `public.book_reading_notes`*

#### G6 — Mener un prêt entre bibliothèques de bout en bout par son écran

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : React / JavaScript, bibliothéconomie

**État.** Le cycle de vie du prêt entre bibliothèques est spécifié et implémenté en base : machine à états verrouillée, quatre triggers, cron `anarbib-peb-detect-overdue-daily` actif. **Un écran existe** : l'onglet PEB de la page Bibliothèque, présent dès le commit initial d'AnarBib v3 (`92e0064e`, 26/04), passé aux RPC PEB le 20/05 (`e4a0b9d6`, EA-12 phase 1), devenu `IllSection.jsx` le 28/09 (`3c33b9f6`). Un prêt s'y affiche chez la prêteuse comme chez l'emprunteuse. Le 29/08, la base portait 2 prêts pour 20 insertions historiques.

*Vérifié : 31/08 — `interlibrary_loans_v2` : 2 prêts vivants pour 20 insertions historiques, comme au 29/08. **29/09** — l'onglet emprunté à l'écran par Xavier (revue d'E6) : un prêt d'essai créé avec son exemplaire (la file de notification a reçu son événement), puis supprimé ; les deux PEB de mai (n° 24 et 25) archivés ; un second prêt d'essai (n° 35) créé, son retour pointé en deux fois, archivé. Un défaut trouvé en chemin : « Supprimer » s'offrait à un prêt déjà sorti, la base le refusait et l'écran affichait « refusé par RLS ». Le bouton ne s'offre plus qu'aux deux statuts que la politique DELETE accepte (préparation, attente de sortie), et un refus se dit en clair dans les dix langues (`b3ac9d13`). Au relevé du soir, aucun PEB n'est ouvert. Le critère 1 n'est pas tenu : c'étaient des essais d'une seule personne, pas un prêt réel entre deux bibliothèques, chacune tenant son côté.*

**Ce que c'est.** Un écran de demande côté bibliothèque emprunteuse, un écran de traitement côté prêteuse, et l'affichage de l'état pour les deux. Les vues `interlibrary_loans_painel_ui` et `interlibrary_loan_items_ui` existent déjà.

**Pourquoi ça compte.** Le prêt entre bibliothèques est ce qui rend un réseau fédératif utile à ses lectrices, plutôt qu'une simple juxtaposition de catalogues. Le corpus le disait « une amorce en base, même sans écran » ; l'écran existait pourtant (voir v). Ce qui manque, c'est qu'un prêt réel le traverse de bout en bout.

**Ce qui compte comme fini.**

- Un prêt complet a été fait entre deux bibliothèques du réseau, par l'interface.
- Le flux « livre perdu ou abîmé » a un traitement écrit — **aucun flux ne le couvre aujourd'hui**, il se traite hors SIGB avec remontée en coordination.

**Dépendances.** `EA-12 phase 2` (parité PEB, environ 45 fonctions) est gelée par `BIBLIO-9` — à ne pas confondre avec cet item.

*Renvois : `spec-cycle-vie-peb.md` · `PLAN_formation_coordination_BLMF §5` · `REGISTRE §14 PEB`*

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

#### G15 — DIRA : un essai d'import sur échantillon avant toute adhésion, PMB restant la base de référence

`P1` Prioritaire · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : aucune compétence technique, bibliothéconomie

**État.** Le 26/09/2026, DIRA a écrit au réseau (« Demande d'adhésion au réseau AnarBib — DIRA ») : une bibliothèque sous **PMB**, avec une collection multilingue, des zines, des archives de collectifs et un comité documentaire actif. Sa question centrale est la pérennité : que deviennent ses données si le projet s'arrête ? La réponse préparée le même jour ne promet pas un aller-retour qui n'existe pas encore (voir **H23**, **H24**). Elle propose un essai sur un échantillon d'une cinquantaine de notices en UNIMARC ISO 2709 avec exemplaires (995), la version de PMB et l'encodage de la base, sans données de lecteur·ices ni de prêts. **Mesuré le 26/09 en production** : aucune instance d'essai séparée n'existe (le projet « staging » est la production). L'essai se fait donc sur le banc (**H14**), sans rien publier.

*Vérifié : **29/09** — l'envoi de la réponse à DIRA n'est daté nulle part dans le dépôt (critère 1). L'aller-retour que la réponse du 26/09 ne promettait pas est depuis éprouvé au banc : **H27** clos le 29/09 (l'export tiré de la base, réimporté dans un PMB vide, rend 46 exemplaires sur 46). Deux pièces existent pour le compte rendu : le CSV de couverture d'un import (**H16**, `4be5fee9`) et le tableau de l'aller-retour (`docs/interop/couverture-pmb.md`).*

**Ce que c'est.** Envoyer la réponse (Xavier). À réception de l'échantillon, le passer au banc (**H14**), avec l'encodage (**H15**) et les exemplaires (**H19**). Renvoyer à DIRA le rapport de couverture (**H16**) : ce qui passe, ce qui se perd, ce qui reste à construire. Décider ensuite, par écrit, d'ouvrir ou non un accès. L'adhésion elle-même suit le circuit ordinaire des admins réseau.

**Pourquoi ça compte.** C'est la première bibliothèque qui vient d'un autre SIGB avec une vraie exigence de réversibilité. Si l'essai est honnête, il fait de DIRA une bibliothèque qui rend le projet durable ; s'il survend, on la perd, et avec elle la crédibilité de l'argument « vos données restent à vous ».

**Ce qui compte comme fini.**

- Réponse envoyée, datée.
- Échantillon reçu, avec version de PMB et encodage.
- Rapport de couverture envoyé à DIRA.
- Décision d'accès écrite, avec sa raison.

**Dépendances.** Avant le compte rendu : **H28** (livré le 26/09 — sans lui aucun ISO 2709 ne s'importait), **H14** (clos le 26/09), **H15** et **H16** (livrés le 26/09), **H19** (livré le 27/09) ; **H28**, **H15**, **H16** et **H19** restent à vérifier sur un import réel. Avant toute bascule : **H23** et **H24** (livrés le 28/09), **H27** (clos le 29/09) et **H21** (en cours : décisions `IMP-26` et `IMP-27` du 29/09, lot 0 livré le 01/10, puis **H30** et **H31**). Les archives : **D7** (clos le 27/09 ; réalisation : **D8**).

*Renvois : `claude/aller-retour-PMB_2026-09-26` · `Réponse à DIRA du 26/09/2026`*

---

### H — Interopérabilité, thésaurus, moisson

*Sortir vers les autres catalogues, et accepter d'être pointé en retour.*

| | | | |
|---|---|---|---|
| **H2** | Poser à la FICEDL les sept questions qui bloquent l'export du thésaurus | `P1` | Bloqué |
| **H6** | Aligner les vocabulaires militants qui ne se connaissent pas | `P2` | Ouvert |
| **H12** | Les listes hors thésaurus de la FICEDL — communes du Bettini, lieux d'édition du Bianco : demander l'export tel quel, jamais l'intégration | `P3` | Ouvert |
| **H28** | Un fichier MARC ISO 2709 s'importe : le format détecté est admis par la base | `P1` | À vérifier |
| **H15** | L'import lit un fichier qui n'est pas en UTF-8 au lieu de le corrompre en silence | `P1` | À vérifier |
| **H16** | Un rapport de couverture par import : chaque zone du fichier que l'import ne reprend pas est comptée et montrée | `P1` | À vérifier |
| **H17** | Le mapping UNIMARC reprend les zones courantes d'un catalogue PMB | `P1` | À vérifier |
| **H18** | Les responsabilités importées gardent leur rôle, leur nature (personne ou collectivité) et leur lien d'autorité | `P1` | À vérifier |
| **H19** | Les exemplaires d'un catalogue importé (995 en UNIMARC, 852 en MARC21) deviennent des exemplaires AnarBib | `P1` | À vérifier |
| **H20** | L'identifiant d'origine d'une notice est gardé par bibliothèque, pas seulement sur la notice partagée | `P1` | À vérifier |
| **H21** | Réimporter un catalogue met à jour ce que l'import connaît déjà au lieu de le dupliquer | `P2` | En cours |
| **H22** | Lire l'export XML propre à PMB, s'il le faut | `P3` | À vérifier |
| **H23** | Un export UNIMARC (ISO 2709 et XML), miroir exact de l'import | `P1` | À vérifier |
| **H24** | L'export d'une bibliothèque contient tout ce qu'elle a catalogué : exemplaires, responsabilités, sujets, collection, identifiants | `P1` | À vérifier |
| **H25** | Exporter les autorités (UNIMARC Autorités), pour que les liens $3 de l'export mènent quelque part | `P2` | À vérifier |
| **H26** | L'export d'un gros catalogue ne dépend plus de la mémoire d'une edge function | `P2` | À vérifier |
| **H29** | Au retour dans PMB, un exemplaire garde son type, sa section et son code statistique | `P2` | Ouvert |
| **H30** | « Retraiter » un import sans fichier (moisson OAI, candidat, dépôt direct) n’efface plus ses lignes | `P1` | Ouvert |
| **H31** | « Retraiter » juge le run au moment d’effacer, pas seulement à l’envoi | `P2` | Ouvert |

#### H2 — Poser à la FICEDL les sept questions qui bloquent l'export du thésaurus

`P1` Prioritaire · État : **Bloqué** · Charge : une soirée · Ce que ça demande : délibération collective

**État.** L'export complet des 620 descripteurs dans les deux formats est **à une soirée de travail** — dès que les sept questions ont une réponse. Elles sont écrites et personne ne les a encore posées.

*Vérifié : [object Object],[object Object]*

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

**Dépendances.** Octobre-novembre, si le camarade s'y met. Lié à **D4**.

*Renvois : `ORIENTATION_outils_bibliotheques_militantes_2026-08-26 §6` · `VEILLE_leftovers_maydayrooms_2026-08-19`*

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

#### H28 — Un fichier MARC ISO 2709 s'importe : le format détecté est admis par la base

`P1` Prioritaire · État : **À vérifier** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL, React / JavaScript

**État.** **Trouvé le 26/09 par la cartographie de l'import, confirmé en production.** La CHECK `partner_catalog_import_runs_detected_format_check` n'admettait ni `marc_iso2709` — le mot que `process-partner-catalog-import` écrit pour tout ISO 2709 reconnu — ni `marc21`, que le front envoyait pour un `.mrc` ou un `.marc`. Le front échouait donc à la **création** du run (23514) ; l'EF, elle, échouait à son **UPDATE final**, après avoir inséré ses lignes : run « failed », lignes invisibles à l'écran. **Aucun run MARC n'avait jamais tourné** (8 runs : 5 CSV, 3 RIS) — le défaut était invisible. Or PMB livre ses exports UNIMARC en `.marc` : c'était le premier fichier que DIRA aurait envoyé.

*Vérifié : 26/09 — migration `20260926184500` appliquée par la CI (`created_by` vide) ; CHECK en production : `marc_iso2709` présent ; banc de la vraie EF sur l'export PMB : `detected_format = marc_iso2709` écrit. **28/09** — toujours aucun run `marc_iso2709` en production (relevé fait pour **H17**) : le critère 2 attend. Plus loin que « prêt à revoir », un lot MARC ne se serait pas publié (langue brute contre la CHECK BCP-47) : corrigé le 28/09 (`2ee5f7a7`, voir **H17**). **29/09** — `import_format_marc_tests` (4 tests) tourne en CI depuis `d008bb51` ; dernière batterie relevée : SQL 149/149, avant la poussée de `2348cb86`.*

**Ce que c'est.** **Livré le 26/09** (`d008bb51`, migration `20260926184500`) : `marc_iso2709` admis, `marc21` toujours refusé (un vocabulaire, pas un format — `forced_vocabulary`) ; une seule copie de `detectFileKind` (`src/lib/importFileKind.js`, il y en avait deux), `.mrc`/`.marc`/`.iso` → `marc_iso2709`, suffixe `.iso` accepté ; garde vitest `import-file-kind` (chaque format écrit par le front ou par l'EF appartient à la CHECK de la **dernière** migration qui la pose) ; suite SQL `import_format_marc_tests`. Reste : **un premier import ISO 2709 réel en production** (l'échantillon de DIRA, ou un export PMB du banc déposé par une coordination).

**Pourquoi ça compte.** C'est la porte d'entrée de tout l'aller-retour PMB : sans elle, aucun des items H15 à H27 n'aurait pu servir.

**Ce qui compte comme fini.**

- La CHECK admet `marc_iso2709` en production (fait, 26/09).
- Un import ISO 2709 réel passe en production jusqu'à « prêt à revoir ».

**Dépendances.** Avant **H15** et **H19** (faits ou en cours). Éprouvé en vrai par **G15**.

*Renvois : `claude/aller-retour-PMB_2026-09-26` · `tests/pmb/README.md`*

#### H15 — L'import lit un fichier qui n'est pas en UTF-8 au lieu de le corrompre en silence

`P1` Prioritaire · État : **À vérifier** · Charge : une soirée · Ce que ça demande : Deno / TypeScript

**État.** `process-partner-catalog-import/index.ts` (l. 623) et `marc.ts` (l. 303) décodent **toujours en UTF-8** (`new TextDecoder('utf-8')`, sans `fatal`). Seul le MARC-8 (leader/9 blanc) déclenche un avertissement. Une base PMB en ISO-8859-1, courante sur les installations anciennes, donnerait des accents remplacés par U+FFFD, **sans aucun avertissement**. Il en va de même pour un CSV enregistré en Windows-1252 par un tableur. **Mesuré sur le banc PMB le 26/09** (`tests/pmb`) : sur un vrai export PMB transcodé en latin-1, **29 notices sur 50** portaient U+FFFD, et chaque UNIMARC recevait un **faux « MARC-8 détecté »** (leader/9 blanc, non défini en UNIMARC — PMB 8.1 l'écrit ainsi). **Livré le 26/09** (`f1159947`, `6ab73436`, migration `20260926191500`) : UTF-8 strict, repli windows-1252 **supposé** et dit (`summary.encoding`, `summary.warnings`, première ligne) ; `forced_encoding` lu avant le décodage ; MARC-8 réservé au MARC21 ; 100 `$a`/26-29 relu et confronté ; `fn_import_set_adapter_overrides` gagne `p_forced_encoding` et **fusionne** (elle effaçait `profile_id`) ; `fn_import_dispatch` refuse de retraiter un import déjà promu (le lien ligne → brouillon partait en cascade) ; écran : sélecteur, panneau « encodage lu », geste « Retraiter », 14 clés × 10 locales.

*Vérifié : 26/09 — la variante latin-1 de l'export PMB donne exactement les mêmes notices que l'UTF-8 (`pmb-fixtures-parseur`, banc de la vraie EF `process-partner-catalog-import-banc`) ; suite SQL `import_encodage_overrides_tests` 6/6. Reste : un import réel en latin-1 en production, et le panneau vu à l'écran par une coordination.*

**Ce que c'est.** Décoder en UTF-8 strict (`fatal: true`) ; en cas d'échec, relire en Windows-1252 et **le dire** dans les avertissements du run. Pour l'ISO 2709 UNIMARC, lire aussi le jeu de caractères déclaré en 100 $a/26-29. Ajouter un réglage `forced_encoding` à `adapter_overrides` (utf-8, iso-8859-1, windows-1252). Tester avec une fixture latin-1 (**H14**).

**Pourquoi ça compte.** Une corruption silencieuse est la pire des pertes : personne ne la voit avant qu'une lectrice cherche un titre accentué. Et elle frapperait justement les bibliothèques européennes qui viennent de PMB.

**Ce qui compte comme fini.**

- Fixture latin-1 importée sans U+FFFD.
- L'encodage retenu apparaît dans les avertissements du run.
- Test au banc des edge functions.

**Dépendances.** Après **H28** (fait). Fixture de **H14** (faite).

*Renvois : `claude/aller-retour-PMB_2026-09-26` · `Réponse à DIRA du 26/09/2026`*

#### H16 — Un rapport de couverture par import : chaque zone du fichier que l'import ne reprend pas est comptée et montrée

`P1` Prioritaire · État : **À vérifier** · Charge : quelques jours · Ce que ça demande : Deno / TypeScript, SQL / PostgreSQL, React / JavaScript

**État.** L'enregistrement brut est bien gardé : `ingest.partner_catalog_staging_rows.raw_payload`, recopié en `book_drafts.marc_json` par `ingest.fn_create_book_drafts_from_import_rows`, puis en `books.marc_json` à la publication (2 250 brouillons en portent un au 26/09). Mais **rien ne dit quelles zones ont été laissées de côté**. Aujourd'hui la perte ne se voit pas : ni dans Importações, ni dans le rapport de révision de lot (`fn_batch_review_report`). **Depuis H15 (26/09)**, `summary` porte déjà `encoding`, `warnings` et `adapter` : la couverture s'y range à côté. Relevé du 26/09 : l'import Solidaires (run 29, 1 673 lignes CSV) n'a reconnu que **4 colonnes sur 17** (`titulo`, `autor`, `idioma`, `numero`) — `tipo_material`, `assunto_local`, `subtitulo_sugerido` et dix autres ont été ignorées sans un mot.

*Vérifié : 26/09 — suite SQL `import_couverture_tests` 5/5 ; banc de la vraie EF sur l'export PMB et sur un CSV (lignes écartées comptées) ; écran rendu avec les locales fr et el (`import-coverage-ecran`). Déployé le 26/09 au soir : migration `20260926194500` appliquée par la CI (`created_by` vide), `fn_batch_review_report` porte `coverage` en production, droits inchangés (pas anon) ; EF redéployées (`deployed-functions` = `4be5fee9`), sondées au démarrage.*

**Ce que c'est.** Au parse, calculer pour chaque run l'inventaire des zones et sous-zones : présentes, reprises, ignorées, avec leur nombre d'occurrences et un exemple. Pour un CSV, lister les colonnes non mappées. Le stocker dans `partner_catalog_import_runs.summary`. L'afficher dans Importations et le joindre à `fn_batch_review_report`. Le rendre téléchargeable, pour l'envoyer tel quel à la bibliothèque (c'est le compte rendu promis à DIRA). Dix locales. **Livré le 26/09** (`c38e400b`, `4be5fee9`, migration `20260926194500`) : `marcCoverage` (seule référence : la table de zones du dialecte ; `surplus` = répétitions non reprises), `csvCoverage`/`risCoverage` (alias CSV sortis de `mapRecord` en une seule liste ; « indice » = colonnes et balises relues par le SQL : collection, cote locale), `summary.coverage`/`coverage_counts`/`skipped_rows` ; `fn_batch_review_report` gagne `coverage` (seuls les éléments non repris, corps extrait du banc au md5 de la prod) ; écran : panneau « ce que l'import a repris du fichier », section du rapport de révision, **CSV téléchargeable** (le compte rendu à renvoyer à DIRA), 16 clés × 10 locales. Mesuré sur l'export PMB : 111 sous-zones, 17 reprises ; 995, 215, 225, 330, 676 en brut. **Reste** : le moissonnage OAI (`harvest-oai-pmh`, par lots sur un même run) n'écrit pas encore de couverture ; le panneau vu à l'écran sur un import réel.

**Pourquoi ça compte.** C'est ce qui rend l'import **sûr** : rien ne se perd sans qu'on le voie. Et c'est aussi la liste de travail de **H17**, tirée des catalogues réels plutôt que d'une norme lue de loin.

**Ce qui compte comme fini.**

- Rapport visible pour un import MARC et pour un import CSV.
- Joint au rapport de révision de lot.
- Téléchargeable ; dix locales ; test.

**Dépendances.** Avant **H17** (il dit quelles zones comptent).

*Renvois : `claude/aller-retour-PMB_2026-09-26` · `Réponse à DIRA du 26/09/2026`*

#### H17 — Le mapping UNIMARC reprend les zones courantes d'un catalogue PMB

`P1` Prioritaire · État : **À vérifier** · Charge : quelques jours · Ce que ça demande : Deno / TypeScript, bibliothéconomie

**État.** La table `UNIMARC` de `marc.ts` (l. 55-74) ne reprend que 200 $a$e$f, 205, 210 $a$c$d, la première 101, 010, 011, 70x/71x $a$b et 60x $a. Elle ignore : **214** (publication, UNIMARC récent), **215** (pages), **225/410** (collection), **300/327/330** (notes, sommaire, résumé), **676/686** (classification), **856** (URL), **200 $h$i** (tomes), les subdivisions **60x $x$y$z** et **461/463** (dépouillement de périodique). **Zones présentes dans un export PMB réel** (jeu de test PMB 8.1, 26/09) : 001 009 010 100 101 102 200 210 **214** 215 225 300 319 327 330 410 461 462 463 464 530 606 610 676 700 701 702 710 711 801 856 896 995 996 — soit la liste de travail, dans cet ordre de fréquence à mesurer par **H16**. **Livré le 28/09** (`8c80de27`, migration `20260928111814`) : type de matériel déduit du guide (article MARC21 « b », fascicule de bulletin PMB lu comme périodique), pages, volume, collection d'une seule zone (225 ou 410), notes (300, 327, 330), classification, adresse électronique (856), périodique et article (ISSN de la revue hôte, numéro, date) ; chaque zone laissée exprès a un motif codé, traduit dans les 10 langues, et le rapport de couverture les distingue ; MARC21 : ponctuation ISBD retirée. Suite SQL `import_zones_tests` (13 blocs). Revue contradictoire H17/H18/H22 : 34 constats confirmés, corrigés. **Reste** : un import PMB réel en production ; rattacher à leur périodique (`serials`) les fascicules importés.

*Vérifié : 28/09 — migrations appliquées par la CI (`created_by` vide), `deployed-functions` = `8c80de27` ; aucun import MARC encore en production (0 run `marc_iso2709`) : rien à constater sur des données réelles. **28/09** — corrigé par la preuve de **H27** (`2ee5f7a7`, revue `a692a75e`, migration `20260928170909`), déployé (`deployed-functions` sur `a692a75e`) : les mots-clés 610/653 arrivent à part au lieu d'être fondus dans les vedettes ; la langue est convertie en BCP-47 à la création du brouillon (`ingest.fn_idioma_bcp47`, 36 langues ; en production, `fn_idioma_bcp47('fre')` = fr) — sans cela, un lot MARC ne se publiait pas ; l'ISSN d'un article est d'abord celui de sa revue. **29/09** — revues de la fin de H27 (`466324aa`, `2348cb86`, migration `20260929102719`), déployées (`deployed-functions` sur `2348cb86`) : sur un périodique, un 010 $a de forme ISSN va en ISSN (PMB y écrit l'ISSN) ; une notice de bulletin PMB prend le titre de sa revue en 200 $h, sinon à la dernière 463 $t, et garde le sien à part ; la 461 $t d'une monographie qui a déjà une collection va en note « Série: » ; 463 $x $e, 225 $i $x, 410 $x et 411 sont laissés avec leur motif. Par l'écran, une revue et ses fascicules, un ensemble et ses tomes ne sont plus « doublon possible » l'un de l'autre, et un article n'est plus rapproché de sa revue par l'ISSN (`import_doublons_intra_lot_tests` 19, `import_rapprochement_issn_tests` 4 ; en production, les deux fonctions au md5 du banc). `marc.test.ts` : 35 tests pontés (28 à `8c80de27`).*

**Ce que c'est.** Étendre la table et la forme normalisée, zone par zone, dans l'ordre que donne le rapport de couverture (**H16**) sur le jeu de **H14** et sur l'échantillon de DIRA. Faire les mêmes ajouts côté MARC21 (300, 490, 5xx, 082, 856) pour garder la symétrie. Chaque champ nouveau suit la règle des trois endroits (`book_drafts`, `publish_book_draft`, `create_book_draft_from_book`). Un test par zone.

**Pourquoi ça compte.** Une notice qui arrive sans pagination, sans collection, sans résumé ni classification oblige à tout reprendre à la main. Ça annule l'intérêt d'importer.

**Ce qui compte comme fini.**

- Les zones listées sont reprises, testées une à une.
- Le rapport de couverture de la fixture PMB ne montre plus que des zones délibérément laissées.

**Dépendances.** Après **H16**. 461/463 touche les périodiques (`serials`, autorité de titre). Les responsabilités sont dans **H18**.

*Renvois : `claude/aller-retour-PMB_2026-09-26` · `Réponse à DIRA du 26/09/2026`*

#### H18 — Les responsabilités importées gardent leur rôle, leur nature (personne ou collectivité) et leur lien d'autorité

`P1` Prioritaire · État : **À vérifier** · Charge : quelques jours · Ce que ça demande : Deno / TypeScript, SQL / PostgreSQL, bibliothéconomie

**État.** `authorNames()` (`marc.ts`) réduit chaque zone 70x/71x à une chaîne « $a, $b ». Les codes de rôle **$4** sont perdus, le numéro d'autorité **$3** aussi, et une collectivité (71x) devient un nom parmi d'autres. **Mesuré le 26/09 en production** : la table `authors` n'a aucune colonne `kind`, `entity_type`, `is_corporate`, `author_type` ni `type`. La nature se lit donc ailleurs, ou pas du tout (à instruire). La source de vérité des responsabilités est `book_contributors` (`book_authors` en est dérivée). **Livré le 28/09** (`8c80de27`, migration `20260928111814`) : `book_contributors` et `book_draft_contributors` gagnent `nature` (personne, collectivité, congrès) et `role_code` (le code d'origine) ; tous les $4/$e sont lus, une 702 sans code devient « outro », l'URI de relation est gardée ; la nature et le code suivent la publication, la reprise d'une notice, la fusion de notices et la scission d'autorité. Les rapprochements d'autorité sont **proposés** en révision, jamais appliqués, en une seule passe pour tout le lot (`fn_conv_autorites_homonymes` : 44 ms en production pour le lot 63, contre plus de 60 s nom par nom) ; le rapport de révision aussi. Rattrapage des brouillons importés en cours (jamais un non-agent). Au passage : la reprise d'une notice effaçait, à la republication, ses champs article, thèse, zine, distributeur et le texte des sujets (aucune notice touchée en production). **Reste** : un import MARC réel en production (aujourd'hui 0 contributeur y porte une nature).

*Vérifié : 28/09 — migrations appliquées par la CI (`created_by` vide), `deployed-functions` = `8c80de27` ; `fn_conv_autorites_homonymes(text[])` et `ingest.fn_h18_nom_d_auteur(jsonb)` en base ; 0 `book_contributors` et 0 `book_draft_contributors` avec une nature (0 run MARC en production) ; lot 63 : 1 395 contributeurs de brouillon. **28/09** — corrigé par la preuve de **H27** (`2ee5f7a7`, revue `a692a75e`, migration `20260928170909`), déployé : un nom grec, cyrillique, arabe ou chinois n'est plus pris pour « Collectif » (`fn_conv_est_non_agent` comparait une forme normalisée vide) ; ses responsabilités étaient écartées à l'import, au rattrapage H18, au rapport de révision et aux candidats d'autorité. Seul un nom sans lettre reste un non-agent ; `v_author_alias_worklist` et `api.report_autorites_doublons` ne prennent plus la clé vide pour un nom. À l'export, une responsabilité secondaire garde son niveau d'origine (701/702, 711/712) quand le rôle n'a pas changé. En production, un nom grec n'est plus un non-agent ; aucune notice n'était touchée (0 import MARC publié, lu le 28/09).*

**Ce que c'est.** Rendre une forme structurée `{ nom, nature, rôle, référence d'autorité }`, avec une table de correspondance des codes $4 vers les rôles AnarBib. Alimenter `book_contributors` depuis les brouillons. Rapprocher les autorités par `fn_conv_autorite_homonyme` (la recherche par nom) et présenter les rapprochements en révision de lot, jamais d'office. Même travail en MARC21 (100/110/111/700/710/711, $e/$4).

**Pourquoi ça compte.** Un traducteur importé comme auteur, ou un collectif militant importé comme une personne : c'est exactement le genre d'erreur qu'un comité documentaire repère en premier, et qui fait perdre confiance dans tout le lot.

**Ce qui compte comme fini.**

- Rôles et nature conservés sur la fixture PMB.
- Rapprochements d'autorité proposés en révision, pas appliqués d'office.
- Tests.

**Dépendances.** Avant **H24** (l'export relit les mêmes rôles).

*Renvois : `claude/aller-retour-PMB_2026-09-26` · `Réponse à DIRA du 26/09/2026`*

#### H19 — Les exemplaires d'un catalogue importé (995 en UNIMARC, 852 en MARC21) deviennent des exemplaires AnarBib

`P1` Prioritaire · État : **À vérifier** · Charge : quelques jours · Ce que ça demande : Deno / TypeScript, SQL / PostgreSQL

**État.** Le parseur ignore la 995, où PMB exporte ses exemplaires. **Mesuré le 26/09 en production** : l'infrastructure existe mais n'a jamais servi à l'import. `exemplar_drafts`, `publish_exemplar_draft` et `ingest.fn_create_exemplar_drafts_from_import_rows` sont en base, mais **0** ligne de staging porte un `created_exemplar_draft_id`. Et `exemplares.tombo` est **unique sur toute la base** (`exemplares_unique_tombo`) : les codes-barres de deux bibliothèques peuvent entrer en collision (23505). **Relevé du 26/09 (cartographie + banc PMB).** Conventions 995 de PMB 8.1, vues dans ses exports : `$a`/`$c` propriétaire, `$f` code-barres, `$k` cote, `$u` note, `$r` type, `$q` public/section (+ une 996 propre à PMB). Trois pièges côté AnarBib : *(1)* `publish_book_draft` pose `greatest(1, initial_copies)` — importer N exemplaires ET publier la notice en ferait **N+1** ; *(2)* sur collision, `publish_exemplar_draft` **régénère le tombo en silence** (`fn_next_tombo`, qui lève si la biblio n'a pas de `tombo_pattern`) — le code-barres d'origine serait perdu ; *(3)* `ingest.fn_unreconcile_staging_on_exemplar_draft` remet la ligne de staging à « pending » dès qu'UN brouillon d'exemplaire lié est annulé — ne pas réutiliser `created_exemplar_draft_id` pour N exemplaires. Côté PMB (retour) : `func_bdp` **ignore le propriétaire de la 995** (il vient du formulaire).

*Vérifié : 27/09 — suite SQL `import_exemplaires_tests` 30/30 et les 118 suites de la CI ; banc de la vraie EF sur l'export PMB (profil honoré, profil supprimé ou illisible sans rien effacer) ; tests Deno du parseur (sous-zones répétées) ; écran rendu en fr et el (`import-exemplaires-ecran`, `shelf-location`). **29/09** — IMP-25 déployé (`2f488790`) : migration `20260929103533` appliquée par la CI (`created_by` vide), `publish_book_draft` au md5 du banc en production ; suites `import_sans_exemplaire_tests` (3) et `import_exemplaires_tests` 30/30. Le déploiement du 27/09 n'était dit que par `cebde675` : migration `20260927113000` appliquée par la CI, vérifiée en production.*

**Ce que c'est.** Lire d'abord `fn_create_exemplar_drafts_from_import_rows` : c'est un chemin jamais emprunté. Parser la 995 ($f code-barres, $k cote, $a/$b propriétaire et prêteur, $r type, $o/$q circulation, $u note) et la 852 en MARC21. Porter les exemplaires dans le staging, puis créer les brouillons d'exemplaires rattachés au brouillon de notice. ~~Préfixer le `tombo` par un code de bibliothèque (comme `SOL-`).~~ Écarté le 26/09 (IMP-21 a) : le `tombo` suit le schéma de la bibliothèque. Traduire le statut vers `circulation_policy`. Les conventions de sous-zones varient d'une installation PMB à l'autre : prévoir un profil par source. **Décisions attendues de Xavier (exposées le 26/09, rien n'est construit avant) :** *(1)* **numérotation** — A : `tombo` = code PMB préfixé ; **B (recommandée)** : `tombo` selon le schéma AnarBib de la bibliothèque, code PMB dans une colonne dédiée ; C : au choix dans le profil ; *(2)* le **code d'origine dans une colonne dédiée**, unique par bibliothèque (et non dans une note) — il est la clé de **H21** (réimport) et de **H24** (995 `$f` à l'export) ; *(3)* la **correspondance 995** réglée dans le profil de la bibliothèque (précise IMP-19 au REGISTRE) ; *(4)* les **statuts PMB → `circulation_policy`** : attendre l'échantillon de DIRA, ou règle par défaut « tout prêtable sauf mention ». Faits qui cadrent *(1)* : `tombo` unique sur toute la base ; chaque biblio a son schéma (`BTL-TL-EX-000909-R`, `MLEG-2026-0270`, `CCLA.2026.91`, `SOL-…`) ; les étiquettes AnarBib sont des QR portant l'identifiant interne de l'exemplaire (`LabelSheetPrinter.jsx`), et le prêt passe par la référence de la notice vers la détention (`create_loan_at_counter`) — un code-barres PMB n'est lu par AnarBib dans aucun cas. **Décidé le 26/09 (IMP-21) et livré le 27/09** (`3efd89b0`, `a7b2d44d`, `02000b89`, migration `20260927113000`) : numérotation B (tombo du schéma de la bibliothèque), code d'origine dans `exemplares.source_item_code` unique par bibliothèque (jamais dans une note), correspondance 995/852 dans le profil d'import (défaut PMB 8.1), statuts PMB gardés dans la note de provenance en attendant l'échantillon de DIRA. L'EF lit les zones d'exemplaire (sous-zones répétées comprises) ; la promotion crée un brouillon d'exemplaire par exemplaire, rattaché à sa notice et publié AVEC elle, à la place de l'exemplaire automatique ; le rapprochement aussi (dépôt compagnon réservé à l'administration, versé à la destination, code déjà présent non recréé, ligne entièrement détenue rejetée) ; le rapport de révision gagne `items` (six raisons, 40 au plus, en un passage). **Trois revues contradictoires** avant tout déploiement (26-27/09, chaque constat passé devant un sceptique) : garde d'appartenance dans `publish_exemplar_draft` (la tête ne demandait qu'un rôle QUELQUE PART), tombo gardé à la republication, cote brute gardée par le formulaire (`src/lib/shelfLocation.js`), exclusion mutuelle promotion/rapprochement, suivi de la notice (corbeille, restauration, lot, fusions de doublons, journal des suppressions), liens d'import non écrivables par l'API, retraitement refusé après rapprochement, profil supprimé refusé dès l'envoi. **Reste** : un import PMB réel (DIRA) mené jusqu'à la publication ; la correspondance statuts → `circulation_policy` (IMP-21 d). **29/09 (IMP-25, décidé le 28/09 par Xavier)** : une notice qu'un fichier MARC importe sans exemplaire n'en reçoit plus d'automatique à la publication (`2f488790`, migration `20260929103533`) ; un CSV ou un RIS garde le sien. Réimporté dans PMB (**H27**) : 46 exemplaires pour 46.

**Pourquoi ça compte.** Une bibliothèque, ce sont des livres sur des étagères. Sans cotes ni codes-barres, l'import donne un catalogue qu'on ne peut ni prêter ni ranger. Et un essai sans exemplaires ne prouve rien à DIRA.

**Ce qui compte comme fini.**

- Les exemplaires de la fixture PMB arrivent en brouillons, puis se publient.
- Aucune collision de tombo : le `tombo` suit le schéma de la bibliothèque, le code d'origine va dans `exemplares.source_item_code`, unique par bibliothèque (IMP-21 a, b).
- Tests SQL et edge function.

**Dépendances.** Fixture de **H14**. Avant **H21** et **H24**.

*Renvois : `claude/aller-retour-PMB_2026-09-26` · `Réponse à DIRA du 26/09/2026`*

#### H20 — L'identifiant d'origine d'une notice est gardé par bibliothèque, pas seulement sur la notice partagée

`P1` Prioritaire · État : **À vérifier** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL

**État.** **Mesuré le 26/09 en production** : le 001 (`external_key`) va bien de `ingest.fn_create_book_drafts_from_import_rows` jusqu'à `books.source_record_id` (254 notices en portent un). Mais `books` est **partagée par le réseau**. Quand l'import rattache une notice à une notice déjà cataloguée par une autre bibliothèque, l'identifiant PMB n'a pas de place qui soit à la bibliothèque qui importe (à vérifier sur un cas réel). `book_holdings.local_bib_ref` existe (2 426 valeurs), mais elle porte la référence locale d'AnarBib, pas celle de PMB. **Livré le 28/09** (`8c80de27`, migration `20260928111812`) : table `book_external_ids` (notice, bibliothèque, schéma, valeur ; unique par bibliothèque), posée à la publication, au rapprochement d'un exemplaire et à l'absorption d'un brouillon importé ; elle suit la notice gardée d'une fusion (`fn_fusion_notices`), et une clé ne passe plus d'une notice à l'autre. Ce qui n'est pas un identifiant (numéro de ligne de staging, numéro de fascicule d'un CSV de périodiques, clé répétée dans un même run) est jugé en un seul lieu (`ingest.fn_h20_identifiant_d_origine`) et effacé à l'import ; un run ne se supprime plus tant qu'un exemplaire rapproché l'attend. Revue contradictoire : 14 constats confirmés, corrigés ; contre-épreuve à 11 mutants. Suite SQL `identifiant_origine_tests` (11).

*Vérifié : 28/09 — migrations appliquées par la CI (`created_by` vide), `deployed-functions` = `8c80de27` ; `book_external_ids` : 264 lignes, toutes MLEG (notices publiées reprises) ; lot 63 : 0 brouillon sur 1 673 garde un faux identifiant (colonne et miroir `marc_json`) ; run 29 : 0. Les 10 brouillons publiés dont l'identifiant diffère du calcul portent des clés saisies à la main (`CCLA-…`, sans ligne de staging) : hors du périmètre de l'effacement, laissés.*

**Ce que c'est.** Une table `book_external_ids (book_id, library_id, scheme, value)` avec un index unique `(library_id, scheme, value)`, alimentée à la publication d'un brouillon importé. Ou bien une colonne sur la détention, si elle suffit. Trancher après avoir lu comment `publish_book_draft` traite un brouillon rattaché à une notice existante.

**Pourquoi ça compte.** C'est la clé de l'aller-retour. Sans elle, pas de réimport qui met à jour (**H21**), et l'export ne peut pas rendre à PMB ses propres numéros de notice (**H24**).

**Ce qui compte comme fini.**

- L'identifiant PMB est retrouvable par bibliothèque, y compris pour une notice rattachée à une notice existante.
- Test SQL.

**Dépendances.** Avant **H21** et **H24**.

*Renvois : `claude/aller-retour-PMB_2026-09-26` · `Réponse à DIRA du 26/09/2026`*

#### H21 — Réimporter un catalogue met à jour ce que l'import connaît déjà au lieu de le dupliquer

`P2` Courant · État : **En cours** · Charge : plusieurs semaines · Ce que ça demande : SQL / PostgreSQL, Deno / TypeScript, React / JavaScript

**État.** La marche en parallèle promise à DIRA suppose qu'elle continue de cataloguer dans PMB et qu'on réimporte. Aujourd'hui, un réimport repasse par la détection de doublons, puis par la révision : il n'existe aucune notion de « notice déjà importée, à mettre à jour ». `book_drafts.action` connaît pourtant `update` (valeur présente en base).

*Vérifié : 26/09 — `book_drafts.action` ∈ {create, update} en base. **29/09** — passé en cours par `69dbeec7` ; aucun des neuf lots n'est livré au soir du 29/09. Constat de production qui a demandé la règle (REGISTRE `IMP-26` a, 28/09) : 198 mises à jour publiées, dont 33 sur des notices aujourd'hui partagées et 3 par une bibliothèque qui ne détenait pas la notice. Le tableau de couverture le dit à DIRA : le 001 est gardé et rendu à l'export, mais un réimport ne s'en sert pas encore (`docs/interop/couverture-pmb.md`, `466324aa`). **01/10 — lot 0 livré** (`1385431b` base, `d4f97afc` écran ; migration `20261001200931` appliquée par la CI, `created_by` vide ; REGISTRE `IMP-27`) : une notice ou un exemplaire rapproché né d’un import ne se publie la première fois que dans un lot révisé, même sorti de son lot ; une notice ou un exemplaire déjà publiés (et au catalogue) se republient hors lot ; l’approbation couvre les brouillons figés à la demande, et la coordination redemande un tour pour les ajouts ; un lot de rapprochement passe par la révision ; une sélection rejoint le lot ouvert du run et « Promouvoir la sélection » ne promeut qu’elle ; « rattaché » ne devient jamais une notice ; vider la corbeille d’un brouillon importé écarte sa ligne, que seul le rejeu de ce brouillon reprend ; « Retraiter » refusé tout de suite pour un run qui a une ligne écartée ou un exemplaire rapproché à la corbeille ; l’écran dit les lignes ignorées. Six passes de revue contradictoire ; SQL 158/158, vitest 1 666 ; vérifié en production le 01/10 (définitions, cinq déclencheurs, droits, 0 tour sans liste) et l’écran servi. **Consigné** : la course entre « Retraiter » accepté et l’effacement par l’edge function, et « Retraiter » d’un run sans fichier (**H30**, **H31**) ; les fusions `api.merge_*` qui absorbent un brouillon importé (lot 5) ; la corbeille d’un exemplaire rapproché libère sa ligne, qu’un nouveau « Rapprocher » puis la sortie de corbeille dédoublent (lot 6) ; l’assistant d’import ne lit pas `skipped_rows` ; une ligne dont la notice proposée a été descartée reste « en attente » sans autre geste que « Rejeter » ; un onglet resté sur un run supprimé reçoit « Run N introuvable » en brut. **À trancher par Xavier** : un exemplaire rattaché sorti de la corbeille après la demande doit-il suivre la liste du tour, comme les notices (aujourd’hui non, règle de H19) ? Après une réattribution, la notice garde-t-elle pour la bibliothèque cible l’identifiant d’origine venu du PMB de la première ?*

**Ce que c'est.** Rapprocher d'abord par `(bibliothèque, identifiant d'origine)` (**H20**). Produire des brouillons `update` avec la différence montrée en révision de lot. Traiter les exemplaires ajoutés et retirés. Quand une notice a été modifiée dans AnarBib depuis l'import, la signaler en conflit : **jamais d'écrasement silencieux**. **Décidé le 29/09 par Xavier (REGISTRE `IMP-26`, précise `IMP-23`)** : reprendre une notice à la main est réservé à ses détentrices ; une divergence trouvée sur une notice partagée est traitée par n'importe quelle détentrice, et l'écarter fait avancer la base ; « retiré » est un constat réversible (non prêtable, masqué à l'OPAC, exclu de l'export, jamais supprimé), proposé seulement pour les exemplaires venus de la même source, d'un fichier MARC à exemplaires déclaré « export complet » ; H21 vise DIRA seule (MLEG ne réimportera pas) ; `accept_duplicate` veut dire « rattaché », jamais une création. **Plan en neuf lots**, chacun livrable et prouvé au banc : 0 préalables (porte de révision, promotion de la seule sélection, `accept_duplicate`, identifiant d'origine jugé à la ligne), 1 reconnaître une notice déjà importée, 2 garder la base de ce que le dernier import a apporté, 3 comparer à trois états, 4 brouillon de mise à jour pour une seule détentrice, 5 notice partagée signalée sans réécriture, 6 exemplaires ajoutés, modifiés, déplacés, 7 retirés, 8 bout en bout sur les fixtures PMB.

**Pourquoi ça compte.** Sans réimport incrémental, la marche en parallèle se réduit à ressaisir deux fois ou à dupliquer. Autrement dit, elle est impraticable. Et PMB ne peut rester un filet que s'il reste la base vivante.

**Ce qui compte comme fini.**

- Réimporter la fixture modifiée ne crée aucun doublon et montre les différences.
- Un conflit est signalé, pas écrasé.

**Dépendances.** Après **H20** et **H19**. Avant toute bascule (**G15**).

*Renvois : `claude/aller-retour-PMB_2026-09-26` · `Réponse à DIRA du 26/09/2026`*

#### H22 — Lire l'export XML propre à PMB, s'il le faut

`P3` Différé · État : **À vérifier** · Charge : une soirée · Ce que ça demande : Deno / TypeScript

**État.** `looksLikeMarcXml()` n'accepte que du vrai MARCXML (`<record>`, `<datafield>`). À notre connaissance, PMB a aussi un XML qui lui est propre (`<notice><f c="200">…`), que l'import ne reconnaîtrait pas. **Vérifié le 26/09 sur le banc** : l'export « UNIMARC PMB XML » est bien `<unimarc><notice><f c="200"><s c="a">…` et notre import rend `null` (figé par `pmb-fixtures-parseur`, fixture `pmb-8.1.1.1_jeu-de-test.pmbxml.xml`). PMB sait aussi sortir du « XML MARC » (sans espace de noms), que l'import lit déjà à l'identique de l'ISO 2709 : ce lecteur n'est utile que si une bibliothèque ne peut produire ni l'un ni l'autre. **Livré le 28/09** (`8c80de27`) : sur décision de Xavier (« Écrire le lecteur »), l'import lit le XML propre à PMB (`<unimarc><notice><f c="…">`) vers le même modèle que l'ISO 2709 ; format `pmb_xml` admis par la CHECK (migration `20260928111814`) ; la fixture `pmb-8.1.1.1_jeu-de-test.pmbxml.xml` donne les mêmes notices que l'ISO 2709.

*Vérifié : 28/09 — migrations appliquées par la CI (`created_by` vide), `deployed-functions` = `8c80de27`.*

**Ce que c'est.** Seulement si une bibliothèque ne peut pas sortir de l'ISO 2709 ni du MARCXML. Il suffirait alors d'un lecteur vers le modèle commun de `marc.ts` (leader + zones), sans rien changer en aval.

**Pourquoi ça compte.** Inutile tant que l'ISO 2709 suffit. Gardé ici pour que personne ne croie que « XML » veut dire « compatible ».

**Ce qui compte comme fini.**

- Constat fait sur le banc ; lecteur écrit ou item clos sans objet.

**Dépendances.** **H14**.

*Renvois : `claude/aller-retour-PMB_2026-09-26` · `Réponse à DIRA du 26/09/2026`*

#### H23 — Un export UNIMARC (ISO 2709 et XML), miroir exact de l'import

`P1` Prioritaire · État : **À vérifier** · Charge : quelques jours · Ce que ça demande : Deno / TypeScript, bibliothéconomie

**État.** `export-catalog-lote/serialize.ts` ne sait écrire que du CSV, du **MARCXML en MARC21** et du JSON (`SUPPORTED_FORMATS`). Son en-tête annonce « UNIMARC ISO 2709 / Dublin Core / BibTeX viendront ensuite » : aucun n'existe. PMB travaille nativement en UNIMARC. La correspondance des zones est écrite **deux fois**, dans `marc.ts` pour l'import et dans `serialize.ts` pour l'export, et rien ne garantit que les deux restent symétriques. **Livré le 28/09** (`8c80de27`) : une table unique `_shared/marc/correspondance.ts`, lue par l'import et par l'écrivain `_shared/marc/ecriture.ts` ; UNIMARC en ISO 2709 (longueurs en octets UTF-8, zone trop longue découpée ou raccourcie, notice trop longue écartée et dite) et en XML ; MARC21 en ISO 2709 (008, 040) et MARCXML ; langues en ISO 639-2, pays de la 801, types de subdivision et dates d'une personne repris de l'origine quand rien ne les contredit. Les 64 notices PMB des fixtures font PMB → AnarBib → UNIMARC → réimport à l'identique (`pmb-aller-retour-export`, `ecriture.test.ts` 13 tests pontés). Revue contradictoire H23/H24 : 35 constats confirmés, corrigés.

*Vérifié : 28/09 — migrations appliquées par la CI (`created_by` vide), `deployed-functions` = `8c80de27` ; formats proposés par l'écran Importations : UNIMARC ISO 2709, UNIMARC XML, MARC21 ISO 2709, MARCXML, CSV, JSON. **28/09** — écrivain corrigé par la preuve de **H27** (`2ee5f7a7`, revue `a692a75e`), déployé (`deployed-functions` sur `a692a75e`) : l'ISSN d'un article sort en 461 $x et non plus en 011 ; les mots-clés importés, rangés à part (**H17**), ressortent en 610/653 et non plus en 606, que PMB change en catégories. **29/09** — revues de la fin de H27 (`466324aa`, `2348cb86`), déployées (`deployed-functions` sur `2348cb86`) : l'export range les périodiques avant les articles, car PMB ne rattache un article qu'à une revue lue avant lui (15 articles rattachés sur 15 au banc, 7 dans l'ordre des identifiants) ; la 995 porte `$r uu` et `$q u` (« indéterminé »), sans quoi PMB rangeait tout exemplaire sous le premier type de sa base (suite : **H29**) ; l'aide de l'écran nomme, dans les 10 langues, l'onglet d'import de PMB (« Exemplaires UNIMARC ») et les deux réglages dont tout dépend. `ecriture.test.ts` : 19 tests pontés (13 à `8c80de27`).*

**Ce que c'est.** Une seule table de correspondance partagée par l'import et l'export (`_shared/marc/`). Un écrivain ISO 2709 : les longueurs du répertoire se comptent en **octets UTF-8**, pas en caractères. Un leader correct et le jeu de caractères déclaré en 100 $a/26-29 (Unicode). Un MARCXML UNIMARC. Des tests `parse(serialize(x)) = x` sur la fixture.

**Pourquoi ça compte.** « Vos données restent à vous » ne vaut que si elles ressortent dans le format du logiciel d'où elles viennent. Un MARC21 que PMB devrait d'abord convertir, c'est une promesse de réversibilité qui s'arrête à mi-chemin.

**Ce qui compte comme fini.**

- Export UNIMARC ISO 2709 et XML disponibles dans Importations.
- Table de zones unique ; tests aller-retour unitaires verts.

**Dépendances.** Contenu complet : **H24**. Preuve : **H27**.

*Renvois : `claude/aller-retour-PMB_2026-09-26` · `Réponse à DIRA du 26/09/2026`*

#### H24 — L'export d'une bibliothèque contient tout ce qu'elle a catalogué : exemplaires, responsabilités, sujets, collection, identifiants

`P1` Prioritaire · État : **À vérifier** · Charge : quelques jours · Ce que ça demande : SQL / PostgreSQL, Deno / TypeScript

**État.** **Mesuré le 26/09 en production** : d'après la définition réelle de `fn_export_catalog_lote`, l'export livre les notices détenues par la bibliothèque, et rien de plus. **Aucun exemplaire** (ni tombo, ni cote, ni statut). Les auteurs sortent de `book_authors` (table dérivée), par leur seul `preferred_name`, sans rôle. Les sujets sont du texte découpé sur `;`/`,`, et non l'autorité du thésaurus. L'écrivain MARCXML met toujours `100 1_`, même pour une collectivité. Rien ne sort sur l'œuvre ni sur le périodique. **Côté PMB (banc, 26/09)** : même un export parfait perd en entrant dans PMB par sa fonction d'import par défaut (`func_bdp`) — 200 `$f`/`$g`, seconde 700, 606 fondues en une 610, Dewey tronquée à 5 caractères, propriétaire de la 995 ignoré (`tests/pmb/README.md`). À traiter dans **H27**. **Livré le 28/09** (`8c80de27`, migration `20260928111816`) : `fn_export_catalog_lote(p_library_id, p_apres, p_limite)` réécrite depuis sa définition réelle : identifiant d'origine de la bibliothèque (001), référence locale, responsabilités (`book_contributors`, rôle, nature, code), sujets du thésaurus dans la langue de la bibliothèque, mots-clés, exemplaires de cette seule bibliothèque, œuvre, périodique (numéro, date), article (revue hôte). **Réémission prudente** décidée par Xavier (REGISTRE IMP-22) : seules les zones qu'AnarBib ne tient pas, et seulement pour la bibliothèque d'où vient la notice (destination d'un dépôt compagnon comprise) ; jamais 001/005/100/995/996 d'origine. Suite SQL `export_catalogue_tests` (10). **Reste** : rattacher les fascicules importés à leur périodique (la 461 vers la notice de titre) ; les imports antérieurs au 28/09 n'ont pas gardé leur zone d'exemplaire (`item_tag`), l'export retombe alors sur celle du dialecte ; contre-épreuve par mutants de la RPC encore partielle.

*Vérifié : 28/09 — migrations appliquées par la CI (`created_by` vide), `deployed-functions` = `8c80de27` ; signature en production : `fn_export_catalog_lote(p_library_id uuid, p_apres bigint, p_limite integer)`. **28/09** — `fn_export_catalog_lote` recréée depuis sa définition réelle par la revue de H25 et H27 (`a692a75e`, migration `20260928170908`, appliquée par la CI) : une 71X `$3` ne mène plus à une fiche de personne, chaque fiche ayant un seul type, le même dans les deux exports (`private.fn_nature_autorite`, voir **H25**). **29/09** — critère 1 éprouvé au banc par la preuve de **H27** (`tests/pmb/bilans/h27-aller-retour.json`) : l'export tiré de la base, réimporté dans un PMB vide, rend 46 exemplaires sur 46, 61 responsabilités sur 61 et 42 notices indexées sur 42 ; deux catégories PMB de même libellé n'en font qu'une (48 liens pour 49) ; le type, la section et le code statistique des exemplaires ne reviennent pas (**H29**).*

**Ce que c'est.** Réécrire `fn_export_catalog_lote` **depuis sa définition réelle**. Y mettre : les exemplaires de la bibliothèque, et d'elle seule ; `book_contributors` avec rôle, nature et autorité ; les sujets du thésaurus avec leurs subdivisions ; collection, notes, périodique (461), œuvre (titre uniforme) ; en 001 l'identifiant d'origine (**H20**), sinon le `bib_ref`, et les autres identifiants en 035. **À trancher** : réémettre les zones non reprises depuis `books.marc_json` pour les notices venues de PMB. On y gagne en fidélité, mais on risque de réémettre une valeur périmée si la notice a été retouchée depuis.

**Pourquoi ça compte.** Une bibliothèque qui part sans ses cotes ni ses exemplaires doit refaire son récolement. En pratique, elle ne peut pas partir. C'est la moitié de la promesse de pérennité.

**Ce qui compte comme fini.**

- Export de la fixture réimportée : mêmes exemplaires, mêmes rôles, mêmes sujets.
- Test SQL sur la RPC.

**Dépendances.** Après **H23**, **H20**, **H19**, **H18**.

*Renvois : `claude/aller-retour-PMB_2026-09-26` · `Réponse à DIRA du 26/09/2026`*

#### H25 — Exporter les autorités (UNIMARC Autorités), pour que les liens $3 de l'export mènent quelque part

`P2` Courant · État : **À vérifier** · Charge : quelques jours · Ce que ça demande : Deno / TypeScript, bibliothéconomie

**État.** Aucun export d'autorités n'existe (personnes, collectivités, sujets). PMB importe ses autorités à part. Sans elles, un export qui porte des références d'autorité en $3 (**H24**) pointe dans le vide, et PMB recrée une autorité par notice. **Livré le 28/09** (`d83a7d0c`, revue `a692a75e`, migration `20260928170908`) : `fn_export_authorities_lote` (noms liés aux notices que la bibliothèque détient, formes rejetées, VIAF/ISNI/Wikidata/IdRef/LCCN ; vedettes du thésaurus et tous leurs ancêtres ; même garde que l'export des notices) et l'écrivain `_shared/marc/autorites.ts` (UNIMARC Autorités : 200/210/250, 4XX, 550, 033, 801 $b AnarBib sans $c) ; format « UNIMARC Autorités » dans Importations, avec la marche à suivre dans PMB, en 10 langues. Une fiche a UN type, le même dans les deux exports (`private.fn_nature_autorite`). La 001 d'une fiche est le $3 de ses notices, préfixé (`AnarBib-A…`, `AnarBib-S…`) : PMB cherche un numéro sans filtrer l'origine. **Essai au banc PMB 8.1** (64 notices des deux fixtures, base restaurée) : 88 autorités, 0 erronée ; **61 responsabilités sur 61** rattachées par le $3, 0 auteur recréé ; **47 catégories sur 47** — mais par leur LIBELLÉ, dans le thésaurus par défaut de PMB (`func_cpt_rameau_first_level` ignore le $3 d'une 606). Deux revues contradictoires (19 puis 6 constats confirmés, corrigés). Recette : `tests/pmb/README.md`. **Reste** : un essai avec le PMB de DIRA (plusieurs thésaurus ?). **Correction du 29/09** : ces 61 rattachements supposent que PMB reçoive l'origine « AnarBib ». Le formulaire de l'onglet « Exemplaires UNIMARC » de PMB 8.1.1.1 ne la transmet pas (sa liste s'appelle `authorities_origin`, l'import lit `authorities_default_origin`) : l'outil du banc envoyait le champ attendu, pas un navigateur. Mesuré comme un navigateur l'envoie (`PMB_COMME_LE_NAVIGATEUR=1`) : 61 responsabilités → 57 auteurs, aucun recréé (PMB rapproche par nom et dates), mais **44 liens notice → fiche, tous vers une source absente** ; avec « Non » : même rapprochement, aucun lien. La marche à suivre (tableau § 3, README, aide de l'écran en 10 langues) dit donc « Non » dans PMB 8.1.1.1, et nomme la ligne à corriger dans PMB pour que le $3 serve.

*Vérifié : 28/09 — déployé : `deployed-functions` sur `a692a75e`, migrations `20260928170908` et `20260928170909` appliquées par la CI (`created_by` vide) ; en production, les 7 définitions recréées ont le md5 du banc, `v_author_alias_worklist` est en security_invoker, ni anon ni authenticated n'exécutent les nouvelles fonctions ; `fn_idioma_bcp47('fre')` = fr, un nom grec n'est plus un non-agent ; la règle de type coûte 180 ms pour les 2 255 responsabilités rattachées de BTL. Avant la poussée : vitest 1 447 tests, SQL 145/145.*

**Ce que c'est.** Sérialiser les autorités de la bibliothèque (celles qui sont liées à ses notices) en UNIMARC Autorités : 200/210/250, formes rejetées en 4xx, liens en 5xx. Le SKOS du thésaurus existe déjà (`thesaurus.ttl`) et peut servir de source pour les sujets.

**Pourquoi ça compte.** Sans les autorités, le catalogue retourne dans PMB à plat, et tout le travail de dédoublonnage des noms est perdu.

**Ce qui compte comme fini.**

- Les autorités de la fixture se réimportent dans le PMB de banc, liées à leurs notices.

**Dépendances.** Après **H24**.

*Renvois : `claude/aller-retour-PMB_2026-09-26` · `Réponse à DIRA du 26/09/2026`*

#### H26 — L'export d'un gros catalogue ne dépend plus de la mémoire d'une edge function

`P2` Courant · État : **À vérifier** · Charge : quelques jours · Ce que ça demande : Deno / TypeScript

**État.** `export-catalog-lote` construit tout le fichier en mémoire, en une seule réponse. `export-fonds-bundle` est déjà plafonné (150 fichiers, 80 Mo) pour la même raison. **Mesuré le 26/09 en production** : le plus gros catalogue du réseau compte 2 184 détentions. Personne n'a mesuré la limite réelle. La taille du catalogue de DIRA est inconnue. **Livré le 28/09** (`8c80de27`) : la RPC d'export se lit par pages (`p_apres`, `p_limite`) et l'écran Importations assemble le fichier lui-même : plus aucune edge function ne tient le catalogue en mémoire. **Mesuré** (REGISTRE IMP-24) : 306 ms en production pour les 2 167 notices de BTL ; écriture ISO 2709 de 2 200 notices en 333 ms (1 167 ms avant), XML en 162 ms (427 ms avant). **Reste** : la mesure à 10 000 et 50 000 notices (`export-mesure-h26.test.js`, sauté par défaut) sur un catalogue synthétique, et la taille réelle de DIRA (**G15**).

*Vérifié : 28/09 — migrations appliquées par la CI (`created_by` vide), `deployed-functions` = `8c80de27` ; mesures au REGISTRE IMP-24.*

**Ce que c'est.** Mesurer la limite avec un catalogue synthétique (10 000 et 50 000 notices). Si elle est trop basse, passer à une génération asynchrone : un travail en file, le fichier déposé dans le Storage, un lien envoyé quand il est prêt.

**Pourquoi ça compte.** Un export qui échoue le jour où une bibliothèque veut partir vaut moins que pas d'export du tout : il fait croire à une porte qui n'ouvre pas.

**Ce qui compte comme fini.**

- Limite mesurée et écrite ; au-delà, export asynchrone éprouvé.

**Dépendances.** Après **H24**. La taille de DIRA vient de **G15**.

*Renvois : `claude/aller-retour-PMB_2026-09-26` · `Réponse à DIRA du 26/09/2026`*

#### H29 — Au retour dans PMB, un exemplaire garde son type, sa section et son code statistique

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : Deno / TypeScript, SQL / PostgreSQL, bibliothéconomie

**État.** **Mesuré au banc PMB 8.1.1.1 le 29/09** (H27, tableau de couverture § 4, bilans dans `tests/pmb/bilans/`) : les 46 exemplaires des fixtures reviennent tous en type « indéterminé / indéterminé », section « indéterminé », code statistique « Indéterminé ». À l'origine : 8 types (23 Livre, 13 indéterminé / indéterminé, 3 Oeuvre d'art, 2 CD audio, 2 Périodique, 1 Cartes et plans, 1 Cédéroms, 1 DVD), 12 sections, 3 codes statistiques (23 Adultes, 14 Indéterminé, 9 Jeunes). PMB retrouve un type et une section par leur code d'import, ou les crée — le type avec une durée de prêt de 0 jour. Cause : l'export écrit `995 $r uu` et `$q u` ; à l'import, `$r` et `$q` ne vont qu'en note de provenance, et les libellés d'origine sont dans la 996 de PMB, que rien ne reprend et qui n'est jamais réémise (IMP-22). Dans les fixtures, `$r` et `$q` valent déjà « uu » et « u » quel que soit le type : ce PMB de test n'a pas réglé ses codes d'import. Une bibliothèque qui repasse à PMB doit aujourd'hui reclasser chaque exemplaire avant de prêter.

*Vérifié : 29/09 — ouvert sur décision de Xavier, à la clôture de H27.*

**Ce que c'est.** Pistes, à trancher après la réponse de DIRA : garder à l'import, dans des colonnes de l'exemplaire (jamais dans une note), le type, la section, le code statistique et la localisation d'origine — codes de la 995 et, quand la 996 est là, ses libellés — puis les réécrire à l'export pour la bibliothèque d'origine ; pour un exemplaire né dans AnarBib, une correspondance réglée dans le profil de la bibliothèque entre ce qu'AnarBib sait de l'exemplaire et les codes de son PMB. À vérifier au banc : ce que `docs_type::import` et ses équivalents de section et de code statistique font d'un code inconnu et d'un libellé.

**Pourquoi ça compte.** Le retour vers PMB est la garantie donnée à une bibliothèque qu'AnarBib ne l'enferme pas. Un catalogue qui revient sans le type ni la section de ses exemplaires ne se prête pas le lendemain.

**Ce qui compte comme fini.**

- Réimporté dans PMB, un exemplaire venu de PMB retrouve son type, sa section et son code statistique d'origine.
- Un exemplaire né dans AnarBib sort avec le type et la section que la bibliothèque a fait correspondre.
- Mesuré au banc PMB, bilan versé.

**Dépendances.** Après **H27** (clos le 29/09). À demander à DIRA d'abord : ce que ces trois informations leur servent, et si les codes d'import de leurs types et sections sont réglés dans leur PMB.

*Renvois : `claude/aller-retour-PMB_2026-09-26` · `Tableau de couverture AnarBib ↔ PMB, § 4 (docs/interop/couverture-pmb.md)`*

#### H30 — « Retraiter » un import sans fichier (moisson OAI, candidat, dépôt direct) n’efface plus ses lignes

`P1` Prioritaire · État : **Ouvert** · Charge : une soirée · Ce que ça demande : SQL / PostgreSQL, Deno / TypeScript

**État.** **Prouvé au banc le 01/10** (revue de H21 lot 0, sonde `P5/SK2/sk2p5-sonde-retraiter.sql` de la session 23c4e409) : pour un run dont le chemin de stockage est une convention sans fichier (`oai/…`, `lookup/…`, `direct/…`), l’écran offre « Retraiter » et `fn_import_dispatch` l’accepte ; l’edge function `process-partner-catalog-import` efface toutes les lignes, puis échoue au téléchargement : run « échoué », 0 ligne ; les fichiers reçus d’un dépôt direct perdent leur ligne ; une moisson OAI incrémentale ne ramène pas les notices effacées. Antérieur au lot 0 (H15, EX-4).

*Vérifié : 01/10 — ouvert à la livraison du lot 0 de H21 (constat de revue, prouvé au banc).*

**Ce que c'est.** Refuser le retraitement dans `fn_import_dispatch` quand `detected_format` vaut `oai_pmh` ou `lookup`, ou que le chemin commence par `direct/` (HINT traduite `error.import.reparse_no_file`, 10 locales), masquer le bouton dans `RunEncodingPanel` pour ces runs ; et, dans l’edge function, lire le fichier AVANT d’effacer les lignes. Correctif candidat prouvé : `sk2p5-mutant-dispatch-chemins-de-convention.sql` (suites voisines vertes).

**Pourquoi ça compte.** C’est une perte de données silencieuse au bout d’un clic offert à l’écran.

**Ce qui compte comme fini.**

- « Retraiter » n’est ni offert ni accepté pour un run sans fichier ; refus traduit.
- Un échec de lecture du fichier n’efface plus aucune ligne.
- Suite SQL et banc de l’edge function.

**Dépendances.** Après le lot 0 de **H21** (livré le 01/10).

*Renvois : `claude/h21-reimport`*

#### H31 — « Retraiter » juge le run au moment d’effacer, pas seulement à l’envoi

`P2` Courant · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : SQL / PostgreSQL, Deno / TypeScript

**État.** **Prouvé au banc le 01/10** (revue de H21 lot 0, sondes `P5/SCEP1`, `P5/SK1r`, `P5/SK2r` de la session 23c4e409). La garde de « Retraiter » (`fn_import_dispatch`) se juge à l’envoi ; l’edge function efface les lignes quelques secondes plus tard, sans rien relire. Dans cette fenêtre, depuis un second onglet ou par l’API : une promotion donne, après relecture, deux notices pour la même ligne d’un run (antérieur, H15) ; un rapprochement fait refuser l’effacement (déclencheur du lot 0) et le run finit « échoué », sa file cachée. À côté, du même geste : un paquet de fonds retraité efface la trace d’attache de ses fichiers reçus, et un même fichier s’attache deux fois ; `receive-fonds-bundle` passe le run en « processing » avant d’effacer ; un effacement des fichiers reçus en échec double les fichiers au retraitement suivant.

*Vérifié : 01/10 — ouvert à la livraison du lot 0 de H21 (constat de revue, prouvé au banc, non mesuré en production : la largeur de la fenêtre n’est pas connue).*

**Ce que c'est.** Faire passer l’effacement des deux edge functions par une RPC `ingest` qui verrouille le run (FOR UPDATE), rejoue la garde de `fn_import_dispatch`, puis efface ; promotion, rapprochement et décision prennent le même verrou. Un effacement refusé laisse le run dans son état et écrit le refus à son journal (règle du 27/09, comme le profil supprimé), au lieu de « échoué ». Garder les fichiers reçus déjà attachés. Variante écartée pour l’instant : un statut « queued » (réécrit par `fn_refresh_partner_catalog_run_counters`, et perdu si l’envoi pg_net se perd).

**Pourquoi ça compte.** Le lot 0 promet « jamais deux notices pour une ligne » ; cette fenêtre est le dernier chemin connu qui la dément.

**Ce qui compte comme fini.**

- Une promotion ou un rapprochement dans la fenêtre est refusé ou fait refuser le retraitement, sans run en échec ni ligne perdue.
- Un retraitement refusé laisse le run et sa file visibles.
- Tests de suite de la fenêtre (relais remplacé par un témoin) et bancs des deux edge functions.

**Dépendances.** Après le lot 0 de **H21** (livré le 01/10) ; avec **H30**.

*Renvois : `claude/h21-reimport`*

---

### I — Auto-hébergement, exploitation, sauvegardes, CI

*Gelé jusqu'au 14/09/2026 sur la production. Le travail en environnement d'essai reste ouvert.*

| | | | |
|---|---|---|---|
| **I2** | Achever la bascule vers l'auto-hébergement | `P1` | Ouvert |
| **I18** | Le banc CI ne rejoue pas sur une image Supabase — il faut un rejeu qui le fasse | `P2` | En cours |
| **I21** | Ce qui doit être vrai avant la bascule chez Les Herbes Folles, et ne l'est pas encore — huit conditions, aucune technique difficile | `P1` | Ouvert |

#### I2 — Achever la bascule vers l'auto-hébergement

`P1` Prioritaire · État : **Ouvert** · Charge : plusieurs semaines · Ce que ça demande : administration système

**État.** La pile est réduite de douze à **six conteneurs** (`db`, `rest`, `auth`, `storage`, `functions`, `caddy`), les versions sont épinglées, `bootstrap.sh` a été exécuté pour de vrai le 26/08 avec huit défauts relevés et corrigés, et la répétition du 18/08 a rejoué 124 migrations et restauré un dump de production en 17 secondes. Reconstruction complète mesurée : **25 minutes**.

*Vérifié : [object Object],[object Object],[object Object]*

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

#### I18 — Le banc CI ne rejoue pas sur une image Supabase — il faut un rejeu qui le fasse

`P2` Courant · État : **En cours** · Charge : quelques jours · Ce que ça demande : administration système

**État.** `scripts/ci/run-sql-suites.sh` crée `anarbib_test` depuis `template0` : `pg_default_acl` y est vide, les fonctions naissent fermées, la vérification des migrations du 29/08 passe — et une image réelle la fait lever. Le vert de `sql-tests` n'atteste donc pas qu'une image Supabase rejoue le dépôt (`DOC-GRANT-2`, même limite structurelle que `DOC-MIGR-1` par l'autre bout). Le choix de `template0` est motivé (pas d'event triggers hérités) et reste bon pour les suites. **07/09** : la spec d'`I17` (§8) rend cet item bon marché — le service `sql-tests` lance déjà l'image ; il suffit d'un second job qui rejoue les migrations dans la base `postgres` du service (défauts et extensions de l'init posés) au lieu d'une base `template0`. **07/09, confirmé par l'expérience d'`I17`** : avec A.1 avant le socle et `CREATE EXTENSION pg_cron`, la base `postgres` de l'image rejoue les 310 migrations sous `postgres` ; le job serait vert aujourd'hui. **16/09 : livré.** Job `rejeu-image` dans `sql-tests.yml` (`scripts/ci/run-image-replay.sh`) : même service Postgres, rejeu dans la base `postgres` de l'image par les deux scripts de la pile (`deploy/init-db/01-roles.sh` : mots de passe, A.1, `pg_cron` ; `deploy/scripts/run-migrations.sh` sous `postgres`), qui parlent à l'image par `PGHOST` au lieu du socket — un `install.sh` sans conteneurs applicatifs. Entre les deux, ce que la pile obtient de ses services avant de migrer (bootstrap.sh 3/8 et 4/8) : le sel au Vault réel par `vault.create_secret`, les stubs `auth` et `storage` de sql-tests, et un stub de pont `tests/sql/_ci_setup_image_services_stub.sql`. **Quatre manques de l'image nue, mesurés en chemin, sans lesquels un rejeu à froid s'arrête** : `auth.jwt()` absent (socle, l. 41402) ; `auth.users` d'origine sans `email_confirmed_at`, `is_sso_user`, `is_anonymous` (`20260623204043`) ; `auth.uid()` d'origine qui ne lit que `request.jwt.claim.sub`, pas `request.jwt.claims` (`20260702081711`, « Nenhum usuário autenticado ») ; `storage.buckets` créée fermée à `postgres`, l'image n'ayant aucun privilège par défaut sur `storage` (`20260820012512`). Le stub dit chacun. Éprouvé quatre fois sur conteneur jetable `public.ecr.aws/supabase/postgres:17.6.1.084` : **320/320 en 54 s sous `postgres`, 133 fonctions exécutables par `anon` (public, api, ingest, private), empreinte MD5 identique à la production du 15/09, 38 crons, 0 table sans RLS**, 64 s bout en bout. `alerte` et `acquittement` comptent les deux jobs. Reste : le premier run de la forge, puis le critère 2 (un rouge pour une vraie raison, corrigé).

*Vérifié : [object Object],[object Object],[object Object]*

**Ce que c'est.** Lire le run dans Actions. Quand il rougit, corriger la cause — une migration, ou le pont si l'image ou GoTrue ont bougé — jamais le job. Le jour où un rouge motivé est corrigé, clore (critère 2).

**Pourquoi ça compte.** Toute assertion « N migrations rejouent de zéro » se mesure sur une image Supabase, jamais sur le banc CI. Sans ce job, c'est la prochaine personne extérieure qui fera la mesure, à ses frais.

**Ce qui compte comme fini.**

- Un job de la forge rejoue les migrations sur `supabase/postgres` et son résultat est lisible dans Actions.
- Il a été rouge une fois pour une vraie raison, et la raison a été corrigée.

**Dépendances.** Après **I17** (sinon le job sera rouge pour la raison déjà connue).

*Renvois : `scripts/ci/run-sql-suites.sh` · `REGISTRE §0 DOC-GRANT-2` · `REGISTRE §0 DOC-MIGR-1` · `scripts/ci/run-image-replay.sh` · `tests/sql/_ci_setup_image_services_stub.sql` · `.forgejo/workflows/sql-tests.yml` · `deploy/init-db/01-roles.sh` · `deploy/scripts/run-migrations.sh`*

#### I21 — Ce qui doit être vrai avant la bascule chez Les Herbes Folles, et ne l'est pas encore — huit conditions, aucune technique difficile

`P1` Prioritaire · État : **Ouvert** · Charge : quelques jours · Ce que ça demande : administration système, délibération collective

**État.** La décision du 07/09 (offre confirmée : VM IPv4, Debian, sauvegardes déjà chez eux) et la note du 05-06/09 laissent une liste que rien ne tient ensemble. **Vérifié le 07/09 dans `deploy/`** : aucune trace d'`unattended-upgrades`, de pare-feu ni d'authentification par clé seule. Le reste est humain ou local : la connexion authentifiée sur la pile locale jamais retestée depuis le retrait de Turnstile ; `deploy/.env` écrasé par `install.sh` (domaines sur `localhost`) sans copie connue ; l'essai depuis un réseau mobile brésilien (NAT64) jamais fait ; le délai d'intervention des Herbes Folles jamais demandé ; le moyen de leur verser de l'argent « demandé depuis juillet, sans réponse » ; un second détenteur des accès ; et la règle posée le 07/09 : **on ne bascule pas avant que la sauvegarde soit partie chez un tiers** — aujourd'hui les trois flux restic sont chez l'hébergeur de destination lui-même.

*Vérifié : [object Object],[object Object],[object Object],[object Object]*

**Ce que c'est.** Tenir la liste ici, cocher chaque condition avec sa preuve (fichier, courriel, essai daté). Le durcissement entre dans `deploy/` ; le dépôt de sauvegarde tiers se demande à Bologne (**I12** dit ce que le miroir froid couvre, et ce n'est pas ça).

**Pourquoi ça compte.** Chacune de ces conditions est petite. Ensemble, c'est la différence entre une bascule et un déménagement de la fragilité.

**Ce qui compte comme fini.**

- Les huit conditions cochées avec preuve, dans cet item.
- `deploy/` porte le durcissement, rejoué par `bootstrap.sh`.

**Dépendances.** Bloque **I2**. Le dépôt tiers et le second détenteur relèvent de la même conversation que **A1** (Bologne).

*Renvois : `claude/DECISION_herbesfolles_offre_confirmee_2026-09-07` · `claude/NOTE_sortie_services_etats_uniens_2026-09-05` · `claude/REPRISE_claude_code_PR28_revoke_anon_2026-09-06 (deploy/.env)`*

---

### J — Documentation et corpus

*Le corpus est vaste et sa dérive est mesurée. Ce backlog en fait partie.*

| | | | |
|---|---|---|---|
| **J9** | Manuel v5 : le reliquat des captures — 180 emplacements en repli pt-BR, IMG-31 à refaire, IMG-08 à confirmer, tout à recapturer en 900-1000 px | `P2` | À vérifier |
| **J10** | Sept domaines sont entrés dans le v17 sans avoir été arbitrés contre leur coût d'achèvement | `P3` | Ouvert |

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
| **K7** | Mener la formation des deux coordinations BLMF jusqu'à l'autonomie | `P1` | En cours |
| **K8** | Finir le texte d'orientation sur les outils de bibliothèques militantes | `P2` | Ouvert |
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
| B18 | 2026-09-02 | **Les clés API legacy sont désactivées — et le feu vert fut un chiffre, comme la fiche l'exigeait.** La jauge refaite le matin même (sur le marqueur JWT, après que le critère « préfixe vide » se soit révélé compter les requêtes SANS clé comme legacy) donnait : zéro `service_role` depuis la bascule du 01/09, et côté `anon` **un seul user-agent navigateur** — un onglet Chrome/Windows connecté, jamais rechargé depuis la bascule — plus Googlebot rejouant son cache d'ancien bundle. L'onglet rechargé, le toggle basculé au dashboard (geste réversible), et la contre-preuve lue dans les logs : **zéro JWT legacy et zéro 401 sur 857 requêtes vivantes** — l'application entière sur la clé publiable et `sb_secret`. Le code a suivi dans l'heure : le repli `SUPABASE_SERVICE_ROLE_KEY` retiré de `secret-key.ts` (une clé morte ne mérite pas de chemin de code, et un repli vers elle masquerait une panne de `SUPABASE_SECRET_KEYS` au lieu de la dire — DOC-SILENCE-1), `.env.example` nettoyé, et le vestige vault `anarbib_staging_anon_key` supprimé (migration `20260902163600`, zéro appelant vérifié). La bascule `service_role` → `sb_secret` entamée le 01/09 est close de bout en bout. **Nuance du 08/09 : la clôture était juste pour l'application, et l'application n'était pas tout.** Le site vitrine `anarbib.org` — second dépôt, `codeberg.org/anarbib/pages` — portait la clé anon legacy dans les dix `index.html` de sa galerie *Explorer*, qui lit `api.public_libraries` : dès le toggle, chaque visiteur de la galerie a reçu un 401 et une page vide, **six jours durant**. La jauge quotidienne l'a vu (4 à 7 requêtes legacy par jour du 04 au 07/09) et l'a lu comme un résidu d'onglets, parce que le chiffre était petit et que personne n'avait demandé le `referer`. Trouvé et réparé dans la nuit du 07 au 08/09 par la session du fond de carte (vitrine `df9ba40`). Ce qui en sort est l'item **B24** et la carte `OPS-9` du registre : une rotation de clé commence par l'inventaire des dépôts qui la portent, et après une désactivation le seuil d'alerte est un, pas cinquante. |
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
| I17 | 2026-09-07 | **Clos le 07/09 sur le constat de l'expérience du §7** (`journal/operations/NOTE_experience-I17-rejeu-fidele_2026-09-07`), pas sur le code. Sur `main` à `c28baac0`, sans la PR #28, image `supabase/postgres:17.6.1.136`, volume vierge : avec A.1 (`anon` retiré du défaut *fonctions* des **deux** rôles dans `01-roles.sh`, entrées vérifiées non vides) et A.2 (migrations sous `postgres`), **310/310 migrations vertes**, dont celles du 29/08, 30/08, 02/09 et 04/09 sans aucun `REVOKE` ni tolérance ajoutés ; 676 fonctions possédées par `postgres` ; **133 fonctions exécutables par `anon`, empreinte MD5 identique à la production** interrogée en lecture seule à la même minute ; `pg_default_acl` sans `anon=` pour les deux rôles, l'entrée `postgres` rétablie par le socle puis refermée par `20260831105114` ; T8-T11 verts. L'option B n'a pas eu à être considérée. Appris en chemin : l'entrypoint traite `initdb.d/*` dans l'ordre du glob, `99-roles.sh` passe **avant** `migrate.sh` (le commentaire de `compose.yml` est faux, `bootstrap.sh` rejoue le script à l'étape 2) ; `cron.job` absent à la 288e, `CREATE EXTENSION pg_cron` sous `postgres` réussit (→ `I19`). Reste **T7** rouge : cinq vues du socle lisibles par `anon` au rejeu, `anon=m` en prod, `REVOKE SELECT` écrit nulle part — versé à `B22`. Le code A.1/A.2 reste à proposer au camarade après la fusion de la #28 (D7). **15/09 : A.1/A.2 sont dans `main`** — repris tels quels par le camarade dans la #28 (`f179f1ff`), mesurés sur sa tête : 133 fonctions `anon`, empreinte identique à la prod. |
| E18 | 2026-09-07 | **Constaté et clos le 07/09 par Xavier, sur `/obra/133` (« L'Homme et la Terre », Reclus)** : six « éditions » strictement identiques à l'écran — « 1905 · Librairie Universelle · Français » six fois, dans l'ordre VI, V, IV, I, III, II. Les données étaient justes (les six notices portent `volume` = I à VI et le sous-titre « Tome N ») : `api.work_public_detail` ne servait pas `volume` et triait par année puis titre, six clés égales. La liste du catalogue, elle, servait déjà le tome par édition avec son badge « Tome N » (`catalog.works.volumeLabel`, dix locales) — la page Œuvre était la seule surface à l'ignorer. Migration `20260907220000_la_page_oeuvre_dit_le_tome` (RPC reprise de sa définition en production : `volume` dans chaque édition, tri année → `fn_volume_rank` → titre, grants conservés), badge « Tome N » dans `WorkPage.jsx` avec la clé existante, suite `oeuvre_tomes_page_tests.sql` au manifeste (trois tomes insérés III, I, II qui doivent sortir I, II, III ; une édition sans tome garde `volume` NULL). Vérifié à l'écran sur `/obra/133` après déploiement. **Second geste le soir même, sur remarque de Xavier** (« c'est pas six éditions, c'est six tomes d'une seule édition ») : l'en-tête disait encore « 6 édition(s) ». Migration `20260907233000` : la RPC sert `edition_count` (une notice sans tome = 1 ; les tomes d'une même année/éditeur/langue = 1) et `volume_count` (tomes distincts, même règle que la liste), l'en-tête compose « 1 édition · 6 volumes » avec les clés plurielles existantes ; T6-T7 ajoutés à la suite. |
| E5 | 2026-09-07 | **Livré et en production le soir même — la dernière exception anti-pistage tombe, et pas par la voie que la fiche proposait.** La fiche voulait un *relais* de `tile.openstreetmap.org` avec cache ; la politique des tuiles d'OSM déconseille les proxys et interdit tout préchargement, et un relais aurait gardé la dépendance. Fait à la place : **un seul fichier PMTiles** (planet Protomaps du 07/09, dérivé d'OpenStreetMap, ODbL) extrait à **z12 = 18 Go** (`pmtiles extract --maxzoom=12`, mesures à vide : z10 3,7 Go, z11 7,9, z13 36, z14 68, z15 138), déposé dans le bucket public **`map-tiles`** (créé en base + migration `20260907234500` inerte ensuite, plafond global Storage monté de 500 Mo à 20 Gio par l'API de gestion, les cinq buckets sans plafond propre figés à leurs 500 Mo de fait) et lu par le navigateur **par requêtes Range** (Storage répond 206 + CORS `*`, vérifié). Rendu dans le Leaflet vendorisé par **`protomaps-leaflet` 4.0.1** (vendorisé, BSD-3, canvas + polices web, pas de serveur de glyphes) via `src/lib/mapTiles.js` ; les trois cartes (`CartographyMap`, `CartographyEditModal`, `CartografiaAjouterPage`) n'ont plus une ligne `L.tileLayer`. Garde CI `src/tests/carte-sans-domaine-tiers.test.js` (aucun `tile.openstreetmap.org` dans `src/`, toute `L.map(` passe par `addBasemap`). `privacy.s6.maptiles` et `federacao.carte.attribution` réécrits dans les dix locales. Recette et rythme de rafraîchissement : `scripts/maptiles/README.md` + `extraire-planet.sh` (mesure par défaut, n'agit que sur demande). **Deux limites écrites** : (1) le fichier est sur le Storage Supabase — la fuite d'IP vers un tiers est close, pas le périmètre Cloud Act, qui tombe avec **I2** (copier le fichier là où Caddy le sert, poser `VITE_MAPTILES_URL`, et compter ces 18 Go dans le disque demandé aux Herbes Folles — **I21**) ; (2) `map-tiles` est volontairement hors du flux storage de **BG2** (reconstructible en 30 min). Étiquettes : `ca` et `eo` absents du fond → noms locaux, sans repli vers une autre langue. Accessoirement : l'échec de juin 2026 dont tout le monde se souvenait comme « les fonds de carte » était **Nominatim** (géocodage, MAP-F), qui reste non configuré. Incident de méthode : la mesure à vide de z15 (177 M d'entrées) lancée en même temps que l'extraction a figé WSL à son plafond de 15 Go — `wsl --shutdown` avec l'accord de Xavier, aucune autre session active, rien perdu ; mesurer seul, ou pas z15. |
| IMP-20 | 2026-09-15 | **Un lot importé appartient à une bibliothèque de destination — livré et en production le soir même** (registre §17 `IMP-20`, migration `20260915184154`, commit `60e0580a`). Ce n'était pas un item : c'est une question de Xavier du 15/09 — « comment attribuer les 1 673 brouillons du lot Solidaires à cette bibliothèque ? » — dont la réponse honnête était « par un UPDATE à la main, que chaque admin aurait à refaire à chaque admission ». La chaîne d'import ne posait jamais `owner_library_id` ; la publication retombait sur la bibliothèque de qui publie. Fait : `destination_library_id` sur la source (la bibliothèque qui *détient* les livres, distincte de la bibliothèque importatrice), tampon de `owner_library_id` à la promotion selon la provenance, `fn_batch_reassign_library` (administration du réseau : brouillons en cours seulement, fiches publiées intactes, source alignée, trace dans les notes, refus si révision approuvée), `fn_batch_owner_libraries` et la colonne « Bibliothèque » dans Catalogação › Lots (« sans bibliothèque » en ambre avant de publier), bibliothèque de destination optionnelle sur une nouvelle source de dépôt dans Importações, 21 clés en dix locales, suite SQL de 12 tests. **Le lot Solidaires est attribué** (essai à blanc annulé, puis réel sous l'identité de Xavier) ; la fonction a rendu ses deux avertissements — bibliothèque sans série de tombos, inactive — d'où **E21**. Reste derrière **G7** (admission) et la révision de lot. |
| I19 | 2026-09-15 | **Clos le 15/09, sur mesure.** *(1)* L'extension : `deploy/init-db/01-roles.sh` crée `pg_cron` (`CREATE EXTENSION IF NOT EXISTS` + `GRANT` à `postgres` et `service_role`) et **s'arrête** si ça échoue ; au premier passage de l'entrypoint, où le rôle `postgres` n'existe pas encore, il le dit (« différé au prochain passage ») et le rejeu par `bootstrap.sh` (étape 2) fait le travail — livré par la PR #28 du camarade (`f179f1ff`), garde `to_regnamespace('cron')` sortie de `20260904130100`. *(2)* Le contrôle de santé : `deploy.sh --controle` vérifie que l'extension existe puis **rejoue `tests/sql/crons_planifies_tests.sql` sur le vrai `cron.job` de l'instance** — la même liste nommée que la CI, sans copie (DOC-RECENS-1) ; ✓ « N jobs planifiés — OK : n/n » sinon ⚠ et code de retour 1. Éprouvé sur pile vierge le 15/09 : 38 jobs, suite verte ; un job retiré à la main → ⚠ et rc 1 ; extension supprimée → ⚠ « extension ABSENTE » et rc 1. Reste hors item : la suite dit ce que le dépôt planifie, pas ce que la prod fait — relevé prod à refaire de temps en temps (38 au 15/09, mêmes noms). |
| E21 | 2026-09-15 | **La série de numéros d'inventaire et la cote d'une bibliothèque se règlent depuis l'écran ; un lot reçoit ses cotes et ses classes de rangement en un geste — livré et en production le soir même** (registre §12 `CAT-E17`, migration `20260915201252`, commit `f7bf927c`). Ouvert et clos le même jour, sur la question de Xavier « comment font-ils pour s'y retrouver avec des numéros d'inventaire dans l'ordre d'apparition ? ». Trois gestes, dans le patron proposé pour les numéros d'inventaire — une convention, un aperçu, une application, une trace : **(1)** bloc « Numérotation » dans Biblioteca › Identité et, pour l'admin, sous chaque bibliothèque de la page Réseau — préfixe, année, séparateur, remplissage, cote, exemple rendu en direct, prochain et dernier numéro ; gardes serveur : préfixe obligatoire sans `%` ni `_`, **unique dans le réseau** (préfixes déclarés et séries héritées des exemplaires, « SOL » et « SOL- » refusés l'un pour l'autre), **figé** dès qu'un exemplaire l'a utilisé ; **(2)** « Cotes manquantes » sur un lot ouvert : aperçu puis application, dans l'ordre du lot, à la suite des cotes existantes (notices, holdings, brouillons vivants), sous verrou par préfixe ; **(3)** « Classer par rubriques » : la rubrique lue là où l'import l'a laissée — pour Solidaires, `assunto_local` de la charge utile brute, puisque le run 29 n'a lié aucun sujet —, table rubrique → code relue par la coordination, `cdd` écrit sur les brouillons sans classe. Suite SQL de 14 tests, 101 suites vertes, 486 tests JS, 57 clés en dix locales. **Reste aux personnes** : choisir le préfixe de Solidaires (Réseau › Numérotation), attribuer les 1 673 cotes, remplir la table des 35 rubriques, activer la bibliothèque, puis la révision du lot (`catalog_batch_reviews`). |
| G7 | 2026-09-15 | **Solidaires est admise** — décision de Xavier du 15/09/2026 au soir, en mode « seul·e admin » (spec-onboarding §2.6), à défaut de co-administrateur·rices trouvé·es à Bologne (registre §1 `RES-D12` amendé, v0.34). Ce que la fiche attendait de l'admission est arrivé le même soir par `IMP-20` et `CAT-E17` : bibliothèque active, série d'inventaire `SOL-` + millésime, 1 673 brouillons attribués et cotés, coordination Christian. Le périmètre d'admission (`RES-Q13`) reste à porter en AG : Solidaires y entre comme cas, pas comme règle. |
| B19 | 2026-09-16 | **La HS256 est révoquée** — geste de Xavier le 15/09 à 22 h 14 (20 h 14 UTC), Settings → JWT Keys → Revoke. **Premier contrôle, 24 h après** (tâche `anarbib-trafic-cles-legacy`, relevé du 16/09) : aucun 401 sur une connexion utilisateur — 1 144 réponses 200, 20 en 204, 12 en 206, tous les jetons de session en ES256 avant comme après ; recoupé sur les logs edge : 0 × 401 sur `/rest/v1/` en 24 h hors les quatre de bingbot du 16/09 à 15 h 19 (robot sans clé, ni ancienne ni nouvelle). Seul reste en HS256 le compte `supabase_admin` de `@supabase-infra/mgmt-api` sur `/admin/v1/network-bans/retrieve`, toujours en 200 — l'infrastructure de Supabase, pas l'application. Les trois anomalies vues au passage ne viennent pas de la révocation et ont chacune leur cause : les `403` sur `DELETE auth_rate_limits` (**B25**, depuis mai), les `400` sur `GET gazette_submissions` du 15/09 à 21 h 09–21 h 11 UTC (le front de GAZ-9 publié par le job `app` quelques minutes **avant** que le job `backend` applique la migration qui ajoute `staff_edited_at`/`original_*` — l'ordre normal de la CI, transitoire), et les `400` sur `POST auth_rate_limits` (**B26**). **Les quatre parcours (connexion, inscription, récupération du mot de passe, document numérique) ont été testés par Xavier le 16/09 : ils fonctionnent.** La tâche `anarbib-trafic-cles-legacy` a été supprimée le même jour. |
| B25 | 2026-09-16 | **Livré le 16/09 au soir** (`af60bc49`, Edge Function `login` redéployée par la CI à 22 h 27, marqueur `deployed-functions` sur ce commit). Deux clients : celui de la clé secrète ne se connecte jamais (il lit, écrit et supprime les compteurs), un second, créé pour `signInWithPassword` seul, porte la session de la personne — le `DELETE` de `clearFailures` repart en `service_role`. Les clés sont des empreintes `sha256Hex` (IP, courriel en minuscules) : plus d'adresse ni de courriel dans la table, ni dans la query string du `DELETE` que traversent les journaux edge. Chaque erreur du magasin est journalisée ; un compteur illisible ferme (500). Banc `login-compteurs-haches` (6 tests : client à part, empreintes partout, `42501` journalisé, porte fermée). **Vérifié en production** : `auth_rate_limits` purgée (52 lignes brutes → 0), contrainte `auth_rate_limits_key_empreinte` posée. Reste à voir passer la première connexion réelle : un `DELETE` en 204 dans les logs edge, plus aucun `42501` dans `postgres_logs`. |
| B26 | 2026-09-16 | **Livré le 16/09 au soir** (`af60bc49`, migration `20260916201249` appliquée par la CI : prod 321 = dépôt 321). `_shared/core/rate-limit.ts` remplace le `hit()` copié trois fois : fenêtre fixe qui repart de 1 (l'ancien, une fois la limite atteinte, re-bloquait à chaque frappe — pour toujours), clé obligatoirement une empreinte, **échec fermé** (`frapper` lève, `freiner` répond 500 `rate_limit_unavailable`). `geocode`, `submit-cartography-entry` et `submit-gazette-contribution` l'utilisent ; `gazette_email` est haché. **Vérifié en production** : la `CHECK` de `kind` liste les sept kinds réels (`ip`, `email`, `geocode_ip`, `carto_ip`, `gazette_ip`, `gazette_email`, `gazette_prefill`), une seconde `CHECK` exige une empreinte de 64 hexadécimaux, la table est vide (lignes brutes purgées). Suite `compteurs_d_abus_tests` (4 tests, en CI) et banc `compteurs-d-abus-partages` (7 tests) ; 509 tests JS verts. Première ligne `geocode_ip` ou `gazette_ip` à voir apparaître au premier usage réel. |
| F9 | 2026-09-16 | **Relevé le 16/09/2026 à 22 h 30 (UTC+2), depuis le poste (`nslookup`)** — les trois enregistrements existent. **SPF** : `send.notifications.anarbib.org` TXT `v=spf1 include:amazonses.com ~all` (Resend envoie depuis le sous-domaine `send.`, c'est là que vit le SPF ; `notifications.anarbib.org` lui-même n'a pas de TXT, ce qui est attendu), MX `10 feedback-smtp.eu-west-1.amazonses.com`. **DKIM** : `resend._domainkey.notifications.anarbib.org` TXT `p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC5Uxzm…` (clé RSA publiée, sélecteur `resend`). **DMARC** : `_dmarc.notifications.anarbib.org` TXT `v=DMARC1; p=none; rua=mailto:admins@anarbib.org` — politique d'observation avec rapports vers les admins, la forme prudente que l'item demandait avant de durcir. Rien à poser ; durcir vers `p=quarantine` est une décision à part, après lecture des rapports `rua`. |
| I6 | 2026-09-16 | **Prouvé le 16/09/2026, à la date que l'item fixait.** `service_health_probes` : 34 568 lignes, la plus ancienne du **17/08 à 20 h 30 UTC**, la plus récente du 16/09 à 20 h 25 — et **zéro ligne de plus de trente jours**. La borne basse a avancé de trente jours en trente jours : la purge intégrée à `health-probe` supprime pour de vrai (le compteur `n_tup_del` de `pg_stat`, remis à zéro le 02/09, ne pouvait pas le dire ; le comptage direct le dit). `service_health_incidents` n'est pas touchée. Aucun cron à ajouter. |
| A2 | 2026-09-16 | **Clos le 16/09/2026, décision de Xavier.** La reconstruction par quelqu'un d'autre que le mainteneur a eu lieu : **un camarade de l'ASR** (compte `ASR2026`, première contribution extérieure) a monté la pile chez lui depuis le dépôt seul, en a écrit l'installateur (`install.sh`, PR #28, **fusionnée le 15/09** — `f179f1ff`) et consigné ce qui cassait dans ses commits (`pg_cron` absent au démarrage, schéma à initialiser sous `supabase_admin`, `GRANT` sur `supabase_migrations`, `LANG_CODE`, port 5173…), puis le mainteneur a relu et fusionné **depuis cette installation** — ses forks partent d'un AnarBib qui tourne chez lui. Les écarts structurels trouvés en chemin ont leurs notes (`CONSTAT_PR28_rejeu_vs_production_revoke_anon_2026-09-06`, `NOTE_experience-I17-rejeu-fidele_2026-09-07`, `DOC-GRANT-2/3`). Ce que la fiche voulait en plus — le journal d'exécution comme section de `deploy/README.md` — est posé le 16/09 (§ « Première reconstruction extérieure »). L'entrée 1 de `CHANTIERS_OUVERTS` reste à réécrire par le mainteneur : **J4**. |
| B22 | 2026-09-16 | **Clos le 16/09, sur mesure.** Relevé prod du jour : 133 fonctions exécutables par `anon` (public, api, ingest, private), 47 sans `GRANT … TO anon/PUBLIC` écrit — le compte du 07/09. Appelants cherchés avant tout REVOKE (vues et leur `security_invoker`, policies, corps + `prosecdef`, triggers, expressions d'index, défauts générés). Migration `20260916223000_b22_ouvertures_a_anon_ecrites` : **4 ouvertures qui servent, écrites** (`private.fn_book_work_id` lue par les vues invoker du catalogue anonyme ; `fn_book_restricted_pdf_state*` : page publique du livre et EF read-pdf ; `fn_volume_rank` : `api.catalog_works_v1`/`work_public_detail`) ; **43 fermées** (10 RPC de circulation + 2 à ACL nulle, 17 d'ingest avec `authenticated` gardé pour les 3 lues par les vues invoker de l'import et les 2 en expression d'index, 5 triggers/helpers des périodiques + `fn_serial_issue_key`, 4 helpers, 3 `fn_assert_*`, et deux DEFINER de T10 qui changent de camp) ; **5 vues de T7** : `REVOKE SELECT` écrit. `grants_herites_tests.sql` : T10 à 26, **T12 = liste fermée des 90 fonctions exécutables par anon**, dans les deux sens. Déployé par la CI (`21a98d0e`) ; **mesuré en prod à 22 h 40 : 90 fonctions, 30 DEFINER, empreinte `1852f6b2…` identique au rejeu sur image, lint 0028 = 26** (0029 = 420, hors item). Règle désormais : une fonction que anon doit appeler = un GRANT écrit dans sa migration ET une ligne dans T12, sinon T12 rougit. Hors item : `private.fn_book_work_id` reste DEFINER exposée à anon par deux vues invoker (voulu, catalogue public) — hors `public`/`api`, le lint 0028 ne la compte pas. |
| E12 | 2026-09-16 | **Clos le 16/09/2026 sur décision de Xavier (« clos tout ce qui peut l'être à bon droit »)** — les trois lots étaient livrés depuis le 02/09 (bandeau du jour : « page Importations restructurée, lots A-C : deux onglets, export trié, plus un code brut ») et la page porte ses onglets (`importacoes.tab.history`, `.reception`, `.rss`) ; l'item était resté « en cours » faute de clôture, pas faute de livraison. Constat corrigé le 16/09. |
| C2 | 2026-09-16 | **Clos le 16/09/2026 sur décision de Xavier (« clos tout ce qui peut l'être à bon droit »)** — le fonds Solidaires **est passé par l'outil d'import du dépôt** (source 17, run 29, lot 63 : 1 673 brouillons), pas par des `INSERT` ; l'admission a été prononcée avant de toucher au lot pour de bon (G7, 15/09 — la fiche voulait « à plusieurs », c'est le mode « seul·e admin » de `RES-D12` qui s'est appliqué, faute de co-admins) ; la clé `assunto_local_sugerido` est présente dans la charge brute des 1 673 brouillons (mesuré le 20/09) — que les corrections d'accents y vivent, et qu'aucune n'ait été faite en silence ailleurs, **n'a pas été vérifié** : à regarder dans la révision du lot. Ce qui a cassé est consigné : `library_without_tombo_pattern` → E21, 91 fascicules et 87 monographies suspectes → **D3**, aucun sujet lié par le run → rubriques (E21). La relecture d'un échantillon se fait dans la révision du lot (`fn_batch_review_report`, rapport admin obligatoire avant `publish_catalog_batch(63)`) : elle n'a pas besoin d'un item à part. |
| K5 | 2026-09-16 | **Clos le 16/09/2026 sur décision de Xavier (« clos tout ce qui peut l'être à bon droit »).** **Rectifié le 20/09/2026** : la première rédaction de cette ligne affirmait des faits que la session qui l'a écrite n'avait pas sous les yeux. Ce qui est établi : l'échéance de Bologne (13/09) est passée, et la suite technique est ouverte à part (H10-H13 ; K9 clos sans objet). Ce qui **n'est attesté par aucune pièce lue** : que l'intervention a eu lieu et que l'appel a été porté, et la liste des contacts pris avec ce que chacun a proposé — la note mémoire de Bologne date du 20/08 et ne dit rien du 13/09, aucun fichier du journal n'est daté des 12-14/09. Les « notes de session du 13-14/09 » citées d'abord n'existent pas ; « CIRA incertain » était périmé (bibliothèque retirée le 31/08). La clôture repose sur la décision de Xavier, qui y était ; le compte rendu reste à verser par lui s'il veut que la ligne dise ce qui s'est passé. Sur l'accessibilité, E1 reste. |
| K6 | 2026-09-16 | **Clos le 16/09/2026 sur décision de Xavier (« clos tout ce qui peut l'être à bon droit »).** **Rectifié le 20/09/2026** : la première rédaction de cette ligne affirmait des faits que la session qui l'a écrite n'avait pas sous les yeux. Ce qui est établi : des fichiers de travail existent sur le disque `F:` dans un dossier nommé « Rencontre Leftove.rs », et l'esquisse SKOS du thésaurus a été régénérée le 09/09 **sur les réponses de la FICEDL du 07/09** (H13 la verse au dépôt) — pas « avec » leftove.rs, comme il avait été écrit. Ce qui **n'est attesté par aucune pièce lue** : que la rencontre s'est tenue, que les trois questions ont reçu une réponse, et que le point licence (CC BY-NC-SA) a été regardé avant — les seules traces « leftove » du dépôt datent des 26-27/08. La clôture repose sur la décision de Xavier ; le sujet de la numérisation et de NORLA reste ouvert dans H6/G8. |
| K9 | 2026-09-16 | **Clos le 16/09/2026 sur décision de Xavier (« clos tout ce qui peut l'être à bon droit »)** — **sans objet** : les quatre textes de Bologne ont servi le 13/09 ; corriger des chiffres dans un dossier d'intervention passé n'a plus de destinataire. Les chiffres vivants (623 descripteurs au 03/09, 138 rattachés sur 148, la question `guerres`/`art : courants`) sont ceux de H10-H13, qui restent ouverts. |
| I12 | 2026-09-16 | **Clos le 16/09/2026 sur décision de Xavier (« clos tout ce qui peut l'être à bon droit »)** — l'automatisation est faite et prouvée depuis le 05/09 (minuteur systemd utilisateur, 18 h 02 chaque jour, passages lus dans `journalctl --user`, +32 commits le 04/09). Ce qui restait — donner un destinataire au `die` du script et écrire la date du dernier rafraîchissement dans le témoin — est **le même problème que I24** (une alerte qui ne survit pas au poste) : il y est versé, pour être réglé une seule fois avec le flux `storage`. |
| I13 | 2026-09-16 | **Clos le 16/09/2026 sur décision de Xavier (« clos tout ce qui peut l'être à bon droit »)** — mesuré le 16/09 : le site est servi par git-pages, une route inconnue (`/une-route-qui-n-existe-pas`) rend **200 `text/html`** ; `public/_redirects` existe, `public/.domains` n'existe plus, la branche `pages` n'existe plus sur Codeberg, `public/CNAME` est gardé pour le miroir GitHub. Le nettoyage des secrets Forgejo devenus inutiles est un geste de Xavier dans les réglages de la forge, hors dépôt — il n'a pas besoin d'un item. Les incertitudes assumées (réversibilité, limites non publiées) restent vraies et n'ont pas mordu depuis le 21/08. |
| I1 | 2026-09-16 | **Clos le 16/09/2026 sur décision de Xavier (« clos tout ce qui peut l'être à bon droit »)** — `deploy/.env.example` porte `GOTRUE_TAG=v2.192.0` avec la règle « image ≥ production » et l'historique de la montée (v2.189.0 → v2.192.0 le 20/08) ; les passes du 26/08 ont mesuré **77 migrations GoTrue = la production exactement** ; la PR #28 a rejoué la pile sur cette image. Le troisième « fini quand » (lister les douze dernières versions de production) est levé : la mesure directe vaut mieux que la liste. |
| G11 | 2026-09-16 | **Clos le 16/09/2026 sur décision de Xavier (« clos tout ce qui peut l'être à bon droit »)** — la règle d'amorçage est **actée au registre** : `GOUV-19`, « ✅ tranché 06/09 (Xavier, Q1 : A + B + C + D′) » — amorçage unique hors circuit, refusé dès qu'un admin actif existe ; mot de passe aléatoire dans tous les modes, affiché une fois ; premier compte = coordination de la première bibliothèque **et** admin réseau ; bibliothèque `demo` créée si la table est vide. `deploy/scripts/seed-admin.mjs` (PR #28, fusionnée le 15/09) applique les quatre (`crypto.randomBytes` en tout mode, rôles `coordenador` + `librarian` + ligne `network_administrators`, refus si un admin existe), et `deploy/README.md` § « Compte administrateur initial » le présente comme l'amorçage d'une base vierge. Constat corrigé : la fiche disait « à écrire », c'était écrit. |
| J3 | 2026-09-17 |  *(second item portant l'identifiant J3 — celui de la PR #28, 06/09 ; le premier est clos plus haut)* **Clos le 17/09/2026 sur les faits, décision de Xavier du 16/09 (« clos tout ce qui peut l'être à bon droit ») ; signalé par la session voisine le 16/09 au soir.** La PR pages #2 (guide d'auto-hébergement du site vitrine, dix langues) est **fusionnée le 16/09 à 22 h 00** (API Codeberg : `merged: true`), après la PR #28 (15/09) comme la fiche l'exigeait ; les quatre phrases sont corrigées et l'avertissement posé ; la relecture D4 (la simulation en option 3, jamais en option 1) est prise, et `install.sh` ne promet plus que Resend (`035853eb`, 16/09 23 h 12 : SMTP et simulation annoncés « à venir », rien de silencieux). |
| A4 | 2026-09-17 |  *(second item portant l'identifiant A4 — celui de la PR #28, 06/09 ; le premier est clos plus haut)* **Clos le 17/09/2026 sur les faits, décision de Xavier du 16/09 (« clos tout ce qui peut l'être à bon droit ») ; signalé par la session voisine le 16/09 au soir.** `CONTRIBUTING.md` porte les trois règles (une PR = un sujet ; le code de production dans une PR à part ; des commits, jamais de réécriture pendant la relecture) et la promesse du mainteneur (un premier retour sous une semaine), en français (§ « Le rythme du travail ») et en anglais (§ « Working rhythm ») ; `DOC-CONTRIB-1` au registre. La PR #28 a été **scindée selon ces règles** (installateur dans #28, code applicatif dans #29, guide vitrine dans pages #2) puis fusionnée le 15/09 en connaissance de cause. L'exigence d'une version portugaise est levée : le fichier est bilingue FR/EN par construction, comme le README. |
| I16 | 2026-09-17 |  *(second item portant l'identifiant I16 — celui de la PR #28, 06/09 ; le premier est clos plus haut)* **Clos le 17/09/2026 sur les faits, décision de Xavier du 16/09 (« clos tout ce qui peut l'être à bon droit ») ; signalé par la session voisine le 16/09 au soir.** L'objet de l'item — **suivre la PR #28 jusqu'à sa fusion** — est atteint : scission faite (#28 installateur, #29 code applicatif ouverte à part, pages #2 guide vitrine), les quatre points bloquants réglés, gel du 08 au 14/09 tenu, **fusion le 15/09** (`f179f1ff`), pages #2 le 16/09, `GOUV-19` acté (G11 clos). Le troisième « fini quand » (`install.sh` exécuté une fois sur une machine qui n'est pas celle de son auteur) n'est pas une condition de la fusion : c'est une épreuve de la pile, versée à **I21** (les conditions avant la bascule) — `deploy/README.md` § « Première reconstruction extérieure » la nomme. La relecture de #29 comme du code de production se poursuit sous son propre numéro de PR, avec F7 et B20. |
| B23 | 2026-09-20 | **Clos le 20/09/2026 sur pièce — constat corrigé : il n'y avait rien à faire.** Le « fini quand » disait « la vue est en invoker, **ou** porte le commentaire qui dit pourquoi elle ne l'est pas ». `obj_description('api.library_email_identity')` rend un `COMMENT ON VIEW` complet, signé « Paquet API-VUES-DEFINER du 29/08/2026 » et amendé le 30/08 : identité d'expédition lue par les fonctions de courriel, `service_role` uniquement, « n'est accordée ni à anon ni à authenticated, et ne doit jamais l'être », et « si un GRANT applicatif lui était accordé un jour, il faudrait la passer en security_invoker dans le même mouvement ». Mesuré le 20/09 : propriétaire `postgres`, `reloptions` vides, seul `service_role` a `SELECT`, aucune fonction ni vue ne la cite, un seul lecteur au dépôt (`register`, par le client admin). Le relevé du 07/09 n'avait lu que `reloptions`, pas le commentaire ; la session du 20/09 l'avait d'abord annoncé « petit, en SQL » sur la même lecture partielle. On ne bascule pas en invoker : le commentaire dit pourquoi. |
| G12 | 2026-09-20 | **Clos le 20/09, sur pièces.** *(1)* La phrase : REGISTRE `FED-O11` (✅ tranché le 06/09, Q2 : A) ; le guide d'auto-hébergement de la vitrine la dit dans ces termes depuis `b9c85e6` (20/09) — la ligne « Partage de catalogue » (clé `s1_adv4` du générateur, dix langues), qui disait « votre catalogue peut être partagé avec le réseau », devient « Une instance, un réseau » : seul le catalogue traverse, par OAI-PMH, sur décision des admins ; comptes, appartenances, prêts entre bibliothèques, gouvernance et gazette ne traversent pas ; `deploy/README.md` porte la même phrase dans une section « Une instance = un réseau ». Contrôlé sur les dix pages régénérées : une mention d'OAI-PMH chacune, l'ancienne formule absente. *(2)* L'annuaire : décision datée dans `journal/arbitrages/QUESTIONS_pr28_contribution_exterieure_2026-09-06.md` (l. 47, verdict A du 06/09 : « l'annuaire n'est pas ouvert »). Aucun code. |
| B20 | 2026-09-20 | **Clos le 20/09, sur mesure.** Relevé du jour dans `supabase/functions/**` : deux fonctions lisaient encore `SUPABASE_SERVICE_ROLE_KEY` par `Deno.env.get`, hors du chemin de `_shared/core/secret-key.ts` — `opds` (l. 28) et `rss-novidades` (l. 28), écrites après B18 sur le modèle d'avant. Commit `f83c5f66` : les deux passent par `secretKey()` ; `src/tests/cle-legacy-garde.test.js` interdit toute lecture d'environnement de la variable legacy (liste fermée des fichiers autorisés : vide ; commentaires ignorés ; noms de constantes et messages d'erreur tolérés, ils ne lisent rien) ; le banc `rss-novidades.test.js` évalue le vrai `secret-key.ts` et ne pose que `SUPABASE_SECRET_KEYS` ; une phrase dans `CONTRIBUTING.md` (fr, en). **Critère 1** : la garde est rouge sur `main` avant le correctif (les deux fonctions nommées) et rouge sur le `secret-key.ts` du sommet de la PR #28 au 06/09 (`b5782ec1`, l. 26 : `return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")`), mesuré le 20/09 ; verte après, 536 tests. **Critère 2** : le `secret-key.ts` de `main` ne connaît que `SUPABASE_SECRET_KEYS` (la PR #28 fusionnée ne le touche plus ; la garde le vérifie). Déployé par la CI au second run (`fd5f5a6b` : le premier, sur `f83c5f66`, était rouge sur quatre délais de tests sans rapport, backend sauté ; `testTimeout` porté à 20 s). Relu en production le 20/09 : `opds` en version 27, sa source déployée lit `secretKey()` ; `/opds/all` rend 18 entrées, `rss-novidades/blmf` 30. Hors item : cinq messages d'erreur (`probe-partner-catalog`, `harvest-oai-pmh`, `gc-deposits`, `process-partner-catalog-import`, `receive-fonds-bundle`) disent encore « Missing … SUPABASE_SERVICE_ROLE_KEY » alors que la variable lue est `SUPABASE_SECRET_KEYS` — trompeur, sans effet. |
| J4 | 2026-09-21 | *(second item portant l'identifiant J4 — celui de `CHANTIERS_OUVERTS` §1, 06/09 ; le premier, sur la spec de gouvernance, est clos plus haut)* **Clos le 21/09 : l'entrée 1 est réécrite, sur un texte validé par Xavier le jour même (option A de deux proposées).** Elle reste « le meilleur premier pas » mais son objet change : la reconstruction par un tiers a eu lieu (06–15/09, PR #28 fusionnée le 15/09), il reste à lancer `install.sh` sur une troisième machine, vierge — ce que `deploy/README.md` nomme comme non éprouvé (I21). L'entrée porte ses mesures datées (06–15/09 ; 07/09, empreinte des fonctions ouvertes à l'anonyme identique à la production, clôture I17 ; 16/09, job `rejeu-image`) et sa signature. Elle dit que la forge refait le rejeu à chaque poussée ; elle ne dit pas que ce filet a déjà attrapé quelque chose — I18 reste en cours sur ce critère. Dans le même commit : le prénom du contributeur quitte l'entrée et `deploy/README.md` (« un camarade de l'ASR (compte `ASR2026`) ») ; le README ne range plus le rejeu CI parmi ce qui n'a pas été éprouvé ; l'en-tête est daté du 21/09 et la note de gel de l'entrée 2, échue le 14/09, devient un état daté qui renvoie à I21. **Hors item, laissé en l'état et signalé** : `AIDER.md` (§ `A2`, fr, pt, en) dit encore « personne ne l'a jamais vérifié » ; le REGISTRE porte le prénom dans des entrées historiques. |
| E17 | 2026-09-21 | **Clos le 21/09 sur décision de Xavier (« Clos E17 »).** Livré en deux temps : `3c411f10` (20/09) — le bloc « Explorer » naît replié, s'en souvient dans les deux sens, dit ce qu'il cache, ne se rouvre jamais seul ; `16d22656` (21/09) — sur écran étroit, « Filtres » naît replié lui aussi, avec son badge des filtres actifs, et emporte sa rangée d'actions. Mesuré à l'écran à 375×812, première visite : premier titre à **778 px, visible sans défiler** (4 018 px avant E17). À 1366×768 le bloc « Filtres » naît ouvert et le premier titre reste à 880 px, sous la ligne de flottaison : **critère écarté par choix de Xavier le 21/09** (« replié sur mobile seulement ») — l'outil principal du catalogue reste sous la main sur portable. Bancs `catalog-explore-replie` (5 cas) et `catalog-filtres-replies-mobile` (7 cas). Vérifié en production le 21/09 à 13 h 55 (les deux feuilles et les deux modules servis portent le code). |
| E16 | 2026-09-21 | **Clos le 21/09 sur pièces — la contradiction vivait dans les fichiers de langue, pas à l'écran.** *Lu dans le code* : la sous-page est un seul composant (`RetentionPolicySection`, monté par l'onglet `privacy` de `BibliotecaPage`), qui rend **un seul bandeau, sans condition** — `biblioteca.privacy.purgeActiveNotice`, « la suppression automatique est active » — depuis le 03/06 (`8d3dd444`, « honest UI »). Le second message, `biblioteca.privacy.phase4aNotice` (« pas encore active, elle le sera en Phase 4b »), n'était plus employé par aucun fichier de code mais restait dans les **dix** locales : c'est là que la refonte du manuel l'a lu. *Lu en base* : le message affiché dit vrai — le cron `anarbib-rgpd-purge-weekly` est actif, `fn_purge_expired_data(p_dry_run := false)`, 16 passages, le dernier le 20/09 à 03 h UTC, `succeeded` ; le préavis `anarbib-rgpd-notify-weekly` tourne une heure avant (20 passages). *Fait* (`48c413ac`) : la clé morte retirée des dix locales (6 690 → 6 689, parité stricte), et le banc `privacidade-un-seul-message-sur-la-purge` (3 cas) qui tient ensemble les trois faits — un seul bandeau, plus de clé `phase4a` ni de renvoi à une « Phase 4b », et une purge planifiée pour de bon (socle + liste fermée des crons, aucune migration qui la déplanifie ou la repasse à blanc). **Ce qui n'a pas été fait** : je n'ai pas ouvert l'écran sur `blmf-teste` (page du personnel, session requise) ; le « fini quand » est tenu par la lecture du composant, qui n'a qu'un chemin de rendu pour ce bandeau. Le Manuel v5 peut retirer sa mise en garde « vérifier l'instance ». |
| I23 | 2026-09-21 | **Clos le 21/09 sur pièces — réglé depuis le 20/09 sans que la fiche le sache.** Trouvé par l'inventaire du 21/09 (sessions et commits depuis le 09/09 confrontés aux items ouverts) : aucune session n'a jamais nommé `I23`, alors que son unique critère — « le domaine résout et redirige » — est tenu. *Mesuré le 21/09 à 20 h 21* : `https://anarbib.is/` répond **307 vers `https://anarbib.org/`** (`.is`, ccTLD islandais, déposé chez ISNIC et non chez OVH comme la fiche le prévoyait) ; `app.anarbib.is` sert l'application en 200 ; `anarbib.org.br` (307) et `app.anarbib.org.br` (200) font de même depuis le 21/09. *Au registre* : **`OPS-10`** (§38, v0.41) — `anarbib.org` reste canonique, `.is` et `.org.br` sont des routes d'accès câblées et éprouvées, **jamais annoncées** : il n'y a donc rien à écrire dans la politique de confidentialité, ce que la fiche réservait au cas où le domaine y figurerait. Deux restes, qui ne sont pas de cet item : `www.anarbib.is` n'a pas répondu en HTTPS à la mesure (cause non relevée), et l'essai de bascule **authentifié** du runbook, que `OPS-10` garde ouvert. |
| I26 | 2026-09-21 | **Clos le 21/09, le soir même de son ouverture — les trois « fini quand » tenus, chacun avec sa mesure.** Décision de Xavier : la voie de la liste au dépôt plutôt qu'un quatrième fichier de dump. *(1) La question des secrets* : mesuré en production, **0 secret littéral et 0 URL en dur sur les 38 commandes** ; une seule lit un secret (`anarbib-health-probe`), à l'exécution, dans `vault.decrypted_secrets`. La liste peut donc vivre au dépôt. *(2) Ce qui a été livré* (commit `2237d433`, migration `20260921193147`) : une migration seule n'y pouvait rien — restaurée avec son historique, elle est inscrite « faite » et ne se rejoue pas ; d'où une **fonction**, qui voyage dans le dump avec le schéma. `private.fn_crons_attendus()` porte nom, horaire, commande et état des 38 jobs, relevés en production (empreinte md5 `bf25c87f…`, recalculée par la migration elle-même : une retouche d'espace ou de fin de ligne la fait échouer) ; `private.fn_crons_replanifier()`, SECURITY DEFINER pour que les jobs appartiennent à `postgres` comme en production, ne touche qu'aux jobs absents, différents ou inactifs, signale les inattendus et ne retire jamais rien. `restore.sh` l'appelle (étape « 3 ter ») ; `bootstrap.sh` rejoue la suite des crons dans sa vérification finale (contrôle h) et **rougit** s'ils manquent. La suite `crons_planifies_tests.sql` gagne T7 et T8 : sa liste et les commandes réellement planifiées doivent être celles de la fonction — qui ajoute un cron par migration sans le reporter fait rougir la CI. *(3) Éprouvé* : banc SQL complet ; puis **aller-retour réel sur `pg_cron`** — pile bâtie depuis le dépôt, dumpée par la CLI (0 ligne de `cron.job` dans le dump, la fonction y est), démontée, restaurée : « 3 ter OK — 38 jobs planifiés, tous sous le rôle postgres », contrôle (h) vert ; contre-épreuve, table vidée → `deploy.sh --controle` rouge (38 absents), fonction → vert. *En production* : migration appliquée par la CI, `fn_crons_replanifier()` y rend `deja_en_place: 38, planifies: []`, et l'empreinte de `cron.job` est inchangée avant/après (`bf25c87f…`). Appris en passant : sur le dépôt rejoué, 14 commandes différaient de la production par la seule mise en forme (espaces, casse) — la fonction suit la production à l'octet. **Ce que cette clôture ne couvre pas** : l'aller-retour a porté sur une pile sans données ; la restauration d'un dump de la *production* postérieur à cette migration n'a pas été rejouée (elle l'avait été le même soir, avant, et c'est elle qui avait fait ouvrir l'item). |
| E22 | 2026-09-22 | **Clos le 22/09 : la feuille est nommée, l'accolade retirée, et une garde rougit avant le build.** Trouvée en comptant les accolades de chaque feuille de `src/` hors commentaires : `src/pages/painel/PanelPage.css`, ligne 632 — une fermante restée seule quand la règle `.ab-painel-tab-divider` a été remplacée par un commentaire (commit `83e68421`, 15/09). La ligne du minifieur (`<stdin>:632`) était la bonne : le lot ne comptait qu'une feuille. Effet dans les navigateurs : aucun — une fermante orpheline au premier niveau est jetée par l'analyseur CSS ; effet réel : un avertissement qu'on apprend à ne plus lire. Retirée (commit du 22/09), `npm run build` ne rend plus l'avertissement. La décision « un avertissement du minifieur doit-il faire échouer le build ? » tombe : `src/tests/css-accolades-equilibrees.test.js` parcourt chaque feuille suivie par git, hors commentaires et chaînes, et rougit en nommant feuille et ligne — avant le build, en CI. |
| B28 | 2026-09-22 | **Clos le 22/09 au soir, sur mesure.** Trouvé le jour même en câblant la suppression de compte sur la page contributeur (`310be843`). Relevé complet de `pg_constraint` en production : **26 colonnes dans 20 tables** portaient une FK vers `profiles` ou `auth.users` en NO ACTION ou RESTRICT que `fn_delete_my_account` ne re-pointait pas — `authority_proposals.proposed_by` en tête (tout·e contributeur·ice ayant proposé une chose ne pouvait pas s'effacer), `library_requests.submitted_by_user_id` (RESTRICT), les éditeurs créés au catalogage, les messages archivés… Une première lecture des codes de `confdeltype` était fausse (deux tables nommées à tort, en SET NULL) ; rectifiée avant la migration. Migration `20260922214500_b28_l_effacement_repointe_tout_acte_sur_le_jeton` (`4f68cbfe`), repartie de la définition réelle : bloc « ACTES NOMMÉS » qui re-pointe les 26 colonnes sur le jeton pseudonyme, comme la gouvernance, et compte `pseudonymized_act_rows`. Suite `tests/sql/effacement_compte_fk_tests.sql` : T1 relit `pg_constraint` (**liste vivante** : une FK nouvelle non citée par la fonction fait rougir), T2–T5 effacent un compte qui a créé un éditeur et déposé une demande d'entrée. Premier run rouge sur le jeu d'essai (contraintes de `library_requests`), reproduit et corrigé en local avec le lanceur de la CI (`1fa81534`, 5/5). **CI verte** (sql-tests, rejeu-image, backend) ; **migration appliquée en production** (`schema_migrations` = `20260922214500`, corps de la fonction relu). Cas réel : le compte contributeur d'essai de l'essai de bascule s'est supprimé depuis sa page à 20 h 54 (`erasure_log`), avant la migration — il n'avait rien proposé ; le cas d'un compte ayant agi est couvert par la suite, pas encore par un compte réel. |
| I27 | 2026-09-22 | **Clos le 22/09 : les trois critères tenus, les deux derniers par Xavier, chacun avec sa preuve.** *(1)* `--essai` : « dry-run ok » sur `app.anarbib.org`, `app.anarbib.is`, `app.anarbib.org.br` — après un premier refus instructif : un jeton à la seule permission `repository` lecture-écriture lisait le dépôt (`push: true` vu par l'API) mais git-pages commence par `GET /api/v1/user`, qui exige **`user` lecture** ; Codeberg répondait 403 et le serveur refusait. *(2)* Publication réelle sur le seul domaine de repli : `--sans-build --site https://app.anarbib.is/` → « result: replaced ». **Preuve** : `https://app.anarbib.is/.version-front` rend `68b18cf8` — un fichier que seul `publier-front.sh` écrit, et que le canonique publié par la CI n'a pas (il y répond par `index.html`, le repli SPA) ; bundle servi `index-B3w3O5ED.js`, le même que sur `app.anarbib.org` ; `Last-Modified` à l'heure du tir. Aucun changement pour les lectrices : c'est le `dist/` du même front. Nuance honnête : le bundle avait été construit sur `4ba95b8f` et le tampon porte `68b18cf8`, deux commits de documentation plus tard — le front est identique, le tampon dit le HEAD au moment de publier. *(3)* Jeton `publier-front-hors-forge` (Codeberg, permissions `repository` lecture-écriture + `user` lecture), dans `~/anarbib-ops/git-pages.token` (chmod 600) et Dashlane ; consigne dans l'en-tête du script. Le chemin de secours du front existe désormais pour de vrai — emprunté un jour calme. |
| B27 | 2026-09-22 | **Clos le 22/09 au soir, sur pièces : les trois critères tenus.** *(1)* Tenu le 21/09 — un appel anonyme avec les arguments du premier chargement répond en **380 ms** (50 œuvres) et 460 ms (200), plan consigné dans l en-tête de la migration `20260921111344` ; 3 533 ms et 27 311 ms avant. *(2)* Relu le 22/09 dans `postgres_logs`, fenêtre de 24 h (21/09 12 h → 22/09 12 h UTC) : **zéro `57014` sur `catalog_works_v1`** ; `edge_logs` sur la même fenêtre : **337 appels, 337 × HTTP 200**, du premier au dernier. Nuance honnête : ces 337 appels viennent d une seule adresse, celle de la sonde — la « journée de trafic réel » est une journée de sonde toutes les cinq minutes avec les arguments exacts du premier chargement ; aucun·e visiteur·se anonyme n a chargé le catalogue par œuvre dans la fenêtre. Les sept `57014` que la journée porte sont ailleurs : cinq lectures de `service_health_incidents` par PostgREST et deux `ALTER TABLE` sur cette même table, le 21/09 entre 18 h 30 et 18 h 39 UTC — une attente de verrou sur une table de sonde, pas la RPC du catalogue ; cause non relevée. *(3)* Tenu — la sonde `catalogue_par_oeuvre` de `health-probe` (`5111ac5f`) appelle la RPC en anonyme toutes les cinq minutes, seuil 3 000 ms = le délai du rôle `anon`, deux tours mauvais ouvrent un incident ; le front journalise son repli. Suites en CI : `catalogue_par_oeuvre_cout_tests` (7 cas), banc `health-probe-catalogue-par-oeuvre` (3 cas). Hors item, consigné pour qui rouvrira la question : la vue elle-même reste le poste le plus cher (`fn_library_visible_to_caller` évaluée par détention, ~70 000 accès aux tampons par appel). |
| F7 | 2026-09-24 | **Attention : l'identifiant `F7` désigne deux objets — les treize secrets vides (clos le 02/09, ligne plus haut) et celui-ci, le transport mail.** **Clos le 24/09 au soir, sur pièces : les deux critères tenus, et le cas (a) de `DOC-SILENCE-1` qui les motivait a une alarme.** *(1)* Sans `MAIL_TRANSPORT=mock` explicite, une fonction sans service configuré lève un message lisible — livré par la PR #30 du camarade (`ASR2026`), fusion `2cd27d71` le 23/09 après six corrections obtenues en relecture (RFC 2047 sur les noms accentués, STARTTLS obligatoire avec opt-in `SMTP_ALLOW_INSECURE`, corps en base64 plié à 76 colonnes, garde `SMTP_HOST`, délais `SMTP_TIMEOUT_MS`, banc `smtp-transport.test.js` qui charge le vrai module). **Preuve en production** : une réservation et son annulation le 23/09 à 19 h 30 ont fait partir quatre courriels par `notify-event`, journalisés « `[transport] envoi via Resend` » — la majuscule n'existe que dans le code fusionné. *(2)* Une seule implémentation d'envoi, appelée par toutes les fonctions : les huit copies de l'appel à Resend ont rejoint `_shared/transport/email.ts` en trois lots (`7a2ba5e9`, `c7db27e1`, `b0ff9970`/`badf88de`/`f2c36a6f`), chacune en passant SON routage explicitement — le module posait un `Reply-To` d'office depuis le contexte, ce qui aurait rendu à `notify-library-request` celui que F14 venait de retirer ; d'où `routing` et `noReplyTo`. Le module a aussi appris `toEmails` (une liste de destinataires en un message, pour `register`) et `transportConfigure()` (la garde de `register` exigeait `RESEND_API_KEY` : une pile SMTP aurait eu `MISSING_ENV` à chaque inscription). **Garde** `src/tests/mail-transport-routage.test.js` : payload figé (From du routage explicite, absence de Reply-To sous `noReplyTo`, repli sur le contexte, `throw` sans service) et liste fermée des fonctions encore en direct, **vide** ; éprouvée par mutation. La garde F14 (`reply-to-meme-domaine`) balaye désormais aussi un Reply-To passé en routage explicite. Déployé en trois runs verts (#1316, #1317, #1318) ; empreintes neuves constatées, OPTIONS 200/405 partout. **Rectification** : `register` n'a jamais été silencieux — il renvoie `email_usuaria_enviado: false` et la page d'inscription avertit. Le vrai cas (a) était `request-password-reset`, dont le `catch` anti-énumération (décision juste, gardée) avalait tout échec de transport. **Réponse le 24/09** (`91475d06`, migration prod `20260924180538`) : le module note chaque échec dans `mail_transport_failures` — jamais l'adresse, erreur expurgée `<adresse>` et tronquée — et `health-probe` porte la sonde `mail_transport` (`fn_healthcheck_mail_transport()`, `security definer` fermée à `anon`) : un échec dans les 30 dernières minutes ouvre l'incident, trente minutes de calme le referment ; `kind` dans la CHECK et dans `sondesStructurelles` par la même livraison ; table classée pour la sauvegarde, purgée à 30 jours ; suite `mail_transport_tests` (6/6) dans la liste des suites. Constaté après déploiement : tour de la sonde à 20 h 35, zéro incident, sonde `ok`. **Non éprouvé** : un vrai échec ouvrant un vrai incident — Xavier a choisi de ne pas simuler ; la recette de F2 (une ligne insérée, deux courriels) reste valable le jour où on voudra. |
| I25 | 2026-09-24 | **Clos le 24/09 sur pièces : la cause est nommée, reproduite et retirée.** Le filet lisait la sortie par `echo "$out" | grep -qE ' OK : …'` sous `set -o pipefail` : `grep -q` quitte à la première ligne « OK : », `echo` n a pas fini d écrire ce qui la suit (« ROLLBACK »), reçoit SIGPIPE, et `pipefail` fait de son code 141 le verdict — FAIL sur une suite verte. Rare, parce que ce reste tient en quelques octets, le plus souvent déjà dans le tampon du tube. **Reproduit le 24/09 hors CI, 300 fois sur 300**, en plaçant 300 Ko après la ligne « OK : » (bash 5 sous Git Bash ; le mécanisme est celui de POSIX) ; **0 sur 300 depuis un fichier**. `scripts/ci/run-sql-suites.sh` lit désormais la sortie depuis un fichier (`grep -c`, aucun tube), et un FAIL imprime le code de psql, celui de grep, le nombre de lignes « OK : » et la taille de la sortie. Rejoué en local sur `supabase_db_anarbib` (325 migrations, 192 tables classées) : `mail_transport_tests` et `crons_planifies_tests` PASS ; une suite sans bilan FAIL avec sa ligne de diagnostic (« psql rc=0 · grep rc=1 · lignes OK=0 · 48 octets »). Le second critère (« trois mois sans récidive ») avait été écrit pour une cause inconnue ; la cause est nommée, l attente n a plus d objet. `32edb185`, `sql-tests` vert en CI. |
| F13 | 2026-09-24 | **Clos le 24/09 sur pièces.** `sendIll` rend le verdict de `safeSendEmail` par `verdictEnvois` (`_shared/domain/outbox-verdict.ts`, le même juge que les sept modules corrigés le 21/09) : `sent_count` ne compte que les envois acceptés par le transport ; la réponse porte `refused_count`, `refused` (adresse et cause) et `skipped_count`. Le cas épinglé du banc `notify-digital-share-banc` est retourné — transport en panne : `sent_count` 0, un refus nommé (`dem@exemplo.test`) ; un cas neuf vérifie les trois comptes sur un envoi à deux (2 / 0 / 0). **Plus aucun cas du dépôt n est épinglé « DÉFAUT CONNU »** (il reste une mention au passé dans `library-profile-banc`). Rien n affiche encore cette réponse : c était le dernier endroit connu à garder la forme du défaut « sent à tort ». `32edb185`, CI verte (`app`, `backend`), fonction déployée (marqueur `deployed-functions`), sondée en production après le déploiement : marqueur `deployed-functions` sur `32edb185`, trois appels sans secret → 401 en 0,3 à 1,7 s à 21 h 32, la fonction démarre. |
| E15 | 2026-09-24 | **Livré le 24/09, clos sur pièces, avec une réserve.** Dans huit locales, le mot de « vider l historique » (`account.history.deleteAll.confirmWord`) était celui de « supprimer le compte » (`account.deleteAccount.confirmText`) : le mot appris pour un geste ouvrait l autre. Le premier change, sur le modèle de pt-BR (APAGAR / EXCLUIR) et de ca (ELIMINA / SUPRIMIR) : **fr EFFACER, en ERASE, es BORRAR, it CANCELLA, de LEEREN, nl WISSEN, el ΕΚΚΑΘΑΡΙΣΗ, eo VIŜI** — le mot du compte ne bouge pas, personne n a rien à réapprendre pour le geste le plus grave. Banc `confirmation-deux-gestes-deux-mots` (2 cas : dix locales, deux mots en capitales, jamais le même ; chaque page compare au mot de SA locale, aucun mot en dur). Gardes i18n (parité 6 690 × 10, écriture) vertes. **Réserve** : les huit mots sont un choix de session, pas des locuteur·rices (nl, el : E2) — « corrige-moi », c est une ligne par locale ; et le manuel lecteur, hors dépôt, cite encore l ancien mot (à reprendre avec J9). `32edb185`, CI verte, en production. |
| H11 | 2026-09-24 | **Clos le 24/09 sur pièces.** Migration `20260924194818` (`f4a531ce`), engendrée par le mapping du sync lui-même (`isSyncable` + `toRow` importés de `scripts/ficedl_thesaurus_sync.mjs`, jamais recopiés) depuis `docs/journal/ficedl/ficedl_thesaurus_2026-09-03.json` : 621 termes (227 sujets, 234 géo, 1 mixte, **159 dates**), les deux fiches sans libellé ni H1 écartées (`mot532`, `mot538`), idempotente — l UPDATE ne touche qu une ligne dont le contenu diffère. **Comparée ligne à ligne à la production avant de pousser** (md5 par `mot_id`, 621 lignes) : 619 identiques, deux différaient — `mot136` et `mot137` portaient au dépôt le drapeau `hors_liste_cira` que la production n avait pas, parce que le sync du 03/09 (11 h 07) a précédé la ré-aspiration commitée à 13 h 17 (`2f314f15`). Le dépôt est la référence : la production a reçu ces deux drapeaux au déploiement, rien d autre. **Vérifié en production après la CI** : 621 termes, 159 dates, empreinte de la table `8d1e585e67e3c5f7059532a41adabcd0` = celle du rejeu local = celle que la suite imprime ; 332 migrations = 332. Suite `ficedl_termes_tests` (7 cas : comptes, un seul `harvested_at`, aucun terme sans libellé, empreinte, et un alignement vers un descripteur `dates` qui passe la clé étrangère — le sujet est créé par le test, aucun n existe en CI). `sql-tests` et `rejeu-image` verts. Le jour où le sync sera rejoué en production, la suite rougira : il faudra régénérer la migration (script au scratchpad de la session, recette dans l en-tête de la migration), pas ajuster le test. |
| F4 | 2026-09-24 | **Clos le 24/09 : le dernier critère est tenu par Xavier.** Mesuré en production le 24/09 : `loan_cycle_notifications` porte trois envois, tous sur l emprunt 84 (BLMF) — l invitation à une note de lecture le 10/09 à 09 h 15, **le rappel J-3 le 18/09** et **le rappel du jour de l échéance le 21/09**, une fois chacun (unicité item × moment). Xavier confirme le 24/09 que ces courriels sont **arrivés, dans la langue de la personne**. Les interrupteurs commandent des envois réels depuis le 31/08 (EF `notify-loan-cycle`, cron quotidien 9 h 15 UTC, suite `rappels_echeance_tests`). Ce qui n est pas dans cette clôture : le J+7 (aucun retard depuis le 31/08 — l emprunt 84 est rendu) ; il partira au premier retard réel, et la table le dira. |
| G14 | 2026-09-24 | **Clos le 24/09 sur pièces.** Xavier a relancé la personne lui-même (décision du 21/09) ; lu en production le 24/09 : l invitation du 30/08 est passée à **`accepted`** avant son expiration du 29/09. Les deux autres invitations du 01/09 : une acceptée, une en attente de ratification (expiration 01/10). Ce que l épisode dit, à verser à **G1** : l invitation par courriel n a pas suffi, la relance humaine oui. |
| E14 | 2026-09-24 | **Clos le 24/09 au soir, sur pièces.** Livré en trois commits (`44ced60d`, `4dfb9d47`, `1145b32f`), déployé, et **emprunté pour de vrai** : à 22 h 55 (heure de Paris), Xavier a déposé le signalement `35a5dc22` depuis `/login`, sans session, et reçu le courriel des admins (PDF versé dans la séance) ; en base, la ligne de file est passée à `sent` au premier essai, accusé de réception compris. *Critère 1* (déposer un signalement depuis n importe quelle page sans rien connaître de Codeberg) : tenu, par ce geste. *Critère 2* (courriel aux admins, file avec un statut, un même défaut signalé cinq fois ne fait pas cinq courriels) : tenu — courriel reçu, file `/relatar-problema/fila`, doublon ouvert rendu tel quel (banc `relatar-banc`). *Critère 3* : dix locales, page titrée, formulaire au clavier (champs étiquetés, `role=alert`/`status`) ; **le rendu sur téléphone n a pas été regardé** — les champs sont en pleine largeur et en 16 px, sans grille, mais c est une lecture du code, pas une mesure. Deux corrections nées du premier signalement réel : le courriel ne cite plus « (E14) », qui ne dit rien à qui le lit (remarque de Xavier), et une personne sans compte n envoie plus « Bibliothèque : AnarBib » — c était le contexte par défaut de `LibraryContext`. Deux gardes avaient mordu avant : la CHECK de la table Altcha (rejeu local) et `salle_des_machines_tests` (privilège par défaut de `public`, fermé par `20260924204107`). La route a d abord dit « signalar », qui n est d aucune langue : `/relatar-problema`. |
| F14 | 2026-09-24 | **Clos le 24/09 : le dernier critère est tenu par Xavier.** Le code est en production depuis le 22/09 au soir (les deux secrets de Reply-To retirés, `register` retombe sur l expéditeur, l adresse humaine `anarbib@proton.me` écrite dans le corps des courriels concernés, dix langues, garde `reply-to-meme-domaine`). Xavier a refait l épreuve : une inscription vers une adresse Riseup, et le courriel de bienvenue est **arrivé en boîte de réception principale** (plus dans les indésirables). Nuance honnête : l en-tête `X-Spam-Status` n a pas été relu ligne à ligne ; c est l arrivée en boîte principale qui fait preuve ici. |
| F11 | 2026-09-24 | **Clos le 24/09 : le dernier critère est tenu par Xavier.** Les deux gestes de code étaient faits le 22/09 (les 27 fonds sans couleur de texte corrigés, garde `mails-fond-et-couleur` ; `color-scheme: dark` déclaré dans les huit documents, `MAIL-Q7`). Xavier a regardé les courriels dans son client, en thème sombre et en thème clair, dont les deux nés le 24/09 (l alerte de signalement et l accusé de réception) : **tout se lit**. Aucune capture versée au dépôt : la parole de Xavier fait preuve. |
| I15 | 2026-09-24 | **Clos le 24/09 au soir : les trois critères tenus.** Xavier a créé le secret Forgejo `VITE_SUPABASE_PUBLISHABLE_KEY` (valeur : la clé publiable, publique par nature) ; `ci.yml` le lit (`f0a88461`) ; le build suivant (run 7258461, vert) a publié un `catalogue-snapshot.json` généré à 20 h 57 UTC — la clé est passée. Vérifié ensuite sur Codeberg (`9e36871c`) : plus aucun workflow ni aucun code ne lit `VITE_SUPABASE_ANON_KEY` (seul le commentaire historique de `ci.yml` le nomme). **Xavier a supprimé l ancien secret** le 24/09. Le piège reste écrit dans `ci.yml` : `prebuild` sort en 0 si la variable manque, la date du snapshot servi est la seule preuve d un build sain. |
| E19 | 2026-09-25 | **Clos le 25/09, sur un critère réécrit par Xavier.** Le premier « fini quand » de la fiche — « les trois cartes visibles sans défiler sur un écran de portable » — était **intenable par construction** : l en-tête, le bandeau, l identité de la personne et les vidéos tutos précèdent l onglet, quoi qu on y déplace (constat de Xavier, 25/09). **Critère réécrit par Xavier le 25/09** : *les trois cartes (export, notifications, lettre) viennent juste après le profil, avant tout le reste de l onglet.* **Tenu** depuis `e09bf16a` (24/09) : profil seul en haut, puis les trois cartes côte à côte (`repeat(3, minmax(0, 1fr))`, une colonne sous 900 px), puis « Ma bibliothèque », puis l adresse (formulaire coupé en deux le 21/09, `26e2421f`), puis ce qui se lit, et « Supprimer mon compte » seule, en dernier, en rouge. Gardé par le banc `conta-decisions-sous-le-profil` (7 cas : ordre des blocs, une seule grille, pistes `minmax`, plus de colonne à droite, chaque geste garde son appel). Vérifié en production le 24/09 à 23 h 30 (`AccountPage-Df-sqleY.css`, `AccountPage-Cwx3hTeR.js`), vu par Xavier sur son portable. Les autres critères : 360 px sans débordement (mesuré dans un harnais le 20/09 à 360, 700, 920 et 1 366 px, trois langues) ; suppression en dernier (banc). **Hors de cette clôture** : la capture de la page dans le Manuel v5, qui vit hors du dépôt (à reprendre avec **J9**). |
| B24 | 2026-09-25 | **Clos le 25/09, les deux critères tenus.** *(1) Une seule copie, une garde.* Dans le dépôt de la vitrine (`codeberg.org/anarbib/pages`, `d4a110f`) : l adresse du projet et la clé publiable vivent dans **`js/config.js` et nulle part ailleurs** (une rotation = une ligne) ; `explorar.js` les lit dans `window.ANARBIB_CONFIG` ; les dix pages `/<lang>/explorar/` chargent `config.js` avant lui et ne portent plus aucun attribut de clé. **`tools/garde-cles.cjs`** refuse tout JWT legacy et toute clé secrète dans le dépôt, toute clé publiable hors de `config.js`, tout attribut `data-supabase-key`, et une clé qui ne commence pas par `sb_publishable_` — **éprouvée rouge** sur une clé remise dans le HTML et sur un JWT dans `config.js`, verte sur l état livré (210 fichiers lus). Elle tourne au pre-push, dont une **copie versionnée** vit désormais dans `tools/hooks/pre-push` (README : l installer dans un clone neuf). Vérifié dans un navigateur (`/fr/` et `/el/explorar/` : trois bibliothèques, console sans erreur) puis **en production** (`anarbib.org/js/config.js` servi, `/fr/explorar/` charge `config.js`, zéro attribut de clé). *(2) L inventaire écrit.* `CONTRIBUTING.md` de l application (§ « Rotation d une clé », fr et en) nomme chaque lieu de chaque clé — secret Forgejo, vitrine, fonctions, poste — et la relecture des `edge_logs` après rotation (le `referer` désigne le lieu oublié). B19, clos le 15/09, porte l inventaire du 08/09. |
| F12 | 2026-09-25 | **Clos le 25/09, les trois critères tenus.** Livré par `2a5d2642`, migration `20260924214108`. *(1) Un envoi refusé est retenté seul, un nombre borné de fois, sans doublon.* Le verdict (`outbox-verdict.ts`) rend QUI a refusé ; les huit handlers des cinq files concernées (team — avec network, assembleia, library_profile —, lettre, gazette, cartography, bug_report) l écrivent dans `refused_recipients` ; un trigger programme le prochain essai (15 min, 1 h, 6 h) ; le cron `anarbib-notify-outbox-retry` (toutes les 15 min) reposte à `notify-event` avec « seulement » ; `core/dispatch.ts` enveloppe le handler dans la restriction (`transport/restriction.ts`, AsyncLocalStorage) et `safeSendEmail` saute tout destinataire déjà servi en le comptant comme servi. Prouvé par le banc `courriels-rejeu-banc` (6 cas : refus partiel nommé, rejeu qui ne sert que le refusé et passe à « sent », refus persistant, pas de fuite de la restriction, deux dépêches concurrentes). *(2) État final et raison ; la sonde distingue.* Après quatre essais la ligne passe en `abandoned` ; `api.fn_outbox_abandonnees` / `api.fn_outbox_acquitter` (admin réseau, raison obligatoire) l en font sortir en `skipped`, raison écrite ; `fn_healthcheck_notifications` compte à part `dont_en_rejeu` et `dont_abandonnees` (corps réel, deux remplacements comptés). Suite `courriels_rejeu_tests` (9 cas). *(3) Le cron est dans `fn_crons_attendus()` et dans la suite des crons* : 39 jobs ; la suite résout désormais aussi les appels `private.` (0 commande non vérifiée). **Éprouvé avant de pousser** : `node:async_hooks` sous Deno 2.7 et dans le binaire `edge-runtime` du conteneur local ; 111 suites SQL et 859 tests verts. **En production le 25/09** : 335 migrations = 335, cron actif, colonnes sur les cinq files, sonde `ok`, fonctions privées fermées, sept fonctions d envoi sondées (démarrage normal : 401, 400, 422, 200), et le premier passage du cron, le 25/09 à 00 h 15 (heure de Paris), a réussi en 46 ms (aucune ligne en échec à reprendre). Verdicts des deux RPC à l audit (0029 = 424). Hors périmètre, dit dans la migration : `authority_proposal_notification_outbox` (son handler ne lit pas le verdict) et les deux files `painel_*`. |
| I22 | 2026-09-25 | **Clos le 25/09 — tranché « interdire et contrôler » (décision de Xavier), le critère tenu.** La ligne `DOC-DEPLOY-1` ne porte plus l'écart ouvert : la note ⚠️ du §30 devient 🔵 « tranché le 25/09 », REGISTRE 0.45. **Le contrôle n'est pas celui que l'item proposait** : une version sans fichier au dépôt n'aurait rien vu, puisque le fichier de l'écart du 07/09 y était, sous la version inscrite. La signature retenue est `supabase_migrations.schema_migrations.created_by` — un auteur quand la migration passe par l'API de gestion (MCP, tableau de bord), rien quand c'est la CI : lu sur les 335 versions de la production le 25/09, et **confirmé par la migration du contrôle elle-même**, appliquée par la CI sans auteur. Migration `20260925082749` (`d4fa5152`) : `fn_healthcheck_deploiement()` ouvre l'incident `deploiement` sur toute version signée absente de `deploiement_ecarts_acquittes`, qui ne se remplit **que par une migration versée au dépôt** — l'acquittement passe lui-même par la CI. Le bilan ne porte jamais l'auteur. **Treize écarts antérieurs acquittés nommément**, chacun avec le commit qui le trace, **dont deux jamais tracés** (`20260922185953` le 22/09, `20260924180538` le 24/09 ; fichiers au dépôt sous la même version) ; 44 d'avant le 20/08 en bloc. Suite `deploiement_tests` (9 cas, dont le bilan sans auteur) ; garde vitest `health-probe-kinds-check` : tout kind inséré par health-probe doit figurer dans la dernière CHECK (éprouvée rouge). **En production le 25/09** : 336 migrations, contrôle `actif` et vert, 57 écarts acquittés, sonde fermée à anon et authenticated, et health-probe l'a lue au tour de 08 h 50 UTC (`"deploiement": true`). Angle mort dit au registre : une `db push` lancée à la main depuis un poste. |
| J2 | 2026-09-25 | **Clos le 25/09, les deux critères tenus.** *(1)* Le tableau de `INDEX.md` court sans trou du v8 au v34 : 36 lignes pour les 36 fichiers d'`archive/`, plus la version courante (relu le 25/09). *(2)* **`DOC-ARCH-1`** au REGISTRE (0.45, décision de Xavier : « ne rien renommer, écrire la règle ») : le préfixe `-archive-` marque les neuf fichiers des lignées d'avant la fusion du 20/05, dont les numéros (v8, v10 à v15) ont été repris par la lignée unifiée — c'est lui qui les distingue ; toute version archivée depuis garde son nom d'origine, le dossier suffit et les liens restent valides. La note de l'INDEX le dit et renvoie au registre. L'en-tête de l'INDEX date désormais son « 90 items » (« à l'écriture ») au lieu de dériver. |
| H13 | 2026-09-25 | **Clos le 25/09, le critère tenu.** Les deux fichiers sont au dépôt (`e0fbb024`), dans `docs/journal/ficedl/` : ceux du 09/09 emportés à Bologne — 28 descripteurs, deux schémas en nœuds anonymes, URI `?motNN`, `broader` « généralités » confirmés, « art : courants » en `skos:Collection` provisoire —, sha256 vérifiés contre les trois copies du disque E: (le disque F: de la mémoire n'était pas branché). **Régénérables par une commande documentée** dans le README du dossier : `node scripts/ficedl_thesaurus_esquisse.mjs docs/journal/ficedl/ficedl_thesaurus_2026-09-03.json docs/journal/ficedl` — copie du `build_esquisse.mjs` du paquet hors ligne, sortie **identique octet pour octet** sur l'aspiration du 03/09 (identique elle aussi à celle du paquet). Le CSV (CRLF + BOM) est sorti de la conversion des fins de ligne pour le rester après un clone ; la garde vitest `ficedl-esquisse-regenerable` régénère et compare à chaque CI. La note du 28/08 est versée à côté, avec les trois points où elle est dépassée (26 descripteurs, un seul vocabulaire, `/id/motNN`). |
| H9 | 2026-09-25 | **Clos le 25/09 au soir, les trois critères tenus.** Livré par `f67ff3d9` (migration `20260925084523`) : la RPC accepte les cinq relations, `skosExport.js` passe par la table `SKOS_MATCH` et ne publie plus rien par défaut, la page-sujet et l'éditeur de la coordination lisent `ficedlMatch.js` — l'éditeur n'offrait jusque-là **aucun** choix de relation —, cinq clés dans les dix locales (en de/nl, « close » ne porte plus le mot de « related »). *(1)* **Xavier a posé depuis l'écran** (capture du 25/09, 21 h 17) un alignement « plus large » : Anarchosyndicalisme (sujet 17) → `mot286` « syndicalisme révolutionnaire », lu en base (`match_type = broad`, 19:17 UTC) ; la page publique `/thesaurus/anarcossindicalismo` l'affiche « PLUS LARGE » à côté de l'« EXACT » de `mot272` (lu dans le navigateur) ; l'export réel `api.thesaurus_export_v1`, appelé en anonyme, passé dans le `skosExport.js` livré, sort `skos:broadMatch <…?mot286>` en Turtle comme en JSON-LD. *(2)* `npm test` vert : 878 tests, dont `skos-relations-h9` (15). *(3)* Le 4.2 de `20260907172508` est inversé dans `20260925084523` le même jour, et annoté là-bas. Suite SQL `alignement_ficedl_relations_tests` (6). Ouvre **H10**. |
| H10 | 2026-09-26 | **Clos le 26/09, les deux critères tenus.** Relevé du matin : 99 liens (44 `exact`, 54 `close`, 1 `broad` posé à l'écran le 25/09), aucun vers la facette `dates`. **Relecture ligne à ligne** (`CONV-EXEC-3`) consignée dans `docs/journal/arbitrages/RELECTURE_alignements_ficedl_2026-09-26.md`, **fiche validée en bloc par Xavier le 26/09**. *(1) Chaque lien porte une relation choisie* : sur les 54 `close`, 19 deviennent « plus large », 21 « plus étroit » (les rubriques composites de Solidaires), 5 « associé », 9 sont confirmés ; sur les 44 `exact`, 6 étaient trop affirmés (3 « plus large » — le descripteur couvre les deux faces, 3 « proche » — une révolution n'est pas une période), 38 sont confirmés nommément dans la fiche. *(2)* **Huit alignements vers la facette `dates`** (Commune ×2 → 1871, Mai-Juin 1936 → 1936, Mai 68 → 1968, révolution russe ×2 → 1917, révolution allemande → 1918 et 1919 — 1789 et 1848 n'existent pas dans la facette, qui commence en 1868), plus trois meilleures cibles trouvées en chemin (Proche et Moyen-Orient, Allemagne 1917-1921, conseils ouvriers). Migration `20260926182521` (`e38f7310`) : clé (slug, `mot_id`), un lien n'est changé que s'il porte encore la relation relevée, vérification des 71 décisions une à une. **Éprouvée avant de pousser** : en lecture seule contre la prod (71/71 visent juste, 0 écart d'état), sur copie jetable du banc (71 tenues, idempotente, refuse un lien modifié entre-temps en le nommant). **En production le 26/09** : migration appliquée par la CI (338 migrations, sans auteur, sonde de déploiement verte), **110 liens — 38 exact, 14 close, 26 broad, 22 narrow, 10 related**, exactement la répartition attendue par la fiche ; **8 vers la facette dates** ; l'export anonyme réel, passé dans `skosExport.js`, sort par exemple Commune de Paris en `skos:broadMatch` vers 1871 et la révolution russe en `skos:closeMatch` vers 1917-1921 et `skos:relatedMatch` vers 1917. |
| H14 | 2026-09-26 | **Clos le 26/09 au soir, les deux critères tenus.** *(1)* PMB 8.1.1.1 (archive officielle, somme SHA256 vérifiée) tourne sur le poste en deux conteneurs (projet compose `pmb-banc`, PHP 8.3 + Apache, MariaDB 10.11 réglée selon les pré-requis PMB 8.1), recette **sans clic** au dépôt sous `tests/pmb/banc` : installation par POST vers `install_rep.php` (sa branche « base existante » — le mode création fabrique `bibli@localhost`, injoignable d'un autre conteneur), montée du schéma v5.34 → v6.03, **export** et **import** pilotés par HTTP (`exporter-pmb.mjs`, `importer-pmb.mjs`) — commits `d8695a68`, `5bfa50ff`. *(2)* Fixtures **exportées par PMB lui-même** sous `tests/pmb/fixtures` : le jeu de test PMB (50 notices, 33 exemplaires 995) en UNIMARC ISO 2709, en XML MARC et dans le XML propre à PMB ; 14 **cas difficiles** (zine, grec, cyrillique, arabe, chinois, collectivité, congrès, rôles, tomes, trois exemplaires, périodique et article, 606 à subdivisions) importés dans PMB puis réexportés. **Latin-1 : pas par PMB** — PMB 8.1 n'installe qu'en UTF-8 (`install_rep.php` force `utf-8`) ; la variante latin-1 est transcodée par `yaz-marcdump` (longueurs ISO 2709 recalculées), et le dit. Ce que PMB perd en réimportant (`func_bdp`) est consigné dans `tests/pmb/README.md` pour **H24**/**H27**. |
| C8 | 2026-09-26 | **Clos le 26/09, les deux critères tenus** (demande de Xavier : « compléter l'ensemble des fiches auteurs », carte blanche sur la méthode). Deux phases, chacune par une migration de données passée par la CI : **Wikidata** (`20260926193111`, `b418e149`) — 607 fiches ; **Library of Congress** (`20260926200208`, `abaa4755`) — 288 fiches liées, 90 complétées. Règles et échantillons dans `docs/journal/operations/enrichissement-autorites-2026-09-26/` (README + `decisions.csv`, `decisions-lc.csv`) : nom identique ET aucune contradiction ET dates concordantes ou deux signaux indépendants (Wikidata), titre de l'auteur au catalogue cité dans la notice ou dates concordantes (LC) ; justesse mesurée sur échantillon aléatoire : 60/60. On ne remplit que le vide, trace par fiche dans `external_ids` (`wikidata_releve`, `lc_releve`). *(1) Couverture en identifiants externes* (Wikidata, VIAF, ISNI ou LC), mesurée en production le 26/09 : **51 %** de toutes les autorités, **78 %** de celles à trois livres ou plus, **86 %** à cinq, **96 %** à dix — le seuil de 20 % est dépassé partout. *(2) Aucun pseudonyme militant remplacé par un nom civil* : aucune forme de nom n'est touchée (forme retenue, forme de tri, variantes) — par construction, et c'est la garde de la migration (id ET forme retenue du relevé). Au passage, la langue d'écriture a reçu sa colonne (`writing_language`, `20260926191225`, `6bcb3fa5`) : 503 fiches renseignées. **En production le 26/09** : 344 migrations, sonde de déploiement verte ; 614 fiches liées à Wikidata, 288 à la LC ; restent 716 fiches sans année de naissance. Les formes variantes (troisième constat de la fiche) n'ont pas été enrichies : Wikidata en porte, mais une variante mal choisie brouille la recherche — à faire à la main si le besoin se montre. **29/09** — Ce qui n'a pas été écrit reste à relire à la main, cas par cas, dans `decisions.csv` (Wikidata : 96 homonymes ambigus, 70 contradictions avec la fiche, 88 fiches à un seul signal, 39 non corroborées) et `decisions-lc.csv` (LC : 27 contradictions, 345 homonymes sans titre commun) ; la phase IdRef du 27/09 (C4) laisse `decisions-idref.csv` (50 contradictions, 173 non corroborées). Une valeur douteuse est en base : E. M. Cioran, `writing_language = 'ro'` (posée par `20260926193111` ; langue maternelle, il écrit en français après 1949), qu'aucune migration ne corrige — à reprendre à la main. |
| C11 | 2026-09-27 | **Clos le 27/09 — critères 1 et 3 tenus sur pièces, le 2 laissé en pratique continue (décision de Xavier).** Relevé du matin, par les fonctions mêmes de l'assistant : 9 groupes de tomes, 90 paires d'œuvres scindées, 10 paires « à décider », 175 notices MLEG sans matière. Fiche de propositions validée en bloc par Xavier (`docs/journal/arbitrages/ARBITRAGE_file_opac_par_oeuvre_2026-09-27.md`). **Partage des gestes** : une première migration qui appliquait tout sous l'identité de Xavier a été refusée par le garde-fou de l'environnement — un verdict ne porte le nom de quelqu'un que s'il l'a posé ; les fusions et réunions de tomes ont donc été faites par Xavier dans l'assistant (plusieurs décisions divergent de la fiche, elles font foi et sont écrites au journal), le reste par deux migrations en leur propre nom : `20260927112143`, `ee07f79c` (*O Capital* écarté des tomes ; les six volumes thématiques de *O Homem e a Terra* réunis, le thème en volume ; une matière existante pour six catégories MLEG, deux en note seule — THES-4) et `20260927114232`, `6f4d7b89` (sept familles de tomes réunies en volumes sur décision de Xavier ; Peirats rendu à la file en alignant l'éditeur, la fusion des œuvres l'ayant masqué). Deux constats faux corrigés en route, au journal (`ccc4c4f9`) : la paire 1510/1511 ne quittait pas « À décider » d'elle-même, et le renommage d'une œuvre fait surgir des paires neuves (*Textos escolhidos*, un troisième *Living my Life*) — tranchées par Xavier. *(1)* **Mesuré en production le 27/09 : « Volumes » 0, « Œuvres scindées » 0, « À décider » 0.** *(3)* Les 175 notices MLEG ont chacune une décision écrite : matière posée (140) ou note conservée par choix (35, *Transversais* et *Ciências Humanas*) ; aucune matière créée. *(2)* Non mesurable — rien n'enregistre qu'une œuvre a été ouverte ; les titres automatiques sont passés de 1 452 à 1 676 (187 œuvres), les regroupements ayant créé ou renommé des œuvres que la pré-traduction a complétées. Leur relecture reste une pratique continue, par la file des titres de l'Atelier : décision de Xavier, le 27/09. |
| C7 | 2026-09-27 | **Clos le 27/09 — critères 1 et 2 tenus sur pièces, le 3 levé par décision de Xavier.** 1 317 notices sans sujet lues une à une (88 % : import Zotero de la BTL, titre seul) ; 851 propositions dans le vocabulaire existant, fiche `docs/journal/arbitrages/C7_propositions_matieres_2026-09-27.md` validée A + B par Xavier ; migration de données `20260927124038` appliquée par la CI : +851 notices, +1 180 affectations, 89 matières avant comme après (THES-4). *(1)* **Mesuré en anonyme : 2 167 / 2 633 notices indexées, 82,3 %** (50,0 % le matin). *(2)* `pierre-joseph-proudhon` n'existe plus ; `anarcocomunismo` actif, « Communisme libertaire », `broad` → « anarchisme », 3 notices. *(3)* Sept des huit sujets sont rattachés à un terme FICEDL plus large, `abolicionismo-penal` est `related` → « prison » (H10). Les porter à la fédération n'est plus demandé : **décision de Xavier, le 27/09, « si ça ne crée pas de fork »** — et il n'y en a pas, mesuré le jour même : la copie du thésaurus compte 621 termes, tous moissonnés à la source le 03/09, aucun terme ajouté localement ni ressemblant aux huit, aucun lien `exact` vers eux ; les huit vivent dans le vocabulaire AnarBib et ne touchent la FICEDL que par des liens SKOS. Restent 466 notices hors vocabulaire (littérature générale, philosophie, sciences sociales, esperanto, spiritualité, histoire du Brésil) : l'étendre serait un autre item. |
| C6 | 2026-09-27 | **Clos le 27/09 — vérifié à l'écran par Xavier, connecté (« vérifié, fonctionnel »).** Les trois assistances de la spec des conventions (§7) livrées le même jour. *§7.2* bouton « Normaliser la casse » sous le titre de la notice (`b9177403`) ; **sur remarque de Xavier** (« lE tRuc qui FAIT cHIER », bouton grisé : la première version n'abaissait que les mots-outils), il applique depuis `1782dfcb` la casse de la langue selon §4.1 — casse de phrase pt/es/fr/it/ca/eo/nl/el, title case en anglais, mots-outils seuls en allemand, sigles et chiffres romains figés, aperçu où chaque mot se clique pour les noms propres. *§7.1* assistant du point d'accès sous le nom d'une personne (`0c3bb62f` : Confirmer, Corriger mot par mot, Nom unique ; variante hispanique seulement offerte) et, **à la demande de Xavier**, la même normalisation de casse pour le nom (`8c73b850`, CONV-1 : « osvaldo BAYER » → « Osvaldo Bayer », particules, initiales, rangs, noms composés et élidés). *§7.3* cron du lundi `anarbib-conv-file-alimenter` (`7eb72630`) qui passe les cinq semeurs de la file de vérification, bac à sable de formation exclu ; premier passage en production : 4 lignes. Critères : (1) trois dispositifs, aucun bloquant ; (2) chaque proposition refusable, original conservé (aperçus, annuler après coup, la file s'écarte) ; (3) libellés dans les dix locales. Limites laissées : le lot « titre_casse » de l'Atelier (171 titres) propose encore l'ancienne forme (mots-outils seuls) ; la casse des collectivités n'a pas d'outil ; `name_lang` (CONV-6) n'est pas au formulaire. **Les trois limites traitées le soir même, à la demande de Xavier.** (a) Un dictionnaire des noms propres attestés (`src/lib/nomsPropres.js`, 1 378 mots et 719 phrases, engendré par `scripts/noms-propres-attestes.mjs` depuis le catalogue, les patronymes, les pays et les collectivités ; mots communs écartés) : le bouton ne les abaisse plus ; la règle a son miroir SQL `fn_conv_casse_titre` (`20260927154351`, parité 26/26 au banc et 173/173 sur les titres réels, par empreinte) qui fait la proposition du lot « titre_casse » ; les 171 propositions en attente refaites (`20260927163827`, fiche `C6_propositions_casse_file_titres_2026-09-27.md` vue par Xavier), 0 écart en production. (b) `name_lang` se saisit (`20260927160008`, datée après B29 qu'elle prolonge) et pilote la découpe (it/af/en particule gardée, fr article, es deux noms). (c) La casse des collectivités (`d421774d`) : mots principaux, français en casse de phrase, sigles de toute longueur gardés. |
| B10 | 2026-09-27 | **Clos le 27/09 au soir, sur pièces : les trois critères tenus, et trois gardes pour qu'ils le restent.** *(1) Policies* — les avis `multiple_permissive_policies` sont résorbés (**25 → 0**, avis relu en production le 27/09). Une permissive par (rôle, commande) sur les 25 tables (`20260927180000`), puis chaque OU ordonné : ce qui ne dépend pas de la ligne d'abord, la lecture publique ensuite, le staff ligne à ligne en dernier (`20260927180030`). Rien n'a changé de qui voit quoi : empreinte md5 des clés visibles, pour `anon` et chacun des 20 comptes réels, **identique sur les 25 tables** avant, après la passe 1 et après la passe 1 bis. Et l'ordre paie : `count(*)` sur `books` sous un compte lecteur **208 → 90 ms**, bibliothécaire 209 → 89 ms, admin réseau **39 → 1,4 ms** ; `exemplares` 177 → 100 ms (lecteur), 40 → 0,9 ms (admin) ; anonyme inchangé. Garde : `policies_permissives_uniques_tests` (33 tests : aucune paire dans aucun schéma, liste fermée vide ; la lecture publique, désormais en deux copies, doit rester identique ; trente lectures et écritures réelles). *(2) Clés étrangères* — **21 indexées** (`20260927180100`) : toutes celles dont le parent est supprimé en exploitation — du 02/09 au 27/09, 146 œuvres, 37 autorités, 21 notices et 2 comptes supprimés, et chaque brouillon purgé coûtait deux parcours complets de la plus grosse table d'import. La liste assumée de B21 passe de **38 à 17**, règle écrite en tête (codes `catalog_ref_*`, bibliothèques, partenaires : des parents qui ne se suppriment pas). *(3) Index* — **22 retirés, raison écrite pour chacun** : 10 redondants jamais empruntés (`20260927180200`) et 12 sans aucun lecteur sur le chemin d'écriture (`20260927180300` : 6 sur `books`, qui en portait 27, 4 sur `book_drafts`, les 3,5 Mo de `idx_shp_endpoint`, un doublon ; son premier essai, tombé dans le `pg_dump` de la sauvegarde hebdomadaire, a été annulé sans rien appliquer et rejoué au run suivant). Garde : `index_redondants_garde_tests` (plus de nouveau redondant ; les 22 redondants empruntés, nommés avec leurs compteurs, se retirent sur mesure). Les 108 index sans lecteur restants sont inventoriés un par un, avec origine et verdict (`docs/journal/audits/AUDIT_performance_B10_2026-09-27.md`). Nés des constats : **B31** (trois lectures anonymes lèvent une erreur au lieu de rendre zéro ligne), **B32** (le catalogue public relit toute sa vue matérialisée à chaque page, et calcule la visibilité ligne à ligne), **B33** (la recherche ne peut emprunter aucun de ses index trigramme), **B34** (l'effacement de compte ne traite pas le journal du catalogue), **I28** (le hook `pre-commit` ne tourne pas dans les worktrees WSL). **Écart tracé** : les cinq migrations enfreignent `DOC-DEPLOY-4` (heure ronde, datées dans le futur), sans collision ni effet d'ordre — audit §7. |
| D7 | 2026-09-27 | **Clos le 27/09 : décision écrite au REGISTRE (section `ARCH`), avec sa raison** — son seul critère. **Décidé par Xavier** : un **modèle archivistique complet dans AnarBib** (niveaux ISAD(G) fonds, sous-fonds, série, sous-série, dossier, pièce ; producteurs en autorités ISAAR(CPF) ; export EAD dès la première version — `ARCH-1`), un **niveau de description variable selon le fonds** (`ARCH-2`), des **conditions d'accès par niveau dès la première version** (`ARCH-3`), présentés pour avis à DIRA, au CIRA et au FICEDL avant tout code (`ARCH-4`). Réalisation : **D8**. |
| I3 | 2026-09-27 | **Clos le 27/09 — les quatre tests passent, et trois de plus.** Le routeur `supabase/functions/main/index.ts` lancé seul dans `supabase/edge-runtime:v1.74.0` (la version de `deploy/.env.example`), fonctions et `config.toml` montés comme dans `deploy/compose.yml`, secret JWT tiré au hasard pour l'essai : il démarre (40 fonctions dispensées, 54 montées, aucune dispense orpheline) et décide juste — nom inexistant 404, fonction protégée sans jeton 401, avec un jeton valide la fonction s'exécute (405, sa propre réponse à un GET), jeton signé d'un autre secret 401, jeton expiré 401, chemin sans `/functions/v1` 401 ; une fonction dispensée (`health-probe`) n'est pas bloquée, son travailleur est lancé — il échoue ensuite (500, « supabaseKey is required ») faute de base et de secrets dans le conteneur isolé : **répondre 200 relève de la répétition complète, I21**. *Critère 2* : les 14 fonctions qui exigent un jeton (`attach-received-asset`, `audio_fingerprint_lookup`, `authority_lookup`, `author_portrait_lookup`, `catalog_metadata_lookup`, `cover_lookup`, `deposit-fonds-direct`, `export-catalog-lote`, `export-fonds-bundle`, `geocode`, `mail-i18n-test`, `notify-library-invitation`, `probe-partner-catalog`, `revoke-digital-asset`) sont toutes appelées par l'application avec une session ou, pour `geocode`, le jeton anonyme de la pile auto-hébergée : voulu. L'essai est au dépôt, rejouable : `deploy/scripts/essai-routeur-main.sh` (docker, openssl, curl ; 7/7). |
| C9 | 2026-09-27 | **Clos le 27/09 — le travail de main qui restait est fait, sur pièces.** *O5/O6* livrés le 03/09 (déjà écrit à la fiche). *O2* : mesuré le 27/09, plus aucune collectivité « à revoir » dans la file (les deux ont été tranchées entre-temps). *O8* : le verdict « pas de scission avant la quatrième » étant dépassé (douze fiches doubles au 03/09), une fiche « qui devient quoi » (`docs/journal/arbitrages/C9_scissions_des_fiches_a_plusieurs_personnes_2026-09-27.md`) a été **validée par Xavier** (« tout, sauf 4955 »), avec, sur sa parole, « Sorel, G. » réuni à « Sorel, Georges ». Migration `20260927193940` (`1948b78d`), en son propre nom, appliquée par la CI : **dix fiches scindées** — six personnes reliées à leur fiche existante (Gurucharri, Ibáñez, Philopat, Biehl, Bookchin, Sacchetti), deux fiches doubles fusionnées puis supprimées, dix fiches créées —, rôle organizador pour les deux ouvrages « (orgs.) » ; Ludmila et Silvério sans « (et al.) » ni capitales ; Noir et Rouge en collectivité ; **trois fusions** au journal (`merged_by` nul, motif écrit). Recherche demandée par Xavier des « Prénom Nom & Prénom Nom » : aucune autre fiche publiée, mais **dix brouillons** (lots 8 et 63) qui en auraient créé à la publication — ils portent désormais une contribution par personne (25), reliée à l'autorité existante quand il y en a une. Vérifié en production le soir même. |
| B35 | 2026-09-28 | **Clos le 28/09 — par le schéma `private`, sur pièces.** Ouvert le matin même comme « différé » : la voie de l'item (borner la réponse au périmètre de l'appelant·e, version interne) coûtait quinze appelants et quatre politiques à raisonner un par un. Vérifié entre-temps : PostgREST n'expose que `public, graphql_public, api, ingest` (PGRST106 sur `private`). Les deux aides ont donc changé de schéma (migration `20260928105437`, commit `6721277b`, déployée par la CI le 28/09 à 11 h 12 UTC) : recréées dans `private` depuis leur définition réelle, les quinze appelants et les quatre politiques re-pointés sur leur définition réelle, les versions `public` supprimées ; `authenticated` garde EXECUTE pour les politiques et les déclencheurs, mais aucune porte RPC ne les sert plus — l'oracle est fermé sans qu'un corps change. Garde dans la migration (deux camps, plus aucun appelant, politique ni vue vers `public`), T32 de `brouillons_par_bibliotheque_tests` en continu (T30/T31 re-pointés), mutants éprouvés (sans re-pointage, sans ALTER POLICY, sans GRANT, sans REVOKE PUBLIC, appelant nu apparu). En prod après déploiement : les deux fonctions absentes de `public`, présentes dans `private`, lint 0029 à 441. Décision de Xavier du 28/09 (« fais-le par le schéma private »). |
| B13 | 2026-09-28 | Décision écrite au REGISTRE (`DOC-MIGR-2`, actée par Xavier) : on ne squashe pas. Faits recomptés : 384 migrations, 9,0 Mo (socle 2,4 Mo, données FICEDL 1,9 Mo), rejeu complet sur l'image Supabase en 2 min 17 s (run 1418), non 25 min. Un squash refait un `pg_dump` porteur du défaut `DOC-GRANT-2` ; chaque migration est une trace citée par version ; le coût dépasse le gain. Rouvrir si le rejeu passe dix minutes ou si un socle est à refaire (I2). |
| B31 | 2026-09-28 | Livré par l'autre session le 27/09 (`507afb03`, migration `20260927184425`) : 13 relations pour `anon` et 10 pour un compte sans adhésion levaient 42501 ; toutes rendent zéro ligne. Vérifié en prod le 28/09 sous `anon` : les trois tables du constat rendent 0 ligne sans erreur, politiques SELECT `TO authenticated`. Suite `lecture_accordee_sans_erreur_tests` en CI. Clos par Xavier sur ces constats. |
| B33 | 2026-09-28 | Livré par l'autre session le 27/09 (`6bdd4331`, migrations `20260927193314`/`…315` ; T1 corrigé le 28/09, `8eaa180c`). Vérifié en prod le 28/09 : `search_catalog_v1` porte le motif regexp unique ; plan à l'appui — `BitmapOr` de six `Bitmap Index Scan` sur les deux index trigramme de `authors` (4,5 ms) ; `publishers_lower_name_idx` sert la publication ; cinq index sans lecteur retirés, raison écrite : `idx_publishers_name_trgm`, `idx_authors_external_ids`, `serials_issn_idx`, `serials_uniform_title_trgm`, `idx_books_autor_trgm` ; les trois derniers ne pouvaient servir aucune requête derrière une policy (LIKE, ILIKE, `~` et `%` ne sont pas leakproof). Réserve notée : l'appel complet sous `anon` reste à 183 ms, le temps est ailleurs que dans les branches trigramme. Clos par Xavier sur ces constats. **29/09** — Au passage, `6bdd4331` fait entrer les jetons échappés dans le motif de `api.search_catalog_v1` : en production, « c++ anarquia » ou « [anarquia » levaient 2201B à l'autocomplétion. Sur base synthétique (20 000 autorités, 20 003 notices), l'autocomplétion passe de 2 182 à 125 ms par appel. Garde : `recherche_index_trigramme_tests` (8). |
| B34 | 2026-09-28 | Livré par l'autre session le 27/09 (`df4dcec1`, migration `20260927184954`) : `fn_delete_my_account` re-pointe l'acteur de `catalog_audit_log` et les comptes des instantanés de brouillons. Vérifié en prod le 28/09 : le corps de la fonction traite le journal ; 1 750 lignes, un seul acteur (actif), aucun uuid orphelin. Suite `effacement_journal_catalogue_tests` en CI. Clos par Xavier sur ces constats. |
| I28 | 2026-09-28 | **Clos le 28/09 : la CI tient les règles du hook, pour tout le monde, puisqu'elle tourne pour tout le monde.** `src/tests/doctrine-migrations-garde.test.js` (dans `npm test`, donc au job `app` de chaque push) : 10 tests — nom à 14 chiffres ; version unique (une collision, c'est une migration sautée sans erreur) ; pas d'heure ronde depuis le 31/08, hors une liste close des 15 déjà versées, dont la garde vérifie qu'elles existent ; pas de date dans le futur (dix minutes de tolérance) ; la doctrine SQL du hook sur toute migration depuis le 31/08 (DEFINER sans `SET search_path`, nouvelle DEFINER sans `REVOKE … FROM PUBLIC`, table sans RLS, vue sans `security_invoker`, table de `public` sans `GRANT`). Livré le 27/09 par `89a2b508`, juste avant B31 (`507afb03`) et B34 (`df4dcec1`). Éprouvé le jour même : relancée à chaque rebase sur les migrations des autres sessions (capas, B30, C9), et elle a arrêté un brouillon de B33 (un `CREATE FUNCTION` dans une migration qui citait « SECURITY DEFINER » sans `SET search_path`). Le second critère est rempli par le premier : la recette de worktree n'a plus besoin du hook. |
| B32 | 2026-09-28 | **Clos le 28/09, sur pièces, à 100 000 notices synthétiques.** Trois migrations (`20260928122316`, `…17`, `…18`). *(b)* La visibilité par bibliothèque se calcule une fois par requête — `fn_visible_library_ids()` en InitPlan dans les 21 policies, la règle restant écrite dans `fn_library_visible_to_caller` : `count(*)` sur `books` sous anon 3,0 s → 52 ms, en session 29,8 s → 0,79 s ; visibilité identique (13 tables, 6 identités). *(a)* Les vues du catalogue lisent les vues matérialisées par deux vues `private` (plus d'enveloppe DEFINER par ligne), et les index sont enfin empruntés (`book_id` 2 193 parcours sur 24 requêtes réelles, `titulo`, `autor_trgm`, `ano`…). Devant la vraie vue, `catalog_works_v1` basculait en boucles imbriquées (1 ligne estimée pour 77 000 — des heures) : elle assemble son WHERE des filtres présents, lit `volume` par la vue, prend le titre de repli dans le catalogue qu'elle sert, matérialise `titres` et interdit les boucles imbriquées le temps de sa requête. Au passage, `catalog_search_ids_v1` rendait `LIMIT 500` sans ordre total : `book_id` départage. *(c)* `fn_locale_from_idioma` s'insère en ligne (plus de `SET`). Quarante parcours de l'OPAC identiques avant/après (md5 du JSON rendu). Mesures finales, anon : page par défaut 15,9 s → 1,8 s, tri auteur·rice 11,3 → 1,7 s, recherche 0,75 s, liste plate par titre 132 → 0,8 ms ; session : page par défaut 54,8 → 2,2 s. Index secondaires : tous gardés, raison écrite ; trois sans parcours (`autor_norm_trgm`, `library_slug`, `titulo_trgm`) à relire aux compteurs de production dans un mois. Le coût d'une page reste linéaire dans le nombre d'œuvres (total, tri global) : une vue par œuvre au-delà de 200 000 notices, ce n'est pas le problème d'aujourd'hui. Vérifié en production le 28/09 (déployé 14:05 UTC) : visibilité identique pour les 21 identités ; 39 parcours sur 40 identiques, le quarantième identique à ce que l'ancienne logique rend sur les mêmes données ; page par défaut anonyme 383 → 74 ms, recherche 335 → 49 ms, `count(*)` 87 → 4 ms, page en session 442 → 135 ms ; lint 0028 = 27, attendu. Audit : `journal/audits/AUDIT_catalogue_grande_echelle_B32_2026-09-28.md`. **Complété le 29/09.** Commits `46d10ed2` (b), `f4622aab` (a), `48267f27` (c) ; suite `catalogue_grande_echelle_tests` (T1-T9) ; banc versé : `scripts/loadtest/catalogue-synthetique.sql` et `catalogue-mesure.sql`. Exception assumée : `private.catalog_public_rows` et `private.catalog_network_rows` sont sans `security_invoker` (une vue matérialisée n'a pas de RLS ; nommées dans la garde T7 de `grants_herites_tests`, étendue à `private`). **Suite le soir même** : `api.catalog_facets_v1` assemble ses cinq prédicats selon les filtres présents (`cddc567b`, `20260928162102` ; 23 jeux de filtres au même md5 avant et après, en production comprise), puis sa recherche « q » devient celle de la page (`5f13ec86`, `20260928164227`, REGISTRE `OPAC-F2` : « memoria » comptait 9 éditions dans les facettes pour 52 à la page) ; `facettes_catalogue_tests` 18. Limite : les facettes restent celles du catalogue public. |
| C12 | 2026-09-28 | **Clos le jour même, 28/09 — la recherche de métadonnées montre une candidate par source, pas une par ISBN.** Constat de Xavier à l'écran : pour l'ISBN 8432302120, les pastilles disaient BNE 2, BnF 2, ICCU 2, LoC 1, Open Library 2, et la liste des candidates n'en montrait qu'une (Siglo XXI 1976, quand la notice porte 1991). Cause dans `catalog_metadata_lookup` : `dedupeAndRank` prenait l'ISBN seul comme clé — en recherche par ISBN toutes les sources rendent le même, tout se repliait sur la mieux notée — et la liste fusionnée était tronquée à `maximumRecords` (8), qui borne déjà chaque source. Correctif en deux commits (`78685511`, `16a4dcb4`) : la clé porte la source, l'identifiant de la notice chez elle (001/035, BID, clé Open Library, QID), l'ISBN, le titre, le premier contributeur et l'année — seule la même notice rendue deux fois se replie ; plus de troncature. Banc `src/tests/catalog-metadata-lookup-candidates.test.js` : le vrai fichier transpilé en mémoire, BNE et LoC stubées, cinq cas, 3/4 rouges sur le code d'avant. Vérifié en production à 16 h 16 dans l'onglet de Xavier : 7 lignes pour 7 résultats annoncés (BNE 2, BnF 2, ICCU 2, LoC 1 ; Open Library avait expiré ce coup-ci). E6 lot 3 (`LookupPanel`) n'y est pour rien : le panneau affiche ce que la fonction rend, et le défaut existait avant l'extraction. |
| H27 | 2026-09-29 | **Clos le 29/09 sur décision de Xavier.** Les trois critères : (1) la suite SQL `aller_retour_pmb_tests` tourne en CI, pertes acceptées écrites et figées notice par notice (`tests/pmb/aller-retour-pertes.json`) ; (2) l'export tiré de la base, réimporté dans un PMB 8.1.1.1 vidé de son jeu de test (`tests/pmb/bilans/`) : 46 exemplaires sur 46, 3 bulletins et 15 dépouillements sur 3 et 15, 61 responsabilités, 57 auteurs, 36 éditeurs ; les notices passent de 62 à 64, les deux pseudo-notices par lesquelles PMB exporte les exemplaires d'un bulletin et la notice propre du bulletin 278 revenant en périodiques ; (3) le tableau de couverture, engendré depuis le code et les bilans (`docs/interop/couverture-pmb.md`). Déployé le 29/09 (`2348cb86`, migrations `20260929102719` et `20260929103533`, md5 de production égal au banc). Ce qui ne revient pas — le type, la section et le code statistique des exemplaires — passe à **H29**. **Le chemin** (fiche à `66943e5a`). *(0)* Depuis le 26/09, un pont vitest (`src/tests/deno-tests-pont.test.js`, `66750198`) joue tels quels les tests Deno du parseur MARC et de l'export, que la CI ne lançait nulle part ; il exige le compte exact : 16 au départ, 75 au 29/09. *(1)* Tenu le 28/09 (`2ee5f7a7`, revue `a692a75e`, migration `20260928170909`) ; la preuve a trouvé cinq défauts, corrigés : un lot MARC ne se publiait pas (langue brute contre `books_idioma_bcp47_chk`), les noms grecs, cyrilliques, arabes ou chinois passaient pour « Collectif », les mots-clés 610/653 ressortaient en 606, l'ISSN d'un article sortait en 011, une responsabilité secondaire perdait son niveau (701/702, 711/712). *(2)-(3)* Tenus par `7dbd9f11`, puis deux revues contradictoires : `466324aa` range les périodiques avant les articles (7 → 15 articles rattachés sur 15), écrit `$r uu`/`$q u` en 995 et ne lit plus l'ISSN d'un périodique PMB comme un ISBN ; `2348cb86` dit les deux réglages de PMB qui décident de tout (« Générer les liens entre notices ? » à Oui, sinon 0 bulletin ; « Tenir compte des notices d'autorités » à Non dans PMB 8.1.1.1) et, par `20260929102719`, ne prend plus, dans un import MARC, les fascicules d'une revue ni les tomes d'un ensemble pour des doublons (58 → 64 brouillons), ni un article pour sa revue par l'ISSN ; `2f488790` (`IMP-25`) : une notice MARC sans exemplaire n'en reçoit plus d'automatique (PMB en refusait 15, sur des articles). Vérifié le 29/09 : `publish_book_draft`, `fn_flag_intra_run_duplicates` et `fn_match_partner_catalog_row` au md5 du banc, ces deux dernières fermées à anon et à authenticated, les deux EF modifiées à 401 sans jeton ; avant la poussée, vitest 1 518, SQL 149/149. |
| Couvertures : la chaîne réparée, une couverture par édition, le lot, la photo en rayon (CAPAS-1 à 6) | 2026-09-27 | **Livré le 27/09, suite le 28/09** (REGISTRE §43 `CAPAS-1` à `CAPAS-6`, `282b4e32` et `af052382` ; note `LIVRAISON_capas_2026-09-27.md`). La voie ISBN de `cover_lookup` répondait 404 chez Open Library depuis une date inconnue, et l'écran disait « aucune couverture trouvée ». **La chaîne** : URL réparée, Inventaire ajouté, titre à défaut d'ISBN (`2a80d43b` : 0 → 85 couvertures sur les 267 notices sans capa qui portent un ISBN) ; la source en panne nommée à l'écran (`fd5d2f0e`) ; provenance et licence par paire, à la publication et à la reprise (`76c6ae3f`, `20260927130518`, `capas_provenance_tests` 7 ; 0 capa attribuée sur 250 avant) ; une sonde horaire des sources, incident `capas_sources` (`0821035a`, `20260927130745`), qui a trouvé à son premier passage le trait d'union lu comme un opérateur (`6a76aa23`). **L'édition** : une candidate dit l'édition que son ISBN désigne, la recherche par titre vise l'édition et non l'œuvre (`027e6903`, `63803dea`) ; un ISBN d'ensemble vaut pour chacun de ses volumes (`3e1a3991`, `20260927164619`, `isbn_volumes_tests` 6 ; `123f20e6`). **Le lot** : `cover-batch` propose dans `cover_proposals` (cron `anarbib-capas-lot`), une personne tranche à l'écran « Couvertures proposées » (`ce2b759d`, `d37111b2`, `c89e1099`, `7dc13e5c`, `20260927180120`, `capas_lot_tests` 20) ; premier passage en production à 18 h 37 UTC : 24 notices, 10 à revoir. **La photo en rayon** : onglet « Couvertures » du Painel (`e6fd1dc2`, `20260927182008`, `capas_photo_tests` 14). **28/09** — une capa neuve a une adresse neuve, sans `upsert`, contre le cache d'une heure du bucket (`d7f65c54`, `CAPAS-6`). La note de livraison attribue l'édition à `e046157f` (une retouche i18n) et le lot à `c89e1099` (un test) : lire `027e6903`/`63803dea` et `ce2b759d`/`7dc13e5c`. **Reste, hors outil** : les versions remplacées restent au bucket tant que `scripts/purge-orphelins-covers.py` n'est pas lancé à la main (classe B) ; aucune migration n'a rendu de provenance aux capas d'avant le 27/09 (**C16**) ; les données fautives relevées (six années impossibles, un ISBN à clé fausse) se corrigent au formulaire, livre en main (**C15**). |
| pt-BR parle brésilien | 2026-09-27 | **Livré le 27/09.** **L'app** : 78 valeurs de `pt-BR.json` au vocabulaire du Portugal réécrites (« ficheiro » → « arquivo », « Guardar » → « Salvar », « gerir » → « gerenciar »…), garde `PT_EUROPEU` (`faae6e0e`) ; puis 91 valeurs françaises ou calquées, sur décisions de Xavier du 27/09 au soir : « cota » → « número de chamada », « notícia » → « ficha », « flux » → « feed », PEB → EEB, « import » → « importação » (`dfa622f5`, garde `FRANCES_EM_PT` ; `e046157f` pour une « Notícia do volume » oubliée) ; le document Communs « Cotação BLMF » devient « Números de chamada BLMF ». **Les courriels** : 16 chaînes (`49047ae3`, `PT_EUROPEU` partagée avec `mail-ptbr-voce.test.js`) ; le texte en dur du rapport hebdomadaire de la bibliothèque (`6f762f8f`), qui pose la liste fermée `TEXTE_EN_DUR_PT` : huit fichiers des Edge Functions rédigés en pt-BR seul, relus par `TU_EUROPEU`, `PT_EUROPEU` et `FRANCES_EM_PT` ; spec alignée (`d997ada7`). Angles morts déclarés dans les gardes : les mots qui existent au Brésil dans un autre sens (« gerir », « Guardar »), les calques en mots portugais (« notícia », « concernida »). **Reste** : ces décisions de vocabulaire ne sont pas au REGISTRE (`DOC-ADDR-1` ne traite que du registre d'adresse) — porté par **E25**. |
| Fusion de notices : rien ne se perd, la référence d'un exemplaire suit son fonds (DEDUP-11 à 14) | 2026-09-28 | **Clos le 28/09** (REGISTRE `DEDUP-11` à `DEDUP-14`, note `LIVRAISON_fusion-notices_2026-09-28.md`). Relevé par Xavier le 27/09 au soir : `suggest_editions_for_book` levait 42702 à chaque appel depuis sa création le 20/06, et aucun test ne l'appelait ; `911ad1db` (`20260927194141`, `editions_suggerees_tests` 4) la répare et fusionne BTL-TL-000880 dans BTL-TL-000881 sans rien perdre (`merge_log` 149). `11da0df8` (`20260928100501`) : une seule `fn_fusion_notices` pour `merge_book` et `merge_book_with_fields` — doublon entier dans `merge_log`, sujets et contributeur·rices repris, brouillons ouverts du doublon écartés, tout ce qui le désignait rattaché — et trois déclencheurs tiennent `exemplares.bib_ref` égal à la référence du fonds : 43 exemplaires réalignés (les 32 autres des « 75 » étaient justes). Suite `fusion_notices_complete_tests` 15/15 au banc ; en production à 10 h 49 UTC, déclencheurs présents, 0 exemplaire décalé. `40cb978f` : « Même édition : fusionner dans cette notice », chemin manuel pour une paire que la détection écarte (`DEDUP-13`, la règle des années reste stricte). BTL-TL-000881 corrigée (`96b4a104`, `bcd36f9d`) : l'exemplaire BLMF CCLA.2026.93 créé par erreur est retiré, « 1ª edição, 2010 » et « 2ª edição, 2011 » sont notées sur les deux exemplaires BTL ; au passage, le formulaire gardait les éditions suggérées de la notice précédente, désormais remises à zéro. Les deux autorités de Cristina Escrivá Moscardó réunies à l'écran (`merge_log` 150, `3d96a337`). Le soir, `8e0fe538` (`20260928163920`, `DEDUP-14`) : un même ISBN, en ISBN-10 ou en ISBN-13, est une même édition (`fn_isbn_coeur`), et un éditeur ne change pas pour un mot générique (`fn_meme_editeur`) ; `editions_distinctes_tests` 8 ; quatre paires démasquées (000504~000727, 000301~BLMF 0000054, 001525~BLMF 0000258, 001808~BLMF 0000060). |
| Sujets effacés par la reprise d'une notice (THES-5) | 2026-09-28 | **Clos le 28/09, trouvé et réparé le jour même** (REGISTRE `THES-5`). « Éditer » une notice publiée créait un brouillon sans ses sujets, et la publication remplaçait ceux de la notice par ce vide : depuis juin, 136 brouillons de reprise publiés sans sujet, 20 notices désindexées (constaté sur BTL-TL-000881). `6cdd27a0` (`20260928133838`) : `trg_seed_draft_subjects` sème les sujets à la création du brouillon, et un brouillon sans aucun sujet n'efface plus rien (limite assumée : on ne retire plus le dernier sujet d'une notice en publiant) ; les brouillons ouverts sont semés, sept notices rendues — six indexées par C7 la veille et BTL-TL-000881 (`sujets_suivent_la_reprise_tests` 7). `bab3f0fa` (`20260928155533`) : six autres retrouvées dans la sauvegarde #BG2 (`restic dump` de six instantanés, du 30/06 au 27/09). `e9ded1e8` (`20260928163609`) : les sept dernières n'avaient de sujet dans aucun instantané ; six indexées sur arbitrage de Xavier, BTL-TL-001242 laissée sans matière. Règle au registre : tout ce qu'un brouillon de reprise ne reprend pas, la publication l'efface. |
| Les sigles se cherchent sans leurs points (OPAC-F3) | 2026-09-28 | **Clos le 28/09 au soir** (REGISTRE `OPAC-F3`, versions 0.51 et 0.52). « La C.N.T. y la revolución española » (BTL) et « La CNT en la revolución española » (MLEG) restaient deux lignes au catalogue par œuvre selon la graphie cherchée. `fn_sigle_sans_points` plie un sigle sur ses lettres, d'abord dans `api.catalog_search_ids_v1` (`f36b4638`, `20260928174350`), puis dans `f_normalize_search`, pour la recherche de l'en-tête (`8d31716d`, `20260928191324` : REINDEX des index des autorités, REFRESH des deux vues matérialisées ; effet assumé, un périodique ou un sujet neuf « C.N.T. » reçoit le slug « cnt »). Le premier push s'est arrêté sur la vérification de la migration : 530 des 1 644 `alias_norm` viennent d'autres normalisations ; `36ae8d5d` plie `alias_norm` sur place, répété à blanc en production (0 alias replié, 6 index valides). Garde : `recherche_sigles_tests` T1-T11. **En production** : au relevé du 29/09, les 398 migrations numérotées du dépôt sont toutes au ledger, appliquées par la CI, `20260928191324` comprise. Au REGISTRE, `OPAC-F3` dit encore « `alias_norm` recalculé » : il est plié sur place. |
| « Rattacher à une autre œuvre » s'exécute depuis l'écran (OPAC-OEU7) | 2026-09-28 | **Clos le 28/09** (REGISTRE `OPAC-OEU7`). L'écran répondait 42501 depuis le 04/09 : `assign_book_to_work` avait été fermée à `authenticated` au solde des différées du 02/09 (B20), faute d'écran, puis réécrite le 04/09 pour l'écran sans le GRANT (un `CREATE OR REPLACE` garde l'ACL en place) ; `oeuvres_rattachement_tests` l'appelait en `postgres`, qui exécute tout. Droit rendu par la migration `20260928184700` (`f36b4638`) ; `oeuvres_rattachement_tests` T4 lit désormais le droit, `solde_des_differees_tests` compte 45 fermées — la clôture B20 du 02/09 en annonce 47 : `fn_circle_member_count` en est sortie le soir même (`20260902175631`), `assign_book_to_work` le 28/09. Règle rappelée : une RPC qu'un écran appelle se vérifie sous le rôle de l'écran, pas sous `postgres`. |
| Le catalogue publié ouvre la page de catalogage | 2026-09-28 | **Livré le 28/09 à la demande de Xavier** (`0d0322c0`) : on part de ce qui existe avant de saisir. L'onglet « Catalogue(s) publié(s) » passe en tête de la barre de catalogage et s'ouvre par défaut. Le dernier onglet visité n'est plus retenu (`catalogacaoActiveTab` n'est plus ni lue ni écrite dans `localStorage` : elle aurait masqué l'onglet de référence à toute personne ayant déjà ouvert la page) ; le lien profond `#tab=` (« Je veux… », cloche, rechargement) garde la main. Garde : `src/tests/catalogacao-onglet-de-reference.test.js` (4 cas). |
| `robots.txt` : les robots d'IA refusés, le catalogue public ouvert aux moteurs | 2026-09-29 | **Livré le 29/09, décision du jour** (`75ccb035`, déployé : servi en `text/plain` depuis 18 h 55). Jusque-là, `/robots.txt` répondait 200 avec `index.html` (le repli de l'application monopage) : les robots recevaient du HTML et l'ignoraient. Désormais les robots des entreprises d'IA (entraînement, assistants, moteurs de réponse) sont refusés partout ; les moteurs de recherche parcourent le catalogue public — notices, œuvres, autorités, périodiques, bibliothèques, thésaurus, cartographie — et les espaces de travail, formulaires, liseuse et banc leur sont fermés ; `Crawl-delay: 5` ménage le pool anonyme (plafond de 20 connexions, cf. capacité mesurée). Garde `src/tests/robots-txt.test.js` : toute route de `App.jsx` doit être classée (publique ou `Disallow`), arbitrage de la RFC 9309 (la règle la plus longue l'emporte), pas de jokers ; trois mutants vérifiés. |
| E3 | 2026-09-30 | **Clos le 30/09, les deux critères tenus.** *(1)* La décision et ses deux raisons sont au REGISTRE (`DOC-ADDR-1`, amendé le 07/09, complété le 27/09) : on tutoie dans toutes les langues qui ont un registre de politesse (en et eo n'en ont pas), pt-BR au « você ». *(2)* Les dix locales appliquent ce registre, chacune sous sa garde au chemin (4) de `src/tests/i18n-ecriture.test.js` : passes du 27/09 (pt-BR `a805951b`, `36c467fa` ; fr `8f0d85a0` ; es et pt-BR `e8caf563` ; ca `f1743c4c`, `53cba900` ; it, de, nl, el `b425dfb1`), refus de l'EF `login` passés en codes traduits (`3cf927e1`). Les quatre dernières valeurs italiennes au « Lei » (« Faccia clic… », « Ricarichi l'elenco »), que la garde ne voyait pas, sont passées au tu le 30/09 (`abb4aa38`) ; `IMPERATIVI_LEI` apprend les deux formes, deux mutants vérifiés rouges. Restes suivis ailleurs : les conventions nl et el à faire relire par une personne de langue maternelle (E2), la passe pt-BR hors de l'app (E25). |
| I24 | 2026-09-30 | **Clos le 30/09 au soir, sur l'essai de Xavier** (« on pourra clore I24 si les résultats confortent l'essai »). Livré par `233bb735`, déployé le jour même sur le poste. *Critère 1, réécrit* — tel qu'écrit (« le service survit à la fermeture du terminal ») il était inatteignable : c'est le gestionnaire systemd lui-même qui sort (constat du 20/09). Ce qui le remplace, et qui a été éprouvé : **un tir tué repart seul**. Xavier a lancé un tir `storage` à 20 h 15, coupé WSL (`wsl --terminate`) à 20 h 16 — le journal redit « Failed to enqueue OnFailure », comme le 15/09 —, rallumé : le contrôle de fraîcheur a vu le tir interrompu et l'a relancé à 20 h 21, sous le nouveau script (verrou `.bg2.lock` né à cette minute) ; instantané `f420f896` à 20 h 39, témoin de vie envoyé, marqueur retiré (18 min 44 s) ; en base, `storage` ni interrompu ni muet, **aucun incident** ouvert par la sonde. *Critère 2* — tenu depuis le 20/09 par `health-probe` (deux alertes reçues par Xavier). *Critère 3* — un dimanche poste éteint : le rattrapage `Persistent=` rejoue les tirs manqués, la relance rejoue un tir tué, le verrou empêche les rattrapages simultanés de se détruire leurs dumps (défaut antérieur trouvé par la relecture), et la sonde écrit sinon dans l'heure. Chemin de la preuve : deux bancs (`fraicheur-relance`, `bg2-un-tir-a-la-fois`), un essai réel. Découvert en route et réparé : `~/anarbib-ops/anarbib-bg2.sh` était une copie depuis le 07/09, pas un lien. |
| F18 | 2026-09-30 | **Clos le 30/09 le soir même de son ouverture : le constat était faux.** La carte F1 tenait `fede@anarbib.org` pour une adresse sans boîte, sur la foi d'une note OVH du 28/08. Xavier a montré la boîte, configurée dans son client de courrier : les contributions à la Gazette (4 envois, 27/08-15/09) et la copie fédérale des ouvertures OAI (3 envois le 02/09) y arrivent. Rien à corriger ; la carte porte un correctif en tête. |
| F17 | 2026-10-01 | **Clos le 01/10 : livré, déployé, le critère tenu au banc.** `88dde5b3` (migration `20260930200514`, appliquée par la CI le 01/10 à 18 h 55 ; `notify-loan-cycle` version 83 relue en production : échéance courante `coalesce(extended_until, due_at)`). La trace `loan_cycle_notifications` porte l'échéance (unicité exemplaire, moment, échéance ; un déclencheur la remplit quand l'écrivain ne la donne pas, pour qu'aucun ordre de déploiement ne fasse repartir un rappel ; les 3 traces existantes reprises). Banc `notify-loan-cycle-banc` 13 : trois cas de prorogation (le J-3 de la nouvelle date part, pas le « c'est aujourd'hui » de l'ancienne ; un J-3 déjà parti pour l'ancienne échéance n'empêche pas le nouveau ; pas de « 7 jours de retard » à tort, date affichée juste) — mutant « due_at seul » : 3 rouges ; `rappels_echeance_tests` 8/8. Aucune prorogation réelle n'a encore eu lieu depuis F4. |
| E26 | 2026-10-01 | **Ouvert et clos le 01/10 : la recherche du catalogue ne trouvait ni « Emma Goldman » ni « Vivre ma vie ».** Signalé par Xavier à l'écran. Deux causes : le filtre texte par auteur·rice cherchait la saisie entière comme sous-chaîne de `autor`, qui est à la forme d'autorité (« GOLDMAN, Emma ») — « Emma Goldman » n'y figurait jamais, un accent omis non plus ; et `catalog_search_ids_v1` ne lisait que les champs de l'édition, si bien que le titre d'œuvre affiché (`work_titles`, « Vivre ma vie » pour l'œuvre 2101) n'était pas cherchable — la seule réponse était un faux positif (Armand : « vivre ? », « vie », « ma » dans « ARMAND »). Migration `20261001190729` (`697c81d9`) : filtre auteur·rice mot par mot, sans accents ni casse (`catalog_works_v1`, réécriture d'une seule clause gardée par md5 ; repli PostgREST `catalogFilters.js` mot par mot) ; la meule de la recherche reçoit les titres de l'œuvre dans toutes les langues et le rang prend le meilleur d'entre eux. En chemin, l'œuvre 1163 (*L'Épopée d'une anarchiste*, abrégé français arrêté en 1920) portait neuf titres « auto » copiés de *Living My Life* : remplacés par son titre français (`manual`, l'autofill ne repasse plus) et une note d'œuvre ; **décision de Xavier : les deux œuvres restent distinctes**. Suite `20261001192041` (`52ebebc1`) : le départage écrit `s.book_id` (garde T7 de `catalogue_grande_echelle_tests`, rouge sur le premier push). Vérifié en production et à l'écran : « Emma Goldman » → 13 œuvres, « Vivre ma Vie » → *Vivre ma vie* en tête. Restes : **E27** (les suggestions de la recherche rapide), **C18** (œuvres scindées). |
| F1 | 2026-10-03 | **Clos le 03/10, décision de Xavier, les trois critères tenus.** (1) La carte est écrite : `docs/journal/audits/CARTE_chaine_courriel_2026-09-30.md`, environ 96 chaînes mesurées en production. (2) Les quatre courriels signalés ont leur verdict : `retirada_efetivada` part sous `reserva_convertida_em_emprestimo`, `retirada_no_show` part, `retirada_reagendada` était un fossile (supprimé), `liberada_para_circulacao` est coupé par réglage. (3) Les branches mortes sont supprimées ou documentées : `57a4aafc` (migration `20261001194818`, déployé et vérifié le 01/10 à 22 h 40) et `e897fb26` (échéance de 60 jours des consultations, décision de Xavier) ; `team.promoted_to_librarian` émis ; colonnes et table sans lecteur gardées par COMMENT (aucune donnée supprimée) ; `notify-mid-loan-reading` retirée de la plateforme par Xavier. Tirs des 02 et 03/10 relus : expiration des consultations sans effet (aucune échéance encore posée), `notify-loan-cycle` en 200. Défauts trouvés en route, traités à part : F16, F17, F19 (livrés), F18 (constat faux), F20, F21. |
| C19 | 2026-10-03 | **Demandé et livré le 03/10 (Xavier).** Une reprise de notice, d'autorité ou d'exemplaire que ne suit aucun enregistrement ne reste plus en file éditoriale : `retake_untouched` la marque à la naissance, la première écriture le retire (ouvrir n'est pas modifier ; sujets, ressources numériques et contributeurs écrits en direct comptent). L'éditeur la fait oublier quand on la quitte (`discard_untouched_retake`), sans corbeille ni entrée au journal ; le job horaire `anarbib-purge-untouched-retakes` rattrape les onglets fermés (plus de 24 h). Cas d'origine : les brouillons 6276 et 6277, écartés à la main par `20260928114148`. Dans le même lot, tout enregistrement des trois éditeurs remonte jusqu'à son message de confirmation, doublé d'un toast temporaire. Migration `20261003202521` (`8ccfa02f`, déployée et vérifiée en production), écran `9419fda7` ; suites `reprises_vierges_tests` (7) et vitest `reprises-vierges`, `confirmation-enregistrement` (12). |
| E28 | 2026-10-04 | **Ouvert et livré le 04/10 : une autorité corrigée ne changeait aucune fiche, et la fiche 2736 montrait deux fois le SNI.** Signalé par Xavier à l'écran (`/livro/2736`). Deux causes. (1) **Doublons** : le lot `conv_revue` du 03/09 avait créé l'autorité depuis la transcription `books.autor` (avec sa faute, « d Informações ») et **ajouté** une ligne de contributeur liée au lieu de rattacher la ligne d'origine ; même cas sur les livres 412, 1282, 1541 et 2316. Données corrigées le 04/10 (autorisé par Xavier) : ligne d'origine rattachée à l'autorité, doublon supprimé, « Russel » → « RUSSELL », faute de `books.autor` du 2736 corrigée, 3 liens `book_authors` orphelins de ces livres retirés. (2) **Affichage** : `get_book_contributors_public` rendait la transcription figée au rattachement, jamais `authors.preferred_name`. Doctrine `CAT-G4` : un contributeur lié s'affiche sous la forme autorisée (point d'accès), la transcription reste la mention de responsabilité (vue ISBD). La RPC rend `authority_name` en plus, `name` inchangé (le catalogage le recharge comme ligne éditable). Migration `20261004212710`, fiche `BookPage.jsx`. Le même soir (autorisé par Xavier), les **29 liens `book_authors` orphelins** des 22 autres livres sont retirés : chacun désignait une personne bien présente parmi les contributeurs du livre, sous un rôle ou une position périmés, et chaque contributeur lié gardait son lien exact (0 orphelin, 0 lien manquant après coup). **Reste, non tranché** : le lot `conv_revue` recréerait des doublons s'il était relancé tel quel. |

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

Backlog v34, écrit le 2026-08-29, mis à jour le 2026-10-04. Remplace `AnarBib-Backlog-2026-06-17-v33.md`. 74 items sur 11 domaines. L'état chiffré a été relevé le 2026-09-29 contre la base de production en lecture seule et contre le dépôt Codeberg au commit `75ccb035` ; les items retouchés depuis portent leur propre date dans leur texte. Ce document n'arbitre rien : le `REGISTRE_decisions.md` fait foi.
