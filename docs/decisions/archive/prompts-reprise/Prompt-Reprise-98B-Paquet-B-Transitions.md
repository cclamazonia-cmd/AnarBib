# Prompt de reprise — Chantier #98-B Profils d'adoption / Paquet B Transitions

**Date de rédaction :** 17 mai 2026 (fin de session)
**Pour reprise par :** Xavier (via Claude, prochaine session dédiée)
**Statut prérequis :** Paquet A profils livré en prod ✅ (migration `20260515170000_paquet_A_profils_infrastructure.sql`)
**Spec de référence :** `docs/specs/spec-profils-bibliotheque.md` v0.3 §9.2
**Estimation :** 3 jours (révisé v0.3 : tables proposals/votes alourdissent le paquet)

---

## 1. Cadrage politique

### 1.1 Pourquoi ce chantier maintenant

Le paquet A a déposé l'infrastructure DB dormante : les 4 colonnes `*_mode` sont sur `libraries`, les 2 contraintes CHECK croisées sont actives, les 11 helpers (`fn_library_*_mode` ×4 + 6 prédicats + `fn_library_has_staff_roles`) sont disponibles, la table `library_profile_history` est immuable. Les 2 biblios en prod (BLMF, BTL) sont en profil D par défaut. Rien ne change fonctionnellement.

Le paquet B active la **réversibilité encadrée** (principe P3 de la spec §2.1) : possibilité de passer d'un profil à un autre, avec la doctrine politique appropriée selon le type de transition (élargissement immédiat, rétractation avec carence, transition critique avec vote, etc.). Sans paquet B, les profils sont figés à l'inscription.

Le paquet B est **prérequis du paquet D** (archivage), qui est lui-même appelé par les transitions de type 4. Donc B doit précéder D.

### 1.2 Doctrines à respecter

