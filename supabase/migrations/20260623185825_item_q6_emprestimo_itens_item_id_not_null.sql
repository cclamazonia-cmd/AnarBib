-- =========================================================================
-- Paquet ITEM-Q6 — emprestimo_itens_v2.item_id NOT NULL (enforce ITEM-Q4)
-- =========================================================================
-- Date     : 2026-06-23
-- Chantier : modèle item / granularité (suite audit externe 2026-06-23, §3.3 / §6 #7)
-- Auteur   : session Claude
--
-- Contexte : ITEM-Q4 (REGISTRE §7) acte que dans le patron emprestimo_itens_v2,
-- item_id est l'identifiant « fort » et holding_id un « confort ». Or la colonne
-- item_id était restée nullable (NOT NULL oublié) — drift signalé par l'audit.
-- En prod : 0 ligne NULL sur 73. On resserre, en cohérence avec ITEM-Q1
-- (consulta_linhas_v2.item_id NOT NULL, école A). Emprunt holding-level écarté.
--
-- CHECKLIST DOCTRINE :
--   [x] Touche une contrainte -> garde-fou pré + DO block de vérification post
-- =========================================================================

BEGIN;

-- Garde-fou : message clair si des NULL étaient apparus d'ici le déploiement
DO $$
DECLARE
  v_nulls int;
BEGIN
  SELECT count(*) INTO v_nulls FROM public.emprestimo_itens_v2 WHERE item_id IS NULL;
  IF v_nulls > 0 THEN
    RAISE EXCEPTION 'ITEM-Q6 : % ligne(s) emprestimo_itens_v2.item_id IS NULL — résoudre l''exemplaire avant SET NOT NULL.', v_nulls;
  END IF;
END $$;

ALTER TABLE public.emprestimo_itens_v2
  ALTER COLUMN item_id SET NOT NULL;

COMMENT ON COLUMN public.emprestimo_itens_v2.item_id IS
  'Exemplaire emprunté (identifiant FORT — ITEM-Q4). NOT NULL depuis 2026-06-23 '
  '(enforce du drift signalé par l''audit externe). holding_id = confort (dénormalisation).';

-- Vérification : la contrainte est bien posée
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_attribute a
    JOIN pg_class c ON c.oid = a.attrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'emprestimo_itens_v2'
      AND a.attname = 'item_id'
      AND a.attnotnull
  ) THEN
    RAISE EXCEPTION 'ITEM-Q6 : item_id NOT NULL non appliqué après migration. Rollback automatique.';
  END IF;
  RAISE NOTICE 'ITEM-Q6 OK : emprestimo_itens_v2.item_id est NOT NULL.';
END $$;

COMMIT;

-- =========================================================================
-- Rollback ciblé :
-- =========================================================================
-- BEGIN;
--   ALTER TABLE public.emprestimo_itens_v2 ALTER COLUMN item_id DROP NOT NULL;
-- COMMIT;
-- =========================================================================
