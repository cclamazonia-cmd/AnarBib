-- =====================================================================
-- Capas : la sonde témoin des sources de couvertures ouvre un incident
-- (27/09/2026)
--
-- La voie ISBN de cover_lookup est restée en 404 chez Open Library pendant
-- une durée inconnue sans que rien ne le dise. health-probe appelle désormais,
-- une fois par heure, les sources de capas par le MÊME code que cover_lookup
-- (supabase/functions/_shared/capas/sources.ts), sur des témoins dont la
-- couverture existe. Au premier échec, un incident `capas_sources` est ouvert
-- SANS alerte ; au deuxième d'affilée, les admins réseau sont prévenu·es ;
-- au retour, il se referme (avec un courriel seulement s'il avait alerté).
--
-- Ce kind doit être admis par la CHECK, sinon l'insertion échoue et la sonde
-- ne retient jamais rien (migration 20260821060000 : « en ajouter une ici sans
-- élargir la CHECK ferait échouer l'insertion en silence »). La garde
-- src/tests/health-probe-kinds-check.test.js lit CETTE liste.
-- =====================================================================

alter table public.service_health_incidents
  drop constraint if exists service_health_incidents_kind_check;

alter table public.service_health_incidents
  add constraint service_health_incidents_kind_check
  check (kind = any (array[
    'service',                -- sondes HTTP du parcours public
    'backup',                 -- temoin de vie des trois flux restic
    'notifications',          -- fn_healthcheck_notifications
    'ressources_numeriques',  -- fn_healthcheck_digital_resources
    'backup_snapshot',        -- instantane non atteste (20260828234500)
    'images_pins',            -- fn_healthcheck_images_pins
    'mail_transport',         -- fn_healthcheck_mail_transport (20260924180538)
    'deploiement',            -- fn_healthcheck_deploiement (20260925082749)
    'capas_sources'           -- sonde temoin des sources de capas (cette migration)
  ]));

-- ─── Vérification : porte sur ce que CETTE migration fait ───────────────
do $verif$
begin
  if not exists (select 1 from pg_constraint
                  where conname = 'service_health_incidents_kind_check'
                    and pg_get_constraintdef(oid) like '%capas_sources%'
                    and pg_get_constraintdef(oid) like '%deploiement%') then
    raise exception 'la CHECK des incidents ignore capas_sources (ou a perdu deploiement)';
  end if;
end $verif$;
