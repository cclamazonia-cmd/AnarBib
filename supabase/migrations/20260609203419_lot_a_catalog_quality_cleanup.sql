-- ════════════════════════════════════════════════════════════════════════════
-- LOT A — Nettoyage catalogue qualite (sans risque, zero perte de donnees)
-- Auteur  : Xavier + Claude
-- Session : Catalogacao work completion
-- Date    : 2026-06-09 (UTC)
--
-- OBJET : Corrections automatisables issues de l'audit qualite catalogue.
--   1. Normalisation des valeurs de langue (codes ISO → noms complets)
--   2. Suppression des 10 auteur*rices orphelin*es (doublons exacts, 0 livre)
--   3. Nettoyage sort_name : point final parasite, guillemets, casse
--   4. Nettoyage titres : double espace
--   5. Correction coquilles editeurs + guillemet orphelin
-- ════════════════════════════════════════════════════════════════════════════

-- ── 1. Normaliser les langues ───────────────────────────────────────────────
-- 8 fiches au total : codes ISO courts ou coquilles → noms complets
-- (forme majoritaire du catalogue : Portugues, Espanhol, Ingles, etc.)
UPDATE public.books SET idioma = 'Português' WHERE idioma = 'pt-BR';
UPDATE public.books SET idioma = 'Espanhol'  WHERE idioma IN ('es', 'Espanha');
UPDATE public.books SET idioma = 'Inglês'    WHERE idioma = 'en';

-- ── 2. Supprimer les auteur*rices orphelin*es ───────────────────────────────
-- 10 fiches : doublons exacts (similarite trigram = 1.0) ayant 0 livre
-- rattache. Ce sont les fantomes de la fiche dupliquee.
-- Garde-fou : le WHERE NOT EXISTS empeche la suppression si un livre a ete
-- rattache entre l'audit et l'application de cette migration.
--
-- IDs :  10491 DE CLEYRE, Voltairine  (doublon de 10490)
--        10501 DIAS, Everardo         (doublon de 10500)
--        10579 FERREIRA, Maria Nazareth (doublon de 10578)
--        10803 LIPIANSKY, Edmond Marc (doublon de 10802)
--        10841 MAGON, Ricardo Flores  (doublon de 10840)
--        10857 MARCOS, Sous Commandant insurge (doublon de 10856)
--        10941 MUSSET, Alfred De      (doublon de 10940)
--        11209 STEIN, Jeff            (doublon de 11208)
--        11273 VELLA, Randolfo        (doublon de 11272)
--        11317 ZENONI, Federico       (doublon de 11316)
DELETE FROM public.authors
WHERE id IN (10491, 10501, 10579, 10803, 10841, 10857, 10941, 11209, 11273, 11317)
  AND NOT EXISTS (SELECT 1 FROM public.book_authors ba WHERE ba.author_id = authors.id);

-- ── 3. Nettoyage sort_name ──────────────────────────────────────────────────

-- 3a. Point final parasite : "MORAES, Wallace." → "MORAES, Wallace"
--     (le point n'est pas une initiale, c'est une coquille de saisie)
UPDATE public.authors SET sort_name = 'MORAES, Wallace'
WHERE id = 10915 AND sort_name = 'MORAES, Wallace.';

-- 3b. Guillemets parasites dans sort_name :
--     'SINDICALISTA", Equipo "El' → 'SINDICALISTA, Equipo El'
UPDATE public.authors
SET sort_name = 'SINDICALISTA, Equipo El'
WHERE id = 11178 AND sort_name LIKE '%SINDICALISTA%';

-- 3c. Casse : "ABAD DE SANTILLAN, DIego" → "Diego" (i minuscule)
UPDATE public.authors SET sort_name = 'ABAD DE SANTILLÁN, Diego'
WHERE id = 24 AND sort_name = 'ABAD DE SANTILLÁN, DIego';

-- ── 4. Nettoyage titres ─────────────────────────────────────────────────────
-- Double espace dans le titre du livre #2661
-- "Organismo  Economico da Revolucao" → "Organismo Economico da Revolucao"
UPDATE public.books
SET titulo = regexp_replace(titulo, '  +', ' ', 'g')
WHERE id = 2661 AND titulo ~ '  ';

-- ── 5. Coquilles editeurs ───────────────────────────────────────────────────

-- 5a. Suffixes dupliques / lettres en trop (coquilles de saisie)
UPDATE public.books SET editora = 'Editora Símbolo'
WHERE editora = 'Editora Símbololo';

UPDATE public.books SET editora = 'Gallimard'
WHERE editora = 'Galllimard';

UPDATE public.books SET editora = 'Editora Hedra'
WHERE editora = 'Editora Hedrara';

UPDATE public.books SET editora = 'Editora Imaginário'
WHERE editora = 'Editora Imaginárioário';

-- 5b. Guillemet orphelin : 'Faisca Publicacoes Libertarias"' (guillemet
--     fermant sans ouvrant) → forme propre
UPDATE public.books
SET editora = 'Faísca Publicações Libertárias'
WHERE editora = E'Faísca Publicações Libertárias"';

NOTIFY pgrst, 'reload schema';
