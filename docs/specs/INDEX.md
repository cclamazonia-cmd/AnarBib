# 📚 INDEX du corpus de specs — AnarBib

**Dernière mise à jour** : 20 mai 2026 (post-réécriture v2.0/v0.4/v2.2)
**Maintenu par** : Xavier (lead dev) + Claude (assistant·e)

Ce document est la **porte d'entrée** du corpus de specs. Pour la description détaillée de chaque spec (statut d'implémentation, dépendances, dates, chantiers liés), voir [`INVENTAIRE.md`](./INVENTAIRE.md).

---

## 🔍 Navigation par domaine

### 🏛️ Gouvernance et structure

| Domaine | Spec de référence | Version | Statut |
|---|---|---|---|
| Administration réseau | [`spec-administrateur-reseau-v0.4.md`](./spec-administrateur-reseau-v0.4.md) | v0.4 (20/05/2026) | 🟢 Référence — implémentation v0.3.1 en prod, enrichissements v0.4 à implémenter |
| Gouvernance locale (rôles, status, transitions) | [`spec-gouvernance-roles.md`](./spec-gouvernance-roles.md) | v1.1 (15/05/2026) | 🟢 Référence — partiellement en prod |
| Profils d'adoption (4 axes orthogonaux) | [`spec-profils-bibliotheque-v0_7.md`](./spec-profils-bibliotheque-v0_7.md) | v0.7 (19/05/2026) | 🟢 Référence post-clôture chantier #98 — entièrement en prod |

### 🚪 Onboarding et migration de comptes

| Domaine | Spec de référence | Version | Statut |
|---|---|---|---|
| Onboarding d'une bibliothèque | [`spec-onboarding-biblioteca-v2.0.md`](./spec-onboarding-biblioteca-v2.0.md) | v2.0 (20/05/2026) | 🟢 Référence — volet 0 livré (paquet F.3), volets 1-10 à implémenter (chantier #111 Q3 2026) |
| Migration de compte entre biblios | [`spec-migration-compte.md`](./spec-migration-compte.md) | v1 (04/05/2026) | 🟡 Spec cadrée, non implémentée |
| Validation physique du compte lecteur | [`spec-validation-physique.md`](./spec-validation-physique.md) | v1 (04/05/2026) | 🟡 Spec cadrée, non implémentée |

### 📖 Flux opérationnels (circulation)

| Domaine | Spec de référence | Version | Statut |
|---|---|---|---|
| Consultations sur place | [`spec-flux-consultations-v2.2.md`](./spec-flux-consultations-v2.2.md) | v2.2 (20/05/2026) | 🟢 Référence — entièrement en prod, doctrines #141/#142 internalisées |
| Emprunts | [`spec-flux-emprunts.md`](./spec-flux-emprunts.md) | v1 (10/05/2026) | 🟢 Référence — partiellement en prod (TODO : propagation doctrines R7-R11) |
| Workflow de réservation | [`spec-workflow-reservation.md`](./spec-workflow-reservation.md) | v3 sémantique (08/05/2026) | 🟢 Référence — en prod |

### 📧 Infrastructure transverse

| Domaine | Spec de référence | Version | Statut |
|---|---|---|---|
| Migration mail Brevo → Resend | [`spec-migration-mail-resend.md`](./spec-migration-mail-resend.md) | v1 (13/05/2026) | 🟠 En cours d'implémentation (item #110 du backlog v8) |

### 📐 Specs doctrinales de chantier ponctuel

Ces specs documentent des chantiers ponctuels clos et servent de **références historiques** pour reconstituer le raisonnement. Elles ne sont **pas** des specs vivantes — la doctrine qu'elles portent a été absorbée dans les specs de référence ci-dessus.

| Spec | Sujet | Chantier d'origine | Statut |
|---|---|---|---|
| [`spec-refactor-v3-semantique.md`](./spec-refactor-v3-semantique.md) | Refactor sémantique du workflow réservation | Paquet 5b (08/05/2026, clos) | 🔵 Référence historique |
| [`spec-workflow-reservation-v2-negotiation.md`](./spec-workflow-reservation-v2-negotiation.md) | Doctrine de négociation symétrique réservation | Pré-paquet 5b (08/05/2026, clos) | 🔵 Référence historique |
| [`spec-implementation-114a-network-cooptation.md`](./spec-implementation-114a-network-cooptation.md) | Doctrine d'implémentation de `notify-event` pour `network.cooptation_*` | Chantier #114.A (14/05/2026, clos) | 🔵 Référence historique |

