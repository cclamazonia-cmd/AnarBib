# 📚 INDEX du corpus de specs — AnarBib

**Dernière mise à jour** : 5 juin 2026 — chantier **Importações/Exportações** charpenté : `spec-importacoes-exportacoes` v0.1 créée (squelette, **§9 wizard cadré**) ; registre **§17 `IMP-1..8`** ; maquettes de référence (tableau de bord v7 + wizard v1) — précédemment : 4 juin 2026 (nuit) — carte-lecteur **phase γ complète** (UI staff `ResolveCardBox` livrée, **gatée `libraries.reader_cards_enabled`** : invisible là où la carte n'est pas activée — hotfix Woodpecker vert) ; **`CADRAGE_importacoes_module_2026-06-04` ouvert** (chantier-cadre Importações ; registre §`IMP` ; **défère** `ACQ-Q4` frontière Catalogação + `FED-5` rôle coordenador) ; `DOC-I18N-1` réaligné **9 locales** (`nl`) — précédemment : 4 juin 2026 (soir) — **`spec-outils-federalistes` v0.1 créée** (face fédération + primitive cercle `círculo` ; cœur socle + cercles) ; **arbitrages FED-O4/O5/O6 tranchés** au registre §`FED` (terme `círculo` ; adhésion opt-out + anti-blackball B ; mutualisation = axe distinct, opt-in biblio multi-cercles) — précédemment : 4 juin 2026 (**section `FED`** au registre : modèle d'accès concentrique + face fédération « Ferramentas federalistas », `círculos` relocalisé hors `rede` ; cadrage `CADRAGE_modele_acces_concentrique_2026-06-04.md`) — précédemment : 3 juin 2026 (soir) — **dette ponctuelle soldée** (verrou `get_accessible_digital_asset` selon DOC-OBJ-2 ; **USER-EMAIL-1** : `profiles.email` rendu miroir synchronisé de `auth.users.email`, registre §0) + **carte-lecteur v0.2** (résolution staff `api.resolve_reader_card` livrée backend, contrat des 3 RPC, section `CARD` au registre §22) — précédemment : 3 juin 2026 (`#MODEL-item-grain` **constaté livré en prod** via audit du dump schéma 03/06 → `spec-granularite-item` passe en 🔵 référence historique [cœur + suite `#ILL-availability`] ; ouverture Phase 1 exemplares, cf. `docs/decisions/`) — précédemment : 2 juin 2026 (trilogie doctrinale : `spec-multi-appartenance-lecteur` v0.3 + `spec-partenariat-biblios` v0.3 figées, `spec-flux-partage-numerique` v0.2 charpentée ; registre enrichi MULTI/PARTNER/ILL/VALID-β1-γ1) — précédemment : 1er juin 2026 (réinjection du chantier catalogue : **6 specs** — 4 catalogage + 2 découverte lecteur — + ordre de mise en œuvre) — précédemment : statut #CL.8 actualisé ; 31 mai 2026 (audit du corpus, groupe A, refonte INDEX/INVENTAIRE)
**Maintenu par** : Xavier (lead dev) + Claude (assistant·e)

Ce document est la **porte d'entrée** du corpus de specs. Pour la description détaillée de chaque spec (statut d'implémentation, dépendances, dates, chantiers liés), voir [`INVENTAIRE.md`](./INVENTAIRE.md).

---

## ⚠️ Préséance & source de vérité *(à lire en premier — humain comme IA)*

**En cas de conflit entre deux textes, l'ordre de préséance est :**

1. **[`REGISTRE_decisions.md`](./REGISTRE_decisions.md)** — foyer unique des **décisions** (arbitrages) et des **doctrines transverses**. Source de vérité sur *ce qui a été choisi et si ça tient encore*. On cite ses IDs (`DOC-…`, `RES-…`, `CAT-…`), on ne reformule jamais une décision ailleurs.
2. **La spec courante** du domaine (version la plus récente) — source de vérité sur *le design/comportement*.
3. **Le backlog** (`AnarBib-Backlog-…-vN.docx`) — source de vérité sur *l'état et les priorités*.

**Tout le reste est de la *trace* non-normative** : `CADRAGE_*`, `CHANTIER_*`, `SESSION_*`, `BILAN_*`, `AUDIT_*`, `QA_*`. Une trace enregistre un raisonnement à un instant T ; sur un conflit avec la couche référence ci-dessus, **la trace est périmée par définition**.

