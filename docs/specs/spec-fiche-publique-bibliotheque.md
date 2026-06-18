---
Genre : référence
Statut : ✅ implémentée en prod (17/06/2026) — doctrine consolidée a posteriori (18/06)
Décisions : incarne PUBLIB-OPTIN-1, PUBLIB-OPTIN-2, PUBLIB-SCHED-1, PUBLIB-GEO-1, PUBLIB-VIS-1, PUBLIB-NAV-1, PUBLIB-VITRINE-1, PUBLIB-O1 (REGISTRE §31) ; cite INV-5
Supersédé par : —
---

# Spec — Annuaire & fiches publiques des bibliothèques (PUBLIB)

**Statut** : v1.0 — consolidation doctrinale (le code est en prod ; la doctrine vivait dans le cadrage + REGISTRE §31).
**Date** : 18/06/2026
**Origine** : audit 360° (P2 « specs »). Comble le manque révélé le 17/06 : les horaires d'ouverture posés ce jour (§19 BIBLIO) étaient **invisibles hors connexion**. Surface **anonyme** présentant une bibliothèque **en tant que lieu**. Décisions arbitrées par Xavier le 17/06 ; trace : `docs/journal/cadrages/CADRAGE_fiche_publique_bibliotheque_2026-06-17.md`. Ce spec **ne décide rien de neuf** : il met par écrit la doctrine déjà livrée (migrations `795ba6ed` + `20260617061715`, frontend `8346f57e`).
**Périmètre** : modèle d'accès anonyme, opt-in par section, données exposées, vues/RPC, surfaces frontend (annuaire + fiche), carte/localisation, RGPD.

> **Cousine connectée** : §25 MYLIB (« Ma bibliothèque », vitrine côté lecteur·rice connecté·e). PUBLIB est sa face **anonyme**.

---

## 1. Principes directeurs

- **PUBLIB-VIS / accès concentrique.** L'ouverture suit `libraries.visibility_level` ∈ `{private, network, public}` (**défaut `private`** — chaque collectif décide explicitement). Seules les biblios **`public` ∧ `is_active`** existent pour l'anonyme. *(= PUBLIB-VIS-1.)*
- **PUBLIB-OPTIN — « trouvable ≠ tout public ».** L'exposition est à **deux niveaux**, et le niveau 2 est **par section, défaut OFF** : une biblio peut figurer à l'annuaire (niveau 1) **sans** révéler *quand* elle ouvre ni son adresse exacte. *(= PUBLIB-OPTIN-1, PUBLIB-GEO-1.)*
- **Souveraineté du collectif.** Publier une section = **coordenador** (`user_can_manage_library`), avec **rappel UI « décision collective conseillée »** avant bascule. Pas de quorum (aucune infra ; reporté si demandé). *(= PUBLIB-OPTIN-2.)*
- **Anti-tracking (INV-5).** Aucune tuile/ressource tierce **auto-chargée** sur nos pages publiques : pas de fuite passive de la consultation. La carte = **lien sortant**, jamais d'embed. *(= PUBLIB-GEO-1, PUBLIB-O1.)*
- **Source unique, pas de duplication.** L'annuaire *data-driven* vit **dans l'app** ; le **site vitrine `anarbib.org`** (repo séparé) **y renvoie**, ne le recopie pas. *(= PUBLIB-VITRINE-1.)*

---

## 2. Modèle d'accès — ce que voit l'anonyme

| Niveau | Porte | Contenu | Objet |
|---|---|---|---|
| **0** | `private` / `network` | **rien** pour l'anon (une biblio `network` reste exclue **même si** elle a coché un opt-in) | — |
| **1 — annuaire** | `is_active ∧ visibility_level='public'` | nom, ville, pays, logo, site web, affiliation, nombre de notices, statut catalogue (en ligne / en construction) | `api.public_libraries` |
| **2 — contact** *(opt-in)* | niveau 1 **∧** `library_public_contact.is_public = true` | e-mail / téléphone / WhatsApp / adresse / note publics | `api.library_contact_public_v1` |
| **2 — horaires** *(opt-in)* | niveau 1 **∧** `library_opening_hours.is_public = true` | `slots` `[{day 1..7, start, end, label?}]` + note | `api.library_opening_hours_public_v1` |

**Triple garde** sur les vues de niveau 2 : `is_public = true` **ET** `libraries.is_active` **ET** `visibility_level = 'public'`. Défaut OFF partout → **rien ne fuit** tant qu'un·e coordenador n'a pas explicitement basculé une section. *(Cloisonnement vérifié en prod : `set local role anon` en transaction.)*

---

## 3. Modèle de données

- **`public.libraries.visibility_level`** `text` (CHECK `{public, network, private}`, **défaut `private`**) — la porte du niveau 1. Indépendant de `is_active`.
- **`public.library_public_contact`** : `library_id`, `public_email`, `public_phone`, `public_whatsapp`, `public_address`, `public_note`, **`is_public boolean DEFAULT false NOT NULL`**.
- **`public.library_opening_hours`** : `library_id`, **`slots jsonb`** (`[{day 1..7, start, end, label?}]`), `public_note`, **`is_public boolean DEFAULT false NOT NULL`** (table canonique des horaires — §19 BIBLIO, migration `20260617004224`).
- **Vues `api.*` (toutes `security_invoker = true`, REVOKE PUBLIC + GRANT `anon`)** : `public_libraries` (niveau 1), `library_contact_public_v1`, `library_opening_hours_public_v1` (niveau 2), `library_service_public` (état de fonctionnement public).

