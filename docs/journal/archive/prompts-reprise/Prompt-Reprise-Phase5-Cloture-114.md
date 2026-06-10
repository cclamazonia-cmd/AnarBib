# Prompt de reprise — Phase 5 E2E + clôture chantier #114

**Version** : 1.0 — 2026-05-14 (fin de session)
**Périmètre** : tests E2E des 10 sous-handlers `network.*`, cleanup outbox de test, mise à jour spec admin réseau v0.3, fermeture définitive du chantier #114.
**Estimation** : 4-6h en session fraîche.
**Prérequis** : aucun (le code est déployé et validé en routing).

---

## 1. État au début de cette reprise

### 1.1 — Chantier #114 : implémentation 100% terminée et déployée

Le routing complet des 10 events `network.*` est en production sur Supabase (EF `notify-event`, projet `uflwmikiyjfnikiphtcp`).

**Commits poussés sur Codeberg + GitHub (mirror) le 14/05/2026 :**

| Commit | Étape | Description |
|---|---|---|
| `9d3ae6b` | 114.B étape 1 | Patch DB : `trg_check_cooptation_completion` enrichi (doctrine 4.2 : rationale opposé) |
| `8e3c2b2` | 114.B étape 2 | 3 clés i18n × 6 locales ajoutées dans `mail-strings.ts` |
| (fix indent) | 114.B étape 2 fix | Indentation et retours-ligne propres pour les 3 clés |
| (commit 3a) | 114.B étape 3a | 3 sous-handlers cooptation (`rejected`, `completed`, `reminder`) |
| (commit 3b) | 114.B étape 3b | 5 sous-handlers retrait collectif (`proposed`, `vote_cast`, `unanimous`, `cancelled`, `executed`) |
| (commit 3c) | 114.B étape 3c | Hotfix bug placeholder i18n `targetName` → `proposedName` |

**État du fichier `_shared/domain/network.ts` :**
- 1286 lignes
- 10 sous-handlers fonctionnels
- 6 helpers (markOutbox*, loadProfile, loadProfilesByIds, loadActiveNetworkAdmins, loadVoteRationale, loadCollectiveRemovalVoteRationale, displayName, cooptationProposalUrl, collectiveRemovalProposalUrl)

### 1.2 — Test fumée validé (Niveau A)

5 events de chaque famille ont été insérés manuellement dans `team_notification_outbox` avec des UUID factices. Tous ont été marqués `status='sent'` par l'EF sans crash. **Les mails sont bien partis, le routing est validé, l'i18n est correcte.**

⚠️ **MAIS le test E2E (Niveau B) n'a PAS été fait.** Il reste à faire dans cette reprise — c'est l'objet principal de Phase 5.

### 1.3 — Décisions doctrinales prises pendant #114.B

À reporter dans `docs/specs/spec-administrateur-reseau.md` v0.3 (cf. Phase 6 ci-dessous).

