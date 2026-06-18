---
Genre : référence
Statut : ✅ implémentée — doctrine consolidée a posteriori (18/06/2026)
Décisions : consolide NOTIF-PA0/PA1/PA2/PA3/PA4, MULTI-C.1–C.4, MULTI-F.1, MULTI-Z23 ; introduit COTIS-1…COTIS-10 (à verser au REGISTRE)
Supersédé par : —
---

# Spec — Cotisation (contribution d'adhésion)

**Statut** : v1.0 — consolidation doctrinale (le code, le cron et les tests existent ; la doctrine écrite manquait).
**Date** : 18/06/2026
**Origine** : audit 360° (P1/P2) — conseil « **consolider la doctrine de la cotisation : spec-cotisation unique (code + tests existent, doctrine écrite manque)** ». Ce document **ne crée rien** : il met par écrit la doctrine **déjà implémentée et déployée en production** (modèle de données du 19/05, gate de circulation MULTI du 08/06, notifications NOTIF-PA du 08/06, revérification au renouvellement §6.1 du 17/06, cron d'expiration #25 du 17/06, tests #33 du 17/06).
**Périmètre** : configuration par biblio, modèle de données (règles, paiements, notifications d'expiration), calcul de validité, gate de circulation, enregistrement de paiement, notifications e-mail (paiement + expiration), affichage lectrice (`/conta`), multi-appartenance.

> **Vocabulaire.** On dit **cotisation** / **contribution d'adhésion** (jamais « abonnement » : pas une logique commerciale). En pt-BR : *contribuição*. La cotisation est un **soutien matériel à un collectif**, pas l'achat d'un service.

---

## 1. Principes directeurs (COTIS-1…COTIS-5)

- **COTIS-1 — Strictement par bibliothèque, jamais agrégée.** Une cotisation appartient à **une appartenance** (`user_library_memberships`), donc à **un couple (lectrice, biblio)**. Aucune agrégation, aucun transfert de privilège entre biblios. Une lectrice membre de A et B a deux cotisations **indépendantes** : à jour dans A n'implique rien pour B. *(= MULTI-C.1–C.4.)*
- **COTIS-2 — Souveraineté de la biblio.** Chaque biblio décide **si** elle utilise la cotisation (`libraries.membership_enabled`), **ses** règles (montants, périodicité), et **si** elle envoie le reçu e-mail (`cotisation_payment_mail_enabled`, défaut ON). Une biblio sans cotisation a l'emprunt **libre** pour ses membres actifs. *(= NOTIF-PA2, « Position 1 ».)*
- **COTIS-3 — Paiement manuel, anti-plateforme.** La cotisation est **enregistrée par le staff** (espèces, virement, chèque, **en nature**, **exemption**…), jamais prélevée par un prestataire de paiement continu. **Aucun renouvellement automatique.** Cohérent avec le refus de la dépendance à une méga-plateforme : la confiance et l'argent circulent en présentiel, dans le collectif.
- **COTIS-4 — Notification = e-mail + bandeau `/conta` ; notif in-app pour le rappel d'expiration.** Le **reçu de paiement** = e-mail seul (si la biblio l'active). Le **rappel d'expiration** (J-7 et J-0), parce que le gate est dur (COTIS-5), est **bicanal : e-mail + notification in-app** (`user_notifications`, catégorie `alerta`). Le **bandeau `/conta`** (`days_until_expiry`) reste l'**état permanent** dans tous les cas. *(Amende la doctrine « e-mail seul » `§4.4` pour le seul cas expiration — décidé 18/06. Le reçu de paiement, lui, reste e-mail seul.)*
- **COTIS-5 — Le gate de circulation est DUR.** Cotisation requise non à jour → **refus** de toute création **et** de tout renouvellement d'emprunt/consultation, avec message clair. **Pas de période de grâce** (le blocage tombe dès `valid_until < aujourd'hui`) ; l'unique « adoucissement » = le **rappel bicanal** (e-mail + notif in-app) à **J-7 et J-0**, en amont (COTIS-4 / COTIS-8). *(= MULTI-F.1, condition 4.)*

---

## 2. Configuration par bibliothèque (COTIS-6)

- **`libraries.membership_enabled` boolean (défaut `false`)** — interrupteur maître. `true` : la biblio **utilise** les règles de cotisation (affichage `/conta` + gate de circulation). `false` : **emprunt libre** pour les membres actifs, cotisation masquée et non bloquante. *(commentaire de colonne en base, fait foi.)*
- **`public.library_membership_rules`** — les règles propres à la biblio. **Plusieurs règles actives possibles** (ex. « tarif standard » + « tarif réduit » / « soutien »). Colonnes clés :
  - `amount_min numeric(10,2)` (≥ 0) — **plancher** ; `amount_suggested numeric(10,2)` (≥ `amount_min`, optionnel) — **conseil, non contrainte**.
  - `currency text` (ISO 3 lettres majuscules, défaut `EUR`).
  - `period_type` ∈ `{annual, monthly, quarterly, lifetime, none}` (défaut `annual`).
  - `period_anchor` ∈ `{rolling, calendar}` (défaut `rolling`).
  - `is_required boolean` (défaut `true`) — si `true`, cette règle **bloque la circulation** quand elle n'est pas honorée ; **conditionne aussi les rappels d'expiration**.
  - `is_active boolean`, `display_order`, `name`, `description`.
- **COTIS-6 — gestion des règles = `coordenador`** (pas `librarian`). *(= spec-gouvernance-roles.)*

---

## 3. Modèle de données

### 3.1 `public.membership_payments` — le registre des paiements (immuable, archivable)
`id`, `user_id`, `library_id`, `rule_id` (nullable), `amount_paid numeric(10,2)` (≥ 0), `currency` (3 lettres maj.), `paid_at timestamptz`, **`valid_from date`** (défaut `CURRENT_DATE`), **`valid_until date`** (`NULL` = sans expiration ; sinon ≥ `valid_from`), `payment_method`, `notes`, `recorded_by` (staff), `created_at`/`updated_at`, **`archived_at` / `archive_reason`** ∈ `{profile_transition, admin_manual, system_cleanup}` (archivage lors d'une transition de profil — D.1, jamais de suppression dure).

### 3.2 Énumérations
- `membership_payment_method` : `cash, transfer, card, check, in_kind, exemption, other`. **`exemption` et `in_kind` sont de plein droit** (montant 0 ou forfaitaire accepté) — la cotisation n'exclut personne pour raisons d'argent.
- `membership_period_type` : `annual, monthly, quarterly, lifetime, none`.
- `membership_period_anchor` : `rolling` (à partir de la date de paiement) | `calendar` (fin de l'année/mois/trimestre civil).

### 3.3 `public.membership_expiry_notifications` — anti-doublon des rappels (#25)
`id`, `membership_id` (FK → `user_library_memberships`, `ON DELETE CASCADE`), `valid_until date`, `threshold_days integer`, `notified_at`. Clé d'unicité `(membership_id, valid_until, threshold_days)` : un rappel par adhésion, par période et par seuil — jamais deux fois.

### 3.4 Vue `public.v_active_memberships`
Source de l'état dérivé : `dues_status` ∈ `{not_applicable, never_paid, lifetime, up_to_date, expired}`, `last_valid_until`, `days_until_expiry`, `membership_enabled`, `membership_status`.

---

## 4. Calcul de la validité — `fn_compute_membership_validity(p_rule_id, p_paid_at := now())`

`STABLE SECURITY DEFINER`. Renvoie `(valid_from date, valid_until date)`. `valid_from := date(p_paid_at)`. `valid_until` selon **`period_type` × `period_anchor`** de la règle :

| period_type | `rolling` | `calendar` |
|---|---|---|
| `annual` | paiement + 1 an − 1 j | 31 décembre de l'année du paiement |
| `quarterly` | paiement + 3 mois − 1 j | fin du trimestre civil |
| `monthly` | paiement + 1 mois − 1 j | fin du mois civil |
| `lifetime` / `none` | `NULL` (sans expiration) | `NULL` |

Le staff peut **surcharger** `valid_from`/`valid_until` (régularisations, paiements rétroactifs) via les paramètres de `fn_record_membership_payment`.

---

## 5. Enregistrement d'un paiement — `fn_record_membership_payment(...)`

`SECURITY DEFINER`. Signature : `(p_user_id, p_rule_id, p_amount_paid, p_payment_method := 'cash', p_paid_at := now(), p_notes := NULL, p_valid_from := NULL, p_valid_until := NULL)` → `(ok, payment_id, valid_from, valid_until, message)`.

- **Garde** : authentifié·e **+ accès Painel (staff de la biblio)**. *(REVOKE PUBLIC/anon ; cf. durcissement IMP/#79.)*
- Valide le montant (`amount_paid >= amount_min`, **sauf** `exemption`/`in_kind`), calcule la validité (via §4 si non fournie), insère dans `membership_payments`.
- **Émet l'événement** `cotisation_payment_recorded` (payload `{payment_id}`) → §6.

> **COTIS-7 — pas de paiement en ligne.** L'enregistrement est un **acte staff** constatant un paiement reçu hors-ligne. Il n'y a pas (et il n'est pas prévu par défaut) de self-service de paiement par la lectrice via un prestataire. Une lectrice **voit** son état mais **règle en présentiel**.

---

## 6. Gate de circulation (COTIS-5, MULTI-F.1)

- **`fn_is_loan_blocked_by_dues(p_user_id, p_library_id) → boolean`** : `true` si une règle **requise et active** existe pour la biblio et que la cotisation est **expirée ou jamais payée**. C'est la **condition 4** des 5 conditions de circulation.
- **`fn_membership_can_engage_circulation(p_user_id, p_library_id) → text`** : porte unique englobant **(1)** appartenance active, **(2)** validation physique par-appartenance, **(3)** absence de restriction locale, **(4)** cotisation à jour. Renvoie un **verdict textuel** (`ok` ou un motif : `no_active_membership`, `not_physically_validated`, `restricted`, `dues_*`…) consommé par les messages d'erreur i18n.
- **Revérification au renouvellement (§6.1, fix 17/06)** : le cœur d'extension `fn_v2_extend_core` appelle `fn_membership_can_engage_circulation` — un membre **restreint, inactif ou non à jour** ne peut **pas prolonger** (avant le fix, seuls les impayés étaient revérifiés). Verrou de non-régression couvert par les tests (§9).

---

## 7. Notifications

### 7.1 Reçu de paiement — `cotisation_payment_recorded` → `handleCotisationPayment`
EF `supabase/functions/_shared/domain/membership.ts`. Relit `membership_payments` par `payment_id` (source de vérité), respecte `library_notification_policies.cotisation_payment_mail_enabled` (NOTIF-PA2, défaut ON). Si activé : **e-mail au membre** (montant + période de validité + méthode — NOTIF-PA4), dans sa locale. **Au membre seulement**, pas au staff (`DOC-NOTIF-1`). Pas de réplique in-app (COTIS-4).

### 7.2 Rappel d'expiration J-7 / J-0 (#25) — `cotisation_expiring` → `handleCotisationExpiring`
- **Cron `anarbib-membership-expiry-daily`** (`40 6 * * *` UTC, **actif**) → `fn_cron_notify_membership_expiry()`.
- La fonction parcourt `v_active_memberships` où `membership_enabled`, statut `active`, `last_valid_until` non nul, **`days_until_expiry ∈ {7, 0}`**, et **où une règle requise active existe**. Pour chaque adhésion : anti-doublon via `membership_expiry_notifications` `(membership_id, valid_until, threshold_days)`, puis dispatch `cotisation_expiring`. **Le doublon n'est inscrit que si le dispatch a réellement été émis** (résilience pg_net).
- EF `handleCotisationExpiring` : **bicanal** (COTIS-4, décidé 18/06) — (a) **e-mail** clés `cotisation.expiring.*` (J-7) / `cotisation.expiring_today.*` (J-0), **10 locales** ; (b) **notification in-app** `user_notifications` (catégorie `alerta`, titre/corps pré-rendus dans la langue du membre, même patron que la réplique restriction/gel) — best-effort, n'invalide pas l'e-mail, part même si le membre n'a pas d'e-mail. **Protection du membre (décidé 18/06)** : la notif in-app part **toujours** (le gate étant dur) ; seul l'**e-mail** est gardé par la politique biblio `cotisation_payment_mail_enabled`.
- **COTIS-8 — auto-limitation** : seules les biblios à `membership_enabled = true` **avec une règle requise active** génèrent des rappels (les deux canaux). Une biblio sans cotisation (ex. MLEG, BTL) n'envoie **rien**.

---

## 8. Affichage lectrice — bandeau `/conta` (COTIS-4)

`src/pages/account/AccountPage.jsx`, section affichée si `availability.cotisacoes` et (appartenance ∨ règles). Sources :
- **`api.fn_my_memberships_status()`** — par appartenance : `dues_status`, `dues_blocking`, `days_until_expiry`, `membership_enabled`, etc. (lue aussi par l'onglet « Mes biblios » — MULTI-Z23).
- **`fn_my_account_status()`** — état de la biblio **primaire**.
- `library_membership_rules` (règles applicables) + historique `membership_payments`.

Rendu : badge de statut, date d'expiration + jours restants, dernier paiement (montant/méthode/date), règles applicables (min/suggéré/requis), lien règlement, historique. Le bandeau est l'**état permanent** ; le seul *push* in-app de la cotisation est le **rappel d'expiration J-7/J-0** (COTIS-4), affiché dans la cloche de notifications (`user_notifications`, catégorie `alerta`).

---

## 9. Tests & CI

- **`tests/sql/paquet_cotisation_tests.sql`** (#33, 18/18) : `fn_compute_membership_validity`, `fn_is_loan_blocked_by_dues`, `fn_membership_can_engage_circulation` (4 verdicts), `fn_record_membership_payment` (auth/rôle/montant/happy-path), câblage du gate sur les 2 tables de circulation, **verrou anti-régression du §6.1**.
- **Exécuté en CI** depuis le 18/06 (workflow `Tests SQL`, allowlist `tests/sql/ci-suites.txt`) contre une base reconstruite (baseline + seed synthétique : biblio BLMF à cotisation + staff + sujet sans adhésion).

---

## 10. Points ouverts / hors-périmètre

- **COTIS-9 — paiement self-service en ligne** : non implémenté, non prioritaire (cf. COTIS-3/COTIS-7, anti-plateforme). À n'ouvrir qu'avec un prestataire **éthique/militant** et une décision d'AG réseau.
- **COTIS-10 — rappels au-delà de J-7/J-0** (ex. J-30, ou relance post-expiration) : volontairement limités à 2 seuils pour ne pas harceler. Élargir = ajouter des seuils dans `fn_cron_notify_membership_expiry` + clés i18n.
- **Reçu PDF** du paiement (à côté de l'e-mail) : non fait ; à arbitrer si une biblio le demande.
- **Devise multiple par biblio** : le modèle porte `currency` par règle et par paiement, mais l'UX suppose une devise cohérente par biblio ; non contraint en base.

---

## 11. Annexe — artefacts (vérifiés dans le baseline `20260510000000_baseline_live.sql`)

- **Tables** : `library_membership_rules`, `membership_payments`, `membership_expiry_notifications`, `library_notification_policies.cotisation_payment_mail_enabled`, `libraries.membership_enabled`.
- **Enums** : `membership_payment_method`, `membership_period_type`, `membership_period_anchor`.
- **Fonctions** : `fn_compute_membership_validity`, `fn_record_membership_payment`, `fn_is_loan_blocked_by_dues`, `fn_membership_can_engage_circulation`, `fn_cron_notify_membership_expiry`, `api.fn_my_memberships_status`, `fn_my_account_status` ; vue `v_active_memberships`.
- **Cron** : `anarbib-membership-expiry-daily` (`40 6 * * *`, actif).
- **Edge Functions** : `handleCotisationPayment` + `handleCotisationExpiring` (`_shared/domain/membership.ts`), routés par `_shared/core/dispatch.ts` ; clés `mail-strings.ts` `cotisation.payment.*` / `cotisation.expiring(_today).*` (10 locales).
- **Frontend** : `src/pages/account/AccountPage.jsx` (bandeau `/conta`), onglet « Mes biblios » (`TabBiblios`).
- **Tests** : `tests/sql/paquet_cotisation_tests.sql` (+ exécution CI `Tests SQL`).
- **Décisions REGISTRE liées** : NOTIF-PA0/PA1/PA2/PA3/PA4 (§6), MULTI-C.1–C.4 / MULTI-F.1 / MULTI-Z23 (§20).

---
*Spec produit le 18/06/2026 (session « Audit 360 — remise à niveau P0/P1 »), consolidation a posteriori de doctrine déjà en production. COTIS-1…COTIS-10 à verser au REGISTRE des décisions.*
