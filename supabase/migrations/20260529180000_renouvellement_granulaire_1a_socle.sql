-- ═══════════════════════════════════════════════════════════════════════════
-- Renouvellement granulaire par item — PHASE 1a (socle de données)
-- ───────────────────────────────────────────────────────────────────────────
-- Spec : docs/specs/spec-renouvellement-granulaire.md
-- Origine : chantier #PAINEL E.3/EA-07, décision 29/05/2026 (quota par item).
--
-- CONTENU 1a (ajout pur, NON destructif, aucune fonction d'extension touchée) :
--   1. Colonne emprestimo_itens_v2.renewals_used (compteur par item)
--   2. Copie des données existantes depuis le header (items ouverts uniquement)
--   3. Trigger de synchro header = MAX(renewals_used des items ouverts), DORMANT
--      tant que les fonctions d'extension n'incrémentent pas encore les items
--      (elles le feront en phase 1b). Garde-fou : maintient le header cohérent
--      pour les triggers existants (sync_extended_once, notify_prorrogacao) et
--      les vues non encore migrées.
--
-- En 1a, les fonctions fn_v2_extend_emprestimo_once / fn_renew_my_loan
-- continuent d'incrémenter le HEADER directement : comportement INCHANGÉ.
-- La bascule logique vers le compteur par item est l'objet de la phase 1b.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. Colonne compteur par item ────────────────────────────────────────────
-- ADD COLUMN avec DEFAULT non-volatile : metadata-only en PG 11+, pas de
-- réécriture de table.
ALTER TABLE public.emprestimo_itens_v2
  ADD COLUMN IF NOT EXISTS renewals_used integer NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.emprestimo_itens_v2.renewals_used IS
  'Compteur de renouvellements par item (chantier renouvellement granulaire, 29/05/2026). '
  'Source de vérité du quota par item depuis la phase 1b. Le header '
  'emprestimos_v2.renewals_used est maintenu = MAX des items ouverts (garde-fou transitoire).';

-- ── 2. Migration des données existantes ─────────────────────────────────────
-- Propagation du compteur header vers chaque item ENCORE OUVERT. Les items
-- déjà rendus gardent le DEFAULT 0 (sans incidence : non renouvelables).
UPDATE public.emprestimo_itens_v2 i
   SET renewals_used = e.renewals_used
  FROM public.emprestimos_v2 e
 WHERE i.emprestimo_id = e.id
   AND i.item_status = 'aberto'
   AND COALESCE(e.renewals_used, 0) > 0;

-- ── 3. Trigger de synchro header = MAX(items ouverts) ────────────────────────
-- Modèle aligné sur trg_emprestimo_sync_extended_once (trigger de synchro de
-- champ, non SECURITY DEFINER, exécuté dans le contexte de l'opération
-- déclenchante — les UPDATE d'items passent par des fonctions DEFINER en 1b).
CREATE OR REPLACE FUNCTION public.trg_sync_header_renewals_from_items()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
BEGIN
  -- Recalcule le compteur header = max des compteurs des items encore ouverts.
  -- Si plus aucun item ouvert, on conserve la valeur header existante (les
  -- emprunts clôturés ne sont plus renouvelables, la valeur n'a plus d'usage).
  UPDATE public.emprestimos_v2 e
     SET renewals_used = COALESCE(
           (SELECT MAX(i.renewals_used)
              FROM public.emprestimo_itens_v2 i
             WHERE i.emprestimo_id = e.id
               AND i.item_status = 'aberto'),
           e.renewals_used
         ),
         updated_at = now()
   WHERE e.id = COALESCE(NEW.emprestimo_id, OLD.emprestimo_id)
     AND e.renewals_used IS DISTINCT FROM COALESCE(
           (SELECT MAX(i.renewals_used)
              FROM public.emprestimo_itens_v2 i
             WHERE i.emprestimo_id = e.id
               AND i.item_status = 'aberto'),
           e.renewals_used
         );
  RETURN NULL; -- AFTER trigger
END;
$function$;

DROP TRIGGER IF EXISTS trg_sync_header_renewals ON public.emprestimo_itens_v2;
CREATE TRIGGER trg_sync_header_renewals
AFTER UPDATE OF renewals_used ON public.emprestimo_itens_v2
FOR EACH ROW
WHEN (NEW.renewals_used IS DISTINCT FROM OLD.renewals_used)
EXECUTE FUNCTION public.trg_sync_header_renewals_from_items();

-- ── 4. Vérifications doctrinales (RAISE EXCEPTION = auto-rollback) ───────────
DO $$
DECLARE
  v_col_exists boolean;
  v_trg_exists boolean;
  v_mismatch_count integer;
BEGIN
  -- 4.1 La colonne existe bien
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='emprestimo_itens_v2'
      AND column_name='renewals_used'
  ) INTO v_col_exists;
  IF NOT v_col_exists THEN
    RAISE EXCEPTION '1a: colonne renewals_used absente apres ALTER';
  END IF;

  -- 4.2 Le trigger de synchro existe
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname='trg_sync_header_renewals'
      AND tgrelid='public.emprestimo_itens_v2'::regclass
  ) INTO v_trg_exists;
  IF NOT v_trg_exists THEN
    RAISE EXCEPTION '1a: trigger trg_sync_header_renewals absent apres creation';
  END IF;

  -- 4.3 Cohérence data : tout item OUVERT d'un emprunt dont le header a
  --     renewals_used > 0 doit avoir été copié (item.renewals_used = header).
  SELECT COUNT(*) INTO v_mismatch_count
  FROM public.emprestimo_itens_v2 i
  JOIN public.emprestimos_v2 e ON e.id = i.emprestimo_id
  WHERE i.item_status = 'aberto'
    AND COALESCE(e.renewals_used,0) > 0
    AND i.renewals_used IS DISTINCT FROM e.renewals_used;
  IF v_mismatch_count > 0 THEN
    RAISE EXCEPTION '1a: % item(s) ouvert(s) non synchronise(s) avec le header', v_mismatch_count;
  END IF;

  RAISE NOTICE '1a OK : colonne + data + trigger en place, % verifications passees.', 3;
END $$;
