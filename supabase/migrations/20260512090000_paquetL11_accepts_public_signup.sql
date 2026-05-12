-- =========================================================================
-- Paquet L.1.1 — Champ accepts_public_signup et resolution v_libraries_for_signup
-- =========================================================================
-- Contexte : la bascule de v_libraries_for_signup en security_invoker (L.1)
-- a révélé un design problem : la vue exposait toutes les biblios actives,
-- y compris celles dont visibility_level='network' (BTL), mais une fois
-- soumise aux RLS de libraries via security_invoker, seules les biblios
-- 'public' restaient visibles aux visiteur·euses anonymes. Conséquence :
-- BTL disparaissait du dropdown signup.
--
-- Doctrine adoptée : visibility_level (visibilité catalogue) ≠ acceptation
-- d'inscriptions. Une bibliothèque peut rester discrète dans son catalogue
-- (network) tout en acceptant des adhésions publiques par signup. On sépare
-- explicitement les deux concepts via un nouveau champ accepts_public_signup.
--
-- Choix techniques (session 2026-05-12 matin) :
--   - Q1 = A3 : DEFAULT calculé (public+network -> true, private -> false)
--   - Q2 = B1 : UPDATE via RLS staff existante (libraries_staff_update)
--   - Q3 = C2 : nouvelle policy SELECT anon ciblée + security_invoker=true
--
-- Effet attendu :
--   - BLMF (public, is_active=true) -> accepts_public_signup=true -> visible
--   - BTL  (network, is_active=true) -> accepts_public_signup=true -> visible
--   - v_libraries_for_signup en security_invoker=true sans casser le signup
--   - 18e ERROR du linter Supabase éradiqué
--
-- Risque : modéré. Vérification end-to-end en fin de paquet (DO block).
-- En cas de régression imprévue, rollback unitaire :
--   ALTER VIEW public.v_libraries_for_signup SET (security_invoker = false);
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. Ajout de la colonne accepts_public_signup
-- -------------------------------------------------------------------------
-- On ajoute avec DEFAULT false pour pouvoir contrôler le backfill ligne à
-- ligne juste après. NOT NULL pour empêcher toute valeur indéterminée.

ALTER TABLE public.libraries
  ADD COLUMN accepts_public_signup boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.libraries.accepts_public_signup IS
  'Indique si la bibliothèque accepte des inscriptions publiques via le '
  'formulaire signup (criar-conta). Indépendant de visibility_level qui '
  'concerne uniquement la visibilité dans le catalogue/annuaire. Une biblio '
  'network peut rester discrète tout en acceptant des adhésions par signup. '
  'Modification réservée aux staff (coordenador, administrador) via la '
  'policy libraries_staff_update existante. Ajouté par paquet L.1.1 '
  '(2026-05-12) suite au design problem révélé par la bascule de '
  'v_libraries_for_signup en security_invoker.';

-- -------------------------------------------------------------------------
-- 2. Backfill A3 selon visibility_level
-- -------------------------------------------------------------------------
-- public et network -> accepte signup (libraries existantes du réseau)
-- private -> n'accepte pas signup (admission gérée hors-réseau)

UPDATE public.libraries
SET accepts_public_signup = (visibility_level IN ('public', 'network'));

-- Trace explicite dans les logs Supabase pour audit
DO $$
DECLARE
  v_total  int;
  v_accept int;
  v_refuse int;
BEGIN
  SELECT count(*) INTO v_total  FROM public.libraries;
  SELECT count(*) INTO v_accept FROM public.libraries WHERE accepts_public_signup = true;
  SELECT count(*) INTO v_refuse FROM public.libraries WHERE accepts_public_signup = false;
  RAISE NOTICE 'Paquet L.1.1 backfill : % biblios total, % acceptent signup, % refusent',
    v_total, v_accept, v_refuse;
END $$;

-- -------------------------------------------------------------------------
-- 3. Nouvelle policy SELECT anon ciblée signup
-- -------------------------------------------------------------------------
-- Cette policy s'ajoute à libraries_public_read (qui reste inchangée). En
-- RLS Postgres, les policies de même commande sont combinées en OR : si
-- l'une OU l'autre accepte, la ligne est visible. Donc :
--   - libraries_public_read continue de filtrer par scope pour le catalogue
--   - libraries_public_signup_read ouvre une voie alternative pour signup
-- Une biblio network avec accepts_public_signup=true sera visible aux
-- anonymes via cette nouvelle policy, sans pour autant être exposée dans
-- les autres vues qui filtrent par visibility_level='public' explicite.

CREATE POLICY "libraries_public_signup_read"
ON public.libraries
FOR SELECT
TO anon, authenticated
USING (is_active = true AND accepts_public_signup = true);

