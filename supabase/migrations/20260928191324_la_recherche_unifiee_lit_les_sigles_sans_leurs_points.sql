-- =========================================================================
-- La recherche unifiée lit les sigles sans leurs points : f_normalize_search
-- plie un sigle sur ses lettres, et tout ce qui la lit suit
-- =========================================================================
-- Date     : 2026-09-28
-- Chantier : suite d'OPAC-F3 (20260928174350) ; décision de Xavier du 28/09,
--            nuit : « la recherche unifiée de l'en-tête ne plie pas les
--            sigles, seule celle du catalogue le fait : on corrige ».
--
-- LE CONSTAT. OPAC-F3 a plié les sigles dans la recherche de la page
-- catalogue (api.catalog_search_ids_v1), qui calcule sa meule à la volée. La
-- recherche unifiée de l'en-tête (api.search_catalog_v1) travaille autrement :
-- elle compare public.f_normalize_search(colonne) à f_normalize_search(requête)
-- par LIKE, ~ et similarité, et ces comparaisons EMPRUNTENT des index trigramme
-- écrits sur f_normalize_search(titulo), f_normalize_search(autor) (les deux
-- vues matérialisées du catalogue), f_normalize_search(preferred_name) et
-- f_normalize_search(sort_name) (autorités), plus la colonne stockée
-- author_name_aliases.alias_norm (B33 : un index trigramme ne sert que si la
-- requête écrit exactement son expression). Plier dans la fonction de recherche
-- seule aurait cassé cet usage. Le pli va donc DANS f_normalize_search :
-- l'index, la colonne stockée et la requête plient de la même main.
--
-- LE GESTE.
--   1. f_normalize_search(input) = fn_sigle_sans_points(lower(unaccent(input))) —
--      même signature, même volatilité (IMMUTABLE, PARALLEL SAFE), NULL → NULL.
--   2. Les index qui la portent se reconstruisent : REINDEX des deux index des
--      autorités ; REFRESH (non concurrent, quelques secondes, de nuit) des
--      deux vues matérialisées, qui rebâtit les leurs. Sans cela, un index
--      calculé avec l'ancienne fonction servirait une requête pliée : des
--      absences silencieuses (l'index dit « pas là » pour un titre présent).
--   3. author_name_aliases.alias_norm, colonne STOCKÉE écrite par les
--      appelants avec f_normalize_search, est recalculée là où elle change ;
--      un alias dont la forme pliée existe déjà, active, chez le même auteur
--      devient inactif (index unique uq_author_name_aliases_norm_active). En
--      production au 28/09 : 0 alias à replier, 0 conflit — le geste est écrit
--      pour les instances qui en auraient.
--   Suivent sans rien recopier : api.search_catalog_v1 (titres, autorités,
--   alias), api.search_subjects et api.fn_serial_search (les deux côtés du LIKE).
--   Effet de bord assumé : fn_serials_autoslug et fn_subjects_autoslug
--   dérivent un slug de f_normalize_search — un périodique ou un sujet CRÉÉ
--   désormais avec « C.N.T. » dans son titre reçoit « cnt » là où il aurait
--   reçu « c-n-t » ; les slugs existants ne bougent pas (le déclencheur ne
--   touche qu'un slug vide).
--   Garde d'entrée sur le md5 de la définition réelle de f_normalize_search
--   (inchangée depuis le baseline). Garde : tests/sql/recherche_sigles_tests.sql
--   T9-T11 ; tests/sql/recherche_index_trigramme_tests.sql (B33) reste la
--   preuve que les index servent toujours.
-- =========================================================================

BEGIN;

DO $entree$
DECLARE v_md5 text;
BEGIN
  SELECT md5(p.prosrc) INTO v_md5 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'f_normalize_search';
  IF v_md5 IS DISTINCT FROM 'cfd93022b31605d201cb3f75e6b31910' THEN
    RAISE EXCEPTION 'sigles unifiée : public.f_normalize_search n''est pas la version attendue (md5 %) — relire sa définition réelle avant de la réécrire', v_md5;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                  WHERE n.nspname = 'public' AND p.proname = 'fn_sigle_sans_points') THEN
    RAISE EXCEPTION 'sigles unifiée : fn_sigle_sans_points absente — 20260928174350 doit précéder';
  END IF;
END
$entree$;

-- 1. La normalisation de recherche plie les sigles.
CREATE OR REPLACE FUNCTION public.f_normalize_search(input text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  SELECT public.fn_sigle_sans_points(lower(extensions.unaccent(input)))
$function$;

COMMENT ON FUNCTION public.f_normalize_search(text) IS
  'Forme de recherche : minuscules, sans accents, sigles pliés sur leurs lettres (« C.N.T. » → « cnt », fn_sigle_sans_points). Portée par les index trigramme des autorités et des vues matérialisées du catalogue, et par author_name_aliases.alias_norm : toute modification exige leur reconstruction (migration 20260928191324).';

-- 3. La colonne stockée des alias suit ; un doublon né du pli devient inactif.
DO $alias$
DECLARE v_repliees int; v_desactivees int;
BEGIN
  UPDATE public.author_name_aliases a
     SET is_active = false
   WHERE a.is_active
     AND a.alias_norm IS DISTINCT FROM public.f_normalize_search(a.alias_text)
     AND EXISTS (SELECT 1 FROM public.author_name_aliases b
                  WHERE b.id <> a.id AND b.author_id = a.author_id AND b.is_active
                    AND b.alias_norm = public.f_normalize_search(a.alias_text));
  GET DIAGNOSTICS v_desactivees = ROW_COUNT;
  UPDATE public.author_name_aliases a
     SET alias_norm = public.f_normalize_search(a.alias_text)
   WHERE a.alias_norm IS DISTINCT FROM public.f_normalize_search(a.alias_text);
  GET DIAGNOSTICS v_repliees = ROW_COUNT;
  RAISE NOTICE 'sigles unifiée : % alias repliés, % doublons désactivés', v_repliees, v_desactivees;
END
$alias$;

-- 2. Les index qui portent la fonction se reconstruisent avec elle.
REINDEX INDEX public.authors_preferred_name_norm_trgm_idx;
REINDEX INDEX public.authors_sort_name_norm_trgm_idx;
REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_v1;
REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_network_v1;
ANALYZE public.mv_books_catalog_list_v1;
ANALYZE public.mv_books_catalog_list_network_v1;

-- ── Vérification : ce que la migration fait, et rien de plus ───────────────
DO $verif$
DECLARE v_n int;
BEGIN
  IF public.f_normalize_search('La C.N.T. y la Revolución Española') <> 'la cnt y la revolucion espanola' THEN
    RAISE EXCEPTION 'sigles unifiée : f_normalize_search ne plie pas (%)', public.f_normalize_search('La C.N.T. y la Revolución Española');
  END IF;
  IF public.f_normalize_search('J. Peirats, ed.') <> 'j. peirats, ed.' THEN
    RAISE EXCEPTION 'sigles unifiée : une abréviation ordinaire a perdu son point';
  END IF;
  IF public.f_normalize_search(NULL) IS NOT NULL THEN RAISE EXCEPTION 'sigles unifiée : NULL doit rester NULL'; END IF;
  SELECT count(*) INTO v_n FROM public.author_name_aliases a
   WHERE a.alias_norm IS DISTINCT FROM public.f_normalize_search(a.alias_text);
  IF v_n > 0 THEN RAISE EXCEPTION 'sigles unifiée : % alias dont alias_norm ne suit pas f_normalize_search', v_n; END IF;
  SELECT count(*) INTO v_n FROM pg_index i
   WHERE i.indexrelid IN ('public.authors_preferred_name_norm_trgm_idx'::regclass, 'public.authors_sort_name_norm_trgm_idx'::regclass,
                          'public.mv_books_catalog_list_v1_titulo_norm_trgm_idx'::regclass, 'public.mv_books_catalog_list_v1_autor_norm_trgm_idx'::regclass,
                          'public.mv_books_catalog_list_network_v1_titulo_norm_trgm_idx'::regclass, 'public.mv_books_catalog_list_network_v1_autor_norm_trgm_idx'::regclass)
     AND i.indisvalid;
  IF v_n <> 6 THEN RAISE EXCEPTION 'sigles unifiée : % index valides sur 6 attendus', v_n; END IF;
  IF (SELECT provolatile FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'public' AND p.proname = 'f_normalize_search') <> 'i' THEN
    RAISE EXCEPTION 'sigles unifiée : f_normalize_search doit rester IMMUTABLE (index d''expression)';
  END IF;
END
$verif$;

COMMIT;
