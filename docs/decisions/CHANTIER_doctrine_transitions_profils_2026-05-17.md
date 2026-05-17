# Doctrine des transitions de profils AnarBib

**Chantier** : #98-B Profils d'adoption / Paquet B Transitions
**Spec source** : `docs/specs/spec-profils-bibliotheque.md` v0.3 §9.1
**Date** : 17 mai 2026
**Statut** : actif

---

## Pourquoi ce document existe

AnarBib permet à chaque bibliothèque militante de se positionner sur **quatre axes politiques orthogonaux** (catalogue, circulation, réseau, gouvernance). Une biblio peut décider à tout moment de **changer son profil** sur un de ces axes — par exemple cesser de publier son catalogue au réseau, ou bien renforcer son système de gouvernance.

Ces changements ne sont pas anodins. Selon ce qui change, **la nature politique du processus n'est pas la même**. Certains changements sont des élargissements simples (la biblio s'ouvre, rien ne se perd), d'autres sont des rétractations qui font perdre des droits acquis aux usager·es, d'autres encore impliquent l'archivage de données politiquement sensibles (prêts en cours, votes passés, audits de gouvernance).

Ce document fixe **la matrice politique** qui distingue ces situations et y attache des **niveaux de gouvernance** différents. Plus le changement est lourd, plus le processus de décision est exigeant.

---

## Les quatre types de transition

| Type | Nom politique | Caractéristique | Gouvernance |
|------|---------------|-----------------|-------------|
| **1** | Élargissement immédiat | La biblio s'ouvre, aucun risque, aucun droit perdu | `direct` (1 admin staff suffit) |
| **2** | Rétractation douce | Recul doctrinal sans perte structurelle | `majority` (vote staff majoritaire) |
| **3** | Rétractation politique | Sortie ou cessation, sans archivage critique | `unanimous` (unanime + carence 7j) |
| **4** | Transition critique avec archivage | Données politiquement sensibles à archiver | `unanimous_extended` (unanime + carence 14j + archivage paquet D) |

---

## Type 1 — Élargissement immédiat

**Doctrine** : *« Une biblio peut toujours s'ouvrir plus. C'est un mouvement politique conforme à l'esprit du commun, et il ne crée aucune perte rétroactive. »*

Une transition de type 1 augmente la portée, la visibilité, l'inclusivité ou la structuration de la biblio. Elle ne supprime rien. Elle ne fait perdre aucun droit acquis à personne.

Exemples :
- Publier le catalogue au réseau (`local_only → network_published`)
- Activer la circulation informelle (`off → informal`)
- Rejoindre la fédération (`isolated → federated`)
- Adopter un système de votes (`informal → full_governance`)

**Gouvernance `direct`** : un·e admin staff (`librarian` ou `coordenador`) peut déclencher le changement directement, sans vote. La rapidité d'exécution est valorisée parce qu'aucun risque n'est encouru.

---

## Type 2 — Rétractation douce

**Doctrine** : *« Une biblio peut reculer sur la structuration sans avoir à mobiliser l'unanimité, tant que le recul ne fait pas disparaître de système de mémoire collective. »*

Une transition de type 2 est un recul **partiel** : la biblio renonce à une partie de sa structuration sans pour autant détruire les audits, votes ou processus délibératifs déjà constitués. Les droits acquis sont diminués mais pas annulés.

Exemples :
- Passer de `full_governance` à `staff_roles` : on garde la distinction staff/usager·es mais on cesse les votes formels. Les votes passés restent consultables, l'historique de gouvernance n'est pas effacé.

**Gouvernance `majority`** : un vote staff à majorité simple suffit. Pas de carence, parce que la décision ne ferme aucune porte qu'on ne pourrait rouvrir par un autre type 1.

---

## Type 3 — Rétractation politique

**Doctrine** : *« Une rétractation qui sort la biblio d'un mode collectif (réseau, circulation formelle, publication de catalogue) doit faire l'objet d'une unanimité du staff, et observer une carence pour permettre la consultation des usager·es directement concerné·es. »*

