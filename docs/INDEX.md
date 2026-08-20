# 📚 INDEX général de la documentation — AnarBib

**Dernière mise à jour** : 20 août 2026 — rafraîchissement après deux mois de retard : cinq dossiers absents de l'arborescence (`guides/`, `notes-audit/`, `schema/`, `drafts/`, `archive/`) et les traductions racine ajoutés, comptes réels, version courante du backlog corrigée (v30 → v33), source vivante de l'avancement re-pointée. *Précédemment : 10 juin 2026 (réorganisation de `decisions/` → `journal/` en sous-dossiers stricts par type). Refonte structurelle initiale : 3 juin 2026 — préséance documentaire, introduction du REGISTRE.*
**Maintenu par** : Xavier (lead dev) + Claude (assistant·e)

Ce document est la **porte d'entrée de toute la documentation** d'AnarBib. Il décrit la règle de préséance qui gouverne le corpus, oriente vers les documents transverses de référence, et présente l'organisation du dossier `docs/` avec ses index spécialisés.

---

## ⚖️ Préséance documentaire — règle de gouvernance

Le corpus AnarBib est vaste et vivant : il s'enrichit chaque semaine. Pour éviter qu'un fait recopié dans dix endroits devienne dix sources de vérité divergentes, **une règle de préséance gouverne tout le corpus** :

> **Font foi (couche normative)** : le **REGISTRE des décisions** (`specs/REGISTRE_decisions.md`), puis la **spec courante** du domaine concerné, puis le **backlog** courant.
> **Trace non-normative** : les documents `CADRAGE_*`, `CHANTIER_*`, `SESSION_*`, `BILAN_*`, `AUDIT_*`, `RIFLEXION_*`, `DECISOES_*` du dossier `journal/`. Ce sont des **traces historiques** précieuses, mais elles n'arbitrent pas.

En cas de doute ou de conflit apparent entre deux documents : **lire le REGISTRE d'abord.** Une spec qui dit « 6 locales » alors que `DOC-I18N-1` du registre dit 8 est une trace périmée d'avant l'ajout de ca/eo, pas une consigne — c'est le registre qui fait foi.

Cette règle a été formalisée par l'**audit de cohérence du corpus du 02/06/2026** (`journal/audits/AUDIT_coherence_corpus_2026-06-02.md`), qui a constaté que les drifts détectés relèvent quasi tous d'une même pathologie : un fait transverse (locales, doctrine de déploiement…) recopié dans chaque spec au lieu d'être cité depuis un foyer unique. Le REGISTRE est ce foyer.

**Conséquence pour la lecture** : un nouveau venu lit le REGISTRE (~835 lignes au 20/08/2026, condensé) avant tout autre document — il y trouve les doctrines transverses et les arbitrages structurants. Il a plus que doublé depuis juin : 36 sections de domaine, plus `§BG2` (sauvegardes).

---

## 📄 Documents transverses de référence

Documents de rang racine, à consulter en priorité selon le besoin. Ordre : le normatif d'abord, puis le politique vivant, puis l'opérationnel.

| Document | Rôle | Statut |
|---|---|---|
| [`specs/REGISTRE_decisions.md`](./specs/REGISTRE_decisions.md) | **Foyer unique des décisions et doctrines transverses** du projet. On cite l'ID ici, on ne reformule jamais ailleurs. | v0.1 du 02/06/2026 — 🟢 référence normative |
| [`governance/guide-gouvernance-fr.md`](./governance/) | Guide de gouvernance à l'usage des coordinateur·rices de biblio et des admins réseau (foyer FR ; 9 traductions dans `governance/`). | v1.0 du 11/05/2026 — 🟢 référence |
| [`GLB/AnarBib_Grand_Livre_blanc_v17_2026-05-29.docx`](./GLB/) | **Grand Livre Blanc** — le livre blanc vivant d'AnarBib : état politique et technique, trajectoire, doctrine. | v17 du 29/05/2026 — 🟢 référence (livre blanc vivant) |
| [`manual.md`](./manual.md) | Manuel d'utilisation du réseau de bibliothèques libertaires. | v1.0 (avril 2026) — 🟢 stable |
| [`multiformat-viewers.md`](./multiformat-viewers.md) | Doc technique du viewer multi-format (PDF en prod, audio/vidéo/image disponibles côté code). | 08/05/2026 — 🟢 stable |

