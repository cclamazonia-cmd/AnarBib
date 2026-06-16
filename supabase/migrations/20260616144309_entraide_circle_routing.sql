-- ════════════════════════════════════════════════════════════════════════════
-- Entraide — v2 : routage par cercles (in-app)
-- Session : Fédération — Communs & Entraide
-- Cadrage : docs/journal/cadrages/CADRAGE_entraide_catalogage_2026-06-15.md (§7)
--
-- Subsidiarité « cercle d'abord → réseau si silence » (§7), zéro touche au
-- dispatcher de notifications. Un appel peut cibler un cercle (circle_id) ; il
-- n'est alors visible qu'aux membres du cercle + l'auteur·rice, jusqu'à escalade
-- (3 j sans réponse → s'ouvre au réseau). La notif mail au cercle viendra après
-- (handler EF + mail-strings), sans rien changer ici.
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.entraide_help_requests
  ADD COLUMN IF NOT EXISTS circle_id    uuid REFERENCES public.circles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS escalated_at timestamptz;
CREATE INDEX IF NOT EXISTS entraide_requests_circle_idx
  ON public.entraide_help_requests(circle_id) WHERE circle_id IS NOT NULL;

-- ── Lecture des APPELS, recadrée cercle ─────────────────────────────────────
DROP POLICY IF EXISTS entraide_requests_read_staff ON public.entraide_help_requests;
CREATE POLICY entraide_requests_read_staff ON public.entraide_help_requests
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.user_library_memberships m
            WHERE m.user_id = auth.uid() AND m.status = 'active'
              AND m.role IN ('librarian','coordenador'))
    AND (
      circle_id IS NULL                         -- réseau-large
      OR escalated_at IS NOT NULL               -- escaladé → réseau
      OR author_user_id = auth.uid()            -- l'auteur·rice voit toujours le sien
      OR EXISTS (                                -- staff d'une biblio membre du cercle ciblé
        SELECT 1 FROM public.circle_memberships cm
        JOIN public.user_library_memberships ulm ON ulm.library_id = cm.library_id
        WHERE cm.circle_id = entraide_help_requests.circle_id
          AND cm.status = 'membro'
          AND ulm.user_id = auth.uid() AND ulm.status = 'active'
          AND ulm.role IN ('librarian','coordenador')
      )
    )
  );

-- ── Lecture des RÉPONSES : alignée sur la visibilité de l'appel parent ───────
-- (la RLS de entraide_help_requests s'applique dans la sous-requête → on ne voit
--  une réponse que si on peut voir son appel.)
DROP POLICY IF EXISTS entraide_offers_read_staff ON public.entraide_help_offers;
CREATE POLICY entraide_offers_read_staff ON public.entraide_help_offers
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.entraide_help_requests r WHERE r.id = request_id));

-- ── Escalade « cercle → réseau si silence » (lazy, idempotente) ──────────────
CREATE OR REPLACE FUNCTION api.fn_entraide_escalate_due()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog
AS $function$
DECLARE n integer;
BEGIN
  UPDATE public.entraide_help_requests r
    SET escalated_at = now()
    WHERE r.status = 'open' AND r.circle_id IS NOT NULL AND r.escalated_at IS NULL
      AND r.created_at < now() - interval '3 days'
      AND NOT EXISTS (SELECT 1 FROM public.entraide_help_offers o WHERE o.request_id = r.id);
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END $function$;
REVOKE EXECUTE ON FUNCTION api.fn_entraide_escalate_due() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_entraide_escalate_due() TO authenticated;

NOTIFY pgrst, 'reload schema';
