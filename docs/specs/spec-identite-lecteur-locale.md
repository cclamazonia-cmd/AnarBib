---
Genre : référence
Statut : ✅ implémentée en prod (Lots 0/2, 11-12/06/2026) — doctrine consolidée a posteriori (18/06)
Décisions : incarne CARD-LOCAL-IDENT, -STAFF, -GATE, -UNIQ, -1, -2, -3, -5, -6, -N3, -N4, -CANAL, -I18N (REGISTRE §27) ; étend MULTI-E.2
Supersédé par : —
---

# Spec — Identité lecteur·rice locale (CARD-LOCAL)

**Statut** : v1.0 — consolidation doctrinale.
**Date** : 18/06/2026
**Origine** : audit 360° (P2 « specs »). Le §27 du REGISTRE portait « spec à rédiger **avant** code » — mais le chantier a en réalité été **livré** (Lots 0/2, 11-12/06) ; cette spec est donc, comme cotisation et PUBLIB, une **consolidation a posteriori** (et corrige cette note périmée du §27). Décisions arbitrées par Xavier les 10-11/06 ; trace : `docs/journal/cadrages/CADRAGE_identite_lecteur_numero_local_2026-06-10.md` (v2).
**Périmètre** : modèle d'identité par biblio, attribution staff, unicité conditionnelle, recherche painel, roster, notifications, boussole de canal. **Hors périmètre** : le wizard de création de compte (cadrage dédié).

> **Filiation** : étend **MULTI-E.2** (§20) — le champ `local_reader_number` **préexistait** ; ce chantier l'**ouvre** (modèle biblio, recherche, attribution, roster, canaux). Cousins : §9 VALID (validation, où l'identité s'attribue), §23 CARD (carte-lecteur QR — **distincte** de l'identité locale).

---

## 1. Principes directeurs

- **CARD-LOCAL-IDENT — identité, pas « numéro ».** `local_reader_number` porte une **identité locale** : un numéro, **un nom**, ou tout schéma maison. Libellés UI **neutres** (« identité », jamais « numéro »).
- **CARD-LOCAL-STAFF — toujours un acte staff.** Le·la lecteur·rice ne s'attribue **jamais** son identité locale ; les wizards/e-mails **informent**, ne font pas saisir.
- **CARD-LOCAL-GATE — pas une condition de circulation.** Le gate reste l'**appartenance validée** (`status='active'`) ; l'identité locale est orthogonale. L'état intermédiaire bloquant = `pending_validation` (clarifie MULTI-F.1).
- **CARD-LOCAL-I18N — 10 locales, neutre.** Champ, hint, erreurs, colonnes du roster, e-mails : tous en **10 locales** (DOC-I18N-1), libellés neutres.

---

## 2. Modèle d'identité par bibliothèque (CARD-LOCAL-2/3)

Deux colonnes sur `public.libraries`, souveraines par biblio :

- **`reader_identity_model`** `text` (défaut **`free_number`**) ∈ `{free_number, sequenced_number, name, none}` — pilote l'**unicité** (cf. §4) : numérique = unique ; `name` = homonymes tolérés ; `none` = pas de schéma. *(Défaut `free_number` = rétro-compatible avec l'ancien index unique.)*
- **`reader_validation_mode`** `text` (défaut **`presential`**) ∈ `{presential, remote, none}` — pilote le **message** à la lectrice (identité par e-mail si `remote` ; au 1er passage si `presential` ; accès direct si `none`). Exposé au signup via `v_libraries_for_signup` (CARD-LOCAL-CANAL).

---

## 3. Données (sur l'appartenance)

`public.user_library_memberships` :
- **`local_reader_number`** `text` — l'identité locale (MULTI-E.2).
- **`imported_from_legacy`** `boolean` (défaut `false`) — marqueur posé à l'attribution/import, exporté au roster (CARD-LOCAL-5).

---

## 4. Unicité conditionnelle (CARD-LOCAL-UNIQ / -6)

Implémentée par **trigger** (pas un index partiel, car la condition dépend de `libraries.reader_identity_model`, une autre table) :
- **`public.fn_enforce_local_reader_identity_uniqueness()`** + trigger `trg_enforce_local_reader_identity_uniqueness` `BEFORE INSERT OR UPDATE OF (local_reader_number, status, library_id)`.
- Impose l'unicité **par biblio uniquement pour les modèles numériques** (`free_number`/`sequenced_number`) ; **levée** en mode `name`.
- **Réutilisation** : l'unicité **exclut `removed` + `terminated`** (seuls les départs **définitifs** libèrent une identité ; tout le reste — dont `left_with_pending_circulation` — la garde réservée).
- Collision : message d'erreur **sans divulguer** le compte existant.

---

