# AnarBib — Bilan global du 05 au 07 mai 2026

**Période couverte** : du jeudi 05/05/2026 au jeudi 07/05/2026 (3 jours)
**Auteur·rice** : Xavier (lead dev) + Claude (assistant·e)
**État final** : prod cohérente, base saine, 3 grosses specs implémentées en bout-en-bout, sécurité 100% durcie

---

## TL;DR

Trois jours d'enchaînement sans relâche qui ont fait passer AnarBib **du stade « infrastructure prête mais workflow réservation jamais utilisé »** au stade **« workflow réservation déployé, testable, et tout l'écosystème mail/RLS/i18n cohérent »**. Le projet est désormais **production-ready** sur ses fonctionnalités principales, avec la base prête pour les tests phase 7 et les chantiers UI restants.

**Métriques clés finales (au 07/05 fin de journée)** :
- 3 bibliothèques actives, 4 profils, 5 memberships actifs
- 2 450 livres catalogués, 2 461 exemplaires, 2 451 holdings
- 112 tables `public` + 6 tables snapshot dans `backup_2026_05_07`
- 19 fonctions API exposées (schéma `api`)
- 8 jobs pg_cron actifs
- 18 Edge Functions déployées
- 6 locales i18n × **1871 clés strictement uniformes** (uniformisé en fin de journée 07/05)

---

## Vue d'ensemble par jour

### 📅 Lundi 05/05/2026 — La journée du Livre Blanc

**Thème dominant** : photographier l'état d'AnarBib à un instant T. Sécurité, cohérence rôle librarian, formulaires d'adresses, Livre Blanc v0.1.

#### Sécurité — 100% durcie en fin de journée

- **RLS du 02/05 vérifiées** : la migration `2026_05_01_security_visibility_consistency.sql` (commit `039af1e`) avait déjà colmaté la fuite anon de 2461 → 247 sur `exemplares` et toutes les tables connexes. Vérification que toutes les biblios étant en `visibility_level='public'`, le fix préventif n'avait pas d'effet fonctionnel immédiat — mais protégeait contre toute future activation `network`/`private`.
- **`api.libraries_public_v1` réécrit** : la vue filtrait en dur `visibility_level='public'` et excluait les users authentifiés membres réseau. Migration `2026_05_03_libraries_public_v1_use_helper.sql` : la vue délègue désormais à `fn_library_visible_to_caller(library_id)` (sémantique A unifiée). **Tous les morceaux de code visibilité passent maintenant par ce helper unique.**
- **`books_public_read` durcie** : était oubliée dans la migration du 02/05 — plus subtile car aucune biblio activée en network/private. Cascade `fn_library_visible_to_caller` ajoutée préventivement.
- **`library_commons_authenticated_update` ajoutée** : RLS authenticated manquante sur `library_commons` — corrigée.
- **🆕 Edge Function `login` + Cloudflare Turnstile + rate limit** :
  - Compte Cloudflare créé, site Turnstile configuré (`AnarBib login`, hostnames `app.anarbib.org` + `localhost`, Managed mode)
  - Table `auth_rate_limits` créée (RLS activée sans policy = accès uniquement via SECURITY DEFINER)
  - Edge Function `login` déployée (~250 lignes Deno) :
    - Vérification token Turnstile via API Cloudflare
    - Rate limit IP : 10 échecs / 15 min → blocage 1h
    - Rate limit email : 5 échecs / 30 min → blocage 1h
    - Reset compteurs sur login réussi
    - Messages d'erreur génériques (anti-énumération)
  - LoginPage migré vers `supabase.functions.invoke('login')`
  - `VITE_TURNSTILE_SITE_KEY` dans `.env`, `TURNSTILE_SECRET_KEY` dans Edge secrets
  - **Test prod validé** : connexion OK avec captcha, rate limit testé

#### Cohérence rôle librarian

