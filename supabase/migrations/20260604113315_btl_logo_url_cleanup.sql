-- ============================================================================
-- Nettoyage donnee : logo_url relatif herite de BTL -> NULL  (TR-6.2b, item 2)
-- ----------------------------------------------------------------------------
-- Contexte : library_commons.logo_url de BTL contenait un chemin frontend
-- relatif ('./assets/img/libraries/btl/logo-btl.png'), vestige de l'epoque des
-- logos bundles. Depuis TR-6.2b, le header ET la carte lecteur ignorent les
-- logo_url non absolus (http/https) et resolvent via logo_file_key -> bucket.
-- Cette migration remet la donnee au propre (le logo BTL passe par logo_file_key).
--
-- Idempotente : ne touche que les logo_url non-null ET non-http. Sur une branche
-- fraiche sans BTL, 0 ligne -> no-op.
-- ============================================================================

UPDATE public.library_commons
SET logo_url = NULL
WHERE library_slug = 'btl'
  AND logo_url IS NOT NULL
  AND logo_url !~* '^https?://';

-- Verification (rollback auto via bloc DO) ----------------------------------
DO $verify$
DECLARE
  v_url text;
BEGIN
  SELECT logo_url INTO v_url FROM public.library_commons WHERE library_slug = 'btl';
  -- Acceptable : NULL (nettoye) ou URL absolue http(s). Refuse : chemin relatif.
  IF v_url IS NOT NULL AND v_url !~* '^https?://' THEN
    RAISE EXCEPTION 'VERIF: logo_url BTL toujours relatif: %', v_url;
  END IF;
  RAISE NOTICE 'VERIF OK: logo_url BTL nettoye (NULL ou absolu).';
END;
$verify$;

NOTIFY pgrst, 'reload schema';
