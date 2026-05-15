# Session 15/05/2026 — Refonte specs + Paquet A profils + QA consultations

**Date :** 15 mai 2026
**Durée totale :** matinée + début d'après-midi (~6h)
**Acteur·rices :** Xavier (lead dev) + Claude (assistant·e)
**Contexte :** prolongement de la session 14/05 (clôture paquet 27 consultas + chantier #114 mails admin réseau). Xavier a dormi une nuit entière entre les deux sessions.

---

## Sommaire

1. [Refonte de 4 specs](#1-refonte-de-4-specs)
2. [Cleanup biblio FRT](#2-cleanup-biblio-frt)
3. [Paquet A profils d'adoption](#3-paquet-a-profils-dadoption)
4. [QA manuelle consultations](#4-qa-manuelle-consultations)
5. [Leçons techniques](#5-leçons-techniques)
6. [Items pour le backlog v13](#6-items-pour-le-backlog-v13)
7. [Bilan et prochaines étapes](#7-bilan-et-prochaines-étapes)

---

## 1. Refonte de 4 specs

**Décision politique** : aligner toutes les specs sœurs sur l'état réel du système en production au 14/05/2026 (chantier admin réseau clos, chantier consultas clos), avec inscription explicite des raffinements doctrinaux figés en cours d'implémentation.

### 1.1. Spec admin réseau v0.3 → v0.3.1 (1037 lignes)

**7 raffinements R1-R7 inscrits** :
- R1 : Proposeur notifié au 1er vote uniquement (`voteCount === 1`)
- R2 : Rationale opposed diffusé conditionnellement selon `disclose_identity=true`
- R3 : `cooptation_reminder` = 2 mails distincts (retardataires `.intro` / proposeur `.proposer_intro`)
- R4 : `collective_removal_cancelled` selon flag `was_unanimous`
- R5 : `executed_at` calculé par l'Edge Function (pas par trigger DB)
- R6 : `disclose_identity` sans DEFAULT (choix politique conscient)
- R7 : Cosmétique `?` pour `vote_cast` orphelin

### 1.2. Spec consultas v2 → v2.1 (1083 lignes)

**6 raffinements R1-R6 inscrits** + toutes phases marquées closes :
- R1 : Invariant `schedule_missing` (créneau complet obligatoire)
- R2 : Helper partagé `src/lib/scheduleFormat.js`
- R3 : Workflow de reproposition après refus (cycle libre)
- R4 : Bouton no-show conditionné temporel (3 critères simultanés)
- R5 : Principe SIGB de notification (notifier celui qui n'a pas initié)
- R6 : Phase 6 E2E reportée au profit de QA manuelle (réalisée ce jour)

### 1.3. Spec gouvernance v1.0 → v1.1 (1379 lignes)

**Refonte cohérence post-paquet F admin réseau** :
- Rôle `administrador` local supprimé du schéma (3 rôles locaux désormais : `reader`, `librarian`, `coordenador`)
- Nouvelle section §1.4 : périmètre d'activation = mode `governance_mode = 'full_governance'` de la spec profils v0.3
- Nouvelle section §6.11 : RPC `fn_team_*` conditionnées par `governance_mode` (à activer au paquet F profils)
- Branche « last admin lockdown » supprimée au paquet F.3, escalade vers admins réseau
- §11 RPC actualisée avec statut d'implémentation : Lots 1-3 livrés partiellement, Lots 4-7 en attente

### 1.4. Spec onboarding v1.0 → v1.1 (823 lignes)

**Workflow unanime + volet 0 profils** :
- §5 entière refondue : « validation à deux yeux » → « votes à l'unanimité avec `disclose_identity` »
- §6.2 nouvelle : volet 0 du wizard (choix du profil d'adoption sur 4 axes orthogonaux)
- §6.3 : volets 1-10 conditionnés par les choix du volet 0
- §3.1 nouvelle table `library_request_votes` symétrique aux votes admin réseau
- 17 events (vs 16 en v1.0) — préfixe `onboarding.*` uniformisé

### 1.5. Trio cohérent

Au sortir de cette refonte, les 4 specs forment un **socle doctrinal cohérent** :

```
spec-administrateur-reseau v0.3.1  ←  autorité transverse, cooptation unanime
            ↓
spec-gouvernance-roles v1.1         ←  rôles locaux, conditionnée par governance_mode
            ↓
spec-flux-consultations v2.1        ←  workflow utilisant les helpers d'autorisation
            ↑
spec-onboarding-biblioteca v1.1     ←  intègre admin réseau (workflow unanime)
                                       et profils v0.3 (volet 0)
```

Tous les commits poussés sur Codeberg + GitHub via `origin`.

---

## 2. Cleanup biblio FRT

**Décision** : suppression définitive de la biblio test FRT (créée 8 avril, `is_active=false`, 0 donnée métier) avant le démarrage du paquet A profils, pour éviter qu'une biblio mal configurée ne contredise les DEFAULTs maximalistes.

**Vérifications préalables** :
- 0 ligne dans 10 tables liées (memberships, holdings, emprunts, réservations, consultas, etc.)
- 2 lignes de config par défaut (`library_commons` + `library_service_state`) à supprimer en CASCADE

**Exécution** : script SQL `cleanup-frt-2026-05-15.sql` exécuté manuellement dans Supabase SQL Editor en transaction `BEGIN`/`COMMIT` avec DO-blocks de vérification pré et post. Pas de migration formelle (action ponctuelle).

**Résultat** : prod nettoyée, 2 biblios actives (BLMF + BTL). Note de décision commitée dans `docs/decisions/CLEANUP_FRT_2026-05-15.md`. Trace SQL commitée dans `tests/sql/cleanup-frt-2026-05-15.sql`.

---

## 3. Paquet A profils d'adoption

### 3.1. Contenu livré

**Migration** : `supabase/migrations/20260515170000_paquet_A_profils_infrastructure.sql`

1. **4 colonnes orthogonales** sur `libraries` :
   - `catalog_mode` ∈ {`local_only`, `network_published`}
   - `circulation_mode` ∈ {`off`, `informal`, `full_sigb`}
   - `network_mode` ∈ {`isolated`, `observer`, `federated`}
   - `governance_mode` ∈ {`informal`, `staff_roles`, `full_governance`}
   - DEFAULTs maximalistes = profil D (zéro régression sur BLMF + BTL)

2. **2 contraintes CHECK croisées** :
   - `chk_catalog_published_requires_network` : si publication réseau, alors network observable ou fédéré
   - `chk_full_sigb_requires_roles` : si circulation complète, alors rôles staff différenciés

3. **Table `library_profile_history`** immutable :
   - Audit des transitions de profil
   - 2 triggers anti-UPDATE / anti-DELETE
   - RLS readonly pour le staff (helper centralisé `user_can_act_as_staff_on_library`)

4. **5 colonnes sur `library_requests`** (table existante, ajout sans CHECK car validation à l'acceptation) :
   - `requested_catalog_mode`, `requested_circulation_mode`, `requested_network_mode`, `requested_governance_mode`
   - `profile_template_chosen` (A / B / C / D / custom — champ statistique)

5. **10 helpers SQL** (`STABLE SECURITY DEFINER`, `GRANT EXECUTE TO anon, authenticated`) :
   - 4 lecteurs : `fn_library_{catalog,circulation,network,governance}_mode`
   - 6 prédicats : `fn_library_has_circulation`, `fn_library_has_full_sigb`, `fn_library_publishes_catalog`, `fn_library_is_federated`, `fn_library_uses_governance`, **`fn_library_has_staff_roles`** (10e helper validé en session 15/05)

6. **DO-block de vérification finale** : confirme post-migration que BLMF + BTL sont en profil D, contraintes actives, helpers fonctionnels, table audit créée, signup enrichie.

### 3.2. Tests d'acceptation

**Fichier** : `tests/sql/paquetA_profils_tests.sql` — **15 tests d'acceptation**.

Pipeline Woodpecker vert. Tests exécutés manuellement dans Supabase SQL Editor : **15/15 OK** en version 2 (cf. leçon technique §5.1).

### 3.3. Décisions politiques inscrites au passage

**`fn_library_has_staff_roles`** (10e helper) : distinction entre deux questions politiques :
- « Y a-t-il des rôles staff différenciés ? » → TRUE pour `staff_roles` ET `full_governance`
- « Y a-t-il la doctrine intégrale de gouvernance ? » → TRUE seulement pour `full_governance`

Les deux questions méritent deux helpers distincts pour permettre aux RLS et RPC d'être précises sans ambiguïté politique.

---

## 4. QA manuelle consultations

**Cadre** : alternative aux tests E2E Playwright (reportés selon spec consultas v2.1 §11.2 R6), checklist 9 scénarios + 1 sous-scénario.

**Résultat global** : workflow opérationnel bout-en-bout, mais **7 bugs et 5 décalages spec ↔ prod** identifiés.

### 4.1. Bugs fonctionnels détectés

| ID | Scénario | Sévérité | Description |
|---|---|---|---|
| **B1** | 3, 6 | 🔴 Haute | Mail proposition créneau mal formaté : `"16/05/2026, das às às às (UTC)"`. Placeholder cassé dans template i18n. |
| **B2** | 2 | 🟠 Moyenne | Mail `em_preparacao` non envoyé au lecteur·rice (trigger ou handler manquant) |
| **B3** | 6 | 🟠 Moyenne | Mail de refus créneau ne contient pas le motif rédigé par le lecteur·rice |
| **B4** | 6 | 🟡 Mineure | Pas de pastille rouge « Recusado » côté lecteur après refus (bloc bleu disparaît mais sans feedback visuel persistant) |
| **B5** | 7 | 🟠 Moyenne | Mail no-show non envoyé au lecteur·rice |
| **B6** | 9 | 🔴 Haute | Annulation biblio sans modal ni note obligatoire (contradiction spec v2.1 §6.2/§8.1) |
| **B7** | 9 | 🔴 Haute | Bouton « Accuser réception » (dismiss) côté lecteur ne fonctionne pas : `dismissed_by_reader_at` reste `null` après clic |

### 4.2. Décalages spec ↔ prod (à documenter)

| ID | Description | Décision |
|---|---|---|
| **D1** | Onglet historique inexistant dans PanelPage (toutes consultas dans le même onglet) | Ajouter au chantier UX général ou aligner la spec en v2.2 |
| **D2** | Workflow stage ne s'affiche pas côté lecteur dans `/conta` (seul « ativa » + bouton « Cancelar » visibles) | Mineur, à ajouter au backlog |
| **D3** | Mail de réception envoyé au lecteur·rice à la création (contradiction principe SIGB R5) | **Décision politique** : on garde — c'est un accusé de réception légitime. Doctrine à amender en v2.2 : SIGB R5 admet exception « accusé de réception explicite » |
| **D4** | Mail à la biblio au scénario 3 (proposition créneau) : traçabilité coordination | Bonne pratique en place, à inscrire dans la spec v2.2 |
| **D5** | `consulta_mail_realizada_enabled = false` par défaut | Cohérent avec principe « lecteur·rice était présent·e » — à documenter |
| **D6** | Spec v2.1 §7.5 mentionne 3 toggles globaux, prod en a 8 (6 fins par event + 2 transverses) | La prod est meilleure que la spec — à corriger en v2.2 |

### 4.3. Doctrine politique émergée pendant la QA

**Distinction traçabilité individuelle vs traçabilité collective** (réflexion à partir du scénario 9) :

Le principe SIGB R5 (« on notifie qui n'a pas initié ») s'applique à la **personne qui clique**, mais ne couvre pas la **mémoire collective de la coordination**. Dans une biblio militante avec gouvernance horizontale, les autres coordenadores doivent pouvoir voir l'action a posteriori sans avoir à ouvrir le panel.

**Distinction à formaliser dans spec v2.2 (et probablement v2.1 admin réseau aussi)** :
- **Notification individuelle au destinataire principal** : selon principe SIGB R5
- **Trace coordination collective** : à `library_commons.coordination_email` (ou `library_email`) pour toutes les actions initiées par le staff biblio sur des consultas

Le toggle `admin_copy_consultas_enabled = true` est probablement le mécanisme correct, à vérifier que le handler `consultas.ts` l'exploite bien.

---

## 5. Leçons techniques

### 5.1. Tests SQL en transaction `BEGIN`/`ROLLBACK`

**Problème rencontré** : la première version des tests paquet A modifiait BLMF dans le test 5 (`UPDATE catalog_mode = 'local_only'`) en s'appuyant sur le ROLLBACK final pour restaurer l'état. Mais les tests 11 et 12 lisaient l'état **modifié intra-transaction**, et échouaient.

**Cause** : dans une transaction PostgreSQL, les statements suivants voient les modifications des statements précédents (c'est le standard SQL). Le ROLLBACK final restaure l'état pré-transaction côté base réelle, mais ne rétroagit pas sur la lecture en cours de transaction.

**Solution adoptée (v2 des tests)** : tout test qui modifie l'état réel doit le **restaurer immédiatement dans le même DO-block**, même si la transaction est censée rollback à la fin.

**Doctrine à inscrire dans la mémoire technique** :
> Pour les tests SQL d'acceptation en transaction `BEGIN`/`ROLLBACK`, ne jamais s'appuyer sur le ROLLBACK final pour annuler les modifications intermédiaires lues par les tests suivants. Restaurer dans le même DO-block, ou utiliser des données fictives (INSERT temporaire).

### 5.2. Migration paquet A : DEFAULTs maximalistes pour zéro régression

**Stratégie** : choisir comme DEFAULT pour les 4 colonnes profil les valeurs les plus permissives (`network_published`, `full_sigb`, `federated`, `full_governance`), correspondant au profil D « bibliothèque-monde ». Conséquence : les 2 biblios existantes (BLMF + BTL) héritent automatiquement de ce profil sans aucun changement fonctionnel.

**Avantage** : la migration paquet A est **politiquement neutre** sur l'existant. Tous les comportements actuels restent identiques, et les biblios pourront choisir leur profil ultérieurement (paquet B + UI paquet C).

**Risque évité** : si on avait mis `NULL` comme DEFAULT, il aurait fallu un script de migration des données existantes — source d'erreurs.

### 5.3. Articulation inter-specs : trio de référence

**Doctrine** : pour un système politique distribué comme AnarBib, les specs ne sont pas autonomes — elles forment un graphe d'articulations. La modification d'une spec doit déclencher une revue de cohérence sur ses sœurs.

**Pattern observé** : la livraison du chantier admin réseau (paquets A-F + #114) a invalidé partiellement 4 autres specs (gouvernance, consultas, onboarding, profils). La refonte collective de ce matin a restauré la cohérence.

**Doctrine à inscrire** :
> Toute évolution majeure d'une spec impose un audit de cohérence sur les specs articulées. Inscrire dans le sommaire de chaque spec ses dépendances explicites (qui en dépend, de qui elle dépend).

### 5.4. QA manuelle vs tests E2E automatisés

**Confirmé empiriquement** : la QA manuelle a détecté **7 bugs fonctionnels** que les tests SQL d'acceptation (qui passent à 15/15) ne pouvaient pas détecter. Les bugs touchent l'UI (boutons cassés), les mails (templates i18n), les triggers manquants, le respect des invariants politiques (note obligatoire annulation).

**Conclusion** : la décision de spec v2.1 §11.2 R6 de remplacer Phase 6 E2E par une QA manuelle est validée. La QA manuelle a un coût (1h ici) mais une valeur élevée pour détecter les écarts entre intention politique (spec) et implémentation (code).

**À inscrire dans la doctrine du projet** :
> Une QA manuelle structurée après chaque livraison majeure de feature est plus précieuse que des tests E2E partiels et fragiles. Documenter les résultats dans `docs/decisions/QA_MANUELLE_*.md`.

---

## 6. Items pour le backlog v13

À ajouter dans la prochaine version du backlog :

### Bugs (chantier dédié « patches consultas », ~1 journée)

- **#130 — B6 annulation biblio sans note obligatoire** (score 18 — politique élevé, contradiction spec)
- **#131 — B1 mail proposition créneau mal formaté** (score 17 — visible côté lecteur·rice)
- **#132 — B7 dismiss côté lecteur ne fonctionne pas** (score 17 — bouton inutile en prod)
- **#133 — B3 motif refus pas dans le mail biblio** (score 14)
- **#134 — B5 mail no-show non envoyé** (score 13)
- **#135 — B2 mail `em_preparacao` non envoyé** (score 12)
- **#136 — B4 pastille rouge « Recusado » manquante côté lecteur** (score 9)

### Décalages spec / amélioration UX (chantier dédié « UX consultas v2 », ~3 jours)

- **#137 — D1 onglet historique PanelPage** (score 14 — UX importante)
- **#138 — D2 workflow stage côté lecteur·rice** (score 11)
- **#139 — Spec consultas v2.2** : amender §7.5 (8 toggles), §11.2 (R7 nouvelle exception SIGB pour accusé de réception, R8 doctrine traçabilité coordination distincte) (score 8 — doc)

### Hygiène et trace

- **#125 — Note décision session 15/05** (cette note, à commiter)
- **#140 — Aligner spec admin réseau v0.3.2 avec doctrine traçabilité coordination** (score 6, doc à amender si confirmée pour consultas v2.2)

---

## 7. Bilan et prochaines étapes

### 7.1. Récap chiffré de la session 15/05

| Métrique | Valeur |
|---|---|
| Specs refondues | 4 (~4322 lignes) |
| Backlog actualisé | v11 → v12 (et bientôt v13 avec items QA) |
| Migrations DB appliquées | 1 (paquet A profils) |
| Tests SQL d'acceptation | 15/15 OK |
| Cleanups DB ponctuels | 1 (biblio FRT) |
| Commits poussés | 6 (3 sprint hygiène + 1 cleanup trace + 1 paquet A migration + 1 tests v2 + cette note à venir) |
| Bugs détectés en QA | 7 |
| Décalages spec ↔ prod documentés | 6 |

### 7.2. État du système en fin de session

- **Repo** : working tree clean, tous commits poussés sur Codeberg + GitHub
- **Prod** : BLMF + BTL en profil D, 10 helpers profils en place, table `library_profile_history` prête, 5 colonnes signup en attente
- **Specs** : 4 refondues alignées sur la prod, spec profils v0.3 inchangée (correcte)
- **CI/CD** : Woodpecker vert

### 7.3. Chemins possibles pour la prochaine session

| Option | Effort | Description |
|---|---|---|
| **A** | ~1 jour | Chantier patches consultas (B1-B7) |
| **B** | 3 jours | Paquet B profils (fonctions de transition + carences + crons) |
| **C** | 3-4 jours | Migration mail Brevo → Resend (#110, indépendant) |
| **D** | 3 jours | Chantier UX consultas v2 (D1, D2 + autres décalages) |

**Recommandation** : prioriser **A (patches consultas)** parce que les bugs sont identifiés frais et que la QA donne un cahier des charges précis. La fenêtre de motivation est bonne pour cleaner ces 7 bugs en une session.

Si A est fait, l'enchaînement naturel serait ensuite **B (paquet B profils)** ou **C (Resend)** selon l'énergie disponible.

### 7.4. Décisions reportées

- **Niveau 2 et 3 d'urgence sur les bugs consultas** : pas de patch en fin de session 15/05, choix de niveau 1 (documenter et clôturer)
- **Spec consultas v2.2** : à rédiger lors du chantier UX consultas v2, pour amender §7.5 et §11.2

---

*Session 15/05/2026 close en fin d'après-midi. Bonne session productive : refonte doctrinale + livraison technique + QA approfondie. Toute la chaîne politique → spec → code → vérification empirique a été parcourue. Le système est dans un état stable et bien documenté.*
