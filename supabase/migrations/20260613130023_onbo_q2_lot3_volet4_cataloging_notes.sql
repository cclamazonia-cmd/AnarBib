-- ════════════════════════════════════════════════════════════════════════════
-- ONBO-Q2 Lot 3 — Volet 4 « Catalogação » : notes libres de politique
-- ════════════════════════════════════════════════════════════════════════════
-- Le volet 4 de l'atelier n'a pas de config structurée propre (le catalog_mode
-- est déjà choisi au volet 0). On ajoute un champ texte libre où le collectif
-- consigne sa décision de catalogage : système de classification, champs
-- obligatoires, conventions de nommage… Alimente le regimento.
--
-- Édité sur la biblio pré-active (is_active=false) via les policies
-- libraries_staff_read / libraries_staff_update du Lot 1 — aucune nouvelle RLS.
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.libraries
  ADD COLUMN IF NOT EXISTS cataloging_policy_notes text;

COMMENT ON COLUMN public.libraries.cataloging_policy_notes IS
  'Notes libres de politique de catalogage (système de classification, champs obligatoires, conventions de nommage…), saisies au volet 4 de l''atelier de constitution. ONBO-Q2 Lot 3.';