> Le `livre-blanc-v0.1.md` (point d'étape de mai) est supersédé par le GLB v17 et part en archive. Le GLB est le livre blanc vivant ; v0.1 reste consultable pour mémoire dans `archive/` (à déplacer).

---

## 🗂️ Organisation du dossier `docs/`

```
docs/
├── INDEX.md                          ← vous êtes ici
├── manual.md + manual-{ca,de,el,en,eo,es,it,nl,pt-BR}.md      Manuel d'utilisation (10 langues)
├── cotation-et-cdd.md + cotation-et-cdd-{9 langues}.md        Guide cotation / CDD (10 langues)
├── multiformat-viewers.md            Doc technique viewer multi-format
│
├── specs/                            Spécifications techniques et fonctionnelles
│   ├── INDEX.md                      → navigation par domaine
│   ├── INVENTAIRE.md                 → description détaillée + dépendances
│   ├── REGISTRE_decisions.md         → ★ foyer unique des décisions (préséance)
│   └── archive/                      → anciennes versions des specs
│
├── journal/                          Mémoire chronologique (trace non-normative) — ex-`decisions/`, réorganisé en sous-dossiers par type (10/06/2026)
│   ├── INDEX.md                      → index chronologique + thématique
│   ├── cadrages/                     → CADRAGE_* (cadrage de chantier/spec)
│   ├── chantiers/                    → CHANTIER_* (documentation de chantier)
│   ├── sessions/                     → SESSION_* + BILAN_* + ETAT-* (⚠️ la copie d'ETAT-AVANCEMENT y est supersédée, cf. backlogs/)
│   ├── audits/                       → AUDIT_* / AUDITORIA_* / QA_*
│   ├── arbitrages/                   → DECISION_* / DECISOES_* / AMENDEMENT_* / CLOTURE_* / RIFLEXION_*
│   ├── bugs/                         → BUG_*
│   ├── operations/                   → CLEANUP_ / DEPLOIEMENT_ / REDEPLOY_ / REFACTOR_ / SETUP_
│   ├── references/                   → cles_ / ref_ / INVENTAIRE_addendum / PROMPT_reprise
│   ├── ficedl/                       → thésaurus FICEDL : audits + données de référence
│   └── archive/                      → prompts de reprise obsolètes, doublons
│
├── backlogs/                         Backlog technique (Markdown depuis le 10/06) + états d'avancement
│   ├── INDEX.md                      → version courante + historique
│   ├── AnarBib-Backlog-2026-06-17-v33.md          ← version courante
│   ├── ETAT-AVANCEMENT-multisessions.md           ← ★ avancement par chantier (repris le 20/08)
│   ├── ETAT-lancement-consolide-2026-07-03.md     ← boussole « avant lancement public »
│   └── archive/                      → anciennes versions (v8→v32, .docx et .md)
│
├── GLB/                              Grand Livre Blanc (livre blanc vivant)
│   ├── AnarBib_Grand_Livre_blanc_v17_2026-05-29.docx
│   └── archive/                      → v15, v16…
│
├── cartographie/                     Carte du réseau (uMap) — ⚠️ contenu très majoritairement NON VERSIONNÉ
│   ├── AnarBib_recensement_bibliotheques_libertaires.docx   ← seul fichier suivi par git
│   └── (local, ignoré par .gitignore) carte-publique/carte-reseau .umap/.geojson, etc.
│
├── db/                               Dumps Supabase (hors git — README uniquement)
│   └── README.md                     → convention de dump (les *.sql ne sont pas suivis)
│
├── governance/                       Guide de gouvernance traduit (10 langues, .md + .docx)
│   └── guide-gouvernance-{ca,de,el,en,eo,es,fr,it,nl,pt-BR}.{md,docx}
│
├── legal/                            Documentation réglementaire (RGPD/LGPD)
│   ├── README.md
│   ├── INCIDENT_RESPONSE.md
│   ├── REGISTRE_TRAITEMENTS.md       → registre art. 30 (aligné 20/08/2026)
│   └── dpa-{de,en,es,fr,it,pt-BR}.md
│
├── guides/                           Vadémécums pratiques du commun, servis dans l'app (10 langues chacun)
│   └── guide-{digitalizar,indexar-assunto,scan-qr,thesaurus-ficedl}-{lang}.md
│
├── notes-audit/                      Chartes et audits de langue (langage inclusif v1/v2, charte relationnelle, audit i18n)
│
├── schema/                           Schéma de référence de la base
│   ├── README.md
│   └── baseline_schema_2026-06-11.sql   → socle rejouable (cf. risque « migrations incrémentales »)
│
├── drafts/                           Brouillons techniques non promus (SQL en attente d'arbitrage)
│
└── archive/                          Documents supersédés conservés
    ├── livre-blanc-v0.1.md           → supersédé par le GLB v17
    └── db-migrations-legacy-pre-woodpecker/   → 44 migrations d'avant la CI
```

---

## 📁 Sous-dossiers — index spécialisés

### `specs/` — Spécifications et REGISTRE

Le cœur documentaire technique. **41 specs vivantes** (`spec-*.md`) au 20/08/2026, organisées par domaine. Contient également le **REGISTRE des décisions** (`REGISTRE_decisions.md`), foyer unique du corpus, ainsi que `CHARTE_corpus.md`, `INVENTAIRE.md`, et les dossiers `maquettes/`, `captures/`, `archive/`.

➡️ [`specs/INDEX.md`](./specs/INDEX.md) — navigation par domaine, à jour au 20 août 2026
➡️ [`specs/INVENTAIRE.md`](./specs/INVENTAIRE.md) — description détaillée et carte des dépendances
➡️ [`specs/REGISTRE_decisions.md`](./specs/REGISTRE_decisions.md) — **★ foyer normatif** : doctrines transverses (DOC-*), arbitrages par domaine (RES-*, PROF-*, ILL-*, NOTIF-*…), points ouverts et drifts détectés.

**Trilogie doctrinale du 02/06** : `spec-multi-appartenance-lecteur`, `spec-partenariat-biblios` (figées) + `spec-flux-partage-numerique` (charpentée). **Cluster catalogue 01/06** : 6 specs (4 catalogage + 2 découverte lecteur).

### `journal/` — Mémoire chronologique (trace non-normative) *(ex-`decisions/`)*

L'historique vivant du projet. **176 fichiers** (162 hors `archive/`) réorganisés le **10/06/2026** en **sous-dossiers stricts par type de document** (le dossier était auparavant un dépôt plat « `decisions/` » devenu illisible) : `cadrages/`, `chantiers/`, `sessions/`, `audits/`, `arbitrages/`, `bugs/`, `operations/`, `references/`, **`ficedl/`** *(ajouté depuis)*, `archive/`. Ce dossier est de la **trace** : il documente *comment* on est arrivés aux décisions, pas ce qui *fait foi* — pour cela, voir le REGISTRE. (Le nom `journal/` reflète mieux ce contenu chronologique que l'ancien `decisions/` : les vraies décisions vivent au REGISTRE.)

