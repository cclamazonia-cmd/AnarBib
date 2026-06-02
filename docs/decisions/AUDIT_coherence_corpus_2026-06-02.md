# 🔍 AUDIT DE COHÉRENCE DU CORPUS — AnarBib

- **Date :** 2 juin 2026
- **Périmètre :** 22 specs vivantes + backlog v25 (le cluster catalogue 01/06 est couvert en addendum dans le registre).
- **Méthode :** extraction des décisions/arbitrages/doctrines de chaque spec → registre unique (`REGISTRE_decisions.md`) → détection des contradictions et obsolescences inter-documents.
- **Verdict :** corpus globalement sain. **4 drifts vifs**, **1 tension de doctrine**, **1 divergence de terminologie**. Aucun ne casse la prod ; tous sont corrigeables en une touche grâce au registre.

---

## Drifts vifs (à corriger)

### DRIFT-1 — « 6 locales » recopié dans ~13 specs (devrait être 8) · **priorité haute**

Presque toutes les specs antérieures à l'ajout de ca/eo écrivent « × 6 locales (pt-BR, fr, es, en, it, de) » : admin-reseau, cartographie, flux-consultations, flux-emprunts, gouvernance-roles, migration-mail, onboarding-biblioteca, onboarding-criar-conta, profils, validation-physique, workflow-reservation (+ 114a 🔵). Les specs récentes (acquisition §7, notify-prorrogacao D5, cluster catalogue) disent correctement **8**.

C'est l'exemple parfait du fait recopié au lieu d'être cité : il a un seul foyer désormais (**DOC-I18N-1**).

**Correction recommandée (pas 13 réécritures) :**
1. Le registre porte la valeur canonique (8) — fait.
2. Une ligne de préséance en tête d'INDEX : « le nombre de locales est régi par DOC-I18N-1 (8) ; tout “6 locales” dans une spec est une trace périmée, pas une consigne. » → neutralise le drift sans toucher 13 fichiers.
3. *(Optionnel, hygiène)* balayage `6 locales → locales du projet (cf. DOC-I18N-1)` au prochain passage de chaque spec, pas en urgence.

### DRIFT-2 — Renvois vers `spec-migration-compte` (4 specs) alors qu'elle est absorbée · **priorité haute**

`gouvernance-roles` (L61, L1273), `onboarding-biblioteca` (L14, L121, L971, L976), `validation-physique` (L668 + clôture L839 « Prochaine étape : spec migration de compte »), `workflow-reservation` (L16) traitent `spec-migration-compte.md` comme la spec vivante de la migration de compte. Or son socle est **absorbé dans `spec-multi-appartenance-lecteur`** (acté backlog v25, HYGIENE-SPECS-0106, Option D · VII.1) et le fichier v1.0 est archivé.

**Correction recommandée :**
1. Registre : entrée `ACCT-MIGRATION` → foyer = `spec-multi-appartenance-lecteur` (à rédiger) ; `migration-compte` = 🔵 archivée.
2. Tampon de supersession en tête de `spec-migration-compte` archivée (si pas déjà fait) : « Socle absorbé dans spec-multi-appartenance (DEC ACCT-MIGRATION). »
3. Le renvoi le plus saillant à corriger : la **clôture de validation-physique** → « Prochaine étape : `spec-multi-appartenance-lecteur` » (cohérent avec son propre amendement par-appartenance du 30/05).

### DRIFT-3 — `renouvellement-granulaire §9` garde « ouvert » ce que NPRO a tranché · **priorité moyenne**

RENOV-2 liste comme « à arbitrer phase 2/3 » la question « la notif de prolongation distingue-t-elle item vs emprunt ? ». Or `spec-notify-prorrogacao-granulaire` (D1–D6) **et** le chantier #NOTIFY-prorrogacao **clos le 30/05** l'ont tranchée : émission par item depuis `fn_v2_extend_core`, trigger header **retiré** (D4), texte « par exemplaire » × 8 locales (D5).

Effet secondaire : `notify-prorrogacao` D5 se marque encore « **point ouvert : valider la formulation** » alors que la formulation est livrée (chantier clos).

**Correction recommandée :**
1. `renouvellement §9` RENOV-2 → « résolu, cf. NPRO-D1/D4 ».
2. `notify-prorrogacao` D5 → statut « acté (chantier clos 30/05) ».

### DRIFT-4 — `cartographie §0` : « octolingue » puis « 6 locales actuelles » (auto-contradiction) · **priorité basse**

Une seule ligne se contredit : compatibilité **octolingue** annoncée, puis « les **6 locales** actuelles ». Correction triviale : « les **8 locales** actuelles (cf. DOC-I18N-1) ».

