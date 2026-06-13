-- ════════════════════════════════════════════════════════════════════════════
-- ONBO-Q2 — Volet 4 « Catalogação » : aide STRUCTURÉE (refonte)
-- ════════════════════════════════════════════════════════════════════════════
-- Le champ texte libre seul (cataloging_policy_notes) ne suffisait pas comme aide
-- à la décision. On ajoute deux champs structurés sur `libraries`, à côté des notes :
--   - cataloging_classification_system : système de cote/classification retenu
--     (adhoc | cdd | cdu | thematic | other) — nullable tant que non décidé.
--   - cataloging_mandatory_fields : champs obligatoires à la catalogation, liste de
--     clés alignées sur catalogacao.field.* (author, title, year, publisher, isbn,
--     language, subjects, edition).
--
-- Édité sur la biblio pré-active via libraries_staff_read / libraries_staff_update
-- (Lot 1) — aucune nouvelle RLS. Alimente le regimento (volet 10).
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.libraries
  ADD COLUMN IF NOT EXISTS cataloging_classification_system text,
  ADD COLUMN IF NOT EXISTS cataloging_mandatory_fields       text[];

-- Garde-fou doux sur le système de classification (NULL autorisé = non décidé).
ALTER TABLE public.libraries
  DROP CONSTRAINT IF EXISTS libraries_cataloging_classification_system_chk;
ALTER TABLE public.libraries
  ADD CONSTRAINT libraries_cataloging_classification_system_chk
  CHECK (cataloging_classification_system IS NULL
         OR cataloging_classification_system = ANY (ARRAY['adhoc','cdd','cdu','thematic','other']));

COMMENT ON COLUMN public.libraries.cataloging_classification_system IS
  'Système de cote/classification retenu au volet 4 de l''atelier (adhoc|cdd|cdu|thematic|other). Nullable. ONBO-Q2.';
COMMENT ON COLUMN public.libraries.cataloging_mandatory_fields IS
  'Champs obligatoires à la catalogation décidés au volet 4 (clés alignées sur catalogacao.field.*). Nullable. ONBO-Q2.';

NOTIFY pgrst, 'reload schema';
