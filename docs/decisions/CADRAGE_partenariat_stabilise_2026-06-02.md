---
Genre : trace
Statut : 🔵 historique
Décisions : incarne PARTNER-D1..D6 (REGISTRE §21)
Supersédé par : REGISTRE_decisions §21 PARTNER (arbitrages) ; spec-partenariat-biblios (design, à écrire)
---

# CADRAGE — Partenariat stabilisé entre bibliothèques

> ⚠️ **Document de travail — historique (tamponné le 02/06/2026).** Les arbitrages D1–D6 ont gradué dans `REGISTRE_decisions.md` §21 `PARTNER`, qui fait désormais foi. Le design graduera dans `spec-partenariat-biblios` (à écrire). Ce cadrage reste lisible comme **contexte de rédaction** (raisonnement, catalogue des droits §4, intersections §6) mais n'est plus normatif : pour les décisions, citer les IDs `PARTNER-*`.

| | |
|---|---|
| **Référence** | CADRAGE_partenariat_stabilise_2026-06-02 |
| **Version** | v0.2 — arbitrages tranchés |
| **Date** | 2 juin 2026 |
| **Emplacement** | `docs/decisions/` |
| **Statut** | 🔵 historique (tamponné 02/06) — arbitrages gradués au registre §21 `PARTNER`. Reste contexte de rédaction pour `spec-partenariat-biblios`. |
| **Origine** | Émergence en séance le 31/05/2026 (cf. backlog v23 §A.1, ici relogé). Clarification du périmètre 01–02/06 ; arbitrages tranchés le 02/06. |
| **Articulation** | Socle doctrinal de la future `spec-partenariat-biblios`. Croisé avec `spec-multi-appartenance-lecteur`, `#ILL-digital`, recursos digitais (P2 #7), `spec-acquisition-provenance`, et le chantier réseau fédératif. |

---

## 1. Pourquoi ce document

Le **partenariat stabilisé entre bibliothèques** a émergé le 31/05 comme objet doctrinal de premier ordre : le mécanisme général qui régit la *sémantique* des relations inter-biblios, et règle par construction toute une famille de questions qu'on aurait sinon tranchées au cas par cas.

Ce document : (a) **reloge** le cadrage hors du backlog v23 §A.1 — section éphémère réécrite à chaque version — vers une source stable ; (b) consignait six questions à trancher, **désormais arbitrées le 02/06** (§5). Il ne contient pas de spécification technique : il fonde `spec-partenariat-biblios`.

## 2. L'objet : deux couches à ne pas confondre

- **Couche infrastructure — déjà livrée (#PARTNERS, 24/05).** La page biblio sait déjà *déclarer* un partenaire : section « Parcerias de correspondência », ajout d'une biblio fédérée ou d'un collectif, retrait, articulation PEB. C'est le « qui est partenaire de qui », déclaratif.
- **Couche sémantique — objet du présent cadrage.** Le partenariat stabilisé définit ce que cette déclaration *ouvre comme droits* entre les deux biblios. Gouvernance de la donnée inter-biblios, pas une redite de #PARTNERS.

**Principe directeur : contenant / contenu.** Le partenariat est un **contenant** — la relation, plus le *catalogue des droits qu'elle peut porter*. Chaque droit a sa **mécanique propre, spécifiée dans sa spec de domaine**, qui référence le partenariat comme condition d'activation. Le partenariat ne devient pas un méga-objet absorbant ces mécaniques (doctrine anti-méga-machine).

## 3. Ce qui est acté de la séance du 31/05

**Transparence inter-biblios graduée.**

- **Par défaut, sans partenariat — transparence minimale.** A sait qu'une lectrice est aussi membre d'autres biblios (*existence* des appartenances), sans aucun détail interne : ni numéro local de B, ni emprunts dans B, ni notes de B.
- **Après partenariat stabilisé déclaré entre A et B — transparence enrichie négociée.** Les deux biblios définissent ensemble (réciprocité obligatoire) le niveau d'information partagé sur leurs lectrices communes : possiblement numéros locaux, historique récent, cotisations, restrictions actives.

Aucune surveillance par défaut (autonomie préservée) ; collaboration possible en pleine transparence ; pas d'information cachée, pas d'arbitraire AnarBib. **Résout par construction** E.2.5 (visibilité numéro local côté painel) et E.3 (transparence inter-biblios) du cadrage multi-appartenance.

**Indépendance de rédaction.** Le partenariat est *hors périmètre* de `spec-multi-appartenance-lecteur`, mais celle-ci s'y articule explicitement. C'est un **enrichissement, pas une dépendance bloquante**.

## 4. Le catalogue des droits qu'un partenariat peut ouvrir

| Droit ouvert par le partenariat | Mécanique spécifiée dans |
|---|---|
| Transparence sur les lectrices communes (E.2.5 / E.3) | `spec-multi-appartenance-lecteur` + painel |
| Partage numérique de documents | `#ILL-digital` → future `spec-flux-partage-numerique` |
| Mutualisation de catalogue | catalogage / `spec-acquisition-provenance` (cf. réseau fédératif §6.1) |
| Éligibilité au PEB | déjà articulée via #PARTNERS |

## 5. Décisions actées — 02/06/2026

> Arbitrées par Xavier sous **mandat impératif du collectif**, dont le critère directeur est l'irréprochabilité politique au sens anarchiste. À ce titre, **D1** (le plus politique) est validé par délégation explicite.

- **D1 — Consentement : opt-in explicite de la lectrice, par partenariat.** Défaut = transparence minimale. Partager les détails change le destinataire de données confiées à chaque biblio séparément : acte positif d'autorisation, jamais tolérance par défaut. Continuité de #CL.8 et de la posture anti-surveillance ; la friction est le prix assumé de l'autonomie.
- **D2 — Granularité : droit par droit côté biblios ; consentement lectrice au niveau du partenariat.** Pas de « tout ou rien » (contraire à la minimisation) ; mais pas de consentement case par case côté lectrice (ingérable). Si la configuration gagne un droit, le consentement est resollicité.
- **D3 — Cercle : orthogonalité stricte.** Aucun partenariat ne se déduit d'un cercle commun (préserve le garde-fou central du cercle : « aucun droit parce que deux biblios partagent un cercle ») ; un partenariat peut exister sans cercle commun. Le cercle facilite socialement la rencontre, ne crée jamais le droit.
- **D4 — Symétrie stricte.** Même périmètre dans les deux sens. Pas d'asymétrie — elle réintroduirait un rapport de pouvoir, contraire à l'horizontalité. Un seul jeu de droits actifs par partenariat.
- **D5 — Révocation : visibilité conditionnée, pas copie.** A voit les données de B via un droit de lecture (RLS) conditionné au partenariat actif ; elle ne les détient jamais. À la rupture, l'accès se ferme sans résidu à effacer. Exception : les artefacts effectivement transmis (docs numériques) suivent le cycle de vie de #ILL-digital, hors révocation. La rupture laisse une trace d'audit (qui, quand).
- **D6 — Périmètre : droits réservés aux partenariats biblio↔biblio (deux biblios AnarBib).** Les collectifs extérieurs (`catalog_partners`) restent au niveau déclaratif de #PARTNERS, sans ouverture de droits sur des données internes. L'envoi d'un doc numérique vers un collectif sort du circuit AnarBib et relève de #ILL-digital.

## 6. Intersections à tracer

- **#PARTNERS** (infra déclarative) : socle visible ; le présent objet en est la sémantique.
- **`spec-multi-appartenance-lecteur`** : articulation transparence (E.2.5/E.3) ; mécanisme parallèle non bloquant.
- **`#ILL-digital`** : le partage numérique est un droit ouvert par le partenariat ; son cadrage §4.4 pose déjà « réutilise-t-on #PARTNERS ? ». À résoudre des deux côtés, sans absorber le circuit ici.
- **recursos digitais (P2 #7 de parité)** : gestion du fichier ; garder le cas d'usage *export-vers-partenaire* en vue.
- **`spec-acquisition-provenance v0.1`** : `partner_source` / `mutualization_status` partagent la notion de partenaire.
- **Réseau fédératif / cercle** : frontière droits vs pas-de-droits (cf. D3).
- **Cohérence inter-pages** : renommage de « Parcerias de correspondência » → MAJ du lien sortant de catalogação (Q4).

## 7. Place dans la séquence

1. **`spec-multi-appartenance-lecteur`** — peut démarrer dès maintenant (cadrage prêt), en citant le partenariat comme parallèle ; absorbe `spec-migration-compte v1.0` (vivante comme socle *jusqu'à* cette rédaction, pas au-delà).
2. **`spec-partenariat-biblios`** — rédigeable dès à présent : son cadrage est clos (les six décisions ci-dessus en sont la charpente).
3. **`spec-flux-partage-numerique`** (#ILL-digital) — après l'arbitrage politique §4.1 du cadrage #ILL-digital, porté aux biblios.

## 8. Prochaine étape

Cadrage **clos**. Rédiger `spec-partenariat-biblios` sur la base des six décisions du §5. La rédaction de `spec-multi-appartenance-lecteur` peut se mener en parallèle (elle cite le partenariat comme mécanisme parallèle non bloquant).

---

*Fin du dossier de cadrage — v0.2, arbitrages tranchés. À classer dans `docs/decisions/`.*
