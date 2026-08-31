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
DECLARE v_def text; v_etat text;
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

  -- CORRECTIF DU 31/08, quelques minutes apres la premiere version : cette
  -- verification insérait une tache de sonde pour prouver que la CHECK refuse
  -- 'pendente'. Elle passait en production et cassait la CI.
  --
  -- La raison est ecrite dans le depot depuis longtemps : les migrations sont
  -- appliquees AVANT le seed. En CI, `libraries` est donc VIDE quand ce bloc
  -- s'execute ; `(SELECT id FROM libraries LIMIT 1)` vaut NULL ; library_id est
  -- NOT NULL ; l'insert leve `not_null_violation` — que le `WHEN
  -- check_violation` ne rattrape pas. La migration s'arretait, la
  -- reconstruction du schema avec elle, et les 40 suites ne tournaient meme pas.
  --
  -- Une migration ne verifie que ce qui est STRUCTUREL : ici, que la contrainte
  -- nomme les sept etats et ne nomme pas 'pendente'. C'est aussi concluant, et
  -- ca ne demande aucune donnee. Le controle fonctionnel — inserer et voir
  -- refuser — a sa place dans tests/sql, qui tourne apres le seed.
  DECLARE v_def text;
  BEGIN
    SELECT pg_get_constraintdef(oid) INTO v_def FROM pg_constraint
     WHERE conrelid='public.painel_internal_tasks'::regclass
       AND conname='painel_internal_tasks_status_check';
    IF v_def IS NULL THEN
      RAISE EXCEPTION 'la CHECK sur status est absente';
    END IF;
    IF v_def LIKE '%pendente%' THEN
      RAISE EXCEPTION 'la CHECK nomme encore pendente : %', v_def;
    END IF;
    FOREACH v_etat IN ARRAY ARRAY['aberta','a_fazer','em_andamento','bloqueada',
                                  'concluida','cancelada','arquivada']
    LOOP
      IF v_def NOT LIKE '%'||v_etat||'%' THEN
        RAISE EXCEPTION 'la CHECK ne nomme pas l etat % : %', v_etat, v_def;
      END IF;
    END LOOP;
  END;
END $$;

COMMIT;
