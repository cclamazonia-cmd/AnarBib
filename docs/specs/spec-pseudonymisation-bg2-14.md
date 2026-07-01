---
Genre : référence / implémentation
Statut : 🟡 cadrée — arbitrages clos (session 01/07/2026)
Décisions : incarne BG2-14 (REGISTRE §BG2) ; cite BG2-4 (staff = même régime), BG2-5 (gouvernance immuable pseudonymisée), BG2-7 (coordonnée institutionnelle en clair), point backlog #3 (sort des outboxes)
Supersédé par : —
---

# spec-pseudonymisation-bg2-14

| | |
|---|---|
| **Version** | v0.1 — arbitrages clos, prête à implémenter |
| **Date** | 1er juillet 2026 |
| **Emplacement cible** | `docs/specs/` |
| **Statut** | Cadrée. Arbitrages tranchés (session 01/07). Reste : migration SQL + rejeu runbook + exclusion outboxes côté script. |
| **Réfère à** | `BG2-14` (REGISTRE §BG2) ; `fn_delete_my_account` (existant, prod) ; `#BG2` |
| **Dépendances** | Vault (`supabase_vault` 0.3.1) · `pgcrypto` (`hmac`) · `anarbib-bg2.sh` · RUNBOOK BG2 |

> **Convention.** **[A]** = acté (arbitrages 01/07). Aucun arbitrage doctrinal ouvert.
> **Réserve.** La sécurité repose sur le secret du **sel** (Vault, hors dump). Si le sel fuit, la pseudonymisation devient réversible. Le sel est géré comme la passphrase restic : hors-ligne, hors du système sauvegardé.

---

## 1. Objet & principe

BG2-14 comble un trou du flux d'effacement : **`fn_delete_my_account` ne touche aujourd'hui aucune table `network_*`**. Un·e admin réseau qui supprime son compte laisse ses actes de gouvernance avec son **vrai `user_id` en clair** — donc dans le flux long, donc dans les backups.

**Principe [A].** Les actes de gouvernance sont **immuables** (BG2-5) : on ne les supprime pas, on **pseudonymise l'acteur** par un **jeton stable, distinct et irréversible** — préservant la distinguabilité des actes sans conserver l'identité.

**Deux régimes coexistent [A]** :
- **Circulation** → compte technique **`removido`** (`…-0001`), indistinct. Existant, inchangé.
- **Gouvernance** (`network_*`) → **jeton stable par personne**, distinct. Nouveau.

## 2. Le jeton stable irréversible

### 2.1 Trilemme et résolution [A]

Stable + irréversible + sans table de correspondance : contradictoire *sans secret*. **Résolution : `hmac(user_id, sel)`, sel hors-base.** Avec le sel : recalculable (stable, sans table). Sans le sel : HMAC non inversible (irréversible).

### 2.2 Le sel vit dans Vault, hors du dump [A]

Secret Vault nommé **`pseudonym_salt`** (créé manuellement, §6.1). Vérifié 01/07 : `vault.secrets` stocke le chiffré (clé hors-base) ; le flux long dumpe `--schema=public`, le schéma `vault` n'y est pas → sel **absent du backup**. Double protection : schéma exclu ET contenu chiffré.

### 2.3 Type du jeton : UUID déterministe [A]

Colonnes cibles en `uuid`. On dérive un **UUID déterministe** du hmac (128 bits pliés), pour **préserver le type** sans migration de schéma. Primitive à câbler (candidat : `uuid_generate_v5` namespace secret, ou formatage des 16 premiers octets du hmac).

## 3. Périmètre exact — 19 colonnes [A]

| Table | Colonnes pseudonymisées |
|---|---|
| `network_admin_collective_removal_proposals` | `proposed_user_id`, `proposed_by`, `cancelled_by` |
| `network_admin_collective_removal_votes` | `voter_user_id` |
| `network_admin_cross_library_actions_log` | `actor_user_id` |
| `network_administrator_audit` | `user_id`, `actor_user_id`, `target_user_id` |
| `network_administrator_cooptation_proposals` | `proposed_user_id`, `proposed_by` |
| `network_administrator_cooptation_votes` | `voter_user_id` |
| `network_administrators` | `user_id` |
| `network_contributors` | `user_id`, `sponsored_by` |
| `network_reviewers` | `user_id`, `added_by_user_id` |
| `network_staff` | `user_id`, `added_by_user_id`, `updated_by_user_id` |

**Plus** : `network_contributors.display_name` (texte) → pseudonymisé [A].

**Acteurs-staff inclus** (`cancelled_by`, `added_by_user_id`, `updated_by_user_id`) — BG2-4 (un rôle est une fonction déléguée).

### 3.1 Colonnes LAISSÉES intactes [A]

