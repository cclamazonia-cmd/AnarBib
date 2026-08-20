# 📂 INDEX du dossier `journal/` — AnarBib *(ex-`decisions/`)*

**Dernière mise à jour** : 20 août 2026 — rafraîchissement après deux mois de retard : comptes réels, sous-dossier `ficedl/` ajouté, table des préfixes complétée (11 préfixes apparus depuis), repères chronologiques prolongés de la mi-juin à août. *Précédemment : 10 juin 2026 (réorganisation en **sous-dossiers stricts par type** ; renommage `decisions/` → `journal/`). Index initial : 3 juin.*
**Maintenu par** : Xavier (lead dev) + Claude (assistant·e)

Ce dossier est la **mémoire chronologique vivante** du projet AnarBib : sessions de travail, ouvertures et clôtures de chantiers, bilans, audits, bugs résolus, réflexions doctrinales, décisions de coordination de bibliothèques. **176 fichiers** (162 hors `archive/`), rangés par type dans des sous-dossiers (table préfixe → sous-dossier dans [`../INDEX.md`](../INDEX.md) § « Nommage et rangement dans `journal/` »).

**Répartition au 20/08/2026** : `cadrages/` 50 · `chantiers/` 30 · `operations/` 22 · `arbitrages/` 18 · `audits/` 16 · `sessions/` 16 · `archive/` 7 · `references/` 5 · **`ficedl/` 4** *(nouveau — thésaurus FICEDL : audits + données de référence)* · `bugs/` 2. Deux fichiers `HANDOFF-*` (12/06) sont restés **à la racine** du dossier, hors du rangement strict : à classer en `references/` ou `sessions/`.

---

## ⚖️ Préséance — `journal/` est de la trace

Conformément à la règle de gouvernance documentaire (voir [`../INDEX.md`](../INDEX.md) section « Préséance documentaire »), le contenu de ce dossier est **de la trace non-normative**. Une session, un chantier, un audit documentent *comment* on est arrivés à une décision et *ce que* nous avons appris en chemin — précieux, mais ce n'est pas ce qui fait foi.

**Pour ce qui fait foi** :
- doctrines transverses et arbitrages structurants → [`../specs/REGISTRE_decisions.md`](../specs/REGISTRE_decisions.md) ;
- specs courantes par domaine → [`../specs/INDEX.md`](../specs/INDEX.md) ;
- liste de travaux et séquencement → [`../backlogs/INDEX.md`](../backlogs/INDEX.md).

Quand le contenu d'un fichier `journal/` a gradué au REGISTRE ou à une spec, **c'est ce dernier qui fait référence**, pas le fichier d'origine. Le fichier reste en trace.

---

## 🏛️ Documents doctrinaux centraux

Une dizaine de fichiers, parmi les ~91, ont une portée doctrinale durable — soit ils sont à l'origine d'une règle inscrite au REGISTRE, soit ils sont des audits structurants à consulter récurremment, soit ils portent des arbitrages qui dépassent un seul chantier. À garder à portée de main.

| Fichier | Portée |
|---|---|
| `audits/AUDIT_coherence_corpus_2026-06-02.md` | **Fondateur du REGISTRE et de la règle de préséance.** Diagnostic structurel du corpus, doctrine documentaire qui en découle. À relire à chaque grand nettoyage. |
| `chantiers/CHANTIER_doctrine_creation_objets_securises_2026-05-12.md` | Doctrine `DOC-OBJ-2` du REGISTRE — comment créer un objet backend proprement (RPC + RLS + audit). Référence permanente côté ingénierie. |
| `chantiers/CHANTIER_doctrine_transitions_profils_2026-05-17.md` | Doctrine des transitions d'état des profils (extérieur ↔ membre ↔ coordinateur·rice). |
| `chantiers/CHANTIER_linter_security_definer_assume_2026-05-12.md` | Doctrine d'usage de `SECURITY DEFINER` côté Postgres. Précautions et patterns acceptés. |
| `audits/AUDIT_securite_fonctions_privees_2026-05-18.md` | Audit de sécurité des fonctions privées (RPC `api`). Posture à reconduire périodiquement. |
| `audits/AUDIT_153_contenus_mails_2026-05-23.md` | Audit des contenus de mails — méthode et constats transférables à d'autres audits de contenu. |
| `arbitrages/DECISION_arbitrages_backlog_v21_glb_v17_2026-05-29.md` | Arbitrages structurants entre backlog et GLB. À relire avant chaque promotion de version GLB. |
| `arbitrages/DECISION_validation_par_appartenance_2026-05-30.md` | Décision-cadre sur la validation par appartenance — patron transverse réutilisé. |
| `arbitrages/DEFINITION_MEMBRE_2026-05-27.md` | Définition de référence de la notion de « membre » dans AnarBib. Sémantique fondatrice. |
| `arbitrages/RIFLEXION_self-hosting_AnarBib_2026-06-01.md` | Réflexion structurelle sur l'auto-hébergement du projet. Ouvre une perspective qui ressortira. |

