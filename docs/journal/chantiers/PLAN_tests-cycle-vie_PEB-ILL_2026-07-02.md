# Plan — suite de tests de cycle de vie PEB + partage numérique (ILL)

**Date** : 2026-07-02
**Auteur** : Xavier (session avec Claude)
**But** : combler le seul résiduel vérifiable du « ≈90 % » chapitre 6 GLB v16 sur *PEB* et *partage numérique* — l'**absence de test de cycle de vie automatisé** (les profils d'adoption en ont un ; PEB et ILL n'en ont aucun dans `tests/sql/ci-suites.txt`). Livrable : une suite `tests/sql/paquet_peb_ill_lifecycle_tests.sql`, ROLLBACK, fixtures dynamiques, seed-compatible, ajoutée à l'allowlist CI. Une fois verte, les deux lignes passent de « Tenue (≈90 %) » à « Tenue » avec preuve permanente.

## Préconditions rétro-conçues (lues en base le 2 juillet)

- **Mode biblio = colonnes simples sur `public.libraries`** : `network_mode='federated'`, `circulation_mode <> 'off'`, `is_active=true`. NOT NULL sans défaut : `slug`, `name`. → créer 2 biblios directement, pas besoin de la gouvernance des profils.
- `fn_peb_authorized(lender,borrower)` = lender≠borrower ∧ circulation(2) ∧ federated(2).
- `fn_peb_create_loan_with_items(p_loan jsonb, p_items jsonb)` **n'est PAS SECURITY DEFINER** → la RLS `interlibrary_loans_v2_insert` s'applique : `user_can_manage_library(lender OU borrower)` ∧ `fn_peb_authorized`. Champs jsonb loan obligatoires : `lender_library_id`, `borrower_library_id`, `initiated_by_library_id` (défauts : `status_global='preparacao'`). Item obligatoires : `line_no`, `holding_id`, `item_id`, `bib_ref` ; **garde dure : l'exemplaire doit être disponible** (absent de emprestimo_itens_v2/reserva_linhas_v2/interlibrary_loan_items_v2/consulta_linhas_v2).
- `fn_ill_request(requester,source,book_id,mode,note)` (SECURITY DEFINER) exige : appelant `user_can_act_as_staff_on_library(requester)` ; `fn_partnership_has_active_right(requester,source,'digital_share')` ; livre **sans ISBN/ISSN** (sinon `ill_isbn_use_peb`) ; crée `ill_digital_shares.flux_state='demande'`.

## Fixtures dynamiques à créer (dans le DO block, tout ROLLBACK)

1. 2 biblios A, B : `network_mode='federated'`, `circulation_mode='full_sigb'`, `is_active=true`.
2. 1 user staff/manager (auth.users + profiles) satisfaisant `user_can_manage_library(A)` et `user_can_act_as_staff_on_library(A)` — **à confirmer** : via `network_staff`/`network_administrators` ou team ? (lire `user_can_manage_library`).
3. **PEB** : 1 livre + 1 holding + 1 item disponible côté prêteur (structure `exemplares`/holdings à lire).
4. **ILL** : `library_partnerships(A→B, status='active')` + `partnership_rights(digital_share, actif)` (structure à lire) + 1 livre **sans ISBN/ISSN** + 1 `digital_asset` (pour `fn_ill_transmit`).
5. Stub auth par acteur : `set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role','authenticated')::text, true)` (objet complet — cf. leçon CI `request.jwt.claims`).

## Chaînes à asserter

- **PEB** : `fn_peb_authorized` → `fn_peb_create_loan_with_items` → `fn_peb_update_status` → `fn_peb_update_item_status` → `fn_peb_archive_loan` → `fn_peb_unarchive_loan`. Vérifier états intermédiaires + rejets (non-fédérée, non-manager, exemplaire indisponible).
- **ILL** : `fn_ill_request` → `fn_ill_respond('accepte')` → `fn_ill_start_digitization` → `fn_ill_transmit(plafond)` → `fn_ill_acknowledge` → `fn_ill_close`. `fn_ill_signed_url` = **hors périmètre SQL** (génère une URL signée Storage ; testé via l'Edge Function `read-ill-shared-asset`). Vérifier rejets : sans droit digital_share (`ill_no_digital_share`), livre à ISBN (`ill_isbn_use_peb`), appelant non-staff (42501).

## Restant à lire au moment du build

`user_can_manage_library` (comment satisfaire le rôle) · structure `exemplares`/holdings + enums `item_status`/`status_global` · structure `partnership_rights` · transitions `fn_peb_update_status`/`fn_ill_respond`.

## Convention harness

`DO $$ … BEGIN … EXCEPTION` unique, bilan final `RAISE EXCEPTION 'PEB-ILL OK : N/N tests passés'` (rollback total) ou `… ECHEC : …`. Ajouter la ligne à `tests/sql/ci-suites.txt`. Valider par `execute_sql` MCP en ROLLBACK (pattern BG2-14) puis en conteneur jetable si besoin, avant push. Éprouver in fine par l'onboarding CIRA Marseille (ordre d'exécution GLB #6).
