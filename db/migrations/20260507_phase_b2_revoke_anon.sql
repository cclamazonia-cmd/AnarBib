-- Phase B2 cleanup : retirer le droit d'EXECUTE par anon (rôle Supabase
-- distinct de PUBLIC). La fonction valide déjà auth.uid() IS NULL en interne,
-- mais autant verrouiller au niveau privilèges.

REVOKE EXECUTE ON FUNCTION public.fn_team_promote_to_administrador(uuid, uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_team_self_demote(uuid, text, text) FROM anon;

-- Et pour cohérence, vérifier les autres fn_team_* installées en B1
REVOKE EXECUTE ON FUNCTION public.fn_team_list_memberships(text, uuid) FROM anon;
