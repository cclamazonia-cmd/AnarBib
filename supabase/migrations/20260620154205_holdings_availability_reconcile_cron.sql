-- =========================================================================
-- Réconciliation de la disponibilité des holdings + filet cron nocturne
-- =========================================================================
-- Date     : 2026-06-20
-- Chantier : Audit cohérence des chiffres affichés (catalogue / exemplaires)
-- Auteur   : AnarBib · Session : Cohérence des compteurs catalogue (BLMF 241↔229)
--
-- POURQUOI
--   Le cache book_holdings.{exemplares_total, available_count} n'est rafraîchi
--   que par (a) le trigger trg_exemplar_recompute_availability sur exemplares
--   (INSERT/DELETE/UPDATE OF visibility,holding_id) et (b) les RPC de prêt/réserve
--   (fn_v2_recompute_from_*). Un import en masse LEGACY (29/03/2026) a créé des
--   book_holdings avec un exemplares_total déclaré sans insérer les exemplaires
--   → cache divergent (20 holdings au 20/06, dont 18 notices BTL à 0 exemplaire).
--   Aucun cron ne réconciliait ce cache. Ce migration : (1) réconcilie une fois
--   au déploiement (reproductible hors prod) ; (2) installe un filet nocturne qui
--   rattrape toute dérive future (legacy, SQL manuel, imports atypiques). La
--   fonction ne réécrit que les lignes réellement divergentes (is distinct from).
--
-- DOCTRINE pg_cron : job créé via cron.schedule (idempotent par nom) dans un bloc
--   défensif — la base de test fraîche (CI sql-tests) peut ne pas avoir le schéma
--   cron. Pas d'UPDATE cron.job (perm denied 42501). Job ACTIF : pur SQL, aucune
--   dépendance Edge Function / secret, donc rien à activer manuellement ensuite.
-- =========================================================================

-- (1) Réconciliation unique au déploiement (idempotente, guardée pour la base de test).
DO $reconcile$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_v2_recompute_holdings_availability'
  ) THEN
    PERFORM public.fn_v2_recompute_holdings_availability();
    RAISE NOTICE 'Réconciliation book_holdings effectuée au déploiement.';
  ELSE
    RAISE WARNING 'fn_v2_recompute_holdings_availability absente : réconciliation sautée (base de test ?).';
  END IF;
END;
$reconcile$;

-- (2) Filet nocturne : réconciliation quotidienne (04:43 UTC, horaire non rond
--     pour ne pas s'agréger aux autres jobs).
DO $cron$
DECLARE v_jobid bigint;
BEGIN
  v_jobid := cron.schedule(
    'anarbib-recompute-holdings-availability',
    '43 4 * * *',
    'SELECT public.fn_v2_recompute_holdings_availability();'
  );
  RAISE NOTICE 'Job cron anarbib-recompute-holdings-availability créé/MAJ (ACTIF), jobid=%.', v_jobid;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Job cron NON créé (cron indisponible ici ?) : %. À créer/vérifier en prod.', SQLERRM;
END;
$cron$;
