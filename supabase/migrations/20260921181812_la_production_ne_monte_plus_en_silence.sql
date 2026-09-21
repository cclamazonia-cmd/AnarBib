-- =============================================================================
-- Sonde des pins d'images : la production ne monte plus en silence
-- =============================================================================
-- Date     : 2026-09-21
-- Chantier : auto-hébergement (I2) / supervision
-- Ref      : docs/journal/operations/NOTE_pins-images-remesures_2026-09-21.md
--
-- POURQUOI. L'hébergeur met GoTrue et Storage à jour de lui-même. Entre le
-- 26/08 et le 21/09 la production est passée de 77 à 82 lignes dans
-- `auth.schema_migrations` et de 65 à 68 dans `storage.migrations`. Les deux
-- pins de `deploy/` (la pile auto-hébergée qui doit pouvoir RECEVOIR un dump de
-- cette production) étaient donc repassés SOUS la production, en violation de
-- la règle « image ≥ production, jamais l'inverse » — depuis une date inconnue,
-- et sans que rien le dise : le seul contrôle vivait dans `bootstrap.sh`, qui
-- ne tourne que le jour où l'on reconstruit, et comparait à un chiffre en dur.
-- Un dump auth ou storage ne se restaure pas proprement sous une image en
-- retard ; on l'aurait appris le jour du sinistre.
--
-- CE QUE FAIT CETTE MIGRATION.
--   1. `private.fn_images_pins_attendus()` — LA source, côté base, de ce que
--      les pins du dépôt savent construire (relevé du 21/09). Se remplace par
--      une migration à chaque remesure, en même temps que `deploy/.env.example`
--      et `deploy/bootstrap.sh` : la garde `src/tests/pins-images-coherence`
--      refuse que les trois divergent.
--   2. `private.fn_images_pins_bilan(…)` — la comparaison, PURE : elle ne lit
--      aucune table, on lui passe le constat. C'est elle que la suite SQL
--      éprouve, car le banc CI n'a ni GoTrue ni Storage (schémas en stub).
--   3. `public.fn_healthcheck_images_pins()` — lit le constat et rend le bilan,
--      dans la forme des deux autres sondes structurelles ({ok, genere_le,
--      rubriques en tableaux}). `health-probe` la lit à chaque tour.
--   4. Le `kind` 'images_pins' entre dans la CHECK des incidents — SANS quoi
--      l'insertion échouerait et l'alerte serait retenue à chaque tour (cf.
--      20260821060000). Contrainte reprise de sa définition RÉELLE en
--      production, relevée le 21/09 : cinq valeurs, on en ajoute une.
--
-- DOCTRINE DU CHAMP `ok`. Bloquants : un composant dont le constat diffère de
-- l'attendu, dans un sens comme dans l'autre (« production en avance » = les
-- pins sont à remesurer ; « instance en retard » = l'image qui tourne est plus
-- vieille que ce que le dépôt attend), et un constat ILLISIBLE — perdre
-- l'instrument est une panne, pas un vert. Rien d'informatif ici.
--
-- CE QUE LA SONDE NE PROUVE PAS. Un décompte égal ne prouve pas des colonnes
-- égales ; c'est le banc (`deploy/banc-paliers.sh`) et la concordance des
-- colonnes qui le prouvent, le jour de la remesure. La sonde dit QUAND
-- remesurer, pas que la mesure est bonne.
-- =============================================================================

begin;

-- 1. L'attendu -----------------------------------------------------------------
create or replace function private.fn_images_pins_attendus()
returns jsonb
language sql
immutable
set search_path to 'pg_temp'
as $fn$
  select jsonb_build_object(
    'releve_le', '2026-09-21',
    'gotrue',  jsonb_build_object('tag', 'v2.197.0', 'migrations', 82, 'derniere', '20260831180000'),
    'storage', jsonb_build_object('tag', 'v1.72.0',  'migrations', 68, 'derniere', 'objects-null-version-index')
  );
$fn$;

comment on function private.fn_images_pins_attendus() is
  'Ce que les pins de deploy/.env.example savent construire, mesuré au banc (deploy/banc-paliers.sh) : tag, nombre de migrations, dernière migration, pour GoTrue et Storage, et la date du relevé. Se remplace par une migration à CHAQUE remesure, avec .env.example et bootstrap.sh — la garde vitest pins-images-coherence tient les trois ensemble.';

-- 2. La comparaison, pure ------------------------------------------------------
create or replace function private.fn_images_pins_bilan(
  p_gotrue_n integer, p_gotrue_derniere text,
  p_storage_n integer, p_storage_derniere text
)
returns jsonb
language plpgsql
stable
set search_path to 'pg_temp'
as $fn$
declare
  v_att        jsonb := private.fn_images_pins_attendus();
  v_derives    jsonb := '[]'::jsonb;
  v_illisibles jsonb := '[]'::jsonb;
  v_comp       text;
  v_n          integer;
  v_der        text;
  v_att_n      integer;