Une transition de type 3 fait sortir la biblio d'un mode collectif sans pour autant détruire de données structurées (parce qu'il n'y en a pas, ou parce qu'elles sont déjà locales). Elle change la posture politique de la biblio vis-à-vis du réseau ou des usager·es.

Exemples :
- Sortir le catalogue du réseau (`network_published → local_only`) : les liens fédérés disparaissent mais le catalogue local reste intact.
- Cesser la circulation informelle (`informal → off`) : il n'y a pas de prêts formels à archiver puisque le mode informel ne les inscrit pas.
- Sortir de la fédération (`federated → isolated` ou via `observer`) : la biblio se rend invisible au réseau sans pour autant perdre ses propres données.

**Gouvernance `unanimous`** : vote staff unanime + **carence 7 jours** avant exécution. La carence permet :
- À chaque membre du staff de revenir sur son vote
- Aux usager·es informé·es de la décision de réagir politiquement (assemblée, débat, contre-proposition)
- À la biblio elle-même de se rétracter sans cérémonie supplémentaire

---

## Type 4 — Transition critique avec archivage

**Doctrine** : *« Aucun système de mémoire collective ne doit disparaître sans avoir été archivé. La mémoire des prêts, des votes, des audits, appartient aux personnes qui les ont posés. Avant qu'AnarBib n'oublie, elle doit transmettre. »*

Une transition de type 4 fait disparaître un **système de mémoire structurée** : les prêts formels en cours, le système de votes, les audits de gouvernance. Politiquement, ces traces ne peuvent pas être effacées par décision majoritaire — elles doivent être **archivées** avant la bascule, conformément aux principes du paquet D.

Exemples :
- Cesser la circulation formelle (`full_sigb → informal` ou `full_sigb → off`) : les prêts en cours, les retours en attente, l'historique des emprunts doivent être archivés avant que le système ne cesse de les suivre.
- Abandonner le système de gouvernance (`staff_roles → informal` ou `full_governance → informal`) : les votes passés, les audits de cooptation, les délibérations doivent être archivés.

**Gouvernance `unanimous_extended`** : vote staff unanime + **carence 14 jours** + **archivage obligatoire** via le paquet D.

Pendant la carence de 14 jours :
- Le paquet D produit les archives (export JSON/CSV, accessible aux personnes concernées)
- Les usager·es directement impacté·es sont notifié·es (ex. emprunteur·euses actuel·les en cas de `full_sigb → off`)
- La biblio peut se rétracter sans cérémonie supplémentaire

**Prérequis technique** : le paquet D doit être livré pour qu'une transition de type 4 puisse s'exécuter. En son absence, `fn_propose_library_profile_change` refusera la proposition en amont (RAISE EXCEPTION `TRANSITION_TYPE_4_REQUIRES_PACKAGE_D`) pour ne pas mobiliser inutilement la délibération.

---

## Application aux quatre axes (matrice complète)

### `catalog_mode`

| Depuis | Vers | Type | Gouvernance |
|--------|------|------|-------------|
| `local_only` | `network_published` | 1 | direct |
| `network_published` | `local_only` | 3 | unanimous |

### `circulation_mode`

| Depuis | Vers | Type | Gouvernance |
|--------|------|------|-------------|
| `off` | `informal` | 1 | direct |
| `off` | `full_sigb` | 1 | direct |
| `informal` | `full_sigb` | 1 | direct |
| `full_sigb` | `informal` | 4 | unanimous_extended (archivage) |
| `informal` | `off` | 3 | unanimous (rien à archiver) |
| `full_sigb` | `off` | 4 | unanimous_extended (archivage) |

### `network_mode`

