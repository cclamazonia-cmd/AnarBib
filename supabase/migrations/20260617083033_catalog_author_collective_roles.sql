-- ════════════════════════════════════════════════════════════════════════════
-- Catalogue : afficher les auteur·rices COLLECTIFS + unifier les rôles
-- ════════════════════════════════════════════════════════════════════════════
-- Date    : 2026-06-17 08:30 UTC (horodatage réel)
-- Session : Correctif auteurs collectifs (catalogage)
-- Auteur  : Xavier + Claude (Opus)
--
-- POURQUOI
--   La colonne Auteur du catalogue vient de mv_books_catalog_list_v1.author_display
--   = COALESCE(v_book_authors_canonical.author_display, books.autor). Or la vue
--   `v_book_authors_canonical` ne gardait que `role = 'autor'` → elle EXCLUAIT les
--   auteurs collectifs/organisations (rôles coletivo/organizacao/organizador). Un
--   collectif ne s'affichait que si le vieux texte `books.autor` était rempli en
--   doublon → documents à auteur collectif affichés « — » (ex. 1º de Maio Classista,
--   Puxirum). Bug général, pas spécifique à un collectif.
--
-- CORRECTIF
--   1. Unifier le rôle legacy `coletivo` (import BTL, hors taxonomie du formulaire)
--      vers `organizacao` (rôle canonique du bouton « + Collectif/Organisation »).
--      ⚠️ Le trigger trg_sync_book_authors (fn_sync_book_authors_from_contributor)
--      NE retire PAS la ligne book_authors de l'ancien rôle quand author_id est
--      inchangé (il insère seulement la nouvelle). On normalise donc via
--      book_contributors (le trigger crée les lignes 'organizacao' dans book_authors)
--      PUIS on supprime les lignes 'coletivo' résiduelles de book_authors.
--      `organizador` est laissé tel quel (rôle distinct = organisateur·rice, personnes).
--   2. Élargir v_book_authors_canonical aux rôles d'auteur (autor, coautor,
--      organizacao, organizador) — 'coletivo' gardé par TOLÉRANCE (au cas où un import
--      legacy en recrée) bien que normalisé ici. security_invoker=true préservé.
--
-- NOTE  La vue n'était dans AUCUNE migration (prod-only) ; cette migration la trace.
--       La correction de la vue + la normalisation ont été appliquées LIVE le 17/06
--       via MCP (clone occupé) ; ce fichier est l'équivalent idempotent (CREATE OR
--       REPLACE + UPDATE/DELETE WHERE role='coletivo' = no-op si déjà fait).
--       L'affichage (author_display) est INCHANGÉ par la normalisation (organizacao
--       rend la même chose que coletivo) → pas de REFRESH de MV nécessaire ici
--       (le cron refresh_mv_books_catalog_list_v1 maintient la MV).
-- ════════════════════════════════════════════════════════════════════════════

-- ── 1. Normalisation des rôles collectifs legacy ───────────────────────────────
UPDATE public.book_contributors SET role = 'organizacao' WHERE role = 'coletivo';
DELETE FROM public.book_authors  WHERE role = 'coletivo';

-- ── 2. Vue canonique : inclure les rôles d'auteur collectif ────────────────────
CREATE OR REPLACE VIEW public.v_book_authors_canonical WITH (security_invoker=true) AS
 WITH canon_source AS (
         SELECT bc.book_id,
            bc.author_id,
            bc."position" AS ord,
            COALESCE(NULLIF(btrim(a.sort_name), ''::text), NULLIF(btrim(a.preferred_name), ''::text), NULLIF(btrim(bc.name), ''::text)) AS base_name
           FROM (public.book_contributors bc
             LEFT JOIN public.authors a ON ((a.id = bc.author_id)))
          WHERE (bc.role = ANY (ARRAY['autor'::text, 'coautor'::text, 'coletivo'::text, 'organizacao'::text, 'organizador'::text]))
        ), canon AS (
         SELECT canon_source.book_id,
            canon_source.author_id,
            canon_source.ord,
                CASE
                    WHEN (canon_source.base_name IS NULL) THEN NULL::text
                    WHEN (POSITION((','::text) IN (canon_source.base_name)) > 0) THEN (upper(TRIM(BOTH FROM split_part(canon_source.base_name, ','::text, 1))) ||
                    CASE
                        WHEN (NULLIF(TRIM(BOTH FROM SUBSTRING(canon_source.base_name FROM (POSITION((','::text) IN (canon_source.base_name)) + 1))), ''::text) IS NOT NULL) THEN (', '::text || TRIM(BOTH FROM SUBSTRING(canon_source.base_name FROM (POSITION((','::text) IN (canon_source.base_name)) + 1))))
                        ELSE ''::text
                    END)
                    ELSE canon_source.base_name
                END AS display_name
           FROM canon_source
        )
 SELECT book_id,
    string_agg(display_name, ' ; '::text ORDER BY ord, display_name) AS author_display,
    jsonb_agg(jsonb_build_object('author_id', author_id, 'label', display_name, 'ord', ord) ORDER BY ord, display_name) AS author_chips
   FROM canon
  GROUP BY book_id;

-- ── 3. Vérification de non-régression ──────────────────────────────────────────
DO $verif$
DECLARE
  v_def       text := pg_get_viewdef('public.v_book_authors_canonical'::regclass);
  v_coletivo  int;
BEGIN
  IF position('organizacao' IN v_def) = 0 THEN
    RAISE EXCEPTION 'VERIF: la vue ne reference pas le role organizacao';
  END IF;
  SELECT count(*) INTO v_coletivo
    FROM public.book_contributors WHERE role = 'coletivo';
  IF v_coletivo <> 0 THEN
    RAISE EXCEPTION 'VERIF: il reste % contributeurs role=coletivo (normalisation incomplete)', v_coletivo;
  END IF;
  SELECT count(*) INTO v_coletivo
    FROM public.book_authors WHERE role = 'coletivo';
  IF v_coletivo <> 0 THEN
    RAISE EXCEPTION 'VERIF: il reste % book_authors role=coletivo (nettoyage incomplet)', v_coletivo;
  END IF;
END
$verif$;
