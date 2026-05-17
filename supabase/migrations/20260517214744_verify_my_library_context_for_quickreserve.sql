-- ====================================================================
-- AnarBib - Migration de VERIFICATION (lecture seule, DO block)
-- Remplace la migration verify_service_state_view_for_quickreserve
-- qui pointait sur une vue inexistante (v_library_service_state_current).
-- ====================================================================
-- Objet : verifier que api.my_library_context expose les colonnes
-- service_mode et allows_new_reservations, et que profiles.is_restricted
-- existe. Consommees par CatalogPage.jsx (paquet quickReserve).
--
-- Doctrine : "no hardening action without a current SQL dump". Cette
-- migration ne CREE rien, ne MODIFIE rien : elle leve une exception si
-- une dependance manque, ce qui bloque Woodpecker proprement.
-- ====================================================================

DO $verify$
DECLARE
  v_view_exists boolean;
  v_col_mode boolean;
  v_col_allows boolean;
BEGIN
  -- Existence de la vue api.my_library_context
  SELECT EXISTS (
    SELECT 1 FROM information_schema.views
    WHERE table_schema = 'api' AND table_name = 'my_library_context'
  ) INTO v_view_exists;

  IF NOT v_view_exists THEN
    RAISE EXCEPTION
      'Vue api.my_library_context introuvable. '
      'Le paquet quickReserve la consomme dans CatalogPage.jsx.';
  END IF;

  -- Colonnes attendues
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'api'
      AND table_name = 'my_library_context'
      AND column_name = 'service_mode'
  ) INTO v_col_mode;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'api'
      AND table_name = 'my_library_context'
      AND column_name = 'allows_new_reservations'
  ) INTO v_col_allows;

  IF NOT v_col_mode THEN
    RAISE EXCEPTION
      'Colonne service_mode absente de api.my_library_context. '
      'Le frontend en a besoin pour les garde-fous reservation.';
  END IF;

  IF NOT v_col_allows THEN
    RAISE EXCEPTION
      'Colonne allows_new_reservations absente de api.my_library_context. '
      'Le frontend en a besoin.';
  END IF;

  -- Verifier aussi que profiles.is_restricted existe (consomme aussi)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'profiles'
      AND column_name = 'is_restricted'
  ) THEN
    RAISE EXCEPTION
      'Colonne profiles.is_restricted introuvable. '
      'Le paquet quickReserve en a besoin pour cacher le bouton aux '
      'comptes restreints.';
  END IF;

  RAISE NOTICE 'OK : api.my_library_context expose service_mode + allows_new_reservations ; profiles.is_restricted presente.';
END
$verify$;