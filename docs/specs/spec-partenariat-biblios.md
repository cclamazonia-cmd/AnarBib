---
Genre : référence
Statut : 🟢 implémentée en prod (front+back) — MAJ 16/06/2026, vérifié — fn_partnership_* complet, tables library_partnerships/partnership_rights/reader_partnership_consent/partnership_break_log, vue library_partnerships_ui, console coordenador + encart consentement /conta. Cf. INVENTAIRE Resync 16/06. (Ancien : « cadrée ».)
Décisions : incarne PARTNER-D1..D9 (REGISTRE §21) ; cite MULTI-MODEL (transparence E.3), VALID-γ1 (non-cascade), ILL-8 (partage numérique = droit)
Supersédé par : —
---

# spec-partenariat-biblios

| | |
|---|---|
| **Version** | v0.3 — charpente **figée** (les 3 points doctrinaux tranchés ; aucun point ouvert) |
| **Date** | 2 juin 2026 |
| **Emplacement cible** | `docs/specs/` |
| **Statut** | Charpente **figée** : cadrage `PARTNER-D1..D9` intégralement incarné ; modèle de données (`library_partnerships` + `partnership_rights`) et partage numérique (`ILL-*`) résolus. Remplissage en session dédiée. |
| **Réfère à** | `#PARTNERS` (infra déclarative livrée 24/05) ; contexte : `CADRAGE_partenariat_stabilise_2026-06-02.md` (🔵 trace). |
| **Dépendances** | `spec-multi-appartenance-lecteur` (transparence E.3/E.2.5 — parallèle), `#ILL-digital`/`spec-flux-partage-numerique` (partage numérique), `spec-acquisition-provenance` (mutualisation), réseau fédératif/cercle (orthogonalité), `spec-gouvernance-roles` (qui propose/accepte). |

> **Convention.** **[A]** = acté (arbitrages 02/06, `PARTNER-D*`). Charpente figée : plus aucun point `[T]` ouvert (cf. §13).

---

## 1. Préambule & objet
- Le **partenariat stabilisé** est la **couche sémantique** des relations inter-biblios : ce qu'une relation déclarée *ouvre comme droits* entre deux biblios AnarBib.
- Il se pose **au-dessus de `#PARTNERS`** (infra déclarative, « qui est partenaire de qui », livrée 24/05) sans la redire.
- **Principe directeur : contenant / contenu [A].** Le partenariat = *contenant* (la relation + le catalogue des droits qu'elle peut porter). Chaque droit a sa **mécanique propre dans sa spec de domaine**, qui référence le partenariat comme condition d'activation. Le partenariat n'absorbe pas ces mécaniques (anti-méga-machine).

## 2. Les deux couches à ne pas confondre
- **Infra `#PARTNERS`** : déclaration (section « Parcerias de correspondência » de la page biblio ; ajout biblio fédérée / collectif ; retrait ; articulation PEB).
- **Sémantique (cette spec)** : ce que la déclaration ouvre — gouvernance de la donnée inter-biblios.

## 3. Modèle du partenariat
- Un partenariat stabilisé = relation **bilatérale entre deux biblios AnarBib** **[A — PARTNER-D6]**. Les collectifs (`catalog_partners`) restent au niveau déclaratif `#PARTNERS`, sans droits sur données internes.
- **Symétrie stricte [A — PARTNER-D4]** : un seul jeu de droits actifs, même périmètre dans les deux sens. Pas d'asymétrie (anti-pouvoir, horizontalité).
- **Cycle de vie [A — PARTNER-D7]** : proposition et acceptation réservées au rôle **`coordenador`** (acte politique d'engagement de la biblio) ; **activation bilatérale** — aucun droit ouvert tant que les deux coordinations n'ont pas accepté (`proposé → actif`, ou `refusé`) ; **rupture unilatérale**, fermant l'accès des deux côtés (`D5`) et tracée. *Deux pour s'unir, un seul pour partir.*

## 4. Le catalogue des droits *(le cœur contenant/contenu)*
Activation **droit par droit côté biblios** **[A — PARTNER-D2]** ; le partenariat déclare un ensemble de droits actifs, réciproques.

| Droit ouvert | Mécanique (foyer de domaine) |
|---|---|
| Transparence sur les lectrices communes (E.2.5 / E.3) | `spec-multi-appartenance-lecteur` (MULTI) + painel (Zone 21) |
| Partage numérique de documents | `#ILL-digital` (cadré : `ILL-1..ILL-8`) → `spec-flux-partage-numerique` |
| Mutualisation de catalogue | catalogage / `spec-acquisition-provenance` |
| Éligibilité au PEB | déjà articulée via `#PARTNERS` |

Chaque droit **référence** le partenariat comme condition d'activation ; la spec de domaine porte le « comment ».

## 5. Granularité & activation (PARTNER-D2)
- Côté biblios : activation **droit par droit** (cases réciproques). Pas de « tout ou rien » (respecte la minimisation).
- Côté lectrice : consentement **au niveau du partenariat**, pas case par case (ingérable). Si la config gagne un droit → re-consentement (§6).

## 6. Consentement de la lectrice (PARTNER-D1)
- **Opt-in explicite par partenariat [A]** ; défaut = **transparence minimale** (existence des appartenances seule, cf. E.3).
- Notification (mail + in-app) quand un partenariat se forme concernant des biblios dont elle est membre.
- Encart `/conta` : liste des partenariats actifs qui la concernent + catégories partagées par chacun.
- **Consentement révocable [A — PARTNER-D8]** : retrait depuis l'encart `/conta` (un bouton par partenariat) → **effet immédiat via RLS**, retour à la transparence minimale, sans résidu (cf. §7).
- Le consentement porte sur une **version de la configuration** des droits. **Ajout** d'un droit (config qui s'élargit) → consentement invalidé, **re-sollicitation**, transparence minimale entre-temps ; **retrait** d'un droit (config qui se restreint) → consentement maintenu (a fortiori couvert). On ne resollicite que *vers le haut* — même logique que le plafond `ILL-3`.
- Re-sollicitation **ciblée** (lectrices concernées seulement), **groupée** (un changement de config = une sollicitation) et **douce** (notification à re-confirmer, pas blocage) — friction minimale.

## 7. Révocation & cycle de vie de la donnée (PARTNER-D5)
- Le partage est une **visibilité conditionnée** (RLS sur partenariat actif **+** droit activé **+** consentement lectrice), **pas une copie** — A ne détient jamais les données de B.
- **Rupture du partenariat** → l'accès se ferme, **sans résidu** à effacer.
- **Exception** : les artefacts effectivement *transmis* (docs numériques) suivent le cycle de vie de `#ILL-digital`, **hors** révocation du partenariat.
- **Trace d'audit** de la rupture (qui, quand) — immuabilité de l'audit.
- **Borne `VALID-γ1`** : la transparence enrichie *expose* une restriction posée chez B, elle n'*impose* aucune action à A — pas de cascade (« la confiance n'est pas transitive »).