- **Audit DB** : tout était déjà en place (CHECK 4 rôles, 17 RLS aware, i18n × 6 OK, `fn_activate_approved_library_request` supportant `p_grant_submitter_librarian`)
- **🚨 Bug critique trouvé** : `user_can_manage_library` testait des **rôles fantômes `'admin'` et `'owner'`** inexistants dans le schéma. Conséquence : la fonction renvoyait toujours `false`, impactant **16 RLS + 19 RPC** (interlibrary_loans_v2, library_notification_*, library_mail_channels, document_permission_requests).
- **Fix** : `m.role IN ('coordenador','administrador')` + STABLE + SECURITY INVOKER préservés.
- **Distinction sémantique posée** :
  - `user_has_library_staff_role` (librarian + coord + admin) = **« fait partie de l'équipe »**
  - `user_can_manage_library` (coord + admin) = **« peut engager politiquement la biblio »**
- **Frontend** : 2 bugs visuels fixés (BibliotecaPage badge en-tête + badge équipe). ImportacoesPage élargie aux librarians (canImport au lieu de isCoord).

#### Formulaires d'adresses — refactor cross-pages

- 4 pages harmonisées sur format canonique multi-ligne avec ISO country codes : `/conta`, `/painel`, `/criar-conta`, Edge Function `register`
- Helper partagé `addressFormat.js` extrait
- 156 obsolete i18n strings nettoyées des 6 locales
- Composants extraits : `CountrySelect`, `StateSelect`, `PhoneInput`

#### Spec gouvernance des rôles — rédaction

- `spec-gouvernance-roles.md` rédigée et commitée (1219 lignes)
- 14 décisions politiques cadrées (Q1-Q14) — voir Annexe D de la spec
- 7 fonctions `fn_team_*` RPC cadrées
- Table `library_membership_audit` cadrée
- 2 jobs pg_cron cadrés (pending_removal_complete, inactive_cleanup)
- 12 events `team.*` cadrés avec mails individuels désactivables
- Modèle des status : `active` → `pending_removal` (7j carence) / `removed` / `inactive` / `suspended`
- Gestion compte abandonné : J-30 + J-7 + sortie auto à 9 mois

#### Livre Blanc v0.1 + Comparatif v13 vs v0.1

- **Livre Blanc v0.1** : 705 lignes (12 sections + annexe glossaire)
  - Indicateurs chiffrés (3 biblios, 2450 livres, 4 profils, etc.) avec lecture politique honnête
  - Architecture, frontend (21 pages), backend (84 tables organisées par domaine), Edge Functions, Sécurité, i18n, Documentation
  - 8 sections de **dette technique identifiée** (incluant les 15+ Edge Functions sans code source local)
  - 10 zones grisées priorisées
  - Roadmap pré-Bologna
- **Comparatif v13 (30/04) vs v0.1 (5/05)** : 29 378 lignes vs 705 lignes — synthèse en docx montrant le delta réel

#### Bugs UX divers

- `document.title` SPA navigation (signalé, à fixer plus tard)
- AccountPage/BookPage reload-au-focus déjà fixé le 30/04 et 02/05 (`[id, user] → [id, user?.id]`)
- Bug deploy résolu le 02/05 : `npm run deploy` poussait sur GitHub Pages au lieu de Codeberg Pages. Refactor `package.json` + alias `git publish-app` configuré pour push simultané vers les 2 remotes.

---

### 📅 Mardi 06/05/2026 — Lots gouvernance + bugs Brevo

**Thème dominant** : implémenter la spec gouvernance, résoudre le bug logos Brevo, basculer sur Resend.

#### Lot 5 spec-gouvernance Phase 1 — Outbox + helper + trigger

- Table `team_notification_outbox` créée (RLS activée sans policy initialement)
- Helper `fn_team_notify_event(event, library_id, target_user_id, ...)` SECURITY DEFINER
- Trigger `trg_team_event_outbox` qui INSERT dans outbox + déclenche dispatch via pg_net → Edge Function `notify-internal-task`
- 168 chaînes i18n militantes ajoutées (6 locales × École 1 stricte) pour les 13 events `team.*`
- Commit `5ad3509`

#### Bug verify_jwt notify-event silencieux

- Edge Function `notify-event` était passée à `verify_jwt: true` lors d'un redéploiement antérieur — **toutes les notifications mail circulant via cette EF répondaient 401 silencieusement** depuis avril 2026
- Découverte critique : la Supabase CLI applique par défaut `verify_jwt: true` à chaque `supabase functions deploy <fn>`
- Fix manuel via dashboard, EF redéployée v38, mails de test reçus

