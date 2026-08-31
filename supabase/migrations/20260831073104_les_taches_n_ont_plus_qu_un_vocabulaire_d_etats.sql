-- =========================================================================
-- Les tâches internes n'ont plus qu'un vocabulaire d'états
-- =========================================================================
-- Date     : 2026-08-31
-- Chantier : tâches internes (item F6)
--
-- TROIS LISTES POUR UN MÊME CHAMP, ET AUCUN ARBITRE
--
--   base       `status` : AUCUNE contrainte, défaut 'pendente'
--   frontend   filtre sur  pendente | em_andamento
--   courriels  aberta | a_fazer | em_andamento | bloqueada
--              concluida | cancelada | arquivada
--
-- Sans contrainte, la colonne accepte n'importe quelle chaîne. Et le frontend
-- n'affichant que deux états sur sept, une tâche passée en `bloqueada` ou
-- `concluida` DISPARAÎT de l'écran sans que personne ne sache où elle est
-- allée. Ce n'est pas un défaut d'affichage : c'est une tâche perdue.
--
-- CE QUI EST RETENU
--
-- Les sept états des libellés — ils décrivent un cycle de vie réfléchi
-- (ouverte → à faire → en cours → bloquée → terminée / annulée / archivée),
-- là où `pendente` était un défaut posé vite. La colonne prend donc `aberta`
-- comme valeur par défaut, et une CHECK tient la liste.
--
-- MAINTENANT, PARCE QUE C'EST LA FENÊTRE
--
-- Zéro tâche existe à ce jour : aucune donnée à reprendre, aucun écran à
-- migrer, aucun risque. Le jour où la première tâche sera créée, ces états
-- seront déjà écrits en base — et poser une CHECK sur une colonne peuplée de
-- valeurs libres est un tout autre chantier.
--
-- Le libellé `pendente` reste dans la table i18n des courriels : il ne coûte
-- rien, et il couvre les lignes qu'une reprise manuelle pourrait écrire.
-- =========================================================================

BEGIN;

-- Sécurité : la migration ne doit pas passer en silence sur des données
-- qu'elle n'a pas prévues. S'il existe une tâche hors vocabulaire, on s'arrête.
DO $$
DECLARE v_hors text;
BEGIN
  SELECT string_agg(DISTINCT status, ', ') INTO v_hors
    FROM public.painel_internal_tasks
   WHERE status NOT IN ('aberta','a_fazer','em_andamento','bloqueada',
                        'concluida','cancelada','arquivada');
  IF v_hors IS NOT NULL THEN
    RAISE EXCEPTION 'des taches portent un etat hors vocabulaire : % — les reprendre avant de poser la CHECK', v_hors;
  END IF;
END $$;

ALTER TABLE public.painel_internal_tasks
  ALTER COLUMN status SET DEFAULT 'aberta';

ALTER TABLE public.painel_internal_tasks
  DROP CONSTRAINT IF EXISTS painel_internal_tasks_status_check;

ALTER TABLE public.painel_internal_tasks
  ADD CONSTRAINT painel_internal_tasks_status_check
  CHECK (status IN ('aberta','a_fazer','em_andamento','bloqueada',
                    'concluida','cancelada','arquivada'));

COMMENT ON COLUMN public.painel_internal_tasks.status IS
  'Cycle de vie d''une tache interne : aberta -> a_fazer -> em_andamento -> bloqueada '
  '-> concluida | cancelada | arquivada. Tenu par painel_internal_tasks_status_check '
  'depuis le 31/08/2026 (item F6). Avant cette date la colonne n''avait AUCUNE '
  'contrainte et valait ''pendente'' par defaut, mot que les libelles de courriel '
  'ne connaissaient pas et que le frontend etait seul a filtrer.';

-- -------------------------------------------------------------------------
-- Vérification (doctrine)
-- -------------------------------------------------------------------------
DO $$
DECLARE v_def text;
BEGIN
  SELECT column_default INTO v_def FROM information_schema.columns
   WHERE table_schema='public' AND table_name='painel_internal_tasks' AND column_name='status';
  IF v_def IS NULL OR v_def NOT LIKE '%aberta%' THEN
    RAISE EXCEPTION 'le defaut de status n''est pas aberta (%)', coalesce(v_def,'NULL');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE conrelid='public.painel_internal_tasks'::regclass
                    AND conname='painel_internal_tasks_status_check') THEN
    RAISE EXCEPTION 'la CHECK sur status est absente';
  END IF;

  -- Elle doit refuser ce qu'elle est censee refuser.
  BEGIN
    INSERT INTO public.painel_internal_tasks (library_id, title, status)
    VALUES ((SELECT id FROM public.libraries LIMIT 1), 'sonde', 'pendente');
    RAISE EXCEPTION 'la CHECK a laisse passer un etat hors vocabulaire';
  EXCEPTION
    WHEN check_violation THEN NULL;  -- attendu
  END;
END $$;

COMMIT;