➡️ [`journal/INDEX.md`](./journal/INDEX.md) — index chronologique et thématique, avec sélection des documents doctrinaux centraux.

**Document fondateur de la doctrine documentaire actuelle** : `journal/audits/AUDIT_coherence_corpus_2026-06-02.md` — qui a institué le REGISTRE et la règle de préséance.

### `backlogs/` — Backlog technique

Versions successives. Seule la dernière est vivante, les autres sont historiques.

➡️ [`backlogs/INDEX.md`](./backlogs/INDEX.md) — version courante + historique

**Version courante** : `AnarBib-Backlog-2026-06-17-v33.md` (Markdown ; v29 et antérieurs `.docx` archivés). Le backlog a eu un rythme d'incrémentation rapide (v8 → v33 en un mois), puis s'est stabilisé — depuis juillet, l'avancement se lit ailleurs :

- [`backlogs/ETAT-AVANCEMENT-multisessions.md`](./backlogs/ETAT-AVANCEMENT-multisessions.md) — consolidation par chantier de toutes les sessions. **Repris le 20/08/2026** : tableau de bord des 26 chantiers, statuts vérifiés en production (tables, crons, edge functions) et non déduits du seul `git log`.
- [`backlogs/ETAT-lancement-consolide-2026-07-03.md`](./backlogs/ETAT-lancement-consolide-2026-07-03.md) — boussole « que reste-t-il avant le lancement public ? », vérifiée en prod le 03/07 ; remplace sur ce point le portrait du v33.

