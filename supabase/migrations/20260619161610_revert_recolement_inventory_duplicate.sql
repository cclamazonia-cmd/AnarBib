-- =====================================================================
-- AnarBib — REVERT des lots 1+2 « inventory_* » (récolement DUPLIQUÉ par erreur)
-- Auteur  : coordination AnarBib
-- Session : Récolement (veille du commun)
--
-- Motif : le récolement existe DÉJÀ en prod depuis le 16/06 (UI TabRecolement
-- commit b7274838 + tables recolement_sessions/recolement_scans + RPC
-- api.recolement_start/scan/finish/open_sessions, baseline). Les migrations
-- 20260619152022 (schéma census) et 20260619153704 (RPC + trigger) ont créé un
-- système PARALLÈLE redondant (inventory_campaigns/scans + fn_inventory_* +
-- colonnes census sur exemplares + trigger). On le retire intégralement.
-- Le récolement réel (recolement_*) n'est PAS touché par cette migration.
--
-- Ordre : trigger → fonctions → colonnes exemplares (dont la FK not_seen_campaign_id)
-- → tables. Tout en IF EXISTS, sans CASCADE.
-- =====================================================================

-- 1. Trigger passif (sur emprestimo_itens_v2)
DROP TRIGGER IF EXISTS trg_inventory_touch_last_seen ON public.emprestimo_itens_v2;

-- 2. Fonctions (RPC + helpers + fn trigger)
DROP FUNCTION IF EXISTS public.fn_inventory_touch_last_seen_on_return();
DROP FUNCTION IF EXISTS public.fn_inventory_start_campaign(uuid, text, text, text);
DROP FUNCTION IF EXISTS public.fn_inventory_record_scan(bigint, bigint);
DROP FUNCTION IF EXISTS public.fn_inventory_close_campaign(bigint);
DROP FUNCTION IF EXISTS public.fn_inventory_campaign_report(bigint);
DROP FUNCTION IF EXISTS public.fn_inventory_set_condition(bigint, text, text);
DROP FUNCTION IF EXISTS public.fn_inventory_in_scope_exemplares(bigint);

-- 3. Colonnes census sur exemplares (la FK not_seen_campaign_id part avec sa colonne ;
--    les CHECK exemplares_*_chk partent avec leurs colonnes).
ALTER TABLE public.exemplares DROP COLUMN IF EXISTS not_seen_campaign_id;
ALTER TABLE public.exemplares DROP COLUMN IF EXISTS not_seen_at;
ALTER TABLE public.exemplares DROP COLUMN IF EXISTS not_seen_flag;
ALTER TABLE public.exemplares DROP COLUMN IF EXISTS condition_set_by;
ALTER TABLE public.exemplares DROP COLUMN IF EXISTS condition_set_at;
ALTER TABLE public.exemplares DROP COLUMN IF EXISTS condition_note;
ALTER TABLE public.exemplares DROP COLUMN IF EXISTS condition_status;
ALTER TABLE public.exemplares DROP COLUMN IF EXISTS last_seen_via;
ALTER TABLE public.exemplares DROP COLUMN IF EXISTS last_seen_at;

-- 4. Tables (scans FK campaigns → scans d'abord)
DROP TABLE IF EXISTS public.inventory_scans;
DROP TABLE IF EXISTS public.inventory_campaigns;

NOTIFY pgrst, 'reload schema';
