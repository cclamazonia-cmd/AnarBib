---
Genre : trace
Statut : 🟡 cadrée
Décisions : cite FS-D1…D8 (REGISTRE §35 AUDIO), DOC-OBJ-2 (objets sécurisés), works v1/v2 (CADRAGE_oeuvre_v2_2026-06-20)
Supersédé par : —
---

# CADRAGE — Fonds sonores P1 : sous-couche granularité (segments)

- **Date** : 2026-06-21
- **Chantier** : `#AUDIO-fonds`, paquet **P1** (cf. `spec-fonds-sonores` §5/§11 ; REGISTRE §35 `AUDIO`).
- **Prérequis** : **P0 livré** (migration `20260621162441` : `authors.external_ids` MBID + empreinte `book_digital_resources`, en prod, run vert). §5 de la spec **re-ancré sur `works`** le 21/06.
- **Session** : Fonds sonores

> Trace de cadrage. Foyer normatif = `spec-fonds-sonores` (design) + REGISTRE §35 (arbitrages). On cite, on ne recopie pas.

## 0. En une phrase

Ajouter la **granularité intra-document** des fonds sonores — le **segment** d'une captation (intervention, chant) et son **crédit** (locuteur·rice, interprète) — en réutilisant au maximum l'existant : la captation reste une **édition `books`** audio, l'œuvre est `public.works`, les crédits d'édition restent `book_contributors` dérivés vers l'œuvre. Seules **2 tables structurelles + 1 réf** sont nouvelles.

## 1. Arbitrages confirmés (Xavier, 21/06)

1. **`digital_resource_id` sur `audio_tracks`** — inclus dès P1 (segment ↔ fichier précis quand l'édition a plusieurs fichiers). FK nullable vers `book_digital_resources`.
2. **`recording_type` = table de réf** `catalog_ref_audio_recording_types` (axe contrôlé, patron `catalog_ref_*`). OK.
3. **Place/Event = texte** (`place_text`) en P1 ; entité lieu/événement différée (FS-Q2). Confirmé.
4. **RPC d'écriture dans P1** (créer/éditer un segment, ajouter/retirer un crédit), schéma `api`, SECURITY DEFINER, gardées staff.

## 2. Schéma (3 objets nouveaux)

- **`catalog_ref_audio_recording_types`** `(code PK, label, sort_order, is_active)` — patron `catalog_ref_*`. Seed : `captacao_ao_vivo | estudio | radio | campo | entrevista | outro`.
- **`audio_tracks`** (MB *Track*) — `book_id→books CASCADE`, `position`, `title`, `start_offset`, `duration`, `work_id→works SET NULL` (l'œuvre réalisée, **FS-D4**), `digital_resource_id→book_digital_resources SET NULL`, `recording_type→ref`, `recording_date`/`recording_date_approx`/`place_text` (captation au grain segment), `external_ids jsonb` (check objet, MBID), `notes`, audit ; `unique(book_id, position)`. `bigint identity` (cohérent `books`/`works`).
- **`audio_track_contributors`** (MB *Relationship*) — `track_id→audio_tracks CASCADE`, `author_id→authors SET NULL`, `name` (repli non-relié, comme `book_contributors`), `role text` (**texte libre**, vocab pt-BR), `position`, `is_primary`.

**Vocabulaire de rôles segment** (texte libre, aligné sur la convention `book_contributors` constatée en prod — `autor`/`organizador`/`coordenador`/`ator`/`realizador`/`outro`) : ajout de `locutor`, `interprete`, `compositor`, `letrista`, `tecnico_som`, `entrevistador`, `entrevistado`. Pas de table de réf pour les rôles (cohérence avec `book_contributors.role`). Labels i18n = P4.

## 3. Réutilisé tel quel (zéro schéma)

- **Captation = édition `books`** (`tipo_material='audio'`, `work_id`, `expression_id`) — déjà là.
- **Crédits grain édition** = `book_contributors` existant + rôles audio au vocabulaire ; **dérivés** vers l'œuvre via le patron `work_public_detail` (doctrine `works_v3` : la source de vérité reste le lien contributeur↔autorité).
- Colonnes `audio_*` à plat de `books` = niveau édition (durée totale, support, langue).

## 4. Sécurité / visibilité (décision P1)

- **RLS staff-only** sur `audio_tracks` + `audio_track_contributors` en P1 : lecture **réservée au staff** (`librarian`/`coordenador` actif), écriture via RPC SECURITY DEFINER uniquement. La réf des types = lecture publique.
- **Pourquoi staff-only et pas read-all anon (≠ `works`/`work_expressions`)** : les titres de segments d'une édition **non publique/réseau** sont du contenu descriptif fin qu'on ne veut pas fuiter à `anon` ni aux lectrices d'autres bibliothèques. L'exposition **OPAC public-safe** (filtrée via `catalog_list_anon_v1`, comme `work_public_detail`) est **explicitement reportée en P3**. P1 = couche **catalogage** (staff).
- Doctrine `_TEMPLATE` respectée : GRANT explicites, `ENABLE ROW LEVEL SECURITY`, policies, `GRANT ALL TO service_role`, vues `security_invoker=true`, DO-block de vérification.

## 5. RPC (schéma `api`, SECURITY DEFINER, staff-gated, `search_path` figé, REVOKE/GRANT)

- `api.audio_track_upsert(...)` → insert/update d'un segment (valide : book audio, work existe, recording_type valide, digital_resource appartient au book). Retourne l'`id`.
- `api.audio_track_delete(p_track_id)`.
- `api.audio_track_contributor_add(p_track_id, p_name, p_role, p_author_id, p_position, p_is_primary)`.
- `api.audio_track_contributor_remove(p_contributor_id)`.
- Vue de confort staff `public.v_audio_tracklist` (`security_invoker=true`) : segments + titre d'œuvre + contributeurs agrégés.
- Erreurs en codes `error.audio.*` (mapping i18n = P4) ; `NOTIFY pgrst` en fin.

## 6. Hors P1 (rappel)

- **P2** : EF `audio_fingerprint_lookup` (AcoustID, candidat MBID).
- **P3** : UI Catalogação (saisie segments/crédits) + **exposition OPAC public-safe** (vue anon-safe via `catalog_list_anon_v1`).
- **P4** : i18n (10 locales, charte) des types/rôles/erreurs.
- **P5** : exposition MBID via OAI.

## 7. Migration & garde-fous

- **1 fichier** `supabase/migrations/<UTC exact>_audio_p1_tracks_segments_sublayer.sql`, horodatage UTC réel au moment du build, > max présent.
- Idempotent (`IF NOT EXISTS`, guards `pg_policies`/`pg_trigger`), `BEGIN`/`COMMIT`, DO-block de vérif (tables + seed + RPCs + vue).
- **Validation `BEGIN`/`ROLLBACK` contre la prod** (MCP) avant push, comme P0.
- Push **un seul** vers Codeberg, run précédent (P0) vert — sérialisation respectée.
- Au livrable : **REGISTRE §35** FS-D3/FS-D5 passent ✅ (schéma livré) + MàJ ; `spec-fonds-sonores` §11 P1 = livré.
