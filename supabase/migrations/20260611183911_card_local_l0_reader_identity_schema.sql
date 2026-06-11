-- ════════════════════════════════════════════════════════════════════════════
-- CARD-LOCAL — Identité lecteur·rice locale — Lot 0 : socle schéma
-- Auteur  : Claude (Opus)
-- Session : Identité lecteur·rice locale (Lot 0)
-- Date    : 2026-06-11 (UTC)
-- Registre: §27 CARD-LOCAL (CARD-LOCAL-2/3/5/6/UNIQ) ; étend MULTI-E.2 (§20)
--
-- Additif et sûr (aucun backfill destructif ; les colonnes NOT NULL ont un DEFAULT
-- rétro-compatible). Pose le socle de données du chantier :
--   1) libraries.reader_identity_model    {free_number·sequenced_number·name·none}
--   2) libraries.reader_validation_mode   {presential·remote·none}
--   3) user_library_memberships.imported_from_legacy   (bool)
--   4) Unicité de l'identité locale : l'index unique `ux_ulm_local_reader_number`
--      est REMPLACÉ par un TRIGGER conditionnel (CARD-LOCAL-UNIQ + CARD-LOCAL-6).
--
-- Notes de conception (cas-limites débusqués avant code) :
-- • « dernier identifiant attribué » (hint N5) = DÉRIVÉ en RPC coordenador (Lot 3),
--   PAS de colonne cache : `libraries` est anon-lisible (`libraries_public_read`),
--   une colonne « dernier numéro » fuiterait ~le compteur de lecteur·rices à anon ;
--   la dérivation évite aussi tout cache obsolète.
-- • `reader_identity_model` / `reader_validation_mode` = enums de config, anon-
--   lisibles via `libraries_public_read` : VOLONTAIRE, aucune donnée sensible
--   (ni PII ni compteur). À basculer en table privée coordenador si décidé plus tard.
-- • Pourquoi un trigger et non un index partiel : l'unicité est levée en mode
--   `name` (homonymes tolérés), or le modèle vit sur `libraries` (autre table) —
--   un index partiel ne peut pas conditionner sur une autre table. Compromis
--   assumé : on perd la garantie d'index au profit d'un trigger ; toutes les
--   écritures passant par des RPC, l'intégrité reste tenue en pratique (race
--   théorique sous forte concurrence — non pertinent ici, attribution staff).
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1) libraries : modèle d'identité + mode de validation (CARD-LOCAL-2 / -3) ──
ALTER TABLE public.libraries
  ADD COLUMN IF NOT EXISTS reader_identity_model text NOT NULL DEFAULT 'free_number'
    CONSTRAINT libraries_reader_identity_model_check
    CHECK (reader_identity_model IN ('free_number','sequenced_number','name','none')),
  ADD COLUMN IF NOT EXISTS reader_validation_mode text NOT NULL DEFAULT 'presential'
    CONSTRAINT libraries_reader_validation_mode_check
    CHECK (reader_validation_mode IN ('presential','remote','none'));

COMMENT ON COLUMN public.libraries.reader_identity_model IS
  'Modèle d''identité lecteur·rice de la biblio (CARD-LOCAL-2). Pilote l''unicité : '
  'free_number/sequenced_number = unique ; name = homonymes tolérés ; none = pas de schéma. '
  'Défaut free_number (rétro-compatible avec l''ancien index unique).';
COMMENT ON COLUMN public.libraries.reader_validation_mode IS
  'Mode de validation de la biblio (CARD-LOCAL-3) : presential (1er passage) / '
  'remote (identité envoyée par e-mail) / none (accès direct). Pilote le message à la lectrice.';

-- ── 2) user_library_memberships : marqueur legacy (CARD-LOCAL-5) ──────────────
ALTER TABLE public.user_library_memberships
  ADD COLUMN IF NOT EXISTS imported_from_legacy boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.user_library_memberships.imported_from_legacy IS
  'true = appartenance issue d''un registre papier antérieur à AnarBib (CARD-LOCAL-5). '
  'Posé à l''attribution/import par le staff ; distingue legacy vs AnarBib dans le roster (N3).';

