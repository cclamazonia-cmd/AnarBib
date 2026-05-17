# Prompt de reprise — Chantier #98-B Paquet B Transitions de profils

**Sous-paquets restants** : B.5 (handler EF) + B.6 (i18n)
**Session précédente** : dimanche 17 mai 2026, 16h00 → 22h45
**Statut** : 4/6 sous-paquets livrés en prod (B.1, B.2, B.3, B.4)

---

## 0. État actuel du chantier

### Ce qui est en prod (DB)

| Sous-paquet | Commit | Contenu |
|---|---|---|
| **B.1** | `863addc` | 3 tables d'audit (`library_profile_proposals`, `library_profile_votes`, `library_profile_grace_locks`) + 3 trigger functions d'immutabilité + 3 policies RLS SELECT + 6 indexes |
| **B.2** | `4c472af` | 2 fonctions de classification (`fn_classify_transition`, `fn_required_governance_for_transition`) + document de doctrine (`docs/decisions/CHANTIER_doctrine_transitions_profils_2026-05-17.md`) |
| **B.3** | `a777c14` | 4 RPC métier (`fn_propose_*`, `fn_vote_*`, `fn_cancel_*`, `fn_execute_*`) + helper `fn_library_active_staff_count` |
| **B.4** | `13dc92b` (+ fix) | 2 fonctions cron (`fn_expire_overdue_*`, `fn_execute_due_*`) + 2 jobs `pg_cron` enregistrés |

### Vérifications fraîches (à passer en début de session reprise)

```sql
-- 1. Toutes les fonctions B en place ?
SELECT proname FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
WHERE n.nspname='public' AND proname IN (
  'fn_classify_transition',
  'fn_required_governance_for_transition',
  'fn_library_active_staff_count',
  'fn_propose_library_profile_change',
  'fn_vote_library_profile_change',
  'fn_cancel_library_profile_change',
  'fn_execute_library_profile_change',
  'fn_expire_overdue_profile_proposals',
  'fn_execute_due_profile_proposals'
)
ORDER BY proname;
-- Attendu : 9 lignes

-- 2. Jobs pg_cron actifs ?
SELECT jobname, schedule, active FROM cron.job 
WHERE jobname LIKE 'anarbib_%profile%';
-- Attendu : 2 lignes, active=true, schedules '0 3 * * *' et '*/15 * * * *'

-- 3. Migrations B trackées ?
SELECT version FROM supabase_migrations.schema_migrations 
WHERE version >= '20260517170000' AND version < '20260518000000'
ORDER BY version;
-- Attendu : 4 lignes (170000 B.1, 190000 B.2, 210000 B.3, 230000 B.4)
```

---

## 1. B.5 — Handler EF `library_profile`

### Objectif

Ajouter un nouveau **handler de domaine** dans l'Edge Function `notify-event` qui réagit aux events du paquet B et envoie les notifications mail appropriées aux destinataires.

### Périmètre

**Fichier à créer** : `supabase/functions/notify-event/_shared/domain/library_profile.ts`

**6 sub-events** à gérer :

