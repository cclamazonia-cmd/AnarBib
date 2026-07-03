# Matrice RLS « deny-all assumé » — 27 tables

> **Date** : 2026-06-23
> **Origine** : audit externe code↔doc du 2026-06-23 (§5.2, reco P4) + advisor Supabase
> `rls_enabled_no_policy`.
> **But** : rendre **explicite** l'implicite. L'audit signalait 29 tables (snapshot
> backlog) « RLS activée mais 0 policy » à qualifier une par une. À ce jour la base
> en compte **27**. Ce document confirme, table par table, que ce sont des
> **deny-all voulus**, et par quel chemin la donnée est réellement servie.

## Principe

`ENABLE ROW LEVEL SECURITY` **sans aucune `POLICY`** ⇒ **deny-all** pour `anon` et
`authenticated` : aucune ligne n'est lisible/écrivable en accès direct PostgREST.
L'accès se fait exclusivement via des fonctions `SECURITY DEFINER` (RPC `api.*` /
`public.fn_*`) ou des Edge Functions tournant en `service_role`. C'est le
**Scénario C** du `_TEMPLATE.sql` (« table hors Data API ») et c'est conforme à
**DOC-RPC-3** (écritures via RPC, `storage`/tables sensibles hors périmètre direct).

## Méthode de vérification

1. Listage des tables `public` avec `relrowsecurity = true` et zéro `pg_policy`.
2. **Recherche d'accès direct côté front** : `grep` de `from('<table>')` dans `src/`
   → **aucun** des 27 noms n'est lu en direct par le frontend (donc aucun risque de
   « 0 ligne silencieux »).
3. Vérification du chemin d'accès réel (vue `api` / RPC SECDEF / Edge Function) via
   `pg_depend` et l'inventaire des fonctions.

## Matrice

| # | Table | Catégorie | Accès attendu | Verdict |
|---|-------|-----------|---------------|---------|
| 1 | `auth_rate_limits` | Anti-abus | EF `login` (`service_role`) | ✅ deny-all voulu |
| 2 | `authority_proposal_notification_outbox` | Outbox notif | enqueue RPC SECDEF → `notify-event` ; cron re-dispatch | ✅ |
| 3 | `cartography_submission_notification_outbox` | Outbox notif | trigger enqueue → `notify-event` | ✅ |
| 4 | `gazette_submission_notification_outbox` | Outbox notif | RPC `*_notify_event` → `notify-event` | ✅ |
| 5 | `lettre_notification_outbox` | Outbox notif | RPC DEFINER → `notify-event` | ✅ |
| 6 | `interlibrary_loan_notification_events` | Outbox notif | DEFINER (anon SELECT révoqué 04-26) | ✅ |
| 7 | `library_request_notification_events` | Outbox notif | DEFINER (anon SELECT révoqué 04-26) | ✅ |
| 8 | `membership_expiry_notifications` | Outbox notif | DEFINER + cron `membership-expiry-daily` | ✅ |
| 9 | `interlibrary_loan_events` | Journal d'audit | écriture DEFINER, lecture interdite en direct | ✅ |
| 10 | `loan_midpoint_message_log` | Journal d'audit | DEFINER + cron `notify-mid-loan-reading` | ✅ |
| 11 | `import_blmf_books_rows` | Staging import | `service_role` (palier 2, anon révoqué 04-26) | ✅ |
| 12 | `import_blmf_exemplares_rows` | Staging import | `service_role` (palier 2) | ✅ |
| 13 | `import_terra_livre_zotero_staging` | Staging import | lecture via `v_terra_livre_books_ready` (`service_role`) | ✅ |
| 14 | `partner_source_records` | Staging ingest partenaire | EF `process-partner-catalog-import` (`service_role`) | ✅ |
| 15 | `partner_source_holdings` | Staging ingest partenaire | idem | ✅ |
| 16 | `partner_source_items` | Staging ingest partenaire | idem | ✅ |
| 17 | `catalog_partner_capabilities` | Staging ingest partenaire | EF `probe-partner-catalog` | ✅ |
| 18 | `catalog_partner_probe_runs` | Staging ingest partenaire | EF `probe-partner-catalog` | ✅ |
| 19 | `lettre_consent_tokens` | Jeton / secret | RPC SECDEF `lettre-confirm` / `lettre-unsubscribe` | ✅ |
| 20 | `library_request_claims` | Jeton / secret | RPC SECDEF (parcours sollicitation institutionnelle) | ✅ |
| 21 | `library_email_identity` | Secret / identité | DEFINER (DNS/DKIM ; anon révoqué 04-26) | ✅ |
| 22 | `cartography_entries` | **Surface publique verrouillée** | **lecture via `api.cartography_*_v1`, écriture via `api.fn_cartography_*` SECDEF** (Scénario C, MAP-E) | ✅ chemin confirmé, 0 lecture directe |
| 23 | `cartography_submissions` | **Surface publique verrouillée** | EF publique `submit-cartography-entry` (`service_role`) + modération `fn_cartography_submission_*` | ✅ |
| 24 | `library_themes` | **Theming biblio** | RPC SECDEF `get/set_library_theme_config*`, `fn_ensure_library_theme`, `api.fn_set_library_theme_active` | ✅ chemin confirmé, 0 lecture directe |
| 25 | `library_theme_configs` | **Theming biblio** | idem (`get/set_library_theme_config*`) | ✅ |
| 26 | `author_name_aliases` | Autorités | alimentée/normalisée par triggers/RPC d'autorités, non exposée au front | ✅ |
| 27 | `user_history_retention_preferences` | RGPD | RPC SECDEF `fn_get/set_my_retention_preference` | ✅ |

