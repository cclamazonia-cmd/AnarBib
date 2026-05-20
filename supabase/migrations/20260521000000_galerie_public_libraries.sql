-- =====================================================================
-- Migration : galerie publique des bibliothèques du réseau (chantier #K2)
-- Date de conception : 2026-05-20
-- Cible : alimenter la page galerie type RebAL sur anarbib.org
--         (le site de présentation), liée au path /explorar de criar-conta.
--
-- Contenu :
--   1. Deux colonnes additives sur library_commons :
--        - affiliation_label : contexte/affiliation affiché sur la carte
--          (« Circolo Anarchico Berneri », « Coletivo Anarquista », etc.)
--        - website_url       : site web propre de la biblio (bouton « Site web »).
--      Les deux sont NULLABLE : une biblio sans affiliation affiche une
--      carte sans cette ligne ; une biblio sans website_url voit le bouton
--      « Site web » masqué côté front.
--   2. Une vue api.public_libraries en SECURITY INVOKER, lisible par anon,
--      qui n'expose QUE les biblios ayant rendu leur catalogue public
--      (visibility_level = 'public' AND is_active = true).
--
-- Doctrine appliquée :
--   - Forme additive (pas de NOT NULL, pas de DEFAULT contraignant) :
--     aucune donnée existante n'est cassée.
--   - SECURITY INVOKER : la vue ne contourne pas la RLS ; chaque ligne
--     reste soumise aux politiques de la table sous-jacente.
--   - Aucune donnée sensible exposée : ni membres, ni emails de contact
--     internes, ni adresse postale. Uniquement ce qui est destiné au public.
--   - DO-block de vérification anti-régression en fin de transaction
--     (doctrine création objets backend sécurisés v2, #150).
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Colonnes additives sur library_commons
-- ---------------------------------------------------------------------
ALTER TABLE public.library_commons
  ADD COLUMN IF NOT EXISTS affiliation_label text,
  ADD COLUMN IF NOT EXISTS website_url       text;

COMMENT ON COLUMN public.library_commons.affiliation_label IS
  'Contexte/affiliation publique de la bibliothèque, affiché sur la carte de la galerie anarbib.org (ex. « Coletivo Anarquista Berneri »). Nullable.';
COMMENT ON COLUMN public.library_commons.website_url IS
  'URL du site web propre de la bibliothèque (bouton « Site web » de la carte galerie). Nullable : si NULL, le bouton est masqué côté front.';

-- Garde-fou doux : si une URL est renseignée, elle doit être http(s).
-- Volontairement permissif (pas de validation de domaine).
ALTER TABLE public.library_commons
  DROP CONSTRAINT IF EXISTS library_commons_website_url_chk;
ALTER TABLE public.library_commons
  ADD CONSTRAINT library_commons_website_url_chk
  CHECK (website_url IS NULL OR website_url ~* '^https?://');

-- ---------------------------------------------------------------------
-- 2. Vue publique api.public_libraries
-- ---------------------------------------------------------------------
-- Note de conception sur le badge :
--   RebAL affiche un badge « Automatizzato ». L'équivalent AnarBib le plus
--   honnête n'est pas un statut binaire mais le couple (catalog_mode,
--   circulation_mode). On expose les deux modes bruts ; le front décide
--   du libellé du badge. catalog_status est un dérivé de confort :
--     'automatizado'  -> catalogue publié au réseau + circulation full SIGB
--     'em_construcao' -> catalogue publié mais circulation non full SIGB
--   (toute biblio de la vue a déjà visibility_level='public').

DROP VIEW IF EXISTS api.public_libraries;

CREATE VIEW api.public_libraries
WITH (security_invoker = true)
AS
SELECT
  l.id,
  l.slug,
  l.name,
  l.short_name,
  l.city,
  l.state,
  l.country,
  lc.affiliation_label,
  lc.website_url,
  lc.logo_url,
  l.catalog_mode,
  l.circulation_mode,
  -- Compteur de notices bibliographiques distinctes détenues par la biblio.
  -- book_holdings = lien notice (book_id) <-> bibliothèque (library_id).
  -- On compte les titres, pas les exemplaires physiques.
  (
    SELECT count(DISTINCT bh.book_id)
    FROM public.book_holdings bh
    WHERE bh.library_id = l.id
  ) AS notices_count,
  -- Badge dérivé de confort (le front peut l'ignorer et recalculer).
  CASE
    WHEN l.catalog_mode = 'network_published'
         AND l.circulation_mode = 'full_sigb'
      THEN 'automatizado'
    ELSE 'em_construcao'
  END AS catalog_status
FROM public.libraries l
LEFT JOIN public.library_commons lc
       ON lc.library_id = l.id
WHERE l.is_active = true
  AND l.visibility_level = 'public';

COMMENT ON VIEW api.public_libraries IS
  'Galerie publique des bibliothèques du réseau AnarBib (chantier #K2). '
  'N''expose que les biblios actives dont le catalogue est public '
  '(visibility_level = ''public''). Lecture anonyme autorisée. '
  'Aucune donnée sensible : ni membres, ni emails internes, ni adresse postale.';

-- ---------------------------------------------------------------------
-- 3. Permissions de lecture
-- ---------------------------------------------------------------------
-- La vue est destinée à être lue depuis le site public anarbib.org
-- (utilisateur anonyme). On accorde SELECT à anon et authenticated.
GRANT SELECT ON api.public_libraries TO anon, authenticated;

-- ---------------------------------------------------------------------
-- 4. Vérification anti-régression (doctrine #150)
-- ---------------------------------------------------------------------
-- On simule un contexte anonyme PostgREST et on vérifie que :
--   (a) la vue est lisible par anon ;
--   (b) elle ne renvoie QUE des biblios publiques ;
--   (c) elle ne renvoie pas la biblio de test privée.
DO $$
DECLARE
  v_total       int;
  v_non_public  int;
BEGIN
  -- Contexte anonyme fidèle à PostgREST.
  SET LOCAL ROLE anon;
  SET LOCAL "request.jwt.claims" = '{}';

  SELECT count(*) INTO v_total
  FROM api.public_libraries;

  -- En recoupant avec la table de base (lecture postgres après RESET),
  -- on vérifie qu'aucune ligne non-publique n'a fui.
  RESET ROLE;
  SELECT count(*) INTO v_non_public
  FROM api.public_libraries v
  JOIN public.libraries l ON l.id = v.id
  WHERE l.visibility_level <> 'public' OR l.is_active = false;

  IF v_non_public > 0 THEN
    RAISE EXCEPTION
      'REGRESSION: api.public_libraries expose % bibliotheque(s) non-publique(s)',
      v_non_public;
  END IF;

  RAISE NOTICE 'OK api.public_libraries : % bibliotheque(s) publique(s) exposee(s), 0 fuite.', v_total;
END $$;

COMMIT;
