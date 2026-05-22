-- ============================================================================
-- 20260522110000_peb_rpc_revoke_anon.sql
-- ----------------------------------------------------------------------------
-- Chantier #ILL-rpc-anon — retrait du GRANT anon herite des RPC du PEB.
--
-- CONSTAT
--   Trois RPC d'ecriture du PEB portent un GRANT EXECUTE ... TO anon :
--     - fn_peb_create_loan_with_items(jsonb, jsonb)  — cree un PEB
--     - fn_peb_delete_loan(bigint)                   — supprime un PEB
--     - fn_peb_update_status(bigint, text)           — change le statut
--   Ce GRANT est un heritage : a la creation d'une fonction, le GRANT
--   EXECUTE par defaut va a PUBLIC (anon inclus). Ces trois fonctions
--   n'ont jamais recu le REVOKE correctif.
--
--   Aucune raison qu'un role anonyme cree, supprime ou change le statut
--   d'un PEB. Ce sont des operations reservees au personnel authentifie
--   des bibliotheques. Le frontend appelle ces RPC en tant qu'utilisateur
--   authentifie, jamais en anon.
--
-- CORRECTIF
--   REVOKE EXECUTE ... FROM anon (et PUBLIC, pour couper la source) sur les
--   trois fonctions. authenticated et service_role conservent l'execution.
--
-- NOTE
--   Les trois RPC sont non-SECURITY DEFINER : elles s'executent avec les
--   droits de l'appelant et restent protegees par la RLS. Le REVOKE retire
--   une surface d'exposition inutile ; il ne modifie aucun comportement
--   pour les utilisateurs authentifies. Alignement sur la doctrine #150.
--
-- VERIFICATION
--   Bloc DO : aucune des trois fonctions n'accorde plus EXECUTE a anon.
-- ============================================================================

REVOKE EXECUTE ON FUNCTION public.fn_peb_create_loan_with_items(jsonb, jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_peb_delete_loan(bigint)                  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_peb_update_status(bigint, text)          FROM PUBLIC, anon;

-- On reconduit explicitement les roles legitimes (idempotent, defensif :
-- garantit que le REVOKE FROM PUBLIC n'a pas emporte un GRANT utile).
GRANT EXECUTE ON FUNCTION public.fn_peb_create_loan_with_items(jsonb, jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_peb_delete_loan(bigint)                  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_peb_update_status(bigint, text)          TO authenticated, service_role;


-- ============================================================================
-- VERIFICATION POST-MIGRATION
-- ============================================================================
DO $verif$
declare
  v_anon_count integer;
begin
  -- Aucune des trois fonctions ne doit plus accorder EXECUTE a anon.
  select count(*) into v_anon_count
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  cross join lateral aclexplode(p.proacl) acl
  where n.nspname = 'public'
    and p.proname in ('fn_peb_create_loan_with_items','fn_peb_delete_loan','fn_peb_update_status')
    and acl.grantee = 'anon'::regrole
    and acl.privilege_type = 'EXECUTE';

  if v_anon_count <> 0 then
    raise exception 'Verification echouee : % RPC du PEB accordent encore EXECUTE a anon.', v_anon_count;
  end if;

  raise notice 'Migration 20260522110000 : verification OK (aucune RPC PEB n accorde EXECUTE a anon).';
end;
$verif$;