| Réf spec impl | Décision finale | Lieu d'implémentation |
|---|---|---|
| §4.1 | `cooptation_rejected.target_intro` : doctrine de fermeture politique non personnelle, texte court (« décision collective et politique, non personnelle ») | i18n existante, conservée telle quelle |
| §4.2 | Rationale opposé dans `cooptation_rejected` : diffusé seulement si `disclose_identity=true` ET vote `opposed`. Cohérent avec doctrine §4.4 de #114.A | Patch DB étape 1 + handler `handleCooptationRejected` |
| §4.3 | `cooptation_completed` : mail-only, pas d'effet de bord. L'INSERT dans `network_administrators` est fait par le trigger DB AVANT l'émission de l'event | Confirmé, pas de code spécifique |
| §4.4 | `cooptation_reminder` : 2 mails distincts. Retardataires reçoivent `.intro` (« vous devez voter »), proposeur reçoit `.proposer_intro` (« votre proposition s'enlise ») | Handler `handleCooptationReminder` + nouvelle clé i18n |
| §4.5 | `collective_removal_proposed` : target jamais notifié à l'ouverture. Hors périmètre mail (cas de fuite) | Handler exclut le target explicitement |
| §4.6 | `collective_removal_unanimous` : 2 mails distincts (target avec carence 7j + tous admins avec date exécution) | Handler `handleCollectiveRemovalUnanimous` |
| §4.7 | Annulation par retrait de vote : 1 event `cancelled` avec `was_unanimous` flag. Si `was_unanimous=true`, target avait été notifié → on lui notifie l'annulation. Sinon, target jamais notifié de rien | Handler `handleCollectiveRemovalCancelled` |
| §4.8 | `collective_removal_executed` : notif simple, pas d'export RGPD (hors périmètre #114.B). `executed_at` calculé côté EF (`new Date().toISOString()`) | Handler `handleCollectiveRemovalExecuted` |

### 1.4 — Raffinement doctrinal supplémentaire (à inscrire en spec)

**Le proposeur n'est notifié au `*_vote_cast` qu'au 1er vote** (signal de démarrage du processus). Pour les votes suivants, silencieux jusqu'au résultat (`completed`/`rejected`/`unanimous`/`cancelled`).

Implémenté pour cooptation_voted (en #114.A) ET pour collective_removal_vote_cast (en #114.B-3b) via comptage des votes existants sur la proposition (`voteCount === 1`).

### 1.5 — Imperfection cosmétique identifiée (non bloquante)

Dans `handleCollectiveRemovalVoteCast`, le payload SQL ne contient pas `proposed_by`. Mon code le récupère via `SELECT proposed_by FROM network_admin_collective_removal_proposals`. Si la proposition n'existe plus (cas pathologique), le proposeur s'affiche `"?"` dans le mail.

**Option d'amélioration** : enrichir le payload côté DB (similaire au patch étape 1 pour `cooptation_rejected`). À voir si nécessaire après les tests E2E. Si Phase 5 confirme que ce cas ne se manifeste jamais en conditions réelles, on laisse tel quel.

---

## 2. Phase 5 — Tests E2E réels (3-4h)

### 2.1 — Prérequis : setup admins temporaires

Pour tester tous les events, il faut **au moins 3 admins réseau actifs** (quorum requis par `fn_network_admin_propose_collective_removal`). Xavier seul ne suffit pas.

**Plan** : coopter temporairement Lívia + Patricia comme admins réseau.

⚠️ **Problème circulaire** : pour coopter, il faut au moins 1 admin actif (Xavier ✅), mais la cooptation se fait par unanimité des autres admins → avec 1 seul admin existant, il faut bypasser l'unanimité.

**Solution** : INSERT manuel dans `network_administrators` pour les 2 nouvelles admins, en simulant qu'elles ont été cooptées :

```sql
-- Bypass cooptation : INSERT direct comme admins actifs
INSERT INTO network_administrators (user_id, status, coopted_at, coopted_by_unanimity_of)
VALUES 
  ('366cdc4e-10e0-44ad-8554-a444bcf9607a', 'active', now(), ARRAY['d6710372-e5e5-4608-800b-99a26817c677']::uuid[]),
  ('2a42b6bd-d159-4ee0-b66b-28a03062232b', 'active', now(), ARRAY['d6710372-e5e5-4608-800b-99a26817c677']::uuid[])
ON CONFLICT (user_id) DO UPDATE SET status='active';

-- Verifier
SELECT user_id, status, coopted_at FROM network_administrators ORDER BY coopted_at DESC;
```

**À la fin des tests, on retire Lívia et Patricia pour revenir à l'état « Xavier seul ».**

### 2.2 — Scénario 1 : Cooptation complète menant à `completed`

**Acteurs** : Xavier (proposeur), Lívia + Patricia (admins votants), Rafael LIMA (target, `a7335128-c741-4f69-b9ff-b48ac92e575a`).

**Étapes** (à faire via SQL Editor avec bypass `auth.uid()` — cf. mémoire) :

1. **Proposer Rafael en cooptation** depuis Xavier.
   - Mail attendu : Lívia et Patricia reçoivent `network.cooptation_proposed`.
   - Vérifier : nom de Rafael affiché correctement, motivation visible, CTA fonctionnel.
   
2. **Lívia vote favorable** (avec `disclose_identity=true`).
   - Mails attendus : Xavier (1er vote = signal de démarrage), Patricia. Pas de mail à Lívia (voteur) ni à Rafael (target).
   - Vérifier : nom de Lívia visible, vote « favorable ».

3. **Patricia vote favorable** (avec `disclose_identity=true`).
   - Mail attendu : `network.cooptation_completed` parti à Rafael (bienvenue), Xavier, Lívia.
   - Vérifier : Rafael reçoit le `target_intro` (« tu as été coopté·e »), les autres reçoivent le `intro` (annonce).
   - Pas de mail à Patricia (voteur) ni à Xavier (proposeur silencieux après 1er vote, MAIS doit recevoir l'annonce completed).
   - **Edge case à vérifier** : Xavier doit-il recevoir `voted` au 2e vote (= dernier vote qui déclenche unanimité) ? Selon doctrine raffinée, NON. Mais doit recevoir `completed`. À confirmer dans le scénario.

4. **Vérifier état DB** :
   ```sql
   SELECT status FROM network_administrator_cooptation_proposals WHERE id = <proposal_id>;
   -- doit etre 'completed'
   SELECT status FROM network_administrators WHERE user_id = 'a7335128-c741-4f69-b9ff-b48ac92e575a';
   -- doit etre 'active'
   ```

5. **Cleanup** : DELETE de Rafael de network_administrators si on ne veut pas le garder admin réseau.

### 2.3 — Scénario 2 : Cooptation menant à `rejected`

**Acteurs** : mêmes, target = Arthur SAMPAIO (`614d887d-4e8d-401d-a208-77c56a1cd5ea`).

**Étapes** :

1. **Proposer Arthur** depuis Xavier.
2. **Lívia vote favorable**.
3. **Patricia vote `opposed`** (avec `disclose_identity=true`, rationale ≥20 chars).
   - Mail attendu : `network.cooptation_rejected` parti à Arthur (target_intro), Xavier (proposeur), Lívia (autre admin). Patricia exclue (voteur opposé déjà au courant).
   - Vérifier sur le mail de Xavier et Lívia : rationale de Patricia VISIBLE (car disclose=true).
   - Vérifier sur le mail d'Arthur : texte « décision collective et politique, non personnelle ». Pas de rationale (target ne voit pas les rationales détaillés).

4. **Refaire le même scénario** avec Patricia votant `opposed` mais cette fois `disclose_identity=false`.
   - Vérifier : nom de Patricia ABSENT du mail, rationale ABSENT (cohérence doctrine §4.2).

### 2.4 — Scénario 3 : Cooptation `reminder` (J+14)

**Setup** : créer une proposition de cooptation en datant `proposed_at` à J-15.

```sql
-- Insert proposition avec date dans le passé pour declencher cron J+14
INSERT INTO network_administrator_cooptation_proposals (proposed_user_id, proposed_by, proposed_at, motivation, status, expires_at)
VALUES ('<un_user_id>', 'd6710372-...', now() - interval '15 days', 'motivation factice...', 'open', now() + interval '45 days');
```

**Étapes** :

1. Lancer manuellement `fn_cron_cooptation_send_reminders()` :
   ```sql
   SELECT public.fn_cron_cooptation_send_reminders();
   ```
2. Mail attendu : Lívia + Patricia (pending voters) reçoivent `.intro` ; Xavier (proposeur) reçoit `.proposer_intro`.
3. Vérifier les 2 textes différents.

### 2.5 — Scénario 4 : Retrait collectif complet jusqu'à `executed`

**Acteurs** : Xavier proposeur, Lívia + Patricia votantes, target = un admin temporaire à coopter d'abord.

Pour ce test, on a besoin d'un 4e admin (target) à retirer. **Setup spécifique** : on coopte temporairement Rafael, puis on propose son retrait.

**Étapes** :

1. **INSERT manuel** de Rafael comme admin actif (bypass cooptation).
2. **Vérifier quorum ≥ 3** :
   ```sql
   SELECT count(*) FROM network_administrators WHERE status = 'active';
   -- doit etre >= 4 (Xavier + Livia + Patricia + Rafael)
   ```
3. **Proposer retrait de Rafael** depuis Xavier (motivation ≥ 50 chars).
   - Mail attendu : `network.collective_removal_proposed` parti à Lívia + Patricia. PAS à Xavier (émetteur). PAS à Rafael (target jamais notifié à ce stade).
4. **Lívia vote favor** (avec disclose=true, pas de rationale requis car favor).
   - Mail attendu : Patricia + Xavier (1er vote).
5. **Patricia vote favor** → unanimité atteinte (Xavier exclu car proposeur, Rafael exclu car target).
   - Mail attendu : `network.collective_removal_unanimous` parti à Rafael (`target_intro` avec carence 7j), Xavier (intro), Lívia (intro).
   - Vérifier état DB : `network_administrators.status` de Rafael = `pending_removal`, `pending_removal_until` = J+7.
6. **Forcer l'exécution du cron** (sans attendre 7j) :
   ```sql
   -- Avancer artificiellement pending_removal_until dans le passé
   UPDATE network_admin_collective_removal_proposals
   SET pending_removal_until = now() - interval '1 hour'
   WHERE proposed_user_id = '<rafael_id>' AND status = 'unanimous';
   
   -- Lancer le cron
   SELECT public.fn_cron_collective_removal_execute();
   ```
7. Mail attendu : `network.collective_removal_executed` parti à Rafael (target_intro), Xavier, Lívia, Patricia.
8. Vérifier état DB : `network_administrators.status` de Rafael = `removed`.

### 2.6 — Scénario 5 : Retrait collectif annulé après unanimité (`was_unanimous=true`)

**Setup** : refaire le scénario 4 jusqu'à l'unanimité, mais au lieu d'attendre l'exécution, annuler manuellement.

1. Refaire scénario 4 étapes 1-5 (unanimité atteinte sur un autre admin temporaire).
2. **Annuler la proposition** :
   ```sql
   SELECT public.fn_network_admin_cancel_collective_removal('<proposal_id>', 'Motif annulation factice pour test E2E');
   ```
3. Mail attendu : `network.collective_removal_cancelled` parti à :
   - **Target** (car was_unanimous=true) → reçoit `target_intro` (« proposition annulée, vous restez admin actif »)
   - Xavier (proposeur) + Lívia (autre admin) → reçoivent `intro` (annonce)
   - Patricia exclue (= annulatrice)
4. Vérifier le `reason_label` apparaît avec le motif.
5. Vérifier état DB : Rafael status = `active` (restauré), proposition status = `cancelled`.

### 2.7 — Scénario 6 : Retrait collectif annulé avant unanimité (`was_unanimous=false`)

**Setup** : retrait collectif proposé, 1 vote favor, puis annulation.

1. Proposer retrait.
2. Lívia vote favor.
3. Patricia (ou Xavier) annule.
4. Mail attendu : **target NE reçoit RIEN** (car was_unanimous=false). Seuls les admins reçoivent `intro`.

### 2.8 — Cleanup post-tests

```sql
-- Retirer Livia et Patricia de network_administrators (les remettre à 'removed')
UPDATE network_administrators
SET status = 'removed', removed_at = now()
WHERE user_id IN (
  '366cdc4e-10e0-44ad-8554-a444bcf9607a',
  '2a42b6bd-d159-4ee0-b66b-28a03062232b'
);

-- Idem pour tous les targets de test (Rafael, Arthur)
UPDATE network_administrators
SET status = 'removed', removed_at = now()
WHERE user_id IN (
  'a7335128-c741-4f69-b9ff-b48ac92e575a',
  '614d887d-4e8d-401d-a208-77c56a1cd5ea'
);

-- Verifier qu'il ne reste que Xavier actif
SELECT user_id, status FROM network_administrators WHERE status = 'active';
-- doit retourner 1 ligne : Xavier
```

**Optionnel** : purger les events de test de l'outbox :
```sql
DELETE FROM team_notification_outbox
WHERE event LIKE 'network.%'
  AND created_at < now() - interval '1 day';
```

---

## 3. Phase 6 — Mise à jour spec admin réseau v0.3 (30 min)

Fichier : `docs/specs/spec-administrateur-reseau.md` (974 lignes au début de #114).

### 3.1 — Sections à ajouter ou amender

**Section §Q1 (cooptation, destinataires)** : ajouter le raffinement du 14/05 — « proposeur notifié uniquement au 1er vote, silencieux après ».

**Section §Q5 (cooptation_rejected)** : compléter avec la doctrine §4.2 :
- Rationale opposé diffusé seulement si disclose_identity=true ET vote='opposed'.
- Texte target_intro standard : « décision collective et politique, non personnelle ».

**Section §Q6 (cooptation_reminder)** : ajouter doctrine §4.4 :
- 2 mails distincts : retardataires reçoivent `.intro`, proposeur reçoit `.proposer_intro`.
- Job cron J+14 et J+25, payload contient `pending_voters[]` pour fan-out.

**Section §Q7 (collective_removal_*)** : ajouter :
- Symétrie avec cooptation : proposeur notifié uniquement au 1er vote.
- `was_unanimous` flag dans `cancelled` event : détermine si target est notifié de l'annulation.
- `executed_at` calculé côté EF (pas dans payload).

**Section nouvelle §Q8 (RGPD post-removal)** : noter que l'export des contributions d'un admin retiré est **hors périmètre #114** (chantier futur potentiel).

### 3.2 — Changelog spec

Ajouter en tête du fichier :
```markdown
## Changelog
- v0.3.1 (2026-05-15) — Implémentation complète #114.A + #114.B. Doctrines §4.1-4.8 figées suite à session 14/05/2026.
```

### 3.3 — Commit

```powershell
git add docs/specs/spec-administrateur-reseau.md
git commit -m "docs(spec): admin reseau v0.3.1 - doctrines 114.B figees + raffinements"
git push
```

---

## 4. Phase 7 — Cleanup final et mémoires (15 min)

### 4.1 — Mettre à jour le backlog v10 → v11

Items à **retirer** (résolus aujourd'hui) :
- #114.B (clos)
- #114.C — implémenté en réalité dans #114.B (le retrait collectif faisait partie du même chantier)

Items à **mettre à jour** dans le récap mémoire :
- Chantier #114 entièrement clos
- 10 sous-handlers déployés et validés E2E
- Doctrine admin réseau v0.3.1 figée

### 4.2 — Mise à jour `userMemories` Claude

Memory edit à ajouter :
> AnarBib chantier #114 ENTIÈREMENT CLOS 2026-05-15. 10 sous-handlers network.* déployés : cooptation_proposed/voted (114.A) + cooptation_rejected/completed/reminder (114.B-3a) + collective_removal_proposed/vote_cast/unanimous/cancelled/executed (114.B-3b/3c). Tests E2E validés sur 6 scénarios. Spec admin réseau v0.3.1 figée. Raffinement final : proposeur notifié uniquement au 1er vote pour cooptation_voted ET collective_removal_vote_cast.

Memory edit à supprimer (obsolète) :
> Le bullet point listant #114.B et #114.C dans la liste des items ouverts (si présent).

### 4.3 — Note décision session

Créer `docs/decisions/SESSION_2026-05-14_2026-05-15_cloture_114.md` synthétisant :
- Spec d'implémentation #114.B en début de session 14/05
- 7 phases enchaînées (audit DB, i18n, code 3a/3b, hotfix 3c, tests fumée, tests E2E, spec update)
- Bugs rencontrés et résolus (placeholder targetName/proposedName, encodage UTF-8 résiduels)
- Doctrine finale figée

---

## 5. Risques et alertes pour cette reprise

### 5.1 — Risque : bypass cooptation pour setup test

L'INSERT manuel dans `network_administrators` court-circuite le workflow politique de cooptation. C'est **acceptable pour les tests** mais ne doit JAMAIS être fait en production. Bien isoler les actions de test (commenter clairement, faire dans une session SQL identifiée).

### 5.2 — Risque : mails massifs en cas de boucle

Si un test génère 4-5 events successifs avec 4 admins actifs, on peut avoir 16-20 mails partis vers `anarbib@proton.me`. **Préparer Proton à recevoir un afflux** (vérifier qu'aucune règle de filtrage agressive n'est en place).

### 5.3 — Risque : `pg_cron` désactivé pour `cooptation_reminder` et `collective_removal_execute`

Selon les mémoires, les jobs cron sont inactifs jusqu'à activation manuelle. Pour les scénarios 3 et 4-7, on lance les fonctions directement (`SELECT public.fn_cron_*`), pas via le scheduler. **Ne pas activer le cron pendant les tests** pour éviter exécutions imprévues.

### 5.4 — Risque : un mail réel pourrait partir vers Rafael ou Arthur

Les profils Rafael LIMA et Arthur SAMPAIO sont de vrais profils de test mais avec de vraies adresses email potentiellement. **Vérifier avant test** :
```sql
SELECT id, email FROM profiles WHERE id IN (
  'a7335128-c741-4f69-b9ff-b48ac92e575a',
  '614d887d-4e8d-401d-a208-77c56a1cd5ea'
);
```
Si l'email est un vrai mail externe, soit on change leur email vers `anarbib@proton.me` le temps des tests, soit on prend d'autres targets factices.

---

## 6. Ordre suggéré pour la reprise

**Session de 4h** :
1. (10 min) Lire ce prompt + vérifier que Woodpecker est bien vert sur les 6 commits.
2. (15 min) Setup admins temporaires (§2.1) + vérification emails targets (§5.4).
3. (45 min) Scénario 1 : cooptation completed.
4. (45 min) Scénarios 2a et 2b : cooptation rejected (avec et sans disclose).
5. (30 min) Scénario 3 : cooptation reminder J+14.
6. (45 min) Scénario 4 : retrait collectif executed.
7. (30 min) Scénarios 5 et 6 : retrait collectif cancelled.
8. (15 min) Cleanup §2.8.
9. (30 min) Spec admin réseau v0.3.1 §3.
10. (15 min) Mémoires + note décision §4.

**Session de 6h** : ajouter 1h de marge pour bugs imprévus + 1h pour explorer le cas pathologique du `?` proposeur dans `vote_cast` si on veut le corriger via enrichissement payload DB (similaire à étape 1 de #114.B).

---

## 7. Référents utiles pour la reprise

- **Spec implementation #114.B** : `docs/specs/spec-implementation-114b-network-restants.md`
- **Spec admin réseau** : `docs/specs/spec-administrateur-reseau.md` v0.3
- **Fichier handler** : `supabase/functions/_shared/domain/network.ts` (1286 lignes après hotfix 3c)
- **Fichier i18n** : `supabase/functions/_shared/i18n/mail-strings.ts`
- **Project Supabase** : `uflwmikiyjfnikiphtcp` (sa-east-1)
- **Repo** : `C:\Users\accat\Claude's AnarBib\anarbib-app\`

### User IDs pour tests

| Personne | UUID | Rôle test |
|---|---|---|
| Xavier | `d6710372-e5e5-4608-800b-99a26817c677` | Admin permanent, proposeur |
| Lívia GUSMÃO VASCONCELOS | `366cdc4e-10e0-44ad-8554-a444bcf9607a` | Admin temporaire votant |
| Patricia FELLINI | `2a42b6bd-d159-4ee0-b66b-28a03062232b` | Admin temporaire votant |
| Rafael LIMA | `a7335128-c741-4f69-b9ff-b48ac92e575a` | Target test (cooptation completed + retrait) |
| Arthur SAMPAIO | `614d887d-4e8d-401d-a208-77c56a1cd5ea` | Target test (cooptation rejected) |

---

**FIN — Une fois cette reprise terminée, le chantier #114 est définitivement clos et la spec admin réseau passe en v0.3.1.**
