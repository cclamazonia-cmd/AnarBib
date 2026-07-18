-- Garde-fou : un exemplaire ne peut pas pointer un holding d'une autre biblio
-- que la sienne. Rien ne garantissait cette coherence jusqu'ici (2 FK
-- independantes seulement : exemplares_holding_id_fkey et
-- exemplares_library_id_fkey) ; c'est ce qui a permis a l'exemplaire
-- MLEG-2026-0267 de se retrouver rattache au holding BLMF du livre 2318
-- (cf. migration precedente pour la correction de donnees).

CREATE OR REPLACE FUNCTION public.fn_validate_exemplar_library_matches_holding()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  IF NEW.holding_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.book_holdings h
      WHERE h.id = NEW.holding_id AND h.library_id = NEW.library_id
    ) THEN
      RAISE EXCEPTION 'exemplar_library_holding_mismatch: exemplar (tombo=%) library_id nao corresponde a biblioteca do holding %.', NEW.tombo, NEW.holding_id
        USING ERRCODE = '23514', HINT = 'error.catalog.holding_library_mismatch';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_exemplar_library_matches_holding ON public.exemplares;
CREATE TRIGGER trg_exemplar_library_matches_holding
  BEFORE INSERT OR UPDATE OF library_id, holding_id ON public.exemplares
  FOR EACH ROW EXECUTE FUNCTION public.fn_validate_exemplar_library_matches_holding();
