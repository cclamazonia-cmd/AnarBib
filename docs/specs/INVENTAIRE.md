# 📋 INVENTAIRE du corpus de specs — AnarBib

**Dernière mise à jour** : 4 juin 2026 (soir) — **`spec-outils-federalistes` v0.1 créée** ; **FED-O4/O5/O6 tranchés** (registre §`FED` : terme `círculo` ; adhésion opt-out + anti-blackball ; mutualisation axe distinct) — précédemment : 4 juin 2026 (cadrage `CADRAGE_modele_acces_concentrique_2026-06-04` ajouté à la carte des dépendances ; modèle d'accès concentrique → registre §`FED`) — précédemment : 3 juin 2026 (`#MODEL-item-grain` **constaté livré en prod** [audit dump schéma 03/06] → `spec-granularite-item` en 🔵 ; ouverture Phase 1 exemplares) — précédemment : 2 juin 2026 (trilogie doctrinale figée/charpentée : `spec-partenariat-biblios` v0.3 + `spec-flux-partage-numerique` v0.2, registre enrichi `PARTNER-D7..D9` + section `ILL` ; clôture doc cluster découverte : en-têtes normalisés posés sur les 2 specs OPAC, section `OPAC` ouverte au registre, favoris requalifié serveur OPAC-W1 ; charpente `spec-multi-appartenance-lecteur` v0.3 ajoutée à la carte des dépendances ; renvoi du cadrage corrigé) — précédemment : 1er juin 2026 (réinjection du chantier catalogue : **6 specs** — 4 catalogage + 2 découverte lecteur — carte de dépendances + ordre de mise en œuvre) — précédemment : 31 mai 2026 (audit du corpus, groupe A)
**Maintenu par** : Xavier (lead dev) + Claude (assistant·e)

Ce document décrit **chaque spec active** du corpus AnarBib avec son statut d'implémentation, ses dépendances entrantes et sortantes, sa date de dernière mise à jour, et les chantiers liés. Pour la navigation rapide par domaine, voir [`INDEX.md`](./INDEX.md).

**État du corpus au 31/05/2026** : 22 specs vivantes (21 distinctes — le doublon spec-cartographie-reseau a été résolu le 31/05 avec archivage du .docx) + 17 specs archivées dans `archive/`. Le groupe A de l'audit du 31/05 a été appliqué (notes de clôture sur 3 specs désynchronisées, archivage du doublon, régularisation de 6 fichiers de la convention de nommage archive/).

---

## 🗺️ Carte des dépendances entre specs

Lecture : **A → B** signifie « A dépend de B » (A référence B dans ses dépendances entrantes).

```
spec-onboarding-biblioteca-v2.0
  ├──→ spec-administrateur-reseau-v0.4 (workflow cooptation + canal humain miroir)
  ├──→ spec-gouvernance-roles v1.3 (rôle coordenador à l'activation)
  ├──→ spec-profils-bibliotheque-v0_7 (volet 0 = profil d'adoption)
  ├──→ spec-validation-physique v1.1 (validation par-appartenance)
  └──→ spec-onboarding-criar-conta v0.3 (parcours public antérieur à la soumission)

spec-administrateur-reseau-v0.4
  ├──→ spec-onboarding-biblioteca-v2.0 (dépendance mutuelle, canal humain symétrique)
  ├──→ spec-profils-bibliotheque-v0_7 (transitions de profil = cas critique canal humain)
  └──→ spec-gouvernance-roles v1.3 (séparation staff local / admin réseau)

spec-profils-bibliotheque-v0_7
  ├──→ spec-administrateur-reseau-v0.4 (admins valident transitions cross-axes)
  ├──→ spec-gouvernance-roles v1.3 (governance_mode pilote rôles staff)
  ├──→ spec-flux-consultations-v2.2 (circulation_mode pilote consultations)
  ├──→ spec-flux-emprunts v1.1 (circulation_mode pilote emprunts)
  └──→ spec-onboarding-biblioteca-v2.0 (volet 0 = choix initial profil)

spec-flux-consultations-v2.2
  ├──→ spec-flux-emprunts v1.1 (invariant croisé emprunt-vs-consulta)
  ├──→ spec-workflow-reservation (modèle de négociation de créneau)
  ├──→ spec-administrateur-reseau-v0.4 (doctrine R9 traçabilité coordination)
  ├──→ spec-gouvernance-roles v1.3 (rôles staff dans matrice de transitions)
  └──→ spec-profils-bibliotheque-v0_7 (comportement conditionné par circulation_mode)

spec-flux-emprunts v1.1
  ├──→ spec-flux-consultations-v2.2 (invariant croisé + source normative R7-R11)
  ├──→ spec-workflow-reservation (transitions retrait → emprunt)
  ├──→ spec-gouvernance-roles v1.3 (rôles staff)
  └──→ spec-renouvellement-granulaire (granularité de prolongation par item)

spec-workflow-reservation
  ├──→ spec-flux-emprunts v1.1 (transition pickup → emprunt)
  └──→ spec-refactor-v3-semantique (historique, doctrine sémantique appliquée)

spec-gouvernance-roles v1.3 (autonome, pas de dépendance sortante)

spec-migration-mail-resend (autonome, touche tous les handlers)

spec-onboarding-criar-conta v0.3
  ├──→ spec-onboarding-biblioteca-v2.0 (parcours en aval de la soumission)
  └──→ spec-gouvernance-roles v1.3 (création de compte = bascule potentielle de rôle)

spec-validation-physique v1.1
  ├──→ spec-onboarding-biblioteca-v2.0 (validation côté solicitantes hors scope)
  ├──→ spec-gouvernance-roles v1.3 (validation côté staff local)
  └──→ DECISION_validation_par_appartenance_2026-05-30 (source de l'amendement)

spec-multi-appartenance-lecteur (charpente v0.3 — #CL.10, à remplir)
  ├──→ spec-gouvernance-roles v1.3 (rôle par biblio, Q12/Q15)
  ├──→ spec-validation-physique v1.1 (validation par-appartenance, β.1)
  ├──→ spec-historico-retencao-lectrice v1.0 (history_enabled par biblio, #CL.8)
  ├──→ spec-notifications-lecteur v1.0 (préférences par biblio — F.3 clé composée)
  └──→ spec-partenariat-biblios (transparence enrichie E.3 — parallèle, non bloquante)

spec-partenariat-biblios (charpente v0.3 figée — chantier partenariat stabilisé)
  ├──→ #PARTNERS / library_partnerships (infra déclarative, 24/05)
  ├──→ spec-multi-appartenance-lecteur (transparence enrichie E.3 — parallèle)
  ├──→ spec-gouvernance-roles v1.3 (coordenador propose/accepte, PARTNER-D7)
  └──→ spec-flux-partage-numerique (droit digital_share, PARTNER-D9)

spec-flux-partage-numerique (charpente v0.2 figée — #ILL-digital)
  ├──→ spec-partenariat-biblios (droit du partenariat, ILL-8)
  ├──→ spec-cycle-vie-peb (circuit DISTINCT — renvoi ISBN/ISSN vers PEB)
  ├──→ recursos digitais / ResourcePage (ProtectedMediaViewer)
  └──→ catalogação (visibility CAT-B3 ; verrou libre-de-droits ILL-5)

spec-cycle-vie-peb (autonome — chantier #ILL-lifecycle)
  └──→ spec-flux-consultations-v2.2 (modèle de référence pour machines à états)

spec-granularite-item (chantier #MODEL-item-grain, structurel)
  └──→ spec-flux-consultations-v2.2 (référence d'architecture)

spec-renouvellement-granulaire (chantier #PAINEL E.3/EA-07)
  └──→ spec-flux-emprunts v1.1 (cible des évolutions)

spec-notifications-lecteur v1.0
  ├──→ spec-flux-consultations-v2.2 (table user_notifications gouverne avisos)
  └──→ spec-flux-emprunts v1.1 (idem côté emprunts)

spec-historico-retencao-lectrice v1.0
  └──→ #CL.8 du méga-item conta (cahier Dunkerque §2.8)

spec-notify-prorrogacao-granulaire v0.1
  └──→ #NOTIFY-Painel-acts (chantier transverse notifications Painel)

spec-carte-lecteur-v0_2
  └──→ DECISION_chantier_mobile_arbitrages_2026-05-28 (source des arbitrages A.1-A.4)

spec-cartographie-reseau v0.1
  └──→ #RESEAU-FED (chantier réseau fédératif)

CADRAGE_modele_acces_concentrique_2026-06-04 (trace — accès concentrique + face fédération ; registre §FED)
  ├──→ spec-administrateur-reseau-v0.4 (rede = admin réseau ; círculos n'y appartient pas)
  ├──→ spec-cartographie-reseau v0.1 (carte uMap = gisement de données ; FED-7 verrouille l'agrégat)
  ├──→ #PARTNERS / library_partnerships (agir engage la biblio → coordenador, FED-1/FED-5)
  └──→ CHANTIER_reseau_federatif_2026-05-25 (trace prolongée)

spec-catalogacao-fiche-et-paliers v0.4 (chantier Catalogação — UX/champs, aucune migration DB)
  ├──→ spec-exemplaires-circulation (le padrão fiche sème la destination)
  ├──→ spec-module-capas (emplacement + ancre cover_object_path)
  └──→ spec-sources-externes-autorites (champs viaf/isni/wikidata — niveau autorité, D6)

spec-exemplaires-circulation v0.2 (couche DESTINATION de l'exemplaire)
  ├──→ spec-granularite-item (#MODEL-item-grain — couche TRACE, prérequis matrice §6)
  ├──→ spec-acquisition-provenance (couche PROVENANCE — migration exemplares MUTUALISÉE)
  └──→ spec-catalogacao-fiche-et-paliers (padrão de circulation)

spec-module-capas v0.2 (couverture — EF cover_lookup)
  ├──→ spec-catalogacao-fiche-et-paliers (emplacement réservé §5.3)
  ├──→ spec-exemplaires-circulation (doublon → pas de re-upload de capa)
  └──→ fetch-url-metadata (EF — og:image, 4ᵉ source)

spec-sources-externes-autorites v0.2 (sources de métadonnées + couche autorité)
  ├──→ spec-catalogacao-fiche-et-paliers (champs d'autorité au Completo)
  ├──→ spec-acquisition-provenance (traçabilité de source à l'application d'une candidate)
  └──→ catalog_metadata_lookup + scraper BN Brasil + fetch-url-metadata (EF existantes réutilisées)

spec-catalogue-decouverte v0.1 (couche découverte lecteur — CatalogPage, #OPAC7-11)
  ├──→ spec-flux-emprunts v1.1 (boutons réservation déjà câblés dans la liste)
  ├──→ spec-flux-consultations-v2.2 (boutons consulta déjà câblés)
  ├──→ spec-exemplaires-circulation (filtre catalogue public visibility, en aval)
  └──→ spec-module-capas (vignettes de couverture, optionnel)

spec-notice-autorite-enrichie v0.1 (notice BookPage + autorité AuthorPage, #OPAC1-6/#AUT1-4)
  ├──→ spec-sources-externes-autorites (couche autorité VIAF/ISNI/Wikidata + Atelier)
  ├──→ spec-administrateur-reseau-v0.4 (gouvernance dont l'Atelier s'inspire — consentement sans vote)
  ├──→ spec-module-capas (capa affichée sur la notice, en aval)
  └──→ spec-catalogue-decouverte (brique commune : chips sujets #OPAC8 ↔ §4.2)
```

---

## 📚 Specs de référence — description détaillée

### 🏛️ `spec-administrateur-reseau-v0.4.md`

**Domaine** : Séparation administrateur réseau / staff local
**Version actuelle** : v0.4 (20 mai 2026)
**Versions précédentes archivées** : v0.3, v0.3.1 dans `archive/`
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

**Dépendances entrantes** : aucune dépendance forte — c'est une spec fondatrice.

**Dépendances sortantes** :
- `spec-onboarding-biblioteca-v2.0` (workflow cooptation utilisé pour évaluer les demandes)
- `spec-profils-bibliotheque-v0_7` (admins réseau valident les transitions cross-axes)
- `spec-gouvernance-roles v1.3` (helpers SQL partagés)
- `spec-flux-consultations-v2.2` (doctrine R9 traçabilité coordination)
- `spec-flux-emprunts v1.1` (idem pour les emprunts)

**Historique des versions** : v0.1 → v0.4 (cf. ancien INVENTAIRE pour le détail).

**Chantiers liés** :
- Paquet A-F admin réseau (11-13/05/2026) ✅ clos
- Chantier #114 mails militants (14/05/2026) ✅ clos
- Futur chantier « canal humain proactif biblios membres » (~6-7h, non démarré)

---

### 🚪 `spec-onboarding-biblioteca-v2.0.md`

**Domaine** : Onboarding d'une bibliothèque dans le réseau AnarBib
**Version actuelle** : v2.0 (20 mai 2026)
**Versions précédentes archivées** : v1.0, v1.1 dans `archive/`
**Taille** : ~98 Ko, 1254 lignes
**Statut** : 🟡 — volet 0 livré 19/05/2026 dans le chantier profils. Volets 1-10 à implémenter dans le chantier #111 (perspective Q3 2026, ~2-3 semaines).

**Périmètre** :
- Parcours complet d'onboarding depuis `/criar-conta` jusqu'à l'activation effective de la biblio
- États du compte côté solicitante (`solicitante_inicial`, `pendente`, `recusada`, `coordenador_em_constituicao`)
- Workflow d'évaluation côté admins réseau (cooptation unanime)
- Parcours obligatoire de constitution (volet 0 + 10 volets)
- *(v2.0)* Doctrine anti-méga-machine §1.4 ; canal humain proactif §5.7 ; encadré canal humain §6.5 ; PDF règlement comme artefact de délibération §6.6 ; scénario Émile-Henry en annexe normative

**Dépendances entrantes** :
- `spec-administrateur-reseau-v0.4` (workflow cooptation + canal humain miroir)
- `spec-gouvernance-roles v1.3` (rôle coordenador attribué à l'activation)
- `spec-profils-bibliotheque-v0_7` (volet 0 = choix initial du profil d'adoption)
- `spec-validation-physique v1.1` (post-onboarding pour les memberships créés)
- `spec-onboarding-criar-conta v0.3` (parcours public antérieur à la soumission)
- `docs/decisions/RIFLEXION_articulation_onboarding_profils_2026-05-20.md`

**Dépendances sortantes** : aucune directe.

**Chantiers liés** :
- Paquet F.3 chantier profils (19/05/2026) ✅ clos — livre le volet 0
- **Chantier #111** (perspective Q3 2026) — implémentation des volets 1-10 enrichis
- Items MM1-MM5 du backlog v23 — propagent la doctrine indépendamment de #111

---

### 🚪 `spec-onboarding-criar-conta.md` *(nouveau v0.3 21/05)*

**Domaine** : Onboarding du parcours public `/criar-conta`
**Version actuelle** : v0.3 (21 mai 2026)
**Taille** : ~22 Ko, 579 lignes
**Statut** : 🟡 Brouillon de cadrage actualisé après clôture du chantier #K2. Cœur (paquets 1, 2, 4, 6, 7, 8) prêt à exécuter.

**Périmètre** :
- Restructuration de la page `/criar-conta` pour clarifier les usages possibles d'un compte AnarBib
- Lever l'ambiguïté actuelle entre exploration libre et action sur un catalogue
- Articulation avec le workflow d'évaluation amont (vers spec-onboarding-biblioteca)

**Dépendances entrantes** : aucune.

**Dépendances sortantes** :
- `spec-onboarding-biblioteca-v2.0` (parcours en aval de la soumission)
- `spec-gouvernance-roles v1.3` (création de compte = bascule potentielle de rôle)

**Chantiers liés** :
- Chantier #K2 cas Karina (18-20/05/2026) ✅ clos — origine de cette spec
- Chantiers paquets 1, 2, 4, 6, 7, 8 à exécuter

---

### 🚪 `spec-validation-physique.md` *(amendée v1.1 30/05)*

**Domaine** : Validation physique des comptes lecteur·rice
**Version actuelle** : v1.1 (amendée le 30/05/2026 — validation par-appartenance, pas par-compte)
**Versions précédentes archivées** : v1.0 dans `archive/`
**Taille** : ~33 Ko
**Statut** : 🟡 Cadrée + **amendement structurel 30/05** (validation par-appartenance). En attente d'implémentation.

**Périmètre** :
- Workflow de validation physique (rencontre avec librarian) requise dans certains modes
- **Amendement 30/05** : validation portée par `user_library_memberships`, pas par `profiles`
- Hors scope solicitantes (cf. onboarding-biblioteca §1)

**Dépendances entrantes** :
- `spec-onboarding-biblioteca-v2.0`
- `spec-gouvernance-roles v1.3`
- `docs/decisions/DECISION_validation_par_appartenance_2026-05-30.md`

**Points d'attention** :
- L'amendement structurel précède l'implémentation et indique précisément les sections à ajuster (3, 4, 5, 8). Ne réécrit pas la spec.
- 34 TODO résiduels (essentiellement les questions de migration de l'existant à trancher au moment de l'implémentation).

---

### 📐 `spec-profils-bibliotheque-v0_7.md`

**Domaine** : Profils d'adoption — 4 axes orthogonaux
**Version actuelle** : v0.7 (19 mai 2026, clôture chantier)
**Versions précédentes archivées** : v0.4, v0.5, v0.6 dans `archive/`
**Taille** : ~36 Ko, 840 lignes
**Statut** : 🟢 Référence post-clôture chantier #98 — **entièrement en prod** sur 3 biblios (BLMF, BTL, BLT-test-informal)

**Périmètre** :
- 4 axes orthogonaux : `catalog_mode`, `circulation_mode`, `network_mode`, `governance_mode`
- Doctrine des transitions (rapide / lente / irréversible)
- Implémentation backend (paquets A-D), frontend painel adaptatif staff (paquet E.0-E.3), frontend compte lecteur·rice adaptatif (paquet E.4)
- Mécanisme de vote sur transitions de profil (paquet E.5)
- Onboarding refondu volet 0 (paquet F), bannière biblios existantes (paquet G)

**Dépendances entrantes** :
- `spec-administrateur-reseau-v0.4` (admins valident transitions cross-axes)
- `spec-gouvernance-roles v1.3` (governance_mode pilote rôles staff)
- `spec-flux-consultations-v2.2` (circulation_mode pilote présence onglet)
- `spec-flux-emprunts v1.1` (circulation_mode pilote emprunts)
- `spec-onboarding-biblioteca-v2.0` (volet 0 = choix initial du profil)

**Dépendances sortantes** : aucune — spec terminale du chantier.

**Chantiers liés** :
- Chantier #98 profils d'adoption (12-20/05/2026) ✅ clos en marathon nocturne le 19/05

---

### 🏛️ `spec-gouvernance-roles.md` *(à jour v1.3 24/05)*

**Domaine** : Gouvernance des rôles dans AnarBib
**Version actuelle** : v1.3 (24 mai 2026 — notification coordination au seuil J-7)
**Versions précédentes archivées** : v1.0, v1.1 dans `archive/`
**Taille** : ~88 Ko, 1379 lignes
**Statut** : 🟢 Référence — partiellement en prod (carence 7j, audit log, cooptation staff local : tout est implémenté)

**Périmètre** :
- Rôles locaux (`reader`, `librarian`, `coordenador`)
- Status (`active`, `pending_removal`, `removed`, `inactive`)
- Transitions et autorisations
- *(v1.1)* Conditionnalité par `governance_mode` (intégration profils)
- *(v1.3)* Notification coordination au seuil J-7 du cycle de cooptation

**Dépendances entrantes** : aucune.

**Dépendances sortantes** : toutes les specs qui mobilisent les rôles staff locaux (8 specs dans le corpus).

**Chantiers liés** :
- Paquet 11+ (rôles + carence + audit log) ✅ clos
- Conditionnalité governance_mode : intégrée dans paquets D-E du chantier profils
- Amendement TM-A inscrit 24/05 (cf. `docs/decisions/AMENDEMENT_TM-A_spec-gouvernance-roles_2026-05-24.md`)

---

### 📖 `spec-flux-consultations-v2.2.md`

**Domaine** : Flux des consultations sur place
**Version actuelle** : v2.2 (20 mai 2026)
**Versions précédentes archivées** : v2, v2.1 dans `archive/`
**Taille** : ~84 Ko, 1244 lignes
**Statut** : 🟢 Référence — **entièrement en prod**. v2.2 inscrit les doctrines #141/#142.

**Périmètre** :
- Cycle de vie d'une consultation (création → agendamento → réalisation/annulation/no-show/expiration)
- Négociation de créneau (matrice transitions)
- RPC publiques `api.*` (5 wrappers)
- Triggers de notification + handler `notify-event/handlers/consultas.ts`
- *(v2.2)* 11 doctrines techniques formalisées (R1-R11) dont R7-R11 internalisées au chantier #141

**Dépendances entrantes** :
- `spec-flux-emprunts v1.1` (invariant croisé + propagation R7-R11)
- `spec-workflow-reservation` (modèle de négociation de créneau)
- `spec-administrateur-reseau-v0.4` (doctrine R9 traçabilité coordination)
- `spec-gouvernance-roles v1.3` (rôles staff dans matrice de transitions)
- `spec-profils-bibliotheque-v0_7` (présence onglet conditionnée par circulation_mode)

**Dépendances sortantes** : aucune directe.

**Chantiers liés** :
- Paquets 24-27 chantier consultations (12-14/05/2026) ✅ clos
- Chantier #141 hardening notifications (16/05/2026) ✅ clos — 7 bugs résolus
- Chantier #142 mail coordination annulation biblio (17/05/2026) ✅ clos
- Chantier #143 onglet Historique PanelPage (17/05/2026) ✅ clos

**Points d'attention** :
- TODO post-v2.2 ~~propager R7-R11 à `spec-flux-emprunts`~~ ✅ **fait le 31/05 (v1.1 emprunts)**. Reste à propager à `spec-workflow-reservation` quand pertinent.

---

### 📖 `spec-flux-emprunts.md` *(amendée v1.1 31/05)*

**Domaine** : Flux des emprunts
**Version actuelle** : v1.1 (31 mai 2026 — propagation R7-R11)
**Taille** : ~43 Ko (v1 était ~36 Ko, +7 Ko de §11.3)
**Statut** : 🟢 Référence — partiellement en prod, QA à dérouler (item #144 du backlog v23)

**Périmètre** :
- Cycle de vie d'un emprunt (création, prolongation, retour, retard, perte)
- RPC publiques `api.*`
- Triggers de notification
- Surfaces UI (lecteur + bibliothécaire)
- *(v1.1)* §11.3 doctrines techniques R7-R11 propagées depuis consultas

**Dépendances entrantes** :
- `spec-flux-consultations-v2.2` (invariant croisé + source normative R7-R11)
- `spec-workflow-reservation` (transition pickup → emprunt)
- `spec-gouvernance-roles v1.3` (rôles staff)
- `spec-renouvellement-granulaire` (granularité de prolongation par item)

**Dépendances sortantes** :
- `spec-profils-bibliotheque-v0_7` (présence emprunts conditionnée par circulation_mode)

**Chantiers liés** :
- Implémentation antérieure (paquets <24) en grande partie en prod
- Doc QA manuelle livré 17/05/2026 (10 scénarios) — à dérouler
- Chantier #NOTIFY-prorrogacao (30/05/2026) ✅ clos — exemple d'application correcte de R10

**Points d'attention** :
- Audit R9 à mener : 5 RPC à vérifier pour le mail de coordination (création comptoir, extension staff, retour staff total/partiel, conversion réservation→emprunt).

---

### 📖 `spec-workflow-reservation.md` *(note de clôture 31/05)*

**Domaine** : Workflow de réservation
**Version actuelle** : v3 sémantique (08 mai 2026)
**Taille** : ~40 Ko (v1.0) + 683 bytes de note de clôture (31/05)
**Statut** : 🟢 Référence — **en prod depuis paquet 5b** (09/05/2026). Note de clôture en blockquote signalant l'écart statut interne / réalité.

**Périmètre** :
- États et transitions d'une réservation
- Workflow `pickup_proposed` → `pickup_confirmed` → `emprunt`
- Sémantique des notes d'audit
- Modèle de négociation symétrique (issu de `spec-workflow-reservation-v2-negotiation.md`)

**Dépendances entrantes** :
- `spec-flux-emprunts v1.1` (transition pickup → emprunt)
- `spec-refactor-v3-semantique` (doctrine sémantique appliquée — référence historique)

**Dépendances sortantes** :
- `spec-flux-consultations-v2.2` (réutilise le modèle de négociation de créneau)
- `spec-flux-emprunts v1.1` (transition vers emprunt)

**Chantiers liés** :
- Paquet 5b refactor v3 sémantique (08/05/2026) ✅ clos

**Points d'attention** :
- TODO résiduel : propagation R7-R11 si pertinent (à auditer).

---

### 📖 `spec-renouvellement-granulaire.md` *(nouveau v0.1 29/05)*

**Domaine** : Renouvellement granulaire par item d'emprunt
**Version actuelle** : v0.1 (29 mai 2026 — cadrage initial)
**Taille** : ~8 Ko, 141 lignes
**Statut** : 🟡 Cadrage initial

**Périmètre** :
- Backend (modèle + fonctions de circulation)
- Parcours lecteur (AccountPage)
- Painel (TabEmprestimos)
- Origine : chantier #PAINEL E.3/EA-07 (fusion onglets Empréstimos) — constat que le bouton « Prolonger » agit sur l'emprunt entier, sans possibilité de prolonger un item précis

**Dépendances entrantes** : aucune directe.

**Dépendances sortantes** :
- `spec-flux-emprunts v1.1` (cible des évolutions ; absorbe le mécanisme du payload `line_nos`)

**Chantiers liés** :
- #PAINEL E.3/EA-07 (en cours)

---

### 📖 `spec-cycle-vie-peb.md` *(nouveau v1 23/05)*

**Domaine** : Cycle de vie du prêt interbibliothèques (`#ILL-lifecycle`)
**Version actuelle** : v1 (23 mai 2026 — cadrage)
**Taille** : ~12 Ko, 266 lignes
**Statut** : 🟡 Spécification, à implémenter — chantier `#ILL-lifecycle`

**Périmètre** :
- Machine à états du PEB (création, transit, retour, archivage)
- Spec autonome — aucun pré-requis fonctionnel
- Modèle de référence : `spec-flux-consultations-v2.2.md`

**Dépendances entrantes** : aucune.

**Dépendances sortantes** :
- `spec-flux-consultations-v2.2` (modèle de référence pour la machine à états)

**Chantiers liés** :
- Chantier `#ILL-lifecycle` (backlog v23, non démarré)

---

### 👤 `spec-notifications-lecteur.md` *(nouveau v1.0 31/05)*

**Domaine** : Notifications lecteur·rice (canal in-app)
**Version actuelle** : v1.0 (31 mai 2026)
**Taille** : ~13 Ko, 320 lignes
**Statut** : 🟢 Référence — chantiers #CL.6 et #CL.7 livrés en production le 31/05

**Périmètre** :
- Boîte aux lettres in-app côté `/conta` (table `user_notifications`, onglet `avisos`)
- Articulation avec le canal e-mail (gouverné par `library_notification_policies` et les outboxes par domaine)
- Ne couvre pas le canal e-mail lui-même

**Dépendances entrantes** :
- `spec-flux-consultations-v2.2` (table user_notifications gouverne les avisos des consultas)
- `spec-flux-emprunts v1.1` (idem côté emprunts)

**Dépendances sortantes** : aucune directe.

**Chantiers liés** :
- #CL.6 (centre d'avis / notifications) ✅ livré 31/05
- #CL.7 (mes données / sécurité / rattachement) ✅ livré 31/05

---

### 👤 `spec-historico-retencao-lectrice.md` *(nouveau v1.0 31/05)*

**Domaine** : Maîtrise lectrice de la rétention de son historique
**Version actuelle** : v1.0 (31 mai 2026)
**Taille** : ~32 Ko, 762 lignes
**Statut** : 🟠 En cours — #CL.8 : backend en prod (C.1a/C.2/C.1b), frontend lectrice C.3/C.4 en prod, C.5/C.6 committés en attente de déploiement. Lien #CL.8 cahier Dunkerque §2.8

**Périmètre** :
- Politique de rétention de l'historique lecteur (configurable côté lecteur·rice)
- Articulation avec les obligations RGPD §7.1 (préavis e-mail livré 31/05)
- Effacement / portabilité / déclassement

**Dépendances entrantes** :
- #CL.8 du méga-item conta (cahier Dunkerque §2.8)

**Dépendances sortantes** : aucune directe.

**Chantiers liés** :
- #CL.8 (maîtrise de l'historique par le lecteur) — implémentation en cours (backend + C.3/C.4 en prod, C.5/C.6 en attente de déploiement)

---

### 📩 `spec-notify-prorrogacao-granulaire.md` *(nouveau v0.1 29/05)*

**Domaine** : Notification de prorrogação granulaire
**Version actuelle** : v0.1 (29 mai 2026 — cadrage)
**Taille** : ~7 Ko, 165 lignes
**Statut** : 🟡 Cadrage, lié `#NOTIFY-Painel-acts`

**Périmètre** :
- Refonte de la couche notification pour qu'elle soit granulaire par item (et non plus header-centrée)
- Origine : constat QA Phase 5 du chantier granularité
- Le backend/UI granulaires sont en prod, seule la couche notification restait aveugle à la granularité

**Note** : la version cadrage v0.1 mentionne « à inscrire backlog v18 ». Cette mention est obsolète (backlog actuel = v23). La spec est encore référencée par `#NOTIFY-Painel-acts`.

**Dépendances entrantes** : aucune.

**Dépendances sortantes** :
- `#NOTIFY-Painel-acts` (chantier transverse notifications Painel — inscrit au backlog v23)

---

### 📱 `spec-carte-lecteur-v0_2.md` *(v0.2 03/06 — supersède v0.1 .docx du 28/05)*

**Domaine** : Carte-lecteur AnarBib (β : génération + révocation ; γ : résolution staff)
**Version actuelle** : v0.2 (3 juin 2026)
**Format** : .md (conversion depuis le .docx v0.1, effectuée à cette révision substantielle)
**Statut** : 🟢 **Référence** — phase β en prod (28/05) ; **résolution staff `api.resolve_reader_card` livrée backend le 03/06** (UI staff à venir) ; arbitrages A.1-A.4 actés (A.1 séquençage 🟡 ouvert).

**Périmètre** :
- Mini-table dédiée `reader_card_tokens` (token haché, index unique partiel WHERE status='active')
- RPC `api.generate_my_reader_card` + `api.revoke_my_reader_card` (SECURITY DEFINER)
- Capacité activable `libraries.reader_cards_enabled`
- QR opaque (qrcode), export PNG + PDF (jspdf) anti-tracking
- RPC `api.resolve_reader_card` (résolution staff : jeton scanné/saisi → appartenance, gardée staff `librarian`/`coordenador` + RLS, DEFINER + REVOKE) — **livrée backend 03/06** (esquisse §9 de v0.1 → contrat formalisé §5.3 de v0.2)

**Dépendances entrantes** : aucune.

**Dépendances sortantes** :
- `docs/decisions/DECISION_chantier_mobile_arbitrages_2026-05-28.md` (arbitrages A.1-A.4 et trois décisions doctrinales)
- `REGISTRE_decisions.md` §22 `CARD` (A.1-A.4 + CARD-R1 résolution staff)

**Chantiers liés** :
- Paquet 1 du chantier #MOBILE ✅ livré 28/05
- Paquet 3 (résolution staff) — à venir

---

### 📐 `spec-granularite-item.md` *(nouveau v1 23/05)*

**Domaine** : Unifier la granularité du modèle sur l'exemplaire (`#MODEL-item-grain`)
**Version actuelle** : v1 (23 mai 2026 — cadrage)
**Taille** : ~12 Ko, 270 lignes
**Statut** : 🔵 Référence historique — chantier **livré en production** (constaté 03/06 via dump schéma). Cœur (`item_id` sur `consulta_linhas_v2`, FK RESTRICT, 30 lignes migrées) + suite §6.2 `#ILL-availability` en base ; suite §6.1 (frontend) = dépendance dissoute (résolution serveur depuis le holding). Cf. `docs/decisions/CLOTURE_MODEL-item-grain_2026-06-03.md`.

**Périmètre** :
- Évolution du modèle pour unifier la granularité sur l'exemplaire (item) plutôt que sur le holding ou la transaction
- Chantier `#MODEL-item-grain` (backlog v23 — absorbe l'ancien `#J`)
- Pré-requis : aucun, mais impact transverse sur les flux

**Dépendances entrantes** : aucune.

**Dépendances sortantes** :
- `spec-flux-consultations-v2.2` (référence d'architecture)

**Chantiers liés** :
- `#MODEL-item-grain` — ✅ **livré en prod** (constaté 03/06 ; cœur + `#ILL-availability`). Réalignement couche référence : backlog → section E, registre §7 `ITEM-Q2/Q5` livrés.

---

### 📧 `spec-migration-mail-resend.md`

**Domaine** : Migration du provider mail Brevo → Resend
**Version actuelle** : v0.4 (1er juin 2026 — doctrine de déploiement EF alignée sur le pipeline Woodpecker réel)
**Versions précédentes archivées** : v0.1, v0.2 dans `archive/`
**Taille** : ~162 Ko (très détaillée), 1469 lignes
**Statut** : 🟠 En cours d'implémentation (item #110 du backlog v23, score 15)

**Périmètre** :
- Motivation politique (Brevo trace par domaine inaccessible à VPN/anti-tracker)
- Cartographie technique existante
- Architecture cible, séquence de paquets d'implémentation
- Tests, hardenings, garde-fous

**Dépendances entrantes** : aucune.

**Dépendances sortantes** : tous les handlers `notify-event/*` (impact transverse).

**Chantiers liés** :
- Setup sous-domaine Resend (07/05/2026) ✅ fait
- Sous-paquets R.1, R.2, R.3 ✅ clos 21/05
- R.4 (bascule de `MAIL_PROVIDER`) à venir
- R.6 (suppression effective Brevo) planifiée 05/06/2026

---

### 🌐 `spec-cartographie-reseau.md` *(nouveau v0.1 27/05)*

**Domaine** : Cartographie du réseau AnarBib
**Version actuelle** : v0.1 (27 mai 2026 — squelette d'arbitrages)
**Taille** : ~12 Ko, 355 lignes (.md ; le .docx a été archivé le 31/05 comme doublon)
**Statut** : 🟡 Brouillon — 12 arbitrages à trancher avant évolution en v1.0

**Périmètre** :
- Recensement des bibliothèques libertaires (121 lieux, 24 pays, mai 2026)
- Articulation avec le chantier `#RESEAU-FED`
- Sources : carte uMap externe, fichier `anarbib_bibliotheques_libertaires.geojson`, document de recensement

**Dépendances entrantes** : aucune.

**Dépendances sortantes** :
- `#RESEAU-FED` (chantier réseau fédératif — préalable à spec)

---

### 🗂️ `spec-catalogacao-fiche-et-paliers.md` *(nouveau v0.4 01/06)*

**Domaine** : Fiche de catalogage — registre de champs déclaratif, 3 paliers, lisibilité
**Version actuelle** : v0.4 (1er juin 2026)
**Statut** : 🟡 Spécification, à implémenter — premier lot du chantier Catalogação (**aucune migration DB**)

**Périmètre** :
- Registre de champs déclaratif (archi 8.E), rendu piloté par `tier × matériel`
- Paliers `simple | advanced | complete` (insertion sans remap des valeurs existantes)
- 12 types de matériel × champs, **sourcés sur les guide strings i18n existantes**
- Lisibilité = **adoption des classes `.ab-*`** (le kit fournit déjà relief + anneau de focus)
- i18n 8 locales ; corrections PT-BR *volante* / *lambe-lambe*

**Dépendances entrantes** : `CADRAGE_catalogacao_parite_et_module_capas_2026-06-01` ; maquette v2 (référence visuelle normative).

**Dépendances sortantes** :
- `spec-exemplaires-circulation` (padrão de circulation)
- `spec-module-capas` (emplacement + ancre `cover_object_path`)
- `spec-sources-externes-autorites` (champs d'autorité au Completo)

**Chantiers liés** : chantier Catalogação (cadrage 01/06). Promotion 🟢 après cahier des charges chrome + diff des 7 autres locales.

**Points d'attention** : chrome (header/hero/polices) = harmonisation avec les pages existantes ; arbitrages A1–A3 + D6 actés.

---

### 🗂️ `spec-exemplaires-circulation.md` *(nouveau v0.2 01/06)*

**Domaine** : Couche **destination** de l'exemplaire (`circulation_policy` + `visibility`), doublons fédérés
**Version actuelle** : v0.2 (1er juin 2026)
**Statut** : 🟡 Spécification, à implémenter — **coordonnée** avec `#MODEL-item-grain` + acquisition

**Périmètre** :
- 2 colonnes (`text` + CHECK) sur `exemplares` / `exemplar_drafts`
- padrão (fiche) → seed → override (exemplaire)
- flux **doublon → exemplaire** (blocage publish sur ISBN réseau, `api.attach_exemplar`)
- filtre catalogue public + matrice d'actions + gardes RPC/RLS

**Dépendances entrantes** :
- `spec-granularite-item` (`#MODEL-item-grain` — couche trace)
- `spec-acquisition-provenance` (couche provenance — **migration `exemplares` mutualisée**)
- `spec-catalogacao-fiche-et-paliers` (padrão de circulation)

**Dépendances sortantes** : `spec-module-capas` (pas de re-upload de capa au rattachement d'exemplaire).

**Chantiers liés** : chantier Catalogação. Arbitrages B1–B7 actés.

**Points d'attention** : **migration `exemplares` à co-rédiger** avec acquisition §5.1 (une seule vague) ; la matrice d'actions §6 est **inopérante avant le cœur `#MODEL-item-grain`**.

---

### 🗂️ `spec-module-capas.md` *(nouveau v0.2 01/06)*

**Domaine** : Couverture — stockage stable + recherche automatique (EF `cover_lookup`)
**Version actuelle** : v0.2 (1er juin 2026)
**Statut** : 🟡 Spécification — **P1 (correction du chemin) = bug autonome livrable immédiatement**

**Périmètre** :
- Chemin `bib_ref` / draft-id stable (fin de la collision `books/new/`)
- EF `cover_lookup` : Open Library + Wikimedia + `og:image` (réutil. `fetch-url-metadata`) + page-1-PDF (différé P3)
- UI galerie, anti-tracking (fetch serveur, stockage local), attribution `cover_source` / `cover_license`

**Dépendances entrantes** :
- `spec-catalogacao-fiche-et-paliers` (emplacement réservé §5.3)
- EF existantes `catalog_metadata_lookup` (jumelle) et `fetch-url-metadata` (og:image)

**Dépendances sortantes** : `spec-exemplaires-circulation` (pas de re-upload au rattachement).

**Chantiers liés** : chantier Catalogação. Arbitrages C1–C3 actés.

**Points d'attention** : la capa appartient à la **fiche partagée** (`book_id`) ; le rendu page-1-PDF est lourd → **sous-paquet différé**.

---

### 🗂️ `spec-sources-externes-autorites.md` *(nouveau v0.2 01/06)*

**Domaine** : Sources de métadonnées + couche **autorité** cross-lingue
**Version actuelle** : v0.2 (1er juin 2026)
**Statut** : 🟡 Spécification, à implémenter

**Périmètre** :
- Métadonnées : réactivation **LoC** (gardée), adaptateurs REST **Wikidata / Open Library** dans `catalog_metadata_lookup`
- **BN Brasil** : réutilisation de l'**EF scraper Sophia existante** (manuel en repli)
- Autorité : EF dédiée `authority_lookup`, **Atelier autorités**, `viaf`/`isni` au niveau autorité + `wikidata` aux deux niveaux (D6)

**Dépendances entrantes** :
- `spec-catalogacao-fiche-et-paliers` (champs d'autorité au Completo)
- EF existantes `catalog_metadata_lookup`, scraper BN Brasil, `fetch-url-metadata`

**Dépendances sortantes** : `spec-acquisition-provenance` (traçabilité de source à l'application d'une candidate).

**Chantiers liés** : chantier Catalogação. Arbitrages D1–D6 actés.

**Points d'attention** : scraper BN **fragile** (repli manuel + canari) ; LoC = **diagnostic avant réactivation** ; isoler l'autorité dans sa propre EF.

> **Spec sœur à cataloguer.** `spec-acquisition-provenance-v0_1` (01/06) est couplée au chantier (migration `exemplares` mutualisée, couche provenance) mais relève d'un chantier propre — à doter de sa fiche dans une entrée dédiée.

---

## 🧭 Ordre de mise en œuvre — chantier Catalogação

L'ordre n'est pas celui de rédaction des specs (#1→#4) mais celui des **dépendances dures**. Le **chemin critique est étroit** ; le reste se mène **en parallèle**.

**Chemin critique (séquentiel) :**
- **Phase 0 — `#MODEL-item-grain` cœur** : ✅ **LIVRÉ** (constaté 03/06). `item_id` sur tous les circuits, consultation comprise. Pierre angulaire posée → garde-fou n°2 levé, la **Phase 1 peut démarrer**.
- **Phase 1 — Migration foncière `exemplares` / `exemplar_drafts`, EN UNE SEULE VAGUE** : provenance (acquisition §5.1) **+** destination `circulation_policy`/`visibility` (exemplaires §4.2), backfill + DO-block.
- **Phase 2 — Circulation effective** : padrão→seed→override + matrice d'actions + filtre public + resserrement `#ILL-availability` (dépend de la Phase 0).
- **Phase 3 — Doublons fédérés** : garde au publish + `api.attach_exemplar`.

**Tracks parallèles (peu de dépendances dures) :**
- **Track A** — Catalogação fiche/paliers (#1) : aucune migration DB → **démarrable immédiatement**.
- **Track B** — Capas (#3) : **P1 (fix chemin) livrable tout de suite** ; P2 `cover_lookup` ; P3 page-1-PDF différé.
- **Track C** — Sources/autorités (#4) : LoC (diagnostic→réactivation) → REST (Wikidata/OL) → BN (réutil. scraper) → `authority_lookup`.

**⛔ Garde-fous durs :**
1. **Jamais deux migrations séparées sur `exemplares`** → une seule vague co-rédigée (sinon `relation already exists`).
2. **Jamais la matrice d'actions avant le cœur `#MODEL-item-grain`**.
3. **Jamais réactiver LoC à l'aveugle** → diagnostic d'abord.
4. **Jamais faire dépendre la catalogação de la seule BN auto** (scraper fragile) → repli manuel + canari.
5. **Surveiller la taille de bundle des EF** (cover_lookup + PDF ; authority_lookup) → CLI si > ~150 ko.
6. **Jamais uploader une capa avant save** (collision `books/new/`) → corriger le chemin d'abord.
7. **Déploiement uniforme** : `git push` → Woodpecker pour tout. Jamais MCP `apply_migration`/`deploy_edge_function`, jamais SQL Editor.

---

## 🔎 Catalogue & découverte (lecteur) — cluster #OPAC / #CATALOG-EXT

Couche **lecteur** (affichage / découverte), **en aval** du chantier Catalogação : ces deux specs consomment ce que le catalogage produit (filtre `visibility`, capas, autorités). Issues de l'atelier RebAL du 20/05.

### 🔎 `spec-catalogue-decouverte.md` *(nouveau v0.1 01/06)*

**Domaine** : Page catalogue — couche **découverte** lecteur (facettes à compteurs, nuage de sujets, favoris, parcours)
**Version actuelle** : v0.1 (1er juin 2026 — cadrage)
**Statut** : 🟡 Spécification, à implémenter — cluster #OPAC7–11

**Périmètre** :
- `CatalogPage.jsx`, vues `api.catalog_list_anon_v1` / `catalog_list_session_v1`
- #OPAC7 facettes latérales à compteurs · #OPAC8 nuage de sujets · #OPAC9 favoris (wishlist serveur, OPAC-W1) · #OPAC10 parcours alpha/nouveautés · #OPAC11 courriel/RSS
- Vignettes de couverture (transverse, optionnel)
- **Ne touche aucun flux de circulation** (boutons réservation/consulta déjà câblés)

**Dépendances entrantes** :
- `spec-flux-emprunts` v1.1 et `spec-flux-consultations-v2.2` (boutons déjà câblés)
- `spec-exemplaires-circulation` (filtre catalogue public `visibility`, en aval)
- `spec-module-capas` (vignettes, optionnel)

**Dépendances sortantes** : `spec-notice-autorite-enrichie` (brique commune chips sujets #OPAC8 ↔ §4.2).

**Chantiers liés** : cluster #OPAC / #CATALOG-EXT (atelier RebAL 20/05).

**Points d'attention** : **cloisonnement des compteurs (INV-1)** — agréger sur `*_anon_v1` pour les anonymes, **jamais** sur une vue réseau (régression B.7 déjà corrigée) ; anti-tracking INV-5 (aucun appel tiers) ; reco compteurs = RPC dédiée `api.catalog_facets_v1` (OPAC-F1) régie par `DOC-PERIM-1`. Décisions tracées au **registre §20 `OPAC`** ; favoris = **OPAC-W1** (serveur). En-tête normalisé posé.

---

### 🔎 `spec-notice-autorite-enrichie.md` *(nouveau v0.1 01/06)*

**Domaine** : Fiche de **notice** (`BookPage.jsx`) + fiche d'**autorité** (`AuthorPage.jsx`) — affichage lecteur
**Version actuelle** : v0.1 (1er juin 2026 — cadrage)
**Statut** : 🟡 Spécification, à implémenter — clusters #OPAC1–6 (notice) / #AUT1–4 (autorité)

**Périmètre** :
- Notice : combler le retard sur RebAL (citer, similaires, tags…) en distinguant le réellement manquant du déjà-fait-autrement
- Autorité : dérivations que RebAL ne sait pas faire (réseau intellectuel, sujets, traductions) — **page d'autorité = lieu de mémoire** (réparation historiographique)
- Horizon amont : l'**Atelier autorités** (orientation seulement ; spec dédiée à venir)

**Dépendances entrantes** :
- `spec-sources-externes-autorites` (couche autorité VIAF/ISNI/Wikidata + Atelier)
- `spec-administrateur-reseau-v0.4` (gouvernance dont l'Atelier s'inspire — mais **consentement sans vote**)
- `spec-module-capas` (capa affichée, en aval) ; chantier criar-conta sans biblio (compte contributeur·rice)

**Dépendances sortantes** : `spec-catalogue-decouverte` (brique commune chips sujets).

**Chantiers liés** : cluster #CATALOG-EXT / #AUT. **Annonce** : `spec-atelier-autorites` (future, dédiée).

**Points d'attention** : **INV-3 anti-tracking** — aucun appel client à Wikidata pour enrichir (fuiterait la consultation) ; moissonnage serveur au catalogage uniquement (cohérent capas/sources) ; **préalable structurant** : tables autorités *collectivité* et *matière* à créer (**OPAC-ATL1**, backlog). Décisions tracées au **registre §20 `OPAC`** (favoris **OPAC-W1** acté serveur, similaires/commentaires/MARC/contributeurs requalifiés) ; autorité externe régie par `CAT-D6`. En-tête normalisé posé.

---

## 🔵 Specs doctrinales de chantier ponctuel — référence historique

Ces specs documentent des chantiers ponctuels clos. Elles sont **conservées comme références historiques** pour reconstituer le raisonnement passé, mais ne sont **pas mises à jour** : leur doctrine a été absorbée dans les specs de référence. Chacune porte une **note de clôture en blockquote** en en-tête depuis le 31/05/2026.

### `spec-refactor-v3-semantique.md`

**Sujet** : Refactor sémantique du workflow réservation
**Chantier d'origine** : Paquet 5b (08/05/2026, clos)
**Doctrine absorbée dans** : `spec-workflow-reservation.md`
**Taille** : ~10 Ko (+ note de clôture 31/05)
**Note de clôture** : ajoutée en blockquote 31/05/2026 — précise que la doctrine est appliquée et que la spec sert désormais à reconstituer le raisonnement.

### `spec-workflow-reservation-v2-negotiation.md`

**Sujet** : Doctrine de négociation symétrique
**Chantier d'origine** : Pré-paquet 5b (08/05/2026, clos)
**Doctrine absorbée dans** : `spec-workflow-reservation.md` + `spec-flux-consultations-v2.2`
**Taille** : ~12 Ko

### `spec-implementation-114a-network-cooptation.md`

**Sujet** : Doctrine d'implémentation de `notify-event` pour `network.cooptation_*`
**Chantier d'origine** : Chantier #114.A (14/05/2026, clos)
**Doctrine absorbée dans** : `spec-administrateur-reseau-v0.4` §4.5
**Taille** : ~14 Ko (+ note de clôture 31/05)
**Note de clôture** : ajoutée en blockquote 31/05/2026 — confirme la clôture du chantier et inscrit la spec en référence historique.

---

## 🔧 Maintenance du corpus

### Cycle de vie d'une spec

1. **Création** : spec rédigée, ajoutée à `INDEX.md` et `INVENTAIRE.md`
2. **Implémentation** : statut passe de 🟡 cadrée à 🟢 référence ou 🟠 en cours
3. **Évolution mineure** : enrichissement vX.Y → vX.(Y+1), pas de fichier séparé, mise à jour en place + entrée changelog (exemple récent : `spec-flux-emprunts v1 → v1.1` le 31/05)
4. **Évolution majeure** : nouvelle version vX.0 → v(X+1).0, fichier séparé avec suffixe, ancienne version archivée après transition validée
5. **Désuétude / clôture** : si la spec devient référence historique (chantier clos, doctrine absorbée ailleurs), ajouter une **note de clôture en blockquote** en en-tête signalant le nouveau statut sans toucher au corps. Cf. pattern appliqué au groupe A le 31/05.

### Quand mettre à jour cet INVENTAIRE

- À chaque nouvelle spec créée
- À chaque promotion d'une spec en version majeure (vX.0 → vX+1.0)
- À chaque chantier clos qui modifie l'état d'implémentation d'une spec
- À chaque réécriture qui modifie les dépendances inter-specs
- À chaque application d'une note de clôture sur une spec qui passe en référence historique

### Discipline de référencement

Les **dépendances entrantes** et **sortantes** doivent être maintenues à jour. Quand on modifie une spec qui ajoute une dépendance vers une autre, mettre à jour les **deux** specs concernées + cet inventaire. Les blocs de dépendances en haut de chaque spec **dupliquent volontairement** l'info de cet inventaire pour faciliter la lecture locale. Quand discrepance détectée, l'INVENTAIRE fait foi (et la spec doit être mise à jour).

### Specs annoncées, non encore remplies

- **`spec-multi-appartenance-lecteur`** : **charpente v0.3 figée**, intégrée au corpus (famille #CL — voir la carte des dépendances ci-dessus). Socle doctrinal : `CADRAGE_spec-multi-appartenance-lecteur_2026-05-31.md` (doc de décision dédié — *et non « backlog v23 §A.1 », renvoi corrigé le 02/06*). Absorbe `spec-migration-compte.md v1.0` (archivée) — cf. `ACCT-MIGRATION` au registre. Remplissage (~800 l.) en session dédiée.
- **`spec-partenariat-biblios`** : **charpente figée v0.3 le 02/06** (`PARTNER-D1..D9` au registre ; cadrage `CADRAGE_partenariat_stabilise_2026-06-02.md`). Dossier d'ouverture constitué ; remplissage à venir, après multi-appartenance.
- **`spec-flux-partage-numerique`** (#ILL-digital) : **charpente figée v0.2 le 02/06** côté conception (`ILL-1..ILL-9` au registre, mandat BLMF ; cadrage `CADRAGE_ILL-digital_2026-05-25` 🔵). Circuit numérique **distinct du PEB** ; droit du partenariat stabilisé (`PARTNER-D9`). Remplissage à venir (DDL, rôles, i18n).
- **`spec-outils-federalistes`** (face fédération) : **v0.1 créée 🟡 cadrée** — cœur = socle + primitive cercle (`círculo`) : annuaire, adhésion opt-out + anti-blackball (FED-O5), cycle de vie ; mutualisation = axe distinct renvoyé (FED-O6). Foyer registre §`FED` (FED-1..7 + FED-O4/O5/O6 tranchés) ; cadrage `CADRAGE_modele_acces_concentrique_2026-06-04.md`. Bloc « Ferramentas federalistas » (nav entre `biblioteca` et `rede`). Prolonge `CHANTIER_reseau_federatif_2026-05-25`. Autres onglets charpentés/renvoyés ; remplissage code à venir.

---

*Fin de l'INVENTAIRE. Pour la navigation rapide par domaine, voir `INDEX.md`. Pour relire l'histoire d'un domaine, consulter `archive/`.*
