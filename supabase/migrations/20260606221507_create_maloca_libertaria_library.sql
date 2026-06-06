-- =========================================================================
-- Creation de la bibliotheque Maloca Libertaria / Biblioteca Emma Goldman
-- =========================================================================
-- Date     : 2026-06-06 22:15 UTC (horodatage reel)
-- Session  : Catalogacao work completion
-- Auteur   : Xavier + Claude
--
-- OBJET
-- -----
-- 1. Insere la bibliotheque MLEG dans la table libraries.
-- 2. Affecte owner_library + holder_library aux 415 book_drafts du lot 8
--    (import CSV Maloca) qui sont actuellement sans bibliotheque.
-- =========================================================================

BEGIN;

-- ─── 1. Insertion de la bibliotheque ────────────────────────────────────

INSERT INTO public.libraries (
  slug,
  name,
  short_name,
  city,
  state,
  country,
  default_locale,
  visibility_level,
  logo_url,
  bib_ref_prefix,
  bib_ref_pad,
  bib_ref_auto,
  -- Modes operationnels (memes que BLMF)
  catalog_mode,
  circulation_mode,
  network_mode,
  governance_mode
) VALUES (
  'mleg',
  'Maloca Libertária / Biblioteca Emma Goldman',
  'MLEG',
  'Salvador',
  'Bahia',
  'Brasil',
  'pt-BR',
  'public',
  'https://uflwmikiyjfnikiphtcp.supabase.co/storage/v1/object/public/library-ui-assets/themes/maloca/logo_maloca.png',
  'MLEG',
  7,
  true,
  'network_published',
  'full_sigb',
  'federated',
  'full_governance'
);

-- ─── 2. Affectation des 415 drafts du lot 8 ────────────────────────────
-- Le lot 8 ("Import partenaire — Biblioteca Maloca / Emma Goldman — CSV v1
-- — run 3") contient 415 book_drafts sans owner_library.

UPDATE public.book_drafts
SET owner_library  = (SELECT id FROM public.libraries WHERE slug = 'mleg'),
    holder_library = (SELECT id FROM public.libraries WHERE slug = 'mleg')
WHERE batch_id = 8
  AND owner_library IS NULL;

-- ─── 3. Verification ───────────────────────────────────────────────────

DO $verif$
DECLARE
  v_lib_id uuid;
  v_count  integer;
BEGIN
  SELECT id INTO v_lib_id FROM public.libraries WHERE slug = 'mleg';
  IF v_lib_id IS NULL THEN
    RAISE EXCEPTION 'VERIF: bibliotheque mleg non trouvee';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.book_drafts
  WHERE batch_id = 8 AND owner_library = v_lib_id;

  IF v_count = 0 THEN
    RAISE EXCEPTION 'VERIF: aucun draft du lot 8 affecte a mleg (attendu ~415)';
  END IF;

  RAISE NOTICE 'OK: bibliotheque mleg cree (%), % drafts affectes', v_lib_id, v_count;
END
$verif$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback :
--   UPDATE public.book_drafts SET owner_library = NULL, holder_library = NULL
--     WHERE batch_id = 8 AND owner_library = (SELECT id FROM public.libraries WHERE slug = 'mleg');
--   DELETE FROM public.libraries WHERE slug = 'mleg';
-- =========================================================================
