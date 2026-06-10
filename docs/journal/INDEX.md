# 📂 INDEX du dossier `journal/` — AnarBib *(ex-`decisions/`)*

**Dernière mise à jour** : 10 juin 2026 (réorganisation en **sous-dossiers stricts par type** — `cadrages/`, `chantiers/`, `sessions/`, `audits/`, `arbitrages/`, `bugs/`, `operations/`, `references/`, `archive/` ; renommage `decisions/` → `journal/`). Index initial : 3 juin.
**Maintenu par** : Xavier (lead dev) + Claude (assistant·e)

Ce dossier est la **mémoire chronologique vivante** du projet AnarBib : sessions de travail, ouvertures et clôtures de chantiers, bilans, audits, bugs résolus, réflexions doctrinales, décisions de coordination de bibliothèques. **~91 fichiers**, rangés par type dans des sous-dossiers (table préfixe → sous-dossier dans [`../INDEX.md`](../INDEX.md) § « Nommage et rangement dans `journal/` »).

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

Les 79 fichiers suivent un système de préfixes qui dit immédiatement *de quoi il s'agit* :

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