| Depuis | Vers | Type | Gouvernance |
|--------|------|------|-------------|
| `isolated` | `observer` | 1 | direct |
| `isolated` | `federated` | 1 | direct |
| `observer` | `federated` | 1 | direct |
| `federated` | `observer` | 3 | unanimous |
| `observer` | `isolated` | 3 | unanimous |
| `federated` | `isolated` | 3 | unanimous |

### `governance_mode`

| Depuis | Vers | Type | Gouvernance |
|--------|------|------|-------------|
| `informal` | `staff_roles` | 1 | direct |
| `informal` | `full_governance` | 1 | direct |
| `staff_roles` | `full_governance` | 1 | direct |
| `full_governance` | `staff_roles` | 2 | majority |
| `staff_roles` | `informal` | 4 | unanimous_extended (perte audits) |
| `full_governance` | `informal` | 4 | unanimous_extended (perte votes+audits) |

---

## Cas particuliers et leurs justifications

### Pourquoi `informal → off` est type 3 et pas type 4

Le mode `informal` signifie explicitement qu'aucun prêt formel n'est inscrit dans la base. Il n'y a donc **rien à archiver** quand on bascule vers `off`. Forcer un type 4 obligerait la biblio à attendre le paquet D pour rien — c'est absurde sur le plan technique et contre-productif politiquement.

**Conséquence** : une biblio en mode `informal` peut cesser sa circulation par vote unanime + 7 jours de carence, sans dépendance technique. C'est le bon niveau de prudence pour une décision politique sans enjeu de mémoire.

### Pourquoi `full_governance → staff_roles` est type 2 et pas type 3

Passer de `full_governance` à `staff_roles` ne fait **pas disparaître** les votes ou audits passés — ils restent consultables. On cesse simplement d'en produire de nouveaux. Politiquement, c'est un recul partiel mais réversible (un type 1 permet de remonter à `full_governance`), et les usager·es ne perdent pas l'accès à leur historique délibératif.

Le niveau `majority` est donc justifié : la décision est lourde mais pas catastrophique, et l'unanimité serait disproportionnée.

### Pourquoi pas de `unanimous` avec carence longue pour le type 2

Le type 2 est suffisamment léger pour qu'une majorité simple sans carence soit acceptable. Ajouter une carence créerait une confusion avec le type 3 (« quelle est la différence ? »). Le découpage clair entre les 4 types facilite l'apprentissage politique du système.

---

## Limites doctrinales et évolutions possibles

Cette matrice est **doctrinale**, pas opérationnelle. Elle peut être modifiée, mais une modification nécessite :

1. Une délibération politique (équivalent d'un type 3 sur la matrice elle-même)
2. La mise à jour conjointe de :
   - `fn_classify_transition` (cette fonction SQL)
   - Le présent document
   - Les RPC du paquet B.3 si la sémantique change
   - Les chaînes i18n du paquet B.6 si de nouvelles catégories apparaissent

**Évolutions identifiées comme possibles** :

- Réexaminer `informal → off` si on découvre que des données (consultas, réservations) y sont en fait suivies : passage au type 4.
- Ajouter une distinction entre `isolated` et `isolated_strict` (visibilité partielle vs totale) : nouvelles cases dans la matrice.
- Introduire un type 5 (transition impossible / bloquée par doctrine) pour les changements politiquement refusés à l'avance — par exemple si la biblio s'engage par charte à rester fédérée.

Ces évolutions sont **conscientes** : elles ne doivent pas arriver par dérive incrémentale mais par délibération explicite.

---

## Référence technique

- Encodé dans : `supabase/migrations/20260517190000_paquet_B2_helpers_classification.sql`
- Fonction : `public.fn_classify_transition(text, text, text) RETURNS jsonb`
- Wrapper : `public.fn_required_governance_for_transition(uuid, text, text) RETURNS text`
- Tables d'audit : `library_profile_proposals`, `library_profile_votes`, `library_profile_grace_locks` (paquet B.1)

---

*Document de doctrine pour AnarBib — Bibliothèque libertaire militante fédérée*
