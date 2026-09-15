-- =========================================================================
-- AnarBib — Les sources se testent à la main
-- =========================================================================
-- Date     : 2026-09-15
-- Chantier : Gazette Rizoma — registre des sources (GAZ-8)
--
-- POURQUOI
--   La santé d'un flux (gazette_sources.last_status / last_error) n'est
--   mesurée qu'une fois par mois, à 06:00 UTC le 15, par stepStart. Quand un
--   flux tombe — Info Libertaire : 525 Cloudflare le 15/08, délai dépassé le
--   15/09 — on le découvre après coup, et on ne peut vérifier un correctif
--   qu'au numéro suivant, un mois plus tard. Le même flux répond en une
--   seconde depuis un poste et depuis la base (pg_net, mesuré le 15/09) :
--   c'est la vantage de l'Edge qui compte, et seule l'Edge peut la donner.
--
-- CE QUE FAIT CETTE MIGRATION
--   api.fn_gazette_probe_sources() — network_staff actif uniquement — demande
--   à l'EF gazette-monthly-build l'étape 'probe_sources' via
--   public.fn_gazette_build_call (secret lu dans le vault, adresse par
--   private.fn_functions_base_url() : aucun littéral ici, I20). L'étape
--   refait la collecte des sources actives et n'écrit QUE last_* : ni
--   numéro, ni job. L'appel est asynchrone (pg_net) : le panneau recharge le
--   registre quelques secondes plus tard.
--
-- GARDES
--   DEFINER fermée à PUBLIC et anon, ouverte à authenticated — la garde de
--   rôle vit dans le corps, exactement comme api.fn_gazette_broadcast.
--   Aucune table, aucun cron, aucune vue. Suite : gazette_sources_probe_tests.
-- =========================================================================

begin;

create or replace function api.fn_gazette_probe_sources()
returns void
language plpgsql
security definer
set search_path = public, extensions
as $fn$
begin
  if not exists (select 1 from public.network_staff ns
                  where ns.user_id = auth.uid() and ns.is_active) then
    raise exception 'forbidden: network_staff only' using errcode = '42501';
  end if;
  perform public.fn_gazette_build_call('probe_sources');
end;
$fn$;

comment on function api.fn_gazette_probe_sources() is
  'Teste les flux du registre gazette_sources depuis l''Edge, à la demande du '
  'staff réseau (bouton « Tester les sources maintenant »). Ne touche ni numéro '
  'ni job : seuls last_fetched_at / last_status / last_error / last_item_at '
  'bougent, quelques secondes plus tard (pg_net → gazette-monthly-build, étape '
  'probe_sources). Garde : network_staff actif (42501 sinon).';

revoke all on function api.fn_gazette_probe_sources() from public, anon;
grant execute on function api.fn_gazette_probe_sources() to authenticated;

-- ---------------------------------------------------------------------
-- Vérification — annule tout si l'état visé n'est pas atteint
-- ---------------------------------------------------------------------
do $$
begin
  if has_function_privilege('anon', 'api.fn_gazette_probe_sources()', 'EXECUTE') then
    raise exception 'ECHEC : api.fn_gazette_probe_sources ouverte à anon';
  end if;
  if not has_function_privilege('authenticated', 'api.fn_gazette_probe_sources()', 'EXECUTE') then
    raise exception 'ECHEC : api.fn_gazette_probe_sources fermée à authenticated — le bouton serait muet';
  end if;
  if position('probe_sources' in pg_get_functiondef('api.fn_gazette_probe_sources()'::regprocedure)) = 0 then
    raise exception 'ECHEC : la RPC ne demande pas l''étape probe_sources';
  end if;
  raise notice 'OK : api.fn_gazette_probe_sources en place, fermée à anon, ouverte à authenticated (garde de rôle dans le corps).';
end $$;

commit;