> ⚠️ **Doublon à connaître.** `ETAT-AVANCEMENT-multisessions.md` existe **en deux exemplaires** : celui de `backlogs/` (vivant, dernière modification le 20/06) et une copie figée au 10/06 dans `journal/sessions/`, laissée par un déplacement que les sessions suivantes n'ont pas suivi. **C'est celui de `backlogs/` qui fait référence** ; la copie du journal porte un tampon de supersession et reste comme trace.

### `GLB/` — Grand Livre Blanc

Le livre blanc vivant d'AnarBib — état politique et technique, trajectoire, doctrine.

**Version courante** : `AnarBib_Grand_Livre_blanc_v17_2026-05-29.docx`. Les versions antérieures (v15, v16…) sont dans `GLB/archive/`.

### `cartographie/` — Carte du réseau

L'écosystème de la carte des bibliothèques libertaires sur uMap : recensement, fichiers uMap et GeoJSON, classification.

> ⚠️ **Ce dossier est presque entièrement hors git, et c'est délibéré.** `.gitignore` exclut `docs/cartographie/*` et ne réintègre que `AnarBib_recensement_bibliotheques_libertaires.docx` : les données cartographiques ne sont **pas publiables tant que les collectifs n'ont pas validé leur apparition** (cf. `arbitrages/DEFINITION_MEMBRE_2026-05-27.md`). Les autres fichiers vivent dans la copie de travail de la coordination.
>
> *Corrigé le 20/08/2026 : cet INDEX décrivait ici onze fichiers et pointait vers un `GUIDE_carte_publique_explorar.md` — aucun n'est présent dans le dépôt.* La doctrine de la carte se lit au REGISTRE **§ 34 `MAP`** ; la spec est [`specs/spec-cartographie-reseau.md`](./specs/spec-cartographie-reseau.md).

### `db/` — Dumps Supabase

Dumps SQL du schéma de production, **non versionnés dans git** (volumineux, changent à chaque export). Seul le README est suivi. Servent de point de récupération, pas de source de vérité — celle-ci reste les migrations versionnées dans `supabase/migrations/`.

➡️ [`db/README.md`](./db/README.md) — convention de dump et `.gitignore` associé.

### `legal/` — Documentation réglementaire

DPA en 6 langues, registre des traitements, procédure de réponse aux incidents. Documentation stable, peu modifiée.

