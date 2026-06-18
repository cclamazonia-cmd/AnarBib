# 📚 INDEX du corpus de specs — AnarBib

**Dernière mise à jour** : 5 juin 2026 (session soir) — **Track A catalogação complet** (Lots 1→6 + 3b) + **module capas P1/P2/P3** (P3 page-1-PDF **côté client**) ; **liaison autorités↔œuvres** (`fn_normalize_name`, trigger contributeurs→book_authors, RPC matching + outil « Rattacher aux œuvres ») ; **fusion de doublons** autorités **et** documents (`merge_log`, `merge_author`, `merge_book`) ; **flux contributeurs** brouillon→publié (triggers seed+sync, préservation `author_id`) ; fiche livre affiche tous les contributeurs. **3 specs nouvelles** : `spec-autorites-notes-bio-multilingues` v0.2, `spec-liaison-autorites-oeuvres` v0.2, `spec-doublons-detection-fusion` v0.1. Registre : `CAT-E7…E9, CAT-C5, CAT-G1/G2, CAT-H1, CAT-I1` — précédemment : 5 juin 2026 — chantier **Importações/Exportações** charpenté : `spec-importacoes-exportacoes` v0.1 créée (squelette, **§9 wizard cadré**) ; registre **§17 `IMP-1..8`** ; maquettes de référence (tableau de bord v7 + wizard v1) — précédemment : 4 juin 2026 (nuit) — carte-lecteur **phase γ complète** (UI staff `ResolveCardBox` livrée, **gatée `libraries.reader_cards_enabled`** : invisible là où la carte n'est pas activée — hotfix Woodpecker vert) ; **`CADRAGE_importacoes_module_2026-06-04` ouvert** (chantier-cadre Importações ; registre §`IMP` ; **défère** `ACQ-Q4` frontière Catalogação + `FED-5` rôle coordenador) ; `DOC-I18N-1` réaligné **9 locales** (`nl`) — précédemment : 4 juin 2026 (soir) — **`spec-outils-federalistes` v0.1 créée** (face fédération + primitive cercle `círculo` ; cœur socle + cercles) ; **arbitrages FED-O4/O5/O6 tranchés** au registre §`FED` (terme `círculo` ; adhésion opt-out + anti-blackball B ; mutualisation = axe distinct, opt-in biblio multi-cercles) — précédemment : 4 juin 2026 (**section `FED`** au registre : modèle d'accès concentrique + face fédération « Ferramentas federalistas », `círculos` relocalisé hors `rede` ; cadrage `CADRAGE_modele_acces_concentrique_2026-06-04.md`) — précédemment : 3 juin 2026 (soir) — **dette ponctuelle soldée** (verrou `get_accessible_digital_asset` selon DOC-OBJ-2 ; **USER-EMAIL-1** : `profiles.email` rendu miroir synchronisé de `auth.users.email`, registre §0) + **carte-lecteur v0.2** (résolution staff `api.resolve_reader_card` livrée backend, contrat des 3 RPC, section `CARD` au registre §23) — précédemment : 3 juin 2026 (`#MODEL-item-grain` **constaté livré en prod** via audit du dump schéma 03/06 → `spec-granularite-item` passe en 🔵 référence historique [cœur + suite `#ILL-availability`] ; ouverture Phase 1 exemplares, cf. `docs/journal/`) — précédemment : 2 juin 2026 (trilogie doctrinale : `spec-multi-appartenance-lecteur` v0.3 + `spec-partenariat-biblios` v0.3 figées, `spec-flux-partage-numerique` v0.2 charpentée ; registre enrichi MULTI/PARTNER/ILL/VALID-β1-γ1) — précédemment : 1er juin 2026 (réinjection du chantier catalogue : **6 specs** — 4 catalogage + 2 découverte lecteur — + ordre de mise en œuvre) — précédemment : statut #CL.8 actualisé ; 31 mai 2026 (audit du corpus, groupe A, refonte INDEX/INVENTAIRE)
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
- **Nombre de locales** : voir `DOC-I18N-1` au registre (foyer unique — **ne pas recopier le compte ici**). *Tout nombre lu dans une spec ou une trace (« 6 », « 8 », « 9 »…) est périmé par rapport au registre, pas une consigne.*
- **Déploiement** = `git push` → Woodpecker (`DOC-DEPLOY-1/2/3`).
- **RPC v3** (`DOC-RPC-3`), **compteurs « page = périmètre »** (`DOC-PERIM-1`), création d'objets backend v2 (`DOC-OBJ-2`).

