-- =====================================================================
-- AnarBib — Récolement / Veille du commun — LOT 1 : schéma census
-- Auteur  : coordination AnarBib
-- Session : Récolement (veille du commun)
-- Réf     : docs/journal/cadrages/CADRAGE_recolement_2026-06-19.md
--
-- Couche « veille/recensement » (D1 hybride, D2 « non vu » doux, D3 présence+état).
-- NON inclus ici : l'ACTION de désherbage (retrait du commun) — geste grave,
-- collégialité alignée sur team_admission_mode — qui aura sa propre tranche (lot B).
-- Ici on POSE seulement le modèle de données : last_seen (passif), campagnes +
-- scans (actif), drapeau « non vu » doux, et la notation d'état (dont « à désherber »).
-- =====================================================================

-- ── 1. Campagnes de récolement ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.inventory_campaigns (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  library_id uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,
  scope_type text NOT NULL DEFAULT 'all' CHECK (scope_type IN ('all','location','collection')),
  scope_value text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed')),
  started_by uuid NOT NULL REFERENCES public.profiles(id),
  started_at timestamptz NOT NULL DEFAULT now(),
  closed_by uuid REFERENCES public.profiles(id),
  closed_at timestamptz,
  notes text
);
CREATE INDEX IF NOT EXISTS idx_inventory_campaigns_library ON public.inventory_campaigns (library_id, status);
COMMENT ON TABLE public.inventory_campaigns IS
  'Campagnes de récolement (veille du commun). Périmètre = totalité / localisation (shelf_location) / collection. Écrites via RPC SECDEF. Cf. CADRAGE_recolement_2026-06-19.';

-- ── 2. Scans (exemplaires « vus » pendant une campagne) ──────────────
CREATE TABLE IF NOT EXISTS public.inventory_scans (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  campaign_id bigint NOT NULL REFERENCES public.inventory_campaigns(id) ON DELETE CASCADE,
  exemplar_id bigint NOT NULL REFERENCES public.exemplares(id) ON DELETE CASCADE,
  scanned_by uuid NOT NULL REFERENCES public.profiles(id),
  scanned_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_inventory_scan UNIQUE (campaign_id, exemplar_id)
);
CREATE INDEX IF NOT EXISTS idx_inventory_scans_campaign ON public.inventory_scans (campaign_id);

-- ── 3. Colonnes census sur exemplares ────────────────────────────────
-- D1 : last_seen rafraîchi passivement (retour de prêt / consultation) OU au scan.
ALTER TABLE public.exemplares ADD COLUMN IF NOT EXISTS last_seen_at timestamptz;
ALTER TABLE public.exemplares ADD COLUMN IF NOT EXISTS last_seen_via text;
-- D3 : état physique (notation ; « a_desbastar » = candidat au désherbage, l'ACTION = lot B).
ALTER TABLE public.exemplares ADD COLUMN IF NOT EXISTS condition_status text NOT NULL DEFAULT 'bom';
ALTER TABLE public.exemplares ADD COLUMN IF NOT EXISTS condition_note text;
ALTER TABLE public.exemplares ADD COLUMN IF NOT EXISTS condition_set_at timestamptz;
ALTER TABLE public.exemplares ADD COLUMN IF NOT EXISTS condition_set_by uuid;
-- D2 : drapeau « non vu » doux (posé en clôture de campagne, effacé au prochain last_seen).
ALTER TABLE public.exemplares ADD COLUMN IF NOT EXISTS not_seen_flag boolean NOT NULL DEFAULT false;
ALTER TABLE public.exemplares ADD COLUMN IF NOT EXISTS not_seen_at timestamptz;
ALTER TABLE public.exemplares ADD COLUMN IF NOT EXISTS not_seen_campaign_id bigint REFERENCES public.inventory_campaigns(id) ON DELETE SET NULL;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.exemplares'::regclass AND conname='exemplares_last_seen_via_chk') THEN
    ALTER TABLE public.exemplares ADD CONSTRAINT exemplares_last_seen_via_chk
      CHECK (last_seen_via IS NULL OR last_seen_via IN ('loan_return','consultation','inventory_scan'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.exemplares'::regclass AND conname='exemplares_condition_status_chk') THEN
    ALTER TABLE public.exemplares ADD CONSTRAINT exemplares_condition_status_chk
      CHECK (condition_status IN ('bom','a_reparar','a_encadernar','a_desbastar'));
  END IF;
END $$;

COMMENT ON COLUMN public.exemplares.last_seen_at IS 'Veille du commun : dernière fois que l''exemplaire a été « vu » (retour de prêt / consultation / scan de récolement). Cf. patron network_administrators.last_seen_at.';
COMMENT ON COLUMN public.exemplares.condition_status IS 'État physique (D3) : bom / a_reparar / a_encadernar / a_desbastar. « a_desbastar » = candidat au désherbage (l''ACTION de retrait = lot B, collégiale).';
COMMENT ON COLUMN public.exemplares.not_seen_flag IS 'Drapeau « non vu » DOUX (D2) : posé si l''exemplaire n''a pas été scanné en clôture d''une campagne couvrant son périmètre. Daté (not_seen_at), non punitif, auto-effacé au prochain last_seen. JAMAIS « perdu » automatiquement.';

-- ── 4. RLS + grants (lecture staff ; écritures via RPC DEFINER au lot 2) ──
ALTER TABLE public.inventory_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_scans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS inventory_campaigns_select ON public.inventory_campaigns;
CREATE POLICY inventory_campaigns_select ON public.inventory_campaigns
  FOR SELECT TO authenticated
  USING (public.user_can_manage_library_notifications(library_id) OR public.fn_caller_is_network_admin());

DROP POLICY IF EXISTS inventory_scans_select ON public.inventory_scans;
CREATE POLICY inventory_scans_select ON public.inventory_scans
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.inventory_campaigns c
    WHERE c.id = campaign_id
      AND (public.user_can_manage_library_notifications(c.library_id) OR public.fn_caller_is_network_admin())
  ));

GRANT SELECT ON public.inventory_campaigns TO authenticated;
GRANT SELECT ON public.inventory_scans TO authenticated;
GRANT ALL ON public.inventory_campaigns TO service_role;
GRANT ALL ON public.inventory_scans TO service_role;

NOTIFY pgrst, 'reload schema';
