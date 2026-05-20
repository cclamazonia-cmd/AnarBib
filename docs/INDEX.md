# 📚 INDEX général de la documentation — AnarBib

**Dernière mise à jour** : 20 mai 2026 (nettoyage du corpus documentaire)
**Maintenu par** : Xavier (lead dev) + Claude (assistant·e)

Ce document est la **porte d'entrée de toute la documentation** d'AnarBib. Il décrit l'organisation du dossier `docs/` et oriente vers les index spécialisés de chaque sous-dossier.

---

## 🗂️ Organisation du dossier `docs/`

```
docs/
├── INDEX.md                      ← vous êtes ici
├── manual.md                     Manuel d'utilisation (v1.0, avril 2026)
├── multiformat-viewers.md        Doc technique : viewer multi-format
├── livre-blanc-v0.1.md           Mini-Livre Blanc, point d'étape pré-Bologna
├── guide-gouvernance-anarbib.md  Guide de gouvernance (coordinateur·rices + admins réseau)
│
├── specs/                        Spécifications techniques et fonctionnelles
│   ├── INDEX.md                  → navigation par domaine
│   ├── INVENTAIRE.md             → description détaillée + carte des dépendances
│   └── archive/                  → anciennes versions des specs
│
├── decisions/                    Mémoire chronologique des décisions
│   ├── INDEX.md                  → index chronologique + thématique
│   └── archive/                  → prompts de reprise obsolètes, doublons
│
├── backlogs/                     Versions successives du backlog technique
│   ├── INDEX.md                  → version courante + historique
│   └── archive/                  → anciennes versions du backlog
│
└── legal/                        Documentation réglementaire (RGPD/LGPD)
    ├── README.md
    ├── INCIDENT_RESPONSE.md
    ├── REGISTRE_TRAITEMENTS.md
    └── dpa-{de,en,es,fr,it,pt-BR}.md
```

---

## 📄 Documents racine de `docs/`

| Document | Description | Statut |
|---|---|---|
| [`manual.md`](./manual.md) | Manuel d'utilisation du réseau de bibliothèques libertaires | v1.0 (avril 2026) — 🟢 stable |
| [`multiformat-viewers.md`](./multiformat-viewers.md) | Doc technique du viewer multi-format (PDF en prod, audio/vidéo/image disponibles côté code) | 08/05/2026 — 🟢 stable |
| [`livre-blanc-v0.1.md`](./livre-blanc-v0.1.md) | Mini-Livre Blanc — point d'étape politique et technique pré-Bologna FICEDL | v0.1 (05/05/2026) — 🟢 référence |
| [`guide-gouvernance-anarbib.md`](./guide-gouvernance-anarbib.md) | Guide de gouvernance à l'usage des coordinateur·rices de biblio et des admins réseau | v1.0 (11/05/2026) — 🟢 référence |

---

## 📁 Sous-dossiers — index spécialisés

### `specs/` — Spécifications

Le cœur documentaire technique du projet. 15 specs actives organisées en 5 familles : gouvernance, onboarding/migration, flux opérationnels, infrastructure transverse, et specs doctrinales de chantier ponctuel.

➡️ **[`specs/INDEX.md`](./specs/INDEX.md)** — navigation rapide par domaine
➡️ **[`specs/INVENTAIRE.md`](./specs/INVENTAIRE.md)** — description détaillée de chaque spec + carte des dépendances

**Réécritures majeures du 20/05/2026** : `spec-onboarding-biblioteca-v2.0`, `spec-administrateur-reseau-v0.4`, `spec-flux-consultations-v2.2` (intégration de la doctrine anti-méga-machine et des doctrines techniques #141).

### `decisions/` — Mémoire chronologique

L'historique vivant des décisions du projet : sessions de travail, chantiers, bilans, bugs, audits, riflexions, décisions de coordination. ~30 fichiers actifs, organisés chronologiquement.

➡️ **[`decisions/INDEX.md`](./decisions/INDEX.md)** — index chronologique et thématique

**Document doctrinal central** : `CHANTIER_doctrine_creation_objets_securises_2026-05-12.md` — la doctrine de création d'objets PostgreSQL sécurisés (fusion 12/05 + #150 du 18/05).

### `backlogs/` — Backlog technique

Les versions successives du backlog. Seule la dernière est vivante, les autres sont historiques.

➡️ **[`backlogs/INDEX.md`](./backlogs/INDEX.md)** — version courante + historique

**Version courante** : `AnarBib-Backlog-2026-05-20-v8.docx` (61 items, unifie les lignées v6/v15/H-I-J).

### `legal/` — Documentation réglementaire

DPA (Data Processing Agreement) en 6 langues, registre des traitements, procédure de réponse aux incidents. Documentation stable, peu modifiée.

*(Pas d'index dédié — 9 fichiers, structure plate, voir le `README.md` du dossier.)*

---

## 🧭 Comment naviguer dans la documentation

**« Je veux comprendre un domaine technique »** → `specs/INDEX.md` puis la spec de référence du domaine.

**« Je veux savoir ce qui a été décidé/fait à telle date »** → `decisions/INDEX.md`, recherche chronologique.

**« Je veux la liste des tâches à faire »** → `backlogs/INDEX.md` puis la version courante du backlog.

**« Je veux comprendre comment créer un objet backend proprement »** → `decisions/CHANTIER_doctrine_creation_objets_securises_2026-05-12.md`.

**« Je veux comprendre la gouvernance du projet »** → `guide-gouvernance-anarbib.md` (vue d'ensemble) puis `specs/spec-gouvernance-roles.md` et `specs/spec-administrateur-reseau-v0.4.md` (détails techniques).

**« Je découvre le projet »** → `livre-blanc-v0.1.md` puis `manual.md`.

---

## 📐 Conventions documentaires

### Nommage des fichiers dans `decisions/`

- `SESSION_*` — compte-rendu d'une session de travail
- `CHANTIER_*` — documentation d'un chantier (en cours ou clos)
- `BILAN_*` — bilan d'une période
- `BUG_*` — analyse d'un bug
- `QA_*` — plan ou résultat de QA manuelle
- `AUDIT_*` / `AUDITORIA_*` — audit technique
- `RIFLEXION_*` — capture conversationnelle d'une réflexion doctrinale
- `DECISOES_*` — décisions de coordination d'une biblio (pt-BR)
- `Prompt-Reprise-*` — mémento de reprise de chantier (⚠️ obsolète une fois le chantier clos → archive)

### Dossiers `archive/`

Chaque sous-dossier qui accumule des versions (`specs/`, `decisions/`, `backlogs/`) a un sous-dossier `archive/` pour les versions remplacées. **Ne jamais supprimer une archive** — elle peut servir dans plusieurs mois.

### Statuts visuels

- 🟢 Référence / stable — à utiliser comme source de vérité
- 🟠 En cours — chantier en cours d'implémentation
- 🟡 Cadré non implémenté — écrit mais pas encore exécuté
- 🔵 Référence historique — chantier ponctuel clos, conservé
- 🔴 Obsolète — à archiver (n'apparaît pas dans les index, voir `archive/`)

---

## 🔧 Maintenance de la documentation

Cet INDEX et les index spécialisés doivent être mis à jour :
- À chaque nouveau document créé
- À chaque promotion de version (spec, backlog)
- À chaque chantier clos
- À chaque nettoyage du corpus

Le dernier nettoyage complet du corpus a eu lieu le **20 mai 2026** (marathon de réécriture des specs + archivage des versions périmées + création des index).

---

*Fin de l'INDEX général. Pour chaque sous-dossier, consulter son index spécialisé.*