> État des drifts connus et corrections en une touche : [`AUDIT_coherence_corpus_2026-06-02.md`](../journal/audits/AUDIT_coherence_corpus_2026-06-02.md).

---

## 🔍 Navigation par domaine

### 🏛️ Gouvernance et structure

| Domaine | Spec de référence | Version | Statut |
|---|---|---|---|
| Administration réseau | [`spec-administrateur-reseau-v0.4.md`](./spec-administrateur-reseau-v0.4.md) | v0.4 (20/05/2026) | 🟢 Référence — v0.3.1 en prod, enrichissements v0.4 à implémenter |
| Gouvernance locale (rôles, status, transitions) | [`spec-gouvernance-roles.md`](./spec-gouvernance-roles.md) | v1.3 (24/05/2026) | 🟢 Référence — partiellement en prod |
| Profils d'adoption (4 axes orthogonaux) | [`spec-profils-bibliotheque-v0_7.md`](./spec-profils-bibliotheque-v0_7.md) | v0.7 (19/05/2026) | 🟢 Référence post-clôture chantier #98 — entièrement en prod |
| Écran de gestion « Biblioteca » (`/biblioteca`, 12 onglets) | [`spec-ecran-biblioteca.md`](./spec-ecran-biblioteca.md) | v1.0 (18/06/2026) | ✅ En prod (chantier-cadre clos) — **carte d'orientation** vers les specs par domaine |

### 🚪 Onboarding et compte lecteur

| Domaine | Spec de référence | Version | Statut |
|---|---|---|---|
| Onboarding d'une bibliothèque | [`spec-onboarding-biblioteca-v2.0.md`](./spec-onboarding-biblioteca-v2.0.md) | v2.0 (20/05/2026) | 🟠 Wizard de constitution (volets 0-9) **en prod** ; volet 10 en finition ; TODO §10 réconciliés `ONBO-Q5..Q12` — **🔴 #111 (éval admin) + TODO 3 + volet 10 = à résoudre au plus vite** |
| Onboarding `/criar-conta` | [`spec-onboarding-criar-conta.md`](./spec-onboarding-criar-conta.md) | v0.3 (21/05/2026) | 🟡 Brouillon de cadrage, cœur (paquets 1, 2, 4, 6, 7, 8) prêt à exécuter |
| Validation physique du compte lecteur·rice | [`spec-validation-physique.md`](./archive/spec-validation-physique.md) | v1.1 (30/05/2026) | ✅ Implémenté en prod (VALID C1-C4, §9) — archivé 2026-06-10 |

### 📖 Flux opérationnels (circulation)