**Faits transverses gouvernés par le registre** (ne pas s'y fier depuis une spec isolée) :
- **Nombre de locales = 8** (`DOC-I18N-1`). *Tout « 6 locales » lu dans une spec est une trace périmée, pas une consigne.*
- **Déploiement** = `git push` → Woodpecker (`DOC-DEPLOY-1/2/3`).
- **RPC v3** (`DOC-RPC-3`), **compteurs « page = périmètre »** (`DOC-PERIM-1`), création d'objets backend v2 (`DOC-OBJ-2`).

> État des drifts connus et corrections en une touche : [`AUDIT_coherence_corpus_2026-06-02.md`](../decisions/AUDIT_coherence_corpus_2026-06-02.md).

---

## 🔍 Navigation par domaine

### 🏛️ Gouvernance et structure

| Domaine | Spec de référence | Version | Statut |
|---|---|---|---|
| Administration réseau | [`spec-administrateur-reseau-v0.4.md`](./spec-administrateur-reseau-v0.4.md) | v0.4 (20/05/2026) | 🟢 Référence — v0.3.1 en prod, enrichissements v0.4 à implémenter |
| Gouvernance locale (rôles, status, transitions) | [`spec-gouvernance-roles.md`](./spec-gouvernance-roles.md) | v1.3 (24/05/2026) | 🟢 Référence — partiellement en prod |
| Profils d'adoption (4 axes orthogonaux) | [`spec-profils-bibliotheque-v0_7.md`](./spec-profils-bibliotheque-v0_7.md) | v0.7 (19/05/2026) | 🟢 Référence post-clôture chantier #98 — entièrement en prod |

### 🚪 Onboarding et compte lecteur

| Domaine | Spec de référence | Version | Statut |
|---|---|---|---|
| Onboarding d'une bibliothèque | [`spec-onboarding-biblioteca-v2.0.md`](./spec-onboarding-biblioteca-v2.0.md) | v2.0 (20/05/2026) | 🟡 volet 0 livré, volets 1-10 perspective Q3 2026 (chantier #111) |
| Onboarding `/criar-conta` | [`spec-onboarding-criar-conta.md`](./spec-onboarding-criar-conta.md) | v0.3 (21/05/2026) | 🟡 Brouillon de cadrage, cœur (paquets 1, 2, 4, 6, 7, 8) prêt à exécuter |
| Validation physique du compte lecteur·rice | [`spec-validation-physique.md`](./spec-validation-physique.md) | v1.1 (30/05/2026) | 🟡 Cadrée + amendement structurel (validation par-appartenance) |

### 📖 Flux opérationnels (circulation)

| Domaine | Spec de référence | Version | Statut |
|---|---|---|---|
| Consultations sur place | [`spec-flux-consultations-v2.2.md`](./spec-flux-consultations-v2.2.md) | v2.2 (20/05/2026) | 🟢 Référence — entièrement en prod, doctrines R1-R11 internalisées |
| Emprunts | [`spec-flux-emprunts.md`](./spec-flux-emprunts.md) | v1.1 (31/05/2026) | 🟢 Référence — partiellement en prod, doctrines R7-R11 propagées |
| Workflow de réservation | [`spec-workflow-reservation.md`](./spec-workflow-reservation.md) | v3 sémantique (08/05/2026) | 🟢 Référence — en prod depuis paquet 5b |
| Renouvellement granulaire par item | [`spec-renouvellement-granulaire.md`](./spec-renouvellement-granulaire.md) | v0.1 (29/05/2026) | 🟡 Cadrage initial, lié #PAINEL E.3/EA-07 |
| Cycle de vie du PEB | [`spec-cycle-vie-peb.md`](./spec-cycle-vie-peb.md) | v1 (23/05/2026) | 🟡 Spec autonome, chantier #ILL-lifecycle à venir |

### 👤 Compte lecteur — méga-item #CL *(nouveau famille)*

| Domaine | Spec de référence | Version | Statut |
|---|---|---|---|
| Notifications lecteur·rice (canal in-app) | [`spec-notifications-lecteur.md`](./spec-notifications-lecteur.md) | v1.0 (31/05/2026) | 🟢 Référence — lien #CL.6 et #CL.7 livrés |
| Maîtrise lectrice de la rétention de l'historique | [`spec-historico-retencao-lectrice.md`](./spec-historico-retencao-lectrice.md) | v1.0 (31/05/2026) | 🟠 En cours — #CL.8 : backend + C.3/C.4 en prod, C.5/C.6 en attente de déploiement |
| Notification de prorrogação granulaire | [`spec-notify-prorrogacao-granulaire.md`](./spec-notify-prorrogacao-granulaire.md) | v0.1 (29/05/2026) | 🟡 Cadrage, lié `#NOTIFY-Painel-acts` |
| Multi-appartenance lectrice (plusieurs biblios) | [`spec-multi-appartenance-lecteur.md`](./spec-multi-appartenance-lecteur.md) | v0.3 (02/06/2026) | 🟡 Charpente figée — arbitrée, audit Zone 23 intégré ; remplissage à venir (lié #CL.10). Absorbe `spec-migration-compte` |

### 📱 Mode terrain / mobile *(nouveau famille)*

| Domaine | Spec de référence | Version | Statut |
|---|---|---|---|
| Carte-lecteur AnarBib | [`spec-carte-lecteur-v0_2.md`](./spec-carte-lecteur-v0_2.md) | v0.2 (03/06/2026) | 🟢 Référence — phase β en prod (génération + révocation) ; **résolution staff `api.resolve_reader_card` livrée backend (03/06) + UI staff `ResolveCardBox` (04/06, gatée `reader_cards_enabled`)** — **phase γ complète** ; arbitrages A.1-A.4 actés (A.1 séquençage 🟡 ouvert). Supersède v0.1 (.docx, 28/05 → archive) |

### 📐 Modélisation structurelle *(nouveau famille)*

| Domaine | Spec de référence | Version | Statut |
|---|---|---|---|
| Granularité du modèle sur l'exemplaire | [`spec-granularite-item.md`](./spec-granularite-item.md) | v1 (23/05/2026) | 🔵 Référence historique — chantier `#MODEL-item-grain` **livré en prod** (cœur + suite `#ILL-availability`, constaté 03/06) |

### 🗂️ Catalogação *(nouvelle famille — chantier Catalogação, 01/06)*

| Domaine | Spec de référence | Version | Statut |
|---|---|---|---|
| Fiche, registre & paliers | [`spec-catalogacao-fiche-et-paliers.md`](./spec-catalogacao-fiche-et-paliers.md) | v0.4 (01/06/2026) | 🟡 Spécifiée — premier lot (aucune migration DB) |
| Exemplaires : circulation & doublons | [`spec-exemplaires-circulation.md`](./spec-exemplaires-circulation.md) | v0.2 (01/06/2026) | 🟡 Spécifiée — coordonnée item-grain + acquisition |
| Module capas | [`spec-module-capas.md`](./spec-module-capas.md) | v0.2 (01/06/2026) | 🟡 Spécifiée — P1 (fix chemin) livrable immédiatement |
| Sources externes & autorités | [`spec-sources-externes-autorites.md`](./spec-sources-externes-autorites.md) | v0.2 (01/06/2026) | 🟡 Spécifiée |

> Chantier coordonné avec `spec-granularite-item` (`#MODEL-item-grain`, couche *trace* — **livrée en prod**) et `spec-acquisition-provenance` (couche *provenance* — migration `exemplares` **mutualisée**). Ordre de mise en œuvre et garde-fous : voir `INVENTAIRE.md` § « Ordre de mise en œuvre — chantier Catalogação ».

### 🔎 Catalogue & découverte (lecteur) *(nouvelle famille — atelier RebAL, #OPAC / #CATALOG-EXT)*

| Domaine | Spec de référence | Version | Statut |
|---|---|---|---|
| Page catalogue — couche découverte (facettes, sujets, favoris, parcours) | [`spec-catalogue-decouverte.md`](./spec-catalogue-decouverte.md) | v0.1 (01/06/2026) | 🟡 Cadrage — cluster #OPAC7–11 |
| Notice & autorités enrichies (BookPage / AuthorPage) | [`spec-notice-autorite-enrichie.md`](./spec-notice-autorite-enrichie.md) | v0.1 (01/06/2026) | 🟡 Cadrage — #OPAC1–6 / #AUT1–4 |

> Couche **lecteur** (affichage / découverte), **en aval** du chantier Catalogação : consomme le filtre `visibility` (exemplaires #2), les capas (module capas #3) et la couche autorité (sources & autorités #4). Lignes rouges : anti-tracking (aucun appel tiers révélant une consultation) + autonomie (cloisonnement des compteurs). Annonce une spec dédiée `spec-atelier-autorites`.

### 📧 Infrastructure transverse

| Domaine | Spec de référence | Version | Statut |
|---|---|---|---|
| Migration mail Brevo → Resend | [`spec-migration-mail-resend.md`](./spec-migration-mail-resend.md) | v0.4 (01/06/2026) | 🟠 En cours (R.1/R.2/R.3 clos, R.4 à venir, R.6 le 05/06 ; doctrine déploiement EF corrigée v0.4) |
| Cartographie du réseau AnarBib | [`spec-cartographie-reseau.md`](./spec-cartographie-reseau.md) | v0.1 (27/05/2026) | 🟡 Brouillon, 12 arbitrages à trancher, lié `#RESEAU-FED` |

### 🔵 Specs doctrinales de chantier ponctuel — référence historique

Ces specs documentent des chantiers ponctuels clos et servent de **références historiques** pour reconstituer le raisonnement. Elles ne sont **pas** des specs vivantes — la doctrine qu'elles portent a été absorbée dans les specs de référence ci-dessus. Chaque spec porte désormais une **note de clôture en blockquote** en en-tête signalant l'état réel.

| Spec | Sujet | Chantier d'origine | Statut |
|---|---|---|---|
| [`spec-refactor-v3-semantique.md`](./spec-refactor-v3-semantique.md) | Refactor sémantique du workflow réservation | Paquet 5b (08/05/2026, clos) | 🔵 Référence historique (note de clôture 31/05) |
| [`spec-workflow-reservation-v2-negotiation.md`](./spec-workflow-reservation-v2-negotiation.md) | Doctrine de négociation symétrique réservation | Pré-paquet 5b (08/05/2026, clos) | 🔵 Référence historique |
| [`spec-implementation-114a-network-cooptation.md`](./spec-implementation-114a-network-cooptation.md) | Doctrine d'implémentation de `notify-event` pour `network.cooptation_*` | Chantier #114.A (14/05/2026, clos) | 🔵 Référence historique (note de clôture 31/05) |

---

## 🗓️ Lecture prioritaire de l'état doctrinal courant

Cinq specs constituent la lecture prioritaire pour comprendre l'état doctrinal actuel du projet :

1. **[`spec-onboarding-biblioteca-v2.0.md`](./spec-onboarding-biblioteca-v2.0.md)** — la spec la plus impactée par la doctrine anti-méga-machine (§1.4, §5.7, §6.5, §6.6, annexe Émile-Henry).
2. **[`spec-administrateur-reseau-v0.4.md`](./spec-administrateur-reseau-v0.4.md)** — préambule politique enrichi, §4.7 canal humain proactif, §8.8 risque burnout admin réseau.
3. **[`spec-flux-consultations-v2.2.md`](./spec-flux-consultations-v2.2.md)** — doctrines techniques R1-R11, source normative pour les autres specs flux.
4. **[`spec-flux-emprunts.md`](./spec-flux-emprunts.md)** *(v1.1 du 31/05)* — propagation des doctrines R7-R11 depuis consultas, audit R9 (traçabilité coordination) inscrit.
5. **[`spec-validation-physique.md`](./spec-validation-physique.md)** *(amendement 30/05)* — bascule structurelle vers la validation par-appartenance (et non plus par-compte).

---

## 🆕 Specs annoncées (cadrées, pas encore remplies)

- **`spec-partenariat-biblios`** — **charpente figée v0.3 le 02/06** (`PARTNER-D1..D9` au registre ; cadrage `CADRAGE_partenariat_stabilise_2026-06-02.md`). Prolongement du chantier `#PARTNERS` livré le 24/05. Remplissage à venir, après `spec-multi-appartenance-lecteur`.
- **`spec-flux-partage-numerique`** (#ILL-digital) — circuit d'envoi de documents numériques entre biblios partenaires (`CADRAGE_ILL-digital_2026-05-25`). **Charpente figée v0.2 le 02/06** (`ILL-1..ILL-9` au registre, mandat BLMF) ; remplissage à venir.
- **`spec-atelier-autorites`** — annonce d'intention (vitrine `anarbib.org`) : face *contribution* de la couche d'autorités (file de propositions, gouvernance par consentement sans vote, autorités collectivité/matière). Préparée frontend par `spec-notice-autorite-enrichie` §5 ; à rédiger après stabilisation du catalogage. Préalable structurant : tables autorités *collectivité* et *matière*.
- **`spec-outils-federalistes`** (face fédération) — **v0.1 créée 🟡 cadrée** (`docs/specs/`) : bloc « Ferramentas federalistas » de la nav (entre `biblioteca` et `rede`), cœur rempli = socle + **primitive cercle** (`círculo`) — annuaire des cercles ouverts, adhésion opt-out + anti-blackball, cycle de vie (vue 1ʳᵉ personne : lecture membres / action coordenador). Foyer : **registre §`FED`** (FED-1..7 + FED-O4/O5/O6 tranchés) + cadrage `CADRAGE_modele_acces_concentrique_2026-06-04.md`. Autres onglets charpentés/renvoyés ; remplissage code à venir.

- **Importações/Exportações** (module bidirectionnel : ingestion technique ⇄ export) — **`spec-importacoes-exportacoes` v0.1 créée 🟡 squelette** (`docs/specs/`). Plomberie de provenance déjà posée (`catalog_ref_*`, cible `book_drafts`, journal `book_draft_import_events`, staging BLMF + Zotero) ; couche format = **adaptateurs** (structure × vocabulaire × modèle). Doctrine au **registre §17 `IMP-1..8`** (`IMP-1..7` actés ; `IMP-8` wizard §9 **cadré**). Frontière `ACQ-Q4` (ingestion → `book_drafts`) ; export référence `ILL-1..9` (`spec-flux-partage-numerique`). Réf. visuelles : `maquette_importacoes_v7.html` (tableau de bord) + `maquette_wizard_import_v1.html` (assistant). Reste : DDL « run d'import » + ratification rôles (`spec-gouvernance-roles`) + remplissage (§12). Le **cadrage 04/06** (`CADRAGE_importacoes_module`, trace) est **supersédé** : son schéma `IMP-A1..A5` est remplacé par `IMP-1..8` (REGISTRE §17) + points ouverts §12 (préséance registre > trace).

> `spec-multi-appartenance-lecteur` a quitté cette liste : sa charpente v0.3 est désormais une spec du corpus (famille « Compte lecteur — #CL »), au statut 🟡 cadrée.

---

## 📂 Conventions du corpus

### Versionnement des specs

- **vX.Y entière** : refonte structurelle de la spec (peu fréquent, exemple : onboarding v1.0 → v2.0).
- **vX.Y mineure** : enrichissement ciblé, ajout de sections sans casser la structure existante (exemple : admin réseau v0.3 → v0.4, flux-emprunts v1 → v1.1).
- **Suffixe `-vX.Y.md`** : utilisé pour distinguer la nouvelle version de la version actuelle pendant la transition. Quand la nouvelle version est validée comme référence, l'ancienne va dans `archive/` avec un suffixe `-archive-vX.Y.md` et la nouvelle peut soit garder son suffixe, soit reprendre le nom canonique (sans suffixe).

### Dossier `archive/`

Contient les **anciennes versions** des specs remplacées par une version plus récente. À conserver pour la traçabilité historique (relire le raisonnement passé, comprendre les évolutions doctrinales). Ne **jamais supprimer** une spec archivée — elle peut être utile dans 6 mois.

**Convention de nommage régularisée 31/05/2026** : tous les fichiers d'archive suivent désormais le pattern `spec-X-archive-vY.Z.md`. Six fichiers ont été renommés à cette occasion pour s'aligner sur la convention majoritaire.

### Statuts visuels utilisés dans ce corpus

- 🟢 **Référence** : spec à jour, à utiliser comme source de vérité
- 🟠 **En cours** : spec d'un chantier en cours d'implémentation
- 🟡 **Cadrée non implémentée** : spec écrite mais pas encore exécutée
- 🔵 **Référence historique** : spec d'un chantier ponctuel clos, à conserver mais pas à modifier (portent désormais une note de clôture en blockquote)
- 🔴 **Obsolète** : spec à archiver/supprimer (n'apparaît pas dans cet INDEX, voir `archive/`)

### Liens entre specs

Les specs se référencent mutuellement par chemin relatif (`./spec-X.md`). Les blocs d'en-tête de chaque spec listent ses **dépendances entrantes** (specs sur lesquelles elle s'appuie) et idéalement ses **dépendances sortantes** (specs qui s'appuient sur elle). Voir `INVENTAIRE.md` pour la carte complète des dépendances.

---

## 🧭 Comment utiliser cet INDEX

**Pour démarrer un nouveau chantier** : identifier la spec de référence du domaine concerné, lire son en-tête (statut, dépendances), puis consulter `INVENTAIRE.md` pour comprendre quels chantiers passés ou en cours touchent ce domaine.

**Pour comprendre un bug en prod** : si le bug touche un flux (consultas, emprunts, réservations, onboarding, gouvernance), consulter la spec de référence du domaine. Les sections « §11.2 ou §11.3 raffinements doctrinaux » (pour consultas et emprunts) inscrivent les doctrines techniques internalisées au fil des chantiers (R1 à R11).

**Pour vérifier l'articulation entre specs** : `INVENTAIRE.md` contient la **carte des dépendances mutuelles**. Quand on modifie une spec, vérifier qui dépend d'elle pour cascade éventuelle.

**Pour archiver une spec** : voir la section « Cycle de vie d'une spec » de `INVENTAIRE.md`.

---

*Fin de l'INDEX. Pour la description détaillée de chaque spec, voir `INVENTAIRE.md`.*
