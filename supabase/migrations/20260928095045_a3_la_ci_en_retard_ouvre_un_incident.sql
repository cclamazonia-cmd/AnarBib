-- =====================================================================
-- A3 — la CI en retard ouvre un incident (28/09/2026)
--
-- Le runner d'intégration continue tourne sur le poste du mainteneur. Le
-- 27/09 à 22 h 40 le portable s'est mis en veille pendant un job `app` :
-- Codeberg l'a déclaré en échec à 23 h 45, le `backend` qui devait suivre
-- n'a jamais tourné, une migration (911ad1db) a attendu le push du lendemain
-- — et rien ne l'a dit. health-probe interroge désormais, une fois par heure,
-- la liste des tâches de la forge (_shared/ci/forgejo-tasks.ts) et ouvre un
-- incident quand une tâche attend depuis plus de deux heures ou quand le
-- dernier job app/backend est en échec depuis plus de trente minutes.
--
-- Ce kind doit être admis par la CHECK, sinon l'insertion échoue et la sonde
-- retient l'alerte (elle le dit dans sa réponse). La liste reprend celle de
-- 20260927130745 à l'identique, plus 'ci_en_retard' ;
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
    'capas_sources',          -- sonde temoin des sources de capas (20260927130745)
    'ci_en_retard'            -- taches de la forge en attente ou en echec (cette migration)
  ]));

-- ─── Vérification : porte sur ce que CETTE migration fait ───────────────
do $verif$
begin
  if not exists (select 1 from pg_constraint
                  where conname = 'service_health_incidents_kind_check'
                    and pg_get_constraintdef(oid) like '%ci_en_retard%'
                    and pg_get_constraintdef(oid) like '%capas_sources%'
                    and pg_get_constraintdef(oid) like '%deploiement%') then
    raise exception 'la CHECK des incidents ignore ci_en_retard (ou a perdu un kind)';
  end if;
end $verif$;
