-- =========================================================================
-- Paquet SECU-SEARCHPATH — Fige le search_path de fn_block_rme_modification
-- =========================================================================
-- Date     : 2026-06-23
-- Chantier : hygiène sécurité (advisors Supabase)
-- Auteur   : session Claude (suite audit externe 2026-06-23, §5.2)
--
-- Contexte : l'unique advisor « Function Search Path Mutable » restant
-- (lint 0011) pointe public.fn_block_rme_modification — fonction-garde
-- (trigger) qui rend immuable le journal d'audit reader_membership_events.
-- Le corps ne fait que RAISE EXCEPTION (aucune dépendance schéma) : figer le
-- search_path est sans effet fonctionnel, purement durcissant.
--
-- CHECKLIST DOCTRINE (cf. CHANTIER_doctrine_creation_objets_securises) :
--   [x] Touche search_path -> DO block de vérification en fin de transaction
--   [-] Pas de SECURITY DEFINER (fonction trigger, SECURITY INVOKER)
--   [-] Pas de changement de signature -> CREATE OR REPLACE sûr (ACL/trigger conservés)
-- =========================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_block_rme_modification()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog
AS $function$
BEGIN
  RAISE EXCEPTION 'reader_membership_events is immutable: % blocked', tg_op
    USING errcode = '42501', hint = 'Table audit immutable. Aucune modification possible.';
END;
$function$;

-- -------------------------------------------------------------------------
-- Vérification automatique : search_path désormais figé
-- -------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'fn_block_rme_modification'
      AND p.proconfig IS NOT NULL
      AND EXISTS (SELECT 1 FROM unnest(p.proconfig) c WHERE c LIKE 'search_path=%')
  ) THEN
    RAISE EXCEPTION 'SECU-SEARCHPATH : search_path non figé après migration. Rollback automatique.';
  END IF;
  RAISE NOTICE 'SECU-SEARCHPATH OK : fn_block_rme_modification.search_path figé.';
END $$;

COMMIT;

-- =========================================================================
-- Rollback ciblé (restaure la version sans search_path figé) :
-- =========================================================================
-- BEGIN;
--   CREATE OR REPLACE FUNCTION public.fn_block_rme_modification()
--   RETURNS trigger LANGUAGE plpgsql AS $function$
--   BEGIN
--     RAISE EXCEPTION 'reader_membership_events is immutable: % blocked', tg_op
--       USING errcode = '42501', hint = 'Table audit immutable. Aucune modification possible.';
--   END;
--   $function$;
-- COMMIT;
-- =========================================================================