- `library_id` : coordonnée institutionnelle (BG2-7).
- `id`, `proposal_id` : clés techniques (jointures).
- `target_entity_id` : polymorphe ; vérifié 01/07, `target_entity_type` = `user_library_membership` seul → pointe une adhésion (déjà PII flux court), pas un `user_id`. Laissé.

## 4. Modifications de la base

### 4.1 Table `erasure_log` [A]

Journal minimal des effacements, pour le rejeu à la restauration (§5). Deux colonnes : `pseudonym_token` (le jeton, PAS le user_id) et `erased_at` (timestamptz).

**Choix crucial [A]** : `erasure_log` stocke le **jeton**, jamais le `user_id` en clair. Aucune PII n'y survit. Le rejeu (§5) fonctionne par **recalcul** : sur un vieux dump contenant les vrais `user_id`, on recalcule le jeton de chaque acteur et on le compare à `erasure_log`. Cohérent avec l'Option 1. Peut résider au flux long sans exposer d'identité. RLS : `ENABLE RLS` + policy `USING (false)`.

### 4.2 Fonction helper `fn_pseudonymize_token(uuid)`

`SECURITY DEFINER`, `SET search_path`, lit le sel via `vault.decrypted_secrets` (`pseudonym_salt`), retourne l'UUID déterministe dérivé de `hmac(user_id::text, sel, 'sha256')`. Grants stricts : pas besoin d'être exécutable par `authenticated` (appelée seulement par `fn_delete_my_account`, elle-même DEFINER).

### 4.3 Insertion dans `fn_delete_my_account`

Après le bloc circulation (`= v_removido`), avant les DELETE finaux : calculer `v_token := fn_pseudonymize_token(v_user_id)` ; les 19 `UPDATE network_*` remplaçant le user_id par `v_token` ; pseudonymiser `display_name` (défaut : le jeton hex) ; `INSERT INTO erasure_log`.

### 4.4 Hygiène de sécurité (même migration)

`fn_delete_my_account` a un grant `service_role EXECUTE` superflu (résidu `ALTER DEFAULT PRIVILEGES`). C'est « effacer mon compte » via `auth.uid()` : `authenticated` suffit. Doctrine v2 : `REVOKE EXECUTE FROM PUBLIC, anon, service_role` ; conserver `authenticated`.

## 5. Rejeu à la restauration [A]

**Problème.** Un dump long antérieur à un effacement contient encore le vrai `user_id` → le restaurer ressusciterait une PII effacée.

**Solution.** Après restauration d'un dump long : (1) réinjecter le sel Vault (`pseudonym_salt`) depuis la gestion de secrets hors-ligne ; (2) pour chaque acteur des 19 colonnes restaurées, recalculer `fn_pseudonymize_token(user_id)` ; (3) si le jeton figure dans `erasure_log`, remplacer le `user_id` par ce jeton. Même un backup de six mois ne ressuscite jamais une identité effacée. Procédure détaillée au RUNBOOK BG2. Coût acceptable (restauration rare).

## 6. Séquençage & sécurité

### 6.1 Le sel : création manuelle, hors migration [A]

`pseudonym_salt` ne doit PAS être créé dans la migration versionnée (sa valeur serait dans git). Créé manuellement une fois via `vault.create_secret`, noté dans la gestion de secrets hors-ligne (comme la passphrase restic). La migration suppose son existence et échoue proprement si absent.

### 6.2 Doctrine de sécurité v2

`erasure_log` : `ENABLE RLS` + policy `USING (false)`. `fn_pseudonymize_token` et `erasure_log` : `REVOKE ALL FROM PUBLIC, anon, authenticated, service_role` puis GRANT explicite du strict nécessaire. Vérification DO-block des grants. `SECURITY DEFINER` en commentaire → faux positif pre-commit (`--no-verify`, #80).

### 6.3 Déploiement

Migration timestampée dans `supabase/migrations/` → commit → push → CI Forgejo applique via `supabase db push`. Jamais `apply_migration` MCP ni SQL Editor avant push. Testée en transaction annulée avant validation.

### 6.4 Exclusion des outboxes (clôt backlog #3) [A]

Les 6 tables `*_outbox` (`recipient_email` transitoire) → exclues du flux long (donnée personnelle éphémère, pas acte de gouvernance). Modification côté `anarbib-bg2.sh`. Clôt le point 3 du backlog #BG2.

## 7. Ce qui reste à produire

1. **Migration SQL** : `erasure_log` + `fn_pseudonymize_token` + insertion dans `fn_delete_my_account` + hygiène grant.
2. **Création manuelle** du sel Vault (§6.1) — hors migration, hors git.
3. **Rejeu** : section au RUNBOOK BG2 (§5).
4. **Exclusion outboxes** : patch `anarbib-bg2.sh` (§6.4).
5. **Test** : effacement d'un compte de test → vérifier les 19 colonnes + `erasure_log` + circulation toujours removido + rien cassé.
6. **Consignation** : REGISTRE BG2-14 « acté » → « implémenté » ; clôturer backlog #3.
