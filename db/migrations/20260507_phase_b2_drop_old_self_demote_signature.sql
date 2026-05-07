-- Suppression de l'ancienne signature 2-args de fn_team_self_demote.
-- La nouvelle signature 3-args (avec p_confirm_close_governance optionnel)
-- couvre tous les cas. La présence des 2 signatures crée une ambiguïté
-- qui empêche tout appel de la fonction.

DROP FUNCTION public.fn_team_self_demote(uuid, text);

-- Vérification : la 3-args doit toujours être là
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc
    WHERE pronamespace = 'public'::regnamespace
      AND proname = 'fn_team_self_demote'
      AND pronargs = 3
  ) THEN
    RAISE EXCEPTION 'fn_team_self_demote (3 args) introuvable après DROP — abort';
  END IF;
END $$;