---

## 4. RPC (toutes `authenticated`, REVOKE PUBLIC, gardées `user_can_manage_library` = coordenador)

- **`api.fn_set_library_contact_public(p_library_id uuid, p_is_public boolean)`** — bascule l'opt-in contact.
- **`api.fn_set_library_hours_public(p_library_id uuid, p_is_public boolean)`** — bascule l'opt-in horaires.
- **`api.fn_upsert_library_opening_hours(p_library_id uuid, p_slots jsonb, p_public_note text)`** — édite les créneaux (§19 BIBLIO).

---

## 5. Surfaces frontend (commit `8346f57e`)

- **#PUB1 — Annuaire** `/bibliotecas` (`BibliotecasPage`) : cartes des biblios de niveau 1 (i18n `bibliotecas.*`), bouton « Voir le catalogue » (rebond OPAC) + « Site ».
- **#PUB2 — Fiche** `/bibliotecas/:slug` (`BibliotecaPublicaPage`) : entête niveau 1 + **#PUB4** section contact + **#PUB5** section horaires (affichées **seulement** si la section est opt-in publique).
- **#PUB-NAV-1** : entrée de navigation publique « Bibliothèques » (header/footer) ; **#PUB6** : rebond depuis le filtre biblio de l'OPAC (`/catalogo/:slug`) vers la fiche.
- **#PUB3 — Panneau admin « Fiche publique »** (coordenador) : 2 toggles (contact, horaires) appelant les RPC `fn_set_library_*_public`, avec le rappel « décision collective conseillée » (PUBLIB-OPTIN-2).
- **PUBLIB-O1 — carte = lien sortant** : « Voir sur la carte » → `openstreetmap.org/search?query=<adresse>` (nouvel onglet), affiché **seulement** si le contact est opt-in public **et** porte une adresse. **Aucune tuile/Leaflet/géocodage** chargé sur notre page (le clic EST le consentement ; réalisation la plus stricte de PUBLIB-GEO-1 / INV-5). OSM, pas Google.

---

## 6. Horaires — frontière des représentations (PUBLIB-SCHED-1, soldé 17/06)

Confronté au réel, le risque de « 3 représentations d'horaires » s'est résolu en **2 usages distincts + 1 colonne morte** :
- **`library_opening_hours`** = **canonique** des horaires *présentables au public* (cette spec).
- **`consultation_schedule_struct`** = **conservé, usage distinct** : fenêtres de **réservation de consultation sur place** (lu par `fn_validate_consulta_schedule_window`). **Pas de fusion.**
- **`service_schedule_text`** = **supprimé** (colonne morte, vide partout). Migration `20260617061715` (BEGIN/ROLLBACK validé), trigger d'audit recréé sans elle, frontière documentée en commentaires SQL.

---

## 7. RGPD

Si une biblio publie des **coordonnées nominatives** (e-mail/téléphone d'une personne plutôt que du collectif), c'est un traitement à porter au `REGISTRE_TRAITEMENTS`. La doctrine encourage des coordonnées **du collectif** (anti-méga-machine, cohérent avec NOTIF-PA4). L'opt-in par section + défaut OFF + garde coordenador sont les garde-fous.

---

## 8. Points ouverts / hors-périmètre

- **Décision collective formelle** (quorum avant bascule) : volontairement **non implémentée** (simple rappel UI) ; à rouvrir si une AG le demande.
- **Carte embarquée** : exclue par doctrine (INV-5) — le lien OSM sortant est la réponse définitive, pas un palier vers du Leaflet.
- **Adresse exacte** : niveau 2 opt-in ; tant qu'aucune adresse publique n'existe, pas de lien carte.

---

## 9. Annexe — artefacts (vérifiés dans le baseline `20260510000000_baseline_live.sql`)

- **Migrations** : `20260617004224` (table `library_opening_hours` + RPC upsert, §19) ; `20260617061715` (PUBLIB-SCHED-1 : drop `service_schedule_text`) ; **`795ba6ed`** (Phase 2 : drapeaux `is_public` + policies anon gated + vues `library_contact_public_v1`/`library_opening_hours_public_v1` + RPC `fn_set_library_*_public`).
- **Vues** : `api.public_libraries`, `api.library_contact_public_v1`, `api.library_opening_hours_public_v1`, `api.library_service_public` (toutes `security_invoker`).
- **RPC** : `api.fn_set_library_contact_public`, `api.fn_set_library_hours_public`, `api.fn_upsert_library_opening_hours`.
- **Tables** : `public.library_public_contact`, `public.library_opening_hours` (+ `is_public`), `public.libraries.visibility_level`.
- **Frontend** (`8346f57e`) : `src/pages/public/BibliotecasPage.jsx` (`/bibliotecas`), `src/pages/public/BibliotecaPublicaPage.jsx` (`/bibliotecas/:slug`) ; i18n `bibliotecas.*` (×10 locales).
- **Décisions REGISTRE** : §31 PUBLIB-OPTIN-1/2, SCHED-1, GEO-1, VIS-1, NAV-1, VITRINE-1, O1. Parents : §19 BIBLIO, §25 MYLIB, §18 OPAC.

---
*Spec produit le 18/06/2026 (session « Audit 360 — remise à niveau P0/P1 »), consolidation a posteriori d'un chantier livré en prod le 17/06. Reste « ouvert » : décision collective formelle (quorum) — volontairement non implémentée.*