## 8. Orthogonalité avec le cercle (PARTNER-D3)
- **Aucun partenariat ne se déduit d'un cercle commun** (préserve le garde-fou central du cercle : aucun droit ouvert par appartenance à un cercle).
- Un partenariat **peut exister sans cercle commun**.
- Le cercle **facilite socialement** la rencontre, ne **crée jamais** le droit.

## 9. Périmètre (PARTNER-D6)
- Droits réservés **biblio↔biblio AnarBib**. Collectifs `catalog_partners` = déclaratif `#PARTNERS`, sans droits sur données internes.
- L'envoi d'un doc numérique vers un collectif **sort du circuit AnarBib** → `#ILL-digital`.

## 10. Implications techniques
- **Modèle de données [A]** : enrichir la table **`library_partnerships`** existante (`#PARTNERS`, 24/05) d'un statut « stabilisé », des droits actifs et du consentement — pas de nouvelle table.
- **Granularité [A — PARTNER-D9]** : droits portés par une **table de jonction** `partnership_rights (partnership_id, right_key)`, `right_key` sous `CHECK`/enum (transparence, partage numérique, mutualisation, PEB). Ajouter un droit futur = une valeur, pas une migration de structure.
- **Symétrie [A — PARTNER-D4]** : le jeu de droits est attaché au **partenariat-paire `{A, B}`**, pas à un sens. Si `library_partnerships` s'avère directionnel au remplissage, un trigger garantit l'égalité des deux jeux.
- **Consentement** : table `reader_partnership_consent` `(user_id, partnership_id, config_version, consented_at, …)` — versionnée par configuration (cf. `PARTNER-D8`).
- **RLS** : visibilité des données de B par A = `partenariat actif (A,B)` ∧ `droit transparence activé` ∧ `consentement lectrice donné (config courante)`.
- **Audit** : journal de rupture (immuable).
- **Propagation** : les RPC painel de transparence lisent via ces conditions (cf. MULTI Zone 21).

## 11. Articulation avec le corpus
- `#PARTNERS` (infra) · `spec-multi-appartenance-lecteur` (MULTI — transparence E.3/E.2.5/Zone 21, parallèle non bloquante) · `#ILL-digital`/`spec-flux-partage-numerique` (partage numérique — droit déclaré ici, mécanique là-bas, **cadrée `ILL-1..ILL-8`**) · recursos digitais (export-vers-partenaire) · `spec-acquisition-provenance` (`partner_source`/`mutualization_status`) · réseau fédératif/cercle (orthogonalité D3) · `spec-gouvernance-roles` (`coordenador` propose/accepte).
- **Cohérence inter-pages** : si « Parcerias de correspondência » est renommé → MAJ du lien sortant de catalogação.

## 12. Annexe — table des décisions
*(à remplir : PARTNER-D1..D9 avec justification ; mention du mandat impératif du collectif pour D1, et du mandat BLMF pour D7..D9.)*

---

## 13. Points tranchés *(plus aucun point ouvert)*

Tous les arbitrages de la charpente sont rendus au registre `PARTNER-D1..D9` :
- **Modèle de données** → `library_partnerships` enrichie (pas de nouvelle table).
- **Partage numérique** → arbitré `ILL-1..ILL-8` (mandat BLMF, 02/06) ; mécanique = `spec-flux-partage-numerique`.
- **Cycle de vie** → `PARTNER-D7` (coordenador ; activation bilatérale ; rupture unilatérale).
- **Retrait du consentement** → `PARTNER-D8` (effet immédiat RLS ; re-sollicitation vers le haut, ciblée/groupée/douce).
- **Granularité des droits** → `PARTNER-D9` (`partnership_rights` ; symétrie au partenariat-paire).

Reste, hors charpente, au **remplissage** : SQL effectif (DDL `partnership_rights`, RLS, trigger de symétrie), maquettes des écrans `coordenador` (proposer/accepter/rompre) et de l'encart `/conta`, et les chaînes i18n (8 locales).

---

*Fin de la charpente — v0.3 **figée**. Le remplissage suit en session dédiée, selon le modèle de `CHARTE_corpus` (en-tête, foyer unique, citer plutôt que recopier). Les décisions font foi au registre `PARTNER-D1..D9`.*