*(Pas d'index dédié — structure plate, voir le `README.md` du dossier.)*

### `governance/` — Guide de gouvernance traduit

Le guide de gouvernance d'AnarBib en **10 langues** (`ca, de, el, en, eo, es, fr, it, nl, pt-BR`), en `.md` + `.docx`. **Foyer canonique : `guide-gouvernance-fr.md`** (les autres langues en sont les traductions). Documentation stable.

---

## 🧭 Comment naviguer dans la documentation

**« Qu'est-ce qui fait foi sur tel point ? »** → [`specs/REGISTRE_decisions.md`](./specs/REGISTRE_decisions.md). Le registre porte les doctrines transverses (DOC-*) et les arbitrages par domaine. En cas de divergence apparente entre deux documents, c'est lui qui tranche.

**« Je veux comprendre un domaine technique »** → [`specs/INDEX.md`](./specs/INDEX.md) puis la spec de référence.

**« Je veux savoir ce qui a été décidé/fait à telle date »** → [`journal/INDEX.md`](./journal/INDEX.md), recherche chronologique. Pour la valeur normative d'une décision, vérifier ensuite au REGISTRE.

**« Je veux la liste des tâches à faire »** → [`backlogs/INDEX.md`](./backlogs/INDEX.md) puis la version courante.

**« Je découvre le projet »** → le **Grand Livre Blanc v17** (`GLB/`) puis [`manual.md`](./manual.md).

**« Je veux comprendre la gouvernance du projet »** → [`governance/guide-gouvernance-fr.md`](./governance/guide-gouvernance-fr.md) (vue d'ensemble) puis `specs/spec-gouvernance-roles.md` et `specs/spec-administrateur-reseau-v0.4.md` (détails techniques).

**« Je veux comprendre comment créer un objet backend proprement »** → REGISTRE entrée `DOC-OBJ-2`, qui pointe vers `journal/chantiers/CHANTIER_doctrine_creation_objets_securises_2026-05-12.md` pour la trace détaillée.

**« Où en est la carte du réseau ? »** → [`specs/spec-cartographie-reseau.md`](./specs/spec-cartographie-reseau.md) et le REGISTRE **§ 34 `MAP`** (arbitrages tranchés, implémentation post-Bologne). Les données elles-mêmes ne sont pas dans le dépôt (voir ci-dessus).

---

## 📐 Conventions documentaires

### Nommage et rangement des fichiers dans `journal/`

Depuis le 10/06/2026, le **préfixe détermine le sous-dossier** (rangement strict par type de document) :

| Préfixe | Sous-dossier | Sens |
|---|---|---|
| `CADRAGE_*` | `cadrages/` | cadrage d'un chantier ou d'une spec |
| `CHANTIER_*` (+ `EA-13_`, `EA05_`, `MODULE_*STATUT`, `Dossier_ouverture_*`) | `chantiers/` | documentation d'un chantier |
| `SESSION_*`, `BILAN_*` | `sessions/` | compte-rendu de session / bilan de période |
| `AUDIT_*`, `AUDITORIA_*`, `QA_*` | `audits/` | audit technique, QA manuelle |
| `DECISION_*`, `DECISOES_*` (coord. biblio pt-BR), `AMENDEMENT_*`, `CLOTURE_*`, `RIFLEXION_*`, `DEFINITION_*` | `arbitrages/` | décisions, clôtures, réflexions doctrinales |
| `BUG_*` | `bugs/` | analyse d'un bug |
| `CLEANUP_*`, `DEPLOIEMENT_*`, `REDEPLOY_*`, `REFACTOR_*`, `SETUP_*` | `operations/` | opérations infra/maintenance ponctuelles |
| `cles_*`, `ref_*`, `INVENTAIRE_addendum`, `PROMPT_reprise_*` | `references/` | données de référence, mémentos de reprise |
| `Prompt-Reprise-*` obsolètes, doublons | `archive/` | trace remplacée (⚠️ jamais supprimée) |
| `PLAN_*` | `chantiers/` | plan de travail détaillé (séquencement, jalons) |
| `MEMO_*` | `cadrages/` | mémo de cadrage, plus court qu'un `CADRAGE_` |
| `MATRICE_*`, `PROTOCOLE_*` | `audits/` | grille d'audit systématique · protocole de validation à dérouler |
| `RUNBOOK_*`, `BASELINE_*`, `SHORTLIST_*`, `MESSAGE_*`, `FICHE_*`, `HEBERGEURS_*` | `operations/` | procédure opérationnelle · référence technique · options comparées · correspondance avec des tiers |
| `ETAT-*` | `sessions/` | photographie d'avancement (multi-sessions ou d'un chantier) |
| *(données FICEDL)* | `ficedl/` | thésaurus FICEDL — audits et données de référence |

> Onze préfixes ajoutés le 20/08/2026, constatés dans le dossier. Deux restent **ambigus** : `NOTE_*` (en `arbitrages/` et `operations/`) et `AUDIT_*` (en `audits/`, `operations/` et `ficedl/`) — ranger selon l'objet, doctrine ou infra.

> Un nouveau document de trace va dans le sous-dossier de son type. En cas de doute, `references/` ou `chantiers/`.

### Dossiers `archive/`

Chaque sous-dossier qui accumule des versions (`specs/`, `journal/`, `backlogs/`, `GLB/`) a un sous-dossier `archive/` pour les versions remplacées. **Ne jamais supprimer une archive** — elle peut servir dans plusieurs mois.

### Statuts visuels

Pour les **specs et documents** :
- 🟢 Référence / stable — à utiliser comme source de vérité
- 🟠 En cours — chantier en cours d'implémentation
- 🟡 Cadré non implémenté — écrit mais pas encore exécuté
- 🔵 Référence historique — chantier ponctuel clos, conservé
- 🔴 Obsolète — à archiver (n'apparaît pas dans les index, voir `archive/`)

Pour les **entrées du REGISTRE** :
- ✅ acté — décision arrêtée
- 🟡 ouvert — à trancher
- 🔵 supersédé/historique
- ⚠️ drift détecté — voir l'audit de cohérence le plus récent

### Tampon de supersession

Quand une spec est absorbée par une autre (par exemple `spec-migration-compte` absorbée dans `spec-multi-appartenance-lecteur` le 02/06), le fichier supersédé reçoit un **tampon en tête** indiquant qui le supersède et l'ID de décision au REGISTRE, puis part en `archive/`. Convention « close before open » étendue à la documentation.

---

## 🔧 Maintenance de la documentation

Cet INDEX et les index spécialisés sont mis à jour :
- à chaque nouveau document créé ;
- à chaque promotion de version (spec, backlog) ;
- à chaque chantier clos ;
- à chaque nettoyage du corpus.

**Audits récents :**
- **20 août 2026** — rafraîchissement des index après deux mois de retard (cet INDEX + `journal/INDEX.md`). Deux dérives trouvées au passage et corrigées : le **registre des traitements** (art. 30 RGPD) listait encore Cloudflare Turnstile comme sous-traitant et un transfert US, alors que l'anti-bot est passé à **Altcha auto-hébergé** les 19-20/08 ; et le doublon `ETAT-AVANCEMENT-multisessions.md` signalé ci-dessus. Doctrine mobile graduée au REGISTRE **§ 36 `MOBILE`**.
- **2 juin 2026** — audit de cohérence du corpus (`journal/audits/AUDIT_coherence_corpus_2026-06-02.md`) → naissance du REGISTRE et formalisation de la préséance documentaire.
- **20 mai 2026** — nettoyage complet : réécriture des specs, archivage des versions périmées, création des index spécialisés.

**Discipline « close before open » étendue à la doc** (DOC-CLOSE-1 du REGISTRE) : un chantier n'est clos que quand ses vérités ont gradué au REGISTRE/à la spec courante, et que sa trace est tamponnée. On ne laisse pas une décision en suspens entre une session et la suivante.

---

*Fin de l'INDEX général. Pour chaque sous-dossier, consulter son index spécialisé. Pour ce qui fait foi : le REGISTRE.*