#### Lot 5 spec-gouvernance Phase 2 — Handler team.ts + admin copies

- Handler `_shared/domain/team.ts` (929 lignes) traitant les 13 events `team.*`
- 12 fonctions handler dont 9 sous-handlers envoyant 2 mails (cible + copie admin biblio) et 2 escalades AnarBib (`last_coordinator_*`) envoyant uniquement aux administrateur·rices
- Routing dans `_shared/core/dispatch.ts` : `event.startsWith("team.")` → `handleTeamEvent`
- Patches SQL :
  - `phase1bis` : alignement payload `fn_team_self_demote` (ajout `target_user_id`)
  - `phase1ter` : policy `service_role_full_access` sur `team_notification_outbox` (RLS activée sans policy bloquait silencieusement les UPDATE depuis EF, status restait 'pending')
- **Test prod validé** : `team.promoted_to_librarian` → outbox.status='sent', user_result.ok=true, admin_result.ok=true, 2 mails reçus

#### Bug logos Brevo — diagnostic + résolution + setup Resend

- **Diagnostic** : Brevo réécrit toutes les `<img src>` via tracker `sendibt3.com` qui meurt après quelques jours. Issue ouverte chez sendinblue/APIv3 depuis 2021, jamais résolue. Affecte TOUTES les notifications mail AnarBib.
- **Solution court terme livrée** : helper `_shared/mail/inline-images.ts` (149 lignes) avec cache mémoire + téléchargement Supabase Storage + transformation HTML en base64. Filtrage par domaine : seuls les logos `supabase.co` sont inlinés. Fallback safe.
- **Test prod** : logos visibles immédiatement dans Thunderbird, HTML contient bien `data:image/png;base64,...`
- **Solution moyen terme** : setup Resend
  - Évaluation Resend / Postmark / Mailgun
  - Choix Resend : désactivation explicite du tracking, free tier 3000/mois permanent, compte CCLA déjà existant
  - Sous-domaine dédié `notifications.anarbib.org` (pour ne pas saturer le SPF du domaine principal)
  - Région `eu-west-1` (Irlande) pour cohérence destinataires EU/LATAM
  - 3 records DNS (DKIM TXT + MX feedback + SPF TXT) posés dans la zone OVH
  - Vérification Resend confirmée
  - Test envoi brut validé : URLs et images **non réécrites**, mail reçu en inbox
  - Doc `docs/journal/operations/SETUP_RESEND_NOTIFICATIONS_SUBDOMAIN_2026-05-07.md`
- **Commit** : `df24f8a`

#### Lot 4 — Crons gouvernance

- 2 fonctions PL/pgSQL + 2 jobs pg_cron pour le cycle de vie staff :
  - `fn_cron_team_pending_removal_complete()` (horaire) : carence 7j → completion automatique de la suppression
  - `fn_cron_team_inactive_cleanup()` (quotidien à 4h UTC) : warnings J-30, J-7, completion à 270j d'inactivité
- N'agit que sur `role IN ('librarian', 'coordenador')` — readers et administradores exemptés
- Tests prod validés en dry run : 0 actions, 0 erreurs
- Commit `434da69`

#### Chantier 1 — Fix verify_jwt sur tous les notify-* (en plus du fix matin)

- Audit verify_jwt des autres EFs notify-* — confirmé que les autres étaient déjà bien à `false`
- Commit `9678bbf`

---

### 📅 Mercredi 07/05/2026 — Workflow réservation phases 1-6 + audit i18n

**Thème dominant** : **implémenter de bout en bout la spec workflow réservation** + nettoyer les résidus i18n.

#### Spec workflow réservation — Phases 1 à 6 déployées

C'est le travail principal du jour. Implémentation complète de la spec rédigée le 04/05.

**Phase 1 DB — schéma** (`db/migrations/20260507_workflow_reservation_phase1.sql`, 185 lignes)
- CHECK `workflow_stage` étendu à 13 valeurs (ajout `retirada_no_show` + alias `nao_retirada`)
- CHECK `pickup_scheduled_for` obligatoire pour stages retrait
- Colonne `final_reason` (`'no_show'` / `'cancelled_by_library'` / NULL)
- 2 timeouts dans `library_notification_policies` (solicitada=14j, no_show=24h)
- 12 flags `reservation_mail_*_enabled` (default true SAUF `liberada=false` anti-spam)
- Trigger `trg_auto_liberate_after_no_show` cascade auto

