# Spec — Migration de compte lecteur·rice entre bibliothèques

**Statut** : Cadrée le 03/05/2026, en attente d'implémentation
**Cible** : Bologna FICEDL, septembre 2026
**Auteur·rices** : Xavier (spec et arbitrages) + Claude (rédaction)
**Dépendances** : `docs/spec-validation-physique.md` (à implémenter au préalable)

---

## Sommaire

1. [Contexte et objectif](#1-contexte-et-objectif)
2. [Modèle conceptuel](#2-modèle-conceptuel)
3. [Schéma DB](#3-schéma-db)
4. [Cycle de vie d'une demande](#4-cycle-de-vie-dune-demande)
5. [Que se transfère, que ne se transfère pas](#5-que-se-transfère-que-ne-se-transfère-pas)
6. [Workflows](#6-workflows)
7. [Notifications mail](#7-notifications-mail)
8. [Interfaces utilisateur](#8-interfaces-utilisateur)
9. [Cas particuliers](#9-cas-particuliers)
10. [Hors scope (à traiter plus tard)](#10-hors-scope)
11. [Checklist d'implémentation](#11-checklist-dimplémentation)
12. [Tests d'acceptation](#12-tests-dacceptation)

---

## 1. Contexte et objectif

### Contexte

AnarBib applique un principe **un user = une biblio** verrouillé en DB (cf. spec validation physique). Conséquence : pour qu'un·e lecteur·rice change de biblio d'attache, il faut un mécanisme spécifique de **migration**, pas une simple inscription nouvelle (qui perdrait l'historique de lecture, l'identité numérique, et la validation physique).

### Cas d'usage

- **Déménagement géographique** : un·e lecteur·rice quitte sa ville et veut s'attacher à la biblio de sa nouvelle région.
- **Fermeture de biblio** : une biblio cesse son activité, ses lecteur·rices doivent pouvoir migrer ailleurs sans perdre leur compte.
- **Erreur d'inscription** : un·e lecteur·rice s'est inscrit·e à la mauvaise biblio à l'origine.
- **Évolution d'affinités** : un·e lecteur·rice change d'orientation politique/militante et veut rejoindre une autre biblio du réseau.

### Principes directeurs

> 1. **Souveraineté du user** sur ses données personnelles et son historique.
> 2. **Souveraineté des biblios** sur leur politique d'accueil (la biblio cible décide).
> 3. **Souveraineté de la biblio actuelle** sur la résolution des affaires en cours.
> 4. **Transparence et journalisation** des décisions à toutes les étapes.

---

## 2. Modèle conceptuel

### Anatomie d'une migration

Une migration implique **trois acteurs** :
- **Le user** (initiateur potentiel, cible de la migration)
- **La biblio actuelle** (où le user est rattaché aujourd'hui)
- **La biblio cible** (où le user veut être rattaché demain)

### Workflow à deux étages avec résolution intermédiaire

```
                  ┌─────────────────┐
                  │   submitted     │
                  │ (user a demandé)│
                  └────────┬────────┘
                           │
                           ▼
            ┌──────────────────────────────┐
            │ pending_emprunts_resolution  │
            │  (biblio actuelle traite     │
            │   les emprunts en cours)     │
            └──────────────┬───────────────┘
                           │
                           ▼
              ┌────────────────────────┐
              │ pending_source_approval│
              │  (biblio actuelle      │
              │   approuve formellement│)
              └────────────┬───────────┘
                           │
                           ▼
              ┌────────────────────────┐
              │ pending_target_approval│
              │  (biblio cible décide  │
              │  validation préservée  │
              │  ou nouvelle rencontre)│
              └────────────┬───────────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │   completed     │
                  │  (migration     │
                  │   effective)    │
                  └─────────────────┘
```

### États d'échec

À tout moment avant `completed`, la demande peut basculer en :

| État | Déclencheur |
|---|---|
| `cancelled_by_user` | User annule depuis `/conta/migration` |
| `rejected_by_source` | Biblio actuelle refuse (avec raison) |
| `rejected_by_target` | Biblio cible refuse (avec raison) |
| `expired` | Timeout 14 jours sans réponse |

### Identifiants des acteurs

Pour chaque demande, on stocke :
- `user_id` (le lecteur·rice à migrer)
- `source_library_id` (biblio actuelle)
- `target_library_id` (biblio cible)
- `initiated_by_user_id` (qui a soumis : le user lui-même OU un coordenador de la biblio actuelle)
- `initiated_by_role` enum (`reader`, `coordenador`) pour traçabilité

---

## 3. Schéma DB

### Nouvelle table `public.account_migration_requests`

```sql
CREATE TABLE public.account_migration_requests (
  id bigserial PRIMARY KEY,
  
  -- Acteurs
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  source_library_id uuid NOT NULL REFERENCES public.libraries(id) ON DELETE RESTRICT,
  target_library_id uuid NOT NULL REFERENCES public.libraries(id) ON DELETE RESTRICT,
  
  -- État du workflow
  status text NOT NULL DEFAULT 'submitted' CHECK (status IN (
    'submitted',
    'pending_emprunts_resolution',
    'pending_source_approval',
    'pending_target_approval',
    'completed',
    'cancelled_by_user',
    'rejected_by_source',
    'rejected_by_target',
    'expired'
  )),
  
  -- Initiation
  initiated_by_user_id uuid NOT NULL REFERENCES public.profiles(id),
  initiated_by_role text NOT NULL CHECK (initiated_by_role IN ('reader', 'coordenador', 'administrador')),
  initiated_at timestamptz NOT NULL DEFAULT now(),
  
  -- Approbations / refus
  emprunts_resolved_at timestamptz NULL,
  emprunts_resolved_by_user_id uuid NULL REFERENCES public.profiles(id),
  emprunts_resolution_note text NULL,
  
  source_approved_at timestamptz NULL,
  source_approved_by_user_id uuid NULL REFERENCES public.profiles(id),
  source_approval_note text NULL,
  
  target_approved_at timestamptz NULL,
  target_approved_by_user_id uuid NULL REFERENCES public.profiles(id),
  target_approval_note text NULL,
  target_keep_validation boolean NULL,  -- décision de la biblio cible : conserver la validation physique ou pas
  
  -- Refus / annulation
  rejected_at timestamptz NULL,
  rejected_by_user_id uuid NULL REFERENCES public.profiles(id),
  rejection_reason text NULL,
  
  -- Timeouts et rappels
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '14 days'),
  reminder_j7_sent_at timestamptz NULL,
  reminder_j10_sent_at timestamptz NULL,
  
  -- Complétion
  completed_at timestamptz NULL,
  
  -- Métadonnées
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Index pour les requêtes fréquentes
CREATE INDEX idx_amr_user_status ON public.account_migration_requests(user_id, status) 
  WHERE status NOT IN ('completed', 'cancelled_by_user', 'rejected_by_source', 'rejected_by_target', 'expired');
CREATE INDEX idx_amr_source_pending ON public.account_migration_requests(source_library_id, status)
  WHERE status IN ('submitted', 'pending_emprunts_resolution', 'pending_source_approval');
CREATE INDEX idx_amr_target_pending ON public.account_migration_requests(target_library_id, status)
  WHERE status = 'pending_target_approval';
CREATE INDEX idx_amr_expires_at ON public.account_migration_requests(expires_at) 
  WHERE status NOT IN ('completed', 'cancelled_by_user', 'rejected_by_source', 'rejected_by_target', 'expired');

-- Contrainte : une seule migration ouverte à la fois par user
CREATE UNIQUE INDEX uniq_amr_one_open_per_user ON public.account_migration_requests(user_id) 
  WHERE status NOT IN ('completed', 'cancelled_by_user', 'rejected_by_source', 'rejected_by_target', 'expired');

-- Contrainte : pas de migration de soi vers soi
ALTER TABLE public.account_migration_requests 
  ADD CONSTRAINT chk_different_libraries CHECK (source_library_id <> target_library_id);
```

### Nouvelle table `public.account_migration_log`

Journal d'audit complet (toutes transitions, même les annulations) :

```sql
CREATE TABLE public.account_migration_log (
  id bigserial PRIMARY KEY,
  migration_request_id bigint NOT NULL REFERENCES public.account_migration_requests(id) ON DELETE CASCADE,
  event text NOT NULL CHECK (event IN (
    'submitted',
    'emprunts_resolved',
    'source_approved',
    'target_approved',
    'completed',
    'cancelled_by_user',
    'rejected_by_source',
    'rejected_by_target',
    'expired',
    'reminder_sent_j7',
    'reminder_sent_j10'
  )),
  performed_by_user_id uuid NULL REFERENCES public.profiles(id),
  note text NULL,
  performed_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_aml_request ON public.account_migration_log(migration_request_id);
CREATE INDEX idx_aml_performed_at ON public.account_migration_log(performed_at DESC);
```

### Nouvelle table `public.archived_libraries`

Pour conserver la trace des biblios supprimées (cf. décision Q3 paquet 4) :

```sql
CREATE TABLE public.archived_libraries (
  id uuid PRIMARY KEY,  -- même UUID que la biblio supprimée
  slug text NOT NULL,
  name text NOT NULL,
  archived_at timestamptz NOT NULL DEFAULT now(),
  archived_by_user_id uuid NULL REFERENCES public.profiles(id),
  reason text NULL,
  
  -- Snapshot des champs importants au moment de l'archivage
  short_name text NULL,
  city text NULL,
  state text NULL,
  visibility_level text NULL,
  network_access_mode text NULL,
  
  metadata jsonb NULL  -- réserve pour conserver autres champs si besoin
);

CREATE INDEX idx_archived_libraries_slug ON public.archived_libraries(slug);
```

**Quand une biblio est supprimée**, un trigger doit :
1. Insérer une ligne dans `archived_libraries`
2. Mettre à jour les transactions historiques pour pointer vers l'archive (clé étrangère préservée logiquement)

À implémenter via trigger BEFORE DELETE sur `libraries`.

### Modifications mineures aux tables existantes

```sql
-- Ajouter une colonne pour marquer les emprunts/réservations qui ont été clôturés via une migration
ALTER TABLE public.emprestimos_v2 
  ADD COLUMN closed_via_migration_id bigint NULL REFERENCES public.account_migration_requests(id);

ALTER TABLE public.reservas_v2 
  ADD COLUMN closed_via_migration_id bigint NULL REFERENCES public.account_migration_requests(id);
```

Cela permet à la biblio actuelle de savoir, dans son historique, "j'ai clôturé X emprunts à l'occasion de la migration Y du user Z".

### RPC fonctions à créer

```sql
-- Soumission d'une demande
api.submit_migration_request(target_library_id uuid) RETURNS bigint  -- retourne l'ID de la requête

-- Action coordenador biblio actuelle : résoudre les emprunts en cours
api.resolve_migration_emprunts(request_id bigint, decisions jsonb, note text) RETURNS void

-- Action coordenador biblio actuelle : approbation
api.approve_migration_source(request_id bigint, note text) RETURNS void

-- Action coordenador biblio cible : approbation
api.approve_migration_target(request_id bigint, keep_validation boolean, note text) RETURNS void

-- Refus (depuis n'importe quelle partie)
api.reject_migration(request_id bigint, reason text) RETURNS void

-- Annulation par le user
api.cancel_migration_by_user(request_id bigint) RETURNS void

-- Job pg_cron : envoyer les rappels J+7 et J+10, et expirer les demandes après 14j
api.process_migration_timeouts() RETURNS void
```

---

## 4. Cycle de vie d'une demande

### Transitions d'état autorisées

```
submitted
  ├→ pending_emprunts_resolution (action automatique : passer à l'étape suivante)
  ├→ cancelled_by_user
  ├→ rejected_by_source (avec raison)
  └→ expired (après 14j)

pending_emprunts_resolution
  ├→ pending_source_approval (action coordenador biblio actuelle après résolution)
  ├→ cancelled_by_user
  ├→ rejected_by_source (avec raison)
  └→ expired

pending_source_approval
  ├→ pending_target_approval (action coordenador biblio actuelle)
  ├→ cancelled_by_user
  ├→ rejected_by_source (avec raison)
  └→ expired

pending_target_approval
  ├→ completed (action coordenador biblio cible avec décision keep_validation)
  ├→ cancelled_by_user
  ├→ rejected_by_target (avec raison)
  └→ expired

completed, cancelled_by_user, rejected_*, expired
  → Aucune transition (états terminaux)
```

### Timeouts et rappels

Un job `pg_cron` quotidien (`api.process_migration_timeouts()`) parcourt toutes les demandes ouvertes :

- **J+7** depuis `initiated_at` : envoi mail de rappel à la partie qui doit agir actuellement (biblio actuelle ou cible selon état)
- **J+10** : second rappel
- **J+14** : expiration automatique avec mail aux deux parties + au user

Les rappels ne s'accumulent pas : si le user annule au J+8, pas de rappel J+10.

### Acteurs autorisés à chaque transition

| Transition | Qui peut la faire |
|---|---|
| `submitted` (création) | User lui-même, OU coordenador de sa biblio actuelle |
| → `pending_emprunts_resolution` | Automatique (immédiate après submission) |
| → `pending_source_approval` | Coordenador biblio actuelle |
| → `pending_target_approval` | Coordenador biblio actuelle |
| → `completed` | Coordenador biblio cible |
| → `cancelled_by_user` | User uniquement |
| → `rejected_by_source` | Coordenador biblio actuelle (à n'importe quel point avant target_approval) |
| → `rejected_by_target` | Coordenador biblio cible |
| → `expired` | Job automatique |

**Notes** :
- Un `librarian` (rôle inférieur à coordenador) ne peut pas approuver/rejeter une migration. C'est une action engageante qui demande le rôle coordenador.
- L'`administrador` AnarBib peut faire toutes les actions (en cas de blocage, fermeture de biblio, etc.).

---

## 5. Que se transfère, que ne se transfère pas

### Schéma global

| Donnée | Transfert | Pourquoi |
|---|---|---|
| **Identité du user** (nom, email, téléphone, etc.) | Conservé tel quel | C'est la même personne |
| **Mot de passe** (Supabase Auth) | Conservé | C'est la même personne |
| **`physically_validated_at`** | Selon décision biblio cible | Souveraineté de la biblio cible |
| **`is_restricted` (suspension)** | Effacé | Une suspension est locale à la biblio actuelle |
| **`default_library_id`** | Mis à jour vers cible | C'est la migration |
| **`user_library_memberships`** | Désactivé sur source, créé sur target | Cf. ci-dessous |
| **Historique d'emprunts passés** (`emprestimos_v2` clôturés) | Conservé en DB | Mais visible pour le user uniquement |
| **Historique de réservations passées** (`reservas_v2` finies) | Conservé en DB | Mais visible pour le user uniquement |
| **Emprunts en cours** (`emprestimos_v2` actifs) | Résolus à étape 1 | Cf. section 6.2 |
| **Réservations en cours** (`reservas_v2` actives) | Résolus à étape 1 | Idem emprunts |
| **Avis** | Conservés mais marqués "compte migré" pour transparence | Le user a déjà publié |
| **Liste d'envies** (`wishlist`) | Conservée intacte | C'est sa liste personnelle |
| **Statistiques de lecture** | Conservées | Sa propriété |
| **Tags / labels personnels** | Conservés | Sa propriété |

### Cloisonnement de visibilité

L'historique est en DB, mais **la visibilité est filtrée selon l'audience** :

- **Le user sur `/conta`** voit son historique complet, **avec libellés clairs** :
  ```
  Empréstimos
  ├── BLMF (avant migration du 12/03/2026)
  │   ├── 2024-05-12 — "L'État, c'est nous" — Bakounine
  │   └── ...
  └── BTL (depuis migration)
      ├── 2026-04-01 — "Le mutualisme" — Proudhon
      └── ...
  ```
- **Les bibliothécaires de BTL** (biblio actuelle après migration) ne voient que les emprunts BTL — l'historique BLMF est invisible pour eux.
- **Les bibliothécaires de BLMF** (ancienne biblio) ne voient que les emprunts BLMF, et savent que le user "n'est plus à BLMF depuis le 12/03/2026".

Côté technique : les vues admin biblio doivent filtrer `WHERE library_id = current_library_context`, ce qui est sans doute déjà le cas mais à vérifier.

### Ce qui n'est PAS transféré

- `physical_validation_note` : note privée de la biblio actuelle, pas pertinente pour la cible
- Décisions internes de la biblio actuelle (sanctions privées, notes du staff sur le user) : conservées dans la biblio actuelle, invisibles pour la cible
- Lien avec les co-emprunteur·euses, groupes de lecture, etc., spécifiques à la biblio actuelle

---

## 6. Workflows

### 6.1 — Workflow A : Migration initiée par le user (cas standard)

```
1. User va sur /conta, voit "Migrer mon compte vers une autre bibliothèque"
2. Clic → page /conta/migration
3. Dropdown des biblios cibles disponibles (toutes biblios actives sauf source)
4. User sélectionne BTL comme cible
5. Voit un récapitulatif : 
   - "Tu vas demander la migration de BLMF vers BTL"
   - "Si tu as des emprunts en cours à BLMF, BLMF décidera quoi en faire"
   - "BTL devra accepter ta demande"
   - "BTL choisira de conserver ta validation physique ou de te demander une rencontre"
6. User confirme
   → Insertion dans account_migration_requests (status='submitted')
   → Insertion dans account_migration_log (event='submitted')
   → Trigger automatique : status='pending_emprunts_resolution'
   → Mail au user : "Demande de migration soumise"
   → Mail au coordenador de BLMF : "Demande de migration à traiter"
7. (Plus tard) Coordenador BLMF se connecte
8. Voit la demande dans /painel onglet "Migrations en cours" (nouveau)
9. Clique sur la demande
10. Voit la liste des emprunts/réservations en cours du user
11. Pour chaque ligne, choisit : 'Clôturer' / 'Transférer inter-biblio' / 'Annuler' (selon le code domain)
12. Confirme la résolution avec note optionnelle
    → status='pending_source_approval'
    → Insertion dans log
13. Coordenador clique "Approuver la migration"
14. Modal de confirmation avec note optionnelle
15. Confirme
    → status='pending_target_approval'
    → Insertion dans log
    → Mail au user : "BLMF a approuvé"
    → Mail au coordenador BTL : "Demande de migration à examiner"
16. (Plus tard) Coordenador BTL se connecte
17. Voit la demande dans /painel onglet "Migrations entrantes"
18. Clique sur la demande
19. Voit le profil du user (informations transférables)
20. Décide : "Accepter avec validation préservée" / "Accepter avec nouvelle rencontre nécessaire" / "Refuser"
21. Si "accepter" :
    → status='completed'
    → Trigger atomique :
       - profiles.default_library_id := target_library_id
       - user_library_memberships : désactivation source, création target
       - profiles.physically_validated_at : selon target_keep_validation (NULL si nouvelle rencontre demandée, conservé sinon)
       - is_restricted := false (effacement de suspension éventuelle)
       - completed_at := NOW()
    → Insertion dans log
    → Mail au user : "Migration vers BTL effective"
22. Si "refuser" :
    → status='rejected_by_target'
    → Insertion dans log avec raison
    → Mail au user : "Demande refusée par BTL, raison: ..."
    → Mail au coordenador BLMF : "Demande de migration refusée par BTL"
```

### 6.2 — Workflow B : Résolution des emprunts en cours

C'est l'étape la plus critique du processus. Le coordenador de la biblio actuelle a 3 options par ligne d'emprunt/réservation :

**Clôture forcée** : l'emprunt est marqué comme retourné/clôturé en DB. Si le livre n'a pas physiquement été rendu, c'est une perte assumée par la biblio (à journaliser comme telle). Cas typique : user a déménagé, livre perdu mais peu cher, on accepte la perte.

**Transfert inter-biblio** : on conserve l'emprunt actif mais on flag le fait qu'il devra être rendu par voie postale ou via une biblio relais. Ce mécanisme existe peut-être déjà dans AnarBib pour les prêts inter-biblio, à vérifier dans le code (`emprestimos_v2.transfer_*` ?).

**Annulation** : pour les réservations uniquement (pas les emprunts). La réservation est annulée, le user n'aura pas le livre. Mail au user pour l'informer.

L'UI doit présenter cela clairement avec une explication sur chaque choix. La résolution peut se faire en plusieurs sessions (sauvegardable en draft).

### 6.3 — Workflow C : Migration initiée par la biblio actuelle (cas fermeture)

```
1. Coordenador BLMF doit fermer sa biblio (raison : changement de local, fin d'activité, etc.)
2. Va dans /biblioteca onglet "Paramètres généraux"
3. Voit un bouton "Préparer la fermeture de cette bibliothèque"
4. Clic → page dédiée /biblioteca/fermeture
5. Vue : liste de tous les comptes actifs de BLMF avec leurs statuts
6. Pour chaque compte, possibilité de "Détacher en limbo AnarBib"
7. Coordenador peut sélectionner tous → action en lot "Détacher tous"
8. Confirme
   → Pour chaque user :
     * default_library_id := NULL
     * user_library_memberships : désactivation
     * Mail au user : "BLMF est en cours de fermeture, ton compte est en attente de réaffectation"
9. (Plus tard) Le user se connecte
10. Voit un bandeau persistant : "Ta bibliothèque a fermé, choisis une nouvelle bibliothèque pour continuer"
11. Clic → page /conta/migration mode "première inscription"
12. User choisit sa nouvelle biblio
13. Workflow standard à partir de là (mais sans biblio actuelle à approuver, vu qu'elle est en limbo)
```

**Note** : le state "default_library_id IS NULL" doit être géré dans toutes les RLS et le frontend. Le user en limbo voit catalogue public uniquement, aucune action lecteur possible.

### 6.4 — Workflow D : Annulation par le user

```
1. User va sur /conta/migration
2. Voit sa demande en cours avec son statut actuel
3. Clic "Annuler ma demande"
4. Modal de confirmation : "Es-tu sûr·e ? Cette action est irréversible."
5. Confirme
   → status='cancelled_by_user'
   → Mail au coordenador BLMF (si la demande était en pending_*) : "User a annulé sa migration"
   → Mail au coordenador BTL (si la demande était en pending_target_approval) : idem
   → Insertion dans log
6. User peut soumettre une nouvelle demande immédiatement si souhaité
```

### 6.5 — Workflow E : Refus par une biblio

Identique au workflow A jusqu'à l'étape de refus :

```
- Coordenador clique "Refuser"
- Modal avec champ raison OBLIGATOIRE
- Confirme
   → status='rejected_by_source' (ou _by_target selon l'étape)
   → Mail au user avec raison transmise
   → Mail à l'autre biblio si déjà impliquée
- User peut soumettre une nouvelle demande (vers la même ou une autre biblio) sans carence (cf. décision Q2 paquet 4)
```

---

## 7. Notifications mail

### Templates à ajouter à `mail-strings.ts`

À ajouter aux 100 clés existantes après les 16 clés de la spec validation physique. Soit ~30 nouvelles clés × 6 locales = **~180 traductions militantes**.

### Liste des clés

```
# Mails au user
migration.submitted.sub                  → "Ta demande de migration est soumise"
migration.submitted.body                 → Récap de la demande, lien vers /conta/migration
migration.empruntos_resolved.sub         → "Tes emprunts à BLMF ont été traités"
migration.empruntos_resolved.body        → Détail de la résolution
migration.source_approved.sub            → "BLMF a approuvé ta migration"
migration.source_approved.body           → Étape suivante : attente BTL
migration.target_approved.sub            → "Tu es maintenant rattaché·e à BTL"
migration.target_approved.body           → Récap final + indication si validation physique requise
migration.rejected_by_source.sub         → "Ta demande de migration a été refusée par BLMF"
migration.rejected_by_source.body        → Raison transmise
migration.rejected_by_target.sub         → "Ta demande de migration a été refusée par BTL"
migration.rejected_by_target.body        → Raison transmise
migration.expired.sub                    → "Ta demande de migration a expiré"
migration.expired.body                   → Pas de réponse, possibilité de refaire une demande
migration.cancelled_by_user.sub          → "Ta migration a été annulée"
migration.cancelled_by_user.body         → Confirmation simple

# Mails à la biblio actuelle (source)
migration.source.request_received.sub    → "Demande de migration à traiter"
migration.source.request_received.body   → Détails du user et de la cible
migration.source.user_cancelled.sub      → "Le·la lecteur·rice a annulé sa migration"
migration.source.user_cancelled.body     → Annulation, pas d'action requise
migration.source.target_rejected.sub     → "BTL a refusé la migration de votre lecteur·rice"
migration.source.target_rejected.body    → Information seulement, raison transmise

# Mails à la biblio cible (target)
migration.target.request_received.sub    → "Demande de migration à examiner"
migration.target.request_received.body   → Détails du user, lien vers fiche d'examen
migration.target.user_cancelled.sub      → "Le·la lecteur·rice a annulé sa migration"
migration.target.user_cancelled.body     → Annulation, pas d'action requise

# Rappels (envoyés à la partie qui doit agir)
migration.reminder_j7.sub                → "Rappel : demande de migration en attente depuis 7 jours"
migration.reminder_j7.body               → Lien vers la fiche, mention du timeout
migration.reminder_j10.sub               → "Dernier rappel : demande de migration expire dans 4 jours"
migration.reminder_j10.body              → Plus pressant
```

### Conventions militantes

À appliquer dans toutes les traductions :
- **fr** : tutoiement, point médian
- **es** : neutre argentin (juntes, lector(a/e), participes accordés conectade)
- **pt-BR** : triple o/a/e, contractions d(o/a/e)
- **it** : compagno/a/e, **JAMAIS** camerata
- **de** : Genoss*in / Genoss*innen avec Genderstern, **JAMAIS** Compas
- **en** : épicène quand possible

---

## 8. Interfaces utilisateur

### 8.1 — Page `/conta/migration` (côté user)

**Visible** : pour le user lui-même, à tout moment.

**Mode "pas de migration en cours"** :
```
┌─ Migrer mon compte ──────────────────────────────────┐
│                                                      │
│ Si tu déménages ou veux changer de bibliothèque      │
│ d'attache, tu peux demander une migration.           │
│                                                      │
│ Ta nouvelle bibliothèque devra accepter ta demande.  │
│ Tes emprunts en cours à BLMF devront être traités.   │
│                                                      │
│ Bibliothèque cible :                                 │
│ ┌──────────────────────────────────────────────────┐ │
│ │ ▾ Choisir une bibliothèque                       │ │
│ └──────────────────────────────────────────────────┘ │
│                                                      │
│ [ Soumettre la demande ]                             │
└──────────────────────────────────────────────────────┘
```

**Mode "migration en cours"** :
```
┌─ Ma demande de migration ────────────────────────────┐
│                                                      │
│ De : BLMF                                            │
│ Vers : BTL                                           │
│                                                      │
│ Statut : ⏳ En attente d'approbation par BTL         │
│                                                      │
│ Étapes :                                             │
│ ✅ Soumise le 12/03/2026                            │
│ ✅ Emprunts traités par BLMF                         │
│ ✅ Approuvée par BLMF le 14/03/2026                 │
│ ⏳ En attente d'approbation par BTL                  │
│ ⌛ Expire le 26/03/2026 (J-12)                      │
│                                                      │
│ [ Annuler ma demande ]                               │
└──────────────────────────────────────────────────────┘
```

**Mode "migration refusée"** :
```
┌─ Ma demande de migration (refusée) ──────────────────┐
│                                                      │
│ De : BLMF                                            │
│ Vers : BTL                                           │
│                                                      │
│ Statut : ❌ Refusée par BTL le 16/03/2026           │
│                                                      │
│ Raison transmise :                                   │
│ ┌──────────────────────────────────────────────────┐ │
│ │ Notre bibliothèque a actuellement une longue     │ │
│ │ liste d'attente. Nous t'invitons à recontacter   │ │
│ │ d'ici 6 mois.                                    │ │
│ └──────────────────────────────────────────────────┘ │
│                                                      │
│ Tu peux soumettre une nouvelle demande               │
│ immédiatement (vers la même ou une autre biblio).    │
│                                                      │
│ [ Soumettre une nouvelle demande ]                  │
└──────────────────────────────────────────────────────┘
```

### 8.2 — Onglet `/painel` "Migrations en cours" (côté coordenador)

Liste des demandes de migration où la biblio est impliquée :
- Migrations sortantes (à traiter par cette biblio en tant que source)
- Migrations entrantes (à examiner en tant que cible)

Chaque ligne : user, biblio source/cible, état actuel, date soumission, date expiration, action attendue.

Filtres : "À traiter" / "En attente de l'autre biblio" / "Récentes" / "Toutes".

### 8.3 — Page de résolution emprunts (côté coordenador biblio actuelle)

Quand le coordenador clique sur une demande au statut `pending_emprunts_resolution`, il accède à un écran dédié :

```
Migration de [user] vers [BTL]

Emprunts en cours à BLMF (3) :
┌──────────────────────────────────────────────────────┐
│ 📚 "L'État, c'est nous" — Bakounine                  │
│ Échéance : 2026-04-15                                │
│ ○ Clôturer (le livre est perdu)                      │
│ ○ Transférer inter-biblio                            │
│ ⊙ (à choisir)                                        │
└──────────────────────────────────────────────────────┘
[ ... 2 autres emprunts ... ]

Réservations en cours à BLMF (1) :
┌──────────────────────────────────────────────────────┐
│ 📚 "Le mutualisme" — Proudhon                        │
│ Statut : pronta_para_retirada                        │
│ ○ Annuler la réservation                             │
│ ○ Maintenir (le user viendra la chercher)            │
└──────────────────────────────────────────────────────┘

Note de résolution (optionnel) :
[ Champ libre ]

[ Sauvegarder en brouillon ] [ Confirmer toutes les résolutions ]
```

### 8.4 — Page d'examen (côté coordenador biblio cible)

```
Demande de migration de [user]

Profil du user :
- Nom : Xavier Van Welden
- Email : xavier@example.com
- Inscription initiale : 2024-05-12 à BLMF
- Validation physique actuelle : ✅ validé (par BLMF, 2024-05-15)
- Historique BLMF : 47 emprunts, 12 réservations

[!] Note : tu ne vois que ce qui est légitimement transférable.
    L'historique détaillé reste privé au user.

Décision :
○ Accepter et conserver la validation physique
  (faire confiance à BLMF, accès immédiat au catalogue)

○ Accepter mais demander une nouvelle rencontre physique
  (le user devra venir à BTL pour valider à nouveau)

○ Refuser cette demande de migration
  (raison obligatoire)

[ Annuler ] [ Confirmer ma décision ]
```

---

## 9. Cas particuliers

### 9.1 — Migration vers une biblio cible qui ferme pendant le processus

Si la biblio cible passe en `is_active=false` pendant qu'une demande est en attente :
- La demande passe automatiquement en `rejected_by_target` avec raison "Bibliothèque cible inactive"
- Mail au user
- User peut refaire une demande vers une autre biblio

### 9.2 — Suspension du user pendant une migration en cours

Si la biblio actuelle suspend le user (`is_restricted=true`) pendant que la migration est en cours, la migration peut continuer. La suspension est levée à la complétion (cf. décision Q3 paquet 1 : suspension orthogonale, mais effacée à migration completed).

### 9.3 — Le user est coordenador/librarian de sa biblio actuelle

Cas où une personne ayant un rôle staff veut migrer vers une autre biblio :
- Le rôle staff est **systématiquement révoqué** lors de la migration (le user devient `reader` à la cible par défaut)
- La biblio cible peut le re-promouvoir séparément si elle le souhaite
- Si le user est le seul coordenador de sa biblio actuelle, la migration est **bloquée** tant qu'un autre coordenador n'a pas été nommé (sinon la biblio se retrouve sans coordination)

### 9.4 — Migration en cas de mort de l'administrador AnarBib

Cas extrême mais à mentionner pour gouvernance future :
- Si toi (administrador unique) deviens indisponible, l'admin AnarBib passe à... ?
- Ce point dépasse cette spec, mais à anticiper dans une future "spec gouvernance"

### 9.5 — Demande de migration pour un user inactif depuis longtemps

Pas de blocage technique. Si un user dort depuis 5 ans, il peut quand même migrer. La biblio cible a la souveraineté de refuser si elle estime que c'est suspect.

### 9.6 — Suppression de compte pendant une migration en cours

Si le user supprime son compte (via /conta) alors qu'une migration est en cours :
- La migration passe en `cancelled_by_user`
- Le compte est anonymisé (cf. Q3 paquet 5)
- Les logs migration restent, mais le `user_id` pointe vers un compte anonymisé

---

## 10. Hors scope

À traiter dans des specs séparées (post-Bologna éventuellement) :

- **Suppression définitive de compte (RGPD)** : décision Q3 paquet 5 notée (anonymisation graduelle), mais workflow complet à spec.
- **Gouvernance AnarBib** : transfert du rôle administrador unique, coopération multi-admins.
- **Migration entre AnarBib et autres SIGB** : export/import vers Koha, etc.
- **Notifications dans le header** : cloche en haut à droite qui agrège les événements (validation, migration, etc.)
- **Rapport d'activité du user** : page récapitulative consultable et exportable de l'activité d'un user (RGPD : droit à la portabilité).

---

## 11. Checklist d'implémentation

### Phase 1 — Schéma DB (3-4h)

- [ ] Migration SQL `2026_05_XX_account_migration_schema.sql`
  - [ ] CREATE TABLE account_migration_requests
  - [ ] CREATE TABLE account_migration_log
  - [ ] CREATE TABLE archived_libraries
  - [ ] ALTER TABLE emprestimos_v2 ADD closed_via_migration_id
  - [ ] ALTER TABLE reservas_v2 ADD closed_via_migration_id
  - [ ] Trigger BEFORE DELETE on libraries → archive
- [ ] Tests SQL : insertions de test, transitions de status

### Phase 2 — Helpers RLS et RPC (4-6h)

- [ ] RLS sur account_migration_requests
  - [ ] User voit ses propres demandes
  - [ ] Coordenador biblio source voit les demandes la concernant
  - [ ] Coordenador biblio target voit les demandes la concernant
  - [ ] Administrador voit tout
- [ ] RPC `api.submit_migration_request(target_library_id)`
- [ ] RPC `api.resolve_migration_emprunts(request_id, decisions, note)`
- [ ] RPC `api.approve_migration_source(request_id, note)`
- [ ] RPC `api.approve_migration_target(request_id, keep_validation, note)`
- [ ] RPC `api.reject_migration(request_id, reason)`
- [ ] RPC `api.cancel_migration_by_user(request_id)`
- [ ] RPC `api.detach_user_to_limbo(user_id)` (pour fermeture biblio)
- [ ] Tests RPC : appels en SQL + vérification logs

### Phase 3 — Job pg_cron timeouts (1h)

- [ ] Fonction `api.process_migration_timeouts()`
  - [ ] Sélectionne les demandes ouvertes
  - [ ] Pour chaque, vérifie si J+7, J+10 ou expiration
  - [ ] Envoie mails appropriés via notify-event
  - [ ] Met à jour status si expiration
- [ ] Schedule pg_cron quotidien (1x par jour à 4h00 UTC)

### Phase 4 — Frontend (1-2 jours, ~10-16h)

- [ ] Page `/conta/migration` (3 modes selon état)
- [ ] Composant suivi statut / timeline
- [ ] Onglet `/painel` "Migrations en cours" (sortantes + entrantes)
- [ ] Page de résolution emprunts
- [ ] Page d'examen côté biblio cible
- [ ] Workflow fermeture biblio (`/biblioteca/fermeture`)
- [ ] Bandeau persistent pour user en limbo
- [ ] Routing/guards pour les nouveaux états

### Phase 5 — Backend Edge Functions (2-3h)

- [ ] Mise à jour de `notify-event` pour nouveaux events :
  - migration_submitted, migration_emprunts_resolved
  - migration_source_approved, migration_target_approved (= completed)
  - migration_rejected_by_source, migration_rejected_by_target
  - migration_cancelled_by_user, migration_expired
  - migration_reminder_j7, migration_reminder_j10
- [ ] Tests Deno

### Phase 6 — Mails i18n (5-7h)

- [ ] Ajouter ~30 nouvelles clés dans `mail-strings.ts`
- [ ] Traductions militantes dans les 6 locales (~180 traductions)
- [ ] Tests mail-strings.test.ts mis à jour
- [ ] Déploiement notify-event

### Phase 7 — Tests d'acceptation (cf. section 12)

**Estimation totale : 4-6 jours de travail effectif** (étalés sur 2-3 semaines).

---

## 12. Tests d'acceptation

### Tests fonctionnels

- [ ] **T1** : User initie migration, biblio actuelle traite emprunts, approuve, biblio cible accepte avec validation préservée → user voit accès complet immédiatement
- [ ] **T2** : Idem mais biblio cible demande nouvelle rencontre → user en attente après migration
- [ ] **T3** : User annule sa demande à n'importe quel point avant completed → annulation propre, mails envoyés
- [ ] **T4** : Biblio actuelle refuse → user reçoit raison, peut refaire une demande
- [ ] **T5** : Biblio cible refuse → idem
- [ ] **T6** : Demande timeout après 14j sans réponse → statut expired, mails aux 3 parties
- [ ] **T7** : Coordenador BLMF lance fermeture, détache 50 comptes en lot → tous en limbo, mails envoyés
- [ ] **T8** : User en limbo se connecte, fait sa propre demande de migration → workflow standard sans approbation source

### Tests sécurité / RLS

- [ ] **S1** : User A ne peut PAS voir les demandes de migration du user B
- [ ] **S2** : Coordenador BLMF voit seulement les migrations où BLMF est impliquée
- [ ] **S3** : Un librarian ne peut PAS approuver/rejeter une migration (seuls coordenador+ peuvent)
- [ ] **S4** : User ne peut PAS soumettre 2 demandes simultanées (contrainte UNIQUE)
- [ ] **S5** : User ne peut PAS migrer vers la même biblio que sa source (contrainte CHECK)

### Tests UI / UX

- [ ] **U1** : Page /conta/migration affiche le bon état dans tous les cas
- [ ] **U2** : Timeline visuelle correcte avec étapes complétées/en cours
- [ ] **U3** : Messages d'erreur explicites (timeout, conflit, etc.)
- [ ] **U4** : Tous les boutons "Valider physiquement" → mails contextuels selon décision

### Tests audit

- [ ] **L1** : Toute transition est journalisée dans account_migration_log
- [ ] **L2** : Le log conserve performed_by_user_id
- [ ] **L3** : SELECT * FROM account_migration_log WHERE migration_request_id=X montre l'historique complet

### Tests de cas extrêmes

- [ ] **E1** : Biblio cible passe en is_active=false pendant migration en cours → auto-rejet
- [ ] **E2** : User est seul coordenador de sa biblio → migration bloquée
- [ ] **E3** : Suppression de compte pendant migration → cancelled_by_user

---

## Annexes

### A — Glossaire

- **Migration** : action de transférer un compte lecteur·rice d'une biblio à une autre, sans recréer le compte ni perdre l'historique.
- **Limbo** : état temporaire d'un compte sans biblio rattachée (`default_library_id IS NULL`), suite à la fermeture de la biblio actuelle.
- **Résolution des emprunts en cours** : action de la biblio actuelle pour traiter les emprunts/réservations actifs du user au moment de la migration (clôture forcée, transfert inter-biblio, ou annulation).
- **Validation préservée** : décision de la biblio cible de conserver la validation physique du user lors de l'acceptation, plutôt que de demander une nouvelle rencontre.

### B — Récap des décisions

| Question | Décision |
|---|---|
| Initiateur | User OU coordenador biblio actuelle |
| Validation | Les deux biblios doivent valider |
| Limites fréquence | Pas de limite, journal d'audit |
| Historique transfert | Cloisonné : visible user, non visible cross-biblio |
| Emprunts en cours | Workflow dédié biblio actuelle |
| Validation physique au transfert | Décision biblio cible |
| États workflow | submitted → emprunts → source → target → completed |
| Timeout | 14 jours avec rappels J+7, J+10 |
| Annulation user | Possible jusqu'à completed |
| Fermeture biblio | Migration en lot vers limbo AnarBib |
| Refus | Pas de carence, notification au user |
| Suppression biblio | Table d'archive `archived_libraries` |
| Mails | Contextuels par acteur |
| Suivi user | Page dédiée `/conta/migration` |
| Suppression compte | Anonymisation graduelle (RGPD) |

### C — Décisions à prendre lors de l'implémentation

- [ ] Faut-il un workflow de transfert inter-biblio préexistant pour les emprunts en cours ? Si oui, le réutiliser.
- [ ] Le coordenador qui se migre lui-même : workflow particulier ou interdiction ?
- [ ] Notifications de rappel : peut-on les configurer (J+7/J+10) par biblio ?
- [ ] Page `/conta/migration` accessible aussi pour visualiser les migrations passées (historique du compte) ?

---

**Spec close. Prochaine étape : implémentation.**
