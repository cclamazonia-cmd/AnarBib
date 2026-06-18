---
Genre : référence
Statut : ✅ implémentée en prod (chantier clos 04/06/2026) — doctrine consolidée a posteriori (18/06)
Décisions : incarne MYLIB-1, MYLIB-2, MYLIB-3, MYLIB-4, MYLIB-5, MYLIB-6, MYLIB-7, MYLIB-O1 (REGISTRE §25) ; articulé avec PUBLIB §31, §6 NOTIF
Supersédé par : —
---

# Spec — « Ma bibliothèque » (vitrine & messagerie lecteur·rice)

**Statut** : v1.0 — consolidation doctrinale.
**Date** : 18/06/2026
**Origine** : audit 360° (P2 « specs », option 2 — chantier livré-clos le 04/06 **sans spec de référence**, seulement une trace). Surface côté **lecteur·rice connecté·e** : voir « sa » bibliothèque (carte de contact) et lui **écrire**, avec un canal **réciproque** biblio→lecteur·rice. Trace : `docs/journal/chantiers/CHANTIER_carte_ma_bibliotheque_lecteur_2026-06-04.md`. Ce spec **ne décide rien de neuf**.
**Périmètre** : carte « Ma bibliothèque » (`/conta`), vitrine de contact (côté biblio), messagerie bidirectionnelle lecteur·rice ↔ biblio.

> **Cousine anonyme** : `spec-fiche-publique-bibliotheque` (PUBLIB §31) expose la **même** table `library_public_contact` à l'**anonyme** sous opt-in `is_public`. Ici, MYLIB = la vue **membre actif·ve** (+ la messagerie). Même donnée, **audiences et gardes distinctes**.

---

## 1. Principes directeurs

- **MYLIB-1 — vitrine de contact = publique opt-in, vide par défaut, table sœur.** `public.library_public_contact` est **distincte** du confidentiel `public.library_contact_profiles` (minimisation : ce qui est montrable vit à part de ce qui est interne).
- **MYLIB-2 — audiences & gardes.** SELECT vitrine = **membres actifs only** (pas d'`anon` à ce niveau — l'anon passe par PUBLIB) ; **édition `coordOnly`** via `upsert_library_public_contact`.
- **MYLIB-3 — logo data-driven.** Le logo de la carte se lit sur `library_commons.logo_url` / `logo_file_key` (`resolveLogoData(commons)`), **jamais** un `LIBRARY_LOGO_MAP` codé en dur ; repli texte ; la carte n'est **jamais masquée** faute de logo. *(MYLIB-6 : `layout/index.jsx` dé-hardcodé, migration `btl_logo_url_cleanup`.)*
- **MYLIB-4 — « écrire à ma biblio » = in-système, jamais `mailto:`.** Le message persiste dans `reader_library_messages` → trigger → `notify-event` ; **anti-spam ≤ 3 / 24 h / lecteur·rice / biblio** ; accusé de réception.
- **MYLIB-5 — canal réciproque biblio→lecteur·rice = mail-only.** RPC `api.send_message_to_reader` ; **anti-spam 30 / 24 h** ; mail **au destinataire seul** (sans copie staff ni `actionBox`), dans **sa** langue.

---

## 2. Modèle de données

- **`public.library_public_contact`** — la vitrine opt-in (membre, et anon via PUBLIB). Distincte de **`public.library_contact_profiles`** (coordonnées internes confidentielles, non montrées).
- **`public.reader_library_messages`** — le fil de messages : `library_id`, `sender_id`, **`direction`** (`reader` | `library`, défaut `reader`), `subject`, `body` (CHECK 1–4000 car.), **`mail_status`** (`pending`…), `recipient_id`, `created_at`, archivage staff (`staff_archived_at/by`) + suppression (`deleted_at/by`).
- **`public.library_commons`** — porte `logo_url` / `logo_file_key` (source data-driven du logo, MYLIB-3).

---

## 3. Vitrine de contact (MYLIB-1/2/3)

- **`public.upsert_library_public_contact(p_library_id, p_profile jsonb) → library_public_contact`** — `authenticated`, REVOKE PUBLIC, **garde coordenador**. Édite la carte montrée aux membres (et, sous PUBLIB opt-in `is_public`, à l'anon).
- **Côté lecteur·rice** : `MyLibraryContactCard` (dans `/conta`, `AccountPage`). **Côté biblio** : l'éditeur de vitrine dans `BibliotecaPage`.

---

## 4. Messagerie bidirectionnelle (MYLIB-4/5)

Une seule table, deux sens distingués par `direction`, deux triggers `AFTER INSERT` conditionnels :

- **Lecteur·rice → biblio** (`direction='reader'`) : insertion (anti-spam ≤ 3/24 h) → **`trg_reader_message_dispatch`** → `fn_reader_message_dispatch` → `notify-event` (la biblio est notifiée). Canal **in-système** (MYLIB-4).
- **Biblio → lecteur·rice** (`direction='library'`) : **`api.send_message_to_reader(p_library_id, p_reader_id, p_subject, p_body)`** (`authenticated`, REVOKE PUBLIC, anti-spam 30/24 h) → insertion → **`trg_library_message_dispatch`** → `fn_library_message_dispatch` → **mail au destinataire seul** (MYLIB-5).

*(MYLIB-7 : le dispatcher a été renommé `fn_dispatch_circulation_notify_event` → `fn_dispatch_notify_event`, 13 appelants réécrits — nom générique car il sert tous les domaines.)*

---

## 5. Points ouverts / hors-périmètre

- **MYLIB-O1 — « chat ouvert » in-app** (fil bidirectionnel persistant temps réel) : 🟡 **reporté** (on attend une demande réelle). **v1 = mail-only des deux côtés** + persistance du fil.

---

## 6. Annexe — artefacts (vérifiés dans le baseline `20260510000000_baseline_live.sql`)

- **Tables** : `public.library_public_contact`, `public.library_contact_profiles` (distinct, confidentiel), `public.reader_library_messages` (direction/mail_status/anti-spam/archivage), `public.library_commons` (logo).
- **Fonctions** : `public.upsert_library_public_contact` (coord) ; `api.send_message_to_reader` (biblio→lecteur·rice) ; triggers `fn_reader_message_dispatch` / `fn_library_message_dispatch` (+ `trg_*`).
- **Frontend** : `src/components/account/MyLibraryContactCard.jsx` (`/conta`), éditeur de vitrine dans `BibliotecaPage`, `resolveLogoData` (`layout/index.jsx`).
- **Décisions REGISTRE** : §25 MYLIB-1..7 + O1. Cousine : §31 PUBLIB (couche anon opt-in, même table contact). Notif : §6.

---
*Spec produit le 18/06/2026 (session « Audit 360 — remise à niveau P0/P1 »), consolidation a posteriori d'un chantier livré-clos le 04/06 qui n'avait qu'une trace. Reste « ouvert » : MYLIB-O1 (chat in-app temps réel), volontairement reporté.*