begin
  foreach v_comp in array array['gotrue', 'storage'] loop
    if v_comp = 'gotrue' then v_n := p_gotrue_n;  v_der := p_gotrue_derniere;
    else                      v_n := p_storage_n; v_der := p_storage_derniere;
    end if;
    v_att_n := (v_att -> v_comp ->> 'migrations')::integer;

    if v_n is null then
      v_illisibles := v_illisibles || jsonb_build_object(
        'composant', v_comp,
        'pourquoi',  'table des migrations absente ou illisible');
    elsif v_n <> v_att_n or v_der is distinct from (v_att -> v_comp ->> 'derniere') then
      v_derives := v_derives || jsonb_build_object(
        'composant',          v_comp,
        'sens',               case when v_n > v_att_n then 'production_en_avance'
                                   when v_n < v_att_n then 'instance_en_retard'
                                   else 'meme_nombre_autre_derniere' end,
        'constate',           v_n,
        'constate_derniere',  v_der,
        'attendu',            v_att_n,
        'attendu_derniere',   v_att -> v_comp ->> 'derniere',
        'pin_du_depot',       v_att -> v_comp ->> 'tag');
    end if;
  end loop;

  return jsonb_build_object(
    'ok', (jsonb_array_length(v_derives) = 0 and jsonb_array_length(v_illisibles) = 0),
    'genere_le', now(),
    'pins_a_remesurer',   v_derives,
    'constat_illisible',  v_illisibles,
    'attendu',            v_att,
    'que_faire', 'Relever les versions servies (/auth/v1/health, /storage/v1/version), passer deploy/banc-paliers.sh avec le pin courant en témoin, puis remplacer ENSEMBLE private.fn_images_pins_attendus() (migration), deploy/.env.example et les seuils de deploy/bootstrap.sh.'
  );
end $fn$;

comment on function private.fn_images_pins_bilan(integer, text, integer, text) is
  'Compare un constat (nombre et dernière migration de GoTrue et de Storage) à private.fn_images_pins_attendus(). PURE : ne lit aucune table — c''est ce qui la rend éprouvable sur le banc CI, où auth et storage sont des stubs. Un constat nul = illisible = bloquant.';

-- 3. La sonde ------------------------------------------------------------------
create or replace function public.fn_healthcheck_images_pins()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'pg_temp'
as $fn$
declare
  v_gn integer; v_gd text;
  v_sn integer; v_sd text;
begin
  -- EXECUTE + to_regclass : ces deux tables n'appartiennent pas au dépôt (GoTrue
  -- et Storage les construisent) et n'existent pas sur le banc CI. Une table
  -- absente doit rendre un constat NUL — donc « illisible », bloquant — pas
  -- une exception qui ferait passer la sonde pour injoignable.
  if to_regclass('auth.schema_migrations') is not null then
    begin
      execute 'select count(*)::integer, max(version)::text from auth.schema_migrations'
        into v_gn, v_gd;
    exception when insufficient_privilege then
      v_gn := null; v_gd := null;
    end;
  end if;

  if to_regclass('storage.migrations') is not null then
    begin
      execute 'select count(*)::integer, (select name::text from storage.migrations order by id desc limit 1) from storage.migrations'
        into v_sn, v_sd;
    exception when insufficient_privilege then
      v_sn := null; v_sd := null;
    end;
  end if;

  return private.fn_images_pins_bilan(v_gn, v_gd, v_sn, v_sd);
end $fn$;

comment on function public.fn_healthcheck_images_pins() is
  'Sonde structurelle : les images GoTrue et Storage de CETTE instance construisent-elles exactement ce que les pins du dépôt attendent ? L''hébergeur monte la production de lui-même (77→82 et 65→68 entre le 26/08 et le 21/09/2026, découvert par hasard) ; un pin passé sous la production rend un dump irrestaurable. Lue par health-probe à chaque tour, incident de genre images_pins. Lecture seule. Dit QUAND remesurer, pas que la mesure est bonne.';

revoke all on function private.fn_images_pins_attendus() from public, anon, authenticated;
revoke all on function private.fn_images_pins_bilan(integer, text, integer, text) from public, anon, authenticated;
revoke all on function public.fn_healthcheck_images_pins() from public, anon, authenticated;
grant execute on function public.fn_healthcheck_images_pins() to service_role;

-- 4. Le genre d'incident -------------------------------------------------------
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
    'images_pins'             -- fn_healthcheck_images_pins
  ]));

-- Vérification : porte sur ce que CETTE migration fait (DOC-DEPLOY-4).
do $verif$
declare
  v jsonb;
begin
  v := private.fn_images_pins_bilan(82, '20260831180000', 68, 'objects-null-version-index');
  if (v ->> 'ok')::boolean is not true then
    raise exception 'images_pins : le constat égal à l''attendu ne rend pas ok (%).', v;
  end if;
  v := private.fn_images_pins_bilan(83, '20261001000000', 68, 'objects-null-version-index');
  if (v ->> 'ok')::boolean is not false
     or v -> 'pins_a_remesurer' -> 0 ->> 'sens' <> 'production_en_avance' then
    raise exception 'images_pins : une production en avance n''est pas signalée (%).', v;
  end if;
  if has_function_privilege('anon', 'public.fn_healthcheck_images_pins()', 'execute')
     or has_function_privilege('authenticated', 'public.fn_healthcheck_images_pins()', 'execute') then
    raise exception 'images_pins : la sonde est restée ouverte à anon ou authenticated.';
  end if;
end $verif$;

commit;
