-- ════════════════════════════════════════════════════════════════════════════
-- Nettoyage advisors Supabase — search_path figé + index dupliqués
-- Auteur  : Claude (Opus)
-- Session : Enrichissement données & backlog
-- Date    : 2026-06-10 (UTC)
--
-- Corrige 2 warnings sécurité + 3 warnings performance signalés par les
-- database advisors Supabase. Périmètre volontairement restreint aux
-- corrections SÛRES et sans effet de bord :
--
--   A. function_search_path_mutable (2) : fige le search_path de 2 fonctions
--      SECURITY INVOKER qui ne l'avaient pas (ne touche pas leur corps).
--   B. duplicate_index (3 tables) : supprime des index strictement redondants
--      (doublons exacts ou couverts par une contrainte/index unique jumeau).
--      Tous sont des index PURS (vérifiés : pas des contraintes) → DROP sûr,
--      les colonnes restent couvertes par leur jumeau.
--
-- NON traités ici (chantiers séparés, pas un « petit nettoyage ») :
--   • security_definer_function_executable (287) : by design pour les RPC
--     PostgREST ; révoquer en masse casserait l'app.
--   • auth_rls_initplan (64) / multiple_permissive_policies (81) : refactor RLS.
--   • unused_index (111) / unindexed_foreign_keys (85) : jugement cas par cas.
--   • materialized_view_in_api (2) : exposition probablement volontaire (OPAC).
-- ════════════════════════════════════════════════════════════════════════════

-- ── A. search_path figé ───────────────────────────────────────────────────
ALTER FUNCTION public.fn_normalize_name(text)
  SET search_path = public, pg_catalog;

ALTER FUNCTION ingest.fn_oai_harvest_state_touch_updated()
  SET search_path = ingest, public, pg_catalog;

-- ── B. Index dupliqués ────────────────────────────────────────────────────
-- book_authors : idx_book_authors_author_id == idx_book_authors_author (author_id)
DROP INDEX IF EXISTS public.idx_book_authors_author_id;

-- exemplares : idx_exemplares_bib_ref == exemplares_bib_ref_idx (bib_ref)
DROP INDEX IF EXISTS public.idx_exemplares_bib_ref;

-- exemplares : idx_exemplares_tombo couvert par l'unique exemplares_unique_tombo
DROP INDEX IF EXISTS public.idx_exemplares_tombo;

-- user_library_memberships : index unique pur redondant avec la contrainte
-- user_library_memberships_user_id_library_id_role_key (user_id, library_id, role)
DROP INDEX IF EXISTS public.user_library_memberships_unique;
