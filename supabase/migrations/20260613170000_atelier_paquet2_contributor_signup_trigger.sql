-- =====================================================================
-- ATELIER AUTORITÉS — Paquet 2 : compte contributeur via criar-conta
-- =====================================================================
-- Quand l'EF `register` pose profiles.signup_intent='contributor' (4e intent,
-- compte réseau sans biblio), ce trigger crée automatiquement la ligne
-- network_contributors (statut active). Aucune appartenance biblio.
-- =====================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_create_network_contributor_on_signup()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_catalog'
AS $$
BEGIN
  IF NEW.signup_intent = 'contributor'
     AND (TG_OP = 'INSERT' OR COALESCE(OLD.signup_intent, '') <> 'contributor') THEN
    INSERT INTO public.network_contributors (user_id, status, display_name)
    VALUES (NEW.id, 'active',
            NULLIF(btrim(coalesce(NEW.first_name, '') || ' ' || coalesce(NEW.last_name, '')), ''))
    ON CONFLICT (user_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;
COMMENT ON FUNCTION public.fn_create_network_contributor_on_signup() IS
  'Atelier autorités (paquet 2) : crée network_contributors quand un compte adopte signup_intent=contributor (via criar-conta / EF register).';

DROP TRIGGER IF EXISTS trg_create_network_contributor ON public.profiles;
CREATE TRIGGER trg_create_network_contributor
  AFTER INSERT OR UPDATE OF signup_intent ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.fn_create_network_contributor_on_signup();

COMMIT;