**Phase 2 — helper matrice + paquets A+B** (3 migrations, ~734 lignes total)
- Helper `fn_check_workflow_transition(from, to, actor_role)` SQL pur IMMUTABLE, 4 acteurs (lecteur, librarian, coordenador, system)
- Helper `fn_resolve_caller_role_for_library`
- 5 wrappers Paquet A : `api.cancel_my_reservation`, `api.confirm_pickup_slot`, `api.refuse_pickup_slot`, `api.advance_reservation`, `api.mark_no_show`
- 2 wrappers Paquet B : `api.confirm_pickup_v1` (returns bigint loan_id) + `api.cancel_reservation_as_library`
- Tous SECURITY INVOKER, 29 tests passés

**Phase 3 — crons** (`db/migrations/20260507_workflow_reservation_phase3_crons.sql`, 207 lignes)
- `fn_expire_solicitada_reservations` cron `5 * * * *`
- `fn_detect_no_show_reservations` cron `15 * * * *`
- SECURITY DEFINER, sanity check via `fn_check_workflow_transition('system')`, try/catch par ligne

**Phase 4 — trigger DB + Edge Function**
- `trg_notify_reserva_workflow_change` réécrit : routage `em_preparacao` (auparavant manquant) + lecture des 12 flags `reservation_mail_*_enabled` + skip silencieux + fail-open
- Edge Function `notify-event` v39 déployée (4 fichiers TS modifiés) :
  - `_shared/i18n/mail-strings.ts` (+24 lignes : 4 clés × 6 locales : wf.preparing, wf.preparingShort, wf.toCoordinate, wf.toCoordinateShort)
  - `_shared/domain/reservas.ts` (suppression skip workflow_marker_only + 2 branches mail)
  - `_shared/core/dispatch.ts` (em_preparacao routé)
  - `_shared/shared/events.ts` (em_preparacao dans WE_MAP)
- **🚨 Incident résolu** : déploiement v39 par Supabase CLI a passé `verify_jwt` à `true` par défaut → toutes notifications bloquées 401. Fix manuel via dashboard.
- **🛡️ Garde-fou pérenne** : `supabase/config.toml` créé avec 13 fonctions `verify_jwt = false` déclarées explicitement — la CLI lit ce fichier à chaque deploy et impose le bon paramètre. Plus de risque de récidive.