Les autres fichiers (sessions, bilans, ouvertures/clôtures de chantiers ponctuels, bugs, QA, etc.) sont précieux pour la mémoire mais n'ont pas le même statut transverse.

---

## 🏷️ Navigation par convention de nommage

Les fichiers suivent un système de préfixes qui dit immédiatement *de quoi il s'agit*. Onze préfixes sont apparus depuis la table de juin — surtout dans `operations/`, à mesure que le projet s'est doté d'une couche infrastructure (sauvegardes, VPS, hébergeurs) :

| Préfixe | Nature |
|---|---|
| `sessions/SESSION_*` | Compte-rendu d'une session de travail (sa date, ses livrables, ses décisions). |
| `chantiers/CHANTIER_*` | Documentation d'un chantier (cadrage, suivi, clôture). En cours ou clos. |
| `cadrages/CADRAGE_*` | Document d'ouverture/de cadrage d'un sujet (souvent l'amont d'un futur chantier). |
| `arbitrages/CLOTURE_*` | Clôture explicite d'un chantier — atterrissage, leçons, ce qui graduera au REGISTRE. |
| `sessions/BILAN_*` | Bilan d'une période (semaine, paquet, série de sessions). |
| `bugs/BUG_*` | Analyse d'un bug — diagnostic, correctif, prévention. |
| `audits/QA_MANUELLE_*` | Plan ou compte-rendu de QA manuelle (test de comportement attendu). |
| `audits/AUDIT_*` / `audits/AUDITORIA_*` | Audit technique (`AUDITORIA` quand le contenu est en pt-BR). |
| `arbitrages/RIFLEXION_*` | Capture conversationnelle d'une réflexion doctrinale ou stratégique. |
| `arbitrages/DECISION_*` | Décision projet ou arbitrage d'ouverture. |
| `arbitrages/DECISOES_*` | Décisions de coordination d'une bibliothèque (pt-BR). |
| `arbitrages/DEFINITION_*` | Définition de référence d'une notion centrale. |
| `arbitrages/AMENDEMENT_*` | Amendement à une spec existante. |
| `operations/CLEANUP_*` | Opération de nettoyage technique. |
| `cadrages/CADRAGE_*`, `operations/DEPLOIEMENT_*`, `operations/REDEPLOY_*`, `operations/REFACTOR_*`, `operations/SETUP_*` | Documents techniques ponctuels, autoexplicatifs. |
| `NOTE_*` | Note brève sur un point précis. |
| `chantiers/Dossier_ouverture_chantier_*` | Dossier d'ouverture d'un chantier — équivalent francisé de `cadrages/CADRAGE_`. |
| `chantiers/PLAN_*` | Plan de travail détaillé d'un chantier (séquencement, jalons). |
| `cadrages/MEMO_*` | Mémo de cadrage — plus court qu'un CADRAGE, sur un point circonscrit. |
| `audits/MATRICE_*` | Matrice d'audit (grille systématique, ex. RLS deny-all). |
| `audits/PROTOCOLE_*` | Protocole de validation à exécuter (ex. validation terrain backend-seul). |
| `operations/RUNBOOK_*` | Procédure opérationnelle à dérouler en situation (restauration, migration). |
| `operations/BASELINE_*` | Établissement d'une référence technique (schéma, état de départ). |
| `operations/SHORTLIST_*` | Sélection comparée d'options (ex. hébergeurs VPS). |
| `operations/MESSAGE_*`, `operations/FICHE_*`, `operations/HEBERGEURS_*` | Correspondance et fiches à destination de tiers (hébergeurs, partenaires). |
| `ficedl/*` | Thésaurus FICEDL — audits et données de référence du vocabulaire d'indexation. |
| `sessions/ETAT-*` | Photographie d'avancement (multi-sessions, ou d'un chantier donné). |

> ⚠️ Deux préfixes sont **ambigus** dans l'état actuel : `NOTE_*` existe en `arbitrages/` *et* en `operations/`, et `AUDIT_*` en `audits/`, `operations/` *et* `ficedl/`. Ranger selon l'objet (doctrine → `arbitrages/`, infra → `operations/`), sans y voir une règle stricte.

---

## 📅 Repères chronologiques

Plutôt qu'un index ligne à ligne des ~91 fichiers, voici les **grands moments** qui ont structuré le corpus — pour situer une date dans son contexte projet.

### Mai 2026

