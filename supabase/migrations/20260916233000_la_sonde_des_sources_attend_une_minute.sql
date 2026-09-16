-- ===========================================================================
-- GAZ-8, suite — la sonde manuelle des sources attend une minute entre deux.
-- Audit du 16/09/2026 (complément « la 420e » de
-- AUDIT_execute_authenticated_2026-09-01) : api.fn_gazette_probe_sources est
-- justifiée (network_staff en tête, délégation à fn_gazette_build_call non
-- exposée), mais rien ne bornait le geste — chaque appel fait un http_post
-- vers notre Edge Function, qui sollicite à son tour les sources externes.
-- Le garde-fou d'une ligne, décidé le 16/09 : si une source porte un
-- last_fetched_at de moins d'une minute, on refuse (55000, message
-- « too_soon »). C'est l'Edge qui écrit last_fetched_at quelques secondes
-- après l'appel : la fenêtre asynchrone entre l'appel et l'écriture n'est pas
-- couverte, et c'est accepté — le but est de borner la fréquence, pas de
-- sérialiser. Après la collecte mensuelle du cron, la sonde manuelle attend
-- aussi une minute : voulu, la collecte vient de tester les flux.
--
-- Définition repartie de celle de la production (identique à la migration
-- 20260915203617), une garde ajoutée, commentaire mis à jour. Droits inchangés
-- (CREATE OR REPLACE conserve l'ACL) : anon fermé, authenticated ouvert, la
-- garde de rôle dans le corps. Suite : gazette_sources_probe_tests (T4 vide
-- les horodatages avant d'appeler, T5 attend le refus).
-- ===========================================================================

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
  if exists (select 1 from public.gazette_sources s
              where s.last_fetched_at > now() - interval '1 minute') then
    raise exception 'too_soon: une sonde a tourne il y a moins d une minute' using errcode = '55000';
  end if;
  perform public.fn_gazette_build_call('probe_sources');
end;
$fn$;

comment on function api.fn_gazette_probe_sources() is
  'Teste les flux du registre gazette_sources depuis l''Edge, à la demande du '
  'staff réseau (bouton « Tester les sources maintenant »). Ne touche ni numéro '
  'ni job : seuls last_fetched_at / last_status / last_error / last_item_at '
  'bougent, quelques secondes plus tard (pg_net → gazette-monthly-build, étape '
  'probe_sources). Gardes : network_staff actif (42501 sinon) ; refus 55000 '
  '« too_soon » si un last_fetched_at date de moins d''une minute (16/09/2026).';

do $$
begin
  if has_function_privilege('anon', 'api.fn_gazette_probe_sources()', 'EXECUTE') then
    raise exception 'ECHEC : api.fn_gazette_probe_sources ouverte à anon';
  end if;
  if not has_function_privilege('authenticated', 'api.fn_gazette_probe_sources()', 'EXECUTE') then
    raise exception 'ECHEC : api.fn_gazette_probe_sources fermée à authenticated';
  end if;
  if position('too_soon' in pg_get_functiondef('api.fn_gazette_probe_sources()'::regprocedure)) = 0 then
    raise exception 'ECHEC : la garde too_soon n''est pas dans le corps';
  end if;
  raise notice 'OK : la sonde manuelle attend une minute entre deux (garde too_soon, 55000).';
end $$;

commit;