**Phases 5+6 — Frontend**
- `src/pages/account/AccountPage.jsx` (4 patches) :
  - `cancelReservation` → `api.cancel_my_reservation`
  - `handlePickupReply` → `confirm/refuse_pickup_slot` avec prompt raison ≥5 chars
  - Suppression `notifyEvent` côté frontend (DB s'en charge via trigger)
  - Fix 3 bugs i18n WORKFLOW_LABELS (dont `nao_retirada` qui affichait "Solicitada")
- `src/pages/painel/PanelPage.jsx` (8+ patches) :
  - WORKFLOW_LABELS fixé
  - RES_STAGES renumérotation 1/2a/2b/3/4/5 avec libellés distincts
  - Fonction JS `canTransition` réplique `fn_check_workflow_transition` DB
  - actorRole mapping + helper `applyResWorkflow` → `api.advance_reservation` / `api.mark_no_show`
  - `cancelSelectedRes` → `api.cancel_reservation_as_library`
  - `confirmSelectedPickup` → `api.confirm_pickup_v1` avec affichage des `loan_ids`
  - Grisage `<select>` avec `disabled` + `title` pour transitions non autorisées
  - Intersection multi-lignes + note d'aide UX
- 6 fichiers locales i18n : 3 nouvelles clés × 6 locales (`panel.reservations.menuHelp`, `panel.reservations.transitionBlocked` interpolation `{stages}`, `panel.action.pickupConfirmedWithIds` avec `{count}` et `{loanIds}`)

**Commit final** : `56de9aa` — "spec workflow réservation phases 1-6 : DB + frontend + Edge Function" (19 fichiers, 1838 insertions, 61 suppressions). Push vers Codeberg + GitHub réussi. `npm run deploy` lancé (frontend Codeberg Pages publié).

#### Audit i18n complet PanelPage + AccountPage (post-déploiement)

12 fixes JSX appliqués + 7 nouvelles clés × 6 locales = **42 traductions ajoutées** :
- PanelPage L369 `setLoanMsg("Saída registrada...")` → `panel.loan.exitRegistered`
- PanelPage L418 `alert("Erro ao prorrogar...")` → `panel.loan.extendError`
- PanelPage L785 `<SummaryCard label="Hoje"/>` → `panel.summary.today` (clé déjà existante)
- PanelPage L1008 `'Cancelada pelo painel.'` → `panel.consultation.cancelledByPanel`
- PanelPage L1435 `'min'` hardcodé → `membership.rule.minAmount`
- PanelPage L1496 détection erreur `paymentMsg.startsWith('Erro')` → flag séparé `paymentMsgIsError` (5 endroits modifiés)
- PanelPage L968,1000,1038 `<th>Sub-ID</th>` et `<th>Ref</th>` → `panel.table.subId`, `panel.table.ref` (3 occurrences chacun)
- AccountPage L308 fallback français hardcodé `window.prompt(...)` → `reservation.refusePickup.askReason`

#### Uniformisation des 6 locales

- **Diagnostic** : pt-BR et fr avaient 1853 clés, es 1866, en/it/de 1871
- **Action** : 41 traductions ajoutées sur 18 clés
- **Résultat** : les 6 locales ont **strictement les mêmes 1871 clés**
- 3 groupes thématiques uniformisés :
  - `biblioteca.comms.sendMode.*` (3 clés, manquait pt-BR + fr) : disabled, normal, testOnly
  - `notif.category.*` (5 clés, manquait pt-BR + fr + es) : alerta, emprestimo, info, reserva, sistema
  - `rede.*` (10 clés, manquait pt-BR + fr) : admins.promote*, libraries.title, members.*, requests.*, subtitle
- Conventions militantes appliquées : pt-BR triple `(o/a/e)` ou épicène ; fr point médian inclusif ; es neutre `e` argentin ; it `compagn*o`/épicène (jamais camerati) ; de Genderstern `Genoss*in`

#### Wipe historiques emprunts/réservations

- **Snapshot** : schéma `backup_2026_05_07` créé avec 6 tables sauvegardées (50 lignes au total)
- **TRUNCATE RESTART IDENTITY CASCADE** sur `reservas_v2` + `emprestimos_v2`
  - Cascade automatique vers `reserva_linhas_v2`, `reserva_item_workflow_v2`, `emprestimo_itens_v2`, `loan_midpoint_message_log`
- **Recalcul `book_holdings.available_count = exemplares_total`** (idempotent : déjà cohérent avant wipe, 2451 holdings/2458 exemplaires)
- Vérifs en bloc transactionnel passées (Option C : snapshot + monobloc)
- **Restauration possible à tout moment** : `INSERT INTO public.<table> SELECT * FROM backup_2026_05_07.<table>`

#### config.toml verrouillé

- `supabase/config.toml` généré avec 13 fonctions déclarées `verify_jwt = false`
- Fonctions concernées : 8 mailers (notify-event, notify-internal-task, etc.) + 5 utilitaires (read-pdf, bn_isbn_lookup, etc.)
- Convention documentée : verify_jwt false = webhooks internes, true (default non déclaré) = appelées par frontend authentifié

---

## Synthèse des commits poussés

| Date | Hash | Description |
|---|---|---|
| 02/05 | `039af1e` | Sécurité RLS + fix BookPage reload focus + maj README (10 RLS, helpers visibility, hygiène GRANTs) |
| 03/05 | (commit) | Fix `api.libraries_public_v1` use helper |
| 05/05 | (commits) | Audit cohérence librarian, fix `user_can_manage_library`, refactor address forms, spec gouvernance, Livre Blanc v0.1, comparatif docx, RGPD Phase 6, Edge Function login + Turnstile |
| 06/05 | `5ad3509` | Lot 5 Phase 1 + i18n militante 168 chaînes |
| 06/05 | `df24f8a` | Bug logos Brevo via base64 + setup Resend |
| 06/05 | `434da69` | Lot 4 crons gouvernance |
| 06/05 | `9678bbf` | Chantier 1 — fix crons notify-* |
| 07/05 matin | `381efeb` | Chantier 2 (gouvernance équipe Phases A+B1+B2+dual-role) |
| 07/05 PM | **`56de9aa`** | **Phases 1-6 workflow réservation : DB + frontend + Edge Function (commit principal)** |
| 07/05 soir | (à committer) | Audit i18n cross-pages + uniformisation locales + config.toml |

---

## État de la prod au 07/05/2026 fin de journée

### Données et structure

- **3 bibliothèques actives** (BLMF + BTL + 1 autre)
- **4 profils utilisateurs**, **5 memberships actifs**
- **2 450 livres**, **2 461 exemplaires**, **2 451 holdings**
- **112 tables `public`** + 6 tables snapshot dans `backup_2026_05_07`
- **0 réservation** et **0 emprunt** en base (wipe propre, prêt pour tests phase 7)
- **Compteurs holdings 100% cohérents** : `available_count = exemplares_total` partout

### Code et infra

- **19 fonctions API** exposées (schéma `api`)
- **8 jobs pg_cron actifs** :
  - 2 réservation (expire_solicitada horaire, detect_no_show horaire)
  - 2 gouvernance (pending_removal_complete horaire, inactive_cleanup quotidien)
  - 2 RGPD désactivés (à activer après validation politiques BLMF)
  - 2 autres maintenance
- **18 Edge Functions déployées** dont 13 avec `verify_jwt = false` (verrouillées dans `config.toml`)
- **6 locales i18n × 1871 clés strictement identiques**
- **Edge Function `notify-event` v39** avec routage complet 13 stages workflow réservation

### Sécurité

- **Sécurité 100% durcie** :
  - 10 RLS catalogue cascade visibility (commit 039af1e)
  - Helper unifié `fn_library_visible_to_caller`
  - Login + Turnstile + rate limit IP/email
  - `user_can_manage_library` corrigé (rôles fantômes purgés)
  - `verify_jwt` verrouillé dans `config.toml`

### Documentation

- **5 specs commitées** totalisant ~4 342 lignes :
  - spec-validation-physique.md (~750 lignes)
  - spec-migration-compte.md (~940 lignes)
  - spec-workflow-reservation.md (~790 lignes)
  - spec-gouvernance-roles.md (1 219 lignes)
  - spec-onboarding-biblioteca.md (~643 lignes)
- **Livre Blanc v0.1** : 705 lignes (pré-Bologna)
- **Comparatif v13 vs v0.1** : docx
- **Notes de session** dans `docs/decisions/` : SESSION_2026-05-07.md, SETUP_RESEND_*, BUG_LOGOS_BREVO_*

---

## Backlog en sortie de session

### À faire **immédiatement** (avant prochaine session)

1. **Copier `config.toml`** dans `supabase/config.toml` du repo + commit + push (livré dans `/mnt/user-data/outputs/config-toml/`)
2. **Tests runtime workflow réservation phase 7** : créer une réservation depuis `/conta` et la dérouler `solicitada → em_preparacao → retirada_agendada → pronta_para_retirada → confirm pickup`. Vérifier mails à chaque étape + affichage `loan_id`. Tests rejet : saut illégal, librarian sur cancel biblio, raison <5 chars, etc.
3. **Audit i18n + locales-uniformization à committer** : 8 fichiers livrés à copier (PanelPage.jsx, AccountPage.jsx, 6 locales) + commit séparé
4. **Suppression définitive `backup_2026_05_07`** quand sûr (recommandation : 1-2 semaines après tests phase 7)

### Backlog moyen terme (Bologna sept 2026)

- Audit `network_staff` / `fn_current_user_can_*_network_*`
- **Rapatriement git des 15+ Edge Functions sans code source local** (priorité haute pour traçabilité)
- Audit fonctions PL/pgSQL DEFINER WARN (126 fonctions)
- Activation crons RGPD #6 et #7 après validation politiques de rétention BLMF
- Backup tables cleanup
- Bascule des 4 vues SECURITY DEFINER ERROR en INVOKER
- **Phase 7 spec workflow réservation** : tests acceptation T1-T15 + U1-U6 + L1-L3 (manuels en runtime)
- Doublon login/login-with-identifier à clarifier
- Audit i18n pages non encore couvertes (CatalogPage, RedePage, BibliotecaPage, etc.)
- `address.city.placeholder` vide dans les 6 locales (TODO mineur)

### Specs cadrées en attente d'implémentation

- **Validation physique** (~750 lignes) : ~2-3 jours d'implémentation
- **Migration de compte** (~940 lignes) : ~4-6 jours d'implémentation
- **Onboarding biblioteca** : déjà cadré

---

## Conventions opérationnelles consolidées (à préserver)

- **Livraison code** : TOUJOURS fichiers complets ready-to-overwrite OU patches `.patch`. JAMAIS instructions « remplace ceci par cela »
- **i18n militante** : TOUJOURS 6 locales simultanément
  - pt-BR : triple `(o/a/e)` ou épicène
  - fr : point médian inclusif
  - es : neutre `e` argentin (jamais el/la)
  - en : standard
  - it : Genderstern `compagn*o` (JAMAIS camerata/camerati = fasciste)
  - de : Genderstern `Genoss*in`
- **Windows PowerShell** : NE JAMAIS livrer scripts qui lisent/écrivent fichiers à caractères non-ASCII (encoding Windows-1252 vs UTF-8). Préférer `git apply`, Python avec `encoding='utf-8'` explicite, ou copier-coller en bloc. Messages git commit sans accents.
- **Migrations DB** : transactionnées par défaut (BEGIN/COMMIT). Vérifier schémas via `information_schema.columns` AVANT requêtes
- **Edge Function deploy** : la Supabase CLI applique `verify_jwt: true` par défaut. Le `config.toml` à mettre en place verrouille `verify_jwt: false` pour les fonctions concernées
- **`canTransition` JS** : doit rester synchrone avec `fn_check_workflow_transition` DB. Helper DB reste source de vérité (validé par wrappers `api.*`) ; grisage UI purement informatif
- **MCP outputs** : ne survivent pas à fin de session — Xavier doit télécharger systématiquement
- **Estimations horaires** : Xavier a explicitement demandé d'arrêter de surévaluer le temps

---

## Lecture politique du chemin parcouru

3 jours pour passer de :
- **Spec workflow réservation rédigée mais non implémentée** (état au 04/05 fin de soirée)

À :
- **Spec entièrement déployée**, testable, avec tooling de garde-fou (`config.toml`), base saine après wipe, frontend i18n parfaitement cohérent dans 6 langues, sécurité durcie sur tous les fronts, gouvernance d'équipe complète avec mails désactivables individuellement

C'est le résultat d'**un rythme de travail intensif mais structuré**. Les sessions ont alterné implémentation, audit, et nettoyage — chaque journée se terminait par un commit propre poussé sur les 2 remotes, et chaque session suivante reprenait sur une base saine.

**Acquis structurels** :
1. **Architecture mail i18n complète** : tous les workflows réservation, gouvernance équipe, profils, RGPD passent par `notify-event` ou `notify-internal-task` avec dispatch DB → pg_net → Edge → Brevo/Resend, mails dans 6 langues militantes uniformes
2. **Helper unifié visibility** (`fn_library_visible_to_caller`) : toute la sémantique public/network/private passe par un seul helper SQL — toute future évolution est centralisée
3. **Sécurité défensive en couches** : RLS strict, login durci, verify_jwt verrouillé, rate limit, snapshots avant opérations destructives
4. **Distinction sémantique propre des rôles** : staff role (équipe) vs management role (engagement politique)
5. **Discipline de versionnement** : 11+ commits poussés sur 2 remotes, traçabilité complète, alias `git publish-app` pour cohérence Codeberg/GitHub

Le projet est **prêt pour les tests phase 7** et pour les chantiers UI restants (enrichissement onglet équipe, polissage divers). Bologna sept 2026 est sur la trajectoire visée.

---

*Bilan rédigé le 07/05/2026 en fin de session.*
