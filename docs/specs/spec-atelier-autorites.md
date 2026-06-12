# 🛠️ spec-atelier-autorites — Atelier autorités (contribution fédérée)

| Champ | Valeur |
|---|---|
| **Domaine** | Couche d'autorités partagée — **face contribution** (personnes, collectivités, matières). Pendant *production* de la lecture enrichie de `spec-notice-autorite-enrichie` §4. |
| **Version** | v0.1 (12 juin 2026) — cadrage. Arbitrages FED-O7 (**ATE-1..4**) **validés le 12/06** ; à inscrire au REGISTRE (§10). Aucune implémentation. |
| **Statut** | 🟡 Cadrage validé (arbitrages tranchés). **Instruit FED-O7.** Préalables structurants non levés (tables collectivité/matière ; rôle contributeur) ; ATE-O1..O5 ouvertes. |
| **Foyer décisions** | **REGISTRE** : parent **FED-O7** (gouvernance des autorités partagées) ; décisions propres = série **`ATE-*`** (proposées ici, à inscrire après validation). *On cite l'ID, on ne reformule pas le registre.* |
| **Dépendances entrantes** | `spec-notice-autorite-enrichie` §5 (vision de l'atelier, INV-6) · `spec-outils-federalistes` (face fédération, grammaire **FED-O5**) · `spec-doublons-detection-fusion` (mécanisme **CAT-H1**) · `spec-autorites-notes-bio-multilingues` (socle **CAT-I1**) · paquet **RAPPORTS-REDE** (signal amont R3b/R4). |
| **Dépendances sortantes** | Création des autorités **collectivité** et **matière** (préalable, hors périmètre catalogage) · rôle/compte **`network_contributors`** · infra `notify-event` (sous-paquet 1b). |
| **Préséance** | REGISTRE + cette spec font foi ; en cas de conflit, le registre tranche. Ce fichier est un **draft** tant que les `ATE-*` ne sont pas ratifiés. |

---

## 1. Objet & doctrine

La couche d'autorités (auteur·rices, et à terme **collectivités** et **matières**) est un **corpus partagé** par tout le réseau. La corriger, l'enrichir, la désambiguïser **dépasse une biblio seule** (`spec-notice` §1) : c'est un travail fédéré. L'**Atelier** organise ce travail *sans* créer d'échelon au-dessus des bibliothèques.

Quatre principes (hérités, non négociables) :
- **Propositions, jamais édition directe.** Une création / modification / fusion d'autorité est une **proposition** examinée par les biblios concernées et la coordination de l'atelier (`spec-notice` §5.2).
- **Le consentement plutôt que le décompte.** Grammaire de l'absence d'objection motivée — réutilise **FED-O5** (cercles) et la cooptation des admins réseau. **Pas de vote, pas de quorum, pas d'autorité tranchante** (**INV-6** de `spec-notice`).
- **Anti-panoptique** (**FED-7**) : aucune vue agrégée du « qui consulte quoi » ; les notifications sont servies aux **parties concernées**, pas diffusées.
- **Mémoire avant tout.** L'autorité bien faite est le rendu public (`spec-notice` §4) qui donne envie de contribuer ; l'atelier en est la fabrique.

---

## 2. État des lieux (base vérifiée en prod le 12/06/2026)

> Méthode du projet : nommer l'existant avant de concevoir.

**Déjà livré (le substrat) :**
- **Mécanisme bas niveau de fusion — `CAT-H1`** : `public.merge_author(bigint,bigint)`, `merge_book(bigint,bigint)`, `suggest_author_duplicates`, `suggest_book_duplicates`, table d'audit **`merge_log`**. Validation **humaine**, appelé **directement par le staff** — **aucun emballage proposition/consentement** à ce jour.
- **Signal amont `R3b`/`R4`** (paquet RAPPORTS-REDE) : `api.report_autorites_doublons()` et `report_autorites_a_completer()` — **lecture seule**, gardés `fn_caller_is_network_admin`. Ils *détectent* doublons et lacunes, **n'écrivent rien** ; le commentaire de la migration dit déjà « la fusion relève du cercle fédéral ». C'est précisément ce que FED-O7 doit instituer.
- **Socle Ateliers — `CAT-I1`** : `author_translations` étendue (`status` draft/reviewed + `reviewed_by/at`), édition bio **post-publication** (clé `published_author_id`), `variant_forms jsonb`.
- **Infrastructure d'événements** : EF `notify-event` + registre `_shared/core/dispatch.ts`. **Deux patrons** d'émission coexistent (voir §6). `mail-strings` i18n 10 locales (**DOC-I18N-1**). Cron de réconciliation (`reconcile-task-dispatch`, modèle).
- **Précédents de cycle proposition/consentement** : `library_profile_proposals` (+ crons `fn_execute_due_profile_proposals` /15 min, `fn_expire_overdue_profile_proposals` quotidien) ; `network_administrator_cooptation_proposals` ; `network_admin_collective_removal_proposals`. Grammaire d'objection + échéance + auto-exécution **déjà éprouvée**.
- **Primitive cercle (FED 1/1b)** : `circles`/`circle_*` (uuid), RPC `api.fn_circle_*`, cron `anarbib-circle-resolve-due-daily`. *(Référence de style et de grammaire FED-O5.)*

**Absent (le gap que cette spec adresse) :**
- Toute table de **propositions d'autorité** (création / modification / fusion).
- Le rôle / compte **`network_contributors`** (le 4ᵉ cercle de contribution).
- Les tables d'autorité **collectivité** et **matière** (préalable structurant, `spec-notice` D7).
- Tout **événement d'autorité** câblé dans `notify-event` (le sous-paquet 1b, §6).

---

## 3. Arbitrages FED-O7 — validés le 12/06/2026

> Les quatre points « à trancher » du registre (FED-O7), **tranchés** le 12/06. Ancrés dans la doctrine existante. Statut : **validés**, à inscrire au REGISTRE (§10) avant implémentation.

### ATE-1 (portée) — **réseau entier, périmètre d'objection dérivé des données**
Le corpus d'autorités est **unique et partagé** : la gouvernance est **réseau entier**, *pas* par cercle (`círculo` = objet d'affinité niveau biblio, FED-1 — mauvaise échelle pour un corpus mutualisé). Mais, conformément à **FED-7** et à « discussion entre compas concerné·es et biblios utilisatrices » (`spec-notice` §5.2), l'ensemble des **parties prenantes** d'une proposition donnée est **dérivé des données** : les **biblios utilisatrices** de l'autorité visée (≥ 1 document lié) + la **coordination de l'atelier**. *Raison* : aucun « super-cercle fédéral » au-dessus des biblios (anti-hiérarchie) ; on n'implique que les réellement concerné·es.

