-- ════════════════════════════════════════════════════════════════════════════
-- Enrichissement catalogue — langue + éditeur via lookup ISBN (Phase 1 resserrée)
-- Auteur  : Xavier + Claude
-- Session : Catalogação work completion
-- Date    : 2026-06-10 (UTC)
--
-- OBJET : Remplit des champs VIDES (langue, et un éditeur) à partir de
-- correspondances ISBN-exactes obtenues via l'Edge Function
-- catalog_metadata_lookup (sources : BnF + Open Library, match `isbn_exact`).
--
-- PÉRIMÈTRE & DOCTRINE QUALITÉ :
--   - LANGUE seulement (12 livres) + 1 ÉDITEUR. Pas de CDD (sources mêlent
--     Dewey/CDU + bruit), pas d'ANNÉE (à vérifier sur colophon — décision Xavier).
--   - Langues retenues : MARC BnF (français, fiable) ou « Português » sur ISBN
--     brésilien (a priori très sûr). id 2218 = Francês sur connaissance directe
--     de Xavier (don personnel), l'outil ayant renvoyé une langue erronée.
--   - Garde `WHERE colonne vide` : idempotent + ne réécrit jamais une valeur
--     qu'une autre session aurait posée entre-temps.
-- ════════════════════════════════════════════════════════════════════════════

-- Langue = Português (livres brésiliens, ISBN br, match isbn_exact)
UPDATE public.books SET idioma = 'Português'
 WHERE id IN (2228, 2245, 2264, 2285, 2305, 2322, 2438)
   AND (idioma IS NULL OR btrim(idioma) = '');

-- Langue = Francês (2217/2274/2386 via MARC BnF ; 2218 via Xavier)
UPDATE public.books SET idioma = 'Francês'
 WHERE id IN (2217, 2218, 2274, 2386)
   AND (idioma IS NULL OR btrim(idioma) = '');

-- Éditeur manquant (id 1120, via BnF) — forme propre « Companhia das Letras »
UPDATE public.books SET editora = 'Companhia das Letras'
 WHERE id = 1120
   AND (editora IS NULL OR btrim(editora) = '');

NOTIFY pgrst, 'reload schema';