Ces doctrines, internalisées au cours des derniers chantiers (#141, #142, #143), s'appliquent intégralement au paquet B :

1. **Doctrine création objets sécurisés** (`docs/decisions/CHANTIER_doctrine_creation_objets_securises_2026-05-12.md`) : toute nouvelle fonction est `SECURITY DEFINER` + `REVOKE EXECUTE FROM PUBLIC` + `GRANT EXECUTE TO authenticated` + `SET search_path = public`. Toute nouvelle table inclut RLS + GRANT explicites. Toute nouvelle vue est `security_invoker = on`. Le pre-commit hook `.githooks/pre-commit` enforce automatiquement. DO-block de vérification en fin de migration.

2. **Doctrine #141.2.E ordre UPDATE narrative-avant-état** : quand une RPC modifie plusieurs tables liées par triggers AFTER UPDATE, toujours UPDATE la source de vérité narrative AVANT la source d'état déclenchante. Ici : INSERT dans `library_profile_history` (narrative) AVANT UPDATE de la colonne `*_mode` (état) si la colonne déclenche un trigger.

3. **Doctrine R8 traçabilité coordination** (chantier #142) : toute action initiée par le staff biblio sur un item collectif génère un mail à la coordination (en plus du mail principal). À appliquer aux 6 events `team.profile_change_*`.

4. **Doctrine notes duales** (#141.2.C) : si une note staff est saisie (motivation, rationale_against, etc.), elle doit être propagée au payload event et affichée dans le mail.

5. **Doctrine immutabilité audit** : `library_profile_proposals`, `library_profile_votes`, `library_profile_grace_locks` sont des tables d'audit. Triggers BEFORE UPDATE/DELETE qui RAISE EXCEPTION (sur le modèle de `fn_block_lph_modification` du paquet A).

6. **Doctrine UTF-8 PowerShell** (étendue 17/05) : sur Windows FR, `Get-Content -Raw` peut corrompre les fichiers UTF-8 ; `Get-Content` peut afficher de faux mojibakes. Utiliser `[System.IO.File]::ReadAllText($path, [System.Text.UTF8Encoding]::new($false))` ou scripts Node `.cjs`.

### 1.3 Principe directeur du paquet B

**Aucune transition silencieuse.** Toute modification d'un `*_mode` passe par `fn_propose_library_profile_change` puis `fn_execute_library_profile_change`. Modification directe interdite (à enforcer via une RLS sur les colonnes ou via le trigger `library_profile_history`).

---

## 2. État de l'art après paquet A

### 2.1 Objets DB déjà disponibles

Colonnes sur `public.libraries` :
- `catalog_mode text NOT NULL DEFAULT 'network_published'` ∈ {local_only, network_published}
- `circulation_mode text NOT NULL DEFAULT 'full_sigb'` ∈ {off, informal, full_sigb}
- `network_mode text NOT NULL DEFAULT 'federated'` ∈ {isolated, observer, federated}
- `governance_mode text NOT NULL DEFAULT 'full_governance'` ∈ {informal, staff_roles, full_governance}

Contraintes CHECK croisées :
- `chk_catalog_published_requires_network` : `catalog_mode <> 'network_published' OR network_mode IN ('observer', 'federated')`
- `chk_full_sigb_requires_roles` : `circulation_mode <> 'full_sigb' OR governance_mode IN ('staff_roles', 'full_governance')`

Table `public.library_profile_history` (audit immutable, anti-UPDATE/DELETE via `fn_block_lph_modification`) :
- Colonnes : id, library_id, axis, old_value, new_value, changed_by, changed_at, motivation
- Indexes : `(library_id, changed_at DESC)`, `(axis)`

Helpers SQL (11) — tous `STABLE SECURITY DEFINER`, GRANT à `anon` + `authenticated` :
- Lecteurs (4) : `fn_library_catalog_mode`, `fn_library_circulation_mode`, `fn_library_network_mode`, `fn_library_governance_mode`
- Prédicats (6) : `fn_library_has_circulation`, `fn_library_has_full_sigb`, `fn_library_publishes_catalog`, `fn_library_is_federated`, `fn_library_uses_governance`, `fn_library_has_staff_roles`

Colonnes `requested_*_mode` + `profile_template_chosen` sur `library_requests` (sans CHECK, validation à l'acceptation).

### 2.2 Vérifications à exécuter en début de session

```sql
-- Vérifier que le paquet A est bien en prod sur cette branche
SELECT column_name FROM information_schema.columns 
WHERE table_schema = 'public' AND table_name = 'libraries' 
  AND column_name IN ('catalog_mode', 'circulation_mode', 'network_mode', 'governance_mode')
ORDER BY column_name;
-- Doit retourner les 4 lignes
```

```sql
-- Vérifier les 11 helpers
SELECT proname FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND proname LIKE 'fn_library_%'
ORDER BY proname;
-- Doit retourner les 11 helpers
```

```sql
-- État actuel des biblios en prod
SELECT id, slug, catalog_mode, circulation_mode, network_mode, governance_mode 
FROM public.libraries 
ORDER BY created_at;
-- BLMF et BTL doivent être en profil D : (network_published, full_sigb, federated, full_governance)
```

---

## 3. Périmètre du paquet B

D'après spec §9.2, le paquet B livre :

1. **2 tables symétriques D.6** pour les propositions/votes en `full_governance`
2. **3 RPC principales** (`fn_propose_library_profile_change`, `fn_vote_library_profile_change`, `fn_revoke_library_profile_transition`)
3. **1 RPC interne** (`fn_execute_library_profile_change`)
4. **2 helpers** (`fn_classify_transition`, `fn_required_governance_for_transition`)
5. **2 jobs pg_cron** (`process_profile_transition_grace` horaire, `expire_profile_proposals` quotidien)
6. **1 table** `library_profile_grace_locks` pour matérialiser le gel pendant carence
7. **6 events** `team.profile_change_*` dans handler `notify-event` + i18n × 6 locales

### 3.1 Tables à créer

**`public.library_profile_proposals`** (similaire à `network_administrator_cooptation_proposals`) :

```sql
CREATE TABLE public.library_profile_proposals (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  library_id          uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,
  axis                text NOT NULL CHECK (axis IN ('catalog_mode', 'circulation_mode', 'network_mode', 'governance_mode')),
  old_value           text NOT NULL,
  new_value           text NOT NULL CHECK (old_value <> new_value),
  transition_type     int NOT NULL CHECK (transition_type IN (1, 2, 3, 4)),
  governance_required text NOT NULL CHECK (governance_required IN ('direct', 'majority', 'unanimous', 'unanimous_extended')),
  motivation          text NOT NULL CHECK (length(motivation) >= 5),
  proposed_by         uuid NOT NULL REFERENCES auth.users(id),
  proposed_at         timestamptz NOT NULL DEFAULT now(),
  status              text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'accepted_unanimous', 'accepted_majority', 'rejected', 'expired', 'cancelled', 'completed')),
  unanimous_at        timestamptz,
  majority_at         timestamptz,
  expires_at          timestamptz NOT NULL,            -- proposed_at + interval '30 days'
  grace_period_until  timestamptz,                     -- mis quand status = accepted_*
  completed_at        timestamptz,                     -- mis par fn_execute_library_profile_change
  cancelled_at        timestamptz,
  cancelled_by        uuid REFERENCES auth.users(id),
  cancelled_motivation text,
  CONSTRAINT chk_status_dates CHECK (
    (status IN ('open') AND completed_at IS NULL) OR
    (status IN ('expired', 'cancelled') AND completed_at IS NULL) OR
    (status = 'completed' AND completed_at IS NOT NULL)
  )
);
```

Indexes : `(library_id, status)`, `(status, expires_at)` pour le job d'expiration, `(status, grace_period_until)` pour le job de carence.

RLS : SELECT pour le staff de la biblio + admins réseau. INSERT/UPDATE bloqués (via fn_block_*) — passage obligatoire par les RPC.

**`public.library_profile_votes`** (symétrique à `network_administrator_cooptation_votes`) :

```sql
CREATE TABLE public.library_profile_votes (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  proposal_id         uuid NOT NULL REFERENCES public.library_profile_proposals(id) ON DELETE CASCADE,
  voter_id            uuid NOT NULL REFERENCES auth.users(id),
  vote                text NOT NULL CHECK (vote IN ('for', 'against')),
  voted_at            timestamptz NOT NULL DEFAULT now(),
  rationale_against   text CHECK (rationale_against IS NULL OR length(rationale_against) >= 20),
  CONSTRAINT chk_one_vote_per_voter UNIQUE (proposal_id, voter_id),
  CONSTRAINT chk_rationale_required_against CHECK (
    vote = 'for' OR (vote = 'against' AND rationale_against IS NOT NULL)
  )
);
```

Indexes : `(proposal_id)`, `(voter_id)`.

**`public.library_profile_grace_locks`** (matérialise le gel §4.6) :

```sql
CREATE TABLE public.library_profile_grace_locks (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  library_id      uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,
  proposal_id     uuid NOT NULL REFERENCES public.library_profile_proposals(id) ON DELETE CASCADE,
  affected_axis   text NOT NULL,
  affected_jobs   text[] NOT NULL,         -- ex. ARRAY['emprestimo_reminders', 'expire_reservations']
  locked_at       timestamptz NOT NULL DEFAULT now(),
  grace_until     timestamptz NOT NULL,
  released_at     timestamptz              -- NULL si lock encore actif
);
```

Index : `(library_id, grace_until) WHERE released_at IS NULL` pour requêtes rapides côté jobs.

### 3.2 Helpers à créer (avant les RPC)

**`fn_classify_transition(p_axis text, p_old text, p_new text) RETURNS int`**

Retourne 1, 2, 3 ou 4 selon la matrice §4.2 de la spec :
- 1 = élargissement (immédiat, pas de carence) : ex. `network_mode: isolated → observer`
- 2 = élargissement nécessitant validation simple : ex. `governance_mode: informal → staff_roles`
- 3 = rétractation douce (carence 24h) : ex. `catalog_mode: network_published → local_only`
- 4 = transition critique (carence 48h ou 7j + archivage potentiel) : ex. `circulation_mode: full_sigb → off`

**`fn_required_governance_for_transition(p_library_id uuid, p_axis text, p_new_value text) RETURNS text`**

Retourne `'direct'` / `'majority'` / `'unanimous'` / `'unanimous_extended'` selon :
- combo (governance_mode actuel, transition_type)
- cas particulier `staff_roles → informal` → `unanimous_extended` (admins + coords, carence 7j)
- Sinon : voir matrice §4.5

### 3.3 RPC à créer

**`fn_propose_library_profile_change(p_library_id uuid, p_axis text, p_new_value text, p_motivation text) RETURNS uuid`**

Logique :
1. Vérif RLS : caller est admin/coord de la biblio (selon `governance_mode`) — sinon RAISE
2. Lire `old_value` via le helper approprié
3. Vérifier `old_value <> p_new_value`
4. Vérifier que la nouvelle valeur respecte les CHECK croisés (chk_catalog_published_requires_network, chk_full_sigb_requires_roles) — sinon RAISE explicite
5. Vérifier qu'il n'y a pas déjà une proposition `open` sur le même axe pour cette biblio — sinon RAISE
6. Vérifier qu'il n'y a pas une transition incompatible en cours (ex. cooptation ouverte alors qu'on veut passer `full_governance → staff_roles`)
7. Classifier la transition via `fn_classify_transition`
8. Déterminer la gouvernance requise via `fn_required_governance_for_transition`
9. Si `governance_required = 'direct'` : appeler directement `fn_execute_library_profile_change` (pas de proposal créé) — retour `NULL`
10. Sinon : INSERT dans `library_profile_proposals` avec status=`open`, expires_at = now() + 30 days
11. Si transition_type IN (3, 4) : INSERT dans `library_profile_grace_locks` avec grace_until = unanimous_at + carence (24h ou 48h ou 7j selon type)
12. Notify : INSERT outbox event `team.profile_change.proposed`
13. Retour : `proposal_id` (ou NULL si direct)

Doctrine R8 : le mail est envoyé au proposer (accusé) + à tous les admins/coords concernés (action attendue) + à `library_commons.coordination_email` (traçabilité).

**`fn_vote_library_profile_change(p_proposal_id uuid, p_vote text, p_rationale_against text DEFAULT NULL) RETURNS jsonb`**

Logique :
1. Vérif : proposition existe, status = `'open'`
2. Vérif : caller est admin/coord (selon `governance_required`)
3. Vérif : caller n'a pas déjà voté
4. Si `vote = 'against'` et `p_rationale_against IS NULL OR length < 20` : RAISE
5. INSERT dans `library_profile_votes`
6. Recompter les votes
7. Si vote `'against'` ET governance_required IN ('unanimous', 'unanimous_extended') → proposition échoue → UPDATE status = `'rejected'`
8. Si tous les électeurs ont voté `'for'` (selon le quorum) → UPDATE status = `'accepted_unanimous'` ou `'accepted_majority'`, `unanimous_at = now()`, `grace_period_until = now() + carence`
9. Notify : `team.profile_change.voted_for` ou `voted_against` ou `accepted_unanimous`

Doctrine 141.2.E : INSERT vote AVANT UPDATE status (la note narrative arrive avant l'état).

Doctrine proposeur (chantier #114) : le proposer reçoit notification UNIQUEMENT au 1er vote (signal démarrage), puis silencieux jusqu'au résultat.

Retour jsonb : `{vote_count_for, vote_count_against, votes_required, new_status, grace_period_until}`.

**`fn_revoke_library_profile_transition(p_proposal_id uuid, p_motivation text) RETURNS void`**

Logique :
1. Vérif : proposition existe, status IN (`'open'`, `'accepted_unanimous'`, `'accepted_majority'`)
2. Vérif : caller est admin de la biblio
3. Vérif : si status = `'accepted_*'`, on est encore avant `grace_period_until` (sinon trop tard, la transition est déjà entrée dans son cycle d'exécution)
4. UPDATE status = `'cancelled'`, cancelled_at = now(), cancelled_by, cancelled_motivation
5. Si lock actif dans `library_profile_grace_locks` : UPDATE released_at = now()
6. Notify : `team.profile_change.cancelled_by_admin`

**`fn_execute_library_profile_change(p_proposal_id uuid) RETURNS void`** (interne)

Appelé par :
- `fn_propose_library_profile_change` directement (transitions de type 1 sans vote)
- Le job pg_cron `process_profile_transition_grace` à expiration de la carence
- Le cas particulier où unanimité atteinte ET transition_type = 1 (pas de carence)

Logique :
1. Vérif : proposition existe, status IN (`'accepted_unanimous'`, `'accepted_majority'`, ou `'open'` si transition_type=1 sans vote)
2. **Doctrine 141.2.E** : INSERT dans `library_profile_history` AVANT UPDATE de `libraries.*_mode` (narrative avant état)
3. Si transition_type = 4 : appeler les helpers d'archivage (paquet D, à implémenter ensuite, sinon RAISE 'paquet D requis')
4. UPDATE `libraries SET <axis>_mode = new_value`
5. UPDATE proposal SET status = `'completed'`, completed_at = now()
6. UPDATE lock SET released_at = now() (si existant)
7. Notify : `team.profile_change.completed_after_grace`

### 3.4 Jobs pg_cron

**`process_profile_transition_grace`** (horaire) :

```sql
SELECT cron.schedule('process_profile_transition_grace', '0 * * * *', $$
  SELECT fn_process_grace_expirations();
$$);
```

`fn_process_grace_expirations()` :
- Pour chaque proposal status IN ('accepted_unanimous', 'accepted_majority') ET grace_period_until < now()
- Appeler `fn_execute_library_profile_change(proposal_id)`

**`expire_profile_proposals`** (quotidien) :

```sql
SELECT cron.schedule('expire_profile_proposals', '0 2 * * *', $$
  UPDATE library_profile_proposals
  SET status = 'expired'
  WHERE status = 'open' AND expires_at < now();
$$);
```

**Modifications de jobs existants** (consulter `library_profile_grace_locks`) :
- `process_emprestimo_reminders` : skip les biblios avec lock actif
- `expire_solicitada` (réservations) : skip
- `process_pending_removal_complete` (admin réseau) : skip
- `refresh_mv_books_catalog_list_network_v1` : skip si lock affecte `catalog_mode`

À recenser et patcher au paquet B.3 (à voir le périmètre exact des jobs concernés).

### 3.5 Edge Function notify-event

Nouveau famille de handlers `team.profile_change.*` (6 events) :

| Event | Destinataires | Contenu |
|---|---|---|
| `proposed` | proposer (accusé) + autres admins/coords (action) + library_commons.coordination_email (R8) | axe, valeur ancienne → nouvelle, motivation, type, carence prévue |
| `voted_for` | autres admins/coords (info) + proposer (1er vote seulement, doctrine #114) | qui, sur quelle proposition |
| `voted_against` | autres admins/coords + proposer + library_commons.coord (R8) | qui, motivation contre |
| `accepted_unanimous` | tous les admins/coords (résultat) + library_commons.coord (R8) | axe, nouvelle valeur, grace_period_until |
| `cancelled_by_admin` | tous les admins/coords + library_commons.coord (R8) | qui a annulé, motivation |
| `completed_after_grace` | tous les admins/coords + library_commons.coord (R8) | axe, ancienne → nouvelle, effets concrets |

Code pattern : sous-handlers dans `_shared/domain/library_profile.ts` (nouveau fichier), routés depuis `notify-event/index.ts` selon prefix `team.profile_change.`.

### 3.6 i18n

6 events × 2 chaînes (subject + body) × 6 locales = 72 chaînes.

À ajouter dans `_shared/i18n/mail-strings.ts` côté EF + 0 chaînes côté frontend (le frontend ne montre pas ces mails, juste un toast post-action peut-être).

Clés proposées :
- `mail.profile_change.proposed.subject` / `.body`
- `mail.profile_change.voted_for.subject` / `.body`
- ... (idem pour les 4 autres events)

---

## 4. Découpage en sous-paquets (proposition)

Sur le modèle du chantier #143 (granularité fine), je propose :

| Sous-paquet | Périmètre | Estimation |
|---|---|---|
| **B.1** | 3 tables + RLS + triggers anti-UPDATE/DELETE + DO-block | ~0.5j |
| **B.2** | 2 helpers `fn_classify_transition` + `fn_required_governance_for_transition` | ~0.5j |
| **B.3** | 4 RPC (propose, vote, revoke, execute) | ~1j |
| **B.4** | 2 jobs pg_cron + audit des jobs existants à patcher | ~0.5j |
| **B.5** | Handler EF `team.profile_change.*` + 6 sub-events | ~0.5j |
| **B.6** | i18n 72 chaînes × 6 locales | ~0.5j |
| **Total** | | **~3j (cohérent spec)** |

Découpage en migrations SQL (timestamps successifs) :
- Migration 1 (B.1) : tables + triggers + DO-block vérifications
- Migration 2 (B.2) : helpers de classification
- Migration 3 (B.3) : 4 RPC + DO-block tests RLS
- Migration 4 (B.4) : 2 jobs pg_cron + patches des jobs existants

EF + i18n hors migration : commits classiques sur le repo.

---

## 5. Critères d'acceptation par sous-paquet

### B.1 — Tables
- [ ] 3 tables créées : `library_profile_proposals`, `library_profile_votes`, `library_profile_grace_locks`
- [ ] Toutes les CHECK constraints actives (status, axis, vote, transition_type, longueur motivation/rationale)
- [ ] RLS SELECT pour staff biblio + admins réseau, INSERT/UPDATE/DELETE refusés (sauf via RPC)
- [ ] Triggers `fn_block_lpp_*` sur les 3 tables (anti-UPDATE/DELETE sauf champs autorisés du paquet B.3)
- [ ] Indexes performants : `(library_id, status)`, `(status, expires_at)`, `(library_id, grace_until) WHERE released_at IS NULL`
- [ ] DO-block : test SET LOCAL ROLE anon + claims '{}' → SELECT bloqué ; SET LOCAL authenticated + claims sub=admin biblio → SELECT OK
- [ ] Aucune régression : `SELECT count(*) FROM libraries` toujours OK, BLMF/BTL accessibles

### B.2 — Helpers de classification
- [ ] `fn_classify_transition` retourne 1, 2, 3 ou 4 pour les 8 transitions canoniques de la matrice §4.2
- [ ] `fn_required_governance_for_transition` retourne `'direct'` / `'majority'` / `'unanimous'` / `'unanimous_extended'` selon (governance_mode, type)
- [ ] Cas particulier `staff_roles → informal` → `'unanimous_extended'` validé
- [ ] DO-block : tester les 16+ combinaisons (axes × type × governance) avec ASSERT explicites

### B.3 — RPC
- [ ] `fn_propose_library_profile_change` :
  - Refuse si combo CHECK croisé violé (test : `catalog_mode = network_published` alors que `network_mode = isolated` → RAISE clair)
  - Refuse si proposition `open` existe sur même axe (test : 2 appels successifs → 2e RAISE)
  - Refuse si proposition incompatible en cours (test : cooptation ouverte alors qu'on tente `full_governance → staff_roles`)
  - Si `governance_required = 'direct'` : INSERT direct dans `library_profile_history` + UPDATE `libraries.*_mode` (sans passage par proposals)
  - Sinon : INSERT proposal + INSERT lock si type 3/4 + outbox event
- [ ] `fn_vote_library_profile_change` :
  - Refuse si caller pas admin/coord
  - Refuse si déjà voté
  - Refuse si `vote = 'against'` sans rationale ≥ 20 chars
  - Si `against` ET governance_required = unanimous → proposition rejected immédiat
  - Si tous votes for → status accepted_*, grace_period_until rempli
- [ ] `fn_revoke_library_profile_transition` :
  - Fonctionne pendant `open` ou `accepted_*` (avant grace_period_until)
  - Refuse après grace_period_until ou si status = completed
  - Libère le lock
- [ ] `fn_execute_library_profile_change` :
  - **Doctrine 141.2.E respectée** : INSERT history AVANT UPDATE libraries (test : si on injecte une erreur entre les 2, la history n'est pas écrite)
  - UPDATE columns SET avec audit
  - Refuse si type = 4 et paquet D pas encore livré (RAISE explicite avec message orientant)

### B.4 — Jobs pg_cron
- [ ] `process_profile_transition_grace` créé, fréquence horaire
- [ ] `expire_profile_proposals` créé, fréquence quotidienne 2h du matin
- [ ] Test simulé : créer proposal accepted_* avec grace_period_until < now(), attendre 1h, vérifier que status passe à `completed` et libraries.*_mode est UPDATE
- [ ] Test simulé : créer proposal `open` avec expires_at < now(), attendre 24h, vérifier passage à `expired`
- [ ] Patch des jobs existants concernés : consulter `library_profile_grace_locks` avant traitement
- [ ] Liste des jobs patchés documentée

### B.5 — Edge Function
- [ ] Nouveau fichier `_shared/domain/library_profile.ts` avec 6 sub-handlers
- [ ] Routage depuis `notify-event/index.ts`
- [ ] Doctrine R8 : chaque event inclut `library_commons.coordination_email` en destinataire CC ou Bcc
- [ ] Doctrine #114 : `voted_for` ne notifie le proposer que sur le 1er vote
- [ ] Test fumée prod : créer une proposal test (axe trivial type 1) et vérifier que les 4 mails sont envoyés (accusé + 2 admins/coords + coord email)

### B.6 — i18n
- [ ] 72 chaînes ajoutées dans `_shared/i18n/mail-strings.ts`
- [ ] Test : pour chaque event, vérifier que la chaîne `subject` et `body` existent dans les 6 locales
- [ ] Tests de placeholders : `{axis_label}`, `{old_label}`, `{new_label}`, `{motivation}`, `{rationale}`, `{voter_name}` correctement interpolés

---

## 6. Tests fonctionnels (mapping spec §12)

Cf. spec §12.4 "Tests de transitions" et §12.5 "Tests de gel pendant carence" pour la liste exhaustive. À dérouler après livraison de B en environnement de test, idéalement sur une biblio fictive (créée pour l'occasion).

À documenter dans un nouveau `docs/decisions/QA_MANUELLE_paquet-B-transitions-YYYY-MM-DD.md` sur le modèle des QA consultations / réservations / emprunts.

---

## 7. Risques identifiés

D'après spec §11.2 :

| Risque | Probabilité | Impact | Mitigation |
|---|---|---|---|
| Une biblio bascule en `circulation_mode = off` par erreur ou suite à un conflit interne | Faible | Élevée | Carence + notif obligatoire à tous les membres staff + révocation possible. En full_governance, unanimité requise. |
| En `informal`, un seul membre staff initie une transition de type 4 sans que les autres y prêtent attention | Faible | Moyenne | Carence 48h + bandeau visible dans le painel pendant la carence. |
| `staff_roles → informal` mal géré (perte des rôles auto-validants) | Faible | Élevée | Doctrine §4.5.6 : carence 7j + unanimité étendue admins+coords + état préservé pendant la carence. Test rigoureux obligatoire. |

Risques techniques spécifiques au paquet B :
- **Logique d'unanimité touche plusieurs jobs pg_cron existants.** Tests simulés indispensables (`SET LOCAL ROLE` + `SET LOCAL "request.jwt.claims"` cf. doctrine RLS chantier 11-12/05).
- **Le job `process_profile_transition_grace` doit être idempotent.** Si appelé 2 fois sur la même proposal accepted_*, le 2e appel doit no-op.
- **Couplage avec paquet D archivage.** Si une transition type 4 est exécutée mais que D n'est pas encore livré, RAISE explicite avec message "paquet D requis pour transitions critiques".

---

## 8. Préparation à la reprise (commandes Day 0)

### 8.1 Vérifier le contexte

```powershell
cd "C:\Users\accat\Claude's AnarBib\anarbib-app"

# Etat du repo
git status
git log --oneline -5

# Verifier qu'on est à jour
git pull
```

### 8.2 Vérifier l'état DB (paquet A en prod)

3 requêtes SQL à passer (cf. §2.2 ci-dessus).

### 8.3 Voir les triggers d'audit existants comme modèle

```powershell
# Voir le pattern fn_block_lph_modification du paquet A
Select-String -Path "supabase\migrations\*paquet_A_profils*" -Pattern "fn_block_lph_modification" -Context 0,15 | Select-Object -First 1
```

### 8.4 Voir les RPC cooptation comme modèle pour propose/vote

```powershell
# Modèle pour fn_propose_library_profile_change et fn_vote_library_profile_change
Get-ChildItem "supabase\migrations" -Filter "*cooptation*" | Select-Object Name
```

### 8.5 Confirmer l'absence d'utilisateurs tiers

Fenêtre stratégique : aucun utilisateur tiers en prod (cf. backlog v15 §VIII), donc on peut faire évoluer les RLS et créer des proposals de test sans craindre de perturber des usagers réels.

---

## 9. Livrables attendus en fin de session

À la fin de la session paquet B, on devrait avoir produit :

1. **4 migrations SQL** dans `supabase/migrations/` (B.1, B.2, B.3, B.4)
2. **1 fichier** `_shared/domain/library_profile.ts` dans `supabase/functions/_shared/`
3. **1 update** de `notify-event/index.ts` pour router `team.profile_change.*`
4. **6 fichiers i18n** mis à jour (`mail-strings.ts` × 6 locales si éclaté, ou 1 seul fichier multilocale selon convention actuelle)
5. **1 doc** `docs/decisions/SESSION_paquet-B-transitions-profils_YYYY-MM-DD.docx` trace de session
6. **1 doc** `docs/decisions/QA_MANUELLE_paquet-B-transitions-YYYY-MM-DD.md` plan QA cadré (à dérouler ensuite)
7. **1 update** `docs/backlogs/AnarBib-Backlog-YYYY-MM-DD-v16.md` :
   - Paquet B clos
   - Prochain : paquet D (archivage) — prérequis pour ouvrir paquet C aux transitions de type 4
8. **Memory edits Claude** mis à jour avec doctrines émergées du paquet B

---

## 10. Doctrines à inscrire (anticipées)

Ces doctrines émergeront probablement du paquet B et seront à acter en spec ou en backlog :

1. **Cohabitation jobs pg_cron / grace_locks** : convention de comment les jobs doivent consulter `library_profile_grace_locks` (helper utilitaire ? requête inline ?). À standardiser pour les ajouts futurs.

2. **Symétrie tables proposals/votes** : la table `library_profile_proposals` ressemble fortement à `network_administrator_cooptation_proposals` (chantier 114). Voir si on peut extraire un pattern réutilisable (mixin SQL ? template ?). Pour l'instant : duplication assumée, refacto possible plus tard.

3. **Idempotence des exécuteurs** : `fn_execute_library_profile_change` peut être appelée plusieurs fois sur la même proposal sans effet de bord. Convention à étendre aux exécuteurs futurs.

---

## 11. Notes de fin

Ce prompt a été rédigé le 17/05/2026 en fin de session productive (4 chantiers clos : #132, #142, #143, plus #141 la veille). L'état du projet est exceptionnellement propre : 0 bug critique ouvert, 0 régression, fenêtre stratégique préservée.

Le paquet B est le **prochain gros chantier** du projet et marque le passage de l'infrastructure dormante à la machinerie active. Une fois B livré, le paquet D (archivage) deviendra le prochain prérequis pour ouvrir les transitions de type 4. La séquence A → C → B → D recommandée par la spec §10.2 est ainsi respectée (A fait, B prochain, C peut se faire en parallèle ou après B).

Bonne reprise. Travaille avec sérénité.

---

*Document de reprise. À conserver dans `docs/decisions/` jusqu'à clôture du paquet B.*