### ATE-2 (grammaire) — **réemploi de FED-O5 (opt-out / anti-blackball), modulé par l'impact ; pas de régime à vote**
Réutiliser la grammaire **FED-O5** : fenêtre d'objection, **silence = consentement**, auto-application à l'échéance ; **objection motivée** ⇒ suspension + ouverture de la discussion (**anti-blackball**) ; refus ssi **≥ 2 biblios utilisatrices distinctes** objectent (ou arbitrage de la coordination atelier, qui **anime mais ne tranche pas seule**). **Fenêtre modulée par l'impact** : courte pour création / enrichissement / traduction (faible risque, réversible) ; longue (≈ 14 j, comme les cercles) pour **fusion** (réécrit le corpus, repointe beaucoup de documents). *Raison* : cohérence doctrinale (`spec-notice` INV-6 + §5.2 « consentement sans vote » ; `spec-outils-federalistes` §1 « le consentement plutôt que le décompte »).

### ATE-3 (qui propose / qui objecte)
- **Propose** : tout **`network_contributors`** (compte réseau non rattaché, le 4ᵉ cercle) **et** tout staff de biblio membre (`bibliotecário`/`coordenador`). Le contributeur **propose, n'édite jamais directement** (`spec-notice` §5.2).
- **Objecte / consent** : le **`coordenador`** d'une biblio **utilisatrice** de l'autorité visée (**FED-4** : voir = concerné·e, *agir/objecter* = coordenador) + la **coordination de l'atelier**. Un contributeur **ne peut pas être seul juge** de sa propre proposition.
- **Exécute** : à l'échéance sans objection (ou sur consentement explicite anticipé) → **auto-application** : création/édition appliquée, ou appel **`merge_author`/`merge_book`** pour une fusion, **tracé dans `merge_log`** + journal des contributions.

### ATE-4 (quorum) — **aucun**
Consentement = **absence d'objection motivée** dans la fenêtre (modèle opt-out FED-O5), **jamais un décompte de voix**. `spec-notice` §5.2 + INV-6 sont explicites : « pas de quorum, pas de scrutin ».

---

## 4. Modèle de proposition & consentement

**Types de proposition** : `creation` · `edition` (champs ciblés, dont bio/dates/IDs externes/variant_forms) · `fusion` (doublon → canonique) · `traduction` (bio courte, locale DOC-I18N-1).

**Cycle de vie** (calqué sur `library_profile_proposals` + FED-O5) :

```
                 objection motivée (1)            ≥2 biblios distinctes
   [open] ──────────────────────────► [contested] ───────────────────► [refused]
     │  silence jusqu'à l'échéance              │  discussion / retrait
     │                                          └──────────► [open] (amendée)
     ▼ (fenêtre écoulée, 0 objection)
  [resolved_consent] ──► exécution ──► [applied]   (merge_log + journal)
```

