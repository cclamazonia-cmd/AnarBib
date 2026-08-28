-- =========================================================================
-- Paquet moisson-oai-hebdomadaire — l'écran promettait un moissonnage
-- automatique ; il existe enfin
-- =========================================================================
-- Date     : 2026-08-28
-- Chantier : importations — moisson OAI-PMH, dernier morceau du Lot 3
-- Voisins  : 20260828170000_chemin_oai_pmh_executable.sql (les RPC exécutables)
--            20260828190000_lot3b_moisson_oai_pmh.sql     (l'EF + le dispatch)
--
-- POURQUOI
--   `importacoes.oai.desc` annonce, dans les 10 locales : « Moissonnage
--   automatique HEBDOMADAIRE de catalogues exposés via le protocole OAI-PMH ».
--   Vérifié le 28/08/2026 : 34 crons actifs, aucun ne moissonne, et aucun
--   workflow de forge planifié non plus. Les seuls appelants de
--   fn_import_harvest_oai étaient le bouton « Moissonner maintenant » et les
--   tests. La promesse tenait à un clic.
--
--   C'est la même forme de défaut que tout le reste de ce chantier — une
--   interface qui affirme, un arrière-plan qui ne fait pas — sauf qu'ici rien
--   n'était cassé : il manquait la boucle. Le modèle de données était déjà fait
--   pour le périodique : lots_per_cycle borne un cycle, pending_resumption_token
--   le reprend au suivant, last_harvest_at alimente le `from=` incrémental.
--
-- POURQUOI UNE FONCTION À PART, ET PAS LE CRON SUR fn_import_harvest_oai
--   fn_import_harvest_oai est la RPC du BOUTON : elle exige une adhésion staff
--   (public.my_access) et le rôle coordenador ou admin réseau, et elle écrit
--   requested_by = l'acteur. Un cron n'a pas d'auth.uid() : elle échouerait sur
--   son propre contrôle d'accès. Emprunter l'identité de quelqu'un pour la
--   contourner serait pire — le run porterait le nom d'une personne qui n'a
--   rien demandé, un mardi à 4 h du matin.
--
--   Cette fonction-ci est donc INTERNE et sans acteur : les runs qu'elle crée
--   portent requested_by = NULL, ce qui est la vérité — c'est le réseau qui
--   moissonne, pas une personne.
--
-- CE QU'ELLE VISE, ET CE QU'ELLE ÉVITE
--   * source_kind = 'oai_pmh' ET import_enabled — la colonne existait,
--     était mise à true à l'enregistrement, et n'était LUE PAR PERSONNE (vérifié
--     par pg_get_functiondef le 28/08 : fn_import_harvest_oai ne la consulte
--     pas). Ici elle veut enfin dire quelque chose : décocher une source
--     l'exclut du moissonnage automatique.
--   * harvest_status <> 'in_progress' — on ne double jamais un cycle en cours.
--     Le verrou périmé (> 30 min) n'est PAS repris ici : la reprise est un geste
--     de rattrapage qui mérite un œil humain, et le cycle suivant la proposera.
--   * les sources en 'paused' d'abord : elles sont au milieu d'une liste, avec
--     un jeton qui a une durée de vie. Les faire attendre derrière une source
--     déjà à jour, c'est risquer de le laisser expirer.
--   * un endpoint est obligatoire (une source sans URL n'est pas moissonnable).
--
--   Une source en 'error' EST reprise. Une panne passagère ne doit pas exiger
--   qu'une humaine reclique ; et une requête par semaine contre un entrepôt
--   durablement cassé n'est pas de l'acharnement — last_error reste lisible à
--   l'écran pour que quelqu'un tranche.
--
-- ET LES SERVEURS D'EN FACE
--   Un cycle vaut au plus lots_per_cycle requêtes (5 par défaut), espacées d'une
--   seconde côté EF, avec un User-Agent qui porte le contact fédéral, et le
--   moissonneur honore désormais Retry-After (503/429) au lieu de prendre un
--   « pas maintenant » pour une panne — ces trois points ont été ajoutés à l'EF
--   dans le même paquet, AVANT de brancher l'automatisme : un clic humain
--   occasionnel pardonne l'impolitesse, une machine hebdomadaire non.
--   En régime établi, le `from=` incrémental fait que chaque cycle ne demande
--   que ce qui a bougé : le plus souvent une requête, qui répond noRecordsMatch.
--
--   Cadence : une fois par semaine, le mardi à 4 h 20 UTC — un creux, et un
--   horaire qui ne tombe sur aucun autre cron du dépôt.
--
-- CHECKLIST DOCTRINE
--   [x] Aucune fonction existante réécrite : cette migration n'AJOUTE que
--       ingest.fn_cron_import_harvest_oai + sa planification
--   [x] cron.schedule dans un bloc DO/EXCEPTION : le job sql-tests reconstruit
--       le schéma SANS pg_cron, un appel nu y rougirait
--   [x] Fonction INTERNE (schéma ingest, aucun GRANT à authenticated)
--   [x] DO block de vérification STRUCTUREL ; le fonctionnel vit dans
--       tests/sql/import_oai_pmh_tests.sql
-- =========================================================================

begin;

create or replace function ingest.fn_cron_import_harvest_oai(
  p_max_sources integer default 20
) returns jsonb
language plpgsql
security definer
set search_path to 'ingest', 'public', 'auth'
as $function$
declare
  v_src        record;
  v_run_id     bigint;
  v_max        integer;
  v_lances     integer := 0;
  v_ignorees   integer := 0;
  v_details    jsonb := '[]'::jsonb;
begin
  for v_src in
    select s.id, s.library_id, s.partner_name, s.oai_endpoint_url,
           h.lots_per_cycle, h.harvest_status
      from ingest.partner_catalog_sources s
      join ingest.oai_harvest_state h on h.source_id = s.id
     where s.source_kind = 'oai_pmh'
       and s.import_enabled
       and coalesce(nullif(btrim(s.oai_endpoint_url), ''), null) is not null
       and h.harvest_status is distinct from 'in_progress'
     -- Les cycles interrompus d'abord : leur jeton de reprise a une duree de
     -- vie, et le perdre coute un re-moissonnage complet.
     order by (h.harvest_status = 'paused') desc, h.last_harvest_at asc nulls first, s.id
     limit greatest(1, coalesce(p_max_sources, 20))
  loop
    v_max := coalesce(v_src.lots_per_cycle, 5);

    -- On refait ici ce que fait la RPC du bouton, MOINS le controle d'acces
    -- (aucun acteur) et AVEC requested_by a NULL : le run est l'oeuvre du
    -- reseau, pas d'une personne.
    insert into ingest.partner_catalog_import_runs
      (source_id, library_id, detected_format, run_status, storage_path,
       original_filename, requested_by, imported_rows)
    values
      (v_src.id, v_src.library_id, 'oai_pmh', 'queued',
       'oai/' || v_src.id::text || '/' || current_date::text,
       'oai-harvest-' || current_date::text, null, 0)
    returning id into v_run_id;

    update ingest.oai_harvest_state
       set harvest_status            = 'in_progress',
           last_run_id               = v_run_id,
           lots_completed_this_cycle = 0,
           last_error                = null
     where source_id = v_src.id;

    perform ingest.fn_dispatch_oai_harvest(v_run_id, v_max);

    v_lances := v_lances + 1;
    v_details := v_details || jsonb_build_object(
      'source_id', v_src.id, 'run_id', v_run_id,
      'partner_name', v_src.partner_name, 'max_lots', v_max,
      'etat_avant', v_src.harvest_status);
  end loop;

  select count(*) into v_ignorees
    from ingest.partner_catalog_sources s
    join ingest.oai_harvest_state h on h.source_id = s.id
   where s.source_kind = 'oai_pmh'
     and (not s.import_enabled or h.harvest_status = 'in_progress');

  return jsonb_build_object(
    'ok', true, 'lances', v_lances, 'ignorees', v_ignorees, 'details', v_details);
end;
$function$;

revoke execute on function ingest.fn_cron_import_harvest_oai(integer) from public;
grant  execute on function ingest.fn_cron_import_harvest_oai(integer) to service_role;

comment on function ingest.fn_cron_import_harvest_oai(integer) is
  'Moissonnage OAI-PMH automatique (hebdomadaire) — dernier morceau du Lot 3. '
  'INTERNE et SANS ACTEUR : les runs crees portent requested_by = NULL, c''est '
  'le reseau qui moissonne. Ne double jamais un cycle en cours (in_progress), '
  'respecte import_enabled (colonne qui, jusqu''au 28/08/2026, n''etait lue par '
  'personne), et sert les sources ''paused'' en premier — leur jeton de reprise '
  'a une duree de vie. Une source en ''error'' est reprise : une panne passagere '
  'ne doit pas exiger un clic humain. Appelee par le cron '
  'anarbib-oai-harvest-weekly.';

-- ── Planification ────────────────────────────────────────────────────────
-- DO/EXCEPTION obligatoire : le job sql-tests reconstruit le schema dans une
-- base SANS pg_cron, ou `cron.schedule` n'existe pas. Un appel nu y ferait
-- rougir la CI sur une migration pourtant saine.
do $$
BEGIN
  PERFORM cron.schedule(
    'anarbib-oai-harvest-weekly',
    '20 4 * * 2',                       -- mardi 04:20 UTC : creux, et aucun autre cron a cette minute
    'SELECT ingest.fn_cron_import_harvest_oai();'
  );
EXCEPTION WHEN undefined_function OR undefined_table OR invalid_schema_name OR insufficient_privilege THEN
  RAISE NOTICE 'pg_cron indisponible ici (base de test) : planification sautee.';
END $$;

-- ── Vérification STRUCTURELLE ────────────────────────────────────────────
do $$
DECLARE
  v_def text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'ingest' AND p.proname = 'fn_cron_import_harvest_oai';
  IF v_def IS NULL THEN
    RAISE EXCEPTION 'ingest.fn_cron_import_harvest_oai introuvable apres migration';
  END IF;
  -- Les trois garanties qui rendent l'automatisme acceptable.
  IF position('import_enabled' in v_def) = 0 THEN
    RAISE EXCEPTION 'le cron ne respecte pas import_enabled : desactiver une source ne servirait a rien';
  END IF;
  IF position('in_progress' in v_def) = 0 THEN
    RAISE EXCEPTION 'le cron ne respecte pas le verrou : il doublerait un cycle en cours';
  END IF;
  IF position('fn_dispatch_oai_harvest' in v_def) = 0 THEN
    RAISE EXCEPTION 'le cron n''appelle pas le dispatch : il creerait des runs que personne ne traite';
  END IF;
  RAISE NOTICE 'moisson-oai-hebdomadaire : verifications structurelles OK';
END $$;

commit;
