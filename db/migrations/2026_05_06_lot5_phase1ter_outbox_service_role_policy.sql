-- ============================================================================
-- Lot 5 — Phase 1ter : Policy service_role sur team_notification_outbox
-- ============================================================================
-- Date : 2026-05-06
-- Auteur : Xavier VAN WELDEN
-- ============================================================================
--
-- Contexte du patch :
--   La table team_notification_outbox a été créée avec RLS activée mais SANS
--   policy explicite (cf. 2026_05_06_lot5_phase1_outbox_infrastructure.sql).
--   L'idée d'origine : seules les RPCs SECURITY DEFINER et le trigger pourraient
--   y écrire, donc pas besoin de policy publique.
--
--   Mais le handler domain/team.ts (côté Edge Function) doit aussi pouvoir
--   UPDATE le status (sent / failed / sent_at) de la ligne outbox après
--   traitement. Or, l'EF utilise supabaseAdmin qui devrait théoriquement
--   bypass la RLS via service_role… mais en pratique l'UPDATE échouait
--   silencieusement (status restait 'pending' en base alors que le mail
--   était bien envoyé).
--
--   Diagnostic effectué le 06/05/2026 23h :
--   - RLS activée sur team_notification_outbox : oui
--   - Policies présentes : aucune
--   - Conséquence : service_role bloqué pour UPDATE depuis EF
--
--   Solution : policy explicite ALL TO service_role.
-- ============================================================================

CREATE POLICY "service_role_full_access" ON public.team_notification_outbox
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Vérification
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'team_notification_outbox'
      AND policyname = 'service_role_full_access'
  ) THEN
    RAISE EXCEPTION 'Échec : policy service_role_full_access manquante après création';
  END IF;

  RAISE NOTICE 'Phase 1ter appliquée : policy service_role_full_access en place sur team_notification_outbox.';
END $$;