## 5. Attribution — `api.set_local_reader_identity(p_user_id, p_library_id, p_value) → text`

`SECURITY DEFINER`, **staff** (CARD-LOCAL-STAFF). Attribue/édite l'identité locale, **indépendamment de la validation** (CARD-LOCAL-GATE). `p_value` vide = **effacement**. Unicité déléguée au trigger (§4). Émet l'événement de réconciliation `reader_identity_assigned` (§7).

---

## 6. Recherche & hint (painel)

- **`public.fn_painel_find_profile_by_lookup(p_lookup) → profiles`** (REVOKE PUBLIC ; `authenticated`/`service_role`) : recherche par **UUID / e-mail / identité locale**, scopée à la **biblio courante**, avec **repli « toutes mes biblios »** si zéro résultat (biblio d'origine signalée). *(CARD-LOCAL-1.)*
- **`api.get_last_assigned_reader_identity(p_library_id) → text`** : hint « dernier identifiant attribué » à l'ouverture, **dérivé** (`max(local_reader_number::bigint)` sur les modèles numériques) — **pas de colonne cache** : `libraries` étant anon-lisible, un cache fuiterait ~le compteur de lecteur·rices (et risquerait l'obsolescence). Guide **non bloquant** (n'invalide jamais le legacy). *(CARD-LOCAL-2.)*

---

## 7. Notifications de réconciliation (CARD-LOCAL-N4)

À l'attribution (validation **ou** édition) : notif **lectrice + biblio** via `notify-event`, événement **`reader_identity_assigned`** → handler `handleReaderIdentityAssigned` (`_shared/domain/membership.ts`), clés `reader_identity_assigned.*` (subject/intro/identityLabel + adminSubject/adminIntro), **10 locales**. **Dédup** avec `validation_confirmed` (ne pas doubler quand l'attribution se fait au moment de la validation).

---

## 8. Roster (CARD-LOCAL-N3)

- **`api.get_reader_roster(p_library_id) → TABLE(user_id, last_name, first_name, email, local_identity, status, imported_from_legacy, registered_since)`** — scopé **coordenador** (RLS).
- **Frontend** : écran biblio (`BibliotecaPage`), export **PDF tableau à colonnes** (jspdf) = livrable principal ; CSV en option. Colonnes i18n `biblioteca.roster.col.*` (lastName, firstName, email, uuid, identity, status, origin, since) + `origin.{anarbib,legacy}`, `title`/`subtitle`/`empty` (10 locales).

---

## 9. Boussole de canal (CARD-LOCAL-CANAL)

- **À la création de compte** : UUID + identifiant de login + « comment marche ta biblio » + « tu es en attente ». **Pas** d'identité locale (elle n'existe pas encore).
- **À la validation / attribution** : l'identité locale, par le canal du `reader_validation_mode` (e-mail si `remote`, au passage si `presential`).

---

## 10. Points ouverts / hors-périmètre

- **Wizard de création de compte** : cadrage dédié (hors de cette spec).
- Le §27 du REGISTRE portait « spec à rédiger avant code » → **périmé** (code livré 11-12/06) ; cette spec régularise.

---

## 11. Annexe — artefacts (vérifiés dans le baseline `20260510000000_baseline_live.sql`)

- **Colonnes** : `libraries.reader_identity_model` (+ CHECK 4 valeurs), `libraries.reader_validation_mode` (+ CHECK 3 valeurs) ; `user_library_memberships.local_reader_number`, `imported_from_legacy`.
- **Fonctions** : `api.set_local_reader_identity`, `api.get_reader_roster`, `api.get_last_assigned_reader_identity`, `public.fn_painel_find_profile_by_lookup`, `public.fn_enforce_local_reader_identity_uniqueness` (+ trigger `trg_enforce_local_reader_identity_uniqueness`).
- **Vue** : `public.v_libraries_for_signup` (porte `reader_validation_mode` pour le message d'accueil).
- **Edge Function** : `handleReaderIdentityAssigned` (`_shared/domain/membership.ts`, routé par `dispatch.ts` sur `reader_identity_assigned`) ; clés `mail-strings.ts` `reader_identity_assigned.*` (10 locales).
- **Frontend** : `BibliotecaPage` (roster) ; i18n `biblioteca.roster.*` (×10 locales).
- **Décisions REGISTRE** : §27 CARD-LOCAL-IDENT/STAFF/GATE/UNIQ/1/2/3/5/6/N3/N4/CANAL/I18N. Parent : §20 MULTI-E.2. Cousins : §9 VALID, §23 CARD.

---
*Spec produit le 18/06/2026 (session « Audit 360 — remise à niveau P0/P1 »), consolidation a posteriori d'un chantier livré en prod les 11-12/06 (Lots 0/2). Régularise la note « spec à rédiger avant code » du REGISTRE §27.*
