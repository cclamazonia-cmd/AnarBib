-- ====================================================================
-- AnarBib - Migration de VERIFICATION (lecture seule, DO block)
-- ====================================================================
-- Objet : verifier que la vue v_library_service_state_current existe
-- avec les 2 colonnes consommees par CatalogPage.jsx (paquet
-- quickReserve, 20260517-213214).
--
-- Doctrine : "no hardening action without a current SQL dump". Cette
-- migration ne CREE rien, ne MODIFIE rien : elle leve une exception si
-- la vue ou ses colonnes attendues sont absentes, ce qui provoque un
-- rollback automatique et bloque Woodpecker proprement.
--
-- A executer AVANT que le frontend ne consomme la vue en production.
-- Si la vue n'a pas exactement ce nom, ajuster CatalogPage.jsx OU
-- creer un alias avant le push.
-- ====================================================================

DO $verify$
DECLARE
  v_view_exists boolean;
  v_col_mode boolean;
  v_col_allows boolean;
BEGIN
  -- Existence de la vue (n'importe quel schema)
  SELECT EXISTS (
    SELECT 1 FROM information_schema.views
    WHERE table_name = 'v_library_service_state_current'
  ) INTO v_view_exists;

  IF NOT v_view_exists THEN
    RAISE EXCEPTION
      'Vue v_library_service_state_current introuvable. '
      'Le paquet quickReserve la consomme dans CatalogPage.jsx. '
      'Ajuster le nom dans le frontend OU creer la vue/un alias.';
  END IF;

  -- Colonnes attendues
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'v_library_service_state_current'
      AND column_name = 'service_mode'
  ) INTO v_col_mode;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'v_library_service_state_current'
      AND column_name = 'allows_new_reservations'
  ) INTO v_col_allows;

  IF NOT v_col_mode THEN
    RAISE EXCEPTION
      'Colonne service_mode absente de v_library_service_state_current. '
      'Le frontend en a besoin pour les garde-fous reservation.';
  END IF;

  IF NOT v_col_allows THEN
    RAISE EXCEPTION
      'Colonne allows_new_reservations absente de '
      'v_library_service_state_current. Le frontend en a besoin.';
  END IF;

  -- Verifier aussi que profiles.is_restricted existe (consomme aussi)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'is_restricted'
  ) THEN
    RAISE EXCEPTION
      'Colonne profiles.is_restricted introuvable. '
      'Le paquet quickReserve en a besoin pour cacher le bouton aux '
      'comptes restreints.';
  END IF;

  RAISE NOTICE 'OK : v_library_service_state_current presente avec service_mode + allows_new_reservations ; profiles.is_restricted presente.';
END
$verify$;