| Domaine | Spec de référence | Version | Statut |
|---|---|---|---|
| Consultations sur place | [`spec-flux-consultations-v2.2.md`](./spec-flux-consultations-v2.2.md) | v2.2 (20/05/2026) | 🟢 Référence — entièrement en prod, doctrines R1-R11 internalisées |
| Emprunts | [`spec-flux-emprunts.md`](./spec-flux-emprunts.md) | v1.1 (31/05/2026) | 🟢 Référence — partiellement en prod, doctrines R7-R11 propagées |
| Workflow de réservation | [`spec-workflow-reservation.md`](./spec-workflow-reservation.md) | v3 sémantique (08/05/2026) | 🟢 Référence — en prod depuis paquet 5b |
| Renouvellement granulaire par item | [`spec-renouvellement-granulaire.md`](./spec-renouvellement-granulaire.md) | v1.0 (18/06/2026) | ✅ Implémentée en prod (phases 1-5) — référence consolidée a posteriori |
| Cycle de vie du PEB | [`spec-cycle-vie-peb.md`](./spec-cycle-vie-peb.md) | v1 (23/05/2026) | 🟡 Spec autonome, chantier #ILL-lifecycle à venir |
| Cotisation (contribution d'adhésion) | [`spec-cotisation.md`](./spec-cotisation.md) | v1.0 (18/06/2026) | ✅ Implémentée en prod — doctrine consolidée a posteriori (consolide NOTIF-PA, MULTI-F.1, §6.1, cron #25, tests #33) |

### 👤 Compte lecteur — méga-item #CL *(nouveau famille)*

| Domaine | Spec de référence | Version | Statut |
|---|---|---|---|
| Notifications lecteur·rice (canal in-app) | [`spec-notifications-lecteur.md`](./spec-notifications-lecteur.md) | v1.0 (31/05/2026) | 🟢 Référence — lien #CL.6 et #CL.7 livrés |
| Maîtrise lectrice de la rétention de l'historique | [`spec-historico-retencao-lectrice.md`](./spec-historico-retencao-lectrice.md) | v1.0 (31/05/2026) | 🟠 En cours — #CL.8 : backend + C.3/C.4 en prod, C.5/C.6 en attente de déploiement |
| Notification de prorrogação granulaire | [`spec-notify-prorrogacao-granulaire.md`](./spec-notify-prorrogacao-granulaire.md) | v0.1 (29/05/2026) | 🟡 Cadrage, lié `#NOTIFY-Painel-acts` |
| Multi-appartenance lectrice (plusieurs biblios) | [`spec-multi-appartenance-lecteur.md`](./archive/spec-multi-appartenance-lecteur.md) | v0.3 (02/06/2026) | ✅ Implémenté en prod (P1-P5) — archivé 2026-06-10. Absorbe `spec-migration-compte` |
| Identité lecteur·rice locale (n° / nom par biblio) | [`spec-identite-lecteur-locale.md`](./spec-identite-lecteur-locale.md) | v1.0 (18/06/2026) | ✅ Implémentée en prod (CARD-LOCAL §27, Lots 0/2) — doctrine consolidée a posteriori |
| Ma bibliothèque (vitrine + messagerie lecteur·rice ↔ biblio) | [`spec-ma-bibliotheque-lecteur.md`](./spec-ma-bibliotheque-lecteur.md) | v1.0 (18/06/2026) | ✅ Implémentée en prod (MYLIB §25) — doctrine consolidée a posteriori |

### 📱 Mode terrain / mobile *(nouveau famille)*

| Domaine | Spec de référence | Version | Statut |
|---|---|---|---|
| Carte-lecteur AnarBib | [`spec-carte-lecteur-v0_2.md`](./archive/spec-carte-lecteur-v0_2.md) | v0.2 (03/06/2026) | ✅ Implémenté en prod (phases β + γ) — archivé 2026-06-10 ; **résolution staff `api.resolve_reader_card` livrée backend (03/06) + UI staff `ResolveCardBox` (04/06, gatée `reader_cards_enabled`)** — **phase γ complète** ; arbitrages A.1-A.4 actés (A.1 séquençage 🟡 ouvert). Supersède v0.1 (.docx, 28/05 → archive) |

### 📐 Modélisation structurelle *(nouveau famille)*

| Domaine | Spec de référence | Version | Statut |
|---|---|---|---|
| Granularité du modèle sur l'exemplaire | [`spec-granularite-item.md`](./spec-granularite-item.md) | v1 (23/05/2026) | 🔵 Référence historique — chantier `#MODEL-item-grain` **livré en prod** (cœur + suite `#ILL-availability`, constaté 03/06) |

### 🗂️ Catalogação *(nouvelle famille — chantier Catalogação, 01/06)*

| Domaine | Spec de référence | Version | Statut |
|---|---|---|---|
| Fiche, registre & paliers | [`spec-catalogacao-fiche-et-paliers.md`](./archive/spec-catalogacao-fiche-et-paliers.md) | v0.4 (01/06/2026) | ✅ **Track A complet** (Lots 1→6 + 3b, 05/06) |
| Exemplaires : circulation & doublons | [`spec-exemplaires-circulation.md`](./archive/spec-exemplaires-circulation.md) | v0.2 (01/06/2026) | ✅ **Livré en prod** (constaté 05/06, CAT-E9) |
| Module capas | [`spec-module-capas.md`](./archive/spec-module-capas.md) | v0.2 (01/06/2026) | ✅ **P1/P2/P3 livré** (P3 page-1-PDF côté client, CAT-C5) |
| Sources externes & autorités | [`spec-sources-externes-autorites.md`](./spec-sources-externes-autorites.md) | v0.2 (01/06/2026) | 🟠 Socle autorité avancé (liaison + dédup livrées) ; reste VIAF/ISNI/Wikidata + `authority_lookup` |
| Notes bio multilingues (Ateliers, socle) | [`spec-autorites-notes-bio-multilingues.md`](./spec-autorites-notes-bio-multilingues.md) | v0.2 (05/06/2026) | ✅ Socle livré (CAT-I1) ; sélecteur de langue UI = reste |
| Liaison autorités ↔ œuvres | [`spec-liaison-autorites-oeuvres.md`](./archive/spec-liaison-autorites-oeuvres.md) | v0.2 (05/06/2026) | ✅ Rétroactif livré (CAT-G1) ; volet préventif = backlog |
| Détection & fusion de doublons | [`spec-doublons-detection-fusion.md`](./archive/spec-doublons-detection-fusion.md) | v0.1 (05/06/2026) | ✅ Autorités + documents livrés (CAT-H1) |

> Chantier coordonné avec `spec-granularite-item` (`#MODEL-item-grain`, couche *trace* — **livrée en prod**) et `spec-acquisition-provenance` (couche *provenance* — migration `exemplares` **mutualisée**). Ordre de mise en œuvre et garde-fous : voir `INVENTAIRE.md` § « Ordre de mise en œuvre — chantier Catalogação ».

### 🔎 Catalogue & découverte (lecteur) *(nouvelle famille — atelier RebAL, #OPAC / #CATALOG-EXT)*

| Domaine | Spec de référence | Version | Statut |
|---|---|---|---|
| Page catalogue — couche découverte (facettes, sujets, favoris, parcours) | [`spec-catalogue-decouverte.md`](./spec-catalogue-decouverte.md) | v1.0 (18/06/2026) | ✅ Implémentée en prod (OPAC7-10) — référence consolidée a posteriori ; OPAC11 RSS 🟡 différé |
| Notice & autorités enrichies (BookPage / AuthorPage) | [`spec-notice-autorite-enrichie.md`](./spec-notice-autorite-enrichie.md) | v1.0 (18/06/2026) | ✅ Implémentée en prod (#OPAC1-6 / #AUT1-4) — référence consolidée a posteriori |
| Thésaurus matière (vocabulaire contrôlé, SKOS) | [`spec-thesaurus-matiere.md`](./spec-thesaurus-matiere.md) | v1.0 (18/06/2026) | ✅ Implémentée en prod (v1→v3, THES §30) — référence consolidée a posteriori ; export SKOS public |
| Annuaire & fiches publiques des bibliothèques | [`spec-fiche-publique-bibliotheque.md`](./spec-fiche-publique-bibliotheque.md) | v1.0 (18/06/2026) | ✅ Implémentée en prod (PUBLIB §31) — doctrine consolidée a posteriori |

> Couche **lecteur** (affichage / découverte), **en aval** du chantier Catalogação : consomme le filtre `visibility` (exemplaires #2), les capas (module capas #3) et la couche autorité (sources & autorités #4). Lignes rouges : anti-tracking (aucun appel tiers révélant une consultation) + autonomie (cloisonnement des compteurs). Annonce une spec dédiée `spec-atelier-autorites`.

### 📧 Infrastructure transverse

| Domaine | Spec de référence | Version | Statut |
|---|---|---|---|
| Migration mail Brevo → Resend | [`spec-migration-mail-resend.md`](./archive/spec-migration-mail-resend.md) | v0.4 (01/06/2026) | ✅ #110 clos — Brevo entièrement retiré (R.6+R.7) — archivé 2026-06-10 |
| Cartographie du réseau AnarBib | [`spec-cartographie-reseau.md`](./spec-cartographie-reseau.md) | v1.0 (18/06/2026) | 🟢 Arbitrages `MAP-A..MAP-L` tranchés (REGISTRE §34) — **reste à implémenter** (post-Bologna) ; aligné PUBLIB (confidentialité) |

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
5. **[`spec-validation-physique.md`](./archive/spec-validation-physique.md)** *(amendement 30/05)* — bascule structurelle vers la validation par-appartenance (et non plus par-compte).

---

## 🆕 Specs annoncées (cadrées, pas encore remplies)

- **`spec-partenariat-biblios`** — **charpente figée v0.3 le 02/06** (`PARTNER-D1..D9` au registre ; cadrage `CADRAGE_partenariat_stabilise_2026-06-02.md`). Prolongement du chantier `#PARTNERS` livré le 24/05. Remplissage à venir, après `spec-multi-appartenance-lecteur`.
- **`spec-flux-partage-numerique`** (#ILL-digital) — circuit d'envoi de documents numériques entre biblios partenaires (`CADRAGE_ILL-digital_2026-05-25`). **Charpente figée v0.2 le 02/06** (`ILL-1..ILL-9` au registre, mandat BLMF) ; remplissage à venir.
- **`spec-atelier-autorites`** — annonce d'intention (vitrine `anarbib.org`) : face *contribution* de la couche d'autorités (file de propositions, gouvernance par consentement sans vote, autorités collectivité/matière). Préparée frontend par `spec-notice-autorite-enrichie` §5 ; à rédiger après stabilisation du catalogage. Préalable structurant : tables autorités *collectivité* et *matière*.
- **`spec-outils-federalistes`** (face fédération) — **v0.2 🟡 cadrée** (`docs/specs/` ; v0.1 04/06 → **v0.2 12/06** : fraîcheur i18n/déploiement + ouverture FED-O7) : bloc « Ferramentas federalistas » de la nav (entre `biblioteca` et `rede`), cœur rempli = socle + **primitive cercle** (`círculo`) — annuaire des cercles ouverts, adhésion opt-out + anti-blackball, cycle de vie (vue 1ʳᵉ personne : lecture membres / action coordenador). Foyer : **registre §`FED`** (FED-1..7 + FED-O4/O5/O6 tranchés ; **FED-O7 ouvert** = gouvernance des autorités partagées au niveau fédéral, articulation *split* avec `spec-atelier-autorites`, signal amont = rapports `rede` R3b/R4 du paquet RAPPORTS-REDE) + cadrage `CADRAGE_modele_acces_concentrique_2026-06-04.md`. Autres onglets charpentés/renvoyés ; remplissage code à venir.

- **Importações/Exportações** (module bidirectionnel : ingestion technique ⇄ export) — **`spec-importacoes-exportacoes` v0.1 créée 🟡 squelette** (`docs/specs/`). Plomberie de provenance déjà posée (`catalog_ref_*`, cible `book_drafts`, journal `book_draft_import_events`, staging BLMF + Zotero) ; couche format = **adaptateurs** (structure × vocabulaire × modèle). Doctrine au **registre §17 `IMP-1..8`** (`IMP-1..7` actés ; `IMP-8` wizard §9 **cadré**). Frontière `ACQ-Q4` (ingestion → `book_drafts`) ; export référence `ILL-1..9` (`spec-flux-partage-numerique`). Réf. visuelles : `maquette_importacoes_v7.html` (tableau de bord) + `maquette_wizard_import_v1.html` (assistant). Reste : DDL « run d'import » + ratification rôles (`spec-gouvernance-roles`) + remplissage (§12). Le **cadrage 04/06** (`CADRAGE_importacoes_module`, trace) est **supersédé** : son schéma `IMP-A1..A5` est remplacé par `IMP-1..8` (REGISTRE §17) + points ouverts §12 (préséance registre > trace).

> `spec-multi-appartenance-lecteur` : **implémentée en prod (P1-P5) et archivée le 2026-06-10** (`archive/`). Cf. [`AUDIT backlog v29 vs prod`](../journal/audits/AUDIT_backlog-v29-vs-prod_2026-06-10.md).

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