**Première quinzaine — fondations.** Doctrines fondatrices (`chantiers/CHANTIER_doctrine_creation_objets_securises` du 12/05, `chantiers/CHANTIER_linter_security_definer_assume` du 12/05), travaux sur les notifications, premières refontes (Brevo → Resend, début).

**Semaine du 18 au 24/05 — chantier-cadre Biblioteca.** `chantiers/CHANTIER_audit_biblioteca_parite_doctrinale_2026-05-21.md` cartographie les écarts ; les sessions du 19 au 23/05 livrent les étapes successives (paquets C/D, profils, EA-11 exchanges, EA-20). Audit de sécurité du 18/05 et audit des contenus mails du 23/05. Chantier-cadre clos le 24 (sauf étape 8 différée).

**Fin mai (25 au 31/05) — ouverture chantiers parallèles.** Module tâches (24/05), réseau fédératif (25/05), extension mobile (26/05), partenaires et correspondance (24/05). Définition de la notion de « membre » (27/05). Audits systématiques du Painel UX (25-26/05). `arbitrages/DECISION_arbitrages_backlog_v21_glb_v17_2026-05-29.md` arbitre la trajectoire backlog/GLB. Audit des specs (31/05).

### Juin 2026

**Début juin — refonte doctrinale du corpus.** `audits/AUDIT_coherence_corpus_2026-06-02.md` constate les drifts du corpus et **institue le REGISTRE des décisions** comme foyer unique du normatif. Trilogie doctrinale du 02/06 (multi-appartenance, partenariat, flux numérique). Cluster catalogue du 01/06.

**Ouverture des chantiers de modèle.** `chantiers/CHANTIER_MODEL-item-grain_ouverture_2026-06-03.md` puis `arbitrages/CLOTURE_MODEL-item-grain_2026-06-03.md` (constat de livraison via audit du dump schéma). `chantiers/CHANTIER_exemplares-phase1_ouverture_2026-06-03.md`.