---

## 🆕 Réécritures du 20 mai 2026

Trois specs ont été enrichies en marathon le 20/05/2026 pour intégrer la **doctrine anti-méga-machine** émergée pendant la session marathon du 19/05 et les **doctrines techniques #141/#142** internalisées les 16-17/05. Ces trois specs constituent la **lecture prioritaire** pour comprendre l'état doctrinal actuel du projet :

1. **[`spec-onboarding-biblioteca-v2.0.md`](./spec-onboarding-biblioteca-v2.0.md)** — la spec la plus impactée. §1.4 doctrine anti-méga-machine, §5.7 bouton « proposer un échange » côté admins, §6.5 encadré canal humain par volet, §6.6 PDF règlement = artefact de délibération, annexe Émile-Henry.
2. **[`spec-administrateur-reseau-v0.4.md`](./spec-administrateur-reseau-v0.4.md)** — préambule politique enrichi (admins = camarades pas hotline), §4.7 canal humain proactif vers biblios membres (symétrique de l'onboarding §5.7), §8.8 risque burnout admin réseau.
3. **[`spec-flux-consultations-v2.2.md`](./spec-flux-consultations-v2.2.md)** — purement doctrinal technique : doctrines R7 (ordre UPDATE), R8 (distinction notes), R9 (traçabilité coordination), R10 (cohérence handler/trigger), R11 (UTF-8 PowerShell).

---

## 📂 Conventions du corpus

### Versionnement des specs

- **vX.Y entière** : refonte structurelle de la spec (peu fréquent, exemple : onboarding v1.0 → v2.0).
- **vX.Y mineure** : enrichissement ciblé, ajout de sections sans casser la structure existante (exemple : admin réseau v0.3 → v0.4).
- **Suffixe `-vX.Y.md`** : utilisé pour distinguer la nouvelle version de la version actuelle pendant la transition. Quand la nouvelle version est validée comme référence, l'ancienne va dans `archive/` avec un suffixe `-archive-vX.Y.md` et la nouvelle peut soit garder son suffixe, soit reprendre le nom canonique (sans suffixe).

### Dossier `archive/`

Contient les **anciennes versions** des specs qui ont été remplacées par une version plus récente. À conserver pour la traçabilité historique (relire le raisonnement passé, comprendre les évolutions doctrinales). Ne **jamais supprimer** une spec archivée — elle peut être utile dans 6 mois.

### Statuts visuels utilisés dans ce corpus

- 🟢 **Référence** : spec à jour, à utiliser comme source de vérité
- 🟠 **En cours** : spec d'un chantier en cours d'implémentation
- 🟡 **Cadrée non implémentée** : spec écrite mais pas encore exécutée
- 🔵 **Référence historique** : spec d'un chantier ponctuel clos, à conserver mais pas à modifier
- 🔴 **Obsolète** : spec à archiver/supprimer (n'apparaît pas dans cet INDEX, voir `archive/`)

### Liens entre specs

Les specs se référencent mutuellement par chemin relatif (`./spec-X.md`). Les blocs d'en-tête de chaque spec listent ses **dépendances entrantes** (specs sur lesquelles elle s'appuie) et idéalement ses **dépendances sortantes** (specs qui s'appuient sur elle). Voir `INVENTAIRE.md` pour la carte complète des dépendances.

---

## 🧭 Comment utiliser cet INDEX

**Pour démarrer un nouveau chantier** : identifier la spec de référence du domaine concerné, lire son en-tête (statut, dépendances), puis consulter `INVENTAIRE.md` pour comprendre quels chantiers passés ou en cours touchent ce domaine.

**Pour comprendre un bug en prod** : si le bug touche un flux (consultas, emprunts, réservations, onboarding, gouvernance), consulter la spec de référence du domaine. Les sections « §11.2 raffinements doctrinaux » (pour consultas) ou équivalentes inscrivent les doctrines techniques internalisées au fil des chantiers.

**Pour vérifier l'articulation entre specs** : `INVENTAIRE.md` contient la **carte des dépendances mutuelles**. Quand on modifie une spec, vérifier qui dépend d'elle pour cascade éventuelle (exemple : modifier spec-administrateur-reseau touche directement spec-onboarding-biblioteca).

**Pour archiver une spec** : voir la section « Maintenance du corpus » de `INVENTAIRE.md`.

---

*Fin de l'INDEX. Pour la description détaillée de chaque spec, voir `INVENTAIRE.md`.*