-- ── 3) Unicité conditionnelle : index unique → trigger (CARD-LOCAL-UNIQ / -6) ──
-- L'ancien index imposait l'unicité pour TOUS les statuts et TOUS les modèles.
-- Nouveau contrat : unicité seulement pour les modèles NUMÉRIQUES, sur statuts
-- VIVANTS (exclut removed/terminated → un départ définitif libère l'identité).
DROP INDEX IF EXISTS public.ux_ulm_local_reader_number;

CREATE OR REPLACE FUNCTION public.fn_enforce_local_reader_identity_uniqueness()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_model text;
BEGIN
  -- Pas d'identité, ou statut « mort » (départ définitif) : identité libre,
  -- rien à vérifier (CARD-LOCAL-6).
  IF NEW.local_reader_number IS NULL
     OR NEW.status IN ('removed', 'terminated') THEN
    RETURN NEW;
  END IF;

  -- Modèle d'identité de la biblio : l'unicité ne s'applique qu'aux modèles
  -- NUMÉRIQUES ; levée en mode 'name' (homonymes) et 'none' (CARD-LOCAL-UNIQ).
  SELECT l.reader_identity_model INTO v_model
    FROM public.libraries l
   WHERE l.id = NEW.library_id;

  IF v_model IS DISTINCT FROM 'free_number'
     AND v_model IS DISTINCT FROM 'sequenced_number' THEN
    RETURN NEW;
  END IF;

  -- Collision : même identité, même biblio, sur une appartenance VIVANTE,
  -- autre que la ligne courante.
  IF EXISTS (
    SELECT 1
      FROM public.user_library_memberships m
     WHERE m.library_id = NEW.library_id
       AND m.local_reader_number = NEW.local_reader_number
       AND m.status NOT IN ('removed', 'terminated')
       AND m.id <> NEW.id
  ) THEN
    RAISE EXCEPTION 'Identité lecteur·rice déjà attribuée dans cette bibliothèque'
      USING ERRCODE = 'unique_violation',
            HINT    = 'reader_identity_already_taken';
  END IF;

  RETURN NEW;
END;
$function$;

-- DEFINER + search_path posés AVANT le REVOKE (doctrine). Le trigger exécute la
-- fonction quel que soit le GRANT EXECUTE → REVOKE total sans risque de blocage.
REVOKE EXECUTE ON FUNCTION public.fn_enforce_local_reader_identity_uniqueness()
  FROM PUBLIC, anon, authenticated, service_role;

COMMENT ON FUNCTION public.fn_enforce_local_reader_identity_uniqueness() IS
  'Unicité conditionnelle de local_reader_number (CARD-LOCAL-UNIQ/§27). Remplace '
  'l''index ux_ulm_local_reader_number : impose l''unicité par biblio uniquement pour '
  'les modèles numériques et les statuts vivants (≠ removed/terminated). Lot 0, 11/06/2026.';

DROP TRIGGER IF EXISTS trg_enforce_local_reader_identity_uniqueness
  ON public.user_library_memberships;
CREATE TRIGGER trg_enforce_local_reader_identity_uniqueness
  BEFORE INSERT OR UPDATE OF local_reader_number, status, library_id
  ON public.user_library_memberships
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_enforce_local_reader_identity_uniqueness();

-- ── 4) Vérification automatique (rollback si anomalie) ───────────────────────
DO $verify$
DECLARE
  v_bad text := '';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema='public' AND table_name='libraries'
                   AND column_name='reader_identity_model') THEN
    v_bad := v_bad || ' libraries.reader_identity_model';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema='public' AND table_name='libraries'
                   AND column_name='reader_validation_mode') THEN
    v_bad := v_bad || ' libraries.reader_validation_mode';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema='public' AND table_name='user_library_memberships'
                   AND column_name='imported_from_legacy') THEN
    v_bad := v_bad || ' ulm.imported_from_legacy';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger
                 WHERE tgname='trg_enforce_local_reader_identity_uniqueness'
                   AND tgrelid='public.user_library_memberships'::regclass) THEN
    v_bad := v_bad || ' trigger-manquant';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_indexes
             WHERE schemaname='public' AND indexname='ux_ulm_local_reader_number') THEN
    v_bad := v_bad || ' ancien-index-encore-present';
  END IF;

  IF v_bad <> '' THEN
    RAISE EXCEPTION 'Lot 0 identité locale — vérification échouée :%', v_bad;
  END IF;
  RAISE NOTICE 'Lot 0 identité locale — vérifications OK';
END
$verify$;

-- Recharge le cache de schéma PostgREST (nouvelles colonnes exposées à l'API).
NOTIFY pgrst, 'reload schema';

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- Rollback ciblé en cas de régression post-déploiement :
-- ════════════════════════════════════════════════════════════════════════════
-- BEGIN;
--   DROP TRIGGER IF EXISTS trg_enforce_local_reader_identity_uniqueness ON public.user_library_memberships;
--   DROP FUNCTION IF EXISTS public.fn_enforce_local_reader_identity_uniqueness();
--   CREATE UNIQUE INDEX IF NOT EXISTS ux_ulm_local_reader_number
--     ON public.user_library_memberships (library_id, local_reader_number)
--     WHERE local_reader_number IS NOT NULL;
--   ALTER TABLE public.user_library_memberships DROP COLUMN IF EXISTS imported_from_legacy;
--   ALTER TABLE public.libraries DROP COLUMN IF EXISTS reader_validation_mode;
--   ALTER TABLE public.libraries DROP COLUMN IF EXISTS reader_identity_model;
--   NOTIFY pgrst, 'reload schema';
-- COMMIT;
-- ════════════════════════════════════════════════════════════════════════════
