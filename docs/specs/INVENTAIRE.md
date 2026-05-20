# 📋 INVENTAIRE du corpus de specs — AnarBib

**Dernière mise à jour** : 20 mai 2026 (post-réécriture v2.0/v0.4/v2.2)
**Maintenu par** : Xavier (lead dev) + Claude (assistant·e)

Ce document décrit **chaque spec active** du corpus AnarBib avec son statut d'implémentation, ses dépendances entrantes et sortantes, sa date de dernière mise à jour, et les chantiers liés. Pour la navigation rapide par domaine, voir [`INDEX.md`](./INDEX.md).

---

## 🗺️ Carte des dépendances entre specs

Lecture : **A → B** signifie « A dépend de B » (A référence B dans ses dépendances entrantes).

```
spec-onboarding-biblioteca-v2.0
  ├──→ spec-administrateur-reseau-v0.4 (workflow cooptation + canal humain miroir)
  ├──→ spec-gouvernance-roles v1.1 (rôle coordenador à l'activation)
  ├──→ spec-profils-bibliotheque-v0_7 (volet 0 = profil d'adoption)
  ├──→ spec-validation-physique (à rédiger)
  └──→ spec-migration-compte (cas particuliers)

spec-administrateur-reseau-v0.4
  ├──→ spec-onboarding-biblioteca-v2.0 (dépendance mutuelle, canal humain symétrique)
  ├──→ spec-profils-bibliotheque-v0_7 (transitions de profil = cas critique canal humain)
  └──→ spec-gouvernance-roles v1.1 (séparation staff local / admin réseau)

spec-profils-bibliotheque-v0_7
  ├──→ spec-administrateur-reseau-v0.3.1 (admins valident transitions cross-axes)
  ├──→ spec-gouvernance-roles v1.1 (governance_mode pilote rôles staff)
  ├──→ spec-flux-consultations-v2.2 (circulation_mode pilote consultations)
  ├──→ spec-flux-emprunts (circulation_mode pilote emprunts)
  └──→ spec-onboarding-biblioteca-v2.0 (volet 0 = choix initial profil)

spec-flux-consultations-v2.2
  ├──→ spec-flux-emprunts (invariant croisé emprunt-vs-consulta)
  ├──→ spec-workflow-reservation (modèle de négociation de créneau)
  ├──→ spec-administrateur-reseau-v0.4 (doctrine R8 traçabilité coordination)
  ├──→ spec-gouvernance-roles v1.1 (rôles staff dans matrice de transitions)
  └──→ spec-profils-bibliotheque-v0_7 (comportement conditionné par circulation_mode)

spec-flux-emprunts
  ├──→ spec-flux-consultations-v2.2 (invariant croisé)
  ├──→ spec-workflow-reservation (transitions retrait → emprunt)
  └──→ spec-gouvernance-roles v1.1 (rôles staff)

spec-workflow-reservation
  ├──→ spec-flux-emprunts (transition pickup → emprunt)
  └──→ spec-refactor-v3-semantique (historique, doctrine sémantique appliquée)

spec-gouvernance-roles v1.1 (autonome, pas de dépendance sortante)

spec-migration-mail-resend (autonome, touche tous les handlers)

spec-migration-compte
  ├──→ spec-onboarding-biblioteca-v2.0 (cas particuliers limbo_fechamento)
  └──→ spec-gouvernance-roles v1.1 (rôles préservés ou modifiés)

spec-validation-physique
  ├──→ spec-onboarding-biblioteca-v2.0 (validation côté solicitantes hors scope)
  └──→ spec-gouvernance-roles v1.1 (validation côté staff local)
```

---

## 📚 Specs de référence — description détaillée

### 🏛️ `spec-administrateur-reseau-v0.4.md`