**Préparation du chantier OPAC (07/06).** `cadrages/CADRAGE_OPAC_chantier_2026-06-07.md` confronte les deux specs OPAC (`../specs/spec-catalogue-decouverte.md`, `../specs/spec-notice-autorite-enrichie.md`) au code réel (frontend lu + backend sondé sur le projet Supabase) et prépare le chantier de découverte : écart par paquet (#OPAC1–11, #AUT1–4), clé de voûte (RPC d'agrégation des facettes/sujets `api.catalog_facets_v1`), décisions à porter au REGISTRE. Trace, 🟡 cadrée — ne fait pas foi.

**Seconde quinzaine (15 au 30/06) — la vague la plus dense du projet.** ~380 commits. Le **modèle Œuvre/Éditions** (FRBR-léger) est cadré puis construit (`cadrages/CADRAGE_modele_oeuvre_editions_*`, `CADRAGE_oeuvre_v2*` du 20/06, `chantiers/CHANTIER_modele_oeuvre_editions_*`) — il devient l'ancre du catalogage. Le **thésaurus matière** passe v1 → v3 (gouvernance par consentement, notation CDD, synonymes, « voir aussi », export SKOS public, parcours par sujet), puis rencontre le **vocabulaire FICEDL** (`ficedl/`, `cadrages/CADRAGE_ficedl_vocabulaire_indexation_*` du 30/06). Livrés dans la même vague : **assembleias** (v0.1 → P3 notifications), **Lettre de la fédération** et **gazette Rizoma**, **entraide par cercles** (+ visio Jitsi embarquée), **récolement** par scan, **annuaire et fiches publiques** (#PUBLIB), les **horaires/permanences** de bibliothèque, et les **phases B/C du chantier mobile** (tiroir hamburger, tables en cartes, safe-area). Cadrages ouverts sans implémentation immédiate : `CADRAGE_mobile_responsive` (16/06), `CADRAGE_ocr_import_navigateur` (17/06), `CADRAGE_fonds_sonores_P1` (21/06), `CADRAGE_recolement`, `CADRAGE_fusion_autorites`, `CADRAGE_accueil_equipe` (19/06).

### Juillet 2026

**Le chantier bascule de l'applicatif vers l'infrastructure.** ~78 commits, mais structurants. **#BG2 — sauvegarde hors-fournisseur** occupe le mois : partition par sensibilité (`cadrages/CADRAGE_BG2_partition_sauvegardes_2026-06-30`), trois flux restic chiffrés hors-site, automatisation par timers systemd, puis **pseudonymisation à l'effacement** (`BG2-14`) — avec `operations/RUNBOOK_restauration_BG2_2026-07-01` comme procédure de référence et `operations/NOTE_premier-tir_BG2-AUTO_2026-07-01` comme trace du premier tir réel. En parallèle, la **migration hors Supabase** est instruite : `arbitrages/DECISION_arbitrage_migration_vps_2026-07-03`, `operations/SHORTLIST_vps_calcul_2026-07-04`, `operations/RUNBOOK_migration_vps_2026-07-04`, `chantiers/PLAN_serveur-dell-latitude_2026-07-04`, et la correspondance avec les hébergeurs pressentis (`operations/MESSAGE_*`). Côté corpus, `backlogs/ETAT-lancement-consolide-2026-07-03.md` remplace le portrait périmé du backlog v33 pour la question « que reste-t-il avant le lancement public ? ».

### Août 2026

**Sécurité, identité, et finitions.** ~115 commits. **Retrait de Cloudflare Turnstile** au profit d'**Altcha auto-hébergé** (18-20/08) : calcul par le navigateur, vérification par nos Edge Functions, anti-rejeu — la dernière exception à la doctrine d'auto-hébergement tombe, et avec elle un transfert hors-UE (registre des traitements aligné le 20/08). Même semaine : fermeture de plusieurs **oracles** (appartenance des lectrices, « numéro de lecteur → e-mail »), **nouveau logo** (dessin humain) et sa déclinaison complète, **profil de numérisation** arrêté (`arbitrages/DECISION_profil_numerisation_2026-08-20`, chaîne ScanTailor Advanced + img2pdf, captures effacées après validation), **dédoublonnage global** du catalogue publié, **récapitulatif hebdomadaire** inter-bibliothèques, **mode dégradé** de l'OPAC si l'API tombe. Ouvert le 01/08 : `cadrages/CADRAGE_notes_de_lecture` (livré Lots 1-5). Le 20/08 également, le **chantier mobile** est repris à la mesure et sa doctrine gradue au REGISTRE § 36 (`cadrages/CADRAGE_mobile_responsive_2026-06-16.md` § 8).

> **Lacune assumée de cet index.** Les repères ci-dessus sont reconstruits depuis les noms de fichiers du dossier et le `git log` ; ils nomment les mouvements, pas chaque document. Pour l'état d'avancement par chantier, voir [`../backlogs/ETAT-AVANCEMENT-multisessions.md`](../backlogs/ETAT-AVANCEMENT-multisessions.md) (repris le 20/08 : tableau de bord par chantier) et surtout le [REGISTRE](../specs/REGISTRE_decisions.md), tenu à jour section par section.

### Décisions de coordination des bibliothèques

`arbitrages/DECISOES_COORDENACAO_BLMF_2026-05-05.md` (Biblioteca Libertária Movimento Florestinha) et `arbitrages/DECISOES_COORDENACAO_BTL_2026-05-06.md` (Biblioteca Terra Livre) — décisions internes des bibliothèques pilotes, en portugais brésilien. Elles documentent les pratiques de terrain qui informent les choix techniques.

---

## 🔍 Comment chercher

**« Telle date / telle session »** → préfixe daté dans le nom de fichier (`YYYY-MM-DD`). Tri par nom = tri chronologique.

**« Telle décision normative »** → toujours commencer par [`../specs/REGISTRE_decisions.md`](../specs/REGISTRE_decisions.md). Le registre cite, le cas échéant, le fichier `journal/` qui lui a donné naissance pour la trace détaillée.

**« Telle doctrine »** → REGISTRE d'abord, puis la doctrine centrale correspondante dans la section ci-dessus.

**« Comment on a fait pour résoudre tel bug / réussir tel chantier »** → c'est exactement la vocation de `journal/`. Chercher par préfixe (`bugs/BUG_*`, `chantiers/CHANTIER_*`, `sessions/SESSION_*`) et par date.

**« Une décision de coordination d'une bibliothèque »** → préfixe `arbitrages/DECISOES_COORDENACAO_<biblio>`.

---

## 🧹 Maintenance et hygiène

- **Toute promotion au REGISTRE** doit, si possible, mentionner le fichier `journal/` source pour la trace.
- **Ne jamais supprimer un fichier de `journal/`** — déplacer vers `archive/` au pire (cas typique : un `Prompt-Reprise_*` devenu obsolète après clôture du chantier qu'il portait).
- **Pas de renommage massif** : les références croisées (depuis specs, GLB, autres fichiers `journal/`) sont nombreuses et fragiles. Si renommage indispensable, traiter au cas par cas.
- **Cet index est navigationnel, pas exhaustif** : il ne liste pas les ~91 fichiers mais oriente vers les bons préfixes et les doctrinaux centraux. À actualiser quand un fichier rejoint le rang « doctrinal central » (ce qui est rare) ou qu'une nouvelle convention de préfixe apparaît.

---

*Fin de l'index des décisions. Pour la navigation générale, voir [`../INDEX.md`](../INDEX.md). Pour ce qui fait doctrine, voir [`../specs/REGISTRE_decisions.md`](../specs/REGISTRE_decisions.md).*