COMMENT ON POLICY "libraries_public_signup_read" ON public.libraries IS
  'Expose aux visiteurs (anon, authenticated) les bibliothèques actives qui '
  'acceptent les inscriptions publiques, indépendamment de visibility_level. '
  'Permet à v_libraries_for_signup de fonctionner en security_invoker=true. '
  'Cette policy s''ajoute (OR) à libraries_public_read sans la remplacer : '
  'le filtrage par scope reste effectif pour les autres vues du catalogue. '
  'Ajoutée par paquet L.1.1 (2026-05-12).';

-- -------------------------------------------------------------------------
-- 4. Bascule v_libraries_for_signup en security_invoker
-- -------------------------------------------------------------------------
-- Maintenant que la policy permet à anon de voir les biblios qui acceptent
-- signup, la vue peut s'exécuter avec les droits du caller sans perdre BTL.

ALTER VIEW public.v_libraries_for_signup SET (security_invoker = true);

COMMENT ON VIEW public.v_libraries_for_signup IS
  'Liste des bibliothèques disponibles pour le formulaire signup public '
  '(criar-conta). security_invoker=true depuis paquet L.1.1 (2026-05-12) : '
  'le filtrage repose sur la policy libraries_public_signup_read qui expose '
  'les biblios où is_active=true AND accepts_public_signup=true. Compatible '
  'avec un accès anonyme via PostgREST.';

-- -------------------------------------------------------------------------
-- 5. Vérification end-to-end en contexte anon simulé
-- -------------------------------------------------------------------------
-- On exécute la vue dans le même contexte rôle+JWT que PostgREST utilise
-- pour un appel anonyme. Si la vue ne retourne pas au moins 2 biblios
-- (BLMF + BTL), la migration échoue et toute la transaction roll-back.

DO $$
DECLARE
  v_count_anon int;
  v_count_auth int;
BEGIN
  -- Contexte anon PostgREST-like
  SET LOCAL ROLE anon;
  SET LOCAL "request.jwt.claims" = '{}';
  SELECT count(*) INTO v_count_anon FROM public.v_libraries_for_signup;
  RESET ROLE;

  IF v_count_anon < 2 THEN
    RAISE EXCEPTION 'Vérification anon échouée : v_libraries_for_signup retourne % '
                    'biblios, attendu >= 2 (BLMF + BTL). Rollback automatique.',
                    v_count_anon;
  END IF;

  -- Contexte authenticated quelconque (sub bidon, juste pour activer le rôle)
  SET LOCAL ROLE authenticated;
  SET LOCAL "request.jwt.claims" = '{"sub":"00000000-0000-0000-0000-000000000000","role":"authenticated"}';
  SELECT count(*) INTO v_count_auth FROM public.v_libraries_for_signup;
  RESET ROLE;

  IF v_count_auth < 2 THEN
    RAISE EXCEPTION 'Vérification authenticated échouée : v_libraries_for_signup '
                    'retourne % biblios, attendu >= 2. Rollback automatique.',
                    v_count_auth;
  END IF;

  RAISE NOTICE 'Vérification OK : % biblios visibles en anon, % en authenticated',
    v_count_anon, v_count_auth;
END $$;

COMMIT;

-- =========================================================================
-- Post-conditions attendues
-- =========================================================================
-- - Le linter Supabase ne signale plus security_definer_view sur la vue
--   v_libraries_for_signup (18e ERROR éradiqué -> reste 0 ERROR du paquet L.1)
-- - Le dropdown signup affiche toujours BLMF et BTL
-- - L'option "Je ne trouve pas ma bibliothèque" continue de fonctionner
-- - Toute nouvelle biblio créée avec visibility_level='public' ou 'network'
--   héritera de accepts_public_signup=true (DEFAULT false + backfill ne
--   couvre que les biblios existantes)
-- ATTENTION : pour les FUTURES biblios créées après ce paquet, le DEFAULT
-- est false. Il faudra soit modifier la valeur explicitement lors de la
-- création, soit ajouter un trigger BEFORE INSERT qui applique la logique
-- A3 automatiquement. À discuter dans une session ultérieure ou lors du
-- prochain chantier "création de biblio par admin réseau" (paquet 23/23bis
-- déjà passé, mais on pourra le revoir).
-- =========================================================================
-- Tests manuels recommandés après push :
-- =========================================================================
-- 1. Navigation privée -> https://app.anarbib.org/criar-conta
-- 2. Vérifier que le dropdown contient :
--    - "— Choisissez une bibliothèque —" (placeholder)
--    - BLMF
--    - BTL
--    - "Je ne trouve pas ma bibliothèque..." (option signup_solicitar)
-- 3. Vérifier le linter Supabase : 0 alerte security_definer_view restante
-- =========================================================================
-- Rollback en cas de problème inattendu post-déploiement (à coller manuel) :
-- =========================================================================
-- BEGIN;
--   ALTER VIEW public.v_libraries_for_signup SET (security_invoker = false);
--   DROP POLICY IF EXISTS "libraries_public_signup_read" ON public.libraries;
--   ALTER TABLE public.libraries DROP COLUMN IF EXISTS accepts_public_signup;
-- COMMIT;
-- =========================================================================
