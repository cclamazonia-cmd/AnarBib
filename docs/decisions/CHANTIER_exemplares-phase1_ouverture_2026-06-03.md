# Dossier d'ouverture — Phase 1 Catalogação : vague mutualisée `exemplares`

> **Genre** : Dossier d'ouverture de chantier (couche *trace*).
> **Statut** : 🟠 Ouvert — 03/06/2026.
> **Décisions citées** : `CAT-B1..B7`, `ACQ-Q1..Q6` · `DOC-MODELE-1`, `DOC-DEPLOY-1`, `DOC-OBJ-2`, `DOC-RPC-3`, `DOC-RLS-1`, `DOC-I18N-1`, `DOC-CLOSE-1`.
> **Supersédé par** : —

**Specs de référence** : `spec-exemplaires-circulation.md` v0.2 (destination, doublons) + `spec-acquisition-provenance-v0_1.md` (provenance) — couche *référence*.
**Pré-requis** : `#MODEL-item-grain` cœur **livré** (cf. `CLOTURE_MODEL-item-grain_2026-06-03.md`) → `CAT-B7` satisfait.
**Place destinée** : `docs/decisions/`.

---

## 1. Pourquoi c'est la pierre angulaire restante

Le cœur item-grain étant en prod, la **Phase 1** est désormais le nœud le plus en aval-bloquant du chemin critique Catalogação. Elle ajoute à l'exemplaire ses deux couches manquantes — **provenance** (d'où il vient) et **destination** (ce qu'il autorise / qui le voit) — et débloque en cascade :

- **Phase 2** : `padrão → seed → override`, **matrice d'actions lecteur** (`spec-exemplaires-circulation` §6), résolution du cas BTL ;
- le **filtre catalogue public** (`visibility = 'public'`) que consomment `spec-catalogue-decouverte` et `spec-notice-autorite-enrichie` (cluster #OPAC) ;
- `#ILL-digital` (verrou libre-de-droits sur `visibility`/`CAT-B3`) ;
- la chaîne d'**acquisition** (provenance d'exemplaire = socle de l'échange réseau futur).

Toujours **indépendant de #110** : rien n'attend Resend.

## 2. Périmètre de CE dossier

**Au cœur (cette ouverture) :** la **migration mutualisée** (`CAT-B6` / `ACQ-Q1` / Q9) — colonnes provenance **et** destination sur `exemplares` + `exemplar_drafts`, **en une seule transaction**, backfill + trigger de validation + DO-block. C'est le §4 ci-dessous.

**Séquencé ensuite (paquets, §5) :** seed du padrão, RPC d'édition intégrant la destination (`CAT-B4`), flux doublon (`api.attach_exemplar` + garde publish, `CAT-B5`), filtre public + matrice, i18n 8 locales, frontend Exemplaires.

**Hors périmètre :** trace (item-grain, livré) ; `acquisition_desiderata` (`ACQ-Q2`, table distincte — pas dans la vague `exemplares`) ; `reception_event` (`ACQ-Q3`, suite) ; le champ fiche « Circulação local padrão » 3-valeurs (relève de `spec-catalogacao-fiche-et-paliers`, Track A).

## 3. Réconciliation des deux specs avant migration (à valider)

Le schéma de prod (03/06) impose trois clarifications — flaggées pour éviter une migration à l'aveugle :

1. **`source_library` (acquisition §5.1) est la bonne colonne, pas `owner_library`.** Le vocabulaire `owner_library / holder_library / partner_source` existe **uniquement sur `books` / `book_drafts`** (niveau notice, `EA-ACQ-2` : à déprécier, pas à recopier). Sur l'exemplaire, le détenteur est déjà `exemplares.library_id` (NOT NULL). On ajoute donc **`source_library` (text)** = l'**origine** (don/troca : collectif, personne, biblio), distincte du détenteur. La ligne « provenance » de `spec-exemplaires-circulation` §2 qui cite `owner_library/holder_library` est une reprise lâche du vocabulaire notice — **`acquisition §5.1` fait foi** (4 colonnes).
2. **Backfill `circulation_policy` = dérivé de `books.loanable`** (seul champ de circulation présent aujourd'hui) : `emprestavel` si `loanable`, sinon `consulta`. Le padrão fiche 3-valeurs n'existe pas encore → on ne s'appuie pas dessus pour le backfill.
3. **`owner_library` du flux doublon** (`api.attach_exemplar`, §7.1) = `exemplares.library_id` (biblio courante). `api.attach_exemplar` **n'existe pas** encore (paquet §5.3).

## 4. Migration mutualisée — co-rédigée (draft à réviser)

> **À placer** dans `supabase/migrations/<UTC>_exemplares_provenance_destination.sql`. **Timestamp UTC à fixer par Xavier** (vérifier l'horloge avant de choisir — `DOC-DEPLOY-1`). Déploiement : `git push` → Woodpecker (jamais `apply_migration` MCP, jamais SQL Editor). `npm run build` avant push. **Une seule vague** sur `exemplares` (`CAT-B6` / §12 vigilance).
>
> Points marqués **`-- ⚠️ CONFIRMER`** = décisions de design laissées ouvertes par les specs (voir §6).

```sql
BEGIN;

-- =====================================================================
-- Phase 1 Catalogação — vague mutualisée exemplares + exemplar_drafts
-- PROVENANCE (acquisition §5.1, ACQ-Q1) + DESTINATION (exemplaires §4.1, CAT-B1..B3)
-- Pré-requis : #MODEL-item-grain cœur livré (CAT-B7). Une seule transaction (CAT-B6).
-- =====================================================================

-- 1) Couche PROVENANCE (acquisition §5.1) ------------------------------
ALTER TABLE public.exemplares
  ADD COLUMN acquisition_mode text,     -- code logique -> catalog_ref_acquisition_modes.code
  ADD COLUMN acquisition_date date,
  ADD COLUMN provenance_note  text,
  ADD COLUMN source_library   text;     -- origine (don/troca) ; != library_id (detenteur)

ALTER TABLE public.exemplar_drafts
  ADD COLUMN acquisition_mode text,
  ADD COLUMN acquisition_date date,
  ADD COLUMN provenance_note  text,
  ADD COLUMN source_library   text;

-- 2) Couche DESTINATION (exemplaires §4.1, B1 text+CHECK) --------------
ALTER TABLE public.exemplares
  ADD COLUMN circulation_policy text,                       -- emprestavel|consulta|ambos (seed padrao)
  ADD COLUMN visibility text NOT NULL DEFAULT 'public';     -- public|staff_only (=arquivo)

ALTER TABLE public.exemplares
  ADD CONSTRAINT exemplares_circulation_policy_chk
    CHECK (circulation_policy IS NULL
           OR circulation_policy = ANY (ARRAY['emprestavel','consulta','ambos'])),
  ADD CONSTRAINT exemplares_visibility_chk
    CHECK (visibility = ANY (ARRAY['public','staff_only']));

ALTER TABLE public.exemplar_drafts
  ADD COLUMN circulation_policy text,
  ADD COLUMN visibility text NOT NULL DEFAULT 'public';

ALTER TABLE public.exemplar_drafts
  ADD CONSTRAINT exemplar_drafts_circulation_policy_chk
    CHECK (circulation_policy IS NULL
           OR circulation_policy = ANY (ARRAY['emprestavel','consulta','ambos'])),
  ADD CONSTRAINT exemplar_drafts_visibility_chk
    CHECK (visibility = ANY (ARRAY['public','staff_only']));

-- 3) BACKFILL (exemplaires §4.2) : 2461 exemplaires ------------------
--    visibility couvert par DEFAULT 'public' ; circulation_policy derive de books.loanable
UPDATE public.exemplares e
SET circulation_policy = CASE WHEN b.loanable THEN 'emprestavel' ELSE 'consulta' END
FROM public.book_holdings h
JOIN public.books b ON b.id = h.book_id
WHERE e.holding_id = h.id
  AND e.circulation_policy IS NULL;

-- exemplaires sans holding (holding_id NULL) -> defaut prudent
UPDATE public.exemplares
SET circulation_policy = 'consulta'
WHERE circulation_policy IS NULL;

-- ⚠️ CONFIRMER : NOT NULL sur exemplares.circulation_policy apres backfill
--    (drafts laisses nullables : policy decidee a l'edition/publish)
ALTER TABLE public.exemplares
  ALTER COLUMN circulation_policy SET NOT NULL;

-- 4) Validation acquisition_mode in referentiel (acquisition §5.1 ; DOC-OBJ-2)
-- ⚠️ CONFIRMER : trigger (ci-dessous) vs confiance RPC seule
CREATE OR REPLACE FUNCTION public.fn_validate_acquisition_mode()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
AS $fn$
BEGIN
  IF NEW.acquisition_mode IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM public.catalog_ref_acquisition_modes
       WHERE code = NEW.acquisition_mode AND is_active
     ) THEN
    RAISE EXCEPTION 'acquisition_mode % inconnu ou inactif', NEW.acquisition_mode
      USING errcode = 'P0001';
  END IF;
  RETURN NEW;
END;
$fn$;

REVOKE ALL ON FUNCTION public.fn_validate_acquisition_mode()
  FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER trg_validate_acquisition_mode_exemplares
  BEFORE INSERT OR UPDATE OF acquisition_mode ON public.exemplares
  FOR EACH ROW EXECUTE FUNCTION public.fn_validate_acquisition_mode();

CREATE TRIGGER trg_validate_acquisition_mode_exemplar_drafts
  BEFORE INSERT OR UPDATE OF acquisition_mode ON public.exemplar_drafts
  FOR EACH ROW EXECUTE FUNCTION public.fn_validate_acquisition_mode();

-- 5) DO-block de verification (DOC-OBJ-2 ; information_schema ; RAISE = rollback)
DO $do$
DECLARE
  v_missing text;
BEGIN
  -- colonnes presentes sur les deux tables
  SELECT string_agg(t || '.' || c, ', ') INTO v_missing
  FROM (VALUES
    ('exemplares','acquisition_mode'),('exemplares','acquisition_date'),
    ('exemplares','provenance_note'),('exemplares','source_library'),
    ('exemplares','circulation_policy'),('exemplares','visibility'),
    ('exemplar_drafts','acquisition_mode'),('exemplar_drafts','acquisition_date'),
    ('exemplar_drafts','provenance_note'),('exemplar_drafts','source_library'),
    ('exemplar_drafts','circulation_policy'),('exemplar_drafts','visibility')
  ) AS x(t,c)
  WHERE NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name=x.t AND column_name=x.c
  );
  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'colonnes absentes : %', v_missing;
  END IF;

  -- backfill complet sur exemplares
  IF EXISTS (SELECT 1 FROM public.exemplares WHERE circulation_policy IS NULL) THEN
    RAISE EXCEPTION 'backfill circulation_policy incomplet (exemplares)';
  END IF;
  IF EXISTS (SELECT 1 FROM public.exemplares WHERE visibility IS NULL) THEN
    RAISE EXCEPTION 'visibility NULL (exemplares)';
  END IF;

  -- CHECK actifs
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='exemplares_visibility_chk') THEN
    RAISE EXCEPTION 'CHECK visibility absent';
  END IF;
END
$do$;

COMMIT;
```

## 5. Suite des paquets (séquence `spec-exemplaires-circulation` §11)

| # | Paquet | Spec | Décisions | Statut |
|---|---|---|---|---|
| P1.1 | **Migration mutualisée** (ci-dessus) | exempl. §4.2 + acq. §5.1 | `CAT-B6`, `ACQ-Q1` | 🟢 PRÊT (draft §4) |
| P1.2 | **Seed padrão → exemplaire** + **RPC d'édition** intégrant `circulation_policy`/`visibility` (pas de RPC dédiée) | exempl. §5, §8 | `CAT-B4`, `DOC-RPC-3` | ⬜ |
| P1.3 | **Doublon fédéré** : garde au publish (`RAISE` + `hint` localisé) + `api.attach_exemplar` (`SECURITY DEFINER`, `REVOKE`, staff actif) | exempl. §7 | `CAT-B5`, `DOC-OBJ-2` | ⬜ |
| P1.4 | **Filtre public** (`visibility='public'` en vue/RLS) + **matrice d'actions** lecteur | exempl. §6 | `CAT-B3`, `DOC-PERIM-1` | ⬜ (coordonné item-grain §6.2 — déjà livré) |
| P1.5 | **i18n 8 locales** (libellés policy/visibility, bandeau doublon, `hint`) | exempl. §10 | `DOC-I18N-1` | ⬜ |
| P1.6 | **Frontend** Catalogação → Exemplaires (sélecteur policy pré-rempli + bascule visibility + bandeau doublon) ; + UX optionnelle item-grain §6.1 | exempl. §9 | `DOC-PS-1` (scripts i18n) | ⬜ |

## 6. Points à confirmer (avant push de P1.1)

1. **`exemplares.circulation_policy NOT NULL`** après backfill (recommandé) ; **`exemplar_drafts` laissé nullable** (policy décidée à l'édition/publish). OK ?
2. **Validation `acquisition_mode`** : trigger `SECURITY DEFINER` (inclus) **ou** confiance RPC seule ? La spec acq. §5.1 hésite (« trigger ou CHECK via fonction »). Reco : garder le trigger (défense en profondeur, peu coûteux).
3. **`source_library`** retenu comme colonne d'origine (vs ne rien ajouter et tout mettre en `provenance_note`) ? Reco : garder `source_library` (requêtable pour l'échange réseau futur).
4. **Timestamp UTC** de la migration — à fixer par toi.

## 7. Garde-fous & critères de clôture P1.1

**Garde-fous** : une seule vague sur `exemplares` (jamais deux `ALTER` séparés → `relation already exists`) ; backfill prudent + DO-block ; `DROP+CREATE` si une signature RPC change en P1.2 (`DOC-OBJ-2`) ; ne pas livrer la matrice (P1.4) isolément — elle suppose la trace (livrée) **et** la destination (P1.1).

**Clôture P1.1** : 6 colonnes présentes sur les 2 tables ; 2461 exemplaires backfillés (0 `circulation_policy` NULL, 0 `visibility` NULL) ; CHECK actifs ; trigger de validation en place + REVOKE ; DO-block passant ; migration verte sur Woodpecker ; `npm run build` vert avant push.

---

*Fin du dossier d'ouverture Phase 1. Trace non-normative — `spec-exemplaires-circulation` v0.2 et `spec-acquisition-provenance` v0.1 font foi. La migration §4 est un draft à réviser, pas un fichier à pousser tel quel.*