**Domaine** : Séparation administrateur réseau / staff local
**Version actuelle** : v0.4 (20 mai 2026)
**Versions précédentes archivées** : v0.3 dans `archive/`, v0.3.1 à archiver
**Taille** : ~92 Ko, 1262 lignes
**Statut** : 🟢 Référence — implémentation v0.3.1 entièrement en prod (paquets A-F + chantier #114), enrichissements v0.4 à implémenter dans un chantier dédié (~6-7h, post-#111 ou en parallèle)

**Périmètre** :
- Définition politique du rôle d'administrateur réseau (transverse aux biblios)
- Workflow de cooptation à l'unanimité
- Workflow de retrait collectif avec carence 7j
- Sémantique des compteurs (« page = périmètre »)
- Helpers SQL centralisés (`user_can_engage_library`, `user_can_act_as_staff_on_library`)
- *(v0.4)* Doctrine anti-méga-machine appliquée aux admins réseau
- *(v0.4)* Mécanisme « Proposer un échange » côté admins vers biblios membres

**Dépendances entrantes** (specs sur lesquelles elle s'appuie) :
- aucune dépendance forte — c'est une spec fondatrice

**Dépendances sortantes** (specs qui s'appuient sur elle) :
- `spec-onboarding-biblioteca-v2.0` (workflow cooptation utilisé pour évaluer les demandes)
- `spec-profils-bibliotheque-v0_7` (admins réseau valident les transitions cross-axes)
- `spec-gouvernance-roles v1.1` (helpers SQL partagés)
- `spec-flux-consultations-v2.2` (doctrine R8 traçabilité coordination)

**Historique des versions** :
- v0.1 (11/05) : première rédaction (846 lignes)
- v0.2 (11/05) : refonte complète, sémantique « page = périmètre »
- v0.3 (11/05) : toutes décisions tranchées, doctrine complète
- v0.3.1 (15/05) : raffinements de notification post-implémentation
- **v0.4 (20/05)** : enrichissement doctrinal anti-méga-machine + canal humain proactif

**Chantiers liés** :
- Paquet A-F admin réseau (11-13/05/2026) ✅ clos
- Chantier #114 mails militants (14/05/2026) ✅ clos
- Futur chantier « canal humain proactif biblios membres » (~6-7h, non démarré)

**Points d'attention** :
- L'admin réseau Xavier est actuellement seul·e en prod. Le quorum minimum de 3 admins pour l'unanimité réelle n'est pas atteint, mode dégradé d'auto-confirmation actif.
- §4.7 (proposer un échange) et §8.8 (risque burnout) sont les **enrichissements v0.4 à implémenter**, pas encore en code.

---

### 🚪 `spec-onboarding-biblioteca-v2.0.md`

**Domaine** : Onboarding d'une bibliothèque dans le réseau AnarBib
**Version actuelle** : v2.0 (20 mai 2026)
**Versions précédentes archivées** : v1.0 dans `archive/`, v1.1 à archiver
**Taille** : ~98 Ko, 1253 lignes
**Statut** : 🟢 Référence — volet 0 livré 19/05/2026 dans le chantier profils (paquet F.3, composant `LibraryProfileWizard.jsx`). Volets 1-10 à implémenter dans le chantier #111 (perspective Q3 2026, ~2-3 semaines).

**Périmètre** :
- Parcours complet d'onboarding depuis `/criar-conta` jusqu'à l'activation effective de la biblio
- États du compte côté solicitante (`solicitante_inicial`, `pendente`, `recusada`, `coordenador_em_constituicao`)
- Workflow d'évaluation côté admins réseau (cooptation unanime)
- Parcours obligatoire de constitution (volet 0 + 10 volets)
- *(v2.0)* Doctrine anti-méga-machine §1.4
- *(v2.0)* Canal humain proactif §5.7 (bouton « proposer un échange » admin → solicitante)
- *(v2.0)* Encadré canal humain dans chaque volet §6.5
- *(v2.0)* PDF règlement comme artefact de délibération §6.6
- *(v2.0)* Section ouverte : parcours d'entrée anarbib.org §6.7
- *(v2.0)* Scénario pédagogique Émile-Henry en annexe normative

**Dépendances entrantes** :
- `spec-administrateur-reseau-v0.4` (workflow cooptation pour l'évaluation des demandes + dépendance mutuelle canal humain)
- `spec-gouvernance-roles v1.1` (rôle coordenador attribué à l'activation)
- `spec-profils-bibliotheque-v0_7` (volet 0 = choix initial du profil d'adoption)
- `docs/decisions/RIFLEXION_articulation_onboarding_profils_2026-05-20.md` (capture conversationnelle origine de la doctrine v2.0)

**Dépendances sortantes** :
- `spec-validation-physique` (à rédiger, non applicable aux solicitantes par définition)
- `spec-migration-compte` (cas limbo_fechamento hors scope onboarding)

**Historique des versions** :
- v1.0 (05/05) : première rédaction, modèle 4 rôles, validation à deux yeux
- v1.1 (15/05) : refonte cohérence post-admin réseau (paquet F) + intégration profils (volet 0)
- **v2.0 (20/05)** : enrichissement doctrinal anti-méga-machine

**Chantiers liés** :
- Paquet F.3 chantier profils (19/05/2026) ✅ clos — livre le volet 0
- **Chantier #111** (perspective Q3 2026) — implémentation des volets 1-10 enrichis anti-méga-machine
- Items MM1-MM5 du backlog v8 — propagent la doctrine indépendamment de #111

**Points d'attention** :
- Cas Karina (18/05/2026, abandon silencieux) traité dans une **spec séparée** : `spec-onboarding-criar-conta.md` (créée le 20/05, sur le parcours public `/criar-conta` antérieur au workflow d'évaluation). Les deux specs sont complémentaires : criar-conta cadre l'entrée publique, onboarding-biblioteca cadre la suite post-soumission.
- Le volet 0 livré le 19/05 n'a **pas encore** l'encadré canal humain (§6.5). Un rétrofit est à prévoir (peut être inclus dans Lot 7 / MM3 ou attendre #111).

---

### 📐 `spec-profils-bibliotheque-v0_7.md`

**Domaine** : Profils d'adoption — 4 axes orthogonaux
**Version actuelle** : v0.7 (19 mai 2026, clôture chantier)
**Versions précédentes** : v0.1 à v0.6 (toutes intermédiaires, à archiver — voir section Maintenance)
**Taille** : ~36 Ko, write-up final
**Statut** : 🟢 Référence post-clôture chantier #98 — **entièrement en prod** sur 3 biblios (BLMF, BTL, BLT-test-informal)

**Périmètre** :
- 4 axes orthogonaux : `catalog_mode`, `circulation_mode`, `network_mode`, `governance_mode`
- Doctrine des transitions (rapide / lente / irréversible)
- Implémentation backend (paquets A-D)
- Frontend painel adaptatif staff (paquet E.0-E.3)
- Frontend compte lecteur·rice adaptatif (paquet E.4)
- Mécanisme de vote sur transitions de profil (paquet E.5)
- Onboarding refondu volet 0 (paquet F)
- Bannière biblios existantes (paquet G)
- Doctrines création objets backend v2.5 + doctrines PowerShell + Git

**Dépendances entrantes** :
- `spec-administrateur-reseau-v0.3.1` (admins valident transitions cross-axes via vote E.5)
- `spec-gouvernance-roles v1.1` (governance_mode pilote rôles staff actifs)
- `spec-flux-consultations-v2.2` (circulation_mode pilote présence onglet Consultas)
- `spec-flux-emprunts` (circulation_mode pilote présence emprunts)
- `spec-onboarding-biblioteca-v2.0` (volet 0 du wizard = choix initial du profil)

**Dépendances sortantes** : aucune — c'est la spec terminale du chantier.

**Historique des versions** :
- v0.1-v0.3 (mai 2026) : itérations cadrage
- v0.4 : version stable du modèle 4 axes orthogonaux
- v0.5 (18/05) : doctrine backend v2.1 + write-up final paquet C
- v0.6 (18/05) : write-up final paquet D + doctrine typage UNION ALL
- **v0.7 (19/05)** : write-up final clôture chantier (paquets E + F + G)

**Chantiers liés** :
- Chantier #98 profils d'adoption (12-20/05/2026) ✅ clos en marathon nocturne le 19/05
- Volumétrie cumulée : 8 jours, ~30h, 11 migrations BDD, 4 hotfix backend, 672 strings i18n × 6 locales, 3 composants frontend, 2 hooks, 3 biblios en prod, 42/42 tests fumée

**Points d'attention** :
- Spec **fermée** : le chantier est clos. Les modifications futures passeront par des chantiers spécifiques (par exemple : extension du modèle 4 axes vers un 5e axe).
- La doctrine anti-méga-machine émergée à la clôture de ce chantier (RIFLEXION du 19/05) **n'est pas inscrite dans cette spec** — elle est inscrite dans `spec-administrateur-reseau-v0.4` et `spec-onboarding-biblioteca-v2.0`. Cohérence à viser dans une éventuelle v0.8 si refonte ultérieure.

---

### 🏛️ `spec-gouvernance-roles.md`

**Domaine** : Gouvernance des rôles dans AnarBib
**Version actuelle** : v1.1 (15 mai 2026)
**Taille** : ~86 Ko
**Statut** : 🟢 Référence — partiellement en prod (carence 7j, audit log, cooptation staff local : tout est implémenté)

**Périmètre** :
- Rôles locaux (`reader`, `librarian`, `coordenador`)
- Status (`active`, `pending_removal`, `removed`, `inactive`)
- Transitions et autorisations
- Cas-limites et garde-fous
- Audit log immuable
- Notifications mail
- RPC SECURITY DEFINER
- Cron jobs (carence)
- *(v1.1)* Conditionnalité par `governance_mode` (intégration profils)

**Dépendances entrantes** : aucune.

**Dépendances sortantes** :
- toutes les specs qui mobilisent les rôles staff locaux

**Historique** :
- v1.0 (05/05/2026)
- **v1.1 (15/05/2026)** : refonte cohérence post-admin réseau + intégration profils

**Chantiers liés** :
- Paquet 11 et plus (rôles + carence + audit log) ✅ clos
- Conditionnalité governance_mode : intégrée dans paquets D-E du chantier profils

**Points d'attention** :
- Mode `informal` (governance_mode = informal) : pas de rôles staff distincts, pas de cooptation, pas de carence, pas d'audit log. Implémenté et testé sur BTL et BLT-test-informal.

---

### 📖 `spec-flux-consultations-v2.2.md`

**Domaine** : Flux des consultations sur place
**Version actuelle** : v2.2 (20 mai 2026)
**Versions précédentes archivées** : v2 dans `archive/`, v2.1 à archiver
**Taille** : ~84 Ko, 1243 lignes
**Statut** : 🟢 Référence — **entièrement en prod**. v2.2 est purement doctrinale technique (aucun nouveau code), inscrit les doctrines #141/#142.

**Périmètre** :
- Cycle de vie d'une consultation (création → agendamento → réalisation/annulation/no-show/expiration)
- Négociation de créneau (matrice transitions)
- RPC publiques `api.*` (5 wrappers)
- Triggers de notification + handler `notify-event/handlers/consultas.ts`
- Surfaces UI (lecteur + bibliothécaire)
- *(v2.2)* 11 doctrines techniques formalisées (R1-R11) dont R7-R11 internalisées au chantier #141

**Dépendances entrantes** :
- `spec-flux-emprunts` (invariant croisé : un holding ne peut pas avoir simultanément un emprunt actif ET une consultation active)
- `spec-workflow-reservation` (modèle de négociation de créneau)
- `spec-administrateur-reseau-v0.4` (doctrine R8 traçabilité coordination)
- `spec-gouvernance-roles v1.1` (rôles staff dans matrice de transitions)
- `spec-profils-bibliotheque-v0_7` (présence onglet conditionnée par circulation_mode)

**Dépendances sortantes** : aucune directe.

**Historique** :
- v1 : première rédaction
- v2 (11/05) : audit Phase 0
- v2.1 (15/05) : refonte post-implémentation, R1-R6 inscrits
- **v2.2 (20/05)** : doctrines R7-R11 internalisées (chantiers #141 + #142)

**Chantiers liés** :
- Paquets 24-27 chantier consultations (12-14/05/2026) ✅ clos
- Chantier #141 hardening notifications (16/05/2026) ✅ clos — 7 bugs résolus
- Chantier #142 mail coordination annulation biblio (17/05/2026) ✅ clos
- Chantier #143 onglet Historique PanelPage (17/05/2026) ✅ clos (sous-paquets 1-3)

**Points d'attention** :
- Phase 6 tests E2E **reportée** au profit de QA manuelle (cf. R6). Reprise possible quand base utilisateur grandit.
- TODO post-v2.2 : propager R7-R11 à `spec-flux-emprunts` et `spec-workflow-reservation` quand pertinent.

---

### 📖 `spec-flux-emprunts.md`

**Domaine** : Flux des emprunts
**Version actuelle** : v1 (10 mai 2026)
**Taille** : ~36 Ko
**Statut** : 🟢 Référence — partiellement en prod, QA à dérouler (item #144 du backlog v8)

**Périmètre** :
- Cycle de vie d'un emprunt (création, prolongation, retour, retard, perte)
- RPC publiques `api.*`
- Triggers de notification
- Surfaces UI (lecteur + bibliothécaire)

**Dépendances entrantes** :
- `spec-flux-consultations-v2.2` (invariant croisé)
- `spec-workflow-reservation` (transition pickup → emprunt)
- `spec-gouvernance-roles v1.1` (rôles staff)

**Dépendances sortantes** :
- `spec-profils-bibliotheque-v0_7` (présence emprunts conditionnée par circulation_mode)

**Historique** :
- v1 (10/05/2026)

**Chantiers liés** :
- Implémentation antérieure (paquets <24) en grande partie
- Doc QA manuelle livré 17/05/2026 (10 scénarios) — à dérouler

**Points d'attention** :
- TODO mise à jour : propager les doctrines R7-R11 internalisées dans `spec-flux-consultations-v2.2` (audit symétrique nécessaire). Doctrine R9 (traçabilité coordination) particulièrement importante pour extensions/renouvellements/retours.
- Pas encore de version v2 — la prochaine mise à jour intégrera les doctrines techniques.

---

### 📖 `spec-workflow-reservation.md`

**Domaine** : Workflow de réservation
**Version actuelle** : v3 sémantique (08 mai 2026)
**Taille** : ~41 Ko
**Statut** : 🟢 Référence — en prod

**Périmètre** :
- États et transitions d'une réservation
- Workflow `pickup_proposed` → `pickup_confirmed` → `emprunt`
- Sémantique des notes d'audit
- Modèle de négociation symétrique (issu de `spec-workflow-reservation-v2-negotiation.md`)

**Dépendances entrantes** :
- `spec-flux-emprunts` (transition pickup → emprunt)
- `spec-refactor-v3-semantique` (doctrine sémantique appliquée — référence historique)

**Dépendances sortantes** :
- `spec-flux-consultations-v2.2` (réutilise le modèle de négociation de créneau)
- `spec-flux-emprunts` (transition vers emprunt)

**Chantiers liés** :
- Paquet 5b refactor v3 sémantique (08/05/2026) ✅ clos

**Points d'attention** :
- Audit recommandé pour propagation des doctrines R7-R11 (ordre UPDATE, traçabilité coordination, etc.)
- Spec mature, peu de besoins immédiats de mise à jour.

---

### 🚪 `spec-migration-compte.md`

**Domaine** : Migration de compte lecteur·rice entre bibliothèques
**Version actuelle** : v1 (04 mai 2026)
**Taille** : ~44 Ko, 940 lignes
**Statut** : 🟡 Spec cadrée, **non implémentée**

**Périmètre** :
- Cas où un·e lecteur·rice change de biblio (déménagement, fermeture de biblio d'origine, autre)
- Workflow de migration avec validation de la biblio d'accueil
- Que transférer (historique, cotisations, etc.), que ne pas transférer
- États intermédiaires (`limbo_fechamento`)

**Dépendances entrantes** :
- `spec-onboarding-biblioteca-v2.0` (référence cas hors scope onboarding)
- `spec-gouvernance-roles v1.1` (rôles préservés ou modifiés)

**Chantiers liés** : aucun pour l'instant.

**Points d'attention** :
- Spec ancienne (04/05, antérieure à toutes les évolutions doctrinales récentes). Une **relecture v2** est probablement nécessaire avant implémentation pour vérifier la cohérence avec admin réseau v0.4, profils v0.7, et la doctrine anti-méga-machine.
- Non priorisée actuellement.

---

### 🚪 `spec-validation-physique.md`

**Domaine** : Validation physique des comptes lecteur·rice
**Version actuelle** : v1 (04 mai 2026)
**Taille** : ~35 Ko
**Statut** : 🟡 Spec cadrée, **non implémentée**

**Périmètre** :
- Workflow de validation physique (rencontre avec librarian) requise dans certains modes
- Hors scope solicitantes (cf. onboarding-biblioteca §1)

**Dépendances entrantes** :
- `spec-onboarding-biblioteca-v2.0` (hors scope solicitantes)
- `spec-gouvernance-roles v1.1`

**Points d'attention** :
- Spec ancienne, à relire avant implémentation pour cohérence avec doctrines récentes.
- Probablement à articuler avec le profil `governance_mode` (mode `validacao_manual` vs `aberto`).

---

### 📧 `spec-migration-mail-resend.md`

**Domaine** : Migration du provider mail Brevo → Resend
**Version actuelle** : v1 (13 mai 2026)
**Taille** : ~162 Ko (très détaillée)
**Statut** : 🟠 En cours d'implémentation (item #110 du backlog v8, score 15)

**Périmètre** :
- Motivation politique (Brevo trace par domaine inaccessible à VPN/anti-tracker, Resend ne trace pas par défaut)
- Cartographie technique existante (handlers, EFs, templates)
- Architecture cible
- Séquence de paquets d'implémentation
- Tests, hardenings, garde-fous
- Risques

**Dépendances entrantes** : aucune.

**Dépendances sortantes** : tous les handlers `notify-event/*` (impact transverse).

**Chantiers liés** :
- Setup sous-domaine Resend (07/05/2026) ✅ fait
- Implémentation en attente (~3-4 jours en mode pragma)

**Points d'attention** :
- Décision politique : Resend choisi pour son absence de tracking par défaut. Cohérent avec l'éthos anarchiste du projet.
- À planifier après spec Karina K1 (priorité immédiate).

---

## 🔵 Specs doctrinales de chantier ponctuel — référence historique

Ces specs documentent des chantiers ponctuels clos. Elles sont **conservées comme références historiques** pour reconstituer le raisonnement passé, mais ne sont **pas mises à jour** : leur doctrine a été absorbée dans les specs de référence.

### `spec-refactor-v3-semantique.md`

**Sujet** : Refactor sémantique du workflow réservation
**Chantier d'origine** : Paquet 5b (08/05/2026, clos)
**Doctrine absorbée dans** : `spec-workflow-reservation.md`
**Taille** : ~10 Ko

### `spec-workflow-reservation-v2-negotiation.md`

**Sujet** : Doctrine de négociation symétrique
**Chantier d'origine** : Pré-paquet 5b (08/05/2026, clos)
**Doctrine absorbée dans** : `spec-workflow-reservation.md` + `spec-flux-consultations-v2.2` §11.2 (modèle réutilisé pour les consultations)
**Taille** : ~12 Ko

### `spec-implementation-114a-network-cooptation.md`

**Sujet** : Doctrine d'implémentation de `notify-event` pour `network.cooptation_*`
**Chantier d'origine** : Chantier #114.A (14/05/2026, clos)
**Doctrine absorbée dans** : `spec-administrateur-reseau-v0.4` §4.5 (events `network.*`)
**Taille** : ~14 Ko

---

## 🗑️ Maintenance du corpus — actions à exécuter

### Specs anciennes versions à archiver

Ces fichiers représentent des **versions antérieures** de specs aujourd'hui remplacées. Ils doivent être **déplacés vers `archive/`** avec un suffixe `-archive-vX.Y` pour conserver la trace historique tout en libérant le dossier principal.

| Fichier actuel | Destination | Raison |
|---|---|---|
| `spec-administrateur-reseau.md` (v0.3.1) | `archive/spec-administrateur-reseau-archive-v0.3.1.md` | Remplacé par `spec-administrateur-reseau-v0.4.md` |
| `spec-flux-consultations.md` (v2.1) | `archive/spec-flux-consultations-archive-v2.1.md` | Remplacé par `spec-flux-consultations-v2.2.md` |
| `spec-onboarding-biblioteca.md` (v1.1) | `archive/spec-onboarding-biblioteca-archive-v1.1.md` | Remplacé par `spec-onboarding-biblioteca-v2.0.md` |
| `spec-profils-bibliotheque.md` (v0.4 ancienne) | `archive/spec-profils-bibliotheque-archive-v0.4.md` | Remplacé par `spec-profils-bibliotheque-v0_7.md` |
| `spec-profils-bibliotheque-v0.5.md` | `archive/spec-profils-bibliotheque-archive-v0.5.md` | Remplacé par `spec-profils-bibliotheque-v0_7.md` |
| `spec-profils-bibliotheque-v0.6.md` | `archive/spec-profils-bibliotheque-archive-v0.6.md` | Remplacé par `spec-profils-bibliotheque-v0_7.md` |
| `spec-flux-consultation-locale.md` | `archive/spec-flux-consultation-locale-archive-v0.md` | Brouillon antérieur du 10/05, absorbé dans `spec-flux-consultations.md` du 15/05 |

### Fichier à supprimer

| Fichier | Action | Raison |
|---|---|---|
| `spec-profils-bibliotheque-v0.3.md.bak` | **Suppression** | Backup automatique périmé du 13/05. Contenu antérieur à v0.5/v0.6/v0.7. Pas de valeur historique (la v0.4 est déjà archivée, v0.3 est encore antérieure). |

### Renommage potentiel des nouvelles specs

Une fois la transition validée, les nouvelles specs avec suffixe `-v2.0` / `-v0.4` / `-v2.2` peuvent **soit conserver leur suffixe**, **soit reprendre le nom canonique** sans suffixe. Choix à trancher selon convention :

- **Option A (conserver suffixe)** : `spec-onboarding-biblioteca-v2.0.md` reste tel quel. Avantage : version visible au premier coup d'œil. Inconvénient : il faudra renommer la prochaine version (v2.1, v3.0).
- **Option B (canoniser)** : renommer en `spec-onboarding-biblioteca.md` après archivage de v1.1. Avantage : lien stable, pas de renommage à chaque version. Inconvénient : la version actuelle doit être lue dans l'en-tête du fichier.

**Pratique actuelle du corpus** : mixte. Certaines specs ont le suffixe (`v0_7`), d'autres non. Recommandation : **canoniser** (Option B) pour les specs stables, **garder suffixe** uniquement pour les versions en transition.

---

## 🔧 Maintenance future

### Quand mettre à jour cet INVENTAIRE

- À chaque nouvelle spec créée
- À chaque promotion d'une spec en version majeure (vX.0 → vX+1.0)
- À chaque chantier clos qui modifie l'état d'implémentation d'une spec
- À chaque réécriture qui modifie les dépendances inter-specs

### Discipline de référencement

Les **dépendances entrantes** et **sortantes** doivent être maintenues à jour. Quand on modifie une spec qui ajoute une dépendance vers une autre, mettre à jour les **deux** specs concernées + cet inventaire.

Les blocs de dépendances en haut de chaque spec **dupliquent volontairement** l'info de cet inventaire pour faciliter la lecture locale. Quand discrepance détectée, l'INVENTAIRE fait foi (et la spec doit être mise à jour).

### Cycle de vie d'une spec

1. **Création** : spec rédigée, ajoutée à `INDEX.md` et `INVENTAIRE.md`
2. **Implémentation** : statut passe de 🟡 cadrée à 🟢 référence ou 🟠 en cours
3. **Évolution mineure** : enrichissement vX.Y → vX.(Y+1), pas de fichier séparé, mise à jour en place + entrée changelog
4. **Évolution majeure** : nouvelle version vX.0 → v(X+1).0, fichier séparé avec suffixe, ancienne version archivée après transition validée
5. **Désuétude** : si la spec devient sans objet (chantier annulé, refonte intégrale), archiver avec mention « obsolète » dans `archive/`

---

*Fin de l'INVENTAIRE. Pour la navigation rapide par domaine, voir `INDEX.md`. Pour relire l'histoire d'un domaine, consulter `archive/`.*