- **Fenêtre** : par défaut courte (création/édition/traduction) ; longue (≈ 14 j) pour `fusion` (ATE-2).
- **Objection** : motivation obligatoire (≥ N caractères, cf. cercles `≥ 20`) ; **anti-blackball** = une objection isolée *suspend et ouvre*, ne refuse pas (ATE-2).
- **Échéance idempotente** : un cron `fn_authority_resolve_due()` (modèle `fn_circle_resolve_due` / `fn_execute_due_profile_proposals`) résout les propositions échues — **rejouable sans effet de bord**.
- **Exécution d'une fusion** = appel de `merge_author`/`merge_book` existants (CAT-H1) ; l'atelier est l'**emballage gouvernance**, pas une réécriture du mécanisme.

---

## 5. Modèle de données (à créer — paquet 1)

> Esquisse de cadrage, **non normative** (le DDL sera tranché au paquet 1).

- **`network_contributors`** — compte réseau **non rattaché à une biblio** (s'appuie sur criar-conta sans biblio, déjà livré). Rôle distinct de `{reader, librarian, coordenador}` **et** de `network_administrators`. Droit : **proposer**, jamais éditer directement (ATE-3). *Décision ouverte : table dédiée vs rôle sur le compte réseau existant.*
- **`authority_proposals`** — `id uuid`, `kind` (creation/edition/fusion/traduction), `target_authority_id bigint` (null si création), `payload jsonb` (diff proposé / id doublon→canonique), `status`, `deadline timestamptz`, `proposed_by`, `created_at`. RLS : lecture = parties prenantes (ATE-1) ; écriture = via RPC.
- **`authority_proposal_objections`** — `id uuid`, `proposal_id uuid`, `objecting_library_id uuid`, `objecting_by uuid`, `reason text`, `created_at`. (Symétrie avec `circle_join_objections`.)
- **Autorités `collectivité` et `matière`** — **préalable** (`spec-notice` D7) ; sans elles l'atelier ne travaille que les personnes (`authors`).
- **Réutilisé tel quel** : `merge_author`/`merge_book`/`merge_log` (CAT-H1), `author_translations`/`variant_forms` (CAT-I1).

**RPC (DOC-RPC-3, schéma `api`)** : `fn_authority_propose(kind, target, payload)` · `fn_authority_object(proposal_id, library_id, reason)` · `fn_authority_withdraw(proposal_id)` · `fn_authority_resolve_due()` (cron, idempotent).

---

## 6. Sous-paquet 1b — Événements & notifications

> Le sujet immédiat : la couche *events* du cycle ci-dessus. Elle suit la mécanique `notify-event` existante.

### 6.1 Le « blocage uuid » n'en est pas un
L'EF `notify-event` exige un **`record_id` numérique** (`index.ts` : `Number(payload.record_id)`, rejet si non entier > 0). Ce `record_id` est l'**id `bigint` de la ligne d'outbox**, **pas** l'id de l'entité métier — `painel_internal_task_notification_outbox` apparie déjà un `id bigint` à un `task_id uuid`. Donc une entité **uuid** (proposition) se notifie sans friction via une ligne d'outbox `bigint`. *(Même résolution applicable au 1b cercles, resté non livré pour cette raison mal diagnostiquée.)*

### 6.2 Outbox + handler
- **Table** `authority_proposal_notification_outbox` (`id bigint` PK, `event text`, `payload jsonb`, `status`, `attempts`, `last_error`, `created_at`, `sent_at`) — calquée sur `team_notification_outbox`.
- **Émission** : les RPC `fn_authority_*` insèrent **une ligne par événement** (pattern E.1bis : 1 INSERT, fan-out côté EF), puis appellent `notify-event` avec `record_id = <id outbox bigint>`.
- **Handler** : `handleAuthorityEvent(recordId)` dans `_shared/domain/` + branche `event.startsWith("authority.")` dans `dispatch.ts` ; lit la ligne d'outbox, résout les **destinataires** = biblios utilisatrices (ATE-1) + coordination atelier + proposeur selon l'événement.
- **Réconciliation** : cron sur le modèle `reconcile-task-dispatch` (renvoi des lignes `dispatch_status` en échec).

### 6.3 Catalogue d'événements (proposé)

| Événement | Déclencheur | Destinataires | Anti-panoptique |
|---|---|---|---|
| `authority.proposal_opened` | proposition créée | biblios utilisatrices + coord. atelier | servi aux concerné·es uniquement |
| `authority.proposal_objected` | objection déposée | proposeur + autres biblios utilisatrices | discussion (anti-blackball) |
| `authority.proposal_resolved_consent` | échéance sans objection / consent explicite | proposeur + biblios utilisatrices | — |
| `authority.proposal_refused` | ≥ 2 objections distinctes | proposeur (avec motivation) | — |
| `authority.merge_executed` | fusion appliquée (`merge_author`/`merge_book`) | biblios utilisatrices | lie `merge_log` |
| `authority.edit_applied` | édition/traduction appliquée | biblios utilisatrices (selon impact) | — |

- **i18n** : `mail-strings` 10 locales (DOC-I18N-1), clés plates, langage inclusif (charte).
- **Garde** : `notify-event` reste protégée par `WEBHOOK_SECRET` ; les RPC émetteurs sont SECURITY DEFINER gardés (parties prenantes ATE-1).

---

## 7. Découpage en paquets

1. **Paquet 1 (backend)** — préalables (tables collectivité/matière ; `network_contributors`) + `authority_proposals`/`_objections` + RLS + RPC `fn_authority_*` + cron `resolve_due`. Réutilise CAT-H1 en exécution.
2. **Sous-paquet 1b (events)** — §6 : outbox + handler + branche `dispatch.ts` + mail-strings 10 locales + cron reconcile. **Dépend du paquet 1** (rien à notifier sans entités).
3. **Paquet 2 (frontend)** — Atelier : file de propositions, tableau de bord contributeur·rice, journal des contributions validées ; surface sur la face fédération (renvoi `spec-outils-federalistes`) et/ou la page autorité (`spec-notice` §5.3).

**Ordre** : 1 → 1b → 2. **Bloqueur amont** : ratifier ATE-1..4 (FED-O7) + lever le préalable collectivité/matière (D7).

---

## 8. Invariants

- **INV-A1** — Contribution = **proposition**, jamais écriture directe sur le corpus partagé (ATE-3).
- **INV-A2** — **Consentement sans décompte** : aucune fonctionnalité de vote/quorum (ATE-4, reprend `spec-notice` INV-6).
- **INV-A3** — **Anti-panoptique** (FED-7) : notifications servies aux parties prenantes dérivées des données, aucune vue agrégée du tissu d'usage.
- **INV-A4** — **Audit immuable** : toute application (édition/fusion) tracée (`merge_log` + journal des contributions), cohérent avec les `*_audit` du réseau.
- **INV-A5** — **Pas d'appel tiers au runtime** (`spec-notice` INV-3) : l'atelier ne déclenche aucun appel externe révélant une consultation ; le moissonnage (Wikidata via `authority_lookup`) reste au catalogage.

---

## 9. Décisions ouvertes

- **ATE-O1** — `network_contributors` : table dédiée vs rôle sur le compte réseau existant ? Droits exacts (proposer ; lire le corpus ; voir l'état de ses propositions).
- **ATE-O2** — Longueurs de fenêtre par type (création/édition/traduction courtes ; fusion ≈ 14 j) : valeurs à fixer.
- **ATE-O3** — Préalable collectivité/matière : créer ces tables **dans** ce chantier ou les renvoyer à un paquet structurant amont (`spec-notice` D7) ?
- **ATE-O4** — Réutiliser l'outbox d'une famille existante (générique) vs table dédiée `authority_proposal_notification_outbox` (§6.2).
- **ATE-O5** — Surface du paquet 2 : onglet face fédération, page autorité, ou les deux.

---

## 10. Articulation registre & backlog

- **FED-O7** (registre, ouvert 12/06) : **instruit** par cette spec. Résolu par **ATE-1..4** (§3, validés 12/06) → FED-O7 passe à « 🟢 instruit (renvoi `spec-atelier-autorites`) ». Entrées prêtes à inscrire (ci-dessous, en attente de staging).
- **Série `ATE-*`** : à inscrire au REGISTRE après validation (ATE-1..4 tranchés ; ATE-O1..O5 ouverts).
- **Backlog** : macro-item **#ATELIER** (`spec-notice` §8) — passe de « 🔭 horizon » à « 🟡 cadré (draft) ». Préalable #D7 (collectivité/matière) à porter au prochain GLB.
- **Signal amont** : `R3b`/`R4` (RAPPORTS-REDE) alimentent la file de propositions (détection → proposition de fusion), **n'autorisent rien** par eux-mêmes.

---

**Draft v0.1 (cadrage). Prochaine étape : ratifier ATE-1..4 (FED-O7) et trancher ATE-O1..O5, puis paquet 1 (préalables + propositions/consentement), puis sous-paquet 1b (events, §6), puis paquet 2 (Atelier). Tant que les `ATE-*` ne sont pas au registre, ce fichier reste un draft non normatif.**
