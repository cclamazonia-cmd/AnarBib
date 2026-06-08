-- ════════════════════════════════════════════════════════════════════════════
-- OPAC — Durcissement OPAC-W1 : WITH CHECK explicite sur user_wishlist
-- Auteur  : Claude (Opus)
-- Session : Cloture corpus OPAC (finitions)
-- Date    : 2026-06-08 (UTC)
-- Registre: OPAC-W1
--
-- La policy unique « Users can manage own wishlist » (cmd ALL) n'avait pas de
-- WITH CHECK explicite : pour INSERT/UPDATE, Postgres retombait sur le USING
-- (auth.uid()=user_id), donc deja sur ce qu'on veut. On rend la regle explicite
-- (defense en profondeur, lisibilite de l'audit).
-- ════════════════════════════════════════════════════════════════════════════

ALTER POLICY "Users can manage own wishlist" ON public.user_wishlist
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