## Conclusion

**Aucune `POLICY` à ajouter.** Les 27 tables sont en deny-all **par conception** et
le front ne les attaque jamais en direct. L'« implicite » de l'advisor est désormais
explicite et tracé.

## MàJ 2026-07-03 — matérialisation d'un deny explicite sur le sous-ensemble PII

Décision de rendre le deny **matériel** (objet `POLICY`) sur les **15 tables
PII / secret / données personnelles** du lot, sans changer le comportement.
Migration `20260703125440_rls_explicit_deny_pii_tables.sql`.

- **Ce qui change** : chaque table porte désormais une policy
  `deny_direct_access_secdef_only` **RESTRICTIVE** `FOR ALL TO anon, authenticated
  USING (false) WITH CHECK (false)`, plus un `REVOKE ALL … FROM anon, authenticated`.
- **Ce qui NE change pas** : `service_role` (BYPASSRLS) et les fonctions
  `SECURITY DEFINER` (exécutées comme owner) contournent la RLS → tous les chemins
  d'accès réels (RPC `api.*` / `fn_*`, Edge Functions) sont intacts. `anon` /
  `authenticated` restent en deny-all, exactement comme avant.
- **Pourquoi** : (1) à l'épreuve d'un futur ajout accidentel de policy permissive
  (le RESTRICTIVE `USING(false)` bloque quoi qu'il arrive) ; (2) fait taire
  l'advisor `0008_rls_enabled_no_policy` sur ces tables sensibles (le bruit résiduel
  ne subsiste que sur les tables non-PII : staging import, ingest partenaire,
  theming, `author_name_aliases`).

Tables concernées (15) : `auth_rate_limits`, `authority_proposal_notification_outbox`,
`cartography_entries`, `cartography_submission_notification_outbox`,
`cartography_submissions`, `gazette_submission_notification_outbox`,
`interlibrary_loan_notification_events`, `lettre_consent_tokens`,
`lettre_notification_outbox`, `library_email_identity`, `library_request_claims`,
`library_request_notification_events`, `loan_midpoint_message_log`,
`membership_expiry_notifications`, `user_history_retention_preferences`.

Les tables Scénario C **non-PII** restent volontairement sans policy (deny-all
implicite + `REVOKE` + `COMMENT`), conformément à la règle de garde ci-dessous.

### Règle de garde (pour les prochaines tables)

Toute nouvelle table `public` doit, à sa migration, **soit** porter au moins une
`POLICY` par opération autorisée (Scénario A/B), **soit** être déclarée Scénario C
(deny-all) avec **(a)** `REVOKE ALL … FROM anon, authenticated`, **(b)** un `COMMENT`
documentant le chemin d'accès (RPC / vue `api` / EF), et **(c)** une ligne dans cette
matrice. Vérifier en particulier les tables touchant une **surface publique**
(catalogue, carto, thèmes, fiches) : confirmer qu'une vue `api` ou un RPC SECDEF sert
la donnée, jamais un `from('<table>')` direct.