> **✅ Corrigé 02/06** : cartographie alignée sur 8 locales (§0, arbitrage B, coûts recalculés 121×8) + en-tête front-matter posé.

---

## Tension de doctrine (à préciser une fois)

### DRIFT-5 — SQL Editor : doctrine absolue vs usages légitimes

DOC-DEPLOY-1 dit « **jamais** SQL Editor ». Mais `cycle-vie-peb` (arbitrage 4) prescrit la suppression de 8 PEB de test **en SQL Editor (rôle postgres)**, et `historico-retencao` (L736) prévoit un test de bout en bout en SQL Editor. Ce ne sont pas des migrations/DDL — ce sont du **nettoyage ponctuel de données de test** et de la **lecture de validation**.

Ce n'est pas une faute, c'est une **imprécision de la doctrine**. À trancher une fois (DOC-DEPLOY-3, statut ouvert) :
> SQL Editor interdit pour migrations/DDL **avant push** ; toléré pour nettoyage ponctuel de données de test et lectures de validation, à tracer (commentaire + date).

Une fois tranché, les deux specs cessent d'être « en infraction ».

---

## Divergence de terminologie (à harmoniser)

### DRIFT-6 — « Camadas 1/3 » (acquisition) vs « couches trace/provenance/destination » (catalogue)

`acquisition-provenance` décrit le modèle d'exemplaire en **Camadas 1 (notice) / 3 (exemplaire)** ; le cluster catalogue décrit **3 couches trace / provenance / destination**. Mêmes objets, deux vocabulaires. Pas une contradiction, mais une source de confusion (et de fausse piste de code) au moment de la migration mutualisée CAT-B6 ↔ ACQ-Q1.

**Correction recommandée :** choisir un vocabulaire canonique (je suggère « couches trace/provenance/destination », plus parlant que des numéros) et l'inscrire au registre comme note de ITEM/ACQ/CAT, l'autre spec citant.

> **Rectificatif 02/06.** Vérification faite, ce n'est **pas** « mêmes objets, deux noms » : « Camadas » = **niveaux de granularité** (œuvre → holding → exemplaire, axe vertical) ; « couches » = **facettes de l'exemplaire** (trace/provenance/destination, axe horizontal). Deux axes orthogonaux, dont le seul vrai risque est la **collision du mot** « couche/camada ». Résolu non par fusion mais par **désambiguïsation** : doctrine `DOC-MODELE-1` au registre + note croisée dans acquisition §4 et exemplaires §2. **✅ Corrigé 02/06.**

---

## Vérifié sain (non-drifts)

- **Doctrine de déploiement** cohérente dans les specs récentes (migration-mail v0.4, acquisition §7, notify-prorrogacao) — la correction v0.4 a bien purgé l'ancienne doctrine CLI manuelle.
- **RPC v3** cohérente (acquisition, cartographie, catalogue).
- **« On notifie qui n'a pas initié »** (DOC-NOTIF-1) cohérent entre consultas, emprunts et réseau.
- **`#J`** n'apparaît qu'en référence historique propre (granularite : « absorbe l'ancien #J »).
- **R7–R11** correctement propagés consultas → emprunts (31/05), avec les non-applicabilités explicitées (R8 côté emprunts).

---

## Ce que cet audit prouve (et la suite)

Le corpus n'est pas incohérent par négligence : il est cohérent **dans chaque spec à sa date**, et les drifts sont presque tous des **faits transverses recopiés** (locales) ou des **renvois qui n'ont pas suivi une absorption** (migration-compte). Exactement les deux pathologies que le registre + la préséance suppriment à la racine.

**Séquence proposée (une touche chacune) :**
1. Adopter le registre (`REGISTRE_decisions.md`) + ajouter la ligne de préséance + DOC-I18N-1 en tête d'INDEX → tue DRIFT-1 et arme la règle générale.
2. Corriger les 2 renvois les plus saillants : clôture de validation-physique (DRIFT-2) et RENOV-2 (DRIFT-3).
3. Trancher DOC-DEPLOY-3 (DRIFT-5) — une ligne, et la doctrine SQL Editor est nette pour tout le corpus.
4. Harmoniser le vocabulaire des couches (DRIFT-6) avant d'écrire la migration mutualisée.
5. DRIFT-4 : à la prochaine ouverture de cartographie (de toute façon en chantier).

Les réécritures de masse (« 6→8 » dans 13 specs) ne sont **pas** prioritaires : la ligne de préséance les rend inoffensives. On les fait à l'usage, spec par spec, quand on la rouvre — discipline « close before open ».