| Sub-event | Déclenché par | Destinataires | Contenu mail |
|---|---|---|---|
| `library_profile.proposed` | INSERT `library_profile_proposals` (sauf type 1 auto-completed) | Staff actif de la biblio (sauf proposeur) | « Nouvelle proposition de transition sur l'axe X » + CTA voter |
| `library_profile.voted` | INSERT `library_profile_votes` | **Au 1er vote uniquement** : proposeur (doctrine #21). Toujours : autres staff non-encore-votants | « X a voté for/against, état actuel : N/M » |
| `library_profile.accepted` | UPDATE `library_profile_proposals` status → `accepted_*` | Tout le staff + admins réseau actifs (transition validée, info publique) | « La transition X a été acceptée, carence jusqu'au … » |
| `library_profile.rejected` | UPDATE `library_profile_proposals` status → `rejected` ou `expired` | Proposeur + staff + admins réseau actifs (selon raison) | « La proposition X a été rejetée/expirée » |
| `library_profile.cancelled` | UPDATE `library_profile_proposals` status → `cancelled` | Tout le staff (sauf proposeur) + admins réseau actifs | « Le proposeur a annulé la proposition X : motif … » |
| `library_profile.executed` | UPDATE `libraries.*_mode` via `fn_execute_*` (donc INSERT `library_profile_history`) | Tout le staff + admins réseau actifs + (optionnel) usager·es impacté·es | « La biblio X est passée de A à B sur l'axe Y » |

### Architecture technique

**Pattern à suivre** : le handler `network.*` du chantier #114 (dans `_shared/domain/network.ts`) est le modèle. Voir :
- `supabase/functions/notify-event/_shared/domain/network.ts`
- `supabase/functions/notify-event/index.ts` (registre des domaines)
- `supabase/functions/notify-event/_shared/mail/layout.ts` (rendu mail)
- `supabase/functions/notify-event/_shared/i18n/mail-strings.ts` (i18n)

**Étapes** :

1. **Triggers DB** à ajouter : 3 nouveaux triggers AFTER INSERT/UPDATE sur les 3 tables de B.1, qui appellent `fn_team_notify_event('library_profile.<sub_event>', ...)` (voir mémoire pattern outbox #14)
   - Trigger sur `library_profile_proposals` (INSERT → `proposed`, UPDATE status → `accepted_*`/`rejected`/`cancelled`)
   - Trigger sur `library_profile_votes` (INSERT → `voted`)
   - Trigger sur `library_profile_history` (INSERT → `executed`)

2. **Handler EF** dans `_shared/domain/library_profile.ts` : pour chaque sub-event, construire le payload mail.

3. **Enregistrement du domaine** dans `index.ts` : `domainHandlers.library_profile = handleLibraryProfileEvent`.

4. **i18n keys** dans `mail-strings.ts` : voir B.6.

5. **Déploiement manuel** (mémoire #4) :
   ```bash
   supabase functions deploy notify-event --no-verify-jwt
   ```

### Doctrines à appliquer

- **Mémoire #8 (actionBox)** : `actionBox` attend `{kind: 'action'|'info', title: string, ctaUrl: string, ctaLabel: string}`. PAS `{kind, label, url}`. À chaque appel à `renderEmail`, vérifier le contrat avant.
- **Mémoire #14 (outbox)** : `team_notification_outbox` n'a pas de `recipient_user_id`. Le fan-out est calculé dans l'EF en lisant le payload. CHECK constraint accepte `team.%` ou `network.%`. **Question doctrinale à trancher en début de session B.5** : les events `library_profile.*` sont-ils `team.library_profile.*` (perimètre biblio) ou `network.library_profile.*` (visibles au réseau quand transitions affectent `network_mode` ou `catalog_mode = network_published`) ? Discussion à avoir.
- **Mémoire #21 (proposeur silencieux)** : sur `voted`, le proposeur est notifié UNIQUEMENT au 1er vote (signal démarrage), puis silencieux jusqu'au résultat. Implémenté via `voteCount === 1` check.
- **Mémoire #19 (Supabase default privileges)** : tout nouveau trigger function créé en B.5 doit avoir `REVOKE EXECUTE ON FUNCTION ... FROM PUBLIC, anon, authenticated, service_role` (puisque les triggers ne sont pas censés être callable depuis frontend).

### Décisions politiques à prendre en début de session

1. **Périmètre des events** : `team.library_profile.*` ou `network.library_profile.*` ? Recommandation à débattre : `team.*` pour `proposed/voted/cancelled` (intra-staff), `network.*` pour `accepted/executed` (info publique au réseau).
2. **Mail pour les usager·es impacté·es** sur `executed` : si la transition affecte la circulation (ex. `full_sigb → off`), faut-il prévenir les emprunteur·euses en cours ? Probablement oui mais c'est un mail différent (pas un mail staff/réseau).
3. **Sujet/ton des mails** : ton doctrinal anarchiste, pas de jargon technique. Ex. « La bibliothèque X a décidé de rejoindre la fédération » plutôt que « Le mode network_mode de X a été mis à jour ».

### Volume estimé

- ~300-400 lignes TypeScript (handler + helpers)
- ~80-150 lignes SQL pour les 3 triggers de notification
- 1h30 de session

---

## 2. B.6 — Internationalisation (i18n)

### Objectif

Traduire **toutes les chaînes utilisateur** du chantier B en 6 locales : pt-BR (primaire), fr, es, en, it, de.

### Périmètre — recensement détaillé

Le prompt de reprise initial estimait 72 chaînes. **En réalité on en aura plus**. Recensement précis :

#### A. Chaînes d'erreur RPC (B.3 + B.2)

Issues des `RAISE EXCEPTION` avec HINT `error.profile_change.*` :

```
error.profile_change.auth_required
error.profile_change.not_staff
error.profile_change.motivation_too_short
error.profile_change.axis_already_open
error.profile_change.unknown_axis
error.profile_change.library_not_found
error.profile_change.archiving_not_available
error.profile_change.quorum_not_met
error.profile_change.vote_invalid
error.profile_change.proposal_not_found
error.profile_change.proposal_not_open
error.profile_change.proposal_expired
error.profile_change.rationale_required
error.profile_change.vote_already_cast
error.profile_change.not_proposer
error.profile_change.not_authorized
error.profile_change.not_accepted
error.profile_change.grace_period_active
error.profile_change.same_value
error.profile_change.invalid_values
```

→ **20 clés × 6 locales = 120 traductions**

#### B. Chaînes UI (panel staff biblio)

Pour l'UI « Proposer une transition », « Voter », « Annuler », « État des propositions », il faut :
- Labels des 4 axes (catalog_mode, circulation_mode, network_mode, governance_mode) → 4 × 6 = 24
- Labels des valeurs (local_only, network_published, off, informal, full_sigb, isolated, observer, federated, informal, staff_roles, full_governance) → 11 × 6 = 66
- Labels des 4 types de transition (direct, majority, unanimous, unanimous_extended) → 4 × 6 = 24
- Labels des statuts proposal (open, accepted_unanimous, accepted_majority, rejected, expired, cancelled, completed) → 7 × 6 = 42
- Labels d'actions (propose, vote_for, vote_against, cancel, view_details) → 5 × 6 = 30
- Phrases descriptives (« Cette transition demande X », « Vote requis : N/M », « Carence jusqu'au … ») → ~10 × 6 = 60

→ **~50 clés × 6 locales = ~300 traductions**

#### C. Chaînes mail (B.5)

Pour chaque sub-event (6) il faudra :
- Sujet (`subject.library_profile.{event}`) → 6 × 6 = 36
- Intro (`intro.library_profile.{event}`) → 6 × 6 = 36
- Body principal → 6 × 6 = 36
- Action box title + cta label → 6 × 6 × 2 = 72

→ **~24 clés × 6 locales = ~144 traductions**

#### Total volume i18n B.6

**~94 clés × 6 locales = ~564 traductions**

Beaucoup plus que les 72 estimés. À considérer pour la planification.

### Approche

1. **Phase 1 : recensement définitif** des clés (à partir du code B.3 + B.5 effectivement écrits)
2. **Phase 2 : rédaction pt-BR** (locale primaire, doctrine anarchiste, ton militant)
3. **Phase 3 : traductions** dans les 5 autres locales (fr/es/en/it/de)
4. **Phase 4 : intégration** dans les fichiers i18n :
   - Frontend : `src/locales/<locale>/profile_change.json` (à créer)
   - Mail : `supabase/functions/notify-event/_shared/i18n/mail-strings.ts` (à étendre)

### Décisions politiques à prendre

1. **Termes politiques par locale** : « bibliothèque militante » se traduit comment en chaque langue ? « gouvernance unanime », « rétractation politique », « élargissement immédiat »… Ces termes ne sont pas neutres, ils encodent une doctrine.
2. **Niveau de formalité par locale** : pt-BR doctrinal vs littéral ? Tu (tu/você) ou vous (vós/o senhor) ?
3. **Tons mail différenciés** : message « accepted » plus solennel que « voted intermédiaire » ?

### Volume estimé

- Recensement précis : 30 min
- Rédaction pt-BR : 1h
- Traductions (avec aide IA) + relecture humaine : 1h-1h30
- Intégration code : 30 min

**Total estimé : ~3h pour B.6.** Plus long que les 1h annoncés initialement, en raison du volume i18n réel et de la difficulté politique des termes.

---

## 3. Doctrines actives à rappeler en début de session

À relire en début de session B.5 :

- **Mémoire #8** : contrat `actionBox`
- **Mémoire #14** : pattern outbox + helpers `fn_team_notify_event` / `fn_network_notify_event`
- **Mémoire #19** : doctrine création objets + piège Supabase default privileges (REVOKE étendu)
- **Mémoire #21** : proposeur silencieux après 1er vote
- **Mémoire #22** : schéma `user_library_memberships` (role, status) + `network_staff` (is_active, can_*)
- **Mémoire #14** + this prompt §B.5 : périmètre `team.*` vs `network.*` à trancher

---

## 4. Backlog hors session B (à ouvrir séparément)

1. **Audit sécurité fonctions privées AnarBib** (chantier né de B.4 v2) : passer en revue toutes les fonctions du schema `public` créées dans les migrations précédentes (paquet A profils, admin réseau v0.3, consultations, etc.) qui n'ont qu'un `REVOKE FROM PUBLIC` et qui devraient être privées. Requête de diagnostic :
   ```sql
   SELECT p.proname, p.prosecdef, has_function_privilege('authenticated', p.oid, 'EXECUTE') 
   FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
   WHERE n.nspname='public' AND p.prosecdef = true
   ORDER BY p.proname;
   ```
   → établir une liste des fonctions à risque, prioriser, faire un paquet d'audit.

2. **Chantier quickReserve** : finir la livraison après les 2 commits incomplets `0c7cef3` + `76b27ca`. Vérifier que `CatalogPage.jsx` consomme bien `api.my_library_context` partout. Tester end-to-end le bouton de réservation rapide.

3. **Nettoyage scripts one-shot Claude** : pattern `create-*.cjs` + `fix-*.cjs` est dans `.gitignore` depuis cette session. À chaque fin de paquet, supprimer manuellement les scripts du dossier racine du repo pour ne pas accumuler.

---

## 5. Métriques de la session 17/05/2026

- **Durée totale** : ~5h (16h00 → 22h45 environ avec breaks)
- **Sous-paquets livrés** : 4/6 (B.1, B.2, B.3, B.4)
- **Lignes SQL** : ~2 000 (B.1 : 450, B.2 : 480, B.3 : 845, B.4 : 370)
- **Commits B** : 4 (un par sous-paquet, plus 2 amend fix)
- **Itérations correctives** : 2 (B.1 fix alignement schéma, B.4 fix syntaxe + REVOKE étendus)
- **Doctrines apprises et inscrites en mémoire** :
  - Cartographie schéma `user_library_memberships` + `network_administrators` vs `network_staff`
  - Piège Supabase `ALTER DEFAULT PRIVILEGES` sur fonctions

---

## 6. Commande pour démarrer la session reprise

Une fois prêt·e, ouvre une nouvelle conversation Claude (dans le projet AnarBib) avec ce prompt ouvert et un message du genre :

> Reprise du paquet B Transitions de profils. Sous-paquets B.1-B.4 livrés en prod hier (17/05). On enchaîne sur B.5 (handler EF library_profile) puis B.6 (i18n). Prompt de reprise déposé dans docs/decisions/Prompt-Reprise-98B-Paquets-B5-B6.md.

Et Claude va naviguer le projet, lire le prompt + les mémoires, et démarrer fraîchement avec tout le contexte.
